# Arquitetura atual

Consolidada em 14/10/2026. Este arquivo orienta o trabalho atual; detalhes por módulo ficam em [MANUTENCAO.md](MANUTENCAO.md). A versão anterior foi preservada integralmente em [histórico](historico/ARQUITETURA-2026-10-13.md), incluindo decisões e limites de testes. Não é leitura inicial obrigatória.

## Produto e limites

W1b (17/10): o servidor observa presença nas regiões/trechos e o tempo contínuo da run; viagem por painel/teleporte regional saiu do fluxo. Um dia dura 480s e pausa em combate. Caçadas e patrulhas adicionais usam o J2/R2 existente, com um encontro ativo por servidor; ficha mantém árvore inicial e lista adicional aprendida por concessão interna. Contratos e localização em [MANUTENCAO](MANUTENCAO.md#mundo-aberto-w1b-17102026); limites verificados em [TESTES](TESTES.md). Sem Studio nesta entrega.

RPG com exploração livre e combate por turnos. A direção é mundo aberto; começar por uma pequena região conectada, com caminhos e pontos de interesse. O jogo deve funcionar sem mestre humano; preservar o núcleo compartilhado para um futuro modo com mestre. O lobby atual ainda tem o papel de mestre na preparação: a direção futura não significa que essa dependência já foi removida.

Hoje há sala social, Treino, Desafios, PvP, ferramentas de mesa e um perfil pessoal persistido limitado às escolhas J1/J3a. Criação completa, mundo aberto e progressão/recompensas persistentes seguem como evolução. O combate clássico do primeiro protótipo está pausado e não é inicializado. A integração CLEG de 19/10 foi revertida; CombatService/BattleController/CameraController originais permanecem pausados. Patrulhas e chefes usam o combate J2 de exploração. A verificação do protótipo original está em andamento; estado e evidências em [TAREFAS](TAREFAS.md) e [TESTES](TESTES.md).

## Responsabilidades existentes

Durante J2, `EncontroAutonomoAvatares` aplica às personagens reais a posição recebida do estado autoritativo; o serviço restaura controles e posição ao descartar o encontro após retorno ou limpeza.

| Camada | Responsabilidade |
| --- | --- |
| Entradas server.server/client.client | Inicializar módulos |
| Servidor | Autoridade sobre regras, estado, permissões, recursos e recompensas |
| Shared/Regras e módulos puros | Cálculos sem Instances/rede; RNG e contexto injetados |
| Shared/Livro | Catálogo gerado a partir do site; não editar dados gerados |
| Cliente | Intenção, interface, câmera, som e animações de resultados confirmados |

MesaService integra o estado e os comandos; EncontroService/TreinoService coordenam partidas; HabilidadeService resolve habilidades; SalaService coordena o lobby. MesaPersistence guarda campanhas. Não confundir essa persistência com o futuro perfil do jogador.

O núcleo J2 combina `shared/EncontroTurnos`, `EncontroIniciativa`, módulos puros de elenco/movimento/mapa/combate, `server/EncontroAutonomoService` e apresentação cliente. O servidor inicia com perfis J1 validados e criaturas canônicas, controla ação, recurso, alvo, efeito, versões e recibos; cliente envia intenção. Habilidades elegíveis de Fogo, Vento, Água, Cura e Terra usam catálogo e executor canônicos; a lista atual e as adaptações estão em [JOGO.md](JOGO.md) e [FIDELIDADE.md](FIDELIDADE.md). Quatro rochas do bosque bloqueiam movimento, rotas da IA, empurrões e visão; linha de visão usa supercobertura também para Muro de Chamas. Turnos individuais expiram automaticamente após 60 s, sem pausa por desconexão; o grupo recebe recibos, mas snapshots e reconexão ficam privados. O mapa 20×20 representa o estado confirmado e não move avatar; o serviço sincroniza avatares/miniaturas pela geometria do marco escolhido. J4 mantém dois marcos ligados por trilha; inspeção visual, combate completo no bosque, multiplayer real e recompensa permanecem pendentes. FIDELIDADE e TESTES registram detalhes e evidências.

Separar responsabilidades gradualmente, preservando testes. Agrupar arquivos por sistema dentro de servidor/cliente/shared quando a mudança tiver escopo verificável; não criar pastas ou módulos vazios antecipadamente. Atualizar MANUTENCAO ao mover um comportamento e conferir gerador/sincronização ao mudar caminhos. Em J2, `EncontroAutonomoMiniaturas` desenha no mundo apenas posições confirmadas; as peças são cosméticas, não colidem e não comandam avatares.

## Contratos que continuam valendo

- Cliente envia intenção. Servidor valida tipo, contexto, controle, turno, recursos, alcance e frequência. Contratos da mesa: [MESA.md](MESA.md); requisitos de evolução do jogo: [PLANO.md](PLANO.md), §11; contratos atuais do jogo autônomo: [JOGO.md](JOGO.md). Lacunas ali descritas continuam pendentes até serem implementadas e verificadas.
- Revalidar estado após esperas; decisões antigas não autorizam ações sobre estado novo. Deduplicação e recompensas persistentes devem impedir aplicação dupla conforme o contrato de cada fluxo.
- Snapshot/recibo é filtrado por observador. Fichas ocultas, sons e efeitos não podem revelar informação secreta. Avatar de jogador replicado não serve como ficha secreta.
- Animação não autoriza dano nem avanço de turno. Efeitos persistentes precisam ser reconstruídos do estado.
- Catálogo, construção da ficha e estado da sessão são conceitos separados. Importação de mesa depende do mestre; no jogo, construção/progressão precisam ser validadas no servidor.
- PA de aprimoramento não é orçamento de ações. Adaptações do livro ficam em [FIDELIDADE.md](FIDELIDADE.md).
- A tela `ArvoresView` permanece no fluxo de fichas v2; o serviço atual modifica a ficha da mesa. O perfil pessoal é separado por UserId e por armazenamento de campanhas; XP/recompensas seguem sem fonte aprovada em [JOGO.md](JOGO.md).
- `PersonagemSessao` valida entradas e compras, enquanto `PersonagemPersistencia` grava construção, nome filtrado e IDs comprados. No carregamento, o servidor recalcula corpo/estatísticas e valida novamente a progressão. Treino, Luta e Duelo montam token por API interna; perfil não entra em snapshot/campanha. O DataStore de teste do Studio exige scope isolado e nunca usa a chave de produção.

## Evolução aprovada em 13/10/2026

- Exploração aberta como direção; encontros aleatórios podem existir dentro do mundo, sem impor uma campanha linear como estrutura principal. Combate tático por turnos é essencial; referências de jogos orientam experiência, não substituem regras do livro.
- Avatar Roblox agora. No futuro, aparência criada no jogo, separada de ficha, atributos e equipamentos mecânicos; não refazer combate para trocar visual.
- Priorizar modelos gratuitos e código aberto úteis antes de recriar. Ao adotar: registrar origem, autor/ID, licença ou termos, versão e alterações; verificar scripts/dependências, rig, colisões e custo no dispositivo alvo. Gratuito não significa automaticamente código aberto. Importar e testar de forma isolada antes de integrar.
- Mestre futuro usa os mesmos comandos validados que jogador/IA, com permissões explícitas; manter essa possibilidade sem atrasar o jogo autônomo.
- Game passes começam por cosméticos/identidade. Centralizar catálogo comercial e benefícios no servidor; não misturar compra com cálculo de combate. Perfil e entrega confiável precedem loja. Produtos e preços ainda não foram cadastrados.

## Verificação e leitura

Antes de marcar tarefa pronta: tools/testar.ps1 com RESULTADO: tudo ok. Mudanças de runtime exigem playtests pertinentes no Studio; testes locais não provam rede/renderização. Quatro clientes, reconexão, duplicação e desempenho são critérios relevantes conforme o sistema. Situação e evidências: [TESTES.md](TESTES.md).

Leitura inicial: README, este arquivo e tarefas relevantes de TAREFAS. Para colaboração, COLABORACAO e registro pertinente de COORDENACAO. Consultar MANUTENCAO para localizar o comportamento; abrir contratos e histórico apenas quando o assunto exigir. Pendências externas e limitações de verificação nunca desaparecem numa limpeza.
