# Arquitetura e decisões iniciais

G19: `EnquadramentoMesa` é geometria pura: limites das casas dos participantes já visíveis no snapshot, margem de duas casas/mínimo de oito, altura pela perspectiva/FOV/espaço livre. `BoardView` aplica no início de cada combate e durante os primeiros.2s de layout, com pendência que garante pelo menos um frame mesmo se houver atraso. Novos snapshots/movimento/alternar M preservam pan/zoom manual depois. Área útil ignora ScreenGui desabilitado e ancestrais invisíveis; não deixa um painel escondido deslocar a câmera. Não consulta dados ocultos nem muda regras. A transição social/corte escuro permanece em SalaTransicao; limite de altura300 pode impedir encaixe integral em FOV/área extremos.

G19 mobile: `Hud` substitui o cartão grande por `Resumo` de56px durante combate compacto; recursos e condições persistem fora da própria vez. Prazo/nome dividem a primeira linha, MENU44px fica ao lado por `InicioView.dimensionarNavegacao`. `BoardView.areaLivre` reserva Resumo/Chefe/Barra com conversão AbsolutePosition→viewport somando GuiInset.Y. `AcoesDoTurno` recolhe grupos/cartas em paisagem com altura<500; botão44px preserva recursos/Ações, abrir é local e escolher mira recolhe mantendo Cancelar/Confirmar. Não envia ação/custo ao abrir ou cancelar. Não se reenquadra continuamente ao trocar a vez ou receber snapshot.

G11/G12: MiraTatica projeta somente fichas do snapshot filtrado; MiraView desenha alcance/alvos/área. PlanejamentoArea guarda início/fim/centro localmente; fixar uma área não envia usarHabilidade. Confirmar envia a intenção por MesaState. AreaHabilidade é geometria pura compartilhada, recebendo callbacks de parede/visão; HabilidadeService continua validando dono, vez, habilitação, custo e desenho antes de pagar. ResultadoView só abre ao evento encontro do servidor, sem deduzir vencedores ou recuperar recursos. CorposDeCriatura/VisualCriaturas e Gestos são apresentação. Visão usa supercobertura entre centros: casas tocadas, inclusive laterais de um canto, bloqueiam; origem/destino continuam excluídos.

## G13/G14 — entrada pela sala social (11/10/2026)

G18: SalaConsultaLayout calcula tamanho e densidade das consultas por pixels projetados; não cria Instances nem decide regras. SalaPaginas preserva foco por nome/rolagem e confirmação de transferência entre reconstruções; consulta em retrato não muda impressão/pegada física da ficha. SalaPreparacaoView explica SeatPart.LugarSala antes de configurar/iniciar e não reenvia escolhas atuais. Selo e prompt PRONTO em SalaView/SalaInteracoes seguem somente snapshot confirmado; AvisosJogo concentra recusas do servidor. Servidor mantém toda validação.

SalaView guarda/restaura GuiService.TouchControlsEnabled durante consultas/eleição/admin no lobby, inclusive valor original false e saída/perda de sala. Evita TouchControlFrame interceptar o SurfaceGui; pegada normal preserva movimento. SalaPaginas rola antes de selecionar, aguarda layout e cancela foco atrasado por serial ao abrir/fechar.

G18, pedido adicional: ArvoresView não é iniciado por client.client; módulo e progressão permanecem para a futura criação de fichas. InicioView/EscolhaView não dependem mais de ArvoresAtalho e não oferecem acesso à tela. T pertence à entrega da ficha no lobby. BoardView ignora sua entrada durante lobby ou digitação, preservando navegação do tabuleiro em partida e editor sem sala conceitual. VoltarFicha restaura canvas650×900 e posição de rolagem zero. O foco em consultas admite uma única repetição se a seleção inicial for recusada/nula; nunca disputa nova seleção do jogador. Entrada opcional injetada em SalaPaginas permite testar Gamepad1 sem afirmar controle físico.

