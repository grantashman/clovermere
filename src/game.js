import './game.css';
import {
  advanceClock,
  createInviteCode,
  createDefaultGameState,
  formatClock,
  getInteraction,
  isCreationComplete,
  movePlayer,
  normalizeGameState
} from './game-systems.js';
import { supabase, supabaseConfigured } from './supabase-client.js';

const TILE = 40;
const MAP_WIDTH = 32;
const MAP_HEIGHT = 18;
const BLOCKED_TILES = new Set(['t', 'w', 'f']);
const STORAGE_KEY = 'hobbit-moon-village-v2';
const LEGACY_STORAGE_KEY = 'hobbit-moon-village-v1';
const LANDSCAPE_LABELS = { heath: 'Hedgerow', river: 'Riverbend', woodland: 'Deepwood' };
const HOUSE_LABELS = { rounddoor: 'Round door', stone: 'Stone cottage', gable: 'Gable house' };
const HAIR_LABELS = { waves: 'Waves', curls: 'Curls', bob: 'Short crop' };
const INTERACTIONS = [
  { x: 7, y: 12, task: 'garden', label: 'garden beds', message: 'The moonberries are taking. You pinch back a leaf and give the soil a careful drink.' },
  { x: 24, y: 5, task: 'pond', label: 'moon pond', message: 'A silver fish turns under the water. The whole pond keeps the secret with you.' },
  { x: 28, y: 14, task: 'gate', label: 'village gate', message: 'You leave the gate unlatched. A friend should never have to knock twice.' },
  { x: 15, y: 8, task: 'noticeboard', label: 'noticeboard', message: 'The noticeboard has a new note: “Pie tasting at the long table, sunset.”' }
];
const DEFAULT_NOTES = ['You arrived before the kettle boiled.', 'The hill is quiet. The good kind.'];

const canvas = document.querySelector('#village-canvas');
const context = canvas?.getContext('2d');
const creatorCanvas = document.querySelector('#creator-canvas');
const creatorContext = creatorCanvas?.getContext('2d');
const avatarCanvas = document.querySelector('#avatar-canvas');
const avatarContext = avatarCanvas?.getContext('2d');
const setupScreen = document.querySelector('#setup-screen');
const playScreen = document.querySelector('#play-screen');

let state = loadState();
let setupStep = 1;
let editing = false;
let setupSnapshot = null;
let toastTimer;
let lastMoveAt = 0;

const STATIC_COLORS = {
  ink: '#24362f',
  cream: '#f8e7c4',
  paper: '#f4e6c8',
  shadow: 'rgba(31, 45, 40, .22)',
  trunk: '#76533e',
  roof: '#4a3c4b',
  wall: '#e7c998',
  door: '#68484c',
  window: '#9bc5b1',
  gold: '#e2b96e',
  flower: '#e29178'
};

function loadState() {
  try {
    const saved = localStorage.getItem(STORAGE_KEY) ?? localStorage.getItem(LEGACY_STORAGE_KEY);
    if (!saved) return createDefaultGameState();
    const parsed = JSON.parse(saved);
    return normalizeGameState({ ...parsed, creationComplete: Boolean(parsed.creationComplete) && isCreationComplete(parsed) });
  } catch {
    return createDefaultGameState();
  }
}

function saveState() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  const saveStatus = document.querySelector('#save-status');
  if (saveStatus) saveStatus.textContent = 'Saved just now · local prototype';
}

