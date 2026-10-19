# Third-Party Notices

## Quickshell

TintedBar is a configuration for [Quickshell](https://quickshell.org), not a fork of it.
Quickshell is licensed under the GNU Lesser General Public License v3.0 only
(`LGPL-3.0-only`). Its source and license are available from
<https://git.outfoxxed.me/quickshell/quickshell>. No Quickshell source code is
vendored in this repository.

## jjonline/calendar.js

The `lunarInfo` table and the solar/lunar conversion logic in
`components/Lunar.qml` are adapted from
[jjonline/calendar.js](https://github.com/jjonline/calendar.js), authored by
JeaYang (JJonline). The upstream package metadata declares GPL-3.0-or-later;
the project's original code is GPL-3.0-only, which is compatible with using
that code under GPLv3. The Lunar-derived portion remains available under
GPL-3.0-or-later from its upstream author. See the upstream `LICENSE` for the
full terms.

## Google Material Symbols Rounded

The following power-menu images under `icons/` are rendered from Google
Material Symbols Rounded:

| Shipped file | Material Symbols name |
| --- | --- |
| `suspend.png` | `pause_circle` |
| `reboot.png` | `refresh` |
| `shutdown.png` | `power_settings_new` |
| `hibernate.png` | `mode_standby` |
| `logout.png` | `logout` |
| `lock.png` | `lock` |

The original SVG files are included under
`icons/source/material-symbols-rounded/`. They come from the Google Material
Design Icons project:

<https://github.com/google/material-design-icons>

Material Symbols Rounded is licensed under the Apache License, Version 2.0.
The full license text is in `LICENSES/Apache-2.0.txt`.

The icons were converted to white PNGs for the Quickshell power menu; the
shapes were not otherwise changed.

## Fonts and Qt (not bundled)

JetBrainsMono Nerd Font (<https://github.com/ryanoasis/nerd-fonts>) and
Noto Sans CJK SC (<https://github.com/notofonts/noto-cjk>) are runtime font
dependencies and are not included in this repository. Qt is likewise a runtime
dependency of Quickshell. If you redistribute a bundled build containing Qt or
the fonts, check and comply with their respective upstream licenses (Qt offers
LGPLv3/GPLv3/commercial terms, <https://www.qt.io/licensing>; the fonts are
distributed under their own font licenses).

## Waybar (layout inspiration)

The initial layout and visual values were ported from the project's previous
Waybar configuration. Waybar itself is MIT-licensed
(<https://github.com/Alexays/Waybar>); no Waybar source code is included here.
