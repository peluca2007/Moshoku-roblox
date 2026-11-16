-- IMP1: câmera da luta que acompanha o golpe. A Coreografia chama `golpe` ao começar a cena (já sabe o instante
-- do contato); o BoardView passa a câmera calculada por `aplicar` antes do tremor. O peso (ImpactoCurvas.peso)
-- sobe na antecipação, segura no contato e volta ao enquadramento normal. Um raycast do ponto de olhar até a
-- câmera impede de entrar na parede (arena fechada). Só apresentação: não mexe em regra nem em rede.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Curvas = require(Shared.ImpactoCurvas)
local FX = require(script.Parent.MenuEfeitos)

local M = {}
local atual: { de: Vector3, para: Vector3, inicio: number, impacto: number, lado: number }? = nil
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true
local MARGEM = 1.2

-- de/para: pontos no mundo (atacante e alvo); impacto: segundos até o contato.
function M.golpe(de: Vector3, para: Vector3, impacto: number)
	if FX.reduzidos then return end
	atual = { de = de, para = para, inicio = os.clock(), impacto = math.max(impacto, 0.1), lado = 0 }
end

function M.limpar()
	atual = nil
end

function M.peso(): number
	if not atual then return 0 end
	local t = os.clock() - atual.inicio
	if t > Curvas.duracaoTotal(atual.impacto) then
		atual = nil
		return 0
	end
	return Curvas.peso(t, atual.impacto)
end

local function atualizarFiltro()
	local lista = {}
	for _, nome in { "Mesa", "CorposDeCriatura", "MesaEfeitosLocais" } do
		local o = workspace:FindFirstChild(nome)
		if o then table.insert(lista, o) end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then table.insert(lista, p.Character) end
	end
	params.FilterDescendantsInstances = lista
end

-- Tira a câmera de dentro de paredes: se algo bloqueia o caminho do olhar até `pos`, para antes.
function M.semParede(olhar: Vector3, pos: Vector3): Vector3
	local d = pos - olhar
	if d.Magnitude < 1e-3 then return pos end
	atualizarFiltro()
	local r = workspace:Raycast(olhar, d, params)
	if r then
		local dist = math.max((r.Position - olhar).Magnitude - MARGEM, 1.5)
		return olhar + d.Unit * math.min(dist, d.Magnitude)
	end
	return pos
end

-- `cf`: câmera de luta já calculada. Devolve a câmera com o enquadramento do golpe misturado.
function M.aplicar(cf: CFrame): CFrame
	local g = atual
	if not g then return cf end
	local w = M.peso() * Curvas.FORCA
	if w <= 0.001 then return cf end
	if g.lado == 0 then
		-- escolhe uma vez o lado da perpendicular em que a câmera já está (sem virar de repente)
		local f = g.para - g.de
		local perp = Vector3.new(-f.Z, 0, f.X)
		g.lado = if (cf.Position - (g.de + g.para) / 2):Dot(perp) >= 0 then 1 else -1
	end
	local pos, olhar = Curvas.enquadre(
		{ x = g.de.X, y = g.de.Y, z = g.de.Z }, { x = g.para.X, y = g.para.Y, z = g.para.Z }, g.lado)
	local p, o = Vector3.new(pos.x, pos.y, pos.z), Vector3.new(olhar.x, olhar.y, olhar.z)
	local alvo = CFrame.lookAt(p, o)
	local misto = cf:Lerp(alvo, w)
	local livre = M.semParede(o, misto.Position)
	if livre ~= misto.Position then
		misto = CFrame.lookAt(livre, o:Lerp(misto.Position + misto.LookVector * 10, 0.5))
	end
	return misto
end

return M
