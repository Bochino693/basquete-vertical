extends "res://scripts/tela_base.gd"

## A PARTIDA: 1 jogador, 3 fases, no estilo das máquinas de arcade. Nenhum
## botão: a cesta da abertura trouxe o jogador e daqui em diante tudo anda
## sozinho (cada fase abre com o MAPA DAS FASES e a contagem 3-2-1).
##
##   * FASE 1 e FASE 2 têm META. A META (caixa da esquerda) mostra o
##     total a alcançar: os pontos com que a fase começou + a meta dela.
##     Alcançou: PASSOU! (a arena acende em verde) e a fase segue valendo
##     até o tempo acabar. Não alcançou: fim de jogo. A FINAL não tem meta:
##     vale tudo (e a META vira o RECORDE a bater).
##   * CESTA = sinal do sensor (input_cesta), com a trava do operador
##     (tempo mínimo entre duas cestas) e o sensor tendo de soltar.
##   * MULTIPLICADOR (modo arcade): cestas seguidas (menos de "janela do
##     combo" entre elas): 3 = x2, 6 = x3, 10 = x4 = MODO ENTERRADA (arena azul
##     elétrica, raios caindo na cesta). Na FINAL ele é TURBINADO: já
##     começa em x2, 3 seguidas = x3 e 6 seguidas = MODO ENTERRADA.
##   * BOLA DE OURO (modo arcade): uma vez por fase, por 6 s; vale +5.
##   * Entre as fases: BÔNUS DE SEQUÊNCIA (o maior combo da fase vira
##     pontos, contados no display).
##   * RECORDE DA ARENA: bateu, a arena inteira vira festa (grade em ondas
##     douradas até o fim da partida, LED "RECORD").
##   * Últimos 10 segundos de cada fase: anel vermelho piscando, tique a
##     cada segundo, coração nos 5 finais.
##   * TORCIDA: muito tempo sem cesta = "uuuh"; não passou da fase 1 =
##     VAIA (e no resultado nada de aplauso nem confete); campeão ou
##     recorde = APLAUSOS, confete e coroa.
##   * Fim: resultado (resultado.gd); a cesta joga de novo.
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
const BolasCaindo = preload("res://scripts/fx/bolas_caindo.gd")
const Holofotes = preload("res://scripts/fx/holofotes.gd")
const Resultado = preload("res://scripts/resultado.gd")

enum { ENTRADA, MAPA, CONTAGEM, JOGANDO, FIM_FASE, RESULTADO }

# medidas da arte (fundo_jogo.png 941 x 1672, ampliada para 1080 x 1920)
const ANEL := Vector2(539.4, 299.0)
const CESTA := Vector2(540.0, 776.0)
const BOLA_OURO := Vector2(540.0, 1010.0)
const PASS_POS := Vector2(214.0, 562.0)
const RELOGIO_DESCE := 26.0     # os dígitos do relógio descem para caber o "TEMPO"
const COR_PONTOS := Color(1.0, 0.86, 0.18)
const MAPA_SEGUNDOS := 2.4
const CORES_FASE := [Color(1.0, 0.46, 0.04), Color(0.25, 0.62, 1.0), Color(1.0, 0.80, 0.12)]
const VERDE := Color(0.3, 1.0, 0.5)
const FINAL := 2

var estado := ENTRADA
var fases: Array = []
var fase := 0
var pontos := 0
var cestas := 0
var maior_combo := 0
var pontos_fase := [0, 0, 0]
var cestas_fase := [0, 0, 0]
var combo_fase := [0, 0, 0]
var passou := [false, false, false]

var _alvo := 0                  # META da fase (0 = final)
var _tempo := 40.0              # que resta
var _total := 40.0
var _decorrido := 0.0
var _ultima_cesta := -100.0
var _combo := 0
var _mult := 1
var _slam := false
var _recorde_antigo := 0
var _festa_feita := false
var _segundo_mostrado := -1
var _ouro_em: Array = []
var _ouro_ativo := false
var _ouro_resta := 0.0
var _mapa_t := 0.0
var _mapa_pronto := false
var _select_t := 0.0
var _tremor := 0.0
var _t := 0.0
var _proximo_raio := 0.0
var _r := RandomNumberGenerator.new()
var _onda_proxima := 0
var _faisca_proxima := 0
var _flutua_proximo := 0
var _alerta := false
var _uuuh_feito := false        # o "uuuh" da torcida já tocou nesta seca

# nós
var _mundo: Node2D
var _fundo: MeshInstance2D
var _mat_fundo: ShaderMaterial
var _grade: Grade
var _holofotes: Holofotes
var _bolas_fx: BolasCaindo
var _proxima_bola_slam := 0.0
var _barras: Array = []
var _ondas: Array = []
var _anel: AnelCrono
var _crono: Display7
var _tempo_lbl: Node2D
var _hud: Control
var _disp_high: Display7
var _disp_pass: Display7
var _disp_atual: Display7
var _lbl_pass: Label
var _lista_top: VBoxContainer
var _mult_lbl: Node2D
var _mult_barra: ColorRect
var _mult_titulo: Label
var _nome_fase: Label
var _sub_fase: Label
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
var _mapa: Control
var _mapa_painel: Panel
var _mapa_titulo: Label
var _mapa_sub: Label
var _mapa_info: Label
var _mapa_prepare: Label
var _mapa_cards: Array = []
var _entrada: Control
var _entrada_bola: Bola
var _entrada_barra: ColorRect
var _resultado: Resultado


func _ready() -> void:
	_r.randomize()
	_mundo = Node2D.new()
	add_child(_mundo)
	_montar_fundo()
	_montar_hud()
	_montar_efeitos()
	_montar_mapa()
	_montar_entrada()
	Tela.connect("efeitos_mudaram", self, "_aplicar_efeitos")
	_resultado = Resultado.new()
	add_child(_resultado)
	_resultado.connect("acabou", self, "_resultado_acabou")


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
	_holofotes = Holofotes.new()
	_mundo.add_child(_holofotes)
	for i in 4:
		var o = OndaLuz.new()
		_mundo.add_child(o)
		_ondas.append(o)
	_anel = AnelCrono.new()
	_anel.position = ANEL
	_mundo.add_child(_anel)
	_crono = Display7.new()
	_crono.diametro_placa = 338.0
	_crono.desvio_placa = Vector2(0, -RELOGIO_DESCE)
	_crono.configurar(2, 150, Arte.LARANJA, -1.0, Display7.PLACA_REDONDA)
	_crono.position = ANEL + Vector2(0, RELOGIO_DESCE)
	_mundo.add_child(_crono)
	_tempo_lbl = Arte.texto_solto("TEMPO", 42, Color(1, 1, 1), 6, Arte.LARANJA, 300)
	_tempo_lbl.position = ANEL + Vector2(0, -98)
	_mundo.add_child(_tempo_lbl)


