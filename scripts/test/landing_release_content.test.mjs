import assert from "node:assert/strict";
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
  assert.match(html,/LGS.*YKS.*TUS.*DUS.*KPSS/);
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
  assert.match(html,lang==="tr"?/Netlerin ve içgörülerin kişiseldir/:/Net scores and insights (?:are|remain) personal/);assert.doesNotMatch(html,/14 günlük|14-day|14 daily/);
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

test("Güncel native ekranlar her sayfanın kendi diliyle ve ortak telefon oranıyla sunulur", () => {
  for (const lang of ["tr", "en"]) {
    const base = lang === "tr" ? "landing/" : "landing/en/";
    for (const page of ["index.html", "features.html"]) {
      const html = read(base + page);
      const media = [...html.matchAll(/<img\b[^>]*src="(\/screenshots\/[^"]+)"[^>]*>/g)];
      assert.ok(media.length > 0);
      for (const [tag, source] of media) {
        assert.match(source, new RegExp(`^/screenshots/20261028/[a-z-]+-${lang}\\.png$`));
        assert.match(tag, /width="540" height="1170"/);
        assert.match(tag, /alt="[^"]+"/);
      }
      assert.doesNotMatch(html, /captured in Turkish|Türkçe ekran|20261008|604" height="1311/);
    }
  }
});

test("Deneme açıklamaları iki dilde bütün türleri, erken AYT bitişini ve özel sonuçları kapsar", () => {
  for (const [lang, id] of [["tr", "deneme"], ["en", "practice"]]) {
    const base = lang === "tr" ? "landing/" : "landing/en/";
    const html = read(base + "features.html");
    const row = html.match(new RegExp(`<article[^>]+id="${id}"[^>]*>([\\s\\S]*?)</article>`))[1];
    for (const kind of ["TYT", "AYT", "YDT", "LGS", "TUS", "DUS", "KPSS"]) assert.ok(row.includes(kind));
    assert.match(row, /3-2-1/);
    assert.match(row, lang === "tr" ? /Sınavı bitirdim/ : /I’ve finished the exam/);
    assert.match(row, lang === "tr" ? /gerçek süre/ : /actual study time/);
    assert.ok(row.includes(`/screenshots/20261028/exam-catalog-${lang}.png`));
    assert.ok(row.includes(`/screenshots/20261028/exam-running-${lang}.png`));
    assert.match(html, lang === "tr" ? /Her test 40 sorudur/ : /Each test has 40 questions/);
    assert.match(html, lang === "tr" ? /Denemene bir ad ve not ekle/ : /Add a name and note/);
    assert.match(html, lang === "tr" ? /puanı, kumu ve sıralamayı değiştirmez/ : /never changes points, sand or rankings/);
  }
});

test("Kategori, global ve deneme ligi ayrı güncel native karelerle sunulur", () => {
  for (const lang of ["tr", "en"]) {
    const base = lang === "tr" ? "landing/" : "landing/en/";
    const html = read(base + "features.html");
    for (const scene of ["league-category", "league-global", "league-exam"]) {
      assert.equal([...html.matchAll(new RegExp(`src="/screenshots/20261028/${scene}-${lang}\\.png"`, "g"))].length, 1);
    }
    assert.match(html, lang === "tr" ? /sonraki ay geçerli olur/ : /applies to your new group next month/);
    assert.match(html, /00:00/);
    assert.doesNotMatch(html, /league-target-20261028|ranking\.webp/);
  }
});

const examSand = {lgs_verbal:60, lgs_quantitative:70, ydt:95, tus_basic:110, tus_clinical:110, dus:120, tyt:130, ayt:145};
test("TR/EN existing eight-exam sand table stays aligned with the server catalog", () => {
  const catalog = JSON.parse(read("supabase/proposed/exam_catalog_32.json"));
  const server = Object.fromEntries(catalog.exams.filter(exam => exam.group !== "kpss").map(exam => [exam.id, exam.reward_coins]));
  assert.deepEqual(server, examSand);
  for (const locale of ["tr", "en"]) {
    const prefix = locale === "tr" ? "landing/" : "landing/en/";
    const html = read(prefix + "features.html");
    const rows = [...html.matchAll(/<tr data-exam-reward="([a-z_]+)"><th scope="row">[^<]+<\/th><td>(\d+)<\/td><\/tr>/g)];
    assert.equal(rows.length, 8);
    assert.deepEqual(Object.fromEntries(rows.map(row => [row[1], Number(row[2])])), examSand);
    assert.match(html, locale === "tr" ? /90 dakika AYT: 72 kum ve 18 puan/ : /90 minutes of AYT earns 72 sand and 18 points/);
    for (const page of ["index.html", "features.html", "faq.html"]) assert.match(read(prefix + page), /DUS/);
  }
});

