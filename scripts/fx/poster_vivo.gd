extends Node2D

## O PÔSTER VIVO (abertura e o fim da apresentação): a arte em Full HD
## (imagens/poster.png) com as coisas dela MEXENDO, como num vídeo:
##   * no shader (shaders/poster.shader + o mapa imagens/poster_vivo.png):
##     as janelas dos prédios acendem e apagam, cada andar no seu tempo, os
##     refletores piscam, o neon do telão SLAM e da coroa grafitada pulsa e
##     falha, uma faixa de luz corre o telão e o fogo da bola, do aro e do
##     contorno do jogador tremula subindo;
##   * por cima: chamas soltando da bola e do aro, o brilho deles
##     tremulando, o refletor grande pulsando com o reflexo de lente, as
##     luzes vermelhas no alto das antenas piscando, a aura do jogador
##     respirando, faíscas de energia estalando no contorno dele e, quando
##     relampeja, um raio caindo do céu na antena do prédio.
## Tudo montado aqui (nada nasce depois); leve: poucas partículas, os
## brilhos são sprites, os raios só desenham enquanto estalam. Parado
## (ligar(false)) não gasta nada e o pôster fica como a arte.
## Coordenadas: as da tela (1080 x 1920), origem no canto do pôster.

const Malhas = preload("res://scripts/fx/malhas.gd")
const Raio = preload("res://scripts/fx/raio_eletrico.gd")

const K := 1080.0 / 941.0                 # do pôster original para a tela
const BOLA := Vector2(218, 129)           # a bola de fogo (centro)
const ARO := Vector2(868, 286)            # o aro (centro da elipse)
const ARO_EIXOS := Vector2(127, 59)
const REFLETOR := Vector2(886, 588)       # o refletor grande da arena
const ANTENAS := [Vector2(170, 302), Vector2(222, 412)]
const AURA := Vector2(58, 0)              # imagens/jogador_aura.png no pôster original
# pontos na borda do jogador (tools/poster_vivo.py grava em
# tools/arte/poster_contorno.txt; copiados aqui)
const CONTORNO := [
	Vector2(210, 49), Vector2(255, 49), Vector2(185, 60), Vector2(147, 86), Vector2(293, 90), Vector2(123, 119), Vector2(306, 119), Vector2(122, 149),
	Vector2(305, 149), Vector2(132, 179), Vector2(292, 179), Vector2(495, 200), Vector2(521, 200), Vector2(176, 201), Vector2(267, 204), Vector2(469, 208),
	Vector2(134, 209), Vector2(209, 213), Vector2(567, 226), Vector2(442, 238), Vector2(150, 239), Vector2(201, 239), Vector2(239, 262), Vector2(172, 269),
	Vector2(435, 269), Vector2(574, 269), Vector2(269, 292), Vector2(298, 294), Vector2(188, 298), Vector2(445, 298), Vector2(589, 298), Vector2(328, 301),
	Vector2(384, 308), Vector2(477, 313), Vector2(209, 319), Vector2(452, 328), Vector2(591, 328), Vector2(239, 341), Vector2(561, 343), Vector2(269, 353),
	Vector2(298, 373), Vector2(567, 376), Vector2(328, 383), Vector2(358, 390), Vector2(597, 396), Vector2(627, 413), Vector2(380, 418), Vector2(379, 448),
	Vector2(646, 448), Vector2(391, 477), Vector2(652, 477), Vector2(656, 503), Vector2(399, 507), Vector2(402, 537), Vector2(675, 537), Vector2(604, 545),
	Vector2(387, 555), Vector2(686, 559), Vector2(627, 565), Vector2(596, 574), Vector2(716, 588), Vector2(378, 597), Vector2(586, 597), Vector2(647, 597),
	Vector2(357, 627), Vector2(589, 627), Vector2(663, 627), Vector2(740, 627), Vector2(686, 650), Vector2(347, 656), Vector2(621, 656), Vector2(755, 656),
	Vector2(716, 674), Vector2(776, 684), Vector2(342, 686), Vector2(635, 686), Vector2(345, 716), Vector2(652, 716), Vector2(757, 716), Vector2(795, 716),
	Vector2(358, 738), Vector2(642, 746), Vector2(760, 746), Vector2(824, 746), Vector2(778, 761), Vector2(624, 766), Vector2(351, 776), Vector2(831, 776),
	Vector2(596, 784),
]

