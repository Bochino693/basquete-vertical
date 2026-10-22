extends Node2D

## DISPLAY DE 7 SEGMENTOS, como o placar de LED de verdade: cada segmento
## aceso tem o miolo quase branco (quente), a cor em volta e um brilho de
## neon; os apagados aparecem escuros, da mesma cor (o vidro do LED); e
## atrás dos dígitos há uma PLACA de vidro escuro (retangular ou redonda),
## para nenhum efeito do fundo passar por cima dos números.
##
## NÍTIDO EM QUALQUER TAMANHO: cada caractere é um quadrado com a textura
## de CAMPO DE DISTÂNCIA dele (imagens/d7_*.png, feitas por
## tools/gerar_texturas.py); o display7.shader calcula por pixel a borda
## (1 pixel da tela de transição), o miolo quente e o brilho. Trocar o
## número só troca a textura de cada casa - nada de geometria por quadro.

enum { SEM_PLACA, PLACA, PLACA_REDONDA }

var digitos := 2
var altura := 120.0
var cor := Color(1.0, 0.46, 0.04) setget _set_cor
var apagado := 0.40                 # força dos segmentos apagados
var brilho := -1.0                  # alcance do brilho (px); -1 = automático
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


## A placa de vidro escuro atrás dos dígitos (desenhada uma vez). A redonda
## é calculada por pixel no placa_redonda.shader (borda lisa).
class Placa extends Node2D:
	var tamanho := Vector2(100, 60)
	var redonda := false
	var cor := Color(1, 0.5, 0)

	func _draw() -> void:
		if redonda:
			var m := tamanho * 0.5
			draw_primitive(PoolVector2Array([-m, Vector2(m.x, -m.y), m, Vector2(-m.x, m.y)]),
				PoolColorArray([Color.white, Color.white, Color.white, Color.white]),
				PoolVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]))
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
		Tela.connect("mudou", self, "_ajustar_nitidez")
	if _placa == null:
		_placa = Placa.new()
		add_child(_placa)
	_placa.visible = placa != SEM_PLACA
	_placa.redonda = placa == PLACA_REDONDA
	var total := largura_total()
	if _placa.redonda:
		var d := diametro_placa if diametro_placa > 0.0 else max(total + altura * 0.5, altura * 1.6)
		_placa.tamanho = Vector2.ONE * d
		if _placa.material == null:
			_placa.material = Arte.material("res://shaders/placa_redonda.shader")
	else:
		_placa.tamanho = Vector2(total + altura * 0.62, altura * 1.18)
		_placa.material = null
	_placa.position = desvio_placa
	_placa.update()
	var w := altura * 0.56
	var gap := altura * 0.20
	var q := quadrado(altura)
	for i in digitos:
		var m = MeshInstance2D.new()
		m.material = _mat
		m.mesh = q
		m.position = Vector2(-total * 0.5 + i * (w + gap), -altura * 0.5)
		add_child(m)
		_casas.append(m)
	_set_cor(c)
	_ajustar_nitidez()
	_mostrar()


## A borda tem 1 pixel DA TELA: o shader precisa saber quantos pixels da
## tela tem a altura do dígito (TV em 720p, 1080p, imagem reduzida...).
func _ajustar_nitidez() -> void:
	if _mat == null:
		return
	var px := Tela.pixels_por_unidade()
	_mat.set_shader_param("altura_px", altura * px)
	_mat.set_shader_param("apagado", apagado)
	_mat.set_shader_param("brilho", (brilho if brilho >= 0.0 else altura * 0.075) / altura)
	if _placa != null and _placa.redonda and _placa.material != null:
		_placa.material.set_shader_param("raio_px", _placa.tamanho.x * 0.5 * px)


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
		if _placa.material != null:
			_placa.material.set_shader_param("cor", c)
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
		m.texture = Arte.textura_d7(s[i])


## O quadrado de um caractere de altura "h" (igual para todos: só a
## textura muda). Cobre o dígito inclinado e o brilho em volta; o UV
## aponta para o mesmo pedaço da textura de 256 px (160 px por altura,
## o centro do dígito no meio dela).
static func quadrado(h: float) -> ArrayMesh:
	var chave := "d7q_%d" % int(h * 10)
	var cache: Dictionary = Arte.cache_malhas
	if cache.has(chave):
		return cache[chave]
	var x0 := -0.35
	var x1 := 0.91
	var y0 := -0.30
	var y1 := 1.30
	var pts := PoolVector2Array()
	var uvs := PoolVector2Array()
	for p in [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]:
		pts.append(p * h)
		uvs.append(Vector2((p.x - 0.28) * 160.0 / 256.0 + 0.5, (p.y - 0.5) * 160.0 / 256.0 + 0.5))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = PoolIntArray([0, 1, 2, 0, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	cache[chave] = m
	return m
