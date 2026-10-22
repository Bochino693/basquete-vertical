extends Node

## OS LEDS DA MÁQUINA (Arduino), COM OS MESMOS COMANDOS DO JOGO ANTIGO:
## uma linha por comando, 9600 baud:
##   ATTRACT    abertura (efeito chamativo)
##   MENU_LOCK  janela de jogadores aberta (aceso parado)
##   SELECT1..4 jogadores escolhidos (1 = aceso, 2..4 = ondas)
##   STARTING   entrando no jogo
##   PLAY       turno começou
##   HIT        cesta
##   RECORD     recorde batido (1ª vez no turno)
##   BOOST      cesta depois do recorde
##   OFF        apaga (fim do turno, saída)
## O Arduino que já está na máquina não precisa ser regravado. Se ele
## responder ao PING com "PONG:SLAM_ARENA" (firmware novo em
## arduino/slam_arena), ele também pode mandar CESTA / START / SELECT /
## FICHA (sensor ou botões ligados nele) — viram os mesmos comandos da
## Zero Delay.
##
## TV BOX (Android): pelo cabo USB, com o plugin StrikeSerial (o mesmo do
## Strike Kids: Arduino original, CH340, FTDI e CP210x). A permissão do
## Android é pedida UMA vez por Arduino, na abertura (marque "Usar por
## padrão"). PC com Windows: a ponte PowerShell do jogo antigo (porta COM
## escolhida no menu). Outros PCs: só registra no console.

signal mudou
## aviso na tela antes da janela de permissão do Android ("" = some)
signal janela_android(texto)

const BAUD := 9600
const LER_MS := 80
const PROCURAR_MS := 1500
const PING_MS := 2000
const REINICIO_MS := 2300        # o Uno reinicia ao abrir a porta
const PERMISSOES := "user://slam_permissoes.cfg"
const DICA_USB := "NA JANELA DO ANDROID: MARQUE \"USAR POR PADRÃO\" E TOQUE EM OK\nassim ela nunca mais aparece"
const COMANDOS_DE_ENTRADA := {"CESTA": "input_cesta", "START": "input_start", "SELECT": "input_select", "FICHA": "input_credito"}

var status := "LEDs: iniciando..."
var conectado := false
var firmware := ""
var janelas_ok := false            # a abertura libera a janela de permissão
var _plugin: Object
var _fase := "procurando"          # procurando | abrindo | esperando | aberta
var _desde := 0
var _ultimo_ler := 0
var _ultimo_ping := 0
var _ultima_procura := -100000
var _falhou := {}
var _pedir_agora := false
var _estado_led := "ATTRACT"
var _ultimo_enviado := ""
var _ultimo_enviado_ms := 0

# Windows: ponte PowerShell (o mesmo jeito do jogo antigo)
const PS_PONTE := """
param([string]$Porta = "COM5", [int]$Baud = 9600, [string]$Arquivo = "")
$ErrorActionPreference = "SilentlyContinue"
try {
	$sp = New-Object System.IO.Ports.SerialPort($Porta, $Baud, "None", 8, "One")
	$sp.DtrEnable = $false
	$sp.RtsEnable = $false
	$sp.NewLine = "`n"
	$sp.WriteTimeout = 80
	$sp.Open()
} catch { exit 1 }
while ($true) {
	try {
		if (Test-Path -LiteralPath $Arquivo) {
			$cmd = [System.IO.File]::ReadAllText($Arquivo).Trim()
			[System.IO.File]::Delete($Arquivo)
			foreach ($l in $cmd.Split("`n")) { if ($l.Trim().Length -gt 0) { $sp.WriteLine($l.Trim()) } }
		}
	} catch {}
	Start-Sleep -Milliseconds 8
}
"""
const ARQ_FILA := "user://slam_led_cmd.txt"
const ARQ_PS := "user://slam_led_ponte.ps1"
var _pid := -1


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	match OS.get_name():
		"Android":
			if Engine.has_singleton("StrikeSerial"):
				_plugin = Engine.get_singleton("StrikeSerial")
				status = "LEDs: procurando o Arduino no USB..."
			else:
				status = "LEDs: este APK não tem o plugin USB (use o GERAR_APK.bat)"
		"Windows":
			_iniciar_ponte_windows()
		_:
			status = "LEDs: no PC sem Windows os comandos só aparecem no console"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_QUIT_REQUEST or what == NOTIFICATION_PREDELETE:
		apagar_e_fechar()


