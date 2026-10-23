# Dublagem — falas para gravar

Gerado por `python tools/dublagem/gerar.py` a partir do catálogo do livro (cânticos) e de `tools/dublagem/falas_fisicas.json` (gritos). **Não edite este arquivo à mão**: edite o JSON e gere de novo.

## Como gravar e entregar

1. **Nome do arquivo = a coluna Arquivo**, em minúsculas, sem espaço nem acento, extensão `.ogg` (ou `.mp3`). O nome é a chave que o jogo usa.
2. **Duração**: grave perto do *Alvo (s)* e **nunca passe do Máx (s)**. O jogo toca a fala junto da animação; fala longa demais atropela o turno seguinte. Corte o silêncio do começo e do fim.
3. **Formato**: mono, 44,1 kHz, pico em −3 dB, sem música nem ruído de fundo. Uma fala por arquivo.
4. **Interpretação**: *cântico* = voz solene e ritmada, pode dividir em versos; *nome* = grito curto e seco; *grito* = voz de combate, projeção alta; *geral* = reações curtas.
5. **Enviar ao Roblox**: Creator Hub → Assets → Audio. O envio de áudio pode exigir verificação de conta e seguir as regras vigentes do Roblox; confira lá.
6. **Ligar ao jogo**: copie o número de cada áudio para `tools/dublagem/ids.json`, no formato `{"grito__deus-da-espada__investida-espada__01": "rbxassetid://123456"}`, e rode `python tools/dublagem/gerar.py`. Falas sem ID ficam mudas.

Os tempos do *Alvo* nos cânticos são estimativas (palavras ÷ 2,1 por segundo + 1 s); se a sua leitura solene for mais lenta, vale o Máx.

**Total: 134 falas.** Prioridade sugerida: `geral` e os gritos do ataque básico e do Deus da Espada (o que mais se repete); depois os `cantico` das magias que você mais usar.

## Falas gerais (reações)

| Arquivo | Quando toca | Fala | Alvo (s) | Máx (s) | ID |
|---|---|---|---|---|---|
| `geral__dor-leve__01.ogg` | ao sofrer dano comum | Argh! | 0.5 | 0.9 | — |
| `geral__dor-leve__02.ogg` | ao sofrer dano comum | Ugh! | 0.5 | 0.9 | — |
| `geral__dor-leve__03.ogg` | ao sofrer dano comum | Hn! | 0.4 | 0.7 | — |
| `geral__dor-forte__01.ogg` | ao sofrer acerto crítico ou dano grande | AAAARGH! | 1.0 | 1.5 | — |
| `geral__dor-forte__02.ogg` | ao sofrer acerto crítico ou dano grande | Aaaah! | 1.0 | 1.5 | — |
| `geral__queda__01.ogg` | ao cair no chão (condição Caído) | Uff! | 0.6 | 1.0 | — |
| `geral__esquiva__01.ogg` | quando o ataque erra ou resiste | Hah! Errou! | 0.9 | 1.4 | — |
| `geral__esquiva__02.ogg` | quando o ataque erra ou resiste | Tarde demais. | 1.0 | 1.5 | — |
| `geral__acerto-critico__01.ogg` | ao acertar um crítico | É ISSO! | 0.9 | 1.4 | — |
| `geral__acerto-critico__02.ogg` | ao acertar um crítico | Em cheio! | 0.9 | 1.4 | — |
| `geral__erro__01.ogg` | quando o próprio ataque erra | Droga! | 0.6 | 1.0 | — |
| `geral__erro__02.ogg` | quando o próprio ataque erra | Ainda não... | 0.9 | 1.4 | — |
| `geral__minha-vez__01.ogg` | no início do turno do jogador | Minha vez! | 0.8 | 1.2 | — |
| `geral__minha-vez__02.ogg` | no início do turno do jogador | Vamos lá. | 0.7 | 1.1 | — |
| `geral__cura-recebida__01.ogg` | ao receber cura | Obrigado. | 0.7 | 1.1 | — |
| `geral__cura-recebida__02.ogg` | ao receber cura | Isso ajudou. | 0.9 | 1.4 | — |
| `geral__concentracao-perdida__01.ogg` | ao perder o cântico por dano | O cântico... se perdeu! | 1.8 | 2.5 | — |
| `geral__inconsciente__01.ogg` | ao cair a 0 PV | Não... ainda não... | 1.8 | 2.5 | — |
| `geral__inconsciente__02.ogg` | ao cair a 0 PV | Eu... não posso... | 1.6 | 2.3 | — |
| `geral__vitoria__01.ogg` | ao vencer o encontro | Conseguimos! | 1.1 | 1.6 | — |
| `geral__vitoria__02.ogg` | ao vencer o encontro | Acabou. Estamos vivos. | 1.8 | 2.5 | — |
| `geral__derrota__01.ogg` | ao perder o encontro | Nos... derrotaram... | 1.8 | 2.5 | — |
| `geral__pedido-de-ajuda__01.ogg` | ao ficar com pouco PV | Preciso de ajuda! | 1.2 | 1.8 | — |

