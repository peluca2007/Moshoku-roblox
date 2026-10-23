> Atualização11/10:47vozes enviadas, IDs registrados e gatilhos locais ligados/testados; permissão persistente da experiência pendente de confirmação específica. Detalhes e limites em assets/vozes-npcs/README.md e docs/TESTES.md. Textos abaixo sobre ausência de IDs descrevem a preparação anterior.

# Dublagem — NPCs, criaturas e bosses

**Gravações recebidas (11/10/2026):**47arquivos em `audios/`; goblin/lobo/bandido/Treant completos. Pedro autorizou reaproveitar o lobo nos nove sons do urso. As cópias WAV corrigidas, durações reais, CSV de importação e mapeamento estão em [assets/vozes-npcs](../assets/vozes-npcs/README.md). As56linhas abaixo permanecem como roteiro/direção de voz; não exigem56gravações diferentes. Áudios ainda sem IDs/gatilhos no Roblox.

Roteiro para o Pedro gravar. Segue o formato de [DUBLAGEM.md](DUBLAGEM.md), com falas originais e vocalizações para os inimigos dos encontros atuais. Este arquivo é editado à mão e não é sobrescrito pelo gerador de magias.

**O roteiro tem 56 entradas de voz:** Goblin Batedor (12), Lobo Cinzento (10), Bandido de Estrada (10), Urso de Presas Vermelhas (9) e Treant Ancião (15). A entrega atual cobre tudo com **47 gravações e nove reaproveitamentos**; não é preciso gravar o urso agora. O Treant é o chefe atual; o urso é o inimigo principal do desafio Presas vermelhas.

## Como usar o roteiro

1. Grave uma linha por arquivo, usando exatamente o nome da primeira coluna. As variantes `01` e `02` são gravações separadas.
2. Use **Alvo** como referência e **Máx** como limite de edição. Os tempos são estimativas para orientar a gravação, não uma sincronização já medida no jogo. Não acelere uma fala que ficou longa: faça outra tomada com uma pausa menor.
3. Grave três tomadas de cada linha: natural, mais intensa e mais contida. Entregue a escolhida com o nome da tabela; guarde as demais em uma pasta `tomadas` com sufixos `_toma-01`, `_toma-02` e `_toma-03`.
4. Mantenha uma pequena pausa entre tomadas. Depois corte o silêncio excedente do começo e do fim, preservando a respiração que fizer parte da atuação.
5. Siga o padrão do roteiro principal: mono, 44,1 kHz, pico por volta de −3 dB, sem música, reverb ou efeitos impressos na voz. Guarde também o original em WAV, se puder; as tabelas usam `.ogg` para a entrega editada.
6. Leia apenas a coluna **Fala / som**. As instruções entre colchetes indicam o som a interpretar; não são palavras para dizer. Não precisa imitar literalmente a escrita de um rosnado.

Para as criaturas, procure timbre e intenção com a voz confortável: o peso pode ser acrescentado na edição. Não precisa forçar a garganta para conseguir a voz grave do Treant ou do urso.

**Situação no jogo:** este é um roteiro de gravação. “Contexto previsto” indica onde cada áudio poderá ser usado; as gravações recebidas e os reusos estão registrados no pacote acima, mas ainda não há IDs ou gatilhos ligados ao jogo. Os nomes organizam a entrega e o manifesto, mas ainda não são chaves registradas em `Dublagem.luau`. O gerador atual não lê este arquivo; colocar essas novas chaves em `ids.json` sozinho não as integra.

## Goblin Batedor

**Voz:** pequena, nasal e rápida; traiçoeiro quando está em vantagem, assustado quando apanha. Um pouco engraçado pela confiança exagerada, sem virar uma voz impossível de entender. As falas são uma proposta de atuação para o jogo, não texto do livro.

