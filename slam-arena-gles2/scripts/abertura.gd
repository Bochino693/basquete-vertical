extends "res://scripts/tela_base.gd"

## ABERTURA (tela de espera / atração). Nada fica parado:
##   * o pôster SLAM ARENA "respira", aproxima devagar, um brilho atravessa
##     o letreiro e os raios azuis da arte piscam como relâmpago;
##   * brasas sobem do chão, estrelinhas cintilam no letreiro, dois
##     holofotes varrem a arena;
##   * ciclo de atração: PÔSTER -> COMO JOGAR -> PÔSTER -> RECORDES (e, a
##     cada duas voltas, a APRESENTAÇÃO animada);
##   * START abre a janela de jogadores (1 a 4): SELECT passa, START
##     confirma, segurar SELECT fecha;
##   * modo CRÉDITO: uma ficha por jogador (fichas guardadas no aparelho);
##   * segurar SELECT 4 s = CONFIGURAÇÃO; segurar qualquer botão 10 s =
##     ASSISTENTE DE BOTÕES (se a placa estiver com os botões trocados).

const Malhas = preload("res://scripts/fx/malhas.gd")
const Bola = preload("res://scripts/fx/bola.gd")
const Display7 = preload("res://scripts/fx/display7.gd")

const SEGURAR_CONFIG := 4.0
const SEGURAR_BOTOES := 10000
const SEGURAR_FECHAR := 1.2
const MODAL_OCIOSO := 30.0

var _pivo: Node2D
var _poster: MeshInstance2D
var _mat_poster: ShaderMaterial
var _brasas: CPUParticles2D
var _estrelas: CPUParticles2D
var _feixes: Array = []
var _start: Node2D
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

# modal de jogadores
var _modal: Control
var _modal_painel: Panel
var _modal_brilho: Panel
var _modal_sub: Label
var _cards: Array = []
var _modal_aberto := false
var _modal_pronto := false
var _sel := 0
var _modal_ocioso := 0.0
var _escolhendo := false

var _t := 0.0
var _estado := "poster"
var _estado_t := 0.0
var _voltas := 0
var _proximo_relampago := 3.0
var _relampago := 0.0
var _select_t := 0.0
var _r := RandomNumberGenerator.new()


func _ready() -> void:
	_r.randomize()
	_montar_poster()
	_montar_efeitos()
	_montar_rodape()
	_montar_como_jogar()
	_montar_recordes()
	_montar_segurar()
	_montar_modal()
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
	_start = Arte.texto_solto("PRESSIONE START", 76, Color(1, 1, 1), 9, Arte.LARANJA)
	_start.position = Vector2(540, 1750)
	add_child(_start)
	_info = Arte.texto("", 30, Color(1.0, 0.85, 0.6), 4, Color(0.1, 0.03, 0.0))
	pos(_info, 0, 1820, 1080, 60)
	add_child(_info)
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
		["jogadores", "ESCOLHA DE 1 A 4 JOGADORES\nCADA UM JOGA NA SUA VEZ"],
		["bola", "ACERTE O MÁXIMO DE CESTAS\nANTES DO TEMPO ACABAR"],
		["combo", "CESTAS SEGUIDAS VALEM MAIS\nx2  x3  x4 = SLAM MODE!"],
		["ouro", "PEGUE A BOLA DE OURO\nELA VALE +5 PONTOS"],
		["coroa", "BATA O RECORDE DA ARENA!"],
	]
	for i in linhas.size():
		var y = 520.0 + i * 182.0
		var icone = _icone(linhas[i][0])
		icone.position = Vector2(205, y + 62)
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
		"jogadores":
			for i in 4:
				var d = Arte.sprite_brilho(Arte.CORES_JOGADORES[i], 70.0)
				d.position = Vector2(-54 + i * 36, 0)
				n.add_child(d)
				var miolo = Polygon2D.new()
				miolo.polygon = Malhas.elipse(Vector2(-54 + i * 36, 0), Vector2(14, 14), 20)
				miolo.color = Arte.CORES_JOGADORES[i]
				n.add_child(miolo)
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
		pos_.rect_min_size = Vector2(110, 82)
		linha.add_child(pos_)
		var chip = Panel.new()
		chip.rect_min_size = Vector2(44, 44)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.name = "Chip"
		linha.add_child(chip)
		var pts = Arte.texto("", 50, Color(1, 1, 1), 5, Color(0, 0, 0), Label.ALIGN_RIGHT)
		pts.rect_min_size = Vector2(300, 82)
		pts.name = "Pts"
		linha.add_child(pts)
		var hora = Arte.texto("", 34, Color(0.8, 0.8, 0.9), 3, Color(0, 0, 0), Label.ALIGN_RIGHT)
		hora.rect_min_size = Vector2(250, 82)
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
			var cor: Color = Arte.CORES_JOGADORES[int(item.get("cor", 0)) % 4]
			var sb = StyleBoxFlat.new()
			sb.bg_color = cor
			sb.set_corner_radius_all(22)
			sb.shadow_color = Color(cor.r, cor.g, cor.b, 0.6)
			sb.shadow_size = 8
			chip.add_stylebox_override("panel", sb)
			chip.visible = true
			pts.text = "%d PTS" % int(item.get("pontos", 0))
			hora.text = str(item.get("hora", ""))
			linha.modulate.a = 1.0
		else:
			chip.visible = false
			pts.text = "-"
			hora.text = ""
			linha.modulate.a = 0.35
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


