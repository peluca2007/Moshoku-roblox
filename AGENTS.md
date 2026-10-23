# Direção do projeto

Projeto Roblox grande, desenvolvido por etapas verificáveis. Leia README.md e docs/ARQUITETURA.md antes de alterar código. O RPG original (site do livro) é a fonte de verdade; não o modifique, exceto na autorização por finalidade descrita abaixo.

Para trabalho compartilhado entre Codex e Claude, leia também docs/COORDENACAO.md e registre tarefa, arquivos em edição e resultado. Não presuma comunicação direta nem aceite de uma divisão ainda não confirmada.

- Scripts de entrada apenas inicializam módulos. Separe servidor, cliente e código compartilhado.
- Orientação contínua do Pedro (10/10/2026): mantenha código e arquivos organizados para facilitar mudanças e adições. Separe responsabilidades em módulos com nomes claros, evite duplicação e atualize `docs/MANUTENCAO.md` quando mudar a localização de um comportamento. Prefira extrações verificáveis a reorganizações amplas durante uma correção.
- Servidor decide combate, dados, recursos e recompensas. Cliente envia intenção e apresenta resultados.
- Todo pedido remoto exige validação de tipo, contexto, recursos, alcance e frequência.
- Regras puras não criam Instances nem enviam eventos. Injete o gerador aleatório.
- Autorização do Pedro (08/10/2026), **por finalidade**, para mudar o site: adaptadores e testes de exportação para o Roblox (como `src/lib/codigoDeMesa.ts` e o botão `BotaoMesaRoblox.tsx`), sem alterar cálculos do livro, dados de regra nem a interface além desses pontos de exportação. Qualquer outra mudança no site precisa de nova autorização. Lá valem as regras do próprio site (AGENTS.md/CLAUDE.md dele): trabalho direto na `main`, um assunto por commit, nunca push sem pedido.
- Plano geral: `docs/PLANO.md` (aprovado). Jogo por turnos.
- Não confunda PA de aprimoramento com pontos de ação. Registre toda adaptação do livro.
- Não acrescente frameworks ou dependências sem necessidade demonstrada.
- Documente contratos, limitações, mudanças de regra e verificações relevantes.
- Nunca declare um playtest concluído sem rodar no Studio. Não publique por conta própria.
- Não deixe Codex e Claude editar o mesmo módulo simultaneamente. Atribua arquivos e revise a integração.
- Código-fonte em src é a referência; arquivos .rbxlx são gerados. Não edite o gerado manualmente.

# Colaboração Claude ↔ Codex

Foco atual (Pedro, 13/10/2026): RPG com exploração de mundo aberto e combate por turnos; começar por uma região pequena. Preservar a possibilidade de mestre futuro no mesmo núcleo, sem exigir mestre como objetivo do jogo. O protótipo antigo (CombatService, BattleController) está pausado.

- Antes de editar, consulte `docs/TAREFAS.md`: só edite arquivos de tarefas em que você é o dono.
- Siga `docs/COLABORACAO.md`. Resumo: seja crítico com o trabalho da outra IA e aponte defeitos com evidência. Ao discordar, registre em `docs/DISCUSSOES.md` e tente refutar com argumentos e provas, não com insistência. Se o outro lado estiver certo, aceite a derrota por escrito e siga a posição correta. Após duas rodadas sem acordo, leve a decisão ao Pedro.
- Ao terminar, atualize o estado da tarefa e diga o que não foi verificado.

# Testes automáticos

O Pedro quer que as IAs testem, não ele.

