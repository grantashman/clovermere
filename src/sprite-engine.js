// Hobbit Moon · sprite engine
// Renders on a small logical pixel grid and scales up with crisp (nearest-neighbour)
// pixels. All art is original, procedural, and composed from the hobbit/village spec.

export const TILE = 16;
export const GRID_W = 512; // 32 tiles
export const GRID_H = 288; // 18 tiles

const PALETTE = {
  ink: '#24362f',
  cream: '#f8e7c4',
  shadow: '#1f2d28',
  trunk: '#76533e',
  trunkLight: '#8a6447',
  roofWood: '#4a3c4b',
  wall: '#ecd2a4',
  door: '#68484c',
  doorLight: '#7e5b5f',
  window: '#9bc5b1',
  windowLight: '#c6e2d4',
  gold: '#e2b96e',
  goldLight: '#f1d49a',
  flower: '#e29178',
  fence: '#9d704f',
  fenceDark: '#7c5538',
  bushLight: '#a9c689',
  bushDark: '#7c9a63',
  stone: '#c7b9a1',
  stoneDark: '#a6967c',
  plank: '#9a6b4b',
  plankLight: '#d3a56c',
  plankDark: '#b47c54',
  dirt: '#845c48',
  soil: '#6b4a39',
  skin2: '#c98f63'
};

export function getPaletteColor(name) {
  return PALETTE[name] ?? name;
}

// Draw an array of [x, y, w, h, colorKey] rects in logical pixels.
export function drawPixels(ctx, rects, ox = 0, oy = 0) {
  for (const [x, y, w, h, color] of rects) {
    ctx.fillStyle = color.startsWith('#') ? color : getPaletteColor(color);
    ctx.fillRect(ox + x, oy + y, w, h);
  }
}

function rects(...rows) {
  return rows;
}

// --- Hobbit sprite ---------------------------------------------------------
// 16 wide × 26 tall logical pixels, anchored so feet sit at (0, 0).
function hairRects(spec) {
  const color = spec.palette.hair;
  const skin = spec.palette.skin;
  if (spec.hair === 'waves') {
    return rects(
      [2, 1, 12, 3, color],
      [1, 3, 2, 6, color],
      [13, 3, 2, 6, color],
      [3, 0, 10, 2, color],
      [4, 4, 8, 2, skin]
    );
  }
  if (spec.hair === 'curls') {
    return rects(
      [2, 1, 12, 3, color],
      [1, 3, 3, 4, color],
      [12, 3, 3, 4, color],
      [4, 0, 8, 2, color],
      [2, 5, 2, 3, color],
      [12, 5, 2, 3, color],
      [5, 4, 6, 2, skin]
    );
  }
  // bob / short crop
  return rects(
    [2, 1, 12, 3, color],
    [1, 3, 2, 4, color],
    [13, 3, 2, 4, color],
    [4, 0, 8, 2, color],
    [4, 4, 8, 2, skin]
  );
}

export function drawHobbitSprite(ctx, spec, cx, feetY, flip = false) {
  const skin = spec.palette.skin;
  const coat = spec.palette.coat;
  const accent = spec.palette.accent;
  const bodyW = spec.body === 'lean' ? 10 : spec.body === 'sturdy' ? 14 : 12;
  const left = Math.round(cx - bodyW / 2);
  const top = feetY - 26;

  // shadow
  ctx.fillStyle = 'rgba(31, 45, 40, .22)';
  ctx.beginPath();
  ctx.ellipse(cx, feetY + 1, bodyW * 0.7, 3, 0, 0, Math.PI * 2);
  ctx.fill();

  // feet
  drawPixels(ctx, rects([left + 1, feetY - 2, 4, 2, PALETTE.door], [left + bodyW - 5, feetY - 2, 4, 2, PALETTE.door]));
  // body / coat
  drawPixels(ctx, rects([left, top + 12, bodyW, 12, coat]));
  // arms
  drawPixels(ctx, rects([left - 2, top + 14, 2, 7, coat], [left + bodyW, top + 14, 2, 7, coat]));
  // belt
  drawPixels(ctx, rects([left, top + 20, bodyW, 2, accent]));
  // head
  drawPixels(ctx, rects([cx - 5, top, 10, 12, skin], [cx - 6, top + 3, 1, 4, skin], [cx + 5, top + 3, 1, 4, skin]));
  // ears
  drawPixels(ctx, rects([cx - 7, top + 4, 2, 3, skin], [cx + 5, top + 4, 2, 3, skin]));
  // hair
  drawPixels(ctx, hairRects(spec));
  // eyes
  drawPixels(ctx, rects([cx - 3, top + 6, 2, 2, PALETTE.ink], [cx + 1, top + 6, 2, 2, PALETTE.ink]));
  // nose/cheek
  drawPixels(ctx, rects([cx - 1, top + 8, 2, 1, PALETTE.skin2]));

  if (flip) {
    // small tool accent on the side for a walking silhouette
    drawPixels(ctx, rects([left + bodyW + 2, top + 12, 1, 8, accent]));
  }
}

