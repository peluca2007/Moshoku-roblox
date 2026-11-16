-- IMP1: câmera da luta que acompanha o golpe. A Coreografia chama `golpe` ao começar a cena (já sabe o instante
-- do contato); o BoardView passa a câmera calculada por `aplicar` antes do tremor. O peso (ImpactoCurvas.peso)
-- sobe na antecipação, segura no contato e volta ao enquadramento normal. Um raycast do ponto de olhar até a
-- câmera impede de entrar na parede (arena fechada). Só apresentação: não mexe em regra nem em rede.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Curvas = require(Shared.ImpactoCurvas)
local Protocol = require(Shared.MesaProtocol)
local FX = require(script.Parent.MenuEfeitos)

local M = {}
local atual: { de: Vector3, para: Vector3, inicio: number, impacto: number, escolha: any, folga: number? }? = nil
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true
local MARGEM = 1.2
-- As paredes do esgoto têm CanQuery=false (não entram no raycast): a sala é tratada como uma caixa em volta do
-- tabuleiro (ImpactoCurvas.fracaoDentro). O raycast continua valendo para peças consultáveis de outras arenas.
local function caixa()
	local b = Protocol.BOARD
	return { x = b.origin.X, z = b.origin.Z, meia = b.width * b.cell / 2 + Curvas.SALA_MARGEM, teto = b.origin.Y + Curvas.SALA_TETO }
end
local function pt(v: Vector3) return { x = v.X, y = v.Y, z = v.Z } end

-- de/para: pontos no mundo (atacante e alvo); impacto: segundos até o contato.
function M.golpe(de: Vector3, para: Vector3, impacto: number)
	if FX.reduzidos then return end
	atual = { de = de, para = para, inicio = os.clock(), impacto = math.max(impacto, 0.1) }
end

-- Só para a QA: o golpe atual (com a escolha de enquadramento e a folga do raycast).
function M.estado()
	return atual
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
		d = d.Unit * math.min(dist, d.Magnitude)
	end
	return olhar + d * Curvas.fracaoDentro(pt(olhar), pt(olhar + d), caixa())
end

-- Escolhe, uma vez por golpe, o primeiro enquadramento 3/4 (ImpactoCurvas.CANDIDATOS) cuja linha do olhar
-- até a câmera está livre; se nenhum está, o de maior folga. Assim a câmera troca de lado ou encurta antes de
-- esbarrar na parede, em vez de colar nos lutadores.
local function escolher(g, cf: CFrame)
	local f = g.para - g.de
	local perp = Vector3.new(-f.Z, 0, f.X)
	local lado = if (cf.Position - (g.de + g.para) / 2):Dot(perp) >= 0 then 1 else -1
	local melhor, folga = Curvas.CANDIDATOS[1], -1
	atualizarFiltro()
	for _, c in Curvas.CANDIDATOS do
		local pos, olhar = Curvas.enquadre(
			{ x = g.de.X, y = g.de.Y, z = g.de.Z }, { x = g.para.X, y = g.para.Y, z = g.para.Z }, lado * c[1], c[2], c[3])
		local p, o = Vector3.new(pos.x, pos.y, pos.z), Vector3.new(olhar.x, olhar.y, olhar.z)
		local r = workspace:Raycast(o, p - o, params)
		local livre = math.min(if r then (r.Position - o).Magnitude / math.max((p - o).Magnitude, 1e-3) else 1,
			Curvas.fracaoDentro(olhar, pos, caixa()))
		if livre > folga + 1e-6 then melhor, folga = { lado * c[1], c[2], c[3] }, livre end
		if livre >= 1 then break end
	end
	g.escolha, g.folga = melhor, folga
end
M.escolher = escolher

-- `cf`: câmera de luta já calculada. Devolve a câmera com o enquadramento do golpe misturado.
function M.aplicar(cf: CFrame): CFrame
	local g = atual
	if not g then return cf end
	local w = M.peso() * Curvas.FORCA
	if w <= 0.001 then return cf end
	if not g.escolha then escolher(g, cf) end
	local c = g.escolha
	local pos, olhar = Curvas.enquadre(
		{ x = g.de.X, y = g.de.Y, z = g.de.Z }, { x = g.para.X, y = g.para.Y, z = g.para.Z }, c[1], c[2], c[3])
	local p, o = Vector3.new(pos.x, pos.y, pos.z), Vector3.new(olhar.x, olhar.y, olhar.z)
	local misto = cf:Lerp(CFrame.lookAt(p, o), w)
	local livre = M.semParede(o, misto.Position)
	if livre ~= misto.Position then
		misto = CFrame.lookAt(livre, o)
	end
	return misto
end

return M