| Arquivo | Contexto previsto | Fala / som | Interpretação | Alvo (s) | Máx (s) |
| --- | --- | --- | --- | --- | --- |
| `npc__goblin-batedor__avistar__01.ogg` | Entrada no encontro | Olha só… visita! | Curioso, sorriso malicioso no fim. | 1,5 | 2,2 |
| `npc__goblin-batedor__avistar__02.ogg` | Entrada alternativa | Esse aí é meu! | Apressado, disputando a presa. | 1,3 | 1,9 |
| `npc__goblin-batedor__ataque__01.ogg` | Preparação de golpe | Pega essa! | Curto, com esforço no final. | 0,8 | 1,2 |
| `npc__goblin-batedor__ataque__02.ogg` | Golpe alternativo | [Grito curto: “Hiah!”] | Mais esforço do que palavras. | 0,5 | 0,9 |
| `npc__goblin-batedor__acerto__01.ogg` | Após acerto confirmado | Heh! Peguei! | Satisfeito, uma risada curta. | 1,0 | 1,5 |
| `npc__goblin-batedor__erro__01.ogg` | Após errar | Fica parado! | Irritado porque a presa escapou. | 1,0 | 1,5 |
| `npc__goblin-batedor__dor-leve__01.ogg` | Dano comum | Ai! | Agudo e seco. | 0,4 | 0,8 |
| `npc__goblin-batedor__dor-leve__02.ogg` | Dano comum alternativo | [Resmungo: “Ngh!”] | Som preso, contrariado. | 0,4 | 0,8 |
| `npc__goblin-batedor__dor-forte__01.ogg` | Dano intenso | Aaaai! | Surpresa que vira medo. | 0,8 | 1,3 |
| `npc__goblin-batedor__provocacao__01.ogg` | Variação ocasional entre ações | Só isso? Hehehe! | Valentia falsa, risada de canto. | 1,6 | 2,3 |
| `npc__goblin-batedor__pouca-vida__01.ogg` | Reação ocasional com pouco PV | Ei… não vale! | A confiança desapareceu. | 1,4 | 2,1 |
| `npc__goblin-batedor__derrota__01.ogg` | Ao ser derrotado | [Gemido curto que perde a força] | Começa agudo, termina sem ar. | 1,1 | 1,7 |

## Lobo Cinzento

**Voz:** animal atento, ágil, de matilha. Só vocalizações, sem frases humanas. Diferencie ameaça, esforço e dor; o lobo não precisa uivar a cada mordida. Grave os sons limpos, sem imitar passos ou o impacto dos dentes.

| Arquivo | Contexto previsto | Fala / som | Interpretação | Alvo (s) | Máx (s) |
| --- | --- | --- | --- | --- | --- |
| `npc__lobo-cinzento__alerta__01.ogg` | Ao perceber os jogadores | [Rosnado baixo e curto] | Alerta, ainda contido. | 0,9 | 1,4 |
| `npc__lobo-cinzento__ameaca__01.ogg` | Antes de avançar | [Rosnado crescente, dentes expostos] | Começa baixo e termina mais áspero. | 1,2 | 1,8 |
| `npc__lobo-cinzento__ataque__01.ogg` | Mordida | [Latido rouco com rosnado curto] | Um impulso seco. | 0,5 | 0,9 |
| `npc__lobo-cinzento__ataque__02.ogg` | Mordida alternativa | [Expiração agressiva: “Hrrá!”] | Esforço breve, animal. | 0,5 | 0,9 |
| `npc__lobo-cinzento__dor-leve__01.ogg` | Dano comum | [Ganido rápido] | Surpresa, sem prolongar. | 0,4 | 0,8 |
| `npc__lobo-cinzento__dor-leve__02.ogg` | Dano comum alternativo | [Ganido mais baixo, seguido de ar] | Contido e diferente da primeira tomada. | 0,6 | 1,0 |
| `npc__lobo-cinzento__dor-forte__01.ogg` | Dano intenso | [Ganido que cai de tom] | Forte no início, curto no fim. | 0,9 | 1,4 |
| `npc__lobo-cinzento__uivo__01.ogg` | Entrada ou chamada ocasional | [Uivo único: “Auuuu…”] | Sobe, sustenta brevemente e desce. | 2,0 | 2,8 |
| `npc__lobo-cinzento__pouca-vida__01.ogg` | Reação ocasional com pouco PV | [Respiração curta com rosnado fraco] | Ainda ameaça, mas está cansado. | 1,1 | 1,7 |
| `npc__lobo-cinzento__derrota__01.ogg` | Ao ser derrotado | [Ganido baixo seguido de expiração] | Perde a força, sem exagero dramático. | 1,1 | 1,7 |

