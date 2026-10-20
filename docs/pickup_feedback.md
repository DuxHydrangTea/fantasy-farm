# Hút vật phẩm và thông báo thu hoạch

`ItemCollector` của player có vùng hút mặc định 48 pixel, chỉnh bằng
`attraction_radius`. Khi túi có chỗ, `ItemPickup` cho sprite bay tăng tốc về
player đang di chuyển. Chỉ khi sprite tới đích mới chuyển đồ vào inventory.
Player đi quá xa (hai lần bán kính), collector bị xóa hoặc túi đầy giữa lúc bay
thì sprite trở về chỗ cũ; số lượng không mất. Nhả chỗ trong túi sẽ thử nhặt lại
các vật phẩm còn trong sensor. Các pickup khác như hạt hoa cũng dùng luồng này.

Vị trí Area2D và số lượng trên đất không thay đổi trong lúc sprite bay, nên
liên kết đống sản phẩm với vật nuôi và snapshot lưu giữa lúc hút vẫn đúng.
Không thêm dữ liệu hiệu ứng vào save, không cần đổi schema. Khi nhặt một phần,
phần dư ở nguyên điểm rơi; signal chỉ báo số lượng thực tế được thêm vào túi.

`ItemCollector.item_acquired` tạo thông báo `+N × [icon]` trên đầu player.
`FarmingController.harvest_yielded` tạo thông báo tại tâm ô đất; thu hoạch vẫn
đòi đủ chỗ cho toàn bộ yield. Chặn gọi thu hoạch lồng nhau từ inventory.changed.
Không hiện thông báo khi thu hoạch thất bại, mua hàng hoặc restore inventory.

`ItemGainFeedback` quản lý presentation; `ItemGainPopup` dùng Pixelify Sans và
icon của ItemDefinition, nảy nhẹ, bay lên rồi mờ trong 0,95 giây. Popup trên đầu
đi theo player; popup ô đất đứng tại vị trí thu hoạch. Nhặt cùng một loại liên tiếp
trong 0,15 giây gộp số trên thông báo, không gộp hay thay đổi giao dịch inventory.
Giới hạn 12 thông báo đang hiển thị mỗi player. Nếu thu hoạch và nhặt đồ cùng lúc
ở vị trí sát nhau, thông báo trên đầu được nâng lên để hai dòng không chồng nhau.
Load thành công xóa các thông báo cũ.

GUT bao gồm `test_pickup_feedback.gd`, `test_item_pickup.gd`, `test_crops.gd`
và test snapshot giữa lúc hút trong `test_world_persistence.gd`. Các test kiểm tra
bay trước khi chuyển đồ, túi đầy, phần dư, collector mất, đích di chuyển, icon/số
thực nhận, hết vòng đời, popup tại ô đất và lưu/tải không nhân đôi vật phẩm.

## Chuyển động cây và nông sản bật ra

Cây trồng và 4 mẫu cây lớn quanh map dùng chung shader `plant_wind.gdshader`.
Shader dịch đỉnh ảnh theo vị trí thế giới để mỗi cây có pha gió khác nhau, neo
cạnh dưới và giữ UV gốc; không đọc nhầm ô bên cạnh trong atlas. Không thêm
`_process` hoặc Tween lặp trên hàng nghìn cây. Biên độ nhỏ, chỉnh tại
`resources/effects/crop_wind.tres` và `tree_wind_32/48.tres` (0 để tắt gió).

`Crop` dùng Tween ngắn, thay thế Tween cũ khi có tác động: mọc nhú khi gieo,
nghiêng khi focus lần đầu/tưới/bắt đầu thu hoạch. Sprite xoay và co giãn quanh
chân cây, không đổi transform root, collision, tile hoặc timestamp lớn.
Focus lặp mỗi tick không khởi động lại chuyển động.

Khi thu hoạch thành công, transaction inventory vẫn commit đúng một lần tại
frame tác động. Cây rời danh sách logic ngay; hình ảnh co lại/mờ trong 0,16 giây.
Thông báo số lượng vẫn ở ô đất, hiện sau 0,3 giây để không chồng lên icon bật ra. `HarvestBurst` cho tối đa 3 icon đại diện bật lên
theo đường cong rồi bay về player (khoảng 0,6 giây), kể cả sản lượng rất lớn.
Đây là hiệu ứng hình ảnh, không phải ItemPickup và không thể nhặt thêm lần nữa.

Do phần thưởng đã commit trước hiệu ứng, lưu giữa lúc icon đang bay vẫn giữ
đúng túi đồ và ô đất đã thu hoạch. Hiệu ứng không vào save; load xóa icon đang
bay và cây đang mờ. Túi không đủ chỗ vẫn từ chối thu hoạch, giữ nguyên cây.
Test bổ sung `unit/test_plant_motion.gd`: chân cây cố định, hoàn nguyên pose,
Tween không lặp theo focus, material dùng chung, giới hạn icon, đích bị xóa;
integration kiểm tra hiệu ứng không tạo thêm vật phẩm và được dọn khi restore.

## Trường hợp đồ này nhặt được, đồ khác không

Túi cũ 24 ô dễ kín vì hạt hoa, thức ăn, nông cụ và các loại nông sản khác nhau.
Khi không còn ô trống, trứng đã có stack vẫn gộp được nhưng sữa/lông hoặc một
nông sản mới không có stack sẽ bị chặn. Đây là kiểm tra sức chứa, không phải
hạn chế theo loài. Túi mặc định nay là 64 ô, save v4 tự thêm 40 ô trống khi tải.

Nếu vẫn hết chỗ, inventory phát `capacity_blocked`; feedback hiện chữ đỏ
“Túi đồ đầy” (hoặc “Túi đồ không đủ chỗ” khi chỉ đủ một phần yield), tối đa một
thông báo mỗi 1,5 giây. Đồ trên đất/cây đang chín được giữ nguyên. Có chỗ mới
thì sensor tự thử hút lại, thu hoạch cũng hoạt động bình thường.

Regression test bao phủ 22 loài cây qua frame tác động, 7 sản phẩm động vật
qua hút/popup, túi kín vẫn gộp trứng nhưng chặn sữa/lông, rồi nhặt lại sau khi
nhả chỗ; migration giữ nguyên 24 slot, tiền, hotbar và từ chối dữ liệu lỗi.
