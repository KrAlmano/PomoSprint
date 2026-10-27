import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { test } from "node:test";
import { FakeElement, REPO, createPage, settle } from "./helpers/fake_dom.mjs";
const read = (file) => fs.readFileSync(path.join(REPO, file), "utf8");
const unescape = (text) => text.replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&#x27;/g, "'");
for (const lang of ["tr", "en"]) {
 const base = lang === "tr" ? "landing/" : "landing/en/";
 test(`${lang}: marka, hedefler ve yeni ürün mesajı ilk HTML'de bulunur`, () => {
  const html = read(base+"index.html");
  assert.match(html,new RegExp(`<html lang="${lang}">`));
  assert.match(html.match(/<title>([^<]+)<\/title>/)[1],/PomoSprint.*Pomodoro/);
  assert.match(html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/)[1],/PomoSprint/);
  assert.match(html,/LGS.*YKS.*TUS/);
  assert.match(html,lang==="tr"?/Çalıştığın süre netine nasıl yansıyor/:/How does your study time relate/);
  assert.doesNotMatch(html,/hg-backdrop|hg-past-hero/);
  assert.match(html,/hreflang="tr"/); assert.match(html,/hreflang="en"/);
  const graph=JSON.parse(html.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/)[1]);
  assert.ok(JSON.stringify(graph).includes('"Organization"')); assert.equal(JSON.stringify(graph).includes('"sameAs"'),false);
 });
 test(`${lang}: form POST, önceden işaretsiz onay ve yasal bağlantılar`,()=>{
  const html=read(base+"index.html"),form=html.match(/<form\b[^>]*id="notify-form"[\s\S]*?<\/form>/)[0];
  assert.match(form,/method="post"/);assert.doesNotMatch(form.match(/<input\b[^>]*id="notify-consent"[^>]*>/)[0],/\bchecked\b/);
  assert.match(html,new RegExp(`href="/${lang==="en"?"en/":""}privacy#`));assert.match(html,new RegExp(`href="/${lang==="en"?"en/":""}kvkk"`));
 });
 test(`${lang}: aylık lig, kişisel net ve açılır kurallar`,()=>{
  const html=read(base+"features.html");assert.match(html,/00:00/);assert.match(html,/04:00/);assert.match(html,/class="league-ladder"/);assert.match(html,/<details class="league-details">/);
  assert.match(html,lang==="tr"?/Netler kişisel takibindir/:/Net scores are personal records/);assert.doesNotMatch(html,/14 günlük|14-day|14 daily/);
 });
 test(`${lang}: SSS görünür cevapları ve JSON-LD aynı`,()=>{
  const html=read(base+"faq.html"),data=JSON.parse(html.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/)[1]);
  const visible=[...html.matchAll(/<div class="faq-item">\s*<button[\s\S]*?<span>([\s\S]*?)<\/span>[\s\S]*?<div class="faq-a-inner">\s*<p>([\s\S]*?)<\/p>/g)];
  assert.equal(visible.length,14);assert.equal(data.mainEntity.length,visible.length);
  visible.forEach((v,i)=>{assert.equal(unescape(v[1]),data.mainEntity[i].name);assert.equal(unescape(v[2]),data.mainEntity[i].acceptedAnswer.text);});
 });
}
test("42 karakter gerçek kullanılabilir katalogla eşleşir",()=>{
 const source=read("lib/models/avatar_model.dart").split("static const List<AvatarCharacter> fallbackCatalog = [")[1].split("\n  ];")[0];
 const entries=source.split(/AvatarCharacter\(/).slice(1),available=entries.filter(e=>!e.split(/\),/)[0].includes("isPremiumOnly: true"));
 assert.equal(available.length,42);assert.equal(entries.filter(e=>e.includes("isDefault: true")).length,7);assert.equal(JSON.parse(read("assets/avatars/special_catalog.json")).avatars.length,21);
 for(const f of ["landing/index.html","landing/en/index.html","landing/features.html","landing/en/features.html"])assert.match(read(f),/42/);
});
test("Kritik hero ve yasal dokunma alanı ilk boyamada hazır",()=>{
 const root=new FakeElement("html");root.classList.add("js-anim");vm.runInNewContext(read("landing/js/boot.js"),{document:{documentElement:root}});assert.equal(root.classList.contains("js-anim"),false);
 assert.doesNotMatch(read("landing/css/style.css"),/\.js-anim\s+\[data-hero\]\s*\{[^}]*opacity:\s*0/);assert.doesNotMatch(read("landing/js/main.js"),/querySelectorAll\("\[data-hero\]"\)/);assert.match(read("landing/css/style.css"),/\.notify-note a\s*\{[^}]*min-height:\s*44px/);
});
function leaderboard({rows=[],ok=true,code="",lang="tr",reject=false}={}){
 const els=Object.fromEntries(["siralama","lb-list","lb-podium","lb-empty"].map(id=>[id,new FakeElement(id,{hidden:id!=="siralama"})])),names=[];
 for(const rank of [1,2,3]){const parts=Object.fromEntries([".lb-podium-avatar",".lb-podium-name",".lb-podium-points"].map(c=>[c,new FakeElement(c)])),slot=new FakeElement("lb-podium-"+rank);slot.querySelector=c=>parts[c];els[slot.id]=slot;names.push(parts[".lb-podium-name"]);}
 const calls=[],page=createPage(els,{api:{request:(url,options)=>{calls.push({url,options});return reject?Promise.reject(new Error("offline")):Promise.resolve({ok,status:ok?200:404,data:rows});},errorCode:()=>code}});
 page.document.documentElement.setAttribute("lang",lang);page.run("landing/js/main.js");return {els,calls,names};
}
test("Sıralama yeni İstanbul-ay RPC'sini kullanır; eskiye fallback yapmaz",async()=>{
 const c=leaderboard({ok:false,code:"PGRST202"});await settle();assert.equal(c.calls.length,1);assert.equal(c.calls[0].url,"/rest/v1/rpc/get_public_monthly_competition");assert.match(c.els["lb-empty"].textContent,/hazırlanıyor/);assert.equal(c.els["siralama"].hidden,false);assert.equal(c.els["lb-podium"].hidden,true);
});
test("Sıfır/bir/iki kullanıcıda uydurma sıralama gösterilmez",async()=>{
 for(const n of [0,1,2]){const c=leaderboard({rows:Array.from({length:n},(_,i)=>({name:`Example ${i}`,avatar_id:"avatar_16_basic",total_points:i+1}))});await settle();assert.equal(c.els["siralama"].hidden,false);assert.equal(c.els["lb-empty"].hidden,n!==0);if(n===0)assert.match(c.els["lb-empty"].textContent,/henüz/);else for(let r=1;r<=3;r++)assert.equal(c.els["lb-podium-"+r].hidden,r>n);}
});
test("En fazla on kişi; ad HTML olmaz ve güvensiz avatar yolu kullanılmaz",async()=>{
 const rows=Array.from({length:12},(_,i)=>({name:i===0?'<img src=x onerror=alert(1)>':`Example ${i}`,avatar_id:"../../x",total_points:i+1})),c=leaderboard({rows,lang:"en"});await settle();assert.equal(c.names[0].textContent,rows[0].name);assert.equal(c.els["lb-list"].children.length,7);assert.equal(c.els["lb-podium"].hidden,false);assert.equal(c.els["lb-empty"].hidden,true);
});
test("Bozuk ve başarısız sıralama açıklamalı hata verir",async()=>{
 for(const options of [{rows:[{name:"A",total_points:-2}]},{rows:[{name:"A",total_points:"3"}]},{reject:true},{ok:false}]){const c=leaderboard({...options,lang:"en"});await settle();assert.match(c.els["lb-empty"].textContent,/could not load/);assert.equal(c.els["lb-list"].children.length,0);assert.equal(c.els["lb-podium"].hidden,true);}
});


