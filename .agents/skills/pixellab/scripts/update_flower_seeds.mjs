import fs from 'node:fs';

for (let i = 1; i <= 10; i++) {
  const pad = String(i).padStart(2, '0');
  const filePath = `items/seeds/flower_${pad}_seed.tres`;
  const content = fs.readFileSync(filePath, 'utf8');

  // Match header
  const headerMatch = content.match(/\[gd_resource[^\]]+\]/);
  const header = headerMatch ? headerMatch[0] : '';

  // Match crop ext_resource
  const cropMatch = content.match(/\[ext_resource type="Resource"[^\]]+path="res:\/\/flowers\/definitions\/flower_[0-9]+\.tres"[^\]]+id="([^"]+)"\]/);
  if (!cropMatch) {
    console.error(`Could not match crop resource in ${filePath}`);
    continue;
  }
  const cropLine = cropMatch[0];
  const cropId = cropMatch[1];

  const newContent = `${header}

${cropLine}
[ext_resource type="Texture2D" path="res://assets/Icons/seeds/flower_seed_packet.png" id="2_icon"]
[ext_resource type="Script" uid="uid://bg2be8miqe4ud" path="res://scripts/item_definition.gd" id="3_script"]

[resource]
script = ExtResource("3_script")
item_id = &"flower_${pad}_seed"
display_name = "Flower ${pad} Seed"
icon = ExtResource("2_icon")
item_type = 1
crop = ExtResource("${cropId}")
max_stack = 999
`;

  fs.writeFileSync(filePath, newContent, 'utf8');
  console.log(`Updated ${filePath}`);
}
