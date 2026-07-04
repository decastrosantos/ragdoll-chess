extends Node3D
## Controlador principal (nó raiz da cena Main).
##
## Orquestra: input do jogador (raycast de clique), validação de destinos via
## MoveRules (movimentos legais por tipo de peça), atualização da matriz do
## tabuleiro, máquina de estados e câmera.

const PIECE_SCENE := preload("res://scenes/pieces/piece_base.tscn")
const RAY_LENGTH := 200.0

# Fileira de trás no arranjo clássico: T C B D R B C T
const BACK_RANK: Array = [
	Piece.Type.ROOK, Piece.Type.KNIGHT, Piece.Type.BISHOP, Piece.Type.QUEEN,
	Piece.Type.KING, Piece.Type.BISHOP, Piece.Type.KNIGHT, Piece.Type.ROOK,
]

# Pausa dramática após o arremesso, antes da câmera voltar (segundos).
const COMBAT_LINGER := 1.2

# "Tempo de pensar" da IA antes de jogar (segundos) — puro teatro.
const AI_THINK_DELAY := 0.9

@onready var board: Board = $Board
@onready var state_machine: GameStateMachine = $GameStateMachine
@onready var battle_camera: BattleCamera = $BattleCamera
@onready var pieces_root: Node3D = $Pieces
@onready var ui: MainMenu = $UI/MainMenu

var selected_piece: Piece = null

# Destinos legais da peça selecionada (Array de Vector2i), calculados pelo
# MoveRules no momento da seleção. Vazio quando nada está selecionado.
var _legal_moves: Array = []


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
	_legal_moves = []
	board.clear_highlights()
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
		# O humano só joga com as brancas; o turno das vermelhas é da IA.
		if state_machine.current == GameStateMachine.State.WHITE_TURN:
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
	elif selected_piece and piece.grid_pos in _legal_moves:
		# Peça inimiga em casa alcançável: CAPTURA!
		_execute_move(selected_piece, piece.grid_pos)


func _on_cell_clicked(cell: Vector2i) -> void:
	if selected_piece == null:
		return
	if cell in _legal_moves:
		_execute_move(selected_piece, cell)
	else:
		# Clique fora dos destinos legais (inclui a própria casa): deseleciona.
		_select(null)


## Seleciona/deseleciona uma peça. Ao selecionar, consulta o MoveRules e
## acende os marcadores das casas legais no tabuleiro.
func _select(piece: Piece) -> void:
	if selected_piece:
		selected_piece.set_selected(false)
	selected_piece = piece
	_legal_moves = []
	board.clear_highlights()
	if piece:
		piece.set_selected(true)
		_legal_moves = MoveRules.get_legal_moves(piece, board)
		board.show_highlights(_legal_moves)


# ---------------------------------------------------------------------------
# EXECUÇÃO DO MOVIMENTO / COMBATE
# ---------------------------------------------------------------------------

## Executa um lance (humano ou IA). `attacker` deve ter `cell` entre seus
## movimentos legais — o chamador é responsável pela validação.
func _execute_move(attacker: Piece, cell: Vector2i) -> void:
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
		_maybe_promote(attacker)
		state_machine.end_action()


## Promoção: peão que alcança a última fileira (row 0 para brancas,
## row 7 para pretas) vira dama automaticamente.
func _maybe_promote(piece: Piece) -> void:
	if piece.type != Piece.Type.PAWN:
		return
	var last_row := 0 if piece.is_white else 7
	if piece.grid_pos.y == last_row:
		piece.promote_to(Piece.Type.QUEEN)


## Sequência cinematográfica da captura (DUELO):
## zoom da câmera -> atacante para na beira da casa -> investidas de esgrima
## enquanto o defensor cambaleia -> golpe final arremessa a vítima (física) ->
## atacante ocupa a casa -> câmera volta -> próximo turno (ou fim de jogo).
func _play_combat(attacker: Piece, target: Piece, cell: Vector2i) -> void:
	var arena := board.grid_to_world(cell)
	battle_camera.focus_on(arena)

	# Aproxima até a BEIRA da casa (0.95 antes do centro) para o duelo
	# acontecer cara a cara, sem sobrepor as peças.
	var approach_dir: Vector3 = arena - attacker.global_position
	approach_dir.y = 0.0
	approach_dir = approach_dir.normalized()
	attacker.move_to(arena - approach_dir * 0.95)
	await attacker.move_finished

	# O duelo: golpes do atacante, cambaleio do defensor.
	target.flinch()
	await attacker.attack_flourish(arena)

	var was_king := target.type == Piece.Type.KING
	attacker.capture(target)
	ui.set_status("MSG_PIECE_CAPTURED")

	await get_tree().create_timer(COMBAT_LINGER).timeout

	# Ocupa a casa conquistada.
	attacker.move_to(arena)
	await attacker.move_finished
	_maybe_promote(attacker)
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
			_play_ai_turn()
		GameStateMachine.State.GAME_OVER:
			ui.show_game_over()


# ---------------------------------------------------------------------------
# TURNO DA IA (peças vermelhas)
# ---------------------------------------------------------------------------

func _play_ai_turn() -> void:
	await get_tree().create_timer(AI_THINK_DELAY).timeout
	# O estado pode ter mudado durante a espera (ex.: novo jogo).
	if state_machine.current != GameStateMachine.State.BLACK_TURN:
		return
	var my_pieces: Array = []
	for child in pieces_root.get_children():
		var piece := child as Piece
		# Só peças vivas: registradas na matriz (capturadas já saíram dela).
		if piece and not piece.is_white and board.is_inside(piece.grid_pos) \
				and board.get_piece_at(piece.grid_pos) == piece:
			my_pieces.append(piece)
	var move: Dictionary = AiPlayer.choose_move(board, my_pieces)
	if move.is_empty():
		# IA sem movimentos legais: encerra a partida.
		state_machine.game_over()
		return
	_execute_move(move["piece"], move["cell"])
