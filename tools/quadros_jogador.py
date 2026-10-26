"""O JOGADOR DA APRESENTACAO, QUADRO A QUADRO (o Slam Arena):

    python3 -I tools/quadros_jogador.py              # os quadros e o roteiro
    python3 -I tools/quadros_jogador.py previa DIR   # + o filme de previa

Cada QUADRO e o jogador da capa INTEIRO numa imagem so, renderizado aqui da
propria arte do poster: as pecas do tools/rig_jogador.py (a regata, o
short, os tenis, os bracos, com as juntas refeitas pixel a pixel) posadas
osso a osso, desenhadas em dobro e reduzidas - borda lisa, sem emenda. As
pernas acham o chao sozinhas (os pes nao escorregam) e as maos vao onde a
bola esta. O brilho azul em volta sai do corpo inteiro.

A animacao inteira e decidida aqui, 60 vezes por segundo: o jogador entra
correndo e quicando a bola (cada quique no chao), o ultimo quique manda a
bola la para o alto, ele salta, pega a bola la em cima, a camera chega
perto e fica lenta ate a POSE DA CAPA, ele enterra e fica pendurado no aro
enquanto a bola cai pela rede e quica. A bola e UMA SO do comeco ao fim (a
da capa, com o fogo: imagens/jogador_bola.png); os dedos que ficam na
frente dela vao num quadrinho a parte, por cima.

Grava imagens/jogador_quadros_N.png (os quadros, em paginas),
imagens/jogador_bola.png e scripts/fx/jogador_quadros_dados.gd (onde cada
quadro esta, o roteiro e os acontecimentos); o jogo so passa os quadros
(scripts/fx/jogador_quadros.gd e scripts/apresentacao.gd).
Precisa de numpy e Pillow (e das pecas: python3 -I tools/rig_jogador.py).
"""
import math
import os
import shutil
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pernas_jogador as pj  # noqa: E402
import rig_jogador as rig  # noqa: E402

RAIZ = rig.RAIZ
IMG = os.path.join(RAIZ, "imagens")
J = {k: np.array(v, dtype=np.float64) for k, v in rig.J.items()}
CINT = J["cintura"]                 # a ancora do jogador (o osso do tronco)

# o mundo da apresentacao (scripts/apresentacao.gd)
CHAO = 1520.0
ARO = np.array([540.0, 560.0])
ESC = 0.75                          # px do mundo por px do poster
FPS = 60
RAIO_BOLA = 74.0                    # a bola sem o fogo (poster)
R_BOLA = RAIO_BOLA * ESC            # no mundo
SOLA = 52.0 * pj.TENIS_ESC          # do tornozelo ao chao (o tenis em pe)
PONTA = np.array([100.0, 52.0]) * pj.TENIS_ESC   # a ponta do tenis (do tornozelo)
# a pegada da mao da bola (os dedos, no antebraco de la): pendurado no aro
PEGADA = np.array([172.0, 150.0])

# a nitidez: px da textura por px do poster (no chao a camera fica de
# longe; no ar ela chega perto - zoom ate ~1,2)
ST_CHAO = 0.70
ST_AR = 0.75
SS = 2                              # desenhado em dobro e reduzido
BRILHO_RED = 4                      # o brilho em 1/4 (e so uma nevoa)
BRILHO_SIG = (9.0, 24.0)            # (poster)


# ================================================================ as pecas
def _carregar():
    pecas = []
    for linha in open(os.path.join(rig.PECAS, "pecas.txt")):
        p = linha.split()
        if p and p[0] == "peca":
            img = Image.open(os.path.join(rig.PECAS, p[1] + ".png")).convert("RGBA")
            pecas.append((p[1], img.convert("RGBa"), int(p[2]), int(p[3])))
    atlas = Image.open(os.path.join(rig.PECAS, "juntas.png")).convert("RGBA")
    juntas = {"ombro": [], "cotovelo": []}
    for linha in open(os.path.join(rig.PECAS, "juntas.txt")):
        if linha.startswith("#") or not linha.strip():
            continue
        p = linha.split()
        cx, cy, ax, ay, w, h = (int(v) for v in p[4:10])
        img = atlas.crop((ax, ay, ax + w, ay + h)).convert("RGBa") if w > 0 else None
        juntas[p[0]].append((float(p[1]), img, (cx, cy), np.array([float(p[2]), float(p[3])])))
    return pecas, juntas


PECAS, JUNTAS = _carregar()
DE = {"ombro": rig.OMBRO_DE, "cotovelo": rig.COTOVELO_DE}


def _remendo(junta, ang):
    lista = JUNTAS[junta]
    de = DE[junta]
    i = int(round((min(max(ang, de), de + rig.PASSO * (len(lista) - 1)) - de) / rig.PASSO))
    ang_i, img, canto, P2 = lista[i]
    return None if img is None else (img, (ang_i, canto, P2))


