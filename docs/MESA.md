## Vozes dos NPCs (11/10/2026)

Contrato aditivo aprovado em DISCUSSOES D-AUDIO-NPCS: token visível pode incluir `vozNPC`, enum cosmético fechado dos cinco repertórios atuais. Derivado de criatura.catalogId no servidor, após canSee; família sonora é pública mesmo com nome alterado/showStats=false, sem conceder PV/ficha/catálogo bruto ou fichas ocultas. Sons são locais; entrada/derrota/vida baixa por transições do snapshot, dor/ataque por recibos filtrados, fase/aviso pelo chefe público, execução somente chefeEfeito agiu=true com chefe ainda visível. Nenhuma intenção remota nova, custo, RNG, dano ou atraso de turno.

# Mesa virtual (modo mestre)

## Sala física G13/G14 — contrato atual, 11/10/2026

Entrada social anterior à partida; guia de uso em [SALA.md](SALA.md). Substitui a escolha de papel da G8 nesse fluxo: primeiro admitido é mestre; transferência é consentida e saída abre eleição. Permissão administrativa continua independente. Nenhuma publicação/configuração de limite de jogadores foi executada.

`snapshot.salaConceitual` reúne `mestre`, `pessoas` (id/nome/admitido/ficha/arma/pronto/equipe), `modo`, `nivel`, `monstros`, `copias`, `eleicao`, `ultimoBrotos`, `transicao`, `maos`, `ofertas`, `papeisSoltos` e `brincadeiraBrotos`. Mapas com UserId devem aceitar chave numérica ou string no cliente. O estado social não é ficha completa nem estado autoritativo do combate. Personagem escolhido e papel em mãos são estados independentes.

| Intenção no remoto Mesa | Decisão do servidor |
| --- | --- |
| `escolherPersonagem {id,arma}` | Catálogo/arma, admissão, disponibilidade da cópia e contexto; não basta segurar a folha |
| `salaPronto {ativo}` | Confirmação do admitido; alterar modo/equipe reinicia prontidão |
| `salaConfigurar {modo,nivel,monstros}` | Mestre, sem partida/transição, sentado em Seat com atributo LugarSala |
| `salaEquipe {userId,equipe}`, `salaCopia {id}`, `salaAdmitir {userId}`, `salaTransferir {userId}` | Permissão e contexto da sala; limites 6/10, cópias, lados e destinatário válidos |
| `salaIniciar {}` | Mestre sentado, checklist PreparacaoSala, prontidão/grupo e ausência de rodada recreativa em rolagem |
| `salaPapel {id=false}` | Libera mãos, sem apagar personagem |
| `salaPapel {id,objeto?,para?}` | ID do catálogo ou SalaItens, admitido fora de combate/transição, raiz até 24 studs da mesa. Recolher exige serial/ID coincidentes e até 22 studs; entrega só de ficha exige posse, dois admitidos/vivos sem carregamento, alvo com mãos livres, até 8 studs e visão livre; intervalo 0,6 s por remetente. Transfere ambas as mãos atomicamente, sem segundo pedido de posse do receptor. `objeto` e `para` juntos são recusados |
| `salaArremessar {id,direcao={x,y,z},forca,soltar?}` | Posse, posição na sala, vetor finito/tamanho válido, força 0–1, intervalo 0,65 s. Origem e relógio derivados do servidor |
| `salaDadosPegar {}` | Admitido, vivo, mão livre, sem estar carregado, raiz até 12 studs da bandeja; intervalo de 1 s também na criação, um trio por pessoa, sem substituir voo |
| `salaDadosLancar {direcao={x,y,z},forca,soltar?}` | Trio próprio nas mãos, contexto da sala, raio 24, direção finita normalizável e força 0–1. Servidor aplica impulso/propriedade de rede e decide três d6; nunca recebe origem, faces ou velocidade |
| `salaCarregar {userId?,soltar?}` | Dois admitidos/vivos, livres, até 6 studs e sem parede, dentro do lobby; recusa cadeia/recaptura em 3 s. `soltar=true` sempre permite ao alvo ou carregador encerrar, inclusive se o contexto mudou |
| `salaOlhar {x,y}` | Admitido, avatar, valores finitos nos limites ±1,3/±1,6; replica atributos do avatar. Comando silencioso, sem retransmitir snapshot inteiro a cada olhar |
| `salaBrotosAbrir {}`, `salaBrotos {}` | Mestre abre para admitidos presentes; cada um lança uma vez; prazo 15 s completa ausentes com RNG do servidor |
| `salaArrumar {}` | Mestre recolhe descritores arremessados; ADM autorizado também via `/adm arrumar` |
| `salaCandidatar {sim}`, `salaRolar {}` | Eleição separada, consentimento e rodada/participação validados por SalaRegras |

