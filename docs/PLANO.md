# Plano Moshoku: do livro ao Roblox

Plano aprovado em 08/10/2026, redirecionado para jogo em §11. Direção atual confirmada por Pedro em 13/10/2026: mundo aberto com combate por turnos; uma região pequena primeiro. Estrutura de runs (roguelite cooperativo, história em árvore, encontro estilo Pokémon) em §12, de 14/10/2026. O mestre permanece uma possibilidade futura. Avatar Roblox inicialmente; criação visual própria depois. Reaproveitar assets gratuitos/código aberto adequados e manter documentação enxuta. Fases antigas abaixo são histórico; não representam ordem vigente nem prova de conclusão.

## 1. Visão

Um só sistema, dois modos que compartilham catálogo, personagens, comandos de combate e apresentação:

- **Mesa assistida (capacidade preservada; expansão futura):** o mestre organiza o encontro, aprova importações e resolve o que o livro deixa ao julgamento ou o que ainda não foi automatizado. Os jogadores usam as habilidades da própria ficha com um clique, e cada ação é animada.
- **RPG autoritativo (prioridade atual):** jogadores e NPCs usam o mesmo núcleo de execução, sem mestre humano, com as regras e o conteúdo que o servidor suporta explicitamente. Encontros do bestiário, progressão por PA e mundo para explorar.

**Modelo do jogo (aprovado pelo Pedro):** combate **por turnos**, como o livro, com **exploração livre** entre combates. Ação em tempo real mudaria controles, rede, IA e as próprias regras; fica como decisão futura e separada.

### O que "reaproveitar todo o código" quer dizer

O site é a referência do conteúdo e dos cálculos. Os **dados** são gerados automaticamente para o Roblox. As **funções** aproveitáveis são reaproveitadas direto ou portadas com testes diferenciais. Código de interface web e as simplificações do simulador de combate **não** viram regra definitiva. Preservamos o conhecimento, os dados e os cálculos; não prometemos executar cada linha de TypeScript literalmente no Roblox.

## 2. O que o site já tem

| No site | O que é | Uso no Roblox |
| --- | --- | --- |
| `src/data/trees/*`: 19 árvores, 343 habilidades (contagem do gerador; talentos e maestrias à parte) | custo de PA/PM/PT/PP, alcance, ações, dano, efeito em prosa, encantamento, pré-requisitos | catálogo, ficha, botões de ação |
| `races.ts`, `backgrounds.ts`, `condicoes.ts`, `weaponGroups.ts`, `shopItems.ts`, `compendioDeItens.ts` | raças, antecedentes, condições, armas e itens | ficha completa, inventário, loja do jogo |
| `bestiary.ts`, `preMadeMonsters.ts` | criaturas | NPCs da mesa e inimigos do jogo |
| `store/selectors.ts` | cálculo da ficha (PV, PM, CA, ataque, CD…) | valores calculados da ficha |
| `lib/combatSim.ts` | `acoesDe(ficha)` com mecânica estruturada (área, fogo, frio, Molhado, Dose…), RNG com semente e `SIMPLIFICACOES` declaradas | referência de execução **classificada**; sugestão de animação |
| `lib/combatTrace.ts`, `passosDoReplay.ts` | registro e passos de combate | inspiração para recibos com causalidade explícita |
| `data/midiaDeHabilidade.ts` | arte separada da regra | modelo do catálogo de apresentação |
| `lib/codigoDeMesa.ts` (adaptador v2; T23c) | envelope `mesa:2` do exportador `ficha-v2/1` | JSON copiado pelo botão e recebido pelo painel T28; valores aguardam aprovação do mestre |

## 3. Fonte de verdade e fidelidade

Cada regra automatizada no Roblox tem: identificador e referência à fonte, versão, entradas, resultados e limites, testes, casos não suportados e uma **classificação**:

- **livro:** reproduz a regra escrita;
- **adaptação explícita:** simplificação declarada, como as de `combatSim`;
- **arbitragem:** decisão do mestre, registrada no recibo.

As simplificações de `combatSim` são inventariadas **antes** de reaproveitar a resolução dele. Uma regra não fica correta só porque bate com o simulador. Habilidades não suportadas continuam consultáveis na mesa, com resolução manual explícita. A **matriz de fidelidade** (`docs/FIDELIDADE.md`) lista cada família de regra, a classificação e o estado dos testes.

