"""Clipes posados por script (ANIM1): poses-chave autorais dos 12 clipes de combate.

Cada clipe: duracao (s), laco, marcos {nome: t}, modos (ver anim_pose.resolver), arma da prévia
("espada", "arco" ou None) e chaves [(t, canais, tensao)]. As chaves de ação começam e terminam na POSTURA, para o
tocador misturar sem salto. Uma chave escrita num modo (ex.: POSTURA com braços em FK) é convertida para o modo do
clipe (`anim_exportar.completar`). Convenções de ângulo em anim_rig.py (graus; Rx+ leva braço/coxa à frente e inclina o
tronco para TRÁS; Ry+ gira a frente para a esquerda; ombro direito Rz+ abre, esquerdo Rz-; cotovelo Rx+ dobra).
Com a pega recomendada, a lâmina sai do punho para -Z da mão: direção da lâmina = direção do braço + 90 graus em X.
"""


def P(base, **kw):
    d = dict(base)
    d.update(kw)
    return d


# Guarda de combate: pé esquerdo à frente, quadril meio virado à direita, joelhos dobrados, espada em guarda média.
POSTURA = {
    "raiz_pos": (0.0, -0.24, 0.05),
    "raiz_rot": (0, -14, 0),
    "cintura": (-6, 10, 0),
    "pescoco": (2, 4, 0),
    "peE": (-0.72, 0.0, -0.55), "peE_rot": (0, 12, 0),
    "peD": (0.78, 0.0, 0.62), "peD_rot": (0, -30, 0),
    "ombroD": (28, 22, 12), "cotoveloD": (62, 0, 0), "pulsoD": (-42, 0, 0),
    "ombroE": (30, -18, -12), "cotoveloE": (72, 0, 0), "pulsoE": (0, 0, 0),
}
POSTURA_RESPIRA = P(POSTURA, raiz_pos=(0.0, -0.28, 0.06), cintura=(-8, 10, 0), ombroD=(30, 22, 13),
                    ombroE=(32, -18, -13), pescoco=(4, 4, 0))

CLIPES = {}

# ------------------------------------------------------------------------------------------------ postura (laço)
CLIPES["PosturaCombate"] = dict(
    duracao=2.0, laco=True, marcos={}, modos={}, arma="espada",
    chaves=[(0.0, POSTURA, 0.0), (1.0, POSTURA_RESPIRA, 0.0), (2.0, POSTURA, 0.0)],
)

# ------------------------------------------------------------------------------------------------ corte leve
CLIPES["CorteLeve"] = dict(
    duracao=1.0, laco=False, marcos={"impacto": 0.40}, modos={}, arma="espada",
    chaves=[
        (0.0, POSTURA, 1.0),
        # preparo: espada atrás do ombro direito, tronco torcido para a direita, peso atrás
        (0.24, P(POSTURA, raiz_pos=(0.05, -0.22, 0.18), raiz_rot=(0, -26, 0), cintura=(2, -24, 4), pescoco=(0, 40, 0),
                 ombroD=(150, 0, 38), cotoveloD=(70, 0, 0), pulsoD=(-10, 0, 0),
                 ombroE=(58, -10, -18), cotoveloE=(32, 0, 0)), 0.5),
        # impacto: braço estendido à frente na altura do peito, lâmina horizontal varrendo para a esquerda
        (0.40, P(POSTURA, raiz_pos=(-0.05, -0.34, -0.34), raiz_rot=(0, 4, 0), cintura=(-8, 14, -2), pescoco=(-2, -16, 0),
                 peD=(0.70, 0.0, 0.40),
                 ombroD=(70, 0, -6), cotoveloD=(6, 0, 0), pulsoD=(-60, 0, 0),
                 ombroE=(24, -10, -30), cotoveloE=(50, 0, 0)), 0.0),
        # seguimento: braço termina baixo à esquerda, por fora do tronco (a torção leva o ombro à frente)
        (0.56, P(POSTURA, raiz_pos=(-0.05, -0.36, -0.38), raiz_rot=(0, 14, 0), cintura=(-12, 28, -4), pescoco=(-4, -34, 0),
                 peD=(0.70, 0.0, 0.40),
                 ombroD=(52, 0, -20), cotoveloD=(8, 0, 0), pulsoD=(-52, 0, 0),
                 ombroE=(14, -10, -40), cotoveloE=(46, 0, 0)), 1.0),
        (1.0, POSTURA, 1.0),
    ],
)

