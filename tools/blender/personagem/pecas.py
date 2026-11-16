"""PERS3: catálogo das peças em malha exportáveis (módulo do jogo -> gerador, parte do R15).

Dados puros (sem bpy): o spec de catálogo e o exportador leem este arquivo. Cada módulo vira um FBX com a origem no CENTRO
da parte do R15 em que é soldado (offset 0,0,0 no catálogo do jogo), um MeshPart por grupo. Grupos tingíveis pelo jogo:
"Cabelo" (cor de cabelo/pele da criação); "Interno" e "Ferro" mantêm a cor própria.
"""

# módulo -> (chave do gerador em cabelos_racas / roupas, parte do R15)
CABELOS = {
    "CabeloCurto2": ("curto", "Head"), "CabeloMasculino1": ("masculino", "Head"), "CabeloLongo2": ("longo", "Head"),
    "CabeloRabo1": ("rabo", "Head"), "CabeloEspetado1": ("espetado", "Head"), "CabeloTrancas1": ("trancas", "Head"),
    "CabeloCoque1": ("coque", "Head"), "CabeloBob1": ("bob", "Head"),
}
BARBAS = {"BarbaCurta2": ("curta", "Head"), "BarbaCavanhaque1": ("cavanhaque", "Head"), "BarbaAna1": ("longa", "Head")}
RACAS = {"OrelhasElficas2": ("elfo", "Head"), "OrelhasBestiais2": ("fera", "Head")}
ROUPAS = {
    "RoupaCapuz2": ("capuz", "Head"), "RoupaCapaCurta1": ("capa_curta", "UpperTorso"),
    "RoupaCintoBolsa1": ("cinto_bolsa", "LowerTorso"), "RoupaOmbreira1": ("ombreira", "RightUpperArm"),
}
TODAS = {**CABELOS, **BARBAS, **RACAS, **ROUPAS}

# papel de material (comum.py) -> nome do grupo/MeshPart no FBX
GRUPO = {"cabelo": "Cabelo", "barba": "Cabelo", "pele": "Cabelo", "metal": "Ferro", "pele_interna": "Interno"}
ROSTOS = ("neutro", "alegre", "serio")
OLHOS = {"OlhoCastanho": (92, 55, 32), "OlhoAzul": (60, 145, 220), "OlhoVerde": (75, 170, 105), "OlhoVioleta": (150, 90, 210),
         "OlhoVermelho": (195, 60, 55), "OlhoDourado": (220, 175, 50), "OlhoNegro": (25, 25, 30), "OlhoTurquesa": (45, 190, 180)}
