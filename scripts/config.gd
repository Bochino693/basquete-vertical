extends Control

# =====================================================================
# CONFIG BASKET
# Salva configuração do jogo em:
#   user://basket_config.cfg
#
# Configura:
# - Tempo da partida
# - Modo LIVRE ou CRÉDITO
# - RESETAR RECORD (zera o all-time high)
#
# INPUTS:
# - START / ENTER: confirma/executa a opção destacada
# - SELECT: passa para a próxima opção
# - Esquerda/Direita: -10s / +10s   •   Cima/Baixo: +60s / -60s
# - ESC: voltar sem salvar
#
# O MOUSE DO SISTEMA FICA SEMPRE OCULTO — é desenhado um cursor neon.
# =====================================================================

@export_file("*.tscn") var cena_voltar: String = "res://scenes/opening.tscn"
@export var caminho_config_basket: String = "user://basket_config.cfg"

# >>> IMPORTANTE: confirme que este caminho/chaves batem com o que o
#     play.tscn realmente grava o all-time high. Se o play salvar em
#     outro arquivo (ou dentro do próprio basket_config.cfg), ajuste
#     'caminho_record' e a função _resetar_record() conforme necessário.
@export var caminho_record: String = "user://basket_record.cfg"

@export var tempo_minimo: int = 10
@export var tempo_maximo: int = 600
@export var passo_tempo: int = 10
@export var passo_tempo_grande: int = 60

@export var cor_neon: Color = Color(1.0, 0.55, 0.10, 1.0)
@export var cor_credito: Color = Color(1.0, 0.18, 0.12, 1.0)
@export var cor_livre: Color = Color(0.24, 1.0, 0.48, 1.0)
@export var cor_reset: Color = Color(1.0, 0.45, 0.06, 1.0)

@export var caminho_fonte: String = "res://fonts/titan.ttf"
@export var caminho_fundo: String = "res://images/basket_back.png"

# ---------- CURSOR NEON (desenhado em código) ----------
var cursor_layer: CanvasLayer = null
var cursor_neon: CursorNeon = null

var tempo_partida: int = 60
var modo_credito: bool = false

var fundo: TextureRect = null
var escurecer: ColorRect = null
var painel: Panel = null

var titulo: Label = null
var tempo_titulo: Label = null
var tempo_valor: Label = null
var modo_titulo: Label = null
var modo_valor: Label = null
var ajuda: Label = null
var status: Label = null

var btn_menos_10: Button = null
var btn_mais_10: Button = null
var btn_menos_60: Button = null
var btn_mais_60: Button = null
var btn_modo: Button = null
var btn_reset_record: Button = null
var btn_salvar: Button = null
var btn_voltar: Button = null

var _opcoes_botoes: Array[Button] = []
var _opcoes_acoes: Array[String] = []
var _opcoes_cores: Array[Color] = []
var _opcao_atual: int = 0

var _salvando: bool = false

# ---------- OVERLAY DE CONFIRMAÇÃO DO RESET ----------
var overlay_reset: Control = null
var painel_reset: Panel = null
var lbl_reset_titulo: Label = null
var lbl_reset_texto: Label = null
var lbl_reset_dica: Label = null
var _confirmando_reset: bool = false



var orientacao_paisagem: bool = false        # false = RETRATO, true = PAISAGEM
var btn_orientacao: Button = null
var cor_orientacao: Color = Color(0.22, 0.66, 1.0, 1.0)



func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	_carregar_config()
	_montar_tela()
	_montar_overlay_reset()
	_criar_cursor_custom()
	_registrar_botoes_navegacao()
	_atualizar_textos()

	await get_tree().process_frame
	_ajustar_layout()
	_atualizar_botoes_hover()

	if not get_viewport().size_changed.is_connected(_on_viewport_size_changed):
		get_viewport().size_changed.connect(_on_viewport_size_changed)



func _on_viewport_size_changed() -> void:
	call_deferred("_ajustar_layout")



