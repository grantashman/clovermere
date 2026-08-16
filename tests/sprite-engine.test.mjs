import test from 'node:test';
import assert from 'node:assert/strict';
import {
  drawHobbitSprite,
  drawTreeSprite,
  drawBuildingSprite,
  drawBuildingShadow,
  drawHills,
  drawSky,
  drawSoftShadow,
  drawTorchGlow,
  drawVignette,
  waterShimmer,
  getPaletteColor,
  GRID_H,
  GRID_W,
  TILE
} from '../src/sprite-engine.js';
import { createDefaultGameState, normalizeGameState, tileAt, resolveVillageTheme, BUILDINGS, NPCS, buildWorldGrid, WORLD_BLOCKED, WORLD_HEIGHT, WORLD_WIDTH, timeOfDay, lightingFor, npcPositionAt, worldPixelPosition } from '../src/game-systems.js';

let before;

function makeContext(width = GRID_W, height = GRID_H) {
  const ops = [];
  const context = {
    canvas: { width, height },
    imageSmoothingEnabled: true,
    fillStyle: '#000',
    font: '',
    textAlign: '',
    globalAlpha: 1,
    fillRect: (x, y, w, h) => ops.push(['fillRect', Math.round(x), Math.round(y), w, h]),
    beginPath: () => ops.push(['beginPath']),
    ellipse: () => ops.push(['ellipse']),
    arc: () => ops.push(['arc']),
    lineTo: () => ops.push(['lineTo']),
    closePath: () => ops.push(['closePath']),
    fill: () => ops.push(['fill']),
    measureText: (t) => ({ width: t.length * 7 }),
    fillText: () => ops.push(['fillText']),
    clearRect: () => ops.push(['clearRect']),
    save: () => ops.push(['save']),
    restore: () => ops.push(['restore']),
    drawImage: () => ops.push(['drawImage']),
    createLinearGradient: () => ({ addColorStop: () => {} }),
    createRadialGradient: () => ({ addColorStop: () => {} }),
    moveTo: () => ops.push(['moveTo']),
    quadraticCurveTo: () => ops.push(['quadraticCurveTo'])
  };
  return { context, ops };
}

test('logical grid keeps the game map proportion', () => {
  assert.equal(GRID_W / TILE, 32);
  assert.equal(GRID_H / TILE, 18);
});

test('palette resolves named colors and passes hex through', () => {
  assert.equal(getPaletteColor('ink'), '#24362f');
  assert.equal(getPaletteColor('#abcdef'), '#abcdef');
});

test('hobbit sprite renders rects within the logical grid and depends on spec', () => {
  const { context, ops } = makeContext();
  before = ops.length;
  drawHobbitSprite(context, createDefaultGameState().hobbit, 256, 270);
  assert.ok(ops.length > before, 'expected draw operations');
  for (const op of ops) {
    if (op[0] === 'fillRect') {
      const [, x, y] = op;
      assert.ok(x >= -16 && x <= GRID_W + 16, `x ${x} within grid`);
      assert.ok(y >= -16 && y <= GRID_H + 16, `y ${y} within grid`);
    }
  }
});

test('hobbit sprite changes silhouette for different bodies', () => {
  const round = makeContext();
  drawHobbitSprite(round.context, normalizeGameState({ hobbit: { body: 'round' } }).hobbit, 100, 200);
  const lean = makeContext();
  drawHobbitSprite(lean.context, normalizeGameState({ hobbit: { body: 'lean' } }).hobbit, 100, 200);
  assert.notDeepEqual(round.ops, lean.ops, 'body shape should change rendering');
});

test('tree sprite stays within the logical canvas', () => {
  const { context, ops } = makeContext();
  drawTreeSprite(context, resolveVillageTheme({ landscape: 'heath' }), 3 * TILE, 3 * TILE, 0);
  for (const op of ops) {
    if (op[0] === 'fillRect') {
      const [, x, y, w, h] = op;
      assert.ok(x >= -2 && x + w <= GRID_W + 2, `x ${x}..${x + w} within grid`);
      assert.ok(y >= -6 && y + h <= GRID_H + 2, `y ${y}..${y + h} within grid`);
    }
  }
});

test('tileAt blocks water, fence, and borders but allows grass paths', () => {
  const village = { landscape: 'river' };
  assert.equal(tileAt(24, 5, village), 'w');
  assert.equal(tileAt(27, 13, village), 'f');
  assert.equal(tileAt(0, 5, village), 't');
  assert.equal(tileAt(15, 10, village), 'p');
});

test('buildWorldGrid creates a larger explorable map with buildings and paths', () => {
  const grid = buildWorldGrid({ landscape: 'heath' });
  assert.equal(grid.length, WORLD_HEIGHT);
  assert.equal(grid[0].length, WORLD_WIDTH);
  // A building footprint is solid.
  const home = BUILDINGS.find((b) => b.id === 'home');
  assert.equal(grid[home.y][home.x], 'b');
  // The gate stays walkable.
  const gate = BUILDINGS.find((b) => b.id === 'gate');
  assert.equal(grid[gate.y][gate.x], 'g');
  // Paths exist near the centre.
  assert.equal(grid[11][30], 'p');
});

