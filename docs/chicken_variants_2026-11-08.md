# Gà theo skin và sản lượng — 2026-11-08

## Quyết định cân bằng

Mỗi skin `chicken_01` đến `chicken_18` là một lựa chọn mua riêng. Giữ gà gốc ở 16.000 xu và 100 trứng mỗi 900 giây; mỗi bậc thêm 4.000 xu và 25 trứng. Tỷ lệ giá/sản lượng giống nhau để người chơi chọn theo ngân sách và hình thức; gà đắt hơn tăng sản lượng trên một chỗ trong chuồng.

Đây là mức cân bằng khởi đầu dựa trên giá và sản lượng hiện có. Chi phí chăm sóc, sức chứa chuồng và giá bán trứng vẫn ảnh hưởng lợi nhuận thực tế.

| Skin | ID định nghĩa | Giá (xu) | Trứng / 15 phút |
| --- | --- | ---: | ---: |
| 01 | `chicken` | 16.000 | 100 |
| 02 | `chicken_02` | 20.000 | 125 |
| 03 | `chicken_03` | 24.000 | 150 |
| 04 | `chicken_04` | 28.000 | 175 |
| 05 | `chicken_05` | 32.000 | 200 |
| 06 | `chicken_06` | 36.000 | 225 |
| 07 | `chicken_07` | 40.000 | 250 |
| 08 | `chicken_08` | 44.000 | 275 |
| 09 | `chicken_09` | 48.000 | 300 |
| 10 | `chicken_10` | 52.000 | 325 |
| 11 | `chicken_11` | 56.000 | 350 |
| 12 | `chicken_12` | 60.000 | 375 |
| 13 | `chicken_13` | 64.000 | 400 |
| 14 | `chicken_14` | 68.000 | 425 |
| 15 | `chicken_15` | 72.000 | 450 |
| 16 | `chicken_16` | 76.000 | 475 |
| 17 | `chicken_17` | 80.000 | 500 |
| 18 | `chicken_18` | 84.000 | 525 |

Phạm vi gồm 18 skin gà; asset rooster là gà trống riêng, không đưa vào danh sách gà đẻ này.

## Triển khai hoàn tất

- Thêm 17 bộ AnimalDefinition, AnimalProductionDefinition và AnimalShopOffer bên cạnh gà gốc. Mỗi định nghĩa gắn trực tiếp đúng SpriteFrames, không random khi mua.
- Bổ sung cả catalog pet shop và farm supply, giữ thứ tự 7 offer cũ rồi thêm gà 02–18. Mỗi catalog có 24 offer thuộc 7 loài.
- Cửa hàng hiện sản lượng, loại sản phẩm và chu kỳ ở đầu phần chi tiết; có bản dịch tiếng Việt và tiếng Anh cho tên các loại mới.
- Mua vẫn là con non, trưởng thành sau 1 giờ và tuổi thọ 14 ngày như cấu hình hiện tại. Chu kỳ 15 phút áp dụng khi đủ điều kiện sản xuất; đói, khát, bệnh và thời tiết vẫn theo cơ chế hiện có.
- Bán lại dựa trên offer đúng ID: 50% giá mua khi non, 75% khi trưởng thành.
- SaveCatalog tự nhận các định nghĩa mới. Save/load giữ ID, skin, sản phẩm đã tạo và giá bán lại; không đổi schema.
- Save cũ có ID `chicken` nhưng từng dùng skin khác vẫn giữ nguyên hình thức và chỉ số gà gốc, tránh tự nâng cấp kinh tế khi tải.

`scripts/setup/build_chicken_variants.gd` là công cụ authoring chạy một lần bằng Godot `--headless --path . --script res://scripts/setup/build_chicken_variants.gd`. Các resource đã được lưu vào repo và game không cần chạy generator. Generator lấy cấu hình gà gốc làm mẫu và thay các biến thể trong hai catalog, nên chỉ chạy lại khi chủ động muốn tái tạo cấu hình.

## Kiểm chứng

- Test biến thể kiểm tra đủ 18 skin, ID riêng, giá/sản lượng tuyến tính, sản xuất theo chu kỳ, mua/bán, save/load, save cũ, thiếu tiền và đầy chuồng.
- Test giao dịch cũ dùng fixture giá, tuổi trưởng thành và số dư cố định, tách khỏi việc điều chỉnh kinh tế trong game.
- Chạy nhóm production + save repository + biến thể: 32/32 đạt.
- Chạy nhóm animal trade + specialized shops + biến thể: 20/20 đạt (4 test biến thể được chạy trong cả hai nhóm).
- Chạy lại chung cả 5 script sau thay đổi cuối: 48/48 test, 1.606 assertion đạt.
- Preview Godot native tại 1280×720 và 844×390 bằng `tests/support/chicken_shop_preview.tscn`; chọn đúng gà 18, chi tiết chứa 525 trứng, panel nằm trong màn hình và không ghi save của người chơi.
- Lint đối chiếu baseline: hai lỗi asset cửa hàng bị thiếu và năm cảnh báo đường dẫn đã có trước thay đổi này.
