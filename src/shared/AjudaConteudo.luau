-- Conteúdo puro da ajuda; não depende de Instances, rede ou regras mutáveis.
-- Descreve o jogo atual (docs/DIRECAO.md §1): cidade sem combate, portas para áreas feitas de passos,
-- combate por turnos, acampamento, escolha de caminho por voto e a anomalia de mana com prazo.
-- Só promete o que já existe; o resto fica de fora até ser implementado.
local abas = {
	{
		id = "inicio", titulo = "Primeiros passos",
		paragrafos = {
			"1. Crie seu aventureiro: escolha a raça, o visual e o nome. O resto da ficha já vem pronto e você pode ajustá-lo depois.",
			"2. A missão principal: uma anomalia de mana no céu cresce a cada dia e estoura em cerca de 30 dias. O prazo não corre sozinho: as suas ações é que gastam dias.",
			"3. A cidade não tem combate. Fale com os mestres, compre e venda, aceite missões e procure a porta do esgoto.",
			"4. Descendo pela porta, o grupo atravessa uma área feita de passos. O chefe de cada área guarda um fragmento da anomalia.",
		},
	},
	{
		id = "combate", titulo = "Salas e combate",
		paragrafos = {
			"Nas salas com luta o combate é por turnos, na grade. Espere sua vez, escolha uma habilidade em Golpes, Apoio ou Tudo e depois o alvo; para mover, use Andar e clique numa casa livre. Alcance, ações e movimento são limitados.",
			"Use Encerrar turno quando terminar. Sua vez também termina ao esgotar o tempo.",
			"Vencer paga ouro. Depois da luta vem o acampamento: veja inventário e status e descanse. Descansar custa meio dia e, por enquanto, cabe no máximo 2 vezes por área.",
			"Cada troca de cenário (porta, fim de batalha) passa pela tela Viajando.",
		},
	},
	{
		id = "cidade", titulo = "Cidade e portas",
		paragrafos = {
			"Aproxime-se dos NPCs e use a interação indicada na tela. Dona Brisa, na taverna: Comprar/Vender e Missões. Mestre Torr, na forja: Comprar/Vender equipamentos.",
			"Mestres da cidade: cada um ensina um caminho depois de uma prova. Passar custa 1 dia da expedição e nenhum ponto. Mestre Hanzo, no dojo, treina: veja requisitos e custo antes de aceitar.",
			"Entrar numa área custa 1 dia; avançar de sala é grátis. Em cada bifurcação o grupo vota entre 2 ou 3 caminhos, ou em voltar à cidade.",
			"Voltar à cidade custa dias, e mais quanto mais fundo o grupo está. O ouro ganho fica com vocês: volte para entregar missão, vender e comprar.",
			"Com o fragmento do chefe, a cidade oferece Selar a anomalia, que encerra a campanha.",
		},
	},
	{
		id = "controles", titulo = "Controles",
		paragrafos = {
			"Teclado/mouse: clique nos botões e nas casas do tabuleiro. Nas interações do mundo, use a tecla mostrada no aviso. O botão MENU (ou Esc) abre e fecha o menu; DIÁRIO, CONTA e AJUDA ficam ao lado dele.",
			"Toque: toque nos botões, avisos de interação e casas do tabuleiro; deslize listas para ler. Na ajuda, toque numa aba e deslize o texto.",
			"Controle: navegue pelos botões com a seleção de interface do Roblox e confirme com A. Nos NPCs, siga o botão indicado no aviso. Na ajuda, B fecha o painel.",
			"Na luta: M alterna a visão do tabuleiro; WASD move a câmera e a roda do mouse ajusta o zoom. No toque, arraste para mover a câmera e faça pinça para zoom. Clique direito, Q ou B do controle cancela a mira/seleção.",
		},
	},
}

for _, aba in abas do
	table.freeze(aba.paragrafos)
	table.freeze(aba)
end

return table.freeze({ abas = table.freeze(abas), dica = "Toque em AJUDA para abrir o guia", duracaoDica = 8 })
