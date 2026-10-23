// Gera tools/fixtures/ficha-v2-aria.json: envelope v2 de uma ficha FICTÍCIA ("Aria"),
// montada com as ações do próprio site e exportada por src/lib/fichaV2.ts.
// Serve aos testes de importação no Studio sem usar fichas reais do Pedro.
// Uso: powershell -File tools/fixtures/ficha-v2-aria.ps1
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

const { useCharacterStore } = await imp("store/useCharacterStore.ts");
const { exportarFichaV2, codificarPartes } = await imp("lib/fichaV2.ts");

const loja = useCharacterStore.getState();
loja.createCharacter("Aria");
const s = () => useCharacterStore.getState();
s().setRace("humano", true);
s().setBackground("plebeu", true);
s().setStartingTree("agua");
s().purchaseAbility({ treeId: "agua", rank: "Principiante", kind: "ability", id: "bola-de-agua" });
s().purchaseAbility({ treeId: "agua", rank: "Principiante", kind: "talent", id: "condutor-de-gelo" });
s().addProficiency("Cartografia de rios");
s().addItem({ name: "Cajado de salgueiro", type: "geral", description: "Leve, com runas gastas." });
s().aplicarCondicao("apontado");
s().anotarCondicao("apontado", "pelo arqueiro da torre");

const ficha = s().characters[s().activeId];
const { envelope, avisos } = exportarFichaV2(ficha);
const texto = JSON.stringify(envelope);
await writeFile(resolve(import.meta.dirname, "ficha-v2-aria.json"), texto + "\n", "utf8");
console.log(`ficha-v2-aria.json: ${Buffer.byteLength(texto)} bytes, ${codificarPartes(envelope).length} parte(s), ${avisos.length} aviso(s)`);
