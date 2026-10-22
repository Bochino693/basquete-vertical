"""Gera o DIAGRAMA DE MONTAGEM do Slam Arena (docs/diagrama_montagem.png):
a placa Zero Delay (qual borne liga em que), a TV Box, o monitor em pe e o
Arduino dos LEDs. O desenho e um SVG feito aqui; o PNG sai pelo Chromium:

    python3 tools/diagrama/gerar_diagrama.py
    NODE_PATH=<node_modules com playwright> node tools/diagrama/renderizar.js

(o .py escreve docs/diagrama_montagem.html; o .js tira a foto em 2x)
"""
import base64
import io
import os

from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
P = os.path.dirname(os.path.dirname(AQUI))
DOCS = os.path.join(P, "docs")

W, H = 2400, 1780
LAR = "#ff7a0a"      # sensor
VERDE = "#1fae55"    # start
OURO = "#e0a800"     # ficha
AZUL = "#2f7de1"     # select
ROXO = "#8a4de8"     # config
GND = "#4a4f5c"
TXT = "#1d2130"
SUB = "#5b6275"
LINHA = "#d9dde6"


def poster_b64():
    im = Image.open(os.path.join(P, "imagens", "poster.png")).convert("RGB")
    im = im.resize((300, 533), Image.LANCZOS)
    b = io.BytesIO()
    im.save(b, "JPEG", quality=88)
    return base64.b64encode(b.getvalue()).decode()


def t(x, y, s, tam=24, peso=500, cor=TXT, ancora="start", extra=""):
    s = s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    return '<text x="%d" y="%d" font-size="%d" font-weight="%d" fill="%s" text-anchor="%s" %s>%s</text>' % (
        x, y, tam, peso, cor, ancora, extra, s)


def caixa(x, y, w, h, cor_borda="#c9ced9", fundo="#ffffff", r=18, esp=2):
    return '<rect x="%d" y="%d" width="%d" height="%d" rx="%d" fill="%s" stroke="%s" stroke-width="%d"/>' % (
        x, y, w, h, r, fundo, cor_borda, esp)


def fio(pontos, cor, esp=7, tracejado=False):
    d = "M %d %d " % pontos[0] + " ".join("L %d %d" % p for p in pontos[1:])
    extra = ' stroke-dasharray="14 10"' if tracejado else ""
    return ('<path d="%s" fill="none" stroke="#ffffff" stroke-width="%d" stroke-linecap="round" stroke-linejoin="round"/>'
            '<path d="%s" fill="none" stroke="%s" stroke-width="%d" stroke-linecap="round" stroke-linejoin="round"%s/>') % (
        d, esp + 6, d, cor, esp, extra)


def par(xa, ya, xb, yb, cor, meio):
    """o par de fios de um borne: SINAL (colorido) em cima, GND (cinza) embaixo"""
    o = []
    o.append(fio([(xa, ya - 9), (meio, ya - 9), (meio, yb - 9), (xb, yb - 9)], cor))
    o.append(fio([(xa, ya + 9), (meio + 16, ya + 9), (meio + 16, yb + 9), (xb, yb + 9)], GND, 5))
    return "".join(o)


