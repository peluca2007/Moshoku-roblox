-- SOMENTE STUDIO: testa handlers server-side com NPC, perfil e transporte simulados.
local LojaService = require(script.Parent.Parent.LojaService)

local function montar()
	local npc = Instance.new("Part")
	npc.Position = Vector3.new(0, 0, 0)
	local character = Instance.new("Model")
	local raiz = Instance.new("Part")
	raiz.Name, raiz.Position, raiz.Parent = "HumanoidRootPart", Vector3.new(2, 0, 0), character
	local humanoide = Instance.new("Humanoid")
	humanoide.Parent = character
	local player = { UserId = 980001, Character = character }
	local handlers, eventos, compras, vendas = {}, {}, {}, {}
	local agora = 0
	LojaService.start({
		handlers = handlers,
		remote = { FireClient = function(_, p, tipo, dados) table.insert(eventos, { p = p, tipo = tipo, dados = dados }) end },
		consultar = function() return { ouro = 200, inventarioInicial = {} } end,
		comprar = function(_, itemId, sourceLocalId) table.insert(compras, { itemId, sourceLocalId }); return true end,
		vender = function(_, sourceLocalId, categorias) table.insert(vendas, { sourceLocalId, categorias }); return true end,
		emCombate = function() return false end,
		obterNpcRaiz = function(id) return if id == "taverneira" or id == "ferreiro" then npc else nil end,
		relogio = function() return agora end,
	})
	return handlers, eventos, compras, vendas, player, character, raiz, npc, function(dt) agora += dt end
end

return {
	["prateleira e venda são filtradas pelo NPC e compra passa ID canônico"] = function(t)
		local h, eventos, compras, vendas, player, personagem, raiz, npc, avancar = montar()
		t.eq(LojaService.abrir(player, "taverneira"), true)
		local dados = eventos[#eventos].dados
		t.eq(dados.npcId, "taverneira")
		for _, item in ipairs(dados.prateleira) do
			t.ok(item.category == "pocao" or item.category == "aventura" or item.category == "tralha")
			t.ok(item.price > 0)
		end
		local listaArmas = h.lojaListar(player, { npcId = "ferreiro" })
		t.eq(listaArmas, nil)
		for _, item in ipairs(eventos[#eventos].dados.prateleira) do
			t.ok(item.category == "arma" or item.category == "armadura")
		end
		LojaService.abrir(player, "taverneira")
		local armaNoBar = h.lojaComprar(player, { npcId = "taverneira", itemId = "item/arma_adaga-punhal", requestId = "x" })
		t.ok(type(armaNoBar) == "string")
		avancar(1)
		local comprado = h.lojaComprar(player, { npcId = "taverneira", itemId = "item/pocao_menor_cura", requestId = "p" })
		t.eq(comprado, nil); t.eq(compras[1][1], "item/pocao_menor_cura")
		t.ok(string.match(compras[1][2], "^loja:"))
		t.eq(h.lojaComprar(player, { npcId = "taverneira", itemId = "item/pocao_menor_cura", requestId = "p" }), nil)
		t.eq(#compras, 1)
		t.ok(h.lojaComprar(player, { npcId = "taverneira", itemId = "item/tralha_pena-de-goblin", requestId = "p" }))
		personagem.HumanoidRootPart.Position = Vector3.new(50, 0, 0)
		t.ok(h.lojaComprar(player, { npcId = "taverneira", itemId = "item/pocao_menor_cura", requestId = "p" }))
		t.eq(#compras, 1)
		personagem:Destroy(); raiz:Destroy(); npc:Destroy()
	end,
	["remoto recusa jogador longe e venda repassa somente categorias server-side"] = function(t)
		local h, _, _, vendas, player, character, raiz, _, avancar = montar()
		LojaService.abrir(player, "taverneira")
		t.eq(h.lojaVender(player, { npcId = "taverneira", sourceLocalId = "kit-id", requestId = "v1" }), nil)
		t.eq(vendas[1][1], "kit-id"); t.eq(vendas[1][2].pocao, true); t.eq(vendas[1][2].arma, nil)
		avancar(1)
		character.HumanoidRootPart.Position = Vector3.new(50, 0, 0)
		t.ok(h.lojaListar(player, { npcId = "taverneira" }))
		character:Destroy(); raiz:Destroy()
	end,
}
