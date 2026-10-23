/**
 * Gera src/shared/Condicoes.luau a partir do glossário de condições do site
 * (CONDICOES + ESTADOS_DE_REGRA, Cap. 4, §2). O site é só lido.
 *
 * Uso: powershell -File tools/gerar-condicoes.ps1
 * Rode de novo sempre que o livro mudar uma condição.
 */
import { writeFile } from "node:fs/promises";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const SITE = resolve(process.env.MOSHOKU_SITE ?? resolve(import.meta.dirname, "..", "..", "Moshoku tensei rpg"));
const site = (relative: string) => import(pathToFileURL(resolve(SITE, "src", relative)).href);
const SAIDA = resolve(import.meta.dirname, "..", "src", "shared", "Condicoes.luau");

const { CONDICOES, ESTADOS_DE_REGRA, TETO_DE_ACUMULOS } = await site("data/condicoes.ts");

type Mecanica = {
  desvantagemEmAtaques?: boolean;
  semAcoes?: boolean;
  deslocamento?: "zero" | "metade";
  danoPorTurno?: string;
  acumulavel?: boolean;
  tetoFixo?: number;
  noTetoVira?: string;
};

function texto(valor: string): string {
  return JSON.stringify(valor); // literal JSON de string também é string Luau válida
}

/** O que cobrar no início do turno, a partir da mecânica que o site sabe aplicar. */
function lembrete(m?: Mecanica): string | undefined {
  if (!m) return undefined;
  const partes: string[] = [];
  if (m.danoPorTurno) partes.push(`sofre ${m.danoPorTurno} de dano no início do turno`);
  if (m.semAcoes) partes.push("sem Ações e sem Reação");
  if (m.deslocamento === "zero") partes.push("Deslocamento 0");
  if (m.deslocamento === "metade") partes.push("Deslocamento pela metade");
  if (m.desvantagemEmAtaques) partes.push("Desvantagem em ataques");
  return partes.length ? partes.join("; ") : undefined;
}

const entradas: string[] = [];
const ids = new Set<string>();
for (const [lista, regra] of [[CONDICOES, false], [ESTADOS_DE_REGRA, true]] as const) {
  for (const c of lista) {
    if (ids.has(c.id)) throw new Error(`id repetido: ${c.id}`);
    ids.add(c.id);
    const m: Mecanica | undefined = c.mecanica;
    const campos = [
      `id = ${texto(c.id)}`,
      `nome = ${texto(c.nome)}`,
      `efeito = ${texto(c.efeito)}`,
      c.duracaoPadrao ? `duracao = ${texto(c.duracaoPadrao)}` : null,
      `acumulavel = ${m?.acumulavel ? "true" : "false"}`,
      m?.tetoFixo ? `teto = ${m.tetoFixo}` : null,
      m?.noTetoVira ? `vira = ${texto(m.noTetoVira)}` : null,
      `regra = ${regra ? "true" : "false"}`,
      lembrete(m) ? `lembrete = ${texto(lembrete(m)!)}` : null,
    ].filter(Boolean);
    entradas.push(`\t{ ${campos.join(", ")} },`);
  }
}
for (const c of CONDICOES) {
  const vira = c.mecanica?.noTetoVira;
  if (vira && !ids.has(vira)) throw new Error(`${c.id} vira ${vira}, que não existe`);
}

// Constante do próprio site: dobro do Bônus de Imperador (Maestria Nada Segura).
// Não recalcular aqui: o Rank Deus é narrativo e fica de fora (D-17).
const tetoPadrao: number = TETO_DE_ACUMULOS;
const luau = `-- GERADO por tools/gerar-condicoes.mts a partir do glossário de condições do
-- site (Cap. 4, §2). Não edite à mão: rode o gerador de novo.
local LISTA = {
${entradas.join("\n")}
}

local POR_ID = {}
for _, entrada in LISTA do
\tPOR_ID[entrada.id] = table.freeze(entrada)
end

return table.freeze({
\tLISTA = table.freeze(LISTA),
\tPOR_ID = table.freeze(POR_ID),
\t-- Teto de acumuláveis sem teto fixo (Quebrantado): TETO_DE_ACUMULOS do site (Imperador × 2).
\tTETO_PADRAO = ${tetoPadrao},
})
`;
await writeFile(SAIDA, luau, "utf8");
console.log(`Gerado ${SAIDA}: ${ids.size} condições, TETO_PADRAO ${tetoPadrao}.`);
