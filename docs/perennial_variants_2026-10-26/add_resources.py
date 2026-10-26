from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[2]
variants=[('autumn_maple','Autumn Maple'),('evergreen_spruce','Evergreen Spruce','spruce'),('willow','Willow'),('pink_blossom','Pink Blossom'),('golden_birch','Golden Birch'),('palm','Palm'),('magic_blue','Magic Blue Tree'),('flowering_cactus','Flowering Cactus'),('red_maple','Red Maple'),('golden_aspen','Golden Aspen'),('orange_oak','Orange Oak'),('blue_conifer','Blue Conifer'),('purple_blossom','Purple Blossom'),('brown_palm','Brown Palm')]
# Reuse current oak economics without resetting hand-tuned existing resources.
oak=(root/'trees/definitions/oak.tres').read_text()
props={key:re.search(r'^'+key+r' = (.+)$',oak,re.M).group(1) for key in ['growth_seconds','harvest_amount']}
manifest=[]
for row in variants:
 key,name,*alias=row;image=alias[0] if alias else key
 texture=f'assets/Trees/Variants64x80/{image}.png'
 assert (root/texture).exists()
 ext='''[ext_resource type="Script" path="res://scripts/tree_definition.gd" id="script"]
[ext_resource type="Resource" path="res://items/trees/wood.tres" id="wood"]
[ext_resource type="Resource" path="res://items/trees/root_wood.tres" id="root"]
[ext_resource type="Texture2D" path="res://trees/textures/oak_stage1.tres" id="stage1"]
[ext_resource type="Texture2D" path="res://trees/textures/oak_stage2.tres" id="stage2"]
[ext_resource type="Texture2D" path="res://trees/textures/oak_stump.tres" id="stump"]
'''+f'[ext_resource type="Texture2D" path="res://{texture}" id="mature"]\n'
 definition='[gd_resource type="Resource" script_class="TreeDefinition" format=3]\n\n'+ext+'\n[resource]\n'+f'''script = ExtResource("script")
tree_id = &"{key}"
display_name = "{name}"
kind = 1
growth_seconds = {props['growth_seconds']}
harvest_amount = {props['harvest_amount']}
harvest_item = ExtResource("wood")
root_item = ExtResource("root")
stage_textures = Array[Texture2D]([ExtResource("stage1"), ExtResource("stage2"), ExtResource("mature")])
ready_texture = ExtResource("mature")
stump_texture = ExtResource("stump")
canopy_texture = ExtResource("mature")
'''
 target=root/f'trees/definitions/{key}.tres';assert not target.exists(),target;target.write_text(definition)
 sapling=f'''[gd_resource type="Resource" script_class="ItemDefinition" format=3]

[ext_resource type="Script" path="res://scripts/item_definition.gd" id="script"]
[ext_resource type="Texture2D" path="res://trees/textures/oak_stage1.tres" id="icon"]
[ext_resource type="Resource" path="res://trees/definitions/{key}.tres" id="tree"]

[resource]
script = ExtResource("script")
item_id = &"{key}_sapling"
display_name = "{name} Sapling"
description = "Plant in the right timber grove. Chop mature trees with an axe."
icon = ExtResource("icon")
item_type = 1
crop = ExtResource("tree")
max_stack = 999
'''
 target=root/f'items/trees/{key}_sapling.tres';assert not target.exists(),target;target.write_text(sapling)
 manifest.append({'tree_id':key,'name':name,'definition':f'trees/definitions/{key}.tres','sapling':f'items/trees/{key}_sapling.tres','mature_texture':texture})
(root/'docs/perennial_variants_2026-10-26/manifest.json').write_text(json.dumps(manifest,indent=2))
print(f'Added {len(manifest)} tree definitions + saplings; growth={props["growth_seconds"]}, wood={props["harvest_amount"]}.')
