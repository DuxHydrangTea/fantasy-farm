# Kế hoạch: Tán cây rung theo gió cho layer `Tree` (tree canopy sway)

## Mục tiêu & phạm vi
Tán cây (phần trên đường ranh tán–thân) của 150 cây trang trí trong TileMapLayer `Tree` của `main_world.tscn` đung đưa theo gió — nguồn gió cùng hệ thời tiết thật (SUNNY/CLOUDY/RAIN/WINDY → 0.65/1.2/1.0/2.8 như cỏ GPU). Thân cây đứng im. **Không tách layer, không đụng collision** (TileSet nhúng của layer Tree đã không có physics — xác minh rồi). Mỗi cây là 1 tile duy nhất → không có vấn đề xé seam nhiều tile; phase theo vị trí tile tự đồng nhất cả tán.

## File mới (4 + 1 doc)

1. **`shaders/tree_canopy.gdshader`** (~45 dòng, `canvas_item` + `world_vertex_coords`):
   - Uniforms: `wind_strength`, `wind_direction`, `canopy_base` (UV fraction 0–1, đo từ đỉnh tile), `sway_scale` (px biên độ), `use_test_time`/`test_time` cho test.
   - Vertex: `breeze` = 2 sóng sin chu kỳ 5s/9s (chia hết TIME 3600s — cùng công thức cỏ để nhịp rừng-cỏ khớp); phase băm từ world origin của tile (`0.071x + 0.043y`); `reach = clamp((canopy_base − UV.y) / canopy_base, 0, 1)` → 0 tại/dưới đường tán, ramp lên đỉnh; `VERTEX += dir × strength × sway_scale × breeze × reach`. Không actor bend.
   - Fragment: `COLOR = texture(TEXTURE, UV) * vertex_tint` (tự chịu CanvasModulate/PointLight2D như biến thể G4 của cỏ).
2. **`resources/trees/tree_canopy_data.gd`** (~30 dòng, `RefCounted` const, mô phỏng `farm_grass_data.gd`): 4 loài Big_Birch/Fruit/Oak/Spruce — mỗi entry: source texture path, `canopy_base` (đo từ frame "chỉ tán" — frame 2 — trong PNG bằng phân tích pixel alpha: đáy opaque của frame 2 so với chiều cao frame 1), `sway_scale` (~6–9px cho cây 64–80px, clamp tổng ≤ 20px).
3. **`components/landscape/tree_canopy_materials.gd`** (~70 dòng, `RefCounted` — clone lifecycle `GrassTileMaterials`): `install(layer)` duplicate TileSet sâu, gắn `ShaderMaterial` per loài vào TileData (theo texture path khớp data file, skip tile đã có material), trả về bool + đếm; `sync_wind(strength, direction)` diff-theo-key có cache `_previous`; `restore()` idempotent, chỉ trả TileSet gốc khi `layer.tile_set == _local`. Không cần headless fallback — material là thuần data, hoạt động cả headless.
4. **`components/landscape/tree_canopy_sway.gd`** (Node mỏng ~50 dòng): giữ `TreeCanopyMaterials`, `_process` đọc `world.weather.effects` (deadband 0.002 như cỏ), gọi `sync_wind`; `_exit_tree` restore. Export `enabled`.
5. **`docs/tree_canopy.md`**: doc thiết kế theo format `beehives.md` (bảng quy tắc, thành phần, test).

## File sửa (1)
**`world/main_world.gd`**: thêm `@export var tree_canopy_sway_enabled: bool = true` + var `tree_canopy`; trong `_ready` cạnh block `grass = FarmGrassField.new()` (dòng ~87–90) mirror: tạo `TreeCanopySway`, wire `world = self`, gắn node `Tree`, `add_child`, tôn trọng export flag. Không sửa `main_world.tscn`.

## Unit test: `tests/unit/test_tree_canopy.gd` (GUT, mô phỏng `test_grass_farm.gd`)
- Fixture instantiate `main_world.tscn` **không enter tree** (comment "Never enter tree" như grass test) → lấy node `Tree`.
- `test_install_creates_local_tileset_with_one_material_per_species`: sau install — `tile_set != original`, 4 material, shader + uniforms đúng kiểu, TileData các loài đều có material.
- `test_sync_wind_updates_all_materials_with_deadband`: set strength 2.8 → đọc lại `get_shader_parameter` trên từng material; gọi lại cùng giá trị → không set thừa (check qua cache).
- `test_restore_idempotent_and_respects_external_edits`: restore 2 lần; giả lập tile_set bị đổi ngoài → không ghi đè.
- `test_canopy_data_within_tile_bounds`: 4 entry, `0.2 < canopy_base < 1.0`, `sway_scale` ≤ 20.
- `test_world_wiring_headless`: add world vào tree (headless) → node `TreeCanopySway` tồn tại, materials đã install, weather `_activate(WINDY)` + strength 1.0 → wind_strength uniform == 2.8 × sway mapping.
- `test_shader_uniform_schema`: shader có đủ tên uniform (mirror `render_preflight` check của grass).

## Vòng kiểm chứng (lặp đến khi xanh — "tự test đến khi chạy ngon")
Godot exe: `C:/Godot_v4.7.1-stable_mono_win64/Godot_v4.7.1-stable_mono_win64_console.exe` (đường dẫn dùng thật trong `docs/mobile_controls.md`).
1. **Đo canopy_base**: script python nhỏ đọc IHDR + alpha frame 2 của 4 PNG `assets/Trees/Big_*.png` → chốt hằng số cho data file (fallback: đo bằng `inspect_image` của skill).
2. `python .agents/skills/godot/scripts/debug/lint_project.py <project> --pretty` → 0 errors.
3. `godot --headless --path . --import` (làm mới class cache cho class_name mới).
4. `check_project` qua dispatcher + `godot_log_parser.py` → **shader phải compile** (skill: shader hỏng render thành default material im lặng — đây là cổng kiểm bắt buộc).
5. Chạy test mới isolate: `python tests/run_tree_tests.py --godot <exe> --suite tests/unit/test_tree_canopy.gd` (scratch project, không đụng editor).
6. Chạy hồi quy: 4 suite cỏ (`test_grass_gpu/farm/chunks/interactions`) + smoke `run_project.py` main scene headless → `ok: true`, 0 error (xác nhận fallback/headless không vỡ).
7. **Godot MCP**: runtime MCP server chỉ sống khi game chạy từ editor — sẽ khởi editor (headless editor) để plugin toolkit online và thử điều khiển qua `npx @npgamedev/godot-mcp-server` (stdio JSON-RPC) cho một lần kiểm tương tác/cảnh báo console; nếu bridge không reachable từ môi trường shell thì ghi rõ trong báo cáo và bù bằng scenario screenshot có cửa sổ (probe kiểu `grass_gpu_farm_probe`) so sánh 2 khung WINDY vs SUNNY xác nhận tán dịch chuyển.
8. Toàn bộ xanh → commit không tạo (chỉ báo cáo), tổng hợp kết quả + số liệu (test pass, canopy_base đo được, biên độ) phản hồi lại.

## Rủi ro đã cân nhắc
- Vertex color của TileMap tile phải truyền qua varying (`vertex_tint`) kẻo mất tint — làm đúng theo core cỏ.
- Tile lưới 4px + atlas 16px: không ảnh hưởng vì mọi tính toán dùng UV 0–1 của vùng tile, không phụ thuộc kích thước atlas.
- Layer `Trees` rỗng (tileset trống) — bỏ qua, installer no-op an toàn.
- Không đụng save schema, không đụng gameplay: thuần visual layer.