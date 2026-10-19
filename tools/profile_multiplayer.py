#!/usr/bin/env python3
"""Bounded local solo/multiclient profiler; no public service or deployment access."""
import argparse
from contextlib import ExitStack
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import shutil
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
PEER = ROOT / "tools/profile_multiplayer_peer.gd"


def summarize(trace):
    """Keep temporal order in raw traces; sort copies only for percentiles."""
    samples = trace["samples"]
    frames = sorted(row["frame_ms"] for row in samples)
    def percentile(fraction):
        return frames[max(0, math.ceil(len(frames) * fraction) - 1)]
    duration = sum(frames) / 1000
    return {"frames": len(frames), "duration_s": duration,
            "p50_ms": percentile(.50), "p95_ms": percentile(.95), "p99_ms": percentile(.99),
            "hitches_over_33ms": sum(value > 1000 / 30 for value in frames),
            "hitches_over_50ms": sum(value > 50 for value in frames),
            "physics_ticks": sum(row["physics_ticks"] for row in samples),
            "physics_ticks_per_s": sum(row["physics_ticks"] for row in samples) / duration,
            # Sequence deltas are observed progress, NOT packet loss or RPC counts.
            "observed_match_sequence_delta": samples[-1]["match_sequence"] - samples[0]["match_sequence"],
            "observed_ack_sequence_delta": samples[-1]["ack_sequence"] - samples[0]["ack_sequence"]}


def authoritative_movement_summary(server_trace, moving_peer_id):
    """Summarize server-observed horizontal travel, not gravity or packet loss."""
    positions = []
    for row in server_trace["samples"]:
        position = row["authoritative_player_positions"].get(str(moving_peer_id))
        if position is not None:
            positions.append([position[0], position[2]])
    if len(positions) < 2:
        raise RuntimeError("Missing authoritative positions for the moving client")
    origin = positions[0]
    distances = [math.dist(origin, position) for position in positions]
    travel = sum(math.dist(previous, current) for previous, current in zip(positions, positions[1:]))
    return {"peer_id": moving_peer_id, "authoritative_travel_m": travel,
            "authoritative_max_displacement_m": max(distances), "samples": len(positions)}


def parser():
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--engine", default=os.environ.get("GODOT_BIN", shutil.which("godot")))
    result.add_argument("--pack", type=Path, help="Exported PCK measured with editor engine, NOT a release-template benchmark")
    result.add_argument("--output", required=True, type=Path, help="Fresh result directory")
    result.add_argument("--scenario", choices=("solo", "network"), default="network")
    result.add_argument("--clients", type=int, choices=(2, 4, 8, 20), default=2, help="Real network clients; solo always has one")
    result.add_argument("--renderers", type=int, choices=(0, 1, 2, 3, 4), default=2)
    result.add_argument("--map", choices=("toy_town", "toy_harbor"), default="toy_town")
    result.add_argument("--width", type=int, default=1280)
    result.add_argument("--height", type=int, default=720)
    result.add_argument("--warmup", type=int, default=120)
    result.add_argument("--samples", type=int, default=600)
    result.add_argument("--repeats", type=int, default=3)
    result.add_argument("--fps", type=int, default=0)
    result.add_argument("--vsync", choices=("default", "off", "on"), default="off")
    result.add_argument("--ablation", choices=("none", "shadows-off", "no-3d"), default="none")
    result.add_argument("--moving-client", action="store_true", help="Opt in to bounded real strafe input for client-0; default is stationary")
    result.add_argument("--timeout", type=float, default=1800, help="Sampling deadline; setup stages are limited to at most60s, never retries")
    result.add_argument("--xvfb", action="store_true", help="Separate Linux virtual displays; NOT same-desktop focus validation")
    return result


