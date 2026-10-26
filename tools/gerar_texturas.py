"""Texturas de efeito FEITAS A MAO (por conta, pixel a pixel) do Slam Arena,
gravadas em imagens/fx_*.png (brancas: o jogo pinta de cada cor):

    python3 -I tools/gerar_texturas.py

fx_brilho   brilho redondo (miolo forte, borda que some)
fx_faisca   risco de faisca (alinhado com a velocidade)
fx_estrela  estrela de 4 pontas (cintilar)
fx_feixe    cone de holofote
fx_anel     anel suave
fx_fumaca   nuvem macia de bordas irregulares
fx_confete  papelzinho de confete
fx_linha    perfil macio de linha (raio eletrico: borda lisa)
fx_faixa    faixa cheia com a borda lisa (aneis de progresso nitidos)
fx_raio     perfil do brilho do raio (curva de sino: some macio dos dois lados,
            sem "quina" no meio - o brilho largo do raio fica liso)
fx_ladrilho ladrilho de LED do piso (quadrado de cantos redondos: borda
            acesa, miolo suave e um ponto de luz no centro)
coroa       coroa de ouro DETALHADA (metal com degrade e brilho, rubi, safiras,
            esmeraldas e perolas nas pontas, contorno escuro)
medalha_1..3 medalhas de ouro, prata e bronze (disco com aro serrilhado,
            estrela em relevo, o numero e o brilho do metal)
d7_*        os caracteres do display de 7 segmentos (0-9, "-", vazio) em
            CAMPO DE DISTANCIA: R = distancia ate os segmentos acesos, G =
            ate o "8" (todos, para os apagados). O display7.shader tira
            disso a borda lisa (1 pixel da tela, em qualquer tamanho), o
            miolo quente e o brilho - nitido de perto como de longe.
(Na TV Box gerar isto em GDScript levaria meio segundo; pronto, abre na hora.)
Precisa de numpy e Pillow.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.join(os.path.dirname(AQUI), "imagens")


def suave(v):
    v = np.clip(v, 0, 1)
    return v * v * (3 - 2 * v)


def gravar(nome, alfa):
    a = (np.clip(alfa, 0, 1) * 255 + 0.5).astype(np.uint8)
    h, w = a.shape
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = a
    Image.fromarray(rgba, "RGBA").save(os.path.join(SAIDA, nome + ".png"), optimize=True)


def grade(w, h):
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    return x - (w - 1) / 2.0, y - (h - 1) / 2.0


def main():
    os.makedirs(SAIDA, exist_ok=True)
    x, y = grade(64, 64)
    d = np.sqrt(x * x + y * y) / 32
    gravar("fx_brilho", np.clip(1 - d, 0, 1) ** 2.2)

    x, y = grade(16, 64)
    gravar("fx_faisca", np.clip(1 - np.abs(x) / 8, 0, 1) ** 2 * np.clip(1 - np.abs(y) / 32, 0, 1) ** 1.2)

    x, y = grade(64, 64)
    px, py = x / 32, y / 32
    r = np.sqrt(px * px + py * py)
    cruz = np.maximum(np.clip(1 - np.abs(px) * 9, 0, 1) ** 2 * (1 - np.abs(py)),
                      np.clip(1 - np.abs(py) * 9, 0, 1) ** 2 * (1 - np.abs(px)))
    gravar("fx_estrela", cruz + np.clip(1 - r * 2.2, 0, 1) ** 2)

    w, h = 64, 128
    x, y = grade(w, h)
    t = (y + (h - 1) / 2) / (h - 1)
    meia = 0.12 + 0.88 * t
    dx = np.abs(x) / 32 / meia
    gravar("fx_feixe", 0.9 * np.clip(1 - dx, 0, 1) ** 1.6 * (1 - suave((t - 0.55) / 0.45)) * suave(t / 0.08))

    x, y = grade(128, 128)
    d = np.sqrt(x * x + y * y) / 64
    gravar("fx_anel", np.clip(1 - np.abs(d - 0.8) / 0.16, 0, 1) ** 1.5)

    x, y = grade(64, 64)
    px, py = x / 32, y / 32
    ang = np.arctan2(py, px)
    borda = 0.78 + 0.08 * np.sin(ang * 3) + 0.05 * np.sin(ang * 7 + 1.3)
    gravar("fx_fumaca", 0.8 * np.clip(1 - np.sqrt(px * px + py * py) / borda, 0, 1) ** 1.4)

    x, y = grade(12, 20)
    gravar("fx_confete", suave(1.6 - np.abs(x) / 6 * 1.6) * suave(1.6 - np.abs(y) / 10 * 1.6))
    # (256 px com mipmaps: nitido nos ladrilhos grandes da frente e liso,
    # sem "enrugar", nos pequenos do fundo da quadra)
    x, y = grade(256, 256)
    px, py = np.abs(x) / 127.5, np.abs(y) / 127.5
    # distancia ao quadrado de cantos redondos (raio 0.28), em fracao do lado
    rc = 0.28
    qx, qy = np.maximum(px - (1 - rc), 0), np.maximum(py - (1 - rc), 0)
    fora = np.sqrt(qx * qx + qy * qy) + np.minimum(np.maximum(px - (1 - rc), py - (1 - rc)), 0) - rc
    dentro = suave(-fora / 0.035)
    borda = np.clip(1 - np.abs(fora + 0.06) / 0.045, 0, 1) ** 1.3
    r = np.sqrt(px * px + py * py)
    gravar("fx_ladrilho", np.maximum(borda, dentro * (0.30 + 0.45 * np.clip(1 - r / 0.75, 0, 1) ** 2)))
    x, y = grade(64, 4)
    gravar("fx_linha", np.clip(1 - np.abs(x) / 31.5, 0, 1) ** 1.5)
    x, y = grade(64, 4)
    gravar("fx_faixa", suave((32 - np.abs(x)) / 9.0))
    x, y = grade(64, 4)
    gravar("fx_raio", np.exp(-(x / 13.0) ** 2))
    gerar_display7()
    gerar_coroa()
    gerar_medalhas()
    print("ok: texturas feitas a mao em imagens/fx_*.png e imagens/d7_*.png")


# ------------------------------------------------- display de 7 segmentos
# (a mesma geometria do display7.gd: altura 1, largura 0.56, segmento 0.135,
# pontas em bisel, inclinado 0.10)
D7_W, D7_T, D7_INC = 0.56, 0.135, 0.10
D7_SEGMENTOS = {
    "0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
    "5": "afgcd", "6": "afgedc", "7": "abc", "8": "abcdefg", "9": "abcdfg",
    "menos": "g", "vazio": "",
}
D7_LADO = 256          # textura de cada caractere (px)
D7_ESCALA = 160.0      # px da textura por altura do digito
D7_CENTRO = (0.28, 0.5)
D7_DMIN, D7_DMAX = -0.10, 0.30   # faixa de distancia gravada (fracao da altura)


def d7_segmento(seg):
    m = D7_T * 0.5
    g = D7_T * 0.14
    w, h = D7_W, 1.0
    a, b = {
        "a": ((m + g, m), (w - m - g, m)),
        "g": ((m + g, h * 0.5), (w - m - g, h * 0.5)),
        "d": ((m + g, h - m), (w - m - g, h - m)),
        "f": ((m, m + g), (m, h * 0.5 - g)),
        "b": ((w - m, m + g), (w - m, h * 0.5 - g)),
        "e": ((m, h * 0.5 + g), (m, h - m - g)),
        "c": ((w - m, h * 0.5 + g), (w - m, h - m - g)),
    }[seg]
    a, b = np.array(a), np.array(b)
    d = (b - a) / np.linalg.norm(b - a)
    n = np.array([-d[1], d[0]])
    pts = [a, a + d * m + n * m, b - d * m + n * m, b, b - d * m - n * m, a + d * m - n * m]
    return [np.array([p[0] + (h * 0.5 - p[1]) * D7_INC, p[1]]) for p in pts]


def d7_distancia(poli, px, py):
    """Distancia exata (negativa dentro) de cada ponto ao poligono convexo."""
    n = len(poli)
    dist = np.full(px.shape, np.inf)
    dentro = np.ones(px.shape, bool)
    # sentido do poligono (area com sinal)
    area = sum(poli[i][0] * poli[(i + 1) % n][1] - poli[(i + 1) % n][0] * poli[i][1] for i in range(n))
    for i in range(n):
        ax, ay = poli[i]
        bx, by = poli[(i + 1) % n]
        ex, ey = bx - ax, by - ay
        wx, wy = px - ax, py - ay
        t = np.clip((wx * ex + wy * ey) / (ex * ex + ey * ey), 0, 1)
        dx, dy = wx - ex * t, wy - ey * t
        dist = np.minimum(dist, np.sqrt(dx * dx + dy * dy))
        lado = ex * wy - ey * wx
        dentro &= (lado > 0) if area > 0 else (lado < 0)
    return np.where(dentro, -dist, dist)


def d7_campo(segs, px, py):
    d = np.full(px.shape, D7_DMAX * 4)
    for s in segs:
        d = np.minimum(d, d7_distancia(d7_segmento(s), px, py))
    return np.clip((D7_DMAX - d) / (D7_DMAX - D7_DMIN), 0, 1)


def gerar_display7():
    j, i = np.mgrid[0:D7_LADO, 0:D7_LADO].astype(np.float64)
    px = (i + 0.5 - D7_LADO / 2) / D7_ESCALA + D7_CENTRO[0]
    py = (j + 0.5 - D7_LADO / 2) / D7_ESCALA + D7_CENTRO[1]
    todos = d7_campo("abcdefg", px, py)
    for nome, segs in D7_SEGMENTOS.items():
        rgba = np.zeros((D7_LADO, D7_LADO, 4), np.uint8)
        rgba[..., 0] = (d7_campo(segs, px, py) * 255 + 0.5).astype(np.uint8)
        rgba[..., 1] = (todos * 255 + 0.5).astype(np.uint8)
        rgba[..., 3] = 255
        Image.fromarray(rgba, "RGBA").save(os.path.join(SAIDA, "d7_%s.png" % nome), optimize=True)



# ------------------------------------------------ coroa e medalhas (icones)
# Desenhados em 4x e reduzidos (borda lisa); o metal e um degrade por pixel.
SS = 4


def _mascara(tam, desenhar):
    im = Image.new("L", (tam[0] * SS, tam[1] * SS), 0)
    desenhar(ImageDraw.Draw(im), SS)
    return np.asarray(im).astype(np.float64) / 255


def _metal(h, w, claro, medio, escuro, y0, y1, brilhos=()):
    """Degrade de metal: claro em cima, escuro embaixo, mais escuro nas
    laterais (volume) e faixas de brilho verticais."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    t = np.clip((y - y0) / max(y1 - y0, 1), 0, 1)
    claro, medio, escuro = (np.array(c) for c in (claro, medio, escuro))
    c = np.where(t[..., None] < 0.45, claro + (medio - claro) * (t[..., None] / 0.45),
                 medio + (escuro - medio) * ((t[..., None] - 0.45) / 0.55))
    lado = np.abs(x - w / 2) / (w / 2)
    c = c * (1.0 - 0.28 * lado[..., None] ** 2)
    for bx, larg, forca in brilhos:
        c = c + forca * np.exp(-((x - bx) / larg) ** 2)[..., None]
    return np.clip(c, 0, 1)


