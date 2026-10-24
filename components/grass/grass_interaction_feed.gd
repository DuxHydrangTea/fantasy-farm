class_name GrassInteractionFeed
extends RefCounted
## One weak registry for the field. No grass queries or per-actor components.
const CAPACITY: int = 96
const RECOVERY: float = 0.18
var entries: Dictionary = {}
var segments: PackedVector4Array = PackedVector4Array()
var parameters: PackedVector4Array = PackedVector4Array()
var clock: float = 0.0
var upload_hz: int = 60
var eligible: int = 0
var uploaded: int = 0
var uploads: int = 0
var teleports: int = 0
var last_error: String = ""
var last_sample_usec: int = 0
var _root: Node
var _tree: SceneTree
var _elapsed: float = 0.0
var _dirty: bool = true

func _init() -> void:
	segments.resize(CAPACITY)
	parameters.resize(CAPACITY)

func attach(root: Node) -> void:
	detach()
	_root = root
	_tree = root.get_tree()
	_tree.node_added.connect(_added)
	_tree.node_removed.connect(_removed)
	for group: StringName in [&"farm_players", &"animal_status_targets", &"grass_interactors"]:
		for node: Node in _tree.get_nodes_in_group(group):
			_consider(node)

func detach() -> void:
	if is_instance_valid(_tree):
		if _tree.node_added.is_connected(_added):
			_tree.node_added.disconnect(_added)
		if _tree.node_removed.is_connected(_removed):
			_tree.node_removed.disconnect(_removed)
	_tree = null
	_root = null
	entries.clear()
	last_error = ""
	eligible = 0
	uploaded = 0
	_dirty = true

func _added(node: Node) -> void:
	if node is FarmPlayer or node is AnimalActor or node.is_in_group(&"grass_interactors"):
		_consider.call_deferred(node)

func _consider(node: Node) -> void:
	if not is_instance_valid(node) or not node is Node2D or not is_instance_valid(_root) or not _root.is_ancestor_of(node):
		return
	if node.is_in_group(&"farm_players") or node.is_in_group(&"animal_status_targets") or node.is_in_group(&"grass_interactors"):
		register_actor(node as Node2D)

func _removed(node: Node) -> void:
	if entries.erase(node.get_instance_id()):
		_dirty = true

func register_actor(actor: Node2D, radius: float = 0.0, strength: float = 6.0) -> void:
	var key: int = actor.get_instance_id()
	if entries.has(key):
		return
	var base_radius: float = radius
	if base_radius <= 0.0:
		base_radius = 14.0
		if actor is AnimalActor and actor.definition != null:
			base_radius = maxf(8.0, maxf(actor.definition.footprint.x, actor.definition.footprint.y) * 0.5 + 6.0)
	var point: Vector2 = actor.global_position
	entries[key] = {"ref": weakref(actor), "radius": maxf(1.0, base_radius), "strength": clampf(strength, 0.0, 12.0),
		"head": point, "tail": point, "observed": point, "motion_at": clock, "angle": 0.0, "present": true}
	_dirty = true

func reset_motion(actor: Node2D) -> void:
	# Explicit teleport/restore hook, also used automatically for implausible jumps.
	var key: int = actor.get_instance_id()
	if entries.has(key):
		var point: Vector2 = actor.global_position
		entries[key].head = point
		entries[key].tail = point
		entries[key].observed = point
		entries[key].motion_at = clock
		_dirty = true

func reset_all_motion() -> void:
	for entry: Dictionary in entries.values():
		var actor: Node2D = entry.ref.get_ref() as Node2D
		if actor != null and actor.is_inside_tree():
			reset_motion(actor)

func tick(delta: float, world_view: Rect2, material: ShaderMaterial, force: bool = false) -> void:
	clock += maxf(0.0, delta)
	_elapsed += maxf(0.0, delta)
	if clock > 1024.0:
		clock -= 512.0
		for entry: Dictionary in entries.values():
			entry.motion_at -= 512.0
		_dirty = true
	material.set_shader_parameter(&"interaction_clock", clock)
	if not force and not _dirty and _elapsed < 1.0 / float(maxi(1, upload_hz)) - 0.000001:
		return
	var began: int = Time.get_ticks_usec()
	_elapsed = fmod(_elapsed, 1.0 / float(maxi(1, upload_hz)))
	_dirty = false
	eligible = 0
	for key: int in entries.keys():
		var entry: Dictionary = entries[key]
		var actor: Node2D = entry.ref.get_ref() as Node2D
		if actor == null or not actor.is_inside_tree() or actor.is_queued_for_deletion() or (is_instance_valid(_root) and not _root.is_ancestor_of(actor)):
			entries.erase(key)
			continue
		if not actor.is_visible_in_tree() or (actor is AnimalActor and actor.is_dead()):
			entry.present = false
			continue
		var point: Vector2 = actor.global_position
		if not entry.present:
			reset_motion(actor)
			entry.present = true
		var radius: float = float(entry.radius) * maxf(actor.global_transform.x.length(), actor.global_transform.y.length())
		var movement: Vector2 = point - (entry.observed as Vector2)
		if movement.length() > maxf(96.0, radius * 8.0):
			entry.tail = point
			entry.head = point
			entry.motion_at = clock
			teleports += 1
		elif movement.length_squared() > 0.000001:
			entry.tail = entry.observed
			entry.head = point
			entry.motion_at = clock
			entry.angle = movement.angle()
		entry.observed = point
		var area: Rect2 = Rect2(entry.tail, Vector2.ZERO).expand(point).grow(radius)
		if not area.intersects(world_view, true):
			continue
		if eligible < CAPACITY:
			var tail: Vector2 = entry.tail
			segments[eligible] = Vector4(tail.x, tail.y, point.x, point.y)
			parameters[eligible] = Vector4(radius, entry.strength, entry.motion_at, entry.angle)
		eligible += 1
	uploads += 1
	uploaded = eligible if eligible <= CAPACITY else 0
	last_error = "" if eligible <= CAPACITY else "Interaction capacity exceeded: %d eligible / %d supported; no actors silently dropped" % [eligible, CAPACITY]
	material.set_shader_parameter(&"actor_count", uploaded)
	if uploaded > 0:
		material.set_shader_parameter(&"actor_segments", segments)
		material.set_shader_parameter(&"actor_parameters", parameters)
	last_sample_usec = Time.get_ticks_usec() - began

func stats() -> Dictionary:
	return {"registered": entries.size(), "eligible": eligible, "uploaded": uploaded, "capacity": CAPACITY,
		"upload_hz": upload_hz, "uploads": uploads, "teleports": teleports, "sample_usec": last_sample_usec, "error": last_error}
