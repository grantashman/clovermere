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
  deepShadow: '#1b2925',
  roofShadow: '#35483b',
  roofHighlight: '#b2c785',
  leafMid: '#628052',
  leafBright: '#c3d18f',
  woodDark: '#5b3d32',
  metal: '#8f9b8c',
  linen: '#e9d7af',
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

// Soft elliptical ground shadow (transparent fill on the logical buffer).
export function drawSoftShadow(ctx, cx, feetY, radiusX, radiusY = 3, alpha = 0.22) {
  ctx.fillStyle = `rgba(31, 45, 40, ${alpha})`;
  ctx.beginPath();
  ctx.ellipse(cx, feetY + 1, radiusX, radiusY, 0, 0, Math.PI * 2);
  ctx.fill();
}

// Sky gradient + parallax hill bands drawn behind the world.
export function drawSky(ctx, theme) {
  const grad = ctx.createLinearGradient(0, 0, 0, 80);
  grad.addColorStop(0, theme.sky);
  grad.addColorStop(1, mix(theme.sky, theme.distant, 0.45));
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, GRID_W, 80);
}

export function drawHills(ctx, theme) {
  // two calm parallax bands
  for (let band = 0; band < 2; band += 1) {
    const base = band === 0 ? 58 : 46;
    const shade = band === 0 ? theme.distant : mix(theme.distant, theme.grass, 0.35);
    for (let x = -8; x < GRID_W + 16; x += 24) {
      const h = (band === 0 ? 18 : 26) + ((x * 13 + band * 7) % 12);
      ctx.fillStyle = shade;
      ctx.beginPath();
      ctx.moveTo(x, base + 14);
      ctx.quadraticCurveTo(x + 12, base - h + 14, x + 24, base + 14);
      ctx.lineTo(x + 24, 80);
      ctx.lineTo(x, 80);
      ctx.closePath();
      ctx.fill();
    }
  }
}

// Warm radial glow for lanterns / torches at dusk and night.
export function drawTorchGlow(ctx, cx, cy, radius, intensity = 1) {
  const grad = ctx.createRadialGradient(cx, cy, 1, cx, cy, radius);
  grad.addColorStop(0, `rgba(255, 210, 130, ${0.55 * intensity})`);
  grad.addColorStop(0.4, `rgba(255, 180, 110, ${0.22 * intensity})`);
  grad.addColorStop(1, 'rgba(255, 170, 90, 0)');
  ctx.fillStyle = grad;
  ctx.beginPath();
  ctx.arc(cx, cy, radius, 0, Math.PI * 2);
  ctx.fill();
}

// Animated water shimmer highlight (phase driven by time in ms).
export function waterShimmer(ctx, ox, oy, time) {
  const t = (time / 600) % 4;
  const off = [0, 3, 6, 3][Math.floor(t)];
  drawPixels(ctx, rects(
    [ox + 12 + off, oy + 9, 10, 1, '#ffffff'],
    [ox + 24 - off, oy + 18, 9, 1, '#ffffff'],
    [ox + 8 + off, oy + 22, 5, 1, '#ffffff']
  ));
}

