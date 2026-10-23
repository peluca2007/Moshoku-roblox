# Contratos F1: catálogo, ficha e execução

Tarefa T20 — Codex. Versão inicial, 08/10/2026.

Referências: `docs/PLANO.md`, `docs/FIDELIDADE.md`, `docs/MESA.md`.

## 1. Status e decisões

Aprovado pelo Pedro:

- Mesa assistida agora; RPG por turnos depois.
- Exploração livre entre combates.
- Dados do site reaproveitados por geração.
- Ações suportadas resolvidas automaticamente; arbitragem do pendente.
- Autorização por finalidade para adaptadores e testes de exportação no site.

Este documento propõe os formatos da F1. Não ativa comandos novos nem altera o contrato de rede existente.

**Propostas a validar por implementação e corpus real:** limites numéricos, limite do envelope, tamanho das partes, prazos e capacidades, normalização dos tipos ainda não fornecidos integralmente, catálogo de ranks e representação de efeitos temporários.

Nenhum limite proposto permite truncar silenciosamente uma ficha ou mudar uma regra do livro. Se o corpus válido exceder um limite, o teste falha e o contrato é revisto.

## 2. Convenções comuns

- Transporte e persistência usam apenas valores JSON: objetos, arrays, strings UTF-8 válidas, números finitos e booleanos.
- Campos opcionais ausentes são omitidos. Não emitir `null` nos novos formatos.
- Arrays são densos, sem chaves extras; objetos não usam chaves numéricas.
- Rejeitar campos desconhecidos em envelopes e comandos recebidos.
- Números de contagem, recursos e versões inteiras são inteiros exatos. Não aceitar NaN/infinito, strings numéricas ou coerção automática.
- Strings com texto humano são filtradas no servidor antes de exibição e novamente ao carregar conteúdo salvo.
- IDs não são rótulos humanos, não passam por tradução e não são derivados de posição em array.
- IDs de usuário, permissões e identidade do solicitante vêm do servidor, nunca de um campo confiado do cliente.
- Hashes detectam divergência de conteúdo; não autenticam uma ficha importada.
- Versões de conteúdo, formato de ficha, protocolo e salvamento são distintas.

### 2.1 Identificadores de catálogo

Segmentos usam o identificador estável original quando ele existe. Codificar cada segmento por percent-encoding dos bytes UTF-8: preservar apenas ASCII alfanumérico e `-._~`; escapes `%HH` em maiúsculas.

Não remover acentos, converter maiúsculas ou trocar caracteres para “parecer um slug”: isso pode criar colisões.

IDs propostos:

| Entidade | Formato |
| --- | --- |
| Árvore | `tree/<treeSourceId>` |
| Rank da árvore | `rank/<treeSourceId>/<rankKey>` |
| Habilidade | `ability/<treeSourceId>/<rankKey>/<abilitySourceId>` |
| Talento | `talent/<treeSourceId>/<rankKey>/<talentSourceId>` |
| Maestria | `mastery/<treeSourceId>/<rankKey>` |
| Condição | `condition/<conditionSourceId>` |
| Raça | `race/<raceSourceId>` |
| Antecedente | `background/<backgroundSourceId>` |
| Item definido | `item/<itemSourceId>` |
| Grupo de arma | `weapon-group/<groupSourceId>` |
| Criatura definida | `creature/<creatureSourceId>` |
| Magia combinada | `combined-spell/<sourceId>` |

`rankKey` vem de um registro explícito correspondente ao tipo `RankName` do site. Seus valores precisam ser conferidos na F1; não inferir pela tradução exibida, bônus ou índice. Incluir Rank narrativo se existir no catálogo, sem atribuir-lhe automaticamente a mecânica de outro Rank.

Entidades sem ID na origem recebem um ID num registro explícito de exportação, com referência inequívoca à origem. Não gerar ID a partir de nome mutável ou índice.

Colisão, referência ausente ou origem ambígua interrompe a geração.

### 2.2 Referência de ação

Não concatenar “normal” ou “silenciosa” ao nome exibido.

```json
{
  "originId": "ability/fogo/Principiante/bola-de-fogo",
  "variantKey": "base",
  "mode": "normal"
}
```

- `originId`: habilidade, talento, maestria ou ação básica catalogada.
- `variantKey`: chave de variante explícita, inicialmente `base`.
- `mode`: `normal`, `encurtada`, `silenciosa` ou `reacao`, quando aquela modalidade estiver registrada.
- Uma modalidade só existe se a fonte/adaptador a declarar. Campo ausente não equivale a custo zero.
- Se `actions.silenciosa` for `"reação"`, conservar essa distinção; não transformar em zero Ações sem consumo de Reação.
- `damage.condicional` e `damage.porTurno` são parcelas/condições, não variantes por si sós.
- Arma equipada, alvo e bônus contextual pertencem ao contexto da execução, não geram novos IDs de habilidade.

