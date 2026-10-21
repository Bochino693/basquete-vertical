extends Control
# =====================================================================
# TELA DE JOGO — BASKET (RETRATO, por turnos) — LAYOUT "ARCADE CHINA"
# Referência: cronômetro circular central (anel que esvazia),
# "ALL-TIME HIGH" no topo-esquerda, placar 7-segmentos embaixo,
# players empilhados na coluna ESQUERDA (atual destacado no topo).
# Efeito de cesta: GRADE DE TILES que afunda/ilumina em ONDA a partir
# do ponto da cesta + partículas modernas.
#
# Cesta = ação "input_pointer" (Zero Delay). Mouse oculto (tudo por input).
# =====================================================================

signal ponto_marcado(idx: int, total: int)
signal partida_encerrada(pontuacoes: Array)

# ---------- CONFIGURAÇÕES ----------
@export_range(1, 4) var num_jogadores: int = 4
@export var tempo_partida: float = 60.0
@export var usar_config_tempo_partida: bool = true
@export var caminho_config_basket: String = "user://basket_config.cfg"
@export var iniciar_automatico: bool = false
@export var caminho_fundo: String = "res://images/fundo_play.png"
@export var caminho_fonte: String = "res://fonts/titan.ttf"

# ---------- CESTA / PONTUAÇÃO ----------
@export var pontos_por_cesta: int = 1
@export var acao_cesta: String = "input_pointer"
@export var acao_start: String = "input_start"

@export var segundos_retorno_opening_podio: int = 12

# ---------- PONTE POWERSHELL / ARDUINO ----------
@export var porta_leds: String = "COM5"
@export var baud_leds: int = 9600
@export var usar_ponte_leds_no_play: bool = true

var _led_bridge_pid: int = -1
var _led_bridge_ps: String = "user://basket_led_bridge.ps1"


# ---------- COROA / VISUAL DE RECORDE ----------
var record_coroa_layer: CanvasLayer = null
var record_coroa_ctrl: Control = null



const _PS_BRIDGE_BASKET := """
param(
	[string]$Porta = "COM5",
	[int]$Baud = 9600,
	[string]$Arquivo = ""
)

$ErrorActionPreference = "SilentlyContinue"

try {
	$sp = New-Object System.IO.Ports.SerialPort($Porta, $Baud, "None", 8, "One")
	$sp.DtrEnable = $false
	$sp.RtsEnable = $false
	$sp.NewLine = "`n"
	$sp.WriteTimeout = 80
	$sp.Open()
} catch {
	exit 1
}

while ($true) {
	try {
		if (Test-Path -LiteralPath $Arquivo) {
			$cmd = [System.IO.File]::ReadAllText($Arquivo).Trim()
			[System.IO.File]::Delete($Arquivo)

			if ($cmd.Length -gt 0) {
				$partes = $cmd.Split(":")
				$limpo = $partes[0].Trim()
				$sp.WriteLine($limpo)
			}
		}
	} catch {}

	Start-Sleep -Milliseconds 8
}
"""


var lbl_podio_timer: Label = null
var _podio_retorno_token: int = 0

var box_players_score: VBoxContainer = null


var _fechando_tela: bool = false

# ---------- ÁUDIO ----------
@export var caminho_musica_fundo: String = "res://songs/bask_play.mp3"
@export var caminho_som_cesta: String = "res://songs/switch.mp3"
@export var caminho_apito_inicio: String = "res://songs/apito_inicio.mp3"
@export var caminho_end_bask: String = "res://songs/end_bask.mp3"
@export var volume_musica_db: float = -10.0
@export var volume_cesta_db: float = 0.0


# ---------- CONTAGEM REGRESSIVA ----------
@export var segundos_contagem: int = 3

# ---------- COMBO / BOA JOGADA ----------
@export var janela_combo_segundos: float = 4.0
@export var volume_combo_db: float = 2.0

@export var caminho_som_combo_1: String = "res://songs/combo_1.mp3"
@export var caminho_som_combo_2: String = "res://songs/combo_2.mp3"
@export var caminho_som_combo_3: String = "res://songs/combo_3.mp3"
@export var caminho_som_combo_4: String = "res://songs/combo_4.mp3"
@export var caminho_som_combo_5: String = "res://songs/combo_5.mp3"
@export var caminho_som_combo_6: String = "res://songs/combo_6.mp3"
@export var caminho_som_combo_7: String = "res://songs/combo_7.mp3"
@export var caminho_som_combo_8: String = "res://songs/combo_8.mp3"
@export var caminho_som_combo_9: String = "res://songs/combo_9.mp3"
@export var caminho_som_combo_10: String = "res://songs/combo_10.mp3"
@export var caminho_som_combo_11: String = "res://songs/combo_11.mp3"
@export var caminho_som_combo_12: String = "res://songs/combo_12.mp3"


# ---------- PÓDIO ----------
@export var mostrar_podio_automatico: bool = true
@export_file("*.tscn") var cena_abertura: String = "res://scenes/opening.tscn"

# ---------- CORES ----------
const CORES_PLAYERS := [
	Color(1.0, 0.27, 0.27),
	Color(0.27, 0.6, 1.0),
	Color(0.3, 1.0, 0.5),
	Color(1.0, 0.82, 0.2),
]
const NOMES_PADRAO := ["JOGADOR 1", "JOGADOR 2", "JOGADOR 3", "JOGADOR 4"]

# Paleta do tema "china arcade" (azul-elétrico + verde display + âmbar).
const COR_AZUL := Color(1.0, 0.38, 0.02)        # agora o tema base fica laranja
const COR_VERDE_DISPLAY := Color(1.0, 0.46, 0.04) # cronômetro/placar central em laranja
const COR_BRANCO_FX := Color(1.0, 1.0, 1.0)       # efeito que antes era verde
const COR_AMBAR := Color(1.0, 0.62, 0.08)

# Paleta do RECORDE (efeito dourado especial ao bater o recorde).
const COR_RECORDE := Color(1.0, 0.42, 0.02)        # laranja forte
const COR_RECORDE_BRILHO := Color(1.0, 0.68, 0.08) # brilho laranja quente
const COR_RECORDE_CLARO := Color(1.0, 0.88, 0.42)  # só para texto/realce


# ---------- BOOSTER DE RECORDE ----------
var _record_booster_ativo: bool = false
var _record_booster_pulso: float = 0.0

# ---------- LEDS ARDUINO / RGB ----------
@export var usar_leds_arduino: bool = true
@export var caminho_fila_leds_basket: String = "user://basket_led_cmd.txt"


# ---------- ESTADO ----------
var _pontos: Array = [0, 0, 0, 0]
var _nomes: Array = NOMES_PADRAO.duplicate()
var _turnos_finalizados: Array = [false, false, false, false]
var _jogador_atual: int = 0
var _tempo_restante: float = 0.0
var _rodando: bool = false

var _podio_ativo: bool = false
var _podio_layer: CanvasLayer = null

var _modal_turno_layer: CanvasLayer = null
var _modal_turno_ativo: bool = false
var _modal_turno_pronto: bool = false

var transicao_root: Control = null

# ---------- NÓS HUD ----------
var fundo: TextureRect
var _hud: CanvasLayer
var _efeitos: CanvasLayer

var crono_ring: Control = null          # anel circular do cronômetro (desenhado)
var lbl_crono: Label = null             # número grande dentro do anel
var lbl_high_titulo: Label = null       # "ALL-TIME HIGH"
var lbl_high_valor: Label = null        # recorde em 7-seg
var lbl_players_titulo: Label = null    # "PLAYERS SCORE"
var lbl_meta_titulo: Label = null       # "SCORE PASS"
var lbl_meta_valor: Label = null        # meta (7-seg amarelo)
var lbl_atual_titulo: Label = null      # "CURRENT SCORE"
var lbl_atual_pontos: Label = null      # pontos atuais (7-seg verde)
var painel_placar: Panel = null         # faixa do placar embaixo do anel

var painel_score_pass: Panel = null     # bloco esquerdo abaixo do cronômetro
var painel_current_score: Panel = null  # bloco direito abaixo do cronômetro

var col_players: HBoxContainer = null   # rodapé horizontal dos players
var card_jogando: Panel = null          # destaque do jogador da vez (topo)
var _player_cards: Array = []           # cards menores (1 por jogador)

var musica_fundo: AudioStreamPlayer
var som_cesta: AudioStreamPlayer
var som_apito: AudioStreamPlayer
var som_fim: AudioStreamPlayer

# ---------- FX AMBIENTE / GRADE ----------
var fx_ambiente_layer: CanvasLayer = null
var fx_ambiente: Control = null
var _fx_tempo: float = 0.0

@export var usar_fx_ambiente: bool = true
@export var usar_shader_fundo: bool = true
@export var intensidade_luz_fundo: float = 0.40

# Grade de tiles que reage à cesta (ondas).
var grade_layer: CanvasLayer = null
var grade_ctrl: Control = null
var _grade_cols: int = 0
var _grade_rows: int = 0
var _grade_passo: float = 0.0
var _grade_ondas: Array = []            # cada onda: {origem:Vector2, t:float, dur:float}

# Ondas de luz fortes no acerto da cesta
var luz_onda_layer: CanvasLayer = null
var luz_onda_ctrl: Control = null
var _ondas_luz: Array = []


@export var tempo_trava_cesta: float = 1.20
var _trava_cesta_t: float = 0.0

var modo_credito: bool = false

# ---------- RECORDE ----------
@export var caminho_record_basket: String = "user://basket_record.cfg"
var record_maximo: int = 0

# Marca o recorde do início do turno e se a quebra já foi celebrada.
var _record_inicial_turno: int = 0
var _recorde_celebrado_turno: bool = false

# ---------- TRANSIÇÃO ----------
var transicao_layer: CanvasLayer = null
var transicao_fundo: ColorRect = null
var transicao_titulo: Label = null
var transicao_subtitulo: Label = null
var transicao_barra_fundo: Panel = null
var transicao_barra: ColorRect = null
var transicao_fx: Control = null
var _transicao_t: float = 0.0
var _transicao_ativa: bool = false

var _podio_linha_dif: Control = null
var _podio_cards_ref: Array = []

var sons_combo: Array = []

var combo_layer: CanvasLayer = null
var lbl_combo: Label = null
var _combo_tween: Tween = null

var _combo_nivel: int = 0
var _combo_ultimo_t: float = -999.0



# =====================================================================
func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	# Alt+F4 / X da janela passam por fechamento seguro,
	# para apagar LEDs e fechar a ponte antes de sair.
	get_tree().auto_accept_quit = false

	_aplicar_config_basket()
	_carregar_record_basket()
	_ler_quantidade_da_opening()

	_montar_cena()
	_carregar_fundo()
	_aplicar_shader_fundo_retrato()
	_iniciar_musica_fundo()
	_carregar_sons()
	_criar_fx_ambiente()
	_criar_grade_tiles()
	_criar_luz_ondas_cesta()
	_criar_transicao_layer()
	_criar_combo_ui()
	#_criar_record_coroa_ui()
	_layout_responsivo()
	_atualizar_visao_turno()
	_atualizar_tempo_label()

	if not get_viewport().size_changed.is_connected(_layout_responsivo):
		get_viewport().size_changed.connect(_layout_responsivo)

	await get_tree().process_frame
	await _transicao_entrada("CARREGANDO ARENA", "PREPARE-SE PARA O DESAFIO")

	if iniciar_automatico:
		iniciar_partida(tempo_partida)
	else:
		_mostrar_modal_turno(true)


func _process(delta: float) -> void:
	_trava_cesta_t = max(0.0, _trava_cesta_t - delta)

	if _transicao_ativa:
		_transicao_t += delta
		if transicao_fx != null:
			transicao_fx.queue_redraw()

	if usar_fx_ambiente:
		_atualizar_fx_ambiente(delta)

	_atualizar_grade(delta)
	_atualizar_luz_ondas_cesta(delta)

	if _record_booster_ativo:
		_record_booster_pulso += delta * 9.0

	if grade_ctrl != null:
		grade_ctrl.queue_redraw()

	if fx_ambiente != null:
		fx_ambiente.queue_redraw()

	if luz_onda_ctrl != null:
		luz_onda_ctrl.queue_redraw()

	if crono_ring != null:
		crono_ring.queue_redraw()

	if not _rodando:
		return

	_tempo_restante -= delta
	if _tempo_restante <= 0.0:
		_tempo_restante = 0.0
		_rodando = false
		_atualizar_tempo_label()
		_encerrar_turno_atual()
	else:
		_atualizar_tempo_label()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_fechar_tela_seguro()



func _fechar_tela_seguro() -> void:
	if _fechando_tela:
		return

	_fechando_tela = true
	_rodando = false
	_modal_turno_ativo = false
	_modal_turno_pronto = false
	_podio_ativo = false

	# Apaga LED e fecha a ponte antes de sair.
	_fechar_ponte_leds_play(true)

	get_tree().quit()



# =====================================================================
# ONDAS DE LUZ DA CESTA — sem partículas
# =====================================================================
func _criar_luz_ondas_cesta() -> void:
	if luz_onda_layer != null and is_instance_valid(luz_onda_layer):
		return

	luz_onda_layer = CanvasLayer.new()
	luz_onda_layer.name = "LuzOndaCestaLayer"
	luz_onda_layer.layer = 3 # acima da grade, abaixo do HUD
	add_child(luz_onda_layer)

	luz_onda_ctrl = Control.new()
	luz_onda_ctrl.name = "LuzOndaCestaCtrl"
	luz_onda_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	luz_onda_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	luz_onda_layer.add_child(luz_onda_ctrl)

	if not luz_onda_ctrl.draw.is_connected(_desenhar_luz_ondas_cesta):
		luz_onda_ctrl.draw.connect(_desenhar_luz_ondas_cesta)


func _disparar_luz_onda_cesta(origem: Vector2, dourado: bool = false, forca: float = 1.0, combo_nivel: int = 1, record_mode: bool = false) -> void:
	var nivel: int = max(1, combo_nivel)

	_ondas_luz.append({
		"origem": origem,
		"t": 0.0,
		"dur": 0.95 if record_mode else (1.05 if nivel >= 9 else 0.95),
		"forca": forca,
		"dourado": dourado,
		"inverso": false,
		"combo": nivel,
		"raio_ida_volta": record_mode or nivel >= 9,
		"record": record_mode
	})

	if luz_onda_ctrl != null:
		luz_onda_ctrl.queue_redraw()


func _disparar_implosao(origem: Vector2, cor: Color = Color(1.0, 0.55, 0.08), forca: float = 1.0) -> void:
	# Onda que vem das PERIFERIAS para DENTRO (efeito inverso da cesta).
	_ondas_luz.append({
		"origem": origem,
		"t": 0.0,
		"dur": 0.62,
		"forca": forca,
		"dourado": false,
		"inverso": true,
		"cor": cor
	})

	if luz_onda_ctrl != null:
		luz_onda_ctrl.queue_redraw()


func _atualizar_luz_ondas_cesta(delta: float) -> void:
	if luz_onda_ctrl == null:
		return

	if _ondas_luz.is_empty():
		return

	var vivas: Array = []

	for o in _ondas_luz:
		o["t"] = float(o["t"]) + delta
		if float(o["t"]) < float(o["dur"]):
			vivas.append(o)

	_ondas_luz = vivas
	luz_onda_ctrl.queue_redraw()



