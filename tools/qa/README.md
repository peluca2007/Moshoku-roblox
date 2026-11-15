# QA no terminal (Studio por MCP)

```
python tools/qa/qa.py <cenário|todos> [--manter-play] [--sem-deps]
```

Pré-requisito: Studio aberto com o place e "Studio como servidor MCP" ligado. O `qa.py` para um Play antigo, sincroniza o
`src` (`tools/studio_sync.py`), roda o cenário (e suas dependências, na ordem) e **para o Play** no fim (`--manter-play` não
para; `--sem-deps` roda só o cenário pedido, no Play que já existe). Nunca salva nem publica o place.

Saída (uma linha por verificação):
`OK   <cenário> · <verificação>` | `FALHA <cenário> · <verificação> — <detalhe> [build/qa/<data>/<captura>.png]`,
até 5 linhas `console>` por cenário (erros/avisos novos) e `RESULTADO: N ok, M falha(s)`. Código de saída 1 se houver falha.
Timeouts do MCP viram `FALHA (timeout)`; exceções do teste viram `FALHA ... erro do teste`.

## Cenários (dependências entre parênteses; `todos` roda nesta ordem, num único Play)
- `inicio`: abertura → criação (prévia 3D com modelo, raça, aparência, nome) → mundo; faixa "Dia 1"; objetivo; sem tela cheia presa.
- `porta_sem_arvore` (inicio): recusa com aviso, dia igual, avatar solto.
- `primeira_arvore`: atalho do Ladino (`tools/playtest/mundo_ladino_atalho.py`: caixas nos guardas, só playtest); objetivo "porta do esgoto".
- `esgoto_sala1`: entra, dia +1, "Sala 1/5", combate em ≤15 s, interface de combate.
- `luta`: disparo e golpe (capturas durante a ação), bot vence, tela de resultado, fase "acampamento", avatar ancorado.
- `acampamento`: Descansar (0,5 dia, 1/2), Levantar acampamento, escolhas, sala 2 com luta.
- `voltar_e_retomar` (acampamento): Voltar à cidade (dias gastos), hub oferece retomar, retomar não repete luta.
- `esgoto_completo` (voltar_e_retomar): luta/acampamento até o chefe; volta à cidade, ouro, opção "selar a anomalia"; selar = fim. Se o bot perder, verifica a derrota.
- `menu`: MENU, RUN (Diário), CONTA, AJUDA abrem e fecham.
- `area_de_testes`: F6, abas e vitrine (ver o arquivo para o que foi coberto).
- `specs`: Play próprio; roda os specs do servidor (~3 min) e lista só as falhas.

## Arquivos
`qa.py` (CLI), `qa_cenarios.py` (cenários), `qa_jogo.py` (passos do jogo), `qa_lib.py` (cliente MCP com retry, `clique`,
`tecla`, `lua_cliente/lua_servidor`, `esperar`, `foto`, `console_erros`, `verificar`), `bot_luta.luau` e `acao_luta.luau`
(jogam pelo remoto `Mesa`, como o cliente). Capturas em `build/qa/<data>/` (`<cenário>_<nome>.png` e nomes estáveis
`abertura`, `criacao`, `cidade`, `luta_hud`, `luta_golpe`, `luta_disparo`, `resultado`, `acampamento`, `escolhas`, `diario`, `menu`...).

## Limitações
- `execute_luau` no cliente reseta a câmera: capturas 3D logo depois dele podem sair sem mundo/câmera errada (artefato do teste).
- Os textos são comparados normalizados (sem acento/espaçamento de letras); mudança de texto no jogo pode exigir ajuste.
- O bot não representa um jogador bom; derrota do grupo é tratada, mas não forçada.
- Um Play inteiro leva ~10–15 min. Multiplayer, celular e áudio audível não são cobertos.