Se for necessário um ID composto para indexação:

`action/<originId codificado como um único segmento>/<variantKey>/<mode>`.

O objeto `ActionRef` continua sendo o formato de rede para evitar análise ambígua da string composta.

## 3. Catálogo gerado

### 3.1 Estrutura lógica

```text
Catalog {
  formatVersion: 1,
  contentVersion: "sha256:<hex>",
  manifest: SourceManifest,
  trees: TreeEntry[],
  races: RaceEntry[],
  backgrounds: BackgroundEntry[],
  conditions: ConditionEntry[],
  items: ItemEntry[],
  weaponGroups: WeaponGroupEntry[],
  creatures: CreatureEntry[],
  combinedSpells: CombinedSpellEntry[],
  basicActions: BasicActionEntry[]
}
```

Cada entrada possui:

```text
{
  id: CatalogId,
  sourceId?: string,
  sourceRef: { path, symbol, selector },
  data: conteúdo normalizado correspondente à definição do site
}
```

`sourceRef.selector` é um caminho determinístico por IDs e Rank, não número de linha ou índice mutável.

O catálogo preserva:

- Conteúdo de árvores e ranks, incluindo maestrias e talentos.
- Custos PA/PM/PT/PP, modalidades, pré-requisitos e escolhas.
- Prosa de alcance, efeito, ritual e encantamento.
- Fórmulas e parcelas separadas.
- Categoria, proficiências, perícias concedidas e alternativas de escolha.
- Conteúdo consultivo não automatizado.

`Acao[]` derivada do simulador não substitui esse catálogo.

Os tipos completos de `PrerequisiteIds`, `PrerequisiteRank`, `ReserveGrant`, itens e criaturas devem ser lidos antes de definir sua normalização. A F1 não pode inventar semântica de AND/OR ou descartar campos desconhecidos desses tipos.

A presença de custo/fórmula no catálogo não habilita execução automática. A habilitação pertence ao registro de executores e à matriz de fidelidade, com fonte e cobertura próprias.

### 3.2 Manifesto

```text
SourceManifest {
  exporterVersion: string,
  exporterDigest: "sha256:<hex>",
  sourceRevision?: string,
  sourceDirty: boolean,
  files: { path: relativePath, sha256: hex }[],
  dependencies: relativePath[],
  counts: { entityKind: integer }
}
```

Regras:

- Paths são relativos à raiz do site; nunca incluir caminhos pessoais absolutos.
- Incluir fontes e dependências transitivas que contribuíram para a exportação.
- Revisão Git é diagnóstico, não substitui hashes quando houver alterações locais.
- Não incluir horário de geração no conteúdo comparado.
- Registrar separadamente as dependências de cálculo da ficha; elas podem mudar sem alterar o catálogo textual.

### 3.3 Versão e representação canônica

`contentVersion` é SHA-256 da projeção canônica dos dados do catálogo, excluindo o próprio hash e o manifesto.

Canonicalização feita pela ferramenta de build:

- Chaves de objetos em ordem lexicográfica de bytes UTF-8.
- Arrays preservam a ordem relevante da fonte.
- Sem espaços supérfluos.
- Strings preservam o conteúdo Unicode, sem normalização silenciosa.
- Números finitos com representação determinística definida pelo exportador.
- Campos opcionais ausentes não viram `null`.

O servidor compara versões opacas conhecidas; F1 não exige implementar SHA-256 em Luau.

Alteração de texto ou dado exportado muda `contentVersion`. Alteração apenas de comentário pode mudar o manifesto sem mudar a versão de conteúdo.

### 3.4 Artefatos Luau e comparação

Destino: `src/shared/Livro/`, dividido por domínio ou árvore. Não exigir um arquivo gigante.

- Arquivos gerados carregam cabeçalho “GERADO; não edite”.
- Índices por ID e listas são produzidos a partir da mesma representação.
- Metadados privados de campanha/personagem nunca entram no catálogo compartilhado.
- `Condicoes.luau` existente permanece compatível até uma migração explícita.

Verificação:

1. Gerar em diretório temporário isolado.
2. Comparar todos os arquivos esperados, incluindo manifesto.
3. Detectar arquivo faltante, excedente ou modificado.
4. Falhar com diferença compreensível.
5. Não sobrescrever silenciosamente os arquivos para esconder a diferença.

