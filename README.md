# kopman · Byte Eater

Jogo de labirinto estilo pacman, **fullstack e 100% Kof**: frontend em
`kof.ui`/Canvas 2D compilado para **kofjs** (roda no browser) e backend em
**kof.web** (JVM) que serve o jogo e mantém um placar REST persistente.

Arte original: o *Byte Eater* e os *code bugs* (azul, rosa, laranja) do atlas
`assets/byte-eater-atlas.png` — criaturas próprias, sem personagens de
Pac-Man/Ghosts.

Este projeto é open source e está disponível sob a licença [MIT](LICENSE).

> Repositório: `kofman/`. O jogo em execução se chama **Byte Eater**; o
> projeto/codename é **kopman**. Especificação técnica p/ agentes: ver
> [`AGENTS.md`](AGENTS.md).

---

## Funciona assim

Você é o **Byte Eater**: corra pelo labirinto comendo **pellets** (+10) e
evite os três **code bugs**. Os **power bytes** ciano (+50) assustam os bugs
por alguns segundos — nessa janela você pode devorá-los (+200). Limpe todos
os pellets para subir de nível (mais rápido a cada nível). São 3 vidas por
partida e um recorde de sessão. O backend guarda um placar top-50 via REST.

Controles:
- **Mouse/toque**: botões ◀ ▶ ▲ ▼ na tela (mais `pausa` e `novo jogo`).
- **Teclado**: setas `← → ↑ ↓` ou `WASD`.

---

## Instalação

### Pré-requisitos

| Ferramenta | Versão | Uso |
|---|---|---|
| **Kof** | ≥ 0.3.2-beta (testado com 0.3.2-beta) | compila frontend (kofjs) e backend (JVM); JDK embutido |
| **ImageMagick** (`magick`) | qualquer recente | fatia o atlas em sprites |
| **make** | qualquer | orquestra `slice/web/serve` |
| **python3** | 3.x | alternativa de preview sem backend |

O Kof é uma distribuição autocontida (compilador + CLI + runtime + stdlib +
JDK embutido): **não precisa de Java, Maven ou Node instalados**. Para
usar outro caminho de `kof` que não o do `PATH`:

```bash
export KOF=/caminho/para/bin/kof   # ou: make KOF=/caminho/para/bin/kof web
```

Verificação rápida da toolchain:

```bash
kof info          # mostra versão/targets e o JDK embutido
magick -version | head -1
```

### Instalando o Kof

1. Baixe o pacote da sua plataforma na página de releases:
   <https://github.com/KofLang/Kof4j/releases> (cerca de 230 MB).
   - **Linux (Intel/AMD 64 bits):** `kof-*-linux-x86_64.tar.gz`
   - **macOS (Apple Silicon):** `kof-*-macos-arm64.tar.gz`
   - **Windows (Intel/AMD 64 bits):** `kof-*-windows-x86_64.zip`
2. Extraia e coloque o `bin` no `PATH` (Linux/macOS):

   ```bash
   tar -xzf kof-*-linux-x86_64.tar.gz
   DIR=$(ls -d kof-*-linux-x86_64 | head -1)
   export PATH="$PWD/$DIR/bin:$PATH"     # para o terminal atual
   # permanente: adicione a linha acima (com caminho absoluto) ao ~/.bashrc
   ```
3. Confirme:

   ```bash
   kof version    # ex.: kof 0.3.2-beta
   kof info       # deve mostrar "JVM: ... (embedded)"
   ```

No Windows, use `Expand-Archive` e adicione `...\bin` ao PATH do sistema.
Mais detalhes (checksum, atualização, troubleshooting): guia oficial de
instalação que acompanha o pacote em `docs/distribution/INSTALL.md`.

### Build

```bash
cd kofman          # raiz deste repositório
make web
```

`make web` faz três coisas: (1) fatia o atlas em `assets/sprites/` (24 PNGs),
(2) compila `src/game/game.kf` para `web/` (kofjs), (3) injeta a ponte de
teclado (`keyboard_bridge.js`) no `index.html` gerado.

---

## Como rodar

### Modo fullstack (recomendado)

```bash
make serve            # make web + kof serve src/server/server.kf
# abra:  http://localhost:8080/
```

O servidor kof.web entrega o jogo (`/`, sprites em `/sprites/*.png`) e a API
de placar na mesma origem. O app define a própria porta com
`app.listen(8080)` — para mudá-la, edite essa linha em
`src/server/server.kf` e rode `make serve` de novo (a CLI `kof serve` avisa
que ignora `--port` nesse modo).

### Só o jogo (sem backend/API)

```bash
make preview          # python http.server na pasta web/
# abra:  http://localhost:8080/
```

Para jogar pela CLI com webview nativo (`kof run src/game/game.kf
--target=js`) funciona apenas a lógica/botões — sem sprites nem teclado
(ver Limitações).

---

## API do placar

| Rota | Descrição |
|---|---|
| `GET  /api/health` | saúde + metadados (`game`, `lang`, versão) |
| `GET  /api/scores?limit=N` | top-N do placar (default 10, máx 100), ordem decrescente |
| `POST /api/scores` | envia `{"name","score","level"}` → `201` + top-10 |

```bash
# enviar uma partida
curl -X POST http://localhost:8080/api/scores \
     -H 'Content-Type: application/json' \
     -d '{"name":"player","score":510,"level":2}'
# → 201 [{"name":"player","score":510,"level":2}, ...]

# consultar
curl 'http://localhost:8080/api/scores?limit=3'

# validar regras (name 1–12 de [a-zA-Z0-9 ], score 0–9.999.999, level 1–999)
curl -X POST http://localhost:8080/api/scores -d '{"name":"a b!","score":1,"level":1}'
# → 400 {"error":"name must be 1-12 chars [a-zA-Z0-9 ]"}
```

