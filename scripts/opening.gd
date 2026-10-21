extends Control
# =====================================================================
# TELA DE ABERTURA (Opening) — BASKET (tela RETRATO)
# Fundo com shader (pulso/realce/shine/aberração), scanlines CRT,
# vinheta pulsante, START com glow e partículas intensas.
# START abre um MODAL NEON VERTICAL para escolher de 1 a 4 jogadores:
#   SELECT passa  •  START seleciona  •  (clique também funciona)
# A escolha fica em: get_tree().get_meta("num_jogadores").
# F10 vai para a cena de configuração.
#
# O MOUSE FICA SEMPRE OCULTO — tudo é feito pelos inputs físicos.
#
# NOVO: 2 LEDs RGB (NeoPixel) nas portas D2 e D3 do Arduino fazendo
# efeitos LARANJA que se alternam (onda, montagem 2 em 2, cometa,
# pulso, encontro no meio, faísca) via ponte PowerShell (COM/9600).
#
# AUTO-MONTAGEM: basta o nó raiz "Opening" (Control) com este script.
# =====================================================================

# ---------- CONFIGURAÇÕES (ajuste pelo Inspetor) ----------
@export_file("*.tscn") var proxima_cena: String = "res://scenes/play.tscn"
@export var cor_neon: Color = Color(1.0, 0.55, 0.1)
@export var permitir_avancar: bool = true
@export var texto_start_label: String = "PRESSIONE START"
@export var caminho_fonte: String = ""
@export_file("*.tscn") var cena_config: String = "res://scenes/config.tscn"
@export var caminho_som_selected: String = "res://songs/selected.mp3"
@export var acao_select: String = "input_select"
@export var acao_start_modal: String = "input_start"

# ---------- EFEITOS VISUAIS (shaders) ----------
@export var usar_efeitos_shader: bool = true
@export var intensidade_pulso: float = 0.12
@export var intensidade_aberracao: float = 0.0025
@export var intensidade_scanlines: float = 0.10

# ---------- LEDS RGB (Arduino D2 e D3) ----------
@export var usar_leds: bool = true
@export var porta_leds: String = "COM5"        # ajuste para a porta do gabinete
@export var baud_leds: int = 9600
@export var leds_por_pino: int = 8             # nº de pixels NeoPixel em CADA fita (D2/D3). Use 1 se forem LEDs simples.
@export var cor_leds: Color = Color(1.0, 0.45, 0.06)   # LARANJA
@export var fps_leds: float = 22.0             # taxa de atualização das animações
@export var segundos_por_efeito: float = 5.0   # tempo de cada efeito antes de trocar

# ---------- LEDS ARDUINO / RGB ----------
@export var usar_leds_arduino: bool = true
@export var caminho_fila_leds_basket: String = "user://basket_led_cmd.txt"



# ---------- HOLD SELECT PARA FECHAR MODAL ----------
@export var segundos_segurar_select_fechar_modal: float = 1.20
@export var intervalo_select_modal_ms: int = 360

var _select_nav_liberado_ms: int = 0
var _select_nav_precisa_soltar: bool = false


var _select_hold_t: float = 0.0
var _select_hold_fechou: bool = false


# ---------- CORES POR JOGADOR (iguais às do jogo) ----------
const CORES_JOGADORES := [
	Color(1.0, 0.27, 0.27),
	Color(0.27, 0.6, 1.0),
	Color(0.3, 1.0, 0.5),
	Color(1.0, 0.82, 0.2),
]

# ---------- NOMES DOS JOGADORES (mostrados no card) ----------
const NOMES_JOGADORES := ["VERMELHO", "AZUL", "VERDE", "AMARELO"]

# ---------- CAMINHOS DOS ASSETS ----------
const CAMINHO_MUSICA: String = "res://songs/intro_bask.mp3"
const CAMINHO_FUNDO: String = "res://images/basket_back.png"

# ---------- LEDS: nº de efeitos no rodízio ----------
const _LED_NUM_EFEITOS := 6

# ---------- PONTE POWERSHELL (escrita em código) ----------
# Lê o arquivo de comando, manda pra serial e apaga o arquivo.
# DtrEnable=$false evita o reset do Arduino ao abrir a porta.
const _PS_BRIDGE := """
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
	$sp.WriteTimeout = 60
	$sp.Open()
} catch {
	exit 1
}
while ($true) {
	try {
		if (Test-Path -LiteralPath $Arquivo) {
			$cmd = [System.IO.File]::ReadAllText($Arquivo)
			[System.IO.File]::Delete($Arquivo)
			if ($cmd.Length -gt 0) { $sp.Write($cmd) }
		}
	} catch {}
	Start-Sleep -Milliseconds 4
}
"""

# ---------- SHADERS (escritos em código) ----------
const _SHADER_FUNDO := """
shader_type canvas_item;

uniform float pulso_intensidade = 0.12;
uniform float pulso_velocidade = 2.2;
uniform float aberracao = 0.0025;
uniform float shine_velocidade = 0.18;
uniform vec4 cor_realce : source_color = vec4(1.0, 0.55, 0.1, 1.0);

void fragment() {
	vec2 uv = UV;
	vec2 centro = vec2(0.5);
	float dist = distance(uv, centro);
	vec2 dir = normalize(uv - centro + vec2(0.0001));
	float ab = aberracao * dist * 2.0;

	float r = texture(TEXTURE, uv - dir * ab).r;
	vec4 base = texture(TEXTURE, uv);
	float b = texture(TEXTURE, uv + dir * ab).b;
	vec3 col = vec3(r, base.g, b);

	float pulso = 1.0 + sin(TIME * pulso_velocidade) * pulso_intensidade;
	col *= pulso;

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	float realce = smoothstep(0.5, 0.95, lum);
	float p2 = 0.20 + 0.15 * sin(TIME * pulso_velocidade * 1.3);
	col += cor_realce.rgb * realce * p2;

	float sweep = sin((uv.x + uv.y) * 3.0 - TIME * shine_velocidade * 6.2831853);
	sweep = smoothstep(0.95, 1.0, sweep);
	col += sweep * 0.12;

	COLOR = vec4(col, base.a);
}
"""

const _SHADER_SCANLINES := """
shader_type canvas_item;

uniform float intensidade : hint_range(0.0, 0.5) = 0.10;
uniform float espessura = 3.0;

void fragment() {
	float s = sin(FRAGCOORD.y / espessura * 3.14159265);
	float linha = smoothstep(-1.0, 1.0, s);
	float a = (1.0 - linha) * intensidade;
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
"""

# ---------- PONTE POWERSHELL SIMPLES / COMANDO ----------
var _ponte_opening_pid: int = -1
var _ponte_opening_ps: String = "user://basket_opening_bridge.ps1"

