"""Efeitos sonoros FEITOS A MAO do Slam Arena (sintese por conta), gravados
em sons/*.wav (16 bits, mono, 22050 Hz):

    python3 -I tools/gerar_sons.py

bip / bip_vai   contagem 3-2-1 e o VAI
tique           cada segundo dos ultimos 10
batida          coracao dos ultimos 5 segundos
moeda           ficha inserida
ouro            bola de ouro (aparece e quando acerta)
recorde         fanfarra do recorde batido
quebra          o combo acabou
sobe            subiu o multiplicador (x2, x3, x4)
vento           passagens de tela
trovao          raio do SLAM MODE
impacto         pancada grave (apresentacao, enterrada)
neon            zumbido da lampada neon acendendo (paineis ligando)
swish           bola passando pela rede
passou          bateu o SCORE PASS da fase (subida + arpejo)
fase            fase concluida (fanfarra curta)
fim_jogo        nao passou de fase (tres notas que caem)
vaia            a torcida vaiando (nao passou da fase 1)
vaia_curta      "uuuh" da torcida (muito tempo sem cesta, nao passou da 2)
aplausos        palmas e assobios (campeao, recorde)
combo_alem      ALEM DO LIMITE: a sequencia passou do combo_12 (o ultimo som de
                combo). Feito com o PROPRIO sino do combo_12: sobe numa escala
                pentatonica (de fliperama chines), explode num acorde maior
                com pancada grave, chuva de moedas e brilhinhos (44100 Hz).
Precisa de numpy.
"""
import os
import wave

import numpy as np

TAXA = 22050
AQUI = os.path.dirname(os.path.abspath(__file__))
SAIDA = os.path.join(os.path.dirname(AQUI), "sons")
R = np.random.default_rng(7)


def t_de(dur):
    return np.arange(int(dur * TAXA)) / TAXA


