import { createDailyState, normalizeDailyState } from './daily-loop.js';

const INVITE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export const MAP_WIDTH = 32;
export const MAP_HEIGHT = 18;
export const WORLD_WIDTH = 240;
export const WORLD_HEIGHT = 160;
export const SETTLEMENT_ORIGIN = { x: 108, y: 71 };
export const START_POSITION = { x: SETTLEMENT_ORIGIN.x + 14, y: SETTLEMENT_ORIGIN.y + 11 };

export const LANDSCAPE_LABELS = { heath: 'Hedgerow', river: 'Riverbend', woodland: 'Deepwood' };
export const HOUSE_LABELS = { rounddoor: 'Round door', stone: 'Stone cottage', gable: 'Gable house' };
export const HAIR_LABELS = { waves: 'Waves', curls: 'Curls', bob: 'Short crop' };

const LOCAL_INTERACTIONS = [
  { x: 7, y: 8, activity: 'rest', interior: 'home', label: 'your smial', message: 'The hearth is banked and the bed is warm. You can rest here when the day has asked enough of you.' },
  { x: 10, y: 8, activity: 'cook', interior: 'home', label: 'hearth', message: 'The hearth is warm enough for a small meal.' },
  { x: 27, y: 11, interior: 'inn', label: 'Golden Perch', message: 'The inn is warm and Wren has left a place by the window.' },
  { x: 7, y: 12, activity: 'garden', task: 'garden', label: 'garden beds', message: 'The moonberries are taking. You pinch back a leaf and give the soil a careful drink.' },
  { x: 13, y: 7, activity: 'fish', task: 'pond', label: 'moon pond', message: 'A silver fish turns under the water. The whole pond keeps the secret with you.' },
  { x: 24, y: 12, activity: 'market', label: 'market stalls', message: 'Daisy has seed packets laid out beneath the striped awning.' },
  { x: 28, y: 14, task: 'gate', label: 'village gate', message: 'You leave the gate unlatched. A friend should never have to knock twice.' },
  { x: 15, y: 8, task: 'noticeboard', label: 'noticeboard', message: 'The noticeboard has a new note: “Pie tasting at the long table, sunset.”' }
];

const offsetPoint = (point) => ({ ...point, x: point.x + SETTLEMENT_ORIGIN.x, y: point.y + SETTLEMENT_ORIGIN.y });
const offsetSchedule = (schedule) => Object.fromEntries(Object.entries(schedule).map(([phase, point]) => [phase, offsetPoint(point)]));
export const INTERACTIONS = LOCAL_INTERACTIONS.map(offsetPoint);

export const INTERIOR_DEFINITIONS = {
  home: { id: 'home', title: 'Your Smial', subtitle: 'A low room, a warm hearth, and a door you can always close.', palette: 'home', objects: ['hearth', 'table', 'bed', 'satchel'] },
  inn: { id: 'inn', title: 'The Golden Perch', subtitle: 'Warm bread, low conversation, and a table by the window.', palette: 'inn', objects: ['hearth', 'counter', 'table', 'window'] }
};

export function enterInterior(state, interiorId) {
  const interior = INTERIOR_DEFINITIONS[interiorId];
  if (!interior) return state;
  return { ...state, location: interiorId, interior: { ...interior } };
}

export function exitInterior(state) {
  return { ...state, location: 'village', interior: null };
}

export const ONBOARDING_OBJECTIVES = [
  { id: 'garden', label: 'Inspect the garden beds', hint: 'Start close to home: press E at the garden.' },
  { id: 'outing', label: 'Visit the moon pond or market', hint: 'Choose a little outing: fish at the pond or visit the market.' },
  { id: 'villager', label: 'Speak with one villager', hint: 'Look for a resident with a gold ring and press E.' },
  { id: 'rest', label: 'Rest at home', hint: 'Return to your smial and press E when the day is done.' }
];

export function normalizeOnboarding(source = {}) {
  return {
    garden: Boolean(source?.garden),
    outing: Boolean(source?.outing),
    villager: Boolean(source?.villager),
    rest: Boolean(source?.rest)
  };
}

