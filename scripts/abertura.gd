extends "res://scripts/tela_base.gd"

## ABERTURA (tela de espera / atração). Nada fica parado:
##   * o pôster SLAM ARENA "respira", aproxima devagar, um brilho atravessa
##     o letreiro e os raios azuis da arte piscam como relâmpago;
##   * brasas sobem do chão, estrelinhas cintilam no letreiro, dois
##     holofotes varrem a arena;
##   * ciclo de atração: PÔSTER -> COMO JOGAR -> PÔSTER -> RECORDES (e, a
##     cada duas voltas, a APRESENTAÇÃO animada);
##   * NENHUM BOTÃO: a primeira CESTA já começa a partida (START também,
##     para o operador);
##   * modo CRÉDITO: uma ficha por partida (fichas guardadas no aparelho);
##   * segurar SELECT 4 s = CONFIGURAÇÃO; segurar qualquer botão 10 s =
##     ASSISTENTE DE BOTÕES (se a placa estiver com os botões trocados).

const Malhas = preload("res://scripts/fx/malhas.gd")
const Bola = preload("res://scripts/fx/bola.gd")
const Display7 = preload("res://scripts/fx/display7.gd")

const SEGURAR_CONFIG := 4.0
const SEGURAR_BOTOES := 10000
const CORES_FASE := [Color(1.0, 0.46, 0.04), Color(0.25, 0.62, 1.0), Color(1.0, 0.80, 0.12)]

var _pivo: Node2D
var _poster: MeshInstance2D
var _mat_poster: ShaderMaterial
var _brasas: CPUParticles2D
var _estrelas: CPUParticles2D
var _feixes: Array = []
var _start: Node2D
var _start_sub: Label
var _bolas: Array = []
var _info: Label
var _fichas_pop: Node2D
var _como: Control
var _recordes: Control
var _rec_display: Display7
var _rec_data: Label
var _rec_lista: VBoxContainer
var _rec_rodape: Label
var _icones_como: Array = []
var _segurar: Node2D
var _segurar_texto: Label

var _t := 0.0
var _estado := "poster"
var _estado_t := 0.0
var _voltas := 0
var _proximo_relampago := 3.0
var _relampago := 0.0
var _select_t := 0.0
var _comecando := false
var _zoom := 0.0
var _r := RandomNumberGenerator.new()


func _ready() -> void:
	_r.randomize()
	_montar_poster()
	_montar_efeitos()
	_montar_rodape()
	_montar_como_jogar()
	_montar_recordes()
	_montar_segurar()
	Ajustes.connect("mudou", self, "_atualizar_info")


# =================================================================== montar
func _montar_poster() -> void:
	_pivo = Node2D.new()
	_pivo.position = Vector2(540, 960)
	add_child(_pivo)
	_poster = MeshInstance2D.new()
	_poster.mesh = Malhas.tela(Rect2(0, 0, 1080, 1920), 12, 22)
	_poster.texture = load("res://imagens/poster.png")
	_mat_poster = Arte.material("res://shaders/poster.shader")
	_poster.material = _mat_poster
	_poster.position = Vector2(-540, -960)
	_pivo.add_child(_poster)


