extends Node2D

## O JOGADOR DA CAPA, QUADRO A QUADRO (a apresentação): cada quadro é o
## jogador INTEIRO numa imagem só, renderizado da própria arte da capa pelo
## tools/quadros_jogador.py - correndo e quicando a bola, juntando,
## saltando, pegando a bola lá em cima, na pose da capa, enterrando e
## pendurado no aro. Aqui só se passa o quadro (como um desenho animado):
## o corpo, o brilho azul em volta (o do corpo inteiro, aditivo) e, num nó
## à parte (`dedos`, que quem monta põe no mundo POR CIMA da bola), os
## dedos que ficam na frente dela. A bola não está nos quadros: é uma só,
## de quem monta (imagens/jogador_bola.png).
##
## O nó fica no mundo com a escala do jogador (Dados.ESC); as posições dos
## quadros são no espaço do jogador (px do pôster, a partir da cintura).

const Dados = preload("res://scripts/fx/jogador_quadros_dados.gd")
const RASTRO := 3
const COR_BRILHO := Color(0.3, 0.55, 1.0)

var luz := 1.0 setget _set_luz         # o brilho em volta
var rastro := 0.0                       # 0 sem rastro, 1 forte
var dedos: Node2D                       # (vai no mundo, por cima da bola)
var quadro := -1

var _paginas := []
var _extra: Texture
var _brilho: Sprite
var _corpo: Sprite
var _dedo: Sprite
var _camada_rastro: Node2D
var _rastros := []
var _historico := []                    # [transformação global, quadro]
var _aquecer := []


func _init() -> void:
	for p in Dados.PAGINAS:
		_paginas.append(load(p))
	_extra = load(Dados.EXTRA)
	scale = Vector2.ONE * Dados.ESC
	_camada_rastro = Node2D.new()
	add_child(_camada_rastro)
	for i in RASTRO:
		var r := _sprite(_extra)
		r.material = Arte.mat_aditivo
		r.visible = false
		_camada_rastro.add_child(r)
		_rastros.append(r)
	_brilho = _sprite(_extra)
	_brilho.material = Arte.mat_aditivo
	add_child(_brilho)
	_corpo = _sprite(_paginas[0])
	add_child(_corpo)
	dedos = Node2D.new()
	_dedo = _sprite(_extra)
	dedos.add_child(_dedo)
	_set_luz(1.0)
	mostrar(0)


func _sprite(tex: Texture) -> Sprite:
	var s := Sprite.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.region_filter_clip = true
	return s


static func _por(s: Sprite, d: Array, de: int) -> void:
	s.region_rect = Rect2(d[de], d[de + 1], d[de + 2], d[de + 3])
	s.position = Vector2(d[de + 4], d[de + 5])
	s.scale = Vector2.ONE * float(d[de + 6])


## O quadro i (o corpo e o brilho).
func mostrar(i: int) -> void:
	if i == quadro:
		return
	quadro = i
	var c: Array = Dados.CORPO[i]
	_corpo.texture = _paginas[int(c[0])]
	_por(_corpo, c, 1)
	_por(_brilho, Dados.BRILHO[i], 0)
	var d: Array = Dados.DEDOS[i]
	if d.size() > 0:
		_por(_dedo, d, 0)


## Tudo de uma vez: o quadro, onde o corpo está (a cintura, no mundo), o
## giro e se a bola está na mão (os dedos por cima dela).
func por(i: int, onde: Vector2, giro: float, na_mao: bool) -> void:
	mostrar(i)
	position = onde
	rotation = giro
	dedos.transform = transform
	dedos.visible = visible and na_mao and Dados.DEDOS[i].size() > 0


func _set_luz(v: float) -> void:
	luz = v
	if _brilho != null:
		_brilho.modulate = Color(COR_BRILHO.r, COR_BRILHO.g, COR_BRILHO.b, 0.55 * clamp(v, 0.0, 2.0))


## Desenha cada página uma vez (bem apagada) - a placa de vídeo prepara
## todas antes da apresentação.
func aquecer(sim: bool) -> void:
	if sim and _aquecer.empty():
		for p in _paginas + [_extra]:
			var s := Sprite.new()
			s.texture = p
			s.region_enabled = true
			s.region_rect = Rect2(0, 0, 8, 8)
			s.modulate.a = 0.01
			add_child(s)
			_aquecer.append(s)
	for s in _aquecer:
		s.visible = sim


func _process(_delta: float) -> void:
	# o rastro: o brilho dos quadros de antes, nas posições de antes
	_historico.push_front([get_global_transform(), quadro])
	if _historico.size() > RASTRO * 2 + 1:
		_historico.pop_back()
	for i in _rastros.size():
		var r: Sprite = _rastros[i]
		var k: int = (i + 1) * 2
		if rastro <= 0.01 or not visible or k >= _historico.size():
			r.visible = false
			continue
		var h: Array = _historico[k]
		r.visible = true
		var b: Array = Dados.BRILHO[int(h[1])]
		r.region_rect = Rect2(b[0], b[1], b[2], b[3])
		var e := float(b[6])
		r.global_transform = h[0] * Transform2D(Vector2(e, 0), Vector2(0, e), Vector2(b[4], b[5]))
		var f: float = rastro * 0.4 * (1.0 - float(i + 1) / (RASTRO + 1))
		r.modulate = Color(0.45, 0.65, 1.0, f).linear_interpolate(Color(1.0, 0.5, 0.1, f), float(i) / RASTRO)