test('world blocked set blocks trees, water, fences, and buildings', () => {
  assert.ok(WORLD_BLOCKED.has('t'));
  assert.ok(WORLD_BLOCKED.has('w'));
  assert.ok(WORLD_BLOCKED.has('b'));
  assert.ok(!WORLD_BLOCKED.has('p'));
  assert.ok(!WORLD_BLOCKED.has('g'));
});

test('NPCs have unique ids, positions, and greetings', () => {
  const ids = new Set(NPCS.map((n) => n.id));
  assert.equal(ids.size, NPCS.length);
  for (const npc of NPCS) {
    assert.ok(typeof npc.greet === 'string' && npc.greet.length > 0);
    assert.ok(npc.palette && npc.palette.coat);
  }
});

test('building sprite paints without error for each type', () => {
  const { context, ops } = makeContext();
  const theme = resolveVillageTheme({ landscape: 'heath' });
  for (const b of BUILDINGS) {
    drawBuildingSprite(context, b.type, 0, 0, theme);
  }
  assert.ok(ops.length > BUILDINGS.length, 'expected building draw operations');
});

test('sky, hills, soft shadow, and vignette paint without error', () => {
  const { context } = makeContext();
  const theme = resolveVillageTheme({ landscape: 'heath' });
  let calls = 0;
  const wrap = (fn) => { fn(context, theme); calls += 1; };
  wrap(drawSky);
  wrap(drawHills);
  drawSoftShadow(context, 50, 60, 12, 3, 0.2); calls += 1;
  drawBuildingShadow(context, 10, 20, 64, 48); calls += 1;
  drawVignette(context); calls += 1;
  assert.ok(calls === 5, 'expected all new visual helpers to run');
});

test('torch glow and water shimmer paint animated effects without error', () => {
  const { context, ops } = makeContext();
  drawTorchGlow(context, 80, 64, 18, 0.7);
  waterShimmer(context, 40, 40, 900);
  assert.ok(ops.some(([name]) => name === 'arc'), 'torch glow should draw a radial shape');
  assert.ok(ops.some(([name]) => name === 'fillRect'), 'water shimmer should draw highlight pixels');
});

test('buildWorldGrid reserves a sky/hill horizon at the north edge', () => {
  const grid = buildWorldGrid({ landscape: 'heath' });
  assert.equal(grid[1][10], 's', 'north row should be open sky');
  assert.equal(grid[3][10], 'h', 'row just below sky should be distant hills');
  assert.equal(grid[5][10], 'g', 'below the hills the ground begins');
  // buildings no longer collide with the horizon band
  const smial = BUILDINGS.find((b) => b.id === 'home');
  assert.ok(smial.y >= 4, 'home sits below the hills band');
});

test('timeOfDay maps the clock to dawn/day/dusk/night phases', () => {
  assert.equal(timeOfDay(6 * 60), 'dawn');
  assert.equal(timeOfDay(12 * 60), 'day');
  assert.equal(timeOfDay(18 * 60), 'dusk');
  assert.equal(timeOfDay(23 * 60), 'night');
  assert.equal(timeOfDay(3 * 60), 'night');
});

test('lightingFor returns a tint and torch state per phase', () => {
  assert.equal(lightingFor(12 * 60).alpha, 0, 'day has no colour wash');
  assert.equal(lightingFor(12 * 60).torch, false, 'day has no torches');
  assert.ok(lightingFor(23 * 60).alpha > 0.3, 'night is strongly tinted');
  assert.equal(lightingFor(19 * 60).torch, true, 'dusk lights the lanterns');
});

test('worldPixelPosition returns logical pixels exactly once', () => {
  assert.deepEqual(worldPixelPosition(14, 10, 0, 1), { x: 224, y: 144 });
  const visible = worldPixelPosition(14, 10, 0, 1);
  assert.ok(visible.x < GRID_W && visible.y < GRID_H, 'spawn remains inside the logical viewport');
});

test('npcPositionAt snaps villagers to their schedule per phase', () => {
  const pim = NPCS.find((n) => n.id === 'pim');
  const day = npcPositionAt(pim, 12 * 60);
  const night = npcPositionAt(pim, 23 * 60);
  assert.deepEqual(day, pim.schedule.day);
  assert.deepEqual(night, pim.schedule.night);
  assert.notDeepEqual(day, night, 'pim moves between day and night');
  for (const npc of NPCS) {
    for (const phase of ['dawn', 'day', 'dusk', 'night']) {
      assert.ok(npc.schedule[phase], `${npc.id} has a ${phase} waypoint`);
      assert.ok(typeof npc.schedule[phase].x === 'number');
    }
  }
});
