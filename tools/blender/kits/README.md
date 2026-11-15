# Kits gratuitos (MOD2a)

Converte kits CC0 (ver `FONTES.md`) para o formato do pipeline de modelos (`tools/blender/lib.py`): um FBX por
modelo, uma MeshPart por cor, cores e materiais no `.json` ao lado. Nada daqui envia à Roblox.

## Regenerar do zero

1. Baixar e extrair os zips de `FONTES.md` em `build/externos/<pasta>/x/` (pastas em `catalogo.FONTES`):
   `mini-dungeon`, `fantasy-town-kit`, `quaternius-weapons-2018`.
2. `python tools/blender_rodar.py tools/blender/kits/preparar.py` (6 s) grava `build/kits/<categoria>/<Nome>.fbx|.json`
   e `build/kits/manifesto.json` (origem, licença, triângulos, dimensões em studs, cores). `--so Nome1,Nome2` converte só alguns.
3. `python tools/blender_rodar.py tools/blender/kits/previas.py [--qual folhas|arena|comparacao|tudo]` (cerca de 3 min)
   grava `build/kits/previa/{esgoto,armas,taverna,criaturas,arena_esgoto,comparacao}.png`, lendo os FBX gerados.

Arquivos: `catalogo.py` (o que converter e ajustes), `kit_lib.py` (importar OBJ, cor por face via UV, paleta sóbria,
agrupar por cor, decimar, pivô, exportar), `extras.py` (peças feitas por código: canos, tocha, água, grade, balcão,
caneca, candelabro, lareira, cajado), `cena_kit.py`/`previas.py` (renderização).

## Convenções das peças

- 1 unidade = 1 stud; casa do combate = 5 studs; piso, paredes e pedras do esgoto têm 5 de lado. Origem no chão, centrada.
- Armas: eixo longo em Y, ponta para -Y do Blender (= -Z do Roblox), pivô na mão do autor. Arco dispara para -Y, escudo tem a
  frente para -Y, flecha com a ponta em -Y (pivô no centro). **Orientação no Roblox não conferida no Studio.**
- Paleta: Kenney vem azulado/salmão; `kit_lib.afinar` converte pedra em cinza, madeira em marrom e baixa a saturação.
- Orçamento de triângulos: cenário 3000, prop 1500, arma 800, criatura 2500 (decimado se passar).

## Enviar um modelo pelo pipeline existente (próximo agente)

O FBX+JSON já está no formato de `tools/blender/lib.py`. `tools/gerar_modelo.py` só gera por `modelos.py`; para um kit:
`roblox_upload.enviar(<fbx>, "Moshoku <Nome>")` -> asset id, registrar em `tools/blender/assets.json`, e repetir o passo do
Studio de `gerar_modelo.py` (LoadAsset, recolorir cada MeshPart pelo grupo do `.json`, `exportar_modelo.py`). Sugestão: um
`--kit build/kits/<cat>/<Nome>.fbx` em `gerar_modelo.py` que pule a etapa do Blender.

## Lista recomendada (nome -> uso)

Esgoto: EsgotoPiso/PisoLajes (piso da casa), EsgotoParede/ParedeBaixa/Arco (paredes), EsgotoColuna, EsgotoEscada,
EsgotoGrade (grade de ferro), EsgotoCano/CanoCurva/CanoParede, EsgotoGradePiso (ralo), EsgotoAgua (canal; ajustar
transparência no Studio), EsgotoTocha (+ PointLight), Barril, Bau, Pote, EsgotoPedras/Pedregulhos, EsgotoArmadilha.
Armas: EspadaLonga, EspadaCurta, Montante, Adaga, Machado, Machadinha, Martelo, Lanca, Cajado (código), Arco/ArcoLongo,
Flecha, EscudoRedondo, EscudoBrasao. Taverna: TavernaMesa/MesaLonga, TavernaCadeira, TavernaBanco/Banquinho,
TavernaBalcao, Caneca, Candelabro, Lareira, Lampiao, Poste. Criaturas: Orc (goblin/orc estático), Humano.