## 4. Camadas de reaproveitamento

### A. Catálogo gerado

Geradores em `tools/` leem o site (só leitura) e produzem um catálogo Luau determinístico em `src/shared/Livro/`, com IDs estáveis, versão do formato, versão do conteúdo e manifesto das fontes. Inclui árvores e habilidades, raças, antecedentes, condições (já existe: `Condicoes.luau`), armas, itens e bestiário.

- Verificação: o teste **regenera** o catálogo e compara com o que está no projeto; contagem e hash sozinhos não bastam. Arquivos gerados são marcados "não edite".

### B. Ficha v2

O envelope da ficha separa três partes:

1. **Construção:** raça, antecedentes, árvores, ranks, habilidades e equipamentos **por ID**.
2. **Valores calculados:** atributos, perícias, máximos e demais resultados dos seletores do site.
3. **Estado de sessão:** recursos atuais (PV, PM, PT, PP), condições e efeitos temporários.

Os textos do livro vêm do catálogo, sem repetição no envelope. O envelope tem versão própria e limites de tamanho, quantidade e profundidade (o v1 tinha só 1000 caracteres). PA de aprimoramento nunca entra no orçamento de ações do turno.

- **Na mesa**, uma ficha importada é uma **proposta aprovada pelo mestre**.
- **No RPG**, construção e progressão são validadas pelo servidor; valores importados nunca concedem poder sozinhos.
- Cada campanha guarda a versão do catálogo que usa. Uma atualização migra ou recusa com explicação; mudar o livro não altera em silêncio uma campanha em andamento.

### C. Núcleo de execução (comum à mesa e ao jogo)

Jogador, mestre e IA produzem **intenções**; todas passam pelo mesmo serviço autoritativo:

`intenção → validação → proposta/decisão → resolução → alteração atômica → recibo → apresentação`

- O servidor confere identidade, controle do personagem, turno, modalidade da ação, aquisição da habilidade, recursos, restrições, alvos e geometria. O cliente nunca envia dano final, custo autorizado ou condição já aplicada.
- Cada pedido tem identificador. O servidor deduplica por solicitante + ID do pedido, vinculado ao conteúdo e com tempo de retenção definido; recompensas persistentes têm proteção que sobrevive à reconexão.
- Na mesa, ações suportadas resolvem sozinhas; com arbitragem, a proposta mostra os pontos pendentes e o mestre aprova. Depois de qualquer espera (decisão do mestre, serviço externo), o servidor revalida o estado: aprovar uma proposta antiga não gasta recurso nem acerta alvo de uma situação que mudou.
- A animação recebe o **recibo** depois da resolução. Ela nunca é necessária para validar dano, gastar recursos ou avançar o estado.

### D. Motor de regras em Luau

**Testes diferenciais** valem em qualquer caminho: uma ferramenta no site roda as funções originais com entradas fixas e grava entradas, saídas, versão da fonte e, quando preciso, a sequência de aleatoriedade, como fixtures compatíveis com o harness Luau. Com algoritmos equivalentes, usa-se RNG com semente; entre implementações diferentes, injeta-se a sequência de resultados.

A **implementação** se decide por experimento:

1. **Porte manual para Luau**, guiado pelos testes diferenciais.
2. **roblox-ts**: compila TypeScript para Luau e convive com módulos Luau existentes. Exige código sem APIs de navegador/Node e adiciona um compilador ao projeto.

O experimento usa módulos reais e suas dependências: um cálculo de ficha, uma resolução pequena com mudança de estado e o rolador que o site de fato usa. Mede o trabalho de adaptação, a depuração, a integração com o harness e o custo de manutenção quando o site muda. Passar todos os vetores prova paridade **nos casos cobertos**; a matriz de fidelidade declara o resto.

## 5. Arquitetura no Roblox

