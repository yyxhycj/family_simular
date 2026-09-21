# 家业 Ink V2 美术接入

## 资源范围

运行资源位于 `assets/Jiaye/InkV2/`：

- `characters/`：4 组人物、5 个年龄阶段，以及 normal、sick、deceased、selected 状态图。
- `houses/`：4 个家宅等级、4 个家宅状态，使用 `1200x560` 运行适配图。
- `events/`：12 类事件，使用 `1200x560` 运行适配图。
- `relics/`：20 个 v1.2 `formId`，使用独立的 `512` 展示图。

本目录只接入交付包导出的运行 PNG。旧版 UI、按钮、图标、装饰和纸张纹理继续位于 `assets/Jiaye/V7/`。交付版本标记为 `ink_v2_review`，来源边界以交付包 `DELIVERY_STATUS.md` 和 `ASSET_MANIFEST.md` 为准。

`docs/Jiaye/InkV2/` 保留本次接入的追溯文件：`DELIVERY_STATUS.md`、`ASSET_MANIFEST.md`、`crop_map.json`、`asset_registry.json`、`character_asset_map.json`、`event_asset_map.json` 和 `relic_form_map.json`。其中 manifest 与映射文件里的资源路径仍记录交付包原始路径 `assets/characters/ink_v2/...`、`assets/houses/ink_v2/...`、`assets/events/ink_v2/...`、`assets/relics/ink_v2/...`；运行资源已映射到 `assets/Jiaye/InkV2/`，运行时前缀对应 `Jiaye/InkV2/`。

## 版本与身份

```lua
Art.Assign(member, identity, artVersion)
```

`artVersion` 支持：

- `nil`：保存旧版 `1.0.0`。
- `"1.0.0"`：旧版人物资源。
- `"ink_v2_review"`：新人物资源。

已有 `artId` 或 `artVersion` 时，接口会校验固定值；传入冲突版本会直接报错。未知版本会直接报错。成员头像只读取成员自己的 `artVersion`，场景版本切换不会改变成员身份。已有 `artId` 且缺少 `artVersion` 的旧成员会固定为 `1.0.0`。

## 场景版本

主渲染入口每次 `App:Render()` 前调用：

```lua
Visual.SetArtVersion(version)
```

`nil` 表示旧版。`"ink_v2_review"` 启用 Ink V2 的家宅、事件和信物图片。版本值经过 `Art.NormalizeVersion` 校验。

头像不读取场景版本。普通头像使用 `256` 图；正常详情头像使用 `detail_768`。病弱和已故详情请求会使用真实存在的状态 `256` 图，避免拼接不存在的 `detail_sick` 或 `detail_deceased` 路径。

## 信物形态

```lua
Art.Relic(formId, artVersion)
Visual.Relic(formId, size)
```

Ink V2 支持完整形态：

`genealogy.1`、`genealogy.2`、`genealogy.3`、`ruler.1`、`ruler.2`、`ruler.3`、`letter.1`、`letter.2`、`letter.3`、`plan.1`、`plan.2`、`plan.3`、`jade.1`、`jade.2`、`jade.3.heirloom`、`jade.3.alliance`、`notes.1`、`notes.2`、`notes.3.private`、`notes.3.public`。

旧 ID `book`、`newbook`、`ruler`、`letter`、`plan`、`jade`、`notes` 保留兼容解析。未知形态直接报错，禁止把高阶形态静默指向基础图。

`RelicV12View` 传入完整 `formId`。Ink V2 下不显示旧版的“临时复用基础图”提示；旧版继续使用旧形态图，v1.2 形态的旧图兼容关系由 `Art.Relic` 处理。

## 事件与家宅

`Art.Event` 和 `Art.House` 只返回交付包中登记的真实路径。未知事件类型、家宅等级、状态或美术版本直接报错；事件插画继续经过 `requireAsset` 校验，不随机选用其他事件图。

原有按钮状态、图标色调、装饰名称和纸张纹理接口保持原路径，调用方无需变更。
