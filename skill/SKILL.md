---
name: turn-reaper-to-cubase
description: Use when making REAPER feel like Cubase.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [reaper, cubase, daw, keymap, mouse-modifiers]
    related_skills: [hermes-windows-toolchain]
---

# 把 REAPER 调成 Cubase 手感

## When to Use

- 用户要从 Cubase 迁到 REAPER，希望鼠标和滚轮手感一致
- 要批量配置 REAPER 鼠标修饰键或滚轮缩放/滚动
- 调试 `reaper-mouse.ini` / `reaper-kb.ini` 写入不生效的问题

给从 Cubase 转到 REAPER 的人用。目标是把「工具 + 修饰键」的操作习惯搬到 REAPER 的鼠标修饰键和滚轮绑定上。

## 两套体系，别搞混

| 要改的 | 存在哪 | 怎么改 |
|---|---|---|
| 鼠标修饰键（拖拽/单击行为） | `reaper-mouse.ini` | ReaScript 调 `SetMouseModifier` |
| 滚轮（缩放/滚动） | `reaper-kb.ini` 的 `KEY 255 ...` 行 | Actions 里点 Add 后滚动滚轮，或手写 |
| 键盘快捷键 | `reaper-kb.ini` 的 `KEY ...` 行 | `KeyMaps/*.ReaperKeyMap` 导入 |

滚轮**不在**鼠标修饰键体系里，`Preferences → Mouse Modifiers` 页面上没有滚轮设置。这是最容易走弯路的地方。

## 一、鼠标修饰键

用 ReaScript 的 `reaper.SetMouseModifier(context, flag, action)`：

- `context`：字符串，如 `"Media item left drag"`、`"MIDI note left click"`。
  **必须用未本地化的英文原名**，界面切成中文也一样。
- `flag`：修饰位，`0`=无 `1`=Shift `2`=Ctrl `3`=Ctrl+Shift `4`=Alt `5`=Shift+Alt `6`=Ctrl+Alt `7`=Ctrl+Shift+Alt
- `action`：行为名（英文原文），或 `"<命令ID> c"`（仅单击/双击类上下文支持）
- 传 `-1` 复位单个位置；`SetMouseModifier(ctx, -1, -1)` 复位整个上下文

### 上下文名的坑

有些上下文名带斜杠，写成空格就静默失效（`GetMouseModifier` 返回空串）：

- `MIDI CC lane left click/drag`（不是 `left drag`）
- `MIDI CC event left click/drag`
- `Media item fade/autocrossfade left drag`

这三个在 REAPER 7.83 只认数值 ID，行为名写进去读回是 `0`，不要用：
`Project tempo/time signature marker left drag`、`Project marker/region edge left drag`、`Project region left drag`。

### 行为名怎么查

不要凭记忆编。两个可靠来源：

1. 从 `reaper.exe` 里提取动作表：搜 `Set default mouse modifier action for "..." to "..."`，每一条就是一个合法 (上下文, 行为) 组合。
2. 或者用 REAPER 自带的生成脚本（Stash 上 935 个 `.lua`），文件名里就有上下文和行为名。

写完必须读回校验：`GetMouseModifier` 返回 `""` 或 `"-1"` 就是没写进去。

## 二、滚轮绑定

`reaper-kb.ini` 里的格式：

```
KEY 255 <键码> <动作ID> <区段>
```

区段：`0`=Main，`32060`=MIDI Editor。

### 键码（实测确认）

基础值 248，加修饰位：Ctrl=+1、Alt=+2、Shift=+4。
REAPER 7 实际使用高位形式（低位 + 9984 / 0x2700），两种写法它都认：

| 组合 | 低位 | 高位 |
|---|---|---|
| 滚轮 | 248 | 10232 |
| Ctrl+滚轮 | 249 | 10233 |
| Alt+滚轮 | 250 | 10234 |
| Ctrl+Alt+滚轮 | 251 | 10235 |
| Shift+滚轮 | 252 | 10236 |
| Ctrl+Shift+滚轮 | 253 | 10237 |

