extends Node

## O QUE O JOGO DESENHA À MÃO: fontes, texturas de brilho/faísca/estrela/
## feixe de luz (feitas pixel a pixel por tools/gerar_texturas.py),
## materiais e estilos neon prontos. Tudo é criado UMA vez e dividido por todas as
## telas (nada é refeito no meio da partida).

const FONTE := "res://fontes/titan.ttf"
const Malhas = preload("res://scripts/fx/malhas.gd")

## Todas as letras que o jogo escreve (a preparação desenha cada uma em
## cada fonte antes da abertura: nenhuma letra nova no meio do jogo).
const LETRAS := "ABCDEFGHIJKLMNOPQRSTUVWXYZÁÀÂÃÉÊÍÓÔÕÚÇ0123456789!?.,:;-+x×%º°/•()'\"&# "
## as fontes gigantes (contagem 3-2-1, VAI!) só usam isto: cada letra
## grande ocupa muita memória de vídeo
const LETRAS_GIGANTES := "0123456789VAI!"

# paleta (a mesma da arte)
const LARANJA := Color(1.0, 0.46, 0.04)
const LARANJA_CLARO := Color(1.0, 0.72, 0.30)
const AMBAR := Color(1.0, 0.62, 0.08)
const OURO := Color(1.0, 0.80, 0.12)
const AZUL_RAIO := Color(0.25, 0.70, 1.0)
const CIANO := Color(0.35, 0.95, 1.0)
const BRANCO := Color(1, 1, 1)
const VERMELHO_ALERTA := Color(1.0, 0.22, 0.16)
const CORES_JOGADORES := [Color(1.0, 0.27, 0.27), Color(0.27, 0.6, 1.0), Color(0.3, 1.0, 0.5), Color(1.0, 0.82, 0.2)]
const NOMES_CORES := ["VERMELHO", "AZUL", "VERDE", "AMARELO"]

var dados_fonte: DynamicFontData
var _fontes := {}

var tex_brilho: Texture
var tex_faisca: Texture
var tex_estrela: Texture
var tex_feixe: Texture
var tex_anel: Texture
var tex_fumaca: Texture
var tex_confete: Texture
var tex_linha: Texture
var tex_branco: ImageTexture

var mat_aditivo: CanvasItemMaterial
var _shaders := {}
var _malhas := {}
## malhas guardadas por quem desenha (display de 7 segmentos...)
var cache_malhas := {}
var _estilos := {}


func _ready() -> void:
	dados_fonte = DynamicFontData.new()
	dados_fonte.font_path = FONTE
	dados_fonte.antialiased = true
	dados_fonte.hinting = DynamicFontData.HINTING_LIGHT
	mat_aditivo = CanvasItemMaterial.new()
	mat_aditivo.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_gerar_texturas()


# ------------------------------------------------------------------ fontes
## A mesma fonte (Titan One) em cada tamanho/contorno; a cor do contorno é
## escolhida em cada texto (font_outline_modulate), então uma fonte serve
## para todas as cores.
func fonte(tamanho: int, contorno := 0) -> DynamicFont:
	var k := "%d_%d" % [tamanho, contorno]
	if _fontes.has(k):
		return _fontes[k]
	var f := DynamicFont.new()
	f.font_data = dados_fonte
	f.size = tamanho
	f.outline_size = contorno
	f.outline_color = Color(1, 1, 1)
	f.use_filter = true
	_fontes[k] = f
	return f


func todas_as_fontes() -> Array:
	return _fontes.values()


## As letras que a preparação desenha em cada fonte.
func letras_de(f: DynamicFont) -> String:
	return LETRAS_GIGANTES if f.size >= 150 else LETRAS


## Texto pronto: Label com a fonte, a cor e o contorno (neon) escolhidos.
func texto(t: String, tamanho: int, cor := Color(1, 1, 1), contorno := 0, cor_contorno := Color(0, 0, 0), alinhar := Label.ALIGN_CENTER) -> Label:
	var l := Label.new()
	l.text = t
	l.align = alinhar
	l.valign = Label.VALIGN_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_font_override("font", fonte(tamanho, contorno))
	l.add_color_override("font_color", cor)
	l.add_color_override("font_outline_modulate", cor_contorno)
	return l


func pintar(l: Label, cor: Color, cor_contorno = null) -> void:
	l.add_color_override("font_color", cor)
	if cor_contorno != null:
		l.add_color_override("font_outline_modulate", cor_contorno)


## Texto centrado num ponto, dentro de um Node2D (para crescer, girar e
## pulsar sem o Godot 3 refazer o texto a cada quadro: a escala de um
## Control redesenha; a de um Node2D não).
func texto_solto(t: String, tamanho: int, cor := Color(1, 1, 1), contorno := 0, cor_contorno := Color(0, 0, 0), largura := 1000.0) -> Node2D:
	var n := Node2D.new()
	var l := texto(t, tamanho, cor, contorno, cor_contorno)
	l.name = "T"
	var alt := float(tamanho + contorno * 2) * 1.5
	l.rect_position = Vector2(-largura * 0.5, -alt * 0.5)
	l.rect_size = Vector2(largura, alt)
	n.add_child(l)
	return n


func rotulo_de(n: Node2D) -> Label:
	return n.get_node("T") as Label


