const INVITE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export const MAP_WIDTH = 32;
export const MAP_HEIGHT = 18;

export const LANDSCAPE_LABELS = { heath: 'Hedgerow', river: 'Riverbend', woodland: 'Deepwood' };
export const HOUSE_LABELS = { rounddoor: 'Round door', stone: 'Stone cottage', gable: 'Gable house' };
export const HAIR_LABELS = { waves: 'Waves', curls: 'Curls', bob: 'Short crop' };

export const INTERACTIONS = [
  { x: 7, y: 12, task: 'garden', label: 'garden beds', message: 'The moonberries are taking. You pinch back a leaf and give the soil a careful drink.' },
  { x: 24, y: 5, task: 'pond', label: 'moon pond', message: 'A silver fish turns under the water. The whole pond keeps the secret with you.' },
  { x: 28, y: 14, task: 'gate', label: 'village gate', message: 'You leave the gate unlatched. A friend should never have to knock twice.' },
  { x: 15, y: 8, task: 'noticeboard', label: 'noticeboard', message: 'The noticeboard has a new note: “Pie tasting at the long table, sunset.”' }
];

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
  version: 2,
  creationComplete: false,
  hobbit: DEFAULT_HOBBIT,
  village: DEFAULT_VILLAGE,
  player: { x: 14, y: 11 },
  clock: 495,
  day: 3,
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
    creationComplete: Boolean(source.creationComplete),
    hobbit: {
      ...DEFAULT_HOBBIT,
      ...hobbit,
      palette: { ...DEFAULT_HOBBIT.palette, ...palette }
    },
    village: { ...DEFAULT_VILLAGE, ...village },
    player: { ...DEFAULT_GAME_STATE.player, ...(source.player ?? {}) },
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

export function resolveVillageTheme(village) {
  const landscape = village?.landscape ?? 'heath';
  const roof = village?.roof === 'plum' ? 'plum' : 'moss';
  const themes = {
    heath: { sky: '#cfe0bf', distant: '#9bb582', grass: '#7a9460', grassLight: '#9bb16e', grassDark: '#4f6b4c', water: '#6fa39b', waterLight: '#a8cfbd', dirt: '#a87555', path: '#d8b783', pathLight: '#eed9a7', roof: roof === 'moss' ? '#4d6347' : '#594753', paper: '#f4e6c8' },
    river: { sky: '#c2d8da', distant: '#7fa3a8', grass: '#5f8b78', grassLight: '#8fae8d', grassDark: '#3f6657', water: '#4f8794', waterLight: '#a6cccc', dirt: '#a97056', path: '#d3bd91', pathLight: '#eee0bc', roof: roof === 'moss' ? '#405d58' : '#55495b', paper: '#eef2ea' },
    woodland: { sky: '#c4cdb1', distant: '#768968', grass: '#5f7d56', grassLight: '#87a068', grassDark: '#385542', water: '#537c7c', waterLight: '#8eb5a5', dirt: '#956d53', path: '#c4ae82', pathLight: '#e4d19c', roof: roof === 'moss' ? '#3d5544' : '#51424e', paper: '#e9ead9' }
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
  { id: 'pim', name: 'Pim Thistledown', x: 9, y: 9, body: 'round', hair: 'waves', palette: { skin: '#d9a274', hair: '#5b3d32', coat: '#6c7f58', accent: '#d8a65b' }, greet: 'Morning! The beans are climbing the trellis at last.' },
  { id: 'wren', name: 'Wren Applewood', x: 28, y: 12, body: 'sturdy', hair: 'curls', palette: { skin: '#e0b48a', hair: '#3f2e26', coat: '#8e5a4a', accent: '#e2b96e' }, greet: 'Welcome to the Perch. Pie is on at sunset, same as always.' },
  { id: 'cedar', name: 'Old Cedar', x: 32, y: 14, body: 'lean', hair: 'bob', palette: { skin: '#c98f63', hair: '#6b5847', coat: '#4a3c4b', accent: '#9bb16e' }, greet: 'Sit a spell. The stars over the water are worth the wait.' },
  { id: 'mossy', name: 'Mossy Greenhill', x: 36, y: 13, body: 'sturdy', hair: 'waves', palette: { skin: '#d9a274', hair: '#4a3326', coat: '#44566b', accent: '#d8a65b' }, greet: 'Need a hinge mended? Leave it by the anvil.' },
  { id: 'daisy', name: 'Daisy Bramble', x: 23, y: 16, body: 'round', hair: 'curls', palette: { skin: '#e6bd95', hair: '#5b3d32', coat: '#b77b3f', accent: '#e29178' }, greet: 'Fresh moonberries, straight from the plot!' }
];

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

