extends Node

## OS COMANDOS DA MÁQUINA (placa Zero Delay e, se tiver, o Arduino).
##
## Na Zero Delay (cada borne: o fio do sinal + o GND):
##   input_start    START (STR)           (PC: 1, Espaço, Enter)
##   input_select   SELECT                (PC: 2, Tab)
##   input_cesta    QUADRADO = sensor     (PC: C, 3)   cada sinal = 1 cesta
##   input_credito  TRIÂNGULO = moedeiro  (PC: 5)      (modo CRÉDITO)
##   input_config   R2 = configuração     (PC: 9, F10)
##
## Sem mapeamento gravado valem os botões da Zero Delay nas DUAS numerações
## que ela pode chegar: a do jogo antigo (Godot 4 / Windows: START 6,
## SELECT 4, cesta 2) e a do Godot 3 no Android (START 11, SELECT 10,
## cesta 2, R2 7). Quadrado (2) e triângulo (3) têm o mesmo número nas
## duas. A FICHA fica num borne que o jogador não alcança (o moedeiro é
## ligado por dentro da máquina): nunca no SELECT, senão cada aperto do
## SELECT seria uma ficha de graça. Se a TV Box numerar diferente, o ASSISTENTE DE BOTÕES
## (menu de configuração, ou segurar qualquer botão 10 s na abertura) pede
## um botão de cada vez e grava em user://slam_botoes.cfg.
##
## CADA APERTO É UM CLIQUE: um botão (ou o sensor) só vale de novo depois
## de SOLTO — sensor preso ou bola parada no sensor não faz ponto; repique
## do contato em menos de 60 ms também não conta.
##
## O CONTROLE REMOTO DA TV BOX também opera a máquina: na abertura (ou na
## apresentação) MENU, VOLTAR ou qualquer seta abre a configuração; lá
## CIMA/BAIXO escolhem, ESQUERDA/DIREITA mudam o valor, OK (= START) muda /
## executa e VOLTAR salva e sai. A Zero Delay é joystick e nunca manda essas
## teclas: o público não chega nelas. O VOLTAR do Android chega ao Godot 3.6
## só como aviso (GO_BACK_REQUEST), sem tecla: aqui ele vira a tecla
## KEY_BACK, que as telas tratam como o Esc do PC (e nunca fecha o jogo:
## quit_on_go_back=false no project.godot).

const ARQUIVO := "user://slam_botoes.cfg"

const ACOES := ["input_start", "input_select", "input_cesta", "input_credito", "input_config"]

## A sequência do assistente: ação, nome na tela, obrigatório?
const SEQUENCIA := [
	["input_start", "START", true],
	["input_select", "SELECT", true],
	["input_cesta", "SENSOR DA CESTA\n(jogue uma bola na cesta)", true],
	["input_credito", "FICHA / MOEDEIRO\n(opcional)", false],
	["input_config", "CONFIGURAÇÃO\n(opcional)", false],
]

const PADRAO_BOTOES := {
	"input_start": [11, 6],
	"input_select": [10, 4],
	"input_cesta": [2],
	"input_credito": [3],
	"input_config": [7],
}
const PADRAO_TECLAS := {
	"input_start": [KEY_1, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
	"input_select": [KEY_2, KEY_TAB],
	"input_cesta": [KEY_C, KEY_3],
	"input_credito": [KEY_5],
	"input_config": [KEY_9, KEY_F10],
}

## Godot 3.6 no Android: joystick sem mapeamento próprio usa o "Default
## Android Gamepad" (sem L2/R2 como botão). Ele ganha este (o mesmo, mais
## esses botões), como no Strike Kids.
const MAPA_ANDROID := "a:b0,b:b1,x:b2,y:b3,back:b4,guide:b5,start:b6,leftstick:b7,rightstick:b8,leftshoulder:b9,rightshoulder:b10,dpup:b11,dpdown:b12,dpleft:b13,dpright:b14,lefttrigger:b15,righttrigger:b16,misc1:b17,paddle1:b18,paddle2:b19,paddle3:b20,paddle4:b21,touchpad:b22,leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:a4,righttrigger:a5,dpup:h0.1,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,platform:Android"

const REPIQUE_MS := 60

var mapeamento_gravado := false
var _abaixados := {}
var _ultimo_clique := {}
var _segurado_desde := {}
var _evento_visto: InputEvent = null
var _veredito_visto := false
var _voltar_ms := -1000


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	# as ações "ui_*" (setas, OK, voltar do controle remoto) não fazem nada
	for acao in InputMap.get_actions():
		if str(acao).begins_with("ui_"):
			InputMap.action_erase_events(acao)
	for acao in ACOES:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao, 0.5)
	_padrao()
	_carregar()
	if OS.get_name() == "Android":
		Input.connect("joy_connection_changed", self, "_joystick_mudou")
		for aparelho in Input.get_connected_joypads():
			_completar_mapa(aparelho)