func _montar_efeitos() -> void:
	# holofotes (cones de luz) que varrem a arena
	for i in 2:
		var f = Sprite.new()
		f.texture = Arte.tex_feixe
		f.material = Arte.mat_aditivo
		f.centered = false
		f.offset = Vector2(-32, 0)
		f.scale = Vector2(9.0, 15.0)
		f.position = Vector2(140 if i == 0 else 940, -40)
		f.modulate = Color(1.0, 0.7, 0.35, 0.13) if i == 0 else Color(0.4, 0.7, 1.0, 0.13)
		add_child(f)
		_feixes.append(f)
	# brasas subindo do chão
	_brasas = CPUParticles2D.new()
	_brasas.amount = 70
	_brasas.lifetime = 6.0
	# (a pré-simulação de 6 s só na preparação: ao voltar para a abertura
	# ela pesaria num quadro só)
	_brasas.preprocess = 6.0
	_brasas.texture = Arte.tex_brilho
	_brasas.material = Arte.mat_aditivo
	_brasas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_brasas.emission_rect_extents = Vector2(560, 10)
	_brasas.position = Vector2(540, 1940)
	_brasas.direction = Vector2(0, -1)
	_brasas.spread = 18.0
	_brasas.gravity = Vector2(0, -12)
	_brasas.initial_velocity = 150.0
	_brasas.initial_velocity_random = 0.6
	_brasas.tangential_accel = 12.0
	_brasas.tangential_accel_random = 1.0
	_brasas.scale_amount = 0.22
	_brasas.scale_amount_random = 0.8
	_brasas.color_ramp = Arte.rampa([Color(1.0, 0.6, 0.2, 0.0), Color(1.0, 0.75, 0.35, 0.95), Color(1.0, 0.4, 0.05, 0.6), Color(0.3, 0.6, 1.0, 0.0)], [0.0, 0.15, 0.6, 1.0])
	add_child(_brasas)
	# estrelinhas cintilando no letreiro
	_estrelas = CPUParticles2D.new()
	_estrelas.amount = 5
	_estrelas.lifetime = 1.3
	_estrelas.texture = Arte.tex_estrela
	_estrelas.material = Arte.mat_aditivo
	_estrelas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_estrelas.emission_rect_extents = Vector2(380, 210)
	_estrelas.position = Vector2(540, 1180)
	_estrelas.gravity = Vector2.ZERO
	_estrelas.initial_velocity = 0.0
	_estrelas.angular_velocity = 90.0
	_estrelas.scale_amount = 1.1
	_estrelas.scale_amount_random = 0.7
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0))
	curva.add_point(Vector2(0.35, 1))
	curva.add_point(Vector2(1, 0))
	_estrelas.scale_amount_curve = curva
	_estrelas.color = Color(1.0, 0.92, 0.7)
	add_child(_estrelas)


func _montar_rodape() -> void:
	# faixa escura embaixo (o texto fica legível em cima do chão brilhante)
	var faixa := Polygon2D.new()
	faixa.polygon = PoolVector2Array([Vector2(0, 1520), Vector2(1080, 1520), Vector2(1080, 1660), Vector2(0, 1660),
		Vector2(0, 1920), Vector2(1080, 1920)])
	var escuro := Color(0.02, 0.01, 0.04, 0.96)
	faixa.vertex_colors = PoolColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), escuro, escuro, escuro, escuro])
	faixa.polygons = [PoolIntArray([0, 1, 2, 3]), PoolIntArray([3, 2, 5, 4])]
	add_child(faixa)
	_start = Arte.texto_solto("ACERTE A CESTA!", 84, Color(1, 1, 1), 9, Arte.LARANJA)
	_start.position = Vector2(540, 1716)
	add_child(_start)
	_start_sub = Arte.texto("PARA COMEÇAR A JOGAR", 32, Arte.LARANJA_CLARO, 4, Color(0.1, 0.03, 0.0))
	pos(_start_sub, 0, 1772, 1080, 50)
	add_child(_start_sub)
	_info = Arte.texto("", 28, Color(1.0, 0.85, 0.6), 4, Color(0.1, 0.03, 0.0))
	pos(_info, 0, 1836, 1080, 56)
	add_child(_info)
	# duas bolas quicando dos lados da chamada
	for i in 2:
		var b := Bola.new()
		b.tamanho(70)
		b.velocidade = 4.0 if i == 0 else -4.0
		b.position = Vector2(70 if i == 0 else 1010, 1716)
		add_child(b)
		_bolas.append(b)
	_fichas_pop = Arte.texto_solto("+1 FICHA", 64, Arte.OURO, 8, Color(0.3, 0.12, 0.0))
	_fichas_pop.position = Vector2(540, 1600)
	_fichas_pop.modulate.a = 0.0
	add_child(_fichas_pop)


