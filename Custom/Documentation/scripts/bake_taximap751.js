/*
 * bake_taximap751.js -- build Interface\TaxiFrame\TaxiMap751.blp for the 8-zone map.
 *
 * WHY THE FIRST ATTEMPT WAS WRONG
 * The obvious source, Interface\WorldMap\Plaguelands\, is the ORIGINAL two-zone
 * continent map: its art covers only Western + Eastern Plaguelands, matching
 * WorldMapArea 1267's stale box (world X 533..3733, Y -5866..-533). Verified by
 * back-projecting node coordinates onto the image -- Hearthglen, Light's Hope,
 * Plaguewood and Eastwall all land on their printed labels within a few pixels.
 * The Lordaeron extension never got new continent art, so 13 of the 31 taxi nodes
 * sit outside that region entirely and their pins scattered off the map.
 *
 * THE FIX
 * Composite a real continent map from the eight PER-ZONE maps, each placed by its
 * own WorldMapArea box, which are correct:
 *     1217 EasternPlaguelands   1268 WesternPlaguelands   1269 Tirisfal
 *     1270 Silverpine           1271 Hilsbrad             1272 Hinterlands
 *     1273 Arathi               1274 RuinsofGilneas
 * Tirisfal/Silverpine/Hilsbrad/Hinterlands/Arathi come from stock locale-enGB
 * (same geography, so the stock art is correct); the other three are DC art in
 * patch-5. Their union is world X -2631..3838, Y -6319..3450, and all 31 taxi
 * nodes fall inside it.
 *
 * GEOMETRY. The taxi frame maps a node through WorldMapContinent's Taxi box onto a
 * square image, so the box is squared about the union's centre and the art is drawn
 * at the sub-rectangle the union actually occupies. Axis convention: world X is the
 * image's VERTICAL extent (top = higher X), world Y the horizontal (left = higher
 * Y) -- the same convention the per-zone boxes use.
 *
 * Emits the .blp plus taximap751_box.json, which carries the exact TaxiMin/TaxiMax
 * that MUST be written to WorldMapContinent id 10, and a labelled preview PNG.
 */
const fs = require('fs');
const path = require('path');
const cp = require('child_process');
const blp = require('K:/Dark-Chaos/wow.export-main/tools/blp-codec.js');

const TOOLS = 'K:/Dark-Chaos/wow.export-main/tools';
const DATA = 'K:/WoW_3.3.5a_ 255 Fun/Data';
const OUT = process.argv[2];                 // scratch dir
const SIZE = 512, TILE = 256, COLS = 4, ROWS = 3;
const ZW = COLS * TILE, ZH = ROWS * TILE;    // 1024 x 768 per zone

// name -> { left,right,top,bottom } = { Y max, Y min, X max, X min }
const ZONES = [
  { n: 'EasternPlaguelands', L: -2288, R: -6319, T: 3704, B: 1017 },
  { n: 'WesternPlaguelands', L: 417, R: -3883, T: 3367, B: 500 },
  { n: 'Hinterlands', L: -1575, R: -5425, T: 1467, B: -1100 },
  { n: 'Arathi', L: -867, R: -4467, T: -133, B: -2533 },
  { n: 'Hilsbrad', L: 1067, R: -2133, T: 400, B: -1733 },
  { n: 'Silverpine', L: 3450, R: -750, T: 1667, B: -1133 },
  { n: 'Tirisfal', L: 3033, R: -1485, T: 3838, B: 825 },
  { n: 'RuinsofGilneas', L: 3440, R: 294, T: -533, B: -2631 },
];

function extractZone(name) {
  const dir = path.join(OUT, 'zonetiles', name);
  fs.mkdirSync(dir, { recursive: true });
  const list = path.join(OUT, `_list_${name}.txt`);
  fs.writeFileSync(list, Array.from({ length: 12 }, (_, i) =>
    `Interface\\WorldMap\\${name}\\${name}${i + 1}.blp`).join('\n') + '\n');
  for (const mpq of [`${DATA}/enGB/locale-enGB.MPQ`, `${DATA}/patch-5.MPQ`,
                     `${DATA}/enGB/patch-enGB-3.MPQ`, `${DATA}/patch-4.MPQ`]) {
    cp.execFileSync('python', [path.join(TOOLS, 'mpq_stormlib_extract.py'),
      '--mpq', mpq, '--out', dir, '--list-file', list, '--quiet'], { stdio: 'ignore' });
    if (fs.existsSync(path.join(dir, `${name}12.blp`))) break;
  }
  const grid = Buffer.alloc(ZW * ZH * 4);
  let got = 0;
  for (let i = 0; i < 12; i++) {
    const p = path.join(dir, `${name}${i + 1}.blp`);
    if (!fs.existsSync(p)) continue;
    const { rgba, w, h } = blp.blpMip0ToRGBA(fs.readFileSync(p));
    if (w !== TILE || h !== TILE) continue;
    const cx = (i % COLS) * TILE, cy = Math.floor(i / COLS) * TILE;
    for (let y = 0; y < TILE; y++)
      rgba.copy(grid, ((cy + y) * ZW + cx) * 4, y * TILE * 4, (y * TILE + TILE) * 4);
    got++;
  }
  if (got !== 12) throw new Error(`${name}: only ${got}/12 tiles`);
  return grid;
}

