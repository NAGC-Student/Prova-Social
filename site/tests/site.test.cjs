const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.join(__dirname, '..');
const releaseUrl = 'https://github.com/NAGCODE-Dev/Prova-Social/releases';

function releaseFixture(assets = null) {
  return {
    tag_name: 'v9.9.9',
    html_url: 'https://github.com/NAGCODE-Dev/Prova-Social/releases/tag/v9.9.9',
    assets: assets || [
      {name: 'app-arm64-v8a-release.apk', browser_download_url: 'https://example.test/arm64.apk'},
      {name: 'app-armeabi-v7a-release.apk', browser_download_url: 'https://example.test/armv7.apk'},
      {name: 'app-x86_64-release.apk', browser_download_url: 'https://example.test/x64.apk'},
    ],
  };
}

function setup({release = null, navigator = undefined} = {}) {
  const nodes = new Map();
  function node(id) {
    if (!nodes.has(id)) nodes.set(id, {textContent: '', dataset: {}, disabled: false, hidden: true,
      classList: {toggle() {}, remove() {}}, style: {setProperty(k, v) { this[k] = v; }},
      setAttribute(k, v) {this[k] = v;}, addEventListener(k, fn) {this[k] = fn;}});
    return nodes.get(id);
  }
  const answers = ['A','B','C','D'].map((a) => {const n = node(a); n.dataset.answer = a; return n;});
  const fallback = node('fallback');
  const fallbackLinks = ['arm64-v8a', 'armeabi-v7a', 'x86_64'].map((abi) => {
    const n = node(`abi-${abi}`);
    n.dataset.apkAbi = abi;
    return n;
  });
  const document = {
    querySelector(selector) {
      if (selector === '[data-apk-fallback]') return fallback;
      return node(selector);
    },
    querySelectorAll(selector) {
      if (selector === '[data-answer]') return answers;
      if (selector === '[data-step]') return [0,1,2,3].map(i => node(`step${i}`));
      if (selector === '[data-apk]') return [node('apk')];
      if (selector === '[data-apk-abi]') return fallbackLinks;
      return [];
    },
  };
  const context = {
    document,
    fetch: async () => {
      if (!release) throw new Error('offline');
      return {ok: true, json: async () => release};
    },
  };
  if (navigator !== undefined) context.navigator = navigator;
  vm.runInNewContext(fs.readFileSync(path.join(root, 'app.js'), 'utf8'), context);
  return {node, answers, fallback, fallbackLinks};
}

const waitForRelease = () => new Promise(resolve => setImmediate(resolve));

test('simulator calculates result from the selected answer and can restart', () => {
  const {node, answers} = setup();
  answers[0].click(); assert.equal(node('[data-score]').textContent, '0/1');
  assert.match(node('[data-review]').textContent, /Uma questão errada/);
  answers[2].click(); assert.equal(node('[data-score]').textContent, '1/1');
  assert.match(node('[data-review]').textContent, /Nenhum erro/);
  assert.equal(node('.score-ring').style['--score'], '100%');
  node('[data-restart]').click(); assert.equal(node('[data-step="1"] [data-next]').disabled, true);
});

test('arm64 device receives the arm64 asset', async () => {
  const {node, fallback} = setup({
    release: releaseFixture(),
    navigator: {
      userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
      userAgentData: {platform: 'Android', getHighEntropyValues: async () => ({architecture: 'arm', bitness: '64'})},
    },
  });
  await waitForRelease();
  assert.equal(node('apk').href, 'https://example.test/arm64.apk');
  assert.equal(fallback.hidden, true);
});

test('high entropy values take precedence over the user agent', async () => {
  const {node} = setup({
    release: releaseFixture(),
    navigator: {
      userAgent: 'Mozilla/5.0 (Linux; Android 9; armv7) AppleWebKit/537.36 Chrome/90 Mobile Safari/537.36',
      userAgentData: {platform: 'Android', getHighEntropyValues: async () => ({architecture: 'arm', bitness: '64'})},
    },
  });
  await waitForRelease();
  assert.equal(node('apk').href, 'https://example.test/arm64.apk');
});

test('x86_64 device receives the x86_64 asset from the user agent', async () => {
  const {node} = setup({
    release: releaseFixture(),
    navigator: {userAgent: 'Mozilla/5.0 (Linux; Android 11; x86_64) AppleWebKit/537.36 Chrome/100 Mobile Safari/537.36'},
  });
  await waitForRelease();
  assert.equal(node('apk').href, 'https://example.test/x64.apk');
});

