extends SceneTree

## Confere se TODOS os scripts compilam e os shaders carregam:
##   godot --no-window --path . -s tools/testes/conferir_scripts.gd
## (com o Godot de tela, os shaders também são compilados na placa)

var _erros := 0


func _init() -> void:
	var lista := []
	_listar("res://", lista)
	for c in lista:
		if c.ends_with(".gd"):
			var s = load(c)
			if s == null or not (s is GDScript) or not s.can_instance():
				print("ERRO script: ", c)
				_erros += 1
		elif c.ends_with(".shader"):
			var sh = load(c)
			if sh == null:
				print("ERRO shader: ", c)
				_erros += 1
	print("conferidos %d arquivos, %d erros" % [lista.size(), _erros])
	quit(1 if _erros > 0 else 0)


func _listar(pasta: String, lista: Array) -> void:
	var d := Directory.new()
	if d.open(pasta) != OK:
		return
	d.list_dir_begin(true, true)
	var f := d.get_next()
	while f != "":
		var c := pasta.plus_file(f)
		if d.current_is_dir():
			if f != "tools" and f != "android" and f != "build":
				_listar(c, lista)
		elif f.ends_with(".gd") or f.ends_with(".shader"):
			lista.append(c)
		f = d.get_next()
	d.list_dir_end()
