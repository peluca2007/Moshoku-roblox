-- Notas editoriais para orientar escolha; não entram em nenhuma regra.
local P={}
local perfis={
	fogo={9,3,2,6,3,"Dano mágico e zonas de chama; cuide da distância e da mana."},
	agua={7,5,4,8,3,"Gelo, proteção e névoa para controlar a luta."},
	vento={7,3,4,8,9,"Reposicionamento e empurrões; depende do terreno."},
	terra={6,8,5,9,2,"Muros e terreno para dividir o campo."},
	cura={2,5,10,2,3,"Recuperação e proteção dos companheiros."},
	desintoxicacao={3,5,9,4,3,"Resposta a venenos e condições; valor depende do inimigo."},
	teorica={6,4,7,7,4,"Versátil: prepara fórmulas e exige planejamento."},
	invocacao={6,5,7,6,4,"Traz aliados e distribui presença no campo."},
	["deus-da-espada"]={10,5,2,3,8,"Pressão ofensiva corpo a corpo; precisa alcançar o alvo."},
	["deus-da-agua-corpo"]={6,9,4,6,4,"Defesa e respostas aos ataques adversários."},
	["deus-do-norte"]={7,6,5,9,7,"Manobras e controle situacional para criar oportunidades."},
	["armas-pesadas"]={9,7,2,6,3,"Golpes fortes e pressão, com menor mobilidade."},
	["cavalaria-e-escudos"]={5,10,8,6,4,"Protege aliados e segura a linha de frente."},
	arquearia={8,3,3,5,6,"Dano à distância; posicionamento é essencial."},
	["furtividade-e-armadilhas"]={7,3,4,8,8,"Esconder, preparar emboscadas e explorar oportunidades."},
	["bardo-e-interacao"]={3,4,10,6,4,"Canções e inspiração para fortalecer o grupo."},
	["navegacao-e-lideranca"]={5,6,9,7,6,"Coordena o grupo e melhora a preparação."},
}
function P.de(ficha)
	local p=perfis[ficha.arvore] or {5,5,5,5,5,"Consulte as habilidades nas próximas páginas."}
	return {dano=p[1],resistencia=p[2],suporte=p[3],controle=p[4],mobilidade=p[5],resumo=p[6],indicativo=true}
end
return P
