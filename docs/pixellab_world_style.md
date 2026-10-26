# PixelLab world asset style guide

Observed 2026-10-26 from representative source PNGs, excluding UI and inventory icons. This is a visual sample audit, not an exhaustive inventory or in-game renderer review. PNGs are deliberately excluded from the code graph, so conclusions come from direct image inspection. Contact sheet: /tmp/pixellab-style/contact.png (temporary).

## Visual contract

- Cozy rural fantasy pixel art; orthogonal top-down RPG projection with visible front faces and top surfaces. Ground axes remain horizontal/vertical; do not use diamond-grid isometric projection.
- Crisp native-resolution pixels and deliberate stepped diagonals. Dark coloured outlines, often near-black on characters; selective dark edges on foliage. Avoid smoothing, gradients, blur, painterly texture and 3D rendering.
- Warm brown wood, ochre/orange soil, brick-red roofs, green foliage with cooler dark shadows. Objects use compact shading clusters; terrain stays comparatively quiet. Do not impose one global colour-count limit on every asset family.
- Small humanoids have large heads and short bodies. Animals have rounded, readable silhouettes. Buildings carry denser material detail than characters and ground.
- Soft-looking ground shadows are still discrete pixel shapes. Match light direction to the chosen reference rather than assuming all sheets share a strict lighting rule.
- Sheet dimensions are not sprite dimensions. Determine the actual source frame region and occupied bounds before choosing the output canvas. Terrain/crop sheets show a recurring 16px module; larger actors/buildings need family-specific sizing.

## Reference anchors

- Humanoids: assets/NPCs (Premade)/Farmer_Bob.png; Chef_Chloe.png. Crop a single neutral frame, not the full animation sheet.
- Animals: assets/Animals/Chicken/Chicken_01.png; assets/Animals/Cow/Cow_01.png. Preserve the selected species' actual proportions.
- Plants: assets/Crops/Crops.png; assets/Crops/Apple_Tree.png; assets/Trees/Big_Oak_Tree.png. Small crop sprites are simpler than tree canopies.
- Props: assets/Outdoor decoration/barrels.png; Well.png; Outdoor_Decor.png. Crop one object without neighbours.
- Terrain: assets/Tiles/Grass/Grass_Tiles_1.png; assets/Tiles/FarmLand/FarmLand_Tile.png. Extract actual tiles before supplying references.
- Buildings: assets/Buildings/Buildings/Unique_Buildings/Inn/Inn_Red.png. Use architecture references for material density and projection; its full size is not a default for small houses.

## Tool selection policy

- One-view world props/buildings/plants: prefer reference-guided object generation. Pro Flash with style_image is a candidate; select dimensions from the target family. Use one direction unless gameplay requires rotations.
- NPCs: character v3 for rotations from an approved front-facing sprite. For a new identity, create and review a style-guided first image before rotating. A south reference must face the viewer straight on.
- Animals: use a suitable template/reference; do not rely on text-only humanoid v3 for chickens or cows.
- Terrain: top-down tileset with a matching base tile/reference and the existing tile size; review seams and transitions.
- Animation: start with one short clip/direction. Check proportions, feet/baseline and palette stability before expanding.
- Do not select a model merely for higher detail: matching the sparse existing pixel density is the priority. Read the current tool schema and cost before generation.

## Reusable English prompt scaffold

Create [SUBJECT] as a single game-world sprite matching the supplied reference images. Cozy rural fantasy pixel art for an orthogonal top-down farming RPG, visible top and front surfaces, matching the reference camera angle. Match the reference's native pixel density, dark coloured outlines, stepped diagonals, compact shading clusters, material palette and silhouette proportions. [FAMILY-SPECIFIC MATERIAL / COLOUR / SHAPE DETAILS]. Fit within [WIDTH]x[HEIGHT] native pixels with the base aligned to [BASELINE]; keep the complete silhouette inside the canvas. Isolated object on a transparent background. No text, UI frame, surrounding scene, antialiasing, blur, smooth gradients, painterly rendering or diamond-isometric perspective.

Replace every bracketed field for the requested asset. Treat this as intent, not a guarantee: use actual reference images and review results at native size beside source assets. Check scale, projection, outline weight, colour contrast and silhouette before import. No generations were submitted during this audit.