// --- Village parts ---------------------------------------------------------

export function drawHouseSprite(ctx, theme, house, ox, oy) {
  const roof = theme.roof;
  if (house === 'stone') {
    drawPixels(ctx, rects(
      [ox + 6, oy + 18, 52, 30, PALETTE.stone],
      [ox + 6, oy + 18, 52, 4, PALETTE.stoneDark],
      [ox + 20, oy + 2, 24, 18, roof],
      [ox + 22, oy + 6, 5, 12, PALETTE.window],
      [ox + 37, oy + 6, 5, 12, PALETTE.window],
      [ox + 24, oy + 28, 16, 20, PALETTE.door],
      [ox + 30, oy + 34, 3, 3, PALETTE.gold],
      [ox + 10, oy + 46, 44, 4, PALETTE.stoneDark]
    ));
  } else if (house === 'gable') {
    drawPixels(ctx, rects(
      [ox + 4, oy + 20, 56, 28, PALETTE.wall],
      [ox + 4, oy + 20, 56, 4, PALETTE.cream],
      [ox + 18, oy + 4, 28, 18, roof],
      [ox + 10, oy + 10, 6, 10, PALETTE.window],
      [ox + 48, oy + 10, 6, 10, PALETTE.window],
      [ox + 26, oy + 28, 16, 20, PALETTE.door],
      [ox + 32, oy + 34, 3, 3, PALETTE.gold]
    ));
  } else {
    // round door hobbit-hole
    drawPixels(ctx, rects(
      [ox + 2, oy + 16, 60, 32, PALETTE.wall],
      [ox + 2, oy + 16, 60, 4, PALETTE.cream],
      [ox + 8, oy + 2, 48, 16, roof],
      [ox + 14, oy + 10, 36, 8, roof],
      [ox + 22, oy + 24, 20, 24, PALETTE.door],
      [ox + 24, oy + 28, 16, 18, PALETTE.doorLight],
      [ox + 30, oy + 36, 3, 3, PALETTE.gold],
      [ox + 10, oy + 40, 44, 8, PALETTE.door],
      [ox + 12, oy + 48, 40, 4, PALETTE.stoneDark]
    ));
    // round door highlight
    ctx.fillStyle = PALETTE.doorLight;
    ctx.beginPath();
    ctx.arc(ox + 32, oy + 36, 9, Math.PI, 0);
    ctx.lineTo(ox + 41, oy + 48);
    ctx.lineTo(ox + 23, oy + 48);
    ctx.closePath();
    ctx.fill();
  }
  // windows glow
  drawPixels(ctx, rects([ox + 22, oy + 28, 4, 0, PALETTE.windowLight]));
}

export function drawTreeSprite(ctx, theme, ox, oy, seed = 0) {
  const trunkX = ox + 9;
  drawPixels(ctx, rects(
    [trunkX, oy + 22, 6, 16, PALETTE.trunk],
    [trunkX - 1, oy + 38, 8, 3, PALETTE.trunkLight],
    [ox + 2, oy + 6, 22, 20, theme.grassDark],
    [ox + 6, oy + 0, 14, 18, theme.grassDark],
    [ox + 10, oy - 4, 8, 14, theme.grassDark],
    [ox + 4, oy + 5, 7, 7, theme.grassLight],
    [ox + 13, oy + 1, 6, 6, theme.grassLight]
  ));
  // canopy dabs vary by seed
  const dabs = [
    [ox + 2 + (seed % 3), oy + 8, 3, 3, PALETTE.bushLight],
    [ox + 18 - (seed % 4), oy + 12, 3, 3, PALETTE.bushLight]
  ];
  drawPixels(ctx, dabs);
}