# ------------------------------------------------------------------- modal
func _montar_modal() -> void:
	_modal = Control.new()
	_modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.rect_size = Vector2(1080, 1920)
	_modal.visible = false
	add_child(_modal)
	var escuro := ColorRect.new()
	escuro.color = Color(0.0, 0.0, 0.02, 0.80)
	escuro.rect_size = Vector2(1080, 1920)
	_modal.add_child(escuro)
	_modal_brilho = Panel.new()
	var sbg := StyleBoxFlat.new()
	sbg.bg_color = Color(0, 0, 0, 0)
	sbg.border_color = Arte.LARANJA
	sbg.set_border_width_all(3)
	sbg.set_corner_radius_all(56)
	sbg.shadow_color = Color(1.0, 0.5, 0.1, 0.8)
	sbg.shadow_size = 46
	sbg.anti_aliasing = true
	_modal_brilho.add_stylebox_override("panel", sbg)
	pos(_modal_brilho, 70, 230, 940, 1460)
	_modal.add_child(_modal_brilho)
	_modal_painel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.025, 0.022, 0.05, 0.97)
	sb.border_color = Color(1.0, 0.55, 0.1, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(50)
	sb.anti_aliasing = true
	_modal_painel.add_stylebox_override("panel", sb)
	pos(_modal_painel, 80, 240, 920, 1440)
	_modal.add_child(_modal_painel)
	var titulo := Arte.texto("QUANTOS JOGADORES?", 66, Color(1, 1, 1), 8, Arte.LARANJA)
	pos(titulo, 0, 40, 920, 90)
	_modal_painel.add_child(titulo)
	var linha := ColorRect.new()
	linha.color = Arte.LARANJA
	pos(linha, 160, 138, 600, 4)
	_modal_painel.add_child(linha)
	_modal_sub = Arte.texto("SELECT PASSA  •  START CONFIRMA", 30, Color(1.0, 0.7, 0.35), 3, Color(0, 0, 0))
	pos(_modal_sub, 0, 150, 920, 50)
	_modal_painel.add_child(_modal_sub)
	for n in range(1, 5):
		var card = _card(n)
		pos(card, 50, 240 + (n - 1) * 290, 820, 250)
		card.rect_pivot_offset = Vector2(410, 125)
		_modal_painel.add_child(card)
		_cards.append(card)


func _card(n: int) -> Panel:
	var cor: Color = Arte.CORES_JOGADORES[n - 1]
	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_meta("cor", cor)
	var disco := Panel.new()
	disco.name = "Disco"
	pos(disco, 40, 50, 150, 150)
	card.add_child(disco)
	var num := Arte.texto(str(n), 96, Color(1, 1, 1), 8, cor)
	pos(num, 0, 0, 150, 150)
	disco.add_child(num)
	var txt := Arte.texto("1 JOGADOR" if n == 1 else "%d JOGADORES" % n, 58, Color(1, 1, 1), 6, Color(cor.r * 0.3, cor.g * 0.3, cor.b * 0.3))
	pos(txt, 210, 30, 580, 90)
	card.add_child(txt)
	var bolinhas := Node2D.new()
	bolinhas.position = Vector2(500 - (n - 1) * 24, 145)
	card.add_child(bolinhas)
	for i in n:
		var b = Polygon2D.new()
		b.polygon = Malhas.elipse(Vector2(i * 48, 0), Vector2(15, 15), 16)
		b.color = Arte.CORES_JOGADORES[i]
		bolinhas.add_child(b)
		var g = Arte.sprite_brilho(Arte.CORES_JOGADORES[i], 60.0)
		g.position = Vector2(i * 48, 0)
		bolinhas.add_child(g)
	var nomes := []
	for i in n:
		nomes.append(Arte.NOMES_CORES[i])
	var lbl := Arte.texto(PoolStringArray(nomes).join("  •  "), 26, Color(cor.r, cor.g, cor.b), 3, Color(0, 0, 0))
	pos(lbl, 210, 180, 580, 44)
	card.add_child(lbl)
	_estilo_card(card, false, true)
	return card


func _estilo_card(card: Panel, sel: bool, liberado: bool) -> void:
	var cor: Color = card.get_meta("cor")
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(44)
	sb.anti_aliasing = true
	if sel:
		sb.bg_color = Color(cor.r * 0.36 + 0.04, cor.g * 0.36 + 0.04, cor.b * 0.36 + 0.04, 0.98)
		sb.border_color = Color(1, 1, 1)
		sb.set_border_width_all(5)
		sb.shadow_color = Color(cor.r, cor.g, cor.b, 0.95)
		sb.shadow_size = 40
	else:
		sb.bg_color = Color(cor.r * 0.12, cor.g * 0.12, cor.b * 0.12, 0.92)
		sb.border_color = Color(cor.r, cor.g, cor.b, 0.7)
		sb.set_border_width_all(2)
		sb.shadow_color = Color(cor.r, cor.g, cor.b, 0.3)
		sb.shadow_size = 14
	card.add_stylebox_override("panel", sb)
	var disco: Panel = card.get_node("Disco")
	var sd := StyleBoxFlat.new()
	sd.set_corner_radius_all(75)
	sd.anti_aliasing = true
	sd.bg_color = Color(cor.r * (0.46 if sel else 0.16), cor.g * (0.46 if sel else 0.16), cor.b * (0.46 if sel else 0.16), 0.98)
	sd.border_color = Color(1, 1, 1) if sel else cor
	sd.set_border_width_all(4 if sel else 2)
	sd.shadow_color = Color(cor.r, cor.g, cor.b, 1.0 if sel else 0.4)
	sd.shadow_size = 26 if sel else 10
	disco.add_stylebox_override("panel", sd)
	card.modulate = Color(1, 1, 1, 1.0 if liberado else 0.28)


# ================================================================== ciclo
func entrar(dados := {}) -> void:
	.entrar(dados)
	_t = 0.0
	_estado = "poster"
	_estado_t = 0.0
	_modal.visible = false
	_modal_aberto = false
	_escolhendo = false
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
	_modal.visible = true
	_preencher_recordes()
	_brasas.emitting = true
	_estrelas.emitting = true
	yield(get_tree().create_timer(0.1), "timeout")
	_brasas.preprocess = 0.0
	_como.visible = false
	_como.modulate.a = 0.0
	_recordes.visible = false
	_recordes.modulate.a = 0.0
	_modal.visible = false


func _atualizar_info() -> void:
	if _info == null:
		return
	var partes := []
	if Ajustes.modo_credito:
		partes.append("FICHAS: %d" % Ajustes.creditos)
		partes.append("1 FICHA POR JOGADOR")
	else:
		partes.append("JOGO LIVRE")
	partes.append("RECORDE %d" % Ajustes.recorde)
	if Ajustes.melhor_hoje() > 0:
		partes.append("HOJE %d" % Ajustes.melhor_hoje())
	_info.text = PoolStringArray(partes).join("   •   ")
	var l := Arte.rotulo_de(_start)
	if Ajustes.modo_credito and Ajustes.creditos <= 0:
		l.text = "INSIRA A FICHA"
	else:
		l.text = "PRESSIONE START"


func _process(delta: float) -> void:
	_t += delta
	_animar_poster(delta)
	_animar_rodape()
	_animar_icones()
	if _modal_aberto:
		_processar_modal(delta)
		return
	_ciclo(delta)
	_segurar_botoes(delta)


func _animar_poster(delta: float) -> void:
	var resp := 0.5 + 0.5 * sin(_t * 1.6)
	_mat_poster.set_shader_param("respiro", resp)
	_pivo.scale = Vector2.ONE * (1.0 + 0.028 * (0.5 + 0.5 * sin(_t * 0.23 - 1.57)))
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
	if _start.modulate.a > 0.0 and not _modal_aberto:
		var l := Arte.rotulo_de(_start)
		l.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * 4.2))


