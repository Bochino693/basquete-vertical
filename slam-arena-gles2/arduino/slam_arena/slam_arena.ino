// SLAM ARENA - Arduino dos LEDs da maquina de basquete (OPCIONAL)
// ===============================================================
// O jogo manda UMA LINHA POR COMANDO, 9600 baud - os MESMOS comandos do
// jogo antigo (o Arduino que ja esta na maquina continua funcionando, nao
// precisa regravar). Este firmware e para quem quiser regravar ou montar
// uma maquina nova:
//   ATTRACT    abertura: efeitos laranja que se alternam
//   MENU_LOCK  janela de jogadores aberta: aceso parado
//   SELECT1    1 jogador: aceso      SELECT2..4: 1 a 3 ondas
//   STARTING   entrando no jogo: enche das pontas para o meio
//   PLAY       turno valendo: respiracao suave
//   HIT        cesta: flash branco -> laranja
//   RECORD     recorde batido: festa dourada (3 s)
//   BOOST      cesta depois do recorde: flash dourado
//   OFF        apaga
//   PING       responde PONG:SLAM_ARENA:1 (o jogo mostra "conectado")
// Sensor da cesta OPCIONAL no pino 4 (contato a GND, INPUT_PULLUP): cada
// bola manda "CESTA" (com trava de 300 ms e precisa soltar) - vale junto
// com o sensor ligado na Zero Delay.
//
// Ligacao: fita 1 (NeoPixel/WS2812) no D2, fita 2 no D3, LEDS_POR_FITA cada.
// Biblioteca: Adafruit NeoPixel (Gerenciador de Bibliotecas da IDE).

#include <Adafruit_NeoPixel.h>

const uint8_t PINO_FITA1 = 2;
const uint8_t PINO_FITA2 = 3;
const uint8_t PINO_SENSOR = 4;
const uint8_t LEDS_POR_FITA = 8;
const uint8_t BRILHO = 180;            // 0..255 (fonte de 5 V aguenta?)
const unsigned long TRAVA_SENSOR = 300;

Adafruit_NeoPixel fita1(LEDS_POR_FITA, PINO_FITA1, NEO_GRB + NEO_KHZ800);
Adafruit_NeoPixel fita2(LEDS_POR_FITA, PINO_FITA2, NEO_GRB + NEO_KHZ800);

enum Modo { M_OFF, M_ATTRACT, M_MENU, M_SELECT, M_STARTING, M_PLAY, M_HIT, M_RECORD, M_BOOST };
Modo modo = M_ATTRACT;
Modo modo_volta = M_PLAY;              // para onde volta depois de HIT/BOOST/RECORD
uint8_t ondas = 0;                     // SELECTn
unsigned long modo_desde = 0;
char linha[24];
uint8_t tam = 0;
bool sensor_solto = true;
unsigned long ultima_cesta = 0;

uint32_t cor(uint8_t r, uint8_t g, uint8_t b, float f) {
  if (f < 0) f = 0;
  if (f > 1) f = 1;
  return fita1.Color((uint8_t)(r * f), (uint8_t)(g * f), (uint8_t)(b * f));
}

// pixel i de 0 a 2*LEDS-1 (as duas fitas seguidas)
void pixel(uint8_t i, uint32_t c) {
  if (i < LEDS_POR_FITA) fita1.setPixelColor(i, c);
  else fita2.setPixelColor(i - LEDS_POR_FITA, c);
}

void tudo(uint32_t c) {
  for (uint8_t i = 0; i < 2 * LEDS_POR_FITA; i++) pixel(i, c);
}

void mostrar() {
  fita1.show();
  fita2.show();
}

void mudar(Modo m) {
  if (m == M_HIT || m == M_BOOST || m == M_RECORD) {
    if (modo != M_HIT && modo != M_BOOST && modo != M_RECORD) modo_volta = modo;
  }
  modo = m;
  modo_desde = millis();
}

void comando(const char *c) {
  if (!strcmp(c, "PING")) { Serial.println("PONG:SLAM_ARENA:1"); return; }
  if (!strcmp(c, "ATTRACT")) mudar(M_ATTRACT);
  else if (!strcmp(c, "MENU_LOCK")) mudar(M_MENU);
  else if (!strncmp(c, "SELECT", 6)) { ondas = c[6] - '1'; mudar(M_SELECT); }
  else if (!strcmp(c, "STARTING")) mudar(M_STARTING);
  else if (!strcmp(c, "PLAY")) { modo_volta = M_PLAY; mudar(M_PLAY); }
  else if (!strcmp(c, "HIT")) mudar(M_HIT);
  else if (!strcmp(c, "BOOST")) mudar(M_BOOST);
  else if (!strcmp(c, "RECORD")) mudar(M_RECORD);
  else if (!strcmp(c, "OFF")) mudar(M_OFF);
}

