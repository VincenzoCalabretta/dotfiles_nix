#!/usr/bin/env python3
"""Switch the active X output to another connected display.

Behaviour:
  * Exactly two connected outputs: switch straight to the non-primary one.
  * More than two: pick the target interactively with fzf.
  * The chosen output is enabled at its highest resolution and refresh rate,
    marked --primary, and every other connected output is turned off.
"""

import re
import shutil
import subprocess
import sys


def run_xrandr(*args):
    return subprocess.run(
        ["xrandr", *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
        check=False,
    )


def get_connected_displays():
    """Return (list of (name, is_primary), raw xrandr output)."""
    result = run_xrandr()
    displays = []
    for line in result.stdout.splitlines():
        if " connected" in line:
            name = line.split()[0]
            is_primary = " primary " in line
            displays.append((name, is_primary))
    return displays, result.stdout


def get_best_mode(display_name, xrandr_output):
    """Return (resolution, refresh_str) with the highest pixels then refresh."""
    in_section = False
    best = None  # (pixels, refresh, resolution_str, refresh_str)

    for line in xrandr_output.splitlines():
        if not line:
            continue
        if not line[0].isspace():
            in_section = line.startswith(display_name + " ")
            continue
        if not in_section:
            continue

        m = re.match(r"\s+(\d+)x(\d+)i?\s+(.+)", line)
        if not m:
            continue
        width, height = int(m.group(1)), int(m.group(2))
        pixels = width * height
        for rate_str in re.findall(r"\d+\.\d+|\d+", m.group(3)):
            try:
                rate = float(rate_str)
            except ValueError:
                continue
            candidate = (pixels, rate, f"{width}x{height}", rate_str)
            if best is None or (candidate[0], candidate[1]) > (best[0], best[1]):
                best = candidate

    if best is None:
        return None
    return best[2], best[3]


def pick_display(candidates):
    """Interactively pick one of `candidates` using fzf, else a numbered prompt."""
    fzf = shutil.which("fzf")
    if fzf and sys.stdin.isatty():
        result = subprocess.run(
            [fzf, "--prompt=Switch to display> ", "--height=100%", "--no-multi"],
            input="\n".join(candidates),
            stdout=subprocess.PIPE,
            universal_newlines=True,
        )
        if result.returncode != 0:
            return None
        choice = result.stdout.strip()
        return choice or None

    for i, name in enumerate(candidates, 1):
        print(f"  {i}) {name}")
    try:
        raw = input("Pick a display: ").strip()
    except (EOFError, KeyboardInterrupt):
        return None
    try:
        idx = int(raw) - 1
    except ValueError:
        return None
    if 0 <= idx < len(candidates):
        return candidates[idx]
    return None


def switch_to(target, all_displays, xrandr_output):
    mode = get_best_mode(target, xrandr_output)
    if mode is None:
        print(f"Could not determine any mode for {target}.", file=sys.stderr)
        return 1
    resolution, refresh = mode

    for name, _ in all_displays:
        if name != target:
            run_xrandr("--output", name, "--off")

    result = run_xrandr(
        "--output", target,
        "--mode", resolution,
        "--rate", refresh,
        "--primary",
    )
    if result.returncode != 0:
        print(result.stderr.strip() or "xrandr failed", file=sys.stderr)
        return result.returncode

    print(f"Switched to {target} at {resolution} @ {refresh}Hz")
    return 0


def main():
    displays, xrandr_output = get_connected_displays()
    if len(displays) < 2:
        print("Fewer than two connected displays; nothing to switch to.", file=sys.stderr)
        return 1

    primary = next((name for name, is_primary in displays if is_primary), None)
    if primary is None:
        primary = displays[0][0]
    candidates = [name for name, _ in displays if name != primary]

    if len(candidates) == 1:
        target = candidates[0]
    else:
        target = pick_display(candidates)
        if target is None:
            print("No display selected.", file=sys.stderr)
            return 1

    return switch_to(target, displays, xrandr_output)


if __name__ == "__main__":
    sys.exit(main())
