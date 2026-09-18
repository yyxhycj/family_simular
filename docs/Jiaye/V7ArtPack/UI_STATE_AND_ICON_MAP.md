# UI状态与图标包

## 按钮

primary / secondary / danger三类；default / pressed / selected / disabled / focus / confirm / busy七态，共21个独立皮肤。无烘焙文字；选择、确认和loading图标独立叠加，避免九宫格拉伸变形。

confirm表示确认前的视觉强调，不等于动作已成功。disabled/busy必须设置实际控件禁用，不是仅换颜色。焦点可与选中状态共同显示。

源SVG viewBox240×96；PNG480×192。参考显示120×48逻辑尺寸，PNG四边切片36像素，对应参考9逻辑尺寸。中间水平延伸，四角不变形。后缀@2x相对SVG viewBox，不代表最终设备密度；读取data/ui_asset_map.json中的源像素/逻辑尺寸。

## 面板与控件

5个面板状态：default/selected/disabled/danger/confirmation。复选框、单选框、输入框各4态；开关off/on/disabled。源均SVG与PNG。文本、点击、键盘、状态生命周期在真实UI控件中实现。

## 人物叠层

portrait_selected / leader / sick / deceased / focus，透明SVG与256PNG，不替换脸；已故和病弱头像可再叠选中框。朱印使用抽象家宅符号，不烘焙固定家姓或系统字体。

## 图标

31种，每种ink/paper/muted三色，提供SVG与24/48/72 PNG。24逻辑画布，1.65线宽，实际热区至少44。浅背景用ink、深背景用paper；禁用采用muted并配文字说明。

`family`, `people`, `estate`, `relics`, `history`, `money`, `grain`, `land`, `relationship`, `lock`, `unlock`, `back`, `forward`, `random`, `edit`, `close`, `check`, `plus`, `minus`, `info`, `warning`, `year`, `save`, `search`, `leader`, `sick`, `deceased`, `house`, `restore`, `more`, `loading`

家族/族人/家业/藏阁/家史绑定family/people/estate/relics/history。机器映射：data/ui_asset_map.json。source/UI_COMPONENT_LIBRARY.svg为可编辑总板。