func _montar_como_jogar() -> void:
	_como = Control.new()
	_como.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_como.rect_size = Vector2(1080, 1920)
	_como.modulate.a = 0.0
	_como.visible = false
	add_child(_como)
	var p := Arte.painel(Arte.LARANJA, 0.86, 40, 3, 26)
	pos(p, 70, 330, 940, 1150)
	_como.add_child(p)
	var titulo := Arte.texto("COMO JOGAR", 84, Color(1, 1, 1), 9, Arte.LARANJA)
	pos(titulo, 70, 360, 940, 110)
	_como.add_child(titulo)
	var linhas := [
		["bola", "ACERTE A CESTA PARA COMEÇAR\nNÃO PRECISA APERTAR NADA"],
		["fases", "3 FASES: BATA A META\nPARA CHEGAR NA FINAL"],
		["combo", "CESTAS SEGUIDAS VALEM MAIS\nx2  x3  x4 = MODO ENTERRADA!"],
		["ouro", "PEGUE A BOLA DE OURO\nELA VALE +5 PONTOS"],
		["coroa", "BATA O RECORDE DA ARENA!"],
	]
	for i in linhas.size():
		var y = 520.0 + i * 182.0
		var icone = _icone(linhas[i][0])
		icone.position = Vector2(205, y + 62)
		icone.set_meta("y0", y + 62)
		_como.add_child(icone)
		_icones_como.append(icone)
		var l = Arte.texto(linhas[i][1], 34, Color(1, 1, 1), 4, Color(0.15, 0.05, 0.0), Label.ALIGN_LEFT)
		pos(l, 300, y, 680, 124)
		_como.add_child(l)


## Os ícones da explicação, desenhados à mão e mexendo.
func _icone(tipo: String) -> Node2D:
	var n := Node2D.new()
	n.set_meta("tipo", tipo)
	match tipo:
		"fases":
			# três degraus (FASE 1, FASE 2, FINAL) que acendem em sequência
			for i in 3:
				var h = 34.0 + i * 26.0
				var d = Arte.sprite_brilho(CORES_FASE[i], 90.0)
				d.position = Vector2(-44 + i * 44, 40 - h * 0.5)
				d.name = "B%d" % i
				n.add_child(d)
				var degrau = Polygon2D.new()
				degrau.polygon = PoolVector2Array([Vector2(-60 + i * 44, 40 - h), Vector2(-28 + i * 44, 40 - h),
					Vector2(-28 + i * 44, 40), Vector2(-60 + i * 44, 40)])
				degrau.color = CORES_FASE[i]
				degrau.name = "D%d" % i
				n.add_child(degrau)
		"bola":
			var b := Bola.new()
			b.tamanho(96)
			n.add_child(b)
		"combo":
			var t := Arte.texto_solto("x2", 70, Arte.LARANJA_CLARO, 8, Arte.LARANJA, 200)
			t.name = "X"
			n.add_child(t)
		"ouro":
			var g := Arte.sprite_brilho(Arte.OURO, 170.0)
			n.add_child(g)
			var b := Bola.new()
			b.tamanho(92)
			b.ouro(1.0)
			n.add_child(b)
		"coroa":
			n.add_child(Arte.coroa(Arte.OURO, 1.2))
	return n