G17 separa a entrada mantida/contorno/confirmações em SalaPegada e as dicas contextuais em SalaMaoDicas. SalaFichaControles guarda somente atalhos compatíveis; SalaPapelGesto oferece balanço visual, sem botão de segurar ou arremesso automático por arrasto. SalaDadosControle apresenta cópia local suavizada e restaura o original ao soltar; SalaDados assenta com Tween no servidor e só depois confirma valores. DadoVisual reutiliza seis faces/aparência na bandeja e nos dados físicos; DadosModelo mantém o adaptador de servidor. Soltar é intenção validada separada de arremessar, sem novas regras do livro.

G16 extrai `SalaEntrega`: valida contexto, mãos, corpos, alcance, visão e intervalo antes de transferir posse em uma operação sem yield. Oferta é confirmação informativa. `SalaPaginas` aguarda confirmação e preserva a ficha numa recusa/consulta simultânea; `SalaEleicaoView` separa convite, rolagem e recolhimento/reabertura. `SalaView` compõe o cursor/câmera apenas enquanto o convite está aberto. Regras de eleição e combate permanecem em seus módulos existentes.

G15 acrescenta `SalaDados` (física/posse/limpeza), `DadosModelo` (seis faces), `SalaCarregarJogadores` (carregamento curto e restauração) e `SalaDadosControle` (intenção/cópia visual/fuga). `SalaLancamento` valida números e `SalaDadosMao` calcula enquadramento sem serviços/Instances; `SalaService` liga o resultado privado do lançamento ao Brotos/eleição no pouso. Estado de mão confirmado dirige os braços e os objetos físicos são replicados pelo servidor. Movimento visual do próprio trio é local durante posse, sem autoridade sobre física/RNG. Contratos e prazos em MESA; limitações verificadas em TESTES.

O lobby precede Treino/Desafios/PvP. `SalaRegras` guarda admissão, mestre, exclusividade/cópias, equipes e prontidão; `PreparacaoSala` fornece o mesmo checklist ao cliente e ao início autoritativo. `SalaService` integra mãos/entrega, Brotos recreativo, início sentado e bloqueios de contexto. `SalaPapeis` limita arremessos; `PapelSolto` calcula a trajetória cosmética sem Instances. Não há física de papel capaz de causar dano ou mover ficha de combate.

`SalaView` coordena os módulos de páginas/gesto/controles, prompts, corpo/braços e transição. Braços clonados são apresentação por cliente a partir das mãos confirmadas e olhar limitado. A câmera desloca-se um pouco à frente da cabeça antes do cálculo nativo, e o fade evita viajar visivelmente da sala à arena. Esc/Tab não são comandos do jogo. Mapa de manutenção em MANUTENCAO; contrato detalhado em MESA; guia de uso em SALA. A estrutura histórica abaixo permanece para os demais sistemas.

## Produto atual: jogo por turnos (atualização 10/10/2026)

G10: `AvisosJogo` apresenta apenas logs de erro já enviados ao cliente. Usa tempo de leitura local e versão de aviso para impedir que um temporizador antigo esconda uma recusa mais recente. Fechar/expirar não envia comandos nem altera a partida; o registro continua no MesaPanel. `AcoesDoTurno.redimensionar` limita as linhas de cartas conforme grupo e altura da janela, mantendo todas acessíveis por rolagem.

A direção aprovada em PLANO §11 e o pedido de gamificação do Pedro priorizam o jogo com as classes iniciais. `EncontroService`/`TreinoService` orquestram partidas e `HabilidadeService` resolve ações; não confundir com o protótipo pausado `CombatService`. `AcoesDoTurno` apresenta escolhas por intenção; `RitmoCombate` usa apenas snapshots e recibos filtrados; `Coreografia`/`Gestos` animam localmente resultados confirmados. Gamificação em GAMIFICACAO; adaptações em FIDELIDADE. Nenhuma dessas telas autoriza dano, recursos ou recompensas. As seções abaixo preservam as decisões do núcleo da mesa e o histórico anterior.

