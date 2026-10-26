# Icon hạt giống hoa — PixelLab, 2026-10-26

10 icon mới cho Rose, Carnation, Orchid, Lavender, Bluebell, Hydrangea, Marigold, Sunflower, Lily of the Valley và Blue Lotus. Túi giấy đồng bộ, minh họa và màu theo từng loài, viền đen, không chữ và không bóng đổ. PNG RGBA 32×32 px, alpha chỉ 0/255.

PixelLab `create_image_pixen` tạo spritesheet 160×64 (5×2), phí 1 generation. Lưu prompt, job ID và mapping trong `prompt.txt` / `manifest.json`. Tách lưới nguyên bản thành 10 PNG tại `assets/Icons/seeds/flower_01_seed_packet.png` đến `flower_10_seed_packet.png`, không resize/redraw. Đã gắn 10 resource `items/seeds/flower_XX_seed.tres`. Icon cũ dùng chung giữ lại để không làm hỏng các tham chiếu khác.

Kiểm tra: Godot import thành công và hiển thị cả 10 resource qua InventorySlot thật; không lỗi (`verification.json`, `inventory-preview.png`). Linter trước/sau đều 0 lỗi và 11 cảnh báo ảnh QA có từ trước. Preview bảng màu nền caro chỉ dùng để xem; PNG trong assets có nền trong suốt.

Sau thao tác, tài khoản còn 1 generation, credits $0.00.
