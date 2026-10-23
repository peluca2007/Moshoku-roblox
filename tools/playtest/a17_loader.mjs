// Fallback local para o gerador: TS em processo, sem subprocesso esbuild.
// Lê o site; só premontados.mts escreve os dois gerados do projeto Roblox.
import { registerHooks, createRequire } from "node:module";
import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
const site = resolve(process.env.MOSHOKU_SITE ?? resolve(import.meta.dirname, "..", "..", "..", "Moshoku tensei rpg"));
const require = createRequire(pathToFileURL(resolve(site, "package.json")));
const ts = require("typescript");
registerHooks({
  resolve(specifier, context, nextResolve) {
    if (context.parentURL?.includes("/node_modules/")) return nextResolve(specifier, context);
    let path;
    if (specifier.startsWith("@/")) path = resolve(site, "src", specifier.slice(2));
    else if (specifier.startsWith(".") && context.parentURL?.startsWith("file:")) path = resolve(dirname(fileURLToPath(context.parentURL)), specifier);
    if (path) {
      for (const suffix of ["", ".ts", ".tsx", ".js", "/index.ts", "/index.tsx"]) {
        if (existsSync(path + suffix) && /\.(mts|ts|tsx|js)$/.test(path + suffix)) return nextResolve(pathToFileURL(path + suffix).href, context);
      }
    }
    return nextResolve(specifier, context);
  },
  load(url, context, nextLoad) {
    if (url.startsWith("file:") && /\.(mts|ts|tsx)$/.test(url) && !url.includes("/node_modules/")) {
      const path = fileURLToPath(url);
      return { format: "module", shortCircuit: true, source: ts.transpileModule(readFileSync(path, "utf8"), {
        fileName: path, compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022, jsx: ts.JsxEmit.ReactJSX, esModuleInterop: true }
      }).outputText };
    }
    return nextLoad(url, context);
  }
});
