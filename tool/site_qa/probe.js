// Read-only early probe injected by the local QA server only.
(function () {
  'use strict';
  var state = { installedAt: performance.now(), firstHeadingFrame: null,
    paintEntries: [], resourceErrors: [], runtimeErrors: [], cspBlocks: [] };
  Object.defineProperty(window, '__POMO_LOCAL_QA_PROBE', { value: state });
  function visibleHeading() {
    var heading = document.querySelector('.hero h1,.page-hero h1,h1');
    if (!heading) return false;
    var rect = heading.getBoundingClientRect(), node = heading, hidden = [];
    while (node && node.nodeType === 1) {
      var style = getComputedStyle(node);
      if (style.display === 'none' || style.visibility === 'hidden' || Number(style.opacity) === 0) hidden.push(node.tagName + (node.id ? '#' + node.id : ''));
      node = node.parentElement;
    }
    state.firstHeadingFrame = { sampledAt: performance.now(),
      sampleKind: 'earliest available heading animation frame; first-paint proxy',
      text: heading.textContent.trim().slice(0, 180), documentLanguage: document.documentElement.lang, visible: hidden.length === 0 && rect.width > 0 && rect.height > 0 && rect.left >= -1 && rect.right <= innerWidth + 1 && rect.top >= -1 && rect.bottom <= innerHeight + 1,
      hiddenAncestors: hidden, rect: { left: rect.left, right: rect.right, top: rect.top, bottom: rect.bottom },
      viewport: { width: innerWidth, height: innerHeight },
      stylesheetsReady: Array.from(document.querySelectorAll('link[rel="stylesheet"]')).every(function (link) { return !!link.sheet; }) };
    return true;
  }
  var queued = false;
  function schedule() {
    if (state.firstHeadingFrame || queued) return;
    queued = true;
    requestAnimationFrame(function () {
      queued = false;
      if (visibleHeading()) observer.disconnect();
    });
  }
  var observer = new MutationObserver(schedule);
  observer.observe(document.documentElement, { childList: true, subtree: true });
  document.addEventListener('DOMContentLoaded', schedule, { once: true });
  schedule();
  window.addEventListener('error', function (event) {
    if (state.resourceErrors.length >= 30 || state.runtimeErrors.length >= 20) return;
    if (event.target && event.target !== window) {
      var element = event.target;
      state.resourceErrors.push({ tag: element.tagName || '', url: element.currentSrc || element.src || element.href || '' });
    } else state.runtimeErrors.push({ message: String(event.message || '').slice(0, 240), source: String(event.filename || '').split('?')[0] });
  }, true);
  window.addEventListener('unhandledrejection', function (event) {
    if (state.runtimeErrors.length < 20) state.runtimeErrors.push({ message: 'Unhandled promise rejection: ' + String(event.reason && event.reason.message || event.reason).slice(0, 200) });
  });
  document.addEventListener('securitypolicyviolation', function (event) {
    if (state.cspBlocks.length < 40) state.cspBlocks.push({ directive: event.effectiveDirective, blocked: String(event.blockedURI || '').slice(0, 180) });
  });
  try {
    new PerformanceObserver(function (list) {
      list.getEntries().forEach(function (entry) {
        if (state.paintEntries.length < 8) state.paintEntries.push({ name: entry.name, at: entry.startTime });
      });
    }).observe({ type: 'paint', buffered: true });
  } catch (_unsupported) { /* Safari may not expose Paint Timing. */ }
})();
