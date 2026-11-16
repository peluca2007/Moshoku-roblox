# Arte de interface gerada localmente (ARTE1)

Geração de imagem offline e gratuita para painéis, ícones e retratos da interface. Tudo fica fora do git, em `build/ferramentas/` (ignorado por `build/` no `.gitignore`).

## O que foi instalado (15/11/2026)

| Item | Versão / origem | Licença |
|---|---|---|
| stable-diffusion.cpp, backend Vulkan (`sd-cli.exe`) | release `master-1104-5dcfa79`, <https://github.com/leejet/stable-diffusion.cpp/releases> (`sd-master-5dcfa79-bin-win-vulkan-x64.zip`) | MIT |
| SDXL base 1.0 (`sd_xl_base_1.0.safetensors`, 6,9 GB, SHA256 `31e35c80…7e5b` conferido com o ETag do Hugging Face) | `stabilityai/stable-diffusion-xl-base-1.0` | CreativeML Open RAIL++-M: uso comercial permitido, com restrições de uso (sem conteúdo ilícito/danoso). Preciso manter o aviso da licença se redistribuir o modelo; as imagens geradas são nossas. |
| VAE SDXL fp16-fix (`sdxl_vae_fp16_fix.safetensors`, SHA256 `235745af…c6e1`) | `madebyollin/sdxl-vae-fp16-fix` | MIT |

Rejeitado: **SDXL-Turbo** (licença Stability AI de pesquisa/não comercial, não serve a um jogo comercial). Escolhi sd.cpp+Vulkan em vez de ComfyUI/DirectML/ZLUDA por ser binário único, sem Python/torch e sem dependência de driver especial; funcionou de primeira na RX 7600.

Layout: `build/ferramentas/sdcpp/` (binário e DLLs), `build/ferramentas/modelos/` (checkpoint e VAE). Amostras em `build/arte/amostras/`.

## Como usar

```
python tools/arte/gerar_imagem.py --estilo icone_habilidade -p "a sword slash" -s 3 -o build/arte/x.png
python tools/arte/gerar_imagem.py -p "..." -n "negativo" -W 1024 -H 256 --passos 25 --cfg 6.5 -s 7 -o x.png
python tools/arte/remover_fundo.py x.png x_transparente.png          # modo escuro (padrão)
python tools/arte/remover_fundo.py x.png y.png --modo borda --max 40  # só o fundo ligado às bordas
python tools/arte/gerar_amostras.py                                   # regenera as 5 amostras
```

Estilos (`--estilo`): `painel_pincelada` (1024x256), `icone_habilidade` (512x512, fundo preto para o recorte), `retrato` (768x1024). Passar `-W/-H/--passos` e `-n` sobrescreve. Com `--semente -1` a semente é aleatória. Em worktrees, o script acha as ferramentas na raiz do repositório principal; `MOSHOKU_FERRAMENTAS` sobrescreve o caminho.

## Tempo medido (RX 7600 8 GB, 25 passos)

Cerca de **28 s por imagem**, tanto 1024x256 quanto 512x512 (5 amostras: 27,6 a 28,5 s, incluindo carregar o modelo de 6,9 GB a cada chamada). Retrato 768x1024 não foi medido.

## Limitações (franqueza)

- Qualidade das amostras: **utilizável como ponto de partida, não final**. Os painéis 1024x256 saem com listras verticais e manchas claras (formato muito fora da resolução nativa do SDXL, ~1024x1024); o ícone de golpe e o de defender saíram aceitáveis, o de esquiva ganhou cenário em vez de ícone isolado. Não chega ao nível de Expedition 33 sem curadoria.
- Melhorias a testar: gerar painéis em 1024x1024 e recortar, ou 1344x768; várias sementes e escolher; LoRA/modelo de pintura a óleo com licença conferida; img2img sobre pinceladas desenhadas à mão; ESRGAN (`--upscale-model`) para subir resolução.
- O recorte `remover_fundo.py` por luminância assume fundo escuro; áreas escuras internas do ícone também ficam translúcidas (use `--modo borda` nesses casos). Não há controle de texto: letras geradas são ruins, por isso o negativo as proíbe; rótulos devem ser texto do Roblox.
- A imagem gerada por IA não tem garantia de ineditismo; revisar antes de usar como marca do jogo.
- Obs. de instalação: baixar o checkpoint com **um** `curl` só; dois downloads no mesmo arquivo corromperam o primeiro (detectado pelo SHA256).

# Pinceladas e ícones do HUD da luta (ARTE2)

Interface da luta com arte pintada, no espírito do HUD de Clair Obscur: Expedition 33 (só estrutura e clima; arte nossa).

