# Habilidades: inventário e plano de animação/cinemática (HAB0)

Planejamento de 16/11/2026, sem código de jogo. Régua: Clair Obscur: Expedition 33 (meta 7,5; a luta hoje vale ~5). Dados do livro em `src/shared/Livro/Dados/Arvores/*.luau` (gerados); regras em `src/shared/Regras/ArvoresPrincipiante.luau`. Nenhuma regra muda aqui.

## 1. Árvores e ranks

- Ladino = `furtividade-e-armadilhas` ("Furtividade e Armadilhas", subgrupo Batedor e Ladrão; pátio/treinador em `Mundo/PatioLadino` e `TreinadoresAparenciaDados`). Rank 1 = "Gatuno".
- Mago da Água = `agua`; Deus da Espada = `deus-da-espada`.
- Ordem dos ranks: **Principiante** (1º) < Intermediário < Avançado < Santo < Rei < Imperador. "Até Principiante" = só o primeiro rank.

## 2. Inventário até Principiante

Habilidades ativas (kind `ability`): Ladino 1, Água 7 (6 ativas + truque), Espada 5 (3 ativas + 2 passivas). Talentos (passivos, fora da luta): Ladino 6, Água 3, Espada 4.

| Árvore | id | Nome | Custo | Alcance/alvo | Efeito resumido (livro) | Tipo |
|---|---|---|---|---|---|---|
| Ladino | primeiro-golpe | Primeiro Golpe (assinatura) | 2 PA, 1 Ação | corpo a corpo | 1x por combate, alvo Desprevenido: Dano Furtivo triplicado | golpe |
| Água | respingo | Respingo (truque) | 0 PA/0 PM | 9 m | 1d6+BC contundente, 1x/turno; alvo Molhado | magia (projétil) |
| Água | bola-de-agua | Bola de Água | 1 PA/1 PM | 18 m | 1d6+BC; empurra 1,5 m; Molhado | magia (projétil) |
| Água | flecha-de-agua | Flecha de Água (assinatura) | 2 PA/1 PM | 27 m | 1d8+BC perfurante; Molhado | magia (projétil) |
| Água | impacto-de-gelo | Impacto de Gelo | 1 PA/2 PM | 18 m | 1d8 frio (dobra em Molhado); falha em Agilidade: -3 m de deslocamento | magia (projétil) |
| Água | lamina-de-gelo | Lâmina de Gelo | 1 PA/2 PM | toque, em si | arma de gelo 1 min: 1d8 cortante + 1d4 frio | buff (arma) |
| Água | escudo-de-agua | Escudo de Água | 1 PA/2 PM | 6 m, barreira 3 m, 2 turnos | aliados atrás: Cobertura Superior (+5 CA); fogo pela metade | zona/barreira |
| Água | nevoa-densa | Névoa Densa | 1 PA/1 PM | esfera 6 m de raio | área obscurecida (cega) | zona |
| Espada | corte-de-braco | Corte de Braço (assinatura) | 2 PA, 1 Ação | corpo a corpo | ataque; Vigor: larga o que segura/perde o braço; desvantagem na concentração de conjurador | golpe |
| Espada | investida-espada | Investida | 1 PA | corpo a corpo | avança até 2x deslocamento e ataca; +1 dado se andou 9 m+; sem Reações | movimento + golpe |
| Espada | golpe-continuo | Golpe Contínuo | 1 PA/1 PT | corpo a corpo | ataque; +4 no acerto se já acertou neste turno | golpe |
| Espada | roupa-leve | Roupa Leve | 1 PA | passivo | sem armadura: +3 m e +2 CA ao se mover 3 m+ | passiva |
| Espada | sem-recuo | Sem Recuo | 1 PA | passivo | imune a Amedrontado/recuo forçado | passiva |

Relacionadas na mesa (fora do rank): `mesa/esconder` (Ladino), `mesa/ataque-*` (ataque básico), `mesa/lamina-de-gelo-forca|intelecto`; Postura do Espadachim (talento Vento/Trovão, sem animação hoje).

