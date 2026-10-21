# Ngôn ngữ và font giao diện

Game khởi động bằng tiếng Anh, kể cả trên máy dùng ngôn ngữ khác. Autoload
`Language` (`GameLanguage`) đặt locale `en`. Chưa thêm menu chọn ngôn ngữ;
khi làm menu Settings, gọi:

```gdscript
Language.set_language("vi") # tiếng Việt
Language.set_language("en") # tiếng Anh
```

Hàm trả `false` và giữ nguyên locale khi nhận mã chưa hỗ trợ. Việc đổi ngôn
ngữ không thay đổi vật phẩm, tiền, tiến trình, lựa chọn hay giao dịch. Hiện tại
ngôn ngữ chưa được lưu giữa các lần mở game: mỗi phiên bắt đầu bằng tiếng Anh.

## Danh mục dịch

`localization/en.po` và `localization/vi.po` được đăng ký trong
`project.godot` → `internationalization/locale/translations`. Câu tiếng Anh là
`msgid`, bản dịch là `msgstr`; `en` là fallback. Đã có bản dịch tiếng Việt cho
nội dung hiện tại để kiểm chứng hệ thống, còn màn hình game mặc định dùng Anh.

- Text tĩnh trong scene giữ câu nguồn tiếng Anh; Control tự dịch khi vẽ.
- Text động gọi `tr(source)` **trước** `.format(values)`. Dùng placeholder có
  tên như `{coins}`, `{item}`, `{count}` để bản dịch được đổi thứ tự từ.
- `display_name` trong resource là câu nguồn tiếng Anh. Dịch bằng
  `tr(item.display_name)` tại UI; không gán bản dịch trở lại resource dùng chung.
- Giữ nguyên `item_id`, `animal_id`, `persistent_id`, enum, tên node, đường dẫn,
  khóa JSON và mã lỗi. Save chỉ ghi ID/dữ liệu, không ghi tên hiển thị đã dịch.
- Repository/schema/service trả lỗi tiếng Anh cùng `error_values` nguyên thủy.
  `GameText.error(result)` dịch và chèn biến ở lớp hiển thị, sau khi IO hoàn tất.
- Khi thêm câu mới, thêm vào **cả hai** file PO. Không dịch từng mảnh rồi nối
  thành câu. Giữ nguyên tên placeholder trong bản dịch. Tên resource và thông
  báo backend đi qua biến động nên cũng phải thêm thủ công vào danh mục dịch.

Ví dụ:

```gdscript
buy_button.text = tr("Buy ×{count} - {coins} coins").format({
    "count": amount,
    "coins": price * amount,
})
```

Inventory, hotbar, tooltip, wallet, popup và shop cập nhật text động khi nhận
`NOTIFICATION_TRANSLATION_CHANGED`. Shop dựng lại các thẻ sau notification,
giữ lại nhóm hàng, số lượng và cá thể đang chọn. Trough/flower prompt cập nhật
mỗi frame vật lý; lời cảm ơn giữ nguyên timer khi đổi ngôn ngữ. SaveManager lưu
câu nguồn/tham số của thông báo gần nhất và phát lại bản dịch khi đổi locale.

## Font

`resources/ui/game_font.tres` dùng `assets/Fonts/upheavtt.ttf` làm font chính.
Theme toàn cục, HUD, menu, thoại NPC và popup nhặt đồ đều dùng resource này.
Font được import với MSDF để giữ nét khi UI/camera thay đổi tỉ lệ.
Upheaval thiếu một số ký tự có dấu; chuỗi fallback hiện có
`pixelify_sans.tres` → Pixelify Sans / Mouse Meadow giữ tiếng Việt và ký tự
đặc biệt hiển thị được. Vì vậy các chữ có dấu có thể khác nét với chữ ASCII.

## Kiểm tra

`tests/integration/test_localization.gd` kiểm tra đổi Anh–Việt khi đang mở túi,
cửa hàng và bán vật nuôi; giữ dữ liệu/lựa chọn; dịch lỗi có tham số; đối chiếu
placeholder và glyph của toàn bộ bản dịch tiếng Việt. Chạy cùng bộ GUT của dự
án. `test_inventory_ui.gd` kiểm tra font chính là `upheavtt.ttf`.
