extends Node

## ROTEIRO DE TESTE: roda o jogo de verdade (cenas/principal.tscn), joga
## uma partida inteira sozinho e tira fotos de cada momento.
##   xvfb-run -s "-screen 0 1080x1920x24" godot --path . res://tools/testes/roteiro.tscn -- --fotos=/caminho
## Também mede o tempo de cada quadro por tela. Com o Godot "headless"
## (sem placa de vídeo, sem fotos) o tempo do quadro é só o do processador
## (scripts, partículas, montagem do desenho):
##   godot_headless --path . res://tools/testes/roteiro.tscn

var principal: Node
var pasta := "user://fotos"
var _quadros := []
var _medindo := false


func _ready() -> void:
	for a in OS.get_cmdline_args():
		if a.begins_with("--fotos="):
			pasta = a.substr(8)
	Directory.new().make_dir_recursive(pasta)
	# (headless: os eventos injetados não esperam o próximo quadro)
	Input.use_accumulated_input = false
	Ajustes.tempo_turno = 20
	Ajustes.recorde = 6
	Ajustes.mostrar_fps = true
	Ajustes.qualidade = 1
	Ajustes.escala_auto = 1.0
	Tela.definir_escala(1.0)
	principal = load("res://cenas/principal.tscn").instance()
	add_child(principal)
	_rodar()


var _n := 0
var _ultimo := ""
var _foto_quadro := -10
var _cpu := {}        # tela -> [tempos de script por quadro]
var _desenhos := {}   # tela -> maior número de desenhos


func _process(delta: float) -> void:
	_n += 1
	if not _medindo or principal.atual == null:
		return
	if _n - _foto_quadro <= 2:
		return
	_quadros.append(delta)
	var tela: String = principal.atual.name
	if not _cpu.has(tela):
		_cpu[tela] = []
		_desenhos[tela] = 0
	_cpu[tela].append(delta)
	if delta > 0.012:
		print("pico %.1f ms (tela %s, depois de %s, jogo: %s)" % [delta * 1000.0, tela, _ultimo, str(principal.telas["jogo"].estado)])
	_desenhos[tela] = int(max(_desenhos[tela], Performance.get_monitor(Performance.RENDER_2D_DRAW_CALLS_IN_FRAME)))


func _esperar(s: float) -> void:
	yield(get_tree().create_timer(s), "timeout")


func _foto(nome: String) -> void:
	if OS.get_name() == "Server":
		# sem placa de vídeo (Godot "headless"): mede só o processador
		print("passo: ", nome)
		_ultimo = nome
		yield(get_tree(), "idle_frame")
		return
	yield(VisualServer, "frame_post_draw")
	var img := get_viewport().get_texture().get_data()
	img.flip_y()
	img.resize(540, 960, Image.INTERPOLATE_BILINEAR)
	img.save_png(pasta.plus_file(nome + ".png"))
	_foto_quadro = _n
	print("foto: ", nome)


func _tela(nome: String) -> Node:
	return principal.telas[nome]


