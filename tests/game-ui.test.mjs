import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const html = fs.readFileSync(new URL('../game.html', import.meta.url), 'utf8');
const gameScript = fs.readFileSync(new URL('../src/game.js', import.meta.url), 'utf8');

function elementBody(id) {
  const match = html.match(new RegExp(`<[^>]+id=["']${id}["'][^>]*>[\\s\\S]*?</(?:div|aside|dialog)>`, 'i'));
  return match?.[0] ?? '';
}

test('play controls and web panels are contained by the game window', () => {
  const canvasWrapStart = html.indexOf('<div class="canvas-wrap">');
  const canvasWrapEnd = html.indexOf('</div>\n          <div class="stage-footer">', canvasWrapStart);
  assert.ok(canvasWrapStart >= 0, 'game window should contain a canvas wrapper');
  assert.ok(canvasWrapEnd > canvasWrapStart, 'game window should have a bounded composition');
  const gameWindow = html.slice(canvasWrapStart, canvasWrapEnd);
  for (const id of ['village-sidebar', 'account-dialog', 'toast']) {
    assert.ok(gameWindow.includes(`id="${id}"`), `${id} should be inside the game window`);
    assert.equal((html.match(new RegExp(`id="${id}"`, 'g')) ?? []).length, 1, `${id} should have one live surface`);
  }
  assert.match(gameWindow, /id="game-book-toggle"/, 'the village book needs an in-game toggle');
  assert.match(gameWindow, /id="game-zoom-in"/, 'the game window needs zoom controls');
  assert.match(gameWindow, /id="game-zoom-out"/, 'the game window needs zoom controls');
  assert.match(gameWindow, /role="dialog"/, 'account controls need an in-game dialog surface');
  assert.match(gameWindow, /id="game-window-hud"/, 'the command layer should have one native HUD root');
  assert.match(gameWindow, /id="game-hud-toggle"/, 'the HUD should be collapsible');
  assert.match(gameWindow, /id="game-hud-reopen"/, 'a collapsed HUD should have a reopen affordance');
  assert.match(gameWindow, /id="minimap-shell"/, 'the game window should contain a minimap shell');
  assert.match(gameWindow, /id="minimap-canvas"/, 'the minimap should render to its own canvas');
  assert.match(gameWindow, /id="minimap-close"/, 'the minimap should be closable');
  assert.match(gameWindow, /id="minimap-reopen"/, 'a closed minimap should have a reopen affordance');
});

test('game starts at half zoom and exposes the complete zoom range', () => {
  assert.match(gameScript, /const ZOOM_MIN = 0\.5;/);
  assert.match(gameScript, /const ZOOM_MAX = 2;/);
  assert.match(gameScript, /const DEFAULT_ZOOM = 0\.5;/);
});