func _montar_recordes() -> void:
	_recordes = Control.new()
	_recordes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recordes.rect_size = Vector2(1080, 1920)
	_recordes.modulate.a = 0.0
	_recordes.visible = false
	add_child(_recordes)
	var p := Arte.painel(Arte.OURO, 0.88, 40, 3, 28)
	pos(p, 70, 300, 940, 1210)
	_recordes.add_child(p)
	var titulo := Arte.texto("RECORDE DA ARENA", 70, Color(1, 1, 1), 8, Arte.AMBAR)
	pos(titulo, 70, 330, 940, 100)
	_recordes.add_child(titulo)
	var coroa := Arte.coroa(Arte.OURO, 0.9)
	coroa.position = Vector2(540, 470)
	coroa.name = "Coroa"
	_recordes.add_child(coroa)
	_rec_display = Display7.new()
	_rec_display.configurar(4, 170, Arte.OURO)
	_rec_display.position = Vector2(540, 640)
	_recordes.add_child(_rec_display)
	_rec_data = Arte.texto("", 30, Color(1.0, 0.85, 0.5), 3, Color(0, 0, 0))
	pos(_rec_data, 70, 735, 940, 50)
	_recordes.add_child(_rec_data)
	var sub := Arte.texto("MELHORES DE HOJE", 52, Color(1, 1, 1), 6, Arte.LARANJA)
	pos(sub, 70, 810, 940, 80)
	_recordes.add_child(sub)
	_rec_lista = VBoxContainer.new()
	_rec_lista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rec_lista.add_constant_override("separation", 12)
	pos(_rec_lista, 130, 910, 820, 470)
	_recordes.add_child(_rec_lista)
	for i in 5:
		var linha = HBoxContainer.new()
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		linha.rect_min_size = Vector2(820, 82)
		linha.add_constant_override("separation", 20)
		var pos_ = Arte.texto("%dº" % (i + 1), 46, Arte.OURO if i == 0 else Color(1, 1, 1), 5, Color(0, 0, 0))
		pos_.rect_min_size = Vector2(100, 82)
		linha.add_child(pos_)
		# até onde chegou (FASE 1, FASE 2, FINAL)
		var chip = Panel.new()
		chip.rect_min_size = Vector2(160, 56)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.name = "Chip"
		var ct = Arte.texto("", 26, Color(1, 1, 1), 3, Color(0, 0, 0))
		ct.name = "T"
		ct.rect_size = Vector2(160, 56)
		chip.add_child(ct)
		linha.add_child(chip)
		var pts = Arte.texto("", 50, Color(1, 1, 1), 5, Color(0, 0, 0), Label.ALIGN_RIGHT)
		pts.rect_min_size = Vector2(300, 82)
		pts.name = "Pts"
		linha.add_child(pts)
		var hora = Arte.texto("", 34, Color(0.8, 0.8, 0.9), 3, Color(0, 0, 0), Label.ALIGN_RIGHT)
		hora.rect_min_size = Vector2(200, 82)
		hora.name = "Hora"
		linha.add_child(hora)
		_rec_lista.add_child(linha)
	_rec_rodape = Arte.texto("", 32, Color(1.0, 0.85, 0.6), 4, Color(0, 0, 0))
	_rec_rodape.autowrap = true
	pos(_rec_rodape, 90, 1390, 900, 100)
	_recordes.add_child(_rec_rodape)


func _preencher_recordes() -> void:
	_rec_display.valor = Ajustes.recorde
	_rec_data.text = ("BATIDO EM " + _data_br(Ajustes.recorde_data)) if Ajustes.recorde_data != "" else "AINDA NINGUÉM BATEU"
	var lista: Array = Ajustes.ranking_dia
	for i in 5:
		var linha: HBoxContainer = _rec_lista.get_child(i)
		var chip: Panel = linha.get_node("Chip")
		var pts: Label = linha.get_node("Pts")
		var hora: Label = linha.get_node("Hora")
		if i < lista.size():
			var item: Dictionary = lista[i]
			var f := int(clamp(int(item.get("fase", 1)), 1, 3))
			var cor: Color = CORES_FASE[f - 1]
			chip.add_stylebox_override("panel", Arte.estilo_neon(cor, 0.9, 26, 2, 8, 0.25))
			chip.get_node("T").text = Ajustes.NOMES_FASE[f - 1]
			chip.visible = true
			pts.text = "%d PTS" % int(item.get("pontos", 0))
			hora.text = str(item.get("hora", ""))
			tom(linha, 1.0)
		else:
			chip.visible = false
			pts.text = "-"
			hora.text = ""
			tom(linha, 0.4)
	if lista.empty():
		_rec_rodape.text = "NINGUÉM JOGOU HOJE AINDA: SEJA O PRIMEIRO!"
	else:
		_rec_rodape.text = "PARTIDAS HOJE: %d   •   CESTAS HOJE: %d" % [Ajustes.partidas_hoje, Ajustes.cestas_hoje]