# ------------------------------------------------------------------------------------------------ corte pesado
CLIPES["CortePesado"] = dict(
    duracao=1.45, laco=False, marcos={"impacto": 0.80}, modos={}, arma="espada",
    chaves=[
        (0.0, POSTURA, 1.0),
        # ergue a arma com as duas mãos sobre a cabeça, inclina para trás
        (0.42, P(POSTURA, raiz_pos=(0.0, -0.14, 0.22), raiz_rot=(0, -8, 0), cintura=(14, -6, 0), pescoco=(-8, 8, 0),
                 ombroD=(166, 6, 14), cotoveloD=(58, 0, 0), pulsoD=(-14, 0, 0),
                 ombroE=(160, -6, -12), cotoveloE=(66, 0, 0)), 0.3),
        # segura no alto (antecipação)
        (0.60, P(POSTURA, raiz_pos=(0.0, -0.12, 0.26), raiz_rot=(0, -8, 0), cintura=(18, -6, 0), pescoco=(-10, 8, 0),
                 ombroD=(174, 6, 12), cotoveloD=(62, 0, 0), pulsoD=(-18, 0, 0),
                 ombroE=(168, -6, -10), cotoveloE=(70, 0, 0)), 1.0),
        # impacto: desce em arco à frente, tronco dobrado, joelho da frente cede
        (0.80, P(POSTURA, raiz_pos=(0.0, -0.50, -0.46), raiz_rot=(-4, 0, 0), cintura=(-18, 6, 0), pescoco=(10, 0, 0),
                 ombroD=(56, 14, -8), cotoveloD=(5, 0, 0), pulsoD=(-62, 0, 0),
                 ombroE=(56, -26, 10), cotoveloE=(14, 0, 0), pulsoE=(-20, 0, 0)), 0.0),
        # assenta: a lâmina ainda desce um pouco e para
        (0.96, P(POSTURA, raiz_pos=(0.0, -0.56, -0.48), raiz_rot=(-6, 0, 0), cintura=(-22, 6, 0), pescoco=(12, 0, 0),
                 ombroD=(48, 14, -8), cotoveloD=(8, 0, 0), pulsoD=(-60, 0, 0),
                 ombroE=(44, -26, 10), cotoveloE=(16, 0, 0), pulsoE=(-20, 0, 0)), 1.0),
        (1.45, POSTURA, 1.0),
    ],
)

# ------------------------------------------------------------------------------------------------ estocada
CLIPES["Estocada"] = dict(
    duracao=0.95, laco=False, marcos={"impacto": 0.40}, modos={}, arma="espada",
    chaves=[
        (0.0, POSTURA, 1.0),
        # recolhe: mão junto ao quadril, ponta para a frente, ombro direito para trás
        (0.22, P(POSTURA, raiz_pos=(0.0, -0.30, 0.22), raiz_rot=(0, -22, 0), cintura=(-4, -16, 0), pescoco=(0, 34, 0),
                 ombroD=(12, 10, 18), cotoveloD=(96, 0, 0), pulsoD=(-78, 0, 0),
                 ombroE=(46, -10, -20), cotoveloE=(40, 0, 0)), 0.6),
        (0.30, P(POSTURA, raiz_pos=(0.0, -0.32, -0.15), raiz_rot=(0, -6, 0), cintura=(-8, 4, 0), pescoco=(0, 6, 0),
                 peE=(-0.72, 0.28, -0.95),
                 ombroD=(44, 16, 6), cotoveloD=(60, 0, 0), pulsoD=(-80, 0, 0),
                 ombroE=(30, -10, -28), cotoveloE=(40, 0, 0)), 0.0),
        # impacto: avanço com o pé da frente, braço reto, ombro direito à frente
        (0.40, P(POSTURA, raiz_pos=(0.0, -0.44, -0.66), raiz_rot=(0, 10, 0), cintura=(-12, 22, 0), pescoco=(2, -30, 0),
                 peE=(-0.72, 0.0, -1.22),
                 ombroD=(86, 20, -4), cotoveloD=(2, 0, 0), pulsoD=(-82, 0, 0),
                 ombroE=(10, -10, -40), cotoveloE=(30, 0, 0)), 0.0),
        (0.52, P(POSTURA, raiz_pos=(0.0, -0.46, -0.70), raiz_rot=(0, 12, 0), cintura=(-13, 24, 0), pescoco=(2, -32, 0),
                 peE=(-0.72, 0.0, -1.22),
                 ombroD=(84, 20, -4), cotoveloD=(4, 0, 0), pulsoD=(-80, 0, 0),
                 ombroE=(8, -10, -42), cotoveloE=(30, 0, 0)), 1.0),
        (0.72, P(POSTURA, peE=(-0.72, 0.22, -0.9)), 0.0),
        (0.95, POSTURA, 1.0),
    ],
)

