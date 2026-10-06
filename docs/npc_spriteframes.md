# SpriteFrames NPC

Đã tạo ngày 06/10/2026 từ toàn bộ 8 PNG trong `res://assets/NPCs (Premade)`.
Resource nằm trực tiếp trong `res://sprite_frames/character/<npc>_frames.tres`.
Resource động vật nằm trực tiếp trong `res://sprite_frames/animals/<variant>_frames.tres`.

## Mapping NPC

Ô frame cố định 64 × 64, đọc trái sang phải, FPS 8. Giữ nguyên canvas của sheet.
Hàng trong bảng đánh số từ 1. Animation ngang gốc nhìn phải; hướng trái dùng `flip_h`.
Nhóm idle/walk xếp hướng xuống, phải, lên; nhóm tool/water xếp phải, xuống, lên.

| NPC | Hàng | Animation / số frame |
|---|---|---|
| Tất cả | 1–3 | `idle_down`, `idle_right`, `idle_up`: 6 frame, loop |
| Tất cả | 4–6 | `walk_down`, `walk_right`, `walk_up`: 6 frame, loop |
| Tất cả | 7 | `faint`: 4 frame, không loop |
| Farmer Bob, Farmer Buba | 8–10 | `tool_right`, `tool_down`, `tool_up`: 6 frame, không loop |
| Farmer Bob, Farmer Buba | 11–13 | `water_right`, `water_down`, `water_up`: 6 frame, không loop |
| Lumberjack Jack, Miner Mike | 8–10 | `tool_right`, `tool_down`, `tool_up`: 6 frame, không loop |
| Fisherman Fin | 8–9 | `cast_right`: 9 frame; `reel_right`: 8 frame, không loop |
| Fisherman Fin | 10–11 | `cast_down`: 9 frame; `reel_down`: 8 frame, không loop |
| Fisherman Fin | 12–13 | `cast_up`: 9 frame; `reel_up`: 8 frame, không loop |

Bartender Bruno, Bartender Katy và Chef Chloe chỉ có 7 hàng chung.
Tên `cast`/`reel` dựa trên quan sát thao tác thả/thu cần trong ảnh.

## Tạo lại

Mở `res://scripts/setup/setup_npc_sprite_frames.gd` trong Godot và chạy EditorScript
(File → Run). Generator dùng profile theo NPC, kiểm tra kích thước sheet, rồi lưu `.tres`.
PNG được giữ làm external resource, không phụ thuộc đường dẫn cache `.godot/imported`.
Script `setup_farmer_bob_frames.gd` vẫn tạo riêng Farmer Bob bằng cùng profile.
Generator động vật `setup_animal_sprite_frames.gd` cũng ghi trực tiếp vào folder `animals`.

Player dùng resource Farmer Bob tại đường dẫn mới; Chicken dùng resource trong `animals`.
UID của các resource đã có được giữ khi chuyển thư mục.