G16: `ofertas[userId]={id,de,serial}` informa a ficha já transferida; o cliente apresenta somente se `maos[userId]==id`. Não é autorização para sobrescrever outro objeto. Fechar uma consulta de escudo/placar não libera uma ficha que chegou enquanto ela estava aberta. Remetente aguarda confirmação mantendo interface na recusa; guardar/arremessar/saída limpa oferta. Convite eleitoral é transitório e rolável; recusar recolhe, C/escudo/tabuleiro permite reconsiderar. Não altera regra de eleição/RNG.

G17: aquisição usa clique/RT/toque mantido, contorno local e dicas inferiores apenas durante posse confirmada. R/Y apoia consulta, entrega confirmada também mantém a folha até ação deliberada. Aquisição sem resposta libera nova tentativa após dois segundos e conserva cancelamento para ack tardio; nova oferta/serial distingue entrega de aquisição. Overlay preserva soltura ainda não enviada. Não há botão de pegar nem carga no clique. `soltar`, quando presente, exige booleano: true produz largada com impulso inicial zero; false/ausente mantém arremesso limitado. Apenas arremessos de papel aguardam 0,65 s; largadas continuam sujeitas a contexto/posse/limites globais/18 descritores. Dados mantêm RNG e valores privados até concluir pouso/alinhamento; cópia local não altera CFrame/Size da peça replicada. DadoVisual compartilha faces/aparência entre bandeja e trio físico.

Envelope/tipos/frequência gerais continuam sob o dispatcher MesaService; comandos usam validação específica antes da mutação. ADM passa primeiro por AdminService; `/adm brotos` e `/adm arrumar` não dão acesso administrativo ao mestre comum. `/adm mestre/jogador` recusam a mudança de papel antiga enquanto o lobby governa a sala, propagando a recusa para a interface.

Arremessos são descritores cosméticos: `{objeto,id,autor,inicio,origem,velocidade,tempoVoo}`. PapelSolto calcula voo/pouso estáveis, limitado à sala; até 18 simultâneos, 45 s de duração. Cliente não envia origem, dano, resultado de dado, personagem reservado nem posição final. Livros são cópias recreativas; fontes da estante/caderno permanecem disponíveis. Não colidem com avatares, causam dano ou alteram recursos.

PreparacaoSala projeta o checklist e fornece o mesmo critério usado por SalaRegras.podeIniciar. Ao aceitar início, limpa mãos/ofertas e publica dados/transição de 2,4 s. Antes de entrar no modo existente, revalida versão, mestre, presença e grupo; mudança cancela a transição. Cliente sobe/aproxima na própria mesa, escurece antes da troca de cenário e revela a arena em 0,7 s. Gestos e corpo são apresentação local em cada cliente, derivados de mãos/olhar; R6/R15 e partes incompletas têm limpeza/reconstrução. SalaLeitura mantém a leitura do papel próxima dos olhos e dentro da tela, sem mover nenhum objeto autoritativo.

Brotos recreativo usa serial próprio e empate com vencedores compartilhados; nunca elege mestre. Eleição usa evento/rodadas próprios e repetição dos empatados. Placar identifica qual ocorreu. As duas modalidades usam Brotos para comparar os três d6; não alteram o motor de combate.

### Extensão G15: física e mãos (11/10/2026)

`maos[id]` também admite `dados-brotos` e `jogador:<UserId>`. Esses valores comandam gesto, não criam papel remoto falso. `SalaDadosFisicos/Dados_<UserId>` contém três dados replicados, atributos `Dono`, `EmMaos`, `Pousou`; `Valor` só aparece depois do quique. Seis faces são coerentes, pares opostos somam sete. O servidor é proprietário da física após desancorar; restrições impedem colisão com avatares atuais/tardios. Peças ficam até 20 s nas mãos ou 12 s no lançamento, com recuperação de limite espacial e assentamento após 2,4 s seguido de alinhamento suave de 0,22 s. Aparência própria usa cópia visual local suavizada conforme câmera/FOV/aspecto enquanto em mãos; o original permanece governado pelo servidor e é reapresentado ao lançar; isso não modifica origem/RNG/colisão do servidor.

Um lançamento de Brotos/eleição valida pendência antes de consumir RNG; valores ficam privados até o pouso. Enquanto houver confirmação pendente, atalhos não repetem a mesma rolagem e o prazo não completa outros dados antecipadamente. Recolhimento explícito ou limpeza confirma o lançamento aceito uma vez. Saída remove o participante e adia conclusão enquanto outro dado aceito ainda cai. Rodadas fora desse contexto são recreativas. O início continua bloqueado pela rodada em andamento.

