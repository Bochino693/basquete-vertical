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
fx_ladrilho ladrilho de LED do piso (quadrado de cantos redondos: borda
            acesa, miolo suave e um ponto de luz no centro)
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
from PIL import Image

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
    x, y = grade(64, 64)
    px, py = np.abs(x) / 31.5, np.abs(y) / 31.5
    # distancia ao quadrado de cantos redondos (raio 0.28), em fracao do lado
    rc = 0.28
    qx, qy = np.maximum(px - (1 - rc), 0), np.maximum(py - (1 - rc), 0)
    fora = np.sqrt(qx * qx + qy * qy) + np.minimum(np.maximum(px - (1 - rc), py - (1 - rc)), 0) - rc
    dentro = suave(-fora / 0.05)
    borda = np.clip(1 - np.abs(fora + 0.07) / 0.06, 0, 1) ** 1.3
    r = np.sqrt(px * px + py * py)
    gravar("fx_ladrilho", np.maximum(borda, dentro * (0.30 + 0.45 * np.clip(1 - r / 0.75, 0, 1) ** 2)))
    x, y = grade(64, 4)
    gravar("fx_linha", np.clip(1 - np.abs(x) / 31.5, 0, 1) ** 1.5)
    x, y = grade(64, 4)
    gravar("fx_faixa", suave((32 - np.abs(x)) / 9.0))
    gerar_display7()
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


if __name__ == "__main__":
    main()
