extends Node

## A TELA DO JOGO: SEMPRE 1080 x 1920 (EM PÉ), A TELA INTEIRA.
##
## Os scripts desenham num retângulo fixo de 1080 x 1920 unidades. Esta
## autoload encaixa esse retângulo na tela de verdade:
##   * GIRO AUTOMÁTICO (o padrão): se a TV Box já entrega a tela EM PÉ (o
##     Android girado no sistema, como o jogo antigo usava), o jogo não gira
##     nada; se entrega DEITADA (monitor em pé no HDMI deitado), a imagem
##     inteira é girada 90° (slam/tela/giro do APK: 1 = topo à esquerda);
##   * TELA CHEIA: a imagem é esticada até as bordas (sem faixas pretas)
##     sempre que o formato da tela for parecido (16:9, 16:10, 4:3...); só
##     uma janela de outro formato (PC deitado, sem giro) fica com faixas.
##
##   giro 99 = automático   1 = topo do jogo na ESQUERDA do HDMI
##   giro -1 = topo do jogo na DIREITA do HDMI   0 = sem giro
## (menu do operador; no PC a variável de ambiente SLAM_GIRO ou
## -- --giro=1 / --giro=auto)
##
## NITIDEZ: na resolução da tela (até 1080 x 1920) o jogo desenha direto,
## pixel por pixel. Tela MAIOR que isso (TV Box em 4K): desenha em 1080 x
## 1920 e amplia LISO (filtro) - nítido e sem pesar 4 vezes mais na placa.
## QUALIDADE: a AUTOMÁTICA desenha SEMPRE em 1080 (nítido); ela mede os
## quadros por segundo durante a partida e, se a TV Box não segurar ~60,
## desliga os efeitos que mais pesam (EFEITOS LEVES, fica gravado) em vez
## de baixar a resolução. 900 ou 720 linhas (ampliadas LISAS, sem os
## "blocos" de pixel) só se o operador escolher MÉDIA ou LEVE.

signal mudou
signal efeitos_mudaram

const LARGURA := 1080.0
const ALTURA := 1920.0
const TAMANHO := Vector2(1080, 1920)

const AUTO := 99

var giro := 0                 # o giro em uso agora
var escala := 1.0
var _desenho := TAMANHO       # o tamanho em que a imagem é desenhada (pixels)
var _pedido := AUTO           # o que foi pedido (AUTO = automático)

# medidor da qualidade automática
var _medindo := false
var _amostras := 0
var _ruins := 0
var _acumulado := 0.0


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	_janela_de_teste()
	_pedido = _giro_configurado()
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
			return _ler_giro(a.substr(7))
	if OS.has_environment("SLAM_GIRO"):
		return _ler_giro(OS.get_environment("SLAM_GIRO"))
	if Ajustes.giro != AUTO:
		return int(clamp(Ajustes.giro, -1, 1))
	return AUTO


static func _ler_giro(t: String) -> int:
	if t.to_lower().begins_with("auto"):
		return AUTO
	return int(clamp(int(t), -1, 1))


## AUTOMÁTICO: a janela já em pé = sem giro (o sistema já gira); deitada na
## TV Box = o giro do APK; deitada no PC = sem giro (janela de teste).
func _giro_auto() -> int:
	var j := OS.window_size
	if j.y >= j.x or OS.get_name() != "Android":
		return 0
	var g := int(ProjectSettings.get_setting("slam/tela/giro")) if ProjectSettings.has_setting("slam/tela/giro") else 1
	return g if g != 0 else 1


func definir_giro(novo: int) -> void:
	_pedido = AUTO if novo == AUTO else int(clamp(novo, -1, 1))
	_aplicar()


func giro_pedido() -> int:
	return _pedido


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
	giro = _giro_auto() if _pedido == AUTO else _pedido
	var base := Vector2(LARGURA, ALTURA) if giro == 0 else Vector2(ALTURA, LARGURA)
	# tela cheia: formato parecido = estica até as bordas (sem faixas)
	var aspecto := SceneTree.STRETCH_ASPECT_KEEP
	var j := OS.window_size
	if j.x > 0.0 and j.y > 0.0:
		var r := (j.x / j.y) / (base.x / base.y)
		if r > 0.7 and r < 1.43:
			aspecto = SceneTree.STRETCH_ASPECT_IGNORE
	var t := Transform2D.IDENTITY
	if giro > 0:
		# (x, y) do jogo -> (y, 1080 - x) na tela
		t = Transform2D(Vector2(0, -1), Vector2(1, 0), Vector2(0, LARGURA))
	elif giro < 0:
		# (x, y) do jogo -> (1920 - y, x) na tela
		t = Transform2D(Vector2(0, 1), Vector2(-1, 0), Vector2(ALTURA, 0))
	# tela maior que 1080 x 1920 (4K): desenhar nela pesaria 4 vezes mais
	var tela_grande := j.x * j.y > base.x * base.y * 1.15
	if escala >= 0.999 and not tela_grande:
		# 2D: desenha na resolução da própria tela (nítido)
		get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_2D, aspecto, base)
		_desenho = j
	else:
		# desenha numa imagem de 1080 linhas (ou menor) e amplia no fim
		get_tree().set_screen_stretch(SceneTree.STRETCH_MODE_VIEWPORT, aspecto, (base * escala).round())
		t = Transform2D(t.x * escala, t.y * escala, t.origin * escala)
		call_deferred("_ampliar_liso")
		_desenho = (base * escala).round()
	# (Godot 3: "get_tree().root.x = " tentaria regravar o root - por variável)
	var janela := get_tree().root
	janela.global_canvas_transform = t
	_aplicando = false
	emit_signal("mudou")


## A imagem desenhada menor que a tela é ampliada com filtro (liso). Sem
## isto o Godot 3 amplia pixel a pixel: os números e o raio ficam em
## "escadinha", pixelados.
func _ampliar_liso() -> void:
	get_tree().root.get_texture().flags = Texture.FLAG_FILTER


## "1080x1920": o tamanho em que a imagem é desenhada (em pé).
func texto_desenho() -> String:
	var d := _desenho if giro == 0 else Vector2(_desenho.y, _desenho.x)
	return "%dx%d" % [int(d.x), int(d.y)]


## A TV Box entrega menos de 1080 linhas (Android em 720p): nada fica nítido
## de verdade enquanto a resolução não for trocada no Android.
func tela_pequena() -> bool:
	var j := OS.window_size
	return min(j.x, j.y) < 1000.0


# ------------------------------------------------- qualidade automática
## A partida liga o medidor; a abertura desliga (lá tudo é mais leve).
func medir(ligado: bool) -> void:
	_medindo = ligado and Ajustes.qualidade == 0 and not Ajustes.efeitos_leves
	_amostras = 0
	_ruins = 0
	_acumulado = 0.0


func _process(delta: float) -> void:
	if not _medindo:
		return
	# janelas de 1 s; 6 janelas ruins seguidas (< 45 quadros) = efeitos leves
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
		Ajustes.efeitos_leves = true
		Ajustes.salvar()
		_medindo = false
		emit_signal("efeitos_mudaram")
		print("Tela: TV Box não segurou 60 quadros; qualidade automática -> efeitos leves (continua em 1080)")
