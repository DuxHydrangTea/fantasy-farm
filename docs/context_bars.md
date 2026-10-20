# Thanh trạng thái theo focus

`Player/ContextBars` điều khiển phần hiển thị của cây ruộng, hoa trong chậu và thanh đói/khát của vật nuôi. Mặc định thanh ẩn, kể cả sau khi tải save. Tiến độ và chỉ số vẫn cập nhật bình thường.

`ContextBarsComponent` nhận các tham chiếu có kiểu qua export trong scene; `FarmPlayer.context_bars` trỏ tới component. Đổi tên node không làm mất wiring hoặc chức năng hover/focus.

- Người chơi focus ô cây trước mặt theo `FarmingActionComponent`, chậu hoa theo `FlowerInteraction`, hoặc vật nuôi gần nhất ở phía trước trong tầm 32 px. Máng đang được focus giữ ưu tiên tương tác.
- Con trỏ ở trên phần sprite nhìn thấy hoặc cách mép tối đa 5 px sẽ hiện thanh của đối tượng gần nhất. Dùng tọa độ thế giới và transform sprite nên hỗ trợ camera zoom, scale và sprite lật.
- Focus và hover có thể hiện đồng thời hai đối tượng. Chậu rỗng không hiện thanh; hover hoa không bật marker focus. Mở túi đồ ẩn thanh; khi đóng, focus/hover được kiểm tra lại.
- `show_needs = false` vẫn tắt thanh của vật nuôi tương ứng.

Component cập nhật mỗi 0,05 giây; hover cây chỉ tra cứu các ô lân cận trong grid, không quét toàn bộ ruộng. Vùng ảnh không trong suốt được cache theo texture. Không lưu trạng thái hiển thị vào file save.
