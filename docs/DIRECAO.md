# Direção do jogo — hub + expedições (14/11/2026)

Decisão do Pedro em 14/11/2026. Este documento substitui o rumo de mundo aberto
descrito em `PLANO.md` §11–§13 e em `JOGO.md` onde houver conflito. As regras de
combate do livro (`MESA.md`, `FIDELIDADE.md`) continuam valendo sem mudança.

## 1. Como o jogo funciona

Fontes: conversa de 14/11/2026 e o documento do Pedro "ideal do meu jogo x
avarege capaing" (Google Docs). A inspiração de estrutura é o jogo de Roblox
*An Average Campaign*; usar só a estrutura como referência, sem copiar nome,
arte, personagens ou fases.

1. **Menu.** Um botão cria uma sala ou entra em uma.
2. **Lobby (sala).** Em primeira pessoa, com os avatares normais do Roblox.
   Quem cria a sala é o mestre e decide quantos entram. Aqui os jogadores criam
   o personagem e editam a aparência. O menu de sala em primeira pessoa já
   existe (`SalaView`) e precisa de retrabalho.
3. **Início.** Quando o mestre inicia, o grupo vai para outro servidor só com
   eles; lá se escolhe o modo de jogo. Foco agora: **modo campanha, sem mestre**.
4. **Campanha longa com save.** O grupo salva e volta depois ao mesmo lobby, que
   mostra o que já aconteceu (ex.: a miniatura do chefe derrotado caída no
   tabuleiro). Depois que a campanha começa, a aparência não muda mais no lobby;
   o personagem só muda pelas ações dentro do jogo.
5. **Abertura na taverna.** Cena de todos se conhecendo na taverna; chega alguém
   e entrega a missão principal (algo como impedir o fim do mundo), com prazo.
6. **Tempo por ações.** O prazo não é relógio rodando: as ações gastam dias. O
   jogo é tranquilo com os dias.
7. **Cidade inicial (hub).** Mundo aberto pequeno, sem combate: NPCs, conversa,
   lojas, missões. A missão do esgoto é um evento da cidade; por enquanto todos
   os eventos acontecem sempre (o sorteio por campanha vem depois).
8. **Portas.** Os caminhos que saem do hub são portas que levam a uma área. Toda
   troca de cenário (porta, fim de batalha) mostra uma tela "Viajando".
9. **Área (expedição).** Não é mundo aberto; é uma sequência de passos com um
   contador no topo (ex.: 0/8; 5 no começo do desenvolvimento):
   - **combate** contra inimigos sorteados da lista da área;
   - **acampamento** depois do combate: compartilhar itens com os companheiros,
     ver inventário e status, e descansar (no máximo 2 vezes; sem pegar itens
     aleatórios);
   - **tela de escolhas**: cerca de 2 caminhos, ou voltar para a cidade (custa dias);
   - **evento**: alguns abrem um mundo aberto pequeno sem combate. Exemplo, o
     homem estranho: ele ensina uma classe, ou o grupo pode enfrentá-lo e ganhar
     itens bons. Depois de um evento vem um combate obrigatório, e só então o
     acampamento;
   - **chefe da área** quando o contador enche, com drops próprios.
10. **Volta.** Ao terminar, o grupo volta à cidade com dinheiro, item ou classe.
11. **Rota.** Por enquanto um caminho só: cidade → esgoto → … → floresta, que tem
    no meio uma área aberta pequena só de conversa e interação.
12. **Combate.** Por turnos, na grade, fiel ao RPG de mesa do Pedro. As regras
    ficam; muda a apresentação (modelos, animação, câmera, feedback, HUD).
13. **Menu de status** dentro do jogo: está ruim e precisa de retrabalho.

### Decisões do Pedro (14/11/2026)

- Prazo da missão principal: cerca de 30 dias (provisório).
- Custos: entrar numa área 1 dia; avançar de sala grátis; descansar meio dia;
  treinar como já está.
