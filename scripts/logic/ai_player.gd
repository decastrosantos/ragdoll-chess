class_name AiPlayer
## IA adversária (LÓGICA pura) — controla as peças vermelhas.
##
## Estratégia "gananciosa" (greedy), suficiente para um protótipo divertido:
##  1. Lista todos os movimentos legais de todas as suas peças;
##  2. Prefere a captura de MAIOR VALOR disponível (dama > torre > ...);
##  3. Sem capturas, joga um movimento qualquer (ruído aleatório desempata,
##     evitando que a IA repita sempre o mesmo lance).
## Evolução futura: minimax com poda alfa-beta sobre esta mesma interface.

const PIECE_VALUE := {
	Piece.Type.PAWN: 1.0,
	Piece.Type.KNIGHT: 3.0,
	Piece.Type.BISHOP: 3.0,
	Piece.Type.ROOK: 5.0,
	Piece.Type.QUEEN: 9.0,
	Piece.Type.KING: 1000.0,  # capturar o rei = vencer
}


## Escolhe o melhor lance. Retorna {"piece": Piece, "cell": Vector2i},
## ou {} se não houver nenhum movimento legal.
static func choose_move(board: Board, my_pieces: Array) -> Dictionary:
	var best_score := -1.0
	var best: Dictionary = {}
	for piece in my_pieces:
		for cell in MoveRules.get_legal_moves(piece, board):
			# Ruído em [0, 0.1): desempata lances equivalentes ao acaso.
			var score := randf() * 0.1
			var occupant: Piece = board.get_piece_at(cell)
			if occupant != null:
				score += PIECE_VALUE[occupant.type]
			if score > best_score:
				best_score = score
				best = {"piece": piece, "cell": cell}
	return best
