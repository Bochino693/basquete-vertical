extends Node2D

## O JOGADOR DA CAPA COMO PERSONAGEM 2D ARTICULADO: o boneco inteiro, feito
## da própria arte do pôster (tools/rig_jogador.py) em PEÇAS INTEIRAS E
## RÍGIDAS - pernas com o calção, tronco, cabeça, o braço da bola em duas
## partes (braço e antebraço com a mão) e a bola, o outro braço em duas
## partes - presas a ossos que giram nas juntas (cintura, pescoço,
## ombros, cotovelos, quadril). Nada é entortado: cada peça só gira e anda
## inteira, e as juntas têm sobra macia (não abrem nem aparecem). O corpo
## inteiro se move junto, a 60 quadros: a apresentação passa de uma POSE
## para outra (pose_entre) - a decolagem, a pose da capa, a enterrada.
##
## AS JUNTAS DO BRAÇO DA BOLA, pixel a pixel: o ombro SOBE quando o braço vai
## por cima (o braço passa por cima da cabeça, não atrás dela) e, para cada
## ângulo do ombro e do cotovelo, um REMENDO feito da arte (tools/
## rig_jogador.py: imagens/jogador_juntas.png e jogador_juntas_dados.gd)
## refaz a junção - o deltoide, a axila, o trapézio, a ponta e a dobra do
## cotovelo - com a luz da borda da arte seguindo a silhueta nova. Na pose
## da capa os remendos são vazios (a arte fica igualzinha).
##
## Coordenadas do pôster original (941 x 1672): na escala 1080/941, na
## origem da tela, a pose da capa fica exatamente onde está no pôster.
## Em volta, a AURA (o brilho azul de cada peça, que vai junto com ela) e um
## RASTRO de brilho das posições de antes (movimento rápido).

const Juntas = preload("res://scripts/fx/jogador_juntas_dados.gd")
const RASTRO := 2
const AURA_TODA := Vector2(58, 0)         # imagens/jogador_aura.png (o rastro)

# as juntas (tools/arte/jogador_pecas.txt)
const JUNTAS := {
	"cintura": Vector2(455, 545), "pescoco": Vector2(440, 305), "quadril": Vector2(400, 560),
	"ombro_e": Vector2(362, 298), "cotovelo_e": Vector2(218, 266),
	"ombro_d": Vector2(540, 398), "cotovelo_d": Vector2(603, 530),
	"bola": Vector2(190, 112),
}
# onde cada peça (e o brilho dela) fica no pôster
const PECAS := {
	"pernas": Rect2(136, 492, 439, 416), "braco_e": Rect2(195, 245, 213, 103),
	"bola": Rect2(82, 34, 197, 166), "antebraco_e": Rect2(99, 53, 139, 249),
	"tronco": Rect2(295, 244, 280, 354), "cabeca": Rect2(369, 169, 153, 159),
	"braco_d": Rect2(521, 371, 120, 197), "antebraco_d": Rect2(566, 493, 191, 214),
}
const BRILHOS := {
	"pernas": Vector2(75, 431), "braco_e": Vector2(134, 184),
	"antebraco_e": Vector2(38, -8), "tronco": Vector2(234, 183), "cabeca": Vector2(308, 108),
	"braco_d": Vector2(460, 310), "antebraco_d": Vector2(505, 432),
}