const _PS_BRIDGE_OPENING_CMD := """
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


# ---------- REFERÊNCIAS DE NÓS ----------
var fundo: TextureRect
var vinheta: TextureRect
var particulas: CPUParticles2D
var musica: AudioStreamPlayer
var texto_start: Label
var fade_overlay: ColorRect
var modal_jogadores: Control
var modal_painel: Panel
var modal_glow: Panel
var som_select: AudioStreamPlayer
var scanlines: ColorRect

# ---------- MODAL ----------
var _lbl_titulo_modal: Label
var _lbl_subtitulo_modal: Label
var _linha_titulo: Panel
var _lista_cards: VBoxContainer
var _cards_modal: Array = []    # Buttons (1 a 4)
var _discos_modal: Array = []   # Panels do disco do número
var _nums_modal: Array = []     # Labels do número
var _txts_modal: Array = []     # Labels do "N JOGADORES"
var _nomes_modal: Array = []    # Labels com os nomes das cores
var _badges_modal: Array = []   # HBox de bolinhas coloridas
var _fundos_cards_modal: Array = [] # Painel de glow/fundo LED de cada card


var _avancando: bool = false
var _modal_aberto: bool = false
var _modal_pronto: bool = false
var _selecionando: bool = false
var _selecao_atual: int = 0
var _fechando_programa: bool = false
var _mudando_para_cena: bool = false


# ---------- LEDS (runtime) ----------
var _led_total: int = 0
var _led_cores: PackedColorArray = PackedColorArray()
var _led_acumulado: float = 0.0
var _led_tempo: float = 0.0
var _led_efeito: int = 0
var _led_efeito_tempo: float = 0.0
var _led_pid: int = -1
var _led_pronto: bool = false
var _led_caminho_cmd: String = "user://led_opening.cmd"
var _led_caminho_tmp: String = "user://led_opening.tmp"
var _led_caminho_ps: String = "user://led_bridge_opening.ps1"
var _led_caminho_cmd_abs: String = ""
var _led_caminho_tmp_abs: String = ""


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# Não deixa o Windows fechar direto sem antes apagar os LEDs.
	get_tree().auto_accept_quit = false

	_montar_cena()
	_carregar_assets()
	_aplicar_shader_fundo()
	_iniciar_musica()

	# Abre a ponte e liga o efeito chamativo da abertura.
	_iniciar_ponte_leds_opening()
	_enviar_led_basket("ATTRACT")

	if not get_viewport().size_changed.is_connected(_ajustar_modal_responsivo):
		get_viewport().size_changed.connect(_ajustar_modal_responsivo)

	await get_tree().process_frame

	_configurar_particulas()
	_animar_entrada()
	_animar_texto_start()
	_pulsar_vinheta()



func _process(delta: float) -> void:
	if _led_pronto:
		_atualizar_leds(delta)

	_atualizar_trava_select_soltar()
	_atualizar_hold_select_modal(delta)


func _atualizar_trava_select_soltar() -> void:
	if acao_select == "" or not InputMap.has_action(acao_select):
		_select_nav_precisa_soltar = false
		return

	# Só libera novo avanço depois que o botão físico for solto.
	if not Input.is_action_pressed(acao_select):
		_select_nav_precisa_soltar = false


func _exit_tree() -> void:
	# Se saiu para o Play/Config, não manda OFF aqui.
	# Se fechou o programa de verdade, apaga os LEDs antes de matar a ponte.
	if not _mudando_para_cena and not _fechando_programa:
		_enviar_led_basket("OFF")
		OS.delay_msec(180)

	_fechar_ponte_leds_opening(false)
	_encerrar_leds()


func _fechar_programa_seguro() -> void:
	if _fechando_programa:
		return

	_fechando_programa = true
	_modal_pronto = false
	_modal_aberto = false
	_selecionando = true
	_avancando = true

	# Apaga os LEDs mesmo se estiver travado no MENU_LOCK.
	_enviar_led_basket("OFF")
	OS.delay_msec(180)

	# Fecha a ponte da Opening.
	_fechar_ponte_leds_opening(false)

	# Fecha também a ponte antiga, caso esteja ativa.
	_encerrar_leds()

	get_tree().quit()


func _notification(what: int) -> void:
	# Reforça o mouse oculto caso a janela ganhe foco novamente.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_MOUSE_ENTER:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	# Fechamento pelo X da janela / Alt+F4 / encerramento do programa.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_fechar_programa_seguro()



func _fs(frac: float) -> int:
	# Tamanho de fonte proporcional à altura da tela (mínimo 12).
	return max(12, int(get_viewport_rect().size.y * frac))


func _ancorar_frac(c: Control, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = l
	c.anchor_top = t
	c.anchor_right = r
	c.anchor_bottom = b
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0


# =====================================================================
# AUTO-MONTAGEM DA CENA
# =====================================================================
func _montar_cena() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# --- Fundo ---
	if has_node("Fundo"):
		fundo = $Fundo
	else:
		fundo = TextureRect.new()
		fundo.name = "Fundo"
		add_child(fundo)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.stretch_mode = TextureRect.STRETCH_SCALE
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# --- Particulas ---
	if has_node("Particulas"):
		particulas = $Particulas
	else:
		particulas = CPUParticles2D.new()
		particulas.name = "Particulas"
		add_child(particulas)

	# --- Musica ---
	if has_node("Musica"):
		musica = $Musica
	else:
		musica = AudioStreamPlayer.new()
		musica.name = "Musica"
		add_child(musica)

	# --- Som de seleção (input_select) ---
	if has_node("SomSelect"):
		som_select = $SomSelect
	else:
		som_select = AudioStreamPlayer.new()
		som_select.name = "SomSelect"
		add_child(som_select)

	# --- CanvasUI ---
	var ui: CanvasLayer
	if has_node("CanvasUI"):
		ui = $CanvasUI
	else:
		ui = CanvasLayer.new()
		ui.name = "CanvasUI"
		add_child(ui)

	# --- Vinheta ---
	if ui.has_node("Vinheta"):
		vinheta = ui.get_node("Vinheta")
	else:
		vinheta = TextureRect.new()
		vinheta.name = "Vinheta"
		ui.add_child(vinheta)
	vinheta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vinheta.stretch_mode = TextureRect.STRETCH_SCALE
	vinheta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vinheta.texture = _criar_vinheta()

	# --- Scanlines ---
	_montar_scanlines(ui)

	# --- TextoStart ---
	texto_start = _garantir_label(ui, "TextoStart", texto_start_label)
	texto_start.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	texto_start.offset_top = -180
	texto_start.offset_bottom = -110
	texto_start.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto_start.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto_start.add_theme_font_size_override("font_size", 44)
	texto_start.add_theme_color_override("font_color", Color.WHITE)
	texto_start.add_theme_color_override("font_outline_color", cor_neon)
	texto_start.add_theme_constant_override("outline_size", 10)
	_aplicar_fonte(texto_start)


	# --- Modal de jogadores (oculto até apertar START) ---
	_montar_modal(ui)

	# --- FadeOverlay (criado por ÚLTIMO p/ ficar acima de tudo) ---
	if ui.has_node("FadeOverlay"):
		fade_overlay = ui.get_node("FadeOverlay")
	else:
		fade_overlay = ColorRect.new()
		fade_overlay.name = "FadeOverlay"
		ui.add_child(fade_overlay)
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_overlay.color = Color(0, 0, 0, 1)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE



func _garantir_label(pai: CanvasLayer, nome: String, txt: String) -> Label:
	if pai.has_node(nome):
		return pai.get_node(nome) as Label
	var l := Label.new()
	l.name = nome
	l.text = txt
	pai.add_child(l)
	return l



func _aplicar_fonte(no: Control) -> void:
	if caminho_fonte == "":
		return
	var f := load(caminho_fonte)
	if f is Font:
		no.add_theme_font_override("font", f)



func _criar_vinheta() -> Texture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.45, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.6)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 512
	gt.height = 512
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 1.0)
	return gt



# =====================================================================
# EFEITOS VISUAIS (shaders + vinheta pulsante)
# =====================================================================
func _aplicar_shader_fundo() -> void:
	if not usar_efeitos_shader or fundo == null:
		return
	var sh := Shader.new()
	sh.code = _SHADER_FUNDO
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("pulso_intensidade", intensidade_pulso)
	mat.set_shader_parameter("aberracao", intensidade_aberracao)
	mat.set_shader_parameter("cor_realce", cor_neon)
	fundo.material = mat



func _montar_scanlines(ui: CanvasLayer) -> void:
	if not usar_efeitos_shader:
		return
	if ui.has_node("Scanlines"):
		scanlines = ui.get_node("Scanlines")
	else:
		scanlines = ColorRect.new()
		scanlines.name = "Scanlines"
		ui.add_child(scanlines)
	scanlines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scanlines.color = Color(1, 1, 1, 1)
	scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = _SHADER_SCANLINES
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("intensidade", intensidade_scanlines)
	scanlines.material = mat


func _pulsar_vinheta() -> void:
	if vinheta == null:
		return
	var t := create_tween().set_loops()
	t.tween_property(vinheta, "modulate:a", 0.72, 1.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(vinheta, "modulate:a", 1.0, 1.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)



# =====================================================================
# MODAL NEON VERTICAL — SELEÇÃO DE JOGADORES (1 a 4)
# =====================================================================
func _montar_modal(ui: CanvasLayer) -> void:
	if ui.has_node("ModalJogadores"):
		modal_jogadores = ui.get_node("ModalJogadores")
	else:
		modal_jogadores = Control.new()
		modal_jogadores.name = "ModalJogadores"
		ui.add_child(modal_jogadores)

	modal_jogadores.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_jogadores.visible = false
	modal_jogadores.modulate.a = 0.0
	modal_jogadores.clip_contents = true

	var escuro := ColorRect.new()
	escuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	escuro.color = Color(0.0, 0.0, 0.02, 0.78)
	escuro.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_jogadores.add_child(escuro)

	# Modal menor e mais seguro na tela.
	# Glow arredondado externo do modal.
	modal_glow = Panel.new()
	modal_glow.name = "ModalGlow"
	_ancorar_frac(modal_glow, 0.075, 0.125, 0.925, 0.875)
	modal_glow.offset_left = -10
	modal_glow.offset_top = -10
	modal_glow.offset_right = 10
	modal_glow.offset_bottom = 10
	modal_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal_glow.add_theme_stylebox_override("panel", _estilo_modal_glow())
	modal_jogadores.add_child(modal_glow)

	# Painel central real.
	modal_painel = Panel.new()
	modal_painel.name = "ModalPainel"
	_ancorar_frac(modal_painel, 0.075, 0.125, 0.925, 0.875)
	modal_painel.add_theme_stylebox_override("panel", _estilo_modal())
	modal_painel.clip_contents = true
	modal_jogadores.add_child(modal_painel)

	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margem.add_theme_constant_override("margin_left", 22)
	margem.add_theme_constant_override("margin_right", 22)
	margem.add_theme_constant_override("margin_top", 20)
	margem.add_theme_constant_override("margin_bottom", 20)
	modal_painel.add_child(margem)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	margem.add_child(vbox)

	_lbl_titulo_modal = Label.new()
	_lbl_titulo_modal.text = "QUANTOS JOGADORES?"
	_lbl_titulo_modal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_titulo_modal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_titulo_modal.add_theme_color_override("font_color", Color.WHITE)
	_lbl_titulo_modal.add_theme_color_override("font_outline_color", cor_neon)
	_lbl_titulo_modal.add_theme_constant_override("outline_size", 7)
	_aplicar_fonte(_lbl_titulo_modal)
	vbox.add_child(_lbl_titulo_modal)

	_linha_titulo = Panel.new()
	_linha_titulo.custom_minimum_size = Vector2(0, 4)
	_linha_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_linha_titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb_linha := StyleBoxFlat.new()
	sb_linha.bg_color = cor_neon
	sb_linha.set_corner_radius_all(20)
	sb_linha.shadow_color = Color(cor_neon.r, cor_neon.g, cor_neon.b, 0.7)
	sb_linha.shadow_size = 8
	_linha_titulo.add_theme_stylebox_override("panel", sb_linha)

	var caixa_linha := MarginContainer.new()
	caixa_linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa_linha.add_theme_constant_override("margin_left", 70)
	caixa_linha.add_theme_constant_override("margin_right", 70)
	caixa_linha.add_theme_constant_override("margin_top", 0)
	caixa_linha.add_theme_constant_override("margin_bottom", 4)
	caixa_linha.add_child(_linha_titulo)
	vbox.add_child(caixa_linha)

	_lbl_subtitulo_modal = Label.new()
	_lbl_subtitulo_modal.text = "SELECT PASSA  •  START CONFIRMA"
	_lbl_subtitulo_modal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_subtitulo_modal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_subtitulo_modal.add_theme_color_override("font_color", Color(cor_neon.r, cor_neon.g, cor_neon.b, 0.9))
	_aplicar_fonte(_lbl_subtitulo_modal)
	vbox.add_child(_lbl_subtitulo_modal)

	var espaco := Control.new()
	espaco.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(espaco)

	_lista_cards = VBoxContainer.new()
	_lista_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lista_cards.alignment = BoxContainer.ALIGNMENT_CENTER

	# Espaço real entre os cards.
	# Cada opção continua sendo um card separado e forte.
	_lista_cards.add_theme_constant_override("separation", 38)

	vbox.add_child(_lista_cards)

	_cards_modal.clear()
	_discos_modal.clear()
	_nums_modal.clear()
	_txts_modal.clear()
	_nomes_modal.clear()
	_badges_modal.clear()
	_fundos_cards_modal.clear()

	for n in range(1, 5):
		_lista_cards.add_child(_criar_card_jogador(n))




func _criar_card_jogador(n: int) -> Button:
	var cor_card: Color = CORES_JOGADORES[n - 1]

	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.flat = true
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size = Vector2(0, 96)
	card.clip_contents = false
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	_aplicar_estilo_card_completo(card, cor_card, false)

	card.pressed.connect(_escolher_jogadores.bind(n))

	card.mouse_entered.connect(func() -> void:
		if _modal_aberto and _modal_pronto and not _selecionando:
			_selecao_atual = n - 1
			_atualizar_destaque_selecao()
	)

	# Fundo real do card: LED/glow arredondado.
	var fundo_led := Panel.new()
	fundo_led.name = "FundoLedCard"
	fundo_led.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo_led.offset_left = -4
	fundo_led.offset_top = -4
	fundo_led.offset_right = 4
	fundo_led.offset_bottom = 4
	fundo_led.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo_led.add_theme_stylebox_override("panel", _estilo_card_led(cor_card, false))
	card.add_child(fundo_led)

	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margem.add_theme_constant_override("margin_left", 20)
	margem.add_theme_constant_override("margin_right", 22)
	margem.add_theme_constant_override("margin_top", 10)
	margem.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margem)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	margem.add_child(hbox)

	var disco := Panel.new()
	disco.custom_minimum_size = Vector2(68, 68)
	disco.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disco.add_theme_stylebox_override("panel", _estilo_disco(false, cor_card))
	hbox.add_child(disco)

	var num := Label.new()
	num.text = str(n)
	num.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num.add_theme_color_override("font_color", Color.WHITE)
	num.add_theme_color_override("font_outline_color", cor_card)
	num.add_theme_constant_override("outline_size", 7)
	_aplicar_fonte(num)
	disco.add_child(num)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 5)
	hbox.add_child(col)

	var txt := Label.new()
	txt.text = "1 JOGADOR" if n == 1 else "%d JOGADORES" % n
	txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.add_theme_color_override("font_color", Color.WHITE)
	txt.add_theme_color_override("font_outline_color", Color(cor_card.r * 0.30, cor_card.g * 0.30, cor_card.b * 0.30, 1.0))
	txt.add_theme_constant_override("outline_size", 5)
	_aplicar_fonte(txt)
	col.add_child(txt)

	var badges := HBoxContainer.new()
	badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badges.alignment = BoxContainer.ALIGNMENT_CENTER
	badges.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badges.add_theme_constant_override("separation", 8)

	for i in range(n):
		badges.add_child(_criar_bolinha(CORES_JOGADORES[i]))

	col.add_child(badges)

	var nomes := Label.new()
	nomes.text = _texto_nomes(n)
	nomes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nomes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nomes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nomes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nomes.add_theme_color_override("font_color", Color(cor_card.r, cor_card.g, cor_card.b, 0.96))
	nomes.add_theme_color_override("font_outline_color", Color.BLACK)
	nomes.add_theme_constant_override("outline_size", 2)
	_aplicar_fonte(nomes)
	col.add_child(nomes)

	_cards_modal.append(card)
	_fundos_cards_modal.append(fundo_led)
	_discos_modal.append(disco)
	_nums_modal.append(num)
	_txts_modal.append(txt)
	_nomes_modal.append(nomes)
	_badges_modal.append(badges)

	return card



func _criar_bolinha(cor: Color) -> Panel:
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(20, 20)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(10)
	sb.border_color = Color(1, 1, 1, 0.35)
	sb.set_border_width_all(1)
	sb.shadow_color = Color(cor.r, cor.g, cor.b, 0.8)
	sb.shadow_size = 8
	dot.add_theme_stylebox_override("panel", sb)
	return dot



func _texto_nomes(n: int) -> String:
	var partes: Array = []
	for i in range(n):
		partes.append(NOMES_JOGADORES[i])
	return "  •  ".join(partes)



func _ajustar_modal_responsivo() -> void:
	if _lbl_titulo_modal == null:
		return

	var tela := get_viewport_rect().size

	_lbl_titulo_modal.add_theme_font_size_override("font_size", _fs(0.032))
	_lbl_subtitulo_modal.add_theme_font_size_override("font_size", _fs(0.015))

	var lado := int(clamp(tela.y * 0.064, 54, 78))
	var altura_card := int(clamp(tela.y * 0.094, max(lado + 20, 88), 120))
	var espaco_cards := int(clamp(tela.y * 0.036, 34, 48))
	var bolinha := int(clamp(tela.y * 0.018, 13, 24))
	

	if _lista_cards != null:
		_lista_cards.add_theme_constant_override("separation", espaco_cards)

	for i in range(_cards_modal.size()):
		var card: Button = _cards_modal[i]
		card.custom_minimum_size = Vector2(0, altura_card)

		_nums_modal[i].add_theme_font_size_override("font_size", _fs(0.040))
		_discos_modal[i].custom_minimum_size = Vector2(lado, lado)

		_txts_modal[i].add_theme_font_size_override("font_size", _fs(0.027))
		_nomes_modal[i].add_theme_font_size_override("font_size", _fs(0.0145))

		for dot in _badges_modal[i].get_children():
			if dot is Panel:
				dot.custom_minimum_size = Vector2(bolinha, bolinha)
				var sb: StyleBox = dot.get_theme_stylebox("panel")
				if sb is StyleBoxFlat:
					sb.set_corner_radius_all(int(bolinha * 0.5))
	


func _estilo_modal() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()

	sb.bg_color = Color(0.025, 0.025, 0.050, 0.96)
	sb.border_color = Color(cor_neon.r, cor_neon.g, cor_neon.b, 0.82)
	sb.set_border_width_all(2)

	# Arredondado de verdade no painel interno.
	sb.set_corner_radius_all(48)
	sb.anti_aliasing = true

	return sb



func _estilo_disco(destacado: bool, cor: Color = Color(1.0, 0.55, 0.1)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()

	if destacado:
		sb.bg_color = Color(cor.r * 0.46, cor.g * 0.46, cor.b * 0.46, 0.98)
		sb.border_color = Color.WHITE
		sb.set_border_width_all(4)
		sb.shadow_color = Color(cor.r, cor.g, cor.b, 1.0)
		sb.shadow_size = 32
		sb.shadow_offset = Vector2.ZERO
		sb.set_expand_margin_all(5)
	else:
		sb.bg_color = Color(cor.r * 0.16, cor.g * 0.16, cor.b * 0.16, 0.94)
		sb.border_color = Color(cor.r, cor.g, cor.b, 0.82)
		sb.set_border_width_all(2)
		sb.shadow_color = Color(cor.r, cor.g, cor.b, 0.42)
		sb.shadow_size = 12
		sb.shadow_offset = Vector2.ZERO

	sb.set_corner_radius_all(100)
	sb.anti_aliasing = true

	return sb



func _estilo_modal_glow() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()

	sb.bg_color = Color(cor_neon.r * 0.06, cor_neon.g * 0.06, cor_neon.b * 0.06, 0.28)
	sb.border_color = Color(cor_neon.r, cor_neon.g, cor_neon.b, 0.95)
	sb.set_border_width_all(3)

	# Esse é o brilho LED externo arredondado.
	sb.shadow_color = Color(cor_neon.r, cor_neon.g, cor_neon.b, 0.95)
	sb.shadow_size = 58
	sb.shadow_offset = Vector2.ZERO

	sb.set_corner_radius_all(54)
	sb.set_expand_margin_all(14)
	sb.anti_aliasing = true

	return sb


func _estilo_card_led(cor: Color, destacado: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()

	if destacado:
		# Fundo mais aceso.
		sb.bg_color = Color(
			min(cor.r * 0.36 + 0.04, 1.0),
			min(cor.g * 0.36 + 0.04, 1.0),
			min(cor.b * 0.36 + 0.04, 1.0),
			0.98
		)

		# Borda branca dá o efeito de flash.
		sb.border_color = Color.WHITE
		sb.set_border_width_all(4)

		# Glow forte colorido em volta.
		sb.shadow_color = Color(cor.r, cor.g, cor.b, 1.0)
		sb.shadow_size = 54
		sb.shadow_offset = Vector2.ZERO
		sb.set_expand_margin_all(10)
	else:
		sb.bg_color = Color(cor.r * 0.12, cor.g * 0.12, cor.b * 0.12, 0.90)
		sb.border_color = Color(cor.r, cor.g, cor.b, 0.72)
		sb.set_border_width_all(2)
		sb.shadow_color = Color(cor.r, cor.g, cor.b, 0.34)
		sb.shadow_size = 18
		sb.shadow_offset = Vector2.ZERO
		sb.set_expand_margin_all(4)

	sb.set_corner_radius_all(42)
	sb.anti_aliasing = true

	return sb


func _aplicar_estilo_card_completo(card: Button, cor: Color, destacado: bool) -> void:
	var vazio := StyleBoxEmpty.new()

	card.add_theme_stylebox_override("normal", vazio)
	card.add_theme_stylebox_override("hover", vazio)
	card.add_theme_stylebox_override("pressed", vazio)
	card.add_theme_stylebox_override("hover_pressed", vazio)
	card.add_theme_stylebox_override("disabled", vazio)
	card.add_theme_stylebox_override("focus", vazio)


func _estilo_card(cor: Color, destacado: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()

	if destacado:
		# Card selecionado: cor forte + neon.
		sb.bg_color = Color(cor.r * 0.30, cor.g * 0.30, cor.b * 0.30, 0.98)
		sb.border_color = Color(cor.r, cor.g, cor.b, 1.0)
		sb.set_border_width_all(4)
		sb.shadow_color = Color(cor.r, cor.g, cor.b, 0.92)
		sb.shadow_size = 34
	else:
		# Card normal: ainda tem a cor do player, mas mais controlada.
		sb.bg_color = Color(cor.r * 0.13, cor.g * 0.13, cor.b * 0.13, 0.94)
		sb.border_color = Color(cor.r, cor.g, cor.b, 0.62)
		sb.set_border_width_all(2)
		sb.shadow_color = Color(cor.r, cor.g, cor.b, 0.28)
		sb.shadow_size = 12

	sb.set_corner_radius_all(38)
	sb.anti_aliasing = true
	return sb


func _estilo_card_hover(cor: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()

	# Hover/selecionado forte, estilo LED neon.
	sb.bg_color = Color(
		min(cor.r * 0.42 + 0.04, 1.0),
		min(cor.g * 0.42 + 0.04, 1.0),
		min(cor.b * 0.42 + 0.04, 1.0),
		0.99
	)

	sb.border_color = Color.WHITE
	sb.set_border_width_all(4)
	sb.shadow_color = Color(cor.r, cor.g, cor.b, 1.0)
	sb.shadow_size = 44
	sb.set_corner_radius_all(38)
	sb.anti_aliasing = true

	return sb



func _abrir_modal() -> void:
	if _modal_aberto:
		return

	# Ao abrir o modal:
	# toca selected e trava os LEDs acesos.
	_tocar(som_select)
	_enviar_led_basket("MENU_LOCK")

	_modal_aberto = true
	_modal_pronto = false
	_pulsar_glow_modal()
	modal_jogadores.visible = true
	modal_jogadores.modulate.a = 0.0
	_ajustar_modal_responsivo()

	await get_tree().process_frame

	modal_painel.pivot_offset = modal_painel.size * 0.5
	modal_painel.scale = Vector2(0.92, 0.92)

	var t := create_tween().set_parallel(true)
	t.tween_property(modal_jogadores, "modulate:a", 1.0, 0.22)
	t.tween_property(modal_painel, "scale", Vector2(1.0, 1.0), 0.32)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var atraso_base := 0.14

	for i in range(_cards_modal.size()):
		var card: Button = _cards_modal[i]
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.7, 0.7)
		card.modulate.a = 0.0

		var tc := create_tween().set_parallel(true)
		tc.tween_property(card, "modulate:a", 1.0, 0.22).set_delay(atraso_base + i * 0.08)
		tc.tween_property(card, "scale", Vector2(1.0, 1.0), 0.34).set_delay(atraso_base + i * 0.08)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(atraso_base + _cards_modal.size() * 0.08 + 0.34).timeout

	_selecao_atual = 0
	_atualizar_destaque_selecao()
	_modal_pronto = true

func _pulsar_glow_modal() -> void:
	if modal_glow == null:
		return

	modal_glow.modulate.a = 0.62

	var t := create_tween().set_loops()
	t.tween_property(modal_glow, "modulate:a", 1.0, 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(modal_glow, "modulate:a", 0.58, 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)



# Destaca a opção atual; as demais voltam ao normal (sincronizado).
func _atualizar_destaque_selecao() -> void:
	for i in range(_cards_modal.size()):
		var card: Button = _cards_modal[i]
		var cor: Color = CORES_JOGADORES[i % CORES_JOGADORES.size()]
		var sel := i == _selecao_atual

		_aplicar_estilo_card_completo(card, cor, sel)

		if i < _fundos_cards_modal.size():
			var fundo_led: Panel = _fundos_cards_modal[i]
			fundo_led.add_theme_stylebox_override("panel", _estilo_card_led(cor, sel))
			fundo_led.modulate.a = 1.0 if sel else 0.86

		_discos_modal[i].add_theme_stylebox_override("panel", _estilo_disco(sel, cor))

		_nums_modal[i].add_theme_color_override("font_color", Color.WHITE)
		_nums_modal[i].add_theme_color_override("font_outline_color", cor)
		_nums_modal[i].add_theme_constant_override("outline_size", 8 if sel else 6)

		_txts_modal[i].add_theme_color_override("font_color", Color.WHITE)
		_txts_modal[i].add_theme_color_override("font_outline_color", Color(cor.r * 0.36, cor.g * 0.36, cor.b * 0.36, 1.0))
		_txts_modal[i].add_theme_constant_override("outline_size", 5 if sel else 4)

		_nomes_modal[i].add_theme_color_override(
			"font_color",
			Color(cor.r, cor.g, cor.b, 1.0) if sel else Color(cor.r, cor.g, cor.b, 0.78)
		)

		card.pivot_offset = card.size * 0.5

		var alvo := Vector2(1.025, 1.025) if sel else Vector2.ONE
		var t := create_tween()
		t.tween_property(card, "scale", alvo, 0.14)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	


# SELECT: avança a opção destacada (circular) e toca o som.
func _navegar_selecao() -> void:
	if not _modal_pronto or _selecionando:
		return

	if _select_hold_fechou:
		return

	var agora: int = Time.get_ticks_msec()

	# Antibounce / antirrepetição do botão físico.
	if agora < _select_nav_liberado_ms:
		return

	# Obriga soltar o botão antes de aceitar o próximo SELECT.
	if _select_nav_precisa_soltar:
		return

	_select_nav_precisa_soltar = true
	_select_nav_liberado_ms = agora + intervalo_select_modal_ms

	_selecao_atual = (_selecao_atual + 1) % 4

	_tocar(som_select)

	var jogadores: int = _selecao_atual + 1

	# 1 jogador: trava aceso.
	# 2 jogadores: 1 onda.
	# 3 jogadores: 2 ondas.
	# 4 jogadores: 3 ondas.
	_enviar_led_basket("SELECT%d" % jogadores)

	_atualizar_destaque_selecao()



# START: confirma a opção destacada.
func _confirmar_selecao() -> void:
	if not _modal_pronto or _selecionando:
		return
	_escolher_jogadores(_selecao_atual + 1)



func _acao(evento: InputEvent, nome: String) -> bool:
	return nome != "" and InputMap.has_action(nome) and evento.is_action_pressed(nome)



func _ir_para_config() -> void:
	if _avancando:
		return
	if cena_config == "" or not ResourceLoader.exists(cena_config):
		push_warning("Opening: cena de config não encontrada em " + cena_config)
		return
	_avancando = true
	var t := create_tween()
	if fade_overlay:
		t.tween_property(fade_overlay, "color:a", 1.0, 0.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await t.finished
	_mudando_para_cena = true
	_fechar_ponte_leds_opening(true)
	_encerrar_leds()
	_trocar_cena(cena_config)



func _fechar_modal() -> void:
	if not _modal_aberto:
		return

	_modal_pronto = false
	_select_hold_t = 0.0
	_select_hold_fechou = false

	var t := create_tween()
	t.tween_property(modal_jogadores, "modulate:a", 0.0, 0.2)

	await t.finished

	modal_jogadores.visible = false
	_modal_aberto = false

	# Modal fechado: volta ao estado parado da máquina.
	_enviar_led_basket("ATTRACT")



func _escolher_jogadores(n: int) -> void:
	if _avancando or _selecionando:
		return

	_selecionando = true
	_modal_pronto = false

	n = clampi(n, 1, 4)
	_selecao_atual = n - 1

	_tocar(som_select)
	_enviar_led_basket("STARTING")

	get_tree().set_meta("num_jogadores", n)

	for i in range(_cards_modal.size()):
		var card: Button = _cards_modal[i]
		card.pivot_offset = card.size * 0.5

		var t := create_tween().set_parallel(true)

		if i == n - 1:
			t.tween_property(card, "scale", Vector2(1.025, 1.025), 0.12)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			t.tween_property(card, "modulate:a", 1.0, 0.12)
		else:
			t.tween_property(card, "modulate:a", 0.0, 0.16)
			t.tween_property(card, "scale", Vector2(0.92, 0.92), 0.16)

	await get_tree().create_timer(0.32).timeout

	_avancar()



# =====================================================================
# ASSETS / MÚSICA
# =====================================================================
func _carregar_assets() -> void:
	if fundo:
		var tex := load(CAMINHO_FUNDO) as Texture2D
		if tex:
			fundo.texture = tex
		else:
			push_warning("Opening: imagem não encontrada em " + CAMINHO_FUNDO)

	if musica:
		var stream := load(CAMINHO_MUSICA) as AudioStream
		if stream:
			if stream is AudioStreamMP3:
				stream.loop = true
			elif stream is AudioStreamOggVorbis:
				stream.loop = true
			musica.stream = stream
		else:
			push_warning("Opening: música não encontrada em " + CAMINHO_MUSICA)

	if som_select:
		var ss := load(caminho_som_selected) as AudioStream
		if ss:
			som_select.stream = ss
		else:
			push_warning("Opening: som 'selected' não encontrado em " + caminho_som_selected)



func _tocar(p: AudioStreamPlayer) -> void:
	if p and p.stream:
		p.play()



func _iniciar_musica() -> void:
	if musica == null or musica.stream == null:
		return
	if not musica.finished.is_connected(_on_musica_finished):
		musica.finished.connect(_on_musica_finished)

	var vol_final: float = musica.volume_db
	musica.volume_db = -40.0
	musica.play()
	var t := create_tween()
	t.tween_property(musica, "volume_db", vol_final, 1.2)



func _on_musica_finished() -> void:
	if musica:
		musica.play()



# =====================================================================
# LEDS RGB (D2 e D3) — PONTE POWERSHELL + EFEITOS LARANJA
# =====================================================================
func _iniciar_leds() -> void:
	if not usar_leds:
		return
	# A ponte serial via PowerShell só roda no Windows do gabinete.
	if OS.get_name() != "Windows":
		return

	_led_total = max(1, leds_por_pino) * 2
	_led_cores.resize(_led_total)
	for i in range(_led_total):
		_led_cores[i] = Color.BLACK

	_led_caminho_cmd_abs = ProjectSettings.globalize_path(_led_caminho_cmd)
	_led_caminho_tmp_abs = ProjectSettings.globalize_path(_led_caminho_tmp)

	# Limpa restos de execuções anteriores.
	if FileAccess.file_exists(_led_caminho_cmd):
		DirAccess.remove_absolute(_led_caminho_cmd_abs)
	if FileAccess.file_exists(_led_caminho_tmp):
		DirAccess.remove_absolute(_led_caminho_tmp_abs)

	_montar_bridge_ps()

	var ps_abs := ProjectSettings.globalize_path(_led_caminho_ps)
	var args := [
		"-ExecutionPolicy", "Bypass",
		"-NoProfile",
		"-WindowStyle", "Hidden",
		"-File", ps_abs,
		"-Porta", porta_leds,
		"-Baud", str(baud_leds),
		"-Arquivo", _led_caminho_cmd_abs,
	]
	_led_pid = OS.create_process("powershell.exe", args)
	_led_pronto = _led_pid > 0
	_led_efeito = 0
	_led_efeito_tempo = 0.0
	_led_tempo = 0.0



func _montar_bridge_ps() -> void:
	var f := FileAccess.open(_led_caminho_ps, FileAccess.WRITE)
	if f:
		f.store_string(_PS_BRIDGE)
		f.close()



func _atualizar_leds(delta: float) -> void:
	_led_tempo += delta
	_led_efeito_tempo += delta
	if _led_efeito_tempo >= segundos_por_efeito:
		_led_efeito_tempo = 0.0
		_led_efeito = (_led_efeito + 1) % _LED_NUM_EFEITOS

	_led_acumulado += delta
	var intervalo : float = 1.0 / max(1.0, fps_leds)
	if _led_acumulado < intervalo:
		return
	_led_acumulado = 0.0

	_calcular_efeito(_led_efeito, _led_tempo)
	_enviar_frame_leds()



func _calcular_efeito(efeito: int, t: float) -> void:
	match efeito:
		0:
			_efeito_onda(t)
		1:
			_efeito_dois_em_dois(t)
		2:
			_efeito_cometa(t)
		3:
			_efeito_pulso(t)
		4:
			_efeito_encontro(t)
		_:
			_efeito_faisca(t)



func _cor_brilho(f: float) -> Color:
	f = clamp(f, 0.0, 1.0)
	return Color(cor_leds.r * f, cor_leds.g * f, cor_leds.b * f, 1.0)



func _efeito_onda(t: float) -> void:
	for i in range(_led_total):
		var f := 0.12 + 0.88 * (0.5 + 0.5 * sin(t * 5.5 - float(i) * 0.65))
		_led_cores[i] = _cor_brilho(f)



func _efeito_dois_em_dois(t: float) -> void:
	var ciclo := _led_total + 4
	var passo := int(t / 0.16) * 2
	var acesos := passo % ciclo
	for i in range(_led_total):
		_led_cores[i] = _cor_brilho(1.0 if i < acesos else 0.04)



func _efeito_cometa(t: float) -> void:
	var head := fmod(t * 9.0, float(_led_total))
	for i in range(_led_total):
		var d : float = abs(float(i) - head)
		d = min(d, float(_led_total) - d)   # cauda dá a volta
		var f : float = clamp(1.0 - d / 3.5, 0.0, 1.0)
		f = pow(f, 1.6)
		_led_cores[i] = _cor_brilho(max(0.03, f))



func _efeito_pulso(t: float) -> void:
	var g := 0.10 + 0.90 * (0.5 + 0.5 * sin(t * 3.0))
	for i in range(_led_total):
		_led_cores[i] = _cor_brilho(g)



func _efeito_encontro(t: float) -> void:
	var prog := fmod(t * 1.0, 2.0)            # 0..1 enche, 1..2 esvazia
	var nivel := prog if prog < 1.0 else (2.0 - prog)
	var alcance := nivel * (float(_led_total) * 0.5 + 1.0)
	for i in range(_led_total):
		var de := float(min(i, _led_total - 1 - i))   # distância da borda mais próxima
		_led_cores[i] = _cor_brilho(1.0 if de < alcance else 0.05)



func _efeito_faisca(t: float) -> void:
	var passo_tempo : float = floor(t * 7.0)
	for i in range(_led_total):
		var h := sin(float(i) * 12.9898 + passo_tempo * 78.233) * 43758.5453
		h = h - floor(h)
		var f := 0.06
		if h > 0.80:
			f = 1.0
		elif h > 0.62:
			f = 0.45
		_led_cores[i] = _cor_brilho(f)



func _enviar_frame_leds() -> void:
	var n := leds_por_pino
	var p2 := PackedStringArray()
	var p3 := PackedStringArray()
	for i in range(n):
		var c2: Color = _led_cores[i]
		p2.append("%d,%d,%d" % [int(c2.r * 255.0), int(c2.g * 255.0), int(c2.b * 255.0)])
	for i in range(n):
		var c3: Color = _led_cores[n + i]
		p3.append("%d,%d,%d" % [int(c3.r * 255.0), int(c3.g * 255.0), int(c3.b * 255.0)])
	var cmd := "SET;2=%s;3=%s\n" % [",".join(p2), ",".join(p3)]
	_enviar_comando_leds(cmd)



func _enviar_comando_leds(cmd: String) -> void:
	if not _led_pronto:
		return
	# Se o .cmd ainda existe, a ponte não consumiu o quadro anterior:
	# dropa este quadro (throttle natural, sem acumular arquivos).
	if FileAccess.file_exists(_led_caminho_cmd):
		return
	var f := FileAccess.open(_led_caminho_tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(cmd)
	f.close()
	DirAccess.rename_absolute(_led_caminho_tmp_abs, _led_caminho_cmd_abs)



func _desligar_leds() -> void:
	if not _led_pronto:
		return
	var n := leds_por_pino
	var zeros := PackedStringArray()
	for i in range(n):
		zeros.append("0,0,0")
	var s := ",".join(zeros)
	var cmd := "SET;2=%s;3=%s\n" % [s, s]
	# Tenta enviar o "apagar" mesmo que a ponte esteja ocupada.
	for tentativa in range(10):
		if not FileAccess.file_exists(_led_caminho_cmd):
			var f := FileAccess.open(_led_caminho_tmp, FileAccess.WRITE)
			if f:
				f.store_string(cmd)
				f.close()
				DirAccess.rename_absolute(_led_caminho_tmp_abs, _led_caminho_cmd_abs)
			return
		OS.delay_msec(6)



func _encerrar_leds() -> void:
	if not _led_pronto:
		return
	_desligar_leds()
	OS.delay_msec(40)
	if _led_pid > 0:
		OS.kill(_led_pid)
		_led_pid = -1
	_led_pronto = false



# =====================================================================
# PARTÍCULAS (intensas: brilham branco e viram neon)
# =====================================================================
func _configurar_particulas() -> void:
	if particulas == null:
		return
	var tela: Vector2 = get_viewport_rect().size
	particulas.position = Vector2(tela.x * 0.5, tela.y)
	particulas.amount = 140
	particulas.lifetime = 7.0
	particulas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particulas.emission_rect_extents = Vector2(tela.x * 0.5, 6.0)
	particulas.direction = Vector2(0, -1)
	particulas.spread = 35.0
	particulas.gravity = Vector2.ZERO
	particulas.initial_velocity_min = 30.0
	particulas.initial_velocity_max = 110.0
	particulas.angular_velocity_min = -40.0
	particulas.angular_velocity_max = 40.0
	particulas.scale_amount_min = 1.5
	particulas.scale_amount_max = 5.0

	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	grad.colors = PackedColorArray([
		Color(cor_neon.r, cor_neon.g, cor_neon.b, 0.0),
		Color(1, 1, 1, 0.95),
		Color(cor_neon.r, cor_neon.g, cor_neon.b, 0.75),
		Color(cor_neon.r, cor_neon.g, cor_neon.b, 0.0),
	])
	particulas.color_ramp = grad
	particulas.emitting = true



# =====================================================================
# ANIMAÇÕES (sem movimento no fundo)
# =====================================================================
func _animar_entrada() -> void:
	if fade_overlay == null:
		return
	var t := create_tween()
	t.tween_property(fade_overlay, "color:a", 0.0, 1.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)



func _animar_texto_start() -> void:
	if texto_start == null:
		return
	texto_start.pivot_offset = texto_start.size * 0.5

	var t_alpha := create_tween().set_loops()
	t_alpha.tween_property(texto_start, "modulate:a", 0.2, 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t_alpha.tween_property(texto_start, "modulate:a", 1.0, 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var t_escala := create_tween().set_loops()
	t_escala.tween_property(texto_start, "scale", Vector2(1.06, 1.06), 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t_escala.tween_property(texto_start, "scale", Vector2(1.0, 1.0), 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)



# =====================================================================
# ENTRADA
# =====================================================================
func _unhandled_input(evento: InputEvent) -> void:
	if _avancando:
		return

	# F10 sempre disponível: vai para a tela de configuração.
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode == KEY_F10:
		_ir_para_config()
		return

	# Modal aberto: SELECT curto passa, START seleciona.
	# Para fechar o modal: segure SELECT.
	if _modal_aberto:
		if not _modal_pronto:
			return

		if _acao(evento, acao_select):
			_navegar_selecao()
		elif _acao(evento, acao_start_modal):
			_confirmar_selecao()

		return

	# Modal fechado: START abre o modal.
	if permitir_avancar and _acao(evento, acao_start_modal):
		_abrir_modal()



func _avancar() -> void:
	if _avancando:
		return

	_avancando = true

	var t := create_tween().set_parallel(true)

	if fade_overlay:
		t.tween_property(fade_overlay, "color:a", 1.0, 0.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	if musica and musica.playing:
		t.tween_property(musica, "volume_db", -40.0, 0.6)

	await t.finished

	# Efeito de transição antes de entrar no jogo.
	_enviar_led_basket("STARTING")
	OS.delay_msec(160)

	# Fecha a ponte da Opening. O Play vai abrir a ponte dele.
	_mudando_para_cena = true
	_fechar_ponte_leds_opening(false)

	if proxima_cena != "":
		_trocar_cena(proxima_cena)
	else:
		push_warning("Opening: defina 'proxima_cena' no Inspetor.")
	
	


func _enviar_led_basket(cmd: String) -> void:
	if not usar_leds_arduino:
		return

	var f := FileAccess.open(caminho_fila_leds_basket, FileAccess.WRITE)
	if f == null:
		push_warning("Opening LEDs: não consegui escrever comando " + cmd)
		return

	var linha := "%s:%d" % [cmd, Time.get_ticks_msec()]
	f.store_line(linha)
	f.close()

	print("LED OPENING CMD -> ", linha)



func _iniciar_ponte_leds_opening() -> void:
	if not usar_leds_arduino:
		return

	if OS.get_name() != "Windows":
		return

	if _ponte_opening_pid > 0:
		return

	var cmd_abs := ProjectSettings.globalize_path(caminho_fila_leds_basket)

	# Limpa comando velho.
	if FileAccess.file_exists(caminho_fila_leds_basket):
		DirAccess.remove_absolute(cmd_abs)

	var f := FileAccess.open(_ponte_opening_ps, FileAccess.WRITE)
	if f:
		f.store_string(_PS_BRIDGE_OPENING_CMD)
		f.close()

	var ps_abs := ProjectSettings.globalize_path(_ponte_opening_ps)

	var args := [
		"-ExecutionPolicy", "Bypass",
		"-NoProfile",
		"-WindowStyle", "Hidden",
		"-File", ps_abs,
		"-Porta", porta_leds,
		"-Baud", str(baud_leds),
		"-Arquivo", cmd_abs
	]

	_ponte_opening_pid = OS.create_process("powershell.exe", args)

	# Dá tempo da COM5 abrir antes do primeiro comando.
	OS.delay_msec(180)



func _fechar_ponte_leds_opening(apagar: bool = false) -> void:
	if apagar:
		_enviar_led_basket("OFF")
		OS.delay_msec(120)

	if _ponte_opening_pid > 0:
		OS.kill(_ponte_opening_pid)
		_ponte_opening_pid = -1



func _atualizar_hold_select_modal(delta: float) -> void:
	if not _modal_aberto:
		_select_hold_t = 0.0
		_select_hold_fechou = false
		return

	if not _modal_pronto:
		_select_hold_t = 0.0
		_select_hold_fechou = false
		return

	if _selecionando or _avancando:
		_select_hold_t = 0.0
		_select_hold_fechou = false
		return

	if acao_select == "" or not InputMap.has_action(acao_select):
		return

	if Input.is_action_pressed(acao_select):
		_select_hold_t += delta

		if _select_hold_t >= segundos_segurar_select_fechar_modal and not _select_hold_fechou:
			_select_hold_fechou = true
			_fechar_modal_por_select_hold()
	else:
		_select_hold_t = 0.0
		_select_hold_fechou = false



func _fechar_modal_por_select_hold() -> void:
	if not _modal_aberto:
		return

	_tocar(som_select)
	_enviar_led_basket("ATTRACT")

	await _fechar_modal()



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
