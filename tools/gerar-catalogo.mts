/**
 * Catálogo do livro para o Roblox — formato 2 (docs/CONTRATOS.md §2–§3).
 *
 * Lê o site (somente leitura) e gera src/shared/Livro/ inteiro:
 *   Catalogo.luau          índice: POR_ID, listas por espécie, versões
 *   Manifesto.luau         fontes, hashes, contagens, exclusões
 *   Dados/<Dominio>.luau   entradas { id, kind, sourceId, sourceRef, data }
 *   Dados/Arvores/<x>.luau uma árvore com seus ranks, habilidades, talentos e maestrias
 *
 * Uso:
 *   powershell -File tools/gerar-catalogo.ps1             gera (staging + troca)
 *   powershell -File tools/gerar-catalogo.ps1 --verificar regenera em memória e compara a pasta inteira
 *
 * Determinístico: mesma fonte, mesmos bytes; sem data/hora no conteúdo.
 */
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { existsSync, rmSync, statSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { mkdir, readFile, readdir, rename, rm, writeFile } from "node:fs/promises";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const FORMATO = 2;
const EXPORTADOR = "gerar-catalogo 2.0.0";
const SITE = resolve(process.env.MOSHOKU_SITE ?? resolve(import.meta.dirname, "..", "..", "Moshoku tensei rpg"));
const DESTINO = resolve(import.meta.dirname, "..", "src", "shared", "Livro");
const verificar = process.argv.includes("--verificar");
// Geração (não --verificar): trava ANTES de ler registros e fontes, para que outra
// geração não grave entre a nossa leitura e a nossa escrita. Removida na saída.
if (!verificar) {
  const trava = DESTINO + ".lock";
  try {
    writeFileSync(trava, String(process.pid), { flag: "wx" });
  } catch {
    console.error(`Outra geração está em andamento (${trava}). Se não estiver, apague o arquivo.`);
    process.exit(3);
  }
  process.on("exit", () => {
    try { rmSync(trava, { force: true }); } catch { /* já removida */ }
  });
}
const fontesUsadas = new Set<string>();
async function site(relativo: string) {
  fontesUsadas.add(`src/${relativo}`);
  return import(pathToFileURL(resolve(SITE, "src", relativo)).href);
}

// ---------------------------------------------------------------------------
// Validação e serialização Luau

class ErroDeCatalogo extends Error {}
const falhar = (caminho: string, motivo: string): never => {
  throw new ErroDeCatalogo(`${caminho}: ${motivo}`);
};

/** Recusa o que não é JSON puro e denso, ANTES de qualquer serialização (onde NaN viraria null e funções sumiriam). */
function validar(valor: unknown, caminho: string): void {
  if (valor === null) falhar(caminho, "null não é aceito");
  if (valor === undefined) falhar(caminho, "undefined dentro de lista");
  switch (typeof valor) {
    case "string": {
      for (let i = 0; i < valor.length; i++) {
        const c = valor.charCodeAt(i);
        if (c >= 0xd800 && c <= 0xdbff) {
          const d = valor.charCodeAt(i + 1);
          if (!(d >= 0xdc00 && d <= 0xdfff)) falhar(caminho, "texto com surrogate isolado (UTF-16 inválido)");
          i++;
        } else if (c >= 0xdc00 && c <= 0xdfff) falhar(caminho, "texto com surrogate isolado (UTF-16 inválido)");
      }
      return;
    }
    case "number":
      if (!Number.isFinite(valor)) falhar(caminho, `número não finito (${valor})`);
      return;
    case "boolean":
      return;
    case "object": {
      if (Array.isArray(valor)) {
        for (let i = 0; i < valor.length; i++) {
          if (!(i in valor)) falhar(`${caminho}[${i}]`, "lista com buraco");
          validar(valor[i], `${caminho}[${i}]`);
        }
        return;
      }
      const proto = Object.getPrototypeOf(valor);
      if (proto !== Object.prototype && proto !== null) falhar(caminho, `objeto não simples (${proto?.constructor?.name})`);
      for (const [k, v] of Object.entries(valor as Record<string, unknown>)) {
        if (v === undefined) continue; // opcional ausente do TypeScript: omitido
        validar(v, `${caminho}.${k}`);
      }
      return;
    }
    default:
      falhar(caminho, `tipo não suportado (${typeof valor})`);
  }
}

/** Remove opcionais ausentes; o resto já foi validado. */
function limpar(valor: unknown): unknown {
  if (Array.isArray(valor)) return valor.map(limpar);
  if (valor && typeof valor === "object")
    return Object.fromEntries(Object.entries(valor).filter(([, v]) => v !== undefined).map(([k, v]) => [k, limpar(v)]));
  return valor;
}

/** Forma canônica: chaves em ordem de bytes UTF-8, sem espaços (CONTRATOS §3.3). */
function canonico(valor: unknown): string {
  if (Array.isArray(valor)) return "[" + valor.map(canonico).join(",") + "]";
  if (valor && typeof valor === "object") {
    const chaves = Object.keys(valor).sort((a, b) => Buffer.compare(Buffer.from(a), Buffer.from(b)));
    return "{" + chaves.map((k) => JSON.stringify(k) + ":" + canonico((valor as Record<string, unknown>)[k])).join(",") + "}";
  }
  return JSON.stringify(valor);
}

/** String Luau: escapes próprios do Luau (JSON emitiria \u0000, inválido em Luau). */
function textoLuau(texto: string): string {
  let saida = '"';
  for (const ch of texto) {
    const c = ch.codePointAt(0)!;
    if (ch === "\\") saida += "\\\\";
    else if (ch === '"') saida += '\\"';
    else if (ch === "\n") saida += "\\n";
    else if (ch === "\r") saida += "\\r";
    else if (ch === "\t") saida += "\\t";
    else if (c < 0x20 || c === 0x7f) saida += `\\u{${c.toString(16)}}`;
    else saida += ch;
  }
  return saida + '"';
}

const IDENT = /^[A-Za-z_][A-Za-z0-9_]*$/;
const RESERVADAS = new Set(["and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while", "continue", "export", "type"]);

function luau(valor: unknown, nivel: number): string {
  const recuo = "\t".repeat(nivel);
  if (typeof valor === "string") return textoLuau(valor);
  if (typeof valor === "number") return Number.isInteger(valor) ? String(valor) : String(valor);
  if (typeof valor === "boolean") return valor ? "true" : "false";
  if (Array.isArray(valor)) {
    if (valor.length === 0) return "{}";
    return "{\n" + valor.map((v) => `${recuo}\t${luau(v, nivel + 1)},`).join("\n") + `\n${recuo}}`;
  }
  const campos = Object.entries(valor as Record<string, unknown>);
  if (campos.length === 0) return "{}";
  return "{\n" + campos.map(([k, v]) => {
    const chave = IDENT.test(k) && !RESERVADAS.has(k) ? k : `[${textoLuau(k)}]`;
    return `${recuo}\t${chave} = ${luau(v, nivel + 1)},`;
  }).join("\n") + `\n${recuo}}`;
}

// Congelamento profundo no próprio módulo gerado (CONTRATOS: catálogo imutável).
const CONGELAR = `local function congelar(t)
	for _, v in t do
		if type(v) == "table" and not table.isfrozen(v) then
			congelar(v)
		end
	end
	return table.freeze(t)
end
`;

// ---------------------------------------------------------------------------
// Identificadores (CONTRATOS §2.1)

/** Percent-encoding dos bytes UTF-8, preservando ASCII alfanumérico e -._~ */
function segmento(texto: string): string {
  if (typeof texto !== "string" || texto.length === 0) falhar("id", `segmento vazio ou inválido (${texto})`);
  let saida = "";
  for (const byte of Buffer.from(texto, "utf8")) {
    const ch = String.fromCharCode(byte);
    saida += /[A-Za-z0-9\-._~]/.test(ch) ? ch : "%" + byte.toString(16).toUpperCase().padStart(2, "0");
  }
  return saida;
}
const idDe = (kind: string, ...partes: string[]) => [kind, ...partes.map(segmento)].join("/");

interface Entrada {
  id: string;
  kind: string;
  sourceId?: string;
  sourceRef: { path: string; symbol: string; selector: string };
  data: unknown;
}

const porId = new Map<string, Entrada>();
function registrar(e: Entrada, dominio: Entrada[]) {
  if (porId.has(e.id)) falhar(e.sourceRef.selector, `id repetido: ${e.id}`);
  validar(e.data, e.sourceRef.selector);
  e.data = limpar(e.data);
  porId.set(e.id, e);
  dominio.push(e);
}

function listaComIds<T extends { id?: string }>(lista: T[], kind: string, path: string, symbol: string, dominio: Entrada[]) {
  if (!Array.isArray(lista)) falhar(symbol, "não é lista");
  for (const item of lista) {
    if (!item || typeof item.id !== "string") falhar(`${symbol}`, `item sem id (${JSON.stringify(item).slice(0, 60)})`);
    registrar({ id: idDe(kind, item.id), kind, sourceId: item.id, sourceRef: { path, symbol, selector: `${symbol}[id=${item.id}]` }, data: item }, dominio);
  }
}

// Entidades sem id na fonte recebem id num REGISTRO explícito (CONTRATOS §2.1), nunca
// derivado do nome a cada geração. tools/registros/<nome>.json: { "<chave na fonte>": "<id>" }.
// Item novo fora do registro interrompe a geração; --registrar acrescenta (slug UMA vez) e
// pede revisão. Renomear na fonte NÃO cria id novo: a geração falha e pede para trocar a
// chave no registro mantendo o id. Tudo é validado antes de gravar qualquer arquivo.
const REGISTROS = resolve(import.meta.dirname, "registros");
const registrarNovos = process.argv.includes("--registrar");
if (registrarNovos && verificar) {
  console.error("--verificar é somente leitura; não combine com --registrar.");
  process.exit(2);
}
const proprio = (obj: object, k: string) => Object.prototype.hasOwnProperty.call(obj, k);
const slug = (k: string) => k.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
// arquivo -> bytes finais (os lidos, ou os que serão gravados) e se precisa gravar.
// A gravação só acontece depois da trava e de TODA a validação (ver o fim do arquivo).
const registrosUsados = new Map<string, { texto: string; gravar: boolean }>();
const ID_DE_REGISTRO = /^[a-z0-9]+(-[a-z0-9]+)*$/;
async function listaComRegistro<T>(lista: T[], chave: (item: T) => string, registro: string, kind: string, path: string, symbol: string, dom: Entrada[]) {
  const arquivo = resolve(REGISTROS, `${registro}.json`);
  const original = existsSync(arquivo) ? await readFile(arquivo, "utf8") : "{}\n";
  const lido = JSON.parse(original);
  if (!lido || typeof lido !== "object" || Array.isArray(lido)) falhar(registro, "registro precisa ser um objeto");
  const mapa: Record<string, string> = Object.assign(Object.create(null), lido);
  const chaves = lista.map(chave);
  if (new Set(chaves).size !== chaves.length) falhar(symbol, `chaves repetidas na fonte para o registro ${registro}`);
  for (const [k, v] of Object.entries(mapa))
    if (typeof v !== "string" || !ID_DE_REGISTRO.test(v)) falhar(registro, `id inválido para "${k}": ${v}`);
  const faltando = chaves.filter((k) => !proprio(mapa, k));
  const sobrando = Object.keys(mapa).filter((k) => !chaves.includes(k));
  if (sobrando.length && faltando.length)
    falhar(symbol, `possível renomeação em ${registro}.json: sumiram ${sobrando.join(", ")}; surgiram ${faltando.join(", ")}. Troque a CHAVE no registro mantendo o id.`);
  if (sobrando.length) falhar(symbol, `registro ${registro}.json tem entradas que sumiram da fonte: ${sobrando.join(", ")}`);
  if (faltando.length && !registrarNovos) falhar(symbol, `sem id no registro ${registro}.json: ${faltando.join(", ")} (rode com --registrar e revise)`);
  const novos: Record<string, string> = {};
  for (const k of faltando) {
    novos[k] = slug(k);
    if (!ID_DE_REGISTRO.test(novos[k])) falhar(registro, `não há id possível para "${k}" (slug "${novos[k]}"); escreva-o à mão no registro`);
  }
  const ids = [...Object.values(mapa), ...Object.values(novos)];
  const repetido = ids.find((id, i) => ids.indexOf(id) !== i);
  if (repetido) falhar(registro, `id repetido no registro: ${repetido}`);
  Object.assign(mapa, novos);
  registrosUsados.set(`tools/registros/${registro}.json`,
    faltando.length ? { texto: JSON.stringify(mapa, null, 2) + "\n", gravar: true } : { texto: original, gravar: false });
  for (const item of lista) {
    const k = chave(item);
    registrar({ id: idDe(kind, mapa[k]), kind, sourceId: k, sourceRef: { path, symbol, selector: `${symbol}[${registro}=${k}]` }, data: item }, dom);
  }
  return mapa;
}

// ---------------------------------------------------------------------------
// Fontes

const { TREES } = await site("data/trees/index.ts");
const { RANKS } = await site("lib/types.ts");
const { RACES } = await site("data/races.ts");
const { BACKGROUNDS, SUBTABLES } = await site("data/backgrounds.ts");
const { WEAPON_GROUPS } = await site("data/weaponGroups.ts");
const { SHOP_ITEMS, estaAVenda } = await site("data/shopItems.ts");
const { COMPENDIO_ITENS } = await site("data/compendioDeItens.ts");
const { BESTIARIO } = await site("data/preMadeMonsters.ts");
const { COMBINED_SPELLS } = await site("data/combinedSpells.ts");
const { SKILLS } = await site("data/skills.ts");
const { CONDICOES, ESTADOS_DE_REGRA } = await site("data/condicoes.ts");

const dominios = new Map<string, Entrada[]>();
const dominio = (nome: string) => {
  if (!dominios.has(nome)) dominios.set(nome, []);
  return dominios.get(nome)!;
};
const contagens: Record<string, number> = {};
const contar = (kind: string) => (contagens[kind] = (contagens[kind] ?? 0) + 1);

// Arquivo real de cada árvore (sourceRef.path) e árvores fora de TREES.
const arquivosArvore = (await readdir(resolve(SITE, "src/data/trees"))).filter((f) => f.endsWith(".ts") && !f.endsWith(".test.ts") && f !== "index.ts").sort();
const arquivoDaArvore = new Map<string, string>();
const excluidos: string[] = [];
for (const f of arquivosArvore) {
  const mod = await site(`data/trees/${f}`);
  const exportadas = Object.values(mod).filter((v: any) => v && typeof v === "object" && Array.isArray(v.ranks) && typeof v.id === "string") as { id: string }[];
  if (exportadas.length === 0) excluidos.push(`src/data/trees/${f} (sem árvore exportada)`);
  for (const a of exportadas) {
    if (TREES.some((t: { id: string }) => t.id === a.id)) arquivoDaArvore.set(a.id, `src/data/trees/${f}`);
    else excluidos.push(`src/data/trees/${f}: árvore "${a.id}" não está em TREES`);
  }
}

// Árvores, normalizadas em entradas por espécie.
const arvoresPorArquivo = new Map<string, Entrada[]>();
const rankKeys = new Set<string>(RANKS);
for (const arvore of TREES) {
  const lista: Entrada[] = [];
  arvoresPorArquivo.set(arvore.id, lista);
  const treeId = idDe("tree", arvore.id);
  const base = `TREES[id=${arvore.id}]`;
  const { ranks, ...dadosArvore } = arvore;
  const rankIds: string[] = [];
  const vistosRank = new Set<string>();
  for (const rank of ranks) {
    if (!rankKeys.has(rank.rank)) falhar(`${base}`, `rank fora de RANKS: ${rank.rank}`);
    if (vistosRank.has(rank.rank)) falhar(`${base}`, `rank repetido: ${rank.rank}`);
    vistosRank.add(rank.rank);
    const rankId = idDe("rank", arvore.id, rank.rank);
    rankIds.push(rankId);
    const sel = `${base}.ranks[rank=${rank.rank}]`;
    const { abilities, talents, mastery, ...dadosRank } = rank;
    const abilityIds = abilities.map((h: { id: string }) => {
      const id = idDe("ability", arvore.id, rank.rank, h.id);
      registrar({ id, kind: "ability", sourceId: h.id, sourceRef: { path: arquivoDaArvore.get(arvore.id) ?? falhar(`TREES[id=${arvore.id}]`, "arquivo de origem não encontrado"), symbol: "TREES", selector: `${sel}.abilities[id=${h.id}]` }, data: { ...h, treeId: arvore.id, rank: rank.rank } }, lista);
      contar("ability");
      return id;
    });
    const talentIds = (talents ?? []).map((t: { id: string }) => {
      const id = idDe("talent", arvore.id, rank.rank, t.id);
      registrar({ id, kind: "talent", sourceId: t.id, sourceRef: { path: arquivoDaArvore.get(arvore.id) ?? falhar(`TREES[id=${arvore.id}]`, "arquivo de origem não encontrado"), symbol: "TREES", selector: `${sel}.talents[id=${t.id}]` }, data: { ...t, treeId: arvore.id, rank: rank.rank } }, lista);
      contar("talent");
      return id;
    });
    let masteryId: string | undefined;
    if (mastery) {
      masteryId = idDe("mastery", arvore.id, rank.rank);
      registrar({ id: masteryId, kind: "mastery", sourceRef: { path: arquivoDaArvore.get(arvore.id) ?? falhar(`TREES[id=${arvore.id}]`, "arquivo de origem não encontrado"), symbol: "TREES", selector: `${sel}.mastery` }, data: { ...mastery, treeId: arvore.id, rank: rank.rank } }, lista);
      contar("mastery");
    }
    registrar({ id: rankId, kind: "rank", sourceId: rank.rank, sourceRef: { path: arquivoDaArvore.get(arvore.id) ?? falhar(`TREES[id=${arvore.id}]`, "arquivo de origem não encontrado"), symbol: "TREES", selector: sel }, data: { ...dadosRank, rank: rank.rank, treeId: arvore.id, abilities: abilityIds, talents: talentIds, mastery: masteryId } }, lista);
    contar("rank");
  }
  registrar({ id: treeId, kind: "tree", sourceId: arvore.id, sourceRef: { path: arquivoDaArvore.get(arvore.id) ?? falhar(`TREES[id=${arvore.id}]`, "arquivo de origem não encontrado"), symbol: "TREES", selector: base }, data: { ...dadosArvore, ranks: rankIds } }, lista);
  contar("tree");
}

listaComIds(RACES, "race", "src/data/races.ts", "RACES", dominio("Racas"));
for (const raca of RACES as { id: string; upgrades?: { id: string }[] }[])
  for (const up of raca.upgrades ?? [])
    registrar({ id: idDe("race-upgrade", raca.id, up.id), kind: "race-upgrade", sourceId: up.id, sourceRef: { path: "src/data/races.ts", symbol: "RACES", selector: `RACES[id=${raca.id}].upgrades[id=${up.id}]` }, data: { ...up, raceId: raca.id } }, dominio("Racas"));
listaComIds(BACKGROUNDS, "background", "src/data/backgrounds.ts", "BACKGROUNDS", dominio("Antecedentes"));
for (const [subId, sub] of Object.entries(SUBTABLES as Record<string, { entries: { id: string }[] }>)) {
  const { entries, ...resto } = sub;
  const entryIds = entries.map((e) => {
    const id = idDe("subtable-entry", subId, e.id);
    registrar({ id, kind: "subtable-entry", sourceId: e.id, sourceRef: { path: "src/data/backgrounds.ts", symbol: "SUBTABLES", selector: `SUBTABLES.${subId}.entries[id=${e.id}]` }, data: { ...e, subtableId: subId } }, dominio("Antecedentes"));
    return id;
  });
  registrar({ id: idDe("subtable", subId), kind: "subtable", sourceId: subId, sourceRef: { path: "src/data/backgrounds.ts", symbol: "SUBTABLES", selector: `SUBTABLES.${subId}` }, data: { ...resto, entries: entryIds } }, dominio("Antecedentes"));
}
listaComIds(WEAPON_GROUPS, "weapon-group", "src/data/weaponGroups.ts", "WEAPON_GROUPS", dominio("GruposDeArma"));
// Adaptações de exportação: transformações necessárias para o formato, sem mudar regra.
const adaptacoes: string[] = [];
// Itens: o compêndio é subconjunto idêntico da loja (verificado abaixo); a fonte é SHOP_ITEMS.
// price: null no site significa "não está à venda"; o catálogo não tem null, então grava
// aVenda = estaAVenda(item) (função do próprio site) e omite o preço.
const semPreco: string[] = [];
const itens = SHOP_ITEMS.map((item: { id: string; price: unknown }) => {
	const { price, ...resto } = item;
	if (price === null) semPreco.push(item.id);
	return { ...resto, ...(price === null ? {} : { price }), aVenda: estaAVenda(item) };
});
adaptacoes.push(`SHOP_ITEMS.price null → aVenda=false sem preço (${semPreco.length} itens; aVenda vem de estaAVenda)`);
listaComIds(itens, "item", "src/data/shopItems.ts", "SHOP_ITEMS", dominio("Itens"));
for (const item of COMPENDIO_ITENS as { id: string }[]) {
	const naLoja = SHOP_ITEMS.find((i: { id: string }) => i.id === item.id);
	if (!naLoja || canonico(limpar(naLoja)) !== canonico(limpar(item))) falhar(`COMPENDIO_ITENS[id=${item.id}]`, "item do compêndio não é idêntico ao da loja");
}
registrar({ id: "item-list/compendio", kind: "item-list", sourceId: "COMPENDIO_ITENS", sourceRef: { path: "src/data/compendioDeItens.ts", symbol: "COMPENDIO_ITENS", selector: "COMPENDIO_ITENS" }, data: { items: (COMPENDIO_ITENS as { id: string }[]).map((i) => idDe("item", i.id)) } }, dominio("Itens"));
adaptacoes.push("COMPENDIO_ITENS → lista de ids (subconjunto idêntico de SHOP_ITEMS, conferido na geração)");
await listaComRegistro(BESTIARIO, (m: { nome: string }) => m.nome, "criaturas", "creature", "src/data/preMadeMonsters.ts", "BESTIARIO", dominio("Criaturas"));
listaComIds(COMBINED_SPELLS, "combined-spell", "src/data/combinedSpells.ts", "COMBINED_SPELLS", dominio("MagiasCombinadas"));
const registroPericias = await listaComRegistro(SKILLS, (p: { name: string }) => p.name, "pericias", "skill", "src/data/skills.ts", "SKILLS", dominio("Pericias"));
listaComIds(CONDICOES, "condition", "src/data/condicoes.ts", "CONDICOES", dominio("Condicoes"));
listaComIds(ESTADOS_DE_REGRA, "condition", "src/data/condicoes.ts", "ESTADOS_DE_REGRA", dominio("Condicoes"));
for (const nome of dominios.keys()) for (const e of dominios.get(nome)!) contar(e.kind);

// Constantes de regra que o jogo executa (Regras.luau), lidas do site e nunca
// copiadas à mão, com VETORES calculados pelas funções do próprio site para os
// testes diferenciais do porte em Luau (PLANO §4.D).
const { RANK_BONUS, RANK_REQUIREMENTS } = await site("lib/types.ts");
const { MAGIC_ACTIONS } = await site("data/trees/shared.ts");
const { ACOES_POR_TURNO } = await site("lib/encounterSim.ts");
const { MOLDES_CRIATURA, ARQUETIPOS_CRIATURA, aplicarPapel, atributosDaCriatura, bonusResistencia, getMoldePorPatamar } = await site("data/bestiary.ts");
const { WEAPON_DIE_LADDER, escalateWeaponDie } = await site("lib/weaponDie.ts");
// O site não exporta o dano fixo por degrau acima do topo; lê-se pela própria função.
const topoDaEscada = (WEAPON_DIE_LADDER as string[])[(WEAPON_DIE_LADDER as string[]).length - 1];
const EXCESS_STEP_DAMAGE = Number(/\+(\d+)$/.exec(escalateWeaponDie(topoDaEscada, 1))?.[1] ?? NaN);
if (!Number.isFinite(EXCESS_STEP_DAMAGE)) falhar("weaponDie.ts", "não foi possível ler o dano por degrau excedente");
const papeis = ["lacaio", "padrao", "chefe"];
const regras = {
  bonusDeRank: RANK_BONUS,
  ordemDosRanks: RANKS,
  requisitosDeRank: RANK_REQUIREMENTS,
  acoesDeMagia: MAGIC_ACTIONS,
  acoesPorTurno: ACOES_POR_TURNO,
  escadaDeDados: WEAPON_DIE_LADDER,
  excessoPorDegrau: EXCESS_STEP_DAMAGE,
  moldesDeCriatura: MOLDES_CRIATURA,
  arquetiposDeCriatura: (ARQUETIPOS_CRIATURA as { id: string; principal: string; bom: string; comum: string[]; fraco: string[]; deslocamento: number }[])
    .map((a) => ({ id: a.id, principal: a.principal, bom: a.bom, comum: a.comum, fraco: a.fraco, deslocamento: a.deslocamento })),
  vetores: {
    aplicarPapel: (MOLDES_CRIATURA as { patamar: number }[]).flatMap((m) => papeis.map((papel) => ({ patamar: m.patamar, papel, saida: aplicarPapel(m.patamar, papel) }))),
    atributosDaCriatura: (MOLDES_CRIATURA as { patamar: number }[]).map((m) => ({ patamar: m.patamar, saida: atributosDaCriatura(m.patamar) })),
    bonusResistencia: (MOLDES_CRIATURA as { patamar: number }[]).map((m) => ({ patamar: m.patamar, saida: bonusResistencia(getMoldePorPatamar(m.patamar)) })),
    escalarDado: (WEAPON_DIE_LADDER as string[]).flatMap((dado) => [0, 1, 2, 3, 5, 9].map((degraus) => ({ dado, degraus, saida: escalateWeaponDie(dado, degraus) }))),
  },
};

// Apresentação (não é regra): a identidade visual de cada árvore, como o livro e a
// ficha do site usam (cor da noite, kanji do título e selo). Vira Identidade.luau.
const { IDENTIDADE_DAS_ARVORES } = await site("data/identidadeDasArvores.ts");
const identidade: Record<string, { cor: string; kanji: string; selo: string }> = {};
for (const [arvore, v] of Object.entries(IDENTIDADE_DAS_ARVORES as Record<string, { corNoite: string; kanji: string; selo: string }>)) {
  const onde = `IDENTIDADE_DAS_ARVORES.${arvore}`;
  if (!porId.has(idDe("tree", arvore))) falhar(onde, "árvore inexistente no catálogo");
  if (!/^#[0-9a-f]{6}$/i.test(v.corNoite)) falhar(onde, `cor inválida: ${v.corNoite}`);
  if (typeof v.kanji !== "string" || !v.kanji || typeof v.selo !== "string" || !v.selo) falhar(onde, "kanji e selo obrigatórios");
  identidade[idDe("tree", arvore)] = { cor: v.corNoite.toLowerCase(), kanji: v.kanji, selo: v.selo };
}
for (const e of porId.values())
  if (e.kind === "tree" && !identidade[e.id]) console.error(`Aviso: árvore sem identidade visual: ${e.id}`);

// Referências: tudo que aponta para outra entidade precisa existir (CONTRATOS §2.1).
// Campos que guardam id LOCAL do site (não catalogId) ficam declarados no manifesto.
const camposComIdLocal = [
  "ability.requires, talent.requires (ids de habilidade ou talento da mesma árvore)",
  "ability.requiresRank.treeId (id de árvore)",
  "ability.grantsSkills, race.fixedSkills, background.fixedSkills, tree.grantedSkills, tree.masterySkillsWhenNotFirst, tree.proficiencies.periciasCobertas (nomes de perícia, aceitando 'Base (especialização)' só como referência textual; ver tools/registros/pericias.json)",
  "background.requiresSubtable (id de subtabela)",
  "tree.proficiencies.gruposDeArma (ids de grupo de arma)",
];
// Perícia especializada ("Ofícios (Forja)") vale se a base estiver no registro.
const temPericia = (nome: string) => proprio(registroPericias, nome) || proprio(registroPericias, nome.replace(/ \(.+\)$/, ""));
const conferir = (ok: boolean, onde: string, oque: string) => { if (!ok) falhar(onde, `referência inexistente: ${oque}`); };
for (const e of porId.values()) {
  const d = e.data as any;
  const onde = e.sourceRef.selector;
  if (e.kind === "ability" || e.kind === "talent") {
    for (const req of d.requires ?? []) {
      const alvo = [...porId.values()].some((o) => (o.kind === "ability" || o.kind === "talent") && (o.data as any).treeId === d.treeId && o.sourceId === req);
      conferir(alvo, onde, `requires ${req}`);
    }
    if (d.requiresRank?.treeId) conferir(porId.has(idDe("tree", d.requiresRank.treeId)), onde, `requiresRank.treeId ${d.requiresRank.treeId}`);
    if (d.requiresRank?.rank) conferir(rankKeys.has(d.requiresRank.rank), onde, `requiresRank.rank ${d.requiresRank.rank}`);
    for (const p of d.grantsSkills ?? []) conferir(temPericia(p), onde, `perícia ${p}`);
  }
  if (e.kind === "race" || e.kind === "background") for (const p of d.fixedSkills ?? []) conferir(temPericia(p), onde, `perícia ${p}`);
  if (e.kind === "background" && d.requiresSubtable) conferir(porId.has(idDe("subtable", d.requiresSubtable)), onde, `subtabela ${d.requiresSubtable}`);
  if (e.kind === "tree") {
    for (const p of d.grantedSkills?.fixed ?? []) conferir(temPericia(p), onde, `perícia ${p}`);
    for (const p of d.grantedSkills?.choose?.from ?? []) conferir(temPericia(p), onde, `perícia ${p}`);
    for (const p of d.masterySkillsWhenNotFirst ?? []) conferir(temPericia(p), onde, `perícia ${p}`);
    for (const p of d.proficiencies?.periciasCobertas ?? []) conferir(temPericia(p), onde, `perícia ${p}`);
    for (const g of d.proficiencies?.gruposDeArma ?? []) conferir(porId.has(idDe("weapon-group", g)), onde, `grupo de arma ${g}`);
  }
}

// ---------------------------------------------------------------------------
// Versões, manifesto e arquivos

const todas = [...porId.values()].sort((a, b) => Buffer.compare(Buffer.from(a.id), Buffer.from(b.id)));
// A ordem pública (listas por espécie na ordem da fonte) também é conteúdo versionado.
const ordemPublica: Record<string, string[]> = {};
for (const lista of [...arvoresPorArquivo.values(), ...dominios.values()])
  for (const e of lista) (ordemPublica[e.kind] ??= []).push(e.id);
const conteudo = "sha256:" + createHash("sha256").update(canonico({ entradas: todas.map((e) => ({ id: e.id, kind: e.kind, data: e.data })), ordem: ordemPublica })).digest("hex");
const sha = (b: Buffer | string) => createHash("sha256").update(b).digest("hex");

// Fecho transitivo dos imports das fontes (uma dependência pode mudar a exportação).
// O TypeScript vem do próprio site (já é dependência dele); nada novo neste projeto.
const ts = createRequire(resolve(SITE, "package.json"))("typescript");
async function fecho(inicio: string[]): Promise<string[]> {
  const vistos = new Set<string>();
  const fila = [...inicio];
  while (fila.length) {
    const rel = fila.pop()!;
    if (vistos.has(rel)) continue;
    vistos.add(rel);
    const texto = await readFile(resolve(SITE, rel), "utf8");
    if (!/\.tsx?$/.test(rel)) continue; // fonte não executável: só o hash
    const { importedFiles } = ts.preProcessFile(texto, true, true);
    for (const { fileName: alvo } of importedFiles) {
      let base: string | null = null;
      if (alvo.startsWith("@/")) base = "src/" + alvo.slice(2);
      else if (alvo.startsWith(".")) base = relative(SITE, resolve(SITE, dirname(rel), alvo)).replace(/\\/g, "/");
      if (!base) continue; // pacote externo: versionado pelo lockfile do site, fora do fecho
      const semJs = base.replace(/\.(m?js|jsx)$/, "");
      const candidatos = [base, semJs + ".ts", semJs + ".tsx", semJs + "/index.ts", semJs + "/index.tsx"];
      const achado = candidatos.find((c) => existsSync(resolve(SITE, c)) && statSync(resolve(SITE, c)).isFile());
      if (achado) fila.push(achado);
      else falhar(rel, `import local não resolvido no fecho das fontes: ${alvo}`);
    }
  }
  return [...vistos].sort();
}
const arquivosFonte = await fecho([...fontesUsadas]);
const files = [];
for (const rel of arquivosFonte) files.push({ path: rel, sha256: sha(await readFile(resolve(SITE, rel))) });
// Hash dos bytes do arquivo de registro como ficará em disco (lido ou a gravar).
const registros = [...registrosUsados].sort(([a], [b]) => (a < b ? -1 : 1)).map(([path, r]) => ({ path, sha256: sha(r.texto) }));
let sourceRevision: string | undefined;
let sourceDirty = true;
try {
  sourceRevision = execFileSync("git", ["-C", SITE, "rev-parse", "--short", "HEAD"], { encoding: "utf8" }).trim();
  sourceDirty = execFileSync("git", ["-C", SITE, "status", "--porcelain", "--", "src"], { encoding: "utf8" }).trim() !== "";
} catch {
  /* sem git: revisão desconhecida, conteúdo continua verificado pelos hashes */
}

const saidas = new Map<string, string>();
const CABECALHO = "-- GERADO por tools/gerar-catalogo.mts a partir do site do livro. Não edite: rode o gerador.\n";
const modulo = (comentario: string, valor: unknown) =>
  `${CABECALHO}-- ${comentario}\n${CONGELAR}return congelar(${luau(valor, 0)})\n`;
const entradaLuau = (e: Entrada) => ({ id: e.id, kind: e.kind, ...(e.sourceId ? { sourceId: e.sourceId } : {}), sourceRef: e.sourceRef, data: e.data });

const nomeArquivo = (id: string) => id.replace(/[^a-z0-9]/gi, "_");
const modulosArvore: string[] = [];
for (const [arvoreId, lista] of arvoresPorArquivo) {
  const nome = nomeArquivo(arvoreId);
  if (modulosArvore.includes(nome)) falhar("arquivos", `nome de módulo repetido: ${nome}`);
  modulosArvore.push(nome);
  saidas.set(`Dados/Arvores/${nome}.luau`, modulo(`Árvore "${arvoreId}": árvore, ranks, habilidades, talentos e maestrias.`, lista.map(entradaLuau)));
}
const modulosDominio = [...dominios.keys()].sort();
for (const nome of modulosDominio) saidas.set(`Dados/${nome}.luau`, modulo(`Domínio ${nome}.`, dominios.get(nome)!.map(entradaLuau)));
saidas.set("Regras.luau", modulo("Constantes de regra lidas do site (bônus de rank, Ações de magia, Ações por turno, moldes e arquétipos do Apêndice G) e vetores das funções do site para os testes diferenciais.", regras));
saidas.set("Identidade.luau", modulo("Identidade visual das árvores (apresentação, não regra): cor da noite, kanji e selo, como no livro. Chave: id da árvore no catálogo.", identidade));

const manifesto = {
  formato: FORMATO,
  conteudo,
  exporterVersion: EXPORTADOR,
  exporterDigest: "sha256:" + sha(await readFile(fileURLToPath(import.meta.url))),
  ...(sourceRevision ? { sourceRevision } : {}),
  sourceDirty,
  files,
  registros,
  counts: Object.fromEntries(Object.entries(contagens).sort()),
  excluidos,
  adaptacoes,
  camposComIdLocal,
};
validar(manifesto, "manifesto");
saidas.set("Manifesto.luau", modulo("Manifesto do catálogo: versão de formato e de conteúdo, fontes com hash, contagens e exclusões.", manifesto));

saidas.set("Catalogo.luau", `${CABECALHO}-- Índice: POR_ID (todas as entradas), POR_ESPECIE (listas em ordem da fonte), FORMATO e CONTEUDO.
-- Os dados vêm de Dados/; as pastas têm nomes diferentes dos módulos (o Roblox confunde homônimos).
local dados = script.Parent:WaitForChild("Dados")
local arvores = dados:WaitForChild("Arvores")
local Manifesto = require(script.Parent:WaitForChild("Manifesto"))
local POR_ID, POR_ESPECIE = {}, {}
local function incluir(lista)
	for _, entrada in lista do
		assert(POR_ID[entrada.id] == nil, "id repetido no catálogo: " .. entrada.id)
		POR_ID[entrada.id] = entrada
		POR_ESPECIE[entrada.kind] = POR_ESPECIE[entrada.kind] or {}
		table.insert(POR_ESPECIE[entrada.kind], entrada)
	end
end
${modulosArvore.map((n) => `incluir(require(arvores:WaitForChild(${textoLuau(n)})))`).join("\n")}
${modulosDominio.map((n) => `incluir(require(dados:WaitForChild(${textoLuau(n)})))`).join("\n")}
for kind, lista in POR_ESPECIE do
	POR_ESPECIE[kind] = table.freeze(lista)
end
return table.freeze({
	FORMATO = Manifesto.formato,
	CONTEUDO = Manifesto.conteudo,
	POR_ID = table.freeze(POR_ID),
	POR_ESPECIE = table.freeze(POR_ESPECIE),
})
`);

// ---------------------------------------------------------------------------
// Verificar ou gravar (staging + troca; a pasta Livro pertence só ao gerador)

async function listar(pasta: string, base = pasta): Promise<string[]> {
  if (!existsSync(pasta)) return [];
  const out: string[] = [];
  for (const e of await readdir(pasta, { withFileTypes: true })) {
    const p = join(pasta, e.name);
    if (e.isDirectory()) out.push(...(await listar(p, base)));
    else out.push(relative(base, p).replace(/\\/g, "/"));
  }
  return out;
}

if (verificar) {
  const diferencas: string[] = [];
  // A revisão do site muda a cada commit, mesmo sem tocar nas fontes do livro. Os
  // hashes das fontes no manifesto já detectam mudança real; a revisão só informa.
  const semRevisao = (t: string) => t.replace(/^\tsourceRevision = .*\n/m, "").replace(/^\tsourceDirty = .*\n/m, "");
  let soRevisao = false;
  for (const [caminho, texto] of saidas) {
    const atual = await readFile(resolve(DESTINO, caminho), "utf8").catch(() => null);
    if (atual === null) diferencas.push(`${caminho} (faltando)`);
    else if (atual !== texto) {
      if (caminho === "Manifesto.luau" && semRevisao(atual) === semRevisao(texto)) soRevisao = true;
      else diferencas.push(`${caminho} (diferente)`);
    }
  }
  if (soRevisao) console.log("Aviso: só a revisão do site mudou desde a geração (fontes do livro iguais).");
  for (const f of await listar(DESTINO)) if (!saidas.has(f)) diferencas.push(`${f} (sobrando)`);
  if (diferencas.length) {
    console.error(`Catálogo desatualizado ou editado à mão:\n  ${diferencas.join("\n  ")}\nRode tools/gerar-catalogo.ps1.`);
    process.exit(1);
  }
  console.log(`Catálogo confere com o site: ${JSON.stringify(manifesto.counts)}; conteúdo ${conteudo.slice(7, 23)}.`);
} else {
  // A trava foi adquirida no início; staging e backup são exclusivos deste processo.
  // Registros com ids novos (--registrar): gravados só agora, sob a trava e já validados.
  for (const [rel, r] of registrosUsados) {
    if (!r.gravar) continue;
    await mkdir(REGISTROS, { recursive: true });
    await writeFile(resolve(import.meta.dirname, "..", rel), r.texto, "utf8");
    console.error(`${rel}: ids novos gravados; revise antes de depender deles.`);
  }
  const staging = `${DESTINO}.novo-${process.pid}`;
  const antigo = `${DESTINO}.antigo-${process.pid}`;
  await rm(staging, { recursive: true, force: true });
  for (const [caminho, texto] of saidas) {
    await mkdir(dirname(resolve(staging, caminho)), { recursive: true });
    await writeFile(resolve(staging, caminho), texto, "utf8");
  }
  await rm(antigo, { recursive: true, force: true });
  if (existsSync(DESTINO)) await rename(DESTINO, antigo);
  try {
    await rename(staging, DESTINO);
  } catch (erro) {
    if (existsSync(antigo)) await rename(antigo, DESTINO); // volta ao anterior
    throw erro;
  }
  await rm(antigo, { recursive: true, force: true });
  console.log(`Gerado: ${JSON.stringify(manifesto.counts)}; conteúdo ${conteudo.slice(7, 23)}; excluídos: ${excluidos.length}.`);
}
