extends "res://scripts/tela_base.gd"

## CONFIGURAÇÃO DO OPERADOR (segurar SELECT 4 s na abertura, R2 da Zero
## Delay, MENU / VOLTAR / seta do controle remoto da TV Box, ou 9/F10 no
## PC). SELECT passa para o próximo item, START muda o valor / executa.
## CONTROLE REMOTO DA TV BOX (no PC, o teclado): CIMA/BAIXO escolhem,
## ESQUERDA/DIREITA mudam o valor, OK (= START) muda / executa e VOLTAR
## (Esc) salva e sai.
## As mudanças só valem em SALVAR E SAIR (ou VOLTAR); SAIR SEM SALVAR
## desfaz tudo.

var _itens: Array = []          # [{id, nome, linha (Panel), valor (Label)}]
var _sel := 0
var _cursor: Panel
var _rolagem: Control
var _rodape: Label
var _confirma: Control
var _confirma_txt: Label
var _confirmando := ""
var _sinais := 0
var _t := 0.0
var _teste_leds := false
var _de := "abertura"

# cópia de trabalho dos ajustes
var c := {}

const VOLUMES := [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
const ITENS := [
	["tempo_1", "TEMPO DA FASE 1"],
	["tempo_2", "TEMPO DA FASE 2"],
	["tempo_3", "TEMPO DA FINAL"],
	["meta_1", "META DA FASE 1"],
	["meta_2", "META DA FASE 2"],
	["modo", "MODO"],
	["arcade", "PONTUAÇÃO"],
	["ouro", "BOLA DE OURO"],
	["trava", "TRAVA DO SENSOR"],
	["janela", "TEMPO DA SEQUÊNCIA"],
	["musica", "VOLUME DA MÚSICA"],
	["efeitos", "VOLUME DOS EFEITOS"],
	["giro", "GIRO DA TELA"],
	["qualidade", "QUALIDADE DA IMAGEM"],
	["apresentacao", "APRESENTAÇÃO NA ESPERA"],
	["fps", "MOSTRAR DESEMPENHO"],
	["leds", "LEDS (ARDUINO)"],
	["porta", "PORTA DOS LEDS (WINDOWS)"],
	["testar_leds", "TESTAR LEDS / PEDIR USB"],
	["botoes", "BOTÕES DA PLACA (ASSISTENTE)"],
	["fichas", "ZERAR FICHAS"],
	["recorde", "ZERAR RECORDE"],
	["salvar", "SALVAR E SAIR"],
	["voltar", "SAIR SEM SALVAR"],
	["fechar", "FECHAR O JOGO (ANDROID)"],
]
## os itens que executam (OK / START); os outros têm valor (ESQUERDA/DIREITA)
const ACOES := ["testar_leds", "botoes", "fichas", "recorde", "salvar", "voltar", "fechar"]


func _ready() -> void:
	var fundo := ColorRect.new()
	fundo.color = Color(0.02, 0.012, 0.03)
	fundo.rect_size = Vector2(LARGURA, ALTURA)
	add_child(fundo)
	var p := Arte.painel(Arte.LARANJA, 0.9, 36, 3, 24)
	pos(p, 40, 40, 1000, 1840)
	add_child(p)
	var titulo := Arte.texto("CONFIGURAÇÃO", 70, Color(1, 1, 1), 8, Arte.LARANJA)
	pos(titulo, 40, 60, 1000, 90)
	add_child(titulo)
	var tempo := Arte.texto("", 36, Arte.LARANJA_CLARO, 4, Color(0, 0, 0))
	tempo.name = "Tempo"
	pos(tempo, 40, 150, 1000, 50)
	add_child(tempo)
	_cursor = Panel.new()
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.add_stylebox_override("panel", Arte.estilo_neon(Arte.LARANJA, 0.5, 16, 3, 18, 0.25))
	add_child(_cursor)
	_rolagem = Control.new()
	_rolagem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rolagem)
	var y := 214.0
	for item in ITENS:
		var nome = Arte.texto(item[1], 30, Color(1, 1, 1), 3, Color(0, 0, 0), Label.ALIGN_LEFT)
		pos(nome, 90, y, 560, 56)
		_rolagem.add_child(nome)
		var valor = Arte.texto("", 30, Arte.LARANJA_CLARO, 3, Color(0, 0, 0), Label.ALIGN_RIGHT)
		pos(valor, 560, y, 420, 56)
		_rolagem.add_child(valor)
		_itens.append({"id": item[0], "nome": nome, "valor": valor, "y": y})
		y += 57.0
	_rodape = Arte.texto("", 24, Color(0.8, 0.85, 0.95), 3, Color(0, 0, 0))
	_rodape.autowrap = true
	pos(_rodape, 70, 1648, 940, 222)
	add_child(_rodape)
	_confirma = Control.new()
	_confirma.rect_size = Vector2(LARGURA, ALTURA)
	_confirma.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirma.visible = false
	add_child(_confirma)
	var esc := ColorRect.new()
	esc.color = Color(0, 0, 0, 0.82)
	esc.rect_size = Vector2(LARGURA, ALTURA)
	_confirma.add_child(esc)
	var pc := Arte.painel(Arte.VERMELHO_ALERTA, 0.95, 36, 3, 30)
	pos(pc, 120, 700, 840, 480)
	_confirma.add_child(pc)
	_confirma_txt = Arte.texto("", 40, Color(1, 1, 1), 5, Arte.VERMELHO_ALERTA)
	_confirma_txt.autowrap = true
	pos(_confirma_txt, 150, 730, 780, 420)
	_confirma.add_child(_confirma_txt)