function escapeHtml(value) {
  return String(value).replace(/[&<>'"]/g, (character) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[character]));
}

function showToast(message) {
  const toast = document.querySelector('#toast');
  toast.textContent = message;
  toast.classList.add('is-visible');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => toast.classList.remove('is-visible'), 3200);
}

function setNestedValue(target, path, value) {
  const parts = path.split('.');
  let cursor = target;
  parts.slice(0, -1).forEach((part) => { cursor = cursor[part]; });
  cursor[parts.at(-1)] = value;
}

function currentValue(group) {
  if (group.startsWith('palette.')) return state.hobbit.palette[group.split('.')[1]];
  if (group in state.hobbit) return state.hobbit[group];
  return state.village[group];
}

function setChoice(group, value) {
  if (group.startsWith('palette.')) setNestedValue(state.hobbit, group, value);
  else if (group in state.hobbit) state.hobbit[group] = value;
  else state.village[group] = value;
  renderSetup();
  renderVillage();
}

function openCreator(step = 1, isEditing = false) {
  setupSnapshot = structuredClone(state);
  setupStep = step;
  editing = isEditing;
  setupScreen.hidden = false;
  playScreen.hidden = true;
  document.querySelector('#cancel-edit').hidden = !isEditing;
  renderSetup();
  setupScreen.querySelector('input')?.focus();
}

function closeCreator() {
  state.creationComplete = true;
  state.player = { x: 15, y: 14 };
  saveState();
  setupSnapshot = null;
  editing = false;
  setupScreen.hidden = true;
  playScreen.hidden = false;
  updateHud();
  renderVillage();
  showToast(`Welcome to ${state.village.name}.`);
}

function cancelCreator() {
  if (setupSnapshot) state = normalizeGameState(setupSnapshot);
  setupSnapshot = null;
  editing = false;
  setupScreen.hidden = true;
  playScreen.hidden = false;
  updateHud();
  renderVillage();
}

function renderSetup() {
  const stepOne = setupStep === 1;
  document.querySelectorAll('[data-pane]').forEach((pane) => { pane.hidden = Number(pane.dataset.pane) !== setupStep; });
  document.querySelectorAll('[data-step-indicator]').forEach((item) => {
    const itemStep = Number(item.dataset.stepIndicator);
    item.classList.toggle('is-active', itemStep === setupStep);
    item.classList.toggle('is-complete', itemStep < setupStep);
  });
  document.querySelector('#step-count').textContent = `0${setupStep} / 02`;
  document.querySelector('#setup-heading').textContent = stepOne ? 'Make your hobbit.' : 'Shape your village.';
  document.querySelector('#setup-intro').textContent = stepOne ? 'Choose the face, clothes, and small details you’ll see every day.' : 'Pick the landscape and home that make this patch of Hobbiton yours.';
  document.querySelector('#preview-kicker').textContent = stepOne ? 'Your first morning' : 'The view from your gate';
  document.querySelector('#preview-location').textContent = state.village.name || 'A village waiting for a name';
  document.querySelector('#preview-caption-title').textContent = stepOne ? 'A door of your own' : state.village.name || 'A place to come back to';
  document.querySelector('#preview-caption-copy').textContent = stepOne ? 'Start with the little details.' : `${LANDSCAPE_LABELS[state.village.landscape]} · ${HOUSE_LABELS[state.village.house]}`;
  document.querySelector('#setup-back').hidden = stepOne;
  document.querySelector('#setup-next').innerHTML = stepOne ? 'Continue to the village <span aria-hidden="true">→</span>' : (editing ? 'Save these changes <span aria-hidden="true">✓</span>' : 'Open the gate <span aria-hidden="true">→</span>');
  document.querySelector('#hobbit-name').value = state.hobbit.name;
  document.querySelector('#village-name').value = state.village.name;
  document.querySelectorAll('[data-group]').forEach((group) => {
    const value = currentValue(group.dataset.group);
    group.querySelectorAll('[data-value]').forEach((choice) => choice.classList.toggle('is-selected', choice.dataset.value === value));
  });
  drawCreatorPreview();
}

function validateSetup() {
  if (setupStep === 1 && state.hobbit.name.trim().length < 2) {
    showToast('Give your hobbit a name before you continue.');
    document.querySelector('#hobbit-name').focus();
    return false;
  }
  if (setupStep === 2 && state.village.name.trim().length < 2) {
    showToast('Every good village needs a name on the gate.');
    document.querySelector('#village-name').focus();
    return false;
  }
  return true;
}

function handleSetupSubmit(event) {
  event.preventDefault();
  if (!validateSetup()) return;
  if (setupStep === 1) {
    setupStep = 2;
    renderSetup();
    document.querySelector('#village-name').focus();
  } else {
    if (!isCreationComplete(state)) return showToast('Add both names before opening the gate.');
    closeCreator();
  }
}

function themeForVillage() {
  const landscape = state.village.landscape;
  const themes = {
    heath: { sky: '#c2d1b5', distant: '#90aa7a', grass: '#76915d', grassLight: '#9bb16e', grassDark: '#4d6a4b', water: '#6d9791', waterLight: '#9ac1a9', dirt: '#a87555', path: '#d8b783', pathLight: '#eed9a7', roof: state.village.roof === 'moss' ? '#4d6347' : '#594753' },
    river: { sky: '#b5ccd0', distant: '#789aa0', grass: '#648b75', grassLight: '#91ae8d', grassDark: '#3f6657', water: '#4f8794', waterLight: '#9cc6c5', dirt: '#a97056', path: '#d3bd91', pathLight: '#eee0bc', roof: state.village.roof === 'moss' ? '#405d58' : '#55495b' },
    woodland: { sky: '#b7c0a5', distant: '#728968', grass: '#5f7d56', grassLight: '#87a068', grassDark: '#385542', water: '#537c7c', waterLight: '#8eb5a5', dirt: '#956d53', path: '#c4ae82', pathLight: '#e4d19c', roof: state.village.roof === 'moss' ? '#3d5544' : '#51424e' }
  };
  return themes[landscape] ?? themes.heath;
}

function tileAt(x, y) {
  if (x < 1 || y < 1 || x >= MAP_WIDTH - 1 || y >= MAP_HEIGHT - 1) return 't';
  if (state.village.landscape === 'river' && x >= 23 && x <= 25 && y >= 2 && y <= 13 && y !== 8) return 'w';
  if (state.village.landscape === 'woodland' && x >= 22 && x <= 26 && y >= 3 && y <= 6) return 'w';
  if ((y === 8 && x >= 2 && x <= 28) || (x === 15 && y >= 8 && y <= 15) || (y === 14 && x >= 24 && x <= 29)) return 'p';
  if (x >= 4 && x <= 10 && y >= 11 && y <= 13) return 'd';
  if (x === 27 && y >= 12 && y <= 15) return 'f';
  const treeSpots = new Set(['3,3', '4,3', '5,2', '28,3', '29,4', '30,5', '2,14', '3,15', '5,16', '25,15', '26,16', '29,16', '18,3', '20,2']);
  return treeSpots.has(`${x},${y}`) ? 't' : 'g';
}

function pixelRect(ctx, x, y, width, height, color) {
  ctx.fillStyle = color;
  ctx.fillRect(Math.round(x), Math.round(y), Math.round(width), Math.round(height));
}

function drawTree(ctx, px, py, theme, scale = 1) {
  pixelRect(ctx, px + 18 * scale, py + 25 * scale, 8 * scale, 18 * scale, STATIC_COLORS.trunk);
  pixelRect(ctx, px + 14 * scale, py + 36 * scale, 16 * scale, 4 * scale, STATIC_COLORS.trunk);
  pixelRect(ctx, px + 8 * scale, py + 14 * scale, 28 * scale, 20 * scale, theme.grassDark);
  pixelRect(ctx, px + 13 * scale, py + 7 * scale, 18 * scale, 23 * scale, theme.grassDark);
  pixelRect(ctx, px + 17 * scale, py + 2 * scale, 10 * scale, 15 * scale, theme.grassDark);
  pixelRect(ctx, px + 10 * scale, py + 13 * scale, 9 * scale, 10 * scale, theme.grassLight);
  pixelRect(ctx, px + 17 * scale, py + 7 * scale, 8 * scale, 8 * scale, theme.grassLight);
  pixelRect(ctx, px + 13 * scale, py + 18 * scale, 3 * scale, 3 * scale, '#b8c57e');
  pixelRect(ctx, px + 30 * scale, py + 11 * scale, 3 * scale, 3 * scale, '#b8c57e');
  pixelRect(ctx, px + 21 * scale, py + 30 * scale, 3 * scale, 3 * scale, theme.grassDark);
}

function drawTile(ctx, x, y, tile, theme) {
  const px = x * TILE;
  const py = y * TILE;
  const grassShade = (x * 17 + y * 31) % 5;
  pixelRect(ctx, px, py, TILE, TILE, tile === 'w' ? theme.water : tile === 'p' ? theme.path : tile === 'd' ? theme.dirt : theme.grass);
  if (tile === 'g') {
    if (grassShade !== 2) pixelRect(ctx, px + 7 + grassShade * 3, py + 10 + (x % 4) * 4, 2, 5, theme.grassDark);
    pixelRect(ctx, px + 25 - (y % 4) * 3, py + 28 + (x % 3), 2, 3, theme.grassLight);
    if ((x + y) % 7 === 0) pixelRect(ctx, px + 31, py + 10, 3, 3, STATIC_COLORS.flower);
  }
  if (tile === 'p') {
    pixelRect(ctx, px + 4, py + 11 + (x % 4), 13, 2, theme.pathLight);
    pixelRect(ctx, px + 22, py + 29 - (y % 4), 12, 2, theme.pathLight);
    pixelRect(ctx, px + 34, py + 16 + (x % 3), 3, 3, theme.pathLight);
  }
  if (tile === 'd') {
    pixelRect(ctx, px + 6, py + 9, 29, 2, '#845c48');
    pixelRect(ctx, px + 9, py + 27, 23, 2, '#845c48');
    pixelRect(ctx, px + 14 + (x % 4) * 4, py + 15 + (y % 3) * 4, 3, 7, theme.grassLight);
    pixelRect(ctx, px + 12 + (y % 4) * 6, py + 13, 7, 3, theme.grassLight);
  }
  if (tile === 'w') {
    pixelRect(ctx, px + 5, py + 12 + (x % 4), 11, 2, theme.waterLight);
    pixelRect(ctx, px + 22, py + 28 - (y % 3), 13, 2, theme.waterLight);
    pixelRect(ctx, px + 31, py + 8 + (x % 5), 4, 2, theme.waterLight);
  }
  if (tile === 'f') {
    pixelRect(ctx, px + 8, py + 8, 4, 31, STATIC_COLORS.trunk);
    pixelRect(ctx, px + 27, py + 8, 4, 31, STATIC_COLORS.trunk);
    pixelRect(ctx, px + 11, py + 12, 18, 3, STATIC_COLORS.trunk);
    pixelRect(ctx, px + 11, py + 27, 18, 3, STATIC_COLORS.trunk);
  }
  if (tile === 't') drawTree(ctx, px, py, theme);
}

function drawHouse(ctx, theme, village, originX = 5, originY = 2, scale = 1) {
  const px = originX * TILE;
  const py = originY * TILE;
  const width = 7 * TILE;
  const height = 5 * TILE;
  ctx.save();
  ctx.shadowColor = STATIC_COLORS.shadow;
  ctx.shadowBlur = 0;
  ctx.shadowOffsetX = 7 * scale;
  ctx.shadowOffsetY = 7 * scale;
  pixelRect(ctx, px + 14, py + 52, width - 28, height - 44, theme.pathLight);
  ctx.restore();
  const wall = village.house === 'stone' ? '#c7b9a1' : village.house === 'gable' ? '#e4c18d' : STATIC_COLORS.wall;
  pixelRect(ctx, px + 10, py + 45, width - 20, height - 40, wall);
  if (village.house === 'gable') {
    pixelRect(ctx, px + 18, py + 19, width - 36, 30, theme.roof);
    pixelRect(ctx, px + 44, py + 5, 8, 28, theme.roof);
    pixelRect(ctx, px + width - 52, py + 5, 8, 28, theme.roof);
  } else {
    pixelRect(ctx, px - 2, py + 31, width + 4, 28, theme.roof);
    pixelRect(ctx, px + 23, py + 16, width - 46, 24, theme.roof);
  }
  pixelRect(ctx, px + 28, py + 66, 42, 20, STATIC_COLORS.door);
  pixelRect(ctx, px + 36, py + 57, 26, 24, STATIC_COLORS.door);
  pixelRect(ctx, px + 38, py + 73, 4, 4, STATIC_COLORS.gold);
  pixelRect(ctx, px + 28, py + 51, 22, 18, STATIC_COLORS.window);
  pixelRect(ctx, px + width - 50, py + 51, 22, 18, STATIC_COLORS.window);
  pixelRect(ctx, px + 37, py + 51, 3, 18, theme.roof);
  pixelRect(ctx, px + width - 41, py + 51, 3, 18, theme.roof);
  pixelRect(ctx, px + 28, py + 58, 22, 3, theme.roof);
  pixelRect(ctx, px + width - 50, py + 58, 22, 3, theme.roof);
  if (village.house === 'rounddoor') {
    ctx.fillStyle = STATIC_COLORS.door;
    ctx.beginPath();
    ctx.arc(px + 49, py + 67, 22, Math.PI, 0);
    ctx.lineTo(px + 71, py + 88);
    ctx.lineTo(px + 27, py + 88);
    ctx.closePath();
    ctx.fill();
    pixelRect(ctx, px + 57, py + 74, 4, 4, STATIC_COLORS.gold);
  }
  pixelRect(ctx, px + 16, py + height - 7, width - 32, 7, '#8b664b');
  pixelRect(ctx, px + 35, py + 9, 22, 7, '#d9c79b');
}

function drawBridge(ctx, theme) {
  if (state.village.landscape !== 'river') return;
  const px = 23 * TILE;
  const py = 8 * TILE;
  pixelRect(ctx, px - 3, py, 3 * TILE + 6, TILE, '#9a6b4b');
  for (let x = 0; x < 3; x += 1) {
    pixelRect(ctx, px + x * TILE + 3, py + 5, TILE - 7, 4, '#d3a56c');
    pixelRect(ctx, px + x * TILE + 3, py + 17, TILE - 7, 4, '#b47c54');
    pixelRect(ctx, px + x * TILE + 3, py + 29, TILE - 7, 4, '#d3a56c');
  }
  pixelRect(ctx, px - 3, py - 6, 4, 52, '#76533e');
  pixelRect(ctx, px + 3 * TILE - 1, py - 6, 4, 52, '#76533e');
}

function drawGardenDecor(ctx, theme) {
  const px = 4 * TILE;
  const py = 11 * TILE;
  pixelRect(ctx, px - 4, py - 5, 7 * TILE + 8, 4, STATIC_COLORS.trunk);
  pixelRect(ctx, px - 4, py + 3 * TILE + 1, 7 * TILE + 8, 4, STATIC_COLORS.trunk);
  for (let row = 0; row < 3; row += 1) {
    for (let col = 0; col < 7; col += 1) {
      const cx = px + col * TILE + 13;
      const cy = py + row * TILE + 15;
      pixelRect(ctx, cx, cy, 5, 11, theme.grassLight);
      pixelRect(ctx, cx - 5, cy + 2, 7, 4, theme.grassLight);
      pixelRect(ctx, cx + 3, cy, 7, 4, theme.grassLight);
      if ((row + col) % 2 === 0) pixelRect(ctx, cx + 1, cy - 4, 4, 4, STATIC_COLORS.gold);
    }
  }
}

function drawNoticeboard(ctx) {
  const px = 15 * TILE + 11;
  const py = 8 * TILE - 22;
  pixelRect(ctx, px + 11, py + 27, 5, 34, STATIC_COLORS.trunk);
  pixelRect(ctx, px, py, 28, 34, '#9d704f');
  pixelRect(ctx, px + 4, py + 4, 20, 23, '#e6c991');
  pixelRect(ctx, px + 8, py + 9, 9, 2, '#b25f52');
  pixelRect(ctx, px + 7, py + 16, 14, 2, '#6c7f58');
  pixelRect(ctx, px + 12, py + 22, 5, 3, STATIC_COLORS.gold);
}

function drawGate(ctx, theme) {
  const px = 28 * TILE;
  const py = 14 * TILE;
  pixelRect(ctx, px - 11, py - 25, 6, 52, STATIC_COLORS.trunk);
  pixelRect(ctx, px + 34, py - 25, 6, 52, STATIC_COLORS.trunk);
  pixelRect(ctx, px - 5, py - 17, 44, 5, theme.pathLight);
  pixelRect(ctx, px - 5, py + 2, 44, 5, theme.pathLight);
  pixelRect(ctx, px + 18, py - 14, 4, 30, theme.pathLight);
}

function drawHobbit(ctx, cx, cy, scale, hobbit, pose = 'down') {
  const skin = hobbit.palette.skin;
  const coat = hobbit.palette.coat;
  const hair = hobbit.palette.hair;
  const accent = hobbit.palette.accent;
  const bodyWidth = hobbit.body === 'lean' ? 13 : hobbit.body === 'sturdy' ? 19 : 16;
  const bodyHeight = hobbit.body === 'lean' ? 24 : 21;
  const left = cx - bodyWidth * scale / 2;
  const top = cy - 10 * scale;
  ctx.save();
  ctx.imageSmoothingEnabled = false;
  ctx.fillStyle = STATIC_COLORS.shadow;
  ctx.beginPath();
  ctx.ellipse(cx, cy + 22 * scale, 15 * scale, 5 * scale, 0, 0, Math.PI * 2);
  ctx.fill();
  pixelRect(ctx, left + 2 * scale, top + bodyHeight * scale, 5 * scale, 11 * scale, STATIC_COLORS.door);
  pixelRect(ctx, left + bodyWidth * scale - 7 * scale, top + bodyHeight * scale, 5 * scale, 11 * scale, STATIC_COLORS.door);
  pixelRect(ctx, left, top + 5 * scale, bodyWidth * scale, bodyHeight * scale, coat);
  pixelRect(ctx, left - 3 * scale, top + 10 * scale, 4 * scale, 11 * scale, coat);
  pixelRect(ctx, left + bodyWidth * scale - 1 * scale, top + 10 * scale, 4 * scale, 11 * scale, coat);
  pixelRect(ctx, cx - 4 * scale, top + 18 * scale, 8 * scale, 4 * scale, accent);
  pixelRect(ctx, cx - 13 * scale, top - 12 * scale, 26 * scale, 20 * scale, skin);
  pixelRect(ctx, cx - 10 * scale, top - 16 * scale, 20 * scale, 5 * scale, hair);
  if (hobbit.hair === 'waves') {
    pixelRect(ctx, cx - 14 * scale, top - 9 * scale, 5 * scale, 14 * scale, hair);
    pixelRect(ctx, cx + 9 * scale, top - 9 * scale, 5 * scale, 14 * scale, hair);
    pixelRect(ctx, cx - 9 * scale, top - 19 * scale, 18 * scale, 5 * scale, hair);
  } else if (hobbit.hair === 'curls') {
    pixelRect(ctx, cx - 15 * scale, top - 8 * scale, 6 * scale, 7 * scale, hair);
    pixelRect(ctx, cx + 9 * scale, top - 8 * scale, 6 * scale, 7 * scale, hair);
    pixelRect(ctx, cx - 10 * scale, top - 21 * scale, 20 * scale, 8 * scale, hair);
    pixelRect(ctx, cx - 13 * scale, top - 14 * scale, 7 * scale, 6 * scale, hair);
    pixelRect(ctx, cx + 6 * scale, top - 14 * scale, 7 * scale, 6 * scale, hair);
  } else {
    pixelRect(ctx, cx - 12 * scale, top - 13 * scale, 24 * scale, 7 * scale, hair);
    pixelRect(ctx, cx - 13 * scale, top - 7 * scale, 4 * scale, 8 * scale, hair);
    pixelRect(ctx, cx + 9 * scale, top - 7 * scale, 4 * scale, 8 * scale, hair);
  }
  pixelRect(ctx, cx - 16 * scale, top - 4 * scale, 5 * scale, 6 * scale, skin);
  pixelRect(ctx, cx + 11 * scale, top - 4 * scale, 5 * scale, 6 * scale, skin);
  pixelRect(ctx, cx - 7 * scale, top - 5 * scale, 3 * scale, 3 * scale, STATIC_COLORS.ink);
  pixelRect(ctx, cx + 4 * scale, top - 5 * scale, 3 * scale, 3 * scale, STATIC_COLORS.ink);
  if (pose === 'left') pixelRect(ctx, left - 7 * scale, top + 17 * scale, 7 * scale, 4 * scale, accent);
  if (pose === 'right') pixelRect(ctx, left + bodyWidth * scale, top + 17 * scale, 7 * scale, 4 * scale, accent);
  ctx.restore();
}

function drawCreatorBackdrop(ctx, width, height, theme, village) {
  ctx.clearRect(0, 0, width, height);
  ctx.fillStyle = theme.sky;
  ctx.fillRect(0, 0, width, height);
  pixelRect(ctx, 0, height * 0.38, width, height * 0.62, theme.grass);
  pixelRect(ctx, 0, height * 0.32, width * 0.38, height * 0.12, theme.distant);
  pixelRect(ctx, width * 0.26, height * 0.27, width * 0.4, height * 0.17, theme.distant);
  pixelRect(ctx, width * 0.62, height * 0.34, width * 0.45, height * 0.13, theme.distant);
  for (let i = 0; i < 12; i += 1) {
    const x = 18 + ((i * 71) % Math.max(width - 36, 1));
    const y = height * 0.47 + ((i * 37) % Math.max(height * 0.38, 1));
    pixelRect(ctx, x, y, 5, 3, i % 2 ? theme.grassDark : theme.grassLight);
  }
  const houseX = width * 0.56;
  const houseY = height * 0.31;
  drawHouse(ctx, theme, village, houseX / TILE, houseY / TILE, 1.2);
  drawTree(ctx, width * 0.08, height * 0.43, theme, 1.55);
  drawTree(ctx, width * 0.82, height * 0.44, theme, 1.4);
  pixelRect(ctx, width * 0.06, height * 0.83, width * 0.88, 5, theme.path);
  pixelRect(ctx, width * 0.06, height * 0.83 + 8, width * 0.88, 3, theme.pathLight);
}

function drawCreatorPreview() {
  if (!creatorContext) return;
  const theme = themeForVillage();
  drawCreatorBackdrop(creatorContext, creatorCanvas.width, creatorCanvas.height, theme, state.village);
  if (setupStep === 1) {
    pixelRect(creatorContext, creatorCanvas.width * 0.18, creatorCanvas.height * 0.77, creatorCanvas.width * 0.64, 5, STATIC_COLORS.shadow);
    drawHobbit(creatorContext, creatorCanvas.width * 0.5, creatorCanvas.height * 0.68, 4.2, state.hobbit);
    pixelRect(creatorContext, creatorCanvas.width * 0.5 - 2, creatorCanvas.height * 0.67, 4, 4, STATIC_COLORS.gold);
  } else {
    drawHobbit(creatorContext, creatorCanvas.width * 0.28, creatorCanvas.height * 0.7, 3.3, state.hobbit, 'right');
    pixelRect(creatorContext, creatorCanvas.width * 0.34, creatorCanvas.height * 0.83, creatorCanvas.width * 0.48, 5, theme.path);
    pixelRect(creatorContext, creatorCanvas.width * 0.34, creatorCanvas.height * 0.83 + 9, creatorCanvas.width * 0.48, 3, theme.pathLight);
  }
}

function drawVillage() {
  if (!context || !canvas) return;
  const theme = themeForVillage();
  context.imageSmoothingEnabled = false;
  context.clearRect(0, 0, canvas.width, canvas.height);
  pixelRect(context, 0, 0, canvas.width, canvas.height, theme.grass);
  for (let y = 0; y < MAP_HEIGHT; y += 1) {
    for (let x = 0; x < MAP_WIDTH; x += 1) drawTile(context, x, y, tileAt(x, y), theme);
  }
  drawHouse(context, theme, state.village);
  drawBridge(context, theme);
  drawGardenDecor(context, theme);
  drawNoticeboard(context);
  drawGate(context, theme);
  const nearby = getInteraction(state.player, INTERACTIONS);
  drawInteractionPrompt(nearby);
  drawHobbit(context, state.player.x * TILE + TILE / 2, state.player.y * TILE + TILE / 2, 1.55, state.hobbit);
}

function drawInteractionPrompt(point) {
  if (!point || !context) return;
  const px = state.player.x * TILE + TILE / 2;
  const py = state.player.y * TILE - 8;
  const label = `E · ${point.label}`;
  context.font = '13px "DM Mono", monospace';
  const width = context.measureText(label).width + 24;
  pixelRect(context, px - width / 2 + 3, py - 30 + 3, width, 24, 'rgba(36, 54, 47, .25)');
  pixelRect(context, px - width / 2, py - 30, width, 24, STATIC_COLORS.ink);
  context.fillStyle = STATIC_COLORS.cream;
  context.textAlign = 'center';
  context.fillText(label, px, py - 13);
}

function updateHud() {
  const landscapeLabel = LANDSCAPE_LABELS[state.village.landscape];
  document.querySelector('#stage-kicker').textContent = `${state.village.name} · ${landscapeLabel}`;
  document.querySelector('#clock-label').textContent = formatClock(state.clock);
  document.querySelector('#day-label').textContent = `Day ${state.day} · Late Summer`;
  document.querySelector('#hobbit-label').textContent = state.hobbit.name;
  document.querySelector('#hobbit-detail').textContent = `${HAIR_LABELS[state.hobbit.hair]} · ${state.village.name}`;
  document.querySelector('#village-label').textContent = state.village.name;
  document.querySelector('#village-landscape').textContent = landscapeLabel;
  document.querySelector('#village-house').textContent = HOUSE_LABELS[state.village.house];
  const tasks = Object.entries(state.tasks);
  const completed = tasks.filter(([, done]) => done).length;
  document.querySelector('#task-count').textContent = `${completed} / ${tasks.length}`;
  tasks.forEach(([task, done]) => {
    const node = document.querySelector(`[data-task="${task}"]`);
    if (!node) return;
    node.classList.toggle('is-complete', done);
    node.querySelector('.task-check').textContent = done ? '✓' : '○';
  });
  document.querySelector('#village-log').innerHTML = state.notes.map((note) => `<li>${escapeHtml(note)}</li>`).join('');
  if (avatarContext) {
    avatarContext.clearRect(0, 0, avatarCanvas.width, avatarCanvas.height);
    avatarContext.fillStyle = themeForVillage().paper ?? STATIC_COLORS.paper;
    avatarContext.fillRect(0, 0, avatarCanvas.width, avatarCanvas.height);
    drawHobbit(avatarContext, avatarCanvas.width / 2, 70, 2.2, state.hobbit);
  }
}

function addNote(message) {
  state.notes = [message, ...state.notes].slice(0, 6);
  updateHud();
}

function move(delta) {
  const next = movePlayer(state.player, delta, Array.from({ length: MAP_HEIGHT }, (_, y) => Array.from({ length: MAP_WIDTH }, (_, x) => tileAt(x, y))), BLOCKED_TILES);
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
  if (!point) return showToast('Nothing here but the evening breeze.');
  state.tasks[point.task] = true;
  state.clock = advanceClock(state.clock, 15);
  addNote(point.message);
  drawVillage();
  saveState();
  showToast(point.message);
}

function resetDay() {
  state = normalizeGameState({ ...state, player: { x: 15, y: 14 }, clock: 495, tasks: { garden: false, pond: false, gate: false, noticeboard: false }, notes: DEFAULT_NOTES });
  updateHud();
  drawVillage();
  saveState();
  showToast('The village is ready for a fresh morning.');
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

async function toggleFullscreen() {
  try {
    if (!document.fullscreenElement) await document.documentElement.requestFullscreen();
    else await document.exitFullscreen();
    updateFullscreenLabel();
  } catch {
    showToast('Fullscreen is not available in this browser.');
  }
}

function updateFullscreenLabel() {
  const button = document.querySelector('#fullscreen-button');
  if (button) button.innerHTML = document.fullscreenElement ? 'Windowed <span aria-hidden="true">↙</span>' : 'Fullscreen <span aria-hidden="true">↗</span>';
}

function hydrateInvite() {
  if (!state.inviteCode) return;
  document.querySelector('#invite-code').textContent = state.inviteCode;
  document.querySelector('#invite-result').hidden = false;
}

function handleKeydown(event) {
  if (setupScreen && !setupScreen.hidden) return;
  if (['INPUT', 'TEXTAREA'].includes(document.activeElement?.tagName)) return;
  const keys = { w: { x: 0, y: -1 }, ArrowUp: { x: 0, y: -1 }, s: { x: 0, y: 1 }, ArrowDown: { x: 0, y: 1 }, a: { x: -1, y: 0 }, ArrowLeft: { x: -1, y: 0 }, d: { x: 1, y: 0 }, ArrowRight: { x: 1, y: 0 } };
  const key = event.key.length === 1 ? event.key.toLowerCase() : event.key;
  if (keys[key]) { event.preventDefault(); move(keys[key]); }
  if (key === 'e' || event.key === ' ') { event.preventDefault(); interact(); }
  if (key === 'r') resetDay();
}

document.querySelector('#creation-form').addEventListener('submit', handleSetupSubmit);
document.querySelector('#setup-back').addEventListener('click', () => { setupStep = 1; renderSetup(); });
document.querySelector('#cancel-edit').addEventListener('click', cancelCreator);
document.querySelector('#hobbit-name').addEventListener('input', (event) => { state.hobbit.name = event.target.value; renderSetup(); });
document.querySelector('#village-name').addEventListener('input', (event) => { state.village.name = event.target.value; renderSetup(); });
document.querySelectorAll('[data-group]').forEach((group) => group.addEventListener('click', (event) => {
  const choice = event.target.closest('[data-value]');
  if (choice) setChoice(group.dataset.group, choice.dataset.value);
}));
document.querySelector('#edit-hobbit-button').addEventListener('click', () => openCreator(1, true));
document.querySelector('#edit-village-button').addEventListener('click', () => openCreator(2, true));
document.querySelector('#invite-button').addEventListener('click', makeInvite);
document.querySelector('#copy-code').addEventListener('click', copyInvite);
document.querySelector('#sign-in-button').addEventListener('click', sendMagicLink);
document.querySelector('#fullscreen-button')?.addEventListener('click', toggleFullscreen);
document.querySelector('#account-button').addEventListener('click', () => document.querySelector('#account-dialog').showModal());
document.querySelector('#account-dialog').addEventListener('click', (event) => { if (event.target === event.currentTarget) event.currentTarget.close(); });
document.addEventListener('keydown', handleKeydown);
document.addEventListener('fullscreenchange', updateFullscreenLabel);

if (!state.creationComplete) openCreator(1, false);
else {
  setupScreen.hidden = true;
  playScreen.hidden = false;
  updateHud();
  hydrateInvite();
  drawVillage();
}