static func _data_br(d: String) -> String:
	var p := d.split("-")
	if p.size() != 3:
		return d
	return "%s/%s/%s" % [p[2], p[1], p[0]]


func _montar_segurar() -> void:
	_segurar = Node2D.new()
	_segurar.position = Vector2(540, 1580)
	_segurar.visible = false
	_segurar.set_script(load("res://scripts/fx/anel_progresso.gd"))
	add_child(_segurar)
	_segurar_texto = Arte.texto("", 32, Color(1, 1, 1), 4, Color(0, 0, 0))
	pos(_segurar_texto, 0, 1470, 1080, 50)
	_segurar_texto.visible = false
	add_child(_segurar_texto)


# ================================================================== ciclo
func entrar(dados := {}) -> void:
	.entrar(dados)
	_t = 0.0
	_estado = "poster"
	_estado_t = 0.0
	_comecando = false
	_zoom = 0.0
	_select_t = 0.0
	_como.visible = false
	_recordes.visible = false
	_mat_poster.set_shader_param("escurecer", 0.0)
	_brasas.emitting = true
	_estrelas.emitting = true
	_segurar.visible = false
	_segurar_texto.visible = false
	Controles.esquecer_segurados()
	Sons.musica("abertura")
	Arduino.led("ATTRACT")
	Arduino.janelas_ok = true
	Tela.medir(false)
	_atualizar_info()
	if not dados.get("da_apresentacao", false):
		neon_liga(_start, 0.3)


func sair() -> void:
	.sair()
	Arduino.janelas_ok = false
	_brasas.emitting = false
	_estrelas.emitting = false


func aquecer() -> void:
	_como.visible = true
	_como.modulate.a = 1.0
	_recordes.visible = true
	_recordes.modulate.a = 1.0
	_preencher_recordes()
	_brasas.emitting = true
	_estrelas.emitting = true
	yield(get_tree().create_timer(0.1), "timeout")
	_brasas.preprocess = 0.0
	_como.visible = false
	_como.modulate.a = 0.0
	_recordes.visible = false
	_recordes.modulate.a = 0.0


func _atualizar_info() -> void:
	if _info == null:
		return
	var partes := []
	if Ajustes.modo_credito:
		partes.append("FICHAS: %d" % Ajustes.creditos)
		partes.append("1 FICHA POR PARTIDA")
	else:
		partes.append("JOGO LIVRE")
	partes.append("RECORDE %d" % Ajustes.recorde)
	if Ajustes.melhor_hoje() > 0:
		partes.append("HOJE %d" % Ajustes.melhor_hoje())
	_info.text = PoolStringArray(partes).join("   •   ")
	var l := Arte.rotulo_de(_start)
	if not Ajustes.pode_jogar():
		l.text = "INSIRA A FICHA"
		_start_sub.text = "1 FICHA POR PARTIDA  •  DEPOIS É SÓ ACERTAR A CESTA"
	else:
		l.text = "ACERTE A CESTA!"
		_start_sub.text = "PARA COMEÇAR A JOGAR"


func _process(delta: float) -> void:
	_t += delta
	_animar_poster(delta)
	_animar_rodape()
	_animar_icones()
	if _comecando:
		return
	_ciclo(delta)
	_segurar_botoes(delta)


