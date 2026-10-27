#!/usr/bin/env python3
import sys
import subprocess
import colorsys
from pathlib import Path

PAPIRUS_COLORS = {
    "adwaita":    "#93c0ea",
    "black":      "#4f4f4f",
    "blue":       "#2b6be6",  # Anchored closer to true blue
    "bluegrey":   "#607d8b",
    "breeze":     "#57b8ec",
    "brown":      "#ae8e6c",
    "carmine":    "#a30002",
    "cyan":       "#00bcd4",
    "darkcyan":   "#45abb7",
    "deeporange": "#eb6637",
    "green":      "#87b158",
    "grey":       "#8e8e8e",
    "indigo":     "#5c6bc0",
    "magenta":    "#ca71df",
    "nordic":     "#81a1c1",
    "orange":     "#ee923a",
    "palebrown":  "#d1bfae",
    "paleorange": "#eeca8f",
    "pink":       "#f06292",
    "red":        "#e25252",
    "teal":       "#16a085",
    "violet":     "#7e57c2",
    "white":      "#e4e4e4",
    "yaru":       "#676767",
    "yellow":     "#f9bd30",
}

ACHROMATIC = {"black", "yaru", "grey", "white"}
STATE_FILE = Path.home() / ".cache" / "matugen" / "last_papirus_color"

def hex_to_hsv(hex_str: str) -> tuple[float, float, float]:
    hex_str = hex_str.strip().lstrip("#")
    if len(hex_str) == 3:
        hex_str = "".join(c * 2 for c in hex_str)
    r, g, b = (int(hex_str[i:i+2], 16) / 255.0 for i in (0, 2, 4))
    return colorsys.rgb_to_hsv(r, g, b)

def closest_papirus_color(target_hex: str) -> str:
    h1, s1, v1 = hex_to_hsv(target_hex)

    if s1 < 0.12 or v1 < 0.15:
        return min(
            ACHROMATIC,
            key=lambda name: abs(v1 - hex_to_hsv(PAPIRUS_COLORS[name])[2])
        )

    best_name = None
    min_dist = float("inf")

    for name, hex_val in PAPIRUS_COLORS.items():
        if name in ACHROMATIC:
            continue
        h2, s2, v2 = hex_to_hsv(hex_val)
        dh = min(abs(h1 - h2), 1.0 - abs(h1 - h2)) * 2.0
        ds = abs(s1 - s2)
        dv = abs(v1 - v2)

        dist = (dh * 4.5) ** 2 + (ds * 1.2) ** 2 + (dv * 1.2) ** 2
        if dist < min_dist:
            min_dist = dist
            best_name = name

    return best_name

if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(1)

    hex_input = sys.argv[1].strip()
    # Read from file if a path was passed instead of a raw hex string
    if Path(hex_input).is_file():
        hex_input = Path(hex_input).read_text().strip()

    folder_color = closest_papirus_color(hex_input)

    # Skip running papirus-folders if it's already set to this color
    if STATE_FILE.is_file() and STATE_FILE.read_text().strip() == folder_color:
        print(f"Papirus folders already set to '{folder_color}', skipping.")
        sys.exit(0)

    print(f"Applying Papirus folder color: {folder_color} (from {hex_input})")
    subprocess.run(["pkexec", "/usr/bin/papirus-folders", "-C", folder_color, "--theme", "Papirus-Dark"], check=False)

    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(folder_color)
