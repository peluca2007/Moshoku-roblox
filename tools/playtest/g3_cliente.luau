local p = game.Players.LocalPlayer
local R = { linhas = {}, falhas = 0, pedidos = 0, disparos = 0 }
shared.G3 = R
function R.check(nome, ok)
	table.insert(R.linhas, (if ok then "OK " else "FALHA ") .. nome)
	if not ok then R.falhas += 1 end
end
local me = {
	id = "g3", name = "Teste das ações", ownerUserId = p.UserId, kind = "jogador", pv = 30, pvMax = 30,
	mana = 10, manaMax = 10, pt = 4, ptMax = 4,
	habilidades = { "mesa/ataque-basico", "mesa/ataque-a-distancia", "mesa/esconder", "mesa/insulto", "mesa/dissonancia",
		"mesa/marcha", "mesa/parar-cancao", "mesa/apontar",
		"ability/terra/Principiante/lanca-de-pedra", "ability/deus-da-espada/Principiante/sem-recuo" },
}
local snap = { tokens = { me }, combat = { active = true, turn = 1, turnId = me.id },
	jogo = { acoes = { tokenId = me.id, total = 3, usadas = 0, usos = {} } } }
local callbacks, miras, mira = {}, {}, nil
local state = {
	snapshot = function() return snap end, findToken = function(id) return if id == me.id then me else nil end,
	canControl = function() return true end, onSnapshot = function(f) table.insert(callbacks, f) end,
	onMira = function(f) table.insert(miras, f) end, mira = function() return mira end,
	setMira = function(m) mira = m; for _, f in miras do f() end end,
	send = function() R.pedidos += 1 end,
}
state.dispararMira = function()
	R.disparos += 1; R.ultimaMira = mira; state.setMira(nil)
end
function R.atualizar() for _, f in callbacks do f(snap) end; task.wait(.3) end
local menu = p.PlayerGui.InicioJogo.MenuInicial
R.menu, R.menuAnterior = menu, menu.Visible; menu.Visible = false
R.gui = require(p.PlayerScripts.Client.AcoesDoTurno).start(state); R.gui.Name = "G3BarraTeste"
R.state, R.snap, R.me = state, snap, me
task.wait(.4)
R.check("confirmacao oculta sem mira", not R.gui.Barra.Controles.ConfirmarAcao.Visible)
R.check("consulta nao abre sozinha", not R.gui.DetalheAcao.Visible)
return "G3 pronto"
