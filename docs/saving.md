# Lưu tiến trình

MainWorld tự tải hồ sơ `local` khi mở game. Tự lưu mỗi 30 giây, khi mất focus và khi đóng cửa sổ bình thường. **F5** lưu nhanh, **F9** tải lại lần lưu gần nhất. Tải lại sẽ bỏ các thay đổi chưa lưu. Thông báo trên màn hình cho biết kết quả; lỗi ghi file không tăng revision và có thể thử lại. Nếu lưu khi thoát thất bại, game giữ cửa sổ mở; F5 để thử lại, hoặc đóng lần nữa để thoát không lưu. Kill process/mất điện chỉ giữ được lần ghi đã hoàn tất.

File: `user://saves/profile_local.json` (Godot: Project → Open User Data Folder; Windows mặc định `%APPDATA%/Godot/app_userdata/fantasy-farm/saves/`). `.bak` là lần lưu hợp lệ trước đó; `.tmp` dùng trong lúc ghi. Không có file nào trong thư mục dự án bị dùng làm save thật. GUT dùng thư mục tạm riêng dưới `.godot/save_tests`.

## Dữ liệu được lưu

- Vị trí/hướng người chơi, hotbar đang chọn, đầy đủ slot và số lượng túi đồ.
- Ô đất đã cuốc/tưới theo tọa độ logic; khôi phục qua terrain connect, giữ đường nối. Cây trồng: loại, thời điểm gieo/chín, tiến độ đã đạt.
- Vật nuôi: ID, loài, skin, chuồng, vị trí/hướng, tuổi, no/nước, phần chu kỳ sản xuất và sản phẩm chưa thu. Cả 47 vật nuôi khởi tạo (18 gà/gà trống, 18 bò/cừu, 11 vịt/ngỗng) dùng cùng cơ chế; số lượng thực tế lấy từ world lúc lưu.
- Vườn hoa: ID vườn, ô chậu có hoa, loại hoa, mốc gieo/tưới/chín, tiến độ và cờ đã cấp hoa trồng sẵn. Chậu không có trong danh sách là chậu trống; vật phẩm hạt/hoa dùng cùng dữ liệu inventory/pickup.
- Lượng thức ăn/nước và vị trí các máng; vật phẩm còn trên đất, số lượng và liên kết đống sản phẩm với vật nuôi tạo ra nó.
- ID chuồng đã khởi tạo (`animal_pens`): chuồng mới như PondPen nhận đàn/máng ban đầu khi tải save cũ; sau khi lưu, vật nuôi bị xóa không tự hồi sinh. Trứng vịt còn dưới nước được giữ trong production stock cho tới khi lên bờ.

Các entity đặt sẵn trong MainWorld có `persistent_id` lưu ngay trong scene; đổi tên node vẫn tải được. Entity sinh khi chơi nhận ID ngẫu nhiên một lần. Khi thêm chuồng/máng mới trong editor, gán `persistent_id` riêng và không sao chép ID của node cũ. Không đổi các ID đã phát hành nếu chưa có migration. Danh sách vật nuôi/vật phẩm được thay thế hoàn toàn khi tải, nên không hồi sinh đồ đã nhặt. Animation đang chạy, đường đi, mục tiêu ăn/uống và reservation được reset; không lưu NodePath, RID hay instance ID.

Địa hình nền, hàng rào, công trình, scatter và thông số thiết kế vẫn lấy từ scene. Chưa có hệ thống xây/dỡ công trình trong runtime; khi thêm tính năng đó cần thêm DTO và test tương ứng. Đổi cấu trúc túi đồ, danh sách chuồng/máng, ID resource hoặc chu kỳ sản xuất có thể cần migration.

## Thời gian offline

Timestamp Unix dùng TimeManager hiện có. Cây lớn tới thời điểm chín đã lưu. Vật nuôi tăng tuổi và giảm no/nước; sản xuất chỉ tính phần thời gian còn đủ no và nước, sau tuổi trưởng thành. Không giả lập đi lại, tự tìm máng hoặc tiêu thụ thức ăn trong thời gian đóng game. Sản phẩm offline cộng vào đúng đống đã lưu. Clock quay lùi không làm mất tiến độ đã đạt. Clock của máy vẫn có thể bị chỉnh trong bản offline.

