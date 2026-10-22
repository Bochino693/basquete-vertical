# Basquete vertical — SLAM ARENA

Jogo de basquete arcade **vertical** (monitor em pé) para a máquina com sensor de
cesta na placa Zero Delay e LEDs no Arduino.

> **Edição OpenGL ES 2.0** (TV Box com placa de vídeo Mali-400/450, como a TX9):
> [`slam-arena-gles2/`](slam-arena-gles2/) — o jogo refeito no **Godot 3.6.3**
> (renderizador GLES2): **sem botão** (a primeira cesta já começa), 1 jogador,
> **3 fases com SCORE PASS** (FASE 1, FASE 2 e a FINAL com multiplicador turbinado),
> apresentação animada, placar de 7 segmentos e efeitos desenhados em código, combo
> que multiplica os pontos, bola de ouro, SLAM MODE, bônus de sequência, recorde da
> arena, ranking do dia, tela de resultado, modo crédito e o mesmo Arduino de LEDs.
> Para gerar o APK no Windows: dois cliques em `slam-arena-gles2/GERAR_APK.bat`.
> Onde ligar cada fio (Zero Delay, TV Box, monitor, moedeiro, LEDs):
> [`slam-arena-gles2/docs/diagrama_montagem.png`](slam-arena-gles2/docs/diagrama_montagem.png).
> Tudo sobre o jogo, a TV Box e o APK: [`slam-arena-gles2/LEIA-ME.txt`](slam-arena-gles2/LEIA-ME.txt).

A versão original (Godot 4.6, renderizador Compatibility / OpenGL ES 3) continua na
raiz deste repositório (`project.godot`, `scenes/`, `scripts/`, `images/`, `songs/`):
ela não abre em TV Box com Mali-450. A pasta da edição GLES2 é um projeto separado
(o Godot 4 ignora a subpasta com o seu próprio `project.godot`).
