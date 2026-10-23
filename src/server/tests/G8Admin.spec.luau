-- SOMENTE STUDIO: papéis e diversão do ADM com avatares falsos fora do workspace.
local Roles = require(script.Parent.Parent.MesaRoles)
local Admin = require(script.Parent.Parent.AdminService)
local ADM = 2287856135

local function avatar(nome, ancorado)
	local m = Instance.new("Model")
	m.Name = nome
	local raiz = Instance.new("Part")
	raiz.Name, raiz.Size, raiz.Anchored, raiz.CFrame = "HumanoidRootPart", Vector3.new(2, 2, 1), ancorado, CFrame.new(0, 3, 0)
	raiz.Parent = m
	local cabeca = Instance.new("Part")
	cabeca.Name, cabeca.Size, cabeca.Anchored, cabeca.CFrame = "Head", Vector3.new(1, 1, 1), ancorado, CFrame.new(0, 4.5, 0)
	cabeca.Parent = m
	local h = Instance.new("Humanoid")
	h.HipHeight, h.Parent = 2, m
	m.PrimaryPart = raiz
	return m
end
local function fixture(secretos)
	local respostas, modos = {}, {}
	local a = { UserId = 1, Name = "Ana", DisplayName = "Ana", Character = avatar("Ana", true) }
	local b = { UserId = 2, Name = "Beto", DisplayName = "Beto", Character = avatar("Beto", false) }
	local api = Admin.start({ tokens = {}, combat = { active = true }, isAdmin = function(p) return p == a end,
		agora = (function() local n = 0; return function() n += 2; return n end end)(),
		remote = { FireClient = function(_, _, r) table.insert(respostas, r.texto) end },
		jogadores = function() return { a, b } end,
		avatarSecreto = function(p) return secretos and secretos[p.UserId] == true end,
		definirModoJogador = function(p, ativo) modos[p.UserId] = ativo end })
	return api, a, b, respostas, modos
end
local function tem(char, nome) return char:FindFirstChild(nome, true) ~= nil end

return {
	["G8 sem mestre por padrão; ADM continua ADM e escolhe o papel"] = function(t)
		local antes = workspace:GetAttribute("MoshokuTesteMestre")
		workspace:SetAttribute("MoshokuTesteMestre", nil)
		local p = { UserId = ADM }
		t.ok(Roles.modoJogador(p)); t.eq(Roles.isMaster(p), false); t.ok(Roles.isAdmin(p))
		Roles.definirModoJogador(p, false); t.ok(Roles.isMaster(p)); t.ok(Roles.isAdmin(p))
		Roles.definirModoJogador(p, true); t.eq(Roles.isMaster(p), false)
		Roles.removed(p)
		local comum = { UserId = 77 }
		workspace:SetAttribute("MoshokuTesteMestre", true); t.eq(Roles.modoJogador(comum), false)
		workspace:SetAttribute("MoshokuTesteMestre", nil); t.ok(Roles.modoJogador(comum))
		workspace:SetAttribute("MoshokuTesteMestre", antes)
	end,
	["G8 /adm jogador e mestre chegam ao serviço; não ADM não troca"] = function(t)
		local api, a, b, _, modos = fixture()
		t.eq(api.executar(a, "/adm mestre"), nil); t.eq(modos[1], false)
		t.eq(api.executar(a, { comando = "jogador" }), nil); t.eq(modos[1], true)
		t.ok(api.executar(b, "/adm mestre") ~= nil); t.eq(modos[2], nil)
	end,
	["G8 diversão em combate: alvo por nome, todos e limpeza por normal"] = function(t)
		local api, a, b = fixture()
		t.eq(api.executar(a, "/adm coroa beto"), nil); t.ok(tem(b.Character, "AdminCoroa")); t.eq(tem(a.Character, "AdminCoroa"), false)
		t.eq(api.executar(a, "/adm brilho todos"), nil); t.ok(tem(a.Character, "AdminBrilho")); t.ok(tem(b.Character, "AdminBrilho"))
		t.eq(tem(b.Character, "AdminCoroa"), false, "novo efeito substitui o anterior")
		t.eq(api.executar(a, "/adm normal todos"), nil); t.eq(tem(a.Character, "AdminBrilho"), false); t.eq(tem(b.Character, "AdminBrilho"), false)
		t.ok(api.executar(a, "/adm raio ninguem") ~= nil)
	end,
	["G8 gigante e mini voltam ao tamanho e à altura com avatar ancorado"] = function(t)
		local api, a = fixture()
		local raiz = a.Character.HumanoidRootPart
		local y = raiz.Position.Y
		t.eq(api.executar(a, "/adm gigante"), nil); t.ok(a.Character:GetScale() > 1.9)
		t.eq(api.executar(a, "/adm mini"), nil); t.ok(math.abs(a.Character:GetScale() - 0.5) < 1e-3)
		t.eq(api.executar(a, "/adm normal"), nil); t.ok(math.abs(a.Character:GetScale() - 1) < 1e-3)
		t.ok(math.abs(raiz.Position.Y - y) < 0.05, string.format("altura %.2f → %.2f", y, raiz.Position.Y))
	end,
	["G8 fantasma restaura transparência"] = function(t)
		local api, a = fixture()
		local cabeca = a.Character.Head
		t.eq(api.executar(a, "/adm fantasma"), nil); t.ok(cabeca.Transparency > 0.5)
		t.eq(api.executar(a, "/adm normal"), nil); t.eq(cabeca.Transparency, 0)
	end,
	["G8 furtivo não recebe efeito: alvo único avisa, todos pula em silêncio"] = function(t)
		local api, a, b, respostas = fixture({ [2] = true })
		t.ok(api.executar(a, "/adm coroa beto") ~= nil); t.eq(tem(b.Character, "AdminCoroa"), false)
		t.eq(api.executar(a, "/adm coroa todos"), nil); t.ok(tem(a.Character, "AdminCoroa")); t.eq(tem(b.Character, "AdminCoroa"), false)
		t.ok(string.find(respostas[#respostas], "1 avatar", 1, true) ~= nil)
		api.executar(a, "/adm normal todos")
	end,
}
