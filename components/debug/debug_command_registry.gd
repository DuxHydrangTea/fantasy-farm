class_name DebugCommandRegistry
extends RefCounted
## Explicit command allowlist. No expressions, script paths or eval.
var commands: Dictionary = {}

func register(path: String, usage: String, description: String, handler: Callable, write: bool = false) -> void:
	commands[path] = {"usage": usage, "description": description, "handler": handler, "write": write}

static func parse(line: String) -> Dictionary:
	line = line.strip_edges()
	if not line.begins_with("/"):
		return {"ok": false, "error": "Commands must start with /."}
	var tokens: Array[String] = []
	var token: String = ""
	var quote: String = ""
	var escaped: bool = false
	var started: bool = false
	for character: String in line.substr(1):
		if escaped:
			token += character
			escaped = false
		elif character == "\\":
			escaped = true
			started = true
		elif not quote.is_empty():
			if character == quote:
				quote = ""
			else:
				token += character
		elif character in ["\"", "'"]:
			quote = character
			started = true
		elif character in [" ", "\t", "\n", "\r"]:
			if started:
				tokens.append(token)
				token = ""
				started = false
		else:
			token += character
			started = true
	if escaped or not quote.is_empty():
		return {"ok": false, "error": "Unclosed quote or escape."}
	if started:
		tokens.append(token)
	if tokens.is_empty():
		return {"ok": false, "error": "Enter /help for available commands."}
	return {"ok": true, "tokens": tokens}

func resolve(tokens: Array) -> Dictionary:
	for length: int in range(tokens.size(), 0, -1):
		var path: String = " ".join(tokens.slice(0, length)).to_lower()
		if commands.has(path):
			return commands[path].merged({"path": path, "args": tokens.slice(length)})
	return {}

func help_text(prefix: String = "") -> String:
	var lines: PackedStringArray = []
	var paths: Array = commands.keys()
	paths.sort()
	for path: String in paths:
		if path.begins_with(prefix.to_lower()):
			lines.append("/%s — %s" % [commands[path].usage, commands[path].description])
	return "\n".join(lines)
