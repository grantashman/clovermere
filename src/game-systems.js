import { createDailyState, normalizeDailyState } from './daily-loop.js';

const INVITE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export const MAP_WIDTH = 32;
export const MAP_HEIGHT = 18;

export const LANDSCAPE_LABELS = { heath: 'Hedgerow', river: 'Riverbend', woodland: 'Deepwood' };
export const HOUSE_LABELS = { rounddoor: 'Round door', stone: 'Stone cottage', gable: 'Gable house' };
export const HAIR_LABELS = { waves: 'Waves', curls: 'Curls', bob: 'Short crop' };

export const INTERACTIONS = [
  { x: 7, y: 8, activity: 'rest', label: 'your smial', message: 'The hearth is banked and the bed is warm. You can rest here when the day has asked enough of you.' },
  { x: 10, y: 8, activity: 'cook', label: 'hearth', message: 'The hearth is warm enough for a small meal.' },
  { x: 7, y: 12, activity: 'garden', task: 'garden', label: 'garden beds', message: 'The moonberries are taking. You pinch back a leaf and give the soil a careful drink.' },
  { x: 13, y: 7, activity: 'fish', task: 'pond', label: 'moon pond', message: 'A silver fish turns under the water. The whole pond keeps the secret with you.' },
  { x: 24, y: 12, activity: 'market', label: 'market stalls', message: 'Daisy has seed packets laid out beneath the striped awning.' },
  { x: 28, y: 14, task: 'gate', label: 'village gate', message: 'You leave the gate unlatched. A friend should never have to knock twice.' },
  { x: 15, y: 8, task: 'noticeboard', label: 'noticeboard', message: 'The noticeboard has a new note: “Pie tasting at the long table, sunset.”' }
];

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
  version: 4,
  creationComplete: false,
  hobbit: DEFAULT_HOBBIT,
  village: DEFAULT_VILLAGE,
  player: { x: 14, y: 11 },
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

export function normalizeGameState(input = {}) {
  const source = input && typeof input === 'object' ? input : {};
  const hobbit = source.hobbit && typeof source.hobbit === 'object' ? source.hobbit : {};
  const village = source.village && typeof source.village === 'object' ? source.village : {};
  const palette = hobbit.palette && typeof hobbit.palette === 'object' ? hobbit.palette : {};

  return {
    ...createDefaultGameState(),
    ...source,
    version: 4,
    creationComplete: Boolean(source.creationComplete),
    hobbit: {
      ...DEFAULT_HOBBIT,
      ...hobbit,
      palette: { ...DEFAULT_HOBBIT.palette, ...palette }
    },
    village: { ...DEFAULT_VILLAGE, ...village },
    player: { ...DEFAULT_GAME_STATE.player, ...(source.player ?? {}) },
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
    dawn: { tint: 'rgb(255, 196, 140)', alpha: 0.16, torch: false },
    day: { tint: 'rgb(255, 255, 255)', alpha: 0.0, torch: false },
    dusk: { tint: 'rgb(232, 142, 86)', alpha: 0.26, torch: true },
    night: { tint: 'rgb(40, 58, 96)', alpha: 0.42, torch: true }
  };
  return { phase, ...table[phase] };
}

