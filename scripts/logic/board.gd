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

# Paleta clássica (referência: Chess Ultra): casas brancas e quase-pretas.
const COLOR_LIGHT := Color(0.91, 0.89, 0.85)  # branco marfim
const COLOR_DARK := Color(0.11, 0.11, 0.12)   # preto grafite
const COLOR_FRAME := Color(0.13, 0.1, 0.08)   # moldura em madeira escura

# Destaques de movimento: verde = casa livre, vermelho = captura possível.
const COLOR_MOVE_HIGHLIGHT := Color(0.35, 0.85, 0.4, 0.55)
const COLOR_CAPTURE_HIGHLIGHT := Color(0.9, 0.25, 0.2, 0.6)

# Matriz 8x8 de referências a Piece (ou null). Indexada como _grid[row][col].
var _grid: Array = []

# Marcadores visuais de destino legal atualmente exibidos.
var _highlights: Array = []
var _highlight_mesh: PlaneMesh
var _highlight_move_material: StandardMaterial3D
var _highlight_capture_material: StandardMaterial3D


func _ready() -> void:
	reset()
	_build_visual_tiles()
	_build_frame()
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
	material.roughness = 0.35  # tampo polido/envernizado
	mesh.material = material
	return mesh


## Moldura escura ao redor do tampo, como um tabuleiro de madeira real.
## Levemente mais baixa que as casas para criar um degrau de borda.
func _build_frame() -> void:
	var frame := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(BOARD_SIZE * CELL_SIZE + 1.6, 0.5, BOARD_SIZE * CELL_SIZE + 1.6)
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR_FRAME
	material.roughness = 0.4
	mesh.material = material
	frame.mesh = mesh
	frame.position = Vector3(0.0, -0.3, 0.0)
	add_child(frame)


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


# ---------------------------------------------------------------------------
# DESTAQUES DE MOVIMENTO LEGAL (marcadores translúcidos sobre as casas)
# ---------------------------------------------------------------------------

## Exibe um marcador em cada célula de `cells` (Array de Vector2i).
## Casa ocupada por inimigo ganha a cor de captura; casa vazia, a de movimento.
func show_highlights(cells: Array) -> void:
	clear_highlights()
	for cell in cells:
		var marker := MeshInstance3D.new()
		marker.mesh = _get_highlight_mesh()
		marker.material_override = (
			_get_capture_material() if get_piece_at(cell) != null
			else _get_move_material()
		)
		# Levemente acima do tampo (y = 0.03) para não "brigar" com a casa
		# (z-fighting) e ainda ficar sob os pés das peças.
		marker.position = grid_to_world(cell) + Vector3(0.0, 0.03, 0.0)
		add_child(marker)
		_highlights.append(marker)


func clear_highlights() -> void:
	for marker in _highlights:
		marker.queue_free()
	_highlights = []


func _get_highlight_mesh() -> PlaneMesh:
	if _highlight_mesh == null:
		_highlight_mesh = PlaneMesh.new()
		# Um pouco menor que a casa para o marcador ler como "alvo", não "piso".
		_highlight_mesh.size = Vector2(CELL_SIZE * 0.82, CELL_SIZE * 0.82)
	return _highlight_mesh


func _get_move_material() -> StandardMaterial3D:
	if _highlight_move_material == null:
		_highlight_move_material = _make_highlight_material(COLOR_MOVE_HIGHLIGHT)
	return _highlight_move_material


func _get_capture_material() -> StandardMaterial3D:
	if _highlight_capture_material == null:
		_highlight_capture_material = _make_highlight_material(COLOR_CAPTURE_HIGHLIGHT)
	return _highlight_capture_material


func _make_highlight_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