export function nextOnboardingObjective(state = {}) {
  const onboarding = normalizeOnboarding(state.onboarding);
  return ONBOARDING_OBJECTIVES.find((objective) => !onboarding[objective.id]) ?? null;
}

export const DEFAULT_HOBBIT = {
  name: 'Merryweather',
  body: 'round',
  hair: 'waves',
  hairColor: 'chestnut',
  outfit: 'gardener',
  palette: {
    skin: '#d9a274',
    hair: '#5b3d32',
    coat: '#6c7f58',
    accent: '#d8a65b'
  }
};

export const DEFAULT_VILLAGE = {
  name: 'Moonrise Hollow',
  landscape: 'heath',
  house: 'rounddoor',
  path: 'honey',
  roof: 'moss'
};

export const DEFAULT_GAME_STATE = {
  version: 6,
  creationComplete: false,
  hobbit: DEFAULT_HOBBIT,
  village: DEFAULT_VILLAGE,
  player: START_POSITION,
  location: 'village',
  interior: null,
  clock: 495,
  day: 3,
  ...createDailyState(),
  tasks: { garden: false, pond: false, gate: false, noticeboard: false },
  inviteCode: null,
  notes: ['You arrived before the kettle boiled.', 'The hill is quiet. The good kind.']
};

export function createDefaultGameState() {
  return structuredClone(DEFAULT_GAME_STATE);
}

function normalizePlayerPosition(source) {
  const raw = source.player && typeof source.player === 'object' ? source.player : {};
  const x = Number.isFinite(Number(raw.x)) ? Number(raw.x) : START_POSITION.x;
  const y = Number.isFinite(Number(raw.y)) ? Number(raw.y) : START_POSITION.y;
  const isLegacyWorld = Number(source.version ?? 0) < 6;
  return {
    x: Number((isLegacyWorld ? x + SETTLEMENT_ORIGIN.x : x).toFixed(4)),
    y: Number((isLegacyWorld ? y + SETTLEMENT_ORIGIN.y : y).toFixed(4))
  };
}

export function normalizeGameState(input = {}) {
  const source = input && typeof input === 'object' ? input : {};
  const hobbit = source.hobbit && typeof source.hobbit === 'object' ? source.hobbit : {};
  const village = source.village && typeof source.village === 'object' ? source.village : {};
  const palette = hobbit.palette && typeof hobbit.palette === 'object' ? hobbit.palette : {};

  return {
    ...createDefaultGameState(),
    ...source,
    version: 6,
    creationComplete: Boolean(source.creationComplete),
    hobbit: {
      ...DEFAULT_HOBBIT,
      ...hobbit,
      palette: { ...DEFAULT_HOBBIT.palette, ...palette }
    },
    village: { ...DEFAULT_VILLAGE, ...village },
    player: normalizePlayerPosition(source),
    location: source.location === 'home' || source.location === 'inn' ? source.location : 'village',
    interior: source.location === 'home' || source.location === 'inn' ? { ...INTERIOR_DEFINITIONS[source.location] } : null,
    ...normalizeDailyState(source),
    tasks: { ...DEFAULT_GAME_STATE.tasks, ...(source.tasks ?? {}) },
    notes: Array.isArray(source.notes) && source.notes.length ? source.notes.slice(0, 6) : [...DEFAULT_GAME_STATE.notes]
  };
}

export function isCreationComplete(state) {
  const hobbitName = state?.hobbit?.name?.trim?.() ?? '';
  const villageName = state?.village?.name?.trim?.() ?? '';
  return hobbitName.length >= 2 && villageName.length >= 2;
}

export function createInviteCode(random = Math.random) {
  let code = '';
  for (let index = 0; index < 6; index += 1) {
    code += INVITE_ALPHABET[Math.floor(random() * INVITE_ALPHABET.length)];
  }
  return code;
}

export function movePlayer(position, delta, map, blockedTiles = new Set()) {
  const next = { x: position.x + delta.x, y: position.y + delta.y };
  if (next.y < 0 || next.y >= map.length || next.x < 0 || next.x >= map[0].length) {
    return position;
  }
  if (blockedTiles.has(map[next.y][next.x])) {
    return position;
  }
  return next;
}

