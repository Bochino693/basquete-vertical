"""O JOGADOR DA CAPA EM PECAS, para a apresentacao animar (igualzinho ao
do poster: regata, short, tenis, a bola de fogo):

    python3 -I tools/recortar_jogador.py

Le tools/arte/poster_original.png (a arte, 941 x 1672) e
tools/arte/jogador_mascara.png (o recorte do
jogador, feito uma vez com o BiRefNet - rembg, modelo "birefnet-general")
e grava em imagens/:

jogador_corpo    o corpo (cabeca, regata, short, pernas, os ombros)
jogador_braco_e  o braco levantado (a mao que segura a bola), sem a bola
jogador_braco_d  o outro braco (a mao aberta)
jogador_bola     a bola de fogo (os dedos que ficavam na frente dela,
                 preenchidos com a propria bola)
jogador_aura     o brilho em volta do jogador inteiro (branco: o jogo pinta)

e tools/arte/jogador_pecas.txt com onde cada peca fica no poster e os
pontos de giro (ombros, centro da bola) - o jogo usa estes numeros.
Precisa de numpy e Pillow.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = os.path.join(RAIZ, "imagens")
ARTE = os.path.join(RAIZ, "tools", "arte")

# medidas no poster (941 x 1672)
OMBRO_E = (352, 300)     # giro do braco levantado
OMBRO_D = (548, 392)     # giro do outro braco
BOLA = (190, 112)        # centro da bola
RAIO_BOLA = 106          # a bola com o fogo em volta
JUNTA = 40               # o ombro fica no corpo e no braco (a junta nao abre)

# o que nao e o jogador: o letreiro, a coroa e o jogador pequeno do fundo
FORA = [
    # a barra do letreiro (o tenis vai ate y 905)
    [(0, 905), (330, 905), (330, 880), (941, 880), (941, 1672), (0, 1672)],
    # o jogador pequeno do fundo
    [(600, 728), (941, 728), (941, 880), (600, 880)],
]
# a coroa do letreiro encosta no calcanhar: corte em curva, com a borda
# macia (a canela acaba na linha azul em x ~ 500)
FORA_MACIO = [(505, 692), (941, 692), (941, 880), (330, 905), (345, 862), (380, 816), (440, 792), (500, 770)]
# o braco levantado (do ombro ate a mao e a bola)
BRACO_E = [(0, 0), (338, 0), (338, 230), (360, 255), (362, 330), (338, 368), (250, 352), (150, 285), (0, 260)]
# o outro braco (do ombro ate os dedos)
BRACO_D = [(540, 336), (655, 380), (820, 600), (820, 790), (598, 790), (562, 600), (526, 488), (524, 405)]
# a mao na bola (os dedos ficam na frente dela)
MAO = [(104, 60), (150, 56), (172, 96), (180, 150), (212, 180), (300, 196), (300, 240), (118, 240), (100, 140)]


def poligono(tam, pts):
    im = Image.new("L", tam, 0)
    ImageDraw.Draw(im).polygon(pts, fill=255)
    return np.asarray(im).astype(np.float64) / 255


def disco(tam, c, r, suave=1.5):
    y, x = np.mgrid[0:tam[1], 0:tam[0]].astype(np.float64)
    d = np.sqrt((x - c[0]) ** 2 + (y - c[1]) ** 2)
    return np.clip((r - d) / suave + 0.5, 0, 1)


def borrar(a, raio):
    im = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8), "L")
    return np.asarray(im.filter(ImageFilter.GaussianBlur(raio))).astype(np.float64) / 255


def espelhar(rgb, buraco, centro):
    """Onde os dedos tapavam a bola: o lado de la da bola, espelhado (a bola
    e redonda: as costuras e o fogo continuam no lugar certo)."""
    rgb = rgb.copy()
    ys, xs = np.where(buraco > 0.01)
    xe = np.clip(2 * centro[0] - xs, 0, rgb.shape[1] - 1)
    k = buraco[ys, xs][:, None]
    rgb[ys, xs] = rgb[ys, xe] * k + rgb[ys, xs] * (1 - k)
    return rgb


def gravar(nome, rgb, alfa, caixa):
    x0, y0, x1, y1 = caixa
    rgba = np.zeros((y1 - y0, x1 - x0, 4))
    rgba[..., :3] = rgb[y0:y1, x0:x1]
    rgba[..., 3] = alfa[y0:y1, x0:x1]
    Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(
        os.path.join(IMG, nome + ".png"), optimize=True)


def caixa_de(alfa, margem=4):
    ys, xs = np.where(alfa > 0.02)
    h, w = alfa.shape
    return (max(int(xs.min()) - margem, 0), max(int(ys.min()) - margem, 0),
            min(int(xs.max()) + margem + 1, w), min(int(ys.max()) + margem + 1, h))


def main():
    poster = Image.open(os.path.join(ARTE, "poster_original.png")).convert("RGB")
    tam = poster.size
    rgb = np.asarray(poster).astype(np.float64) / 255
    m = np.zeros((tam[1], tam[0]))
    mascara = Image.open(os.path.join(ARTE, "jogador_mascara.png")).convert("L")
    m[:mascara.size[1], :mascara.size[0]] = np.asarray(mascara).astype(np.float64) / 255
    for p in FORA:
        m *= 1 - poligono(tam, p)
    m *= 1 - borrar(poligono(tam, FORA_MACIO), 5)
    # o braco levantado: so o lado de fora do ombro (com a junta)
    bola = disco(tam, BOLA, RAIO_BOLA, 3.0) * m
    mao = poligono(tam, MAO)
    braco_e = m * poligono(tam, BRACO_E) * (1 - disco(tam, BOLA, RAIO_BOLA + 4, 3.0) * (1 - mao))
    braco_d = m * poligono(tam, BRACO_D)
    junta_e = disco(tam, OMBRO_E, JUNTA, 10.0)
    junta_d = disco(tam, OMBRO_D, JUNTA, 10.0)
    corpo = m * (1 - poligono(tam, BRACO_E)) * (1 - poligono(tam, BRACO_D))
    corpo = np.maximum(corpo, m * np.maximum(junta_e, junta_d))
    corpo *= 1 - bola * (1 - mao)
    # a bola sem os dedos: o buraco preenchido com a propria bola
    bola_a = bola * (1 - mao)
    buraco = borrar(mao, 2.0) * disco(tam, BOLA, RAIO_BOLA - 4, 1.0)
    bola_rgb = espelhar(rgb, buraco, BOLA)
    bola_a = np.maximum(bola_a, buraco * disco(tam, BOLA, 84, 2.0))
    # a aura: o jogador inteiro borrado (o jogo pinta de azul e laranja) -
    # inteira (o poster vivo) e em pecas que giram junto com os bracos (a
    # apresentacao: o brilho do braco vai com o braco). Por dentro do
    # jogador o brilho e mais fraco (o do jogador inteiro, nas pecas tambem)
    tudo = np.maximum(m, bola)
    dentro = 1 - 0.6 * np.clip(borrar(tudo, 3) * 2 - 1, 0, 1)
    aura = np.clip(borrar(tudo, 22) * 1.6, 0, 1) * dentro
    def aura_de(a):
        return np.clip(borrar(a, 22) * 1.6, 0, 1) * dentro
    branco = np.ones_like(rgb)
    pecas = []
    for nome, cor, alfa in (("jogador_corpo", rgb, corpo), ("jogador_braco_e", rgb, braco_e),
                            ("jogador_braco_d", rgb, braco_d), ("jogador_bola", bola_rgb, bola_a),
                            ("jogador_aura", branco, aura),
                            ("jogador_aura_corpo", branco, aura_de(corpo)),
                            ("jogador_aura_braco_e", branco, aura_de(np.maximum(braco_e, bola_a))),
                            ("jogador_aura_braco_d", branco, aura_de(braco_d))):
        cx = caixa_de(alfa)
        gravar(nome, cor, alfa, cx)
        pecas.append((nome, cx))
    with open(os.path.join(ARTE, "jogador_pecas.txt"), "w") as f:
        for nome, cx in pecas:
            f.write("%s %d %d %d %d\n" % (nome, cx[0], cx[1], cx[2] - cx[0], cx[3] - cx[1]))
        f.write("ombro_e %d %d\nombro_d %d %d\nbola %d %d\n" % (OMBRO_E + OMBRO_D + BOLA))
    print("ok: imagens/jogador_*.png")
    for nome, cx in pecas:
        print("  %s: x %d y %d  %d x %d" % (nome, cx[0], cx[1], cx[2] - cx[0], cx[3] - cx[1]))


if __name__ == "__main__":
    main()
