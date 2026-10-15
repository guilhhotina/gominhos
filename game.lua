local floor, ceil, sqrt, sin, cos, tan, abs, clamp, pi
local setColor, drawRect, drawClear, textPrint, textMensure, textFontSize
local STD

local TWO32 = 4294967296
local SAVE_KEY = 'gominhos_save_v1'
local LEN, LH = 20, 4.6
local K = LEN / 30
local X = LH / 3.5
local CLIM = 2.3 * X
local FIRE_RATE, MAX_P, MAX_E, MAX_PART = 3, 700, 260, 700
local MUZZLE_Y, MUZZLE_Z, LOSE_Z = 1.38, -0.6, -0.45
local CHARGE_MAX = 40
local PART_DRAW_MAX = 400

local W, H, Z, OSX, OSY = 1920, 1080, 1, 0, 0

local newRng, hashStr
do
local XOR4 = {}
for a = 0, 15 do
  for b = 0, 15 do
    local r, m, x, y = 0, 1, a, b
    for _ = 1, 4 do
      local xa, yb = x % 2, y % 2
      if xa ~= yb then r = r + m end
      x = (x - xa) / 2
      y = (y - yb) / 2
      m = m * 2
    end
    XOR4[a * 16 + b + 1] = r
  end
end

local function bxor(a, b)
  local r, m = 0, 1
  for _ = 1, 8 do
    local an, bn = a % 16, b % 16
    r = r + XOR4[an * 16 + bn + 1] * m
    a = (a - an) / 16
    b = (b - bn) / 16
    m = m * 16
  end
  return r
end

local function imul(a, b)
  local alo = a % 65536
  local ahi = (a - alo) / 65536
  local blo = b % 65536
  local bhi = (b - blo) / 65536
  return (alo * blo + ((ahi * blo + alo * bhi) % 65536) * 65536) % TWO32
end

local function shr(v, p) return (v - v % p) / p end
local function bor1(a) if a % 2 == 0 then return a + 1 end return a end
local function bor61(a)
  local lo = a % 64
  return a - lo + 61 + (shr(lo, 2) % 2) * 2
end

newRng = function(seed)
  local s = seed % TWO32
  return function()
    s = (s + 0x6D2B79F5) % TWO32
    local t = imul(bxor(s, shr(s, 32768)), bor1(s))
    t = bxor(t, (t + imul(bxor(t, shr(t, 128)), bor61(t))) % TWO32)
    return bxor(t, shr(t, 16384)) / TWO32
  end
end

hashStr = function(str)
  local h = 2166136261
  for i = 1, #str do h = imul(bxor(h, string.byte(str, i)), 16777619) end
  return h
end
end

local function hx(s) return tonumber(string.sub(s, 2), 16) end
local function chans(c)
  local b = c % 256
  local g = ((c - b) / 256) % 256
  return (c - b - g * 256) / 65536, g, b
end
local function c255(v)
  if v < 0 then return 0 end
  if v > 255 then return 255 end
  return floor(v + 0.5)
end
local function mixRgb(a, b, t)
  local ar, ag, ab = chans(a)
  local br, bg, bb = chans(b)
  return (c255(ar + (br - ar) * t) * 256 + c255(ag + (bg - ag) * t)) * 256 + c255(ab + (bb - ab) * t)
end
local function rgba(c, a) return c * 256 + (a or 255) end

local INK, CREAM, CREAM_D = 0x24122e, 0xfff3df, 0xe9cfa6
local PINK, PINK_D, MINT, MINT_D = 0xff5d8f, 0xc2386a, 0x45cf9f, 0x23926e
local GOLD, GOLD_D, PLUM, PLUM_D = 0xffc531, 0xc98a12, 0x43284f, 0x2d1836
local LIME, HAZE, WHITE = 0xd6ff3a, 0xffe3d1, 0xffffff

local tintCache = {}
local function mixc(c, target, q)
  if q <= 0 then return c end
  local tc = tintCache[target]
  if not tc then tc = {}; tintCache[target] = tc end
  local key = c * 16 + q
  local v = tc[key]
  if not v then
    local a = c % 256
    v = mixRgb((c - a) / 256, target, q / 15) * 256 + a
    tc[key] = v
  end
  return v
end

local SKINS = {
  {id='mirtilo', name='Mirtilo', price=0, base='#4f8dff', shade='#3462d1', light='#8cc0ff', feet='#22307a', topper='sprout', pattern='sugar', acc={'#5fd068','#3a9e4c','#7a4a2a'}},
  {id='morango', name='Morango', price=120, base='#ff4f6a', shade='#c9304f', light='#ff8fa0', feet='#7a1a34', topper='leafcrown', pattern='seeds', acc={'#4fc25a','#2f8a3e','#ffe06a'}, blush='#ffc2d0'},
  {id='limao', name='Limão', price=150, base='#ffe14d', shade='#e0b42c', light='#fff3a0', feet='#8a6512', topper='leaf', pattern='sugar', acc={'#7bd44a','#4c9a2c','#8a5a2a'}},
  {id='uva', name='Uva', price=200, base='#9b5cff', shade='#6e37cf', light='#c49bff', feet='#3a1d7a', topper='vine', pattern='sugar', acc={'#7a4a2a','#66c35a','#3d8f3a'}},
  {id='menta', name='Menta', price=260, base='#7ff0c8', shade='#4cc59d', light='#c4fff0', feet='#23705a', topper='choco', pattern='chips', acc={'#6b3a22','#4a2414','#8a5232'}},
  {id='laranja', name='Laranja', price=320, base='#ff9a3c', shade='#dd6d1f', light='#ffc68a', feet='#7a330e', topper='propeller', pattern='sugar', acc={'#ffe14d','#4f8dff','#ff4f6a'}},
  {id='pudim', name='Pudim', price=400, base='#ffd36b', shade='#e8a83c', light='#fff0b8', feet='#7a4a1a', topper='cherry', pattern='caramel', acc={'#e8222f','#9e1020','#5a3a1a'}, caramel='#a8551c', caramelL='#c9732e'},
  {id='algodao', name='Algodão-doce', price=480, base='#ffa6d6', shade='#e27fb8', light='#ffd6ee', feet='#7a3f7f', topper='cloud', pattern='cotton', acc={'#ffffff','#e3eeff','#b8d8ff'}, base2='#9fd2ff'},
  {id='abelha', name='Abelha', price=560, base='#ffd23f', shade='#e0a91c', light='#fff0a0', feet='#2a2026', topper='antennae', pattern='bee', acc={'#2a2026','#ffffff','#cfefff'}},
  {id='noite', name='Noite', price=650, base='#3b3f9e', shade='#272a73', light='#6a70d6', feet='#15163f', topper='wizard', pattern='stars', acc={'#5b3fc8','#ffe14d','#ffe14d'}},
  {id='fantasma', name='Fantasma', price=800, base='#eef3ff', shade='#c3cdee', light='#ffffff', feet='#8e9bd0', topper='halo', pattern='ghost', acc={'#ffe14d','#e0b42c','#ffffff'}, blush='#a9c8ff', ghost=true},
  {id='ouro', name='Ouro', price=1200, base='#ffc531', shade='#d9921a', light='#fff1a8', feet='#7a4e0a', topper='crown', pattern='gold', acc={'#e8a31c','#ff4f6a','#4fd6ff'}},
}
local ENEMY = {id='azedinho', name='Azedinho', base='#43284f', shade='#2d1836', light='#6a4278', feet='#1e0f24', topper='horns', pattern='sour', acc={'#d6ff3a','#9bc21e','#efe2c8'}, enemy=true}

local function convertSkin(sk)
  for _, f in ipairs({'base', 'shade', 'light', 'feet', 'blush', 'caramel', 'caramelL', 'base2'}) do
    if sk[f] then sk[f] = hx(sk[f]) end
  end
  for i = 1, 3 do sk.acc[i] = hx(sk.acc[i]) end
end
for _, sk in ipairs(SKINS) do convertSkin(sk) end
convertSkin(ENEMY)

local FLAVOR = {
  mirtilo = 'O clássico. Nasceu com uma folhinha na cabeça e nunca mais largou dela.',
  morango = 'Coberto de sementinhas e com coroa de folhas. Doce até no grito de guerra.',
  limao = 'Azedinho por fora, gente boa por dentro. Os Azedinhos odeiam a concorrência.',
  uva = 'Fugiu de um cacho enorme e ainda carrega um pedaço da videira.',
  menta = 'Fresquinho, com gotas de chocolate e um tablete fazendo as vezes de chapéu.',
  laranja = 'Tem uma hélice no boné e nenhuma ideia de como ela funciona.',
  pudim = 'Calda de caramelo escorrendo e uma cereja no topo. Treme quando anda.',
  algodao = 'Metade rosa, metade azul, feito de nuvem. Melhor não pegar chuva.',
  abelha = 'Listrado, de antenas e asinhas. O único gominho que zumbe.',
  noite = 'Estrelado e de chapéu de mago. Brilha mais quando a fase aperta.',
  fantasma = 'Meio transparente, com auréola. Ninguém lembra de que sabor ele era.',
  ouro = 'Brilha, tem coroa e custa caro. Os Azedinhos tremem quando ele chega.',
}

local ICONS = {
  coin = {p = {a = '#24122e', b = '#ffc531', c = '#fff1a8', d = '#c98a12'}, rows = {'..aaaa..', '.abbbba.', 'abccbbda', 'abcbbbda', 'abcbbbda', 'abbbbdda', '.adddda.', '..aaaa..'}},
  pause = {p = {a = '#24122e'}, rows = {'aa..aa', 'aa..aa', 'aa..aa', 'aa..aa', 'aa..aa', 'aa..aa'}},
  soundOn = {p = {a = '#24122e'}, rows = {'...a.....', '..aa..a..', 'aaaa...a.', 'aaaa.a.a.', 'aaaa...a.', '..aa..a..', '...a.....'}},
  soundOff = {p = {a = '#24122e'}, rows = {'...a.....', '..aa.....', 'aaaa.a.a.', 'aaaa..a..', 'aaaa.a.a.', '..aa.....', '...a.....'}},
  close = {p = {a = '#24122e'}, rows = {'aa...aa', 'aaa.aaa', '.aaaaa.', '..aaa..', '.aaaaa.', 'aaa.aaa', 'aa...aa'}},
  fort = {p = {a = '#24122e', b = '#fff3df'}, rows = {'a.a.a.a', 'aaaaaaa', '.aaaaa.', '.abaab.', '.aaaaa.', '.aabaa.', '.aabaa.'}},
  arrowL = {p = {a = '#ffffff'}, rows = {'..a', '.aa', 'aaa', '.aa', '..a'}},
  arrowR = {p = {a = '#ffffff'}, rows = {'a..', 'aa.', 'aaa', 'aa.', 'a..'}},
  arrowLd = {p = {a = '#24122e'}, rows = {'...a', '..aa', '.aaa', 'aaaa', '.aaa', '..aa', '...a'}},
  arrowRd = {p = {a = '#24122e'}, rows = {'a...', 'aa..', 'aaa.', 'aaaa', 'aaa.', 'aa..', 'a...'}},
}

local FONT3 = {
  ['0'] = {'111', '101', '101', '101', '111'}, ['1'] = {'010', '110', '010', '010', '111'},
  ['2'] = {'111', '001', '111', '100', '111'}, ['3'] = {'111', '001', '011', '001', '111'},
  ['4'] = {'101', '101', '111', '001', '001'}, ['5'] = {'111', '100', '111', '001', '111'},
  ['6'] = {'111', '100', '111', '101', '111'}, ['7'] = {'111', '001', '010', '010', '010'},
  ['8'] = {'111', '101', '111', '101', '111'}, ['9'] = {'111', '101', '111', '001', '111'},
  ['x'] = {'000', '101', '010', '101', '000'}, ['+'] = {'000', '010', '111', '010', '000'},
}

local function skinIdx(id)
  for i, s in ipairs(SKINS) do if s.id == id then return i end end
  return 1
end

local save = {level = 1, coins = 0, owned = {'mirtilo'}, equipped = 'mirtilo', mixed = false, muted = false}
local G = {}
local mobs, parts, pool, partPool = {}, {}, {}, {}
local gates, spinners, bases = {}, {}, {}
local cannon = {x = 0, tx = 0, recoil = 0}
local keys = {left = false, right = false, tapL = 0, tapR = 0, tap = 0.08}
local capP = MAX_P
local rnd = newRng(1)
local T = 0
local perfAcc, perfN = 0, 0
local shakeOX, shakeOY = 0, 0
local ui = {screen = 'menu', focus = 'play', btns = {}, shopReturn = 'menu', toast = nil, toastT = 0, hint = false, hintT = 0, flash = 0, result = nil}
local shop = {idx = 1, pos = 1, spinT = 0, shakeT = 0, popT = 0}
local sfxLast = {}

local sfx, persist, show, play, pause, resume, toMenu, openShop, closeShop, showResult, toast

local function owns(id)
  for _, o in ipairs(save.owned) do if o == id then return true end end
  return false
end

local curCol, GA = -1, 1
local clipOn, clx0, cly0, clx1, cly1 = false, 0, 0, 0, 0

local function colorSet(c)
  if GA < 1 then local a = c % 256; c = c - a + floor(a * GA) end
  if c ~= curCol then setColor(c); curCol = c end
end

local function fill(c, x, y, w, h)
  if clipOn then
    if x < clx0 then w = w - (clx0 - x); x = clx0 end
    if y < cly0 then h = h - (cly0 - y); y = cly0 end
    if x + w > clx1 then w = clx1 - x end
    if y + h > cly1 then h = cly1 - y end
  end
  if w <= 0 or h <= 0 or x >= W or y >= H or x + w <= 0 or y + h <= 0 then return end
  if x < -8 then w = w + x + 8; x = -8 end
  if y < -8 then h = h + y + 8; y = -8 end
  if w > W + 16 then w = W + 16 end
  if h > H + 16 then h = H + 16 end
  colorSet(c)
  drawRect(0, floor(x), floor(y), floor(w), floor(h))
