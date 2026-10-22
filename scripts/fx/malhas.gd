extends Reference

## Malhas 2D montadas UMA vez (Godot 3: ArrayMesh com pontos Vector2). Os
## efeitos mudam só parâmetros do shader por quadro; a placa de vídeo
## guarda a malha (nada é reenviado).

const TAU_ := 6.2831853


static func _malha(pontos: PoolVector2Array, uvs: PoolVector2Array, indices: PoolIntArray, cores = null) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pontos
	arr[Mesh.ARRAY_TEX_UV] = uvs
	if cores != null:
		arr[Mesh.ARRAY_COLOR] = cores
	arr[Mesh.ARRAY_INDEX] = indices
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Retângulo dividido em colunas x linhas (fundo vivo, poster).
static func tela(ret: Rect2, colunas: int, linhas: int) -> ArrayMesh:
	var p := PoolVector2Array()
	var uv := PoolVector2Array()
	var idx := PoolIntArray()
	for j in linhas + 1:
		for i in colunas + 1:
			var u = float(i) / colunas
			var v = float(j) / linhas
			p.append(ret.position + ret.size * Vector2(u, v))
			uv.append(Vector2(u, v))
	var w := colunas + 1
	for j in linhas:
		for i in colunas:
			var a = j * w + i
			idx.append_array(PoolIntArray([a, a + 1, a + w + 1, a, a + w + 1, a + w]))
	return _malha(p, uv, idx)


## O PISO DE LED da quadra (piso.shader): ladrilhos em perspectiva, nas
## linhas da quadra do fundo (as colunas fogem para o ponto de fuga, como
## as laterais pintadas; cada fileira é um pouco mais alta que a de trás).
## Cada ponto: VERTEX = centro do ladrilho na tela, UV = o canto (em px, a
## partir do centro), COLOR = (u, v da textura, sorteio, profundidade: 0 no
## fundo da quadra .. 1 na frente). Só entram os ladrilhos que aparecem.
static func piso(fuga: Vector2, topo: float, fundo: float, passo0: float, achatar: float, largura: float, folga := 0.12) -> ArrayMesh:
	var p := PoolVector2Array()
	var uv := PoolVector2Array()
	var cor := PoolColorArray()
	var idx := PoolIntArray()
	var r := RandomNumberGenerator.new()
	r.seed = 2024
	var d0 := topo - fuga.y
	var linhas := [topo]
	var y := topo
	while y < fundo:
		y += passo0 * (y - fuga.y) / d0 * achatar
		linhas.append(y)
	var tcs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for j in linhas.size() - 1:
		var ya: float = linhas[j]
		var yb: float = linhas[j + 1]
		var sa := (ya - fuga.y) / d0
		var sb := (yb - fuga.y) / d0
		var prof: float = clamp((ya + yb) * 0.5 - topo, 0.0, fundo - topo) / (fundo - topo)
		var n := int(ceil(largura * 0.5 / (passo0 * sa))) + 1
		for c in range(-n, n + 1):
			var cantos := [Vector2(fuga.x + (c - 0.5) * passo0 * sa, ya), Vector2(fuga.x + (c + 0.5) * passo0 * sa, ya),
				Vector2(fuga.x + (c + 0.5) * passo0 * sb, yb), Vector2(fuga.x + (c - 0.5) * passo0 * sb, yb)]
			if cantos[1].x < -10.0 or cantos[0].x > largura + 10.0:
				continue
			var centro: Vector2 = (cantos[0] + cantos[1] + cantos[2] + cantos[3]) * 0.25
			var sorteio := r.randf()
			var base := p.size()
			for k in 4:
				p.append(centro)
				uv.append((cantos[k] - centro) * (1.0 - folga))
				var tc: Vector2 = tcs[k]
				cor.append(Color(tc.x, tc.y, sorteio, prof))
			idx.append_array(PoolIntArray([base, base + 1, base + 2, base, base + 2, base + 3]))
	return _malha(p, uv, idx, cor)


## A PAREDE DE LED (piso.shader, com a mesma arrumação do piso): ladrilhos
## retos de lado "passo", da borda de cima de "ret" para baixo.
static func parede(ret: Rect2, passo: float, folga := 0.16) -> ArrayMesh:
	var p := PoolVector2Array()
	var uv := PoolVector2Array()
	var cor := PoolColorArray()
	var idx := PoolIntArray()
	var r := RandomNumberGenerator.new()
	r.seed = 2024
	var colunas := int(ceil(ret.size.x / passo))
	var linhas := int(ceil(ret.size.y / passo))
	var sobra := (colunas * passo - ret.size.x) * 0.5
	var tcs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	var meia := passo * 0.5 * (1.0 - folga)
	var cantos := [Vector2(-meia, -meia), Vector2(meia, -meia), Vector2(meia, meia), Vector2(-meia, meia)]
	for gy in linhas:
		for gx in colunas:
			var centro := ret.position + Vector2(-sobra + (gx + 0.5) * passo, (gy + 0.5) * passo)
			var sorteio := r.randf()
			var prof := float(gy) / max(1, linhas - 1)
			var base := p.size()
			for k in 4:
				p.append(centro)
				uv.append(cantos[k])
				var tc: Vector2 = tcs[k]
				cor.append(Color(tc.x, tc.y, sorteio, prof))
			idx.append_array(PoolIntArray([base, base + 1, base + 2, base, base + 2, base + 3]))
	return _malha(p, uv, idx, cor)


