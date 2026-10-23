# Contratos do jogo por turnos

Estado consolidado em 13/10/2026 para destravar o primeiro personagem e a
progressão. Este documento descreve o escopo inicial; comandos ainda não
implementados não são considerados entregues. Regras existentes da mesa e
adaptações do livro permanecem em [MESA.md](MESA.md) e [FIDELIDADE.md](FIDELIDADE.md).

## Como jogar

- **Começar:** uma run é uma expedição cooperativa de até quatro jogadores, com objetivo e prazo em dias. Abra **RUN**, escolha o modo e, no modo do zero, uma árvore da oferta (no pronto ela já vem definida). Depois abra **MENU → Montar ficha**, crie o personagem e escolha uma arma do kit. Vote no destino em RUN; **VIAGEM** mostra rota, prazo e eventos. Escolha sua opção e espere os votos do grupo; viajar gasta dias.
- **Explorar e lutar:** observe as patrulhas nas trilhas. Ao alcançar o jogador com ficha, a patrulha inicia combate e a grade nasce no local. Na sua vez, use **Atacar/Disparar**, escolha uma casa livre ou um botão **Mover**, e **Encerrar turno**. Ações, movimento, alcance e tempo são limitados. Para fugir, alcance a borda e use **Fugir** com uma Ação: o teste de Atletismo pode falhar e encerrar a vez; fugir não paga recompensa. Contato pelas costas sem detecção dá surpresa: prioridade na primeira rodada e alvo Desprevenido até começar a agir.
- **Vila:** Dona Brisa oferece **Comprar/Vender** e **Missões** na taverna; Mestre Torr vende/compra equipamentos na forja. Mestre Hanzo abre **Treinar no dojo**; confira requisitos e custo da provação. A oferta de treinadores varia por run; no modo sem árvore, consulte a oferta disponível, os requisitos e os custos em PA de aprimoramento e dias antes de treinar.
- **Controles:** clique ou toque em botões e casas; deslize listas no celular e siga o aviso das interações do mundo. No controle, selecione botões pela navegação do Roblox e confirme com A; siga o botão indicado nos NPCs. No combate de exploração não há atalhos de teclado para atacar/encerrar. Somente na **visão da mesa**, M alterna a visão durante a partida, WASD move a câmera, roda do mouse/pinça ajusta zoom e arraste move a câmera no toque; clique direito, Q ou B cancela mira/seleção. O **?**, abaixo de VIAGEM, abre quatro abas de ajuda; **Fechar** ou B no controle fecha. Uma dica de 8 segundos aparece uma vez por sessão.

## Personagem e progressão inicial

- A ficha v2 do site pode servir de entrada no fluxo legado da mesa. No jogo,
  construção precisa ser validada e calculada no servidor; `calculated` recebido
  do site não é autoridade para o personagem próprio.
- J1 valida a construção e calcula uma prévia derivada para rank Principiante:
  atributos, perícias, PV/PM/PT/PP, CA, deslocamento e iniciativa. O jogador
  pode criar/substituir a ficha pessoal persistida e selecioná-la para a próxima partida
  em Treino/Luta/Duelo. O servidor reconstrói o corpo a partir das escolhas
  guardadas na sessão privada; o cliente não envia corpo nem identidade do dono.
  A seleção não persiste entre servidores nem se mistura ao slot da campanha.
  Na sala inicial, o atalho MENU continua acessível para abrir a criação; `SalaService`
  encaminha o marcador pessoal ao validador J1 sem tratá-lo como ficha da mesa.
- O formulário atual exige seleção manual de raça, então cobra o custo de
  escolha pelo tier (1 PA comum/incomum, 2 rara, 3 lendária/mítica), sobre os 3
  PA iniciais. Escolher também o antecedente não acrescenta custo. Compras
  pessoais usam o PA infinito provisório já aprovado até Intermediário e somente
  habilidades compráveis do rank aberto; não abrem rank. J3a persiste os IDs
  comprados no perfil, recalculando e revalidando ao carregar. O saldo de PA
  continua informativo e não é consumido.