func _desenhar_luz_ondas_cesta() -> void:
	if luz_onda_ctrl == null:
		return

	var tela: Vector2 = get_viewport_rect().size

	for o in _ondas_luz:
		var origem: Vector2 = o["origem"]
		var t: float = float(o["t"])
		var dur: float = float(o["dur"])
		var p: float = clampf(t / dur, 0.0, 1.0)
		var forca: float = float(o.get("forca", 1.0))
		var inverso: bool = bool(o.get("inverso", false))
		var dourado: bool = bool(o.get("dourado", false))
		var combo_nivel: int = int(o.get("combo", 1))
		var raio_ida_volta: bool = bool(o.get("raio_ida_volta", false))
		var record_onda: bool = bool(o.get("record", false))

		# Recorde agora NÃO desenha arco de luz.
		# O efeito de recorde fica só nos quadrados da grade.
		if record_onda:
			continue

		var cor_ring: Color
		var cor_glow: Color

		if o.has("cor"):
			cor_ring = o["cor"]
			cor_glow = COR_BRANCO_FX
		elif combo_nivel >= 13:
			cor_ring = Color(1.0, 0.02, 0.0)
			cor_glow = Color(1.0, 0.42, 0.25)
		elif combo_nivel >= 9:
			cor_ring = Color(0.62, 0.12, 1.0)
			cor_glow = Color(0.95, 0.35, 1.0)
		elif combo_nivel >= 6:
			cor_ring = Color(0.08, 0.42, 1.0)
			cor_glow = Color(0.38, 0.75, 1.0)
		elif dourado:
			cor_ring = COR_RECORDE
			cor_glow = COR_RECORDE_BRILHO
		else:
			cor_ring = Color(1.0, 0.48, 0.06)
			cor_glow = COR_BRANCO_FX

		if inverso:
			_desenhar_onda_inversa(origem, p, forca, cor_ring, cor_glow, tela)
		else:
			_desenhar_onda_normal(origem, p, forca, dourado, cor_ring, cor_glow, tela, combo_nivel, raio_ida_volta)
	
	
	
func _desenhar_record_shader_eterno(tela: Vector2) -> void:
	if luz_onda_ctrl == null:
		return

	var origem := _record_origem_fx()

	# Como _record_booster_pulso já sobe rápido no _process,
	# aqui usamos multiplicadores pequenos para deixar elegante.
	var tempo := _record_booster_pulso

	var pulso_forca: float = 0.72 + 0.28 * abs(sin(tempo * 1.35))
	var ciclo: float = fposmod(tempo * 0.075, 1.0)

	# Duas ondas em ciclos diferentes para nunca ficar vazio.
	# Cada uma tem frente amarela e rastro branco atrás.
	_desenhar_record_dupla_faixa(origem, ciclo, pulso_forca, tela, 1.00)
	_desenhar_record_dupla_faixa(origem, fposmod(ciclo + 0.50, 1.0), pulso_forca, tela, 0.78)

	# Brilho central constante na cesta, bem controlado.
	var brilho_cesta: float = 0.10 + 0.08 * abs(sin(tempo * 1.8))
	luz_onda_ctrl.draw_circle(
		origem,
		tela.y * 0.045,
		Color(1.0, 0.86, 0.18, brilho_cesta)
	)

	luz_onda_ctrl.draw_circle(
		origem,
		tela.y * 0.026,
		Color(1.0, 1.0, 1.0, brilho_cesta * 0.45)
	)


func _desenhar_record_dupla_faixa(origem: Vector2, p: float, pulso: float, tela: Vector2, intensidade: float = 1.0) -> void:
	p = clampf(p, 0.0, 1.0)

	var raio_min: float = tela.y * 0.090
	var raio_max: float = tela.y * 0.690
	var raio_frente: float = lerpf(raio_min, raio_max, p)

	# A faixa branca vem atrás da amarela.
	var atraso_branco: float = tela.y * 0.055
	var raio_tras: float = max(raio_min * 0.65, raio_frente - atraso_branco)

	# Fade suave para nascer e sumir sem corte.
	var envelope: float = sin(p * PI)
	envelope = pow(max(0.0, envelope), 0.72)

	var alpha_amarelo: float = 0.44 * envelope * pulso * intensidade
	var alpha_branco: float = 0.34 * envelope * pulso * intensidade

	var largura_amarela: float = max(5.0, tela.y * 0.014)
	var largura_branca: float = max(3.5, tela.y * 0.010)

	# Rastro branco atrás
	_desenhar_faixa_onda_record(
		origem,
		raio_tras,
		largura_branca,
		Color(1.0, 1.0, 1.0, alpha_branco)
	)

	# Frente amarela
	_desenhar_faixa_onda_record(
		origem,
		raio_frente,
		largura_amarela,
		Color(1.0, 0.78, 0.02, alpha_amarelo)
	)

	# Glow fino na frente
	_desenhar_faixa_onda_record(
		origem,
		raio_frente + largura_amarela * 0.72,
		max(1.5, largura_amarela * 0.28),
		Color(1.0, 0.96, 0.62, alpha_amarelo * 0.48)
	)


func _desenhar_record_hit_ida_volta(origem: Vector2, p: float, forca: float, tela: Vector2) -> void:
	# Quando acerta no recorde: a onda sai e volta.
	var ping: float = p_ping_pong(p)
	var envelope: float = sin(p * PI)
	envelope = pow(max(0.0, envelope), 0.65)

	var raio_min: float = tela.y * 0.080
	var raio_max: float = tela.y * 0.610
	var raio_frente: float = lerpf(raio_min, raio_max, ping)
	var raio_tras: float = max(raio_min * 0.65, raio_frente - tela.y * 0.060)

	var largura_amarela: float = max(6.0, tela.y * 0.018)
	var largura_branca: float = max(4.0, tela.y * 0.012)

	var alpha_amarelo: float = 0.72 * envelope * forca
	var alpha_branco: float = 0.54 * envelope * forca

	# Atrás branca
	_desenhar_faixa_onda_record(
		origem,
		raio_tras,
		largura_branca,
		Color(1.0, 1.0, 1.0, alpha_branco)
	)

	# Frente amarela
	_desenhar_faixa_onda_record(
		origem,
		raio_frente,
		largura_amarela,
		Color(1.0, 0.80, 0.02, alpha_amarelo)
	)

	# Flash central no impacto
	var flash: float = 0.20 * envelope * forca
	luz_onda_ctrl.draw_circle(
		origem,
		tela.y * 0.075,
		Color(1.0, 0.88, 0.18, flash)
	)

	luz_onda_ctrl.draw_circle(
		origem,
		tela.y * 0.045,
		Color(1.0, 1.0, 1.0, flash * 0.45)
	)


func _desenhar_faixa_onda_record(origem: Vector2, raio: float, largura: float, cor: Color) -> void:
	if luz_onda_ctrl == null:
		return
	if largura <= 0.0:
		return

	luz_onda_ctrl.draw_arc(
		origem,
		raio,
		0.0,
		TAU,
		128,
		cor,
		largura,
		true
	)


func _desenhar_onda_record(origem: Vector2, p: float, forca: float, tela: Vector2) -> void:
	var fade: float = 1.0 - p
	var raio_base: float = lerpf(tela.y * 0.030, tela.y * 0.52, p)
	var largura_amarela: float = max(4.0, tela.y * 0.0105) * (1.0 + 0.10 * (forca - 1.0))
	var largura_branca: float = max(2.5, largura_amarela * 0.48)
	var espacamento: float = tela.y * 0.072

	# glow de origem bem mais limpo e preso na cesta
	luz_onda_ctrl.draw_circle(
		origem,
		raio_base * 0.18,
		Color(1.0, 0.92, 0.72, 0.16 * fade * forca)
	)

	for i in range(4):
		var raio: float = raio_base + float(i) * espacamento
		var alpha: float = (0.34 - float(i) * 0.055) * fade * forca

		if alpha <= 0.0:
			continue

		# faixa amarela
		_desenhar_faixa_onda_record(
			origem,
			raio,
			largura_amarela,
			Color(1.0, 0.80, 0.05, alpha)
		)

		# faixa branca logo na sequência
		_desenhar_faixa_onda_record(
			origem,
			raio + largura_amarela * 0.78,
			largura_branca,
			Color(1.0, 1.0, 1.0, alpha * 0.95)
		)

	# halo externo leve, sem bagunça
	var halo_alpha: float = 0.09 * fade * forca
	if halo_alpha > 0.0:
		_desenhar_faixa_onda_record(
			origem,
			raio_base + espacamento * 0.35,
			max(1.5, largura_amarela * 0.28),
			Color(1.0, 0.96, 0.82, halo_alpha)
		)



func _desenhar_onda_normal(
	origem: Vector2,
	p: float,
	forca: float,
	dourado: bool,
	cor_ring: Color,
	cor_glow: Color,
	tela: Vector2,
	combo_nivel: int = 1,
	raio_ida_volta: bool = false
) -> void:
	var p_raio: float = p

	# De 9 para cima o raio também sai e volta.
	if raio_ida_volta:
		if p <= 0.5:
			p_raio = p * 2.0
		else:
			p_raio = (1.0 - p) * 2.0

	var fade: float = 1.0 - p
	if raio_ida_volta:
		fade = 1.0 - abs(p - 0.5) * 0.85

	var raio_base: float = lerpf(tela.x * 0.10, tela.y * 0.82, p_raio)

	var num_aneis: int = 4
	if dourado:
		num_aneis = 6
	if combo_nivel >= 9:
		num_aneis = 7
	if combo_nivel >= 13:
		num_aneis = 9

	var flash_alpha: float = 0.20 * fade * forca
	if combo_nivel >= 9:
		flash_alpha *= 1.25
	if combo_nivel >= 13:
		flash_alpha *= 1.45

	luz_onda_ctrl.draw_circle(
		origem,
		raio_base * 0.32,
		Color(cor_glow.r, cor_glow.g, cor_glow.b, flash_alpha * 0.6)
	)

	for i in range(num_aneis):
		var raio: float = raio_base + float(i) * tela.y * 0.052
		var alpha: float = (0.34 - float(i) * 0.038) * fade * forca
		if combo_nivel >= 9:
			alpha *= 1.15
		if combo_nivel >= 13:
			alpha *= 1.35

		if alpha <= 0.0:
			continue

		var largura: float = max(3.0, tela.y * (0.006 + float(i) * 0.0015)) * (1.0 + 0.3 * (forca - 1.0))

		luz_onda_ctrl.draw_arc(
			origem,
			raio,
			0.0,
			TAU,
			128,
			Color(cor_ring.r, cor_ring.g, cor_ring.b, alpha),
			largura,
			true
		)

		luz_onda_ctrl.draw_arc(
			origem,
			raio + 7.0,
			0.0,
			TAU,
			128,
			Color(cor_glow.r, cor_glow.g, cor_glow.b, alpha * 0.42),
			max(1.5, largura * 0.42),
			true
		)

	# Raio extra no roxo e vermelho.
	if combo_nivel >= 9:
		var extra_alpha: float = 0.18 * fade * forca
		var extra_raio: float = raio_base * 0.72

		luz_onda_ctrl.draw_arc(
			origem,
			extra_raio,
			0.0,
			TAU,
			128,
			Color(cor_glow.r, cor_glow.g, cor_glow.b, extra_alpha),
			max(3.0, tela.y * 0.009),
			true
		)

	if combo_nivel >= 13:
		var extra2_alpha: float = 0.22 * fade * forca
		var extra2_raio: float = raio_base * 1.15

		luz_onda_ctrl.draw_arc(
			origem,
			extra2_raio,
			0.0,
			TAU,
			128,
			Color(cor_ring.r, cor_ring.g, cor_ring.b, extra2_alpha),
			max(4.0, tela.y * 0.011),
			true
		)

	var quantidade_raios: int = 10
	if combo_nivel >= 9:
		quantidade_raios = 14
	if combo_nivel >= 13:
		quantidade_raios = 18

	for i in range(quantidade_raios):
		var ang: float = -PI * 0.92 + TAU * float(i) / float(quantidade_raios)
		var dir := Vector2(cos(ang), sin(ang))

		var inicio: Vector2 = origem + dir * (raio_base * 0.10)
		var fim: Vector2 = origem + dir * (raio_base * 1.15)

		var a: float = 0.20 * fade * forca
		var w: float = max(2.0, tela.y * 0.004)

		luz_onda_ctrl.draw_line(
			inicio,
			fim,
			Color(cor_ring.r, cor_ring.g, cor_ring.b, a),
			w,
			true
		)

		luz_onda_ctrl.draw_line(
			inicio,
			fim,
			Color(cor_glow.r, cor_glow.g, cor_glow.b, a * 0.36),
			max(1.0, w * 0.38),
			true
		)



func _desenhar_onda_inversa(origem: Vector2, p: float, forca: float, cor_ring: Color, cor_glow: Color, tela: Vector2) -> void:
	# Raio GRANDE -> PEQUENO (da periferia para dentro).
	var raio_base: float = lerpf(tela.y * 0.85, tela.x * 0.06, p)
	# Brilha mais conforme converge.
	var intensidade: float = (0.25 + 0.75 * p) * forca

	var num_aneis: int = 3
	for i in range(num_aneis):
		var raio: float = raio_base + float(i) * tela.y * 0.05
		var alpha: float = (0.40 - float(i) * 0.10) * intensidade
		if alpha <= 0.0:
			continue
		var largura: float = max(3.0, tela.y * (0.007 + float(i) * 0.0015))

		luz_onda_ctrl.draw_arc(
			origem,
			raio,
			0.0,
			TAU,
			128,
			Color(cor_ring.r, cor_ring.g, cor_ring.b, alpha),
			largura,
			true
		)

		luz_onda_ctrl.draw_arc(
			origem,
			max(2.0, raio - 6.0),
			0.0,
			TAU,
			128,
			Color(cor_glow.r, cor_glow.g, cor_glow.b, alpha * 0.4),
			max(1.5, largura * 0.4),
			true
		)

	# Raios apontando para DENTRO
	var quantidade_raios: int = 12
	for i in range(quantidade_raios):
		var ang: float = TAU * float(i) / float(quantidade_raios)
		var dir := Vector2(cos(ang), sin(ang))

		var fim: Vector2 = origem + dir * raio_base
		var inicio: Vector2 = origem + dir * (raio_base + tela.y * 0.06)

		var a: float = 0.22 * intensidade
		var w: float = max(2.0, tela.y * 0.0035)

		luz_onda_ctrl.draw_line(
			inicio,
			fim,
			Color(cor_ring.r, cor_ring.g, cor_ring.b, a),
			w,
			true
		)

	# Flash de convergência no centro, no fim
	if p > 0.78:
		var f: float = (p - 0.78) / 0.22
		var raio_flash: float = lerpf(tela.x * 0.02, tela.x * 0.14, f)
		luz_onda_ctrl.draw_circle(origem, raio_flash, Color(cor_glow.r, cor_glow.g, cor_glow.b, 0.5 * f * forca))
		luz_onda_ctrl.draw_circle(origem, raio_flash * 0.5, Color(1, 1, 1, 0.6 * f * forca))


# =====================================================================
func _ler_quantidade_da_opening() -> void:
	var qtd := num_jogadores
	if get_tree().has_meta("num_jogadores"):
		qtd = int(get_tree().get_meta("num_jogadores"))
	num_jogadores = clampi(qtd, 1, 4)
	_pontos = [0, 0, 0, 0]
	_nomes = NOMES_PADRAO.duplicate()
	_turnos_finalizados = [false, false, false, false]
	_jogador_atual = 0


