"""Prepara a arte e os sons do Slam Arena (edicao GLES2) a partir dos
arquivos originais do jogo antigo (Godot 4: as pastas images/ e songs/,
que estao no historico do repositorio, commit 1ba5184 - o jogo pronto ja
tem tudo o que este script faz, em imagens/, sons/ e musicas/). Rode de
novo so se a arte original mudar:

    git worktree add ../jogo-antigo 1ba5184
    python3 -I tools/preparar_arte.py ../jogo-antigo

O que faz:
  * imagens/fundo_jogo.png - o fundo da partida SEM os tracinhos e o arco
    do cronometro desenhados na arte (o cronometro de verdade e desenhado
    pelo jogo, aceso conforme o tempo, exatamente no mesmo lugar), depois
    limpo do granulado e ampliado para 1080 x 1920 (tools/fundo_hd.py);
  * imagens/poster.png - a arte da abertura, em Full HD, e o mapa do
    poster vivo (tools/poster_vivo.py; a arte original fica em
    tools/arte/poster_original.png);
  * icones do Android (192 e adaptativo 432), banner da TV (320x180) e as
    imagens de abertura da TV Box (uma para cada giro da tela);
  * sons/*.wav - os efeitos curtos em WAV (o Godot toca na hora, sem
    decodificar MP3 no meio da partida);
  * musicas/*.mp3 - as musicas (tocadas em fluxo).
Precisa de: Pillow, numpy e ffmpeg.
"""
import math
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

AQUI = os.path.dirname(os.path.abspath(__file__))
P = os.path.dirname(AQUI)                      # o projeto
ORIGINAIS = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(P), "jogo-antigo")
ORIG_IMG = os.path.join(ORIGINAIS, "images")
ORIG_SOM = os.path.join(ORIGINAIS, "songs")

# Cronometro da arte (fundo_play.png, 941 x 1672): centro e faixa dos
# tracinhos/arco (medidos pixel a pixel; tools/README no LEIA-ME)
CENTRO = (470.0, 260.5)
FAIXA = (112.0, 193.0)        # raio de dentro e de fora do que sai (tracinhos, arco e o brilho deles)
ORIGEM = (60.0, 100.0)        # de onde vem o "chao" escuro que cobre
CIRCULO = 196.0               # o circulo fino da arte (fica): o brilho dele volta por dentro
COR_BRILHO = np.array([1.0, 0.34, 0.08], dtype=np.float32)


def limpar_cronometro():
    im = Image.open(os.path.join(ORIG_IMG, "fundo_play.png")).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    h, w, _ = a.shape
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    dx = xs - CENTRO[0]
    dy = ys - CENTRO[1]
    r = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dy, dx)
    r0, r1 = FAIXA
    # raio de origem: o miolo escuro do circulo, na mesma direcao
    t = np.clip((r - r0) / (r1 - r0), 0.0, 1.0)
    rs = ORIGEM[0] + t * (ORIGEM[1] - ORIGEM[0])
    sx = np.clip(CENTRO[0] + np.cos(ang) * rs, 0, w - 1)
    sy = np.clip(CENTRO[1] + np.sin(ang) * rs, 0, h - 1)
    # bilinear
    x0 = np.floor(sx).astype(int)
    y0 = np.floor(sy).astype(int)
    x1 = np.clip(x0 + 1, 0, w - 1)
    y1 = np.clip(y0 + 1, 0, h - 1)
    fx = (sx - x0)[..., None]
    fy = (sy - y0)[..., None]
    amostra = (a[y0, x0] * (1 - fx) * (1 - fy) + a[y0, x1] * fx * (1 - fy)
               + a[y1, x0] * (1 - fx) * fy + a[y1, x1] * fx * fy)
    # o brilho do circulo fino (que fica) por dentro, como na arte: cai
    # depressa para o miolo
    brilho = 58.0 * np.exp(-np.clip(CIRCULO - r, 0.0, None) / 4.5)
    amostra = amostra + brilho[..., None] * COR_BRILHO
    # peso: 1 dentro da faixa; entra devagar por dentro (12 px) e sai
    # rapido por fora (3 px, antes do circulo fino)
    def suave(v):
        v = np.clip(v, 0.0, 1.0)
        return v * v * (3 - 2 * v)
    peso = suave((r - r0) / 12.0) * suave(((r1 + 2.0) - r) / 3.0)
    peso = peso[..., None]
    b = a * (1 - peso) + amostra * peso
    out = Image.fromarray(np.clip(b + 0.5, 0, 255).astype(np.uint8))
    out.save(os.path.join(P, "imagens", "fundo_jogo.png"), optimize=True)
    print("ok: imagens/fundo_jogo.png", out.size)