def compor(pose, st, so=None):
    """O jogador inteiro na pose (sem a bola), st px da textura por px do
    poster: (imagem RGBA, canto no espaco do jogador). so: so estas pecas."""
    o = rig.ossos(pose)
    itens = []
    for nome, img, x0, y0 in PECAS:
        if nome == "bola" or (so is not None and nome not in so):
            continue
        itens.append((img, o[rig.PECA_OSSO[nome]] @ rig.mover((x0, y0))))
        if so is not None:
            continue
        if nome == "antebraco_e":
            ang = pose.get("cotovelo_e", 0.0)
            r = _remendo("cotovelo", ang)
            if r:
                itens.append((r[0], o["ombro_e"] @ rig._transf_remendo(ang, r[1], J["cotovelo_e"])))
        if nome == "tronco":
            ang = pose.get("ombro_e", 0.0)
            r = _remendo("ombro", ang)
            if r:
                S2 = J["ombro_e"] + rig.deslocamento_ombro(ang)
                itens.append((r[0], o["tronco"] @ rig._transf_remendo(ang, r[1], S2)))
    cantos = []
    for img, T in itens:
        w, h = img.size
        for c in ((0, 0), (w, 0), (0, h), (w, h)):
            cantos.append((T @ (c[0], c[1], 1.0))[:2])
    cantos = np.array(cantos)
    b0 = np.floor(cantos.min(0)) - 2
    b1 = np.ceil(cantos.max(0)) + 2
    k = st * SS
    W, H = int(math.ceil((b1[0] - b0[0]) * k)), int(math.ceil((b1[1] - b0[1]) * k))
    M = np.diag([k, k, 1.0]) @ rig.mover(-b0)
    tela = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for img, T in itens:
        A = M @ T
        w, h = img.size
        c = np.array([(A @ (x, y, 1.0))[:2] for x, y in ((0, 0), (w, 0), (0, h), (w, h))])
        i0 = np.maximum(np.floor(c.min(0)).astype(int) - 2, 0)
        i1 = np.minimum(np.ceil(c.max(0)).astype(int) + 2, (W, H))
        if i1[0] <= i0[0] or i1[1] <= i0[1]:
            continue
        inv = np.linalg.inv(A) @ rig.mover(i0)
        sub = img.transform((int(i1[0] - i0[0]), int(i1[1] - i0[1])), Image.AFFINE,
                            tuple(inv[:2].ravel()), Image.BICUBIC)
        tela.alpha_composite(sub.convert("RGBA"), (int(i0[0]), int(i0[1])))
    img = tela.convert("RGBa").reduce(SS).convert("RGBA")
    caixa = img.getchannel("A").point(lambda a: 255 if a > 2 else 0).getbbox()
    if caixa is None:
        return None, b0
    img = img.crop(caixa)
    return img, b0 + np.array(caixa[:2], dtype=np.float64) / st