- `tools/arte/pinceladas.py` (Pillow + numpy, sem IA, semente fixa) gera em `build/arte/hud/`: faixa de carta (normal, foco, bloqueada), botão curto (normal, foco, bloqueado, principal), disco e losango de tecla/custo, manchas de retrato e cartão, anel dourado do personagem ativo e `prancha.png` (contato). Bordas de cerdas e falhas de tinta, leve inclinação e fio dourado em um lado. As faixas e botões são 9-slice (cortes em `CORTES`, copiados para `shared/UIArteLuta`).
- `tools/arte/icones_gameicons.py` baixa os SVG para `build/arte/gameicons/`, tira o fundo, converte em branco com transparência (resvg) e monta um atlas `icones.png` (46 ícones, células de 128 px). O Roblox tinge por `ImageColor3` conforme a árvore da habilidade.
- Ids e mapeamento `habilidade -> ícone` (por id, palavra e árvore): `src/shared/UIArteLuta.luau`. Para trocar a arte: regerar, servir `build/arte/hud` por HTTP local e enviar com `upload_image` do MCP do Studio, e atualizar os ids.
- Aplicado em `client/AcoesDoTurno` (botões de comando, abas, cartas), `TooltipAcao`, `DetalheAcao` e nos helpers de `client/UI/PecasLuta` (`P.arte`, `P.icone`, `P.tecla`, `P.losango`).
- Pendente (fora do escopo da tarefa): usar `mancha_retrato`/`mancha_cartao` nos cartões do grupo e retratos (`Hud`/`RetratoLuta`/`BarrasLuta`) e trocar o disco amarelo do personagem ativo (`BoardView`, parte `turn`) pelo `anel_ativo.png` (id em `UIArteLuta.PECAS.anel_ativo`); crédito dos ícones na tela de Ajuda.

## Créditos dos ícones (CC BY 3.0)