void ler_serial() {
  while (Serial.available()) {
    char ch = Serial.read();
    if (ch == '\n' || ch == '\r') {
      if (tam > 0) {
        linha[tam] = 0;
        // o jogo antigo (PowerShell) mandava "COMANDO:numero": fica so o comando
        char *dois = strchr(linha, ':');
        if (dois && strncmp(linha, "PONG", 4)) *dois = 0;
        comando(linha);
      }
      tam = 0;
    } else if (tam < sizeof(linha) - 1) {
      linha[tam++] = ch;
    }
  }
}

void ler_sensor() {
  bool fechado = digitalRead(PINO_SENSOR) == LOW;
  unsigned long agora = millis();
  if (fechado && sensor_solto && agora - ultima_cesta > TRAVA_SENSOR) {
    Serial.println("CESTA");
    ultima_cesta = agora;
    sensor_solto = false;
  } else if (!fechado) {
    sensor_solto = true;
  }
}

void efeitos() {
  unsigned long t = millis() - modo_desde;
  float s = t / 1000.0;
  const uint8_t n = 2 * LEDS_POR_FITA;
  switch (modo) {
    case M_OFF:
      tudo(0);
      break;
    case M_ATTRACT: {
      // 4 efeitos que se alternam a cada 5 s: onda, cometa, pulso, encontro
      uint8_t e = (t / 5000) % 4;
      for (uint8_t i = 0; i < n; i++) {
        float f = 0;
        if (e == 0) f = 0.12 + 0.88 * (0.5 + 0.5 * sin(s * 5.5 - i * 0.65));
        else if (e == 1) { float d = fabs(fmod(s * 9.0, n) - i); if (d > n / 2) d = n - d; f = 1.0 - d / 3.5; }
        else if (e == 2) f = 0.1 + 0.9 * (0.5 + 0.5 * sin(s * 3.0));
        else { float p = fmod(s, 2.0); float nivel = p < 1 ? p : 2 - p; uint8_t borda = min(i, (uint8_t)(n - 1 - i)); f = borda < nivel * (n / 2 + 1) ? 1.0 : 0.05; }
        pixel(i, cor(255, 115, 15, f));
      }
      break;
    }
    case M_MENU:
      tudo(cor(255, 115, 15, 1.0));
      break;
    case M_SELECT:
      for (uint8_t i = 0; i < n; i++) {
        float f = 1.0;
        if (ondas > 0) f = 0.15 + 0.85 * (0.5 + 0.5 * sin(s * 6.0 * ondas - i * 0.8));
        pixel(i, cor(255, 115, 15, f));
      }
      break;
    case M_STARTING: {
      float p = min(1.0, s / 0.8);
      for (uint8_t i = 0; i < n; i++) {
        uint8_t borda = min(i, (uint8_t)(n - 1 - i));
        pixel(i, borda <= p * (n / 2) ? cor(255, 140, 30, 1.0) : 0);
      }
      break;
    }
    case M_PLAY:
      tudo(cor(255, 100, 10, 0.35 + 0.25 * sin(s * 2.5)));
      break;
    case M_HIT:
    case M_BOOST: {
      float f = 1.0 - s / 0.45;
      uint8_t r = 255, g = modo == M_BOOST ? 200 : 120, b = modo == M_BOOST ? 40 : 20;
      if (t < 90) tudo(cor(255, 255, 255, 1.0));
      else tudo(cor(r, g, b, f));
      if (s > 0.45) mudar(modo_volta);
      break;
    }
    case M_RECORD:
      for (uint8_t i = 0; i < n; i++) {
        bool liga = ((uint8_t)(s * 12) + i) % 3 == 0;
        pixel(i, liga ? cor(255, 220, 60, 1.0) : cor(255, 120, 10, 0.25));
      }
      if (s > 3.0) mudar(modo_volta);
      break;
  }
  mostrar();
}

void setup() {
  Serial.begin(9600);
  pinMode(PINO_SENSOR, INPUT_PULLUP);
  fita1.begin();
  fita2.begin();
  fita1.setBrightness(BRILHO);
  fita2.setBrightness(BRILHO);
  tudo(0);
  mostrar();
  Serial.println("OLA:SLAM_ARENA:1");
  modo_desde = millis();
}

void loop() {
  ler_serial();
  ler_sensor();
  static unsigned long ultimo = 0;
  if (millis() - ultimo >= 20) {       // 50 quadros por segundo
    ultimo = millis();
    efeitos();
  }
}