func _process(_delta: float) -> void:
	if cursor_neon == null:
		return
	var mp := get_viewport().get_mouse_position()
	cursor_neon.position = mp
	cursor_neon.definir_hover(_mouse_sobre_botao(mp))



func _mouse_sobre_botao(pos_mouse: Vector2) -> bool:
	for b in _opcoes_botoes:
		if b != null and b.visible and b.get_global_rect().has_point(pos_mouse):
			return true
	return false



# =====================================================================
# CONFIG (load / save)
# =====================================================================
func _carregar_config() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(caminho_config_basket)

	if err == OK:
		tempo_partida = int(cfg.get_value("jogo", "tempo_partida", 60))
		modo_credito = bool(cfg.get_value("jogo", "modo_credito", false))

		var modo_txt: String = str(cfg.get_value("jogo", "modo_operacao", "livre")).to_lower()
		if modo_txt == "credito" or modo_txt == "crédito":
			modo_credito = true

		var orient_txt: String = str(cfg.get_value("video", "orientacao", "retrato")).to_lower()
		orientacao_paisagem = (orient_txt == "paisagem" or orient_txt == "horizontal" or orient_txt == "deitado")
	else:
		tempo_partida = 60
		modo_credito = false
		orientacao_paisagem = false

	tempo_partida = clampi(tempo_partida, tempo_minimo, tempo_maximo)




func _salvar_config() -> void:
	if _salvando:
		return

	_salvando = true

	var cfg := ConfigFile.new()
	# Recarrega o que já existe para não apagar o record gravado no mesmo arquivo.
	cfg.load(caminho_config_basket)

	cfg.set_value("jogo", "tempo_partida", float(tempo_partida))
	cfg.set_value("jogo", "modo_credito", modo_credito)
	cfg.set_value("jogo", "modo_operacao", "credito" if modo_credito else "livre")

	cfg.set_value("video", "orientacao", "paisagem" if orientacao_paisagem else "retrato")

	var err: int = cfg.save(caminho_config_basket)

	if err == OK:
		# Reflete a orientação imediatamente, se a Tela (autoload) existir.
		var tela_node := get_node_or_null("/root/Tela")
		if tela_node != null and tela_node.has_method("aplicar_orientacao_do_config"):
			tela_node.aplicar_orientacao_do_config()

		_mostrar_status("CONFIGURAÇÃO SALVA!", Color(0.45, 1.0, 0.55, 1.0))
		await get_tree().create_timer(0.55).timeout
		_voltar()
	else:
		_mostrar_status("ERRO AO SALVAR CONFIGURAÇÃO", Color(1.0, 0.22, 0.18, 1.0))

	_salvando = false



func _mostrar_status(txt: String, cor: Color) -> void:
	if status == null:
		return
	status.text = txt
	status.add_theme_color_override("font_color", cor)



# =====================================================================
# RESET RECORD
# =====================================================================
func _pedir_confirmacao_reset() -> void:
	if _confirmando_reset or _salvando:
		return
	_confirmando_reset = true
	overlay_reset.visible = true
	overlay_reset.modulate.a = 0.0
	painel_reset.pivot_offset = painel_reset.size * 0.5
	painel_reset.scale = Vector2(0.9, 0.9)

	var t := create_tween().set_parallel(true)
	t.tween_property(overlay_reset, "modulate:a", 1.0, 0.18)
	t.tween_property(painel_reset, "scale", Vector2.ONE, 0.26)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)



func _cancelar_reset() -> void:
	if not _confirmando_reset:
		return
	var t := create_tween()
	t.tween_property(overlay_reset, "modulate:a", 0.0, 0.16)
	await t.finished
	overlay_reset.visible = false
	_confirmando_reset = false



