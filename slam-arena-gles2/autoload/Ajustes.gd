extends Node

## AJUSTES DO OPERADOR, RECORDE E ESTATÍSTICAS DO DIA.
##
##   user://slam_ajustes.cfg   o que o operador escolhe no menu (CONFIG)
##   user://slam_recordes.cfg  recorde da arena, ranking do dia, contadores
##   user://slam_creditos.cfg  fichas já pagas (não se perdem se a luz cair)
##
## Tudo é lido UMA vez ao abrir e gravado só quando muda, numa linha de
## trabalho separada (gravar na memória da TV Box pode levar 20-80 ms: no
## meio da partida seria um tranco na tela).

signal mudou

const VERSAO := "1.0-gles2"

const ARQ_AJUSTES := "user://slam_ajustes.cfg"
const ARQ_RECORDES := "user://slam_recordes.cfg"
const ARQ_CREDITOS := "user://slam_creditos.cfg"

const TEMPO_MIN := 10
const TEMPO_MAX := 600
const TRAVAS := [0.3, 0.5, 0.7, 0.9, 1.2, 1.5, 2.0]
const JANELAS_COMBO := [2.5, 3.0, 4.0, 5.0, 6.0]
const QUALIDADES := ["AUTOMÁTICA", "MÁXIMA (1080)", "MÉDIA (900)", "LEVE (720)"]
const ESCALAS := [1.0, 1.0, 0.8333, 0.6667]

# ------------------------------------------------------------ do operador
var tempo_turno := 60              # segundos de cada jogador
var modo_credito := false          # LIVRE ou CRÉDITO (1 ficha por jogador)
var modo_arcade := true            # combo multiplica + bola de ouro; falso = 1 ponto por cesta
var bola_de_ouro := true
var trava_sensor := 0.7            # tempo mínimo entre duas cestas (s)
var janela_combo := 4.0            # tempo máximo entre cestas para manter o combo (s)
var vol_musica := 0.8
var vol_efeitos := 1.0
var giro := 99                     # 99 = o padrão do aparelho; -1 / 0 / 1
var qualidade := 0                 # índice de QUALIDADES
var escala_auto := 1.0             # o que a qualidade automática escolheu
var mostrar_fps := false
var porta_com := "COM5"            # só no Windows (LEDs pela ponte PowerShell)
var leds := true
var apresentacao := true           # a apresentação animada no ciclo de espera

# ------------------------------------------------------------- recordes
var recorde := 0
var recorde_data := ""
var ranking_dia: Array = []        # [{pontos, cor, hora, cestas}] (5 melhores de hoje)
var dia := ""
var partidas_hoje := 0
var cestas_hoje := 0
var cestas_total := 0
var partidas_total := 0

var creditos := 0


var _fila: Array = []
var _linha: Thread


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	carregar()


## Grava em segundo plano (a fila é entregue a uma linha de trabalho).
func _gravar(cfg: ConfigFile, caminho: String) -> void:
	for item in _fila:
		if item[1] == caminho:
			_fila.erase(item)
			break
	_fila.append([cfg, caminho])


func _process(_delta: float) -> void:
	if _fila.empty():
		return
	if _linha != null:
		if _linha.is_alive():
			return
		_linha.wait_to_finish()
	var lote := _fila.duplicate()
	_fila.clear()
	_linha = Thread.new()
	_linha.start(self, "_trabalho", lote)


func _trabalho(lote: Array) -> void:
	for item in lote:
		item[0].save(item[1])


## Ao fechar: termina de gravar tudo.
func _exit_tree() -> void:
	if _linha != null:
		_linha.wait_to_finish()
		_linha = null
	for item in _fila:
		item[0].save(item[1])
	_fila.clear()


func carregar() -> void:
	var c := ConfigFile.new()
	if c.load(ARQ_AJUSTES) == OK:
		tempo_turno = int(clamp(int(c.get_value("jogo", "tempo_turno", tempo_turno)), TEMPO_MIN, TEMPO_MAX))
		modo_credito = bool(c.get_value("jogo", "modo_credito", modo_credito))
		modo_arcade = bool(c.get_value("jogo", "modo_arcade", modo_arcade))
		bola_de_ouro = bool(c.get_value("jogo", "bola_de_ouro", bola_de_ouro))
		trava_sensor = float(c.get_value("jogo", "trava_sensor", trava_sensor))
		janela_combo = float(c.get_value("jogo", "janela_combo", janela_combo))
		vol_musica = clamp(float(c.get_value("som", "musica", vol_musica)), 0.0, 1.0)
		vol_efeitos = clamp(float(c.get_value("som", "efeitos", vol_efeitos)), 0.0, 1.0)
		giro = int(c.get_value("tela", "giro", giro))
		qualidade = int(clamp(int(c.get_value("tela", "qualidade", qualidade)), 0, QUALIDADES.size() - 1))
		escala_auto = clamp(float(c.get_value("tela", "escala_auto", escala_auto)), 0.6667, 1.0)
		mostrar_fps = bool(c.get_value("tela", "mostrar_fps", mostrar_fps))
		apresentacao = bool(c.get_value("tela", "apresentacao", apresentacao))
		porta_com = str(c.get_value("leds", "porta_com", porta_com))
		leds = bool(c.get_value("leds", "ligados", leds))
	var r := ConfigFile.new()
	if r.load(ARQ_RECORDES) == OK:
		recorde = int(r.get_value("recorde", "pontos", 0))
		recorde_data = str(r.get_value("recorde", "data", ""))
		dia = str(r.get_value("hoje", "dia", ""))
		ranking_dia = r.get_value("hoje", "ranking", [])
		partidas_hoje = int(r.get_value("hoje", "partidas", 0))
		cestas_hoje = int(r.get_value("hoje", "cestas", 0))
		cestas_total = int(r.get_value("total", "cestas", 0))
		partidas_total = int(r.get_value("total", "partidas", 0))
	var f := ConfigFile.new()
	if f.load(ARQ_CREDITOS) == OK:
		creditos = int(max(0, int(f.get_value("fichas", "creditos", 0))))
	_virar_o_dia()