- A prévia procura o kit inicial pelo subgrupo exato da árvore no catálogo
  gerado. Mostra os itens e os inclui no inventário inicial, todos inicialmente
  desequipados. Depois de criar a ficha, o jogador pode escolher uma arma já
  presente no kit; a escolha é salva no perfil, equipa armas corpo a corpo para
  Ataque e prioriza armas de distância para Disparo. Trocar a árvore limpa a
  escolha; perfis antigos sem seleção mantêm o comportamento anterior. A UI só oferece árvores com kit catalogado; o servidor
  recusa qualquer árvore sem kit, sem fallback. A UI aceita nome de até 32 caracteres; o servidor filtra antes
  de guardar, revalida sessão/combate depois da espera e usa só o resultado
  filtrado ao montar o token.
- O catálogo presente em `Shared/Livro/Catalogo` não implica suporte jogável.
  Habilidades só podem ser escolhidas para uso quando `Shared/Regras/Execucao`
  declara sua execução. As demais ficam indisponíveis, sem efeito presumido.
- A árvore inicial mantém a adaptação já registrada: PA não limita compras e o
  teto é Intermediário. Cartas de custo zero vêm com o rank; requisitos de
  árvore/compra são validados por `Regras/Progressao`. Símbolos de origem natural
  da Teórica continuam não suportados. Não confundir PA de aprimoramento com
  Ações do turno.
- Campanhas continuam salvas por slot e separadas do perfil pessoal. J3a grava
  apenas a construção validada, nome filtrado e IDs de habilidades compradas em
  `PersonagensPessoais`; atributos e kit são recalculados no servidor ao entrar.
  O CAS por revisão recusa uma sessão antiga que tente sobrescrever alterações
  feitas em outro servidor. Inventário/consumo de itens permanece temporário.
- O kit entra desarmado; equipamento configurável, gastos de PA e XP/recompensas
  continuam fora do escopo. No Studio, persistência falha fechada sem
  `ServerStorage.PersonagemTestConfig` com scope exclusivo `test_` + 32 hex;
  não cai no armazenamento de produção. Para jogar/testar a criação sem API
  externa, `Mode=memory` opta explicitamente por memória volátil no servidor
  atual; sem esse atributo, o scope continua usando o DataStore isolado.
- Não há no repositório fórmula validada de XP concedido, nível, nem conversão
  de XP em PA. Nenhum XP/recompensa será inventado nesta fatia. A adaptação
  PA-infinito é a regra efetiva até decisão documentada diferente.

## Encontro e comandos

- O servidor mantém um encontro versionado e decide turno, efeitos, recursos,
  alvos, movimento e resultado. O cliente pede uma ação e exibe recibos; animação
  não confirma acerto, dano ou avanço.