Contagens são diagnóstico. “Mesmo número de habilidades” não comprova igualdade.

## 4. Envelope da ficha v2

### 4.1 Cabeçalho

```text
FichaV2 {
  mesa: 2,
  envelopeVersion: 1,
  catalog: { formatVersion: 1, contentVersion: string },
  calculationsVersion: "sha256:<hex>",
  sourceCharacterId: string,
  name: string,
  construction: Construction,
  calculated: Calculated,
  session: ImportedSession
}
```

- `mesa: 2` distingue o novo envelope do código v1.
- `envelopeVersion` versiona a estrutura dentro dessa família.
- `calculationsVersion` identifica o adaptador e as fontes transitivas dos cálculos usados.
- `sourceCharacterId` permite reconhecer a origem, mas não prova propriedade nem substitui o ID Roblox.
- A campanha fixa as versões de catálogo/cálculo aceitas.
- Versão desconhecida exige migração explícita ou recusa.
- V1 continua aceito pelo caminho atual, sem fingir que contém uma construção completa.

### 4.2 Construção

Campos propostos, correspondentes aos dados fornecidos:

```text
Construction {
  raceId?,
  raceChosen: boolean,
  backgroundId?,
  backgroundChosen: boolean,
  subtableEntryId?,
  attributeBase: { forca, agilidade, vigor, intelecto, espirito },
  raceAttributeChoices: AttributeKey[],
  racialUpgradeIds: CatalogId[],
  saveAdvantages: AttributeKey[],
  startingTreeId?,
  unlockedRankIds: CatalogId[],
  purchasedIds: CatalogId[],
  combinedSpellIds: CatalogId[],
  skillIds: string[],
  treeSkillChoiceIds: string[],
  proficiencyIds: string[],
  weaponGroupIds: CatalogId[],
  bonusHp: integer,
  bonusMp: integer,
  gold: integer,
  inventory: InventoryEntry[],
  overrides: AllowedOverrides,
  legacyBarreira?: NormalizedLegacyBarreira
}
```

Pontos obrigatórios:

- `purchasedIds` conserva habilidade versus talento por seu namespace.
- Maestrias derivadas de Rank não são automaticamente compras adicionais.
- Escolha ausente e seleção explicitamente vazia são distintas quando a fonte fizer essa distinção.
- IDs de perícia, proficiência, aprimoramento racial e subentrada exigem registro conferido; não trocar por rótulos arbitrários.
- `legacyBarreira` não pode ser descartada silenciosamente. Migrar usando comportamento do site ou recusar a ficha com explicação.
- Bônus, overrides, ouro e inventário são declarações não confiáveis da importação. Na mesa, são exibidos para aprovação; no RPG, precisam de origem legítima.
- PA gasto é derivado por seletor. PA disponível/concedido não foi definido nos trechos e não pode ser inferido do gasto.

`InventoryEntry` precisa preservar os campos que afetam os seletores: definição do item, quantidade, equipamento e modificações suportadas. O tipo `InventoryItem` integral não foi fornecido; sua normalização é bloqueio explícito da F1.

Itens únicos recebem ID de instância no servidor. ID da definição não identifica uma espada individual.

`AllowedOverrides` deve mapear apenas os campos de `CharacterData.overrides` fornecidos, com limites e aprovação explícitos. Sem objeto extensível de overrides arbitrários.

### 4.3 Valores calculados

```text
Calculated {
  attributes: { forca, agilidade, vigor, intelecto, espirito },
  maxima: { pv, pm, pt, pp },
  armorClass: integer,
  movementMeters: number,
  initiative: { bonus: integer, advantage: boolean },
  highestRankBonus: integer,
  skills: { skillId, bonus: integer, trained: boolean }[],
  actionContexts: ActionContext[],
  paSpent: integer
}
```

```text
ActionContext {
  action: ActionRef,
  contextKey: string,
  weaponDefinitionId?,
  attackBonus?: integer,
  spellDC?: integer,
  combatBonus?: integer,
  damageFormula?: string
}
```

- Cada valor tem seletor/contexto de origem documentado no adaptador.
- Para PV da mesa, conferir `getPvNaMesa`/`hpAtualNaMesa`; não substituir automaticamente por `getMaxHp`/`getCurrentHp`.
- Não usar um BC da árvore inicial para todas as técnicas.
- `ActionContext` é consulta calculada, não autorização de aquisição ou execução.
- Custos, restrições e efeitos vêm da fonte versionada e do executor, não são confiados porque vieram no envelope.
- A mesma ficha pode ter diferentes contextos de arma/modalidade.
- Não limitar esse bloco a `acoesDe`: perícias, passivas, talentos e rituais precisam continuar consultáveis.