# AS POSES (graus; + = sentido do relógio na tela; 0 = a pose da capa)
const CAPA := {}
const DECOLAGEM := {"pernas": 10, "tronco": -8, "cabeca": -4, "ombro_e": -35, "cotovelo_e": 20, "ombro_d": 20, "cotovelo_d": 10}
const SUBINDO := {"pernas": 5, "tronco": -4, "cabeca": -2, "ombro_e": -18, "cotovelo_e": 10, "ombro_d": 10, "cotovelo_d": 5}
# a enterrada: o ombro sobe, o cotovelo vai alto, a bola passa POR CIMA da
# cabeça (que abaixa um pouco) e desce na FRENTE do rosto
const ENTERRADA := [
	{},
	{"pernas": -3, "tronco": 3, "cabeca": 3, "ombro_e": 32.5, "cotovelo_e": -24.5, "ombro_d": -8, "cotovelo_d": -4},
	{"pernas": -5, "tronco": 6, "cabeca": 5, "ombro_e": 67.5, "cotovelo_e": -34.5, "ombro_d": -15, "cotovelo_d": -7},
	{"pernas": -7, "tronco": 10, "cabeca": 7, "ombro_e": 92.5, "cotovelo_e": -24.5, "ombro_d": -22, "cotovelo_d": -9},
	{"pernas": -9, "tronco": 14, "cabeca": 8, "ombro_e": 112.5, "cotovelo_e": 0.5, "ombro_d": -28, "cotovelo_d": -11},
	{"pernas": -10, "tronco": 16, "cabeca": 8, "ombro_e": 122.5, "cotovelo_e": 10.5, "ombro_d": -32, "cotovelo_d": -13},
]
# pendurado no aro: o braço esticado para CIMA segurando, o corpo embaixo
const PENDURADO := {"pernas": 8, "tronco": 4, "cabeca": 5, "ombro_e": 105.5, "cotovelo_e": -32.5, "ombro_d": -10, "cotovelo_d": -4}
const OSSOS := ["pernas", "tronco", "cabeca", "ombro_e", "cotovelo_e", "ombro_d", "cotovelo_d"]

var luz := 1.0 setget _set_luz              # o brilho em volta (aura)
var rastro := 0.0                           # 0 sem rastro, 1 forte
var na_mao := true setget _set_na_mao

var _ossos := {}            # nome -> Node2D
var _bola: Sprite
var _rem_ombro: Sprite      # o remendo da junta do ombro (no tronco)
var _rem_cotovelo: Sprite   # o remendo do cotovelo (no braço)
var _auras := []            # sprites do brilho (um por peça)
var _auras_ossos := []      # [brilho, osso, posição no osso] (seguem o osso)
var _camada_aura: Node2D    # os brilhos, todos atrás do corpo inteiro
var _rastros := []          # sprites do brilho inteiro nas posições de antes
var _historico := []        # transformações de antes (globais)
var _brasas: CPUParticles2D


func _init() -> void:
	var aura: Texture = load("res://imagens/jogador_aura.png")
	# o rastro: o brilho do jogador inteiro nas posições de antes (fica no
	# mundo, não no jogador)
	for i in RASTRO:
		var r := Sprite.new()
		r.texture = aura
		r.centered = false
		r.material = Arte.mat_aditivo
		r.set_as_toplevel(true)
		r.visible = false
		add_child(r)
		_rastros.append(r)
	# os brilhos ficam numa camada atrás do corpo inteiro (o brilho de uma
	# peça não tinge a peça vizinha de azul), cada um seguindo o seu osso
	_camada_aura = Node2D.new()
	add_child(_camada_aura)
	# os ossos: as pernas e o tronco no corpo; a cabeça e os braços no
	# tronco; o antebraço no braço. A ordem dos filhos é a do desenho: o
	# braço de lá (e a bola) atrás do tronco, o braço de cá na frente.
	var pernas := _osso("pernas", self, "quadril")
	_peca("pernas", pernas)
	var tronco := _osso("tronco", self, "cintura")
	var ombro_e := _osso("ombro_e", tronco, "ombro_e")
	_peca("braco_e", ombro_e)
	var cotovelo_e := _osso("cotovelo_e", ombro_e, "cotovelo_e")
	_bola = _peca("bola", cotovelo_e)
	_peca("antebraco_e", cotovelo_e)
	_rem_cotovelo = _remendo(ombro_e)
	_peca("tronco", tronco)
	_rem_ombro = _remendo(tronco)
	var cabeca := _osso("cabeca", tronco, "pescoco")
	_peca("cabeca", cabeca)
	var ombro_d := _osso("ombro_d", tronco, "ombro_d")
	_peca("braco_d", ombro_d)
	var cotovelo_d := _osso("cotovelo_d", ombro_d, "cotovelo_d")
	_peca("antebraco_d", cotovelo_d)
	# brasas soltando do corpo e da bola
	_brasas = CPUParticles2D.new()
	_brasas.texture = Arte.tex_brilho
	_brasas.material = Arte.mat_aditivo
	_brasas.local_coords = false
	_brasas.amount = 48
	_brasas.lifetime = 1.0
	_brasas.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_brasas.emission_rect_extents = Vector2(200, 300)
	_brasas.position = Vector2(380, 480)
	_brasas.direction = Vector2(0, -1)
	_brasas.spread = 60.0
	_brasas.gravity = Vector2(0, -160)
	_brasas.initial_velocity = 110.0
	_brasas.initial_velocity_random = 0.7
	_brasas.scale_amount = 0.22
	_brasas.scale_amount_random = 0.7
	_brasas.color_ramp = Arte.rampa([Color(1.0, 0.85, 0.5, 0.0), Color(1.0, 0.6, 0.15, 0.95), Color(1.0, 0.3, 0.05, 0.0)], [0.0, 0.2, 1.0])
	_brasas.emitting = false
	add_child(_brasas)
	_set_luz(luz)
	pose(CAPA)


