class_name Piece
extends RigidBody3D
## Peça base (VISUALIZAÇÃO + FÍSICA).
##
## Truque central do protótipo: a peça é um RigidBody3D PERMANENTEMENTE, mas
## nasce com `freeze = true` (modo cinemático). Congelada, ela se comporta como
## um corpo estático/animável — podemos movê-la com Tween sem a física intervir.
## No instante da captura, basta `freeze = false` + um impulso para a engine
## assumir o controle e arremessá-la de forma hilária. Não há troca de nós
## (converter CharacterBody3D em RigidBody3D em runtime não é possível no Godot 4;
## congelar/descongelar é o padrão idiomático equivalente).

signal move_finished

enum Type { PAWN, ROOK, KNIGHT, BISHOP, QUEEN, KING }

# --- Movimento animado ---
const MOVE_DURATION := 0.5   # segundos até chegar na casa destino
const JUMP_HEIGHT := 1.4     # altura do pico do "pulo" durante o movimento

# --- Física da captura (valores exagerados de propósito!) ---
const CAPTURE_IMPULSE := 34.0     # magnitude do impulso linear (kg·m/s por kg)
const CAPTURE_UP_FACTOR := 0.55   # componente vertical adicionada à direção
const TORQUE_IMPULSE_MAX := 18.0  # giro aleatório para efeito cômico
const DESPAWN_DELAY := 3.5        # segundos até a vítima sumir da cena

# Escala de altura por tipo de peça (placeholders low-poly; o rei é o mais alto).
const TYPE_HEIGHT_SCALE := {
	Type.PAWN: 0.7,
	Type.ROOK: 0.9,
	Type.KNIGHT: 1.0,
	Type.BISHOP: 1.1,
	Type.QUEEN: 1.25,
	Type.KING: 1.4,
}

const COLOR_WHITE := Color(0.92, 0.88, 0.78)  # marfim
const COLOR_BLACK := Color(0.20, 0.18, 0.16)  # pedra escura
const SELECTED_EMISSION := Color(1.0, 0.85, 0.2)

var type: int = Type.PAWN
var is_white := true
var grid_pos := Vector2i.ZERO

var _material: StandardMaterial3D

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _particles: GPUParticles3D = $CaptureParticles


## Configura tipo, cor e célula lógica. Chamado logo após instanciar.
func setup(piece_type: int, white: bool, cell: Vector2i) -> void:
	type = piece_type
	is_white = white
	grid_pos = cell
	name = "%s_%s_%d_%d" % [Type.keys()[type], "W" if white else "B", cell.x, cell.y]

	# Placeholder visual: cápsula low-poly esticada conforme o tipo.
	var height_scale: float = TYPE_HEIGHT_SCALE[type]
	_mesh.scale = Vector3(0.9, height_scale, 0.9)
	_mesh.position = Vector3(0.0, 0.8 * height_scale, 0.0)

	_material = StandardMaterial3D.new()
	_material.albedo_color = COLOR_WHITE if white else COLOR_BLACK
	_material.emission = SELECTED_EMISSION
	_material.emission_enabled = false
	_mesh.material_override = _material


## Realce visual da peça selecionada (emissão dourada).
func set_selected(selected: bool) -> void:
	if _material:
		_material.emission_enabled = selected


# ---------------------------------------------------------------------------
# MOVIMENTO — deslize com pulo em arco (Tween)
# ---------------------------------------------------------------------------

## Move a peça até `target` (posição global do centro da casa) com um arco.
## Emite `move_finished` ao terminar.
func move_to(target: Vector3) -> void:
	var start := global_position
	var tween := create_tween()
	# Interpolamos um parâmetro t de 0 a 1 e calculamos a posição manualmente,
	# para poder somar a parábola do pulo à interpolação linear.
	tween.tween_method(_move_step.bind(start, target), 0.0, 1.0, MOVE_DURATION)
	tween.tween_callback(func() -> void: move_finished.emit())


## Matemática do arco: posição = lerp(início, fim, t) + UP * y(t), onde
##     y(t) = 4 · h · t · (1 − t)
## é uma parábola com raízes em t=0 e t=1 (a peça decola e pousa no chão)
## e pico exatamente h (JUMP_HEIGHT) em t=0.5 — pois 4·h·0.5·0.5 = h.
func _move_step(t: float, start: Vector3, target: Vector3) -> void:
	global_position = start.lerp(target, t) + Vector3.UP * (4.0 * JUMP_HEIGHT * t * (1.0 - t))


# ---------------------------------------------------------------------------
# COMBATE — a diversão: física exagerada
# ---------------------------------------------------------------------------

## A peça (atacante) captura `target_piece`: delega o arremesso à vítima,
## passando a própria posição como origem do golpe.
func capture(target_piece: Piece) -> void:
	target_piece.launch_from(global_position)


## Ativa a física e arremessa ESTA peça para longe do ponto de ataque.
##
## Matemática do vetor de lançamento:
##  1. Direção horizontal do golpe = (posição da vítima − posição do atacante),
##     com y zerado e normalizada. É a direção "fugindo" do atacante — a vítima
##     voa no sentido do golpe, como uma bolinha atingida por um taco.
##  2. Somamos CAPTURE_UP_FACTOR no eixo Y para transformar o vetor numa rampa
##     (~29° para 0.55, pois tan(θ) = 0.55/1.0) e renormalizamos: a trajetória
##     resultante é uma parábola balística sob a gravidade.
##  3. Impulso = direção · CAPTURE_IMPULSE · massa. Como impulso J = m·Δv,
##     multiplicar pela massa garante Δv = CAPTURE_IMPULSE m/s independentemente
##     da massa do corpo. Com v ≈ 34 m/s, o alcance teórico R = v²·sen(2θ)/g
##     ≈ 34²·0.83/9.8 ≈ 98 m — MUITO além dos 16 m do tabuleiro. Exagero proposital.
##  4. Um torque aleatório faz a peça girar descontroladamente no ar (comédia).
func launch_from(attacker_position: Vector3) -> void:
	# (1) Direção horizontal do golpe.
	var flat_direction := global_position - attacker_position
	flat_direction.y = 0.0
	if flat_direction.length_squared() < 0.0001:
		# Atacante exatamente em cima da vítima: escolhe uma direção aleatória.
		flat_direction = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	flat_direction = flat_direction.normalized()

	# (2) Rampa de lançamento.
	var launch_direction := (flat_direction + Vector3.UP * CAPTURE_UP_FACTOR).normalized()

	# (3) Liga a física e aplica o impulso no centro de massa.
	freeze = false
	apply_central_impulse(launch_direction * CAPTURE_IMPULSE * mass)

	# (4) Giro cômico: torque impulsivo com eixo aleatório.
	apply_torque_impulse(Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	) * TORQUE_IMPULSE_MAX)

	# Efeito visual: explosão de poeira/faíscas no ponto do impacto.
	_particles.burst()

	_despawn_later()


## Remove a vítima da cena depois que ela já voou para bem longe.
func _despawn_later() -> void:
	await get_tree().create_timer(DESPAWN_DELAY).timeout
	queue_free()
