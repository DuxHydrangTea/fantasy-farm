# Bổ sung thức ăn và nước cho máng

Đứng cách máng tối đa 30 pixel, không có vật cản ở giữa. Lời nhắc phía trên nhân vật hiện lượng còn lại/sức chứa và điều kiện nạp máng.

- **Máng thức ăn:** nhấn **E**, **Space** hoặc chuột phải. Dùng đúng loại thức ăn từ bất kỳ ô nào trong kho, không cần cầm trên hotbar. Nạp tối đa số gói nguyên mà máng nhận được.
- **Máng nước:** chọn bình tưới trên hotbar, nhấn **E**, **Space** hoặc chuột phải. Thêm tối đa 30 đơn vị/lần, giới hạn ở sức chứa. Bình tưới hiện không có dung tích hữu hạn trong hệ thống công cụ.
- Hoạt ảnh chạm ở frame 3 mới nạp và trừ vật phẩm. Mở túi, mất vật phẩm, xóa máng, ra xa hoặc xuất hiện vật cản trước đó sẽ hủy lần nạp. Đổi hotbar không chuyển hành động sang vật phẩm khác.
- Máng đầy, thiếu thức ăn, thiếu bình tưới hoặc thiếu chỗ cho một gói sẽ hiện lý do. Khi đang ở gần máng, phím tương tác ưu tiên máng; ra ngoài phạm vi sẽ tiếp tục thao tác trồng trọt như trước.

Người chơi được cấp 5 gói thức ăn gia cầm khi khởi tạo kho mới trong `player.tscn`. Một gói dùng `ItemDefinition.food_units_per_item`, hiện mặc định **300**. Máng thức ăn chứa **600**, bắt đầu với **120** như trước; máng nước giữ sức chứa/bắt đầu **120**. Ví dụ nạp máng thức ăn đang có 120 sẽ dùng 1 gói và lên 420; 180 chỗ còn lại chưa nhận được cả gói, nên không trừ thêm thức ăn.

## Cấu hình và tái sử dụng

Trên `AnimalTrough`:

| Thuộc tính | Ý nghĩa |
|---|---|
| `kind` | Thức ăn hoặc nước |
| `capacity`, `stock` | Sức chứa và lượng khởi tạo |
| `feed_item` | Resource thức ăn loại FEED cho máng này; không cố định ID gia cầm trong code |
| `water_per_use` | Nước thêm mỗi lần dùng bình tưới |
| `allowed_species` | Loài được ăn/uống; rỗng nghĩa là mọi loài |

Thay `feed_item` bằng resource cỏ khô hoặc loại thức ăn khác và cấu hình `allowed_species` để dùng cho bò, cừu, ngựa… Sức chứa nên ít nhất bằng `food_units_per_item`. Chỉ nhận gói nguyên để tránh làm mất phần thức ăn dư.

`AnimalTrough.refill_from_inventory()` chịu trách nhiệm lượng nạp, giới hạn và trừ kho; có khóa chống gọi lại từ tín hiệu thay đổi kho. `TroughInteraction` tìm máng gần nhất có thể với tới, hiển thị trạng thái và thực hiện lần nạp tại frame chạm. `StateComponent` điều phối input và hoạt ảnh, còn hành động trồng trọt dùng các action riêng nên lần nạp không tưới/cuốc đất đồng thời. Các animal tiếp tục dùng chung hệ thống tìm máng và tiêu thụ đã có.

## Kiểm thử

```bash
python3 tests/run_animal_tests.py --godot /home/dungnguyen/Downloads/Godot_v4.7.2-stable_linux.x86_64
```

Các test bổ sung nằm trong `tests/unit/test_trough_refilling.gd` và `tests/integration/test_trough_interaction.gd`: chuyển số lượng chính xác, không mất gói dư, giới hạn kho/máng, cấu hình loại thức ăn khác, tín hiệu gọi lại, hoạt ảnh/input E, bình tưới, đổi slot, hủy thao tác, xóa đối tượng, vật cản, ưu tiên máng và bố cục lời nhắc ở hai kích thước viewport.
