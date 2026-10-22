extends Node2D

## DISPLAY DE 7 SEGMENTOS DESENHADO À MÃO, com brilho de neon em volta de
## cada segmento aceso e os segmentos apagados levemente visíveis (como um
## placar de LED de verdade).
##
## Leve de verdade: cada caractere (0-9, "-", " ") de cada tamanho vira
## UMA malha, feita uma vez e guardada (Arte); cada dígito do display é um
## MeshInstance2D que só troca de malha quando o número muda (nenhuma conta
## de geometria em GDScript durante o jogo). A cor é o modulate.

const SEGMENTOS := {
	"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
	"5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg",
	"-": "g", " ": "",
}

var digitos := 2
var altura := 120.0
var cor := Color(1.0, 0.46, 0.04) setget _set_cor
var apagado := 0.13                 # força dos segmentos apagados
var brilho := -1.0                  # largura do brilho (px); -1 = automático
var inclinacao := 0.10
var zeros := true                   # zeros à esquerda
var texto := "" setget _set_texto   # mostra um texto livre ("--", "  ")
var valor := 0 setget _set_valor
var _casas: Array = []


func configurar(n_digitos: int, altura_px: float, c: Color, glow := -1.0) -> void:
	digitos = n_digitos
	altura = altura_px
	brilho = glow
	for m in _casas:
		m.queue_free()
	_casas = []
	var w := altura * 0.56
	var gap := altura * 0.20
	var total := largura_total()
	for i in digitos:
		var m = MeshInstance2D.new()
		m.position = Vector2(-total * 0.5 + i * (w + gap), -altura * 0.5)
		add_child(m)
		_casas.append(m)
	_set_cor(c)
	preparar_malhas()
	_mostrar()


## Prepara as malhas de todos os caracteres deste tamanho (preparação).
func preparar_malhas() -> void:
	for ch in SEGMENTOS:
		malha(ch, altura, brilho if brilho >= 0.0 else altura * 0.11, inclinacao, apagado)


func largura_total() -> float:
	var w := altura * 0.56
	var gap := altura * 0.20
	return digitos * w + (digitos - 1) * gap


func _set_valor(v: int) -> void:
	if v == valor and texto == "":
		return
	valor = v
	texto = ""
	_mostrar()


func _set_texto(t: String) -> void:
	texto = t
	_mostrar()


func _set_cor(c: Color) -> void:
	cor = c
	modulate = Color(c.r, c.g, c.b, modulate.a)


func _string() -> String:
	var s := texto
	if s == "":
		var limite := int(pow(10, digitos)) - 1
		var v := int(clamp(valor, -limite, limite))
		s = str(v)
		if zeros:
			while s.length() < digitos:
				s = "0" + s
	while s.length() < digitos:
		s = " " + s
	return s.substr(s.length() - digitos, digitos)


func _mostrar() -> void:
	if _casas.empty():
		return
	var s := _string()
	for i in digitos:
		var m: MeshInstance2D = _casas[i]
		m.mesh = malha(s[i], altura, brilho if brilho >= 0.0 else altura * 0.11, inclinacao, apagado)


## A malha de um caractere (branca: o display pinta com o modulate).
static func malha(ch: String, h: float, glow: float, inclinacao: float, apagado: float) -> ArrayMesh:
	var chave := "d7_%s_%d_%d_%d_%d" % [ch, int(h * 10), int(glow * 10), int(inclinacao * 1000), int(apagado * 1000)]
	var cache: Dictionary = Arte.cache_malhas
	if cache.has(chave):
		return cache[chave]
	var w := h * 0.56
	var t := h * 0.12
	var pts := []
	var cols := []
	var idx := []
	var acesos: String = SEGMENTOS.get(ch, "")
	for seg in "abcdefg":
		var poli = _segmento(seg, w, h, t, inclinacao)
		if seg in acesos:
			_poligono(poli, Color(1, 1, 1, 1), glow, pts, cols, idx)
		elif apagado > 0.0:
			_poligono(poli, Color(0.55, 0.45, 0.40, apagado), 0.0, pts, cols, idx)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PoolVector2Array(pts)
	arr[Mesh.ARRAY_COLOR] = PoolColorArray(cols)
	arr[Mesh.ARRAY_INDEX] = PoolIntArray(idx)
	var m := ArrayMesh.new()
	if not idx.empty():
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	cache[chave] = m
	return m


## Hexágono do segmento (pontas em bisel), já inclinado (caixa w x h).
static func _segmento(seg: String, w: float, h: float, t: float, inclinacao: float) -> PoolVector2Array:
	var m := t * 0.5
	var g := t * 0.18
	var a := Vector2()
	var b := Vector2()
	match seg:
		"a":
			a = Vector2(m + g, m)
			b = Vector2(w - m - g, m)
		"g":
			a = Vector2(m + g, h * 0.5)
			b = Vector2(w - m - g, h * 0.5)
		"d":
			a = Vector2(m + g, h - m)
			b = Vector2(w - m - g, h - m)
		"f":
			a = Vector2(m, m + g)
			b = Vector2(m, h * 0.5 - g)
		"b":
			a = Vector2(w - m, m + g)
			b = Vector2(w - m, h * 0.5 - g)
		"e":
			a = Vector2(m, h * 0.5 + g)
			b = Vector2(m, h - m - g)
		"c":
			a = Vector2(w - m, h * 0.5 + g)
			b = Vector2(w - m, h - m - g)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	var out := PoolVector2Array([a, a + d * m + n * m, b - d * m + n * m, b, b - d * m - n * m, a + d * m - n * m])
	for k in out.size():
		var p: Vector2 = out[k]
		p.x += (h * 0.5 - p.y) * inclinacao
		out[k] = p
	return out


## Miolo (leque) + dois anéis de brilho que somem para fora.
## (Godot 3: PoolArrays são cópias; o acúmulo é em Array comum.)
static func _poligono(poli: PoolVector2Array, c: Color, glow: float, pts: Array, cols: Array, idx: Array) -> void:
	var n := poli.size()
	var base := pts.size()
	for p in poli:
		pts.append(p)
		cols.append(c)
	for k in range(1, n - 1):
		idx.append(base)
		idx.append(base + k)
		idx.append(base + k + 1)
	if glow <= 0.0:
		return
	var centro := Vector2()
	for p in poli:
		centro += p
	centro /= n
	var normais := []
	for k in n:
		var p: Vector2 = poli[k]
		var n1 = (p - poli[(k - 1 + n) % n]).normalized()
		var n2 = (poli[(k + 1) % n] - p).normalized()
		var normal = Vector2(n1.y, -n1.x) + Vector2(n2.y, -n2.x)
		if normal.dot(p - centro) < 0.0:
			normal = -normal
		normais.append(normal.normalized())
	var aneis := [[0.0, 0.50], [0.6, 0.16], [1.8, 0.0]]
	var inicio := []
	for anel in aneis:
		inicio.append(pts.size())
		for k in n:
			pts.append(poli[k] + normais[k] * glow * anel[0])
			cols.append(Color(c.r, c.g, c.b, c.a * anel[1]))
	for r in 2:
		var a0: int = inicio[r]
		var b0: int = inicio[r + 1]
		for k in n:
			var a = a0 + k
			var b = a0 + (k + 1) % n
			var ao = b0 + k
			var bo = b0 + (k + 1) % n
			idx.append_array([a, b, bo, a, bo, ao])
