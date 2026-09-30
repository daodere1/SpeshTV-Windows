(function () {
  'use strict';
  var firstFrame = false;
  var opened = false;
  var timer;
  var events = [];
  var started = Date.now();
  var ua = navigator.userAgent || '';
  function record(stage, error) {
    var allowed = ['Error', 'TypeError', 'RangeError', 'SyntaxError', 'CompileError', 'LinkError', 'RuntimeError'];
    events.push({ stage: stage, elapsedMs: Date.now() - started,
      errorType: error && allowed.indexOf(error.name) >= 0 ? error.name : error ? 'Error' : null });
    if (events.length > 20) events.shift();
  }
  function report() {
    var chrome = ua.match(/(?:Chrome|Chromium)\/([\d.]+)/);
    var android = ua.match(/Android\s+([\d.]+)/);
    var config = window.speshRendererConfig || {};
    return { schemaVersion: 1, generatedAt: new Date().toISOString(),
      androidVersion: android ? android[1] : null, chromiumVersion: chrome ? chrome[1] : null,
      androidWebView: /Android/i.test(ua) && (/;\s*wv\)/i.test(ua) || /Version\/4\.0/i.test(ua)),
      renderer: config.renderer === 'canvaskit' ? 'canvaskit' : 'automatic',
      softwareRendering: config.canvasKitForceCpuOnly === true,
      firstFrame: firstFrame, events: events.slice() };
  }
  function navigate(software) {
    var url = new URL(location.href);
    url.searchParams.delete('speshRecovery');
    if (software) url.searchParams.set('speshRenderer', 'software');
    location.replace(url.href);
  }
  function open(reason) {
    if (opened) return;
    opened = true;
    clearTimeout(timer);
    record(reason);
    var panel = document.createElement('section');
    panel.id = 'spesh-startup-recovery';
    panel.setAttribute('role', 'alertdialog');
    panel.setAttribute('aria-modal', 'true');
    panel.setAttribute('aria-labelledby', 'spesh-recovery-title');
    panel.innerHTML = '<div class="spesh-recovery-inner"><h1 id="spesh-recovery-title">SpeshTV could not start</h1>' +
      '<p>Retry, or open Compatibility Mode.</p><div class="spesh-recovery-actions">' +
      '<button type="button" data-action="retry">Retry</button>' +
      '<button type="button" data-action="compatibility">Compatibility Mode</button>' +
      '<button type="button" data-action="return">Return to Jellyfin</button>' +
      '<button type="button" data-action="report">Download report</button></div></div>';
    document.body.appendChild(panel);
    panel.querySelector('[data-action="retry"]').onclick = function () { navigate(false); };
    panel.querySelector('[data-action="compatibility"]').onclick = function () { navigate(true); };
    panel.querySelector('[data-action="return"]').onclick = function () {
      var path = location.pathname;
      var index = path.toLowerCase().indexOf('/web/');
      location.replace((index >= 0 ? path.slice(0, index) : '') + '/web/#/home');
    };
    panel.querySelector('[data-action="report"]').onclick = function () {
      var blob = new Blob([JSON.stringify(report(), null, 2)], {type: 'application/json'});
      var href = URL.createObjectURL(blob);
      var link = document.createElement('a');
      link.href = href;
      link.download = 'speshtv-startup-report.json';
      document.body.appendChild(link);
      link.click();
      link.remove();
      setTimeout(function () { URL.revokeObjectURL(href); }, 1000);
    };
    panel.querySelector('button').focus();
  }
  record('loader-ready');
  window.addEventListener('flutter-first-frame', function () {
    firstFrame = true;
    clearTimeout(timer);
    record('first-frame');
    var panel = document.getElementById('spesh-startup-recovery');
    if (panel && !new URLSearchParams(location.search).has('speshRecovery')) panel.remove();
  });
  window.addEventListener('error', function (event) {
    if (firstFrame) return;
    record('startup-error', event.error || new Error());
  });
  window.addEventListener('unhandledrejection', function (event) {
    if (firstFrame) return;
    record('startup-rejection', event.reason || new Error());
  });
  timer = setTimeout(function () { if (!firstFrame) open('startup-timeout'); }, 45000);
  if (new URLSearchParams(location.search).get('speshRecovery') === '1') open('manual-recovery');
})();
