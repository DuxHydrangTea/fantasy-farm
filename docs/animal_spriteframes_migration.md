# Danh sách animation động vật để chuẩn bị migrate SpriteFrames

**Cập nhật 06/10/2026:** 93 SpriteFrames động vật hiện nằm trực tiếp trong
`res://sprite_frames/animals`. Generator `setup_animal_sprite_frames.gd` đã cập nhật
đường dẫn này. Các ghi chú đề xuất bên dưới giữ lại theo thời điểm rà soát ban đầu.

Ngày rà soát: 04/10/2026. Nguồn: `res://assets/Animals`.

Đây là bản đề xuất để review, chưa phải cấu hình generator đã chốt. Chưa tạo `.tres`, chưa đổi script hoặc scene.

## Quy ước và bằng chứng

- Có 13 thư mục loài, tổng cộng 98 PNG. Rooster được tính trong Chicken.
- Hàng và cột trong tài liệu đánh số từ **1**. Khi viết generator, chuyển về chỉ số từ 0.
- Frame đọc từ trái sang phải; chỉ lấy số frame ghi trong bảng, bỏ các ô trống ở cuối hàng.
- Số frame của 10 loài dạng sheet 32 × 32 đã được đếm bằng kiểm tra alpha của từng ô trên tất cả biến thể. Các biến thể trong cùng loài có cùng dãy số frame.
- Tên state dựa trên mapping người dùng và quan sát chuỗi frame phóng lớn của ảnh đại diện. Chưa xác minh bằng phát animation trong Godot; không coi tên suy luận là tên gốc của tác giả.
- **Cao**: hành vi có dấu hiệu rõ (Z khi ngủ, chớp trắng khi hurt, chuyển tư thế nằm/đứng) hoặc mapping người dùng phù hợp hình ảnh. **Vừa**: hành vi hợp lý nhưng còn có cách gọi khác. **Thấp**: chưa đủ bằng chứng để gán ý nghĩa.
- `loop` trong bảng là **đề xuất**; FPS chưa chốt. State chuyển tư thế/hurt/attack thường không loop; idle/walk/sleep thường loop.
- Không tạo state cho hướng hoặc hành vi không có trong asset chỉ để đủ một bộ chung.

## Tổng quan 13 loài

| Loài | Nguồn/biến thể | Kích thước PNG | Ô frame | Bố cục |
|---|---|---|---|---|
| Bee | `Bee_Flying_Animation.png`; 2 hàng cần phân biệt | 64 × 32 | 16 × 16 | 2 hàng × 4 frame |
| Butterfly | `Butterfly.png`; 8 hàng màu | 16 × 64 | 8 × 8 | 8 biến thể, mỗi biến thể 2 frame |
| Chicken | `Chicken_01`…`Chicken_18`, `Rooster` | 256 × 512 | 32 × 32 | 16 hàng, 8 cột |
| Cow | `Cow_01`…`Cow_09` | 256 × 480 | 32 × 32 | 15 hàng, 8 cột |
| Duck | `Duck_01`…`Duck_04`, `Duck_in_a_hat` | 256 × 640 | 32 × 32 | 20 hàng, 8 cột |
| Frog | `Frog_01`…`Frog_06` | 320 × 128 | 32 × 32 | 4 hàng, 10 cột |
| Goose | `Goose_01`…`Goose_06` | 384 × 512 | 32 × 32 | 16 hàng, 12 cột |
| Horse | `Horse_01`…`Horse_05` | 256 × 480 | 32 × 32 | 15 hàng, 8 cột |
| Kapybara | Thường và Albino; mỗi biến thể 6 file trong `Static` | Cao 32; rộng 288…800 | 32 × 32 | Mỗi file là một dải hành động |
| Mouse | `Mouse_01`…`Mouse_04` | 320 × 128 | 32 × 32 | 4 hàng, 10 cột |
| Pig | `Pig_01`…`Pig_16` | 288 × 480 | 32 × 32 | 15 hàng, 9 cột |
| Sheep | `Sheep_01`…`Sheep_09` | 256 × 480 | 32 × 32 | 15 hàng, 8 cột |
| Swan | `Swan_01`…`Swan_03` | 256 × 640 | 32 × 32 | 20 hàng, 8 cột |