# ------------------------------------------------------------------------------------------------ disparo de arco
# Corpo de lado (ombro esquerdo para o alvo), braço do arco estendido, mão direita puxa a corda até o queixo.
ARQUEIRO = dict(
    raiz_pos=(0.0, -0.16, 0.0), raiz_rot=(0, -62, 0), cintura=(-2, -8, 0), pescoco=(0, 66, 0),
    peE=(-0.25, 0.0, -0.80), peE_rot=(0, -40, 0), peD=(0.35, 0.0, 0.80), peD_rot=(0, -70, 0),
    maoE=(0.70, 0.12, -1.82), poloE=(-0.4, -1.0, 0.2), pulsoE=(0, 0, 0),
)
CLIPES["DisparoArco"] = dict(
    duracao=2.0, laco=False, marcos={"puxar": 0.48, "soltar": 1.22}, arma="arco",
    modos={"bracoE": "ik", "bracoD": "ik", "ref_maoE": "ombroE", "ref_maoD": "mundo"},
    chaves=[
        (0.0, POSTURA, 1.0),
        # vira de lado e ergue o arco; a mão direita encaixa a flecha junto do arco
        (0.34, P(POSTURA, **dict(ARQUEIRO, raiz_rot=(0, -50, 0)), maoD=(1.0, 3.35, -1.3), poloD=(1.0, -0.6, 0.2), pulsoD=(0, 0, 0)), 0.6),
        (0.48, P(POSTURA, **ARQUEIRO, maoD=(0.85, 3.62, -1.45), poloD=(1.0, -0.4, 0.4), pulsoD=(0, 0, 0)), 0.6),
        # puxa até a ancoragem no queixo, cotovelo alto atrás
        (1.00, P(POSTURA, **dict(ARQUEIRO, cintura=(0, -10, 0)), maoD=(0.46, 3.98, 0.02), poloD=(0.5, 0.3, 1.0),
                 pulsoD=(0, 0, 0)), 1.0),
        (1.22, P(POSTURA, **dict(ARQUEIRO, cintura=(0, -10, 0)), maoD=(0.48, 4.0, 0.08), poloD=(0.5, 0.3, 1.0),
                 pulsoD=(0, 0, 0)), 0.0),
        # solta: a mão direita salta para trás, o arco cede um pouco
        (1.34, P(POSTURA, **dict(ARQUEIRO, cintura=(4, -12, 0), maoE=(0.70, 0.02, -1.82)), maoD=(0.95, 4.0, 0.80),
                 poloD=(0.6, 0.0, 1.0), pulsoD=(20, 0, 0)), 0.0),
        (1.60, P(POSTURA, **dict(ARQUEIRO, maoE=(0.70, -0.15, -1.78)), maoD=(1.0, 3.6, 0.70), poloD=(0.6, -0.4, 1.0),
                 pulsoD=(0, 0, 0)), 0.5),
        (1.80, P(POSTURA, **dict(ARQUEIRO, raiz_rot=(0, -34, 0), pescoco=(0, 30, 0), maoE=(0.1, -0.5, -1.5)),
                 maoD=(1.6, 2.7, -0.2), poloD=(1.0, -0.3, 0.6), pulsoD=(0, 0, 0)), 0.3),
        (2.0, POSTURA, 1.0),
    ],
)

