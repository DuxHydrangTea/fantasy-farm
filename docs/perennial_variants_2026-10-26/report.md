# Perennial tree resource additions

14 definitions + 14 sapling items, listed in manifest.json. Existing runtime auto-discovers definitions; no production scripts, shop offers or player saves modified. Placeholder young stages and brown stump reuse Oak. Mature/falling texture uses the matching complete 64x80 sprite. Excluded broken green_birch; retained accepted first-sheet willow.

Validation: isolated Godot 4.7.2 + GUT run, 2 tests passed / 309 assertions. Real TimberTree nodes grew, chopped to brown stumps and regrew. Static lint of trees, items/trees and validation script: zero diagnostics.

Existing tree unit/integration suites: 5/25 passing, 20 failing, 169/243 assertions passing. Baseline excluding all 28 added resources has the same 20 failures / assertion totals. Existing test assumptions differ from current tuned growth times, harvest amounts and dig hits; not changed here. Logs: validation.log, existing-tests.log, baseline-existing-tests.log.

Preview: resource_preview.png. Shared placeholder brown stump: trees/textures/oak_stump.tres. New resource economics match existing Oak: 86400 seconds and 400 Wood. New saplings are ready as resources but not yet offered by a shop.