### 4.4 Sessão importada

```text
ImportedSession {
  current: { pv, pm, pt, pp },
  conditions: { conditionId, stacks, note? }[],
  shortRests?: integer,
  tableState?: {
    exhaustion: integer,
    deathMarks: integer,
    stabilized: boolean,
    responsibleRankBonus: integer,
    salvationsUsed: integer,
    trauma: integer,
    scars: integer[],
    uses: { useKey: string, count: integer }[]
  },
  manualEffects: { effectId: CatalogId, stacks: integer, note? }[]
}
```

- `CharacterData.mesa.responsavel` precisa ter sua semântica conferida antes de mapear para `responsibleRankBonus`. Não tratar número como ID de personagem por suposição.
- Contadores de uso precisam de namespace e período de reset conhecidos.
- Condições importadas são validadas com o catálogo e suas regras.
- `manualEffects` representa anotações aprovadas, não efeitos executáveis arbitrários.
- Cântico em andamento, fila de reações, temporizadores, autor oculto e entidades invocadas não são reconstruídos a partir de uma anotação.
- Efeitos mecânicos futuros precisam de estado completo: definição, origem, alvo, aplicação e término. Seu formato será definido por executor.
- Valores atuais acima do máximo podem ser reduzidos com aviso visível antes da aprovação; valor negativo, tipo inválido ou dado ilegível é erro.

### 4.5 Política de atualização

Criar ficha:

- Aplicar construção, calculados e sessão aprovados.
- Gerar identidade Roblox.
- Definir posição, dono e visibilidade pelo comando do mestre, fora do envelope.

Atualizar ficha:

- Preservar posição, dono e visibilidade.
- Padrão: preservar sessão atual; ajustar recursos aos novos máximos quando necessário, com aviso.
- Substituir sessão somente com opção explícita na proposta e aprovação.
- Não apagar condições ou recursos atuais só porque o site exportou uma foto antiga.
- Exigir versão esperada da ficha; mudança durante aprovação invalida a proposta.

### 4.6 Limites iniciais propostos

| Campo/estrutura | Limite |
| --- | --- |
| Envelope JSON UTF-8 | 65.536 bytes |
| Profundidade | 12 contêineres, incluindo a raiz |
| Total de valores/contêineres | 16.384 nós |
| Nome | 1–32 pontos de código Unicode |
| ID de catálogo | 1–256 bytes ASCII após codificação |
| ID local de origem | 1–128 bytes UTF-8 |
| Árvores/ranks/compras | 64 árvores, 512 ranks desbloqueados, 1.024 compras |
| Magias combinadas | 256 |
| Perícias/proficiências/escolhas por lista | 256 |
| Inventário | 256 entradas |
| Contextos de ação | 1.024 |
| Condições | 12, conforme mesa atual |
| Nota de condição/efeito manual | 60 pontos de código |
| Efeitos manuais | 32 |
| Contadores de uso | 256 |
| Fórmula calculada | 256 bytes, consultiva; executor usa sua própria validação |
| PV/PM/PT/PP atuais e máximos | inteiros 0–9.999 |
| Atributos calculados | inteiros −20 a 50 |
| CA | inteiro 0–99 |
| Movimento | 0–999 m, até uma casa decimal |
| Iniciativa | inteiro −50 a 50 |
| PA gasto/ouro | inteiros 0–1.000.000.000, a validar contra fonte |

Outros números, incluindo construção, trauma, cicatrizes e contadores, exigem limites específicos conferidos no tipo/fonte. Enquanto não definidos, não aceitar o campo como estrutura numérica irrestrita.

Esses limites são de aplicação. Não são tetos novos do livro. Exportação que os excede deve explicar o problema, não cortar compras ou inventário.

## 5. Transporte v2

### 5.1 Decisão proposta

Usar JSON UTF-8 em uma linha no botão de exportação e enviar o texto em partes pelo cliente Roblox.

Não usar compressão/base64 na primeira implementação:

- Base64 não reduz o conteúdo por si só.
- Compressão exigiria um descompressor compatível e limites de expansão.
- JSON simples aproveita o caminho de validação existente.
- A necessidade de compressão será medida com fichas reais.

O fluxo do usuário continua: copiar no site e colar uma vez no painel. A divisão em partes é interna.

### 5.2 Comandos propostos

Todos usam o RemoteEvent existente `ReplicatedStorage.Mesa`, sem criação de RemoteEvents adicionais.

