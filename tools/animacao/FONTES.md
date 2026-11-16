# Fontes das animações (ANIM1)

## Universal Animation Library (Quaternius) — baixada em 15/11/2026 (UAL1 Standard, CC0; ver docs/ARTE.md)

| | UAL 1 | UAL 2 |
|---|---|---|
| Página | https://quaternius.com/packs/universalanimationlibrary.html | https://quaternius.com/packs/universalanimationlibrary2.html |
| Download | https://quaternius.itch.io/universal-animation-library | https://quaternius.itch.io/universal-animation-library-2 |
| Licença | CC0 1.0 (a página aponta https://creativecommons.org/publicdomain/zero/1.0/; o itch.io diz "Creative Commons Zero v1.0 Universal") | CC0 (mesmas indicações) |
| Versão/data | lançada em 03/2025; itch.io cita "Updated files v2.0" e versões com e sem root motion | itch.io cita correções em `Sword_Light_*` |
| Conteúdo (descrição da página) | 120+ animações: locomoção em 8 direções, trote, corrida, empurrar, rastejar, nadar, sentar, mortes, combate, armas de fogo, emotes | 130+ animações: combos corpo a corpo e com arma (3 e 4 golpes, separados com recuperação), parkour, fazenda, pesca, zumbi |
| Arquivos (itch.io) | `Universal Animation Library[Standard].zip` (15 MB, grátis), `[Pro].zip` (41 MB), `[Source].zip` (46 MB, pago) | idem |

Consulta em 15/11/2026. Por que não foi baixada: os dois botões de download (site e itch.io) abrem o diálogo
"name your own price" do itch.io, que pede uma ação humana ("No thanks, just take me to the downloads") antes de
gerar o link. Pela regra da tarefa, isso não foi contornado. A lista exata de clipes não aparece em texto nas páginas
(só em imagens), então não está registrada aqui.

Para usar: o Pedro baixa o `[Standard].zip` à mão, extrai em `build/externos/ual/` (fora do git; dado não confiável:
só o importador do Blender abre), escreve `tools/animacao/ual_clipes.json` a partir do `ual_clipes.exemplo.json` e roda
o exportador com `--ual` (ver README.md). Registrar aqui a versão do zip e a lista de ações impressa pelo exportador.

## Em uso hoje: poses-chave posadas por script

Os 12 clipes de `src/shared/Animacoes/Clipes/` têm `origem = "script"`: poses-chave escritas à mão em
`tools/blender/anim_clipes.py` (código do projeto, sem terceiros), interpoladas e com IK de pernas/braços em
`tools/blender/anim_pose.py`. Sem licença de terceiros envolvida.
