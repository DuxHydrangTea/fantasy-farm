# Mouse Meadow

Font pixel nguyên bản, có nét bất quy tắc như được vẽ bằng chuột. Mỗi kiểu có 560 ký tự, đủ 146 ký tự tiếng Việt hoa/thường và ASCII in được.

| File | Kiểu |
| --- | --- |
| `MouseMeadow-Regular.ttf` | Regular |
| `MouseMeadow-Bold.ttf` | Bold |
| `MouseMeadow-Italic.ttf` | Italic |
| `MouseMeadow-BoldItalic.ttf` | Bold Italic |

## Dùng trong Godot

Đường dẫn resource: `res://common/ui/fonts/Mouse_Meadow/`.

Sau khi Godot quét và import các file, kéo font từ FileSystem vào thuộc tính **Theme Overrides > Fonts > Font** của Label/Button, hoặc đặt **Default Font** trong Theme của giao diện. Chọn đúng file tương ứng khi cần chữ đậm hoặc nghiêng.

Đặt cỡ chữ trong **Theme Overrides > Font Sizes**. Font được thiết kế trên lưới 80 đơn vị với em 1600 đơn vị; cỡ **20, 40, 60, 80… px** giữ pixel nguyên khi vị trí và scale của Control cũng nằm trên lưới nguyên.

Để giữ nét pixel, trong Import dock của font nên đặt **Subpixel Positioning: Disabled**, giữ **Multichannel Signed Distance Field: Off**, rồi Reimport. Dùng **Texture Filter: Nearest** cho Control hoặc project. Không ép line-height quá thấp vì tiếng Việt có cả dấu trên và dấu dưới.

Tham khảo: [Godot — Using Fonts](https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_fonts.html).

## Giấy phép và nguồn gốc

Các font được tạo cho dự án với sự hỗ trợ của Codex ngày 2026-10-12, từ các bản vẽ pixel riêng; không lấy glyph hoặc outline của font khác. Regular là bản 1.0; các kiểu bổ sung là bản 1.1.

Phát hành theo **SIL Open Font License 1.1**, không có Reserved Font Name. Được dùng trong game và sản phẩm thương mại. Khi phân phối font, giữ thông báo bản quyền và toàn bộ giấy phép trong `OFL.txt`; bản font chỉnh sửa vẫn phải dùng OFL. Không bán riêng font. Tác phẩm tạo bằng font không bắt buộc phải dùng OFL.

Các file đã được đối chiếu checksum với bản xuất gốc, kiểm tra bảng ký tự tiếng Việt và giấy phép nhúng. Việc thêm asset này không tự thay đổi font trong scene hoặc theme hiện có.
