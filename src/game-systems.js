const INVITE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

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