- `shared/EncontroTurnos` implementa sequência pura; `server/EncontroAutonomoService`
  mantém sessões em memória, recebe ordem/controle só de código de servidor e
  valida fim de turno pelo jogador autenticado. O payload não escolhe ator. A
  última repetição devolve o mesmo recibo. O estado mantém as três Ações por
  turno do Cap. 4 §4; `solicitarAtaqueBasico` e `solicitarDisparo` validam
  jogador/vez/versão/alvo e consomem uma Ação junto da resolução server-side.
  O Disparo usa a primeira arma de distância do inventário ou d6 de referência,
  tem alcance máximo de 12 casas e respeita o Muro de Chamas. O menu fora da sala e a placa física “Expedição” na
  sala iniciam um protótipo solo com um goblin e um lobo; o servidor exige ficha
  pessoal válida, ignora IDs/fichas enviados pelo cliente e recusa partida
  assistida ativa ou outro encontro ativo dos integrantes. O grupo é opt-in,
  mantém até quatro jogadores e só o primeiro da fila pode iniciar; no marco mundial, o servidor exige que todos os integrantes enfileirados estejam no alcance e com visão livre antes de iniciar, preservando a fila se alguém ainda não chegou; a placa
  continua solo para quem não entrou. `shared/EncontroAutonomoCombate` usa ataque básico e Disparo,
  arma de referência d6 quando nada está equipado, atributo + bônus de Rank,
  crítico e CA. Personagens de Fogo recebem Brasa no combate: 1 Ação, 0 PM,
  alcance de 6 casas e dano 1d6 + BC ígneo, uma vez por turno. O resolvedor
  compartilhado aplica crítico, resistência e imunidade. Bola de Fogo e Toque
  Escaldante só aparecem se a ficha possuir a habilidade comprada. Bola custa
  2 Ações/1 PM, tem alcance de 12 casas e aplica Em Chamas ao acertar; a
  condição causa 1d6 ígneo no início
  de cada vez do alvo. Toque Escaldante usa adjacência e preserva o bônus de
  2 Ações/2 PM e +1d6 quando o conjurador está com metade dos PV ou menos.
  Fagulha só aparece se comprada; cria perigo em uma casa escolhida no mapa,
  até 6 casas, por 2 rodadas. Entrar ou atravessar causa 1d4 ígneo uma vez por
  zona em cada movimento, também em aliados e criaturas; não causa dano ao
  criar/permanecer, não aplica Em Chamas e não bloqueia. A grade ainda é plana
  sem paredes de cenário além das rochas fixas do bosque; rocha e Muro de Chamas bloqueiam a linha de visão pela supercobertura da grade.
  Empurrões de habilidades e arrasto de Mão de Terra percorrem as casas no
  servidor e também acionam essas zonas; o percurso termina na casa que derruba
  o alvo. Bloqueios e ocupantes continuam interrompendo o deslocamento.
  Defender usa 1 Ação e reduz os golpes da IA por Vigor + metade do Rank de
  corpo até a próxima vez. Cura custa 2 Ações/2 PM, exige compra, alcança aliado
  adjacente e restaura 1d8 + BC, sem exceder PV máximo; pode reerguer aliado em
  0 PV. Em Chamas termina com o encontro. J1 permite comprar habilidades elegíveis
  do rank aberto na sessão; fichas novas não recebem Bola de Fogo, Toque ou Cura
  automaticamente. Formação
  temporária em duas fileiras mantém o ataque básico ao alcance enquanto não há mover.
  Criatura derrotada sai da fila; ao derrotar a última, a fase vira vitória.
  Painel oferece os alvos adjacentes, exibe saldo e deixa encerrar turno; vitória
  oferece retorno ao menu. A interface mantém um mapa tático 20×20 com as
  posições do último snapshot, iniciais dos atores e destaque do jogador
  controlado; criaturas derrotadas não ocupam nem aparecem na grade. No turno
  próprio, destinos alcançáveis ficam verdes e podem enviar a intenção de mover;
  o servidor recalcula rota e revalida o pedido. A rota também aciona as zonas
  de Fagulha do servidor; se um ator cair durante o percurso, o movimento para
  naquela casa. As zonas expiram no início da terceira rodada após sua criação
  ou no fim do encontro. Recibos confirmados animam por um
  instante a casa de origem/destino ou o alvo de dano/cura; falhas de ataque não
   são mostradas como acerto. O painel de mapa é apresentação 2D; as arenas da clareira e do bosque têm grade cosmética de 20×20 casas, alinhada à mesma geometria. As linhas não bloqueiam movimento nem visão. No encontro, `EncontroAutonomoAvatares` ancora os avatares e os posiciona nas casas do snapshot do servidor, restaurando posição/controles após o retorno de todos, mesmo quando a raiz está temporariamente fora do personagem. `EncontroAutonomoMiniaturas` mantém figuras sem colisão de personagem, goblin, lobo e Treant (silhueta genérica para outras criaturas), com PV e destaque da vez, alinhadas à escala de 1,8 studs por casa e ao centro do marco escolhido. A forma é cosmética e vem apenas do nome do ator; coordenadas e estado continuam vindo do snapshot do servidor. O retorno
  só é aceito após vitória/derrota e exige o
  jogador participante; o servidor descarta a sessão quando todos os
  participantes conectados retornam. O remoto limita pedidos novos a um por 0,25 s por
  jogador, com retransmissão exata idempotente permitida. O início pela interface
  aceita comando e ID; o início por marco mundial também recebe o ID estável da
  área, revalidado pelo servidor junto à vida e ao alcance. A retransmissão
  devolve o estado do mesmo encontro. Ao encerrar a vez do jogador, a IA ataca uma vez
  se houver personagem adjacente; caso contrário, usa uma Ação e o deslocamento
  do molde para se aproximar de um jogador vivo, respeitando ocupantes, rochas fixas do bosque e rotas,
  e ataca se ficar adjacente. O ataque usa bônus e `dano por turno` fixo do
  molde. Grupo sem PV conclui em derrota; a luta conclui em vitória quando todas
  as criaturas caem, inclusive com mais de um jogador ativo. No snapshot terminal, o servidor aplica
  o descanso automático provisório de FIDELIDADE §7E: PV/PM/PT/PP máximos e
  condições limpas, inclusive depois da derrota. Isso adapta o modo luta existente,
  não implementa comportamento completo do Apêndice G. J2 já integra Brasa,
  Rajada Curta (truque gratuito de Vento), Pedrisco (truque gratuito de Terra), Bala de Pedra (comprada; acerta automaticamente alvo Atolado, mantendo crítico só em 20 natural), Lança de Pedra (comprada; até três criaturas, resistência individual e Atolado em falha), Atoleiro (comprado; esfera centrada no conjurador, Atolado e terreno difícil por 100 rodadas), Lâmina de Vento, Sopro de Poeira e Passo de Vento (comprados; cone direcional com Cego/Desequilibrado na falha e deslocamento até 12 casas, ignorando terreno difícil), Respingo,
  Bola d’Água, Flecha d’Água, Impacto de Gelo, Lâmina de Gelo e Empurrão (comprados), Bola de Fogo,
  Fagulha, Toque Escaldante, Cura, Defender, Clarão e Muro de Chamas (Cego altera ataques e expira
  ao fim da próxima vez do alvo). Muro de Terra cria linha transversal de quatro casas, com bloqueios e 40 PV compartilhados. Ataques físicos que cruzam a linha são interceptados; básico/disparo podem mirar uma casa da barreira. Dano é automático, sem crítico e sem excedente para a criatura; ao zerar os PV, as quatro casas são removidas. Anteparo Teórico cria duas casas adjacentes com 30 PV compartilhados por dez rodadas; bloqueia movimento e ataques físicos, enquanto magia atravessa. Mão de Terra (2 Ações/2 PM), comprada de Terra, aplica Agarrado e Atolado após falha em Força contra CD 8 + BC; escapar repete o teste e a CD por 1 Ação. A fonte mantém um alvo por vínculo, pode arrastá-lo até 3 m sem se mover e soltá-lo gratuitamente; ficar Caído/incapacitado encerra a sustentação. Rochas fixas e muros de Terra/Fogo bloqueiam linha de visão; a travessia do Muro de Chamas causa dano. O prazo de turno é 60 segundos com encerramento automático, inclusive durante desconexão. Se todos saem, o encontro é removido após 60 s sem reconexão. Desistência voluntária reutiliza `EncontroService.desistir`: a ficha do jogador cai a 0 PV e a luta continua para os demais; não há custo de Ação nem recompensa nova. Se for o último jogador, a derrota aplica a recuperação terminal provisória RB-25. Multiplayer com vários clientes e recompensa continuam pendentes. Avatares e miniaturas usam o marco escolhido no início mundial; menu começa na clareira. O posicionamento físico está implementado; a recuperação terminal usa adaptação provisória RB-25, e não há descanso próprio durante a exploração. A região tem dois marcos de encontro ligados por trilha; o percurso e o combate no segundo marco ainda não foram verificados com personagem real.
