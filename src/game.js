import './game.css';
import { createInviteCode, formatClock, getInteraction, movePlayer, advanceClock } from './game-systems.js';
import { supabase, supabaseConfigured } from './supabase-client.js';

const canvas = document.querySelector('#village-canvas');
const context = canvas.getContext('2d');
const TILE = 48;
const MAP = [
  'ttttttggggggggtttttt',
  'tttggggppppgggggtttt',
  'ttggggppppppgggggtt',
  'tgggggppppppggggggtt',
  'gggggppwwwwppggggggg',
  'gggggppwwwwppggggggg',
  'gggggppwwwwppggggggg',
  'ggggggppwwppgggggggg',
  'ggggggppppppgggggggg',
  'ggggggppppppgggggggg',
  'ttggggggggggggggggtt',
  'ttttggggggggggggtttt'
];
const BLOCKED_TILES = new Set(['t', 'w', 'h', 'f']);
const INTERACTIONS = [
  { x: 7, y: 4, task: 'garden', label: 'garden patch', message: 'The moonberries are coming along. You give them a careful drink.' },
  { x: 9, y: 6, task: 'pond', label: 'moon pond', message: 'A silver fish turns beneath the pond. You make a quiet wish.' },
  { x: 12, y: 8, task: 'gate', label: 'village gate', message: 'You leave the gate unlatched. Someone might come by before supper.' }
];
const STORAGE_KEY = 'hobbit-moon-village-v1';
const DEFAULT_STATE = {
  player: { x: 10, y: 9 },
  clock: 495,
  day: 3,
  tasks: { garden: false, pond: false, gate: false },
  inviteCode: null,
  notes: ['You arrived before the kettle boiled.', 'The hill is quiet. The good kind.']
};
const COLORS = {
  grass: '#6f8b5b',
  grassLight: '#88a265',
  grassDark: '#4f6c4b',
  dirt: '#aa7b58',
  dirtLight: '#c59669',
  path: '#d8b783',
  pathLight: '#edd6a3',
  water: '#527c86',
  waterLight: '#7eabb0',
  tree: '#35543f',
  treeLight: '#54785a',
  trunk: '#805e45',
  roof: '#493b4d',
  wall: '#ecd8ae',
  door: '#6a4a4c',
  ink: '#24362f',
  cream: '#f7e9c8',
  gold: '#e2b96e'
};

let state = loadState();
let toastTimer;
let lastMoveAt = 0;

function loadState() {
  try {
    const saved = JSON.parse(localStorage.getItem(STORAGE_KEY));
    return saved ? { ...DEFAULT_STATE, ...saved, tasks: { ...DEFAULT_STATE.tasks, ...saved.tasks } } : structuredClone(DEFAULT_STATE);
  } catch {
    return structuredClone(DEFAULT_STATE);
  }
}

function saveState() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  document.querySelector('#save-status').textContent = 'Saved just now · local demo';
}

function addNote(message) {
  state.notes = [message, ...state.notes].slice(0, 4);
  const list = document.querySelector('#village-log');
  list.innerHTML = state.notes.map((note) => `<li>${escapeHtml(note)}</li>`).join('');
}

