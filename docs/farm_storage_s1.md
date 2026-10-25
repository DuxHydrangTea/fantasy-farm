# S1 — Kho nông sản và kho giống/thức ăn

Tài liệu ghi lại mốc này. Bản hiện tại đã nối đầy đủ kho vật tư và gieo từ kho; xem [S3–S5](farm_storage_s3_s5.md).

Ngày triển khai: 25/10/2026. Hai kho gửi/rút thủ công, save **v24**.

## Cách dùng

- `Warehouse` tại (932, 199): kho nông sản, **128 ô**. Nhận item PRODUCE, gồm rau củ, trái cây, sản phẩm vật nuôi, gỗ, mật và món nấu.
- `SeedInventory` tại (1047, 199), giữ variant 5: kho giống và thức ăn, **64 ô**. Nhận hạt có CropDefinition hợp lệ và thức ăn FEED. Hạt hoa, cây giống lâu năm, tool, booster và đồ đặt vẫn nằm ngoài nhóm này.
- Đến trước cửa kho, hướng về công trình và nhấn **E**; hoặc click/chạm vào công trình bằng hệ thống tương tác hiện có.
- Bên trái là túi, bên phải là kho. Chọn vật phẩm, chọn số lượng rồi gửi/rút; có nút gửi tất cả đồ phù hợp và rút tất cả. Điện thoại có nút −/+ lớn.
- Item sai nhóm bị khóa và có tooltip. Khi đích đầy, chỉ chuyển phần chứa được và giữ phần dư ở nguồn. Con số thông báo là số thực chuyển.
- Đóng bằng ×, E, Esc hoặc Tab. Rời xa cửa thì panel tự đóng.

## Dữ liệu và tích hợp

ID ổn định `produce_warehouse` / `farm_supply_storage` độc lập tên node. `StorageAccess` là component con của Barn; hình ảnh, variant, vị trí, collision gốc giữ nguyên. Dịch vụ `FarmStorageService` do FarmWorld sở hữu, không lưu đồ trong sprite/building.

Hai resource trong `resources/storage` cấu hình filter, số ô mặc định và giới hạn stack. Stack cap bằng 0 nghĩa là theo ItemDefinition. Save giữ sức chứa của từng kho; sửa mặc định không tự cắt kho của profile đã có.

Giao dịch dựng hai trạng thái đích/nguồn trước, kiểm tra lại nguồn, nhóm item, sức chứa, cửa kho và trạng thái profile. Chỉ phát signal khi cả hai phía đã cập nhật; khóa tái nhập còn hiệu lực trong lúc thông báo. SaveManager không chụp giữa giao dịch.

Migration **v23 → v24** thêm hai kho rỗng và không di chuyển đồ từ túi hay giỏ worker. DTO kho được validate trước restore; khôi phục kho trước worker/offline. Túi, giỏ, xu, nông cụ và Chef được giữ nguyên. Không sửa save cá nhân trong quá trình kiểm thử.

S1 chưa đổi đích sản phẩm worker, nguồn feed hay nguồn gieo. **S2** mới nối sản phẩm worker vào Warehouse, **S3** lấy feed chung và **S4** gieo từ kho.

## Kiểm chứng

76 test / 817 assertion qua trong bộ chọn: storage unit + world integration, save repository, inventory, workers, tool upgrades, Chef và tool upgrade persistence. Bao gồm thiếu chỗ/phần dư, khóa signal tái nhập, bộ lọc, DTO lỗi, giữ sức chứa khi restore, mở cửa/khóa profile, ray chống xuyên tường, migration v23, roundtrip v24 và ghi/đọc hai kho có đồ qua JSON trên ổ đĩa.

QA native qua **26 mục trên mỗi renderer** (Compatibility và Forward+): E mở kho, Enter chọn item và giữ focus, chuột/touch gửi/rút, bulk filter, Esc/× đóng, panel 1280×720 và 844×390, snapshot v24. Kết quả bản cuối ở `.godot/storage-native-final/` (mỗi renderer có `report.json`, ảnh desktop/touch và engine log).

Lint: 0 lỗi/cảnh báo. Engine validation scene kho: 0 lỗi, 0 cảnh báo cấu hình và không có cảnh báo thuộc tính năng kho; 30 cảnh báo phụ thuộc cũ vẫn còn trong project.

QA native tái hiện được bằng:

```powershell
python scripts/run_storage_qa.py --godot <Godot-standard-console.exe>
```

Chuẩn bị staging bằng `scripts/build_web.py` trước. Runner xác minh staging dùng user directory riêng và không bật MCPRuntimeServer; chạy Compatibility và Forward+, ghi báo cáo/ảnh vào `.godot/storage-native/`. Cảm ứng là input mô phỏng ở 844×390 trên desktop; chưa phải kiểm chứng trên thiết bị điện thoại thật.