| Parte | Responsabilidade |
| --- | --- |
| Catálogo gerado | conteúdo estático, IDs, descrições, referências de origem |
| Núcleo puro de regras | cálculos, autorização de ações e resolução com RNG e contexto injetados; sem Instances nem rede |
| Serviço de personagens | construção, progressão, equipamentos, valores derivados |
| Serviço de encontros | turnos, ações, reações, concentração, condições, efeitos persistentes |
| Serviço de geometria | alcance, áreas, visibilidade, ocupação; adaptadores para grade (mesa) e mundo (jogo) |
| Despachante de comandos | permissões, frequência, deduplicação, transações (já existe na mesa: `dispatch`) |
| Controladores jogador/mestre/IA | produzem intenções pela mesma interface; não aplicam regras |
| Projeções por observador | decidem que fichas, recibos, registros e efeitos cada jogador recebe (já existe: `canSee`, névoa) |
| Apresentação no cliente | interface, miniaturas, animações, som, câmera |
| Persistência | personagens e campanhas com versões, migrações e proteção contra conflitos |

- **IA de NPC:** conhece só a percepção autorizada do NPC e usa apenas ações legais. Perfis simples: agressivo, defensivo, suporte e fuga. O "maior dano esperado" do simulador pode ser uma ferramenta, não a estratégia universal. Navegação e tática ficam separadas da resolução.
- **Persistência de personagem:** separada dos espaços de campanha, com proteção contra sessões simultâneas e gravação de estado antigo na troca de servidor. Itens e recompensas têm identificador próprio, para não duplicar.
- **Geometria:** antes de validar alcance automaticamente, decidir distância, diagonais, ocupação, cobertura, linha de visão, altura e formas de área. O tamanho da casa (hoje 1,5 m) é uma adaptação provisória; a relação com as medidas do livro será decidida e registrada.

## 6. Ataques animados

**Princípio:** apresentação não é regra. Cada habilidade tem uma referência visual estável num catálogo separado, como `midiaDeHabilidade` no site.

- **Receitas:** o arquétipo (projétil, raio, área, corpo a corpo, disparo de arma, cura, aura, barreira, invocação, condição) e o tema (fogo, gelo/água, vento, terra, cura, veneno, som, sombra, espada, punho) podem ser **sugeridos** a partir da árvore, da arma e das flags da `Acao`. O mapeamento final é revisado: Brasa e Bola de Fogo são ambas mágicas à distância, mas não são a mesma animação, e Fagulha nem causa dano.
- **Etapas de uma receita:** preparação, lançamento, trajetória, impacto, defesa, falha, interrupção e efeito persistente. Uma ação com vários alvos tem uma única identidade causal.
- **Reserva:** habilidade sem receita própria recebe uma animação padrão discreta. Isso garante apresentação para todas, não exclusividade.
- **Estado persistente:** efeitos duradouros (barreira, chamas) são reconstruídos a partir do estado, não só de eventos, para quem entra depois.
- **Audiência:** o efeito segue a mesma regra da ficha e do recibo. Habilidade de ficha oculta não revela posição, alvo nem som a quem não pode ver.
- **Corpo do personagem:** um adaptador de rig começa num rig controlado; o suporte aos avatares dos jogadores é verificado à parte. O `Animator` sobrescreve `Motor6D.Transform`, então animação procedural nas juntas precisa de composição deliberada. Animações feitas no Animation Editor ficam na conta do Pedro.
- **Orçamento e acessibilidade:** limite de partículas, luzes, duração e simultaneidade por efeito. A qualidade reduzida mantém alvo, trajetória e resultado e corta a decoração. O jogador pode reduzir tremor, flashes e intensidade. Nada cobre os controles no celular.
- **Como as IAs criam:** pelo Studio MCP, escrevem a receita, dão Play, disparam a habilidade e capturam uma sequência temporal com medição de desempenho. O aceite exige execução e medição, não só um print bonito. Assets externos (modelos, sons, animações enviadas) são decisão posterior, com origem e direitos registrados.

## 7. Verificação

1. **Dados:** geração determinística, referências válidas, detecção de mudança (regenerar e comparar).
2. **Regras:** testes diferenciais, casos de fronteira e invariantes independentes do simulador.
3. **Integração:** vários clientes, permissões, ações duplicadas, decisões atrasadas, reconexão, persistência. Já existe a base: `tools/testar.ps1`, playtests MCP, `MesaDebug` só no Studio.
4. **Apresentação:** Studio, celular real, legibilidade, acessibilidade, desempenho.

## 8. Fases

