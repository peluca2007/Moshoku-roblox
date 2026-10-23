-- Só o conteúdo impresso da ficha; controles ficam fora do papel.
local RS=game:GetService("ReplicatedStorage")
local Perfil=require(RS.Shared.PerfilFicha)
local Catalogo=require(RS.Shared.Livro.Catalogo)
local I={}
function I.paginas(f) return 2+math.max(1,math.ceil(#f.cartas/10)) end
function I.render(texto,f,pagina,arma,eu,sala)
	texto("MOSHOKU  /  FICHA DE PERSONAGEM",20)
	texto(f.nome,46)
	texto("─────────────────────────",20)
	if pagina==1 then
		texto(string.format("PV %d     PM %d     CA %d",f.pv,f.pm,f.ca),34)
		texto(f.armas[arma].nome,28)
		local linhas={};for _,k in {"forca","agilidade","vigor","intelecto","espirito"} do table.insert(linhas,string.upper(k).."   "..tostring(f.atributos[k] or 0)) end
		texto(table.concat(linhas,"\n"),31)
		texto("PA de aprimoramento gastos: "..f.paGasto.."   •   PH: —",22)
	elseif pagina==2 then
		local p=Perfil.de(f);texto("Como este personagem joga",33);texto(p.resumo,29)
		texto(string.format("Dano %d/10\nResistência %d/10\nSuporte %d/10\nControle %d/10\nMobilidade %d/10",p.dano,p.resistencia,p.suporte,p.controle,p.mobilidade),29)
		texto("Perfil indicativo de estilo; não altera atributos.",21)
	else
		texto("Habilidades",34)
		for i=(pagina-3)*10+1,math.min(#f.cartas,(pagina-2)*10) do
			local id=f.cartas[i];local e=Catalogo.POR_ID[id]
			texto("• "..(e and (e.nome or e.data and e.data.name) or id:match("[^/]+$")),26)
		end
	end
	texto("─────────────────────────",20)
	local donos={};for _,p in sala and sala.pessoas or {} do if p.ficha==f.id then table.insert(donos,p.nome) end end
	texto(if eu and eu.ficha==f.id then "SEU PERSONAGEM" elseif #donos>0 then "Em uso por "..table.concat(donos,", ") else "Disponível para jogar",23)
	texto("FOLHA "..pagina.." / "..I.paginas(f),20)
end
return I
