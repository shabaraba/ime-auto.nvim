# Changelog

## [0.1.4](https://github.com/shabaraba/ime-auto.nvim/compare/v0.1.3...v0.1.4) (2026-07-22)


### Features

* Add Linux support for IME switching via fcitx/ibus ([#41](https://github.com/shabaraba/ime-auto.nvim/issues/41)) ([0d178c0](https://github.com/shabaraba/ime-auto.nvim/commit/0d178c03df30a12538f427059fa844a96174000e))
* Add Windows support for IME switching via PowerShell ([#40](https://github.com/shabaraba/ime-auto.nvim/issues/40)) ([ae2ec91](https://github.com/shabaraba/ime-auto.nvim/commit/ae2ec910552bfe1f94fe85e5a055d416601be89a))


### Bug Fixes

* Apply default log level before comparison in utils.notify ([#48](https://github.com/shabaraba/ime-auto.nvim/issues/48)) ([81674ac](https://github.com/shabaraba/ime-auto.nvim/commit/81674ac3d24af856191b3fe5b8cddaa4a97f08b8))
* Check TISSelectInputSource result and report accurate error for unselectable sources ([#54](https://github.com/shabaraba/ime-auto.nvim/issues/54)) ([46f7112](https://github.com/shabaraba/ime-auto.nvim/commit/46f71125e0a6771016060202e30b50defb629dc6)), closes [#30](https://github.com/shabaraba/ime-auto.nvim/issues/30)
* Correctly detect JIS keyboard layout to avoid injecting keys on US keyboards ([#45](https://github.com/shabaraba/ime-auto.nvim/issues/45)) ([d64e98f](https://github.com/shabaraba/ime-auto.nvim/commit/d64e98f132c0b0af555c77cc9d3031ffc69b81d9)), closes [#14](https://github.com/shabaraba/ime-auto.nvim/issues/14)
* Correctly parse status output for ime_method=custom ([#51](https://github.com/shabaraba/ime-auto.nvim/issues/51)) ([fa77b8f](https://github.com/shabaraba/ime-auto.nvim/commit/fa77b8f36aed1a7e922b5baec6de987b3269659b)), closes [#24](https://github.com/shabaraba/ime-auto.nvim/issues/24)
* Create slot and debug log files with 0600 permissions from the start ([#56](https://github.com/shabaraba/ime-auto.nvim/issues/56)) ([b0b67d8](https://github.com/shabaraba/ime-auto.nvim/commit/b0b67d88a4cbcd33b1193e875ff0257babbfdaff))
* Disable escape sequence handling when plugin is disabled ([#44](https://github.com/shabaraba/ime-auto.nvim/issues/44)) ([8b28287](https://github.com/shabaraba/ime-auto.nvim/commit/8b28287791efff9ea4e938f12a9bc165928c76ab)), closes [#20](https://github.com/shabaraba/ime-auto.nvim/issues/20)
* Invalidate IME state cache after plugin-initiated switch ([#46](https://github.com/shabaraba/ime-auto.nvim/issues/46)) ([cda1cce](https://github.com/shabaraba/ime-auto.nvim/commit/cda1cce4f0ba9ba4738e586b06809e39a9f15767)), closes [#23](https://github.com/shabaraba/ime-auto.nvim/issues/23)
* Isolate IME slot files per Neovim instance ([#62](https://github.com/shabaraba/ime-auto.nvim/issues/62)) ([4de0def](https://github.com/shabaraba/ime-auto.nvim/commit/4de0def175061136df0f7da4b35c1bc502f80437)), closes [#31](https://github.com/shabaraba/ime-auto.nvim/issues/31)
* Make IME switching async to prevent UI freeze on mode change ([#50](https://github.com/shabaraba/ime-auto.nvim/issues/50)) ([e219f92](https://github.com/shabaraba/ime-auto.nvim/commit/e219f924fb6f797a2b79e30d53e6386912abc6a0))
* Make Windows IME on/off deterministic and load SendKeys assembly ([#42](https://github.com/shabaraba/ime-auto.nvim/issues/42)) ([7156603](https://github.com/shabaraba/ime-auto.nvim/commit/715660356c6fdf62b8111e5ef3f64180e16be278))
* Notify on escape sequence match failure and reduce race window ([#64](https://github.com/shabaraba/ime-auto.nvim/issues/64)) ([547d9b0](https://github.com/shabaraba/ime-auto.nvim/commit/547d9b0a6b5e62de6b54f144a21a98bec685525b))
* Only write debug log to stderr when debug logging is enabled ([#47](https://github.com/shabaraba/ime-auto.nvim/issues/47)) ([21d2a3a](https://github.com/shabaraba/ime-auto.nvim/commit/21d2a3af6d76fa8025e556beb51890813a11f99d))
* Pass debug env var via vim.system instead of shell string concat ([#55](https://github.com/shabaraba/ime-auto.nvim/issues/55)) ([b94ea65](https://github.com/shabaraba/ime-auto.nvim/commit/b94ea65cdb21f636ae649a500852e6e7d5a5289a)), closes [#28](https://github.com/shabaraba/ime-auto.nvim/issues/28)
* Reset pending escape char on cursor move and enforce position continuity ([#60](https://github.com/shabaraba/ime-auto.nvim/issues/60)) ([7a040e3](https://github.com/shabaraba/ime-auto.nvim/commit/7a040e34fdd237a1ff03fbf2a323e49615beedae)), closes [#26](https://github.com/shabaraba/ime-auto.nvim/issues/26)
* Restore correct cursor position after escape sequence deletion ([#49](https://github.com/shabaraba/ime-auto.nvim/issues/49)) ([12c7fce](https://github.com/shabaraba/ime-auto.nvim/commit/12c7fce9c4d784449c18664355c0b16e1a938fef)), closes [#22](https://github.com/shabaraba/ime-auto.nvim/issues/22)
* Support escape_sequence of any length, not just 2 chars ([#57](https://github.com/shabaraba/ime-auto.nvim/issues/57)) ([c7f0a81](https://github.com/shabaraba/ime-auto.nvim/commit/c7f0a81718bdbee4742066c9713a43255941d088)), closes [#21](https://github.com/shabaraba/ime-auto.nvim/issues/21)
* Turn off IME when leaving insert mode via Ctrl-C ([#38](https://github.com/shabaraba/ime-auto.nvim/issues/38)) ([94d622a](https://github.com/shabaraba/ime-auto.nvim/commit/94d622abc9e103a7a9517c5ac79a7ba52bd21742))
* Use TIS input mode property instead of substring match for Japanese IME detection ([#39](https://github.com/shabaraba/ime-auto.nvim/issues/39)) ([7efcc78](https://github.com/shabaraba/ime-auto.nvim/commit/7efcc78d0f554035303460a841e21ed29f47d0c1)), closes [#15](https://github.com/shabaraba/ime-auto.nvim/issues/15)
* Use TIS-based IME status detection instead of ID string matching ([#53](https://github.com/shabaraba/ime-auto.nvim/issues/53)) ([0a318ea](https://github.com/shabaraba/ime-auto.nvim/commit/0a318eaca62eeb1f9cabe7154aa5ae7e37968d6f))
* Warn when accessibility permission is missing for key sending ([#43](https://github.com/shabaraba/ime-auto.nvim/issues/43)) ([b37440c](https://github.com/shabaraba/ime-auto.nvim/commit/b37440c745485a3dbbb2c6ba079584385ecb91c2))


### Code Refactoring

* Deduplicate toggle/key-send/TIS-property logic in Swift IME tool ([#59](https://github.com/shabaraba/ime-auto.nvim/issues/59)) ([9519d07](https://github.com/shabaraba/ime-auto.nvim/commit/9519d0788dd6b9bc0f754983f7b0d1e9b57246b8))
* Remove unused ui.lua and dead debounced/helper functions ([#58](https://github.com/shabaraba/ime-auto.nvim/issues/58)) ([b9e2873](https://github.com/shabaraba/ime-auto.nvim/commit/b9e287393917361bb5a43fea7f3717e7d9e79219))
* Use vim.trim and unify command execution path ([#52](https://github.com/shabaraba/ime-auto.nvim/issues/52)) ([aa9e816](https://github.com/shabaraba/ime-auto.nvim/commit/aa9e8167fee8ebf1daa06cea7b40c142dda1450b))


### Documentation

* Document investigation into mode-specific TIS input source IDs ([#63](https://github.com/shabaraba/ime-auto.nvim/issues/63)) ([d40d096](https://github.com/shabaraba/ime-auto.nvim/commit/d40d096be7bbe4e3ad67b4626038496be7b413ea))
* Sync CLAUDE.md with actual code identifiers, flows, and split ime.lua ([#61](https://github.com/shabaraba/ime-auto.nvim/issues/61)) ([be3e84b](https://github.com/shabaraba/ime-auto.nvim/commit/be3e84b01d48dc61492a26cf6b6c56421e9527a3))

## [0.1.3](https://github.com/shabaraba/ime-auto.nvim/compare/v0.1.2...v0.1.3) (2026-01-19)


### Bug Fixes

* Resolve input mode mismatch on JIS keyboards (macOS) ([#11](https://github.com/shabaraba/ime-auto.nvim/issues/11)) ([c2070d6](https://github.com/shabaraba/ime-auto.nvim/commit/c2070d67a2207ebf9b32c5c0e291e0132454de50))

## [0.1.2](https://github.com/shabaraba/ime-auto.nvim/compare/v0.1.1...v0.1.2) (2026-01-18)


### Features

* Add precompiled Universal Binary and improve developer workflow ([#9](https://github.com/shabaraba/ime-auto.nvim/issues/9)) ([5828a00](https://github.com/shabaraba/ime-auto.nvim/commit/5828a00040687d1adbb760f35826447d5ced022d))

## [0.1.1](https://github.com/shabaraba/ime-auto.nvim/compare/v0.1.0...v0.1.1) (2026-01-18)


### Features

* implement toggle-based IME switching with slot system ([#3](https://github.com/shabaraba/ime-auto.nvim/issues/3)) ([c000297](https://github.com/shabaraba/ime-auto.nvim/commit/c000297d301c94ef5c6bcc5553748851e308c045))
* improve IME switching performance and add external CLI tool support ([#1](https://github.com/shabaraba/ime-auto.nvim/issues/1)) ([60513cf](https://github.com/shabaraba/ime-auto.nvim/commit/60513cf6b2faaaf355b9ccdd46f4ed6cab6ba570))
* improve UX with better error messages and input source selection ([#2](https://github.com/shabaraba/ime-auto.nvim/issues/2)) ([e235c9a](https://github.com/shabaraba/ime-auto.nvim/commit/e235c9a8d004cd80bada1b9a8d11b07db088bb53))
* initial implementation of ime-auto.nvim ([b79bc5f](https://github.com/shabaraba/ime-auto.nvim/commit/b79bc5ff8ea6daa63003e0395e92e5c2a728aa88))
* skip IME off operation when IME is already disabled ([b5ccf68](https://github.com/shabaraba/ime-auto.nvim/commit/b5ccf682195f5f8f1fda7c075b6a7b085b0538fb))


### Bug Fixes

* change release-please type from node to simple ([#7](https://github.com/shabaraba/ime-auto.nvim/issues/7)) ([13cd1a2](https://github.com/shabaraba/ime-auto.nvim/commit/13cd1a2a83e1350a466f1b1f1c510ad2129d3df8))


### Documentation

* update installation example with correct repository URL ([acc1d7a](https://github.com/shabaraba/ime-auto.nvim/commit/acc1d7a5250fec5ea5c328ea466afef69925f856))


### Miscellaneous

* add release-please ([#4](https://github.com/shabaraba/ime-auto.nvim/issues/4)) ([a02d17f](https://github.com/shabaraba/ime-auto.nvim/commit/a02d17f48b031400deeca187f0c019814ab0123d))