| Comando | Payload | Resultado |
| --- | --- | --- |
| `fichaImportBegin` | `requestId, byteCount, partCount, targetId?, expectedTokenVersion?, sessionPolicy` | servidor cria `uploadId` e confirma limites |
| `fichaImportPart` | `uploadId, index, text` | confirma `nextIndex` |
| `fichaImportCommit` | `uploadId` | valida envelope e produz proposta de importação |
| `fichaImportAbort` | `uploadId` | libera buffer |
| `fichaImportApply` | `proposalId, expectedProposalVersion` | mestre aprova importação |
| `fichaImportReject` | `proposalId` | cancela proposta |

`sessionPolicy`: `preserve` ou `replace`. Para criação, usar `replace`. Para atualização, padrão `preserve`.

F2 inicialmente mantém esses comandos restritos ao mestre, como a importação atual. Uma futura solicitação de importação pelo dono exige tarefa e política próprias.

### 5.3 Partes e limites

Propostas:

- Parte: 1–4.096 bytes.
- Até 32 partes, total até 65.536 bytes.
- Dividir em fronteiras UTF-8; cada parte deve ser UTF-8 válida.
- Enviar sequencialmente após confirmação.
- Índices densos começando em 1.
- Parte repetida idêntica: confirmar sem anexar novamente.
- Parte repetida diferente ou fora de ordem: erro; não alterar buffer.
- Até duas transferências por jogador e 16 no servidor.
- Memória de texto reservada global: até 1 MiB.
- Expiração absoluta: 60 segundos desde início; partes não renovam indefinidamente.
- Liberar em aborto, expiração, desconexão e conclusão.
- Respeitar orçamento de frequência; partes não contornam o despachante.

O servidor gera `uploadId` e vincula transferência ao solicitante real, geração da mesa e destino. Um jogador não pode usar o upload de outro.

O começo captura geração da mesa e versão do destino. Carregamento, limpeza ou mudança relevante invalida a aplicação, mesmo que a transferência tenha terminado.

### 5.4 Validação

Ordem:

1. Tipo/tamanho do payload remoto.
2. Papel, frequência, upload, prazo e índices.
3. Soma de bytes igual a `byteCount`; quantidade igual a `partCount`.
4. UTF-8 válido.
5. Verificação lexical/estrutural limitada: profundidade, nós e chaves duplicadas.
6. `HttpService:JSONDecode` protegido.
7. Validação completa do schema, números, campos e referências.
8. Compatibilidade de catálogo/cálculos.
9. Filtro de texto.
10. Revalidação após filtros.
11. Proposta para o mestre; sem criar/alterar ficha antes da aprovação.
12. Revalidação e aplicação atômica ao aprovar.

A implementação precisa testar como `JSONDecode` representa arrays vazios e valores opcionais. Não confiar que ele sozinho detecta chaves duplicadas, profundidade excessiva ou legitimidade da ficha.

O verificador estrutural deve ser um scanner limitado de JSON, não uma expressão regular que conte chaves dentro de strings. Essa necessidade faz parte da estimativa da F2.

O cliente não fornece funções, URLs para buscar, IDs de assets a carregar ou código executável.

## 6. Núcleo de execução: identidade e deduplicação

### 6.1 Identidades

- `sessionEpoch`: UUID gerado pelo servidor ao estabelecer a sessão de comandos.
- `sequence`: inteiro crescente por solicitante nessa sessão.
- `requestId`: exatamente `<sessionEpoch>:<sequence>`.
- `encounterId`: identidade gerada pelo servidor; não reutilizar após trocar a mesa.
- `proposalId`, `resolutionId`, `actionId`, `receiptId`: gerados pelo servidor.
- `eventId`: identifica um evento causal dentro da resolução.
- `parentEventId`: liga reação/efeito secundário ao evento que o causou.

Não usar nome da ação, nome do personagem ou timestamp como identidade.

### 6.2 Retenção proposta

Deduplicação por:

`solicitante real + sessionEpoch + requestId`.

- Guardar conteúdo normalizado completo e estado/resultados da requisição.
- Retenção mínima: 300 segundos após estado terminal.
- Até 128 requisições retidas por solicitante; não expulsar entradas ainda protegidas para admitir novas.
- Até oito requisições pendentes por solicitante.
- Capacidade esgotada: recusar novas requisições com erro de capacidade.
- Pendências têm prazo próprio; não podem prender capacidade para sempre.

Sequência é crescente. O cliente normal envia pedidos em ordem; repetição usa sequência e conteúdo originais.

