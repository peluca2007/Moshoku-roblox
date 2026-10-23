# Direção visual e animações

## Mundo V2 — mutirão visual (Pedro, 16/10/2026)

Pedro: "o mapa tá muito feio, tudo tá muito feio". Opus planeja e revisa; Sonnet/Haiku (subagentes) e Codex executam.

**Diagnóstico (capturas no Play, 16/10):** o mundo é uma placa de Part verde flutuando no vazio (a borda aparece); sem relevo, água nem horizonte; céu padrão; `Lighting.Technology` não é definido no place gerado; praça e trilhas são retângulos de Part; a Floresta Sombria é um gramado claro com pinheiros espaçados.

**Direção de arte:** fantasia low-poly estilizada (referência Arcane Lineage), fim de tarde dourado, saturação moderada, formas facetadas e coerentes. Regras:
1. Nunca mostrar a borda do mundo: o horizonte é sempre montanha, mata ou névoa.
2. Chão é Terrain (relevo, água, materiais pintados); Part só para construção e prop.
3. Zonas de jogo continuam planas em y=0 (arenas, grades, praça, trilhas, nascimentos, pés dos prédios): o relevo sobe em volta delas.
4. Densidade por camadas: árvores grandes → arbustos → tufos/flores/pedras → grama decorativa.
5. Cada região tem identidade: região inicial = campos abertos e colinas; vila = praça de pedra viva; floresta = mata fechada, escura, névoa; ruínas = vale encaixado, pedra e musgo.

| Pacote | Dono | Arquivos | Estado |
| --- | --- | --- | --- |
| V1 Terreno contínuo | Codex; afinação de relevo/lago por Sonnet no Studio | `shared/Mundo/TerrenoLayout`, `server/Mundo/Terreno`, solos de Part das regiões | entregue; corrigido desnível de +2 (superfície = base + ocupância·r + r/2); relevo em afinação |
| V2 Luz, céu e atmosfera | Sonnet | `tools/build-place.ps1` (Lighting/Terrain), `shared/Mundo/AmbientePerfis`, `client/CeuMundo` | entregue e visto no Play |
| V3 Vegetação e props novos | Sonnet | `tools/blender/{formas,vegetacao,props,previa}.py` | 27 modelos enviados (raízes reprovadas) |
| V4 Povoar regiões com os modelos novos | Codex | layouts/props das regiões | entregue; paliçada, portões, lampiões, flores, mata fechada vistos no Play |
| V1b Relevo, lago, sopé | Sonnet com Studio | `TerrenoLayout` | entregue; montanhas a 80+ studs, lago irregular, terreno em ~5,5 s |
| C1 Câmera estilo Project Zomboid | Sonnet | `client/CameraMundo`, `shared/CameraMundoCalculo`, `client/ModoCamera` | jogada no Studio: diagonal, Q gira, W anda pela tela, oclusão ok |
| T1 Ladino e Mestra da Água com provações | Codex + Sonnet | `Regras/Provacoes*`, `Mundo/{TreinadoresLayout,PatioLadino,JardimAgua,TreinadoresAparencia}` | jogadas de ponta a ponta no Studio; Studio 1.829/0 |
| V5/V6 Modelos e composição da vila, trajes | Sonnet (Blender) + Codex | `tools/blender/{vila,casas,trajes}.py`, `VilaLayout` | entregue; vista no Play |
| V5 Interface (telas e HUD) | depois | cliente | pendente |

Briefs: `build/codex/V*.md`. Studio: só o coordenador usa (um Studio).

## Avatar do jogador (Pedro, 16/10/2026)

Boneco "quadradão" (R15 blocado, como o boneco de cubos das prévias), rosto montado em blocos 3D (olhos, sobrancelhas, nariz, boca), cabelo/barba/traços de raça e roupas como peças do Blender. Personaliza na criação e no espelho da vila. Começa com roupas básicas; os trajes bonitos (Ladino, Mestra e futuros) são loot raro de chefe e ficam na conta, sem efeito de regra. Cada raça do livro tem traços próprios (proporção, paleta de pele, orelhas, chifres, cauda, auréola…). Pacotes: A1 regras/servidor (Codex), A2 peças Blender (Sonnet), A3 telas (depois do U1).

