local p = game.Players.LocalPlayer
local C = p.PlayerScripts.Client
local A = require(game.ReplicatedStorage.Shared.ApresentacaoAcoes)
local R = { linhas = {}, falhas = 0, pronto = false }
shared.G1 = R
local function check(n, b)
	table.insert(R.linhas, (if b then "OK " else "FALHA ") .. n)
	if not b then R.falhas += 1 end
end
R.check = check
local me = { id = "g1", name = "Ignis", habilidades = { "mesa/ataque-basico", "ability/fogo/Principiante/brasa", "mesa/esconder" },
	pv = 30, pvMax = 30, mana = 3, manaMax = 8, pt = 2, ptMax = 2, ownerUserId = p.UserId, x = 8, z = 10 }
local snap = { combat = { active = true, turn = 1, turnId = "g1" }, tokens = { me },
	jogo = { acoes = { tokenId = "g1", usadas = 0, total = 3, usos = {} } } }
local callbacks, miraCallbacks = {}, {}
local mira
local state = {
	snapshot = function() return snap end, findToken = function(id) return if id == "g1" then me else nil end,
	localUserId = function() return p.UserId end, canControl = function() return true end,
	onSnapshot = function(f) table.insert(callbacks, f) end, onMira = function(f) table.insert(miraCallbacks, f) end,
	mira = function() return mira end,
	setMira = function(m) mira = m; for _, f in miraCallbacks do f() end end,
	send = function(c, payload) R.ultimoPedido = { c, payload } end,
	dispararMira = function() R.disparou = true end,
	onEfeito = function(f) R.efeito = f end, onEncontro = function(f) R.encontro = f end,
}
local menu = p.PlayerGui.InicioJogo.MenuInicial
R.menuAnterior = menu.Visible; menu.Visible = false
local barraGui = require(C.AcoesDoTurno).start(state); barraGui.Name = "G1BarraTeste"
local ritmo = require(C.RitmoCombate).start(state); ritmo.Name = "G1RitmoTeste"
R.barraGui, R.ritmo, R.me, R.snap, R.state = barraGui, ritmo, me, snap, state
function R.atualizar() for _, f in callbacks do f(snap) end end
R.atualizar()
check("golpes visiveis na abertura", barraGui.Barra.Cartas:FindFirstChild("Carta_mesa/ataque-basico").Visible)
check("apoio fora da lista de golpes", not barraGui.Barra.Cartas:FindFirstChild("Carta_mesa/esconder").Visible)
check("sua vez anunciada", ritmo.Faixa.Visible and ritmo.Faixa.Titulo.Text == "SUA VEZ")
snap.jogo.acoes.usadas = 3; R.atualizar()
check("motivo da carta visivel", barraGui.Barra.Cartas:FindFirstChild("Carta_mesa/ataque-basico").Resumo.Text == "Sem Ações")
check("fim de turno destacado", barraGui.Barra.Controles.EncerrarTurno.Text == "Pronto • Encerrar turno")
snap.jogo.acoes.usadas = 0; R.atualizar()
R.efeito({ habilidadeId = "mesa/ataque-basico", casterId = "g1", alvos = { { id = "g1", dano = 12, critico = true } } })
check("critico vem do recibo", ritmo.Faixa.Dica.Text == "CRÍTICO • 12 de dano")
return "G1 cliente preparado para cliques reais"
