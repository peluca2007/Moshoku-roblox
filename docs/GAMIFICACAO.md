# Gamificação do jogo

Direção do Pedro, 10/10/2026: o livro orienta o RPG, mas a experiência precisa funcionar como jogo e ser divertida. Clareza das decisões, ritmo e animações são parte do produto. Não basta uma regra estar implementada ou um teste passar. Mudanças numéricas e adaptações continuam rastreáveis em FIDELIDADE; o servidor decide resultados.

## Primeira rodada: G1

Antes, o turno abria uma lista longa de cartas e algumas ações de utilidade ficavam apenas no registro. Agora:

- **Escolher por intenção:** Golpes reúne ataques e perigos; Apoio reúne preparação, cura, controle e utilidades. Tudo conserva a consulta completa, incluindo passivas e cartas ainda manuais.
- **Entender o impedimento:** falta de Ações, PM, PT, uso já gasto e personagem caído aparecem na própria carta. Essa indicação é uma ajuda local; o servidor continua revalidando.
- **Saber quando agir:** uma vinheta anuncia sua vez e outra nomeia a ação confirmada, com dano/cura/crítico quando vierem no recibo. Resultados recebidos mostram apenas os alvos do próprio jogador; a ação dele pode resumir os alvos visíveis enviados pelo servidor. Nada é anunciado por previsão de dano.
- **Concluir sem armadilha:** gastar todas as Ações destaca Encerrar turno. O jogo não passa a vez automaticamente, porque ainda pode haver ações gratuitas úteis.
- **Sentir a identidade:** Bardo conduz as canções com braços e ondas ritmadas; Tático indica o alvo; Ladino se recolhe ao se esconder e tem dois cortes rápidos no Primeiro Golpe. Animações locais, canceláveis e limitadas; não movimentam a ficha autoritativa. Modo reduzido evita as cenas novas dessas três famílias.
- **Caber na tela:** a barra centraliza em janelas médias, muda para duas colunas em largura reduzida e usa controles de pelo menos 44 px. Prévia de largura não equivale a teste em celular físico.

## Polimento G2: acompanhar a luta

A fila começa no ator atual e continua pela iniciativa, voltando ao início ao alcançar o fim. Agora/Depois/A seguir deixam a sequência explícita. A largura fica limitada à janela e a rolagem horizontal dá acesso à fila inteira; cartas ficam menores quando a faixa estreita. Atualizar PV não interrompe a navegação; trocar o ator volta ao início. Não se prevê quem será eliminado nem se muda a iniciativa. Se o ator não está entre as fichas visíveis, a fila começa no próximo visível e o identifica como tal.

O rodapé mostra o total de participantes visíveis e a rodada quando não há contagem de tempo; com prazo, mantém o contador autoritativo. O HUD já abre com o snapshot disponível. O antigo letreiro de turno do BoardView foi retirado após a captura real mostrar sobreposição com RitmoCombate; a fila permanece, e a vinheta anuncia a própria vez. Os banners de vitória/derrota desta etapa foram substituídos pelo painel persistente ResultadoView na G11.

## Qualidade de vida G3: entender e confirmar a ação

Toda carta tem **?** para ler o texto completo e o custo, sem selecionar alvo nem gastar Ações. Cartas bloqueadas e passivas também abrem a consulta ao clicar no corpo. O motivo de impedimento acompanha snapshots enquanto a janela fica aberta; a descrição permanece legível mesmo sem recursos. Quando há texto adicional do catálogo, aparece sob **No livro**, separado da descrição usada pelo jogo. Passivas/ações de consulta não recebem custo zero inventado.

Miras sobre si exibem **Usar habilidade**; listas exibem **Confirmar N alvos**, desativado até selecionar alguém e enquanto faltar recurso. O segundo clique existente continua disponível. Consultar cancela a mira anterior, e trocar de turno/encerrar combate fecha a consulta e limpa a seleção antiga. Trocar de aba volta ao início da lista. São melhorias de navegação e intenção: o servidor mantém todas as validações e decide resultados.

## G4: responder sem perder a leitura

Reações têm texto completo, rolagem, prazo em segundos e Deixar passar fixo. Atalhos informados ignoram digitação. A janela fica acima do menu; expirar visualmente não inventa resposta ao servidor.

## G5: jogar com a identidade elemental

Fogo passa a ter preparação e recompensa: Bola de Fogo (2 Ações) acende, Brasa (1 Ação) aproveita +1d4 contra Em Chamas. Fagulha deixa de cobrar mana por um efeito apenas visual: prepara uma casa perigosa por duas rodadas. O braseiro é baixo, tem chama menor e aviso de dano; não parece uma parede. Vento pode empurrar através dele, aproveitando cooperação já suportada pelo movimento autoritativo. Aliados também correm risco.