func _rodar() -> void:
	# preparação
	while principal.atual == null:
		yield(get_tree(), "idle_frame")
	_medindo = true
	var ap = _tela("apresentacao")
	yield(_esperar(0.9), "completed")
	yield(_foto("01_apresentacao_letreiro"), "completed")
	yield(_esperar(2.2), "completed")
	yield(_foto("02_apresentacao_quadra"), "completed")
	yield(_esperar(1.3), "completed")
	yield(_foto("03_apresentacao_bola"), "completed")
	yield(_esperar(2.05), "completed")
	yield(_foto("04_apresentacao_cesta"), "completed")
	yield(_esperar(0.75), "completed")
	yield(_foto("05_apresentacao_raio"), "completed")
	yield(_esperar(0.5), "completed")
	yield(_foto("06_apresentacao_poster"), "completed")
	while principal.atual != _tela("abertura"):
		yield(get_tree(), "idle_frame")
	var ab = _tela("abertura")
	yield(_esperar(1.5), "completed")
	yield(_foto("07_abertura"), "completed")
	ab._mostrar_painel(ab._como)
	yield(_esperar(1.0), "completed")
	yield(_foto("08_como_jogar"), "completed")
	ab._esconder_painel()
	yield(_esperar(0.5), "completed")
	Ajustes.ranking_dia = [{"pontos": 42, "cestas": 30, "cor": 1, "hora": "14:02"}, {"pontos": 35, "cestas": 25, "cor": 0, "hora": "13:40"}, {"pontos": 12, "cestas": 12, "cor": 3, "hora": "11:15"}]
	ab._mostrar_painel(ab._recordes)
	yield(_esperar(1.0), "completed")
	yield(_foto("09_recordes"), "completed")
	ab._esconder_painel()
	yield(_esperar(0.5), "completed")
	Controles.injetar("input_start")
	yield(_esperar(1.0), "completed")
	Controles.injetar("input_select")
	yield(_esperar(0.4), "completed")
	yield(_foto("10_jogadores"), "completed")
	Controles.injetar("input_start")
	while principal.atual != _tela("jogo"):
		yield(get_tree(), "idle_frame")
	var jg = _tela("jogo")
	yield(_esperar(0.3), "completed")
	yield(_foto("11_carregando"), "completed")
	while not jg._ordem_pronta:
		yield(get_tree(), "idle_frame")
	yield(_esperar(0.3), "completed")
	yield(_foto("12_ordem"), "completed")
	Controles.injetar("input_start")
	yield(_esperar(0.55), "completed")
	yield(_foto("13_contagem"), "completed")
	while jg.estado != jg.JOGANDO:
		yield(get_tree(), "idle_frame")
	yield(_esperar(1.2), "completed")
	yield(_foto("14_jogando"), "completed")
	Controles.injetar("input_cesta")
	yield(_esperar(0.22), "completed")
	yield(_foto("15_cesta"), "completed")
	for i in 5:
		yield(_esperar(0.8), "completed")
		Controles.injetar("input_cesta")
	yield(_esperar(0.25), "completed")
	yield(_foto("16_combo6"), "completed")
	jg._mostrar_ouro()
	yield(_esperar(0.8), "completed")
	yield(_foto("17_bola_de_ouro"), "completed")
	for i in 4:
		yield(_esperar(0.8), "completed")
		Controles.injetar("input_cesta")
	yield(_esperar(0.35), "completed")
	yield(_foto("18_slam_mode"), "completed")
	yield(_esperar(1.0), "completed")
	yield(_foto("19_recorde"), "completed")
	jg._decorrido = jg._total - 8.5
	yield(_esperar(1.0), "completed")
	yield(_foto("20_ultimos_segundos"), "completed")
	while jg.estado != jg.ORDEM:
		yield(get_tree(), "idle_frame")
	yield(_esperar(1.0), "completed")
	yield(_foto("21_proximo_jogador"), "completed")
	Controles.injetar("input_cesta")
	while jg.estado != jg.JOGANDO:
		yield(get_tree(), "idle_frame")
	for i in 3:
		yield(_esperar(0.9), "completed")
		Controles.injetar("input_cesta")
	jg._decorrido = jg._total - 1.0
	while jg.estado != jg.PODIO:
		yield(get_tree(), "idle_frame")
	yield(_esperar(3.6), "completed")
	yield(_foto("22_podio"), "completed")
	_medindo = false
	principal.ir("config", {})
	yield(_esperar(1.0), "completed")
	yield(_foto("23_config"), "completed")
	principal.ir("botoes", {})
	yield(_esperar(1.0), "completed")
	yield(_foto("24_botoes"), "completed")
	_relatorio()
	get_tree().quit()


func _relatorio() -> void:
	for tela in _cpu:
		var v: Array = _cpu[tela]
		v.sort()
		var soma := 0.0
		for x in v:
			soma += x
		print("%s: %d quadros, média %.2f ms, p95 %.2f ms, pior %.2f ms, desenhos máx %d" % [tela, v.size(),
			soma / v.size() * 1000.0, v[int(v.size() * 0.95)] * 1000.0, v[v.size() - 1] * 1000.0, _desenhos[tela]])
	_quadros.sort()
	var n := _quadros.size()
	if n == 0:
		return
	var soma := 0.0
	for q in _quadros:
		soma += q
	print("quadros: %d  média %.1f ms  mediana %.1f ms  p95 %.1f ms  pior %.1f ms" % [n, soma / n * 1000.0,
		_quadros[n / 2] * 1000.0, _quadros[int(n * 0.95)] * 1000.0, _quadros[n - 1] * 1000.0])
