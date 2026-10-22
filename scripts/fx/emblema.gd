extends Node2D

## O EMBLEMA DA ABERTURA DO APP: a bola de basquete com brilho e um anel
## que enche. É a imagem de abertura do Android (imagens/splash.png é este
## emblema parado, gravado por tools/testes/gravar_splash.tscn), a capa da
## preparação (o anel enche) e o primeiro quadro da apresentação: o app
## abre sem nenhuma tela preta e sem "pulo" de uma imagem para outra.
## Redondo de propósito: fica certo com a TV Box em pé ou deitada.

const Bola = preload("res://scripts/fx/bola.gd")
const RAIO := 230.0

var progresso := 0.0 setget _set_progresso
var bola: Bola
var _brilho: Sprite
var _brilho2: Sprite


func _init() -> void:
	_brilho2 = Arte.sprite_brilho(Arte.AZUL_RAIO, 1150.0)
	_brilho2.modulate.a = 0.24
	add_child(_brilho2)
	_brilho = Arte.sprite_brilho(Arte.LARANJA, 820.0)
	_brilho.modulate.a = 0.62
	add_child(_brilho)
	bola = Bola.new()
	bola.tamanho(300)
	bola.velocidade = 0.0
	add_child(bola)


func _set_progresso(v: float) -> void:
	v = clamp(v, 0.0, 1.0)
	if abs(v - progresso) < 0.003:
		return
	progresso = v
	update()


func _draw() -> void:
	draw_arc(Vector2.ZERO, RAIO, -PI * 0.5, PI * 1.5, 96, Color(1.0, 0.72, 0.4, 0.2), 10.0, true)
	if progresso > 0.0:
		draw_arc(Vector2.ZERO, RAIO, -PI * 0.5, -PI * 0.5 + TAU * progresso, 96, Arte.LARANJA, 12.0, true)
