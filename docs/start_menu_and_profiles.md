# Start menu and independent farms

The application starts at `world/start_menu.tscn` before loading the farm world.

- **Continue** opens the last successfully played farm. It is disabled when no readable save exists.
- **New game** asks for a farm name and creates a unique `farm_<random ID>` profile. Its first save is committed after world initialization.
- **Played games** lists saved farms with their balance, field columns and last played time. Each entry opens its own save.
- **Quit** closes the application from the menu.

Existing `profile_local.json` saves appear as **Existing farm**. Creating a farm does not overwrite them. Profiles use the existing save repository, checksum, backup recovery and revision checks. Names and the last selected profile are stored in `user://saves/profiles.cfg`; each world remains in `profile_<ID>.json`. Invalid saves remain visible but cannot be selected. Full validation still runs before loading a world; failures return to the menu and disable writes.

## Offline progress switch

`project.godot` sets `gameplay/offline_progress_enabled=false`. Loading restores the saved farm timestamp directly and skips worker offline replay. While open, the session clock advances with frame time and clamps long stalls. Closing the game does not grow crops, advance workers or grant offline income.

The existing offline simulation methods are retained. To enable them again, change the setting to `true`. New saves include an optional `wall_saved_at` timestamp, so re-enabling calculates only real time since the latest save rather than granting time deliberately skipped while offline progress was disabled. Saves without this marker retain the original wall-clock behavior when the feature is enabled. Schema version stays 36 because the new field is optional.

## Verification

- Profile unit tests: 4 passed, including discovery of legacy saves and backup recovery.
- Menu integration tests: 2 passed, including desktop, landscape and portrait layouts in Vietnamese and English.
- Offline policy integration tests: 3 passed, including an unchanged checkpoint after seven simulated closed days and re-enabling the feature.
- Persistence bootstrap tests: 3 passed; repository tests: 21 passed.
- Native UI probe: 47 checks passed across two independently saved farms, Continue, older profile selection and responsive layouts. Uses an isolated save directory; personal saves are untouched. Godot reports ObjectDB instances at probe shutdown, with no runtime script errors.

QA scenes and tests: `tests/support/start_menu_probe.tscn`, `tests/unit/test_game_profiles.gd`, `tests/integration/test_start_menu.gd`, `tests/integration/test_offline_policy.gd`.