export function resolveVillageTheme(village) {
  const landscape = village?.landscape ?? 'heath';
  const roof = village?.roof === 'plum' ? 'plum' : 'moss';
  const themes = {
    heath: { sky: '#a8d8df', distant: '#6fa574', grass: '#5e994f', grassLight: '#add565', grassDark: '#2f6844', water: '#3d9daa', waterLight: '#b6ead2', dirt: '#ad6848', path: '#dfb25e', pathLight: '#f6d98c', roof: roof === 'moss' ? '#356744' : '#68445f', paper: '#f7e8c6' },
    river: { sky: '#91cfe0', distant: '#6097a1', grass: '#4f9679', grassLight: '#91c86d', grassDark: '#286450', water: '#348eac', waterLight: '#a9e7dd', dirt: '#ad6848', path: '#dbbe78', pathLight: '#f3e0a7', roof: roof === 'moss' ? '#2e625c' : '#654c68', paper: '#eef5e8' },
    woodland: { sky: '#a8cba8', distant: '#5f8f65', grass: '#4b8b4d', grassLight: '#94c75f', grassDark: '#285d3c', water: '#3d8498', waterLight: '#9bd8b7', dirt: '#9c654c', path: '#d0ad68', pathLight: '#ecd28d', roof: roof === 'moss' ? '#2f5c42' : '#60465d', paper: '#edf0d4' }
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

export const WORLD_WIDTH = 64;
export const WORLD_HEIGHT = 40;
export const VIEW_W = MAP_WIDTH; // 32 tiles visible
export const VIEW_H = MAP_HEIGHT; // 18 tiles visible

// Convert a world tile coordinate to logical-pixel screen coordinates once.
export function worldPixelPosition(wx, wy, camX, camY, tileSize = 16) {
  return { x: (wx - camX) * tileSize, y: (wy - camY) * tileSize };
}

export const BUILDINGS = [
  { id: 'home', type: 'smial', x: 5, y: 5, w: 4, h: 3, name: 'Your Smial' },
  { id: 'barn', type: 'barn', x: 10, y: 15, w: 4, h: 3, name: 'The Barn' },
  { id: 'market', type: 'market', x: 22, y: 13, w: 4, h: 3, name: 'Market Stalls' },
  { id: 'inn', type: 'inn', x: 27, y: 7, w: 5, h: 4, name: 'The Golden Perch' },
  { id: 'smithy', type: 'smithy', x: 35, y: 10, w: 4, h: 3, name: 'The Forge' },
  { id: 'library', type: 'library', x: 39, y: 16, w: 4, h: 3, name: 'The Library' },
  { id: 'well', type: 'well', x: 30, y: 13, w: 1, h: 1, name: 'The Well' },
  { id: 'gate', type: 'gate', x: 60, y: 20, w: 1, h: 2, name: 'The Gate' }
];

export const NPCS = [
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

// Returns a WORLD_HEIGHT × WORLD_WIDTH grid of tile chars. Buildings occupy 'b'.
export function buildWorldGrid(village) {
  const grid = [];
  for (let y = 0; y < WORLD_HEIGHT; y += 1) {
    const row = [];
    for (let x = 0; x < WORLD_WIDTH; x += 1) {
      if (x < 1 || y < 1 || x >= WORLD_WIDTH - 1 || y >= WORLD_HEIGHT - 1) row.push('t');
      else if (y <= 2) row.push('s'); // open sky at the north edge
      else if (y === 3) row.push('h'); // distant hills band
      else row.push('g');
    }
    grid.push(row);
  }

  // River on the east with a bridge crossing (starts below the hills band).
  for (let y = 5; y <= 32; y += 1) {
    for (let x = 45; x <= 47; x += 1) {
      if (y === 18) continue;
      grid[y][x] = 'w';
    }
  }
  for (let x = 45; x <= 47; x += 1) {
    grid[18][x] = 'p';
    grid[17][x] = 'p';
    grid[19][x] = 'p';
  }

  // Central path network.
  const pathCells = [];
  for (let x = 5; x <= 60; x += 1) pathCells.push([x, 11]);
  for (let y = 5; y <= 22; y += 1) pathCells.push([30, y]);
  for (let y = 5; y <= 18; y += 1) pathCells.push([14, y]);
  for (let x = 5; x <= 22; x += 1) pathCells.push([x, 16]);
  for (let x = 27; x <= 39; x += 1) pathCells.push([x, 14]);
  for (const [x, y] of pathCells) {
    if (grid[y] && grid[y][x] && grid[y][x] === 'g') grid[y][x] = 'p';
  }

  // Home garden + pond (pond sits just below the hills band).
  for (let y = 9; y <= 11; y += 1) for (let x = 5; x <= 11; x += 1) if (grid[y][x] === 'g') grid[y][x] = 'd';
  for (let y = 4; y <= 6; y += 1) for (let x = 11; x <= 14; x += 1) grid[y][x] = 'w';

  // Woodland treeline at the south.
  const woods = new Set(['12,34', '14,35', '16,33', '20,36', '24,34', '27,37', '31,35', '35,36', '40,34', '44,35', '48,33', '52,36', '56,34', '8,36', '18,35', '38,34']);
  woods.forEach((cell) => {
    const [x, y] = cell.split(',').map(Number);
    if (grid[y] && grid[y][x]) grid[y][x] = 't';
  });

  // Building footprints block movement.
  for (const b of BUILDINGS) {
    for (let y = b.y; y < b.y + b.h; y += 1) {
      for (let x = b.x; x < b.x + b.w; x += 1) {
        if (grid[y] && grid[y][x]) grid[y][x] = b.id === 'gate' ? 'g' : 'b';
      }
    }
  }
  return grid;
}

export const WORLD_BLOCKED = new Set(['t', 'w', 'f', 'b', 's', 'h']);

