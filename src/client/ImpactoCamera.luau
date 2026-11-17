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
local atual: { de: Vector3, para: Vector3, inicio: number, impacto: number, esc: number, opc: { escala: number?, altura: number?, orbita: number?, dolly: number? }?, escolha: any, folga: number? }? = nil
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
-- A caixa só vale quando a dupla está dentro da sala (o tabuleiro); palcos de QA e arenas fora dele não são limitados.
local function fracaoNaSala(olhar, pos)
	local c = caixa()
	if math.abs(olhar.x - c.x) > c.meia + 6 or math.abs(olhar.z - c.z) > c.meia + 6 then return 1 end
	return Curvas.fracaoDentro(olhar, pos, c)
end

-- de/para: pontos no mundo (atacante e alvo); impacto: segundos até o contato.
-- opc (assinaturas): { escala = <1 aproxima, altura = ponto de olhar acima do meio da dupla, orbita = rad que a câmera gira em volta
-- da dupla ao longo do golpe, dolly = fração extra de distância no começo que some até o contato (aproximação lenta) }
function M.golpe(de: Vector3, para: Vector3, impacto: number, opc: { escala: number?, altura: number?, orbita: number?, dolly: number? }?)
	workspace:SetAttribute("ImpactoGolpeChamado", os.clock()) -- QA: prova que a Coreografia chamou
	if FX.reduzidos then return end
	atual = { de = de, para = para, inicio = os.clock(), impacto = math.max(impacto, 0.1), opc = opc,
		esc = math.max(tonumber(workspace:GetAttribute("EscalaDeTempoDasCenas")) or 1, 1) } -- esc: câmera lenta forçada (só QA) dilata tudo
end

-- REA2: câmera presa num ponto móvel (ex.: a arma caindo): `posicao()` devolve o ponto no mundo (nil = mantém o último).
-- Aproxima em ~0,15 s, segura até `dur` e solta em ~0,3 s; mistura com a câmera da luta (que continua calculando).
local foco: { inicio: number, dur: number, posicao: () -> Vector3?, ultimo: Vector3, esc: number, dist: number, altura: number }? = nil
function M.foco(inicial: Vector3, dur: number, posicao: () -> Vector3?, opc: { dist: number?, altura: number? }?)
	if FX.reduzidos then return end
	foco = { inicio = os.clock(), dur = dur, posicao = posicao, ultimo = inicial, dist = (opc and opc.dist) or 3.6, altura = (opc and opc.altura) or 5,
		esc = math.max(tonumber(workspace:GetAttribute("EscalaDeTempoDasCenas")) or 1, 1) }
	workspace:SetAttribute("ImpactoFocoEm", os.clock()) -- QA
end
local function aplicarFoco(cf: CFrame): CFrame?
	local f = foco
	if not f then return nil end
	local t = (os.clock() - f.inicio) / f.esc
	if t >= f.dur then foco = nil return nil end
	local p = f.posicao()
	if p then f.ultimo = p end
	local alvo = f.ultimo
	local w = Curvas.suave(math.min(t / 0.15, 1)) * Curvas.suave(math.min((f.dur - t) / 0.3, 1))
	local fora = Vector3.new(cf.Position.X - alvo.X, 0, cf.Position.Z - alvo.Z)
	fora = if fora.Magnitude > 0.1 then fora.Unit else Vector3.zAxis
	fora = CFrame.Angles(0, math.rad(65), 0):VectorToWorldSpace(fora) -- de lado: a câmera da luta fica atrás do atacante, que taparia a arma
	local pos = alvo + fora * f.dist + Vector3.new(0, f.altura, 0) -- de cima e perto: nenhum corpo fica entre a câmera e a arma
	local mira = alvo - Vector3.new(0, 0.3, 0)
	pos = M.semParede(mira, pos)
	return cf:Lerp(CFrame.lookAt(pos, mira), w)
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
	local t = (os.clock() - atual.inicio) / atual.esc
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
	return olhar + d * fracaoNaSala(pt(olhar), pt(olhar + d))
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
			{ x = g.de.X, y = g.de.Y, z = g.de.Z }, { x = g.para.X, y = g.para.Y, z = g.para.Z }, lado * c[1], c[2], c[3] * (if g.opc and g.opc.escala then g.opc.escala else 1), if g.opc then g.opc.altura else nil)
		local p, o = Vector3.new(pos.x, pos.y, pos.z), Vector3.new(olhar.x, olhar.y, olhar.z)
		local r = workspace:Raycast(o, p - o, params)
		local livre = math.min(if r then (r.Position - o).Magnitude / math.max((p - o).Magnitude, 1e-3) else 1,
			fracaoNaSala(olhar, pos))
		if livre > folga + 1e-6 then melhor, folga = { lado * c[1], c[2], c[3] }, livre end
		if livre >= 1 then break end
	end
	g.escolha, g.folga = melhor, folga
