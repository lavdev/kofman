# AGENTS.md — kofman (Byte Eater)

Especificação técnica e funcional do projeto para agentes que forem editar o
código. Repositório: `kofman/` (este diretório). Linguagem do projeto: **Kof
0.3.2-beta** (distribuição local — ver `README.md`). Leia isto antes de
alterar `src/game/game.kf`, `src/server/server.kf`, o pipeline de assets ou o
Makefile.

---

## 1. Visão geral

`kofman` é um jogo de labirinto estilo pacman, 100% Kof, fullstack:

- **Frontend** (`src/game/game.kf`, target **kofjs**): o Byte Eater (criatura
  amarela alada) come pellets num labirinto 16×12 enquanto 3 *code bugs*
  coloridos (azul, rosa, laranja) o caçam. Canvas 2D 1024×768 via `kof.ui`.
- **Backend** (`src/server/server.kf`, target **JVM**): `kof.web` serve o
  frontend compilado e expõe um placar REST persistido em JSON.
- **Arte** (`assets/`): atlas original `byte-eater-atlas.png` (4×6 células de
  256px) fatiado em 24 sprites 64×64 (ImageMagick) — pipeline reprodutível.
- **Entrada**: clique nos botões do d-pad **e** teclado físico (setas/WASD)
  via ponte `assets/web-input.js` injetada no build.

O jogo em execução se chama **Byte Eater**; a pasta do projeto é `kofman`.

## 2. Arquitetura (leia antes de mexer)

### 2.1 Por que lógica pura + fila de ops?

Constraint comprovada do compilador kofjs (0.3.2): chamadas de método
`kof.ui` só são abaixadas para o runtime DOM quando o handle do widget é uma
**variável local criada pelo construtor** do widget (ou captura dela) dentro
de `main()`/lambdas. Qualquer handle que cruze fronteira de função
(anotação de parâmetro, campo estático, leitura de estático para local)
perde o tipo de widget e vira chamada JS crua que **quebra em runtime**.

Consequência de design:

- A simulação (`tickState` e helpers) é **pura**: não toca Canvas/Label,
  apenas estado global em `class G`.
- Cada tick a simulação **append ops de desenho** numa `List<Int>` local
  (ver 2.4).
- A **única** lambda de intervalo (`time.interval(100, …)` dentro de `main()`)
  captura `c` (Canvas), `hs` e `hm` (Labels) e faz o *drain* das ops + sync
  dos labels de HUD. Toda chamada a `c.*`, `hs.text`, `hm.text` vive ali
  dentro (ou em `main()`).

**Não** mova desenho/HUD para funções auxiliares com parâmetros tipados
`Canvas`/`Label` — não compila para chamadas válidas (ver §7).

### 2.2 Fluxo por tick (100 ms → 10 Hz)

1. `tickState()` — avança relógio/timers, simula jogador e bugs, colisões,
   transições de modo; depois `buildScene(ops)` descreve o frame.
2. Lambda do loop faz *drain* de `ops` no canvas (`c.setFill`…).
3. Lambda sincroniza `hs` (pontos/nível/vidas/recorde) e `hm` (mensagens),
   com guarda de texto (`G.lastHud`/`G.lastMsg` — capturas são read-only).

### 2.3 Estados do jogo (`G.mode`)

| mod | nome | transição |
|---|---|---|
| 0 | ready (attract, zzz) | 1ª direção (`press`) inicia |
| 1 | jogando | come pellets; colisão→2/3; zera pellets→4 |
| 2 | morrendo (14 ticks, zzz) | depois→1 com `resetActors` |
| 3 | game over (zzz) | seta reinicia **jogando**; botão “novo jogo” volta ao ready |
| 4 | nível completo (9 ticks) | depois→nível+1, `initLevel`, modo 1 |
| 5 | pausa | `togglePause`; overlay escuro alpha 45 |

### 2.4 Formato das ops de desenho

Lista plana de `Int`; códigos:

| op | campos | significado |
|---|---|---|
| 1 | `RECT x0 y0 x1 y1 colorCode` | retângulo sólido |
| 2 | `BEGIN` | `beginPath` (paths em lote) |
| 3 | `MT x y` | `moveTo` |
| 4 | `LT x y` | `lineTo` |
| 5 | `ARC x y r` | `arc` fechado (0..2π) |
| 6 | `FILL colorCode` | `setFill` + `fill` do path atual |
| 7 | `SPR img x y flip alpha` | sprite 64×64 (mirror se flip=1; alpha 0–100) |
| 8 | `ALPHA a` | `setGlobalAlpha(a/100)` |

Cores por código (resolvidas no drain): 0 bg `#040610`, 1 parede `#203096`,
2 realce de parede, 3 pellet amarelo, 4 power ciano, 5 branco, 6 preto.

### 2.5 Constantes e invariantes do jogo

- Grid 16×12, tile `T=64`; canvas 1024×768. Tokens do mapa (linhas de 16
  chars): `#` parede, `.` pellet, `o` power byte, `P` spawn (só no maze de
  origem), ` ` piso sem pellet. **Toda linha tem exatamente 16 chars** e
  borda `#` — validar se editar o labirinto.
