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
  player: { x: 15, y: 14 },
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