- Voltar à cidade custa mais quanto mais fundo o grupo está (uma área de 8 dias,
  deixada no 7º, custa perto disso). O ouro ganho fica: voltar serve para
  entregar missão, vender e comprar na loja.
- O progresso da área é mantido. Retomar gasta os dias de ir até onde parou, sem
  repetir eventos; no máximo alguns combates (onde haveria 4, a volta tem 2 e a
  retomada tem 1). **Esses combates reduzidos ainda não foram implementados.**
- Grupo inteiro caído: volta para a cidade pagando os dias da distância, sem
  perder ouro e mantendo o progresso da área; a campanha continua (confirmado
  pelo Pedro em 15/11/2026).
- Descanso e exaustão: o grupo escolhe quando descansar, sem limite fixo. Cada
  luta sem descanso depois dá 1 nível de Exaustão do livro; descansar (meio dia)
  zera. **Ainda não implementado**: hoje vale o limite provisório de 2 por área.
- Missão principal: **calamidade de mana**. Uma anomalia no céu cresce a cada
  dia e estoura no dia 30. O chefe de cada área guarda um fragmento; com eles o
  grupo sela a anomalia. O prazo fica visível no céu.
- Fim do prazo: **luta final forçada** no dia 30, mais forte quanto menos áreas
  concluídas. Vencer dá o final bom; perder, o ruim.
- Área de testes: aberta só no Studio e para administradores.
- Só ferramentas gratuitas (sons, modelos, animação). Cinemáticas: câmera
  `Scriptable` com `TweenService`, barras de cinema, desfoque e campo de visão,
  animações com marcadores (`GetMarkerReachedSignal`) feitas no editor nativo do
  Roblox; `client/CenaAbertura` já segue esse caminho e é a base.

- Telas (14/11): criação de personagem com o personagem em 3D no centro, painel
  de escolhas à direita e etapas embaixo; menu principal como menu de pausa
  central (tela escurecida, painel estreito, poucos botões grandes).

### Decisões do Pedro (15/11/2026)

- Vida e mana entre salas: o que foi gasto numa luta segue para a próxima sala.
  Descansar no acampamento (meio dia) recupera tudo e zera a exaustão.
  **Ainda não implementado** (pacote P5 em `TAREFAS.md`): hoje toda sala começa
  com a vida do último descanso.
- Grupo: só participa quem confirmou no início. Quem chega depois pode pedir
  para entrar quando o grupo está na cidade, com personagem novo e sem classe;
  nunca no meio de uma área. **Ainda não implementado**: hoje a campanha pega
  todo o servidor e quem chega depois só assiste.
- Fim da campanha enquanto só o esgoto existe: com o fragmento do chefe, a
  cidade oferece "Selar a anomalia", que encerra com o final bom. Provisório;
  sai quando houver mais áreas e a luta final do dia 30.

### Telas de referência (Pedro, 15/11/2026)

Capturas do jogo de inspiração em `docs/imagens contextos/` (fora do git: são
de outro jogo). Vale só a estrutura; arte, fonte, nomes e textos são nossos
(tema Pergaminho).

- **Viajando:** tela cheia escura, só o texto "Viajando..." no centro.
- **Acampamento:** cena 3D própria (fogueira, tenda, noite, personagem sentado),
  sem painel no meio. Contador da área no canto superior direito ("Floresta
  (1/5)"). Embaixo, dois botões: "Pronto (0/1)" (quantos confirmaram / tamanho
  do grupo) e "Mostrar", que abre o inventário por cima.
- **Inventário do acampamento:** três colunas. Esquerda, esconderijo do grupo
  com "Transferir ouro"; centro, inventário pessoal (lista de itens com botões
  por item, ouro e "Transferir ouro"); direita, equipamento em grade de espaços
  e lista de atributos. Embaixo, "Pronto" e "Esconder".
- **Escolha de caminho:** título "Para onde seguir?" e cartões lado a lado
  (2 ou 3), cada um com nome, imagem, uma frase, "Votos: N" e botões de votar.
  Embaixo, na mesma linha: "Saquear (N)", o tempo restante da votação e "Pausa
  curta (restantes) (N)", também decididos por voto.