## A onda de luz (onda.shader): 9 anéis x 48 gomos x 4 linhas + 18 raios.
static func onda() -> ArrayMesh:
	var p := PoolVector2Array()
	var uv := PoolVector2Array()
	var idx := PoolIntArray()
	var gomos := 48
	for i in 9:
		var base = p.size()
		for s in gomos + 1:
			var ang = TAU_ * float(s) / gomos
			var d = Vector2(cos(ang), sin(ang))
			for linha in 4:
				p.append(d)
				uv.append(Vector2(linha, i))
		for s in gomos:
			for linha in 3:
				var a = base + s * 4 + linha
				var b = base + (s + 1) * 4 + linha
				idx.append_array(PoolIntArray([a, b, b + 1, a, b + 1, a + 1]))
	for j in 18:
		var base = p.size()
		for ao_longo in 2:
			for lado in [-1, 0, 1]:
				p.append(Vector2(lado, 0))
				uv.append(Vector2(ao_longo, 100 + j))
		for k in 2:
			var a = base + k
			var b = base + 3 + k
			idx.append_array(PoolIntArray([a, b, b + 1, a, b + 1, a + 1]))
	return _malha(p, uv, idx)


## Anel do cronômetro (anel.shader): 60 tracinhos com brilho + arco fino.
static func anel(r_dentro: float, r_fora: float, r_arco: float, n := 60) -> ArrayMesh:
	var p := PoolVector2Array()
	var uv := PoolVector2Array()
	var idx := PoolIntArray()
	var meia_ang := TAU_ / n * 0.30
	var brilho := 7.0
	for k in n:
		var frac = (float(k) + 0.5) / n
		var ang = -PI * 0.5 + TAU_ * float(k) / n + TAU_ / n * 0.5
		var d = Vector2(cos(ang), sin(ang))
		var t = Vector2(-d.y, d.x)
		var largura = (r_dentro + r_fora) * 0.5 * sin(meia_ang)
		var c0 = d * r_dentro - t * largura
		var c1 = d * r_dentro + t * largura
		var c2 = d * r_fora + t * largura
		var c3 = d * r_fora - t * largura
		var base = p.size()
		for c in [c0, c1, c2, c3]:
			p.append(c)
			uv.append(Vector2(frac, 0))
		var meio = d * (r_dentro + r_fora) * 0.5
		# (o brilho começa 1,3 px para fora: a beirada do tracinho fica lisa)
		for c in [c0, c1, c2, c3]:
			p.append(c + (c - meio).normalized() * 1.3)
			uv.append(Vector2(frac, 1))
		for c in [c0, c1, c2, c3]:
			p.append(c + (c - meio).normalized() * brilho)
			uv.append(Vector2(frac, 2))
		idx.append_array(PoolIntArray([base, base + 1, base + 2, base, base + 2, base + 3]))
		for q in 4:
			var a = base + 4 + q
			var b = base + 4 + (q + 1) % 4
			idx.append_array(PoolIntArray([a, b, b + 4, a, b + 4, a + 4]))
	# arco fino por dentro (180 gomos), com borda suave dos dois lados
	var gomos := 180
	var base_arco := p.size()
	for s in gomos + 1:
		var frac = float(s) / gomos
		var ang = -PI * 0.5 + TAU_ * frac
		var d = Vector2(cos(ang), sin(ang))
		p.append(d * (r_arco - 4.0))
		uv.append(Vector2(frac, 11))
		p.append(d * (r_arco - 1.2))
		uv.append(Vector2(frac, 10))
		p.append(d * (r_arco + 1.2))
		uv.append(Vector2(frac, 10))
		p.append(d * (r_arco + 4.0))
		uv.append(Vector2(frac, 11))
	for s in gomos:
		for linha in 3:
			var a = base_arco + s * 4 + linha
			var b = base_arco + (s + 1) * 4 + linha
			idx.append_array(PoolIntArray([a, b, b + 1, a, b + 1, a + 1]))
	return _malha(p, uv, idx)