## 1–4. Cow, Horse, Pig, Sheep

Có thể chia sẻ thứ tự/tên state đề xuất, nhưng **phải dùng số frame riêng cho từng loài**. Hướng ngang gốc là trái. Cow/Horse dựa trên mapping người dùng; Pig/Sheep suy luận theo chuyển động tương ứng trên ảnh.

| Hàng | State đề xuất | Cow | Horse | Pig | Sheep | Loop | Ý nghĩa / độ chắc chắn |
|---|---|---:|---:|---:|---:|---|---|
| 1 | `idle_left` | 2 | 2 | 2 | 2 | Có | Đứng nhìn trái — Cao |
| 2 | `idle_down` | 2 | 2 | 2 | 2 | Có | Đứng trực diện — Cao |
| 3 | `idle_up` | 2 | 2 | 2 | 2 | Có | Đứng quay lưng — Cao |
| 4 | `walk_left` | 8 | 6 | 8 | 8 | Có | Đi trái — Cao |
| 5 | `walk_down` | 8 | 6 | 8 | 8 | Có | Đi xuống — Cao |
| 6 | `walk_up` | 8 | 6 | 8 | 8 | Có | Đi lên — Cao |
| 7 | `graze_left` | 8 | 8 | 9 | 8 | Có | Cúi đầu ăn; Pig có thể gọi `eat_left`/`sniff_left` — Vừa |
| 8 | `chew_left` | 8 | 6 | 6 | 8 | Có | Đứng nhai/vẫy tai, đuôi; tên `idle_chew_left` cũng phù hợp — Vừa |
| 9 | `lie_down_left` | 6 | 6 | 4 | 4 | Không | Từ đứng hạ mình nằm — Cao |
| 10 | `stand_up_left` | 6 | 6 | 4 | 4 | Không | Từ nằm đứng dậy — Cao |
| 11 | `sleep_start_left` | 4 | 4 | 4 | 4 | Không | Đang nằm hạ đầu/nhắm mắt; alias `rest_head_left` — Cao |
| 12 | `sleep_left` | 8 | 8 | 8 | 8 | Có | Nằm ngủ, có Z — Cao |
| 13 | `hurt_left` | 4 | 4 | 4 | 4 | Không | Chớp trắng nhìn trái — Cao |
| 14 | `hurt_down` | 4 | 4 | 4 | 4 | Không | Chớp trắng trực diện — Cao |
| 15 | `hurt_up` | 4 | 4 | 4 | 4 | Không | Chớp trắng quay lưng — Cao |

Các khác biệt so với mapping ban đầu: Horse hàng 4–6 và 8 chỉ có 6 frame; Pig hàng 7 có 9, hàng 8 có 6, hàng 9–10 có 4; Sheep hàng 9–10 có 4.

## 5–6. Chicken (gồm Rooster), Goose

Hai góc `down_left` và `up_left` giữ theo quy ước người dùng. Độ chắc chắn của nhãn góc: Vừa; cần kiểm tra tư thế khi phát trong Godot. Goose có thể dùng cùng tên state đề xuất với Chicken, nhưng hàng ăn có 12 frame thay vì 8.

| Hàng trước | Hàng sau | State `down_left` | State `up_left` | Chicken | Goose | Loop | Ý nghĩa / độ chắc chắn |
|---:|---:|---|---|---:|---:|---|---|
| 1 | 9 | `idle_down_left` | `idle_up_left` | 2 | 2 | Có | Đứng quan sát — Cao |
| 2 | 10 | `walk_down_left` | `walk_up_left` | 6 | 6 | Có | Đi — Cao |
| 3 | 11 | `peck_down_left` | `peck_up_left` | 8 | 12 | Có | Cúi đầu mổ/ăn — Cao |
| 4 | 12 | `sit_down_left` | `sit_up_left` | 3 | 3 | Không | Hạ mình ngồi — Cao |
| 5 | 13 | `sleep_start_down_left` | `sleep_start_up_left` | 3 | 3 | Không | Ngồi rồi hạ đầu/nhắm mắt — Vừa |
| 6 | 14 | `stand_up_down_left` | `stand_up_up_left` | 3 | 3 | Không | Ngồi đứng dậy — Cao |
| 7 | 15 | `sleep_down_left` | `sleep_up_left` | 8 | 8 | Có | Ngủ, có Z — Cao |
| 8 | 16 | `hurt_down_left` | `hurt_up_left` | 4 | 4 | Không | Chớp trắng nhận sát thương — Cao |

