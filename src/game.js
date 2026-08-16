import './game.css';
import {
  advanceClock,
  BUILDINGS,
  buildWorldGrid,
  createDefaultGameState,
  createInviteCode,
  formatClock,
  getInteraction,
  enterInterior,
  exitInterior,
  INTERACTIONS,
  isCreationComplete,
  LANDSCAPE_LABELS,
  HOUSE_LABELS,
  HAIR_LABELS,
  lightingFor,
  MAP_HEIGHT,
  MAP_WIDTH,
  movePlayer,
  movePlayerRealtime,
  NPCS,
  nextOnboardingObjective,
  npcGreetingFor,
  npcMotionAt,
  npcPositionAt,
  normalizeGameState,
  resolveVillageTheme,
  tileAt,
  timeOfDay,
  wrapDialogueText,
  VIEW_H,
  VIEW_W,
  WORLD_BLOCKED,
  WORLD_HEIGHT,
  WORLD_LANDMARKS,
  WORLD_WIDTH,
  worldPixelPosition
} from './game-systems.js';
import { supabase, supabaseConfigured } from './supabase-client.js';
import { completeRequest, createDailyState, inventoryQuantity, ITEMS, performActivity, recordVillagerTalk, WEATHER_LABELS } from './daily-loop.js';
import {
  drawBuildingSprite,
  drawBuildingShadow,
  drawBuildingDetail,
  drawColonyProp,
  drawBridgeSprite,
  drawGateSprite,
  drawGardenSprite,
  drawHills,
  drawHobbitSprite,
  drawInteriorScene,
  drawHouseSprite,
  drawNoticeboardSprite,
  drawPixels,
  drawPondSprite,
  drawSky,
  drawSoftShadow,
  drawTerrainDetail,
  drawTorchGlow,
  drawTreeSprite,
  drawVignette,
  drawNameplate,
  drawSelectionRing,
  drawWeatherOverlay,
  drawWorldLabel,
  drawWorldLandmark,
  GRID_H,
  GRID_W,
  TILE
} from './sprite-engine.js';

const TILE_PX = TILE;
const BLOCKED_TILES = new Set(['t', 'w', 'f']);
const STORAGE_KEY = 'hobbit-moon-village-v2';
const LEGACY_STORAGE_KEY = 'hobbit-moon-village-v1';
const DEFAULT_NOTES = ['You arrived before the kettle boiled.', 'The hill is quiet. The good kind.'];
const COLONY_PROPS = [
  { type: 'hedge', x: 1, y: 4 },
  { type: 'hedge', x: 1, y: 5 },
  { type: 'hedge', x: 2, y: 4 },
  { type: 'flowerbed', x: 16, y: 5 },
  { type: 'bench', x: 17, y: 9 },
  { type: 'lantern', x: 13, y: 9 },
  { type: 'lantern', x: 20, y: 9 },
  { type: 'fence', x: 4, y: 8 },
  { type: 'fence', x: 9, y: 8 },
  { type: 'crate', x: 18, y: 13 },
  { type: 'barrel', x: 20, y: 13 },
  { type: 'flowerbed', x: 16, y: 15 },
  { type: 'bench', x: 17, y: 16 },
  { type: 'lantern', x: 30, y: 11 },
  { type: 'hedge', x: 28, y: 17 },
  { type: 'hedge', x: 30, y: 17 }
];

const canvas = document.querySelector('#village-canvas');
const context = canvas?.getContext('2d');
const creatorCanvas = document.querySelector('#creator-canvas');
const creatorContext = creatorCanvas?.getContext('2d');
const avatarCanvas = document.querySelector('#avatar-canvas');
const avatarContext = avatarCanvas?.getContext('2d');
const minimapCanvas = document.querySelector('#minimap-canvas');
const minimapContext = minimapCanvas?.getContext('2d');
const setupScreen = document.querySelector('#setup-screen');
const playScreen = document.querySelector('#play-screen');

// Higher-resolution backing buffer: the art remains authored on the logical grid,
// but is rasterised at 5× so a future desktop shell and high-DPI display retain
// crisp edges without changing the world-coordinate contract.
const RENDER_SCALE = 5;
const ZOOM_MIN = 0.75;
const ZOOM_MAX = 1.25;
const ZOOM_STEP = 0.1;
const DEFAULT_ZOOM = 0.88;
const buffer = document.createElement('canvas');
buffer.width = GRID_W * RENDER_SCALE;
buffer.height = GRID_H * RENDER_SCALE;
const bufferCtx = buffer?.getContext('2d');

let state = loadState();
let setupStep = 1;
let editing = false;
let setupSnapshot = null;
let toastTimer;
let lastMoveAt = 0;
let playerMotion = { x: state.player.x, y: state.player.y, facing: 'down', phase: 0 };
let heldDirections = new Set();
let movementDistance = 0;
let lastFrameAt = null;
let lastPersistAt = 0;
let dialogue = null;
let cameraZoom = DEFAULT_ZOOM;
let bookOpen = true;
let hudOpen = true;
let minimapOpen = true;

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

function beginLogicalBuffer() {
  bufferCtx.setTransform(RENDER_SCALE, 0, 0, RENDER_SCALE, 0, 0);
  bufferCtx.imageSmoothingEnabled = false;
  bufferCtx.clearRect(0, 0, GRID_W, GRID_H);
}

function endLogicalBuffer() {
  bufferCtx.setTransform(1, 0, 0, 1, 0, 0);
}

function syncPlayerMotion() {
  playerMotion = { x: state.player.x, y: state.player.y, facing: playerMotion.facing ?? 'down', phase: playerMotion.phase ?? 0 };
  movementDistance = 0;
}

