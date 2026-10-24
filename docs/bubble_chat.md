# Bubble chat NPC

Cập nhật ngày 24/10/2026: dùng asset có sẵn `assets/Ui/bubble-chat.png` thay cho panel theme và tam giác Polygon2D ghép tay.

Style dùng chung nằm tại `resources/ui/merchant_bubble_panel.tres`: StyleBoxTexture lấy vùng (8,9,32,35) trong ảnh 48×48, bỏ khoảng trong suốt quanh ảnh bằng region_rect. Nine-patch giữ góc, viền và phần đuôi trong dải phải/dưới cố định để đuôi không bị kéo dài khi chữ EN/VI đổi chiều rộng. Không sửa ảnh nguồn. Chữ nâu đậm trên nền trắng, lấy font hiện tại; nền và chữ không chặn input.

Áp dụng cho `scenes/characters/shop_merchant.tscn`, `scenes/characters/produce_buyer.tscn` và presentation dùng khi gắn ShopMerchant vào NPC có sẵn (`scenes/ui/merchant_interaction.tscn`). Các node Tail cũ đã bỏ. ShopMerchant căn đầu đuôi theo vị trí NPC, bù cả interaction_offset của presentation động. Giao dịch và thời gian hiện lời cảm ơn 3,5 giây giữ nguyên.

QA trong [thư mục bằng chứng](bubble_chat_2026-10-24/): 33/33 kiểm tra native trên ba kiểu NPC, EN/VI, đúng asset, không còn Tail ghép, padding chữ và tự ẩn. Đã xem ảnh render trực tiếp. Lint 0 lỗi/0 cảnh báo; engine validation không có lỗi/cảnh báo thuộc phần thay đổi, còn 22 cảnh báo dependency có sẵn.

Web Compatibility export thành công với asset mới.