func _animar_poster(delta: float) -> void:
	var resp := 0.5 + 0.5 * sin(_t * 1.6)
	_mat_poster.set_shader_param("respiro", resp)
	_pivo.scale = Vector2.ONE * (1.0 + _zoom + 0.028 * (0.5 + 0.5 * sin(_t * 0.23 - 1.57)))
	# brilho que atravessa o letreiro (a cada 5,5 s)
	var ciclo := fmod(_t, 5.5)
	_mat_poster.set_shader_param("brilho_pos", lerp(-300.0, 2500.0, ciclo / 1.7) if ciclo < 1.7 else -2000.0)
	_mat_poster.set_shader_param("brilho_forca", 0.9)
	# relâmpago (duas piscadas) de tempos em tempos
	_proximo_relampago -= delta
	if _proximo_relampago <= 0.0:
		_proximo_relampago = _r.randf_range(3.0, 7.0)
		_relampago = 0.0
	_relampago += delta
	var flash := 0.0
	if _relampago < 0.06:
		flash = 1.0
	elif _relampago < 0.12:
		flash = 0.15
	elif _relampago < 0.2:
		flash = 0.8
	elif _relampago < 0.45:
		flash = 0.8 * (1.0 - (_relampago - 0.2) / 0.25)
	_mat_poster.set_shader_param("relampago", flash)
	# holofotes
	for i in _feixes.size():
		var f: Sprite = _feixes[i]
		f.rotation = sin(_t * (0.35 + i * 0.12) + i * 2.0) * 0.55 + (0.25 if i == 0 else -0.25)


func _animar_rodape() -> void:
	var s := 1.0 + 0.06 * (0.5 + 0.5 * sin(_t * 4.2))
	_start.scale = Vector2(s, s)
	if _start.modulate.a > 0.0 and not _comecando:
		var l := Arte.rotulo_de(_start)
		tom(l, 0.82 + 0.18 * (0.5 + 0.5 * sin(_t * 4.2)))
	for i in _bolas.size():
		var b: Node2D = _bolas[i]
		b.position.y = 1734.0 - abs(sin(_t * 3.6 + i * 1.57)) * 46.0


func _animar_icones() -> void:
	if not _como.visible:
		return
	for n in _icones_como:
		match n.get_meta("tipo"):
			"bola":
				n.position.y = float(n.get_meta("y0")) - abs(sin(_t * 3.4)) * 26.0
			"combo":
				var x: Node2D = n.get_node("X")
				var nivel = int(fmod(_t * 1.2, 3.0)) + 2
				var l = Arte.rotulo_de(x)
				var txt = "x%d" % nivel
				if l.text != txt:
					l.text = txt
					pop(x, 1.3)
			"coroa":
				n.rotation = sin(_t * 2.0) * 0.08
			"fases":
				# os degraus acendem um por um (0, 1, 2, todos)
				var passo = int(fmod(_t * 2.0, 4.0))
				for i in 3:
					var aceso = passo == 3 or i <= passo
					n.get_node("D%d" % i).modulate.a = 1.0 if aceso else 0.25
					n.get_node("B%d" % i).visible = aceso and (passo == 3 or i == passo)


func _ciclo(delta: float) -> void:
	_estado_t += delta
	match _estado:
		"poster":
			if _estado_t > 9.0:
				_voltas += 1
				if _voltas % 4 == 0 and Ajustes.apresentacao:
					ir("apresentacao", {})
					return
				_mostrar_painel(_como if _voltas % 2 == 1 else _recordes)
		"painel":
			if _estado_t > 8.0:
				_esconder_painel()


