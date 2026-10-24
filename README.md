# Moshoku RPG para Roblox

Direção do Pedro (13/10/2026): **exploração de mundo aberto e combate por turnos**, começando por uma região pequena. Mestre é uma possibilidade futura sobre o mesmo núcleo; o objetivo é um jogo que funcione sem mestre. Avatar Roblox agora, personalização própria depois. Priorizar assets gratuitos/código aberto adequados, com procedência e revisão.

Para trabalhar: leia [arquitetura atual](docs/ARQUITETURA.md), consulte a tarefa em [TAREFAS](docs/TAREFAS.md) e localize o comportamento em [MANUTENCAO](docs/MANUTENCAO.md). Consulte histórico somente quando necessário; confirme entregas antes de refazê-las.

**24/10/2026 — começo jogável (versão 0.3.0, [PATCH-NOTES](docs/PATCH-NOTES.md)):** apertar Play leva da abertura à criação, à vila, à provação de um treinador, à primeira luta na arena e de volta ao mapa, conferido no Studio. Não testado ainda em celular, telas médias e multiplayer.

**Estado atual (17/10/2026):** exploração a pé com combate por turnos e **runs cooperativas** (1–4 jogadores): vila, acampamento, Floresta Sombria e Ruínas pela passagem das montanhas. W1b substitui viagem por painel por eventos de caminho, relógio de 8 minutos/dia, caçadas na praça e patrulhas por região; segunda árvore aprendida integra a ficha. Verificação local e limites de Studio em [TESTES](docs/TESTES.md); estado das entregas em [TAREFAS](docs/TAREFAS.md). Ferramentas de mesa continuam no mesmo núcleo. **23/10:** a patrulha que encosta leva o grupo à Luta da mesa numa arena com o cenário da região (cidade, campo, floresta e ruínas; [PLANO §13](docs/PLANO.md)) e devolve todos ao ponto do contato. O mesmo vale para marcos, guardião da run e dojo; o combate J2 antigo foi apagado.

**Protótipo pausado:** o combate clássico de Espada/Magia/Defender segue desativado e não é uma opção jogável nesta versão. A integração CLEG foi revertida; as lutas do mundo usam a Luta da mesa na arena da região. A recuperação e suas verificações estão em [TAREFAS](docs/TAREFAS.md) e [TESTES](docs/TESTES.md).

## Jogar

Gere o place com `powershell -File tools/build-place.ps1`, abra `Moshoku-Prototipo.rbxlx` no Studio e inicie **Play**. A abertura conduz à criação e à primeira run, sem árvore; procure um mestre, depois o quadro de caçadas ou a trilha da Floresta. Ruínas são alcançadas a pé pela passagem. **RUN** mostra história e escolhas dos eventos; **CONTA** mostra desbloqueios; **AJUDA** explica os controles. O relógio pausa em combate e o prazo continua valendo. Para os comandos da mesa, veja abaixo.

A faixa no alto acompanha a vez atual e indica quem vem depois. Deslize a fila para consultar os demais participantes; ao passar o turno, ela volta para quem está agindo.

Ao começar a partida, a câmera centraliza os participantes no tabuleiro jogável e aproxima conforme o espaço da tela. Depois, seus movimentos e zoom são preservados. No celular, recursos e condições ficam em um resumo curto. Em paisagem baixa, toque em **Escolher ação**; escolher uma carta recolhe a barra para liberar a mira, com **Cancelar mira** acessível. MENU continua disponível por toque.

As consultas da mesa adaptam letras e botões à tela, com preparação em retrato no celular. O selo mostra a prontidão confirmada; a preparação explica pendências e quando é preciso sentar. Escolher novamente o modo/desafio atual preserva as confirmações. Durante uma consulta, o joystick cede espaço aos toques e retorna ao fechar; controles de navegação conservam o foco quando a página atualiza.

A árvore de progressão da mesa abre ranks e compra habilidades pelo servidor, com PA infinito provisório até Intermediário. O perfil pessoal J3a persiste construção e habilidades compradas; XP, recompensas e progressão de ranks ainda não estão implementados. T continua disponível para entregar a ficha; M alterna o tabuleiro durante a partida e não interfere no lobby nem na digitação. As habilidades dos personagens prontos continuam disponíveis.

## Usar a mesa

1. Gere o place: `powershell -File tools/build-place.ps1`. Abra `Moshoku-Prototipo.rbxlx` no Studio.
2. Para testar mestre + jogador: aba **Test** → **Clients and Servers** → 2 jogadores → Start. O primeiro cliente é o mestre.
3. Tecla **M** (ou botão "Visão da mesa") alterna a câmera de mesa. WASD move a câmera, roda do mouse faz zoom.
4. Clique numa ficha para selecionar; clique numa casa vazia para movê-la. Clique direito desmarca.
5. Os specs não rodam automaticamente no Play. Para executá-los pelo MCP no servidor, use `local s=game.ServerScriptService.Server; return require(s.TestRunner).run(s.tests)` e confira o resultado no Output. A suíte local roda com `powershell -ExecutionPolicy Bypass -File tools/testar.ps1`.

Para importar uma ficha do site: `powershell -File tools/ficha-para-mesa.ps1 "pasta/da/ficha.mtficha"` (ou o link de compartilhar entre aspas). O código vai para a área de transferência; cole no painel do mestre. A ferramenta usa o código do site, sem modificá-lo, para calcular PV, mana, atributos, CA e iniciativa.

No lobby atual, o primeiro participante é mestre e pode transferir o posto pelo escudo; a saída abre eleição consentida. Permissão ADM é independente. A lista `MESTRES` em `MesaRoles` pertence ao fluxo legado sem sala, usado em roteiros específicos.

