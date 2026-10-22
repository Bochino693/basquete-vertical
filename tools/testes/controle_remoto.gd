extends Node

## TESTE DO CONTROLE REMOTO DA TV BOX: roda o jogo de verdade e opera a
## configuração só com as teclas do controle (setas, OK, MENU e o VOLTAR do
## Android, que chega como aviso GO_BACK_REQUEST), como o operador faria.
##   xvfb-run -s "-screen 0 1080x1920x24" godot --path . res://tools/testes/controle_remoto.tscn -- --fotos=/caminho
## No fim manda FECHAR O JOGO: o jogo tem de fechar sozinho. Escreve
## "CONTROLE REMOTO: OK" ou cada ERRO encontrado.

var principal: Node
var pasta := "user://fotos"
var _erros := 0


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--fotos="):
			pasta = a.substr(8)
	Directory.new().make_dir_recursive(pasta)
	Input.use_accumulated_input = false
	Ajustes.apresentacao = true
	Ajustes.qualidade = 1
	Ajustes.efeitos_leves = false
	Tela.definir_escala(1.0)
	principal = load("res://cenas/principal.tscn").instance()
	add_child(principal)
	_rodar()


func _esperar(s: float) -> void:
	yield(get_tree().create_timer(s), "timeout")


func _foto(nome: String) -> void:
	if OS.get_name() == "Server":
		yield(get_tree(), "idle_frame")
		return
	yield(VisualServer, "frame_post_draw")
	var img := get_viewport().get_texture().get_data()
	img.flip_y()
	img.resize(540, 960, Image.INTERPOLATE_BILINEAR)
	img.save_png(pasta.plus_file(nome + ".png"))
	print("foto: ", nome)


## Aperta e solta uma tecla do controle (eco = tecla segurada repetindo).
func _tecla(k: int, eco := false) -> void:
	var ev := InputEventKey.new()
	ev.scancode = k
	ev.pressed = true
	ev.echo = eco
	Input.parse_input_event(ev)
	yield(get_tree(), "idle_frame")
	if not eco:
		var solta := InputEventKey.new()
		solta.scancode = k
		Input.parse_input_event(solta)
	yield(_esperar(0.15), "completed")


## O VOLTAR do controle: no Android ele chega só como aviso.
func _voltar() -> void:
	get_tree().notification(MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST)
	yield(_esperar(0.15), "completed")


func _tela(nome: String) -> Node:
	return principal.telas[nome]


func _ate(nome: String, limite := 5.0) -> void:
	var t0 := OS.get_ticks_msec()
	while principal.atual != _tela(nome) or principal._trocando:
		if OS.get_ticks_msec() - t0 > int(limite * 1000.0):
			_erro("não chegou na tela %s (está em %s)" % [nome, principal.atual.name if principal.atual else "-"])
			return
		yield(get_tree(), "idle_frame")
	yield(_esperar(0.2), "completed")


func _conferir(ok: bool, texto: String) -> void:
	if ok:
		print("ok     ", texto)
	else:
		_erro(texto)


func _erro(texto: String) -> void:
	_erros += 1
	print("ERRO   ", texto)


