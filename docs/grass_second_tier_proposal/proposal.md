# Đề xuất tầng cỏ thứ hai cho world

Khảo sát ngày 2026-11-16 từ scene `world/main_world.tscn` hiện tại, chụp bằng Godot 4.8 beta3 / OpenGL trong project xem thử riêng. Không thay đổi scene hoặc dữ liệu lưu cá nhân.

## Cách dùng hai bộ tile

- Mép cỏ: dùng cho gò tự nhiên gần cây, ao và bờ sông; mép cong hoặc bậc so le, tránh dải hình chữ nhật dài.
- Mép đất: dùng ít hơn, cho gò cạnh công trình hoặc quảng trường, nơi cần đọc độ cao rõ hơn.
- Mỗi vị trí là một mảng rời; không nâng đồng loạt mặt cỏ toàn world. Làm 1–2–3 trước, rồi đánh giá 4–5–6.

Ảnh tổng thể: `overview_annotated.png`. Cận cảnh sáu vị trí: `zone_details.png`. Tọa độ và kích thước đề xuất: `regions.json`. Các khung là vùng khảo sát, không phải đường viền gò cuối cùng.

## 1. Bãi cỏ đông bắc, phía phải tiệm rèn

- Tileset: mép cỏ. Ưu tiên: Cao.
- Vùng world tham khảo: x=2016, y=48, rộng 224, cao 112 px (khoảng 14×7 tile).
- Pixel gần màu cỏ nền hiện tại: 83.1% trong vùng khảo sát.
- Khoảng cỏ rộng phía trên đường đất; một gò lớn, lệch về cụm cây, sẽ tạo điểm cao cho góc đông bắc.

## 2. Bãi cỏ phía nam khu kho

- Tileset: mép đất. Ưu tiên: Cao.
- Vùng world tham khảo: x=2128, y=1280, rộng 224, cao 144 px (khoảng 14×9 tile).
- Pixel gần màu cỏ nền hiện tại: 89.0% trong vùng khảo sát.
- Đây là khoảng cỏ rỗng rõ nhất ngoài khu sản xuất. Dùng một gò mép đất có hình bất đối xứng để nối khu công trình với bờ nam; chừa hành lang thẳng từ hai cổng kho.

## 3. Dải cỏ phía tây ao cảnh

- Tileset: mép cỏ. Ưu tiên: Cao.
- Vùng world tham khảo: x=1872, y=640, rộng 144, cao 144 px (khoảng 9×9 tile).
- Pixel gần màu cỏ nền hiện tại: 77.9% trong vùng khảo sát.
- Tạo một doi cỏ hẹp bên cụm liễu, chỉ ở phía tây ao; thu nhỏ theo bờ thực tế để giữ ít nhất 32 px với nước và đường lát.

## 4. Góc tây bắc đài phun nước

- Tileset: mép đất. Ưu tiên: Vừa.
- Vùng world tham khảo: x=1920, y=320, rộng 160, cao 96 px (khoảng 10×6 tile).
- Pixel gần màu cỏ nền hiện tại: 62.3% trong vùng khảo sát.
- Gò nhỏ làm nền cho cụm cây phía sau quảng trường. Dừng trước nền đất, ghế và đường đi; không nâng nền đài phun nước.

## 5. Dải cỏ ngoài hàng rào vườn cây, phía tây nam

- Tileset: mép cỏ. Ưu tiên: Vừa.
- Vùng world tham khảo: x=416, y=1472, rộng 208, cao 64 px (khoảng 13×4 tile).
- Pixel gần màu cỏ nền hiện tại: 88.5% trong vùng khảo sát.
- Một gò dài và thấp sẽ chia nhịp dải xanh giữa đường lát và sông. Chừa khoảng thở cho cây hiện có và bờ nước; không đưa gò vào lưới trồng cây.

## 6. Khoảng cỏ giữa khu cắm trại và cửa hàng hạt giống

- Tileset: mép cỏ. Ưu tiên: Thấp.
- Vùng world tham khảo: x=368, y=96, rộng 208, cao 96 px (khoảng 13×6 tile).
- Pixel gần màu cỏ nền hiện tại: 85.6% trong vùng khảo sát.
- Một mảng gò nhỏ quanh cụm cây sẽ nối khu nghỉ với phố chợ. Chừa đường ngang, sân lều và lối tới cửa hàng; không làm thành một dải liên tục.

## Các vùng nên giữ thoáng

- Ruộng rau tây bắc, vườn cây ăn quả tây nam và rừng gỗ phía nam là các lưới sản xuất. Không đặt gò trong ô trồng hoặc lối thao tác của công nhân.
- Giữ các sân chuồng, cửa công trình, bệ đài phun nước, ghế và đường đất/lát gạch ở cao độ hiện tại.
- Khi triển khai, thu mép gò vào trong vùng đánh dấu và chừa ít nhất 2–3 tile tại đường/cổng; chừa ít nhất 2 tile với mép nước. Vị trí 3 cần thu hẹp theo bờ ao thực tế; vị trí 2 phải chừa lối ra từ cả hai cổng kho.
- Chưa kiểm tra va chạm hoặc điều hướng cho gò đề xuất vì chưa sửa world. Cần quyết định chúng chỉ là trang trí hay có cơ chế chặn bước trước khi triển khai gameplay.

Tỷ lệ cỏ phẳng được đếm từ ảnh render hiện tại bằng các pixel có RGB cách màu nền #43894f dưới 5 ở từng kênh. Chỉ số dùng để so mức độ trống trong các vùng khảo sát, không phải bằng chứng rằng vùng không có vật cản.