## Um osso: gira na junta (a posição é a junta, no espaço do pai).
func _osso(nome: String, pai: Node2D, junta: String) -> Node2D:
	var o := Node2D.new()
	var p: Vector2 = JUNTAS[junta]
	var origem := Vector2.ZERO
	if pai != self:
		origem = pai.get_meta("junta")
	o.position = p - origem
	o.set_meta("junta", p)
	pai.add_child(o)
	_ossos[nome] = o
	return o


## Uma peça no osso (e o brilho dela, na camada de trás).
func _peca(nome: String, osso: Node2D) -> Sprite:
	var junta: Vector2 = osso.get_meta("junta")
	if BRILHOS.has(nome):
		var b := Sprite.new()
		b.texture = load("res://imagens/jogador_%s_aura.png" % nome)
		b.centered = false
		b.material = Arte.mat_aditivo
		b.modulate = Color(0.35, 0.55, 1.0)
		_camada_aura.add_child(b)
		_auras.append(b)
		_auras_ossos.append([b, osso, BRILHOS[nome] - junta])
	var s := Sprite.new()
	s.texture = load("res://imagens/jogador_%s.png" % nome)
	s.centered = false
	s.position = PECAS[nome].position - junta
	osso.add_child(s)
	return s


## Um remendo de junta (um pedaço do atlas, trocado conforme o ângulo).
func _remendo(osso: Node2D) -> Sprite:
	var s := Sprite.new()
	s.texture = load("res://imagens/jogador_juntas.png")
	s.centered = false
	s.region_enabled = true
	s.region_filter_clip = true
	s.visible = false
	osso.add_child(s)
	return s


## Quanto o ombro da bola anda com o braço (sobe com ele lá em cima).
static func deslocamento_ombro(ome: float) -> Vector2:
	return Juntas.ERGUIDO * smoothstep(0.0, Juntas.ERGUE_ATE, ome) + Juntas.BAIXADO * smoothstep(0.0, Juntas.BAIXA_ATE, -ome)


