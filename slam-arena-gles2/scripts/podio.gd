extends Control

## PÓDIO (resultado da partida): colunas que sobem do menor para o maior,
## pontos contando, coroa desenhada à mão caindo no campeão, holofotes,
## confete e a linha de diferença entre os jogadores. START joga de novo;
## sem nada, volta para a abertura sozinho.

signal acabou(acao)

const Malhas = preload("res://scripts/fx/malhas.gd")
const VOLTA_SEGUNDOS := 12

var _painel: Panel
var _titulo: Label
var _campeao: Label
var _colunas: Array = []
var _coroa: Node2D
var _linha: Node2D
var _rodape: Label
var _dica: Label
var _confete: CPUParticles2D
var _feixes: Array = []
var _novo_recorde: Node2D
var _ativo := false
var _pronto := false
var _t := 0.0
var _token := 0


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
	_painel.rect_position = Vector2(40, 170)
	_painel.rect_size = Vector2(1000, 1530)
	add_child(_painel)
	_titulo = Arte.texto("RESULTADO FINAL", 80, Color(1, 1, 1), 9, Arte.LARANJA)
	_titulo.rect_position = Vector2(40, 200)
	_titulo.rect_size = Vector2(1000, 110)
	add_child(_titulo)
	_campeao = Arte.texto("", 44, Arte.OURO, 6, Color(0.2, 0.08, 0.0))
	_campeao.rect_position = Vector2(40, 310)
	_campeao.rect_size = Vector2(1000, 70)
	add_child(_campeao)
	for i in 4:
		_colunas.append(_coluna())
	_linha = Node2D.new()
	_linha.set_script(load("res://scripts/fx/linha_diferenca.gd"))
	add_child(_linha)
	_coroa = Arte.coroa(Arte.OURO, 1.0)
	_coroa.visible = false
	add_child(_coroa)
	_novo_recorde = Arte.texto_solto("NOVO RECORDE DA ARENA!", 50, Arte.OURO, 7, Color(0.3, 0.1, 0.0))
	_novo_recorde.position = Vector2(540, 1505)
	_novo_recorde.visible = false
	add_child(_novo_recorde)
	_rodape = Arte.texto("", 34, Color(1, 1, 1), 5, Color(0, 0, 0))
	_rodape.rect_position = Vector2(40, 1560)
	_rodape.rect_size = Vector2(1000, 56)
	add_child(_rodape)
	_dica = Arte.texto("START JOGA DE NOVO", 40, Arte.AMBAR, 5, Color(0, 0, 0))
	_dica.rect_position = Vector2(40, 1620)
	_dica.rect_size = Vector2(1000, 60)
	add_child(_dica)
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


func _coluna() -> Dictionary:
	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var lugar := Arte.texto("1º", 46, Arte.OURO, 5, Color(0, 0, 0))
	var nome := Arte.texto("", 30, Color(1, 1, 1), 4, Color(0, 0, 0))
	var pts := Arte.texto("0", 92, Color(1, 1, 1), 9, Arte.LARANJA)
	var txt := Arte.texto("PONTOS", 26, Color(1, 1, 1), 3, Color(0, 0, 0))
	var extra := Arte.texto("", 22, Color(0.85, 0.9, 1.0), 3, Color(0, 0, 0))
	extra.autowrap = true
	for l in [lugar, nome, pts, txt, extra]:
		card.add_child(l)
	return {"card": card, "lugar": lugar, "nome": nome, "pts": pts, "txt": txt, "extra": extra, "valor": 0, "idx": 0}


func aquecer() -> void:
	visible = true
	_confete.emitting = true
	_coroa.visible = true
	_novo_recorde.visible = true


func esconder() -> void:
	_ativo = false
	_pronto = false
	_token += 1
	visible = false
	_confete.emitting = false
	_coroa.visible = false


