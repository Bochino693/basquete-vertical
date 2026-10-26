"""AS PERNAS DO JOGADOR DA CAPA, PARA CORRER (usado pelo tools/rig_jogador.py).

Na capa o jogador esta no ar: uma perna dobrada vindo para a camera (o tenis
em perspectiva) e a outra escondida atras do logo - nao da para correr com
aquilo. Entao o short e as pernas sao DESENHADOS no estilo da propria arte
(medido no poster): a silhueta preta, a luz de contorno (nucleo branco e
laranja do lado de tras, branco e azul do lado da frente), os raios laranja
do short, a meia laranja, o tenis com a sola de luz azul; a perna de la com
a luz azul (como na capa). Pecas articuladas: o short de cima (a pelve), e
em cada perna o short com a coxa (gira no quadril), a canela (no joelho,
por baixo da barra do short) e o tenis (no tornozelo, por cima da canela).
As juntas sao redondas no pivo e ficam por baixo da peca de cima: girando,
nada abre.

Coordenadas do poster original (941 x 1672), o jogador EM PE (a pose da capa
gira as pernas para a posicao do salto).
"""
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

TAM = (941, 1672)
G = 2

# os pivos (em pe)
QUADRIL_C = (478.0, 592.0)      # a perna de ca (na frente)
QUADRIL_L = (376.0, 588.0)      # a perna de la (atras, luz azul)
COXA = 185.0                    # do quadril ao joelho
CANELA = 195.0                  # do joelho ao tornozelo
SOLA = 44.0                     # do tornozelo ao chao (o tenis)


def joelho(q):
    return (q[0], q[1] + COXA)


def tornozelo(q):
    return (q[0], q[1] + COXA + CANELA)


# o short de cima (no poster; o alto fica por baixo da barra da camisa)
PELVE = [(298, 492), (360, 486), (430, 488), (500, 494), (552, 504), (564, 540), (566, 590), (556, 632),
         (532, 660), (490, 672), (440, 666), (400, 672), (350, 668), (318, 655), (298, 628), (288, 585),
         (290, 535)]
PELVE_RAIOS = [[(312, 560), (346, 600), (331, 606), (372, 652), (356, 656), (380, 672)],
               [(402, 546), (432, 578), (419, 583), (452, 620)],
               [(502, 542), (527, 582), (513, 586), (540, 626)]]
PELVE_AZUL = [[(470, 600), (520, 652)], [(540, 560), (556, 610)]]

# o short com a coxa (em volta do quadril; a barra a 215, o joelho a 185)
COXA_FORMA = [(-60, -55), (0, -68), (58, -55), (64, 0), (62, 60), (63, 120), (67, 180), (70, 212),
              (52, 222), (20, 226), (-15, 228), (-50, 227), (-72, 222), (-70, 190), (-66, 130),
              (-64, 70), (-67, 0)]
COXA_RAIOS = [[(-50, 12), (-20, 60), (-38, 68), (-6, 120), (-26, 128), (8, 184)],
              [(28, 4), (50, 44), (36, 52), (54, 96)]]
COXA_BARRA = [(-60, 200), (-30, 206), (0, 208), (30, 206), (60, 201)]
COXA_AZUL = [[(22, 118), (46, 170)], [(-34, 150), (-12, 192)]]

# a canela (em volta do joelho; o tornozelo a 195)
CANELA_FORMA = [(-28, -22), (0, -34), (28, -22), (32, 0), (30, 30), (26, 70), (22, 120), (19, 160),
                (17, 190), (10, 206), (0, 212), (-10, 206), (-18, 190), (-21, 165), (-29, 125), (-40, 80),
                (-43, 50), (-38, 15)]
CANELA_MEIA = [148.0, 162.0]
CANELA_AZUL = [[(22, 30), (17, 110)]]

# o tenis (em volta do tornozelo, a ponta para a frente)
TENIS_ESC = 0.95
TENIS_FORMA = [(-30, -22), (20, -24), (40, -14), (70, 0), (100, 12), (122, 26), (126, 38), (118, 48),
               (60, 52), (0, 52), (-45, 50), (-52, 38), (-50, 10), (-42, -12)]