### Cubase 那四条对应的动作

| 组合 | 行为 | Main | MIDI Editor |
|---|---|---|---|
| Ctrl+滚轮 | 水平缩放 | 990 | 40431 |
| Ctrl+Shift+滚轮 | 纵向缩放 | 991 | 40430 |
| Shift+滚轮 | 水平滚动（反向） | 977 | 40660 |
| 滚轮 | 纵向滚动 | 989 | 40432 |

水平滚动要用 **reversed** 版（977/40660）。正向版 988/40433 的方向是滚轮向上=向右，跟 Cubase 相反。

### 更省事的做法

Actions 窗口 → 搜动作 → 选中 → 点 `Add...` → 直接滚一下滚轮（按住需要的修饰键）。
REAPER 自己把正确键码写进 `reaper-kb.ini`，不用手算。手写只在批量配置时划算。

## 三、完整映射表（Cubase 操作 → REAPER）

| 场景 | 修饰键 | 行为 |
|---|---|---|
| 事件单击 | 无 | `Select item` |
| 事件单击 | Ctrl | `Toggle item selection` |
| 事件拖动 | 无 | `Move item` |
| 事件拖动 | Ctrl | `Move item ignoring snap` |
| 事件拖动 | Alt | `Copy item` |
| 事件拖动 | Ctrl+Alt | `Copy item ignoring snap` |
| 空白单击 | Alt / Ctrl+Alt | `No action`（留给拖动上下文） |
| 空白拖动 | 无 | `Marquee select items` |
| 空白拖动 | Ctrl | `Marquee toggle item selection` |
| 空白拖动 | Alt | `Draw an empty MIDI item` |
| 空白拖动 | Ctrl+Alt | `Draw an empty MIDI item ignoring snap` |
| 音符单击 | 无 / Ctrl | `Select note` / `Toggle note selection` |
| 音符拖动 | 无 / Ctrl / Alt / Ctrl+Alt | `Move note` / `Move note ignoring snap` / `Copy note` / `Copy note ignoring snap` |
| 卷帘单击 | Alt / Ctrl+Alt | `No action`（故意留空，见下） |
| 卷帘拖动 | 无 / Ctrl | `Marquee select notes` / `Marquee toggle note selection` |
| 卷帘拖动 | Alt / Ctrl+Alt | `Insert note, drag to extend or change pitch` / `Insert note ignoring snap, ...` |

Cubase 的橡皮擦没有修饰键，保留 REAPER 原生即可。

## 四、验证方法（重要）

改完不能只看「脚本没报错」，要发真实事件看效果。

### 无界面跑 ReaScript

REAPER 启动时自动执行 `<resource>/Scripts/__startup.lua`（注意在 `Scripts/` 子目录，不是资源根目录）。
用它加载脚本、把结果写文件、然后 `reaper.Main_OnCommand(40004, 0)` 退出：

```lua
_G.HEADLESS_OUT = [[C:\path\to\result.txt]]
local ok, err = pcall(dofile, [[C:\path\to\your_script.lua]])
if not ok then
  local f = io.open(_G.HEADLESS_OUT, "w")
  if f then f:write("ERR "..tostring(err)) f:close() end
end
reaper.defer(function() reaper.Main_OnCommand(40004, 0) end)
```

脚本里判断 `if _G.HEADLESS_OUT then` 写文件，否则 `ShowMessageBox`。

### 发真实鼠标滚轮

`computer_use` 对 REAPER 窗口的 UIA 树经常超时，抓不到元素。改用 Win32 直接发：

