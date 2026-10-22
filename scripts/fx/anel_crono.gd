extends Node2D

## O CRONÔMETRO REDONDO (no círculo da arte): 60 tracinhos acesos conforme
## o tempo que resta, o arco fino com a "cabeça" brilhante que anda a cada
## quadro, e um rastro de luz que gira sem parar no círculo da arte.
## Últimos 10 s: vermelho e piscando.

const Malhas = preload("res://scripts/fx/malhas.gd")

var r_dentro := 188.0
var r_fora := 208.0
var r_arco := 176.0
var r_corredor := 225.0

var _mat: ShaderMaterial
var _anel: MeshInstance2D
var _cabeca: Sprite
var _corredor: MeshInstance2D
var _corredor2: MeshInstance2D
var _frac := 1.0
var _varre := 1.0
var _alerta := false
var _t := 0.0
var cor := Arte.LARANJA setget _set_cor


func _ready() -> void:
	_anel = MeshInstance2D.new()
	_anel.mesh = Malhas.anel(r_dentro, r_fora, r_arco)
	_mat = Arte.material("res://shaders/anel.shader")
	_anel.material = _mat
	add_child(_anel)
	_corredor = MeshInstance2D.new()
	_corredor.mesh = Malhas.arco_rastro(r_corredor, 3.5, 70.0, Color(1.0, 0.85, 0.5))
	_corredor.material = Arte.mat_aditivo
	add_child(_corredor)
	_corredor2 = MeshInstance2D.new()
	_corredor2.mesh = _corredor.mesh
	_corredor2.material = Arte.mat_aditivo
	_corredor2.rotation = PI
	_corredor2.modulate.a = 0.55
	add_child(_corredor2)
	_cabeca = Arte.sprite_brilho(Color(1.0, 0.85, 0.55), 46.0)
	add_child(_cabeca)
	_set_cor(cor)
	definir(1.0)


func _set_cor(c: Color) -> void:
	cor = c
	if _mat != null:
		_mat.set_shader_param("cor", c)
		_mat.set_shader_param("cor_apagado", Color(c.r * 0.30, c.g * 0.22, c.b * 0.2))


func definir(frac: float) -> void:
	_frac = clamp(frac, 0.0, 1.0)
	_mat.set_shader_param("frac", _frac)


func alerta(ligado: bool) -> void:
	if ligado == _alerta:
		return
	_alerta = ligado
	_set_cor(Arte.VERMELHO_ALERTA if ligado else Arte.LARANJA)


## Os tracinhos acendem em sequência, do topo, em "tempo" segundos.
func varrer(tempo := 0.9) -> void:
	_varre = 0.0
	var tw := create_tween()
	tw.tween_method(self, "_set_varre", 0.0, 1.0, tempo).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_varre(v: float) -> void:
	_varre = v
	_mat.set_shader_param("varre", v)


func _process(delta: float) -> void:
	_t += delta
	var velocidade := 3.2 if _alerta else 1.1
	_corredor.rotation = fposmod(_corredor.rotation + delta * velocidade, TAU)
	_corredor2.rotation = fposmod(_corredor2.rotation + delta * velocidade, TAU)
	var f := min(_frac, _varre)
	var ang := -PI * 0.5 + TAU * f
	_cabeca.position = Vector2(cos(ang), sin(ang)) * r_arco
	_cabeca.visible = f > 0.002
	var pulso := 0.0
	if _alerta:
		pulso = 0.5 + 0.5 * sin(_t * 12.0)
	_mat.set_shader_param("pulso", pulso)
	_cabeca.modulate = Color(cor.r, cor.g * 0.9 + 0.1, cor.b + 0.3, 0.75 + 0.25 * sin(_t * 9.0))