## Gritos das técnicas físicas

| Arquivo | Quando toca | Fala | Alvo (s) | Máx (s) | ID |
|---|---|---|---|---|---|
| `grito__deus-da-espada__corte-de-braco__01.ogg` | Corte de Braço: ao cortar o braço do alvo | Seu braço é meu! | 1.5 | 2.2 | — |
| `grito__deus-da-espada__corte-de-braco__02.ogg` | Corte de Braço: ao cortar o braço do alvo | Corte de Braço! | 1.2 | 1.8 | — |
| `grito__deus-da-espada__investida-espada__01.ogg` | Investida: ao disparar em direção ao alvo | Aaaaaah — INVESTIDA! | 1.8 | 2.5 | — |
| `grito__deus-da-espada__investida-espada__02.ogg` | Investida: ao disparar em direção ao alvo | Não vou parar! | 1.3 | 1.9 | — |
| `grito__deus-da-espada__golpe-continuo__01.ogg` | Golpe Contínuo: nos três cortes seguidos | Um... dois... TRÊS! | 1.8 | 2.5 | — |
| `grito__deus-da-espada__golpe-continuo__02.ogg` | Golpe Contínuo: nos três cortes seguidos | Sem parar, sem respirar! | 2.0 | 2.8 | — |
| `grito__deus-da-agua-corpo__provocar__01.ogg` | Provocar: grito que puxa o ódio | Aqui! Olhem para mim! | 1.8 | 2.5 | — |
| `grito__deus-da-agua-corpo__provocar__02.ogg` | Provocar: grito que puxa o ódio | Venham, covardes! | 1.5 | 2.2 | — |
| `grito__deus-do-norte__forma-quadrupede__01.ogg` | Forma Quadrúpede: ao correr agachado e atacar | Grrraaah! | 1.2 | 1.8 | — |
| `grito__deus-do-norte__forma-quadrupede__02.ogg` | Forma Quadrúpede: ao correr agachado e atacar | Como uma fera! | 1.2 | 1.8 | — |
| `grito__deus-do-norte__arremesso-de-espada__01.ogg` | Arremesso de Espada: ao arremessar a espada | Leve isso! | 1.0 | 1.5 | — |
| `grito__deus-do-norte__arremesso-de-espada__02.ogg` | Arremesso de Espada: ao arremessar a espada | Toma a minha espada! | 1.5 | 2.2 | — |
| `grito__deus-do-norte__bala-de-lagrimas__01.ogg` | Bala de Lágrimas: ao soprar o tempero nos olhos | Chore, então! | 1.1 | 1.6 | — |
| `grito__deus-do-norte__bala-de-lagrimas__02.ogg` | Bala de Lágrimas: ao soprar o tempero nos olhos | Bala de Lágrimas! | 1.4 | 2.0 | — |
| `grito__deus-do-norte__primeiros-socorros-de-campo__01.ogg` | Primeiros Socorros de Campo: ao socorrer um aliado | Aguenta firme, eu cuido disso! | 2.2 | 3.1 | — |
| `grito__deus-do-norte__golpe-baixo__01.ogg` | Golpe Baixo: ao varrer as pernas do alvo | Olhe para baixo! | 1.3 | 1.9 | — |
| `grito__deus-do-norte__golpe-baixo__02.ogg` | Golpe Baixo: ao varrer as pernas do alvo | Cai! | 0.7 | 1.1 | — |
| `grito__armas-pesadas__investida-devastadora__01.ogg` | Investida Devastadora: ao esmagar após a corrida | SAIAM DA FRENTE! | 1.5 | 2.2 | — |
| `grito__armas-pesadas__investida-devastadora__02.ogg` | Investida Devastadora: ao esmagar após a corrida | DEVASTAÇÃO! | 1.4 | 2.0 | — |
| `grito__armas-pesadas__agarrao__01.ogg` | Agarrão: ao agarrar o alvo | Peguei você! | 1.2 | 1.8 | — |
| `grito__armas-pesadas__golpe-circular__01.ogg` | Golpe Circular: ao girar a arma em volta de si | Todos de uma vez! | 1.5 | 2.2 | — |
| `grito__armas-pesadas__golpe-circular__02.ogg` | Golpe Circular: ao girar a arma em volta de si | Cheguem mais perto! | 1.5 | 2.2 | — |
| `grito__armas-pesadas__cabecada__01.ogg` | Cabeçada: ao dar a cabeçada | Toma essa! | 1.0 | 1.5 | — |
| `grito__armas-pesadas__cabecada__02.ogg` | Cabeçada: ao dar a cabeçada | CABEÇADA! | 1.1 | 1.6 | — |
| `grito__cavalaria-e-escudos__muralha-de-um__01.ogg` | Muralha da Companhia: ao erguer o escudo sobre os aliados | Atrás de mim! Ninguém passa! | 2.2 | 3.1 | — |
| `grito__cavalaria-e-escudos__golpe-de-escudo__01.ogg` | Golpe de Escudo: ao bater com o escudo | Para trás! | 1.0 | 1.5 | — |
| `grito__cavalaria-e-escudos__golpe-de-escudo__02.ogg` | Golpe de Escudo: ao bater com o escudo | Golpe de Escudo! | 1.4 | 2.0 | — |
| `grito__cavalaria-e-escudos__puxar__01.ogg` | Puxar: ao puxar o aliado para perto | Venha para cá! | 1.2 | 1.8 | — |
| `grito__cavalaria-e-escudos__provocar-odio__01.ogg` | Provocar Ódio: grito que puxa o ódio | Eu sou o seu inimigo! | 1.6 | 2.3 | — |
| `grito__cavalaria-e-escudos__provocar-odio__02.ogg` | Provocar Ódio: grito que puxa o ódio | É comigo que vocês vão lutar! | 2.0 | 2.8 | — |
| `grito__cavalaria-e-escudos__provocar-odio-soberano__01.ogg` | Provocar Ódio Soberano: grito soberano que domina a atenção | NENHUM DE VOCÊS VAI PASSAR POR MIM! | 2.8 | 3.8 | — |
| `grito__arquearia__disparo-duplo__01.ogg` | Disparo Duplo: ao soltar duas flechas | Duas de uma vez! | 1.4 | 2.0 | — |
| `grito__arquearia__disparo-duplo__02.ogg` | Disparo Duplo: ao soltar duas flechas | Não vai escapar! | 1.4 | 2.0 | — |
| `grito__arquearia__tiro-de-contencao__01.ogg` | Tiro de Contenção: ao acertar a perna do alvo | Fique onde está! | 1.3 | 1.9 | — |
| `grito__mesa__ataque-basico__01.ogg` | Ataque básico: ao golpear com a arma (todo personagem tem) | Hah! | 0.5 | 0.9 | — |
| `grito__mesa__ataque-basico__02.ogg` | Ataque básico: ao golpear com a arma (todo personagem tem) | Yaah! | 0.6 | 1.0 | — |
| `grito__mesa__ataque-basico__03.ogg` | Ataque básico: ao golpear com a arma (todo personagem tem) | Toma! | 0.6 | 1.0 | — |
| `grito__mesa__ataque-a-distancia__01.ogg` | Disparo: ao disparar a arma de longe | Hm! | 0.4 | 0.7 | — |
| `grito__mesa__ataque-a-distancia__02.ogg` | Disparo: ao disparar a arma de longe | Lá vai! | 0.8 | 1.2 | — |