```python
import ctypes, ctypes.wintypes as w, time
u = ctypes.windll.user32
hwnds = []
@ctypes.WINFUNCTYPE(w.BOOL, w.HWND, w.LPARAM)
def cb(h, l):
    b = ctypes.create_unicode_buffer(256); u.GetWindowTextW(h, b, 256)
    if b.value.startswith("REAPER v7"): hwnds.append(h)
    return True
u.EnumWindows(cb, 0)
H = hwnds[0]
u.ShowWindow(H, 9); u.SetForegroundWindow(H); time.sleep(1)
pt = w.POINT(1200, 350)
u.ClientToScreen(H, ctypes.byref(pt))
u.SetCursorPos(pt.x, pt.y); time.sleep(0.3)
u.keybd_event(0x11, 0, 0, 0)          # Ctrl 按下（0x10=Shift）
for _ in range(8):
    u.PostMessageW(H, 0x020A, (120 & 0xFFFF) << 16, (pt.y << 16) | pt.x)
    time.sleep(0.1)
u.keybd_event(0x11, 0, 2, 0)          # 松开
```

`120`=向上，`-120`=向下。

### 观测缩放/滚动变化

`reaper.GetSet_ArrangeView2(0, false, 0, 0)` 返回 `start, end`：

- **水平缩放**：`end - start` 变化，`start` 不变
- **水平滚动**：`end - start` 不变，`start` 变化
- **纵向缩放/滚动**：两者都不变（垂直维度，这套 API 看不到）

用 `reaper.defer` 每帧记录，变化时写文件。纵向操作只能靠「水平维度无变化」排除法判断。

## 五、交付物结构

```
Scripts/CubaseMouse/
  Cubase_mouse_modifiers.lua   应用脚本（幂等，可重复跑）
  Restore_REAPER_defaults.lua  只还原本脚本动过的位置
  README.md                    对照表 + 键码规律 + 实测记录
  清单.md                      逐条清单
MouseMaps/
  Cubase 风格鼠标修饰键.ReaperMouseMap   可直接导入的键位文件
reaper-kb.ini.bak-before-wheel           滚轮改动前备份
```

应用脚本要先备份 `reaper-mouse.ini` 到 `MouseMaps/backup-<时间戳>.ReaperMouseMap`，再逐条写入并读回校验，最后弹窗报告「总条目 N ｜ 变更 N ｜ 原本已是该值 N ｜ 失败 N」。失败数必须是 0。

## 六、单击位留空让拖动直接生效

REAPER 的 `left click` 和 `left drag` 是两个独立上下文。按下鼠标时，如果单击位绑了行为，
它会先触发，拖动上下文就轮不到了。

所以「按住修饰键拖动 = 画东西」这种手势，必须把对应的**单击位设成 `No action`**：

```lua
-- 编曲区空白处
r.SetMouseModifier("Track left click", 4, "No action")             -- Alt
r.SetMouseModifier("Track left click", 6, "No action")             -- Ctrl+Alt
-- MIDI 钢琴卷帘空白处
r.SetMouseModifier("MIDI piano roll left click", 4, "No action")   -- Alt
r.SetMouseModifier("MIDI piano roll left click", 6, "No action")   -- Ctrl+Alt
```

这样 Alt 按下直接落到对应的 `left drag`，一次手势画出事件或音符并拖出长度，
跟 Cubase 的铅笔一致。

**注意 `No action` 读回是 `0`，不是空串。** 只有 `""` 和 `-1` 才表示写入失败——
把 `0` 当失败会误判。

三个例外仍然保留绑定，因为单击和拖动互不干扰，且都是常用操作：
事件本体的 Alt（在鼠标处切开）、音符本体的 Alt（删除音符）、标尺的 Alt（清循环）。

## 七、已知做不到的

- **Cubase 的「Alt+点击后拖动决定事件长度」（编曲区）**：REAPER 的 click 和 drag 是两个独立上下文。编曲区只能拆成「Alt 点击 = 插入定长事件」+「Alt 拖动 = 画事件」。
- **工具模式**：Cubase 的 Split/Erase/Range 是切换工具后点击，REAPER 没有工具状态，只能靠修饰键模拟单点动作。
- **橡皮擦**：Cubase 里没有默认修饰键，保留 REAPER 原生（右键拖 = 擦除）最省事。
