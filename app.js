// ---- Layout constants (must match the frame SVGs in /frames) ----
const STRIP_W = 600;
const STRIP_H = 1800;
const PAD = 40;
const PHOTO_W = STRIP_W - PAD * 2; // 520
const PHOTO_H = Math.round(PHOTO_W * 3 / 4); // 390, 4:3
const GAP = 30;
const PHOTO_Y = [
  PAD,
  PAD + PHOTO_H + GAP,
  PAD + (PHOTO_H + GAP) * 2,
];

const video = document.getElementById('video');
const cameraSelect = document.getElementById('cameraSelect');
const startBtn = document.getElementById('startBtn');
const captureBtn = document.getElementById('captureBtn');
const retakeBtn = document.getElementById('retakeBtn');
const countdownEl = document.getElementById('countdown');
const flashEl = document.getElementById('flash');
const shotsEls = [...document.querySelectorAll('.shot')];
const frameOptionsEl = document.getElementById('frameOptions');
const frameUploadInput = document.getElementById('frameUpload');
const stripCanvas = document.getElementById('stripCanvas');
const stripCtx = stripCanvas.getContext('2d');
const captureCanvas = document.getElementById('captureCanvas');
const downloadBtn = document.getElementById('downloadBtn');

let stream = null;
let shots = [null, null, null]; // ImageBitmap-ready <img> elements
let frames = []; // [{name, url}]
let selectedFrameUrl = null;
let selectedFrameImg = null;

// ---------- Camera setup ----------
async function listCameras() {
  const devices = await navigator.mediaDevices.enumerateDevices();
  const cams = devices.filter(d => d.kind === 'videoinput');
  cameraSelect.innerHTML = cams
    .map((c, i) => `<option value="${c.deviceId}">${c.label || 'Camera ' + (i + 1)}</option>`)
    .join('');
}

async function startCamera() {
  try {
    if (stream) stream.getTracks().forEach(t => t.stop());
    const deviceId = cameraSelect.value;
    stream = await navigator.mediaDevices.getUserMedia({
      video: deviceId ? { deviceId: { exact: deviceId } } : { facingMode: 'user' },
      audio: false,
    });
    video.srcObject = stream;
    await listCameras(); // labels populate after permission granted
    captureBtn.disabled = false;
    startBtn.textContent = 'Restart Camera';
  } catch (err) {
    alert('Could not access the camera: ' + err.message);
  }
}

startBtn.addEventListener('click', startCamera);
cameraSelect.addEventListener('change', () => { if (stream) startCamera(); });

// ---------- Capture sequence ----------
async function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function runCountdown(seconds) {
  countdownEl.classList.remove('hidden');
  for (let s = seconds; s > 0; s--) {
    countdownEl.textContent = s;
    await sleep(700);
  }
  countdownEl.classList.add('hidden');
}

function grabFrame() {
  // Crop the live video to a 4:3 region matching PHOTO_W/PHOTO_H, mirrored to match preview.
  const vw = video.videoWidth, vh = video.videoHeight;
  const targetRatio = PHOTO_W / PHOTO_H;
  let sx, sy, sw, sh;
  if (vw / vh > targetRatio) {
    sh = vh;
    sw = vh * targetRatio;
    sx = (vw - sw) / 2;
    sy = 0;
  } else {
    sw = vw;
    sh = vw / targetRatio;
    sx = 0;
    sy = (vh - sh) / 2;
  }
  captureCanvas.width = PHOTO_W;
  captureCanvas.height = PHOTO_H;
  const ctx = captureCanvas.getContext('2d');
  ctx.save();
  ctx.translate(PHOTO_W, 0);
  ctx.scale(-1, 1); // mirror to match on-screen preview
  ctx.drawImage(video, sx, sy, sw, sh, 0, 0, PHOTO_W, PHOTO_H);
  ctx.restore();
  return captureCanvas.toDataURL('image/jpeg', 0.92);
}

function flash() {
  flashEl.classList.remove('active');
  void flashEl.offsetWidth; // restart animation
  flashEl.classList.add('active');
}