func _montar_hud() -> void:
	_hud = Control.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.rect_size = Vector2(LARGURA, ALTURA)
	_mundo.add_child(_hud)
	# RECORDE (topo esquerdo)
	# (tudo grande e em português: o jogador fica a uns 2 metros da tela)
	var t1 := Arte.texto("RECORDE", 34, Color(1, 1, 1), 5, Arte.LARANJA, Label.ALIGN_LEFT)
	pos(t1, 60, 48, 270, 44)
	_hud.add_child(t1)
	_disp_high = Display7.new()
	_disp_high.configurar(4, 80, Arte.OURO)
	_disp_high.position = Vector2(172, 152)
	_hud.add_child(_disp_high)
	# MELHORES DE HOJE (topo direito): os 3 melhores do dia
	var t2 := Arte.texto("MELHORES DE HOJE", 30, Color(1, 1, 1), 5, Arte.LARANJA, Label.ALIGN_RIGHT)
	pos(t2, 720, 50, 300, 42)
	_hud.add_child(t2)
	_lista_top = VBoxContainer.new()
	_lista_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lista_top.add_constant_override("separation", 0)
	pos(_lista_top, 760, 96, 258, 120)
	_hud.add_child(_lista_top)
	for i in 3:
		var l = Arte.texto("", 34, Arte.OURO if i == 0 else Color(1.0, 0.82, 0.55), 4, Color(0, 0, 0), Label.ALIGN_RIGHT)
		l.rect_min_size = Vector2(258, 40)
		_lista_top.add_child(l)
	# META (caixa esquerda) e PONTOS (caixa direita)
	_lbl_pass = Arte.texto("META", 32, Arte.CIANO, 5, Color(0.0, 0.1, 0.18))
	pos(_lbl_pass, 85, 470, 260, 42)
	_hud.add_child(_lbl_pass)
	_disp_pass = Display7.new()
	_disp_pass.configurar(3, 82, Arte.CIANO)
	_disp_pass.position = PASS_POS
	_hud.add_child(_disp_pass)
	var t3 := Arte.texto("PONTOS", 32, COR_PONTOS, 5, Color(0.2, 0.08, 0.0))
	pos(t3, 735, 470, 260, 42)
	_hud.add_child(t3)
	_disp_atual = Display7.new()
	_disp_atual.configurar(3, 82, COR_PONTOS)
	_disp_atual.position = Vector2(866, 562)
	_hud.add_child(_disp_atual)
	# multiplicador (caixa do meio)
	_mult_titulo = Arte.texto("MULTIPLICADOR", 20, Color(1, 1, 1), 3, Arte.LARANJA)
	pos(_mult_titulo, 384, 536, 310, 26)
	_hud.add_child(_mult_titulo)
	_mult_lbl = Arte.texto_solto("x1", 56, Color(1, 1, 1), 7, Arte.LARANJA, 300)
	_mult_lbl.position = Vector2(539, 582)
	_hud.add_child(_mult_lbl)
	_mult_barra = ColorRect.new()
	_mult_barra.color = Arte.LARANJA
	pos(_mult_barra, 404, 610, 270, 6)
	_mult_barra.rect_pivot_offset = Vector2(135, 3)
	_hud.add_child(_mult_barra)
	# a fase (caixa central)
	_nome_fase = Arte.texto("", 58, Color(1, 1, 1), 7, Color(0, 0, 0))
	pos(_nome_fase, 372, 692, 336, 76)
	_hud.add_child(_nome_fase)
	_sub_fase = Arte.texto("", 31, Color(1.0, 0.9, 0.62), 4, Color(0, 0, 0))
	_sub_fase.autowrap = true
	pos(_sub_fase, 380, 766, 320, 96)
	_hud.add_child(_sub_fase)
	# trilha das fases (rodapé): FASE 1, FASE 2, FINAL
	for i in 3:
		var card = Panel.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pos(card, 29 + i * 346, 1708, 330, 128)
		var nome = Arte.texto(Ajustes.NOMES_FASE[i], 34, Color(1, 1, 1), 4, Color(0, 0, 0), Label.ALIGN_LEFT)
		nome.name = "Nome"
		pos(nome, 50, 0, 180, 58)
		card.add_child(nome)
		var info = Arte.texto("", 25, Arte.LARANJA_CLARO, 3, Color(0, 0, 0), Label.ALIGN_RIGHT)
		info.name = "Info"
		pos(info, 140, 8, 178, 48)
		card.add_child(info)
		var pts = Arte.texto("-", 64, CORES_FASE[i], 6, Color(0, 0, 0), Label.ALIGN_RIGHT)
		pts.name = "Pts"
		pos(pts, 14, 44, 300, 82)
		card.add_child(pts)
		var bolinha = Polygon2D.new()
		bolinha.polygon = Malhas.elipse(Vector2.ZERO, Vector2(13, 13), 16)
		bolinha.color = CORES_FASE[i]
		bolinha.position = Vector2(30, 28)
		card.add_child(bolinha)
		_hud.add_child(card)
		_cards.append(card)
	_bola_card = Bola.new()
	_bola_card.tamanho(58)
	_hud.add_child(_bola_card)


func _montar_efeitos() -> void:
	# as bolas que saem da cesta e caem para fora da tela (por cima do
	# placar; por baixo dos "+N" e dos avisos)
	_bolas_fx = BolasCaindo.new()
	_mundo.add_child(_bolas_fx)
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
	# raios do MODO ENTERRADA
	for i in 3:
		var r = Raio.new()
		_mundo.add_child(r)
		_raios.append(r)
	# "+N" que sobem
	for i in 6:
		var f = Arte.texto_solto("+1", 100, Color(1, 1, 1), 10, Arte.LARANJA, 360)
		f.visible = false
		_mundo.add_child(f)
		_flutuantes.append(f)
	# texto do combo
	_combo_banner = Arte.texto_solto("", 112, Color(1, 1, 1), 13, Arte.LARANJA, 1060)
	_combo_banner.position = Vector2(540, 1185)
	_combo_banner.visible = false
	_mundo.add_child(_combo_banner)
	# faixa central de avisos (passou, recorde, últimos 10 s, slam...)
	_banner = Node2D.new()
	_banner.position = Vector2(540, 1395)
	_banner.visible = false
	_mundo.add_child(_banner)
	_banner_painel = Arte.painel(Arte.LARANJA, 0.88, 26, 3, 26)
	_banner_painel.rect_position = Vector2(-450, -78)
	_banner_painel.rect_size = Vector2(900, 156)
	_banner.add_child(_banner_painel)
	_banner_txt = Arte.texto("", 64, Color(1, 1, 1), 8, Arte.LARANJA)
	_banner_txt.rect_position = Vector2(-450, -78)
	_banner_txt.rect_size = Vector2(900, 156)
	_banner_txt.autowrap = true
	_banner.add_child(_banner_txt)
	# moldura que pisca no recorde
	_borda = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Arte.OURO
	sb.set_border_width_all(18)
	sb.border_blend = true
	# (sem sombra: a sombra do StyleBoxFlat pinta o painel inteiro - com a
	# moldura do tamanho da tela, a tela toda ficava amarela)
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


