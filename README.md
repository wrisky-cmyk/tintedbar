# TintedBar

[中文](README.md) · [English](README.en.md)

**Quickshell 桌面外壳**：状态栏、面板、锁屏、壁纸。

![TintedBar 整体预览](screenshots/preview.png)

*整体预览：状态栏、设置面板与桌面背景。*

TintedBar 是基于 QML（[quickshell](https://quickshell.org)）的 Wayland 桌面外壳，用一个进程替代
waybar + mako + wofi + wlogout + hyprpaper + hypridle + hyprlock + hyprpolkitagent：
栏、面板（启动器 / 剪贴板 / 电源 / 通知 / 日历 / 天气 / 设置）、锁屏和壁纸都在其中，
没有常驻 Python/Node，除天气外不联网。

- 目标环境：Hyprland 或 niri（带 layer-shell + IPC 的 wlroots / smithay 系合成器）。
- 面板一律走 IPC，**不占用任何键位**；按键由合成器绑定。
- ⚠️ **修改 `.qml` 后保存即热重载。锁屏期间或授权弹窗挂着时不要保存**：重载会重建窗口
  （屏幕黑一下），正在进行的授权也会被取消。

## 特色

- 窗口标题与关闭按钮位于栏中央，把栏当作窗口的一部分，鼠标操作更顺手。
- 面向小屏：一窗一工作区，工作区按钮显示该区窗口的真实图标。
- 功能够用而不臃肿：复杂功能不做，日常只需填天气坐标、写壁纸映射。

## 依赖

**必需**（缺失会导致无法启动或主要功能不可用）：

| 依赖 | 用途 |
| --- | --- |
| quickshell 0.3.x、Qt 6.12 | 运行时 |
| Hyprland 或 niri（`hyprctl` / `niri msg`） | 工作区、标题、焦点、DPMS |
| D-Bus 会话总线 + NetworkManager / UPower / BlueZ / PipeWire / 通知服务 | 网络、电池、蓝牙、音量、通知；缺失时对应模块留空，不会崩溃 |
| `sh` + coreutils（`grep`/`sed`/`find`/`df`） | 读取 `/proc`、`/sys`，调用命令行工具 |
| 字体 **JetBrainsMono Nerd Font** + **Noto Sans CJK SC** | 图标字形与中文；缺失时回退系统字体，并输出 `[FONT]` WARN（常见豆腐块） |

**按模块可选**（缺失只影响对应功能）：

| 依赖 | 影响 |
| --- | --- |
| `cliphist` + wl-clipboard | 剪贴板面板。**写入端需自行加入合成器 autostart**：`wl-paste --watch cliphist store` |
| `curl` | 天气（仅在开关打开时每 30 分钟请求一次 Open-Meteo） |
| `gsettings` / `gio`（或 `xdg-open`） | 跟随系统深浅色 / 启动器打开应用 |
| `notify-send`（libnotify） | 重启提示的通知动作；缺失时图标仍可点，但不会弹出详情 |
| `systemctl` / `loginctl` | 电源菜单的关机/重启/休眠/注销 |
| `nm-applet` / `blueman-manager` / `pavucontrol` | 点网络 / 蓝牙 / 音量图标拉起的面板 |
| `$TERMINAL`（兜底 `alacritty`） | 左栏终端按钮、点击温度/磁盘/CPU/内存时打开的 `top` |

**无需安装**：playerctl / pactl / wpctl / brightnessctl / grim / jq / python / Node。
媒体走 MPRIS（D-Bus），音量走 PipeWire 服务，网速读 `/proc`，通知自己发。

## 快速开始

1. **作为 quickshell 的默认配置**：解压到 `~/.config/quickshell/`（入口为其中的 `shell.qml`），
   直接运行 `quickshell`。目录也可以随意放置：`quickshell -p <目录>`。需要并存多份时，各自放到
   `~/.config/quickshell/<名字>/shell.qml`，再用 `quickshell -c <名字>` 选择。
2. **随会话启动**：在合成器配置的自启段加入 `quickshell`。担心重复启动时用 `quickshell -n`，
   检测到已有实例会直接退出。
3. **排错时前台运行**：`quickshell --no-color`，报错会直接输出到终端；不想占用终端可加 `-d`。

```sh
# Hyprland（hyprland.conf）
exec-once = quickshell

# niri（config.kdl）
spawn-at-startup "quickshell"
```

修改 `.qml` 后保存即可热重载，无需重启。日志位于
`/run/user/$UID/quickshell/by-pid/<pid>/log.log`（用 `ls -t` 取最新一份）。不再使用时，
删掉自启行并退出进程即可：它只在自己的进程内工作，不安装服务，也不修改系统设置。

## 常用 IPC

面板开合统一走 IPC（`quickshell` 可简写为 `qs`），按键留给合成器，例如绑定到 `Super+Space`：

```sh
qs ipc call launcher toggle           # 启动器
qs ipc call clips toggle              # 剪贴板
qs ipc call powermenu toggle          # 电源菜单
qs ipc call settings toggle           # 设置面板
qs ipc call calendar toggle           # 日历
qs ipc call weather toggle            # 天气
qs ipc call notify toggle             # 通知历史
qs ipc call lock toggle               # 上锁
qs ipc call wallpaper reload          # 重读壁纸映射
qs ipc call bt toggle                 # 切换蓝牙电源
qs ipc call audio mute                # 切换默认输出静音
qs ipc call net toggle                # 断开/接回当前链路（有线优先）
```

多屏时，面板作用于**聚焦屏**；lock / wallpaper / bt 为全局。
完整命令（托盘菜单、分格网络控制等）见[完整参考](docs/reference.md#ipc键位自行绑定)。

## 栏上操作

| 位置 | 左键 | 右键 |
| --- | --- | --- |
| 终端 / 工作区 | 打开终端 / 切换工作区 | — |
| 时钟 / 铃铛 | 日历 / 通知历史 | 切换日历视图 / 勿扰开关 |
| 网络 | 打开 nm-applet | 无线格开关射频；有线格断开或接回网线；网速数字断开当前链路 |
| 蓝牙 | 打开 blueman-manager | 切换蓝牙电源 |
| 音量 | 打开 pavucontrol | 切换默认输出静音 |
| 深浅 / 温度等 | 切换系统深浅色 / 在终端打开 `top` | — |
| 空闲抑制 | 切换“现在是否抑制” | 立即上锁 |
| 齿轮 / 重启提示 | 设置面板 / 查看重启原因 | — / 立即重新检查 |

蓝牙、网络、隐私指示和重启提示的完整状态规则见[状态图标细节](docs/reference.md#状态图标细节)。

## 配置

- `weather.conf`：天气坐标 `lat=` / `lon=`；留空则天气模块隐藏。
- `wallpapers.conf`：每行 `输出名=图片路径` 或 `输出名=#RRGGBB`；图片可放在任意目录，
  写绝对路径或 `~` 开头的路径，`*` 为兜底。
- `components/Style.qml`：字体名、栏高默认值和面板圆角等；颜色默认跟随当前 GTK 主题。
- 设置面板的开关保存在 `~/.local/state/quickshell/bar-settings.json`，由程序写入，请勿手改。

详细字段、配色家族和键盘操作见[完整参考](docs/reference.md)。

## 更多文档

- [完整参考](docs/reference.md)：全部 IPC、键盘操作、栏上交互、状态图标、设置项和配置文件。
- [进阶与排障](docs/advanced.md)：锁屏、polkit、换机器、版本签名、常见问题和目录结构。

## 版权与归属

- 基于 [Quickshell](https://quickshell.org)（LGPL-3.0-only）构建；本仓库是配置，不包含 Quickshell 源码。
- `components/Lunar.qml` 的农历表与换算逻辑移植自
  [jjonline/calendar.js](https://github.com/jjonline/calendar.js)（作者 JeaYang，GPL-3.0-or-later）。
- 电源菜单图标来自 Google Material Symbols Rounded（Apache-2.0）。
- 初始布局与视觉数值移植自本项目之前的 Waybar 配置；Waybar 本身为 MIT 许可。
- 字体与 Qt 是运行时依赖，不随仓库分发。

第三方来源、许可证全文和字体/Qt 的说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 许可证

Copyright (C) 2026 wrisky-cmyk

本项目自身代码采用 GNU General Public License v3.0（GPL-3.0-only）授权；第三方组件仍按其各自
许可证授权，详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。完整条款见 [LICENSE](LICENSE)。

电源菜单图标来自 Google Material Symbols Rounded，以 Apache-2.0 授权；
来源、对应关系和原始 SVG 见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
