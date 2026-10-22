extends Node2D

## Anel que enche (segurar um botão para abrir a configuração).

var progresso := 0.0 setget _set_progresso
var raio := 46.0
var cor := Color(1.0, 0.6, 0.15)


func _set_progresso(v: float) -> void:
	v = clamp(v, 0.0, 1.0)
	if abs(v - progresso) < 0.004:
		return
	progresso = v
	update()


func _draw() -> void:
	draw_arc(Vector2.ZERO, raio, 0.0, TAU, 48, Color(1, 1, 1, 0.18), 8.0, true)
	if progresso > 0.0:
		draw_arc(Vector2.ZERO, raio, -PI * 0.5, -PI * 0.5 + TAU * progresso, 48, cor, 9.0, true)