end

local EMPTY = {}
local function gPut(g, x, y, c)
  local row = g[y]
  if not row then row = {}; g[y] = row end
  row[x] = c
end
local function gRect(g, x, y, w, h, c)
  for yy = y, y + h - 1 do for xx = x, x + w - 1 do gPut(g, xx, yy, c) end end
end
local function encodeGrid(g, rows, cols)
  local cnt, best, bestN = {}, nil, 0
  for r = 0, rows - 1 do
    local row = g[r]
    if row then
      for c = 0, cols - 1 do
        local v = row[c]
        if v then
          local n = (cnt[v] or 0) + 1
          cnt[v] = n
          if n > bestN then best, bestN = v, n end
        end
      end
    end
  end
  local out = {}
  local function pass(colored)
    local open = {}
    for r = 0, rows - 1 do
      local row = g[r] or EMPTY
      local nopen = {}
      local c = 0
      while c < cols do
        local v = row[c]
        if v and (not colored or v ~= best) then
          local c2 = c + 1
          while c2 < cols do
            local v2 = row[c2]
            if not v2 or (colored and v2 ~= v) then break end
            c2 = c2 + 1
          end
          local cv = colored and v or best
          local key = cv * 16384 + c * 128 + c2
          local idx = open[key]
          if idx then
            out[idx + 3] = r + 1
          else
            idx = #out + 1
            out[idx], out[idx + 1], out[idx + 2], out[idx + 3], out[idx + 4] = c, r, c2, r + 1, cv
          end
          nopen[key] = idx
          c = c2
        else
          c = c + 1
        end
      end
      open = nopen
    end
  end
  if best then pass(false); pass(true) end
  out.n = #out / 5
  return out
end

local function sprDown(t, x, y, cw, ch, snap, tgt, q)
  for i = 1, t.n * 5, 5 do
    local x0 = floor((x + t[i] * cw) / snap + 0.5) * snap
    local x1 = floor((x + t[i + 2] * cw) / snap + 0.5) * snap
    local y0 = floor((y + t[i + 1] * ch) / snap + 0.5) * snap
    local y1 = floor((y + t[i + 3] * ch) / snap + 0.5) * snap
    if x1 > x0 and y1 > y0 then fill(mixc(t[i + 4], tgt, q), x0, y0, x1 - x0, y1 - y0) end
  end
end

