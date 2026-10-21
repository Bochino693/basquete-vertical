extends Sprite

## A BOLA DE BASQUETE FEITA À MÃO (bola.shader: esfera, luz, costuras que
## giram). Sem imagem: um quadradinho branco esticado ao tamanho pedido.

var velocidade := 3.0          # giro (radianos por segundo)
var _giro := 0.0
var _mat: ShaderMaterial


func _init() -> void:
	texture = Arte.tex_branco
	_mat = Arte.material("res://shaders/bola.shader")
	material = _mat


func tamanho(px: float) -> void:
	scale = Vector2.ONE * px / float(texture.get_width())


func ouro(v: float) -> void:
	_mat.set_shader_param("ouro", v)


func _process(delta: float) -> void:
	_giro = fposmod(_giro + delta * velocidade, TAU)
	_mat.set_shader_param("giro", _giro)
