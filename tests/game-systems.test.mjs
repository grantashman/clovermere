import test from 'node:test';
import assert from 'node:assert/strict';
import { createInviteCode, getInteraction, movePlayer } from '../src/game-systems.js';

const map = [
  'ggggg',
  'ggwgg',
  'ggfgg',
  'ggdgg',
  'ggggg'
];

const blocked = new Set(['w', 'f']);

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
