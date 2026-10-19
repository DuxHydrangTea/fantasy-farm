# Text rendering

All gameplay scenes use the project theme at `resources/ui/game_theme.tres` and
its shared font at `resources/ui/pixelify_sans.tres`. New Label, Button and other
Control nodes inherit this font automatically. Avoid per-node font overrides;
they bypass the shared Vietnamese fallback and rendering settings.

Both Pixelify Sans and its Mouse Meadow fallback are imported with MSDF enabled.
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