func _mostrar_painel(p: Control) -> void:
	_estado = "painel"
	_estado_t = 0.0
	if p == _recordes:
		_preencher_recordes()
	# o painel entra subindo (sem ficar transparente)
	p.visible = true
	p.modulate.a = 1.0
	p.rect_position.y = ALTURA
	var tw := create_tween().set_parallel(true)
	tw.tween_property(p, "rect_position:y", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(self, "_escurecer", 0.0, 1.0, 0.35)
	Sons.tocar("vento", -8.0)
	if p == _recordes:
		var coroa: Node2D = _recordes.get_node("Coroa")
		coroa.scale = Vector2(0.2, 0.2)
		var tc := create_tween()
		tc.tween_property(coroa, "scale", Vector2(0.9, 0.9), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _esconder_painel() -> void:
	_estado = "poster"
	_estado_t = 0.0
	for p in [_como, _recordes]:
		if p.visible:
			var tw = create_tween().set_parallel(true)
			tw.tween_property(p, "rect_position:y", -ALTURA, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tw.tween_method(self, "_escurecer", 1.0, 0.0, 0.35)
			tw.chain().tween_callback(p, "set_visible", [false])


func _escurecer(v: float) -> void:
	_mat_poster.set_shader_param("escurecer", v)


# --------------------------------------------------- segurar = operador
func _segurar_botoes(delta: float) -> void:
	if Controles.segurando("input_select"):
		_select_t += delta
	else:
		_select_t = 0.0
	var tudo := Controles.maior_tempo_segurado()
	if tudo >= SEGURAR_BOTOES:
		Controles.esquecer_segurados()
		ir("botoes", {})
		return
	if _select_t >= SEGURAR_CONFIG:
		_select_t = 0.0
		Controles.esquecer_segurados()
		ir("config", {})
		return
	var mostrar := _select_t > 0.6 or tudo > 4500
	_segurar.visible = mostrar
	_segurar_texto.visible = mostrar
	if mostrar:
		if _select_t > 0.6:
			_segurar.set("progresso", _select_t / SEGURAR_CONFIG)
			_segurar_texto.text = "CONFIGURAÇÃO..."
		else:
			_segurar.set("progresso", float(tudo) / SEGURAR_BOTOES)
			_segurar_texto.text = "ASSISTENTE DE BOTÕES..."


# ===================================================================== botões
func _unhandled_input(event: InputEvent) -> void:
	if not ativo:
		return
	if Controles.credito(event):
		Ajustes.adicionar_credito(1)
		Sons.tocar("moeda")
		_fichas_pop.modulate.a = 1.0
		_fichas_pop.scale = Vector2.ONE
		_fichas_pop.position = Vector2(540, 1640)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_fichas_pop, "position:y", 1540.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(_fichas_pop, "scale", Vector2.ZERO, 0.2).set_delay(0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		_atualizar_info()
		return
	# R2 da Zero Delay, ou MENU / VOLTAR / seta do controle remoto da TV Box
	if Controles.config(event) or Controles.pede_config(event):
		Controles.esquecer_segurados()
		ir("config", {})
		return
	if Controles.cesta(event) or Controles.start(event):
		_comecar()


## A cesta (ou START) começa a partida: a arte pisca como relâmpago, a
## chamada vira "VAMOS JOGAR!" e a arena entra.
func _comecar() -> void:
	if _comecando:
		return
	if not Ajustes.pode_jogar():
		Sons.tocar("quebra")
		pop(_start, 1.25)
		return
	_comecando = true
	Ajustes.gastar_credito()
	Controles.esquecer_segurados()
	if _estado == "painel":
		_esconder_painel()
	Sons.tocar("swish")
	Sons.tocar("selecao", -2.0)
	Arduino.led("STARTING")
	_proximo_relampago = 0.0
	var l := Arte.rotulo_de(_start)
	l.text = "VAMOS JOGAR!"
	l.modulate.a = 1.0
	pop(_start, 1.35, 0.3)
	var tw := create_tween()
	tw.tween_property(self, "_zoom", 0.09, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	var s := sessao
	yield(get_tree().create_timer(0.45), "timeout")
	if vale(s):
		ir("jogo", {})
