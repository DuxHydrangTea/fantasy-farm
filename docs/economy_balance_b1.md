# Cân bằng kinh tế B1 — 25/10/2026

Đã triển khai vòng cân bằng dựa trên catalog thực và mô phỏng, save v33. Đây là thông số thử nghiệm có kiểm chứng, không phải nghiệm thu cuối về nhịp tiến triển bằng phiên chơi người thật. Số liệu máy đọc được: [metrics.json](economy_balance_2026-10-25/metrics.json).

## 1. Đơn Hoàn Hảo

Trước đây mọi đơn Hoàn Hảo nhận 150% thưởng đơn thường. Với giá Bạc 1,8×/Vàng 3,5×, nộp toàn Vàng có thể thấp hơn bán thẳng 40–46%. Công thức mới:

`reward = max(round(base_order_reward × 1.5), ceil(exact_tier_sale_value × 1.10))`

Giá bán đối chiếu tính theo đơn giá đã làm tròn của từng tầng, đúng số Bạc/Vàng sẽ tiêu; vẫn dùng Bạc trước Vàng, không trộn hàng Thường. Không đổi thưởng đơn thường hay đơn đã có. Chế độ Hoàn Hảo được chốt khi giao, không lưu như một hợp đồng thưởng cố định riêng. UI hiển thị cả thưởng cuối và giá bán thẳng; preview cũ không khớp sẽ bị từ chối.

| Đơn | Thưởng Hoàn Hảo cũ | Mới: toàn Bạc | Mới: toàn Vàng | Mới: nửa Bạc/nửa Vàng |
| --- | ---: | ---: | ---: | ---: |
| tomato_crate_bulk | 150000 | 158400 | 308000 | 233200 |
| potato_military | 243750 | 257400 | 501600 | 379500 |
| grand_salad_basket | 336000 | 336000 | 616000 | 466400 |
| winter_soup_barrel | 241500 | 241500 | 443300 | 335500 |
| dairy_egg_express | 84000 | 84000 | 154000 | 116380 |
| royal_pumpkin_contract | 5437500 | 5742000 | 11165000 | 8453500 |

## 2. Bếp, cây ghép và mật combo

Một cây ghép táo hướng Sản lượng cho 600 quả × 25 xu = 15.000 xu/vụ. Hướng Star cho 300 quả, nhưng công thức cũ chỉ dùng 2 quả/4 giờ. Một vụ cần tới 150 lượt bếp; vì vậy chỉ tăng nhẹ giá món lẻ không giải quyết được công suất.

**Thêm 9 công thức mẻ lớn riêng**, không sửa công thức/món cũ. Món cũ, món đang nấu và đồ tồn kho giữ nguyên giá và nguyên liệu. Tất cả công thức mới tốn 1 vị trí hàng đợi và 4 giờ:

| Mẻ mới | Nguyên liệu | Giá bán | Chênh với bán nguyên liệu trực tiếp |
| --- | --- | ---: | ---: |
| star_apple_tart_batch | 300 quả Star tương ứng + 1 Mật Dại | 17423 | 9773 |
| star_peach_parfait_batch | 300 quả Star tương ứng + 1 Mật Dại | 20873 | 11723 |
| star_pear_compote_batch | 300 quả Star tương ứng + 1 Mật Dại | 26393 | 14843 |
| star_cherry_preserve_batch | 300 quả Star tương ứng + 1 Mật Dại | 38123 | 21473 |
| hybrid_01_06_custard_batch | 100 mật tương ứng + 100 Sữa Bò Thường | 81200 | 23200 |
| hybrid_02_07_custard_batch | 100 mật tương ứng + 100 Sữa Bò Thường | 81200 | 23200 |
| hybrid_03_08_custard_batch | 100 mật tương ứng + 100 Sữa Bò Thường | 81200 | 23200 |
| mono_06_custard_batch | 100 mật tương ứng + 100 Sữa Bò Thường | 67200 | 19200 |
| mono_07_custard_batch | 100 mật tương ứng + 100 Sữa Bò Thường | 67200 | 19200 |

Giá mẻ Star = `ceil((giá bán 600 quả thường + 1 Mật Dại) × 1.15)`. Mẻ táo bán 17.423 xu; trừ giá trị 1 mật còn 17.273 xu, hơn hướng Sản lượng khoảng 15,15% nhưng phải chờ bếp. Đây là lợi ích để đổi lấy thao tác và công suất bếp, không nâng giá quả Star thô. Một cây táo Star có thể cấp một mẻ mỗi 4 giờ; nhiều cây Star phải tranh công suất hàng đợi nên hướng Sản lượng vẫn có vai trò.

