"""O que sai de cada kit: pacote, arquivo OBJ, nome final, categoria e ajustes.

Escala: o combate usa casas de 5 studs (Protocol.BOARD.cell) e o boneco R15 tem ~5 studs de altura.
Os blocos do Mini Dungeon têm 1 unidade de lado, então `escala=5` faz uma peça de piso ocupar uma casa.
Armas: depois da conversão o eixo longo é Y e a ponta aponta para -Y do Blender (= -Z do Roblox);
o pivô é a origem do modelo original (a mão do autor), conferido nas prévias.
"""

FONTES = {
    "mini-dungeon": {
        "id": "kenney/mini-dungeon-2.0", "licenca": "CC0 1.0",
        "pasta": "mini-dungeon/x/Models/OBJ format",
    },
    "kaykit-dungeon": {
        "id": "kaykit/dungeon-remastered-1.0", "licenca": "CC0 1.0",
        "pasta": "kaykit-dungeon/x/KayKit-Dungeon-Remastered-1.0-main/addons/kaykit_dungeon_remastered/Assets/obj",
    },
    "fantasy-town": {
        "id": "kenney/fantasy-town-kit-2.0", "licenca": "CC0 1.0",
        "pasta": "fantasy-town-kit/x/Models/OBJ format",
    },
    "quaternius-armas": {
        "id": "quaternius/lowpoly-medieval-weapons-2018", "licenca": "CC0 1.0",
        "pasta": "quaternius-weapons-2018/x/Medieval Weapons Pack - Sept 2018/OBJ",
    },
}

# Tons mais sóbrios por tipo de peça
PEDRA = {"sat": 0.35, "valor": 0.78}
MADEIRA = {"sat": 0.55, "valor": 0.72}
FERRO = {"sat": 0.30, "valor": 0.82}
NEUTRO = {"sat": 0.55, "valor": 0.85}

_ARMA = {"orcamento": "arma", "pivo": "origem", "rot": (90, 0, 0), "maximo_cores": 5}


def _d(fonte, arquivo, nome, categoria, uso, **o):
    return {"fonte": fonte, "arquivo": arquivo, "nome": nome, "categoria": categoria, "uso": uso, **o}