- Mesmo ID e conteúdo: devolver estado já registrado, sem resolver/rolar/cobrar novamente.
- Mesmo ID com conteúdo diferente: erro `REQUEST_ID_CONFLICT`.
- Sequência antiga sem registro retido: erro `REQUEST_EXPIRED`; nunca aplicar novamente.
- Sequência futura aceita avança o marcador da sessão. Pedido posterior que chegue com sequência menor e não tenha registro é recusado.
- Reconexão recebe nova sessão. Não reenviar automaticamente ações antigas como pedidos novos.
- Ações internas de IA seguem mecanismo equivalente por principal controlado pelo servidor.

Reservar a entrada antes de qualquer yield. Resultados de validação de um pedido estruturalmente válido também são registrados, para que repetição não produza comportamento diferente.

Validação de tipo/tamanho e orçamento continua necessária para pedidos malformados ou repetidos.

Isso não promete “exactly once” universal entre servidores. Recompensa/item persistente exige ID de operação armazenado e recuperação idempotente no serviço de persistência, fora da F1.

## 7. Intenção

Formato proposto:

```text
ActionIntent {
  protocolVersion: 1,
  sessionEpoch: string,
  sequence: integer,
  requestId: string,
  encounterId: string,
  expectedGeneration: integer,
  expectedTurn: integer,
  expectedActorVersion: integer,
  actorId: string,
  action: ActionRef,
  targetIds: string[],
  area?: AreaSelection,
  context?: { weaponInstanceId?: string, choiceId?: string }
}
```

`AreaSelection` só aceita formas implementadas pelo serviço de geometria. Formato inicial da grade, a validar:

```text
{ origin: {x, z}, aim?: {x, z} }
```

A forma/tamanho vêm da ação catalogada e executor, não de raio ou alcance livre enviado pelo cliente.

Limites propostos:

- Até 60 alvos, únicos.
- Um ator.
- Um contexto de arma.
- Payload normalizado até 16 KiB e profundidade 8.
- IDs devem existir e ter tipo correto.

O servidor verifica:

- Solicitante controla o ator e pode agir nesse encontro.
- Ator visível conforme política; consultas recusadas não revelam entidades ocultas.
- Ação adquirida ou concedida e modalidade disponível.
- Turno, Ações/Reação, recursos e contadores.
- Arma/contexto válido.
- Condições, requisitos, faixa de PV e estado do alvo.
- Alvos, alcance, área, trajetória e percepção exigidos.
- Catálogo e executor suportados.

A intenção não contém dano final, custo autorizado, condição a aplicar, semente aleatória ou fórmula substituta.

A arbitragem usa campos próprios; não amplia `ActionIntent` com um objeto de efeitos arbitrários.

## 8. Proposta e decisão do mestre

### 8.1 Proposta

```text
ActionProposal {
  protocolVersion: 1,
  proposalId: string,
  proposalVersion: integer,
  requestId: string,
  resolutionId: string,
  encounterId: string,
  actorId: string,
  action: ActionRef,
  targetIds: string[],
  state: "awaitingDecision",
  expiresAt: serverTime,
  catalogVersion: string,
  rulesVersion: string,
  preconditions: ReadSet,
  supportedPlan: ExecutionPlan,
  questions: ArbitrationQuestion[]
}
```

`ReadSet` é interno ao servidor:

- Geração da mesa.
- Versão do encontro/turno.
- Versões do ator e alvos.
- Versão do mapa/geometria relevante.
- Catálogo e regras.
- Estado de recursos, aquisição, equipamentos e contadores consultados.

Primeira implementação pode usar revisão conservadora do encontro inteiro. Isso invalida mais propostas, mas é correto; otimização por dependências exige testes.

`supportedPlan` é criado pelo executor, nunca pelo cliente. Não precisa ser exposto integralmente; o mestre recebe resumo suficiente para aprovar.

Proposta não gasta recursos nem sorteia resultados apenas para fornecer uma prévia.

### 8.2 Perguntas

```text
ArbitrationQuestion {
  questionId: string,
  ruleId: string,
  kind: "choice" | "integer" | "targetSet",
  label: string,
  options?: { id, label }[],
  min?: integer,
  max?: integer,
  eligibleTargetIds?: string[]
}
```

- Até oito perguntas.
- Até oito opções por pergunta.
- Valores e alvos aceitos são definidos pelo servidor.
- Textos vêm de catálogo ou filtro.
- Resultado continua classificado como arbitragem no recibo.

### 8.3 Decisão

```text
MasterDecision {
  protocolVersion: 1,
  sessionEpoch: string,
  sequence: integer,
  requestId: string,
  proposalId: string,
  expectedProposalVersion: integer,
  decision: "approve" | "reject",
  answers?: { questionId, optionId?, integerValue?, targetIds? }[],
  note?: string
}
```

