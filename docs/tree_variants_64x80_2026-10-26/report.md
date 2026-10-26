# Tree variants — Unzoom and 64x80 preparation

First verified the previously saved building PNGs and packaged 44 task-produced building images into docs/buildings_saved_2026-10-26.zip (original art-pack files excluded). Existing images unchanged.

Source tree sheet: user clipboard image, 1376x768, a 4x2 grid of 344x384 cells. Cells cropped without resizing and each processed once with PixelLab unzoom_image, quantize=-1. Output grids 58–60x66. Eight calls, 0.1 generation each, actual balance 32.80 -> 32.00. No AI-generated replacement tree imagery.

Used free PixelLab pixelart_workbench operations to select neutral grey sheet background with RGB tolerance 12 and erase it, preserving darker ground shadows. Removed the cactus's separate decorative sparkle. Used draw/copy to place original recovered tree pixels onto transparent 64x80 canvases; no scaling, stretching or palette quantization. Offsets and estimated trunk-root baseline y=70 recorded in placement.json. The baseline was estimated from lower central trunk pixels, not in-engine collision calibration. Light fringes or other source artifacts may remain.

Eight separate RGBA PNGs verified exactly 64x80 with transparent exterior and no nontransparent pixel touching the canvas edge. Contact sheet reviewed at 3x nearest-neighbour. Ground shadows remain in the images and are currently opaque grey, not separate shadow layers. Source contains more than 256 colours after anti-aliased art/grid recovery, so PNGs were retained without lossy GIF conversion.

Files: assets/Trees/Variants64x80/{autumn_maple,spruce,willow,pink_blossom,golden_birch,palm,magic_blue,flowering_cactus}.png. Sheet trees_sheet_4x2.png: 256x160, 64x80 per cell. Zip: trees_64x80.zip. No existing tree definitions, shaders, collisions or game scenes changed.
