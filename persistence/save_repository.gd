class_name SaveRepository
extends RefCounted
## Hợp đồng backend đọc và ghi snapshot của profile.
##
## Hàm triển khai có thể đồng bộ hoặc coroutine; nơi gọi dùng await.
## Backend online cần kiểm tra expected_revision nguyên tử tại server.

## Đọc profile theo mã và trả dictionary kết quả. Bản cơ sở báo không hỗ trợ.
func read_profile(_profile_id: String) -> Dictionary:
	return {"ok": false, "code": "unsupported", "error": "Backend does not support reading."}

## Ghi snapshot nếu revision hiện tại khớp giá trị dự kiến.
## Bản cơ sở báo không hỗ trợ.
func write_profile(_profile_id: String, _snapshot: Dictionary, _expected_revision: int) -> Dictionary:
	return {"ok": false, "code": "unsupported", "error": "Backend does not support writing."}

## Giao diện ghi bất đồng bộ; bản cơ sở chờ triển khai [method write_profile].
## Tham số pre_validated được backend cụ thể sử dụng nếu hỗ trợ.
func write_profile_async(profile: String, snapshot: Dictionary, expected_revision: int, _pre_validated: bool = false) -> Dictionary:
	# HTTP/fake backends can retain their existing coroutine implementation.
	return await write_profile(profile, snapshot, expected_revision)
