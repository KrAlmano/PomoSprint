import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { test } from "node:test";
import { REPO } from "./helpers/fake_dom.mjs";

const root = path.join(REPO, "landing");
const files = fs.readdirSync(root, { recursive: true })
  .filter(file => file.endsWith(".html") && !file.startsWith("_partials/"));
function tags(html) {
  return [...html.matchAll(/<([a-z][\w-]*)\b([^<>]*)>/gi)].map(match => ({
    name: match[1].toLowerCase(),
    attrs: Object.fromEntries([...match[2].matchAll(/([\w-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/g)]
      .map(attr => [attr[1].toLowerCase(), (attr[2] ?? attr[3]).replaceAll("&amp;", "&")])),
  }));
}
const documents = new Map(files.map(file => {
  const source = fs.readFileSync(path.join(root, file), "utf8");
  const elements = tags(source);
  return [file, { source, elements, ids: elements.map(tag => tag.attrs.id).filter(Boolean) }];
}));
function targetFile(file, link) {
  const url = new URL(link, `https://pomosprint.app/${file}`);
  if (url.origin !== "https://pomosprint.app") return null;
  let target = decodeURIComponent(url.pathname).replace(/^\//, "");
  if (!target || target.endsWith("/")) target += "index.html";
  else if (!path.extname(target)) target += ".html";
  return { file: target, fragment: decodeURIComponent(url.hash.slice(1)) };
}

test("all published HTML has unique IDs, one heading and valid local links/ARIA targets", () => {
  assert.ok(files.length > 0);
  for (const [file, doc] of documents) {
    assert.equal(new Set(doc.ids).size, doc.ids.length, `${file}: duplicate ID`);
    assert.equal(doc.elements.filter(tag => tag.name === "h1").length, 1, `${file}: one h1`);
    for (const { name, attrs } of doc.elements) {
      for (const key of ["href", "src", "poster", "data-src", "action"]) {
        if (!attrs[key]) continue;
        const target = targetFile(file, attrs[key]);
        if (!target) continue;
        assert.equal(fs.existsSync(path.join(root, target.file)), true, `${file}: missing ${key}=${attrs[key]}`);
        // #top is the HTML-defined document-start target and need not be an ID.
        if (target.fragment && target.fragment.toLowerCase() !== "top" && documents.has(target.file)) {
          assert.ok(documents.get(target.file).ids.includes(target.fragment), `${file}: missing fragment ${attrs[key]}`);
        }
      }
      for (const key of ["aria-labelledby", "aria-describedby", "aria-controls", "for"]) {
        if (attrs[key]) for (const id of attrs[key].split(/\s+/)) assert.ok(doc.ids.includes(id), `${file}: missing ${key}=${id}`);
      }
      if (name === "img") assert.ok(Object.hasOwn(attrs, "alt"), `${file}: image without alt`);
    }
  }
});

test("TR/EN marketing pages have reciprocal alternates and a native expandable league summary", () => {
  for (const page of ["index.html", "features.html", "faq.html"]) {
    for (const locale of ["tr", "en"]) {
      const file = locale === "tr" ? page : `en/${page}`;
      const { source, elements } = documents.get(file);
      assert.equal(elements.find(tag => tag.name === "html").attrs.lang, locale);
      const alternates = elements.filter(tag => tag.name === "link" && tag.attrs.rel === "alternate");
      for (const expected of ["tr", "en"]) {
        const alternate = alternates.find(tag => tag.attrs.hreflang === expected);
        assert.ok(alternate, `${file}: missing ${expected} alternate`);
        const target = targetFile(file, alternate.attrs.href);
        assert.equal(target.file, expected === "tr" ? page : `en/${page}`);
      }
      if (page === "features.html") {
        assert.match(source, /<details class="league-details">\s*<summary>[^<]+<\/summary>/);
      }
    }
  }
});
