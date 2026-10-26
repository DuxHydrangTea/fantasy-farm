# Sapling icon generation — Meowa

User requested 14 missing timber-sapling icons on 2026-10-26.

Source references: the project's Oak sapling (Small_Oak_Tree atlas region) for pixel style, and the corresponding mature tree from `assets/Trees/Variants64x80/` for species shape/colour. Evergreen Spruce uses `spruce.png`.

Provider: Meowa Universal Edit, `image2_5`, medium quality, 1K generation, pixel mode, strict dimensions, standard background removal. Authentication reads Windows User `MEOWA_API_KEY`; no key is stored here.

The first 32x32 trial lost too much structure. The second trial uses a nearest-neighbour 4x reference (128x128), followed by nearest-neighbour reduction to native icon size. Original output images, exact prompts, job IDs, status and actual costs are preserved here. The first trial is kept for audit but is not a game asset.

Two active jobs maximum; HTTP 429 responses pause submission until existing jobs progress. Resuming `batch.py run` reads saved job IDs rather than resubmitting completed requests.

Budget: 15 successful edits at 9 credits each = 135 credits including the rejected first trial, subject to actual returned metadata. Icons are reviewed before item resources are updated. The files in this folder are development sources and are excluded from Godot import via `.gdignore`.

## Delivered and verified

- 14 distinct PNG icons at 32x32 in `assets/Icons/tree_saplings/`, with binary transparency and a consistent baseline. The preview shows enlarged icons and native-size miniatures.
- All 14 corresponding ItemDefinition resources now reference their own icon. Installed using Godot ResourceSaver; only icon references changed.
- Source PNGs and prompts retained. Actual returned cost metadata confirms 135 credits across 15 successful edits.
- `image_checks.json` records dimensions, bounds, opaque pixels and hashes. `verification.json` summarizes checks.
- Godot 4.7.1 imported and loaded every icon; `inventory_preview.png` exercises the real InventoryComponent and InventorySlot. No engine errors. The project has unrelated existing GDScript warnings in the debugger log.
- Static project lint: zero errors and warnings, before and after. `git diff --check` passed.
