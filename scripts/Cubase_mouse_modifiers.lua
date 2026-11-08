--[[
  Cubase 操作规格 → REAPER 鼠标修饰键
  ---------------------------------------------------------------
  本脚本严格按用户拉出的 Cubase 操作表实现，只动以下 24 个位置：

  编曲区
    左键点击          选择事件
    Ctrl+左键点击     多选事件（加/减选）
    左键拖动          移动事件 / 空白处框选
    Ctrl+左键拖动     忽略吸附移动 / 空白处反向框选
    Alt+左键拖动      铅笔创建事件 / 复制事件（单击位留空，一次手势完成）
    Ctrl+Alt+左键拖动  忽略吸附铅笔创建 / 复制
    注：编曲区和钢琴卷帘的 Alt/Ctrl+Alt 单击位都设成 No action，
        这样按下时不会先触发单击上下文，拖动才能直接画出东西。

  MIDI 编辑器
    左键点击          选择音符
    Ctrl+左键点击     多选音符
    左键拖动          移动音符 / 空白处框选
    Ctrl+左键拖动     忽略吸附移动 / 空白处反向框选
    Alt+左键拖动      铅笔创建音符（单击上下文留空，一次手势完成）
    Ctrl+Alt+左键拖动  忽略吸附铅笔创建 / 复制
    注：钢琴卷帘的 Alt/Ctrl+Alt 单击位设成 No action，这样按下时
        不会先触发单击上下文，拖动才能直接画出音符。

  CC / Velocity 车道（velocity 车道就是 CC lane 的一种，共用同一组上下文）
    无修饰拖动    直接画/改 CC（velocity 同理）
    Ctrl+拖动     框选 CC / 反向框选
    Alt+拖动      插入 CC 点
    Ctrl+Alt+拖动 忽略吸附插入
    Ctrl+Shift    精细编辑
    CC 事件本体、CC 线段也套用同一套逻辑（Alt 复制 / Ctrl 忽略吸附 / Ctrl+Alt 复制忽略吸附）

  橡皮（Erase）相关一律不动，保留 REAPER 原生。

  滚轮四条（水平/纵向缩放、水平/纵向滚动）不在鼠标修饰键体系内，
  由 tools/apply_wheel.py 写进 reaper-kb.ini 的快捷键绑定。

  跑法：Actions → New action → Load ReaScript → 选本文件 → Run
  撤销：跑同目录 Restore_REAPER_defaults.lua
--]]

local r = reaper

-- 修饰位：0=无 1=Shift 2=Ctrl 3=Ctrl+Shift 4=Alt 5=Shift+Alt 6=Ctrl+Alt 7=Ctrl+Shift+Alt
local MAP = {
  -- 编曲区 · 事件上（单击）
  ["Media item left click"] = {
    { 0, "Select item" },  -- 无：左键点击 = 选择事件
    { 2, "Toggle item selection" },  -- Ctrl：Ctrl+左键点击 = 多选事件
  },
  -- 编曲区 · 事件上（拖动）
  ["Media item left drag"] = {
    { 0, "Move item" },  -- 无：左键拖动 = 移动事件
    { 2, "Move item ignoring snap" },  -- Ctrl：Ctrl+左键拖动 = 忽略吸附移动
    { 4, "Copy item" },  -- Alt：Alt+左键拖动 = 复制事件
    { 6, "Copy item ignoring snap" },  -- Ctrl+Alt：Ctrl+Alt+左键拖动 = 忽略吸附复制
  },
  -- 编曲区 · 空白处（单击）
  -- 同 MIDI 钢琴卷帘：Alt 单击必须留空，否则按下先触发单击上下文、画不出事件。
  -- 留空后 Alt 按下只落到拖动上下文，一次手势就能画出事件并拖出长度。
  ["Track left click"] = {
    { 4, "No action" },   -- Alt：留给拖动上下文处理
    { 6, "No action" },   -- Ctrl+Alt：同上
  },
  -- 编曲区 · 空白处（拖动）
  ["Track left drag"] = {
    { 0, "Marquee select items" },  -- 无：空白处左键拖动 = 框选事件
    { 2, "Marquee toggle item selection" },  -- Ctrl：Ctrl+左键拖动 = 反向框选
    { 4, "Draw an empty MIDI item" },  -- Alt：Alt+左键拖动空白 = 铅笔创建
    { 6, "Draw an empty MIDI item ignoring snap" },  -- Ctrl+Alt：Ctrl+Alt+左键拖动空白 = 忽略吸附铅笔创建
  },
  -- MIDI · 音符上（单击）
  ["MIDI note left click"] = {
    { 0, "Select note" },  -- 无：左键点击 = 选择音符
    { 2, "Toggle note selection" },  -- Ctrl：Ctrl+左键点击 = 多选音符
  },
  -- MIDI · 音符上（拖动）
  ["MIDI note left drag"] = {
    { 0, "Move note" },  -- 无：左键拖动 = 移动音符
    { 2, "Move note ignoring snap" },  -- Ctrl：Ctrl+左键拖动 = 忽略吸附移动
    { 4, "Copy note" },  -- Alt：Alt+左键拖动 = 复制音符
    { 6, "Copy note ignoring snap" },  -- Ctrl+Alt：Ctrl+Alt+左键拖动 = 忽略吸附复制
  },
  -- MIDI · 钢琴卷帘空白处（单击）
  -- Alt 单击必须留空，否则按下会先触发单击上下文、画不出音符。
  -- 留空后 Alt 按下只落到拖动上下文，一次手势就能画音符。
  ["MIDI piano roll left click"] = {
    { 4, "No action" },   -- Alt：留给拖动上下文处理
    { 6, "No action" },   -- Ctrl+Alt：同上
  },
  -- MIDI · 钢琴卷帘空白处（拖动）
  ["MIDI piano roll left drag"] = {
    { 0, "Marquee select notes" },  -- 无：空白处左键拖动 = 框选音符
    { 2, "Marquee toggle note selection" },  -- Ctrl：Ctrl+左键拖动 = 反向框选
    { 4, "Insert note, drag to extend or change pitch" },  -- Alt：Alt+左键拖动空白 = 铅笔创建音符
    { 6, "Insert note ignoring snap, drag to extend or change pitch" },  -- Ctrl+Alt：Ctrl+Alt+左键拖动空白 = 忽略吸附铅笔创建
  },
  -- CC / Velocity 车道 · 空白处
  -- 无修饰 = 直接画/改（velocity 车道同理），Ctrl 框选，Alt 插点，Ctrl+Alt 忽略吸附插点
  ["MIDI CC lane left click/drag"] = {
    { 0, "Draw/edit CC events ignoring selection" },  -- 无：直接画/改 CC（注意是斜杠，带空格的同名条目 REAPER 不认）
    { 2, "Marquee select CC" },  -- Ctrl：框选 CC
    { 4, "Insert CC event" },  -- Alt：插入 CC 点
    { 6, "Insert CC event ignoring snap" },  -- Ctrl+Alt：忽略吸附插入
  },
  -- CC / Velocity 车道 · 事件本体
  ["MIDI CC event left click/drag"] = {
    { 0, "Move CC event on one axis only" },  -- 无：移动 CC 事件
    { 2, "Move CC event on one axis only ignoring snap" },  -- Ctrl：忽略吸附移动
    { 4, "Copy CC event" },  -- Alt：复制 CC 事件
    { 6, "Copy CC event ignoring snap" },  -- Ctrl+Alt：忽略吸附复制
    { 3, "Edit CC events" },  -- Ctrl+Shift：精细编辑
  },
  -- CC / Velocity 车道 · 线段
  ["MIDI CC segment left click/drag"] = {
    { 0, "Move CC segment ignoring time selection" },  -- 无：移动线段
    { 2, "Edit CC segment curvature" },  -- Ctrl：改曲率
    { 4, "Insert CC event" },  -- Alt：线段上插点
    { 6, "Insert CC event ignoring snap" },  -- Ctrl+Alt：忽略吸附插点
  },}

