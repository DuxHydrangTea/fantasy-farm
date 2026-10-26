# Fruit trees edited with PixelLab

Requested 2026-10-26: choose four trees from `assets/Trees/Variants64x80/` and edit the originals into apple, peach, pear and cherry tree sprites.

## Source mapping

- Apple: `orange_oak.png` — broad rounded canopy and strong branching.
- Peach: `pink_blossom.png` — compact rounded fruit-tree habit.
- Pear: `golden_aspen.png` — taller upright crown.
- Cherry: `purple_blossom.png` — broad spreading crown.

Every source was inspected at native resolution. Edits use PixelLab `edit_image_pixen` at 64x80, keeping the existing native pixel density and trunk-root placement, changing foliage to green and adding species-specific fruit. Transparency is preserved; no image resizing or palette replacement is applied to final assets.

Initial budget: 8 generations, one per edit. The four attempts to remove fruit from the ready trees retained the fruit and were rejected after visual inspection. Four replacement edits use the original fruitless tree references and request green leaf canopies; these are retained as `bare_v2`. Total generation count: 12, including 4 rejected edits. The current Windows User `PIXELLAB_API_KEY` is supplied to the project helper only in the child process environment. No API keys are stored in this folder. Trial concurrency is one job at a time. Rejected overlong prompts/rate-limit requests did not produce jobs.

Exact prompts, seeds, source mapping, job IDs, original outputs and balance result are retained. Generated art is kept separate from the original timber trees. Only mature/ready visual references in the four fruit-tree definitions are intended to change; growth, yield, grafts, saplings and saves retain their existing data.