- Escudo de Água J2: habilidade comprada/rank Água; cria linha transversal de 2 casas, alcance 4, por 2 rodadas, cobrando 2 Ações/2 PM. A linha não bloqueia movimento/visão/magia nem absorve PV; atualmente dá +5 CA ao aliado atingido pela linha de ataque físico da IA ou que ocupa uma casa do escudo. Parcelas ígneas tipadas de habilidades são reduzidas à metade quando sua linha cruza uma célula ativa do escudo. Ataques genéricos da IA seguem sem tipo de dano inferido.
- Névoa Densa J2: habilidade comprada/rank Água; cria esfera de raio 4 casas por 50 rodadas, com 2 Ações/1 PM. Bloqueia linha de visão, mas não movimento. Quem está dentro recebe Cego apenas durante as rolagens; sair ou expirar remove o efeito sem gravar condição. A dissipação por vento segue sem comando ambiental.
- Sopro de Poeira J2: habilidade comprada/rank Vento; 1 Ação/1 PM, cone de 4 casas e resistência de Vigor contra CD 8 + BC. Na falha, aplica Cego e Desequilibrado até o fim da próxima vez do alvo; sem dano. O servidor inclui apenas atores vivos dentro da geometria/visão confirmada.
- Passo de Vento J2: habilidade comprada/rank Vento; 2 Ações/2 PM, desloca até 12 casas por caminho livre, ignora terreno difícil e não consome o orçamento de movimento. Obstáculos, ocupação e bordas da grade continuam valendo; voo vertical não é representado.
- Vácuo Localizado J2: habilidade comprada/rank Vento; 2 Ações/2 PM, alcance 6, causa 1d6 de sufocamento e Silenciado. Patamar igual/menor não resiste; patamar maior testa Vigor contra CD 8 + BC. Só criaturas vivas explicitamente respiradoras podem ser alvos. O mesmo alvo não pode receber o efeito em rodadas consecutivas; espécies não classificadas permanecem fora.
- Dardo Arcano J2: habilidade comprada/rank Teórica; custa 2 Ações/1 PM, alcance 6 casas, dano canônico de 1d8 + BC arcano.
- `shared/EncontroIniciativa` rola d20 com bônus e vantagem recebidos de código
  servidor; desempata por bônus maior e depois ordem de entrada, conforme RB-13.
  `server/EncontroAutonomoElenco` deriva iniciativa do corpo pessoal validado e
  monta 2–3 fichas de criatura do catálogo para 1–4 jogadores. Criaturas não têm
  bônus no bestiário: usam zero, mesmo fallback atual da mesa para tokens sem
  ficha. O menu inicial aceita fila voluntária de até quatro e liderança FIFO;
  a placa física inicia solo. No marco mundial, o líder inicia para a fila somente depois que o servidor valida alcance e linha de visão de todos no mesmo marco; recusa preserva a fila para nova tentativa.
