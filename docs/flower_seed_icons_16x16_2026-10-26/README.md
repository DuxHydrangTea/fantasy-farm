# Hạt giống hoa 16×16 — 32 loại

Nguồn là ảnh người dùng gửi (lưu `source.png`). Tất cả 32 túi hạt giống được tách theo thứ tự 8 cột × 4 hàng, không lấy nhãn chữ.

PixelLab unzoom (`6b0184a3-dec3-41e6-88d1-923e8ac12253`) nhận montage 1280×640 và trả 149×73. Do kết quả không chia đều theo 8×4 và palette 32 màu làm đổi một số màu hoa, PNG cuối lấy mẫu nearest-neighbour từng ô 160×160 gốc xuống 16×16, giữ màu ảnh gốc. Chỉ làm sạch silhouette: bỏ nền bốn góc, chuẩn hóa viền ngoài 1px đen; không tạo mới hình hoa. Không dùng nội suy mờ.

32 PNG riêng nằm tại `assets/Icons/seeds/flowers16/`, tên gồm số thứ tự + loài hoa. Sheet RGBA 128×64 nằm cùng thư mục, frame16×16. Các file `flower_01_seed_packet.png`…`flower_10_seed_packet.png` ở thư mục seeds được thay nội dung thành 16×16, giữ đường dẫn và UID import; resource hiện có tự dùng bản mới. 22 loại bổ sung chỉ được lưu asset, chưa tạo resource cây/giống mới.

`manifest.json` lưu mapping, source rectangle và hash. `preview-32-icons.png` là ảnh xem phóng to nearest-neighbour; PNG asset thật đều 16×16. Bản 32×32 của lần trước vẫn có thể khôi phục từ spritesheet PixelLab được lưu trong docs cũ.

## Dọn asset cũ

Đã chuyển 10 resource hạt giống hiện có sang PNG chuẩn trong `assets/Icons/seeds/flowers16/`. Xóa icon dùng chung cũ và 10 PNG trùng ở thư mục seeds gốc, cùng 11 sidecar import. Trong assets chỉ giữ bộ 32 icon 16×16 và sheet tương ứng. Ảnh nguồn và bản xem lịch sử trong docs chỉ phục vụ đối chiếu, không được game sử dụng.