---------------------------------------------------------------- 备份
local function Backup()
  local res = r.GetResourcePath()
  local fh = io.open(res .. "/reaper-mouse.ini", "rb")
  if not fh then return "（reaper-mouse.ini 不存在）" end
  local data = fh:read("*a"); fh:close()
  local dir = res .. "/MouseMaps"
  r.RecursiveCreateDirectory(dir, 0)
  local dst = dir .. "/backup-" .. os.date("%Y%m%d-%H%M%S") .. ".ReaperMouseMap"
  local out = io.open(dst, "wb")
  if not out then return "（备份失败）" end
  out:write(data); out:close()
  return dst
end

---------------------------------------------------------------- 应用
local FLAGNAME = { "无", "Shift", "Ctrl", "Ctrl+Shift", "Alt", "Shift+Alt", "Ctrl+Alt", "Ctrl+Shift+Alt" }
local backupPath = Backup()

local total, changed, same, failed = 0, 0, 0, 0
local failLines, summary = {}, {}

for ctx, items in pairs(MAP) do
  local hit = 0
  for _, it in ipairs(items) do
    local flag, value = it[1], it[2]
    total = total + 1

    local before = r.GetMouseModifier(ctx, flag) or ""
    r.SetMouseModifier(ctx, flag, value)
    local after = r.GetMouseModifier(ctx, flag) or ""

    if after == "" or after == "-1" then
      failed = failed + 1
      failLines[#failLines + 1] = string.format("✗ %s / %s → %s", ctx, FLAGNAME[flag + 1], value)
    else
      hit = hit + 1
      if before == after then same = same + 1 else changed = changed + 1 end
    end
  end
  summary[#summary + 1] = string.format("%-32s %d/%d", ctx, hit, #items)
end

r.MarkProjectDirty(0)

---------------------------------------------------------------- 报告
table.sort(summary)
local msg = string.format(
  "Cubase 鼠标修饰键（按你的操作表）已写入\n\n"
  .. "总条目 %d ｜ 变更 %d ｜ 原本已是该值 %d ｜ 失败 %d\n\n"
  .. "备份：%s\n\n%s\n",
  total, changed, same, failed, tostring(backupPath), table.concat(summary, "\n"))

if #failLines > 0 then
  msg = msg .. "\n以下没生效：\n" .. table.concat(failLines, "\n") .. "\n"
end
msg = msg .. "\n滚轮四条请另跑 tools/apply_wheel.py。"

if _G.CUBASE_MM_HEADLESS then
  local f = io.open(_G.CUBASE_MM_HEADLESS, "w")
  if f then f:write(msg .. "\n") f:close() end
else
  r.ShowMessageBox(msg, "Cubase Mouse Modifiers", 0)
end
