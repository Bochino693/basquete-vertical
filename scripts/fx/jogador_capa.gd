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
## Coordenadas do pôster original (941 x 1672): na escala 1080/941, na
## origem da tela, a pose da capa fica exatamente onde está no pôster.
## Em volta, a AURA (o brilho azul de cada peça, que vai junto com ela) e um
## RASTRO de brilho das posições de antes (movimento rápido).

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
	"pernas": Rect2(136, 492, 436, 416), "braco_e": Rect2(181, 229, 232, 143),
	"bola": Rect2(82, 34, 197, 166), "antebraco_e": Rect2(99, 53, 157, 251),
	"tronco": Rect2(295, 266, 280, 332), "tampa_ombro": Rect2(320, 253, 109, 119),
	"cabeca": Rect2(369, 169, 153, 157), "braco_d": Rect2(521, 371, 120, 197),
	"antebraco_d": Rect2(559, 493, 198, 214),
}
const BRILHOS := {
	"pernas": Vector2(75, 431), "braco_e": Vector2(120, 168),
	"antebraco_e": Vector2(38, -8), "tronco": Vector2(234, 205), "cabeca": Vector2(308, 108),
	"braco_d": Vector2(460, 310), "antebraco_d": Vector2(498, 432),
}

# AS POSES (graus; + = sentido do relógio na tela; 0 = a pose da capa)
const CAPA := {}
const DECOLAGEM := {"pernas": 10, "tronco": -8, "cabeca": -4, "ombro_e": -35, "cotovelo_e": 20, "ombro_d": 20, "cotovelo_d": 10}
const SUBINDO := {"pernas": 5, "tronco": -4, "cabeca": -2, "ombro_e": -18, "cotovelo_e": 10, "ombro_d": 10, "cotovelo_d": 5}
const ENTERRADA := [
	{},
	{"pernas": -4, "tronco": 4, "cabeca": 3, "ombro_e": 40, "cotovelo_e": -25, "ombro_d": -10, "cotovelo_d": -5},
	{"pernas": -7, "tronco": 8, "cabeca": 6, "ombro_e": 80, "cotovelo_e": -35, "ombro_d": -20, "cotovelo_d": -8},
	{"pernas": -9, "tronco": 12, "cabeca": 9, "ombro_e": 118, "cotovelo_e": -30, "ombro_d": -28, "cotovelo_d": -10},
	{"pernas": -10, "tronco": 15, "cabeca": 11, "ombro_e": 150, "cotovelo_e": -15, "ombro_d": -33, "cotovelo_d": -12},
	{"pernas": -10, "tronco": 17, "cabeca": 12, "ombro_e": 172, "cotovelo_e": 5, "ombro_d": -36, "cotovelo_d": -14},
]
# pendurado no aro: o braço esticado segurando, o corpo balança para trás
const PENDURADO := {"pernas": -2, "tronco": 9, "cabeca": 8, "ombro_e": 182, "cotovelo_e": 18, "ombro_d": -24, "cotovelo_d": -8}
const OSSOS := ["pernas", "tronco", "cabeca", "ombro_e", "cotovelo_e", "ombro_d", "cotovelo_d"]

var luz := 1.0 setget _set_luz              # o brilho em volta (aura)
var rastro := 0.0                           # 0 sem rastro, 1 forte
var na_mao := true setget _set_na_mao

var _ossos := {}            # nome -> Node2D
var _bola: Sprite
var _tampa: Sprite
var _auras := []            # sprites do brilho (um por peça)
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
	_peca("tronco", tronco)
	_tampa = _peca("tampa_ombro", tronco)
	_tampa.modulate.a = 0.0
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


## Uma peça no osso (com o brilho dela, atrás).
func _peca(nome: String, osso: Node2D) -> Sprite:
	var junta: Vector2 = osso.get_meta("junta")
	if BRILHOS.has(nome):
		var b := Sprite.new()
		b.texture = load("res://imagens/jogador_%s_aura.png" % nome)
		b.centered = false
		b.scale = Vector2(2, 2)
		b.position = BRILHOS[nome] - junta
		b.material = Arte.mat_aditivo
		b.modulate = Color(0.35, 0.55, 1.0)
		osso.add_child(b)
		_auras.append(b)
	var s := Sprite.new()
	s.texture = load("res://imagens/jogador_%s.png" % nome)
	s.centered = false
	s.position = PECAS[nome].position - junta
	osso.add_child(s)
	return s


## A pose (graus por osso; o que faltar é 0 = a capa).
func pose(p: Dictionary) -> void:
	for nome in OSSOS:
		_ossos[nome].rotation_degrees = float(p.get(nome, 0.0))
	# o ombro de lá fecha (a silhueta preta) conforme o braço sai da capa
	_tampa.modulate.a = clamp(abs(float(p.get("ombro_e", 0.0))) / 40.0, 0.0, 1.0)


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
	var o: Node2D = _ossos["cotovelo_e"]
	var t := Transform2D.IDENTITY
	var n: Node = o
	while n != self:
		t = n.transform * t
		n = n.get_parent()
	return transform.xform(t.xform(JUNTAS["bola"] - JUNTAS["cotovelo_e"]))


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
