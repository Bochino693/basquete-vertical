extends "res://scripts/tela_base.gd"

## A PARTIDA: 1 a 4 jogadores, um de cada vez, cada um com o seu tempo.
##
##   * CESTA = sinal do sensor (input_cesta), com a trava do operador
##     (tempo mínimo entre duas cestas) e o sensor tendo de soltar.
##   * COMBO: cestas seguidas (menos de "janela do combo" entre elas).
##     No modo ARCADE o combo multiplica os pontos: 3 seguidas = x2,
##     6 = x3, 10 = x4 = SLAM MODE (arena azul elétrica, raios caindo).
##   * BOLA DE OURO (modo arcade): aparece 1 ou 2 vezes por turno, por 6 s;
##     a cesta nesse tempo vale +5.
##   * RECORDE DA ARENA: bateu, a arena inteira vira festa (grade em ondas
##     douradas sem fim, LED "RECORD").
##   * Os últimos 10 segundos: anel vermelho piscando, tique a cada
##     segundo, coração nos 5 finais.
##   * Jogadores 2 a 4: a meta é passar o LÍDER (aviso quando passa).
##   * Fim: pódio (podio.gd).
## Tudo o que aparece já existe (montado na preparação): na partida só se
## mexe em parâmetros, posições e transparência.

const Malhas = preload("res://scripts/fx/malhas.gd")
const Display7 = preload("res://scripts/fx/display7.gd")
const Grade = preload("res://scripts/fx/grade.gd")
const OndaLuz = preload("res://scripts/fx/onda_luz.gd")
const AnelCrono = preload("res://scripts/fx/anel_crono.gd")
const Barras = preload("res://scripts/fx/barras.gd")
const Raio = preload("res://scripts/fx/raio_eletrico.gd")
const Bola = preload("res://scripts/fx/bola.gd")
const Podio = preload("res://scripts/podio.gd")

enum { ENTRADA, ORDEM, CONTAGEM, JOGANDO, FIM_TURNO, PODIO }

# medidas da arte (fundo_jogo.png 941 x 1672, ampliada para 1080 x 1920)
const ANEL := Vector2(539.4, 299.0)
const CESTA := Vector2(540.0, 776.0)
const BOLA_OURO := Vector2(540.0, 1010.0)
const AUTO_INICIO := 45.0

var estado := ENTRADA
var n_jogadores := 1
var vez := 0
var pontos := [0, 0, 0, 0]
var cestas := [0, 0, 0, 0]
var combos := [0, 0, 0, 0]
var terminou := [false, false, false, false]

var _tempo := 60.0              # que resta
var _total := 60.0
var _decorrido := 0.0
var _ultima_cesta := -100.0
var _combo := 0
var _mult := 1
var _slam := false
var _recorde_no_turno := false
var _recorde_na_partida := false
var _passou_lider := false
var _segundo_mostrado := -1
var _ouro_em: Array = []
var _ouro_ativo := false
var _ouro_resta := 0.0
var _ordem_t := 0.0
var _ordem_pronta := false
var _select_t := 0.0
var _tremor := 0.0
var _t := 0.0
var _proximo_raio := 0.0
var _r := RandomNumberGenerator.new()
var _onda_proxima := 0
var _faisca_proxima := 0
var _flutua_proximo := 0
var _alerta := false

# nós
var _mundo: Node2D
var _fundo: MeshInstance2D
var _mat_fundo: ShaderMaterial
var _grade: Grade
var _barras: Array = []
var _ondas: Array = []
var _anel: AnelCrono
var _crono: Display7
var _hud: Control
var _disp_high: Display7
var _disp_pass: Display7
var _disp_atual: Display7
var _lbl_pass: Label
var _lista_players: VBoxContainer
var _mult_lbl: Node2D
var _mult_barra: ColorRect
var _mult_titulo: Label
var _nome_vez: Label
var _sub_vez: Label
var _cards: Array = []
var _bola_card: Bola
var _ouro: Node2D
var _ouro_bola: Bola
var _ouro_anel: Node2D
var _ouro_txt: Node2D
var _faiscas: Array = []
var _faiscas_ouro: CPUParticles2D
var _flutuantes: Array = []
var _combo_banner: Node2D
var _banner: Node2D
var _banner_painel: Panel
var _banner_txt: Label
var _banner_tw: SceneTreeTween
var _combo_tw: SceneTreeTween
var _borda: Panel
var _raios: Array = []
var _escuro: ColorRect
var _contagem: Node2D
var _ordem: Control
var _ordem_titulo: Label
var _ordem_nome: Label
var _ordem_info: Label
var _ordem_start: Label
var _ordem_cards: Array = []
var _entrada: Control
var _entrada_bola: Bola
var _entrada_barra: ColorRect
var _podio: Podio


func _ready() -> void:
	_r.randomize()
	_mundo = Node2D.new()
	add_child(_mundo)
	_montar_fundo()
	_montar_hud()
	_montar_efeitos()
	_montar_ordem()
	_montar_entrada()
	_podio = Podio.new()
	add_child(_podio)
	_podio.connect("acabou", self, "_podio_acabou")


# ==================================================================== montar
func _montar_fundo() -> void:
	_fundo = MeshInstance2D.new()
	_fundo.mesh = Malhas.tela(Rect2(0, 0, LARGURA, ALTURA), 24, 42)
	_fundo.texture = load("res://imagens/fundo_jogo.png")
	_mat_fundo = Arte.material("res://shaders/fundo_vivo.shader")
	_fundo.material = _mat_fundo
	_mundo.add_child(_fundo)
	# equalizador nas "asas" da arena
	for lado in 2:
		var b = Barras.new()
		var x0 = 78.0 if lado == 0 else 838.0
		b.montar(Vector2(x0, 452), 8, 14.0, 8.0, 108.0, 7 + lado)
		b.cores(Color(1.0, 0.32, 0.02), Color(1.0, 0.85, 0.4))
		_mundo.add_child(b)
		_barras.append(b)
	_grade = Grade.new()
	_mundo.add_child(_grade)
	for i in 4:
		var o = OndaLuz.new()
		_mundo.add_child(o)
		_ondas.append(o)
	_anel = AnelCrono.new()
	_anel.position = ANEL
	_mundo.add_child(_anel)
	_crono = Display7.new()
	# (as malhas dos dois tamanhos, de 2 e de 3 dígitos, ficam prontas já)
	_crono.configurar(3, 112, Arte.LARANJA)
	_crono.configurar(2, 150, Arte.LARANJA)
	_crono.position = ANEL
	_mundo.add_child(_crono)