- Cada pedido mutável deve ser validado contra sessão, jogador/personagem
  controlado, versão observada, fase/turno, tipo e tamanho do payload, recursos,
  alcance, frequência e limites do mapa. Revalidar depois de qualquer espera.
- Um recibo futuro deve identificar encontro, versão aplicada, ator, ação,
  resultado e alvos observáveis. Repetir o mesmo identificador de pedido não
  aplica efeito ou recompensa duas vezes; pedido antigo recebe conflito/estado
  atual, nunca reaplicação.
- Jogadores e IA usam o mesmo resolvedor. Um inimigo só tem um controlador
  efetivo por decisão: mestre explícito ou IA. Trocar controlador incrementa a
  versão de controle; comandos atrasados do controlador anterior são recusados.
- Política aprovada por Pedro (14/10/2026): cada turno de jogador expira em
  60 segundos e é encerrado automaticamente, inclusive se o jogador estiver
  desconectado. O prazo começa quando o turno começa; ações do turno não o
  reiniciam. Clique manual e expiração disputam a mesma transição versionada do
  servidor. O serviço aplica o prazo por ator/rodada; o snapshot informa um
  deadline sincronizado apenas para a contagem visual do HUD. Não cobre
  abandono, derrota automática nem retorno após o fim do encontro.

## Grade e menu de ação

- `MesaProtocol` define a grade legada 20×20, célula de 5 studs, origem e
  distância Chebyshev; J2 conserva a diagonal como uma casa. A grade autônoma
  começa plana, com posições e ocupação decididas pelo servidor.
- Movimento comum consome 1 Ação e alcança até `floor(movementMeters / 1,5)`
  casas da ficha pessoal, reaproveitando a adaptação descrita em
  `FIDELIDADE.md` §7C. BFS server-side bloqueia casas ocupadas e rochas fixas do bosque, e calcula rota;
  as rochas bloqueiam linha de visão, sem alterar alcance, cobertura ou dano. A IA usa o deslocamento canônico para perseguir (RB-18).
  Isto não autoriza inferir linha de visão da interface.