async function takeThreePhotos() {
  captureBtn.disabled = true;
  retakeBtn.disabled = true;
  shots = [null, null, null];
  shotsEls.forEach(el => { el.innerHTML = `<span>${+el.dataset.index + 1}</span>`; el.classList.remove('filled'); });

  for (let i = 0; i < 3; i++) {
    await runCountdown(3);
    flash();
    const dataUrl = grabFrame();
    shots[i] = dataUrl;
    const el = shotsEls[i];
    el.innerHTML = '';
    const img = document.createElement('img');
    img.src = dataUrl;
    el.appendChild(img);
    el.classList.add('filled');
    await sleep(500);
  }

  captureBtn.disabled = false;
  retakeBtn.disabled = false;
  renderStrip();
}

captureBtn.addEventListener('click', takeThreePhotos);
retakeBtn.addEventListener('click', () => {
  shots = [null, null, null];
  shotsEls.forEach(el => { el.innerHTML = `<span>${+el.dataset.index + 1}</span>`; el.classList.remove('filled'); });
  renderStrip();
});

// ---------- Frame templates ----------
async function loadFrameManifest() {
  try {
    const res = await fetch('frames/frames.json');
    frames = await res.json();
  } catch {
    frames = [];
  }
  renderFrameOptions();
}

function renderFrameOptions() {
  frameOptionsEl.innerHTML = '';

  const noneOpt = document.createElement('div');
  noneOpt.className = 'frame-option none selected';
  noneOpt.textContent = 'No frame';
  noneOpt.addEventListener('click', () => selectFrame(null));
  frameOptionsEl.appendChild(noneOpt);

  frames.forEach(f => {
    const opt = document.createElement('div');
    opt.className = 'frame-option';
    const img = document.createElement('img');
    img.src = f.url;
    img.alt = f.name;
    opt.appendChild(img);
    opt.title = f.name;
    opt.addEventListener('click', () => selectFrame(f.url, opt));
    frameOptionsEl.appendChild(opt);
  });
}

function selectFrame(url, optEl) {
  [...frameOptionsEl.children].forEach(c => c.classList.remove('selected'));
  if (optEl) optEl.classList.add('selected');
  else frameOptionsEl.firstChild.classList.add('selected');

  selectedFrameUrl = url;
  if (!url) {
    selectedFrameImg = null;
    renderStrip();
    return;
  }
  const img = new Image();
  img.crossOrigin = 'anonymous';
  img.onload = () => { selectedFrameImg = img; renderStrip(); };
  img.src = url;
}

frameUploadInput.addEventListener('change', (e) => {
  const file = e.target.files[0];
  if (!file) return;
  const url = URL.createObjectURL(file);
  const opt = document.createElement('div');
  opt.className = 'frame-option';
  const img = document.createElement('img');
  img.src = url;
  opt.appendChild(img);
  opt.title = file.name;
  opt.addEventListener('click', () => selectFrame(url, opt));
  frameOptionsEl.appendChild(opt);
  selectFrame(url, opt);
});

// ---------- Strip rendering ----------
function renderStrip() {
  stripCtx.clearRect(0, 0, STRIP_W, STRIP_H);
  stripCtx.fillStyle = '#ffffff';
  stripCtx.fillRect(0, 0, STRIP_W, STRIP_H);

  shots.forEach((dataUrl, i) => {
    const y = PHOTO_Y[i];
    if (!dataUrl) {
      stripCtx.fillStyle = '#e6e6e6';
      stripCtx.fillRect(PAD, y, PHOTO_W, PHOTO_H);
      return;
    }
    const img = new Image();
    img.onload = () => {
      stripCtx.drawImage(img, PAD, y, PHOTO_W, PHOTO_H);
      if (selectedFrameImg) stripCtx.drawImage(selectedFrameImg, 0, 0, STRIP_W, STRIP_H);
      updateDownloadState();
    };
    img.src = dataUrl;
  });

  if (selectedFrameImg) stripCtx.drawImage(selectedFrameImg, 0, 0, STRIP_W, STRIP_H);
  updateDownloadState();
}

function updateDownloadState() {
  downloadBtn.disabled = !shots.every(Boolean);
}

// ---------- Download ----------
downloadBtn.addEventListener('click', () => {
  stripCanvas.toBlob((blob) => {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    const stamp = new Date().toISOString().replace(/[:.]/g, '-');
    a.href = url;
    a.download = `photobooth-${stamp}.png`;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  }, 'image/png');
});

// ---------- Init ----------
(async function init() {
  renderStrip();
  await loadFrameManifest();
  try {
    await navigator.mediaDevices.enumerateDevices().then(listCameras);
  } catch {}
})();
