#!/usr/bin/env python3
import subprocess
import re

def get_connected_displays():
    """Get a list of connected displays with `xrandr` and identify the primary display."""
    xrandr_output = subprocess.run(["xrandr"], stdout=subprocess.PIPE, universal_newlines=True)
    connected_displays = []

    for line in xrandr_output.stdout.splitlines():
        if " connected" in line:
            display_name = line.split()[0]
            is_primary = "primary" in line
            connected_displays.append((display_name, is_primary))

    return connected_displays, xrandr_output.stdout

def get_max_resolution_and_refresh(display_name, xrandr_output):
    """Parse xrandr output to find the max resolution and refresh rate for the given display."""
    lines = xrandr_output.splitlines()
    display_section = []
    capture = False

    for line in lines:
        if line.startswith(display_name):
            capture = True
            continue
        elif capture and not line.startswith(' '):
            break
        elif capture:
            display_section.append(line.strip())

    max_mode = None
    max_pixels = 0
    max_refresh = 0.0

    for line in display_section:
        match = re.match(r"(\d+)x(\d+)\s+([\d.]+)\*?\+?", line)
        if match:
            width, height, refresh = match.groups()
            width, height, refresh = int(width), int(height), float(refresh)
            pixels = width * height
            if (pixels > max_pixels) or (pixels == max_pixels and refresh > max_refresh):
                max_pixels = pixels
                max_refresh = refresh
                max_mode = (f"{width}x{height}", f"{refresh}")

    return max_mode

def toggle_displays():
    """Disable primary display and enable the secondary display with max resolution and refresh."""
    (displays, xrandr_output) = get_connected_displays()

    if len(displays) < 2:
        print("At least two monitors need to be connected to toggle displays.")
        return

    primary_display = None
    secondary_display = None

    for display, is_primary in displays:
        if is_primary:
            primary_display = display
        else:
            secondary_display = display

    if primary_display and secondary_display:
        # Get max resolution and refresh rate for the secondary display
        mode = get_max_resolution_and_refresh(secondary_display, xrandr_output)
        if mode:
            resolution, refresh = mode
            subprocess.run(["xrandr", "--output", primary_display, "--off"])
            subprocess.run([
                "xrandr", "--output", secondary_display,
                "--mode", resolution,
                "--rate", refresh,
                "--primary"
            ])
            print(f"Switched to {secondary_display} with resolution {resolution} @ {refresh}Hz.")
        else:
            print(f"Could not determine best mode for {secondary_display}.")
    else:
        print("Couldn't identify primary and secondary displays.")

if __name__ == "__main__":
    toggle_displays()
