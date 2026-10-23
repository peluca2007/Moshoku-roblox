-- GERADO por tools/gerar-catalogo.mts a partir do site do livro. Não edite: rode o gerador.
-- Manifesto do catálogo: versão de formato e de conteúdo, fontes com hash, contagens e exclusões.
local function congelar(t)
	for _, v in t do
		if type(v) == "table" and not table.isfrozen(v) then
			congelar(v)
		end
	end
	return table.freeze(t)
end
return congelar({
	formato = 2,
	conteudo = "sha256:d1f4f24f9a69a9fc5c855ed8a4b8975ac17bf5238a37cf6e15e4cac16fdac93e",
	exporterVersion = "gerar-catalogo 2.0.0",
	exporterDigest = "sha256:21967d6e4942e2325c7b830adfd90796a32fdd57a2542de5df127867060bca5c",
	sourceRevision = "4282186",
	sourceDirty = false,
	files = {
		{
			path = "src/data/backgrounds.ts",
			sha256 = "d281b727f94f2b7b3d3ea2c90e8c19faa9cb0c689430bfb79b1bcd5e5992c4c7",
		},
		{
			path = "src/data/bestiary.ts",
			sha256 = "baba2fa09f5b1f851a9ff230ab64daf7ebd8bbd1f1ea1777f4733e335d47f76e",
		},
		{
			path = "src/data/combinedSpells.ts",
			sha256 = "aef4af9ac1f94acfed2241e304136aed1612549f337c625270eadcd0c8efbf23",
		},
		{
			path = "src/data/compendioDeItens.ts",
			sha256 = "0eb1f0944ea7edc25ff41d036e65e06af8bad9221c84698be7261dec1fa7d609",
		},
		{
			path = "src/data/condicoes.ts",
			sha256 = "40da4f8364f165a7727a7650ad3916ab9d8b64e306aaedf223b43602d439e48e",
		},
		{
			path = "src/data/identidadeDasArvores.ts",
			sha256 = "caf13e31ccf01d418a71e96a01b64c1763e3c900189afea12e57d72bb7c3fc92",
		},
		{
			path = "src/data/preMadeMonsters.ts",
			sha256 = "0a79b61f610963088a3cfdc42f592503385c1efcd3c6ab164fb85b9cc72698d9",
		},
		{
			path = "src/data/races.ts",
			sha256 = "7b087f44109a71bd946bd3e81e82bf501b28b35dc64e9f179189f903c0b1c9f9",
		},
		{
			path = "src/data/shopItems.ts",
			sha256 = "3e456846e3efc555d7ccce5a78e441c736fa2694108d6cc7e5779e019cb11ca2",
		},
		{
			path = "src/data/skills.ts",
			sha256 = "8ece0104f819e5132fbc40e27fec36f993251295dd6e2b5415ffdaf36ffba738",
		},
		{
			path = "src/data/trees/agua.ts",
			sha256 = "e07c6b98084d29402184d5f582634c310c2257a5f0c0a6664d449eb83d7b9343",
		},
		{
			path = "src/data/trees/arquearia.ts",
			sha256 = "94e63ae4e0b13f85ef1454700ce156a053d0ef72b47cf82f06a06606f1570a58",
		},
		{
			path = "src/data/trees/bardo.ts",
			sha256 = "8bfb417c894f5ddbcc8c840c79d8400b0bf9d2b8318df2ac2f69ee79af8af0be",
		},
		{
			path = "src/data/trees/barreira.ts",
			sha256 = "9fbabd9466f10682852ead314533146084c6791898e1809651889742cbbe565b",
		},
		{
			path = "src/data/trees/cura.ts",
			sha256 = "18602798623df455b623d3e70283425c392de8caa711607e841023cdcb9e28cc",
		},
		{
			path = "src/data/trees/desintoxicacao.ts",
			sha256 = "82511da984c6d12a084311a83261ebd5418190fd4b8fcdee48b6b045af9db70a",
		},
		{
			path = "src/data/trees/escudos.ts",
			sha256 = "7f84d74bd165e47a5cca4a0d83447601501d7fe7ec4ba0586725f25a180c90d7",
		},
		{
			path = "src/data/trees/espada.ts",
			sha256 = "33f9432eec1f925caad6ab7783d52dc96020e0a4209189f7f25a9c9ce0777466",
		},
		{
			path = "src/data/trees/fogo.ts",
			sha256 = "bde2178871c78edda4845b61bf0f0e7d573ec939da7388c81cc532131829a0fd",
		},
		{
			path = "src/data/trees/index.ts",
			sha256 = "ad946f9fa43ac829418eb58367becf2904d0a38a0f0635f9859015bf429c714e",
		},
		{
			path = "src/data/trees/invocacao.ts",
			sha256 = "711a201c0858a275761a897f4fc2de8d19e9f9c4f339a6c56bc31d1c398e4fcf",
		},
		{
			path = "src/data/trees/ladino.ts",
			sha256 = "f58df756c560b94644002d5cb99e1582b5736fefc3547f83c16e43b9695b4598",
		},
		{
			path = "src/data/trees/lutador.ts",
			sha256 = "111e573ef08c833a69ca08a1ad445b54318c9799212113d860fccc6b12e5a3f9",
		},
		{
			path = "src/data/trees/norte.ts",
			sha256 = "b59bc6335656ea030936ca693f94066a8288d8387de2cd78b5bc9e277ced3b62",
		},
		{
			path = "src/data/trees/punho_fogo.ts",
			sha256 = "a3f6225ccabd70c8723b9025b02a5a19ab147f125e127f8b0649df25e4a8202a",
		},
		{
			path = "src/data/trees/shared.ts",
			sha256 = "cce09fba89ac9efe4950d281cf537fc65af603714d0d528e5ab4d4c68e5d42a9",
		},
		{
			path = "src/data/trees/suishin.ts",
			sha256 = "004adf7251ae510fff5b43df75cd14032675c223a5bac07b0ece5b47c08036ab",
		},
		{
			path = "src/data/trees/tatico.ts",
			sha256 = "62ad6b8323349412bbd5072e258b5140774eba739bb495751a15014c3afa382d",
		},
		{
			path = "src/data/trees/teorica.ts",
			sha256 = "6cf905ad6e73f639bf61e8aa1fb24abb8a9635303faa19d89fadaf425463b672",
		},
		{
			path = "src/data/trees/terra.ts",
			sha256 = "eab42e50fe39b9124c75b44b7ef11dd0f74fcdd09558bb909bb263fcf1d07cd0",
		},
		{
			path = "src/data/trees/vendaval.ts",
			sha256 = "65b8dd2241c3ded2377f30859b4f2c9010cfe24af88fd7b33a24b3c6579e9a25",
		},
		{
			path = "src/data/trees/vento.ts",
			sha256 = "a41dd0c41d3a02e50ffdbe961b5971b8d86c334917e376056c4bca0360e7282f",
		},
		{
			path = "src/data/weaponGroups.ts",
			sha256 = "7fb38187e7e12847a48f7b0d70ccb1015988886c420f9ca72c7699097296d425",
		},
		{
			path = "src/lib/combatReactions.ts",
			sha256 = "efbd2d58791b24364a0e01f0294cbe151df807dfe05c23fc8700226cfa0588ad",
		},
		{
			path = "src/lib/combatScenario.ts",
			sha256 = "41b89492596d11459c61d9302d1f99d590be6e1c5812cda82769724325fac58e",
		},
		{
			path = "src/lib/combatSim.ts",
			sha256 = "463272a8126ab44efed5e32034953e13e025d68c890f2fddfb9d6d01fc9530e7",
		},
		{
			path = "src/lib/combatSummons.ts",
			sha256 = "727f01ca76285d98db5453090b343a79e2e2c02b48a72a8ba9e9b4054e671c22",
		},
		{
			path = "src/lib/combatTrace.ts",
			sha256 = "95f6f02aa1a81f238372e39cc170252401445935bf65341a13a6e3cbd04c9841",
		},
		{
			path = "src/lib/combatWeapon.ts",
			sha256 = "df7e4a180cec03bf8092e517a57a5c14824696e93af42f5dd784f6845ad55d53",
		},
		{
			path = "src/lib/dice.ts",
			sha256 = "b2ab6f69ae155cd6235d901840cb556cbc4cf13b3b419177eace86e594dc1a06",
		},
		{
			path = "src/lib/encounterSim.ts",
			sha256 = "8e99b9097ea9298a22fa4e9e54a7286bf682d1962c6907d9204192d670f31018",
		},
		{
			path = "src/lib/magiaTeorica.ts",
			sha256 = "d3b195875b5d5ca1f81c527599ea2133edc1aaf5d7733196a55bded32f22fa91",
		},
		{
			path = "src/lib/rotuloDoPatamar.ts",
			sha256 = "96380b51a523bbb2bdfe5e4d33ca746ce01882ac1b6cf92ee7c0cf8f99390b01",
		},
		{
			path = "src/lib/simbolosTeoricos.ts",
			sha256 = "0d9fd8e906e3d919c7f37b7f677c7a47bf2046f8edeb484b64bf699e50602cdd",
		},
		{
			path = "src/lib/types.ts",
			sha256 = "089758df5929929301987cfe03a5cbae18e607f6ea6fd4e31aadd4118e515279",
		},
		{
			path = "src/lib/weaponDie.ts",
			sha256 = "92338b111ad55fbdd1a78e83faaefb07bfa66b201ee4a7c6b37ddc6734bff19f",
		},
		{
			path = "src/store/selectors.ts",
			sha256 = "c5b9f402f78fdb05b5245afe6ebc32858dce63331856adda23b58b48f5bcfed5",
		},
	},
	registros = {
		{
			path = "tools/registros/criaturas.json",
			sha256 = "ecbdb2dab94ae6b964be24c9232b294bc630c5c880f77c10bf18de8c94b7f1a5",
		},
		{
			path = "tools/registros/pericias.json",
			sha256 = "85816727fca49b1ce0748f3083a29c69bd60a2d01b6b687c0b934fe99d61becc",
		},
	},
	counts = {
		ability = 343,
		background = 13,
		["combined-spell"] = 11,
		condition = 28,
		creature = 28,
		item = 165,
		["item-list"] = 1,
		mastery = 114,
		race = 12,
		["race-upgrade"] = 24,
		rank = 114,
		skill = 20,
		subtable = 3,
		["subtable-entry"] = 22,
		talent = 289,
		tree = 19,
		["weapon-group"] = 9,
	},
	excluidos = {
		"src/data/trees/barreira.ts: árvore \"barreira\" não está em TREES",
		"src/data/trees/shared.ts (sem árvore exportada)",
	},
	adaptacoes = {
		"SHOP_ITEMS.price null → aVenda=false sem preço (8 itens; aVenda vem de estaAVenda)",
		"COMPENDIO_ITENS → lista de ids (subconjunto idêntico de SHOP_ITEMS, conferido na geração)",
	},
	camposComIdLocal = {
		"ability.requires, talent.requires (ids de habilidade ou talento da mesma árvore)",
		"ability.requiresRank.treeId (id de árvore)",
		"ability.grantsSkills, race.fixedSkills, background.fixedSkills, tree.grantedSkills, tree.masterySkillsWhenNotFirst, tree.proficiencies.periciasCobertas (nomes de perícia, aceitando 'Base (especialização)' só como referência textual; ver tools/registros/pericias.json)",
		"background.requiresSubtable (id de subtabela)",
		"tree.proficiencies.gruposDeArma (ids de grupo de arma)",
	},
})