function escapeHtml(value) {
  return value.replace(/[&<>'"]/g, (character) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[character]));
}

function drawTile(x, y, tile) {
  const px = x * TILE;
  const py = y * TILE;
  context.fillStyle = tile === 'w' ? COLORS.water : tile === 'p' ? COLORS.path : COLORS.grass;
  context.fillRect(px, py, TILE, TILE);

  if (tile === 'g') {
    context.fillStyle = (x + y) % 3 === 0 ? COLORS.grassLight : COLORS.grassDark;
    context.fillRect(px + 9 + ((x * 13 + y * 5) % 21), py + 13 + ((x * 7 + y * 11) % 22), 2, 2);
    context.fillRect(px + 29 + ((x * 3 + y * 17) % 11), py + 33 - ((x + y) % 8), 1, 3);
  }
  if (tile === 'p') {
    context.strokeStyle = COLORS.pathLight;
    context.lineWidth = 2;
    context.beginPath();
    context.moveTo(px + 7, py + 14 + (x % 4));
    context.lineTo(px + 18, py + 13 + (x % 4));
    context.moveTo(px + 27, py + 35 - (y % 4));
    context.lineTo(px + 41, py + 34 - (y % 4));
    context.stroke();
  }
  if (tile === 'w') {
    context.strokeStyle = COLORS.waterLight;
    context.lineWidth = 2;
    context.beginPath();
    context.moveTo(px + 8, py + 17 + (y % 4));
    context.quadraticCurveTo(px + 16, py + 11 + (y % 4), px + 25, py + 17 + (y % 4));
    context.moveTo(px + 25, py + 32 - (x % 3));
    context.quadraticCurveTo(px + 34, py + 26 - (x % 3), px + 43, py + 32 - (x % 3));
    context.stroke();
  }
  if (tile === 't') drawTree(px, py);
}

function drawTree(px, py) {
  context.fillStyle = COLORS.trunk;
  context.fillRect(px + 21, py + 27, 8, 17);
  context.fillStyle = COLORS.tree;
  context.beginPath();
  context.arc(px + 24, py + 19, 17, 0, Math.PI * 2);
  context.fill();
  context.fillStyle = COLORS.treeLight;
  context.beginPath();
  context.arc(px + 18, py + 13, 8, 0, Math.PI * 2);
  context.fill();
  context.fillStyle = '#9bb16f';
  context.fillRect(px + 13, py + 8, 3, 3);
}

function drawCottage() {
  const px = 14 * TILE;
  const py = 1 * TILE;
  context.fillStyle = COLORS.wall;
  context.fillRect(px + 7, py + 19, TILE * 2.2, TILE * 1.75);
  context.fillStyle = COLORS.roof;
  context.beginPath();
  context.moveTo(px - 2, py + 23);
  context.lineTo(px + TILE * 1.1, py - 8);
  context.lineTo(px + TILE * 2.35, py + 23);
  context.closePath();
  context.fill();
  context.fillStyle = COLORS.door;
  context.beginPath();
  context.arc(px + TILE * 1.12, py + TILE * 1.72, 13, Math.PI, 0);
  context.lineTo(px + TILE * 1.36, py + TILE * 1.75);
  context.lineTo(px + TILE * 0.88, py + TILE * 1.75);
  context.closePath();
  context.fill();
  context.fillStyle = COLORS.gold;
  context.fillRect(px + 31, py + 51, 3, 3);
  context.fillStyle = '#8bc0a7';
  context.fillRect(px + 22, py + 34, 11, 10);
  context.fillRect(px + 73, py + 34, 11, 10);
  context.fillStyle = COLORS.ink;
  context.fillRect(px + 27, py + 34, 2, 10);
  context.fillRect(px + 77, py + 34, 2, 10);
}

function drawSign(x, y, text) {
  const px = x * TILE + TILE / 2;
  const py = y * TILE + 12;
  context.fillStyle = COLORS.trunk;
  context.fillRect(px - 2, py + 13, 4, 19);
  context.fillStyle = COLORS.wall;
  context.fillRect(px - 24, py, 48, 17);
  context.fillStyle = COLORS.ink;
  context.font = '9px "DM Mono", monospace';
  context.textAlign = 'center';
  context.fillText(text, px, py + 11);
}

function drawPlayer() {
  const px = state.player.x * TILE + TILE / 2;
  const py = state.player.y * TILE + TILE / 2 + 2;
  context.save();
  context.translate(px, py);
  context.fillStyle = 'rgba(36, 54, 47, .25)';
  context.beginPath();
  context.ellipse(0, 15, 14, 5, 0, 0, Math.PI * 2);
  context.fill();
  context.fillStyle = '#71514f';
  context.fillRect(-10, 5, 20, 16);
  context.fillStyle = '#f1c698';
  context.beginPath();
  context.arc(0, -5, 10, 0, Math.PI * 2);
  context.fill();
  context.fillStyle = '#a25e4f';
  context.beginPath();
  context.moveTo(-14, -8);
  context.quadraticCurveTo(0, -25, 14, -8);
  context.lineTo(0, -13);
  context.closePath();
  context.fill();
  context.fillStyle = COLORS.ink;
  context.fillRect(-5, -5, 2, 2);
  context.fillRect(4, -5, 2, 2);
  context.restore();
}

function drawInteractionPrompt(point) {
  if (!point) return;
  const px = state.player.x * TILE + TILE / 2;
  const py = state.player.y * TILE - 8;
  const label = `E · ${point.label}`;
  context.font = '11px "DM Mono", monospace';
  const width = context.measureText(label).width + 18;
  context.fillStyle = 'rgba(36, 54, 47, .9)';
  context.fillRect(px - width / 2, py - 25, width, 20);
  context.fillStyle = COLORS.cream;
  context.textAlign = 'center';
  context.fillText(label, px, py - 11);
}

function drawVillage() {
  context.clearRect(0, 0, canvas.width, canvas.height);
  for (let y = 0; y < MAP.length; y += 1) {
    for (let x = 0; x < MAP[y].length; x += 1) drawTile(x, y, MAP[y][x]);
  }
  drawCottage();
  drawSign(4, 8, 'HILL 3');
  drawSign(16, 8, 'POND');
  INTERACTIONS.forEach((point) => {
    if (point.task === 'garden') {
      context.fillStyle = COLORS.dirt;
      context.fillRect(point.x * TILE + 4, point.y * TILE + 8, 40, 30);
      context.fillStyle = COLORS.gold;
      for (let i = 0; i < 4; i += 1) context.fillRect(point.x * TILE + 10 + i * 8, point.y * TILE + 17 + (i % 2) * 7, 4, 4);
    }
  });
  const nearby = getInteraction(state.player, INTERACTIONS);
  drawInteractionPrompt(nearby);
  drawPlayer();
}

function updateHud() {
  document.querySelector('#clock-label').textContent = formatClock(state.clock);
  document.querySelector('#day-label').textContent = `Day ${state.day} · Late Summer`;
  const tasks = Object.entries(state.tasks);
  const completed = tasks.filter(([, done]) => done).length;
  document.querySelector('#task-count').textContent = `${completed} / ${tasks.length}`;
  tasks.forEach(([task, done]) => {
    const node = document.querySelector(`[data-task="${task}"]`);
    node.classList.toggle('is-complete', done);
    node.querySelector('.task-check').textContent = done ? '✓' : '○';
  });
  document.querySelector('#village-log').innerHTML = state.notes.map((note) => `<li>${escapeHtml(note)}</li>`).join('');
}

function move(delta) {
  const next = movePlayer(state.player, delta, MAP, BLOCKED_TILES);
  if (next.x === state.player.x && next.y === state.player.y) return;
  state.player = next;
  state.clock = advanceClock(state.clock, 10);
  if (Date.now() - lastMoveAt > 2500) addNote('Your footsteps make a soft path through the grass.');
  lastMoveAt = Date.now();
  document.querySelector('#canvas-hint').classList.add('is-hidden');
  updateHud();
  drawVillage();
  saveState();
}

function interact() {
  const point = getInteraction(state.player, INTERACTIONS);
  if (!point) {
    showToast('Nothing here but the evening breeze.');
    return;
  }
  state.tasks[point.task] = true;
  state.clock = advanceClock(state.clock, 15);
  addNote(point.message);
  updateHud();
  drawVillage();
  saveState();
  showToast(point.message);
}

function resetVillage() {
  state = structuredClone(DEFAULT_STATE);
  saveState();
  updateHud();
  drawVillage();
  showToast('The village is ready for a fresh morning.');
}

function showToast(message) {
  const toast = document.querySelector('#toast');
  toast.textContent = message;
  toast.classList.add('is-visible');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove('is-visible'), 3200);
}

function makeInvite() {
  state.inviteCode = createInviteCode();
  saveState();
  document.querySelector('#invite-code').textContent = state.inviteCode;
  document.querySelector('#invite-result').hidden = false;
  showToast('Your local invite card is ready.');
}

async function copyInvite() {
  if (!state.inviteCode) return;
  try {
    await navigator.clipboard.writeText(state.inviteCode);
    showToast('Invite code copied.');
  } catch {
    showToast(`Your invite code is ${state.inviteCode}.`);
  }
}

async function sendMagicLink() {
  const status = document.querySelector('#account-status');
  const email = document.querySelector('#email-input').value.trim();
  if (!supabaseConfigured || !supabase) {
    status.textContent = 'Demo mode is active. The village is working locally; hosted account sign-in will switch on after Supabase is configured.';
    return;
  }
  if (!email) {
    status.textContent = 'Add an email address first, and I’ll send a one-time sign-in link.';
    return;
  }
  status.textContent = 'Sending your sign-in link…';
  const { error } = await supabase.auth.signInWithOtp({ email, options: { emailRedirectTo: window.location.origin } });
  status.textContent = error ? error.message : 'Check your inbox for the sign-in link. It is safe to close this window.';
}

function hydrateInvite() {
  if (!state.inviteCode) return;
  document.querySelector('#invite-code').textContent = state.inviteCode;
  document.querySelector('#invite-result').hidden = false;
}

document.addEventListener('keydown', (event) => {
  if (['INPUT', 'TEXTAREA'].includes(document.activeElement?.tagName)) return;
  const keys = { w: { x: 0, y: -1 }, ArrowUp: { x: 0, y: -1 }, s: { x: 0, y: 1 }, ArrowDown: { x: 0, y: 1 }, a: { x: -1, y: 0 }, ArrowLeft: { x: -1, y: 0 }, d: { x: 1, y: 0 }, ArrowRight: { x: 1, y: 0 } };
  const key = event.key.length === 1 ? event.key.toLowerCase() : event.key;
  if (keys[key]) { event.preventDefault(); move(keys[key]); }
  if (key === 'e' || event.key === ' ') { event.preventDefault(); interact(); }
  if (key === 'r') resetVillage();
});

document.querySelector('#invite-button').addEventListener('click', makeInvite);
document.querySelector('#copy-code').addEventListener('click', copyInvite);
document.querySelector('#sign-in-button').addEventListener('click', sendMagicLink);
document.querySelector('#account-button').addEventListener('click', () => document.querySelector('#account-dialog').showModal());
document.querySelector('#account-dialog').addEventListener('click', (event) => { if (event.target === event.currentTarget) event.currentTarget.close(); });

hydrateInvite();
updateHud();
drawVillage();
