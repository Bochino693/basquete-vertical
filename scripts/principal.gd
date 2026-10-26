extends Node

## O SLAM ARENA: monta todas as telas UMA vez, por trás de uma capa, e
## troca entre elas (nada é carregado do disco depois da preparação).
##
## PREPARAÇÃO (a "capa": o EMBLEMA - a bola com brilho - igual à imagem de
## abertura do app, com o anel enchendo): cada tela é montada e desenhada
## pelo menos uma vez escondida, AOS POUCOS (uma parte nova por quadro: o
## custo da placa de vídeo dividido, a bola da capa não para de girar)
## (os shaders são preparados na placa, as letras de cada fonte entram no
## cache); só então a apresentação começa - e o primeiro quadro dela é a
## própria capa: do toque no ícone até o jogo, nenhuma tela preta. Na
## Mali-450 preparar um shader ou uma letra grande no meio do jogo é um
## tranco visível - aqui não tem.

const TELAS := {
	"apresentacao": "res://scripts/apresentacao.gd",
	"abertura": "res://scripts/abertura.gd",
	"jogo": "res://scripts/jogo.gd",
	"config": "res://scripts/config.gd",
	"botoes": "res://scripts/mapear.gd",
}

var telas := {}
var atual: Control = null
var _trocando := false

var _camada_topo: CanvasLayer
var _escuro: ColorRect
var _capa: Control
var _emblema: Node2D
var _fps: Label
var _aviso: Label
var _fps_t := 0.0
var _progresso_alvo := 0.0