func _montar_hud() -> void:
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.rect_size = Vector2(LARGURA, ALTURA)
	_mundo.add_child(_hud)
	# ALL-TIME HIGH (topo esquerdo)
	var t1 := Arte.texto("ALL-TIME HIGH", 26, Arte.LARANJA_CLARO, 3, Color(0.15, 0.04, 0.0), Label.ALIGN_LEFT)
	pos(t1, 62, 56, 240, 36)
	_hud.add_child(t1)
	_disp_high = Display7.new()
	_disp_high.configurar(4, 70, Arte.LARANJA)
	_disp_high.position = Vector2(170, 150)
	_hud.add_child(_disp_high)
	# PLAYERS SCORE (topo direito)
	var t2 := Arte.texto("PLAYERS SCORE", 26, Arte.LARANJA_CLARO, 3, Color(0.15, 0.04, 0.0), Label.ALIGN_RIGHT)
	pos(t2, 778, 56, 240, 36)
	_hud.add_child(t2)
	_lista_players = VBoxContainer.new()
	_lista_players.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lista_players.add_constant_override("separation", 0)
	pos(_lista_players, 768, 96, 250, 118)
	_hud.add_child(_lista_players)
	for i in 4:
		var l = Arte.texto("", 26, Arte.CORES_JOGADORES[i], 3, Color(0, 0, 0), Label.ALIGN_RIGHT)
		l.rect_min_size = Vector2(250, 29)
		_lista_players.add_child(l)
	# SCORE PASS (caixa esquerda) e CURRENT SCORE (caixa direita)
	_lbl_pass = Arte.texto("SCORE PASS", 24, Arte.AMBAR, 3, Color(0.15, 0.04, 0.0))
	pos(_lbl_pass, 85, 478, 260, 34)
	_hud.add_child(_lbl_pass)
	_disp_pass = Display7.new()
	_disp_pass.configurar(3, 66, Arte.AMBAR)
	_disp_pass.position = Vector2(214, 562)
	_hud.add_child(_disp_pass)
	var t3 := Arte.texto("CURRENT SCORE", 24, Arte.LARANJA_CLARO, 3, Color(0.15, 0.04, 0.0))
	pos(t3, 735, 478, 260, 34)
	_hud.add_child(t3)
	_disp_atual = Display7.new()
	_disp_atual.configurar(3, 66, Arte.LARANJA)
	_disp_atual.position = Vector2(866, 562)
	_hud.add_child(_disp_atual)
	# multiplicador (caixa do meio)
	_mult_titulo = Arte.texto("MULTIPLICADOR", 18, Arte.LARANJA_CLARO, 2, Color(0, 0, 0))
	pos(_mult_titulo, 384, 530, 310, 24)
	_hud.add_child(_mult_titulo)
	_mult_lbl = Arte.texto_solto("x1", 50, Color(1, 1, 1), 6, Arte.LARANJA, 300)
	_mult_lbl.position = Vector2(539, 576)
	_hud.add_child(_mult_lbl)
	_mult_barra = ColorRect.new()
	_mult_barra.color = Arte.LARANJA
	pos(_mult_barra, 404, 603, 270, 6)
	_mult_barra.rect_pivot_offset = Vector2(135, 3)
	_hud.add_child(_mult_barra)
	# jogador da vez (caixa central)
	_nome_vez = Arte.texto("", 46, Color(1, 1, 1), 6, Color(0, 0, 0))
	pos(_nome_vez, 378, 700, 324, 64)
	_hud.add_child(_nome_vez)
	_sub_vez = Arte.texto("", 25, Color(1.0, 0.85, 0.6), 3, Color(0, 0, 0))
	_sub_vez.autowrap = true
	pos(_sub_vez, 384, 768, 312, 86)
	_hud.add_child(_sub_vez)
	# cartões dos jogadores (rodapé)
	for i in 4:
		var card = Panel.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nome = Arte.texto("JOGADOR %d" % (i + 1), 28, Color(1, 1, 1), 3, Color(0, 0, 0), Label.ALIGN_LEFT)
		nome.name = "Nome"
		card.add_child(nome)
		var pts = Arte.texto("0", 52, Arte.CORES_JOGADORES[i], 5, Color(0, 0, 0), Label.ALIGN_RIGHT)
		pts.name = "Pts"
		card.add_child(pts)
		var bolinha = Polygon2D.new()
		bolinha.polygon = Malhas.elipse(Vector2.ZERO, Vector2(13, 13), 16)
		bolinha.color = Arte.CORES_JOGADORES[i]
		bolinha.name = "Cor"
		card.add_child(bolinha)
		_hud.add_child(card)
		_cards.append(card)
	_bola_card = Bola.new()
	_bola_card.tamanho(44)
	_hud.add_child(_bola_card)