## Protótipo clássico pausado

A integração CLEG de 19/10 foi revertida após a revisão do fluxo. O protótipo clássico permanece pausado e não há posto ou instrução de acesso no jogo. O combate de exploração é a Luta da mesa na arena da região. A recuperação e as verificações em andamento estão registradas em [TAREFAS](docs/TAREFAS.md) e [TESTES](docs/TESTES.md).

## Como trabalhar nesta pasta

`src/` guarda os scripts editáveis. `default.project.json` mapeia os arquivos para o Studio usando Rojo. Nesta primeira versão, você não precisa instalar Rojo: o arquivo `.rbxlx` já foi gerado.

Após alterações, execute `powershell -File tools/build-place.ps1` nesta pasta e reabra o arquivo gerado. Esse gerador atende a estrutura atual; ao adicionar pastas ou assets, atualize-o ou passe a usar Rojo. Com Rojo instalado, `rojo serve` inicia a sincronização e o plugin Rojo no Studio conecta os arquivos. Referência: https://rojo.space/docs/v7/getting-started/new-game/

## Integração com assistentes

### Extensões recomendadas no VS Code

Abra esta pasta no VS Code e use Extensões → filtro `@recommended`. A pasta `.vscode` já lista as recomendações, sem instalar nada automaticamente:

- **Rojo – Roblox Studio Sync**, de evaera: https://marketplace.visualstudio.com/items?itemName=evaera.vscode-rojo — conecta os arquivos ao Studio. Use `Ctrl+Shift+P` → `Rojo: Open menu`, instale o plugin do Studio pelo menu e inicie a sincronização. A extensão também oferece instalação do Rojo quando necessário.
- **Luau Language Server**, de JohnnyMorganz: https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.luau-lsp — suporte de linguagem, sugestões e diagnósticos. A plataforma Roblox foi configurada nesta pasta; resolução completa das Instances pode exigir sourcemap do Rojo.
- **StyLua**, de JohnnyMorganz: https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.stylua — formatação consistente de Luau; formatar ao salvar foi configurado nesta pasta.

No Studio, abra o plugin Rojo e conecte ao servidor iniciado pela extensão. Faça edições dos scripts em src no VS Code; teste com Play no Studio. Para usar o arquivo atualizado sem sincronização, pare o teste, feche a versão anterior e reabra Moshoku-Prototipo.rbxlx.

Se o plugin disser **Couldn't connect to the Rojo server**, inicie o servidor: no VS Code, **Terminal → Run Task → Rojo: iniciar sincronização**; ou, nesta pasta, `powershell -ExecutionPolicy Bypass -File tools/rojo.ps1`. Mantenha esse terminal aberto e conecte o plugin a **localhost:34872**. Se já houver servidor deste projeto na porta, o comando apenas informa que está ativo. O script encontra também a instalação Aftman/Rokit fora do PATH. `rojo sourcemap` atende o editor, mas não inicia o servidor de sincronização. Para outra porta: `powershell -ExecutionPolicy Bypass -File tools/rojo.ps1 -Porta 34873` e use a mesma no plugin.

Codex e Claude Code podem editar os scripts desta pasta; Rojo faz a ponte de arquivos com o Studio. Outra opção é o MCP integrado ao Studio: **Assistant → … → Manage MCP Servers → Enable Studio as MCP server**. A documentação oficial descreve Quick connect para Claude Code e Codex CLI: https://create.roblox.com/docs/studio/mcp

A conexão com o Roblox Studio foi confirmada pelas IAs e usada nos testes automáticos. `python tools/studio_mcp.py` acessa o servidor MCP local; `python tools/studio_sync.py` sincroniza os scripts com o place aberto em modo Edit. Resultados, comandos e limitações estão em `docs/TESTES.md`. Se ambos os assistentes participarem, atribua módulos diferentes e integre uma mudança por vez.

## Documentação

- `docs/DUBLAGEM_NPCS.md`: roteiro para gravar goblin, lobo, bandido, urso e Treant, com interpretação, duração e nomes de arquivos.
- `assets/vozes-npcs/README.md`: 47 gravações preparadas para importação e 9 reusos do lobo no urso; manifesto/CSV, ainda sem IDs no jogo.

- `docs/PATCH-NOTES.md`: o que mudou em cada versão, em linguagem de jogador (versão atual 0.3.0).
- `docs/TAREFAS.md`: quadro curto do que está pronto e pendente; histórico completo em `docs/historico/`.
- `docs/SALA.md`: lobby, objetos manipuláveis, controles, preparação e Brotos.
- `docs/MANUTENCAO.md`: mapa dos módulos e orientação para alterar/adicionar comportamentos.
- `docs/MANUAL.md`: **como mestrar** — guia de uso da mesa para o mestre.
- `docs/MESA.md`: mesa virtual, papéis, visibilidade e contrato de rede atual.
- `docs/COLABORACAO.md`, `docs/TAREFAS.md`, `docs/DISCUSSOES.md`: divisão do trabalho entre Claude e Codex e registro de divergências.
- `docs/ARQUITETURA.md`: responsabilidades, contrato de rede e decisões.
- `docs/ROADMAP.md`: etapas e adaptação das regras.
- `docs/TESTES.md`: cenários e situação real da validação.
- `AGENTS.md`: orientações para futuras alterações por assistentes.

Nada do projeto original foi alterado. A mesa já possui salvamento de campanhas, importação de fichas, iniciativa, condições, mapa e névoa. Inventário, árvores completas e minigames pertencem à evolução futura do modo jogo. A mesa depende do mestre para julgar as regras; o combate automático continua pausado.