func _animar_icones() -> void:
	if not _como.visible:
		return
	for n in _icones_como:
		match n.get_meta("tipo"):
			"bola":
				n.position.y = 520.0 + 182.0 + 62.0 - abs(sin(_t * 3.4)) * 26.0
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
			"jogadores":
				n.scale = Vector2.ONE * (1.0 + 0.05 * sin(_t * 5.0))


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
	p.visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_property(p, "modulate:a", 1.0, 0.35)
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
			tw.tween_property(p, "modulate:a", 0.0, 0.35)
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


# ===================================================================== modal
func _abrir_modal() -> void:
	if _modal_aberto:
		return
	_modal_aberto = true
	_modal_pronto = false
	_modal_ocioso = 0.0
	_escolhendo = false
	if _estado == "painel":
		_esconder_painel()
	Sons.tocar("selecao")
	Arduino.led("MENU_LOCK")
	_modal.visible = true
	_modal.modulate.a = 0.0
	_modal_painel.rect_pivot_offset = _modal_painel.rect_size * 0.5
	_modal_painel.rect_scale = Vector2(0.92, 0.92)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_modal, "modulate:a", 1.0, 0.22)
	tw.tween_property(_modal_painel, "rect_scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var liberados := Ajustes.jogadores_liberados()
	_sel = 0
	for i in _cards.size():
		var c: Panel = _cards[i]
		_estilo_card(c, false, i < liberados)
		c.rect_scale = Vector2(0.7, 0.7)
		var a = c.modulate.a
		c.modulate.a = 0.0
		var tc = create_tween().set_parallel(true)
		tc.tween_property(c, "modulate:a", a, 0.22).set_delay(0.14 + i * 0.08)
		tc.tween_property(c, "rect_scale", Vector2.ONE, 0.34).set_delay(0.14 + i * 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if Ajustes.modo_credito:
		_modal_sub.text = "FICHAS: %d   •   SELECT PASSA   •   START CONFIRMA" % Ajustes.creditos
	else:
		_modal_sub.text = "SELECT PASSA  •  START CONFIRMA"
	var s := sessao
	yield(get_tree().create_timer(0.14 + 4 * 0.08 + 0.34), "timeout")
	if not vale(s) or not _modal_aberto:
		return
	_destacar()
	_modal_pronto = true


func _destacar() -> void:
	var liberados := Ajustes.jogadores_liberados()
	for i in _cards.size():
		var c: Panel = _cards[i]
		var sel = i == _sel
		_estilo_card(c, sel, i < liberados)
		var tw = create_tween()
		tw.tween_property(c, "rect_scale", Vector2.ONE * (1.035 if sel else 1.0), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _navegar() -> void:
	var liberados := int(max(1, Ajustes.jogadores_liberados()))
	_sel = (_sel + 1) % liberados
	_modal_ocioso = 0.0
	Sons.tocar("cursor", -4.0)
	Arduino.led("SELECT%d" % (_sel + 1))
	_destacar()


func _fechar_modal() -> void:
	_modal_pronto = false
	var tw := create_tween()
	tw.tween_property(_modal, "modulate:a", 0.0, 0.2)
	tw.tween_callback(_modal, "set_visible", [false])
	_modal_aberto = false
	_select_t = 0.0
	Arduino.led("ATTRACT")


func _processar_modal(delta: float) -> void:
	_modal_brilho.modulate.a = 0.6 + 0.4 * (0.5 + 0.5 * sin(_t * 5.5))
	if not _modal_pronto:
		return
	_modal_ocioso += delta
	if _modal_ocioso > MODAL_OCIOSO:
		_fechar_modal()
		return
	if Controles.segurando("input_select"):
		_select_t += delta
		if _select_t >= SEGURAR_FECHAR:
			Sons.tocar("selecao", -4.0)
			_fechar_modal()
	else:
		_select_t = 0.0


func _confirmar() -> void:
	if _escolhendo:
		return
	var n := _sel + 1
	if n > Ajustes.jogadores_liberados():
		Sons.tocar("quebra")
		return
	_escolhendo = true
	_modal_pronto = false
	Sons.tocar("selecao")
	Arduino.led("STARTING")
	Ajustes.gastar_creditos(n)
	for i in _cards.size():
		var c: Panel = _cards[i]
		var tw = create_tween().set_parallel(true)
		if i == _sel:
			tw.tween_property(c, "rect_scale", Vector2(1.08, 1.08), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			tw.tween_property(c, "modulate:a", 0.0, 0.16)
			tw.tween_property(c, "rect_scale", Vector2(0.92, 0.92), 0.16)
	var s := sessao
	yield(get_tree().create_timer(0.45), "timeout")
	if not vale(s):
		return
	ir("jogo", {"jogadores": n})


# ===================================================================== botões
func _unhandled_input(event: InputEvent) -> void:
	if not ativo:
		return
	if Controles.credito(event):
		Ajustes.adicionar_credito(1)
		Sons.tocar("moeda")
		_fichas_pop.modulate.a = 1.0
		_fichas_pop.position = Vector2(540, 1640)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_fichas_pop, "position:y", 1540.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(_fichas_pop, "modulate:a", 0.0, 0.9).set_delay(0.3)
		_atualizar_info()
		if _modal_aberto:
			_modal_sub.text = "FICHAS: %d   •   SELECT PASSA   •   START CONFIRMA" % Ajustes.creditos
			_destacar()
		return
	if Controles.config(event) or (event is InputEventKey and event.pressed and not event.echo and event.scancode == KEY_F10):
		ir("config", {})
		return
	if _modal_aberto:
		if not _modal_pronto:
			return
		if Controles.select(event):
			_navegar()
		elif Controles.start(event):
			_confirmar()
		return
	if Controles.start(event):
		if Ajustes.jogadores_liberados() <= 0:
			Sons.tocar("quebra")
			pop(_start, 1.25)
			return
		_abrir_modal()
