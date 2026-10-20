# 家业水墨美术接入

## 运行资源

- `assets/image/`：四组人物、五个年龄阶段的 1536×1536 透明底立绘。
- `assets/Jiaye/InkV2/houses/`：四个家宅等级与四个状态的 `1200x560` 插画。
- `assets/Jiaye/InkV2/events/`：事件 `1200x560` 插画。
- `assets/Jiaye/InkV2/relics/`：信物形态各自的 `512` 展示图。
- `assets/Jiaye/V7/`：按钮、图标、装饰、头像标记与纸张纹理。

人物、家宅、事件和信物的资源映射统一由 `scripts/Jiaye/Art.lua` 管理。游戏只使用这一套水墨资源。

## 人物身份与年龄

```lua
Art.Assign(member, identity)
Art.Portrait(member)
```

`Art.Assign` 保留已登记的 `artId`；新增人物按身份与编号稳定分配形象。未知 `artId` 直接报错。

`Art.Portrait` 根据人物的年龄阶段返回立绘。已故人物使用离世年龄或固定的离世阶段。病弱、已故、选中和族长标记由 `Visual.Portrait` 叠加。

存档读取、导出和导入时保留人物身份、年龄与家谱内容，并移除 `artVersion` 字段。

## 信物、事件与家宅

```lua
Art.Relic(formId)
Visual.Relic(formId, size)
Art.Event(event, relicId)
Art.House(homeId, state)
```

信物支持 `genealogy`、`ruler`、`letter`、`plan`、`jade`、`notes` 的完整形态。旧信物 ID `book`、`newbook`、`ruler`、`letter`、`plan`、`jade`、`notes` 映射到对应形态。

未知信物形态、事件类型、家宅等级或状态直接报错。所有映射均返回已登记的真实资源路径。

## 来源与审计

交付包的来源清单保存在 `docs/Jiaye/InkV2/`，其中路径和版本标记描述原始交付文件。

`scripts/QA/T14ResourceAudit.lua` 检查当前解析器返回的资源、人物离世年龄、UI 素材和字体；正式入口为 `main.lua`。