- Antes de marcar qualquer tarefa como pronta, rode `powershell -File tools/testar.ps1`: compila todo `src`, roda os specs de módulos puros e a simulação do painel. Só vale "pronta" com `RESULTADO: tudo ok`.
- Specs novos vão em `src/server/tests/*.spec.luau`, no formato do `TestRunner`. Módulo puro também roda fora do Studio; módulo que usa serviços do Roblox roda só no Studio.
- Desde 16/10 o Play NÃO roda os specs sozinho (levavam ~3 min). Para rodar no Studio: em Play, `execute_luau` no Server com `local s=game.ServerScriptService.Server; return require(s.TestRunner).run(s.tests)`, ou marque no Edit o atributo `RodarTestesNoPlay=true` em ServerScriptService antes do Play (e tire depois, para não salvar no place).
- Playtest no Studio: o Studio funciona como servidor MCP (`.mcp.json`, servidor `roblox-studio`; no Studio: Assistant → … → Manage MCP Servers → Enable Studio as MCP server). Com ele, a IA inicia e para o teste, executa Luau no servidor ou no cliente, lê o Output e captura a tela. Comandos: `python tools/studio_mcp.py run tools/playtest/roteiro.json` (mesa, campanha), `roteiro_fechamento.json`, `roteiro_m45.json` (visibilidade, condições, mapa, permissões) e `python tools/playtest/ui_cliques.py` (cliques reais no painel); sincronizar src sem Rojo: `python tools/studio_sync.py`. Registre em `docs/TESTES.md` o que foi verificado assim. O Pedro só testa o que exigir julgamento humano (sensação, visual, celular real).

# Documentação e reaproveitamento (Pedro, 13/10/2026)

- Manter a documentação curta, atual e sem repetição: atualizar a seção existente antes de acrescentar registros. Consultar tarefas e evidências para não refazer entregas concluídas.
- README é entrada; ARQUITETURA descreve o presente; MANUTENCAO localiza comportamentos; PLANO guarda direção/fases; TAREFAS registra dono/estado; TESTES guarda evidência. Nos demais, usar links em vez de copiar relatos extensos.
- Arquivar histórico superado com link e data, preservando contratos, decisões, pendências e limitações ainda relevantes. Não transformar intenção ou registro antigo em entrega comprovada. Não reler todo o histórico a cada tarefa.
- Avatar Roblox por enquanto; aparência personalizável no jogo no futuro, separada das regras da ficha.
- Preferir reaproveitamento adequado de modelos gratuitos e código aberto. Registrar procedência/licença/versão; revisar scripts e dependências e validar compatibilidade/desempenho antes de integrar. Não instalar frameworks sem necessidade demonstrada.

# Uso econômico de modelos (Pedro, 13/10/2026)

- Pedro autoriza delegar subtarefas a modelos adequados à dificuldade. Escolha o menor suficiente: `gpt-6-luna` para buscas, documentação, testes e correções pequenas bem delimitadas; `gpt-6.1-sol` para mudanças com várias responsabilidades, integração ou diagnóstico difícil; `gpt-6-astra` só para impasse fundamentado ou raciocínio excepcionalmente complexo. Não escalar por tamanho do arquivo apenas.
- Antes de escalar, registrar a dificuldade concreta e o resultado esperado. Falha de permissão, ferramenta ausente e teste quebrado por ambiente não justificam modelo mais caro. Não repetir a mesma tarefa em vários modelos sem motivo.
- Preferir um subagente por entrega delimitada; no máximo dois simultâneos, com arquivos exclusivos. Informar objetivo, trechos/arquivos necessários, restrições e critério de conclusão; evitar copiar todo o histórico. O coordenador revisa o resultado e integra, sem refazer o trabalho.
- Usar os agentes locais `economico`, `implementador` e `especialista` quando disponíveis. Se a ferramenta só aceitar modelo explícito, aplicar a mesma política; não herdar Astra/Sol automaticamente para tarefas pequenas. Subagentes não delegam recursivamente por padrão.
- Tarefas triviais que já possam ser concluídas com uma ação não precisam de subagente. Configuração de modelo é preferência, não promessa de economia medida; seleção explícita no app pode prevalecer e o modelo de um chat em andamento não muda por editar arquivos.
