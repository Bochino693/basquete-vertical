extends Control

## LETREIRO DE LED QUE RODA: o texto passa sem parar da direita para a
## esquerda dentro de uma placa de vidro escuro, e LÂMPADAS correm em volta
## (no placar, em cima da moldura da própria arte), como letreiro de parque.
## No placar ele entra no lugar da meta já batida: "PASSOU DE FASE  •
## RUMO À FASE 2".
## Leve: um texto que só anda (posição em pixel inteiro: as letras não
## borram) e lâmpadas que são brilhos prontos.

var velocidade := 150.0          # pixels por segundo
var margem_lampadas := 10.0
var n_lampadas := 28

var _placa: Panel
var _janela: Control
var _txt: Label
var _texto := ""
var _cor := Color(0.3, 1.0, 0.5)
var _periodo := 1.0
var _x := 0.0
var _t := 0.0
var _lampadas := []              # [brilho, miolo]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


func montar(tamanho: Vector2, fonte := 46) -> void:
	rect_size = tamanho
	_placa = Panel.new()
	_placa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_placa.rect_size = tamanho
	add_child(_placa)
	# a janela corta o texto na borda da placa
	_janela = Control.new()
	_janela.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_janela.rect_clip_content = true
	_janela.rect_position = Vector2(8, 4)
	_janela.rect_size = tamanho - Vector2(16, 8)
	add_child(_janela)
	_txt = Arte.texto("", fonte, Color(1, 1, 1), 5, Color(0.0, 0.04, 0.02), Label.ALIGN_LEFT)
	_janela.add_child(_txt)
	for i in n_lampadas:
		var g := Arte.sprite_brilho(Color(1, 1, 1), 44.0)
		var m := Arte.sprite_brilho(Color(1, 1, 1), 15.0)
		add_child(g)
		add_child(m)
		_lampadas.append([g, m])
	# lâmpadas espaçadas igualmente em volta da placa
	var r := Rect2(-Vector2.ONE * margem_lampadas, tamanho + Vector2.ONE * margem_lampadas * 2.0)
	var perimetro := 2.0 * (r.size.x + r.size.y)
	for i in n_lampadas:
		var s := perimetro * float(i) / n_lampadas
		var p := r.position
		if s < r.size.x:
			p += Vector2(s, 0)
		elif s < r.size.x + r.size.y:
			p += Vector2(r.size.x, s - r.size.x)
		elif s < 2.0 * r.size.x + r.size.y:
			p += Vector2(r.size.x - (s - r.size.x - r.size.y), r.size.y)
		else:
			p += Vector2(0, r.size.y - (s - 2.0 * r.size.x - r.size.y))
		_lampadas[i][0].position = p
		_lampadas[i][1].position = p


## As lâmpadas em cima de um caminho fechado (coordenadas deste letreiro):
## no placar, a própria moldura da caixa da arte.
func lampadas_no_caminho(pontos: PoolVector2Array) -> void:
	var n := pontos.size()
	var total := 0.0
	for i in n:
		total += pontos[i].distance_to(pontos[(i + 1) % n])
	for k in _lampadas.size():
		var s := total * float(k) / _lampadas.size()
		for i in n:
			var a: Vector2 = pontos[i]
			var b: Vector2 = pontos[(i + 1) % n]
			var l := a.distance_to(b)
			if s <= l:
				var p := a.linear_interpolate(b, s / max(l, 0.001))
				_lampadas[k][0].position = p
				_lampadas[k][1].position = p
				break
			s -= l


## Liga (ou troca) o texto que roda. O mesmo texto não recomeça do zero.
func mostrar(t: String, cor: Color) -> void:
	if visible and t == _texto and cor == _cor:
		return
	_texto = t
	_cor = cor
	var um := t + "   •   "
	var f: Font = _txt.get_font("font")
	_periodo = max(f.get_string_size(um).x, 1.0)
	# cópias suficientes para a janela nunca ficar vazia
	var copias := int(ceil(_janela.rect_size.x / _periodo)) + 2
	var s := ""
	for i in copias:
		s += um
	_txt.text = s
	_txt.rect_size = Vector2(_periodo * copias + 8.0, _janela.rect_size.y)
	_txt.add_color_override("font_color", cor.linear_interpolate(Color(1, 1, 1), 0.25))
	# a mesma placa de vidro escuro dos displays (o neon fica na moldura da arte)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.012, 0.006, 0.004, 0.93)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(cor.r * 0.8, cor.g * 0.8, cor.b * 0.8, 0.7)
	sb.anti_aliasing = true
	_placa.add_stylebox_override("panel", sb)
	# começa já com o começo da frase à vista (lê-se "PASSOU..." na hora)
	_x = -8.0
	_t = 0.0
	visible = true
	set_process(true)
	_mover(0.0)


func esconder() -> void:
	visible = false
	_texto = ""
	set_process(false)


func _process(delta: float) -> void:
	_mover(delta)


func _mover(delta: float) -> void:
	_t += delta
	_x += velocidade * delta
	var px := -_x if _x < 0.0 else -fposmod(_x, _periodo)
	_txt.rect_position = Vector2(round(px), 0)
	# lâmpadas: uma acesa a cada 3, correndo em volta
	var miolo := _cor.linear_interpolate(Color(1, 1, 1), 0.65)
	for i in _lampadas.size():
		var k := fposmod(float(i) - _t * 7.0, 3.0)
		var b := 0.25 + 0.75 * clamp(1.0 - abs(k - 0.5) * 1.6, 0.0, 1.0)
		_lampadas[i][0].modulate = Color(_cor.r, _cor.g, _cor.b, b)
		_lampadas[i][1].modulate = Color(miolo.r, miolo.g, miolo.b, b)
