import './game.css';
import {
  advanceClock,
  BUILDINGS,
  buildWorldGrid,
  createDefaultGameState,
  createInviteCode,
  formatClock,
  getInteraction,
  INTERACTIONS,
  isCreationComplete,
  LANDSCAPE_LABELS,
  HOUSE_LABELS,
  HAIR_LABELS,
  MAP_HEIGHT,
  MAP_WIDTH,
  movePlayer,
  NPCS,
  normalizeGameState,
  resolveVillageTheme,
  tileAt,
  VIEW_H,
  VIEW_W,
  WORLD_BLOCKED,
  WORLD_HEIGHT,
  WORLD_WIDTH
} from './game-systems.js';
import { supabase, supabaseConfigured } from './supabase-client.js';
import {
  drawBuildingSprite,
  drawBridgeSprite,
  drawGateSprite,
  drawGardenSprite,
  drawHobbitSprite,
  drawHouseSprite,
  drawNoticeboardSprite,
  drawPixels,
  drawPondSprite,
  drawTreeSprite,
  GRID_H,
  GRID_W,
  TILE
} from './sprite-engine.js';

const TILE_PX = TILE;
const BLOCKED_TILES = new Set(['t', 'w', 'f']);
const STORAGE_KEY = 'hobbit-moon-village-v2';
const LEGACY_STORAGE_KEY = 'hobbit-moon-village-v1';
const DEFAULT_NOTES = ['You arrived before the kettle boiled.', 'The hill is quiet. The good kind.'];

const canvas = document.querySelector('#village-canvas');
const context = canvas?.getContext('2d');
const creatorCanvas = document.querySelector('#creator-canvas');
const creatorContext = creatorCanvas?.getContext('2d');
const avatarCanvas = document.querySelector('#avatar-canvas');
const avatarContext = avatarCanvas?.getContext('2d');
const setupScreen = document.querySelector('#setup-screen');
const playScreen = document.querySelector('#play-screen');

// Logical offscreen buffer for crisp pixel-art scaling.
const buffer = document.createElement('canvas');
buffer.width = GRID_W;
buffer.height = GRID_H;
const bufferCtx = buffer?.getContext('2d');

let state = loadState();
let setupStep = 1;
let editing = false;
let setupSnapshot = null;
let toastTimer;
let lastMoveAt = 0;

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
  drawVillage();
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
  drawVillage();
  showToast(`Welcome to ${state.village.name}.`);
}

function cancelCreator() {
  if (setupSnapshot) state = normalizeGameState(setupSnapshot);
  setupSnapshot = null;
  editing = false;
  setupScreen.hidden = true;
  playScreen.hidden = false;
  updateHud();
  drawVillage();
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
  return resolveVillageTheme(state.village);
}

// --- Pixel grid helpers ----------------------------------------------------

function tileRects(x, y, tile, theme, village) {
  const px = x * TILE;
  const py = y * TILE;
  const base = tile === 'w' ? theme.water : tile === 'p' ? theme.path : tile === 'd' ? theme.dirt : theme.grass;
  const rects = [[px, py, TILE, TILE, base]];
  if (tile === 'g') {
    const shade = (x * 17 + y * 31) % 5;
    if (shade !== 2) rects.push([px + 4 + (shade % 4) * 2, py + 6, 2, 4, theme.grassDark]);
    rects.push([px + 11 - (y % 3) * 2, py + 11, 2, 3, theme.grassLight]);
    if ((x + y) % 7 === 0) rects.push([px + 12, py + 4, 2, 2, '#b8c57e']);
    if ((x * 3 + y) % 11 === 0) rects.push([px + 6, py + 9, 2, 2, theme.flower ?? '#e29178']);
  }
  if (tile === 'p') {
    rects.push([px + 2, py + 5 + (x % 3), 6, 2, theme.pathLight]);
    rects.push([px + 9, py + 11 - (y % 3), 5, 2, theme.pathLight]);
  }
  if (tile === 'd') {
    rects.push([px + 2, py + 4, 12, 2, '#845c48']);
    rects.push([px + 4, py + 12, 8, 2, theme.grassLight]);
  }
  if (tile === 'w') {
    rects.push([px + 3, py + 5 + (x % 3), 5, 2, theme.waterLight]);
    rects.push([px + 9, py + 11 - (y % 3), 5, 2, theme.waterLight]);
  }
  if (tile === 'f') {
    rects.push([px + 6, py + 2, 4, 14, '#9d704f']);
    rects.push([px + 6, py + 2, 4, 2, '#7c5538']);
  }
  return rects;
}

let worldGrid = null;

function ensureWorldGrid() {
  if (!worldGrid) worldGrid = buildWorldGrid(state.village);
  return worldGrid;
}

function cameraForPlayer(player) {
  const camX = Math.max(0, Math.min(player.x - Math.floor(VIEW_W / 2), WORLD_WIDTH - VIEW_W));
  const camY = Math.max(0, Math.min(player.y - Math.floor(VIEW_H / 2), WORLD_HEIGHT - VIEW_H));
  return { camX, camY };
}

