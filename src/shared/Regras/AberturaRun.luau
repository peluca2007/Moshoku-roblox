-- Política da abertura P2. Cliente apresenta; servidor aplica ao iniciar.
local Shared = game:GetService("ReplicatedStorage").Shared
local Conta = require(Shared.Regras.RunConta)
local Povoamento = require(Shared.Mundo.PropsPovoamento)
local Abertura = {}

Abertura.MODOS = table.freeze({
	{ id = "semArvore", titulo = "Aprender na vila · Recomendado", descricao = "Comece livre e aprenda seu primeiro caminho com um mestre, passando por uma provação." },
	{ id = "zero", titulo = "Escolher seu caminho", descricao = "Escolha uma das especialidades sorteadas antes de explorar a vila." },
	{ id = "pronto", titulo = "Aventureiro pronto", descricao = "Receba uma construção definida e desafios pessoais; ao terminar, ganhe mais moedas." },
})

function Abertura.modo(conta, solicitado)
	if not Conta.modosLiberados(conta) then return "semArvore" end
	for _, modo in Abertura.MODOS do if modo.id == solicitado then return solicitado end end
	return "semArvore"
end

Abertura.RECUO_PORTAO = 16

function Abertura.nascimento()
	-- Dentro da entrada, longe o bastante do telhado do portão para a câmera do mundo (que fica
	-- ao norte, no alto) enxergar o personagem desde o primeiro quadro. Olhar para o sul (-Z).
	return { x = 0, y = 3.5, z = Povoamento.PORTAO_NORTE - Abertura.RECUO_PORTAO }
end

return Abertura
