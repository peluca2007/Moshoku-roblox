# Verificações de M1, M2 e M3 fora do Studio

**Histórico:** a ferramenta desta pasta cobriu M1–M3. O comando obrigatório atual é `powershell -File tools/testar.ps1`, que compila todo src e inclui CondicaoRules e o salvamento de M4/M5 (66 testes). Não use `run.ps1` como validação da entrega atual. Este registro foi mantido para reproduzir a checagem da época.

Dono de `run.ps1`, `roblox-types.luau` e deste README: Codex (app), tarefa histórica T13-App. O painel e seu simulador permanecem sob a coordenação do Claude/Codex CLI.

Executáveis oficiais Luau 0.741 encontrados nesta máquina em 08/10/2026:

```text
C:\Users\pedro\AppData\Local\Temp\moshoku-luau-0.741
```

Na raiz do projeto, usando PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/codex-tests/run.ps1 -LuauDirectory 'C:\Users\pedro\AppData\Local\Temp\moshoku-luau-0.741'
```

O mesmo comando pode ser chamado pelo Git Bash do Claude. `Bypass` vale somente para esse processo; não altera a política permanente do Windows. Leia `run.ps1` antes de executar. A pasta dos executáveis é temporária e pode ser removida pela limpeza do Windows.

O script compila nove arquivos: quatro módulos compartilhados, seus quatro specs e MesaPanel. Executa os specs originais com imports adaptados em cópias temporárias e testa callbacks do painel com APIs simuladas. Não instala dependências no jogo nem modifica `src` ou o place.

Resultado executado pelo Codex (app) em 08/10/2026:

| Grupo | Passaram | Falhas |
| --- | ---: | ---: |
| Dice | 9 | 0 |
| MesaProtocol | 5 | 0 |
| MesaSave | 18 | 0 |
| FichaImport | 11 | 0 |
| Total dos specs | 43 | 0 |

O simulador do painel também passou, incluindo os comandos de M2/M3. O comando termina com erro se a compilação, qualquer spec ou o simulador falhar.

`roblox-types.luau` fornece somente os construtores de Color3/Vector3, soma/subtração de vetores e igualdade de cores usados pelos specs. São tabelas Luau simuladas, sem a precisão e o comportamento completo dos tipos do motor. Algoritmos e asserções dos specs não são reescritos. As cópias ficam numa pasta única no diretório temporário, disponível para diagnóstico.

Esses resultados não substituem o playtest no Roblox Studio: layout, mouse/toque, filtro de texto, rede, integração entre clientes e operações reais do DataStore ainda dependem do Studio. A execução de MesaSave verifica o codec; não executa MesaPersistence nem prova que uma campanha foi gravada no serviço.
