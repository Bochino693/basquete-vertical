extends Node2D

## RAIO ELÉTRICO (MODO ENTERRADA e apresentação): um caminho em zigue-zague
## com galhos, que treme por alguns décimos de segundo. Cada caminho é uma
## faixa contínua com textura de borda macia (fx_linha): brilho largo,
## faixa média e o miolo branco - liso, sem a "escadinha" das linhas
## comuns. Refeito só quando treme (uma chamada de desenho por faixa).
##
## Para parecer raio de verdade (e não um "tubo" de brilho): a força varia
## AO ACASO ao longo do caminho, o brilho afina e SOME nas pontas (o fim
## não aparece cortado), os galhos e sub-galhos mudam de número e de lugar
## a cada tremida e o tremor tem ritmo irregular.

var cor := Color(0.35, 0.80, 1.0)
var _caminhos: Array = []         # [pontos, é galho, força]
var _de := Vector2()
var _ate := Vector2()
var _vida := 0.0
var _tremer := 0.0
var _proxima := 0.06
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
	# o fim mexe um pouquinho a cada tremida (não acerta sempre o mesmo ponto)
	var fim := _ate + Vector2(_r.randf_range(-10, 10), _r.randf_range(-8, 8))
	var principal := _zigue(_de, fim, 5, _r.randf_range(0.16, 0.26))
	_caminhos.append([principal, false, 1.0])
	var comprimento := _de.distance_to(fim)
	for g in _r.randi_range(2, 4):
		var i := _r.randi_range(2, principal.size() - 4)
		var p: Vector2 = principal[i]
		var dir := (fim - _de).normalized().rotated(_r.randf_range(-1.0, 1.0))
		var galho := _zigue(p, p + dir * comprimento * _r.randf_range(0.10, 0.30), 3, 0.32)
		_caminhos.append([galho, true, _r.randf_range(0.45, 0.8)])
		# às vezes um sub-galho, mais fraco
		if _r.randf() < 0.45 and galho.size() > 5:
			var q: Vector2 = galho[_r.randi_range(1, galho.size() - 3)]
			var d2 := dir.rotated(_r.randf_range(-1.1, 1.1))
			_caminhos.append([_zigue(q, q + d2 * comprimento * _r.randf_range(0.05, 0.12), 2, 0.35), true, 0.35])
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
	if _tremer >= _proxima:
		_tremer = 0.0
		_proxima = _r.randf_range(0.035, 0.09)
		_gerar()
	modulate.a = clamp(_vida * 6.0, 0.0, 1.0) * (0.7 + 0.3 * _r.randf())


func _draw() -> void:
	for cam in _caminhos:
		var c: PoolVector2Array = cam[0]
		var galho: bool = cam[1]
		var forca: float = cam[2]
		var g: float = 0.55 if galho else 1.0
		var pesos := _pesos(c.size(), galho)
		# o brilho largo é sutil e some antes nas pontas; o miolo vai até o fim
		_faixa(c, pesos, 1.6, Color(cor.r, cor.g, cor.b, 0.12 * forca), 44.0 * g)
		_faixa(c, pesos, 1.0, Color(cor.r, cor.g, cor.b, 0.55 * forca), 12.0 * g)
		_faixa(c, pesos, 0.5, Color(0.92, 0.98, 1.0, forca), 4.5 * g)


## A força de cada ponto: some suave nas pontas (galho: afina até a ponta;
## o raio principal: entra e sai suave) e varia ao acaso pelo caminho.
func _pesos(n: int, galho: bool) -> PoolRealArray:
	var p := PoolRealArray()
	var anterior := 1.0
	for k in n:
		var s := float(k) / max(n - 1, 1)
		var ponta: float
		if galho:
			ponta = pow(1.0 - s, 0.9)
		else:
			ponta = smoothstep(0.0, 0.05, s) * (1.0 - 0.8 * smoothstep(0.86, 1.0, s))
		# acaso, um pouco amaciado com o ponto anterior (não pisca em degraus)
		var acaso: float = lerp(anterior, _r.randf_range(0.45, 1.0), 0.6)
		anterior = acaso
		p.append(ponta * acaso)
	return p


## Uma faixa ao longo do caminho (as juntas com a média das direções), com
## a textura macia atravessada (u = de um lado ao outro). A largura e a
## transparência seguem os pesos (elevados a "curva": o brilho largo afina
## antes, o miolo depois).
func _faixa(c: PoolVector2Array, pesos: PoolRealArray, curva: float, cor_faixa: Color, larg: float) -> void:
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
		var w := pow(max(pesos[k], 0.0), curva)
		var normal := Vector2(-d.y, d.x).normalized() * larg * 0.5 * (0.35 + 0.65 * w)
		pts.append(c[k] + normal)
		pts.append(c[k] - normal)
		uvs.append(Vector2(0, 0.5))
		uvs.append(Vector2(1, 0.5))
		var ck := Color(cor_faixa.r, cor_faixa.g, cor_faixa.b, cor_faixa.a * w)
		cores.append(ck)
		cores.append(ck)
		if k > 0:
			var a: int = (k - 1) * 2
			idx.append_array(PoolIntArray([a, a + 1, a + 3, a, a + 3, a + 2]))
	VisualServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cores, uvs, PoolIntArray(), PoolRealArray(), Arte.tex_linha.get_rid())