## G6: recuperação e leitura tática

G9: `ApresentacaoApoio` projeta canções/usos e efeitos já confirmados no snapshot, sem recalcular alcance. Inclui fichas próprias mesmo quando `aliadoSeu` não está marcado; referências a beneficiados ausentes não viram nomes/IDs expostos. `BardoView` cuida apenas da interface: resumo persistente ao recolher, detalhes roláveis, ajuste à janela e preservação da leitura quando o conteúdo não mudou. Nenhum contrato remoto ou regra foi alterado.

`VisaoFurtiva` é geometria pura compartilhada. `UtilidadesService` valida Esconder e revela ao atravessar visão; o servidor registra orientação em movimentos/ataques. Snapshot expõe orientação e hostilidade ao ator atual apenas de fichas já visíveis. `VisaoFurtivaView` desenha a prévia sobre esse recorte; `PreviaFurtiva` guarda apenas intenção local de consulta. Muros incluem `bloqueiaVisao` para alinhar a prévia ao bloqueio real. O cliente nunca manda observadores, direções ou resultado de furtividade.

`BalanceamentoJogo` concentra bônus do perfil interno concedido por Treino/Encontro. Habilidades puro recebe bônus opcionais, zero por padrão; o pedido remoto não fornece esses campos. `DescricaoHabilidade` apresenta a mecânica e valores da ficha própria recebida sob demanda; `TooltipAcao` cuida do tamanho/rolagem/fechamento. `ArmasNoChaoView` apresenta objetos confirmados. BoardView integra esses módulos. Guia de alterações em MANUTENCAO.md.

Levantar usa o fluxo validado de usarHabilidade; saldo `passosLivres` é do turno e consumido pelo validador de movimento. AvatarFichas controla pose pela junta do corpo, sem girar a raiz de câmera; posição, direção e recuperação continuam no servidor. CorposDeCriatura restaura corpos recuperados. Não há alteração de Humanoid.Health para simular PV.

## Modo atual: mesa virtual

G5: `PlanosArvores` é orientação estática, sem conceder habilidades. `Regras/Fogo` declara Fagulha como zona de uma casa e Brasa com condição `alvoEmChamas`; `Regras/Habilidades` resolve somente pelo alvo recebido do servidor, com RNG injetado. `HabilidadeService.casasDaZona` valida a forma `casa` antes do custo; `moveu` cobra uma vez por zona distinta atravessada, interrompendo ao cair/remover. `BoardView` desenha o braseiro a partir dos muros do snapshot; o aviso é projetado em PerigosMesa, removido ao destruir a chama, com conexão de projeção encerrada ao destruir a interface. `ArvoresView` apresenta descrição executável e texto original separados. Adaptações/limites em FIDELIDADE §7P.

Qualidade de vida G3: `AcoesDoTurno` oferece consulta e confirmação explícita da mira; `DetalheAcao` só apresenta nome, custo, descrição e disponibilidade recebidos da barra. Não seleciona alvos nem envia comandos. Consulta fecha na troca de turno/saída e atualiza o motivo a cada snapshot; o botão Confirmar usa o mesmo `MesaState.dispararMira` existente.

Estrutura, contrato de rede e visibilidade estão em `docs/MESA.md`. Decisões principais:

- Servidor guarda todo o estado da mesa e rola os dados; cliente envia pedidos e apresenta.
- Fichas não são Instances replicadas: cada cliente desenha localmente o que o snapshot dele contém. Assim fichas ocultas e atributos secretos nunca chegam a quem não deve ver.
- Snapshot completo por jogador após cada mudança. Simples e suficiente para uma mesa (até 60 fichas, poucos jogadores); trocar por diferenças só se medições indicarem custo.
- Nomes digitados passam pelo filtro de texto do Roblox antes de serem mostrados a outros. Textos de rolagem são gerados pelo servidor.

## Protótipo de combate automático (pausado)