# =====================================================================
# AUTO-MONTAGEM — layout estilo referência
# =====================================================================
func _montar_cena() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Fundo
	if has_node("Fundo"):
		fundo = $Fundo
	else:
		fundo = TextureRect.new()
		fundo.name = "Fundo"
		add_child(fundo)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Áudio
	musica_fundo = _garantir_audio("MusicaFundo")
	som_cesta = _garantir_audio("SomCesta")
	som_apito = _garantir_audio("SomApito")
	som_fim = _garantir_audio("SomFim")

	# HUD
	if has_node("HUD"):
		_hud = $HUD
	else:
		_hud = CanvasLayer.new()
		_hud.name = "HUD"
		_hud.layer = 5
		add_child(_hud)

	# --- ALL-TIME HIGH (topo-esquerda) ---
	lbl_high_titulo = _novo_label(_hud, COR_AZUL, 3, "ALL-TIME HIGH")
	lbl_high_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_high_valor = _novo_label_seg(_hud, COR_AZUL, "0000")
	lbl_high_valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	# --- PLAYERS SCORE (topo-direita) ---
	lbl_players_titulo = _novo_label(_hud, COR_AZUL, 3, "PLAYERS SCORE")
	lbl_players_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	box_players_score = VBoxContainer.new()
	box_players_score.name = "BoxPlayersScore"
	box_players_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_players_score.alignment = BoxContainer.ALIGNMENT_BEGIN
	box_players_score.add_theme_constant_override("separation", 0)
	_hud.add_child(box_players_score)


	# --- ANEL DO CRONÔMETRO (centro) ---
	crono_ring = Control.new()
	crono_ring.name = "CronoRing"
	crono_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(crono_ring)
	crono_ring.draw.connect(_desenhar_crono_ring)

	lbl_crono = _novo_label(_hud, COR_VERDE_DISPLAY, 8, "0")
	lbl_crono.add_theme_color_override("font_outline_color", Color(0.28, 0.08, 0.0))

	# --- SCORE PASS e CURRENT SCORE separados nos dois campos da arte ---
	painel_score_pass = Panel.new()
	painel_score_pass.name = "PainelScorePass"
	painel_score_pass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel_score_pass.add_theme_stylebox_override("panel", _estilo_faixa_placar())
	_hud.add_child(painel_score_pass)

	painel_current_score = Panel.new()
	painel_current_score.name = "PainelCurrentScore"
	painel_current_score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painel_current_score.add_theme_stylebox_override("panel", _estilo_faixa_placar())
	_hud.add_child(painel_current_score)

	lbl_meta_titulo = _novo_label(_hud, COR_AMBAR, 3, "SCORE PASS")
	lbl_meta_valor = _novo_label_seg(_hud, COR_AMBAR, "00")

	lbl_atual_titulo = _novo_label(_hud, COR_VERDE_DISPLAY, 3, "CURRENT SCORE")
	lbl_atual_pontos = _novo_label_seg(_hud, COR_VERDE_DISPLAY, "00")

	# --- COLUNA DE PLAYERS (esquerda) + jogador da vez (topo) ---
	card_jogando = Panel.new()
	card_jogando.name = "CardJogando"
	card_jogando.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(card_jogando)
	var vj := VBoxContainer.new()
	vj.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vj.offset_left = 10; vj.offset_right = -10; vj.offset_top = 8; vj.offset_bottom = -8
	vj.alignment = BoxContainer.ALIGNMENT_CENTER
	vj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_jogando.add_child(vj)
	card_jogando.set_meta("vbox", vj)

	col_players = HBoxContainer.new()
	col_players.name = "ColPlayersRodape"
	col_players.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col_players.alignment = BoxContainer.ALIGNMENT_CENTER
	col_players.add_theme_constant_override("separation", 10)
	_hud.add_child(col_players)

	# Camada de efeitos (acima do HUD)
	if has_node("EfeitosLayer"):
		_efeitos = $EfeitosLayer
	else:
		_efeitos = CanvasLayer.new()
		_efeitos.name = "EfeitosLayer"
		_efeitos.layer = 12
		add_child(_efeitos)



func _garantir_audio(nome: String) -> AudioStreamPlayer:
	if has_node(nome):
		return get_node(nome)
	var a := AudioStreamPlayer.new()
	a.name = nome
	add_child(a)
	return a


