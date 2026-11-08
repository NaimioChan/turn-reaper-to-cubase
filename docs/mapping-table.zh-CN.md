# Cubase 鼠标修饰键 —— 逐条清单

共 24 条，覆盖 8 个上下文。


## 事件上（单击）

`Media item left click`

| 修饰键 | 行为 |
|---|---|
| 无 | `Select item` |
| Ctrl | `Toggle item selection` |

## 事件上（拖动）

`Media item left drag`

| 修饰键 | 行为 |
|---|---|
| 无 | `Move item` |
| Ctrl | `Move item ignoring snap` |
| Alt | `Copy item` |
| Ctrl+Alt | `Copy item ignoring snap` |

## 空白处（拖动）

`Track left drag`

| 修饰键 | 行为 |
|---|---|
| 无 | `Marquee select items` |
| Ctrl | `Marquee toggle item selection` |
| Alt | `Draw an empty MIDI item` |
| Ctrl+Alt | `Draw an empty MIDI item ignoring snap` |

## 空白处（单击）

`Track left click`

| 修饰键 | 行为 |
|---|---|
| Alt | `No action` |
| Ctrl+Alt | `No action` |

这里故意留空。REAPER 把单击和拖动当成两个独立上下文，按下时如果单击位有行为，
会先触发它，拖动画事件就画不出来。留空后 Alt 按下直接落到拖动上下文，
一次手势就能画出事件并拖出长度。

## 音符上（单击）

`MIDI note left click`

| 修饰键 | 行为 |
|---|---|
| 无 | `Select note` |
| Ctrl | `Toggle note selection` |

## 音符上（拖动）

`MIDI note left drag`

| 修饰键 | 行为 |
|---|---|
| 无 | `Move note` |
| Ctrl | `Move note ignoring snap` |
| Alt | `Copy note` |
| Ctrl+Alt | `Copy note ignoring snap` |

## 钢琴卷帘空白（拖动）

`MIDI piano roll left drag`

| 修饰键 | 行为 |
|---|---|
| 无 | `Marquee select notes` |
| Ctrl | `Marquee toggle note selection` |
| Alt | `Insert note, drag to extend or change pitch` |
| Ctrl+Alt | `Insert note ignoring snap, drag to extend or change pitch` |

## 钢琴卷帘空白（单击）

`MIDI piano roll left click`

| 修饰键 | 行为 |
|---|---|
| Alt | `No action` |
| Ctrl+Alt | `No action` |

这里故意留空。REAPER 把单击和拖动当成两个独立上下文，按下时如果单击位有行为，
会先触发它，拖动画音符就画不出来。留空后 Alt 按下直接落到拖动上下文，
一次手势就能画音符并拖出长度。