# ------------------------------------------------------------------------------------------------ conjurar
CLIPES["Conjurar"] = dict(
    duracao=1.4, laco=False, marcos={"impacto": 0.84}, modos={}, arma=None,
    chaves=[
        (0.0, POSTURA, 1.0),
        # junta as mãos diante do peito
        (0.40, P(POSTURA, raiz_pos=(0.0, -0.22, 0.10), cintura=(4, -8, 0), pescoco=(-4, 8, 0),
                 ombroD=(30, 34, 0), cotoveloD=(104, 0, 0), pulsoD=(10, 0, 0),
                 ombroE=(30, -34, 0), cotoveloE=(104, 0, 0), pulsoE=(10, 0, 0)), 0.3),
        # carrega: mãos recolhidas junto do ombro direito, corpo enrolado
        (0.64, P(POSTURA, raiz_pos=(0.0, -0.30, 0.20), raiz_rot=(0, -20, 0), cintura=(8, -18, 0), pescoco=(-6, 34, 0),
                 ombroD=(30, 20, 22), cotoveloD=(110, 0, 0), pulsoD=(10, 0, 0),
                 ombroE=(38, -50, -4), cotoveloE=(104, 0, 0), pulsoE=(10, 0, 0)), 0.0),
        # impacto: as duas palmas empurram para o alvo
        (0.84, P(POSTURA, raiz_pos=(0.0, -0.38, -0.40), raiz_rot=(0, 2, 0), cintura=(-12, 6, 0), pescoco=(6, -6, 0),
                 ombroD=(86, 12, -4), cotoveloD=(6, 0, 0), pulsoD=(62, 0, 0),
                 ombroE=(86, -12, 4), cotoveloE=(6, 0, 0), pulsoE=(62, 0, 0)), 0.0),
        (1.02, P(POSTURA, raiz_pos=(0.0, -0.36, -0.36), raiz_rot=(0, 2, 0), cintura=(-10, 6, 0), pescoco=(6, -6, 0),
                 ombroD=(82, 12, -2), cotoveloD=(12, 0, 0), pulsoD=(54, 0, 0),
                 ombroE=(82, -12, 2), cotoveloE=(12, 0, 0), pulsoE=(54, 0, 0)), 1.0),
        (1.4, POSTURA, 1.0),
    ],
)

# ------------------------------------------------------------------------------------------------ canalizar (laço)
CANAL = P(POSTURA, raiz_pos=(0.0, -0.20, 0.0), raiz_rot=(0, -6, 0), cintura=(-4, 6, 0), pescoco=(4, 0, 0),
          ombroD=(70, 16, 6), cotoveloD=(30, 0, 0), pulsoD=(56, 0, 0),
          ombroE=(70, -16, -6), cotoveloE=(30, 0, 0), pulsoE=(56, 0, 0))
CLIPES["Canalizar"] = dict(
    duracao=1.6, laco=True, marcos={}, modos={}, arma=None,
    chaves=[
        (0.0, CANAL, 0.0),
        (0.8, P(CANAL, raiz_pos=(0.0, -0.26, 0.02), cintura=(-6, 2, 2), ombroD=(76, 16, 4), ombroE=(64, -16, -8),
                pulsoD=(50, 0, 0), pulsoE=(62, 0, 0)), 0.0),
        (1.6, CANAL, 0.0),
    ],
)

# ------------------------------------------------------------------------------------------------ reação a golpe
CLIPES["ReacaoGolpe"] = dict(
    duracao=0.75, laco=False, marcos={"impacto": 0.0}, modos={}, arma="espada",
    chaves=[
        (0.0, POSTURA, 0.0),
        # o golpe joga o corpo para trás: quadril recua, tronco e cabeça vão para trás, braços abrem
        (0.09, P(POSTURA, raiz_pos=(0.0, -0.30, 0.38), raiz_rot=(8, -6, 0), cintura=(18, 2, 6), pescoco=(20, 12, 0),
                 ombroD=(46, 10, 34), cotoveloD=(40, 0, 0), ombroE=(42, -10, -32), cotoveloE=(46, 0, 0)), 0.0),
        # recupera curvado para a frente (o corpo "absorve")
        (0.28, P(POSTURA, raiz_pos=(0.0, -0.34, 0.20), raiz_rot=(-4, -10, 0), cintura=(-16, 8, -2), pescoco=(-4, 6, 0),
                 ombroD=(24, 22, 16), cotoveloD=(70, 0, 0), ombroE=(26, -18, -16), cotoveloE=(80, 0, 0)), 0.4),
        (0.75, POSTURA, 1.0),
    ],
)

