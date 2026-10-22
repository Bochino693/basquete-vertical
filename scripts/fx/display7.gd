extends Node2D

## DISPLAY DE 7 SEGMENTOS DESENHADO À MÃO, como o placar de LED de verdade:
## cada segmento aceso tem o miolo quase branco (quente), a cor em volta e
## um brilho de neon; os apagados aparecem escuros, da mesma cor (o vidro
## do LED); e atrás dos dígitos há uma PLACA de vidro escuro (retangular
## ou redonda), para nenhum efeito do fundo passar por cima dos números.
##
## Leve de verdade: cada caractere (0-9, "-", " ") de cada tamanho vira
## UMA malha, feita uma vez e guardada (Arte); cada dígito do display é um
## MeshInstance2D que só troca de malha quando o número muda (nenhuma conta
## de geometria em GDScript durante o jogo). A cor é um parâmetro do
## display7.shader (o modulate fica livre para aparecer/sumir).

const SEGMENTOS := {
	"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
	"5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg",
	"-": "g", " ": "",
}
enum { SEM_PLACA, PLACA, PLACA_REDONDA }

var digitos := 2
var altura := 120.0
var cor := Color(1.0, 0.46, 0.04) setget _set_cor
var apagado := 0.40                 # força dos segmentos apagados
var brilho := -1.0                  # largura do brilho (px); -1 = automático
var inclinacao := 0.10
var zeros := true                   # zeros à esquerda
var texto := "" setget _set_texto   # mostra um texto livre ("--", "  ")
var valor := 0 setget _set_valor
var placa := PLACA
## placa redonda: diâmetro (0 = automático) e onde fica em relação aos
## dígitos (o cronômetro: os dígitos um pouco abaixo do centro, "TEMPO" em cima)
var diametro_placa := 0.0
var desvio_placa := Vector2()
var _casas: Array = []
var _mat: ShaderMaterial
var _placa: Placa


## A placa de vidro escuro atrás dos dígitos (desenhada uma vez).
class Placa extends Node2D:
	var tamanho := Vector2(100, 60)
	var redonda := false
	var cor := Color(1, 0.5, 0)

	func _draw() -> void:
		if redonda:
			var r := tamanho.x * 0.5
			draw_circle(Vector2.ZERO, r, Color(0.012, 0.006, 0.004, 0.93))
			draw_circle(Vector2(0, -r * 0.08), r * 0.92, Color(0.03, 0.016, 0.01, 0.6))
			# a borda: faixa com textura de bordas macias (draw_arc da Mali sai em "escadinha")
			Arte.arco(self, Vector2.ZERO, r - 2.0, 0.0, TAU, Color(cor.r, cor.g, cor.b, 0.45), 3.5)
			return
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.012, 0.006, 0.004, 0.93)
		sb.set_corner_radius_all(int(min(tamanho.y * 0.18, 16.0)))
		sb.set_border_width_all(2)
		sb.border_color = Color(cor.r * 0.7, cor.g * 0.7, cor.b * 0.7, 0.55)
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(-tamanho * 0.5, tamanho))
		# reflexo do vidro: uma faixa clara fina no alto
		var faixa := Rect2(-tamanho.x * 0.5 + 8.0, -tamanho.y * 0.5 + 5.0, tamanho.x - 16.0, tamanho.y * 0.16)
		draw_rect(faixa, Color(1, 1, 1, 0.035))


func configurar(n_digitos: int, altura_px: float, c: Color, glow := -1.0, tipo_placa := PLACA) -> void:
	digitos = n_digitos
	altura = altura_px
	brilho = glow
	placa = tipo_placa
	for m in _casas:
		m.queue_free()
	_casas = []
	if _mat == null:
		_mat = Arte.material("res://shaders/display7.shader")
	if _placa == null:
		_placa = Placa.new()
		add_child(_placa)
	_placa.visible = placa != SEM_PLACA
	_placa.redonda = placa == PLACA_REDONDA
	var total := largura_total()
	if _placa.redonda:
		var d := diametro_placa if diametro_placa > 0.0 else max(total + altura * 0.5, altura * 1.6)
		_placa.tamanho = Vector2.ONE * d
	else:
		_placa.tamanho = Vector2(total + altura * 0.62, altura * 1.18)
	_placa.position = desvio_placa
	_placa.update()
	var w := altura * 0.56
	var gap := altura * 0.20
	for i in digitos:
		var m = MeshInstance2D.new()
		m.material = _mat
		m.position = Vector2(-total * 0.5 + i * (w + gap), -altura * 0.5)
		add_child(m)
		_casas.append(m)
	_set_cor(c)
	preparar_malhas()
	_mostrar()


