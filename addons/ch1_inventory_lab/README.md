# Open Hyper AI Ch1 · 真人九格

独立本地自定义地图，引用当前安装的官方 `dota` 地图。仅真人的主英雄获得三个备用栏的使用权限和装备被动；BOT、幻象与分身保持原有物品栏规则。

安装（仓库根目录 PowerShell）：

```powershell
./tools/install-nine-slot-addon.ps1 -DotaRoot 'D:\steam\steamapps\common\dota 2 beta' -CreateDesktopShortcut
```

退出 DOTA2 后，双击桌面 **Open Hyper AI Ch1 - 真人九格**。进入队伍界面，选择阵营，点击“锁定并开始”，再选择英雄。空位自动填充 BOT。开局准备时间为 90 秒，归零后由引擎正常出兵。

桌面入口通过 Steam 启动，继承个人启动参数（包括国服的 `-perfectworld`）。同时关闭“自定义游戏中禁用独立英雄按键”，让原有英雄按键在此地图生效。如果从主菜单控制台进入，也请在设置中关闭这一选项。

也可以完全沿用原来的 DOTA2 启动入口。进入主菜单后，按控制台键（本机是 F7）输入：

```text
dota_per_unit_keybindings_disabled_during_custom_games 0; dota_launch_custom_game ch1_inventory_lab dota
```

正在对局时先退出至主菜单，再执行。普通 BOT 房间仍使用“本地开发脚本”；九格需要从上述自定义地图入口进入。此地图使用自定义模式规则，目前未实现完整的 Turbo 经济与快递规则。

安装器只部署 `game/dota_addons/ch1_inventory_lab`，并在覆盖前备份已有版本。使用本机现有 Open Hyper AI Ch1 BOT 脚本，不修改普通 BOT 脚本、个人配置或 Steam 启动项。Lua modifier 只由本地图初始化，不能从普通 BOT 的 FretBots 入口加载。

备用栏使用引擎原生主动施法权限，并补充装备原生 intrinsic modifier；装备自身的不叠加、冷却、禁用等规则继续适用。新物品或具有特殊脚本的物品仍需逐个兼容验证。