// Deterministic terrain dressing: original rocks, grasses, flowers, bank reeds,
// and path stones make the colony map feel authored without a sprite sheet.
export function drawTerrainDetail(ctx, theme, tile, ox, oy, seed = 0, time = 0) {
  const variant = Math.abs(seed) % 17;
  const grain = Math.abs(seed * 13) % 11;
  if (tile === 'g') {
    // Low-contrast ground planes keep the field from reading as one flat fill.
    drawPixels(ctx, rects(
      [ox + 1 + (grain % 4), oy + 2, 4, 1, mix(theme.grass, theme.grassLight, 0.10)],
      [ox + 10 - (grain % 3), oy + 5, 3, 1, mix(theme.grass, theme.grassDark, 0.10)],
      [ox + 3, oy + 14 - (grain % 3), 6, 1, mix(theme.grass, theme.grassLight, 0.13)]
    ));
    if (variant === 1 || variant === 8 || variant === 14) {
      drawPixels(ctx, rects(
        [ox + 2, oy + 11, 5, 2, PALETTE.trunk],
        [ox + 3, oy + 10, 4, 1, PALETTE.stone],
        [ox + 7, oy + 12, 3, 1, PALETTE.shadow],
        [ox + 1, oy + 13, 2, 1, PALETTE.stoneDark]
      ));
    } else if (variant === 3 || variant === 12 || variant === 16) {
      drawPixels(ctx, rects(
        [ox + 3, oy + 9, 1, 5, theme.grassDark],
        [ox + 6, oy + 7, 2, 7, theme.grassDark],
        [ox + 9, oy + 10, 1, 4, theme.grassLight],
        [ox + 11, oy + 8, 1, 5, theme.grassDark]
      ));
    } else if (variant === 5 || variant === 10) {
      drawPixels(ctx, rects(
        [ox + 4, oy + 10, 2, 2, theme.flower ?? PALETTE.flower],
        [ox + 7, oy + 8, 2, 2, PALETTE.goldLight],
        [ox + 9, oy + 11, 2, 2, theme.flower ?? PALETTE.flower],
        [ox + 6, oy + 12, 5, 1, theme.grassDark]
      ));
    } else if (variant === 9 || variant === 13) {
      drawPixels(ctx, rects(
        [ox + 1, oy + 10, 10, 2, theme.grassDark],
        [ox + 3, oy + 8, 2, 2, theme.grassLight],
        [ox + 8, oy + 7, 2, 3, theme.grassLight],
        [ox + 11, oy + 9, 2, 3, theme.grassDark]
      ));
    }
  } else if (tile === 'p') {
    drawPixels(ctx, rects(
      [ox + 1, oy + 1, 14, 1, mix(theme.path, theme.grassDark, 0.18)],
      [ox + 2 + (grain % 5), oy + 4, 4, 1, theme.pathLight],
      [ox + 9, oy + 10 - (grain % 3), 5, 2, theme.pathLight],
      [ox + 4, oy + 14, 3, 1, mix(theme.path, theme.grassDark, 0.22)]
    ));
  } else if (tile === 'd') {
    drawPixels(ctx, rects(
      [ox + 2, oy + 7, 4, 1, PALETTE.soil],
      [ox + 9, oy + 10, 4, 1, PALETTE.soil],
      [ox + 5, oy + 14, 5, 1, mix(PALETTE.soil, '#3b2b28', 0.22)]
    ));
  } else if (tile === 'w' && variant % 3 === 0) {
    const shimmer = Math.floor(time / 700) % 2;
    drawPixels(ctx, [
      [ox + 2 + shimmer * 5, oy + 4 + (variant % 3) * 3, 5, 1, theme.waterLight],
      [ox + 10 - shimmer * 3, oy + 12, 3, 1, mix(theme.water, theme.waterLight, 0.7)]
    ]);
  }
}

// Amber selection marker used for the controlled colonist and the focused villager.
export function drawSelectionRing(ctx, cx, feetY, active = true) {
  ctx.strokeStyle = active ? '#e1bd64' : 'rgba(219, 228, 182, .42)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.ellipse(cx, feetY + 1, 11, 3, 0, 0, Math.PI * 2);
  ctx.stroke();
}

// Small management-style nameplate; only focused villagers receive one by default.
export function drawNameplate(ctx, label, cx, topY, active = false) {
  ctx.save();
  ctx.font = '7px "DM Mono", monospace';
  ctx.textAlign = 'center';
  const width = Math.max(34, ctx.measureText(label).width + 8);
  ctx.fillStyle = active ? 'rgba(24, 33, 31, .94)' : 'rgba(24, 33, 31, .76)';
  ctx.fillRect(cx - width / 2, topY - 10, width, 10);
  ctx.fillStyle = active ? '#f0d487' : '#d8ded1';
  ctx.fillText(label, cx, topY - 3);
  ctx.restore();
}

export function drawWorldLabel(ctx, label, cx, topY, accent = '#f0d487') {
  ctx.save();
  ctx.font = '6px "DM Mono", monospace';
  ctx.textAlign = 'center';
  const width = Math.max(34, ctx.measureText(label).width + 8);
  ctx.fillStyle = 'rgba(24, 33, 31, .84)';
  ctx.fillRect(cx - width / 2 + 2, topY + 2, width, 10);
  ctx.fillStyle = '#18211f';
  ctx.fillRect(cx - width / 2, topY, width, 10);
  ctx.fillStyle = accent;
  ctx.fillText(label, cx, topY + 7);
  ctx.restore();
}

