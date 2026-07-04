class_name GameStateMachine
extends Node
## Máquina de Estados do jogo (Padrão State Machine).
##
## Fluxo do turno:
##   WHITE_TURN --(jogador clica)--> ANIMATING_MOVE ou COMBAT --> BLACK_TURN --> ...
##
## Regras:
##  - Input do jogador SÓ é aceito nos estados de turno (WHITE_TURN / BLACK_TURN).
##  - ANIMATING_MOVE: uma peça está deslizando/pulando até a casa destino.
##  - COMBAT: uma captura está em andamento (câmera foca, física arremessa a vítima).
##  - GAME_OVER: um rei foi capturado; volta ao menu.

enum State {
	WHITE_TURN,
	BLACK_TURN,
	ANIMATING_MOVE,
	COMBAT,
	GAME_OVER,
}

signal state_changed(previous: int, current: int)

var current: int = State.WHITE_TURN

# Guarda qual turno assume o controle quando a animação/combate terminar.
var _turn_after_action: int = State.BLACK_TURN


## Recomeça a partida: brancas jogam primeiro.
func reset() -> void:
	_turn_after_action = State.BLACK_TURN
	transition_to(State.WHITE_TURN)


## Chamado pelo controlador no momento em que um movimento é confirmado.
## Congela o input (sai do estado de turno) e memoriza de quem é a vez seguinte.
func begin_action(is_combat: bool) -> void:
	if not is_turn_state():
		push_warning("begin_action() chamado fora de um estado de turno — ignorado.")
		return
	_turn_after_action = State.BLACK_TURN if current == State.WHITE_TURN else State.WHITE_TURN
	transition_to(State.COMBAT if is_combat else State.ANIMATING_MOVE)


## Chamado quando a animação/física terminou: passa a vez ao próximo jogador.
func end_action() -> void:
	transition_to(_turn_after_action)


func game_over() -> void:
	transition_to(State.GAME_OVER)


func is_turn_state() -> bool:
	return current == State.WHITE_TURN or current == State.BLACK_TURN


func is_white_turn() -> bool:
	return current == State.WHITE_TURN


func transition_to(new_state: int) -> void:
	var previous := current
	current = new_state
	state_changed.emit(previous, new_state)
