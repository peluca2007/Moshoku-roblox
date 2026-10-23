"""Gera docs/DUBLAGEM.md e src/shared/Dublagem.luau a partir de:
  - tools/dublagem/falas_fisicas.json (gritos das técnicas físicas e falas gerais);
  - os cânticos (incantation) do próprio livro, lidos do catálogo em src/shared/Livro;
  - tools/dublagem/ids.json (chave -> "rbxassetid://..." depois que o áudio é enviado).

Nomes de arquivo: <tipo>__<arvore>__<tecnica>__NN.ogg (tipos: cantico, nome, grito)
e geral__<situacao>__NN.ogg. A chave do Luau é o nome sem extensão.
Uso: python tools/dublagem/gerar.py
"""
import glob
import json
import os
import re

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FALAS = json.load(open(os.path.join(RAIZ, "tools/dublagem/falas_fisicas.json"), encoding="utf-8"))
ids_path = os.path.join(RAIZ, "tools/dublagem/ids.json")
IDS = json.load(open(ids_path, encoding="utf-8")) if os.path.exists(ids_path) else {}

# Técnicas mágicas executáveis (as que têm cântico no livro).
MAGICAS = [
    "agua:respingo", "agua:bola-de-agua", "agua:flecha-de-agua", "agua:impacto-de-gelo", "agua:lamina-de-gelo",
    "agua:escudo-de-agua", "agua:nevoa-densa", "vento:rajada-curta", "vento:lamina-de-vento", "vento:empurrao",
    "vento:passo-de-vento", "vento:sopro-de-poeira", "vento:vacuo-localizado", "terra:pedrisco", "terra:bala-de-pedra",
    "terra:atoleiro", "terra:muro-de-terra", "terra:lanca-de-pedra", "terra:mao-de-terra", "cura:cura", "cura:estancar",
    "cura:selar-a-ferida", "cura:vigor-emprestado", "desintoxicacao:purgar", "desintoxicacao:antidoto",
    "desintoxicacao:peconha", "desintoxicacao:rosa-preta", "teorica:dardo-arcano", "teorica:anteparo-teorico",
    "invocacao:chamado", "fogo:brasa", "fogo:bola-de-fogo", "fogo:fagulha", "fogo:toque-escaldante",
    "fogo:muro-de-chamas", "fogo:clarao",
]
canticos = {}
for arq in glob.glob(os.path.join(RAIZ, "src/shared/Livro/Dados/Arvores/*.luau")):
    t = open(arq, encoding="utf-8").read()
    for m in re.finditer(r'id = "ability/([a-z\-]+)/Principiante/([a-z\-]+)"', t):
        seg = t[m.end():m.end() + 6000]
        nome = re.search(r'\bname = "([^"]+)"', seg)
        inc = re.search(r'incantation = "((?:[^"\\]|\\.)*)"', seg)
        canticos[(m.group(1), m.group(2))] = (
            nome.group(1) if nome else m.group(2),
            json.loads('"' + inc.group(1) + '"') if inc else "",
        )


def segundos_do_texto(texto, ritmo=2.1):
    palavras = len(re.findall(r"\w+", texto))
    return round(palavras / ritmo + 1.0, 1)


def maximo(seg):
    return round(seg * 1.3 + 0.2, 1)


linhas = []  # (chave, tipo, quando, texto, segundos)
for item in MAGICAS:
    arv, tec = item.split(":")
    nome, inc = canticos.get((arv, tec), (tec, ""))
    if not inc:
        continue
    ultima = inc.strip().split("\n")[-1]
    linhas.append((f"cantico__{arv}__{tec}__01", "cantico", f"{nome}: cântico completo antes de soltar a magia", inc, segundos_do_texto(inc)))
    linhas.append((f"nome__{arv}__{tec}__01", "nome", f"{nome}: só o nome gritado, na hora de soltar", ultima, 1.2))
for t in FALAS["tecnicas"]:
    for n, (texto, seg) in enumerate(t["falas"], 1):
        linhas.append((f"grito__{t['arvore']}__{t['id']}__{n:02d}", "grito", f"{t['nome']}: {t['quando']}", texto, seg))
for g in FALAS["geral"]:
    for n, (texto, seg) in enumerate(g["falas"], 1):
        linhas.append((f"geral__{g['id']}__{n:02d}", "geral", g["quando"], texto, seg))

