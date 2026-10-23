/**
 * Ficha do site → código de mesa (docs/MESA.md › "Importar fichas do site").
 *
 * Não reimplementa regra nenhuma: carrega o código do site original (somente
 * leitura) e usa as mesmas funções da ficha — leitura de arquivo/link,
 * normalização de `importCharacter` e os seletores de PV, mana, CA etc.
 * Ficha mudou no site → gere o código de novo.
 *
 * Uso (pelo wrapper): tools/ficha-para-mesa.ps1 <arquivo .mtficha/.json | link>
 * MOSHOKU_SITE aponta para a pasta do site (padrão: pasta irmã "Moshoku tensei rpg").
 */
import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { basename, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const SITE = resolve(process.env.MOSHOKU_SITE ?? resolve(import.meta.dirname, "..", "..", "Moshoku tensei rpg"));
const site = (relative: string) => import(pathToFileURL(resolve(SITE, "src", relative)).href);


// O store do site persiste em window.localStorage, que não existe no Node; a
// ficha só precisa viver na memória. Simular `window` confundiria o resto do
// código do site, então só o aviso dessa persistência é silenciado.
const avisar = console.warn;
console.warn = (...args: unknown[]) => {
  if (typeof args[0] === "string" && args[0].startsWith("[zustand persist middleware]")) return;
  avisar(...args);
};

function falhar(mensagem: string): never {
  console.error(`Erro: ${mensagem}`);
  process.exit(1);
}

async function lerFicha(entrada: string) {
  // Arquivo existente vence: "Ficha #2.mtficha" é arquivo, não link.
  const hash = entrada.indexOf("#");
  if (!existsSync(entrada) && (/^https?:\/\//i.test(entrada) || entrada.startsWith("#"))) {
    const { decodificarFicha } = await site("lib/fichaLink.ts");
    const lido = await decodificarFicha(hash >= 0 ? entrada.slice(hash) : entrada);
    if (!lido.ok) falhar(`link de ficha ilegível (${lido.motivo}).`);
    return lido.conteudo;
  }
  const { lerArquivoDeFicha } = await site("lib/fichaArquivo.ts");
  const bytes = await readFile(entrada).catch(() => falhar(`não abri o arquivo ${entrada}.`));
  try {
    return await lerArquivoDeFicha(new File([bytes], basename(entrada)));
  } catch (erro) {
    falhar(erro instanceof Error ? erro.message : String(erro));
  }
}

const entrada = process.argv[2];
if (!entrada) falhar("informe o arquivo da ficha (.mtficha/.json) ou o link de compartilhar.");

const dados = await lerFicha(entrada);

// Mesma normalização que o site aplica ao importar (migrações e saneamento).
const { useCharacterStore } = await site("store/useCharacterStore.ts");
const id = useCharacterStore.getState().importCharacter(dados);
const ficha = useCharacterStore.getState().characters[id];

// O cálculo é o mesmo do botão "Copiar para a mesa Roblox" do site.
const { codigoDeMesa } = await site("lib/codigoDeMesa.ts");
const { codigo, texto, avisos } = codigoDeMesa(ficha);
const nome = codigo.nome;
const pvMax = codigo.pvMax;
const manaMax = codigo.manaMax;
const deslocamento = codigo.deslocamento;
const atributos = codigo.atributos;
const iniciativa = { bonus: codigo.iniciativa, hasAdvantage: codigo.vantagemIniciativa };

const sinal = (n: number) => (n >= 0 ? `+${n}` : String(n));
console.error(`Ficha: ${nome}`);
console.error(`PV ${codigo.pv}/${pvMax} • Mana ${codigo.mana}/${manaMax} • CA ${codigo.ca} • ${String(deslocamento).replace(".", ",")} m`);
console.error(
  `FOR ${sinal(atributos.forca)} AGI ${sinal(atributos.agilidade)} VIG ${sinal(atributos.vigor)} INT ${sinal(atributos.intelecto)} ESP ${sinal(atributos.espirito)}` +
    ` • Iniciativa ${sinal(iniciativa.bonus)}${iniciativa.hasAdvantage ? " com vantagem" : ""}`
);
for (const aviso of avisos) console.error(`Aviso: ${aviso}`);
// Só o código vai para a saída padrão: o wrapper copia essa linha para a área de transferência.
console.log(texto);