test("Lig merdiveni her iki dilde dengeli beş sütunda kalır", () => {
  const css = read("landing/css/style.css");
  assert.match(css, /\.league-ladder\s*\{[^}]*display:\s*grid;[^}]*grid-template-columns:\s*repeat\(5,\s*minmax\(0,\s*1fr\)\)/);
  assert.match(css, /\.league-ladder li\s*\{[^}]*min-width:\s*0/);
  assert.match(css, /\.league-ladder img\s*\{[^}]*max-width:\s*100%/);
  for (const file of ["landing/features.html", "landing/en/features.html"]) {
    const ladder = read(file).match(/<ol class="league-ladder"[\s\S]*?<\/ol>/)[0];
    assert.equal([...ladder.matchAll(/<li>/g)].length, 5);
    const tiers = [...ladder.matchAll(/league_([a-z]+)_monthly/g)].map(m => m[1]);
    assert.deepEqual(tiers, ["bronze", "silver", "gold", "sapphire", "diamond"]);
  }
});

test("Güncel native görseller tam PNG boyutlarında ve doğru arayüz diliyle kullanılır", () => {
  for (const file of ["timer-20261028-tr.png", "social-20261028-tr.png", "social-20261028-en.png", "exam-catalog-20261028-tr.png", "exam-running-20261028-en.png", "league-target-20261028-tr.png"]) {
    const image = fs.readFileSync(path.join(REPO, "landing/screenshots", file));
    assert.equal(image.subarray(1, 4).toString(), "PNG");
    assert.equal(image.readUInt32BE(16), 604);
    assert.equal(image.readUInt32BE(20), 1311);
  }
  for (const lang of ["tr", "en"]) {
    for (const page of ["index.html", "features.html"]) {
      const html = read(`landing/${lang === "en" ? "en/" : ""}${page}`);
      assert.match(html, new RegExp(`src="/screenshots/social-20261028-${lang}\\.png"[^>]*width="604" height="1311"`));
      assert.match(html, lang === "tr" ? /örnek hesaplarla/ : /local sample accounts/);
      assert.doesNotMatch(html, /src="\/screenshots\/(?:social|timer)\.webp"/);
      assert.match(html, /(?:src|href)="\/screenshots\/timer-20261028-tr\.png"/);
    }
  }
});

