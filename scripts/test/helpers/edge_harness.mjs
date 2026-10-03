// supabase/functions/*/index.ts dosyalarını Deno olmadan, Node'un tip
// ayıklamasıyla (Node 22.18+ ya da 23.6+: bayraksız tip ayıklama ve module.registerHooks) yükler.
//  * `npm:@supabase/supabase-js@2` importu helpers/fake_supabase.mjs'e yönlenir,
//  * `Deno.serve` yakalanır, `Deno.env.get` testin verdiği ortamdan okunur.
// Canlıya hiçbir istek gitmez; fetch'i test kendisi sahteler.
// Not: Deno global'i süreç başına tektir; her test dosyası tek fonksiyon yükler
// (node --test her dosyayı ayrı süreçte çalıştırır).
import { registerHooks } from "node:module";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(here, "../../..");
const FAKE_SUPABASE = pathToFileURL(path.join(here, "fake_supabase.mjs")).href;

let hooksRegistered = false;

function ensureHooks() {
  if (hooksRegistered) return;
  hooksRegistered = true;
  registerHooks({
    resolve(specifier, context, nextResolve) {
      if (specifier === "npm:@supabase/supabase-js@2" || specifier === "@supabase/supabase-js") {
        return { url: FAKE_SUPABASE, shortCircuit: true };
      }
      return nextResolve(specifier, context);
    },
  });
}

/**
 * @param {string} relPath repo köküne göre index.ts yolu
 * @param {Record<string, string>} env Deno.env değerleri (testte değiştirilebilir)
 * @returns {Promise<{ handler: (req: Request) => Promise<Response>, env: Record<string, string> }>}
 */
export async function loadEdgeFunction(relPath, env) {
  ensureHooks();
  const state = { handler: null, env: { ...env } };
  globalThis.Deno = {
    env: { get: (key) => state.env[key] },
    serve: (handler) => {
      state.handler = handler;
    },
  };
  await import(pathToFileURL(path.join(REPO, relPath)).href);
  if (typeof state.handler !== "function") throw new Error(`${relPath}: Deno.serve çağrılmadı`);
  return state;
}