# ----------------------------------------------------------------- estilos
## Painel neon: fundo escuro, borda da cor e brilho em volta (o brilho do
## Godot 3 é geometria com degradê: leve, sem desfoque).
## (o mesmo estilo é reaproveitado: trocar o estilo de um painel no meio
## do jogo não cria nada novo)
func estilo_neon(cor: Color, fundo_alpha := 0.82, raio := 24, borda := 3, brilho := 16, fundo_tom := 0.10) -> StyleBoxFlat:
	var chave := "%s|%.2f|%d|%d|%d|%.2f" % [cor.to_html(), fundo_alpha, raio, borda, brilho, fundo_tom]
	if _estilos.has(chave):
		return _estilos[chave]
	var sb := StyleBoxFlat.new()
	_estilos[chave] = sb
	sb.bg_color = Color(cor.r * fundo_tom, cor.g * fundo_tom, cor.b * fundo_tom + 0.015, fundo_alpha)
	sb.border_color = cor
	sb.set_border_width_all(borda)
	sb.set_corner_radius_all(raio)
	sb.corner_detail = 6
	sb.shadow_color = Color(cor.r, cor.g, cor.b, 0.45)
	sb.shadow_size = brilho
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1
	return sb


func painel(cor: Color, fundo_alpha := 0.82, raio := 24, borda := 3, brilho := 16) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_stylebox_override("panel", estilo_neon(cor, fundo_alpha, raio, borda, brilho))
	return p


func sprite_brilho(cor: Color, tamanho: float, textura: Texture = null) -> Sprite:
	var s := Sprite.new()
	s.texture = textura if textura != null else tex_brilho
	s.material = mat_aditivo
	s.modulate = cor
	var lado: float = s.texture.get_width()
	s.scale = Vector2.ONE * (tamanho / lado)
	return s


func shader(caminho: String) -> Shader:
	if not _shaders.has(caminho):
		_shaders[caminho] = load(caminho)
	return _shaders[caminho]


## Coroa desenhada à mão (pontas + base + joias).
func coroa(cor: Color, escala := 1.0) -> Node2D:
	var n := Node2D.new()
	n.scale = Vector2.ONE * escala
	var brilho := sprite_brilho(cor, 150.0)
	n.add_child(brilho)
	var c := Polygon2D.new()
	c.polygon = PoolVector2Array([Vector2(-50, 26), Vector2(-56, -26), Vector2(-28, 2), Vector2(0, -38),
		Vector2(28, 2), Vector2(56, -26), Vector2(50, 26)])
	c.color = cor
	n.add_child(c)
	var base := Polygon2D.new()
	base.polygon = PoolVector2Array([Vector2(-52, 22), Vector2(52, 22), Vector2(50, 36), Vector2(-50, 36)])
	base.color = cor.darkened(0.25)
	n.add_child(base)
	for x in [-56, 0, 56]:
		var j = Polygon2D.new()
		j.polygon = Malhas.elipse(Vector2(x, -30 if x == 0 else -24), Vector2(7, 7), 12)
		j.color = Color(1, 1, 1)
		n.add_child(j)
	return n


## Malhas que vários efeitos dividem (feitas uma vez).
func malha_onda() -> ArrayMesh:
	if not _malhas.has("onda"):
		_malhas["onda"] = Malhas.onda()
	return _malhas["onda"]


func material(caminho: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader(caminho)
	return m


# --------------------------------------------------------------- partículas
## Faíscas de cesta (explosão única, aditivas, rápidas).
func faiscas(qtd := 48, cor := Color(1.0, 0.7, 0.25)) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = qtd
	p.lifetime = 0.9
	p.explosiveness = 0.95
	p.texture = tex_faisca
	p.material = mat_aditivo
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.gravity = Vector2(0, 900)
	p.initial_velocity = 820.0
	p.initial_velocity_random = 0.65
	p.damping = 260.0
	p.flag_align_y = true
	p.scale_amount = 0.9
	p.scale_amount_random = 0.6
	p.color_ramp = _rampa([Color(1, 1, 1, 1), cor, Color(cor.r, cor.g * 0.5, cor.b * 0.3, 0.0)], [0.0, 0.25, 1.0])
	p.local_coords = false
	return p


func _rampa(cores: Array, pontos: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PoolRealArray(pontos)
	g.colors = PoolColorArray(cores)
	return g


func rampa(cores: Array, pontos: Array) -> Gradient:
	return _rampa(cores, pontos)


# -------------------------------------------------------------- texturas
## As texturas de efeito são feitas à mão por tools/gerar_texturas.py
## (brancas: cada efeito pinta da sua cor).
func _gerar_texturas() -> void:
	tex_brilho = load("res://imagens/fx_brilho.png")
	tex_faisca = load("res://imagens/fx_faisca.png")
	tex_estrela = load("res://imagens/fx_estrela.png")
	tex_feixe = load("res://imagens/fx_feixe.png")
	tex_anel = load("res://imagens/fx_anel.png")
	tex_fumaca = load("res://imagens/fx_fumaca.png")
	tex_confete = load("res://imagens/fx_confete.png")
	tex_linha = load("res://imagens/fx_linha.png")
	# branco liso 4x4 (base dos desenhos com shader: bola, feixes)
	var im := Image.new()
	im.create(4, 4, false, Image.FORMAT_RGBA8)
	im.fill(Color(1, 1, 1, 1))
	tex_branco = ImageTexture.new()
	tex_branco.create_from_image(im, Texture.FLAG_FILTER)
