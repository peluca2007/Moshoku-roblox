# Fontes dos kits (MOD2a, 15/11/2026)

Tudo CC0 (domínio público), confirmado na página do pacote e no `License.txt` dentro do zip. Os zips ficam em
`build/externos/<pacote>/` (fora do git) e são tratados como dados: só lidos pelo Blender, nada executado.

| Pacote | Página (licença lida em 15/11/2026) | Download usado | Usado em |
| --- | --- | --- | --- |
| Kenney Mini Dungeon 2.0 | https://kenney.nl/assets/mini-dungeon ("Creative Commons CC0"); https://opengameart.org/content/mini-dungeon (CC0) | https://opengameart.org/sites/default/files/kenney_mini-dungeon_2.0.zip | esgoto, taverna (mesa, cadeira), criaturas (orc, humano) |
| Kenney Fantasy Town Kit 2.0 | https://kenney.nl/assets/fantasy-town-kit (CC0); https://opengameart.org/content/fantasy-town-kit (CC0) | https://opengameart.org/sites/default/files/kenney_fantasy-town-kit_2.0.zip | taverna (banco, banquinho, lampião, poste) |
| Quaternius LowPoly Medieval Weapons (set/2018) | https://opengameart.org/content/lowpoly-medieval-weapons (CC0, autor quaternius) | https://opengameart.org/sites/default/files/Medieval%20Weapons%20Pack%20-%20Sept%202018.zip | armas |
| Kenney Furniture Kit | https://opengameart.org/content/furniture-kit (CC0) | https://opengameart.org/sites/default/files/kenney_furniturePack.zip | baixado e REJEITADO (móveis modernos); não entra |

Texto da licença (`License.txt` dos pacotes Kenney): "License: (Creative Commons Zero, CC0)
http://creativecommons.org/publicdomain/zero/1.0/ - You can use this content for personal, educational, and
commercial purposes. Support by crediting 'Kenney' or 'www.kenney.nl' (this is not a requirement)".
Crédito a Kenney e Quaternius fica como cortesia (colocar nos créditos do jogo).

## Não obtido

- Kenney: o botão de download de kenney.nl pede um link assinado gerado por script da página (retornou `forbidden`
  para requisição direta); não foi contornado. Usado o espelho oficial do mesmo autor no OpenGameArt (CC0), onde
  existem Mini Dungeon e Fantasy Town Kit. **Retro Fantasy Kit, Weapon Pack e Particle Pack do Kenney: não baixados**
  (sem espelho direto; o Weapon Pack do OpenGameArt deu "Access denied").
- Quaternius Fantasy Props MegaKit, Ultimate Monsters e Ultimate RPG: só por Google Drive/Patreon/itch (clique
  humano). Não baixados. Um humano pode baixá-los em `build/externos/<pacote>/` e acrescentar entradas ao
  `catalogo.py`.
- Criaturas do esgoto (rato, slime, morcego, aranha, esqueleto): nenhum pacote direto. Só orc e humano do Mini Dungeon.
  O rato atual continua o de `tools/blender/criaturas.py`.

## Criaturas Quaternius (MOD3, 15/11/2026)

| Pacote | Origem | Licença | Uso |
|---|---|---|---|
| Monster Pack Animated by Quaternius (Bat, Dragon, Skeleton, Slime) | `build/externos/Monster Pack Animated by Quaternius.zip` (baixado pelo coordenador; extraído em `build/externos/monster-pack/`) | CC0 segundo o autor; **o zip não traz arquivo de licença** e a página consultada (quaternius.com) não a mostra no texto: o coordenador deve confirmar a licença na página do pacote | criaturas da luta |
| Easy Animated Enemy Pack - Jan 2019 (Frog, Rat, Snake, Snake_angry, Spider, Wasp) | `build/externos/Easy Animated Enemy Pack - Jan 2019.zip` (extraído em `build/externos/easy-enemy/`) | idem (CC0 declarada, sem arquivo no zip) | criaturas da luta |

Só os FBX são lidos (malha + pesos); as animações do pacote não são usadas. Crédito a Quaternius como cortesia.

## Lobo e goblin (MOD4, 16/11/2026)

Ambos CC0 do Quaternius, baixados do espelho oficial dele no OpenGameArt (licença CC0 lida na página em 16/11/2026) para
pastas próprias em `build/externos/` (fora do git):

| Pacote | Página | Download | Usado em |
| --- | --- | --- | --- |
| Animal Pack Vol.2 (lobo; só Idle e Walking) | https://opengameart.org/content/animated-animales-low-poly (CC0) | https://opengameart.org/sites/default/files/Animal%20Pack%20Vol.2%20by%20%40Quaternius.zip | `animais-vol2` -> LoboQuaternius |
| Ultimate Animated Character Pack, nov/2019 (Goblin_Male) | https://opengameart.org/content/animated-characters-pack (CC0) | https://opengameart.org/sites/default/files/ultimate_animated_character_pack_by_quaternius.zip | `personagens-ultimate` -> GoblinQuaternius |

Lobo: Respirar/Andar do pacote; Atacar (bote com marco `impacto`), LevarGolpe e Morrer sintetizados. Goblin: Idle, Walk, Punch
(Atacar), RecieveHit, Defeat do pacote. Registro em `shared/Animacoes/Criaturas/*.luau` (`origem`).