## 3. Estado atual e proposta

Hoje: `Coreografia.tocar` escolhe o perfil por árvore (`PERFIS`: agua=corrente, deus-da-espada=corte, furtividade=astucia, `nova=true`, some em modo reduzido); `Gestos.especificar` (tabela ESPEC por id) escolhe o gesto do corpo; os clipes vêm de `shared/Animacoes/Clipes` (CorteLeve, CortePesado, Estocada, Conjurar, Canalizar, DisparoArco, ReacaoGolpe, Esquiva, Bloqueio, PosturaCombate, Queda, Vitoria). Receitas próprias de VFX (`Magias.RECEITAS`) existem só para o fogo; água/gelo usam o projétil genérico "corrente" e o impacto genérico (`impacto`, `ImpactoFx`). Câmera: `ImpactoCamera` trata todo golpe igual; nenhuma habilidade tem câmera própria. Som: `Sons.impacto(id, arv, spec, resultado)`; dublagem de cântico/nome já existe para a água (`shared/Dublagem`).

"Genérico" = só o gesto padrão da família, sem receita nem identidade própria.

| Habilidade | Hoje na luta | Proposta: clipe | VFX | Câmera | Som | Reaproveitar / criar |
|---|---|---|---|---|---|---|
| primeiro-golpe | ESPEC próprio (golpe, 2 cortes, preparo .15); CorteLeve/Estocada; impacto "astucia" (arco) | Estocada com antecipação longa agachado; congela 2 quadros no contato | corte fino escuro e fumaça/sombra no ladino antes do golpe; número triplo grande | assinatura: aproxima, 0,25 s de câmera lenta no contato, volta | metal curto, silêncio antes | Estocada, ImpactoFx, ParticleEmitter de fumaça; criar clipe "Emboscada" e receita de sombra |
| respingo | genérico: Conjurar + projétil corrente | Conjurar curto (truque, 1 mão) | jato fino de água, sem círculo mágico; alvo Molhado com brilho/gotejar | normal (rápido) | splash leve | Conjurar + emissor de água; criar aura "Molhado" reutilizável |
| bola-de-agua | genérico: Conjurar + corrente, recuo 1 casa | Conjurar com puxão das duas mãos | esfera de água viva (Part + emissor + rastro), splash no impacto, empurra | segue o projétil, plano curto no impacto | borbulhar + splash | emissor nativo + Part; criar receita em `RECEITAS` |
| flecha-de-agua | genérico: família "corrente" | DisparoArco com arco de água (assinatura): arma e solta | linha de água perfurante, rastro longo, racha em gotas no alvo | assinatura: lateral + câmera lenta 0,3 s no disparo | tensão, corte de ar, splash | DisparoArco (reuso); criar modelo de flecha de água e receita |
| impacto-de-gelo | genérico (o nome tem "gelo": impacto com `gelo`) | Conjurar apontando, mão fechando | estilhaços e cristais, cristalização no alvo, névoa fria; cristal extra se Molhado | aproxima no impacto | vidro/gelo rachando | Part cristal + emissor; criar receita e estado "congelado" curto |
| lamina-de-gelo | ESPEC `conjuro` pose empunhar + prop gelo (existe); golpes `lamina-de-gelo-*` com prop | Conjurar "empunhar", depois CorteLeve com a lâmina | espada de gelo materializa na mão, frio na lâmina, rastro azulado | cinemática curta ao materializar (de baixo, 0,6 s) | cristalizar + cortes frios | prop gelo existe; só refinar |
| escudo-de-agua | genérico: Canalizar (palmas) + zona | Canalizar em laço; ao fim, palmas para frente | parede d'água 3 m, translúcida, com respingo na base | plano aberto mostrando a barreira | corrente contínua | Part + textura animada; criar receita de muro/zona |
| nevoa-densa | genérico: Canalizar + zona | Canalizar levantando os braços | volume de névoa de 6 m (emissores, visibilidade baixa) | câmera sobe e mostra a área | sopro frio | emissores nativos; criar receita de zona |
| corte-de-braco | ESPEC próprio (corte 62°, preciso, preparo .26); CortePesado/CorteLeve | CortePesado dirigido ao braço do alvo | arco alto, faísca na mão do alvo; efeito "larga a arma" visível | assinatura: câmera lenta 0,2 s e close na mão ao acertar | corte pesado + arma caindo | CortePesado, ImpactoFx; criar reação `solta-arma` no alvo |
| investida-espada | ESPEC `investida`/espada, peso .5 (gesto existe) | corrida curta e Estocada/CorteLeve ao final | poeira nos pés, linhas de velocidade, rastro de corte | acompanha a corrida e freia no contato | passos, whoosh, metal | investida de Gestos; criar clipe de corrida de combate e poeira |
| golpe-continuo | ESPEC próprio (3 cortes encadeados) | combo CorteLeve x3, terceiro mais forte | arcos sucessivos, brilho crescente se já acertou | micro-aproximação a cada corte | 3 metais com altura crescente | já existe; só polir |
| roupa-leve, sem-recuo | sem apresentação (passivas) | sem clipe | indicador leve ao ativar (+CA / imune a recuo) | nenhuma | nenhum | só indicador de estado (baixa prioridade) |

