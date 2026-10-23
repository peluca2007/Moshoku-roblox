# Como mestrar na Mesa Moshoku

Guia de uso para o mestre. O jogo entra atualmente pela sala social: veja `docs/SALA.md` para pegar fichas, prontidão, escudo, controles e início. As ferramentas abaixo continuam disponíveis durante a sessão; detalhes técnicos em `docs/MESA.md`.

## Antes da sessão

1. **Fichas dos jogadores:** na ficha do site, abra **Exportar, compartilhar e imagens** e clique em **Copiar para a mesa Roblox**. O código vai para a área de transferência: o jogador manda para você (pelo Discord, por exemplo) e você cola no painel da mesa.
   - Alternativa com o arquivo `.mtficha` ou o link de compartilhar: `powershell -File tools/ficha-para-mesa.ps1 "arquivo.mtficha"` gera o mesmo código.
2. **NPCs:** abra a ficha do NPC no site e use o mesmo botão, ou use a ferramenta com os arquivos `.mtficha` (como os da pasta da campanha). Para criaturas simples, crie a ficha direto na mesa (nome, PV e mana).
3. **Abrir a mesa:** abra o place no Studio ou entre no jogo publicado. Na sala atual, o primeiro participante é mestre; pode transferir o posto pelo escudo, e sua saída abre eleição consentida. Permissão administrativa é independente. A lista `MESTRES` pertence ao modo legado de mesa sem lobby.

## A tela

- **Tecla M** ou botão **Visão da mesa:** câmera de cima. WASD move a câmera, roda do mouse dá zoom. No celular: arrastar move, pinça dá zoom.
- **Painel à direita:** dados, registro, ficha selecionada e, para o mestre, as ferramentas. **Recolher** esconde o painel.
- **Clique numa ficha** para selecioná-la (contorno azul). Com uma ficha sua selecionada, **clique numa casa** para movê-la. **Clique direito** desmarca. A ficha da vez no combate tem contorno amarelo.

## Durante a sessão

### Fichas
- **Importar:** selecione uma casa vazia, cole o código em **Colar código de ficha** e clique em **Importar na casa selecionada**. Escolha o **Dono** no formulário antes, para o jogador poder mover a própria ficha.
- **Atualizar:** se a ficha mudou no site, gere o código de novo, selecione a ficha na mesa e clique em **Atualizar ficha selecionada**. Posição e dono não mudam.
- **Criar à mão:** em **Ferramentas do mestre**, preencha nome, tipo, PV e mana e envie.
- **Ocultar:** fichas ocultas só aparecem para o mestre, semitransparentes. Use para emboscadas; **Oculta: não** revela para todos.
- **Mostrar atributos:** desligado, os jogadores não veem o PV e a mana daquele NPC.
- **PV e mana:** botões −5/−1/+1/+5 na ficha selecionada. O jogador ajusta a própria ficha; o mestre, todas.

### Seu avatar é a sua ficha
- Quando o mestre cria ou importa uma ficha de jogador e escolhe você como **Dono**, o seu próprio avatar do Roblox vai até a casa da ficha e passa a ser ela no tabuleiro. Nome, PV e condições aparecem sobre a sua cabeça.
- Para andar, clique na casa no tabuleiro (Visão da mesa): o avatar caminha até lá. Enquanto for a ficha, ele não anda com WASD.
- NPCs do mestre continuam miniaturas.

### Dados
- Digite a fórmula (`1d20+4`, `2d6+3`, `1d8+1d6-1`) ou use os atalhos. **Modo** alterna Normal, Vantagem, Desvantagem e as Absolutas (Cap. 4).
- **Rolagem secreta:** só quem rolou e o mestre veem. Rolagem secreta do mestre: só o mestre vê.
- 20 natural é crítico e 1 natural é falha, sempre no dado escolhido.

### Combate
- **Rolar iniciativa:** marque as fichas na lista de **Iniciativa** e clique em **Rolar iniciativa**. A mesa rola d20 + Agilidade de cada ficha importada, com vantagem quando o antecedente dá, e começa o combate. Fichas sem dados do site rolam d20 + 0.
- **Iniciativa à mão:** digite os valores na lista e use **Iniciar / reiniciar o combate**.
- **Próximo turno:** o mestre avança; o jogador encerra o próprio turno em **Encerrar meu turno**.
- **Movimento:** o registro mostra quantas casas e metros a ficha andou (1 casa = 1,5 m, provisório). O mestre julga se valeu.

