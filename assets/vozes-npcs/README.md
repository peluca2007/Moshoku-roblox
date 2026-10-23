# Vozes dos NPCs — gravações do Pedro

Preparação local das 47 gravações entregues em `audios/`, conferida em 11/10/2026. Os arquivos originais continuam intactos. As cópias estão em [arquivos](arquivos), em WAV PCM de 16 bits, mono, 44,1 kHz, com os nomes corrigidos. Arquivos originalmente chamados `.ogg.m4a` foram realmente decodificados, não apenas renomeados.

## O que está pronto

- Goblin Batedor: 12 gravações.
- Lobo Cinzento: 10 gravações.
- Bandido de Estrada: 10 gravações.
- Treant Ancião: 15 gravações.
- Urso de Presas Vermelhas: 9 entradas reaproveitando o lobo, conforme autorização do Pedro.

São **47 arquivos para importar, cobrindo 56 entradas** do roteiro. Não é preciso enviar outras nove cópias ao Roblox para o urso: o mesmo ID poderá atender as duas criaturas.

| Som previsto no urso | Gravação do lobo usada |
| --- | --- |
| Entrada | `npc__lobo-cinzento__ameaca__01.wav` |
| Ameaça | `npc__lobo-cinzento__alerta__01.wav` |
| Ataque01 | `npc__lobo-cinzento__ataque__01.wav` |
| Ataque02 | `npc__lobo-cinzento__ataque__02.wav` |
| Dor leve01 | `npc__lobo-cinzento__dor-leve__01.wav` |
| Dor leve02 | `npc__lobo-cinzento__dor-leve__02.wav` |
| Dor forte | `npc__lobo-cinzento__dor-forte__01.wav` |
| Pouca vida | `npc__lobo-cinzento__pouca-vida__01.wav` |
| Derrota | `npc__lobo-cinzento__derrota__01.wav` |

O uivo fica exclusivo do lobo. Não foi aplicado pitch, efeito, música ou aumento de volume. A identidade diferente do urso ainda depende da interpretação/edição futura; o reuso atende ao pedido de aproveitar as gravações existentes.

## Conferência e durações

[manifesto.json](manifesto.json) registra origem, hashes, duração antes/depois, pico, bordas retiradas e mapeamento completo. [importacao.csv](importacao.csv) lista as 47 gravações únicas com a coluna `id_roblox` preenchida após o envio. Uma nova execução preserva IDs já preenchidos nessa planilha.

A preparação só retira bordas abaixo de −50 dBFS RMS com margem de 150 ms; não remove pausas internas. Foram preservados aproximadamente 87,83 segundos dos 89,13 segundos decodificados. Esse critério automático não substitui ouvir as cópias, especialmente respirações e finais suaves.

**36 entradas do roteiro ficam acima do tempo sugerido** (incluindo reusos). Os tempos eram estimativas para gravação; as falas foram preservadas. A futura reprodução deve usar a duração real e limitar sobreposição, sem atrasar as regras/turnos para terminar a fala.

Quatro gravações têm amostras próximas de 0 dBFS: ruptura-aviso do Treant, entrada 01 do Treant, ataque 02 do goblin e ataque 02 do bandido. Isso é um sinal técnico para escuta, não prova de distorção audível. Não houve escuta subjetiva nesta preparação nem correção de saturação.

## Integração no jogo

Os 47 WAV foram enviados pelo Creator Hub em 11/10/2026 para a conta Reset45206551, sem distribuição no Creator Store e sem publicar o jogo. Os IDs reais estão em `ids_roblox.json` e na coluna `id_roblox` de `importacao.csv`.

`python tools/dublagem/integrar_npcs.py` valida a planilha e gera `src/shared/DublagemNPCs.luau`: 56 entradas com duração medida e os nove reusos autorizados. O gerador antigo `gerar.py` continua separado.

O jogo local liga entrada, ataque, dor, pouca vida, derrota, fases e avisos/execuções do Treant a snapshots/recibos confirmados. Variações alternam sem mudar pitch. Falas extras de acerto/erro/provocação, alerta/uivo e ameaça específica do urso permanecem no catálogo para contextos futuros; não inventam novas ações no jogo. Duas vozes NPC no máximo, fila de quatro com validade curta, prioridade para avisos/derrota e volume do grupo MoshokuEfeitos. Ocultar, sair ou trocar partida cancela sons/pendências.

Studio: 47 IDs carregaram e aceitaram Play na bancada silenciosa; controlador 10/10, specs 1.096/0. Goblin e Treant tiveram gatilhos reais observados com Loaded/IsPlaying; Presas iniciou usando o ID da ameaça do lobo. Isso não é aprovação subjetiva da qualidade sonora nem teste em servidor publicado/outro aparelho.

**Pendente:** autorização específica para conceder à experiência MoshokuRPGMesa (10769906362) acesso persistente às versões dos 47 áudios. A revisão automática bloqueou o botão Add nessa etapa; não contornar nem publicar o jogo. Carregamento no Studio da conta proprietária não substitui essa autorização nem um teste com outras contas.

## Reproduzir a preparação

`python tools/dublagem/preparar_npcs.py --ffmpeg CAMINHO_DO_FFMPEG`

O script exige FFmpeg disponível; não instala nem baixa nada automaticamente. A execução inicial usou ferramenta temporária extraída de `imageio-ffmpeg 0.6.0` para Windows 64 bits, obtida no PyPI com SHA256 do wheel conferido: `02fa47c83703c37df6bfe4896aab339013f62bf02c5ebf2dce6da56af04ffc0a`. FFmpeg 7.1 ficou fora do projeto, sem dependência nova no jogo. Origem do pacote: [PyPI](https://pypi.org/project/imageio-ffmpeg/0.6.0/).

Roteiro e direção de voz: [DUBLAGEM_NPCS.md](../../docs/DUBLAGEM_NPCS.md).
