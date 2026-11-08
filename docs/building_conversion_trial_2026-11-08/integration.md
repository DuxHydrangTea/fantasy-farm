# Building integration

Four standalone StaticBody2D scenes under res://scenes/buildings/converted_farm/. None inherits an old building scene or uses appearance/variant scripts.

- result_1_transparent -> seed_storage; supply storage access retained.
- result_2_transparent -> produce_warehouse; produce storage access retained.
- result_3_transparent -> cattle_barn; separate wall, trough and fence colliders.
- result_4_clean_transparent -> chicken_coop; separate shelter and run colliders.

World node names and root placements retained. Sprite pivots are at entrance ground level. Original assets and old scenes preserved. Duck shelter unchanged.

Validation: headless import, instantiate all four standalone scenes, validate their textures/colliders and storage area nodes, instantiate main_world and confirm all four replacements. See verify.log. Gameplay interaction and visual overlap still require in-game review.
