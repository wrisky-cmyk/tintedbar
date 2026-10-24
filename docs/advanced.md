# 进阶与排障

[返回 README](../README.md) · [完整参考](reference.md)

本页收录锁屏、授权弹窗、换机器与移植、版本签名、排障和目录结构。

## 启动与自启

常用方式见 [README 的快速开始](../README.md#快速开始)。其他启动写法：

```sh
# Hyprland（Lua 配置）
hl.exec_cmd("quickshell")

# 自定义启动脚本：后台启动
setsid -f quickshell        # 或 quickshell -d
```

## 锁屏

使用 Wayland 会话锁协议（`ext-session-lock-v1`）与 PAM 认证，PAM 配置名为 `quickshell-lock`：

```sh
# 没有这个文件会自动退回 "login"；需要独立的认证栈再创建它
printf 'auth include login\n' | sudo tee /etc/pam.d/quickshell-lock
```

- 解锁使用**登录密码**。锁屏**没有**“解锁”IPC：一句 `quickshell ipc call lock unlock` 就能绕过
  PAM，因此干脆不提供该入口。小键盘可以正常输入。
- **被锁在门外时**：切换到 TTY（`Ctrl+Alt+F2`）登录，或从另一台机器 SSH 进来。`login` 认证栈
  带有 `pam_faillock`（默认连续输错 3 次锁定 10 分钟），等待冷却或走 TTY 均可。
- 回退方案：系统中若还保留 hyprlock，这份配置无法启动时可直接运行 `hyprlock` 应急。

## 授权弹窗（polkit）

由 quickshell 自己充当 polkit agent（替代 hyprpolkitagent）。触发条件不变：`pkexec`、安装软件包、
修改系统设置等需要权限的操作会弹出“需要授权”卡片；输入**登录密码**，Enter 提交 / Esc 取消。
认证使用系统的 `/usr/lib/pam.d/polkit-1`，与其他 agent 一致，因此同样受 `pam_faillock` 管理：
连续输错 3 次锁定 10 分钟，期间卡片会直接显示剩余分钟数。

- 锁屏期间**不弹窗**（密码框不会压到锁屏界面上），解锁后会弹。
- 多屏时，弹窗出现在**触发那一刻的聚焦屏**。
- 若系统中还有别的 polkit agent 在自启（hyprpolkitagent / polkit-gnome 等），这个 agent 会注册失败，
  弹窗仍由后者提供。**一个会话只认一个 agent**，要切换就得让另一个不要启动。

## 换机器与移植

- 代码中**没有写死的家目录或配置目录**：家目录通过 `HOME`/XDG 获取，shell 自己的文件
  （`weather.conf` / `wallpapers.conf` / `scripts/` / `icons/`）通过 `Quickshell.shellDir` 定位，
  因此目录可以随意放置。电池、温度、LED、网卡探测不到时，对应模块整块隐藏。
- `weather.conf` 和 `wallpapers.conf` 随包附带，而且**不改也能运行**：壁纸默认纯色，天气坐标留空时
  模块隐藏（需要时填写 `lat=` / `lon=`）。换机器通常只需调整[可手改的配置文件](reference.md#可手改的配置文件)
  中三处与本机绑定的内容：壁纸输出名（用 `hyprctl monitors` 查看）、天气经纬度、
  `Style.qml` 顶部的字体名。
- 多屏：每屏一份栏和面板，点击作用于聚焦屏；壁纸按输出名分别配置。
- 亮度与麦克风（V26.10.24起）：换机器**无需改任何东西**——内置屏背光走 logind（无包
  依赖），外接屏自动探测 DDC/CI（想用需装 `ddcutil` 并把用户加入 `i2c` 组，建议 1.0+；
  探测不到显示器就不显示该模块）；麦克风走 PipeWire，优先控制占用流实际连接的输入源，
  链路与默认输入源都不可用时点击为空动作。
  sysfs 背光的写入依赖 systemd-logind，非 systemd 发行版上表现为"模块在、调整不生效"。

## 版本与指纹

设置面板右栏最下方有一行只读的**版本**（点击或回车打开项目仓库，面板同时收起），启动日志开头也会输出
`[QS] config version …`(V26.10.24起日志为英文)——报 bug、核对文档都以它为准。版本采用**日期版**（`YY.MM.DD` 表示这份配置的
日期），无需自行维护。发布包中带有 `manifest.json`，因此该行会额外显示 8 位**内容指纹**：

| 面板显示（示例） | 含义 |
| --- | --- |
| `26.10.18` | 没有 `manifest.json`：只显示日期，不做比对 |
| `26.10.18+021fad79` | 与发布时逐字节一致 |
| `26.10.18+021fad79≠`（警示色） | 内容被改动过。**自己改过配置就会一直如此**；想让面板恢复安静，删除 `manifest.json` 即可 |

指纹只用于提示“内容被改动过”（自己改过或拿错了包）：它由配置自行报告，无法阻止有意修改。
**要确认下载的包未被篡改，请使用签名**：

```sh
ssh-keygen -Y verify -n tintedbar-dist -f allowed_signers -I '<发布者身份>' \
  -s tintedbar-261018.tar.gz.sig < tintedbar-261018.tar.gz
```

出现 `Good "tintedbar-dist" signature` 即表示发布包原封未动。公钥 / `allowed_signers` 请从
发布页获取（**不要信任包内自带的那份**，否则等于没有签名）。

## 排障

| 现象 | 排查方向 |
| --- | --- |
| 栏没有出现 | 查看日志中的 `Failed to load`（热重载时也会输出）；语法错误时栏不会自行恢复 |
| 图标显示为豆腐块 / 中文变成方框 | 字体未安装或名称不对，日志会出现 `[FONT]` WARN；修改 `Style.qml` 顶部 |
| 天气不显示 | 检查设置中的“天气”开关、`weather.conf` 是否填写坐标，以及能否连接 Open-Meteo |
| 剪贴板面板一直为空 | 合成器 autostart 中缺少 `wl-paste --watch cliphist store` |
| 某个模块空白 | 多数是 D-Bus 服务未运行（NetworkManager / UPower / BlueZ / PipeWire） |
| 亮度模块不出现或调节异常 | 模块不出现：设置面板右栏的“亮度”开关没开（默认关），或两个后端都不可用——内置屏走 /sys/class/backlight（写走 logind），外接屏走 ddcutil，先用 `ddcutil detect` 验证 DDC/CI 与 i2c 组权限（需安装 ddcutil 且用户在 i2c 组）。调整后屏幕约 0.5~4 秒才跟上属正常（显示器受理一次写后会短暂拒绝后续写，配置已内置写冷却）；日志中的 `[BRIGHT]` 会给出后端与失败原因 |
| 修改 `.qml` 后没有变化 | 保存的可能是未被加载的文件；在日志中搜索 `Reloading configuration` / `Configuration Loaded` |
| `ipc call` 报找不到 target / 名称错误 | 用 `quickshell ipc show` 列出当前所有 target 与子命令 |
| 锁屏无法进入 | 连续输错 3 次会进入 `pam_faillock` 冷却（等待 10 分钟或切换 TTY；见“锁屏”） |
| 想确认运行的是哪一版 | 查看设置面板右栏最下方的**版本**，或日志开头的 `[QS] config version <日期>`；带 `≠` 表示内容被改动过（见“版本与指纹”） |

## 目录结构

```text
shell.qml                    栏与各面板窗口（PopupWindow）
components/                  Style（配色/字体） · Compositor（组合器单例：工作区/全屏/
                             键盘布局等，§ 见仓库文档） · I18n（文案/日期） · Lunar（农历）
                             Almanac（干支/月相/节气） · Weather · IconProbe（图标探测）
                             启动器/剪贴板/电源/通知/设置面板 · LockScreen
                             栏上模块与时钟/天气/亮度弹窗（V26.10.24 起从 shell.qml
                             拆出为独立文件） · 各组按钮
scripts/                     icon-follow.sh · launch-desktop.sh · theme-apply.sh
                             theme-toggle.sh · theme-css.sh（把主题 CSS 解析成“名字=值”）
icons/                       电源菜单用的图片
wallpapers.conf              壁纸映射：输出名=图片路径 或 输出名=#RRGGBB
weather.conf                 天气坐标（留空 = 天气模块整体隐藏）
manifest.json                仅发布副本包含：版本 + 内容指纹（见“版本与指纹”）
LICENSE                      GNU General Public License v3.0（GPL-3.0-only）
THIRD_PARTY_NOTICES.md       第三方图标署名与来源
LICENSES/                    第三方许可证（目前为 Apache-2.0）
icons/source/                Material Symbols Rounded 的原始 SVG
screenshots/                 截图预览
docs/                        详细文档（reference.md / advanced.md）
~/.local/state/quickshell/   程序状态（bar-settings.json / 天气缓存 / 通知历史 / 启动器使用频率）
```