test('armv7 device receives the armeabi-v7a asset from the user agent', async () => {
  const {node} = setup({
    release: releaseFixture(),
    navigator: {userAgent: 'Mozilla/5.0 (Linux; Android 9; armv7) AppleWebKit/537.36 Chrome/90 Mobile Safari/537.36'},
  });
  await waitForRelease();
  assert.equal(node('apk').href, 'https://example.test/armv7.apk');
});

test('unknown Android ABI reveals the three named links instead of arm64', async () => {
  const {node, fallback, fallbackLinks} = setup({
    release: releaseFixture(),
    navigator: {userAgent: 'Mozilla/5.0 (Linux; Android 12; SM-A115M) AppleWebKit/537.36 Chrome/110 Mobile Safari/537.36'},
  });
  await waitForRelease();
  assert.equal(node('apk').href, releaseFixture().html_url);
  assert.equal(fallback.hidden, false);
  assert.deepEqual(fallbackLinks.map(link => link.href), [
    'https://example.test/arm64.apk',
    'https://example.test/armv7.apk',
    'https://example.test/x64.apk',
  ]);
});

test('non-Android browsers receive the release page and the named links', async () => {
  const {node, fallback} = setup({
    release: releaseFixture(),
    navigator: {userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Version/17.0 Mobile/15E148 Safari/604.1'},
  });
  await waitForRelease();
  assert.equal(node('apk').href, releaseFixture().html_url);
  assert.equal(fallback.hidden, false);
});

test('a release containing only armv7 is not treated as arm64', async () => {
  const onlyArmv7 = releaseFixture([
    {name: 'app-armeabi-v7a-release.apk', browser_download_url: 'https://example.test/armv7.apk'},
  ]);
  const {node, fallback, fallbackLinks} = setup({
    release: onlyArmv7,
    navigator: {userAgent: 'Mozilla/5.0 (Linux; Android 12; SM-A115M) AppleWebKit/537.36 Chrome/110 Mobile Safari/537.36'},
  });
  await waitForRelease();
  assert.equal(node('apk').href, onlyArmv7.html_url);
  assert.equal(fallback.hidden, false);
  assert.equal(fallbackLinks[1].href, 'https://example.test/armv7.apk');
  assert.equal(fallbackLinks[0].href, onlyArmv7.html_url);
  assert.equal(fallbackLinks[2].href, onlyArmv7.html_url);
});

test('release failure preserves usable downloads link', async () => {
  const {node, fallback, fallbackLinks} = setup();
  await waitForRelease();
  assert.equal(node('apk').href, releaseUrl);
  assert.equal(fallback.hidden, false);
  assert.ok(fallbackLinks.every(link => link.href === releaseUrl));
});

test('public proof URLs are routed to the Flutter web app', () => {
  const redirects = fs.readFileSync(path.join(root, '_redirects'), 'utf8');
  assert.match(redirects, /^\/provas\/\* \/app\/index\.html 200$/m);
});

test('the published page ships the hidden fallback with the three named ABIs', () => {
  const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  assert.match(html, /data-apk-fallback hidden/);
  for (const abi of ['arm64-v8a', 'armeabi-v7a', 'x86_64'])
    assert.match(html, new RegExp(`data-apk-abi="${abi}"`));
});
function luminance(hex) { const rgb = hex.match(/\w\w/g).map(v => parseInt(v,16)/255).map(v => v <= .04045 ? v/12.92 : ((v+.055)/1.055)**2.4); return rgb[0]*.2126+rgb[1]*.7152+rgb[2]*.0722; }
test('dark palette has AA text contrast on all surfaces and keyboard/reduced-motion styles', () => {
  const css = fs.readFileSync(path.join(root, 'styles.css'), 'utf8');
  for (const surface of ['101311','181c19','202521']) for (const text of ['f3f5f3','aab2ac'])
    assert.ok((luminance(text)+.05)/(luminance(surface)+.05) >= 4.5);
  assert.match(css, /focus-visible/); assert.match(css, /prefers-reduced-motion/);
  assert.match(css, /--bg:#101311/);
  const html = fs.readFileSync(path.join(root, 'index.html'), 'utf8');
  assert.doesNotMatch(html, /FUVEST|01:42:18|90%|50%|80 questões/);
});
