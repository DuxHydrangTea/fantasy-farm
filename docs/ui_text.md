# Text rendering

All gameplay scenes use the project theme at `resources/ui/game_theme.tres` and
its shared font at `resources/ui/game_font.tres`. New Label, Button and other
Control nodes inherit this font automatically. Avoid per-node font overrides;
they bypass the shared Vietnamese fallback and rendering settings.

Upheaval (`assets/Fonts/upheavtt.ttf`) is the primary font. Pixelify Sans and
Mouse Meadow provide fallback glyphs for Vietnamese and symbols. All three are
imported with MSDF enabled.
The built-in fallback font also has MSDF enabled in Project Settings. Keep these
settings in the tracked `.ttf.import` files so another checkout imports them the
same way. MSDF preserves glyph edges when camera zoom or UI scale changes.

Use a readable screen size (normally at least 16 px for UI text). A very small
label can still be hard to read even with MSDF. Prefer a 1 px outline or shadow
over a thick outline that closes the gaps inside letters.

HUD text and interaction prompts belong in a CanvasLayer so camera zoom does
not change their screen size. Place moving prompts on whole screen pixels and
keep them within the viewport. World labels, such as pickup quantities, may
scale with the world; they still inherit the shared MSDF font.

Keep nearest filtering on pixel-art sprites. Do not change the entire scene's
texture filtering to address font rendering.

Gameplay text defaults to English. See [localization](localization.md) for PO
catalogs, named placeholders and live English/Vietnamese switching.

## Independent UI scale

`UIScaleComponent` adjusts each screen-space CanvasLayer against the viewport's
stretch transform. The world viewport/camera stays unchanged. UI uses at least a
640×360 virtual canvas; at a 500×400 window, the 16:9 content area is roughly
500×281 and menu text is about 19 physical pixels instead of about 6 pixels.
Larger windows approach one UI unit per physical pixel. Never scale the game
camera or change the world viewport to make a menu readable.

Shop, inventory, hotbar, wallet and animal inspector use this component. Roots
use top-left anchors and an explicit virtual size. Measure/input-test controls
through `get_global_transform_with_canvas()` when the layer has a scale; a plain
`get_global_rect()` omits the CanvasLayer transform.

Compact shops use short category names with full tooltips, separate scrolling
areas for cards/details, a persistent quantity/checkout row and no bottom hint.
The close button stays reachable. Resizing/retranslation retains selections and
quantity. Inventory retains all 64 slots through its scroll area. See
[animal status](animal_status_ui.md) for the field inspector.
