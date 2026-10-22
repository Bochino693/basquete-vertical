extends Control

## BASE DE CADA TELA (abertura, apresentação, jogo, configuração,
## botões). As telas são montadas UMA vez, por trás da capa de preparação,
## e depois só aparecem/somem: trocar de tela não carrega nada do disco.

signal trocar(nome, dados)

const LARGURA := 1080.0
const ALTURA := 1920.0

var ativo := false
## muda a cada entrada: um "yield" antigo que acorda depois de a tela sair
## confere isto e não faz nada (corrotinas do Godot 3)
var sessao := 0


func _init() -> void:
	rect_position = Vector2.ZERO
	rect_size = Vector2(LARGURA, ALTURA)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## (Godot 3 chama o _ready da base e o da tela: a tela só trabalha a
## cada quadro quando está na frente)
func _ready() -> void:
	set_process(false)


func entrar(_dados := {}) -> void:
	sessao += 1
	ativo = true
	visible = true
	set_process(true)


func sair() -> void:
	sessao += 1
	ativo = false
	visible = false
	set_process(false)


## Mostra tudo o que a tela tem pelo menos uma vez (a capa cobre): os
## desenhos (shaders) são preparados na placa e as letras de cada fonte
## entram no cache antes da abertura.
func aquecer() -> void:
	pass


func ir(nome: String, dados := {}) -> void:
	emit_signal("trocar", nome, dados)


func espera(segundos: float) -> SceneTreeTimer:
	return get_tree().create_timer(segundos)


## O "yield" ainda vale? (a tela não saiu nem entrou de novo)
func vale(s: int) -> bool:
	return s == sessao and ativo


## Lâmpada de neon ligando: pisca (acende/apaga), falha e firma. Só
## ACESO ou APAGADO, nunca meio transparente: um texto com contorno meio
## transparente mostra o contorno por dentro das letras (fica "sujo").
func neon_liga(no: CanvasItem, atraso := 0.0, alvo := 1.0) -> SceneTreeTween:
	no.modulate.a = 0.0
	var tw := create_tween()
	if atraso > 0.0:
		tw.tween_interval(atraso)
	var passos := [[1.0, 0.04], [0.0, 0.05], [1.0, 0.03], [0.0, 0.07], [1.0, 0.04], [0.0, 0.04], [1.0, 0.0]]
	for p in passos:
		tw.tween_callback(self, "_neon_alfa", [no, float(p[0]) * alvo])
		if float(p[1]) > 0.0:
			tw.tween_interval(float(p[1]))
	return tw


func _neon_alfa(no: CanvasItem, a: float) -> void:
	if is_instance_valid(no):
		no.modulate.a = a


## Escurece (ou clareia) um nó SEM transparência: multiplica as cores
## (texto com contorno continua inteiro, só mais apagado).
static func tom(no: CanvasItem, v: float) -> void:
	no.modulate = Color(v, v, v, 1.0)


## Pulo de escala (Node2D ou Control) - "pop".
func pop(no: CanvasItem, pico := 1.25, tempo := 0.24) -> void:
	var tw := create_tween()
	if no is Control:
		(no as Control).rect_pivot_offset = (no as Control).rect_size * 0.5
		tw.tween_property(no, "rect_scale", Vector2.ONE * pico, tempo * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(no, "rect_scale", Vector2.ONE, tempo * 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(no, "scale", Vector2.ONE * pico, tempo * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(no, "scale", Vector2.ONE, tempo * 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Retângulo de Control em coordenadas absolutas da tela.
static func pos(c: Control, x: float, y: float, w: float, h: float) -> Control:
	c.rect_position = Vector2(x, y)
	c.rect_size = Vector2(w, h)
	return c
