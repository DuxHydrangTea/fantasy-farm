extends Node
## Hiệu ứng trượt vào và ra cho nội dung modal trên canvas.
## Thuộc tính di chuyển và giá trị gốc được chọn khi cấu hình.

## Tween hiện tại, nếu có.
var motion: Tween
## Node có thuộc tính được làm chuyển động.
var target: Node
## Đường dẫn thuộc tính số trên target.
var property: NodePath
## Giá trị thuộc tính trước hiệu ứng.
var baseline: float

## Gắn node, thuộc tính và lưu giá trị gốc; làm trong suốt ColorRect nội dung.
func configure(moving: Node, path: NodePath, content: Control) -> void:
	target = moving
	property = path
	baseline = float(target.get_indexed(property))
	if content is ColorRect:
		(content as ColorRect).color.a = 0.0
	for child: Node in content.get_children():
		if child is ColorRect:
			(child as ColorRect).color.a = 0.0

## Dừng tween hiện tại và khôi phục thuộc tính về giá trị gốc.
func stop() -> void:
	if motion != null:
		motion.kill()
		motion = null
	target.set_indexed(property, baseline)

## Trượt từ vị trí lệch 12 đơn vị về giá trị gốc trong 0,16 giây.
func enter() -> void:
	stop()
	target.set_indexed(property, baseline + 12.0)
	motion = create_tween()
	motion.tween_property(target, property, baseline, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Trượt ra 12 đơn vị trong 0,12 giây rồi gọi callback hoàn tất.
func leave(done: Callable) -> void:
	if motion != null:
		motion.kill()
	motion = create_tween()
	motion.tween_property(target, property, baseline + 12.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	motion.tween_callback(done)