TENIS_SOLA = [(-50, 38), (0, 40), (60, 40), (120, 37)]
TENIS_RISCO = [(-40, 25), (-5, 31), (30, 28), (62, 14)]
TENIS_CADARCO = [((28, -12), (36, -2)), ((44, -6), (51, 4)), ((60, 1), (66, 11)), ((76, 8), (81, 18))]
TENIS_GOLA = [(-30, -22), (-5, -25), (20, -24)]

# a luz azul da borda (medida no poster: o joelho e a sola do tenis)
LUZ_AZUL = [(-1.0, (133, 209, 253)), (-0.3, (248, 253, 253)), (0.5, (220, 248, 254)), (1.4, (37, 125, 232)),
            (2.4, (0, 63, 212)), (3.4, (4, 56, 193)), (4.4, (2, 50, 172)), (5.4, (2, 35, 136)),
            (6.4, (3, 22, 85)), (7.4, (2, 18, 55)), (9.0, (2, 14, 38)), (12.0, (3, 6, 16))]
# (a da frente da perna de ca: um fio branco-azulado, fino)
LUZ_FRENTE = [(-1.0, (150, 200, 255)), (-0.3, (240, 250, 255)), (0.5, (205, 232, 255)), (1.4, (70, 130, 225)),
              (2.4, (18, 45, 115)), (3.4, (6, 14, 38)), (5.0, (5, 3, 4))]
LARANJA = (255, 118, 12)
LARANJA_CLARO = (255, 214, 120)
AZUL = (60, 150, 255)


def spline(pts, n=10):
    """Catmull-Rom fechada pelos pontos (o contorno liso)."""
    p = [np.array(q, dtype=np.float64) for q in pts]
    r = []
    for i in range(len(p)):
        p0, p1, p2, p3 = p[i - 1], p[i], p[(i + 1) % len(p)], p[(i + 2) % len(p)]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            r.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                            + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    return [tuple(q) for q in r]


def _mover(pts, centro, esc=1.0):
    return [(centro[0] + x * esc, centro[1] + y * esc) for x, y in pts]


