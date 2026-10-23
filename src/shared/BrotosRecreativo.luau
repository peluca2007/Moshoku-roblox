-- Rodada social separada da sucessão do mestre. RNG e relógio injetados.
local Shared = game:GetService("ReplicatedStorage").Shared
local B=require(Shared.Brotos)
local R={}
function R.new()
	local rodada=nil;local serial=0;local api={}
	function api.abrir(ids,agora)
		if rodada and rodada.fase=="rolagem" then return "Já existe uma rodada do Brotos aberta." end
		local participantes={};for _,id in ids do participantes[id]=true end
		if next(participantes)==nil then return "Não há participantes na sala." end
		serial+=1;rodada={serial=serial,fase="rolagem",fim=agora+15,participantes=participantes,dados={}}
		return nil
	end
	function api.rolar(id,inteiro)
		if not rodada or rodada.fase~="rolagem" or not rodada.participantes[id] or rodada.dados[id] then return "Você não tem uma rolagem pendente." end
		rodada.dados[id]=B.rolar(inteiro);return nil
	end
	function api.atualizar(agora,inteiro)
		if not rodada or rodada.fase~="rolagem" then return false end
		local completo=true
		for id in rodada.participantes do
			if not rodada.dados[id] then
				if agora>=rodada.fim then rodada.dados[id]=B.rolar(inteiro) else completo=false end
			end
		end
		if not completo then return false end
		rodada.fase="resultado";rodada.vencedores=B.vencedores(rodada.dados);return true
	end
	function api.sair(id,agora,inteiro,adiar)
		if rodada and rodada.fase=="rolagem" then rodada.participantes[id]=nil;rodada.dados[id]=nil;if not adiar then api.atualizar(agora,inteiro) end end
	end
	function api.publico() return rodada end
	return api
end
return R
