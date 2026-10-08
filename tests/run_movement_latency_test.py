#!/usr/bin/env python3
"""Local-only baseline: python3 tests/run_movement_latency_test.py.

Each client has its own loopback UDP relay; every datagram in each direction
waits added_rtt/2 plus a deterministic -jitter/0/+jitter cycle (clamped at zero).
This can reorder packets. Optional loss drops every Nth datagram independently
in each direction (including ENet control packets); no host network changes.
Measurements use the runner's monotonic receipt times for undelayed loopback
telemetry. Engine tick measurements are retained separately for clock diagnosis.
Use --max-response-ms 50 to opt into a future prediction acceptance bound.
"""
import argparse
import heapq
import json
import os
from pathlib import Path
import re
import selectors
import socket
import statistics
import subprocess
import threading
import time

ROOT = Path(__file__).resolve().parents[1]


class DelayProxy:
    def __init__(self, server_port, delay_ms, jitter_ms=0, loss_every=0):
        self.selector = selectors.DefaultSelector()
        self.front = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.front.bind(('127.0.0.1', 0))
        self.back = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.back.bind(('127.0.0.1', 0))
        for sock in (self.front, self.back):
            sock.setblocking(False)
            self.selector.register(sock, selectors.EVENT_READ)
        self.server = ('127.0.0.1', server_port)
        self.client = None
        self.delay = delay_ms / 2000
        self.jitter = jitter_ms / 1000
        self.queue = []
        self.holds = []
        self.scheduled_holds = []
        self.received_counts = [0, 0]
        self.loss_every = loss_every
        self.dropped_counts = [0, 0]
        self.counts = [0, 0]
        self.error = None
        self.stop = threading.Event()
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    def run(self):
        try:
            self.forward()
        except Exception as error:
            self.error = error

    def forward(self):
        serial = 0
        while not self.stop.is_set():
            now = time.monotonic()
            timeout = max(0, min(.01, self.queue[0][0] - now)) if self.queue else .01
            for key, _ in self.selector.select(timeout):
                sock = key.fileobj
                while True:
                    try:
                        data, address = sock.recvfrom(65535)
                    except BlockingIOError:
                        break
                    if sock is self.front:
                        if self.client is None:
                            self.client = address
                        if address != self.client:
                            raise RuntimeError('Unexpected second client')
                        target, destination, direction = self.back, self.server, 0
                    else:
                        if address != self.server or self.client is None:
                            continue
                        target, destination, direction = self.front, self.client, 1
                    serial += 1
                    received = time.monotonic()
                    offset = (self.received_counts[direction] % 3 - 1) * self.jitter
                    self.received_counts[direction] += 1
                    if self.loss_every and self.received_counts[direction] % self.loss_every == 0:
                        self.dropped_counts[direction] += 1
                        continue
                    hold = max(0, self.delay + offset)
                    self.scheduled_holds.append(hold * 1000)
                    heapq.heappush(self.queue, (received + hold, serial, received, target, destination, data, direction))
            now = time.monotonic()
            while self.queue and self.queue[0][0] <= now:
                _, _, received, sock, address, data, direction = heapq.heappop(self.queue)
                sock.sendto(data, address)
                self.holds.append((time.monotonic() - received) * 1000)
                self.counts[direction] += 1

    def close(self):
        self.stop.set()
        self.thread.join(2)
        for sock in (self.front, self.back):
            sock.close()
        self.selector.close()


def stats(values):
    ordered = sorted(values)
    return {'n': len(values), 'min': min(values), 'median': statistics.median(values),
            'p95': ordered[min(len(values) - 1, int(len(values) * .95))],
            'max': max(values), 'stdev': statistics.pstdev(values)}


def wait_marker(process, path, marker, timeout=15):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if marker in path.read_text():
            return
        if process.poll() is not None:
            break
        time.sleep(.05)
    raise RuntimeError(f'Missing {marker}: {path}')