// Continuous movement in tile coordinates. The player keeps the existing grid
// collision contract, but advances by elapsed time instead of keypress events.
export function movePlayerRealtime(position, direction, deltaSeconds, map, blockedTiles = new Set(), speed = 4.5) {
  const length = Math.hypot(direction.x ?? 0, direction.y ?? 0);
  if (!length || deltaSeconds <= 0) return { ...position };
  const distance = Math.min(deltaSeconds, 0.12) * speed;
  const velocity = { x: (direction.x ?? 0) / length, y: (direction.y ?? 0) / length };
  const canOccupy = (x, y) => {
    const samples = [[x + 0.2, y + 0.2], [x + 0.8, y + 0.2], [x + 0.2, y + 0.8], [x + 0.8, y + 0.8]];
    return samples.every(([sampleX, sampleY]) => {
      const tileX = Math.floor(sampleX);
      const tileY = Math.floor(sampleY);
      return tileY >= 0 && tileY < map.length && tileX >= 0 && tileX < map[0].length && !blockedTiles.has(map[tileY][tileX]);
    });
  };
  let next = { ...position };
  const candidateX = next.x + velocity.x * distance;
  if (canOccupy(candidateX, next.y)) next.x = candidateX;
  const candidateY = next.y + velocity.y * distance;
  if (canOccupy(next.x, candidateY)) next.y = candidateY;
  return { x: Number(next.x.toFixed(4)), y: Number(next.y.toFixed(4)) };
}

export function getInteraction(position, points, radius = 1.5) {
  return points
    .map((point) => ({ ...point, distance: Math.hypot(point.x - position.x, point.y - position.y) }))
    .filter((point) => point.distance <= radius)
    .sort((a, b) => a.distance - b.distance)[0] ?? null;
}

export function advanceClock(clock, minutes = 10) {
  const next = clock + minutes;
  return next >= 24 * 60 ? next - 24 * 60 : next;
}

export function formatClock(clock) {
  const hours = Math.floor(clock / 60);
  const minutes = String(clock % 60).padStart(2, '0');
  const suffix = hours >= 12 ? 'PM' : 'AM';
  const shownHour = hours % 12 || 12;
  return `${shownHour}:${minutes} ${suffix}`;
}

// --- Time of day -----------------------------------------------------------

// Phase from a minutes-since-midnight clock value.
export function timeOfDay(clock) {
  if (clock >= 5 * 60 && clock < 7.5 * 60) return 'dawn';
  if (clock >= 7.5 * 60 && clock < 17 * 60) return 'day';
  if (clock >= 17 * 60 && clock < 20 * 60) return 'dusk';
  return 'night';
}

// Lighting overlay + torch state for a given clock.
export function lightingFor(clock) {
  const phase = timeOfDay(clock);
  const table = {
    dawn: { tint: null, alpha: 0, torch: false },
    day: { tint: null, alpha: 0, torch: false },
    dusk: { tint: null, alpha: 0, torch: true },
    night: { tint: null, alpha: 0, torch: true }
  };
  return { phase, ...table[phase] };
}

export function resolveVillageTheme(village) {
  const landscape = village?.landscape ?? 'heath';
  const roof = village?.roof === 'plum' ? 'plum' : 'moss';
  const themes = {
    heath: { sky: '#a8d8df', distant: '#6fa574', grass: '#5e994f', grassMid: '#7eaf57', grassLight: '#add565', grassDark: '#2f6844', grassShade: '#3f7d43', moss: '#789c52', mossLight: '#a8c96a', rock: '#827c68', rockLight: '#b3a987', flower: '#e29178', water: '#3d9daa', waterLight: '#b6ead2', dirt: '#ad6848', path: '#dfb25e', pathLight: '#f6d98c', roof: roof === 'moss' ? '#356744' : '#68445f', paper: '#f7e8c6' },
    river: { sky: '#91cfe0', distant: '#6097a1', grass: '#4f9679', grassMid: '#70ad78', grassLight: '#91c86d', grassDark: '#286450', grassShade: '#3b7d64', flower: '#eaa27d', water: '#348eac', waterLight: '#a9e7dd', dirt: '#ad6848', path: '#dbbe78', pathLight: '#f3e0a7', roof: roof === 'moss' ? '#2e625c' : '#654c68', paper: '#eef5e8' },
    woodland: { sky: '#a8cba8', distant: '#5f8f65', grass: '#4b8b4d', grassMid: '#6eaa52', grassLight: '#94c75f', grassDark: '#285d3c', grassShade: '#3c763e', flower: '#d88d8d', water: '#3d8498', waterLight: '#9bd8b7', dirt: '#9c654c', path: '#d0ad68', pathLight: '#ecd28d', roof: roof === 'moss' ? '#2f5c42' : '#60465d', paper: '#edf0d4' }
  };
  return themes[landscape] ?? themes.heath;
}