# ------------------------------------------------------------------- LEDs
## Muda o estado dos LEDs (é reenviado sozinho se o Arduino reconectar).
func led(cmd: String) -> void:
	if cmd in ["ATTRACT", "MENU_LOCK", "STARTING", "PLAY", "OFF"] or cmd.begins_with("SELECT"):
		_estado_led = cmd
	_enviar(cmd)


func _enviar(cmd: String) -> void:
	if not Ajustes.leds:
		return
	_ultimo_enviado = cmd
	_ultimo_enviado_ms = Time.get_ticks_msec()
	match OS.get_name():
		"Android":
			if _plugin != null and _fase == "aberta":
				_plugin.call("escrever", cmd)
		"Windows":
			if _pid > 0:
				var f := File.new()
				if f.open(ARQ_FILA, File.READ_WRITE if f.file_exists(ARQ_FILA) else File.WRITE) == OK:
					f.seek_end()
					f.store_string(cmd + "\n")
					f.close()
		_:
			if OS.is_debug_build():
				print("LED -> ", cmd)


func apagar_e_fechar() -> void:
	if _plugin != null and _fase == "aberta":
		_plugin.call("escrever", "OFF")
		OS.delay_msec(60)
		_plugin.call("fechar")
		_fase = "procurando"
	if _pid > 0:
		_enviar("OFF")
		OS.delay_msec(150)
		OS.kill(_pid)
		_pid = -1


func ultimo_comando() -> String:
	return _ultimo_enviado


# ---------------------------------------------------------- Windows (PC)
func _iniciar_ponte_windows() -> void:
	if not Ajustes.leds:
		status = "LEDs desligados no menu"
		return
	var f := File.new()
	if f.open(ARQ_PS, File.WRITE) == OK:
		f.store_string(PS_PONTE)
		f.close()
	var d := Directory.new()
	if d.file_exists(ARQ_FILA):
		d.remove(ARQ_FILA)
	_pid = OS.execute("powershell.exe", ["-ExecutionPolicy", "Bypass", "-NoProfile", "-WindowStyle", "Hidden",
		"-File", ProjectSettings.globalize_path(ARQ_PS), "-Porta", Ajustes.porta_com, "-Baud", str(BAUD),
		"-Arquivo", ProjectSettings.globalize_path(ARQ_FILA)], false)
	conectado = _pid > 0
	status = "LEDs: ponte PowerShell na %s" % Ajustes.porta_com if conectado else "LEDs: PowerShell não abriu"
	emit_signal("mudou")
	if conectado:
		_enviar(_estado_led)


func reiniciar_ponte_windows() -> void:
	if OS.get_name() != "Windows":
		return
	if _pid > 0:
		OS.kill(_pid)
		_pid = -1
	_iniciar_ponte_windows()


# ----------------------------------------------------------- Android (USB)
func _process(_delta: float) -> void:
	if _plugin == null:
		return
	var agora := Time.get_ticks_msec()
	match _fase:
		"procurando":
			if agora - _ultima_procura >= PROCURAR_MS:
				_ultima_procura = agora
				_procurar(agora)
		"abrindo":
			var e := str(_plugin.call("estado"))
			if e == "aberta":
				_fase = "esperando"
				_desde = agora
				_set_status("LEDs: Arduino conectado, esperando ele reiniciar...")
			elif e == "erro" or e == "fechada" or agora - _desde > 8000:
				_falha(str(_plugin.call("erro")))
		"esperando", "aberta":
			if agora - _ultimo_ler < LER_MS:
				return
			_ultimo_ler = agora
			if str(_plugin.call("estado")) != "aberta":
				_perdeu()
				return
			var texto := str(_plugin.call("ler"))
			if texto != "":
				for linha in texto.split("\n", false):
					_receber(linha.strip_edges())
			if _fase == "esperando" and agora - _desde >= REINICIO_MS:
				_fase = "aberta"
				conectado = true
				_set_status("LEDs: Arduino conectado (USB)")
				_plugin.call("escrever", _estado_led)
				_ultimo_ping = agora - PING_MS + 300
			elif _fase == "aberta" and agora - _ultimo_ping >= PING_MS:
				_ultimo_ping = agora
				_plugin.call("escrever", "PING")