func salvar() -> void:
	var c := ConfigFile.new()
	c.set_value("jogo", "tempo_turno", tempo_turno)
	c.set_value("jogo", "modo_credito", modo_credito)
	c.set_value("jogo", "modo_arcade", modo_arcade)
	c.set_value("jogo", "bola_de_ouro", bola_de_ouro)
	c.set_value("jogo", "trava_sensor", trava_sensor)
	c.set_value("jogo", "janela_combo", janela_combo)
	c.set_value("som", "musica", vol_musica)
	c.set_value("som", "efeitos", vol_efeitos)
	c.set_value("tela", "giro", giro)
	c.set_value("tela", "qualidade", qualidade)
	c.set_value("tela", "escala_auto", escala_auto)
	c.set_value("tela", "mostrar_fps", mostrar_fps)
	c.set_value("tela", "apresentacao", apresentacao)
	c.set_value("leds", "porta_com", porta_com)
	c.set_value("leds", "ligados", leds)
	_gravar(c, ARQ_AJUSTES)
	emit_signal("mudou")


func salvar_recordes() -> void:
	var r := ConfigFile.new()
	r.set_value("recorde", "pontos", recorde)
	r.set_value("recorde", "data", recorde_data)
	r.set_value("hoje", "dia", dia)
	r.set_value("hoje", "ranking", ranking_dia)
	r.set_value("hoje", "partidas", partidas_hoje)
	r.set_value("hoje", "cestas", cestas_hoje)
	r.set_value("total", "cestas", cestas_total)
	r.set_value("total", "partidas", partidas_total)
	_gravar(r, ARQ_RECORDES)


func salvar_creditos() -> void:
	var f := ConfigFile.new()
	f.set_value("fichas", "creditos", creditos)
	_gravar(f, ARQ_CREDITOS)


# ---------------------------------------------------------------- fichas
func adicionar_credito(n := 1) -> void:
	creditos = int(min(99, creditos + n))
	salvar_creditos()
	emit_signal("mudou")


## Quantos jogadores podem entrar agora (no modo LIVRE, sempre 4).
func jogadores_liberados() -> int:
	if not modo_credito:
		return 4
	return int(min(4, creditos))


func gastar_creditos(n: int) -> void:
	if not modo_credito:
		return
	creditos = int(max(0, creditos - n))
	salvar_creditos()
	emit_signal("mudou")


# --------------------------------------------------------------- recordes
static func hoje() -> String:
	var d := OS.get_date()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


func _virar_o_dia() -> void:
	var h := hoje()
	if dia != h:
		dia = h
		ranking_dia = []
		partidas_hoje = 0
		cestas_hoje = 0


## Registra um turno terminado. Devolve a posição no ranking do dia (1..5)
## ou 0 se não entrou.
func registrar_turno(pontos: int, cestas: int, cor: int) -> int:
	_virar_o_dia()
	cestas_hoje += cestas
	cestas_total += cestas
	var t := OS.get_time()
	var item := {"pontos": pontos, "cestas": cestas, "cor": cor, "hora": "%02d:%02d" % [t.hour, t.minute]}
	var pos := 0
	if pontos > 0:
		var i := 0
		while i < ranking_dia.size() and int(ranking_dia[i]["pontos"]) >= pontos:
			i += 1
		if i < 5:
			ranking_dia.insert(i, item)
			pos = i + 1
			while ranking_dia.size() > 5:
				ranking_dia.pop_back()
	return pos


func registrar_partida() -> void:
	_virar_o_dia()
	partidas_hoje += 1
	partidas_total += 1
	salvar_recordes()


func melhor_hoje() -> int:
	_virar_o_dia()
	return int(ranking_dia[0]["pontos"]) if not ranking_dia.empty() else 0


## Bateu o recorde da arena? Grava na hora (a luz pode cair no meio).
func tentar_recorde(pontos: int) -> bool:
	if pontos <= recorde:
		return false
	recorde = pontos
	recorde_data = hoje()
	salvar_recordes()
	return true


func zerar_recorde() -> void:
	recorde = 0
	recorde_data = ""
	ranking_dia = []
	salvar_recordes()


func escala_tela() -> float:
	if qualidade == 0:
		return escala_auto
	return float(ESCALAS[qualidade])


static func tempo_texto(segundos: int) -> String:
	return "%02d:%02d" % [segundos / 60, segundos % 60]
