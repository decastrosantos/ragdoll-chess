class_name MoveRules
## Regras de movimento das peças (LÓGICA pura, sem nada visual).
##
## Gera os movimentos LEGAIS de cada tipo de peça respeitando bloqueios e
## capturas. Escopo deliberado do protótipo (estilo Battle Chess — o jogo
## termina com a captura física do rei, não com xeque-mate formal):
##  - SEM detecção de xeque (mover deixando o rei ameaçado é permitido);
##  - SEM roque e SEM en passant;
##  - COM promoção: o peão que alcança a última fileira vira dama
##    (aplicada pelo controlador via Piece.promote_to()).
##
## Convenção (a mesma do Board): célula = Vector2i(col, row);
## brancas começam nas rows 6-7 e avançam para row 0.

const ORTHOGONAL: Array = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]
const DIAGONAL: Array = [
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]
# Os 8 "saltos em L" do cavalo: (±1, ±2) e (±2, ±1).
const KNIGHT_OFFSETS: Array = [
	Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1),
	Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1),
]


## Retorna um Array de Vector2i com todos os destinos legais da peça.
static func get_legal_moves(piece: Piece, board: Board) -> Array:
	match piece.type:
		Piece.Type.PAWN:
			return _pawn_moves(piece, board)
		Piece.Type.ROOK:
			return _sliding_moves(piece, board, ORTHOGONAL)
		Piece.Type.BISHOP:
			return _sliding_moves(piece, board, DIAGONAL)
		Piece.Type.QUEEN:
			return _sliding_moves(piece, board, ORTHOGONAL + DIAGONAL)
		Piece.Type.KNIGHT:
			return _step_moves(piece, board, KNIGHT_OFFSETS)
		Piece.Type.KING:
			return _step_moves(piece, board, ORTHOGONAL + DIAGONAL)
	return []


## Peças DESLIZANTES (torre, bispo, dama): caminham casa a casa em cada
## direção até esbarrar em algo. Casa vazia -> pode ir e continua; peça
## inimiga -> pode capturar e PARA; peça aliada -> PARA sem incluir.
static func _sliding_moves(piece: Piece, board: Board, directions: Array) -> Array:
	var moves: Array = []
	for direction in directions:
		var cell: Vector2i = piece.grid_pos + direction
		while board.is_inside(cell):
			var occupant: Piece = board.get_piece_at(cell)
			if occupant == null:
				moves.append(cell)
			else:
				if occupant.is_white != piece.is_white:
					moves.append(cell)  # captura
				break  # qualquer peça bloqueia o caminho
			cell += direction
	return moves


## Peças de PASSO FIXO (cavalo, rei): testam cada offset uma única vez.
## O cavalo ignora bloqueios no caminho (ele "salta") — só importa o destino.
static func _step_moves(piece: Piece, board: Board, offsets: Array) -> Array:
	var moves: Array = []
	for offset in offsets:
		var cell: Vector2i = piece.grid_pos + offset
		if not board.is_inside(cell):
			continue
		var occupant: Piece = board.get_piece_at(cell)
		if occupant == null or occupant.is_white != piece.is_white:
			moves.append(cell)
	return moves


## PEÃO — a única peça assimétrica:
##  - Avança 1 casa SE estiver vazia (peão não captura para frente);
##  - Avança 2 casas no primeiro movimento (rows 6/1) se AMBAS estiverem vazias;
##  - Captura APENAS nas diagonais dianteiras.
## Direção de avanço: brancas row-- (dir = -1), pretas row++ (dir = +1).
static func _pawn_moves(piece: Piece, board: Board) -> Array:
	var moves: Array = []
	var dir := -1 if piece.is_white else 1
	var start_row := 6 if piece.is_white else 1

	# Avanço simples.
	var one_ahead: Vector2i = piece.grid_pos + Vector2i(0, dir)
	if board.is_inside(one_ahead) and board.get_piece_at(one_ahead) == null:
		moves.append(one_ahead)
		# Avanço duplo (só do ponto de partida, com o caminho todo livre).
		var two_ahead: Vector2i = piece.grid_pos + Vector2i(0, dir * 2)
		if piece.grid_pos.y == start_row and board.get_piece_at(two_ahead) == null:
			moves.append(two_ahead)

	# Capturas diagonais.
	for dx in [-1, 1]:
		var diagonal: Vector2i = piece.grid_pos + Vector2i(dx, dir)
		if not board.is_inside(diagonal):
			continue
		var occupant: Piece = board.get_piece_at(diagonal)
		if occupant != null and occupant.is_white != piece.is_white:
			moves.append(diagonal)

	return moves
