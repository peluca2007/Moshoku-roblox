# Patch notes

Notas por versão, em linguagem de jogador, com uma seção técnica curta no fim de cada uma. Versões ainda não publicadas: tudo roda no Studio (Play), sem publicação.

## 0.2.0 — Vila viva, Ruínas do Vale e a run completa (16/10/2026)

### Novidades
- **Ruínas do Vale.** Nova região, alcançada pela viagem da expedição: um arco rachado com runa brilhante, alamedas de colunas e muros caídos, árvores secas, lápides e, no fim do caminho, a praça circular do guardião com o altar do Selo e fiapos de luz violeta no ar. O céu e a névoa mudam de clima quando você chega.
- **Treinadores na vila.** Cada expedição sorteia três treinadores (por exemplo, Bardo, Mago de Fogo e Tático). Quem começa "sem árvore" aprende uma árvore com um deles gastando PA e dias do prazo. A compra é confirmada pelo servidor.
- **Painel da viagem.** Mostra os avatares do grupo, a rota (de onde para onde), os dias restantes, o evento da estrada, as opções com vetos e quantos votos cada uma tem.
- **Tela da conta.** Entre as expedições, veja sua moeda, conquistas e códice, e compre desbloqueios.
- **Defeitos que importam.** Personagens prontos com *Manco* andam e fogem menos; com *Frágil* sofrem Desvantagem para resistir ao Sopro de Poeira.
- **Ajuda dentro do jogo.** Botão **?** com quatro abas (primeiros passos, explorar e lutar, vila, controles) e uma dica na primeira abertura.
- **Tela de carregamento** com o título do jogo e dicas, enquanto o mundo é montado.
- **Patrulha e arena nas Ruínas.** Um goblin vigia o caminho e, se vê você, a luta nasce ali mesmo (grade, turnos, fuga pela borda). O guardião agora enfrenta o grupo na praça da câmara, com as colunas e o altar como obstáculos.
- **Conta que vale na run.** Raças raras desbloqueadas ficam disponíveis na criação (as demais seguem bloqueadas, com mensagem clara) e a Poção Menor comprada entra no kit inicial, uma vez por run. Cosméticos são só registrados por enquanto.
- **Eventos de viagem com teste.** A estrada agora traz 14 eventos (10 novos, provisórios): muitas opções pedem um teste de perícia contra uma CD, rolado pelo servidor com o bônus da ficha; defeitos como *Zangado* (Persuasão) ou *Desastrado* (Furtividade) dão Desvantagem. O resultado (perícia, dados, CD, sucesso ou falha) aparece no painel da viagem e pode custar ou poupar dias, mexer na caixa da viagem ou deixar marcas na história.
- **Treinadores com identidade.** Cada treinador veste a cor da sua árvore e tem o selo em kanji flutuando sobre a cabeça.
- **Carregamento bem mais rápido.** As malhas dos modelos passaram a ser criadas em paralelo (de cerca de 15 s para cerca de 1 s no Studio).
- **Acampamento renovado.** Tendas, tripé de caldeirão sobre a fogueira, fardos de feno, barris, placa de direção, vegetação, pedras e toras espalhadas pelo campo, e manchas de chão.

### Visual
- **Luz por zona:** noite na sala da Mesa, fim de tarde dourado na vila, crepúsculo verde e sombrio na Floresta Sombria, névoa violeta nas Ruínas; as transições são suaves.
- **Vila nova:** taverna de dois andares com placa e lanternas, forja aberta com forno brilhando e chaminé alta, dojo de dois telhados com lanternas de pedra, casas de campo ladeando a estrada de entrada, estandes de mercado com toldo listrado, cercas e barris. As chaminés soltam fumaça.
- **Floresta mais fechada:** 93 pinheiros (eram 38), arbustos, pedras com musgo, toras e tocos, chão e trilha mais claros, vaga-lumes e poeira dourada na vila. Carvalhos novos substituem os de tronco torto.
- **NPCs vivos:** ficam em pose natural e acenam quando você se aproxima.

### Jogabilidade e regras
- A viagem para as Ruínas teleporta o grupo; a passagem da câmara abre por escolha da história (1 dia) e o guardião é um bando de goblins.
- A visão da run agora informa origem/destino da viagem e a contagem de votos por opção (sem revelar quem votou em quê).

### Celular
- O painel RUN cabe na tela; os botões de atalho do canto (RUN, CONTA, VIAGEM, ?) somem enquanto um painel grande está aberto, para não cobrir o botão Fechar; os botões das abas da ajuda ficam dentro do painel. O painel da viagem fecha sozinho quando o evento é resolvido.

### Correções
- O céu e a luz da vila deixaram de herdar a noite da sala da Mesa.
- O NPC não fica mais de braços abertos (as peças ancoradas bloqueavam a animação).
- A estrela decorativa da tela de carregamento não aparece mais como quadrado.

### Limitações conhecidas
- Cosméticos da conta não têm efeito visual ainda.
- Só *Manco* e *Frágil* têm efeito em combate; os outros defeitos atuam nos testes dos eventos de viagem e vetam opções.
- Prédios são só fachada; sem animações de personagem próprias além de idle e aceno.
- Não testado em celular real, com dois jogadores reais, nem no jogo publicado (permissões dos assets de malha, DataStore).

### Técnico
- Pipeline automática de modelos: `python tools/gerar_modelo.py <modelo> <NomeModulo>` gera no Blender (sem janela), envia pela Open Cloud, recolore no Studio e grava dados em `Mundo/Modelos`. Detalhes em [MANUTENCAO](MANUTENCAO.md).
- Novos módulos puros e validados: `AmbientePerfis`, `PropsLayout`, `ChaoLayout`, `RuinasLayout`. Construtores: `Mundo/{Props,Ruinas,Ambientacao}`. Cliente: `AmbienteMundo`, `Carregamento`, `ContaView`, `ViagemView`, `AjudaView`, `TreinadorView`.
- `TAREFAS.md` foi reescrito (curto); o histórico integral está em `docs/historico/`.
- Testes: suíte local `RESULTADO: tudo ok`; Studio TestRunner 1.759/0 na última rodada completa. Evidências em [TESTES](TESTES.md).

## 0.1.0 — Primeira versão jogável (14–15/10/2026)

Mundo aberto com região inicial, vila e Floresta Sombria; combate por turnos autônomo no local (grade que nasce, patrulhas, surpresa, fuga, entrada tardia); criação de personagem pessoal; loja, missões e dojo; ciclo da run (modos de criação, oferta de árvores, votação, eventos de viagem, prazo, chefes, final, conta). Detalhes no histórico em `docs/historico/`.
