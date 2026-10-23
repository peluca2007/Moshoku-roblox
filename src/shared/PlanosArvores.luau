-- Orientação de jogo, não progressão nem cálculo. Apenas técnicas já executáveis.
return table.freeze({
	fogo = table.freeze({
		estilo = "Acenda e pressione",
		passos = {
			{ id = "ability/fogo/Principiante/bola-de-fogo", dica = "Acenda o alvo com Bola de Fogo (2 Ações)." },
			{ id = "ability/fogo/Principiante/brasa", dica = "Complete a vez com Brasa (1 Ação): +1d4 contra Em Chamas." },
			{ id = "ability/fogo/Principiante/fagulha", dica = "Prepare uma passagem com Fagulha; um aliado de Vento pode empurrar alguém através dela." },
		},
		cuidado = "O fogo pode atingir aliados. Fagulha não incendeia o alvo; o bônus da Brasa exige Em Chamas.",
	}),
	agua = table.freeze({
		estilo = "Prepare com água, castigue com gelo",
		passos = {
			{ id = "ability/agua/Principiante/respingo", dica = "Abra a vez com Respingo (1 Ação) para deixar o alvo Molhado." },
			{ id = "ability/agua/Principiante/impacto-de-gelo", dica = "Use Impacto de Gelo (2 Ações): a parcela de frio dobra contra Molhado." },
			{ id = "ability/agua/Principiante/nevoa-densa", dica = "Use Névoa Densa para cortar linhas de visão e proteger a aproximação." },
		},
		cuidado = "Dano ígneo seca Molhado. Combine a ordem dos ataques com seus aliados.",
	}),
	vento = table.freeze({
		estilo = "Escolha onde a luta acontece",
		passos = {
			{ id = "ability/vento/Principiante/empurrao", dica = "Alinhe-se antes de Empurrão: ele afasta o alvo de você, até 4 casas se falhar a resistência." },
			{ id = "ability/vento/Principiante/rajada-curta", dica = "Depois do controle (2 Ações), use Rajada Curta (1 Ação) para completar a vez." },
			{ id = "ability/vento/Principiante/passo-de-vento", dica = "Passo do Vento reposiciona para o próximo ângulo. Empurrar através de Fagulha ou Muro de Chamas ativa o perigo." },
		},
		cuidado = "Paredes e fichas interrompem empurrões. Controle exige planejar o caminho, além do alvo.",
	}),
	terra = table.freeze({
		estilo = "Prenda e domine o terreno",
		passos = {
			{ id = "ability/terra/Principiante/atoleiro", dica = "Atoleiro dificulta o terreno ao redor e pode deixar inimigos Atolados." },
			{ id = "ability/terra/Principiante/bala-de-pedra", dica = "Na próxima vez, Bala de Pedra acerta automaticamente quem continuar Atolado." },
			{ id = "ability/terra/Principiante/muro-de-terra", dica = "Muro de Terra fecha uma passagem: preserve uma saída para o seu grupo." },
		},
		cuidado = "Atoleiro também alcança aliados no raio. O terreno difícil continua depois da resistência.",
	}),
})