export function tileAt(x, y, village) {
  const landscape = village?.landscape ?? 'heath';
  if (x < 1 || y < 1 || x >= MAP_WIDTH - 1 || y >= MAP_HEIGHT - 1) return 't';
  if (landscape === 'river' && x >= 23 && x <= 25 && y >= 2 && y <= 13 && y !== 8) return 'w';
  if (landscape === 'woodland' && x >= 22 && x <= 26 && y >= 3 && y <= 6) return 'w';
  if ((y === 8 && x >= 2 && x <= 28) || (x === 15 && y >= 8 && y <= 15) || (y === 14 && x >= 24 && x <= 29)) return 'p';
  if (x >= 4 && x <= 10 && y >= 11 && y <= 13) return 'd';
  if (x === 27 && y >= 12 && y <= 15) return 'f';
  const treeSpots = new Set(['3,3', '4,3', '5,2', '28,3', '29,4', '30,5', '2,14', '3,15', '5,16', '25,15', '26,16', '29,16', '18,17', '20,16']);
  return treeSpots.has(`${x},${y}`) ? 't' : 'g';
}

// --- Expanded explorable world ---------------------------------------------

export const VIEW_W = MAP_WIDTH;
export const VIEW_H = MAP_HEIGHT;

export const WORLD_LANDMARKS = [
  { id: 'apple-orchard', type: 'orchard', x: 32, y: 22, w: 18, h: 13, label: 'Apple Orchard', accent: '#e5bd6b' },
  { id: 'willowmere', type: 'willowmere', x: 190, y: 20, w: 21, h: 16, label: 'Willowmere', accent: '#a8d8c3' },
  { id: 'stonecutters-hollow', type: 'quarry', x: 182, y: 112, w: 23, h: 16, label: 'Stonecutter’s Hollow', accent: '#d6c39d' },
  { id: 'west-lookout', type: 'lookout', x: 25, y: 116, w: 18, h: 14, label: 'West Lookout', accent: '#d4ad63' }
];

// Convert a world tile coordinate to logical-pixel screen coordinates once.
export function worldPixelPosition(wx, wy, camX, camY, tileSize = 16) {
  return { x: (wx - camX) * tileSize, y: (wy - camY) * tileSize };
}

const LOCAL_BUILDINGS = [
  { id: 'home', type: 'smial', x: 5, y: 5, w: 4, h: 3, name: 'Your Smial' },
  { id: 'barn', type: 'barn', x: 10, y: 15, w: 4, h: 3, name: 'The Barn' },
  { id: 'market', type: 'market', x: 22, y: 13, w: 4, h: 3, name: 'Market Stalls' },
  { id: 'inn', type: 'inn', x: 27, y: 7, w: 5, h: 4, name: 'The Golden Perch' },
  { id: 'smithy', type: 'smithy', x: 35, y: 10, w: 4, h: 3, name: 'The Forge' },
  { id: 'library', type: 'library', x: 39, y: 16, w: 4, h: 3, name: 'The Library' },
  { id: 'well', type: 'well', x: 30, y: 13, w: 1, h: 1, name: 'The Well' },
  { id: 'gate', type: 'gate', x: 60, y: 20, w: 1, h: 2, name: 'The Gate' }
];

export const BUILDINGS = LOCAL_BUILDINGS.map((building) => ({
  ...building,
  x: building.x + SETTLEMENT_ORIGIN.x,
  y: building.y + SETTLEMENT_ORIGIN.y
}));

