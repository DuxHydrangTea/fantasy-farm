class_name GameLanguage
extends Node
## Thiết lập ngôn ngữ giao diện khi autoload vào scene tree.

## Ngôn ngữ mặc định.
const DEFAULT_LANGUAGE: String = "vi"
## Các locale cho phép chọn.
const SUPPORTED_LANGUAGES: PackedStringArray = ["en", "vi"]

func _enter_tree() -> void:
	FarmUI.load_preferences()
	set_language(FarmUI.language)

## Đổi locale nếu được hỗ trợ và cập nhật thuộc tính lang trên web.
## Trả false khi mã ngôn ngữ không nằm trong danh sách.
func set_language(language: String) -> bool:
	if not SUPPORTED_LANGUAGES.has(language):
		return false
	TranslationServer.set_locale(language)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.documentElement.lang = '" + language + "'")
	return true