## A pose (graus por osso; o que faltar é 0 = a capa).
func pose(p: Dictionary) -> void:
	for nome in OSSOS:
		_ossos[nome].rotation_degrees = float(p.get(nome, 0.0))
	var ome := float(p.get("ombro_e", 0.0))
	var cot := float(p.get("cotovelo_e", 0.0))
	var desl := deslocamento_ombro(ome)
	_ossos["ombro_e"].position = JUNTAS["ombro_e"] - JUNTAS["cintura"] + desl
	_por_remendo(_rem_ombro, Juntas.OMBRO, Juntas.OMBRO_DE, ome, JUNTAS["ombro_e"] + desl, JUNTAS["cintura"])
	_por_remendo(_rem_cotovelo, Juntas.COTOVELO, Juntas.COTOVELO_DE, cot, JUNTAS["cotovelo_e"], JUNTAS["ombro_e"])
	# os brilhos seguem os ossos (metade do tamanho: escala 2)
	for a in _auras_ossos:
		a[0].transform = _no_corpo(a[1]) * Transform2D(Vector2(2, 0), Vector2(0, 2), a[2])


## A transformação de um osso no espaço do jogador.
func _no_corpo(osso: Node2D) -> Transform2D:
	var t := Transform2D.IDENTITY
	var n: Node = osso
	while n != self:
		t = n.transform * t
		n = n.get_parent()
	return t


## O remendo mais perto do ângulo, levado ao pivô de agora e girado metade
## do que falta (o braço de verdade gira liso entre um e outro).
func _por_remendo(s: Sprite, lista: Array, de: float, ang: float, pivo: Vector2, junta_pai: Vector2) -> void:
	var n := lista.size()
	var i := int(round((clamp(ang, de, de + Juntas.PASSO * (n - 1)) - de) / Juntas.PASSO))
	var r: Array = lista[i]
	if r[7] <= 0:
		s.visible = false
		return
	s.visible = true
	s.region_rect = Rect2(r[5], r[6], r[7], r[8])
	s.offset = Vector2(r[3], r[4]) - Vector2(r[1], r[2])
	s.position = pivo - junta_pai
	s.rotation_degrees = 0.5 * (ang - float(r[0]))


## A mistura de duas poses (k = 0: a, 1: b).
static func misturar(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var r := {}
	for nome in OSSOS:
		r[nome] = lerp(float(a.get(nome, 0.0)), float(b.get(nome, 0.0)), k)
	return r


## Ao longo de uma lista de poses (k = 0: a primeira, 1: a última), liso.
func pose_entre(lista: Array, k: float) -> void:
	var n := lista.size() - 1
	var x: float = clamp(k, 0.0, 1.0) * n
	var i := int(min(floor(x), n - 1))
	var f := x - i
	pose(misturar(lista[i], lista[i + 1], f * f * (3.0 - 2.0 * f)))


func _set_luz(v: float) -> void:
	luz = v
	for a in _auras:
		a.modulate.a = 0.5 * clamp(v, 0.0, 2.0)


func _set_na_mao(v: bool) -> void:
	na_mao = v
	if _bola != null:
		_bola.visible = v


func brasas(ligar: bool) -> void:
	_brasas.emitting = ligar


## O centro da bola na mão, no espaço do pai (onde ela está agora).
func bola_na_mao() -> Vector2:
	return transform.xform(_no_corpo(_ossos["cotovelo_e"]).xform(JUNTAS["bola"] - JUNTAS["cotovelo_e"]))


## O raio da bola (no espaço do pai).
func raio_bola() -> float:
	return 80.0 * scale.x


func _process(_delta: float) -> void:
	# o rastro: o brilho nas últimas posições (some quando o jogador para)
	_historico.push_front(get_global_transform())
	if _historico.size() > RASTRO + 1:
		_historico.pop_back()
	for i in _rastros.size():
		var r: Sprite = _rastros[i]
		var k: int = i + 1
		if rastro <= 0.01 or k >= _historico.size():
			r.visible = false
			continue
		var t: Transform2D = _historico[k]
		r.visible = true
		r.global_transform = t.translated(AURA_TODA)
		var f: float = rastro * 0.22 * (1.0 - float(k) / (RASTRO + 1))
		r.modulate = Color(0.45, 0.65, 1.0, f).linear_interpolate(Color(1.0, 0.5, 0.1, f), float(k) / RASTRO)
