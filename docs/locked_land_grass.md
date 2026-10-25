# Cỏ trên đất chưa mở — tương tác GPU

Đã triển khai ngày 25/10/2026. Cỏ che đất chưa mua vẫn giữ hai sprite gốc trong Outdoor_Decor, cùng vị trí và kiểu xen kẽ. Khi player/vật nuôi đi qua, phần ngọn nghiêng theo shader tương tác đang dùng cho cỏ toàn map; gốc giữ nguyên. Cỏ cũng nhận gió/thời tiết hiện tại.

## Cách thử

Mở lại game rồi đi vào phần ruộng còn phủ cỏ, chưa mua. Không cần vật phẩm hay thêm dữ liệu: hiệu ứng tự áp dụng cho toàn bộ ô đang khóa trong save hiện tại. Không thay tiền, số cột đã mua hoặc vị trí player. Tiếp tục mua cột đất để thấy cỏ được dọn dần như trước.

## Cấu trúc và hiệu năng

- `LandGrassCover` là RefCounted, không thêm node vào Scene Tree hay collider cho từng ô.
- Bốn CanvasItem RID dùng chung hai ShaderMaterial: hai RID cho phần đất khóa cố định và hai cho cột đang dọn. Chỉ dựng lại phần cố định khi số cột đổi; hoạt ảnh mở đất cập nhật riêng cột đang dọn.
- Dùng shader `grass_tilemap.gdshader` hiện có, giữ chính xác atlas UV, chân sprite và ánh sáng. Nhận actor segments và đồng hồ từ `FarmGrassField` qua cùng registry, không quét player/vật nuôi lần nữa.
- Thêm biên culling 12 pixel để ngọn đang nghiêng không bị cắt ở cạnh vùng vẽ. Không tính độ nghiêng từng ô bằng CPU.
- F10/tắt GPU hoặc fallback trả về cách vẽ tĩnh ban đầu. Headless giữ lớp tĩnh. Mở đủ đất không vẽ cỏ. Reset/load cập nhật từ số cột sở hữu; không đổi schema save.
- Khi thoát hoặc bật/tắt nhiều lần, giải phóng RID/material, không để lớp tĩnh và lớp GPU vẽ trùng.

## Kiểm chứng

- 43/43 test, 5 script: `.godot/land-grass-verified-tests-engine.log`. Gồm quyền sở hữu, mua đất, save/load, migration, registry tương tác, chunk và 4 RID/0 node mới.
- Fixture mở đất cũ được làm sạch lớp đất khởi đầu trước khi kiểm tra đất chưa cuốc; kiểm tra quyền mở cột không phụ thuộc vật cản trang trí của map; migration bảo toàn đất đã cuốc kể cả khi mưa offline làm đất ướt.
- Native Compatibility và Forward+: 16/16 checks mỗi renderer, `.godot/locked-grass-native/`. So ảnh GPU với bản gốc khi tắt gió/tương tác (sai lệch tối đa ≤1), so ảnh cùng vị trí player khi bật/tắt áp lực để chứng minh cỏ thật sự biến dạng; kiểm tra mở đất, reveal, reset, full unlock và fallback.
- Lint: `.godot/land-grass-final-lint.json`. Web build: `.dist/build-report.json`.

Chỉ chạy bản QA trong staging để kiểm tra; không sửa save cá nhân. Chưa đo trên điện thoại thật.