export function drawGardenSprite(ctx, theme, ox, oy, cols = 7, rows = 3) {
  drawPixels(ctx, rects([ox - 2, oy - 2, cols * 16 + 4, rows * 16 + 4, PALETTE.soil]));
  for (let r = 0; r < rows; r += 1) {
    for (let c = 0; c < cols; c += 1) {
      const x = ox + c * 16;
      const y = oy + r * 16;
      drawPixels(ctx, rects(
        [x + 4, y + 6, 5, 9, theme.grassLight],
        [x + 1, y + 8, 4, 3, theme.grassLight],
        [x + 9, y + 7, 4, 3, theme.grassLight]
      ));
      if ((r + c) % 2 === 0) drawPixels(ctx, rects([x + 5, y + 1, 3, 3, PALETTE.gold]));
      if ((r + c) % 3 === 0) drawPixels(ctx, rects([x + 8, y + 2, 3, 3, PALETTE.flower]));
    }
  }
}

export function drawNoticeboardSprite(ctx, ox, oy) {
  drawPixels(ctx, rects(
    [ox + 10, oy + 24, 5, 30, PALETTE.trunk],
    [ox + 34, oy + 24, 5, 30, PALETTE.trunk],
    [ox, oy, 50, 30, PALETTE.fence],
    [ox + 4, oy + 4, 42, 22, '#e6c991'],
    [ox + 9, oy + 9, 12, 2, '#b25f52'],
    [ox + 8, oy + 15, 20, 2, '#6c7f58'],
    [ox + 14, oy + 20, 7, 3, PALETTE.gold]
  ));
}

export function drawGateSprite(ctx, theme, ox, oy) {
  drawPixels(ctx, rects(
    [ox - 10, oy - 26, 7, 52, PALETTE.trunk],
    [ox + 34, oy - 26, 7, 52, PALETTE.trunk],
    [ox - 4, oy - 18, 46, 5, theme.pathLight],
    [ox - 4, oy + 2, 46, 5, theme.pathLight],
    [ox + 18, oy - 14, 5, 30, theme.pathLight],
    [ox + 6, oy - 22, 8, 6, PALETTE.fence],
    [ox + 28, oy - 22, 8, 6, PALETTE.fence]
  ));
}

export function drawBridgeSprite(ctx, theme, ox, oy) {
  drawPixels(ctx, rects(
    [ox - 3, oy, 51, 16, PALETTE.plank],
    [ox, oy + 3, 45, 3, PALETTE.plankLight],
    [ox, oy + 9, 45, 3, PALETTE.plankDark],
    [ox - 3, oy - 6, 4, 28, PALETTE.trunk],
    [ox + 44, oy - 6, 4, 28, PALETTE.trunk]
  ));
}

export function drawPondSprite(ctx, theme, ox, oy) {
  drawPixels(ctx, rects(
    [ox + 6, oy + 4, 36, 24, theme.water],
    [ox + 2, oy + 10, 44, 12, theme.water],
    [ox + 10, oy + 9, 14, 3, theme.waterLight],
    [ox + 24, oy + 18, 12, 2, theme.waterLight],
    [ox + 8, oy + 22, 6, 3, theme.waterLight]
  ));
}

// --- Building sprites (LOTR-flavoured, original names) -----------------------

function roofCap(ctx, ox, oy, w, roof) {
  drawPixels(ctx, rects([ox, oy, w, 2, roof]));
}

