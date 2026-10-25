# Planting Depth — S3a: ghép cành và quả Star

Đã triển khai ngày 25/10/2026. Save hiện hành **v30**. Giữ nguyên chu kỳ quả và buff ong hiện có; nhịp bình minh S3b vẫn hoãn.

## Mở bảng và chọn hướng

Đến gần cây ăn quả **đã trưởng thành**, nhấn **E**, click hoặc chạm cây. Bảng quản lý hiện hướng hiện tại, sản phẩm/số lượng của vụ đang chạy, tiến độ quả, hướng chờ và số Sáp Ghép Cành trong túi. Thu quả bằng nút **Thu hoạch vụ hiện tại** trong bảng. Hover hoặc cây vừa trưởng thành không tự bung modal.

Hai thẻ lựa chọn:

- **Sản lượng:** gấp đôi số quả Thường, phù hợp bán hoặc dùng đơn hàng/công thức thường. Thẻ hiện số đơn hàng hiện tại có yêu cầu loại quả đó.
- **Tuyển chọn:** giữ số lượng gốc, chuyển sang quả **Star** riêng để nấu món Chef mới. Thẻ hiện số công thức Chef sử dụng loại quả Star tương ứng.

Lần chọn đầu miễn phí. Các lần đổi tiếp theo tiêu **1 Sáp Ghép Cành**, lấy từ túi; chọn lại hướng đã chốt hoặc bấm lặp không tiêu thêm. Thay một hướng đang chờ bằng hướng khác cũng là một lần đổi. Bảng có thể cuộn trên điện thoại; các nút chọn và thu hoạch cao tối thiểu 64 đơn vị UI.

**Mọi lựa chọn đều áp dụng sau lần thu kế tiếp**, bao gồm lần chọn miễn phí và trường hợp cây đang tích tiến độ chưa chín. Ví dụ cây chưa định hướng đang có 300 táo: chọn Sản lượng vẫn thu 300 táo hiện tại, vụ sau mới ra 600. Đổi từ Sản lượng sang Tuyển chọn giữa vụ vẫn thu đủ 600 táo thường hiện tại, rồi mới bắt đầu vụ Star 300 quả.

Chưa chọn thì cây vẫn sản xuất quả Thường ×1. Thiếu sáp, đứng xa, cây non hoặc trạng thái cây thay đổi so với lúc xem không tiêu đồ. Túi/kho không chứa đủ cả vụ thì giữ nguyên quả và hướng chờ.

## Sáp Ghép Cành tại Chef

Công thức thử nghiệm: **5 gỗ Thường + 1 Mật Dại Thường + 1.000 xu → 1 Sáp Ghép Cành**, chế trong **60 giây**, dùng chung hàng đợi Chef. Mang nguyên liệu vào túi, chọn công thức, xem chi phí rồi bấm chế; nhận sáp vào túi sau khi hoàn tất. Sáp là vật liệu dùng trong bảng ghép, không phải phân để dùng bằng Space trên ruộng.

Chef kiểm tra đủ nguyên liệu, xu và chỗ hàng đợi trước khi tiêu; không tự lấy vật liệu Bạc/Vàng hoặc mật khác thay Mật Dại. Xu và nguyên liệu cùng được commit trước thông báo, không mất tiền khi thiếu đồ hoặc bấm lặp.

## Quả Star và món mới

Star là **SKU riêng**, không phải tầng Vàng của S0–S1. Kho/túi và worker giữ đúng ID; không thể gộp hoặc tự thay bằng quả thường. Icon trong túi có dấu sao, tên vật phẩm có Star. Star không nhận thêm tầng Bạc/Vàng; khi bán thô, chọn nhóm Thường trong menu bán vì bản thân SKU Star chỉ có một tầng.

| Quả | Giá Star thô = quả thường | Món Chef | Giá bán món thử nghiệm |
|---|---:|---|---:|
| Táo Star | 25 xu | Bánh táo Star | 280 xu |
| Đào Star | 30 xu | Kem đào Star | 294 xu |
| Lê Star | 38 xu | Lê Star hầm | 316 xu |
| Anh đào Star | 55 xu | Mứt anh đào Star | 364 xu |

Mỗi món cần **2 quả Star đúng loài + 1 Mật Dại**, chế 4 giờ, nhận 1 món. Công thức xuất hiện trong Chef nhưng thiếu Star thì không nấu được; công thức thường vẫn chỉ dùng quả thường. Giá món bằng tổng giá bán thô nguyên liệu ×1,4, làm tròn đơn giá. Giá, công thức và chi phí sáp đều là thông số thử nghiệm. Cân bằng thu nhập giữa hai hướng còn phụ thuộc công suất hàng đợi Chef; chưa khẳng định hai hướng cho cùng thu nhập.

## Worker, offline và save

Orchard worker chỉ thu hoạch; không tự chọn hoặc đổi hướng ghép. Worker dùng đúng sản phẩm/số lượng của vụ hiện tại để kiểm tra sức chứa và giao vào Warehouse. Thu thành công mới chuyển hướng chờ sang hướng đang hoạt động. Kho đầy không làm mất quả, không ép chuyển hướng và không chia nhỏ một vụ thu.

Lệnh ghép đồng bộ thời gian worker trước khi thay cấu hình, rồi kiểm tra lại revision của cây. Phần offline đã qua không hưởng hướng vừa chọn. `active_graft`, `pending_graft` và `graft_revision` nằm trong record của từng cây, không sửa shared TreeDefinition. Toàn bộ UI dùng một menu chung cho nông trại, không tạo menu riêng cho mỗi cây.

Migration v29 → v30 đặt các cây ăn quả cũ về chưa định hướng, cho chọn miễn phí. Giữ nguyên `fruit_work`, quả chín, thời gian, kho, giỏ, xu và hàng đợi Chef. Hướng chờ và chi phí đã trả giữ qua save/load; load lại không trừ sáp hoặc phát lại sản phẩm. Không sửa trực tiếp save cá nhân.

## Kiểm chứng

- **202/202 test, 5.809 assertions, 26 script**. Gồm 12 ca S3a mới, chuyển hướng giữa vụ, bấm lặp/stale revision, thiếu sáp, kho không chứa đủ 600 quả, worker giao Star, migration, Chef trừ xu nguyên tử và offline 48 giờ một lần so với chia giờ. Log `.godot/grafting-final-engine.log`.
- Test tương tác cây xen kẽ được cập nhật theo luồng mới: E/click mở bảng rồi bấm thu; không còn kỳ vọng tự thu ngay lúc click.
- Native **30/30 kiểm tra trên mỗi renderer Compatibility và Forward+**: E/click, chọn miễn phí, chế sáp, đổi hướng bằng touch, save/load pending, worker thu vụ cũ và giao Star, rút kho và nấu món Star. Kiểm tra UI Anh/Việt ở 1280×720 và cửa sổ 844×390 với input cảm ứng mô phỏng, chưa phải kiểm chứng trên điện thoại vật lý. Ảnh/báo cáo `.godot/grafting-native/`.
- Lint toàn dự án: 0 lỗi/cảnh báo. Build Web thành công, `.dist/build-report.json` có `ok: true`.
- Dùng profile QA riêng; không khẳng định toàn bộ fixture lịch sử của repository đều xanh ngoài bộ hồi quy đã ghi.

Nguồn chính: `components/trees/fruit_tree.gd`, `graft_service.gd`, `graft_menu.gd`, `components/cooking/chef_cooking.gd` và `persistence/tree_save_schema.gd`. Kiểm thử: `tests/integration/test_grafting.gd`, `scripts/run_grafting_qa.py`.