local function iconTpl(def)
  local g = {}
  local pal = {}
  for k, v in pairs(def.p) do pal[k] = rgba(hx(v)) end
  for y, row in ipairs(def.rows) do
    for x = 1, #row do
      local c = pal[string.sub(row, x, x)]
      if c then gPut(g, x - 1, y - 1, c) end
    end
  end
  local t = encodeGrid(g, #def.rows, #def.rows[1])
  t.cols, t.rows = #def.rows[1], #def.rows
  return t
end

local ICON_T = {}
local SKIN_COL, ENEMY_COL, BURST_ENEMY, BURST_BASE, BURST_GOLD, BURST_WIN = {}, nil, nil, nil, nil, nil

local scene = {}
do
local GFX = 'gfx/'
local SLOTS = 508
local UI_SLOTS = 40
local LOADS = {menu = 6, loading = 16, celebrate = 2, playing = 0}
local TWO_PI = 6.283185307179586

local M
local imgLoad, imgDraw, imgUnload, imgMensure
local OX, OY, CX, CY, PX = 0, 0, 0, 0, 3
local camX, camY, camZ, upY, upZ, bkY, bkZ, P00, P11, HW, HH, camDist = 0, 0, 0, 0, 0, 0, 0, 0, 0, 960, 540, 30
local fogNear, fogInv = 44, 1 / 66
local ZI = {}
local MOBSET = {}

local cache, live, inflight = {}, {}, {}
local order, epoch = {}, 0
local loadsFrame = 0
local essLeft, essTotal = 0, 0
local targets, shopIdx = nil, nil
local primary = nil

local function nearest(list, v)
  local bi, bd = 1, 1e18
  for i = 1, #list do
    local d = list[i] - v
    if d < 0 then d = -d end
    if d < bd then bi, bd = i, d end
  end
  return bi
end

local function recOf(e)
  local r = e.rec
  if r then return r end
  r = cache[e.file]
  if not r then
    r = {file = e.file, want = 0}
    cache[e.file] = r
  end
  e.rec = r
  return r
end

local function release(r)
  imgUnload(r.id)
  local i = r.slot
  local n = #live
  live[i] = live[n]
  live[i].slot = i
  live[n] = nil
  r.id, r.ready, r.slot = nil, false, nil
end

local function loadRec(r)
  local id = imgLoad(GFX .. r.file)
  loadsFrame = loadsFrame + 1
  if type(id) ~= 'number' or id < 0 then r.failed = true; return end
  r.id, r.ready = id, false
  live[#live + 1] = r
  r.slot = #live
  inflight[#inflight + 1] = r
end

local function have(e)
  local r = e.rec or recOf(e)
  return r.ready
end

local function proj(x, y, z)
  local dy, dz = y - camY, z - camZ
  local dep = -(dy * bkY + dz * bkZ)
  local k = P00 * HW / dep
  return HW + (x - camX) * k, HH - (dy * upY + dz * upZ) * P11 * HH / dep, k, dep
end

local function fogq(dep)
  local q = (dep - fogNear) * fogInv
  if q <= 0 then return 0 end
  if q >= 1 then return 15 end
  return floor(q * 15 + 0.5)
end

local function blit(e, sx, sy)
  imgDraw(e.rec.id, PX * floor((sx - e.ax) / PX + 0.5) + OX + CX, PX * floor((sy - e.ay) / PX + 0.5) + OY + CY)
end

local function sn(v) return floor(v / PX + 0.5) * PX end

local function sRect(c, x0, y0, x1, y1)
  local X0, X1, Y0, Y1 = sn(x0), sn(x1), sn(y0), sn(y1)
  if X1 <= X0 then X1 = X0 + PX end
  if Y1 <= Y0 then Y1 = Y0 + PX end
  fill(c, X0 + OX + CX, Y0 + OY + CY, X1 - X0, Y1 - Y0)
end

local function gText(g, s, x, y, sc, c)
  for i = 1, #s do
    local gl = FONT3[string.sub(s, i, i)]
    if gl then
      for r = 0, 4 do
        for cc = 0, 2 do
          if string.sub(gl[r + 1], cc + 1, cc + 1) == '1' then gRect(g, x + ((i - 1) * 4 + cc) * sc, y + r * sc, sc, sc, c) end
        end
      end
    end
  end
end

local function hpTpl(b)
  local g = {}
  gRect(g, 1, 0, 46, 20, rgba(INK)); gRect(g, 0, 1, 48, 18, rgba(INK))
  gRect(g, 2, 1, 44, 18, rgba(PLUM)); gRect(g, 1, 2, 46, 16, rgba(PLUM))
  gRect(g, 2, 1, 44, 1, rgba(0x6a4278))
  local hp = b.hp > 0 and b.hp or 0
  local t = tostring(ceil(hp))
  local tw = (#t * 4 - 1) * 2 + 9
  local x0 = floor((48 - tw) / 2)
  local ic = {'a.a.a.a', 'aaaaaaa', '.aaaaa.', '.aa.aa.', '.aaaaa.'}
  for y, row in ipairs(ic) do
    for xx = 1, 7 do if string.sub(row, xx, xx) == 'a' then gPut(g, x0 + xx - 1, 3 + y, rgba(LIME)) end end
  end
  gText(g, t, x0 + 9, 3, 2, rgba(PLUM_D))
  gText(g, t, x0 + 9, 2, 2, rgba(LIME))
  gRect(g, 3, 14, 42, 3, rgba(PLUM_D))
  local fw = floor(42 * clamp(hp / b.max, 0, 1) + 0.5)
  if fw > 0 then gRect(g, 3, 14, fw, 3, rgba(0x9bc21e)); gRect(g, 3, 14, fw, 1, rgba(LIME)) end
  return encodeGrid(g, 20, 48)
end

local function gateRow(gt)
  local g = gt.pair and M.gates.pair[gt.mult][gt.x < 0 and 'left' or 'right'] or M.gates.single[gt.mult]
  return g.sprites[nearest(M.gates.bs, gt.bs or 1)][ZI.gate(gt.z)]
end

local function baseSet(b)
  if b.x < -0.01 then return M.bases.left end
  if b.x > 0.01 then return M.bases.right end
  return M.bases.center
end

local function mobSet(m)
  if m.team == 1 then
    if m.kind == 2 then return M.mobs.azedinho.brute, ZI.brute, 'brute' end
    return M.mobs.azedinho.mob, ZI.enemy, 'enemy'
  end
  if m.kind == 1 then return MOBSET[m.skin].champ, ZI.champ, 'champ' end
  return MOBSET[m.skin].mob, ZI.mob, 'mob'
end

local function poseOf(z, f, m)
  if m.air then return (m.airV > 0 and z.air) or z.jump or z.walk[f] end
  return z.walk[f]
end

local function pose(set, zi, f, m)
  local e = poseOf(set[zi], f, m)
  if have(e) then return e end
  local walk = set[zi].walk
  for d = 1, 4 do
    local a = walk[(f - 1 + d) % 8 + 1]
    if have(a) then return a end
    a = walk[(f - 1 - d) % 8 + 1]
    if have(a) then return a end
  end
  for d = 1, 2 do
    local s = set[zi - d]
    if s and have(poseOf(s, f, m)) then return poseOf(s, f, m) end
    s = set[zi + d]
    if s and have(poseOf(s, f, m)) then return poseOf(s, f, m) end
  end
  return nil
end

do

local function zIndexer(list)
  local t = {}
  for i = 0, 2800 do t[i] = nearest(list, -25 + i * 0.01) end
  return function(z)
    local i = floor((z + 25) * 100 + 0.5)
    if i < 0 then i = 0 elseif i > 2800 then i = 2800 end
    return t[i]
  end
end

function scene.load(std, root, manifest)
  GFX = root .. 'gfx/'
  imgLoad, imgDraw, imgUnload, imgMensure = std.image.load, std.image.draw, std.image.unload, std.image.mensure
  M = assert(manifest and load(manifest) or loadfile(GFX .. 'manifest.lua'))()
  PX = M.scale
  for _, key in ipairs({'mob', 'champ', 'enemy', 'brute', 'gate', 'spinner'}) do ZI[key] = zIndexer(M.buckets[key]) end
  for i, sk in ipairs(SKINS) do MOBSET[i] = M.mobs[sk.id] end
  fogNear, fogInv = M.fog.near, 1 / (M.fog.far - M.fog.near)
end
end

function scene.camera_fit(w, h)
  local c = M.camera
  camX, camY, camZ = c.pos[1], c.pos[2], c.pos[3]
  upY, upZ, bkY, bkZ = c.up[2], c.up[3], c.back[2], c.back[3]
  P00, P11, camDist = c.p00, c.p11, c.dist
  HW, HH = M.screen.w / 2, M.screen.h / 2
  CX, CY = floor((w - M.screen.w) / 2), floor((h - M.screen.h) / 2)
end

local rebuild, recount
do
local WALK_A, WALK_B, WALK_C = {1, 5}, {3, 7}, {2, 4, 6, 8}

local function walkFrames(L, set, frames)
  for _, z in ipairs(set) do for _, f in ipairs(frames) do L[#L + 1] = z.walk[f] end end
end

local function flightZ(buckets)
  local t = {}
  for i, z in ipairs(buckets) do if z >= -2.6 then t[#t + 1] = i end end
  return t
end

local function levelList(d)
  local L = {}
  local spRows = {}
  for _, sp in ipairs(d.spinners) do spRows[#spRows + 1] = M.spinners.sprites[ZI.spinner(sp.z)] end
  for _, gt in ipairs(d.gates) do L[#L + 1] = gateRow(gt)[1] end
  for _, b in ipairs(d.bases) do L[#L + 1] = baseSet(b).alive[1] end
  for _, row in ipairs(spRows) do for k = 1, #row, 4 do L[#L + 1] = row[k] end end
  for _, gt in ipairs(d.gates) do local row = gateRow(gt); L[#L + 1] = row[2]; L[#L + 1] = row[3] end
  for _, b in ipairs(d.bases) do
    local set = baseSet(b)
    for k = 2, #set.alive do L[#L + 1] = set.alive[k] end
    for _, e in ipairs(set.dying) do L[#L + 1] = e end
  end
  for _, row in ipairs(spRows) do for k = 3, #row, 4 do L[#L + 1] = row[k] end end
  return L
end

local function sharedList(t)
  local L = {}
  local function add(e) L[#L + 1] = e end
  local eq = t.equipped
  local mob, champ = M.mobs[eq].mob, M.mobs[eq].champ
  local enemy, brute = M.mobs.azedinho.mob, M.mobs.azedinho.brute
  add(M.background)
  add(M.cannon[eq][1]); add(M.ui[eq].champ); add(M.ui[eq].champ_dim); add(M.ui[eq].hero)
  add(M.ui.azedinho.enemy); add(M.ui[eq].result)
  for _, key in ipairs({'mob', 'enemy', 'champ', 'brute'}) do for _, row in ipairs(M.shadow[key]) do add(row[1]) end end
  walkFrames(L, mob, WALK_A)
  for _, z in ipairs(mob) do add(z.air) end
  walkFrames(L, enemy, WALK_A)
  walkFrames(L, champ, WALK_A)
  for _, i in ipairs(flightZ(M.buckets.champ)) do add(champ[i].air) end
  walkFrames(L, brute, WALK_A)
  for _, key in ipairs({'mob', 'champ'}) do
    for _, i in ipairs(flightZ(M.buckets[key])) do
      local row = M.shadow[key][i]
      for l = 2, #row do add(row[l]) end
    end
  end
  for k = 2, #M.cannon[eq] do add(M.cannon[eq][k]) end
  walkFrames(L, mob, WALK_B); walkFrames(L, enemy, WALK_B)
  walkFrames(L, champ, WALK_B)
  for i = 2, #t.flavors do
    local set = M.mobs[t.flavors[i]].mob
    walkFrames(L, set, WALK_A)
    for _, z in ipairs(set) do add(z.air) end
  end
  walkFrames(L, mob, WALK_C); walkFrames(L, enemy, WALK_C)
  local main = L
  L = {}
  for _, id in ipairs(t.art) do add(M.ui[id].result) end
  local art = L
  L = {}
  walkFrames(L, brute, WALK_B)
  for _, z in ipairs(mob) do add(z.jump) end
  for _, z in ipairs(enemy) do add(z.jump) end
  add(M.ui[eq].shop[1])
  for i = 2, #t.flavors do
    local set = M.mobs[t.flavors[i]]
    walkFrames(L, set.mob, WALK_B)
    walkFrames(L, set.champ, WALK_A)
  end
  walkFrames(L, champ, WALK_C); walkFrames(L, brute, WALK_C)
  for _, z in ipairs(champ) do add(z.jump) end
  for _, z in ipairs(brute) do add(z.jump) end
  for i = 2, #t.flavors do walkFrames(L, M.mobs[t.flavors[i]].mob, WALK_C) end
  for _, key in ipairs({'mob', 'enemy'}) do for _, row in ipairs(M.shadow[key]) do add(row[2]); add(row[3]) end end
  return main, L, art
end

local function shopList(idx)
  local L = {}
  local function side(i)
    local sk = SKINS[i]
    if sk then L[#L + 1] = M.ui[sk.id].shop_side; L[#L + 1] = M.ui[sk.id].shop[1] end
  end
  local cur = M.ui[SKINS[idx].id].shop
  L[#L + 1] = cur[1]
  side(idx - 1); side(idx + 1)
  for k = 2, #cur do L[#L + 1] = cur[k] end
  side(idx - 2); side(idx + 2)
  return L
end

recount = function()
  local left, total = 0, 0
  for i = 1, #order do
    local r = order[i]
    if r.ess and not r.failed then
      total = total + 1
      if not r.ready then left = left + 1 end
    end
  end
  essLeft, essTotal = left, total
end

rebuild = function()
  epoch = epoch + 1
  order = {}
  local cap = SLOTS
  local function add(e, ess)
    local r = e.rec or recOf(e)
    if r.want == epoch or #order >= cap then return false end
    r.want, r.ess = epoch, ess
    order[#order + 1] = r
    return true
  end
  if shopIdx then for _, e in ipairs(shopList(shopIdx)) do add(e, false) end end
  if targets then
    local main, extra, art = sharedList(targets)
    cap = #order + SLOTS - UI_SLOTS
    for _, e in ipairs(levelList(targets.cur)) do add(e, true) end
    for _, e in ipairs(main) do add(e, true) end
    for _, e in ipairs(art) do add(e, false) end
    cap = SLOTS
    if targets.nxt then for _, e in ipairs(levelList(targets.nxt)) do add(e, false) end end
    for _, e in ipairs(extra) do add(e, false) end
  end
  for i = #live, 1, -1 do
    local r = live[i]
    if r.want ~= epoch then release(r) end
  end
  recount()
end
end

function scene.set_targets(t)
  targets = t
  primary = M.mobs[t.equipped]
  rebuild()
end

function scene.set_shop(idx)
  if idx == shopIdx then return end
  shopIdx = idx
  rebuild()
end

function scene.pump(mode)
  loadsFrame = 0
  local n = #inflight
  if n > 0 then
    local idle = native_image_loading_count and native_image_loading_count() == 0
    local w = 0
    for i = 1, n do
      local r = inflight[i]
      inflight[i] = nil
      if r.id then
        local iw = imgMensure(r.id)
        if iw and iw > 0 then
          r.ready = true
        elseif idle then
          release(r)
          r.failed = true
        else
          w = w + 1
          inflight[w] = r
        end
      end
    end
  end
  local budget = LOADS[mode] or 0
  if budget > 0 then
    for i = 1, #order do
      if loadsFrame >= budget or #live >= SLOTS then break end
      local r = order[i]
      if not r.id and not r.failed then loadRec(r) end
    end
  end
  if n > 0 or loadsFrame > 0 then recount() end
end

function scene.pending() return essLeft, essTotal end

function scene.begin_frame(ox, oy)
  OX, OY = ox, oy
end

function scene.draw_background()
  local e = M.background
  if have(e) then
    imgDraw(e.rec.id, OX + CX, OY + CY)
  end
end

local touched, nTouched = {}, 0

local function enqueue(e, sx, sy)
  local r = e.rec
  local n = r.qn or 0
  if n == 0 then
    nTouched = nTouched + 1
    touched[nTouched] = r
    if not r.qx then r.qx, r.qy = {}, {} end
  end
  n = n + 1
  r.qn = n
  r.qx[n] = PX * floor((sx - e.ax) / PX + 0.5) + OX + CX
  r.qy[n] = PX * floor((sy - e.ay) / PX + 0.5) + OY + CY
end

local function flush()
  for t = 1, nTouched do
    local r = touched[t]
    local id, qx, qy = r.id, r.qx, r.qy
    for i = 1, r.qn do imgDraw(id, qx[i], qy[i]) end
    r.qn = 0
    touched[t] = nil
  end
  nTouched = 0
end

local function shadowSprite(m)
  local _, zl, key = mobSet(m)
  local row = M.shadow[key][zl(m.z)]
  local e = row[1]
  if m.y > 0 then e = row[nearest(M.shadow.levels, clamp(1 - m.y * 0.25, 0.45, 1))] end
  if have(e) then return e end
  e = row[1]
  if have(e) then return e end
  return nil
end

function scene.draw_shadows(list, n)
  for i = 1, n do
    local m = list[i]
    local e = shadowSprite(m)
    if e then
      local sx, sy = proj(m.x, 0, m.z)
      enqueue(e, sx, sy)
    end
  end
  flush()
end

function scene.batch_key(z) return ZI.mob(z) end

function scene.draw_mobs(list, n)
  for i = 1, n do
    local m = list[i]
    local set, zl = mobSet(m)
    local zi, f = zl(m.z), floor(m.phase / TWO_PI * 8 + 0.5) % 8 + 1
    local e = pose(set, zi, f, m)
    if not e and m.team == 0 and primary then
      local alt = m.kind == 1 and primary.champ or primary.mob
      if alt ~= set then e = pose(alt, zi, f, m) end
    end
    if e then
      local sx, sy = proj(m.x, m.y, m.z)
      enqueue(e, sx, sy)
    end
  end
  flush()
end

function scene.draw_gate(gt)
  local row = gateRow(gt)
  local e = row[nearest(M.gates.flash, gt.flash)]
  if not have(e) then
    e = row[1]
    if not have(e) then return end
  end
  local sx, sy = proj(gt.x, 0, gt.z)
  blit(e, sx, sy)
end

function scene.draw_spinner(sp)
  local row = M.spinners.sprites[ZI.spinner(sp.z)]
  local n = M.spinners.frames
  local k = floor(sp.a / TWO_PI * n + 0.5) % n + 1
  local e = row[k]
  if not have(e) then
    e = nil
    for d = 1, n / 2 do
      local a = row[(k - 1 + d) % n + 1]
      if have(a) then e = a; break end
      a = row[(k - 1 - d) % n + 1]
      if have(a) then e = a; break end
    end
    if not e then return end
  end
  local sx, sy = proj(sp.x, 0, sp.z)
  blit(e, sx, sy)
end

function scene.draw_base(b)
  if b.dying >= 1 then return end
  local set = baseSet(b)
  local e
  if b.dying >= 1 / 16 then e = set.dying[nearest(M.bases.dying, b.dying)]
  else e = set.alive[nearest(M.bases.flash, b.flash)] end
  if not have(e) then
    e = set.alive[1]
    if not have(e) then return end
  end
  local sx, sy = proj(b.x, 0, b.z)
  blit(e, sx, sy)
end

function scene.draw_cannon(c, flavor)
  local list = M.cannon[flavor]
  local e = list[nearest(M.cannon.rk, c.recoil < 1 and c.recoil or 1)]
  if not have(e) then
    e = list[1]
    if not have(e) then return end
  end
  local sx, sy = proj(c.x, 0, M.cannon.z)
  blit(e, sx, sy)
end

function scene.draw_particle(p)
  local sx, sy, k, dep = proj(p.x, p.y, p.z)
  local f = p.t / p.life
  local half = p.s * (f > 0.65 and (1 - (f - 0.65) / 0.35) or 1) * 0.6 * k
  if half < PX * 0.5 then half = PX * 0.5 end
  sRect(mixc(p.c, HAZE, fogq(dep)), sx - half, sy - half, sx + half, sy + half)
end

function scene.draw_base_label(b)
  local hp = b.hp > 0 and ceil(b.hp) or 0
  if b.lblHp ~= hp then b.lblHp = hp; b.lblTpl = hpTpl(b) end
  local x, y = proj(b.x, 5.4, b.z)
  sprDown(b.lblTpl, sn(x - 24 * PX) + OX + CX, sn(y - 10 * PX) + OY + CY, PX, PX, PX, HAZE, 0)
end

function scene.thumb_size(kind) return M.ui.sizes[kind] or M.ui.sizes.champ end

local function thumbEntry(skin_id, kind, frame)
  local set = M.ui[skin_id]
  if kind == 'shop' then return set.shop[(frame or 0) % M.ui.shop.frames + 1] end
  return set[kind] or set.enemy
end

function scene.draw_thumb(skin_id, kind, x, y, frame)
  local e = thumbEntry(skin_id, kind, frame)
  if not have(e) then
    if kind ~= 'shop' then return end
    e = M.ui[skin_id].shop[1]
    if not have(e) then return end
  end
  imgDraw(e.rec.id, floor(x - e.ax), floor(y - e.ay))
end

function scene.shake_offset(ex, ey)
  return sn(-ex * P00 * HW / camDist), sn(ey * upY * P11 * HH / camDist)
end

function scene.unload()
  for i = #live, 1, -1 do release(live[i]) end
  for i = #inflight, 1, -1 do inflight[i] = nil end
  order, targets, shopIdx, essLeft, essTotal = {}, nil, nil, 0, 0
  epoch = epoch + 1
end
end

local SFX_GAP = {shoot = 0.04, gate = 0.055, pop = 0.035, hit = 0.06, spin = 0.08}
local SFX_CH = {shoot = 0, pop = 1, hit = 2, gate = 3, spin = 4, champ = 5, ['break'] = 5, nav = 6, click = 6, deny = 6, coin = 6, win = 7, lose = 7}

sfx = function(name)
  if save.muted or not native_audio_sfx_play then return end
  local gap = SFX_GAP[name]
  if gap and sfxLast[name] and T - sfxLast[name] < gap then return end
  sfxLast[name] = T
  pcall(native_audio_sfx_play, SFX_CH[name], scene.root .. 'sfx/' .. name .. '.wav')
end

persist = function()
  if not (STD and STD.storage and STD.json and STD.json.encode) then return end
  local owned = {}
  for i, o in ipairs(save.owned) do owned[i] = o end
  local ok, s = pcall(STD.json.encode, {level = save.level, coins = save.coins, owned = owned, equipped = save.equipped, mixed = save.mixed, muted = save.muted})
  if ok and s then STD.storage.set(SAVE_KEY, s):run() end
end

local function loadSave()
  save.level, save.coins, save.owned, save.equipped, save.mixed, save.muted = 1, 0, {'mirtilo'}, 'mirtilo', false, false
  if not (STD.storage and STD.json and STD.json.decode) then return end
  STD.storage.get(SAVE_KEY):callback(function(v)
    if type(v) ~= 'string' or #v == 0 then return end
    local ok, t = pcall(STD.json.decode, v)
    if not ok or type(t) ~= 'table' then return end
    if type(t.level) == 'number' and t.level >= 1 then save.level = floor(t.level) end
    if type(t.coins) == 'number' and t.coins >= 0 then save.coins = floor(t.coins) end
    if type(t.owned) == 'table' then
      local list, seen = {}, {}
      for _, id in ipairs(t.owned) do
        if type(id) == 'string' and not seen[id] then
          for _, sk in ipairs(SKINS) do if sk.id == id then list[#list + 1] = id; seen[id] = true end end
        end
      end
      if not seen.mirtilo then table.insert(list, 1, 'mirtilo') end
      save.owned = list
    end
    if type(t.equipped) == 'string' and owns(t.equipped) then save.equipped = t.equipped end
    if type(t.mixed) == 'boolean' then save.mixed = t.mixed end
    if type(t.muted) == 'boolean' then save.muted = t.muted end
  end):run()
end

local buildLevel, update, fireChampion, prepareAssets
do
local function genLevel(n)
  local r = newRng(n * 7919 + 101)
  local gl = {}
  local ng = 2 + floor((n - 1) / 2)
  if ng > 6 then ng = 6 end
  local zA, zB = -5.6 * K, -22.4 * K
  local slots = {}
  for i = 0, ng - 1 do slots[i + 1] = (ng == 1) and (zA + zB) / 2 or zA + (zB - zA) * i / (ng - 1) end
  local function pick()
    local v = r()
    if v < 0.55 then return 2 elseif v < 0.88 then return 3 end
    return 4
  end
  local bs = ng > 1 and clamp((zA - zB) / (ng - 1) / 2.8, 0.84, 1) or 1
  for i = 0, ng - 1 do
    local z = slots[i + 1] + (r() - 0.5) * 0.9 * K
    if n >= 3 and i > 0 and r() < 0.3 then
      local hi = (n >= 6 and r() < 0.5) and 4 or 3
      local lo = hi == 4 and 3 or 2
      local left = r() < 0.5
      gl[#gl + 1] = {z = z, x0 = -1.72 * X, amp = 0, w = 3.1 * X, mult = left and lo or hi, speed = 0, ph = 0, bs = bs, pair = true}
      gl[#gl + 1] = {z = z, x0 = 1.72 * X, amp = 0, w = 3.1 * X, mult = left and hi or lo, speed = 0, ph = 0, bs = bs, pair = true}
    else
      local mult = pick()
      if n == 1 then mult = (i == 0) and 2 or 3 end
      if n == 2 then mult = (i % 2 == 1) and 3 or 2 end
      local w = (mult == 2 and 2.6 or (mult == 3 and 2.2 or 1.7)) * X
      local lim = LH - w / 2 - 0.15
      local mv = 0.25 + n * 0.07
      if mv > 0.8 then mv = 0.8 end
      local moving = mult == 4 or (n >= 2 and r() < mv)
      local x0, amp = 0, 0
      if moving then
        x0 = (r() * 2 - 1) * lim * 0.25
        amp = (lim - abs(x0)) * (0.55 + r() * 0.45)
      else
        x0 = (r() * 2 - 1) * lim * 0.8
      end
      local speed = 0.55 + r() * 0.8
      local ph = r() * 6.28
      gl[#gl + 1] = {z = z, x0 = x0, amp = amp, w = w, mult = mult, speed = speed, ph = ph, bs = bs}
    end
  end
  local sp = {}
  local ns = n < 3 and 0 or (n < 8 and 1 or 2)
  for k = 0, ns - 1 do
    local i = (ns == 1) and floor((ng - 1) / 2) or (k == 0 and 0 or ng - 2)
    local a = slots[clamp(i, 0, ng - 1) + 1]
    local b = slots[clamp(i + 1, 0, ng - 1) + 1]
    local x = (r() - 0.5) * 2.2 * X
    local R = 1.45 * (K > 0.72 and K or 0.72)
    local sgn = r() < 0.5 and -1 or 1
    local w = sgn * (1.3 + r() * 0.8 + n * 0.03)
    sp[#sp + 1] = {z = (a + b) / 2, x = x, R = R, w = w, a = r() * 6.28}
  end
  local hp = floor(55 + (n - 1) * 26 + (n - 1) * (n - 1) * 1.5 + 0.5)
  local twin = n >= 4 and (n % 3 == 1 or r() < 0.35)
  local BZ = -LEN + 1.2
  local bl
  if twin then
    local h2 = floor(hp * 0.55 + 0.5)
    bl = {{x = -1.75 * X, z = BZ, w = 2.4, hp = h2}, {x = 1.75 * X, z = BZ, w = 2.4, hp = h2}}
  else
    bl = {{x = 0, z = BZ, w = 2.9, hp = hp}}
  end
  local interval = 3.3 - n * 0.13
  if interval < 1.4 then interval = 1.4 end
  local perWave = 2 + floor(n * 0.75)
  if perWave > 16 then perWave = 16 end
  local bruteEvery = 0
  if n >= 3 then bruteEvery = 6 - floor(n / 4); if bruteEvery < 3 then bruteEvery = 3 end end
  local espd = 2.3 + n * 0.05
  if espd > 3.3 then espd = 3.3 end
  return {gates = gl, spinners = sp, bases = bl, interval = interval, perWave = perWave, bruteEvery = bruteEvery, bruteHp = 5 + n, espd = espd}
end

local function shake(a) if a > G.shake then G.shake = a end end

local function burst(x, y, z, cols, n, spd)
  spd = spd or 3.2
  for _ = 1, n do
    if #parts >= MAX_PART then return end
    local p = partPool[#partPool]
    if p then partPool[#partPool] = nil else p = {} end
    p.x, p.y, p.z = x, y, z
    p.vx = (rnd() - 0.5) * spd
    p.vy = rnd() * spd + 1.4
    p.vz = (rnd() - 0.5) * spd
    p.t = 0
    p.life = 0.4 + rnd() * 0.35
    p.s = 0.07 + rnd() * 0.08
    p.c = cols[floor(rnd() * #cols) + 1]
    parts[#parts + 1] = p
  end
end

local function colsOf(m) if m.team == 1 then return ENEMY_COL end return SKIN_COL[m.skin] end

local function kill(m, quiet)
  if m.dead then return end
  m.dead = true
  burst(m.x, 0.45 * m.scale, m.z, colsOf(m), m.kind ~= 0 and 14 or 5)
  if not quiet then sfx('pop') end
  if m.team == 1 then G.kills = G.kills + 1 end
end

local function newMob()
  local m = pool[#pool]
  if m then pool[#pool] = nil else m = {} end
  return m
end

local function spawnPlayer(skin, x, z, kind)
  local m = newMob()
  m.team, m.x, m.y, m.z, m.vx, m.vy = 0, x, 0, z, 0, 0
  m.air, m.airV, m.hp, m.r, m.scale, m.skin, m.passed = false, 0, 1, 0.3, 1, skin, 0
  m.phase = rnd() * 6.28
  m.spd = (4.0 + rnd() * 0.45) * K
  m.kind, m.dead, m.pop = 0, false, 1
  if kind == 1 then m.kind = 1; m.hp = 20 + G.level * 2; m.r = 0.72; m.scale = 2.1; m.spd = 3.0 * K end
  mobs[#mobs + 1] = m
  G.pCount = G.pCount + 1
  return m
end

local function spawnEnemy(b, brute)
  if G.eCount >= MAX_E then return end
  local m = newMob()
  m.team = 1
  m.x = clamp(b.x + (rnd() - 0.5) * 1.6, -LH + 0.4, LH - 0.4)
  m.y = 0
  m.z = b.z + 1.5 + rnd() * 0.8
  m.vx = (rnd() - 0.5) * 0.6
  m.vy, m.air, m.airV, m.hp, m.r, m.scale, m.skin, m.passed = 0, false, 0, 1, 0.3, 1, 0, 0
  m.phase = rnd() * 6.28
  m.spd = G.L.espd * (0.92 + rnd() * 0.16) * K
  m.kind, m.dead, m.pop = 0, false, 0.2
  if brute then m.kind = 2; m.hp = G.L.bruteHp; m.r = 0.55; m.scale = 1.75; m.spd = m.spd * 0.72 end
  mobs[#mobs + 1] = m
  G.eCount = G.eCount + 1
end

local function pickSkin()
  if save.mixed then
    local o = save.owned
    return skinIdx(o[floor(rnd() * #o) + 1])
  end
  return skinIdx(save.equipped)
end

local function fire()
  if G.pCount >= capP then return end
  local m = spawnPlayer(pickSkin(), cannon.x + (rnd() - 0.5) * 0.24, MUZZLE_Z, 0)
  m.air, m.y = true, MUZZLE_Y
  m.vy = 1.7 + rnd() * 0.5
  m.airV = 4.6 * K
  m.vx = (rnd() - 0.5) * 0.4
  m.pop = 0.5
  cannon.recoil = 1
  G.charge = G.charge + 1
  if G.charge > CHARGE_MAX then G.charge = CHARGE_MAX end
  sfx('shoot')
end

fireChampion = function()
  if G.state ~= 'playing' or G.paused or G.charge < CHARGE_MAX then return end
  G.charge = 0
  local m = spawnPlayer(pickSkin(), cannon.x, MUZZLE_Z - 0.3, 1)
  m.air, m.y, m.vy, m.airV, m.pop = true, MUZZLE_Y, 2.2, 3.8 * K, 0.3
  cannon.recoil = 1.6
  burst(cannon.x, MUZZLE_Y, MUZZLE_Z, BURST_GOLD, 16, 4)
  sfx('champ')
  shake(0.12)
end

local function hasBit(mask, bit) return floor(mask / bit) % 2 == 1 end

local function multiply(m, gt)
  gt.flash = 1
  sfx('gate')
  local n = (gt.mult - 1) * (m.kind == 1 and 3 or 1)
  local hw = gt.w / 2 - 0.2
  for _ = 1, n do
    if G.pCount >= capP then break end
    local x = clamp(m.x + (rnd() - 0.5) * 1.5, gt.x - hw, gt.x + hw)
    local c = spawnPlayer(m.skin, x, gt.z - 0.15 - rnd() * 0.55, 0)
    c.passed = m.passed
    c.pop = 0.25
    c.vx = (rnd() - 0.5) * 2.2
  end
end

local function win()
  if G.state ~= 'playing' then return end
  G.state, G.endT = 'won', 0
  G.reward = 30 + G.level * 10 + floor(G.kills / 4)
  for _, m in ipairs(mobs) do if m.team == 1 and not m.dead then kill(m, true) end end
  save.coins = save.coins + G.reward
  save.level = G.level + 1
  persist()
  sfx('win')
  for _ = 1, 4 do burst((rnd() - 0.5) * 5, 2.5, -18 - rnd() * 8, BURST_WIN, 30, 6) end
end

local function lose()
  if G.state ~= 'playing' then return end
  G.state, G.endT = 'lost', 0
  sfx('lose')
  shake(0.3)
  ui.flash = 0.6
end

local function hitBase(b, m)
  b.hp = b.hp - m.hp
  if b.hp < 0 then b.hp = 0 end
  b.flash = 1
  m.dead = true
  if rnd() < 0.4 then burst(m.x, 0.6, b.front, colsOf(m), 3) end
  sfx('hit')
  if b.hp <= 0 and b.alive then
    b.alive, b.dying = false, 0
    burst(b.x, 1.6, b.z + 0.6, BURST_BASE, 60, 7)
    sfx('break')
    shake(0.35)
    local all = true
    for _, o in ipairs(bases) do if o.alive then all = false end end
    if all then win() end
  end
end

local CS, GX0, GZ0 = 1.3, -5, -36
local GW, GH = 9, 37
local gridHead, gridNext = {}, {}

local function pair(m, o)
  if o.dead or o.air then return end
  local dx, dz = o.x - m.x, o.z - m.z
  local rr = m.r + o.r
  local d2 = dx * dx + dz * dz
  if d2 >= rr * rr then return end
  if m.team == o.team then
    local d = sqrt(d2)
    if d == 0 then d = 0.01 end
    local ov = (rr - d) / d * 0.5
    local ws = m.scale + o.scale
    local wm, wo = o.scale / ws, m.scale / ws
    m.x = m.x - dx * ov * wm * 0.9
    m.z = m.z - dz * ov * wm * 0.45
    o.x = o.x + dx * ov * wo * 0.9
    o.z = o.z + dz * ov * wo * 0.45
  elseif G.state == 'playing' then
    local d = m.hp < o.hp and m.hp or o.hp
    m.hp = m.hp - d
    o.hp = o.hp - d
    if m.hp <= 0 then kill(m) end
    if o.hp <= 0 then kill(o) end
  end
end

local function cellOf(v, n)
  if v < 0 then return 0 end
  v = floor(v)
  if v > n - 1 then return n - 1 end
  return v
end

local function collide()
  for i = 1, GW * GH do gridHead[i] = 0 end
  local ms = mobs
  local n = #ms
  for i = 1, n do
    local m = ms[i]
    if not m.dead and not m.air then
      local cx = cellOf((m.x - GX0) / CS, GW)
      local cz = cellOf((m.z - GZ0) / CS, GH)
      local k = cz * GW + cx + 1
      gridNext[i] = gridHead[k]
      gridHead[k] = i
      m.cx, m.cz = cx, cz
    end
  end
  for i = 1, n do
    local m = ms[i]
    if not m.dead and not m.air then
      for dz = -1, 1 do
        local z2 = m.cz + dz
        if z2 >= 0 and z2 < GH then
          for dx = -1, 1 do
            local x2 = m.cx + dx
            if x2 >= 0 and x2 < GW then
              local j = gridHead[z2 * GW + x2 + 1]
              while j ~= 0 do
                if j > i then
                  pair(m, ms[j])
                  if m.dead then break end
                end
                j = gridNext[j]
              end
            end
            if m.dead then break end
          end
        end
        if m.dead then break end
      end
    end
  end
end

prepareAssets = function()
  local flavors = {save.equipped}
  if save.mixed then
    for _, id in ipairs(save.owned) do if id ~= save.equipped then flavors[#flavors + 1] = id end end
  end
  local nx = genLevel(G.level + 1)
  for _, gd in ipairs(nx.gates) do gd.x = gd.x0 end
  local o = save.owned
  G.art = {save.equipped, o[floor(rnd() * #o) + 1], save.equipped}
  scene.set_targets({
    cur = {gates = gates, spinners = spinners, bases = bases},
    nxt = {gates = nx.gates, spinners = nx.spinners, bases = nx.bases},
    flavors = flavors, equipped = save.equipped, art = {G.art[2]},
  })
end

buildLevel = function(n)
  for i = #mobs, 1, -1 do pool[#pool + 1] = mobs[i]; mobs[i] = nil end
  for i = #parts, 1, -1 do partPool[#partPool + 1] = parts[i]; parts[i] = nil end
  G.pCount, G.eCount = 0, 0
  local L = genLevel(n)
  G.L, G.level = L, n
  gates = {}
  for i, gd in ipairs(L.gates) do
    gd.bit = 2 ^ (i - 1)
    gd.x = gd.x0
    gd.flash = 0
    gates[i] = gd
  end
  spinners = L.spinners
  bases = {}
  local front = -1e9
  for i, bd in ipairs(L.bases) do
    bd.max, bd.alive, bd.flash, bd.dying = bd.hp, true, 0, -1
    bd.front, bd.hw = bd.z + 1.25, bd.w / 2
    bases[i] = bd
    if bd.front > front then front = bd.front end
  end
  G.baseFront = front
  G.charge, G.kills, G.wave, G.eTimer, G.endT = 0, 0, 0, 2.4, 0
  G.state, G.fireAcc, G.reward, G.resultShown = 'menu', 1, 0, false
  cannon.tx = 0
  prepareAssets()
end

update = function(dt)
  G.t = G.t + dt
  local C = cannon
  if keys.left then C.tx = C.tx - 7 * dt end
  if keys.right then C.tx = C.tx + 7 * dt end
  C.tx = clamp(C.tx, -CLIM, CLIM)
  local e = dt * 18
  if e > 1 then e = 1 end
  C.x = C.x + (C.tx - C.x) * e
  C.recoil = C.recoil - dt * 7
  if C.recoil < 0 then C.recoil = 0 end
  if G.state == 'playing' then
    G.fireAcc = G.fireAcc + dt
    local iv = 1 / FIRE_RATE
    while G.fireAcc >= iv do
      G.fireAcc = G.fireAcc - iv
      fire()
    end
    G.eTimer = G.eTimer - dt
    if G.eTimer <= 0 then
      G.eTimer = G.L.interval
      G.wave = G.wave + 1
      local alive = {}
      for _, b in ipairs(bases) do if b.alive then alive[#alive + 1] = b end end
      if #alive > 0 then
        local per = ceil(G.L.perWave / #alive)
        for _, b in ipairs(alive) do
          for _ = 1, per do spawnEnemy(b, false) end
          burst(b.x, 0.6, b.front + 0.2, BURST_ENEMY, 4, 2)
        end
        if G.L.bruteEvery > 0 and G.wave % G.L.bruteEvery == 0 then spawnEnemy(alive[floor(rnd() * #alive) + 1], true) end
      end
    end
  end
  for _, gt in ipairs(gates) do
    gt.x = gt.x0 + gt.amp * sin(G.t * gt.speed + gt.ph)
    gt.flash = gt.flash - dt * 5
    if gt.flash < 0 then gt.flash = 0 end
  end
  for _, sp in ipairs(spinners) do sp.a = sp.a + sp.w * dt end

  local celebrate = G.state == 'won'
  local i = 1
  while i <= #mobs do
    local m = mobs[i]
    if not m.dead then
      if m.pop < 1 then m.pop = m.pop + dt * 6; if m.pop > 1 then m.pop = 1 end end
      if m.team == 0 then
        local pz = m.z
        if m.air then
          m.vy = m.vy - 20 * dt
          m.y = m.y + m.vy * dt
          m.z = m.z - m.airV * dt
          m.x = m.x + m.vx * dt
          if m.y <= 0 then m.y = 0; m.air = false; m.vx = m.vx * 0.3 end
        elseif celebrate then
          if rnd() < dt * 1.5 then m.air = true; m.vy = 3 + rnd() * 2; m.airV = 0 end
        elseif G.state ~= 'lost' then
          m.z = m.z - m.spd * dt
          local tx, best = nil, 1e9
          if m.z < G.baseFront + 8 * K then
            for _, b in ipairs(bases) do
              if b.alive then
                local d = abs(b.x - m.x)
                if d < best then best, tx = d, b.x end
              end
            end
          end
          if tx then
            local d = tx - m.x
            local want = abs(d) < 0.6 and d * 0.5 or clamp(d * 1.8, -2.4, 2.4)
            local f = dt * 4
            if f > 1 then f = 1 end
            m.vx = m.vx + (want - m.vx) * f
          else
            local f = 1 - dt * 3
            if f < 0 then f = 0 end
            m.vx = m.vx * f
          end
          m.x = m.x + m.vx * dt
        end
        if not m.air then m.phase = m.phase + dt * (m.spd / K * 3.2 / sqrt(m.scale)) end
        local lim = LH - 0.32 * m.scale
        m.x = clamp(m.x, -lim, lim)
        if not celebrate then
          for _, gt in ipairs(gates) do
            if pz > gt.z and m.z <= gt.z and not hasBit(m.passed, gt.bit) and abs(m.x - gt.x) < gt.w / 2 then
              m.passed = m.passed + gt.bit
              multiply(m, gt)
            end
          end
        end
        if G.state == 'playing' then
          for _, b in ipairs(bases) do
            if b.alive and m.z <= b.front and abs(m.x - b.x) < b.hw + 0.05 then hitBase(b, m); break end
          end
        end
        if m.z < -LEN - 1 then m.dead = true end
      else
        if G.state == 'lost' then
          if rnd() < dt * 1.5 and not m.air then m.air = true; m.vy = 3; m.airV = 0 end
          if m.air then
            m.vy = m.vy - 20 * dt
            m.y = m.y + m.vy * dt
            if m.y <= 0 then m.y = 0; m.air = false end
          end
        elseif G.state == 'playing' then
          m.z = m.z + m.spd * dt
          m.x = m.x + m.vx * dt
          local f = 1 - dt * 1.5
          if f < 0 then f = 0 end
          m.vx = m.vx * f
          m.phase = m.phase + dt * m.spd / K * 3.2 / sqrt(m.scale)
          if m.z > LOSE_Z then lose() end
        end
        local lim = LH - 0.32 * m.scale
        m.x = clamp(m.x, -lim, lim)
      end
    end
    i = i + 1
  end

  for _, sp in ipairs(spinners) do
    local ca, sa = cos(sp.a), sin(sp.a)
    for j = 1, #mobs do
      local m = mobs[j]
      if not m.dead and not m.air and m.kind == 0 then
        local dz = m.z - sp.z
        if dz <= sp.R + 0.5 and dz >= -sp.R - 0.5 then
          local dx = m.x - sp.x
          local t = clamp(dx * ca - dz * sa, -sp.R, sp.R)
          local ex, ez = dx - t * ca, dz + t * sa
          if ex * ex + ez * ez < 0.09 then kill(m, true); sfx('spin') end
        end
      end
    end
  end

  collide()

  local w = 0
  local n = #mobs
  for j = 1, n do
    local m = mobs[j]
    if m.dead then
      if m.team == 1 then G.eCount = G.eCount - 1 else G.pCount = G.pCount - 1 end
      pool[#pool + 1] = m
    else
      w = w + 1
      mobs[w] = m
    end
  end
  for j = n, w + 1, -1 do mobs[j] = nil end

  local pw = 0
  local pn = #parts
  for j = 1, pn do
    local p = parts[j]
    p.t = p.t + dt
    if p.t >= p.life then
      partPool[#partPool + 1] = p
    else
      p.vy = p.vy - 14 * dt
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
      p.z = p.z + p.vz * dt
      if p.y < 0.05 then p.y = 0.05; p.vy = p.vy * -0.35; p.vx = p.vx * 0.6; p.vz = p.vz * 0.6 end
      pw = pw + 1
      parts[pw] = p
    end
  end
  for j = pn, pw + 1, -1 do parts[j] = nil end

  for _, b in ipairs(bases) do
    if b.flash > 0 then b.flash = b.flash - dt * 7; if b.flash < 0 then b.flash = 0 end end
    if b.dying >= 0 and b.dying < 1 then
      b.dying = b.dying + dt * 1.6
      if b.dying > 1 then b.dying = 1 end
    end
  end

  if G.state == 'won' or G.state == 'lost' then
    G.endT = G.endT + dt
    if not G.resultShown and G.endT > (G.state == 'won' and 1.8 or 1.2) then
      G.resultShown = true
      showResult(G.state == 'won')
    end
  end
end
end

local DEFAULT_FOCUS = {menu = 'play', shop = 'shAct', result = 'resNext', pause = 'pResume'}

show = function(id)
  ui.screen = id
  ui.btns = {}
  ui.focus = id and DEFAULT_FOCUS[id] or nil
end

toast = function(t)
  ui.toast = t
  ui.toastT = 1.6
end

play = function()
  if G.state ~= 'menu' then buildLevel(save.level) end
  G.state = scene.pending() > 0 and 'loading' or 'playing'
  G.eTimer = 2.4
  G.loadT = 0
  show(nil)
  ui.hint = save.level <= 2
  ui.hintT = 7
end

pause = function()
  if G.state ~= 'playing' or G.paused then return end
  G.paused = true
  keys.left, keys.right, keys.tapL, keys.tapR = false, false, 0, 0
  show('pause')
end

resume = function()
  G.paused = false
  show(nil)
end

toMenu = function()
  G.paused = false
  buildLevel(save.level)
  show('menu')
end

showResult = function(won)
  ui.result = {won = won, art = G.art}
  if won then sfx('coin') end
  show('result')
end

openShop = function(from)
  ui.shopReturn = from
  show('shop')
  shop.idx = skinIdx(save.equipped)
  shop.pos = shop.idx
  shop.spinT = 0
  scene.set_shop(shop.idx)
end

closeShop = function()
  show(ui.shopReturn)
  scene.set_shop(nil)
end

local function equip(i)
  save.equipped = SKINS[i].id
  persist()
  prepareAssets()
end

local function shopStep(d)
  local ni = clamp(shop.idx + d, 1, #SKINS)
  if ni ~= shop.idx then
    shop.idx = ni
    shop.spinT = 0
    scene.set_shop(ni)
    sfx('nav')
  end
end

local function shopAction()
  local i = shop.idx
  local s = SKINS[i]
  if save.equipped == s.id then sfx('click'); return end
  if owns(s.id) then
    equip(i)
    sfx('click')
    toast(s.name .. ' no canhão')
    shop.popT = 0.45
    return
  end
  if save.coins >= s.price then
    save.coins = save.coins - s.price
    save.owned[#save.owned + 1] = s.id
    equip(i)
    sfx('coin')
    toast(s.name .. ' é seu!')
    shop.popT = 0.45
    return
  end
  sfx('deny')
  shop.shakeT = 0.3
  toast('Faltam ' .. (s.price - save.coins) .. ' moedas')
end

local function toggleMix()
  save.mixed = not save.mixed
  persist()
  prepareAssets()
  sfx('click')
end

local function toggleMute()
  save.muted = not save.muted
  persist()
  sfx('click')
end

local function handleBack()
  if ui.screen == 'shop' then sfx('click'); closeShop(); return end
  if ui.screen == 'pause' then sfx('click'); resume(); return end
  if ui.screen == 'result' then sfx('click'); toMenu(); return end
  if not ui.screen and G.state == 'playing' then pause(); return end
  if not ui.screen and G.state == 'loading' then sfx('click'); toMenu(); return end
  if ui.screen == 'menu' then ui.quit() end
end

local function nav(dir)
  local list = ui.btns
  if #list == 0 then return end
  local cur
  for _, b in ipairs(list) do if b.id == ui.focus then cur = b end end
  if not cur then ui.focus = DEFAULT_FOCUS[ui.screen]; return end
  local cx, cy = cur.x + cur.w / 2, cur.y + cur.h / 2
  local best, bs = nil, 1e9
  for _, b in ipairs(list) do
    if b ~= cur then
      local x, y = b.x + b.w / 2 - cx, b.y + b.h / 2 - cy
      local along = (dir == 'left' and -x) or (dir == 'right' and x) or (dir == 'up' and -y) or y
      local ortho = (dir == 'left' or dir == 'right') and y or x
      if along >= 6 then
        local s = along + abs(ortho) * 2.2
        if s < bs then bs, best = s, b end
      end
    end
  end
  if best then ui.focus = best.id; sfx('nav') end
end

local function activate()
  for _, b in ipairs(ui.btns) do
    if b.id == ui.focus then b.act(); return end
  end
  ui.focus = DEFAULT_FOCUS[ui.screen]
end

local drawScene
do
local NB, BZ0, BZS = 290, -24, 0.1
local bHead, iNext, iKind, iRef = {}, {}, {}, {}
local mHead, mNext, mRef = {}, {}, {}
local nItems, nMobItems = 0, 0

local function bucketOf(z)
  local b = floor((z - BZ0) / BZS) + 1
  if b < 1 then return 1 end
  if b > NB then return NB end
  return b
end

local function addItem(z, kind, ref)
  local b = bucketOf(z)
  nItems = nItems + 1
  iKind[nItems], iRef[nItems] = kind, ref
  iNext[nItems] = bHead[b]
  bHead[b] = nItems
end

local function addMob(z, m)
  local b = bucketOf(z)
  nMobItems = nMobItems + 1
  mRef[nMobItems] = m
  mNext[nMobItems] = mHead[b]
  mHead[b] = nMobItems
end

local K_PART, K_GATE, K_SPIN, K_BASE, K_CANNON = 2, 3, 4, 6, 7
local CANNON_Z = 0.75
local batch, shadowList, pbatch, bucketKey = {}, {}, {}, nil

local function drawItem(j)
  local kind = iKind[j]
  if kind == K_GATE then scene.draw_gate(iRef[j])
  elseif kind == K_SPIN then scene.draw_spinner(iRef[j])
  elseif kind == K_BASE then scene.draw_base(iRef[j])
  elseif kind == K_CANNON then scene.draw_cannon(cannon, save.equipped) end
end

drawScene = function()
  scene.begin_frame(shakeOX, shakeOY)
  scene.draw_background()
  for b = 1, NB do bHead[b] = 0; mHead[b] = 0 end
  nItems, nMobItems = 0, 0
  for _, gt in ipairs(gates) do addItem(gt.z, K_GATE, gt) end
  for _, sp in ipairs(spinners) do addItem(sp.z, K_SPIN, sp) end
  for _, b in ipairs(bases) do if b.dying < 1 then addItem(b.z, K_BASE, b) end end
  addItem(CANNON_Z, K_CANNON, cannon)
  local ns = 0
  for i = 1, #mobs do
    local m = mobs[i]
    if not m.dead then
      addMob(m.z, m)
      ns = ns + 1
      shadowList[ns] = m
    end
  end
  local pn = #parts
  local stride = pn > PART_DRAW_MAX and ceil(pn / PART_DRAW_MAX) or 1
  for i = 1, pn, stride do addItem(parts[i].z, K_PART, parts[i]) end
  scene.draw_shadows(shadowList, ns)
  if not bucketKey then
    bucketKey = {}
    for b = 1, NB do bucketKey[b] = scene.batch_key(BZ0 + (b - 0.5) * BZS) end
  end
  local nb, np, curKey = 0, 0, -1
  local function flushBatch()
    if nb > 0 then scene.draw_mobs(batch, nb) end
    for i = 1, np do scene.draw_particle(pbatch[i]); pbatch[i] = nil end
    nb, np = 0, 0
  end
  for b = 1, NB do
    local key = bucketKey[b]
    if key ~= curKey then
      if nb > 0 or np > 0 then flushBatch() end
      curKey = key
    end
    local j = bHead[b]
    while j ~= 0 do
      if iKind[j] == K_PART then
        np = np + 1
        pbatch[np] = iRef[j]
      else
        if nb > 0 or np > 0 then flushBatch() end
        drawItem(j)
      end
      j = iNext[j]
    end
    j = mHead[b]
    while j ~= 0 do
      nb = nb + 1
      batch[nb] = mRef[j]
      j = mNext[j]
    end
  end
  flushBatch()
  for _, b in ipairs(bases) do
    if b.alive then scene.draw_base_label(b) end
  end
end
end

local PADL, PADT, PADB = 0, 0, 0
local u, drawUI, resetTextCaches
do
u = function(v) return floor(v * Z + 0.5) end

local fontPx = 0
local function font(css)
  local px = floor(css * Z + 0.5)
  if px ~= fontPx then textFontSize(px); fontPx = px end
end
local mcache, mcount = {}, 0
local measurePending = false
local function measure(s)
  local key = fontPx .. '\1' .. s
  local e = mcache[key]
  if e then return e[1], e[2] end
  local w, h = textMensure(s)
  w, h = w or 0, h or 0
  if s ~= '' and (w <= 0 or h <= 0) then
    measurePending = true
    return 0, fontPx
  end
  if mcount > 800 then mcache, mcount = {}, 0 end
  mcache[key] = {w, h}
  mcount = mcount + 1
  return w, h
end
local function txt(s, x, y, c)
  colorSet(c)
  textPrint(floor(x), floor(y), s)
end
local function txtB(s, x, y, c)
  txt(s, x, y, c)
  txt(s, x + (fontPx >= 48 and 2 or 1), y, c)
end
local function txtSh(s, x, y, c, shc, dy)
  if shc then txtB(s, x, y + dy, shc) end
  txtB(s, x, y, c)
end

local wcache = {}
local function wrap(s, maxw)
  local key = fontPx .. '\1' .. maxw .. '\1' .. s
  local r = wcache[key]
  if r then return r end
  r = {}
  measurePending = false
  local line = ''
  for word in string.gmatch(s, '%S+') do
    local cand = line == '' and word or (line .. ' ' .. word)
    if measure(cand) > maxw and line ~= '' then
      r[#r + 1] = line
      line = word
    else
      line = cand
    end
  end
  if line ~= '' then r[#r + 1] = line end
  if not measurePending then wcache[key] = r end
  return r
end

local function panel(x, y, w, h, face, edge, drop, b)
  b = b or u(3)
  if drop then fill(rgba(INK, 89), x - b, y + h, w + 2 * b, b + u(5)) end
  fill(rgba(INK), x - b, y, w + 2 * b, h)
  fill(rgba(INK), x, y - b, w, h + 2 * b)
  fill(rgba(face), x, y, w, h)
  fill(rgba(edge), x, y + h - u(4), w, u(4))
  fill(rgba(WHITE, 107), x, y, w, u(3))
end

local function icon(name, x, y, size)
  local t = ICON_T[name]
  local cell = floor(size / t.cols)
  if cell < 1 then cell = 1 end
  local ox = floor(x + (size - cell * t.cols) / 2)
  local oy = floor(y + (size - cell * t.rows) / 2)
  sprDown(t, ox, oy, cell, cell, 1, 0, 0)
end

local function ring(x, y, w, h, off)
  local c = (floor(T / 0.45) % 2 == 0) and rgba(GOLD) or rgba(WHITE)
  local o, t = off or u(6), u(4)
  fill(c, x - o - t, y - o - t, w + 2 * (o + t), t)
  fill(c, x - o - t, y + h + o, w + 2 * (o + t), t)
  fill(c, x - o - t, y - o, t, h + 2 * o)
  fill(c, x + w + o, y - o, t, h + 2 * o)
end

local function regBtn(id, x, y, w, h, act)
  ui.btns[#ui.btns + 1] = {id = id, x = x, y = y, w = w, h = h, act = act}
end

local function keycapW(k)
  if ICON_T[k] then return u(10) + 2 * u(6) > u(24) and u(10) + 2 * u(6) or u(24) end
  font(12)
  local w = measure(k)
  local m = w + 2 * u(6)
  if m < u(24) then m = u(24) end
  return m
end

local function keycap(k, x, y)
  local w, h = keycapW(k), u(22)
  fill(rgba(INK), x, y, w, h)
  fill(rgba(0x000000), x, y + h - u(3), w, u(3))
  if ICON_T[k] then
    local s = u(10)
    icon(k, x + (w - s) / 2, y + (h - u(3) - s) / 2, s)
  else
    font(12)
    local tw, th = measure(k)
    txtB(k, x + (w - tw) / 2, y + (h - u(3) - th) / 2, rgba(WHITE))
  end
  return w
end

local LEG_GAME = {{{'arrowL', 'arrowR'}, 'MIRAR'}, {{'OK'}, 'GIGANTE'}, {{'VOLTAR'}, 'PAUSA'}}
local LEG_SHOP = {{{'arrowL', 'arrowR'}, 'TROCAR'}, {{'OK'}, 'ESCOLHER'}}

local function legendW(L)
  local total = 0
  for i, it in ipairs(L) do
    if i > 1 then total = total + u(18) end
    for _, k in ipairs(it[1]) do total = total + keycapW(k) end
    font(13)
    total = total + u(5) + measure(it[2])
  end
  return total
end

local function legend(L, cx, y, onDark)
  local x = floor(cx - legendW(L) / 2)
  for i, it in ipairs(L) do
    if i > 1 then x = x + u(18) end
    for _, k in ipairs(it[1]) do x = x + keycap(k, x, y) end
    x = x + u(5)
    font(13)
    local tw, th = measure(it[2])
    local ty = y + (u(22) - th) / 2
    if onDark then txtSh(it[2], x, ty, rgba(WHITE), rgba(INK), u(2)) else txtB(it[2], x, ty, rgba(INK)) end
    x = x + tw
  end
end

local function chipSize(text, withIcon)
  font(15)
  local tw, th = measure(text)
  local ch = th
  local w = u(10) + tw + u(10)
  if withIcon then w = w + u(16) + u(7); if u(16) > ch then ch = u(16) end end
  return w, u(8) + ch + u(10)
end

local function chip(x, y, text, withIcon, face)
  local w, h = chipSize(text, withIcon)
  panel(x, y, w, h, face, CREAM_D, false)
  font(15)
  local tw, th = measure(text)
  local cx = x + u(10)
  local inner = h - u(18)
  if withIcon then
    icon('coin', cx, y + u(8) + (inner - u(16)) / 2, u(16))
    cx = cx + u(16) + u(7)
  end
  txtB(text, cx, y + u(8) + (inner - th) / 2, rgba(INK))
  return w, h
end

local function iconBtn(id, x, y, size, ic, act, disabled)
  local focused = id and ui.focus == id
  if disabled then GA = 0.35 end
  panel(x, y, size, size, CREAM, CREAM_D, true)
  local is = floor(size * 18 / 40)
  icon(ic, x + (size - is) / 2, y + (size - u(3) - is) / 2, is)
  GA = 1
  if id and act then regBtn(id, x, y, size, size, act) end
  if focused then ring(x, y, size, size) end
end

local STY = {
  pink = {face = PINK, edge = PINK_D, text = WHITE, sh = PINK_D},
  mint = {face = MINT, edge = MINT_D, text = WHITE, sh = MINT_D},
  cream = {face = CREAM, edge = CREAM_D, text = INK},
  eqd = {face = 0xeaffc0, edge = 0xbfe36a, text = 0x2f6a2a},
  poor = {face = 0xddcbe2, edge = 0xbba5c2, text = PLUM},
}

local function partsSize(parts, css, ics)
  font(css)
  local w, h = 0, 0
  for i, p in ipairs(parts) do
    if i > 1 then w = w + u(8) end
    if p.i then
      w = w + u(ics)
      if u(ics) > h then h = u(ics) end
    else
      local tw, th = measure(p.t)
      w = w + tw
      if th > h then h = th end
    end
  end
  return w, h
end

local function drawParts(parts, css, ics, x, y, h, color, shc)
  font(css)
  for i, p in ipairs(parts) do
    if i > 1 then x = x + u(8) end
    if p.i then
      icon(p.i, x, y + (h - u(ics)) / 2, u(ics))
      x = x + u(ics)
    else
      local tw, th = measure(p.t)
      txtSh(p.t, x, y + (h - th) / 2, color, shc, u(2))
      x = x + tw
    end
  end
end

local function btnSize(parts, big, sub)
  local cw, ch = partsSize(parts, big and 26 or 18, 20)
  local padX = big and u(34) or u(20)
  local h = (big and u(14) or u(13)) + ch + (big and u(18) or u(16))
  local w = cw + 2 * padX
  if sub then
    font(12)
    local sw, sh = measure(sub)
    h = h + sh + u(6)
    if sw + 2 * padX > w then w = sw + 2 * padX end
  end
  return w, h
end

local function button(id, x, y, w, h, style, parts, big, sub, act, dx)
  local st = STY[style]
  local focused = ui.focus == id
  if focused then y = y - u(3) end
  x = x + (dx or 0)
  panel(x, y, w, h, st.face, st.edge, true)
  local cw, ch = partsSize(parts, big and 26 or 18, 20)
  local ty = y + (big and u(14) or u(13))
  if sub then
    font(12)
    local sw, sh = measure(sub)
    txtB(sub, x + (w - sw) / 2, ty, rgba(st.text, 230))
    ty = ty + sh + u(6)
  end
  drawParts(parts, big and 26 or 18, 20, x + (w - cw) / 2, ty, ch, rgba(st.text), st.sh and rgba(st.sh) or nil)
  regBtn(id, x, y, w, h, act)
  if focused then ring(x, y, w, h) end
end

local function T1(s) return {{t = s}} end

local function hop(period, delay)
  return (floor((T + (delay or 0)) / (period / 2)) % 2 == 1) and -u(4) or 0
end

local function thumbAt(skin_id, kind, cx, bottom)
  local size = scene.thumb_size(kind)
  scene.draw_thumb(skin_id, kind, floor(cx - size / 2), floor(bottom - size))
end

local function drawMenu()
  for i = 0, 7 do
    local y0 = floor(H * (0.45 + 0.55 * i / 8))
    local y1 = floor(H * (0.45 + 0.55 * (i + 1) / 8))
    fill(rgba(INK, floor(127 * (i + 0.5) / 8)), 0, y0, W, y1 - y0)
  end
  local ib = u(40)
  local top = PADT
  local _, chh = chipSize(tostring(save.coins), true)
  chip(PADL, top + (ib - chh) / 2, tostring(save.coins), true, 0xfff7e0)
  iconBtn('mute', W - PADL - ib, top, ib, save.muted and 'soundOff' or 'soundOn', toggleMute)

  local legY = H - PADB - u(22)
  legend(LEG_GAME, W / 2, legY, true)
  local sw, sh = btnSize(T1('SABORES'), false)
  local sabY = legY - u(12) - sh
  local sub = 'FASE ' .. save.level
  local pw, ph = btnSize(T1('JOGAR'), true, sub)
  local playY = sabY - u(12) - ph
  button('play', floor((W - pw) / 2), playY, pw, ph, 'pink', T1('JOGAR'), true, sub, function() sfx('click'); play() end)
  button('skins', floor((W - sw) / 2), sabY, sw, sh, 'mint', T1('SABORES'), false, nil, function() sfx('click'); openShop('menu') end)

  font(84)
  local hw, hh = measure('GOMINHOS')
  local h1H = floor(84 * Z * 0.9)
  font(15)
  local maxw = floor(measure('0') * 30)
  local lines = wrap('Dispare gominhos, multiplique nos portais e derrube a fortaleza dos Azedinhos.', maxw)
  local lh = floor(15 * Z * 1.35)
  local pW = 0
  for _, l in ipairs(lines) do local lw = measure(l); if lw > pW then pW = lw end end
  local pH = #lines * lh + u(8) + u(10)
  local logoH = u(150) + u(10) + h1H + u(10) + u(6) + pH
  local topEnd = top + ib + u(14)
  local botStart = playY - u(14)
  local ly = topEnd + (botStart - topEnd - logoH) / 2 - u(21)
  if ly < topEnd then ly = topEnd end
  local mb = ly + u(150)
  local hero, enemy = scene.thumb_size('hero'), scene.thumb_size('enemy')
  local mx = W / 2 - (hero + u(2) + enemy) / 2
  thumbAt(save.equipped, 'hero', mx + hero / 2, mb + hop(0.7, 0))
  thumbAt(ENEMY.id, 'enemy', mx + hero + u(2) + enemy / 2, mb + hop(0.7, 0.35))
  local hy = mb + u(10) + (h1H - hh) / 2
  local hx0 = W / 2 - hw / 2
  font(84)
  local o = u(5)
  local offs = {{o, 0}, {-o, 0}, {0, -o}, {o, o}, {-o, o}, {0, 2 * o}, {o, 2 * o}, {-o, 2 * o}, {o, -o}, {-o, -o}}
  for _, of in ipairs(offs) do txtB('GOMINHOS', hx0 + of[1], hy + of[2], rgba(INK)) end
  txtB('GOMINHOS', hx0, hy + o, rgba(PINK_D))
  txtB('GOMINHOS', hx0, hy, rgba(WHITE))
  local py = mb + u(10) + h1H + u(10) + u(6)
  local boxW = pW + 2 * u(12)
  local bx = floor(W / 2 - boxW / 2)
  panel(bx, py, boxW, pH, CREAM, CREAM_D, false)
  font(15)
  for i, l in ipairs(lines) do
    local lw = measure(l)
    txtB(l, W / 2 - lw / 2, py + u(8) + (i - 1) * lh + (lh - floor(15 * Z)) / 2, rgba(INK))
  end
end

local drawHud
do
local function drawHint()
  if floor(T / 0.6) % 2 == 1 then GA = 0.55 end
  font(14)
  local t1, t2 = 'mirar, o canhão atira sozinho', 'gigante'
  local w1 = measure(t1)
  local w2 = measure(t2)
  local kw = keycapW('arrowL') + keycapW('arrowR') + keycapW('OK')
  local w = u(14) + kw + u(6) * 5 + w1 + u(4) + w2 + u(14)
  local h = u(9) + u(22) + u(11)
  local x, y = PADL, H - (u(16) + OSY) - h
  panel(x, y, w, h, CREAM, CREAM_D, false)
  local cx, cy = x + u(14), y + u(9)
  cx = cx + keycap('arrowL', cx, cy) + u(6)
  cx = cx + keycap('arrowR', cx, cy) + u(6)
  font(14)
  local _, th = measure(t1)
  local ty = cy + (u(22) - th) / 2
  txtB(t1, cx, ty, rgba(INK))
  cx = cx + w1 + u(6)
  fill(rgba(INK), cx - u(2), cy + u(9), u(4), u(4))
  cx = cx + u(4) + u(6)
  cx = cx + keycap('OK', cx, cy) + u(6)
  font(14)
  txtB(t2, cx, ty, rgba(INK))
  GA = 1
end

local function drawChamp()
  local w, h = u(78), u(94)
  local x = W - (u(16) + OSX) - w
  local y = H - (u(16) + OSY) - h
  local c = G.charge / CHARGE_MAX
  local ready = c >= 1
  if ready then y = y + hop(0.5, 0) end
  local face, edge = ready and GOLD or PLUM, ready and GOLD_D or PLUM_D
  panel(x, y, w, h, face, edge, true)
  local mh = floor(h * (c > 1 and 1 or c))
  if mh > 0 then
    local ca, cb = ready and 0xffe27a or 0x7b4a8a, ready and GOLD or 0x6a3c78
    fill(rgba(cb), x, y + h - mh, w, mh)
    local yy = y + h
    while yy > y + h - mh do
      local t = yy - u(4)
      if t < y + h - mh then t = y + h - mh end
      fill(rgba(ca), x, t, w, yy - t)
      yy = yy - u(8)
    end
  end
  font(11)
  local lw, lh = measure('GIGANTE')
  local ly = y + h - u(9) - lh
  thumbAt(save.equipped, ready and 'champ' or 'champ_dim', x + w / 2, ly)
  font(11)
  txtB('GIGANTE', x + (w - lw) / 2, ly, rgba(ready and INK or WHITE))
  keycap('OK', x + (w - keycapW('OK')) / 2, y + u(7))
end

drawHud = function()
  local top = u(10) + OSY
  local ib = u(40)
  local lt = 'FASE ' .. G.level
  local _, lch = chipSize(lt, false)
  chip(PADL, top + (ib - lch) / 2, lt, false, CREAM)
  local pbx = W - PADL - ib
  iconBtn(nil, pbx, top, ib, 'pause')
  local ct = tostring(save.coins)
  local cw, cch = chipSize(ct, true)
  chip(pbx - u(14) - cw, top + (ib - cch) / 2, ct, true, 0xfff7e0)
  if ui.hint and ui.hintT > 0 then drawHint() end
  drawChamp()
end
end

local function drawToast()
  if not ui.toast or ui.toastT <= 0 then return end
  font(15)
  local tw, th = measure(ui.toast)
  local w, h = tw + 2 * u(14), u(9) + th + u(12)
  local x, y = floor(W / 2 - w / 2), floor(H * 0.7 - h)
  panel(x, y, w, h, CREAM, CREAM_D, false)
  txtB(ui.toast, x + u(14), y + u(9), rgba(INK))
end

local drawResult, drawPause
do
local function centeredPanel(contentH)
  local pw = u(460)
  if pw > W - 2 * PADL then pw = W - 2 * PADL end
  local ph = u(18) + contentH + u(20)
  local x = floor((W - pw) / 2)
  local y = floor((H - ph) / 2)
  panel(x, y, pw, ph, CREAM, CREAM_D, false)
  return x + u(18), y + u(18), pw - 2 * u(18)
end

drawResult = function()
  fill(rgba(INK, 140), 0, 0, W, H)
  local r = ui.result
  local won = r.won
  local title = won and 'Fortaleza derrubada!' or 'Os Azedinhos passaram!'
  local sub = won and ('Fase ' .. G.level .. ' concluída. ' .. G.kills .. ' Azedinhos viraram confete.') or 'Eles chegaram no canhão. Mire nos portais de x3 e x4 pra encher o campo de gominhos.'
  local inner = u(460) - 2 * u(18)
  font(28)
  local tw, th = measure(title)
  font(15)
  local lines = wrap(sub, inner)
  local lh = floor(15 * Z * 1.35)
  local next = won and 'PRÓXIMA FASE' or 'TENTAR DE NOVO'
  local _, nh = btnSize(T1(next), true)
  local _, sh2 = btnSize(T1('SABORES'), false)
  local gap = u(12)
  local rewardH = won and u(36) or 0
  local contentH = u(110) + gap + th + gap + #lines * lh + (won and (gap + rewardH) or 0) + gap + u(4) + nh + gap + sh2
  local ix, iy, iw = centeredPanel(contentH)
  local cx = ix + iw / 2
  local ab = iy + u(110)
  local sz = u(96)
  if won then
    local delays = {0, 0.27, 0.4}
    for k = 1, 3 do thumbAt(r.art[k], 'result', cx + (k - 2) * (sz + u(4)), ab + hop(0.55, delays[k])) end
  else
    thumbAt(ENEMY.id, 'result', cx - (sz + u(4)) / 2, ab + hop(0.55, 0))
    thumbAt(ENEMY.id, 'result', cx + (sz + u(4)) / 2, ab + hop(0.55, 0.27))
  end
  local y = ab + gap
  font(28)
  txtB(title, cx - tw / 2, y, rgba(INK))
  y = y + th + gap
  font(15)
  for _, l in ipairs(lines) do
    local lw = measure(l)
    txt(l, cx - lw / 2, y, rgba(INK))
    y = y + lh
  end
  if won then
    y = y + gap
    font(30)
    local rt = '+' .. G.reward
    local rw, rh = measure(rt)
    local total = u(28) + u(10) + rw
    local rx = cx - total / 2
    icon('coin', rx, y + (rewardH - u(28)) / 2, u(28))
    txtB(rt, rx + u(28) + u(10), y + (rewardH - rh) / 2, rgba(INK))
    y = y + rewardH
  end
  y = y + gap + u(4)
  button('resNext', ix, y, iw, nh, 'pink', T1(next), true, nil, function() sfx('click'); buildLevel(save.level); play() end)
  y = y + nh + gap
  button('resShop', ix, y, iw, sh2, 'mint', T1('SABORES'), false, nil, function() sfx('click'); openShop('result') end)
end

drawPause = function()
  fill(rgba(INK, 140), 0, 0, W, H)
  font(28)
  local tw, th = measure('Pausado')
  font(15)
  local st = 'Fase ' .. G.level
  local sw, sh = measure(st)
  local _, h1 = btnSize(T1('CONTINUAR'), true)
  local _, h2 = btnSize(T1('RECOMEÇAR FASE'), false)
  local _, h3 = btnSize(T1('MENU'), false)
  local gap = u(12)
  local contentH = th + gap + sh + gap + u(4) + h1 + gap + h2 + gap + h3 + gap + u(22)
  local ix, iy, iw = centeredPanel(contentH)
  local cx = ix + iw / 2
  font(28)
  txtB('Pausado', cx - tw / 2, iy, rgba(INK))
  local y = iy + th + gap
  font(15)
  txt(st, cx - sw / 2, y, rgba(INK))
  y = y + sh + gap + u(4)
  button('pResume', ix, y, iw, h1, 'pink', T1('CONTINUAR'), true, nil, function() sfx('click'); resume() end)
  y = y + h1 + gap
  button('pRestart', ix, y, iw, h2, 'cream', T1('RECOMEÇAR FASE'), false, nil, function() sfx('click'); G.paused = false; buildLevel(save.level); play() end)
  y = y + h2 + gap
  button('pMenu', ix, y, iw, h3, 'mint', T1('MENU'), false, nil, function() sfx('click'); toMenu() end)
  y = y + h3 + gap
  legend(LEG_GAME, cx, y, false)
end

end

local drawShop
do
local function rays(cx, cy, s)
  for k = 0, 13, 2 do
    local am = -pi + (k + 0.5) * 2 * pi / 14
    local ca, sa = cos(am), sin(am)
    local r = 6
    while r < 38 do
      local size = r * 2 * pi / 14
      local rm = r + size / 2
      local al = rm < 20 and 0.5 or (rm < 30 and 0.36 or 0.22)
      local bx, by = cx + ca * rm * s, cy + sa * rm * s
      local hs = size * s / 2
      fill(rgba(WHITE, floor(al * 255)), floor(bx - hs), floor(by - hs), floor(hs * 2), floor(hs * 2))
      r = r + size
    end
  end
end

local function drawTag(i, cx, y, sc, tint, q)
  local sk = SKINS[i]
  local eq, own = save.equipped == sk.id, owns(sk.id)
  local bg = eq and 0x2f8a3e or (own and MINT_D or PLUM)
  local parts = eq and T1('NO CANHÃO') or (own and T1('SEU') or {{i = 'coin'}, {t = tostring(sk.price)}})
  local css = 12 * sc
  local cw, ch = partsSize(parts, css, css)
  local w, h = cw + 2 * u(7 * sc), ch + u(4 * sc) + u(5 * sc)
  local x = floor(cx - w / 2)
  fill(mixc(rgba(bg), tint, q), x, y, w, h)
  font(css)
  local px0 = x + u(7 * sc)
  for k, p in ipairs(parts) do
    if k > 1 then px0 = px0 + u(8) end
    if p.i then
      icon('coin', px0, y + (h - u(css)) / 2, u(css))
      px0 = px0 + u(css)
    else
      local tw, th = measure(p.t)
      txtB(p.t, px0, y + (h - th) / 2, mixc(rgba(WHITE), tint, q))
      px0 = px0 + tw
    end
  end
  return h
end

local function drawStage(x, y, w, h)
  local sk = SKINS[shop.idx]
  local bg = mixRgb(sk.light, CREAM, 0.55)
  fill(rgba(bg), x, y, w, h)
  clipOn, clx0, cly0, clx1, cly1 = true, x, y, x + w, y + h
  rays(x + w / 2, y + h * 0.46, h * 1.5 / 80)
  local mainS, sideS = scene.thumb_size('shop'), scene.thumb_size('shop_side')
  local slideW = w / 2 - sideS / 2 - u(8)
  local cyMid = y + h / 2
  local popStep = shop.popT > 0 and floor((0.45 - shop.popT) / 0.45 * 4) or -1
  local popLift = (popStep == 1 or popStep == 2) and -u(10) or 0
  for pass = 1, 2 do
    for i = 1, #SKINS do
      local d = i - shop.pos
      local main = i == shop.idx and abs(d) < 0.5
      if abs(d) <= 1 and (main == (pass == 2)) then
        local size = main and mainS or sideS
        local sc = main and 1 or 0.68
        local scx = x + w / 2 + d * slideW
        local top = cyMid - (size + u(4) + u(26) * sc) / 2
        if main then
          local cyc = 1.4 + 24 * 0.09
          local tt = shop.spinT % cyc
          local frame = tt < 1.4 and 0 or floor((tt - 1.4) / 0.09) % 24
          top = top + (popLift ~= 0 and popLift or hop(0.6, 0))
          scene.draw_thumb(SKINS[i].id, 'shop', floor(scx - size / 2), floor(top), frame)
        else
          scene.draw_thumb(SKINS[i].id, 'shop_side', floor(scx - size / 2), floor(top))
        end
        drawTag(i, scx, top + size + u(4), sc, bg, main and 0 or 7)
      end
    end
  end
  clipOn = false
  fill(rgba(CREAM_D), x, y, w, u(3))
  fill(rgba(CREAM_D), x, y + h - u(3), w, u(3))
  fill(rgba(CREAM_D), x, y + u(3), u(3), h - u(6))
  fill(rgba(CREAM_D), x + w - u(3), y + u(3), u(3), h - u(6))
  fill(rgba(INK, 15), x + u(3), y + h - u(13), w - u(6), u(10))
  local as = u(44)
  local ay = y + h / 2 - u(23)
  iconBtn(nil, x + u(12), ay, as, 'arrowLd', nil, shop.idx == 1)
  iconBtn(nil, x + w - u(12) - as, ay, as, 'arrowRd', nil, shop.idx == #SKINS)
end

drawShop = function()
  fill(rgba(INK, 140), 0, 0, W, H)
  local pw = u(1000)
  if pw > W - 2 * PADL then pw = W - 2 * PADL end
  local ph = u(660)
  if ph > H - PADT - PADB then ph = H - PADT - PADB end
  local px0 = floor((W - pw) / 2)
  local py0 = floor(PADT + (H - PADT - PADB - ph) / 2)
  panel(px0, py0, pw, ph, CREAM, CREAM_D, false)
  local ix, iy = px0 + u(16), py0 + u(16)
  local iw, ih = pw - u(32), ph - u(16) - u(18)
  local ib = u(40)
  font(28)
  local _, hh = measure('Sabores')
  txtB('Sabores', ix, iy + (ib - hh) / 2, rgba(INK))
  iconBtn('close', ix + iw - ib, iy, ib, 'close', function() sfx('click'); closeShop() end)
  local ct = tostring(save.coins)
  local cw, ch = chipSize(ct, true)
  chip(ix + iw - ib - u(10) - cw, iy + (ib - ch) / 2, ct, true, 0xfff7e0)
  local by = iy + ib + u(12)
  local bh = iy + ih - by
  local stw = floor((iw - u(12)) * 1.25 / 2.25)
  drawStage(ix, by, stw, bh)

  local infx = ix + stw + u(12)
  local infw = iw - stw - u(12)
  local cx = infx + infw / 2
  local sk = SKINS[shop.idx]
  local gap = u(8)
  local count = 'SABOR ' .. shop.idx .. ' DE ' .. #SKINS
  font(12)
  local cntW, cntH = measure(count)
  font(36)
  local nmW, nmH = measure(sk.name)
  font(15)
  local maxw = floor(measure('0') * 32)
  if maxw > infw - u(16) then maxw = infw - u(16) end
  local lines = wrap(FLAVOR[sk.id], maxw)
  local lh = floor(15 * Z * 1.35)
  local descH = #lines * lh
  if descH < floor(15 * Z * 2.7) then descH = floor(15 * Z * 2.7) end
  local eq, own = save.equipped == sk.id, owns(sk.id)
  local poor = not own and save.coins < sk.price
  local style = eq and 'eqd' or (own and 'mint' or (poor and 'poor' or 'pink'))
  local parts
  if eq then parts = T1('NO CANHÃO')
  elseif own then parts = T1('USAR ESTE')
  elseif poor then parts = {{t = 'FALTAM'}, {i = 'coin'}, {t = tostring(sk.price - save.coins)}}
  else parts = {{t = 'COMPRAR'}, {i = 'coin'}, {t = tostring(sk.price)}} end
  local aw, ah = btnSize(parts, true)
  if aw < u(230) then aw = u(230) end
  local dotS, dotG = u(12), u(7)
  font(14)
  local t1w, t1h = measure('Exército sortido')
  font(12)
  local t2w, t2h = measure('cada disparo sai com um sabor seu')
  local tgW = u(4) + u(40) + u(10) + (t1w > t2w and t1w or t2w) + u(4)
  local tgH = u(8) + (t1h + t2h > u(20) and t1h + t2h or u(20))
  local total = cntH + gap + nmH + gap + descH + gap + ah + gap + dotS + gap + tgH + gap + u(22)
  local y = by + (bh - total) / 2
  font(12)
  txtB(count, cx - cntW / 2, y, rgba(mixRgb(INK, CREAM, 0.35)))
  y = y + cntH + gap
  font(36)
  txtB(sk.name, cx - nmW / 2, y, rgba(INK))
  y = y + nmH + gap
  font(15)
  for i, l in ipairs(lines) do
    local lw = measure(l)
    txt(l, cx - lw / 2, y + (i - 1) * lh, rgba(INK))
  end
  y = y + descH + gap
  local dx = 0
  if shop.shakeT > 0 then
    local seq = {0, -4, 0, 4}
    dx = u(seq[floor((0.3 - shop.shakeT) / 0.075) % 4 + 1])
  end
  button('shAct', floor(cx - aw / 2), y, aw, ah, style, parts, true, nil, shopAction, dx)
  y = y + ah + gap
  local dw = #SKINS * dotS + (#SKINS - 1) * dotG
  local dxp = floor(cx - dw / 2)
  for i, s in ipairs(SKINS) do
    local x0 = dxp + (i - 1) * (dotS + dotG)
    if i == shop.idx then
      local big = floor(dotS * 1.35)
      fill(rgba(INK), x0 - (big - dotS) / 2, y - (big - dotS) / 2, big, big)
    elseif owns(s.id) then
      fill(rgba(MINT_D), x0, y, dotS, dotS)
      fill(rgba(MINT), x0 + u(2), y + u(2), dotS - 2 * u(2), dotS - 2 * u(2))
    else
      fill(rgba(PLUM), x0, y, dotS, dotS)
      fill(rgba(CREAM), x0 + u(2), y + u(2), dotS - 2 * u(2), dotS - 2 * u(2))
    end
  end
  y = y + dotS + gap
  local tx = floor(cx - tgW / 2)
  local on = save.mixed
  local swx, swy = tx + u(4), y + (tgH - u(20)) / 2
  panel(swx, swy, u(40), u(20), on and MINT or 0xd9c6a8, on and MINT_D or 0xbfa37c, false, u(2))
  fill(rgba(on and WHITE or INK), swx + (on and u(23) or u(3)), swy + u(2), u(14), u(12))
  local ttx = swx + u(40) + u(10)
  local tty = y + (tgH - t1h - t2h) / 2
  font(14)
  txtB('Exército sortido', ttx, tty, rgba(INK))
  font(12)
  txt('cada disparo sai com um sabor seu', ttx, tty + t1h, rgba(mixRgb(INK, CREAM, 0.25)))
  regBtn('mix', tx, y, tgW, tgH, toggleMix)
  if ui.focus == 'mix' then ring(tx, y, tgW, tgH, u(2)) end
  y = y + tgH + gap
  legend(LEG_SHOP, cx, y, false)
end
end

local function drawLoading()
  local left, total = scene.pending()
  font(15)
  local t = 'Carregando...'
  local tw, th = measure(t)
  local bw = u(220)
  local w = (tw > bw and tw or bw) + 2 * u(14)
  local h = u(9) + th + u(8) + u(8) + u(12)
  local x, y = floor(W / 2 - w / 2), floor(H / 2 - h / 2)
  panel(x, y, w, h, CREAM, CREAM_D, false)
  txtB(t, W / 2 - tw / 2, y + u(9), rgba(INK))
  local by = y + u(9) + th + u(8)
  local bx = floor(W / 2 - bw / 2)
  fill(rgba(PLUM_D), bx, by, bw, u(8))
  local done = total > 0 and (total - left) / total or 1
  local fw = floor(bw * done)
  if fw > 0 then fill(rgba(LIME), bx, by, fw, u(8)) end
end

drawUI = function()
  ui.btns = {}
  local screen = ui.screen
  if screen ~= 'menu' and (G.state == 'playing' or G.state == 'loading' or G.state == 'won' or G.state == 'lost') then drawHud() end
  if screen == 'menu' then drawMenu()
  elseif screen == 'shop' then drawShop()
  elseif screen == 'result' then drawResult()
  elseif screen == 'pause' then drawPause()
  elseif G.state == 'loading' then drawLoading() end
  drawToast()
end

resetTextCaches = function()
  mcache, mcount, wcache, fontPx = {}, 0, {}, 0
end
end

local function bindStd(std)
  STD = std
  floor, ceil, sqrt, sin, cos, tan, abs, clamp, pi = std.math.floor, std.math.ceil, std.math.sqrt, std.math.sin, std.math.cos, std.math.tan, std.math.abs, std.math.clamp, std.math.pi
  setColor, drawRect, drawClear = std.draw.color, std.draw.rect, std.draw.clear
  textPrint, textMensure, textFontSize = std.text.print, std.text.mensure, std.text.font_size
  if native_text_font_face then native_text_font_face('Pixelify', scene.root .. 'fonts/PixelifySans.ttf') end
  std.text.font_name('Pixelify')
end

local function buildPalettes()
  for i, sk in ipairs(SKINS) do SKIN_COL[i] = {rgba(sk.base), rgba(sk.light), rgba(sk.shade)} end
  ENEMY_COL = {rgba(ENEMY.base), rgba(LIME), rgba(ENEMY.light)}
  BURST_ENEMY = {ENEMY_COL[2], ENEMY_COL[3]}
  BURST_BASE = {rgba(0x5e3628), rgba(LIME), rgba(PLUM), rgba(0x7a4a33)}
  BURST_GOLD = {rgba(GOLD), rgba(WHITE)}
  BURST_WIN = {}
  for i, c in ipairs(SKIN_COL) do BURST_WIN[i] = c[1] end
  for name, def in pairs(ICONS) do ICON_T[name] = iconTpl(def) end
end

local function init(data, std)
  scene.root = type(data.root) == 'string' and data.root or ''
  bindStd(std)

  W, H = data.width or std.app.width, data.height or std.app.height
  Z = clamp(H / 700 < W / 1150 and H / 700 or W / 1150, 1, 3)
  OSX, OSY = W * 0.035, H * 0.045
  PADL, PADT, PADB = u(16) + floor(OSX + 0.5), u(16) + floor(OSY + 0.5), u(18) + floor(OSY + 0.5)

  rnd = newRng(std.math.random(1, 2147483646) + floor(std.milis))
  tintCache = {}
  resetTextCaches()
  curCol, GA, clipOn = -1, 1, false
  T, perfAcc, perfN, capP = 0, 0, 0, MAX_P
  sfxLast = {}

  buildPalettes()

  scene.load(std, scene.root, data.manifest)
  scene.camera_fit(W, H)

  for k in pairs(G) do G[k] = nil end
  G.state, G.paused, G.t, G.shake = 'menu', false, 0, 0
  G.pCount, G.eCount = 0, 0
  cannon.x, cannon.tx, cannon.recoil = 0, 0, 0
  ui.screen, ui.focus, ui.btns, ui.toast, ui.toastT, ui.hint, ui.hintT, ui.flash, ui.result = 'menu', 'play', {}, nil, 0, false, 0, 0, nil
  shop.idx, shop.pos, shop.spinT, shop.shakeT, shop.popT = 1, 1, 0, 0, 0

  loadSave()
  buildLevel(save.level)
  show('menu')
end

local function loop(data, std)
  local raw = (std.delta or 16) / 1000
  local dt = raw < 0.05 and raw or 0.05
  T = T + dt
  local st = G.state
  local mode = (st == 'playing' and 'playing') or (st == 'loading' and 'loading')
    or ((st == 'won' or st == 'lost') and not ui.screen and 'celebrate') or 'menu'
  scene.pump(mode)
  if st == 'loading' then
    G.loadT = G.loadT + dt
    if scene.pending() == 0 or G.loadT > 10 then G.state = 'playing' end
  end
  local playing = G.state == 'playing' and not G.paused and not ui.screen
  keys.left = playing and (std.key.press.left or keys.tapL > 0) and true or false
  keys.right = playing and (std.key.press.right or keys.tapR > 0) and true or false
  if not G.paused then update(dt) end
  if keys.tapL > 0 then keys.tapL = keys.tapL - dt end
  if keys.tapR > 0 then keys.tapR = keys.tapR - dt end
  if G.state == 'playing' and not G.paused then
    perfAcc = perfAcc + (raw < 0.1 and raw or 0.1)
    perfN = perfN + 1
    if perfN >= 90 then
      if perfAcc / perfN > 0.034 and capP > 240 then capP = floor(capP * 0.85 + 0.5) end
      perfAcc, perfN = 0, 0
    end
  end
  if ui.screen == 'shop' then
    shop.spinT = shop.spinT + dt
    local e = dt * 12
    if e > 1 then e = 1 end
    shop.pos = shop.pos + (shop.idx - shop.pos) * e
    if abs(shop.pos - shop.idx) < 0.01 then shop.pos = shop.idx end
  end
  if shop.shakeT > 0 then shop.shakeT = shop.shakeT - dt end
  if shop.popT > 0 then shop.popT = shop.popT - dt end
  if ui.toastT > 0 then ui.toastT = ui.toastT - dt end
  if ui.hintT > 0 and G.state == 'playing' and not G.paused then ui.hintT = ui.hintT - dt end
  if ui.flash > 0 then ui.flash = ui.flash - dt end
  if G.shake > 0.001 then
    G.shake = G.shake * STD.math.pow(0.02, dt)
    shakeOX, shakeOY = scene.shake_offset((rnd() - 0.5) * G.shake, (rnd() - 0.5) * G.shake)
  else
    shakeOX, shakeOY = 0, 0
  end
end

local function draw(data, std)
  curCol, GA = -1, 1
  drawClear(rgba(HAZE))
  drawScene()
  if ui.flash > 0 then fill(rgba(0xff3d6e, floor(255 * 0.45 * ui.flash / 0.6)), 0, 0, W, H) end
  drawUI()
end

local function key(data, std, name, pressed)
  if not pressed then return end
  if name == 'menu' then handleBack(); return end
  if ui.screen then
    if ui.screen == 'shop' and (name == 'left' or name == 'right') then
      shopStep(name == 'left' and -1 or 1)
    elseif name == 'left' or name == 'right' or name == 'up' or name == 'down' then
      nav(name)
    elseif name == 'a' then
      activate()
    end
    return
  end
  if G.state ~= 'playing' or G.paused then return end
  if name == 'left' then keys.tapL = keys.tap
  elseif name == 'right' then keys.tapR = keys.tap
  elseif name == 'a' or name == 'up' then fireChampion() end
end

local function exit(data, std)
  scene.unload()
  resetTextCaches()
  tintCache = {}
  ui.btns = {}
end

ui.quit = function()
  if not (STD.app and STD.app.exit) then return end
  exit(nil, STD)
  STD.app.exit()
end

return {
  meta = {
    title = 'Gominhos',
    author = 'Gominhos',
    description = 'Dispare gominhos, multiplique nos portais e derrube a fortaleza dos Azedinhos.',
    version = '1.0.0',
  },
  config = {require = 'math math.random storage json'},
  callbacks = {init = init, loop = loop, draw = draw, key = key, exit = exit},
}
