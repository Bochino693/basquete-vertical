extends Node

## Grava imagens/splash.png (a imagem de abertura do app: o Android a mostra
## no instante em que o ícone é tocado) a partir do PRÓPRIO emblema do jogo
## (scripts/fx/emblema.gd), parado: a capa e a apresentação começam nele,
## então do toque até o jogo não há tela preta nem "pulo".
##   godot --path . res://tools/testes/gravar_splash.tscn
## Quadrada (1080 x 1080) e redonda: fica certa com a TV Box em pé ou
## deitada (o Godot a encaixa no meio da tela, na cor de fundo do projeto).

const LADO := 1080
var _vp: Viewport
var _n := 0


func _ready() -> void:
	_vp = Viewport.new()
	_vp.size = Vector2(LADO, LADO)
	_vp.render_target_update_mode = Viewport.UPDATE_ALWAYS
	_vp.transparent_bg = false
	_vp.usage = Viewport.USAGE_2D
	add_child(_vp)
	var fundo := ColorRect.new()
	fundo.color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	fundo.rect_size = Vector2(LADO, LADO)
	_vp.add_child(fundo)
	var e = load("res://scripts/fx/emblema.gd").new()
	e.position = Vector2(LADO, LADO) * 0.5
	e.bola.velocidade = 0.0
	_vp.add_child(e)


func _process(_d: float) -> void:
	_n += 1
	if _n == 5:
		var img := _vp.get_texture().get_data()
		img.flip_y()
		img.convert(Image.FORMAT_RGB8)
		img.save_png("res://imagens/splash.png")
		print("gravado: imagens/splash.png ", img.get_size())
		get_tree().quit()
