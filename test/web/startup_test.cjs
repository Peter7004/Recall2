const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const source = fs.readFileSync(path.join(__dirname, '../../web/startup.js'), 'utf8');

function createStartup({ complete = true, naturalWidth = 1254, missingImage = false } = {}) {
  let now = 0;
  let nextTimer = 1;
  let removals = 0;
  let reloads = 0;
  const timers = new Map();
  const errors = [];
  const attributes = new Map();
  const classes = new Set();
  const windowEvents = new Map();
  const imageEvents = new Map();
  const retryEvents = new Map();
  const message = { hidden: true };
  const image = missingImage ? null : {
    complete,
    naturalWidth,
    addEventListener: (name, callback) => imageEvents.set(name, callback),
  };
  const logo = {
    classList: { add: name => classes.add(name) },
    querySelector: () => image,
  };
  const root = {
    querySelector: () => logo,
    remove: () => removals++,
    setAttribute: (name, value) => attributes.set(name, value),
  };
  const retry = { addEventListener: (name, callback) => retryEvents.set(name, callback) };
  const elements = { 'recall-startup': root, 'startup-error': message, 'startup-retry': retry };
  const window = {
    addEventListener: (name, callback) => windowEvents.set(name, callback),
    location: { reload: () => reloads++ },
    setTimeout(callback, delay) {
      const id = nextTimer++;
      timers.set(id, { callback, at: now + delay });
      return id;
    },
    clearTimeout: id => timers.delete(id),
  };
  class HTMLScriptElement {
    constructor(src) { this.src = src; }
  }
  vm.runInNewContext(source, {
    window,
    document: { getElementById: id => elements[id] },
    performance: { now: () => now },
    console: { error: (...args) => errors.push(args) },
    HTMLScriptElement,
  });

  // Advance a deterministic clock, including callbacks that schedule another timer.
  function advance(milliseconds) {
    const end = now + milliseconds;
    while (true) {
      const next = [...timers].filter(([, timer]) => timer.at <= end)
        .sort((a, b) => a[1].at - b[1].at)[0];
      if (!next) break;
      now = next[1].at;
      timers.delete(next[0]);
      next[1].callback();
    }
    now = end;
  }

  return {
    controller: window.recallStartup,
    advance,
    message,
    attributes,
    classes,
    errors,
    timers,
    loadImage: () => imageEvents.get('load')(),
    failImage: () => imageEvents.get('error')(),
    firstFrame: () => windowEvents.get('flutter-first-frame')(),
    failScript: src => windowEvents.get('error')({ target: new HTMLScriptElement(src) }),
    retry: () => retryEvents.get('click')(),
    get removals() { return removals; },
    get reloads() { return reloads; },
  };
}

test('fast first frame retains the revealed logo until 700 ms', () => {
  const app = createStartup();
  assert.ok(app.classes.has('is-loaded'));
  app.firstFrame();
  app.controller.ready();
  assert.equal(app.timers.size, 1);
  app.advance(699);
  assert.equal(app.removals, 0);
  app.advance(1);
  assert.equal(app.removals, 1);
  app.controller.ready();
  assert.equal(app.removals, 1);
});

test('slow initialization adds no further delay', () => {
  const app = createStartup();
  app.advance(1200);
  assert.equal(app.removals, 0);
  app.firstFrame();
  assert.equal(app.removals, 1);
  assert.equal(app.timers.size, 0);
});

test('the minimum starts when the image loads, not before it becomes visible', () => {
  const app = createStartup({ complete: false, naturalWidth: 0 });
  app.firstFrame();
  app.advance(1000);
  assert.equal(app.removals, 0);
  app.loadImage();
  app.advance(699);
  assert.equal(app.removals, 0);
  app.advance(1);
  assert.equal(app.removals, 1);
});

test('startup failure cancels a pending removal and retains retry', () => {
  const app = createStartup();
  app.firstFrame();
  app.advance(350);
  app.controller.failed(new Error('engine failure'));
  assert.equal(app.timers.size, 0);
  assert.equal(app.message.hidden, false);
  assert.equal(app.attributes.get('aria-busy'), 'false');
  app.controller.ready();
  app.advance(1000);
  assert.equal(app.removals, 0);
  app.retry();
  assert.equal(app.reloads, 1);
});

test('script failure before readiness is not hidden by a later first frame', () => {
  const app = createStartup();
  app.failScript('https://example.test/Recall2/main.dart.js?v=1');
  app.advance(1000);
  app.firstFrame();
  assert.equal(app.message.hidden, false);
  assert.equal(app.removals, 0);
  assert.equal(app.errors.length, 1);
});

test('unavailable logo assets cannot block an otherwise ready app', () => {
  for (const options of [{ missingImage: true }, { naturalWidth: 0 }]) {
    const app = createStartup(options);
    app.firstFrame();
    assert.equal(app.removals, 1);
  }
  const app = createStartup({ complete: false, naturalWidth: 0 });
  app.firstFrame();
  app.failImage();
  assert.equal(app.removals, 1);
});

test('errors after handoff do not resurrect the dismissed loading screen', () => {
  const app = createStartup();
  app.advance(700);
  app.firstFrame();
  app.controller.failed(new Error('later application error'));
  assert.equal(app.message.hidden, true);
  assert.equal(app.errors.length, 0);
});

test('the CSS reveal lasts 700 ms and reduced motion disables animation', () => {
  const css = fs.readFileSync(path.join(__dirname, '../../web/startup.css'), 'utf8');
  assert.match(css, /animation:\s*recall-reveal 700ms/);
  assert.match(css, /@media\s*\(prefers-reduced-motion:\s*reduce\)[\s\S]*animation:\s*none/);
});
