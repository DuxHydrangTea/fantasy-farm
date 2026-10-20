class_name SaveRepository
extends RefCounted
## Backend contract. Methods may be synchronous or coroutines; callers await them.
## Online implementations must enforce expected_revision atomically on the server.
func read_profile(_profile_id: String) -> Dictionary:
	return {"ok": false, "code": "unsupported", "error": "Backend chưa hỗ trợ đọc."}

func write_profile(_profile_id: String, _snapshot: Dictionary, _expected_revision: int) -> Dictionary:
	return {"ok": false, "code": "unsupported", "error": "Backend chưa hỗ trợ ghi."}
