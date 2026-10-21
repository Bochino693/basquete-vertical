extends Node

## A TELA DO JOGO: SEMPRE 1080 x 1920 (EM PÉ).
##
## Os scripts desenham num retângulo fixo de 1080 x 1920 unidades. Esta
## autoload encaixa esse retângulo na tela de verdade:
##   * monitor em pé ligado no HDMI deitado (a máquina): a imagem inteira é
##     girada 90° (giro 1 ou -1);
##   * TV ou monitor deitado sem giro (giro 0): o jogo fica no meio, com
##     faixas pretas dos lados (nada estica nem deforma).
##
##   giro  1 = topo do jogo na ESQUERDA do HDMI
##   giro -1 = topo do jogo na DIREITA do HDMI
##   giro  0 = sem giro
## (menu do operador; padrão do APK: slam/tela/giro no project.godot; no PC
## a variável de ambiente SLAM_GIRO ou -- --giro=1)
##
## QUALIDADE: na TV Box fraca a imagem pode ser desenhada em 900 ou 720
## linhas e ampliada (a placa pinta 30% ou 55% menos pixels). Na qualidade
## AUTOMÁTICA o jogo mede os quadros por segundo durante a partida e desce
## sozinho um degrau se a TV Box não segurar ~60 (fica gravado).

signal mudou

const LARGURA := 1080.0
const ALTURA := 1920.0
const TAMANHO := Vector2(1080, 1920)

var giro := 0
var escala := 1.0

# medidor da qualidade automática
var _medindo := false
var _amostras := 0
var _ruins := 0
var _acumulado := 0.0


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_janela_de_teste()
	giro = _giro_configurado()
	escala = Ajustes.escala_tela()
	get_tree().root.connect("size_changed", self, "_aplicar")
	_aplicar()


## O jogo abre em TELA CHEIA. Para testar no PC numa janela:
##   godot --path . -- --janela=540x960
func _janela_de_teste() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--janela="):
			var p = a.substr(9).split("x")
			OS.window_fullscreen = false
			if p.size() == 2:
				OS.window_size = Vector2(int(p[0]), int(p[1]))
				OS.center_window()


func _giro_configurado() -> int:
	for a in OS.get_cmdline_args():
		if a.begins_with("--giro="):
			return int(clamp(int(a.substr(7)), -1, 1))
	if OS.has_environment("SLAM_GIRO"):
		return int(clamp(int(OS.get_environment("SLAM_GIRO")), -1, 1))
	if Ajustes.giro != 99:
		return int(clamp(Ajustes.giro, -1, 1))
	if OS.get_name() != "Android":
		return 0
	return int(ProjectSettings.get_setting("slam/tela/giro")) if ProjectSettings.has_setting("slam/tela/giro") else 1


func definir_giro(novo: int) -> void:
	giro = int(clamp(novo, -1, 1))
	_aplicar()


func definir_escala(nova: float) -> void:
	escala = clamp(nova, 0.5, 1.0)
	_aplicar()


func tamanho() -> Vector2:
	return TAMANHO


var _aplicando := false


func _aplicar() -> void:
	if _aplicando:
		return
	_aplicando = true
	var base := Vector2(LARGURA, ALTURA) if giro == 0 else Vector2(ALTURA, LARGURA)
	var t := Transform2D.IDENTITY
	if giro > 0:
		# (x, y) do jogo -> (y, 1080 - x) na tela
		t = Transform2D(Vector2(0, -1), Vector2(1, 0), Vector2(0, LARGURA))
	elif giro < 0:
		# (x, y) do jogo -> (1920 - y, x) na tela
		t = Transform2D(Vector2(0, 1), Vector2(-1, 0), Vector2(ALTURA, 0))
	if escala >= 0.999:
		# 2D: desenha na resolução da própria tela (nítido)
		get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_2D, SceneTree.STRETCH_ASPECT_KEEP, base)
	else:
		# desenha numa imagem menor (base x escala) e amplia no fim
		get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_VIEWPORT, SceneTree.STRETCH_ASPECT_KEEP, (base * escala).round())
		t = Transform2D(t.x * escala, t.y * escala, t.origin * escala)
	# (Godot 3: "get_tree().root.x = " tentaria regravar o root - por variável)
	var janela := get_tree().root
	janela.global_canvas_transform = t
	_aplicando = false
	emit_signal("mudou")


# ------------------------------------------------- qualidade automática
## A partida liga o medidor; a abertura desliga (lá tudo é mais leve).
func medir(ligado: bool) -> void:
	_medindo = ligado and Ajustes.qualidade == 0 and escala > 0.67
	_amostras = 0
	_ruins = 0
	_acumulado = 0.0


func _process(delta: float) -> void:
	if not _medindo:
		return
	# janelas de 1 s; 6 janelas ruins seguidas (< 45 quadros) = desce
	# (TV em 50 Hz não conta como ruim)
	_acumulado += delta
	_amostras += 1
	if _acumulado < 1.0:
		return
	var fps := float(_amostras) / _acumulado
	_acumulado = 0.0
	_amostras = 0
	if fps < 45.0:
		_ruins += 1
	else:
		_ruins = 0
	if _ruins >= 6:
		_ruins = 0
		var nova := 0.8333 if escala > 0.9 else 0.6667
		Ajustes.escala_auto = nova
		Ajustes.salvar()
		definir_escala(nova)
		_medindo = escala > 0.67
		print("Tela: TV Box não segurou 60 quadros; qualidade automática -> %d linhas" % int(round(LARGURA * nova)))
