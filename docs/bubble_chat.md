# Bubble chat NPC

Bubble dùng chung cho NPC bán hàng và mua nông sản qua `resources/ui/merchant_bubble_panel.tres`. Asset `assets/Ui/speech-bubble-pixellab.png` được tạo bằng PixelLab Pixen, sau đó unzoom bằng PixelLab và cắt nền tối để lấy ảnh trong suốt. Bản unzoom gốc được giữ tại `docs/bubble_chat_pixellab_2026-10-28/unzoom-source.png`.

StyleBoxTexture và material lật ngang giữ phần đuôi ở góc dưới bên trái bằng nine-patch; phần chữ vẫn đọc bình thường. Khung giãn theo nội dung tiếng Việt và tiếng Anh, rồi tự ẩn sau 3,5 giây.
