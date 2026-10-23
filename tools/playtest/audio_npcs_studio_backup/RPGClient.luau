local Client = script.Parent:WaitForChild("Client")
local MesaState = require(Client.MesaState)
MesaState.start()
require(Client.Efeitos).start()
task.spawn(require(Client.Ambiente).start) -- espera o cenário chegar; não segura o resto
require(Client.BoardView).start(MesaState)
require(Client.MesaPanel).start(MesaState)
-- Fatia A1 (Árvore do Fogo): barra de ações do turno e animações das magias.
require(Client.AcoesDoTurno).start(MesaState)
require(Client.Magias).start(MesaState)
-- ArvoresView fica fora da entrada por enquanto; T é a entrega da ficha no lobby.
-- A tela será retomada junto à criação de fichas (pedido do Pedro, 11/10/2026).
-- HUD de jogo: seu PV/PM sempre à vista e a ordem dos turnos.
require(Client.Hud).start(MesaState)
require(Client.BardoView).start(MesaState)
require(Client.ChefeView).start(MesaState)
-- Escolha de personagem (um por árvore inicial) e botão PERSONAGEM.
local escolha = require(Client.EscolhaView).start(MesaState)
local admin = require(Client.AdminView).start(MesaState)
local inicio = require(Client.InicioView).start(MesaState, escolha, admin)
local sala = require(Client.SalaView).start(MesaState)
require(Client.ResultadoView).start(MesaState, inicio, sala)
require(Client.AvisosJogo).start(MesaState)
require(Client.FeedbackCombate).start(MesaState)
require(Client.RitmoCombate).start(MesaState)
-- Pergunta de Reação (A14): Aparar, Guarda do Corpo, Couraça, Parede, Escudo, Interpor.
require(Client.ReacaoView).start(MesaState)
-- Quadro de desenho da Magia Teórica (A19).
require(Client.FormulaView).start(MesaState)
require(Client.SalaMonstrosView).start(MesaState)
MesaState.ready()

