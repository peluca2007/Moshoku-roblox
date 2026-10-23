-- Conteúdo puro da ajuda F5; não depende de Instances, rede ou regras mutáveis.
-- Fontes: AberturaFluxo/CriacaoRapidaView/RunView/ViagemView, EncontroAutonomoView,
-- BoardView (somente mesa), Mundo/Npcs e RunTreinadores/TreinadorView.
local abas = {
	{
		id = "inicio", titulo = "Primeiros passos",
		paragrafos = {
			"1. Crie seu aventureiro: escolha a raça, o visual e o nome. O resto da ficha já vem pronto e você pode ajustá-lo depois.",
			"2. Você começa no portão norte da vila. Siga o marcador dourado e fale com um mestre.",
			"3. Aceite a prova do mestre e cumpra o desafio: você aprende seu primeiro caminho de poder.",
			"4. Explore a pé: Floresta pela trilha e Ruínas pela passagem das montanhas. Um dia dura 8 minutos; em combate o relógio pausa. Eventos surgem ao entrar em trechos do caminho.",
		},
	},
	{
		id = "combate", titulo = "Explorar e lutar",
		paragrafos = {
			"Explore as trilhas e observe as patrulhas visíveis. Se uma patrulha alcançar você, a grade de combate nasce no local. Tenha uma ficha criada.",
			"Espere sua vez. Use Atacar (ou Disparar) no alvo; para mover, escolha uma casa livre na grade ou um dos botões Mover. Alcance, ações e movimento são limitados.",
			"Use Encerrar turno quando terminar. Sua vez também termina ao esgotar o tempo.",
			"Para fugir, chegue à borda da grade e use Fugir na sua vez, com uma Ação disponível. Há um teste de Atletismo: falhar encerra sua vez; fugir não dá recompensa.",
			"Surpresa: alcançar a patrulha pelas costas sem ser detectado dá prioridade na primeira rodada e deixa o alvo Desprevenido até começar a agir.",
		},
	},
	{
		id = "vila", titulo = "Vila",
		paragrafos = {
			"Aproxime-se dos NPCs e use a interação indicada na tela. No quadro perto da praça, aceite caçadas repetíveis para ganhar ouro e PA de aprimoramento.",
			"Dona Brisa, na taverna: Comprar/Vender e Missões. Mestre Torr, na forja: Comprar/Vender equipamentos.",
			"Mestre Hanzo, no dojo: Treinar no dojo. Consulte os requisitos e o custo antes de aceitar a provação.",
			"Mestres da vila: cada um ensina um caminho depois de uma prova. Passar custa 1 dia da expedição e nenhum ponto. Quem já tem um caminho pode aprender um segundo com outro mestre.",
		},
	},
	{
		id = "controles", titulo = "Controles",
		paragrafos = {
			"Teclado/mouse: clique nos botões e nas casas da grade. Nas interações do mundo, use a tecla mostrada no aviso. Não há atalho de teclado para Atacar ou Encerrar turno no combate de exploração.",
			"Toque: toque nos botões, avisos de interação e casas da grade; deslize listas para ler. Na ajuda, toque numa aba e deslize o texto.",
			"Controle: navegue pelos botões com a seleção de interface do Roblox e confirme com A. Nos NPCs, siga o botão indicado no aviso. Na ajuda, B fecha o painel.",
			"Somente na visão da mesa: M alterna a visão durante a partida; WASD move a câmera e a roda do mouse ajusta o zoom. No toque, arraste para mover a câmera e faça pinça para zoom. Clique direito, Q ou B do controle cancela a mira/seleção da mesa.",
		},
	},
}

for _, aba in abas do
	table.freeze(aba.paragrafos)
	table.freeze(aba)
end

return table.freeze({ abas = table.freeze(abas), dica = "Toque em AJUDA para abrir o guia", duracaoDica = 8 })
