# Cozy HUD — bộ asset chuẩn hóa

## Sản phẩm

4 nhóm asset (5 PNG): hotbar, ô hotbar thường/đang chọn, tiền và thời tiết.
PNG ở `assets/Ui/CozyHUD/`; StyleBoxTexture và Theme ở
`resources/ui/cozy_hud/`. Mở `scenes/ui/previews/cozy_hud_preview.tscn`,
chạy F6 để thử. Click/chạm chọn ô; Tab dùng focus bàn phím.
Scene này dùng để duyệt asset riêng. Bộ asset hiện đã được gắn vào HUD gameplay:
hotbar và nút túi, khung ô công cụ, tiền ở góc phải và thời tiết ở góc trái.
Túi đồ đã có theme mới; xem `docs/inventory_redesign_2026-10-27/README.md`. Các menu khác vẫn dùng theme trước đó.

| PNG | Kích thước gốc | Vùng cố định mỗi cạnh |
| --- | --- | --- |
| slot_normal / slot_selected | 32 × 32 | 8 px |
| hotbar | 240 × 48 | 8 px |
| wallet | 96 × 32 | 8 px |
| weather | 112 × 32 | 8 px |

Gắn Theme mới lên cụm HUD hoặc dùng StyleBox riêng. PanelContainer dùng
`HotbarPanel`, `WalletPanel`, `WeatherPanel` làm theme_type_variation.
Các nút dùng normal/hover/pressed/focus của Theme. Theme này là bộ preview
giới hạn cho 4 nhóm asset; chưa có bộ trạng thái disabled và toàn bộ component
menu. Không gắn nó làm Theme toàn game khi chưa hoàn thiện các component đó.

Dùng `texture_filter = 1` (Nearest) ở Control cha, tắt mipmap; giữ tọa độ và
kích thước nguyên. StyleBox co giãn phần giữa, góc luôn giữ 8 px. Nội dung có
padding riêng: slot 8, hotbar 12, tiền/thời tiết ngang 12 và dọc 10.
Nút tương tác tối thiểu 48 × 48; preview dùng 56 × 56.
Tránh kéo cả PNG bằng TextureButton.STRETCH_SCALE nếu cần giữ góc nguyên:
dùng Button có StyleBoxTexture hoặc NinePatchRect.

## Nguồn và xử lý

- `source/`: 4 ảnh imagegen gốc của cuộc hội thoại, lưu nguyên trạng.
- `unzoom/`: kết quả PixelLab Unzoom, quantize=16, nền trắng. ID job ở
  `provenance.json`. Không dùng các bản nền trắng này trực tiếp trong game.
- Unzoom tự phát hiện lưới khác nhau (slots 125×63; hotbar 128×45;
  wallet 92×32; weather 443×223). Dùng riêng kết quả Unzoom không tạo ra một bộ
  đồng nhất. Bộ cuối lấy góc và cạnh của slot làm chuẩn; 3 ảnh panel giữ làm
  tài liệu tham khảo tỷ lệ, thay góc theo chuẩn chung.
- `scripts/ui/prepare_cozy_hud.py`: flood-fill nền trắng từ mép, chuẩn hóa
  palette, tách hai slot, giữ cùng alpha, ghép góc cố định và lặp tiết diện
  cạnh một pixel. Phần giữa dùng màu kem phẳng để không kéo méo gradient.
- Chạy lại bằng `python3 scripts/ui/prepare_cozy_hud.py` (Pillow).
- Bộ PNG dùng palette chung 14 màu (thêm xanh sage cho nút chính của túi đồ), mỗi PNG dùng 10–11 màu kể cả trong suốt;
  alpha chỉ 0/255. Không có pixel bán trong suốt ở mép.

## Kiểm chứng

Godot 4.7.2, Compatibility renderer, project preview tách biệt trong /tmp,
không nạp autoload hoặc save cá nhân. Font và icon lấy từ dự án hiện tại.

- 960×540 và 844×390: kiểm tra 32 Control, không overlap/zero-size/offscreen.
- Click ô thứ hai: ô thứ hai được chọn, ô thứ nhất bỏ chọn ở cả hai kích thước.
- Hai ảnh chụp runtime không rỗng, nhãn tiếng Việt hiển thị được.
- Hai lần chạy scenario không có lỗi hoặc cảnh báo engine.
- Lint toàn repository: 0 lỗi, 11 cảnh báo có sẵn cả trước và sau; không phát
  sinh thêm. Chưa chạy nghiệm thu trên điện thoại vật lý.

`asset-preview.png`: bảng asset phóng nearest; `desktop.png`, `mobile.png`:
ảnh runtime; `verification.json`: kết quả gọn; `*-layout.json`: bố cục thực.
Các file `*-scenario.json` chạy bằng run_scenario.py của skill Godot với
project preview đã nạp các dependency; đường dẫn đầu ra thuộc workspace này.

## Tích hợp HUD gameplay

- `scenes/ui/hotbar.tscn`: Tray PanelContainer và Theme mới.
- `InventorySlot` dùng NinePatchRect khi `hotbar_skin=true` hoặc `cozy_skin=true`; giữ nguyên
  TextureButton và logic chuyển/chọn vật phẩm. Các ô trong túi dùng `cozy_skin`.
- Hotbar sở hữu WalletHUD, cập nhật theo signal của ví và ẩn khi menu mở.
- Khung thời tiết và nút túi dùng Theme mới; các nút vùng công cụ và hạt từ kho
  trên desktop được dời xuống dưới khung tiền để tránh đè nhau.
- Native touch mode ẩn debug thời tiết khi đổi từ desktop sang touch.
- Bộ kiểm thử chạy theo thời gian thực: 34/34 test, 408 assertions, gồm
  hotbar, inventory và mobile controls. Lượt fixed-fps trước đó không phù hợp
  với test hết hạn feedback dùng đồng hồ thực; lượt thời gian thực đạt toàn bộ.
- Ảnh và báo cáo native trên cảnh nông trại ở `live/`. Dùng bản staging và
  thư mục dữ liệu QA riêng; không nạp save cá nhân.
- Log native vẫn có các cảnh báo UID cũ của tài nguyên hoa, engine dùng
  đường dẫn dự phòng; không phải cảnh báo từ các asset HUD mới.
