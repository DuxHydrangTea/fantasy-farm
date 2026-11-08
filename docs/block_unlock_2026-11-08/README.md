# Block-based farmland unlocking

New profiles start with only block 0: Rect2i(49, 19, 8, 8), 64 planting cells.
There are 24 blocks, separated by the existing one-tile FieldBoundaries paths.
The order starts at the top right, travels down four blocks, then up the next
column to the left, continuing in a snake. Every purchase opens one whole block.
Paths remain visible and walkable and keep blocks_farming=true.

LandExpansionState.block_rect is the shared geometry for ownership, the next
purchase sign, weed cover, reveal animation, and migration. Save version 40 stores
land_blocks and land_starting_blocks. Version 39 ownership is rounded up to whole
blocks while preserving all previously owned planting cells. Existing crops,
items, and coins are retained; existing farms are not reset to one block.

Validation: 49 focused GUT tests pass (land unit/integration, starter progression,
save repository, profile list, and tool upgrades). Runtime screenshot:
first_block.png. The real local save migrates to 12 blocks with all 589 crops.
Whole-project validation also reports pre-existing failures in
output/flower_scene_refactor_backup and tests/performance/profile_workers.gd;
the land scripts and running main scene load successfully.
