# Entrada e administração — A11

O jogador abre o mesmo menu no Studio e no jogo: personagem, treino, fila para luta em grupo, luta, duelo, instruções e volume. O registro e as árvores ficam nos atalhos durante a partida. A escolha vale só para a sessão; não representa salvamento de progressão.

A luta inclui somente quem entrou na fila daquele modo e quem pediu para começar. PvE comporta até quatro; PvP aguarda pelo menos dois lados adversários e comporta até 32 participantes. Recém-chegados podem assistir. Uma partida ativa não pode ser substituída nem pelo mestre. Desconexão remove a fila e derrota as fichas daquele dono, avançando sua vez se necessário. São decisões de organização da sessão, sem alteração de cálculos do livro.

## Comandos

Abra COMANDOS ADMIN no menu ou use `/adm ajuda` no chat. A conta do Pedro (2287856135) e o criador individual têm acesso; no Studio, o mestre também. Ser mestre de servidor privado não concede esses comandos no jogo publicado.

| Comando | Efeito |
|---|---|
| `/adm ajuda` | Lista disponível |
| `/adm status` | Estado da partida e quantidade de fichas |
| `/adm curar` | Recupera somente suas fichas, fora de combate |
| `/adm encerrar` | Encerra a partida, preservando a mesa; botão pede segundo toque |
| `/adm voltar` | Retorna seu avatar à entrada, fora de combate e sem avatar vinculado |
| `/adm brilho` | Brilho no próprio avatar por dez segundos |
| `/adm confete` | Partículas no próprio avatar por dez segundos |
| `/adm festa` | Brilho e partículas juntos |
| `/adm normal` | Remove os próprios efeitos |

O servidor valida permissão, lista fechada, tamanho e frequência. Não aceita alvos, código ou argumentos extras. Brincadeiras ficam fora de combate e não alteram atributos. Encerrar afeta a partida de todos e é registrado no servidor.

## Verificação e limites

Em 09/10/2026: testar.ps1 passou (122 fontes); Studio: 232 specs sem falhas, nove verificações dos ganchos sonoros, 19 assets carregados/reproduzidos e três verificações de limite/limpeza. Cliques reais abriram escolha e administração, alteraram o volume e iniciaram treino (menu fechado após resposta do servidor). Captura do menu conferida. As primeiras consultas imediatas após clique anteciparam a resposta assíncrona; repetição com espera confirmou o treino.

Não verificados: dois clientes reais, celular, escuta integral/volume percebido, chat /adm em servidor publicado e sensação de jogo. Não publicado. Cidade, dojos e persistência pessoal pertencem às próximas etapas.

## A12 — apresentação e menu por páginas (09/10/2026)
A abertura agora prioriza Jogar, Seu personagem e Ajustes; Explorar e Como jogar são acessos secundários. Modos ficam na página Jogar, e volume, animações, administração e ferramentas ficam em Ajustes. Durante a partida há apenas MENU, preservando atalhos de teclado existentes. Sem alterações de regra ou pedidos remotos.

Identidade Livro Noite: fundo em degradê escuro, título serifado, violeta para ação principal e ouro para acentos. Selo geométrico rotativo, doze centelhas no máximo, resposta de hover/pressão dos botões. Tudo com Instances nativas, sem assets novos, áudio com voz ou dependências. Ajustes permite reduzir animações imediatamente; preferências continuam por sessão.

FeedbackCombate lê somente snapshots: perda/ganho de PV do dono pulsa duas faixas estreitas nas bordas por 0,8 s. Primeiro snapshot, menu aberto, fim de combate e modo reduzido não pulsam. Não acrescenta dano, câmera tremendo ou flash de tela inteira.

Verificação: testar.ps1 tudo ok (124 fontes), 232 specs no Studio, sete verificações isoladas de feedback/limites e cliques reais de navegação, volume, redução e treino. Capturas: tools/playtest/a12_inicio.jpg e a12_modos.jpg. Prévia de conteúdo com 375 px de largura conferida no Studio, sem equivali-la a teste em celular. Não verificados: toque em celular real, dois clientes, desempenho de aparelhos fracos e julgamento estético do Pedro. Não publicado.

## A13 — vitrine individual de personagens (09/10/2026)
Cada cartão mostra os cinco atributos calculados (incluindo raça), atributo-chave, vida/mana máximas, PT, CA, CD da árvore e PA de aprimoramento gasto em destaque lateral. A CD usa a mesma Execucao.bc do jogo (8 + atributo-chave + bônus do rank da árvore). O PA vem de calculated.paSpent, não da quantidade de cartas nem de pontos de ação. Valores iguais são preservados quando as fichas têm os mesmos atributos/rank; não foi feito rebalanceamento.