## Nome da magia gritado

| Arquivo | Quando toca | Fala | Alvo (s) | Máx (s) | ID |
|---|---|---|---|---|---|
| `nome__agua__respingo__01.ogg` | Respingo: só o nome gritado, na hora de soltar | Respingo! | 1.2 | 1.8 | — |
| `nome__agua__bola-de-agua__01.ogg` | Bola de Água: só o nome gritado, na hora de soltar | Bola de Água! | 1.2 | 1.8 | — |
| `nome__agua__flecha-de-agua__01.ogg` | Flecha de Água: só o nome gritado, na hora de soltar | Flecha de Água! | 1.2 | 1.8 | — |
| `nome__agua__impacto-de-gelo__01.ogg` | Impacto de Gelo: só o nome gritado, na hora de soltar | Impacto de Gelo! | 1.2 | 1.8 | — |
| `nome__agua__lamina-de-gelo__01.ogg` | Lâmina de Gelo: só o nome gritado, na hora de soltar | Lâmina de Gelo! | 1.2 | 1.8 | — |
| `nome__agua__escudo-de-agua__01.ogg` | Escudo de Água: só o nome gritado, na hora de soltar | Escudo de Água! | 1.2 | 1.8 | — |
| `nome__agua__nevoa-densa__01.ogg` | Névoa Densa: só o nome gritado, na hora de soltar | Névoa Densa! | 1.2 | 1.8 | — |
| `nome__vento__rajada-curta__01.ogg` | Rajada Curta: só o nome gritado, na hora de soltar | Rajada Curta! | 1.2 | 1.8 | — |
| `nome__vento__lamina-de-vento__01.ogg` | Lâmina de Vento: só o nome gritado, na hora de soltar | Lâmina de Vento! | 1.2 | 1.8 | — |
| `nome__vento__empurrao__01.ogg` | Empurrão: só o nome gritado, na hora de soltar | Empurrão! | 1.2 | 1.8 | — |
| `nome__vento__passo-de-vento__01.ogg` | Passo de Vento: só o nome gritado, na hora de soltar | Passo de Vento! | 1.2 | 1.8 | — |
| `nome__vento__sopro-de-poeira__01.ogg` | Sopro de Poeira: só o nome gritado, na hora de soltar | Sopro de Poeira! | 1.2 | 1.8 | — |
| `nome__vento__vacuo-localizado__01.ogg` | Vácuo Localizado: só o nome gritado, na hora de soltar | Vácuo Localizado! | 1.2 | 1.8 | — |
| `nome__terra__pedrisco__01.ogg` | Pedrisco: só o nome gritado, na hora de soltar | Pedrisco! | 1.2 | 1.8 | — |
| `nome__terra__bala-de-pedra__01.ogg` | Bala de Pedra: só o nome gritado, na hora de soltar | Bala de Pedra! | 1.2 | 1.8 | — |
| `nome__terra__atoleiro__01.ogg` | Atoleiro: só o nome gritado, na hora de soltar | Atoleiro! | 1.2 | 1.8 | — |
| `nome__terra__muro-de-terra__01.ogg` | Muro de Terra: só o nome gritado, na hora de soltar | Pedra que dorme sob meus pés, levanta-te devagar, camada sobre camada, até que nada do que vier atrás de mim passe por cima. Muro de Terra! | 1.2 | 1.8 | — |
| `nome__terra__lanca-de-pedra__01.ogg` | Lança de Pedra: só o nome gritado, na hora de soltar | Lança de Pedra! | 1.2 | 1.8 | — |
| `nome__terra__mao-de-terra__01.ogg` | Mão de Terra: só o nome gritado, na hora de soltar | Mão de Terra! | 1.2 | 1.8 | — |
| `nome__cura__cura__01.ogg` | Cura: só o nome gritado, na hora de soltar | a força de se erguer de novo. Cura! | 1.2 | 1.8 | — |
| `nome__cura__estancar__01.ogg` | Estancar: só o nome gritado, na hora de soltar | Sangue que insiste em fugir por uma porta que não devia ter sido aberta, fica. Fogo que ainda come, para. Estancar! | 1.2 | 1.8 | — |
| `nome__cura__selar-a-ferida__01.ogg` | Selar a Ferida: só o nome gritado, na hora de soltar | Selar a Ferida! | 1.2 | 1.8 | — |
| `nome__cura__vigor-emprestado__01.ogg` | Vigor Emprestado: só o nome gritado, na hora de soltar | Vigor Emprestado! | 1.2 | 1.8 | — |
| `nome__desintoxicacao__purgar__01.ogg` | Purgar: só o nome gritado, na hora de soltar | O que entrou aqui sem ser convidado e se instalou como se a casa fosse sua: sai. Sai como quiseres, mas sai agora. Purgar! | 1.2 | 1.8 | — |
| `nome__desintoxicacao__antidoto__01.ogg` | Antídoto: só o nome gritado, na hora de soltar | Que a pureza da minha mana proteja este sangue contra qualquer veneno ou peçonha que tente cruzar a sua pele. Antídoto! | 1.2 | 1.8 | — |
| `nome__desintoxicacao__peconha__01.ogg` | Peçonha: só o nome gritado, na hora de soltar | Peçonha que dorme em toda raiz amarga deste mundo e só espera uma mão que saiba pedir: sobe por este braço e acha o sangue dele. Peçonha! | 1.2 | 1.8 | — |
| `nome__desintoxicacao__rosa-preta__01.ogg` | Rosa-Preta: só o nome gritado, na hora de soltar | Rosa dos jardins de Asura, entra neste sangue sem aviso e apaga-lhe a consciência como uma vela entre os dedos. Rosa-Preta! | 1.2 | 1.8 | — |
| `nome__teorica__dardo-arcano__01.ogg` | Dardo Arcano: só o nome gritado, na hora de soltar | Fixo a essência, digo o verbo e fecho a forma. Três palavras, e a mana não anda um passo fora delas. Dardo Arcano! | 1.2 | 1.8 | — |
| `nome__teorica__anteparo-teorico__01.ogg` | Anteparo: só o nome gritado, na hora de soltar | Fixo a essência, digo o verbo e fecho a forma. Três palavras, e a mana não anda um passo fora delas. Anteparo! | 1.2 | 1.8 | — |
| `nome__invocacao__chamado__01.ogg` | Chamado de Emergência: só o nome gritado, na hora de soltar | Eu não te ordeno e não te compro: eu te chamo pelo nome que nós dois combinamos, e espero que venhas porque prometeste vir. Chamado! | 1.2 | 1.8 | — |
| `nome__fogo__brasa__01.ogg` | Brasa: só o nome gritado, na hora de soltar | Brasa! | 1.2 | 1.8 | — |
| `nome__fogo__bola-de-fogo__01.ogg` | Bola de Fogo: só o nome gritado, na hora de soltar | Bola de Fogo! | 1.2 | 1.8 | — |
| `nome__fogo__fagulha__01.ogg` | Fagulha: só o nome gritado, na hora de soltar | Fagulha! | 1.2 | 1.8 | — |
| `nome__fogo__toque-escaldante__01.ogg` | Toque Escaldante: só o nome gritado, na hora de soltar | Toque Escaldante! | 1.2 | 1.8 | — |
| `nome__fogo__muro-de-chamas__01.ogg` | Muro de Chamas: só o nome gritado, na hora de soltar | Muro de Chamas! | 1.2 | 1.8 | — |
| `nome__fogo__clarao__01.ogg` | Clarão: só o nome gritado, na hora de soltar | Clarão! | 1.2 | 1.8 | — |

