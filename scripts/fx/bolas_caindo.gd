extends Node2D

## BOLAS QUE SAEM DA CESTA E CAEM PARA FORA DA TELA: a cada cesta a bola
## aparece logo abaixo da faixa da fase (é a bola que acabou de passar pela
## rede), cai na quadra lá no fundo e quica vindo para a frente - cresce,
## porque a quadra está em perspectiva - até sair pela borda de baixo, como
## se caísse para fora da máquina. Com muitas cestas seguidas saem várias,
## abrindo para os lados; no SLAM MODE vêm com rastro de fogo azul e no
## recorde (ou na bola de ouro) são de ouro. Cada quique acende um anel no
## piso e faz o "toc" da bola na quadra.
##
## Leve: um conjunto fixo de bolas, montado na preparação; por quadro só
## mudam posição, escala e transparência das que estão no ar.

const Bola = preload("res://scripts/fx/bola.gd")
# a mesma perspectiva do piso (grade.gd): as laterais da quadra fogem para
# FUGA; s = 1 na linha de fundo (TOPO_PISO), s ~ 2 na borda de baixo
const FUGA := Vector2(540, 88)
const TOPO_PISO := 994.0
const G := 1500.0             # gravidade (px do fundo da quadra / s²)
const RAIO := 31.0            # raio da bola no fundo da quadra (px)
const SAIDA_Y := 905.0        # onde a bola aparece (logo abaixo da faixa da fase)
const N := 12

enum { NORMAL, FOGO, OURO }

var _bolas := []
var _aneis := []
var _anel_prox := 0
var _vivas := 0
var _r := RandomNumberGenerator.new()


func _ready() -> void:
	_r.randomize()
	# camadas: anéis do piso e sombras por baixo, depois rastros e brilhos,
	# as bolas por cima
	for i in 6:
		var a := Arte.sprite_brilho(Color(1, 0.6, 0.2), 200.0, Arte.tex_anel)
		a.visible = false
		add_child(a)
		_aneis.append(a)
	for i in N:
		var sombra := Sprite.new()
		sombra.texture = Arte.tex_brilho
		sombra.visible = false
		add_child(sombra)
		_bolas.append({"sombra": sombra, "viva": false})
	for b in _bolas:
		var rastro := Arte.sprite_brilho(Color(1, 0.5, 0.1), 100.0, Arte.tex_feixe)
		rastro.offset = Vector2(0, -float(Arte.tex_feixe.get_height()) * 0.5)
		rastro.visible = false
		add_child(rastro)
		b["rastro"] = rastro
		var brilho := Arte.sprite_brilho(Color(1, 0.6, 0.2), 100.0)
		brilho.visible = false
		add_child(brilho)
		b["brilho"] = brilho
	for b in _bolas:
		var bola = Bola.new()
		bola.visible = false
		bola.set_process(false)
		add_child(bola)
		b["bola"] = bola
	set_process(false)


## Solta "n" bolas da cesta (cor: do combo; tipo: NORMAL, FOGO, OURO).
func soltar(n: int, cor: Color, tipo := NORMAL) -> void:
	for i in n:
		var b: Dictionary = _livre()
		var lado := float(i) - float(n - 1) * 0.5
		b["x"] = _r.randf_range(-24.0, 24.0) + lado * 30.0
		b["h"] = TOPO_PISO - SAIDA_Y
		b["s"] = 1.0
		b["vx"] = lado * 190.0 + _r.randf_range(-70.0, 70.0)
		b["vh"] = -_r.randf_range(40.0, 260.0)
		b["vs"] = _r.randf_range(0.42, 0.58)
		b["espera"] = i * 0.08
		b["t"] = 0.0
		b["quiques"] = 0
		b["tipo"] = tipo
		b["cor"] = cor
		b["viva"] = true
		var bola = b["bola"]
		bola.ouro(1.0 if tipo == OURO else 0.0)
		bola.velocidade = _r.randf_range(7.0, 11.0) * (1.0 if _r.randf() < 0.5 else -1.0)
		var c: Color = Color(0.35, 0.8, 1.0) if tipo == FOGO else (Arte.OURO if tipo == OURO else cor)
		b["brilho"].modulate = Color(c.r, c.g, c.b, 0.0)
		b["rastro"].modulate = Color(c.r, c.g, c.b, 0.0)
		b["rastro"].visible = tipo != NORMAL
		_posicionar(b)
	_vivas = _contar()
	set_process(true)


## Some com todas (começo de fase, resultado).
func limpar() -> void:
	for b in _bolas:
		_apagar(b)
	for a in _aneis:
		a.visible = false
	_vivas = 0
	set_process(false)


func _livre() -> Dictionary:
	var mais_velha: Dictionary = _bolas[0]
	for b in _bolas:
		if not b["viva"]:
			return b
		if b["t"] > mais_velha["t"]:
			mais_velha = b
	return mais_velha


func _contar() -> int:
	var n := 0
	for b in _bolas:
		if b["viva"]:
			n += 1
	return n