**Khác với khai báo ban đầu:** người dùng gọi hàng 5/13 là `sleep`, 7/15 là `cluck`/`scratch`, 8/16 là `flap`/`hop`. Ảnh thể hiện Z ở 7/15 và chớp trắng ở 8/16, nên đề xuất đổi thành `sleep` và `hurt`; hàng 5/13 thành `sleep_start`. Đây là thay đổi đề xuất để review, chưa phải quyết định đã được người dùng chốt.

## 7–8. Duck, Swan

Hai góc giữ quy ước `down_left`/`up_left` như người dùng, độ chắc chắn của nhãn góc: Vừa. Bộ state đề xuất tương ứng nhau; số frame bơi hàng 9/19 khác nhau.

| Hàng trước | Hàng sau | State `down_left` | State `up_left` | Duck | Swan | Loop | Ý nghĩa / độ chắc chắn |
|---:|---:|---|---|---:|---:|---|---|
| 1 | 11 | `idle_down_left` | `idle_up_left` | 2 | 2 | Có | Đứng trên cạn — Cao |
| 2 | 12 | `walk_down_left` | `walk_up_left` | 6 | 6 | Có | Đi trên cạn — Cao |
| 3 | 13 | `sit_down_left` | `sit_up_left` | 3 | 3 | Không | Hạ mình ngồi — Cao |
| 4 | 14 | `stand_up_down_left` | `stand_up_up_left` | 3 | 3 | Không | Đứng dậy — Cao |
| 5 | 15 | `sleep_start_down_left` | `sleep_start_up_left` | 3 | 3 | Không | Hạ đầu/chuẩn bị ngủ — Vừa |
| 6 | 16 | `sleep_down_left` | `sleep_up_left` | 8 | 8 | Có | Ngủ trên cạn, có Z — Cao |
| 7 | 17 | `hurt_down_left` | `hurt_up_left` | 4 | 4 | Không | Chớp trắng — Cao |
| 8 | 18 | `swim_idle_down_left` | `swim_idle_up_left` | 2 | 2 | Có | Nổi trên nước — Cao |
| 9 | 19 | `swim_down_left` | `swim_up_left` | 4 | 3 | Có | Chuyển động trên nước; cần xem tốc độ khi phát — Vừa |
| 10 | 20 | `swim_sleep_down_left` | `swim_sleep_up_left` | 8 | 8 | Có | Ngủ trên nước, có Z — Cao |

**Khác với khai báo ban đầu:** hàng 6/16 từng được gọi `quack`/`peck`, nhưng có Z nên đề xuất `sleep`. Hàng 10/20 từng được gọi `swim_fast`/`swim_quack`, nhưng cũng có Z nên đề xuất `swim_sleep`. Hàng 5/15 đổi tên đề xuất từ `sleep` sang `sleep_start` để phân biệt quá trình với vòng ngủ. Swan hàng 9/19 chỉ có 3 frame.

## 9. Frog

Nguồn: `Frog_01`…`Frog_06`. Hướng ngang đề xuất là **phải**, vì mặt và lưỡi hướng sang phải; không dùng mặc định `left` của gia súc.

| Hàng | State đề xuất | Frame | Loop | Ý nghĩa | Chắc chắn |
|---:|---|---:|---|---|---|
| 1 | `idle_right` | 2 | Có | Ngồi chờ, thân nhấp nhô | Cao |
| 2 | `croak_right` | 8 | Không | Phồng vùng bụng/cổ rồi xẹp, giống kêu ộp ộp | Vừa |
| 3 | `tongue_attack_right` | 10 | Không | Phóng và thu lưỡi; có thể dùng `catch_insect_right` nếu logic là kiếm ăn | Cao |
| 4 | `hurt_right` | 4 | Không | Chớp trắng | Cao |

Không có bằng chứng rõ để đặt hàng 2 thành `walk` hoặc `jump`. Không tự thêm animation di chuyển cho Frog.

## 10. Mouse

Nguồn: `Mouse_01`…`Mouse_04`. Hướng ngang đề xuất **phải**, theo vị trí mặt và thức ăn.

