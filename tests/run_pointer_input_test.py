#!/usr/bin/env python3
"""X11 OS input smoke for solo, listen-host and dedicated-client recovery."""
import argparse
import ctypes as c
import ctypes.util
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--port', type=int, default=29730)
    parser.add_argument('--role', choices=('offline', 'host', 'client'), default='host')
    parser.add_argument('--resolution', default='1280x720')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    x = c.CDLL(ctypes.util.find_library('X11'))
    xt = c.CDLL(ctypes.util.find_library('Xtst'))
    x.XOpenDisplay.argtypes = [c.c_char_p]
    x.XOpenDisplay.restype = c.c_void_p
    display = x.XOpenDisplay(None)
    if not display:
        raise SystemExit('X11 display unavailable; pointer gate not run')
    x.XDefaultRootWindow.argtypes = [c.c_void_p]
    x.XDefaultRootWindow.restype = c.c_ulong
    x.XSetInputFocus.argtypes = [c.c_void_p, c.c_ulong, c.c_int, c.c_ulong]
    x.XRaiseWindow.argtypes = [c.c_void_p, c.c_ulong]
    x.XTranslateCoordinates.argtypes = [c.c_void_p, c.c_ulong, c.c_ulong, c.c_int, c.c_int, c.POINTER(c.c_int), c.POINTER(c.c_int), c.POINTER(c.c_ulong)]
    x.XFlush.argtypes = [c.c_void_p]
    x.XCloseDisplay.argtypes = [c.c_void_p]
    x.XKeysymToKeycode.argtypes = [c.c_void_p, c.c_ulong]
    xt.XTestFakeMotionEvent.argtypes = [c.c_void_p, c.c_int, c.c_int, c.c_int, c.c_ulong]
    xt.XTestFakeRelativeMotionEvent.argtypes = [c.c_void_p, c.c_int, c.c_int, c.c_ulong]
    xt.XTestFakeButtonEvent.argtypes = [c.c_void_p, c.c_uint, c.c_int, c.c_ulong]
    xt.XTestFakeKeyEvent.argtypes = [c.c_void_p, c.c_uint, c.c_int, c.c_ulong]
    root = x.XDefaultRootWindow(display)
    process = None
    server = None
    try:
        with (args.output / 'peer.log').open('w') as log, (args.output / 'server.log').open('w') as server_log:
            engine = os.environ.get('GODOT_BIN', 'godot')
            network_args = []
            if args.role == 'host':
                network_args = [f'--host-port={args.port}']
            elif args.role == 'client':
                server = subprocess.Popen([engine, '--headless', '--path', str(ROOT), '--', f'--server-port={args.port}', '--settings-path=user://pointer-os-server.cfg'], stdout=server_log, stderr=subprocess.STDOUT)
                deadline = time.monotonic() + 8
                while 'DEDICATED_SERVER_READY' not in (args.output / 'server.log').read_text():
                    if server.poll() is not None or time.monotonic() >= deadline:
                        raise RuntimeError('Dedicated pointer server not ready; see server.log')
                    time.sleep(.05)
                network_args = ['--join-address=127.0.0.1', f'--join-port={args.port}']
            process = subprocess.Popen([engine, '--path', str(ROOT), '--resolution', args.resolution, '--script', 'res://tests/pointer_input_peer.gd', '--', *network_args, f'--pointer-role={args.role}', '--settings-path=user://pointer-os-test.cfg'], stdout=log, stderr=subprocess.STDOUT)
            seen = 0
            deadline = time.monotonic() + 65
            while process.poll() is None and time.monotonic() < deadline:
                stages = [line.removeprefix('POINTER_STAGE ') for line in (args.output / 'peer.log').read_text().splitlines() if line.startswith('POINTER_STAGE ')]
                for line in stages[seen:]:
                    record = json.loads(line)
                    seen += 1
                    stage = record['stage']
                    if stage == 'finished' or process.poll() is not None:
                        continue
                    if stage == 'server_loss':
                        server.terminate()
                        server.wait(timeout=5)
                        continue
                    window = record['window']
                    if stage == 'focus_away':
                        x.XSetInputFocus(display, root, 1, 0)
                        x.XFlush(display)
                        continue
                    x.XRaiseWindow(display, window)
                    x.XSetInputFocus(display, window, 1, 0)
                    x.XFlush(display)
                    time.sleep(.15)
                    if stage in ('close_lobby', 'settings', 'back', 'close_recovery'):
                        px, py, child = c.c_int(), c.c_int(), c.c_ulong()
                        x.XTranslateCoordinates(display, window, root, int(record['position'][0]), int(record['position'][1]), c.byref(px), c.byref(py), c.byref(child))
                        print(f"POINTER_INJECT stage={stage} client={record['position']} root={[px.value, py.value]}", flush=True)
                        xt.XTestFakeMotionEvent(display, -1, px.value, py.value, 0)
                        x.XFlush(display)
                        time.sleep(.15)
                        xt.XTestFakeButtonEvent(display, 1, 1, 0)
                        xt.XTestFakeButtonEvent(display, 1, 0, 40)
                    elif stage in ('camera', 'camera_after_focus', 'camera_after_recovery'):
                        xt.XTestFakeRelativeMotionEvent(display, 24, -7, 0)
                    elif stage in ('pause', 'resume', 'open_lobby'):
                        key = x.XKeysymToKeycode(display, 0x6c if stage == 'open_lobby' else 0xff1b)
                        xt.XTestFakeKeyEvent(display, key, 1, 0)
                        xt.XTestFakeKeyEvent(display, key, 0, 40)
                    x.XFlush(display)
                time.sleep(.05)
            if process.poll() is None:
                raise RuntimeError('Pointer fixture timeout; inspect peer.log before changing production')
            output = (args.output / 'peer.log').read_text()
            if process.returncode or 'POINTER_INPUT_OK' not in output:
                raise RuntimeError(f'Pointer fixture failed; see {args.output / "peer.log"}')
            output += (args.output / 'server.log').read_text()
            errors = [line for line in output.splitlines() if line.startswith(('SCRIPT ERROR:', 'ERROR:')) and 'resources still in use at exit' not in line]
            if errors:
                raise RuntimeError(errors)
            print(f'POINTER_OS_INPUT_OK role={args.role} actual_x11_events=true')
    finally:
        if process is not None and process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
        if server is not None and server.poll() is None:
            server.terminate()
            server.wait(timeout=5)
        x.XCloseDisplay(display)


if __name__ == '__main__':
    main()
