# Matriz de fidelidade inicial

## CLEG — registro arquivado e revertido (19/10/2026)

A descrição de regras experimentais do protótipo clássico registrada durante CLEG foi revertida e não define o comportamento atual do jogo. O protótipo está pausado; patrulhas e chefes continuam usando J2. Nenhum valor desta seção deve ser tratado como regra implementada ou vigente. Histórico da integração/reversão e evidências preservados em [TAREFAS](TAREFAS.md) e [TESTES](TESTES.md).

## W1b — exploração, tempo e aprendizagem (Pedro, 17/10/2026)

Decisão de produto, sem mudar dados/cálculos do site: a viagem por painel de R4 está **superada**. Destinos são alcançados a pé pela geografia existente, incluindo PASSAGEM W1a. F8 permanece inteiro como eventos de caminho, uma vez por trecho/run; sorteio, votos nas escolhas, perícias/defeitos e consequências reutilizam os executores existentes. Mapeamento em [MANUTENCAO](MANUTENCAO.md#mundo-aberto-w1b-17102026). Não há novo benefício de velocidade de cavalo; Explorador conserva peso nas decisões e influência nos eventos, sem uma viagem abstrata.

O relógio autoritativo da run usa 480s/dia, começa às 06h e pausa no combate. `dia` passa a ser contínuo, não limitado a quartos; save antigo continua válido. Prazo expira quando tempo atinge o limite, sem encerrar automaticamente a run. Descanso curto soma 2h; longo e provação aprovada pulam à próxima manhã, uma vez por operação confirmada. Esta cadência é gamificação aprovada pelo Pedro, não regra nova de turno. Os custos de dias próprios de F8 permanecem consequências explícitas. Perfis de zona são modulados pela hora.

Caçadas: 3 ofertas distintas dentre 4, pessoais/repetíveis dentro da run, com bônus provisórios de 8/10/12 PO e **1 PA de aprimoramento**, além do espólio J2 existente. N6b não está implementada; o bônus específico fica em `perfil.paGanhos`, persistido no mesmo recibo do ouro. Progressão ainda mantém `PA_INFINITO=true`: não se afirma que exista um orçamento finito de compra. PA nunca significa Ações do turno. Quadro original de Parts, sem asset externo; substituição estética pelo Blender pendente.

Patrulhas usam R2/J2, sem combate paralelo: uma silhueta por grupo, um encontro por servidor; reaparecimento após 120s do relógio da run, nunca durante combate. Ratos/goblins nos arredores, batedores na trilha e lobos/aranhas/urso na floresta (curva B1 em N9), bandidos na passagem, goblins/golem menor nas Ruínas. Criaturas usam fichas canônicas, sem novo ataque especial de golem. Guardiões e o mecanismo existente do Treant permanecem; não se rebalanceou R7b. O arquétipo `fortaleza` ainda cai no multiplicador padrão de espólio legado (RecompensaEncontro só nomeia `tanque`); isso não altera a ficha de combate.

**Segunda árvore na ficha (substitui a limitação P2/T1 abaixo):** a concessão da provação é sincronizada pelo servidor como `arvoresAprendidas`, mantendo `startingTreeId`. Abre o rank Principiante pelo mesmo contrato da inicial (`unlockedRankIds`), sem conceder compras pagas: cartas de custo zero aparecem automaticamente; demais são compradas pelo caminho de progressão existente e então aparecem no J2. Perícias adicionais usam `masterySkillsWhenNotFirst` já portado. PV permanecem os da inicial; recursos usam as fórmulas existentes da categoria, sem somar duas vezes árvores da mesma categoria. Aumentar máximos não repõe recursos já gastos. Lista adicional e PA sobrevivem ao save/recalcular; lista inválida é recusada. A trava provisória de uma segunda árvore por run permanece em RunTreinadores; o armazenamento suporta lista para extensão futura. Sem alteração do livro/site.

## F6 — Ruínas: arena e patrulha (15/10/2026)

Adaptação espacial: `region/encounter/ruinas` ocupa a praça da câmara, centro (600, −262), grade 20×20 de 1,8 studs/casa. Colunas e altar permanecem no layout; casas que intersectam suas bases giradas são bloqueadas conservadoramente para movimento e visão. Formação inicial coloca aventureiros ao sul e goblins ao norte do altar; não altera atributos ou regras do livro. O campo `areaId` é a única mudança no nó `chefe-ruinas`.

O guardião continua sendo o bando provisório: **2 Goblins Batedores lacaios por jogador**, peso 0,5 cada, orçamento total N para N jogadores (Equilibrado, Apêndice G). Uma silhueta de goblin representa a patrulha visível: ela inicia **N goblins lacaios para N jogadores próximos** (peso 0,5N, ameaça baixa), reutilizando o orçamento do catálogo da clareira. Entradas tardias seguem R2d, sem acrescentar criaturas depois do início. A patrulha original da clareira conserva seu contrato anterior.

Cone, perseguição, contato, surpresa, fuga e retorno usam R2a–R2d; encontro começa no contato, com terreno amostrado pelo servidor. A arena privada guarda a origem para liberar somente essa patrulha no retorno. Recompensa/progresso da patrulha das Ruínas usa o marco das Ruínas, sem contar missão da clareira. Permanece um encontro ativo por servidor, inclusive terminal aguardando retorno. RNG continua injetado no J2; nenhum cálculo/dado do site foi alterado. Verificações e limites em [TESTES](TESTES.md).

## G15 — dados físicos e amigos nas mãos (11/10/2026)

Adaptação social pedida diretamente por Pedro, inspirada em Garry's Mod/R.E.P.O./PEAK: trio de dados com quique e carregar brevemente outro avatar admitido no lobby. Física é apresentação de três d6 decididos no servidor; o pouso confirma Brotos/eleição, sem substituir a classificação aprovada nem conceder recursos. Recolhimento confirma lançamento aceito, sem nova rolagem. Prazo aguarda lançamentos já em voo.

Carregar jogador não é agarrão do combate: não consome Ações, não causa dano nem arremessa. Alcance, paredes, mãos livres, timeout e soltura pelo alvo protegem a mobilidade, com estado restaurado. Não muda números/cálculos do livro ou site. Os modelos são nativos; nenhum asset pago, script externo ou dependência foi adquirido.

## G13/G14 — sala social, objetos e Brotos (11/10/2026)

Adaptação de interface autorizada diretamente pelo Pedro: lobby caminhável, seis admitidos até dez por aprovação, personagens exclusivos salvo cópia, prontidão de metade, mestre inicial/transferência consentida e eleição após saída. Detalhes registrados em DISCUSSOES D-G13 e MESA; não são regras do livro de combate. Esse fluxo substitui a seleção manual de papel da G8, mantendo permissão ADM independente.

Dados do Brotos usam três d6 e a classificação aprovada para a sala: trio > sequência > dupla; 111 é o melhor trio. Eleição resolve o posto de mestre; rodada recreativa é outra funcionalidade, com uma rolagem por admitido, conclusão automática após 15 s e vitória compartilhada em empates. Nenhuma dessas rolagens aplica dano, teste de personagem, recompensa ou gasto de recurso. Resultado sempre decidido no servidor, RNG injetável nos módulos puros.

Papéis/livros/arremessos/braços e decoração são cosméticos. Copiar, soltar, entregar ou recolher uma folha não troca a reserva de personagem; Assumir continua sendo intenção validada pelo servidor. Livros não concedem inventário nem equipamento. A trajetória não tem colisão/dano/empurrão. A câmera de início e a preparação usam os modos existentes, sem alterar números, habilidades ou cálculos exportados. Nenhum conteúdo do site do livro, modelo pago ou nova dependência foi alterado/adquirido.

Tarefa T20 — Codex. Versão inicial, 08/10/2026.

Referências: `docs/PLANO.md`, `docs/MESA.md` e `docs/CONTRATOS.md`.

Este documento inventaria regras, adaptações e lacunas. Não implementa regras nem declara o simulador como motor definitivo do livro.

## 1. Como ler a matriz

### Classificação

- **Livro:** comportamento respaldado pelo conteúdo do site/livro citado. A classificação pode ser provisória até conferir a implementação e a fonte integral.
- **Adaptação explícita:** escolha técnica, aproximação ou heurística que não equivale à regra integral.
- **Arbitragem:** decisão humana necessária na mesa. No RPG, exige estruturação da regra ou exclusão explícita do conteúdo automatizado.

Uma família pode conter as três classificações. Classificar a representação de uma condição como fiel não significa que seus efeitos mecânicos estejam implementados.

### Estado no Roblox

- **Automatizado:** o servidor ou módulo puro já executa o comportamento indicado.
- **Mesa manual:** o mestre usa os controles e julga/aplica a regra.
- **Não existe:** não há representação ou execução específica confirmada.

Quando parte está automatizada e parte é manual, ambas aparecem na coluna.

### Evidência de testes

Os testes e playtests existentes foram relatados por Claude e documentados no projeto. Esta entrega documental não os executou novamente.

- **D:** specs de `Dice` no harness/TestRunner.
- **I:** `FichaImport.spec.luau` e testes da exportação `codigoDeMesa` no site.
- **C:** `CondicaoRules.spec.luau`, 15 testes relatados.
- **S:** `MesaSave.spec.luau`, 26 testes relatados.
- **P:** fixture do painel, incluindo callbacks, permissões e apresentação.
- **ST:** playtests MCP de mesa, campanha, fechamento, M4/M5, visibilidade e cliques reais.
- **Nenhum confirmado:** não foi fornecida evidência de teste específico dessa regra no Roblox.

Esses marcadores demonstram cobertura dos módulos existentes, não paridade completa com o livro. `docs/TESTES.md` deve registrar roteiro, revisão testada, resultado e limitações.

## 2. Fontes e limites desta versão

Fontes fornecidas para esta matriz:

- Interfaces `CharacterData`, `Tree`, `TreeRankDef`, `AbilityDef`, `TalentDef`, `MasteryDef`, `PurchasedAbility`, `UnlockedRank`, `Acao` e `EventoAtaque`.
- Lista de seletores exportados de `src/store/selectors.ts`.
- Exports e as 24 entradas de `SIMPLIFICACOES` de `src/lib/combatSim.ts`.
- Contratos atuais da mesa em `docs/MESA.md`.

Os nomes de funções indicam onde investigar; não substituem a leitura dos corpos das funções. Referências de capítulo só são usadas quando aparecem nos trechos fornecidos.

Antes de automatizar uma regra:

1. Conferir o conteúdo atual do site e suas dependências.
2. Registrar a referência exata e a versão da fonte.
3. Separar comportamento do livro de aproximação do simulador.
4. Criar casos diferenciais e invariantes independentes.
5. Registrar explicitamente os casos não suportados.

## 3. Matriz por família

| ID | Família e fonte | Classificação inicial | Roblox hoje | Testes existentes | O que falta |
| --- | --- | --- | --- | --- | --- |
| FID-01 | Fórmulas de dados. `combatSim.rolarDados`, `rolarFormula`, `mediaFormula`, `maxFormula`; `Dice.parse/roll` | Livro para rolagem; adaptação explícita para a gramática aceita pelo rolador | Automatizado: interpretar e rolar fórmulas suportadas | D, P, ST | Comparar gramáticas, arredondamentos, sinais e resultados com o rolador efetivamente usado pelo site; não presumir equivalência |
| FID-02 | Vantagem/desvantagem e modalidades absolutas. Cap. 4; `d20Ajustado`; `Dice` | Livro para modalidades; adaptação explícita para elegibilidade da fórmula no Roblox | Automatizado: cinco modos; modo só afeta o único d20 somado | D, P, ST | Testar cancelamento, origem das vantagens e modalidades absolutas na execução de habilidades; verificar se o simulador cobre as cinco modalidades |
| FID-03 | Ataque e acerto. `getAttackBonus`, `autorizarAcao`, `resolver`, `executarAtaquePersonagem` | Livro nos testes estruturados; arbitragem nos contextos não estruturados | Mesa manual: rolagem livre e julgamento; não há ataque de habilidade autoritativo | D valida dados, não resolução | Defesa correta, contexto de árvore/arma, aquisição, alvos, alcance, restrições e recibo |
| FID-04 | Crítico e falha. `EventoAtaque.critico`; Cap. 4; `Dice` | Livro para indicação de natural; adaptação explícita para elegibilidade do d20 | Automatizado: indicação de crítico/falha no rolador; dano e consequências manuais | D, ST | Regra integral de dano crítico, exceções, crítico automático e interações com resistência/reação |
| FID-05 | Dano, BC, parcelas e tipos. `resolver`, `partesDoDano`, `aplicarDano`, `AbilityDef.damage` | Livro para parcelas explicitamente tipadas; adaptação explícita nos legados e contextos aproximados | Mesa manual; ajuste de PV automatizado como operação administrativa | D, P, ST não comprovam regra de dano | AST ou representação equivalente; BC por contexto; resistência, imunidade, redução, dano temporário e ordem das operações |
| FID-06 | Resistência e CD. `getSpellDC`, `getMaiorBonusDeRank`, `resolver`; Apêndice G | Livro para fórmulas citadas; adaptação explícita para atributo intermediário e boneco sem ficha | Mesa manual | Nenhum confirmado para resolução | Atributo exigido por ação, fonte da CD, resistência de criatura e arredondamento da metade do Rank |
| FID-07 | Construção e valores derivados. `selectors.ts`; `getFinalAttributes`, `getMaxHp/Mp`, `getPtPool/PpPool`, `getArmorClass` | Livro, provisório até conferir seletores e overrides; arbitragem para alterações do mestre | Automatizado: importação v1 de um subconjunto; edição manual de PV/mana | I, S, P, ST | Ficha v2, escolhas raciais/de árvore, perícias, equipamentos, contextos e legitimidade no RPG |
| FID-08 | Recursos PV, PM, PT e PP. `getCurrentHp/Mp/Pt/Pp`, `Acao`, `AbilityDef` | Livro para recursos; arbitragem para edição da mesa | Automatizado: armazenar/ajustar PV e mana; PT/PP não existem no token atual | I, S, P, ST | PT, PP, máximos, custos condicionais, reserva/consumo por etapa e atomicidade |
| FID-09 | PA de aprimoramento e progressão. `getPaSpent`, `canUnlockRank`, `canPurchaseAbility`, custos dos seletores | Livro; adaptação provisória aprovada: PA infinito até Intermediário | J1 mostra saldo após escolha de raça; compra em sessão só de habilidade elegível do rank já aberto; PA não é consumido | Specs `Progressao`, `PersonagemSessao` e `FichaPersonagemProprio` | Abrir rank, XP, persistência e compras de item; nunca confundir PA com Ações |
| FID-10 | Economia de Ações, concessões e limites de uso. `Acao.acoes/limite`, `limiteDeUso`; Cap. 4, §4–5 | Livro: 3 Ações por turno; adaptações específicas continuam descritas nas linhas de origem | J2 autônoma guarda 3 Ações; ataques de jogador e IA consomem 1, versionados/idempotentes; outras ações/concessões ainda ausentes | Specs de `EncontroTurnos` e serviço | Ligar custos próprios restantes, concessões, contador por combate, reações e regras específicas de chefe |
| FID-11 | Condições: catálogo, acúmulos e transformação. `condicoes.ts`, `getCondicoesAtivas`, `getEfeitosDeCondicoes`; Cap. 4, §2 | Livro para representação do catálogo; pontos de divergência pendentes | Automatizado: catálogo, adicionar/remover, acúmulos, transformação e persistência; efeitos de combate manuais | C, S, P, ST | Conciliar Dose/Colapso/Atordoado; distinguir teto global de teto por aplicador; modelar origem quando necessário |
| FID-12 | Duração e término de condições | Livro para referência em prosa; arbitragem para interpretação contextual | Automatizado: referência e nota; sem contagem numérica ou expiração automática | C, S, P, ST | Política por efeito estruturado, gatilhos de término, relógios de turno/rodada/tempo; não inventar duração de condição |
| FID-13 | Molhado, Congelado, Em Chamas, Quebrantado, Dose e Exaustão. `resolver`, `indicesDeFrio`, `tickChamas`, `transbordarDoses`, seletores | Livro nos efeitos confirmados; adaptação explícita nos casos legados; divergências pendentes | Mesa manual para efeitos; marcas de condições automatizadas | C comprova marcas, não efeitos | Dobra só da parcela fria, consumo de Congelado, dano periódico, autoria e penalidades |
| FID-14 | Reações, interceptação, aparar, redução e suporte. `consumirReacao`, `amortecerComBarro`, `reagirAFalhaAliada`, `Acao` | Livro para cartas; adaptação explícita nas aproximações de redução e alcance | Mesa manual | Nenhum confirmado para execução | Janela de decisão, prioridade, consumo único, ordem de modificadores e restrições de voz/percepção |
| FID-15 | Conjuração contínua/dividida e concentração. `testeDeConcentracao`, `perdaDeFoco`, `turnoPersonagem`; Cap. 4, §3 | Livro para mecanismo descrito; adaptação explícita nas escolhas de IA e cobertura parcial | Mesa manual; Conjurando pode ser marcado, sem máquina de estados | C para representação apenas | Etapas, PM investido, interrupção, perda/reembolso, reação durante cântico e cura/escudo prolongados |
| FID-16 | Sustentados e manutenção. `exigeManutencao`, `separarSustentado`, `tickSustentado` | Adaptação explícita: três turnos na bancada; livro/arbitragem para duração real e permanência na área | Mesa manual | Nenhum confirmado | Duração original, manutenção, entrada/saída, área persistente, origem, término e retomada por snapshot |
| FID-17 | Movimento, distância, alcance e áreas. `dependeDePosicao`, `alvosNaArea`, `limiteDeAlvosNaArea`; `MesaProtocol` | Adaptação explícita para grade e áreas abstratas; arbitragem para terreno e linha de visão | J2 fixa posições iniciais, permite movimento até o deslocamento da ficha, bloqueia atores/rochas nas rotas e usa supercobertura para visão através de rochas/Muro; sem mudança em alcance/cobertura | Specs de caminho/visão/serviço e Studio TestRunner; clique visual da grade ainda não confirmado | Terreno difícil, cobertura, oclusão de outras geometrias, movimento forçado e escala no mundo continuam ausentes |
| FID-18 | Névoa, ocultação e percepção | Adaptação explícita de visibilidade da mesa; arbitragem para percepção do livro | Automatizado: projeção de fichas, atributos, logs e rolagens conforme visibilidade | ST | Percepção mecânica, furtividade, audição; aplicar política também a recibos e efeitos futuros |
| FID-19 | Armas, proficiência e Dados de Arma. `getWeaponDamage`, `getWeaponGroups`, `isProficientWithWeapon`, `temDesvantagemPorArma` | Livro para proficiência/degraus; adaptação explícita para arma d6 de referência e tipagem ausente | Mesa manual; inventário não existe no token | Nenhum confirmado | Equipamento escolhido, contexto de atributo/Rank, grupo, tipo físico e referência estável ao item |
| FID-20 | Cura, PV temporários e Ferida Fresca. `curar`, `darPvTemp`, `prepararSuporteDoTurno` | Livro para cura; adaptação explícita para janela causal de Ferida Fresca e heurística de IA | J2 mede dano após a última vez do curador; Vigor Emprestado mantém o maior PV temporário sem acumular, absorve antes dos PV reais e dura 100 rodadas ou até o fim do encontro | Specs de helper/serviço e TestRunner do Studio; veja RB-38 | Marcas da Morte continuam manuais; PV temporários só são concedidos pela habilidade implementada |
| FID-21 | Inconsciência, morte, Fio da Vida e estabilização. `testeDoFioDaVida`, `aoIniciarRodada`; Cap. 4, §7 | Livro para mecanismo descrito; adaptações/omissões da bancada | Mesa manual; PV pode chegar a zero sem aplicação automática dessas regras | ST para PV apenas | Marcas, responsável, crítico contra adjacente caído, Medicina, despertar, Exaustão e criaturas |
| FID-22 | Descanso, recuperação, trauma e cicatrizes. Site `src/lib/descanso.ts` (Cap. 4, §7), `CharacterData.descansosCurtos/mesa` | Curto: 25% PV/PM/PP (arredondado para baixo) e PT inteiros; no máximo 2 até Longo. Longo (8 h seguras): 25% PV + Vigor + 2×maior bônus de Rank (mínimo 1), todos PM/PT/PP; ganhos limitados aos máximos. | W1 implementa esses dois descansos apenas no acampamento; servidor valida vida, combate, distância fixa de 10 studs, linha de visão por raycast e frequência. Normaliza prompts reutilizados. Persistem recursos atuais e contador no registro J1. Trauma, sono perturbado, tratamento por kit, cicatrizes e Downtime ficam fora. | Specs puros e de serviço; execução Studio/local registrada em TESTES | Tempo seguro/ciclo de dia não simulado; sem consequências de Trauma/sono, cura por kit, Ferimentos, Downtime ou interface de ficha do site |
| FID-23 | Iniciativa, rodada e vez. `getInitiative`; `MesaService.rollInitiative/nextTurn` | Livro para bônus/vantagem importados; desempate automático por bônus maior e ordem de entrada conforme RB-13. Criaturas autônomas sem bônus no bestiário usam zero, mesmo fallback atual da mesa para token sem ficha | Automatizado: iniciativa informada/rolada, rodada, vez e proteção de clique duplo | Integrar surpresa, efeitos de início/fim, reação e orçamento; conferir desempate com a fonte |
| FID-24 | Salvações e prevenção de morte. `combatSim`, habilidades, `CharacterData.mesa.salvacoes`; Cap. 4, §5 | Livro para teto citado; adaptação explícita para contador parcial do simulador | Mesa manual | Nenhum confirmado | Contador compartilhado, elegibilidade, consumo e interação com Fio da Vida |
| FID-25 | Liderança e concessão de ações. `prepararSuporteDoTurno`, árvores correspondentes | Livro para cartas; adaptações de seleção/composição do cenário | Mesa manual | Nenhum confirmado | Preparação, organização, posição, aliados elegíveis e contadores |
| FID-26 | Bardo, inspiração e efeitos narrativos. `escolherSuporte`, árvore Bardo | Livro nas cartas; arbitragem para emoção/narrativa; adaptações de IA | Mesa manual | Nenhum confirmado | Alvos, voz, silêncio/surdez, escolhas de reação e efeitos não combativos |
| FID-27 | Invocação e pactos. árvores de invocação, `combatSim` | Livro para pactos; adaptação explícita para seleção automática e perfis resumidos | Não existe como subsistema; NPCs podem ser criados manualmente | ST para criação de token apenas | Aquisição, preparação explícita, limite, PM, controle, duração, perfis e efeitos próprios |
| FID-28 | Ladino, furtividade, surpresa, Primeiro Golpe e Fluxo. `aberturaFurtiva`, `motivoFurtivo`, `Acao.regra` | Livro nos mecanismos confirmados; arbitragem para segredos; adaptações por ausência de mapa | Mesa manual | Nenhum confirmado | Esconder-se, percepção, cobertura, elegibilidade, multiplicação de parcelas e reações |
| FID-29 | Bestiário, IA e comportamento de chefe. `bestiary.ts`, `preMadeMonsters.ts`, `escolherAcao`, `encounterSim` | Livro para dados; adaptação explícita para heurísticas e orçamento abstrato | NPCs manuais; IA não existe | ST para tokens, não IA | Catálogo, ações legais, percepção, tática, navegação e regras de chefe rastreáveis |
| FID-30 | Rituais, habilidades narrativas, perícias e escolhas. `AbilityDef.ritual/tempoDeRitual/grantsSkills`, talentos, maestrias, seletores | Livro para conteúdo; arbitragem enquanto execução não estruturada | Não existe na ficha v1; mesa manual fora do painel | Nenhum confirmado | Catálogo completo, pré-requisitos, escolhas, duração e efeitos não representados por `Acao` |
| FID-31 | Inventário, dinheiro, recompensas e legitimidade. `CharacterData.inventory/gold`, dados de itens | Livro para conteúdo; arbitragem para importação da mesa | Não existe como subsistema autoritativo | Nenhum confirmado | Instâncias de item, equipamento, concessões, transações persistentes e construção legítima |

## 4. Inventário das 24 entradas de SIMPLIFICACOES

A numeração S01–S24 corresponde à ordem das entradas fornecidas. Uma entrada pode misturar regra, adaptação, omissão, política de IA e histórico de bug.

| ID | Conteúdo inventariado | Classificação e encaminhamento |
| --- | --- | --- |
| S01 | BC apenas onde explicitado/Dados de Arma; impacto separado da parcela por turno; Inverter sem BC/teste; Quebra de Gelo contra Congelado sem d20/crítico; Molhado dobra só frio; Nova Congelante já dobrada; legados tratam dano integral como frio; Reação encerra cântico; IA não usa Fluxo durante cântico | Conferir regras individuais como livro. Tratamento de frio legado é adaptação. Separar regra de interrupção da política da IA. Testar parcelas e ordem das operações |
| S02 | Couraça de Barro exige ataque físico tipado, PM/Reação; orçamento abstrato não ativa; Refrão ocorre após falha restante, concede PV temporários sem empilhar, cobra PP/Reação; alcance 9 m quando há posição, presumido sem ela; voz/silêncio/surdez presumidos | Cartas são referência de livro. Alcance/percepção presumidos são adaptações. Não levar premissas de cenário para o mapa do RPG |
| S03 | Molhado, Congelado, Dose, Em Chamas, Quebrantado, Preso, Caído, Envenenado; condições/faixa de PV exigidas; agarrão presumido com +1 Ação; Exaustão 3 dá desvantagem; estados posicionais omitidos | Livro provisório nos efeitos; agarrão presumido é adaptação. Dose/Quebrantado exigem conciliação específica. Estados omitidos continuam manuais |
| S04 | Cura/PV temporários e dobra da Ferida Fresca; IA cura na metade ou abaixo e oferece casca a quem não tem | Cura é regra a conferir; limiar de cura e seleção são política de IA, não regra do livro |
| S05 | Sustentados duram três turnos, inclusive sete magias citadas; Tempestade Cortante originalmente dura um minuto/dez turnos | Adaptação explícita. Não usar três turnos como padrão no Roblox. Estruturar tempo, área e permanência |
| S06 | Reações de Aguentar, que reduzem dano, são aproximadas por PV temporários; histórico de leitura como dano causado | Adaptação explícita incompatível com resolução fiel. Bug antigo é histórico, não regra atual a preservar |
| S07 | Salvações, paredes, selos e fórmulas armadas omitidos; Parede de Emergência intercepta até 15 de ataque físico; cura secundária de Julgamento/Luz Absoluta omitida | Cobertura parcial. Conferir Parede como livro; omissão de cura não pode definir uma habilidade completa |
| S08 | IA maximiza dano esperado por Ação; não recua, concentra fogo, conserva recursos nem valoriza condições | Adaptação explícita de IA. Pode servir como baseline, nunca como política universal |
| S09 | Fio da Vida, inconsciência, marcas, cura, estabilização e despertar; dano a zero; IA só atinge caídos por área; Medicina, crítico adjacente e Exaustão de despertar omitidos; criaturas morrem a zero | Livro provisório nas fórmulas citadas. Separar política de escolha de alvo das omissões mecânicas. Conferir arredondamentos e exceções |
| S10 | Ferida Fresca aproximada por rodada desde o golpe; dobra dados e soma BC uma vez; dano absorvido por temporários abre janela; quantidade fresca não medida; histórico de janela/dobra diferentes | Adaptação explícita na janela. Conferir regra atual sobre absorção/quantidade; histórico não é especificação |
| S11 | Resistência com atributo e metade do maior Rank; criatura usa metade do ataque; personagem usa atributo intermediário contra ação de criatura; boneco usa metade do BC do atacante | Livro provisório nas fórmulas; atributo intermediário e boneco são adaptações, proibidas como fallback silencioso no RPG |
| S12 | Rank do patamar para CD de Fio/Concentração; arma escolhida/equipada para golpe; fallback d6 com aviso; técnicas compartilham BC da árvore inicial | Conferir CDs/arma como livro. Fallback d6 e BC inicial compartilhado são adaptações. Exigir contexto por ação |
| S13 | Histórico: motor matava a zero e distorcia probabilidades; Fio da Vida mudou resultados | Histórico explicativo. Não é regra nem critério de balanceamento obrigatório |
| S14 | Conjuração contínua/dividida, contribuição mínima, Concentração, interrupção e perda de metade do PM investido | Livro provisório, Cap. 4, §3. Conferir ordem de investimento/perda, arredondamento e etapas antes de automatizar |
| S15 | IA começa cântico com turno inteiro e chance mínima de 35%; não divide cura/escudo | Heurística explícita e cobertura parcial. Ausência de execução pela IA não prova que a regra proíba a ação |
| S16 | Criatura repete ataque; teia sem dano, voo, emboscada e tática própria não são simulados | Adaptação/omissão explícita. Bestiário consultivo não equivale a IA completa |
| S17 | Chefe ganha uma ação avulsa por rodada, fora do turno | Adaptação explícita. Não atribuir a todos os chefes sem regra/perfil aprovado |
| S18 | Vantagem binária; bônus de aliado até +6; quatro Ações próprias e duas concedidas; duas Salvações sem contador geral | Livro provisório nos tetos, Cap. 4, §5. Contador parcial é lacuna. Validar modalidades absolutas separadamente |
| S19 | Liderança parcialmente modelada; efeitos estratégicos omitidos; IA concede Ações ao maior golpe e presume organização com vários inimigos | Separar cartas do livro, arbitragem estratégica e heurísticas de IA |
| S20 | Bardo parcialmente modelado; Inspiração destinada ao melhor atacante; efeitos de viagem/emoção/decisão omitidos | Livro nas cartas confirmadas; seleção é IA; narrativa exige arbitragem ou cenário estruturado |
| S21 | Pactos preparados automaticamente até Rank/PM, salvo seleção explícita inclusive vazia; efeitos resumidos a perfis | Preparação automática e perfis resumidos são adaptações. Preservar a diferença entre ausência de escolha e escolha vazia |
| S22 | Falta de proficiência dá desvantagem sem reduzir dano; dois d20 no recibo; referência não tem grupo real; tipo físico não vem do inventário | Livro provisório para proficiência. Referência e tipagem ausente são lacunas; não inventar cortante/perfurante/contundente |
| S23 | Dano Furtivo, Primeiro Golpe, tentativa inicial de esconder, Passo Vazio e esconder com cobertura; segredos/reação exigem arbitragem | Conferir mecanismos como livro. Segredos e reações não estruturados ficam manuais |
| S24 | Cenário unidimensional opcional; distância ausente vira abstrato; áreas escolhem 2–5 alvos por régua de metros; cobertura/geometria fina omitidas; orçamento abstrato não ativa Fluxo | Adaptações explícitas. Não aplicar régua abstrata quando houver mapa com seleção geométrica |

## 5. Adaptações e decisões já presentes no Roblox

| ID | Decisão atual | Natureza | Limite de fidelidade |
| --- | --- | --- | --- |
| RB-01 | Tabuleiro 20×20; casa visual de 5 studs; equivalência provisória de 1,5 m | Adaptação explícita | Studs e metros são unidades distintas; a equivalência não foi confirmada como regra do livro |
| RB-02 | Distância em casas com diagonal valendo 1 | Adaptação explícita | Não implica distância euclidiana, trajeto livre ou linha de visão |
| RB-03 | Movimento livre sem orçamento na mesa assistida; log informa distância | Arbitragem legada | J2 autônoma aplica regra/adaptação separada RB-17; isso não altera o controle administrativo do mestre |
| RB-04 | Parede bloqueia destino do jogador; mestre pode mover para parede; terreno difícil/água só visuais | Adaptação explícita e arbitragem | Não há prova de bloqueio de trajetória, cobertura ou modificador de movimento |
| RB-05 | Ocupação só bloqueia jogador quando a outra ficha é visível; sobreposição com ficha oculta é possível | Adaptação explícita de privacidade | Ocupação física completa não pode ser inferida pela recusa do comando |
| RB-06 | PV/mana livres na mesa; importação v1 traz valores calculados | Arbitragem na edição; livro provisório nos seletores exportados | Importação não recalcula nem prova construção legítima |
| RB-07 | Modos afetam exatamente um d20 somado, mesmo com outros dados; múltiplos d20/d20 subtraído ignoram modo com aviso | Adaptação explícita do rolador | Não generalizar esse comportamento para toda ação futura |
| RB-08 | Natural/crítico/falha só no d20 elegível | Representação automatizada; consequências manuais | Não aplica dano crítico, falha especial ou efeito de habilidade |
| RB-09 | Condições sem duração numérica; duração em prosa e nota filtrada | Livro para representação; arbitragem para término | Não significa que todo efeito do futuro motor seja incapaz de ter duração estruturada |
| RB-10 | Até 12 condições por ficha; notas até 60 caracteres; teto padrão de acúmulos 12 importado de `TETO_DE_ACUMULOS` | Limites de aplicação e constante do site | Quantidade máxima de condições é limite técnico; teto global não substitui automaticamente teto contextual por aplicador |
| RB-11 | Dose no teto transforma em Atordoado conforme catálogo gerado | Livro provisório do glossário atual | Diverge do termo Colapso no texto do simulador; precisa de conciliação |
| RB-12 | Lembretes de condições no início do turno; não aplica dano/término | Apresentação automatizada e arbitragem | Lembrete não é execução |
| RB-13 | Iniciativa informada ou rolada com bônus importado; desempate por bônus e ordem enviada na automática | Automatizado; desempate como decisão da mesa até conferir fonte | O trecho antigo que diz “rolagem automática futura” está obsoleto perante M3 |
| RB-14 | Névoa oculta fichas e informações associadas; dono vê sua ficha não oculta na névoa; mapa continua público | Política de privacidade da mesa | Não é teste de percepção, alcance visual ou conhecimento tático da IA |
| RB-15 | Dados 3D, miniaturas, letreiro e painel animados | Apresentação | Nenhuma animação decide resultado ou comprova regra de combate |
| RB-16 | IA J2 ataca uma vez no fim da vez do jogador se houver alvo adjacente; escolhe menor PV e usa `danoPorTurno` do molde como dano fixo; sem alvo, passa; zero PV do grupo conclui derrota | Adaptação explícita do fluxo legado de combate (Apêndice G) | Não representa prioridade tática, críticos que ampliem dano, recuperação ou regras de inconsciência/Fio da Vida |
| RB-17 | Movimento comum J2 gasta 1 Ação e percorre até `floor(movementMeters ÷ 1,5)` pontos de movimento; diagonal custa 1; entrar em casa difícil custa 2; atores e células bloqueadas não podem ser atravessados; mapa 20×20 | Adaptação explícita da regra ordinária de §7F/RB-01/RB-02; equivalência 1,5 m/casa; Atoleiro projeta esfera de raio 4 casas centrada na fonte e zona dura 100 rodadas | Servidor, IA e prévia do mapa usam pathfinder ponderado; custo soma 1 por casa comum e 2 por casa difícil. Falha individual em Agilidade aplica Atolado até próxima vez do alvo; sucesso não causa efeito/dano. Duração de 10 min mapeada a 100 rodadas | `EncontroAutonomoMovimento.spec`, `EncontroAutonomoHabilidades.spec`, `EncontroAutonomoService.spec` e Studio TestRunner 1.364/0 | A esfera é projetada no plano da grade e recortada nas bordas; sem clique real/multiplayer; não há terreno difícil fora das zonas Atoleiro. |
| RB-18 | Em turno de criatura sem jogador adjacente: aproxima-se do jogador vivo mais próximo usando até o deslocamento do molde, paga 1 Ação e ataca se terminar adjacente; empates do movimento escolhem menor distância, custo e coordenadas estáveis | Política de IA do protótipo; adaptação explícita dos dados de deslocamento do Apêndice G e movimento RB-17, não comportamento tático prescrito pelo livro | Um movimento por turno; não persegue se nenhuma casa alcançável reduzir a distância; ataque continua usando dano fixo RB-16 e contorna as rochas do bosque | `EncontroAutonomoMovimento.spec.luau` e `EncontroAutonomoService.spec.luau` | Cobertura, tática e múltiplas ações permanecem pendentes |
| RB-19 | Brasa do Fogo Principiante: 1 Ação, 0 PM, alcance 9 m, 1d6 + BC ígneo, ataque mágico à distância, uma vez por turno | Mecânica canônica `Regras/Fogo`; 9 m = 6 casas pela grade de 1,5 m | Servidor deriva acesso da ficha J1, valida alcance/vez/uso, visão e cobra Ação atomicamente; resolvedor comum aplica crítico, resistência, imunidade e +1d4 condicional contra Em Chamas | `EncontroAutonomoHabilidades.spec.luau` e `EncontroAutonomoService.spec.luau` | Só rochas/Muro bloqueiam visão; clique real e multiplayer pendentes |
| RB-20 | Bola de Fogo: 2 Ações, 1 PM, alcance 18 m, 1d8 + BC ígneo; ao acertar aplica Em Chamas, que causa 1d6 ígneo no início de cada vez do alvo | Mecânica canônica `Regras/Fogo`; alcance = 12 casas pela grade de 1,5 m. O catálogo exige a habilidade em `purchasedIds`; não concede compra ao abrir Fogo | Servidor valida posse, alcance, linha, ações e PM; resolve crítico/resistência/imunidade; aplica condição só no acerto; tick usa `Habilidades.danoDeCondicao`, e criatura derrotada sai da fila. Condições encerram com o encontro | `EncontroAutonomoHabilidades.spec.luau`, `EncontroAutonomoService.spec.luau`, `EncontroTurnos.spec.luau` e TestRunner do Studio | Só rochas/Muro bloqueiam visão; clique real e multiplayer pendentes. Ficha J1 pode adquirir a habilidade no rank aberto, sem recebê-la automaticamente. |
| RB-21 | Toque Escaldante: corpo a corpo mágico, 2 Ações, 2 PM, 2d6 + BC ígneo; +1d6 quando o conjurador está com metade dos PV ou menos; ao acertar aplica Em Chamas | Mecânica canônica `Regras/Fogo`; corpo a corpo = casa vizinha na grade, diagonal inclusive | Servidor exige posse em `purchasedIds`, adjacência, visão e recursos atuais; usa PV atual da sessão, resolvedor comum, e cobra Ações/PM junto da aplicação | `EncontroAutonomoService.spec.luau` e TestRunner do Studio | Só rochas/Muro bloqueiam visão; cobertura permanece ausente. Ficha J1 pode adquirir a habilidade no rank aberto, sem recebê-la automaticamente. |
| RB-22 | Defender: 1 Ação; até o início da próxima vez, cada golpe reduz dano por Vigor + metade arredondada para cima do maior Rank de corpo, nunca abaixo de zero | Mecânica canônica `Regras/Maestrias`; sem adaptação numérica | Servidor calcula da ficha, protege a si próprio e reduz ataques da IA; expira ao começar a próxima vez do personagem | `EncontroAutonomoService.spec.luau` e TestRunner do Studio | Só ataques de criatura entram no encontro J2 atual; efeitos periódicos não são reduzidos por Defender nesta fatia. |
| RB-23 | Cura: 2 Ações, 2 PM, 1d8 + BC; dobra dados contra Ferida Fresca e remove Marcas da Morte conforme a ficha canônica | Mecânica canônica `Regras/ArvoresPrincipiante` e resolvedor compartilhado `Regras/Habilidades`; alcance corpo a corpo interpretado como si próprio ou até uma casa, inclusive diagonal | Servidor exige habilidade comprada, conjurador vivo, PM e alvo jogador do encontro com PV abaixo do máximo; cura não excede PV máximo e pode reerguer alvo em 0 PV. `EstadoHabilidades.feridaFresca` usa sequência causal: dano recebido após o fim da última vez do curador dobra os dados; antes da primeira vez do curador, dano deste encontro conta. A ação Cura não concede PV temporários. Marcas da Morte não são modeladas | `EncontroAutonomoService.spec.luau` e TestRunner do Studio | Ficha J1 pode adquirir a habilidade no rank aberto, sem recebê-la automaticamente; sem terreno/bloqueio de linha na grade. Marcas da Morte seguem ausentes. |
| RB-24 | Poção Menor de Cura: 1 Ação, cura 1d8 + 2 PV; usar em si ou dar a aliado adjacente; não dobra com Ferida Fresca e não remove Ferimento Crítico | Descrição canônica de `item/pocao_menor_cura`; alcance próprio/uma casa conforme o texto do item | `EncontroAutonomoItens` só habilita item já presente com nome/tipo/descrição canônicos; servidor consome a mesma entrada no inventário temporário J1 e na cópia do encontro, e cura até PV máximo. A remoção permanece até o jogador sair; não há salvamento entre sessões | `PersonagemSessao.spec.luau`, `EncontroAutonomoService.spec.luau` e TestRunner do Studio | J1 não oferece compra de item e o kit inicial não contém a poção; nenhuma é concedida. Persistência entre sessões e Ferimento Crítico seguem fora desta fatia. |
| RB-25 | Fim de encontro: descanso automático restaura PV, PM e PT e limpa condições | Adaptação existente em §7E, reutilizada em J2 até a exploração oferecer descansos próprios; inclui PP, já presente na sessão da ficha | No snapshot terminal de vitória/derrota, o servidor restaura os máximos de PV/PM/PT/PP, limpa condições e encerra Defender; sem Marcas da Morte nesta fatia | `EncontroAutonomoService.spec.luau` e TestRunner do Studio | Não implementa descanso durante exploração, progressão, salvamento entre sessões ou recuperação de estados que J2 ainda não modela. |
| RB-26 | Clarão: 1 Ação/1 PM; esfera de 6 m; Vigor (CD 8 + BC) ou Cego até o fim do próximo turno do alvo; sem dano | `Regras/Fogo` e adaptação de Clarão em §7A: qualquer casa visível escolhida como centro; círculo de 4 casas na grade; conjurador excluído, aliados incluídos; linha de visão por supercobertura, incluindo rochas e Muro | Servidor valida o centro visível, recalcula alvos na área e cobra Ação/PM atomicamente; condição expira ao fim da próxima vez do alvo e o catálogo de Cego altera ataques; recibo identifica cada alvo e resistência | `EncontroAutonomoHabilidades.spec.luau`, `EncontroAutonomoCombate.spec.luau`, `EncontroAutonomoService.spec.luau` e TestRunner do Studio | Outras geometrias de oclusão, múltiplos jogadores em sessão real e clique real da ação seguem sem verificação. |
| RB-27 | Muro de Chamas: 2 Ações/3 PM; linha até 6 casas, dano 3d6 ao atravessar, aplica Em Chamas, bloqueia visão e dura 10 rodadas | `Regras/Fogo`/§7A: linha reta em 8 direções que começa numa casa vizinha; comprimento escolhido; entrar em qualquer casa conta como atravessar; sem dano a quem já estava sobre a linha ao conjurá-la | Mira mostra a prévia e exige confirmação; serviço valida início/direção/comprimento, cria células com prazo compartilhado e cobra recursos junto da ação. Cada muro causa um disparo de 3d6 por movimento (várias casas da mesma parede no trajeto não duplicam); Em Chamas usa o tick já existente. Rochas fixas e Muro bloqueiam a linha por supercobertura para ataques, habilidades direcionadas e alvos do Clarão. Some na 11ª rodada | `EncontroAutonomoTerreno.spec.luau`, `EncontroAutonomoHabilidades.spec.luau`, `EncontroAutonomoService.spec.luau` e TestRunner do Studio | Outras geometrias de oclusão, clique real da mira, aprovação visual e multiplayer 2/4 clientes não verificados; a parede não impede movimento e a travessia ativa dano. |
| RB-28 | Bola d’Água: 2 Ações/1 PM, alcance 18 m, 1d6 contundente + BC, aplica Molhado por 10 rodadas e empurra 1 casa | Mecânica canônica `Regras/ArvoresPrincipiante`; 18 m = 12 casas pela grade de 1,5 m | Requer rank Principiante e compra. O servidor só empurra após acerto, para radialmente para longe do conjurador, respeitando ocupantes e grade 20×20; recibo inclui origem/destino e quantidade deslocada, e snapshot reflete a casa final. Molhado expira após dez rodadas completas | `EncontroAutonomoHabilidades.spec.luau`, `EncontroAutonomoService.spec.luau` e TestRunner do Studio | Sem obstáculos de cenário, clique de combate real ou multiplayer; a regra original não define empurrão contra parede/ocupante e a parada antes de bloqueio é adaptação técnica. |
| RB-29 | Impacto de Gelo: 2 Ações/2 PM, alcance 18 m, 1d8 Frio + BC contundente sempre; Agilidade contra CD 8 + BC evita redução de movimento em 2 casas até o fim da próxima vez do alvo | Mecânica canônica `Regras/ArvoresPrincipiante`; alcance = 12 casas pela grade de 1,5 m. Requer compra e rank de Água | Servidor aplica o dano mesmo em sucesso, registra resistência e estados no recibo/snapshot, limita movimento de jogador/IA e expira a redução após a próxima vez do alvo. A UI apresenta sucesso/falha sem confundir resistência com erro de ataque | `EncontroAutonomoHabilidades.spec.luau`, `EncontroAutonomoService.spec.luau` e TestRunner do Studio | Sem combate com cliente real ou multiplayer; geometria sem terreno difícil. |
| RB-30 | Empurrão: 2 Ações/1 PM, alcance 18 m; Força contra CD 8 + BC evita Desequilibrado e empurrão de até quatro casas | Mecânica canônica `Regras/ArvoresPrincipiante`; alcance = 12 casas pela grade de 1,5 m. Requer compra e rank de Vento | Falha aplica condição até o fim da próxima vez e desloca radialmente para longe do conjurador; ocupante/limite interrompe o movimento, registrado no recibo e snapshot. Direção radial é a adaptação explicitada na carta para a grade. Resistência de criatura usa metade do `bonusAtaque`, arredondada para cima, política já usada pelo Clarão | `EncontroAutonomoHabilidades.spec.luau`, `EncontroAutonomoService.spec.luau` e TestRunner do Studio | Sem terreno/parede de cenário, combate real ou multiplayer. |
| RB-31 | Lâmina de Gelo: 2 Ações/2 PM para conjurar em si por 10 rodadas; ataques corpo a corpo de Força ou Intelecto custam 1 Ação, sem PM, e causam 1d8 cortante + BC de Água + 1d4 frio | Mecânica canônica `Regras/Execucao`/`ArvoresPrincipiante`; requer compra e rank de Água. Molhado dobra só a parcela fria | Estado temporário no servidor libera os dois IDs de ataque; valida alcance adjacente e arma ativa e remove as opções no fim da décima rodada completa. Nenhum cálculo de `HabilidadeService` foi alterado | `EncontroAutonomoHabilidades.spec.luau`, `EncontroAutonomoService.spec.luau` e TestRunner do Studio | Sem clique de combate real ou multiplayer; veja evidência em `docs/TESTES.md`. |
| RB-32 | Desistência voluntária em combate: a ficha do jogador cai a 0 PV/derrotada e a luta segue para os demais; a mesa legada também conserva a escolha de personagem | Adaptação explícita de `EncontroService.desistir`; no J2 há um ator por jogador. Não introduz fuga tática, custo de Ação nem recompensa | Serviço autentica o UserId, atualiza PV no corpo da sessão de combate e retira ator da fila numa transição versionada idempotente; se todos os jogadores estiverem derrotados, conclui derrota. UI pede confirmação | `EncontroTurnos.spec.luau`, `EncontroAutonomoService.spec.luau` e TestRunner do Studio | Falta playtest multiplayer real; sem efeitos de saída/reentrada além do contrato atual de retorno. |
| RB-33 | Pedrisco de Terra Principiante: 1 Ação, 0 PM, alcance 9 m, 1d6 contundente + BC; uma vez por turno | Mecânica canônica de `Regras/ArvoresPrincipiante` e catálogo `ability/terra/Principiante/pedrisco`; 9 m = 6 casas na grade de 1,5 m. O truque vem com o rank Principiante de Terra, sem compra separada | Serviço usa executor comum para validar rank, linha de visão, alcance, frequência por turno e recursos; cliente mostra o alvo/custo e recibo como Pedrisco. Sem nova regra | `EncontroAutonomoHabilidades.spec.luau` e TestRunner do Studio | Sem clique de combate real ou multiplayer; outras habilidades de Terra não estão integradas por esta entrega. |
| RB-34 | Bala de Pedra de Terra Principiante: 2 Ações, 1 PM, alcance 27 m, 1d10 contundente + BC; contra Atolado, qualquer resultado no d20 acerta, apenas 20 natural é crítico | Mecânica canônica `Regras/ArvoresPrincipiante` e catálogo `ability/terra/Principiante/bala-de-pedra`; 27 m = 18 casas na grade de 1,5 m. Exige compra e rank de Terra | Serviço usa executor comum para acesso, visão, alcance, custo, acerto automático condicional e crítico natural; nota do recibo nomeia Atolado em vez de “agarrado” | `EncontroAutonomoHabilidades.spec.luau` e TestRunner do Studio | Sem clique de combate real ou multiplayer; outras habilidades de Terra não estão integradas por esta entrega. |

| RB-35 | Lança de Pedra de Terra Principiante: 2 Ações/2 PM, alcance 9 m, até três criaturas; cada alvo testa Agilidade contra CD 8 + BC; falha recebe 2d6 perfurante e Atolado até a próxima vez | Mecânica canônica `Regras/ArvoresPrincipiante` e catálogo `ability/terra/Principiante/lanca-de-pedra`; 9 m = 6 casas na grade de 1,5 m. Exige compra e rank de Terra | Servidor valida a lista inteira de criaturas distintas, vivas, visíveis e no alcance antes de qualquer teste; aplica resistências/dano por alvo, uma cobrança pelo conjunto e replay versionado. Sucesso não causa dano | Specs de helper/serviço e TestRunner do Studio: 1.358/0; suíte local: 309/0 | Sem combate por clique real ou multiplayer. |
| RB-36 | Atoleiro de Terra Principiante: 2 Ações/2 PM; esfera de 6 m de raio centrada no conjurador; Agilidade contra CD 8 + BC; falha fica Atolado até a próxima vez; terreno difícil por 10 minutos | Mecânica canônica `Regras/ArvoresPrincipiante`; 6 m = 4 casas; duração representada por 100 rodadas | Serviço testa todos os atores vivos no círculo exceto a fonte; sem dano. Casas difíceis custam 2 ao entrar e somam custo no orçamento; área remove no começo da rodada 101. Projeção euclidiana em 2D e recorte na borda da grade | Specs de helper/serviço/movimento e TestRunner do Studio: 1.364/0; suíte local 309/0 | Sem clique real, avaliação visual ou multiplayer. |
| RB-37 | Muro de Terra de Terra Principiante: 3 Ações/2 PM; linha transversal de 4 casas centrada num ponto a até 9 m; dura 10 minutos, bloqueia movimento/visão/projéteis e tem 40 PV | Mecânica canônica `Regras/ArvoresPrincipiante`; 9 m = 6 casas; projeção de linha delegada a `AreaHabilidade` | J2 valida compra/rank, centro visível e casas livres; cria zona com 40 PV/100 rodadas, bloqueia rotas, empurrões e linha de visão no servidor; ataque básico pode mirar diretamente a casa da barreira, aplica dano aos PV compartilhados e remove a zona ao destruí-la | Specs de helper/terreno/serviço e TestRunner Studio: 1.373/0; suíte local: `RESULTADO: tudo ok` | Sem clique real, avaliação visual ou multiplayer. A regra de dano direto é a adaptação confirmada por Pedro. |
| RB-38 | Vigor Emprestado: 2 Ações/3 PM/toque; concede 2d8 + BC de PV temporários e dobra os dados contra Ferida Fresca | Mecânica canônica em `Regras/ArvoresPrincipiante`; `BC` vem do rank em Cura | Serviço exige habilidade comprada/rank, conjurador vivo, recursos e alvo aliado válido; conserva o maior valor sem acumular, absorve dano antes dos PV reais e expira após 100 rodadas ou fim do encontro. Ferida Fresca registra a sequência original de dano mesmo se toda absorção ocorrer nos PV temporários | `EncontroAutonomoDefesas.spec.luau`, `EncontroAutonomoHabilidades.spec.luau`, `EncontroAutonomoService.spec.luau`; TestRunner Studio **1.410/0** | Sem inspeção visual/clique real ou multiplayer; Marcas da Morte permanecem fora do J2. |

## 6. Pontos que bloqueiam automação fiel

### 6.1 Dose, Colapso e Atordoado

O contrato atual de `Condicoes` informa Dose 3 → Atordoado. S03 do simulador descreve Colapso na terceira Dose.

Não presumir equivalência entre os termos. Conferir o glossário e a carta atual, identificar se Colapso é descrição, estado distinto ou comportamento composto e registrar a decisão. O gerador deve continuar importando a fonte atual; não “corrigir” o catálogo a partir da memória do simulador.

**Resolvido (Claude, 08/10/2026), pelo texto do glossário** (`src/data/condicoes.ts`, Dose, efeito): "A 3ª Dose é o Colapso: as Doses saem todas e o alvo fica Atordoado até o fim do próximo turno dele." Colapso é o **nome do evento**, um comportamento composto (remover todas as Doses e aplicar Atordoado), e não um estado à parte. A mesa já faz isso (`CondicaoRules.add` com `vira = "atordoado"`). A duração ("até o fim do próximo turno dele") fica em prosa, como as demais. Classificação: **livro**.

### 6.2 Quebrantado

O catálogo usa teto padrão 12. S03 menciona limite pelo Bônus de Rank de quem aplicou.

Esses limites podem atuar em níveis diferentes. Conferir se existe limite por fonte, por aplicação ou total. O modelo atual `{id, stacks, note}` não registra aplicador; pode ser insuficiente para execução automática, embora sirva à mesa manual.

**Resolvido (Claude, 08/10/2026), pelo texto do glossário e do site:**

- Regra do livro: "cada acúmulo dá −1 na CA e −1 no dano… até o máximo do Bônus de Rank de quem aplicou — o DOBRO disso se quem aplicou tiver a Maestria Nada Segura".
- O site tem `CondicaoAtiva.bonusDeRankDaFonte` para esse teto. `TETO_DE_ACUMULOS = Imperador × 2 = 12` é documentado no site como "fallback quando o rastreador não sabe o Bônus de Rank de quem aplicou".
- Classificação da mesa hoje: **adaptação explícita**. Usa o teto absoluto do site como reserva, e o teto pelo aplicador fica com o mestre (**arbitragem**).
- Para automatizar (F4/F5), cada aplicação de Quebrantado precisa registrar o Bônus de Rank da fonte e se ela tem Nada Segura, como o site já prevê.

### 6.3 Metade do Rank e outros arredondamentos

Os trechos dizem “metade”, mas não fornecem todas as operações de arredondamento. Conferir funções e livro. Não escolher `floor`, `ceil` ou decimal por conveniência de implementação.

### 6.4 Duração em prosa

Preservar a representação atual. Estruturar duração futura por efeito e fonte comprovada; não converter toda condição em contador genérico de rodadas.

### 6.5 Acquisition versus Acao

`Acao` não traz identidade estável nem cobre toda habilidade, talento, maestria ou ritual. Ação derivada precisa apontar para sua origem e contexto. O catálogo consultivo deve preservar conteúdo não simulável.

## 7. Cobertura exigida para a fatia F3

Antes de declarar a fatia pronta:

- Ataque de arma: proficiência, contexto, defesa, acerto/falha, dano e parcelas.
- Brasa: custo, limite por turno, alcance e resultado.
- Bola de Fogo: aquisição, custo, acerto e aplicação de Em Chamas.
- Cura escolhida: limite de PV, BC/dados e política de Ferida Fresca confirmada.
- Reação escolhida: elegibilidade, janela, prioridade e consumo único.
- Conjuração escolhida: início, continuação, conclusão e interrupção.
- Múltiplos clientes: autorização, audiência, duplicação, proposta vencida e mudança durante espera.
- Efeitos: recibo causal, falha/interrupção, privacidade e qualidade reduzida.

A seleção de carta de cura, reação e conjuração é proposta a validar na tarefa de implementação. Não substituí-las por aproximações silenciosas apenas para passar no playtest.

## 7A. Fatia A1: Árvore do Fogo jogável (Claude, 09/10/2026; revisão do Codex na rodada 9)

Pedido do Pedro: uma árvore inteira jogável, com animação. A fatia cobre a Magia de Fogo no rank Principiante, em combate por turnos. Regras em `src/shared/Regras/`:
- `Combate.luau`: porte do `resolver` e das rolagens do site;
- `Fogo.luau`: a tabela de mecânicas, que cita o texto e declara as adaptações;
- `Habilidades.luau`: o resolvedor genérico;
- `Criaturas.luau`: o Apêndice G.

Testes:
- `Regras.spec`, com 18 casos;
- `RegrasLivro.spec`, só no Studio, que confere PM, Ações e metros contra o catálogo;
- `tools/playtest/fogo_e2e.luau`, com 31 checagens no servidor;
- `ui_fogo.py`, com 12 cliques reais.

**Livro (conferido no site):**
- Ataque: d20 + BC contra a CA. 1 natural erra; 20 natural acerta e é crítico.
- Crítico: os dados rolam de novo, inclusive a parcela condicional; o BC soma uma vez.
- Vantagem e desvantagem se anulam.
- Teste de resistência: d20 + bônus contra a CD, e empate passa.
  - Personagem: atributo + metade do maior Bônus de Rank, arredondada para cima.
  - Criatura: metade do bônus de ataque, para cima.
- Resistência corta o dano pela metade, para baixo; Imunidade zera. Quem é imune a ígneo não pega Em Chamas.
- Condições que alteram a rolagem:
  - atacante Cego, Envenenado, Preso ou Caído: Desvantagem;
  - atacante Escondido: Vantagem;
  - alvo Cego ou Preso: Vantagem para quem ataca;
  - alvo Caído: Vantagem corpo a corpo, Desvantagem à distância;
  - Quebrantado: −1 de CA do alvo e −1 no dano de quem ataca, por acúmulo.
- O turno tem 3 Ações.
- BC = Intelecto + Bônus de Rank do maior rank aberto em Fogo.
- Em Chamas causa 1d6 ígneo no início de cada turno de quem queima.
- Apagar o fogo custa 1 Ação e um teste de Agilidade CD 10.
- Maestria Chama Viva: dano cheio contra alvo Em Chamas, mesmo no sucesso do teste. Está ligada à ficha, mas nenhuma magia desta fatia tem "metade no sucesso" com dano, então só o spec a exercita.

**Adaptações (não são conclusões do texto):**
- Geometria:
  - 1 casa = 1,5 m.
  - O alcance usa diagonal 1 (Chebyshev). A área ("esfera de 6 m") usa distância euclidiana, para formar um círculo na grade.
  - Linha de visão por Bresenham, bloqueada por parede e por Muro de Chamas.
- Toque: casa vizinha, com diagonal.
- Brasa: a carta diz "uma vez por turno", e a mesa conta isso pela vez da ficha.
- Toque Escaldante aplica Em Chamas só ao acertar.
- Clarão:
  - o jogador escolhe qualquer casa visível como centro, sem exigir que o conjurador seja o centro;
  - atinge aliados;
  - só atinge quem tem linha de visão do conjurador.
- Cego dura até o fim do próximo turno do alvo que começar depois da aplicação. O fim do combate encerra.
- Muro de Chamas:
  - linha reta de 6 casas, numa das 8 direções da grade;
  - para na borda ou em parede e pode cruzar outro muro;
  - "atravessar" é entrar numa casa do muro, cobrado uma vez por movimento e de novo a cada novo movimento que entre;
  - quem já está na linha quando o muro sobe não sofre dano;
  - 1 minuto = 10 rodadas; some ao fim do combate.
- Fagulha: a grade não tem objetos inflamáveis. Ela só gera registro e animação, e a carta avisa antes de gastar PM.
- A forma Encurtada e a Silenciosa não entram nesta fatia.
- Criatura a 0 PV sai da mesa. Personagem a 0 PV fica Caído, e as Marcas da Morte ficam com o mestre.

**Não suportado nesta fatia, e avisado:**
- O nível de Exaustão: a mesa só marca "Exausto", então a Desvantagem do nível 3 não é aplicada, e a nota do registro avisa.
- Resistências e imunidades da ficha do personagem: o envelope v2 não as traz. O registro avisa a cada dano tipado que um personagem recebe; na criação autoritativa (J1), o servidor as deriva.
- Reações, Concentração e Conjuração Contínua.
- Os talentos do Fogo, como Pavio Curto.
- Os ranks acima do Principiante.

## 8. Manutenção

Cada ampliação deve atualizar esta matriz e registrar:

- Fonte e revisão.
- Classificação de cada comportamento.
- Implementação responsável.
- Casos automatizados e casos recusados/manuais.
- Testes novos e resultado efetivamente executado.
- Migrações e impacto nas campanhas existentes.

T20 entrega a documentação inicial para revisão e gravação. Não modifica o site, o motor ou os testes; não declara novos playtests concluídos.


## 7B. Continuação do motor A3 — Codex, 09/10/2026

Esta seção descreve mecanismos testados, não 13 árvores prontas: o registro executável continua restrito ao Fogo. Fonte primária consultada: catálogo gerado conferido com o site pelo comando obrigatório, especialmente árvore Cura/mechanic.loop e condições Molhado/Inconsciente.

- Patamar do alvo: patamar do bestiário ou highestRankBonus da ficha v2. Ficha sem dados usa zero; não é criação autoritativa de personagem (J1).
- Força ou Agilidade: melhor dos dois, mais metade do maior Bônus de Rank arredondada para cima. É a escolha automática de resistência já anunciada pelo Claude; a criatura usa o bônus do Apêndice G.
- Ferida Fresca: o dano resolvido recebe uma sequência causal; cada fim de turno do curador recebe outra. A ferida vale se houve dano depois desse marco, incluindo absorção por PV temporários. Antes da primeira vez do curador, dano registrado neste combate conta. Não é rodada atual/anterior. Alterações manuais de PV não são tratadas como dano de habilidade.
- Selar a Ferida: mantém a janela até rodada atual + 600 (1 hora com 6 s/rodada); encerra com o combate. Isso é adaptação temporal da mesa, não relógio fora de combate. Limpeza não depende de o alvo ter recebido condição. PV temporários também expiram no prazo do efeito, conservam o maior valor e saem ao terminar combate.
- Puxar: carta Principiante executável. Move um aliado para a casa adjacente livre mais próxima do conjurador, por caminho desocupado; sem destino/passagem, recusa antes de cobrar recursos. Aplica Sob Sua Guarda ao alvo, que habilita Interpor segundo o alcance e as condições de Reações (§7H). O teste A17 confirma o ciclo Puxar → golpe no protegido → dano transferido ao protetor. Empurrão usa o mesmo gancho de movimento do avatar e do dano de zona. Isso não automatiza sustentação, escapar ou arrastar de Mão de Terra/Agarrão.
- Condições: catálogo estruturado quando presente. A afirmação de que tudo já era estruturado estava incompleta: Inconsciente só define em prosa a composição Incapacitado/Caído; o servidor a projeta sem gravar duas condições extras. Molhado também está em prosa: frio dobra por parcela e dano ígneo remove Molhado e impede Em Chamas nesse golpe. O vínculo de quem molhou para desvantagem contra frio ainda precisa do sistema de fontes; não se declara a condição completamente automatizada.
- Brisa: o dado extra entra na parcela antes das defesas; não atravessa imunidade/resistência. Em parcelas diferentes, usa o dado de maior face e o tipo dessa parcela (adaptação declarada para o resolvedor genérico); crítico rola o dado extra novamente.
- Disparo duplo: duas rolagens de acerto independentes, inclusive após erro do primeiro. Segundo não ganha o bônus fixo salvo se a tabela o pedir; recibo e controle de acerto no turno reconhecem o segundo. A seleção de dois alvos, alcance da arma, Marcado e contenção da carta completa continuam fora do registro executável.
- Durações: reaplicar substitui o prazo anterior; uma condição que existia antes de a habilidade aplicá-la não é removida pelo prazo desta habilidade. Clarão voltou a declarar explicitamente fim da próxima vez do alvo.
- Audiência: resultados por alvo usam o log do próprio alvo, evitando incluir ficha oculta no registro do conjurador visível. Recibo sem conjurador visível omite sua origem, centro, direção, trajeto e encantamento. Verificação de audiência usa dependências isoladas; não equivale a dois clientes reais.

Não se alterou nenhum arquivo do site. As fórmulas e durações não implementadas não foram convertidas em efeitos narrativos consumindo recursos. Validação reproduzível e limites estão em TESTES.md, seção A3-Motor.


## 7C. A3 — registro das 13 árvores e integração da mesa (Codex, 09/10/2026)

`ArvoresPrincipiante` acrescenta 41 ações ao registro, além das seis do Fogo. Todos os IDs, custos normais de Ação e PM são conferidos contra `Livro/Catalogo` por A3Arvores.spec. Cada carta Principiante das 13 árvores tem mecânica executável ou um motivo explícito de controle manual. O catálogo gerado e o site permanecem intactos. Isso **não significa automação integral de todas as cartas**.

- Água, Vento e Terra: parcelas tipadas, Molhado/Frio, empurrão, cone, deslocamento, terreno difícil, silêncio e zonas de Água/Névoa. Névoa projeta Cego em quem está dentro e bloqueia a linha de visão. Dissipação por vento forte continua manual.
- Cura e Desintoxicação: cura, selo causal de Ferida Fresca, PV temporários, Dose/Purgar, Antídoto e Sono. Dose 2 aplica Envenenado; Dose 3 colapsa e aplica Atordoado. Purgar aflição só opera com rank/origem conhecidos; não presume rank de condição manual. Marcas da Morte e inversão da cura contra mortos-vivos continuam sob condução do mestre.
- Técnicas de corpo: investidas, dado de arma, limites de uso, golpes com teste posterior, provocações, perda de Ação e reduções de movimento. A perda de Ação altera o orçamento do servidor, inclusive para mover/apagar fogo e para invocados. Reações e passivas continuam consultadas na ficha; técnicas não acionam automaticamente contra-ataques, concentração ou interceptação.
- Muralha concede cobertura/resistência de área a aliados próximos enquanto a fonte existe e a distância permanece até duas casas; imobiliza a fonte até sua próxima vez. Puxar desloca o aliado e registra Guarda. Dano não interceptado no protegido repõe 1 PT, limitado ao máximo; a interceptação por Reação é manual.
- Escudo de Água: travessia da linha entre atacante e alvo concede cobertura aos aliados contra ataque físico/projétil e corta pela metade a parcela ígnea, além de eventual Resistência. Essa redução não é uma Resistência adicional e não impede os dados de serem resolvidos antes.
- Estados temporários separados por fonte vivem em `EstadosDeCombate`: término no começo/fim da próxima vez, N vezes ou N rodadas; coberturas não somam. O snapshot do controlador informa os estados; a barra informa efeitos ativos, recursos e usos.
- Invocação: escolha explícita entre quatro Pactos adquiridos; Chamado cria ficha adjacente livre, com vez após o conjurador e uma Ação. PV/CA/BC e dano seguem os perfis do Principiante; Emergência reduz PM a 4, Firmado evita metade de PV/dano. Cão/Corvo atacam, Cão pode derrubar, Filhote ajuda e Fátuo marca. Pacto ativo impede outro Chamado; derrota bloqueia o mesmo Pacto em memória até controle manual do descanso. Vida útil: 600 rodadas, removido também ao encerrar combate. Talentos/passivas de ordem compartilhada, voo vertical, visão compartilhada, mensagens e crescimento não são automatizados.

### Controles e adaptações explícitas

A mira de lista reúne até o máximo permitido de fichas diferentes; um segundo clique na carta confirma, outro clique no alvo o remove. Disparo Duplo usa um alvo para os dois tiros ou dois alvos separados; Marcado e o teste extra só existem no caso de ambos acertarem o mesmo alvo. O servidor recusa duplicatas, listas esparsas, alvo oculto e alcance/visão inválidos antes de cobrar recursos. Compras atualizam as cartas sem trocar de ficha; a barra tem rolagem para caber múltiplas árvores. Zonas têm estilo próprio, sem representar Névoa/Água como fogo.

Deslocamento ordinário de ficha v2: uma Ação, seis casas (9 m) como referência provisória; penalidades temporárias reduzem esse limite. Terreno difícil dobra o custo das casas atravessadas. Investidas respeitam o limite reduzido, e ações mágicas com distância própria conservam a distância da carta. Movimento do mestre continua administrativo, sem esses custos. Passivas que aumentam movimento não estão projetadas; são ajuste manual. Aliados: fichas de jogador ou mesma propriedade; não existe sistema de facções. Arquearia usa 12 casas provisórias porque a ficha v2 não exporta alcance. Passo de Vento usa o plano da mesa. Armas sem indicação válida usam o d6 de referência com aviso. Bala de Lágrimas exige item com nome contendo tempero; o livro exige saco preparado, mas não define consumo automático por uso, portanto o inventário é preservado.

### Cartas mantidas em controle manual

Não cobram recursos nem produzem recibo como se funcionassem. A carta mostra o motivo:

| Carta | Pendência para automação |
| --- | --- |
| Lâmina de Gelo | Ação básica para empunhar/atacar com arma temporária |
| Estancar | Origem/natureza do sangramento ou fogo ativo |
| Mão de Terra / Agarrão | Sustentação, escapar e arrastar |
| Muro de Terra / Anteparo Teórico | Alvo de barreira com PV e destruição |
| Primeiros Socorros | Marcas da Morte e limite por Descanso Curto |
| Arremesso de Espada | Arma largada, recuperação e reequipamento |
| Golpe de Escudo | Inventário v2 só distingue arma, armadura e geral; não identifica escudo |

Também manuais: Sangria (origem/rank/descanso), Mão que Acalma (causa e nível de Exaustão), Golpe de Escudo Soberano (Puro Escudo e última posição), Tiro de Objeto (alvo de objeto), exploração, reações e passivas. Corte de Braço é uma aproximação de bloqueio de técnicas com arma; desarmar e concentração precisam de tratamento integral. Contra Santo ou superior, a ação é recusada antes do custo e remete ao desarme manual para não aplicar bloqueio de braço incorreto. Provocar valida a intenção de ataque contra quem provocou quando alcançável; não obriga automaticamente o jogador a gastar sua Ação nem simula IA.

Os estados de habilidade, fontes, zonas, usos e Pactos são transitórios. Campanha não salva sua duração; Pactos são excluídos da exportação para não reaparecer como personagem comum após carregar. Retomar combate salvo com todos esses estados, repousos e dois clientes reais não foi verificado. A3 integral permanece em andamento até fechar essas pendências.


## 7D. Ataque básico (A5, 09/10/2026)

Livro, Cap. 4 §3: "Atacar com Arma (1 Ação): um golpe corpo a corpo ou um projétil disparado." Todo personagem com ficha completa ganha duas cartas no fim da barra: **Ataque básico** (corpo a corpo, adjacente) e **Disparo** (arma de longe, 12 casas).

Implementação: `mesa/ataque-basico` e `mesa/ataque-a-distancia` em `Execucao.MECANICAS`. Acerto e dano usam a arma equipada (Dado de Arma da escada, sobe com os degraus da árvore de corpo de maior rank) mais o atributo da arma e o Bônus de Rank dessa árvore (`Execucao.arvoreDeCorpo`).

Adaptações registradas:
- Sem arma equipada, vale a arma de referência d6 (aviso no registro), como nas técnicas de arma.
- Disparo: alcance de 18 m (12 casas), o mesmo provisório de Arquearia; sem arco no inventário usa a arma de referência d6.
- J2 autônoma: antes de existir movimento, posiciona o grupo na fileira `z=10` e 2–3 criaturas na `z=11` (casas centradas em `x=8..11`); ataque básico só alcança alvo a uma casa Chebyshev. Reutiliza RB-01/RB-02 e a ação de 1 Ação, sem transpor isso para geometria, movimento ou cobertura geral. A formação é uma adaptação temporária de abertura; o serviço mantém as coordenadas no servidor.
- J2 oferece Ataque básico corpo a corpo e Disparo de jogador contra criatura. Ambos custam 1 Ação, usam atributo da arma + Bônus de Rank da árvore de corpo, repetem dados no crítico e não dobram o fixo, conforme `Regras/Arma` e `Regras/Combate`. Disparo usa alcance de até 12 casas, a primeira arma de distância do inventário ou d6 de referência, e respeita o Muro de Chamas como bloqueio de visão. Dano físico não recebe tipo presumido nem aplica resistência/imunidade física ausente da arma de referência.
- J1/J3, adaptação limitada do equipamento pessoal: o jogador escolhe e persiste somente `sourceLocalId` de uma arma já presente no kit inicial recalculado pelo servidor. A seleção equipa arma corpo a corpo para Ataque; arma de distância fica em primeiro lugar para a regra atual de Disparo. Não há compra, item novo, armadura, alteração de dano/CA ou mudança na escolha de Punhos de A15. A troca de árvore limpa a escolha; perfil antigo sem seleção mantém o fallback anterior. Essa fatia não implementa a escolha ampla de armas de A15.
- Não portado: Ataque de Oportunidade, Desvantagem de "atirar colado" e distância longa do arco; Empurrar/Derrubar/Desarmar (manobras do mesmo capítulo) continuam fora.


## 7E. Inimigos que agem sozinhos e Modo Luta (09/10/2026)

O livro não traz regras de IA: o mestre conduz os inimigos. No Modo Luta (sem mestre), o servidor age por eles. Tudo abaixo é adaptação de jogo, não regra do livro:

- **Alvo**: o personagem vivo mais próximo (distância em casas, diagonal custando 1); empate vai para quem tem menos PV.
- **Movimento**: até 2 Andares (cada um com o Deslocamento da criatura, em casas de 1,5 m), contornando paredes, fichas, barreiras e zonas que ferem ao atravessar. Condições que prendem (Agarrado, Atolado, Imóvel) zeram o movimento; Reduz Movimento e Metade do Movimento valem.
- **Ataque**: 1 por turno, corpo a corpo, quando termina colado no alvo: d20 + bônus de ataque do Apêndice G contra a CA; acerto causa o **dano por turno** do molde (já com o papel lacaio/padrão/chefe), como valor fixo. Crítico e falha natural seguem o resolvedor comum. Condições com "sem Ações" fazem o inimigo perder a vez.
- **Fim do encontro**: vitória quando não resta inimigo de pé; derrota quando nenhum personagem de jogador tem PV. Ao fim, **descanso automático**: PV, PM e PT cheios e condições limpas (substitui Marcas da Morte e descanso até existir a fase de exploração).
- **Balanceamento**: o Apêndice G calcula inimigos para um grupo. Sozinho, o Ignis (26 PV) contra um goblin batedor (lacaio) é uma luta parelha; o roteiro automático, que joga mal, perdeu nas duas rodadas de teste. Ajustar a dificuldade para quem joga sozinho é decisão pendente com o Pedro.


## A15 — arma inicial e punhos (09/10/2026, Codex)

Fonte: site original, sem mudanças. `startingKits.ts` define o kit; `trees/*` fornece `proficiencies.gruposDeArma`; `weaponDie.ts/WEAPON_PRESETS` fornece as armas mundanas e seus dados. `grupoDaArma` consulta GRUPO_POR_ARMA em weaponGroups.ts. O gerador revalida essa classificação. Armas encantadas, relíquias e nomes de exemplo sem Dado Base não foram concedidos na criação.

Adaptação pedida por Pedro: a arma escolhida substitui a arma principal gratuita do kit, sem compra/venda, custo de PA ou ganho de dinheiro. Magia Ofensiva, Cura e Suporte e Invocação mantêm Cajado / Foco Arcano. Árvore sem grupo de arma oferece só o kit. Arquearia escolhe entre Arcos e Bestas e Arremesso; Funda / Dardo continua como reserva na mochila (sem duplicação se ela própria for escolhida). Disparo continua usando a primeira arma de disparo do inventário; a escolha é posta primeiro. CA e os demais números calculados não dependem dessa troca. Não compramos talentos novos nem alteramos Couro Grosso.

Lutador, `src/data/trees/lutador.ts:49`, maestria Principiante: **“Seus ataques desarmados usam Dado Base d6 (com seus degraus normais).”** O catálogo guarda a maestria como entrada própria; Arma resolve essa entrada e o valor explícito. Escolher Punhos retira a arma do kit e deixa nenhuma arma equipada. No Principiante o degrau normal resulta em d8; não há arma de referência nem aviso nesse caso.

Cap. 3, Chapter3.tsx, “Arma improvisada não sobe a escada”: **“A cadeira, a garrafa e a pedra do chão travam em d6 e não ganham degrau nenhum.”** Portada a trava do objeto improvisado e do foco. Norte escapa quando é a árvore utilizada na escala; abrir Norte num rank menor não libera degraus de outra árvore. Empate de rank conserva a adaptação anterior de usar a maior soma de degraus; com soma igual, Norte prevalece para o improvisado. Isso automatiza a escolha que o livro deixa ao jogador.

**Lacuna D-A15, não resolvida:** Cap. 1 dá proficiência gratuita em Desarmado e Improvisado, mas não publica dado/dano para soco comum. WEAPON_PRESETS só publica Objeto Improvisado d6; a maestria do Norte concede objetos improvisados d6, sem definir soco. Não confundo objetos e ataque desarmado nem infiro d4/d6/1 fixo. Norte recebe a opção Punhos sinalizada como “não definido”, bloqueada no servidor até haver fonte ou decisão do autor. Magos preservam o kit como solicitado. Portanto A15 está parcialmente entregue, não integralmente fechada. Fichas antigas ambíguas ainda usam o fallback anterior com aviso; essa referência não define regra de punhos.

Contrato: `escolherPersonagem { id, arma? }`, ausência = kit. Tipo, comprimento, UTF-8, chaves e pertencimento são validados. Confirmação ao dono por `escolhaPersonagem { id, arma }`; sem alterar snapshot. Frequência segue o orçamento remoto existente. Troca em combate fica para a próxima criação. EncontroService instala o adaptador de montagem depois de HabilidadeService estar inicializado; Treino/Luta/Duelo usam o mesmo handler. Não editou HabilidadeService ou ArvoresPrincipiante da A14. Dado do ataque vem do inventário atualizado a cada execução. Apresentação de arma/gesto ainda não foi adaptada por modelo.


## 7H. Reações (A14, Claude, 09/10/2026)

Livro, Cap. 4 §4: "3 Ações por turno e 1 Reação por rodada". Antes da A14 nenhuma Reação funcionava no jogo ("consulte a ficha"). Agora o servidor abre uma **janela de Reação**: pergunta ao dono da ficha, com prazo de 8 s (sem resposta, não reage), e aplica. Regras puras: `Regras/Reacoes.luau`; orçamento e pergunta: `server/ReacoesService.luau`; tela: `client/ReacaoView.luau` (teclas 1–3, 0 deixa passar).

| Reação | Quando o jogo pergunta | Efeito |
| --- | --- | --- |
| Aparar (Deus da Água) | golpe corpo a corpo te acerta e o Bônus de Rank faria errar | o golpe erra (20 natural acerta sempre) |
| Guarda do Corpo (Deus da Água) | aliado ao seu lado vai ser atacado (antes da rolagem) | você vira o alvo; vale a sua CA |
| Fluxo (maestria, Deus da Água) | automático: criatura adjacente erra golpe corpo a corpo em você | contra-ataque comum com a arma, rolando acerto; 1 por rodada; não gasta Reação |
| Couraça de Barro (Terra) | golpe físico te causa dano; 2 PM | dano −(1d6 + BC de Terra) |
| Parede de Emergência (Teórica) | você ou aliado a até 3 m vai sofrer ataque físico; 4 PM | parede de 15 PV recebe o dano primeiro |
| Bloquear com Escudo (Cap. 4 §4, todos) | golpe físico te acerta, com escudo equipado | +5 na CA (+2 sem proficiência); se ainda acertar, dano −2 × maior Rank |
| Interpor / Sob Minha Guarda (maestria, Cavalaria) | golpe causa dano ao seu protegido a até 3 m | todo o dano vem para você |

Também: a Reação volta no início da sua vez; Desequilibrado e quem está sem Ações não reagem; a Investida do Deus da Espada tira as Reações até a sua próxima vez; uma carta nova **Sob Minha Guarda** (0 Ação, exige o rank de Cavalaria) designa o protegido, e o Puxar continua pondo o puxado Sob Sua Guarda.

Adaptações registradas:
- O golpe de criatura (dano por turno do Apêndice G) não tem tipo; conta como físico para Couraça, Parede e Escudo.
- Parede de Emergência: migração D-A16-2 concluída na A17. Barreira real de 15 PV intercepta o golpe físico inteiro e expira no começo da próxima vez da fonte; magia atravessa (inclusive magia com dano físico). Fica na casa da linha imediatamente antes do alvo; contra adjacente, na casa do alvo representando a aresta. Excesso não atravessa, conforme o contrato de Barreiras da A16. Não é mais reserva de PV presa ao protegido.
- Escudo: o inventário exportado não tem tipo "escudo"; vale o item equipado com "escudo" no nome. Proficiência em Escudos: Cavalaria e Deus do Norte.
- Aparar só é oferecido quando faria o golpe errar (o jogador não gasta a Reação à toa).
- Ordem: Guarda do Corpo → Parede (antes da rolagem); depois, a Reação do alvo (uma entre Aparar, Escudo e Couraça) → Interpor; depois de aplicar, Fluxo.
- Fora do escopo: Ataque de Oportunidade, reação do Arremesso de Espada (interceptar projétil), "não pode durante um cântico" da Couraça (não há cântico contínuo).


## 7F. A16 — cartas Principiante executáveis (Codex, 09/10/2026)

Esta seção substitui as pendências correspondentes de §7C. Fonte consultada, sem modificar o site: `Livro/Dados/Arvores/{terra,teorica,armas_pesadas,deus_da_espada,deus_do_norte,cavalaria_e_escudos,cura,desintoxicacao}.luau` e `sourceRef` das cartas; Cap. 4 §3 (Disputas, manobras, usar item), §6 (arma largada a 1,5 m) e Apêndice G (dano por turno). O catálogo foi conferido por `testar.ps1` com o site original.

| Carta/sistema | Livro portado | Adaptação e limite de representação |
| --- | --- | --- |
| Muro de Terra | 3 Ações, 2 PM; 40 PV, largura 6 m, alcance 9 m, Cobertura Total, 10 minutos | Quatro casas transversais, PV únicos para toda a barreira, 100 rodadas. Impede movimento/visão. Ataque físico pela linha para nela; magia que exige ver alvo atrás dela é recusada. Ataque básico/disparo pode mirar diretamente a casa da barreira. Alvo imóvel: dano automático, sem crítico; excesso de dano não passa para a criatura. Altura/subir/peso não simulados. |
| Anteparo Teórico | 2 Ações, 2 PM; 30 PV, até 3 m, toque, 1 minuto; barra corpos/projéteis, magia atravessa | Duas casas, 10 rodadas; mesmo sistema de PV. Magia é identificada pela categoria da árvore, mesmo quando parcela é física (Pedrisco/Bala de Pedra são magia). Nenhum ataque direto de magia a objetos foi acrescentado. |
| Agarrão | Disputa de Força; Agarrado; arrastar até 3 m; ataques desarmados contra quem você agarra acertam automaticamente | Corrigida metade do maior Rank no atacante da disputa (Cap. 4 §3); defensor já a tinha. Empate mantém situação. Escape: 1 Ação, melhor Força/Agilidade + metade do maior Rank contra o total original do vencedor (CD fixa pedida para A16; o Glossário manda repetir Disputa). Arrastar custa 1 Ação, uma vez por turno; os dois se deslocam juntos em linha livre. Um alvo por fonte, sem empilhamento de vínculos. Mãos vazias só causam dano quando Arma reconhece a maestria dos punhos; não inventa soco comum do Norte (D-A15). |
| Mão de Terra | 2 Ações/2 PM para conjurar; Força CD 8 + BC aplica Agarrado + Atolado; 1 Ação e mesmo teste/CD para escapar; 1 Ação arrasta 3 m | Fonte precisa estar viva, capaz de agir e não Caída; Soltar é livre e encerra apenas condições pertencentes ao vínculo. Mão pode arrastar o alvo sem mover o conjurador. Adaptação de grade: servidor escolhe deterministicamente a casa livre que mais aproxima o alvo da fonte em até duas casas, respeitando rochas/ocupantes; não há mira manual de destino. Limite de um vínculo por fonte. IA gasta uma de suas Ações para tentar escapar antes de mover/atacar. |
| Desarmar (manobra comum) | Cap. 4 §3: 1 Ação, Força contra melhor Força/Agilidade do alvo, ambos com metade do maior Rank; objeto a 1,5 m; pegar custa 1 Ação | Escolha automática da melhor defesa. Queda adjacente para leste (na borda/parede, própria casa), em vez de pedir uma segunda mira. Só a arma equipada; sem roubo/troca permanente de inventário. Objetos no chão não replicam dados de ficha nem dono; apresentação pública usa interseção de visibilidade de todos os jogadores, pois `api.estado()` não recebe destinatário. |
| Corte de Braço | Ataque; acertando: Vigor CD 8 + Força + Rank; falha larga arma e braço inútil até fim da próxima vez; Santo+ apenas larga | Não recusa Santo. Arma real fica no chão; braço limita técnicas de arma/mão e recuperação nesse prazo. Inimigo humanoide do bestiário recebe arma abstrata; dano desarmado ou com braço inútil = metade para baixo, mínimo 1, até recuperar/expirar. Essa redução é proposta implementada, não número de soco do livro: Apêndice G só publica dano por turno. Garras/mordidas não são largadas. Sem Conjuração Contínua/Teste de Concentração: Desvantagem daquele golpe permanece não implementada e avisada na carta. Corte aparado não desarma. |
| Arremesso de Espada (Ação) | 1 Ação, Agilidade + Rank, alcance 18 m, dano normal da arma; fica desarmado | Usa a arma equipada, sem fallback de arco; queda na casa de impacto mesmo no erro, recuperação adjacente/na casa por 1 Ação. Três Bainhas saca reserva real livremente; quando o exportador não a enumera, cria reserva transitória idêntica (adaptação declarada), removida no descanso. Limite 60 objetos por combate. Reação CD12 para interceptação está solicitada à A14; não implementada aqui. |
| Golpe de Escudo | 1 Ação; 2d8 + Força + Rank contundente; falha Força CD 8 + Vigor + Rank: empurra 3 m e Caído | Escudo reconhecido por `Reacoes.escudo`, inclusive armadura do kit. Empurrão para na primeira casa bloqueada; testes e Reações passam pelo fluxo comum. |
| Golpe de Escudo Soberano | Puro Escudo; CD +2, empurra 6 m e Caído; última posição até início da próxima vez concede Cobertura ao aliado que passar | Marca a casa usada no golpe; cruzar a linha por ela concede +2 CA (Cobertura Parcial, escolha mínima porque carta não nomeia grau) contra um próximo ataque, consumida mesmo se errar, sem somar coberturas. Marca do chão termina no início da vez da fonte. Provocar Ódio Soberano já valida Puro Escudo, preservado. |
| Primeiros Socorros de Campo | 1 Ação; Vigor + Rank PV; aliado adjacente ou si; remove Marcas da Morte; uma vez por criatura por Descanso Curto | Cura e levanta quem estava Caído a 0 PV. Sem Marcas da Morte ou Descanso Curto: uma vez por criatura por combate, compartilhada entre curadores. Descanso automático (§7E) repõe o limite. Sem depender do mestre. |
| Estancar | 2 Ações/2 PM; encerra sangramento/corte/queimadura; não veneno nem fogo mágico ainda ardendo | Em Chamas de magia/zonas de fogo registra `fontesCondicao.magica`; esse fogo é preservado. Origem sem registro é tratada como fogo não mágico; condição importada com rank de fonte é conservadoramente mágica. Estado puro `sangramento` pode ser removido; o Principiante atual não possui produtor de sangramento nem sangramento exportado. Sem estado elegível, recusa antes do custo. Não afirma simular hemorragia que não existe no combate. |
| Quebrar Equipamento | 1 Ação; falha Força CD 8 + Força + Rank quebra arma/escudo mundano | Carta original escolhe arma; carta adicional Quebrar escudo escolhe escudo. Só nomes de arma mundana reconhecidos em Armas ou Escudo do kit; origem desconhecida é recusada antes de cobrar. Desativa item e subtrai armorClassBonus se houver; impede usar seu bloqueio. Humanoide sem inventário: arma abstrata quebrada reduz dano pela metade. Bestas/garras são recusadas. Quebra dura até descanso automático, quando restaura equipamento (adaptação PvE/PvP sem economia/reparo). Inutilizar equipamento mágico por 3 turnos não foi implementado: envelope v2 não distingue sua natureza. |
| Sangria | 2 Ações/3 PM; aflição até um rank acima, 3d6 irredutíveis, não a 0 PV; uma vez por aflição por Descanso Longo | Opera nas aflições já representadas: Envenenado/Petrificado com fonte/rank conhecidos. Dano sem tipo e ignora PV temporários (irredutível). Limite por alvo/aflição/fonte no combate, compartilhado entre curadores, reiniciado no descanso automático. Rank/causa desconhecidos recusam antes do custo. Não supõe doenças/aflições sem representação. |
| Mão que Acalma | Remove um nível de Exaustão causado por ferimento/trauma/Fio da Vida; não fome/sede/marcha | Continua indisponível com motivo na carta: `Exausto` só representa nível 3+, não informa nível nem causa. Apagar a marca inteira seria uma regra errada; não se cobra PM/Ações nem se remete ao mestre. |

### Contrato e integração

Comandos existentes `usarHabilidade {tokenId, habilidadeId, alvoId?, x?, z?}` recebem IDs transitórios `mesa/escapar`, `mesa/arrastar`, `mesa/soltar`, `mesa/pegar-arma`, `mesa/desarmar` e `mesa/quebrar-escudo`. Nenhum remoto novo. O snapshot `jogo` acrescenta `objetos={id,x,z,nome genérico}` e `pv/pvMax` às zonas. Validação de tipo, dono, vez, condição, recursos, vínculo, alcance e caminho ocorre antes de pagar; frequência continua no despachante único da mesa (8 pedidos acumuláveis/8 por segundo). Pegar é Usar Item, sem alvo de ataque e sem Ataque de Oportunidade representado; não inventa pergunta de Aparar ao levantar um objeto.

Ataques de Arremesso/Golpe de Escudo/Corte conservam `antesDoAtaque`, `aposRolagem`, `aposAplicar`. Barreira interceptora é alvo de objeto, não oferece reação à criatura protegida. Pureza/RNG: Barreiras, Agarrar e Desarme não criam Instances nem enviam eventos. Desarme altera tabelas de equipamento fornecidas pelo servidor; guarda referências para restaurar sem duplicar a arma. Arma/A15 apenas passa a excluir itens transitórios indisponíveis dos disparos.

Estados são transitórios e limpos ao encerrar/descartar combate; nenhuma migração de campanha persistente foi adicionada. IA recupera arma adjacente gastando 1 Ação, tenta escapar gastando 1 Ação e golpeia barreira adjacente se não consegue contorná-la. Mantida a proposta de migrar Parede de Emergência em D-A16-2, sem tocar ReacoesService.

Recibos existentes continuam alimentando Coreografia/Magias. Novos visuais nesta tarefa: arma metálica simples no chão e letreiro PV da barreira. Gestos específicos de arrastar/escape, arremesso por modelo de arma, destruição detalhada da barreira e animação de socorros não foram criados. Não equivalem a novas cartas manuais: regra executa no servidor.


## 7G. A17 — integração de maestrias, talentos, passivas e ações básicas (Codex, 09/10/2026)

Fonte de regra: `Livro/Dados/Arvores/{deus_da_espada,deus_da_agua_corpo,deus_do_norte,armas_pesadas,arquearia,agua,vento,terra}.luau` (texto e sourceRef do catálogo); Cap. 4, opções básicas. `Regras/Maestrias` mantém funções/textos do Claude; somente o registro MECANICAS foi completado, com evidência em D-A17-1. Servidor aplica todas as passivas abaixo, sem depender de clicar numa carta manual.

| Regra | Execução e adaptação |
| --- | --- |
| Brisa | 0 Ações/PM, uma vez por vez, criatura hostil a até 6 casas: empurra uma casa mesmo passando Força; falha aplica Desequilibrado até fim da próxima vez do alvo. Espaço bloqueado limita o empurrão. Sem manipulação narrativa de ar fora de combate. |
| Afinidade Aquática | 0 Ações/PM, uma vez por vez, Molhado em criatura adjacente. Não representa água controlada distante, litros, aquecimento ou evaporação. Sem Condutor: dez rodadas; fogo seca. |
| Moldar | 0 Ações/PM, uma vez por vez, alvo hostil a até 6 casas. Casa do alvo vira terreno difícil **para hostis** até fim da próxima vez da fonte, mesmo passando Agilidade; falha aplica Atolado até fim da próxima vez do alvo. Não há seleção da forma do chão, buracos, abrigo, altura ou volume. A casa é a adaptação mínima do chão moldado. |
| Esquivar | Uma Ação, criatura visível escolhida: estado esquiva guarda seu id no personagem até o início da próxima vez dele. Ataques da fonte têm Desvantagem; testes de resistência contra efeitos dessa fonte têm Vantagem. Não afeta ataques de terceiros. |
| Defender | Uma Ação, estado até início da próxima vez: redução não negativa = Vigor + metade arredondada para cima do maior Rank de corpo. Mesmo fluxo de Reações, sem gastar Reação. |
| Ajudar | Uma Ação, aliado adjacente recebe auxilio no próximo ataque; expira no início da próxima vez de quem ajudou. Donos diferentes da mesma equipe são aliados. |
| Marcar / Olho do Caçador | Uma Ação, alvo visível; condição Marcado e fontes separadas registradas. O arqueiro recebe +1 contra sua própria marca; outro arqueiro não ganha o ponto sem também marcar. Limite de alcance de interface: 32 casas (todo o tabuleiro). Limpa no fim do combate. |
| Pés Leves / Roupa Leve | Deslocamento usa movementMeters da ficha (9 m sem campo) e maior bônus de 3 m, sem somar os dois. Armadura de corpo desliga Roupa Leve; escudo não. Casas andadas na própria vez acumulam; duas casas dão +2 CA do momento do movimento até o **início da próxima vez**, quando o contador zera. Não contabiliza movimento fora da vez. Andar recebe o alcance do servidor no snapshot. |
| Pés no Chão | Ignora terreno difícil em Andar e investidas; não ignora custo de movimento Caído, paredes, fichas nem barreiras. Moldar não dificulta a fonte/aliados. |
| Sem Recuo / Paciência de Pedra / Base Firme | Sem Recuo e Paciência impedem Amedrontado; Paciência impede também o estado Provocado. Base Firme suprime empurrão, puxão e Caído quando o efeito oferece teste de Força/Agilidade, sem apagar seu dano/outras condições; teste de Vigor não concede essa proteção. |
| Quem Se Move Primeiro | Na primeira vez da ficha no combate, primeiro ataque com arma tem Vantagem e +1 Dado de Arma; erro também consome a abertura. Segundo disparo/segundo alvo não recebem de novo. Crítico repete os dados adicionais conforme a regra geral, sem repetir fixos. Contadores limpam no fim/descartar. Desempate da iniciativa já estava integrado em EncontroService/A18. |
| O Corpo é a Arma | Primeiro acerto corpo a corpo contra cada criatura na própria vez aplica um Quebrantado; erro não consome, disparo não aplica, outra vez libera de novo. Número explícito da técnica substitui a taxa, sem somar um. Contra-ataque fora da própria vez não aplica a taxa. |
| Condutor de Gelo | Molhado aplicado pela ficha com o talento conserva a origem e dura até fim do combate, sem secar por fogo. Suas magias de frio rolam um dado extra do tamanho do maior dado de frio contra qualquer Molhado; o extra entra após a dobra de Molhado e antes das defesas do frio. Crítico repete o dado; seco ou magia sem frio não recebem extra. |

Gancho A18 integrado: `deps.mesmaEquipe` usa EncontroService na injeção de MesaService. `golpeDeCriatura(atacante, alvos, mec, estilo)` é API interna do servidor, sem remoto novo. Reserva uma Ação/execução por vez inclusive área vazia; valida identidade, combate/vez, recursos de Ação/incapacidade, lista densa sem duplicação, alcance, linha, hostilidade e área congelada. Revalida após janelas de Reação, incluindo alvo removido ou saindo da área; não persegue. Reutiliza o mesmo resolvedor de turnoDoInimigo: entradas, antesDoAtaque, reação ao acerto, defesas, aplicarEfeito, PV temporários/queda, recibo e apósAplicar. Guarda pode interceptar do lado de fora da área; o alvo original ainda precisa permanecer válido. Tipo contundente e padrão de raízes são a adaptação A18, não uma técnica do livro.

Premontados: compras A16/passivas A17 incorporadas pelo exportador original, preservando Aparar/Guarda de Isa, Couraça de Brutus, Parede de Euclides e opções de arma A15. Todas as 67 compras das 14 receitas aceitas, nenhuma recusada. `premontados.ps1 -SemEsbuild` oferece transformação TypeScript em processo quando o sandbox Windows recusa esbuild com spawn EPERM; usa dependência já instalada do site e não o modifica.

Limites preservados: água/chão narrativos, terreno em três dimensões, foco/concentração/Surpreso específicos da Espada não foram acrescentados nesta integração. Reação Arremesso continua fora da A17. Não declara todas as maestrias de qualquer rank implementadas. Dois clientes reais, latência, balanceamento, celular e julgamento visual continuam pendentes; evidências e números em TESTES.

## 7I. A18 — equipes, desafios e Treant Ancião (Codex, 09/10/2026)
**Livro:** catálogo `Livro/Dados/Criaturas`, origem `src/data/preMadeMonsters.ts/BESTIARIO`. Nível 1 conserva goblin batedor (patamar 1/lacaio), lobo cinzento e bandido (1/padrão). Nível 2 acrescenta Urso de Presas Vermelhas (2/padrão). Nível 3 usa **Treant Ancião** (3/chefe), espírito milenar da floresta, com resistência contundente/perfurante e imunidade veneno. `Regras/Criaturas.ficha` preserva PV, CA, bônus, dano por turno, deslocamento, resistências e imunidades do catálogo e Apêndice G. Papel chefe usa ×2,5 PV e ×1,5 dano, como já portado do site.

**Adaptação pedida para o Roblox:** equipes 1/2 e participantes sem equipe (cada dono constitui seu lado); qualquer distribuição até 32 participantes, filas voluntárias, vitória do último lado com alguma ficha viva (Pactos contam), empate sem ninguém de pé. Grupos PvE 1–4. Nível do desafio não é patamar/rank do personagem. Nível 2: um urso + um goblin por participante, com lobo adicional quando há pelo menos três. Nível 3: um Treant + um lobo por participante adicional. A escala altera apoio, não a ficha do livro. Balanceamento não verificado: um chefe de patamar 3 pode derrotar um Principiante em um golpe; não reduzi números do livro para fingir acessibilidade solo.

**Apresentação inventada de jogo:** arena Bosque Desperto, doze pilares/copa, luz verde/dourada e piso tingido; corpo de tronco/galhos/coroa com 11,5 studs de altura, numa só casa lógica (sem ocupação Enorme); letreiro, barra de chefe e pulsos/raízes locais. Sem assets novos ou dependências. Animações reduzidas suprimem os pulsos/expansão. Limpeza cancela tweens, destrói arena/avisos e invalida tarefas atrasadas. Sigilo reutiliza o callback de CorposDeCriatura (uma mesa por servidor); chefes secretos não publicam HUD/área, alvo secreto não é escolhido para aviso.

**Padrões inventados, não técnicas do livro:** acima de 60% PV, Raízes despertas (quadrado 3×3); de 60% a mais de 30%, Ruptura da terra (cruz de cinco casas); 30% ou menos, Fúria da floresta (quadrado 5×5). Mira no jogador público vivo com menos PV (empate por id); área limitada ao tabuleiro e congelada no primeiro turno, executada na próxima vez do chefe. Incapacidade/zero Ações cancela o aviso; fim/reinício limpa pendentes. Gancho futuro: ataque com bônus da criatura e parcela fixa contundente do dano por turno por alvo ainda na área, sem novas condições. Área e tipo contundente são adaptação e exigem balanceamento.

**Limitação de integração:** HabilidadeService está com A16 e não foi editado. `api.equipeDe`/`api.mesmaEquipe` já resolvem equipes/vitória, mas cura/Ajudar/Guarda/Interpor entre donos da mesma equipe dependem da injeção do gancho pelo Claude. `ChefesService` chama `habilidades().golpeDeCriatura` quando disponível; por enquanto avisa “prévia visual”, resolve com `turnoDoInimigo` e deixa recibos/Reações/PV temporários/queda no caminho existente. Sair da marca ainda NÃO garante evitar o golpe corpo a corpo do fallback. Não aplico PV nem condições por fora. Chefão completo e PvP aliado completo não são declarados entregues antes dessas integrações e dos testes correspondentes.

Site e catálogo intactos; não publicado. Verificações e ressalvas em TESTES A18.


## 7J. A19 — Magia Teórica desenhada (Codex; integração e fechamento pelo Claude, 09/10/2026)
Fonte lida sem edição: site Chapter2.tsx §6–8, RegrasDaTeorica.tsx e lib/magiaTeorica.ts, data/trees/teorica.ts; catálogo Livro/Dados/Arvores/teorica.luau. Escopo: Alfabeto Arcano, um verbo e Círculo/Linha/Quadrado; seis potências quando a ficha as conhece. Sem Frase Composta, formas posteriores, pedra, armadas ou talentos posteriores.

| Livro | Porte / representação A19 |
| --- | --- |
| PM/d8: 1,2,5,6,10,12; PV 20,40,60,80,100,120; Ações 2,2,3,3,4,4 | Constantes puras; 504 combinações, tabela independente e testes de recusa. |
| Essência extra +1; forma diferente de Círculo +1; primeiro verbo grátis | Uma conta só. Quadrado + Lançar permitido, sem bônus de dano. |
| Linha ×1,5 alcance/tamanho; Quadrado PV +50%; Terra +50% somados | Medidas do motor do site, em múltiplos de 1,5 m; estrutura no ar limitada a 12 m. |
| Seis essências por talento ou escola Principiante | Efeito próprio; nenhuma Maestria herdada da escola. Vida cura dados sem BC. |
| Régua do Selo; essência de escola ganha um rank | Regra pura por origem da magia; metade dos dados/área/duração, não metade do BC. Integração pendente. |
| Concentração Espírito + metade do maior Rank; CD 10 + Rank atacante, 12 sem fonte | Controlador novo com RNG injetado; Corte dá Desvantagem; Traço Firme refaz a primeira falha automaticamente uma vez por combate. Hook de dano pendente. |
| Desenhar no ar custa Ações da potência; dividir entre turnos | Controlador reserva PM no início e gasta Ações disponíveis; continuar na própria vez; Perda de Foco cancela se passar a vez inteira sem desenhar. Reembolso deixa perdido floor(PM/2). |
| Preparo 1 minuto; ativação 1 Ação por quem pagar | Relógio servidor; preparo só fora de combate; qualquer ficha controlada ao toque alimenta. BC fica registrado no desenho. Um slot transitório por criador; refazer substitui/reinicia o minuto. Não representa pergaminhos físicos transferíveis nem persistência de campanha. |
| Fórmula de Bolso dura até ativar, inclusive após Descanso Longo | Slot de bolso mantém-se no descanso automático enquanto o token existir; giz expira no descanso. Preparo incompleto interrompe ao iniciar luta. |
| Mouse/dedo traça contorno | Tela nova coleta pontos e reconhece três formas; precisão é cosmética. Barra/render/servidor/Studio ainda dependem de liberação A17. |

Integração (Claude, depois que a cota do Codex acabou):
- Carta **Desenhar fórmula** (0 Ação, exige o Principiante da Teórica) abre o quadro; a fórmula executa pelo mesmo `usarHabilidade` com a mecânica montada por `Formulas.mecanica` (custo reservado pelo FormulasService). Lançar passa pelos ganchos de Reação.
- Dano sofrido enquanto desenha chama o Teste de Concentração; a vez que passa sem desenhar cancela (Perda de Foco); Incapacitado/0 PV derruba.
- **Sustentação** (Cap. 2 §7, P&R "Quantas magias posso sustentar? Uma"): parede ou selo novo derruba o anterior do mesmo autor; cai se o autor for Incapacitado ou cair a 0 PV.
- **Selar**: magia que cruza o selo é barrada (mesmo rank ou abaixo) ou sai com metade dos dados/área/duração (1 rank acima). Adaptação: se o golpe cruza selos com fatores diferentes, vale o menor, para todos os alvos daquela magia.
- **Sinalizar**: marca visível de 1 casa por 1 rodada (zona sem efeito).
- **Encostar** numa parede com essência: comando `tocarFormula` (gratuito, adjacente). Fogo: dados de contato d6 ígneo, Agilidade CD 8 + BC para metade, 1×/rodada; Água: Agilidade ou Molhado; Vento: Força ou empurrado 1 casa, 1×/rodada; Terra/Som: só o registro. Inimigos da IA não encostam de propósito.
- **Erguer com Vida**: o aliado ao toque indicado em `alvoId` recebe os PV temporários; sem alvo válido, ninguém recebe.
- Fora do escopo: Frase Composta, formas além das três, pedra, fórmulas armadas, pergaminho como item transferível.


## 7K. A20 — Principiante das árvores de utilidade (Claude, 09/10/2026)

Regras puras em `Regras/Utilidades.luau`; servidor em `server/UtilidadesService.luau` (ganchos no HabilidadeService); ganchos genéricos no resolvedor: `conjurador.aposRolarAtaque`, `alvo.aposRolarTeste`, `conjurador.desvantagem`, `alvo.bonusDeAcerto`. Três personagens prontos novos: Nyx (Furtividade e Armadilhas), Lírio (Bardo) e Orion (Navegação e Liderança); a escolha agora tem 17.

| Carta | Livro | No jogo / adaptação |
| --- | --- | --- |
| Se Esconder (Cap. 4, todos) | 1 Ação; Cobertura, escuridão ou fora da vista; Agilidade (Furtividade) contra 10 + Espírito de cada inimigo | Exige névoa ou nenhum inimigo com linha de visão. Criatura usa o bônus de resistência do Apêndice G no lugar do Espírito. A perícia Furtividade não entra (a ficha não exporta perícias). Escondido: Vantagem (resolvedor), a IA não o escolhe como alvo, atacar revela. |
| Dano Furtivo (maestria) | 1×/turno, acerto contra Desprevenido, Cego, imobilizado ou com Vantagem: +1d6 por patamar | Desprevenido = ainda não agiu no combate, Surpreso ou atacante Escondido. Imobilizado = Agarrado, Preso, Paralisado, Petrificado, Inconsciente. |
| Primeiro Golpe | 1×/combate, alvo Desprevenido, Dano Furtivo triplicado | Ataque com arma; recusado antes do custo se o alvo não estiver Desprevenido. |
| Duelista de Rua | arma leve: +2 CA contra um oponente por turno | "Arma leve" = grupo Lâminas Curtas; o oponente é o primeiro que te ataca na rodada. O "não provoca oportunidade" não se aplica (não há Ataque de Oportunidade no jogo). |
| Nunca Preso | escapa de contenção não mágica com 1 Ação e Vantagem Absoluta | 3d20 no Escapar do Agarrão (a Mão de Terra é mágica e não conta). |
| Boticário | Vigor (CD 8 + Intelecto + Rank) ou Envenenado 1 minuto | Carta "Veneno de campo", 1 Ação, ao toque (o livro não dá o custo; adaptação). |
| Mãos Rápidas, Engenhoca, Falsário | exploração/roubo/armadilha de 10 min | Fora do combate por turnos: só na ficha. |
| Inspiração | Dado (1d6 no 1º–2º patamar) a um aliado que ouve; usos = Espírito por Descanso Longo; soma a qualquer teste mesmo após ver | 1 Ação, aliado a até 12 casas (voz). Usos por combate (o combate termina com descanso automático). O jogo pergunta ao aliado quando o ataque erra ou o teste de resistência falha. |
| Insulto Afiado | 1 Ação: Espírito contra Intuição; vence → próximo ataque do alvo com Desvantagem | Intuição da criatura = bônus de resistência de Espírito (Apêndice G). |
| A Plateia — Canções | 1 Ação para começar/trocar; uma por vez; acaba se silenciado ou nocauteado | Dissonância: no começo da sua vez, até patamar criaturas hostis que ouvem (12 casas, não Surdas, não constructos) sofrem 1d6 sônico por patamar, as mais próximas primeiro. Marcha (talento): aliados que ouvem +1 casa de Deslocamento (soma: bônus de aliado que gastou Ação, Cap. 4 §5). "Parar a canção" sem Ação. |
| Refrão da Retomada | Reação + 1 PP quando aliado a até 9 m erra ataque: até 3 aliados recebem 1d6 + patamar PV temporários | O jogo pergunta ao bardo; escolhe automaticamente os 3 aliados com menor fração de PV a até 6 casas. |
| Ordem de Tiro (maestria) | sem Ação, 1×/turno: Apontado até sua próxima vez; o primeiro acerto (seu ou de aliado) +1d6 por patamar; com Hastes/Arcos você soma o Rank no acerto e no dano; reapontar o mesmo alvo não acertado acumula até 2× patamar | Como no livro. |
| Voz que Corrige | Reação, 1×/turno: ataque contra o Apontado erra → quem errou rola de novo | O jogo pergunta ao Tático; a nova rolagem é um d20 simples. |
| Primeiro a Ver | entrando em combate de uma marcha conduzida por você, aliados somam seu Rank na Iniciativa e você escolhe quem age primeiro | Vale no início do Desafio (Modo Luta); a escolha de quem age primeiro não está no jogo. |
| Onde Pisar, Mapa Vivo, Suprimento, Sinais, Conhecimento de Bestas, Olho de Cerco, Voz Emprestada, Colecionador, Contrato | exploração | Fora do combate por turnos. |

## 7L. G1 — gamificação da apresentação (Codex, 10/10/2026)

Pedro autorizou priorizar a experiência de jogo sobre a reprodução literal da mesa. Nesta primeira rodada, as adaptações são de apresentação: cartas agrupadas por intenção; custo e motivo de bloqueio visíveis; destaque para encerrar a vez; vinhetas a partir de resultado confirmado e gestos locais de Bardo/Ladino/Tático. Cálculos, custos, alvos, duração e regras do livro não foram alterados. Não há turno automático ao zerar Ações: cartas gratuitas continuam possíveis. A categoria Golpes/Apoio é navegação, não uma categoria de regra. Cartas de consulta continuam disponíveis em Tudo.

Animações não significam dano, cura ou benefício extra: canções são gestos de regência e ondas visuais; apontar desenha a marca no alvo; esconder abaixa a postura do fantasma local; Primeiro Golpe encena dois cortes, mas o servidor resolve a mesma ação anterior. Só informações já filtradas pelo servidor entram na vinheta. Direção e limites em GAMIFICACAO.md.

## 7M. G2 — projeção da ordem de turnos (Codex, 10/10/2026)

A fila visual gira a iniciativa para começar no ator atual, sem alterar o array do servidor. Só inclui fichas presentes no snapshot filtrado; ator oculto não é reconstruído e o primeiro participante é rotulado Próximo visível. Caídos permanecem se o servidor ainda os mantiver na ordem. Contagem é de participantes visíveis, não de turnos até agir. Rolagem, rótulos, retirada do letreiro duplicado e atualização inicial do HUD são apresentação; nenhuma mudança de custo, tempo, recurso, regra ou recompensa.

## 7N. G3 — consulta e confirmação de cartas (Codex, 10/10/2026)

A janela de detalhes apresenta a descrição já existente da mecânica e, quando diferente, o texto do catálogo identificado como No livro. O custo continua vindo de Execucao; cartas indisponíveis/manual/passivas dizem Consulta, sem simular custo executável. Abrir detalhes não usa habilidade e cancela mira anterior. O botão Usar habilidade/Confirmar N alvos chama o mesmo dispararMira usado pelo segundo clique; não envia resultado nem contorna a validação do servidor. Sem alvo em lista ou com impedimento local, não dispara. Troca de turno limpa mira antiga e consulta; troca de aba volta ao início da rolagem. Nenhuma mudança de regra, recompensa ou recurso.

## 7O. G4 — apresentação das Reações (Codex, 10/10/2026)

Texto completo rolável, prazo em segundos, atalhos 1–9 para escolher e 0/Espaço para passar; não valem ao digitar. Fechar ao expirar localmente não envia escolha. Servidor mantém pergunta, prazo, validação, custo e resultado. Nenhuma alteração de regra.

## 7P. G5 — Fogo e orientação das árvores (Codex, 10/10/2026)

Autorização direta do Pedro em 10/10: “melhore as arvores […] vc pode gamificar, mudar algumas coisas”. Adaptação exclusivamente no jogo, sem modificar o site, catálogo exportado ou cálculos do livro.

| Técnica | Antes / livro | Jogo G5 |
| --- | --- | --- |
| Fagulha | Acende material inflamável, sem dano direto. Na grade sem objetos: só animação/registro. | Perigo em **uma casa visível a até 6 casas**, por **2 rodadas**. Entrar ou atravessar causa **1d4 ígneo por zona por movimento**, inclusive aliados/criador e empurrões. Sem dano ao criar ou permanecer, sem Em Chamas e sem bloqueio de visão/passagem. Expira na primeira troca de vez da rodada limite ou no fim do combate. **1 Ação/1 PM preservados**. |
| Brasa | 1d6 + BC ígneo, uma vez por turno. | **+1d4 ígneo se o alvo já estiver Em Chamas no acerto**. Erro não rola dano. Crítico dobra os dados das duas parcelas; BC só uma vez. Resistências/imunidades e arredondamento por parcela existentes continuam. **1 Ação/0 PM, alcance e uma vez por turno preservados**. |

O servidor passa o estado real do alvo ao resolvedor; bônus/condições/dano enviados pelo cliente não são usados. Forma interna `casa` valida inteiro/limites, parede, alcance e visão antes de cobrar. Perigos distintos atravessados agora cobram cada um uma vez (inclusive sobreposição); antes só o primeiro perigo do percurso cobrava e mascarava os demais. Não há dano extra por cada casa da mesma zona. Cobranças param se a ficha cai/sai. Empurrões continuam passando pelo movimento autoritativo.

Fagulha usa braseiro baixo com aviso “1d4 ao entrar”, distinto do Muro de Chamas. PlanosArvores só orienta técnicas executáveis de Fogo/Água/Vento/Terra, com conhecida/aprenda abaixo. Não concede técnica, rank, recurso ou bônus. A página separa No jogo/No livro nas cartas com descrição executável; texto original permanece disponível. Água/Vento/Terra não receberam alteração numérica nesta rodada. Balanceamento e diversão não são atestados por specs.

Integração posterior J2 (14/10): o encontro autônomo reutiliza a mesma adaptação de Fagulha. Como a grade J2 não tem paredes/oclusão, cada casa na grade é visível; o servidor valida limites, alcance, posse, custo e turno. O percurso BFS autoritativo aciona zonas em movimento de jogadores e IA, inclusive atravessamento, e para se o ator cai. Zonas expiram no início da terceira rodada quando criadas na primeira (duas rodadas completas) ou no encerramento do encontro. Sem mudança numérica ou de regra.

J2/A3 (14/10): Lâmina de Vento reutiliza a mecânica de Principiante já registrada em `ArvoresPrincipiante`: compra e rank são exigidos, o BC vem da árvore do ID e o encontro aplica alcance, Ações, PM, dano cortante e Desequilibrado do resolvedor comum. Não altera números do livro; sua integração está limitada ao executor J2.

J2/A3 (14/10): Respingo também usa sua mecânica canônica: exige compra/rank, mantém dano contundente, alcance, custo, Molhado e uma utilização por turno. Molhado dura até o fim da próxima vez do conjurador, conforme o registro da carta.

J2/A3 (14/10): Flecha d’Água reutiliza a mecânica canônica comprada de Água, incluindo dano, BC, alcance, Ações, PM, Molhado e duração de dez rodadas. Sem ajuste numérico de regra.

J2/A3 (14/10): Escudo de Água cria linha transversal comprada de 2 casas, alcance 4, por 2 rodadas, cobrando 2 Ações/2 PM. No pipeline atual, a linha dá +5 CA ao aliado em sua casa ou quando a linha da IA a atravessa; não bloqueia visão/movimento/magia nem vira PV. A IA J2 só tem ataque físico não tipado contra jogadores; não há ataques/projéteis de jogadores contra aliados nem parcela ígnea tipada. A redução ígnea e essas rotas ficam pendentes até suportar dano/alvos tipados; não foram simuladas.

J2/A3 (14/10): Névoa Densa usa esfera de raio 4 casas, 2 Ações/1 PM e duração de 50 rodadas. Células ativas bloqueiam linha de visão mas não movimento. Um ocupante é tratado como Cego apenas em cópias de atacante/alvo durante a resolução; ao sair da zona ou expirar, nenhum estado de Cego fica persistido. Vento forte não existe como comando ambiental neste recorte.

J2/A3 (14/10): Sopro de Poeira usa cone direcional de 4 casas na grade, 1 Ação/1 PM e resistência de Vigor contra CD 8 + BC. Falha aplica Cego e Desequilibrado até o fim da próxima vez daquele alvo; sem dano. A geometria de grade usa a convenção compartilhada de cone (45° para cada lado do eixo selecionado) e afeta atores vivos dentro da área, incluindo aliados; mira e confirmação ocorrem antes da cobrança.

J2/A3 (14/10): Passo de Vento usa 2 Ações/2 PM para deslocar até 12 casas. Na grade, o caminho precisa estar livre e respeita atores, rochas e bordas; ignora terreno difícil e orçamento de movimento. Movimento vertical/voo não pode ser representado e ataques de oportunidade não existem no encontro atual.

J2/A3 (14/10): Vácuo Localizado custa 2 Ações/2 PM, alcance 6, causa 1d6 de sufocamento e Silenciado; patamar igual/menor não resiste e patamar maior testa Vigor contra CD 8 + BC. Sem campo de respiração no bestiário, a lista J2 é positiva e explícita: goblin batedor e lobo cinzento respiram; demais criaturas são desconhecidas e inelegíveis. “Não consecutivo” é aplicado por rodada do encontro: o mesmo alvo pode receber Vácuo após uma rodada intermediária, nunca em rodadas imediatamente adjacentes; a tentativa válida conta mesmo se o alvo resiste. Silenciado só é aplicado como estado canônico; nenhum efeito extra foi inventado.


## 7Q. G6 — Recuperação, furtividade e precisão do jogo (10/10/2026)

Autorização: Pedro pediu gamificar, facilitar Esconder, reduzir frustração de falhas e corrigir Caído/zero PV. Não altera site, catálogo ou valores calculados da ficha.

- Personagens criados em Treino, Desafios e PvP recebem perfil interno `balanceamentoJogo`: +2 em rolagens de ataque e +3 na CD de habilidades resolvidas por Habilidades (inclusive efeitos no acerto). Não soma dano nem BC; disputas opostas, apagar fogo, atributos, custos e naturais permanecem. PvP aplica o mesmo perfil aos dois lados. Importação/criação avulsa de mesa não recebe o perfil; o remoto não aceita esses bônus. Controle de escape conserva a CD que o resolvedor realmente produziu. Caso de referência: BC 3 contra CA 12 passa de 60% para 70% de acerto; CD 11 contra resistência +2 passa de 40% para 55% de aplicação. São probabilidades enumeradas, não comprovação de diversão ou equilíbrio de todas as classes.
- Esconder: 1 Ação, garantido fora da visão dos inimigos ou na névoa, sem o teste adicional contra todos os inimigos. Cada observador vivo vigia cone de 90° até 4 casas (6 m), distância euclidiana, limitado por linha de visão. Cego/Inconsciente não vigiam. Direção vem de movimento/ataque aceito pelo servidor; inicial aponta para o centro da mesa. Ser visto, inclusive atravessando o cone, ou atacar revela. Preserva Vantagem/Dano Furtivo e a restrição de Primeiro Golpe a uma vez por combate. Prévia tem contorno e seta por observador, com cores distintas, e usa somente observadores já presentes no snapshot filtrado; não dá conhecimento de personagens ocultos.
- Caído positivo não incapacita: ataques preservam Desvantagem e pode rastejar. Levantar custa 1 Ação e deixa metade do Deslocamento como saldo para movimento na mesma vez; saldo não passa ao próximo turno nem permite duplicação. Agarrado/atolado/imóvel deve se soltar; incapacitação e zero PV continuam impedindo agir. IA comum também pode levantar; invocado recebe a opção. Cura de zero remove Caído e Inconsciente; não remove outras aflições. Zero PV continua sendo derrota/inconsciência do jogo, não implementa Marcas da Morte do livro.
- Pose de jogador inclina a junta do corpo (Motor6D ou attachment de AnimationConstraint/RigidConstraint) e mantém a raiz da câmera vertical; restaura a junta ao levantar, recuperar PV ou sair. Não usa morte física/ragdoll do Humanoid. Criaturas restauram a pose ao recuperar-se.
- Muros já bloqueavam percurso reto no combate; corrigido atravessar fresta diagonal e caminho fora do combate. Deslocamentos de habilidade, empurrão/arrasto e busca da IA respeitam bloqueios diagonais. Destinos da IA exigem percurso reto livre; movimentos visuais consecutivos concluem a etapa anterior antes de iniciar a seguinte, evitando cortar um muro ao interromper uma animação. Arbitragem livre do mestre continua podendo reposicionar fichas sem a marca `andar`.
- Arremesso/Desarmar já produziam objetos no servidor: preservado item único, custo/alcance de recuperar e queda mesmo se arremesso errar. Visual passa a ter lâmina, guarda e cabo; é representação genérica de arma. Desarmar larga a uma casa (regra existente); não larga dentro de barreira. Recolher remove o modelo.
- Hover apresenta regras executáveis, fórmulas e valores base da própria ficha quando disponíveis; condições, cobertura e reações podem mudar o resultado. Bônus do jogo são identificados. Consulta não cobra nem lança habilidade. Não altera dados do livro.

## 7R. G7 — Esquivar, Bardo e sigilo da furtividade (10/10/2026)

Autorização: pedido direto do Pedro (Esquivar em si mesmo, clareza do Bardo, campo de visão, furtivo invisível aos outros, Esconder com teste, ADM em combate). Não altera site, catálogo ou valores da ficha.

- Esquivar: 1 Ação sobre si (`alvo = "si"`), sem alcance nem alvo inimigo; vale contra todos os atacantes até a próxima vez.
- Esconder (substitui o sucesso automático da §7Q): continua exigindo estar fora da visão ou na névoa, e agora rola Furtividade (bônus exportado da perícia, sem somar rank de novo; sem perícia, resistência de Agilidade) contra CD = maior entre 10 e 10 + Espírito de cada inimigo vivo a até 4 casas que veja o personagem. Falha cobra a Ação e não aplica Escondido; o recibo mostra o d20, o bônus e a CD.
- Escondido é sigilo do servidor: a ficha só vai ao snapshot do próprio dono (nem o mestre a recebe), não é alvo de ações dos outros nem da IA. O cliente apenas desenha "FURTIVO" para o dono.
- Paredes do mapa (chave com vírgula) bloqueiam a visão, inclusive pela quina diagonal.
- Bardo: só uma canção ativa por bardo; Marchas de bardos diferentes não acumulam (+1 casa). Um aliado guarda um Dado de Inspiração por vez; a carta recusa sem gastar uso nem Ação. A canção termina quando o bardo cai a 0 PV. O painel de apoio só cita fontes que o jogador pode ver.
- ADM: curar/recursos/reviver/limpar/pv/mana/pt/mover/acoes/passar/voltar funcionam durante o combate, com alvo `id|meus|todos`, valores limitados ao máximo da ficha e destino livre de parede/ocupação. Devolver Ações não renova técnicas de uma vez por turno. Ferramenta de teste, não regra do livro.

## G11/G12 — apresentação, muralha e Ladino (Pedro, 10/10/2026)

G11 não muda regras: detalhes de criaturas, preparo/erro/acerto, mira e resultado persistente são apresentação. Recuperação anunciada é a já existente no EncontroService.

Pedido confirmado: Muralha de Chama como **linha reta ajustável**, sem curvas. O limite do livro de 9 m permanece em 6 casas de 1,5 m. Adaptação da grade: escolher uma casa vizinha como início e 1–6 casas nas oito direções, com confirmação; não atravessar parede/quina. Custos, duração, dano e condições não mudam. O cliente não recebe liberdade para deslocar a origem para longe, exceder o comprimento ou enviar uma área arbitrária. Caminho antigo só com direção preservado, agora também respeitando cantos de pedra.

Pedido de gamificação: **Se Esconder exclusivo do Ladino**. Na construção por árvores, isso significa ter rank aberto em Furtividade e Armadilhas; personagens/multiclasse com essa árvore podem usar. Retirada a carta das outras fichas e validado no servidor, inclusive pedidos forjados. A restrição é adaptação autorizada, substituindo a disponibilidade universal anterior; custo/teste/CD, revelação e sigilo continuam iguais. Não altera o livro/site.

Correção de frestas: linha de visão cobre todas as casas tocadas pelo segmento entre centros, inclusive os dois lados de uma quina exata. Uma fresta decorativa de uma parede sólida não é passagem para ataque. Origens/destinos mantêm o tratamento anterior; o resolvedor mantém suas exceções explícitas (como ataque físico interceptado por barreira com PV). Golpe Circular continua seguindo sua regra de adjacência, sem acrescentar visão nesta entrega. Não há testes físicos de altura/balística: combate é na grade.

## A1 — aparência racial e cosméticos (Pedro/Codex, 16/10/2026)

Fonte de características: descrições de `shared/Livro/Dados/Racas`, somente leitura. Avatar R15 de corpo padrão blocado, cabeça cúbica e rosto de blocos são direção visual do Pedro, separados dos cálculos. Escalas abaixo são **adaptações cosméticas provisórias**, em altura/largura/profundidade/cabeça; não convertem metros do livro nem alteram alcance, deslocamento, categoria de tamanho, voo, recursos ou recompensas mecânicas. Paleta humana base = clara, média, escura e oliva; a escolha não representa atributo.

| Raça | Interpretação visual atual |
| --- | --- |
| Humano | 1/1/1/1; paleta base, sem peça obrigatória. |
| Elfo | 1,04/0,92/0,92/1; esguio, paleta base, `OrelhasElficas` obrigatórias. |
| Anão | 0,85/1,12/1,10/0,95; baixo/largo, paleta base, barba opcional. |
| Hobbit | 0,78/0,90/0,90/1,05; pequeno e cabeça proporcionalmente maior, paleta base. |
| Raça Fera | 1,03/1,06/1,04/1; paleta base e `OrelhasBestiais` obrigatórias como simplificação dos traços mamíferos. |
| Celestial | 1/1/1/1; paleta base, `AsasCelestial` obrigatórias, sem conceder movimento por aparência. |
| Oceano | 1/1/1/1 e paleta base; a descrição não determina pele azul ou anatomia, portanto nenhum desses traços foi imposto. |
| Migurd | 0,90/0,92/0,92/1,02; aparência adolescente, paleta base, olhos e cabelo exclusivamente azuis. |
| Superd | 1/1/1/1; pele clara, cabelo exclusivamente verde, `CaudaSuperd` obrigatória. Cauda apenas decorativa; a lança/ataque do livro continuam pertencendo à ficha. |
| Ogro | 1,18/1,15/1,12/1,08; maior/largo, paleta base. `ChifresOgro` opcionais são uma adaptação artística explícita, sem fundamento anatômico na descrição do livro. |
| Demônio Imortal | 1,04/1,02/1,02/1, pele azeviche. Seis braços masculinos **não representados** neste rig R15: limitação visual documentada. Continua bloqueado na criação atual. |
| Dragão | 1,12/1,08/1,08/1,05; "corpo de gente" do livro: aparência humana sem chifres/cauda, cabelo prateado ou branco, olhos dourados e pele clara, como Orsted/Perugius em Mushoku Tensei (Pedro, 16/10). Continua bloqueado na criação atual. |

Cabeça recebe cubo real após a descrição padrão. Peças raciais/cabelos/barbas/roupas básicas dependem do A2; ausência não interrompe o jogo e pode deixar temporariamente um traço sem representação. Olhos, sobrancelhas, nariz (incluindo ausência) e boca são listas puras de cuboides na face; sem imagem enviada. Paletas, medidas e desenho exigem avaliação artística posterior. A elegibilidade de raça continua em RunBeneficiosConta/criação, nunca na aparência.

Os oito trajes dos treinadores compõem loot **raro cosmético permanente de conta**, sem efeito de ficha. Chance **PROVISÓRIA de 15% por jogador participante por vitória de chefe da run**, uma peça ainda não possuída, uniforme entre os IDs raros restantes; pool esgotado não dá peça. Mesmo pool nos chefes da Floresta e Ruínas (história atual); nenhum drop em derrota, fuga ou encontro comum. Não é uma regra ou tabela de tesouro do livro. Posse e recibo (também sem prêmio) persistem juntos; armazenamento indisponível não produz evento de sucesso. Ver contratos/limites em MANUTENCAO e evidência em TESTES.

## J1 — custo inicial da escolha de raça (13/10/2026)

Livro/site: Cap. 1, §5 (`Chapter1.tsx`) define 3 PA iniciais; escolher raça custa 1 PA para tier comum/incomum, 2 para rara e 3 para lendária/mítica. Selecionar também um antecedente não adiciona custo; escolher apenas antecedente custa 1 PA. O formulário J1 exige escolha de raça, aplica a primeira regra e mostra o saldo. O caminho de antecedente sem raça e o sorteio de raça não estão implementados. Por adaptação provisória aprovada, o saldo é informativo e não limita compras: `Progressao.podeComprar` valida somente habilidade permitida no rank aberto, sem abrir rank, XP ou persistência. Fonte original lida em modo somente leitura (`types.ts`, `Chapter1.tsx`); nenhuma alteração no site.


## 7S. N5 — Provação do Dojo (14/10/2026)
O livro descreve uma provação narrativa com critério próprio. J2 atualmente só encerra por vitória/derrota e não mantém critério de sobrevivência com o adversário vivo após 5 rodadas; MVP usa vitória no encontro contra um lobo cinzento existente. Mestre Hanzo não aparece no catálogo canônico de dojos; protótipo o configura como Avançado para a exigência de dois patamares sobre aluno Principiante. PA livre fica acumulado no estado do Dojo porque Progressao mantém PA infinito; PA travado fica associado à árvore.
## N6 — recompensa J2 (Codex, 14/10/2026)

Apêndice G: base 10/20/40/80/160/320; lacaio/padrão/chefe ×0,5/1/4; imunidade eleva patamar. O catálogo fornece patamar/papel e, quando existente, arquétipo/categoria; o mapeamento autoritativo do J2 está no elenco por ID canônico. Adaptações: Goblin Batedor (patamar 1/lacaio/Ágil/humanoide), sem imunidade; Lobo Cinzento (1/padrão/Bruto/besta), sem imunidade; Treant Ancião (3/chefe/Bruto/planta), sem imunidade, usando Bruto para a Fortaleza não suportada pelo cálculo do Apêndice G. Boneco de treino não é criatura hostil canônica e não paga recompensa. Zonas não alteram os valores. N6c liquida na guilda, a 100%, o valor de tralhas/partes porque ainda não há inventário de espólio; equipamento sorteado só fica registrado no valor da recompensa e não é pago/entregue. Cada participante vivo recebe o mesmo pagamento total em PO, sem divisão; desistentes/derrotados e encontros encerrados por derrota não pagam. `ritmoDePa.ts` trata PA por sessão/marco, não por encontro; N6b continua pendente.

N7 usa a regra `Loja` para rank F, prateleira, preços e revenda (tralha a 100%, demais itens a 50%, relíquia nunca). A tela vende itens do catálogo canônico, mas inventário comprado/vendido e ouro são persistidos no perfil J1; schema v4 migrou v1–v3 sem inventário de loja. A Poção Menor de Cura mantém nome e descrição canônicos exigidos pelo consumível J2. Isso não adiciona item ao loot de encontro nem permite venda de equipamento ativo.

## N8 — missões da vila (14/10/2026)

Missões são conteúdo/adaptação do jogo, sem regra nova do livro: Caçada no Bosque exige duas vitórias no marco do bosque e paga 30 PO; Sombra da Floresta exige uma vitória no marco da Floresta Sombria e paga 80 PO. Valores provisórios de economia. Só contam vitórias em que o jogador permaneceu vivo e recebeu a recompensa N6; cada ID único de encontro é registrado uma vez. Entregar muda o estado e credita PO na mesma gravação do perfil. A tela e o aviso não alteram resolução do combate.

`ritmoDePa.ts` só define PA por sessão e marco, não por encontro; sem PA em N6, pendência N6b.

## N9 — orçamento dos encontros por zona (14/10/2026)

Adaptação de dificuldade/conteúdo do jogo, sem alterar fichas, PV, dano, CA ou resolução. **B1 (Pedro, 17/10): derrota continua encerrando a run; sem tutorial.** Apêndice G: peso `2^(patamar + imunidade - patamarGrupo) × papel`, papéis lacaio/padrão/chefe 0,5/1/4; orçamento = jogadores, Fácil ≤0,75, Equilibrado ≤1, Difícil ≤1,25 (fonte conferida em R7b abaixo). Para um iniciante de patamar 1, **um rato ou goblin lacaio pesa 0,5: Fácil**. São as criaturas canônicas mais fracas do catálogo; nenhuma de patamar menor existe. Não se criou lacaio de lacaio nem se alterou o molde.

Curva em `EncontrosPorZona`: região inicial/estrada ficam com rato/goblin lacaios, um por jogador. A formação começa a oito casas (criaturas z=18, jogadores z=10), abrindo uma troca com Disparo básico durante a aproximação da IA; isso altera **onde** os atores aparecem, sem diminuir dano, reduzir ações ou inventar surpresa. Patrulhas encaminham seu marco de conteúdo ao elenco, preservando a arena física no contato; trilha em (4,-315) passa de lobo padrão para um goblin lacaio por jogador, na formação próxima original (peso 0,5: Fácil no Apêndice G; risco médio no começo pela distância curta). Dois lacaios, embora Equilibrado no orçamento, mediram apenas 0–11% de vitória sem habilidades e foram rejeitados. O bosque existente mantém lobos padrão (peso 1). “Lobos na estrada” sai de (14,-110) para a borda da floresta (28,-345); nome/local e **Perigo: alto** aparecem no bilhete. Seu peso continua 1, mas o aviso mede risco para iniciante, não reclassifica o Apêndice G. Interior da floresta, passagem, Ruínas e guardiões permanecem com seus elencos anteriores. Quadro: quaisquer três das quatro ofertas contêm pelo menos duas fáceis próximas. IDs preservados por compatibilidade com saves.

A bancada B1 usa os presets canônicos após a primeira provação (Água e Furtividade), sem habilidades compradas/poções, só Ataque, Disparo básico e Defender. Antes de aprender árvore não há corpo J2 elegível no serviço atual; não se inventou uma ficha inicial alternativa. Orçamento não garante vitória; evidência e limites da simulação em [TESTES](TESTES.md#b1--equilíbrio-e-defeitos-17102026).

## R2a - patrulha e terreno no local (14/10/2026)
Adaptacao de produto do PLANO 12, sem alterar o livro: um Goblin Batedor canonico, cone de 100 graus/20 studs, verificacao a cada 0,25 s, patrulha 4 studs/s, perseguicao 9 studs/s e contato a 5 studs com raycast livre. Perde alvo apos 5 s sem deteccao ou 30 studs da origem; retorna apos liberacao terminal, com 15 s de espera. Um encontro global, somente o alvo entra nesta etapa (jogadores da fila nao sao capturados).
Grade 20x20 de 1,8 studs/casa no X/Z do inimigo; raycast por centro de casa, sem piso, inclinacao >18 graus, obstaculo marcado ou altura absoluta >0,75 stud bloqueiam a casa. Este ultimo limite e conservador porque avatares/miniaturas ainda usam y=0; andares/terreno elevado nao sao suportados. Spawn bloqueado recusa o encontro em vez de deslocar atores. Terreno e apresentacao compartilham a amostra; marcos de reserva conservam layout fixo. Recompensa/missao usa a identidade canonica da clareira, separada da ancora de projecao.
Surpresa, fuga por Atletismo, camera superior e entrada tardia permanecem em R2b; nenhuma adaptacao dessas regras foi aplicada. Evidencias em TESTES, localizacao em MANUTENCAO.

## R3a — força das árvores no sorteio da run (Claude, 14/10/2026)

Adaptação de produto, sem alterar o livro: o PLANO §12 pede oferta ponderada ("mais forte, mais rara"). O livro não dá nota de força; esta é uma medida **de desenho**, auditável, em `shared/Regras/RunArvoresForca.luau` (+ spec).

**Método.** Para cada árvore, extração mecânica (subagente Sonnet, 19/19 árvores, 85 habilidades Principiante, conferida contra a contagem de ids) das habilidades Principiante por função: ataque/dano 2, cura 2, proteção 1,5, controle/mobilidade/utilidade 1, passiva/reação/outro 0,5 pontos cada. A nota é a soma, escalada para 1–10 (15 pontos ≈ 10), que `RunSorteios.pesoDeForca` converte em peso (11 − força). Resultado: Água 10, Desintoxicação 10, Terra 9, Deus do Norte 9, Deus da Espada 8, Fogo 7, Vento 7, Lutador 7, Cavalaria 7, Cura 6, Deus da Água 6, Arquearia 6, Vendaval 5, Teórica 4, Punho do Fogo 3; Invocação, Bardo, Furtividade e Navegação ficam na nota neutra 5.

**Limites (não tratar como balanceamento).** A nota mede cobertura de papéis, não dano real, sinergia nem rank maior. Árvores cujo valor está em talentos ou no Intermediário (Invocação, Bardo, Furtividade, Navegação) **não foram avaliadas** e recebem a nota neutra, não uma nota inventada. Os talentos (3–8 por árvore) não foram analisados. Os pesos de função são julgamento de design e devem ser ajustados com playtest.

**Achado de porte (importa mais que a nota).** A oferta só inclui árvore com ao menos 3 habilidades Principiante executáveis no jogo hoje (1 para utilidade/invocação), para o jogador não receber personagem sem ação em combate. Hoje ficam **fora**: Vendaval (0 de 4) e Punho do Fogo (0 de 3), sem porte; Deus da Água (1 de 5; reações/passivas indisponíveis); Arquearia (2 de 4); Magia Teórica (2 de 4); Navegação (0 de 1) é a exceção: entra na oferta por `valorNaRun`, porque "Explorador" é o nome do 1º rank dela no livro (`rankLabels`) e a run depende dele (voto ×2, viagem, eventos, sem emboscada). Portar essas habilidades as libera automaticamente (basta atualizar `exec`).

**Dados incompletos.** Nas árvores de PT a maioria das habilidades não traz custo de recurso no catálogo; "campo ausente" não foi tratado como 0. Alcances não foram comparados entre catálogo e porte.

## R3b — criação por run: modos, PA extra e defeitos (Claude, 14/10/2026)
Atualização 23/10/2026: com o J2 apagado (PLANO §13), as lutas acontecem no motor da mesa, que ainda não aplica os efeitos de defeitos em combate; eles continuam valendo em perícias/eventos de caminho. A bancada B1 abaixo descreve o motor J2 e é histórica.
Adaptação de produto do PLANO §12, sem regra nova do livro. Valores **provisórios** (`RunCriacao`): sem árvore +2 PA; personagem pronto +3 PA e +1 por defeito (2 defeitos), recompensa final ×1,25 por defeito (×1,5), nunca abaixo da base. O livro dá 3 PA iniciais (J1) e a Progressao usa PA infinito, portanto o PA extra é só registrado até o motor contar PA. A ficha pronta vem de `PersonagensProntos` (17 fichas, uma por árvore); só as de árvore elegível entram no sorteio, com as mais fortes mais raras. Defeitos usam Desvantagem/deslocamento já existentes no livro (ver `RunDefeitos`); a mecânica só é aplicada quando o motor consumir `efeitos`. Pendente: UI de escolha, persistência do plano (R5), aplicar os efeitos no combate/perícias.

## R2b — surpresa, fuga e entrada na grade (regras puras, Claude, 14/10/2026)

**R2c — fuga integrada (Codex, 15/10):** exige chegar à borda tática confirmada (x/z 1 ou 20). Tentar custa **1 das 3 Ações**, adaptação provisória do jogo: o livro não estabelece custo para este teste de fuga. Falha descarta as Ações restantes pelo fim de turno existente, incluindo efeitos de início da próxima vez. Sucesso retira somente o fugitivo e preserva seus PV/PM/PT/PP no corpo do encontro; não marca derrota, não recompensa nem aplica descanso RB-25. Em grupo, a luta continua; sem jogador vivo restante, `fled` é terminal e permite o retorno autenticado que libera a arena e a patrulha (espera existente de 15 s). A restauração de controles do avatar não é descanso da ficha.

Atletismo vem de `calculated.skills[{skillId="skill/atletismo"}].bonus`, derivado por `PericiasPersonagem` de **Força + bônus de rank quando treinada**, sem novo modificador. Para corpo legado sem essa entrada, usa só `calculated.attributes.forca` (sem presumir treino). Deslocamento pessoal: `calculated.movementMeters`; perseguidores: `Livro/Dados/Criaturas.data.deslocamento`, em metros, somente criaturas vivas na fila. Mantidos integralmente CD/20/1 naturais do módulo puro de Claude. Não houve alteração de dano ou cálculo de ficha.

**R2d — entrada tardia integrada (Codex, 15/10):** adaptação de produto do PLANO §12, sem mudar cálculos do livro. A grade é quadrada, 20×20 casas de 1,8 stud; distâncias ao centro usam máximo de |X|/|Z| convertido em metros táticos (1,5 m/casa), preservando os cantos. Raio da grade: 15 m (18 studs); raio inicial de entrada: **3 m/duas casas/3,6 studs**, provisório. No contato, aliados elegíveis nesse raio entram com o alvo, até quatro. Quem está no restante da grade ou chega depois é reservado para o começo da rodada seguinte à observação no servidor (0,25 s e antes de avançar a vez); continua livre antes da confirmação. Fora da grade, ou com raiz a mais de 6 studs de altura do plano, não entra. Não há solicitação remota de entrada.

Confirmação revalida identidade conectada, mesmo Character vivo, ficha carregada com PV, ausência de outro encontro/fila/combate legado e posição dentro da grade. Sair cancela a reserva; voltar exige nova observação e nova rodada seguinte. Encontro terminal não admite ninguém. Identidades já participantes (inclusive fugitivos/retornados) permanecem reservadas até limpar o encontro; ninguém reentra no mesmo encontro, e o limite de quatro inclui esses antigos participantes. Sem borda livre, a tentativa é cancelada e pode ser observada novamente para outra rodada.

A casa inicial é a borda livre de menor distância euclidiana ao **ponto onde o servidor observou a entrada**, com desempate por X e depois Z. Usa bloqueios amostrados da GradeTatica, muros ainda ativos na nova rodada e ocupantes (jogadores caídos inclusive; fugitivos e criaturas removidas não ocupam). Montagem e recursos usam o mesmo Elenco/preparação do grupo inicial, com cópia privada da ficha. **Iniciativa RB-13:** só o entrante rola, com bônus/vantagem da ficha; resultados antigos são preservados. Ordenação por total, bônus e estabilidade, deixando antigos antes do novo em empate completo; a nova ordem vale antes do primeiro ator da rodada seguinte, após expirar a prioridade de surpresa da rodada 1. Não rerrola o grupo nem ajusta o elenco inimigo/recompensa para a chegada. O recibo da transição agrega `joinedActors`; todos os participantes e o novo recebem recibo e snapshot privado. Não gasta Ação para entrar.

**Limites:** câmera superior aguarda Pedro. Recursos preservados aqui são os do corpo privado do encontro: a gravação de recursos de combate no perfil pessoal entre encontros não é fornecida pela integração J2 atual (`MesaService.corpoPessoal` reconstrói a ficha do perfil). R2c/R2d não criam persistência nem declaram esse ciclo validado. Multiplayer real e equilíbrio ainda pendentes; evidências em [TESTES](TESTES.md).
Integração Codex: contato a até 5 studs (distância 3D já usada em R2a), com raycast livre, também inicia pelas costas. O cone é conferido no instante do contato, inclusive entre verificações de percepção; detecção prévia conserva memória por 5 s. Sem emboscadas automáticas nem integração de Explorador neste trecho. O servidor aplica `ordemComSurpresa` depois de rolar RB-13; na rodada 2 restaura a ordem rolada, filtrando derrotados. `desprevenido` é condição do encontro até começar a primeira vez do alvo; não altera ficha, CA, dano ou resolvedores e preserva condição preexistente. Fuga e entrada tardia integradas conforme R2c/R2d acima.
`shared/Regras/EncontroPatrulha.luau`. **Surpresa** apoia-se na condição Desprevenido do livro ("ainda não agiu neste combate, está Surpreso ou não sabe onde você está"): o jogador que inicia o contato sem ter sido visto surpreende; o lado surpreendente age primeiro na 1ª rodada e o outro fica Desprevenido até agir. Grupo com Explorador (Navegação e Liderança) nunca é emboscado (regra do livro ao liderar a marcha). **Fuga** (adaptação do PLANO §12): d20 + Atletismo contra CD 10 + 1 por casa de 1,5 m de deslocamento que o perseguidor mais rápido tem a mais (teto 25); 20 natural foge, 1 natural falha; falhar custa o turno, fugir faz a criatura voltar a patrulhar. **Grade**: "dentro" entra já, "ao pisar" entra no começo da rodada seguinte, "fora" ainda não. CD, teto e raios são provisórios; o livro não define fuga de encontro por patrulha.

## R3c / F4 / T1 — treinadores e provações da run (16/10/2026)
Decisão do Pedro (16/10): somente **Ladino** (`furtividade-e-armadilhas`) e **Mestra da Água** (`agua`) ficam disponíveis. `RunTreinadores.SOMENTE_FIXOS = true` desliga os demais reversivelmente; `sortearAleatorio`, candidatos, raridade, vagas e parâmetros antigos continuam preservados. Os fixos independem do desbloqueio da taverna; saves antigos mantêm seus dados e recibos, mas a oferta apresentada passa a ser fixa.

Adaptação da **provação do dojo, Cap. 5 §5**: os critérios narrativos viram dois minigames próprios. O Sino do Ladino exige pegar e devolver o sino sem detecção (cone horizontal de 70°, alcance 20 studs ou 10 agachado, oclusão física; amostragem servidor 10 Hz). Ser visto reinicia no portão e devolve o sino, sem limite de tentativas. As Comportas usa uma árvore aleatória de caminhos em grade 5×5: retos, curvas, T, cruz e tampões terminais; três saídas precisam estar ligadas em menos de 90 s. Fluxo aparece imediatamente, sem acumular água de rotações anteriores. A solução nunca é enviada ao cliente. Cada peça gira com prompt de mouse/toque, alcance servidor ≤12 studs e intervalo de 1/6 s.

A aprovação concede a árvore por `RunSessao:treinar`, gasta **1 dia do grupo, sem PA**, e grava árvore/dia/recibo no mesmo save, com rollback e replay. Falha/cancelamento/expiração da tentativa não gasta dia. Uma vaga por prova; demais recebem “Ocupado — aguarde” e podem tentar outra vez. Prova/tempo não persistem nem sobrevivem à desconexão; aprovação não salva pode ser reenviada pelo treinador. Contrato F4 de **aquisição inicial no modo sem árvore, uma vez**; a ficha J1 recebe sozinha a árvore aprendida (P2, 17/10). **Segunda árvore (decisão do Pedro, P2):** quem já tem uma árvore pode passar na provação de OUTRO mestre e aprendê-la como segunda (regra do dojo do livro: aprender outra árvore passando por um mestre), por 1 dia e sem PA; não repete árvore já conhecida; limite provisório de UMA segunda por run — adaptação do protótipo, não conferida no texto do livro. Desde W1b, o plano também sincroniza a lista de árvores na ficha; ranks, cartas e persistência seguem a seção W1b acima. O dojo Hanzo/N5 e PA infinito da progressão permanecem fluxos distintos.

Identidades provisórias por HumanoidDescription: cores/proporções distintas, idle padrão existente; sem animação de braços cruzados confirmada. **Nenhum ID de catálogo adicionado**. Trajes Blender opcionais têm contrato em `Mundo/TreinadoresAparencia.TRAJES` (módulo/parte/offset), montagem por MontarModelo e WeldConstraint; ausência do módulo é ignorada. Mestra em plataforma calculada sobre o relevo na margem leste do lago, a oeste da vila; não modifica o Terrain. Pátio precisa de zona plana adicional descrita em TAREFAS. Falas provisórias em [DUBLAGEM_NPCS](DUBLAGEM_NPCS.md). Testes/evidências e limites em [TESTES](TESTES.md).

## R4a — viagem: custo, eventos, prévia e vetos (regras puras, Claude, 14/10/2026)
`shared/Regras/RunViagem.luau`. Adaptação do PLANO §12, sem regra de viagem no livro além de "liderar a marcha ignora terreno difícil natural" (Navegação e Liderança): Explorador no grupo encurta a viagem em 25% (múltiplo de 0,25 dia), favorece eventos bons (peso ×2) e reduz os ruins (×0,5), e é o único que vê a prévia da próxima região (chances em passos de 5%, sem itens/eventos exatos). Cavalo usa `Run.CUSTO_DIAS.viagemACavalo` e libera eventos de `modo = "cavalo"`. Defeitos vetam opções por tag (`RunDefeitos`); a UI de voto decide como mostrar quem fica sem poder escolher. Conteúdo e consequências atuais: seção R4b/F8 abaixo; parâmetros permanecem provisórios.

## R6a — conta entre runs (regras puras, Claude, 14/10/2026)
`shared/Regras/RunConta.luau`. Adaptação do PLANO §12 (nada disto existe no livro): ao fim da run a conta ganha moeda (final 100, derrota 20, +10 por região, +30 se o objetivo foi cumprido, tudo × multiplicador dos defeitos do personagem pronto), conquistas por condição sobre o resumo (4 provisórias), e o final alcançado entra no códice. A moeda compra desbloqueios de catálogo (treinadores raros — que só entram no sorteio da taverna depois de comprados —, raça rara, item inicial, cosmético). Valores e catálogo são provisórios; não há tela, persistência (serviço R5/R6b) nem balanceamento.

## F7 — aplicação dos desbloqueios da conta (Codex, 15/10/2026)
Adaptação de progressão entre runs (PLANO §12), sem alteração do livro: raça base = tiers comum/incomum; a compra legada `raca:rara` libera **Celestial, Superd e Ogro** (tier rara). Lendária/mítica aguardam desbloqueios próprios. Custo racial em PA e demais escolhas continuam sujeitos ao motor J1. J1 filtra a oferta e o servidor consulta a conta da conexão para aceitar a criação; falha de conta bloqueia.

`item:pocao-menor` concede uma **Poção Menor de Cura** (`item/pocao_menor_cura`, correspondência exata do livro, sem substituição) na criação dentro de uma run. Kit extra puro em `RunBeneficiosConta.KIT_EXTRA`; uma entrega por jogador/run (grupo + semente), persistida junto à ficha, com recibo estável e baixa ao vender/consumir. Recalcular ou reconectar não renova a entrega; o inventário pessoal existente continua persistente. O contexto singleton acompanha a única run deste servidor após iniciar/retomar, sem depender do cliente.

Treinadores: ligação F4 já consulta a conta de quem inicia a run; desbloqueio aumenta elegibilidade na taverna, sem garantir sorteio. Cosmético `capa-vermelha` permanece só registro na conta e descrição na tela, sem aparência aplicada nem efeito mecânico. Preços, base racial e benefícios são provisórios; ver evidências/limites em [TESTES](TESTES.md).

## R7a — esqueleto da história v1 (Claude, 14/10/2026)
`shared/Regras/RunHistoria.luau` (validador e navegação por dados) e `shared/Mundo/HistoriaV1.luau` (dados). Conteúdo do jogo, sem regra do livro: vila → Floresta Sombria ou Ruínas do Vale → guardião → retorno → 1 final, objetivo "levar o Selo à vila" em 12 dias. A câmara das Ruínas é uma tranca (`passagem-aberta`) que o jogo abre por habilidade de Terra, item ou escolha (ainda sem gatilho real). Prazo vencido não encerra a run (o final continua alcançável; consequências ficam a cargo da história). **Textos e nomes são marcadores provisórios** para o Pedro/IAs reescreverem; as Ruínas do Vale ainda não existem como região no mundo.

## R4b — eventos de viagem na run (Claude, 15/10/2026)
Ao entrar em outra região o grupo recebe um evento sorteado e vota (peso/ausência/empate de `RunVotacao`). F8 (16/10): catálogo **PROVISÓRIO** de 14 eventos (4 legados + 10 novos); testes opcionais e consequências reais em dias, flags e `run.ouroViagem`. Estrada/costa são encontros globais da viagem, sem nova região marítima física.

**F8 — adaptação:** quem testa é o maior bônus entre presentes não caídos, sem veto da opção e com ficha J1 calculada; não depende do voto individual. Empate de bônus usa dado entre IDs em ordem estável. Sem ficha apta, recusa a resolução; opções sem teste continuam disponíveis. Bônus de perícia lê `calculated.skills` derivado por `PericiasPersonagem` (atributo + rank quando treinada); atributo lê `calculated.attributes` diretamente. `Combate.resistencia` resolve d20 + bônus ≥ CD (sem sucesso/falha automática por 20/1); defeito correspondente em `RunDefeitos.efeitos().desvantagemEm` usa 2d20/menor. Vetos por tag continuam separados; novos testes não carregam veto da mesma perícia, permitindo a penalidade atuar.

Dias somam custo base + desfecho; positivos passam por `Run.gastarDias`, negativos recuperam no máximo o tempo já decorrido (dia mínimo zero), sem reativar objetivo expirado. PO usam **caixa compartilhado só da viagem**, inicial zero: ganho/perda não altera J1 nem moeda da conta; perda por falha limita ao saldo, compra garantida exige saldo. Valores/CD/textos/flags são conteúdo provisório. Resultado completo (executor, dados, bônus, CD, total, sucesso, texto e deltas efetivos) fica em `run.ultimoEvento`, visão/recibo e save v1 aditivo; saves antigos sem campos continuam válidos. Falha de gravação preserva estado anterior/votos e reutiliza a resolução em memória; crash antes de gravar não garante o mesmo dado. Não há nova recompensa entre runs nem combate disparado por evento. Verificação e limites em [TESTES](TESTES.md).

## F1 — defeitos do personagem pronto no J2 (Codex, 15/10/2026)

Adaptação de produto do PLANO §12/R3b, usando o catálogo provisório existente de `RunDefeitos`, sem mudar dados/cálculos do livro. `RunDefeitos.validarCombate`, `deslocamentoCombate` e `fontesDeDesvantagem` são extensões puras aditivas. `EncontroAutonomoCombate` prepara cópia do ator sem alterar a ficha pessoal/persistida; recebe RNG nos testes e mantém o resolvedor canônico de dados/condições.

- **Manco:** subtrai 3 m do deslocamento canônico, mínimo zero, antes de converter em casas de 1,5 m. Movimento usa o limite reduzido; fuga usa os metros reduzidos na CD já adotada em R2c (não altera Atletismo). Repreparar o ator recalcula da ficha, sem acumular a redução.
- **Frágil:** Desvantagem nos testes de Vigor, incluindo a resistência de aliados atingidos pelo Sopro de Poeira. O adaptador `soproComDefeitos` injeta uma condição interna apenas nas cópias locais de alvos/catálogo daquela resolução; o resolvedor canônico aplica o teste antes de decidir Cego/Desequilibrado. Essa condição não é gravada/replicada. Desvantagens não acumulam; Vantagem e Desvantagem se anulam pelo `Combate.d20` existente.
- **Zangado/Persuasão, Burro/Investigação, Medroso/Intimidação e Desastrado/Furtividade:** `testeComDefeitos` suporta cada nome exato, com recibo de dois d20/menor. Esses testes ainda não têm comandos no J2; não há penalidade inventada para ataques, dano, iniciativa, resistência de outro atributo ou fuga/Atletismo. Ao implementar essas ações, o servidor deve chamar esse resolvedor com o nome do teste. Vetos de eventos continuam separados.

O serviço aceita `deps.defeitosDe(userId)` ou registro tardio `api.definirProvedorDefeitos(fn)` exclusivamente servidor. Provedor síncrono devolve lista densa de IDs canônicos distintos (`{}` sem run/modo pronto); erro, suspensão, nil ou IDs inválidos recusam a admissão, sem ignorar penalidades. Os IDs/efeitos ficam capturados no encontro e não mudam durante ele. A ligação ao estado da run pertence ao Claude; contrato exato e verificação em [TAREFAS F1](TAREFAS.md).

Snapshot de cada ator inclui `defects`, `defectEffects`, `defectMovement` (base/metros efetivos/redução/casas); movimento e fuga incluem `result.defectMovement`. Cada resistência afetada no Sopro inclui `resistance.defects`, dados/ajuste canônicos e nota explicativa. A View atual não formata esses novos campos; não foi editada fora da reserva. O snapshot torna a causa consultável, sem permitir decisão mecânica no cliente. Specs puros em `DefeitosCombate.spec.luau`; sem Studio nesta entrega, logo integração run→rede/UI e multiplayer ainda não comprovados.

## R7b — guardião J2 da run (Codex, 15/10/2026)

`EncontrosPorZona.paraRun` escolhe conteúdo para **grupo de patamar 1**, sem alterar o livro. Fonte conferida somente leitura: site original `src/data/bestiary.ts`, `pesoNoOrcamento` (636–651), `TEMPERATURAS` (603–624) e `orcamentoDeEncontro`: peso = `2^(patamar + imunidade - patamarGrupo) × papel`, papéis 0,5/1/4; orçamento = jogadores. Fácil ≤0,75; Equilibrado ≤1; Difícil ≤1,25; acima disso Mortal. Logo, o exemplo de um padrão de patamar 2 contra um jogador de patamar 1 é **Mortal**, não Difícil.

Adaptação de conteúdo: o Urso da história é um guardião, **não o papel mecânico Chefe**. No solo recebe papel Lacaio pelo mesmo `Criaturas.aplicarPapel`: metade de PV/dano do molde, sem alterar CA/ataque/patamar/resistências. Peso 1, Equilibrado; não existe combinação inteira desse Urso e lacaios de patamar 1 entre 1 e 1,25 para solo. Em grupo conserva papel Padrão e completa o teto Difícil com padrões/lacaios existentes do N9:

| Jogadores | Elenco | Peso / orçamento | Faixa |
| --- | --- | --- | --- |
| 1 | Urso patamar 2 Lacaio | 1 / 1 | Equilibrado |
| 2 | Urso Padrão + Goblin Batedor | 2,5 / 2 | Difícil |
| 3 | Urso Padrão + Lobo Cinzento + Goblin | 3,5 / 3 | Difícil |
| 4 | Urso Padrão + 3 Lobos | 5 / 4 | Difícil |

O orçamento orienta conteúdo; não garante vitória. Play solo real com Água/cajado: duas derrotas e uma vitória, sem alterar PV/dados/estatísticas para obter o resultado. **Golem das Ruínas recusado com motivo claro:** patamar 2 com imunidades pesa 4 contra solo; até Lacaio pesa 2 (Mortal). Não foi reduzido silenciosamente nem substituído por outro monstro; conteúdo seguro das Ruínas requer decisão/ajuste no nó de história do Claude. Só o Urso base único está habilitado nesta entrega; arena `forest` ou `dark-forest` é independente da posição do grupo.

**Pagamento:** mantém N6, uma vez por encounterId, apenas na vitória e para participantes vivos que não fugiram; Urso solo paga 10 PO (base 20 × Lacaio 0,5). A conta R6 recebe moeda própria pelo fim da run; não recebe o espólio J2. Replay não repaga. Derrota/fuga não pagam PO. `aoEncerrar` agora cobre também `fled` total; fuga individual com aliados ativos não encerra a run. IA inicial da run é adiada até o chamador registrar o encounterId, evitando perder uma derrota no primeiro golpe. Evidências e limites em [TESTES](TESTES.md).
