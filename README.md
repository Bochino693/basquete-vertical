# Basquete vertical — SLAM ARENA

Jogo de basquete arcade **vertical** (monitor em pé), de 1 a 4 jogadores por turnos,
para a máquina com sensor de cesta na placa Zero Delay e LEDs no Arduino.

> **Edição OpenGL ES 2.0** (TV Box com placa de vídeo Mali-400/450, como a TX9):
> [`slam-arena-gles2/`](slam-arena-gles2/) — o jogo refeito no **Godot 3.6.3**
> (renderizador GLES2), com apresentação animada, placar de 7 segmentos e efeitos
> desenhados em código, combo que multiplica os pontos, bola de ouro, SLAM MODE,
> recorde da arena, ranking do dia, pódio, modo crédito e o mesmo Arduino de LEDs.
> Para gerar o APK no Windows: dois cliques em `slam-arena-gles2/GERAR_APK.bat`.
> Tudo sobre o jogo, a TV Box e o APK: [`slam-arena-gles2/LEIA-ME.txt`](slam-arena-gles2/LEIA-ME.txt).

A versão original (Godot 4.6, renderizador Compatibility / OpenGL ES 3) continua na
raiz deste repositório (`project.godot`, `scenes/`, `scripts/`, `images/`, `songs/`):
ela não abre em TV Box com Mali-450. A pasta da edição GLES2 é um projeto separado
(o Godot 4 ignora a subpasta com o seu próprio `project.godot`).