end
M.escolher = escolher

-- Oclusão (IMP6): o corpo de um lutador não pode ficar entre a câmera e a dupla. Raycast só contra os lutadores
-- (criaturas e personagens); tenta girar a câmera em volta do meio da dupla (e subir) até as duas linhas ficarem livres.
local pOclusao = RaycastParams.new()
pOclusao.FilterType = Enum.RaycastFilterType.Include
local function lutadores(): { Instance }
	local lista = {}
	local c = workspace:FindFirstChild("CorposDeCriatura")
	if c then for _, m in c:GetChildren() do table.insert(lista, m) end end
	for _, p in Players:GetPlayers() do if p.Character then table.insert(lista, p.Character) end end
	return lista
end
local function ocluido(pos: Vector3, ponto: Vector3): boolean
	local d = ponto - pos
	local r = workspace:Raycast(pos, d, pOclusao)
	return r ~= nil and (r.Position - ponto).Magnitude > 2.4
end
local function dentroDeLutador(pos: Vector3): boolean
	for _, m in pOclusao.FilterDescendantsInstances do
		if m:IsA("Model") then
			local cf, tam = m:GetBoundingBox()
			local l = cf:PointToObjectSpace(pos)
			if math.abs(l.X) < tam.X / 2 + 0.8 and math.abs(l.Y) < tam.Y / 2 + 0.8 and math.abs(l.Z) < tam.Z / 2 + 0.8 then return true end
		end
	end
	return false
end
function M.desocluir(cf: CFrame, a: Vector3, b: Vector3): CFrame
	pOclusao.FilterDescendantsInstances = lutadores()
	local pos = cf.Position
	local function ruim(p: Vector3): boolean
		return dentroDeLutador(p) or ocluido(p, a) or ocluido(p, b)
	end
	if not ruim(pos) then return cf end
	local meio = (a + b) / 2
	local rel = pos - meio
	for _, ang in { 0.4, -0.4, 0.8, -0.8, 1.2, -1.2, 1.7, -1.7 } do
		for _, sobe in { 0, 2.5 } do
			local c, s = math.cos(ang), math.sin(ang)
			local p = meio + Vector3.new(rel.X * c - rel.Z * s, rel.Y + sobe, rel.X * s + rel.Z * c)
			if not ruim(p) then
				return CFrame.lookAt(M.semParede(meio + Vector3.new(0, 1.5, 0), p), meio + Vector3.new(0, 1.8, 0))
			end
		end
	end
	return cf
end

-- `cf`: câmera de luta já calculada. Devolve a câmera com o enquadramento do golpe misturado.
local publicado = -1
local function publicar(w: number)
	-- QA: o executor do Studio tem outra cópia dos módulos; o peso real vai no atributo ImpactoPeso do Workspace
	local v = math.floor(w * 100 + 0.5) / 100
	if v ~= publicado then
		publicado = v
		workspace:SetAttribute("ImpactoPeso", v)
	end
end

function M.aplicar(cf: CFrame): CFrame
	local preso = aplicarFoco(cf)
	if preso then return preso end
	local g = atual
	if not g then publicar(0) return cf end
	local w = M.peso() * Curvas.FORCA
	publicar(w)
	if w <= 0.001 then return cf end
	if not g.escolha then escolher(g, cf) end
	local c = g.escolha
	local opc = g.opc
	local t = (os.clock() - g.inicio) / g.esc
	local abre, esc = c[2], c[3] * (if opc and opc.escala then opc.escala else 1)
	if opc then
		-- movimento autoral: gira devagar em volta da dupla e vem chegando até o contato (dolly), depois recua
		abre += (opc.orbita or 0) * (math.clamp(t / Curvas.duracaoTotal(g.impacto), 0, 1) - 0.4)
		esc *= 1 + (opc.dolly or 0) * (1 - Curvas.suave(t / math.max(g.impacto, 0.1)))
	end
	local pos, olhar = Curvas.enquadre(
		{ x = g.de.X, y = g.de.Y, z = g.de.Z }, { x = g.para.X, y = g.para.Y, z = g.para.Z }, c[1], abre, esc, if opc then opc.altura else nil)
	local p, o = Vector3.new(pos.x, pos.y, pos.z), Vector3.new(olhar.x, olhar.y, olhar.z)
	local misto = cf:Lerp(CFrame.lookAt(p, o), w)
	local livre = M.semParede(o, misto.Position)
	if livre ~= misto.Position then
		misto = CFrame.lookAt(livre, o)
	end
	misto = M.desocluir(misto, g.de, g.para)
	return misto
end

return M