test("Deneme feature satırları gerçek TR katalog ve EN çalışan sayaç görüntüsünü açık örnek hesabıyla sunar", () => {
  for (const [lang, id, asset] of [
    ["tr", "deneme", "exam-catalog-20261028-tr.png"],
    ["en", "mock-exams", "exam-running-20261028-en.png"],
  ]) {
    const html = read(`landing/${lang === "en" ? "en/" : ""}features.html`);
    const row = html.match(new RegExp(`<article class="feature-row reverse" id="${id}">([\\s\\S]*?)</article>`))[1];
    assert.match(row, /class="feature-row-text"/);
    assert.match(row, /class="feature-row-media"/);
    assert.ok(row.includes(`/screenshots/${asset}`));
    assert.match(row, lang === "tr" ? /Yerel örnek hesapla/ : /local sample account/);
    if (lang === "en") assert.match(row, /full-duration TYT countdown/);
  }
});

test("Lig satırları kaynakla aynı gerçek kareyi, ekran dilini ve örnek hesabı açıklayarak kullanır", () => {
  const asset = "league-target-20261028-tr.png";
  const bytes = fs.readFileSync(path.join(REPO, "landing/screenshots", asset));
  const sha256 = createHash("sha256").update(bytes).digest("hex");
  assert.equal(sha256, "0d53a21d86e2a3b54c986581f19f2178a12300b907a899978b38bc008906eebd");
  const manifest = read("landing/screenshots/README.md");
  assert.match(manifest, /ios18-league\/e2e-league-target-change\.png/);
  assert.ok(manifest.includes(sha256));
  for (const [lang, id] of [["tr", "lig"], ["en", "leagues"]]) {
    const base = `landing/${lang === "en" ? "en/" : ""}`;
    const html = read(`${base}features.html`);
    const row = html.match(new RegExp(`<article class="feature-row reverse" id="${id}">([\\s\\S]*?)</article>`))[1];
    assert.equal([...row.matchAll(new RegExp(asset.replaceAll(".", "\\."), "g"))].length, 1);
    assert.match(row, /width="604" height="1311"/);
    assert.doesNotMatch(row, /screenshots\/ranking\.webp/);
    assert.match(row, lang === "tr" ? /Yerel örnek hesapla gerçek lig ekranı/ : /captured in Turkish with a local sample account/);
    assert.match(row, lang === "tr" ? /hedef değişikliği sonraki ay uygulanır/ : /goal changes apply next month/);
    assert.ok(!read(`${base}index.html`).includes(asset), "ana sayfaya yeni lig görseli eklenmez");
  }
  assert.equal(fs.existsSync(path.join(REPO, "landing/screenshots/exam-history-20261028-en.png")), false);
});
