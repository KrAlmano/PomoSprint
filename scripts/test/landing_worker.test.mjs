import assert from "node:assert/strict";
import { test } from "node:test";
import worker from "../../landing/worker.js";

test("site Worker: HTTP ve www yönlendirmesi yol/sorguyu korur", async () => {
  for (const source of ["http://pomosprint.app/features?lang=en", "https://www.pomosprint.app/features?lang=en"]) {
    const res = await worker.fetch(new Request(source), { ASSETS: { fetch: () => { throw new Error("unexpected asset lookup"); } } });
    assert.equal(res.status, 301);
    assert.equal(res.headers.get("location"), "https://pomosprint.app/features?lang=en");
  }
});

test("site Worker: HTTPS ana alan ve yerel test istekleri ASSETS'e aynen aktarılır", async () => {
  for (const source of ["https://pomosprint.app/en/privacy", "http://127.0.0.1:8187/reset-password?lang=en"]) {
    const request = new Request(source);
    const response = new Response("asset", { status: 200 });
    const result = await worker.fetch(request, { ASSETS: { fetch: (input) => { assert.equal(input, request); return Promise.resolve(response); } } });
    assert.equal(result, response);
  }
});
