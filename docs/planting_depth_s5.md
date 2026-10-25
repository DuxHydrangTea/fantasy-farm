# S5 — Đơn Hoàn Hảo, đất màu mỡ và mặc định tiếng Việt

Đã triển khai ngày 25/10/2026, ban đầu save v32; vòng [B1](economy_balance_b1.md) hiện dùng v33. Các mức thưởng/sản lượng là thông số thử nghiệm theo plan.

## Chơi thử ngay trên hồ sơ local

Khởi động lại game để nạp code, mặc định tiếng Việt và dữ liệu đã chuẩn bị. Không reset hồ sơ hoặc thay đơn đang có.

1. Tới bảng đơn hàng, mở một trong ba đơn hiện tại. Trong túi đã được bổ sung đủ nông sản để thử cả giao Thường và Hoàn Hảo:

| Nông sản bổ sung | Thường | Bạc | Vàng |
| --- | ---: | ---: | ---: |
| Cà chua | 2.000 | 1.000 | 1.000 |
| Khoai tây | 2.000 | 1.000 | 1.000 |
| Bắp cải | 800 | 400 | 400 |

2. Chọn **Nộp Hoàn Hảo (bảo đảm giá)**. Xem đúng số lượng từng tầng trước khi xác nhận. Đơn thường chỉ lấy Thường; đơn Hoàn Hảo ưu tiên Bạc trước Vàng và tuyệt đối không bù bằng Thường. Toàn bộ nguyên liệu của đơn phải đạt Bạc/Vàng. Thưởng được tính `max(round(base_reward × 1.5), ceil(giá bán đúng tầng × 1.10))` và kiểm tra giới hạn ví trước khi trừ đồ.
3. Thử bốn cây cà rốt chín ở mép trên phía phải ruộng:

| Ô tọa độ map | Loại đất | Chất lượng | Sản lượng |
| --- | --- | --- | ---: |
| (56,19) | Thường | Bạc | 100 |
| (55,19) | Thường | Vàng | 100 |
| (49,19) | Màu mỡ | Bạc | 150 |
| (56,20) | Màu mỡ | Vàng | 150 |

Worker trồng trọt đã được **tạm dừng** để không tự thu mất các mẫu. Bật lại trong bảng người làm thuê sau khi thử. Cả hợp đồng, công việc đang giữ và giỏ đều được bảo toàn. Kho vật tư có thêm 24 hạt cà rốt, đã chọn làm giống từ kho để thử viền sáng khi cầm hạt.

Dữ liệu được thêm qua repository có kiểm tra schema, preflight, revision và hash nguồn. Save mới revision 529; giữ nguyên số xu, đơn hàng, cây cũ và các kho khác. Bản sao lưu trước khi thêm dữ liệu:

`C:/Users/faker/AppData/Roaming/Godot/app_userdata/fantasy-farm/saves/profile_local.json.before-s5-1792937448.bak`

Các lượng trong bảng là lượng **bổ sung**, không phải ghi đè stack đã có. Cây mẫu chỉ thêm vào ô chưa trồng, không xóa cây cũ.

## Quy tắc và UI

- Bảng đơn hàng có nút giao thường, Nộp Hoàn Hảo và bỏ đơn riêng. Hộp xác nhận hiển thị vật phẩm, số Thường/Bạc/Vàng sẽ dùng và thưởng cuối cùng. Nếu tầng nguyên liệu thay đổi, xác nhận cũ bị vô hiệu hóa; hủy và mở lại để xem kế hoạch mới. Service cũng kiểm tra lại kế hoạch khi commit.
- Trừ vật phẩm, cộng xu, hoàn thành/đổi đơn đều commit trước notification; khóa reentry chống giao hai lần. Cảnh báo bán nông sản nhận diện cả Bạc/Vàng được yêu cầu bởi đơn.
- Khoảng 18% từng ô trong hình chữ nhật trồng trọt được chọn bằng hash nguyên xác định từ `(x,y,layout_version)`, không chọn nguyên cột. Chỉ ô đã mở hiện viền đỏ; viền sáng hơn khi cầm hạt rau. Một node vẽ chung toàn bộ viền, không thêm node theo ô.
- Sản lượng đất màu mỡ = `max(base + 1, round(base × 1.5))`: base 1 → 2, base 4 → 6. Không ảnh hưởng tầng chất lượng hoặc thời gian lớn. Player và worker dùng cùng tính toán và cùng kiểm tra sức chứa toàn bộ mẻ trước khi thu; worker giao vào Warehouse như cũ.
- Save v31 → v32 thêm `fertile_layout_version = 1`, không thay vị trí/tiến độ cây. Thuật toán v1 có nhánh cố định; bản mới muốn đổi thuật toán phải thêm version và migration có chủ đích. Không tự thay layout theo hằng version hiện hành.
- Game mặc định `vi` ở Language autoload; tiếng Anh vẫn có thể chọn bằng API ngôn ngữ hiện hữu. Đã thêm dịch cho UI S5 và các câu thao tác cây còn thiếu. Font và bố cục đã kiểm tra bằng ảnh.
- Điều kiện nguồn đơn chỉ xét NPC có menu cửa hàng thực sự, tránh nhận nhầm catalog mặc định ẩn của Chef/kho/người làm thuê thành nơi bán giống.

## Kiểm chứng

- Hồi quy 28 script: 231/232 test trước sửa điều kiện nguồn hàng của Chef; lỗi đó đã được sửa và kiểm tra lại trong bộ trực tiếp dưới đây. Các bài còn lại về worker, offline, kho, Chef, nâng cấp và schema đã qua.
- Bộ tác động trực tiếp cuối: **57/57 test, 1.124 assertions**, gồm S5, đơn unit/integration, crop automation và save repository: `.godot/s5-verified-tests-engine.log`.
- Sau bổ sung nhận diện Bạc/Vàng cho cảnh báo bán: bộ đơn unit + integration kiểm tra lại tại `.godot/s5-order-final-engine.log`.
- Native QA cuối: **22/22 kiểm tra trên mỗi renderer** Compatibility và Forward+, chuột/touch, 1280×720, 844×390, 720×960; mặc định tiếng Việt, xem tầng, hủy, nộp Hoàn Hảo, bảo toàn Thường, viền sáng, cà rốt Bạc 150 và save/load. Báo cáo `.godot/s5-native-verified/{compatibility,forward-plus}/report.json`.
- Lint: `.godot/s5-final-lint.json`; Web build: `.dist/build-report.json`.
- Dữ liệu local: `.godot/s5-profile-installed.json`, `.godot/s5-installed-verification.json`. Công cụ opt-in `tests/support/prepare_s5_profile.tscn` có preview mặc định, chỉ ghi khi truyền `--apply` kèm hash nguồn. Không chạy tự động từ gameplay.

Touch được mô phỏng bằng sự kiện native; chưa xác minh trên Android/iOS thật. Cảnh báo UID cũ dùng đường dẫn thay thế là baseline của dự án.