| Hàng | State đề xuất | Frame | Loop | Ý nghĩa | Chắc chắn |
|---:|---|---:|---|---|---|
| 1 | `idle_right` | 6 | Có | Thân nhấp nhô, đầu hạ rồi nâng; có thể là `sniff_right` | Vừa |
| 2 | `walk_right` | 6 | Có | Chân/thân thay đổi giống bước chạy; có thể gọi `run_right` | Vừa |
| 3 | `eat_right` | 10 | Có | Cầm/gặm miếng thức ăn màu vàng | Cao |
| 4 | `hurt_right` | 4 | Không | Chớp trắng | Cao |

Hai hàng đầu là nơi ưu tiên review bằng playback; tên `idle`/`walk` là đề xuất, số frame đã đếm chắc chắn.

## 11. Bee

Nguồn animation: `Bee_Flying_Animation.png`, ô 16 × 16, 4 cột × 2 hàng. Hai hàng đều mô tả đập cánh; khác biệt chi tiết giữa hai hàng chưa được xác định.

| Hàng | Tên tạm để giữ đủ dữ liệu | Frame | Loop | Chắc chắn |
|---:|---|---:|---|---|
| 1 | `fly` | 4 | Có | Cao cho hành vi bay; Thấp cho vai trò riêng của hàng |
| 2 | `fly_alt` | 4 | Có | Cao cho hành vi bay; Thấp cho ý nghĩa khác biệt |

Không nối hai hàng thành animation 8 frame khi chưa rõ chúng là hai biến thể hay hai chế độ. Có thể tách thành hai biến thể cùng state `fly` sau khi review; `fly_alt` chỉ là tên tạm, không khẳng định đây là state gameplay khác.

`Bee_Hive.png` (16 × 16) và `Bee_Nest.png` (32 × 48) là hình tổ tĩnh. Loại khỏi generator động vật; nếu cần hiển thị thì dùng texture riêng.

## 12. Butterfly

Nguồn: `Butterfly.png` (16 × 64). Chia ô **8 × 8**: 2 cột × 8 hàng. Mỗi hàng là một màu với hai tư thế cánh; không coi mỗi hàng là một state.

| Hàng | ID biến thể đề xuất | State | Frame/cột | Loop | Màu quan sát |
|---:|---|---|---|---|---|
| 1 | `butterfly_01` | `fly` | 2 / cột 1–2 | Có | Xanh cyan |
| 2 | `butterfly_02` | `fly` | 2 / cột 1–2 | Có | Xanh lá |
| 3 | `butterfly_03` | `fly` | 2 / cột 1–2 | Có | Vàng |
| 4 | `butterfly_04` | `fly` | 2 / cột 1–2 | Có | Đỏ |
| 5 | `butterfly_05` | `fly` | 2 / cột 1–2 | Có | Hồng/tím nhạt |
| 6 | `butterfly_06` | `fly` | 2 / cột 1–2 | Có | Tím đậm |
| 7 | `butterfly_07` | `fly` | 2 / cột 1–2 | Có | Đỏ/vàng |
| 8 | `butterfly_08` | `fly` | 2 / cột 1–2 | Có | Xanh cyan, phối màu khác |

Độ chắc chắn: Cao cho bố cục hai tư thế cánh theo hàng; Vừa cho mô tả màu. Dùng ID theo hàng thay vì tên màu để tránh gộp nhầm những màu gần nhau. Dự kiến một SpriteFrames cho mỗi hàng màu.

## 13. Kapybara

Giữ đúng cách viết `Kapybara` của thư mục nguồn. Có hai biến thể: `Kapybara_*` và `Albino_Kapybara_*`, nằm trong `res://assets/Animals/Kapybara/Static`. Tên thư mục `Static` không có nghĩa ảnh chỉ có một frame.

Mỗi file chứa một hàng, ô 32 × 32. Gom sáu file cùng tiền tố vào một SpriteFrames. Các state không thêm hậu tố hướng vì có động tác tự quay nhìn trong cùng dải, chưa có bộ di chuyển theo hướng.