- **Luta:** contador da área no canto superior direito; ordem dos turnos numa
  coluna à esquerda; barras de vida sob cada personagem; embaixo, no centro, as
  cartas de ação, a barra do personagem (nome, nível, vida e mana) e as abas
  Lutar / Itens / Fuga.
- **Lobby:** interior de taverna em primeira pessoa, com os outros jogadores à
  vista; coluna de ícones à direita. O ícone da espada abre a lista de grupos
  ("Grupo de Fulano (2/3)") com pesquisa, "Criar grupo" e "Fechar".

Diferenças já decididas em relação à referência: descanso sem limite fixo, com
exaustão (acima); "Saquear" não existe no nosso desenho.

### Personagem (Pedro, 15/11/2026)

No estilo de Arcane Lineage e Deepwoken (só a estrutura como referência):
corpo R15 padrão do Roblox, roupa do jogo (o jogador não usa as roupas do
avatar), cabelo do próprio avatar do Roblox do jogador, cor definida pela raça
e pelas escolhas da criação, traços de raça (orelha de elfo, barba de anão)
como acessórios nossos. Cabelo que não aceita troca de cor é trocado por um cabelo padrão nosso que aceita. Cabeleireiro na cidade: o jogador informa o ID de um cabelo do catálogo do Roblox e passa a usá-lo no jogo (o servidor valida o ID). Substitui o boneco "quadradão" de cubos e a regra
antiga "avatar Roblox por enquanto". **Ainda não implementado.**

Pacotes gratuitos baixados pelo Pedro em `build/externos/` (fora do git):
Universal Animation Library e Monster Pack Animated (Quaternius), Easy
Animated Enemy Pack (rato, aranha, cobra, sapo, vespa). Conferir a licença de
cada um ao integrar. `MDA_Hatchery_CP1.zip` (pacote Unity sem licença
visível) não será usado.

### Escala do mundo (Pedro, 15/11/2026)

Todas as construções ficam bem maiores em relação ao personagem (corpo R15
padrão, ≈5 studs): portas com folga acima da cabeça, andares altos, ruas e
praças largas. Critério provisório do coordenador: porta ≈ 1,6× a altura do
personagem e pé-direito ≈ 2×; ajustar pelo olho no Studio. **Ainda não
implementado.**

### Luta: referência de apresentação (Pedro, 15/11/2026)

Vídeo de referência em `docs/imagens contextos/` (outro jogo; só a estrutura).
Decisão: **as regras do livro ficam, com grade, casas, alcance e área**. Muda
a apresentação: câmera por trás do ombro de quem age, inimigos à frente,
HUD mínimo (menu de ação curto ao lado do personagem, anúncio "Fulano usa X"
no topo, barras finas de vida sobre cada combatente, cartão compacto do
personagem no canto inferior direito) e câmera que acompanha o golpe. A grade
só aparece no chão ao andar ou mirar.

### Prioridades e ideias do Pedro (15/11/2026, por voz)

- **O mais importante agora: animações e modelos.** Depois cinemáticas, menu e
  balanceamento. O Pedro acha **todas** as animações de hoje muito feias, não
  só um golpe; a da flecha foi o exemplo citado.
- **Viajando:** em vez de só o texto, uma animação curta dos personagens do
  grupo andando. Tem de ser leve (cada área é um mapa próprio). Ideia, não
  obrigação.
- **Acampamento como lugar:** um mapa pequeno e aberto onde o grupo anda, como
  o acampamento de Baldur's Gate 3 (só a estrutura como referência). Quem o
  grupo conheceu numa escolha ou missão passa a aparecer lá depois, e dá para
  conversar com ele (exemplo do Pedro: o vampiro de uma missão concluída).
  **Ainda não implementado**: hoje o acampamento é um painel com o grupo parado
  junto à porta (pacote CAMP1 em `TAREFAS.md`).

### Decisões em aberto (perguntar ao Pedro com opções e recomendação)