func _montar_efeitos() -> void:
	# bola de ouro
	_ouro = Node2D.new()
	_ouro.position = BOLA_OURO
	_ouro.visible = false
	_mundo.add_child(_ouro)
	_ouro.add_child(Arte.sprite_brilho(Arte.OURO, 400.0))
	_ouro_anel = Node2D.new()
	_ouro_anel.set_script(load("res://scripts/fx/anel_progresso.gd"))
	_ouro_anel.set("raio", 108.0)
	_ouro_anel.set("cor", Arte.OURO)
	_ouro.add_child(_ouro_anel)
	_ouro_bola = Bola.new()
	_ouro_bola.tamanho(160)
	_ouro_bola.ouro(1.0)
	_ouro_bola.velocidade = 5.0
	_ouro.add_child(_ouro_bola)
	_ouro_txt = Arte.texto_solto("+5", 46, Arte.OURO, 6, Color(0.3, 0.1, 0.0), 200)
	_ouro_txt.position = Vector2(0, 150)
	_ouro.add_child(_ouro_txt)
	# faíscas da cesta
	for i in 2:
		var f = Arte.faiscas(46, Color(1.0, 0.65, 0.2))
		f.position = CESTA
		_mundo.add_child(f)
		_faiscas.append(f)
	_faiscas_ouro = Arte.faiscas(70, Arte.OURO)
	_faiscas_ouro.initial_velocity = 1000.0
	_faiscas_ouro.position = BOLA_OURO
	_mundo.add_child(_faiscas_ouro)
	# raios do SLAM MODE
	for i in 3:
		var r = Raio.new()
		_mundo.add_child(r)
		_raios.append(r)
	# "+N" que sobem
	for i in 6:
		var f = Arte.texto_solto("+1", 74, Color(1, 1, 1), 8, Arte.LARANJA, 300)
		f.visible = false
		_mundo.add_child(f)
		_flutuantes.append(f)
	# texto do combo
	_combo_banner = Arte.texto_solto("", 96, Color(1, 1, 1), 12, Arte.LARANJA, 1040)
	_combo_banner.position = Vector2(540, 1185)
	_combo_banner.visible = false
	_mundo.add_child(_combo_banner)
	# faixa central de avisos (recorde, últimos 10 s, slam, líder...)
	_banner = Node2D.new()
	_banner.position = Vector2(540, 1395)
	_banner.visible = false
	_mundo.add_child(_banner)
	_banner_painel = Arte.painel(Arte.LARANJA, 0.88, 26, 3, 26)
	_banner_painel.rect_position = Vector2(-450, -78)
	_banner_painel.rect_size = Vector2(900, 156)
	_banner.add_child(_banner_painel)
	_banner_txt = Arte.texto("", 58, Color(1, 1, 1), 7, Arte.LARANJA)
	_banner_txt.rect_position = Vector2(-450, -78)
	_banner_txt.rect_size = Vector2(900, 156)
	_banner_txt.autowrap = true
	_banner.add_child(_banner_txt)
	# moldura que pisca no recorde
	_borda = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Arte.OURO
	sb.set_border_width_all(12)
	sb.shadow_color = Color(1.0, 0.78, 0.14, 0.6)
	sb.shadow_size = 44
	_borda.add_stylebox_override("panel", sb)
	_borda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_borda.rect_size = Vector2(LARGURA, ALTURA)
	_borda.modulate.a = 0.0
	_borda.visible = false
	add_child(_borda)
	# escurecer + números da contagem
	_escuro = ColorRect.new()
	_escuro.color = Color(0, 0, 0, 1)
	_escuro.rect_size = Vector2(LARGURA, ALTURA)
	_escuro.modulate.a = 0.0
	_escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_escuro)
	_contagem = Arte.texto_solto("3", 330, Color(1, 1, 1), 14, Arte.LARANJA, 1000)
	_contagem.position = Vector2(540, 960)
	_contagem.visible = false
	add_child(_contagem)


func _montar_ordem() -> void:
	_ordem = Control.new()
	_ordem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ordem.rect_size = Vector2(LARGURA, ALTURA)
	_ordem.visible = false
	add_child(_ordem)
	var escuro := ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.8)
	escuro.rect_size = Vector2(LARGURA, ALTURA)
	_ordem.add_child(escuro)
	var p := Arte.painel(Arte.LARANJA, 0.96, 36, 3, 30)
	pos(p, 60, 560, 960, 760)
	_ordem.add_child(p)
	_ordem_titulo = Arte.texto("ORDEM DE JOGO", 70, Color(1, 1, 1), 8, Arte.LARANJA)
	pos(_ordem_titulo, 60, 595, 960, 96)
	_ordem.add_child(_ordem_titulo)
	_ordem_nome = Arte.texto("", 46, Color(1, 1, 1), 6, Color(0, 0, 0))
	pos(_ordem_nome, 60, 690, 960, 70)
	_ordem.add_child(_ordem_nome)
	for i in 4:
		var card = Panel.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var o = Arte.texto("%dº" % (i + 1), 40, Arte.CORES_JOGADORES[i], 4, Color(0, 0, 0))
		o.name = "O"
		card.add_child(o)
		var nm = Arte.texto("JOGADOR %d" % (i + 1), 26, Color(1, 1, 1), 3, Color(0, 0, 0))
		nm.name = "N"
		card.add_child(nm)
		var st = Arte.texto("", 26, Color(1, 1, 1), 3, Color(0, 0, 0))
		st.name = "S"
		card.add_child(st)
		_ordem.add_child(card)
		_ordem_cards.append(card)
	_ordem_info = Arte.texto("", 30, Color(0.88, 0.88, 0.9), 3, Color(0, 0, 0))
	pos(_ordem_info, 60, 1050, 960, 50)
	_ordem.add_child(_ordem_info)
	_ordem_start = Arte.texto("PRESSIONE START OU ACERTE A CESTA", 40, Color(1, 1, 1), 6, Arte.LARANJA)
	pos(_ordem_start, 60, 1180, 960, 70)
	_ordem.add_child(_ordem_start)


func _montar_entrada() -> void:
	_entrada = Control.new()
	_entrada.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entrada.rect_size = Vector2(LARGURA, ALTURA)
	_entrada.visible = false
	add_child(_entrada)
	var fundo := ColorRect.new()
	fundo.color = Color(0.01, 0.006, 0.02)
	fundo.rect_size = Vector2(LARGURA, ALTURA)
	_entrada.add_child(fundo)
	var halo := Arte.sprite_brilho(Arte.LARANJA, 560.0)
	halo.position = Vector2(540, 760)
	halo.modulate.a = 0.35
	_entrada.add_child(halo)
	_entrada_bola = Bola.new()
	_entrada_bola.tamanho(220)
	_entrada_bola.velocidade = 7.0
	_entrada_bola.position = Vector2(540, 760)
	_entrada.add_child(_entrada_bola)
	var t := Arte.texto("CARREGANDO ARENA", 76, Color(1, 1, 1), 9, Arte.LARANJA)
	pos(t, 0, 920, LARGURA, 110)
	_entrada.add_child(t)
	var s := Arte.texto("PREPARE-SE PARA O DESAFIO", 36, Color(0.85, 0.9, 1.0), 4, Color(0, 0, 0))
	pos(s, 0, 1030, LARGURA, 60)
	_entrada.add_child(s)
	var trilho := Arte.painel(Arte.LARANJA, 0.9, 12, 2, 10)
	pos(trilho, 180, 1150, 720, 22)
	_entrada.add_child(trilho)
	_entrada_barra = ColorRect.new()
	_entrada_barra.color = Arte.LARANJA
	pos(_entrada_barra, 184, 1154, 0, 14)
	_entrada.add_child(_entrada_barra)


# ============================================================= ciclo de vida
func entrar(dados := {}) -> void:
	.entrar(dados)
	n_jogadores = int(clamp(int(dados.get("jogadores", 1)), 1, 4))
	pontos = [0, 0, 0, 0]
	cestas = [0, 0, 0, 0]
	combos = [0, 0, 0, 0]
	terminou = [false, false, false, false]
	vez = 0
	_recorde_na_partida = false
	_total = float(Ajustes.tempo_turno)
	_tempo = _total
	_grade.limpar()
	_podio.esconder()
	_ordem.visible = false
	_contagem.visible = false
	_banner.visible = false
	_combo_banner.visible = false
	_ouro.visible = false
	_escuro.modulate.a = 0.0
	_sair_slam(true)
	_alertar(false)
	_mat_fundo.set_shader_param("apagado", 0.0)
	_disp_high.valor = Ajustes.recorde
	_layout_cards()
	_atualizar_turno_hud()
	_atualizar_lista()
	_anel.definir(1.0)
	_crono.valor = int(_total) if _total < 100 else 99
	_ajustar_crono()
	Sons.musica("jogo", 0.9)
	Tela.medir(true)
	Ajustes.registrar_partida()
	estado = ENTRADA
	_entrada_e_ordem()


