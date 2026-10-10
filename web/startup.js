(() => {
  const root = document.getElementById('recall-startup');
  let ready = false;
  const logo = root?.querySelector('.startup-logo');
  const image = logo?.querySelector('img');
  const reveal = () => logo?.classList.add('is-loaded');
  if (image?.complete && image.naturalWidth > 0) reveal();
  else image?.addEventListener('load', reveal, { once: true });

  window.recallStartup = {
    ready() {
      ready = true;
      root?.remove();
    },
    failed(error) {
      if (ready) return;
      console.error('Recall startup failed:', error);
      root?.setAttribute('aria-busy', 'false');
      root?.setAttribute('aria-label', 'Recall 실행 오류');
      const message = document.getElementById('startup-error');
      if (message) message.hidden = false;
    },
  };

  document.getElementById('startup-retry')?.addEventListener('click', () => {
    window.location.reload();
  });

  window.addEventListener('flutter-first-frame', () => {
    window.recallStartup.ready();
  }, { once: true });

  window.addEventListener('error', event => {
    const target = event.target;
    if (target instanceof HTMLScriptElement &&
        /(?:flutter_bootstrap|main\.dart)\.js(?:[?#].*)?$/.test(target.src)) {
      window.recallStartup.failed(new Error('Flutter startup script could not be loaded.'));
    } else if (target === window) {
      window.recallStartup.failed(event.error ?? event.message);
    }
  }, true);
})();