O avatar carregado tem raiz temporariamente ancorada, colisões desativadas e movimento do Humanoid suspenso; estado anterior e conexão de partes tardias são restaurados na soltura. Atualização limita deslocamento ao lobby, verifica parede e termina em 4 s, morte/respawn/saída/início/arrumação. `CarregadoPor` na raiz identifica o estado replicado e permite salto/Q/B/botão contextual de toque; não há dano, impulso de arremesso, Ações ou agarrão de combate envolvidos.

Referências técnicas consultadas: [propriedade de rede](https://create.roblox.com/docs/physics/network-ownership) e [impulsos em assemblies](https://create.roblox.com/docs/physics/assemblies). Catálogo gratuito de dados consultado no Creator Store; solução final nativa, sem importar scripts/dependências externas nem adquirir recursos pagos.

## Ficha completa integrada — T28, 09/10/2026

Fluxo verificado no Studio: aba **Mestre** → colar código v2 → **Importar na casa selecionada** → conferir a proposta → **Aprovar**. Para consultar: selecionar a ficha no tabuleiro → aba **Ficha** → **Abrir ficha completa**. Seções recolhíveis mostram atributos, defesa/recursos, perícias, habilidades/talentos, maestrias, magias combinadas e inventário. **Voltar aos controles** retorna aos ajustes da mesa. Referências de rank não são apresentadas como compras adquiridas. A consulta não executa habilidades ou combate.

### Contrato em uso (distinto da proposta inicial F1)

- Envelope atual do exportador: `mesa: 2`, `envelopeVersion: 2`, `exporterVersion: "ficha-v2/1"`, `compatibility: "master-approved-snapshot"`, construção, valores calculados e sessão. Os valores são declarações aprovadas pelo mestre; não validam progressão para o futuro RPG. Não há certificação por hash de cálculos neste envelope. IDs ausentes do catálogo geram aviso e construção incompleta.
- Transporte do mestre: `fichaImportBegin {byteCount, partCount, targetId?, sessionPolicy?, ownerUserId?, hidden?, x?, z?, requestId?}`, `fichaImportPart {uploadId,index,text}`, `fichaImportCommit {uploadId}`, `fichaImportAbort {uploadId}`. Até 65.536 bytes, partes de 4.096 bytes, até 32 partes e prazo de 60 segundos. Confirmações chegam no evento `fichaUpload`; recusas no log privado.
- Commit cria proposta, sem aplicar à mesa. `snapshot.fichaPropostas` é exclusivo do mestre. `fichaImportApply {proposalId,version}` aplica após revalidar; `fichaImportReject {proposalId}` recusa. Propostas expiram em 600 segundos. Trocar a mesa ou alterar a ficha alvo invalida a aprovação antiga. Textos e notas são filtrados antes de derivar as condições aplicadas.
- Atualização padrão `sessionPolicy: "preserve"`: mantém PV/PM/condições da mesa, PT/PP (limitados aos novos máximos) e descansos; `replace` usa a sessão importada. Construção/valores calculados são atualizados nos dois casos.
- `fichaDetalhe {id}` exige permissão para ver os atributos da ficha. Resposta: `{id,version,ficha2}`. PV/PM/máximos/nome/condições refletem o token atual; notas de condição somente para mestre ou dono autorizado. O corpo é uma cópia, não uma autorização de ação.
- `token.ficha2Versao` e `fichaDetalhe.version` são identificadores opacos `geração:versão`. O cliente compara igualdade, descarta respostas antigas e apaga cache quando perde acesso ou muda de papel. Outra campanha com o mesmo id e versão local exige novo detalhe. O snapshot não carrega a ficha completa.

Verificado: importação e navegação por teclado/mouse MCP, atualização de PV e regressões de filtro, sessão e privacidade. T29 verificou o ciclo de DataStore real com ficha v2, inclusive recuperação em novo servidor Play e invalidação do detalhe com mesmo id/versão local. Pendências: dois clientes reais, reconexão em servidor publicado, filtro TextService fora do Studio e celular real. O catálogo/cálculo fixado por campanha da proposta F1 ainda precisa de decisão/migração explícita; esta entrega não certifica o motor de regras nem a fase de combate.

Teste isolado de persistência: `python tools/playtest/campanha_v2.py`, com Studio em Edit. O roteiro sincroniza somente MesaPersistence e configura Folder `ServerStorage.MesaTestConfig` com atributo `Scope` aleatório (`test_` + 32 hexadecimais). MesaPersistence só reconhece essa configuração no Studio; configuração inválida bloqueia acesso, sem fallback ao scope padrão. O roteiro exige scope vazio, usa ficha fictícia, remove o registro e a configuração ao terminar. Não criar essa Folder no jogo publicado. Resultados e limites em TESTES.md.

Objetivo atual do projeto: usar o Roblox como mesa para o autor mestrar campanhas de Moshoku. O servidor guarda o estado da mesa e rola os dados; o mestre decide as regras. Não há combate automático neste modo.

## O que existe (atualizado em 08/10/2026, M1–M6)

Entregue e verificado por testes automáticos e playtests no Studio via MCP (`docs/TESTES.md`):

- **M1:** tabuleiro 20×20 (casa de 5 studs); fichas de jogador e NPC com nome, PV, mana, cor, dono, oculta e "mostrar atributos"; rolador com os cinco modos do livro, público ou secreto; iniciativa; registro respeitando o que cada um pode ver.
- **M2:** campanhas salvas em 5 espaços, com salvamento automático e ao fechar o servidor, e proteção contra conflito.
- **M3:** importação de fichas do site (botão "Copiar para a mesa Roblox" ou `tools/ficha-para-mesa.ps1`) e iniciativa automática.
- **M4/M5:** mapa (parede, terreno difícil, água), névoa de guerra e condições do livro com acúmulos e lembretes de turno.
- **M6:** salão de taverna, miniaturas animadas, dados 3D, letreiro de turno e painel com abas (`docs/VISUAL.md`).

- **Avatar é a ficha:** a primeira ficha de jogador de cada jogador presente usa o próprio avatar do Roblox; o servidor ancora o avatar na casa e o faz andar até a casa nova (`src/server/AvatarFichas.luau`). O snapshot marca `token.avatar = true` e lista `avatares` (donos vinculados). O cliente esconde avatares cujas fichas não pode ver (oculta ou na névoa); como personagens replicam para todos, isso é **só visual**, por isso NPCs nunca viram avatar. Enquanto vinculado, o jogador anda pelo tabuleiro clicando na casa, não com WASD.

Pendente: celular real, sensação das animações (olho humano) e o que estiver em `docs/PLANO.md` (ficha v2, ações com habilidades, motor de regras, jogo).

## Papéis

`src/server/MesaRoles.luau`. É mestre quem: está na lista `MESTRES` (UserIds); é dono do servidor privado; é o criador do jogo (conta de usuário). No Studio, o primeiro jogador presente vira mestre, para que testes com vários clientes locais tenham um mestre e jogadores. Pode haver mais de um mestre fora do Studio.

## Visibilidade

| Dado | Mestre | Dono da ficha | Outros jogadores |
| --- | --- | --- | --- |
| Ficha oculta | vê (semitransparente) | não vê | não vê |
| PV/mana com `showStats=false` | vê | vê | não recebe (campos `nil`) |
| Campos `hidden`, `showStats` | recebe | não recebe | não recebe |
| Rolagem secreta | vê | vê se for quem rolou | não vê |
| Vez de ficha oculta | nome | — | "vez do mestre" |

Fichas são desenhadas no cliente a partir do snapshot, nunca como Instances replicadas; por isso uma ficha oculta não chega aos jogadores de nenhuma forma.

## Rede

Um `RemoteEvent` `ReplicatedStorage.Mesa` (nome em `MesaProtocol.REMOTE`).

### Cliente → servidor: `FireServer(comando: string, payload: table?)`

| Comando | Payload | Quem |
| --- | --- | --- |
| `requestSnapshot` | — | todos |
| `roll` | `formula: string`, `mode?: Modo`, `visibility?: "publica" \| "mestre"` | todos |
| `move` | `id, x, z` | mestre; dono (em combate, só na vez da ficha) |
| `adjust` | `id, field: "pv" \| "mana", delta: inteiro ≠ 0` | mestre; dono |
| `createToken` | `name, kind?, pvMax?, manaMax?, ownerUserId?, hidden?, color?, x?, z?` | mestre |
| `updateToken` | `id` + qualquer de `name, kind, pv, pvMax, mana, manaMax, hidden, showStats, ownerUserId, color` | mestre |
| `removeToken` | `id` | mestre |
| `combatStart` | `entries: { {id, initiative} }` | mestre |
| `nextTurn` | `expectedTurn?`, `expectedId?` | mestre; dono da ficha da vez (visível) |
| `combatEnd` | — | mestre |

`Modo` = `normal`, `vantagem`, `desvantagem`, `vantagemAbsoluta`, `desvantagemAbsoluta`. `ownerUserId = 0` significa sem dono. Limites em `MesaProtocol.LIMITS`. Valores fora de tipo/limite são recusados sem aplicar nada; o motivo vai só para quem pediu, como log `erro`. Limite de frequência: 8 pedidos acumuláveis, recarga de 8/s; rolagens com 0,4 s de intervalo. Nomes de ficha passam pelo filtro de texto do Roblox (`TextService`) antes de aparecer para outros.

`nextTurn` com `expectedTurn` diferente de `combat.turn` (ou `expectedId` diferente da ficha da vez) é ignorado: evita que um clique duplo avance duas vezes. O painel deve sempre enviar `expectedTurn = snapshot.combat.turn`.

### Servidor → cliente: `FireClient(jogador, tipo, dados)`

`"snapshot"`, enviado após toda mudança:

```
{
  you = { userId, master: boolean },
  tokens = { { id, name, kind, ownerUserId, x, z, color: Color3,
               pv?, pvMax?, mana?, manaMax?,      -- nil se o jogador não pode ver
               hidden?, showStats? } },           -- só para mestre
  combat = { active, round, turn: number, order: { id }, turnId?: id, masterTurn: boolean },
  players = { { userId, name, master } },
}
```

`"log"`: `{ text: string, tone: "publica" | "secreta" | "sistema" | "erro", time: number }`. O texto já vem pronto; o cliente só exibe.

## Módulos

| Arquivo | Dono atual | Papel |
| --- | --- | --- |
| `src/shared/MesaProtocol.luau` | Claude | Constantes, limites, validação simples e geometria do tabuleiro |
| `src/shared/Dice.luau` | Codex | Interpretar e rolar fórmulas (puro, RNG injetado) |
| `src/server/MesaService.luau` | Claude | Estado, permissões, validação, envio |
| `src/server/MesaRoles.luau` | Claude | Quem é mestre |
| `src/server/MesaWorld.luau` | Claude | Chão, tabuleiro, grade, spawn |
| `src/server/TestRunner.luau` | Claude | Roda `tests/*.spec` no Studio |
| `src/client/MesaState.luau` | Claude | Snapshot, seleção, ouvintes |
| `src/client/BoardView.luau` | Claude | Fichas 3D locais, clique → casa, câmera de mesa |
| `src/client/MesaPanel.luau` | Codex | Interface: rolador, log, ficha selecionada, ferramentas do mestre, iniciativa |

Donos podem mudar por acordo registrado em `docs/TAREFAS.md`.

### `Dice` (contrato)

```
Dice.parse(text: any): (Spec?, string?)        -- erro em português quando inválido
Dice.roll(rng: Random, spec: Spec, mode: Modo?): {
  total: number,
  text: string,          -- pronto para o log, ex.: "1d20+4 (vantagem): [7, 17] → 17 + 4 = 21"
  natural: number?,      -- d20 escolhido, quando a fórmula tem exatamente um d20 e ele é somado
  critical: "sucesso" | "falha" | nil,
}
```

O servidor chama `Dice.parse(payload.formula)` e, se válido, `Dice.roll(rng, spec, mode)`; usa `result.text` no log precedido do nome de quem rolou.

### `MesaPanel` (contrato)

`MesaPanel.start(state)`, onde `state` é o módulo `MesaState`. Usa apenas: `send`, `snapshot`, `isMaster`, `localUserId`, `findToken`, `canControl`, `selectedToken`, `selectedCell`, `selectToken`, `tableView`, `setTableView`, `onSnapshot`, `onLog`, `onSelection`, `onTableView`. Não cria RemoteEvents, não desenha no tabuleiro 3D e não decide regras.

## Adaptações e pendências de regra

- Distância em casas com diagonal valendo 1; 1 casa = 1,5 m (`METERS_PER_CELL`). Provisório: o livro mede em metros e o tamanho da casa não foi confirmado. Movimento não é limitado; o log informa a distância para o mestre julgar.
- PV e mana são números livres que o mestre define; não são calculados a partir da ficha do livro.
- Modos de rolagem (vantagem etc.) valem quando a fórmula tem um único d20 somado, mesmo com outros dados (`1d20+1d6+4`). Com dois ou mais d20, ou d20 subtraído, o modo é ignorado e o texto avisa. Crítico/falha só no d20 somado.
- A iniciativa é informada pelo mestre (os jogadores rolam e dizem). Rolagem automática exige ficha com bônus, etapa futura.

## Campanhas salvas (etapa M2)

Objetivo: a mesa sobrevive ao fechamento do servidor e o mestre retoma a campanha na próxima sessão.

### Funcionamento

- Cinco espaços (`slot` 1–5) no DataStore `MesaCampanhas`, chave `slot_<n>`, compartilhados por todos os mestres do jogo.
- O mestre salva ou carrega um espaço; a partir daí, esse é o espaço atual. Salvamento automático a cada 60 s quando houve mudança, e ao fechar o servidor (`BindToClose`).
- Base: o espaço que esta sessão carregou ou salvou por último (`baseSlot` + `revision`) é o único que pode ser gravado sem `force`. Salvar em outro espaço só funciona se ele estiver vazio.
- Conflito: cada gravação aumenta `revision`. Se o espaço foi gravado por outro servidor, ou contém registro ilegível, o status vira `conflito` e o salvamento automático para. O mestre decide: carregar de novo ou "Salvar mesmo assim" (`force = true`). Falha temporária do serviço (`indisponivel`) não para o salvamento automático.
- Durante o carregamento e o fechamento do servidor, comandos que mudam a mesa são recusados. Salvar e carregar manuais têm intervalo mínimo de 5 s.
- O número do espaço não é sigiloso; aparece no registro público quando o mestre carrega. `snapshot.campaign` vai só ao mestre por ser interface de administração.
- DataStore indisponível (place não publicado, Studio sem acesso às APIs, falha do serviço): a mesa continua funcionando sem salvar; o mestre vê o estado `indisponivel`. Para testar no Studio, o Pedro precisa publicar o place e ativar "Enable Studio Access to API Services" (Configurações do jogo → Segurança). Publicar é decisão dele.
- Nomes são filtrados de novo ao carregar, em nome do mestre que carregou.

### Registro gravado

```
{ revision: inteiro >= 1, savedAt: inteiro (os.time), opId: string, mesa = MesaSave.encode(estado) }   -- versão do esquema fica dentro de mesa
```

### Comandos novos (só mestre)

| Comando | Payload | Efeito |
| --- | --- | --- |
| `campaignSave` | `slot?: 1–5`, `force?: boolean` | Salva no espaço informado ou no atual |
| `campaignLoad` | `slot: 1–5` | Substitui a mesa pelo conteúdo salvo; espaço vazio carrega mesa limpa |
| `tableClear` | — | Remove todas as fichas e encerra o combate; não apaga nada salvo |

Snapshot ganha, só para mestre: `campaign = { slot?, revision?, savedAt?, dirty: boolean, status: "livre" | "ok" | "salvando" | "carregando" | "conflito" | "indisponivel" }`. `livre` = nenhum espaço escolhido.

### `MesaSave` (contrato, puro)

```
MesaSave.SCHEMA = 1
MesaSave.encode(state: State): { [string]: any }   -- só tipos aceitos pelo DataStore: sem Color3/Vector3/Instance
MesaSave.decode(data: any): (State?, { string })   -- nil + motivo se a estrutura é inutilizável; senão estado + avisos
State = {
  nextId: number,
  tokens: { Token },                                -- ordem preservada
  combat: { active, round, order: { id }, turnIndex, turn },
}
Token = { id, name, kind, ownerUserId, x, z, pv, pvMax, mana, manaMax, hidden, showStats, color: Color3, version }
```

`decode` valida tudo com `MesaProtocol`: ficha inválida ou id repetido são descartados com aviso; duas fichas na mesma casa são aceitas (um jogador pode parar sobre ficha oculta, ver `move`); nome é limitado em caracteres (`utf8.len`), não em bytes; `version` começa em 0; mais de `LIMITS.tokens` fichas é truncado com aviso; `nextId` passa a ser ao menos o maior número usado em ids `t<n>`; combate com ids ausentes ou índice fora da lista é encerrado com aviso; `schema` maior que o conhecido é recusado ("salvo por versão mais nova"). `encode(decode(encode(x)))` deve ser igual a `encode(x)`.

## Importar fichas do site (etapa M3)

Objetivo: trazer para a mesa os valores calculados da ficha do site original (PV, mana, atributos, CA, deslocamento, iniciativa) sem duplicar as regras no Roblox.

### Fluxo

1. O jogador exporta a ficha no site (arquivo `.mtficha`/`.json` ou link `/ficha/importar#…`).
2. Na ficha do site: **Exportar, compartilhar e imagens → Copiar para a mesa Roblox**. O botão copia em uma linha o JSON completo `mesa:2` (`ficha-v2/1`); o painel divide o texto para transporte. A ferramenta `tools/ficha-para-mesa.ps1 <arquivo ou link>` usa o mesmo adaptador do site e também imprime esse envelope, sem modificar o site.
3. No painel, o mestre cola o envelope. O servidor cria uma proposta; só depois da aprovação explícita do mestre a ficha é aplicada na casa selecionada ou atualiza a ficha selecionada.

Regras não são recalculadas no Roblox. Ficha alterada no site exige gerar o código de novo.

### Envelope atual (versão 2)

O exportador do site entrega `mesa: 2`, `envelopeVersion: 2`, `exporterVersion: "ficha-v2/1"` e `compatibility: "master-approved-snapshot"`, com construção, valores calculados e sessão. O JSON copiado é o envelope inteiro, sem prefixo nem codificação adicional; `MesaState` o divide em partes de transporte. Avisos e omissões permanecem no envelope. Esses valores são uma declaração para revisão do mestre, não prova de cálculo legítimo nem aprovação automática. Contratos de proposta, aprovação e atualização ficam descritos acima.

### Formato legado de código de mesa (versão 1)

Mantido abaixo como referência para campanhas/clientes antigos. O botão atual e a ferramenta de exportação não emitem mais esse formato.

JSON em uma linha, até 1000 caracteres:

```
{"mesa":1,"nome":"Aria","pv":30,"pvMax":34,"mana":12,"manaMax":16,
 "atributos":{"forca":1,"agilidade":3,"vigor":2,"intelecto":0,"espirito":4},
 "ca":13,"deslocamento":9,"iniciativa":3,"vantagemIniciativa":false}
```

Limites: `nome` 1–32 caracteres (filtrado no servidor); `pv`, `pvMax`, `mana`, `manaMax` inteiros 0–9999 com atual ≤ máximo (atual acima do máximo é reduzido, com aviso); atributos inteiros −20 a 50; `ca` 0–99; `deslocamento` 0–999 (metros; pode ser decimal com até 1 casa); `iniciativa` −50 a 50; `vantagemIniciativa` booleano. `mesa` diferente de 1 é recusado.

### Ficha com dados importados

Token ganha `sheet?` (recebido só por quem pode ver os atributos, mesma regra de PV/mana):

```
sheet = { forca, agilidade, vigor, intelecto, espirito, ca, deslocamento, iniciativa, vantagemIniciativa }
```

### Comandos novos (só mestre)

| Comando | Payload | Efeito |
| --- | --- | --- |
| `importToken` | `code: string`, `id?`, `x?`, `z?`, `ownerUserId?`, `hidden?` | Sem `id`: cria ficha `jogador` com os dados (nome do código). Com `id`: atualiza PV, mana, máximos e `sheet` da ficha existente e renomeia; posição, dono e visibilidade não mudam. |
| `rollInitiative` | `ids: { id }` | Rola d20 + `sheet.iniciativa` (0 sem sheet), com vantagem se `vantagemIniciativa`, para cada ficha; inicia o combate na ordem decrescente. Empate: maior bônus, depois a ordem enviada. Cada rolagem vai ao registro respeitando a visibilidade da ficha. |

### Módulos

| Arquivo | Dono | Papel |
| --- | --- | --- |
| `tools/ficha-para-mesa.mts`, `tools/ficha-para-mesa.ps1` | Claude | Ferramenta Node que gera o código de mesa |
| `src/shared/FichaImport.luau` + `src/server/tests/FichaImport.spec.luau` | Codex | `FichaImport.parse(decoded: any): (Import?, string?, { string })`: valida a tabela já decodificada do JSON e devolve `{ name, pv, pvMax, mana, manaMax, sheet }`, erro, avisos. Puro. |
| `src/server/MesaService.luau` | Claude | `importToken`, `rollInitiative`, `sheet` no snapshot; JSON via `HttpService:JSONDecode` em `pcall` |
| `src/shared/MesaSave.luau` | Codex | Gravar e ler `sheet` opcional, validado com os mesmos limites. Registros sem `sheet` continuam válidos (schema continua 1). |
| `src/client/MesaPanel.luau` | Codex | Campo "Colar código de ficha" com "Importar na casa" e "Atualizar ficha selecionada"; atributos/CA/deslocamento/iniciativa na ficha selecionada quando houver `sheet`; botão "Rolar iniciativa" que usa as fichas marcadas na lista de iniciativa. |

## Condições do livro (etapa M5)

Fonte: `CONDICOES` e `ESTADOS_DE_REGRA` do site (Cap. 4, §2). `src/shared/Condicoes.luau` é **gerado** por `tools/gerar-condicoes.mts`; não edite à mão.

Fiel ao site: **não há duração numérica em rodadas**. O livro escreve a duração em prosa, e o site usa nota livre para não inventar números. A mesa mostra a `duracao` padrão do livro como referência e guarda uma nota por condição.

### Dados gerados (`Condicoes`)

```
Condicoes.LISTA = { { id, nome, efeito, duracao?, acumulavel, teto?, vira?, regra, lembrete? } }  -- ordem do livro
Condicoes.POR_ID = { [id] = entrada }
Condicoes.TETO_PADRAO = número   -- teto de acumuláveis sem teto fixo (Quebrantado): TETO_DE_ACUMULOS do site = 12
```

`regra = true` para os estados de regra (Conjurando, Desprevenido…). `vira` = id em que a condição se transforma ao chegar no teto (Dose 3 → Atordoado). `lembrete` = texto curto do que cobrar no início do turno (ex.: dano por turno), quando o site tem isso como mecânica.

### Na ficha

`token.conditions = { { id, stacks, note? } }`: até 12 condições, `stacks` de 1 ao teto (1 se não acumulável), `note` até 60 caracteres, filtrada no servidor. Quem vê a ficha vê as condições; a `note` só vai ao mestre e ao dono.

### Regras puras (`src/shared/CondicaoRules.luau`)

```
CondicaoRules.add(list, catalog, id, stacks?, note?) -> (newList?, erro?, mensagens: { string })
CondicaoRules.remove(list, catalog, id, stacks?) -> (newList?, erro?, mensagens)
CondicaoRules.labels(list, catalog) -> { string }          -- "Caído", "Dose ×2"
CondicaoRules.validate(raw, catalog) -> (lista, avisos)     -- para MesaSave.decode
```

Sem mutar a lista recebida. `add` de acumulável soma acúmulos até o teto; ao chegar no teto com `vira`, remove a condição e aplica `vira` (mensagem explica). `add` de condição já presente e não acumulável só troca a nota, se houver. `remove` sem `stacks` tira a condição inteira. Id fora do catálogo é erro.

### Comandos (mestre ou dono da ficha)

| Comando | Payload |
| --- | --- |
| `conditionAdd` | `id` (ficha), `condition`, `stacks?` (1–20), `note?` |
| `conditionRemove` | `id`, `condition`, `stacks?` |

Início do turno de uma ficha em combate: o servidor envia ao mestre e ao dono, como `sistema`, os `lembrete` e `duracao` das condições dela.

## Mapa e névoa (etapa M4)

`snapshot.map = { terrain = { ["x,z"] = "parede" | "dificil" | "agua" }, fog = { ["x,z"] = true } }`. Todos recebem o mapa. A névoa esconde o **conteúdo**, não a forma: o jogador vê que a casa está coberta, mas não as fichas nela.

Visibilidade passa a ser: o mestre vê tudo; os outros veem uma ficha se ela não estiver oculta **e** (não estiver na névoa **ou** for do próprio jogador). Atributos, registros e rolagens seguem a mesma regra (`canSee`).

Parede: jogador não move ficha para ela; o mestre pode. Terreno difícil e água são só visuais: o mestre aplica a regra. Criar ficha evita parede ao procurar casa livre.

| Comando (mestre) | Payload |
| --- | --- |
| `paintCells` | `brush`: `parede`/`dificil`/`agua`/`limpar`/`nevoa`/`revelar`; `cells = { {x, z} }` (até 200) |
| `fogAll` | `covered: boolean` (cobre ou revela o tabuleiro inteiro) |

No cliente, `MesaState` ganha o pincel: `brush()`, `setBrush(nome?)`, `onBrush(cb)`. Com pincel ativo, clicar ou arrastar no tabuleiro pinta casas em vez de selecionar fichas.

### Módulos de M4/M5

| Arquivo | Dono |
| --- | --- |
| `tools/gerar-condicoes.mts`, `src/shared/Condicoes.luau` (gerado) | Claude |
| `src/server/MesaService.luau` (comandos, névoa na visibilidade, lembretes), `src/client/BoardView.luau` (condições na ficha, terreno, névoa, pincel), `src/client/MesaState.luau` (pincel) | Claude |
| `src/shared/CondicaoRules.luau` + spec | Codex |
| `src/shared/MesaSave.luau` + spec (`conditions`, `map`; schema continua 1, campos opcionais) | Codex |
| `src/client/MesaPanel.luau` + fixture (condições da ficha selecionada; ferramentas de mapa) | Codex |

## G12 — intenção de área ajustável (10/10/2026)

`usarHabilidade` aceita adicionalmente `inicioX`, `inicioZ`, junto de `x`, `z` (fim), apenas para uma zona declarada `moldavel` pelo servidor; hoje, Muro de Chamas. Ambos os extremos devem ser casas inteiras válidas; início vizinho ao conjurador, linha horizontal/vertical/diagonal de 1–6 casas inclusive início, sem terreno de parede ou quina atravessada. Sem campos de início, mantém o pedido antigo de direção e comprimento padrão. Nenhuma lista de casas recebida do cliente é aceita como resultado autoritativo. A validação antecede Ações/PM. Não há remoto novo.

Áreas no cliente: selecionar a carta apresenta a geometria; clicar fixa centro/direção; muralha usa primeiro clique para início e segundo para fim; Confirmar área envia. Trocar início reinicia só o desenho. Áreas em volta de si mantêm Usar habilidade. Snapshots/recibos filtrados continuam sendo a única origem dos resultados e da informação sobre fichas.
