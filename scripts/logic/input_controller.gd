extends Node3D
## Controlador principal (nó raiz da cena Main).
##
## Orquestra: input do jogador (raycast de clique), regras mínimas do protótipo
## (qualquer peça move para qualquer casa — as regras reais do xadrez virão
## depois), atualização da matriz do tabuleiro, máquina de estados e câmera.

const PIECE_SCENE := preload("res://scenes/pieces/piece_base.tscn")
const RAY_LENGTH := 200.0

# Fileira de trás no arranjo clássico: T C B D R B C T
const BACK_RANK: Array = [
	Piece.Type.ROOK, Piece.Type.KNIGHT, Piece.Type.BISHOP, Piece.Type.QUEEN,
	Piece.Type.KING, Piece.Type.BISHOP, Piece.Type.KNIGHT, Piece.Type.ROOK,
]

# Pausa dramática após o arremesso, antes da câmera voltar (segundos).
const COMBAT_LINGER := 1.4

@onready var board: Board = $Board
@onready var state_machine: GameStateMachine = $GameStateMachine
@onready var battle_camera: BattleCamera = $BattleCamera
@onready var pieces_root: Node3D = $Pieces
@onready var ui: MainMenu = $UI/MainMenu

var selected_piece: Piece = null


func _ready() -> void:
	ui.new_game_pressed.connect(_on_new_game)
	state_machine.state_changed.connect(_on_state_changed)


# ---------------------------------------------------------------------------
# CICLO DE PARTIDA
# ---------------------------------------------------------------------------

func _on_new_game() -> void:
	_clear_pieces()
	_spawn_initial_pieces()
	state_machine.reset()


func _clear_pieces() -> void:
	selected_piece = null
	for child in pieces_root.get_children():
		child.queue_free()
	board.reset()


func _spawn_initial_pieces() -> void:
	for col in Board.BOARD_SIZE:
		_spawn_piece(BACK_RANK[col], false, Vector2i(col, 0))       # pretas: fileira de trás
		_spawn_piece(Piece.Type.PAWN, false, Vector2i(col, 1))      # pretas: peões
		_spawn_piece(Piece.Type.PAWN, true, Vector2i(col, 6))       # brancas: peões
		_spawn_piece(BACK_RANK[col], true, Vector2i(col, 7))        # brancas: fileira de trás


func _spawn_piece(type: int, is_white: bool, cell: Vector2i) -> void:
	var piece := PIECE_SCENE.instantiate() as Piece
	pieces_root.add_child(piece)
	piece.setup(type, is_white, cell)
	piece.global_position = board.grid_to_world(cell)
	board.set_piece_at(cell, piece)


# ---------------------------------------------------------------------------
# INPUT — seleção e destino via raycast
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# _unhandled_input só recebe o clique se a UI (menu) não o consumiu antes.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if state_machine.is_turn_state():
			_handle_click(event.position)


func _handle_click(screen_position: Vector2) -> void:
	# Converte o pixel clicado num raio 3D partindo da câmera.
	var origin := battle_camera.project_ray_origin(screen_position)
	var direction := battle_camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * RAY_LENGTH)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var collider: Object = hit["collider"]
	# É uma peça viva (ainda registrada na matriz)? Peças arremessadas já
	# saíram da matriz e são ignoradas.
	if collider is Piece and board.is_inside(collider.grid_pos) \
			and board.get_piece_at(collider.grid_pos) == collider:
		_on_piece_clicked(collider)
	else:
		var cell := board.world_to_grid(hit["position"])
		if board.is_inside(cell):
			_on_cell_clicked(cell)


func _on_piece_clicked(piece: Piece) -> void:
	if piece.is_white == state_machine.is_white_turn():
		# Peça do jogador da vez: seleciona (ou troca a seleção).
		_select(null if piece == selected_piece else piece)
	elif selected_piece:
		# Peça inimiga com uma peça já selecionada: CAPTURA!
		_execute_move(piece.grid_pos)


func _on_cell_clicked(cell: Vector2i) -> void:
	if selected_piece == null:
		return
	if cell == selected_piece.grid_pos:
		_select(null)
		return
	_execute_move(cell)


func _select(piece: Piece) -> void:
	if selected_piece:
		selected_piece.set_selected(false)
	selected_piece = piece
	if piece:
		piece.set_selected(true)


# ---------------------------------------------------------------------------
# EXECUÇÃO DO MOVIMENTO / COMBATE
# ---------------------------------------------------------------------------

func _execute_move(cell: Vector2i) -> void:
	var attacker := selected_piece
	_select(null)

	var target: Piece = board.get_piece_at(cell)

	# Atualiza a FONTE DA VERDADE (matriz) imediatamente; o visual alcança depois.
	board.set_piece_at(attacker.grid_pos, null)
	board.set_piece_at(cell, attacker)
	attacker.grid_pos = cell

	# A state machine bloqueia novos inputs até end_action()/game_over().
	state_machine.begin_action(target != null)

	if target:
		await _play_combat(attacker, target, cell)
	else:
		attacker.move_to(board.grid_to_world(cell))
		await attacker.move_finished
		state_machine.end_action()


## Sequência cinematográfica da captura:
## zoom da câmera -> atacante pula na casa -> vítima é arremessada (física) ->
## pausa dramática -> câmera volta -> próximo turno (ou fim de jogo).
func _play_combat(attacker: Piece, target: Piece, cell: Vector2i) -> void:
	var arena := board.grid_to_world(cell)
	battle_camera.focus_on(arena)

	attacker.move_to(arena)
	await attacker.move_finished

	var was_king := target.type == Piece.Type.KING
	attacker.capture(target)
	ui.set_status("MSG_PIECE_CAPTURED")

	await get_tree().create_timer(COMBAT_LINGER).timeout
	battle_camera.return_to_overview()

	if was_king:
		state_machine.game_over()
	else:
		state_machine.end_action()


# ---------------------------------------------------------------------------
# REAÇÃO A MUDANÇAS DE ESTADO (atualiza a UI — sempre via chaves de tradução)
# ---------------------------------------------------------------------------

func _on_state_changed(_previous: int, current: int) -> void:
	match current:
		GameStateMachine.State.WHITE_TURN:
			ui.set_status("MSG_WHITE_TURN")
		GameStateMachine.State.BLACK_TURN:
			ui.set_status("MSG_BLACK_TURN")
		GameStateMachine.State.GAME_OVER:
			ui.show_game_over()
