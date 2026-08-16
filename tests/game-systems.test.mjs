import test from 'node:test';
import assert from 'node:assert/strict';
import {
  createDefaultGameState,
  createInviteCode,
  formatClock,
  getInteraction,
  isCreationComplete,
  movePlayer,
  normalizeGameState,
  advanceClock,
  movePlayerRealtime,
  npcMotionAt,
  NPCS,
  wrapDialogueText,
  nextOnboardingObjective,
  normalizeOnboarding,
  npcGreetingFor,
  INTERIOR_DEFINITIONS,
  enterInterior,
  exitInterior,
  lightingFor,
  buildWorldGrid,
  START_POSITION,
  WORLD_WIDTH,
  WORLD_HEIGHT,
  SETTLEMENT_ORIGIN
} from '../src/game-systems.js';

const map = [
  'ggggg',
  'ggwgg',
  'ggfgg',
  'ggdgg',
  'ggggg'
];

const blocked = new Set(['w', 'f']);

test('createDefaultGameState includes a named hobbit and village draft', () => {
  const state = createDefaultGameState();
  assert.equal(state.hobbit.name, 'Merryweather');
  assert.equal(state.village.name, 'Moonrise Hollow');
  assert.equal(state.creationComplete, false);
  assert.deepEqual(state.hobbit.palette, {
    skin: '#d9a274',
    hair: '#5b3d32',
    coat: '#6c7f58',
    accent: '#d8a65b'
  });
});

test('normalizeGameState preserves custom choices while filling new defaults', () => {
  const state = normalizeGameState({
    hobbit: { name: 'Pip', hair: 'curls', palette: { coat: '#8e5a4a' } },
    village: { name: 'Fernmere', landscape: 'river' },
    creationComplete: true
  });
  assert.equal(state.hobbit.name, 'Pip');
  assert.equal(state.hobbit.hair, 'curls');
  assert.equal(state.hobbit.palette.coat, '#8e5a4a');
  assert.equal(state.hobbit.palette.skin, '#d9a274');
  assert.equal(state.village.name, 'Fernmere');
  assert.equal(state.village.landscape, 'river');
  assert.equal(state.village.house, 'rounddoor');
  assert.equal(state.creationComplete, true);
});

test('normalizeGameState migrates older saves into the daily loop without overwriting explicit resources', () => {
  const migrated = normalizeGameState({ version: 2, inventory: {}, energy: 42, coins: 5, garden: { planted: true, watered: false, ready: false } });
  assert.equal(migrated.version, 6);
  assert.equal(migrated.energy, 42);
  assert.equal(migrated.coins, 5);
  assert.deepEqual(migrated.inventory, {});
  assert.deepEqual(migrated.garden, { planted: true, watered: false, ready: false, crop: 'moonberry', stage: 'sprout', growthDays: 0 });
  assert.equal(normalizeGameState({ version: 2 }).inventory.seed_packet, 1);
  assert.equal(migrated.season, 'Late Summer');
  assert.ok(['clear', 'mist', 'rain', 'golden-wind'].includes(migrated.weather));
  assert.deepEqual(migrated.onboarding, { garden: false, outing: false, villager: false, rest: false });
});

test('lighting keeps world colours unfiltered until the lighting pass is redesigned', () => {
  for (const clock of [360, 495, 900, 1080, 1380]) {
    assert.equal(lightingFor(clock).alpha, 0, `clock ${clock} should not tint the world`);
  }
});

test('the generated world is huge, varied, deterministic, and starts near its centre', () => {
  const first = buildWorldGrid({ name: 'Moonrise Hollow', landscape: 'heath' });
  const second = buildWorldGrid({ name: 'Moonrise Hollow', landscape: 'heath' });
  assert.equal(first.length, WORLD_HEIGHT);
  assert.equal(first[0].length, WORLD_WIDTH);
  assert.deepEqual(first, second);
  const terrain = new Set(first.flat());
  assert.ok(WORLD_WIDTH >= 200 && WORLD_HEIGHT >= 140);
  assert.ok(['g', 'm', 'r', 't', 'w'].every((tile) => terrain.has(tile)));
  assert.ok(Math.abs(START_POSITION.x - WORLD_WIDTH / 2) < WORLD_WIDTH * 0.12);
  assert.ok(Math.abs(START_POSITION.y - WORLD_HEIGHT / 2) < WORLD_HEIGHT * 0.12);
  assert.equal(first[START_POSITION.y][START_POSITION.x], 'p');
  const legacy = normalizeGameState({ version: 5, player: { x: 14, y: 11 } });
  assert.deepEqual(legacy.player, START_POSITION);
  assert.equal(SETTLEMENT_ORIGIN.x + 14, START_POSITION.x);
});

