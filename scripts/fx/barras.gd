extends MeshInstance2D

## EQUALIZADOR DE ENERGIA: barras que sobem e descem sozinhas (barras.shader,
## TIME no vértice: zero trabalho do script). "energia" (0..1) segue o
## combo do jogador.

const Malhas = preload("res://scripts/fx/malhas.gd")

var _mat: ShaderMaterial
var energia := 0.2 setget _set_energia


func montar(base: Vector2, n: int, largura: float, vao: float, altura: float, semente := 1) -> void:
	mesh = Malhas.barras(base, n, largura, vao, semente)
	_mat = Arte.material("res://shaders/barras.shader")
	material = _mat
	_mat.set_shader_param("altura", altura)
	_set_energia(energia)


func _set_energia(v: float) -> void:
	energia = clamp(v, 0.0, 1.0)
	if _mat != null:
		_mat.set_shader_param("energia", energia)


func cores(base: Color, topo: Color) -> void:
	_mat.set_shader_param("cor_base", base)
	_mat.set_shader_param("cor_topo", topo)