func _resetar_record() -> void:
	# 1) Reescreve o arquivo de record ZERADO (cobrindo nomes de chave comuns).
	var rec := ConfigFile.new()
	rec.set_value("record", "valor", 0)
	rec.set_value("record", "recorde", 0)
	rec.set_value("record", "high", 0)
	rec.set_value("recorde", "valor", 0)
	rec.set_value("high", "valor", 0)
	rec.save(caminho_record)

	# 2) Por segurança, zera também possíveis chaves de record dentro do
	#    próprio basket_config.cfg (caso o play grave ali).
	var cfg := ConfigFile.new()
	cfg.load(caminho_config_basket)
	cfg.set_value("record", "valor", 0)
	cfg.set_value("record", "recorde", 0)
	cfg.set_value("jogo", "record", 0)
	cfg.set_value("jogo", "recorde", 0)
	cfg.set_value("jogo", "all_time_high", 0)
	cfg.save(caminho_config_basket)

	# 3) Fecha overlay e dá feedback.
	var t := create_tween()
	t.tween_property(overlay_reset, "modulate:a", 0.0, 0.16)
	await t.finished
	overlay_reset.visible = false
	_confirmando_reset = false

	_mostrar_status("RECORD ZERADO!", Color(1.0, 0.62, 0.20, 1.0))
	_pulse(status)



# =====================================================================
# TELA
# =====================================================================
func _montar_tela() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	fundo = TextureRect.new()
	fundo.name = "Fundo"
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)

	if caminho_fundo != "" and ResourceLoader.exists(caminho_fundo):
		fundo.texture = load(caminho_fundo)

	escurecer = ColorRect.new()
	escurecer.name = "Escurecer"
	escurecer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	escurecer.color = Color(0.0, 0.0, 0.0, 0.72)
	escurecer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(escurecer)

	painel = Panel.new()
	painel.name = "PainelConfig"
	painel.clip_contents = true
	painel.add_theme_stylebox_override("panel", _estilo_painel(cor_neon))
	add_child(painel)

	titulo = _criar_label("CONFIGURAÇÃO", 58, Color.WHITE, cor_neon, 9)
	painel.add_child(titulo)

	tempo_titulo = _criar_label("TEMPO DA PARTIDA", 28, Color(1.0, 0.88, 0.55, 1.0), Color.BLACK, 5)
	painel.add_child(tempo_titulo)

	tempo_valor = _criar_label("01:00", 82, Color.WHITE, cor_neon, 10)
	painel.add_child(tempo_valor)

	modo_titulo = _criar_label("MODO DE OPERAÇÃO", 28, Color(1.0, 0.88, 0.55, 1.0), Color.BLACK, 5)
	painel.add_child(modo_titulo)

	modo_valor = _criar_label("LIVRE", 64, cor_livre, Color.BLACK, 9)
	painel.add_child(modo_valor)

	btn_menos_60 = _criar_botao("-60s", cor_neon)
	btn_menos_10 = _criar_botao("-10s", cor_neon)
	btn_mais_10 = _criar_botao("+10s", cor_neon)
	btn_mais_60 = _criar_botao("+60s", cor_neon)

	painel.add_child(btn_menos_60)
	painel.add_child(btn_menos_10)
	painel.add_child(btn_mais_10)
	painel.add_child(btn_mais_60)

	btn_modo = _criar_botao("ALTERAR MODO", cor_livre)
	painel.add_child(btn_modo)

	btn_reset_record = _criar_botao("RESETAR RECORD", cor_reset)
	painel.add_child(btn_reset_record)

	btn_orientacao = _criar_botao("TELA: RETRATO", cor_orientacao)
	painel.add_child(btn_orientacao)

	btn_salvar = _criar_botao("SALVAR", Color(0.30, 1.0, 0.48, 1.0))
	painel.add_child(btn_salvar)

	btn_voltar = _criar_botao("VOLTAR", Color(1.0, 0.22, 0.18, 1.0))
	painel.add_child(btn_voltar)

	ajuda = _criar_label(
		"START/ENTER CONFIRMA  •  SELECT PASSA\nSETAS ALTERAM O TEMPO",
		22,
		Color(0.86, 0.92, 1.0, 1.0),
		Color.BLACK,
		4
	)
	painel.add_child(ajuda)

	status = _criar_label("", 26, Color.WHITE, Color.BLACK, 5)
	painel.add_child(status)

	btn_menos_60.pressed.connect(_alterar_tempo.bind(-passo_tempo_grande))
	btn_menos_10.pressed.connect(_alterar_tempo.bind(-passo_tempo))
	btn_mais_10.pressed.connect(_alterar_tempo.bind(passo_tempo))
	btn_mais_60.pressed.connect(_alterar_tempo.bind(passo_tempo_grande))

	btn_modo.pressed.connect(_alternar_modo)
	btn_reset_record.pressed.connect(_pedir_confirmacao_reset)
	btn_orientacao.pressed.connect(_alternar_orientacao)
	btn_salvar.pressed.connect(_salvar_config)
	btn_voltar.pressed.connect(_voltar)