def desenhar(forma, raios=(), azul=(), linhas=(), sem_luz=None, de_la=False, cor_dentro=None,
             textura=None):
    """Uma peca no estilo da arte (cor e alfa no tamanho do poster).

    forma: o contorno (pontos do poster, ja liso). raios: polilinhas laranja
    (os raios do short). azul: riscos azuis. linhas: (pontos, largura, cor)
    a mais. sem_luz(px, py) -> 0..1: onde a peca fica por baixo de outra (sem
    luz de contorno). de_la: a perna de la (luz e miolo azuis)."""
    import rig_jogador as rg
    xs = [p[0] for p in forma]
    ys = [p[1] for p in forma]
    x0, y0 = int(math.floor(min(xs))) - 12, int(math.floor(min(ys))) - 12
    x1, y1 = int(math.ceil(max(xs))) + 12, int(math.ceil(max(ys))) + 12
    W, H = (x1 - x0) * G, (y1 - y0) * G
    # a mascara (em 8x, reduzida para a grade de 2x)
    S = 4
    im = Image.new("L", (W * S, H * S), 0)
    ImageDraw.Draw(im).polygon([((x - x0) * G * S, (y - y0) * G * S) for x, y in forma], fill=255)
    msk = np.asarray(im.resize((W, H), Image.BOX)).astype(np.float64) / 255
    sd = rg._alisar(rg._sinal(msk >= 0.5), 3)
    px = x0 + (np.arange(W) + 0.5) / G
    py = y0 + (np.arange(H) + 0.5) / G
    PX, PY = np.meshgrid(px, py)
    # a luz da borda pela direcao: o lado de tras laranja, o da frente azul
    gy, gx = np.gradient(sd)
    nn = np.hypot(gx, gy) + 1e-9
    nx, ny = -gx / nn, -gy / nn
    sd_luz = sd
    if sem_luz is not None:
        sd_luz = sd + 20.0 * sem_luz(PX, PY)
    if de_la:
        cor = rg._perfil(LUZ_AZUL, sd_luz)
        dentro = np.array(cor_dentro or (3, 12, 34)) / 255.0
    else:
        # atras laranja, na frente o fio branco-azulado, embaixo o azul
        fr = rg._suave(-0.25, 0.35, nx)[..., None]
        bx = rg._suave(0.55, 0.9, ny)[..., None]
        cor = rg._perfil(rg.LUZ_MEDIA, sd_luz) * (1 - fr) + rg._perfil(LUZ_FRENTE, sd_luz) * fr
        cor = cor * (1 - bx) + rg._perfil(LUZ_AZUL, sd_luz) * bx
        dentro = np.array(cor_dentro or (5, 2, 2)) / 255.0
    # o miolo (a cor do fundo da peca bem para dentro): a textura da arte
    # (mapeada de um pedaco do poster) ou a cor lisa
    fundo = rg._suave(4.0, 8.0, sd_luz)[..., None]
    if textura is not None:
        dentro = textura(PX, PY)
    cor = cor * (1 - fundo) + dentro * fundo
    # os desenhos de dentro (raios laranja, riscos azuis, barras)
    camada = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(camada)

    def linha(pts, largura, c):
        q = [((x - x0) * G, (y - y0) * G) for x, y in pts]
        d.line(q, fill=c + (255,), width=max(1, int(round(largura * G))), joint="curve")
        for x, y in (q[0], q[-1]):
            r = largura * G * 0.5
            d.ellipse((x - r, y - r, x + r, y + r), fill=c + (255,))
    fator = 0.55 if de_la else 1.0
    lar = tuple(int(v * fator) for v in LARANJA)
    lar_c = tuple(int(v * fator) for v in LARANJA_CLARO)
    for pts in raios:
        linha(pts, 7.0, lar)
    brilho = camada.filter(ImageFilter.GaussianBlur(3 * G))
    for pts in raios:
        linha(pts, 2.4, lar_c)
    for pts in azul:
        linha(pts, 2.2, AZUL)
    for pts, largura, c in linhas:
        linha(pts, largura, c)
    dec = np.asarray(camada).astype(np.float64) / 255
    gl = np.asarray(brilho).astype(np.float64) / 255
    longe = rg._suave(1.5, 3.5, sd_luz)
    a_gl = gl[..., 3] * 0.55 * longe
    cor = cor * (1 - a_gl[..., None]) + gl[..., :3] * a_gl[..., None]
    a_dec = dec[..., 3] * longe
    cor = cor * (1 - a_dec[..., None]) + dec[..., :3] * a_dec[..., None]
    alfa = rg._suave(-2.0, 2.0, sd)
    # reduz (pre-multiplicada) para o tamanho do poster
    h, w = H // G, W // G
    a1 = alfa.reshape(h, G, w, G).mean(axis=(1, 3))
    pm = (cor * alfa[..., None]).reshape(h, G, w, G, 3).mean(axis=(1, 3))
    c1 = pm / np.maximum(a1, 1e-6)[..., None]
    rgb = np.zeros((TAM[1], TAM[0], 3))
    alf = np.zeros((TAM[1], TAM[0]))
    rgb[y0:y0 + h, x0:x0 + w] = c1
    alf[y0:y0 + h, x0:x0 + w] = a1
    return rgb, alf


def _faixa_y(y_de, y_ate):
    """sem luz acima de y_de (some ate y_ate)."""
    def f(px, py):
        import rig_jogador as rg
        return 1 - rg._suave(y_de, y_ate, py)
    return f


# ------------------------------------------------------------ a textura da arte
_POSTER = {}


def _poster():
    if not _POSTER:
        import recortar_jogador as rj
        c = rj.calcular()
        _POSTER["rgb"] = c["rgb"]
        _POSTER["m"] = c["mascara"]
    return _POSTER["rgb"], _POSTER["m"]


def mapa(origem, eixo_y, eixo_x, esc, azular=False):
    """A textura de um pedaco do poster: o ponto local (x, y) da peca (em
    volta do pivo) vem de origem + (x * eixo_x + y * eixo_y) * esc no poster
    (fora do jogador: preto). azular: a luz azul da perna de la."""
    import rig_jogador as rg
    ex = np.array(eixo_x, dtype=np.float64)
    ey = np.array(eixo_y, dtype=np.float64)
    ex /= np.linalg.norm(ex)
    ey /= np.linalg.norm(ey)

    def f_pivo(pivo):
        def f(px, py):
            rgb, m = _poster()
            lx, ly = px - pivo[0], py - pivo[1]
            sx = origem[0] + (lx * ex[0] + ly * ey[0]) * esc
            sy = origem[1] + (lx * ex[1] + ly * ey[1]) * esc
            c = rg._amostra(rgb * m[..., None], sx, sy)
            if azular:
                c = _azular(c)
            return c
        return f
    return f_pivo