func _rodar() -> void:
	while principal.atual == null:
		yield(get_tree(), "idle_frame")
	yield(_ate("apresentacao"), "completed")
	yield(_esperar(1.0), "completed")
	# 1. na apresentação, uma seta do controle abre a configuração
	yield(_tecla(KEY_DOWN), "completed")
	yield(_ate("config"), "completed")
	_conferir(principal.atual == _tela("config"), "seta na apresentação abre a configuração")
	var cf = _tela("config")
	_conferir(cf._sel == 0, "a configuração começa no primeiro item")
	# 2. CIMA/BAIXO escolhem (segurar repete)
	yield(_tecla(KEY_DOWN), "completed")
	yield(_tecla(KEY_DOWN, true), "completed")
	yield(_tecla(KEY_UP), "completed")
	_conferir(cf._sel == 1, "BAIXO, BAIXO segurado e CIMA: item 2 (TEMPO DA FASE 2)")
	# 3. ESQUERDA/DIREITA mudam o valor (e voltam)
	var antes := int(cf.c["tempo"][1])
	var lista: Array = Ajustes.TEMPOS_FASE[1]
	var i := lista.find(float(antes)) if lista.find(float(antes)) >= 0 else lista.find(antes)
	yield(_tecla(KEY_RIGHT), "completed")
	_conferir(int(cf.c["tempo"][1]) == int(lista[(i + 1) % lista.size()]), "DIREITA: próximo tempo (%d -> %d)" % [antes, int(cf.c["tempo"][1])])
	yield(_tecla(KEY_LEFT), "completed")
	yield(_tecla(KEY_LEFT), "completed")
	_conferir(int(cf.c["tempo"][1]) == int(lista[(i - 1 + lista.size()) % lista.size()]), "ESQUERDA duas vezes: tempo anterior (%d)" % int(cf.c["tempo"][1]))
	# 4. OK muda para o próximo
	var meio := int(cf.c["tempo"][1])
	yield(_tecla(KEY_ENTER), "completed")
	_conferir(int(cf.c["tempo"][1]) != meio, "OK muda o valor (%d -> %d)" % [meio, int(cf.c["tempo"][1])])
	var escolhido := int(cf.c["tempo"][1])
	yield(_foto("controle_01_config"), "completed")
	# 5. VOLTAR salva e sai
	yield(_voltar(), "completed")
	yield(_ate("abertura"), "completed")
	_conferir(principal.atual == _tela("abertura"), "VOLTAR na configuração salva e volta para a abertura")
	_conferir(int(Ajustes.tempo_fase[1]) == escolhido, "o tempo escolhido (%d s) ficou salvo" % escolhido)
	# 6. VOLTAR na abertura abre a configuração (e não fecha o jogo)
	yield(_voltar(), "completed")
	yield(_ate("config"), "completed")
	_conferir(principal.atual == _tela("config"), "VOLTAR na abertura abre a configuração (o jogo não fecha)")
	# 7. CIMA no primeiro item dá a volta: FECHAR O JOGO; OK pergunta, VOLTAR cancela
	yield(_tecla(KEY_UP), "completed")
	_conferir(cf._itens[cf._sel]["id"] == "fechar", "CIMA no primeiro item vai para o último (FECHAR O JOGO)")
	yield(_foto("controle_02_fechar"), "completed")
	yield(_tecla(KEY_ENTER), "completed")
	_conferir(cf._confirmando == "fechar", "OK em FECHAR O JOGO pede confirmação")
	yield(_foto("controle_03_confirmar"), "completed")
	yield(_voltar(), "completed")
	_conferir(cf._confirmando == "" and principal.atual == cf, "VOLTAR cancela a pergunta e fica na configuração")
	# 8. assistente de botões: VOLTAR volta para a configuração
	while cf._itens[cf._sel]["id"] != "botoes":
		yield(_tecla(KEY_UP), "completed")
	yield(_tecla(KEY_ENTER), "completed")
	yield(_ate("botoes"), "completed")
	_conferir(principal.atual == _tela("botoes"), "OK em BOTÕES DA PLACA abre o assistente")
	yield(_voltar(), "completed")
	yield(_ate("config"), "completed")
	_conferir(principal.atual == cf, "VOLTAR no assistente volta para a configuração")
	# 9. Esc (PC) sai; MENU na abertura abre de novo
	yield(_tecla(KEY_ESCAPE), "completed")
	yield(_ate("abertura"), "completed")
	yield(_tecla(KEY_MENU), "completed")
	yield(_ate("config"), "completed")
	_conferir(principal.atual == cf, "MENU na abertura abre a configuração")
	# 10. FECHAR O JOGO: OK e OK de novo fecham o jogo
	yield(_tecla(KEY_UP), "completed")
	yield(_tecla(KEY_ENTER), "completed")
	print("CONTROLE REMOTO: %s" % ("OK" if _erros == 0 else "%d ERROS" % _erros))
	print("confirmando FECHAR O JOGO com OK (o jogo tem de fechar)")
	get_tree().create_timer(3.0).connect("timeout", self, "_nao_fechou")
	yield(_tecla(KEY_ENTER), "completed")


func _nao_fechou() -> void:
	print("ERRO   o jogo não fechou")
	get_tree().quit()