func _novo_label(pai: Node, cor: Color, outline: int, txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", outline)
	_aplicar_fonte(l)
	pai.add_child(l)
	return l


func _novo_label_seg(pai: Node, cor: Color, txt: String) -> Label:
	# Placar estilo display 7-seg (cor forte + glow via outline da própria cor).
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(cor.r * 0.25, cor.g * 0.25, cor.b * 0.25, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	_aplicar_fonte(l)
	pai.add_child(l)
	return l


func _aplicar_fonte(lbl: Control) -> void:
	if caminho_fonte == "":
		return
	var f := load(caminho_fonte)
	if f is Font:
		lbl.add_theme_font_override("font", f)


# =====================================================================
# LAYOUT RESPONSIVO
# =====================================================================
func _fs(frac: float) -> int:
	return max(12, int(get_viewport_rect().size.y * frac))


func _ancorar(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = l; c.anchor_top = t; c.anchor_right = r; c.anchor_bottom = b
	c.offset_left = 0; c.offset_top = 0; c.offset_right = 0; c.offset_bottom = 0



func _layout_responsivo() -> void:
	if _hud == null:
		return

	var tela: Vector2 = get_viewport_rect().size

	# Topo: ALL-TIME HIGH / PLAYERS SCORE
	_ancorar(lbl_high_titulo, 0.05, 0.035, 0.55, 0.065)
	_ancorar(lbl_high_valor, 0.05, 0.062, 0.45, 0.110)
	_ancorar(lbl_players_titulo, 0.55, 0.035, 0.95, 0.065)
	# Valores dos players que já jogaram.
	# Fica logo abaixo do texto PLAYERS SCORE.
	# Valores dos players que já jogaram.
	# Mesma faixa Y do score da esquerda, abaixo do PLAYERS SCORE.
	_ancorar(box_players_score, 0.550, 0.062, 0.950, 0.110)

	lbl_high_titulo.add_theme_font_size_override("font_size", _fs(0.018))
	lbl_high_valor.add_theme_font_size_override("font_size", _fs(0.045))
	lbl_players_titulo.add_theme_font_size_override("font_size", _fs(0.018))
	
	if box_players_score != null:
		var sep_score: int = 0
		if num_jogadores == 2:
			sep_score = 1
		elif num_jogadores >= 3:
			sep_score = 0

		box_players_score.add_theme_constant_override("separation", sep_score)


	# Anel do cronômetro — encaixado no círculo da arte
	_ancorar(crono_ring, 0.300, 0.045, 0.700, 0.260)
	_ancorar(lbl_crono, 0.300, 0.045, 0.700, 0.260)
	lbl_crono.add_theme_font_size_override("font_size", _fs(0.095))

	# SCORE PASS — campo esquerdo da imagem
	_ancorar(painel_score_pass, 0.060, 0.242, 0.335, 0.318)
	_ancorar(lbl_meta_titulo, 0.070, 0.247, 0.325, 0.270)
	_ancorar(lbl_meta_valor, 0.070, 0.268, 0.325, 0.313)

	# CURRENT SCORE — campo direito da imagem
	_ancorar(painel_current_score, 0.665, 0.242, 0.940, 0.318)
	_ancorar(lbl_atual_titulo, 0.675, 0.247, 0.930, 0.270)
	_ancorar(lbl_atual_pontos, 0.675, 0.268, 0.930, 0.313)

	lbl_meta_titulo.add_theme_font_size_override("font_size", _fs(0.014))
	lbl_atual_titulo.add_theme_font_size_override("font_size", _fs(0.014))
	lbl_meta_valor.add_theme_font_size_override("font_size", _fs(0.044))
	lbl_atual_pontos.add_theme_font_size_override("font_size", _fs(0.044))

	# O card antigo da esquerda não será mais usado.
	# Agora todos os players ficam no rodapé.
	if card_jogando != null:
		card_jogando.visible = false
		_ancorar(card_jogando, 0.0, 0.0, 0.0, 0.0)

	# Rodapé responsivo dos jogadores.
	# 4 players ocupam quase tudo.
	# 2 players ficam centralizados.
	var rodape_left: float = 0.035
	var rodape_right: float = 0.965

	match num_jogadores:
		1:
			rodape_left = 0.355
			rodape_right = 0.645
		2:
			rodape_left = 0.230
			rodape_right = 0.770
		3:
			rodape_left = 0.105
			rodape_right = 0.895
		_:
			rodape_left = 0.035
			rodape_right = 0.965

	_ancorar(col_players, rodape_left, 0.875, rodape_right, 0.970)
	col_players.alignment = BoxContainer.ALIGNMENT_CENTER

	var sep_rodape: int = int(clampf(tela.x * 0.016, 8.0, 18.0))
	if num_jogadores >= 4:
		sep_rodape = int(clampf(tela.x * 0.010, 6.0, 12.0))

	col_players.add_theme_constant_override("separation", sep_rodape)
	_reconstruir_players()
	_atualizar_high_label()
	_ajustar_transicao_layout()
	_layout_combo_ui()
	_atualizar_scores_players_hud()



# =====================================================================
# VISÃO DO TURNO
# =====================================================================
func _atualizar_visao_turno() -> void:
	_atualizar_card_jogando()
	_reconstruir_players()
	_atualizar_placar_labels()
	_atualizar_scores_players_hud()



func _atualizar_card_jogando() -> void:
	if card_jogando != null:
		card_jogando.visible = false



func _reconstruir_players() -> void:
	if col_players == null:
		return

	for c in col_players.get_children():
		c.queue_free()

	_player_cards.clear()

	var altura_card: float = _altura_card_player()

	for i in range(num_jogadores):
		var card := _criar_mini_player(i)
		card.custom_minimum_size = Vector2(_largura_min_card_player_rodape(), altura_card)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL

		col_players.add_child(card)
		_player_cards.append(card)



func _criar_mini_player(i: int) -> Panel:
	var cor: Color = CORES_PLAYERS[i % CORES_PLAYERS.size()]
	var fin: bool = bool(_turnos_finalizados[i])
	var eh_atual: bool = i == _jogador_atual

	var card := Panel.new()
	card.custom_minimum_size = Vector2(_largura_min_card_player_rodape(), _altura_card_player())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.clip_contents = true

	if eh_atual:
		card.add_theme_stylebox_override("panel", _estilo_card_jogando(cor))
		card.modulate.a = 1.0
	else:
		card.add_theme_stylebox_override("panel", _estilo_mini_player(cor, fin))
		card.modulate.a = 1.0 if not fin else 0.58

	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -8
	h.offset_top = 4
	h.offset_bottom = -4
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", int(clampf(get_viewport_rect().size.x * 0.006, 4.0, 8.0)))
	card.add_child(h)

	var dot_size: float = clampf(get_viewport_rect().size.y * 0.016, 10.0, 18.0)

	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(dot_size, dot_size)
	dot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = cor if not fin or eh_atual else Color(0.5, 0.5, 0.5)
	sb.set_corner_radius_all(int(dot_size * 0.5))
	sb.shadow_color = Color(cor.r, cor.g, cor.b, 0.75 if eh_atual else 0.35)
	sb.shadow_size = 10 if eh_atual else 5
	dot.add_theme_stylebox_override("panel", sb)
	h.add_child(dot)

	var nome := Label.new()
	nome.text = str(_nomes[i])
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nome.clip_text = true
	nome.add_theme_font_size_override("font_size", _fonte_nome_card_player_rodape())
	nome.add_theme_color_override("font_color", Color.WHITE if not fin or eh_atual else Color(0.6, 0.6, 0.6))
	nome.add_theme_color_override("font_outline_color", Color.BLACK)
	nome.add_theme_constant_override("outline_size", 3)
	_aplicar_fonte(nome)
	h.add_child(nome)

	var pts := Label.new()
	pts.text = "%02d" % int(_pontos[i])
	pts.custom_minimum_size = Vector2(_fs(0.036), 0.0)
	pts.size_flags_horizontal = Control.SIZE_SHRINK_END
	pts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pts.add_theme_font_size_override("font_size", _fonte_pontos_card_player_rodape())
	pts.add_theme_color_override("font_color", cor if not fin or eh_atual else Color(0.6, 0.6, 0.6))
	pts.add_theme_color_override("font_outline_color", Color.BLACK)
	pts.add_theme_constant_override("outline_size", 4)
	_aplicar_fonte(pts)
	h.add_child(pts)

	return card



func _atualizar_placar_labels() -> void:
	if lbl_atual_pontos != null:
		lbl_atual_pontos.text = "%02d" % int(_pontos[_jogador_atual])
		var cor: Color = CORES_PLAYERS[_jogador_atual % CORES_PLAYERS.size()]
		lbl_atual_pontos.add_theme_color_override("font_color", COR_VERDE_DISPLAY)

	if lbl_meta_valor != null:
		lbl_meta_valor.text = "%02d" % record_maximo

	_atualizar_scores_players_hud()



func _atualizar_high_label() -> void:
	if lbl_high_valor != null:
		lbl_high_valor.text = "%04d" % record_maximo


# =====================================================================
# ANEL DO CRONÔMETRO (desenhado)
# =====================================================================
func _desenhar_crono_ring() -> void:
	if crono_ring == null:
		return
	var r := crono_ring.size
	var c := r * 0.5
	var raio : float = min(r.x, r.y) * 0.42
	var frac := 1.0
	if tempo_partida > 0.0:
		frac = clampf(_tempo_restante / tempo_partida, 0.0, 1.0)

	# trilho de fundo
	crono_ring.draw_arc(c, raio, 0.0, TAU, 80, Color(0.10, 0.18, 0.30, 0.85), max(4.0, raio * 0.10), true)
	# glow externo
	for g in range(3):
		crono_ring.draw_arc(c, raio + g * 3.0, -PI/2.0, -PI/2.0 + TAU * frac, 80,
			Color(COR_VERDE_DISPLAY.r, COR_VERDE_DISPLAY.g, COR_VERDE_DISPLAY.b, 0.10 - g * 0.025),
			max(6.0, raio * 0.16), true)
	# anel ativo (verde) — esvazia no sentido horário a partir do topo
	var cor_anel := COR_VERDE_DISPLAY
	if _tempo_restante <= 10.0 and _rodando:
		cor_anel = Color(1.0, 0.35, 0.3)
	crono_ring.draw_arc(c, raio, -PI/2.0, -PI/2.0 + TAU * frac, 80, cor_anel, max(4.0, raio * 0.10), true)

	# "tracinhos" do mostrador (estilo referência)
	var n := 40
	for i in range(n):
		var ang := -PI/2.0 + TAU * float(i) / float(n)
		var aceso := float(i) / float(n) <= frac
		var p1 := c + Vector2(cos(ang), sin(ang)) * (raio * 1.18)
		var p2 := c + Vector2(cos(ang), sin(ang)) * (raio * 1.30)
		var cc := cor_anel if aceso else Color(0.18, 0.25, 0.35, 0.55)
		crono_ring.draw_line(p1, p2, Color(cc.r, cc.g, cc.b, 0.9 if aceso else 0.4), 2.0, true)


# =====================================================================
# ESTILOS
# =====================================================================
func _estilo_faixa_placar() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.10, 0.80)
	sb.border_color = Color(COR_AZUL.r, COR_AZUL.g, COR_AZUL.b, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(COR_AZUL.r, COR_AZUL.g, COR_AZUL.b, 0.35)
	sb.shadow_size = 18
	return sb


func _estilo_card_jogando(cor: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(cor.r * 0.12, cor.g * 0.12, cor.b * 0.12, 0.72)
	sb.border_color = Color(cor.r, cor.g, cor.b, 0.95)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(cor.r, cor.g, cor.b, 0.55)
	sb.shadow_size = 24
	return sb


func _estilo_mini_player(cor: Color, fin: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()

	if fin:
		sb.bg_color = Color(0.03, 0.03, 0.05, 0.45)
		sb.border_color = Color(0.4, 0.4, 0.45, 0.3)
		sb.shadow_size = 0
	else:
		sb.bg_color = Color(cor.r * 0.08, cor.g * 0.08, cor.b * 0.08, 0.55)
		sb.border_color = Color(cor.r, cor.g, cor.b, 0.55)
		sb.shadow_color = Color(cor.r, cor.g, cor.b, 0.2)
		sb.shadow_size = 10

	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	return sb



func _estilo_painel(cor_borda: Color, ativo: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.08, 0.86)
	sb.border_color = cor_borda
	sb.set_border_width_all(5 if ativo else 3)
	sb.set_corner_radius_all(26)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(cor_borda.r, cor_borda.g, cor_borda.b, 0.55 if ativo else 0.22)
	sb.shadow_size = 20 if ativo else 8
	return sb


# =====================================================================
# ÁUDIO
# =====================================================================
func _iniciar_musica_fundo() -> void:
	if musica_fundo == null:
		return
	var s := load(caminho_musica_fundo) as AudioStream
	if s == null:
		push_warning("Game: música de fundo não encontrada em " + caminho_musica_fundo)
		return
	if s is AudioStreamMP3:
		s.loop = true
	elif s is AudioStreamOggVorbis:
		s.loop = true
	musica_fundo.stream = s
	musica_fundo.volume_db = volume_musica_db
	musica_fundo.play()



func _carregar_sons() -> void:
	if som_cesta:
		var sc := load(caminho_som_cesta) as AudioStream
		if sc:
			som_cesta.stream = sc
			som_cesta.volume_db = volume_cesta_db

	if som_apito:
		var sa := load(caminho_apito_inicio) as AudioStream
		if sa:
			som_apito.stream = sa

	if som_fim:
		var sf := load(caminho_end_bask) as AudioStream
		if sf:
			som_fim.stream = sf

	# Sons de combo 1 até 12.
	sons_combo.clear()

	var caminhos := [
		caminho_som_combo_1,
		caminho_som_combo_2,
		caminho_som_combo_3,
		caminho_som_combo_4,
		caminho_som_combo_5,
		caminho_som_combo_6,
		caminho_som_combo_7,
		caminho_som_combo_8,
		caminho_som_combo_9,
		caminho_som_combo_10,
		caminho_som_combo_11,
		caminho_som_combo_12
	]

	for i in range(caminhos.size()):
		var player := _garantir_audio("SomCombo%d" % (i + 1))
		player.volume_db = volume_combo_db

		var stream := load(caminhos[i]) as AudioStream
		if stream:
			player.stream = stream
		else:
			push_warning("Combo: som não encontrado em " + str(caminhos[i]))

		sons_combo.append(player)


func _criar_combo_ui() -> void:
	if combo_layer != null and is_instance_valid(combo_layer):
		return

	combo_layer = CanvasLayer.new()
	combo_layer.name = "ComboLayer"
	combo_layer.layer = 45
	add_child(combo_layer)

	lbl_combo = Label.new()
	lbl_combo.name = "LblCombo"
	lbl_combo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_combo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_combo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_combo.visible = false
	lbl_combo.modulate.a = 0.0
	lbl_combo.text = ""

	lbl_combo.add_theme_color_override("font_color", Color.WHITE)
	lbl_combo.add_theme_color_override("font_outline_color", Color(1.0, 0.38, 0.02))
	lbl_combo.add_theme_constant_override("outline_size", 14)

	_aplicar_fonte(lbl_combo)

	combo_layer.add_child(lbl_combo)
	_layout_combo_ui()


func _layout_combo_ui() -> void:
	if lbl_combo == null:
		return

	# Texto de combo mais baixo, sem sair da tela.
	_ancorar(lbl_combo, 0.04, 0.555, 0.96, 0.675)

	lbl_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_combo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_combo.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl_combo.clip_text = true

	lbl_combo.add_theme_font_size_override("font_size", _fs(0.043))
	lbl_combo.add_theme_constant_override("outline_size", 8)


func _criar_record_coroa_ui() -> void:
	return


func _desenhar_coroa_record() -> void:
	return


func _desenhar_segmento_piche(a: Vector2, b: Vector2, progresso: float, cor: Color, largura: float) -> void:
	return


func _desenhar_polyline_piche(pontos: Array, progresso: float, cor: Color, largura: float, jitter: Vector2 = Vector2.ZERO) -> void:
	return


func _desenhar_polyline_piche_offset(pontos: Array, progresso: float, cor: Color, largura: float, offset: Vector2) -> void:
	return


func _desenhar_gota_piche(inicio: Vector2, comprimento: float, progresso: float, cor: Color, largura: float) -> void:
	return



func _ativar_visual_record() -> void:
	_record_booster_ativo = true
	_record_booster_pulso = 0.0

	# Recorde domina o visual:
	# limpa ondas anteriores de combo para não misturar azul/roxo/vermelho.
	_grade_ondas.clear()
	_ondas_luz.clear()

	if grade_ctrl != null:
		grade_ctrl.queue_redraw()

	if luz_onda_ctrl != null:
		luz_onda_ctrl.queue_redraw()

	if record_coroa_ctrl != null:
		record_coroa_ctrl.visible = true
		record_coroa_ctrl.queue_redraw()


func _desativar_visual_record() -> void:
	_record_booster_ativo = false
	_record_booster_pulso = 0.0

	if record_coroa_ctrl != null:
		record_coroa_ctrl.visible = false



func _tocar(p: AudioStreamPlayer) -> void:
	if p and p.stream:
		p.play()


func _tocar_som_cesta() -> void:
	_tocar(som_cesta)


# =====================================================================
# CONTAGEM / VAI
# =====================================================================
func _contagem_regressiva() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ContagemLayer"
	layer.layer = 28
	add_child(layer)
	var lbl := Label.new()
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", _fs(0.17))
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", COR_AZUL)
	lbl.add_theme_constant_override("outline_size", 10)
	_aplicar_fonte(lbl)
	layer.add_child(lbl)
	for n in range(segundos_contagem, 0, -1):
		lbl.text = str(n)
		lbl.pivot_offset = get_viewport_rect().size * 0.5
		lbl.scale = Vector2(1.5, 1.5)
		lbl.modulate.a = 0.0

		# EFEITO INVERSO DA CESTA: das periferias para o centro, a cada segundo.
		var centro_tela := get_viewport_rect().size * 0.5
		var prog := float(segundos_contagem - n) / float(max(1, segundos_contagem - 1))
		var forca_count := lerpf(0.75, 1.45, prog)
		var cor_count := Color(1.0, 0.55, 0.08).lerp(COR_RECORDE, prog)
		_disparar_implosao(centro_tela, cor_count, forca_count)
		_disparar_onda_grade(centro_tela, true)

		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(lbl, "modulate:a", 1.0, 0.18)
		t.tween_property(lbl, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.7).timeout
		var t2 := create_tween()
		t2.tween_property(lbl, "modulate:a", 0.0, 0.18)
		await t2.finished
	layer.queue_free()


func _flash_vai() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FlashVaiLayer"
	layer.layer = 28
	add_child(layer)
	var lbl := Label.new()
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.text = "VAI!"
	lbl.add_theme_font_size_override("font_size", _fs(0.12))
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 10)
	_aplicar_fonte(lbl)
	layer.add_child(lbl)
	lbl.pivot_offset = get_viewport_rect().size * 0.5
	lbl.scale = Vector2(0.6, 0.6)
	var t := create_tween()
	t.tween_property(lbl, "scale", Vector2(1.12, 1.12), 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.22)
	t.tween_property(lbl, "modulate:a", 0.0, 0.28)
	t.tween_callback(layer.queue_free)


# =====================================================================
# MODAL DE TURNO
# =====================================================================
func _mostrar_modal_turno(inicial: bool) -> void:
	_modal_turno_ativo = true
	_modal_turno_pronto = false
	_rodando = false
	if _modal_turno_layer != null:
		_modal_turno_layer.queue_free()
		_modal_turno_layer = null
	_modal_turno_layer = CanvasLayer.new()
	_modal_turno_layer.name = "ModalTurnoLayer"
	_modal_turno_layer.layer = 30
	add_child(_modal_turno_layer)

	var escuro := ColorRect.new()
	escuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	escuro.color = Color(0, 0, 0, 0.82)
	escuro.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_turno_layer.add_child(escuro)

	var painel := Panel.new()
	painel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	painel.offset_left = -470; painel.offset_right = 470
	painel.offset_top = -300; painel.offset_bottom = 300
	painel.add_theme_stylebox_override("panel", _estilo_modal_turno())
	_modal_turno_layer.add_child(painel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 36; vbox.offset_right = -36; vbox.offset_top = 34; vbox.offset_bottom = -34
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	painel.add_child(vbox)

	var titulo := Label.new()
	titulo.text = "ORDEM DE JOGO" if inicial else "PRÓXIMO JOGADOR"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 50)
	titulo.add_theme_color_override("font_color", Color.WHITE)
	titulo.add_theme_color_override("font_outline_color", COR_VERDE_DISPLAY)
	titulo.add_theme_constant_override("outline_size", 8)
	_aplicar_fonte(titulo)
	vbox.add_child(titulo)

	var jogador := Label.new()
	jogador.text = "%s COMEÇA AGORA" % str(_nomes[_jogador_atual])
	jogador.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	jogador.add_theme_font_size_override("font_size", 36)
	jogador.add_theme_color_override("font_color", CORES_PLAYERS[_jogador_atual])
	jogador.add_theme_color_override("font_outline_color", Color.BLACK)
	jogador.add_theme_constant_override("outline_size", 5)
	_aplicar_fonte(jogador)
	vbox.add_child(jogador)

	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_theme_constant_override("separation", 14)
	vbox.add_child(linha)
	for i in range(num_jogadores):
		linha.add_child(_criar_card_ordem_modal(i))

	var info := Label.new()
	info.text = "CADA JOGADOR JOGA %d SEGUNDOS" % int(tempo_partida)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 22)
	info.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_aplicar_fonte(info)
	vbox.add_child(info)

	var start := Label.new()
	start.text = "PRESSIONE START"
	start.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start.add_theme_font_size_override("font_size", 34)
	start.add_theme_color_override("font_color", Color.WHITE)
	start.add_theme_color_override("font_outline_color", COR_VERDE_DISPLAY)
	start.add_theme_constant_override("outline_size", 6)
	_aplicar_fonte(start)
	vbox.add_child(start)

	painel.pivot_offset = painel.size * 0.5
	painel.scale = Vector2(0.88, 0.88)
	painel.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(painel, "scale", Vector2(1, 1), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(painel, "modulate:a", 1.0, 0.25)
	var pisca := create_tween().set_loops()
	pisca.tween_property(start, "modulate:a", 0.25, 0.6)
	pisca.tween_property(start, "modulate:a", 1.0, 0.6)
	await get_tree().create_timer(0.45).timeout
	_modal_turno_pronto = true


func _criar_card_ordem_modal(i: int) -> Panel:
	var cor: Color = CORES_PLAYERS[i % CORES_PLAYERS.size()]
	var ativo := i == _jogador_atual
	var finalizado: bool = bool(_turnos_finalizados[i])
	var card := Panel.new()
	card.custom_minimum_size = Vector2(185, 150)
	card.add_theme_stylebox_override("panel", _estilo_painel(cor, ativo))
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	var ordem := Label.new()
	ordem.text = "%dº" % (i + 1)
	ordem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ordem.add_theme_font_size_override("font_size", 28)
	ordem.add_theme_color_override("font_color", cor)
	_aplicar_fonte(ordem)
	vbox.add_child(ordem)
	var nome := Label.new()
	nome.text = str(_nomes[i])
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nome.add_theme_font_size_override("font_size", 22)
	nome.add_theme_color_override("font_color", Color.WHITE)
	_aplicar_fonte(nome)
	vbox.add_child(nome)
	var status := Label.new()
	if finalizado:
		status.text = "OK"; status.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	elif ativo:
		status.text = "AGORA"; status.add_theme_color_override("font_color", Color.WHITE)
	else:
		status.text = "DEPOIS"; status.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 18)
	_aplicar_fonte(status)
	vbox.add_child(status)
	return card


func _estilo_modal_turno() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.10, 0.98)
	sb.border_color = COR_AZUL
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(34)
	sb.set_content_margin_all(26)
	sb.shadow_color = Color(COR_AZUL.r, COR_AZUL.g, COR_AZUL.b, 0.55)
	sb.shadow_size = 28
	return sb


func _iniciar_turno_atual() -> void:
	if _modal_turno_ativo and not _modal_turno_pronto:
		return
	_modal_turno_ativo = false
	_modal_turno_pronto = false
	if _modal_turno_layer != null:
		_modal_turno_layer.queue_free()
		_modal_turno_layer = null

	_atualizar_visao_turno()
	_ocultar_hud_para_contagem()
	await _contagem_regressiva()
	await _montar_hud_apos_contagem()
	_tocar(som_apito)
	_flash_vai()
	iniciar_partida(tempo_partida)


func _ocultar_hud_para_contagem() -> void:
	_tempo_restante = tempo_partida
	_rodando = false
	_atualizar_tempo_label()
	for n in [lbl_high_titulo, lbl_high_valor, lbl_players_titulo, crono_ring, lbl_crono,
			painel_placar, lbl_meta_titulo, lbl_meta_valor, lbl_atual_titulo, lbl_atual_pontos,
			card_jogando, col_players]:
		if n != null:
			n.visible = true
			n.modulate.a = 0.0


func _montar_hud_apos_contagem() -> void:
	var ordem := [lbl_high_titulo, lbl_high_valor, lbl_players_titulo, crono_ring, lbl_crono,
			painel_placar, lbl_meta_titulo, lbl_meta_valor, lbl_atual_titulo, lbl_atual_pontos,
			card_jogando, col_players]
	var atraso := 0.0
	for n in ordem:
		if n == null:
			continue
		n.visible = true
		n.modulate.a = 0.0
		var t := create_tween()
		t.tween_property(n, "modulate:a", 1.0, 0.16).set_delay(atraso)
		atraso += 0.03
	await get_tree().create_timer(atraso + 0.2).timeout



func _encerrar_turno_atual() -> void:
	_rodando = false
	_record_booster_ativo = false
	_record_booster_pulso = 0.0

	# Fim do tempo: apaga LED e fecha COM5.
	_fechar_ponte_leds_play(true)

	_tocar(som_fim)

	_turnos_finalizados[_jogador_atual] = true

	if _jogador_atual >= num_jogadores - 1:
		encerrar_partida()
		return

	_jogador_atual += 1
	_atualizar_visao_turno()

	await get_tree().create_timer(0.7).timeout
	_mostrar_modal_turno(false)


# =====================================================================
# API PÚBLICA / PONTOS
# =====================================================================
func definir_jogadores(qtd: int, nomes: Array = []) -> void:
	num_jogadores = clampi(qtd, 1, 4)
	for i in range(4):
		_pontos[i] = 0
		_turnos_finalizados[i] = false
		_nomes[i] = nomes[i] if i < nomes.size() else NOMES_PADRAO[i]
	_jogador_atual = 0
	_atualizar_visao_turno()


func adicionar_ponto_jogador_atual(valor: int = 1) -> void:
	adicionar_ponto(_jogador_atual, valor)



func adicionar_ponto(idx: int, valor: int = 1) -> void:
	if idx < 0 or idx >= num_jogadores:
		return

	_pontos[idx] += valor

	if idx == _jogador_atual:
		var combo_nivel: int = _registrar_combo_cesta()

		_atualizar_placar_labels()

		var pts_atuais: int = int(_pontos[idx])
		var bateu_recorde_agora: bool = pts_atuais > record_maximo

		_verificar_recorde_atual()
		_pulso_placar()

		# Antes de bater recorde: efeito normal de combo.
		if not _record_booster_ativo and not bateu_recorde_agora:
			_enviar_led_basket("HIT")
			_efeito_cesta(combo_nivel)

		# Primeira vez que bate o recorde:
		# limpa combo e entra visual record dominante.
		elif bateu_recorde_agora and not _recorde_celebrado_turno:
			_recorde_celebrado_turno = true
			_ativar_visual_record()

			_enviar_led_basket("RECORD")
			_efeito_cesta_record(true)
			_flash_recorde()

		# Depois do recorde:
		# continua só record, sem shader de combo.
		else:
			_enviar_led_basket("BOOST")
			_efeito_cesta_record(false)

	else:
		_reconstruir_players()

	ponto_marcado.emit(idx, _pontos[idx])



func _registrar_combo_cesta() -> int:
	var agora: float = Time.get_ticks_msec() / 1000.0

	if agora - _combo_ultimo_t <= janela_combo_segundos:
		_combo_nivel += 1
	else:
		_combo_nivel = 1

	_combo_ultimo_t = agora

	_tocar_som_combo(_combo_nivel)
	_mostrar_texto_combo(_combo_nivel)

	return _combo_nivel



func _tocar_som_combo(nivel: int) -> void:
	if sons_combo.is_empty():
		_tocar_som_cesta()
		return

	var idx: int = clampi(nivel, 1, sons_combo.size()) - 1

	if idx >= 0 and idx < sons_combo.size():
		var p = sons_combo[idx]
		if p is AudioStreamPlayer and p.stream:
			p.stop()
			p.play()
			return

	_tocar_som_cesta()



func _mostrar_texto_combo(nivel: int) -> void:
	if lbl_combo == null:
		return

	var txt := ""

	match nivel:
		1:
			txt = "BOA!"
		2:
			txt = "COMBO x2"
		3:
			txt = "COMBO x3"
		4:
			txt = "SUPER x4"
		5:
			txt = "MEGA x5"
		6, 7, 8:
			txt = "BLUE x%d" % nivel
		9, 10, 11, 12:
			txt = "NEON x%d" % nivel
		_:
			txt = "MAX x%d" % nivel

	lbl_combo.text = txt
	lbl_combo.visible = true
	lbl_combo.modulate.a = 0.0
	lbl_combo.scale = Vector2(0.86, 0.86)
	lbl_combo.pivot_offset = lbl_combo.size * 0.5

	var cor_outline := Color(1.0, 0.38, 0.02)
	var cor_texto := Color.WHITE

	if nivel >= 13:
		cor_outline = Color(1.0, 0.02, 0.0)
		cor_texto = Color(1.0, 0.88, 0.84)
	elif nivel >= 9:
		cor_outline = Color(0.80, 0.20, 1.0)
		cor_texto = Color(0.96, 0.88, 1.0)
	elif nivel >= 6:
		cor_outline = Color(0.08, 0.42, 1.0)
		cor_texto = Color(0.88, 0.94, 1.0)
	elif nivel >= 4:
		cor_outline = COR_RECORDE
		cor_texto = COR_RECORDE_CLARO

	lbl_combo.add_theme_color_override("font_color", cor_texto)
	lbl_combo.add_theme_color_override("font_outline_color", cor_outline)

	if _combo_tween != null:
		_combo_tween.kill()

	_combo_tween = create_tween()
	_combo_tween.set_parallel(true)

	_combo_tween.tween_property(lbl_combo, "modulate:a", 1.0, 0.08)
	_combo_tween.tween_property(lbl_combo, "scale", Vector2(0.98, 0.98), 0.14)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_combo_tween.chain()
	_combo_tween.tween_interval(0.42)

	_combo_tween.chain()
	_combo_tween.set_parallel(true)
	_combo_tween.tween_property(lbl_combo, "scale", Vector2(0.90, 0.90), 0.18)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_combo_tween.tween_property(lbl_combo, "modulate:a", 0.0, 0.18)

	_combo_tween.chain()
	_combo_tween.tween_callback(func():
		if lbl_combo != null:
			lbl_combo.visible = false
	)



func _resetar_combo() -> void:
	_combo_nivel = 0
	_combo_ultimo_t = -999.0

	if lbl_combo != null:
		lbl_combo.visible = false
		lbl_combo.modulate.a = 0.0

	if _combo_tween != null:
		_combo_tween.kill()
		_combo_tween = null



func _pulso_placar() -> void:
	if lbl_atual_pontos == null:
		return
	lbl_atual_pontos.pivot_offset = lbl_atual_pontos.size * 0.5
	var t := create_tween()
	t.tween_property(lbl_atual_pontos, "scale", Vector2(1.25, 1.25), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(lbl_atual_pontos, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func definir_pontos(idx: int, valor: int) -> void:
	if idx < 0 or idx >= num_jogadores:
		return
	_pontos[idx] = valor
	if idx == _jogador_atual:
		_atualizar_placar_labels()
	else:
		_reconstruir_players()


func iniciar_partida(segundos: float = -1.0) -> void:
	if segundos > 0.0:
		tempo_partida = segundos

	_iniciar_ponte_leds_play()

	_tempo_restante = tempo_partida
	_rodando = true

	_record_inicial_turno = record_maximo
	_recorde_celebrado_turno = false
	_desativar_visual_record()
	_resetar_combo()

	_enviar_led_basket("PLAY")
	_atualizar_tempo_label()



func pausar_partida() -> void:
	_rodando = false


func retomar_partida() -> void:
	if _tempo_restante > 0.0:
		_rodando = true


func encerrar_partida() -> void:
	_rodando = false
	_record_booster_ativo = false
	_record_booster_pulso = 0.0

	# Segurança: ao finalizar o jogo inteiro, apaga e fecha a ponte.
	_fechar_ponte_leds_play(true)

	if musica_fundo and musica_fundo.playing:
		var tm := create_tween()
		tm.tween_property(musica_fundo, "volume_db", -40.0, 0.6)
	for n in [card_jogando, col_players]:
		if n != null:
			n.visible = false
	var finais: Array = []
	for i in range(num_jogadores):
		finais.append(_pontos[i])
	partida_encerrada.emit(finais)
	if mostrar_podio_automatico and _podio_layer == null:
		_mostrar_podio()


# =====================================================================
# GRADE DE TILES — efeito de fundo que afunda em ONDA na cesta
# =====================================================================
func _criar_grade_tiles() -> void:
	if grade_layer != null and is_instance_valid(grade_layer):
		return
	grade_layer = CanvasLayer.new()
	grade_layer.name = "GradeLayer"
	grade_layer.layer = 1   # entre o fundo (0) e o HUD (5)
	add_child(grade_layer)
	grade_ctrl = Control.new()
	grade_ctrl.name = "GradeCtrl"
	grade_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grade_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade_layer.add_child(grade_ctrl)
	if not grade_ctrl.draw.is_connected(_desenhar_grade):
		grade_ctrl.draw.connect(_desenhar_grade)
	_calcular_grade()


func _calcular_grade() -> void:
	var tela := get_viewport_rect().size
	_grade_passo = max(36.0, tela.y * 0.062)
	_grade_cols = int(ceil(tela.x / _grade_passo)) + 1
	_grade_rows = int(ceil(tela.y / _grade_passo)) + 1



func _disparar_onda_grade(origem: Vector2, inverso: bool = false, combo_nivel: int = 1, record_mode: bool = false) -> void:
	var nivel: int = max(1, combo_nivel)

	var duracao: float = 1.10

	if record_mode:
		duracao = 1.28
	elif nivel >= 13:
		duracao = 1.34
	elif nivel >= 9:
		duracao = 1.26
	elif nivel >= 6:
		duracao = 1.18
	elif nivel >= 3:
		duracao = 0.84
	else:
		duracao = 1.12

	_grade_ondas.append({
		"origem": origem,
		"t": 0.0,
		"dur": duracao,
		"inverso": inverso,
		"combo": nivel,
		"ida_volta": nivel >= 6,
		"raio_extra": nivel >= 9,
		"raio_max": nivel >= 13,
		"record": record_mode
	})



func _atualizar_grade(delta: float) -> void:
	if grade_ctrl == null:
		return
	if _grade_ondas.is_empty():
		# redesenha de leve mesmo parado (respiro do grid)
		grade_ctrl.queue_redraw()
		return
	var vivas: Array = []
	for o in _grade_ondas:
		o["t"] = float(o["t"]) + delta
		if float(o["t"]) < float(o["dur"]):
			vivas.append(o)
	_grade_ondas = vivas
	grade_ctrl.queue_redraw()



func _desenhar_grade() -> void:
	if grade_ctrl == null or _grade_passo <= 0.0:
		return

	var tela := get_viewport_rect().size
	var base_a := 0.024 + 0.010 * sin(_fx_tempo * 1.20)

	var origem_record := _record_origem_fx()
	var record_ciclo: float = 0.0
	var record_pulso: float = 0.0

	if _record_booster_ativo:
		record_ciclo = fposmod(_record_booster_pulso * 0.075, 1.0)
		record_pulso = 0.70 + 0.30 * abs(sin(_record_booster_pulso * 1.45))

	for gx in range(_grade_cols):
		for gy in range(_grade_rows):
			var p := Vector2(gx * _grade_passo, gy * _grade_passo)

			var afund := 0.0
			var acende := 0.0
			var combo_tile: int = 0

			# ============================================================
			# ONDAS NORMAIS / IMPACTO DE CESTA
			# ============================================================
			for o in _grade_ondas:
				var dist := p.distance_to(o["origem"])
				var t := float(o["t"])
				var dur: float = max(0.01, float(o["dur"]))
				var combo_onda: int = int(o.get("combo", 1))
				var ida_volta: bool = bool(o.get("ida_volta", false))
				var raio_extra: bool = bool(o.get("raio_extra", false))
				var raio_max: bool = bool(o.get("raio_max", false))
				var record_onda: bool = bool(o.get("record", false))

				var prog: float = clampf(t / dur, 0.0, 1.0)

				var progs_raio: Array = []
				if ida_volta:
					var ping: float = p_ping_pong(prog)
					progs_raio.append(ping)

					if raio_extra:
						progs_raio.append(p_ping_pong(fposmod(prog + 0.24, 1.0)))
					if raio_max:
						progs_raio.append(p_ping_pong(fposmod(prog + 0.46, 1.0)))
				else:
					progs_raio.append(prog)

				for prog_raio in progs_raio:
					var raio := float(prog_raio) * (tela.x * 1.35)

					if bool(o.get("inverso", false)):
						raio = (1.0 - float(prog_raio)) * (tela.x * 1.35)

					var largura := tela.y * 0.105

					if record_onda:
						largura = tela.y * 0.090
					elif combo_onda >= 13:
						largura = tela.y * 0.155
					elif combo_onda >= 9:
						largura = tela.y * 0.145
					elif combo_onda >= 6:
						largura = tela.y * 0.135
					elif combo_onda >= 3:
						largura = tela.y * 0.118

					var d: float = abs(dist - raio)

					if d < largura:
						var k: float = 1.0 - (d / largura)
						k = pow(k, 1.85)

						var fade_tempo: float = 1.0 - prog
						if ida_volta:
							fade_tempo = 1.0 - abs(prog - 0.5) * 0.72

						k *= fade_tempo

						if k > acende:
							acende = k

							if record_onda:
								# Impacto da cesta no recorde:
								# linha amarela na frente e branca logo atrás.
								var faixa_idx: int = int(floor(raio / max(10.0, largura * 0.72))) % 2
								combo_tile = 1000 + faixa_idx
							else:
								combo_tile = combo_onda

						afund = max(afund, k)

			# ============================================================
			# RECORD ETERNO NA GRADE
			# Duas linhas de quadrados:
			# - frente amarela
			# - atrás branca
			# ============================================================
			if _record_booster_ativo:
				var dist_record: float = p.distance_to(origem_record)

				for w in range(2):
					var ciclo_w: float = fposmod(record_ciclo + float(w) * 0.50, 1.0)

					var raio_min: float = tela.y * 0.075
					var raio_max: float = tela.y * 0.720

					var raio_amarelo: float = lerpf(raio_min, raio_max, ciclo_w)
					var raio_branco: float = max(raio_min * 0.65, raio_amarelo - tela.y * 0.060)

					var envelope: float = sin(ciclo_w * PI)
					envelope = pow(max(0.0, envelope), 0.72)

					var largura_linha: float = max(_grade_passo * 0.42, tela.y * 0.022)

					# Linha branca atrás
					var d_branco: float = abs(dist_record - raio_branco)
					if d_branco < largura_linha:
						var kb: float = 1.0 - (d_branco / largura_linha)
						kb = pow(kb, 1.45) * envelope * record_pulso * 0.88

						if kb > acende:
							acende = kb
							combo_tile = 1001

						afund = max(afund, kb * 0.62)

					# Linha amarela na frente
					var d_amarelo: float = abs(dist_record - raio_amarelo)
					if d_amarelo < largura_linha:
						var ka: float = 1.0 - (d_amarelo / largura_linha)
						ka = pow(ka, 1.35) * envelope * record_pulso

						if ka > acende:
							acende = ka
							combo_tile = 1000

						afund = max(afund, ka * 0.80)

			var tam := _grade_passo * (0.38 + afund * 0.35)
			var off := afund * _grade_passo * 0.16
			var centro := p + Vector2(_grade_passo, _grade_passo) * 0.5 + Vector2(off, off)
			var meia := tam * 0.5
			var rect := Rect2(centro - Vector2(meia, meia), Vector2(tam, tam))

			var cor_base := COR_AZUL
			var cor_acende := Color.WHITE
			var extra_alpha: float = 0.0

			if combo_tile == 1000:
				# Linha da frente: AMARELA
				cor_base = Color(1.0, 0.78, 0.02)
				cor_acende = Color(1.0, 0.88, 0.14)
				extra_alpha = 0.12 * acende
			elif combo_tile == 1001:
				# Linha de trás: BRANCA
				cor_base = Color(1.0, 1.0, 1.0)
				cor_acende = Color(1.0, 1.0, 1.0)
				extra_alpha = 0.09 * acende
			elif combo_tile >= 13:
				cor_base = Color(0.62, 0.00, 0.00)
				cor_acende = Color(1.00, 0.03, 0.02)
				extra_alpha = 0.20 * abs(sin(_fx_tempo * 17.0))
			elif combo_tile >= 9:
				cor_base = Color(0.34, 0.05, 0.78)
				cor_acende = Color(0.82, 0.20, 1.00)
				extra_alpha = 0.17 * abs(sin(_fx_tempo * 14.0))
			elif combo_tile >= 6:
				cor_base = Color(0.02, 0.18, 0.85)
				cor_acende = Color(0.12, 0.55, 1.00)
				extra_alpha = 0.14 * abs(sin(_fx_tempo * 10.0))
			elif combo_tile >= 3:
				cor_base = Color(1.0, 0.30, 0.00)
				cor_acende = Color(1.0, 0.58, 0.04)
				extra_alpha = 0.11 * abs(sin(_fx_tempo * 7.0))
			elif combo_tile >= 1:
				cor_base = Color(0.75, 0.82, 1.0)
				cor_acende = Color.WHITE
				extra_alpha = 0.06 * abs(sin(_fx_tempo * 3.0))

			var a := base_a + acende * 0.46 + extra_alpha
			var cor := Color(cor_base.r, cor_base.g, cor_base.b, a)

			if acende > 0.18:
				var a_fx: float = clampf(a + acende * 0.36, 0.0, 0.95)
				cor = Color(cor_acende.r, cor_acende.g, cor_acende.b, a_fx)

			grade_ctrl.draw_rect(
				rect,
				cor,
				false,
				max(1.0, 1.0 + acende * 2.7),
				true
			)

			# Reforço interno somente nas linhas do recorde.
			if combo_tile >= 1000 and acende > 0.24:
				var inner_record := rect.grow(-max(3.0, _grade_passo * 0.16))
				if inner_record.size.x > 2.0 and inner_record.size.y > 2.0:
					grade_ctrl.draw_rect(
						inner_record,
						Color(cor_base.r, cor_base.g, cor_base.b, 0.08 + acende * 0.12),
						false,
						1.2,
						true
					)
			elif acende > 0.35:
				var inner := rect.grow(-max(2.0, _grade_passo * 0.11))
				if inner.size.x > 2.0 and inner.size.y > 2.0:
					grade_ctrl.draw_rect(
						inner,
						Color(cor.r, cor.g, cor.b, acende * 0.10),
						false,
						1.0,
						true
					)



func p_ping_pong(v: float) -> float:
	v = clampf(v, 0.0, 1.0)

	if v <= 0.5:
		return v * 2.0

	return (1.0 - v) * 2.0




# =====================================================================
# EFEITO DE CESTA (partículas + onda na grade)
# =====================================================================
func _efeito_cesta(combo_nivel: int = 1) -> void:
	var tela := get_viewport_rect().size
	var origem := Vector2(tela.x * 0.5, tela.y * 0.365)

	_disparar_onda_grade(origem, false, combo_nivel)
	_disparar_luz_onda_cesta(origem, false, 1.0, combo_nivel)



func _efeito_cesta_record(grande: bool, combo_nivel: int = 4) -> void:
	var origem := _record_origem_fx()

	# No recorde, o efeito visual é na grade.
	# Cesta no recorde = onda de quadrados indo e voltando.
	_disparar_onda_grade(origem, false, 9, true)

	if grande:
		_disparar_onda_grade(origem, false, 9, true)
		_flash_bordas_record()


func _flash_recorde() -> void:
	var layer := CanvasLayer.new()
	layer.name = "FlashRecordeLabel"
	layer.layer = 32
	add_child(layer)

	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(raiz)

	var painel := Panel.new()
	_ancorar(painel, 0.145, 0.325, 0.855, 0.405)
	painel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.025, 0.0, 0.88)
	sb.border_color = COR_RECORDE
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	sb.shadow_color = Color(COR_RECORDE.r, COR_RECORDE.g, COR_RECORDE.b, 0.82)
	sb.shadow_size = 30
	painel.add_theme_stylebox_override("panel", sb)

	raiz.add_child(painel)

	var lbl := Label.new()
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.text = "RECORDE BATIDO!"
	lbl.add_theme_font_size_override("font_size", _fs(0.040))
	lbl.add_theme_color_override("font_color", COR_RECORDE_CLARO)
	lbl.add_theme_color_override("font_outline_color", Color(0.28, 0.08, 0.0))
	lbl.add_theme_constant_override("outline_size", 7)
	_aplicar_fonte(lbl)
	painel.add_child(lbl)

	painel.pivot_offset = painel.size * 0.5
	painel.scale = Vector2(0.72, 0.72)
	painel.modulate.a = 0.0

	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(painel, "modulate:a", 1.0, 0.12)
	t.tween_property(painel, "scale", Vector2(1.0, 1.0), 0.30)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.80).timeout

	var t2 := create_tween()
	t2.set_parallel(true)
	t2.tween_property(painel, "scale", Vector2(1.08, 1.08), 0.22)
	t2.tween_property(painel, "modulate:a", 0.0, 0.28)
	await t2.finished

	if is_instance_valid(layer):
		layer.queue_free()


func _flash_bordas_record() -> void:
	# Moldura dourada que pisca uma vez nas bordas da tela.
	var layer := CanvasLayer.new()
	layer.name = "FlashRecordeBordas"
	layer.layer = 13
	add_child(layer)
	var moldura := Panel.new()
	moldura.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(COR_RECORDE.r, COR_RECORDE.g, COR_RECORDE.b, 0.9)
	sb.set_border_width_all(10)
	sb.shadow_color = Color(1.0, 0.78, 0.14, 0.6)
	sb.shadow_size = 40
	moldura.add_theme_stylebox_override("panel", sb)
	layer.add_child(moldura)
	moldura.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(moldura, "modulate:a", 1.0, 0.12)
	t.tween_property(moldura, "modulate:a", 0.0, 0.5)
	t.tween_callback(layer.queue_free)


func _textura_brilho() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 64; tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex



# =====================================================================
# INPUT
# =====================================================================
func _unhandled_input(evento: InputEvent) -> void:
	# Alt+F4 fecha a tela com segurança.
	if evento is InputEventKey:
		if evento.pressed and not evento.echo and evento.keycode == KEY_F4 and evento.alt_pressed:
			_fechar_tela_seguro()
			_input_handled_seguro()
			return

	if _modal_turno_ativo:
		if _modal_turno_pronto and (_evento_start(evento) or _evento_tecla_1(evento)):
			_iniciar_turno_atual()
			_input_handled_seguro()
		return
	if _podio_ativo:
		if _evento_start(evento) or _evento_tecla_1(evento):
			_reiniciar_partida_do_podio()
			_input_handled_seguro()
		return
	if _rodando and _acao(evento, acao_cesta):
		if _trava_cesta_t > 0.0:
			_input_handled_seguro()
			return

		_trava_cesta_t = tempo_trava_cesta
		adicionar_ponto_jogador_atual(pontos_por_cesta)
		_input_handled_seguro()
		return


func _input_handled_seguro() -> void:
	if not is_inside_tree():
		return
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _acao(evento: InputEvent, nome: String) -> bool:
	return nome != "" and InputMap.has_action(nome) and evento.is_action_pressed(nome)


func _evento_start(evento: InputEvent) -> bool:
	if not evento.is_pressed():
		return false
	if evento is InputEventKey and evento.echo:
		return false
	return _acao(evento, acao_start)


func _evento_tecla_1(evento: InputEvent) -> bool:
	if evento is InputEventKey and evento.pressed and not evento.echo:
		return evento.keycode == KEY_1 or evento.keycode == KEY_KP_1
	return false



func _voltar_abertura() -> void:
	_podio_ativo = false
	await _transicao_saida("SAINDO DA ARENA", "VOLTANDO AO MENU")
	if cena_abertura != "":
		_trocar_cena(cena_abertura)
	else:
		var tela_node := get_node_or_null("/root/Tela")
		if tela_node != null and tela_node.has_method("recarregar"):
			tela_node.recarregar()
		else:
			get_tree().reload_current_scene()


# =====================================================================
# TEMPO / FUNDO / CONFIG
# =====================================================================
func _atualizar_tempo_label() -> void:
	if lbl_crono == null:
		return
	var total := int(ceil(_tempo_restante))
	lbl_crono.text = str(total)
	if _tempo_restante <= 10.0 and _rodando:
		lbl_crono.add_theme_color_override("font_color", Color(1, 0.4, 0.35))
	else:
		lbl_crono.add_theme_color_override("font_color", COR_VERDE_DISPLAY)


func _carregar_fundo() -> void:
	if fundo == null:
		return
	var tex := load(caminho_fundo) as Texture2D
	if tex:
		fundo.texture = tex
	else:
		push_warning("Game: fundo não encontrado em " + caminho_fundo)


func _aplicar_config_basket() -> void:
	if not usar_config_tempo_partida:
		tempo_partida = 60.0
		modo_credito = false
		return
	var cfg := ConfigFile.new()
	var err: int = cfg.load(caminho_config_basket)
	if err == OK:
		tempo_partida = float(cfg.get_value("jogo", "tempo_partida", 60.0))
		modo_credito = bool(cfg.get_value("jogo", "modo_credito", false))
		var modo_txt: String = str(cfg.get_value("jogo", "modo_operacao", "livre")).to_lower()
		if modo_txt == "credito" or modo_txt == "crédito":
			modo_credito = true
	else:
		tempo_partida = 60.0
		modo_credito = false
		cfg.set_value("jogo", "tempo_partida", tempo_partida)
		cfg.set_value("jogo", "modo_credito", modo_credito)
		cfg.set_value("jogo", "modo_operacao", "credito" if modo_credito else "livre")
		cfg.save(caminho_config_basket)
	tempo_partida = clampf(tempo_partida, 10.0, 600.0)


func _aplicar_shader_fundo_retrato() -> void:
	if fundo == null:
		return
	if not usar_shader_fundo:
		fundo.material = null
		return
	# Fundo "arcade china": azul-elétrico, raios laterais subindo, bloom suave,
	# grão fino anti-banding. Sem quadriculado pixelado.
	var shader := Shader.new()
	var s: String = ""
	s += "shader_type canvas_item;\n"
	s += "render_mode unshaded;\n"
	s += "uniform float intensidade = 0.40;\n"
	s += "float hash(vec2 p){ return fract(sin(dot(p, vec2(41.0,289.0)))*43758.5453); }\n"
	s += "float ruido(vec2 p){ vec2 i=floor(p); vec2 f=fract(p);\n"
	s += "  float a=hash(i); float b=hash(i+vec2(1.0,0.0));\n"
	s += "  float c=hash(i+vec2(0.0,1.0)); float d=hash(i+vec2(1.0,1.0));\n"
	s += "  vec2 u=f*f*(3.0-2.0*f);\n"
	s += "  return mix(mix(a,b,u.x),mix(c,d,u.x),u.y); }\n"
	s += "void fragment(){\n"
	s += "  vec2 uv=UV;\n"
	s += "  vec4 base=texture(TEXTURE,uv);\n"
	s += "  vec2 c=uv-vec2(0.5,0.42);\n"
	s += "  float d=length(c);\n"
	s += "  float vin=smoothstep(1.1,0.2,d);\n"
	s += "  base.rgb*=0.45+vin*0.55;\n"
	s += "  vec3 azul=vec3(0.12,0.45,1.0);\n"
	s += "  vec3 ciano=vec3(0.2,0.8,1.0);\n"
	s += "  base.rgb=mix(base.rgb, base.rgb*azul*1.3, 0.30);\n"
	# raios verticais nas laterais (descargas elétricas)
	s += "  float borda=smoothstep(0.30,0.0,uv.x)+smoothstep(0.70,1.0,uv.x);\n"
	s += "  float ray=ruido(vec2(uv.x*8.0, uv.y*3.0 - TIME*1.4));\n"
	s += "  ray=pow(ray,4.0)*borda;\n"
	s += "  base.rgb+=ciano*ray*intensidade*0.9;\n"
	# brilho central pulsante (arena)
	s += "  float pulso=0.85+0.15*sin(TIME*1.3);\n"
	s += "  float arena=smoothstep(0.65,0.0,d);\n"
	s += "  base.rgb+=azul*arena*intensidade*0.18*pulso;\n"
	# bloom fake
	s += "  float lum=dot(base.rgb,vec3(0.299,0.587,0.114));\n"
	s += "  float bloom=smoothstep(0.55,1.0,lum);\n"
	s += "  base.rgb+=base.rgb*bloom*0.45;\n"
	# grão anti-banding
	s += "  float n=ruido(uv*vec2(440.0,760.0)+TIME*0.6);\n"
	s += "  base.rgb+=(n-0.5)*0.015;\n"
	s += "  COLOR=base;\n"
	s += "}\n"
	shader.code = s
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("intensidade", intensidade_luz_fundo)
	fundo.material = mat


# =====================================================================
# FX AMBIENTE (bokeh suave)
# =====================================================================
func _criar_fx_ambiente() -> void:
	if not usar_fx_ambiente:
		return
	if fx_ambiente_layer != null and is_instance_valid(fx_ambiente_layer):
		return
	fx_ambiente_layer = CanvasLayer.new()
	fx_ambiente_layer.name = "FxAmbienteLayer"
	fx_ambiente_layer.layer = 2
	add_child(fx_ambiente_layer)
	fx_ambiente = Control.new()
	fx_ambiente.name = "FxAmbiente"
	fx_ambiente.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx_ambiente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_ambiente_layer.add_child(fx_ambiente)
	if not fx_ambiente.draw.is_connected(_desenhar_fx_ambiente):
		fx_ambiente.draw.connect(_desenhar_fx_ambiente)


func _atualizar_fx_ambiente(delta: float) -> void:
	if fx_ambiente == null:
		return
	_fx_tempo += delta
	fx_ambiente.queue_redraw()


func _desenhar_fx_ambiente() -> void:
	if fx_ambiente == null:
		return
	var tela := get_viewport_rect().size
	var centro := Vector2(tela.x * 0.5, tela.y * 0.245)
	for a in range(5):
		var raio := 90.0 + a * 55.0 + sin(_fx_tempo * 1.2 + a) * 8.0
		fx_ambiente.draw_circle(centro, raio, Color(COR_AZUL.r, COR_AZUL.g, COR_AZUL.b, 0.014 - a * 0.0022))


# =====================================================================
# RECORDE
# =====================================================================
func _carregar_record_basket() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(caminho_record_basket)
	if err == OK:
		record_maximo = int(cfg.get_value("recorde", "maximo", 0))
	else:
		record_maximo = 0
		cfg.set_value("recorde", "maximo", record_maximo)
		cfg.save(caminho_record_basket)


func _salvar_record_basket() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("recorde", "maximo", record_maximo)
	cfg.save(caminho_record_basket)


func _verificar_recorde_atual() -> void:
	if _jogador_atual < 0 or _jogador_atual >= num_jogadores:
		return
	var pontos_atuais: int = int(_pontos[_jogador_atual])
	if pontos_atuais > record_maximo:
		record_maximo = pontos_atuais
		_salvar_record_basket()
		_atualizar_high_label()
		_atualizar_placar_labels()


# =====================================================================
# TRANSIÇÃO
# =====================================================================
func _criar_transicao_layer() -> void:
	if transicao_layer != null and is_instance_valid(transicao_layer):
		return
	transicao_layer = CanvasLayer.new()
	transicao_layer.name = "TransicaoLayer"
	transicao_layer.layer = 100
	add_child(transicao_layer)
	transicao_root = Control.new()
	transicao_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transicao_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transicao_layer.add_child(transicao_root)
	transicao_fundo = ColorRect.new()
	transicao_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transicao_fundo.color = Color(0.0, 0.0, 0.0, 1.0)
	transicao_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transicao_root.add_child(transicao_fundo)
	transicao_fx = Control.new()
	transicao_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transicao_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transicao_root.add_child(transicao_fx)
	if not transicao_fx.draw.is_connected(_desenhar_transicao_fx):
		transicao_fx.draw.connect(_desenhar_transicao_fx)
	transicao_titulo = Label.new()
	transicao_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transicao_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	transicao_titulo.add_theme_font_size_override("font_size", _fs(0.052))
	transicao_titulo.add_theme_color_override("font_color", Color.WHITE)
	transicao_titulo.add_theme_color_override("font_outline_color", COR_VERDE_DISPLAY)
	transicao_titulo.add_theme_constant_override("outline_size", 9)
	_aplicar_fonte(transicao_titulo)
	transicao_root.add_child(transicao_titulo)
	transicao_subtitulo = Label.new()
	transicao_subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transicao_subtitulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	transicao_subtitulo.add_theme_font_size_override("font_size", _fs(0.022))
	transicao_subtitulo.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	transicao_subtitulo.add_theme_color_override("font_outline_color", Color.BLACK)
	transicao_subtitulo.add_theme_constant_override("outline_size", 4)
	_aplicar_fonte(transicao_subtitulo)
	transicao_root.add_child(transicao_subtitulo)
	transicao_barra_fundo = Panel.new()
	transicao_barra_fundo.add_theme_stylebox_override("panel", _estilo_barra_transicao(false))
	transicao_root.add_child(transicao_barra_fundo)
	transicao_barra = ColorRect.new()
	transicao_barra.color = COR_VERDE_DISPLAY
	transicao_barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transicao_root.add_child(transicao_barra)
	_ajustar_transicao_layout()
	transicao_root.visible = false


func _ajustar_transicao_layout() -> void:
	if transicao_root == null:
		return
	var tela := get_viewport_rect().size
	transicao_root.position = Vector2.ZERO
	transicao_root.size = tela
	if transicao_fundo != null:
		transicao_fundo.position = Vector2.ZERO; transicao_fundo.size = tela
	if transicao_fx != null:
		transicao_fx.position = Vector2.ZERO; transicao_fx.size = tela
	if transicao_titulo != null:
		transicao_titulo.position = Vector2(0.0, tela.y * 0.395); transicao_titulo.size = Vector2(tela.x, tela.y * 0.105)
	if transicao_subtitulo != null:
		transicao_subtitulo.position = Vector2(0.0, tela.y * 0.505); transicao_subtitulo.size = Vector2(tela.x, tela.y * 0.060)
	var barra_w: float = tela.x * 0.66
	var barra_h: float = max(12.0, tela.y * 0.012)
	var barra_x: float = (tela.x - barra_w) * 0.5
	var barra_y: float = tela.y * 0.605
	if transicao_barra_fundo != null:
		transicao_barra_fundo.position = Vector2(barra_x, barra_y); transicao_barra_fundo.size = Vector2(barra_w, barra_h)
	if transicao_barra != null:
		transicao_barra.position = Vector2(barra_x + 3.0, barra_y + 3.0); transicao_barra.size = Vector2(1.0, max(2.0, barra_h - 6.0))


func _estilo_barra_transicao(ativo: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.10, 0.92)
	sb.border_color = COR_AZUL
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(20)
	sb.shadow_color = Color(COR_AZUL.r, COR_AZUL.g, COR_AZUL.b, 0.42)
	sb.shadow_size = 18 if ativo else 10
	return sb


func _transicao_entrada(titulo: String, subtitulo: String) -> void:
	if transicao_root == null:
		return
	_ajustar_transicao_layout()
	_transicao_ativa = true
	_transicao_t = 0.0
	transicao_root.visible = true
	transicao_root.modulate.a = 1.0
	transicao_titulo.text = titulo
	transicao_subtitulo.text = subtitulo
	var tela := get_viewport_rect().size
	var barra_w_final: float = max(1.0, tela.x * 0.66 - 6.0)
	transicao_barra.size.x = 1.0
	transicao_fx.queue_redraw()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(transicao_barra, "size:x", barra_w_final, 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(transicao_root, "modulate:a", 0.0, 0.42).set_delay(0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	transicao_root.visible = false
	_transicao_ativa = false


func _transicao_saida(titulo: String, subtitulo: String) -> void:
	if transicao_root == null:
		return
	_ajustar_transicao_layout()
	_transicao_ativa = true
	_transicao_t = 0.0
	transicao_root.visible = true
	transicao_root.modulate.a = 0.0
	transicao_titulo.text = titulo
	transicao_subtitulo.text = subtitulo
	transicao_barra.size.x = 1.0
	transicao_fx.queue_redraw()
	var tela := get_viewport_rect().size
	var barra_w_final: float = max(1.0, tela.x * 0.66 - 6.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(transicao_root, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(transicao_barra, "size:x", barra_w_final, 0.56).set_delay(0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	_transicao_ativa = false


func _desenhar_transicao_fx() -> void:
	if transicao_fx == null:
		return
	var tela := get_viewport_rect().size
	var centro := Vector2(tela.x * 0.5, tela.y * 0.48)
	for i in range(7):
		var raio := 80.0 + float(i) * 52.0 + sin(_transicao_t * 2.2 + float(i)) * 8.0
		var alpha := 0.09 - float(i) * 0.010
		transicao_fx.draw_arc(centro, raio, _transicao_t + float(i) * 0.3,
			_transicao_t + TAU * 0.72 + float(i) * 0.3, 90,
			Color(COR_AZUL.r, COR_AZUL.g, COR_AZUL.b, alpha), 4.0, true)


# =====================================================================
# PÓDIO (mantido do anterior, cores ajustadas ao tema)
# =====================================================================
func _mostrar_podio() -> void:
	var ordem := _ranking()
	_podio_retorno_token += 1
	lbl_podio_timer = null
	_podio_ativo = false
	_podio_layer = CanvasLayer.new()
	_podio_layer.name = "PodioLayer"
	_podio_layer.layer = 20
	add_child(_podio_layer)
	var escuro := ColorRect.new()
	escuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	escuro.color = Color(0.0, 0.0, 0.0, 0.0)
	escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_podio_layer.add_child(escuro)
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.modulate.a = 0.0
	raiz.position.y = 90.0
	_podio_layer.add_child(raiz)
	var painel_fundo := Panel.new()
	_ancorar(painel_fundo, 0.040, 0.095, 0.960, 0.865)
	painel_fundo.add_theme_stylebox_override("panel", _estilo_painel_resultado())
	raiz.add_child(painel_fundo)
	var titulo := Label.new()
	titulo.text = "RESULTADO FINAL"
	_ancorar(titulo, 0.05, 0.115, 0.95, 0.185)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", _fs(0.050))
	titulo.add_theme_color_override("font_color", Color.WHITE)
	titulo.add_theme_color_override("font_outline_color", COR_AZUL)
	titulo.add_theme_constant_override("outline_size", 9)
	_aplicar_fonte(titulo)
	raiz.add_child(titulo)
	var subtitulo := Label.new()
	subtitulo.text = "COMPARATIVO DE CESTAS"
	_ancorar(subtitulo, 0.05, 0.180, 0.95, 0.225)
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitulo.add_theme_font_size_override("font_size", _fs(0.022))
	subtitulo.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
	subtitulo.add_theme_color_override("font_outline_color", Color.BLACK)
	subtitulo.add_theme_constant_override("outline_size", 4)
	_aplicar_fonte(subtitulo)
	raiz.add_child(subtitulo)
	var linha := HBoxContainer.new()
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 14)
	_ancorar(linha, 0.065, 0.265, 0.935, 0.735)
	raiz.add_child(linha)
	_podio_linha_dif = Control.new()
	_podio_linha_dif.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ancorar(_podio_linha_dif, 0.0, 0.0, 1.0, 1.0)
	_podio_linha_dif.modulate.a = 0.0
	raiz.add_child(_podio_linha_dif)
	if not _podio_linha_dif.draw.is_connected(_desenhar_linha_diferenca):
		_podio_linha_dif.draw.connect(_desenhar_linha_diferenca)
	var maior_ponto: int = 1
	for i in range(num_jogadores):
		maior_ponto = max(maior_ponto, int(_pontos[i]))
	var ordem_crescente: Array = ordem.duplicate()
	ordem_crescente.reverse()
	var cards_animar: Array = []
	_podio_cards_ref.clear()
	for idx in ordem_crescente:
		var lugar := ordem.find(idx) + 1
		var card_info: Dictionary = _criar_coluna_resultado(linha, idx, lugar, maior_ponto)
		card_info["cestas_real"] = int(_pontos[idx])
		cards_animar.append(card_info)
		_podio_cards_ref.append(card_info)
	lbl_podio_timer = Label.new()
	lbl_podio_timer.text = "AGUARDE O RESULTADO..."
	_ancorar(lbl_podio_timer, 0.05, 0.775, 0.95, 0.825)
	lbl_podio_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_podio_timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_podio_timer.add_theme_font_size_override("font_size", _fs(0.024))
	lbl_podio_timer.add_theme_color_override("font_color", Color.WHITE)
	lbl_podio_timer.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_podio_timer.add_theme_constant_override("outline_size", 5)
	_aplicar_fonte(lbl_podio_timer)
	raiz.add_child(lbl_podio_timer)
	var dica := Label.new()
	dica.text = "START RECOMEÇA A PARTIDA"
	_ancorar(dica, 0.05, 0.825, 0.95, 0.875)
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dica.add_theme_font_size_override("font_size", _fs(0.021))
	dica.add_theme_color_override("font_color", COR_AMBAR)
	dica.add_theme_color_override("font_outline_color", Color.BLACK)
	dica.add_theme_constant_override("outline_size", 4)
	_aplicar_fonte(dica)
	raiz.add_child(dica)
	var t1 := create_tween()
	t1.tween_property(escuro, "color:a", 0.84, 0.40)
	var t2 := create_tween()
	t2.set_parallel(true)
	t2.tween_property(raiz, "modulate:a", 1.0, 0.42)
	t2.tween_property(raiz, "position:y", 0.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t2.finished
	for i in range(cards_animar.size()):
		await _animar_coluna_resultado(cards_animar[i], 0.0)
		await get_tree().create_timer(0.12).timeout
	if num_jogadores >= 2 and _podio_linha_dif != null:
		await get_tree().create_timer(0.10).timeout
		_podio_linha_dif.queue_redraw()
		var tl := create_tween()
		tl.tween_property(_podio_linha_dif, "modulate:a", 1.0, 0.45)
		await tl.finished
		await get_tree().create_timer(1.8).timeout
		var ts := create_tween()
		ts.tween_property(_podio_linha_dif, "modulate:a", 0.0, 0.55)
		await ts.finished
	await get_tree().create_timer(0.15).timeout
	_disparar_confete()
	await get_tree().create_timer(0.7).timeout
	lbl_podio_timer.text = "START RECOMEÇA  •  VOLTA AO MENU EM %d" % segundos_retorno_opening_podio
	var pisca := create_tween().set_loops()
	pisca.tween_property(dica, "modulate:a", 0.30, 0.65)
	pisca.tween_property(dica, "modulate:a", 1.0, 0.65)
	_podio_ativo = true
	_contagem_retorno_opening_podio(_podio_retorno_token)


func _desenhar_linha_diferenca() -> void:
	if _podio_linha_dif == null or _podio_cards_ref.size() < 2:
		return
	var tela := get_viewport_rect().size
	var gap: float = tela.y * 0.045
	var inv := _podio_linha_dif.get_global_transform().affine_inverse()
	var col_tops: Array = []
	var marcadores: Array = []
	var valores: Array = []
	for info in _podio_cards_ref:
		var card: Panel = info.get("card", null)
		if card == null or not is_instance_valid(card):
			continue
		var topo_global: Vector2 = card.global_position + Vector2(card.size.x * 0.5, 0.0)
		var topo_local: Vector2 = inv * topo_global
		col_tops.append(topo_local)
		marcadores.append(topo_local - Vector2(0.0, gap))
		valores.append(int(info.get("cestas_real", info.get("cestas", 0))))
	if marcadores.size() < 2:
		return
	var cor_linha := Color(COR_AZUL.r, COR_AZUL.g, COR_AZUL.b, 0.95)
	for i in range(marcadores.size()):
		_podio_linha_dif.draw_line(col_tops[i], marcadores[i], Color(cor_linha.r, cor_linha.g, cor_linha.b, 0.30), 2.0, true)
	for i in range(marcadores.size() - 1):
		_desenhar_tracejado(marcadores[i], marcadores[i + 1], cor_linha, 3.0, 14.0, 8.0)
	for m in marcadores:
		_podio_linha_dif.draw_circle(m, 6.0, cor_linha)
		_podio_linha_dif.draw_circle(m, 3.0, Color(1, 1, 1, 0.95))
	var fonte := ThemeDB.fallback_font
	var tam := _fs(0.019)
	for i in range(marcadores.size() - 1):
		var dif: int = valores[i + 1] - valores[i]
		if dif == 0:
			continue
		var meio: Vector2 = (marcadores[i] + marcadores[i + 1]) * 0.5 + Vector2(0.0, -14.0)
		var txt := "+%d" % dif
		var largura := fonte.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x
		_podio_linha_dif.draw_string(fonte, meio - Vector2(largura * 0.5, 0.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, COR_AMBAR)


func _desenhar_tracejado(de: Vector2, ate: Vector2, cor: Color, esp: float, traco: float, vao: float) -> void:
	var total: float = de.distance_to(ate)
	if total <= 0.0:
		return
	var dir: Vector2 = (ate - de) / total
	var pos: float = 0.0
	while pos < total:
		var ini: Vector2 = de + dir * pos
		var fim: Vector2 = de + dir * min(pos + traco, total)
		_podio_linha_dif.draw_line(ini, fim, cor, esp, true)
		pos += traco + vao


func _ranking() -> Array:
	var idxs: Array = []
	for i in range(num_jogadores):
		idxs.append(i)
	idxs.sort_custom(func(a, b):
		if int(_pontos[a]) == int(_pontos[b]):
			return a < b
		return int(_pontos[a]) > int(_pontos[b])
	)
	return idxs


func _cor_medalha(lugar: int) -> Color:
	match lugar:
		1: return Color(1.0, 0.84, 0.0)
		2: return Color(0.75, 0.75, 0.8)
		3: return Color(0.8, 0.5, 0.2)
		_: return Color(0.6, 0.6, 0.6)


func _disparar_confete() -> void:
	var tela := get_viewport_rect().size
	var confete := CPUParticles2D.new()
	confete.position = Vector2(tela.x * 0.5, -20.0)
	confete.amount = 120
	confete.lifetime = 4.0
	confete.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confete.emission_rect_extents = Vector2(tela.x * 0.5, 8.0)
	confete.direction = Vector2(0, 1)
	confete.spread = 25.0
	confete.gravity = Vector2(0, 220)
	confete.initial_velocity_min = 80.0
	confete.initial_velocity_max = 200.0
	confete.angular_velocity_min = -200.0
	confete.angular_velocity_max = 200.0
	confete.scale_amount_min = 2.0
	confete.scale_amount_max = 5.0
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	grad.colors = PackedColorArray([Color(1, 0.84, 0), Color(1, 0.3, 0.3), Color(0.3, 0.6, 1), Color(0.3, 1, 0.5)])
	confete.color_ramp = grad
	_podio_layer.add_child(confete)
	confete.emitting = true


func _criar_coluna_resultado(linha: HBoxContainer, idx: int, lugar: int, maior_ponto: int) -> Dictionary:
	var cor: Color = CORES_PLAYERS[idx % CORES_PLAYERS.size()]
	var cestas: int = int(_pontos[idx])
	var ratio: float = clampf(float(cestas) / float(max(1, maior_ponto)), 0.05, 1.0)
	var diferenca_vencedor: int = maior_ponto - cestas
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 8)
	linha.add_child(col)
	var espaco := Control.new()
	espaco.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(espaco)
	var card := Panel.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_END
	card.custom_minimum_size = Vector2(0.0, lerpf(190.0, 410.0, ratio))
	card.add_theme_stylebox_override("panel", _estilo_card_resultado(cor, lugar))
	card.modulate.a = 0.0
	card.scale = Vector2(1.0, 0.08)
	col.add_child(card)
	var dentro := VBoxContainer.new()
	dentro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dentro.offset_left = 10; dentro.offset_right = -10; dentro.offset_top = 12; dentro.offset_bottom = -12
	dentro.alignment = BoxContainer.ALIGNMENT_CENTER
	dentro.add_theme_constant_override("separation", 5)
	card.add_child(dentro)
	var lbl_lugar := Label.new()
	lbl_lugar.text = "%dº" % lugar
	lbl_lugar.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_lugar.add_theme_font_size_override("font_size", _fs(0.036 if lugar == 1 else 0.030))
	lbl_lugar.add_theme_color_override("font_color", _cor_medalha(lugar))
	lbl_lugar.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_lugar.add_theme_constant_override("outline_size", 5)
	_aplicar_fonte(lbl_lugar)
	dentro.add_child(lbl_lugar)
	var lbl_nome := Label.new()
	lbl_nome.text = str(_nomes[idx])
	lbl_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_nome.add_theme_font_size_override("font_size", _fs(0.020))
	lbl_nome.add_theme_color_override("font_color", Color.WHITE)
	lbl_nome.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_nome.add_theme_constant_override("outline_size", 4)
	_aplicar_fonte(lbl_nome)
	dentro.add_child(lbl_nome)
	var lbl_cestas := Label.new()
	lbl_cestas.text = "0"
	lbl_cestas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_cestas.add_theme_font_size_override("font_size", _fs(0.080 if lugar == 1 else 0.064))
	lbl_cestas.add_theme_color_override("font_color", Color.WHITE)
	lbl_cestas.add_theme_color_override("font_outline_color", cor)
	lbl_cestas.add_theme_constant_override("outline_size", 8)
	_aplicar_fonte(lbl_cestas)
	dentro.add_child(lbl_cestas)
	var lbl_txt := Label.new()
	lbl_txt.text = "CESTAS"
	lbl_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_txt.add_theme_font_size_override("font_size", _fs(0.018))
	lbl_txt.add_theme_color_override("font_color", cor)
	lbl_txt.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_txt.add_theme_constant_override("outline_size", 3)
	_aplicar_fonte(lbl_txt)
	dentro.add_child(lbl_txt)
	var lbl_dif := Label.new()
	lbl_dif.text = "MELHOR RESULTADO" if lugar == 1 else "-%d DO 1º LUGAR" % diferenca_vencedor
	lbl_dif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_dif.add_theme_font_size_override("font_size", _fs(0.015))
	lbl_dif.add_theme_color_override("font_color", Color(0.86, 0.90, 1.0))
	lbl_dif.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_dif.add_theme_constant_override("outline_size", 3)
	_aplicar_fonte(lbl_dif)
	dentro.add_child(lbl_dif)
	var barra_fundo := Panel.new()
	barra_fundo.custom_minimum_size = Vector2(0.0, 18.0)
	barra_fundo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra_fundo.clip_contents = true
	barra_fundo.add_theme_stylebox_override("panel", _estilo_barra_resultado(Color(0.10, 0.11, 0.16, 0.90)))
	dentro.add_child(barra_fundo)
	var trilho := Control.new()
	trilho.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trilho.offset_left = 3.0; trilho.offset_top = 3.0; trilho.offset_right = -3.0; trilho.offset_bottom = -3.0
	trilho.clip_contents = true
	trilho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	barra_fundo.add_child(trilho)
	var barra := Panel.new()
	barra.add_theme_stylebox_override("panel", _estilo_preenche_barra(cor))
	barra.anchor_left = 0.0; barra.anchor_top = 0.0; barra.anchor_right = 0.0; barra.anchor_bottom = 1.0
	barra.offset_left = 0.0; barra.offset_top = 0.0; barra.offset_right = 0.0; barra.offset_bottom = 0.0
	barra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trilho.add_child(barra)
	return {"card": card, "label_cestas": lbl_cestas, "barra": barra, "ratio": ratio, "cestas": cestas, "cor": cor, "lugar": lugar}






func _estilo_barra_resultado(cor: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.border_color = Color(1.0, 1.0, 1.0, 0.16)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	sb.shadow_size = 8
	sb.anti_aliasing = true
	return sb


func _estilo_preenche_barra(cor: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(cor.r, cor.g, cor.b, 0.95)
	sb.border_color = Color(1.0, 1.0, 1.0, 0.20)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(cor.r, cor.g, cor.b, 0.65)
	sb.shadow_size = 12
	sb.anti_aliasing = true
	return sb


func _contagem_retorno_opening_podio(token: int) -> void:
	var segundos: int = segundos_retorno_opening_podio
	while segundos >= 0:
		if token != _podio_retorno_token or not _podio_ativo:
			return
		if lbl_podio_timer != null:
			lbl_podio_timer.text = "START RECOMEÇA  •  VOLTA AO MENU EM %d" % segundos
		await get_tree().create_timer(1.0).timeout
		segundos -= 1
	if token != _podio_retorno_token or not _podio_ativo:
		return
	_voltar_abertura()


func _reiniciar_partida_do_podio() -> void:
	_podio_retorno_token += 1
	_podio_ativo = false
	if _podio_layer != null:
		_podio_layer.queue_free()
		_podio_layer = null
	lbl_podio_timer = null
	_podio_linha_dif = null
	_podio_cards_ref.clear()
	_pontos = [0, 0, 0, 0]
	_turnos_finalizados = [false, false, false, false]
	_jogador_atual = 0
	_tempo_restante = 0.0
	_rodando = false
	_modal_turno_ativo = false
	_modal_turno_pronto = false
	for n in [card_jogando, col_players]:
		if n != null:
			n.visible = true
			n.modulate = Color(1, 1, 1, 1)
	if musica_fundo != null:
		musica_fundo.volume_db = volume_musica_db
		if musica_fundo.stream != null and not musica_fundo.playing:
			musica_fundo.play()
	_atualizar_visao_turno()
	_atualizar_tempo_label()
	await get_tree().create_timer(0.25).timeout
	_mostrar_modal_turno(true)


func _animar_coluna_resultado(info: Dictionary, atraso: float = 0.0) -> void:
	var card: Panel = info.get("card", null)
	var lbl_cestas: Label = info.get("label_cestas", null)
	var barra: Control = info.get("barra", null)
	var ratio: float = float(info.get("ratio", 0.0))
	var cestas: int = int(info.get("cestas", 0))
	var lugar: int = int(info.get("lugar", 0))
	if card == null:
		return
	card.pivot_offset = Vector2(card.size.x * 0.5, card.size.y)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "modulate:a", 1.0, 0.24).set_delay(atraso)
	tw.tween_property(card, "scale", Vector2.ONE, 0.38).set_delay(atraso).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if barra != null:
		var destino := clampf(ratio, 0.0, 1.0)
		barra.anchor_right = 0.0
		tw.tween_property(barra, "anchor_right", destino, 0.55).set_delay(atraso + 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if lbl_cestas != null:
		lbl_cestas.text = "0"
		tw.tween_method(Callable(self, "_atualizar_numero_resultado").bind(lbl_cestas), 0.0, float(cestas), 0.62).set_delay(atraso + 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	if lugar == 1 and card != null:
		var brilho := create_tween()
		brilho.tween_property(card, "scale", Vector2(1.04, 1.04), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		brilho.tween_property(card, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.04).timeout


func _atualizar_numero_resultado(valor: float, lbl: Label) -> void:
	if lbl == null:
		return
	lbl.text = str(int(round(valor)))



func _estilo_painel_resultado() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.012, 0.02, 0.04, 0.90)
	sb.border_color = Color(COR_AZUL.r, COR_AZUL.g, COR_AZUL.b, 0.78)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(40)
	sb.set_content_margin_all(22)
	sb.shadow_color = Color(COR_AZUL.r, COR_AZUL.g, COR_AZUL.b, 0.38)
	sb.shadow_size = 48
	return sb


func _estilo_card_resultado(cor: Color, lugar: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if lugar == 1:
		sb.bg_color = Color(0.10, 0.085, 0.02, 0.92)
		sb.border_color = Color(1.0, 0.84, 0.18, 1.0)
		sb.shadow_color = Color(1.0, 0.78, 0.16, 0.78)
		sb.shadow_size = 46
	else:
		sb.bg_color = Color(cor.r * 0.10, cor.g * 0.10, cor.b * 0.10, 0.82)
		sb.border_color = Color(cor.r, cor.g, cor.b, 0.78)
		sb.shadow_color = Color(cor.r, cor.g, cor.b, 0.34)
		sb.shadow_size = 26
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(30)
	sb.set_content_margin_all(12)
	return sb



func _altura_card_player() -> float:
	var tela_y: float = get_viewport_rect().size.y

	match num_jogadores:
		1:
			return clampf(tela_y * 0.078, 62.0, 88.0)
		2:
			return clampf(tela_y * 0.074, 60.0, 84.0)
		3:
			return clampf(tela_y * 0.070, 56.0, 78.0)
		_:
			return clampf(tela_y * 0.066, 52.0, 72.0)


func _largura_min_card_player_rodape() -> float:
	var tela_x: float = get_viewport_rect().size.x

	match num_jogadores:
		1:
			return clampf(tela_x * 0.26, 180.0, 280.0)
		2:
			return clampf(tela_x * 0.22, 150.0, 240.0)
		3:
			return clampf(tela_x * 0.18, 120.0, 210.0)
		_:
			return clampf(tela_x * 0.14, 90.0, 170.0)


func _fonte_nome_card_player_rodape() -> int:
	match num_jogadores:
		1:
			return _fs(0.019)
		2:
			return _fs(0.017)
		3:
			return _fs(0.0145)
		_:
			return _fs(0.012)



func _fonte_pontos_card_player_rodape() -> int:
	match num_jogadores:
		1:
			return _fs(0.032)
		2:
			return _fs(0.028)
		3:
			return _fs(0.024)
		_:
			return _fs(0.020)



func _enviar_led_basket(cmd: String) -> void:
	if not usar_leds_arduino:
		return

	var f := FileAccess.open(caminho_fila_leds_basket, FileAccess.WRITE)
	if f == null:
		push_warning("Basket LEDs: não consegui escrever comando " + cmd)
		return

	# O número no final garante que HIT/BOOST repetido seja sempre um comando novo.
	var linha := "%s:%d" % [cmd, Time.get_ticks_msec()]
	f.store_line(linha)
	f.close()

	print("LED CMD -> ", linha)



func _iniciar_ponte_leds_play() -> void:
	if not usar_ponte_leds_no_play:
		return

	if not usar_leds_arduino:
		return

	if OS.get_name() != "Windows":
		return

	if _led_bridge_pid > 0:
		return

	var cmd_abs := ProjectSettings.globalize_path(caminho_fila_leds_basket)

	# Limpa comando antigo para não mandar coisa velha.
	if FileAccess.file_exists(caminho_fila_leds_basket):
		DirAccess.remove_absolute(cmd_abs)

	var f := FileAccess.open(_led_bridge_ps, FileAccess.WRITE)
	if f:
		f.store_string(_PS_BRIDGE_BASKET)
		f.close()

	var ps_abs := ProjectSettings.globalize_path(_led_bridge_ps)

	var args := [
		"-ExecutionPolicy", "Bypass",
		"-NoProfile",
		"-WindowStyle", "Hidden",
		"-File", ps_abs,
		"-Porta", porta_leds,
		"-Baud", str(baud_leds),
		"-Arquivo", cmd_abs
	]

	_led_bridge_pid = OS.create_process("powershell.exe", args)

	# Tempo maior para garantir que a COM5 abriu.
	OS.delay_msec(350)



func _fechar_ponte_leds_play(apagar: bool = true) -> void:
	if apagar:
		_enviar_led_basket("OFF")
		OS.delay_msec(120)

	if _led_bridge_pid > 0:
		OS.kill(_led_bridge_pid)
		_led_bridge_pid = -1



func _exit_tree() -> void:
	_fechar_ponte_leds_play(true)



func _record_origem_fx() -> Vector2:
	var tela := get_viewport_rect().size
	# Mais colado na cesta
	return Vector2(tela.x * 0.5, tela.y * 0.345)



func _atualizar_scores_players_hud() -> void:
	if box_players_score == null:
		return

	for c in box_players_score.get_children():
		c.queue_free()

	# Não mostra card, não mostra fundo e não mostra "aguardando".
	# Só aparecem os players que já terminaram o turno.
	for i in range(num_jogadores):
		if not bool(_turnos_finalizados[i]):
			continue

		var linha := _criar_linha_score_player(i)
		box_players_score.add_child(linha)



func _criar_linha_score_player(i: int) -> HBoxContainer:
	var cor: Color = CORES_PLAYERS[i % CORES_PLAYERS.size()]

	var linha := HBoxContainer.new()
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	linha.custom_minimum_size = Vector2(0, _altura_linha_score_players())
	linha.alignment = BoxContainer.ALIGNMENT_CENTER
	linha.add_theme_constant_override("separation", 6)

	var nome := Label.new()
	nome.text = _nome_curto_score(i)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nome.add_theme_font_size_override("font_size", _fonte_score_players_nome())
	nome.add_theme_color_override("font_color", cor)
	nome.add_theme_color_override("font_outline_color", Color.BLACK)
	nome.add_theme_constant_override("outline_size", 3)
	_aplicar_fonte(nome)
	linha.add_child(nome)

	var pts := Label.new()
	pts.text = "%02d" % int(_pontos[i])
	pts.custom_minimum_size = Vector2(_fs(0.040), 0)
	pts.size_flags_horizontal = Control.SIZE_SHRINK_END
	pts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pts.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pts.add_theme_font_size_override("font_size", _fonte_score_players_pontos())
	pts.add_theme_color_override("font_color", cor)
	pts.add_theme_color_override("font_outline_color", Color.BLACK)
	pts.add_theme_constant_override("outline_size", 4)
	_aplicar_fonte(pts)
	linha.add_child(pts)

	return linha



func _nome_curto_score(i: int) -> String:
	# Para 3 e 4 players, usa nome curto para não estourar o painel.
	if num_jogadores >= 3:
		return "P%d" % (i + 1)

	return str(_nomes[i])



func _altura_linha_score_players() -> float:
	var tela_y: float = get_viewport_rect().size.y

	match num_jogadores:
		1:
			return clampf(tela_y * 0.038, 30.0, 42.0)
		2:
			return clampf(tela_y * 0.026, 22.0, 30.0)
		3:
			return clampf(tela_y * 0.020, 18.0, 24.0)
		_:
			return clampf(tela_y * 0.016, 14.0, 20.0)



func _fonte_score_players_nome() -> int:
	match num_jogadores:
		1:
			return _fs(0.017)
		2:
			return _fs(0.014)
		3:
			return _fs(0.0115)
		_:
			return _fs(0.0095)



func _fonte_score_players_pontos() -> int:
	match num_jogadores:
		1:
			return _fs(0.024)
		2:
			return _fs(0.020)
		3:
			return _fs(0.016)
		_:
			return _fs(0.013)



func _trocar_cena(caminho: String) -> void:
	if caminho == "":
		return
	var tela_node := get_node_or_null("/root/Tela")
	if tela_node != null and tela_node.has_method("trocar"):
		tela_node.trocar(caminho)
	else:
		# Sem o autoload Tela: comportamento antigo.
		if ResourceLoader.exists(caminho):
			get_tree().change_scene_to_file(caminho)
