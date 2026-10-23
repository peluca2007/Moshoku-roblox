-- Política pura: motivos formam um conjunto, padrões vêm da configuração, nunca do corpo bloqueado.
local M={}
function M.padroes(config)
	return {WalkSpeed=config.CharacterWalkSpeed,JumpPower=config.CharacterJumpPower,JumpHeight=config.CharacterJumpHeight}
end
function M.restaurar(h,padroes)
	h.WalkSpeed=padroes.WalkSpeed
	h.JumpPower=padroes.JumpPower
	h.JumpHeight=padroes.JumpHeight
end
function M.new(obter,obterPadroes)
	local motivos={}
	local humanoide=nil
	local bloqueado=false
	local function atualizar()
		local atual=obter()
		if atual~=humanoide then
			if humanoide and bloqueado then M.restaurar(humanoide,obterPadroes()) end
			humanoide=atual; bloqueado=false
		end
		if not humanoide then return end
		if next(motivos) then
			humanoide.WalkSpeed=0; humanoide.JumpPower=0; humanoide.JumpHeight=0
			bloqueado=true
		elseif bloqueado then
			M.restaurar(humanoide,obterPadroes()); bloqueado=false
		end
	end
	local function definir(motivo,ativo)
		assert(type(motivo)=="string" and motivo~="","Bloqueio exige motivo")
		motivos[motivo]=if ativo then true else nil
		atualizar()
	end
	return definir,atualizar
end
return M