### Condições do livro
- Na ficha selecionada, escolha a condição (busca pelo nome), acrescente uma nota se quiser ("CD 14 para soltar") e adicione. Condições acumuláveis (Dose, Quebrantado) têm +/−; a Dose vira Atordoado ao chegar a 3, como no livro.
- Não há contagem automática de rodadas: o livro escreve a duração em texto. No início do turno de cada ficha, a mesa lembra o mestre e o dono do que cobrar (ex.: "Em Chamas: sofre 1d6 de dano") e de como a condição termina.

### Mapa e névoa
- Em **Mapa**, escolha um pincel e clique ou arraste no tabuleiro: **Parede** (jogadores não entram), **Terreno difícil** e **Água** (só visuais, o mestre aplica a regra), **Apagar terreno**.
- **Névoa** cobre casas: os jogadores veem a casa escura, mas não as fichas dentro dela. **Revelar** descobre. **Cobrir tudo com névoa** e **Revelar tudo** pedem confirmação.
- Clique de novo no pincel ativo para voltar a selecionar fichas.

## Salvar a campanha

- Em **Campanha**, escolha o espaço (1 a 5) e clique em **Salvar**. A partir daí a mesa salva sozinha a cada minuto quando algo muda, e também quando o servidor fecha.
- Na próxima sessão: escolha o espaço e clique em **Carregar** duas vezes (confirmação). Fichas, posições, condições, mapa, névoa e combate voltam.
- **Conflito:** se outra sessão gravou no mesmo espaço, a mesa para de salvar sozinha e oferece **Salvar mesmo assim**. Na dúvida, carregue o espaço antes.
- O espaço 5 é usado pelos testes automáticos. Prefira os espaços 1 a 4 para campanhas.
- Salvar exige o jogo publicado e, no Studio, "Permitir acesso do Studio aos serviços de API" ligado.

## Jogar com os amigos

O jogo publicado começa privado: só você entra. Para os jogadores entrarem é preciso mudar o acesso nas **Configurações da experiência**. A decisão é sua; nada disso é feito automaticamente:
- **Permissões:** deixar a experiência pública (qualquer um pode achar e entrar) ou dar acesso a pessoas específicas, conforme as opções que a sua conta oferecer.
- **Servidores privados:** permitem que só convidados entrem numa instância. Podem ser gratuitos. No lobby, vale a ordem de entrada/transferência/eleição da sala.
- Voz: o chat de voz do Roblox tem restrição de idade. Muitas mesas usam o Discord para a voz e o Roblox para o tabuleiro.

## Quando algo der errado

- Mensagens vermelhas no registro explicam pedidos recusados (casa ocupada, sem permissão, fórmula inválida).
- Erros de script aparecem na janela **Saída** do Studio (menu Janela → Saída) ou no console **F9** dentro do jogo.
- Os testes automáticos ficam em `docs/TESTES.md`; as IAs rodam `tools/testar.ps1` e o playtest pelo Studio antes de cada entrega.


## Treino, Desafios e PvP

Esses modos são preparados pelo mestre no escudo da sala, inclusive para jogar sozinho. O checklist informa quem ainda precisa escolher ficha ou confirmar prontidão. Seis vagas são automáticas; o mestre pode autorizar até dez participantes e cópias de personagens.

- **Treino:** pratica habilidades contra bonecos; recursos seguem as regras específicas do modo.
- **Desafios:** três níveis de encontros, com grupo e opção de o mestre controlar criaturas.
- **PvP:** pelo menos dois jogadores; cada um por si ou equipes definidas no escudo.

A barra de ações começa com os ataques básicos disponíveis. Na Visão da mesa, o tabuleiro se centraliza na área livre entre os painéis. Para cancelar mira, use **Cancelar mira**, clique direito, Q ou B do controle; Esc e Tab ficam com o Roblox. MENU → Sair da partida encerra seu Treino ou permite desistir de uma luta, conforme validação do servidor.

Para testar várias pessoas localmente, use **Test → Clients and Servers** no Studio. Publicar e alterar acesso/permissões continuam sendo decisões do Pedro, sem execução automática pelas IAs. Testes e limites atuais estão em `docs/TESTES.md`.
