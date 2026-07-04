class_name PieceFactory
## Fábrica dos visuais das peças (VISUALIZAÇÃO).
##
## Constrói cada tipo de peça com primitivas 3D em proporções "chunky" de
## cartoon (inspiração: Clash of Clans) — bases largas, corpos rechonchudos,
## coroas e detalhes dourados. Cada tipo tem silhueta inconfundível:
##   PEÃO   -> bolinha com cabeça
##   TORRE  -> tower com ameias (merlões)
##   CAVALO -> torso + cabeça de cavalo inclinada com orelhas
##   BISPO  -> mitra cônica alta com ponta dourada
##   RAINHA -> vestido cônico + coroa de 5 pontas
##   REI    -> o mais alto, coroa larga + cruz no topo
##
## São placeholders 100% procedurais: quando houver modelos de artista
## (GLB/GLTF), basta trocar o retorno de build() pela cena importada —
## nada mais no jogo precisa mudar.

## Monta e retorna o nó visual da peça. `team` é o material do time
## (a emissão de seleção vive nele); `accent` é o material dos detalhes.
static func build(type: int, team: Material, accent: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	match type:
		Piece.Type.PAWN:
			_build_pawn(root, team, accent)
		Piece.Type.ROOK:
			_build_rook(root, team, accent)
		Piece.Type.KNIGHT:
			_build_knight(root, team, accent)
		Piece.Type.BISHOP:
			_build_bishop(root, team, accent)
		Piece.Type.QUEEN:
			_build_queen(root, team, accent)
		Piece.Type.KING:
			_build_king(root, team, accent)
	return root


# ---------------------------------------------------------------------------
# UM CONSTRUTOR POR TIPO (alturas: peão ~1.4 ... rei ~2.35; casa tem 2.0)
# ---------------------------------------------------------------------------

static func _build_pawn(root: Node3D, team: Material, accent: Material) -> void:
	_part(root, _cylinder(0.6, 0.5, 0.25), team, Vector3(0, 0.125, 0))
	_part(root, _sphere(0.45), team, Vector3(0, 0.62, 0))          # corpo gorducho
	_part(root, _sphere(0.27), team, Vector3(0, 1.12, 0))          # cabeça
	_part(root, _sphere(0.09), accent, Vector3(0, 1.4, 0))         # topete dourado


static func _build_rook(root: Node3D, team: Material, accent: Material) -> void:
	_part(root, _cylinder(0.65, 0.55, 0.25), team, Vector3(0, 0.125, 0))
	_part(root, _cylinder(0.5, 0.45, 1.0), team, Vector3(0, 0.75, 0))    # torre
	_part(root, _cylinder(0.55, 0.55, 0.14), accent, Vector3(0, 1.32, 0))  # anel do topo
	# Quatro merlões (ameias) nos pontos cardeais da muralha.
	for offset in [Vector3(0.38, 0, 0), Vector3(-0.38, 0, 0), Vector3(0, 0, 0.38), Vector3(0, 0, -0.38)]:
		_part(root, _box(Vector3(0.22, 0.24, 0.22)), team, offset + Vector3(0, 1.5, 0))


static func _build_knight(root: Node3D, team: Material, accent: Material) -> void:
	_part(root, _cylinder(0.62, 0.52, 0.25), team, Vector3(0, 0.125, 0))
	_part(root, _cylinder(0.45, 0.28, 0.9), team, Vector3(0, 0.7, 0))    # torso
	# Cabeça de cavalo: bloco alongado inclinado para a frente (+Z),
	# como se farejasse o inimigo. O focinho aponta para onde a peça "olha".
	_part(root, _box(Vector3(0.34, 0.42, 0.68)), team, Vector3(0, 1.32, 0.16), Vector3(-0.35, 0, 0))
	# Orelhas em cone dourado.
	_part(root, _cylinder(0.09, 0.0, 0.22), accent, Vector3(0.12, 1.62, -0.02))
	_part(root, _cylinder(0.09, 0.0, 0.22), accent, Vector3(-0.12, 1.62, -0.02))


static func _build_bishop(root: Node3D, team: Material, accent: Material) -> void:
	_part(root, _cylinder(0.6, 0.5, 0.25), team, Vector3(0, 0.125, 0))
	_part(root, _cylinder(0.46, 0.14, 1.3), team, Vector3(0, 0.9, 0))    # mitra cônica
	_part(root, _sphere(0.18), team, Vector3(0, 1.6, 0))                 # colarinho
	_part(root, _sphere(0.11), accent, Vector3(0, 1.78, 0))              # ponta dourada


static func _build_queen(root: Node3D, team: Material, accent: Material) -> void:
	_part(root, _cylinder(0.62, 0.52, 0.25), team, Vector3(0, 0.125, 0))
	_part(root, _cylinder(0.5, 0.26, 1.35), team, Vector3(0, 0.925, 0))  # vestido
	_part(root, _cylinder(0.34, 0.38, 0.18), accent, Vector3(0, 1.68, 0))  # coroa
	# Cinco pontas da coroa distribuídas uniformemente no círculo (TAU/5).
	for i in 5:
		var angle := TAU * i / 5.0
		_part(root, _cylinder(0.07, 0.0, 0.22), accent,
			Vector3(cos(angle) * 0.27, 1.86, sin(angle) * 0.27))


static func _build_king(root: Node3D, team: Material, accent: Material) -> void:
	_part(root, _cylinder(0.66, 0.56, 0.25), team, Vector3(0, 0.125, 0))
	_part(root, _cylinder(0.55, 0.3, 1.5), team, Vector3(0, 1.0, 0))     # manto (o mais alto)
	_part(root, _cylinder(0.36, 0.42, 0.2), accent, Vector3(0, 1.85, 0))   # coroa larga
	# Cruz no topo: uma barra vertical + uma horizontal.
	_part(root, _box(Vector3(0.09, 0.44, 0.09)), accent, Vector3(0, 2.22, 0))
	_part(root, _box(Vector3(0.3, 0.09, 0.09)), accent, Vector3(0, 2.26, 0))


# ---------------------------------------------------------------------------
# HELPERS DE GEOMETRIA
# ---------------------------------------------------------------------------

static func _part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = pos
	part.rotation = rot
	parent.add_child(part)
	return part


static func _cylinder(bottom: float, top: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	return mesh


static func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh
