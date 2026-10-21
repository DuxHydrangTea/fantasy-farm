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

Vật nuôi trưởng thành sau 24 giờ và chết khi đủ 14 ngày tuổi thực, gồm cả thời gian offline.
Sản xuất được chặn tại mốc chết; phụ phẩm đã hoàn tất vẫn thành pickup, trứng được thả trên bờ.
Animal chết khi restore hoặc trong capture không được ghi lại vào danh sách sống; `animal_pens`
ngăn đàn mặc định hồi sinh. Schema 5 giữ nguyên: `age` và `saved_at` đã đủ để tính các mốc này.

## File và phục hồi

`save_schema.gd` kiểm tra DTO version 10, giá trị số hữu hạn, số lượng, ID, ô trùng và liên kết sản phẩm. Version 1 được thêm vườn hoa; version 2 được chuyển từ grid hoa 10 × 6 sang 18 × 10 trong bộ nhớ, giữ nguyên vị trí vật lý và tiến độ hoa cũ. Version 3 được thêm ví 1.000 xu một lần; version 4 lưu số xu nguyên cùng inventory. Version 4 được mở rộng túi từ 24 lên 64 ô, giữ nguyên toàn bộ slot cũ và hotbar; sau đó version 5 được migrate sang version 6 với số cột đất đã mở. Vườn có 180 chậu, gồm 8 chậu trồng sẵn và nguồn hạt ban đầu, sau đó lưu cả trạng thái chậu và hạt đã nhặt. `save_catalog.gd` ánh xạ ID sang resource được đóng gói, không load đường dẫn do file cung cấp. Adapter kiểm tra thế giới hiện tại trước khi thay đổi dữ liệu.

File chứa payload JSON và SHA-256 của chính chuỗi payload. Checksum phát hiện lỗi dữ liệu, không phải mã hóa/chống sửa save. Backend ghi/flush/đọc kiểm tra `.tmp`, chuyển primary hợp lệ thành `.bak`, rồi rename `.tmp` thành primary. Nếu lỗi giữa các bước, bản dự phòng vẫn đọc được. Primary hỏng sẽ thử `.bak`; primary thuộc phiên bản mới hơn sẽ bị từ chối để tránh hạ phiên bản và mất dữ liệu. Không có backup hợp lệ hoặc thế giới không tương thích: giữ file và tắt tự lưu. Không tự ghi game mới đè lên file hỏng. Đã phục hồi `.bak` thì lần lưu kế tiếp chỉ xoay bản hợp lệ, không đè backup bằng primary hỏng.

## Chuẩn bị cho online

`save_manager.gd` điều phối capture/restore và trạng thái busy. `world_state_adapter.gd` dùng FarmWorld/FarmPlayer và tham chiếu typed được scene gán, không tìm Player/component bằng tên node; `save_schema.gd` chỉ biết DTO. `save_repository.gd` là hợp đồng backend:

```gdscript
read_profile(profile_id: String) -> Dictionary
# {ok: true, found: false} hoặc {ok: true, found: true, snapshot: {...}}
write_profile(profile_id: String, snapshot: Dictionary, expected_revision: int) -> Dictionary
# {ok: true, revision: N} hoặc {ok: false, code: "conflict", error: "..."}
write_profile_async(profile_id: String, snapshot: Dictionary, expected_revision: int) -> Dictionary
# Service dùng phương thức này; mặc định await write_profile của backend.
```

Service `await` read_profile và write_profile_async, nên backend HTTP có thể giữ coroutine write_profile hiện có thông qua fallback. LocalSaveRepository chuyển JSON/hash/I/O của write_profile_async sang Thread, copy DTO trước await, validate Resource/catalog trên main thread và join trước khi báo lưu xong. API write_profile sync vẫn phục vụ test/công cụ. Revision và fingerprint vẫn được kiểm tra để phát hiện thay đổi bên ngoài. Inject backend vào `SaveManager.bind_world(world, backend, profile_id)` trước khi bind mặc định; bootstrap MainWorld hiện dùng file local. Test dùng repository bất đồng bộ giả và file thật để kiểm tra giao diện này. Bản hiện tại **chưa có đồng bộ cloud, đăng nhập hay multiplayer**.