func _ready() -> void:
	randomize()
	get_tree().set_auto_accept_quit(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_montar_topo()
	Arduino.connect("janela_android", self, "_aviso_android")
	_preparar()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_QUIT_REQUEST:
		Arduino.apagar_e_fechar()
		get_tree().quit()


# ------------------------------------------------------------ camada de cima
func _montar_topo() -> void:
	_camada_topo = CanvasLayer.new()
	_camada_topo.layer = 100
	add_child(_camada_topo)
	_escuro = ColorRect.new()
	_escuro.color = Color(0, 0, 0, 0)
	_escuro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_escuro.rect_size = Vector2(1080, 1920)
	_camada_topo.add_child(_escuro)
	_aviso = Arte.texto("", 30, Color(1, 1, 1), 4, Color(0, 0, 0))
	_aviso.autowrap = true
	_aviso.rect_position = Vector2(60, 1560)
	_aviso.rect_size = Vector2(960, 200)
	_aviso.visible = false
	_camada_topo.add_child(_aviso)
	_fps = Arte.texto("", 24, Color(0.6, 1.0, 0.6), 3, Color(0, 0, 0), Label.ALIGN_LEFT)
	_fps.rect_position = Vector2(16, 6)
	_fps.rect_size = Vector2(1000, 40)
	_camada_topo.add_child(_fps)
	# capa da preparação (a mesma imagem da abertura da TV Box)
	_capa = Control.new()
	_capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.rect_size = Vector2(1080, 1920)
	_camada_topo.add_child(_capa)
	var fundo := ColorRect.new()
	fundo.color = Color(0.024, 0.016, 0.047)
	fundo.rect_size = Vector2(1080, 1920)
	_capa.add_child(fundo)
	_emblema = load("res://scripts/fx/emblema.gd").new()
	_emblema.position = Vector2(540, 960)
	# parada como a imagem de abertura do Android enquanto as telas são
	# montadas (o processador fica ocupado: uma imagem parada não "engasga");
	# a bola começa a girar quando a montagem acaba
	_emblema.bola.velocidade = 0.0
	_capa.add_child(_emblema)


## O anel da capa anda liso até o passo novo (por tempo: mesmo com um
## passo mais pesado ele não pula).
func _capa_progresso(f: float) -> void:
	_progresso_alvo = f


func _animar_capa(delta: float) -> void:
	if _capa == null:
		return
	var p: float = _emblema.progresso
	if p < _progresso_alvo:
		# (o emblema ignora passos menores que 0,003: o último vai direto)
		var novo: float = p + max(delta, 0.0) * 0.9
		_emblema.progresso = _progresso_alvo if _progresso_alvo - novo < 0.012 else novo


# ---------------------------------------------------------------- preparação
func _preparar() -> void:
	yield(get_tree(), "idle_frame")
	var nomes := TELAS.keys()
	var passo := 0
	var total := nomes.size() * 2 + 1
	for nome in nomes:
		var t: Control = load(TELAS[nome]).new()
		t.name = nome
		add_child(t)
		t.connect("trocar", self, "ir")
		telas[nome] = t
		passo += 1
		_capa_progresso(float(passo) / total)
		yield(get_tree(), "idle_frame")
	# a camada de cima continua por cima de todas as telas
	move_child(_camada_topo, get_child_count() - 1)
	# as letras GIGANTES (contagem 3-2-1, VAI!) são as mais pesadas de
	# preparar: vão agora, com a capa ainda parada (não aparece)
	var gigantes := Control.new()
	gigantes.rect_size = Vector2(1080, 1920)
	add_child(gigantes)
	move_child(gigantes, 0)
	for f in Arte.todas_as_fontes():
		if f.size >= 150:
			var lg = Label.new()
			lg.add_font_override("font", f)
			lg.add_color_override("font_outline_modulate", Color(1, 1, 1))
			lg.text = Arte.letras_de(f)
			gigantes.add_child(lg)
	for i in 2:
		yield(get_tree(), "idle_frame")
	gigantes.queue_free()
	var giro := create_tween()
	giro.tween_property(_emblema.bola, "velocidade", 2.5, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# cada tela desenhada (escondida pela capa) AOS POUCOS: primeiro as
	# partes que ela mostra sempre, uma por quadro; depois o "aquecer" dela
	# (o que só aparece às vezes: avisos, painéis, efeitos), que também vai
	# por partes e pode levar vários quadros
	for nome in nomes:
		var t: Control = telas[nome]
		t.visible = true
		yield(_revelar_aos_poucos(t), "completed")
		var aq = t.aquecer()
		if aq is GDScriptFunctionState:
			yield(aq, "completed")
		for i in 3:
			yield(get_tree(), "idle_frame")
		t.visible = false
		passo += 1
		_capa_progresso(float(passo) / total)
	# letras: cada fonte criada desenha todas as letras uma vez (uma fonte
	# por quadro)
	var letras := Control.new()
	letras.rect_size = Vector2(1080, 1920)
	add_child(letras)
	move_child(letras, 0)
	var y := 0.0
	for f in Arte.todas_as_fontes():
		var l = Label.new()
		l.add_font_override("font", f)
		l.add_color_override("font_outline_modulate", Color(1, 1, 1))
		l.text = Arte.letras_de(f)
		l.rect_position = Vector2(0, fmod(y, 1800.0))
		y += 37.0
		letras.add_child(l)
		yield(get_tree(), "idle_frame")
	for i in 2:
		yield(get_tree(), "idle_frame")
	letras.queue_free()
	_capa_progresso(1.0)
	# o anel termina de encher (liso) antes de a apresentação começar
	while _emblema.progresso < 0.996:
		yield(get_tree(), "idle_frame")
	yield(get_tree().create_timer(0.15), "timeout")
	# começa: a apresentação (ou direto a abertura)
	var primeira := "apresentacao" if Ajustes.apresentacao else "abertura"
	for a in OS.get_cmdline_args():
		if a.begins_with("--tela="):
			primeira = a.substr(7)
	atual = telas[primeira]
	if primeira == "apresentacao":
		# o primeiro quadro da apresentação é a própria capa (o emblema com o
		# anel cheio e a bola na mesma volta): troca seca, sem nada piscar
		atual.entrar({"primeira_vez": true, "giro_bola": _emblema.bola.get("_giro")})
		yield(get_tree(), "idle_frame")
		yield(get_tree(), "idle_frame")
	else:
		atual.entrar({"primeira_vez": true})
		var tw := create_tween()
		tw.tween_property(_capa, "modulate:a", 0.0, 0.45)
		yield(tw, "finished")
	_capa.queue_free()
	_capa = null


## As partes que a tela já mostra aparecem uma por quadro (um grupo grande
## vai pelas partes dele). No fim tudo está como antes (só à mostra).
func _revelar_aos_poucos(t: Node) -> void:
	var partes := []
	_juntar_partes(t, partes, 0)
	for p in partes:
		p.visible = false
	# quadro leve: várias partes no próximo (a preparação não demora mais
	# num aparelho rápido); quadro pesado: uma só
	var lote := 1
	var n := 0
	for p in partes:
		p.visible = true
		n += 1
		if n >= lote:
			n = 0
			var t0 := OS.get_ticks_msec()
			yield(get_tree(), "idle_frame")
			lote = int(clamp(40.0 / max(OS.get_ticks_msec() - t0, 1), 1, 6))
	yield(get_tree(), "idle_frame")


func _juntar_partes(no: Node, partes: Array, nivel: int) -> void:
	for c in no.get_children():
		if not (c is CanvasItem) or not c.visible:
			continue
		if nivel < 2 and c.get_child_count() >= 6:
			_juntar_partes(c, partes, nivel + 1)
		else:
			partes.append(c)


# ---------------------------------------------------------------- troca
## Troca de tela com um mergulho rápido no preto ("sem_escuro": direto).
func ir(nome: String, dados := {}) -> void:
	if _trocando or not telas.has(nome):
		return
	_trocando = true
	var rapido: bool = dados.get("sem_escuro", false)
	if not rapido:
		var tw := create_tween()
		tw.tween_property(_escuro, "color:a", 1.0, 0.22)
		yield(tw, "finished")
	if atual != null:
		atual.sair()
	atual = telas[nome]
	atual.entrar(dados)
	if not rapido:
		var tw2 := create_tween()
		tw2.tween_property(_escuro, "color:a", 0.0, 0.32)
		yield(tw2, "finished")
	_trocando = false


# -------------------------------------------------------------- avisos
func _aviso_android(texto: String) -> void:
	_aviso.text = texto
	_aviso.visible = texto != ""


func _process(delta: float) -> void:
	_animar_capa(delta)
	if not Ajustes.mostrar_fps:
		if _fps.text != "":
			_fps.text = ""
		return
	_fps_t += delta
	if _fps_t >= 0.5:
		_fps_t = 0.0
		_fps.text = "%d FPS  |  %d desenhos  |  imagem %s  |  %.0f MB" % [Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_2D_DRAW_CALLS_IN_FRAME),
			Tela.texto_desenho(), OS.get_static_memory_usage() / 1048576.0]


func _unhandled_input(event: InputEvent) -> void:
	# F3 (PC) liga/desliga o painel de desempenho
	if event is InputEventKey and event.pressed and not event.echo and event.scancode == KEY_F3:
		Ajustes.mostrar_fps = not Ajustes.mostrar_fps