## Cânticos das magias (texto do livro)

| Arquivo | Quando toca | Fala | Alvo (s) | Máx (s) | ID |
|---|---|---|---|---|---|
| `cantico__agua__respingo__01.ogg` | Respingo: cântico completo antes de soltar a magia | Água que corre sem pedir licença, junta-te na minha palma / e vai de uma vez, fria e ligeira, onde eu apontar. / Respingo! | 12.0 | 15.8 | — |
| `cantico__agua__bola-de-agua__01.ogg` | Bola de Água: cântico completo antes de soltar a magia | Que a grande proteção da água esteja no lugar que buscas. / Eu clamo por um riacho refrescante e borbulhante, aqui e agora. / Bola de Água! | 12.9 | 17.0 | — |
| `cantico__agua__flecha-de-agua__01.ogg` | Flecha de Água: cântico completo antes de soltar a magia | Água que flui sem nunca escolher caminho, escolhe um agora: / a linha reta entre mim e ele. Toma a forma da caçada. / Flecha de Água! | 12.9 | 17.0 | — |
| `cantico__agua__impacto-de-gelo__01.ogg` | Impacto de Gelo: cântico completo antes de soltar a magia | Coloco diante de ti um berço de gelo, como desejas. / Deita-te e esquece o calor que te trouxe. / Impacto de Gelo! | 11.5 | 15.2 | — |
| `cantico__agua__lamina-de-gelo__01.ogg` | Lâmina de Gelo: cântico completo antes de soltar a magia | Frio cortante do inverno, que racha a árvore em silêncio: / vem à minha mão e esculpe a arma que ceifará meus inimigos. / Lâmina de Gelo! | 12.9 | 17.0 | — |
| `cantico__agua__escudo-de-agua__01.ogg` | Escudo de Água: cântico completo antes de soltar a magia | Espírito das correntes que dorme sob toda pedra, / ergue-te da terra e faz de ti a muralha que me protege do calor. / Escudo de Água! | 13.4 | 17.6 | — |
| `cantico__agua__nevoa-densa__01.ogg` | Névoa Densa: cântico completo antes de soltar a magia | Respiração fria da manhã, que apaga o vale antes do sol subir: / desce sobre eles e rouba-lhes a visão do mundo. / Névoa Densa! | 12.4 | 16.3 | — |
| `cantico__vento__rajada-curta__01.ogg` | Rajada Curta: cântico completo antes de soltar a magia | Vento que passa e não fica, corta só o que eu mandar, / uma lâmina fina de ar que ninguém vê chegar. / Rajada Curta! | 12.0 | 15.8 | — |
| `cantico__vento__lamina-de-vento__01.ogg` | Lâmina de Vento: cântico completo antes de soltar a magia | Ar que passa por tudo sem pedir licença a coisa nenhuma, / toma o fio da navalha e vai até ele. / Lâmina de Vento! | 12.0 | 15.8 | — |
| `cantico__vento__empurrao__01.ogg` | Empurrão: cântico completo antes de soltar a magia | Vento que não corta, só empurra com o peso do mundo inteiro atrás, / vai até ele e não pares até que perceba que perdeu o chão. / Empurrão! | 13.9 | 18.3 | — |
| `cantico__vento__passo-de-vento__01.ogg` | Passo de Vento: cântico completo antes de soltar a magia | Ar sob meus pés, que finge não estar lá até que eu peça, / leva-me daqui pra ali antes que alguém perceba que eu me movi. / Passo de Vento! | 14.8 | 19.4 | — |
| `cantico__vento__sopro-de-poeira__01.ogg` | Sopro de Poeira: cântico completo antes de soltar a magia | Poeira que dorme no chão, levanta e cega quem olhar de frente sem pensar duas vezes. / Sopro de Poeira! | 10.0 | 13.2 | — |
| `cantico__vento__vacuo-localizado__01.ogg` | Vácuo Localizado: cântico completo antes de soltar a magia | Ar que envolve a cabeça dele sem que ele perceba nada, eu te retiro agora mesmo, sem aviso. / Vácuo Localizado! | 10.5 | 13.8 | — |
| `cantico__terra__pedrisco__01.ogg` | Pedrisco: cântico completo antes de soltar a magia | Chão que me sustenta, empresta-me uma pedra pequena, / dura como a promessa de quem nunca sai do lugar. / Pedrisco! | 10.5 | 13.8 | — |
| `cantico__terra__bala-de-pedra__01.ogg` | Bala de Pedra: cântico completo antes de soltar a magia | Pó que já foi montanha, muito antes de virar caminho, / lembra do peso que tinhas antes de aprender a ser pó, e vai. / Bala de Pedra! | 13.4 | 17.6 | — |
| `cantico__terra__atoleiro__01.ogg` | Atoleiro: cântico completo antes de soltar a magia | Terra firme, sê honesta uma vez na vida: nunca foste firme, / sempre foste lama esperando a desculpa certa pra ceder. / Atoleiro! | 11.0 | 14.5 | — |
| `cantico__terra__muro-de-terra__01.ogg` | Muro de Terra: cântico completo antes de soltar a magia | Pedra que dorme sob meus pés, levanta-te devagar, camada sobre camada, até que nada do que vier atrás de mim passe por cima. Muro de Terra! | 13.9 | 18.3 | — |
| `cantico__terra__lanca-de-pedra__01.ogg` | Lança de Pedra: cântico completo antes de soltar a magia | Estacas que dormem sob o chão que eles pisam sem desconfiar de nada, / acordem juntas, subam de uma vez, e não avisem antes. / Lança de Pedra! | 13.4 | 17.6 | — |
| `cantico__terra__mao-de-terra__01.ogg` | Mão de Terra: cântico completo antes de soltar a magia | Mão que eu não tenho, mas o chão empresta: fecha os dedos de pedra / em volta de quem fugiu sobre uma terra que não é dele. / Mão de Terra! | 14.8 | 19.4 | — |
| `cantico__cura__cura__01.ogg` | Cura: cântico completo antes de soltar a magia | Que este poder divino seja alimento farto, e que dê a quem perdeu as forças / a força de se erguer de novo. Cura! | 12.0 | 15.8 | — |
| `cantico__cura__estancar__01.ogg` | Estancar: cântico completo antes de soltar a magia | Sangue que insiste em fugir por uma porta que não devia ter sido aberta, fica. Fogo que ainda come, para. Estancar! | 11.0 | 14.5 | — |
| `cantico__cura__selar-a-ferida__01.ogg` | Selar a Ferida: cântico completo antes de soltar a magia | Ferida, eu te marco e te guardo aberta um pouco mais, só o suficiente pra ser bem curada. / Selar a Ferida! | 11.0 | 14.5 | — |
| `cantico__cura__vigor-emprestado__01.ogg` | Vigor Emprestado: cântico completo antes de soltar a magia | Força que eu ainda tenho de sobra, empresto um pouco a ti — não é meu pra sempre, mas é teu agora. / Vigor Emprestado! | 12.0 | 15.8 | — |
| `cantico__desintoxicacao__purgar__01.ogg` | Purgar: cântico completo antes de soltar a magia | O que entrou aqui sem ser convidado e se instalou como se a casa fosse sua: sai. Sai como quiseres, mas sai agora. Purgar! | 12.4 | 16.3 | — |
| `cantico__desintoxicacao__antidoto__01.ogg` | Antídoto: cântico completo antes de soltar a magia | Que a pureza da minha mana proteja este sangue contra qualquer veneno ou peçonha que tente cruzar a sua pele. Antídoto! | 11.0 | 14.5 | — |
| `cantico__desintoxicacao__peconha__01.ogg` | Peçonha: cântico completo antes de soltar a magia | Peçonha que dorme em toda raiz amarga deste mundo e só espera uma mão que saiba pedir: sobe por este braço e acha o sangue dele. Peçonha! | 13.9 | 18.3 | — |
| `cantico__desintoxicacao__rosa-preta__01.ogg` | Rosa-Preta: cântico completo antes de soltar a magia | Rosa dos jardins de Asura, entra neste sangue sem aviso e apaga-lhe a consciência como uma vela entre os dedos. Rosa-Preta! | 12.0 | 15.8 | — |
| `cantico__teorica__dardo-arcano__01.ogg` | Dardo Arcano: cântico completo antes de soltar a magia | Fixo a essência, digo o verbo e fecho a forma. Três palavras, e a mana não anda um passo fora delas. Dardo Arcano! | 12.0 | 15.8 | — |
| `cantico__teorica__anteparo-teorico__01.ogg` | Anteparo: cântico completo antes de soltar a magia | Fixo a essência, digo o verbo e fecho a forma. Três palavras, e a mana não anda um passo fora delas. Anteparo! | 11.5 | 15.2 | — |
| `cantico__invocacao__chamado__01.ogg` | Chamado de Emergência: cântico completo antes de soltar a magia | Eu não te ordeno e não te compro: eu te chamo pelo nome que nós dois combinamos, e espero que venhas porque prometeste vir. Chamado! | 12.9 | 17.0 | — |
| `cantico__fogo__brasa__01.ogg` | Brasa: cântico completo antes de soltar a magia | Brasa que dorme no fundo da lareira, acorda só um instante, / salta da minha mão e lembra ao mundo que ainda és fogo. / Brasa! | 12.4 | 16.3 | — |
| `cantico__fogo__bola-de-fogo__01.ogg` | Bola de Fogo: cântico completo antes de soltar a magia | Chama que dormes na pedra e na madeira, acorda na minha mão / e vai até ele antes que ele perceba que já é tarde. / Bola de Fogo! | 13.9 | 18.3 | — |
| `cantico__fogo__fagulha__01.ogg` | Fagulha: cântico completo antes de soltar a magia | Pequena chama, nasce na ponta do meu dedo, tímida como fósforo riscado no vento. / Não morras logo — só o suficiente pra pegar. / Fagulha! | 12.0 | 15.8 | — |
| `cantico__fogo__toque-escaldante__01.ogg` | Toque Escaldante: cântico completo antes de soltar a magia | Calor que mora na minha própria mão e não me queima, / passa agora para a mão dele, que não vai gostar da visita. / Toque Escaldante! | 12.9 | 17.0 | — |
| `cantico__fogo__muro-de-chamas__01.ogg` | Muro de Chamas: cântico completo antes de soltar a magia | Linha que eu risco no chão, levanta-te em fogo e fica de pé. / Que ninguém atravesse sem pagar o preço da travessia. / Muro de Chamas! | 13.4 | 17.6 | — |
| `cantico__fogo__clarao__01.ogg` | Clarão: cântico completo antes de soltar a magia | Luz que estoura antes mesmo de aquecer, mais rápida que o susto, / rouba a visão de quem olhar direto pra ela. / Clarão! | 11.5 | 15.2 | — |