func _montar_overlay_reset() -> void:
	overlay_reset = Control.new()
	overlay_reset.name = "OverlayReset"
	overlay_reset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_reset.visible = false
	overlay_reset.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay_reset)

	var escuro := ColorRect.new()
	escuro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	escuro.color = Color(0.0, 0.0, 0.0, 0.82)
	escuro.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_reset.add_child(escuro)

	painel_reset = Panel.new()
	painel_reset.clip_contents = true
	painel_reset.add_theme_stylebox_override("panel", _estilo_painel(cor_reset))
	overlay_reset.add_child(painel_reset)

	lbl_reset_titulo = _criar_label("RESETAR RECORD?", 46, Color.WHITE, cor_reset, 8)
	painel_reset.add_child(lbl_reset_titulo)

	lbl_reset_texto = _criar_label(
		"Isto vai APAGAR o recorde\ne voltar para ZERO.",
		28, Color(1.0, 0.92, 0.82, 1.0), Color.BLACK, 5
	)
	painel_reset.add_child(lbl_reset_texto)

	lbl_reset_dica = _criar_label(
		"START / ENTER  CONFIRMA\nSELECT / ESC  CANCELA",
		26, cor_reset, Color.BLACK, 5
	)
	painel_reset.add_child(lbl_reset_dica)



func _criar_label(texto: String, tamanho: int, cor: Color, outline: Color, outline_size: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", outline)
	l.add_theme_constant_override("outline_size", outline_size)

	if caminho_fonte != "" and ResourceLoader.exists(caminho_fonte):
		var f := load(caminho_fonte)
		if f is Font:
			l.add_theme_font_override("font", f)

	return l



func _criar_botao(texto: String, cor: Color) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.disabled = false

	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.BLACK)
	b.add_theme_color_override("font_outline_color", Color.BLACK)
	b.add_theme_constant_override("outline_size", 4)

	if caminho_fonte != "" and ResourceLoader.exists(caminho_fonte):
		var f := load(caminho_fonte)
		if f is Font:
			b.add_theme_font_override("font", f)

	b.add_theme_stylebox_override("normal", _estilo_botao(cor, 0))
	b.add_theme_stylebox_override("hover", _estilo_botao(cor, 1))
	b.add_theme_stylebox_override("pressed", _estilo_botao(cor, 2))
	b.add_theme_stylebox_override("focus", _estilo_botao(cor, 1))

	return b



func _estilo_painel(cor: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.030, 0.045, 0.98)
	sb.border_color = cor
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(38)
	sb.set_content_margin_all(26)
	sb.shadow_color = Color(cor.r, cor.g, cor.b, 0.62)
	sb.shadow_size = 46
	sb.shadow_offset = Vector2.ZERO
	return sb



