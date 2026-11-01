extends Node
## Canvas motion avoids interference from container layout and UI scaling.
var motion: Tween
var target: Node
var property: NodePath
var baseline: float

func configure(moving: Node, path: NodePath, content: Control) -> void:
	target = moving
	property = path
	baseline = float(target.get_indexed(property))
	if content is ColorRect:
		(content as ColorRect).color.a = 0.0
	for child: Node in content.get_children():
		if child is ColorRect:
			(child as ColorRect).color.a = 0.0

func stop() -> void:
	if motion != null:
		motion.kill()
		motion = null
	target.set_indexed(property, baseline)

func enter() -> void:
	stop()
	target.set_indexed(property, baseline + 12.0)
	motion = create_tween()
	motion.tween_property(target, property, baseline, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func leave(done: Callable) -> void:
	if motion != null:
		motion.kill()
	motion = create_tween()
	motion.tween_property(target, property, baseline + 12.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	motion.tween_callback(done)
