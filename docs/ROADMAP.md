# Escopo e evolução

## Referência do RPG

Consulta local: projeto `Moshoku tensei rpg`, README.md, src/lib/dice.ts e src/lib/combatSim.ts. O simulador original também declara simplificações; não presumir que ele representa todas as regras. Não houve auditoria completa do livro nesta etapa.

Confirmado nessa consulta: progressão por PA em vez de nível; árvores com sete patamares; mana; d20 com vantagem/desvantagem; condições elementais; cântico com efeito mecânico. Essas regras orientam a futura adaptação, mas ainda não estão todas implementadas.

## Regras provisórias implementadas

PV 30, mana 12, inimigo 22 PV; três pontos de ação por turno; uma casa por ponto; ataque custa dois; espada alcance um; magia alcance cinco e custa três de mana; d20+4 contra defesa 12; dano 1d6+2 ou 1d8+2; crítico adiciona um dado; defesa aumenta CA em quatro por uma rodada. Movimento só em linha reta, sem diagonais nem travessia do inimigo. Inimigo aproxima até três casas e ataca adjacente. Sorteio a cada dois segundos no campo, chance 30%.

Esses números são escolhas de protótipo, não regras extraídas do livro. PA de recompensa aparece apenas como mensagem experimental; não é acumulado nem salvo. Sem iniciativa individual, reações, condições, cântico ou progressão real.

## Decisão de 08/10/2026: prioridade é mestrar

O autor decidiu usar o Roblox primeiro como mesa para mestrar. Etapas da mesa (M1–M5) estão em `docs/TAREFAS.md`. As etapas abaixo descrevem o modo jogo autônomo e ficam pausadas; motor de regras, ficha e grupo construídos para a mesa devem ser reaproveitáveis por elas. Ao portar combate automático no futuro, cada combatente deve ter um controlador (jogador, mestre ou IA) em vez de turno inimigo fixo.

## Etapas do modo jogo (pausadas)

1. **Base atual:** abrir no Studio e concluir roteiro de TESTES.md sem erros. Corrigir câmera, controles e ciclo de sessão antes de crescer.
2. **Fidelidade do combate:** mapear fórmulas e economia do livro; definir tamanho da casa em metros; portar iniciativa, recursos, vantagem e reações. Testes determinísticos das regras e revisão de exemplos do livro.
3. **Primeira região jogável:** área segura, região de encontro, três criaturas com fichas reais e uma missão. Arena com obstáculos e caminhos; transições visuais; interface acessível no celular.
4. **Ficha e progressão:** PA real, uma árvore completa e persistência versionada. Verificar reconexão e falhas de salvamento antes de expandir árvores.
5. **Cânticos/minigames:** experimentar ritmo ou sequência para conceder vantagem, mantendo o dado. Definir alternativa acessível e validar duração no servidor.
6. **Cooperativo:** grupo, iniciativa por participante, desconexão durante turno, bloqueio de ações fora da vez e orçamento de arenas. Testes com múltiplos clientes.
7. **Conteúdo e mundo amplo:** novas regiões, árvores e criaturas após medir desempenho e validar salvamento. Publicação só após testes e decisão do autor.

## Decisões a combinar antes das próximas etapas

- Controle de um personagem ou grupo? Primeiro protótipo usa um personagem.
- Encontros solo ou compartilhados? Primeiro protótipo usa sessões individuais.
- Fidelidade exata ao livro versus mudanças de ritmo? Primeiro protótipo usa números provisórios.
- Câmera totalmente vertical versus inclinada? Primeiro protótipo usa visão elevada inclinada.
