import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const html = fs.readFileSync(new URL('../game.html', import.meta.url), 'utf8');

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
});
