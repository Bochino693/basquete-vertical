extends Node2D

## RAIO ELÉTRICO (MODO ENTERRADA e apresentação): um caminho em zigue-zague
## com galhos, que treme por alguns décimos de segundo. Cada caminho é uma
## faixa contínua com textura de borda macia (fx_linha): brilho largo,
## faixa média e o miolo branco - liso, sem a "escadinha" das linhas
## comuns. Refeito só quando treme (uma chamada de desenho por faixa).

var cor := Color(0.35, 0.80, 1.0)
var _caminhos: Array = []
var _de := Vector2()
var _ate := Vector2()
var _vida := 0.0
var _tremer := 0.0
var _r := RandomNumberGenerator.new()


func _ready() -> void:
	_r.randomize()
	material = Arte.mat_aditivo
	visible = false
	set_process(false)


func disparar(de: Vector2, ate: Vector2, duracao := 0.32) -> void:
	_de = de
	_ate = ate
	_vida = duracao
	_tremer = 0.0
	_gerar()
	visible = true
	set_process(true)


func _gerar() -> void:
	_caminhos = []
	var principal := _zigue(_de, _ate, 5, 0.22)
	_caminhos.append(principal)
	for g in 2:
		var i = _r.randi_range(2, principal.size() - 3)
		var p: Vector2 = principal[i]
		var dir = (_ate - _de).normalized().rotated(_r.randf_range(-0.9, 0.9))
		_caminhos.append(_zigue(p, p + dir * _de.distance_to(_ate) * _r.randf_range(0.18, 0.32), 3, 0.3))
	update()


func _zigue(a: Vector2, b: Vector2, niveis: int, desvio: float) -> PoolVector2Array:
	var pts := [a, b]
	var amp := a.distance_to(b) * desvio
	for n in niveis:
		var novos = [pts[0]]
		for i in range(1, pts.size()):
			var p0: Vector2 = pts[i - 1]
			var p1: Vector2 = pts[i]
			var meio = (p0 + p1) * 0.5
			var normal = (p1 - p0).normalized().rotated(PI * 0.5)
			novos.append(meio + normal * _r.randf_range(-amp, amp))
			novos.append(p1)
		pts = novos
		amp *= 0.5
	return PoolVector2Array(pts)


func _process(delta: float) -> void:
	_vida -= delta
	if _vida <= 0.0:
		visible = false
		set_process(false)
		return
	_tremer += delta
	if _tremer >= 0.07:
		_tremer = 0.0
		_gerar()
	modulate.a = clamp(_vida * 6.0, 0.0, 1.0) * (0.75 + 0.25 * _r.randf())


func _draw() -> void:
	for i in _caminhos.size():
		var c: PoolVector2Array = _caminhos[i]
		var g = 1.0 if i == 0 else 0.6
		_faixa(c, Color(cor.r, cor.g, cor.b, 0.22), 40.0 * g)
		_faixa(c, Color(cor.r, cor.g, cor.b, 0.75), 14.0 * g)
		_faixa(c, Color(0.92, 0.98, 1.0, 1.0), 5.5 * g)


## Uma faixa de largura "larg" ao longo do caminho (as juntas com a média
## das direções), com a textura macia atravessada (u = de um lado ao outro).
func _faixa(c: PoolVector2Array, cor_faixa: Color, larg: float) -> void:
	var n := c.size()
	if n < 2:
		return
	var pts := PoolVector2Array()
	var uvs := PoolVector2Array()
	var cores := PoolColorArray()
	var idx := PoolIntArray()
	for k in n:
		var d := Vector2()
		if k > 0:
			d += (c[k] - c[k - 1]).normalized()
		if k < n - 1:
			d += (c[k + 1] - c[k]).normalized()
		var normal := Vector2(-d.y, d.x).normalized() * larg * 0.5
		pts.append(c[k] + normal)
		pts.append(c[k] - normal)
		uvs.append(Vector2(0, 0.5))
		uvs.append(Vector2(1, 0.5))
		cores.append(cor_faixa)
		cores.append(cor_faixa)
		if k > 0:
			var a: int = (k - 1) * 2
			idx.append_array(PoolIntArray([a, a + 1, a + 3, a, a + 3, a + 2]))
	VisualServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cores, uvs, PoolIntArray(), PoolRealArray(), Arte.tex_linha.get_rid())
