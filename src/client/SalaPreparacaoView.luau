local RS=game:GetService("ReplicatedStorage")
local P=require(RS.Shared.PreparacaoSala)
local V={}
function V.render(ui,sala,state,aba,mudar)
	local texto,botao=ui.texto,ui.botao
	local mestre=sala.mestre==game.Players.LocalPlayer.UserId
	local sentado=ui.sentado~=false
	local function permitir(b,ativo)
		b.Interactable=ativo;b.AutoButtonColor=ativo;b.TextTransparency=if ativo then 0 else .35
		return b
	end
	local r=P.resumo(sala)
	texto(if mestre then "Preparar a partida" else "Preparação do grupo",45)
	texto(P.NOMES[sala.modo]..(if sala.modo=="luta" then " • nível "..sala.nivel else "").."  •  Grupo previsto: "..#r.grupo,25)
	local abas={{"sessao","Sessão"},{"pessoas","Pessoas"},{"sala","Sala"}}
	if ui.abas then ui.abas(abas,mudar) else for _,a in abas do botao("Aba_"..a[1],a[2],function() mudar(a[1]) end) end end
	if aba=="sessao" then
		texto(if mestre then "1. Escolha o modo.\n2. Confira as fichas e confirmações do grupo.\n3. Inicie a partida pelo botão abaixo." else "Pegue uma ficha e use ASSUMIR. Depois confirme que está pronto aqui. O mestre escolhe o modo e inicia para o grupo.",25)
		texto(if mestre then "Modo da partida" else "Modo escolhido pelo mestre",31)
		local descricoes={treino="Praticar habilidades contra bonecos.",luta="Enfrentar criaturas em grupo.",duelo="Jogadores contra jogadores; equipes na aba Pessoas."}
		for _,id in {"treino","luta","duelo"} do
			if not mestre then if id==sala.modo then texto(P.NOMES[id].." • "..descricoes[id],25) end;continue end
			permitir(botao("Modo_"..id,(if sala.modo==id then "✓  " else "")..P.NOMES[id].." • "..descricoes[id],function() if id~=sala.modo then state.send("salaConfigurar",{modo=id,nivel=sala.nivel,monstros=false}) end end),mestre and sentado)
		end
		if mestre and sala.modo=="luta" then
			for n=1,3 do permitir(botao("Nivel_"..n,(if sala.nivel==n then "✓  " else "").."Desafio "..n,function() if n~=sala.nivel then state.send("salaConfigurar",{modo=sala.modo,nivel=n,monstros=sala.monstros}) end end),sentado) end
			permitir(botao("Monstros",if sala.monstros then "✓  Mestre controla as criaturas" else "Mestre joga com seu personagem",function() state.send("salaConfigurar",{modo=sala.modo,nivel=sala.nivel,monstros=not sala.monstros}) end),sentado)
		end
		if mestre then texto("Trocar o modo, o desafio ou as equipes pede uma nova confirmação dos jogadores.",22) end
		local nomes={};for _,f in require(RS.Shared.PersonagensProntos) do nomes[f.id]=f.nome end
		texto("Quem vai entrar",31)
		for _,p in sala.pessoas do
			local status=if not p.admitido then "aguardando vaga" elseif p.id==sala.mestre and sala.monstros then "controla as criaturas" elseif not p.ficha then "falta assumir uma ficha" else (nomes[p.ficha] or p.ficha)..(if p.id==sala.mestre then " • confirma ao iniciar" elseif p.pronto then " • pronto" else " • falta confirmar PRONTO")
			texto(p.nome.." — "..status,25)
			if p.id==game.Players.LocalPlayer.UserId and p.admitido and p.ficha and not mestre then
				botao("MeuPronto",if p.pronto then "Cancelar meu PRONTO" else "Estou pronto para jogar",function() state.send("salaPronto",{ativo=not p.pronto}) end)
			end
		end
		texto(r.prontos.." confirmação(ões) • mínimo: "..r.minimo..". Todos os participantes admitidos e com ficha entram, mesmo quem ainda não confirmou.",22)
		if mestre then
			local br=sala.brincadeiraBrotos;local livre=not (br and br.fase=="rolagem") and not sala.transicao
			local pode=sentado and livre and r.podeIniciar
			local rotulo=if not sentado then "Sente-se à mesa para começar" elseif not livre then "Aguarde os dados…" elseif not r.podeIniciar then "Confira as pendências abaixo" else "Iniciar "..P.NOMES[sala.modo].." com "..#r.grupo.." personagem(ns)"
			local b=permitir(botao("LancarDados",rotulo,function() if pode then state.send("salaIniciar",{}) end end),pode)
			b.BackgroundColor3=if pode then Color3.fromRGB(66,110,83) else Color3.fromRGB(185,174,152);b.TextColor3=if pode then Color3.fromRGB(255,244,219) else Color3.fromRGB(75,65,53)
			if not sentado then texto("Sente-se em uma cadeira da mesa para configurar e iniciar a sessão.",25) end
		else texto("O mestre inicia a sessão quando a mesa estiver pronta.",25) end
		if #r.pendencias>0 then texto(table.concat(r.pendencias,"\n"),27) else texto("✓ Fichas e prontidão conferidas.",27) end
		texto("O mestre confirma ao começar. Jogadores: usem Estou pronto acima ou o selo PRONTO da mesa.",22)
	elseif aba=="pessoas" then
		texto("Ficha • prontidão • equipe",31)
		for _,p in sala.pessoas do
			texto(p.nome..(if p.id==sala.mestre then " • mestre" else "").."\n"..(if not p.admitido then "Aguardando vaga" elseif not p.ficha and not (p.id==sala.mestre and sala.monstros) then "Sem ficha" elseif p.pronto then "✓ Pronto" elseif p.id==sala.mestre then "Confirma ao começar" else "Preparando"),27)
			if mestre then
				if not p.admitido then botao("Admitir_"..p.id,"Autorizar entrada",function() state.send("salaAdmitir",{userId=p.id}) end)
				else
					if sala.modo=="duelo" then for equipe=0,2 do botao("Equipe_"..p.id.."_"..equipe,(if p.equipe==equipe then "✓ " else "")..(if equipe==0 then "Cada um por si" else "Equipe "..equipe),function() if p.equipe~=equipe then state.send("salaEquipe",{userId=p.id,equipe=equipe}) end end) end end
					if p.id~=sala.mestre then
						local t=ui.transferencia or {};local confirmando=t.para==p.id and t.ate and os.clock()<t.ate
						botao("Transferir_"..p.id,if confirmando then "Confirmar transferência para "..p.nome.."?" else "Passar o posto de mestre",function()
							if t.para==p.id and t.ate and os.clock()<t.ate then table.clear(t);state.send("salaTransferir",{userId=p.id}) else t.para=p.id;t.ate=os.clock()+5 end
							if ui.atualizar then ui.atualizar() end
						end)
					end
				end
			end
		end
	else
		texto("Dados do Brotos",34);texto("Uma rodada para toda a sala. Trio > sequência > dupla; 111 é o melhor trio. Só diversão: o posto de mestre continua com o dono atual.",25)
		if mestre then
			botao("BrotosTodos","Todos jogam Dados do Brotos",function() state.send("salaBrotosAbrir",{}) end)
			botao("ArrumarSala","Recolher papéis e livros arremessados",function() state.send("salaArrumar",{}) end)
			texto("Autorizar cópias de personagem",31)
			for _,f in require(RS.Shared.PersonagensProntos) do
				botao("Copia_"..f.id,f.nome.." • "..tostring(sala.copias[f.id] or 1).." cópia(s) • autorizar +1",function() state.send("salaCopia",{id=f.id}) end)
			end
		end
		texto("O contorno mostra o que você pode pegar. Mantenha o clique, RT ou toque para segurar; solte para largar. F ou X do controle arremessa. As ações de leitura e entrega aparecem enquanto você segura o objeto.",25)
	end
end
return V
