class_name Board
extends Node3D
## Gerenciador do Tabuleiro (LÓGICA)
##
## Responsabilidades:
##  1. Manter a matriz 8x8 que é a FONTE DA VERDADE do estado lógico do jogo.
##  2. Converter coordenadas de matriz [col, row] <-> posições globais 3D (Vector3).
##  3. Gerar proceduralmente as casas visuais e a superfície de colisão p/ cliques.
##
## Convenção de coordenadas:
##  - Uma célula é um Vector2i(col, row): col cresce no eixo +X, row cresce no eixo +Z.
##  - row 0..1 = peças pretas (fundo da cena), row 6..7 = brancas (perto da câmera).

const BOARD_SIZE := 8
const CELL_SIZE := 2.0          # Largura de cada casa em metros (unidades 3D)
const TILE_THICKNESS := 0.5     # Espessura do tampo do tabuleiro

const COLOR_LIGHT := Color(0.85, 0.78, 0.66)  # "madeira clara"
const COLOR_DARK := Color(0.36, 0.26, 0.20)   # "madeira escura"

# Matriz 8x8 de referências a Piece (ou null). Indexada como _grid[row][col].
var _grid: Array = []


func _ready() -> void:
	reset()
	_build_visual_tiles()
	_build_click_surface()


## Zera a matriz lógica (não remove nós de peças — isso é papel do controlador).
func reset() -> void:
	_grid = []
	for row in BOARD_SIZE:
		var line := []
		line.resize(BOARD_SIZE)  # preenchido com null
		_grid.append(line)


# ---------------------------------------------------------------------------
# CONVERSÃO DE COORDENADAS — a matemática central do grid
# ---------------------------------------------------------------------------

## Converte uma célula da matriz em posição global 3D (centro da casa, no topo
## do tabuleiro, y = 0).
##
## Matemática: o tabuleiro é CENTRALIZADO na origem do mundo. A largura total é
## BOARD_SIZE * CELL_SIZE = 16. Logo, a borda esquerda fica em x = -8 ("half").
## O centro da casa `col` fica em:
##     x = col * CELL_SIZE - half + CELL_SIZE/2
## Ex.: col 0 -> 0*2 - 8 + 1 = -7  (centro da primeira casa)
##      col 7 -> 7*2 - 8 + 1 = +7  (centro da última casa)
## O mesmo vale para `row` no eixo Z.
func grid_to_world(cell: Vector2i) -> Vector3:
	var half := BOARD_SIZE * CELL_SIZE * 0.5
	return Vector3(
		cell.x * CELL_SIZE - half + CELL_SIZE * 0.5,
		0.0,
		cell.y * CELL_SIZE - half + CELL_SIZE * 0.5
	)


## Operação inversa: dado um ponto 3D qualquer (ex.: onde o raycast do clique
## atingiu o tabuleiro), retorna a célula correspondente.
##
## Matemática: desloca o ponto para o espaço "canto do tabuleiro na origem"
## somando `half`, e divide pelo tamanho da casa. floor() garante que qualquer
## ponto DENTRO da casa mapeie para o mesmo índice inteiro.
## O resultado pode estar fora de [0,7] — valide com is_inside().
func world_to_grid(world_pos: Vector3) -> Vector2i:
	var half := BOARD_SIZE * CELL_SIZE * 0.5
	return Vector2i(
		int(floor((world_pos.x + half) / CELL_SIZE)),
		int(floor((world_pos.z + half) / CELL_SIZE))
	)


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < BOARD_SIZE and cell.y >= 0 and cell.y < BOARD_SIZE


# ---------------------------------------------------------------------------
# ESTADO LÓGICO (matriz de peças)
# ---------------------------------------------------------------------------

func get_piece_at(cell: Vector2i) -> Piece:
	return _grid[cell.y][cell.x]


func set_piece_at(cell: Vector2i, piece: Piece) -> void:
	_grid[cell.y][cell.x] = piece


# ---------------------------------------------------------------------------
# GERAÇÃO PROCEDURAL DO VISUAL (placeholders low-poly)
# ---------------------------------------------------------------------------

## Cria as 64 casas como MeshInstance3D alternando dois materiais.
## O padrão de damas segue a paridade: (col + row) % 2.
func _build_visual_tiles() -> void:
	var light_mesh := _make_tile_mesh(COLOR_LIGHT)
	var dark_mesh := _make_tile_mesh(COLOR_DARK)
	for row in BOARD_SIZE:
		for col in BOARD_SIZE:
			var tile := MeshInstance3D.new()
			tile.mesh = light_mesh if (col + row) % 2 == 0 else dark_mesh
			# O centro da casa fica meio TILE abaixo de y=0 para o TOPO do
			# tampo coincidir exatamente com o plano y=0 onde as peças pousam.
			tile.position = grid_to_world(Vector2i(col, row)) + Vector3(0.0, -TILE_THICKNESS * 0.5, 0.0)
			add_child(tile)


func _make_tile_mesh(color: Color) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CELL_SIZE, TILE_THICKNESS, CELL_SIZE)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	return mesh


## Um único StaticBody3D cobrindo o tabuleiro inteiro serve para:
##  1. Receber o raycast dos cliques (destino do movimento).
##  2. Servir de chão físico para as peças arremessadas quicarem.
func _build_click_surface() -> void:
	var body := StaticBody3D.new()
	body.name = "BoardSurface"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BOARD_SIZE * CELL_SIZE, TILE_THICKNESS, BOARD_SIZE * CELL_SIZE)
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.position = Vector3(0.0, -TILE_THICKNESS * 0.5, 0.0)
