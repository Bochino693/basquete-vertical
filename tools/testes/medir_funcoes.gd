extends Node

## Mede quanto tempo de processador as ações do jogo levam (µs), chamando
## cada uma várias vezes:
##   godot_headless --path . res://tools/testes/medir_funcoes.tscn

var principal: Node


func _ready() -> void:
	Ajustes.tempo_fase = [60, 35, 30]
	principal = load("res://cenas/principal.tscn").instance()
	add_child(principal)
	_rodar()


func _medir(nome: String, obj: Object, metodo: String, args := [], vezes := 20) -> void:
	var tempos := []
	for i in vezes:
		var t0 := OS.get_ticks_usec()
		obj.callv(metodo, args)
		tempos.append(OS.get_ticks_usec() - t0)
		yield(get_tree(), "idle_frame")
	tempos.sort()
	print("%-28s mediana %6d µs   pior %6d µs" % [nome, tempos[tempos.size() / 2], tempos[tempos.size() - 1]])


func _rodar() -> void:
	while principal.atual == null:
		yield(get_tree(), "idle_frame")
	yield(get_tree().create_timer(0.5), "timeout")
	var ap = principal.telas["apresentacao"]
	yield(_medir("apresentação: quique", ap, "_quique", [1.0]), "completed")
	principal.ir("jogo", {"sem_escuro": true})
	yield(get_tree().create_timer(0.5), "timeout")
	var jg = principal.telas["jogo"]
	jg._comecar_tempo()
	jg.estado = jg.JOGANDO
	Ajustes.trava_sensor = 0.0
	yield(_medir("jogo: cesta", jg, "_cesta", [], 30), "completed")
	yield(_medir("jogo: bola de ouro", jg, "_mostrar_ouro"), "completed")
	yield(_medir("jogo: aviso", jg, "_avisar", ["TESTE DE AVISO", Arte.OURO, 1.0, 9]), "completed")
	yield(_medir("jogo: raio", jg, "_raio_slam"), "completed")
	yield(_medir("jogo: entrar slam", jg, "_entrar_slam"), "completed")
	yield(_medir("jogo: festa recorde", jg, "_festa_recorde"), "completed")
	yield(_medir("jogo: atualizar alvo", jg, "_atualizar_alvo"), "completed")
	yield(_medir("jogo: cartão da fase", jg, "_atualizar_card", [0]), "completed")
	yield(_medir("jogo: HUD da fase", jg, "_preparar_fase_hud", [1], 5), "completed")
	jg.passou = [false, false, false]
	jg._alvo = 0
	yield(_medir("jogo: passou", jg, "_conferir_pass", [], 1), "completed")
	yield(_medir("jogo: resultado", jg, "_mostrar_resultado", [true], 3), "completed")
	yield(_medir("Ajustes: salvar recordes", Ajustes, "salvar_recordes"), "completed")
	get_tree().quit()
