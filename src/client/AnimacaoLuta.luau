-- Corpo dos personagens durante a luta (LUTA-A): toca, só nesta tela, os clipes por dados
-- (TocadorClipe) nos avatares que são fichas do combate: PosturaCombate em laço enquanto a luta dura,
-- Queda (fica no chão) quando a ficha chega a 0 PV e Vitoria no fim de uma luta vencida. A arma (a última vista
-- nos recibos; espada se nenhuma) fica na mão com a pega dos clipes, só nesta tela e fora dos clones. Só apresentação:
-- escreve Motor6D.Transform localmente; não muda CFrame, ficha nem rede. Os gestos de técnica usam um
-- fantasma (Corpo/Gestos) e escondem o avatar enquanto duram, então não brigam com isto.
local Players = game:GetService("Players")
local Tocador = require(script.Parent.TocadorClipe)
local Corpo = require(script.Parent.Corpo)

local AnimacaoLuta = {}

local DURACAO_VITORIA = 2.6

function AnimacaoLuta.start(state)
	-- userId -> { personagem, tocador, postura, queda }
	local corpos: { [number]: any } = {}
	local ultimoAtivo = false
	local ultimoSnapshot = nil

	local function soltar(userId: number, fade: number?)
		local c = corpos[userId]
		if not c then return end
		corpos[userId] = nil
		for _, p in c.arma or {} do
			p:Destroy()
		end
		if c.tocador and c.tocador.vivo then
			c.tocador:parar(fade or 0.25)
			local t = c.tocador
			task.delay((fade or 0.25) + 0.1, function()
				if t.vivo then t:destruir() end
			end)
		end
	end

	local function corpoDe(userId: number)
		local dono = Players:GetPlayerByUserId(userId)
		local personagem = dono and dono.Character
		if not personagem or not personagem:FindFirstChild("HumanoidRootPart") or not personagem:FindFirstChild("RightShoulder", true) then
			return nil
		end
		local c = corpos[userId]
		if c and c.personagem ~= personagem then
			soltar(userId, 0)
			c = nil
		end
		if not c then
			local ok, t = pcall(Tocador.novo, personagem)
			if not ok then return nil end
			c = { personagem = personagem, tocador = t }
			corpos[userId] = c
		end
		return c
	end

	local function venceu(snap): boolean
		local inimigos, inimigoVivo, aliadoVivo = 0, false, false
		for _, token in snap.tokens or {} do
			local vivo = not token.derrotado and (token.pv == nil or token.pv > 0)
			if token.criatura then
				inimigos += 1
				if vivo then inimigoVivo = true end
			elseif token.avatar and vivo then
				aliadoVivo = true
			end
		end
		return inimigos > 0 and not inimigoVivo and aliadoVivo
	end

	-- Só para inspeção (como CenaTempoFixo): o atributo LutaClipeTeste do Workspace ("Queda", "Vitoria"...)
	-- toca esse clipe nos avatares em luta; nil o tira.
	workspace:GetAttributeChangedSignal("LutaClipeTeste"):Connect(function()
		local nome = workspace:GetAttribute("LutaClipeTeste")
		for _, c in corpos do
			if c.teste then c.teste:parar(0.2); c.teste = nil end
			if type(nome) == "string" and c.tocador.vivo then
				local ok, controle = pcall(c.tocador.tocar, c.tocador, nome)
				if ok then c.teste = controle end
			end
		end
	end)

	state.onSnapshot(function(snap)
		local ativo = snap ~= nil and snap.combat ~= nil and snap.combat.active == true
		if ativo then
			local vistos = {}
			for _, token in snap.tokens or {} do
				if token.avatar and token.ownerUserId then
					local c = corpoDe(token.ownerUserId)
					if c then
						vistos[token.ownerUserId] = true
						local tipo = Corpo.armasVistas[c.personagem] or "espada"
						if c.tipoArma ~= tipo then
							for _, p in c.arma or {} do p:Destroy() end
							c.arma = Corpo.arma({ modelo = c.personagem, clipes = c.tocador }, tipo)
							for _, p in c.arma do p.Archivable = false end -- o fantasma (Clone) não leva a arma
							c.tipoArma = tipo
						end
						if not c.postura or c.postura.terminou then
							c.postura = c.tocador:tocar("PosturaCombate", { fadeEntrada = 0.35 })
						end
						local caido = token.pv ~= nil and token.pv <= 0
						if caido and not c.queda then
							c.queda = c.tocador:tocar("Queda", { fadeEntrada = 0.08 })
						elseif not caido and c.queda then
							c.queda:parar(0.4)
							c.queda = nil
						end
					end
				end
			end
			for userId in corpos do
				if not vistos[userId] then soltar(userId) end
			end
		elseif ultimoAtivo then
			-- Fim da luta: vitória comemora; senão, só larga a postura.
			if (snap and #(snap.tokens or {}) > 0 and venceu(snap)) or (ultimoSnapshot and venceu(ultimoSnapshot)) then
				for userId, c in corpos do
					if not c.queda and c.tocador.vivo then
						c.tocador:tocar("Vitoria", { fadeEntrada = 0.15 })
						task.delay(DURACAO_VITORIA, function()
							if corpos[userId] == c then soltar(userId, 0.5) end
						end)
					else
						soltar(userId)
					end
				end
			else
				for userId in corpos do soltar(userId) end
			end
		end
		ultimoAtivo = ativo
		if ativo then ultimoSnapshot = snap end
	end)
end

return AnimacaoLuta
