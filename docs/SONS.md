# Efeitos sonoros — reaproveitamento do site

Direção de Pedro em 09/10/2026: reutilizar efeitos existentes no site de Mushoku Tensei, sem reutilizar qualquer voz. Falas, cânticos, gritos, gemidos e outras vocalizações ficam para os novos dubladores. Sons de espada e magia são efeitos sonoros, separados de `docs/DUBLAGEM.md`.

## Efeitos enviados e integrados (09/10/2026)

Fonte lida sem alterações: `../Moshoku tensei rpg/public/sons/arena/`. O catálogo `../Moshoku tensei rpg/src/lib/sonsDaArena.ts` registra os usos e as origens dos arquivos.

| Uso | Arquivos MP3 |
| --- | --- |
| Espada e defesa | espada-corte, espada-metal, espada-combo, aparar |
| Flecha, lança e golpe | flecha-impacto-1, flecha-impacto-2, lanca, soco |
| Magia elemental | fogo, fogo-impacto, gelo, agua, vento, vento-impacto, terra |
| Cura e outros efeitos | cura-1, cura-2, brilho, moedas |

Excluídos: `grito-feminino`, `grito-masculino-1`, `grito-masculino-2`, `grito-masculino-3`, `assobio` e `buff`. Assobio é vocalização; o catálogo descreve buff como "gooo", portanto fica fora por possível voz.

Os dezenove arquivos foram selecionados pelos nomes e pela descrição do catálogo do site, sem escuta auditiva. Não declarar ausência de voz misturada comprovada por escuta. `semVozConfirmado` permanece false no manifesto, registrando essa limitação de forma explícita. Não reutilizar gravações vocais do site para preencher a dublagem; caso uma escuta revele voz num efeito, retirar seu ID do manifesto e regenerar.

## Arquivos, uso e permissões

`assets/sons/` contém as 19 cópias locais (2.765.340 bytes), sem transformar os originais. `tools/sons/manifesto.json` registra caminho, SHA-256, classificação, estado de escuta e ID Roblox de cada arquivo. `python tools/sons/preparar.py` copia e gera `src/shared/SonsIds.luau`; `--verificar` confere cópias, manifesto e módulo gerado sem editar. Hash diferente impede reutilizar um ID antigo.

Enviados pelo Creator Hub à conta já conectada, como áudios privados; captura em `tools/sons/envio-confirmado.jpg`. Pedro autorizou explicitamente acesso permanente dos 19 assets à experiência **MoshokuRPGMesa (10769906362)**. Permissões salvas individualmente. A revisão automática bloqueou o primeiro salvamento por falta de autorização específica para a permanência; só foi retomado após o "Sim, autorizar os 19 efeitos para esse jogo" de Pedro.

`Sons.luau` seleciona efeitos de apresentação pelo gesto e resultado do recibo já filtrado pelo servidor. `Sonorizacao.luau` só toca chaves permitidas com ID válido, localmente no SoundService, volume 0,55, máximo de oito sons e cauda limitada (2,5 s por padrão, 1,5 s em impactos; máximo 5 s). Limpa em Ended, timeout, cancelamento da cena e fim do combate. Nenhum remoto novo, regra, recurso ou dano alterado. Vozes futuras continuam no módulo Dublagem separado.

Coreografia: cortes, combo, impacto de espada, soco/escudo/cabeçada, impacto de disparos, conjuração elemental, cura e brilho. Ataque errado não toca impacto físico; explosão de projétil de Fogo toca também no chão, conforme a animação. Magias de Fogo têm ganchos nos callbacks reais de lançamento e chegada. Receitas atrasadas não reabrem áudio após fim do combate.

`aparar`, `lanca`, `moedas` e `flecha-impacto-2` estão enviados e acessíveis, mas sem gatilho próprio nesta entrega: não inventar aparada, recompensa ou equipamento só para usar um áudio. Não há som da corda do arco no catálogo. Cura usa seu efeito de conjuração e resultado; avaliação auditiva de sobreposição, volume e corte de cauda ainda pendente.

## Origens preservadas do catálogo do site

| Arquivo | Origem registrada no site |
| --- | --- |
| espada-corte | 54427377-sword-slash-476148 (Pixabay) |
| espada-metal | daviddumaisaudio-sword-slash-with-metallic-impact-185435 (Pixabay) |
| espada-combo | freesound_gamestudio-rpg-sword-attack-combo19-388939 (Pixabay) |
| aparar | deepwoken-parry; o catálogo registra uso autorizado pelo autor |
| flecha-impacto-1 / 2 | dennish18-arrow-body-impact-146419 / freesound_community-arrow-impact-87260 |
| vento-impacto | dragon-studio-elemental-spell-impact-wind-478376 |
| fogo-impacto | dragon-studio-fire-spell-impact-393921 |
| soco | dragon-studio-hard-punch-sfx-515251 |
| moedas | freesound_community-coins27-36030 |
| brilho | universfield-magic-twinkle-244951 |
| fogo, gelo, agua, vento, terra, cura-1 / 2, lanca | yodguard-*-magic / spear_thrust (Pixabay) |

Esta tabela preserva o registro existente, sem afirmar uma nova auditoria de licenças.

## Verificação e limites

`tools/testar.ps1`: 116 fontes compiladas sem erro, specs puros (incluindo quatro grupos de Sons), catálogo, painel e estado do cliente aprovados: **RESULTADO: tudo ok**. Studio: 223 specs do servidor, nove verificações de ganchos/cancelamento no cliente e carregamento/reprodução real dos 19 IDs. Roteiro: `python tools/studio_mcp.py run tools/playtest/a10_sons.json`; provas e resultado final em TESTES.md.

O teste usa IsLoaded, TimeLength e IsPlaying reais; não equivale a ouvir o conteúdo completo. Sem avaliação auditiva de voz misturada, volume, sensação, dois clientes ou celular. Scripts sincronizados em Edit e place local regenerado pelo gerador; jogo não publicado.

Quando faltar um efeito, pedir a Pedro o som específico e o contexto (por exemplo: disparo elétrico ou impacto de escudo), conforme sua oferta. Não pedir gravação de voz para substituir um efeito de espada.

Nenhum arquivo do site foi alterado.

## A11 — mistura e volume
Volume local em 0%, 35%, 70% ou 100% pelo menu; padrão 70%. Ganho por efeito reduz sobreposição, cauda termina com fade curto e cura toca só no impacto, evitando duplicação. Nenhuma fala adicionada. Seleção continua pelo catálogo, sem escuta integral certificada. Studio confirmou novamente os 19 carregamentos e limpeza.