func _receber(linha: String) -> void:
	if linha == "":
		return
	if linha.begins_with("PONG") or linha.begins_with("OLA"):
		var novo := linha.substr(linha.find(":") + 1) if ":" in linha else linha
		if novo != firmware:
			firmware = novo
			_set_status("LEDs: Arduino conectado (%s)" % firmware)
		return
	var cmd := linha.to_upper()
	if COMANDOS_DE_ENTRADA.has(cmd):
		Controles.injetar(COMANDOS_DE_ENTRADA[cmd])


func _procurar(agora: int) -> void:
	var lista := str(_plugin.call("listar"))
	var com_permissao := []
	var sem_permissao := []
	for linha in lista.split("\n", false):
		var p: PoolStringArray = linha.split("|")
		if p.size() < 4:
			continue
		if agora - int(_falhou.get(p[0], -100000)) < 15000:
			continue
		if p[3] == "1":
			com_permissao.append(p[0])
		else:
			sem_permissao.append([p[0], p[1]])
	if not com_permissao.empty():
		_fase = "abrindo"
		_desde = agora
		_set_status("LEDs: abrindo o USB...")
		_plugin.call("abrir", com_permissao[0], BAUD)
		return
	if not sem_permissao.empty():
		_pedir_permissao(sem_permissao[0][0], sem_permissao[0][1])
		return
	_set_status("LEDs: Arduino não encontrado no USB")


func _pedir_permissao(nome: String, chave: String) -> void:
	if bool(_plugin.call("permissao_pendente")):
		return
	var ja := _ja_pediu(chave)
	if _pedir_agora:
		_pedir_agora = false
	elif ja or not janelas_ok:
		_set_status("LEDs: Arduino sem permissão do Android (menu > TESTAR LEDS pede de novo)" if ja else "LEDs: Arduino no USB, aguardando a abertura para pedir permissão")
		return
	_marcar_pedido(chave)
	_set_status("LEDs: aceite a janela do Android (marque \"Usar por padrão\")")
	emit_signal("janela_android", DICA_USB)
	get_tree().create_timer(0.6).connect("timeout", self, "_abrir_janela", [nome])
	get_tree().create_timer(12.0).connect("timeout", self, "emit_signal", ["janela_android", ""])


func _abrir_janela(nome: String) -> void:
	if _plugin != null:
		_plugin.call("pedir_permissao", nome)


## O operador pediu (menu): pede a permissão de novo, mesmo já tendo pedido.
func pedir_permissao_agora() -> void:
	_pedir_agora = true
	_ultima_procura = -100000
	_falhou.clear()


func _ja_pediu(chave: String) -> bool:
	var c := ConfigFile.new()
	return c.load(PERMISSOES) == OK and c.has_section_key("pedidos", chave.replace(":", "_"))


func _marcar_pedido(chave: String) -> void:
	var c := ConfigFile.new()
	c.load(PERMISSOES)
	c.set_value("pedidos", chave.replace(":", "_"), true)
	c.save(PERMISSOES)


func _falha(motivo: String) -> void:
	_set_status("LEDs: não abriu o Arduino (%s)" % motivo)
	_plugin.call("fechar")
	_fase = "procurando"
	conectado = false


func _perdeu() -> void:
	_set_status("LEDs: Arduino desconectado")
	_plugin.call("fechar")
	_fase = "procurando"
	conectado = false
	firmware = ""


func _set_status(s: String) -> void:
	if s != status:
		status = s
		emit_signal("mudou")