func _process(delta: float) -> void:
	for b in _bolas:
		if b["viva"]:
			_mover(b, delta)
	for a in _aneis:
		if a.visible:
			a.modulate.a -= delta * 2.2
			a.scale *= 1.0 + delta * 2.6
			if a.modulate.a <= 0.0:
				a.visible = false
	if _contar() == 0:
		var algum_anel := false
		for a in _aneis:
			algum_anel = algum_anel or a.visible
		if not algum_anel:
			set_process(false)


func _mover(b: Dictionary, delta: float) -> void:
	if b["espera"] > 0.0:
		b["espera"] -= delta
		return
	b["t"] += delta
	# vem para a frente (a escala da perspectiva cresce cada vez mais rápido)
	b["s"] += b["vs"] * delta * b["s"] * b["s"]
	b["x"] += b["vx"] * delta
	b["vh"] -= G * delta
	b["h"] += b["vh"] * delta
	if b["h"] <= 0.0 and b["vh"] < 0.0:
		b["h"] = 0.0
		var forca: float = abs(b["vh"])
		b["vh"] = forca * 0.56 if forca > 140.0 else 0.0
		b["quiques"] += 1
		_quique(b, forca)
	_posicionar(b)
	var bola = b["bola"]
	var y: float = bola.position.y - RAIO * b["s"]
	if y > 1960.0 or bola.position.x < -160.0 or bola.position.x > 1240.0:
		_apagar(b)


func _posicionar(b: Dictionary) -> void:
	var s: float = b["s"]
	var chao := Vector2(FUGA.x + b["x"] * s, FUGA.y + (TOPO_PISO - FUGA.y) * s)
	var p := chao - Vector2(0, b["h"] * s)
	var raio := RAIO * s
	var aparece: float = clamp(b["t"] / 0.12, 0.0, 1.0)
	var bola = b["bola"]
	var esperando: bool = b["espera"] > 0.0
	bola.visible = not esperando
	bola.set_process(not esperando)
	bola.position = p
	bola.tamanho(raio * 2.0 * lerp(0.6, 1.0, aparece))
	bola.modulate.a = aparece
	# sombra no chão: menor e mais fraca com a bola no alto
	var sombra: Sprite = b["sombra"]
	sombra.visible = not esperando
	var alto: float = clamp(b["h"] / 260.0, 0.0, 1.0)
	var lado := raio * 2.6 * (1.0 - alto * 0.4) / float(Arte.tex_brilho.get_width())
	sombra.position = chao + Vector2(0, raio * 0.15)
	sombra.scale = Vector2(lado, lado * 0.36)
	sombra.modulate = Color(0, 0, 0, 0.6 * (1.0 - alto * 0.6) * aparece)
	# brilho em volta (combo, fogo, ouro)
	var tipo: int = b["tipo"]
	var brilho: Sprite = b["brilho"]
	brilho.visible = not esperando
	brilho.position = p
	brilho.scale = Vector2.ONE * raio * (4.2 if tipo != NORMAL else 3.2) / float(Arte.tex_brilho.get_width())
	brilho.modulate.a = (0.55 if tipo != NORMAL else 0.28) * aparece
	# rastro (fogo / ouro): o cone aponta para trás do movimento
	var rastro: Sprite = b["rastro"]
	if tipo != NORMAL and not esperando:
		var v := Vector2(b["vx"] * s, -b["vh"] * s + b["vs"] * s * s * (TOPO_PISO - FUGA.y - b["h"]))
		var veloc := v.length()
		if veloc > 1.0:
			var d := v / veloc
			rastro.rotation = atan2(-d.x, d.y)
			rastro.position = p
			var w := raio * 2.2 / float(Arte.tex_feixe.get_width())
			rastro.scale = Vector2(w, clamp(veloc * 0.10, raio, raio * 6.0) / float(Arte.tex_feixe.get_height()))
			rastro.modulate.a = 0.75 * aparece


func _quique(b: Dictionary, forca: float) -> void:
	var s: float = b["s"]
	var chao := Vector2(FUGA.x + b["x"] * s, FUGA.y + (TOPO_PISO - FUGA.y) * s)
	var a: Sprite = _aneis[_anel_prox]
	_anel_prox = (_anel_prox + 1) % _aneis.size()
	var tipo: int = b["tipo"]
	var c: Color = Color(0.35, 0.8, 1.0) if tipo == FOGO else (Arte.OURO if tipo == OURO else b["cor"])
	a.visible = true
	a.position = chao
	var lado := RAIO * s * 3.0 / float(Arte.tex_anel.get_width())
	a.scale = Vector2(lado, lado * 0.38)
	a.modulate = Color(c.r, c.g, c.b, clamp(forca / 700.0, 0.25, 0.9))
	if b["quiques"] <= 2:
		Sons.tocar("quique", -6.0 - b["quiques"] * 5.0 + clamp(forca / 120.0, 0.0, 4.0), _r.randf_range(0.92, 1.08) / sqrt(s))


func _apagar(b: Dictionary) -> void:
	b["viva"] = false
	b["bola"].visible = false
	b["bola"].set_process(false)
	b["sombra"].visible = false
	b["brilho"].visible = false
	b["rastro"].visible = false
