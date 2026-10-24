# Cỏ, bụi, hoa và nấm trang trí — GPU

Ngày 25/10/2026. Mở rộng từ bốn loại cỏ thành **80 mẫu trong Outdoor_Decor.png**: cỏ, bụi xanh, hoa thấp, nụ hoa, hoa cao, hoa súng, bèo, cây thủy sinh và **đầy đủ 10 mẫu nấm**. Map hiện có **815 cụm** thuộc danh sách này; tất cả nhận gió thời tiết và lực nghiêng từ player/vật nuôi.

## Đặt thêm trong Godot

Mở `world/main_world.tscn`, chọn **TinyDecor**, chọn atlas `assets/Outdoor decoration/Outdoor_Decor.png`, vẽ mẫu trong danh sách sau rồi lưu và chạy lại. Không cần thêm node hoặc giới hạn vùng. Tọa độ bên dưới là `(cột, hàng)` trong atlas, bắt đầu từ 0. Đơn vị atlas là **16×16 pixel**, khác lưới logic 4px của World. Hoa cao dùng nguyên tile 16×32 hoặc 32×32, không cắt thành các mảnh 16px.

| Hàng atlas | Các cột được hỗ trợ |
|---|---|
| 0 | 0–5 |
| 1 | 0–8 |
| 2 | 0–8 |
| 3 | 0–8 |
| 4 | 0–3 |
| 5 | 2, 4–5 |
| 6 | 2 |
| 7 | 8 |
| 8 | 6–8 |
| 9 | 3, 5–8 |
| 15, 16 | 6 |
| 17, 18, 19 | 5–8 |
| 20 | 4–8 |
| 21, 23 | 4, 5, 7–8 |
| 22, 24, 25 | 4 |

Đã bổ sung **năm mẫu bụi xanh** tại **(5,5), (3,9), (5,9), (6,9), (7,9)**, gồm những bụi trong ảnh người dùng. **Tảng đá (4,9)** giữa hàng bụi giữ nguyên.

Đã bổ sung nấm tại **(7,2), (8,2), (0..2,3), (0..2,4), (2,5), (2,6)** và sáu mẫu hoa lớn tại **(5,21), (7,21), (8,21), (5,23), (7,23), (8,23)**. Đá, gỗ và hàng rào vẫn đứng yên; không kéo lắc cả khúc gỗ chỉ vì trên đó có hình nấm.

Đây là hiệu ứng của foliage trang trí trên TinyDecor; không thay luật trồng/thu hoạch của cây trồng hay vườn hoa gameplay. Foliage vẫn đi xuyên qua được.

## Render và chi phí

- **138 cụm cỏ gốc** giữ renderer chunk hiện có.
- **677 cụm** dùng vertex shader ngay trên TileMap, gồm những loại mới và các cụm cần giữ thứ tự vẽ khi chồng đồ trang trí. Nhóm này cũng nghiêng trên GPU, không đứng yên.
- Các mẫu mới giữ nguyên UV nguồn của TileMap để tránh sai lệch nearest sampling ở zoom lẻ. Hai đường render dùng chung công thức gió, neo chân và lực actor trong `grass_field_core.gdshaderinc`.
- Vẫn chỉ thêm **một node GPUGrass**. Không thêm process, Tween hay collider cho từng cụm. Material dùng chung theo loại; adapter chỉ đồng bộ uniform đã thay đổi. Feed actor và việc gửi uniform vẫn có chi phí CPU.
- TileSet được clone cục bộ, không thay asset dùng chung hoặc dữ liệu cell serialized. F10 debug và fallback khôi phục TileSet/cells gốc. Không thêm trường vào save.

Danh sách authoring nằm trong `scripts/grass/build_farm_grass_assets.gd`; script đọc kích thước thật từ TileSet và tạo metadata chân từ pixel opaque. Diagnostic atlas có ô 32×32, tám frame giống nhau cho mỗi mẫu; runtime vẫn dùng texture gốc. Uniform table có sức chứa 128 loại; vượt giới hạn sẽ fallback thay vì đọc ngoài mảng.

Shader TileMap nhận cả chiều rộng/cao thực và vị trí chân. Hoa 32px có độ nghiêng chuẩn hóa theo chiều cao, không tăng gấp đôi biên độ chỉ vì sprite cao hơn. UV gốc, thứ tự Y-sort và toàn bộ hình hoa được giữ nguyên.

## Kiểm chứng

- **34/34 GUT, 1562 assertions**: pixel/root cho cả 80 mẫu và tám frame diagnostic; region đúng kích thước thật; không trùng, đầy đủ 10 nấm và 6 hoa lớn, đá/gỗ/hàng rào bị loại; quét toàn map, ô vẽ mới, source transaction, local TileSet và hồi quy G1–G4.
- **224/224 native checks mỗi renderer**, gồm toàn map 815 cụm, ngày/đêm, zoom 0,8/1,25, camera nhiều vị trí, fallback, save/restore, player và 86 vật nuôi thật. Kết quả cuối ở `flowers_mushrooms_gpu_2026-10-25/verification.json`.
- Palette QA đặt riêng cả 80 mẫu ở zoom 2, tắt overlay HUD để không che các hàng cuối. Cả đường render kết hợp và đường TileMap thuần so với ảnh nguồn trong sai số tối đa 1/255 khi tắt biến dạng; từng mẫu được kiểm tra thay đổi pixel khi cấp lực actor tại chân. Kiểm tra zoom lẻ 0,8/1,25 chạy trên map thật, không phải mọi mức zoom của palette.
- Hồi quy native G1: 189 checks mỗi renderer. Lint sạch, engine validation và Web export đạt. Browser runtime và điện thoại thật chưa được kiểm thử trong đợt này; G5 benchmark dài vẫn còn.

Ảnh, JSON, log của 80 mẫu: [flowers_mushrooms_gpu_2026-10-25](flowers_mushrooms_gpu_2026-10-25/). Các đợt cũ: [64 mẫu](foliage_bushes_2026-10-25/), [59 mẫu](foliage_gpu_2026-10-25/). `palette-source.png` là artwork gốc, `palette-pressure-false/true.png` là kiểm tra lực trên từng backend. Cường độ lực trong palette QA được đặt cao để đo rõ sự khác biệt, không phải cấu hình lực mặc định của gameplay.

Chạy lại native QA bằng `scripts/grass/run_grass_g1.py --phase g4 --godot ENGINE --output OUTPUT`, sau khi chuẩn bị staging bằng `scripts/build_web.py`. Scene preview F6 không bind save cá nhân: `tests/support/grass_gpu_farm_preview.tscn`.