# ------------------------------------------------------------------------------------------------ esquiva
CLIPES["Esquiva"] = dict(
    duracao=0.8, laco=False, marcos={"desvio": 0.18}, modos={}, arma="espada",
    chaves=[
        (0.0, POSTURA, 1.0),
        # tomba para a esquerda e para trás, abaixando a cabeça; a perna direita estica
        (0.18, P(POSTURA, raiz_pos=(-0.70, -0.58, 0.28), raiz_rot=(4, -14, 16), cintura=(4, 14, 24), pescoco=(-6, 0, -12),
                 peE=(-1.05, 0.0, -0.45),
                 ombroD=(30, 30, 34), cotoveloD=(70, 0, 0), ombroE=(40, -26, -40), cotoveloE=(64, 0, 0)), 0.3),
        (0.36, P(POSTURA, raiz_pos=(-0.66, -0.56, 0.26), raiz_rot=(4, -14, 14), cintura=(4, 14, 21), pescoco=(-4, 0, -10),
                 peE=(-1.05, 0.0, -0.45),
                 ombroD=(30, 30, 32), cotoveloD=(72, 0, 0), ombroE=(38, -26, -36), cotoveloE=(64, 0, 0)), 0.5),
        (0.8, POSTURA, 1.0),
    ],
)

# ------------------------------------------------------------------------------------------------ bloqueio
GUARDA_ALTA = P(POSTURA, raiz_pos=(0.0, -0.36, 0.10), raiz_rot=(0, -10, 0), cintura=(-2, 8, 0), pescoco=(-4, 2, 0),
                ombroD=(80, 16, 12), cotoveloD=(84, 0, 0), pulsoD=(0, 90, 0),
                ombroE=(76, -16, -12), cotoveloE=(84, 0, 0))
CLIPES["Bloqueio"] = dict(
    duracao=0.85, laco=False, marcos={"impacto": 0.24}, modos={}, arma="espada",
    chaves=[
        (0.0, POSTURA, 1.0),
        (0.16, GUARDA_ALTA, 0.6),
        (0.24, GUARDA_ALTA, 0.0),
        # o choque empurra a guarda e o corpo um pouco para trás
        (0.32, P(GUARDA_ALTA, raiz_pos=(0.0, -0.44, 0.28), cintura=(6, 8, 0), ombroD=(74, 16, 12), ombroE=(70, -16, -12)), 0.2),
        (0.52, GUARDA_ALTA, 0.6),
        (0.85, POSTURA, 1.0),
    ],
)