- Nenhuma no momento.

## 2. O que já existe e serve

| Peça do desenho | Base existente | Ação |
|---|---|---|
| Menu | `client/InicioView`, `client/AberturaFluxo` | adaptar |
| Lobby | `server/SalaService`, `shared/SalaRegras`, `client/SalaView` | adaptar: modo "expedição" |
| Cena da taverna | `client/CenaAbertura`, `shared/CenaAberturaDados` | adaptar; interior da taverna é novo |
| Cidade | `server/Mundo/Vila`, `shared/Mundo/VilaLayout` | reusar, encolher |
| NPCs e conversa | `shared/Mundo/NpcsDados`, `client/DialogoNpcView` | adaptar; ramificação é nova |
| Missões | `shared/Regras/Missao`, `server/MissaoService` | adaptar: tipo "concluir expedição" |
| Lojas | `server/LojaService`, `client/LojaView` | reusar |
| Portas | não existe; `LutaDoMundoServico` já move o grupo por CFrame | novo |
| Cadeia de salas | `shared/Regras/RunHistoria`, `RunSessao`, `server/RunServico` | adaptar (ver §4) |
| Combate da sala | `LutaDoMundoServico` → `EncontroService.iniciarLutaDoMundo` | adaptar: arena "esgoto", sorteio por área |
| Sala especial | `server/ChefesService`, `shared/Regras/RecompensaEncontro` | adaptar; tabela de drops é nova |
| NPC de classe | `shared/Regras/RunTreinadores`, `server/ProvacoesServico` | adaptar |
| Recompensa na volta | `RunConta.registrarRun`, ouro no perfil | adaptar: ouro, item ou classe |
| Eventos da cidade | `RunTreinadores.sortearAleatorio` (desligado por `SOMENTE_FIXOS`) | reusar |
| Rato do esgoto | `creature/rato-gigante` (dados e modelo) | reusar |

A árvore de história (`RunHistoria`) já tem nós com opções, votação do grupo,
luta que bloqueia o avanço até a vitória e save a cada passo. Falta: aceitar
luta em nó comum (hoje só em `chefe`), gerar a cadeia por run a partir de
`run.semente`, sortear inimigos de uma lista da área, e um tipo de nó mini-hub.

## 3. O que sai

Fica fora do desenho novo; remover junto com os testes que dependem disso:

- relógio em tempo real (`RunRelogio`, `RunTempo`, `RelogioRunView`). O prazo em
  dias **fica**, gasto por ação (`Run.dia`, `CUSTO_DIAS`, `opcao.dias`);
- patrulhas visíveis e combate por contato (`PatrulhasDoMundo`, `Mundo/Patrulha*`,
  `VisaoCone`, `CacadasService`);
- trechos a pé e custos de viagem (`EventosCaminho`, `PassagemLayout`, `RunViagem`);
- patrulhas dentro da vila em `EncontrosPorZona` (hub não tem combate);
- `client/ViagemView` está órfão: aproveitar como tela do mapa de salas ou apagar.

Não retomar: J2/EncontroAutonomo (apagado em 23/10) e CombatService/BattleController.
O motor da Mesa (`EncontroService` + `HabilidadeService`) é a única base de combate.

## 4. Primeira fatia jogável

Menu → lobby → cena da taverna → cidade com NPC de missão → porta do esgoto →
5 salas com escolha de caminho → sala do inimigo especial → volta com recompensa.

1. Desligar o mundo aberto em `server.server.luau` e `RunServico` (patrulhas,
   caçadas, relógio, `mundoAberto`).
2. Criar `shared/Mundo/ExpedicaoEsgoto.luau` (lista de inimigos, 5 salas, sala
   especial, recompensa) e `shared/Regras/ExpedicaoGerador.luau` (monta uma
   história compatível com `RunHistoria` a partir da semente). Em `RunHistoria`,
   novos tipos de nó `sala` (com luta) e `hub`.
3. `RunSessao` recebe a história gerada; tirar de `RunServico` a exigência de
   proximidade para lutar e votar.
