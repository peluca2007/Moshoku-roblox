-- Bônus somente para personagens criados pelos modos de jogo, nunca importações.
-- Não muda BC, dano, atributos ou os dados do livro. FIDELIDADE §7Q.
local B = { ACERTO = 2, CD = 3 }
function B.acerto(t) return if t.balanceamentoJogo then B.ACERTO else 0 end
function B.cd(t) return if t.balanceamentoJogo then B.CD else 0 end
return table.freeze(B)