## Narração da cena de abertura

Mantida à mão (a fonte não é `gerar.py`, mas ele COPIA esta seção ao regenerar o arquivo — verificado em 17/10): a fonte é `src/shared/CenaAberturaDados.luau` (`FALAS`: chave, texto, início, duração). Mesmas regras de gravação acima; voz de narrador, calma e evocativa, uma fala por arquivo. O *Alvo* é o tempo que a legenda fica na tela (a cena tem 25 s fixos e o trajeto da câmera segue o relógio, então **o áudio nunca pode passar do Máx**). Para ligar, ponha o `rbxassetid://` no campo `audio` da fala correspondente em `FALAS`; `CenaAbertura` toca o som quando a legenda aparece e o destrói ao fim da cena. Fala sem `audio` fica muda.

| Arquivo | Quando toca | Fala | Alvo (s) | Máx (s) | ID |
|---|---|---|---|---|---|
| `abertura__01.ogg` | cena de abertura, sobre as montanhas nevadas (0,9 s) | Dizem que todo mundo ganha uma segunda chance… | 3.8 | 4.2 | — |
| `abertura__02.ogg` | cena de abertura, sobre o lago (5,8 s) | Aqui, a magia respira na água e no vento. | 3.8 | 4.2 | — |
| `abertura__03.ogg` | cena de abertura, sobre a floresta (10,8 s) | Ela corre fundo nas árvores de poder. | 3.2 | 3.6 | — |
| `abertura__04.ogg` | cena de abertura, descendo sobre a vila (18,0 s) | Mestres esperam por quem tem coragem de aprender. | 3.6 | 4.0 | — |
| `abertura__05.ogg` | cena de abertura, junto ao portão norte (21,9 s) | Sua nova vida começa aqui. | 2.7 | 3.1 | — |
