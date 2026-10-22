extends Node2D

## A linha tracejada do pódio que liga o topo das colunas, com a diferença
## de pontos entre um jogador e o próximo (+N).

var _topos: Array = []
var _valores: Array = []
var _fonte: Font


func definir(topos: Array, valores: Array) -> void:
	_topos = topos
	_valores = valores
	_fonte = Arte.fonte(30, 4)
	update()


func _draw() -> void:
	if _topos.size() < 2:
		return
	var cor := Color(1.0, 0.5, 0.08, 0.95)
	var marcas := []
	for t in _topos:
		var m: Vector2 = t - Vector2(0, 110)
		marcas.append(m)
		draw_line(t, m, Color(cor.r, cor.g, cor.b, 0.35), 2.0)
	for i in marcas.size() - 1:
		var de: Vector2 = marcas[i]
		var ate: Vector2 = marcas[i + 1]
		var total = de.distance_to(ate)
		var dir = (ate - de) / max(total, 0.001)
		var p = 0.0
		while p < total:
			draw_line(de + dir * p, de + dir * min(p + 16.0, total), cor, 4.0)
			p += 26.0
		var dif = int(_valores[i + 1]) - int(_valores[i])
		if dif != 0:
			var txt = "+%d" % dif
			var meio: Vector2 = (de + ate) * 0.5 - Vector2(0, 18)
			var w = _fonte.get_string_size(txt).x
			draw_string(_fonte, meio - Vector2(w * 0.5, 0), txt, Arte.AMBAR)
	for m in marcas:
		draw_circle(m, 8.0, cor)
		draw_circle(m, 4.0, Color(1, 1, 1))