const LOCAL_NPCS = [
  {
    id: 'pim', name: 'Pim Thistledown',
    x: 9, y: 9, body: 'round', hair: 'waves',
    palette: { skin: '#d9a274', hair: '#5b3d32', coat: '#6c7f58', accent: '#d8a65b' },
    greet: 'Morning! The beans are climbing the trellis at last.',
    schedule: { dawn: { x: 9, y: 10 }, day: { x: 23, y: 11 }, dusk: { x: 9, y: 9 }, night: { x: 7, y: 8 } }
  },
  {
    id: 'wren', name: 'Wren Applewood',
    x: 28, y: 12, body: 'sturdy', hair: 'curls',
    palette: { skin: '#e0b48a', hair: '#3f2e26', coat: '#8e5a4a', accent: '#e2b96e' },
    greet: 'Welcome to the Perch. Pie is on at sunset, same as always.',
    schedule: { dawn: { x: 28, y: 12 }, day: { x: 29, y: 12 }, dusk: { x: 28, y: 12 }, night: { x: 27, y: 11 } }
  },
  {
    id: 'cedar', name: 'Old Cedar',
    x: 32, y: 14, body: 'lean', hair: 'bob',
    palette: { skin: '#c98f63', hair: '#6b5847', coat: '#4a3c4b', accent: '#9bb16e' },
    greet: 'Sit a spell. The stars over the water are worth the wait.',
    schedule: { dawn: { x: 30, y: 13 }, day: { x: 32, y: 14 }, dusk: { x: 31, y: 14 }, night: { x: 30, y: 13 } }
  },
  {
    id: 'mossy', name: 'Mossy Greenhill',
    x: 36, y: 13, body: 'sturdy', hair: 'waves',
    palette: { skin: '#d9a274', hair: '#4a3326', coat: '#44566b', accent: '#d8a65b' },
    greet: 'Need a hinge mended? Leave it by the anvil.',
    schedule: { dawn: { x: 36, y: 13 }, day: { x: 36, y: 13 }, dusk: { x: 35, y: 13 }, night: { x: 35, y: 12 } }
  },
  {
    id: 'daisy', name: 'Daisy Bramble',
    x: 23, y: 16, body: 'round', hair: 'curls',
    palette: { skin: '#e6bd95', hair: '#5b3d32', coat: '#b77b3f', accent: '#e29178' },
    greet: 'Fresh moonberries, straight from the plot!',
    schedule: { dawn: { x: 23, y: 16 }, day: { x: 23, y: 16 }, dusk: { x: 24, y: 16 }, night: { x: 22, y: 16 } }
  }
];

export const NPCS = LOCAL_NPCS.map((npc) => ({
  ...npc,
  x: npc.x + SETTLEMENT_ORIGIN.x,
  y: npc.y + SETTLEMENT_ORIGIN.y,
  schedule: offsetSchedule(npc.schedule)
}));

export const NPC_WEATHER_GREETINGS = {
  rain: {
    pim: 'The rain is doing good work for the beans. Bring your coat next time!',
    wren: 'A soft rain makes the Perch smell wonderfully of warm bread.'
  },
  mist: {
    cedar: 'The mist keeps the pond quiet. Listen and you can hear the fish turn.'
  },
  'golden-wind': {
    daisy: 'The golden wind is carrying petals across the market. Mind your hat!'
  }
};

export function npcGreetingFor(npc, weather = 'clear') {
  return NPC_WEATHER_GREETINGS[weather]?.[npc.id] ?? npc.greet;
}

// Where an NPC stands at a given clock (snaps to their phase waypoint).
export function npcPositionAt(npc, clock) {
  const phase = timeOfDay(clock);
  return npc.schedule?.[phase] ?? { x: npc.x, y: npc.y };
}

// Render-time waypoint interpolation keeps scheduled villagers from teleporting
// when the village clock crosses dawn, day, dusk, or night.
export function npcMotionAt(npc, clock) {
  const schedule = npc.schedule;
  if (!schedule) return { x: npc.x, y: npc.y };
  const phase = timeOfDay(clock);
  const ranges = { night: [0, 300], dawn: [300, 450], day: [450, 1020], dusk: [1020, 1200] };
  const [start, end] = ranges[phase];
  const nextPhase = { night: 'dawn', dawn: 'day', day: 'dusk', dusk: 'night' }[phase];
  const from = schedule[phase] ?? { x: npc.x, y: npc.y };
  const to = schedule[nextPhase] ?? from;
  const phaseProgress = Math.max(0, Math.min(1, (clock - start) / (end - start)));
  const travelProgress = Math.max(0, Math.min(1, phaseProgress / 0.2));
  return {
    x: Number((from.x + (to.x - from.x) * travelProgress).toFixed(4)),
    y: Number((from.y + (to.y - from.y) * travelProgress).toFixed(4))
  };
}

