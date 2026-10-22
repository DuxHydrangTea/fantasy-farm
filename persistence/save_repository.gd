class_name SaveRepository
extends RefCounted
## Backend contract. Methods may be synchronous or coroutines; callers await them.
## Online implementations must enforce expected_revision atomically on the server.
func read_profile(_profile_id: String) -> Dictionary:
	return {"ok": false, "code": "unsupported", "error": "Backend does not support reading."}

func write_profile(_profile_id: String, _snapshot: Dictionary, _expected_revision: int) -> Dictionary:
	return {"ok": false, "code": "unsupported", "error": "Backend does not support writing."}

func write_profile_async(profile: String, snapshot: Dictionary, expected_revision: int, _pre_validated: bool = false) -> Dictionary:
	# HTTP/fake backends can retain their existing coroutine implementation.
	return await write_profile(profile, snapshot, expected_revision)
