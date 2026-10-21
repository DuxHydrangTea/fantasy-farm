class_name GameText
extends RefCounted
## Translate complete source messages at the presentation boundary, after IO.
## Model IDs, save keys and error codes always remain language-independent.
static func error(result: Dictionary) -> String:
	return String(TranslationServer.translate(String(result.get("error", "")))).format(result.get("error_values", {}))

static func grouped_integer(value: int) -> String:
	var digits: String = str(value)
	var separator: String = "." if TranslationServer.get_locale().begins_with("vi") else ","
	var result: String = ""
	while digits.length() > 3:
		result = separator + digits.right(3) + result
		digits = digits.left(digits.length() - 3)
	return digits + result

static func action_key(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key: InputEventKey = event as InputEventKey
			return OS.get_keycode_string(key.physical_keycode if key.physical_keycode != 0 else key.keycode)
	return "E"
