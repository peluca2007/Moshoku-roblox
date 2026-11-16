# Arte de interface gerada localmente (ARTE1)

Geração de imagem offline e gratuita para painéis, ícones e retratos da interface. Tudo fica fora do git, em `build/ferramentas/` (ignorado por `build/` no `.gitignore`).

## O que foi instalado (15/11/2026)

| Item | Versão / origem | Licença |
|---|---|---|
| stable-diffusion.cpp, backend Vulkan (`sd-cli.exe`) | release `master-1104-5dcfa79`, <https://github.com/leejet/stable-diffusion.cpp/releases> (`sd-master-5dcfa79-bin-win-vulkan-x64.zip`) | MIT |
| SDXL base 1.0 (`sd_xl_base_1.0.safetensors`, 6,9 GB, SHA256 `31e35c80…7e5b` conferido com o ETag do Hugging Face) | `stabilityai/stable-diffusion-xl-base-1.0` | CreativeML Open RAIL++-M: uso comercial permitido, com restrições de uso (sem conteúdo ilícito/danoso). Preciso manter o aviso da licença se redistribuir o modelo; as imagens geradas são nossas. |
| VAE SDXL fp16-fix (`sdxl_vae_fp16_fix.safetensors`, SHA256 `235745af…c6e1`) | `madebyollin/sdxl-vae-fp16-fix` | MIT |

Rejeitado: **SDXL-Turbo** (licença Stability AI de pesquisa/não comercial, não serve a um jogo comercial). Escolhi sd.cpp+Vulkan em vez de ComfyUI/DirectML/ZLUDA por ser binário único, sem Python/torch e sem dependência de driver especial; funcionou de primeira na RX 7600.

Layout: `build/ferramentas/sdcpp/` (binário e DLLs), `build/ferramentas/modelos/` (checkpoint e VAE). Amostras em `build/arte/amostras/`.

## Como usar

```
python tools/arte/gerar_imagem.py --estilo icone_habilidade -p "a sword slash" -s 3 -o build/arte/x.png
python tools/arte/gerar_imagem.py -p "..." -n "negativo" -W 1024 -H 256 --passos 25 --cfg 6.5 -s 7 -o x.png
python tools/arte/remover_fundo.py x.png x_transparente.png          # modo escuro (padrão)
python tools/arte/remover_fundo.py x.png y.png --modo borda --max 40  # só o fundo ligado às bordas
python tools/arte/gerar_amostras.py                                   # regenera as 5 amostras
```

Estilos (`--estilo`): `painel_pincelada` (1024x256), `icone_habilidade` (512x512, fundo preto para o recorte), `retrato` (768x1024). Passar `-W/-H/--passos` e `-n` sobrescreve. Com `--semente -1` a semente é aleatória. Em worktrees, o script acha as ferramentas na raiz do repositório principal; `MOSHOKU_FERRAMENTAS` sobrescreve o caminho.

## Tempo medido (RX 7600 8 GB, 25 passos)

Cerca de **28 s por imagem**, tanto 1024x256 quanto 512x512 (5 amostras: 27,6 a 28,5 s, incluindo carregar o modelo de 6,9 GB a cada chamada). Retrato 768x1024 não foi medido.

## Limitações (franqueza)

- Qualidade das amostras: **utilizável como ponto de partida, não final**. Os painéis 1024x256 saem com listras verticais e manchas claras (formato muito fora da resolução nativa do SDXL, ~1024x1024); o ícone de golpe e o de defender saíram aceitáveis, o de esquiva ganhou cenário em vez de ícone isolado. Não chega ao nível de Expedition 33 sem curadoria.
- Melhorias a testar: gerar painéis em 1024x1024 e recortar, ou 1344x768; várias sementes e escolher; LoRA/modelo de pintura a óleo com licença conferida; img2img sobre pinceladas desenhadas à mão; ESRGAN (`--upscale-model`) para subir resolução.
- O recorte `remover_fundo.py` por luminância assume fundo escuro; áreas escuras internas do ícone também ficam translúcidas (use `--modo borda` nesses casos). Não há controle de texto: letras geradas são ruins, por isso o negativo as proíbe; rótulos devem ser texto do Roblox.
- A imagem gerada por IA não tem garantia de ineditismo; revisar antes de usar como marca do jogo.
- Obs. de instalação: baixar o checkpoint com **um** `curl` só; dois downloads no mesmo arquivo corromperam o primeiro (detectado pelo SHA256).
