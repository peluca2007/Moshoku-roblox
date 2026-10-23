-- Evento de resultado e snapshot final podem chegar em ordens diferentes.
local E={}
function E.new()
	local s={ativo=nil,pendente=nil,resultado=nil,visivel=false}
	local function mostrar()
		if s.ativo==false and s.pendente then
			s.resultado=s.pendente;s.pendente=nil;s.visivel=true
		end
	end
	function s.receber(resultado) s.pendente=resultado;mostrar() end
	function s.snapshot(ativo)
		if ativo then
			if s.ativo==false then s.pendente=nil;s.resultado=nil end
			s.visivel=false
		end
		s.ativo=ativo;mostrar()
	end
	function s.fechar() s.visivel=false end
	return s
end
return E
