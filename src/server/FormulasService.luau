-- A19: estado servidor de desenho, preparo e alimentação. Execução/dano/zona
-- são injetados pelo HabilidadeService; nenhum segundo motor de combate.
local F = require(game:GetService("ReplicatedStorage").Shared.Regras.Formulas)
local Protocol = require(game:GetService("ReplicatedStorage").Shared.MesaProtocol)
local S = {}
function S.novo(ctx)
	local api = {}
	local desenhos, preparadas, executando, tracoUsado = {}, {}, {}, {}
	local serial = 0
	local agora = ctx.agora or os.clock
	local function ficha(player,payload,master,vez)
		if type(payload) ~= "table" or type(payload.tokenId) ~= "string" or #payload.tokenId > 160 then return nil,"Pedido inválido." end
		local token = ctx.tokens[payload.tokenId]
		if not token or not ctx.canSee(player,token) then return nil,"Ficha não encontrada." end
		if not master and token.ownerUserId ~= player.UserId then return nil,"Você só age com sua ficha." end
		if token.pv <= 0 or token.derrotado or ctx.semAcoes(token) then return nil,"Não pode desenhar ou alimentar neste estado." end
		if ctx.reacoes.pendente() or executando[token.id] then return nil,"Aguarde a execução/Reação em andamento." end
		if vez and (not ctx.combat.active or ctx.currentTurnId() ~= token.id) then return nil,"Aguarde a vez da ficha em combate." end
		return token,nil
	end
	local function intencao(payload)
		if payload.alvoId ~= nil and (type(payload.alvoId) ~= "string" or #payload.alvoId > 160) then return nil,"Alvo inválido." end
		if (payload.x ~= nil or payload.z ~= nil) and not Protocol.isCell(payload.x,payload.z) then return nil,"Casa inválida." end
		if payload.qualidade ~= nil and (type(payload.qualidade) ~= "number" or payload.qualidade ~= payload.qualidade or payload.qualidade < 0 or payload.qualidade > 1) then return nil,"Qualidade cosmética inválida." end
		return { tokenId=payload.tokenId,essencia=payload.essencia,verbo=payload.verbo,forma=payload.forma,potencia=payload.potencia,
			alvoId=payload.alvoId,x=payload.x,z=payload.z },nil
	end
	local function interromper(token,motivo)
		local d = desenhos[token.id]
		if not d then return end
		desenhos[token.id] = nil
		if ctx.tokens[token.id] == token then token.mana=math.min(token.manaMax,token.mana+F.reembolsoInterrupcao(d.r.pm)); token.version+=1 end
		ctx.logAboutToken(token,token.name.." interrompe "..d.r.leitura..": "..motivo..". Perde as Ações gastas e "..math.floor(d.r.pm/2).." PM.")
	end
	local function conferir(d)
		local token=d.token
		if ctx.tokens[token.id]~=token or token.pv<=0 or token.derrotado or ctx.semAcoes(token) then return "Incapacitado/caído ou ficha removida." end
		if token.ownerUserId~=d.ownerUserId or not ctx.canSee(d.player,token) then return "Controle/visibilidade da ficha mudou." end
		local r,err=F.validar(token.ficha2,d.r)
		if not r then return err end
		local c=ctx.condicoesDe(token)
		if c.surdo or c.soterrado or ctx.silenciado(token) then return "Perdeu voz/postura da conjuração." end
		return ctx.validarAlvo(d.player,token,d.mec,d.pedido)
	end
	local function executar(player,token,r,pedido,bc)
		local mec=F.mecanica(r); mec.pm,mec.acoes=0,0 -- custo já reservado
		mec.bcFormula=bc
		executando[token.id]=true
		local ok,erro=pcall(ctx.executar,player,token,mec,pedido,bc)
		executando[token.id]=nil
		if not ok then error(erro,0) end
		return erro
	end
	local function dedicar(d)
		local erro=conferir(d)
		if erro then interromper(d.token,erro); return erro end
		local turno=ctx.turno(d.token.id)
		local n=math.min(d.r.acoes-d.gastas,math.max(0,ctx.limiteDeAcoes(d.token)-turno.usadas))
		if n<=0 then return "Sem Ações para continuar desenhando." end
		if d.r.fere and turno.usos["formula-feriu"] then return "Só uma fórmula desenhada que fere por turno." end
		turno.usadas+=n; d.gastas+=n; d.ultimaDedicacao=ctx.combat.turn; d.token.version+=1
		ctx.logAboutToken(d.token,string.format("%s desenha %s · %d/%d Ações",d.token.name,d.r.leitura,d.gastas,d.r.acoes))
		if d.gastas<d.r.acoes then return nil end
		if d.r.fere then turno.usos["formula-feriu"]=true end
		desenhos[d.token.id]=nil
		return executar(d.player,d.token,d.r,d.pedido,d.bc)
	end
	ctx.handlers.desenharFormula=function(player,payload,master)
		local token,err=ficha(player,payload,master,true); if not token then return err end
		if desenhos[token.id] then return "Já desenha uma fórmula; continue ou cancele." end
		local pedido; pedido,err=intencao(payload); if not pedido then return err end
		local r; r,err=F.validar(token.ficha2,pedido); if not r then return err end
		local mec=F.mecanica(r)
		err=ctx.validarAlvo(player,token,mec,pedido); if err then return err end
		if ctx.silenciado(token) or ctx.condicoesDe(token).surdo then return "Sem voz para Conjurar; desenho não se silencia." end
		local turno=ctx.turno(token.id)
		if turno.usadas>=ctx.limiteDeAcoes(token) then return "Sem Ação para começar o desenho." end
		if r.fere and turno.usos["formula-feriu"] then return "Só uma fórmula desenhada que fere por turno." end
		if token.mana<r.pm then return "PM insuficiente." end
		token.mana-=r.pm; token.version+=1
		local d={token=token,player=player,ownerUserId=token.ownerUserId,r=r,mec=mec,pedido=pedido,bc=ctx.bc(token),gastas=0,inicioVez=ctx.combat.turn,reacaoDisponivel=ctx.reacoes.temReacao(token)}
		desenhos[token.id]=d
		return dedicar(d)
	end
	ctx.handlers.continuarFormula=function(player,payload,master)
		local token,err=ficha(player,payload,master,true); if not token then return err end
		local d=desenhos[token.id]; if not d then return "Não há fórmula em desenho." end
		return dedicar(d)
	end
	ctx.handlers.cancelarFormula=function(player,payload,master)
		-- Cancelar é livre, inclusive fora da vez e quando incapaz de agir.
		if type(payload)~="table" or type(payload.tokenId)~="string" then return "Pedido inválido." end
		local token=ctx.tokens[payload.tokenId]
		if not token or not ctx.canSee(player,token) or not master and token.ownerUserId~=player.UserId then return "Ficha não encontrada/não controlada." end
		if executando[token.id] then return "A execução já começou." end
		if not desenhos[token.id] then return "Não há fórmula em desenho." end
		interromper(token,"cancelou voluntariamente"); return nil
	end
	ctx.handlers.prepararFormula=function(player,payload,master)
		local token,err=ficha(player,payload,master,false); if not token then return err end
		if ctx.combat.active then return "Prepare fora de combate, durante 1 minuto." end
		local pedido; pedido,err=intencao(payload); if not pedido then return err end
		local meio=payload.meio
		if meio~="giz" and meio~="bolso" then return "Escolha giz ou Fórmula de Bolso." end
		local r; r,err=F.validar(token.ficha2,pedido,meio); if not r then return err end
		serial+=1
		preparadas[token.id]={id="f"..serial,token=token,r=r,bc=ctx.bc(token),prontaEm=agora()+60}
		ctx.logAboutToken(token,token.name.." prepara "..r.leitura.."; requer 60 segundos. PM será pago por quem alimentar.")
		token.version+=1; return nil
	end
	local function perto(token,p,player)
		local origem=p.token
		return ctx.tokens[origem.id]==origem and ctx.canSee(player,origem)
			and math.max(math.abs(token.x-origem.x),math.abs(token.z-origem.z))<=1
	end
	ctx.handlers.ativarFormula=function(player,payload,master)
		local token,err=ficha(player,payload,master,true); if not token then return err end
		if desenhos[token.id] then return "Não pode usar pergaminho enquanto Conjura." end
		local pedido; pedido,err=intencao(payload); if not pedido then return err end
		if payload.preparadaId~=nil and (type(payload.preparadaId)~="string" or #payload.preparadaId>40) then return "Preparo inválido." end
		local p=preparadas[token.id]
		if payload.preparadaId then
			p=nil; for _,c in preparadas do if c.id==payload.preparadaId then p=c; break end end
		elseif not p then
			for _,id in ctx.tokenOrder do local c=preparadas[id]; if c and perto(token,c,player) then p=c; break end end
		end
		if not p or not perto(token,p,player) then return "Escolha uma fórmula preparada visível ao toque." end
		if agora()<p.prontaEm then return "O preparo ainda não completou 1 minuto." end
		local mec=F.mecanica(p.r)
		err=ctx.validarAlvo(player,token,mec,pedido); if err then return err end
		local turno=ctx.turno(token.id)
		if turno.usadas>=ctx.limiteDeAcoes(token) then return "Sem Ação para ativar." end
		if token.mana<p.r.pm then return "PM insuficiente para alimentar a fórmula." end
		preparadas[p.token.id]=nil
		token.mana-=p.r.pm; turno.usadas+=1; token.version+=1
		return executar(player,token,p.r,pedido,p.bc)
	end
	ctx.handlers.tocarFormula=function(player,payload,master)
		local token,err=ficha(player,payload,master,true); if not token then return err end
		if desenhos[token.id] then return "Não pode tocar uma estrutura enquanto Conjura." end
		local pedido; pedido,err=intencao(payload); if not pedido then return err end
		if not Protocol.isCell(pedido.x,pedido.z) then return "Escolha a casa da parede ao toque." end
		return ctx.tocarFormula(player,token,pedido)
	end
	function api.ocupado(token) return desenhos[token.id]~=nil or executando[token.id]==true end
	function api.desenhando(token) return desenhos[token.id]~=nil end
	function api.aoSofrerDano(token,atacante,mec,dano)
		local d=desenhos[token.id]; if not d or dano<=0 then return end
		if token.pv<=0 or ctx.semAcoes(token) then interromper(token,"caiu/incapacitado"); return end
		local f=token.ficha2
		local bonus=if atacante then ctx.patamar(atacante) else nil
		local r=F.concentracao(ctx.random,f.calculated.attributes.espirito or 0,f.calculated.highestRankBonus or 0,bonus,mec and mec.corteBraco)
		ctx.logAboutToken(token,string.format("Concentração: d20 %d, total %d contra CD %d: %s",r.dado,r.total,r.cd,if r.passou then "mantém" else "falha"))
		if not r.passou and F.talento(f,"traco-firme") and not tracoUsado[token.id] then
			tracoUsado[token.id]=true
			r=F.concentracao(ctx.random,f.calculated.attributes.espirito or 0,f.calculated.highestRankBonus or 0,bonus,mec and mec.corteBraco)
			ctx.logAboutToken(token,string.format("Traço Firme (1/combate): %d contra CD %d: %s",r.total,r.cd,if r.passou then "mantém" else "falha"))
		end
		if not r.passou then interromper(token,"falhou em Concentração") end
	end
	function api.revalidar()
		for _,d in desenhos do
			local err=conferir(d)
			if err then interromper(d.token,err)
			elseif d.reacaoDisponivel and not ctx.reacoes.temReacao(d.token) then interromper(d.token,"usou Reação") end
		end
	end
	function api.aoTrocarVez(anteriorId,novoId)
		local d=anteriorId and desenhos[anteriorId]
		if d and d.ultimaDedicacao~=d.inicioVez then interromper(d.token,"Perda de Foco: passou sua vez sem desenhar") end
		d=novoId and desenhos[novoId]; if d then d.inicioVez=ctx.combat.turn end
		for id,p in preparadas do
			if ctx.tokens[id]~=p.token or ctx.combat.active and agora()<p.prontaEm then preparadas[id]=nil end
		end
		api.revalidar()
	end
	function api.estadosDe(token)
		local out={}; local d=desenhos[token.id]; local p=preparadas[token.id]
		if d then table.insert(out,string.format("Conjurando fórmula %s · %d/%d Ações",d.r.potencia,d.gastas,d.r.acoes)) end
		if p then table.insert(out,if agora()<p.prontaEm then "Preparando fórmula · "..math.ceil(p.prontaEm-agora()).." s" else "Fórmula preparada · 1 Ação") end
		return out
	end
	function api.temPreparada(token)
		for _,p in preparadas do
			local publico = p.token==token or ctx.publico and ctx.publico(p.token)
			if publico and ctx.tokens[p.token.id]==p.token and agora()>=p.prontaEm and math.max(math.abs(token.x-p.token.x),math.abs(token.z-p.token.z))<=1 then return true end
		end
		return false
	end
	function api.descanso()
		for _,d in desenhos do interromper(d.token,"combate encerrado") end
		for id,p in preparadas do if p.r.meio~="bolso" or ctx.tokens[id]~=p.token or agora()<p.prontaEm then preparadas[id]=nil end end
		table.clear(tracoUsado)
	end
	function api.descartar() table.clear(desenhos); table.clear(preparadas); table.clear(executando); table.clear(tracoUsado) end
	return api
end
return S
