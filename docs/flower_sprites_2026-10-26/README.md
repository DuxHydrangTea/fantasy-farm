# Modular flower sprites — PixelLab unzoom

Key lấy từ cấu hình dự án, đuôi 5225. Không dùng kết nối MCP cũ. Input là bản concept Codex đã duyệt, tách riêng từng cây và pad trong canvas256×256 để đủ kích thước tối thiểu của PixelLab, giữ pixel và alpha gốc.

28 cây đầu đã chạy PixelLab unzoom thật, trả sprite với kích thước dò lưới khác nhau (job ID và kích thước xem manifest). Kết quả opaque được xóa nền bằng flood-fill trắng, dùng alpha gốc bảo vệ hoa trắng và các lỗ giữa thân. Sau đó crop nội dung, fit theo tỉ lệ bằng nearest-neighbour, pad vào khung32×48, căn gốc ở giữa phía dưới. Không kéo méo và không dùng ảnh gốc thay cho kết quả unzoom.

PNG riêng: `assets/Flowers/Modular32x48/`. Có sheet cây32×48 theo8 cột; các vị trí còn thiếu để trong suốt. Các sprite chưa thay vào resource trong game.

## Chưa hoàn tất do dịch vụ

Còn Cosmos (29), Gardenia (30), Anemone (31), Lily (32) và chậu đất32×20. PixelLab từ chối tạo job mới với thông báo: "We're seeing long queues right now and free generations are temporarily unavailable. A subscription or credits work immediately." Đã thử lại có giãn cách và kiểm tra riêng từng ảnh, cùng lỗi. Không tạo ảnh thay thế cục bộ rồi gắn nhãn là PixelLab.

Chạy tiếp bằng `node scripts/unzoom_flower_pack.mjs`; helper tái dùng mọi job đã tạo và ảnh đã tải, không tạo lại28 ảnh. Sau khi đủ33 kết quả chạy `python3 scripts/finish_flower_sprites.py` để lưu chậu, chuẩn hóa cả32 cây và tạo ảnh ghép xem trước. Có thể chạy với `--partial` để xuất riêng ảnh sẵn có.