def gravar(nome, x, vol=1.0):
    x = np.asarray(x, dtype=np.float64)
    pico = np.max(np.abs(x)) or 1.0
    x = x / pico * vol
    # entrada e saida sem estalo (2 ms)
    n = min(len(x) // 4, int(0.002 * TAXA))
    if n > 0:
        x[:n] *= np.linspace(0, 1, n)
        x[-n:] *= np.linspace(1, 0, n)
    dados = (np.clip(x, -1, 1) * 32000).astype("<i2").tobytes()
    with wave.open(os.path.join(SAIDA, nome + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TAXA)
        w.writeframes(dados)


def tom(freqs, dur, ataque, queda):
    t = t_de(dur)
    env = np.minimum(1, t / ataque) * np.exp(-t / queda * 1.2)
    v = sum(np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t) for f in freqs)
    return v * env


def arpejo(freqs, passo, cauda=0.35, brilho=0.3):
    t = t_de(passo * len(freqs) + cauda)
    v = np.zeros_like(t)
    for k, f in enumerate(freqs):
        t0 = t - k * passo
        m = t0 >= 0
        tt = t0[m]
        v[m] += (np.sin(2 * np.pi * f * tt) + brilho * np.sin(6 * np.pi * f * tt)) * np.exp(-tt * 7) * np.minimum(1, tt / 0.003)
    return v


def varredura(f0, f1, dur):
    t = t_de(dur)
    u = t / dur
    f = f0 + (f1 - f0) * u
    fase = np.cumsum(2 * np.pi * f / TAXA)
    s = np.sin(fase)
    env = np.minimum(1, u * 40) * (1 - u)
    return (0.7 * s + 0.3 * np.sign(s)) * env


def passa_baixa(x, corte):
    """corte (0..1) pode variar no tempo"""
    y = np.zeros_like(x)
    c = np.broadcast_to(corte, x.shape)
    acc = 0.0
    for i in range(len(x)):
        acc += (x[i] - acc) * c[i]
        y[i] = acc
    return y


def biquad_passa_banda(x, f0, q):
    """filtro passa-banda (2a ordem), para as vogais da torcida"""
    w = 2 * np.pi * f0 / TAXA
    alfa = np.sin(w) / (2 * q)
    b0, b2 = alfa, -alfa
    a0, a1, a2 = 1 + alfa, -2 * np.cos(w), 1 - alfa
    b0, b2, a1, a2 = b0 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(len(x)):
        v = b0 * x[i] + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, x[i]
        y2, y1 = y1, v
        y[i] = v
    return y


def torcida_vogal(dur, vozes, f_min, f_max, queda, formantes, semente):
    """muitas vozes (dente de serra com vibrato, cada uma comecando num
    instante) passando pelas formantes de uma vogal ("uuu")"""
    rng = np.random.default_rng(semente)
    t = t_de(dur)
    soma = np.zeros_like(t)
    for _ in range(vozes):
        f0 = rng.uniform(f_min, f_max)
        ini = rng.uniform(0.0, 0.25)
        fim = dur - rng.uniform(0.05, 0.35)
        f = f0 * (1 - queda * t / dur) * (1 + 0.012 * np.sin(2 * np.pi * rng.uniform(4, 7) * t + rng.uniform(0, 6)))
        fase = np.cumsum(2 * np.pi * f / TAXA) + rng.uniform(0, 6)
        serra = 2 * (fase / (2 * np.pi) % 1.0) - 1
        env = np.clip((t - ini) / 0.12, 0, 1) * np.clip((fim - t) / 0.25, 0, 1)
        soma += serra * env * rng.uniform(0.6, 1.0)
    soma += R.uniform(-1, 1, len(t)) * 0.8 * np.clip(t / 0.2, 0, 1) * np.clip((dur - t) / 0.4, 0, 1)
    voz = np.zeros_like(t)
    for fc, q, g in formantes:
        voz += biquad_passa_banda(soma, fc, q) * g
    return voz


def palmas(dur, por_segundo, semente):
    """aplausos: muitas palmas (estalos curtos de ruido filtrado) em
    instantes soltos, a multidao enchendo e depois baixando"""
    rng = np.random.default_rng(semente)
    n = int(dur * TAXA)
    saida = np.zeros(n + TAXA // 10)
    for k in range(4):
        # 4 timbres de palma (mao mais grave / mais aguda)
        tam = int(0.012 * TAXA)
        tt = np.arange(tam) / TAXA
        ruido = rng.uniform(-1, 1, tam)
        palma = passa_baixa(ruido, 0.35 + 0.12 * k) - passa_baixa(ruido, 0.05) * 0.8
        palma *= np.exp(-tt * (260 + 60 * k))
        trem = np.zeros(n)
        qtd = int(dur * por_segundo / 4)
        for _ in range(qtd):
            q = rng.uniform(0, dur)
            forca = rng.uniform(0.3, 1.0) * min(1.0, q / 0.25) * min(1.0, (dur - q) / 0.9)
            trem[min(n - 1, int(q * TAXA))] += forca
        saida[:n + tam - 1] += np.convolve(trem, palma)
    return saida[:n]


def assobio(dur, f0, f1, semente):
    rng = np.random.default_rng(semente)
    t = t_de(dur)
    f = f0 + (f1 - f0) * np.sin(np.pi * 0.5 * t / dur) + 30 * np.sin(2 * np.pi * 6 * t)
    s = np.sin(np.cumsum(2 * np.pi * f / TAXA)) + 0.05 * rng.uniform(-1, 1, len(t))
    return s * np.clip(t / 0.05, 0, 1) * np.clip((dur - t) / 0.12, 0, 1)


def main():
    os.makedirs(SAIDA, exist_ok=True)
    gravar("bip", tom([880], 0.14, 0.004, 0.10), 0.55)
    gravar("bip_vai", tom([1320, 1760], 0.45, 0.004, 0.36), 0.6)
    gravar("tique", tom([1600], 0.05, 0.001, 0.045), 0.45)
    t = t_de(0.42)
    bat = np.sin(2 * np.pi * 58 * t) * np.exp(-t * 22)
    t2 = np.clip(t - 0.16, 0, None)
    bat += 0.75 * np.sin(2 * np.pi * 52 * t2) * np.exp(-t2 * 22) * (t >= 0.16)
    gravar("batida", bat, 0.9)
    gravar("moeda", arpejo([987.8, 1318.5], 0.07, 0.3), 0.6)
    gravar("ouro", arpejo([1046.5, 1318.5, 1568.0, 2093.0, 2637.0], 0.06, 0.5), 0.6)
    gravar("recorde", arpejo([523.3, 659.3, 784.0, 1046.5, 784.0, 1046.5, 1318.5], 0.09, 0.8, 0.35), 0.75)
    gravar("quebra", varredura(620, 180, 0.32), 0.4)
    gravar("sobe", varredura(300, 1400, 0.35), 0.35)
    # vento: ruido filtrado que abre e fecha
    d = 0.55
    u = t_de(d) / d
    gravar("vento", passa_baixa(R.uniform(-1, 1, len(u)), 0.03 + 0.25 * np.sin(np.pi * u)) * np.sin(np.pi * u), 0.45)
    # trovao: estalo + ronco grave
    t = t_de(0.95)
    ru = R.uniform(-1, 1, len(t))
    estalo = passa_baixa(ru, 0.5) * np.exp(-t * 18)
    ronco = passa_baixa(ru, 0.03) * 3 * np.exp(-t * 3.5) * np.minimum(1, t / 0.02)
    gravar("trovao", estalo * 0.8 + ronco, 0.85)
    # impacto: pancada grave que cai de tom
    t = t_de(0.4)
    f = 120 * np.exp(-t * 6) + 45
    gravar("impacto", np.sin(np.cumsum(2 * np.pi * f / TAXA)) * np.exp(-t * 9), 0.95)
    # neon: zumbido de 100 Hz com estalinhos (lampada ligando)
    t = t_de(0.5)
    zum = np.sign(np.sin(2 * np.pi * 100 * t)) * 0.3 + np.sin(2 * np.pi * 200 * t) * 0.3
    pisca = (np.sin(2 * np.pi * 9 * t) > -0.2).astype(float)
    estalos = (R.uniform(0, 1, len(t)) > 0.995) * R.uniform(-1, 1, len(t))
    gravar("neon", passa_baixa(zum * pisca + estalos * 2, 0.35) * np.minimum(1, t / 0.02) * np.exp(-t * 3), 0.35)
    # swish: ruido agudo rapido (a rede)
    d = 0.32
    t = t_de(d)
    u = t / d
    ru = R.uniform(-1, 1, len(t))
    agudo = ru - passa_baixa(ru, 0.18)
    gravar("swish", agudo * np.sin(np.pi * u) ** 0.6 * np.exp(-u * 2.2), 0.55)
    # passou: subida rapida + arpejo brilhante por cima
    sub = varredura(380, 1500, 0.28)
    arp = arpejo([784.0, 987.8, 1174.7, 1568.0, 1975.5], 0.05, 0.45, 0.4)
    x = np.zeros(max(len(sub), len(arp) + int(0.12 * TAXA)))
    x[:len(sub)] += 0.55 * sub
    x[int(0.12 * TAXA):int(0.12 * TAXA) + len(arp)] += arp
    gravar("passou", x, 0.7)
    # fase: fanfarra (arpejo + acorde que fica)
    arp = arpejo([523.3, 659.3, 784.0, 1046.5], 0.1, 0.2, 0.3)
    t = t_de(0.9)
    acorde = sum(np.sin(2 * np.pi * f * t) + 0.3 * np.sin(4 * np.pi * f * t) for f in [523.3, 659.3, 784.0, 1046.5])
    acorde *= np.minimum(1, t / 0.01) * np.exp(-t * 2.6) * (1 + 0.04 * np.sin(2 * np.pi * 6 * t))
    x = np.zeros(int(0.4 * TAXA) + len(acorde))
    x[:len(arp)] += arp
    x[int(0.4 * TAXA):] += 0.6 * acorde
    gravar("fase", x, 0.75)
    # fim_jogo: tres notas que caem e uma longa com vibrato (timbre quadrado suave)
    partes = []
    for f, d in [(392.0, 0.22), (370.0, 0.22), (349.2, 0.22), (329.6, 0.75)]:
        t = t_de(d)
        vib = 1 + (0.012 * np.sin(2 * np.pi * 5.5 * t) if d > 0.5 else 0)
        fase = np.cumsum(2 * np.pi * f * vib / TAXA)
        onda = np.sin(fase) + 0.35 * np.sign(np.sin(fase))
        env = np.minimum(1, t / 0.01) * np.exp(-t * (2.0 if d > 0.5 else 4.0))
        partes.append(passa_baixa(onda * env, 0.25))
    gravar("fim_jogo", np.concatenate(partes), 0.6)
    # vaia: a torcida inteira "uuuuu", caindo de tom
    u = [(320, 4.0, 1.0), (800, 6.0, 0.45), (2300, 8.0, 0.08)]
    gravar("vaia", torcida_vogal(2.4, 26, 95, 190, 0.12, u, 3), 0.8)
    # vaia curta: "uuuh" desapontado
    gravar("vaia_curta", torcida_vogal(1.2, 16, 120, 210, 0.22, u, 5), 0.6)
    # aplausos: palmas que enchem, dois assobios por cima
    x = palmas(3.0, 520, 9)
    a1 = assobio(0.7, 1800, 2600, 1)
    a2 = assobio(0.55, 2200, 3100, 2)
    i1, i2 = int(0.35 * TAXA), int(1.25 * TAXA)
    x[i1:i1 + len(a1)] += a1 * 0.18
    x[i2:i2 + len(a2)] += a2 * 0.15
    gravar("aplausos", x, 0.75)
    # quique da bola na quadra: o "toc" grave da bola, o som de borracha e
    # o estalo do piso (geradores proprios: os sons de cima nao mudam)
    t = t_de(0.32)
    f = 140 * np.exp(-t * 18) + 62
    toc = np.sin(np.cumsum(2 * np.pi * f / TAXA)) * np.exp(-t * 26)
    borracha = np.sin(2 * np.pi * 330 * t) * np.exp(-t * 55) * 0.35
    estalo = passa_baixa(np.random.default_rng(11).uniform(-1, 1, len(t)), 0.25) * np.exp(-t * 160) * 0.6
    gravar("quique", toc + borracha + estalo, 0.9)
    gerar_combo_alem()
    print("ok: sons feitos a mao em", os.path.relpath(SAIDA, os.path.dirname(AQUI)))


# ------------------------------------------------------- ALEM DO LIMITE
def gerar_combo_alem():
    TX = 44100
    with wave.open(os.path.join(SAIDA, "combo_12.wav")) as w:
        sino = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64) / 32768
        if w.getnchannels() == 2:
            sino = sino.reshape(-1, 2).mean(axis=1)
        tx_sino = w.getframerate()
    sino = sino / (np.max(np.abs(sino)) or 1.0)
    dur = 2.7
    n = int(dur * TX)
    x = np.zeros(n)
    rng = np.random.default_rng(13)

    def nota(semitons, t0, vol, queda=None):
        # o sino do combo_12 transposto (lido mais rapido = mais agudo)
        r = 2 ** (semitons / 12) * tx_sino / TX
        idx = np.arange(0, len(sino) - 1, r)
        v = np.interp(idx, np.arange(len(sino)), sino)
        if queda is not None:
            v = v * np.exp(-np.arange(len(v)) / TX * queda)
        i0 = int(t0 * TX)
        m = min(len(v), n - i0)
        x[i0:i0 + m] += v[:m] * vol

    def senoide(f, t0, d, vol, queda):
        i0 = int(t0 * TX)
        t = np.arange(int(d * TX)) / TX
        v = np.sin(2 * np.pi * f * t) * np.exp(-t * queda) * np.minimum(1, t / 0.002)
        m = min(len(v), n - i0)
        x[i0:i0 + m] += v[:m] * vol

    # 1. a sequencia continua subindo, rapida (pentatonica: "fliperama chines")
    for k, st in enumerate([2, 4, 7, 9, 12, 14]):
        nota(st, 0.06 * k, 0.55 + 0.05 * k, queda=9.0)
    # 2. o "vuuup" que leva ate a explosao
    t = np.arange(int(0.42 * TX)) / TX
    u = t / 0.42
    ruido = rng.uniform(-1, 1, len(t))
    a = 0.02 + 0.5 * u ** 2
    y = np.zeros_like(ruido)
    acc = 0.0
    for i in range(len(ruido)):
        acc += (ruido[i] - acc) * a[i]
        y[i] = ruido[i] - acc
    x[:len(y)] += y * u ** 2 * 0.35
    # 3. A EXPLOSAO (0,42 s): acorde maior com o mesmo sino + grave + prato
    t0 = 0.42
    for st, vol in [(-12, 0.75), (-8, 0.55), (-5, 0.60), (0, 0.65), (4, 0.45), (7, 0.40)]:
        nota(st, t0, vol)
    t = np.arange(int(0.7 * TX)) / TX
    f = 38 + 70 * np.exp(-t * 14)
    grave = np.sin(np.cumsum(2 * np.pi * f / TX)) * np.exp(-t * 5.5)
    i0 = int(t0 * TX)
    x[i0:i0 + len(grave)] += grave * 1.1
    t = np.arange(int(1.1 * TX)) / TX
    prato = rng.uniform(-1, 1, len(t))
    prato = prato - np.concatenate([[0], prato[:-1]])          # so o agudo
    x[i0:i0 + len(prato)] += prato * np.exp(-t * 4.5) * 0.22
    # 4. chuva de moedas (jackpot) e brilhinhos
    for k in range(22):
        tm = t0 + 0.08 + rng.uniform(0, 1.3) * (k / 22) ** 0.7 + rng.uniform(0, 0.05)
        fb = rng.uniform(1750, 2150)
        senoide(fb, tm, 0.12, 0.16, 30)
        senoide(fb * 1.335, tm + 0.035, 0.16, 0.13, 24)
    for k in range(46):
        tm = t0 + rng.uniform(0.0, 1.9) ** 1.4 / 1.9 ** 0.4
        senoide(rng.uniform(3200, 7200), tm, 0.06, 0.07, 55)
    # 5. o floreio final: o sino sobe mais uma oitava, fraquinho
    for k, st in enumerate([12, 14, 16, 19, 21, 24]):
        nota(st, 1.05 + 0.05 * k, 0.22, queda=7.0)
    # mistura: limita macio, sem estalo no fim
    x = np.tanh(x * 1.1)
    fim = int(0.35 * TX)
    x[-fim:] *= np.linspace(1, 0, fim) ** 2
    x = x / (np.max(np.abs(x)) or 1.0) * 0.92
    dados = (np.clip(x, -1, 1) * 32000).astype("<i2").tobytes()
    with wave.open(os.path.join(SAIDA, "combo_alem.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TX)
        w.writeframes(dados)


if __name__ == "__main__":
    main()