func _joystick_mudou(aparelho: int, ligado: bool) -> void:
	if ligado:
		call_deferred("_completar_mapa", aparelho)


func _completar_mapa(aparelho: int) -> void:
	if Input.is_joy_known(aparelho):
		return
	var guid := Input.get_joy_guid(aparelho)
	if guid == "":
		return
	var nome := Input.get_joy_name(aparelho).replace(",", " ")
	Input.add_joy_mapping("%s,%s,%s" % [guid, nome, MAPA_ANDROID], true)


func _padrao() -> void:
	for acao in ACOES:
		InputMap.action_erase_events(acao)
		for b in PADRAO_BOTOES[acao]:
			var ev = InputEventJoypadButton.new()
			ev.device = -1
			ev.button_index = b
			InputMap.action_add_event(acao, ev)
		for k in PADRAO_TECLAS[acao]:
			var ek = InputEventKey.new()
			ek.scancode = k
			InputMap.action_add_event(acao, ek)


func _carregar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARQUIVO) != OK:
		return
	var botoes := {}
	for item in SEQUENCIA:
		if cfg.has_section_key("botoes", item[0]):
			botoes[item[0]] = str(cfg.get_value("botoes", item[0]))
	if not botoes.empty():
		_aplicar(botoes)
		mapeamento_gravado = true