Online cần server xác thực người dùng/quyền hồ sơ, kiểm tra DTO và luật chơi, cấp thời gian chuẩn, giới hạn payload, áp dụng `expected_revision` bằng transaction/CAS và trả conflict khi revision cũ. Backend local chỉ bảo vệ khỏi revision đã đổi lúc kiểm tra; không hỗ trợ hai process ghi cùng lúc. Với network mất kết nối sau khi server đã commit, thiết kế idempotency key cho thao tác ghi, đọc đối chiếu revision và UI xử lý conflict/retry. Không tự lấy snapshot có timestamp lớn nhất để hợp nhất túi đồ/sản phẩm vì sẽ gây nhân đôi hoặc mất đồ. Migration schema cần chạy trước validate và có test; phiên bản không được hỗ trợ hiện bị từ chối.

## Kiểm tra

GUT: `tests/unit/test_save_repository.gd`, `tests/integration/test_world_persistence.gd`. Các test dùng file thật trong `.godot`, roundtrip MainWorld, phục hồi backup/checksum, revision cũ, phiên bản mới, dữ liệu không hợp lệ, sản xuất offline không trùng, ID sau rename, đồ đã nhặt và thay backend bất đồng bộ. Không bind hồ sơ thật từ fixture GUT.

Tiền xu và mua hàng: xem [Cửa hàng](shops.md). Save v4 bắt buộc trường `coins` trong khoảng 0–1.000.000.000; tải save cũ tự migrate, không chỉnh trực tiếp file người chơi trong quá trình phát triển.

Save v5 dùng túi mặc định 64 ô. Migration v4 chỉ thêm ô trống sau 24 ô cũ, không đổi item/count, selected_slot, tiền hoặc các tiến trình khác. Custom fixture có số slot khác được giữ để backend vẫn kiểm tra độc lập; adapter kiểm tra số slot của thế giới thực trước restore.

## Schema v6: farmland ownership

`land_columns` records 1…48 contiguous unlocked columns from the right of the
48 × 34 planting rectangle. Existing v1…v5 saves migrate without losing crops,
soil, currency or items: all columns needed to contain existing tilled plots
remain open. See [farmland expansion](land_expansion.md).

## Schema v7: boosters

Crop rows store `fertilized`; animal rows store `juvenile_tonic_used` and
`tonic_pending`. v1…v6 saves migrate with false flags. Restore applies them before
offline catch-up so one-use effects cannot be reapplied or lost. See
[boosters](boosters.md) for details.

## Schema v8: retained trough feed

Each trough row stores integer `feed_reserve`. Automatic E/click refilling keeps
the unused portion of a feed pack here, and spends it on later fills of the same
trough. v1…v7 snapshots migrate to zero reserve without changing the input DTO.
World preflight rejects a water reserve or a food reserve at least as large as
one configured pack before mutating inventory, wallet or world. Capture/restore
preserves the reserve with stock and persistent trough ID. See
[unified interaction](unified_interaction.md).

## Schema v9: beehives and pollination

`beehives` records persistent ID, placement, capped work, per-species pollen
contributions and ready honey. Crop rows add `pollination_reduction` so fertilizer
continues to use the original duration. v1…v8 migration gives empty hives/zero
reduction without resetting existing data. Preflight rejects corrupt work, pollen,
outputs and placements before mutation; offline replay splits at bloom/maturity
boundaries. See [beehives](beehives.md).

### Schema 10: weather and soil moisture

Version 9 migrates without resetting progress. `weather` stores the deterministic
seed and timestamped same-day overrides; `soil[].moisture` stores the remaining
normal-rate seconds before drying. Restore these before time catch-up. See
[weather.md](weather.md) for the 06:00 UTC+7 daily boundary and modifiers.
