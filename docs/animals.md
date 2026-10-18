# Vật nuôi

Scene dùng: `scenes/animals/chicken.tscn`. MainWorld có một Chicken trong
`CoopPen`, ở khu hàng rào bên phải, cạnh công trình Coop hiện có.

## Thành phần dùng chung

- `animal.tscn` / `AnimalActor`: nối dữ liệu loài, collider chân, sprite và UI.
- `MovementComponent`, `AnimationComponent`: dùng chung với nhân vật hiện tại.
- `AnimalWanderComponent`: chọn đích ngẫu nhiên, đi rồi nghỉ; chọn đích khác khi
  bị vật cản chặn. Kiểm tra collider tại đích, dùng `move_and_slide` khi di chuyển.
- `AnimalNeedsComponent`: no (`satiety`) và nước (`hydration`), mỗi con giữ riêng.
- `AnimalPen`: giới hạn cứng vùng đi lại; áp dụng cả khi hàng rào có khoảng hở.
- `AnimalDefinition`: tốc độ, thời gian nghỉ, kích thước chân, khoảng cách mép rào,
  thời gian tiêu hao thức ăn/nước và SpriteFrames. Không gắn logic riêng theo loài
  trong các component.

Scene gà kế thừa scene chung và gán `animals/definitions/chicken.tres`.
`skin_frames` có thể gán bất kỳ bộ `chicken_01_frames`…`chicken_18_frames`;
skin thiếu idle/walk tự dùng lại bộ mặc định. Hình gốc nhìn trái; quay phải lật
sprite, giữ hướng khi đi dọc. Sprite được neo chân từ vùng pixel không trong suốt.

## Vùng chuồng

`MainWorld/CoopPen` ở `(1008, 288)`, bounds local `(0, 0, 384, 256)` nằm trong
hàng rào `(62,17)`…`(87,34)`. Scene Pen có Y-sort để gà và công trình sắp theo chân.
Vùng xanh nhạt chỉ vẽ trong editor. Di chuyển Pen hoặc sửa Bounds ở Inspector để
đổi vùng; nó hỗ trợ tịnh tiến, xoay, scale. Đặt vật nuôi làm con của Pen sẽ tự nhận
vùng; hoặc gán thuộc tính `pen` khi đặt vật nuôi ở nơi khác trong scene tree.

Vật nuôi không được gán Pen sẽ đứng yên. Nếu bị đẩy hoặc đặt ra ngoài vùng,
component đưa nó về trong vùng và chọn lại đích. Rào không cần collider để giới
hạn gà, nhưng công trình/người/vật cản có collider vẫn được xét bình thường.
AI hiện chọn đường thẳng và chọn lại khi bị chặn, chưa tìm đường qua mê cung.

## Đói và khát

Hai giá trị là **mức còn lại**, từ 0 đến 100: càng thấp càng đói/khát.
Thanh cam phía trên biểu diễn độ no, thanh xanh bên dưới biểu diễn nước.
`show_needs` bật/tắt hiển thị. Gà mất hết độ no sau 600 giây, hết nước sau
300 giây theo cấu hình hiện có; từng loài có thể đổi các thông số này.

Component dùng Unix timestamp của TimeManager, không phụ thuộc FPS. Thời gian
pause/mở túi vẫn tính vào nhu cầu khi cập nhật tiếp, đồng bộ cách tính của cây.
Timestamp lặp/lùi không trừ hai lần; giá trị luôn giới hạn trong 0…100.

`needs.feed(25.0)` / `needs.drink(25.0)` hồi chỉ số và trả về lượng hồi thực tế.
Đây là điểm nối để bổ sung máng ăn/máng nước; chưa có thao tác tự ăn/uống,
chết, sinh sản, trưởng thành, tạo sản phẩm hay save/load trong lượt này.
Các resource sản phẩm cũ được giữ để các định nghĩa loài hiện có tải đúng.

## Thêm bò, cừu, lợn

Tạo scene kế thừa `animal.tscn`, gán definition tương ứng, chỉnh move_speed,
footprint, pen_margin, thời gian nghỉ và nhu cầu theo loài. Đặt instance dưới Pen
phù hợp. Không cần sao chép AI, logic đói/khát hoặc animation controller.

## Kiểm tra

GUT kiểm tra tiêu hao/hồi nhu cầu, timestamp lặp/lùi, độc lập giữa các con,
giới hạn Pen có transform, đi lại thật qua physics frames, va chạm công trình,
lật sprite, đứng yên khi thiếu Pen, skin và khả năng dùng definition bò/cừu/lợn.

`godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit`

Preview thủ công: `godot --path . -s tests/support/animal_preview.gd`.