function main() {
  // union of the zone boxes
  const Xs = ZONES.flatMap(z => [z.T, z.B]), Ys = ZONES.flatMap(z => [z.L, z.R]);
  const uXT = Math.max(...Xs), uXB = Math.min(...Xs);
  const uYL = Math.max(...Ys), uYR = Math.min(...Ys);
  const spanX = uXT - uXB, spanY = uYL - uYR;
  const span = Math.max(spanX, spanY);                 // square the box
  const cX = (uXT + uXB) / 2, cY = (uYL + uYR) / 2;
  const box = { xMin: cX - span / 2, xMax: cX + span / 2, yMin: cY - span / 2, yMax: cY + span / 2 };
  console.log(`union  X ${uXB.toFixed(0)}..${uXT.toFixed(0)}  Y ${uYR.toFixed(0)}..${uYL.toFixed(0)}`);
  console.log(`square box X ${box.xMin.toFixed(0)}..${box.xMax.toFixed(0)}  Y ${box.yMin.toFixed(0)}..${box.yMax.toFixed(0)}  span ${span.toFixed(0)}`);

  // world -> canvas
  const W = 1024, H = 1024;                            // work big, downscale at the end
  const px = y => (box.yMax - y) / span * W;
  const py = x => (box.xMax - x) / span * H;

  const canvas = Buffer.alloc(W * H * 4);              // transparent
  for (const z of ZONES) {
    const src = extractZone(z.n);
    const x0 = Math.round(px(z.L)), x1 = Math.round(px(z.R));
    const y0 = Math.round(py(z.T)), y1 = Math.round(py(z.B));
    const dw = Math.max(1, x1 - x0), dh = Math.max(1, y1 - y0);
    const scaled = blp.resizeRGBA(src, ZW, ZH, dw, dh);
    let drawn = 0;
    for (let y = 0; y < dh; y++) {
      const dy = y0 + y;
      if (dy < 0 || dy >= H) continue;
      for (let x = 0; x < dw; x++) {
        const dx = x0 + x;
        if (dx < 0 || dx >= W) continue;
        const s = (y * dw + x) * 4, d = (dy * W + dx) * 4;
        const a = scaled[s + 3];
        if (a < 8) continue;                            // let the zone's own alpha cut its border
        canvas[d] = scaled[s]; canvas[d + 1] = scaled[s + 1];
        canvas[d + 2] = scaled[s + 2]; canvas[d + 3] = 255;
        drawn++;
      }
    }
    console.log(`  ${z.n.padEnd(20)} -> (${x0},${y0}) ${dw}x${dh}, ${drawn} px`);
  }

  // opaque background where nothing was drawn
  for (let i = 0; i < W * H; i++) {
    if (canvas[i * 4 + 3] === 0) {
      canvas[i * 4] = 18; canvas[i * 4 + 1] = 14; canvas[i * 4 + 2] = 10; canvas[i * 4 + 3] = 255;
    }
  }

  fs.writeFileSync(path.join(OUT, 'taxi', 'composite.bin'), canvas);
  const small = blp.resizeRGBA(canvas, W, H, SIZE, SIZE);
  const mips = [];
  let cur = small, w = SIZE;
  while (w >= 1) { mips.push(blp.encodeDXT1(cur, w, w)); if (w === 1) break; cur = blp.resizeRGBA(cur, w, w, w >> 1, w >> 1); w >>= 1; }
  const out = blp.makeBlpMips(mips, SIZE);
  fs.writeFileSync(path.join(OUT, 'taxi', 'TaxiMap751.blp'), out);
  fs.writeFileSync(path.join(OUT, 'taxi', 'taximap751_box.json'), JSON.stringify(box, null, 1));
  console.log(`wrote TaxiMap751.blp (${out.length} bytes, ${mips.length} mips)`);
  console.log(`wrote taximap751_box.json -- write these into WorldMapContinent id 10`);
}

main();
