"""O JOGADOR DA CAPA EM PECAS (a materia-prima dos quadros da apresentacao):

    python3 -I tools/rig_jogador.py            # as pecas e os remendos
    python3 -I tools/rig_jogador.py previa DIR # + quadros de previa das poses

O jogador inteiro, da propria arte do poster (tools/arte/poster_original.png
e o recorte tools/arte/jogador_mascara.png), em PECAS INTEIRAS E RIGIDAS,
como um boneco de animacao 2D: pernas (com o calcao), tronco, cabeca, o
braco da bola em duas partes (braco e antebraco com a mao) e a bola, o
outro braco em duas partes. As pecas se encontram nas juntas com sobra
(ombro, cotovelo, pescoco, cintura): a peca de cima acaba macia por cima
da de baixo, entao a junta nao abre nem aparece quando gira.

As juntas do braco da bola (o ombro, que SOBE com o braco por cima, e o
cotovelo) ficam certas pixel a pixel: para cada angulo sai um REMENDO feito
da arte que refaz a juncao (veja "as juntas" abaixo).

O jogo NAO monta este boneco: o tools/quadros_jogador.py faz dele cada
QUADRO da animacao inteiro (o jogador todo numa imagem so, pose a pose) e o
jogo so passa os quadros. Grava tudo em tools/arte/pecas/ (fora do jogo):
<peca>.png, pecas.txt (onde cada peca fica no poster e as juntas), o atlas
dos remendos juntas.png e juntas.txt. Precisa de numpy e Pillow (~2 min).
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import recortar_jogador as rj  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARTE = os.path.join(RAIZ, "tools", "arte")
PECAS = os.path.join(ARTE, "pecas")

# as juntas no poster original (941 x 1672)
J = {
    "cintura": (455.0, 545.0),
    "pescoco": (440.0, 305.0),
    "quadril": (400.0, 560.0),
    "ombro_e": (362.0, 298.0),      # o braco da bola (o de la)
    "cotovelo_e": (218.0, 266.0),
    "pulso_e": (148.0, 182.0),
    "ombro_d": (540.0, 398.0),      # o braco da mao aberta (o de ca)
    "cotovelo_d": (603.0, 530.0),
    "pulso_d": (670.0, 626.0),
    "bola": (190.0, 112.0),
    # as pernas (desenhadas: tools/pernas_jogador.py), em pe
    "pelve": (427.0, 590.0),
    "quadril_c": (478.0, 592.0), "joelho_c": (478.0, 777.0), "tornozelo_c": (478.0, 972.0),
    "quadril_l": (376.0, 588.0), "joelho_l": (376.0, 773.0), "tornozelo_l": (376.0, 968.0),
    # o centro da bola embaixo da mao aberta (quicando)
    "bola_mao_d": (708.0, 748.0),
}
# a cabeca: o cabelo e a nuca acima do vao azul que separa o cabelo do
# ombro, e acima da linha laranja da alca da camisa (a alca fica no tronco:
# nao gira com a cabeca)
CABECA = [(372, 150), (560, 150), (560, 318), (476, 326), (470, 324), (464, 320), (458, 315),
          (452, 310), (446, 305), (440, 302), (434, 298), (428, 294), (422, 289), (416, 285),
          (410, 280), (404, 276), (394, 268), (386, 259), (380, 250), (372, 240)]
# o ombro da bola (o de la): o deltoide vai com o braco ate a CAVA da camisa
# (a faixa laranja da cava, a alca e o cabelo ficam no tronco e na cabeca);
# embaixo, ate a linha da axila (o lado do corpo fica no tronco)
ZONA_BRACO = [(250, 150), (372, 150), (378, 240), (383, 258), (388, 266), (394, 272), (400, 280),
              (399, 288), (399, 294), (401, 300), (402, 304), (402, 340), (250, 340)]
AXILA = [(240, 360), (324, 343), (404, 307), (404, 420), (240, 420)]
# o braco de ca (do ombro aos dedos), passando no vao entre o joelho e o
# antebraco (a luz do joelho fica nas pernas)
BRACO_D = [(540, 336), (655, 380), (820, 600), (820, 790), (606, 790), (582, 600), (526, 488), (524, 405)]
# a barra da camisa (o tronco acaba nela; o short fica por baixo)
BARRA = [(200, 0), (941, 0), (941, 556), (560, 553), (512, 547), (497, 544), (447, 537), (380, 531),
         (340, 523), (313, 515), (290, 511), (200, 511)]
TAM = (941, 1672)


def poligono_liso(pts, tam=TAM, ss=4):
    """O poligono com a borda lisa (desenhado em ss vezes e reduzido)."""
    im = Image.new("L", (tam[0] * ss, tam[1] * ss), 0)
    ImageDraw.Draw(im).polygon([(x * ss, y * ss) for x, y in pts], fill=255)
    im = im.resize(tam, Image.BOX)
    return np.asarray(im).astype(np.float64) / 255


def plano(p, n, f, tam=TAM):
    """0 de um lado da linha (por p, normal n) e 1 do outro, com a borda
    macia de f pixels."""
    y, x = np.mgrid[0:tam[1], 0:tam[0]].astype(np.float64)
    n = np.array(n, float) / np.linalg.norm(n)
    d = (x - p[0]) * n[0] + (y - p[1]) * n[1]
    if f <= 0:
        return (d > 0).astype(np.float64)
    t = np.clip((d + f) / (2 * f), 0, 1)
    return t * t * (3 - 2 * t)


def unit(a, b):
    v = np.array(b, float) - np.array(a, float)
    return v / np.linalg.norm(v)


def pecas():
    c = rj.calcular()
    rgb, m, mao = c["rgb"], c["mascara"], c["mao"]
    tam = TAM
    bola_d = rj.disco(tam, rj.BOLA, rj.RAIO_BOLA + 4, 3.0)
    # ---- o ombro da bola: o deltoide (ate a cava e a axila) vai com o braco;
    # o braco tem a junta inteira por baixo do corte macio do tronco
    axila = poligono_liso(AXILA)
    zona = poligono_liso(ZONA_BRACO) * rj.disco(tam, J["ombro_e"], 46, 2.0) * (1 - axila)
    zona_dura = (rj.borrar(zona, 1.0) > 0.01).astype(np.float64)
    braco_e_pol = rj.poligono(tam, rj.BRACO_E) * (1 - (axila > 0.5))
    # ---- o braco da bola: braco (do ombro ao cotovelo) e antebraco com a mao
    braco = m * np.maximum(braco_e_pol, zona_dura) * (1 - bola_d * (1 - mao))
    # (cortados na bissetriz do cotovelo: o antebraco, na frente, com o
    # corte macio; o braco vai 1 px por baixo dele - o remendo do cotovelo
    # faz a ponta e a dobra quando gira)
    bis = unit(J["ombro_e"], J["cotovelo_e"]) + unit(J["cotovelo_e"], J["pulso_e"])
    lado = plano(J["cotovelo_e"], bis, 0.75)
    braco_e = braco * (1 - plano(np.array(J["cotovelo_e"]) + 1.0 * bis / np.linalg.norm(bis), bis, 0))
    antebraco_e = braco * lado
    # ---- o outro braco
    braco = m * rj.poligono(tam, BRACO_D)
    bis = unit(J["ombro_d"], J["cotovelo_d"]) + unit(J["cotovelo_d"], J["pulso_d"])
    lado = plano(J["cotovelo_d"], bis, 3)
    cot = rj.disco(tam, J["cotovelo_d"], 30, 10.0)
    braco_d = braco * np.maximum(1 - lado, rj.disco(tam, J["cotovelo_d"], 34, 2.0))
    # a raiz some macia sobre o ombro do tronco (que tem o ombro inteiro)
    braco_d *= plano(J["ombro_d"], unit(J["ombro_d"], J["cotovelo_d"]), 16)
    antebraco_d = braco * np.maximum(lado, cot)
    # ---- o corpo (sem os bracos e a bola), com o ombro de ca inteiro e o
    # lado do corpo debaixo da axila; o deltoide de la fica com o braco
    corpo = m * (1 - braco_e_pol) * (1 - rj.poligono(tam, BRACO_D))
    corpo = np.maximum(corpo, m * rj.disco(tam, J["ombro_d"], 44, 8.0))
    corpo *= 1 - c["bola"]
    corpo *= 1 - zona
    # o tronco acaba na barra da camisa (o short e as pernas sao as pecas
    # desenhadas do tools/pernas_jogador.py, por baixo dela)
    tronco = corpo * poligono_liso(BARRA)
    # cabeca por cima do pescoco (o tronco fica com o pescoco inteiro)
    n_pesc = (0.12, -1.0)
    cabeca_pol = poligono_liso(CABECA)
    cabeca = corpo * cabeca_pol * plano((J["pescoco"][0], J["pescoco"][1] + 6), n_pesc, 9)
    tronco_todo = tronco.copy()
    # (o tronco vai 8 px por baixo da cabeca em toda a nuca: girando, a junta
    # nao abre)
    acima = poligono_liso([(x, y - 8 if x >= 422 else y) for x, y in CABECA])
    tronco *= 1 - acima * plano((J["pescoco"][0], J["pescoco"][1] - 16), n_pesc, 2)
    # (para o remendo do ombro: o tronco mais alto na nuca, onde a cabeca
    # cobre o corte - o remendo nao ve borda ali; o cabelo nao entra)
    nuca = rj.poligono(tam, [(418, 150), (941, 150), (941, 400), (418, 400)])
    tronco_pescoco = np.maximum(tronco, tronco_todo * nuca * (1 - plano((J["pescoco"][0], J["pescoco"][1] - 30), n_pesc, 2)))
    import pernas_jogador
    lista = [
        # nome, cor, alfa (a ordem do desenho: o braco de la atras de tudo, as
        # pernas e o short, o tronco, a cabeca, o braco de ca na frente)
        ("braco_e", rgb, braco_e),
        ("bola", c["bola_rgb"], c["bola"]),
        ("antebraco_e", rgb, antebraco_e),
    ] + pernas_jogador.pecas_pernas() + [
        ("tronco", rgb, tronco),
        ("cabeca", rgb, cabeca),
        ("braco_d", rgb, braco_d),
        ("antebraco_d", rgb, antebraco_d),
    ]
    extra = {"rgb": rgb, "mascara": m, "tronco_pescoco": tronco_pescoco, "braco_e": braco_e,
             "antebraco_e": antebraco_e, "zona": zona, "cabeca": cabeca}
    # o contorno convexo da raiz do braco (ate 40 px do ombro), no braco
    yy, xx = np.where((braco_e >= 0.5) & (rj.disco(tam, J["ombro_e"], 40, 0.5) >= 0.5))
    # (so a metade de baixo: a que vira o lado da axila com o braco em cima;
    # o alto do ombro tem curvas que o casco taparia)
    extra["raiz_braco"] = [np.array(p) for p in _casco(zip(xx + 0.5, yy + 0.5)) if p[1] >= J["ombro_e"][1] - 6]
    return lista, extra


def caixa(alfa, margem):
    ys, xs = np.where(alfa > 0.004)
    x0, y0 = max(xs.min() - margem, 0), max(ys.min() - margem, 0)
    x1, y1 = min(xs.max() + margem + 1, TAM[0]), min(ys.max() + margem + 1, TAM[1])
    return x0, y0, x1, y1


def gravar(nome, cor, alfa):
    """A peca, recortada no tamanho dela."""
    x0, y0, x1, y1 = caixa(alfa, 3)
    rgba = np.zeros((y1 - y0, x1 - x0, 4))
    rgba[..., :3] = cor[y0:y1, x0:x1]
    rgba[..., 3] = alfa[y0:y1, x0:x1]
    Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(
        os.path.join(PECAS, "%s.png" % nome), optimize=True)
    return (x0, y0, x1 - x0, y1 - y0)


# ------------------------------------------------------------ as juntas
# AS JUNTAS DO BRACO DA BOLA, pixel a pixel (o ombro e o cotovelo: as que
# giram muito). O ombro SOBE quando o braco vai por cima (a escapula sobe:
# o braco passa por cima da cabeca, sem cruzar ela) e desce um pouco quando
# o braco baixa. Para cada angulo da junta (de 2,5 em 2,5 graus) sai um
# REMENDO, desenhado por cima das duas pecas: a silhueta da juncao refeita
# - a peca parada, a que gira e, entre elas, a carne de cada junta (no
# ombro: o deltoide subindo, a axila ate o lado do corpo, o trapezio ate a
# base do pescoco, o fundo da cava; no cotovelo: a ponta redonda quando
# dobra e o fundo da dobra quando estica). Dentro, o preto da arte; na
# borda nova, a LUZ DE CONTORNO da propria arte (o perfil medido no poster:
# nucleo branco, laranja e o vermelho apagando - grossa nas bordas de cima,
# fina nas de baixo, como la). O remendo so pinta onde a arte das pecas
# ficaria errada: a luz velha que foi para dentro, os cortes que ficaram
# para fora, o vao entre as pecas. Na pose da capa ele e vazio (a arte fica
# igualzinha). Tudo vai num atlas so (tools/arte/pecas/juntas.png) e os
# numeros no juntas.txt.
PASSO = 2.5
OMBRO_DE, OMBRO_ATE = -140.0, 130.0
COTOVELO_DE, COTOVELO_ATE = -40.0, 25.0
OMBRO_ERGUIDO = (-8.0, -42.0)       # o ombro com o braco la em cima
OMBRO_BAIXADO = (3.0, 8.0)          # o ombro com o braco la embaixo
ERGUE_ATE, BAIXA_ATE = 100.0, 35.0  # graus do braco ate o ombro todo erguido / baixado
OMBRO_RAIO = 24.0                   # o deltoide (cabe na silhueta da capa: 25 px)
AXILA_BRACO = (324.0, 342.0)        # o fim de baixo do braco (no braco)
AXILA_CORPO = [(328.0, 346.0), (334.0, 360.0)]   # o lado do corpo (no tronco)
TRAPEZIO = [(420.0, 302.0)]         # a base do pescoco (no tronco): o trapezio sobe ate o ombro
COTOVELO_MIOLO = 16.0               # o miolo do cotovelo (cabe na dobra da capa: 18 px)
COTOVELO_DOBRA = 17.5               # o fundo da dobra (a borda a 19 px)
COTOVELO_PONTA = 34.0               # a ponta do cotovelo (a borda a 35,5 px)
COTOVELO_REDONDO = 30.0             # a ponta redonda (o lado de fora)
G = 2                               # o remendo e feito em dobro e reduzido

# a luz de contorno da arte (medida no poster): (distancia para dentro da
# borda em px, cor) - grossa nas bordas de cima (o ombro), fina nas de baixo
LUZ_GROSSA = [(-2.0, (249, 150, 16)), (-1.0, (250, 195, 26)), (0.0, (252, 226, 155)),
              (1.0, (254, 249, 244)), (2.0, (254, 255, 255)), (3.0, (253, 213, 118)),
              (4.0, (252, 135, 12)), (5.0, (247, 111, 10)), (6.0, (240, 110, 8)), (7.0, (183, 80, 7)),
              (8.0, (81, 21, 2)), (9.0, (60, 18, 1)), (10.0, (35, 10, 1)), (11.0, (14, 3, 1)),
              (12.0, (5, 2, 2))]
# (a do cotovelo, medida no braco: o nucleo branco e o laranja mais estreitos)
LUZ_MEDIA = [(-1.6, (225, 58, 12)), (-0.6, (250, 184, 162)), (0.4, (248, 251, 248)), (1.4, (245, 255, 255)),
             (2.4, (245, 185, 113)), (3.4, (243, 109, 9)), (4.4, (250, 105, 2)), (5.4, (166, 54, 1)),
             (6.4, (63, 12, 0)), (7.4, (33, 10, 0)), (8.4, (12, 3, 0)), (9.4, (5, 2, 2))]
LUZ_FINA = [(-1.0, (249, 185, 122)), (-0.4, (250, 250, 250)), (0.6, (250, 210, 135)), (1.6, (240, 85, 8)),
            (2.6, (205, 37, 8)), (3.6, (110, 20, 10)), (4.6, (35, 10, 12)), (5.6, (5, 2, 2))]


def _suave(a, b, x):
    t = np.clip((np.asarray(x, dtype=np.float64) - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def deslocamento_ombro(ome):
    """Quanto o ombro da bola anda (px) com o braco em ome graus."""
    return (np.array(OMBRO_ERGUIDO) * float(_suave(0.0, ERGUE_ATE, ome))
            + np.array(OMBRO_BAIXADO) * float(_suave(0.0, BAIXA_ATE, -ome)))


def _distancia(alvo, pad=0):
    """Distancia exata (pixels da grade) de cada ponto ao ponto de alvo mais
    perto (0 no alvo): coluna e depois linha. pad: a borda continua igual
    (o que passa da janela nao vira borda)."""
    if pad:
        alvo = np.pad(alvo, pad, mode="edge")
    H, W = alvo.shape
    g = np.where(alvo, 0.0, 1e4)
    for y in range(1, H):
        np.minimum(g[y], g[y - 1] + 1, out=g[y])
    for y in range(H - 2, -1, -1):
        np.minimum(g[y], g[y + 1] + 1, out=g[y])
    g2 = g * g
    xs = np.arange(W, dtype=np.float64)
    dx2 = (xs[:, None] - xs[None, :]) ** 2
    d2 = np.empty((H, W))
    for y0 in range(0, H, 8):
        d2[y0:y0 + 8] = (g2[y0:y0 + 8, :, None] + dx2[None]).min(axis=1)
    d = np.sqrt(d2)
    return d[pad:-pad, pad:-pad] if pad else d


def _sinal(mask):
    """Distancia com sinal (px do poster) ate a borda: + dentro, - fora."""
    p = 16 * G
    return np.where(mask, _distancia(~mask, p) - 0.5, 0.5 - _distancia(mask, p)) / G


def _amostra(arr, px, py):
    """arr no ponto (px, py) do poster (continuo: o pixel i vai de i a i+1),
    bilinear; fora da imagem = 0."""
    H, W = arr.shape[:2]
    x = px - 0.5
    y = py - 0.5
    x0 = np.floor(x).astype(np.int64)
    y0 = np.floor(y).astype(np.int64)
    fx = x - x0
    fy = y - y0
    if arr.ndim == 3:
        fx, fy = fx[..., None], fy[..., None]
    r = 0.0
    for dy, wy in ((0, 1 - fy), (1, fy)):
        for dx, wx in ((0, 1 - fx), (1, fx)):
            xx, yy = x0 + dx, y0 + dy
            ok = (xx >= 0) & (xx < W) & (yy >= 0) & (yy < H)
            v = arr[np.clip(yy, 0, H - 1), np.clip(xx, 0, W - 1)]
            if arr.ndim == 3:
                ok = ok[..., None]
            r = r + np.where(ok, v, 0.0) * wx * wy
    return r


def _casco(pts):
    """O casco convexo dos pontos (cadeia monotona)."""
    p = sorted(set((round(float(x), 4), round(float(y), 4)) for x, y in pts))

    def giro(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    baixo, cima = [], []
    for q in p:
        while len(baixo) >= 2 and giro(baixo[-2], baixo[-1], q) <= 0:
            baixo.pop()
        baixo.append(q)
    for q in reversed(p):
        while len(cima) >= 2 and giro(cima[-2], cima[-1], q) <= 0:
            cima.pop()
        cima.append(q)
    return baixo[:-1] + cima[:-1]


def _dentro_casco(casco, px, py):
    r = np.ones(px.shape, bool)
    for i in range(len(casco)):
        a, b = casco[i], casco[(i + 1) % len(casco)]
        r &= (b[0] - a[0]) * (py - a[1]) - (b[1] - a[1]) * (px - a[0]) >= 0
    return r


def _maximo(a, raio):
    im = Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), "L")
    return np.asarray(im.filter(ImageFilter.MaxFilter(2 * raio + 1))).astype(np.float64) / 255


def _alisar(a, vezes=2):
    for _ in range(vezes):
        a = np.pad(a, 1, mode="edge")
        a = (a[:-2] + 2 * a[1:-1] + a[2:]) / 4
        a = (a[:, :-2] + 2 * a[:, 1:-1] + a[:, 2:]) / 4
    return a


def _perfil(tab, d):
    xs = [t for t, _ in tab]
    return np.stack([np.interp(d, xs, [c[i] / 255.0 for _, c in tab]) for i in range(3)], axis=-1)


def _grossura(nx, ny):
    """A luz da borda: 0 fina (borda virada para baixo) a 1 grossa (para
    cima e para a esquerda, de onde vem a luz da arte)."""
    return np.clip(0.55 - 0.5 * ny - 0.25 * nx, 0.0, 1.0)


def _remendo(extra, cfg, ang, dbg=None):
    """O remendo de uma junta com a peca que gira em ang graus: (imagem
    RGBA, canto no poster) - ou (None, None) se nao precisa de nada."""
    P = np.array(cfg["pivo"], dtype=np.float64)
    P2 = P + cfg["desloc"](ang)
    rgb, m = extra["rgb"], extra["mascara"]
    fixa, gira = cfg["fixa"], cfg["gira"]
    lo = np.floor(np.minimum(P, P2) - cfg["janela"]).astype(int)
    hi = np.ceil(np.maximum(P, P2) + cfg["janela"]).astype(int)
    xs = lo[0] + (np.arange((hi[0] - lo[0]) * G) + 0.5) / G
    ys = lo[1] + (np.arange((hi[1] - lo[1]) * G) + 0.5) / G
    PX, PY = np.meshgrid(xs, ys)
    # a peca que gira (no pivo andado): o ponto da tela -> o ponto da peca
    a = math.radians(ang)
    c, s = math.cos(a), math.sin(a)
    GX = P[0] + c * (PX - P2[0]) + s * (PY - P2[1])
    GY = P[1] - s * (PX - P2[0]) + c * (PY - P2[1])

    def girar(p):
        v = np.array(p, dtype=np.float64) - P
        return P2 + np.array([c * v[0] - s * v[1], s * v[0] + c * v[1]])
    Fa = _amostra(fixa, PX, PY)
    Ga = _amostra(gira, GX, GY)
    Fpm = _amostra(rgb * fixa[..., None], PX, PY)
    Gpm = _amostra(rgb * gira[..., None], GX, GY)
    # a borda da arte de cada peca (no lugar dela)
    dF = np.clip(_sinal(_amostra(m, PX, PY) >= 0.5), 0, 12.0)
    dG = np.clip(_sinal(_amostra(m, GX, GY) >= 0.5), 0, 12.0)
    if cfg["frente"] == "fixa":
        Na, Npm, dN, Ba, Bpm, dB = Fa, Fpm, dF, Ga, Gpm, dG
    else:
        Na, Npm, dN, Ba, Bpm, dB = Ga, Gpm, dG, Fa, Fpm, dF
    # (a cobertura das duas juntas: na emenda macia cada uma tem metade)
    cob = Na + Ba * (1 - Na)
    cobreN = (cob >= 0.5) & (Na >= 0.5 * cob)
    cobreB = (cob >= 0.5) & ~cobreN
    ctx = {"PX": PX, "PY": PY, "P": P, "P2": P2, "ang": ang, "girar": girar}
    U = (cob >= 0.5) | cfg["enchimento"](ctx)
    # a borda nova e a borda da arte
    sdU = _sinal(U)
    dU = np.clip(sdU, 0, 12.0)
    dentro = sdU > 0
    # onde pintar: a peca da frente so se um corte dela ficou para fora (a
    # luz dela fica, como na arte); a de tras se a borda dela mudou (para
    # fora ou para dentro); o enchimento todo
    wN = _suave(0.6, 1.6, dN - dU)
    if "relaxar" in cfg:
        wN = np.maximum(wN, cfg["relaxar"](ctx) * _suave(0.6, 1.6, np.abs(dU - dN)))
    w = np.where(cobreN, wN, np.where(cobreB, _suave(0.6, 1.6, np.abs(dU - dB)), np.where(dentro, 1.0, 0.0)))
    w = np.where(dentro, w, _maximo(np.where(dentro, w, 0.0), 3 * G))
    # (um pixel a mais para dentro no preto: a peca de verdade gira lisa)
    al = np.maximum(cob, 1e-6)
    lum = ((Npm + Bpm * (1 - Na)[..., None]) / al[..., None]).max(axis=2)
    w = np.maximum(w, _maximo(w, G) * ((lum < 0.1) & (sdU > 3)))
    w *= cfg["envelope"](ctx)
    if "sem_pintar" in cfg:
        w *= 1 - _amostra(cfg["sem_pintar"], PX, PY)
    if dbg is not None:
        dbg.update(U=U, sdU=sdU, dN=dN, dB=dB, w=w, cobreN=cobreN, cobreB=cobreB, PX=PX, PY=PY)
    # a luz da borda: a grossura pela direcao da borda (perto da peca parada
    # a luz e a da arte; perto da que gira, a dela girada)
    gy, gx = np.gradient(_alisar(sdU))
    nn = np.hypot(gx, gy) + 1e-9
    nx, ny = -gx / nn, -gy / nn
    dFp = _distancia(Fa >= 0.5, 16 * G)
    dGp = _distancia(Ga >= 0.5, 16 * G)
    wg = dFp / (dFp + dGp + 1e-6)
    f = (1 - wg) * _grossura(nx, ny) + wg * _grossura(c * nx + s * ny, -s * nx + c * ny)
    # (a distancia lisa: a borda da grade em dobro nao vira serrilhado na luz)
    sl = _alisar(sdU, 3)
    grossa, borda = cfg.get("luz", (LUZ_GROSSA, 2.6))
    cor = _perfil(LUZ_FINA, sl) * (1 - f[..., None]) + _perfil(grossa, sl) * f[..., None]
    alfa = (_suave(-1.6, 1.6, sl) * (1 - f) + _suave(-borda, borda, sl) * f) * w
    # reduz (media pre-multiplicada) e recorta no que tem
    h, wd = alfa.shape[0] // G, alfa.shape[1] // G
    a1 = alfa.reshape(h, G, wd, G).mean(axis=(1, 3))
    pm = (cor * alfa[..., None]).reshape(h, G, wd, G, 3).mean(axis=(1, 3))
    c1 = pm / np.maximum(a1, 1e-6)[..., None]
    yy, xx = np.where(a1 > 0.6 / 255)
    if len(xx) == 0:
        return None, None
    x0, y0 = max(xx.min() - 1, 0), max(yy.min() - 1, 0)
    x1, y1 = min(xx.max() + 2, wd), min(yy.max() + 2, h)
    rgba = np.concatenate([c1, a1[..., None]], axis=2)[y0:y1, x0:x1]
    img = (np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8)
    return img, (lo[0] + x0, lo[1] + y0)


def _circulo(c, r, n=48):
    return [np.array(c, dtype=np.float64) + r * np.array([math.cos(2 * math.pi * k / n), math.sin(2 * math.pi * k / n)])
            for k in range(n)]


def junta_ombro(extra):
    """O ombro da bola: o tronco parado na frente, o braco girando atras."""
    S = np.array(J["ombro_e"])

    def enchimento(ctx):
        PX, PY, P2, girar = ctx["PX"], ctx["PY"], ctx["P2"], ctx["girar"]
        # o deltoide: do ombro de antes ao erguido (com o braco baixando o
        # ombro desce inteiro: so o de agora)
        Sb = S if ctx["ang"] >= 0 else P2
        ab = P2 - Sb
        t = np.clip(((PX - Sb[0]) * ab[0] + (PY - Sb[1]) * ab[1]) / max(float(ab @ ab), 1e-9), 0, 1)
        ctx["dseg"] = dseg = np.hypot(PX - (Sb[0] + t * ab[0]), PY - (Sb[1] + t * ab[1]))
        pts = _circulo(Sb, OMBRO_RAIO) + _circulo(P2, OMBRO_RAIO)
        # a axila e a raiz do braco inteira, girada (1 px para fora: a linha
        # nova sai tangente ao braco, cobrindo o corte serrilhado da raiz)
        for p in [np.array(AXILA_BRACO)] + extra["raiz_braco"]:
            v = p - S
            pts.append(girar(S + v * (1 + 1.0 / max(np.hypot(*v), 1.0))))
        # o lado do corpo e o trapezio ate a base do pescoco
        pts += [np.array(p) for p in AXILA_CORPO + TRAPEZIO]
        U = (dseg <= OMBRO_RAIO) | _dentro_casco(_casco(pts), PX, PY)
        # o fundo da cava (o corpo atras da faixa da cava)
        U |= (_amostra(extra["zona"], PX, PY) >= 0.5) & (PY > S[1]) & (PX > S[0])
        return U

    def envelope(ctx):
        return 1 - _suave(OMBRO_RAIO + 32, OMBRO_RAIO + 38, ctx["dseg"])

    def relaxar(ctx):
        # na ponta da axila a luz do canto do tronco (que virava para o
        # braco) tambem sai quando fica para dentro
        return 1 - _suave(8.0, 14.0, np.hypot(ctx["PX"] - AXILA_CORPO[0][0], ctx["PY"] - AXILA_CORPO[0][1]))
    return {"nome": "ombro", "pivo": S, "desloc": deslocamento_ombro, "janela": 64,
            "fixa": extra["tronco_pescoco"], "gira": extra["braco_e"], "frente": "fixa",
            "enchimento": enchimento, "envelope": envelope, "relaxar": relaxar,
            "sem_pintar": extra["cabeca"], "de": OMBRO_DE, "ate": OMBRO_ATE}


def junta_cotovelo(extra):
    """O cotovelo da bola: o braco parado atras, o antebraco girando na frente."""
    E = np.array(J["cotovelo_e"])
    bis = unit(J["ombro_e"], J["cotovelo_e"]) + unit(J["cotovelo_e"], J["pulso_e"])
    bis /= np.linalg.norm(bis)
    dobra = np.array([-bis[1], bis[0]])          # do cotovelo para a dobra (o lado de dentro)
    C = E + COTOVELO_DOBRA * dobra               # o fundo da dobra
    O = E - COTOVELO_PONTA * dobra               # a ponta do cotovelo

    def enchimento(ctx):
        PX, PY, girar = ctx["PX"], ctx["PY"], ctx["girar"]
        ctx["dE"] = np.hypot(PX - E[0], PY - E[1])
        miolo = _circulo(E, COTOVELO_MIOLO, 24)
        # o fundo da dobra e a ponta: do lugar no braco ao lugar no antebraco
        U = _dentro_casco(_casco(miolo + [C, girar(C)]), PX, PY)
        U |= _dentro_casco(_casco(miolo + [O, girar(O)]), PX, PY)
        # a ponta redonda (o lado de fora da dobra)
        U |= (ctx["dE"] <= COTOVELO_REDONDO) & ((PX - E[0]) * dobra[0] + (PY - E[1]) * dobra[1] < -4)
        return U

    def envelope(ctx):
        return 1 - _suave(40.0, 46.0, ctx["dE"])
    return {"nome": "cotovelo", "pivo": E, "desloc": lambda ang: np.zeros(2), "janela": 48,
            "fixa": extra["braco_e"], "gira": extra["antebraco_e"], "frente": "gira",
            "enchimento": enchimento, "envelope": envelope, "luz": (LUZ_MEDIA, 2.0),
            "de": COTOVELO_DE, "ate": COTOVELO_ATE}


def remendos(extra):
    """Os remendos das juntas, num atlas so (prateleiras), e o script com
    os numeros. Devolve {junta: [(graus, imagem, canto, pivo andado)]}."""
    juntas = [junta_ombro(extra), junta_cotovelo(extra)]
    todos = {}
    for cfg in juntas:
        n = int(round((cfg["ate"] - cfg["de"]) / PASSO)) + 1
        lista = []
        for i in range(n):
            ang = cfg["de"] + i * PASSO
            img, canto = _remendo(extra, cfg, ang)
            lista.append((ang, img, canto, np.array(cfg["pivo"], dtype=np.float64) + cfg["desloc"](ang)))
        todos[cfg["nome"]] = lista
        print("  %s: %d remendos (%d vazios)" % (cfg["nome"], n, sum(1 for x in lista if x[1] is None)))
    LARG, F = 1024, 2
    x = y = alt = 0
    lugares = {}
    for nome, lista in todos.items():
        for i, (ang, img, canto, P2) in enumerate(lista):
            if img is None:
                continue
            h, w = img.shape[:2]
            if x + w + F > LARG:
                x, y, alt = 0, y + alt + F, 0
            lugares[(nome, i)] = (x + F, y + F)
            x += w + F
            alt = max(alt, h + F)
    atlas = np.zeros((y + alt + F, LARG, 4), np.uint8)
    for (nome, i), lug in lugares.items():
        img = todos[nome][i][1]
        h, w = img.shape[:2]
        atlas[lug[1]:lug[1] + h, lug[0]:lug[0] + w] = img
    Image.fromarray(atlas, "RGBA").save(os.path.join(PECAS, "juntas.png"), optimize=True)
    with open(os.path.join(PECAS, "juntas.txt"), "w") as f:
        f.write("# os remendos das juntas do braco da bola, um por angulo, no atlas juntas.png\n")
        f.write("# (coordenadas do poster original): junta, graus, pivo andado x, y, canto do\n")
        f.write("# remendo x, y, no atlas x, y, largura, altura (largura 0: nada a remendar)\n")
        for cfg in juntas:
            nome = cfg["nome"]
            for i, (ang, img, canto, P2) in enumerate(todos[nome]):
                if img is None:
                    f.write("%s %.1f %.3f %.3f 0 0 0 0 0 0\n" % (nome, ang, P2[0], P2[1]))
                else:
                    h, w = img.shape[:2]
                    lug = lugares[(nome, i)]
                    f.write("%s %.1f %.3f %.3f %d %d %d %d %d %d\n" % (nome, ang, P2[0], P2[1], canto[0], canto[1], lug[0], lug[1], w, h))
    print("  atlas das juntas: %d x %d" % (atlas.shape[1], atlas.shape[0]))
    return todos


# ------------------------------------------------------------ previa
OSSOS = ["tronco", "pelve", "coxa_l", "joelho_l", "pe_l", "coxa_c", "joelho_c", "pe_c", "cabeca",
         "ombro_e", "cotovelo_e", "ombro_d", "cotovelo_d"]
OSSOS_PAI = {"pelve": "tronco", "coxa_l": "pelve", "joelho_l": "coxa_l", "pe_l": "joelho_l",
             "coxa_c": "pelve", "joelho_c": "coxa_c", "pe_c": "joelho_c",
             "tronco": None, "cabeca": "tronco", "ombro_e": "tronco",
             "cotovelo_e": "ombro_e", "ombro_d": "tronco", "cotovelo_d": "ombro_d"}
PIVOS = {"pelve": "pelve", "coxa_l": "quadril_l", "joelho_l": "joelho_l", "pe_l": "tornozelo_l",
         "coxa_c": "quadril_c", "joelho_c": "joelho_c", "pe_c": "tornozelo_c",
         "tronco": "cintura", "cabeca": "pescoco", "ombro_e": "ombro_e",
         "cotovelo_e": "cotovelo_e", "ombro_d": "ombro_d", "cotovelo_d": "cotovelo_d"}
PECA_OSSO = {"canela_l": "joelho_l", "pe_l": "pe_l", "coxa_l": "coxa_l",
             "canela_c": "joelho_c", "pe_c": "pe_c", "coxa_c": "coxa_c", "pelve": "pelve",
             "braco_e": "ombro_e", "bola": "cotovelo_e", "antebraco_e": "cotovelo_e",
             "tronco": "tronco", "cabeca": "cabeca", "braco_d": "ombro_d", "antebraco_d": "cotovelo_d"}


def rot(graus, centro):
    a = math.radians(graus)
    c, s = math.cos(a), math.sin(a)
    cx, cy = centro
    return np.array([[c, -s, cx - c * cx + s * cy], [s, c, cy - s * cx - c * cy], [0, 0, 1.0]])


def mover(v):
    return np.array([[1, 0, v[0]], [0, 1, v[1]], [0, 0, 1.0]])


def ossos(pose):
    """As transformacoes dos ossos (como o jogo: o ombro anda com o braco)."""
    o = {}
    for nome in OSSOS:
        pai = OSSOS_PAI[nome]
        base = o[pai] if pai else np.eye(3)
        if nome == "ombro_e":
            base = base @ mover(deslocamento_ombro(pose.get("ombro_e", 0.0)))
        o[nome] = base @ rot(pose.get(nome, 0.0), J[PIVOS[nome]])
    return o


def remendo_da_pose(ang, lista, de):
    """(imagem, transformacao no osso da peca parada) do remendo, como o
    jogo: o mais perto, levado ao pivo de agora e girado metade do que falta."""
    i = int(round((min(max(ang, de), de + PASSO * (len(lista) - 1)) - de) / PASSO))
    ang_i, img, canto, P2_i = lista[i]
    if img is None:
        return None, None
    return Image.fromarray(img, "RGBA"), (ang_i, canto, P2_i)


def _transf_remendo(ang, dados, pivo_agora):
    ang_i, canto, P2_i = dados
    return mover(pivo_agora) @ rot(0.5 * (ang - ang_i), (0, 0)) @ mover(np.array(canto) - P2_i)


def previa(pasta, pecas_img, caixas, poses, todos, zoom=True):
    os.makedirs(pasta, exist_ok=True)
    for i, (nome_pose, pose) in enumerate(poses):
        o = ossos(pose)
        tela = Image.new("RGBA", (1100, 1400), (26, 22, 42, 255))
        desl = mover((80, 250))

        def por(img, t):
            inv = np.linalg.inv(desl @ t)
            tela.alpha_composite(img.transform(tela.size, Image.AFFINE, tuple(inv[:2].ravel()), Image.BICUBIC))
        for nome, img in pecas_img:
            x0, y0 = caixas[nome][:2]
            por(img, o[PECA_OSSO[nome]] @ mover((x0, y0)))
            if todos is None:
                continue
            if nome == "antebraco_e":
                # o cotovelo (no braco, por cima do antebraco)
                ang = pose.get("cotovelo_e", 0.0)
                rimg, dados = remendo_da_pose(ang, todos["cotovelo"], COTOVELO_DE)
                if rimg is not None:
                    por(rimg, o["ombro_e"] @ _transf_remendo(ang, dados, np.array(J["cotovelo_e"])))
            if nome == "tronco":
                # o ombro (no tronco, por cima dele)
                ang = pose.get("ombro_e", 0.0)
                rimg, dados = remendo_da_pose(ang, todos["ombro"], OMBRO_DE)
                if rimg is not None:
                    S2 = np.array(J["ombro_e"]) + deslocamento_ombro(ang)
                    por(rimg, o["tronco"] @ _transf_remendo(ang, dados, S2))
        tela = tela.convert("RGB")
        tela.save(os.path.join(pasta, "%02d_%s.png" % (i, nome_pose)))
        if zoom:
            S2 = np.array(J["ombro_e"]) + deslocamento_ombro(pose.get("ombro_e", 0.0))
            c = desl @ o["tronco"] @ np.array([S2[0], S2[1], 1.0])
            x, y = int(c[0]), int(c[1])
            z = tela.crop((x - 100, y - 100, x + 100, y + 100)).resize((600, 600), Image.NEAREST)
            z.save(os.path.join(pasta, "%02d_%s_ombro.png" % (i, nome_pose)))


# as pernas da capa (no ar: o joelho de ca para cima, a perna de la embaixo)
PERNAS_CAPA = {"coxa_c": -58, "joelho_c": 125, "pe_c": 40, "coxa_l": 15, "joelho_l": 35, "pe_l": 30}


def _com(pose, extra):
    r = dict(PERNAS_CAPA)
    r.update(pose)
    r.update(extra)
    return r


POSES_PREVIA = [
    ("empe", {}),
    # correndo (a perna de ca na frente / atras) com a bola quicando na mao
    # de ca e o braco de la balancando atras
    ("corre_a", {"coxa_c": -32, "joelho_c": 15, "pe_c": -8, "coxa_l": 25, "joelho_l": 45, "pe_l": 30,
                 "ombro_e": -100, "cotovelo_e": -20, "ombro_d": 6, "cotovelo_d": 8}),
    ("corre_b", {"coxa_c": 15, "joelho_c": 100, "pe_c": 25, "coxa_l": -30, "joelho_l": 95, "pe_l": 10,
                 "ombro_e": -80, "cotovelo_e": -30, "ombro_d": 0, "cotovelo_d": -4}),
    ("capa", _com({}, {})),
    ("e1", _com({}, {"tronco": 3, "cabeca": 3, "ombro_e": 32.5, "cotovelo_e": -24.5, "ombro_d": -8, "cotovelo_d": -4})),
    ("e3", _com({}, {"tronco": 10, "cabeca": 7, "ombro_e": 92.5, "cotovelo_e": -24.5, "ombro_d": -22, "cotovelo_d": -9})),
    ("e5", _com({}, {"tronco": 16, "cabeca": 8, "ombro_e": 122.5, "cotovelo_e": 10.5, "ombro_d": -32, "cotovelo_d": -13})),
    ("pendurado", {"coxa_c": -20, "joelho_c": 40, "pe_c": 25, "coxa_l": 5, "joelho_l": 25, "pe_l": 20,
                   "tronco": 4, "cabeca": 5, "ombro_e": 105.5, "cotovelo_e": -32.5, "ombro_d": -10, "cotovelo_d": -4}),
    ("braco_baixo", {"ombro_e": -130, "cotovelo_e": -30}),
]


def main():
    os.makedirs(PECAS, exist_ok=True)
    lista, extra = pecas()
    caixas = {}
    imgs = []
    for nome, cor, alfa in lista:
        caixas[nome] = gravar(nome, cor, alfa)
        imgs.append((nome, Image.open(os.path.join(PECAS, "%s.png" % nome)).convert("RGBA")))
        print("  %s: x %d y %d  %d x %d" % ((nome,) + caixas[nome]))
    with open(os.path.join(PECAS, "pecas.txt"), "w") as f:
        f.write("# a ordem do desenho: peca x y largura altura (no poster original)\n")
        for nome, _, _ in lista:
            f.write("peca %s %d %d %d %d\n" % ((nome,) + caixas[nome]))
        f.write("# as juntas: nome x y\n")
        for k, v in J.items():
            f.write("junta %s %.1f %.1f\n" % (k, v[0], v[1]))
    # ("rapida": so as pecas e a previa, sem refazer os remendos)
    todos = remendos(extra) if not (len(sys.argv) > 1 and sys.argv[1] == "rapida") else None
    if len(sys.argv) > 2 and sys.argv[1] in ("previa", "rapida"):
        previa(sys.argv[2], imgs, caixas, POSES_PREVIA, todos)


if __name__ == "__main__":
    main()
