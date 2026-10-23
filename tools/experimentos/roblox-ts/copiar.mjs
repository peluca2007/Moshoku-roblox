// Copia para src/shared o fecho de imports de um módulo do site, trocando "@/x" por caminhos relativos.
import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, relative, resolve, join } from "node:path";

const SITE = process.argv[2];
const ENTRADA = process.argv[3]; // ex.: store/selectors.ts
const DESTINO = resolve("src/shared");
const visto = new Set();

function resolver(de, alvo) {
  let base;
  if (alvo.startsWith("@/")) base = join(SITE, "src", alvo.slice(2));
  else if (alvo.startsWith(".")) base = resolve(dirname(de), alvo);
  else return null; // pacote externo
  for (const c of [base + ".ts", base + ".tsx", join(base, "index.ts")]) if (existsSync(c)) return c;
  throw new Error(`não achei ${alvo} a partir de ${de}`);
}

function copiar(arquivo) {
  if (visto.has(arquivo)) return;
  visto.add(arquivo);
  let texto = readFileSync(arquivo, "utf8");
  const relSrc = relative(join(SITE, "src"), arquivo);
  const saida = join(DESTINO, relSrc);
  texto = texto.replace(/from\s+["']([^"']+)["']/g, (m, alvo) => {
    const r = resolver(arquivo, alvo);
    if (!r) return m;
    copiar(r);
    let rel = relative(dirname(saida), join(DESTINO, relative(join(SITE, "src"), r))).replace(/\\/g, "/").replace(/\.tsx?$/, "").replace(/\/index$/, "");
    if (!rel.startsWith(".")) rel = "./" + rel;
    return `from "${rel}"`;
  });
  mkdirSync(dirname(saida), { recursive: true });
  writeFileSync(saida, texto);
}

copiar(join(SITE, "src", ENTRADA));
console.log(`${visto.size} arquivos copiados`);