# ------------------------------------------------------------------------------------------------ queda (termina caído)
CLIPES["Queda"] = dict(
    duracao=1.35, laco=False, segurar=True, marcos={"chao": 0.74}, modos={"pernas": "fk"}, arma="espada",
    chaves=[
        (0.0, POSTURA, 1.0),
        # os joelhos cedem, o tronco vai para trás, os braços abrem
        (0.16, P(POSTURA, raiz_pos=(0.0, -0.36, 0.30), raiz_rot=(10, -8, 0), cintura=(14, 0, 0), pescoco=(10, 0, 0),
                 quadrilD=(48, 0, 6), joelhoD=(-58, 0, 0), tornozeloD=(0, 0, 0),
                 quadrilE=(54, 0, -6), joelhoE=(-64, 0, 0), tornozeloE=(0, 0, 0),
                 ombroD=(50, 0, 40), cotoveloD=(30, 0, 0), ombroE=(50, 0, -40), cotoveloE=(30, 0, 0)), 0.2),
        # senta
        (0.46, P(POSTURA, raiz_pos=(0.0, -1.42, 0.80), raiz_rot=(24, 0, 0), cintura=(12, 0, 0), pescoco=(-6, 0, 0),
                 quadrilD=(106, 0, 10), joelhoD=(-100, 0, 0), tornozeloD=(-30, 0, 0),
                 quadrilE=(112, 0, -10), joelhoE=(-106, 0, 0), tornozeloE=(-30, 0, 0),
                 ombroD=(-26, 0, 36), cotoveloD=(20, 0, 0), ombroE=(-26, 0, -36), cotoveloE=(20, 0, 0)), 0.0),
        # as costas batem no chão
        (0.74, P(POSTURA, raiz_pos=(0.0, -1.66, 1.30), raiz_rot=(80, 0, 0), cintura=(4, 0, 0), pescoco=(-14, 0, 0),
                 quadrilD=(44, 0, 8), joelhoD=(-60, 0, 0), tornozeloD=(-34, 0, 0),
                 quadrilE=(52, 0, -8), joelhoE=(-66, 0, 0), tornozeloE=(-34, 0, 0),
                 ombroD=(10, 0, 60), cotoveloD=(20, 0, 0), ombroE=(10, 0, -60), cotoveloE=(20, 0, 0)), 0.0),
        # quica e assenta
        (0.90, P(POSTURA, raiz_pos=(0.0, -1.60, 1.36), raiz_rot=(84, 0, 0), cintura=(-4, 0, 0), pescoco=(-20, 0, 0),
                 quadrilD=(22, 0, 8), joelhoD=(-30, 0, 0), tornozeloD=(6, 0, 0),
                 quadrilE=(30, 0, -8), joelhoE=(-36, 0, 0), tornozeloE=(6, 0, 0),
                 ombroD=(0, 0, 70), cotoveloD=(14, 0, 0), pulsoD=(-70, 0, 0), ombroE=(0, 0, -70), cotoveloE=(14, 0, 0)), 0.2),
        (1.35, P(POSTURA, raiz_pos=(0.0, -1.70, 1.38), raiz_rot=(88, 0, 0), cintura=(0, 0, 0), pescoco=(0, 24, 0),
                 quadrilD=(8, 0, 8), joelhoD=(-12, 0, 0), tornozeloD=(0, 0, 0),
                 quadrilE=(14, 0, -10), joelhoE=(-20, 0, 0), tornozeloE=(0, 0, 0),
                 ombroD=(-4, 0, 74), cotoveloD=(10, 0, 0), pulsoD=(-80, 0, 0), ombroE=(-4, 0, -74), cotoveloE=(10, 0, 0)), 1.0),
    ],
)

# ------------------------------------------------------------------------------------------------ vitória (termina na pose)
VITORIA = dict(
    raiz_pos=(0.0, -0.06, 0.0), raiz_rot=(0, -6, 0), cintura=(8, -8, 0), pescoco=(10, 12, 0),
    peE=(-0.80, 0.0, -0.20), peE_rot=(0, 16, 0), peD=(0.85, 0.0, 0.25), peD_rot=(0, -20, 0),
    ombroD=(150, 0, 18), cotoveloD=(5, 0, 0), pulsoD=(-62, 0, 0),
    ombroE=(-6, -80, -36), cotoveloE=(84, 0, 0), pulsoE=(0, 0, 0),
)
CLIPES["Vitoria"] = dict(
    duracao=1.6, laco=False, segurar=True, marcos={}, modos={}, arma="espada",
    chaves=[
        (0.0, POSTURA, 1.0),
        # abaixa antes de erguer
        (0.20, P(POSTURA, raiz_pos=(0.0, -0.36, 0.05), cintura=(-14, 10, 0), ombroD=(20, 22, 20), cotoveloD=(80, 0, 0)), 0.3),
        (0.52, P(POSTURA, **dict(VITORIA, raiz_pos=(0.0, -0.02, 0.0), ombroD=(160, 0, 14))), 0.0),
        (0.80, P(POSTURA, **VITORIA), 0.5),
        (1.6, P(POSTURA, **dict(VITORIA, raiz_pos=(0.0, -0.08, 0.0), cintura=(6, -8, 0))), 1.0),
    ],
)