4. Sorteio de inimigos por área em `EncontrosPorZona`; arena `esgoto` em
   `ArenasDados` e `ArenaCenario`.
5. Tela do mapa de salas com os votos (`client/RunView` ou o `ViagemView`).
6. `server/PortaExpedicao.luau` e a missão "esgoto entupido" (`MissoesDados`,
   `Missao.TIPOS`, `MissaoService`, falas em `NpcsDados`).
7. Recompensa na volta em `RunServico.fecharConta` e resumo na `ResultadoView`.
8. Interior da taverna e novo trajeto em `CenaAberturaDados`; nascimento na taverna.
9. Botão do `InicioView` leva ao lobby; modo "expedição" em `SalaRegras`,
   `PreparacaoSala` e `SalaService`.

Riscos: o inimigo especial exige uma camada local sobre `Livro/Dados` (gerado do
site, não editar à mão); a segunda árvore ainda não entra na ficha; não há
modelos de esgoto além do rato; 28 criaturas têm dados e só 8 têm modelo.

## 5. Combate: plano de apresentação

Regra fixa: o servidor decide tudo; o cliente só apresenta o recibo. Ordem por
impacto e custo.

**Só código**
1. Criaturas da arena com os modelos do Blender. Hoje `server/CorposDeCriatura`
   monta esferas e caixas; os 8 modelos só aparecem nas patrulhas. Usar
   `CriaturaAnimada` + `ModelosCriaturas.escalaCombate`.
2. Fila de apresentação no cliente: segurar PV e números até o impacto do golpe
   (`BoardView` aplica o snapshot na hora). A IA espera o fim da caminhada antes
   de atacar (`HabilidadeService`, por volta das linhas 2184 e 2203).
3. Câmera: inclinação por volta de 50°, girar com Q/E, seguir quem age, close
   curto no impacto (`BoardView`, `EnquadramentoMesa`).
4. Leitura de acerto e erro: rolagem junto do alvo ("d20 14+5 = 19 vs CA 15"),
   chance de acerto na mira, pausa curta no impacto, esquiva quando erra.
5. HUD no tema V2 (`UI/Tema`): barra de ações com ícones, marcadores de Ações e
   movimento, ordem de turnos com retratos. O kit de arte (`shared/UIArte`,
   `client/UI/Componentes`) já está no estilo Pergaminho (§6).

**Médio**
6. Movimento animado no cliente, casa a casa, olhando para onde anda (hoje é
   interpolação reta no servidor em `AvatarFichas` e `CorposDeCriatura`).
7. Efeitos com texturas enviadas (corte, impacto, fumaça, círculos mágicos) em
   `ParticleEmitter`/`Beam`. A regra antiga "sem assets enviados" de `VISUAL.md`
   deixa de valer.
8. Armas modeladas no Blender, sempre equipadas (hoje são 3 caixas no fantasma).

**Precisa de pipeline novo**
9. Cerca de 12 animações próprias (corte leve e pesado, estocada, arco, conjurar,
   canalizar, reação a golpe, esquiva, bloqueio, queda, postura).
10. Rig e skin no Blender. `tools/blender/lib.py` exporta uma MeshPart por cor,
    sem armature nem textura. Antes de investir, confirmar na documentação da
    Open Cloud se o upload aceita modelo com rig.

**Caminho das animações (pesquisa de 15/11/2026, decisão do coordenador).**
Animação de outro dono não toca na nossa experiência (toda animação é
restrita desde 07/2025) e a Open Cloud só aceita animação em `.rbxm` binário,
sem garantia. Por isso:

1. Flecha e efeitos primeiro, só código e uma malha: voo em arco, rastro,
   cravar no alvo, faíscas por flipbook (texturas CC0 do Kenney).
2. Tocador próprio no cliente (`Motor6D.Transform` em `PreSimulation`, que
   prevalece sobre o Animator), dirigido por clipes em tabela Luau. Os dados
   vêm da Universal Animation Library do Quaternius (CC0), redirecionados para
   o R15 no Blender por script; o que faltar (arco, conjurar) é posado por
   script. Não depende de envio nem de permissão.
