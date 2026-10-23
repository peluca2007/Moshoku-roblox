# Colaboração entre Claude e Codex

Duas IAs trabalham neste projeto. O autor (Pedro) decide no fim e avalia aspectos subjetivos. As IAs executam testes automáticos e playtests no Studio. Este documento vale igualmente para as duas.

## Divisão do trabalho

- Cada arquivo tem um dono por vez, registrado em `docs/TAREFAS.md`. Não edite arquivo de outro dono; proponha a mudança em `docs/TAREFAS.md` ou `docs/DISCUSSOES.md`.
- Contratos entre módulos (`docs/MESA.md`, `docs/ARQUITETURA.md`) mudam só por acordo registrado. Quem precisar de mudança no contrato abre a discussão antes de codificar contra ela.
- Ao terminar uma tarefa: marque como "pronta para revisão" em `TAREFAS.md`, com o que foi feito, o que não foi verificado e como testar.
- A outra IA revisa antes do playtest. Revisão procura defeitos reais (cenário concreto que falha), não preferência de estilo.

## Canal direto

Para subtarefas deste projeto, Pedro autorizou em 13/10/2026 a distribuição econômica por modelo. O coordenador da conversa usa a política de AGENTS.md: Luna primeiro em trabalho delimitado, Sol para integração complexa, Astra só com justificativa. Até dois subagentes simultâneos, cada um com arquivos reservados, sem recursão automática. Configuração local em `.codex/config.toml` e `.codex/agents/`; escolha explícita no app pode prevalecer. Isso não altera a responsabilidade de revisar nem presume resposta do Claude.

O canal abaixo registra a colaboração anterior com Claude; sua disponibilidade precisa ser confirmada antes de depender dele.

Desde 08/10/2026 o Claude conversa com o Codex sem o Pedro repassar mensagens: chama o Codex CLI desta máquina (`codex exec`, e `codex exec resume` para continuar a mesma conversa) e lê a resposta final. Pedro autorizou.

- O Claude é o orquestrador: distribui tarefas pelo quadro, dispara o Codex em segundo plano e revisa o resultado. Assim os dois trabalham ao mesmo tempo em arquivos diferentes.
- Execuções de revisão rodam com `--sandbox read-only`. Execuções de implementação rodam com `--sandbox workspace-write` e só nos arquivos da tarefa.
- Só uma instância do Codex por tarefa. Se a sessão do app do Codex estiver com uma tarefa "em andamento", o Claude não dispara outra para os mesmos arquivos.
- O Codex responde ao Claude na resposta final da execução e registra decisões em `TAREFAS.md` e `DISCUSSOES.md`, como antes. O histórico precisa ficar nos arquivos, não só na conversa.
- `docs/COORDENACAO.md` e `docs/CODEX-AUTOMACAO.md` foram criados pelo Codex antes deste canal. O quadro oficial continua sendo `TAREFAS.md`.

## Seja crítico

Concordar por educação é falha. Cada IA deve:

- Ler o trabalho da outra procurando erros de lógica, segurança (servidor confiando no cliente), validação ausente, regra do livro mal adaptada e contrato violado.
- Apontar o problema com evidência: arquivo e linha, cenário que quebra, trecho do livro, documentação oficial do Roblox ou teste que falha.
- Não aceitar uma afirmação só porque a outra IA foi confiante. Confiança não é evidência.

## Quando discordar

1. **Registre** em `docs/DISCUSSOES.md`: tema, posição, evidência e o que mudaria de ideia.
2. **A outra parte responde** tentando refutar, também com evidência. Não basta repetir a posição.
3. **Avalie com honestidade.** Se o argumento do outro se sustenta e o seu não, **aceite a derrota por escrito** ("Cedo: …, porque …") e siga a posição vencedora. Perder uma discussão para chegar ao código certo é o resultado esperado, não um problema.
4. **No máximo duas rodadas** de réplica. Sem acordo, resuma as duas posições em poucas linhas e leve ao Pedro, que decide. A decisão fica registrada.
5. Nunca reverta em silêncio o código da outra IA nem contorne a discordância implementando sua versão por cima.

O que conta como evidência, da mais forte para a mais fraca: teste ou execução no Studio; documentação oficial do Roblox ou trecho do livro; cenário concreto passo a passo; argumento de princípio (AGENTS.md, ARQUITETURA.md). Gosto pessoal não conta.

## Formato de registro em DISCUSSOES.md

```
## D-<número>: <tema curto> — aberta | resolvida | com o Pedro
Arquivos: ...
**<IA>:** posição + evidência. Mudo de ideia se: ...
**<IA>:** réplica + evidência.
**Resultado:** quem cedeu e por quê / decisão do Pedro.
```

## Limites que valem sempre

- Não declarar playtest feito sem execução real no Studio pelas IAs; registrar evidência e limites. Pedro avalia sensação, visual e dispositivos físicos quando necessário.
- Não publicar o jogo.
- Não acrescentar framework ou dependência sem necessidade demonstrada.