O uivo é apenas uma sugestão sonora: não representa uma habilidade de invocar reforços ou um bônus de matilha.

## Bandido de Estrada

**Voz:** humano, oportunista, acostumado a intimidar viajantes. Mais seco e natural que o goblin; fala com confiança, sem precisar gritar o tempo todo.

| Arquivo | Contexto previsto | Fala / som | Interpretação | Alvo (s) | Máx (s) |
| --- | --- | --- | --- | --- | --- |
| `npc__bandido-de-estrada__avistar__01.ogg` | Entrada no encontro | Parados aí. | Ordem baixa e firme. | 1,0 | 1,5 |
| `npc__bandido-de-estrada__avistar__02.ogg` | Entrada alternativa | Escolheram o caminho errado. | Calmo, ameaçador. | 1,8 | 2,5 |
| `npc__bandido-de-estrada__ataque__01.ogg` | Preparação de golpe | Agora! | Explosão breve. | 0,6 | 1,0 |
| `npc__bandido-de-estrada__ataque__02.ogg` | Golpe alternativo | [Esforço seco: “Hah!”] | Expiração de quem golpeia. | 0,4 | 0,8 |
| `npc__bandido-de-estrada__acerto__01.ogg` | Após acerto confirmado | Baixou a guarda. | Satisfeito, sem comemoração longa. | 1,1 | 1,6 |
| `npc__bandido-de-estrada__erro__01.ogg` | Após errar | Droga… | Irritado, entre dentes. | 0,6 | 1,0 |
| `npc__bandido-de-estrada__dor-leve__01.ogg` | Dano comum | [Gemido curto: “Argh!”] | Grave natural, reação rápida. | 0,5 | 0,9 |
| `npc__bandido-de-estrada__dor-forte__01.ogg` | Dano intenso | [Grito curto seguido de ar] | Surpresa antes da dor. | 0,9 | 1,4 |
| `npc__bandido-de-estrada__pouca-vida__01.ogg` | Reação ocasional com pouco PV | Isso não era o combinado… | Perde a segurança. | 1,8 | 2,5 |
| `npc__bandido-de-estrada__derrota__01.ogg` | Ao ser derrotado | [Gemido que se apaga] | Cansado, sem última fala longa. | 1,1 | 1,7 |

## Urso de Presas Vermelhas

**Entrega atual:** estas nove entradas usam as gravações de lobo indicadas no [pacote de vozes](../assets/vozes-npcs/README.md). A direção abaixo fica como referência opcional se, no futuro, você quiser dar uma voz própria ao urso.

**Voz:** mais pesado, lento e cheio que o lobo. A ameaça vem do peso da respiração; o ataque é um esforço brusco. Sem fala humana. Não grave impactos, pisadas ou estalos de osso junto da voz.

