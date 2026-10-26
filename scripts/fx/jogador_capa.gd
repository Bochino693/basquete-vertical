extends Node2D

## O JOGADOR DA CAPA, em peças (imagens/jogador_*.png, recortadas do pôster
## por tools/recortar_jogador.py): igualzinho ao do pôster - a regata, o
## short, o tênis, a bola de fogo. O nó usa as coordenadas do pôster (941 x
## 1672): na escala 1080/941, na origem da tela, ele fica exatamente onde
## está no pôster.
##
## Os braços giram no ombro (braco_e: o levantado, com a bola; braco_d: o
## da mão aberta); a bola fica na mão (na_mao) ou solta (o jogo a move:
## posicao_bola). Em volta, a AURA (o jogador inteiro borrado, azul,
## como o brilho da capa) e um RASTRO de aura das posições de antes
## (movimento rápido). Desenho leve: quatro imagens, a aura e o rastro só
## nos movimentos rápidos.

const OMBRO_E := Vector2(352, 300)
const OMBRO_D := Vector2(548, 392)
const CENTRO_BOLA := Vector2(190, 112)
const RASTRO := 2

var braco_e := 0.0 setget _set_braco_e      # giro do braço levantado (rad, 0 = pose da capa)
var braco_d := 0.0 setget _set_braco_d
var luz := 1.0 setget _set_luz              # o brilho em volta (aura)
var rastro := 0.0                           # 0 sem rastro, 1 forte
var na_mao := true setget _set_na_mao

var _aura_azul: Sprite
var _pivo_e: Node2D
var _pivo_d: Node2D
var _bola: Sprite
var _corpo: Sprite
var _rastros := []          # sprites da aura (o rastro)
var _historico := []        # transformações de antes (globais)
var _brasas: CPUParticles2D


func _init() -> void:
	var caixas := _ler_caixas()
	var aura: Texture = load("res://imagens/jogador_aura.png")
	# o rastro: a aura nas posições de antes (fica no mundo, não no jogador)
	for i in RASTRO:
		var r := Sprite.new()
		r.texture = aura
		r.centered = false
		r.material = Arte.mat_aditivo
		r.set_as_toplevel(true)
		r.visible = false
		add_child(r)
		_rastros.append(r)
	_aura_azul = _peca(aura, caixas["jogador_aura"])
	_aura_azul.material = Arte.mat_aditivo
	_aura_azul.modulate = Color(0.35, 0.55, 1.0, 0.5)
	add_child(_aura_azul)
	# o braço levantado e a bola (atrás do corpo: é o braço de lá)
	_pivo_e = Node2D.new()
	_pivo_e.position = OMBRO_E
	add_child(_pivo_e)
	_bola = _peca(load("res://imagens/jogador_bola.png"), caixas["jogador_bola"])
	_bola.position -= OMBRO_E
	_pivo_e.add_child(_bola)
	var be := _peca(load("res://imagens/jogador_braco_e.png"), caixas["jogador_braco_e"])
	be.position -= OMBRO_E
	_pivo_e.add_child(be)
	_corpo = _peca(load("res://imagens/jogador_corpo.png"), caixas["jogador_corpo"])
	add_child(_corpo)
	# o braço da mão aberta (o de cá: na frente do corpo)
	_pivo_d = Node2D.new()
	_pivo_d.position = OMBRO_D
	add_child(_pivo_d)
	var bd := _peca(load("res://imagens/jogador_braco_d.png"), caixas["jogador_braco_d"])
	bd.position -= OMBRO_D
	_pivo_d.add_child(bd)
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


## As caixas das peças no pôster (tools/arte/jogador_pecas.txt, copiadas
## aqui: o jogo não lê a pasta tools).
static func _ler_caixas() -> Dictionary:
	return {
		"jogador_corpo": Rect2(135, 168, 440, 741),
		"jogador_braco_e": Rect2(98, 52, 269, 321),
		"jogador_braco_d": Rect2(520, 349, 238, 357),
		"jogador_bola": Rect2(83, 34, 195, 167),
		"jogador_aura": Rect2(58, 0, 730, 956),
	}


static func _peca(tex: Texture, caixa: Rect2) -> Sprite:
	var s := Sprite.new()
	s.texture = tex
	s.centered = false
	s.position = caixa.position
	return s


func _set_braco_e(v: float) -> void:
	braco_e = v
	if _pivo_e != null:
		_pivo_e.rotation = v


func _set_braco_d(v: float) -> void:
	braco_d = v
	if _pivo_d != null:
		_pivo_d.rotation = v


func _set_luz(v: float) -> void:
	luz = v
	if _aura_azul != null:
		_aura_azul.modulate.a = 0.5 * clamp(v, 0.0, 2.0)


func _set_na_mao(v: bool) -> void:
	na_mao = v
	if _bola != null:
		_bola.visible = v


func brasas(ligar: bool) -> void:
	_brasas.emitting = ligar


## O centro da bola na mão, no espaço do pai (onde ela está agora).
func bola_na_mao() -> Vector2:
	var local := OMBRO_E + (CENTRO_BOLA - OMBRO_E).rotated(braco_e)
	return transform.xform(local)


## O raio da bola (no espaço do pai).
func raio_bola() -> float:
	return 80.0 * scale.x


func _process(_delta: float) -> void:
	# o rastro: a aura nas últimas posições (some quando o jogador para)
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
		r.global_transform = t.translated(_aura_azul.position)
		var f: float = rastro * 0.22 * (1.0 - float(k) / (RASTRO + 1))
		r.modulate = Color(0.45, 0.65, 1.0, f).linear_interpolate(Color(1.0, 0.5, 0.1, f), float(k) / RASTRO)
