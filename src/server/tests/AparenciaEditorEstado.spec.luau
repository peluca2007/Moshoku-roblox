local Shared = game:GetService("ReplicatedStorage").Shared
local Editor = require(Shared.Aparencia.EditorEstado)
local Aparencia = require(Shared.Aparencia.Aparencia)
local Racas = require(Shared.Aparencia.Racas)

local function rng(seed)
	local state = seed
	return { NextInteger = function(_, a, b) state = (state * 48271) % 2147483647; return a + state % (b - a + 1) end }
end
local function tem(lista, id)
	for _, item in lista do if item.id == id then return true end end
	return false
end

return {
	["navegação percorre opções ciclicamente nos dois sentidos"] = function(t)
		local estado = Editor.novo("race/humano")
		local opcoes = Editor.opcoes(estado, "olhos")
		local primeiro = opcoes[1].id
		Editor.selecionar(estado, "olhos", opcoes[#opcoes].id)
		Editor.navegar(estado, "olhos", 1); t.eq(estado.aparencia.rosto.olhos, primeiro)
		Editor.navegar(estado, "olhos", -1); t.eq(estado.aparencia.rosto.olhos, opcoes[#opcoes].id)
	end,
	["troca de raça preserva escolhas válidas e reajusta cores fora da paleta"] = function(t)
		local estado = Editor.novo("race/humano")
		Editor.selecionar(estado, "olhos", "OlhoQuadrado")
		Editor.selecionar(estado, "pele", "PeleClara")
		local outro = Editor.reajustar(estado, "race/migurd")
		t.eq(outro.aparencia.rosto.olhos, "OlhoQuadrado")
		t.eq(outro.aparencia.cores.pele, "PeleClara")
		t.eq(outro.aparencia.cores.olho, "OlhoAzul"); t.eq(outro.aparencia.cores.cabelo, "CabeloAzul")
		t.ok(Aparencia.validar(outro.aparencia, outro.raceId, outro.possuidos))
	end,
	["novo mantém aparência salva e reajustar conserva traço racial compatível"] = function(t)
		local salva = Aparencia.padrao("race/humano", 12)
		salva.rosto.olhos = "OlhoQuadrado"
		local estado = Editor.novo("race/humano", salva)
		t.eq(estado.aparencia.rosto.olhos, "OlhoQuadrado")
		estado = Editor.novo("race/ogro")
		Editor.selecionar(estado, "tracos", "ChifresOgro")
		local ogro = Editor.reajustar(estado, "race/ogro")
		t.eq(ogro.aparencia.roupas.cabeca, "ChifresOgro")
		local humano = Editor.reajustar(ogro, "race/humano")
		t.eq(humano.aparencia.roupas.cabeca, nil)
	end,
	["raras aparecem somente quando possuídas e traços só na raça que os oferece"] = function(t)
		local estado = Editor.novo("race/humano")
		t.eq(Editor.selecionar(estado, "roupas", "LadinoCapa"), false)
		t.eq(tem(Editor.opcoes(estado, "roupas"), "LadinoCapa"), false)
		t.eq(tem(Editor.opcoes(estado, "tracos"), "ChifresOgro"), false)
		estado = Editor.novo("race/humano", nil, { LadinoCapa = true })
		t.eq(tem(Editor.opcoes(estado, "roupas"), "LadinoCapa"), true)
		t.eq(tem(Editor.opcoes(estado, "roupas"), "OrelhasElficas"), false)
		t.eq(tem(Editor.opcoes(Editor.novo("race/ogro"), "tracos"), "ChifresOgro"), true)
	end,
	["seleções oferecidas e navegação mantêm o validador A1 satisfeito"] = function(t)
		for raceId in Racas.POR_ID do
			local estado = Editor.novo(raceId, nil, {LadinoCapa=true, MestraTiara=true})
			for _, campo in {"olhos","sobrancelhas","nariz","boca","olho","cabelo","corCabelo","barba","pele","camisa","calca","roupas","tracos"} do
				for _, opcao in Editor.opcoes(estado,campo) do
					t.ok(Editor.selecionar(estado,campo,opcao.id))
					t.ok(Aparencia.validar(estado.aparencia,raceId,estado.possuidos),raceId..":"..campo)
				end
				Editor.navegar(estado,campo,1)
				t.ok(Aparencia.validar(estado.aparencia,raceId,estado.possuidos))
			end
		end
	end,
	["aleatória permanece válida em todas as raças e várias amostras"] = function(t)
		for raceId in Racas.POR_ID do
			for amostra = 1, 8 do
				local estado = Editor.novo(raceId)
				Editor.aleatorio(estado, rng(amostra))
				t.ok(Aparencia.validar(estado.aparencia, raceId, estado.possuidos), raceId)
			end
		end
	end,
	["cursor de roupas e traços avança após seleção e toggle de remoção"] = function(t)
		local estado = Editor.novo("race/humano")
		local opcoes = Editor.opcoes(estado, "roupas")
		Editor.navegar(estado, "roupas", 1)
		t.eq(estado.cursores.roupas, opcoes[1].id)
		Editor.navegar(estado, "roupas", 1)
		t.eq(estado.cursores.roupas, opcoes[2].id)
		local ogro = Editor.novo("race/ogro")
		Editor.navegar(ogro, "tracos", 1)
		t.eq(ogro.aparencia.roupas.cabeca, "ChifresOgro")
		Editor.navegar(ogro, "tracos", 1)
		t.eq(ogro.aparencia.roupas.cabeca, nil)
		t.eq(ogro.cursores.tracos, "ChifresOgro")
	end,
	["clone copia profundamente a aparência"] = function(t)
		local origem = Aparencia.padrao("race/humano", 1)
		local copia = Editor.clone(origem); copia.rosto.olhos = "alterado"
		t.ok(origem.rosto.olhos ~= copia.rosto.olhos)
	end,
}