function persistPlayerMotion() {
  state.player = { x: Number(playerMotion.x.toFixed(3)), y: Number(playerMotion.y.toFixed(3)) };
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

function updateZoomLabel() {
  const label = document.querySelector('#game-zoom-label');
  if (label) label.textContent = `${Math.round(cameraZoom * 100)}%`;
}

function setCameraZoom(delta) {
  cameraZoom = Math.max(ZOOM_MIN, Math.min(ZOOM_MAX, Number((cameraZoom + delta).toFixed(2))));
  updateZoomLabel();
  drawVillage(performance.now());
}

function setBookOpen(open) {
  bookOpen = Boolean(open);
  const book = document.querySelector('#village-sidebar');
  const toggle = document.querySelector('#game-book-toggle');
  book?.classList.toggle('is-collapsed', !bookOpen);
  toggle?.setAttribute('aria-expanded', String(bookOpen));
  if (toggle) toggle.textContent = bookOpen ? 'Hide village book' : 'Village book';
}

function setHudOpen(open) {
  hudOpen = Boolean(open);
  const hud = document.querySelector('#game-window-hud');
  const toggle = document.querySelector('#game-hud-toggle');
  hud?.classList.toggle('hud-is-collapsed', !hudOpen);
  toggle?.setAttribute('aria-expanded', String(hudOpen));
  if (toggle) toggle.innerHTML = hudOpen ? 'HUD <span aria-hidden="true">⌃</span>' : 'HUD <span aria-hidden="true">⌄</span>';
}

function setMinimapOpen(open) {
  minimapOpen = Boolean(open);
  const shell = document.querySelector('#minimap-shell');
  const reopen = document.querySelector('#minimap-reopen');
  const toggles = [document.querySelector('#game-minimap-toggle')];
  shell?.classList.toggle('is-collapsed', !minimapOpen);
  if (reopen) reopen.hidden = minimapOpen;
  toggles.forEach((toggle) => {
    if (!toggle) return;
    toggle.setAttribute('aria-expanded', String(minimapOpen));
    toggle.textContent = minimapOpen ? 'Map' : 'Map +';
  });
  drawMinimap();
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
  worldGrid = null;
  renderSetup();
  drawVillage();
}

function openCreator(step = 1, isEditing = false) {
  setupSnapshot = structuredClone(state);
  setupStep = step;
  editing = isEditing;
  const canvasWrap = document.querySelector('.canvas-wrap');
  if (isEditing && canvasWrap) {
    if (setupScreen.parentElement !== canvasWrap) canvasWrap.appendChild(setupScreen);
    setupScreen.classList.add('in-game-editor');
  }
  setupScreen.hidden = false;
  playScreen.hidden = !isEditing;
  if (animHandle) { cancelAnimationFrame(animHandle); animHandle = null; }
  heldDirections.clear();
  dialogue = null;
  lastFrameAt = null;
  document.querySelector('#cancel-edit').hidden = !isEditing;
  renderSetup();
  setupScreen.querySelector('input')?.focus();
}

function closeCreator() {
  const wasEditing = editing;
  state.creationComplete = true;
  state.player = { x: 14, y: 11 };
  syncPlayerMotion();
  saveState();
  setupSnapshot = null;
  editing = false;
  setupScreen.hidden = true;
  if (wasEditing) setupScreen.classList.remove('in-game-editor');
  playScreen.hidden = false;
  updateHud();
  drawVillage();
  if (!wasEditing) requestPlayFullscreen();
  else startVillageAnimation();
  showToast(`Welcome to ${state.village.name}.`);
}

function cancelCreator() {
  const wasEditing = editing;
  if (setupSnapshot) state = normalizeGameState(setupSnapshot);
  setupSnapshot = null;
  editing = false;
  setupScreen.hidden = true;
  if (wasEditing) setupScreen.classList.remove('in-game-editor');
  playScreen.hidden = false;
  updateHud();
  drawVillage();
  if (!wasEditing) requestPlayFullscreen();
  else startVillageAnimation();
}

// Play in fullscreen by default when the player enters the village.
function requestPlayFullscreen() {
  try {
    if (!document.fullscreenElement && playScreen?.requestFullscreen) playScreen.requestFullscreen();
  } catch {
    /* fullscreen is optional; ignore if the browser blocks it */
  }
  startVillageAnimation();
  updateFullscreenLabel();
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

// blend two #rrggbb colours (game.js-local helper)
function mixHex(a, b, t) {
  const ca = parseInt(a.slice(1), 16);
  const cb = parseInt(b.slice(1), 16);
  const ar = (ca >> 16) & 255, ag = (ca >> 8) & 255, ab = ca & 255;
  const br = (cb >> 16) & 255, bg = (cb >> 8) & 255, bb = cb & 255;
  return `rgb(${Math.round(ar + (br - ar) * t)},${Math.round(ag + (bg - ag) * t)},${Math.round(ab + (bb - ab) * t)})`;
}

// --- Pixel grid helpers ----------------------------------------------------

function tileRects(x, y, tile, theme, village) {
  const px = x * TILE;
  const py = y * TILE;
  const base = tile === 'w' ? theme.water : tile === 'p' ? theme.path : tile === 'd' ? theme.dirt : tile === 's' ? theme.sky : tile === 'h' ? theme.distant : theme.grass;
  const rects = [[px, py, TILE, TILE, base]];
  if (tile === 's') {
    // a couple of soft clouds
    const c = (x * 13 + y * 7) % 9;
    if (c === 2) rects.push([px + 3, py + 5, 9, 3, mixHex(theme.sky, '#ffffff', 0.5)]);
    if (c === 5) rects.push([px + 6, py + 9, 6, 2, mixHex(theme.sky, '#ffffff', 0.4)]);
    return rects;
  }
  if (tile === 'h') {
    // distant hill speckle for texture
    if ((x + y) % 3 === 0) rects.push([px + 4, py + 8, 2, 2, mixHex(theme.distant, theme.grass, 0.4)]);
    return rects;
  }
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

function cameraForPlayer(player, zoom = cameraZoom) {
  const viewW = VIEW_W / zoom;
  const viewH = VIEW_H / zoom;
  const camX = Math.max(0, Math.min(player.x - viewW / 2, WORLD_WIDTH - viewW));
  const camY = Math.max(0, Math.min(player.y - viewH / 2, WORLD_HEIGHT - viewH));
  return { camX, camY, viewW, viewH };
}

function applyCameraZoom(x, y) {
  const centerX = GRID_W / 2;
  const centerY = GRID_H / 2;
  return {
    x: centerX + (x - centerX) * cameraZoom,
    y: centerY + (y - centerY) * cameraZoom
  };
}

function drawWorld(ctx, theme, village, spec, player, cam, time = 0, zoom = cameraZoom) {
  // Render a larger tile window, then scale it around the logical centre. The
  // camera therefore follows fractional player coordinates instead of snapping
  // one whole tile at a time.
  const { camX, camY } = cam;
  const renderViewW = Math.ceil(VIEW_W / zoom) + 2;
  const renderViewH = Math.ceil(VIEW_H / zoom) + 2;
  const baseCamX = Math.floor(camX);
  const baseCamY = Math.floor(camY);
  // ground tiles within the viewport window
  for (let sy = 0; sy < renderViewH; sy += 1) {
    const wy = baseCamY + sy;
    if (wy <= 0 || wy >= WORLD_HEIGHT - 1) continue;
    for (let sx = 0; sx < renderViewW; sx += 1) {
      const wx = baseCamX + sx;
      if (wx <= 0 || wx >= WORLD_WIDTH - 1) continue;
      drawPixels(ctx, tileRects(wx - camX, wy - camY, worldGrid[wy][wx], theme, village));
    }
  }
  // tile detail layer: grass tufts, pebbles, small flowers for texture
  for (let sy = 0; sy < renderViewH; sy += 1) {
    const wy = baseCamY + sy;
    if (wy <= 0 || wy >= WORLD_HEIGHT - 1) continue;
    for (let sx = 0; sx < renderViewW; sx += 1) {
      const wx = baseCamX + sx;
      if (wx <= 0 || wx >= WORLD_WIDTH - 1) continue;
      const tile = worldGrid[wy][wx];
      if (tile === 'g' || tile === 'p' || tile === 'd') drawTileDetail(ctx, wx - camX, wy - camY, wx, wy, theme, tile);
      if (tile === 'g' || tile === 'p' || tile === 'd' || tile === 'w') {
        drawTerrainDetail(ctx, theme, tile, (wx - camX) * TILE, (wy - camY) * TILE, wx * 31 + wy * 17, time);
      }
    }
  }

  const worldToScreen = (wx, wy) => {
    const position = worldPixelPosition(wx, wy, camX, camY, TILE);
    return { sx: position.x, sy: position.y };
  };

  // Large authored anchors establish readable destinations in the expanded map.
  for (const landmark of WORLD_LANDMARKS) {
    const { sx, sy } = worldToScreen(landmark.x, landmark.y);
    const width = landmark.w * TILE;
    const height = landmark.h * TILE;
    if (sx < -width || sy < -height || sx > GRID_W || sy > GRID_H) continue;
    drawWorldLandmark(ctx, theme, landmark.type, sx, sy, width, height, time);
  }

  // building floor shadows (drawn before the buildings)
  for (const b of BUILDINGS) {
    const { sx, sy } = worldToScreen(b.x, b.y);
    if (sx < -80 || sy < -80 || sx > GRID_W || sy > GRID_H) continue;
    drawBuildingShadow(ctx, sx, sy, b.w * TILE, b.h * TILE);
  }

  // buildings
  for (const b of BUILDINGS) {
    const { sx, sy } = worldToScreen(b.x, b.y);
    if (sx < -80 || sy < -80 || sx > GRID_W || sy > GRID_H) continue;
    drawBuildingSprite(ctx, b.type, sx, sy, theme, time);
    drawBuildingDetail(ctx, b.type, sx, sy, theme, time);
  }

  // garden, pond, bridge, noticeboard, gate props near the starting area
  const garden = worldToScreen(5, 9); drawSoftShadow(ctx, garden.sx + 3 * TILE, garden.sy + 3 * TILE, 3.4 * TILE, 5, 0.14); drawGardenSprite(ctx, theme, garden.sx, garden.sy, 7, 3, state.garden.stage);
  const pond = worldToScreen(11, 3); drawPondSprite(ctx, theme, pond.sx, pond.sy, time);
  const bridge = worldToScreen(67, 30); drawBridgeSprite(ctx, theme, bridge.sx, bridge.sy);
  const board = worldToScreen(30, 9); drawSoftShadow(ctx, board.sx + 25, board.sy + 24, 26, 4, 0.18); drawNoticeboardSprite(ctx, board.sx - 6, board.sy - 24);
  const gate = worldToScreen(60, 20); drawGateSprite(ctx, theme, gate.sx, gate.sy);

  // authored settlement dressing: hedges, work clutter, benches, flowerbeds, and lamps
  for (const [index, prop] of COLONY_PROPS.entries()) {
    const { sx, sy } = worldToScreen(prop.x, prop.y);
    if (sx < -40 || sy < -40 || sx > GRID_W + 40 || sy > GRID_H + 40) continue;
    drawColonyProp(ctx, theme, prop.type, sx, sy, index + prop.x * 7 + prop.y * 13, time);
  }

  const homeLabel = worldToScreen(7, 5);
  const gardenLabel = worldToScreen(8, 9);
  const pondLabel = worldToScreen(12, 4);
  const marketLabel = worldToScreen(24, 13);
  drawWorldLabel(ctx, 'Your smial', homeLabel.sx + TILE / 2, homeLabel.sy - 10, '#f0d487');
  drawWorldLabel(ctx, 'Garden beds', gardenLabel.sx + TILE / 2, gardenLabel.sy - 8, '#b8c785');
  drawWorldLabel(ctx, 'Moon pond', pondLabel.sx + TILE / 2, pondLabel.sy - 8, '#b9d9d0');
  drawWorldLabel(ctx, 'Market', marketLabel.sx + TILE / 2, marketLabel.sy - 8, '#e2b96e');
  for (const landmark of WORLD_LANDMARKS) {
    const point = worldToScreen(landmark.x + landmark.w / 2, landmark.y);
    if (point.sx < -80 || point.sy < -24 || point.sx > GRID_W + 80 || point.sy > GRID_H + 24) continue;
    drawWorldLabel(ctx, landmark.label, point.sx, point.sy - 8, landmark.accent);
  }

  // trees in the viewport (with their own shadows inside)
  for (let wy = baseCamY; wy < baseCamY + renderViewH; wy += 1) {
    for (let wx = baseCamX; wx < baseCamX + renderViewW; wx += 1) {
      if (worldGrid[wy] && worldGrid[wy][wx] === 't') {
        const { sx, sy } = worldToScreen(wx, wy);
        drawTreeSprite(ctx, theme, sx, sy, (wx * 7 + wy * 13) % 5);
      }
    }
  }

  // NPCs at their scheduled positions for the current clock
  const lighting = lightingFor(state.clock);
  const focusNpc = nearbyNpc();
  for (const npc of NPCS) {
    const pos = npcMotionAt(npc, state.clock);
    const { sx, sy } = worldToScreen(pos.x, pos.y);
    if (sx < -20 || sy < -30 || sx > GRID_W || sy > GRID_H) continue;
    const feetY = sy + TILE / 2 + 4;
    const isFocused = focusNpc?.id === npc.id;
    if (isFocused) drawSelectionRing(ctx, sx + TILE / 2, feetY, true);
    drawHobbitSprite(ctx, { body: npc.body, hair: npc.hair, palette: npc.palette }, sx + TILE / 2, feetY, false, { moving: true, phase: time / 120 + npc.id.length });
    if (isFocused) drawNameplate(ctx, npc.name, sx + TILE / 2, feetY - 25, true);
    if (lighting.torch) drawTorchGlow(ctx, sx + TILE / 2, feetY - 18, 14, 0.5);
  }

  // player
  const p = worldToScreen(player.x, player.y);
  const playerFeet = p.sy + TILE / 2 + 4;
  drawSelectionRing(ctx, p.sx + TILE / 2, playerFeet, true);
  drawHobbitSprite(ctx, spec, p.sx + TILE / 2, playerFeet, false, player);
  if (lighting.torch) {
    drawTorchGlow(ctx, p.sx + TILE / 2, playerFeet - 16, 20, 0.7);
    // warm lantern glow at building doorways
    for (const b of BUILDINGS) {
      const { sx, sy } = worldToScreen(b.x, b.y);
      if (sx < -40 || sy < -40 || sx > GRID_W || sy > GRID_H) continue;
      drawTorchGlow(ctx, sx + (b.w * TILE) / 2, sy + b.h * TILE - 6, 18, 0.45);
    }
  }

  // depth vignette over the whole frame
  drawVignette(ctx);

  // time-of-day colour wash
  if (lighting.alpha > 0) {
    ctx.fillStyle = lighting.tint;
    ctx.globalAlpha = lighting.alpha;
    ctx.fillRect(0, 0, GRID_W, GRID_H);
    ctx.globalAlpha = 1;
  }
  drawWeatherOverlay(ctx, state.weather, time);
}

function drawTileDetail(ctx, sx, sy, wx, wy, theme, tile) {
  const px = sx * TILE;
  const py = sy * TILE;
  const seed = (wx * 31 + wy * 17) % 11;
  if (tile !== 'd') {
    // grass tufts
    if (seed < 5) drawPixels(ctx, [[px + 3 + (seed % 6), py + 11, 2, 3, theme.grassDark]]);
    if (seed === 7) drawPixels(ctx, [[px + 10, py + 9, 2, 2, theme.grassLight]]);
    if (seed === 9) drawPixels(ctx, [[px + 6, py + 5, 1, 2, '#b8c57e']]);
    if (seed % 4 === 0) drawPixels(ctx, [[px + 12, py + 12, 2, 2, theme.flower ?? '#e29178']]);
  } else {
    // soil clods
    if (seed < 6) drawPixels(ctx, [[px + 4 + (seed % 5), py + 6, 3, 2, '#6b4a39']]);
  }
  if (tile === 'p') {
    if (seed % 3 === 0) drawPixels(ctx, [[px + 3, py + 12, 4, 1, mixPath(theme)]]);
  }
}

function mixPath(theme) {
  return theme.pathLight;
}

function drawInteriorWorld(ctx, time = 0) {
  drawInteriorScene(ctx, state.interior ?? { id: state.location }, time);
  drawHobbitSprite(ctx, state.hobbit, GRID_W / 2, GRID_H - 42, false, playerMotion);
  drawWorldLabel(ctx, state.interior?.title ?? 'Inside', GRID_W / 2, 16, '#f0d487');
}

function drawMinimap() {
  if (!minimapContext || !minimapCanvas) return;
  const ctx = minimapContext;
  const width = minimapCanvas.width;
  const height = minimapCanvas.height;
  const cellW = width / WORLD_WIDTH;
  const cellH = height / WORLD_HEIGHT;
  const theme = themeForVillage();
  const grid = ensureWorldGrid();
  ctx.save();
  ctx.imageSmoothingEnabled = false;
  ctx.clearRect(0, 0, width, height);
  ctx.fillStyle = '#172822';
  ctx.fillRect(0, 0, width, height);
  const colors = {
    g: theme.grass,
    p: theme.path,
    d: theme.dirt,
    w: theme.water,
    t: theme.grassDark,
    b: '#8b6a59',
    f: '#b38a55',
    s: theme.sky,
    h: theme.distant
  };
  for (let y = 0; y < WORLD_HEIGHT; y += 1) {
    for (let x = 0; x < WORLD_WIDTH; x += 1) {
      ctx.fillStyle = colors[grid[y]?.[x]] ?? colors.g;
      ctx.fillRect(Math.floor(x * cellW), Math.floor(y * cellH), Math.ceil(cellW) + 1, Math.ceil(cellH) + 1);
    }
  }
  // landmark plates make the expanded map legible even when zoomed far out.
  for (const landmark of WORLD_LANDMARKS) {
    ctx.fillStyle = `${landmark.accent}99`;
    ctx.fillRect(landmark.x * cellW, landmark.y * cellH, landmark.w * cellW, landmark.h * cellH);
    ctx.strokeStyle = landmark.accent;
    ctx.lineWidth = 1;
    ctx.strokeRect(landmark.x * cellW + .5, landmark.y * cellH + .5, landmark.w * cellW - 1, landmark.h * cellH - 1);
  }
  for (const building of BUILDINGS) {
    ctx.fillStyle = building.type === 'gate' ? '#d3ae61' : '#7e5b4f';
    ctx.fillRect(building.x * cellW, building.y * cellH, building.w * cellW, building.h * cellH);
  }
  const cam = cameraForPlayer(playerMotion);
  ctx.strokeStyle = '#f5e7bf';
  ctx.globalAlpha = .62;
  ctx.lineWidth = 1.5;
  ctx.strokeRect(cam.camX * cellW, cam.camY * cellH, cam.viewW * cellW, cam.viewH * cellH);
  ctx.globalAlpha = 1;
  for (const npc of NPCS) {
    const pos = npcMotionAt(npc, state.clock);
    ctx.fillStyle = '#e29178';
    ctx.beginPath();
    ctx.arc((pos.x + .5) * cellW, (pos.y + .5) * cellH, Math.max(2, cellW * .7), 0, Math.PI * 2);
    ctx.fill();
  }
  const playerX = state.location === 'village' ? playerMotion.x : WORLD_WIDTH / 2;
  const playerY = state.location === 'village' ? playerMotion.y : WORLD_HEIGHT / 2;
  ctx.fillStyle = '#f8df88';
  ctx.strokeStyle = '#24362f';
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo((playerX + .5) * cellW, (playerY - .2) * cellH);
  ctx.lineTo((playerX + 1.05) * cellW, (playerY + .5) * cellH);
  ctx.lineTo((playerX + .5) * cellW, (playerY + 1.2) * cellH);
  ctx.lineTo((playerX - .05) * cellW, (playerY + .5) * cellH);
  ctx.closePath();
  ctx.fill();
  ctx.stroke();
  ctx.fillStyle = '#f7e8c6';
  ctx.font = '700 9px "DM Mono", monospace';
  ctx.fillText('N', width - 13, 12);
  ctx.restore();
}

function drawVillage(time = 0) {
  if (!context || !bufferCtx) return;
  const theme = themeForVillage();
  ensureWorldGrid();
  const cam = cameraForPlayer(playerMotion);
  beginLogicalBuffer();
  bufferCtx.fillStyle = state.location === 'village' ? theme.grass : '#261f25';
  bufferCtx.fillRect(0, 0, GRID_W, GRID_H);
  bufferCtx.save();
  bufferCtx.translate(GRID_W / 2, GRID_H / 2);
  bufferCtx.scale(cameraZoom, cameraZoom);
  bufferCtx.translate(-GRID_W / 2, -GRID_H / 2);
  if (state.location === 'village') drawWorld(bufferCtx, theme, state.village, state.hobbit, playerMotion, cam, time, cameraZoom);
  else drawInteriorWorld(bufferCtx, time);
  bufferCtx.restore();
  endLogicalBuffer();

  context.imageSmoothingEnabled = false;
  context.clearRect(0, 0, canvas.width, canvas.height);
  context.drawImage(buffer, 0, 0, buffer.width, buffer.height, 0, 0, canvas.width, canvas.height);
  drawInteractionPrompt();
  drawDialogueOverlay();
  drawMinimap();
}

// Realtime animation loop: input is held between keydown/keyup events and
// movement is integrated from elapsed time, so motion is continuous.
let animHandle = null;
function directionFromHeldKeys() {
  const direction = { x: 0, y: 0 };
  for (const key of heldDirections) {
    if (key === 'up') direction.y -= 1;
    if (key === 'down') direction.y += 1;
    if (key === 'left') direction.x -= 1;
    if (key === 'right') direction.x += 1;
  }
  return direction;
}

function updateRealtimeMotion(deltaSeconds, now) {
  const direction = dialogue || state.location !== 'village' ? { x: 0, y: 0 } : directionFromHeldKeys();
  const before = { x: playerMotion.x, y: playerMotion.y };
  const next = movePlayerRealtime(playerMotion, direction, deltaSeconds, ensureWorldGrid(), WORLD_BLOCKED, 4.8);
  const moved = Math.hypot(next.x - before.x, next.y - before.y);
  playerMotion = {
    ...playerMotion,
    ...next,
    moving: moved > 0.0001,
    phase: playerMotion.phase + deltaSeconds * (moved > 0.0001 ? 14 : 2)
  };
  if (moved > 0.0001) {
    const dominant = Math.abs(direction.x) > Math.abs(direction.y) ? direction.x : direction.y;
    playerMotion.facing = Math.abs(direction.x) > Math.abs(direction.y) ? (dominant < 0 ? 'left' : 'right') : (dominant < 0 ? 'up' : 'down');
    movementDistance += moved;
    while (movementDistance >= 0.75) {
      state.clock = advanceClock(state.clock, 5);
      movementDistance -= 0.75;
      updateHud();
    }
    persistPlayerMotion();
    if (now - lastPersistAt > 400) {
      saveState();
      lastPersistAt = now;
    }
    if (Date.now() - lastMoveAt > 2500) addNote('Your footsteps make a soft path through the grass.');
    lastMoveAt = Date.now();
    document.querySelector('#canvas-hint').classList.add('is-hidden');
  }
}

function startVillageAnimation() {
  if (animHandle) return;
  const tick = (now) => {
    if (!playScreen || playScreen.hidden) { animHandle = null; return; }
    const deltaSeconds = lastFrameAt == null ? 0 : Math.min(0.12, (now - lastFrameAt) / 1000);
    lastFrameAt = now;
    updateRealtimeMotion(deltaSeconds, now);
    drawVillage(now);
    animHandle = requestAnimationFrame(tick);
  };
  animHandle = requestAnimationFrame(tick);
}

function drawInteractionPrompt() {
  if (!context || dialogue) return;
  const cam = cameraForPlayer(playerMotion);
  const npc = state.location === 'village' ? nearbyNpc() : null;
  const point = state.location === 'village' ? getInteraction(playerMotion, INTERACTIONS) : null;
  let label = null;
  if (state.location !== 'village') label = state.location === 'home' ? 'E · Use the hearth or rest' : 'E · Listen by the window';
  else if (npc) label = `E · Talk to ${npc.name}`;
  else if (point) label = `E · ${point.label}`;
  if (!label) return;
  const cx = (playerMotion.x - cam.camX) * TILE + TILE / 2;
  const cy = (playerMotion.y - cam.camY) * TILE;
  const logical = applyCameraZoom(cx, cy);
  const baseX = (logical.x / GRID_W) * canvas.width;
  const baseY = (logical.y / GRID_H) * canvas.height;
  const scaleX = canvas.width / GRID_W;
  const scaleY = canvas.height / GRID_H;
  context.font = `${Math.round(8 * scaleX)}px "DM Mono", monospace`;
  const textWidth = context.measureText(label).width + 16 * scaleX;
  const px = baseX - textWidth / 2;
  const py = baseY - 25 * scaleY;
  context.fillStyle = 'rgba(36, 54, 47, .28)';
  context.fillRect(px + 3, py + 3, textWidth, 18 * scaleY);
  context.fillStyle = '#24362f';
  context.fillRect(px, py, textWidth, 18 * scaleY);
  context.fillStyle = '#f8e7c4';
  context.textAlign = 'center';
  context.fillText(label, baseX, py + 12 * scaleY);
}

function drawDialogueOverlay() {
  if (!context || !dialogue) return;
  const scaleX = canvas.width / GRID_W;
  const scaleY = canvas.height / GRID_H;
  const panelX = 12 * scaleX;
  const panelY = 198 * scaleY;
  const panelW = (GRID_W - 24) * scaleX;
  const panelH = 78 * scaleY;
  const lines = wrapDialogueText(dialogue.message, 58);
  context.save();
  context.fillStyle = 'rgba(10, 18, 17, .78)';
  context.fillRect(panelX + 5 * scaleX, panelY + 5 * scaleY, panelW, panelH);
  context.fillStyle = '#1c2a26';
  context.fillRect(panelX, panelY, panelW, panelH);
  context.strokeStyle = '#d9b866';
  context.lineWidth = Math.max(2, scaleX);
  context.strokeRect(panelX + scaleX, panelY + scaleY, panelW - 2 * scaleX, panelH - 2 * scaleY);
  context.fillStyle = '#e7c875';
  context.font = `600 ${Math.round(8 * scaleX)}px "DM Mono", monospace`;
  context.textAlign = 'left';
  context.fillText(dialogue.speaker.toUpperCase(), panelX + 12 * scaleX, panelY + 17 * scaleY);
  context.fillStyle = '#f8ecd0';
  context.font = `${Math.round(9 * scaleX)}px Manrope, sans-serif`;
  lines.slice(0, 4).forEach((line, index) => context.fillText(line, panelX + 12 * scaleX, panelY + (35 + index * 13) * scaleY));
  context.fillStyle = '#9fb09f';
  context.font = `${Math.round(6 * scaleX)}px "DM Mono", monospace`;
  context.textAlign = 'right';
  context.fillText('E / SPACE  CLOSE', panelX + panelW - 12 * scaleX, panelY + panelH - 10 * scaleY);
  context.restore();
}

function nearbyNpc() {
  return NPCS.find((npc) => {
    const pos = npcPositionAt(npc, state.clock);
    return Math.hypot(pos.x - playerMotion.x, pos.y - playerMotion.y) <= 1.5;
  }) ?? null;
}

function drawCreatorPreview() {
  if (!creatorContext || !bufferCtx) return;
  const theme = themeForVillage();
  beginLogicalBuffer();
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

  endLogicalBuffer();
  creatorContext.imageSmoothingEnabled = false;
  creatorContext.clearRect(0, 0, creatorCanvas.width, creatorCanvas.height);
  creatorContext.drawImage(buffer, 0, 0, buffer.width, buffer.height, 0, 0, creatorCanvas.width, creatorCanvas.height);
}

function updateHud() {
  const landscapeLabel = LANDSCAPE_LABELS[state.village.landscape];
  document.querySelector('#stage-kicker').textContent = `${state.village.name} · ${landscapeLabel}`;
  document.querySelector('#clock-label').textContent = formatClock(state.clock);
  document.querySelector('#day-label').textContent = `Day ${state.day} · ${state.season}`;
  document.querySelector('#colony-population').textContent = String(NPCS.length + 1);
  document.querySelector('#colony-phase').textContent = timeOfDay(state.clock);
  document.querySelector('#colony-save').textContent = supabaseConfigured ? 'HOSTED' : 'LOCAL';
  document.querySelector('#energy-label').textContent = `${Math.floor(state.energy)} / ${state.maxEnergy}`;
  document.querySelector('#coin-label').textContent = String(state.coins);
  const weatherLabel = WEATHER_LABELS[state.weather] ?? 'Clear';
  const weatherNode = document.querySelector('#weather-label');
  if (weatherNode) weatherNode.textContent = weatherLabel;
  const weatherDot = document.querySelector('#weather-dot');
  if (weatherDot) weatherDot.setAttribute('aria-label', `${weatherLabel} weather`);
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
  const objective = nextOnboardingObjective(state);
  const objectiveLabel = document.querySelector('#objective-label');
  const objectiveHint = document.querySelector('#objective-hint');
  const objectiveCount = document.querySelector('#objective-count');
  const onboardingCount = Object.values(state.onboarding ?? {}).filter(Boolean).length;
  if (objectiveLabel) objectiveLabel.textContent = objective ? objective.label : 'First-day path complete';
  if (objectiveHint) objectiveHint.textContent = objective ? objective.hint : 'The village is yours to shape. Choose what feels good today.';
  if (objectiveCount) objectiveCount.textContent = `${onboardingCount} / 4`;
  const inventoryNode = document.querySelector('#inventory-list');
  if (inventoryNode) {
    const items = Object.entries(state.inventory).filter(([itemId, quantity]) => quantity > 0 && ITEMS[itemId]);
    inventoryNode.innerHTML = items.length ? items.map(([itemId, quantity]) => `<li><span>${escapeHtml(ITEMS[itemId].name)}</span><b>${quantity}</b></li>`).join('') : '<li class="empty"><span>Nothing tucked away yet</span><b>—</b></li>';
  }
  const mealQuantity = Number(state.inventory.pondside_stew ?? 0);
  const eatButton = document.querySelector('#eat-button');
  if (eatButton) {
    eatButton.disabled = mealQuantity < 1;
    eatButton.textContent = mealQuantity > 0 ? `Eat stew · +28 energy (${mealQuantity})` : 'No stew ready yet';
  }
  const gardenStageLabels = { empty: 'Empty bed', sprout: 'Sprout · watered', leaf: 'Leafing · watered', flowering: 'Flowering · growing', ready: 'Ready to harvest' };
  const gardenStatus = gardenStageLabels[state.garden.stage] ?? (state.garden.planted ? 'Growing' : 'Empty bed');
  document.querySelector('#garden-status').textContent = gardenStatus;
  document.querySelector('#activity-status').textContent = state.garden.ready ? 'The moonberries are ready. Return to the garden and press E.' : objective?.hint ?? 'Choose a place to work and press E.';
  const request = state.request;
  const requestLabel = document.querySelector('#request-label');
  const requestCopy = document.querySelector('#request-copy');
  const requestButton = document.querySelector('#request-button');
  const relationshipLabel = document.querySelector('#relationship-label');
  if (request) {
    const relationship = state.relationships?.[request.npcId] ?? 0;
    if (requestLabel) requestLabel.textContent = request.status === 'complete' ? `${request.title} · complete` : request.title;
    if (requestCopy) requestCopy.textContent = request.status === 'complete' ? 'The kindness has been added to the village book.' : request.text;
    if (relationshipLabel) relationshipLabel.textContent = `${request.npcId[0].toUpperCase()}${request.npcId.slice(1)} · ${'♥'.repeat(Math.min(5, Math.ceil(relationship / 2)))}${'♡'.repeat(Math.max(0, 5 - Math.ceil(relationship / 2)))}`;
    if (requestButton) {
      const held = inventoryQuantity(state.inventory, request.itemId);
      requestButton.disabled = request.status === 'complete' || held < request.quantity;
      requestButton.textContent = request.status === 'complete' ? 'Request complete' : held >= request.quantity ? 'Deliver the request' : `Need ${request.quantity} · ${ITEMS[request.itemId]?.shortName ?? request.itemId}`;
    }
  }
  const interiorHud = document.querySelector('#interior-hud');
  const canvasWrap = document.querySelector('.canvas-wrap');
  if (canvasWrap) canvasWrap.classList.toggle('is-interior', state.location !== 'village');
  setBookOpen(bookOpen);
  setHudOpen(hudOpen);
  setMinimapOpen(minimapOpen);
  updateZoomLabel();
  const minimapLocation = document.querySelector('#minimap-location');
  if (minimapLocation) minimapLocation.textContent = state.location === 'village' ? state.village.name : state.interior?.title ?? 'Interior';
  const windowLocation = document.querySelector('#window-hud-location');
  const windowContext = document.querySelector('#window-hud-context');
  if (windowLocation) windowLocation.textContent = state.location === 'village' ? state.village.name : state.interior?.title ?? 'Interior';
  if (windowContext) windowContext.textContent = state.location === 'village' ? (objective?.hint ?? 'The village is yours to shape.') : (state.interior?.subtitle ?? 'A room with a little time to think.');
  const gameMealButton = document.querySelector('#game-meal-button');
  if (gameMealButton) {
    const hasStew = mealQuantity > 0;
    const hasIngredients = inventoryQuantity(state.inventory, 'silver_fish') > 0 && inventoryQuantity(state.inventory, 'moonberry') > 0;
    gameMealButton.disabled = state.location === 'village' ? !hasStew && !hasIngredients : !hasStew && !hasIngredients;
    gameMealButton.textContent = hasStew ? `Satchel · eat stew +28` : hasIngredients ? 'Hearth · cook stew' : 'Satchel · no meal';
  }
  const gameRequestButton = document.querySelector('#game-request-button');
  if (gameRequestButton && request) {
    const held = inventoryQuantity(state.inventory, request.itemId);
    gameRequestButton.disabled = request.status === 'complete' || held < request.quantity;
    gameRequestButton.textContent = request.status === 'complete' ? 'Request · complete' : held >= request.quantity ? 'Request · deliver' : `Request · need ${ITEMS[request.itemId]?.shortName ?? request.itemId}`;
  }
  if (interiorHud) {
    interiorHud.hidden = state.location === 'village';
    if (state.location !== 'village') {
      document.querySelector('#interior-title').textContent = state.interior?.title ?? 'Inside';
      document.querySelector('#interior-subtitle').textContent = state.interior?.subtitle ?? '';
      const interiorAction = document.querySelector('#interior-action');
      if (interiorAction) {
        const canCook = inventoryQuantity(state.inventory, 'silver_fish') > 0 && inventoryQuantity(state.inventory, 'moonberry') > 0;
        const canEat = inventoryQuantity(state.inventory, 'pondside_stew') > 0;
        interiorAction.disabled = state.location === 'home' && !canCook && !canEat;
        interiorAction.textContent = state.location === 'home' ? (canCook ? 'Cook at the hearth' : canEat ? 'Eat by the hearth' : 'No meal ready') : 'Listen by the window';
      }
    }
  }
  document.querySelector('#village-log').innerHTML = state.notes.map((note) => `<li>${escapeHtml(note)}</li>`).join('');
  if (avatarContext && bufferCtx) {
    beginLogicalBuffer();
    drawPixels(bufferCtx, [[0, 0, GRID_W, GRID_H, themeForVillage().paper ?? '#f4e6c8']]);
    // avatar uses the lower portion of the buffer for a head-and-shoulders crop
    drawHobbitSprite(bufferCtx, state.hobbit, GRID_W / 2, GRID_H * 0.92);
    endLogicalBuffer();
    avatarContext.imageSmoothingEnabled = false;
    avatarContext.clearRect(0, 0, avatarCanvas.width, avatarCanvas.height);
    avatarContext.drawImage(buffer, 0, 0, buffer.width, buffer.height, 0, 0, avatarCanvas.width, avatarCanvas.height);
  }
}

function addNote(message) {
  state.notes = [message, ...state.notes].slice(0, 6);
  updateHud();
}

function markOnboardingStep(step) {
  if (!state.onboarding || state.onboarding[step]) return;
  state.onboarding = { ...state.onboarding, [step]: true };
  updateHud();
}

function performMealActivity(activityId, speaker = 'Satchel') {
  const result = performActivity(state, activityId);
  if (!result.ok) {
    showToast(result.message);
    return openDialogue(speaker, result.message);
  }
  state = normalizeGameState({ ...state, ...result.state });
  addNote(result.message);
  persistPlayerMotion();
  saveState();
  openDialogue(speaker, result.message);
}

function eatMeal() {
  performMealActivity('eat');
}

function gameMealAction() {
  if (state.location !== 'village') return useInteriorAction();
  if (inventoryQuantity(state.inventory, 'pondside_stew') > 0) return eatMeal();
  openDialogue('Command deck', 'The hearth is inside your smial. Bring a fish and a moonberry there when you want to cook.');
}

function leaveToLandingPage() {
  window.location.assign('./');
}

function openAccountDialog() {
  const dialog = document.querySelector('#account-dialog');
  if (!dialog) return;
  dialog.hidden = false;
  dialog.querySelector('input')?.focus();
}

function closeAccountDialog() {
  const dialog = document.querySelector('#account-dialog');
  if (!dialog) return;
  dialog.hidden = true;
  document.querySelector('#game-account-button')?.focus();
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

function openDialogue(speaker, message) {
  dialogue = { speaker, message };
  document.querySelector('#canvas-hint')?.classList.add('is-hidden');
  const live = document.querySelector('#dialogue-live');
  if (live) live.textContent = `${speaker}: ${message}`;
  drawVillage(performance.now());
}

function closeDialogue() {
  if (!dialogue) return;
  dialogue = null;
  const live = document.querySelector('#dialogue-live');
  if (live) live.textContent = '';
  drawVillage(performance.now());
}

function deliverRequest() {
  const result = completeRequest(state, state.request?.id);
  if (!result.ok) {
    showToast(result.message);
    return openDialogue('Village book', result.message);
  }
  state = normalizeGameState({ ...state, ...result.state });
  addNote(result.message);
  saveState();
  openDialogue('Village book', result.message);
}

function useInteriorAction() {
  if (state.location === 'home') {
    const canCook = inventoryQuantity(state.inventory, 'silver_fish') > 0 && inventoryQuantity(state.inventory, 'moonberry') > 0;
    if (canCook) return performMealActivity('cook', 'Hearth');
    if (inventoryQuantity(state.inventory, 'pondside_stew') > 0) return performMealActivity('eat', 'Hearth');
    return openDialogue('Hearth', 'The fire is low. Bring a fish and a moonberry, then the pot can do its work.');
  }
  openDialogue('The Golden Perch', 'You sit by the window and hear the village settle around you. Wren has left a warm place at the table.');
}

function leaveInterior() {
  state = normalizeGameState(exitInterior(state));
  heldDirections.clear();
  saveState();
  updateHud();
  drawVillage(performance.now());
  showToast('You step back into the village light.');
}

function performPointActivity(point) {
  if (point.interior) {
    state = normalizeGameState(enterInterior(state, point.interior));
    saveState();
    updateHud();
    drawVillage(performance.now());
    showToast(`You enter ${state.interior.title}.`);
    return;
  }
  const result = performActivity(state, point.activity);
  if (!result.ok) {
    showToast(result.message);
    return openDialogue(point.label, result.message);
  }
  state = normalizeGameState({ ...state, ...result.state });
  if (point.activity === 'garden') markOnboardingStep('garden');
  if (point.activity === 'fish' || point.activity === 'market') markOnboardingStep('outing');
  if (point.activity === 'rest') markOnboardingStep('rest');
  if (point.task) state.tasks[point.task] = true;
  addNote(result.message);
  persistPlayerMotion();
  saveState();
  openDialogue(point.label, result.message);
}

function interact() {
  if (dialogue) return closeDialogue();
  if (state.location !== 'village') return useInteriorAction();
  const npc = nearbyNpc();
  if (npc) {
    const social = recordVillagerTalk(state, npc.id);
    state = normalizeGameState({ ...state, ...social.state, clock: advanceClock(state.clock, 5) });
    const greeting = npcGreetingFor(npc, state.weather);
    const requestLine = state.request?.npcId === npc.id && state.request.status !== 'complete' ? ` ${state.request.text} Press the satchel button when you have it.` : '';
    markOnboardingStep('villager');
    addNote(`${npc.name} says, “${greeting}”`);
    persistPlayerMotion();
    saveState();
    return openDialogue(npc.name, `${greeting}${requestLine}`);
  }
  const point = getInteraction(playerMotion, INTERACTIONS);
  if (!point) return showToast('Nothing here but the evening breeze.');
  if (point.activity || point.interior) return performPointActivity(point);
  state.tasks[point.task] = true;
  state.clock = advanceClock(state.clock, 15);
  addNote(point.message);
  persistPlayerMotion();
  saveState();
  openDialogue('Village note', point.message);
}

function resetDay() {
  state = normalizeGameState({ ...state, ...createDailyState({ day: 3, landscape: state.village.landscape }), player: { x: 14, y: 11 }, clock: 495, day: 3, tasks: { garden: false, pond: false, gate: false, noticeboard: false }, notes: DEFAULT_NOTES });
  syncPlayerMotion();
  dialogue = null;
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
  const label = document.fullscreenElement ? 'Windowed ↙' : 'Fullscreen ↗';
  const headerButton = document.querySelector('#fullscreen-button');
  const gameButton = document.querySelector('#game-fullscreen-button');
  if (headerButton) headerButton.innerHTML = label;
  if (gameButton) gameButton.textContent = label;
}

function hydrateInvite() {
  if (!state.inviteCode) return;
  document.querySelector('#invite-code').textContent = state.inviteCode;
  document.querySelector('#invite-result').hidden = false;
}

function handleKeydown(event) {
  if (setupScreen && !setupScreen.hidden) return;
  const accountDialog = document.querySelector('#account-dialog');
  if (accountDialog && !accountDialog.hidden) {
    if (event.key === 'Escape') { event.preventDefault(); closeAccountDialog(); }
    return;
  }
  if (['INPUT', 'TEXTAREA'].includes(document.activeElement?.tagName)) return;
  const keys = {
    w: 'up', ArrowUp: 'up',
    s: 'down', ArrowDown: 'down',
    a: 'left', ArrowLeft: 'left',
    d: 'right', ArrowRight: 'right'
  };
  const key = event.key.length === 1 ? event.key.toLowerCase() : event.key;
  if (dialogue) {
    if (key === 'e' || event.key === ' ' || key === 'Escape') { event.preventDefault(); closeDialogue(); }
    return;
  }
  if (key === '-' || key === '_') { event.preventDefault(); setCameraZoom(-ZOOM_STEP); return; }
  if (key === '=' || key === '+') { event.preventDefault(); setCameraZoom(ZOOM_STEP); return; }
  if (event.key === 'Tab') { event.preventDefault(); setHudOpen(!hudOpen); return; }
  if (key === 'm') { event.preventDefault(); setMinimapOpen(!minimapOpen); return; }
  if (key === 'b') { event.preventDefault(); setBookOpen(!bookOpen); return; }
  if (keys[key]) { event.preventDefault(); heldDirections.add(keys[key]); }
  if (key === 'e' || event.key === ' ') { event.preventDefault(); interact(); }
  if (key === 'r') resetDay();
}

function handleKeyup(event) {
  const keys = { w: 'up', s: 'down', a: 'left', d: 'right', ArrowUp: 'up', ArrowDown: 'down', ArrowLeft: 'left', ArrowRight: 'right' };
  const key = event.key.length === 1 ? event.key.toLowerCase() : event.key;
  if (keys[key]) heldDirections.delete(keys[key]);
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
document.querySelector('#eat-button')?.addEventListener('click', eatMeal);
document.querySelector('#request-button')?.addEventListener('click', deliverRequest);
document.querySelector('#interior-action')?.addEventListener('click', useInteriorAction);
document.querySelector('#leave-interior')?.addEventListener('click', leaveInterior);
document.querySelector('#game-interact-button')?.addEventListener('click', interact);
document.querySelector('#game-fullscreen-button')?.addEventListener('click', toggleFullscreen);
document.querySelector('#game-account-button')?.addEventListener('click', openAccountDialog);
document.querySelector('#game-hud-toggle')?.addEventListener('click', () => setHudOpen(!hudOpen));
document.querySelector('#game-hud-reopen')?.addEventListener('click', () => setHudOpen(true));
document.querySelector('#game-minimap-toggle')?.addEventListener('click', () => setMinimapOpen(!minimapOpen));
document.querySelector('#minimap-close')?.addEventListener('click', () => setMinimapOpen(false));
document.querySelector('#minimap-reopen')?.addEventListener('click', () => setMinimapOpen(true));
document.querySelector('#game-book-toggle')?.addEventListener('click', () => setBookOpen(!bookOpen));
document.querySelector('#game-book-close')?.addEventListener('click', () => setBookOpen(false));
document.querySelector('#game-zoom-out')?.addEventListener('click', () => setCameraZoom(-ZOOM_STEP));
document.querySelector('#game-zoom-in')?.addEventListener('click', () => setCameraZoom(ZOOM_STEP));
document.querySelector('#game-leave-button')?.addEventListener('click', leaveToLandingPage);
document.querySelector('#game-meal-button')?.addEventListener('click', gameMealAction);
document.querySelector('#game-request-button')?.addEventListener('click', deliverRequest);
document.querySelector('#copy-code').addEventListener('click', copyInvite);
document.querySelector('#sign-in-button').addEventListener('click', sendMagicLink);
document.querySelector('#fullscreen-button')?.addEventListener('click', toggleFullscreen);
document.querySelector('#account-button').addEventListener('click', openAccountDialog);
document.querySelector('#account-close').addEventListener('click', closeAccountDialog);
document.querySelector('#account-cancel').addEventListener('click', closeAccountDialog);
document.querySelector('#account-dialog').addEventListener('click', (event) => { if (event.target === event.currentTarget) closeAccountDialog(); });
document.addEventListener('keydown', handleKeydown);
document.addEventListener('keyup', handleKeyup);
document.addEventListener('visibilitychange', () => { if (document.hidden) heldDirections.clear(); });
document.addEventListener('fullscreenchange', updateFullscreenLabel);

if (!state.creationComplete) openCreator(1, false);
else {
  setupScreen.hidden = true;
  playScreen.hidden = false;
  updateHud();
  hydrateInvite();
  drawVillage();
  requestPlayFullscreen();
}
