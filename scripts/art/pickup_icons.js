// Pickup icons for texture/icon/ (docs/PICKUPS.md). Same style as the hand-made icons: a 64-unit
// box, two darker copies offset down for the extruded edge, a gradient face and a white highlight.
// Run: node scripts/art/pickup_icons.js   (writes <name>.svg and, for new files, a <name>.svg.import
// with svg/scale 1.5 so they import at 96 px like the others). Change art here and re-run; never edit
// the SVGs by hand.
const PAL = {
  red:['#ffb3a3','#e8402e','#a8261a','#6e140c'], orange:['#ffd590','#f08a1c','#a85a00','#6a3600'],
  gold:['#ffe68a','#f0a020','#a86200','#7a4100'], green:['#c4f5a8','#3fbf4a','#24802c','#10461a'],
  olive:['#dcec9e','#7f9e3a','#55722a','#2a3a12'], teal:['#a8f2e4','#19b39a','#0e7a68','#054238'],
  sky:['#d4f0ff','#3fa8f0','#1f6eaa','#0c3c66'], violet:['#e6c4ff','#9a4ae8','#6a26a8','#3a0e66'],
  magenta:['#ffc4ee','#e83aa8','#a01e72','#5c0a40'], steel:['#ffffff','#a8b0b8','#6a7280','#343a44'],
  crimson:['#ff9ab4','#d0164a','#940c2e','#6e0820'], ink:['#8e8e9c','#44444f','#2a2a32','#121216'],
  wood:['#f5c98a','#c47a32','#8a4f1a','#4f2a0a'], cream:['#fffdf6','#f0e2c4','#b8a27a','#6a5838'],
  jade:['#b8f0c8','#3aa86a','#1f7044','#0c3a20'],
};
let GID = 0;
const P = (d, f, c, w = 2) => `<path d="${d}" fill="${f}" stroke="${c.s}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round"/>`;
const PE = (d, f, c, w = 2) => `<path d="${d}" fill="${f}" fill-rule="evenodd" stroke="${c.s}" stroke-width="${w}" stroke-linejoin="round"/>`;
const C = (x, y, r, f, c, w = 2) => `<circle cx="${x}" cy="${y}" r="${r}" fill="${f}" stroke="${c.s}" stroke-width="${w}"/>`;
const E = (x, y, rx, ry, f, c, w = 2) => `<ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="${f}" stroke="${c.s}" stroke-width="${w}"/>`;
const R = (x, y, w, h, rx, f, c, sw = 2, tr = '') => `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" fill="${f}" stroke="${c.s}" stroke-width="${sw}" stroke-linejoin="round"${tr ? ` transform="${tr}"` : ''}/>`;
const L = (d, col, w = 2, extra = '') => `<path d="${d}" fill="none" stroke="${col}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round" ${extra}/>`;
//text as stroked glyphs: Godot's SVG importer (ThorVG) has no fonts. x is the centre, y the baseline.
const GLYPHS = {'×':'M1 3 L9 11 M9 3 L1 11', '2':'M1 4 Q1 0 5 0 Q9 0 9 4 Q9 7 1 14 H9', '5':'M9 0 H2 L1 6 Q5 4 8 6 Q10 9 8 12 Q5 15 1 12',
  '?':'M1 4 Q1 0 5 0 Q9 0 9 4 Q9 7 5 8 V10 M5 13 V13.6', '$':'M8 2 Q5 0 3 1 Q0 3 3 6 L7 8 Q10 10 7 13 Q4 14 1 12 M5 -1 V15'};
const T = (x, y, s, size, f) => { const k = size / 14, w = s.length * 11 * k - k; let out = '';
  [...s].forEach((ch, i) => { out += `<path d="${GLYPHS[ch]}" transform="translate(${(x - w / 2 + i * 11 * k).toFixed(2)} ${(y - size).toFixed(2)}) scale(${k.toFixed(3)})" fill="none" stroke="${f}" stroke-width="${(2.4).toFixed(2)}" stroke-linecap="round" stroke-linejoin="round"/>`; });
  return out; };
const G = (tr, inner) => `<g transform="${tr}">${inner}</g>`;
function starPts(cx, cy, ro, ri, n, rot = -90) {
  let s = ''; for (let i = 0; i < n * 2; i++) { const r = i % 2 ? ri : ro, a = (rot + i * 180 / n) * Math.PI / 180;
    s += (i ? 'L' : 'M') + (cx + r * Math.cos(a)).toFixed(1) + ' ' + (cy + r * Math.sin(a)).toFixed(1) + ' '; } return s + 'Z';
}
function gearPts(cx, cy, ro, ri, n) {
  let s = ''; const st = 360 / n;
  for (let i = 0; i < n; i++) { const a0 = i * st;
    [[a0 - st * .22, ro], [a0 + st * .22, ro], [a0 + st * .32, ri], [a0 + st * .68, ri]].forEach(([a, r], j) => {
      const t = a * Math.PI / 180; s += (i + j ? 'L' : 'M') + (cx + r * Math.cos(t)).toFixed(1) + ' ' + (cy + r * Math.sin(t)).toFixed(1) + ' '; }); }
  return s + 'Z';
}
function sector(cx, cy, r0, r1, a0, a1) {
  const p = (r, a) => [(cx + r * Math.cos(a * Math.PI / 180)).toFixed(2), (cy + r * Math.sin(a * Math.PI / 180)).toFixed(2)];
  const [x0, y0] = p(r1, a0), [x1, y1] = p(r1, a1), [x2, y2] = p(r0, a1), [x3, y3] = p(r0, a0), lg = (a1 - a0) > 180 ? 1 : 0;
  return `M${x3} ${y3} L${x0} ${y0} A${r1} ${r1} 0 ${lg} 1 ${x1} ${y1} L${x2} ${y2} ${r0 > 0 ? `A${r0} ${r0} 0 ${lg} 0 ${x3} ${y3}` : ''} Z`;
}
const ring = (cx, cy, ro, ri) => `M${cx} ${cy - ro} a${ro} ${ro} 0 1 0 0.01 0 Z M${cx} ${cy - ri} a${ri} ${ri} 0 1 1 -0.01 0 Z`;
const gem = (x, y, s) => `M${x - s} ${y - s * .35} L${x - s * .5} ${y - s} L${x + s * .5} ${y - s} L${x + s} ${y - s * .35} L${x} ${y + s} Z`;

