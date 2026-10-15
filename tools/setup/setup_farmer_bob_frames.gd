@tool
extends EditorScript

# Giữ entry point cũ, dùng chung profile và đường dẫn với generator toàn bộ NPC.
const NpcSpriteFramesSetup = preload("res://tools/setup/setup_npc_sprite_frames.gd")


func _run() -> void:
	NpcSpriteFramesSetup.new().generate_npc("Farmer_Bob")