test('onboarding objective order guides a new player through the first day', () => {
  const state = createDefaultGameState();
  assert.equal(nextOnboardingObjective(state).id, 'garden');
  const progressed = { ...state, onboarding: normalizeOnboarding({ garden: true }) };
  assert.equal(nextOnboardingObjective(progressed).id, 'outing');
  assert.equal(nextOnboardingObjective({ ...progressed, onboarding: { garden: true, outing: true, villager: true, rest: true } }), null);
});

test('weather-aware greetings retain the authored greeting and add a readable response', () => {
  const pim = NPCS.find((npc) => npc.id === 'pim');
  assert.equal(npcGreetingFor(pim, 'clear'), pim.greet);
  assert.notEqual(npcGreetingFor(pim, 'rain'), pim.greet);
  assert.match(npcGreetingFor(pim, 'rain'), /rain/i);
});

test('interior transitions keep the village save and expose authored room details', () => {
  const village = createDefaultGameState();
  const inside = enterInterior(village, 'home');
  assert.equal(inside.location, 'home');
  assert.equal(inside.interior.title, 'Your Smial');
  assert.ok(INTERIOR_DEFINITIONS.home.objects.includes('hearth'));
  const outside = exitInterior(inside);
  assert.equal(outside.location, 'village');
  assert.equal(outside.interior, null);
  assert.deepEqual(outside.village, village.village);
});

test('isCreationComplete requires both a hobbit and village name', () => {
  const state = createDefaultGameState();
  state.hobbit.name = '';
  state.village.name = '';
  assert.equal(isCreationComplete(state), false);
  state.hobbit.name = 'Robin';
  assert.equal(isCreationComplete(state), false);
  state.village.name = 'Thimblebrook';
  assert.equal(isCreationComplete(state), true);
});

test('movePlayer advances onto a walkable tile', () => {
  assert.deepEqual(movePlayer({ x: 1, y: 1 }, { x: 0, y: -1 }, map, blocked), { x: 1, y: 0 });
});

test('movePlayer refuses water and fence tiles', () => {
  assert.deepEqual(movePlayer({ x: 1, y: 1 }, { x: 0, y: 0 }, map, blocked), { x: 1, y: 1 });
  assert.deepEqual(movePlayer({ x: 1, y: 1 }, { x: 1, y: 1 }, map, blocked), { x: 1, y: 1 });
});

test('movePlayer refuses to leave the map', () => {
  assert.deepEqual(movePlayer({ x: 0, y: 0 }, { x: -1, y: 0 }, map, blocked), { x: 0, y: 0 });
});

test('getInteraction returns the closest named point', () => {
  const result = getInteraction({ x: 5, y: 5 }, [
    { x: 6, y: 5, label: 'garden' },
    { x: 9, y: 9, label: 'pond' }
  ], 2);
  assert.equal(result.label, 'garden');
});

test('getInteraction returns null outside its radius', () => {
  assert.equal(getInteraction({ x: 0, y: 0 }, [{ x: 3, y: 3, label: 'pond' }], 2), null);
});

test('createInviteCode emits six uppercase characters', () => {
  const code = createInviteCode(() => 0.123456);
  assert.match(code, /^[A-Z0-9]{6}$/);
  assert.equal(code.length, 6);
});

test('advanceClock wraps cleanly into the next day', () => {
  assert.equal(advanceClock(1435, 10), 5);
});

test('formatClock uses a friendly 12-hour label', () => {
  assert.equal(formatClock(0), '12:00 AM');
  assert.equal(formatClock(735), '12:15 PM');
});

test('realtime movement advances continuously and stops before blocked tiles', () => {
  const open = movePlayerRealtime({ x: 1, y: 0 }, { x: 1, y: 0 }, 0.25, map, blocked, 2);
  assert.ok(open.x > 1 && open.x < 2, 'movement should be fractional, not tile-snapped');
  const blockedResult = movePlayerRealtime({ x: 1.5, y: 1 }, { x: 1, y: 0 }, 1, map, blocked, 4);
  assert.equal(blockedResult.x, 1.5, 'blocked movement should not enter the water tile');
});

test('npc motion interpolates between schedule waypoints during a phase transition', () => {
  const npc = { schedule: { dawn: { x: 2, y: 2 }, day: { x: 8, y: 2 }, dusk: { x: 8, y: 2 }, night: { x: 2, y: 2 } } };
  const moving = npcMotionAt(npc, 310);
  assert.ok(moving.x > 2 && moving.x < 8, 'NPC should be in transit rather than teleporting');
});

test('dialogue wrapping keeps lines within the in-world panel width', () => {
  const lines = wrapDialogueText('The beans are climbing the trellis at last, and the whole garden smells like rain.', 28);
  assert.ok(lines.length >= 2);
  assert.ok(lines.every((line) => line.length <= 28));
});