ITENS = [
    # ---------- ESGOTO (Mini Dungeon, 1 unidade = 1 casa = 5 studs) ----------
    _d("mini-dungeon", "floor", "EsgotoPiso", "esgoto", "piso de uma casa", orcamento="cenario", escala=5, **PEDRA),
    _d("mini-dungeon", "floor-detail", "EsgotoPisoLajes", "esgoto", "piso de uma casa com lajes", orcamento="cenario", escala=5, **PEDRA),
    _d("mini-dungeon", "wall", "EsgotoParede", "esgoto", "parede de uma casa", orcamento="cenario", escala=5, **PEDRA),
    _d("mini-dungeon", "wall-half", "EsgotoParedeBaixa", "esgoto", "parede baixa", orcamento="cenario", escala=5, **PEDRA),
    _d("mini-dungeon", "wall-narrow", "EsgotoParedeFina", "esgoto", "parede fina", orcamento="cenario", escala=5, **PEDRA),
    _d("mini-dungeon", "wall-opening", "EsgotoArco", "esgoto", "parede com passagem em arco", orcamento="cenario", escala=5, **PEDRA),
    _d("mini-dungeon", "column", "EsgotoColuna", "esgoto", "coluna", orcamento="cenario", escala=5, **PEDRA),
    _d("mini-dungeon", "stairs", "EsgotoEscada", "esgoto", "escada de uma casa", orcamento="cenario", escala=5, **PEDRA),
    _d("mini-dungeon", "gate", "EsgotoGrade", "esgoto", "grade de ferro", orcamento="cenario", escala=5, **FERRO),
    _d("mini-dungeon", "trap", "EsgotoArmadilha", "esgoto", "armadilha de espinhos no chão", orcamento="cenario", escala=5, **FERRO),
    _d("mini-dungeon", "rocks", "EsgotoPedras", "esgoto", "pedras soltas", orcamento="cenario", escala=5, **PEDRA),
    _d("mini-dungeon", "stones", "EsgotoPedregulhos", "esgoto", "pedregulhos", orcamento="cenario", escala=5, **PEDRA),
    _d("mini-dungeon", "wood-structure", "EsgotoMadeiramento", "esgoto", "estrutura de madeira", orcamento="cenario", escala=5, **MADEIRA),
    _d("mini-dungeon", "wood-support", "EsgotoEscora", "esgoto", "escora de madeira", orcamento="cenario", escala=5, **MADEIRA),
    _d("mini-dungeon", "barrel", "Barril", "esgoto", "barril (arena e taverna)", escala=5, **MADEIRA),
    _d("mini-dungeon", "chest", "Bau", "esgoto", "baú", escala=5, **MADEIRA),
    _d("mini-dungeon", "pot", "Pote", "esgoto", "pote de barro", escala=5, **MADEIRA),
    _d("mini-dungeon", "banner", "Estandarte", "esgoto", "estandarte de parede", escala=5, sat=0.7, valor=0.62),
    _d("mini-dungeon", "coin", "Moeda", "esgoto", "moeda", escala=5, sat=0.7, valor=0.8),
    _d("mini-dungeon", "key", "Chave", "esgoto", "chave", escala=5, sat=0.7, valor=0.8),
    _d("mini-dungeon", "potion", "Pocao", "esgoto", "poção", escala=5, sat=0.7, valor=0.8),
    # ---------- ESGOTO (KayKit Dungeon Remastered, CC0, CEN4; módulo de parede ~12 studs de largura) ----------
    _d("kaykit-dungeon", "wall", "EsgotoKKParede", "esgoto", "parede de pedra com tijolos (CEN4)", orcamento="cenario", alvo=("x", 12), maximo_cores=5, **PEDRA),
    _d("kaykit-dungeon", "wall_cracked", "EsgotoKKParedeRachada", "esgoto", "parede rachada (CEN4)", orcamento="cenario", alvo=("x", 12), maximo_cores=5, **PEDRA),
    _d("kaykit-dungeon", "wall_broken", "EsgotoKKParedeQuebrada", "esgoto", "parede quebrada (CEN4)", orcamento="cenario", alvo=("x", 12), maximo_cores=5, **PEDRA),
    _d("kaykit-dungeon", "pillar", "EsgotoKKPilar", "esgoto", "pilar (CEN4)", orcamento="cenario", alvo=("z", 30), maximo_cores=5, **PEDRA),
    _d("kaykit-dungeon", "floor_tile_large", "EsgotoKKPiso", "esgoto", "piso grande de lajes (CEN4)", orcamento="cenario", alvo=("x", 16), maximo_cores=5, **PEDRA),
    _d("kaykit-dungeon", "floor_tile_large_rocks", "EsgotoKKPisoPedras", "esgoto", "piso com pedras (CEN4)", orcamento="cenario", alvo=("x", 16), maximo_cores=5, **PEDRA),
    _d("kaykit-dungeon", "rubble_large", "EsgotoKKEntulho", "esgoto", "entulho (CEN4)", orcamento="cenario", alvo=("x", 8), maximo_cores=4, **PEDRA),
    # ---------- TAVERNA ----------
    _d("mini-dungeon", "table", "TavernaMesa", "taverna", "mesa", escala=5, **MADEIRA),
    _d("mini-dungeon", "chair", "TavernaCadeira", "taverna", "cadeira", escala=5, **MADEIRA),
    _d("fantasy-town", "stall-bench", "TavernaBanco", "taverna", "banco", escala=5, **MADEIRA),
    _d("fantasy-town", "stall-stool", "TavernaBanquinho", "taverna", "banquinho", escala=5, **MADEIRA),
    _d("fantasy-town", "stall", "TavernaBalcaoFeira", "taverna", "balcão de feira (alternativa de balcão)", escala=5, **MADEIRA),
    _d("fantasy-town", "lantern", "Lampiao", "taverna", "lampião de chão (taverna e esgoto)", escala=5, **FERRO),
    _d("fantasy-town", "pillar-wood", "TavernaPoste", "taverna", "poste de madeira", escala=5, **MADEIRA),
    # ---------- ARMAS (Quaternius 2018 + Kenney) ----------
    _d("quaternius-armas", "Sword", "EspadaLonga", "armas", "espada", alvo=("max", 4.2), **_ARMA, **FERRO),
    _d("quaternius-armas", "Sword_2", "EspadaCurta", "armas", "espada de uma mão", alvo=("max", 3.6), **_ARMA, **FERRO),
    _d("quaternius-armas", "Sword_Big", "Montante", "armas", "espada grande", alvo=("max", 5.2), **_ARMA, **FERRO),
    _d("quaternius-armas", "Dagger", "Adaga", "armas", "adaga", alvo=("max", 1.9), **_ARMA, **FERRO),
    _d("quaternius-armas", "Axe", "Machado", "armas", "machado", alvo=("max", 3.8), **_ARMA, **FERRO),
    _d("quaternius-armas", "Axe_Small", "Machadinha", "armas", "machadinha", alvo=("max", 2.4), **_ARMA, **FERRO),
    _d("quaternius-armas", "Hammer_Small", "Martelo", "armas", "martelo de guerra", alvo=("max", 3.2), **_ARMA, **FERRO),
    _d("quaternius-armas", "Spear", "Lanca", "armas", "lança", alvo=("max", 6.5), **_ARMA, **FERRO),
    _d("quaternius-armas", "Bow_Wooden", "Arco", "armas", "arco (dispara para -Z)", alvo=("z", 4.6), orcamento="arma", pivo="origem", rot=(0, 0, 90), maximo_cores=5, **MADEIRA),
    _d("quaternius-armas", "Bow_Wooden2", "ArcoLongo", "armas", "arco alternativo", alvo=("z", 4.6), orcamento="arma", pivo="origem", rot=(0, 0, 90), maximo_cores=5, **MADEIRA),
    _d("quaternius-armas", "Arrow", "Flecha", "armas", "flecha (ponta para -Z)", alvo=("max", 3.0), orcamento="arma", pivo="centro", rot=(0, 0, 0), maximo_cores=5, **FERRO),
    _d("quaternius-armas", "Shield_Round", "EscudoRedondo", "armas", "escudo redondo (frente para -Z)", alvo=("x", 2.6), orcamento="arma", pivo="origem", rot=(0, 0, 0), maximo_cores=5, **MADEIRA),
    _d("quaternius-armas", "Shield_Heater", "EscudoBrasao", "armas", "escudo de brasão (frente para -Z)", alvo=("x", 2.4), orcamento="arma", pivo="origem", rot=(0, 0, 0), maximo_cores=5, **FERRO),
    # ---------- CRIATURAS (Mini Dungeon) ----------
    _d("mini-dungeon", "character-orc", "Orc", "criaturas", "orc/goblin (estático, sem animação)", orcamento="criatura", alvo=("z", 5.2), **NEUTRO),
    _d("mini-dungeon", "character-human", "Humano", "criaturas", "humano (estático)", orcamento="criatura", alvo=("z", 5.0), **NEUTRO),
]
