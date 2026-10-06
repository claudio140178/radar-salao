/* Conta cliques no WhatsApp das paginas (sem dados pessoais) e envia ao Supabase do radar */
(function () {
  var API = 'https://bktxduncdwklopfkclxk.supabase.co/rest/v1/whatsapp_cliques';
  var KEY = 'sb_publishable_BruCDrmqZIiS8_3-f_Y2FQ_0CbQ4rnY';
  document.addEventListener('click', function (e) {
    var a = e.target.closest && e.target.closest('a[href*="wa.me/"]');
    if (!a) return;
    var txt = '';
    try { txt = decodeURIComponent(a.href.split('text=')[1] || ''); } catch (_) {}
    var m = txt.match(/\[([A-Z0-9-]{2,40})\]/);
    var pg = (location.pathname.replace(/\.html$/, '') || '/').slice(0, 120);
    var h3 = a.querySelector('h3');
    var origem = 'direto';
    try { if (document.referrer) origem = new URL(document.referrer).hostname; } catch (_) {}
    var body = {
      site: 'morganasilveirastudiodebeleza.online',
      pagina: pg,
      ref: m ? m[1] : (pg === '/' ? 'HOME' : 'SEM-REF'),
      servico: ((h3 ? h3.textContent : a.textContent) || '').trim().slice(0, 80),
      origem: origem.slice(0, 80),
      dispositivo: /Mobi|Android/i.test(navigator.userAgent) ? 'mobile' : 'desktop'
    };
    try {
      fetch(API, { method: 'POST', keepalive: true,
        headers: { apikey: KEY, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
        body: JSON.stringify(body) });
    } catch (_) {}
  }, true);
})();
