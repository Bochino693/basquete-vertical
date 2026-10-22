extends "res://scripts/tela_base.gd"

## ASSISTENTE DE BOTÕES DA PLACA: pede um botão de cada vez (START,
## SELECT, SENSOR DA CESTA e, se tiver, FICHA e CONFIGURAÇÃO) e grava.
## Vale botão de joystick ou tecla (placa no modo teclado). Os opcionais
## pulam sozinhos se nada for apertado em 8 s.

const PULAR_EM := 8.0

var _passo := 0
var _botoes := {}
var _titulo: Label
var _pede: Node2D
var _info: Label
var _lista: Label
var _espera := 0.0
var _t := 0.0
var _fim := false
var _de := "abertura"
var _soltar := ""


func _ready() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.012, 0.03)
	fundo.rect_size = Vector2(LARGURA, ALTURA)
	add_child(fundo)
	var p := Arte.painel(Arte.CIANO, 0.9, 36, 3, 24)
	pos(p, 60, 360, 960, 1200)
	add_child(p)
	_titulo = Arte.texto("BOTÕES DA PLACA", 64, Color(1, 1, 1), 8, Arte.AZUL_RAIO)
	pos(_titulo, 60, 400, 960, 90)
	add_child(_titulo)
	var sub := Arte.texto("APERTE O BOTÃO PEDIDO (UM DE CADA VEZ)", 30, Color(0.8, 0.9, 1.0), 3, Color(0, 0, 0))
	pos(sub, 60, 500, 960, 50)
	add_child(sub)
	_pede = Arte.texto_solto("", 74, Color(1, 1, 1), 9, Arte.LARANJA, 900)
	_pede.position = Vector2(540, 720)
	add_child(_pede)
	Arte.rotulo_de(_pede).autowrap = true
	Arte.rotulo_de(_pede).rect_position = Vector2(-450, -130)
	Arte.rotulo_de(_pede).rect_size = Vector2(900, 260)
	_info = Arte.texto("", 32, Color(1.0, 0.85, 0.5), 4, Color(0, 0, 0))
	_info.autowrap = true
	pos(_info, 100, 880, 880, 120)
	add_child(_info)
	_lista = Arte.texto("", 32, Color(1, 1, 1), 3, Color(0, 0, 0), Label.ALIGN_LEFT)
	_lista.autowrap = true
	pos(_lista, 140, 1030, 800, 480)
	add_child(_lista)


func entrar(dados := {}) -> void:
	.entrar(dados)
	_de = str(dados.get("de", "abertura"))
	_passo = 0
	_botoes = {}
	_fim = false
	_espera = 0.0
	_soltar = ""
	Sons.musica("")
	_mostrar_passo()


func _mostrar_passo() -> void:
	var item: Array = Controles.SEQUENCIA[_passo]
	Arte.rotulo_de(_pede).text = "APERTE:\n" + item[1]
	_info.text = "" if item[2] else "(SE A MÁQUINA NÃO TIVER, ESPERE: PULA SOZINHO)"
	_espera = 0.0
	pop(_pede, 1.15)
	_atualizar_lista()


func _atualizar_lista() -> void:
	var linhas := []
	for item in Controles.SEQUENCIA:
		var nome: String = item[1].split("\n")[0]
		var v = "..."
		if _botoes.has(item[0]):
			v = Controles.texto_do_codigo(_botoes[item[0]])
		elif Controles.SEQUENCIA.find(item) < _passo:
			v = "(sem)"
		linhas.append("%s:  %s" % [nome, v])
	_lista.text = PoolStringArray(linhas).join("\n")


func _process(delta: float) -> void:
	_t += delta
	tom(_pede, 0.85 + 0.15 * sin(_t * 5.0))
	if _fim:
		return
	var item: Array = Controles.SEQUENCIA[_passo]
	if not item[2]:
		_espera += delta
		_info.text = "(SE A MÁQUINA NÃO TIVER, ESPERE: PULA EM %d)" % int(ceil(PULAR_EM - _espera))
		if _espera >= PULAR_EM:
			_avancar()


func _input(event: InputEvent) -> void:
	if not ativo or _fim:
		return
	if not (event is InputEventJoypadButton or event is InputEventKey) or event.is_echo():
		return
	var codigo := Controles.codigo_do_evento(event)
	if codigo == "":
		return
	if not event.is_pressed():
		if codigo == _soltar:
			_soltar = ""
		return
	if Controles.voltou(event):
		ir(_de)
		return
	if _soltar != "":
		return
	for acao in _botoes:
		if _botoes[acao] == codigo:
			_info.text = "ESSE JÁ É O %s: APERTE OUTRO" % Controles.texto_do_codigo(codigo)
			Sons.tocar("quebra", -6.0)
			get_tree().set_input_as_handled()
			return
	_botoes[Controles.SEQUENCIA[_passo][0]] = codigo
	_soltar = codigo
	Sons.tocar("selecao", -4.0)
	get_tree().set_input_as_handled()
	_avancar()


func _avancar() -> void:
	_passo += 1
	if _passo >= Controles.SEQUENCIA.size():
		_terminar()
	else:
		_mostrar_passo()


func _terminar() -> void:
	_fim = true
	Controles.gravar(_botoes)
	_atualizar_lista()
	Arte.rotulo_de(_pede).text = "GRAVADO!"
	_info.text = "OS BOTÕES DA PLACA FORAM GRAVADOS NESTA TV BOX"
	Sons.tocar("recorde", -4.0)
	var s := sessao
	yield(get_tree().create_timer(2.5), "timeout")
	if vale(s):
		ir(_de if _de == "config" else "abertura", {"de": "abertura"})