export function drawWeatherOverlay(ctx, weather = 'clear', time = 0) {
  if (!weather || weather === 'clear') return;
  ctx.save();
  if (weather === 'mist') {
    ctx.globalAlpha = 0.14;
    ctx.fillStyle = '#e6ead6';
    ctx.fillRect(0, 42, GRID_W, GRID_H - 42);
    ctx.globalAlpha = 0.08;
    for (let band = 0; band < 4; band += 1) {
      ctx.fillRect(-20 + ((time / 18 + band * 75) % (GRID_W + 40)), 74 + band * 34, 88, 6);
    }
  } else if (weather === 'rain') {
    ctx.globalAlpha = 0.12;
    ctx.fillStyle = '#6b99a7';
    ctx.fillRect(0, 0, GRID_W, GRID_H);
    ctx.globalAlpha = 0.5;
    ctx.strokeStyle = '#b9d9d0';
    ctx.lineWidth = 1;
    for (let index = 0; index < 28; index += 1) {
      const x = (index * 37 + Math.floor(time / 18)) % (GRID_W + 18) - 9;
      const y = (index * 19) % GRID_H;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x - 3, y + 8);
      ctx.stroke();
    }
  } else if (weather === 'golden-wind') {
    ctx.globalAlpha = 0.22;
    ctx.fillStyle = '#e2b96e';
    ctx.fillRect(0, 0, GRID_W, 20);
    ctx.globalAlpha = 0.9;
    for (let index = 0; index < 16; index += 1) {
      const x = (index * 47 + Math.floor(time / 22)) % (GRID_W + 20) - 10;
      const y = 48 + ((index * 23) % 180);
      drawPixels(ctx, [[x, y, 3, 2, index % 2 ? '#f1d49a' : '#c99a57']]);
    }
  }
  ctx.restore();
}

// subtle darkening at the edges for depth
export function drawVignette(ctx) {
  const grad = ctx.createRadialGradient(GRID_W / 2, GRID_H / 2, GRID_H * 0.35, GRID_W / 2, GRID_H / 2, GRID_H * 0.85);
  grad.addColorStop(0, 'rgba(0,0,0,0)');
  grad.addColorStop(1, 'rgba(20,30,26,0.20)');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, GRID_W, GRID_H);
}

