-- Estado puro da sala. IDs, relógio e dados são fornecidos pelo servidor.
local Shared = game:GetService("ReplicatedStorage").Shared
local Brotos = require(Shared.Brotos)
local Preparacao = require(Shared.PreparacaoSala)
local S = {}
function S.new(validos)
	local s={pessoas={},ordem={},mestre=nil,modo="luta",nivel=1,monstros=false,copias={},eleicao=nil,ultimoBrotos=nil,brotosSerial=0,versao=0}
	local api={estado=s}
	local function lista()
		local r={}; for _,id in s.ordem do if s.pessoas[id] and s.pessoas[id].admitido then table.insert(r,id) end end; return r
	end
	local function mestre(id) return s.mestre==id end
	local function zerar() for _,p in s.pessoas do p.pronto=false end; s.versao+=1 end
	local function eleger(id) s.mestre=id; s.eleicao=nil; zerar() end
	function api.entrar(id,nome)
		if s.pessoas[id] then return end
		s.pessoas[id]={id=id,nome=nome,admitido=#lista()<6,pronto=false,equipe=0}
		table.insert(s.ordem,id)
		if not s.mestre and not s.eleicao then eleger(id) end
		zerar()
	end
	function api.sair(id,agora)
		s.pessoas[id]=nil; local i=table.find(s.ordem,id); if i then table.remove(s.ordem,i) end
		-- Uma vaga básica liberada admite o primeiro da espera; nunca excede seis
		-- por este caminho, nem deixa só pessoas sem permissão para se candidatar.
		for _,uid in s.ordem do if #lista()>=6 then break end;local p=s.pessoas[uid];if not p.admitido then p.admitido=true end end
		if s.eleicao then s.eleicao.candidatos[id]=nil; s.eleicao.dados[id]=nil end
		if s.mestre==id then s.mestre=nil; s.eleicao={fase="convite",fim=agora+12,candidatos={},dados={},rodada=0} end
		if #s.ordem==0 then s.eleicao=nil end
		zerar()
	end
	function api.aplicar(id,acao,p,agora,ativo)
		if type(p)~="table" or not s.pessoas[id] then return "Pedido de sala inválido." end
		local eu=s.pessoas[id]
		if not eu.admitido then return "Aguarde autorização do mestre para entrar na mesa." end
		if acao=="candidatar" then
			local e=s.eleicao
			if not e or e.fase~="convite" or type(p.sim)~="boolean" then return "A escolha de mestre não está aberta." end
			e.candidatos[id]=if p.sim then true else nil
			if not e.fim then e.fim=agora+12 end
			return nil
		end
		if acao=="transferir" then
			if not mestre(id) then return "Só o mestre transfere o posto." end
			local alvo=s.pessoas[p.userId]; if not alvo or not alvo.admitido then return "Escolha alguém da mesa." end
			eleger(alvo.id); return nil
		end
		if ativo then return "Espere a partida terminar para preparar outra sessão." end
		if acao=="admitir" then
			if not mestre(id) then return "Só o mestre autoriza vagas extras." end
			local alvo=s.pessoas[p.userId]
			if not alvo or alvo.admitido or #lista()>=10 then return "Vaga indisponível; máximo de dez participantes." end
			alvo.admitido=true; zerar(); return nil
		elseif acao=="configurar" then
			if not mestre(id) then return "Só o mestre escolhe o modo." end
			if p.modo~="luta" and p.modo~="duelo" and p.modo~="treino" then return "Modo inválido." end
			if type(p.nivel)~="number" or p.nivel%1~=0 or p.nivel<1 or p.nivel>3 or type(p.monstros)~="boolean" then return "Configuração inválida." end
			if p.modo~="luta" and p.monstros then return "Controle de monstros está disponível nos Desafios." end
			s.modo,s.nivel,s.monstros=p.modo,p.nivel,p.monstros; zerar(); return nil
		elseif acao=="equipe" then
			if not mestre(id) then return "Só o mestre define as equipes." end
			local alvo=s.pessoas[p.userId]
			if not alvo or not alvo.admitido or type(p.equipe)~="number" or p.equipe%1~=0 or p.equipe<0 or p.equipe>2 then return "Equipe inválida." end
			alvo.equipe=p.equipe; zerar(); return nil
		elseif acao=="copia" then
			if not mestre(id) then return "Só o mestre adiciona cópias de fichas." end
			if not validos[p.id] then return "Ficha inválida." end
			s.copias[p.id]=math.min(10,(s.copias[p.id] or 1)+1); zerar(); return nil
		elseif acao=="escolher" then
			if not validos[p.id] then return "Ficha inválida." end
			local usados=0
			for outro,x in s.pessoas do if outro~=id and x.admitido and x.ficha==p.id then usados+=1 end end
			if usados >= (s.copias[p.id] or 1) then return "Essa ficha já tem dono. O mestre pode adicionar uma cópia." end
			eu.ficha=p.id; eu.pronto=false; s.versao+=1; return nil
		elseif acao=="pronto" then
			if type(p.ativo)~="boolean" then return "Confirmação inválida." end
			if not eu.ficha and not (mestre(id) and s.monstros) then return "Escolha uma ficha primeiro." end
			eu.pronto=p.ativo; return nil
		end
		return "Opção de sala desconhecida."
	end
	function api.podeIniciar(id)
		if not mestre(id) then return nil,"Só o mestre inicia a partida." end
		local r=Preparacao.resumo(s)
		if not r.podeIniciar then return nil,r.pendencias[1] end
		-- Preserva a ordem de entrada para a montagem da partida.
		local grupo={};for _,uid in lista() do if table.find(r.grupo,uid) then table.insert(grupo,uid) end end
		return grupo,nil
	end
	function api.rolar(id,inteiro)
		local e=s.eleicao
		if not e or e.fase~="rolagem" or not e.candidatos[id] or e.dados[id] then return "Você não tem uma rolagem pendente." end
		e.dados[id]=Brotos.rolar(inteiro); return nil
	end
	function api.atualizar(agora,inteiro)
		local e=s.eleicao; if not e then return false end
		if e.fase=="convite" then
			if not e.fim or agora<e.fim then return false end
			local n,unico=0,nil; for id in e.candidatos do if s.pessoas[id] then n+=1;unico=id end end
			if n==0 then e.fim=nil; return true end
			if n==1 then eleger(unico); return true end
			e.fase="rolagem";e.rodada+=1;e.fim=agora+15;return true
		end
		local completos=true
		for id in e.candidatos do
			if not e.dados[id] then if agora>=e.fim then e.dados[id]=Brotos.rolar(inteiro) else completos=false end end
		end
		if not completos then return false end
		local vencedores=Brotos.vencedores(e.dados)
		s.brotosSerial+=1;s.ultimoBrotos={dados=e.dados,vencedores=vencedores,rodada=e.rodada,evento=s.brotosSerial}
		if #vencedores==1 then eleger(vencedores[1])
		elseif #vencedores==0 then e.fase="convite";e.fim=nil
		else e.candidatos={}; for _,id in vencedores do e.candidatos[id]=true end; e.dados={};e.rodada+=1;e.fim=agora+15 end
		return true
	end
	function api.publico()
		local p={};local ids=lista(); if s.mestre then local i=table.find(ids,s.mestre);if i then table.remove(ids,i);table.insert(ids,1,s.mestre) end end
		for _,id in s.ordem do local x=table.clone(s.pessoas[id]);x.lugar=table.find(ids,id);table.insert(p,x) end
		return {pessoas=p,mestre=s.mestre,modo=s.modo,nivel=s.nivel,monstros=s.monstros,copias=table.clone(s.copias),eleicao=s.eleicao,ultimoBrotos=s.ultimoBrotos,versao=s.versao}
	end
	return api
end
return S
