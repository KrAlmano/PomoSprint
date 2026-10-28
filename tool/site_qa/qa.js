(function () {
  'use strict';
  var ORIGIN = location.origin, WIDTHS = [375, 1024, 1440], HEIGHT = 1000;
  var runButton = document.getElementById('qa-run'), stopButton = document.getElementById('qa-stop');
  var downloadButton = document.getElementById('qa-download');
  var status = document.getElementById('qa-status'), summary = document.getElementById('qa-summary');
  var resultsNode = document.getElementById('qa-results'), host = document.getElementById('qa-frame-host');
  var running = false, stopping = false, results = [], frame;
  var currentSummary = null, runStartedAt = null, runCompletedAt = null;
  var heads = new Map(), imageChecks = new Map(), videoChecks = new Map();
  function delay(ms) { return new Promise(function (resolve) { setTimeout(resolve, ms); }); }
  function deadline(promise, ms, label) {
    var timer;
    return Promise.race([promise, new Promise(function (_resolve, reject) { timer = setTimeout(function () { reject(new Error(label + ' timeout')); }, ms); })]).finally(function () { clearTimeout(timer); });
  }
  function local(value, base, canonical) {
    var url;
    try { url = new URL(value, base || ORIGIN); } catch (_bad) { return null; }
    if (canonical && (url.hostname === 'pomosprint.app' || url.hostname === 'www.pomosprint.app')) url = new URL(url.pathname + url.search + url.hash, ORIGIN);
    if (url.origin !== ORIGIN || url.username || url.password || !/^https?:$/.test(url.protocol)) return null;
    if (/^\/(auth|rest|functions|api|storage)(?:\/|$)/.test(url.pathname)) return null;
    url.hash = '';
    return url;
  }
  async function head(url) {
    if (!heads.has(url.href)) heads.set(url.href, (async function () {
      var controller = new AbortController(), timer = setTimeout(function () { controller.abort(); }, 6000);
      try {
        var response = await fetch(url.href, { method: 'HEAD', mode: 'same-origin', credentials: 'omit', redirect: 'error', cache: 'no-store', signal: controller.signal });
        return { url: url.pathname + url.search, status: response.status, ok: response.ok, type: response.headers.get('content-type') || '' };
      } catch (_error) { return { url: url.pathname + url.search, status: 0, ok: false, error: 'same-origin HEAD failed or timed out' }; }
      finally { clearTimeout(timer); }
    })());
    return heads.get(url.href);
  }
  async function image(url) {
    if (!imageChecks.has(url.href)) imageChecks.set(url.href, (async function () {
      var exists = await head(url); if (!exists.ok) return exists;
      return new Promise(function (resolve) {
        var img = new Image(), timer = setTimeout(function () { done(false, 'image decode timeout'); }, 6000);
        function done(ok, error) { clearTimeout(timer); img.onload = img.onerror = null; resolve({ url: url.pathname, ok: ok, status: exists.status, width: img.naturalWidth, height: img.naturalHeight, error: error || null }); }
        img.onload = function () { done(img.naturalWidth > 0 && img.naturalHeight > 0); };
        img.onerror = function () { done(false, 'image decode error'); };
        img.src = url.href;
      });
    })());
    return imageChecks.get(url.href);
  }
  async function video(url) {
    if (!videoChecks.has(url.href)) videoChecks.set(url.href, (async function () {
      var exists = await head(url); if (!exists.ok) return exists;
      return new Promise(function (resolve) {
        var element = document.createElement('video'), timer = setTimeout(function () { done(false, 'metadata timeout; runtime result pending'); }, 7000);
        element.preload = 'metadata'; element.muted = true; element.playsInline = true;
        function done(ok, error) {
          clearTimeout(timer); element.onloadedmetadata = element.onerror = null;
          var value = { url: url.pathname, status: exists.status, ok: ok, width: element.videoWidth, height: element.videoHeight, duration: Number.isFinite(element.duration) ? element.duration : null, error: error || null };
          element.pause(); element.removeAttribute('src'); element.load(); resolve(value);
        }
        element.onloadedmetadata = function () { done(element.videoWidth > 0 && element.videoHeight > 0); };
        element.onerror = function () { done(false, 'video metadata/decode error ' + (element.error ? element.error.code : 'unknown')); };
        element.src = url.href; element.load();
      });
    })());
    return videoChecks.get(url.href);
  }
  async function limited(items, operation) {
    var values = [];
    for (var i = 0; i < items.length; i += 4) values.push.apply(values, await Promise.all(items.slice(i, i + 4).map(operation)));
    return values;
  }
  function show(current) {
    var failed = results.filter(function (item) { return item.result !== 'PASS'; });
    if (current === 'COMPLETE') runCompletedAt = new Date().toISOString();
    currentSummary = { status: current, runtime_executed: results.length > 0, matrix_complete: current === 'COMPLETE', all_readonly_cases_passed: current === 'COMPLETE' && failed.length === 0, interaction_checks: 'PENDING_CUA', exact_first_paint: 'NOT_PROVEN_BY_THIS_PROXY', completed_cases: results.length, failed_cases: failed.length,
      measurements: 'Read-only same-origin iframe layout/resources; no product interactions', first_paint_limit: 'Earliest-heading rAF proxy; exact Paint Timing may be unsupported in Safari',
      started_at: runStartedAt, completed_at: runCompletedAt,
      failures: failed.map(function (item) { return { page: item.page, width: item.width, failures: item.failures }; }) };
    summary.textContent = JSON.stringify(currentSummary, null, 2);
    downloadButton.disabled = current !== 'COMPLETE';
    resultsNode.textContent = JSON.stringify(results, null, 2).slice(0, 900000);
  }
  function navigate(url, width) {
    return new Promise(function (resolve, reject) {
      frame.width = String(width); frame.height = String(HEIGHT);
      var timer = setTimeout(function () { frame.onload = null; reject(new Error('iframe navigation timeout')); }, 15000);
      frame.onload = function () { clearTimeout(timer); frame.onload = null; resolve(); };
      frame.src = url.href;
    });
  }
  async function inspect(page, width) {
    var url = local(page.url, ORIGIN, false);
    if (!url) throw new Error('Invalid fixed page URL');
    var existence = await head(url);
    if (!existence.ok) return { page: page.url, locale: page.locale, width: width, result: 'FAIL', failures: ['page HTTP ' + existence.status] };
    await navigate(url, width);
    var win = frame.contentWindow, doc = frame.contentDocument;
    await deadline(doc.fonts && doc.fonts.ready || Promise.resolve(), 5000, 'fonts');
    await delay(650); // existing <=300ms decorative entrance completes; no scroll/input is synthesized.
    var failures = [], warnings = [], probe = win.__POMO_LOCAL_QA_PROBE;
    var scrollWidth = Math.max(doc.documentElement.scrollWidth, doc.body ? doc.body.scrollWidth : 0);
    var overflow = scrollWidth - win.innerWidth;
    if (overflow > 1) failures.push('horizontal overflow ' + overflow + 'px');
    if (win.innerWidth !== width) failures.push('iframe viewport width mismatch');
    if (doc.documentElement.lang !== page.locale) failures.push('rendered document language differs from expected locale');
    if (!probe) failures.push('early first-frame probe missing');
    var hero = probe && probe.firstHeadingFrame;
    if (!hero || !hero.visible) failures.push('heading hidden or absent at earliest sampled frame');
    if (hero && !hero.stylesheetsReady) warnings.push('first heading sample preceded all stylesheets; exact first-paint visibility needs manual confirmation');
    if (typeof win.PomoSupabase !== 'undefined' && win.PomoSupabase !== null) failures.push('live API config was not disabled');
    if (probe && probe.runtimeErrors.length) failures.push('runtime JavaScript errors');
    if (probe && probe.cspBlocks.some(function (item) { return item.directive === 'connect-src'; })) failures.push('attempted connection blocked by local-only CSP');
    if (probe && probe.resourceErrors.length) failures.push('browser resource load errors');
    var elements = Array.from(doc.querySelectorAll('body *')).slice(0, 5000);
    var offenders = elements.map(function (element) { var rect = element.getBoundingClientRect(); return { tag: element.tagName, id: element.id, className: typeof element.className === 'string' ? element.className.slice(0, 140) : '', left: Math.round(rect.left), right: Math.round(rect.right), width: Math.round(rect.width) }; })
      .filter(function (rect) { return rect.width > 0 && (rect.left < -1 || rect.right > width + 1); }).slice(0, 15);
    var refs = [], skipped = [];
    function add(value, kind) {
      if (!value) return;
      var resolved = local(value, win.location.href, kind === 'link');
      if (resolved) refs.push({ url: resolved, kind: kind });
      else if (!/^(#|mailto:|tel:)/i.test(value)) skipped.push({ kind: kind, url: String(value).split('?')[0].slice(0, 180), reason: 'external/non-static target not followed' });
    }
    Array.from(doc.querySelectorAll('img')).forEach(function (element) { add(element.currentSrc || element.getAttribute('src'), 'image'); });
    Array.from(doc.querySelectorAll('video')).forEach(function (element) { add(element.getAttribute('poster'), 'image'); add(element.getAttribute('data-src') || element.currentSrc || element.getAttribute('src'), 'video'); });
    Array.from(doc.querySelectorAll('a[href]')).forEach(function (element) { add(element.getAttribute('href'), 'link'); });
    var unique = Array.from(new Map(refs.map(function (ref) { return [ref.kind + ref.url.href, ref]; })).values());
    if (unique.length > 500) throw new Error('Page exceeded bounded500resource inspection limit');
    var checked = await limited(unique, function (ref) { return ref.kind === 'image' ? image(ref.url) : ref.kind === 'video' ? video(ref.url) : head(ref.url); });
    var broken = checked.filter(function (item) { return !item.ok; });
    if (broken.length) failures.push('missing/broken local resource or internal link');
    return { page: page.url, file: page.file, expected_locale: page.locale, actual_locale: doc.documentElement.lang, width: width, height: win.innerHeight,
      result: failures.length ? 'FAIL' : 'PASS', failures: failures, warnings: warnings, overflow_px: Math.max(0, overflow), overflow_candidates: offenders,
      first_heading_frame: hero || null, paint_entries: probe ? probe.paintEntries : [],
      checked_resources: checked.length, broken_resources: broken, skipped_external_targets: skipped.slice(0, 15),
      browser_resource_errors: probe ? probe.resourceErrors : [], runtime_errors: probe ? probe.runtimeErrors : [], csp_blocks: probe ? probe.cspBlocks : [] };
  }
  runButton.addEventListener('click', async function () {
    if (running) return; running = true; stopping = false; results = []; runStartedAt = new Date().toISOString(); runCompletedAt = null; downloadButton.disabled = true; heads.clear(); imageChecks.clear(); videoChecks.clear();
    runButton.disabled = true; stopButton.disabled = false; show('RUNNING');
    if (frame) frame.remove();
    frame = document.createElement('iframe'); frame.title = 'Read-only local page under test';
    frame.setAttribute('sandbox', 'allow-scripts allow-same-origin'); // no forms, popups, downloads or top navigation.
    host.appendChild(frame);
    try {
      var response = await fetch('/__qa/pages.json', { method: 'GET', mode: 'same-origin', credentials: 'omit', redirect: 'error', cache: 'no-store' });
      if (!response.ok) throw new Error('Fixed page manifest unavailable');
      var pages = await response.json();
      if (!Array.isArray(pages) || pages.length < 1 || pages.length > 60) throw new Error('Invalid bounded page manifest');
      for (var w = 0; w < WIDTHS.length && !stopping; w++) for (var p = 0; p < pages.length && !stopping; p++) {
        var page = pages[p];
        if (!page || typeof page.url !== 'string' || !local(page.url)) throw new Error('Manifest contains nonlocal page');
        status.textContent = 'Measuring ' + (results.length + 1) + '/' + (WIDTHS.length * pages.length) + ': ' + page.url + ' @ ' + WIDTHS[w] + 'px';
        try { results.push(await inspect(page, WIDTHS[w])); }
        catch (error) { results.push({ page: page.url, width: WIDTHS[w], result: 'FAIL', failures: [String(error.message || error).slice(0, 220)] }); }
        show('RUNNING');
      }
      show(stopping ? 'STOPPED_INCOMPLETE' : 'COMPLETE');
      status.textContent = stopping ? 'Stopped; runtime matrix incomplete.' : 'Complete. Read structured results; CUA interaction checks are still separate.';
    } catch (error) { status.textContent = String(error.message || error); show('ERROR_INCOMPLETE'); }
    finally { running = false; runButton.disabled = false; stopButton.disabled = true; if (frame) frame.src = 'about:blank'; }
  });
  downloadButton.addEventListener('click', function () {
    // User-triggered export of this exact completed in-memory run, including
    // failures if present. Never hard-code a case count or a PASS result.
    if (running || !currentSummary || currentSummary.status !== 'COMPLETE' || !currentSummary.matrix_complete) return;
    var exportedAt = new Date().toISOString();
    var filename = 'pomosprint-browser-qa-20261028-' + exportedAt.replace(/[:.]/g, '-') + '.json';
    var payload = { schema_version: 1, exported_at: exportedAt,
      evidence_scope: 'Actual read-only browser layout/resource measurements; final B acceptance and product interactions are not inferred',
      source: { origin: ORIGIN, path: location.pathname, user_agent: navigator.userAgent,
        outer_viewport: { width: innerWidth, height: innerHeight, device_pixel_ratio: devicePixelRatio } },
      summary: currentSummary, cases: results };
    var objectUrl = null, anchor = document.createElement('a');
    try {
      var blob = new Blob([JSON.stringify(payload, null, 2) + '\n'], { type: 'application/json;charset=utf-8' });
      objectUrl = URL.createObjectURL(blob);
      anchor.href = objectUrl; anchor.download = filename; anchor.hidden = true;
      document.body.appendChild(anchor);
      anchor.click();
      status.textContent = 'Download requested: ' + filename + '. Check Safari Downloads to retain the actual JSON.';
      // Safari can begin the file download asynchronously. This URL is memory
      // only; revoke after that bounded grace period and remove the link now.
      var completedUrl = objectUrl;
      setTimeout(function () { URL.revokeObjectURL(completedUrl); }, 30000);
      objectUrl = null;
    } catch (error) {
      status.textContent = 'Could not start JSON download: ' + String(error.message || error).slice(0, 180);
    } finally {
      anchor.remove();
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    }
  });
  stopButton.addEventListener('click', function () { stopping = true; status.textContent = 'Stopping after this read-only case…'; });
})();


// QA-only manual frame observer. No synthetic product input or media play call.
(function () {
  'use strict';
  var origin = location.origin;
  var allowedPages = ['/', '/en/', '/features', '/en/features', '/faq', '/en/faq'];
  var selectedPage = null, selectedWidth = 375, frame = null;
  var samples = [], loadNumber = 0;
  var host = document.getElementById('manual-frame-host');
  var status = document.getElementById('manual-status');
  var readout = document.getElementById('manual-readout');
  var download = document.getElementById('manual-download');
  function state() {
    if (!frame || !frame.contentDocument) return {status:'NOT_OPENED'};
    var doc, win;
    try {
      win = frame.contentWindow;
      if (win.location.origin !== origin) return {status:'FOREIGN_NAVIGATION_REFUSED'};
      doc = frame.contentDocument;
    } catch (_error) { return {status:'CROSS_ORIGIN_REFUSED'}; }
    return {
      status:'OBSERVED_ONLY', at:new Date().toISOString(), page:win.location.pathname,
      viewport:{width:win.innerWidth,height:win.innerHeight}, language:doc.documentElement.lang,
      videos:Array.from(doc.querySelectorAll('video[data-demo-video]')).slice(0,8).map(function (video) {
        var rect=video.getBoundingClientRect();
        var visible=rect.bottom>0 && rect.top<win.innerHeight && rect.right>0 && rect.left<win.innerWidth;
        return {source:(video.getAttribute('data-src')||video.getAttribute('src')||'').split('?')[0],
          current_time:video.currentTime, duration:Number.isFinite(video.duration)?video.duration:null,
          paused:video.paused, ended:video.ended, muted:video.muted, loop:video.loop,
          autoplay:video.autoplay, plays_inline:video.playsInline, ready_state:video.readyState,
          visible:visible, hidden:video.hidden, label:video.getAttribute('aria-label'),
          bounds:{top:Math.round(rect.top),bottom:Math.round(rect.bottom),width:Math.round(rect.width),height:Math.round(rect.height)}};
      })
    };
  }
  function draw() { var s=state(); readout.textContent=JSON.stringify({at:s.at,page:s.page,width:s.viewport&&s.viewport.width,language:s.language,videos:(s.videos||[]).map(function(v){return {src:v.source.split('/').pop(),time:Number(v.current_time.toFixed(3)),duration:v.duration,paused:v.paused,muted:v.muted,loop:v.loop,visible:v.visible,ready:v.ready_state};})}); }
  function open() {
    if (!selectedPage) return;
    var token=++loadNumber;
    if (frame) frame.remove();
    frame=document.createElement('iframe');
    frame.title='Manual local product page at '+selectedWidth+' pixels';
    frame.width=String(selectedWidth);frame.height='1000';
    frame.setAttribute('sandbox','allow-scripts allow-same-origin');
    frame.addEventListener('load',function () {
      if(token!==loadNumber)return;
      status.textContent='Manual preview: '+selectedPage+' @ '+selectedWidth+' px. Product actions are manual; readout is observation only.';
      draw();
    });
    host.appendChild(frame);frame.src=new URL(selectedPage,origin).href;
  }
  document.getElementById('qa-run').addEventListener('click',function () {
    if(frame){frame.remove();frame=null;}
    status.textContent='Manual preview closed while the read-only matrix runs.';
    draw();
  });
  document.getElementById('manual-pages').addEventListener('click',function (event) {
    var page=event.target && event.target.getAttribute('data-manual-page');
    if(allowedPages.indexOf(page)<0)return;
    selectedPage=page;open();
  });
  document.getElementById('manual-widths').addEventListener('click',function (event) {
    var width=Number(event.target && event.target.getAttribute('data-manual-width'));
    if([375,1024,1440].indexOf(width)<0)return;
    selectedWidth=width;open();
  });
  document.getElementById('manual-sample').addEventListener('click',function () {
    var value=state();if(value.status!=='OBSERVED_ONLY')return;
    if(samples.length>=200){status.textContent='Sample bound reached; export before collecting more.';return;}
    samples.push(value);download.disabled=false;
    status.textContent='Recorded manual observation '+samples.length+'; no product action inferred as PASS.';draw();
  });
  download.addEventListener('click',function () {
    if(!samples.length)return;
    var payload={schema_version:1,scope:'Read-only samples during real manual Safari product interactions; no automatic PASS claim',
      user_agent:navigator.userAgent,samples:samples};
    var url=URL.createObjectURL(new Blob([JSON.stringify(payload,null,2)+'\n'],{type:'application/json;charset=utf-8'}));
    var a=document.createElement('a');a.href=url;
    a.download='pomosprint-manual-safari-'+new Date().toISOString().replace(/[:.]/g,'-')+'.json';
    a.hidden=true;document.body.appendChild(a);a.click();a.remove();
    setTimeout(function(){URL.revokeObjectURL(url);},30000);
  });
  var lastObservedSample=0;
  setInterval(function(){if(frame && !document.hidden){draw();if(Date.now()-lastObservedSample>=5000&&samples.length<200){var observed=state();if(observed.status==='OBSERVED_ONLY'){observed.sample_mode='read_only_interval_during_manual_browsing';samples.push(observed);download.disabled=false;lastObservedSample=Date.now();}}}},500);
})();


// QA-only local PNG download bridge. No network, storage, file write or image synthesis.
(function () {
  'use strict';
  var MAX_BYTES = 10 * 1024 * 1024;
  var MAX_BASE64 = Math.ceil(MAX_BYTES / 3) * 4;
  var filenameField = document.getElementById('local-png-filename');
  var dataField = document.getElementById('local-png-base64');
  var button = document.getElementById('local-png-download');
  var jpegButton = document.getElementById('local-jpeg-download');
  var status = document.getElementById('local-png-status');
  if (!filenameField || !dataField || !button || !jpegButton || !status) return;

  function validateFilename(raw, format) {
    var name = String(raw || '').trim();
    // One extension only, no path separators, dotfiles, traversal or bidi/control characters.
    var extension = format === 'jpeg' ? 'jpg' : 'png';
    var validName = new RegExp('^[A-Za-z0-9][A-Za-z0-9_-]{0,79}\\.'+extension+'$', 'i');
    if (!validName.test(name)) {
      throw new Error('Dosya adı 1–80 harf/rakam/tire/alt çizgi ve .'+extension+' uzantısından oluşmalı.');
    }
    return name.replace(new RegExp('\\.'+extension+'$', 'i'), '.'+extension);
  }
  function decodeImage(raw, format) {
    if (typeof raw !== 'string' || raw.length > MAX_BASE64 + 128) {
      throw new Error('PNG verisi en fazla 10 MiB olabilir.');
    }
    var prefix = format === 'jpeg' ? /^data:image\/jpeg;base64,/i : /^data:image\/png;base64,/i;
    var encoded = raw.trim().replace(prefix, '').replace(/\s/g, '');
    var equalsAt = encoded.indexOf('=');
    var paddingShapeValid = equalsAt === -1 ||
      (equalsAt === encoded.length-1) ||
      (equalsAt === encoded.length-2 && encoded.endsWith('=='));
    if (!encoded || encoded.length > MAX_BASE64 || encoded.length % 4 !== 0 ||
        /[^A-Za-z0-9+/=]/.test(encoded) || !paddingShapeValid) {
      throw new Error('Geçerli PNG base64 verisi gerekli.');
    }
    var padding = encoded.endsWith('==') ? 2 : encoded.endsWith('=') ? 1 : 0;
    var expected = encoded.length / 4 * 3 - padding;
    if (expected < 8 || expected > MAX_BYTES) throw new Error('PNG verisi 8 bayt–10 MiB aralığında olmalı.');
    var decoded;
    try { decoded = atob(encoded); } catch (_error) { throw new Error('Base64 verisi çözülemedi.'); }
    // Reject non-canonical padding rather than silently accepting altered input.
    if (decoded.length !== expected || btoa(decoded) !== encoded) throw new Error('Base64 kodlaması geçersiz.');
    var signature = format === 'jpeg' ? [255,216,255] : [137,80,78,71,13,10,26,10];
    for (var i=0; i<signature.length; i++) if (decoded.charCodeAt(i) !== signature[i]) {
      throw new Error('Seçilen görüntü türünün imzası geçersiz.');
    }
    if (format === 'jpeg' && (decoded.charCodeAt(decoded.length-2) !== 255 || decoded.charCodeAt(decoded.length-1) !== 217)) {
      throw new Error('JPEG bitiş işareti geçersiz.');
    }
    var bytes = new Uint8Array(decoded.length);
    for (var j=0; j<decoded.length; j++) bytes[j]=decoded.charCodeAt(j);
    return bytes;
  }
  function downloadImage(format) {
    var objectUrl = null, anchor = null;
    button.disabled = true; jpegButton.disabled = true;
    try {
      var filename = validateFilename(filenameField.value, format);
      var bytes = decodeImage(dataField.value, format);
      var blob = new Blob([bytes], {type:format === 'jpeg' ? 'image/jpeg' : 'image/png'});
      objectUrl = URL.createObjectURL(blob);
      anchor = document.createElement('a');
      anchor.href = objectUrl; anchor.download = filename; anchor.hidden = true;
      document.body.appendChild(anchor);
      anchor.click();
      dataField.value = '';
      status.textContent = 'İndirme istendi: '+filename+' ('+bytes.length+' bayt). Base64 alanı temizlendi.';
      var completedUrl = objectUrl;
      setTimeout(function () { URL.revokeObjectURL(completedUrl); }, 30000);
      objectUrl = null;
    } catch (error) {
      status.textContent = 'İndirilmedi: '+String(error.message || error).slice(0,220);
    } finally {
      if (anchor) anchor.remove();
      if (objectUrl) URL.revokeObjectURL(objectUrl);
      button.disabled = false; jpegButton.disabled = false;
    }
  }
  button.addEventListener('click', function () { downloadImage('png'); });
  jpegButton.addEventListener('click', function () { downloadImage('jpeg'); });
})();