| Fase | Entrega | Pronto quando |
| --- | --- | --- |
| **F0 Consolidar a mesa** | M1–M6 integrados; `MESA.md` atualizado (inventário real: entregue, verificado, pendente) | testes e playtests verdes; documentação sem itens obsoletos |
| **F1 Contratos e experimento** | IDs estáveis, envelopes versionados, matriz de fidelidade inicial, modelo por turnos decidido, experimento Luau × roblox-ts com módulos reais | decisão registrada com medições |
| **F2 Ficha e catálogo consultivo** | catálogo gerado; importação da ficha v2 aprovada pelo mestre; ficha completa e todas as habilidades consultáveis, inclusive as não automatizadas | ficha de NPCs reais idêntica ao site; regeneração sem diferença |
| **F3 Fatia de combate assistido** | ataque de arma, Brasa e Bola de Fogo, uma cura, uma reação e uma conjuração interrompível: alvos, recursos, recibos, poucas animações bem acabadas | combate com fichas reais e vários clientes, sem cálculo manual nos casos suportados e sem aplicação duplicada |
| **F4 Ampliar a mesa** | automatizar por famílias de regra; ampliar animações a partir dos mesmos recibos; arbitragem sempre disponível | matriz de fidelidade cresce com testes |
| **F5 RPG mínimo persistente** | personagem validado pelo servidor, progressão, equipamentos, IA, encontro, uma pequena região | uma sessão completa sem mestre, sobrevivendo à troca de servidor |
| **F6 Expandir o mundo** | regiões, missões, conteúdo; publicação | decisão do Pedro |

### Pedidos do Pedro para a jogabilidade (08/10/2026; decisões de gamificação delegadas ao Claude e ao Codex)

- **O avatar é a ficha:** a ficha de jogador com dono presente é o próprio avatar do Roblox no tabuleiro; ele anda até a casa quando a ficha se move. NPCs continuam miniaturas, porque o avatar replica para todos e não pode ser segredo. Entregue antes da F3.
- **Menu de ação no turno (F3):** na vez dele, o jogador escolhe entre **Mover**, **Atacar** (arma), **Habilidade** (do catálogo, com custo e alcance), **Item**, **Defender/Preparar** e **Encerrar turno**, como no livro. O alcance aparece no tabuleiro, o alvo é escolhido com clique e o servidor resolve e anima. Gamificar = deixar claro o que dá para fazer agora (ações e recursos restantes, alvos válidos destacados), sem mudar a regra; o que mudar vira adaptação registrada em `FIDELIDADE.md`.

Assinaturas visuais por árvore não bloqueiam o jogo mínimo: começam poucas e bem acabadas e crescem com o conteúdo jogável.

**O compromisso verificável do plano:** uma regra rastreável, uma ficha legítima, uma ação aplicada uma única vez, uma animação que não vaza informação e uma sessão que sobrevive à troca de servidor.

## 9. Riscos

- **Divergência entre site e Roblox:** catálogo sempre gerado e comparado; regras com testes diferenciais e classificação.
- **Prosa que máquina não executa:** na mesa, arbitragem; no jogo, só o que tiver mecânica estruturada. Estruturar mais regras é trabalho no site, com o livro na frente.
- **Mudanças no site:** autorização **por finalidade**, e não por nome de arquivo: adaptadores e testes de exportação que não alteram cálculos do livro, dados de regra nem interface.
- **Legitimidade de fichas:** aprovação do mestre na mesa; validação do servidor no jogo.
- **Desempenho e celular:** orçamento por efeito, qualidade reduzida, medição antes de otimizar.
- **Assets e moderação:** começar procedural; assets enviados ficam na conta do Pedro, com origem registrada.

## 10. Decisões do Pedro

**Decidido em 08/10/2026:** o Pedro aprovou tudo:
- plano e ordem das fases;
- jogo **por turnos** com exploração livre;
- autorização **por finalidade** para adaptadores e testes de exportação no site;
- na mesa, ações suportadas resolvem sozinhas e o mestre arbitra o pendente;
- commit do botão no site, feito em `5be6375` (sem push).

Itens que estavam em aberto:

