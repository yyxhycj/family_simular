# 角色 ID 与头像对应表

**不是固定家族。**以下姓名、年龄、身份仅为接入示例，并非玩家当前存档。正式绑定：`runId + member.id → member.artId（只分配一次并存档）→ 年龄阶段/状态 → 文件`。
改名、换岗、换族长、切页和重绘均不重选美术ID。旧头像大改脸型时新增版本，不静默覆盖旧身份。

| 固定 artId | 性别呈现 | 识别锚点 |
|---|---|---|
| `portrait_m01` | 男 | 方下颌、平眉、右眼外侧小痣、青灰衣 |
| `portrait_m02` | 男 | 长椭圆脸、细长眼、左眉外挑、灰蓝衣 |
| `portrait_f01` | 女 | 椭圆脸、弯眉、左耳青玉坠、素绿衣 |
| `portrait_f02` | 女 | 圆脸、额前碎发、米杏衣 |

4个基础视觉身份，每个5个阶段：infant / child / young / adult / elder。它们不是无限量互不相同的脸型；长局允许美术复用，但不能合并角色状态。职业/资质不因美术ID受限制。

## 示例人物（禁止当作固定开局）

| memberId | 姓名 | 年龄 | 性别 | 身份示例 | artId | 头像 |
|---|---|---:|---|---|---|---|
| `sample-run-a:member-101` | 顾砚舟 | 42 | 男 | 木匠／示例族长 | `portrait_m01` | `assets/characters/portrait_m01/adult_normal_256.png` |
| `sample-run-a:member-102` | 闻素宁 | 39 | 女 | 医者／示例成员 | `portrait_f01` | `assets/characters/portrait_f01/adult_normal_256.png` |
| `sample-run-a:member-103` | 顾知远 | 20 | 男 | 求学／示例成员 | `portrait_m02` | `assets/characters/portrait_m02/young_normal_256.png` |
| `sample-run-a:member-104` | 顾清禾 | 10 | 女 | 启蒙／示例成员 | `portrait_f02` | `assets/characters/portrait_f02/child_normal_256.png` |

## 尺寸与状态

详情：512×512 viewBox分层SVG，直接渲染768×768透明PNG。头像：256×256，圆外透明、圆内米白底。每阶段提供正常、病弱、已故和选中头像；详情提供正常、病弱、已故。病弱/已故是原画色阶衍生，不是换一张脸；选中使用独立框，可叠在病弱和已故状态上。

美术年龄分段示例：0–4/5–12/13–27/28–54/55+，只用于选择插画，不改变生育、成年、寿命规则。已故阶段冻结死亡时年龄。健康状态从实际游戏取得，不从本包擅自推断。

完整路径：data/portrait_library.json；示例：data/character_examples.json；纯Lua解析：data/AssetResolver.lua。
