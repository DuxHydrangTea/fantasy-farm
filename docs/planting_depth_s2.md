# Planting Depth — S2: gỗ và lâm nghiệp

Đã triển khai ngày 25/10/2026. Save hiện hành **v29**. S2 nối tiếp stack chất lượng của S0–S1; không thay đổi bố cục khu cây hiện tại.

## Cách chơi

- **Gỗ bán 1 xu/đơn vị**, giữ làm vật liệu thay vì nguồn thu chính.
- Tại NPC bán hàng hiện có, mở **Farm supplies / Vật tư nông trại**, chọn Wood. Giá mua **63 xu/đơn vị**: giá bán cũ 25 xu × 2,5 = 62,5, làm tròn tới xu gần nhất.
- Mỗi profile mua tối đa **30 gỗ/ngày**, dùng chung giữa các lần mở cửa hàng và mọi vendor. UI hiện số đã mua, ví dụ `12/30`. Đặt lại lúc **06:00 UTC+7**, theo mốc ngày chung của thời tiết/lương; không cộng dồn hạn mức khi nghỉ nhiều ngày.
- Nâng cuốc, tưới và gieo **2×2 vẫn chỉ mất xu**. Các mức sau cần thêm gỗ Thường theo bảng dưới. Tự lấy từ **Warehouse trước, rồi túi**; không phải mang hết gỗ về túi. UI báo lượng có/cần và kiểm tra lại khi mua.

| Mức đích | Gỗ thêm cho mỗi nông cụ |
|---|---:|
| 3×3 | 10 |
| 4×4 | 15 |
| 5×5 | 20 |
| 6×6 | 30 |

Giá xu và điều kiện mở đất của nâng cấp giữ nguyên. Đây là chi phí thử nghiệm. Một công cụ cần 75 gỗ để đi từ 1×1 lên 6×6; cả ba cần 225 gỗ. Một lượt chặt Oak trưởng thành hiện cho 400 gỗ, đủ phần vật liệu cho cả ba. Nếu chỉ mua chợ thì cần ít nhất 8 hạn mức ngày cho toàn bộ ba công cụ; mỗi lần nâng cấp riêng không cần quá một hạn mức. Cap 30/ngày và nhịp tiến trình vẫn cần đo thêm ở giai đoạn cân bằng.

## Chặt, đập gốc và nhổ cây non

Chặt cây trưởng thành bằng rìu như trước, giữ nguyên lượng gỗ và cây giống được trả. **Cuốc một nhát vào gốc** sẽ xóa gốc, trả **2 Root Wood** và ngừng tái sinh tại ô đó. Giữ gốc thì cây vẫn tái sinh như hiện tại.

Cuốc cây gỗ còn non sẽ nhổ và trả đúng **1 cây giống**, không có root hay gỗ. Túi không chứa nổi cây giống thì giữ nguyên cây non. Cây gỗ trưởng thành còn thân không thể bị nhổ bằng cuốc: phải chặt trước.

Cuốc vùng từ 2×2 tới 6×6 xử lý các gốc/cây non trong vùng bằng cùng `apply_area` với thao tác cuốc đất. Phạm vi khóa khi bắt đầu animation, đổi slot/selection thì hủy thao tác cây đang chờ. Preview nhận diện theo vị trí hiển thị thực của hàng cây xen kẽ, không nhầm ô lưu với ô hiển thị. Bấm lặp không nhân root; lượng không chứa được khi chặt/đập gốc rơi xuống đất. Worker không tự đập gốc hoặc nhổ cây.

## Save và giao dịch

- v28 → v29 thêm bộ đếm mua gỗ, không sửa gỗ/xu đã có và không thu lại vật liệu của nông cụ đã nâng.
- Gốc cũ từng nhận 1–2 nhát cuốc được giữ lại, chuẩn hóa tiến độ đập về 0 theo luật mới một nhát. Không tự xóa gốc hoặc tặng root trong migration; nhát tiếp theo mới trả thưởng.
- Mua gỗ commit ví, túi và hạn mức trước thông báo. Giới hạn dùng chung ngăn mua qua vendor thứ hai trong callback; thất bại không mất xu/đồ/hạn mức. Save/load khi giao dịch đang dở bị chặn.
- Nâng cấp commit vật liệu hai nguồn, xu và cấp nông cụ trước thông báo; thiếu vật liệu, thiếu tiền hoặc báo giá thay đổi đều không tiêu đồ. Có rollback nếu commit thất bại.
- Chặt cây giao cả gỗ và cây giống trước khi báo túi thay đổi. Pickup được tạo bằng loader lúc chạy để tránh PackedScene chưa hoàn tất do vòng phụ thuộc script; kiểm chứng cả trường hợp túi đầy.

## Phạm vi và kiểm chứng

Chưa có hệ mở rộng Bếp để gắn chi phí gỗ, nên S2 dùng nâng cấp nông cụ làm đầu ra vật liệu. Không thêm hệ nâng cấp Bếp/chuồng mới. Ghép cành S3a, combo mật S4 và Perfect Delivery S5 chưa triển khai.

- **190/190 test, 5.636 assertions, 25 script**: 10 ca S2 mới cùng hồi quy chất lượng rau, kho, worker/offline, Chef, mua bán, nông cụ, migration, onboarding và bố trí cây xen kẽ. Log `.godot/forestry-final-engine.log`.
- Native **24/24 kiểm tra trên mỗi renderer Compatibility và Forward+**: mua 12 rồi 18 gỗ, chặn vượt 30, dùng gỗ Warehouse nâng lên 3×3, UI cảm ứng, một animation cuốc 6×6 dọn hai gốc + một cây non đúng phần thưởng và roundtrip save giữ hạn mức. Báo cáo/ảnh `.godot/forestry-native/`.
- Lint toàn dự án: 0 lỗi, 0 cảnh báo. Build Web thành công, `.dist/build-report.json` có `ok: true`.
- Dùng profile QA riêng, không sửa save cá nhân. Không khẳng định toàn bộ fixture lịch sử của repository đều xanh; một số test cây cũ vẫn dùng thông số tăng trưởng trước đợt kinh tế hiện hành, nằm ngoài bộ hồi quy trên.

Nguồn chính: `wood_market.gd`, `shop_service.gd`, `tool_upgrade_service.gd`, `timber_tree.gd`, `tree_plantation.gd` và `farming_controller.gd`. Kiểm thử mới: `tests/integration/test_forestry.gd`, `scripts/run_forestry_qa.py`.