| Arquivo | Contexto previsto | Fala / som | Interpretação | Alvo (s) | Máx (s) |
| --- | --- | --- | --- | --- | --- |
| `npc__urso-de-presas-vermelhas__entrada__01.ogg` | Entrada no desafio | [Rugido grave e aberto] | Um aviso de território. | 1,7 | 2,5 |
| `npc__urso-de-presas-vermelhas__ameaca__01.ogg` | Preparação de avanço | [Bufada forte seguida de rosnado] | Pesado, sem pressa no início. | 1,2 | 1,8 |
| `npc__urso-de-presas-vermelhas__ataque__01.ogg` | Golpe | [Urro curto: “Hroah!”] | Arranque brusco. | 0,6 | 1,0 |
| `npc__urso-de-presas-vermelhas__ataque__02.ogg` | Golpe alternativo | [Rosnado de esforço] | Mais fechado que a primeira variante. | 0,6 | 1,0 |
| `npc__urso-de-presas-vermelhas__dor-leve__01.ogg` | Dano comum | [Grunhido baixo] | Reação curta de irritação. | 0,5 | 0,9 |
| `npc__urso-de-presas-vermelhas__dor-leve__02.ogg` | Dano comum alternativo | [Bufada áspera] | Ar pelo nariz e pela boca. | 0,5 | 0,9 |
| `npc__urso-de-presas-vermelhas__dor-forte__01.ogg` | Dano intenso | [Urro que sobe e termina abruptamente] | Dor misturada com raiva. | 1,0 | 1,6 |
| `npc__urso-de-presas-vermelhas__pouca-vida__01.ogg` | Reação ocasional com pouco PV | [Respiração pesada com rosnado] | Cansado, ainda perigoso. | 1,3 | 1,9 |
| `npc__urso-de-presas-vermelhas__derrota__01.ogg` | Ao ser derrotado | [Grunhido descendente e expiração longa] | Peso que se desfaz, sem som de queda. | 1,5 | 2,2 |

## Treant Ancião — boss

**Voz:** antiga, profunda e paciente. Uma frase começa como aviso e termina como sentença. Use pausas pequenas; o ritmo precisa caber no combate. A voz limpa já basta: ecos, camadas e sensação de madeira ficam para a edição. Estas falas dão personalidade ao chefe, sem acrescentar história oficial ao livro.

| Arquivo | Contexto previsto | Fala / som | Interpretação | Alvo (s) | Máx (s) |
| --- | --- | --- | --- | --- | --- |
| `boss__treant-anciao__entrada__01.ogg` | Entrada no desafio | Seus passos… ferem este chão. | Desperta devagar, firme no fim. | 2,4 | 3,2 |
| `boss__treant-anciao__entrada__02.ogg` | Entrada alternativa | A floresta não os chamou. | Reprovação calma. | 2,0 | 2,8 |
| `boss__treant-anciao__ataque__01.ogg` | Golpe comum | Afastem-se. | Ordem grave e curta. | 0,9 | 1,4 |
| `boss__treant-anciao__ataque__02.ogg` | Golpe comum alternativo | [Esforço grave: “Hrrum!”] | Peso sem frase. | 0,7 | 1,2 |
| `boss__treant-anciao__raizes-aviso__01.ogg` | Aviso de Raízes despertas, fase 1 | Raízes… despertem. | Chamada baixa, crescente. | 1,6 | 2,3 |
| `boss__treant-anciao__raizes-execucao__01.ogg` | Execução de Raízes despertas | Prendam-nos! | Uma ordem seca. | 0,9 | 1,4 |
| `boss__treant-anciao__fase-2__01.ogg` | Transição para fase 2 | Minha paciência… acabou. | Mais duro, menos contemplativo. | 1,9 | 2,7 |
| `boss__treant-anciao__ruptura-aviso__01.ogg` | Aviso de Ruptura da terra, fase 2 | Terra… rompa-se! | Pressão crescente, final marcado. | 1,5 | 2,2 |
| `boss__treant-anciao__ruptura-execucao__01.ogg` | Execução de Ruptura da terra | [Urro grave e breve] | Liberação brusca de força. | 0,8 | 1,3 |
| `boss__treant-anciao__fase-3__01.ogg` | Transição para fase 3 | Sintam a fúria da floresta! | A raiva finalmente aparece. | 2,1 | 2,9 |
| `boss__treant-anciao__furia-aviso__01.ogg` | Aviso de Fúria da floresta, fase 3 | Não haverá abrigo! | Ameaça aberta, dicção clara. | 1,4 | 2,1 |
| `boss__treant-anciao__furia-execucao__01.ogg` | Execução de Fúria da floresta | [Rugido profundo que termina seco] | Maior que o ataque comum, ainda curto. | 1,1 | 1,7 |
| `boss__treant-anciao__dor-leve__01.ogg` | Dano comum | [Grunhido grave: “Hrr…”] | Irritação contida. | 0,6 | 1,0 |
| `boss__treant-anciao__dor-forte__01.ogg` | Dano intenso | [Gemido grave que cresce e se corta] | Surpresa, depois resistência. | 1,0 | 1,6 |
| `boss__treant-anciao__derrota__01.ogg` | Ao ser derrotado | A floresta… permanece. | Perde a força, conserva a dignidade. | 2,3 | 3,2 |