func sair() -> void:
	.sair()
	Tela.medir(false)
	_podio.esconder()
	_grade.limpar()


func aquecer() -> void:
	# tudo aparece uma vez (a capa cobre)
	_entrada.visible = true
	_ordem.visible = true
	_banner.visible = true
	_combo_banner.visible = true
	_contagem.visible = true
	_ouro.visible = true
	_borda.visible = true
	_borda.modulate.a = 1.0
	_cards_visiveis(4)
	for o in _ondas:
		o.disparar(CESTA, 13)
	_grade.disparar(CESTA, 9)
	_grade.modo_recorde(true, CESTA)
	for f in _faiscas:
		f.restart()
		f.emitting = true
	_faiscas_ouro.restart()
	_faiscas_ouro.emitting = true
	_raios[0].disparar(Vector2(100, 100), CESTA)
	for f in _flutuantes:
		f.visible = true
	_podio.aquecer()
	yield(get_tree().create_timer(0.12), "timeout")
	_entrada.visible = false
	_ordem.visible = false
	_banner.visible = false
	_combo_banner.visible = false
	_contagem.visible = false
	_ouro.visible = false
	_borda.visible = false
	for f in _flutuantes:
		f.visible = false
	_grade.limpar()
	_podio.esconder()


func _entrada_e_ordem() -> void:
	var s := sessao
	_entrada.visible = true
	_entrada.modulate.a = 1.0
	_entrada_barra.rect_size.x = 0.0
	Sons.tocar("vento", -4.0)
	var tw := create_tween()
	tw.tween_property(_entrada_barra, "rect_size:x", 712.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_entrada, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	yield(tw, "finished")
	if not vale(s):
		return
	_entrada.visible = false
	# a arena "liga" como neon: cada parte acende piscando
	Sons.tocar("neon", -2.0)
	var partes := [_fundo, _grade, _anel, _crono]
	for c in _hud.get_children():
		partes.append(c)
	var k := 0
	for p in partes:
		if p is CanvasItem and p.visible and not p in _cards:
			neon_liga(p, 0.04 * k + _r.randf_range(0.0, 0.18))
			k += 1
	yield(get_tree().create_timer(0.7), "timeout")
	if not vale(s):
		return
	_anel.varrer(0.9)
	_mostrar_ordem(true)


# ===================================================================== ordem
func _mostrar_ordem(inicial: bool) -> void:
	estado = ORDEM
	_ordem_pronta = false
	_ordem_t = 0.0
	_select_t = 0.0
	_tempo = _total
	_ajustar_crono()
	_crono.valor = int(ceil(_tempo)) if _total < 100 else int(ceil(_tempo))
	_anel.definir(1.0)
	_anel.alerta(false)
	_atualizar_turno_hud()
	_ordem_titulo.text = "ORDEM DE JOGO" if inicial else "PRÓXIMO JOGADOR"
	if n_jogadores == 1:
		_ordem_titulo.text = "PREPARADO?"
	_ordem_nome.text = "JOGADOR %d (%s) COMEÇA AGORA" % [vez + 1, Arte.NOMES_CORES[vez]]
	_ordem_nome.add_color_override("font_color", Arte.CORES_JOGADORES[vez])
	_ordem_info.text = "CADA JOGADOR JOGA %d SEGUNDOS" % int(_total) if n_jogadores > 1 else "VOCÊ TEM %d SEGUNDOS" % int(_total)
	var largura := 210.0
	var gap := 20.0
	var x0 := 540.0 - (n_jogadores * largura + (n_jogadores - 1) * gap) * 0.5
	for i in 4:
		var card: Panel = _ordem_cards[i]
		card.visible = i < n_jogadores
		if i >= n_jogadores:
			continue
		var cor: Color = Arte.CORES_JOGADORES[i]
		var agora = i == vez
		pos(card, x0 + i * (largura + gap), 790, largura, 220)
		card.add_stylebox_override("panel", Arte.estilo_neon(cor, 0.9, 26, 5 if agora else 2, 26 if agora else 8))
		pos(card.get_node("O"), 0, 20, largura, 60)
		pos(card.get_node("N"), 0, 92, largura, 44)
		var st: Label = card.get_node("S")
		pos(st, 0, 146, largura, 50)
		if terminou[i]:
			st.text = "%d PTS" % pontos[i]
			st.add_color_override("font_color", Color(0.7, 0.7, 0.75))
			card.modulate.a = 0.6
		elif agora:
			st.text = "AGORA"
			st.add_color_override("font_color", Color(1, 1, 1))
			card.modulate.a = 1.0
		else:
			st.text = "DEPOIS"
			st.add_color_override("font_color", Color(0.75, 0.75, 0.8))
			card.modulate.a = 0.85
	_ordem.visible = true
	_ordem.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_ordem, "modulate:a", 1.0, 0.3)
	Sons.tocar("vento", -6.0)
	Arduino.led("STARTING" if inicial else "MENU_LOCK")
	var s := sessao
	yield(get_tree().create_timer(0.45), "timeout")
	if vale(s) and estado == ORDEM:
		_ordem_pronta = true


