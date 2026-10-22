extends Control

## RESULTADO DA PARTIDA (1 jogador, 3 fases): o placar total contando no
## display de LED, uma coluna por fase subindo com os pontos de cada uma
## (PASSOU / NÃO PASSOU), cestas, maior combo, a posição no ranking do dia.
## O CLIMA muda tudo: FESTA (campeão ou recorde) = aplausos, coroa e
## confete; VAIA (não passou da fase 1, nenhum ponto) = nada de aplauso nem
## confete, painel vermelho e "TENTE DE NOVO!"; NEUTRO = sem festa. Uma CESTA (depois de
## 2,5 s: a bola que ainda caía no fim do tempo não conta) ou START joga de
## novo; sem nada, volta para a abertura sozinho.

signal acabou(acao)

const Display7 = preload("res://scripts/fx/display7.gd")
const VOLTA_SEGUNDOS := 14
const GUARDA_CESTA := 2.5
const CORES_FASE := [Color(1.0, 0.46, 0.04), Color(0.25, 0.62, 1.0), Color(1.0, 0.80, 0.12)]

var _painel: Panel
var _titulo: Label
var _sub: Label
var _rotulo_total: Label
var _total: Display7
var _colunas: Array = []
var _status: Array = []
var _caixas: Array = []
var _rank: Label
var _dica: Label
var _rodape: Label
var _coroa: Node2D
var _confete: CPUParticles2D
var _feixes: Array = []
var _ativo := false
var _t := 0.0
var _visto := 0.0
var _token := 0
var _ultimo_tique := 0


func _init() -> void:
	rect_size = Vector2(1080, 1920)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	var escuro := ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.82)
	escuro.rect_size = rect_size
	add_child(escuro)
	for i in 2:
		var f = Sprite.new()
		f.texture = Arte.tex_feixe
		f.material = Arte.mat_aditivo
		f.centered = false
		f.offset = Vector2(-32, 0)
		f.scale = Vector2(7.0, 14.0)
		f.position = Vector2(220 if i == 0 else 860, -30)
		f.modulate = Color(1.0, 0.85, 0.4, 0.16)
		add_child(f)
		_feixes.append(f)
	_painel = Arte.painel(Arte.LARANJA, 0.90, 44, 3, 30)
	_por(_painel, 40, 150, 1000, 1600)
	add_child(_painel)
	_titulo = Arte.texto("FIM DE JOGO", 84, Color(1, 1, 1), 9, Arte.LARANJA)
	_por(_titulo, 40, 186, 1000, 116)
	add_child(_titulo)
	_sub = Arte.texto("", 40, Arte.OURO, 5, Color(0.2, 0.08, 0.0))
	_por(_sub, 40, 300, 1000, 62)
	add_child(_sub)
	_rotulo_total = Arte.texto("SUA PONTUAÇÃO", 30, Arte.LARANJA_CLARO, 4, Color(0, 0, 0))
	_por(_rotulo_total, 40, 380, 1000, 44)
	add_child(_rotulo_total)
	_total = Display7.new()
	_total.zeros = false
	_total.configurar(4, 170, Arte.LARANJA)
	_total.position = Vector2(540, 530)
	add_child(_total)
	for i in 3:
		_colunas.append(_coluna(i))
		var st := Arte.texto("", 28, Color(1, 1, 1), 4, Color(0, 0, 0))
		add_child(st)
		_status.append(st)
	var nomes := ["CESTAS", "MAIOR SEQUÊNCIA", "HOJE"]
	for i in 3:
		var cx := Arte.painel(Arte.AMBAR, 0.85, 26, 2, 10)
		_por(cx, 80 + i * 315, 1262, 290, 128)
		cx.rect_pivot_offset = Vector2(145, 64)
		add_child(cx)
		var a := Arte.texto(nomes[i], 26, Arte.AMBAR, 3, Color(0, 0, 0))
		_por(a, 0, 10, 290, 36)
		cx.add_child(a)
		var b := Arte.texto("0", 60, Color(1, 1, 1), 6, Arte.LARANJA)
		b.name = "V"
		_por(b, 0, 40, 290, 80)
		cx.add_child(b)
		_caixas.append(cx)
	_rank = Arte.texto("", 38, Color(1, 1, 1), 5, Color(0, 0, 0))
	_por(_rank, 40, 1410, 1000, 60)
	add_child(_rank)
	_dica = Arte.texto("ACERTE A CESTA PARA JOGAR DE NOVO", 44, Arte.AMBAR, 6, Color(0, 0, 0))
	_por(_dica, 40, 1540, 1000, 70)
	add_child(_dica)
	_rodape = Arte.texto("", 30, Color(0.85, 0.85, 0.9), 4, Color(0, 0, 0))
	_por(_rodape, 40, 1630, 1000, 50)
	add_child(_rodape)
	_coroa = Arte.coroa(Arte.OURO, 1.0)
	_coroa.visible = false
	add_child(_coroa)
	_confete = CPUParticles2D.new()
	_confete.emitting = false
	_confete.amount = 140
	_confete.lifetime = 4.2
	_confete.one_shot = true
	_confete.explosiveness = 0.55
	_confete.texture = Arte.tex_confete
	_confete.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_confete.emission_rect_extents = Vector2(540, 10)
	_confete.position = Vector2(540, -30)
	_confete.direction = Vector2(0, 1)
	_confete.spread = 30.0
	_confete.gravity = Vector2(0, 260)
	_confete.initial_velocity = 160.0
	_confete.initial_velocity_random = 0.6
	_confete.angular_velocity = 260.0
	_confete.angular_velocity_random = 1.0
	_confete.scale_amount = 2.4
	_confete.scale_amount_random = 0.5
	_confete.hue_variation = 1.0
	_confete.hue_variation_random = 1.0
	_confete.color = Color(1.0, 0.4, 0.4)
	_confete.tangential_accel = 30.0
	_confete.tangential_accel_random = 1.0
	add_child(_confete)
	# atrás do painel: o confete não passa por cima dos textos
	move_child(_confete, _painel.get_index())