Ícones de [game-icons.net](https://game-icons.net) (repositório github.com/game-icons/icons), licença Creative Commons Attribution 3.0 (<https://creativecommons.org/licenses/by/3.0/>). Autores: **Lorc**, **Delapouite**, **Skoll**, **Willdabeast**, **Carl Olsen**, **sbed** (CC BY 3.0) e **Zeromancer** (heart-plus; CC0 no site). A fonte de cada ícone do atlas está em `build/arte/hud/icones.json` (campo `fonte`, `autor/arquivo`). Alterações: fundo removido, cor branca e recorte em atlas.

# Criaturas Quaternius na luta (MOD3)

Pipeline: `python tools/criaturas_quaternius.py` (Blender: `tools/blender/kits/criaturas_quaternius.py`) lê os FBX de
`build/externos/{monster-pack,easy-enemy}`, põe o modelo na pose do clipe Idle, divide cada polígono pelo osso de maior peso
em partes rígidas (Corpo, Cabeca, BracoE/D, PernaE/D, Cauda) e grava `build/criaturas/<Modulo>.fbx|.json|.png` no contrato de
`tools/blender/criaturas.py` (grupos `<Parte>_<Cor>`, `pivos` em coordenadas Roblox). Os pivôs vão a `Shared/Mundo/PivosModelos`
(`gravar_pivos`). Prancha: `python tools/blender/kits/prancha.py build/criaturas build/beleza/modelos/prancha.jpg`.
Fontes e licença: `tools/blender/kits/FONTES.md` (CC0 declarada; confirmar na página, o zip não traz arquivo).

**Animação (decisão com evidência).** As curvas do pacote não foram convertidas: o esqueleto não sobrevive ao envio
(`roblox_upload` só manda MeshParts) e animação de outro dono não toca (docs/DIRECAO.md §5). As criaturas usam o
`AnimacaoCriatura` já existente (respirar, andar por pernas/patas, golpe, tombar) sobre as peças rígidas; novo tipo
`voador` (asas batem em roll). Clipes Luau a partir das curvas ficam como melhoria futura.

**Mapeamento.** rato-gigante -> RatoQuaternius; aranha-da-floresta -> AranhaQuaternius; esqueleto-andarilho -> EsqueletoQuaternius;
serpente-de-fogo -> SerpenteQuaternius (sem fogo); dragao-azul -> DragaoQuaternius. Convertidos sem criatura no jogo: Slime,
Morcego, Sapo, Vespa. **Sem correspondente:** lobo-cinzento, goblin-batedor, urso, bandido, treant, golem (ficam os blocos;
Orc/Humano do Kenney em `build/kits/criaturas` são estáticos e não foram ligados).

**Ligação e fallback.** `ModelosCriaturas.escolher(id, variante, existe)` usa o campo `preferido` só se `existe(modulo)`
(MontarModelo.existe); sem o módulo em `server/Mundo/Modelos`, segue o modelo de blocos. **Falta o envio:** a chave Open Cloud
em `~/.moshoku/roblox_api_key.txt` respondeu "Invalid API Key" (15/11) e o Studio estava ocupado. Com chave válida e Studio livre:
`python tools/criaturas_quaternius.py --studio` (envia, recolore, exporta `Modelos/*.luau`) e `python tools/studio_sync.py`.

**Notas (renders do Blender, sem Studio).** Rato 7,5; Aranha 8; Esqueleto 7,5 (cor lisa de osso); Serpente 8; Sapo 8;
Slime 7; Morcego 7,5; Vespa 8; Dragão 6,5 (mais morcego grande que dragão). Triângulos: rato 4000, sapo 4900, aranha 2700
(acima do orçamento de 2500; decimar se pesar). Cor sRGB vem do material e passa por `SATURACAO`/`VALOR` do script.

## Animações da luta: Universal Animation Library (APRES1)
Quaternius, **CC0 1.0** (`License.txt` do pacote), `Universal Animation Library[Standard].zip` (UAL1, glb Unreal-Godot, 24 fps), baixada em 15/11/2026 e extraída em `build/externos/ual/` (fora do git). Redirecionada para o R15 por `tools/blender/anim_ual.py` com o mapa `tools/animacao/ual_clipes.json` (ver `tools/animacao/README.md`). Clipes da UAL: PosturaCombate (Sword_Idle), CorteLeve/CortePesado (Sword_Attack, 1,1x e 0,7x), Estocada (Punch_Jab), Conjurar (Spell_Simple Enter+Shoot+Exit), Canalizar, ReacaoGolpe (Hit_Chest), Esquiva (Roll), Queda (Death01). Continuam por script (`origem = "script"`): DisparoArco (a UAL1 só tem pistola), Bloqueio, Vitoria.

## Personagem novo (PERS2, 15/11/2026)

Moldes de camisa/calça, cabelos, roupas rígidas e traços de raça são **autorais** (gerados por script Blender em
`tools/blender/personagem/`, sem pacote externo): sem licença de terceiros. Corpo e cabeça são os padrões do Roblox
(HumanoidDescription/SpecialMesh Head). Conferência: `python tools/blender_rodar.py tools/blender/personagem/folhas.py --folha prancha`
gera `build/beleza/personagem/prancha.jpg`. Envio pendente (chave da Open Cloud devolveu 401): moldes em
`build/personagem/moldes/camisa_<conjunto>_<pele>.png` e `calca_*` com
`python tools/roblox_upload.py build/personagem/moldes/camisa_aventureiro_clara.png --nome CamisaAventureiro --tipo Decal`
(idem ladino/mago e calças); depois preencher `shared/Aparencia/Personagem.CONJUNTOS` com `rbxassetid://<id>`.

## Personagem rodada 3 (PERS3, 16/11/2026)

Cabelos, barbas, orelhas, rostos e peças de roupa modelados por script no Blender (`tools/blender/personagem/`, sem pacote
externo, sem textura de terceiros): sem licença de terceiros; as peças são nossas. Conferência: `python tools/blender_rodar.py
tools/blender/personagem/folhas.py --folha v3` gera `build/beleza/personagem/prancha_v3.jpg`. Envio (rota do Studio):
`$env:MOSHOKU_VIA_STUDIO="1"; python tools/blender/personagem/enviar.py` (peças -> `src/server/Mundo/Modelos`, rostos ->
`build/personagem/rostos/ids.json`).

## Corpos oficiais gratuitos (PERS4, 16/11/2026)

Só pacotes publicados pela própria Roblox (dono `Roblox`, id 1; preço 0; `catalog.roblox.com/v1/bundles/details`), aplicados
pela `HumanoidDescription` (`Personagem.CORPOS`, escolhido por `Personagem.CORPO`; padrão ainda `"caixas"`). Sem
arquivos baixados nem malha nossa: o corpo vem da Roblox em tempo de execução. Todos aceitam o `Shirt`/`Pants` clássico
(Man/Woman/Boy; os "Base Body" anime têm cabeça dinâmica 1,6 e quebram o encaixe).

| Chave | Pacote (bundle) | Ids Torso/BD/BE/PE/PD | Nota |
|---|---|---|---|
| `homem` | Man (238) | 86500008 / 86500036 / 86500054 / 86500064 / 86500078 | Recomendado: mãos, ombros e pés de verdade, cabeça padrão |
| `mulher` | Woman (239) | 86499666 / 86499698 / 86499716 / 86499753 / 86499793 | Mais fina, ok; precisa de `TorsoColor` = pele |
| `menino` | ROBLOX Boy (109) | 376532000 / 376531012 / 376530220 / 376531300 / 376531703 | Mais baixo e largo, bom p/ anão |
| (descartado) | City Life Woman (337) | 2492674027 ... | roupa pintada no torso, ignora a camisa |
| (descartado) | Base Body Dawson/Jordan/Parker (991/994/985) | 11709869073 ... | cabeça 1,6 e pescoço longo; hair/rosto desalinham |

## Cenário do esgoto (CEN1, 16/11/2026)

Só peças do Roblox (Part, cilindros, Fire, ParticleEmitter, PointLight/SpotLight) com materiais nativos e o `MaterialVariant` `EsgotoPedra` já registrado. Nenhum ativo externo novo: a licença não muda. Os kits CC0 (mini-dungeon, fantasy-town-kit) não foram usados: peças procedurais bastaram e evitam conversão e peso. Código: `src/server/Mundo/CenarioEsgoto.luau`.