## File và phục hồi

`save_schema.gd` kiểm tra DTO version 2, giá trị số hữu hạn, số lượng, ID, ô trùng và liên kết sản phẩm. Version 1 được migrate trong bộ nhớ để thêm vườn hoa; lần lưu tiếp theo ghi version 2. Vườn mới có 60 chậu, gồm 8 chậu trồng sẵn và nguồn hạt ban đầu, sau đó lưu cả trạng thái chậu và hạt đã nhặt. `save_catalog.gd` ánh xạ ID sang resource được đóng gói, không load đường dẫn do file cung cấp. Adapter kiểm tra thế giới hiện tại trước khi thay đổi dữ liệu.

File chứa payload JSON và SHA-256 của chính chuỗi payload. Checksum phát hiện lỗi dữ liệu, không phải mã hóa/chống sửa save. Backend ghi/flush/đọc kiểm tra `.tmp`, chuyển primary hợp lệ thành `.bak`, rồi rename `.tmp` thành primary. Nếu lỗi giữa các bước, bản dự phòng vẫn đọc được. Primary hỏng sẽ thử `.bak`; primary thuộc phiên bản mới hơn sẽ bị từ chối để tránh hạ phiên bản và mất dữ liệu. Không có backup hợp lệ hoặc thế giới không tương thích: giữ file và tắt tự lưu. Không tự ghi game mới đè lên file hỏng. Đã phục hồi `.bak` thì lần lưu kế tiếp chỉ xoay bản hợp lệ, không đè backup bằng primary hỏng.

## Chuẩn bị cho online

`save_manager.gd` điều phối capture/restore và trạng thái busy. `world_state_adapter.gd` dùng FarmWorld/FarmPlayer và tham chiếu typed được scene gán, không tìm Player/component bằng tên node; `save_schema.gd` chỉ biết DTO. `save_repository.gd` là hợp đồng backend:

```gdscript
read_profile(profile_id: String) -> Dictionary
# {ok: true, found: false} hoặc {ok: true, found: true, snapshot: {...}}
write_profile(profile_id: String, snapshot: Dictionary, expected_revision: int) -> Dictionary
# {ok: true, revision: N} hoặc {ok: false, code: "conflict", error: "..."}
```

Service `await` cả hai phương thức, nên backend HTTP có thể trả coroutine. Inject backend vào `SaveManager.bind_world(world, backend, profile_id)` trước khi bind mặc định; bootstrap MainWorld hiện dùng file local. Test dùng repository bất đồng bộ giả để kiểm tra giao diện này. Bản hiện tại **chưa có đồng bộ cloud, đăng nhập hay multiplayer**.

Online cần server xác thực người dùng/quyền hồ sơ, kiểm tra DTO và luật chơi, cấp thời gian chuẩn, giới hạn payload, áp dụng `expected_revision` bằng transaction/CAS và trả conflict khi revision cũ. Backend local chỉ bảo vệ khỏi revision đã đổi lúc kiểm tra; không hỗ trợ hai process ghi cùng lúc. Với network mất kết nối sau khi server đã commit, thiết kế idempotency key cho thao tác ghi, đọc đối chiếu revision và UI xử lý conflict/retry. Không tự lấy snapshot có timestamp lớn nhất để hợp nhất túi đồ/sản phẩm vì sẽ gây nhân đôi hoặc mất đồ. Migration schema cần chạy trước validate và có test; phiên bản không được hỗ trợ hiện bị từ chối.

## Kiểm tra

GUT: `tests/unit/test_save_repository.gd`, `tests/integration/test_world_persistence.gd`. Các test dùng file thật trong `.godot`, roundtrip MainWorld, phục hồi backup/checksum, revision cũ, phiên bản mới, dữ liệu không hợp lệ, sản xuất offline không trùng, ID sau rename, đồ đã nhặt và thay backend bất đồng bộ. Không bind hồ sơ thật từ fixture GUT.