var mat: ShaderMaterial
var _mapa: Texture
var _ruido: Texture
var _poster: MeshInstance2D
var _aura: Sprite
var _brilho_bola: Sprite
var _brilho_aro: Sprite
var _chama_bola: CPUParticles2D
var _chama_aro: CPUParticles2D
var _refletor: Sprite
var _reflexo: Sprite
var _estrela: Sprite
var _farois := []
var _faiscas := []
var _raio_ceu: Node2D
var _t := 0.0
var _proxima_faisca := 0.6
var _faisca_i := 0
var _proxima_falha := 4.0
var _falha := -1.0
var _farol_forte := 0.0
var _r := RandomNumberGenerator.new()


func _init() -> void:
	_r.randomize()
	_poster = MeshInstance2D.new()
	_poster.mesh = Malhas.tela(Rect2(0, 0, 1080, 1920), 12, 22)
	_poster.texture = load("res://imagens/poster.png")
	mat = Arte.material("res://shaders/poster.shader")
	_mapa = load("res://imagens/poster_vivo.png")
	_ruido = load("res://imagens/poster_ruido.png")
	mat.set_shader_param("mapa", _mapa)
	mat.set_shader_param("ruido", _ruido)
	_poster.material = mat
	add_child(_poster)
	# a aura do jogador (o mesmo recorte da apresentação), azul
	_aura = Sprite.new()
	_aura.texture = load("res://imagens/jogador_aura.png")
	_aura.centered = false
	_aura.position = AURA * K
	_aura.scale = Vector2.ONE * K
	_aura.material = Arte.mat_aditivo
	_aura.modulate = Color(0.35, 0.6, 1.0, 0.0)
	add_child(_aura)
	# o brilho da bola e do aro (tremulam como fogo)
	_brilho_bola = Arte.sprite_brilho(Color(1.0, 0.5, 0.12), 340.0)
	_brilho_bola.position = BOLA
	add_child(_brilho_bola)
	_brilho_aro = Arte.sprite_brilho(Color(1.0, 0.45, 0.1), 420.0)
	_brilho_aro.scale.y *= 0.5
	_brilho_aro.position = ARO + Vector2(-20, -10)
	add_child(_brilho_aro)
	# o refletor: o brilho, o risco do reflexo de lente e a estrela
	_refletor = Arte.sprite_brilho(Color(0.6, 0.8, 1.0), 250.0)
	_refletor.position = REFLETOR
	add_child(_refletor)
	_reflexo = Arte.sprite_brilho(Color(0.55, 0.75, 1.0), 1.0)
	_reflexo.position = REFLETOR
	_reflexo.scale = Vector2(620.0, 14.0) / _reflexo.texture.get_width()
	add_child(_reflexo)
	_estrela = Arte.sprite_brilho(Color(0.8, 0.9, 1.0), 200.0, Arte.tex_estrela)
	_estrela.position = REFLETOR
	add_child(_estrela)
	# as luzes vermelhas no alto das antenas
	for p in ANTENAS:
		var f := Arte.sprite_brilho(Color(1.0, 0.16, 0.1), 54.0)
		f.position = p
		var miolo := Arte.sprite_brilho(Color(1.0, 0.75, 0.7), 14.0)
		f.add_child(miolo)
		miolo.scale = Vector2.ONE * 14.0 / 54.0
		add_child(f)
		_farois.append(f)
	# chamas soltando da bola e do aro
	_chama_bola = _chamas(26, 0.55)
	_chama_bola.position = BOLA
	_chama_bola.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_chama_bola.emission_sphere_radius = 78.0
	add_child(_chama_bola)
	_chama_aro = _chamas(30, 0.5)
	_chama_aro.position = ARO
	_chama_aro.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	_chama_aro.emission_points = _pontos_aro()
	_chama_aro.scale_amount = 0.75
	add_child(_chama_aro)
	# o raio do céu (relampejar) e as faíscas no contorno do jogador
	_raio_ceu = Raio.new()
	_raio_ceu.cor = Color(0.55, 0.8, 1.0)
	_raio_ceu.espessura = 0.75
	add_child(_raio_ceu)
	for i in 3:
		var f := Raio.new()
		f.espessura = 0.32
		add_child(f)
		_faiscas.append(f)
	set_process(false)