As fases, os nomes dos avisos e as criaturas foram conferidos em `src/shared/Regras/Chefes.luau` e `src/server/EncontroService.luau`. As frases são propostas novas de dublagem. Os gatilhos e limites de reprodução ainda precisam de integração quando houver áudio.

## Ordem de gravação sugerida

- **Sessão 1 — Goblin e lobo:** 22 arquivos. Grave cada personagem inteiro antes de trocar de voz; deixe dor forte e uivo para o fim da sessão.
- **Sessão 2 — Treant:** 15 arquivos. Faça entradas e avisos primeiro, depois ataques/reações e derrota. Mantenha o mesmo timbre nas três fases; aumente a intenção.
- **Sessão 3 — Bandido e urso:** 19 arquivos. Comece com a voz humana do bandido e termine com o urso.

Para uma primeira entrega menor, escolha entrada/alerta, duas variantes de ataque, dor leve e derrota de cada criatura. No Treant, inclua também os três avisos de especial. As demais variantes podem entrar depois.

## Conferência antes de entregar

- [ ] Nome dos arquivos igual ao roteiro, sem espaços ou acentos.
- [ ] Uma fala ou vocalização por arquivo, sem ler os colchetes.
- [ ] Voz limpa, sem música, reverb, passos ou impacto junto.
- [ ] Nenhuma tomada distorcida ou cortada no começo/fim.
- [ ] Duração conferida; alternativas guardadas em `tomadas`.
- [ ] Goblin, bandido, lobo, urso e Treant reconhecíveis como vozes diferentes.

Na futura integração, entrada e troca de fase devem tocar uma vez por evento; uivo/provocação precisam ser ocasionais; variantes de ataque/dor devem evitar repetição imediata. O aviso visual do ataque deve continuar legível sem áudio, e derrotas só podem tocar após confirmação do jogo.

## Treinadores T1 — falas provisórias (16/10/2026)

Texto original de adaptação, exibido em TreinadorView; sem gravação, IDs ou gatilho de áudio adicionados. Ladino fala baixo e seco; Mestra, calma e firme.

| Arquivo | Contexto previsto | Fala / som | Interpretação | Alvo (s) | Máx (s) |
| --- | --- | --- | --- | --- | --- |
| `npc__ladino__provacao__01.ogg` | Consulta elegível | Passos leves. Traga meu sino sem chamar atenção. | Cúmplice, quase sussurro. | 3 | 4 |
| `npc__mestra-agua__provacao__01.ogg` | Consulta elegível | A água encontra um caminho. Mostre-me o seu. | Serena, desafia com gentileza. | 3 | 4 |
| `npc__treinadores__aprendido__01.ogg` | Plano já tem árvore | Você já conhece seu caminho. Pratique o que aprendeu. | Aprovação curta; interpretação por personagem. | 3 | 4 |
| `npc__treinadores__segunda__01.ogg` | P2: já tem um caminho, pode aprender o segundo (Ladino) | Já tem um caminho? Posso lhe mostrar outro, se passar na minha prova. | Cúmplice, sussurro; convite. | 4 | 5 |
| `npc__treinadores__segunda__02.ogg` | P2: já tem um caminho, segundo com a Mestra da Água | Já tem um caminho? A água também pode ser o seu segundo. Mostre-me. | Serena, desafia com gentileza. | 4 | 5 |
| `npc__treinadores__conhece__01.ogg` | P2: este caminho já é seu | Este caminho você já conhece. Pratique o que aprendeu. | Aprovação curta. | 3 | 4 |
| `npc__treinadores__dois__01.ogg` | P2: já aprendeu dois caminhos | Você já conhece dois caminhos. Pratique o que aprendeu. | Aprovação curta. | 3 | 4 |
