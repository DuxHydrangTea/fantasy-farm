class_name GameLanguage
extends Node
## Entry point for a future language selector. Current builds start in English.
const DEFAULT_LANGUAGE: String = "en"
const SUPPORTED_LANGUAGES: PackedStringArray = ["en", "vi"]

func _enter_tree() -> void:
	set_language(DEFAULT_LANGUAGE)

func set_language(language: String) -> bool:
	if not SUPPORTED_LANGUAGES.has(language):
		return false
	TranslationServer.set_locale(language)
	return true