func _coluna(i: int) -> Dictionary:
	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var nome := Arte.texto(Ajustes.NOMES_FASE[i], 32, CORES_FASE[i], 4, Color(0, 0, 0))
	var pts := Arte.texto("0", 80, Color(1, 1, 1), 8, CORES_FASE[i])
	var txt := Arte.texto("PONTOS", 24, Color(1, 1, 1), 3, Color(0, 0, 0))
	var extra := Arte.texto("", 22, Color(0.85, 0.9, 1.0), 3, Color(0, 0, 0))
	extra.autowrap = true
	for l in [nome, pts, txt, extra]:
		card.add_child(l)
	return {"card": card, "nome": nome, "pts": pts, "txt": txt, "extra": extra, "valor": 0}


func aquecer() -> void:
	visible = true
	_confete.emitting = true
	_coroa.visible = true
	for i in 3:
		_colunas[i]["card"].visible = true


func esconder() -> void:
	_ativo = false
	_token += 1
	visible = false
	_confete.emitting = false
	_coroa.visible = false


## d: pontos, cestas, maior_combo, fase (0..2: a última jogada), campeao,
## passou[3], pontos_fase[3], cestas_fase[3], combo_fase[3], recorde (bool),
## posicao (no ranking do dia, 0 = não entrou)
func mostrar(d: Dictionary) -> void:
	_token += 1
	var tk := _token
	_ativo = true
	_visto = 0.0
	visible = true
	modulate.a = 0.0
	_coroa.visible = false
	var recorde: bool = d.get("recorde", false)
	var campeao: bool = d.get("campeao", false)
	var fase: int = int(d.get("fase", 0))
	var clima: String = d.get("clima", "festa" if recorde or campeao else "neutro")
	var cor: Color = Arte.OURO if clima == "festa" else (Arte.VERMELHO_ALERTA if clima == "vaia" else Arte.LARANJA)
	_painel.add_stylebox_override("panel", Arte.estilo_neon(cor, 0.90, 44, 3, 30))
	_titulo.text = "NOVO RECORDE!" if recorde else ("CAMPEÃO DA ARENA!" if campeao else "FIM DE JOGO")
	Arte.pintar(_titulo, Color(1, 1, 1), cor)
	if campeao:
		_sub.text = "VOCÊ VENCEU AS 3 FASES!"
	elif int(d.get("pontos", 0)) == 0:
		_sub.text = "NENHUMA CESTA..."
	elif fase == 0:
		_sub.text = "NÃO PASSOU DA FASE 1"
	else:
		_sub.text = "VOCÊ CHEGOU NA %s" % Ajustes.NOMES_FASE[fase]
	_total.cor = cor
	_total.valor = 0
	_atualizar_dica()
	_rodape.text = ""
	_rank.text = ""
	# colunas das fases (altura pelos pontos de cada uma)
	var pf: Array = d.get("pontos_fase", [0, 0, 0])
	var cf: Array = d.get("cestas_fase", [0, 0, 0])
	var kf: Array = d.get("combo_fase", [0, 0, 0])
	var passou: Array = d.get("passou", [false, false, false])
	var maior := 1
	for i in 3:
		maior = int(max(maior, int(pf[i])))
	var base_y := 1192.0
	for i in 3:
		var col: Dictionary = _colunas[i]
		var card: Panel = col["card"]
		var jogou: bool = i <= fase
		var h: float = lerp(250.0, 470.0, clamp(float(pf[i]) / float(maior), 0.0, 1.0)) if jogou else 150.0
		var x: float = 80.0 + i * 315.0
		var w := 290.0
		card.rect_position = Vector2(x, base_y - h)
		card.rect_size = Vector2(w, h)
		card.rect_pivot_offset = Vector2(w * 0.5, h)
		card.rect_scale = Vector2(1, 0.05)
		card.modulate.a = 0.0
		var c: Color = CORES_FASE[i]
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(30)
		sb.set_border_width_all(4)
		sb.anti_aliasing = true
		sb.bg_color = Color(c.r * 0.14, c.g * 0.14, c.b * 0.14, 0.94) if jogou else Color(0.06, 0.06, 0.08, 0.8)
		sb.border_color = c if jogou else Color(0.4, 0.4, 0.45)
		sb.shadow_color = Color(c.r, c.g, c.b, 0.45 if jogou else 0.0)
		sb.shadow_size = 22
		card.add_stylebox_override("panel", sb)
		_por(col["nome"], 0, 14, w, 46)
		_por(col["pts"], 0, 58, w, 100)
		col["pts"].text = "0" if jogou else "-"
		_por(col["txt"], 0, 154, w, 32)
		col["txt"].visible = jogou
		_por(col["extra"], 8, 188, w - 16, 58)
		col["extra"].text = "%d CESTAS • SEQUÊNCIA %d" % [int(cf[i]), int(kf[i])]
		col["extra"].visible = jogou
		col["valor"] = int(pf[i])
		var st: Label = _status[i]
		_por(st, x, base_y + 12, w, 44)
		if not jogou:
			st.text = "NÃO JOGOU"
			st.add_color_override("font_color", Color(0.55, 0.55, 0.6))
		elif i == 2:
			st.text = "COMPLETOU!"
			st.add_color_override("font_color", Arte.OURO)
		elif passou[i]:
			st.text = "PASSOU"
			st.add_color_override("font_color", Color(0.35, 1.0, 0.5))
		else:
			st.text = "NÃO PASSOU"
			st.add_color_override("font_color", Arte.VERMELHO_ALERTA)
		st.modulate.a = 0.0
	var valores := [str(int(d.get("cestas", 0))), "x%d" % int(d.get("maior_combo", 0)),
		"%dº" % int(d.get("posicao", 0)) if int(d.get("posicao", 0)) > 0 else "-"]
	for i in 3:
		var cx: Panel = _caixas[i]
		cx.get_node("V").text = valores[i]
		cx.modulate.a = 0.0
	# ------------------------------------------------------ a sequência
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.4)
	_titulo.rect_pivot_offset = _titulo.rect_size * 0.5
	_titulo.rect_scale = Vector2(1.8, 1.8)
	var tt := create_tween()
	tt.tween_property(_titulo, "rect_scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	yield(tw, "finished")
	if tk != _token:
		return
	# placar total contando
	var pontos := int(d.get("pontos", 0))
	var tc := create_tween()
	tc.tween_method(self, "_contar_total", 0.0, float(pontos), clamp(0.4 + pontos * 0.01, 0.6, 1.6)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	yield(get_tree().create_timer(0.5), "timeout")
	# colunas subindo, uma por vez
	for i in 3:
		if tk != _token:
			return
		var col: Dictionary = _colunas[i]
		var card: Panel = col["card"]
		Sons.tocar("sobe", -6.0, 0.8 + i * 0.15)
		var tcol := create_tween().set_parallel(true)
		tcol.tween_property(card, "modulate:a", 1.0, 0.2)
		tcol.tween_property(card, "rect_scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if i <= fase:
			tcol.tween_method(self, "_contar", 0.0, float(col["valor"]), 0.6, [col["pts"]]).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tcol.tween_property(_status[i], "modulate:a", 1.0, 0.25).set_delay(0.35)
		yield(get_tree().create_timer(0.42), "timeout")
	if tk != _token:
		return
	for i in 3:
		var cx: Panel = _caixas[i]
		cx.rect_scale = Vector2(0.6, 0.6)
		var tb := create_tween().set_parallel(true)
		tb.tween_property(cx, "modulate:a", 1.0, 0.18).set_delay(i * 0.1)
		tb.tween_property(cx, "rect_scale", Vector2.ONE, 0.32).set_delay(i * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	yield(get_tree().create_timer(0.45), "timeout")
	if tk != _token:
		return
	var posicao := int(d.get("posicao", 0))
	if clima == "vaia":
		_rank.text = "TENTE DE NOVO!"
		_rank.add_color_override("font_color", Color(1.0, 0.55, 0.45))
	elif recorde:
		_rank.text = "VOCÊ É O NOVO RECORDE DA ARENA!"
		_rank.add_color_override("font_color", Arte.OURO)
	elif posicao > 0:
		_rank.text = "VOCÊ FICOU EM %dº LUGAR HOJE!" % posicao
		_rank.add_color_override("font_color", Color(0.4, 1.0, 0.55))
	else:
		_rank.text = "RECORDE DA ARENA: %d PONTOS" % Ajustes.recorde
		_rank.add_color_override("font_color", Color(1, 1, 1))
	_rank.rect_pivot_offset = _rank.rect_size * 0.5
	_rank.rect_scale = Vector2(0.5, 0.5)
	var tr := create_tween()
	tr.tween_property(_rank, "rect_scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if clima == "festa":
		Sons.tocar("aplausos", -1.0)
		_coroa.visible = true
		_coroa.position = Vector2(540, -100)
		_coroa.scale = Vector2(1.1, 1.1)
		var tcr := create_tween()
		tcr.tween_property(_coroa, "position:y", 112.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		Sons.tocar("recorde", -2.0)
	if clima == "festa":
		_confete.restart()
		_confete.emitting = true
	var seg := VOLTA_SEGUNDOS
	while seg >= 0:
		if tk != _token:
			return
		_rodape.text = "VOLTA AO INÍCIO EM %d" % seg
		yield(get_tree().create_timer(1.0), "timeout")
		seg -= 1
	if tk == _token:
		emit_signal("acabou", "abertura")


## "ACERTE A CESTA..." ou, no modo crédito sem ficha, "INSIRA A FICHA...".
func _atualizar_dica() -> void:
	_dica.text = "ACERTE A CESTA PARA JOGAR DE NOVO" if Ajustes.pode_jogar() else "INSIRA A FICHA PARA JOGAR DE NOVO"


func ficha_inserida() -> void:
	if _ativo:
		_atualizar_dica()


func _contar_total(v: float) -> void:
	var n := int(round(v))
	if n != _total.valor:
		_total.valor = n
		var agora := OS.get_ticks_msec()
		if agora - _ultimo_tique > 55:
			_ultimo_tique = agora
			Sons.tocar("tique", -10.0, 1.4)


func _contar(valor: float, l: Label) -> void:
	l.text = str(int(round(valor)))


func _por(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.rect_position = Vector2(x, y)
	c.rect_size = Vector2(w, h)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_visto += delta
	for i in _feixes.size():
		_feixes[i].rotation = sin(_t * (0.5 + i * 0.17) + i * 1.7) * 0.5 + (0.2 if i == 0 else -0.2)
	_dica.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * 4.0))
	if _coroa.visible:
		_coroa.rotation = sin(_t * 2.2) * 0.07


## START joga de novo logo; a CESTA só depois da guarda.
func pode_reiniciar(com_cesta: bool) -> bool:
	return _ativo and _visto >= (GUARDA_CESTA if com_cesta else 1.0)