| Arquivo | Responsabilidade |
| --- | --- |
| src/server.server.luau | Inicialização do servidor |
| src/server/CombatService.luau | Sessões, turnos, validação e encontros |
| src/server/CombatRules.luau | Rolagem e resolução do ataque, com RNG injetado |
| src/server/WorldBuilder.luau | Construção temporária do campo e primitivas |
| src/client.client.luau | Inicialização do cliente |
| src/client/BattleController.luau | Interface, comandos e apresentação do estado |
| src/client/CameraController.luau | Câmera de exploração e batalha |
| src/shared/Grid.luau | Geometria e validação de coordenadas |

Escolha do projeto: Luau, módulos nativos e Rojo, sem framework adicional neste estágio. Não existe uma arquitetura universal obrigatória; esta divisão segue as fronteiras oficiais da plataforma e mantém baixa a complexidade inicial.

## Autoridade e contrato de rede

`ReplicatedStorage.RPG` é um RemoteEvent criado pelo servidor. Cliente envia `action, x?, z?`; ações permitidas: move, attack, spell, guard, end, flee. Coordenadas só se aplicam a move. Servidor verifica sessão ativa, turno, intervalo de 0,12 segundo, coordenadas inteiras, limites, custo, ocupação e alcance. Não recebe dano ou resultado de dados do cliente.

Servidor envia snapshot com `active`, `hp`, `mp`, `enemyHp`, `enemy`, `pa`, `origin`, `message`; ao encerrar envia `active=false` e mensagem. O campo interno `pa` significa pontos de ação e deverá ser renomeado para `actionPoints` antes da implementação de progressão. Não é PA do livro.

Estados atuais: exploração → turno jogador → turno inimigo → turno jogador ou encerramento. Temporizador do inimigo verifica identidade da sessão antes de agir. Saída, desconexão e remoção do personagem limpam a arena. Há oito segundos de pausa entre encontros.

## Limites e evolução

As arenas ainda existem no mesmo Workspace, em altitude elevada. Não há isolamento de replicação nem orçamento validado para muitos jogadores. Antes de multiplayer de produção, substituir por arenas com capacidade limitada e uma política de acesso/replicação apropriada. Não ativar streaming sem testar a câmera e a disponibilidade da arena no cliente.

CombatService ainda concentra orquestração e encontros. Conforme surgirem regiões, extrair EncounterService; conforme aparecerem mapas táticos, extrair ArenaService. BattleController ainda reúne interface e entrada; separar quando houver mais telas. Evitar criar dezenas de módulos vazios antecipadamente.

Persistência futura: PlayerDataService exclusivamente no servidor, esquema versionado, migrações, tratamento de falhas e proteção contra duplicação. Não tratar o localStorage do site como salvamento Roblox. Minigames precisam de janelas e limites calculados no servidor; nunca aceitar recompensa arbitrária do cliente.

Para escala: medir custo de Instances, rede e memória com ferramentas do Studio; substituir polling global conforme a população aumentar; testar desktop e celular; usar pooling somente se medições justificarem. Modelos e animações serão assets separados das regras.

## Fontes consultadas em 08/10/2026

- Modelo de dados e localização dos objetos: https://create.roblox.com/docs/projects/data-model
- Módulos: https://create.roblox.com/docs/reference/engine/classes/ModuleScript
- Servidor como autoridade: https://create.roblox.com/docs/scripting/security/security-tactics
- Validação e limitação de pedidos: https://create.roblox.com/docs/scripting/security/client-server-boundary
- Conteúdo replicado e código exclusivo do servidor: https://create.roblox.com/docs/scripting/security/access-control
- Organização e sincronização de arquivos: https://rojo.space/docs/v7/project-format/

## Fluxo de mudança

Uma funcionalidade por alteração. Registrar regra e referência, implementar no módulo responsável, testar casos relevantes, atualizar documentação e gerar o place. Adotar Git como próximo passo para histórico; este diretório ainda não é um repositório. Alterações feitas diretamente nos scripts do Studio devem voltar para src para não se perderem na geração.