func _chamas(quantas: int, vida: float) -> CPUParticles2D:
	var c := CPUParticles2D.new()
	c.texture = Arte.tex_fumaca
	c.material = Arte.mat_aditivo
	c.amount = quantas
	c.lifetime = vida
	c.randomness = 0.5
	c.direction = Vector2(0, -1)
	c.spread = 28.0
	c.gravity = Vector2(0, -380)
	c.initial_velocity = 80.0
	c.initial_velocity_random = 0.6
	c.angular_velocity = 90.0
	c.angular_velocity_random = 1.0
	c.scale_amount = 0.95
	c.scale_amount_random = 0.5
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.6))
	curva.add_point(Vector2(0.25, 1.0))
	curva.add_point(Vector2(1, 0.25))
	c.scale_amount_curve = curva
	c.color_ramp = Arte.rampa([Color(1.0, 0.9, 0.6, 0.0), Color(1.0, 0.72, 0.3, 0.42), Color(1.0, 0.36, 0.06, 0.26), Color(0.6, 0.1, 0.02, 0.0)], [0.0, 0.15, 0.55, 1.0])
	c.emitting = false
	return c


## Pontos na volta do aro (mais do lado de lá e da esquerda, onde a arte
## tem fogo).
static func _pontos_aro() -> PoolVector2Array:
	var p := PoolVector2Array()
	for i in 28:
		var a: float = TAU * i / 28.0
		var q := Vector2(cos(a), sin(a)) * ARO_EIXOS
		p.append(q)
		if q.x < 0.0 or q.y < 0.0:
			p.append(q * 0.97)
	return p


## Liga (o pôster vive) ou desliga (fica como a arte, sem gastar nada).
## Na TV Box que não segurou 60 quadros (Ajustes.leves()) o pôster volta
## ao shader simples (uma leitura de textura) e a aura grande sai; as
## chamas, os brilhos e as faíscas (leves) ficam.
func ligar(sim: bool) -> void:
	set_process(sim)
	_chama_bola.emitting = sim
	_chama_aro.emitting = sim
	var leve := Ajustes.leves()
	var sh := Arte.shader("res://shaders/poster_leve.shader" if leve else "res://shaders/poster.shader")
	if mat.shader != sh:
		var guardados := {}
		for nome in ["brilho_pos", "brilho_forca", "respiro", "relampago", "escurecer"]:
			guardados[nome] = mat.get_shader_param(nome)
		mat.shader = sh
		for nome in guardados:
			if guardados[nome] != null:
				mat.set_shader_param(nome, guardados[nome])
		if not leve:
			mat.set_shader_param("mapa", _mapa)
			mat.set_shader_param("ruido", _ruido)
	mat.set_shader_param("vida", 1.0 if sim else 0.0)
	for n in [_brilho_bola, _brilho_aro, _refletor, _reflexo, _estrela] + _farois:
		n.visible = sim
	_aura.visible = sim and not leve
	if not sim:
		for r in _faiscas + [_raio_ceu]:
			r.visible = false
			r.set_process(false)
	else:
		_process(0.0)


## Tudo aceso e estalando uma vez (a preparação, atrás da capa: a placa
## de vídeo já conhece cada textura e o shader).
func aquecer() -> void:
	ligar(true)
	relampejar()
	for i in _faiscas.size():
		_faiscar()