## pontos/cestas/combos: um por jogador (na ordem em que jogaram).
func mostrar(n: int, pontos: Array, cestas: Array, combos: Array, novo_recorde: bool) -> void:
	_token += 1
	var tk := _token
	_ativo = true
	_pronto = false
	visible = true
	modulate.a = 0.0
	_coroa.visible = false
	_novo_recorde.visible = false
	_linha.modulate.a = 0.0
	_dica.text = "START JOGA DE NOVO"
	_rodape.text = "AGUARDE O RESULTADO..."
	var ordem := []
	for i in n:
		ordem.append(i)
	# do maior para o menor (empate: quem jogou antes)
	for a in ordem.size():
		for b in range(a + 1, ordem.size()):
			if int(pontos[ordem[b]]) > int(pontos[ordem[a]]):
				var tmp = ordem[a]
				ordem[a] = ordem[b]
				ordem[b] = tmp
	var vencedor: int = ordem[0]
	var empate := n > 1 and int(pontos[ordem[0]]) == int(pontos[ordem[1]])
	if n == 1:
		_campeao.text = "VOCÊ FEZ %d PONTOS!" % int(pontos[0])
	elif empate:
		_campeao.text = "EMPATE NO TOPO!"
	else:
		_campeao.text = "CAMPEÃO: JOGADOR %d (%s)" % [vencedor + 1, Arte.NOMES_CORES[vencedor]]
	_campeao.add_color_override("font_color", Arte.CORES_JOGADORES[vencedor] if not empate else Arte.OURO)
	var maior := 1
	for i in n:
		maior = int(max(maior, int(pontos[i])))
	# colunas da esquerda (menor) para a direita (campeão)
	var crescente := ordem.duplicate()
	crescente.invert()
	var largura := 880.0 / max(1, n)
	var gap := 22.0
	var w := largura - gap
	var x0 := 100.0 + (880.0 - largura * n) * 0.5
	var base_y := 1450.0
	var topos := []
	for k in 4:
		var col: Dictionary = _colunas[k]
		var card: Panel = col["card"]
		if k >= n:
			card.visible = false
			continue
		var idx: int = crescente[k]
		var lugar = ordem.find(idx) + 1
		var cor: Color = Arte.CORES_JOGADORES[idx]
		var ratio: float = clamp(float(pontos[idx]) / float(maior), 0.0, 1.0)
		var h: float = lerp(330.0, 900.0, ratio)
		card.visible = true
		card.rect_position = Vector2(x0 + k * largura, base_y - h)
		card.rect_size = Vector2(w, h)
		card.rect_pivot_offset = Vector2(w * 0.5, h)
		card.rect_scale = Vector2(1, 0.05)
		card.modulate.a = 0.0
		var sb = StyleBoxFlat.new()
		sb.set_corner_radius_all(30)
		sb.set_border_width_all(4)
		sb.anti_aliasing = true
		if lugar == 1:
			sb.bg_color = Color(0.12, 0.09, 0.02, 0.94)
			sb.border_color = Arte.OURO
			sb.shadow_color = Color(1.0, 0.78, 0.16, 0.7)
			sb.shadow_size = 34
		else:
			sb.bg_color = Color(cor.r * 0.12, cor.g * 0.12, cor.b * 0.12, 0.9)
			sb.border_color = cor
			sb.shadow_color = Color(cor.r, cor.g, cor.b, 0.35)
			sb.shadow_size = 18
		card.add_stylebox_override("panel", sb)
		var medalhas = [Arte.OURO, Color(0.78, 0.8, 0.86), Color(0.85, 0.52, 0.22), Color(0.6, 0.6, 0.6)]
		_por(col["lugar"], 0, 18, w, 60, "%dº" % lugar)
		col["lugar"].add_color_override("font_color", medalhas[lugar - 1])
		_por(col["nome"], 0, 80, w, 44, "JOGADOR %d" % (idx + 1) if w > 260 else "P%d" % (idx + 1))
		col["nome"].add_color_override("font_color", cor)
		_por(col["pts"], 0, 128, w, 120, "0")
		col["pts"].add_color_override("font_outline_modulate", cor)
		_por(col["txt"], 0, 246, w, 36, "PONTOS")
		_por(col["extra"], 6, 286, w - 12, 70, "%d CESTAS • COMBO %d" % [int(cestas[idx]), int(combos[idx])])
		col["extra"].visible = h > 380
		col["valor"] = int(pontos[idx])
		col["idx"] = idx
		topos.append(Vector2(x0 + k * largura + w * 0.5, base_y - h))
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.4)
	yield(tw, "finished")
	for k in n:
		if tk != _token:
			return
		var col: Dictionary = _colunas[k]
		var card: Panel = col["card"]
		Sons.tocar("sobe", -6.0, 0.8 + k * 0.15)
		var tc = create_tween().set_parallel(true)
		tc.tween_property(card, "modulate:a", 1.0, 0.2)
		tc.tween_property(card, "rect_scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tc.tween_method(self, "_contar", 0.0, float(col["valor"]), 0.62, [col["pts"]]).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		yield(get_tree().create_timer(0.55), "timeout")
	if tk != _token:
		return
	# coroa no campeão
	if not empate:
		var topo: Vector2 = topos[n - 1]
		_coroa.visible = true
		_coroa.position = Vector2(topo.x, -100)
		_coroa.scale = Vector2(1.2, 1.2)
		var tcr := create_tween()
		tcr.tween_property(_coroa, "position:y", topo.y - 56, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		Sons.tocar("recorde", -2.0)
	if n >= 2:
		_linha.call("definir", topos, _valores_crescentes(crescente, pontos))
		var tl := create_tween()
		tl.tween_property(_linha, "modulate:a", 1.0, 0.45)
	_confete.restart()
	_confete.emitting = true
	if novo_recorde:
		_novo_recorde.visible = true
		_novo_recorde.scale = Vector2(0.3, 0.3)
		var tn := create_tween()
		tn.tween_property(_novo_recorde, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	yield(get_tree().create_timer(0.8), "timeout")
	if tk != _token:
		return
	_pronto = true
	var seg := VOLTA_SEGUNDOS
	while seg >= 0:
		if tk != _token:
			return
		_rodape.text = "VOLTA AO MENU EM %d" % seg
		yield(get_tree().create_timer(1.0), "timeout")
		seg -= 1
	if tk == _token:
		emit_signal("acabou", "abertura")


func _valores_crescentes(crescente: Array, pontos: Array) -> Array:
	var v := []
	for idx in crescente:
		v.append(int(pontos[idx]))
	return v


func _contar(valor: float, l: Label) -> void:
	l.text = str(int(round(valor)))


func _por(l: Label, x: float, y: float, w: float, h: float, texto: String) -> void:
	l.rect_position = Vector2(x, y)
	l.rect_size = Vector2(w, h)
	l.text = texto


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	for i in _feixes.size():
		_feixes[i].rotation = sin(_t * (0.5 + i * 0.17) + i * 1.7) * 0.5 + (0.2 if i == 0 else -0.2)
	_dica.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * 4.0))
	if _coroa.visible:
		_coroa.rotation = sin(_t * 2.2) * 0.07


func pode_reiniciar() -> bool:
	return _ativo and _pronto
