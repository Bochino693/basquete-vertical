extends Node2D

## A REDE DA CESTA (apresentação): fios em zigue-zague do aro até o anel de
## baixo. Balança quando a bola passa (só então é redesenhada).

var raio_aro := Vector2(120, 26)
var raio_baixo := Vector2(78, 18)
var altura := 150.0
var fios := 12
var cor := Color(0.9, 0.95, 1.0)
var _balanco := 0.0
var _t := 0.0


func balancar(forca := 1.0) -> void:
	_balanco = forca
	set_process(true)


func _ready() -> void:
	material = Arte.mat_aditivo
	set_process(false)
	update()


func _process(delta: float) -> void:
	_t += delta
	_balanco = max(0.0, _balanco - delta * 1.6)
	update()
	if _balanco <= 0.0:
		set_process(false)


func _ponto(i: float, nivel: float) -> Vector2:
	# i: posição ao redor (0..fios), nivel: 0 (aro) .. 1 (baixo)
	var ang := PI * (i / fios)
	var r := raio_aro.linear_interpolate(raio_baixo, nivel)
	var p := Vector2(-cos(ang) * r.x, sin(ang) * r.y + altura * nivel)
	var onda := sin(_t * 22.0 + nivel * 5.0 + i) * 14.0 * _balanco * nivel
	p.x += onda
	p.y += _balanco * 26.0 * nivel * nivel
	return p


func _draw() -> void:
	var niveis := 5
	for i in range(0, fios + 1):
		var pts = PoolVector2Array()
		for k in niveis + 1:
			var nivel = float(k) / niveis
			var desl = 0.5 if k % 2 == 1 else 0.0
			pts.append(_ponto(clamp(i + desl, 0, fios), nivel))
		draw_polyline(pts, Color(cor.r, cor.g, cor.b, 0.18), 7.0)
		draw_polyline(pts, Color(cor.r, cor.g, cor.b, 0.85), 2.2)
	var baixo := PoolVector2Array()
	for i in fios + 1:
		baixo.append(_ponto(i, 1.0))
	draw_polyline(baixo, Color(cor.r, cor.g, cor.b, 0.7), 2.5)
