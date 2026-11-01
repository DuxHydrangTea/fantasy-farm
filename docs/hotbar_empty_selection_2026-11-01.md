# Hotbar: trạng thái tay không

- Lượt chơi mới bắt đầu selected_index=-1. Save cũ vẫn giữ selected_slot đã lưu.
- Click/chạm lại ô đang chọn hoặc nhấn lại phím số tương ứng để bỏ chọn. Escape khi không có menu cũng bỏ chọn.
- select_slot vẫn idempotent cho các caller programmatic; toggle_slot dành cho input. select_slot(-1) thoát cả chế độ giống trong kho.
- Không có ô nào được tô active khi tay không. Nhãn hiển thị Tay không / Empty hands.
- SaveSchema nhận -1..5; lưu/tải qua LocalSaveRepository giữ -1 và tiếp tục từ chối -2/6. Save cũ chọn ô 0 vẫn tải được.

Kiểm chứng: 39/39 test, 657 assertion trong hotbar_empty_selection_focused.log (unit selection, hotbar input, supply storage, mobile). Lint 0 lỗi/cảnh báo. Preview thật vi/en ở 1280/1920, hotbar không tô ô nào, nhãn Tay không.

Có chạy thêm suite world_persistence cũ (hotbar_empty_selection_tests.log): nhiều fixture cũ không khớp giá/động vật/vị trí hoa và cleanup SaveManager. Không sửa các fixture đó trong thay đổi hotbar; không coi toàn repo sạch lỗi. Ca save riêng trong test_supply_storage_flow đã qua, có disk roundtrip tay không, save chọn ô cũ và từ chối index ngoài miền.