def run(options):
    if not options.engine:
        raise ValueError("Set --engine or GODOT_BIN to the Godot4.7.2 editor executable")
    if min(options.width, options.height, options.samples, options.repeats) <= 0 or min(options.warmup, options.fps) < 0 or options.timeout <= 0:
        raise ValueError("Positive resolution/samples/repeats/timeout and nonnegative warmup/FPS required")
    network = options.scenario == "network"
    player_count = options.clients if network else 1
    if options.renderers > player_count:
        raise ValueError("Renderer count cannot exceed the real client count; solo needs --renderers 0 or 1")
    if not network and options.clients != 2:
        raise ValueError("--clients applies only to --scenario network")
    if options.moving_client and options.scenario != "network":
        raise ValueError("--moving-client requires --scenario network")
    if options.xvfb and not shutil.which("Xvfb"):
        raise ValueError("--xvfb requires installed Xvfb")
    engine = str(Path(shutil.which(options.engine) or options.engine).resolve())
    help_text = subprocess.run([engine, "--help"], capture_output=True, text=True, check=True, timeout=10).stdout
    if "--script " not in help_text:
        raise ValueError("This binary cannot run an external --script driver. Official release templates ignore it; use the editor engine with --pack. That is not standalone performance proof.")
    version = subprocess.run([engine, "--version"], capture_output=True, text=True, check=True, timeout=10).stdout.strip()
    if version != "4.7.2.stable.official.ed1daf0bf":
        raise ValueError("Profiler requires the repository's pinned Godot4.7.2 official engine")
    pack = options.pack.resolve() if options.pack else None
    if pack and not pack.is_file():
        raise ValueError("PCK not found")
    output = options.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    metadata = dict(vars(options), engine=engine, pack=str(pack) if pack else None,
                    engine_version=version, mode="exported_pack_editor_engine" if pack else "source_editor_engine",
                    output=str(output), os=platform.platform(), cpu=platform.processor() or "unknown",
                    logical_cpus_reported=os.cpu_count(), monitor_refresh_hz="not collected",
                    render_scale="project default", LP_NUM_THREADS=os.environ.get("LP_NUM_THREADS", "unset"),
                    transport="local direct-IP dedicated ENet; no HTTP allocator" if network else "offline solo",
                    actual_player_count=player_count,
                    admission_rendering="disabled until sampling", audio="Dummy", moving_players=options.moving_client,
                    movement_scenario="stationary by default; --moving-client sends bounded alternating strafe Input actions on safe spawn ground",
                    reconciliation_measurement="No profiler hook observes snapshot receipt/reconcile boundaries; pending snapshot age and correction distance are intentionally not inferred.",
                    thermal_sensors="not collected", gpu_power="not collected",
                    sample_start="per-process warmup; not a synchronized barrier")
    if pack:
        metadata["pack_sha256"] = hashlib.sha256(pack.read_bytes()).hexdigest()
    (output / "metadata.json").write_text(json.dumps(metadata, indent=2))
    processes = {}
    sequences = {}
    with tempfile.TemporaryDirectory(prefix="disaster-profile-") as directory, ExitStack() as stack:
        control = Path(directory)
        # The socket is only a free-port hint; bind failures remain fatal, never retry silently.
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
            reservation.bind(("127.0.0.1", 0))
            port = reservation.getsockname()[1]

        def read(label):
            path = control / (label + ".json")
            return json.loads(path.read_text()) if path.exists() else {}

        def wait(predicate, stage, timeout=None):
            deadline = time.monotonic() + (min(options.timeout, 60) if timeout is None else timeout)
            while not predicate():
                if any(peer.poll() is not None for peer in processes.values()):
                    raise RuntimeError(f"Peer exited during {stage}; inspect {output}")
                if time.monotonic() >= deadline:
                    raise TimeoutError(f"Deadline during {stage}; inspect {output}")
                time.sleep(.05)

        def command(label, action, **data):
            sequences[label] = sequences.get(label, 0) + 1
            path = control / (label + ".command")
            temporary = path.with_suffix(".tmp")
            temporary.write_text(json.dumps(dict(action=action, sequence=sequences[label], **data)))
            temporary.replace(path)
            if action != "quit":
                wait(lambda: read(label).get("sequence") == sequences[label], action + ":" + label)

        def stop(peer):
            if peer.poll() is None:
                peer.terminate()
                try:
                    peer.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    peer.kill()
                    peer.wait()

        def launch(label, graphical=False, extra=()):
            log = stack.enter_context((output / (label + ".log")).open("w"))
            environment = dict(os.environ)
            if graphical and options.xvfb:
                # -displayfd allocates a free display, unlike fixed display numbers.
                display_file = control / (label + ".display")
                with display_file.open("w") as display_output:
                    display = subprocess.Popen(["Xvfb", "-displayfd", str(display_output.fileno()),
                                                "-screen", "0", f"{options.width}x{options.height}x24"],
                                               pass_fds=(display_output.fileno(),), stdout=log, stderr=log)
                stack.callback(stop, display)
                wait(lambda: display_file.stat().st_size > 0 or display.poll() is not None, "Xvfb")
                if display.poll() is not None:
                    raise RuntimeError("Xvfb exited")
                environment["DISPLAY"] = ":" + display_file.read_text().strip()
            args = [engine]
            if pack:
                args += ["--main-pack", str(pack)]
            else:
                args += ["--path", str(ROOT)]
            if not graphical:
                args += ["--headless"]
            args += ["--audio-driver", "Dummy", "--resolution", f"{options.width}x{options.height}",
                     "--script", str(PEER), "--", f"--profile-control={control}",
                     f"--profile-label={label}", f"--settings-path={control / (label + '.cfg')}", *extra]
            peer = subprocess.Popen(args, cwd=pack.parent if pack else ROOT, env=environment, stdout=log, stderr=log)
            processes[label] = peer
            stack.callback(stop, peer)
            wait(lambda: bool(read(label)), "startup:" + label)

        labels = [f"client-{index}" for index in range(player_count)]
        if network:
            launch("server", extra=(f"--server-port={port}",))
        for index, label in enumerate(labels):
            launch(label, index < options.renderers,
                   ("--join-address=127.0.0.1", f"--join-port={port}") if network else ())
            if network:
                wait(lambda: read(label).get("owner", 0) > 1, "admission:" + label)
        all_labels = [*labels, "server"] if network else labels
        command(labels[0], "map", map_id=options.map)
        wait(lambda: all(read(label).get("map_id") == options.map for label in all_labels), "map agreement")
        if network:
            wait(lambda: all(read(label).get("players") == player_count for label in all_labels), "roster agreement")
            for label in labels:
                command(label, "ready")
            wait(lambda: all(read(label).get("can_start") for label in all_labels), "Ready at every peer")
            command(labels[0], "start")
        else:
            command(labels[0], "solo")
        wait(lambda: all(read(label).get("state") == 1 for label in all_labels), "ACTIVE")
        command("server" if network else labels[0], "cleanup")
        summaries = []
        for repeat in range(options.repeats):
            for label in all_labels:
                command(label, "sample", warmup=options.warmup, samples=options.samples,
                        fps=options.fps, vsync=options.vsync, ablation=options.ablation,
                        moving_client=options.moving_client)
            wait(lambda: all(read(label).get("complete") for label in all_labels), "frame samples", options.timeout)
            for label in all_labels:
                trace = json.loads((control / (label + ".trace.json")).read_text())
                if trace["sequence"] != sequences[label] or len(trace["samples"]) != options.samples:
                    raise RuntimeError("Stale or incomplete trace")
                if any(row["state"] != 1 or row["players"] != len(labels) for row in trace["samples"]):
                    raise RuntimeError("Match/roster changed during trace")
                if any(row["removed_district_mask"] != 0 or row["pending_district"] != -1 for row in trace["samples"]):
                    raise RuntimeError("Dry world changed during trace; cannot compare rendering cost")
                (output / f"{repeat}-{label}.json").write_text(json.dumps(trace))
                summaries.append(dict(repeat=repeat, peer=label, **summarize(trace)))
            if options.moving_client:
                client_trace = json.loads((control / "client-0.trace.json").read_text())
                server_trace = json.loads((control / "server.trace.json").read_text())
                movement = authoritative_movement_summary(server_trace, client_trace["local_peer_id"])
                if movement["authoritative_max_displacement_m"] <= 0.5:
                    raise RuntimeError("Controlled input did not move the authoritative client position")
                summaries[-1]["moving_client_authoritative"] = movement
            (output / "summary.json").write_text(json.dumps(summaries, indent=2))
        # Close clients first so authority can process departures before its own shutdown.
        for label in all_labels:
            command(label, "quit")
            processes[label].wait(timeout=15)
            if processes[label].returncode:
                raise RuntimeError("Nonzero peer shutdown: " + label)
    for label in all_labels:
        lines = (output / (label + ".log")).read_text().splitlines()
        errors = [line for line in lines if line.startswith(("SCRIPT ERROR:", "ERROR:"))]
        if errors or f"MULTIPLAYER_PROFILE_PEER_OK label={label}" not in lines:
            raise RuntimeError(f"Runtime/log gate failed for {label}; inspect {output}")
    print(f"MULTIPLAYER_PROFILE_OK scenario={options.scenario} clients={player_count} renderers={options.renderers} repeats={options.repeats} samples={options.samples} output={output}")


if __name__ == "__main__":
    run(parser().parse_args())
