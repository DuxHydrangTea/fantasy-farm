class_name GameText
extends RefCounted
## Các hàm định dạng và dịch chuỗi tại lớp trình bày.
## Mã model, khóa save và mã lỗi được giữ độc lập với ngôn ngữ.

## Dịch trường error của kết quả rồi thế các giá trị error_values.
static func error(result: Dictionary) -> String:
	return String(TranslationServer.translate(String(result.get("error", "")))).format(result.get("error_values", {}))

## Định dạng số nguyên theo nhóm ba chữ số, dùng dấu chấm cho locale tiếng Việt.
static func grouped_integer(value: int) -> String:
	var digits: String = str(value)
	var separator: String = "." if TranslationServer.get_locale().begins_with("vi") else ","
	var result: String = ""
	while digits.length() > 3:
		result = separator + digits.right(3) + result
		digits = digits.left(digits.length() - 3)
	return digits + result

## Tên phím đầu tiên được gán cho action, hoặc E nếu không có phím.
static func action_key(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key: InputEventKey = event as InputEventKey
			return OS.get_keycode_string(key.physical_keycode if key.physical_keycode != 0 else key.keycode)
	return "E"