Giá mẻ kem trứng = 100 lần món lẻ, vẫn chênh 40% giá trị nguyên liệu. Mật đơn: 67.200 xu/mẻ; mật lai: 81.200 xu/mẻ. Giữ công thức lẻ để người chơi ít nguyên liệu vẫn nấu thử và mở hình hũ. Nấu mẻ lớn cũng mở hình tương ứng. Chef hiển thị giá bán và chênh với bán nguyên liệu để người chơi tự so sánh.

Các con số chênh trên là chi phí cơ hội của nguyên liệu theo giá bán, không phải tiền lãi đã trừ toàn bộ mua giống/thức ăn/lương. Mẻ Star còn có độ trễ bếp 4 giờ ở lần thu đầu; bảng không coi đó là thu tiền ngay cùng lúc với hướng Sản lượng.

## 3. Phần đã đo và giữ nguyên

- Worker: mô phỏng 48 giờ với 2 ô (1 thường, 1 màu mỡ), cấp 12 hạt cà rốt, không bón phân. Thu 94.500 xu theo giá bán, trừ hạt 32.400 và lương 5.600 còn 56.500. Dừng trồng khi hết đúng 12 hạt; không tự mua hạt, không thêm quota. Kiểm thử đơn bước/định kỳ offline vẫn đạt. Giữ mức lương trong vòng này; chưa có mục tiêu thời gian tiến triển đủ chắc để đổi lương hàng loạt.
- Đất màu mỡ: giữ hash v1 khoảng 18% theo ô và sản lượng +50%. Với cà rốt Bạc: ô thường 6.300 doanh thu − 2.700 hạt = 3.600; ô màu mỡ 9.450 − 2.700 = 6.750. Đây là lợi nhuận sau hạt, chưa tính lương/thời gian thao tác. Không tăng thêm vì lợi ích đã rõ, không ảnh hưởng chất lượng.
- Mật: khi hoa hợp lệ nở đầy đủ, mẻ 100 hũ mật đơn/lai mất 12 giờ, hoặc 9,6 giờ khi gió; bán 40.000/50.000 xu mỗi mẻ. Trần đúng 1 mẻ nên offline dài không tự tích nhiều mẻ. Không đổi thời gian hoặc giá mật thô.
- Đã xuất bảng 22 loại rau: thời gian, giá hạt, sản lượng và tiền sau trừ hạt theo từng tầng. Cột Vàng chưa trừ chi phí cơ hội Root Tonic, nên không được diễn giải là lợi nhuận ròng cuối cùng. Không đổi giá giống hoặc nerf tồn kho trong vòng này.

## 4. Save và dữ liệu thử

v32 → v33 chỉ nâng phiên bản catalog vì có SKU mẻ lớn; không đổi cấu trúc cây, đơn, hàng đợi hoặc tài sản cũ. Client cũ sẽ từ chối save mới thay vì lùi về backup thiếu các SKU mới.

Đã bổ sung vào túi local đủ để nấu hai mẻ mới: 300 Táo Star, 1 Mật Dại, 100 Mật Lai Hoa01–Hoa06, 100 Sữa Bò. Không đổi tiền, cây, trạng thái worker hay các đơn đã có. Hồ sơ vừa có tiến trình mới giữa preview và ghi; công cụ từ chối hash cũ, đọc lại bản mới nhất rồi mới áp dụng.

Save được ghi ở revision 559, đã đọc lại và kiểm checksum. Backup: `C:/Users/faker/AppData/Roaming/Godot/app_userdata/fantasy-farm/saves/profile_local.json.before-balance-1792938575.bak`.

Mở lại game, tới Chef, chọn **Đại tiệc Táo Star (300 quả)** hoặc **Mẻ kem trứng Mật Lai Hoa01–Hoa06 (100 hũ)**. Kiểm tra giá/chênh và giao nguyên liệu. Hai mẻ vẫn chạy 4 giờ theo thiết kế; không giả lập hoàn tất trong save cá nhân.

## 5. Kiểm chứng và giới hạn

- 109/109 bài, 1.996 assertions, 11 script: `.godot/balance-tests-engine.log`. Bao gồm 18 tổ hợp (6 đơn × toàn Bạc/toàn Vàng/phối hợp), ví đầy, preview cũ, chống nộp hai lần, giữ món lẻ đã trả nguyên liệu, mẻ lớn, mở hũ, save, kho và worker offline.
- Native chuột/touch: Compatibility và Forward+, 1280×720, 844×390, 720×960, xem đối chiếu giá đơn và nấu/nhận hai mẻ. Báo cáo cuối trong `.godot/balance-native-final/`.
- Lint: `.godot/balance-final-lint.json`; Web: `.dist/build-report.json`.
- Không có phiên người thật 2,5 giờ hoặc thiết bị Android/iOS thật trong vòng này. Các mốc tiến triển dài hạn, mức lạm phát cuối game và chi phí cơ hội bếp giữa mọi quy mô đàn/vườn vẫn cần dữ liệu chơi thực. Không tuyên bố đã cân bằng hoàn toàn game.
