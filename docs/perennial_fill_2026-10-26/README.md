# Balanced mature perennial planting

Applied to the current local profile, not a repeating auto-fill. Filled all 306 valid cells on the existing staggered 48px grid: 153 fruit trees (Apple39, Cherry38, Peach38, Pear38), 153 timber/perennial trees (17 types x9). Every row in the timber area has all 17 types, shifted three columns between rows. All start mature; fruit trees have one ready harvest. Broken green_birch excluded.

Original snapshot retained as profile_before.json; installation.json records the live save path and timestamped backup. Only trees and revision changed from the schema-migrated original snapshot. Player, wallet, inventory, crops and other saved systems preserved. No production runtime scripts or scenes changed.

Validation: native Godot 4.7.2 isolated test, 1 test/1898 assertions passed; schema/checksum, balance, unique cells, mature sprites, world preflight and actual restore all checked. Static lint zero diagnostics. Existing unrelated scene UID fallback warnings appear during resource collection.

Installed using a hash guard and atomic replacement. Launched editor playtest, confirmed 306 live trees and enabled saving, inspected camera view of both planted regions. in_game.png is the actual game screenshot. Existing camera/player saved position preserved; preview camera reposition is runtime-only.
