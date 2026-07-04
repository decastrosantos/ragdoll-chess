extends GPUParticles3D
## Explosão de poeira/faíscas disparada no momento da captura.
## Todo o material é construído em código para manter a cena .tscn enxuta.

func _ready() -> void:
	one_shot = true
	emitting = false
	explosiveness = 1.0   # todas as partículas nascem no mesmo instante (estouro)
	amount = 32
	lifetime = 0.9
	local_coords = false  # partículas ficam no mundo (não seguem a peça voadora)

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 75.0                      # cone largo, quase hemisférico
	material.initial_velocity_min = 3.0
	material.initial_velocity_max = 8.0
	material.gravity = Vector3(0.0, -12.0, 0.0)
	material.scale_min = 0.5
	material.scale_max = 1.4
	process_material = material

	# Cada partícula é uma esferinha "de poeira" sem sombreamento.
	var mesh := SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	var mesh_material := StandardMaterial3D.new()
	mesh_material.albedo_color = Color(0.62, 0.52, 0.4)
	mesh_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mesh_material
	draw_pass_1 = mesh


## Dispara o estouro (pode ser chamado múltiplas vezes).
func burst() -> void:
	restart()
	emitting = true