def poster():
    shutil.copy(os.path.join(ORIG_IMG, "basket_back.png"), os.path.join(P, "tools", "arte", "poster_original.png"))
    # em Full HD e o mapa do poster vivo (tools/poster_vivo.py)
    import poster_vivo
    poster_vivo.main()


def logo_quadrado(lado):
    """O emblema SLAM ARENA da arte (bola + letreiro), quadrado."""
    im = Image.open(os.path.join(ORIG_IMG, "basket_back.png")).convert("RGB")
    # emblema: de x 40 a 900, y 780 a 1500 (941 x 1672)
    caixa = (30, 770, 911, 1651)
    return im.crop(caixa).resize((lado, lado), Image.LANCZOS)


def icones():
    ui = os.path.join(P, "imagens")
    logo = logo_quadrado(432)
    # icone comum (192): o emblema com cantos arredondados
    ic = logo.resize((192, 192), Image.LANCZOS).convert("RGBA")
    mascara = Image.new("L", (192, 192), 0)
    ImageDraw.Draw(mascara).rounded_rectangle((0, 0, 191, 191), 38, fill=255)
    ic.putalpha(mascara)
    ic.save(os.path.join(ui, "icone.png"))
    # adaptativo: fundo escuro + emblema menor (a mascara do Android corta
    # ate 1/6 de cada lado)
    fundo = Image.new("RGB", (432, 432), (10, 6, 18))
    gd = ImageDraw.Draw(fundo)
    for i in range(216, 0, -4):
        c = int(40 * (1 - i / 216.0))
        gd.ellipse((216 - i, 216 - i, 216 + i, 216 + i), fill=(10 + c * 2, 6 + c // 2, 18 + c // 3))
    fundo.save(os.path.join(ui, "icone_fundo.png"))
    frente = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    menor = logo.resize((288, 288), Image.LANCZOS).convert("RGBA")
    m = Image.new("L", (288, 288), 0)
    ImageDraw.Draw(m).ellipse((0, 0, 287, 287), fill=255)
    menor.putalpha(m.filter(ImageFilter.GaussianBlur(2)))
    frente.paste(menor, (72, 72), menor)
    frente.save(os.path.join(ui, "icone_frente.png"))
    # banner da TV (320 x 180): fundo escuro, emblema e o nome
    ban = Image.new("RGB", (320, 180), (8, 5, 16))
    em = logo.resize((170, 170), Image.LANCZOS)
    ban.paste(em, (75, 5))
    ban.save(os.path.join(P, "tools", "android", "banner_tv.png"))
    print("ok: icones e banner")


def aberturas():
    """A imagem de abertura (imagens/splash.png) agora e o EMBLEMA do proprio
    jogo, gravado pelo Godot (a capa e a apresentacao comecam nele: nenhuma
    tela preta ao abrir):
        godot --path . res://tools/testes/gravar_splash.tscn"""
    print("ok: aberturas (imagens/splash.png: rode tools/testes/gravar_splash.tscn)")


SONS = {
    "switch.mp3": "cesta.wav",
    "selected.mp3": "selecao.wav",
    "pointer.mp3": "cursor.wav",
    "apito_inicio.mp3": "apito.wav",
    "end_bask.mp3": "fim_turno.wav",
}
MUSICAS = {
    "intro_bask.mp3": "abertura.mp3",
    "bask_play.mp3": "jogo.mp3",
    "good_player.mp3": "podio.mp3",
}


def sons():
    pares = dict(SONS)
    for i in range(1, 13):
        pares["combo_%d.mp3" % i] = "combo_%d.wav" % i
    for origem, destino in pares.items():
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", os.path.join(ORIG_SOM, origem),
                        "-ac", "1", "-ar", "44100", "-sample_fmt", "s16",
                        os.path.join(P, "sons", destino)], check=True)
    for origem, destino in MUSICAS.items():
        shutil.copy(os.path.join(ORIG_SOM, origem), os.path.join(P, "musicas", destino))
    print("ok: %d sons, %d musicas" % (len(pares), len(MUSICAS)))


def main():
    for d in ("imagens", "sons", "musicas", os.path.join("tools", "android")):
        os.makedirs(os.path.join(P, d), exist_ok=True)
    limpar_cronometro()
    # o fundo sem o granulado da arte e ja em 1080 x 1920 (tools/fundo_hd.py)
    import fundo_hd
    fundo_hd.main()
    poster()
    icones()
    aberturas()
    sons()


if __name__ == "__main__":
    main()