def run_case(args, delay, out):
    out.mkdir(parents=True, exist_ok=True)
    processes, handles, proxies = [], [], []
    telemetry = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    telemetry.bind(('127.0.0.1', 0))
    telemetry.settimeout(.1)
    events, telemetry_errors = [], []
    telemetry_stop = threading.Event()

    def receive():
        while not telemetry_stop.is_set():
            try:
                data, _ = telemetry.recvfrom(65535)
                stamp = time.monotonic()
                events.append({**json.loads(data), 'time': stamp})
            except socket.timeout:
                continue
            except Exception as error:
                telemetry_errors.append(str(error))
                return

    receiver = threading.Thread(target=receive, daemon=True)
    receiver.start()
    try:
        # Reserve a distinct ephemeral loopback port before starting Godot.
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reserve:
            reserve.bind(('127.0.0.1', 0))
            port = reserve.getsockname()[1]

        def launch(role, network):
            path = out / f'{role}.log'
            handle = path.open('w')
            handles.append(handle)
            command = [args.godot, '--headless', '--path', str(ROOT), '--script',
                       'res://tests/movement_latency_peer.gd', '--', f'--role={role}',
                       f'--trials={args.trials}', f'--patterns={",".join(args.patterns)}',
                       f'--telemetry-port={telemetry.getsockname()[1]}', *network]
            process = subprocess.Popen(command, stdout=handle, stderr=subprocess.STDOUT)
            processes.append(process)
            return process, path

        server, log = launch('server', [f'--server-port={port}'])
        wait_marker(server, log, 'DEDICATED_SERVER_READY')
        for role in ('owner', 'guest'):
            proxy = DelayProxy(port, delay, args.jitter_ms, args.loss_every)
            proxies.append(proxy)
            client, log = launch(role, ['--join-address=127.0.0.1', f'--join-port={proxy.front.getsockname()[1]}'])
            wait_marker(client, log, f'LATENCY_CONNECTED {role}')
        deadline = time.monotonic() + args.trials * 4 + 60
        while any(process.poll() is None for process in processes):
            if any(process.poll() not in (None, 0) for process in processes):
                raise RuntimeError(f'Peer failed; see {out}')
            if time.monotonic() >= deadline:
                raise RuntimeError(f'Peer timeout; see {out}')
            time.sleep(.05)
        telemetry_stop.set()
        receiver.join(2)
        if telemetry_errors or receiver.is_alive():
            raise RuntimeError(f'Telemetry receiver failed: {telemetry_errors}')
        (out / 'telemetry.json').write_text(json.dumps(events) + '\n')
        result = {'added_rtt_ms': delay, 'one_way_jitter_ms': args.jitter_ms,
                  'loss_every': args.loss_every,
                  'patterns': args.patterns, 'clock': 'Python time.monotonic; undelayed local telemetry receipt',
                  'clients': {}, 'proxy': {}}
        for role, process in zip(('server', 'owner', 'guest'), processes):
            text = (out / f'{role}.log').read_text()
            errors = [line for line in text.splitlines() if re.match(r'^(SCRIPT ERROR|ERROR):', line)
                      and not re.match(r'^ERROR: \d+ resources still in use at exit', line)]
            if process.returncode or f'LATENCY_OK {role}' not in text or errors:
                raise RuntimeError(f'{role} failed: {errors}; see {out}')
            measurements = [json.loads(line.removeprefix('MEASUREMENT '))
                            for line in text.splitlines() if line.startswith('MEASUREMENT ')]
            if len(measurements) != 1:
                raise RuntimeError(f'{role}: missing unique measurement')
            record = measurements[0]
            if role == 'server':
                result['server'] = record
            else:
                role_events = [event for event in events if event['role'] == role]

                def event_time(kind, key):
                    matches = [event['time'] for event in role_events if event['event'] == kind and event['key'] == key]
                    if len(matches) != 1:
                        raise RuntimeError(f'{role}: expected one {kind}/{key}, got {len(matches)}')
                    return matches[0]

                for trial in record['trials']:
                    trial['latency_ms'] = (event_time('motion', trial['trial']) - event_time('input', trial['trial'])) * 1000
                    trial['input_duration_ms'] = (event_time('release', trial['trial']) - event_time('input', trial['trial'])) * 1000
                rtts = [(event['time'] - event_time('probe', event['key'])) * 1000
                        for event in role_events if event['event'] == 'echo']
                first_input = event_time('input', 0)
                arrivals = [event['time'] for event in role_events
                            if event['event'] == 'snapshot' and event['time'] >= first_input]
                gaps = [(second - first) * 1000 for first, second in zip(arrivals, arrivals[1:])]
                if len(rtts) < args.trials - 1 or len(arrivals) < 100:
                    raise RuntimeError(f'{role}: insufficient external telemetry')
                result['clients'][role] = {'latency_ms': stats([t['latency_ms'] for t in record['trials']]),
                                           'rtt_ms': stats(rtts),
                                           'ticks_rtt_ms': stats(record['ticks_rtt_ms']),
                                           'snapshot_gap_ms': stats(gaps),
                                           'trials': record['trials'], 'observed_travel_m': record['observed_travel_m'],
                                           'correction_m': stats(record['corrections_m']),
                                           'traversal': record.get('traversal', []),
                                           'max_camera_error_rad': record['max_camera_error_rad']}
                if min(rtts) < max(0, delay - 2 * args.jitter_ms) - 1:
                    raise RuntimeError(f'{role}: RTT shorter than injected hold; check clocks/proxy')
        for role, proxy in zip(('owner', 'guest'), proxies):
            if proxy.error is not None or not proxy.thread.is_alive():
                raise RuntimeError(f'{role} proxy failed: {proxy.error}')
            result['proxy'][role] = {'one_way_hold_ms': stats(proxy.holds),
                                     'scheduled_one_way_hold_ms': stats(proxy.scheduled_holds),
                                     'received_each_direction': proxy.received_counts,
                                     'dropped_each_direction': proxy.dropped_counts,
                                     'datagrams_each_direction': proxy.counts}
        result['response_bound_ms'] = args.max_response_ms
        result['response_bound_passed'] = (None if args.max_response_ms is None else
                                          all(client['latency_ms']['max'] <= args.max_response_ms
                                              for client in result['clients'].values()))
        (out / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        return result
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
        for process in processes:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        for proxy in proxies:
            proxy.close()
        telemetry_stop.set()
        receiver.join(2)
        telemetry.close()
        for handle in handles:
            handle.close()
        (out / 'telemetry.json').write_text(json.dumps(events) + '\n')
        traces = []
        for role in ('owner', 'guest'):
            path = out / f'{role}.log'
            if path.exists():
                traces.extend({'role': role, **json.loads(line.removeprefix('TRAVERSAL '))}
                              for line in path.read_text().splitlines() if line.startswith('TRAVERSAL '))
        (out / 'traversal.json').write_text(json.dumps(traces, indent=2) + '\n')
        (out / 'proxy.json').write_text(json.dumps([
            {'received': proxy.received_counts, 'forwarded': proxy.counts,
             'dropped': proxy.dropped_counts, 'loss_every': proxy.loss_every,
             'error': str(proxy.error) if proxy.error else None} for proxy in proxies], indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
    parser.add_argument('--trials', type=int, default=6)
    parser.add_argument('--delays', nargs='+', type=float, default=[0, 100, 200])
    parser.add_argument('--jitter-ms', type=float, default=0, help='One-way -N/0/+N ms cycle')
    parser.add_argument('--loss-every', type=int, default=0, help='Drop every Nth datagram per direction; 0 disables')
    parser.add_argument('--patterns', nargs='+', choices=['walk', 'sprint', 'reversal'], default=['walk', 'sprint', 'reversal'])
    parser.add_argument('--output', type=Path, default=ROOT / '.amp/in/artifacts/movement-latency')
    parser.add_argument('--max-response-ms', type=float)
    args = parser.parse_args()
    if args.loss_every < 0 or args.loss_every == 1:
        parser.error('Loss interval must be 0 or >=2')
    if args.trials < 2 or any(delay < 0 or delay > 300 for delay in args.delays):
        parser.error('Use >=2 trials and added RTT in 0..300ms')
    if not 0 <= args.jitter_ms <= 100 or args.trials < len(args.patterns):
        parser.error('Use jitter in 0..100ms and at least one trial per pattern')
    results, failures = [], []
    for delay in args.delays:
        try:
            results.append(run_case(args, delay, args.output / f'added-{delay:g}ms'))
        except (RuntimeError, subprocess.TimeoutExpired) as error:
            failure = {'added_rtt_ms': delay, 'error': str(error)}
            failures.append(failure)
            print(failure, flush=True)
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / 'summary.json').write_text(json.dumps(results, indent=2) + '\n')
    (args.output / 'failures.json').write_text(json.dumps(failures, indent=2) + '\n')
    for result in results:
        for role, client in result['clients'].items():
            print(f"added={result['added_rtt_ms']:g}ms {role}: latency={client['latency_ms']['median']:.2f}ms "
                  f"RTT={client['rtt_ms']['median']:.2f}ms gap={client['snapshot_gap_ms']['median']:.2f}ms "
                  f"gap_jitter_sd={client['snapshot_gap_ms']['stdev']:.2f}ms "
                  f"correction_p95={client['correction_m']['p95']:.3f}m max={client['correction_m']['max']:.3f}m")
    if failures:
        raise SystemExit('MOVEMENT_LATENCY_FAILED (all requested cases attempted; evidence retained)')
    if any(result['response_bound_passed'] is False for result in results):
        raise SystemExit('MOVEMENT_LATENCY_RESPONSE_BOUND_FAILED (measurements retained)')
    print('MOVEMENT_LATENCY_OK measurement-only' if args.max_response_ms is None else 'MOVEMENT_LATENCY_OK response-bound')


if __name__ == '__main__':
    main()