Persistência: `data/scores.json` (top-50), criado pelo servidor na primeira
gravação; caminho relativo à raiz do projeto. JSON tipado via `kof.json`.

---

## Informações técnicas

### Arquitetura

```
                src/game/game.kf (kofjs)          src/server/server.kf (JVM)
   lógica pura (tick 100 ms) ──ops de desenho──▶ kof.ui Canvas 1024×768
        │ state em class G                          ▲ drain na lambda do loop
        └─ sprites: <img> de web/sprites (64×64)    └─ HUD: Labels (pontos/msg)
                                    │ servido por
   web/ (build estático) ◀──────────────── kof.web: app.listen(8080)
   index.html + Default.mjs + sprites + keyboard_bridge.js
                                    │
                    GET/POST /api/* → data/scores.json (kof.io)
```

Pontos centrais (detalhes no AGENTS.md):

- **Loop**: `time.interval(100 ms)` → simulação pura (`tickState`) → a
  lambda do loop (única dona dos handles Canvas/Label) desenha uma fila de
  ops e atualiza os labels. Movimento em grid por *commit-on-arrival*.
- **Entidade**: Byte Eater (26 px/tick, escala por nível) vs. 3 bugs com IA
  caça/scatter (pulsos de 90 ticks), proibição de ré, retorno à base e modo
  *fright* (alpha 55 + piscada nos últimos 20 ticks).
- **Backend**: rotas REST + `app.serveDir("/")` com caminho absoluto
  (`Path("web").toAbsolute()`), validação de payload, ordenação desc e corte
  top-50; funções deliberadamente curtas (constraint do backend JVM).
- **Pipeline de arte**: `assets/slice.sh` (ImageMagick) recorta as 24 células
  do atlas (4×6 de 256 px), remove transparência e centraliza em PNGs 64×64.
- **Teclado**: ponte DOM `keyboard_bridge.js` (de `assets/web-input.js`)
  traduz `keydown` (setas/WASD) em cliques nos botões do d-pad; sem ela o
  `kof.ui` alpha não entrega identidade de tecla aos handlers Kof.

### Stack e versões

- Kof **0.3.2-beta** — targets usados: `js` (frontend) e `jvm` (backend).
- Módulos usados: `kof.ui` (Window/Label/Button/Row/Canvas/Color), `kof.web`
  (app/rotas/serveDir), `kof.json` (decode/encode tipado), `kof.io`
  (Path/File), `kof.time` (interval).
- Arte: `byte-eater-atlas.png` 1024×1536 RGBA; 24 sprites 64×64.

### Estrutura do projeto

```
assets/            atlas + slice.sh + sprites/ (24 PNG) + web-input.js/patch_web.sh
src/game/           módulos de estado, simulação, atores e renderização
src/game/game.kf    bootstrap/UI e drain do Canvas
src/server/server.kf  backend kof.web + placar (kof.io)
web/               build estático (make web)
data/scores.json   placar persistido (runtime)
Makefile           slice | web | serve | preview | clean
AGENTS.md          especificação técnica/funcional p/ agentes
```

### Números de jogo (referência)

Grid 16×12 (tile 64 px, canvas 1024×768) · ~84 pellets · 4 power bytes ·
tick 100 ms (10 Hz) · pellet +10 · power +50 (fright ~2,5–7 s) · bug +200 ·
3 vidas · velocidades em px/tick — jogador `26+2·(lvl−1)` cap 44; bugs caça
`20+3·(lvl−1)+2·id` cap 40; fright 13; retorno 48.

---

## Limitações conhecidas (plataforma Kof 0.3.2 em desenvolvimento)

1. **Teclado** depende da ponte injetada no build (`patch_web.sh`); rodar o
   `index.html` regenerado sem `make web` perde as teclas.
2. **Cliente não posta o placar**: o runtime kofjs em browser ainda não tem
   `fetch`/WebSocket (gap Fase 5) — o jogo roda na mesma origem do servidor,
   mas a submissão de score é via REST/curl até a plataforma expor fetch.
3. `kof run --target=js` (webview) gera outro `index.html` sem `web/sprites`
   e sem a ponte de teclado → para a experiência completa, sirva a pasta
   `web/` (modo fullstack ou `preview`).
4. `kof check` no `game.kf` pode abortar com erro interno do backend JVM
   (ASM) — o arquivo é validado pelo build `--target=js`; o `server.kf` (que
   passa no check) mantém funções curtas por essa mesma razão.
5. Sprites `<img>` carregam assíncronos: primeiros frames podem aparecer sem
   os personagens (um instante após abrir a página tudo normaliza).

---

## Verificação executada (evidência)

Testado em Chromium headless real e `curl`, servindo pela própria `make
serve`:

- Boot, HUD e canvas (paredes/pellets/power/sprites por amostragem de
  pixels e inspeção visual).
- Começar com clique e com tecla (setas/WASD): comer pellets (+10), power
  (+50) com *fright*, devorar bug (+200), perder vida, **game over com
  recorde** e reinício preservando recorde, **transições de nível 1→4**,
  pausa/retomar — 0 exceções de runtime em sessões de ~40 s.
- API: health, GET top-N, POST válido (201 + ordenação), validações 400,
  malformado, persistência em `data/scores.json`.

## Créditos da arte

Atlas original gerado para este projeto (descrição em `assets/ASSET.md`;
o prompt de geração exclui expressamente Pac-Man, Ghosts e personagens de
jogos existentes). Os sprites em `assets/sprites/` são derivados desse atlas
pelo `assets/slice.sh`; `assets/web-input.js` é a ponte de teclado escrita
para este projeto.