- Menu conceitual: Mover, Atacar, Habilidade, Item, Defender e Encerrar. Atacar
  e Habilidade podem se apoiar nas ações já resolvidas em `Regras/Combate` e
  `Regras/Execucao`; a disponibilidade de cada habilidade continua condicionada
  à execução real no servidor.
- Defender segue RB-22. Cura pode mirar em si ou aliado adjacente. Primeiro item de combate: Poção Menor de Cura existente
  no inventário, 1 Ação, 1d8 + 2 PV, para si ou aliado adjacente; não é magia e
  não remove Ferimento Crítico. O servidor só aceita a entrada canônica, remove
  uma unidade e limita a cura ao PV máximo. A remoção fica no inventário
  temporário J1 entre encontros até o jogador sair; não há salvamento entre sessões.
  Nenhuma poção é concedida: kits J1 não incluem consumíveis e ainda não há loja.
- Cura usa a Ferida Fresca canônica: o servidor registra dano em sequência causal
  e compara com o fim da última vez do curador; dano depois do marco dobra os
  dados. Antes da primeira vez do curador, dano ocorrido no encontro conta.
  Vigor Emprestado concede PV temporários: o maior valor substitui sem acumular,
  o escudo absorve dano antes dos PV reais e expira após 100 rodadas ou ao fim
  do encontro. Marcas da Morte continuam fora do J2.
- Encerrar consome a vez uma única vez. Repetições e prazo competem pela mesma
  transição versionada; desistência também é autenticada, versionada e
  idempotente, mas remove o ator do participante sem consumir Ações.

J4 está pronta para revisão: o servidor monta um blockout curto de entrada, trilhas, acampamento, bosque e clareira, conectado ao lobby por passagem oeste. Uma trilha plana liga a borda da clareira ao marco de encontro do bosque. Cada prompt envia ID estável e o serviço valida marco, vida, alcance configurado e, quando exigida pelo prompt, linha de visão por raycast no servidor. No Studio, o fluxo anterior da porta até a clareira iniciou encontro com ficha J1; nesta continuação, o avatar percorreu a saída oeste, a borda da clareira e a trilha até o marco do bosque. O combate no bosque não iniciou: a sessão não tinha ficha pessoal carregada e o E-hold automatizado não gerou evento observável. Os dois prompts e a ligação geométrica foram confirmados por specs; a captura do viewport permaneceu preta, então inspeção 3D/aprovação visual ainda faltam. A iniciativa aceita `Random.new()` do servidor. A formação física J2 reserva a clareira para um encontro por servidor; não há arena instanciada por grupo.

## Run (PLANO §12; regras puras R1)

