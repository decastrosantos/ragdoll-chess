class_name AiPlayer
## IA adversária (LÓGICA pura) — controla as peças vermelhas.
##
## Quatro níveis de dificuldade:
##  EASY       -> lance aleatório (nem olha capturas);
##  MEDIUM     -> "ganancioso": pega a captura de maior valor disponível;
##  HARD       -> ganancioso + prudente: evita casas onde seria capturado;
##  SUPER_HARD -> minimax de 2 níveis: avalia o ganho do lance MENOS a
##                melhor resposta possível das brancas (troca de material).
##
## A simulação usa apenas a matriz do Board (set/get_piece_at), aplicando o
## lance, medindo e desfazendo — nenhum nó 3D é tocado.

enum Difficulty { EASY, MEDIUM, HARD, SUPER_HARD }

const PIECE_VALUE := {
	Piece.Type.PAWN: 1.0,
	Piece.Type.KNIGHT: 3.0,
	Piece.Type.BISHOP: 3.0,
	Piece.Type.ROOK: 5.0,
	Piece.Type.QUEEN: 9.0,
	Piece.Type.KING: 1000.0,  # capturar o rei = vencer
}


## Escolhe o lance conforme a dificuldade. Retorna {"piece": Piece,
## "cell": Vector2i}, ou {} se não houver nenhum movimento legal.
static func choose_move(board: Board, my_pieces: Array, difficulty: int) -> Dictionary:
	match difficulty:
		Difficulty.EASY:
			return _choose_random(board, my_pieces)
		Difficulty.HARD:
			return _choose_greedy(board, my_pieces, true)
		Difficulty.SUPER_HARD:
			return _choose_minimax(board, my_pieces)
	return _choose_greedy(board, my_pieces, false)  # MEDIUM (padrão)


# ---------------------------------------------------------------------------
# NÍVEIS
# ---------------------------------------------------------------------------

static func _choose_random(board: Board, my_pieces: Array) -> Dictionary:
	var options: Array = []
	for piece in my_pieces:
		for cell in MoveRules.get_legal_moves(piece, board):
			options.append({"piece": piece, "cell": cell})
	if options.is_empty():
		return {}
	return options[randi() % options.size()]


## Ganancioso; com `safe`, simula o lance e desconta 90% do próprio valor
## se as brancas puderem capturar a peça na casa de destino (prudência).
static func _choose_greedy(board: Board, my_pieces: Array, safe: bool) -> Dictionary:
	var best_score := -INF
	var best: Dictionary = {}
	for piece in my_pieces:
		var from: Vector2i = piece.grid_pos
		for cell in MoveRules.get_legal_moves(piece, board):
			var occupant: Piece = board.get_piece_at(cell)
			var score := randf() * 0.1  # ruído desempata lances equivalentes
			if occupant != null:
				score += PIECE_VALUE[occupant.type]
			if safe:
				board.set_piece_at(from, null)
				board.set_piece_at(cell, piece)
				if _can_white_capture_at(board, cell):
					score -= PIECE_VALUE[piece.type] * 0.9
				board.set_piece_at(cell, occupant)
				board.set_piece_at(from, piece)
			if score > best_score:
				best_score = score
				best = {"piece": piece, "cell": cell}
	return best


## Minimax raso (2 níveis): score = ganho imediato − 0.9 × melhor captura
## que as brancas conseguem em resposta (em qualquer lugar do tabuleiro).
static func _choose_minimax(board: Board, my_pieces: Array) -> Dictionary:
	var best_score := -INF
	var best: Dictionary = {}
	for piece in my_pieces:
		var from: Vector2i = piece.grid_pos
		for cell in MoveRules.get_legal_moves(piece, board):
			var captured: Piece = board.get_piece_at(cell)
			var gain: float = PIECE_VALUE[captured.type] if captured != null else 0.0
			board.set_piece_at(from, null)
			board.set_piece_at(cell, piece)
			var reply := _best_white_capture(board)
			board.set_piece_at(cell, captured)
			board.set_piece_at(from, piece)
			var score := gain - reply * 0.9 + randf() * 0.05
			if score > best_score:
				best_score = score
				best = {"piece": piece, "cell": cell}
	return best


# ---------------------------------------------------------------------------
# HELPERS DE SIMULAÇÃO
# ---------------------------------------------------------------------------

static func _white_pieces(board: Board) -> Array:
	var result: Array = []
	for row in Board.BOARD_SIZE:
		for col in Board.BOARD_SIZE:
			var piece: Piece = board.get_piece_at(Vector2i(col, row))
			if piece != null and piece.is_white:
				result.append(piece)
	return result


## Alguma peça branca alcança `cell` no estado atual da matriz?
static func _can_white_capture_at(board: Board, cell: Vector2i) -> bool:
	for white_piece in _white_pieces(board):
		if cell in MoveRules.get_legal_moves(white_piece, board):
			return true
	return false


## Valor da melhor captura disponível para as brancas na matriz atual.
static func _best_white_capture(board: Board) -> float:
	var best := 0.0
	for white_piece in _white_pieces(board):
		for cell in MoveRules.get_legal_moves(white_piece, board):
			var occupant: Piece = board.get_piece_at(cell)
			if occupant != null and not occupant.is_white:
				best = maxf(best, PIECE_VALUE[occupant.type])
	return best
