"""O POSTER VIVO da abertura (Slam Arena):

    python3 -I tools/poster_vivo.py

Le tools/arte/poster_original.png (a arte, 941 x 1672) e
tools/arte/jogador_mascara.png (o recorte do jogador) e grava:

imagens/poster.png       a arte em FULL HD (1080 x 1920): ampliada uma vez
                         com Lanczos e um realce leve (nitida, sem a placa
                         esticar na hora)
imagens/poster_vivo.png  o MAPA do que mexe na arte (540 x 960), lido pelo
                         shaders/poster.shader:
                           R = luzes (janelas dos predios, refletores da
                               arena): piscam, acendem e apagam
                           G = o sorteio de cada luz (cada uma muda no
                               seu tempo; 16 valores, j / 15)
                           B = neon (o telao SLAM, a coroa grafitada, o
                               muro de grafite): pulsa e falha como neon
                           A = fogo (a bola, o aro, o contorno em brasa do
                               jogador): tremula com o ruido subindo
imagens/poster_ruido.png ruido macio que emenda nos lados (128 x 128): o
                         fogo do poster tremula com ele subindo
Precisa de numpy e Pillow.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = os.path.join(RAIZ, "imagens")
ARTE = os.path.join(RAIZ, "tools", "arte")
TELA = (1080, 1920)
MAPA = (540, 960)

# regioes no poster original (941 x 1672)
PREDIOS = [
    [(0, 215), (58, 215), (58, 470), (0, 470)],          # os da esquerda
    [(64, 312), (156, 312), (156, 500), (64, 500)],      # o alto (com os letreiros)
    [(156, 385), (252, 385), (252, 540), (156, 540)],    # o da frente
]
REFLETORES = [(690, 460), (860, 440), (941, 415), (941, 530), (690, 565)]
TELAO = [(752, 530), (941, 515), (941, 800), (752, 800)]
GRAFITE = [(0, 515), (175, 515), (160, 672), (0, 672)]
LETREIRO_Y = 745          # dali para baixo e o letreiro SLAM ARENA (fica como esta)
BOLA = (190, 112)
REFLETOR = (772, 512)


def poligono(tam, pts, escala=1.0):
    im = Image.new("L", tam, 0)
    ImageDraw.Draw(im).polygon([(x * escala, y * escala) for x, y in pts], fill=255)
    return np.asarray(im).astype(np.float64) / 255


def disco(tam, c, r, escala=1.0, suave=6.0):
    y, x = np.mgrid[0:tam[1], 0:tam[0]].astype(np.float64)
    d = np.hypot(x - c[0] * escala, y - c[1] * escala)
    return np.clip((r * escala - d) / suave + 0.5, 0, 1)


def filtro(a, f):
    im = Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), "L")
    return np.asarray(im.filter(f)).astype(np.float64) / 255


def ampliar(orig):
    im = orig.resize(TELA, Image.LANCZOS)
    return im.filter(ImageFilter.UnsharpMask(radius=1.3, percent=45, threshold=2))


def mapa(rgb, jogador):
    """O mapa do que mexe (em 1080 x 1920; reduzido no fim)."""
    tam = TELA
    k = TELA[0] / 941.0
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    v = np.maximum(r, np.maximum(g, b))
    mn = np.minimum(r, np.minimum(g, b))
    sat = (v - mn) / np.maximum(v, 1e-3)
    fundo = filtro(v, ImageFilter.GaussianBlur(7))
    ponto = np.clip((v - fundo - 0.04) / 0.16, 0, 1)        # luz pequena no escuro
    longe = 1 - filtro(jogador, ImageFilter.MaxFilter(25))   # longe do jogador e do contorno em brasa
    # luzes: janelas e refletores
    luz = ponto * np.clip((v - 0.30) / 0.25, 0, 1)
    regiao = poligono(tam, REFLETORES, k)
    for p in PREDIOS:
        regiao = np.maximum(regiao, poligono(tam, p, k))
    luzes = luz * regiao * longe
    # neon: as cores fortes do telao, da coroa e do grafite
    neon = np.clip((v - 0.35) / 0.3, 0, 1) * np.clip((sat - 0.35) / 0.3, 0, 1)
    neon = neon * np.maximum(poligono(tam, TELAO, k), poligono(tam, GRAFITE, k) * longe)
    # fogo: o laranja forte em cima do letreiro (bola, aro, contorno, faiscas)
    laranja = np.clip((r - 0.5) / 0.3, 0, 1) * np.clip((r - b - 0.3) / 0.3, 0, 1) * (g < r * 0.95)
    acima = poligono(tam, [(0, 0), (941, 0), (941, LETREIRO_Y), (0, LETREIRO_Y)], k)
    fogo = laranja * acima * (1 - poligono(tam, TELAO, k)) * (1 - poligono(tam, GRAFITE, k)) * (1 - luzes)
    fogo = np.maximum(fogo, laranja * disco(tam, BOLA, 135, k, 30))
    # o refletor grande tem o brilho dele (scripts/fx/poster_vivo.gd)
    luzes *= 1 - disco(tam, REFLETOR, 70, k, 20)
    return luzes, neon, fogo


def sorteio(luzes, limiar=0.08, grande=40):
    """Cada luz (cada janela, cada lampada: os pontos acesos que se
    encostam) ganha o seu sorteio - acende e apaga inteira, nunca em
    pedacos. 16 valores, j / 15 (o shader usa o sorteio vezes um tempo que
    da a volta a cada 15 voltas inteiras: o numero fica pequeno na placa).
    As luzes grandes (holofotes) so pulsam um pouco (nao apagam)."""
    h, w = luzes.shape
    acesa = luzes > limiar
    rotulo = np.full((h, w), -1, dtype=np.int64)
    rnd = np.random.RandomState(941)
    fases = []
    luzes = luzes.copy()
    for y0, x0 in zip(*np.where(acesa)):
        if rotulo[y0, x0] >= 0:
            continue
        n = len(fases)
        fases.append(np.floor(rnd.rand() * 16) / 15)
        pilha = [(y0, x0)]
        rotulo[y0, x0] = n
        pontos = []
        while pilha:
            y, x = pilha.pop()
            pontos.append((y, x))
            for yy, xx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= yy < h and 0 <= xx < w and acesa[yy, xx] and rotulo[yy, xx] < 0:
                    rotulo[yy, xx] = n
                    pilha.append((yy, xx))
        if len(pontos) > grande:
            ys, xs = zip(*pontos)
            luzes[ys, xs] *= 0.35
    # a borda de cada luz (macia) fica com o sorteio dela
    for _ in range(2):
        livre = rotulo < 0
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            viz = np.roll(np.roll(rotulo, dy, 0), dx, 1)
            pega = livre & (viz >= 0)
            rotulo[pega] = viz[pega]
            livre = rotulo < 0
    tabela = np.array(fases + [0.0])
    fase = tabela[rotulo]          # (-1 = sem luz: o ultimo, 0)
    return luzes, fase


def ruido(lado=128, seed=7):
    rnd = np.random.RandomState(seed)
    total = np.zeros((lado, lado))
    peso = 0.0
    for oit, w in ((4, 1.0), (8, 0.5), (16, 0.25), (32, 0.125)):
        g = rnd.rand(oit, oit)
        # amplia emendando nos lados (interpolacao cubica periodica)
        t = np.arange(lado) * oit / lado
        i0 = np.floor(t).astype(int)
        f = t - i0
        f = f * f * (3 - 2 * f)
        linhas = g[i0 % oit] * (1 - f)[:, None] + g[(i0 + 1) % oit] * f[:, None]
        tudo = linhas[:, i0 % oit] * (1 - f)[None, :] + linhas[:, (i0 + 1) % oit] * f[None, :]
        total += tudo * w
        peso += w
    total /= peso
    total = (total - total.min()) / (total.max() - total.min())
    return total


def contorno(jogador, passo=26):
    """Pontos na borda do jogador (um por quadradinho de passo x passo, no
    poster original): onde estalam as faiscas de energia em volta dele."""
    m = jogador > 0.5
    im = Image.fromarray((m * 255).astype(np.uint8), "L")
    dentro = np.asarray(im.filter(ImageFilter.MinFilter(5))) > 127
    borda = m & ~dentro
    ys, xs = np.where(borda)
    vistos = {}
    for x, y in zip(xs, ys):
        if y > LETREIRO_Y - 60:
            continue
        chave = (x // passo, y // passo)
        if chave not in vistos:
            vistos[chave] = (int(x), int(y))
    pts = []
    for p in sorted(vistos.values(), key=lambda p: (p[1], p[0])):
        if all((p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2 >= 20 ** 2 for q in pts):
            pts.append(p)
    return pts


def main():
    orig = Image.open(os.path.join(ARTE, "poster_original.png")).convert("RGB")
    assert orig.size == (941, 1672), orig.size
    hd = ampliar(orig)
    hd.save(os.path.join(IMG, "poster.png"), optimize=True)
    rgb = np.asarray(hd).astype(np.float64) / 255
    # (a mascara so tem a parte de cima do poster: o resto e vazio)
    jog = Image.new("L", orig.size, 0)
    jog.paste(Image.open(os.path.join(ARTE, "jogador_mascara.png")).convert("L"), (0, 0))
    jogador = np.asarray(jog.resize(TELA, Image.BILINEAR)).astype(np.float64) / 255
    luzes, neon, fogo = mapa(rgb, jogador)
    reduz = []
    for c in (luzes, neon, fogo):
        im = Image.fromarray((np.clip(c, 0, 1) * 255 + 0.5).astype(np.uint8), "L")
        reduz.append(np.asarray(im.resize(MAPA, Image.BOX)).astype(np.float64) / 255)
    luzes, fase = sorteio(reduz[0])
    canais = [Image.fromarray((np.clip(c, 0, 1) * 255 + 0.5).astype(np.uint8), "L") for c in (luzes, fase, reduz[1], reduz[2])]
    Image.merge("RGBA", canais).save(os.path.join(IMG, "poster_vivo.png"), optimize=True)
    rz = ruido()
    Image.fromarray((rz * 255 + 0.5).astype(np.uint8), "L").save(os.path.join(IMG, "poster_ruido.png"), optimize=True)
    jog941 = np.asarray(jog).astype(np.float64) / 255
    pts = contorno(jog941)
    k = TELA[0] / 941.0
    with open(os.path.join(ARTE, "poster_contorno.txt"), "w") as f:
        f.write(", ".join("Vector2(%d, %d)" % (round(x * k), round(y * k)) for x, y in pts) + "\n")
    print("ok: %d pontos no contorno (tools/arte/poster_contorno.txt: vai no scripts/fx/poster_vivo.gd)" % len(pts))
    print("ok: imagens/poster.png %s, poster_vivo.png %s, poster_ruido.png" % (hd.size, MAPA))


if __name__ == "__main__":
    main()