def _esfera(h, w, cx, cy, r, cor, brilho=(1, 1, 1)):
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / r
    luz = np.clip(1.15 - np.sqrt((x - cx + r * 0.35) ** 2 + (y - cy + r * 0.35) ** 2) / r, 0, 1)
    c = np.array(cor) * (0.45 + 0.75 * luz[..., None])
    esp = np.exp(-(((x - cx + r * 0.38) ** 2 + (y - cy + r * 0.42) ** 2) / (r * 0.22) ** 2))
    c = c + np.array(brilho) * esp[..., None] * 0.9
    return np.clip(c, 0, 1), d


def _compor(base, cor, alfa):
    a = alfa[..., None]
    base[..., :3] = base[..., :3] * (1 - a) + cor * a
    base[..., 3] = np.maximum(base[..., 3], alfa)


def _gravar_rgba(nome, rgba, tam):
    im = Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")
    im = im.resize(tam, Image.LANCZOS)
    im.save(os.path.join(SAIDA, nome + ".png"), optimize=True)


def _contorno(alfa, px):
    im = Image.fromarray((alfa * 255).astype(np.uint8), "L")
    im = im.filter(ImageFilter.MaxFilter(px * 2 + 1))
    return np.asarray(im).astype(np.float64) / 255


def gerar_coroa():
    W, H = 256, 184
    pontas = [(26, 50), (77, 40), (128, 16), (179, 40), (230, 50)]
    vales = [(54, 104), (102, 98), (154, 98), (202, 104)]
    corpo = [(36, 128)]
    for i, p in enumerate(pontas):
        corpo.append(p)
        if i < len(vales):
            corpo.append(vales[i])
    corpo.append((220, 128))

    def d_corpo(d, k):
        d.polygon([(x * k, y * k) for x, y in corpo], fill=255)

    def d_faixa(d, k):
        d.rounded_rectangle([28 * k, 120 * k, 228 * k, 164 * k], radius=10 * k, fill=255)

    def d_perolas(d, k):
        for x, y in pontas:
            d.ellipse([(x - 11) * k, (y - 19) * k, (x + 11) * k, (y + 3) * k], fill=255)

    h, w = H * SS, W * SS
    m_corpo = _mascara((W, H), d_corpo)
    m_faixa = _mascara((W, H), d_faixa)
    m_per = _mascara((W, H), d_perolas)
    tudo = np.maximum(np.maximum(m_corpo, m_faixa), m_per)
    rgba = np.zeros((h, w, 4))
    # contorno escuro (define a forma de longe)
    _compor(rgba, np.array([0.28, 0.13, 0.02]), _contorno(tudo, 3 * SS))
    ouro = _metal(h, w, (1.0, 0.96, 0.62), (1.0, 0.78, 0.20), (0.78, 0.46, 0.06), 16 * SS, 128 * SS,
                  [(96 * SS, 7 * SS, 0.30), (166 * SS, 5 * SS, 0.18)])
    _compor(rgba, ouro, m_corpo)
    # recorte interno das pontas (relevo): uma linha mais escura por dentro
    borda_int = np.clip(m_corpo - _contorno(1 - m_corpo, 5 * SS) * m_corpo, 0, 1)
    rgba[..., :3] *= (1 - 0.18 * (m_corpo - borda_int)[..., None])
    faixa = _metal(h, w, (1.0, 0.88, 0.42), (0.92, 0.62, 0.12), (0.62, 0.34, 0.04), 120 * SS, 164 * SS,
                   [(96 * SS, 9 * SS, 0.22)])
    _compor(rgba, np.array([0.30, 0.14, 0.02]), _contorno(m_faixa, 2 * SS))
    _compor(rgba, faixa, m_faixa)
    # friso claro em cima e embaixo da faixa
    y = np.mgrid[0:h, 0:w][0] / SS
    frisos = (np.exp(-((y - 125) / 1.6) ** 2) + np.exp(-((y - 159) / 1.6) ** 2)) * m_faixa
    rgba[..., :3] = np.clip(rgba[..., :3] + 0.35 * frisos[..., None], 0, 1)
    # joias da faixa: rubi no meio, safiras e esmeraldas
    joias = [(128, 142, 15, (0.95, 0.08, 0.16)), (84, 142, 10, (0.10, 0.35, 1.0)),
             (172, 142, 10, (0.10, 0.35, 1.0)), (47, 142, 7, (0.05, 0.80, 0.35)),
             (209, 142, 7, (0.05, 0.80, 0.35))]
    for x, yy, r, cor in joias:
        c, d = _esfera(h, w, x * SS, yy * SS, r * SS, cor)
        _compor(rgba, np.array([0.25, 0.12, 0.02]), np.clip((1.18 - d) * 6, 0, 1))
        _compor(rgba, c, np.clip((1.0 - d) * r * SS / 2.5, 0, 1))
    # perolas nas pontas
    for x, yy in pontas:
        c, d = _esfera(h, w, x * SS, (yy - 8) * SS, 10 * SS, (1.0, 0.97, 0.92))
        _compor(rgba, c, np.clip((1.0 - d) * 10 * SS / 2.5, 0, 1))
    _gravar_rgba("coroa", rgba, (W, H))


