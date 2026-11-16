# Big Oak style shadows for perennial variants

Implemented 2026-11-16. The user's reference is the mature middle frame of `assets/Trees/Big_Oak_Tree.png`. Its ground shadow uses pure black at alpha 40/255, considerably lighter and deeper than the removed alpha-117 thin ellipses.

## Art and integration

Fifteen separate shadow PNGs are in `assets/Trees/Shadows/Variants64x80`. Every visible shadow pixel is exactly RGBA (0,0,0,40), matching Big Oak. The broad stepped oval template was generated with the Big Oak image as a reference, then its alpha was flattened to the exact sampled value and its proportions normalized to the reference's 36x22 silhouette. Sizes scale with canopy width using the reference's 41px canopy, retaining the 36:22 aspect ratio. Ground offsets follow the sampled reference centre relative to its opaque root, scaled with shadow size.

The source `Variants64x80` tree PNGs and atlas are unchanged from the prior shadowless cleanup. Separate textures avoid cutting off a broad shadow at a tall tree's 80px canvas boundary and keep the root anchor and collider identical. `TreeDefinition` now has optional `ground_shadow_texture` and `ground_shadow_offset`; the fourteen definitions that use the live timber variant atlas reference their corresponding shadow PNGs. A shadow for `green_birch` is also available as an asset for future use.

`PerennialTree` lazily creates a `GroundShadow` Sprite2D behind the tree, outside the canopy motion node. It is visible only for a configured mature/ready tree, hidden for the sapling/growing stages and after chopping to a stump. Existing baked-shadow trees such as Oak have no extra configured shadow, avoiding duplication. No gameplay timings, yields, tree source pixels or collision geometry were changed.

## Validation

Three new regression tests pass: exact Big Oak opacity / non-clipped shadow extent; growth, stump and regrowth visibility without shifting the tree or collider; and no duplicate shadow on built-in Oak. Broader tree suites still have 22 failing tests. A baseline using the previous PerennialTree/TreeDefinition code and pre-shadow definition resources has the exact same 22 failing test names (3/25 baseline pass, 6/28 pass with the three new tests). Those failures are pre-existing atlas/growth/economy/save assumptions and were not changed for this task.

Project lint: zero errors and zero warnings. A real Godot/OpenGL preview renders the original Big Oak reference beside fourteen actual mature TimberTree actors; no compile/runtime errors. The open editor was refreshed after the resource/code updates. `validation.json` and `shadow_assets.json` record checks, dimensions, root offsets and source-image hashes.

`native_preview.png` shows all active species with Big Oak in the first slot. `reference_comparison.png` is a closer crop of Big Oak, Willow, Purple Blossom and Blue Conifer. Original source tree PNG hashes were rechecked after integration and are unchanged.
