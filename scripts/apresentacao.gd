extends "res://scripts/tela_base.gd"

## APRESENTAÇÃO DO SLAM ARENA (abertura animada, ~11 s), toda desenhada
## em código para a OpenGL ES 2.0:
##   1. começa no EMBLEMA (a bola com brilho e o anel: a mesma imagem de
##      abertura do app e da capa - nenhuma tela preta): o anel explode, a
##      bola some no clarão e o LOGO DA LAZER & SPORT salta no lugar, com
##      um reflexo dourado; GAMES bate letra por letra e APRESENTA;
##   2. a quadra de neon se desenha sozinha no escuro (a grade cintila);
##   3. a bola cai e quica três vezes (cada quique: onda de luz, poeira,
##      a grade inteira treme em onda);
##   4. a cesta de neon se desenha, a bola voa girando e passa pela rede
##      (a rede balança) - SWISH!;
##   5. dois raios caem na cesta, a tela pisca e o pôster SLAM ARENA entra
##      com impacto, faíscas e o brilho atravessando o letreiro;
##   6. segue direto para a abertura (o mesmo pôster: sem corte).
## START pula para a abertura; uma CESTA já começa a partida (sem botão).

const Malhas = preload("res://scripts/fx/malhas.gd")
const Grade = preload("res://scripts/fx/grade.gd")
const OndaLuz = preload("res://scripts/fx/onda_luz.gd")
const Traco = preload("res://scripts/fx/traco_neon.gd")
const Bola = preload("res://scripts/fx/bola.gd")
const Raio = preload("res://scripts/fx/raio_eletrico.gd")
const Rede = preload("res://scripts/fx/rede.gd")

const Emblema = preload("res://scripts/fx/emblema.gd")
const PosterVivo = preload("res://scripts/fx/poster_vivo.gd")

const CHAO := 1520.0
const ARO := Vector2(540, 560)
const LOGO := Vector2(540, 790)
const LOGO_ESCALA := 0.594      # o logo (1280 x 849) com 760 de largura

var _mundo: Node2D
var _grade: Grade
var _ondas: Array = []
var _quadra: Array = []
var _aro_tras: Traco
var _aro_frente: Traco
var _tabela: Traco
var _quadrado: Traco
var _rede: Rede
var _bola: Bola
var _sombra: Sprite
var _poeira: CPUParticles2D
var _faiscas: Array = []
var _raios: Array = []
var _flash: ColorRect
var _emblema: Emblema
var _marca: Node2D             # logo + GAMES + APRESENTA
var _logo: Sprite
var _mat_logo: ShaderMaterial
var _letras: Array = []
var _linha: ColorRect
var _apresenta: Label
var _reflexo_t := -1.0
var _poster_pivo: Node2D
var _poster: Node2D
var _mat_poster: ShaderMaterial
var _r := RandomNumberGenerator.new()

# a bola
var _fase := ""
var _pos := Vector2()
var _vel := Vector2()
var _quiques := 0
var _voo_t := 0.0
var _voo_de := Vector2()
var _tremor := 0.0
var _t := 0.0
var _brilho_t := -1.0
var _onda_i := 0