// blend two hex colours
function mix(a, b, t) {
  const ca = parseInt(a.slice(1), 16);
  const cb = parseInt(b.slice(1), 16);
  const ar = (ca >> 16) & 255, ag = (ca >> 8) & 255, ab = ca & 255;
  const br = (cb >> 16) & 255, bg = (cb >> 8) & 255, bb = cb & 255;
  const r = Math.round(ar + (br - ar) * t);
  const g = Math.round(ag + (bg - ag) * t);
  const bl = Math.round(ab + (bb - ab) * t);
  return `rgb(${r},${g},${bl})`;
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

export function drawHobbitSprite(ctx, spec, cx, feetY, flip = false, motion = {}) {
  const skin = spec.palette.skin;
  const coat = spec.palette.coat;
  const accent = spec.palette.accent;
  const bodyW = spec.body === 'lean' ? 10 : spec.body === 'sturdy' ? 14 : 12;
  const phase = Number(motion.phase ?? 0);
  const bob = motion.moving ? Math.round(Math.sin(phase) * 0.8) : 0;
  const animatedFeetY = feetY + bob;
  const left = Math.round(cx - bodyW / 2);
  const top = animatedFeetY - 26;
  const stride = motion.moving ? Math.round(Math.sin(phase) * 1.2) : 0;

  // ground shadow stays planted while the body bobs above it
  drawSoftShadow(ctx, cx, feetY, bodyW * 0.72, 3, 0.24);

  // feet (with sole shading and alternating stride)
  drawPixels(ctx, rects([left + 1 + stride, animatedFeetY - 2, 4, 2, PALETTE.door], [left + bodyW - 5 - stride, animatedFeetY - 2, 4, 2, PALETTE.door], [left + 1 + stride, animatedFeetY, 4, 1, PALETTE.shadow], [left + bodyW - 5 - stride, animatedFeetY, 4, 1, PALETTE.shadow]));
  // body / coat (with a shaded right side for roundness)
  drawPixels(ctx, rects([left, top + 12, bodyW, 12, coat]));
  drawPixels(ctx, rects([left + bodyW - 3, top + 12, 3, 12, mix(coat, '#1f2d28', 0.22)]));
  // arms
  drawPixels(ctx, rects([left - 2, top + 14, 2, 7, coat], [left + bodyW, top + 14, 2, 7, coat]));
  // belt (shadow line above + accent below)
  drawPixels(ctx, rects([left, top + 19, bodyW, 1, mix(coat, '#1f2d28', 0.3)], [left, top + 20, bodyW, 2, accent]));
  // readable work-worn accessories at tiny scale: shoulder strap, satchel, and cuff highlights
  drawPixels(ctx, rects(
    [left + 1, top + 13, 2, 7, mix(coat, '#ffffff', 0.12)],
    [left + bodyW - 2, top + 14, 2, 4, accent],
    [left - 2, top + 19, 3, 4, PALETTE.plank],
    [left + bodyW - 1, top + 22, 2, 2, PALETTE.goldLight]
  ));
  // head
  drawPixels(ctx, rects([cx - 5, top, 10, 12, skin], [cx - 6, top + 3, 1, 4, skin], [cx + 5, top + 3, 1, 4, skin]));
  // head shade on the right cheek
  drawPixels(ctx, rects([cx + 3, top + 7, 2, 4, mix(skin, '#1f2d28', 0.16)]));
  // ears
  drawPixels(ctx, rects([cx - 7, top + 4, 2, 3, skin], [cx + 5, top + 4, 2, 3, skin]));
  // hair is anchored to this character rather than the canvas origin
  drawPixels(ctx, hairRects(spec), left - 2, top);
  // eyes
  drawPixels(ctx, rects([cx - 3, top + 6, 2, 2, PALETTE.ink], [cx + 1, top + 6, 2, 2, PALETTE.ink]));
  // nose/cheek
  drawPixels(ctx, rects([cx - 1, top + 8, 2, 1, PALETTE.skin2]));
  // rim light down the left side
  drawPixels(ctx, rects([left, top + 12, 1, 12, mix(coat, '#ffffff', 0.14)]));

  if (flip) {
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
  // ground shadow
  drawSoftShadow(ctx, ox + 12, oy + 40, 13, 3, 0.2);
  drawPixels(ctx, rects(
    [trunkX, oy + 22, 6, 16, PALETTE.trunk],
    [trunkX - 1, oy + 38, 8, 3, PALETTE.trunkLight],
    [ox + 2, oy + 6, 22, 20, mix(theme.grassDark, '#1f2d28', 0.12)],
    [ox + 6, oy + 0, 14, 18, mix(theme.grassDark, '#1f2d28', 0.12)],
    [ox + 10, oy - 4, 8, 14, mix(theme.grassDark, '#1f2d28', 0.12)],
    [ox + 4, oy + 5, 7, 7, theme.grassLight],
    [ox + 13, oy + 1, 6, 6, theme.grassLight]
  ));
  // canopy dabs vary by seed, with a lit top and shaded underside
  const dabs = [
    [ox + 2 + (seed % 3), oy + 8, 3, 3, PALETTE.bushLight],
    [ox + 18 - (seed % 4), oy + 12, 3, 3, PALETTE.bushLight],
    [ox + 8, oy + 18, 4, 3, mix(theme.grassDark, '#1f2d28', 0.3)]
  ];
  drawPixels(ctx, dabs);
}

export function drawGardenSprite(ctx, theme, ox, oy, cols = 7, rows = 3, stage = 'ready') {
  drawPixels(ctx, rects([ox - 2, oy - 2, cols * 16 + 4, rows * 16 + 4, PALETTE.soil]));
  if (stage === 'empty') return;
  for (let r = 0; r < rows; r += 1) {
    for (let c = 0; c < cols; c += 1) {
      const x = ox + c * 16;
      const y = oy + r * 16;
      if (stage === 'sprout') {
        drawPixels(ctx, rects([x + 7, y + 9, 2, 5, theme.grassLight], [x + 4, y + 10, 4, 2, theme.grassLight], [x + 8, y + 7, 3, 2, PALETTE.gold]));
      } else if (stage === 'leaf') {
        drawPixels(ctx, rects([x + 5, y + 6, 4, 8, theme.grassLight], [x + 9, y + 7, 4, 7, theme.grassLight], [x + 2, y + 9, 5, 3, theme.grassLight], [x + 10, y + 4, 3, 3, PALETTE.leafBright]));
      } else {
        drawPixels(ctx, rects(
          [x + 4, y + 6, 5, 9, theme.grassLight],
          [x + 1, y + 8, 4, 3, theme.grassLight],
          [x + 9, y + 7, 4, 3, theme.grassLight]
        ));
        if ((r + c) % 2 === 0) drawPixels(ctx, rects([x + 5, y + 1, 3, 3, stage === 'flowering' ? PALETTE.gold : PALETTE.goldLight]));
        if ((r + c) % 3 === 0) drawPixels(ctx, rects([x + 8, y + 2, 3, 3, stage === 'flowering' ? PALETTE.flower : '#d6b65f']));
      }
    }
  }
}

export function drawInteriorScene(ctx, interior = {}, time = 0) {
  const inn = interior.id === 'inn' || interior.palette === 'inn';
  const wall = inn ? '#b88761' : '#cfa873';
  const wallLight = inn ? '#d9b27d' : '#e5c997';
  const floor = inn ? '#7b5346' : '#795842';
  const floorLight = inn ? '#a86d51' : '#9a6b4b';
  const trim = inn ? '#4d3940' : '#4a3c4b';
  drawPixels(ctx, rects(
    [0, 0, GRID_W, GRID_H, wall],
    [0, 0, GRID_W, 34, wallLight],
    [0, 34, GRID_W, 5, trim],
    [0, 39, GRID_W, GRID_H - 39, floor],
    [0, 42, GRID_W, 2, floorLight],
    [0, GRID_H - 8, GRID_W, 8, '#3b2b2d']
  ));
  for (let x = 0; x < GRID_W; x += 32) drawPixels(ctx, [[x, 45 + ((x / 32) % 2) * 8, 18, 2, floorLight]]);
  if (inn) {
    drawPixels(ctx, rects([52, 58, 150, 34, PALETTE.plank], [58, 64, 138, 5, PALETTE.plankLight], [62, 76, 24, 12, PALETTE.linen], [174, 76, 16, 12, PALETTE.linen]));
    drawPixels(ctx, rects([360, 28, 76, 8, trim], [368, 36, 60, 30, '#8dc5b7'], [374, 42, 48, 2, '#d8ebd0'], [374, 56, 48, 2, '#d8ebd0']));
  } else {
    drawPixels(ctx, rects([72, 64, 118, 44, PALETTE.plank], [80, 72, 102, 5, PALETTE.plankLight], [88, 88, 86, 8, PALETTE.linen], [372, 68, 58, 20, PALETTE.linen], [378, 88, 46, 12, PALETTE.plank]));
    drawPixels(ctx, rects([362, 98, 70, 10, PALETTE.plank], [372, 88, 50, 12, PALETTE.linen]));
  }
  ctx.fillStyle = '#3b2b2d';
  ctx.beginPath();
  ctx.arc(274, 82, 32, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = '#d17e46';
  ctx.beginPath();
  ctx.arc(274, 82, 22 + Math.round(Math.sin(time / 260) * 2), 0, Math.PI * 2);
  ctx.fill();
  drawPixels(ctx, rects([258, 102, 32, 6, PALETTE.stone], [264, 108, 20, 4, PALETTE.stoneDark], [264, 62, 20, 5, PALETTE.gold], [268, 56, 12, 7, PALETTE.goldLight]));
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

export function drawPondSprite(ctx, theme, ox, oy, time = 0) {
  // Mask the rectangular water tiles first; the authored bank below owns the shoreline.
  ctx.fillStyle = theme.grass;
  ctx.fillRect(ox - 2, oy + 14, 68, 54);
  // An irregular bank replaces the old blue rectangle with a small authored water body.
  ctx.fillStyle = mix(theme.grass, theme.water, 0.42);
  ctx.beginPath();
  ctx.moveTo(ox + 8, oy + 2);
  ctx.quadraticCurveTo(ox + 28, oy - 2, ox + 48, oy + 6);
  ctx.quadraticCurveTo(ox + 56, oy + 20, ox + 48, oy + 42);
  ctx.quadraticCurveTo(ox + 26, oy + 50, ox + 4, oy + 40);
  ctx.quadraticCurveTo(ox - 2, oy + 22, ox + 8, oy + 2);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = theme.water;
  ctx.beginPath();
  ctx.moveTo(ox + 11, oy + 7);
  ctx.quadraticCurveTo(ox + 29, oy + 2, ox + 45, oy + 9);
  ctx.quadraticCurveTo(ox + 51, oy + 21, ox + 44, oy + 36);
  ctx.quadraticCurveTo(ox + 27, oy + 43, ox + 9, oy + 35);
  ctx.quadraticCurveTo(ox + 4, oy + 21, ox + 11, oy + 7);
  ctx.closePath();
  ctx.fill();
  drawPixels(ctx, rects(
    [ox + 10, oy + 7, 8, 2, theme.waterLight],
    [ox + 28, oy + 10, 12, 2, mix(theme.water, theme.waterLight, 0.7)],
    [ox + 17, oy + 22, 7, 1, theme.waterLight],
    [ox + 34, oy + 29, 9, 2, theme.waterLight],
    [ox + 4, oy + 19, 3, 5, theme.grassDark],
    [ox + 48, oy + 15, 3, 6, theme.grassDark],
    [ox + 6, oy + 37, 4, 3, PALETTE.stone],
    [ox + 44, oy + 38, 5, 3, PALETTE.stoneDark]
  ));
  if (time) waterShimmer(ctx, ox + 2, oy + 2, time);
}

// --- Small settlement props -----------------------------------------------

export function drawColonyProp(ctx, theme, type, ox, oy, seed = 0, time = 0) {
  const wobble = Math.abs(seed) % 3;
  if (type === 'hedge') {
    drawSoftShadow(ctx, ox + 12, oy + 14, 14, 3, 0.18);
    drawPixels(ctx, rects(
      [ox + 1, oy + 7, 23, 10, theme.grassDark],
      [ox + 4, oy + 3, 11, 10, PALETTE.leafMid],
      [ox + 13, oy + 1, 9, 12, theme.grassLight],
      [ox + 0, oy + 10, 8, 5, PALETTE.leafMid],
      [ox + 5, oy + 5, 3, 2, PALETTE.leafBright],
      [ox + 16, oy + 4, 3, 2, PALETTE.leafBright],
      [ox + 20, oy + 10, 3, 2, theme.grassDark]
    ));
  } else if (type === 'barrel') {
    drawSoftShadow(ctx, ox + 8, oy + 15, 8, 2, 0.22);
    drawPixels(ctx, rects(
      [ox + 3, oy + 3, 10, 13, PALETTE.plank],
      [ox + 2, oy + 5, 12, 2, PALETTE.woodDark],
      [ox + 2, oy + 12, 12, 2, PALETTE.woodDark],
      [ox + 5, oy + 4, 2, 10, PALETTE.plankLight],
      [ox + 4, oy + 1, 8, 2, PALETTE.stoneDark]
    ));
  } else if (type === 'crate') {
    drawSoftShadow(ctx, ox + 8, oy + 14, 9, 2, 0.2);
    drawPixels(ctx, rects(
      [ox + 2, oy + 5, 14, 10, PALETTE.plank],
      [ox + 2, oy + 5, 14, 2, PALETTE.plankLight],
      [ox + 3, oy + 7, 2, 8, PALETTE.plankDark],
      [ox + 13, oy + 7, 2, 8, PALETTE.plankDark],
      [ox + 5, oy + 8, 8, 1, PALETTE.plankLight],
      [ox + 7, oy + 10, 5, 1, PALETTE.plankLight]
    ));
  } else if (type === 'lantern') {
    const pulse = 1 + ((Math.floor(time / 500) + wobble) % 2);
    drawSoftShadow(ctx, ox + 7, oy + 25, 7, 2, 0.16);
    drawPixels(ctx, rects(
      [ox + 6, oy + 1, 2, 7, PALETTE.woodDark],
      [ox + 2, oy + 7, 10, 2, PALETTE.metal],
      [ox + 4, oy + 9, 6, 8, PALETTE.gold],
      [ox + 5, oy + 10, pulse + 2, 5, PALETTE.goldLight],
      [ox + 6, oy + 17, 2, 8, PALETTE.woodDark]
    ));
    drawTorchGlow(ctx, ox + 7, oy + 13, 12, 0.35);
  } else if (type === 'bench') {
    drawSoftShadow(ctx, ox + 11, oy + 12, 12, 2, 0.2);
    drawPixels(ctx, rects(
      [ox + 1, oy + 4, 22, 4, PALETTE.plankLight],
      [ox + 3, oy + 8, 3, 8, PALETTE.woodDark],
      [ox + 18, oy + 8, 3, 8, PALETTE.woodDark],
      [ox + 2, oy + 2, 20, 2, PALETTE.plank]
    ));
  } else if (type === 'flowerbed') {
    drawPixels(ctx, rects(
      [ox + 1, oy + 8, 23, 7, PALETTE.soil],
      [ox + 3, oy + 5, 3, 7, theme.grassLight],
      [ox + 9, oy + 3, 3, 9, theme.grassLight],
      [ox + 16, oy + 5, 3, 7, theme.grassLight],
      [ox + 4, oy + 3, 2, 2, theme.flower ?? PALETTE.flower],
      [ox + 10, oy + 1, 2, 2, PALETTE.goldLight],
      [ox + 17, oy + 3, 2, 2, theme.flower ?? PALETTE.flower]
    ));
  } else if (type === 'fence') {
    drawPixels(ctx, rects(
      [ox, oy + 8, 32, 3, PALETTE.fence],
      [ox + 2, oy + 2, 4, 14, PALETTE.fenceDark],
      [ox + 14, oy + 2, 4, 14, PALETTE.fenceDark],
      [ox + 26, oy + 2, 4, 14, PALETTE.fenceDark],
      [ox + 2, oy + 2, 4, 2, PALETTE.fence]
    ));
  }
}

// --- Building sprites (LOTR-flavoured, original names) -----------------------

// Ambient-occlusion floor shadow under a building footprint (drawn before the building).
export function drawBuildingShadow(ctx, ox, oy, w, h) {
  ctx.fillStyle = 'rgba(31, 45, 40, 0.16)';
  ctx.beginPath();
  ctx.ellipse(ox + w / 2, oy + h - 2, w * 0.55, 7, 0, 0, Math.PI * 2);
  ctx.fill();
}

function roofCap(ctx, ox, oy, w, roof) {
  drawPixels(ctx, rects([ox, oy, w, 2, roof]));
}

// Lit chimney with drifting smoke (time in ms for the wisp phase).
function drawChimneySmoke(ctx, ox, oy, time) {
  drawPixels(ctx, rects(
    [ox + 58, oy - 8, 6, 10, '#5b4a3f'],
    [ox + 58, oy - 8, 6, 2, '#6f5b4d']
  ));
  const t = (time / 500) % 6;
  const puffs = [
    [ox + 58 + (t < 3 ? t : 6 - t), oy - 12, 4, 3, 'rgba(220,220,210,0.5)'],
    [ox + 60 - (t < 3 ? t : 6 - t), oy - 16, 4, 3, 'rgba(210,210,200,0.34)'],
    [ox + 58 + (t < 3 ? t * 0.6 : 6 - t * 0.6), oy - 20, 3, 3, 'rgba(200,200,190,0.2)']
  ];
  drawPixels(ctx, puffs);
}

export function drawBuildingSprite(ctx, type, ox, oy, theme, time = 0) {
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
      // roof highlight + warm window glow
      drawPixels(ctx, rects([ox + 18, oy + 7, 30, 2, mix(theme.roof, '#ffffff', 0.18)], [ox + 26, oy + 36, 20, 8, 'rgba(241, 212, 154, 0.22)']));
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
      // roof highlight + warm window glow
      drawPixels(ctx, rects([ox + 10, oy + 9, 60, 2, mix(theme.roof, '#ffffff', 0.18)], [ox + 12, oy + 36, 12, 12, 'rgba(198, 226, 212, 0.25)'], [ox + 56, oy + 36, 12, 12, 'rgba(198, 226, 212, 0.25)']));
      drawChimneySmoke(ctx, ox, oy, time);
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
      drawChimneySmoke(ctx, ox, oy, time);
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

export function drawBuildingDetail(ctx, type, ox, oy, theme, time = 0) {
  const roof = theme.roof;
  const roofLight = mix(roof, '#ffffff', 0.18);
  const wallShadow = mix(theme.grass, '#1b2925', 0.35);
  const detail = [];

  if (type === 'smial') {
    for (let x = 18; x <= 48; x += 8) detail.push([ox + x, oy + 9 + ((x / 8) % 2), 5, 2, roofLight]);
    detail.push([ox + 8, oy + 29, 5, 12, wallShadow], [ox + 52, oy + 30, 5, 11, wallShadow]);
    detail.push([ox + 13, oy + 39, 7, 3, PALETTE.leafMid], [ox + 49, oy + 39, 7, 3, PALETTE.leafMid]);
  } else if (type === 'inn') {
    for (let x = 11; x <= 68; x += 9) detail.push([ox + x, oy + 12 + (x % 3), 6, 2, roofLight]);
    detail.push(
      [ox + 12, oy + 36, 12, 2, PALETTE.windowLight], [ox + 17, oy + 36, 2, 12, PALETTE.roofShadow],
      [ox + 56, oy + 36, 12, 2, PALETTE.windowLight], [ox + 61, oy + 36, 2, 12, PALETTE.roofShadow],
      [ox + 31, oy + 29, 16, 3, PALETTE.plankDark], [ox + 33, oy + 30, 12, 1, PALETTE.goldLight]
    );
    drawColonyProp(ctx, theme, 'lantern', ox, oy + 44, 1, time);
    drawColonyProp(ctx, theme, 'lantern', ox + 70, oy + 44, 2, time);
  } else if (type === 'barn') {
    for (let x = 7; x <= 56; x += 10) detail.push([ox + x, oy + 28, 2, 20, mix('#9c5a3c', '#402c29', 0.18)]);
    detail.push([ox + 14, oy + 10, 7, 2, '#b87a52'], [ox + 43, oy + 10, 7, 2, '#b87a52']);
    detail.push([ox + 27, oy + 33, 3, 18, PALETTE.woodDark], [ox + 39, oy + 33, 3, 18, PALETTE.woodDark]);
    detail.push([ox + 29, oy + 39, 12, 2, PALETTE.plankLight]);
  } else if (type === 'market') {
    detail.push(
      [ox + 7, oy + 22, 2, 28, PALETTE.woodDark], [ox + 55, oy + 22, 2, 28, PALETTE.woodDark],
      [ox + 13, oy + 25, 8, 7, PALETTE.flower], [ox + 23, oy + 25, 8, 7, PALETTE.gold],
      [ox + 34, oy + 25, 8, 7, PALETTE.leafBright], [ox + 44, oy + 25, 8, 7, PALETTE.flower]
    );
    drawColonyProp(ctx, theme, 'crate', ox + 2, oy + 39, 3, time);
    drawColonyProp(ctx, theme, 'crate', ox + 48, oy + 39, 4, time);
  } else if (type === 'smithy') {
    for (let x = 12; x <= 54; x += 10) detail.push([ox + x, oy + 9, 5, 2, roofLight]);
    detail.push(
      [ox + 7, oy + 30, 10, 4, PALETTE.metal], [ox + 9, oy + 28, 6, 2, PALETTE.metal],
      [ox + 47, oy + 31, 10, 3, PALETTE.woodDark], [ox + 50, oy + 28, 4, 3, PALETTE.metal]
    );
    const spark = Math.floor(time / 300) % 2;
    detail.push([ox + 52 + spark, oy + 23, 2, 2, PALETTE.goldLight], [ox + 58 - spark, oy + 20, 1, 1, PALETTE.gold]);
  } else if (type === 'library') {
    for (let x = 9; x <= 54; x += 9) detail.push([ox + x, oy + 12, 5, 2, roofLight]);
    detail.push(
      [ox + 12, oy + 36, 10, 2, PALETTE.windowLight], [ox + 16, oy + 36, 2, 12, PALETTE.roofShadow],
      [ox + 44, oy + 36, 10, 2, PALETTE.windowLight], [ox + 48, oy + 36, 2, 12, PALETTE.roofShadow],
      [ox + 25, oy + 30, 14, 2, PALETTE.linen]
    );
  } else if (type === 'well') {
    detail.push([ox + 1, oy + 18, 3, 10, PALETTE.stoneDark], [ox + 12, oy + 18, 3, 10, PALETTE.stoneDark]);
  }
  drawPixels(ctx, detail);
}
