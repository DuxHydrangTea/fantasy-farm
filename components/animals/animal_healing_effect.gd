extends Node2D
## Same slow, fading pixel particles as crop quality, tinted healing red.
const EMISSION_SECONDS: float = 1.5
const DURATION: float = 3.0
var elapsed: float = 0.0
var particles: GPUParticles2D

func _ready() -> void:
	z_index = 20
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(11, 4, 0)
	material.direction = Vector3(0, -1, 0)
	material.spread = 25.0
	material.gravity = Vector3(0, -3, 0)
	material.initial_velocity_min = 5.0
	material.initial_velocity_max = 10.0
	material.scale_min = 0.55
	material.scale_max = 1.0
	material.particle_flag_disable_z = true
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.25, Color.WHITE)
	fade.set_color(2, Color(1, 1, 1, 0))
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = fade
	material.color_ramp = ramp
	var image: Image = Image.create(5, 5, false, Image.FORMAT_RGBA8)
	for point: Vector2i in [Vector2i(2, 0), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(2, 3), Vector2i(2, 4)]:
		image.set_pixel(point.x, point.y, Color.WHITE)
	particles = GPUParticles2D.new()
	particles.name = "HealingParticles"
	particles.emitting = false
	particles.amount = 3
	particles.lifetime = 1.5
	particles.randomness = 0.7
	particles.position = Vector2(0, -8)
	particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particles.texture = ImageTexture.create_from_image(image)
	particles.process_material = material
	particles.modulate = Color(1.0, 0.22, 0.25, 0.8)
	add_child(particles)
	particles.emitting = true

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
	elif elapsed >= EMISSION_SECONDS:
		particles.emitting = false
