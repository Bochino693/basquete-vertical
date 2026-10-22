extends MeshInstance2D

## O PISO DE LED (ou a parede de LED) QUE ACENDE EM ONDA (piso.shader).
## Na partida é o PISO DA QUADRA: ladrilhos em perspectiva nas linhas da
## quadra do fundo, só da linha de fundo para baixo (nunca por cima do
## placar). Na apresentação é uma PAREDE de ladrilhos atrás da quadra.
## Até 4 ondas ao mesmo tempo (a mais velha cede o lugar) + o modo
## RECORDE (duas ondas eternas amarelo/branco). Por quadro o script só
## passa 4 vetores ao shader.

const Malhas = preload("res://scripts/fx/malhas.gd")
# a quadra de fundo_jogo.png (ampliada para 1080 x 1920): as laterais
# pintadas fogem para FUGA; a linha de fundo da quadra fica em TOPO_PISO
const FUGA := Vector2(540, 88)
const TOPO_PISO := 994.0

var _ondas: Array = []
var _mat: ShaderMaterial
var _recorde := false
var _rec_centro := Vector2(540, 700)
var _rec_pulso := 0.0
var _rec_forca := 0.0
var base := 1.0 setget _set_base
var _parede := 0.0


## altura_parede > 0: parede de ladrilhos retos do alto da tela até essa
## altura (apresentação); 0: o piso em perspectiva da partida.
func _init(altura_parede := 0.0) -> void:
	_parede = altura_parede


func _ready() -> void:
	if _parede > 0.0:
		mesh = Malhas.parede(Rect2(0, 0, 1080, _parede), 88.0)
	else:
		mesh = Malhas.piso(FUGA, TOPO_PISO, 1930.0, 62.0, 0.6, 1080.0)
	texture = load("res://imagens/fx_ladrilho.png")
	_mat = Arte.material("res://shaders/piso.shader")
	material = _mat
	_mat.set_shader_param("cor_base", Arte.LARANJA)
	_limpar_uniformes()


## A cor do piso parado (laranja; azul no SLAM MODE).
func definir_cor_base(c: Color) -> void:
	if _mat != null:
		_mat.set_shader_param("cor_base", c)


func _set_base(v: float) -> void:
	base = v
	if _mat != null:
		_mat.set_shader_param("base", v)


## combo: 1..n (cores e tamanho como no jogo original); inverso = da
## borda para o centro (contagem); cor: força uma cor.
func disparar(origem: Vector2, combo := 1, inverso := false, cor = null, atraso := 0.0) -> void:
	var nivel := int(max(1, combo))
	var dur := 1.12
	var largura := 1920.0 * 0.105
	if nivel >= 13:
		dur = 1.34
		largura = 1920.0 * 0.155
	elif nivel >= 9:
		dur = 1.26
		largura = 1920.0 * 0.145
	elif nivel >= 6:
		dur = 1.18
		largura = 1920.0 * 0.135
	elif nivel >= 3:
		dur = 0.84
		largura = 1920.0 * 0.118
	var c: Color = cor if cor != null else cor_do_combo(nivel)
	if _ondas.size() >= 4:
		_ondas.pop_front()
	_ondas.append({"o": origem, "t": -atraso, "dur": dur, "inv": inverso, "ida": nivel >= 6 and not inverso,
		"larg": largura, "cor": c})


static func cor_do_combo(nivel: int) -> Color:
	if nivel >= 13:
		return Color(1.0, 0.06, 0.03)
	if nivel >= 9:
		return Color(0.82, 0.20, 1.0)
	if nivel >= 6:
		return Color(0.12, 0.55, 1.0)
	if nivel >= 3:
		return Color(1.0, 0.58, 0.04)
	return Color(0.85, 0.90, 1.0)


func modo_recorde(ligado: bool, centro := Vector2(540, 700)) -> void:
	_recorde = ligado
	_rec_centro = centro
	if ligado:
		_ondas.clear()
		_limpar_uniformes()


func limpar() -> void:
	_ondas.clear()
	_recorde = false
	_rec_forca = 0.0
	_limpar_uniformes()


func _limpar_uniformes() -> void:
	for i in 4:
		_mat.set_shader_param("o%d" % i, Plane(0, 0, -9999, 0))
	_mat.set_shader_param("rec", Plane(0, 0, 0, 0))


func _process(delta: float) -> void:
	if _ondas.empty() and not _recorde and _rec_forca <= 0.0:
		return
	var vivas := []
	for o in _ondas:
		o["t"] += delta
		if o["t"] < o["dur"]:
			vivas.append(o)
	_ondas = vivas
	var larg := [180.0, 180.0, 180.0, 180.0]
	for i in 4:
		if i < _ondas.size():
			var o: Dictionary = _ondas[i]
			var p: float = clamp(o["t"] / o["dur"], 0.0, 1.0)
			var pr = p
			var fade = 1.0 - p
			if o["ida"]:
				pr = p * 2.0 if p <= 0.5 else (1.0 - p) * 2.0
				fade = 1.0 - abs(p - 0.5) * 0.72
			if o["t"] < 0.0:
				fade = 0.0
			var raio = pr * 1080.0 * 1.35
			if o["inv"]:
				raio = (1.0 - pr) * 1080.0 * 1.35
			var c: Vector2 = o["o"]
			_mat.set_shader_param("o%d" % i, Plane(c.x, c.y, raio, fade))
			_mat.set_shader_param("c%d" % i, o["cor"])
			larg[i] = o["larg"]
		else:
			_mat.set_shader_param("o%d" % i, Plane(0, 0, -9999, 0))
	_mat.set_shader_param("larg", Plane(larg[0], larg[1], larg[2], larg[3]))
	# recorde: entra e sai suave
	_rec_forca = move_toward(_rec_forca, 1.0 if _recorde else 0.0, delta * 2.0)
	if _rec_forca > 0.0:
		_rec_pulso += delta * 9.0
		var ciclo := fposmod(_rec_pulso * 0.075, 1.0)
		var pulso := (0.70 + 0.30 * abs(sin(_rec_pulso * 1.45))) * _rec_forca
		_mat.set_shader_param("rec", Plane(_rec_centro.x, _rec_centro.y, ciclo, pulso))
	else:
		_mat.set_shader_param("rec", Plane(0, 0, 0, 0))
