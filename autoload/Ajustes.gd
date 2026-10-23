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

const VERSAO := "1.9.1-gles2"

const ARQ_AJUSTES := "user://slam_ajustes.cfg"
const ARQ_RECORDES := "user://slam_recordes.cfg"
const ARQ_CREDITOS := "user://slam_creditos.cfg"

## As 3 fases: tempo de cada uma e a META (pontos a fazer NA fase; o
## SCORE PASS da tela mostra o total que precisa ter: pontos com que a fase
## começou + a meta). A FINAL não tem meta: vale tudo.
const TEMPOS_FASE := [[30, 35, 40, 45, 50, 60], [25, 30, 35, 40, 45, 50], [20, 25, 30, 35, 40, 45]]
const METAS_FASE := [[10, 15, 20, 25, 30, 35, 40, 50], [15, 20, 25, 30, 35, 40, 50, 60]]
const NOMES_FASE := ["FASE 1", "FASE 2", "FINAL"]
const TRAVAS := [0.3, 0.5, 0.7, 0.9, 1.2, 1.5, 2.0]
const JANELAS_COMBO := [2.5, 3.0, 4.0, 5.0, 6.0]
const QUALIDADES := ["AUTOMÁTICA", "MÁXIMA (1080)", "MÉDIA (900)", "LEVE (720)"]
const ESCALAS := [1.0, 1.0, 0.8333, 0.6667]

# ------------------------------------------------------------ do operador
var tempo_fase := [40, 35, 30]     # segundos de cada fase (FASE 1, FASE 2, FINAL)
var meta_fase := [20, 30]          # pontos a fazer na FASE 1 e na FASE 2
var modo_credito := false          # LIVRE ou CRÉDITO (1 ficha por partida)
var modo_arcade := true            # combo multiplica + bola de ouro; falso = 2 pontos por cesta
var bola_de_ouro := true
var trava_sensor := 0.9            # tempo mínimo entre duas cestas (s)
var janela_combo := 4.0            # tempo máximo entre cestas para manter o combo (s)
var vol_musica := 0.8
var vol_efeitos := 1.0
var giro := 99                     # 99 = automático (Tela.AUTO); -1 / 0 / 1
var qualidade := 0                 # índice de QUALIDADES
var efeitos_leves := false         # a qualidade automática desligou os efeitos extras
var mostrar_fps := false
var porta_com := "COM5"            # só no Windows (LEDs pela ponte PowerShell)
var leds := true
var apresentacao := true           # a apresentação animada no ciclo de espera

