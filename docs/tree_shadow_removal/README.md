# Perennial tree baked-shadow removal

Updated 2026-11-16. Removed the hand-painted thin ellipse ground shadows from `assets/Trees/Variants64x80`.

The shadow pixels were uniquely encoded as RGBA (0,0,0,117), while actual tree artwork was alpha 255. The final integration clears only those exact shadow pixels to RGBA (0,0,0,0). All other pixels, canvas sizes, roots, trunks, canopy details and atlas positions remain byte-identical at the decoded-pixel level. The image-edit model preview was not used for opaque artwork because it changed resolution and alpha values; the original opaque tree pixels are the preservation authority.

Changed fifteen individual 64x80 tree images plus `timber_variants_sheet.png`. Removed 7131 pixels total, including the duplicated shadows in the main atlas. The fourteen live `trees/textures/variant_*.tres` AtlasTexture regions agree exactly with their corresponding cleaned individual images. `green_birch.png` was also cleaned. The two older 4x2 sheets already had no matching shadow pixels and were left unchanged. Existing resource paths and dimensions are preserved.

Original backups and detailed preparation data are in `.godot/tree-shadow-removal`. `report.json` records changed files, exact removal counts, hashes and preserved opaque tree-pixel counts. `before_after.png` shows representative trees on the existing grass colour.

Validation: Godot 4.8 beta3 reimported the cleaned PNG files. A native resource check loaded all fourteen live AtlasTexture resources, confirmed each remains 64x80 and contains no semitransparent shadow pixels. The open editor was brought to the foreground for its filesystem/texture refresh.