function drawWorld(ctx, theme, village, spec, player, cam) {
  drawPixels(ctx, [[0, 0, GRID_W, GRID_H, theme.grass]]);
  // far hills along the top of the viewport
  for (let x = 0; x < GRID_W; x += 16) {
    const h = 26 + ((x * 7) % 14);
    drawPixels(ctx, [[x, 46 - h, 16, h, theme.distant]]);
  }
  drawPixels(ctx, [[0, 44, GRID_W, 4, theme.grass]]);

  const { camX, camY } = cam;
  // ground tiles within the viewport window
  for (let sy = 0; sy < VIEW_H; sy += 1) {
    const wy = camY + sy;
    if (wy <= 0 || wy >= WORLD_HEIGHT - 1) continue;
    for (let sx = 0; sx < VIEW_W; sx += 1) {
      const wx = camX + sx;
      if (wx <= 0 || wx >= WORLD_WIDTH - 1) continue;
      drawPixels(ctx, tileRects(wx - camX, wy - camY, worldGrid[wy][wx], theme, village));
    }
  }

  const worldToScreen = (wx, wy) => ({ sx: (wx - camX) * TILE, sy: (wy - camY) * TILE });

  // buildings
  for (const b of BUILDINGS) {
    const { sx, sy } = worldToScreen(b.x, b.y);
    if (sx < -80 || sy < -80 || sx > GRID_W || sy > GRID_H) continue;
    drawBuildingSprite(ctx, b.type, sx, sy, theme);
  }

  // garden, pond, bridge, noticeboard, gate props near the starting area
  const garden = worldToScreen(5, 9); drawGardenSprite(ctx, theme, garden.sx, garden.sy);
  const pond = worldToScreen(11, 3); drawPondSprite(ctx, theme, pond.sx, pond.sy);
  const bridge = worldToScreen(45, 17); drawBridgeSprite(ctx, theme, bridge.sx, bridge.sy);
  const board = worldToScreen(30, 9); drawNoticeboardSprite(ctx, board.sx - 6, board.sy - 24);
  const gate = worldToScreen(60, 20); drawGateSprite(ctx, theme, gate.sx, gate.sy);

  // trees in the viewport
  for (let wy = camY; wy < camY + VIEW_H; wy += 1) {
    for (let wx = camX; wx < camX + VIEW_W; wx += 1) {
      if (worldGrid[wy] && worldGrid[wy][wx] === 't') {
        const { sx, sy } = worldToScreen(wx, wy);
        drawTreeSprite(ctx, theme, sx, sy, (wx * 7 + wy * 13) % 5);
      }
    }
  }

  // NPCs
  for (const npc of NPCS) {
    const { sx, sy } = worldToScreen(npc.x, npc.y);
    if (sx < -20 || sy < -30 || sx > GRID_W || sy > GRID_H) continue;
    const feetY = sy * TILE + TILE / 2 + 4;
    drawHobbitSprite(ctx, { body: npc.body, hair: npc.hair, palette: npc.palette }, sx * TILE + TILE / 2, feetY);
  }

  // player
  const p = worldToScreen(player.x, player.y);
  const playerFeet = p.sy * TILE + TILE / 2 + 4;
  drawHobbitSprite(ctx, spec, p.sx * TILE + TILE / 2, playerFeet);
}

function drawVillage() {
  if (!context || !bufferCtx) return;
  const theme = themeForVillage();
  ensureWorldGrid();
  const cam = cameraForPlayer(state.player);
  bufferCtx.imageSmoothingEnabled = false;
  bufferCtx.clearRect(0, 0, GRID_W, GRID_H);
  drawWorld(bufferCtx, theme, state.village, state.hobbit, state.player, cam);

  context.imageSmoothingEnabled = false;
  context.clearRect(0, 0, canvas.width, canvas.height);
  context.drawImage(buffer, 0, 0, GRID_W, GRID_H, 0, 0, canvas.width, canvas.height);
  drawInteractionPrompt();
}

function drawInteractionPrompt() {
  if (!context) return;
  const cam = cameraForPlayer(state.player);
  const npc = nearbyNpc();
  const point = getInteraction(state.player, INTERACTIONS);
  let label = null;
  if (npc) label = `E · Talk to ${npc.name}`;
  else if (point) label = `E · ${point.label}`;
  if (!label) return;
  const cx = (state.player.x - cam.camX) * TILE + TILE / 2;
  const cy = (state.player.y - cam.camY) * TILE;
  const baseX = (cx / GRID_W) * canvas.width;
  const baseY = (cy / GRID_H) * canvas.height;
  const scaleX = canvas.width / GRID_W;
  const scaleY = canvas.height / GRID_H;
  context.font = `${Math.round(13 * scaleX)}px "DM Mono", monospace`;
  const textWidth = context.measureText(label).width + 22 * scaleX;
  const px = baseX - textWidth / 2;
  const py = baseY - 30 * scaleY;
  context.fillStyle = 'rgba(36, 54, 47, .28)';
  context.fillRect(px + 3, py + 3, textWidth, 22 * scaleY);
  context.fillStyle = '#24362f';
  context.fillRect(px, py, textWidth, 22 * scaleY);
  context.fillStyle = '#f8e7c4';
  context.textAlign = 'center';
  context.fillText(label, baseX, py + 15 * scaleY);
}

