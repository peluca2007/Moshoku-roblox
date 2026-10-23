# Experimento: porte manual × roblox-ts (F1)

Data: 08/10/2026. Autor: Claude. Pedido em `docs/PLANO.md` §4D.

## Pergunta

Dá para compilar as regras do site (TypeScript) para Luau com o roblox-ts e reaproveitar o código literalmente, ou é melhor portar à mão com testes diferenciais?

## Método

1. Medir nos módulos de regra do site a dependência de recursos que o roblox-ts não oferece (expressões regulares, APIs de navegador/Node).
2. Copiar o cálculo da ficha (`store/selectors.ts`) com todo o fecho de imports para uma pasta isolada (fora deste projeto e do site), trocando só os caminhos `@/…` por relativos, e compilar com `roblox-ts@3.0.0` (`rbxtsc --type package`).

Reprodução guardada em `tools/experimentos/roblox-ts/`:
- `package.json` e `package-lock.json` com as versões exatas;
- `copiar.mjs`, que copia o fecho de imports;
- `tsconfig.json` e `default.project.json`;
- `fontes.sha256`, com o hash das 34 fontes copiadas;
- `revisao-do-site.txt`;
- `diagnosticos.txt`, com a saída integral do compilador.

Passos, numa pasta vazia fora dos dois projetos: copiar esses arquivos, `npm ci`, `node copiar.mjs "<pasta do site>" store/selectors.ts`, `npx rbxtsc --type package`.

## Resultados

Dependência de expressões regulares (contagem aproximada de usos):

| Módulo | Linhas | Usos de regex |
| --- | --- | --- |
| `store/selectors.ts` | 1432 | 0 |
| `lib/combatSim.ts` | 3261 | 75 (lê a prosa das habilidades) |
| `lib/weaponFormula.ts` | 201 | 10 |
| `lib/encounterSim.ts` | 1754 | 2 |
| `lib/rollEngine.ts`, `lib/dice.ts` | 74, 22 | 1 cada |

Nenhum dos módulos medidos usa API de navegador ou Node.

Compilação do fecho de `selectors.ts`: **34 arquivos, ~12 mil linhas, 105 diagnósticos de compilação**, todos de compatibilidade de dialeto. A lógica e a paridade depois de uma adaptação **não** foram avaliadas:

- `Math` não existe (41): o roblox-ts usa `math` do Luau.
- `.length` de array não existe (~25): o roblox-ts usa `.size()`.
- `string.trim`, `toLowerCase`, `replace`, `localeCompare`; `Array.from`, `flatMap`, `reverse`, `slice`; `Object.entries`, `Boolean` como função: inexistentes ou diferentes.
- Erros concentrados em `selectors.ts` (57), `magiaTeorica.ts` (16), `types.ts` (8).

Tamanho da reescrita para um subconjunto comum aos dois dialetos, só no fecho de `selectors.ts`: 42 usos de `Math.*`, 23 de `.length`, 15 chamadas de métodos de texto ausentes e 2 de `Object.*`, **cerca de 82 pontos**. Os 129 métodos de array (`map`, `filter`…) o roblox-ts implementa. O `combatSim` somaria as 75 expressões regulares.

## Conclusão

O roblox-ts **não** reaproveita o código do site literalmente: compilar exigiria reescrever o TypeScript no dialeto do roblox-ts. Esse dialeto deixaria de rodar no site (`Math` → `math`, `.length` → `.size()`), então seriam duas versões do mesmo código, que é justamente o que se queria evitar, e com um compilador a mais no projeto.

**Decisão (Claude e Codex, depois de duas rodadas; ver `docs/DISCUSSOES.md`):**

O ponto decisivo não é a contagem de erros, e sim o **escopo da autorização**. Para usar o roblox-ts sem manter duas cópias, o código de regras do site teria de ser reescrito num subconjunto comum aos dois dialetos (cerca de 82 pontos só na ficha, mais as 75 expressões regulares do simulador). Isso altera código de regra do livro, e a autorização do Pedro cobre só adaptadores e testes de exportação. O experimento não demonstrou reaproveitamento direto com roblox-ts. Adotar uma versão adaptada manteria outra implementação, e unificar o núcleo exigiria autorização adicional. A escolha do Luau é por escopo e manutenção, não por superioridade técnica demonstrada. Fica então:

1. **Porte manual para Luau** das regras que o servidor precisa executar, guiado por **testes diferenciais**: um script no site roda as funções originais com entradas fixas e grava fixtures; os specs Luau exigem o mesmo resultado.
2. **A leitura de prosa fica no site.** O `combatSim` extrai a mecânica das habilidades com 75 expressões regulares. Em vez de portar esse parser, o site exporta a parte estática como estrutura. `acoesDe(ficha)` depende do contexto da ficha (arma, bônus, escolhas), então a exportação separa **definição estática** (por habilidade e modalidade), **contexto calculado** (por ficha) e **capacidade de execução** (o que o Roblox sabe executar), mantendo as adaptações do simulador classificadas na matriz de fidelidade.
3. Validação em três níveis: **aprovação da construção** pelo mestre na mesa (F2); **validação de execução** em F3 (aquisição da habilidade, recursos e contexto, já necessária para executar ações); **recomputação autoritativa** completa da ficha no RPG (F5). O cálculo da ficha (`selectors.ts`, sem regex) é o primeiro candidato a porte com testes diferenciais.

Mudo de ideia se: o Pedro autorizar reescrever o núcleo de regras do site num subconjunto comum aos dois dialetos. Nesse caso, fazer a comparação completa prevista no plano (rolador, resolução pequena e execução diferencial pelos dois caminhos) antes de escolher. Também se o roblox-ts passar a cobrir a biblioteca padrão do JavaScript.