export function drawBuildingSprite(ctx, type, ox, oy, theme) {
  switch (type) {
    case 'smial': {
      // round-doored hobbit smial, larger footprint
      drawPixels(ctx, rects(
        [ox + 4, oy + 26, 56, 18, PALETTE.wall],
        [ox + 4, oy + 26, 56, 3, PALETTE.cream],
        [ox + 16, oy + 6, 34, 22, theme.roof],
        [ox + 24, oy + 14, 18, 12, theme.roof],
        [ox + 28, oy + 34, 16, 16, PALETTE.door],
        [ox + 30, oy + 38, 12, 10, PALETTE.doorLight],
        [ox + 34, oy + 42, 3, 3, PALETTE.gold],
        [ox + 14, oy + 44, 36, 6, PALETTE.stoneDark]
      ));
      ctx.fillStyle = PALETTE.doorLight;
      ctx.beginPath();
      ctx.arc(ox + 36, oy + 42, 8, Math.PI, 0);
      ctx.lineTo(ox + 44, oy + 52);
      ctx.lineTo(ox + 28, oy + 52);
      ctx.closePath();
      ctx.fill();
      break;
    }
    case 'inn': {
      drawPixels(ctx, rects(
        [ox + 2, oy + 28, 76, 24, PALETTE.wall],
        [ox + 2, oy + 28, 76, 3, PALETTE.cream],
        [ox + 8, oy + 8, 64, 22, theme.roof],
        [ox + 28, oy + 16, 24, 12, theme.roof],
        [ox + 12, oy + 36, 12, 12, PALETTE.window],
        [ox + 56, oy + 36, 12, 12, PALETTE.window],
        [ox + 33, oy + 36, 14, 16, PALETTE.door],
        [ox + 38, oy + 42, 3, 3, PALETTE.gold],
        [ox + 16, oy + 50, 44, 4, PALETTE.stoneDark],
        [ox + 4, oy + 24, 12, 4, PALETTE.gold],
        [ox + 60, oy + 24, 12, 4, PALETTE.gold]
      ));
      break;
    }
    case 'smithy': {
      drawPixels(ctx, rects(
        [ox + 2, oy + 26, 60, 26, PALETTE.stone],
        [ox + 2, oy + 26, 60, 3, PALETTE.stoneDark],
        [ox + 10, oy + 6, 44, 22, '#5b4a3f'],
        [ox + 14, oy + 14, 36, 12, '#5b4a3f'],
        [ox + 24, oy + 34, 16, 18, PALETTE.door],
        [ox + 30, oy + 40, 3, 3, PALETTE.gold],
        [ox + 46, oy + 30, 10, 10, '#3a3a3a'],
        [ox + 49, oy + 33, 4, 4, PALETTE.gold]
      ));
      break;
    }
    case 'market': {
      drawPixels(ctx, rects(
        [ox, oy + 36, 64, 16, PALETTE.plank],
        [ox + 4, oy + 20, 56, 16, PALETTE.plankLight],
        [ox + 8, oy + 8, 48, 12, '#b25f52'],
        [ox + 12, oy + 12, 40, 6, PALETTE.gold],
        [ox + 10, oy + 40, 6, 14, PALETTE.trunk],
        [ox + 48, oy + 40, 6, 14, PALETTE.trunk],
        [ox + 22, oy + 44, 18, 6, PALETTE.cream]
      ));
      break;
    }
    case 'barn': {
      drawPixels(ctx, rects(
        [ox + 2, oy + 24, 60, 28, '#9c5a3c'],
        [ox + 2, oy + 24, 60, 3, '#b87a52'],
        [ox + 12, oy + 6, 40, 20, '#7a4332'],
        [ox + 26, oy + 32, 14, 20, PALETTE.door],
        [ox + 30, oy + 38, 3, 3, PALETTE.gold],
        [ox + 18, oy + 44, 28, 6, '#6b3c2a']
      ));
      break;
    }
    case 'library': {
      drawPixels(ctx, rects(
        [ox + 2, oy + 28, 60, 24, '#7c6f63'],
        [ox + 2, oy + 28, 60, 3, '#9b8d7e'],
        [ox + 8, oy + 8, 48, 22, theme.roof],
        [ox + 12, oy + 36, 10, 12, PALETTE.window],
        [ox + 44, oy + 36, 10, 12, PALETTE.window],
        [ox + 28, oy + 36, 12, 16, PALETTE.door],
        [ox + 32, oy + 42, 3, 3, PALETTE.gold]
      ));
      break;
    }
    case 'well': {
      drawPixels(ctx, rects(
        [ox, oy + 18, 16, 12, PALETTE.stone],
        [ox, oy + 18, 16, 3, PALETTE.stoneDark],
        [ox + 2, oy + 22, 12, 6, theme.water],
        [ox - 2, oy + 2, 4, 18, PALETTE.trunk],
        [ox + 14, oy + 2, 4, 18, PALETTE.trunk],
        [ox - 4, oy, 24, 3, PALETTE.roofWood]
      ));
      break;
    }
    default: {
      drawHouseSprite(ctx, theme, 'rounddoor', ox, oy);
    }
  }
}