- Spawn: jogador `(7,9)`; bug azul `(7,5)`, rosa `(8,5)`, laranja `(7,6)`;
  células de spawn nunca têm pellet (`clearCell`). Powers em `(1,1),(14,1),
  (1,9),(14,9)`.
- Direções: 0 esquerda, 1 direita, 2 cima, 3 baixo.
- Velocidades (px/tick @10Hz): jogador `26 + 2*(lvl-1)` (cap 44); bugs em
  caça `20 + 3*(lvl-1) + 2*id` (cap 40); assustados 13; voltando pra casa 48.
- Movimento por *commit-on-arrival*: em cima do centro de um tile → decide
  virada e **comita o próximo tile** (`ptx/pty`), depois desliza até o centro.
  Bugs nunca dão ré (exceto beco sem saída).
- Pontuação: pellet +10; power +50 e ativa fright `70 - 8*(lvl-1)` ticks
  (mín. 25); bug assustado devorado +200 (vira `st=2` e volta pra casa).
  Recorde de sessão `G.hi` (atualizado no game over). 3 vidas por partida
  (HUD mostra respawns restantes, começa em 2; 3ª morte = game over).
- IA dos bugs: persegue o jogador em pulsos de 90 ticks alternando com
  *scatter* para o canto (`(tick/90)%2`); assustado anda pseudo-aleatório
  determinístico (sem RNG); pisca nos últimos 20 ticks de fright (salta
  frame em tick par) e é desenhado com alpha 55.
- Animação: sprite do jogador cicla a cada 2 ticks (`(tick/2)%4`) e usa a
  linha `zzz` em ready/dying/gameover; bugs: azul 4 frames, rosa/laranja 2.

### 2.6 Índice de sprites (`G.imgs`, ordem fixa)

```
0..3 player_run_*   4..7 player_alt_*   8..11 player_byte_*
12..15 player_zzz_* 16..19 bug_blue_*   20..21 bug_pink_*  22..23 bug_orange_*
```

A arte canônica (linhas 0–2 do atlas) **olha para a DIREITA**; sprites são
espelhados com `save/transform(-1)/drawImage/restore` quando a entidade anda
para a esquerda (bugs azuis têm arte canônica esquerda — só bugs rosa/laranja
olham para o observador e não espelham). Se um frame novo for adicionado ao
atlas, atualizar `assets/slice.sh`, a tabela acima e o header do arquivo.

## 3. Árvore de arquivos

```
Makefile                 targets: slice, web, serve, preview, clean
assets/
  byte-eater-atlas.png   atlas-fonte 1024x1536 (4x6 de 256px) — NÃO editar
  ASSET.md               descrição da arte
  slice.sh               atlas -> assets/sprites/*.png (ImageMagick)
  sprites/               24 PNGs 64x64 transparentes (gerados)
  web-input.js           ponte teclado->d-pad (injetada no index.html)
  patch_web.sh           copia web-input.js e injeta <script> no index.html
src/game/game.kf         bootstrap/UI e drain do Canvas
src/game/state.kf        estado global e modelo de Bug
src/game/actors.kf       criação e reset dos atores
src/game/maze.kf         mapa e ciclo de níveis
src/game/player.kf       movimento e coleta do jogador
src/game/bugs.kf         IA e movimento dos bugs
src/game/collisions.kf   colisões e vidas
src/game/simulation.kf   loop de simulação e transições
src/game/game_flow.kf    comandos de partida e pausa
src/game/sprites.kf      catálogo e carregamento de sprites
src/game/hud.kf          formatação pura do HUD
src/game/scene.kf        composição pura da cena
src/game/draw_ops.kf     operações abstratas de desenho
src/server/server.kf     backend kof.web/JVM (~190 linhas)
web/                     saída de `make web` (Default.mjs + runtime + sprites)
data/scores.json         placar persistido (criado em runtime pelo servidor)
```

## 4. Backend e API

`src/server/server.kf` (funções curtas de propósito — ver §7, item 6):

| Rota | Comportamento |
|---|---|
| `GET /api/health` | `{"ok":true,"game":"byte-eater","lang":"kof",…}` |
| `GET /api/scores?limit=N` | array JSON top-N (default 10, máx 100), score desc |
| `POST /api/scores` | body `{"name","score","level"}`; 201 + top-10 ou 400 `{"error":…}` |

Validação: `name` 1–12 chars `[a-zA-Z0-9 ]`; `score` 0–9.999.999; `level`
1–999. Mantém top-50 em `data/scores.json` (`kof.io`, JSON tipado). Erros de
JSON malformado viram `{"error":"handler error: …"}` (runtime).

- O servidor **define a própria porta** com `app.listen(8080)`; o flag
  `--port` do `kof serve` é ignorado nesse modo (a CLI avisa).
- Estáticos: `app.serveDir("/", …)` com **caminho absoluto** (`Path("web")
  .toAbsolute()`) — serveDir resolve relativos contra `-Dkof.root`, não cwd.
