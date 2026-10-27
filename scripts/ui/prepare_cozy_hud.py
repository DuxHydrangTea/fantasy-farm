"""Normalize PixelLab Unzoom HUD drafts into a shared, exact nine-slice kit.

Run from the project root: python3 scripts/ui/prepare_cozy_hud.py
Unzoom sources are kept in docs/hud_assets_2026-10-27/unzoom.
The normal slot is the canonical frame; other drafts supply proportions only.
"""

from collections import deque
from pathlib import Path
import json

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "docs/hud_assets_2026-10-27/unzoom"
OUTPUT = ROOT / "assets/Ui/CozyHUD"
MARGIN = 8
PALETTE = [
    "#401c10", "#542f1d", "#88593d", "#976446", "#ab7251",
    "#c19672", "#d0a984", "#e6c4a0", "#fcefda",
    "#6f8555", "#c2ce9b", "#e29a44", "#fde76e", "#89a76c",
]


def cutout(image):
    """Remove only edge-connected near-white; keep the ivory interior."""
    image = image.convert("RGBA")
    pixels = image.load()
    pending = deque()
    seen = set()
    for x in range(image.width):
        pending.extend(((x, 0), (x, image.height - 1)))
    for y in range(image.height):
        pending.extend(((0, y), (image.width - 1, y)))
    while pending:
        x, y = pending.popleft()
        if (x, y) in seen or not (0 <= x < image.width and 0 <= y < image.height):
            continue
        seen.add((x, y))
        if min(pixels[x, y][:3]) < 245:
            continue
        pixels[x, y] = (0, 0, 0, 0)
        pending.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))
    return image


def normalize_palette(image):
    colors = [tuple(bytes.fromhex(value[1:])) for value in PALETTE]
    output = Image.new("RGBA", image.size)
    for y in range(image.height):
        for x in range(image.width):
            rgba = image.getpixel((x, y))
            if rgba[3] == 0:
                continue
            nearest = min(colors, key=lambda rgb: sum((a - b) ** 2 for a, b in zip(rgb, rgba[:3])))
            output.putpixel((x, y), (*nearest, 255))
    return output


def frame(source, width, height):
    """Keep corners exact and repeat single-pixel edge strips: no interpolation."""
    m = MARGIN
    sw, sh = source.size
    result = Image.new("RGBA", (width, height), "#fcefda")
    for sx, sy, dx, dy in [
        (0, 0, 0, 0), (sw - m, 0, width - m, 0),
        (0, sh - m, 0, height - m), (sw - m, sh - m, width - m, height - m),
    ]:
        result.paste(source.crop((sx, sy, sx + m, sy + m)), (dx, dy))
    # A constant cross-section prevents stretched gradients and visible seams.
    for src, dest, size in [
        ((sw // 2, 0, sw // 2 + 1, m), (m, 0), (width - 2 * m, m)),
        ((sw // 2, sh - m, sw // 2 + 1, sh), (m, height - m), (width - 2 * m, m)),
        ((0, sh // 2, m, sh // 2 + 1), (0, m), (m, height - 2 * m)),
        ((sw - m, sh // 2, sw, sh // 2 + 1), (width - m, m), (m, height - 2 * m)),
    ]:
        result.paste(source.crop(src).resize(size, Image.Resampling.NEAREST), dest)
    return result


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    sheet = normalize_palette(cutout(Image.open(SOURCE / "slots.png")))
    # Exact detected native-grid regions of the two frames in the 125x63 result.
    normal = sheet.crop((15, 10, 60, 53))
    selected = sheet.crop((65, 10, 110, 53))
    # Both states must have identical silhouette and alignment.
    selected.putalpha(normal.getchannel("A"))
    specifications = [
        ("slot_normal", normal, 32, 32),
        ("slot_selected", selected, 32, 32),
        ("hotbar", normal, 240, 48),
        ("wallet", normal, 96, 32),
        ("weather", normal, 112, 32),
        ("button_primary", normal, 32, 32),
    ]
    report = {"palette": PALETTE, "texture_margin": MARGIN, "assets": {}}
    for name, source, width, height in specifications:
        image = frame(source, width, height)
        if name == "button_primary":
            for y in range(MARGIN, height - MARGIN):
                for x in range(MARGIN, width - MARGIN):
                    image.putpixel((x, y), (137, 167, 108, 255))
        image.save(OUTPUT / (name + ".png"))
        colors = set(image.get_flattened_data())
        assert {rgba[3] for rgba in colors} == {0, 255}
        assert len(colors) <= len(PALETTE) + 1
        report["assets"][name] = {"size": [width, height], "colors": len(colors), "alpha": "binary"}
    a = Image.open(OUTPUT / "slot_normal.png").getchannel("A")
    b = Image.open(OUTPUT / "slot_selected.png").getchannel("A")
    assert a.tobytes() == b.tobytes()
    (ROOT / "docs/hud_assets_2026-10-27/asset-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
