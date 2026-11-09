const steps = ['Conheça o fluxo', 'Resolva uma questão', 'Veja onde melhorar', 'Refaça seus erros'];
let currentStep = 0;
const stepElements = [...document.querySelectorAll('[data-step]')];
const title = document.querySelector('[data-step-title]');
const count = document.querySelector('[data-step-count]');
const progress = document.querySelector('[data-progress]');

function renderStep(index) {
  currentStep = Math.max(0, Math.min(index, steps.length - 1));
  stepElements.forEach((element, position) => element.classList.toggle('active', position === currentStep));
  title.textContent = steps[currentStep];
  count.textContent = `${currentStep + 1} de ${steps.length}`;
  progress.style.width = `${((currentStep + 1) / steps.length) * 100}%`;
}

document.querySelectorAll('[data-next]').forEach(button => button.addEventListener('click', () => renderStep(currentStep + 1)));
document.querySelectorAll('[data-answer]').forEach(button => {
  button.addEventListener('click', () => {
    document.querySelectorAll('[data-answer]').forEach(item => {
      item.classList.toggle('selected', item === button);
      item.setAttribute('aria-pressed', String(item === button));
    });
    const correct = button.dataset.answer === 'C';
    document.querySelector('[data-score]').textContent = correct ? '1/1' : '0/1';
    document.querySelector('.score-ring').style.setProperty('--score', correct ? '100%' : '0%');
    document.querySelector('[data-result]').textContent = correct ? 'Você acertou este exercício.' : 'Este exercício precisa de revisão.';
    document.querySelector('[data-feedback]').textContent = '6 × 4 = 24: seis grupos de quatro unidades.';
    document.querySelector('[data-review]').textContent = correct ? 'Nenhum erro nesta tentativa. Experimente com sua própria prova.' : 'Uma questão errada nesta tentativa. Revise a explicação e tente novamente.';
    document.querySelector('[data-answer-hint]').textContent = `Alternativa ${button.dataset.answer} selecionada.`;
    document.querySelector('[data-step="1"] [data-next]').disabled = false;
  });
});

document.querySelector('[data-restart]').addEventListener('click', () => {
  document.querySelectorAll('[data-answer]').forEach(item => { item.classList.remove('selected'); item.setAttribute('aria-pressed', 'false'); });
  document.querySelector('[data-answer-hint]').textContent = 'Escolha uma alternativa para continuar.';
  document.querySelector('[data-step="1"] [data-next]').disabled = true;
  renderStep(0);
});

const releasePage = 'https://github.com/NAGCODE-Dev/Prova-Social/releases';
const abiAssets = {
  'arm64-v8a': 'app-arm64-v8a-release.apk',
  'armeabi-v7a': 'app-armeabi-v7a-release.apk',
  'x86_64': 'app-x86_64-release.apk',
};

function abiFromUserAgent(userAgent) {
  const value = String(userAgent || '').toLowerCase();
  if (/arm64|aarch64/.test(value)) return 'arm64-v8a';
  if (/x86_64|x64|amd64/.test(value)) return 'x86_64';
  if (/armv7|armeabi/.test(value)) return 'armeabi-v7a';
  return null;
}

function abiFromHighEntropy(architecture, bitness) {
  const arch = String(architecture || '').toLowerCase();
  const bits = String(bitness || '').toLowerCase();
  if (arch === 'arm' || arch === 'arm64' || arch === 'aarch64') {
    return bits === '32' ? 'armeabi-v7a' : 'arm64-v8a';
  }
  if (arch === 'x86_64' || arch === 'x64' || arch === 'amd64' || (arch === 'x86' && bits === '64')) return 'x86_64';
  if (arch === 'armv7' || arch === 'armeabi' || arch === 'armeabi-v7a') return 'armeabi-v7a';
  return null;
}

async function detectAndroidAbi() {
  const nav = typeof navigator === 'undefined' ? undefined : navigator;
  const userAgent = nav?.userAgent || '';
  const platform = nav?.userAgentData?.platform || nav?.platform || '';
  if (!/android/i.test(`${userAgent} ${platform}`)) return null;
  try {
    const values = await nav?.userAgentData?.getHighEntropyValues?.(['architecture', 'bitness']);
    if (values) {
      const abi = abiFromHighEntropy(values.architecture, values.bitness);
      if (abi) return abi;
    }
  } catch (_) {
    // A API de alto nível de entropia pode estar bloqueada; usa o user agent.
  }
  return abiFromUserAgent(userAgent) || abiFromUserAgent(platform);
}

async function loadRelease() {
  const buttons = [...document.querySelectorAll('[data-apk]')];
  const fallback = document.querySelector('[data-apk-fallback]');
  const fallbackLinks = [...document.querySelectorAll('[data-apk-abi]')];
  let release = null;
  try {
    const response = await fetch('https://api.github.com/repos/NAGCODE-Dev/Prova-Social/releases/latest');
    if (!response.ok) throw new Error('Release indisponível');
    release = await response.json();
  } catch (_) {
    // A página de releases continua sendo um destino utilizável.
  }

  const releaseUrl = release?.html_url || releasePage;
  if (release?.tag_name) document.querySelector('[data-version]').textContent = `Versão ${release.tag_name} · Android e Web`;
  const assetFor = abi => (release?.assets || []).find(item => item.name === abiAssets[abi]);
  const abi = await detectAndroidAbi();
  const asset = abi ? assetFor(abi) : null;

  if (asset) {
    buttons.forEach(button => { button.href = asset.browser_download_url; });
    if (fallback) fallback.hidden = true;
    return;
  }

  buttons.forEach(button => { button.href = releaseUrl; });
  if (fallback) fallback.hidden = false;
  fallbackLinks.forEach(link => {
    const named = assetFor(link.dataset.apkAbi);
    link.href = named?.browser_download_url || releaseUrl;
  });
}

renderStep(0);
loadRelease();
