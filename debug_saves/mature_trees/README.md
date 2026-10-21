# Save có sẵn toàn bộ khu cây trưởng thành

- Khu trái: 153 cây ăn quả (39 Apple, 38 Peach, 38 Pear, 38 Cherry), có quả sẵn.
- Khu phải: 153 cây gỗ (51 Oak, 51 Birch, 51 Spruce), cây đứng trưởng thành, chưa bị chặt.
- Lấp mọi vị trí hợp lệ theo lưới 48 px của hai khu đất.
- Giữ vị trí nhân vật của phiên chơi vừa chụp; chỉ bổ sung cây vào hai khu đất.
- Chuyển save hiện có sang schema v11, giữ tiền, túi đồ và tiến trình cũ.

File `profile_local.json` dùng đúng envelope/checksum của game. Đã kiểm tra
schema, preflight world, restore thực tế và đọc lại file bằng Godot.
Đã cài vào save đang dùng sau khi người dùng xác nhận. `installation.json`
ghi đường dẫn save và bản backup nguyên gốc; đã mở game xác nhận đủ 306 cây
và kiểm tra lưu lại thành công.

Để dùng lại bản này: đóng game rồi sao chép `profile_local.json` vào:

`C:\Users\faker\AppData\Roaming\Godot\app_userdata\fantasy-farm\saves\profile_local.json`

Mỗi lần cài nên sao lưu file đang có trước. Mở lại game để tải bản mới.