## O MAPA DAS FASES: abre cada fase (sozinho, sem botão).
func _montar_mapa() -> void:
	_mapa = Control.new()
	_mapa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mapa.rect_size = Vector2(LARGURA, ALTURA)
	_mapa.visible = false
	add_child(_mapa)
	var escuro := ColorRect.new()
	escuro.color = Color(0, 0, 0, 0.78)
	escuro.rect_size = Vector2(LARGURA, ALTURA)
	_mapa.add_child(escuro)
	_mapa_painel = Arte.painel(Arte.LARANJA, 0.96, 36, 3, 30)
	pos(_mapa_painel, 60, 470, 960, 900)
	_mapa.add_child(_mapa_painel)
	_mapa_titulo = Arte.texto("FASE 1", 130, Color(1, 1, 1), 12, Arte.LARANJA)
	pos(_mapa_titulo, 60, 492, 960, 176)
	_mapa.add_child(_mapa_titulo)
	_mapa_sub = Arte.texto("", 40, Arte.LARANJA_CLARO, 5, Color(0, 0, 0))
	pos(_mapa_sub, 60, 668, 960, 64)
	_mapa.add_child(_mapa_sub)
	for i in 3:
		var card = Panel.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pos(card, 94 + i * 306, 768, 280, 300)
		card.rect_pivot_offset = Vector2(140, 150)
		var n = Arte.texto(Ajustes.NOMES_FASE[i], 36, CORES_FASE[i], 4, Color(0, 0, 0))
		n.name = "N"
		pos(n, 0, 22, 280, 54)
		card.add_child(n)
		var m = Arte.texto("", 40, Color(1, 1, 1), 5, Color(0, 0, 0))
		m.name = "M"
		pos(m, 0, 86, 280, 60)
		card.add_child(m)
		var tp = Arte.texto("", 28, Color(0.85, 0.88, 0.95), 3, Color(0, 0, 0))
		tp.name = "T"
		pos(tp, 0, 150, 280, 44)
		card.add_child(tp)
		var st = Arte.texto("", 32, Color(1, 1, 1), 4, Color(0, 0, 0))
		st.name = "S"
		pos(st, 0, 214, 280, 56)
		card.add_child(st)
		_mapa.add_child(card)
		_mapa_cards.append(card)
	_mapa_info = Arte.texto("", 31, Color(0.92, 0.92, 0.96), 4, Color(0, 0, 0))
	_mapa_info.autowrap = true
	pos(_mapa_info, 90, 1090, 900, 110)
	_mapa.add_child(_mapa_info)
	_mapa_prepare = Arte.texto("PREPARE-SE!", 62, Color(1, 1, 1), 7, Arte.LARANJA)
	pos(_mapa_prepare, 60, 1232, 960, 96)
	_mapa.add_child(_mapa_prepare)


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
	var s := Arte.texto("3 FASES  •  BATA A META", 36, Color(0.85, 0.9, 1.0), 4, Color(0, 0, 0))
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
## dados: "de_novo" = jogar de novo a partir do resultado (sem a tela de
## carregar: a arena já está ali).
func entrar(dados := {}) -> void:
	.entrar(dados)
	estado = ENTRADA
	fases = Ajustes.fases()
	fase = 0
	pontos = 0
	cestas = 0
	maior_combo = 0
	pontos_fase = [0, 0, 0]
	cestas_fase = [0, 0, 0]
	combo_fase = [0, 0, 0]
	passou = [false, false, false]
	_recorde_antigo = Ajustes.recorde
	_festa_feita = false
	_combo = 0
	_mult = 1
	_grade.limpar()
	_bolas_fx.limpar()
	_holofotes.modo(Holofotes.NORMAL)
	_resultado.esconder()
	_mapa.visible = false
	_contagem.visible = false
	_banner.visible = false
	_combo_banner.visible = false
	_ouro.visible = false
	_ouro_ativo = false
	_escuro.modulate.a = 0.0
	_sair_slam(true)
	_alertar(false)
	_mat_fundo.set_shader_param("apagado", 0.0)
	_disp_high.valor = Ajustes.recorde
	_disp_atual.valor = 0
	_preparar_fase_hud(0)
	_atualizar_lista_top()
	Sons.musica("jogo", 0.9)
	_aplicar_efeitos()
	Tela.medir(true)
	Ajustes.iniciar_partida()
	Arduino.led("STARTING")
	_entrada_e_mapa(dados.get("de_novo", false))


func sair() -> void:
	.sair()
	Tela.medir(false)
	_resultado.esconder()
	_grade.limpar()
	_bolas_fx.limpar()


func aquecer() -> void:
	# tudo aparece uma vez (a capa cobre)
	_entrada.visible = true
	_mapa.visible = true
	_banner.visible = true
	_combo_banner.visible = true
	_contagem.visible = true
	_ouro.visible = true
	_borda.visible = true
	_borda.modulate.a = 1.0
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
	_bolas_fx.soltar(3, Arte.LARANJA, BolasCaindo.FOGO)
	_holofotes.flashes(4)
	for f in _flutuantes:
		f.visible = true
	_resultado.aquecer()
	yield(get_tree().create_timer(0.12), "timeout")
	_entrada.visible = false
	_mapa.visible = false
	_banner.visible = false
	_combo_banner.visible = false
	_contagem.visible = false
	_ouro.visible = false
	_borda.visible = false
	for f in _flutuantes:
		f.visible = false
	_grade.limpar()
	_bolas_fx.limpar()
	_resultado.esconder()


