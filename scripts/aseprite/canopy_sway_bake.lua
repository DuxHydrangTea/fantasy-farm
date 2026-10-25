-- Canopy Sway Bake: generates looping sine-shear wind frames for a tree canopy.
-- Mirrors shaders/grass_field_core.gdshaderinc in this repo: horizontal
-- displacement grows linearly with distance above the pinned root row, so the
-- pin row stays still and the top of the canopy sways at full amplitude.
--
-- Workflow:
--   1. Open the canopy sprite. The canopy must be its own layer/cel -- split
--      it from the trunk first, the trunk must NOT sway.
--   2. Optional: make a selection whose bottom edge is the pin row (where
--      canopy meets trunk). Without a selection the pin is auto-detected as
--      the bottom-most non-transparent row.
--   3. File > Scripts > Canopy Sway Bake, pick parameters, press Bake.
--   4. The whole bake is one transaction: a single Ctrl+Z undoes it.
--
-- Looping: frame angles step by TAU/N, so the default single sine loops
-- seamlessly at any frame count. The optional "gust" mode adds the second
-- 0.25-weight sine from the shader (5:9 period ratio, here 10 and 18 frame
-- periods); that only loops after LCM(10,18) = 90 frames, which the script
-- enforces by overriding the frame count.

local TAU = math.pi * 2

local spr = app.activeSprite
if not spr then
  app.alert("Open a sprite first.")
  return
end

local layer = app.activeLayer
if not layer or not layer.isImage then
  app.alert("Select an image layer (not a group or folder).")
  return
end
if layer.isBackground then
  app.alert("Convert the background layer to a transparent layer first (Layer > Convert).")
  return
end

local src_cel = app.activeCel
if not src_cel and #layer.cels > 0 then
  src_cel = layer.cels[1]
end
if not src_cel then
  app.alert("This layer has no cel to animate.")
  return
end

local src = src_cel.image:clone()
local origin = src_cel.position
local W, H = src.width, src.height

local function content_bottom(img)
  for y = img.height - 1, 0, -1 do
    for x = 0, img.width - 1 do
      if img:getPixel(x, y) ~= 0 then
        return y
      end
    end
  end
  return -1
end

local auto_pin = content_bottom(src)
if auto_pin < 0 then
  app.alert("The active cel is empty.")
  return
end

-- Pin suggestion: selection bottom (canvas Y), else bottom of the content.
local suggested_pin = origin.y + auto_pin
local sel = spr.selection
if sel and not sel.isEmpty then
  suggested_pin = sel.bounds.y + sel.bounds.height - 1
end

local dlg = Dialog("Canopy Sway Bake")
dlg:number{ id="frames", label="Frames:", text="8", decimals=0 }
dlg:number{ id="fps", label="Frame rate (fps):", text="8", decimals=0 }
dlg:number{ id="amp", label="Amplitude (px):", text="2", decimals=1 }
dlg:number{ id="drift", label="Phase drift (rad/row):", text="0.08", decimals=2 }
dlg:number{ id="pin", label="Pin row (canvas Y):", text=tostring(suggested_pin), decimals=0 }
dlg:combobox{ id="edge", label="Edge handling:", option="Smear (keeps outline)",
  options={ "Smear (keeps outline)", "Wrap", "Transparent" } }
dlg:check{ id="gust", text="Second gust sine (forces 90 frames)" }
dlg:button{ id="ok", text="Bake" }
dlg:button{ id="cancel", text="Cancel" }
dlg:show()

local data = dlg.data
if not data.ok then
  return
end

local frames = math.floor(data.frames or 8)
local fps = math.max(1, math.floor(data.fps or 8))
local amp = data.amp or 2.0 -- negative amplitude inverts the wind direction
local drift = data.drift or 0.08 -- positive: gusts enter at the top, travel down
local edge = data.edge or "Smear (keeps outline)"
local gust = data.gust

if gust then
  frames = 90 -- LCM(10, 18); smaller counts would not loop the gust sine
else
  frames = math.min(512, math.max(2, frames))
end

local pin_y = math.floor(data.pin or suggested_pin) - origin.y
if pin_y < 0 or pin_y > H - 1 then
  pin_y = auto_pin -- manual pin outside the image: fall back to content bottom
end

-- Normalize reach by the content span so the topmost row sways at full
-- amplitude (the shader's GPU-quad branch does the same per 16px strip).
local top = 0
for y = 0, H - 1 do
  local has = false
  for x = 0, W - 1 do
    if src:getPixel(x, y) ~= 0 then
      has = true
      break
    end
  end
  if has then
    top = y
    break
  end
end
local span = math.max(1, pin_y - top)

local baked = {}
for f = 0, frames - 1 do
  local img = Image(W, H, src.colorMode)
  for y = 0, H - 1 do
    local above = pin_y - y
    local reach = math.max(0, above) / span
    local phase = drift * above
    local bend = math.sin(TAU * f / frames + phase)
    if gust then
      bend = bend + 0.25 * math.sin(TAU * f / 18 + phase * 0.7)
    end
    local dx = math.floor(amp * bend * reach + 0.5)
    for x = 0, W - 1 do
      local sx = x - dx
      if edge == "Smear (keeps outline)" then
        -- Duplicate the outermost pixel outward: the outline stretches 1-2px
        -- instead of breaking (Transparent) or teleporting across (Wrap).
        sx = math.max(0, math.min(W - 1, sx))
      elseif edge == "Wrap" then
        sx = sx % W
      end
      if sx >= 0 and sx < W then
        local px = src:getPixel(sx, y)
        if px ~= 0 then
          img:drawPixel(x, y, px)
        end
      end
    end
  end
  baked[f + 1] = img
end

app.transaction(function()
  while #spr.frames < frames do
    spr:newEmptyFrame()
  end
  for i = 1, frames do
    local cel = layer:cel(i)
    if cel then
      cel.image = baked[i]
      cel.position = origin
    else
      spr:newCel(layer, i, baked[i], origin)
    end
    spr.frames[i].duration = 1 / fps
  end
  -- Drop this layer's stale cels left behind by a previous longer bake.
  if #spr.frames > frames then
    for i = #spr.frames, frames + 1, -1 do
      local cel = layer:cel(i)
      if cel then
        spr:deleteCel(cel)
      end
    end
  end
  for _, t in ipairs(spr.tags) do
    if t.name == "Sway" then
      spr:deleteTag(t)
    end
  end
  local tag = spr:newTag(1, frames)
  tag.name = "Sway"
  tag.aniDir = AniDir.FORWARD
end)

print(string.format("Canopy Sway Bake: %d frames @ %d fps, amp %.1f px, drift %.2f, pin row %d (canvas Y), edge=%s",
  frames, fps, amp, drift, pin_y + origin.y, edge))