3. Criaturas animadas no cliente com o mesmo tocador (peças rígidas e pivôs);
   o servidor manda só o estado.
4. Depois, teste isolado: os mesmos dados como `KeyframeSequence` em `.rbxm`
   pela Open Cloud. Esqueleto e skin nas criaturas só se um teste provar que
   os ossos sobrevivem ao envio.

**Fontes gratuitas a usar (pesquisa de 15/11/2026; conferir a licença na
página de cada pacote e registrar antes de integrar).** Modelos CC0: Kenney
(Mini Dungeon para o esgoto, Retro Fantasy Kit para a vila) e Quaternius
(Fantasy Props MegaKit para taverna, barris e armas; monstros low-poly).
Sons CC0: Kenney Interface Sounds, UI Audio e Impact Sounds. Texturas de
efeito: Kenney Particle Pack em `ParticleEmitter` com flipbook. Código:
`luau-lsp analyze` para checar tipos no `testar.ps1` (ainda não adotado).
Não usar: geradores de IA do MCP do Studio (`generate_mesh`,
`generate_animation`: custo e licença incertos), Pixabay, plugins de terceiros
que rodam código no Studio sem revisão.

Preservar: tabela `ESPEC` de gestos por técnica (`Gestos.luau`), linha do tempo
cancelável, prévia de área compartilhada (`AreaHabilidade`), sons, dublagem,
Reações e modo de efeitos reduzidos.

## 6. Estado da pasta (14/11/2026)

- Esta pasta (`Desktop\Moshoku-roblox`) é o projeto: clone de
  `github.com/peluca2007/Moshoku-roblox`, branch
  `claude/roblox-playable-start-962fc2`, commit `4757f7f` (24/10).
- Sem commit ainda: o kit de arte de interface (`shared/UIArte`,
  `client/UI/Componentes`, `client/Hud`, `client/Atalhos`,
  `tools/blender/ui_kit.py`, `ui_estilos.py`) e este documento.
- Interface: o Pedro escolheu o **estilo 2, Pergaminho** (14/11/2026).
  `tools/blender/ui_kit.py` já gera as peças nesse estilo em `build/ui`
  (mesmos tamanhos e cortes; a arte anterior está em `build/ui/escuro-ouro`).
  Aplicado em 14/11: PNGs enviados (`upload_image` só aceita URL; servir
  `build/ui` em localhost durante o envio), ids em `shared/UIArte.luau` e paleta
  de papel em `shared/UITemaDados`. Falta conferir no Studio a luta e a tela de
  resultado; ver PERG1 em `TAREFAS.md`.
- A pasta antiga `Desktop\Moshokurpgroblox` (git quebrado, cópia parcial) não é
  mais usada; apagar só quando o Pedro confirmar.
- Blender: `Downloads\blender-5.4.0-alpha…\blender.exe`, achado sozinho por
  `tools/blender_rodar.py`.
- Áudios originais (`audios/`, `assets/sons/gerados`) se perderam; os IDs já
  enviados continuam em `assets/vozes-npcs/ids_roblox.json`.

## 7. Plano de execução (14/11/2026)

Pedido do Pedro: plano único juntando a direção acima e as melhorias que ele
trouxe (área de testes, sons gratuitos, conferência de modelos do Blender).
Estado de cada item fica em `TAREFAS.md`; aqui só a ordem e quem faz.

**Modelos (Pedro, 14/11).** Alternar para não esgotar o limite de um só:
Haiku (`economico`) em buscas, documentação e correções pequenas; Sonnet
(`implementador`) no grosso de cada pacote delimitado; Opus em pacotes com
várias responsabilidades, diagnóstico difícil e revisão de entrega alheia;
Fable coordena, revisa a integração, joga no Studio (há um Studio só) e pega
o que os outros não resolverem. No máximo dois agentes por vez, com arquivos
exclusivos. Só ferramentas gratuitas.

