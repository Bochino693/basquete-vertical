"""O fundo da partida em FULL HD e LIMPO:

    python3 -I tools/fundo_hd.py

A arte original (941 x 1672) tem um granulado de "papel velho" na quadra
inteira (pontinhos escuros: na TV parece chamuscado/enrugado) e era
esticada para 1080 x 1920 pela placa. Aqui:
  1. o granulado sai: mediana + desfoque leve, SO longe das linhas de neon
     (as linhas e o brilho delas ficam como estao);
  2. a imagem e ampliada uma vez, com Lanczos, para 1080 x 1920 - o jogo
     desenha o fundo pixel por pixel (nitido, sem esticar).
Grava por cima de imagens/fundo_jogo.png. Se ja estiver em 1080 x 1920,
nao faz nada (rodar de novo nao estraga). O tools/preparar_arte.py chama
isto no fim. Precisa de numpy e Pillow.
"""
import os

import numpy as np
from PIL import Image, ImageFilter

AQUI = os.path.dirname(os.path.abspath(__file__))
ARQ = os.path.join(os.path.dirname(AQUI), "imagens", "fundo_jogo.png")
TAMANHO = (1080, 1920)


def main():
    im = Image.open(ARQ).convert("RGB")
    if im.size == TAMANHO:
        print("ok: imagens/fundo_jogo.png ja esta em Full HD e limpo")
        return
    a = np.asarray(im).astype(np.float64) / 255
    liso = im.filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.GaussianBlur(2.2))
    liso = np.asarray(liso).astype(np.float64) / 255
    # mascara das linhas de neon (o vermelho alto), um pouco alargada e macia
    linha = Image.fromarray(((a[..., 0] > 0.42) * 255).astype(np.uint8))
    linha = linha.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(1.5))
    m = np.asarray(linha).astype(np.float64)[..., None] / 255
    b = a * m + liso * (1 - m)
    out = Image.fromarray((np.clip(b, 0, 1) * 255 + 0.5).astype(np.uint8))
    out = out.resize(TAMANHO, Image.LANCZOS)
    out.save(ARQ, optimize=True)
    print("ok: imagens/fundo_jogo.png", out.size, "(sem granulado, Full HD)")


if __name__ == "__main__":
    main()