func _estilo_botao(cor: Color, estado: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()

	if estado == 0:
		sb.bg_color = Color(0.055, 0.050, 0.070, 0.98)
		sb.shadow_size = 12
	elif estado == 1:
		sb.bg_color = Color(cor.r * 0.28, cor.g * 0.28, cor.b * 0.28, 0.98)
		sb.shadow_size = 28
	else:
		sb.bg_color = Color(cor.r, cor.g, cor.b, 0.96)
		sb.shadow_size = 32

	sb.border_color = cor
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	sb.shadow_color = Color(cor.r, cor.g, cor.b, 0.68)
	sb.shadow_offset = Vector2.ZERO
	return sb



func _ajustar_layout() -> void:
	var tela: Vector2 = get_viewport_rect().size

	if fundo != null:
		fundo.position = Vector2.ZERO
		fundo.size = tela

	if escurecer != null:
		escurecer.position = Vector2.ZERO
		escurecer.size = tela

	var painel_w: float = min(920.0, tela.x - 80.0)
	var painel_h: float = min(1040.0, tela.y - 80.0)

	if painel != null:
		painel.position = Vector2(
			(tela.x - painel_w) * 0.5,
			(tela.y - painel_h) * 0.5
		).round()
		painel.size = Vector2(painel_w, painel_h)

	if titulo != null:
		titulo.position = Vector2(30.0, 24.0)
		titulo.size = Vector2(painel_w - 60.0, 74.0)

	if tempo_titulo != null:
		tempo_titulo.position = Vector2(40.0, 116.0)
		tempo_titulo.size = Vector2(painel_w - 80.0, 42.0)

	if tempo_valor != null:
		tempo_valor.position = Vector2(40.0, 160.0)
		tempo_valor.size = Vector2(painel_w - 80.0, 104.0)

	var btn_w: float = (painel_w - 120.0) / 4.0
	var btn_h: float = 72.0
	var btn_y: float = 284.0

	var botoes_tempo := [btn_menos_60, btn_menos_10, btn_mais_10, btn_mais_60]
	for i in range(botoes_tempo.size()):
		var b: Button = botoes_tempo[i]
		if b == null:
			continue
		b.position = Vector2(42.0 + float(i) * (btn_w + 12.0), btn_y)
		b.size = Vector2(btn_w, btn_h)

	if modo_titulo != null:
		modo_titulo.position = Vector2(40.0, 384.0)
		modo_titulo.size = Vector2(painel_w - 80.0, 42.0)

	if modo_valor != null:
		modo_valor.position = Vector2(40.0, 430.0)
		modo_valor.size = Vector2(painel_w - 80.0, 78.0)

	if btn_modo != null:
		btn_modo.position = Vector2(90.0, 516.0)
		btn_modo.size = Vector2(painel_w - 180.0, 62.0)

	if btn_reset_record != null:
		btn_reset_record.position = Vector2(90.0, 586.0)
		btn_reset_record.size = Vector2(painel_w - 180.0, 62.0)

	if btn_orientacao != null:
		btn_orientacao.position = Vector2(90.0, 656.0)
		btn_orientacao.size = Vector2(painel_w - 180.0, 62.0)

	if status != null:
		status.position = Vector2(40.0, painel_h - 318.0)
		status.size = Vector2(painel_w - 80.0, 44.0)

	if btn_salvar != null:
		btn_salvar.position = Vector2(90.0, painel_h - 272.0)
		btn_salvar.size = Vector2(painel_w - 180.0, 72.0)

	if btn_voltar != null:
		btn_voltar.position = Vector2(90.0, painel_h - 188.0)
		btn_voltar.size = Vector2(painel_w - 180.0, 64.0)

	if ajuda != null:
		ajuda.position = Vector2(40.0, painel_h - 100.0)
		ajuda.size = Vector2(painel_w - 80.0, 70.0)

	_ajustar_layout_overlay(tela)



func _ajustar_layout_overlay(tela: Vector2) -> void:
	if painel_reset == null:
		return
	var w: float = min(760.0, tela.x - 100.0)
	var h: float = min(520.0, tela.y - 160.0)
	painel_reset.position = Vector2((tela.x - w) * 0.5, (tela.y - h) * 0.5).round()
	painel_reset.size = Vector2(w, h)

	if lbl_reset_titulo != null:
		lbl_reset_titulo.position = Vector2(30.0, 56.0)
		lbl_reset_titulo.size = Vector2(w - 60.0, 70.0)
	if lbl_reset_texto != null:
		lbl_reset_texto.position = Vector2(30.0, 168.0)
		lbl_reset_texto.size = Vector2(w - 60.0, 110.0)
	if lbl_reset_dica != null:
		lbl_reset_dica.position = Vector2(30.0, h - 150.0)
		lbl_reset_dica.size = Vector2(w - 60.0, 96.0)



# =====================================================================
# AÇÕES
# =====================================================================
func _alterar_tempo(valor: int) -> void:
	tempo_partida = clampi(tempo_partida + valor, tempo_minimo, tempo_maximo)
	_atualizar_textos()
	_pulse(tempo_valor)



func _alternar_modo() -> void:
	modo_credito = not modo_credito
	_atualizar_textos()
	_pulse(modo_valor)



func _alternar_orientacao() -> void:
	orientacao_paisagem = not orientacao_paisagem
	_atualizar_textos()
	_pulse(btn_orientacao)



func _atualizar_textos() -> void:
	var minutos: int = tempo_partida / 60
	var segundos: int = tempo_partida % 60

	if tempo_valor != null:
		tempo_valor.text = "%02d:%02d" % [minutos, segundos]

	if modo_valor != null:
		if modo_credito:
			modo_valor.text = "CRÉDITO"
			modo_valor.add_theme_color_override("font_color", cor_credito)
		else:
			modo_valor.text = "LIVRE"
			modo_valor.add_theme_color_override("font_color", cor_livre)

	if btn_modo != null:
		btn_modo.text = "MUDAR PARA LIVRE" if modo_credito else "MUDAR PARA CRÉDITO"

	if btn_orientacao != null:
		btn_orientacao.text = "TELA: PAISAGEM" if orientacao_paisagem else "TELA: RETRATO"

	if status != null:
		status.text = ""

	_atualizar_botoes_hover()



func _pulse(no: Control) -> void:
	if no == null:
		return
	no.pivot_offset = no.size * 0.5
	var tw := create_tween()
	tw.tween_property(no, "scale", Vector2(1.08, 1.08), 0.08)
	tw.tween_property(no, "scale", Vector2.ONE, 0.14)



func _voltar() -> void:
	var alvo := cena_voltar if cena_voltar != "" else "res://scenes/opening.tscn"
	_trocar_cena(alvo)


# =====================================================================
# INPUT
# =====================================================================
func _unhandled_input(evento: InputEvent) -> void:
	# Enquanto o overlay de reset está aberto, ele captura tudo.
	if _confirmando_reset:
		if evento.is_action_pressed("input_start"):
			_resetar_record()
			_input_handled_seguro()
			return
		if evento.is_action_pressed("input_select"):
			_cancelar_reset()
			_input_handled_seguro()
			return
		if evento is InputEventKey and evento.pressed and not evento.echo:
			match (evento as InputEventKey).keycode:
				KEY_ENTER:
					_resetar_record()
					_input_handled_seguro()
				KEY_ESCAPE:
					_cancelar_reset()
					_input_handled_seguro()
		return

	if _salvando:
		return

	if evento.is_action_pressed("input_select"):
		_navegar_opcao(1)
		_input_handled_seguro()
		return

	if evento.is_action_pressed("input_start"):
		_executar_opcao_atual()
		_input_handled_seguro()
		return

	if evento is InputEventKey:
		var k := evento as InputEventKey
		if not k.pressed or k.echo:
			return

		match k.keycode:
			KEY_ENTER:
				_executar_opcao_atual()
				_input_handled_seguro()
				return
			KEY_ESCAPE:
				_voltar()
				_input_handled_seguro()
				return
			KEY_RIGHT, KEY_DOWN:
				_navegar_opcao(1)
				_input_handled_seguro()
				return
			KEY_LEFT, KEY_UP:
				_navegar_opcao(-1)
				_input_handled_seguro()
				return



func _registrar_botoes_navegacao() -> void:
	_opcoes_botoes.clear()
	_opcoes_acoes.clear()
	_opcoes_cores.clear()

	_adicionar_opcao(btn_menos_60, "menos_60", cor_neon)
	_adicionar_opcao(btn_menos_10, "menos_10", cor_neon)
	_adicionar_opcao(btn_mais_10, "mais_10", cor_neon)
	_adicionar_opcao(btn_mais_60, "mais_60", cor_neon)
	_adicionar_opcao(btn_modo, "modo", cor_livre)
	_adicionar_opcao(btn_reset_record, "reset_record", cor_reset)
	_adicionar_opcao(btn_orientacao, "orientacao", cor_orientacao)
	_adicionar_opcao(btn_salvar, "salvar", Color(0.30, 1.0, 0.48, 1.0))
	_adicionar_opcao(btn_voltar, "voltar", Color(1.0, 0.22, 0.18, 1.0))

	_opcao_atual = clampi(_opcao_atual, 0, max(_opcoes_botoes.size() - 1, 0))
	_atualizar_botoes_hover()



func _adicionar_opcao(btn: Button, acao: String, cor: Color) -> void:
	if btn == null:
		return

	_opcoes_botoes.append(btn)
	_opcoes_acoes.append(acao)
	_opcoes_cores.append(cor)

	var index: int = _opcoes_botoes.size() - 1
	if not btn.mouse_entered.is_connected(_selecionar_opcao_mouse.bind(index)):
		btn.mouse_entered.connect(_selecionar_opcao_mouse.bind(index))



func _selecionar_opcao_mouse(index: int) -> void:
	if _salvando or _confirmando_reset:
		return
	_opcao_atual = clampi(index, 0, _opcoes_botoes.size() - 1)
	_atualizar_botoes_hover()



func _navegar_opcao(direcao: int) -> void:
	if _opcoes_botoes.is_empty():
		return

	_opcao_atual += direcao
	if _opcao_atual >= _opcoes_botoes.size():
		_opcao_atual = 0
	if _opcao_atual < 0:
		_opcao_atual = _opcoes_botoes.size() - 1

	_atualizar_botoes_hover()



func _executar_opcao_atual() -> void:
	if _opcoes_acoes.is_empty():
		return

	var acao: String = str(_opcoes_acoes[_opcao_atual])

	match acao:
		"menos_60":
			_alterar_tempo(-passo_tempo_grande)
		"menos_10":
			_alterar_tempo(-passo_tempo)
		"mais_10":
			_alterar_tempo(passo_tempo)
		"mais_60":
			_alterar_tempo(passo_tempo_grande)
		"modo":
			_alternar_modo()
		"reset_record":
			_pedir_confirmacao_reset()
		"orientacao":
			_alternar_orientacao()
		"salvar":
			_salvar_config()
		"voltar":
			_voltar()



func _atualizar_botoes_hover() -> void:
	for i in range(_opcoes_botoes.size()):
		var btn: Button = _opcoes_botoes[i]
		if btn == null:
			continue

		var selecionado: bool = i == _opcao_atual
		var cor: Color = _opcoes_cores[i]

		if btn == btn_modo:
			cor = cor_credito if modo_credito else cor_livre

		if selecionado:
			btn.add_theme_stylebox_override("normal", _estilo_botao(cor, 1))
			btn.add_theme_stylebox_override("hover", _estilo_botao(cor, 2))
			btn.scale = Vector2(1.04, 1.04)
			btn.modulate = Color.WHITE
		else:
			btn.add_theme_stylebox_override("normal", _estilo_botao(cor, 0))
			btn.add_theme_stylebox_override("hover", _estilo_botao(cor, 1))
			btn.scale = Vector2.ONE
			btn.modulate = Color(1, 1, 1, 0.76)



func _input_handled_seguro() -> void:
	if not is_inside_tree():
		return
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()



# =====================================================================
# CURSOR NEON (desenhado em código, sem imagem)
# =====================================================================
func _criar_cursor_custom() -> void:
	cursor_layer = CanvasLayer.new()
	cursor_layer.layer = 999
	add_child(cursor_layer)

	cursor_neon = CursorNeon.new()
	cursor_neon.name = "CursorNeon"
	cursor_neon.cor_normal = cor_neon
	cursor_neon.cor_hover = cor_livre
	cursor_neon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_layer.add_child(cursor_neon)



# ---------------------------------------------------------------------
# Classe interna: seta neon com brilho e pulso (desenhada via _draw).
# ---------------------------------------------------------------------
class CursorNeon extends Control:
	var cor_normal: Color = Color(1.0, 0.55, 0.10, 1.0)
	var cor_hover: Color = Color(0.24, 1.0, 0.48, 1.0)

	var _hover: bool = false
	var _fase: float = 0.0
	var _escala: float = 1.0

	# Vértices da seta (tip na origem) e triângulos (convexos).
	const _PTS := [
		Vector2(0.0, 0.0),     # 0 ponta
		Vector2(0.0, 20.0),    # 1 base esquerda
		Vector2(5.0, 15.0),    # 2 entalhe (junção)
		Vector2(9.0, 23.0),    # 3 cauda externa 1
		Vector2(13.0, 19.0),   # 4 cauda externa 2
		Vector2(8.0, 11.0),    # 5 junção direita
		Vector2(15.0, 11.0),   # 6 asa direita
	]
	const _TRIS := [
		[0, 1, 2],
		[0, 2, 5],
		[0, 5, 6],
		[2, 3, 4],
		[2, 4, 5],
	]
	# Contorno em ordem (para o brilho / borda neon).
	const _CONTORNO := [0, 6, 5, 4, 3, 2, 1, 0]


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_level = true
		z_index = 4096
		custom_minimum_size = Vector2(28, 28)
		set_process(true)


	func definir_hover(v: bool) -> void:
		if v != _hover:
			_hover = v
		queue_redraw()


	func _process(delta: float) -> void:
		_fase += delta * (6.5 if _hover else 3.2)
		var alvo := 1.18 if _hover else 1.0
		_escala = lerp(_escala, alvo, clamp(delta * 12.0, 0.0, 1.0))
		queue_redraw()


	func _draw() -> void:
		var cor := cor_hover if _hover else cor_normal
		var pulso := 0.5 + 0.5 * sin(_fase)

		# Pontos escalados a partir da ponta.
		var pts: PackedVector2Array = PackedVector2Array()
		for p in _PTS:
			pts.append(p * _escala)

		# 1) Halo neon externo (várias bordas, alpha baixo → brilho).
		var contorno := PackedVector2Array()
		for idx in _CONTORNO:
			contorno.append(pts[idx])
		var camadas := 4
		for c in range(camadas):
			var t := float(c) / float(camadas - 1)
			var largura : float = lerp(10.0, 2.0, t) * (1.0 + 0.25 * pulso)
			var alfa : float = lerp(0.05, 0.22, t) * (0.7 + 0.3 * pulso)
			draw_polyline(contorno, Color(cor.r, cor.g, cor.b, alfa), largura, true)

		# 2) Corpo preenchido (triângulos convexos → sem glitch).
		var preenche := Color(0.05, 0.05, 0.07, 0.96)
		for tri in _TRIS:
			var tri_pts := PackedVector2Array([pts[tri[0]], pts[tri[1]], pts[tri[2]]])
			draw_colored_polygon(tri_pts, preenche)

		# 3) Borda nítida por cima.
		draw_polyline(contorno, Color(cor.r, cor.g, cor.b, 0.95), 2.0, true)

		# 4) Brilho interno suave perto da ponta.
		draw_circle(pts[0], 2.2 + 1.4 * pulso, Color(cor.r, cor.g, cor.b, 0.30 + 0.25 * pulso))


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