md = [
    "# Dublagem — falas para gravar", "",
    "Gerado por `python tools/dublagem/gerar.py` a partir do catálogo do livro (cânticos) e de `tools/dublagem/falas_fisicas.json` (gritos). **Não edite este arquivo à mão**: edite o JSON e gere de novo.", "",
    "## Como gravar e entregar", "",
    "1. **Nome do arquivo = a coluna Arquivo**, em minúsculas, sem espaço nem acento, extensão `.ogg` (ou `.mp3`). O nome é a chave que o jogo usa.",
    "2. **Duração**: grave perto do *Alvo (s)* e **nunca passe do Máx (s)**. O jogo toca a fala junto da animação; fala longa demais atropela o turno seguinte. Corte o silêncio do começo e do fim.",
    "3. **Formato**: mono, 44,1 kHz, pico em −3 dB, sem música nem ruído de fundo. Uma fala por arquivo.",
    "4. **Interpretação**: *cântico* = voz solene e ritmada, pode dividir em versos; *nome* = grito curto e seco; *grito* = voz de combate, projeção alta; *geral* = reações curtas.",
    "5. **Enviar ao Roblox**: Creator Hub → Assets → Audio. O envio de áudio pode exigir verificação de conta e seguir as regras vigentes do Roblox; confira lá.",
    "6. **Ligar ao jogo**: copie o número de cada áudio para `tools/dublagem/ids.json`, no formato `{\"grito__deus-da-espada__investida-espada__01\": \"rbxassetid://123456\"}`, e rode `python tools/dublagem/gerar.py`. Falas sem ID ficam mudas.", "",
    "Os tempos do *Alvo* nos cânticos são estimativas (palavras ÷ 2,1 por segundo + 1 s); se a sua leitura solene for mais lenta, vale o Máx.", "",
    f"**Total: {len(linhas)} falas.** Prioridade sugerida: `geral` e os gritos do ataque básico e do Deus da Espada (o que mais se repete); depois os `cantico` das magias que você mais usar.", "",
]
titulos = {
    "geral": "Falas gerais (reações)",
    "grito": "Gritos das técnicas físicas",
    "nome": "Nome da magia gritado",
    "cantico": "Cânticos das magias (texto do livro)",
}
for tipo in ["geral", "grito", "nome", "cantico"]:
    md += [f"## {titulos[tipo]}", "", "| Arquivo | Quando toca | Fala | Alvo (s) | Máx (s) | ID |", "|---|---|---|---|---|---|"]
    for chave, tp, quando, texto, seg in linhas:
        if tp == tipo:
            fala = texto.replace("\n", " / ").replace("|", "\\|")
            md.append(f"| `{chave}.ogg` | {quando} | {fala} | {seg} | {maximo(seg)} | {IDS.get(chave, '—')} |")
    md.append("")
# Seções mantidas à mão (fonte fora deste gerador) sobrevivem à regeneração: copiadas do arquivo atual.
MANTIDAS = ["## Narração da cena de abertura"]
caminho_md = os.path.join(RAIZ, "docs/DUBLAGEM.md")
if os.path.exists(caminho_md):
    with open(caminho_md, encoding="utf-8") as f:
        atual = f.read()
    for titulo_secao in MANTIDAS:
        inicio = atual.find("\n" + titulo_secao)
        if inicio >= 0:
            fim = atual.find("\n## ", inicio + 1)
            trecho = atual[inicio + 1:fim if fim >= 0 else len(atual)].rstrip("\n")
            md += [trecho, ""]
with open(caminho_md, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(md))

lu = [
    "-- GERADO por tools/dublagem/gerar.py: não edite. Falas dubladas (docs/DUBLAGEM.md).",
    "-- IDS só tem as falas já enviadas ao Roblox; as outras ficam mudas.",
    "local Dublagem = {}", "", "Dublagem.SEGUNDOS = {",
]
for chave, _tp, _q, _t, seg in linhas:
    lu.append(f'\t["{chave}"] = {seg},')
lu += ["}", "", "Dublagem.IDS = {"]
for chave, *_ in linhas:
    if chave in IDS:
        lu.append(f'\t["{chave}"] = "{IDS[chave]}",')
lu += [
    "}", "",
    "-- Variantes com ID cujo nome começa por `prefixo` (ex.: \"grito__deus-da-espada__investida-espada\").",
    "function Dublagem.variantes(prefixo: string): { string }",
    "\tlocal lista = {}",
    "\tfor chave in Dublagem.IDS do",
    "\t\tif string.sub(chave, 1, #prefixo) == prefixo then",
    "\t\t\ttable.insert(lista, chave)",
    "\t\tend",
    "\tend",
    "\ttable.sort(lista)",
    "\treturn lista",
    "end", "", "return Dublagem", "",
]
with open(os.path.join(RAIZ, "src/shared/Dublagem.luau"), "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(lu))
print(f"{len(linhas)} falas; {len(IDS)} com ID")
