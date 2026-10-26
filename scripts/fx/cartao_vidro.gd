extends Panel

## CARTÃO DE VIDRO (painéis da abertura): fundo escuro translúcido, um
## reflexo claro na parte de cima (como vidro), borda fina na cor e um
## brilho suave em volta. Uma faixa de luz atravessa o cartão quando ele
## abre (varrer). Leve: dois StyleBox desenhados uma vez; por quadro só anda
## a faixa de luz, e só enquanto ela passa.

const DURACAO_FAIXA := 1.0

var cor := Color(1, 1, 1) setget definir_cor
var _estilo: StyleBoxFlat
var _reflexo: Panel
var _janela: Control
var _faixa: Sprite
var _t := -1.0


func _init(c := Color(1.0, 0.46, 0.04), raio := 40) -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_estilo = StyleBoxFlat.new()
	_estilo.bg_color = Color(0.035, 0.025, 0.07, 0.88)
	_estilo.set_border_width_all(3)
	_estilo.set_corner_radius_all(raio)
	_estilo.corner_detail = 8
	_estilo.shadow_size = 26
	_estilo.anti_aliasing = true
	_estilo.anti_aliasing_size = 1
	add_stylebox_override("panel", _estilo)
	_reflexo = Panel.new()
	_reflexo.mouse_filter = MOUSE_FILTER_IGNORE
	var r := StyleBoxFlat.new()
	r.bg_color = Color(1, 1, 1, 0.05)
	r.corner_radius_top_left = raio - 3
	r.corner_radius_top_right = raio - 3
	r.corner_detail = 8
	r.anti_aliasing = true
	_reflexo.add_stylebox_override("panel", r)
	add_child(_reflexo)
	_janela = Control.new()
	_janela.mouse_filter = MOUSE_FILTER_IGNORE
	_janela.rect_clip_content = true
	add_child(_janela)
	_faixa = Sprite.new()
	_faixa.texture = Arte.tex_brilho
	_faixa.material = Arte.mat_aditivo
	_faixa.rotation_degrees = 18
	_faixa.visible = false
	_janela.add_child(_faixa)
	definir_cor(c)
	connect("resized", self, "_ajustar")
	set_process(false)


func definir_cor(c: Color) -> void:
	cor = c
	if _estilo == null:
		return
	_estilo.border_color = Color(c.r, c.g, c.b, 0.95)
	_estilo.shadow_color = Color(c.r, c.g, c.b, 0.34)


func _ajustar() -> void:
	_reflexo.rect_position = Vector2(3, 3)
	_reflexo.rect_size = Vector2(rect_size.x - 6, min(rect_size.y * 0.30, 340.0))
	_janela.rect_position = Vector2(3, 3)
	_janela.rect_size = rect_size - Vector2(6, 6)
	var lado: float = _faixa.texture.get_width()
	_faixa.scale = Vector2(150.0 / lado, rect_size.y * 1.4 / lado)


## Uma faixa de luz atravessa o cartão.
func varrer() -> void:
	_t = 0.0
	_faixa.visible = true
	set_process(true)
	_process(0.0)


func _process(delta: float) -> void:
	_t += delta
	var k := _t / DURACAO_FAIXA
	if k >= 1.0:
		_faixa.visible = false
		set_process(false)
		return
	var e := k * k * (3.0 - 2.0 * k)
	_faixa.position = Vector2(lerp(-160.0, rect_size.x + 160.0, e), rect_size.y * 0.5)
	_faixa.modulate = Color(1, 1, 1, 0.16 * sin(k * PI))