func _ready() -> void:
	_r.randomize()
	var fundo := ColorRect.new()
	# a mesma cor da capa e da imagem de abertura do app
	fundo.color = ProjectSettings.get_setting("application/boot_splash/bg_color")
	fundo.rect_size = Vector2(LARGURA, ALTURA)
	add_child(fundo)
	_mundo = Node2D.new()
	add_child(_mundo)
	_grade = Grade.new(CHAO)
	_mundo.add_child(_grade)
	# quadra de neon (vista de frente, em perspectiva)
	var linhas := [
		[PoolVector2Array([Vector2(-40, CHAO), Vector2(1120, CHAO)]), Arte.LARANJA, 5.0],
		[Malhas.elipse(Vector2(540, CHAO), Vector2(470, 330), 64, PI, 180.0), Arte.LARANJA, 5.0],
		[PoolVector2Array([Vector2(370, CHAO), Vector2(430, 1170), Vector2(650, 1170), Vector2(710, CHAO)]), Arte.LARANJA_CLARO, 4.0],
		[Malhas.elipse(Vector2(540, 1170), Vector2(110, 36), 48, 0.0, 360.0), Arte.LARANJA_CLARO, 4.0],
		[PoolVector2Array([Vector2(0, 1840), Vector2(1080, 1840)]), Color(1.0, 0.3, 0.02), 6.0],
		[Malhas.elipse(Vector2(540, 1840), Vector2(150, 50), 48, PI, 180.0), Color(1.0, 0.3, 0.02), 5.0],
	]
	for l in linhas:
		var t = Traco.new()
		t.montar(l[0], l[2], 12.0)
		t.cor = l[1]
		t.progresso = 0.0
		_mundo.add_child(t)
		_quadra.append(t)
	# cesta: tabela, quadradinho, aro (atrás e na frente da bola) e rede
	_tabela = Traco.new()
	_tabela.montar(PoolVector2Array([Vector2(330, 300), Vector2(750, 300), Vector2(750, 590), Vector2(330, 590)]), 6.0, 16.0, true)
	_tabela.cor = Color(0.6, 0.85, 1.0)
	_mundo.add_child(_tabela)
	_quadrado = Traco.new()
	_quadrado.montar(PoolVector2Array([Vector2(455, 420), Vector2(625, 420), Vector2(625, 540), Vector2(455, 540)]), 4.0, 10.0, true)
	_quadrado.cor = Color(0.85, 0.95, 1.0)
	_mundo.add_child(_quadrado)
	_aro_tras = Traco.new()
	_aro_tras.montar(Malhas.elipse(ARO, Vector2(120, 26), 40, PI, 180.0), 6.0, 14.0)
	_aro_tras.cor = Arte.LARANJA
	_mundo.add_child(_aro_tras)
	_rede = Rede.new()
	_rede.position = ARO
	_rede.visible = false
	_mundo.add_child(_rede)
	_sombra = Arte.sprite_brilho(Color(0, 0, 0, 0.6), 160.0)
	_sombra.material = null
	_mundo.add_child(_sombra)
	_bola = Bola.new()
	_bola.tamanho(150)
	_bola.velocidade = 4.0
	_bola.visible = false
	_mundo.add_child(_bola)
	_aro_frente = Traco.new()
	_aro_frente.montar(Malhas.elipse(ARO, Vector2(120, 26), 40, 0.0, 180.0), 7.0, 16.0)
	_aro_frente.cor = Arte.LARANJA
	_mundo.add_child(_aro_frente)
	for i in 3:
		var o = OndaLuz.new()
		_mundo.add_child(o)
		_ondas.append(o)
	_poeira = CPUParticles2D.new()
	_poeira.emitting = false
	_poeira.one_shot = true
	_poeira.explosiveness = 0.9
	_poeira.amount = 18
	_poeira.lifetime = 0.9
	_poeira.texture = Arte.tex_fumaca
	_poeira.direction = Vector2(0, -1)
	_poeira.spread = 80.0
	_poeira.initial_velocity = 260.0
	_poeira.initial_velocity_random = 0.5
	_poeira.gravity = Vector2(0, 220)
	_poeira.damping = 120.0
	_poeira.scale_amount = 1.4
	_poeira.scale_amount_random = 0.5
	_poeira.color_ramp = Arte.rampa([Color(1.0, 0.6, 0.3, 0.5), Color(0.5, 0.25, 0.1, 0.0)], [0.0, 1.0])
	_mundo.add_child(_poeira)
	for i in 2:
		var f = Arte.faiscas(60, Color(1.0, 0.7, 0.3) if i == 0 else Color(0.5, 0.8, 1.0))
		_mundo.add_child(f)
		_faiscas.append(f)
	for i in 2:
		var r = Raio.new()
		_mundo.add_child(r)
		_raios.append(r)
	# o pôster (o mesmo da abertura)
	_poster_pivo = Node2D.new()
	_poster_pivo.position = Vector2(540, 960)
	_poster_pivo.visible = false
	add_child(_poster_pivo)
	# (o pôster vivo em Full HD: o mesmo da abertura)
	_poster = PosterVivo.new()
	_poster.position = Vector2(-540, -960)
	_poster_pivo.add_child(_poster)
	_mat_poster = _poster.mat
	# o emblema (igual à capa) e a marca LAZER & SPORT GAMES
	_emblema = Emblema.new()
	_emblema.position = Vector2(540, 960)
	add_child(_emblema)
	_montar_marca()
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1)
	_flash.rect_size = Vector2(LARGURA, ALTURA)
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


