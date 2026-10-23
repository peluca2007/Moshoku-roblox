-- GERADO por tools/gerar-catalogo.mts a partir do site do livro. Não edite: rode o gerador.
-- Domínio GruposDeArma.
local function congelar(t)
	for _, v in t do
		if type(v) == "table" and not table.isfrozen(v) then
			congelar(v)
		end
	end
	return table.freeze(t)
end
return congelar({
	{
		id = "weapon-group/espadas",
		kind = "weapon-group",
		sourceId = "espadas",
		sourceRef = {
			path = "src/data/weaponGroups.ts",
			symbol = "WEAPON_GROUPS",
			selector = "WEAPON_GROUPS[id=espadas]",
		},
		data = {
			id = "espadas",
			name = "Espadas",
			description = "A lâmina longa de gume, de uma ou duas mãos. O treino é de guarda, distância e fio — quem sabe espada longa sabe espadão, e é a mesma escola.",
			examples = {
				"Espada Curta",
				"Rapieira",
				"Espada Longa",
				"Espadão / Montante",
				"Katana",
			},
		},
	},
	{
		id = "weapon-group/laminas-curtas",
		kind = "weapon-group",
		sourceId = "laminas-curtas",
		sourceRef = {
			path = "src/data/weaponGroups.ts",
			symbol = "WEAPON_GROUPS",
			selector = "WEAPON_GROUPS[id=laminas-curtas]",
		},
		data = {
			id = "laminas-curtas",
			name = "Lâminas Curtas",
			description = "Punho fechado no cabo, alcance de um braço. Não é espada pequena: é outro ofício — corpo colado, ângulo escondido, e a mão que não segura a lâmina importa tanto quanto a que segura.",
			examples = {
				"Adaga",
				"Punhal",
				"Faca de Arremesso",
				"Kukri",
			},
		},
	},
	{
		id = "weapon-group/machados-e-marretas",
		kind = "weapon-group",
		sourceId = "machados-e-marretas",
		sourceRef = {
			path = "src/data/weaponGroups.ts",
			symbol = "WEAPON_GROUPS",
			selector = "WEAPON_GROUPS[id=machados-e-marretas]",
		},
		data = {
			id = "machados-e-marretas",
			name = "Machados e Marretas",
			description = "Peso na ponta. O golpe não corta por fio, corta por inércia — e quem erra com um machado não recupera a guarda no mesmo tempo de quem erra com uma espada.",
			examples = {
				"Machado de Batalha",
				"Machadinha",
				"Martelo de Guerra",
				"Maça",
				"Foice de Guerra",
			},
		},
	},
	{
		id = "weapon-group/hastes",
		kind = "weapon-group",
		sourceId = "hastes",
		sourceRef = {
			path = "src/data/weaponGroups.ts",
			symbol = "WEAPON_GROUPS",
			selector = "WEAPON_GROUPS[id=hastes]",
		},
		data = {
			id = "hastes",
			name = "Hastes",
			description = "Alcance antes de tudo. Mantém o inimigo onde você quer e cobra caro de quem tenta entrar. É também o grupo do cajado de combate — o bastão do mago que aprendeu a usá-lo como arma.",
			examples = {
				"Lança",
				"Alabarda",
				"Cajado de Combate",
				"Naginata",
			},
		},
	},
	{
		id = "weapon-group/arcos-e-bestas",
		kind = "weapon-group",
		sourceId = "arcos-e-bestas",
		sourceRef = {
			path = "src/data/weaponGroups.ts",
			symbol = "WEAPON_GROUPS",
			selector = "WEAPON_GROUPS[id=arcos-e-bestas]",
		},
		data = {
			id = "arcos-e-bestas",
			name = "Arcos e Bestas",
			description = "Tiro tenso, a corda armazenando o golpe. Puxar arco é força de costas treinada; besta troca essa força por tempo de recarga. O treino de mira é o mesmo, e por isso andam juntos.",
			examples = {
				"Arco Curto",
				"Arco Longo",
				"Besta",
				"Besta Leve",
			},
			alcance = {
				normal = 24,
				longo = 90,
			},
		},
	},
	{
		id = "weapon-group/arremesso",
		kind = "weapon-group",
		sourceId = "arremesso",
		sourceRef = {
			path = "src/data/weaponGroups.ts",
			symbol = "WEAPON_GROUPS",
			selector = "WEAPON_GROUPS[id=arremesso]",
		},
		data = {
			id = "arremesso",
			name = "Arremesso",
			description = "O que sai da mão e não volta. Peso, giro e leitura de vento — nada disso se aprende puxando corda, e é por isso que não é o mesmo grupo dos arcos.",
			examples = {
				"Funda",
				"Dardo",
				"Azagaia",
				"Machadinha de Arremesso",
			},
			alcance = {
				normal = 9,
				longo = 27,
			},
		},
	},
	{
		id = "weapon-group/flexiveis",
		kind = "weapon-group",
		sourceId = "flexiveis",
		sourceRef = {
			path = "src/data/weaponGroups.ts",
			symbol = "WEAPON_GROUPS",
			selector = "WEAPON_GROUPS[id=flexiveis]",
		},
		data = {
			id = "flexiveis",
			name = "Flexíveis",
			description = "Arma que não é rígida: chicote, corrente, foice presa a corda. A mais difícil de todas, porque a arma continua se movendo depois que você parou — e acerta quem a empunha com a mesma facilidade.",
			examples = {
				"Chicote",
				"Corrente de Combate",
				"Kusarigama",
			},
		},
	},
	{
		id = "weapon-group/desarmado-e-improvisado",
		kind = "weapon-group",
		sourceId = "desarmado-e-improvisado",
		sourceRef = {
			path = "src/data/weaponGroups.ts",
			symbol = "WEAPON_GROUPS",
			selector = "WEAPON_GROUPS[id=desarmado-e-improvisado]",
		},
		data = {
			id = "desarmado-e-improvisado",
			name = "Desarmado e Improvisado",
			description = "O punho, o cotovelo, o joelho — e a cadeira, a garrafa, a pedra do chão. Todo personagem nasce proficiente aqui: ninguém precisa de escola pra dar um soco ou quebrar um banco na cabeça de alguém.",
			examples = {
				"Ataque Desarmado",
				"Objeto Improvisado",
				"Cajado / Foco Arcano",
			},
		},
	},
	{
		id = "weapon-group/escudos",
		kind = "weapon-group",
		sourceId = "escudos",
		sourceRef = {
			path = "src/data/weaponGroups.ts",
			symbol = "WEAPON_GROUPS",
			selector = "WEAPON_GROUPS[id=escudos]",
		},
		data = {
			id = "escudos",
			name = "Escudos",
			description = "O único grupo que não ataca. Escudo não é armadura que se veste, é arma que se empunha: sem treino ele ocupa a mão e atrapalha; com treino ele é a diferença entre levar o golpe e não levar.",
			examples = {
				"Escudo",
				"Escudo Leve",
				"Pavês",
			},
		},
	},
})
