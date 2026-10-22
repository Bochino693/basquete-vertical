extends MeshInstance2D

## ONDA DE LUZ (anéis + raios) que sai da cesta — ou, no modo "inverso",
## vem das bordas para o centro (contagem regressiva). Uma malha dividida
## por todas as ondas (onda.shader); o script só passa raio/força/cores.

const ALTURA := 1920.0
const LARGURA := 1080.0

var ativa := false
var _t := 0.0
var _dur := 1.0
var _combo := 1
var _forca := 1.0
var _inverso := false
var _dourado := false
var _ida_volta := false
var _cor_anel := Color(1.0, 0.48, 0.06)
var _cor_brilho := Color(1, 1, 1)
var _mat: ShaderMaterial
var _flash: Sprite


func _ready() -> void:
	mesh = Arte.malha_onda()
	_mat = Arte.material("res://shaders/onda.shader")
	material = _mat
	_flash = Arte.sprite_brilho(Color(1, 1, 1), 64.0)
	add_child(_flash)
	visible = false
	set_process(false)


func disparar(origem: Vector2, combo := 1, forca := 1.0, inverso := false, cor = null, dourado := false) -> void:
	position = origem
	_t = 0.0
	_combo = int(max(1, combo))
	_forca = forca
	_inverso = inverso
	_dourado = dourado
	_ida_volta = not inverso and _combo >= 9
	_dur = 0.62 if inverso else (1.05 if _combo >= 9 else 0.95)
	if cor != null:
		_cor_anel = cor
		_cor_brilho = Color(1, 1, 1)
	elif _combo >= 13:
		_cor_anel = Color(1.0, 0.02, 0.0)
		_cor_brilho = Color(1.0, 0.42, 0.25)
	elif _combo >= 9:
		_cor_anel = Color(0.62, 0.12, 1.0)
		_cor_brilho = Color(0.95, 0.35, 1.0)
	elif _combo >= 6:
		_cor_anel = Color(0.08, 0.42, 1.0)
		_cor_brilho = Color(0.38, 0.75, 1.0)
	elif dourado:
		_cor_anel = Color(1.0, 0.42, 0.02)
		_cor_brilho = Color(1.0, 0.68, 0.08)
	else:
		_cor_anel = Color(1.0, 0.48, 0.06)
		_cor_brilho = Color(1, 1, 1)
	_mat.set_shader_param("cor_anel", _cor_anel)
	_mat.set_shader_param("cor_brilho", _cor_brilho)
	var aneis := 4
	if inverso:
		aneis = 3
	elif _combo >= 13:
		aneis = 9
	elif _combo >= 9:
		aneis = 7
	elif dourado:
		aneis = 6
	var raios := 12 if inverso else (18 if _combo >= 13 else (14 if _combo >= 9 else 10))
	_mat.set_shader_param("n_aneis", float(aneis))
	_mat.set_shader_param("n_raios", float(raios))
	_mat.set_shader_param("espaco", ALTURA * (0.05 if inverso else 0.052))
	_mat.set_shader_param("larg", 8.0 if inverso else 9.0)
	_mat.set_shader_param("ang0", 0.0 if inverso else -PI * 0.92)
	_mat.set_shader_param("larg_raio", 3.5)
	ativa = true
	visible = true
	set_process(true)
	_atualizar()


func _process(delta: float) -> void:
	_t += delta
	if _t >= _dur:
		ativa = false
		visible = false
		set_process(false)
		return
	_atualizar()


func _atualizar() -> void:
	var p: float = clamp(_t / _dur, 0.0, 1.0)
	if _inverso:
		var raio: float = lerp(ALTURA * 0.85, LARGURA * 0.06, p)
		var intens := (0.25 + 0.75 * p) * _forca
		_mat.set_shader_param("raio", raio)
		_mat.set_shader_param("alfa", intens * 1.15)
		_mat.set_shader_param("raio_ini", 1.0)
		_mat.set_shader_param("raio_fim", 1.0 + ALTURA * 0.06 / max(raio, 1.0))
		if p > 0.78:
			var f := (p - 0.78) / 0.22
			_flash.visible = true
			_flash.scale = Vector2.ONE * lerp(LARGURA * 0.04, LARGURA * 0.28, f) / 64.0
			_flash.modulate = Color(_cor_anel.r, _cor_anel.g, _cor_anel.b, 0.7 * f * _forca)
		else:
			_flash.visible = false
		return
	var pr := p
	var fade := 1.0 - p
	if _ida_volta:
		pr = p * 2.0 if p <= 0.5 else (1.0 - p) * 2.0
		fade = 1.0 - abs(p - 0.5) * 0.85
	var raio_base: float = lerp(LARGURA * 0.10, ALTURA * 0.82, pr)
	var mult := 1.0
	if _combo >= 13:
		mult = 1.55
	elif _combo >= 9:
		mult = 1.2
	_mat.set_shader_param("raio", raio_base)
	_mat.set_shader_param("alfa", fade * _forca * mult)
	_mat.set_shader_param("raio_ini", 0.10)
	_mat.set_shader_param("raio_fim", 1.15)
	_flash.visible = true
	_flash.scale = Vector2.ONE * (raio_base * 0.64) / 64.0
	_flash.modulate = Color(_cor_brilho.r, _cor_brilho.g, _cor_brilho.b, 0.16 * fade * _forca * mult)
