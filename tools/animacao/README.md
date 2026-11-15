# Animações por dados (ANIM1)

Clipes de combate como tabelas Luau, tocados no cliente por `src/client/TocadorClipe.luau` (escreve
`Motor6D.Transform` em `PreSimulation`). Nada é enviado ao Roblox. Fontes e licenças: `FONTES.md`.

## Peças

| Arquivo | Papel |
|---|---|
| `tools/blender/anim_exportar.py` | entrada: gera `src/shared/Animacoes/Clipes/*.luau`, `Catalogo.luau` e as prévias |
| `tools/blender/anim_clipes.py` | poses-chave autorais dos 12 clipes (a fonte de hoje) |
| `tools/blender/anim_pose.py` | resolve uma pose (canais FK/IK) nas 15 juntas do R15 |
| `tools/blender/anim_rig.py` | rig R15 de referência, FK com a fórmula do Roblox, IK de dois segmentos, eixos |
| `tools/blender/anim_curvas.py` | interpolação entre chaves, redução de quadros, espelho do `Amostra.luau` |
| `tools/blender/anim_previa.py` | boneco de blocos posado pelos DADOS exportados, folha PNG e conferências |
| `tools/blender/anim_ual.py` | redirecionamento da Universal Animation Library (Quaternius, CC0) para o R15 |
| `src/shared/Animacoes/Amostra.luau` | leitura pura dos clipes (spec: `src/server/tests/Animacoes.spec.luau`) |

## Regenerar

```
python tools/blender_rodar.py tools/blender/anim_exportar.py                 # todos + prévias (~25 s)
python tools/blender_rodar.py tools/blender/anim_exportar.py --clipes CorteLeve,Queda
python tools/blender_rodar.py tools/blender/anim_exportar.py --sem-previa
python tools/blender_rodar.py tools/blender/anim_exportar.py --teste-ual CorteLeve   # ida e volta do redirecionamento
```

Cada clipe imprime: chaves gravadas, erro da IK dos pés, `pe_min` (sola mais baixa; ~0 = no chão) e `penetra`
(quanto braço, mão ou lâmina entra no tronco/cabeça e em que instante). Depois **abra** `build/anim/previa/<Clipe>.png`:
linha de cima 3/4 pela frente-direita, linha de baixo perfil pela direita; poste vermelho = alvo à frente; o
retângulo no chão é a casa (4 x 4). Rode `powershell -File tools/testar.ps1` no fim.

Com a UAL baixada (ver `FONTES.md`): copie `ual_clipes.exemplo.json` para `ual_clipes.json`, ajuste os nomes das
ações e rode `... anim_exportar.py --ual build/externos/ual/<arquivo>.glb --mapa tools/animacao/ual_clipes.json`.
Os clipes do mapa passam a ter `origem = "ual"`; os demais continuam posados.

## Acrescentar um clipe

1. Em `anim_clipes.py`, `CLIPES["Nome"] = dict(duracao, laco, marcos, modos, arma, chaves=[(t, canais, tensao)])`.
   Comece e termine na `POSTURA` (clipes de ação), use `P(POSTURA, ...)` para mudar só alguns canais. Golpe precisa do
   marco `impacto` (disparo: `soltar`). `segurar=True` deixa o clipe parado no último quadro (Queda, Vitória).
2. Acrescente o nome em `ORDEM` (`anim_exportar.py`) e, se for golpe, em `GOLPES`/`ESPERADOS` do spec.
3. Exporte, abra a folha e corrija até ler bem. Convenções (graus; matriz Rx·Ry·Rz como `CFrame.Angles`): Rx+ leva
   braço/coxa à frente e inclina o tronco para TRÁS; Ry+ gira a frente para a esquerda; ombro direito Rz+ abre,
   esquerdo Rz-; cotovelo Rx+ dobra; joelho dobra com Rx-.

## Contrato com o jogo

- Quatérnio `{t, qx, qy, qz, qw}` = rotação do `Motor6D.Transform` da junta (eixos da Part0); entra em
  `CFrame.new(x, y, z, qx, qy, qz, qw)`. Supõe o R15 padrão (C0/C1 sem rotação). `raiz` = translação do Transform
  da junta `Root` em studs do boneco de referência (o tocador escala por `HumanoidRootPart.Size.Y / 2`).
- Pega da arma assumida pelos clipes de espada: a lâmina sai do punho para **-Z da mão** (perpendicular ao
  antebraço). No `Corpo.arma` de hoje a lâmina segue -Y da mão (continua o braço); para casar com os clipes, o
  punho deve ser soldado com `CFrame.new(0, -0.15, 0) * CFrame.Angles(math.rad(90), 0, 0)`.
- Arco: o arco fica na mão esquerda, vertical, com o braço estendido para o alvo; a corda vai à mão direita entre os
  marcos `puxar` e `soltar` (a flecha sai em `soltar`).