def _azular(c):
    """A cor da arte com a luz azul (a perna de la): o escuro vira azul-noite,
    o claro vira azul e branco."""
    l = c.max(axis=2, keepdims=True)
    noite = np.array([3, 12, 34]) / 255.0
    azul = np.array([40, 120, 255]) / 255.0
    branco = np.array([200, 235, 255]) / 255.0
    r = noite * (1 - np.clip(l * 1.6, 0, 1)) + azul * np.clip(l * 1.6, 0, 1)
    return r * (1 - np.clip(l * 2 - 1.2, 0, 1)) + branco * np.clip(l * 2 - 1.2, 0, 1)


def pecas_pernas():
    """[(nome, cor, alfa)] das pecas de baixo, em pe (a ordem do desenho e a
    do jogador_capa.gd: a perna de la, a de ca e o short de cima). A textura
    de cada peca vem da propria arte (o short, a canela e o tenis do poster,
    girados para a posicao em pe; a perna de la com a luz azul)."""
    r = []
    for lado, q in (("l", QUADRIL_L), ("c", QUADRIL_C)):
        de_la = lado == "l"
        k = joelho(q)
        t = tornozelo(q)
        # a canela: a do poster (do joelho ao tornozelo, com a meia laranja),
        # em pe; a frente com a luz azul
        tex = TEX_CANELA(k) if not de_la else TEX_CANELA_LA(k)
        cor, alfa = desenhar(spline(_mover(CANELA_FORMA, k)), sem_luz=_faixa_y(k[1] - 5, k[1] + 12),
                             de_la=de_la, textura=tex)
        r.append(("canela_" + lado, cor, alfa))
        # o tenis: o do poster espelhado (a ponta para a frente)
        tex = TEX_TENIS(t) if not de_la else TEX_TENIS_LA(t)
        cor, alfa = desenhar(spline(_mover(TENIS_FORMA, t, TENIS_ESC)), de_la=de_la, textura=tex)
        r.append(("pe_" + lado, cor, alfa))
        # o short com a coxa (o alto por baixo do short de cima)
        tex = TEX_COXA(q) if not de_la else TEX_COXA_LA(q)
        cor, alfa = desenhar(spline(_mover(COXA_FORMA, q)), sem_luz=_faixa_y(q[1] + 10, q[1] + 34),
                             de_la=de_la, textura=tex)
        r.append(("coxa_" + lado, cor, alfa))
    # o short de cima: o do poster (por cima do alto das duas pernas,
    # sumindo macio embaixo)
    import rig_jogador as rg
    rgb, m = _poster()
    pol = rg.poligono_liso(PELVE_AREA)
    yy = np.arange(TAM[1], dtype=np.float64)[:, None]
    alfa = m * pol * (1 - rg._suave(PELVE_BAIXO[0], PELVE_BAIXO[1], yy))
    r.append(("pelve", rgb, alfa))
    return r


# o short de cima no poster (a barra da camisa cobre o alto) e onde ele some
PELVE_AREA = [(270, 470), (600, 470), (600, 700), (270, 700)]
PELVE_BAIXO = (628.0, 662.0)
# as texturas (de onde vem cada peca no poster): o short da perna de ca (o
# joelho dobrado da capa), o lado de la do short (a luz azul), a canela e o
# tenis (espelhado)
TEX_COXA = mapa((420, 572), (0.857, 0.515), (0.515, -0.857), 0.7)
TEX_COXA_LA = mapa((350, 575), (0, 1), (1, 0), 0.7)
TEX_CANELA = mapa((494, 664.5), (-0.886, 0.464), (0.464, 0.886), 0.97)
TEX_CANELA_LA = mapa((494, 664.5), (-0.886, 0.464), (0.464, 0.886), 0.97, azular=True)
TEX_TENIS = mapa((330, 790), (0, 1), (-1, 0), 1.7)
TEX_TENIS_LA = mapa((330, 790), (0, 1), (-1, 0), 1.7, azular=True)


def _faixa_y_baixo(px, py):
    import rig_jogador as rg
    return rg._suave(636.0, 652.0, py)