## O raio do céu cai na antena do prédio (junto com o relâmpago da arte).
func relampejar() -> void:
	if not is_processing():
		return
	var de := Vector2(_r.randf_range(20.0, 110.0), -30.0)
	_raio_ceu.disparar(de, ANTENAS[0] + Vector2(0, -6), 0.42)
	_farol_forte = 1.0


func _process(delta: float) -> void:
	_t += delta
	mat.set_shader_param("tempo", fmod(_t, 600.0))
	mat.set_shader_param("luz_a", fmod(_t * 0.45, TAU))
	mat.set_shader_param("luz_c", fmod(_t * 1.2 + 40.0, 30.0 * PI))
	# neon: pulsa devagar e de vez em quando falha (pisca rápido)
	var neon := 0.08 + 0.10 * sin(_t * 2.3)
	_proxima_falha -= delta
	if _proxima_falha <= 0.0:
		_proxima_falha = _r.randf_range(4.0, 9.0)
		_falha = 0.0
	if _falha >= 0.0:
		_falha += delta
		if _falha < 0.5:
			neon = -0.7 if fmod(_falha * 22.0, 1.0) < 0.45 else 0.3
		else:
			_falha = -1.0
	mat.set_shader_param("neon", neon)
	# a faixa de luz correndo o telão
	var ciclo := fmod(_t, 3.4)
	mat.set_shader_param("telao_y", lerp(560.0, 960.0, ciclo / 1.5) if ciclo < 1.5 else -1000.0)
	# fogo: o brilho tremulando (somas de senos fora de compasso)
	var tremula := 0.5 + 0.22 * sin(_t * 13.0) + 0.16 * sin(_t * 23.7 + 1.3) + 0.12 * sin(_t * 7.1)
	_brilho_bola.modulate.a = 0.2 + 0.2 * tremula
	var tremula2 := 0.5 + 0.22 * sin(_t * 11.3 + 2.0) + 0.16 * sin(_t * 19.1) + 0.12 * sin(_t * 5.3 + 0.7)
	_brilho_aro.modulate.a = 0.16 + 0.18 * tremula2
	# o refletor pulsa (e a estrela gira devagar)
	var pulso := 0.5 + 0.5 * sin(_t * 1.3)
	_refletor.modulate.a = 0.3 + 0.25 * pulso
	_reflexo.modulate.a = 0.2 + 0.22 * pulso
	_estrela.modulate.a = 0.35 + 0.3 * pulso
	_estrela.rotation = _t * 0.15
	# as luzes das antenas: uma piscada a cada 1,6 s (e forte no raio)
	_farol_forte = max(0.0, _farol_forte - delta * 2.5)
	for i in _farois.size():
		var f: float = fmod(_t + i * 0.7, 1.6)
		var a: float = 1.0 if f < 0.12 else max(0.0, 1.0 - (f - 0.12) / 0.3)
		var s: Sprite = _farois[i]
		s.modulate.a = max(a, _farol_forte)
	# a aura do jogador respira
	_aura.modulate.a = 0.11 + 0.08 * sin(_t * 1.8)
	# faíscas de energia estalando no contorno do jogador
	_proxima_faisca -= delta
	if _proxima_faisca <= 0.0:
		_proxima_faisca = _r.randf_range(0.22, 0.75)
		_faiscar()


func _faiscar() -> void:
	var a: Vector2 = CONTORNO[_r.randi() % CONTORNO.size()]
	var perto := []
	for p in CONTORNO:
		var d: float = a.distance_to(p)
		if d > 50.0 and d < 135.0:
			perto.append(p)
	if perto.empty():
		return
	var b: Vector2 = perto[_r.randi() % perto.size()]
	var raio: Node2D = _faiscas[_faisca_i]
	_faisca_i = (_faisca_i + 1) % _faiscas.size()
	raio.cor = Color(0.45, 0.75, 1.0) if _r.randf() < 0.6 else Color(1.0, 0.6, 0.2)
	raio.disparar(a, b, _r.randf_range(0.14, 0.26))