Estado e regras em `src/shared/Regras/Run*.luau`, sem Instances; o servidor guardará o estado (R5) e valida todo pedido.
- **`Run`:** jogadores (1–4; ausente espera no acampamento e não conta para a queda; ao voltar, devolve os dias perdidos para tirar o PA do período), `dia` em múltiplos de 0,25, objetivo com prazo (`ativo`→`expirado`/`cumprido`; expirado só vira outro com `trocarObjetivo`, e o perdido fica registrado), `flags` de trancas, fim por queda do grupo ou por final. Custos em `CUSTO_DIAS` são provisórios; o dojo informa o próprio custo.
- **`RunVotacao`:** voto do Explorador (Navegação e Liderança) pesa 2; ausente e estranho não votam; empate rola dado com um lado por opção empatada (dado injetado, recibo traz o valor).
- **`RunSorteios`:** sorteio ponderado sem repetição com RNG injetado; oferta de árvores por composição (`COMPOSICAO_OFERTA` corpo 3/magia 2/utilidade 1, provisória) com peso `FORCA_MAX+1-força` (mais forte, mais rara; as forças das 19 árvores vêm em R3); treinadores da vila em sorteio separado, com chance de um extra da taverna.
- **`RunDefeitos`:** defeitos do personagem pronto (Zangado, Manco, Burro…), cada um com Desvantagem em perícia do livro, deslocamento menor e tags de opção de evento que bloqueia. Lista provisória.
- **`RunArvoresForca`:** força 1–10, categoria e elegibilidade das 19 árvores (R3a); só entra na oferta árvore com habilidades Principiante executáveis hoje.
- **`RunCriacao`:** três modos (R3b). `zero` = oferta de 6 árvores sorteada (peso pela força); `semArvore` = +2 PA para comprar com treinador; `pronto` = ficha de `PersonagensProntos` (sorteada, as fortes mais raras), 2 defeitos distintos, +3 PA +1 por defeito e recompensa final ×1,25 por defeito. Valores provisórios; PA só registrado (Progressao usa PA infinito).
- **`RunTreinadores`:** 3 treinadores comuns na vila + chance de 1 extra raro na taverna; dias de treino por raridade (R3c).
- **`RunViagem`:** custo em dias (pé/cavalo/Explorador), sorteio de eventos por região/modo, prévia só com Explorador, vetos por defeito e aplicação da opção vencedora à run (R4a).
- **`RunSave`:** serializa/restaura a run e os planos de criação para DataStore (userId numérico vira texto e volta ao tipo; versão do save; recusa save corrompido) — R5.
- **`RunConta`:** moeda da conta por run, desbloqueios comprados, conquistas e códice; treinador raro só entra na taverna depois de comprado (R6a).
- **`RunHistoria`** + **`Mundo/HistoriaV1`:** árvore da história validada (destinos, saídas, alcance de final), opções com trancas por flag, avançar gastando prazo e encerrando em final; história v1 provisória (R7a).
- **`RunSessao`:** orquestra uma run com dependências injetadas (armazenamento, rng, Explorador): iniciar/retomar, escolher árvore, votar (espera todos; ausente/caído não conta; fecha se o último que faltava sai), avançar a história, queda do grupo, e `visao` sem vazar votos alheios; falha de save desfaz o avanço (R5b). Mudar de região traz 1 evento de viagem (voto, vetos por defeito); nó `chefe` com `luta` suspende os votos até o encontro J2 terminar (`lutaTerminou`: vitória destrava o Selo, derrota encerra a run, fuga mantém pendente); fim da run paga a conta uma vez (`resumo`, `marcarContaRegistrada`). A árvore inicial só pode ser escolhida antes de partir e prende a criação do J1 (`RestricaoDeCriacao`).
- **`EncontroPatrulha`:** surpresa (Desprevenido do livro), ordem com surpresa, fuga por Atletismo e situação na grade (R2b).
- Não feito: persistência, serviço, UI, eventos da viagem (R4/R5); ligar treinadores aos NPCs/dojo (R3d).

## Limites da primeira fatia

- Começar por um grupo cooperativo de até quatro, sem exigir mestre, em uma
  região pequena e em um encontro com duas ou três criaturas.
- Raças, antecedentes, distribuição da criação, equipamento inicial e tabela
  de XP ainda não têm escopo validado como conjunto. Não apresentar opções do
  site como prontas sem port/regras e testes diferenciais contra o original.
- O avatar Roblox continua separado da ficha mecânica. Mestre futuro pode
  controlar inimigos pelo mesmo núcleo, com permissão explícita.

## Etapas e evidência

- J0 registra os contratos e lacunas acima; decisões pendentes não são aceite de
  Claude nem revisão conjunta.
- J1 porta somente cálculos e validações selecionados, com comparação
  diferencial ao `selectors.ts` do site, que é somente leitura.
- J2 fecha encontro, geometria e políticas de prazo/desconexão; precisa testes
  com 1, 2 e 4 clientes e playtest no Studio.
- J3a implementa persistência do perfil e compras já aceitas, sem inventar XP,
  recompensas, ranks ou equipamento. `PersonagemPersistencia` isola chaves do
  perfil; specs injetam armazenamento falso e não escrevem em DataStore real.

Fontes de implementação: `src/shared/MesaProtocol.luau`,
`src/shared/FichaV2.luau`, `src/shared/Regras/Progressao.luau`,
`src/shared/Regras/Execucao.luau`, `src/server/ProgressaoService.luau` e
`src/shared/Regras/AtributosPersonagem.luau`,
`src/shared/Regras/PericiasPersonagem.luau`,
`src/shared/Regras/CriacaoPersonagem.luau`,
`src/shared/Regras/EstatisticasPersonagem.luau` e
`src/server/MesaPersistence.luau`.
Direção: [PLANO.md §11](PLANO.md).