- Verificar papel atual de mestre.
- Rejeição não recebe respostas.
- Aprovação exige exatamente as respostas necessárias, sem duplicadas ou extras.
- Nota: até 240 pontos de código, filtrada; não altera cálculo.
- Dois mestres aprovando a mesma proposta não aplicam duas vezes.
- Decisão tem deduplicação própria e reivindica atomicamente a proposta.
- Proposta vence em 60 segundos, como limite técnico proposto.
- Mudança de estado torna proposta `stale`, com explicação privada adequada; exige nova validação/proposta.
- Filtro da nota pode esperar: depois dele, revalidar papel, presença, proposta, prazo e estado.

Não permitir que “aprovar” signifique executar uma lista de alterações arbitrárias enviada pelo cliente. Ajustes manuais do mestre são comandos administrativos separados e auditados.

## 9. Resolução e atomicidade

Para a fatia automática sem decisão intermediária:

1. Validar.
2. Resolver em estado temporário com RNG do servidor.
3. Validar invariantes.
4. Aplicar recursos, contadores, PV e condições juntos, sem yield.
5. Registrar resultado/deduplicação.
6. Emitir projeções e snapshots.

Erro antes da aplicação não deixa custos ou dano parciais.

Reações e conjuração podem exigir várias etapas. O executor deve declarar:

- Estados da resolução.
- Em que etapa custos são reservados/consumidos.
- Eventos já sorteados e armazenados.
- Perguntas/janelas pendentes.
- Política de interrupção e reembolso segundo a fonte.

Cada etapa aplicada tem ID próprio e recibo. Não prender um lock de encontro durante uma espera humana.

Uma ação aceita uma vez não significa que todas as suas etapas sejam uma única transação. Também não autoriza refazer rolagens ao reabrir uma janela ou recuperar um snapshot.

A ordem de reações simultâneas é contrato pendente de regra. Antes de implementar a reação escolhida da F3, registrar prioridade e gatilho; não adotar “primeiro pacote recebido” silenciosamente.

## 10. Recibo e causalidade

Formato interno proposto:

```text
ActionReceipt {
  protocolVersion: 1,
  receiptId: string,
  resolutionId: string,
  actionId: string,
  requestId: string,
  encounterId: string,
  stepId: string,
  actorId: string,
  action: ActionRef,
  catalogVersion: string,
  rulesVersion: string,
  status: "applied" | "interrupted" | "rejected" | "cancelled",
  classification: { ruleId, kind: "livro" | "adaptacao" | "arbitragem" }[],
  events: ResolutionEvent[],
  resourceChanges: ResourceChange[],
  conditionChanges: ConditionChange[],
  notes: string[]
}
```

`ResolutionEvent`:

```text
{
  eventId,
  parentEventId?,
  kind,
  actorId?,
  targetId?,
  test?: {
    kind: "attack" | "save" | "other",
    formula,
    mode,
    rolls,
    chosenNatural?,
    bonus,
    total,
    difficulty,
    success,
    critical?
  },
  damage?: {
    parts: { sourceId, damageTypeId?, rolls, diceTotal, fixedBonus }[],
    raw,
    afterModifiers,
    afterResistance,
    absorbedTemporary,
    pvLost
  },
  healing?: { rolled, applied },
  effectId?
}
```

- Distinguir resultado do teste de alteração efetiva.
- Não chamar dano absorvido de PV perdido.
- Tipos de dano são IDs estruturados quando conhecidos; prosa legada não vira tipo por adivinhação.
- Evento sem d20 não recebe natural inventado.
- Uma ação em área mantém `actionId` comum e eventos próprios por alvo.
- Reação/efeito secundário aponta para seu evento causador.
- `by`, nomes e texto pronto são derivados para apresentação; não identificam causalidade.
- Não enviar semente ou estado RNG aos clientes.

O evento `roll` atual permanece compatível até migração. O recibo novo permitirá associar apresentação e registro por identidade explícita.

## 11. Audiência por observador

O recibo interno não é enviado integralmente a todos.

Projeções usam permissões atuais e a visibilidade relevante ao momento do evento. Uma ficha visível antes de mover para névoa não deve revelar sua nova posição só porque era visível anteriormente.

Regras:

- Mestre recebe visão autorizada completa.
- Dono recebe dados privados da própria ficha conforme política da mesa.
- Outros recebem apenas fichas, campos e eventos permitidos.
- Notas de condição continuam privadas para mestre/dono.
- Propostas e decisões administrativas não são públicas por padrão.
- Alvos ocultos, suas quantidades, somas de dano e recursos não aparecem em agregados.
- Fonte oculta de uma alteração na ficha própria pode ser omitida: informar a alteração autorizada não exige revelar atacante, habilidade, posição ou trajetória.
- Efeito visual/sonoro recebe somente dados da projeção; não usar coordenadas privadas para depois “esconder” o efeito.
- Não expor sequência global com lacunas que denunciem quantidade de eventos secretos.
- Sequenciamento de entrega é por observador.
- Repetição de requisição reenvia apenas a projeção atualmente autorizada, não um pacote privado antigo.
- Dados já legitimamente vistos não podem ser retirados da memória do jogador; registrar essa limitação.

Snapshots reconstroem efeitos persistentes autorizados. Eventos transitórios são deduplicados no cliente por identidade de apresentação, com retenção limitada; não reproduzir todos ao entrar na sessão.

## 12. Persistência e compatibilidade

- Não mudar `MesaSave.SCHEMA = 1` nesta entrega documental.
- A inclusão da ficha v2 exige tarefa de migração e testes próprios.
- Campanhas guardam versão de catálogo/cálculos e estado suficiente para leitura.
- Catálogo antigo indisponível: recusar carregamento automático ou migrar explicitamente; não reinterpretar IDs silenciosamente.
- Renomear/remover IDs requer mapa de migração; não reutilizar ID para conteúdo diferente.
- Dados de construção autoritativos de personagem são separados das campanhas da mesa.
- IDs de recompensa e operações persistentes precisam sobreviver a reconexão/troca de servidor; a cache de pedidos de 300 segundos não resolve isso.
- F1 define a exigência, não implementa persistência de personagem ou economia.

## 13. Verificação contratual

Testes exigidos nas tarefas de implementação:

- IDs: colisões, mudanças de ordem/nome e referências ausentes.
- Geração: regeneração idêntica e alteração manual detectada.
- Catálogo: talentos, maestrias, rituais, PP e conteúdo fora de `Acao`.
- Envelope: opcionais, escolhas vazias, legados, limites e versões.
- JSON: Unicode, escapes, arrays vazios, chaves duplicadas, profundidade e números inválidos.
- Transporte: repetição idêntica/diferente, ordem, prazo, aborto, capacidade, desconexão e geração trocada.
- Importação: nada aplicado antes da aprovação; atualização preserva sessão por padrão; filtro e revalidação.
- Execução: intenção adulterada, recurso insuficiente, ação não adquirida e alvo inválido.
- Deduplicação: pedido pendente/terminal, conteúdo diferente, cache cheia, sequência vencida e dois mestres.
- Atomicidade: falha não deixa custo/dano parcial.
- Causalidade: área, dois golpes no mesmo alvo, reação e efeito secundário.
- Audiência: névoa, ficha oculta, notas, agregados, posição, efeitos e repetição.
- Fixtures diferenciais: entradas/saídas, versão da fonte e RNG explícito quando necessário.

Antes de marcar implementação pronta, executar `tools/testar.ps1` e os playtests apropriados. Documentação não substitui esses resultados.

## 14. Fora da F1

- Implementar catálogo completo e importação v2: F2.
- Resolver combate completo ou substituir `MesaService` inteiro.
- Definir regras ausentes do livro por conveniência técnica.
- Automatizar todas as condições, descanso, morte ou reações.
- Portar todo `combatSim` sem matriz de fidelidade.
- Escolher Luau versus roblox-ts sem o experimento aprovado.
- Migrar todo o projeto para um compilador/framework novo.
- Implementar economia, recompensas e persistência de personagem.
- Criar animação exclusiva para cada habilidade ou publicar assets.
- Criar serviços web, autenticação externa ou busca de ficha por URL.
- Modificar cálculos/dados de regra do site sob a autorização de exportação.
- Publicar o jogo ou fazer push.

## 15. Pendências explícitas da F1

1. Ler tipos integrais de Rank, pré-requisitos, concessões, inventário, criaturas e legados.
2. Confirmar os registros de IDs e as regras de migração.
3. Conciliar Dose/Colapso/Atordoado e tetos de Quebrantado.
4. Conferir semântica de `mesa.responsavel` e contadores.
5. Executar corpus de fichas reais para validar limites e fidelidade de exportação.
6. Validar transporte/JSON no Studio antes de congelar seu formato.
7. Executar experimento com funções reais e dependências para decidir estratégia de implementação.
8. Registrar resultado e diferenças em `docs/FIDELIDADE.md`, `docs/TESTES.md` e coordenação.

T20 entrega estes contratos para revisão e gravação. O executor local falhou antes de ler arquivos; nenhum código, teste ou playtest novo foi executado nesta entrega.