def gerar_medalhas():
    L = 128
    metais = {
        1: ((1.0, 0.96, 0.60), (1.0, 0.78, 0.16), (0.72, 0.42, 0.04)),
        2: ((1.0, 1.0, 1.0), (0.80, 0.84, 0.90), (0.46, 0.51, 0.60)),
        3: ((1.0, 0.82, 0.58), (0.86, 0.52, 0.24), (0.50, 0.26, 0.08)),
    }
    fonte = ImageFont.truetype(os.path.join(os.path.dirname(AQUI), "fontes", "titan.ttf"), 64 * SS)
    h = w = L * SS
    y, x = np.mgrid[0:h, 0:w].astype(np.float64)
    cx = cy = L * SS / 2
    ang = np.arctan2(y - cy, x - cx)
    r = np.sqrt((x - cx) ** 2 + (y - cy) ** 2) / SS
    for n, (claro, medio, escuro) in metais.items():
        rgba = np.zeros((h, w, 4))
        # aro serrilhado (24 dentes)
        r_aro = 58 + 2.2 * np.cos(ang * 24)
        aro = np.clip((r_aro - r) * SS / 2.0, 0, 1)
        _compor(rgba, np.array(escuro) * 0.45, np.clip((r_aro + 2.5 - r) * SS / 2.0, 0, 1))
        _compor(rgba, _metal(h, w, claro, medio, escuro, 8 * SS, 120 * SS, [(44 * SS, 10 * SS, 0.25)]), aro)
        # disco de dentro, um pouco mais fundo (degrade invertido = relevo)
        disco = np.clip((47 - r) * SS / 2.0, 0, 1)
        _compor(rgba, np.array(escuro) * 0.7, np.clip((49 - r) * SS / 2.0, 0, 1))
        _compor(rgba, _metal(h, w, medio, claro, medio, 20 * SS, 108 * SS, [(50 * SS, 8 * SS, 0.15)]), disco)
        # estrela em relevo atras do numero
        pts = []
        for k in range(10):
            a = -np.pi / 2 + k * np.pi / 5
            rr = 40 if k % 2 == 0 else 17
            pts.append((L / 2 + rr * np.cos(a), L / 2 + rr * np.sin(a) + 2))
        estrela = _mascara((L, L), lambda d, k: d.polygon([(px * k, py * k) for px, py in pts], fill=255))
        rgba[..., :3] = np.clip(rgba[..., :3] * (1 - 0.10 * estrela[..., None]) + 0.10 * estrela[..., None] * np.array(claro), 0, 1)
        # o numero: escuro, com a luz embaixo (gravado no metal)
        def d_num(d, k, dx=0.0, dy=0.0):
            d.text(((L / 2 + dx) * k, (L / 2 + 3 + dy) * k), str(n), font=fonte, fill=255, anchor="mm")
        luz = _mascara((L, L), lambda d, k: d_num(d, k, 0, 2.2))
        num = _mascara((L, L), d_num)
        _compor(rgba, np.array(claro), luz * 0.9)
        _compor(rgba, np.array(escuro) * 0.55, num)
        # brilho do vidro/metal: um arco claro em cima
        reflexo = np.clip(1 - np.abs(np.sqrt((x - cx) ** 2 + (y - cy - 30 * SS) ** 2) / SS - 66) / 5, 0, 1)
        reflexo *= np.clip((cy - y) / (40 * SS), 0, 1) * (r < 56)
        rgba[..., :3] = np.clip(rgba[..., :3] + 0.22 * reflexo[..., None], 0, 1)
        _gravar_rgba("medalha_%d" % n, rgba, (L, L))


if __name__ == "__main__":
    main()