def brilho(img, canto, st):
    """O brilho em volta do corpo inteiro (so a transparencia, em 1/4):
    (imagem L, canto no espaco do jogador, px do poster por px)."""
    R = BRILHO_RED
    m = int(math.ceil(3.0 * BRILHO_SIG[1] * st / R)) * R
    a = np.asarray(img.getchannel("A")).astype(np.float64) / 255
    h, w = a.shape
    H, W = (h + 2 * m + R - 1) // R * R, (w + 2 * m + R - 1) // R * R
    cheio = np.zeros((H, W))
    cheio[m:m + h, m:m + w] = a
    a4 = cheio.reshape(H // R, R, W // R, R).mean(axis=(1, 3))
    base = Image.fromarray((a4 * 255).astype(np.uint8), "L")
    g = np.zeros_like(a4)
    for sig, peso in zip(BRILHO_SIG, (0.9, 0.75)):
        b = np.asarray(base.filter(ImageFilter.GaussianBlur(sig * st / R))).astype(np.float64) / 255
        g += peso * b
    g = np.clip(g * 1.25, 0, 1)
    return Image.fromarray((g * 255 + 0.5).astype(np.uint8), "L"), canto - m / st, R / st


# ================================================================ cinematica
def ponto(o, osso, p):
    return (o[osso] @ (p[0], p[1], 1.0))[:2]


def giro(o, osso):
    return math.atan2(o[osso][1, 0], o[osso][0, 0])


def _ang(v):
    return math.atan2(v[1], v[0])


def _norm(a):
    return (a + 180.0) % 360.0 - 180.0


def perna(pose, lado, alvo, pe_graus):
    """O tornozelo no alvo (espaco do jogador), o pe no angulo (0 = o pe da
    arte em pe; + = a ponta desce). O joelho dobra para a frente."""
    o = rig.ossos(pose)
    h = ponto(o, "pelve", J["quadril_" + lado])
    pai = giro(o, "pelve")
    d = np.asarray(alvo, dtype=np.float64) - h
    l1, l2 = pj.COXA, pj.CANELA
    dist = min(max(np.linalg.norm(d), abs(l1 - l2) + 1.0), l1 + l2 - 0.5)
    base = _ang(d)
    a = math.acos(min(max((l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist), -1.0), 1.0))
    coxa = base - a
    joelho = h + l1 * np.array([math.cos(coxa), math.sin(coxa)])
    fim = h + dist * np.array([math.cos(base), math.sin(base)])
    canela = _ang(fim - joelho)
    pose["coxa_" + lado] = math.degrees(coxa - math.pi / 2 - pai)
    pose["joelho_" + lado] = math.degrees(canela - coxa)
    pose["pe_" + lado] = pe_graus - math.degrees(canela - math.pi / 2)
    return pose


def tornozelo_no_chao(chao_y, ponta_x, pe_graus):
    """Onde fica o tornozelo com a ponta do tenis no chao (em ponta_x) e o
    pe girado pe_graus em volta dela (o calcanhar sobe)."""
    a = math.radians(pe_graus)
    c, s = math.cos(a), math.sin(a)
    v = -PONTA
    return np.array([ponta_x, chao_y]) + np.array([c * v[0] - s * v[1], s * v[0] + c * v[1]])


BRACOS = {
    # osso do braco, do antebraco, ombro, cotovelo, a ponta (o centro da bola)
    "e": ("ombro_e", "cotovelo_e", "ombro_e", "cotovelo_e", "bola"),
    "d": ("ombro_d", "cotovelo_d", "ombro_d", "cotovelo_d", "bola_mao_d"),
}
LIMITES = {"ombro_e": (-140.0, 130.0), "cotovelo_e": (-40.0, 25.0),
           "ombro_d": (-120.0, 60.0), "cotovelo_d": (-75.0, 20.0)}


def braco(pose, lado, alvo, ponta=None, preferido=None):
    """A ponta do braco (o centro da bola na mao) no alvo: das duas dobras
    do cotovelo, a que fica dentro dos limites (ou a mais perto da
    preferida)."""
    ob, oa, jo, jc, jp = BRACOS[lado]
    P = J[jp] if ponta is None else np.asarray(ponta, dtype=np.float64)
    u0 = J[jc] - J[jo]
    f0 = P - J[jc]
    l1, l2 = np.linalg.norm(u0), np.linalg.norm(f0)
    alvo = np.asarray(alvo, dtype=np.float64)
    for _ in range(4):           # (o ombro da bola anda com o braco)
        o = rig.ossos(pose)
        S = ponto(o, ob, J[jo])
        pai = giro(o, "tronco")
        d = alvo - S
        dist = min(max(np.linalg.norm(d), abs(l1 - l2) + 0.5), l1 + l2 - 0.2)
        base = _ang(d)
        a = math.acos(min(max((l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist), -1.0), 1.0))
        melhor = None
        for sinal in (1.0, -1.0):
            A1 = base + sinal * a
            E = S + l1 * np.array([math.cos(A1), math.sin(A1)])
            A2 = _ang(alvo - E)
            om = _norm(math.degrees(A1 - _ang(u0) - pai))
            co = _norm(math.degrees((A2 - A1) - (_ang(f0) - _ang(u0))))
            lo, hi = LIMITES[ob], LIMITES[oa]
            fora = max(0.0, lo[0] - om, om - lo[1]) + max(0.0, hi[0] - co, co - hi[1])
            perto = 0.0 if preferido is None else abs(_norm(co - preferido))
            nota = fora * 10 + perto
            if melhor is None or nota < melhor[0]:
                melhor = (nota, om, co)
        pose[ob] = min(max(melhor[1], LIMITES[ob][0]), LIMITES[ob][1])
        pose[oa] = min(max(melhor[2], LIMITES[oa][0]), LIMITES[oa][1])
    return pose


def bola_mao(o, lado):
    """(centro da bola, giro) na mao (espaco do jogador)."""
    if lado == "e":
        return ponto(o, "cotovelo_e", J["bola"]), giro(o, "cotovelo_e")
    return ponto(o, "cotovelo_d", J["bola_mao_d"]), giro(o, "cotovelo_d")


def mundo(B, p):
    return np.asarray(B, dtype=np.float64) + ESC * (np.asarray(p, dtype=np.float64) - CINT)


def jogador(B, w):
    return CINT + (np.asarray(w, dtype=np.float64) - np.asarray(B, dtype=np.float64)) / ESC


def suave(k):
    k = min(max(k, 0.0), 1.0)
    return k * k * (3 - 2 * k)


def misturar(a, b, k):
    r = {}
    for n in set(a) | set(b):
        r[n] = a.get(n, 0.0) + (b.get(n, 0.0) - a.get(n, 0.0)) * k
    return r


def hermite(p0, v0, p1, v1, T, tau):
    """Cubica de p0 (velocidade v0) a p1 (v1) em T segundos, no tempo tau."""
    s = min(max(tau / T, 0.0), 1.0)
    h00 = 2 * s ** 3 - 3 * s ** 2 + 1
    h10 = s ** 3 - 2 * s ** 2 + s
    h01 = -2 * s ** 3 + 3 * s ** 2
    h11 = s ** 3 - s ** 2
    return h00 * p0 + h10 * T * v0 + h01 * p1 + h11 * T * v1


# ================================================================ a corrida
# correndo e quicando a bola com a mao de ca (um quique a cada dois passos);
# o ciclo e um so (NC quadros) e se repete. O corpo anda junto com os
# quadros (os pes no chao nao escorregam).
P = 0.66                            # um ciclo (dois passos e um quique), s
NC = 12                             # quadros por ciclo
V = 280.0                           # a corrida (mundo, px/s)
X0 = 200.0 - V * (2 + 0.5) * P       # onde comeca (pisa em x 200 no 3o quique)
APOIO = 0.38                        # a parte do ciclo com o pe no chao
PASSO_PE = V * APOIO * P / ESC      # o pe no apoio anda isso para tras (poster)
PISA = 0.40                         # o pe pisa essa parte do passo na frente
LEVANTA = 120.0                     # o pe sobe (poster)
Y_CORRE = CHAO - (J["tornozelo_c"][1] + SOLA - CINT[1]) * ESC + 8
BALANCO = 7.0                       # o corpo sobe e desce (mundo)
G = 2600.0                          # a gravidade da bola (mundo, px/s2)
DXB = 182.0                         # a bola na frente do corpo (mundo)
Y_PEGA = Y_CORRE + 126.0            # a mao pega a bola subindo
Y_SOLTA = Y_CORRE + 136.0           # e solta empurrando para baixo
Y_ESPERA = Y_CORRE + 108.0          # a mao esperando a bola voltar
Y_QUICA = CHAO - R_BOLA             # o centro da bola no chao
F_PEGA, F_SOLTA = 10.0 / NC, 13.0 / NC     # a mao na bola (fase do ciclo)
F_QUICA = 0.5                       # a bola no chao
T_DESCE = (F_QUICA - (F_SOLTA - 1.0)) * P
T_SOBE = (F_PEGA - F_QUICA) * P
V_SOLTA = (Y_QUICA - Y_SOLTA - 0.5 * G * T_DESCE ** 2) / T_DESCE
V_PEGA = -((Y_QUICA - Y_PEGA + 0.5 * G * T_SOBE ** 2) / T_SOBE - G * T_SOBE)


def corpo_corre(f):
    """O corpo (x relativo, y) na fase f do ciclo."""
    return np.array([0.0, Y_CORRE + BALANCO * math.cos(4 * math.pi * (f - APOIO / 2))])


def mao_corre_y(f):
    """A altura (mundo) do centro da bola na mao de ca, na fase f."""
    f = f % 1.0
    if f >= F_PEGA or f < F_SOLTA - 1.0:
        tau = ((f - F_PEGA) % 1.0) * P
        return hermite(Y_PEGA, V_PEGA, Y_SOLTA, V_SOLTA, (F_SOLTA - F_PEGA) * P, tau)
    # sem a bola: a mao volta para cima e espera a bola
    tau = (f - (F_SOLTA - 1.0)) * P
    t1 = (0.45 - (F_SOLTA - 1.0)) * P
    if tau < t1:
        return hermite(Y_SOLTA, V_SOLTA * 0.4, Y_ESPERA, 0.0, t1, tau)
    return hermite(Y_ESPERA, 0.0, Y_PEGA, V_PEGA * 0.8, (F_PEGA - 0.45) * P, tau - t1)


def pose_corre(f):
    """(pose, corpo) na fase f do ciclo."""
    B = corpo_corre(f)
    pose = {"tronco": 24.0, "pelve": -16.0, "cabeca": 2.0 + 1.5 * math.sin(4 * math.pi * f),
            "ombro_e": -66.0 + 12.0 * math.cos(2 * math.pi * (f - 0.3)), "cotovelo_e": 16.0}
    chao = jogador(B, (0.0, CHAO))[1]
    for lado, fase in (("c", 0.0), ("l", 0.5)):
        o = rig.ossos(pose)
        q = ponto(o, "pelve", J["quadril_" + lado])
        g = (f - fase) % 1.0
        if g < APOIO:
            s = g / APOIO
            ponta_x = q[0] + PASSO_PE * (PISA - s) + PONTA[0]
            pe = 34.0 * suave((s - 0.45) / 0.55)
            alvo = tornozelo_no_chao(chao, ponta_x, pe)
        else:
            u = (g - APOIO) / (1.0 - APOIO)
            ini = tornozelo_no_chao(chao, q[0] + PASSO_PE * (PISA - 1.0) + PONTA[0], 34.0)
            fim = tornozelo_no_chao(chao, q[0] + PASSO_PE * PISA + PONTA[0], 0.0)
            k = suave(u * 1.1 - 0.05)
            alvo = ini + (fim - ini) * k
            alvo[1] -= LEVANTA * math.sin(math.pi * u) ** 0.9 * (1.15 - 0.3 * u)
            pe = 34.0 + (-4.0 - 34.0) * suave(u)
        perna(pose, lado, alvo, pe)
    braco(pose, "d", jogador(B, (B[0] + DXB, mao_corre_y(f))), preferido=-10.0)
    return pose, B


# ================================================================ o roteiro
# (segundos desde que a parte do jogador comeca; a bola do 3o quique sobe
# la para o alto e ele pega la em cima)
T_PLANTA = (2 + F_QUICA) * P        # o 3o quique (o pe de la pisa junto)
T_SAI = 1.86                        # os pes saem do chao
T_PEGA = 2.32                       # a mao de la pega a bola la em cima
T_GOLPE = 3.20                      # acaba a camera lenta: o braco vem
T_IMPACTO = 3.48                    # a bola no aro
T_FIM = 4.20
BOLA_ARO = ARO + np.array([4.0, 12.0])
CAPA = dict(rig.PERNAS_CAPA)
ENTERRADA = [
    dict(CAPA),
    {"coxa_c": -55, "joelho_c": 118, "pe_c": 38, "coxa_l": 8, "joelho_l": 40, "pe_l": 30,
     "tronco": 3, "cabeca": 3, "ombro_e": 32.5, "cotovelo_e": -24.5, "ombro_d": -8, "cotovelo_d": -4},
    {"coxa_c": -50, "joelho_c": 110, "pe_c": 35, "coxa_l": 0, "joelho_l": 48, "pe_l": 30,
     "tronco": 6, "cabeca": 5, "ombro_e": 67.5, "cotovelo_e": -34.5, "ombro_d": -15, "cotovelo_d": -7},
    {"coxa_c": -44, "joelho_c": 100, "pe_c": 32, "coxa_l": -8, "joelho_l": 56, "pe_l": 30,
     "tronco": 10, "cabeca": 7, "ombro_e": 92.5, "cotovelo_e": -24.5, "ombro_d": -22, "cotovelo_d": -9},
    {"coxa_c": -38, "joelho_c": 90, "pe_c": 30, "coxa_l": -14, "joelho_l": 62, "pe_l": 28,
     "tronco": 14, "cabeca": 8, "ombro_e": 112.5, "cotovelo_e": 0.5, "ombro_d": -28, "cotovelo_d": -11},
    {"coxa_c": -34, "joelho_c": 84, "pe_c": 28, "coxa_l": -18, "joelho_l": 66, "pe_l": 28,
     "tronco": 16, "cabeca": 8, "ombro_e": 122.5, "cotovelo_e": 10.5, "ombro_d": -32, "cotovelo_d": -13},
]
PENDURADO = {"coxa_c": -22, "joelho_c": 42, "pe_c": 25, "coxa_l": 6, "joelho_l": 28, "pe_l": 22,
             "tronco": 4, "cabeca": 5, "ombro_e": 105.5, "cotovelo_e": -32.5, "ombro_d": -10, "cotovelo_d": -4}


def pose_na_lista(lista, k):
    n = len(lista) - 1
    x = min(max(k, 0.0), 1.0) * n
    i = min(int(math.floor(x)), n - 1)
    return misturar(lista[i], lista[i + 1], suave(x - i))


class Quadro:
    def __init__(self, nome, pose, st, mao=None, tempo=0.0, segura=True):
        self.nome, self.pose, self.st, self.mao, self.tempo = nome, pose, st, mao, tempo
        self.segura = mao is not None and segura    # a bola na mao (nao so perto)
        o = rig.ossos(pose)
        self.bola = None
        if mao is not None:
            self.bola, self.giro = bola_mao(o, mao)
        self.pegada = ponto(o, "cotovelo_e", PEGADA)


def montar():
    """Os quadros e, 60 vezes por segundo, onde fica tudo."""
    quadros = []
    # ---- a corrida (o ciclo)
    corre = []
    for k in range(NC):
        f = k / NC
        pose, B = pose_corre(f)
        na_mao = f >= F_PEGA - 1e-9 or f < F_SOLTA - 1.0 - 1e-9
        q = Quadro("corre%02d" % k, pose, ST_CHAO, "d", segura=na_mao)
        corre.append(len(quadros))
        quadros.append(q)
    DT = P / NC

    def B_corre(n):
        f = (n % NC) / NC
        return np.array([X0 + V * n * DT, corpo_corre(f)[1]])

    # ---- a passada final: o pe de la fica onde pisou no 3o quique
    n_planta = int(round(T_PLANTA / DT))
    q6 = quadros[corre[n_planta % NC]]
    B6 = B_corre(n_planta)
    o6 = rig.ossos(q6.pose)
    ponta_l = mundo(B6, ponto(o6, "pe_l", J["tornozelo_l"] + PONTA))
    chao_ponta = ponta_l[1]

    def no_chao(nome, t, B, base, pe_l):
        pose = dict(base)
        pp = jogador(B, ponta_l)
        perna(pose, "l", tornozelo_no_chao(pp[1], pp[0], pe_l), pe_l)
        q = Quadro(nome, pose, ST_CHAO, None, t)
        q.B = B
        return q

    chao = [
        no_chao("junta1", T_PLANTA + DT, B6 + (18.0, 22.0),
                {"tronco": 18, "pelve": -12, "cabeca": 0, "coxa_c": -45, "joelho_c": 85, "pe_c": 20,
                 "ombro_e": -40, "cotovelo_e": 12, "ombro_d": 12, "cotovelo_d": -35}, 6.0),
        no_chao("junta2", T_PLANTA + 2 * DT, B6 + (32.0, 36.0),
                {"tronco": 13, "pelve": -9, "cabeca": -4, "coxa_c": -62, "joelho_c": 105, "pe_c": 28,
                 "ombro_e": -12, "cotovelo_e": 4, "ombro_d": -6, "cotovelo_d": -24}, 14.0),
        no_chao("sai", T_PLANTA + 3 * DT, B6 + (48.0, -6.0),
                {"tronco": 8, "pelve": -5, "cabeca": -8, "coxa_c": -70, "joelho_c": 115, "pe_c": 32,
                 "ombro_e": 20, "cotovelo_e": -6, "ombro_d": -18, "cotovelo_d": -12}, 40.0),
    ]
    B_sai = chao[-1].B
    i_chao = len(quadros)
    quadros += chao
    # ---- no ar: sobe, pega a bola, camera lenta ate a pose da capa
    pega = {"ombro_e": 75.0, "cotovelo_e": -15.0}
    sai = chao[-1].pose
    sobe_poses = []
    for i, t in enumerate((1.94, 2.07, 2.20)):
        k = (i + 1) / 4.0
        base = misturar(sai, dict(CAPA, tronco=0.0, cabeca=-4.0, pelve=0.0), suave(k))
        base["ombro_e"] = sai["ombro_e"] + (pega["ombro_e"] - sai["ombro_e"]) * suave(k * 1.1)
        base["cotovelo_e"] = sai["cotovelo_e"] + (pega["cotovelo_e"] - sai["cotovelo_e"]) * k
        sobe_poses.append(("sobe%d" % (i + 1), t, base))
    lento = [
        ("pega", T_PEGA, dict(CAPA, cabeca=-4.0, **pega)),
        ("lento1", 2.60, dict(CAPA, cabeca=-2.5, ombro_e=46.0, cotovelo_e=-10.0)),
        ("lento2", 2.86, dict(CAPA, cabeca=-1.0, ombro_e=18.0, cotovelo_e=-3.0)),
        ("capa", 3.06, dict(CAPA)),
    ]
    i_sobe = len(quadros)
    for nome, t, pose in sobe_poses:
        quadros.append(Quadro(nome, pose, ST_AR, None, t))
    i_lento = len(quadros)
    for nome, t, pose in lento:
        quadros.append(Quadro(nome, pose, ST_AR, "e", t))
    # ---- a enterrada (o braco por cima da cabeca, a bola no aro)
    i_golpe = len(quadros)
    ND = 6
    for i in range(ND):
        k = (i + 1) / ND
        t = T_GOLPE + (T_IMPACTO - T_GOLPE) * k ** 0.85
        quadros.append(Quadro("golpe%d" % (i + 1), pose_na_lista(ENTERRADA, k), ST_AR, "e", t))
    # ---- pendurado no aro (a mao fica no aro)
    i_pend = len(quadros)
    for i, (t, k) in enumerate(((3.57, 0.45), (3.72, 1.0))):
        quadros.append(Quadro("pendura%d" % (i + 1), misturar(ENTERRADA[-1], PENDURADO, suave(k)), ST_AR, None, t))

    # ---- onde fica o corpo no ar
    B_imp = BOLA_ARO - ESC * (quadros[i_golpe + ND - 1].bola - CINT)
    B_capa = B_imp + np.array([-62.0, -8.0])
    B_pega = B_capa + np.array([-26.0, 14.0])
    pegada_mundo = mundo(B_imp, quadros[i_golpe + ND - 1].pegada)

    def corpo_ar(t):
        if t < T_PEGA:
            k = (t - T_SAI) / (T_PEGA - T_SAI)
            x = B_sai[0] + (B_pega[0] - B_sai[0]) * k
            y = B_pega[1] + (B_sai[1] - B_pega[1]) * (1.0 - k) ** 2
            return np.array([x, y])
        if t < T_GOLPE:
            return B_pega + (B_capa - B_pega) * suave((t - T_PEGA) / (T_GOLPE - T_PEGA))
        k = min((t - T_GOLPE) / (T_IMPACTO - T_GOLPE), 1.0)
        return B_capa + (B_imp - B_capa) * k ** 1.6

    # ---- a bola solta: os quiques e o voo ate a mao la em cima
    q_pega = quadros[i_lento]
    bola_pega = mundo(corpo_ar(T_PEGA), q_pega.bola)
    voos = []                       # (t0, p0, giro0, tq, t1, p1, giro1, gravidade)
    for n in range(3):
        n_solta = n * NC + 1
        qs = quadros[corre[n_solta % NC]]
        t0 = n_solta * DT
        p0 = mundo(B_corre(n_solta), qs.bola)
        g0 = qs.giro
        tq = (n + F_QUICA) * P
        if n < 2:
            n_pega = n * NC + int(round(F_PEGA * NC))
            qp = quadros[corre[n_pega % NC]]
            t1 = n_pega * DT
            p1 = mundo(B_corre(n_pega), qp.bola)
            g1 = qp.giro
        else:
            t1, p1, g1 = T_PEGA, bola_pega, q_pega.giro
        voos.append((t0, p0, g0, tq, t1, p1, g1))
    quiques = []

    def bola_voo(v, t):
        t0, p0, g0, tq, t1, p1, g1 = v
        x = p0[0] + (p1[0] - p0[0]) * (t - t0) / (t1 - t0)
        if t < tq:
            T = tq - t0
            v0 = (Y_QUICA - p0[1] - 0.5 * G * T * T) / T
            tau = t - t0
            y = p0[1] + v0 * tau + 0.5 * G * tau * tau
        else:
            T = t1 - tq
            if t1 - tq > 0.4:       # o ultimo: sobe forte e chega quase parando
                g = 2.0 * (Y_QUICA - 150.0 * T - p1[1]) / (T * T)
                vu = 150.0 + g * T
                # (sobe na frente dele, nao na frente do rosto, e volta para a mao)
                x += 95.0 * math.sin(math.pi * (t - tq) / T)
            else:
                g = G
                vu = (Y_QUICA - p1[1] + 0.5 * G * T * T) / T
            tau = t - tq
            y = Y_QUICA - vu * tau + 0.5 * g * tau * tau
        # o giro: para a frente, ~1,5 volta por segundo, chegando no da mao
        d = g1 - g0
        voltas = round((2 * math.pi * 1.5 * (t1 - t0) - d) / (2 * math.pi))
        d += 2 * math.pi * voltas
        return np.array([x, y]), g0 + d * (t - t0) / (t1 - t0)

    # ---- depois da enterrada: cai pela rede e quica no chao
    def bola_depois(t):
        tau = t - T_IMPACTO
        p = BOLA_ARO.copy()
        vel = np.array([24.0, 600.0])
        g = 2600.0
        giro = q_g.giro
        y_chao = Y_QUICA
        tt = 0.0
        quica = []
        while True:
            # proxima batida no chao
            a, b, c = 0.5 * g, vel[1], p[1] - y_chao
            tc = (-b + math.sqrt(b * b - 4 * a * c)) / (2 * a)
            if tt + tc > tau or abs(vel[1]) < 120:
                dt = tau - tt
                return p + vel * dt + np.array([0.0, 0.5 * g * dt * dt]), giro + 9.0 * tau, quica
            p = p + vel * tc + np.array([0.0, 0.5 * g * tc * tc])
            vel = np.array([vel[0] * 0.8, -(vel[1] + g * tc) * 0.48])
            tt += tc
            quica.append(T_IMPACTO + tt)

    q_g = quadros[i_golpe + ND - 1]

    # ---- 60 vezes por segundo
    linhas = []
    eventos = []
    n_ticks = int(round(T_FIM * FPS)) + 1
    tempos_chao = [i_chao + j for j in range(3)]
    ar = [i_chao + 2] + list(range(i_sobe, i_pend + 2))
    for i in range(n_ticks):
        t = i / FPS
        giro_corpo = 0.0
        camada = 1
        segura = 0
        amassa = 1.0
        if t < T_PLANTA + DT - 1e-9:
            n = int(math.floor(t / DT + 1e-9))
            qi = corre[n % NC]
            B = B_corre(n)
        elif t < T_SAI:
            qi = max(j for j in tempos_chao if quadros[j].tempo <= t + 1e-9)
            B = quadros[qi].B
        else:
            qi = max(j for j in ar if quadros[j].tempo <= t + 1e-9)
            if t < T_IMPACTO:
                B = corpo_ar(t)
            else:
                # pendurado: a mao no aro, o corpo balanca embaixo dela
                tau = t - T_IMPACTO
                giro_corpo = 0.10 * math.exp(-2.6 * tau) * math.sin(tau * 8.0)
                q = quadros[qi]
                c, s_ = math.cos(giro_corpo), math.sin(giro_corpo)
                v = ESC * (q.pegada - CINT)
                B = pegada_mundo - np.array([c * v[0] - s_ * v[1], s_ * v[0] + c * v[1]])
        q = quadros[qi]
        # a bola
        if t >= T_IMPACTO:
            bp, bg, qq = bola_depois(t)
            camada = 0 if bp[1] < ARO[1] + 200.0 else 1
        elif q.segura and (t >= T_PEGA - 1e-9 or t < T_PLANTA):
            c, s_ = math.cos(giro_corpo), math.sin(giro_corpo)
            bp = mundo(B, q.bola)
            bg = q.giro
            segura = 1
        else:
            v = next(v for v in voos if v[0] - 1e-9 <= t <= v[4] + 1e-9)
            bp, bg = bola_voo(v, t)
        for tq in [v[3] for v in voos]:
            amassa = min(amassa, 1.0 - 0.3 * math.exp(-abs(t - tq) * 45.0))
        z, F = camera(t)
        linhas.append([qi, B[0], B[1], giro_corpo, bp[0], bp[1], bg, amassa, camada, segura, z, F[0], F[1]])
    _, _, quica_depois = bola_depois(T_FIM)
    for n, v in enumerate(voos):
        eventos.append((v[3], "quique", v[1][0] * 0 + bola_voo(v, v[3])[0][0], (0.6, 0.85, 1.25)[n], n))
    for tq in quica_depois:
        eventos.append((tq, "quique", bola_depois(tq)[0][0], 0.7, 1))
    eventos += [(T_SAI - 0.04, "salta"), (T_PEGA, "pega"), (T_GOLPE, "golpe"), (T_IMPACTO, "impacto")]
    return quadros, linhas, sorted(eventos, key=lambda e: e[0])


def camera(t):
    """(zoom, ponto do mundo no meio da tela)."""
    chaves = [(0.0, 1.0, (540.0, 960.0)), (1.55, 1.0, (540.0, 960.0)), (T_PEGA, 1.09, (490.0, 790.0)),
              (T_GOLPE, 1.15, (478.0, 760.0)), (T_IMPACTO, 1.15, (488.0, 768.0)), (T_FIM, 1.14, (490.0, 775.0))]
    for (t0, z0, f0), (t1, z1, f1) in zip(chaves, chaves[1:]):
        if t <= t1:
            k = suave((t - t0) / (t1 - t0))
            return z0 + (z1 - z0) * k, np.array(f0) + (np.array(f1) - np.array(f0)) * k
    return chaves[-1][1], np.array(chaves[-1][2])


# ================================================================ os quadros
FOGO_FRENTE = 104.0                 # os dedos por cima da bola: ate aqui do centro


def renderizar(quadros):
    """Desenha cada quadro inteiro, o brilho dele e os dedos na frente da bola."""
    for q in quadros:
        q.img, q.canto = compor(q.pose, q.st)
        q.brilho, q.brilho_canto, q.brilho_px = brilho(q.img, q.canto, q.st)
        q.frente = None
        if q.segura:
            so = {"antebraco_d"} if q.mao == "d" else {"antebraco_e"}
            img, canto = compor(q.pose, q.st, so=so)
            if img is not None:
                h, w = img.size[1], img.size[0]
                yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
                px = canto[0] + (xx + 0.5) / q.st
                py = canto[1] + (yy + 0.5) / q.st
                d = np.hypot(px - q.bola[0], py - q.bola[1])
                m = np.clip((FOGO_FRENTE - d) / 6.0, 0, 1)
                a = np.asarray(img).astype(np.float64)
                a[..., 3] *= m
                img = Image.fromarray(a.astype(np.uint8), "RGBA")
                cx = img.getchannel("A").point(lambda v: 255 if v > 2 else 0).getbbox()
                if cx is not None:
                    q.frente = img.crop(cx)
                    q.frente_canto = canto + np.array(cx[:2], dtype=np.float64) / q.st
        print("  %-10s %4d x %4d  (st %.2f)%s" % (q.nome, q.img.width, q.img.height, q.st,
              "  + dedos %dx%d" % q.frente.size if q.frente is not None else ""))


# ================================================================ a previa
def _bola_img():
    for nome, img, x0, y0 in PECAS:
        if nome == "bola":
            return img.convert("RGBA"), J["bola"] - (x0, y0)


def previa(pasta, quadros, linhas, passo=2, esc=0.5):
    """O filme como o jogo desenha (a cada `passo` ticks), em esc da tela."""
    os.makedirs(pasta, exist_ok=True)
    bola, bola_c = _bola_img()
    W, H = int(1080 * esc), int(1920 * esc)

    def por(tela, img, M, aditivo=None):
        inv = np.linalg.inv(M)
        im = img.transform((W, H), Image.AFFINE, tuple(inv[:2].ravel()), Image.BILINEAR)
        if aditivo is not None:
            a = np.asarray(im.getchannel("A")).astype(np.float64)[..., None] / 255 * aditivo
            base = np.asarray(tela).astype(np.float64)
            base[..., :3] = np.minimum(base[..., :3] + a * 255, 255)
            tela.paste(Image.fromarray(base.astype(np.uint8), "RGBA"))
        else:
            tela.alpha_composite(im)

    def rotm(a):
        c, s = math.cos(a), math.sin(a)
        return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1.0]])

    def esc_m(k):
        return np.diag([k, k, 1.0])

    for i in range(0, len(linhas), passo):
        t = i / FPS
        qi, bx, by, gc, px, py, gb, am, camada, segura, z, F0, F1 = linhas[i]
        q = quadros[int(qi)]
        F = np.array([F0, F1])
        TELA = esc_m(esc) @ rig.mover((540.0, 960.0)) @ esc_m(z) @ rig.mover(-F)
        tela = Image.new("RGBA", (W, H), (22, 18, 40, 255))
        d = ImageDraw.Draw(tela)

        def pt(w):
            return tuple((TELA @ (w[0], w[1], 1.0))[:2])
        d.line([pt((-400, CHAO)), pt((1500, CHAO))], fill=(255, 120, 20), width=3)
        d.rectangle([pt((330, 300)), pt((750, 590))], outline=(150, 210, 255), width=2)
        caixa = [pt(ARO - (120, 26)), pt(ARO + (120, 26))]
        d.arc(caixa, 180, 360, fill=(255, 120, 20), width=4)
        for k in range(7):
            x = ARO[0] - 110 + k * 36
            d.line([pt((x, ARO[1] + 10)), pt((ARO[0] - 60 + k * 20, ARO[1] + 200))], fill=(220, 220, 240), width=1)
        JOG = TELA @ rig.mover((bx, by)) @ rotm(gc) @ esc_m(ESC) @ rig.mover(-CINT)
        BOLA = TELA @ rig.mover((px, py)) @ esc_m(ESC) @ np.diag([2 - am, am, 1.0]) @ rotm(gb) @ rig.mover(-bola_c)
        if camada == 0:
            por(tela, bola, BOLA)
        d = ImageDraw.Draw(tela)
        d.arc(caixa, 0, 180, fill=(255, 140, 30), width=5)
        br = Image.merge("RGBA", [q.brilho] * 4)
        por(tela, br, JOG @ rig.mover(q.brilho_canto) @ esc_m(q.brilho_px), aditivo=np.array([0.3, 0.55, 1.0]) * 0.55)
        por(tela, q.img, JOG @ rig.mover(q.canto) @ esc_m(1.0 / q.st))
        if camada == 1:
            por(tela, bola, BOLA)
            if segura and q.frente is not None:
                por(tela, q.frente, JOG @ rig.mover(q.frente_canto) @ esc_m(1.0 / q.st))
        tela.convert("RGB").save(os.path.join(pasta, "%04d.png" % (i // passo)))


# ================================================================ para o jogo
def empacotar(imgs, larg=2048, alt_max=2048, folga=2):
    """Prateleiras: [(pagina, x, y)] na ordem das imagens, e as paginas (w, h)."""
    ordem = sorted(range(len(imgs)), key=lambda i: -imgs[i].height)
    lugar = [None] * len(imgs)
    paginas = []
    x = y = alt = 0
    for i in ordem:
        w, h = imgs[i].size
        if not paginas or x + w + folga > larg:
            x, y, alt = 0, y + alt, 0
        if not paginas or y + h + folga > alt_max:
            paginas.append([0, 0])
            x = y = alt = 0
        lugar[i] = (len(paginas) - 1, x + folga, y + folga)
        x += w + folga
        alt = max(alt, h + folga)
        pg = paginas[-1]
        pg[0] = max(pg[0], x + folga)
        pg[1] = max(pg[1], y + alt + folga)
    return lugar, paginas


def _gd(v):
    return "%.3f" % v if abs(v - round(v)) > 1e-6 else "%d" % round(v)


def exportar(quadros, linhas, eventos):
    # os corpos: paginas jogador_quadros_N.png
    corpos = [q.img for q in quadros]
    lugar, paginas = empacotar(corpos)
    telas = [Image.new("RGBA", tuple(p), (0, 0, 0, 0)) for p in paginas]
    for q, (pg, x, y) in zip(quadros, lugar):
        telas[pg].paste(q.img, (x, y))
    nomes = []
    for i, t in enumerate(telas):
        nome = "jogador_quadros_%d.png" % i
        t.save(os.path.join(IMG, nome), optimize=True)
        nomes.append(nome)
    # os brilhos e os dedos: jogador_quadros_extra.png
    extras = []
    for q in quadros:
        b = Image.merge("RGBA", [Image.new("L", q.brilho.size, 255)] * 3 + [q.brilho])
        extras.append(b)
        if q.frente is not None:
            extras.append(q.frente)
    lugar_x, pag_x = empacotar(extras, larg=1024, alt_max=4096)
    assert len(pag_x) == 1
    tx = Image.new("RGBA", tuple(pag_x[0]), (0, 0, 0, 0))
    for im, (_, x, y) in zip(extras, lugar_x):
        tx.paste(im, (x, y))
    tx.save(os.path.join(IMG, "jogador_quadros_extra.png"), optimize=True)
    # a bola (a mesma do comeco ao fim)
    bola_c = _bola_img()[1]
    shutil.copyfile(os.path.join(rig.PECAS, "bola.png"), os.path.join(IMG, "jogador_bola.png"))
    px = sum(p[0] * p[1] for p in paginas) + tx.width * tx.height
    print("  paginas: %s + extra %dx%d  (%.2f Mpx no total)" % (
        ", ".join("%dx%d" % tuple(p) for p in paginas), tx.width, tx.height, px / 1e6))
    # os dados
    with open(os.path.join(RAIZ, "scripts", "fx", "jogador_quadros_dados.gd"), "w") as f:
        f.write("extends Reference\n\n")
        f.write("## GERADO por tools/quadros_jogador.py (nao editar a mao): os quadros do\n")
        f.write("## jogador da apresentacao (cada um o jogador inteiro, renderizado da arte\n")
        f.write("## da capa) e o roteiro inteiro, 60 vezes por segundo.\n\n")
        f.write("const ESC := %.3f            # px do mundo por px do poster\n" % ESC)
        f.write("const FPS := %d\n" % FPS)
        f.write("const RAIO_BOLA := %.2f      # a bola no mundo (sem o fogo)\n" % R_BOLA)
        f.write("const BOLA_CENTRO := Vector2(%.1f, %.1f)   # o centro em jogador_bola.png\n" % tuple(bola_c))
        f.write("const PAGINAS := [%s]\n" % ", ".join('"res://imagens/%s"' % n for n in nomes))
        f.write('const EXTRA := "res://imagens/jogador_quadros_extra.png"\n')
        f.write("# cada quadro (no espaco do jogador: px do poster, a partir da cintura):\n")
        f.write("# [pagina, x, y, largura, altura, canto x, canto y, px do poster por px]\n")
        f.write("const CORPO := [\n")
        for q, (pg, x, y) in zip(quadros, lugar):
            c = q.canto - CINT
            f.write("\t[%d, %d, %d, %d, %d, %.2f, %.2f, %.4f],   # %s\n" % (
                pg, x, y, q.img.width, q.img.height, c[0], c[1], 1.0 / q.st, q.nome))
        f.write("]\n# o brilho em volta (em EXTRA): [x, y, largura, altura, canto x, canto y, px]\n")
        f.write("const BRILHO := [\n")
        k = 0
        dedos = []
        for q in quadros:
            _, x, y = lugar_x[k]
            c = q.brilho_canto - CINT
            f.write("\t[%d, %d, %d, %d, %.2f, %.2f, %.4f],\n" % (x, y, q.brilho.width, q.brilho.height, c[0], c[1], q.brilho_px))
            k += 1
            if q.frente is not None:
                _, x, y = lugar_x[k]
                c = q.frente_canto - CINT
                dedos.append("\t[%d, %d, %d, %d, %.2f, %.2f, %.4f]," % (x, y, q.frente.width, q.frente.height, c[0], c[1], 1.0 / q.st))
                k += 1
            else:
                dedos.append("\t[],")
        f.write("]\n# os dedos por cima da bola (em EXTRA; vazio: nenhum)\nconst DEDOS := [\n")
        f.write("\n".join(dedos) + "\n]\n")
        f.write("# 60 por segundo: quadro, corpo x, y, giro, bola x, y, giro, amassa, camada\n")
        f.write("# (1: na frente do jogador; 0: atras do aro da frente), na mao, zoom,\n")
        f.write("# o ponto do mundo no meio da tela x, y\n")
        f.write("const COLUNAS := %d\n" % len(linhas[0]))
        f.write("const ROTEIRO := [\n")
        for ln in linhas:
            f.write("\t[%s],\n" % ", ".join(_gd(v) if j in (0, 8, 9) else "%.2f" % v if j not in (3, 6, 7, 10) else "%.4f" % v
                                           for j, v in enumerate(ln)))
        f.write("]\n# os acontecimentos: [segundos, nome, ...]\nconst EVENTOS := [\n")
        for e in eventos:
            f.write("\t[%.3f, \"%s\"%s],\n" % (e[0], e[1], "".join(", %s" % _gd(float(v)) for v in e[2:])))
        f.write("]\n")
        for nome in ("T_SAI", "T_PEGA", "T_GOLPE", "T_IMPACTO", "T_FIM"):
            f.write("const %s := %.3f\n" % (nome, globals()[nome]))


def main():
    quadros, linhas, eventos = montar()
    print("%d quadros" % len(quadros))
    renderizar(quadros)
    exportar(quadros, linhas, eventos)
    if len(sys.argv) > 2 and sys.argv[1] == "previa":
        previa(sys.argv[2], quadros, linhas)


if __name__ == "__main__":
    main()
