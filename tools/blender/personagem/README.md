# PERS1 — personagem no estilo "R15 padrão + roupa do jogo" (fase 1: proposta renderizada)

Rumo decidido pelo Pedro (15/11/2026), com *Arcane Lineage*/*Deepwoken* como referência só de estrutura: **corpo R15
padrão do Roblox** (blocado clássico), **roupa do jogo** (nunca a do avatar), **cabelo do próprio avatar** do jogador,
cor de pele (e de cabelo, quando der) pela raça e pela criação, **traços de raça como acessórios nossos**. Se o cabelo do
avatar não aceitar recolorir, entra um **cabelo padrão nosso**. Haverá um **cabeleireiro** na cidade (o jogador digita o
ID de um cabelo do catálogo). Nada foi enviado à Roblox nem testado no Studio nesta fase.

## Como gerar

```
python tools/blender_rodar.py tools/blender/personagem/folhas.py              # as duas folhas (~3 min)
python tools/blender_rodar.py tools/blender/personagem/folhas.py --folha estilo --so mago   # uma fileira (aventureiro|ladino|mago|racas|cabelos)
python tools/blender_rodar.py tools/blender/personagem/folhas.py --folha comparacao
```

Saídas (em `build/`, fora do git): `build/personagem/estilo_roblox.png` (3 conjuntos em 4 vistas + golpe, traços de raça,
cabelos nossos), `build/personagem/comparacao.png` (boneco atual x novos, mesma escala; vista da luta a 50° com goblin e
rato atuais em casas de 5 studs), `build/personagem/moldes/*.png` (camisa/calça clássicas 585 × 559 e rosto) e
`build/personagem/triangulos.json`.

| Arquivo | Papel |
|---|---|
| `comum.py` | geometria (varredura superelíptica, esfera com azimute/elevação, aros, placas, solidificar), FK nas juntas do R15 a partir dos clipes de `anim_clipes.py`, materiais (corpo = pele + Pants + Shirt pelo alfa), rosto pintado (numpy), cena EEVEE com luz de três pontos, textos, composição |
| `roblox_r15.py` | corpo R15 padrão com as medidas de `anim_rig.py` (as do jogo), UV de cada face nas regiões do molde clássico, cabeça e rosto |
| `roupas.py` | pintura dos moldes (pano com grão, vincos, costuras, barras, oclusão pintada) e as peças rígidas: cinto, bolsa, canos de bota, capuz, capelete, lenço, adaga, chapéu, saia do manto, mangas em sino, capa (pronta, ainda sem conjunto) |
| `cabelos_racas.py` | 4 cabelos nossos recoloríveis (curto, longo, rabo, espetado), 1 "cabelo de avatar" de exemplo e os traços de raça (orelhas de elfo, barba de anão trançada, orelhas de raça-fera) |
| `folhas.py` | monta os bonecos e as duas folhas |

## Pesquisa (create.roblox.com/docs, consultada em 15/11/2026)

**a) Cabelo do avatar num corpo padrão.** `Players:GetHumanoidDescriptionFromUserIdAsync(userId)` "returns a
HumanoidDescription which specifies everything equipped for the avatar of the user… also includes scales and body
colors" (a versão sem `Async` está *deprecated*) — https://create.roblox.com/docs/reference/engine/classes/Players.md.
Dela só se copia `HairAccessory` ("usually those attached to its head resembling hair", lista separada por vírgulas) para
uma **HumanoidDescription nova** com corpo/cabeça/roupas/rosto zerados, escalas e `HeadColor`… da raça, aplicada com
`Humanoid:ApplyDescription(Reset)Async` — https://create.roblox.com/docs/reference/engine/classes/HumanoidDescription.md e
https://create.roblox.com/docs/characters/appearance. O jogo já faz isso em `src/server/AparenciaJogador.luau`
(`ApplyDescriptionResetAsync(Servico.descrever(...))`, com `Visual.descrever` zerando Head/Torso/…/Shirt/Pants): basta
preencher `HairAccessory`. A página não diz explicitamente se itens não possuídos podem ser vestidos; o uso corrente é que
sim (a confirmar no Studio).

**b) Recolorir cabelo de acessório.** Não há um caminho único:
- `SpecialMesh.VertexColor` "changes the hue of a mesh's texture" (multiplica) — https://create.roblox.com/docs/reference/engine/classes/SpecialMesh.md;
- `MeshPart.TextureID` é gravável por script (só `MeshId` é "Not Accessible Security") — https://create.roblox.com/docs/reference/engine/classes/MeshPart.md;
  limpar a textura deixa a malha na cor `MeshPart.Color` (recolore, mas perde o desenho de fios);
- `SurfaceAppearance.Color` tinge **só o ColorMap, como multiplicador** ("Tinting only applies to the ColorMap and not the
  MeshPart.Color"; recomenda mapas quase brancos), e `AlphaMode` Overlay/TintMask controlam onde — https://create.roblox.com/docs/art/modeling/surface-appearance.
  Multiplicar só escurece: um cabelo preto não vira loiro.

Regra proposta: cabelo com `SpecialMesh` → `VertexColor`; `MeshPart` sem `SurfaceAppearance` → limpar `TextureID` e usar
`Color` (o jogador vê a prévia e decide); com `SurfaceAppearance` (cabelo PBR) → **não recolorível**: se a raça/criação
exigir outra cor, o jogo usa um **cabelo padrão nosso** (`cabelos_racas.py`: uma MeshPart por cor, `Color` livre).

**c) Roupa do jogo.**
- *Shirt/Pants clássicas*: molde 585 × 559 (regiões 128 × 128 e 64 × 128 — https://create.roblox.com/docs/art/accessories/classic-clothing).
  Publicar como item custa 80 Robux por envio no Creator Dashboard, e a Open Cloud **não** tem tipo Shirt/Pants: aceita
  Animation, Audio, Decal/Image, Mesh, Model e Video — https://create.roblox.com/docs/cloud/guides/usage-assets. E a
  `HumanoidDescription.Shirt/Pants` exige asset do tipo Shirt/Pants, "not a Decal or Image". Caminho grátis: enviar o PNG
  como **Decal** pela Open Cloud (chave do projeto, como `tools/roblox_upload.py`) e pôr `Shirt.ShirtTemplate` /
  `Pants.PantsTemplate` direto nas instâncias (o guia manda testar assim no Studio). **Que um id de Image funcione no
  ShirtTemplate em jogo publicado ainda precisa ser confirmado no Studio** — é o ponto de risco desta proposta.
- *Roupa em camadas*: exige malha com esqueleto, gaiolas interna/externa (`WrapLayer`) e o Avatar Setup no Studio —
  https://create.roblox.com/docs/art/accessories/layered-clothing; a Open Cloud não documenta esse envio. Fora de alcance
  sem trabalho manual no Studio.
- *Peças rígidas*: MeshPart soldada a uma parte do R15 — é o que `EncaixeCosmetico.configurarPecas` já faz (Weld,
  `Massless`, sem colisão) e o que `tools/gerar_modelo.py` já envia (FBX pela Open Cloud, recolorido por grupo).

**Recomendação:** híbrido, como os jogos de referência — **camisa/calça clássicas pintadas por script** para o pano
(dobras, costuras e sombreado ficam na textura e custam zero triângulos) **+ peças rígidas** para volume e silhueta
(cinto, bolsa, capuz, chapéu, saia do manto, mangas, canos de bota). Camadas ficam de fora.

**d) Cabeleireiro (ID digitado).** No servidor:
1. aceitar só número inteiro positivo, com limite de frequência por jogador (ex.: 1 pedido a cada 5 s) e cache por ID;
2. `MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Asset)` (lança erro se o item não existe; tem
   `AssetTypeId`, `IsForSale`, `Creator`…; "Transparent Batching") — https://create.roblox.com/docs/reference/engine/classes/MarketplaceService.md —
   e exigir `AssetTypeId == 41` (`HairAccessory`) — https://create.roblox.com/docs/reference/engine/enums/AssetType.md;
3. aplicar com `HairAccessory = tostring(id)` + `ApplyDescription` (sem `InsertService`). Se for preciso inspecionar a
   malha antes (para decidir se recolore), `InsertService:LoadAsset` serve: a checagem de segurança libera "benign asset
   types such as t-shirts, shirts, pants and avatar accessories… loadable from any game" — https://create.roblox.com/docs/reference/engine/classes/InsertService.md;
   conferir que o resultado só tem `Accessory` com `Handle` (nada de scripts), como `gerar_modelo.py` já faz;
4. gravar o ID no perfil só depois de aplicado; recolorir segue a regra de (b), senão o cabelo fica na cor original.

## Triângulos (`build/personagem/triangulos.json`)

| Peça | Triângulos |
|---|---|
| Corpo R15 (14 caixas chanfradas × 108 + cabeça 668) | 2.180 |
| Aventureiro: cinto 396 + bolsa 72 + canos de bota 2 × 384 | 1.236 |
| Ladino: capuz 1.208, lenço 672, capelete 448, cinto 324, adaga 76, botas 768 | 3.496 |
| Mago: saia do manto 1.040, chapéu 966, mangas 2 × 672 | 3.350 |
| Cabelos nossos: curto 1.140, longo 1.446, rabo 1.126, espetado 946 | ≤ 1.500 cada |
| Raças: orelhas de elfo 92, barba de anão 682, orelhas de fera 112 | |

Corpo dentro do alvo (≤ 4.000); toda peça ≤ 1.500. Com as peças, o pior conjunto (ladino) dá ~5.700 por personagem.

## O que muda

**Pipeline de envio.** Moldes: PNG → Open Cloud como Decal (novo modo em `tools/roblox_upload.py`; o id vai a um
catálogo de roupas). Peças rígidas e cabelos: o FBX atual de `gerar_modelo.py` (uma MeshPart por cor), com origem no ponto
de encaixe e `ENCAIXES` como em `avatar.py`. Exportar estas peças ainda não está escrito (fase 2): faltam suavização
(`mesh_smooth_type` com faces suaves, hoje `FACE` chapado) e um `GERADORES` que o `modelos.py` enxergue.

**Jogo.** `src/shared/Aparencia/Visual.luau` (`descrever`: deixar `HairAccessory` do avatar ou do cabeleireiro, cores da
raça; `decorar`: pôr `Shirt`/`Pants` do conjunto e as peças rígidas em vez dos cabelos/roupas de caixas), `Catalogo.luau`
(trocar `CABELOS`/`BARBAS`/roupas por conjuntos `{camisa, calca, pecas}` e os cabelos nossos; o `ROSTO` de caixas vira
textura no Head), `EncaixeCosmetico.luau` (continua soldando as peças) e `src/client/AparenciaEditor.luau` (escolha de
conjunto, de cor de cabelo, "usar cabelo do avatar" e o cabeleireiro). Servidor: `src/server/AparenciaJogador.luau`.

## Limitações vistas nas folhas

- Corpo blocado é rígido: no golpe as caixas se abrem nos cantos dos joelhos e cotovelos como em qualquer R15 padrão.
- Saia do manto e capa são rígidas no `LowerTorso`/`UpperTorso`: a perna atravessa a saia no golpe (visível no mago).
- Cabelo do avatar com chapéu/capuz se atravessa; o jogo deve esconder o cabelo quando houver capuz/chapéu.
- A projeção do molde no R15 é minha aproximação (faixas por altura da peça); posições do molde a conferir no template
  oficial. Nada foi testado no Studio: `ShirtTemplate` com id de Image, recolorir cabelos reais, `ApplyDescription` com
  cabelo não possuído e o custo de desempenho continuam **não verificados**.