def dispositivo(x, y, w, h, cor, titulo, linhas, icone):
    o = [caixa(x, y, w, h, cor, "#ffffff", 18, 3)]
    o.append('<rect x="%d" y="%d" width="10" height="%d" rx="5" fill="%s"/>' % (x, y + 14, h - 28, cor))
    o.append(icone(x + 62, y + h // 2))
    o.append(t(x + 118, y + 46, titulo, 27, 800, TXT))
    for i, l in enumerate(linhas):
        o.append(t(x + 118, y + 82 + i * 30, l, 20, 500, SUB))
    return "".join(o)


def ic_sensor(cx, cy):
    return ('<ellipse cx="%d" cy="%d" rx="34" ry="10" fill="none" stroke="%s" stroke-width="6"/>'
            '<path d="M %d %d L %d %d L %d %d L %d %d" fill="none" stroke="#9aa1b2" stroke-width="3"/>'
            '<circle cx="%d" cy="%d" r="9" fill="%s"/>') % (cx, cy - 18, LAR, cx - 30, cy - 14, cx - 18, cy + 26, cx + 18, cy + 26, cx + 30, cy - 14, cx + 30, cy + 24, LAR)


def ic_botao(cor):
    def f(cx, cy):
        return ('<circle cx="%d" cy="%d" r="34" fill="%s" opacity="0.18"/>'
                '<circle cx="%d" cy="%d" r="24" fill="%s"/><circle cx="%d" cy="%d" r="24" fill="none" stroke="#ffffff" stroke-width="3" opacity="0.6"/>') % (
            cx, cy, cor, cx, cy, cor, cx, cy)
    return f


def ic_moeda(cx, cy):
    return ('<rect x="%d" y="%d" width="64" height="76" rx="10" fill="#2d3140"/>'
            '<rect x="%d" y="%d" width="30" height="6" rx="3" fill="%s"/>'
            '<circle cx="%d" cy="%d" r="15" fill="%s"/><text x="%d" y="%d" font-size="16" font-weight="800" fill="#2d3140" text-anchor="middle">$</text>') % (
        cx - 32, cy - 38, cx - 15, cy - 24, OURO, cx, cy + 12, OURO, cx, cy + 18)


def borne(x, y, simbolo, nome, cor, usado):
    o = []
    housing = "#ffffff" if usado else "#eef0f4"
    o.append('<rect x="%d" y="%d" width="44" height="58" rx="6" fill="%s" stroke="%s" stroke-width="3"/>' % (
        x, y - 29, housing, cor if usado else "#b9bfcc"))
    for k, py in enumerate((y - 9, y + 9)):
        o.append('<circle cx="%d" cy="%d" r="6" fill="%s"/>' % (x + 22, py, (cor if k == 0 else GND) if usado else "#c3c8d3"))
    o.append(t(x + 62, y + 2, simbolo, 28, 800, cor if usado else "#a7adbb"))
    o.append(t(x + 62 + 52, y + 2, nome, 22 if usado else 19, 700 if usado else 500, TXT if usado else "#a7adbb"))
    return "".join(o)


def main():
    os.makedirs(DOCS, exist_ok=True)
    o = []
    o.append('<rect width="%d" height="%d" fill="#ffffff"/>' % (W, H))
    # ---------------------------------------------------------- cabecalho
    o.append('<rect x="0" y="0" width="%d" height="150" fill="#14111f"/>' % W)
    o.append('<rect x="0" y="146" width="%d" height="4" fill="%s"/>' % (W, LAR))
    o.append(t(60, 78, "SLAM ARENA  •  DIAGRAMA DE MONTAGEM", 54, 900, "#ffffff"))
    o.append(t(60, 122, "Placa Zero Delay, TV Box TX9 (Mali-450), monitor em pé e LEDs no Arduino (opcional)", 26, 500, "#c9c4da"))
    o.append(t(W - 60, 78, "cada borne = 2 fios", 26, 700, "#ffffff", "end"))
    o.append('<line x1="%d" y1="112" x2="%d" y2="112" stroke="%s" stroke-width="7" stroke-linecap="round"/>' % (W - 420, W - 330, LAR))
    o.append(t(W - 318, 120, "SINAL", 22, 700, "#ffffff"))
    o.append('<line x1="%d" y1="112" x2="%d" y2="112" stroke="#8f95a6" stroke-width="5" stroke-linecap="round"/>' % (W - 220, W - 140))
    o.append(t(W - 128, 120, "GND", 22, 700, "#ffffff"))
    # ------------------------------------------------ coluna 1: a maquina
    o.append(t(60, 205, "NA MÁQUINA", 24, 800, SUB, extra='letter-spacing="3"'))
    dx, dw, dh = 60, 560, 150
    devs = [
        (320, LAR, "SENSOR DA CESTA", ["contato seco: fecha no GND quando", "a bola passa (cada sinal = 1 cesta)"], ic_sensor),
        (500, VERDE, "BOTÃO START", ["o mesmo do jogo antigo", "(jogar não precisa: a cesta começa)"], ic_botao(VERDE)),
        (680, OURO, "MOEDEIRO  (CH-926)", ["só no modo CRÉDITO  •  1 pulso = 1 ficha", "fonte 12 V própria, GND junto"], ic_moeda),
        (860, AZUL, "BOTÃO SELECT  (operador)", ["segurar 4 s na abertura =", "configuração (opcional)"], ic_botao(AZUL)),
        (1040, ROXO, "BOTÃO CONFIGURAÇÃO", ["opcional (R2): abre a", "configuração direto"], ic_botao(ROXO)),
    ]
    for y, cor, tit, linhas, ic in devs:
        o.append(dispositivo(dx, y, dw, dh, cor, tit, linhas, ic))
    # ---------------------------------------------- coluna 2: Zero Delay
    bx, by, bw, bh = 820, 190, 600, 1120
    o.append('<rect x="%d" y="%d" width="%d" height="%d" rx="26" fill="#0f5132" stroke="#0a3a24" stroke-width="4"/>' % (bx, by, bw, bh))
    o.append('<circle cx="%d" cy="%d" r="9" fill="#d4af37"/><circle cx="%d" cy="%d" r="9" fill="#d4af37"/>' % (bx + 30, by + 30, bx + bw - 30, by + 30))
    o.append('<circle cx="%d" cy="%d" r="9" fill="#d4af37"/><circle cx="%d" cy="%d" r="9" fill="#d4af37"/>' % (bx + 30, by + bh - 30, bx + bw - 30, by + bh - 30))
    o.append(t(bx + bw // 2, by + 66, "PLACA ZERO DELAY", 34, 900, "#ffffff", "middle"))
    o.append(t(bx + bw // 2, by + 100, "encoder USB  •  os bornes, pelo nome", 20, 500, "#b8e0c8", "middle"))
    usados = [(395, "□", "QUADRADO  →  SENSOR", LAR), (575, "", "START  →  START", VERDE),
              (755, "△", "TRIÂNGULO  →  FICHA", OURO), (935, "", "SELECT  →  SELECT", AZUL), (1115, "", "R2  →  CONFIGURAÇÃO", ROXO)]
    tx = bx + 40
    for y, simb, nome, cor in usados:
        o.append('<rect x="%d" y="%d" width="%d" height="78" rx="14" fill="#ffffff" opacity="0.96"/>' % (bx + 22, y - 39, bw - 44))
        o.append(borne(tx, y, simb if simb else "▶", nome, cor, True))
    # bornes livres (embaixo, pequenos)
    o.append(t(bx + bw // 2, by + bh - 112, "livres: ○ BOLINHA • X • L1 • R1 • L2 • HOME • joystick", 19, 600, "#b8e0c8", "middle"))
    o.append(t(bx + bw // 2, by + bh - 80, "(a ordem dos bornes na sua placa pode ser outra:", 18, 500, "#b8e0c8", "middle"))
    o.append(t(bx + bw // 2, by + bh - 54, "siga o NOME impresso ao lado de cada um)", 18, 500, "#b8e0c8", "middle"))
    # fios dispositivos -> bornes
    for (y, cor, _, _, _), (yb, _, _, _) in zip(devs, usados):
        o.append(par(dx + dw, y + dh // 2, tx, yb, cor, 700))
    # ------------------------------------------- coluna 3: TV Box e monitor
    # monitor em pe
    mx, my, mw, mh = 1960, 190, 340, 600
    o.append('<rect x="%d" y="%d" width="%d" height="%d" rx="22" fill="#1b1d26" stroke="#0e0f14" stroke-width="4"/>' % (mx, my, mw, mh))
    o.append('<image x="%d" y="%d" width="%d" height="%d" href="data:image/jpeg;base64,%s" preserveAspectRatio="xMidYMid slice"/>' % (
        mx + 20, my + 20, mw - 40, mh - 40, poster_b64()))
    o.append('<rect x="%d" y="%d" width="80" height="22" rx="6" fill="#1b1d26"/>' % (mx + mw // 2 - 40, my + mh))
    o.append(t(mx + mw // 2, my + mh + 62, "MONITOR EM PÉ", 26, 800, TXT, "middle"))
    o.append(t(mx + mw // 2, my + mh + 92, "o jogo fica em pé sozinho", 19, 500, SUB, "middle"))
    o.append(t(mx + mw // 2, my + mh + 118, "(GIRO AUTOMÁTICO, tela cheia)", 19, 500, SUB, "middle"))
    # TV Box
    tbx, tby, tbw, tbh = 1560, 520, 300, 170
    o.append('<rect x="%d" y="%d" width="%d" height="%d" rx="20" fill="#20232d"/>' % (tbx, tby, tbw, tbh))
    o.append('<circle cx="%d" cy="%d" r="6" fill="#3ee07a"/>' % (tbx + 30, tby + 30))
    o.append(t(tbx + tbw // 2, tby + 62, "TV BOX TX9", 30, 900, "#ffffff", "middle"))
    o.append(t(tbx + tbw // 2, tby + 92, "Android  •  Mali-450", 18, 500, "#aab0c0", "middle"))
    for i, (rot, cor) in enumerate([("USB 1", "#ffffff"), ("USB 2", "#ffffff"), ("HDMI", "#ffffff")]):
        px = tbx + 26 + i * 92
        o.append('<rect x="%d" y="%d" width="72" height="34" rx="6" fill="#3a3f4f"/>' % (px, tby + tbh - 54))
        o.append(t(px + 36, tby + tbh - 31, rot, 16, 800, cor, "middle"))
    # USB Zero Delay -> USB 1
    o.append(fio([(bx + bw, 820), (tbx + 62, 820), (tbx + 62, tby + tbh - 20)], "#2b2f3a", 9))
    o.append(t(bx + bw + 16, 805, "cabo USB", 19, 700, SUB))
    # HDMI -> monitor
    o.append(fio([(tbx + 246, tby + tbh - 20), (tbx + 246, 750), (1925, 750), (1925, 490), (mx, 490)], "#2b2f3a", 9))
    o.append(t(1915, 470, "HDMI", 19, 700, SUB, "end"))
    o.append(t(tbx + tbw // 2, tby - 22, "fonte 5 V da própria TV Box", 18, 500, SUB, "middle"))
    # ------------------------------------------------ Arduino e LEDs
    ax, ay, aw, ah = 1560, 960, 330, 230
    o.append('<rect x="%d" y="%d" width="%d" height="%d" rx="18" fill="#00708a" stroke="#005266" stroke-width="4"/>' % (ax, ay, aw, ah))
    o.append(t(ax + aw // 2, ay + 46, "ARDUINO", 30, 900, "#ffffff", "middle"))
    o.append(t(ax + aw // 2, ay + 74, "LEDs  •  opcional", 18, 600, "#bfe9f2", "middle"))
    pinos = [("D2", "FITA 1 (DIN)"), ("D3", "FITA 2 (DIN)"), ("D4", "sensor (opcional)"), ("GND", "GND comum")]
    for i, (p, d) in enumerate(pinos):
        yy = ay + 108 + i * 30
        o.append('<rect x="%d" y="%d" width="56" height="22" rx="5" fill="#ffffff"/>' % (ax + aw - 74, yy - 16))
        o.append(t(ax + aw - 46, yy, p, 16, 800, "#00708a", "middle"))
        o.append(t(ax + aw - 86, yy, d, 17, 600, "#ffffff", "end"))
    # USB Arduino -> USB 2
    o.append(fio([(tbx + 154, ay), (tbx + 154, tby + tbh - 20)], "#2b2f3a", 9))
    o.append(t(tbx + 170, 900, "cabo USB", 19, 700, SUB))
    # fitas de LED
    lx = 1990
    for k, yy in enumerate((1020, 1110)):
        o.append('<rect x="%d" y="%d" width="330" height="40" rx="10" fill="#f4f5f8" stroke="#c9ced9" stroke-width="2"/>' % (lx, yy - 20))
        for j in range(8):
            o.append('<circle cx="%d" cy="%d" r="11" fill="%s"/>' % (lx + 26 + j * 40, yy, "#ff8a1f" if (j + k) % 2 == 0 else "#ffc06b"))
        o.append(fio([(ax + aw, ay + 108 + k * 30 - 6), (lx - 30, ay + 108 + k * 30 - 6), (lx - 30, yy), (lx, yy)], "#00a6c7", 5))
    o.append(t(lx + 165, 980, "2 fitas WS2812 (NeoPixel), 8 LEDs cada", 18, 600, SUB, "middle"))
    # fonte 5 V dos LEDs: +5 V nas fitas, GND junto com o do Arduino
    fx, fy = lx + 50, 1200
    o.append(fio([(fx + 200, fy), (fx + 200, 1170), (2345, 1170), (2345, 1020), (lx + 330, 1020)], "#e5383b", 5))
    o.append(fio([(2345, 1110), (lx + 330, 1110)], "#e5383b", 5))
    o.append(fio([(fx, fy + 37), (1940, fy + 37), (1940, ay + 108 + 3 * 30 - 6), (ax + aw, ay + 108 + 3 * 30 - 6)], GND, 5))
    o.append('<rect x="%d" y="%d" width="230" height="74" rx="12" fill="#2d3140"/>' % (fx, fy))
    o.append(t(fx + 115, fy + 32, "FONTE 5 V (LEDs)", 20, 800, "#ffffff", "middle"))
    o.append(t(fx + 115, fy + 58, "+5 V nas fitas • GND comum", 16, 500, "#c9cede", "middle"))
    # ------------------------------------------------------------ notas
    ny = 1400
    o.append('<rect x="40" y="%d" width="%d" height="%d" rx="22" fill="#f6f7fa" stroke="%s" stroke-width="2"/>' % (ny - 40, W - 80, H - ny - 10, LINHA))
    o.append(t(70, ny + 2, "IMPORTANTE", 24, 900, LAR, extra='letter-spacing="3"'))
    notas = [
        ("1", "Cada borne da Zero Delay tem 2 fios: o SINAL e o GND. O comando vale quando o sinal fecha no GND."),
        ("2", "Nunca ligue tensão nos bornes. Sensor de 12/24 V (indutivo, fotoelétrico): só por relé ou optoacoplador."),
        ("3", "Moedeiro: COIN no TRIÂNGULO e o GND da fonte dele junto com o GND da placa. Pulso LENTO ou MÉDIO."),
        ("4", "Ficha nunca no SELECT (cada aperto seria uma ficha de graça). Para jogar não precisa de botão nenhum."),
        ("5", "Se algum comando cair no lugar errado: CONFIGURAÇÃO > BOTÕES DA PLACA (aperta um de cada vez e grava)."),
        ("6", "Swish Arena (horizontal): as mesmas ligações de START e SENSOR (QUADRADO); lá não há moedeiro."),
    ]
    for i, (n, s) in enumerate(notas):
        col = i % 2
        lin = i // 2
        xx = 70 + col * 1150
        yy = ny + 52 + lin * 92
        o.append('<circle cx="%d" cy="%d" r="20" fill="%s"/>' % (xx + 20, yy - 8, LAR))
        o.append(t(xx + 20, yy, n, 22, 900, "#ffffff", "middle"))
        palavras = s.split(" ")
        linha1, linha2 = "", ""
        for p in palavras:
            if len(linha1) + len(p) < 62 and not linha2:
                linha1 += (" " if linha1 else "") + p
            else:
                linha2 += (" " if linha2 else "") + p
        o.append(t(xx + 56, yy - 4, linha1, 22, 600, TXT))
        if linha2:
            o.append(t(xx + 56, yy + 26, linha2, 22, 600, TXT))
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" '
           'font-family="Inter, Liberation Sans, sans-serif">%s</svg>') % (W, H, W, H, "".join(o))
    html = ('<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:#fff}'
            'svg{display:block}</style></head><body>%s</body></html>') % svg
    with open(os.path.join(DOCS, "diagrama_montagem.html"), "w", encoding="utf-8") as f:
        f.write(html)
    print("ok: docs/diagrama_montagem.html (%d x %d)" % (W, H))


if __name__ == "__main__":
    main()