**Toda entrega:** `tools/testar.ps1`, conferência no Studio pelo coordenador
quando mexe em runtime, registro em `TESTES.md` e um commit local por assunto.

| Fase | Entrega | Quem |
|---|---|---|
| 1. Esgoto jogável | EXP3 servidor (porta, missão, luta por sala, recompensa) e EXP4 cliente (faixa de dias, acampamento, escolha, "Viajando") | Sonnet ×2 |
| | EXP5: integração, playtest da fatia inteira no Studio, luta e resultado no tema Pergaminho | Fable |
| 2. Área de testes | TESTER1: sala fora do mapa, aberta pelo menu (só Studio e administradores). Estandes: criaturas e props com animações; gestos e efeitos de combate por técnica; sons e vozes com botão de tocar; arenas; peças da interface | Sonnet (dados e sala) + Sonnet (painel); Opus revisa |
| 3. Sons gratuitos | SOM1a: gerador local em Python puro (interface, moedas, passos, golpes, impactos, magia simples), 3 variações por som | Sonnet |
| | SOM1b: busca no Openverse (sem chave), só CC0/CC-BY, autor e licença em `SONS.md` | Haiku |
| | SOM1c: grupos de volume (voz > efeitos do jogador > efeitos inimigos > música > ambiente), música por estado (cidade, área, luta, chefe, vitória, derrota) | Sonnet |
| 4. Combate: apresentação (§5) | 4a criaturas com modelo na arena; 4c câmera; 4d leitura de acerto e erro; 4e HUD de luta no tema | Sonnet, um por vez |
| | 4b fila de apresentação (segurar PV e números até o impacto); 4f movimento casa a casa no cliente | Opus |
| | 4g efeitos com texturas; 4h armas modeladas | Sonnet |
| | 4i pesquisa: upload de modelo com rig pela Open Cloud; depois rig e ~12 animações | Opus pesquisa; Fable decide |
| 5. Modelos | MOD1: validar no Blender 5.4 os scripts de conferência do `WildCake/roblox-blender-modelling` (MIT) e ligar triângulos/UV/peças móveis em `tools/blender` | Sonnet |
| | MOD2: modelos das criaturas do esgoto que faltarem e cenário próprio do esgoto, com luz por arena | Sonnet; Fable confere no Studio |
| 6. Campanha | Interior da taverna e cena nova; lobby em modo expedição (`SalaView`); menu de status refeito; acampamento completo (dividir itens, inventário); evento do homem estranho; combates reduzidos na volta e na retomada; segunda área (floresta); lobby mostrando o que já aconteceu | Opus nos que cruzam servidor e cliente; Sonnet no resto |
| 7. Limpeza | Apagar o mundo aberto antigo (§3) num commit só de remoção; atualizar ARQUITETURA, MANUTENCAO e README | Sonnet remove, Opus revisa, Haiku documenta |

Ordem: 1 → 2 (o Pedro quer ver o jogo) → 3 e 4 em paralelo → 5 → 6 → 7. A fase
7 pode subir se o código morto atrapalhar. Dependem de resposta do Pedro: o
que acontece quando o prazo acaba, como funciona a exaustão e as imagens das
telas de acampamento e de escolhas (§1).

## 8. O que ler

Primeiro: este arquivo, `TAREFAS.md` (topo), `MANUTENCAO.md`, `ARQUITETURA.md`,
`COLABORACAO.md`. Por tema: `MESA.md`, `FIDELIDADE.md`, `CONTRATOS.md`,
`SALA.md`, `VISUAL.md`, `SONS.md`, `DUBLAGEM*.md`. Diários históricos, não
seguir como rumo: `TESTES.md`, `COORDENACAO.md`, `DISCUSSOES.md`, `ROADMAP.md`,
`ENTRADA.md`, `GAMIFICACAO.md`, `CODEX-AUTOMACAO.md`, `CONTINUACAO-G14.md`,
`EXPERIMENTO-ROBLOX-TS.md`, `ANIMACOES.md`.
