const INVITE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

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