# ------------------------------------------------------------- recordes
var recorde := 0
var recorde_data := ""
var ranking_dia: Array = []        # [{pontos, cestas, fase, hora}] (5 melhores de hoje; fase 1..3)
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
		for i in 3:
			tempo_fase[i] = _da_lista(TEMPOS_FASE[i], int(c.get_value("fases", "tempo_%d" % (i + 1), tempo_fase[i])))
		for i in 2:
			meta_fase[i] = _da_lista(METAS_FASE[i], int(c.get_value("fases", "meta_%d" % (i + 1), meta_fase[i])))
		modo_credito = bool(c.get_value("jogo", "modo_credito", modo_credito))
		modo_arcade = bool(c.get_value("jogo", "modo_arcade", modo_arcade))
		bola_de_ouro = bool(c.get_value("jogo", "bola_de_ouro", bola_de_ouro))
		trava_sensor = float(c.get_value("jogo", "trava_sensor", trava_sensor))
		# 1.9.1: a trava passa a ser de no mínimo 0,9 s (a mesma bola girando
		# no aro não marca duas cestas); o que as versões anteriores gravaram
		# com menos sobe para 0,9 s
		if int(c.get_value("jogo", "versao_trava", 1)) < 2:
			trava_sensor = max(trava_sensor, 0.9)
		janela_combo = float(c.get_value("jogo", "janela_combo", janela_combo))
		vol_musica = clamp(float(c.get_value("som", "musica", vol_musica)), 0.0, 1.0)
		vol_efeitos = clamp(float(c.get_value("som", "efeitos", vol_efeitos)), 0.0, 1.0)
		giro = int(c.get_value("tela", "giro", giro))
		qualidade = int(clamp(int(c.get_value("tela", "qualidade", qualidade)), 0, QUALIDADES.size() - 1))
		efeitos_leves = bool(c.get_value("tela", "efeitos_leves", efeitos_leves))
		# 1.6: a qualidade automática não baixa mais a resolução (fica sempre
		# em 1080, nítida); o que as versões anteriores gravaram é medido de novo
		if int(c.get_value("tela", "versao_escala", 1)) < 3:
			efeitos_leves = false
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
		if r.get_value("hoje", "versao", 1) < 2:
			# ranking do jogo antigo (turnos de 60 s): outra conta, recomeça
			ranking_dia = []
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
	for i in 3:
		c.set_value("fases", "tempo_%d" % (i + 1), tempo_fase[i])
	for i in 2:
		c.set_value("fases", "meta_%d" % (i + 1), meta_fase[i])
	c.set_value("jogo", "modo_credito", modo_credito)
	c.set_value("jogo", "modo_arcade", modo_arcade)
	c.set_value("jogo", "bola_de_ouro", bola_de_ouro)
	c.set_value("jogo", "trava_sensor", trava_sensor)
	c.set_value("jogo", "versao_trava", 2)
	c.set_value("jogo", "janela_combo", janela_combo)
	c.set_value("som", "musica", vol_musica)
	c.set_value("som", "efeitos", vol_efeitos)
	c.set_value("tela", "giro", giro)
	c.set_value("tela", "qualidade", qualidade)
	c.set_value("tela", "efeitos_leves", efeitos_leves)
	c.set_value("tela", "versao_escala", 3)
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
	r.set_value("hoje", "versao", 2)
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


## Dá para começar uma partida agora? (LIVRE: sempre; CRÉDITO: 1 ficha)
func pode_jogar() -> bool:
	return not modo_credito or creditos >= 1


func gastar_credito() -> void:
	if not modo_credito:
		return
	creditos = int(max(0, creditos - 1))
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


## As 3 fases desta partida: [{tempo, meta, nome}] (meta 0 = FINAL).
func fases() -> Array:
	var lista := []
	for i in 3:
		lista.append({"tempo": int(tempo_fase[i]), "meta": int(meta_fase[i]) if i < 2 else 0, "nome": NOMES_FASE[i]})
	return lista


## Registra a partida terminada (fase = até onde chegou, 1..3). Devolve a
## posição no ranking do dia (1..5) ou 0 se não entrou.
func registrar_resultado(pontos: int, cestas: int, fase: int) -> int:
	_virar_o_dia()
	cestas_hoje += cestas
	cestas_total += cestas
	var t := OS.get_time()
	var item := {"pontos": pontos, "cestas": cestas, "fase": fase, "hora": "%02d:%02d" % [t.hour, t.minute]}
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
	salvar_recordes()
	return pos


## Uma partida começou (contadores do dia e do total).
func iniciar_partida() -> void:
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
	return float(ESCALAS[qualidade])


## Qualidade AUTOMÁTICA numa TV Box que não segurou 60 quadros: a imagem
## continua em 1080; saem os efeitos que mais pesam (holofotes, brilhos e
## rastros das bolas que caem).
func leves() -> bool:
	return qualidade == 0 and efeitos_leves


static func tempo_texto(segundos: int) -> String:
	return "%02d:%02d" % [segundos / 60, segundos % 60]


## O valor gravado, se for uma das opções; senão a opção mais perto.
static func _da_lista(lista: Array, v: int) -> int:
	var melhor: int = lista[0]
	for x in lista:
		if abs(int(x) - v) < abs(melhor - v):
			melhor = int(x)
	return melhor
