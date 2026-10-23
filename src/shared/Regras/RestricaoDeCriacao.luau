-- Gancho entre a run e a criação do personagem pessoal (J1): enquanto há uma run, a árvore inicial é a que a
-- run deu (oferta escolhida ou ficha pronta). A run registra a função; a criação a consulta. Sem run, nada
-- muda. Puro: só guarda uma função, sem Instances.
local Restricao = {}

local funcao = nil

-- fn(player) -> arvoreId | nil, mensagemDeBloqueio | nil, semArvore | nil
--   arvoreId        a criação só vale com startingTreeId == "tree/<arvoreId>"
--   nil, mensagem   a criação fica bloqueada com essa mensagem (ex.: escolher a árvore antes)
--   nil, nil, true  P2: a run ainda não deu árvore (aprende-se com um mestre); a ficha nasce SEM árvore
--   nil             sem restrição
function Restricao.definir(fn)
	funcao = fn
end

-- Devolve (arvoreIdDoCatalogo | nil, mensagem | nil, semArvore | nil). Erro na função da run bloqueia por segurança.
function Restricao.consultar(player)
	if funcao == nil then return nil, nil, nil end
	local ok, arvore, mensagem, semArvore = pcall(funcao, player)
	if not ok then return nil, "A run não conseguiu confirmar sua árvore inicial. Tente novamente." end
	if type(arvore) == "string" and arvore ~= "" then return "tree/" .. arvore, nil end
	if type(mensagem) == "string" and mensagem ~= "" then return nil, mensagem end
	return nil, nil, semArvore == true
end

return Restricao
