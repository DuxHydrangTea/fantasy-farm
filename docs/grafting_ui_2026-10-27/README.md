# Grafting UI — 2026-10-27

Implemented directly following the user's authorization to choose the concept and ship it without another approval step.

## Design and behavior

- Reuses the shared cream, brown and sage pixel UI theme and actual game sprites. The generated concept is a reference, not a baked interface background.
- Desktop separates the current tree/crop, two graft directions, and the reviewed offer. Compact layouts move the offer into the choices scroll while keeping confirmation and harvesting accessible.
- Compares doubled ordinary yield with base-volume Star fruit. Order demand and Chef recipe counts come from game data.
- Reviewing a direction has no side effects. Confirmation binds to the reviewed tree revision and cost; stale offers require another review.
- First choice is free; subsequent changes require one grafting wax. The current crop is retained and the pending direction activates after harvest.
- Handles missing wax, duplicate confirmation, full inventory, removed trees and walking out of range. Supports Vietnamese and English.
- Runtime icon cropping removes transparent padding without changing sprite source files.
- GraftService, tree mechanics, prices and save schema are unchanged.

## Verification

- New UI suite: 5/5 tests, 49/49 assertions.
- Combined UI and existing graft suite: 16/17 tests, 189/190 assertions. The offline 48-hour restore test at `tests/integration/test_grafting.gd:300` also failed in the baseline before these UI changes.
- Native mouse/touch probe: 35/35 checks; no script/runtime errors; isolated data, no personal save.
- Desktop layout has zero findings. Compact full report contains 14 offscreen findings for scroll-clipped children; zero-size/overlap gates pass. Header, harvest and confirmation reports have zero findings. Native checks verify viewport bounds and minimum 48px action targets.
- Component and scene lint: zero errors or warnings. Scene validation: zero errors and 28 existing dependency warnings outside the grafting scene/controller.

See `verification.json`, `runtime-report.json`, layout reports and `scene-tree.json` for evidence. Screenshots cover Vietnamese/English desktop and 844×390 / 667×375 compact viewports. `concept.png` and `prompt.md` retain the generated visual reference.