func entrar(dados := {}) -> void:
	.entrar(dados)
	_de = str(dados.get("de", "abertura"))
	c = {
		"tempo": Ajustes.tempo_fase.duplicate(), "meta": Ajustes.meta_fase.duplicate(), "modo": Ajustes.modo_credito, "arcade": Ajustes.modo_arcade,
		"ouro": Ajustes.bola_de_ouro, "trava": Ajustes.trava_sensor, "janela": Ajustes.janela_combo,
		"musica": Ajustes.vol_musica, "efeitos": Ajustes.vol_efeitos, "giro": Tela.giro_pedido(),
		"qualidade": Ajustes.qualidade, "apresentacao": Ajustes.apresentacao, "fps": Ajustes.mostrar_fps,
		"leds": Ajustes.leds, "porta": Ajustes.porta_com,
	}
	_sel = 0
	_sinais = 0
	_confirmando = ""
	_confirma.visible = false
	Sons.musica("")
	Arduino.led("OFF")
	Arduino.janelas_ok = true
	_atualizar()
	_mover_cursor(true)


func sair() -> void:
	.sair()
	Arduino.janelas_ok = false


func _txt(v: bool) -> String:
	return "SIM" if v else "NÃO"


func _atualizar() -> void:
	var tp: Array = c["tempo"]
	var mt: Array = c["meta"]
	get_node("Tempo").text = "PARTIDA: %d + %d + %d s   •   METAS %d / %d" % [tp[0], tp[1], tp[2], mt[0], mt[1]]
	for it in _itens:
		var v = ""
		match it["id"]:
			"tempo_1", "tempo_2", "tempo_3":
				v = "%d s" % int(c["tempo"][int(it["id"].right(6)) - 1])
			"meta_1", "meta_2":
				v = "%d PONTOS" % int(c["meta"][int(it["id"].right(5)) - 1])
			"modo":
				v = "CRÉDITO (1 FICHA POR PARTIDA)" if c["modo"] else "LIVRE"
			"arcade":
				v = "MULTIPLICADOR (x2 x3 x4)" if c["arcade"] else "CLÁSSICA (2 POR CESTA)"
			"ouro":
				v = _txt(c["ouro"]) if c["arcade"] else "(SÓ COM MULTIPLICADOR)"
			"trava":
				v = ("%.1f s" % float(c["trava"])).replace(".", ",")
			"janela":
				v = ("%.1f s" % float(c["janela"])).replace(".", ",")
			"musica":
				v = "%d%%" % int(round(float(c["musica"]) * 100))
			"efeitos":
				v = "%d%%" % int(round(float(c["efeitos"]) * 100))
			"giro":
				var nomes := ["TOPO À DIREITA", "SEM GIRO", "TOPO À ESQUERDA"]
				if int(c["giro"]) == Tela.AUTO:
					v = "AUTOMÁTICO (%s)" % nomes[Tela.giro + 1]
				else:
					v = nomes[int(c["giro"]) + 1]
			"qualidade":
				v = Ajustes.QUALIDADES[int(c["qualidade"])]
				if int(c["qualidade"]) == 0:
					v += " (%d)" % int(round(1080.0 * Ajustes.escala_auto))
			"apresentacao":
				v = _txt(c["apresentacao"])
			"fps":
				v = _txt(c["fps"])
			"leds":
				v = "LIGADOS" if c["leds"] else "DESLIGADOS"
			"porta":
				v = str(c["porta"]) if OS.get_name() == "Windows" else "(SÓ NO PC)"
			"testar_leds":
				v = "CONECTADO" if Arduino.conectado else "SEM ARDUINO"
			"botoes":
				v = "GRAVADO" if Controles.mapeamento_gravado else "PADRÃO"
			"fichas":
				v = "%d FICHAS" % Ajustes.creditos
			"recorde":
				v = "%d PONTOS" % Ajustes.recorde
		it["valor"].text = v
	_rodape.text = "CONTROLE DA TV BOX: CIMA/BAIXO ESCOLHE  •  ESQUERDA/DIREITA MUDA  •  OK CONFIRMA  •  VOLTAR SALVA E SAI\n%s\nSENSOR DA CESTA: %d SINAIS (jogue uma bola para testar)\nSTART: %s   •   SELECT: %s   •   CESTA: %s   •   FICHA: %s\nPARTIDAS: %d   •   CESTAS: %d   •   Slam Arena %s" % [
		Arduino.status, _sinais, Controles.texto_de("input_start"), Controles.texto_de("input_select"),
		Controles.texto_de("input_cesta"), Controles.texto_de("input_credito"), Ajustes.partidas_total, Ajustes.cestas_total, Ajustes.VERSAO]