func _montar_marca() -> void:
	_marca = Node2D.new()
	add_child(_marca)
	_logo = Sprite.new()
	_logo.texture = load("res://imagens/logo_lazer_sport.png")
	_logo.position = LOGO
	_logo.scale = Vector2.ONE * LOGO_ESCALA
	_mat_logo = Arte.material("res://shaders/brilho_logo.shader")
	_logo.material = _mat_logo
	_marca.add_child(_logo)
	# GAMES: uma letra por vez (cada uma entra batendo)
	var f := Arte.fonte(130, 10)
	var texto := "GAMES"
	var larguras := []
	var total := 0.0
	for ch in texto:
		var w: float = f.get_string_size(ch).x + 24.0
		larguras.append(w)
		total += w
	var x := 540.0 - total * 0.5
	var y := LOGO.y + 849.0 * LOGO_ESCALA * 0.5 - 6.0
	for i in texto.length():
		var l := Arte.texto(texto[i], 130, Arte.LARANJA, 10, Color(0.16, 0.04, 0.0))
		pos(l, x, y, larguras[i], 190)
		l.rect_pivot_offset = Vector2(larguras[i] * 0.5, 95)
		_marca.add_child(l)
		_letras.append(l)
		x += larguras[i]
	_linha = ColorRect.new()
	_linha.color = Arte.LARANJA
	pos(_linha, 540.0 - total * 0.5, y + 186, total, 6)
	_linha.rect_pivot_offset = Vector2(total * 0.5, 3)
	_marca.add_child(_linha)
	_apresenta = Arte.texto("A P R E S E N T A", 40, Color(0.92, 0.92, 1.0), 4, Color(0, 0, 0))
	pos(_apresenta, 0, y + 204, 1080, 64)
	_apresenta.rect_pivot_offset = Vector2(540, 32)
	_marca.add_child(_apresenta)


func aquecer() -> void:
	_marca.visible = true
	_marca.modulate.a = 1.0
	_logo.scale = Vector2.ONE * LOGO_ESCALA
	for l in _letras:
		l.visible = true
	_apresenta.visible = true
	_poster_pivo.visible = true
	_poster.aquecer()
	_bola.visible = true
	_rede.visible = true
	for t in _quadra:
		t.progresso = 1.0
	for o in _ondas:
		o.disparar(Vector2(540, CHAO), 6)
	_faiscas[0].emitting = true
	_poeira.emitting = true
	_raios[0].disparar(Vector2(0, 0), ARO)
	yield(get_tree().create_timer(0.1), "timeout")
	_preparar_cena()


func _preparar_cena() -> void:
	_poster_pivo.visible = false
	_poster.ligar(false)
	_bola.visible = false
	_sombra.visible = false
	_rede.visible = false
	_flash.modulate.a = 0.0
	# começa no emblema, igual à capa (anel cheio)
	_emblema.visible = true
	_emblema.modulate.a = 1.0
	_emblema.scale = Vector2.ONE
	_emblema.progresso = 1.0
	_emblema.bola.velocidade = 2.5
	_emblema.bola.scale = Vector2.ONE * 300.0 / float(_emblema.bola.texture.get_width())
	_marca.visible = false
	_marca.modulate.a = 1.0
	_marca.scale = Vector2.ONE
	_marca.position = Vector2.ZERO
	_logo.scale = Vector2.ONE * LOGO_ESCALA
	# (texto com contorno nunca aparece/some por transparência: o contorno
	# apareceria através da letra; entra e sai por escala)
	for l in _letras:
		l.visible = false
	_linha.rect_scale = Vector2(0, 1)
	_apresenta.visible = false
	_reflexo_t = -1.0
	_mat_logo.set_shader_param("forca", 0.0)
	for t in _quadra:
		t.progresso = 0.0
		t.alfa = 1.0
	for t in [_tabela, _quadrado, _aro_tras, _aro_frente]:
		t.progresso = 0.0
		t.alfa = 1.0
	_grade.limpar()
	# a grade só acende na explosão do emblema (o 1º quadro = a capa)
	_grade.base = 0.0
	_mundo.modulate.a = 1.0
	_fase = ""


func sair() -> void:
	.sair()
	_poster.ligar(false)


func entrar(dados := {}) -> void:
	.entrar(dados)
	_preparar_cena()
	if dados.has("giro_bola"):
		# a mesma volta da bola da capa (a troca não pisca)
		_emblema.bola.set("_giro", float(dados["giro_bola"]))
	_t = 0.0
	Sons.musica("abertura")
	Arduino.led("ATTRACT")
	Tela.medir(false)
	_roteiro()


func _roteiro() -> void:
	var s := sessao
	# 1. o emblema explode e o logo LAZER & SPORT salta no lugar
	_emblema.bola.velocidade = 7.0
	yield(espera(0.3), "timeout")
	if not vale(s):
		return
	Sons.tocar("impacto")
	Sons.tocar("neon", -4.0)
	_tremor = 14.0
	var o: OndaLuz = _ondas[_onda_i]
	_onda_i = (_onda_i + 1) % _ondas.size()
	o.disparar(Vector2(540, 960), 9, 1.3)
	_grade.disparar(Vector2(540, 960), 9)
	var te := create_tween().set_parallel(true)
	te.tween_property(_emblema, "scale", Vector2(2.4, 2.4), 0.45).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	te.tween_property(_emblema, "modulate:a", 0.0, 0.45)
	te.tween_property(_emblema.bola, "scale", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	te.tween_property(_grade, "base", 0.7, 0.5)
	_faiscas[0].position = Vector2(540, 960)
	_faiscas[0].restart()
	_faiscas[0].emitting = true
	_marca.visible = true
	_logo.scale = Vector2.ONE * LOGO_ESCALA * 0.15
	var tl := create_tween()
	tl.tween_property(_logo, "scale", Vector2.ONE * LOGO_ESCALA, 0.5).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	yield(espera(0.6), "timeout")
	if not vale(s):
		return
	_emblema.visible = false
	_reflexo_t = 0.0
	yield(espera(0.2), "timeout")
	if not vale(s):
		return
	# GAMES, letra por letra
	for i in _letras.size():
		var l: Label = _letras[i]
		l.rect_scale = Vector2(2.6, 2.6)
		l.visible = true
		var tg := create_tween()
		tg.tween_property(l, "rect_scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sons.tocar("tique", -2.0, 0.9 + i * 0.12)
		yield(espera(0.08), "timeout")
		if not vale(s):
			return
	yield(espera(0.12), "timeout")
	if not vale(s):
		return
	Sons.tocar("sobe", -6.0, 1.2)
	_tremor = 8.0
	var ta := create_tween().set_parallel(true)
	ta.tween_property(_linha, "rect_scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_apresenta.rect_scale = Vector2(1.4, 0.05)
	ta.tween_callback(_apresenta, "show").set_delay(0.2)
	ta.tween_property(_apresenta, "rect_scale", Vector2.ONE, 0.4).set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	yield(espera(0.85), "timeout")
	if not vale(s):
		return
	_reflexo_t = 0.0
	yield(espera(1.0), "timeout")
	if not vale(s):
		return
	var tf := create_tween().set_parallel(true)
	# a marca "implode" para o centro da tela (escala e posição juntas)
	tf.tween_property(_marca, "scale", Vector2.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tf.tween_property(_marca, "position", Vector2(540, 960), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	# 2. a quadra se desenha
	yield(espera(0.3), "timeout")
	if not vale(s):
		return
	Sons.tocar("vento")
	for i in _quadra.size():
		_quadra[i].desenhar(0.9, i * 0.12)
	_grade.disparar(Vector2(540, CHAO), 1, true, Arte.LARANJA)
	yield(espera(1.2), "timeout")
	if not vale(s):
		return
	# 3. a bola cai e quica
	_pos = Vector2(540, -120)
	_vel = Vector2(0, 300)
	_quiques = 0
	_bola.visible = true
	_bola.scale = Vector2.ONE * 150.0 / 4.0
	_sombra.visible = true
	_fase = "cai"
	yield(espera(2.1), "timeout")
	if not vale(s):
		return
	# 4. a cesta se desenha e a bola voa até ela
	Sons.tocar("neon", -6.0)
	_tabela.desenhar(0.5)
	_quadrado.desenhar(0.4, 0.2)
	_aro_tras.desenhar(0.35, 0.3)
	_aro_frente.desenhar(0.35, 0.3)
	_rede.visible = true
	_rede.modulate.a = 0.0
	var tr := create_tween()
	tr.tween_property(_rede, "modulate:a", 1.0, 0.4).set_delay(0.4)
	yield(espera(0.7), "timeout")
	if not vale(s):
		return
	_voo_de = _pos
	_voo_t = 0.0
	_fase = "voa"
	_bola.velocidade = 11.0
	Sons.tocar("vento", -2.0, 1.3)
	yield(espera(1.0), "timeout")
	if not vale(s):
		return
	# 5. raios, flash e o pôster
	Sons.tocar("trovao")
	Arduino.led("RECORD")
	_raios[0].disparar(Vector2(60, -20), ARO + Vector2(-30, 0), 0.45)
	_raios[1].disparar(Vector2(1020, -20), ARO + Vector2(30, 0), 0.45)
	_tremor = 22.0
	yield(espera(0.25), "timeout")
	if not vale(s):
		return
	_flash.modulate.a = 1.0
	Sons.tocar("impacto")
	_poster_pivo.visible = true
	_poster.ligar(true)
	_poster.relampejar()
	_poster_pivo.scale = Vector2(1.3, 1.3)
	_mat_poster.set_shader_param("escurecer", 0.0)
	_mat_poster.set_shader_param("relampago", 1.0)
	var tp := create_tween().set_parallel(true)
	tp.tween_property(_flash, "modulate:a", 0.0, 0.5)
	tp.tween_property(_poster_pivo, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tp.tween_property(_mundo, "modulate:a", 0.0, 0.3)
	tp.tween_method(self, "_relampago", 1.0, 0.0, 0.8)
	for i in 2:
		_faiscas[i].position = Vector2(540, 1150)
		_faiscas[i].restart()
		_faiscas[i].emitting = true
	_tremor = 26.0
	_brilho_t = 0.0
	yield(espera(2.0), "timeout")
	if not vale(s):
		return
	Arduino.led("ATTRACT")
	ir("abertura", {"sem_escuro": true, "da_apresentacao": true})


func _relampago(v: float) -> void:
	_mat_poster.set_shader_param("relampago", v)


func _quique(forca: float) -> void:
	var o: OndaLuz = _ondas[_onda_i]
	_onda_i = (_onda_i + 1) % _ondas.size()
	o.disparar(Vector2(_pos.x, CHAO), 1 + _quiques * 3, clamp(forca, 0.3, 1.3))
	_grade.disparar(Vector2(_pos.x, CHAO), 1 + _quiques * 3)
	_poeira.position = Vector2(_pos.x, CHAO)
	_poeira.restart()
	_poeira.emitting = true
	Sons.tocar("impacto", linear2db(clamp(forca, 0.2, 1.0)))
	_tremor = 14.0 * forca


func _process(delta: float) -> void:
	_t += delta
	var r := 75.0
	match _fase:
		"cai":
			_vel.y += 4200.0 * delta
			_pos += _vel * delta
			if _pos.y >= CHAO - r:
				_pos.y = CHAO - r
				var v := _vel.y
				if v > 500.0 and _quiques < 4:
					_quiques += 1
					_vel.y = -v * 0.62
					_quique(v / 2600.0)
					_bola.scale = Vector2(1.25, 0.72) * 150.0 / 4.0
				else:
					_vel = Vector2.ZERO
					_fase = "parada"
			_bola.scale = _bola.scale.linear_interpolate(Vector2.ONE * 150.0 / 4.0, clamp(delta * 14.0, 0.0, 1.0))
		"voa":
			_voo_t += delta / 0.85
			var t: float = min(_voo_t, 1.0)
			var alvo := ARO + Vector2(0, -10)
			var meio := Vector2(lerp(_voo_de.x, alvo.x, 0.5) + 120.0, min(_voo_de.y, alvo.y) - 520.0)
			var a := _voo_de.linear_interpolate(meio, t)
			var b := meio.linear_interpolate(alvo, t)
			_pos = a.linear_interpolate(b, t)
			_bola.scale = Vector2.ONE * lerp(150.0, 104.0, t) / 4.0
			if _voo_t >= 1.0:
				_fase = "rede"
				_voo_t = 0.0
				_rede.balancar(1.0)
				Sons.tocar("swish")
				Arduino.led("HIT")
				var o: OndaLuz = _ondas[_onda_i]
				_onda_i = (_onda_i + 1) % _ondas.size()
				o.disparar(ARO, 9, 1.2)
				_grade.disparar(ARO, 9)
				_faiscas[0].position = ARO
				_faiscas[0].restart()
				_faiscas[0].emitting = true
		"rede":
			_voo_t += delta
			_pos = ARO + Vector2(0, -10 + 260.0 * _voo_t)
			_bola.modulate.a = clamp(1.0 - _voo_t * 2.0, 0.0, 1.0)
			if _voo_t > 0.6:
				_fase = ""
				_bola.visible = false
				_bola.modulate.a = 1.0
	_bola.position = _pos
	_sombra.position = Vector2(_pos.x, CHAO + 6)
	_sombra.scale = Vector2(1.6, 0.35) * clamp(1.0 - (CHAO - _pos.y) / 900.0, 0.2, 1.0) * 160.0 / 64.0
	_sombra.visible = _bola.visible and _fase != "rede" and _fase != "voa"
	# tremor
	if _tremor > 0.1:
		_mundo.position = Vector2(_r.randf_range(-1, 1), _r.randf_range(-1, 1)) * _tremor
		_poster_pivo.position = Vector2(540, 960) + _mundo.position * 0.6
		_tremor = max(0.0, _tremor - delta * 70.0)
	else:
		_mundo.position = Vector2.ZERO
		_poster_pivo.position = Vector2(540, 960)
	# reflexo dourado atravessando o logo da Lazer & Sport
	if _reflexo_t >= 0.0:
		_reflexo_t += delta
		var k: float = _reflexo_t / 0.8
		_mat_logo.set_shader_param("pos", lerp(-0.3, 1.6, k))
		_mat_logo.set_shader_param("forca", 1.0)
		if k >= 1.0:
			_reflexo_t = -1.0
			_mat_logo.set_shader_param("forca", 0.0)
	# brilho no letreiro do pôster
	if _brilho_t >= 0.0:
		_brilho_t += delta
		_mat_poster.set_shader_param("brilho_forca", 1.2)
		_mat_poster.set_shader_param("brilho_pos", lerp(-300.0, 2500.0, _brilho_t / 1.3))
		if _brilho_t > 1.3:
			_brilho_t = -1.0
			_mat_poster.set_shader_param("brilho_pos", -2000.0)


func _unhandled_input(event: InputEvent) -> void:
	if not ativo:
		return
	if Controles.credito(event):
		Ajustes.adicionar_credito(1)
		Sons.tocar("moeda")
		ir("abertura", {})
	elif Controles.cesta(event) and Ajustes.pode_jogar():
		Ajustes.gastar_credito()
		Arduino.led("STARTING")
		Sons.tocar("selecao")
		ir("jogo", {})
	elif Controles.config(event) or Controles.pede_config(event):
		# controle remoto da TV Box: direto para a configuração
		ir("config", {})
	elif Controles.start(event) or Controles.cesta(event):
		ir("abertura", {})
