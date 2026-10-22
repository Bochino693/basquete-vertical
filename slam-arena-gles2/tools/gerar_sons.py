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
    print("ok: sons feitos a mao em", os.path.relpath(SAIDA, os.path.dirname(AQUI)))


if __name__ == "__main__":
    main()