func _mover_cursor(direto := false) -> void:
	var it: Dictionary = _itens[_sel]
	var alvo := Vector2(66, it["y"] - 1)
	_cursor.rect_size = Vector2(948, 58)
	if direto:
		_cursor.rect_position = alvo
	else:
		var tw := create_tween()
		tw.tween_property(_cursor, "rect_position", alvo, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for i in _itens.size():
		_itens[i]["nome"].add_color_override("font_color", Color(1, 1, 1) if i == _sel else Color(0.75, 0.75, 0.8))


func _process(delta: float) -> void:
	_t += delta
	_cursor.modulate.a = 0.75 + 0.25 * sin(_t * 6.0)
	if int(_t * 2.0) != int((_t - delta) * 2.0):
		_atualizar()


const CONFIRMA := "\n\nSTART OU OK CONFIRMA\nSELECT OU VOLTAR CANCELA"


## START / OK: executa o item (ou muda o valor para o próximo).
func _executar() -> void:
	var id: String = _itens[_sel]["id"]
	if not id in ACOES:
		_mudar(1)
		return
	Sons.tocar("cursor", -6.0)
	match id:
		"testar_leds":
			_testar_leds()
		"botoes":
			ir("botoes", {"de": "config"})
			return
		"fichas":
			_perguntar("fichas", "ZERAR AS FICHAS?\n\n%d fichas pagas vão sumir." % Ajustes.creditos + CONFIRMA)
		"recorde":
			_perguntar("recorde", "ZERAR O RECORDE?\n\nO recorde (%d) e o ranking de hoje vão sumir." % Ajustes.recorde + CONFIRMA)
		"fechar":
			_perguntar("fechar", "FECHAR O JOGO?\n\nOs ajustes são salvos e a TV Box volta para o Android." + CONFIRMA)
		"salvar":
			_salvar()
			return
		"voltar":
			ir(_de if _de != "config" else "abertura")
			return
	_atualizar()
	pop(_itens[_sel]["valor"], 1.12, 0.18)


## Valor anterior (-1) ou próximo (1) do item; dá a volta na lista.
func _mudar(passo: int) -> void:
	var id: String = _itens[_sel]["id"]
	if id in ACOES:
		return
	Sons.tocar("cursor", -6.0)
	match id:
		"tempo_1", "tempo_2", "tempo_3":
			var i := int(id.right(6)) - 1
			c["tempo"][i] = int(_proximo(Ajustes.TEMPOS_FASE[i], float(c["tempo"][i]), passo))
		"meta_1", "meta_2":
			var i := int(id.right(5)) - 1
			c["meta"][i] = int(_proximo(Ajustes.METAS_FASE[i], float(c["meta"][i]), passo))
		"modo":
			c["modo"] = not c["modo"]
		"arcade":
			c["arcade"] = not c["arcade"]
		"ouro":
			c["ouro"] = not c["ouro"]
		"trava":
			c["trava"] = _proximo(Ajustes.TRAVAS, float(c["trava"]), passo)
		"janela":
			c["janela"] = _proximo(Ajustes.JANELAS_COMBO, float(c["janela"]), passo)
		"musica":
			c["musica"] = _proximo(VOLUMES, float(c["musica"]), passo)
		"efeitos":
			c["efeitos"] = _proximo(VOLUMES, float(c["efeitos"]), passo)
			Sons.tocar("combo_3", linear2db(max(0.01, c["efeitos"])) - linear2db(max(0.01, Ajustes.vol_efeitos)))
		"giro":
			# automático -> topo à esquerda -> topo à direita -> sem giro
			var ordem := [Tela.AUTO, 1, -1, 0]
			c["giro"] = ordem[(ordem.find(int(c["giro"])) + passo + ordem.size()) % ordem.size()]
		"qualidade":
			var n := Ajustes.QUALIDADES.size()
			c["qualidade"] = (int(c["qualidade"]) + passo + n) % n
		"apresentacao":
			c["apresentacao"] = not c["apresentacao"]
		"fps":
			c["fps"] = not c["fps"]
		"leds":
			c["leds"] = not c["leds"]
		"porta":
			var n := int(str(c["porta"]).replace("COM", ""))
			c["porta"] = "COM%d" % ((n - 1 + passo + 20) % 20 + 1)
	_atualizar()
	pop(_itens[_sel]["valor"], 1.12, 0.18)


func _andar(passo: int) -> void:
	_sel = (_sel + passo + _itens.size()) % _itens.size()
	_mover_cursor()
	Sons.tocar("cursor", -10.0)


static func _proximo(lista: Array, atual: float, passo := 1) -> float:
	for i in lista.size():
		if abs(float(lista[i]) - atual) < 0.01:
			return float(lista[(i + passo + lista.size()) % lista.size()])
	return float(lista[0])


func _perguntar(qual: String, texto: String) -> void:
	_confirmando = qual
	_confirma_txt.text = texto
	_confirma.visible = true


func _responder(sim: bool) -> void:
	if sim and _confirmando == "fechar":
		# salva e fecha: a TV Box volta para o Android (os LEDs apagam)
		_gravar()
		Arduino.apagar_e_fechar()
		get_tree().quit()
		return
	if sim:
		if _confirmando == "recorde":
			Ajustes.zerar_recorde()
		elif _confirmando == "fichas":
			Ajustes.creditos = 0
			Ajustes.salvar_creditos()
		Sons.tocar("quebra")
	_confirmando = ""
	_confirma.visible = false
	_atualizar()


func _testar_leds() -> void:
	if _teste_leds:
		return
	_teste_leds = true
	Arduino.pedir_permissao_agora()
	var s := sessao
	for cmd in ["ATTRACT", "SELECT4", "HIT", "RECORD", "BOOST", "OFF"]:
		Arduino.led(cmd)
		yield(get_tree().create_timer(1.2), "timeout")
		if not vale(s):
			break
	_teste_leds = false


func _salvar() -> void:
	_gravar()
	Sons.tocar("selecao")
	ir("abertura")


func _gravar() -> void:
	var giro_mudou := int(c["giro"]) != Tela.giro_pedido()
	Ajustes.tempo_fase = c["tempo"].duplicate()
	Ajustes.meta_fase = c["meta"].duplicate()
	Ajustes.modo_credito = bool(c["modo"])
	Ajustes.modo_arcade = bool(c["arcade"])
	Ajustes.bola_de_ouro = bool(c["ouro"])
	Ajustes.trava_sensor = float(c["trava"])
	Ajustes.janela_combo = float(c["janela"])
	Ajustes.vol_musica = float(c["musica"])
	Ajustes.vol_efeitos = float(c["efeitos"])
	Ajustes.giro = int(c["giro"])
	Ajustes.qualidade = int(c["qualidade"])
	Ajustes.apresentacao = bool(c["apresentacao"])
	Ajustes.mostrar_fps = bool(c["fps"])
	var porta_mudou: bool = str(c["porta"]) != Ajustes.porta_com or bool(c["leds"]) != Ajustes.leds
	Ajustes.leds = bool(c["leds"])
	Ajustes.porta_com = str(c["porta"])
	Ajustes.salvar()
	if giro_mudou:
		Tela.definir_giro(Ajustes.giro)
	Tela.definir_escala(Ajustes.escala_tela())
	Sons.reaplicar_volume()
	if porta_mudou:
		Arduino.reiniciar_ponte_windows()


func _unhandled_input(event: InputEvent) -> void:
	if not ativo:
		return
	if Controles.cesta(event):
		_sinais += 1
		Sons.tocar("tique")
		_atualizar()
		return
	if _confirmando != "":
		if Controles.start(event):
			_responder(true)
		elif Controles.select(event) or Controles.voltou(event):
			_responder(false)
		return
	if Controles.select(event):
		_andar(1)
		return
	if Controles.start(event):
		# (o OK do controle remoto é o Enter: START)
		_executar()
		return
	# controle remoto da TV Box (segurar CIMA/BAIXO anda direto)
	if Controles.tecla(event, [KEY_DOWN], true):
		_andar(1)
	elif Controles.tecla(event, [KEY_UP], true):
		_andar(-1)
	elif Controles.tecla(event, [KEY_RIGHT]):
		_mudar(1)
	elif Controles.tecla(event, [KEY_LEFT]):
		_mudar(-1)
	elif Controles.voltou(event):
		_salvar()