1. Aprovar o plano e a ordem das fases.
2. Modelo do jogo: por turnos com exploração livre (recomendado) ou ação em tempo real?
3. Autorização por finalidade para adaptadores e testes de exportação no site?
4. Na mesa, ações suportadas resolvem sozinhas e o mestre só arbitra o que estiver pendente (recomendado), ou o mestre aprova toda ação?
5. Commit do botão "Copiar para a mesa Roblox" no site.

## 11. Mudança de rumo: primeiro o jogo (09/10/2026)

O Pedro testou a mesa e decidiu: **por enquanto, o produto é um RPG por turnos jogável**, não uma mesa no estilo Owlbear. A F5, que era "depois", passa a ser o alvo. As fases F3/F4 da mesa assistida saem da frente. O núcleo continua o mesmo, só muda quem produz as intenções.

**Decisões do Pedro:**
- **Personagem criado no jogo.** O jogador escolhe raça, antecedente e árvore inicial dentro do Roblox, a partir do catálogo, e o servidor calcula tudo. Importar a ficha do site pode vir depois, mas só como ponto de partida: o servidor recalcula, e os números do navegador não valem.
- **Grupo cooperativo.** Até 4 jogadores no mesmo servidor lutam juntos, cada um no seu turno. Sozinho também funciona.
- **Mestre opcional.** O jogo roda sem mestre. Um mestre (os papéis de `MesaRoles`) pode entrar para controlar inimigos ou arbitrar, mas nunca é necessário. As ferramentas atuais da mesa ficam como modo do mestre.
- **Gamificação delegada** ao Claude e ao Codex (já valia). O que mudar em relação ao livro vira adaptação em `FIDELIDADE.md`.

**O que muda de fase:**

| Fase | Entrega | Pronto quando |
| --- | --- | --- |
| **J0 Contratos do jogo** | Estado do encontro, protocolo do menu de ação, recibos, perfis de IA, geometria da grade e criação de personagem. Revisados pelas duas IAs | Contratos em `docs/JOGO.md` aceitos pelas duas IAs |
| **J1 Motor de personagem** | Porte para Luau dos seletores necessários a um personagem inicial (atributos finais, PV/PM/PT/PP, CA, deslocamento, iniciativa, perícias), com testes diferenciais contra `selectors.ts`. Tela de criação no jogo | Personagens criados no Roblox têm os mesmos números que o site com as mesmas escolhas |
| **J2 Fatia de combate** | Encontro na grade com o grupo e 2–3 criaturas do bestiário com IA simples. Menu Mover / Atacar / Habilidade / Item / Defender / Encerrar. Ataque de arma, 2–3 habilidades do catálogo (ex.: Brasa, Bola de Fogo, uma cura), um item. Recibos e animações básicas. Mestre opcional assume inimigos | Uma luta completa, do início ao fim, com 1 e com 2 clientes, sem cálculo manual e sem ação aplicada duas vezes |
| **J3 Progressão e persistência** | XP/PA, ranks, compra de habilidades, equipamento; personagem salvo por jogador, separado das campanhas da mesa | Uma sessão completa sobrevive à troca de servidor |
| **J4 Exploração** | Uma pequena região livre entre combates, encontros disparados no mundo, descanso | Ir de um encontro a outro andando |
| **J5 Conteúdo** | Mais árvores, criaturas, regiões, missões; publicação | Decisão do Pedro |

**Reaproveitamento:** o site já tem um simulador de combate automático:
- `combatSim.ts`, com 3.300 linhas;
- `combatWeapon`, `combatReactions` e `combatSummons`;
- `fichaComoCriatura`.

Além disso, `selectors.ts` tem 53 funções exportadas. A regra de §3 continua valendo: o simulador é **fonte de conhecimento e de vetores de teste**, não motor definitivo. As 24 `SIMPLIFICACOES` dele não viram regra sem passar por `FIDELIDADE.md`. O porte segue a decisão da F1: manual para Luau, com testes diferenciais.