O gerador premontados.mts projeta atributos, ranks e PA no módulo público; --vitrine atualiza somente a vitrine, sem regravar fichas do servidor ou IDs de itens. Site e fichas existentes não foram alterados. Validação compara as 14 projeções às fichas usadas pelo servidor.

Verificação: testar.ps1 tudo ok (125 fontes), Studio 234 specs, todos os 14 cartões com PA correto e textos de recursos/atributos/PA cabendo; escolha de Nerea por clique confirmada no menu e marca selecionada. Captura tools/playtest/a13_atributos.jpg conferida. Sem celular/multiplayer real ou rebalanceamento; sem publicação.

## F2 — Proteção compartilhada da montagem (10/10/2026)

Treino, Desafio e PvP usam a mesma trava da arena. Se a criação ceder durante o filtro de nomes, outro início é recusado antes de limpar fichas; alterar fila/equipe também é recusado durante a montagem. A trava é liberada tanto na conclusão quanto em recusa ou erro interno (o erro continua visível ao despachante). Depois da montagem, continua valendo a recusa de novo início enquanto houver combate ativo. Sem mudança de regra ou contrato remoto.

O roteiro `a9_personagens_e2e.luau` passa a sair de cada treino com `sairPartida`, confirmar a arena vazia e aguardar a vez do jogador após cada avanço. `python tools/playtest/f2_verificar.py` seleciona apenas `Moshoku-Prototipo.rbxlx`, exige Edit, roda a suíte e consulta o término da regressão em vez de presumir sua duração. Encerra somente o Play iniciado por ele. A varredura tenta cartas e procura erros internos; recusas por alcance, alvo, recursos ou mecânica não suportada não são aprovação da execução dessas cartas.

## A18 — Desafios e PvP por equipes (09/10/2026)

Jogar abre **Desafios** e **PvP por equipes**. Desafios: entre no grupo e alguém começa o nível desejado; quem inicia entra também. Nível 1 preserva os encontros anteriores. Nível 2, Presas vermelhas: urso de patamar 2, goblins e, com três/quatro jogadores, um lobo. Nível 3: Treant Ancião (patamar 3, papel chefe), com um lobo por jogador adicional. Níveis são dificuldade do desafio, nunca rank do personagem.

PvP: escolher **Equipe 1**, **Equipe 2** ou **Sem equipe** inscreve na fila. A lista mostra os jogadores por lado. Quem começa também participa, usando sua escolha anterior (padrão: sem equipe). Uma equipe sem adversário não inicia. Tamanhos desiguais são aceitos; não há equilíbrio automático. Equipes são congeladas até o fim; Pactos seguem o dono. Sem equipe conserva o todos contra todos. Teto provisório: 32 participantes na arena.

Contratos: `entrarFila {modo="luta"|"duelo"|"sair", equipe?=0|1|2}`; equipe só no duelo. `iniciarDuelo {}`. `iniciarLuta {nivel?=1|2|3}`; omitido = 1. Tipos, valores e chaves fechadas são validados antes de mutação. Campos de PV, dono, alvo, boss ou equipes são recusados. Orçamento remoto de MesaService; equipe/nível explícito têm ainda intervalo mínimo de 0,6 s no serviço. A montagem bloqueia dois inícios simultâneos durante o filtro de texto. Alterar fila/equipe durante combate ou montagem é recusado.

`sala.lados` tem três listas de UserIds: sem equipe, Equipe 1, Equipe 2. `sala.equipe` informa a escolha. `encontro.equipes` guarda UserId → 0/1/2 congelado. `encontro.nivel` e `encontro.chefe {id,nome,pv,pvMax,fase,aviso?,areaAtiva}` apresentam o desafio. Aviso: `{id,fase,nome,x,z,casas={{x,z},...}}`, posição congelada até a próxima vez do chefe. `chefeEfeito {id,aviso,integrado,agiu}` só anima o cenário; não é recibo de dano. Arena, marcas e letreiro locais são limpos no fim; corpo do Treant vem do servidor. Segredo/névoa usam o filtro de CorposDeCriatura.

**Integração pendente do Claude após A16:** até injetar `deps.mesmaEquipe`, HabilidadeService trata o outro dono da mesma equipe como adversário para cura/Ajudar/Reações. Até exportar `golpeDeCriatura`, as raízes são **prévia visual** e o golpe efetivo usa a IA corpo a corpo antiga. Aviso ocupa uma vez; na próxima vez do chefe, dispara o fallback. Sair da marca ainda não garante evitar o golpe. Assinatura e integração em TAREFAS A18.