export function wrapDialogueText(text, maxCharacters = 42) {
  const words = String(text).trim().split(/\s+/).filter(Boolean);
  const lines = [];
  let line = '';
  for (const word of words) {
    const candidate = line ? `${line} ${word}` : word;
    if (line && candidate.length > maxCharacters) {
      lines.push(line);
      line = word;
    } else {
      line = candidate;
    }
  }
  if (line) lines.push(line);
  return lines;
}

function seedFromText(value = '') {
  let seed = 2166136261;
  for (const character of String(value)) {
    seed ^= character.charCodeAt(0);
    seed = Math.imul(seed, 16777619);
  }
  return seed >>> 0;
}

function hash2d(x, y, seed) {
  let value = Math.imul(x ^ seed, 374761393) ^ Math.imul(y + seed, 668265263);
  value = Math.imul(value ^ (value >>> 13), 1274126177);
  return ((value ^ (value >>> 16)) >>> 0) / 4294967295;
}

function smoothNoise(x, y, scale, seed) {
  const gx = Math.floor(x / scale);
  const gy = Math.floor(y / scale);
  const fx = (x / scale) - gx;
  const fy = (y / scale) - gy;
  const fade = (value) => value * value * (3 - 2 * value);
  const sx = fade(fx);
  const sy = fade(fy);
  const a = hash2d(gx, gy, seed);
  const b = hash2d(gx + 1, gy, seed);
  const c = hash2d(gx, gy + 1, seed);
  const d = hash2d(gx + 1, gy + 1, seed);
  return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy;
}

function setWorldCell(grid, x, y, tile) {
  if (x > 0 && y > 5 && x < WORLD_WIDTH - 1 && y < WORLD_HEIGHT - 1) grid[y][x] = tile;
}

function carveEllipse(grid, cx, cy, radiusX, radiusY, tile = 'w') {
  for (let y = Math.floor(cy - radiusY); y <= Math.ceil(cy + radiusY); y += 1) {
    for (let x = Math.floor(cx - radiusX); x <= Math.ceil(cx + radiusX); x += 1) {
      const dx = (x - cx) / radiusX;
      const dy = (y - cy) / radiusY;
      if (dx * dx + dy * dy <= 1 && hash2d(x, y, 91) > 0.12) setWorldCell(grid, x, y, tile);
    }
  }
}

function paintCorridor(grid, startX, startY, endX, endY, width = 1, bridge = false) {
  const distance = Math.max(Math.abs(endX - startX), Math.abs(endY - startY));
  for (let step = 0; step <= distance; step += 1) {
    const t = distance ? step / distance : 0;
    const x = Math.round(startX + (endX - startX) * t);
    const y = Math.round(startY + (endY - startY) * t);
    for (let oy = -width; oy <= width; oy += 1) {
      for (let ox = -width; ox <= width; ox += 1) {
        const current = grid[y + oy]?.[x + ox];
        if (current && (bridge || current !== 'w')) setWorldCell(grid, x + ox, y + oy, 'p');
      }
    }
  }
}