**Revisão do Codex (CLI), rodada 8: aceita a direção e a divisão, com 8 exigências, todas aceitas pelo Claude:**
1. J0 fecha também o **escopo jogável**: quais raças, antecedentes, árvores, equipamento inicial e habilidades estão suportados. Estar no catálogo não significa ser executável.
2. J1 **valida escolhas**, não só números: orçamento de criação, pré-requisitos, escolhas pendentes e combinações inválidas recusadas. Os diferenciais usam construções sintéticas válidas e casos de fronteira.
3. J2 é testada com **4 clientes**: morte, derrota, abandono, desconexão, AFK e retorno. Decisão de Pedro (14/10/2026): turno de jogador expira após 60 s e encerra automaticamente, inclusive durante desconexão; ações não reiniciam o prazo. Sem participantes conectados por 60 s, o encontro é limpo; reconexão cancela esse prazo. A desistência voluntária adapta o contrato legado: a ficha vai a 0 PV/derrotada e o combate prossegue para os demais, sem custo de Ação ou recompensa. Specs cobrem validação, idempotência, recibo ao grupo e derrota do último jogador; ainda faltam quatro clientes e o ciclo J2 completo.
4. J2 já traz **recuperação entre encontros** e reconexão mínima. Em J3, "sobreviver à troca de servidor" inclui conflito entre sessões e recompensas idempotentes.
5. Os vetores do `combatSim` são **classificados por comportamento** (regra fiel, adaptação, heurística de IA), e há invariantes independentes do simulador.
6. Mestre e IA têm **posse exclusiva por inimigo**, com versão. Intenção antiga é recusada, e a desconexão do mestre devolve o controle. Arbitragem é um comando auditado e revalidado.
7. **Mover, Defender e Item** precisam de custo, alcance, duração, gatilho e fonte definidos em J0 antes de programar. O que for adaptação vai para `FIDELIDADE.md`. A geometria cobre caminho, ocupação, diagonais, linha de visão e aliados bloqueando.
8. Criação e progressão mostram as opções ainda não suportadas como **indisponíveis**, sem escondê-las.

**O que fica da mesa e serve ao jogo:**
- servidor autoritativo e `dispatch`;
- tabuleiro e grade;
- dados;
- condições;
- avatar como ficha;
- catálogo gerado;
- ficha v2 e aba Ficha (consulta);
- persistência com revisão;
- testes MCP.

**O que fica pausado:** novas funções só da mesa assistida.

## 12. Estrutura do jogo: runs em mundo aberto (Pedro, 14/10/2026)

Definida pelo Pedro em perguntas e respostas com o Claude. Onde conflitar, substitui §11, a regra "1 árvore inicial exceto Vendaval/Punho de Fogo, utilidades fora" e o acordo D-J4-1 (encontro por prompt em marco fixo). Revisão do Codex pendente (DISCUSSOES D-R-1).

- **Formato:** roguelite cooperativo. Cada run é do grupo (1–4 jogadores), num servidor próprio, dura 1–2 h e salva no meio. Acaba com a queda do grupo inteiro ou ao chegar a um final. A conta guarda desbloqueios entre runs.
- **História em árvore** (referência: Average Campaign, do Roblox): escolhas com lore levam a luta, evento ou recompensa; galhos levam a folhas (finais). **Esqueleto fixo** feito à mão (regiões, galhos, finais, identidade: a Cidade Santa tende a ter mestres de Cura e Desintoxicação) e **recheio sorteado** por run (eventos, inimigos, prêmios, treinadores). A run tem um **objetivo com prazo**; perder o prazo não encerra a run, abre objetivos alternativos com consequências.
- **Mundo (W1b, Pedro, 17/10):** regiões conectadas a pé; Ruínas pela PASSAGEM W1a. Superados painel de viagem, voto de destino, teleporte regional e custos de viagem/cavalo. Eventos F8 tornam-se eventos de caminho na primeira entrada de cada trecho por run, conservando escolhas, testes e consequências. Atalho VIAGEM removido; mapa fica para outra entrega.
- **Encontro estilo Pokémon:** inimigos visíveis patrulham com cone de visão e perseguem quem veem; chegar por trás sem ser visto dá surpresa. Perto o bastante, a câmera vai para cima e **a grade nasce ali mesmo**, visível de longe. Quem está perto entra; quem está longe entra ao pisar na grade, no começo da rodada seguinte. Fuga pela borda com teste (ex.: Atletismo contra o inimigo mais rápido); falhou, perde o turno; fugiu, o inimigo volta a patrulhar.
- **Decisões do grupo:** votação, empate no dado. Quem tem Navegação e Liderança (rank Explorador) vota com peso 2, e o grupo nunca é emboscado (regra do livro ao liderar a marcha), vê antes de votar o que é característico da próxima região, com probabilidade e sem itens/eventos exatos ("99% de ter mestre de desintoxicação"), tem eventos melhores na viagem e bônus de lugar por região.
- **Personagem, a cada run:**
  - **Do zero:** raça e antecedente; a run sorteia uma oferta de árvores (2–3 de corpo, 2 de magia, 1 de utilidade) com chance ponderada pela força (mais forte, mais rara; análise do Claude, registrada em `FIDELIDADE.md`). Escolhe uma na criação ou depois com um treinador; quem fica sem árvore começa com mais PA.
  - **Pronto:** mais PA e build definida, com **defeitos** sorteados (Zangado, Manco, Burro…). Cada defeito usa mecânica do livro (Desvantagem em testes, deslocamento menor, como as "Maldições" dos antecedentes) e pode vetar ou piorar opções de eventos. Dá **mais** recompensa no fim. Adaptação registrada em `FIDELIDADE.md`.
  - **Vila:** 3–4 treinadores num sorteio **separado** da oferta da criação (ex.: lutador, mago de fogo, curandeiro, bardo) e chance de um extra na taverna. As árvores de utilidade entram.