func gravar(botoes: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for acao in botoes:
		cfg.set_value("botoes", acao, botoes[acao])
	cfg.save(ARQUIVO)
	_padrao()
	_aplicar(botoes)
	mapeamento_gravado = true


func apagar_mapeamento() -> void:
	var d := Directory.new()
	if d.file_exists(ARQUIVO):
		d.remove(ARQUIVO)
	_padrao()
	mapeamento_gravado = false


## O botão gravado substitui os botões de joystick do padrão (as teclas do
## PC continuam valendo).
func _aplicar(botoes: Dictionary) -> void:
	for acao in botoes:
		var texto = str(botoes[acao])
		for ev in InputMap.get_action_list(acao):
			if ev is InputEventJoypadButton:
				InputMap.action_erase_event(acao, ev)
		if texto.begins_with("tecla:"):
			var ek = InputEventKey.new()
			ek.physical_scancode = int(texto.substr(6))
			InputMap.action_add_event(acao, ek)
		elif texto.begins_with("botao:"):
			var ev = InputEventJoypadButton.new()
			ev.device = -1
			ev.button_index = int(texto.substr(6))
			InputMap.action_add_event(acao, ev)


static func codigo_do_evento(event: InputEvent) -> String:
	if event is InputEventJoypadButton:
		return "botao:%d" % int(event.button_index)
	if event is InputEventKey:
		var k := event as InputEventKey
		var c := int(k.physical_scancode) if k.physical_scancode != 0 else int(k.scancode)
		if c != 0:
			return "tecla:%d" % c
	return ""


static func texto_do_codigo(codigo: String) -> String:
	if codigo.begins_with("tecla:"):
		return "TECLA %s" % OS.get_scancode_string(int(codigo.substr(6)))
	if codigo.begins_with("botao:"):
		return "BOTÃO %d" % int(codigo.substr(6))
	return "-"


func texto_de(acao: String) -> String:
	var partes := []
	for ev in InputMap.get_action_list(acao):
		var t = ""
		if ev is InputEventJoypadButton:
			t = "BOTÃO %d" % int(ev.button_index)
		elif ev is InputEventKey:
			var c: int = ev.physical_scancode if ev.physical_scancode != 0 else ev.scancode
			t = OS.get_scancode_string(c).to_upper()
		if t != "" and not t in partes:
			partes.append(t)
	return PoolStringArray(partes).join(" / ") if not partes.empty() else "-"


## É um aperto NOVO de um botão da placa (ou tecla ligada a uma ação, ou
## sinal do Arduino)? Segurar não repete; repique não conta.
func eh_da_placa(event: InputEvent) -> bool:
	if event is InputEventAction and event.has_meta("arduino"):
		return event.pressed
	if event.is_echo():
		return false
	if not (event is InputEventJoypadButton or event is InputEventKey):
		return false
	if event == _evento_visto:
		return _veredito_visto
	var codigo := codigo_do_evento(event)
	var valido := true
	if event.is_pressed():
		var agora := Time.get_ticks_msec()
		if _abaixados.has(codigo):
			valido = false
		elif agora - int(_ultimo_clique.get(codigo, -100000)) < REPIQUE_MS:
			valido = false
		_abaixados[codigo] = true
		if valido:
			_ultimo_clique[codigo] = agora
	else:
		_abaixados.erase(codigo)
		valido = false
	_evento_visto = event
	_veredito_visto = valido
	return valido


## Aperto novo desta ação?
func apertou(event: InputEvent, acao: String) -> bool:
	return event.is_action_pressed(acao) and eh_da_placa(event)


func start(event: InputEvent) -> bool:
	return apertou(event, "input_start")


func select(event: InputEvent) -> bool:
	return apertou(event, "input_select")


func cesta(event: InputEvent) -> bool:
	return apertou(event, "input_cesta")


func credito(event: InputEvent) -> bool:
	return apertou(event, "input_credito")


func config(event: InputEvent) -> bool:
	return apertou(event, "input_config")


## Arduino: o sensor/botão que ele manda vira a mesma ação da placa.
func injetar(acao: String) -> void:
	var ev := InputEventAction.new()
	ev.action = acao
	ev.pressed = true
	ev.set_meta("arduino", true)
	Input.parse_input_event(ev)
	var solta := InputEventAction.new()
	solta.action = acao
	solta.pressed = false
	solta.set_meta("arduino", true)
	Input.parse_input_event(solta)


# ------------------------------------------------ controle remoto da TV Box
func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
		call_deferred("_tecla_voltar")


func _tecla_voltar() -> void:
	if Time.get_ticks_msec() - _voltar_ms < 250:
		return   # (já chegou como tecla)
	for apertada in [true, false]:
		var ev := InputEventKey.new()
		ev.scancode = KEY_BACK
		ev.pressed = apertada
		Input.parse_input_event(ev)


## Tecla do controle remoto (ou do teclado do PC) apertada agora? Com
## "repetir", segurar a tecla repete (andar na lista).
static func tecla(event: InputEvent, teclas: Array, repetir := false) -> bool:
	return event is InputEventKey and event.pressed and (repetir or not event.echo) and teclas.has(int(event.scancode))


## VOLTAR do controle (Esc no PC).
static func voltou(event: InputEvent) -> bool:
	return tecla(event, [KEY_BACK, KEY_ESCAPE])


## MENU, VOLTAR ou uma seta do controle (F10 no PC): abre a configuração.
static func pede_config(event: InputEvent) -> bool:
	return tecla(event, [KEY_MENU, KEY_BACK, KEY_ESCAPE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_F10])


# --------------------------------------------- botões segurados (abertura)
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.scancode == KEY_BACK:
		_voltar_ms = Time.get_ticks_msec()
	if not (event is InputEventJoypadButton or event is InputEventKey) or event.is_echo():
		return
	eh_da_placa(event)
	var chave := codigo_do_evento(event)
	if chave == "":
		return
	if event.is_pressed():
		if not _segurado_desde.has(chave):
			_segurado_desde[chave] = Time.get_ticks_msec()
	else:
		_segurado_desde.erase(chave)


## Há quanto tempo (ms) o botão segurado há mais tempo está apertado.
func maior_tempo_segurado() -> int:
	var agora := Time.get_ticks_msec()
	var maior := 0
	for k in _segurado_desde:
		maior = int(max(maior, agora - int(_segurado_desde[k])))
	return maior


func esquecer_segurados() -> void:
	_segurado_desde.clear()


func segurando(acao: String) -> bool:
	return Input.is_action_pressed(acao)