func _entrada_e_mapa(de_novo: bool) -> void:
	var s := sessao
	if not de_novo:
		_entrada.visible = true
		_entrada.modulate.a = 1.0
		_entrada.rect_position.y = 0.0
		_entrada_barra.rect_size.x = 0.0
		Sons.tocar("vento", -4.0)
		var tw := create_tween()
		tw.tween_property(_entrada_barra, "rect_size:x", 712.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		# a tela de carregar sobe e revela a arena (sem ficar transparente)
		tw.tween_property(_entrada, "rect_position:y", -ALTURA, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		yield(tw, "finished")
		if not vale(s):
			return
		_entrada.visible = false
		_entrada.rect_position.y = 0.0
	# a arena "liga" como neon: cada parte acende piscando
	Sons.tocar("neon", -2.0)
	var partes := [_fundo, _grade, _anel, _crono]
	for c in _hud.get_children():
		partes.append(c)
	var k := 0
	for p in partes:
		if p is CanvasItem and p.visible and p != _bola_card:
			neon_liga(p, 0.03 * k + _r.randf_range(0.0, 0.14))
			k += 1
	yield(get_tree().create_timer(0.55), "timeout")
	if not vale(s):
		return
	_anel.varrer(0.9)
	_iniciar_fase(0)


# ===================================================================== fases
## Mostra o MAPA DAS FASES e, sozinho, segue para a contagem.
func _iniciar_fase(i: int) -> void:
	fase = i
	estado = MAPA
	_mapa_t = 0.0
	_mapa_pronto = false
	_preparar_fase_hud(i)
	var f: Dictionary = fases[i]
	var final := i == FINAL
	var cor: Color = CORES_FASE[i]
	_mapa_titulo.text = Ajustes.NOMES_FASE[i]
	Arte.pintar(_mapa_titulo, Color(1, 1, 1), cor)
	_mapa_painel.add_stylebox_override("panel", Arte.estilo_neon(cor, 0.96, 36, 3, 30))
	if final:
		_mapa_sub.text = "SEM META: FAÇA O MÁXIMO!"
		_mapa_info.text = "FINAL: MULTIPLICADOR TURBINADO!\nCOMEÇA EM x2  •  MODO ENTERRADA COM 6 SEGUIDAS"
	else:
		_mapa_sub.text = "FAÇA %d PONTOS EM %d SEGUNDOS" % [int(f["meta"]), int(f["tempo"])]
		if i == 0:
			_mapa_info.text = "CESTAS SEGUIDAS MULTIPLICAM OS PONTOS\nx2  •  x3  •  x4 = MODO ENTERRADA" if Ajustes.modo_arcade else "CADA CESTA VALE 2 PONTOS"
		else:
			_mapa_info.text = "META %d  •  VOCÊ TEM %d PONTOS\nBATA A META PARA CHEGAR NA FINAL" % [_alvo, pontos]
	for k in 3:
		var card: Panel = _mapa_cards[k]
		var fk: Dictionary = fases[k]
		var ck: Color = CORES_FASE[k]
		card.get_node("M").text = "META %d" % int(fk["meta"]) if k < FINAL else "VALE TUDO"
		card.get_node("T").text = "%d SEGUNDOS" % int(fk["tempo"])
		var st: Label = card.get_node("S")
		if k < i:
			st.text = "OK  %d PTS" % int(pontos_fase[k])
			st.add_color_override("font_color", VERDE)
			card.add_stylebox_override("panel", Arte.estilo_neon(VERDE, 0.9, 26, 2, 8))
			tom(card, 0.75)
		elif k == i:
			st.text = "AGORA!"
			st.add_color_override("font_color", Color(1, 1, 1))
			card.add_stylebox_override("panel", Arte.estilo_neon(ck, 0.9, 26, 5, 26, 0.2))
			tom(card, 1.0)
		else:
			st.text = "DEPOIS"
			st.add_color_override("font_color", Color(0.7, 0.7, 0.75))
			card.add_stylebox_override("panel", Arte.estilo_neon(ck, 0.9, 26, 2, 8))
			tom(card, 0.6)
		card.rect_scale = Vector2.ONE
	# o mapa entra subindo de baixo (sem ficar transparente)
	_mapa.visible = true
	_mapa.modulate.a = 1.0
	_mapa.rect_position.y = ALTURA
	var tw := create_tween()
	tw.tween_property(_mapa, "rect_position:y", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# o nome da fase entra batendo
	_mapa_titulo.rect_pivot_offset = _mapa_titulo.rect_size * 0.5
	_mapa_titulo.rect_scale = Vector2(2.6, 2.6)
	_mapa_titulo.modulate.a = 1.0
	var tt := create_tween().set_parallel(true)
	tt.tween_property(_mapa_titulo, "rect_scale", Vector2.ONE, 0.32).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var atual: Panel = _mapa_cards[i]
	var tc := create_tween()
	tc.tween_interval(0.42)
	tc.tween_property(atual, "rect_scale", Vector2(1.1, 1.1), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tc.tween_property(atual, "rect_scale", Vector2.ONE, 0.2)
	Arduino.led("MENU_LOCK")
	var s := sessao
	yield(get_tree().create_timer(0.36), "timeout")
	if not vale(s) or estado != MAPA:
		return
	Sons.tocar("impacto", -2.0)
	_tremer(14.0)
	_onda().disparar(Vector2(540, 580), 6, 1.2, false, cor)
	_grade.disparar(Vector2(540, 580), 6, false, cor)
	if final:
		Sons.tocar("trovao", -3.0)
		var ta := create_tween()
		ta.tween_method(self, "_azul", 0.0, 0.8, 0.12)
		ta.tween_method(self, "_azul", 0.8, 0.0, 0.5)
	yield(get_tree().create_timer(0.3), "timeout")
	if vale(s) and estado == MAPA:
		_mapa_pronto = true


## Acabou o tempo do mapa (ou a cesta/START pulou): a contagem.
func _pular_mapa() -> void:
	if estado != MAPA or not _mapa_pronto:
		return
	_mapa_pronto = false
	estado = CONTAGEM
	var s := sessao
	Sons.tocar("selecao")
	var tw := create_tween()
	tw.tween_property(_mapa, "rect_position:y", -ALTURA, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	yield(tw, "finished")
	if not vale(s):
		return
	_mapa.visible = false
	_mapa.rect_position.y = 0.0
	# contagem 3-2-1: ondas vindo das bordas para o centro
	_contagem.visible = true
	var lbl := Arte.rotulo_de(_contagem)
	var et := create_tween()
	et.tween_property(_escuro, "modulate:a", 0.45, 0.2)
	var cor_fase: Color = CORES_FASE[fase]
	for n in [3, 2, 1]:
		lbl.text = str(n)
		var prog = float(3 - n) / 2.0
		var cor = cor_fase.linear_interpolate(Color(1.0, 0.25, 0.02), prog * 0.6)
		Arte.pintar(lbl, Color(1, 1, 1), cor)
		_onda().disparar(Vector2(540, 960), 1, lerp(0.75, 1.45, prog), true, cor)
		_grade.disparar(Vector2(540, 960), 1, true, cor)
		Sons.tocar("bip")
		_contagem.scale = Vector2(0.3, 0.3)
		_contagem.modulate.a = 1.0
		var tc = create_tween()
		tc.tween_property(_contagem, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		yield(get_tree().create_timer(0.66), "timeout")
		if not vale(s):
			return
		var tf = create_tween()
		tf.tween_property(_contagem, "scale", Vector2.ZERO, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
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
	tv.tween_property(_contagem, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	var te := create_tween()
	te.tween_property(_escuro, "modulate:a", 0.0, 0.3)
	Sons.tocar("apito")
	Sons.tocar("bip_vai", -4.0)
	_onda().disparar(CESTA, 3, 1.2)
	_grade.disparar(CESTA, 3)
	_tremer(10.0)
	_comecar_tempo()


## HUD da fase que vai começar (antes do mapa: o display já mostra a meta).
func _preparar_fase_hud(i: int) -> void:
	var f: Dictionary = fases[i] if i < fases.size() else {"tempo": 40, "meta": 0}
	_total = float(f["tempo"])
	_tempo = _total
	_alvo = pontos + int(f["meta"]) if i < FINAL else 0
	_ajustar_crono()
	_crono.valor = int(_total)
	_anel.definir(1.0)
	_anel.alerta(false)
	_nome_fase.text = Ajustes.NOMES_FASE[i]
	_nome_fase.add_color_override("font_color", CORES_FASE[i])
	_mult_titulo.text = "MULTIPLICADOR TURBINADO" if i == FINAL and Ajustes.modo_arcade else "MULTIPLICADOR"
	_combo = 0
	_mult = _mult_base()
	_atualizar_mult(false)
	for k in 3:
		_atualizar_card(k)
	_atualizar_alvo()


func _comecar_tempo() -> void:
	estado = JOGANDO
	_aviso_prioridade = 0
	_tempo = _total
	_decorrido = 0.0
	_ultima_cesta = -100.0
	_uuuh_feito = false
	_combo = 0
	_mult = _mult_base()
	_segundo_mostrado = -1
	_ouro_ativo = false
	_ouro.visible = false
	_sair_slam(true)
	_alertar(false)
	_grade.modo_recorde(_festa_feita, CESTA - Vector2(0, 30))
	_atualizar_mult(false)
	_atualizar_alvo()
	_agendar_ouro()
	Arduino.led("PLAY")


func _agendar_ouro() -> void:
	_ouro_em = []
	if not (Ajustes.modo_arcade and Ajustes.bola_de_ouro) or _total < 20.0:
		return
	var vezes := 2 if _total >= 50.0 else 1
	for i in vezes:
		var faixa0 = 0.22 + 0.42 * i / vezes
		var faixa1 = faixa0 + 0.42 / vezes
		_ouro_em.append(_total * _r.randf_range(faixa0, faixa1))


# ===================================================================== cesta
func _cesta() -> void:
	if estado == MAPA:
		_pular_mapa()
		return
	if estado != JOGANDO:
		return
	if _decorrido - _ultima_cesta < Ajustes.trava_sensor:
		return
	var intervalo := _decorrido - _ultima_cesta
	_ultima_cesta = _decorrido
	_uuuh_feito = false
	_combo = _combo + 1 if intervalo <= Ajustes.janela_combo else 1
	maior_combo = int(max(maior_combo, _combo))
	combo_fase[fase] = int(max(combo_fase[fase], _combo))
	cestas += 1
	cestas_fase[fase] += 1
	var mult_antes := _mult
	var ganho := 2
	var ouro := false
	if Ajustes.modo_arcade:
		_mult = _mult_do_combo(_combo, fase == FINAL)
		ganho = _mult
		if _ouro_ativo:
			ouro = true
			ganho += 5
			_pegar_ouro()
	_somar(ganho)
	pop(_disp_atual, 1.3, 0.24)
	# efeitos
	var nivel := _combo
	_conferir_recorde()
	if _festa_feita:
		Arduino.led("BOOST")
		_grade.disparar(CESTA, 9, false, Arte.OURO)
		_onda().disparar(CESTA, 1, 1.15, false, null, true)
	else:
		Arduino.led("HIT")
		_grade.disparar(CESTA, nivel)
		_onda().disparar(CESTA, nivel, 1.0)
		if nivel >= 9:
			_grade.disparar(CESTA, nivel, false, null, 0.14)
	_onda_no_fundo(CESTA, Color(1.0, 0.75, 0.35))
	# a bola sai da cesta e cai para fora da tela (com combo, várias)
	var tipo_bola := BolasCaindo.NORMAL
	if ouro or _festa_feita:
		tipo_bola = BolasCaindo.OURO
	elif _slam:
		tipo_bola = BolasCaindo.FOGO
	_bolas_fx.soltar(_bolas_da_cesta(nivel), Grade.cor_do_combo(nivel), tipo_bola)
	_holofotes.energia = 0.25 + min(nivel, 10) * 0.075
	if nivel >= 6:
		_holofotes.flashes(2 + int(min(nivel, 14) / 4))
	_faisca().restart()
	Sons.tocar("combo_%d" % int(clamp(nivel, 1, 12)))
	_mostrar_combo(nivel)
	_flutuar("+%d" % ganho, Arte.OURO if ouro else (Grade.cor_do_combo(nivel) if nivel >= 3 else Arte.LARANJA))
	_tremer(4.0 + min(nivel, 12) * 0.9)
	for b in _barras:
		b.energia = clamp(0.2 + _combo * 0.08, 0.2, 1.0)
	if _mult > mult_antes:
		_subiu_mult()
	_atualizar_mult(true)
	_conferir_pass()
	_atualizar_alvo()


## Quantas bolas saem da cesta: mais com o combo (no MODO ENTERRADA, uma a mais).
## EFEITOS LEVES (qualidade automática numa TV Box que não segurou 60
## quadros): sem os holofotes e sem os brilhos/rastros das bolas que caem.
func _aplicar_efeitos() -> void:
	var leves := Ajustes.leves()
	_holofotes.visible = not leves
	_bolas_fx.leves = leves


func _bolas_da_cesta(nivel: int) -> int:
	var n := 1
	if nivel >= 10:
		n = 4
	elif nivel >= 6:
		n = 3
	elif nivel >= 3:
		n = 2
	return n + (1 if _slam else 0)


## Soma pontos (na partida e na fase) e mostra.
func _somar(n: int) -> void:
	pontos += n
	pontos_fase[fase] += n
	_disp_atual.valor = pontos
	_atualizar_card(fase)


func _mult_base() -> int:
	return 2 if fase == FINAL and Ajustes.modo_arcade else 1


## 3 seguidas = x2, 6 = x3, 10 = x4. Na FINAL (turbo): x2 já de saída,
## 3 = x3, 6 = x4.
static func _mult_do_combo(c: int, turbo := false) -> int:
	if turbo:
		if c >= 6:
			return 4
		if c >= 3:
			return 3
		return 2
	if c >= 10:
		return 4
	if c >= 6:
		return 3
	if c >= 3:
		return 2
	return 1


var _onda_fundo := 99.0


func _onda_no_fundo(centro: Vector2, cor: Color) -> void:
	_mat_fundo.set_shader_param("onda_centro", centro)
	_mat_fundo.set_shader_param("cor_onda", cor)
	_onda_fundo = 0.0


func _onda() -> OndaLuz:
	var o: OndaLuz = _ondas[_onda_proxima]
	_onda_proxima = (_onda_proxima + 1) % _ondas.size()
	return o


func _faisca() -> CPUParticles2D:
	var f: CPUParticles2D = _faiscas[_faisca_proxima]
	_faisca_proxima = (_faisca_proxima + 1) % _faiscas.size()
	f.emitting = true
	return f


func _flutuar(texto: String, cor: Color, de := Vector2(-1, -1)) -> void:
	var f: Node2D = _flutuantes[_flutua_proximo]
	_flutua_proximo = (_flutua_proximo + 1) % _flutuantes.size()
	var l := Arte.rotulo_de(f)
	l.text = texto
	Arte.pintar(l, Color(1, 1, 1), cor)
	f.visible = true
	f.position = de if de.x >= 0.0 else Vector2(CESTA.x + _r.randf_range(-150, 150), 1075.0)
	f.modulate.a = 1.0
	f.scale = Vector2(0.5, 0.5)
	# entra crescendo, sobe e sai ENCOLHENDO (nunca meio transparente)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(f, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "position:y", f.position.y - 135.0, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "scale", Vector2.ZERO, 0.2).set_delay(0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(f, "set_visible", [false])


func _mostrar_combo(nivel: int) -> void:
	var txt := "BOA!"
	match nivel:
		1:
			txt = "BOA!"
		2, 3:
			txt = "%d SEGUIDAS!" % nivel
		4:
			txt = "ESQUENTOU 4!"
		5:
			txt = "PEGOU FOGO 5!"
		6, 7, 8:
			txt = "EM CHAMAS %d!" % nivel
		9, 10, 11, 12:
			txt = "IMPARÁVEL %d!" % nivel
		_:
			txt = "LENDÁRIO %d!" % nivel
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
	_combo_banner.modulate.a = 1.0
	_combo_banner.scale = Vector2(0.35, 0.35)
	_combo_banner.rotation = _r.randf_range(-0.06, 0.06)
	# entra crescendo e sai encolhendo: o texto fica sempre inteiro
	_combo_tw = create_tween()
	_combo_tw.tween_property(_combo_banner, "scale", Vector2(1.05, 1.05), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_combo_tw.tween_interval(0.42)
	_combo_tw.tween_property(_combo_banner, "scale", Vector2.ZERO, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_combo_tw.tween_callback(_combo_banner, "set_visible", [false])


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
	if not Ajustes.modo_arcade:
		txt = str(_combo)
		_mult_titulo.text = "SEQUÊNCIA"
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


# ================================================== score pass, recorde...
## Alcançou o META da fase: PASSOU! (a fase continua valendo).
func _conferir_pass() -> void:
	if fase >= FINAL or passou[fase] or pontos < _alvo:
		return
	passou[fase] = true
	Sons.tocar("passou", 1.0)
	Arduino.led("BOOST")
	_avisar("PASSOU!  RUMO À %s" % Ajustes.NOMES_FASE[fase + 1], VERDE, 1.5, 3)
	_grade.disparar(PASS_POS, 9, false, VERDE, 0.05)
	_onda().disparar(PASS_POS, 6, 1.3, false, VERDE)
	_onda_no_fundo(PASS_POS, VERDE)
	_tremer(12.0)
	pop(_disp_pass, 1.45, 0.4)
	pop(_lbl_pass, 1.3, 0.3)
	_atualizar_card(fase)
	pop(_cards[fase], 1.08, 0.3)


func _conferir_recorde() -> void:
	if pontos <= Ajustes.recorde:
		return
	Ajustes.tentar_recorde(pontos)
	_disp_high.valor = Ajustes.recorde
	if not _festa_feita and _recorde_antigo >= 3:
		_festa_feita = true
		_festa_recorde()


func _festa_recorde() -> void:
	Arduino.led("RECORD")
	Sons.tocar("recorde")
	_grade.modo_recorde(true, CESTA - Vector2(0, 30))
	_avisar("RECORDE BATIDO!", Arte.OURO, 1.6, 4)
	_borda.visible = true
	var tw := create_tween()
	tw.tween_property(_borda, "modulate:a", 1.0, 0.12)
	tw.tween_property(_borda, "modulate:a", 0.0, 0.5)
	tw.tween_property(_borda, "modulate:a", 0.8, 0.12)
	tw.tween_property(_borda, "modulate:a", 0.0, 0.6)
	_faiscas_ouro.position = CESTA
	_faiscas_ouro.restart()
	_faiscas_ouro.emitting = true
	_holofotes.modo(Holofotes.RECORDE)
	_holofotes.flashes(8)
	_bolas_fx.soltar(4, Arte.OURO, BolasCaindo.OURO)
	_tremer(16.0)


## META (caixa da esquerda) e a frase da caixa central.
func _atualizar_alvo() -> void:
	var recorde_meu := _festa_feita or (_recorde_antigo < 3 and pontos > _recorde_antigo and pontos > 0 and pontos >= Ajustes.recorde)
	if fase < FINAL:
		_disp_pass.valor = _alvo
		if passou[fase]:
			_lbl_pass.text = "PASSOU!"
			_lbl_pass.add_color_override("font_color", VERDE)
			_disp_pass.cor = VERDE
			_sub_fase.text = "VOCÊ É O RECORDE!" if recorde_meu else "PASSOU! SIGA PONTUANDO"
		else:
			_lbl_pass.text = "META"
			_lbl_pass.add_color_override("font_color", Arte.CIANO)
			_disp_pass.cor = Arte.CIANO
			_sub_fase.text = "FALTAM %d PARA PASSAR" % (_alvo - pontos)
	else:
		_lbl_pass.text = "RECORDE"
		_lbl_pass.add_color_override("font_color", Arte.OURO)
		_disp_pass.cor = Arte.OURO
		_disp_pass.valor = Ajustes.recorde
		if recorde_meu:
			_sub_fase.text = "VOCÊ É O RECORDE DA ARENA!"
		elif Ajustes.recorde > 0:
			_sub_fase.text = "FALTAM %d PARA O RECORDE" % (Ajustes.recorde + 1 - pontos)
		else:
			_sub_fase.text = "FAÇA O PRIMEIRO RECORDE!"


var _aviso_prioridade := 0
var _aviso_ate := 0.0


## Aviso na faixa central. Um aviso mais importante (passou, recorde, slam,
## tempo) não é coberto por um menos importante enquanto aparece.
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
	_banner.modulate.a = 1.0
	_banner.scale = Vector2(0.6, 0.05)
	# abre e fecha na vertical (como uma faixa de LED), sem transparência
	_banner_tw = create_tween()
	_banner_tw.tween_property(_banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tw.tween_interval(duracao)
	_banner_tw.tween_property(_banner, "scale", Vector2(1.04, 0.0), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_banner_tw.tween_callback(_banner, "set_visible", [false])


func _tremer(forca: float) -> void:
	_tremor = max(_tremor, forca)


# ================================================================ MODO ENTERRADA
func _entrar_slam() -> void:
	_slam = true
	_proximo_raio = 0.0
	Sons.tocar("trovao")
	_avisar("MODO ENTERRADA!  PONTOS x4", Arte.CIANO, 1.4, 3)
	_tremer(18.0)
	_holofotes.modo(Holofotes.SLAM)
	_holofotes.flashes(6)
	_proxima_bola_slam = _t + 0.3
	var tw := create_tween().set_parallel(true)
	tw.tween_method(self, "_azul", 0.0, 1.0, 0.35)
	_grade.base = 1.9
	_grade.definir_cor_base(Color(0.15, 0.5, 1.0))
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
		_grade.definir_cor_base(Arte.LARANJA)
	if _holofotes != null:
		_holofotes.modo(Holofotes.RECORDE if _festa_feita else Holofotes.NORMAL)
	for b in _barras:
		b.cores(Color(1.0, 0.32, 0.02), Color(1.0, 0.85, 0.4))


func _azul(v: float) -> void:
	_mat_fundo.set_shader_param("azul", v)


func _apagar(v: float) -> void:
	_mat_fundo.set_shader_param("apagado", v)


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
	_ouro_txt.visible = true
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
	_ouro_txt.visible = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_ouro, "scale", Vector2(1.8, 1.8), 0.35)
	tw.tween_property(_ouro, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(_ouro, "set_visible", [false])


func _perder_ouro() -> void:
	_ouro_ativo = false
	var tw := create_tween()
	tw.tween_property(_ouro, "scale", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(_ouro, "set_visible", [false])


# ========================================================== últimos segundos
func _alertar(ligado: bool) -> void:
	_alerta = ligado
	_anel.alerta(ligado)
	_crono.cor = Arte.VERMELHO_ALERTA if ligado else Arte.LARANJA
	if _tempo_lbl != null:
		Arte.pintar(Arte.rotulo_de(_tempo_lbl), Color(1, 1, 1), Arte.VERMELHO_ALERTA if ligado else Arte.LARANJA)
	if not ligado:
		_mat_fundo.set_shader_param("alerta", 0.0)


# ================================================================ fim da fase
func _fim_da_fase() -> void:
	estado = FIM_FASE
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
	_combo = 0
	_mult = _mult_base()
	_atualizar_mult(true)
	_mult_barra.rect_scale.x = 0.0
	for b in _barras:
		b.energia = 0.2
	_avisar("TEMPO!", CORES_FASE[fase], 1.0, 9)
	yield(get_tree().create_timer(1.4), "timeout")
	if not vale(s):
		return
	if fase == FINAL:
		_mostrar_resultado(true)
		return
	if not passou[fase]:
		# NÃO PASSOU: a arena apaga e é o fim
		Sons.tocar("fim_jogo")
		# a torcida: vaia de verdade na fase 1, "uuuh" na fase 2
		Sons.tocar("vaia" if fase == 0 else "vaia_curta", -1.0)
		_avisar("NÃO PASSOU!  FALTARAM %d" % (_alvo - pontos), Arte.VERMELHO_ALERTA, 2.0, 9)
		_atualizar_card(fase)
		var ta := create_tween()
		ta.tween_method(self, "_apagar", 0.0, 0.6, 0.8)
		_tremer(8.0)
		yield(get_tree().create_timer(2.5), "timeout")
		if vale(s):
			_mostrar_resultado(false)
		return
	Sons.tocar("fase")
	_avisar("%s CONCLUÍDA!" % Ajustes.NOMES_FASE[fase], VERDE, 1.3, 9)
	_atualizar_card(fase)
	_onda().disparar(Vector2(540, 1772), 9, 1.3, false, VERDE)
	_grade.disparar(Vector2(540, 1772), 9, false, VERDE)
	yield(get_tree().create_timer(1.7), "timeout")
	if not vale(s):
		return
	# BÔNUS DE SEQUÊNCIA: o maior combo da fase vira pontos, contados
	var bonus: int = int(combo_fase[fase]) if Ajustes.modo_arcade and int(combo_fase[fase]) >= 3 else 0
	if bonus > 0:
		_avisar("BÔNUS DE SEQUÊNCIA +%d" % bonus, Arte.OURO, 1.6, 9)
		Sons.tocar("ouro", -4.0)
		var passos := int(min(bonus, 20))
		var resto := bonus
		for k in passos:
			var n := int(ceil(float(resto) / float(passos - k)))
			resto -= n
			_somar(n)
			Sons.tocar("tique", -6.0, 1.0 + 0.04 * k)
			pop(_disp_atual, 1.12, 0.1)
			yield(get_tree().create_timer(0.06), "timeout")
			if not vale(s):
				return
		_conferir_recorde()
		_flutuar("+%d" % bonus, Arte.OURO, Vector2(866, 765))
		yield(get_tree().create_timer(1.0), "timeout")
		if not vale(s):
			return
	_iniciar_fase(fase + 1)


func _mostrar_resultado(campeao: bool) -> void:
	estado = RESULTADO
	Tela.medir(false)
	_grade.modo_recorde(false)
	_atualizar_card(fase)
	var posicao := Ajustes.registrar_resultado(pontos, cestas, fase + 1)
	var recorde := pontos > _recorde_antigo and pontos > 0 and pontos >= Ajustes.recorde
	# o clima do fim: VAIA (não passou da fase 1 ou nenhum ponto: nada de
	# aplauso nem confete), FESTA (campeão ou recorde de quem passou da 1)
	# ou NEUTRO (passou da 1 e parou na 2: sem vaia e sem festa)
	var clima := "neutro"
	if fase == 0 or pontos == 0:
		clima = "vaia"
		recorde = false
	elif campeao or recorde:
		clima = "festa"
	if clima == "festa":
		Sons.musica("podio")
	else:
		Sons.parar_musica(0.8)
	Arduino.led("RECORD" if clima == "festa" else "OFF")
	_atualizar_lista_top()
	_resultado.mostrar({"pontos": pontos, "cestas": cestas, "maior_combo": maior_combo, "fase": fase,
		"campeao": campeao, "passou": passou, "pontos_fase": pontos_fase, "cestas_fase": cestas_fase,
		"combo_fase": combo_fase, "recorde": recorde, "posicao": posicao, "clima": clima})


func _resultado_acabou(acao: String) -> void:
	if not ativo:
		return
	if acao == "reiniciar":
		if not Ajustes.pode_jogar():
			Sons.tocar("quebra")
			return
		Ajustes.gastar_credito()
		Sons.tocar("selecao")
		_resultado.esconder()
		entrar({"de_novo": true})
	else:
		ir("abertura")


# ================================================================ HUD helpers
func _ajustar_crono() -> void:
	var dig := 3 if _total >= 100 else 2
	if _crono.digitos != dig:
		_crono.configurar(dig, 150 if dig == 2 else 112, _crono.cor, -1.0, Display7.PLACA_REDONDA)


## O cartão da fase no rodapé: a jogar, jogando, passou / não passou.
func _atualizar_card(i: int) -> void:
	var card: Panel = _cards[i]
	var cor: Color = CORES_FASE[i]
	var info: Label = card.get_node("Info")
	var pts: Label = card.get_node("Pts")
	var meta := int(fases[i]["meta"]) if i < fases.size() else 0
	var jogada := i < fase or (i == fase and estado in [FIM_FASE, RESULTADO])
	if i > fase:
		pts.text = "-"
		info.text = "META %d" % meta if i < FINAL else "VALE TUDO"
		info.add_color_override("font_color", Color(0.7, 0.7, 0.75))
		card.add_stylebox_override("panel", Arte.estilo_neon(cor, 0.55, 22, 2, 6, 0.06))
		tom(card, 0.62)
		return
	pts.text = str(pontos_fase[i])
	if i < FINAL and passou[i]:
		info.text = "PASSOU"
		info.add_color_override("font_color", VERDE)
	elif i < FINAL and jogada:
		info.text = "NÃO PASSOU"
		info.add_color_override("font_color", Arte.VERMELHO_ALERTA)
	else:
		info.text = "META %d" % meta if i < FINAL else ("FIM" if jogada else "VALE TUDO")
		info.add_color_override("font_color", Arte.LARANJA_CLARO)
	if jogada:
		var c: Color = VERDE if (i == FINAL or passou[i]) else Arte.VERMELHO_ALERTA
		card.add_stylebox_override("panel", Arte.estilo_neon(c, 0.7, 22, 2, 8, 0.1))
		tom(card, 0.9)
	else:
		card.add_stylebox_override("panel", Arte.estilo_neon(cor, 0.85, 22, 4, 24, 0.16))
		tom(card, 1.0)


func _atualizar_lista_top() -> void:
	var lista: Array = Ajustes.ranking_dia
	for k in _lista_top.get_child_count():
		var l: Label = _lista_top.get_child(k)
		if k < lista.size():
			l.text = "%dº   %d" % [k + 1, int(lista[k].get("pontos", 0))]
		else:
			l.text = "%dº   -" % (k + 1)


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
	# a bola quicando em cima da fase atual (rodapé)
	if estado in [MAPA, CONTAGEM, JOGANDO, FIM_FASE]:
		var card: Panel = _cards[fase]
		_bola_card.visible = true
		_bola_card.position = card.rect_position + Vector2(card.rect_size.x - 34, -26 - abs(sin(_t * 4.0)) * 22.0)
	else:
		_bola_card.visible = false
	# segurar SELECT 3 s: o operador encerra a partida
	if estado != RESULTADO and Controles.segurando("input_select"):
		_select_t += delta
		if _select_t > 3.0:
			_select_t = 0.0
			ir("abertura")
			return
	else:
		_select_t = 0.0
	match estado:
		MAPA:
			_mapa_t += delta
			tom(_mapa_prepare, 0.8 + 0.2 * (0.5 + 0.5 * sin(_t * 6.0)))
			if _mapa_t >= MAPA_SEGUNDOS:
				_pular_mapa()
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
				if fase < FINAL and not passou[fase]:
					_avisar("ÚLTIMOS 10 s! FALTAM %d" % (_alvo - pontos), Arte.VERMELHO_ALERTA, 1.2, 2)
				else:
					_avisar("ÚLTIMOS 10 SEGUNDOS!", Arte.VERMELHO_ALERTA, 1.2, 2)
			Sons.tocar("tique", -2.0)
			pop(_crono, 1.12, 0.2)
			if seg <= 5:
				Sons.tocar("batida", -3.0)
	if _alerta:
		_mat_fundo.set_shader_param("alerta", 0.35 + 0.3 * sin(_t * 9.0))
	# MODO ENTERRADA: a máquina transborda - bolas de fogo saindo da cesta
	if _slam and _t >= _proxima_bola_slam:
		_proxima_bola_slam = _t + _r.randf_range(0.45, 0.85)
		_bolas_fx.soltar(1, Arte.CIANO, BolasCaindo.FOGO)
	# combo: a barrinha esvazia; acabou a janela, o combo acaba
	if _combo > 0:
		var resta := 1.0 - (_decorrido - _ultima_cesta) / Ajustes.janela_combo
		if resta <= 0.0:
			if _mult > _mult_base():
				Sons.tocar("quebra", -3.0)
			_combo = 0
			_mult = _mult_base()
			_sair_slam()
			_atualizar_mult(true)
			for b in _barras:
				b.energia = 0.2
			_mult_barra.rect_scale.x = 0.0
		else:
			_mult_barra.rect_scale.x = resta
	else:
		_mult_barra.rect_scale.x = 0.0
	# muito tempo sem cesta: a torcida faz "uuuh" (uma vez por seca)
	var seca := _decorrido - max(_ultima_cesta, 0.0)
	if seca > 7.0 and not _uuuh_feito and _tempo > 3.0:
		_uuuh_feito = true
		Sons.tocar("vaia_curta", -5.0)
	# dica quando ninguém acerta
	if seca > 6.0 and int(_t * 2.0) % 2 == 0:
		if _sub_fase.text != "ARREMESSE!":
			_sub_fase.text = "ARREMESSE!"
	elif _sub_fase.text == "ARREMESSE!":
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
	# MODO ENTERRADA: raios caindo na cesta
	if _slam:
		_proximo_raio -= delta
		if _proximo_raio <= 0.0:
			_proximo_raio = _r.randf_range(0.45, 1.0)
			_raio_slam()
	if _tempo <= 0.0:
		_fim_da_fase()


# ===================================================================== botões
## Nenhum botão é preciso: a CESTA faz tudo (pula o mapa, joga de novo).
## START (operador) faz o mesmo; uma FICHA no meio fica guardada.
func _unhandled_input(event: InputEvent) -> void:
	if not ativo:
		return
	if Controles.credito(event):
		Ajustes.adicionar_credito(1)
		Sons.tocar("moeda", -4.0)
		_resultado.ficha_inserida()
		return
	if Controles.cesta(event):
		if estado == RESULTADO:
			if _resultado.pode_reiniciar(true):
				_resultado_acabou("reiniciar")
		else:
			_cesta()
		return
	if Controles.start(event):
		if estado == MAPA:
			_pular_mapa()
		elif estado == RESULTADO and _resultado.pode_reiniciar(false):
			_resultado_acabou("reiniciar")
