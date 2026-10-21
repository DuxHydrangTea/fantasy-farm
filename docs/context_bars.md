# Thanh trạng thái theo focus

`Player/ContextBars` điều khiển phần hiển thị của cây ruộng, hoa trong chậu và thanh đói/khát của vật nuôi. Mặc định thanh ẩn, kể cả sau khi tải save. Tiến độ và chỉ số vẫn cập nhật bình thường.

`ContextBarsComponent` nhận các tham chiếu có kiểu qua export trong scene; `FarmPlayer.context_bars` trỏ tới component. Đổi tên node không làm mất wiring hoặc chức năng hover/focus.

- Người chơi focus ô cây trước mặt theo `FarmingActionComponent`, chậu hoa theo `FlowerInteraction`, hoặc vật nuôi gần nhất ở phía trước trong tầm 32 px. Máng đang được focus giữ ưu tiên tương tác.
- Con trỏ ở trên phần sprite nhìn thấy hoặc cách mép tối đa 5 px sẽ hiện thanh của đối tượng gần nhất. Dùng tọa độ thế giới và transform sprite nên hỗ trợ camera zoom, scale và sprite lật.
- Focus và hover có thể hiện đồng thời hai đối tượng. Chậu rỗng không hiện thanh; hover hoa không bật marker focus. Mở túi đồ ẩn thanh; khi đóng, focus/hover được kiểm tra lại.
- Vật nuôi được hover hoặc focus dừng di chuyển và giữ state `IDLE` tới khi cả hai nguồn đều rời đi. Con đang nằm/ngủ trên cạn hoàn tất đứng dậy trước; vịt dưới nước dùng `swim_idle`. Con khác tiếp tục hoạt động bình thường.
- Dừng để tương tác hủy chuyến đi/bữa ăn hiện tại và nhả chỗ đã giữ ở máng, không tiêu hao thức ăn/nước. Bỏ chọn thì AI tự quyết định lại, kể cả đi ăn/uống hoặc đưa trứng lên bờ. Mở túi đồ hoặc tháo ContextBars cũng nhả trạng thái giữ.
- `show_needs = false` chỉ tắt thanh; con vật vẫn phản ứng idle khi hover/focus. Tuổi, đói/khát và sản xuất vẫn cập nhật theo đồng hồ; không lưu trạng thái focus vào save.

Component cập nhật mỗi 0,05 giây; hover cây chỉ tra cứu các ô lân cận trong grid, không quét toàn bộ ruộng. Vùng ảnh không trong suốt được cache theo texture. Không lưu trạng thái hiển thị vào file save.

## Animal information

`ContextBarsComponent.animal_info` is an optional typed `AnimalInfoPanel`
reference. The component creates a scene instance automatically when unassigned.
Hovering an animal takes priority over an animal in facing range for this one
screen-space inspector. Existing needs bars/idle behavior remain independent.
Menus, removal and death clear the inspector; production eligibility and model
state remain unchanged. See [animal status UI](animal_status_ui.md).
