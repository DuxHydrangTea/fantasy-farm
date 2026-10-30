# Concept bubble trạng thái — 30/10/2026

Đã được duyệt và tích hợp vào game ngày 30/10/2026. Asset chính thức nằm trong `assets/Ui/status_bubbles/`; không sử dụng thêm lượt PixelLab khi tích hợp.

- `concept_board.png`: bảng tổng hợp, icon phóng lớn và ví dụ nhiều trạng thái.
- `raw/`: ảnh PNG 16×16 nền trong suốt; bốn icon mới tạo bằng PixelLab Pixen. Cỏ được trích nguyên sprite đang dùng trong game.
- `preview/`: bubble đơn và nhóm, cùng bản phóng 8× để xem pixel. Bubble đơn 28×27, nhóm hai icon 48×27, nhóm ba icon 68×27.
- `hungry_alternate_16.png` trong raw là mẫu đầu tiên không chọn vì dễ nhầm mặt khóc.
- `manifest.json`: ID công việc, seed, nguồn sprite cỏ và chi phí. Tổng 5 lượt, bao gồm biến thể mặt đói.

Trong game: một bubble nằm trên đầu mỗi đối tượng có trạng thái; hiển thị các icon đang hoạt động cùng hàng, ẩn bubble khi không còn tình trạng. Cây có thể hiện cỏ + sâu; vật nuôi có thể hiện bệnh + đói + khát. Bubble bật lên nhẹ khi xuất hiện, không lặp animation mỗi nhịp cập nhật.

`build_concept.py` chỉ ghép các ảnh vào bảng trình bày bằng nearest-neighbor, không sửa pixel của icon PixelLab và không sửa scene gameplay. `scripts/assets/export_status_bubbles.py` xuất bộ asset chính thức, giữ nguyên pixel của icon đã duyệt.
