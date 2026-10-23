// Gera src/server/Premontados.luau: personagens prontos (fictícios), montados com as
// AÇÕES do próprio site (criação, árvore, compras legais pelo orçamento de PA) e
// exportados por src/lib/fichaV2.ts. Os números são os do livro, não escritos à mão.
// Ponte até a criação no jogo (J1): o servidor revalida com FichaV2 ao carregar.
// Uso: powershell -File tools/fixtures/premontados.ps1
import { writeFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";
import { resolve } from "node:path";

const SITE = resolve(process.env.MOSHOKU_SITE ?? resolve(import.meta.dirname, "..", "..", "..", "Moshoku tensei rpg"));
const imp = (r: string) => import(pathToFileURL(resolve(SITE, "src", r)).href);
const memoria = new Map<string, string>();
Object.defineProperty(globalThis, "localStorage", {
  value: {
    getItem: (k: string) => memoria.get(k) ?? null,
    setItem: (k: string, v: string) => void memoria.set(k, v),
    removeItem: (k: string) => void memoria.delete(k),
    clear: () => memoria.clear(),
    key: () => null,
    length: 0,
  },
  configurable: true,
});
const avisoOriginal = console.warn;
console.warn = (...a: unknown[]) => { if (typeof a[0] === "string" && a[0].startsWith("[zustand")) return; avisoOriginal(...a); };

const { useCharacterStore } = await imp("store/useCharacterStore.ts");
const { exportarFichaV2 } = await imp("lib/fichaV2.ts");
const s = () => useCharacterStore.getState();

type Compra = { treeId: string; rank: string; kind: "ability" | "talent"; id: string };
interface Receita {
  id: string;
  nome: string;
  raca: string;
  antecedente: string;
  arvore: string;
  atributos: Record<string, number>;
  compras: Compra[];
  /** Itens extras além do kit da árvore (ex.: saco de temperos). */
  itens?: { name: string; type: "arma" | "armadura" | "geral"; baseDie?: string; acBonus?: number }[];
}

// Uma receita por árvore inicial jogável (decisão do Pedro, 09/10/2026: qualquer
// árvore, menos Vendaval e Punho de Fogo; utilidades fora por ora). Os 2 pontos
// de atributo da criação vão para o atributo-chave da árvore; o kit é o do livro
// (Cap. 1, kit por subgrupo); as compras são as cartas que o jogo já executa, em
// ordem de prioridade, e o próprio site recusa o que passa do orçamento de PA.
const ab = (treeId: string, ...ids: string[]): Compra[] => ids.map((id) => ({ treeId, rank: "Principiante", kind: "ability", id }));
const tal = (treeId: string, ...ids: string[]): Compra[] => ids.map((id) => ({ treeId, rank: "Principiante", kind: "talent", id }));
const base = { raca: "humano", antecedente: "plebeu" };
const RECEITAS: Receita[] = [
  { ...base, id: "mago-de-fogo", nome: "Ignis, Aprendiz de Fogo", arvore: "fogo", atributos: { intelecto: 2 },
    compras: ab("fogo", "bola-de-fogo", "toque-escaldante", "clarao", "muro-de-chamas", "fagulha") },
  { ...base, id: "maga-da-agua", nome: "Nerea, Aprendiz da Água", arvore: "agua", atributos: { intelecto: 2 },
    compras: [...tal("agua", "condutor-de-gelo"), ...ab("agua", "bola-de-agua", "impacto-de-gelo", "flecha-de-agua", "lamina-de-gelo", "escudo-de-agua", "nevoa-densa")] },
  { ...base, id: "mago-do-vento", nome: "Zéfiro, Aprendiz do Vento", arvore: "vento", atributos: { intelecto: 2 },
    compras: [...tal("vento", "pes-leves"), ...ab("vento", "lamina-de-vento", "empurrao", "sopro-de-poeira", "passo-de-vento", "vacuo-localizado")] },
  { ...base, id: "mago-da-terra", nome: "Brutus, Aprendiz da Terra", arvore: "terra", atributos: { intelecto: 2 },
    compras: ab("terra", "couraca-de-barro", "muro-de-terra", "mao-de-terra", "bala-de-pedra", "lanca-de-pedra", "atoleiro") },
  { ...base, id: "curandeira", nome: "Lívia, Curandeira", arvore: "cura", atributos: { espirito: 2 },
    compras: ab("cura", "estancar", "cura", "vigor-emprestado", "selar-a-ferida") },
  { ...base, id: "alquimista", nome: "Vesper, Desintoxicadora", arvore: "desintoxicacao", atributos: { espirito: 2 },
    compras: ab("desintoxicacao", "sangria", "peconha", "rosa-preta", "purgar", "antidoto") },
  { ...base, id: "teorico", nome: "Euclides, Teórico", arvore: "teorica", atributos: { intelecto: 2 },
    compras: ab("teorica", "parede-de-emergencia", "anteparo-teorico", "dardo-arcano") },
  { ...base, id: "invocador", nome: "Ravena, Invocadora", arvore: "invocacao", atributos: { espirito: 2 },
    compras: [...ab("invocacao", "chamado"), ...tal("invocacao", "pacto-cao-de-caca")] },
  { ...base, id: "espadachim", nome: "Kaito, Estilo Deus da Espada", arvore: "deus-da-espada", atributos: { forca: 2 },
    compras: ab("deus-da-espada", "roupa-leve", "sem-recuo", "corte-de-braco", "investida-espada", "golpe-continuo") },
  { ...base, id: "duelista-da-agua", nome: "Isa, Estilo Deus da Água", arvore: "deus-da-agua-corpo", atributos: { agilidade: 2 },
    compras: [...ab("deus-da-agua-corpo", "aparar", "guarda-do-corpo", "base-firme"), ...tal("deus-da-agua-corpo", "paciencia-de-pedra"), ...ab("deus-da-agua-corpo", "provocar")] },
  { ...base, id: "guerreiro-do-norte", nome: "Bjorn, Estilo Deus do Norte", arvore: "deus-do-norte", atributos: { forca: 2 },
    compras: [...ab("deus-do-norte", "arremesso-de-espada", "primeiros-socorros-de-campo"), ...tal("deus-do-norte", "tres-bainhas", "pes-no-chao"), ...ab("deus-do-norte", "forma-quadrupede", "golpe-baixo", "bala-de-lagrimas")],
    itens: [{ name: "Saco de temperos", type: "geral" }] },
  { ...base, id: "brutamontes", nome: "Gorm, Armas Pesadas", arvore: "armas-pesadas", atributos: { forca: 2 },
    compras: ab("armas-pesadas", "agarrao", "quebrar-equipamento", "investida-devastadora", "golpe-circular", "cabecada") },
  { ...base, id: "escudeiro", nome: "Tessa, Cavalaria e Escudos", arvore: "cavalaria-e-escudos", atributos: { vigor: 2 },
    compras: [...ab("cavalaria-e-escudos", "golpe-de-escudo"), ...tal("cavalaria-e-escudos", "puro-escudo"), ...ab("cavalaria-e-escudos", "provocar-odio", "muralha-de-um", "puxar")] },
  { ...base, id: "arqueira", nome: "Sylva, Arqueira", arvore: "arquearia", atributos: { agilidade: 2 },
    compras: ab("arquearia", "disparo-duplo", "tiro-de-contencao") },
  // Árvores de utilidade (pedido do Pedro, 09/10/2026: fazer as três depois da Teórica).
  { ...base, id: "ladina", nome: "Nyx, Furtividade e Armadilhas", arvore: "furtividade-e-armadilhas", atributos: { agilidade: 2 },
    compras: [...ab("furtividade-e-armadilhas", "primeiro-golpe"), ...tal("furtividade-e-armadilhas", "duelista-de-rua", "nunca-preso", "boticario")] },
  { ...base, id: "bardo", nome: "Lírio, Bardo", arvore: "bardo-e-interacao", atributos: { espirito: 2 },
    compras: [...ab("bardo-e-interacao", "inspiracao", "refrao-da-retomada"), ...tal("bardo-e-interacao", "insulto-afiado", "cantiga-de-marcha")] },
  { ...base, id: "tatico", nome: "Orion, Navegação e Liderança", arvore: "navegacao-e-lideranca", atributos: { intelecto: 2 },
    compras: [...ab("navegacao-e-lideranca", "primeiro-a-ver"), ...tal("navegacao-e-lideranca", "voz-que-corrige")] },
];

const { getStartingKit } = await imp("data/startingKits.ts");
const { TREES } = await imp("data/trees/index.ts");
const { WEAPON_PRESETS } = await imp("lib/weaponDie.ts");
const { grupoDaArma, weaponGroupName } = await imp("data/weaponGroups.ts");
type ArmaEscolhivel = {
  id: string; nome: string; dado: string; grupo: string; grupoNome: string;
  disparo: boolean; desarmado?: boolean; indisponivel?: string;
};

// Só armas mundanas do Cap. 3. Relíquias/encantadas não são equipamento inicial.
function armasDaArvore(arvore: any, kit: any) {
  const padrao = kit.items.find((i: any) => i.type === "arma");
  if (!padrao?.baseDie) throw new Error(`Kit sem arma: ${arvore.id}`);
  const grupos = arvore.proficiencies?.gruposDeArma ?? [];
  const mago = ["Magia Ofensiva", "Cura e Suporte", "Invocação"].includes(arvore.subgroup);
  const opcao = (name: string, baseDie: string, group: string): ArmaEscolhivel => ({
    id: name, nome: name, dado: baseDie, grupo: group, grupoNome: weaponGroupName(group),
    disparo: ["arcos-e-bestas", "arremesso"].includes(group),
  });
  const armas = [opcao(padrao.name, padrao.baseDie, grupoDaArma(padrao.name))];
  if (!mago && grupos.length) {
    for (const p of WEAPON_PRESETS) {
      if (!grupos.includes(p.group) || p.name === padrao.name) continue;
      if (arvore.subgroup === "Arqueiro" && !["arcos-e-bestas", "arremesso"].includes(p.group)) continue;
      if (grupoDaArma(p.name) !== p.group) throw new Error(`Grupo divergente: ${p.name}`);
      armas.push(opcao(p.name, p.die, p.group));
    }
    if (grupos.includes("desarmado-e-improvisado")) {
      const texto = arvore.ranks.find((r: any) => r.rank === "Principiante")?.mastery?.description ?? "";
      const dado = /ataques desarmados usam Dado Base (d\d+)/i.exec(texto)?.[1];
      armas.push({ ...opcao("desarmado", dado ?? "não definido", "desarmado-e-improvisado"),
        nome: "Punhos (desarmado)", desarmado: true,
        ...(dado ? {} : { indisponivel: "O livro não define o dano desarmado sem a maestria do Lutador." }),
      });
    }
  }
  return { padrao: padrao.name, armas };
}

function luau(valor: any): string {
  if (typeof valor === "string") return JSON.stringify(valor);
  if (typeof valor === "number" || typeof valor === "boolean") return String(valor);
  if (Array.isArray(valor)) return `{ ${valor.map(luau).join(", ")} }`;
  return `{ ${Object.entries(valor).map(([k, v]) => `[${JSON.stringify(k)}] = ${luau(v)}`).join(", ")} }`;
}

const saida: string[] = [];
const vitrine: string[] = [];
for (const r of RECEITAS) {
  s().createCharacter(r.nome);
  s().setRace(r.raca, true);
  s().setBackground(r.antecedente, true);
  s().setStartingTree(r.arvore);
  for (const [chave, valor] of Object.entries(r.atributos)) s().setAttribute(chave, valor);
  // Kit do livro para o subgrupo da árvore, mais itens extras; equipa armas e armaduras.
  const arvore = TREES.find((t: { id: string }) => t.id === r.arvore);
  const kit = arvore ? getStartingKit(arvore.subgroup) : undefined;
  const escolhaArmas = armasDaArvore(arvore, kit);
  const itens = [...(kit?.items ?? []), ...(r.itens ?? [])];
  for (const item of itens) s().addItem(item);
  const inventario = s().characters[s().activeId].inventory ?? [];
  // Só uma arma de corpo a corpo equipada (Arma.daFicha exige uma); arco fica no inventário.
  let armaEquipada = false;
  for (const item of inventario) {
    const disparo = /arco|besta|funda|dardo/i.test(item.name);
    if (item.type === "armadura" || (item.type === "arma" && !armaEquipada && !disparo)) {
      if (!item.equipped) s().toggleEquipped(item.id);
      if (item.type === "arma") armaEquipada = true;
    }
  }
  const recusadas = r.compras.filter((c) => !s().purchaseAbility(c)).map((c) => c.id);
  const ficha = s().characters[s().activeId];
  const { envelope, avisos } = exportarFichaV2(ficha);
  // Identidade estável: o pré-montado não depende do id aleatório do site.
  envelope.sourceCharacterId = `premontado:${r.id}`;
  const texto = JSON.stringify(envelope);
  if (texto.includes("]==]")) throw new Error("JSON não cabe em colchete longo");
  console.log(`${r.id}: ${Buffer.byteLength(texto)} bytes; compras aceitas ${r.compras.length - recusadas.length}/${r.compras.length}` +
    (recusadas.length ? ` (recusadas pelo site: ${recusadas.join(", ")})` : "") + `; avisos ${avisos.length}`);
  saida.push(`\t[${JSON.stringify(r.id)}] = [==[${texto}]==],`);
  const calc = envelope.calculated;
  const cartas = (envelope.construction.purchasedIds as string[]).filter((i) => i.startsWith("ability/"));
  vitrine.push(`\t{ id = ${JSON.stringify(r.id)}, nome = ${JSON.stringify(r.nome)}, arvore = ${JSON.stringify(r.arvore)}, ` +
    `pv = ${calc.maxima.pv}, pm = ${calc.maxima.pm}, pt = ${calc.maxima.pt}, ca = ${calc.armorClass}, ` +
    `paGasto = ${calc.paSpent}, atributos = { ${Object.entries(calc.attributes).map(([k,v]) => `${k} = ${v}`).join(", ")} }, ` +
    `ranks = { ${(envelope.construction.unlockedRankIds as string[]).map((id) => JSON.stringify(id)).join(", ")} }, ` +
    `cartas = { ${cartas.map((c) => JSON.stringify(c)).join(", ")} }, ` +
    `armaPadrao = ${luau(escolhaArmas.padrao)}, armas = ${luau(escolhaArmas.armas)} },`);
}

const modulo = `-- GERADO por tools/fixtures/premontados.mts com o exportador do site. Não edite: rode o gerador.
-- Personagens prontos e fictícios (envelope ficha v2, JSON). O servidor valida com FichaV2.
return table.freeze({
${saida.join("\n")}
})
`;
if (!process.argv.includes("--vitrine")) {
  await writeFile(resolve(import.meta.dirname, "..", "..", "src", "server", "Premontados.luau"), modulo, "utf8");
}
// Vitrine pública (cliente): o que a tela de escolha mostra. A ficha completa fica no servidor.
await writeFile(resolve(import.meta.dirname, "..", "..", "src", "shared", "PersonagensProntos.luau"),
  `-- GERADO por tools/fixtures/premontados.mts. Não edite: rode o gerador.
-- Vitrine dos personagens prontos (um por árvore inicial). A ficha completa e a
-- validação ficam no servidor (Premontados + FichaV2).
return table.freeze({
${vitrine.join("\n")}
})
`, "utf8");
