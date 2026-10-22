extends MeshInstance2D

## LINHA DE NEON QUE SE DESENHA SOZINHA (traco.shader): a malha é feita
## uma vez; "progresso" revela a linha do começo ao fim com a ponta acesa,
## "inicio" apaga o começo (um traço que corre), "tremor" faz a lâmpada
## falhar ao acender.

const Malhas = preload("res://scripts/fx/malhas.gd")

var _mat: ShaderMaterial
var progresso := 1.0 setget _set_progresso
var inicio := 0.0 setget _set_inicio
var alfa := 1.0 setget _set_alfa
var tremor := 0.0 setget _set_tremor
var cor := Color(1.0, 0.46, 0.04) setget _set_cor


func _init() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/traco.shader")
	material = _mat


func montar(pontos: PoolVector2Array, largura := 4.0, brilho := 10.0, fechado := false) -> void:
	mesh = Malhas.traco(pontos, largura, brilho, fechado)


func _set_progresso(v: float) -> void:
	progresso = v
	_mat.set_shader_param("progresso", v)


func _set_inicio(v: float) -> void:
	inicio = v
	_mat.set_shader_param("inicio", v)


func _set_alfa(v: float) -> void:
	alfa = v
	_mat.set_shader_param("alfa", v)


func _set_tremor(v: float) -> void:
	tremor = v
	_mat.set_shader_param("tremor", v)


func _set_cor(c: Color) -> void:
	cor = c
	_mat.set_shader_param("cor", c)


## Desenha do zero ao fim em "tempo" segundos (devolve o tween).
func desenhar(tempo: float, atraso := 0.0) -> SceneTreeTween:
	_set_progresso(0.0)
	var tw := create_tween()
	tw.tween_property(self, "progresso", 1.0, tempo).set_delay(atraso).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw
