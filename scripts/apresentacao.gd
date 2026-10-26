extends "res://scripts/tela_base.gd"

## APRESENTAÇÃO DO SLAM ARENA (abertura animada, ~11 s), toda desenhada
## em código para a OpenGL ES 2.0:
##   1. começa no EMBLEMA (a bola com brilho e o anel: a mesma imagem de
##      abertura do app e da capa - nenhuma tela preta): o anel explode, a
##      bola some no clarão e o LOGO DA LAZER & SPORT salta no lugar, com
##      um reflexo dourado; GAMES bate letra por letra e APRESENTA;
##   2. a quadra de neon se desenha sozinha no escuro (a grade cintila);
##   3. a BOLA DE FOGO quica três vezes, cada vez mais forte (cada quique:
##      raios no chão, onda de luz, poeira, a grade treme), com a SOMBRA do
##      jogador correndo no chão; a cesta de neon se desenha; o último
##      quique manda a bola lá para o alto;
##   4. CORTE (clarão): o JOGADOR DA CAPA - o próprio, recortado do pôster
##      (regata, short, tênis, a bola de fogo) - entra voando, a câmera
##      enquadra igual ao pôster e ele sobe em CÂMERA LENTA até a pose da
##      capa; o braço gira e ele ENTERRA: o aro verga, a rede balança,
##      faíscas, raios em volta da bola;
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
const JogadorCapa = preload("res://scripts/fx/jogador_capa.gd")
const PosterVivo = preload("res://scripts/fx/poster_vivo.gd")

const CHAO := 1520.0
const ARO := Vector2(540, 560)
const LOGO := Vector2(540, 790)
const LOGO_ESCALA := 0.594      # o logo (1280 x 849) com 760 de largura

# o jogador da capa (tempos em segundos, a partir da bola de fogo)
const BOLA_FOGO := 104.0        # a bola dos quiques
const QUIQUES := [[0.42, 300.0, 0.6], [1.0, 450.0, 0.85], [1.52, 590.0, 1.25]]   # quando, onde, força
const T_CORTE := 1.86           # o corte (clarão) e o jogador entra
const T_ENTRA := 0.42           # entra voando
const T_LENTO := 0.95           # câmera lenta até a pose da capa
const T_ENTERRA := 0.32         # a enterrada: o braço passa por cima e a bola entra
const T_IMPACTO := T_CORTE + T_ENTRA + T_LENTO + T_ENTERRA
const ESCALA_CAPA := 1080.0 / 941.0
# depois do corte a câmera enquadra como o pôster: o aro onde ele fica na
# capa, do tamanho de lá
const ARO_CAPA := Vector2(884, 282)
const ZOOM_CAPA := 1.1
const ZOOM_LENTO := 1.15

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

# o jogador da capa
var _jog                        # JogadorCapa (o da capa, colorido)
var _jog_sombra                 # JogadorCapa escuro (a sombra no chão)
var _bola_fogo: Sprite          # o brilho de fogo em volta da bola
var _chamas: CPUParticles2D     # o fogo saindo da bola
var _raio_chao: Raio
var _raios_bola: Array = []     # raios pequenos em volta da bola (câmera lenta)
var _jt := 0.0
var _jparte := ""
var _jquique := -1
var _jq0 := Vector2()           # onde o jogador estava quando a parte começou
var _bola_solta := false
var _bola_vel := Vector2()
var _zoom := 1.0
var _cam := Vector2()           # deslocamento da câmera (o tremor vai por cima)
var _aro_t := -1.0
var _raio_t := 0.0
var _bola_base := 1.0           # a escala da bola sem amassar

# a bola
var _fase := ""
var _pos := Vector2()
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
	_bola_fogo = Arte.sprite_brilho(Color(1.0, 0.5, 0.1, 0.9), 300.0)
	_bola_fogo.visible = false
	_mundo.add_child(_bola_fogo)
	_chamas = CPUParticles2D.new()
	_chamas.texture = Arte.tex_brilho
	_chamas.material = Arte.mat_aditivo
	_chamas.local_coords = false
	_chamas.amount = 60
	_chamas.lifetime = 0.45
	_chamas.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_chamas.emission_sphere_radius = 40.0
	_chamas.direction = Vector2(0, -1)
	_chamas.spread = 40.0
	_chamas.gravity = Vector2(0, -260)
	_chamas.initial_velocity = 60.0
	_chamas.initial_velocity_random = 0.6
	_chamas.scale_amount = 0.9
	_chamas.scale_amount_random = 0.5
	_chamas.color_ramp = Arte.rampa([Color(1.0, 0.9, 0.5, 0.9), Color(1.0, 0.45, 0.05, 0.7), Color(0.6, 0.05, 0.0, 0.0)], [0.0, 0.4, 1.0])
	_chamas.emitting = false
	_mundo.add_child(_chamas)
	_bola = Bola.new()
	_bola.tamanho(150)
	_bola.velocidade = 4.0
	_bola.visible = false
	_mundo.add_child(_bola)
	_aro_frente = Traco.new()
	_aro_frente.montar(Malhas.elipse(ARO, Vector2(120, 26), 40, 0.0, 180.0), 7.0, 16.0)
	_aro_frente.cor = Arte.LARANJA
	_mundo.add_child(_aro_frente)
	# o jogador da capa (na frente do aro: o braço passa por cima dele)
	_jog = JogadorCapa.new()
	_jog.visible = false
	_mundo.add_child(_jog)
	# a sombra dele no chão (o mesmo jogador, escuro e deitado)
	_jog_sombra = JogadorCapa.new()
	_jog_sombra.luz = 0.0
	_jog_sombra.modulate = Color(0, 0, 0, 0.82)
	_jog_sombra.visible = false
	_mundo.add_child(_jog_sombra)
	_mundo.move_child(_jog_sombra, _tabela.get_index())
	_raio_chao = Raio.new()
	_raio_chao.cor = Color(0.4, 0.8, 1.0)
	_mundo.add_child(_raio_chao)
	for i in 2:
		var rb = Raio.new()
		rb.cor = Color(1.0, 0.6, 0.2) if i == 0 else Color(0.45, 0.8, 1.0)
		_mundo.add_child(rb)
		_raios_bola.append(rb)
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
	_raio_chao.disparar(Vector2(100, CHAO), Vector2(400, CHAO))
	_raios_bola[0].disparar(Vector2(100, 600), Vector2(300, 700))
	_jog.visible = true
	_jog.position = Vector2(100, 400)
	_jog.rastro = 1.0
	_jog.brasas(true)
	_jog_sombra.visible = true
	_bola_fogo.visible = true
	_chamas.emitting = true
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
	_jog.visible = false
	_jog.rastro = 0.0
	_jog.brasas(false)
	_jog.na_mao = true
	_jog.pose(JogadorCapa.CAPA)
	_jog.rotation = 0.0
	_jog_sombra.visible = false
	_bola_fogo.visible = false
	_chamas.emitting = false
	_bola_solta = false
	_zoom = 1.0
	_cam = Vector2.ZERO
	_aro_t = -1.0
	_bola.modulate.a = 1.0
	for n in [_aro_tras, _aro_frente, _rede]:
		n.position.y = 0.0 if n != _rede else ARO.y
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
	# 3. a BOLA DE FOGO quica (a sombra do jogador corre no chão) e
	# 4. CORTE: o jogador da capa voa, câmera lenta, ENTERRA (no _process)
	_jt = 0.0
	_jparte = ""
	_jquique = -1
	_bola_solta = false
	_bola.visible = true
	_bola.modulate.a = 1.0
	_bola.tamanho(BOLA_FOGO)
	_bola_base = _bola.scale.x
	_bola.velocidade = 6.0
	_bola_fogo.visible = true
	_chamas.emitting = true
	_sombra.visible = true
	_sombra_jogador(0.0)
	_jog_sombra.visible = true
	_bola_na_frente(true)
	_fase = "jogador"
	Sons.tocar("vento", -4.0, 1.4)
	yield(espera(0.55), "timeout")
	if not vale(s):
		return
	# a cesta se desenha enquanto a bola quica
	Sons.tocar("neon", -6.0)
	_tabela.desenhar(0.5)
	_quadrado.desenhar(0.4, 0.2)
	_aro_tras.desenhar(0.35, 0.3)
	_aro_frente.desenhar(0.35, 0.3)
	_rede.visible = true
	_rede.modulate.a = 0.0
	var tr := create_tween()
	tr.tween_property(_rede, "modulate:a", 1.0, 0.4).set_delay(0.4)
	yield(espera(T_IMPACTO - 0.55 + 0.34), "timeout")
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


# ================================================================ o jogador
## A bola na frente do jogador ou atrás do aro da frente (passando pela
## cesta).
func _bola_na_frente(sim: bool) -> void:
	# o fogo logo atrás da bola
	_mundo.remove_child(_bola_fogo)
	_mundo.remove_child(_bola)
	var i: int = _jog.get_index() + 1 if sim else _aro_frente.get_index()
	_mundo.add_child(_bola_fogo)
	_mundo.move_child(_bola_fogo, i)
	_mundo.add_child(_bola)
	_mundo.move_child(_bola, i + 1)


static func _suave(k: float) -> float:
	k = clamp(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


## Onde o jogador fica no mundo para aparecer na tela num ponto e numa
## escala (a câmera desta hora: _cam e _zoom).
func _da_tela(p: Vector2) -> Vector2:
	return (p - _cam) / _zoom


## A câmera igual ao pôster: o aro onde ele fica na capa.
func _camera_capa(zoom: float) -> void:
	_zoom = zoom
	_cam = ARO_CAPA - ARO * zoom


func _animar_jogador(delta: float) -> void:
	_jt += delta
	var t := _jt
	if t < T_CORTE:
		# 3. a bola de fogo quica (cada vez mais forte) e sobe lá para o alto
		var x0 := -60.0
		var y0 := 760.0
		var t0 := 0.0
		var pos := Vector2()
		var feito := false
		for i in QUIQUES.size():
			var q: Array = QUIQUES[i]
			if t < q[0]:
				var u: float = (t - t0) / (q[0] - t0)
				var chao := CHAO - BOLA_FOGO * 0.5
				if i == 0:
					pos = Vector2(lerp(x0, q[1], u), lerp(y0, chao, u * u))
				else:
					var altura: float = 420.0 * QUIQUES[i - 1][2]
					pos = Vector2(lerp(x0, q[1], u), chao - 4.0 * altura * u * (1.0 - u))
				feito = true
				break
			x0 = q[1]
			t0 = q[0]
			if _jquique < i:
				_jquique = i
				_quique_fogo(q[1], q[2], i)
		if not feito:
			# o último quique manda a bola lá para o alto (sai da tela)
			var u: float = (t - t0) / (T_CORTE - t0)
			pos = Vector2(x0 + 140.0 * u, CHAO - BOLA_FOGO * 0.5 - (CHAO + 300.0) * (1.0 - (1.0 - u) * (1.0 - u)))
		_pos = pos
		# a sombra do jogador: deitada no chão, correndo atrás da bola
		_sombra_jogador(t / T_CORTE)
		# (a sombra corre: as pernas e os braços balançam)
		var passo := sin(t * 6.0)
		_jog_sombra.pose({"pernas": 10.0 * passo, "tronco": -4.0, "ombro_e": -20.0 + 15.0 * passo,
			"cotovelo_e": 15.0, "ombro_d": 18.0 * abs(passo), "cotovelo_d": 10.0})
		return
	if _jparte == "":
		_corte()
	var hero_pos := _da_tela(Vector2.ZERO)
	var hero_esc := ESCALA_CAPA / _zoom
	if t < T_CORTE + T_ENTRA:
		# 4. ele entra voando de baixo (rápido) - a bola já na mão
		var k: float = (t - T_CORTE) / T_ENTRA
		var e := 1.0 - pow(1.0 - k, 3.0)
		_jog.position = hero_pos + _da_tela(Vector2(-420, 980)).linear_interpolate(_da_tela(Vector2(-70, 110)), e) - _da_tela(Vector2.ZERO)
		_jog.scale = Vector2.ONE * hero_esc * lerp(0.86, 0.98, e)
		_jog.rotation = lerp(-0.12, -0.03, e)
		# o corpo inteiro: decolando, subindo e chegando na pose da capa
		_jog.pose_entre([JogadorCapa.DECOLAGEM, JogadorCapa.SUBINDO, JogadorCapa.CAPA], min(e * 1.15, 1.0))
		_jog.rastro = 1.0
		_jog.luz = lerp(1.6, 1.0, e)
	elif t < T_IMPACTO - T_ENTERRA:
		# 5. CÂMERA LENTA até a pose da capa (a câmera chega perto)
		if _jparte != "lento":
			_jparte = "lento"
			_jq0 = _jog.position
			Sons.tocar("sobe", -4.0, 0.8)
		var k: float = (t - T_CORTE - T_ENTRA) / T_LENTO
		var z: float = lerp(ZOOM_CAPA, ZOOM_LENTO, _suave(k))
		_camera_capa(z)
		hero_pos = _da_tela(Vector2.ZERO)
		hero_esc = ESCALA_CAPA / _zoom
		var e := _suave(k)
		_jog.position = _jq0.linear_interpolate(hero_pos, e)
		_jog.scale = Vector2.ONE * hero_esc * lerp(0.98, 1.0, e)
		_jog.rotation = lerp(-0.03, 0.0, e)
		_jog.pose(JogadorCapa.CAPA)
		_jog.rastro = lerp(0.6, 0.0, k)
		_jog.luz = 1.0 + 0.25 * sin(k * PI)
		# a energia: raios pequenos em volta da bola, de vez em quando
		_raio_t -= delta
		if _raio_t <= 0.0:
			_raio_t = _r.randf_range(0.12, 0.25)
			var c: Vector2 = _jog.bola_na_mao()
			var rb: Raio = _raios_bola[_r.randi() % 2]
			var a := _r.randf() * TAU
			var r: float = _jog.raio_bola() * 1.1
			rb.disparar(c + Vector2(cos(a), sin(a)) * r, c + Vector2(cos(a + 1.6), sin(a + 1.6)) * r * 1.5, 0.16)
	elif t < T_IMPACTO:
		# 6. a ENTERRADA: o braço gira por cima da cabeça e a bola vai ao aro
		if _jparte != "enterra":
			_jparte = "enterra"
			_jq0 = _jog.position
			_jog.rastro = 1.0
			Sons.tocar("vento", -2.0, 1.5)
		var k: float = (t - (T_IMPACTO - T_ENTERRA)) / T_ENTERRA
		var e := k * k
		_jog.rotation = lerp(0.0, 0.05, e)
		# o corpo inteiro na enterrada: o braço passa por cima da cabeça,
		# o tronco vem para a frente, o outro braço vai para trás
		_jog.pose_entre(JogadorCapa.ENTERRADA, e)
		# o corpo vai junto até a bola chegar no aro
		var alvo := ARO + Vector2(4, 12)
		_jog.position = Vector2.ZERO
		var b: Vector2 = _jog.bola_na_mao()
		var fim := alvo - b
		_jog.position = _jq0.linear_interpolate(fim, e)
		_jog.luz = 1.3
	else:
		# 7. pendurado no aro; a bola de fogo cai pela rede
		if _jparte != "pendura":
			_jparte = "pendura"
			_jq0 = _jog.position
			_impacto_enterrada()
		var k: float = min((t - T_IMPACTO) / 0.6, 1.0)
		_jog.pose(JogadorCapa.misturar(JogadorCapa.ENTERRADA[JogadorCapa.ENTERRADA.size() - 1], JogadorCapa.PENDURADO, _suave(k)))
		_jog.rotation = lerp(0.05, 0.02, _suave(k)) + sin((t - T_IMPACTO) * 9.0) * 0.03 * (1.0 - k)
		# a mão fica presa no aro (onde a bola entrou) e o corpo fica
		# pendurado embaixo dela, balançando
		_jog.position = Vector2.ZERO
		_jog.position = ARO + Vector2(4, 12) - _jog.bola_na_mao()
		_jog.rastro = max(0.0, 1.0 - (t - T_IMPACTO) * 4.0)
		_jog.luz = 1.0 + 0.8 * max(0.0, 1.0 - (t - T_IMPACTO) * 3.0)
	if _jog.na_mao:
		_pos = _jog.bola_na_mao()
	# a bola solta caindo pela rede
	if _bola_solta:
		_bola_vel.y += 2600.0 * delta
		_pos += _bola_vel * delta
		if _pos.y > ARO.y + 230.0 and _bola.get_index() < _jog.get_index():
			_bola_na_frente(true)
		if _pos.y >= CHAO - BOLA_FOGO * 0.5 and _bola_vel.y > 0.0:
			_pos.y = CHAO - BOLA_FOGO * 0.5
			_bola_vel.y = -_bola_vel.y * 0.45
			_quique_fogo(_pos.x, 0.7, 1)


## A sombra do jogador deitada na quadra (a luz vem de trás da cesta),
## correndo atrás da bola.
func _sombra_jogador(corre: float) -> void:
	_jog_sombra.transform = Transform2D(Vector2(0, 0.24), Vector2(-0.62, 0), Vector2(lerp(500.0, 820.0, corre), CHAO - 175.0))


## O CORTE: clarão, a câmera enquadra como o pôster, o jogador da capa
## entra (com a bola na mão: pegou lá em cima) e a bola de fogo some (é a
## dele agora).
func _corte() -> void:
	_jparte = "entra"
	_flash.modulate.a = 0.9
	var tf := create_tween()
	tf.tween_property(_flash, "modulate:a", 0.0, 0.3)
	_camera_capa(ZOOM_CAPA)
	_jog_sombra.visible = false
	_bola.visible = false
	_bola_fogo.visible = false
	_chamas.emitting = false
	_sombra.visible = false
	_jog.visible = true
	_jog.na_mao = true
	_jog.brasas(true)
	Sons.tocar("impacto", -2.0)
	Sons.tocar("sobe", -6.0, 1.3)
	_tremor = 10.0


## Um quique da bola de fogo: raios correndo pelo chão, onda de luz,
## poeira, faíscas, a grade treme (cada vez mais forte).
func _quique_fogo(x: float, forca: float, n: int) -> void:
	var o: OndaLuz = _ondas[_onda_i]
	_onda_i = (_onda_i + 1) % _ondas.size()
	o.disparar(Vector2(x, CHAO), 1 + n * 4, clamp(forca, 0.3, 1.3))
	_grade.disparar(Vector2(x, CHAO), 1 + n * 4)
	_poeira.position = Vector2(x, CHAO)
	_poeira.restart()
	_poeira.emitting = true
	_faiscas[0].position = Vector2(x, CHAO - 10)
	_faiscas[0].restart()
	_faiscas[0].emitting = true
	var lado := 180.0 + 90.0 * n
	_raio_chao.disparar(Vector2(x - lado, CHAO + _r.randf_range(-8, 8)), Vector2(x + lado, CHAO + _r.randf_range(-8, 8)), 0.26)
	if n >= 1:
		var rb: Raio = _raios_bola[n % 2]
		rb.disparar(Vector2(x, CHAO), Vector2(x + _r.randf_range(-260, 260), CHAO - 300.0 - 160.0 * n), 0.22)
	Sons.tocar("quique", linear2db(clamp(forca, 0.3, 1.0)))
	Sons.tocar("impacto", -12.0 + 5.0 * n)
	_tremor = 6.0 + 6.0 * n
	_bola.scale = Vector2(1.3, 0.7) * _bola_base
	_bola.velocidade = -_bola.velocidade


## A bola entra: o aro verga, a rede balança, faíscas, o brilho do jogador
## estoura e a bola de fogo cai pela rede.
func _impacto_enterrada() -> void:
	_jog.na_mao = false
	_bola_solta = true
	_bola_vel = Vector2(30, 950)
	_pos = ARO + Vector2(4, 12)
	_bola.visible = true
	_bola.tamanho(150.0)
	_bola_base = _bola.scale.x
	_bola_fogo.visible = true
	_chamas.emitting = true
	_bola_na_frente(false)
	_rede.balancar(1.5)
	_aro_t = 0.0
	_tremor = 26.0
	Sons.tocar("impacto")
	Sons.tocar("swish", 2.0)
	Arduino.led("HIT")
	var o: OndaLuz = _ondas[_onda_i]
	_onda_i = (_onda_i + 1) % _ondas.size()
	o.disparar(ARO, 13, 1.3)
	_grade.disparar(ARO, 13)
	for i in 2:
		_faiscas[i].position = ARO
		_faiscas[i].restart()
		_faiscas[i].emitting = true
	for i in 2:
		var rb: Raio = _raios_bola[i]
		rb.disparar(ARO + Vector2(-140 + 280 * i, -30), ARO + Vector2(-20 + 40 * i, 60), 0.3)


## O aro vergando e voltando (mola).
func _aro_offset() -> float:
	if _aro_t < 0.0:
		return 0.0
	return 16.0 * exp(-5.0 * _aro_t) * cos(_aro_t * 24.0)


func _process(delta: float) -> void:
	_t += delta
	if _fase == "jogador":
		_animar_jogador(delta)
	if _aro_t >= 0.0:
		_aro_t += delta
		var dy := _aro_offset()
		_aro_tras.position.y = dy
		_aro_frente.position.y = dy
		_rede.position.y = ARO.y + dy
		if _aro_t > 2.0:
			_aro_t = -1.0
	_bola.position = _pos
	if _fase == "jogador":
		_bola.scale = _bola.scale.linear_interpolate(Vector2.ONE * _bola_base, clamp(delta * 12.0, 0.0, 1.0))
	_bola_fogo.position = _pos
	_bola_fogo.modulate.a = 0.75 + 0.25 * sin(_t * 23.0)
	_chamas.position = _pos
	_sombra.position = Vector2(_pos.x, CHAO + 6)
	_sombra.scale = Vector2(1.6, 0.35) * clamp(1.0 - (CHAO - _pos.y) / 900.0, 0.2, 1.0) * BOLA_FOGO / 64.0
	_sombra.visible = _bola.visible and _fase == "jogador"
	# câmera (o enquadramento do pôster depois do corte) e tremor
	var tremor := Vector2.ZERO
	if _tremor > 0.1:
		tremor = Vector2(_r.randf_range(-1, 1), _r.randf_range(-1, 1)) * _tremor
		_tremor = max(0.0, _tremor - delta * 70.0)
	_mundo.scale = Vector2.ONE * _zoom
	_mundo.position = _cam + tremor
	_poster_pivo.position = Vector2(540, 960) + tremor * 0.6
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
