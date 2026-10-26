# SLAM ARENA — basquete arcade vertical (TV Box TX9, Mali-450)

Jogo de basquete arcade **vertical** (monitor em pé) da Lazer & Sport, feito no
**Godot 3.6.3 (OpenGL ES 2.0)** para TV Box com placa de vídeo Mali-400/450 (TX9):
sem botão (a primeira cesta já começa), 1 jogador, **3 fases com META**,
multiplicador x2/x3/x4 e MODO ENTERRADA, bola de ouro, apresentação animada, torcida
(vaias e aplausos), recorde e ranking do dia, modo crédito, sensor e botões na
placa Zero Delay e LEDs no Arduino.

**Versão 2.2-gles2** (aparece no rodapé da tela de configuração). A configuração
opera também pelo **controle remoto da TV Box**: MENU, VOLTAR ou uma seta na
abertura abre; setas escolhem e mudam, OK confirma, VOLTAR salva e sai.

## Gerar o APK (Windows)
1. **Code → Download ZIP** e extraia o ZIP inteiro.
2. Dois cliques em **`GERAR_APK.bat`** (na pasta com o `project.godot`).
3. O APK sai em `APK-Pronto\SlamArena-<versão>.apk` (a pasta abre sozinha no fim) — instale na TV Box pelo pendrive.

Se der erro, envie `build\android\GERACAO-COMPLETA.log`.

## Montagem
Onde ligar cada fio (Zero Delay, TV Box, monitor, moedeiro, Arduino e LEDs):
[`docs/diagrama_montagem.png`](docs/diagrama_montagem.png).

Tudo sobre o jogo, a configuração do operador e a TV Box: [`LEIA-ME.txt`](LEIA-ME.txt).

> O jogo antigo (Godot 4, que não abre na Mali-450) ficou no histórico do
> repositório: commit `1ba5184`.
