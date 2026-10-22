extends Node2D

## A ARENA VIVA: dois HOLOFOTES nos cantos da quadra que varrem o piso
## devagar o tempo todo (nem parada a arena fica morta) e acendem mais
## forte com o combo; no MODO ENTERRADA ficam azuis e rápidos, no recorde
## dourados. E os FLASHES DA TORCIDA: com muitas cestas seguidas, câmeras
## piscam nas laterais da quadra.
## Leve: 2 fachos + 8 estrelinhas, prontos na preparação (só aditivos).

enum { NORMAL, SLAM, RECORDE }

const CORES := [Color(1.0, 0.62, 0.22), Color(0.35, 0.78, 1.0), Color(1.0, 0.82, 0.25)]

var energia := 0.0 setget _set_energia
var _modo := NORMAL
var _alvo_energia := 0.0
var _fachos := []
var _flashes := []
var _flash_prox := 0
var _t := 0.0
var _r := RandomNumberGenerator.new()


func _ready() -> void:
	_r.randomize()
	# o facho é só o trapézio do cone (a ponta estreita no canto, a origem
	# do nó): a placa não pinta os cantos transparentes da textura
	var larg := 480.0
	var comp := 1150.0
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PoolVector2Array([Vector2(-0.06 * larg, 0), Vector2(0.06 * larg, 0),
		Vector2(0.5 * larg, comp), Vector2(-0.5 * larg, comp)])
	arr[Mesh.ARRAY_TEX_UV] = PoolVector2Array([Vector2(0.44, 0), Vector2(0.56, 0), Vector2(1, 1), Vector2(0, 1)])
	arr[Mesh.ARRAY_INDEX] = PoolIntArray([0, 1, 2, 0, 2, 3])
	var cone := ArrayMesh.new()
	cone.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	for lado in 2:
		var f := MeshInstance2D.new()
		f.mesh = cone
		f.texture = Arte.tex_feixe
		f.material = Arte.mat_aditivo
		f.position = Vector2(-30.0 if lado == 0 else 1110.0, 960.0)
		add_child(f)
		_fachos.append(f)
	for i in 8:
		var e := Arte.sprite_brilho(Color(1, 1, 1), 90.0, Arte.tex_estrela)
		e.visible = false
		add_child(e)
		_flashes.append(e)


func modo(m: int) -> void:
	_modo = m


func _set_energia(v: float) -> void:
	_alvo_energia = clamp(v, 0.0, 1.0)
	energia = max(energia, _alvo_energia)


## Câmeras da torcida piscando nas laterais.
func flashes(n: int) -> void:
	for i in n:
		var e: Sprite = _flashes[_flash_prox]
		_flash_prox = (_flash_prox + 1) % _flashes.size()
		var esquerda := _r.randf() < 0.5
		e.position = Vector2(_r.randf_range(40, 190) if esquerda else _r.randf_range(890, 1040), _r.randf_range(1010, 1640))
		e.visible = true
		e.set_meta("t", -i * 0.06 - _r.randf_range(0.0, 0.12))
		e.modulate.a = 0.0


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	# a energia cai devagar até o repouso
	_alvo_energia = move_toward(_alvo_energia, 0.0, delta * 0.18)
	energia = move_toward(energia, _alvo_energia, delta * 0.6)
	var rapido := 2.6 if _modo == SLAM else 1.0
	var cor: Color = CORES[_modo]
	for lado in 2:
		var f: MeshInstance2D = _fachos[lado]
		var sinal := 1.0 if lado == 0 else -1.0
		# aponta para dentro da quadra e varre (os dois fora de fase)
		var ang := -0.62 * sinal + sin(_t * 0.45 * rapido + lado * 2.1) * 0.30 * sinal
		f.rotation = ang
		var forca := 0.10 + 0.24 * energia + (0.08 if _modo != NORMAL else 0.0)
		f.modulate = Color(cor.r, cor.g, cor.b, forca * (0.85 + 0.15 * sin(_t * 3.1 + lado)))
	for e in _flashes:
		if not e.visible:
			continue
		var t: float = e.get_meta("t") + delta
		e.set_meta("t", t)
		if t < 0.0:
			continue
		var k := t / 0.22
		if k >= 1.0:
			e.visible = false
			continue
		var pico := sin(k * PI)
		e.modulate.a = pico
		e.scale = Vector2.ONE * (0.4 + 1.1 * pico) * 90.0 / Arte.tex_estrela.get_width()
		e.rotation = k * 0.6
