"""Build tree resources from the shipped atlases; run from the repository root."""
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[2]


def write(path: str, source: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(source, encoding="utf-8")


def atlas(path: str, png: str, rect: tuple[int, int, int, int]) -> None:
    write(path, '[gd_resource type="AtlasTexture" format=3]\n\n'
          f'[ext_resource type="Texture2D" path="res://{png}" id="png"]\n\n'
          f'[resource]\natlas = ExtResource("png")\nregion = Rect2{rect}\nfilter_clip = true\n')


def item(path: str, identifier: str, name: str, icon: str, kind: int = 2,
         extra: str = "", resources: str = "") -> None:
    write(path, '[gd_resource type="Resource" script_class="ItemDefinition" format=3]\n\n'
          '[ext_resource type="Script" path="res://scripts/item_definition.gd" id="script"]\n'
          f'[ext_resource type="Texture2D" path="res://{icon}" id="icon"]\n{resources}\n'
          f'[resource]\nscript = ExtResource("script")\nitem_id = &"{identifier}"\n'
          f'display_name = "{name}"\nitem_type = {kind}\nicon = ExtResource("icon")\n{extra}')


def main() -> None:
    item("items/tools/axe.tres", "axe", "Axe", "icons/no_outline/tools/tools_r01_c04.tres", 0, 'tool_type = 2\ndescription = "Chop mature timber trees. Use a hoe to dig their stumps."\n')
    for identifier, name, icon in [("wood", "Wood", "materials_r06_c03"), ("root_wood", "Root Wood", "materials_r06_c04")]:
        item(f"items/trees/{identifier}.tres", identifier, name, f"icons/no_outline/materials/{icon}.tres")
    # Sheet thực tế: grapes, apple, pear, peach, cherry. Không dùng nho cho táo.
    for index, identifier in [(1, "apple"), (3, "peach"), (2, "pear"), (4, "cherry")]:
        icon = f"trees/textures/{identifier}_fruit.tres"
        atlas(icon, "assets/Crops/Fruit_Trees_Fruit_Objects.png", (index * 16, 0, 16, 16))
        item(f"items/trees/{identifier}.tres", identifier, identifier.title(), icon)
        ext = ''.join(f'[ext_resource type="Texture2D" path="res://crops/fruit_trees/shared/stage_{stage:02d}.tres" id="stage{stage}"]\n' for stage in range(1, 4))
        ext += f'[ext_resource type="Texture2D" path="res://crops/fruit_trees/{identifier}/ready.tres" id="ready"]\n'
        definition(identifier, identifier.title() + " Tree", ext,
                   f'kind = 0\ngrowth_seconds = 180.0\nfruit_cycle_seconds = 90.0\nharvest_amount = 3\n',
                   f"items/trees/{identifier}.tres")
        sapling(identifier, identifier.title() + " Sapling", "crops/fruit_trees/shared/stage_01.tres")
    for identifier in ["oak", "birch", "spruce"]:
        ext = ""
        textures = []
        for size, frame, suffix in [("Small", 1, "stage1"), ("Medium", 1, "stage2"), ("Big", 1, "stage3"), ("Big", 0, "stump"), ("Big", 2, "canopy")]:
            filename = f"{size}_{identifier.title()}_Tree.png"
            if identifier == "spruce" and size == "Big":
                filename = "Big_Spruce_tree.png"
            png = f"assets/Trees/{filename}"
            width, height = struct.unpack(">II", (ROOT / png).read_bytes()[16:24])
            path = f"trees/textures/{identifier}_{suffix}.tres"
            atlas(path, png, (frame * (width // 3), 0, width // 3, height))
            ext += f'[ext_resource type="Texture2D" path="res://{path}" id="{suffix}"]\n'
            textures.append(path)
        leaf = "Spruce_Needle" if identifier == "spruce" else identifier.title() + "_Leaf"
        ext += f'[ext_resource type="Texture2D" path="res://assets/Trees/{leaf}_Particle.png" id="leaf"]\n'
        ext += '[ext_resource type="Resource" path="res://items/trees/root_wood.tres" id="root"]\n'
        definition(identifier, identifier.title() + " Tree", ext,
                   'kind = 1\ngrowth_seconds = 240.0\nstump_seconds = 120.0\nchop_hits = 4\ndig_hits = 3\nharvest_amount = 5\n'
                   'stump_texture = ExtResource("stump")\ncanopy_texture = ExtResource("canopy")\nleaf_texture = ExtResource("leaf")\nroot_item = ExtResource("root")\n',
                   "items/trees/wood.tres", "stage3")
        sapling(identifier, identifier.title() + " Seed", textures[0])


def update_catalogs() -> None:
    # Thêm block theo ID cố định; giữ nguyên giá/cấu hình do người dùng đã sửa.
    for path, ids, script_id, array_name, prefix in [
        ("resources/shops/farm_supply.tres", ["apple_sapling", "peach_sapling", "pear_sapling", "cherry_sapling", "oak_sapling", "birch_sapling", "spruce_sapling", "axe"], "2_offer", "offers", "tree_offer"),
        ("resources/shops/produce_prices.tres", ["apple", "peach", "pear", "cherry", "wood", "root_wood"], "1_k2k64", "entries", "tree_price"),
    ]:
        target = ROOT / path
        source = target.read_text(encoding="utf-8")
        if f'id="{prefix}_0"' in source:
            continue
        resources = ""
        blocks = ""
        for index, identifier in enumerate(ids):
            folder = "tools" if identifier == "axe" else "trees"
            resources += f'[ext_resource type="Resource" path="res://items/{folder}/{identifier}.tres" id="{prefix}_item_{index}"]\n'
            price = (250 if identifier == "axe" else 60 if "sapling" in identifier else 20 if identifier in ["wood", "root_wood"] else 40)
            blocks += f'[sub_resource type="Resource" id="{prefix}_{index}"]\nscript = ExtResource("{script_id}")\nitem = ExtResource("{prefix}_item_{index}")\nprice = {price}\n'
            if array_name == "offers":
                blocks += 'category = 1\n'
            blocks += "\n"
        insert = source.index("[sub_resource")
        source = source[:insert] + resources + "\n" + source[insert:]
        source = source.replace("[resource]\n", blocks + "[resource]\n", 1)
        lines = source.splitlines()
        for index, line in enumerate(lines):
            if line.startswith(array_name + " = "):
                lines[index] = line[:-2] + ", " + ", ".join(f'SubResource("{prefix}_{i}")' for i in range(len(ids))) + "])"
        target.write_text("\n".join(lines) + "\n", encoding="utf-8")


def definition(identifier: str, name: str, ext: str, props: str, product: str, ready: str = "ready") -> None:
    write(f"trees/definitions/{identifier}.tres", '[gd_resource type="Resource" script_class="TreeDefinition" format=3]\n\n'
          '[ext_resource type="Script" path="res://scripts/tree_definition.gd" id="script"]\n'
          f'[ext_resource type="Resource" path="res://{product}" id="product"]\n{ext}\n[resource]\n'
          f'script = ExtResource("script")\ntree_id = &"{identifier}"\ndisplay_name = "{name}"\n{props}'
          'harvest_item = ExtResource("product")\nstage_textures = Array[Texture2D]([ExtResource("stage1"), ExtResource("stage2"), ExtResource("stage3")])\n'
          f'ready_texture = ExtResource("{ready}")\n')


def sapling(identifier: str, name: str, icon: str) -> None:
    description = "Plant in the left orchard. Water once to start growth." if identifier in ["apple", "peach", "pear", "cherry"] else "Plant in the right timber grove. Chop mature trees with an axe."
    item(f"items/trees/{identifier}_sapling.tres", f"{identifier}_sapling", name, icon, 1,
         f'crop = ExtResource("tree")\ndescription = "{description}"\n', f'[ext_resource type="Resource" path="res://trees/definitions/{identifier}.tres" id="tree"]\n')


if __name__ == "__main__":
    main()
    update_catalogs()