func _iniciar_turno() -> void:
	if estado != ORDEM or not _ordem_pronta:
		return
	_ordem_pronta = false
	estado = CONTAGEM
	var s := sessao
	Sons.tocar("selecao")
	var tw := create_tween()
	tw.tween_property(_ordem, "modulate:a", 0.0, 0.25)
	yield(tw, "finished")
	if not vale(s):
		return
	_ordem.visible = false
	# contagem 3-2-1: ondas vindo das bordas para o centro
	_contagem.visible = true
	var lbl := Arte.rotulo_de(_contagem)
	var et := create_tween()
	et.tween_property(_escuro, "modulate:a", 0.45, 0.2)
	for n in [3, 2, 1]:
		lbl.text = str(n)
		var prog = float(3 - n) / 2.0
		var cor = Color(1.0, 0.55, 0.08).linear_interpolate(Color(1.0, 0.25, 0.02), prog)
		Arte.pintar(lbl, Color(1, 1, 1), cor)
		_onda().disparar(Vector2(540, 960), 1, lerp(0.75, 1.45, prog), true, cor)
		_grade.disparar(Vector2(540, 960), 1, true, cor)
		Sons.tocar("bip")
		_contagem.scale = Vector2(1.5, 1.5)
		_contagem.modulate.a = 0.0
		var tc = create_tween().set_parallel(true)
		tc.tween_property(_contagem, "modulate:a", 1.0, 0.16)
		tc.tween_property(_contagem, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		yield(get_tree().create_timer(0.72), "timeout")
		if not vale(s):
			return
		var tf = create_tween()
		tf.tween_property(_contagem, "modulate:a", 0.0, 0.16)
		yield(tf, "finished")
		if not vale(s):
			return
	# VAI!
	lbl.text = "VAI!"
	Arte.pintar(lbl, Color(1, 1, 1), Color(0, 0, 0))
	_contagem.scale = Vector2(0.6, 0.6)
	_contagem.modulate.a = 1.0
	var tv := create_tween()
	tv.tween_property(_contagem, "scale", Vector2(1.12, 1.12), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tv.tween_interval(0.22)
	tv.tween_property(_contagem, "modulate:a", 0.0, 0.28)
	var te := create_tween()
	te.tween_property(_escuro, "modulate:a", 0.0, 0.3)
	Sons.tocar("apito")
	Sons.tocar("bip_vai", -4.0)
	_onda().disparar(CESTA, 3, 1.2)
	_grade.disparar(CESTA, 3)
	_tremer(10.0)
	_comecar_tempo()


func _comecar_tempo() -> void:
	estado = JOGANDO
	_aviso_prioridade = 0
	_tempo = _total
	_decorrido = 0.0
	_ultima_cesta = -100.0
	_combo = 0
	_mult = 1
	_recorde_no_turno = false
	_passou_lider = false
	_segundo_mostrado = -1
	_ouro_ativo = false
	_ouro.visible = false
	_sair_slam(true)
	_alertar(false)
	_grade.modo_recorde(false)
	_atualizar_mult(false)
	_atualizar_turno_hud()
	_agendar_ouro()
	Arduino.led("PLAY")


func _agendar_ouro() -> void:
	_ouro_em = []
	if not (Ajustes.modo_arcade and Ajustes.bola_de_ouro) or _total < 20.0:
		return
	var vezes := 2 if _total >= 50.0 else 1
	for i in vezes:
		var faixa0 = 0.18 + 0.4 * i / vezes
		var faixa1 = faixa0 + 0.4 / vezes
		_ouro_em.append(_total * _r.randf_range(faixa0, faixa1))


# ===================================================================== cesta
func _cesta() -> void:
	if estado == ORDEM:
		_iniciar_turno()
		return
	if estado != JOGANDO:
		return
	if _decorrido - _ultima_cesta < Ajustes.trava_sensor:
		return
	var intervalo := _decorrido - _ultima_cesta
	_ultima_cesta = _decorrido
	_combo = _combo + 1 if intervalo <= Ajustes.janela_combo else 1
	combos[vez] = int(max(combos[vez], _combo))
	cestas[vez] += 1
	var mult_antes := _mult
	_mult = _mult_do_combo(_combo) if Ajustes.modo_arcade else 1
	var ganho := _mult
	var ouro := false
	if _ouro_ativo:
		ouro = true
		ganho += 5
		_pegar_ouro()
	pontos[vez] += ganho
	_disp_atual.valor = pontos[vez]
	pop(_disp_atual, 1.3, 0.24)
	_atualizar_card_vez()
	# efeitos
	var nivel := _combo
	var recorde_agora = pontos[vez] > Ajustes.recorde
	if recorde_agora:
		var antigo := Ajustes.recorde
		Ajustes.tentar_recorde(pontos[vez])
		_disp_high.valor = Ajustes.recorde
		_recorde_na_partida = true
		if not _recorde_no_turno and antigo >= 3:
			_recorde_no_turno = true
			_festa_recorde()
	if _recorde_no_turno:
		Arduino.led("BOOST")
		_grade.disparar(CESTA, 9, false, Arte.OURO)
		_onda().disparar(CESTA, 1, 1.15, false, null, true)
	else:
		Arduino.led("HIT")
		_grade.disparar(CESTA, nivel)
		_onda().disparar(CESTA, nivel, 1.0)
		if nivel >= 9:
			_grade.disparar(CESTA, nivel, false, null, 0.14)
	_mat_fundo.set_shader_param("onda_centro", CESTA)
	_onda_fundo = 0.0
	_faisca().restart()
	Sons.tocar("combo_%d" % int(clamp(nivel, 1, 12)))
	_mostrar_combo(nivel)
	_flutuar("+%d" % ganho, Arte.OURO if ouro else (Grade.cor_do_combo(nivel) if nivel >= 3 else Color(1, 1, 1)))
	_tremer(4.0 + min(nivel, 12) * 0.9)
	for b in _barras:
		b.energia = clamp(0.2 + _combo * 0.08, 0.2, 1.0)
	if _mult > mult_antes:
		_subiu_mult()
	_atualizar_mult(true)
	_conferir_lider()
	_atualizar_alvo()


static func _mult_do_combo(c: int) -> int:
	if c >= 10:
		return 4
	if c >= 6:
		return 3
	if c >= 3:
		return 2
	return 1


var _onda_fundo := 99.0


func _onda() -> OndaLuz:
	var o: OndaLuz = _ondas[_onda_proxima]
	_onda_proxima = (_onda_proxima + 1) % _ondas.size()
	return o


func _faisca() -> CPUParticles2D:
	var f: CPUParticles2D = _faiscas[_faisca_proxima]
	_faisca_proxima = (_faisca_proxima + 1) % _faiscas.size()
	f.emitting = true
	return f


func _flutuar(texto: String, cor: Color) -> void:
	var f: Node2D = _flutuantes[_flutua_proximo]
	_flutua_proximo = (_flutua_proximo + 1) % _flutuantes.size()
	var l := Arte.rotulo_de(f)
	l.text = texto
	Arte.pintar(l, Color(1, 1, 1), cor)
	f.visible = true
	f.position = Vector2(CESTA.x + _r.randf_range(-150, 150), 960.0)
	f.modulate.a = 1.0
	f.scale = Vector2(0.5, 0.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(f, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "position:y", f.position.y - 150.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "modulate:a", 0.0, 0.45).set_delay(0.55)


func _mostrar_combo(nivel: int) -> void:
	var txt := "BOA!"
	match nivel:
		1:
			txt = "BOA!"
		2:
			txt = "COMBO 2"
		3:
			txt = "COMBO 3"
		4:
			txt = "SUPER 4!"
		5:
			txt = "MEGA 5!"
		6, 7, 8:
			txt = "BLUE %d!" % nivel
		9, 10, 11, 12:
			txt = "NEON %d!" % nivel
		_:
			txt = "MAX %d!" % nivel
	var cor_contorno := Color(1.0, 0.38, 0.02)
	var cor_texto := Color(1, 1, 1)
	if nivel >= 13:
		cor_contorno = Color(1.0, 0.02, 0.0)
		cor_texto = Color(1.0, 0.88, 0.84)
	elif nivel >= 9:
		cor_contorno = Color(0.8, 0.2, 1.0)
		cor_texto = Color(0.96, 0.88, 1.0)
	elif nivel >= 6:
		cor_contorno = Color(0.08, 0.42, 1.0)
		cor_texto = Color(0.88, 0.94, 1.0)
	elif nivel >= 4:
		cor_contorno = Color(1.0, 0.42, 0.02)
		cor_texto = Color(1.0, 0.88, 0.42)
	var l := Arte.rotulo_de(_combo_banner)
	l.text = txt
	Arte.pintar(l, cor_texto, cor_contorno)
	if _combo_tw != null and _combo_tw.is_valid():
		_combo_tw.kill()
	_combo_banner.visible = true
	_combo_banner.modulate.a = 0.0
	_combo_banner.scale = Vector2(0.7, 0.7)
	_combo_banner.rotation = _r.randf_range(-0.06, 0.06)
	_combo_tw = create_tween()
	_combo_tw.set_parallel(true)
	_combo_tw.tween_property(_combo_banner, "modulate:a", 1.0, 0.08)
	_combo_tw.tween_property(_combo_banner, "scale", Vector2(1.05, 1.05), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_combo_tw.chain().tween_interval(0.42)
	_combo_tw.chain().set_parallel(true)
	_combo_tw.tween_property(_combo_banner, "scale", Vector2(0.9, 0.9), 0.18)
	_combo_tw.tween_property(_combo_banner, "modulate:a", 0.0, 0.18)


func _subiu_mult() -> void:
	Sons.tocar("sobe", -2.0, 0.9 + _mult * 0.12)
	pop(_mult_lbl, 1.6, 0.4)
	if _mult >= 4 and not _slam:
		_entrar_slam()
	elif _mult < 4:
		_avisar("PONTOS x%d!" % _mult, Grade.cor_do_combo(3 if _mult == 2 else 6), 0.9)


func _atualizar_mult(_mudou: bool) -> void:
	var l := Arte.rotulo_de(_mult_lbl)
	var txt := "x%d" % _mult
	if l.text != txt:
		l.text = txt
	var cor := Arte.LARANJA
	if _mult == 2:
		cor = Color(1.0, 0.58, 0.04)
	elif _mult == 3:
		cor = Color(0.12, 0.55, 1.0)
	elif _mult >= 4:
		cor = Color(0.35, 0.9, 1.0)
	Arte.pintar(l, Color(1, 1, 1), cor)
	_mult_barra.color = cor
	if not Ajustes.modo_arcade:
		_mult_titulo.text = "COMBO"
		l.text = str(_combo)


# ========================================================= recorde, líder...
func _festa_recorde() -> void:
	Arduino.led("RECORD")
	Sons.tocar("recorde")
	_grade.modo_recorde(true, CESTA - Vector2(0, 30))
	_avisar("RECORDE BATIDO!", Arte.OURO, 1.6, 3)
	_borda.visible = true
	var tw := create_tween()
	tw.tween_property(_borda, "modulate:a", 1.0, 0.12)
	tw.tween_property(_borda, "modulate:a", 0.0, 0.5)
	tw.tween_property(_borda, "modulate:a", 0.8, 0.12)
	tw.tween_property(_borda, "modulate:a", 0.0, 0.6)
	_faiscas_ouro.position = CESTA
	_faiscas_ouro.restart()
	_faiscas_ouro.emitting = true
	_tremer(16.0)


func _lider() -> int:
	var m := -1
	for i in n_jogadores:
		if terminou[i]:
			m = int(max(m, pontos[i]))
	return m


func _conferir_lider() -> void:
	var l := _lider()
	if l < 0 or _passou_lider:
		return
	if pontos[vez] > l and l > 0:
		_passou_lider = true
		Sons.tocar("sobe", 0.0, 1.3)
		Arduino.led("BOOST")
		_avisar("PASSOU O LÍDER!", Arte.CORES_JOGADORES[vez], 1.2, 2)


func _atualizar_alvo() -> void:
	var l := _lider()
	var p: int = pontos[vez]
	if l >= 0 and p <= l:
		_lbl_pass.text = "SCORE PASS"
		_disp_pass.valor = l + 1
		_sub_vez.text = "FALTAM %d PARA LIDERAR" % (l + 1 - p) if estado == JOGANDO else "LÍDER: %d PONTOS" % l
	elif p > Ajustes.recorde or (Ajustes.recorde > 0 and p == Ajustes.recorde and _recorde_no_turno):
		_lbl_pass.text = "RECORDE!"
		_disp_pass.valor = Ajustes.recorde
		_sub_vez.text = "VOCÊ É O RECORDE DA ARENA!"
	else:
		_lbl_pass.text = "SCORE PASS"
		_disp_pass.valor = Ajustes.recorde + 1 if Ajustes.recorde > 0 else 0
		if Ajustes.recorde > 0:
			_sub_vez.text = "FALTAM %d PARA O RECORDE" % (Ajustes.recorde + 1 - p)
		else:
			_sub_vez.text = "FAÇA O PRIMEIRO RECORDE!"


var _aviso_prioridade := 0
var _aviso_ate := 0.0


## Aviso na faixa central. Um aviso mais importante (recorde, slam, tempo)
## não é coberto por um menos importante enquanto aparece.
func _avisar(texto: String, cor: Color, duracao := 1.1, prioridade := 1) -> void:
	if prioridade < _aviso_prioridade and _t < _aviso_ate:
		return
	_aviso_prioridade = prioridade
	_aviso_ate = _t + duracao + 0.4
	_banner_txt.text = texto
	_banner_painel.add_stylebox_override("panel", Arte.estilo_neon(cor, 0.9, 26, 4, 30))
	Arte.pintar(_banner_txt, Color(1, 1, 1), cor)
	if _banner_tw != null and _banner_tw.is_valid():
		_banner_tw.kill()
	_banner.visible = true
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(0.6, 0.6)
	_banner_tw = create_tween()
	_banner_tw.set_parallel(true)
	_banner_tw.tween_property(_banner, "modulate:a", 1.0, 0.12)
	_banner_tw.tween_property(_banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tw.chain().tween_interval(duracao)
	_banner_tw.chain().set_parallel(true)
	_banner_tw.tween_property(_banner, "modulate:a", 0.0, 0.25)
	_banner_tw.tween_property(_banner, "scale", Vector2(1.08, 1.08), 0.25)


func _tremer(forca: float) -> void:
	_tremor = max(_tremor, forca)


# ================================================================ SLAM MODE
func _entrar_slam() -> void:
	_slam = true
	_proximo_raio = 0.0
	Sons.tocar("trovao")
	_avisar("SLAM MODE!  PONTOS x4", Arte.CIANO, 1.4, 3)
	_tremer(18.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_method(self, "_azul", 0.0, 1.0, 0.35)
	_grade.base = 2.4
	for b in _barras:
		b.cores(Color(0.1, 0.45, 1.0), Color(0.6, 0.95, 1.0))


func _sair_slam(imediato := false) -> void:
	if not _slam and not imediato:
		return
	_slam = false
	if imediato:
		_azul(0.0)
	else:
		var tw := create_tween()
		tw.tween_method(self, "_azul", 1.0, 0.0, 0.5)
	if _grade != null:
		_grade.base = 1.0
	for b in _barras:
		b.cores(Color(1.0, 0.32, 0.02), Color(1.0, 0.85, 0.4))


func _azul(v: float) -> void:
	_mat_fundo.set_shader_param("azul", v)


func _raio_slam() -> void:
	var origens := [Vector2(40, 60), Vector2(1040, 60), Vector2(30, 900), Vector2(1050, 900), Vector2(540, 20)]
	var r: Raio = _raios[_r.randi() % _raios.size()]
	r.disparar(origens[_r.randi() % origens.size()], CESTA + Vector2(_r.randf_range(-60, 60), _r.randf_range(-30, 30)), 0.3)
	if _r.randf() < 0.35:
		Sons.tocar("trovao", -12.0, _r.randf_range(0.9, 1.2))


# ============================================================== bola de ouro
func _mostrar_ouro() -> void:
	_ouro_ativo = true
	_ouro_resta = 6.0
	_ouro.visible = true
	_ouro.scale = Vector2(0.1, 0.1)
	_ouro.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_ouro, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sons.tocar("ouro")
	_avisar("BOLA DE OURO!  VALE +5", Arte.OURO, 1.0, 2)


func _pegar_ouro() -> void:
	_ouro_ativo = false
	Sons.tocar("ouro", 2.0, 1.25)
	_faiscas_ouro.position = BOLA_OURO
	_faiscas_ouro.restart()
	_faiscas_ouro.emitting = true
	_onda().disparar(BOLA_OURO, 1, 1.3, false, Arte.OURO, true)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_ouro, "scale", Vector2(1.8, 1.8), 0.35)
	tw.tween_property(_ouro, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(_ouro, "set_visible", [false])


func _perder_ouro() -> void:
	_ouro_ativo = false
	var tw := create_tween()
	tw.tween_property(_ouro, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_ouro, "set_visible", [false])


# ========================================================== últimos segundos
func _alertar(ligado: bool) -> void:
	_alerta = ligado
	_anel.alerta(ligado)
	_crono.cor = Arte.VERMELHO_ALERTA if ligado else Arte.LARANJA
	if not ligado:
		_mat_fundo.set_shader_param("alerta", 0.0)


# ================================================================ fim do turno
func _fim_do_turno() -> void:
	estado = FIM_TURNO
	var s := sessao
	_tempo = 0.0
	_anel.definir(0.0)
	_crono.valor = 0
	Sons.tocar("fim_turno")
	Arduino.led("OFF")
	_sair_slam()
	_alertar(false)
	if _ouro_ativo:
		_perder_ouro()
	terminou[vez] = true
	Ajustes.registrar_turno(pontos[vez], cestas[vez], vez)
	Ajustes.salvar_recordes()
	_avisar("TEMPO!  %d PONTOS" % pontos[vez], Arte.CORES_JOGADORES[vez], 1.6, 9)
	_atualizar_lista()
	_atualizar_card_vez()
	yield(get_tree().create_timer(2.4), "timeout")
	if not vale(s):
		return
	_grade.modo_recorde(false)
	if vez < n_jogadores - 1:
		vez += 1
		_atualizar_turno_hud()
		_mostrar_ordem(false)
	else:
		_mostrar_podio()


func _mostrar_podio() -> void:
	estado = PODIO
	Sons.musica("podio")
	_podio.mostrar(n_jogadores, pontos, cestas, combos, _recorde_na_partida)


func _podio_acabou(acao: String) -> void:
	if not ativo:
		return
	if acao == "reiniciar":
		if Ajustes.modo_credito and Ajustes.creditos < n_jogadores:
			ir("abertura")
			return
		Ajustes.gastar_creditos(n_jogadores)
		entrar({"jogadores": n_jogadores, "sem_escuro": true})
	else:
		ir("abertura")


# ================================================================ HUD helpers
func _ajustar_crono() -> void:
	var dig := 3 if _total >= 100 else 2
	if _crono.digitos != dig:
		_crono.configurar(dig, 150 if dig == 2 else 112, _crono.cor)


func _layout_cards() -> void:
	_cards_visiveis(n_jogadores)


func _cards_visiveis(n: int) -> void:
	var largura = [300.0, 440.0, 320.0, 240.0][n - 1] if n > 1 else 420.0
	var gap := 16.0
	var total = n * largura + (n - 1) * gap
	var x0 = 540.0 - total * 0.5
	for i in 4:
		var card: Panel = _cards[i]
		card.visible = i < n
		if i >= n:
			continue
		pos(card, x0 + i * (largura + gap), 1708, largura, 128)
		var nome: Label = card.get_node("Nome")
		nome.text = "JOGADOR %d" % (i + 1) if largura >= 300 else "P%d" % (i + 1)
		pos(nome, 52, 0, largura - 60, 56)
		var pts: Label = card.get_node("Pts")
		pos(pts, 14, 50, largura - 30, 72)
		var c: Polygon2D = card.get_node("Cor")
		c.position = Vector2(30, 28)


func _atualizar_turno_hud() -> void:
	var cor: Color = Arte.CORES_JOGADORES[vez]
	_nome_vez.text = "JOGADOR %d" % (vez + 1)
	_nome_vez.add_color_override("font_color", cor)
	_disp_atual.valor = pontos[vez]
	_disp_high.valor = Ajustes.recorde
	for i in n_jogadores:
		var card: Panel = _cards[i]
		var c: Color = Arte.CORES_JOGADORES[i]
		var agora = i == vez and not terminou[i]
		if agora:
			card.add_stylebox_override("panel", Arte.estilo_neon(c, 0.85, 22, 4, 24, 0.16))
			card.modulate.a = 1.0
		elif terminou[i]:
			card.add_stylebox_override("panel", Arte.estilo_neon(Color(0.45, 0.45, 0.5), 0.6, 22, 2, 0))
			card.modulate.a = 0.75
		else:
			card.add_stylebox_override("panel", Arte.estilo_neon(c, 0.55, 22, 2, 8, 0.08))
			card.modulate.a = 0.85
		var pts: Label = card.get_node("Pts")
		pts.text = str(pontos[i])
	_atualizar_mult(false)
	_atualizar_alvo()


func _atualizar_card_vez() -> void:
	var pts: Label = _cards[vez].get_node("Pts")
	pts.text = str(pontos[vez])


func _atualizar_lista() -> void:
	var linhas := []
	for i in n_jogadores:
		if terminou[i]:
			linhas.append(i)
	for k in 4:
		var l: Label = _lista_players.get_child(k)
		if k < linhas.size():
			var i: int = linhas[k]
			l.text = "%s  %d" % ["JOGADOR %d" % (i + 1) if n_jogadores <= 2 else "P%d" % (i + 1), pontos[i]]
			l.add_color_override("font_color", Arte.CORES_JOGADORES[i])
		else:
			l.text = ""


# ===================================================================== quadro
func _process(delta: float) -> void:
	_t += delta
	# tremor da tela (só a posição do mundo)
	if _tremor > 0.1:
		_mundo.position = Vector2(_r.randf_range(-1, 1), _r.randf_range(-1, 1)) * _tremor
		_tremor = max(0.0, _tremor - delta * 60.0)
	elif _mundo.position != Vector2.ZERO:
		_mundo.position = Vector2.ZERO
		_tremor = 0.0
	# fundo vivo: respiração + radar que desce + onda da cesta
	_mat_fundo.set_shader_param("respiro", 0.5 + 0.5 * sin(_t * 1.5))
	var radar := fmod(_t, 6.0)
	_mat_fundo.set_shader_param("scan_y", lerp(-100.0, 2050.0, radar / 2.2) if radar < 2.2 else -500.0)
	_mat_fundo.set_shader_param("scan_forca", 0.55)
	if _onda_fundo < 1.2:
		_onda_fundo += delta
		_mat_fundo.set_shader_param("onda_raio", _onda_fundo * 1750.0)
		_mat_fundo.set_shader_param("onda_forca", clamp(1.0 - _onda_fundo / 1.2, 0.0, 1.0))
	elif _onda_fundo < 99.0:
		_onda_fundo = 99.0
		_mat_fundo.set_shader_param("onda_forca", 0.0)
	# bola do cartão da vez quicando
	if estado in [ORDEM, CONTAGEM, JOGANDO] and vez < n_jogadores:
		var card: Panel = _cards[vez]
		_bola_card.visible = true
		_bola_card.position = card.rect_position + Vector2(card.rect_size.x - 34, -26 - abs(sin(_t * 4.0)) * 22.0)
	else:
		_bola_card.visible = false
	match estado:
		ORDEM:
			_ordem_t += delta
			_ordem_start.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * 4.5))
			if Controles.segurando("input_select"):
				_select_t += delta
				if _select_t > 3.0:
					_select_t = 0.0
					ir("abertura")
					return
			else:
				_select_t = 0.0
			if _ordem_pronta and _ordem_t > AUTO_INICIO:
				_iniciar_turno()
		JOGANDO:
			_jogando(delta)


func _jogando(delta: float) -> void:
	_decorrido += delta
	_tempo = max(0.0, _total - _decorrido)
	_anel.definir(_tempo / _total)
	var seg := int(ceil(_tempo))
	if seg != _segundo_mostrado:
		_segundo_mostrado = seg
		_crono.valor = seg
		if seg <= 10 and seg > 0:
			if not _alerta:
				_alertar(true)
				_avisar("ÚLTIMOS 10 SEGUNDOS!", Arte.VERMELHO_ALERTA, 1.2, 2)
			Sons.tocar("tique", -2.0)
			pop(_crono, 1.12, 0.2)
			if seg <= 5:
				Sons.tocar("batida", -3.0)
	if _alerta:
		_mat_fundo.set_shader_param("alerta", 0.35 + 0.3 * sin(_t * 9.0))
	# combo: a barrinha esvazia; acabou a janela, o combo acaba
	if _combo > 0:
		var resta := 1.0 - (_decorrido - _ultima_cesta) / Ajustes.janela_combo
		if resta <= 0.0:
			if _mult > 1:
				Sons.tocar("quebra", -3.0)
			_combo = 0
			_mult = 1
			_sair_slam()
			_atualizar_mult(true)
			for b in _barras:
				b.energia = 0.2
			_mult_barra.rect_scale.x = 0.0
		else:
			_mult_barra.rect_scale.x = resta
	else:
		_mult_barra.rect_scale.x = 0.0
	# dica quando ninguém acerta
	if _decorrido - max(_ultima_cesta, 0.0) > 6.0 and int(_t * 2.0) % 2 == 0:
		if _sub_vez.text != "ARREMESSE!":
			_sub_vez.text = "ARREMESSE!"
	elif _sub_vez.text == "ARREMESSE!":
		_atualizar_alvo()
	# bola de ouro
	if not _ouro_em.empty() and _decorrido >= float(_ouro_em[0]) and _tempo > 6.0:
		_ouro_em.pop_front()
		_mostrar_ouro()
	if _ouro_ativo:
		_ouro_resta -= delta
		_ouro_anel.set("progresso", _ouro_resta / 6.0)
		_ouro.position.y = BOLA_OURO.y - abs(sin(_t * 3.2)) * 20.0
		if _ouro_resta <= 0.0:
			_perder_ouro()
	# SLAM MODE: raios caindo na cesta
	if _slam:
		_proximo_raio -= delta
		if _proximo_raio <= 0.0:
			_proximo_raio = _r.randf_range(0.45, 1.0)
			_raio_slam()
	if _tempo <= 0.0:
		_fim_do_turno()


# ===================================================================== botões
func _unhandled_input(event: InputEvent) -> void:
	if not ativo:
		return
	if Controles.cesta(event):
		_cesta()
		return
	if Controles.start(event):
		if estado == ORDEM:
			_iniciar_turno()
		elif estado == PODIO and _podio.pode_reiniciar():
			_podio.esconder()
			_podio_acabou("reiniciar")
