# Seven tree variants from 2K source

Source: /home/dungnguyen/Downloads/Create_pixel_art_tree_variations_2K_20261026131740.jpg (2752x1536). Cropped only 24 bottom margin rows to fit PixelLab area limit; Unzoom output 473x260, quantize=-1. Charged 0.1 generations; balance 31.50.
Excluded top-row third tree (weeping willow) from all exported sprites. Existing previously accepted willow sprite was not modified.

Seven native-size, transparent PNGs: assets/Trees/Extracted2K. Exterior white background, neutral grey ground shadows and isolated neutral artifacts removed; inner tree shading retained. Native sizes including 2px padding: see sizes.json.
Seven additional 64x80 game canvases: assets/Trees/Variants64x80, same filenames; proportional nearest-neighbor reduction, centered, bottom baseline y76. Original Unzoom detail retained in Extracted2K copies. New atlas trees_2k_sheet_4x2.png contains these seven only.

Visually inspected native preview on contrasting green background. Verified transparent RGBA and nonempty silhouettes for all 14 PNGs. No game scenes changed. No ZIP created.

White-birch repair: removed global white-pixel deletion, restricted neutral ground-shadow removal to below y99, protected lower root polygon, rebuilt original-color native PNG, 64x80 PNG and atlas. Reviewed enlarged against dark purple background. No PixelLab charge.
