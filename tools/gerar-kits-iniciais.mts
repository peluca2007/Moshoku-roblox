/**
 * Porta STARTING_KITS do site, somente leitura, sem escolher variantes ou equipar.
 * MOSHOKU_SITE pode apontar para outra cópia da fonte original.
 * Uso (na raiz deste projeto, com o tsx já instalado no site):
 * node "../Moshoku tensei rpg/node_modules/tsx/dist/cli.mjs" --tsconfig "../Moshoku tensei rpg/tsconfig.json" tools/gerar-kits-iniciais.mts
 * Acrescente --check para conferir a saída sem escrever.
 */
import { createHash } from "node:crypto";
import { readFile, writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const SITE = resolve(process.env.MOSHOKU_SITE ?? resolve(import.meta.dirname, "..", "..", "Moshoku tensei rpg"));
const FONTE = resolve(SITE, "src/data/startingKits.ts");
const SAIDA = resolve(import.meta.dirname, "../src/shared/KitsIniciais.luau");
if (process.argv.slice(2).some((arg) => arg !== "--check")) throw new Error("Argumento desconhecido; use --check.");
const fonte = await readFile(FONTE);
const { STARTING_KITS } = await import(pathToFileURL(FONTE).href);
if (!Array.isArray(STARTING_KITS) || STARTING_KITS.length === 0) throw new Error("STARTING_KITS ausente ou vazio.");

// Serializa todos os campos da fonte: metadados novos não são descartados em silêncio.
// Recusa tipos sem representação fiel, em vez de transformar regras/dados.
function luau(value: unknown, depth = 0): string {
  if (typeof value === "string") return JSON.stringify(value).replace(/\\u([0-9a-f]{4})/gi, "\\u{$1}");
  if (typeof value === "boolean") return String(value);
  if (typeof value === "number" && Number.isFinite(value)) return String(value);
  const pad = "\t".repeat(depth);
  if (Array.isArray(value)) return `{\n${value.map((item) => `${pad}\t${luau(item, depth + 1)},`).join("\n")}\n${pad}}`;
  if (value && typeof value === "object" && Object.getPrototypeOf(value) === Object.prototype) {
    return `{\n${Object.entries(value).map(([key, item]) => `${pad}\t[${luau(key)}] = ${luau(item, depth + 1)},`).join("\n")}\n${pad}}`;
  }
  throw new Error(`Valor sem representação fiel em Luau: ${String(value)}`);
}

const subgrupos = new Set<string>();
let itens = 0;
for (const kit of STARTING_KITS) {
  if (typeof kit.subgroup !== "string" || !kit.subgroup || subgrupos.has(kit.subgroup)) throw new Error("Subgrupo ausente ou duplicado.");
  subgrupos.add(kit.subgroup);
  if (!Array.isArray(kit.items) || kit.items.length === 0) throw new Error(`Kit vazio: ${kit.subgroup}`);
  for (const item of kit.items) {
    if (typeof item.name !== "string" || !item.name || !["arma", "armadura", "geral"].includes(item.type)) throw new Error(`Item inválido: ${kit.subgroup}`);
    if (item.description !== undefined && typeof item.description !== "string") throw new Error("Descrição inválida.");
    if (item.baseDie !== undefined && typeof item.baseDie !== "string") throw new Error("Dado inválido.");
    if (item.acBonus !== undefined && (typeof item.acBonus !== "number" || !Number.isFinite(item.acBonus))) throw new Error("CA inválida.");
    itens++;
  }
}

const sha256 = createHash("sha256").update(fonte).digest("hex");
const saida = `-- GERADO por tools/gerar-kits-iniciais.mts. Não edite à mão.
-- Fonte: site original, src/data/startingKits.ts (Cap. 1, Equipamento Inicial e a Árvore Inicial).
-- SHA256 da fonte: ${sha256}
-- Nomes/alternativas/descrições preservados; este catálogo não escolhe nem equipa itens.
local LISTA = ${luau(STARTING_KITS)}

local function congelar(valor)
\tif type(valor) == "table" then
\t\tfor _, filho in valor do
\t\t\tcongelar(filho)
\t\tend
\t\ttable.freeze(valor)
\tend
end
congelar(LISTA)

local POR_SUBGRUPO = {}
for _, kit in LISTA do
\tPOR_SUBGRUPO[kit.subgroup] = kit
end
table.freeze(POR_SUBGRUPO)

return table.freeze({
\tLISTA = LISTA,
\tPOR_SUBGRUPO = POR_SUBGRUPO,
\tFONTE = "src/data/startingKits.ts",
\tSHA256_FONTE = "${sha256}",
\t-- Mesmo contrato de getStartingKit no site: chave exata de Tree.subgroup, nil se ausente.
\tobter = function(subgrupo)
\t\treturn POR_SUBGRUPO[subgrupo]
\tend,
})
`;
if (process.argv.includes("--check")) {
  if (await readFile(SAIDA, "utf8") !== saida) throw new Error("KitsIniciais.luau difere da fonte; rode o gerador.");
  console.log(`Kits conferidos: ${subgrupos.size} subgrupos, ${itens} itens, SHA256 ${sha256}.`);
} else {
  await writeFile(SAIDA, saida, "utf8");
  console.log(`Gerado ${SAIDA}: ${subgrupos.size} subgrupos, ${itens} itens.`);
}