// Returns a deterministic, large world with several low-frequency biomes. The
// settlement remains authored, but everything beyond it grows from the village
// identity so saves get a stable world without shipping a giant map asset.
export function buildWorldGrid(village = {}) {
  const seed = seedFromText(`${village.name ?? 'Moonrise Hollow'}:${village.landscape ?? 'heath'}`);
  const grid = [];
  for (let y = 0; y < WORLD_HEIGHT; y += 1) {
    const row = [];
    for (let x = 0; x < WORLD_WIDTH; x += 1) {
      if (x < 1 || y < 1 || x >= WORLD_WIDTH - 1 || y >= WORLD_HEIGHT - 1) row.push('t');
      else if (y <= 4) row.push('s');
      else if (y === 5) row.push('h');
      else {
        const forest = smoothNoise(x + 18, y - 7, 17, seed + 11);
        const moisture = smoothNoise(x - 23, y + 31, 23, seed + 29);
        const ridge = smoothNoise(x + 61, y + 9, 11, seed + 47);
        if (ridge < 0.16) row.push('r');
        else if (forest > 0.68) row.push('t');
        else if (moisture > 0.76 && forest < 0.54) row.push('w');
        else if (moisture > 0.54 || ridge > 0.71) row.push('m');
        else row.push('g');
      }
    }
    grid.push(row);
  }

  // Large water bodies and a meandering river provide unmistakable landmarks.
  carveEllipse(grid, 44, 38, 17, 12);
  carveEllipse(grid, 198, 39, 20, 14);
  carveEllipse(grid, 192, 124, 15, 10);
  for (let y = 7; y < WORLD_HEIGHT - 7; y += 1) {
    const centre = 176 + Math.round(Math.sin(y / 15) * 6 + Math.sin(y / 31) * 4);
    for (let x = centre - 2; x <= centre + 2; x += 1) setWorldCell(grid, x, y, 'w');
  }

  // Clear and build the central settlement bowl, keeping the player near the
  // true world centre while retaining room on every side for exploration.
  const ox = SETTLEMENT_ORIGIN.x;
  const oy = SETTLEMENT_ORIGIN.y;
  for (let y = oy - 4; y <= oy + 53; y += 1) {
    for (let x = ox - 4; x <= ox + 64; x += 1) setWorldCell(grid, x, y, 'g');
  }
  for (let y = oy + 2; y <= oy + 5; y += 1) for (let x = ox + 11; x <= ox + 14; x += 1) setWorldCell(grid, x, y, 'w');

  // Village paths and outward trails. The long corridors deliberately bridge
  // water crossings so each named destination can be reached on foot.
  paintCorridor(grid, ox + 5, oy + 11, ox + 66, oy + 11, 1);
  paintCorridor(grid, ox + 30, oy + 5, ox + 30, oy + 50, 1);
  paintCorridor(grid, ox + 14, oy + 6, ox + 14, oy + 18, 1);
  paintCorridor(grid, ox + 5, oy + 16, ox + 24, oy + 16, 1);
  paintCorridor(grid, ox + 27, oy + 14, ox + 39, oy + 14, 1);
  paintCorridor(grid, ox + 30, oy + 31, ox + 67, oy + 31, 1, true);
  paintCorridor(grid, ox + 53, oy + 31, ox + 53, oy + 44, 1);
  paintCorridor(grid, ox + 12, oy + 44, ox + 61, oy + 44, 1);
  paintCorridor(grid, ox + 60, oy + 52, ox + 88, oy + 52, 1);
  const trailStart = { x: ox + 31, y: oy + 15 };
  for (const landmark of WORLD_LANDMARKS) {
    paintCorridor(grid, trailStart.x, trailStart.y, landmark.x + Math.floor(landmark.w / 2), landmark.y + Math.floor(landmark.h / 2), 1, true);
  }

  // The home garden and far regions use explicit organic silhouettes on top of
  // the noise field, preventing a lucky seed from erasing the authored anchors.
  for (let y = oy + 9; y <= oy + 11; y += 1) for (let x = ox + 5; x <= ox + 11; x += 1) setWorldCell(grid, x, y, 'd');
  for (let y = 0; y < WORLD_HEIGHT; y += 1) {
    for (let x = 0; x < WORLD_WIDTH; x += 1) {
      if (grid[y][x] === 'w' && x > ox - 4 && x < ox + 64 && y > oy - 4 && y < oy + 53) grid[y][x] = 'g';
    }
  }
  for (const b of BUILDINGS) {
    for (let y = b.y; y < b.y + b.h; y += 1) {
      for (let x = b.x; x < b.x + b.w; x += 1) {
        if (grid[y] && grid[y][x]) grid[y][x] = b.type === 'gate' ? 'g' : 'b';
      }
    }
  }
  return grid;
}

export const WORLD_BLOCKED = new Set(['t', 'w', 'r', 'f', 'b', 's', 'h']);

