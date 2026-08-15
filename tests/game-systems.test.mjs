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
  advanceClock
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
