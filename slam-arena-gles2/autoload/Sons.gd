extends Node

## SONS: as músicas (MP3 em fluxo, com troca suave entre uma e outra), os
## efeitos do jogo original (WAV: tocam na hora) e os efeitos FEITOS À MÃO
## (bip da contagem, tique dos últimos segundos, moeda, bola de ouro,
## trovão do SLAM MODE, quebra de combo, vento...), sintetizados por
## tools/gerar_sons.py e guardados em WAV (na TV Box a síntese em GDScript
## levaria segundos; pronto, abre na hora).
##
## Os efeitos tocam num conjunto fixo de tocadores (nenhum nó novo no meio
## da partida); o mais antigo é reaproveitado quando todos estão ocupados.

const MUSICAS := {
	"abertura": "res://musicas/abertura.mp3",
	"jogo": "res://musicas/jogo.mp3",
	"podio": "res://musicas/podio.mp3",
}
const EFEITOS := ["cesta", "selecao", "cursor", "apito", "fim_turno",
	# feitos à mão (tools/gerar_sons.py)
	"bip", "bip_vai", "tique", "batida", "moeda", "ouro", "recorde", "quebra",
	"sobe", "vento", "trovao", "impacto", "neon", "swish", "passou", "fase", "fim_jogo",
	"vaia", "vaia_curta", "aplausos"]
const TOCADORES := 10

var _efeitos := {}
var _tocadores: Array = []
var _proximo := 0
var _musica_a: AudioStreamPlayer
var _musica_b: AudioStreamPlayer
var _musica_atual := ""
var _tween: Tween


func _ready() -> void:
	pause_mode = Node.PAUSE_MODE_PROCESS
	for i in TOCADORES:
		var p = AudioStreamPlayer.new()
		add_child(p)
		_tocadores.append(p)
	_musica_a = AudioStreamPlayer.new()
	_musica_b = AudioStreamPlayer.new()
	add_child(_musica_a)
	add_child(_musica_b)
	_tween = Tween.new()
	add_child(_tween)
	for nome in EFEITOS:
		_efeitos[nome] = load("res://sons/%s.wav" % nome)
	for i in range(1, 13):
		_efeitos["combo_%d" % i] = load("res://sons/combo_%d.wav" % i)


# ----------------------------------------------------------------- efeitos
func tocar(nome: String, volume_db := 0.0, tom := 1.0) -> void:
	if not _efeitos.has(nome) or Ajustes.vol_efeitos <= 0.001:
		return
	var p: AudioStreamPlayer = _tocadores[_proximo]
	_proximo = (_proximo + 1) % TOCADORES
	p.stream = _efeitos[nome]
	p.pitch_scale = tom
	p.volume_db = volume_db + linear2db(Ajustes.vol_efeitos)
	p.play()


# ----------------------------------------------------------------- músicas
## Troca de música com as duas tocando juntas por um instante (sem corte).
func musica(nome: String, volume := 1.0, troca := 0.8) -> void:
	if nome == _musica_atual:
		return
	_musica_atual = nome
	var sai := _musica_a if _musica_a.playing else _musica_b
	var entra := _musica_b if sai == _musica_a else _musica_a
	_tween.stop_all()
	if sai.playing:
		_tween.interpolate_property(sai, "volume_db", sai.volume_db, -60.0, troca, Tween.TRANS_SINE, Tween.EASE_IN)
		_tween.interpolate_callback(sai, troca, "stop")
	if nome == "" or not MUSICAS.has(nome) or Ajustes.vol_musica <= 0.001:
		_tween.start()
		return
	var s = load(MUSICAS[nome])
	if s is AudioStreamMP3 or s is AudioStreamOGGVorbis:
		s.loop = true
	entra.stream = s
	var alvo := linear2db(Ajustes.vol_musica * volume)
	entra.volume_db = -50.0
	entra.play()
	_tween.interpolate_property(entra, "volume_db", -50.0, alvo, troca, Tween.TRANS_SINE, Tween.EASE_OUT)
	_tween.start()


func abaixar_musica(fator := 0.35, tempo := 0.4) -> void:
	var p := _musica_a if _musica_a.playing else _musica_b
	if not p.playing:
		return
	_tween.interpolate_property(p, "volume_db", p.volume_db, linear2db(max(0.001, Ajustes.vol_musica * fator)), tempo)
	_tween.start()


func parar_musica(tempo := 0.6) -> void:
	musica("", 1.0, tempo)


func reaplicar_volume() -> void:
	for p in [_musica_a, _musica_b]:
		if p.playing:
			p.volume_db = linear2db(max(0.001, Ajustes.vol_musica))
	if Ajustes.vol_musica <= 0.001:
		parar_musica(0.2)