test("TR/EN KPSS copy and grouped rewards match all twelve sessions without claiming new media", () => {
  const catalog = JSON.parse(read("supabase/proposed/exam_catalog_32.json"));
  const exams = catalog.exams.filter(exam => exam.group === "kpss");
  assert.equal(exams.length, 12);
  const grouped = {
    gygk: exams.filter(exam => /_gygk$/.test(exam.id)),
    field: exams.filter(exam => exam.id.startsWith("kpss_field_") && exam.id !== "kpss_field_statistics"),
    statistics: exams.filter(exam => exam.id === "kpss_field_statistics"),
  };
  assert.deepEqual(Object.fromEntries(Object.entries(grouped).map(([key, entries]) => [key, entries.length])), {gygk: 3, field: 8, statistics: 1});
  const expected = {gygk: [130, 105, 26], field: [50, 40, 10], statistics: [60, 50, 12]};
  for (const [key, entries] of Object.entries(grouped)) {
    for (const exam of entries) {
      assert.deepEqual([exam.duration_seconds / 60, exam.reward_coins, exam.reward_points], expected[key]);
      assert.equal(exam.total_questions, key === "gygk" ? 120 : 40);
      assert.equal(exam.wrong_answer_divisor, 4);
      if (key === "gygk") assert.deepEqual(exam.subjects.map(subject => subject.question_count), [60, 60]);
    }
  }
  for (const locale of ["tr", "en"]) {
    const prefix = locale === "tr" ? "landing/" : "landing/en/";
    const html = read(prefix + "features.html");
    const details = html.match(/<details class="league-details" data-kpss-catalog>([\s\S]*?)<\/details>/)[1];
    const rows = [...details.matchAll(/<tr data-kpss-group="([a-z]+)"><th scope="row">([^<]+)<\/th><td>([^<]+)<\/td><\/tr>/g)];
    assert.equal(rows.length, 3);
    for (const [, key, label, reward] of rows) {
      assert.deepEqual([...label.matchAll(/\d+/g), ...reward.matchAll(/\d+/g)].map(match => Number(match[0])), expected[key]);
    }
    for (const exam of grouped.gygk) {
      const qualification = locale === "tr" ? exam.name_tr.split(" · ")[0].replace("KPSS ", "") : exam.name_en.split(" · ")[0].replace("KPSS ", "");
      assert.ok(details.includes(qualification), qualification);
    }
    for (const exam of [...grouped.field, ...grouped.statistics]) assert.ok(details.includes(exam.subjects[0][`name_${locale}`]), exam.id);
    assert.match(details, /60 \+ 60/);
    assert.doesNotMatch(details, /ÖABT|\bAGS\b|<img|<video|database|migration|veritabanı/i);
    assert.match(html, locale === "tr" ? /YKS, TUS, DUS ve KPSS: doğru − yanlış\/4/ : /YKS, TUS, DUS and KPSS: correct − wrong\/4/);
    const screenshotTags = html.match(/<img\b[^>]*src="\/screenshots\/[^>]+>/g);
    assert.ok(screenshotTags.length > 0);
    for (const tag of screenshotTags) assert.doesNotMatch(tag, /KPSS|kpss/);
    for (const page of ["index.html", "features.html", "faq.html"]) {
      const source = read(prefix + page);
      assert.match(source.match(/<meta name="description" content="([^"]+)"/)[1], /KPSS/);
      assert.match(source.match(/<meta property="og:description" content="([^"]+)"/)[1], /KPSS/);
    }
    const faq = read(prefix + "faq.html");
    assert.match(faq, locale === "tr" ? /KPSS neti doğru − yanlış\/4/ : /wrong\/4 for YKS, TUS, DUS and KPSS/);
    assert.match(faq, /105/);
    assert.match(faq, /26/);
    assert.doesNotMatch(faq, /ÖABT|\bAGS\b/);
  }
});