| Hậu tố file | State đề xuất | Kích thước | Frame | Loop | Ý nghĩa / độ chắc chắn |
|---|---|---|---:|---|---|
| `Idle.png` | `idle` | 288 × 32 | 9 | Có | Nghỉ trên nước — Cao |
| `LookAround.png` | `look_around` | 320 × 32 | 10 | Không | Quay đầu quan sát khi thân nổi — Cao |
| `Dive.png` | `dive` | 288 × 32 | 9 | Không | Hạ mình chìm xuống — Cao |
| `LookAround_submerged.png` | `look_around_submerged` | 288 × 32 | 9 | Không | Quan sát khi thân chìm, đầu nổi — Cao |
| `Bubbles.png` | `bubbles` | 800 × 32 | 25 | Có | Đầu nổi thấp, hiệu ứng gợn/bọt nước — Vừa cho loop, Cao cho tên theo file |
| `Emerge.png` | `emerge` | 320 × 32 | 10 | Không | Nâng mình nổi lên — Cao |

`Bubbles` không được tự đổi thành `swim` hay `sleep`: tên file và hình không đủ chứng minh các hành vi đó. Chưa suy ra trình tự state machine từ các file này.

## Các điểm cần lưu ý cho đợt migrate

1. **Profile riêng theo loài.** Cow/Horse/Pig/Sheep có thể chia sẻ tên state nhưng khác số frame; Chicken/Goose và Duck/Swan tương tự. Chỉ các biến thể trong cùng loài dùng chung đầy đủ profile.
2. **Tách action khỏi hướng một cách tường minh.** Các tên như `stand_up_up_left`, `swim_idle_down_left` có nhiều dấu gạch dưới; không lấy mỗi từ cuối hoặc đầu để suy ra action/direction.
3. **Hướng gốc khác nhau.** Gia súc/gia cầm dùng trái; Frog/Mouse đề xuất dùng phải; Bee/Butterfly/Kapybara dùng tên không có hướng. Có thể tạo hướng đối diện bằng `flip_h` trong runtime, không cần nhân đôi atlas.
4. **AnimationComponent hiện chưa tương thích toàn bộ danh sách.** Component hiện ghép `action_direction` với bốn hướng và lật trái từ animation phải. Đợt migrate cần cấu hình hướng nguồn, hỗ trợ góc chéo và animation không có hậu tố hướng; fallback `idle_down` cũng không tồn tại ở nhiều loài. Đây là ghi chú cho lần triển khai sau, chưa sửa component.
5. **Giữ đúng frame canvas.** Không crop sát hình từng frame: dễ làm vị trí sprite nhảy. Dùng đúng ô 32/16/8 px theo profile.
6. **Kế hoạch output đề xuất:** `res://resources/animals/<species>/<variant>_frames.tres`. Mỗi biến thể một resource; riêng Butterfly lấy biến thể từ hàng, Kapybara gom từ nhiều file. Chưa tạo thư mục output.
7. **Review tập trung:** mapping ngủ/hurt của gia cầm và thủy cầm khác khai báo ban đầu; Mouse hàng 1–2; Frog hàng 2; khác biệt hai hàng Bee; FPS/loop và hướng chéo. Các tên trong tài liệu là bản đề xuất có thể sửa trước khi generate.

## Dãy số frame để đối chiếu nhanh

```text
Cow:     2,2,2,8,8,8,8,8,6,6,4,8,4,4,4
Horse:   2,2,2,6,6,6,8,6,6,6,4,8,4,4,4
Pig:     2,2,2,8,8,8,9,6,4,4,4,8,4,4,4
Sheep:   2,2,2,8,8,8,8,8,4,4,4,8,4,4,4
Chicken: 2,6,8,3,3,3,8,4,2,6,8,3,3,3,8,4
Goose:   2,6,12,3,3,3,8,4,2,6,12,3,3,3,8,4
Duck:    2,6,3,3,3,8,4,2,4,8,2,6,3,3,3,8,4,2,4,8
Swan:    2,6,3,3,3,8,4,2,3,8,2,6,3,3,3,8,4,2,3,8
Frog:    2,8,10,4
Mouse:   6,6,10,4
Bee:     4,4 (16 × 16)
Butterfly: 2,2,2,2,2,2,2,2 (8 × 8; mỗi hàng một biến thể)
Kapybara: idle=9, look_around=10, dive=9,
          look_around_submerged=9, bubbles=25, emerge=10
```
