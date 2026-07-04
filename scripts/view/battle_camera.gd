class_name BattleCamera
extends Camera3D
## Câmera isométrica em perspectiva com zoom dinâmico de combate.
##
## Dois "enquadramentos":
##  - Visão geral: alta e atrás do tabuleiro, olhando para o centro.
##  - Foco de combate: mergulha até perto da casa onde a captura acontece.
## As transições interpolam posição E ponto de mira simultaneamente (Tween).

# Ângulo mais baixo e próximo (estilo Chess Ultra): valoriza as silhuetas
# das peças sem esconder as fileiras do fundo.
const OVERVIEW_POSITION := Vector3(0.0, 10.5, 11.0)
const OVERVIEW_TARGET := Vector3.ZERO                # centro do tabuleiro
const FOCUS_OFFSET := Vector3(0.0, 4.5, 5.0)         # deslocamento relativo à casa focada
const ZOOM_DURATION := 0.6

var _look_target := OVERVIEW_TARGET
var _tween: Tween


func _ready() -> void:
	look_at_from_position(OVERVIEW_POSITION, OVERVIEW_TARGET)


## Zoom de combate: voa até perto do ponto da captura.
func focus_on(world_point: Vector3) -> void:
	_fly_to(world_point + FOCUS_OFFSET, world_point)


## Retorna suavemente ao enquadramento padrão.
func return_to_overview() -> void:
	_fly_to(OVERVIEW_POSITION, OVERVIEW_TARGET)


func _fly_to(target_position: Vector3, target_look: Vector3) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()  # cancela voo anterior para evitar disputas de Tween
	var start_position := global_position
	var start_look := _look_target
	_look_target = target_look
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(
		_fly_step.bind(start_position, target_position, start_look, target_look),
		0.0, 1.0, ZOOM_DURATION
	)


## Interpola posição e ponto de mira em paralelo. Interpolar o ALVO do olhar
## (em vez da rotação) evita gimbal e mantém o tabuleiro sempre em quadro.
func _fly_step(t: float, start_pos: Vector3, end_pos: Vector3, start_look: Vector3, end_look: Vector3) -> void:
	global_position = start_pos.lerp(end_pos, t)
	look_at(start_look.lerp(end_look, t))
