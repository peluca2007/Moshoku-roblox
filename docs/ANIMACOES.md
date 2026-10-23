# Animações de combate (A5)

Regra de ouro (pedido do Pedro, 09/10/2026): **a animação tem que fazer sentido com o que a técnica faz no livro.** Investida move o corpo; golpe tem impacto; provocar tem grito; disparo duplo puxa a corda duas vezes. Antes de animar uma técnica nova, leia o texto dela no catálogo (`src/shared/Livro/Dados/Arvores/`) e escolha o gesto pelo que ela *faz*, não pela árvore.

## Como funciona

- O servidor decide tudo e manda o **recibo**. O cliente só apresenta.
- `src/client/Corpo.luau`: cria um **fantasma local** do personagem (ou da miniatura) e esconde o corpo real **só nesta tela** (`LocalTransparencyModifier`). O fantasma avança, gira, levanta o braço, segura arma. Nada muda a posição, a ficha ou a colisão do corpo real. Rigs novos (`AnimationConstraint`) são convertidos em `Motor6D` no fantasma.
- `src/client/Gestos.luau`: um gesto por tipo de técnica (tabela `ESPEC`, chave = último trecho do ID). Magias sem entrada própria ganham a pose de conjuração (`apontar` ou `palmas`).
- `src/client/Coreografia.luau`: linha do tempo das cenas (efeitos, projéteis, impactos). O gesto devolve o instante em que o golpe chega e se o projétil padrão deve ser omitido.
- Orçamento: no máximo 6 fantasmas, 6 cenas, 420 peças. Cenas canceladas (fim do combate) devolvem o corpo real.
- A arma na mão do fantasma vem do nome da arma equipada, enviado no recibo (`recibo.arma`): espada, arma pesada, adaga ou arco.

## Técnicas e gestos

| Técnica | Gesto | O que se vê |
|---|---|---|
| Ataque básico (todos) | golpe | recua, avança, corta em arco na arma equipada, faíscas no alvo |
| Disparo (arma de longe, todos) | disparo | arco na mão, corda puxada, flecha com rastro |
| Corte de Braço | golpe preciso | preparo mais lento, linha fina branca sobre o membro, corte diagonal |
| Investida (Deus da Espada) | investida | corpo atravessa o campo até a casa de chegada, imagens residuais, linhas de velocidade, poeira, dois cortes largos |
| Golpe Contínuo | golpe ×3 | três cortes em ângulos diferentes, o último em X |
| Provocar (Deus da Água) / Provocar Ódio | grito | salto, braços abertos, três ondas de choque pelo chão, "!!" e fio vermelho em cada alvo |
| Provocar Ódio Soberano | grito + escudo | mesmo gesto, quarta onda, escudo erguido, tremor maior |
| Forma Quadrúpede | investida baixa | corpo rente ao chão em zigue-zague, três garras no alvo |
| Arremesso de Espada | arremesso | braço para trás, espada gira no ar e fica cravada no alvo |
| Golpe Baixo | golpe baixo | agacha, varre o chão com o corte, poeira |
| Investida Devastadora | investida pesada | arma enorme sobre a cabeça, corrida mais lenta, impacto com onda, rachaduras no chão e tremor forte |
| Golpe Circular | giro | corpo dá a volta, dois anéis de corte ao redor, faíscas em cada adjacente |
| Cabeçada | cabeçada | recua o tronco, projeta a cabeça, estrelinhas girando sobre o alvo |
| Golpe de Escudo | escudada | escudo na frente, onda de choque, poeira |
| Puxar (Cavalaria) | corrente | corrente de elos até o aliado e recolhe |
| Disparo Duplo | disparo ×2 | duas flechas com intervalo |
| Tiro de Contenção | disparo + prender | flecha e fios que prendem o chão sob o alvo |
| Lâmina de Gelo (conjurar) | empunhar | braço levantado, lâmina de gelo surge na mão |
| Lâmina de Gelo (atacar) | golpe de gelo | dois cortes azulados, floco de neve no impacto |
| Ação do invocado | golpe sem arma | garra em dois cortes |
| Magias (água, vento, terra, cura, desintoxicação, teórica, invocação, fogo) | conjuro | mão apontada para o alvo (ataque/efeito) ou palmas abertas com leve flutuação (cura, área, zona, invocação) e depois os efeitos da árvore |

O alvo de dano a um **personagem** também reage no corpo: o fantasma dele é jogado para trás, inclina e volta (miniaturas já recuavam).

## Dublagem

As falas e os nomes de arquivo estão em `docs/DUBLAGEM.md` (gerado por `tools/dublagem/gerar.py`). Quem age fala o nome da magia (ou o grito da técnica); quem apanha faz o som de dor. Só toca se o áudio tiver ID em `tools/dublagem/ids.json`. Só os **personagens do jogador local** falam: inimigos não têm voz humana.

## O que ainda não foi visto a olho

Em Edit a captura do Studio não desenha a cena; em Play desenha, e foi assim que os quadros abaixo foram conferidos. Por script ficou medido o resto: o fantasma percorre o trajeto da investida, as poses têm o sentido certo e o corpo real sempre volta. O ritmo em velocidade normal e as técnicas que não foram vistas quadro a quadro ainda pedem o olho do Pedro.

## Como inspecionar uma animação quadro a quadro (Studio)

Em Play, com o servidor MCP do Studio:
- `workspace:SetAttribute("CenaTempoFixo", 0.27)` congela todas as cenas nesse instante (segundos desde o início da cena). `nil` solta.
- `workspace:SetAttribute("EscalaDeTempoDasCenas", 20)` deixa tudo 20× mais lento.
- Recibo sintético pelo servidor: `ReplicatedStorage.Mesa:FireClient(jogador, "efeito", { habilidadeId = ..., casterId = ..., origem = {x, z}, trajeto = {...}, alvos = {{ id = ..., acertou = true, dano = 9 }} })`. Assim dá para ver qualquer técnica, mesmo que a ficha não a tenha.
- Esconda as ScreenGuis e ponha a câmera em `Scriptable` para enquadrar. A captura de tela do MCP desenha a cena 3D em Play.

Quadros conferidos em 09/10/2026:
- **Ataque básico**: o fantasma estende o braço com a espada até o boneco, com clarão dourado no ponto do golpe.
- **Investida**: corpo inclinado em plena corrida, com imagens residuais neon na cor da árvore.

Depois dessa inspeção, os cortes ficaram mais largos e grossos (com núcleo branco), as faíscas mais longas, entrou um clarão de impacto, e a lâmina da espada ficou maior. O golpe físico agora é dourado-claro, antes cinza e quase invisível no fundo escuro.


## Animações reais do personagem (A7)

O fantasma mantém Humanoid e Animator, então veste a roupa do avatar e toca as animações do pacote dele, lidas do script Animate (com os IDs padrão do Roblox como reserva):

| Gesto | Animação |
|---|---|
| golpe, giro, arremesso, investida (chegada) | `toolnone` segurando a arma, `toolslash` no corte |
| escudada, cabeçada, Forma Quadrúpede (chegada) | `toollunge` |
| investida (corrida) | `run` acelerado |
| conjurar apontando, provocar, puxar, disparo | `point` |
| conjurar com as palmas (cura, área, zona), Provocar Ódio Soberano | `cheer` |
| empunhar Lâmina de Gelo | `toolnone` |

Miniaturas (sem Humanoid) continuam com a pose por código.
