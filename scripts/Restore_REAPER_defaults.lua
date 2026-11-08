--[[
  Cubase 鼠标修饰键 —— 恢复出厂默认
  只还原 Cubase_mouse_modifiers.lua 动过的 24 个位置，其他自定义不动。
  跑法：Actions → New action → Load ReaScript → 选本文件 → Run
--]]

local r = reaper

local TOUCHED = {
  ["MIDI note left click"] = { 0, 2 },
  ["MIDI note left drag"] = { 0, 2, 4, 6 },
  ["MIDI piano roll left click"] = { 4, 6 },
  ["MIDI piano roll left drag"] = { 0, 2, 4, 6 },
  ["Media item left click"] = { 0, 2 },
  ["Media item left drag"] = { 0, 2, 4, 6 },
  ["Track left click"] = { 4, 6 },
  ["Track left drag"] = { 0, 2, 4, 6 },
}

local n = 0
for ctx, flags in pairs(TOUCHED) do
  for _, f in ipairs(flags) do
    r.SetMouseModifier(ctx, f, -1)
    n = n + 1
  end
end
r.MarkProjectDirty(0)
local msg = string.format("已恢复 %d 个鼠标修饰位为出厂默认。", n)
if _G.CUBASE_MM_HEADLESS then
  local f = io.open(_G.CUBASE_MM_HEADLESS, "w")
  if f then f:write(msg .. "\n") f:close() end
else
  r.ShowMessageBox(msg, "Restore Mouse Modifiers", 0)
end