## Arco com rastro (sem shader: a cor de cada ponto já faz o degradê).
static func arco_rastro(raio: float, largura: float, graus: float, cor: Color) -> ArrayMesh:
	var p := PoolVector2Array()
	var uv := PoolVector2Array()
	var cores := PoolColorArray()
	var idx := PoolIntArray()
	var gomos := 40
	for s in gomos + 1:
		var t = float(s) / gomos
		var ang = -deg2rad(graus) * (1.0 - t)
		var d = Vector2(cos(ang), sin(ang))
		var a = pow(t, 2.2)
		for linha in 3:
			var off = [-largura, 0.0, largura][linha]
			p.append(d * (raio + off))
			uv.append(Vector2(t, linha))
			cores.append(Color(cor.r, cor.g, cor.b, a * (1.0 if linha == 1 else 0.0)))
	for s in gomos:
		for linha in 2:
			var a = s * 3 + linha
			var b = (s + 1) * 3 + linha
			idx.append_array(PoolIntArray([a, b, b + 1, a, b + 1, a + 1]))
	return _malha(p, uv, idx, cores)


## Linha de neon (traco.shader) por uma sequência de pontos: miolo de
## "largura" e brilho de "brilho" px de cada lado. UV.x = distância
## percorrida (0..1).
static func traco(pontos: PoolVector2Array, largura: float, brilho: float, fechado := false) -> ArrayMesh:
	var bruto := PoolVector2Array(pontos)
	if fechado and bruto.size() > 1:
		bruto.append(bruto[0])
	# pontos a cada 10 px no máximo: a linha aparece lisa enquanto se desenha
	var pts := PoolVector2Array()
	for i in bruto.size():
		if i > 0:
			var a: Vector2 = bruto[i - 1]
			var b: Vector2 = bruto[i]
			var partes = int(ceil(a.distance_to(b) / 10.0))
			for k in range(1, partes):
				pts.append(a.linear_interpolate(b, float(k) / partes))
		pts.append(bruto[i])
	var n := pts.size()
	var p := PoolVector2Array()
	var uv := PoolVector2Array()
	var idx := PoolIntArray()
	var total := 0.0
	var dist := [0.0]
	for i in range(1, n):
		total += pts[i].distance_to(pts[i - 1])
		dist.append(total)
	total = max(total, 0.001)
	for i in n:
		var antes: Vector2 = pts[i] - pts[max(0, i - 1)]
		var depois: Vector2 = pts[min(n - 1, i + 1)] - pts[i]
		if fechado and (i == 0 or i == n - 1):
			antes = pts[0] - pts[n - 2]
			depois = pts[1] - pts[0]
		var tang = (antes.normalized() + depois.normalized())
		if tang.length() < 0.001:
			tang = depois if depois.length() > 0.001 else antes
		tang = tang.normalized()
		var normal = Vector2(-tang.y, tang.x)
		# junta sem afinar nas curvas (limitado para não estourar em ponta)
		var escala = 1.0
		if antes.length() > 0.001 and depois.length() > 0.001:
			var cosmeio: float = abs(normal.dot(Vector2(-antes.normalized().y, antes.normalized().x)))
			escala = clamp(1.0 / max(cosmeio, 0.35), 1.0, 2.5)
		var u: float = dist[i] / total
		var offs = [-(largura * 0.5 + brilho), -largura * 0.5, largura * 0.5, largura * 0.5 + brilho]
		for linha in 4:
			p.append(pts[i] + normal * offs[linha] * escala)
			uv.append(Vector2(u, linha))
	for i in n - 1:
		for linha in 3:
			var a = i * 4 + linha
			var b = (i + 1) * 4 + linha
			idx.append_array(PoolIntArray([a, b, b + 1, a, b + 1, a + 1]))
	return _malha(p, uv, idx)


## Barras do equalizador (barras.shader): retângulos lado a lado a partir
## de "base" (o topo sobe a partir dela, para cima).
static func barras(base: Vector2, n: int, largura: float, vao: float, sorteio_semente := 1) -> ArrayMesh:
	var p := PoolVector2Array()
	var uv := PoolVector2Array()
	var cores := PoolColorArray()
	var idx := PoolIntArray()
	var r := RandomNumberGenerator.new()
	r.seed = sorteio_semente
	for i in n:
		var x = base.x + i * (largura + vao)
		var fase = r.randf()
		var b = p.size()
		for c in [Vector2(x, base.y), Vector2(x + largura, base.y), Vector2(x + largura, base.y), Vector2(x, base.y)]:
			p.append(c)
		uv.append_array(PoolVector2Array([Vector2(i, 0), Vector2(i, 0), Vector2(i, 1), Vector2(i, 1)]))
		for k in 4:
			cores.append(Color(fase, 0, 0, 1))
		idx.append_array(PoolIntArray([b, b + 1, b + 2, b, b + 2, b + 3]))
	return _malha(p, uv, idx, cores)


## Pontos de um círculo/elipse (para traços).
static func elipse(centro: Vector2, raios: Vector2, n := 64, ang0 := -PI * 0.5, graus := 360.0) -> PoolVector2Array:
	var out := PoolVector2Array()
	for i in n + 1:
		var a = ang0 + deg2rad(graus) * float(i) / n
		out.append(centro + Vector2(cos(a) * raios.x, sin(a) * raios.y))
	return out