function nearbyNpc() {
  return NPCS.find((npc) => Math.hypot(npc.x - state.player.x, npc.y - state.player.y) <= 1.5) ?? null;
}

function drawCreatorPreview() {
  if (!creatorContext || !bufferCtx) return;
  const theme = themeForVillage();
  bufferCtx.imageSmoothingEnabled = false;
  bufferCtx.clearRect(0, 0, GRID_W, GRID_H);
  // preview backdrop at logical scale
  drawPixels(bufferCtx, [[0, 0, GRID_W, GRID_H, theme.sky]]);
  for (let x = 0; x < GRID_W; x += 16) {
    const h = 30 + ((x * 11) % 18);
    drawPixels(bufferCtx, [[x, 92 - h, 16, h, theme.distant]]);
  }
  drawPixels(bufferCtx, [[0, 90, GRID_W, GRID_H - 90, theme.grass]]);
  drawHouseSprite(bufferCtx, theme, state.village.house, GRID_W * 0.52, GRID_H * 0.30);
  drawTreeSprite(bufferCtx, theme, GRID_W * 0.06, GRID_H * 0.46, 1);
  drawTreeSprite(bufferCtx, theme, GRID_W * 0.80, GRID_H * 0.47, 3);
  drawPixels(bufferCtx, [[GRID_W * 0.06, GRID_H * 0.82, GRID_W * 0.88, 4, theme.path]]);
  drawPixels(bufferCtx, [[GRID_W * 0.06, GRID_H * 0.82 + 5, GRID_W * 0.88, 3, theme.pathLight]]);
  if (setupStep === 1) {
    drawHobbitSprite(bufferCtx, state.hobbit, GRID_W * 0.5, GRID_H * 0.82);
    drawPixels(bufferCtx, [[Math.round(GRID_W * 0.5) - 2, Math.round(GRID_H * 0.78), 4, 4, '#e2b96e']]);
  } else {
    drawHobbitSprite(bufferCtx, state.hobbit, GRID_W * 0.30, GRID_H * 0.80, false);
    drawPixels(bufferCtx, [[GRID_W * 0.36, GRID_H * 0.82, GRID_W * 0.46, 4, theme.path]]);
    drawPixels(bufferCtx, [[GRID_W * 0.36, GRID_H * 0.82 + 5, GRID_W * 0.46, 3, theme.pathLight]]);
  }

  creatorContext.imageSmoothingEnabled = false;
  creatorContext.clearRect(0, 0, creatorCanvas.width, creatorCanvas.height);
  creatorContext.drawImage(buffer, 0, 0, GRID_W, GRID_H, 0, 0, creatorCanvas.width, creatorCanvas.height);
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
  if (avatarContext && bufferCtx) {
    bufferCtx.imageSmoothingEnabled = false;
    bufferCtx.clearRect(0, 0, GRID_W, GRID_H);
    drawPixels(bufferCtx, [[0, 0, GRID_W, GRID_H, themeForVillage().paper ?? '#f4e6c8']]);
    // avatar uses the lower portion of the buffer for a head-and-shoulders crop
    drawHobbitSprite(bufferCtx, state.hobbit, GRID_W / 2, GRID_H * 0.92);
    avatarContext.imageSmoothingEnabled = false;
    avatarContext.clearRect(0, 0, avatarCanvas.width, avatarCanvas.height);
    avatarContext.drawImage(buffer, 0, 0, GRID_W, GRID_H, 0, 0, avatarCanvas.width, avatarCanvas.height);
  }
}

function addNote(message) {
  state.notes = [message, ...state.notes].slice(0, 6);
  updateHud();
}

function move(delta) {
  const grid = ensureWorldGrid();
  const next = movePlayer(state.player, delta, grid, WORLD_BLOCKED);
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
  const npc = nearbyNpc();
  if (npc) {
    state.clock = advanceClock(state.clock, 5);
    addNote(`${npc.name} says, “${npc.greet}”`);
    drawVillage();
    saveState();
    return showToast(`${npc.name}: ${npc.greet}`);
  }
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
  state = normalizeGameState({ ...state, player: { x: 14, y: 11 }, clock: 495, tasks: { garden: false, pond: false, gate: false, noticeboard: false }, notes: DEFAULT_NOTES });
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
  const keys = {
    w: { x: 0, y: -1 }, ArrowUp: { x: 0, y: -1 },
    s: { x: 0, y: 1 }, ArrowDown: { x: 0, y: 1 },
    a: { x: -1, y: 0 }, ArrowLeft: { x: -1, y: 0 },
    d: { x: 1, y: 0 }, ArrowRight: { x: 1, y: 0 }
  };
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
