extends Node

## Uma foto do jogo de verdade depois de alguns segundos (testar o giro e a
## tela cheia em formatos de tela diferentes):
##   xvfb-run -s "-screen 0 1920x1080x24" godot --path . res://tools/testes/foto_rapida.tscn -- --tela=abertura --giro=1 --foto=/tmp/a.png --apos=5

var _foto := "user://foto.png"
var _apos := 5.0


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--foto="):
			_foto = a.substr(7)
		elif a.begins_with("--apos="):
			_apos = float(a.substr(7))
	Ajustes.qualidade = 1
	add_child(load("res://cenas/principal.tscn").instance())
	yield(get_tree().create_timer(_apos), "timeout")
	yield(VisualServer, "frame_post_draw")
	var img := get_viewport().get_texture().get_data()
	img.flip_y()
	img.save_png(_foto)
	print("foto: %s  janela %s  giro %d  quadros %d" % [_foto, str(OS.window_size), Tela.giro, Engine.get_frames_drawn()])
	get_tree().quit()
