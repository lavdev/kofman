# Contribuindo com o Byte Eater

Obrigado por querer contribuir! O Byte Eater é um projeto open source feito em
Kof e recebe contribuições de código, arte, documentação, testes e ideias de
gameplay.

## Antes de começar

Instale:

- Kof 0.3.2-beta;
- ImageMagick, para o pipeline de sprites;
- `make` e `python3`.

Consulte o [README](README.md) para instalação e execução.

## Fluxo local

```bash
make test       # testes da lógica pura
make verify     # testes + build JS + check do backend
make web        # gera a experiência jogável em web/
```

Para testar a API, execute `make serve` em um terminal e `make api-smoke` em
outro.

## Organização do código

- `src/game/`: lógica do jogo, estado, simulação e renderização;
- `src/server/`: API e persistência do placar;
- `assets/`: atlas, sprites gerados e ponte de teclado;
- `tests/`: smoke tests externos.

Leia [AGENTS.md](AGENTS.md) antes de alterar o frontend. O Kof possui
restrições importantes: handles de `Canvas` e `Label` devem permanecer no
escopo permitido de `main()`, e funções puras devem continuar separadas da
renderização.

## Pull requests

1. Crie uma branch para sua alteração.
2. Mantenha cada PR focado em uma mudança coerente.
3. Adicione ou atualize testes para regras novas.
4. Execute `make verify` antes de enviar.
5. Descreva o comportamento alterado e como foi validado.

Não faça commit de `web/` ou `data/`; são artefatos gerados e ignorados pelo
Git.

## Arte e assets

Altere o atlas somente quando houver uma decisão explícita de design. Para
sprites derivados, atualize o pipeline em `assets/slice.sh` e execute
`make slice`. Consulte `assets/ASSET.md` e mantenha os créditos da arte.

## Relatos de bugs

Inclua passos para reproduzir, comportamento esperado, comportamento observado
e versão do Kof. Para problemas visuais, inclua screenshot quando possível.
