# PixelLab API keys

- Read PixelLab API keys from `PIXELLAB_API_KEYS` in the project `.env`; keys are separated by `|`. Never print or disclose their values.
- Use one key until its PixelLab balance reaches zero before moving on to the next key. Check the balance when needed to determine whether the key still has available generations.
- When PixelLab confirms that a key has zero generations remaining, remove only that key from `PIXELLAB_API_KEYS` in `.env`, preserving the other keys. Do not remove a key solely because of a network error, rate limit, or an unverified authentication failure.
- After each PixelLab generation or edit, report the generations charged, the remaining balance for the key used, and how many API keys were used. Check the actual charge and balance when available; never reveal key values.
- For buildings and other world sprites, include the project's existing camera perspective explicitly in PixelLab prompts: straight-on, front-facing 2D game view, horizontal front facade, with the roof visible from slightly above; no isometric, diagonal, or three-quarter side view. Use a suitable in-game image as a composition or style reference when possible, and inspect the output before integrating it. Prompting alone does not guarantee the correct perspective.