## Interface V2 — escuro com ouro (Pedro, 16/10/2026)

Escolha do Pedro entre 3 opções: **painéis escuros com ouro** (ref. Arcane Lineage), só no fluxo atual (menu, HUD, run, conta, viagem, ajuda, treinadores, provações, combate J2, avisos). Telas antigas da mesa/admin ficam como estão.

Regras:
1. Tudo sai de um tema único (`client/UI/Tema` + componentes em `client/UI/`); nenhuma tela define cor, fonte, raio ou borda solta.
2. Painel: fundo preto-azulado (#0f1118) a ~10–15% de transparência, borda dourada fosca (#c9a45c, 1,5 px) com fio interno escuro, cantos 6 px, losangos dourados nos cantos de painéis grandes, sombra suave por trás. Legível sobre o mundo claro.
3. Texto: creme (#efe6d2) no corpo, ouro claro (#e8c87a) nos títulos; secundário #a39d8f. Contraste ≥ 4,5:1.
4. Fontes (testadas no Studio em 16/10, `docs/evidencias/ui-v1/91-teste-glifos-fontes.jpg`): títulos em Bodoni caixa alta, subtítulos Garamond, corpo Merriweather, números Oswald, rótulos de botão SourceSansPro. Cinzel não existe no Roblox; Grenze Gotisch fica ilegível pequena. Ícones são glifos na fonte Garamond (a única que desenha ✦ ⚔ ☰ ✕ ✓ ↺ ⚑ ★ ♥ em monocromático); nas outras viram caixas vazias ou emoji colorido.
5. Botões: principal = ouro com texto escuro; secundário = contorno dourado; perigo = vinho; ≥ 44 px de altura; hover/pressão com tween curto; ícone opcional à esquerda.
6. Cores das árvores e de estado (perigo, sucesso, alerta) entram só como destaque (faixa, ícone, barra), nunca como fundo inteiro.
7. Avisos: banner no alto com ícone e título curto + linha de detalhe; some sozinho; não cobre o personagem nem a área central da câmera alta.
8. Celular: tudo escala com a tela; nada abaixo de 44 px de toque; nada sob o polegar do joystick.

## Estética anterior: Livro Noite (V1, pedido do Pedro, 09/10/2026)

O jogo veste o tema **Livro Noite** do site e o livro folheado (`/livro`): página azul-noite, letra gritada em caixa alta, cores de capítulo e o "caos" de motivos espalhados. A taverna à luz de velas (M6, mais abaixo) fica como histórico.

Tudo sai de `src/shared/Estilo.luau`, e nenhum módulo define cor ou fonte solta. As fontes no site são:
- a paleta noite e as cores de capítulo, em `src/app/livro/folhear/folhear.css`;
- as vozes da letra, em `src/components/book/folhear/fontes.ts`;
- a identidade de cada árvore (cor da noite, kanji e selo), em `src/data/identidadeDasArvores.ts`. Ela vem gerada em `src/shared/Livro/Identidade.luau` pelo gerador do catálogo, sem cópia à mão.

| Token | Uso | Cor |
| --- | --- | --- |
| PAPEL | página (tabuleiro), fundo do painel | #141418 |
| PAPEL_2 | cartões, base das miniaturas | #1e1e24 |
| TINTA / TINTA_SUAVE | texto, grade (a 13–25%) | #e8e3d9 / #aca79d |
| MESA / MESA_FUNDO | a mesa quadriculada, névoa de jogo | #101013 / #070709 |
| CAPITULOS 0–5 | abas, luzes do caos, estados | #ffa94d #5eb1ff #b197fc #38d9a9 #ff6b6b #ffd43b |
| DESTAQUE / DESTAQUE_FUNDO | seleção, títulos do painel / botão principal | #b197fc / #5b4a9c |
| PERIGO, ALERTA, SUCESSO | dano e falha, crítico e condições, PV alto | capítulos 4, 5, 3 |

O Roblox não tem a Barlow, a Fraunces nem a Literata, que o livro usa. A troca é uma adaptação visual:

| Voz | No livro | No Roblox |
| --- | --- | --- |
| grito (títulos, números) | Barlow Condensed | Oswald Bold |
| rótulo (botões) | Barlow | Roboto Condensed |
| corpo | Literata | Merriweather |
| elegante | Fraunces itálica | Merriweather itálica |

Os kanji usam a fonte japonesa padrão do Roblox.

O cenário (`MesaWorld`) é o livro aberto sobre a mesa quadriculada:
- capa, maço de páginas e a página com a grade em tinta;
- as abas coloridas dos capítulos na borda direita;
- o caos da página em marca-d'água: o número de capítulo vazado "01", 第一章, selos 壱/参, estrelas ✦, dados d20 em fio e faixas listradas;
- luz neutra de leitura e luzes coloridas rasantes nos cantos;
- os 19 selos das árvores flutuando no escuro em volta, nas cores delas; o `Ambiente` os faz subir, descer e pulsar.

O caos é desenhado com texto e quadros, sem imagens enviadas. As artes `public/livro/caos/*.svg` do site exigiriam upload na conta do Pedro, e isso fica para decisão dele.

Contraste: o teste do painel exige ≥ 4,5:1 em todo botão e campo, e passa com a paleta nova.

Verificação em 09/10:
- `testar.ps1` todo verde;
- no Studio, o cenário foi criado (362 objetos) e o painel foi visto no estilo novo.

**Ainda não visto:** a cena 3D. A captura do Studio não desenhou o 3D, nem um painel neon de teste, provavelmente porque a janela estava minimizada. A densidade da atmosfera (0,32) ainda precisa ser conferida a olho.

---

## Histórico: salão de taverna (etapa M6)

Tema: **salão de taverna à luz de velas, com o grande mapa no chão**. O tabuleiro tem 100×100 studs e os avatares andam sobre ele, então ele virou um mapa de pergaminho sobre um estrado com moldura dourada (e não uma mesa gigante). Em volta: paredes de pedra, pilares, estandartes vinho, mesas laterais com velas e lanternas. Mesmas cores do site (`src/app/globals.css` do site), para a mesa parecer parte do mesmo livro.

Regra: animação e efeito são **só apresentação, no cliente**. Nada de efeito decide regra, e nenhum efeito pode atrasar ou bloquear um comando. Sem assets externos (imagens ou modelos enviados): só peças, materiais, luzes e fontes nativas do Roblox.

## Paleta (do site)

| Nome | Uso | RGB |
| --- | --- | --- |
| pergaminho 50 | texto claro, tabuleiro claro | 253, 246, 227 |
| pergaminho 200 | tabuleiro | 238, 224, 196 |
| pergaminho 400 | bordas suaves | 199, 174, 128 |
| pergaminho 700 | tinta da grade, texto escuro | 100, 84, 58 |
| pergaminho 900 | fundo do painel | 43, 24, 16 |
| pergaminho 950 | fundo mais escuro | 26, 18, 16 |
| vinho 400 | perigo, dano, NPC | 201, 82, 122 |
| vinho 600 | botões de ação do mestre | 74, 14, 46 |
| ouro 300 | destaque, crítico, seleção | 226, 186, 94 |
| ouro 500 | bordas douradas | 184, 134, 46 |
| oliva (cura) | cura, sucesso | 120, 160, 90 |

Fontes: títulos `Font.fromName("Fondamento")` (fantasia, legível); texto `Font.fromName("SourceSansPro")`. Números grandes (dados, dano): `Fondamento` em negrito.

## Decisões tomadas ao ver no Studio

- **Legibilidade antes do clima:** a primeira versão estava escura demais. Agora o ambiente é mais claro, a neblina é leve e há quatro luzes invisíveis sobre o mapa; o clima fica nas bordas.
- **Sem `Highlight`:** o Roblox só desenha 31 `Highlight` ao mesmo tempo, e a mesa aceita 60 fichas. Seleção e vez são anéis neon animados.
- **Mapa liso:** o material "Fabric" parecia tábuas; o pergaminho usa superfície lisa.
- **Câmera:** o ambiente não tem teto, para a Visão da mesa enxergar o mapa de cima.

## Cenário (Claude, `MesaWorld`, `Ambiente`)

- Sala de taverna: piso de tábuas, paredes de pedra, vigas; mesa de madeira escura sob o tabuleiro; tabuleiro em tom pergaminho com grade em tinta (pergaminho 700); velas na mesa e lanternas com luz quente que tremula (no cliente).
- Iluminação noturna quente: `Lighting` com ambiente baixo e quente, `Atmosphere`, `Bloom` leve, `ColorCorrection` levemente quente.

## Fichas e tabuleiro (Claude, `BoardView`, `Efeitos`)

- Miniaturas: base redonda de madeira com aro colorido (cor da ficha), pedestal e cabeça; anel dourado que pulsa na seleção; anel brilhante e leve flutuação na ficha da vez; ficha oculta (mestre) semitransparente pulsando.
- Movimento: salto em arco até a casa nova, com duração proporcional à distância, e leve "assentar" ao pousar.
- PV: barra que muda de cor (oliva → ouro → vinho) com transição; número flutuante (−5 vinho, +5 oliva) subindo e sumindo.
- Névoa e terreno: entram e saem com transição de transparência; pintura com pequeno "pop".
- Dados 3D: cada rolagem que o jogador pode ver gera um dado que cai e gira sobre a mesa e para mostrando o resultado; dourado para rolagem pública, vinho para secreta; crítico com brilho dourado, falha com tom vinho.
- Letreiro de turno: "Rodada 2 — vez de Kade" aparece e some no topo da tela.
- Câmera: transição suave ao entrar/sair da Visão da mesa; zoom suavizado.

### Evento novo (servidor → cliente)

`FireClient(jogador, "roll", { by, label?, text, total, natural?, critical?, secret: boolean, tokenId? })`, enviado junto com o registro de cada rolagem e de cada iniciativa, só a quem pode ver aquela rolagem. `natural` é o d20 escolhido quando houver. O cliente usa só para animar; o registro continua sendo a fonte do texto. `MesaState.onRoll(cb)` repassa o evento.

## Painel (Codex, `MesaPanel`)

- Cores e fontes da tabela acima; cantos arredondados (`UICorner`), bordas finas douradas (`UIStroke`), botões com realce ao passar o mouse e ao apertar (tween curto).
- Abas no topo: **Mesa** (visão da mesa, dados, registro), **Ficha** (ficha selecionada, condições, ajustes), **Mestre** (criar/importar/editar, iniciativa, mapa) e **Campanha**. Mestre e Campanha só para o mestre. Troca de aba com transição curta. Acaba o painel de rolagem infinita.
- Recolher/abrir com deslize (tween). Em tela estreita (celular), o painel vira uma faixa inferior que sobe.
- Registro: entrada nova aparece com fade; rolagens com o total em destaque; crítico em ouro, falha em vinho.
- Toque e acessibilidade: botões ≥ 44 px, contraste do texto ≥ 4,5:1 sobre o fundo.
- Mesma API do `MesaState` de antes, mais `onRoll` se quiser destacar a última rolagem.

## Divisão

| Arquivo | Dono |
| --- | --- |
| `src/server/MesaWorld.luau`, `src/client/Ambiente.luau` (novo: luzes, velas, atmosfera) | Claude |
| `src/client/BoardView.luau`, `src/client/Efeitos.luau` (novo: dados 3D, números, letreiro) | Claude |
| `src/server/MesaService.luau` (evento `roll`), `src/client/MesaState.luau` (`onRoll`) | Claude |
| `src/client/MesaPanel.luau` (+ fixture) | Codex |