Caem no genérico hoje: 6 da Água (respingo, bola, flecha, impacto de gelo, escudo, névoa) e as 2 passivas da Espada (sem apresentação). Com gesto próprio (ESPEC, sem VFX/câmera dedicados): primeiro-golpe, corte-de-braco, investida-espada, golpe-continuo, lâmina de gelo. Nenhuma tem cinemática, câmera própria nem receita de VFX; só o fogo tem receitas em `Magias`.

Cinemática curta: reservar às assinaturas (Primeiro Golpe, Flecha de Água, Corte de Braço); ranks altos (Espada de Luz, Maremoto etc.) ficam para depois.

## 4. Pacotes propostos

Ordem pelo que aparece no começo do jogo (golpes de espada e magia de água básica):

| Pacote | Escopo | Arquivos exclusivos | Pronto quando |
|---|---|---|---|
| HAB1 Espada + Ladino | polir primeiro-golpe, corte-de-braco, investida, golpe-contínuo; clipes novos (Emboscada, corrida); reação `solta-arma` | `shared/Animacoes/Clipes/*` novos, `tools/blender/anim_clipes.py`, entradas ESPEC dessas em `client/Gestos`, `client/ImpactoFx` (só depois que IMP5 fechar) | no Studio, capturas quadro a quadro de cada uma (antecipação, contato, recuperação), câmera lenta nas assinaturas, `qa luta` ok |
| HAB2 Água, projéteis | VFX de respingo, bola, flecha de água, impacto de gelo; aura Molhado | novo `client/MagiasAgua` (registro em `Magias.RECEITAS`), desvio por árvore em `Coreografia` | capturas do projétil, do impacto e do alvo Molhado; flecha de água com marca de assinatura |
| HAB3 Água, zonas/buff + passivas | lâmina de gelo (materialização), escudo, névoa, indicadores das passivas | novo `client/MagiasAguaZona`, indicadores em `client/Efeitos` | captura de cada zona e do buff; `FX.reduzidos` continua legível |

Regras comuns: ParticleEmitter e Parts nativos; asset externo só com procedência registrada (`docs/ARTE.md`); som por `Sons`/`docs/SONS.md`; respeitar `FX.reduzidos` e `CenaTempoFixo`; `Coreografia`, `Corpo` e `ImpactoFx` estão com IMP5 (só tocar depois que ele entregar). Fechar cada pacote com nota franca contra a meta 7,5.

Não verificado: nada foi rodado; o estado "genérico" vem de leitura/grep em `Gestos`, `Magias` e `Coreografia`, sem ver a luta no Studio.