## Prepara as malhas de todos os caracteres deste tamanho (preparação).
func preparar_malhas() -> void:
	for ch in SEGMENTOS:
		malha(ch, altura, _brilho_px(), inclinacao, apagado)


func _brilho_px() -> float:
	return brilho if brilho >= 0.0 else altura * 0.075


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
	if _mat != null:
		_mat.set_shader_param("cor", c)
	if _placa != null:
		_placa.cor = c
		_placa.update()


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
		m.mesh = malha(s[i], altura, _brilho_px(), inclinacao, apagado)


## A malha de um caractere. As cores dos pontos não são a cor do display:
## g = aceso, r = miolo quente, a = transparência (display7.shader pinta).
static func malha(ch: String, h: float, glow: float, inclinacao: float, apagado: float) -> ArrayMesh:
	var chave := "d7n_%s_%d_%d_%d_%d" % [ch, int(h * 10), int(glow * 10), int(inclinacao * 1000), int(apagado * 1000)]
	var cache: Dictionary = Arte.cache_malhas
	if cache.has(chave):
		return cache[chave]
	var w := h * 0.56
	var t := h * 0.135
	var pts := []
	var cols := []
	var idx := []
	var acesos: String = SEGMENTOS.get(ch, "")
	# primeiro os apagados (por baixo), depois os acesos e o miolo quente
	if apagado > 0.0:
		for seg in "abcdefg":
			if not seg in acesos:
				_poligono(_segmento(seg, w, h, t, inclinacao), Color(0, 0, 0, apagado), 0.0, pts, cols, idx)
	for seg in acesos:
		_poligono(_segmento(seg, w, h, t, inclinacao), Color(0, 1, 0, 1), glow, pts, cols, idx)
	for seg in acesos:
		_poligono(_segmento(seg, w, h, t, inclinacao, 0.32), Color(1, 1, 0, 1), 0.0, pts, cols, idx)
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
## "fino" < 1: o miolo do segmento (mais fino e um pouco mais curto).
static func _segmento(seg: String, w: float, h: float, t: float, inclinacao: float, fino := 1.0) -> PoolVector2Array:
	var m := t * 0.5
	var g := t * 0.14
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
	if fino < 1.0:
		a += d * m * 0.9
		b -= d * m * 0.9
		m *= fino
	var n := Vector2(-d.y, d.x)
	var out := PoolVector2Array([a, a + d * m + n * m, b - d * m + n * m, b, b - d * m - n * m, a + d * m - n * m])
	for k in out.size():
		var p: Vector2 = out[k]
		p.x += (h * 0.5 - p.y) * inclinacao
		out[k] = p
	return out


## Miolo (leque) + uma borda macia de 1,6 px (a beirada fica lisa, sem
## "escadinha", mesmo sem antisserrilhado na placa) + dois anéis de brilho
## que somem para fora. (Godot 3: PoolArrays são cópias; o acúmulo é em
## Array comum.)
const MACIO := 1.25


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
	# anéis: [distância da borda (px), força]
	var aneis := [[0.0, 1.0], [MACIO, 0.0]]
	if glow > 0.0:
		aneis = [[0.0, 1.0], [MACIO, 0.40], [MACIO + glow * 0.6, 0.11], [MACIO + glow * 1.8, 0.0]]
	var inicio := []
	for anel in aneis:
		inicio.append(pts.size())
		for k in n:
			pts.append(poli[k] + normais[k] * anel[0])
			cols.append(Color(c.r, c.g, c.b, c.a * anel[1]))
	for r in aneis.size() - 1:
		var a0: int = inicio[r]
		var b0: int = inicio[r + 1]
		for k in n:
			var a = a0 + k
			var b = a0 + (k + 1) % n
			var ao = b0 + k
			var bo = b0 + (k + 1) % n
			idx.append_array([a, b, bo, a, bo, ao])
