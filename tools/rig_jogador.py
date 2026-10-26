"""O JOGADOR DA CAPA COMO PERSONAGEM 2D ARTICULADO (a apresentacao):

    python3 -I tools/rig_jogador.py            # as pecas
    python3 -I tools/rig_jogador.py previa DIR # + quadros de previa do movimento

O jogador inteiro, da propria arte do poster (tools/arte/poster_original.png
e o recorte tools/arte/jogador_mascara.png), em PECAS INTEIRAS E RIGIDAS,
como um boneco de animacao 2D: pernas (com o calcao), tronco, cabeca, o
braco da bola em duas partes (braco e antebraco com a mao) e a bola, o
outro braco em duas partes. As pecas se encontram nas juntas com sobra
(ombro, cotovelo, pescoco, cintura): a peca de cima acaba macia por cima
da de baixo, entao a junta nao abre nem aparece quando gira - e nada e
entortado (cada peca so gira e anda inteira). O jogo monta o boneco com
ossos (scripts/fx/jogador_capa.gd) e anima de verdade, a 60 quadros.

Grava imagens/jogador_<peca>.png, imagens/jogador_<peca>_aura.png (o
brilho em volta, metade do tamanho) e tools/arte/jogador_pecas.txt (onde
cada peca fica no poster e as juntas: vai no jogador_capa.gd).
Precisa de numpy e Pillow.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import recortar_jogador as rj  # noqa: E402

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = os.path.join(RAIZ, "imagens")
ARTE = os.path.join(RAIZ, "tools", "arte")

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
}
# a cabeca (o que fica acima da linha do pescoco, dentro disto)
CABECA = [(372, 150), (560, 150), (560, 318), (470, 322), (400, 318), (372, 300)]
# o ombro de la por tras do braco (o corpo fechado ali quando o braco sobe:
# a silhueta preta com a luz da borda em cima, como o resto da arte)
OMBRO_TAMPA = [(345, 385), (330, 350), (326, 315), (334, 285), (352, 265), (378, 258),
               (405, 268), (425, 290), (430, 330), (400, 370)]
OMBRO_LUZ = [(331, 300), (336, 283), (352, 266), (378, 259), (404, 268)]
TAM = (941, 1672)


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
    ombro_disco = rj.disco(tam, J["ombro_e"], 46, 3.0)
    # ---- o braco da bola: braco (do ombro ao cotovelo) e antebraco com a mao
    braco = m * np.maximum(rj.poligono(tam, rj.BRACO_E), ombro_disco) * (1 - bola_d * (1 - mao))
    bis = unit(J["ombro_e"], J["cotovelo_e"]) + unit(J["cotovelo_e"], J["pulso_e"])
    lado = plano(J["cotovelo_e"], bis, 3)
    cot = rj.disco(tam, J["cotovelo_e"], 30, 10.0)
    braco_e = braco * np.maximum(1 - lado, rj.disco(tam, J["cotovelo_e"], 34, 2.0))
    antebraco_e = braco * np.maximum(lado, cot)
    # ---- o outro braco
    braco = m * rj.poligono(tam, rj.BRACO_D)
    bis = unit(J["ombro_d"], J["cotovelo_d"]) + unit(J["cotovelo_d"], J["pulso_d"])
    lado = plano(J["cotovelo_d"], bis, 3)
    cot = rj.disco(tam, J["cotovelo_d"], 30, 10.0)
    braco_d = braco * np.maximum(1 - lado, rj.disco(tam, J["cotovelo_d"], 34, 2.0))
    # a raiz some macia sobre o ombro do tronco (que tem o ombro inteiro)
    braco_d *= plano(J["ombro_d"], unit(J["ombro_d"], J["cotovelo_d"]), 16)
    antebraco_d = braco * np.maximum(lado, cot)
    # ---- o corpo (sem os bracos e a bola), com o ombro de ca inteiro
    corpo = m * (1 - rj.poligono(tam, rj.BRACO_E)) * (1 - rj.poligono(tam, rj.BRACO_D))
    corpo = np.maximum(corpo, m * rj.disco(tam, J["ombro_d"], 44, 8.0))
    corpo *= 1 - c["bola"]
    corpo *= 1 - ombro_disco * (1 - rj.poligono(tam, OMBRO_TAMPA))
    # pernas (com o calcao) e tronco: a cintura com sobra, o tronco por cima
    n_cint = (0.22, 1.0)
    pernas = corpo * plano((J["cintura"][0], J["cintura"][1] - 34), n_cint, 2)
    tronco = corpo * (1 - plano(J["cintura"], n_cint, 16))
    # cabeca por cima do pescoco (o tronco fica com o pescoco inteiro)
    n_pesc = (0.12, -1.0)
    cabeca = corpo * rj.poligono(tam, CABECA) * plano((J["pescoco"][0], J["pescoco"][1] + 6), n_pesc, 9)
    tronco *= 1 - rj.poligono(tam, CABECA) * plano((J["pescoco"][0], J["pescoco"][1] - 16), n_pesc, 2)
    # a tampa do ombro de la (peca do tronco: o jogo acende quando o braco sobe)
    tampa = rj.borrar(rj.poligono(tam, OMBRO_TAMPA), 1.2)
    tampa_cor = np.zeros_like(rgb) + np.array([0.02, 0.018, 0.035])
    luz = Image.new("L", tam, 0)
    ImageDraw.Draw(luz).line(OMBRO_LUZ, fill=255, width=3)
    luz = np.asarray(luz.filter(ImageFilter.GaussianBlur(1.2))).astype(np.float64) / 255
    tampa_cor = tampa_cor * (1 - luz[..., None]) + np.array([1.0, 0.56, 0.18]) * luz[..., None]
    return [
        # nome, cor, alfa (a ordem do desenho)
        ("pernas", rgb, pernas),
        ("braco_e", rgb, braco_e),
        ("bola", c["bola_rgb"], c["bola"]),
        ("antebraco_e", rgb, antebraco_e),
        ("tronco", rgb, tronco),
        ("tampa_ombro", tampa_cor, tampa * (1 - np.clip(tronco * 4, 0, 1))),
        ("cabeca", rgb, cabeca),
        ("braco_d", rgb, braco_d),
        ("antebraco_d", rgb, antebraco_d),
    ]


def caixa(alfa, margem):
    ys, xs = np.where(alfa > 0.004)
    x0, y0 = max(xs.min() - margem, 0), max(ys.min() - margem, 0)
    x1, y1 = min(xs.max() + margem + 1, TAM[0]), min(ys.max() + margem + 1, TAM[1])
    return x0, y0, x1, y1


def gravar(nome, cor, alfa, brilho=True):
    """A peca (recortada no tamanho dela) e o brilho em volta (com folga
    para o brilho caber, metade do tamanho, so a transparencia)."""
    x0, y0, x1, y1 = caixa(alfa, 3)
    rgba = np.zeros((y1 - y0, x1 - x0, 4))
    rgba[..., :3] = cor[y0:y1, x0:x1]
    rgba[..., 3] = alfa[y0:y1, x0:x1]
    Image.fromarray((np.clip(rgba, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA").save(
        os.path.join(IMG, "jogador_%s.png" % nome), optimize=True)
    r = [(x0, y0, x1 - x0, y1 - y0)]
    if brilho:
        # (com uma borda vazia em volta do poster: o brilho de quem encosta
        # na borda, como a bola, nao fica cortado)
        P = 64
        cheio = np.pad(alfa, P)
        ys, xs = np.where(cheio > 0.004)
        bx0, by0 = xs.min() - 64, ys.min() - 64
        bx1 = bx0 + (xs.max() + 65 - bx0) // 2 * 2
        by1 = by0 + (ys.max() + 65 - by0) // 2 * 2
        a = cheio[by0:by1, bx0:bx1]
        bx0, by0, bx1, by1 = bx0 - P, by0 - P, bx1 - P, by1 - P
        dentro = 1 - 0.6 * np.clip(rj.borrar(a, 3) * 2 - 1, 0, 1)
        au = np.clip(rj.borrar(a, 22) * 1.6, 0, 1) * dentro
        im = Image.fromarray((au * 255 + 0.5).astype(np.uint8), "L").resize(((bx1 - bx0) // 2, (by1 - by0) // 2), Image.LANCZOS)
        Image.merge("LA", (Image.new("L", im.size, 255), im)).save(os.path.join(IMG, "jogador_%s_aura.png" % nome), optimize=True)
        r.append((bx0, by0, bx1 - bx0, by1 - by0))
    return r


# ------------------------------------------------------------ previa
OSSOS_PAI = {"pernas": None, "tronco": None, "cabeca": "tronco", "ombro_e": "tronco",
             "cotovelo_e": "ombro_e", "ombro_d": "tronco", "cotovelo_d": "ombro_d"}
PIVOS = {"pernas": "quadril", "tronco": "cintura", "cabeca": "pescoco", "ombro_e": "ombro_e",
         "cotovelo_e": "cotovelo_e", "ombro_d": "ombro_d", "cotovelo_d": "cotovelo_d"}
PECA_OSSO = {"pernas": "pernas", "braco_e": "ombro_e", "bola": "cotovelo_e", "antebraco_e": "cotovelo_e",
             "tronco": "tronco", "tampa_ombro": "tronco", "cabeca": "cabeca", "braco_d": "ombro_d",
             "antebraco_d": "cotovelo_d"}


def rot(graus, centro):
    a = math.radians(graus)
    c, s = math.cos(a), math.sin(a)
    cx, cy = centro
    return np.array([[c, -s, cx - c * cx + s * cy], [s, c, cy - s * cx - c * cy], [0, 0, 1.0]])


def ossos(pose):
    o = {}
    for nome in ["pernas", "tronco", "cabeca", "ombro_e", "cotovelo_e", "ombro_d", "cotovelo_d"]:
        pai = OSSOS_PAI[nome]
        base = o[pai] if pai else np.eye(3)
        o[nome] = base @ rot(pose.get(nome, 0.0), J[PIVOS[nome]])
    return o


def previa(pasta, pecas_img, caixas, poses):
    os.makedirs(pasta, exist_ok=True)
    for i, (nome_pose, pose) in enumerate(poses):
        o = ossos(pose)
        tela = Image.new("RGBA", (1100, 1250), (26, 22, 42, 255))
        desl = np.array([[1, 0, 80], [0, 1, 250], [0, 0, 1.0]])
        for nome, img in pecas_img:
            if nome == "tampa_ombro":
                k = min(abs(pose.get("ombro_e", 0.0)) / 40.0, 1.0)
                if k <= 0:
                    continue
                img = img.copy()
                img.putalpha(img.getchannel("A").point(lambda v: int(v * k)))
            x0, y0 = caixas[nome][:2]
            t = desl @ o[PECA_OSSO[nome]] @ np.array([[1, 0, x0], [0, 1, y0], [0, 0, 1.0]])
            inv = np.linalg.inv(t)
            camada = img.transform(tela.size, Image.AFFINE, tuple(inv[:2].ravel()), Image.BICUBIC)
            tela.alpha_composite(camada)
        tela.convert("RGB").save(os.path.join(pasta, "%02d_%s.png" % (i, nome_pose)))


POSES_PREVIA = [
    ("decolagem", {"pernas": 10, "tronco": -8, "cabeca": -4, "ombro_e": -35, "cotovelo_e": 20, "ombro_d": 20, "cotovelo_d": 10}),
    ("subindo", {"pernas": 5, "tronco": -4, "cabeca": -2, "ombro_e": -18, "cotovelo_e": 10, "ombro_d": 10, "cotovelo_d": 5}),
    ("capa", {}),
    ("e1", {"pernas": -4, "tronco": 4, "cabeca": 3, "ombro_e": 40, "cotovelo_e": -25, "ombro_d": -10, "cotovelo_d": -5}),
    ("e2", {"pernas": -7, "tronco": 8, "cabeca": 6, "ombro_e": 80, "cotovelo_e": -35, "ombro_d": -20, "cotovelo_d": -8}),
    ("e3", {"pernas": -9, "tronco": 12, "cabeca": 9, "ombro_e": 118, "cotovelo_e": -30, "ombro_d": -28, "cotovelo_d": -10}),
    ("e4", {"pernas": -10, "tronco": 15, "cabeca": 11, "ombro_e": 150, "cotovelo_e": -15, "ombro_d": -33, "cotovelo_d": -12}),
    ("e5", {"pernas": -10, "tronco": 17, "cabeca": 12, "ombro_e": 172, "cotovelo_e": 5, "ombro_d": -36, "cotovelo_d": -14}),
]


def main():
    lista = pecas()
    caixas = {}
    imgs = []
    brilhos = {}
    for nome, cor, alfa in lista:
        r = gravar(nome, cor, alfa, nome not in ("tampa_ombro", "bola"))
        caixas[nome] = r[0]
        if len(r) > 1:
            brilhos[nome] = r[1]
        imgs.append((nome, Image.open(os.path.join(IMG, "jogador_%s.png" % nome)).convert("RGBA")))
        print("  %s: x %d y %d  %d x %d" % ((nome,) + caixas[nome]))
    with open(os.path.join(ARTE, "jogador_pecas.txt"), "w") as f:
        for nome, _, _ in lista:
            f.write("%s %d %d %d %d\n" % ((nome,) + caixas[nome]))
        for nome, cx in brilhos.items():
            f.write("%s_aura %d %d %d %d\n" % ((nome,) + cx))
        for k, v in J.items():
            f.write("%s %.1f %.1f\n" % (k, v[0], v[1]))
    if len(sys.argv) > 2 and sys.argv[1] == "previa":
        previa(sys.argv[2], imgs, caixas, POSES_PREVIA)


if __name__ == "__main__":
    main()
