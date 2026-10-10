(() => {
  const root = document.getElementById('recall-startup');
  const minimumDuration = 700;
  let appReady = false;
  let dismissed = false;
  let startupFailed = false;
  let timer = null;
  let revealedAt = null;
  const logo = root?.querySelector('.startup-logo');
  const image = logo?.querySelector('img');
  let logoSettled = !image;

  const dismissWhenReady = () => {
    if (!appReady || !logoSettled || startupFailed || dismissed || timer !== null) return;
    const remaining = revealedAt === null
      ? 0
      : minimumDuration - (performance.now() - revealedAt);
    if (remaining > 0) {
      timer = window.setTimeout(() => {
        timer = null;
        dismissWhenReady();
      }, remaining);
      return;
    }
    dismissed = true;
    root?.remove();
  };
  const reveal = () => {
    if (logoSettled) return;
    logoSettled = true;
    revealedAt = performance.now();
    logo?.classList.add('is-loaded');
    dismissWhenReady();
  };
  const skipMissingLogo = () => {
    logoSettled = true;
    dismissWhenReady();
  };
  if (image?.complete && image.naturalWidth > 0) reveal();
  else if (image?.complete) skipMissingLogo();
  else {
    image?.addEventListener('load', reveal, { once: true });
    image?.addEventListener('error', skipMissingLogo, { once: true });
  }

  window.recallStartup = {
    ready() {
      appReady = true;
      dismissWhenReady();
    },
    failed(error) {
      if (dismissed || startupFailed) return;
      startupFailed = true;
      window.clearTimeout(timer);
      timer = null;
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