- **Prazo em tempo real (W1b):** 1 dia = 8 minutos, constante em dados, manhã inicial às 06h. Servidor controla e salva a fração do dia; combate pausa. Descanso longo e provação aprovada saltam à manhã seguinte; curto soma 2h. Eventos ainda aplicam seus custos/consequências F8. Superado o avanço só por viagem/decisão.
- **Caçadas e patrulhas (W1b):** quadro na praça com 3 ofertas curtas repetíveis; ouro e PA de aprimoramento. Patrulhas fáceis nos arredores, lobos/aranhas/urso na floresta, bandidos na passagem, goblins/golem menor nas Ruínas; reaparecem após tempo de run. Reutilizar R2/J2, cone/perseguição/surpresa, câmera superior e grade local; um encontro ativo por servidor.
- **Entre runs:** moeda da conta (desbloqueia treinadores no sorteio, raças, itens iniciais), conquistas específicas, códice (lore, criaturas, finais) e cosméticos.
- **Grupo e save:** servidor só do grupo; um lobby pode reunir jogadores antes. Se alguém faltar, a run continua e o personagem dele espera no acampamento, sem o PA do período.
- **Mestre:** fora por ora; o núcleo continua permitindo controlar e criar monstros no futuro.
- **Primeira versão jogável atualizada:** vila → mestre/caçadas → regiões a pé com eventos e patrulhas → chefe → retorno a pé/final. A viagem por painel deste roteiro está superada. Abertura e treinadores atuais: P2 em [TAREFAS](TAREFAS.md); verificação W1b em [TESTES](TESTES.md).
- **Em aberto (decisão técnica/balanceamento das IAs):** custo exato em dias de cada ação, quantos defeitos e quanto PA extra; grade em terreno irregular (árvore/rocha viram casa bloqueada ou cobertura?); como o ausente recupera o atraso.

## Histórico da discussão

- **Codex → rascunho do Claude**, aceito pelo Claude:
  - "zero regra duplicada" era falso;
  - `combatSim` não é motor definitivo, e daí veio a classificação livro/adaptação/arbitragem;
  - `acoesDe` não é catálogo completo, e faltavam IDs estáveis;
  - o envelope v1 não comporta a ficha v2;
  - importar não prova legitimidade;
  - recursos e estados separados;
  - a geometria precisa ser decidida antes;
  - animação deduzida é só sugestão;
  - `Animator` × `Motor6D`;
  - fatia jogável antes de ampliar;
  - testes diferenciais × roblox-ts são eixos diferentes e se decidem por experimento;
  - autorização por finalidade.
- **Claude contestou** que o painel M6 ainda estivesse sem integração e testes. A primeira versão já estava instalada, com 13/13 cliques reais. A revisão V1/V2 também foi instalada e verificada: cliques reais com 0 falhas e print conferido. O Codex aceitou. Ele apontou com razão que `MESA.md` estava desatualizado; corrigido.
- **Conferência final do Codex:** aprovou, com três correções aplicadas: deduplicação explícita no servidor, casa de 1,5 m como adaptação provisória e status do painel M6.