/* each icon: p = body palette, a / a2 = accent palettes, dc = detail colour on the top layer, hi = highlight stroke */
const ICONS = {
  wrench: {p:'steel', dc:'#343a44', hi:'M24 12 A9 9 0 0 1 28 8', draw:c => G('rotate(-45 32 31) translate(0 1)', P('M21 15 A11 11 0 0 0 43 15 L43 6 L37 9 L37 16 L27 16 L27 9 L21 6 Z', c.b, c) + R(27.5, 24, 9, 30, 4.5, c.b, c) + C(32, 47, 2.4, c.d, c, 0))},
  sparkplug: {p:'cream', a:'steel', dc:'#b8a27a', hi:'M29 9 V22', draw:c => R(27, 5, 10, 22, 4, c.b, c) + L('M27 12 H37 M27 17 H37', c.d, 1.6) + P('M21 27 H43 L45 35 H19 Z', c.a, c) + R(25, 35, 14, 11, 2, c.a, c, 1.8) + L('M25 39 H39 M25 43 H39', c.s, 1.4) + L('M32 46 V54 H38 V51', c.s, 3)},
  tierod: {p:'steel', a:'crimson', hi:'M18 25 L44 33', draw:c => R(10, 26, 44, 9, 4.5, c.b, c, 2, 'rotate(18 32 31)') + C(11, 24, 8, c.a, c) + C(53, 38, 8, c.a, c) + C(11, 24, 3, c.s, c, 0) + C(53, 38, 3, c.s, c, 0)},
  tankpatch: {p:'red', a:'cream', dc:'#ffd2c8', hi:'M22 32 A10 10 0 0 1 25 24', draw:c => P('M32 5 C40 18 50 28 50 39 A18 18 0 0 1 14 39 C14 28 24 18 32 5 Z', c.b, c) + R(16, 33, 32, 11, 3, c.a, c, 1.8, 'rotate(-20 32 38)') + L('M25 36 L27 41 M31 34 L33 39 M37 32 L39 37', c.s, 1.4)},
  toolbox: {p:'red', a:'steel', hi:'M13 27 H30', draw:c => L('M24 24 V15 Q24 12 27 12 H37 Q40 12 40 15 V24', c.s, 7) + L('M24 24 V15 Q24 12 27 12 H37 Q40 12 40 15 V24', c.b, 3) + R(8, 23, 48, 31, 5, c.b, c) + L('M8 33 H56', c.s, 2) + R(27, 29, 10, 9, 2, c.a, c, 1.5)},
  tyre: {p:'ink', a:'steel', dc:'#8e8e9c', hi:'M14 22 A20 20 0 0 1 24 11', draw:c => C(32, 31, 23, c.b, c) + `<circle cx="32" cy="31" r="19.5" fill="none" stroke="${c.d}" stroke-width="3" stroke-dasharray="4 4.2"/>` + C(32, 31, 11, c.a, c, 1.8) + C(32, 31, 3.5, c.s, c, 0)},
  bulb: {p:'gold', a:'steel', dc:'#a86200', hi:'M23 16 A11 11 0 0 1 30 10', draw:c => P('M32 6 A16 16 0 0 1 42 34 Q39 37 39 41 H25 Q25 37 22 34 A16 16 0 0 1 32 6 Z', c.b, c) + L('M27 31 L29.5 23 L32 31 L34.5 23 L37 31', c.d, 2) + R(25, 41, 14, 12, 3, c.a, c, 1.8) + L('M25 45.5 H39 M25 49.5 H39', c.s, 1.4)},
  service: {p:'green', dc:'#fffdf6', hi:'M16 22 A17 17 0 0 1 24 13', draw:c => P(gearPts(32, 31, 25, 19, 9), c.b, c) + C(32, 31, 11, c.d, c, 1.8) + L('M32 25 V37 M26 31 H38', c.s, 3.4)},
  jerry: {p:'olive', a:'steel', dc:'#55722a', hi:'M15 22 V40', draw:c => P('M12 18 Q12 14 16 14 H40 L48 22 V52 Q48 54 46 54 H14 Q12 54 12 52 Z', c.b, c) + R(17, 18, 7, 5, 2, c.s, c, 0) + R(27, 18, 7, 5, 2, c.s, c, 0) + L('M19 30 L41 48 M41 30 L19 48', c.d, 3.2) + P('M40 15 L46 8 L53 14 L48 19 Z', c.a, c, 1.8)},
  crate: {p:'wood', a:'green', hi:'M14 18 H34', draw:c => R(10, 14, 44, 40, 3, c.b, c) + L('M10 27 H54 M10 41 H54', c.s, 2) + P('M32 18 L44 31 H37.5 V47 H26.5 V31 H20 Z', c.a, c, 1.8)},
  overhaul: {p:'steel', a:'green', hi:'M16 22 A17 17 0 0 1 24 13', draw:c => P(gearPts(32, 31, 25, 19, 9), c.b, c) + C(32, 31, 12, c.s, c, 0) + P('M32 21 L41 30 H36 L32 26 L28 30 H23 Z', c.a, c, 1.4) + P('M32 29 L41 38 H36 L32 34 L28 38 H23 Z', c.a, c, 1.4)},
  turbo: {p:'steel', a:'orange', dc:'#343a44', hi:'M14 26 A17 17 0 0 1 22 16', draw:c => R(38, 8, 16, 13, 3, c.a, c) + C(28, 34, 20, c.b, c) + L('M28 34 m-5 0 a5 5 0 1 1 5 5 a9 9 0 1 1 9 -9 a13 13 0 0 0 -13 -13', c.d, 2.6)},
  blueprint: {p:'sky', dc:'#ffffff', hi:'', draw:c => R(8, 12, 46, 40, 3, c.b, c) + L('M8 22 H54 M8 32 H54 M8 42 H54 M19 12 V52 M31 12 V52 M43 12 V52', c.d, 1, 'opacity=".28"') + R(24, 18, 16, 28, 6, 'none', {s:c.d}, 2.2) + L('M26 26 H38 M26 38 H38', c.d, 2) + P('M54 44 L46 52 L46 44 Z', c.s, c, 0)},
  nitro: {p:'sky', a:'steel', dc:'#fff3a0', hi:'M24 24 V44', draw:c => R(20, 18, 24, 36, 9, c.b, c) + R(27, 11, 10, 9, 2, c.a, c, 1.8) + R(22, 6, 20, 6, 3, c.a, c, 1.8) + P('M35 23 L25 38 H31.5 L28.5 50 L40 33 H33.5 Z', c.d, c, 1.4)},
  magnet: {p:'red', a:'steel', hi:'M16 36 A16 16 0 0 0 21 47', draw:c => P('M12 10 H26 V34 A6 6 0 0 0 38 34 V10 H52 V34 A20 20 0 0 1 12 34 Z', c.b, c) + R(12, 10, 14, 9, 1, c.a, c, 1.8) + R(38, 10, 14, 9, 1, c.a, c, 1.8)},
  frenzy: {p:'gold', dc:'#7a4100', hi:'M30 16 A12 12 0 0 1 38 12', draw:c => C(25, 37, 16, c.b, c) + C(25, 37, 11, 'none', c, 1.2) + C(40, 26, 17, c.b, c) + C(40, 26, 12, 'none', c, 1.2) + T(40, 32, '×2', 15, c.d)},
  shield: {p:'sky', a:'crimson', hi:'M15 22 A19 19 0 0 1 26 10', draw:c => C(32, 31, 24, c.b, c) + C(32, 31, 19, 'none', {s:'#ffffff'}, 1.2).replace('/>', ' opacity=".35"/>') + R(25.5, 19, 13, 24, 5, c.a, c, 1.8) + R(27.5, 22, 9, 6, 2, c.s, c, 0)},
  plow: {p:'gold', dc:'#2a2a32', hi:'M12 21 Q32 12 52 21', draw:c => P('M6 20 Q32 8 58 20 L54 44 Q32 34 10 44 Z', c.b, c) + L('M17 17 L14 40 M28 13.5 L26.5 37 M40 13.5 L40.5 37 M50 16.5 L51.5 40', c.d, 4) + R(26, 42, 12, 10, 2, c.s, c, 0)},
  spikes: {p:'steel', a:'ink', hi:'', draw:c => P(starPts(32, 31, 26, 16, 12), c.b, c) + C(32, 31, 12, c.a, c, 1.8) + C(32, 31, 4.5, c.b, c, 1.4)},
  flood: {p:'gold', a:'ink', hi:'M17 29 V36', draw:c => L('M42 20 L55 12 M43 32 H57 M42 44 L55 52', c.b, 4.5) + R(9, 21, 30, 24, 5, c.a, c) + R(13, 25, 22, 16, 3, c.b, c, 1.8) + R(20, 45, 8, 8, 1, c.a, c, 1.8)},
  firetrail: {p:'orange', dc:'#ffe68a', hi:'', draw:c => P('M32 6 C38 18 50 22 48 38 C47 49 40 56 32 56 C24 56 16 49 16 38 C16 28 24 24 26 14 C30 22 30 26 32 28 C34 20 34 14 32 6 Z', c.b, c) + P('M32 30 C36 36 41 39 40 46 C39 51 36 53 32 53 C28 53 24 51 24 46 C24 41 28 39 29 34 C30 37 31 38 32 39 Z', c.d, c, 0)},
  monster: {p:'ink', a:'green', dc:'#a8b0b8', hi:'M15 27 A19 19 0 0 1 24 17', draw:c => C(32, 35, 21, c.b, c) + `<circle cx="32" cy="35" r="17.5" fill="none" stroke="${c.d}" stroke-width="5" stroke-dasharray="3.5 5" opacity=".7"/>` + C(32, 35, 8, c.d, c, 1.6) + P('M32 2 L41 11 H35.5 V15 H28.5 V11 H23 Z', c.a, c, 1.6)},
  timewarp: {p:'violet', dc:'#f4eaff', hi:'M15 26 A18 18 0 0 1 24 15', draw:c => R(28, 4, 8, 7, 2, c.b, c) + C(32, 33, 22, c.b, c) + C(32, 33, 16, c.d, c, 1.6) + L('M32 33 V22 M32 33 L40 37', c.s, 3) + L('M18 48 A19 19 0 0 1 14 40', c.s, 2)},
  wrecking: {p:'ink', a:'steel', hi:'M16 32 A14 14 0 0 1 22 25', draw:c => C(49, 8, 4, 'none', {s:c.a}, 3) + C(44, 14, 4, 'none', {s:c.a}, 3) + C(39, 20, 4, 'none', {s:c.a}, 3) + R(33, 23, 8, 6, 2, c.a, c, 1.6) + C(28, 39, 17, c.b, c)},
  golden: {p:'gold', a:'crimson', hi:'M14 22 L16 38', draw:c => P('M8 46 L12 18 L23 32 L32 12 L41 32 L52 18 L56 46 Z', c.b, c) + C(12, 17, 3.2, c.b, c, 1.6) + C(32, 11, 3.2, c.b, c, 1.6) + C(52, 17, 3.2, c.b, c, 1.6) + R(8, 42, 48, 11, 2, c.b, c) + C(20, 47.5, 3, c.a, c, 1.2) + C(32, 47.5, 3.6, c.a, c, 1.2) + C(44, 47.5, 3, c.a, c, 1.2)},
  horn: {p:'red', a:'ink', dc:'#6e140c', hi:'M24 30 L48 19', draw:c => C(13, 32, 9, c.a, c) + P('M20 26 L52 12 V52 L20 38 Z', c.b, c) + E(52, 32, 4.5, 20, c.d, c)},
  oilslick: {p:'ink', dc:'#7fd0ff', a:'magenta', hi:'', draw:c => P('M10 36 C8 26 20 22 28 26 C34 18 50 20 52 30 C58 34 56 46 46 46 C40 52 26 52 20 46 C12 46 10 42 10 36 Z', c.b, c) + L('M20 34 Q30 28 40 32', c.d, 2.6) + L('M24 40 Q34 36 44 39', c.a, 2.2)},
  flare: {p:'crimson', a:'gold', hi:'', draw:c => R(20, 28, 10, 28, 3, c.b, c, 2, 'rotate(32 25 42)') + P(starPts(40, 18, 15, 5.5, 8), c.a, c, 1.6)},
  mine: {p:'ink', a:'crimson', hi:'M22 34 A11 11 0 0 1 28 26', draw:c => E(32, 42, 25, 11, c.b, c) + P('M17 40 A15 15 0 0 1 47 40 Z', c.b, c) + C(32, 25, 4.2, c.a, c, 1.4) + C(14, 44, 2, c.s, c, 0) + C(50, 44, 2, c.s, c, 0)},
  emp: {p:'sky', a:'gold', dc:'#ffffff', hi:'M14 24 A20 20 0 0 1 24 12', draw:c => C(32, 32, 23, c.b, c) + C(32, 32, 16.5, 'none', {s:c.d}, 1.6) + P('M35 11 L22 35 H31 L28 53 L42 28 H33 Z', c.a, c, 1.6)},
  bait: {p:'red', a:'cream', dc:'#ffc8b8', hi:'M18 22 A14 14 0 0 1 28 14', draw:c => R(36, 39, 18, 6, 3, c.a, c, 1.6, 'rotate(35 45 42)') + C(53, 49, 3.6, c.a, c, 1.4) + C(50, 53, 3.6, c.a, c, 1.4) + P('M14 30 C10 16 30 8 40 16 C48 22 46 40 34 44 C26 47 18 42 14 30 Z', c.b, c) + L('M20 28 Q28 22 36 26 M22 35 Q30 31 38 34', c.d, 2.2)},
  jets: {p:'steel', a:'orange', hi:'M18 12 V28 M42 12 V28', draw:c => P('M15 40 Q20 60 25 40 Z', c.a, c, 1.6) + P('M39 40 Q44 60 49 40 Z', c.a, c, 1.6) + R(14, 8, 12, 27, 5, c.b, c) + R(38, 8, 12, 27, 5, c.b, c) + P('M12 33 H28 L29 41 H11 Z', c.b, c, 1.8) + P('M36 33 H52 L53 41 H35 Z', c.b, c, 1.8) + R(24, 16, 16, 7, 2, c.b, c, 1.6)},
  hop: {p:'green', a:'steel', dc:'#f2ffe4', hi:'M19 19 H45', draw:c => R(12, 49, 40, 8, 3, c.a, c, 1.8) + L('M19 48 L45 44 L19 39 L45 34 L19 29 L45 25', c.s, 7) + L('M19 48 L45 44 L19 39 L45 34 L19 29 L45 25', c.a, 3.6) + R(14, 16, 36, 9, 3.5, c.b, c, 1.8) + P('M32 1 L42 11 H36.5 V15 H27.5 V11 H22 Z', c.d, c, 1.4)},
  hubcap: {p:'steel', a:'crimson', dc:'#6a7280', hi:'M15 24 A19 19 0 0 1 25 12', draw:c => C(32, 31, 23, c.b, c) + L('M32 13 V49 M14 31 H50 M19 18 L45 44 M45 18 L19 44', c.d, 2.6) + C(32, 31, 8, c.a, c, 1.6) + L('M4 22 H10 M2 31 H8 M4 40 H10', c.s, 2.4)},
  mortar: {p:'red', dc:'#ffe2da', hi:'', draw:c => C(32, 32, 23, c.b, c) + C(32, 32, 15.5, c.d, c, 1.6) + C(32, 32, 7.5, c.b, c, 1.6) + L('M32 5 V16 M32 48 V59 M5 32 H16 M48 32 H59', c.s, 3)},
  pocket: {p:'green', a:'steel', dc:'#d4f0ff', hi:'M18 14 V30', draw:c => R(14, 10, 26, 44, 4, c.b, c) + R(19, 15, 16, 11, 2, c.d, c, 1.4) + L('M40 22 H46 Q50 22 50 26 V42 Q50 46 46 46', c.s, 4.5) + R(41, 42, 9, 10, 2, c.a, c, 1.6) + R(10, 50, 34, 5, 2, c.s, c, 0)},
  nuke: {p:'gold', a:'ink', hi:'M14 24 A20 20 0 0 1 24 12', draw:c => C(32, 32, 24, c.b, c) + P(sector(32, 32, 6.5, 19, -120, -60), c.a, c, 0) + P(sector(32, 32, 6.5, 19, 0, 60), c.a, c, 0) + P(sector(32, 32, 6.5, 19, 120, 180), c.a, c, 0) + C(32, 32, 4, c.a, c, 0)},
  coinstack: {p:'gold', hi:'M18 25 A14 5 0 0 1 30 23', draw:c => [50, 43, 36, 29].map(y => P(`M14 ${y} V${y + 5} A16 6 0 0 0 46 ${y + 5} V${y} Z`, c.s === c.b ? c.b : '#c27400', c, 1.5) + E(30, y, 16, 6, c.b, c, 1.5)).join('') + E(30, 29, 9, 3, 'none', c, 1.2)},
  strongbox: {p:'steel', a:'gold', dc:'#343a44', hi:'M12 20 H30', draw:c => R(8, 16, 48, 38, 4, c.b, c) + R(13, 21, 38, 28, 3, 'none', c, 1.6) + C(32, 35, 8.5, c.a, c, 1.8) + L('M32 35 L32 29 M32 35 L37 37', c.d, 2.2) + R(5, 23, 5, 8, 1.5, c.s, c, 0) + R(5, 40, 5, 8, 1.5, c.s, c, 0)},
  gemcluster: {p:'magenta', dc:'#ffe3f5', hi:'', draw:c => P(gem(20, 40, 12), c.b, c) + L('M8 36 H32 M20 52 L16 36 M20 52 L24 36', c.d, 1.2) + P(gem(44, 40, 12), c.b, c) + L('M32 36 H56 M44 52 L40 36 M44 52 L48 36', c.d, 1.2) + P(gem(32, 21, 13), c.b, c) + L('M19 16.5 H45 M32 34 L27.5 16.5 M32 34 L36.5 16.5', c.d, 1.2)},
  starfrag: {p:'gold', hi:'M22 26 L28 22', draw:c => P(starPts(32, 33, 26, 11, 5), c.b, c) + L('M32 20 L29 28 L35 33 L30 41 L33 48', c.s, 2.6) + L('M35 33 L48 30', c.s, 2.2)},
  goldgoon: {p:'gold', a:'crimson', dc:'#3a1a00', hi:'M20 30 A14 13 0 0 1 28 23', draw:c => P('M18 32 L5 13 L25 24 Z', c.b, c) + P('M46 32 L59 13 L39 24 Z', c.b, c) + E(32, 37, 18, 16, c.b, c) + P('M24 22 L26 12 L30 18 L32 10 L34 18 L38 12 L40 22 Z', c.a, c, 1.6) + C(25, 35, 3.6, c.d, c, 0) + C(39, 35, 3.6, c.d, c, 0) + L('M24 44 Q32 50 40 44', c.s, 2.6)},
  scratch: {p:'cream', a:'steel', dc:'#f0a020', hi:'M10 18 H28', draw:c => R(5, 14, 54, 36, 4, c.b, c) + R(10, 22, 13, 20, 2, c.a, c, 1.4) + R(26, 22, 13, 20, 2, c.a, c, 1.4) + P(starPts(48, 32, 8, 3.5, 5), c.d, c, 1.2)},
  mystery: {p:'magenta', a:'magenta', dc:'#ffffff', hi:'', draw:c => P('M10 22 L32 12 L54 22 V45 L32 55 L10 45 Z', c.b, c) + P('M10 22 L32 12 L54 22 L32 32 Z', c.s === c.b ? c.b : '#ff8ad6', c, 1.8) + L('M32 32 V55', c.s, 2) + T(21.5, 48, '?', 17, c.d) + T(43, 48, '?', 17, c.d)},
  double: {p:'cream', dc:'#2a2a32', hi:'', draw:c => G('rotate(-12 22 32)', R(8, 18, 28, 28, 6, c.b, c) + C(15, 25, 2.6, c.d, c, 0) + C(22, 32, 2.6, c.d, c, 0) + C(29, 39, 2.6, c.d, c, 0)) + G('rotate(10 43 38)', R(30, 25, 26, 26, 6, c.b, c) + C(37, 32, 2.5, c.d, c, 0) + C(49, 32, 2.5, c.d, c, 0) + C(37, 44, 2.5, c.d, c, 0) + C(49, 44, 2.5, c.d, c, 0))},
  wheel: {p:'crimson', a:'gold', dc:'#fffdf6', hi:'', draw:c => C(32, 34, 23, c.b, c) + [0, 2, 4, 6].map(i => P(sector(32, 34, 0, 21, i * 45 - 90, i * 45 - 45), c.a, c, 0)).join('') + C(32, 34, 5, c.s, c, 0) + P('M32 14 L26 4 H38 Z', c.d, c, 1.6)},
  deal: {p:'cream', a:'crimson', hi:'', draw:c => R(20, 12, 24, 36, 4, c.b, c, 2, 'rotate(-20 32 52)') + R(20, 12, 24, 36, 4, c.b, c, 2, 'rotate(20 32 52)') + R(20, 10, 24, 36, 4, c.b, c) + P('M32 18 L39 28 L32 38 L25 28 Z', c.a, c, 1.4)},
  lottery: {p:'gold', a:'crimson', hi:'', draw:c => P('M6 18 H58 V26 A4 4 0 0 0 58 34 V44 H6 V34 A4 4 0 0 0 6 26 Z', c.b, c) + C(19, 30, 5, c.a, c, 1.4) + C(32, 30, 5, c.a, c, 1.4) + C(45, 30, 5, c.a, c, 1.4) + L('M12 39.5 H52', c.s, 1.6, 'stroke-dasharray="2 3"')},
  claw: {p:'steel', a:'crimson', hi:'', draw:c => L('M32 2 V15', c.s, 3) + C(32, 45, 7.5, c.a, c, 1.6) + P('M27 23 Q13 33 20 50 L24 48 Q19 36 31 26 Z', c.b, c, 1.8) + P('M37 23 Q51 33 44 50 L40 48 Q45 36 33 26 Z', c.b, c, 1.8) + R(23, 13, 18, 11, 3, c.b, c)},
  ring: {p:'gold', hi:'M15 24 A19 19 0 0 1 24 13', draw:c => PE(ring(32, 31, 24, 14), c.b, c)},
  bowling: {p:'cream', a:'crimson', a2:'ink', hi:'M27 12 Q25 16 26 20', draw:c => P('M28 6 C24 6 23 12 25 18 C26 22 22 28 21 36 C20 46 24 54 30 54 H34 C40 54 44 46 43 36 C42 28 38 22 39 18 C41 12 40 6 36 6 Z', c.b, c) + L('M25.5 19 H38.5 M25 23.5 H39', c.a, 2.6) + C(48, 45, 11, c.a2, c)},
  speedtrap: {p:'steel', a:'gold', a2:'ink', dc:'#1f6eaa', hi:'M14 18 H28', draw:c => R(28, 36, 7, 20, 2, c.a2, c) + R(9, 14, 40, 22, 4, c.b, c) + C(21, 25, 7.5, c.d, c, 1.6) + R(37, 18, 8, 7, 1.5, c.a, c, 1.4) + P('M49 20 L58 14 V36 L49 30 Z', c.b, c, 1.6)},
  cone: {p:'orange', dc:'#ffffff', hi:'', draw:c => P('M27 8 H37 L46 46 H18 Z', c.b, c) + P('M24.5 21 H39.5 L41.6 30 H22.4 Z', c.d, c, 0) + R(9, 44, 46, 9, 2.5, c.b, c)},
  bullseye: {p:'crimson', dc:'#fff3dc', hi:'', draw:c => C(32, 32, 23, c.b, c) + C(32, 32, 16, c.d, c, 0) + C(32, 32, 9.5, c.b, c, 0) + C(32, 32, 3.5, c.d, c, 0)},
  bomb: {p:'ink', a:'orange', hi:'M18 32 A13 13 0 0 1 24 24', draw:c => R(31, 11, 11, 10, 2, c.b, c, 2, 'rotate(30 36 16)') + L('M41 11 Q46 4 52 8', c.s, 2.5) + C(29, 37, 19, c.b, c) + P(starPts(53, 8, 8, 3, 6), c.a, c, 1.2)},
  truck: {p:'teal', a:'ink', a2:'gold', dc:'#d4f0ff', hi:'M10 18 H28', draw:c => R(5, 14, 36, 30, 3, c.b, c) + P('M41 22 H50 L57 31 V44 H41 Z', c.b, c) + P('M44 25.5 H48.5 L53 31 H44 Z', c.d, c, 1.4) + C(16, 46, 6.5, c.a, c) + C(48, 46, 6.5, c.a, c) + T(23, 36, '$', 19, c.a2)},
  parcel: {p:'wood', dc:'#fff3dc', hi:'', draw:c => P('M10 22 L32 13 L54 22 V46 L32 55 L10 46 Z', c.b, c) + L('M10 22 L32 31 L54 22 M32 31 V55', c.s, 2) + L('M21 17.5 L43 26.5 V36', c.d, 4.2)},
  combo: {p:'orange', dc:'#4f1a00', hi:'', draw:c => P(starPts(32, 31, 26, 17, 10), c.b, c) + T(32, 38.5, '×5', 19, c.d)},
  idol: {p:'jade', a:'crimson', dc:'#0c3a20', hi:'M20 14 V28', draw:c => R(15, 7, 34, 48, 9, c.b, c) + L('M19 21 H45', c.s, 3) + P('M21 27 H30 L28 32 H21 Z', c.a, c, 1.2) + P('M43 27 H34 L36 32 H43 Z', c.a, c, 1.2) + R(22, 40, 20, 9, 2, c.d, c, 1.4) + L('M27 40 V49 M32 40 V49 M37 40 V49', c.b, 1.4)},
  glass: {p:'sky', a:'ink', dc:'#ffffff', hi:'', draw:c => R(8, 18, 42, 17, 8.5, c.b, c, 2, 'rotate(-22 30 26)') + L('M20 26 L26 30 L23 34 M36 18 L38 24', c.d, 1.8) + C(25, 43, 10.5, c.a, c) + C(25, 43, 3.5, c.b, c, 1.2)},
  moon: {p:'crimson', dc:'#940c2e', hi:'M15 26 A19 19 0 0 1 24 14', draw:c => C(32, 32, 23, c.b, c) + C(24, 26, 4.5, c.d, c, 0) + C(38, 40, 6, c.d, c, 0) + C(40, 22, 3, c.d, c, 0) + C(22, 42, 2.5, c.d, c, 0)},
  bargain: {p:'cream', a:'crimson', dc:'#b8a27a', hi:'', draw:c => R(12, 11, 36, 42, 2, c.b, c) + R(8, 7, 44, 7, 3.5, c.b, c) + R(8, 50, 44, 7, 3.5, c.b, c) + L('M18 21 H42 M18 27 H42 M18 33 H34', c.d, 2) + P('M35 36 L33 30 L38.5 34 Z', c.a, c, 1) + P('M45 36 L47 30 L41.5 34 Z', c.a, c, 1) + C(40, 42, 7, c.a, c, 1.6)},
  sack: {p:'wood', dc:'#ffe68a', hi:'', draw:c => P('M20 16 Q32 22 44 16 L46 22 Q57 36 50 50 Q32 58 14 50 Q7 36 18 22 Z', c.b, c) + L('M21 21 Q32 26 43 21', c.s, 3) + E(26, 37, 4, 3, c.d, c, 0) + E(38, 37, 4, 3, c.d, c, 0) + L('M26 35.5 V38.5 M38 35.5 V38.5', c.s, 1.6)},
  stopwatch: {p:'sky', a:'green', dc:'#ffffff', hi:'M17 28 A17 17 0 0 1 25 19', draw:c => R(28, 6, 8, 7, 2, c.b, c) + C(32, 35, 20, c.b, c) + C(32, 35, 14, c.d, c, 1.6) + L('M32 35 L38 27', c.s, 3) + C(49, 16, 9, c.a, c, 1.8) + L('M49 11.5 V20.5 M44.5 16 H53.5', '#ffffff', 2.6)},
  ffwd: {p:'violet', hi:'', draw:c => P('M7 15 L31 32 L7 49 Z', c.b, c) + P('M32 15 L56 32 L32 49 Z', c.b, c)},
  barricade: {p:'orange', a:'ink', dc:'#ffffff', hi:'', draw:c => R(12, 32, 6, 22, 1.5, c.a, c, 1.6) + R(46, 32, 6, 22, 1.5, c.a, c, 1.6) + R(5, 20, 54, 15, 3, c.b, c) + [9, 23, 37, 51].map(x => P(`M${x + 2} 21 H${x + 9} L${x + 3} 34 H${x - 4} Z`, c.d, c, 0)).join('') + R(5, 20, 54, 15, 3, 'none', c)},
  turret: {p:'steel', a:'ink', hi:'', draw:c => R(32, 21, 24, 8, 3, c.a, c, 1.8, 'rotate(-28 34 27)') + P('M12 54 L18 40 H46 L52 54 Z', c.b, c) + P('M17 40 A15 15 0 0 1 47 40 Z', c.b, c) + C(32, 33, 3, c.a, c, 0)},
  compass: {p:'cream', a:'crimson', a2:'ink', hi:'M15 25 A19 19 0 0 1 24 14', draw:c => C(32, 32, 24, c.b, c) + C(32, 32, 18, 'none', c, 1.2) + P('M32 11 L37.5 32 H26.5 Z', c.a, c, 1.4) + P('M26.5 32 H37.5 L32 53 Z', c.a2, c, 1.4)},
  panic: {p:'crimson', a:'ink', hi:'M20 34 A14 12 0 0 1 28 28', draw:c => R(8, 40, 48, 13, 4, c.a, c) + P('M13 42 A19 17 0 0 1 51 42 Z', c.b, c)},
  //crush prizes (docs/PICKUPS.md, "Gift boxes"): the gift box on the crush pill, and the Vault's door
  gift: {p:'crimson', a:'gold', hi:'M12 31 H24', draw:c => R(10, 28, 44, 26, 3, c.b, c) + R(7, 19, 50, 11, 3, c.b, c) + R(28, 19, 8, 35, 1, c.a, c, 1.6) + P('M32 19 C25 7 12 9 17 16 Q23 20 32 19 Z', c.a, c, 1.6) + P('M32 19 C39 7 52 9 47 16 Q41 20 32 19 Z', c.a, c, 1.6) + C(32, 18, 3.5, c.a, c, 1.4)},
  vault: {p:'steel', a:'gold', a2:'ink', hi:'M12 14 H28', draw:c => R(7, 9, 50, 44, 4, c.b, c) + R(12, 14, 40, 34, 3, 'none', c, 1.6) + C(32, 31, 10, c.a, c, 1.8) + L('M32 22 V40 M23 31 H41 M26 25 L38 37 M38 25 L26 37', c.s, 1.6) + C(32, 31, 3.5, c.a2, c, 1.2) + R(13, 52, 8, 5, 1.5, c.a2, c, 1.2) + R(43, 52, 8, 5, 1.5, c.a2, c, 1.2)},
  chute: {p:'crimson', a:'wood', hi:'', draw:c => P('M7 25 A25 19 0 0 1 57 25 Q51 21 44.5 25 Q38 21 32 25 Q26 21 19.5 25 Q13 21 7 25 Z', c.b, c) + L('M9 25 L25 41 M55 25 L39 41 M32 25 V41', c.s, 1.5) + R(23, 40, 18, 15, 2, c.a, c) + L('M23 47.5 H41', c.s, 1.5)},
  //game modes (HudTheme.MODE_ICONS): the run setup medallions and the Goonopedia's mode tiles
  mode_countdown: {p:'orange', a:'crimson', dc:'#fffdf6', hi:'M15 27 A19 19 0 0 1 23 16', draw:c => R(28, 4, 8, 7, 2, c.b, c) + C(32, 34, 23, c.b, c) + C(32, 34, 18, c.d, c, 1.6) + P(sector(32, 34, 0, 15, -90, 150), c.a, c, 0) + L('M32 18 V21 M48 34 H45 M32 50 V47 M16 34 H19', c.s, 2) + L('M32 34 V20', c.s, 3) + C(32, 34, 2.6, c.s, c, 0)},
  mode_sprint: {p:'steel', a:'ink', a2:'crimson', hi:'', draw:c => R(10, 6, 6, 52, 3, c.a2, c) + R(16, 9, 40, 27, 2, c.b, c) + [0, 1, 2].map(row => [0, 1, 2, 3].filter(col => (row + col) % 2 == 0).map(col => R(16 + col * 10, 9 + row * 9, 10, 9, 0, c.a, c, 0)).join('')).join('') + R(16, 9, 40, 27, 2, 'none', c)},
  //the pins are flat gold on top: ThorVG drops these teardrops when they take a gradient fill
  mode_marathon: {p:'green', a:'gold', dc:'#fffdf6', hi:'', draw:c => L('M10 54 C22 54 20 38 32 38 C44 38 42 22 54 22', c.s, 10) + L('M10 54 C22 54 20 38 32 38 C44 38 42 22 54 22', c.b, 6) + L('M10 54 C22 54 20 38 32 38 C44 38 42 22 54 22', c.d, 1.6, 'stroke-dasharray="3 3.5"') + [[10, 54], [32, 38], [54, 22]].map(([x, y]) => P(`M${x} ${y} C${x - 7} ${y - 8} ${x - 7} ${y - 18} ${x} ${y - 18} C${x + 7} ${y - 18} ${x + 7} ${y - 8} ${x} ${y} Z`, c.a.startsWith('url') ? '#f5b02a' : c.a, c, 1.6) + C(x, y - 12.5, 2.6, c.s, c, 0)).join('')},
  mode_defense: {p:'sky', a:'gold', hi:'M17 15 V30', draw:c => P('M32 5 L53 12 V30 C53 43 44 52 32 57 C20 52 11 43 11 30 V12 Z', c.b, c) + P('M21 41 V29 L32 20 L43 29 V41 Z', c.a, c, 1.8) + R(29, 32, 6, 9, 1, c.s, c, 0)},
  mode_pocalypse: {p:'cream', a:'crimson', hi:'M16 24 A17 17 0 0 1 24 12', draw:c => P('M32 5 C46 5 54 15 54 27 C54 35 50 40 46 42 V50 Q46 55 41 55 H23 Q18 55 18 50 V42 C14 40 10 35 10 27 C10 15 18 5 32 5 Z', c.b, c) + E(23, 30, 6.5, 7, c.a, c, 1.6) + E(41, 30, 6.5, 7, c.a, c, 1.6) + P('M32 37 L35.5 43 H28.5 Z', c.s, c, 0) + L('M26 48 V55 M32 48 V55 M38 48 V55', c.s, 1.6)},
  //car traits (CarTraits, docs/CAR_ART.md "Traits"): the garage card's badges and the Goonopedia's Signature rows
  trait_second_wind: {p:'gold', a:'steel', dc:'#7a4100', hi:'M14 22 A12 12 0 0 1 22 14', draw:c => C(22, 26, 14, c.b, c) + C(22, 26, 5, c.d, c, 0) + R(33, 22, 24, 8, 2, c.a, c) + R(46, 30, 5, 7, 1, c.a, c, 1.6) + R(52, 30, 5, 5, 1, c.a, c, 1.6) + L('M12 46 Q18 52 26 48 M30 52 Q36 58 44 52', c.s, 2.4)},
  trait_duct_tape: {p:'steel', a:'cream', dc:'#343a44', hi:'M14 22 A20 20 0 0 1 24 11', draw:c => P('M40 46 L58 54 L52 58 L36 50 Z', c.a, c, 1.8) + PE(ring(30, 30, 22, 10), c.b, c) + `<circle cx="30" cy="30" r="16" fill="none" stroke="${c.d}" stroke-width="1.4" opacity=".5"/>`},
  trait_cargo_bay: {p:'wood', a:'gold', hi:'M10 34 H26', draw:c => R(6, 30, 26, 24, 2, c.b, c) + L('M6 38 H32 M6 46 H32', c.s, 1.6) + R(32, 12, 26, 24, 2, c.b, c) + L('M32 20 H58 M32 28 H58', c.s, 1.6) + C(45, 48, 7, c.a, c, 1.8) + L('M45 44 V52 M41 48 H49', c.s, 2.2)},
  trait_top_heavy: {p:'cream', a:'ink', hi:'M18 22 L36 12', draw:c => G('rotate(-24 32 34)', R(10, 16, 44, 26, 4, c.b, c) + R(16, 21, 10, 8, 2, c.s, c, 0) + C(18, 46, 6, c.a, c) + C(46, 46, 6, 'none', c, 1.4)) + L('M38 54 H60', c.s, 2.4)},
  trait_meter: {p:'gold', a:'ink', dc:'#7a4100', hi:'M12 18 H34', draw:c => R(8, 14, 48, 36, 5, c.b, c) + R(14, 20, 36, 18, 3, c.a, c, 1.6) + T(32, 34, '$', 12, '#7fffa0') + C(20, 44, 2.5, c.d, c, 0) + C(32, 44, 2.5, c.d, c, 0) + C(44, 44, 2.5, c.d, c, 0)},
  trait_city_tyres: {p:'ink', a:'steel', dc:'#8e8e9c', hi:'M14 18 A18 18 0 0 1 22 10', draw:c => C(32, 26, 19, c.b, c) + `<circle cx="32" cy="26" r="15.5" fill="none" stroke="${c.d}" stroke-width="2.6" stroke-dasharray="3.5 3.5"/>` + C(32, 26, 8, c.a, c, 1.8) + R(4, 50, 56, 7, 2, c.a, c, 1.6) + L('M10 53.5 H18 M26 53.5 H34 M42 53.5 H50', '#ffd36b', 2)},
  trait_offroad: {p:'olive', a:'ink', a2:'steel', hi:'M10 44 L22 30', draw:c => P('M4 56 L22 30 L32 40 L42 26 L60 56 Z', c.b, c) + C(32, 24, 12, c.a, c) + C(32, 24, 5, c.a2, c, 1.6) + L('M22 10 L26 14 L22 18 L26 22 M42 10 L38 14 L42 18 L38 22', c.s, 2)},
  trait_loaded_bed: {p:'sky', a:'wood', hi:'M10 38 H50', draw:c => R(12, 12, 14, 12, 1.5, c.a, c, 1.8) + R(28, 8, 14, 16, 1.5, c.a, c, 1.8) + R(44, 14, 12, 10, 1.5, c.a, c, 1.8) + P('M6 24 H58 V44 Q58 48 54 48 H10 Q6 48 6 44 Z', c.b, c) + C(16, 52, 6, c.s, c, 0) + C(48, 52, 6, c.s, c, 0)},
  trait_downforce: {p:'crimson', a:'steel', hi:'M10 14 H52', draw:c => R(6, 10, 52, 9, 3, c.b, c) + R(16, 18, 6, 14, 1, c.a, c, 1.6) + R(42, 18, 6, 14, 1, c.a, c, 1.6) + P('M20 38 H26 V46 H30 L23 56 L16 46 H20 Z', c.b, c, 1.6) + P('M38 38 H44 V46 H48 L41 56 L34 46 H38 Z', c.b, c, 1.6)},
  trait_low_clearance: {p:'crimson', a:'gold', hi:'M14 24 H44', draw:c => P('M4 40 Q8 26 24 22 H40 Q54 24 60 36 V42 H4 Z', c.b, c) + R(2, 48, 60, 5, 2, c.s, c, 0) + P(starPts(18, 47, 9, 3.5, 5), c.a, c, 1.4) + L('M30 46 L36 42 M40 47 L46 44', c.a, 2)},
  trait_drift_king: {p:'gold', a:'violet', dc:'#7a4100', hi:'M14 30 L18 20', draw:c => P('M8 46 L12 18 L24 32 L32 12 L40 32 L52 18 L56 46 Z', c.b, c) + R(8, 46, 48, 8, 2, c.b, c) + C(32, 50, 3.5, c.a, c, 1.2) + C(19, 50, 2.5, c.a, c, 1) + C(45, 50, 2.5, c.a, c, 1)},
  trait_featherweight: {p:'cream', dc:'#b8a27a', hi:'M30 16 Q36 12 44 10', draw:c => P('M54 6 C30 8 14 26 12 50 C26 48 46 36 54 6 Z', c.b, c) + L('M50 12 L14 52', c.d, 2) + L('M42 18 L30 18 M36 26 L24 28 M30 34 L20 37', c.d, 1.4) + L('M14 52 L8 58', c.s, 2.4)},
  trait_pit: {p:'sky', a:'crimson', hi:'M12 18 H30', draw:c => R(6, 12, 34, 18, 4, c.b, c) + R(26, 34, 32, 18, 4, c.a, c, 2, 'rotate(18 42 43)') + L('M44 10 Q56 16 52 28', c.s, 2.6) + P('M47 26 L53 31 L56 23 Z', c.s, c, 0)},
  trait_lightbar: {p:'ink', a:'crimson', a2:'sky', hi:'', draw:c => L('M12 22 L4 14 M10 34 H2 M52 22 L60 14 M54 34 H62 M32 14 V4', '#ffd36b', 2.6) + R(8, 24, 48, 16, 6, c.b, c) + R(12, 27, 19, 10, 3, c.a, c, 1.4) + R(33, 27, 19, 10, 3, c.a2, c, 1.4) + R(14, 42, 36, 8, 2, c.b, c, 1.6)},
  trait_defib: {p:'crimson', a:'gold', hi:'M16 18 A9 9 0 0 1 24 13', draw:c => P('M32 54 C10 40 6 28 10 20 C14 12 26 10 32 20 C38 10 50 12 54 20 C58 28 54 40 32 54 Z', c.b, c) + P('M34 14 L24 32 H31 L27 46 L40 26 H33 Z', c.a, c, 1.4)},
  trait_box_sway: {p:'cream', a:'crimson', hi:'M20 16 H40', draw:c => R(16, 12, 32, 40, 4, c.b, c, 2, 'rotate(10 32 32)') + R(28, 20, 8, 24, 1, c.a, c, 0, 'rotate(10 32 32)') + R(20, 28, 24, 8, 1, c.a, c, 0, 'rotate(10 32 32)') + L('M6 20 Q2 32 6 44 M58 20 Q62 32 58 44', c.s, 2.4)},
  trait_fifth_wheel: {p:'steel', a:'ink', dc:'#343a44', hi:'M14 22 A20 20 0 0 1 24 12', draw:c => C(32, 32, 24, c.b, c) + P('M24 56 L29.5 33 H34.5 L40 56 Z', c.s, c, 0) + C(32, 31, 5, c.s, c, 0) + `<circle cx="32" cy="32" r="18" fill="none" stroke="${c.d}" stroke-width="1.6" stroke-dasharray="2 4" opacity=".7"/>`},
  trait_unstoppable: {p:'steel', a:'wood', hi:'M10 22 H30', draw:c => R(38, 14, 20, 20, 2, c.a, c, 1.8, 'rotate(20 48 24)') + R(42, 36, 16, 16, 2, c.a, c, 1.8, 'rotate(-25 50 44)') + P('M4 18 H30 L42 32 L30 46 H4 Z', c.b, c) + L('M10 32 H28', c.s, 2.4)},
  trait_drop_load: {p:'wood', a:'orange', hi:'M12 12 H30', draw:c => R(8, 8, 26, 22, 2, c.b, c) + L('M8 19 H34', c.s, 1.6) + R(26, 34, 26, 22, 2, c.b, c) + L('M26 45 H52', c.s, 1.6) + P('M44 6 H52 V18 H58 L48 30 L38 18 H44 Z', c.a, c, 1.8)},
};
function icon(key) {
  const d = ICONS[key]; if (!d) return '';
  const p = PAL[d.p], a = PAL[d.a || d.p], a2 = PAL[d.a2 || d.a || d.p], id = 'ig' + (GID++);
  const low = f => d.draw({b:f, s:p[3], d:f, a:f, a2:f});
  const top = d.draw({b:`url(#${id})`, s:p[3], d:d.dc || p[0], a:`url(#${id}a)`, a2:`url(#${id}b)`});
  const grad = (gid, pl) => `<linearGradient id="${gid}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${pl[0]}"/><stop offset="1" stop-color="${pl[1]}"/></linearGradient>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" aria-hidden="true"><defs>${grad(id, p)}${grad(id + 'a', a)}${grad(id + 'b', a2)}</defs><g transform="translate(1.9 0) scale(.94)"><g transform="translate(0 4.5)">${low(p[3])}</g><g transform="translate(0 2.5)">${low(p[2])}</g>${top}${d.hi ? L(d.hi, '#ffffff', 2.2, 'opacity=".8"') : ''}</g></svg>`;
}


//--- output ------------------------------------------------------------------------------------
if (typeof module !== 'undefined' && require.main === module) {
  const fs = require('fs'), path = require('path');
  const dir = path.join(__dirname, '..', '..', 'texture', 'icon');
  const skip = new Set(['idol', 'glass', 'moon', 'bargain', 'sack']); //curses are on hold (GAMEPLAY_SUGGESTIONS "Maybe")
  const importTemplate = fs.readFileSync(path.join(dir, 'coin.svg.import'), 'utf8')
    .split('\n').filter(line => !/^(uid|path|dest_files)=/.test(line)).join('\n');
  let n = 0;
  for (const key of Object.keys(ICONS)) {
    if (skip.has(key)) continue;
    const file = path.join(dir, key + '.svg');
    GID = 0;
    fs.writeFileSync(file, icon(key).replace(' aria-hidden="true"', ' width="64" height="64"'));
    if (!fs.existsSync(file + '.import')) fs.writeFileSync(file + '.import', importTemplate.replace(/coin\.svg/g, key + '.svg'));
    n++;
  }
  console.log('wrote ' + n + ' icons to ' + dir);
}
