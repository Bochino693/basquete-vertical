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
fx_ladrilho ladrilho de LED do piso (quadrado de cantos redondos: borda
            acesa, miolo suave e um ponto de luz no centro)
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
    print("ok: texturas feitas a mao em imagens/fx_*.png")


if __name__ == "__main__":
    main()