- Persistência é escrita síncrona por requisição; adequado para placar de
  demonstração (sem lock/transação).

## 5. Comandos de build/verificação

```bash
make web        # slice + compila src/game -> web/ + injeta ponte de teclado
make serve      # make web + kof serve src/server/server.kf  -> :8080
make preview    # python http.server na web/ (sem API)
make slice      # só refaz sprites; make clean remove web/ e data/
```

Verificação exigida após qualquer mudança funcional:

1. Frontend: `kof build src/game --target=js --output web` precisa compilar
   sem diagnostics (não usar `kof check` no game.kf — ver §7 item 6).
2. Servidor: `kof check src/server/server.kf` limpo.
3. Smoke E2E no browser real: abrir `http://127.0.0.1:8080/`, clicar ▶ e
   observar HUD de pontos/mensagens; testar teclas setas/WASD; conferir
   canvas com pixels (fundo 0_0_1, paredes 2_3_9, pellets 15_13_5).
4. API: `curl` de health/GET/POST + `cat data/scores.json`.

## 6. Invariantes de edição (checklist)

- [ ] Não quebrar as 16 colunas / 12 linhas do labirinto; borda `#` completa.
- [ ] Nomes de função: **não** usar `at` (colide com builtin scheduler);
      o leitor de célula se chama `glyph`.
- [ ] Não concatenar `Char` em `String` (vira número); usar `substring`.
- [ ] Não criar `List` com elementos em inicializador de campo estático nem
      `listOf(não-vazio)` atribuído direto a estático — montar via local.
- [ ] Não inicializar estáticos com expressões (só literais); usar
      `initGlobals()`.
- [ ] Não chamar métodos de widget sobre campo estático ou variável lida de
      estático (perde o tipo de widget).
- [ ] Manter funções rasas (poucos locais/ifs) em código que roda no backend
      JVM — frames profundos derrubam o ASM (ver §7).
- [ ] Novo sprite → atualizar `slice.sh`, índice em `G.imgs` (comentário do
      header) e a tabela §2.6.
- [ ] Novas cores de desenho → estender códigos de paleta no drain (não
      passar `Color` por função).

## 7. Constraints da toolchain (Kof 0.3.2-beta — todas verificadas em runtime)

1. **Widgets só funcionam como locais de construtor/captura** em `main()`/
   lambdas; parâmetros/estáticos com tipos `kof.ui` emitem JS cru que
   quebra (`c.setFill is not a function`). → arquitetura de op-drain.
2. `static List<…> x = listOf(el, el, …)` **perde o corpo** no JS target
   (emite `G.x = <temp undefined>`). Montar via local e atribuir.
3. Inicializadores estáticos **só com literais** sobrevivem (`static px =
   7*64+32` vira `static px;` sem valor). → `initGlobals()`.
4. `Char` é ponto de código numérico: `' '` é `32`; `"P" + ' '` gera `"P32"`.
5. Função top-level `at` é reescrita para o builtin `kofSchedulerAt` (nunca
   chamada). 
6. Backend JVM: `kof check`/compilação derrubam com `ASM COMPUTE_FRAMES
   ArrayIndexOutOfBoundsException` em métodos com muitos locais/ifs aninhados
   (ex.: o game.kf inteiro). Contornos: game.kf é validado pelo **build JS**;
   server.kf usa funções curtas e passa no `kof check`.
7. `if` com `return` no fim seguido de outro `if` no mesmo nível → parser
   aninha o segundo if dentro do primeiro (braceless?) — movimento usa
   aritmética com clamp, sem cadeias `if(dir==N){…return}`.
8. Teclado: `kof.ui.Event` só expõe `type()` — sem identidade da tecla.
   Ponte DOM: `assets/web-input.js` traduz `keydown` em cliques nos botões.
9. Browser kofjs (alpha) **não tem** `fetch`/WebSocket/`localStorage`
   (gap Fase 5 da plataforma) → o cliente não consome a API; placar via
   REST/curl. Também: `kof run --target=js` (webview) roda outro index.html
   sem sprites nem ponte — o caminho suportado é servir `web/` (backend ou
   `preview`).
10. `time.now()` é `Long`; `Long/Int` continua `Long` — não alimentar campo
    `Int` com isso (verificador JVM rejeita).
11. `serveDir` com prefixo relativo resolve contra `-Dkof.root` (≠ cwd) —
    passar caminho absoluto.
12. Sprites são `<img>` criados sem append no DOM; o browser decodifica
    assíncrono — os primeiros frames podem aparecer sem sprite.

## 8. Limitações conhecidas / próximos passos naturais

- Fright não muda a arte dos bugs (usa alpha + piscada) — sem sprite
  "assustado" dedicado no atlas.
- Placar do jogo não é postado pelo cliente (item 9 acima); ganhar suporte
  de `fetch` na plataforma permitiria POST automático no game over.
- Uma única tela/modo por página (sem router).
- Dificuldade sobe com velocidade e fright mais curto; labirinto fixo.
- O jogo depende de ponte de teclado no build (`patch_web.sh`): se o
  index.html for regenerado sem `make web`, teclas param de funcionar.