As páginas de Fogo, Água, Vento e Terra mostram Como jogar: sequência de técnicas, utilidade tática e cuidado com aliados/condições/terreno. Conhecida/Aprenda abaixo relaciona o guia à ficha atual sem comprar automaticamente. Água explica Molhado → frio; Vento, posição → empurrão; Terra, contenção → tiro e bloqueio de passagem. Técnicas adaptadas mostram No jogo antes do texto No livro. Aprender/abrir ranks usam botões de 44 px. Não se acrescentaram classes ou ranks nem se reequilibraram todas as árvores.

## Critério para as próximas rodadas

Uma ação deve responder: o que posso fazer agora, onde posso usar, o que aconteceu e como isso me aproxima da vitória. Explicações longas do livro ficam na consulta; o turno apresenta escolhas. Cada árvore precisa de um jeito reconhecível de jogar e de se mover. Menos tempo sem decisão e menos cliques sem propósito são prioridades. Animação deve ter preparação, execução e resposta coerentes, preservando a leitura do campo.

Esta rodada não reequilibra classes nem fecha a gamificação de todos os sistemas. Ritmo percebido, estética e diversão precisam de avaliação humana após os testes técnicos. Multiplayer real, celular físico, sensação dos impactos, telegráficos de criaturas comuns, resultado de partida e identidade das demais técnicas continuam candidatos de evolução, sem ampliar ranks ou classes.


## G6: mais decisões, menos travas

Esconder passa a ser uma escolha de posição: cones curtos na direção de cada inimigo, com contornos de cores distintas e setas, visíveis ao consultar a carta ou mirá-la. Sair do cone/cobertura funciona sem rolagem adicional; cruzar a visão revela. O Ladino consegue preparar sua abertura sem depender de todos os inimigos falharem em um teste.

Levantar tem botão próprio, custo e movimento restante visível. Zero PV pede cura; recuperar PV devolve o corpo à pose normal. A queda preserva a raiz vertical para não tombar a câmera. Armas largadas ficam legíveis no chão. Tooltip explica alcance, dano, acerto, CD, duração, limites e consequências, com rolagem para texto longo; não gasta a ação. Feedback diferencia resistência de efeito confirmado.

Ajuste inicial dos modos de jogo: +2 no acerto e +3 nas CDs, sem aumentar dano/custos. Fichas de mesa preservadas. Detalhes e limites em FIDELIDADE §7Q. Celular está fora desta etapa por pedido de Pedro; foco em mouse/teclado. Console físico e configurações de disponibilização ainda precisam de validação.

Organização pedida por Pedro: módulos específicos para regra, consulta e apresentação. Mapa de manutenção em MANUTENCAO.md. Não implica que toda a base antiga já tenha sido refatorada.


## G9: apoio consultável durante a luta

O painel do Bardo começa compacto. Canção, usos de Inspiração e quantidade de fichas visíveis com bônus permanecem à vista; Detalhes abre beneficiados e regras de combinação acima das cartas. Recolher devolve espaço ao campo. Bônus próprios entram na lista; não se deduz identidade de beneficiados ausentes do snapshot. O servidor continua decidindo canção, alcance, custo e efeitos.


## G10: espaço para decidir e entender recusas

A barra não reserva uma segunda linha vazia para poucos golpes. Janelas baixas mantêm uma linha rolável; janelas altas permitem até duas conforme o grupo. Cartas, consulta, confirmação e controles continuam disponíveis. Erros confirmados pelo servidor agora aparecem em aviso fechável durante o jogo, sem exigir abrir o registro. O texto dita o tempo de leitura e a altura; uma recusa nova substitui a anterior sem ser apagada pelo temporizador antigo.

## G11/G12 — mirar, preparar e concluir

A mira nomeia a ficha sob o mouse, distância e alcance; destaca candidatos visíveis e escolhas de vários alvos. Zonas/cones/círculos mostram a área preenchida. Fixar a área é uma etapa de escolha, sem custo; só a confirmação lança. Muro de Chamas permite início vizinho, direção e comprimento de 1–6 casas, sem curvas, com opção de trocar início. Limites continuam no servidor.

O Ladino passa a ter exclusividade de Esconder por sua árvore, além de Dano Furtivo e Primeiro Golpe. A restrição também vale para pedidos remotos. Pedra sólida fecha frestas visuais e visão por quinas; passagem realmente aberta no mapa continua aberta.

Golpes têm preparo mais legível; falhas desviam o corte e não recebem faíscas de acerto no bloco de golpes revisado. Críticos têm clarão maior. Goblins/bandidos ganham detalhes soldados ao rig; bestas têm volumes, focinho/patas e o urso mantém presas distintas. Ao fim, o evento confirmado abre resultado persistente, com retorno ao campo ou à escolha da próxima partida, substituindo o banner antigo.
