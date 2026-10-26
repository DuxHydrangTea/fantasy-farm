# Flower seed packets — Meowa 48x48 redesign

Requested 2026-10-26: redesign all flower seed packet icons using Meowa AI.

Scope: 32 existing visual species; 10 currently have game seed ItemDefinition resources. The other 22 remain available art assets, without adding new gameplay species.

Design direction: warm cream/gold paper seed envelope, clean folded seams, thin brown outlines, species-colour ribbon and a large identifiable botanical flower illustration. Transparent canvas, no lettering. Native delivery size: 48x48. Generated previews work at enlarged size and are reduced with nearest-neighbour; accidental gradient colours are limited to 64 per icon without dithering, with binary alpha and a consistent baseline.

Source: original 32 packet reference images in `assets/Icons/seeds/flowers16/`, mapped by the existing manifest. Meowa API key is read from Windows User environment and never saved here.

Initial Universal Edit jobs: image2_5 medium, pixel mode, strict 192x192 working canvas, 1K generation, one reference, 7 credits each. Nine jobs succeeded before the service reported only 6 trial credits remaining.

Fallback: Asset Clone, a 5x5 sheet holding the remaining 23 species and two existing style controls. image2_5 standard/low, 1K, pixel mode, standard background removal. Submitted as one sheet generation to fit the remaining balance. No credits purchased. Exact requests, job IDs and cost metadata are retained beside this file.

## Final delivery

- All 32 icons are newly redesigned by Meowa and delivered as distinct 48x48 transparent PNGs in `assets/Icons/seeds/flowers48/`, with an 8x4 sheet (384x192).
- Nine individual Universal Edit images cost 63 credits; one shared Asset Clone sheet cost 5 credits. Actual total: **68 credits**.
- Sheet variant 2 was selected for finer detail. Its dimensions are not evenly divisible by 5, so the 25 packet silhouettes were detected by connected opaque components and sorted into their 5x5 placement order. This avoids slicing neighbouring packets or clipping flowers. The first 23 cells provide the remaining species; the two duplicate style controls are excluded.
- `manifest.json` maps all 32 flower names to PNGs, hashes, job IDs and costs. `sheet_slices.json` preserves the exact source bounds.
- The 10 existing flower seed resources now reference the new art. Their identities, crop links, stack sizes and UID metadata are preserved. No save or shop prices changed.
- Godot loaded all 32 assets; the real InventorySlot uses the new textures for all 10 gameplay items, and all 10 flower shop offers resolve to 48x48 icons. See `inventory_preview.png`, `verification.json` and `verify.log` (no runtime errors).
- Static project lint before and after: zero errors and warnings. The Mono editor's recovery-mode import logs unrelated timer warnings; runtime verification succeeds.
