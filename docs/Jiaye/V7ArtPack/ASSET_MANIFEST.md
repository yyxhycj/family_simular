# ASSET_MANIFEST · 家业V7美术资源制作版

实际运行资源 **722项文件**，包含SVG及PNG导出；导出倍数、状态变体不算新脸型。

源为真实可编辑SVG与直接PNG导出；人物景物为矢量化美术表达，未宣称完全还原手绘水墨笔触。无字体文件，无PSD/原生Figma。

关键映射：CHARACTER_ASSET_MAP.md / EVENT_ASSET_MAP.md / UI_STATE_AND_ICON_MAP.md。

## 数量

| 分类 | 文件数 |
|---|---:|
| character | 40 |
| character-state | 120 |
| house | 32 |
| relic | 14 |
| event | 24 |
| icon | 372 |
| ui | 92 |
| decor | 24 |
| texture | 4 |

独立设计：4身份×5阶段、16家宅状态图、12事件、7信物、31图标、21按钮状态；另有表单/面板/状态层、装饰及纹理。

## 裁切与透明

人物详情为透明外轮廓，头像是圆外透明/圆内浅底；家宅和事件是不透明完整横图，推荐15:7，不用于抠图贴纸。UI/图标/信物/装饰透明。

安全区格式[x,y,宽,高]是主要构图建议，不是热区。PNG 768是SVG直接渲染，不是低分辨率图片超分。UI九宫格使用data/ui_asset_map.json的源像素及逻辑尺寸。

## 全部图片

| ID | 文件路径 | 尺寸 | Alpha | 安全区 | 用途与绑定 |
|---|---|---|---|---|---|
| `portrait_m01.infant.svg` | `assets/characters/portrait_m01/infant_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m01 / infant |
| `portrait_m01.infant.png` | `assets/characters/portrait_m01/infant_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m01 / infant |
| `portrait_m01.infant.detail.sick` | `assets/characters/portrait_m01/infant_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m01 / infant / sick |
| `portrait_m01.infant.detail.deceased` | `assets/characters/portrait_m01/infant_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m01 / infant / deceased |
| `portrait_m01.infant.normal` | `assets/characters/portrait_m01/infant_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / infant / normal |
| `portrait_m01.infant.sick` | `assets/characters/portrait_m01/infant_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / infant / sick |
| `portrait_m01.infant.deceased` | `assets/characters/portrait_m01/infant_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / infant / deceased |
| `portrait_m01.infant.selected` | `assets/characters/portrait_m01/infant_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / infant / selected |
| `portrait_m01.child.svg` | `assets/characters/portrait_m01/child_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m01 / child |
| `portrait_m01.child.png` | `assets/characters/portrait_m01/child_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m01 / child |
| `portrait_m01.child.detail.sick` | `assets/characters/portrait_m01/child_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m01 / child / sick |
| `portrait_m01.child.detail.deceased` | `assets/characters/portrait_m01/child_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m01 / child / deceased |
| `portrait_m01.child.normal` | `assets/characters/portrait_m01/child_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / child / normal |
| `portrait_m01.child.sick` | `assets/characters/portrait_m01/child_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / child / sick |
| `portrait_m01.child.deceased` | `assets/characters/portrait_m01/child_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / child / deceased |
| `portrait_m01.child.selected` | `assets/characters/portrait_m01/child_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / child / selected |
| `portrait_m01.young.svg` | `assets/characters/portrait_m01/young_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m01 / young |
| `portrait_m01.young.png` | `assets/characters/portrait_m01/young_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m01 / young |
| `portrait_m01.young.detail.sick` | `assets/characters/portrait_m01/young_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m01 / young / sick |
| `portrait_m01.young.detail.deceased` | `assets/characters/portrait_m01/young_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m01 / young / deceased |
| `portrait_m01.young.normal` | `assets/characters/portrait_m01/young_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / young / normal |
| `portrait_m01.young.sick` | `assets/characters/portrait_m01/young_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / young / sick |
| `portrait_m01.young.deceased` | `assets/characters/portrait_m01/young_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / young / deceased |
| `portrait_m01.young.selected` | `assets/characters/portrait_m01/young_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / young / selected |
| `portrait_m01.adult.svg` | `assets/characters/portrait_m01/adult_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m01 / adult |
| `portrait_m01.adult.png` | `assets/characters/portrait_m01/adult_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m01 / adult |
| `portrait_m01.adult.detail.sick` | `assets/characters/portrait_m01/adult_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m01 / adult / sick |
| `portrait_m01.adult.detail.deceased` | `assets/characters/portrait_m01/adult_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m01 / adult / deceased |
| `portrait_m01.adult.normal` | `assets/characters/portrait_m01/adult_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / adult / normal |
| `portrait_m01.adult.sick` | `assets/characters/portrait_m01/adult_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / adult / sick |
| `portrait_m01.adult.deceased` | `assets/characters/portrait_m01/adult_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / adult / deceased |
| `portrait_m01.adult.selected` | `assets/characters/portrait_m01/adult_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / adult / selected |
| `portrait_m01.elder.svg` | `assets/characters/portrait_m01/elder_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m01 / elder |
| `portrait_m01.elder.png` | `assets/characters/portrait_m01/elder_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m01 / elder |
| `portrait_m01.elder.detail.sick` | `assets/characters/portrait_m01/elder_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m01 / elder / sick |
| `portrait_m01.elder.detail.deceased` | `assets/characters/portrait_m01/elder_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m01 / elder / deceased |
| `portrait_m01.elder.normal` | `assets/characters/portrait_m01/elder_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / elder / normal |
| `portrait_m01.elder.sick` | `assets/characters/portrait_m01/elder_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / elder / sick |
| `portrait_m01.elder.deceased` | `assets/characters/portrait_m01/elder_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / elder / deceased |
| `portrait_m01.elder.selected` | `assets/characters/portrait_m01/elder_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m01 / elder / selected |
| `portrait_m02.infant.svg` | `assets/characters/portrait_m02/infant_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m02 / infant |
| `portrait_m02.infant.png` | `assets/characters/portrait_m02/infant_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m02 / infant |
| `portrait_m02.infant.detail.sick` | `assets/characters/portrait_m02/infant_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m02 / infant / sick |
| `portrait_m02.infant.detail.deceased` | `assets/characters/portrait_m02/infant_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m02 / infant / deceased |
| `portrait_m02.infant.normal` | `assets/characters/portrait_m02/infant_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / infant / normal |
| `portrait_m02.infant.sick` | `assets/characters/portrait_m02/infant_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / infant / sick |
| `portrait_m02.infant.deceased` | `assets/characters/portrait_m02/infant_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / infant / deceased |
| `portrait_m02.infant.selected` | `assets/characters/portrait_m02/infant_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / infant / selected |
| `portrait_m02.child.svg` | `assets/characters/portrait_m02/child_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m02 / child |
| `portrait_m02.child.png` | `assets/characters/portrait_m02/child_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m02 / child |
| `portrait_m02.child.detail.sick` | `assets/characters/portrait_m02/child_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m02 / child / sick |
| `portrait_m02.child.detail.deceased` | `assets/characters/portrait_m02/child_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m02 / child / deceased |
| `portrait_m02.child.normal` | `assets/characters/portrait_m02/child_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / child / normal |
| `portrait_m02.child.sick` | `assets/characters/portrait_m02/child_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / child / sick |
| `portrait_m02.child.deceased` | `assets/characters/portrait_m02/child_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / child / deceased |
| `portrait_m02.child.selected` | `assets/characters/portrait_m02/child_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / child / selected |
| `portrait_m02.young.svg` | `assets/characters/portrait_m02/young_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m02 / young |
| `portrait_m02.young.png` | `assets/characters/portrait_m02/young_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m02 / young |
| `portrait_m02.young.detail.sick` | `assets/characters/portrait_m02/young_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m02 / young / sick |
| `portrait_m02.young.detail.deceased` | `assets/characters/portrait_m02/young_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m02 / young / deceased |
| `portrait_m02.young.normal` | `assets/characters/portrait_m02/young_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / young / normal |
| `portrait_m02.young.sick` | `assets/characters/portrait_m02/young_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / young / sick |
| `portrait_m02.young.deceased` | `assets/characters/portrait_m02/young_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / young / deceased |
| `portrait_m02.young.selected` | `assets/characters/portrait_m02/young_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / young / selected |
| `portrait_m02.adult.svg` | `assets/characters/portrait_m02/adult_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m02 / adult |
| `portrait_m02.adult.png` | `assets/characters/portrait_m02/adult_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m02 / adult |
| `portrait_m02.adult.detail.sick` | `assets/characters/portrait_m02/adult_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m02 / adult / sick |
| `portrait_m02.adult.detail.deceased` | `assets/characters/portrait_m02/adult_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m02 / adult / deceased |
| `portrait_m02.adult.normal` | `assets/characters/portrait_m02/adult_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / adult / normal |
| `portrait_m02.adult.sick` | `assets/characters/portrait_m02/adult_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / adult / sick |
| `portrait_m02.adult.deceased` | `assets/characters/portrait_m02/adult_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / adult / deceased |
| `portrait_m02.adult.selected` | `assets/characters/portrait_m02/adult_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / adult / selected |
| `portrait_m02.elder.svg` | `assets/characters/portrait_m02/elder_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m02 / elder |
| `portrait_m02.elder.png` | `assets/characters/portrait_m02/elder_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_m02 / elder |
| `portrait_m02.elder.detail.sick` | `assets/characters/portrait_m02/elder_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m02 / elder / sick |
| `portrait_m02.elder.detail.deceased` | `assets/characters/portrait_m02/elder_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_m02 / elder / deceased |
| `portrait_m02.elder.normal` | `assets/characters/portrait_m02/elder_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / elder / normal |
| `portrait_m02.elder.sick` | `assets/characters/portrait_m02/elder_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / elder / sick |
| `portrait_m02.elder.deceased` | `assets/characters/portrait_m02/elder_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / elder / deceased |
| `portrait_m02.elder.selected` | `assets/characters/portrait_m02/elder_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_m02 / elder / selected |
| `portrait_f01.infant.svg` | `assets/characters/portrait_f01/infant_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f01 / infant |
| `portrait_f01.infant.png` | `assets/characters/portrait_f01/infant_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f01 / infant |
| `portrait_f01.infant.detail.sick` | `assets/characters/portrait_f01/infant_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f01 / infant / sick |
| `portrait_f01.infant.detail.deceased` | `assets/characters/portrait_f01/infant_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f01 / infant / deceased |
| `portrait_f01.infant.normal` | `assets/characters/portrait_f01/infant_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / infant / normal |
| `portrait_f01.infant.sick` | `assets/characters/portrait_f01/infant_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / infant / sick |
| `portrait_f01.infant.deceased` | `assets/characters/portrait_f01/infant_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / infant / deceased |
| `portrait_f01.infant.selected` | `assets/characters/portrait_f01/infant_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / infant / selected |
| `portrait_f01.child.svg` | `assets/characters/portrait_f01/child_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f01 / child |
| `portrait_f01.child.png` | `assets/characters/portrait_f01/child_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f01 / child |
| `portrait_f01.child.detail.sick` | `assets/characters/portrait_f01/child_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f01 / child / sick |
| `portrait_f01.child.detail.deceased` | `assets/characters/portrait_f01/child_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f01 / child / deceased |
| `portrait_f01.child.normal` | `assets/characters/portrait_f01/child_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / child / normal |
| `portrait_f01.child.sick` | `assets/characters/portrait_f01/child_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / child / sick |
| `portrait_f01.child.deceased` | `assets/characters/portrait_f01/child_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / child / deceased |
| `portrait_f01.child.selected` | `assets/characters/portrait_f01/child_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / child / selected |
| `portrait_f01.young.svg` | `assets/characters/portrait_f01/young_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f01 / young |
| `portrait_f01.young.png` | `assets/characters/portrait_f01/young_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f01 / young |
| `portrait_f01.young.detail.sick` | `assets/characters/portrait_f01/young_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f01 / young / sick |
| `portrait_f01.young.detail.deceased` | `assets/characters/portrait_f01/young_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f01 / young / deceased |
| `portrait_f01.young.normal` | `assets/characters/portrait_f01/young_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / young / normal |
| `portrait_f01.young.sick` | `assets/characters/portrait_f01/young_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / young / sick |
| `portrait_f01.young.deceased` | `assets/characters/portrait_f01/young_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / young / deceased |
| `portrait_f01.young.selected` | `assets/characters/portrait_f01/young_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / young / selected |
| `portrait_f01.adult.svg` | `assets/characters/portrait_f01/adult_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f01 / adult |
| `portrait_f01.adult.png` | `assets/characters/portrait_f01/adult_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f01 / adult |
| `portrait_f01.adult.detail.sick` | `assets/characters/portrait_f01/adult_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f01 / adult / sick |
| `portrait_f01.adult.detail.deceased` | `assets/characters/portrait_f01/adult_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f01 / adult / deceased |
| `portrait_f01.adult.normal` | `assets/characters/portrait_f01/adult_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / adult / normal |
| `portrait_f01.adult.sick` | `assets/characters/portrait_f01/adult_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / adult / sick |
| `portrait_f01.adult.deceased` | `assets/characters/portrait_f01/adult_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / adult / deceased |
| `portrait_f01.adult.selected` | `assets/characters/portrait_f01/adult_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / adult / selected |
| `portrait_f01.elder.svg` | `assets/characters/portrait_f01/elder_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f01 / elder |
| `portrait_f01.elder.png` | `assets/characters/portrait_f01/elder_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f01 / elder |
| `portrait_f01.elder.detail.sick` | `assets/characters/portrait_f01/elder_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f01 / elder / sick |
| `portrait_f01.elder.detail.deceased` | `assets/characters/portrait_f01/elder_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f01 / elder / deceased |
| `portrait_f01.elder.normal` | `assets/characters/portrait_f01/elder_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / elder / normal |
| `portrait_f01.elder.sick` | `assets/characters/portrait_f01/elder_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / elder / sick |
| `portrait_f01.elder.deceased` | `assets/characters/portrait_f01/elder_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / elder / deceased |
| `portrait_f01.elder.selected` | `assets/characters/portrait_f01/elder_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f01 / elder / selected |
| `portrait_f02.infant.svg` | `assets/characters/portrait_f02/infant_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f02 / infant |
| `portrait_f02.infant.png` | `assets/characters/portrait_f02/infant_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f02 / infant |
| `portrait_f02.infant.detail.sick` | `assets/characters/portrait_f02/infant_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f02 / infant / sick |
| `portrait_f02.infant.detail.deceased` | `assets/characters/portrait_f02/infant_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f02 / infant / deceased |
| `portrait_f02.infant.normal` | `assets/characters/portrait_f02/infant_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / infant / normal |
| `portrait_f02.infant.sick` | `assets/characters/portrait_f02/infant_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / infant / sick |
| `portrait_f02.infant.deceased` | `assets/characters/portrait_f02/infant_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / infant / deceased |
| `portrait_f02.infant.selected` | `assets/characters/portrait_f02/infant_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / infant / selected |
| `portrait_f02.child.svg` | `assets/characters/portrait_f02/child_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f02 / child |
| `portrait_f02.child.png` | `assets/characters/portrait_f02/child_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f02 / child |
| `portrait_f02.child.detail.sick` | `assets/characters/portrait_f02/child_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f02 / child / sick |
| `portrait_f02.child.detail.deceased` | `assets/characters/portrait_f02/child_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f02 / child / deceased |
| `portrait_f02.child.normal` | `assets/characters/portrait_f02/child_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / child / normal |
| `portrait_f02.child.sick` | `assets/characters/portrait_f02/child_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / child / sick |
| `portrait_f02.child.deceased` | `assets/characters/portrait_f02/child_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / child / deceased |
| `portrait_f02.child.selected` | `assets/characters/portrait_f02/child_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / child / selected |
| `portrait_f02.young.svg` | `assets/characters/portrait_f02/young_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f02 / young |
| `portrait_f02.young.png` | `assets/characters/portrait_f02/young_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f02 / young |
| `portrait_f02.young.detail.sick` | `assets/characters/portrait_f02/young_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f02 / young / sick |
| `portrait_f02.young.detail.deceased` | `assets/characters/portrait_f02/young_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f02 / young / deceased |
| `portrait_f02.young.normal` | `assets/characters/portrait_f02/young_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / young / normal |
| `portrait_f02.young.sick` | `assets/characters/portrait_f02/young_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / young / sick |
| `portrait_f02.young.deceased` | `assets/characters/portrait_f02/young_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / young / deceased |
| `portrait_f02.young.selected` | `assets/characters/portrait_f02/young_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / young / selected |
| `portrait_f02.adult.svg` | `assets/characters/portrait_f02/adult_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f02 / adult |
| `portrait_f02.adult.png` | `assets/characters/portrait_f02/adult_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f02 / adult |
| `portrait_f02.adult.detail.sick` | `assets/characters/portrait_f02/adult_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f02 / adult / sick |
| `portrait_f02.adult.detail.deceased` | `assets/characters/portrait_f02/adult_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f02 / adult / deceased |
| `portrait_f02.adult.normal` | `assets/characters/portrait_f02/adult_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / adult / normal |
| `portrait_f02.adult.sick` | `assets/characters/portrait_f02/adult_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / adult / sick |
| `portrait_f02.adult.deceased` | `assets/characters/portrait_f02/adult_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / adult / deceased |
| `portrait_f02.adult.selected` | `assets/characters/portrait_f02/adult_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / adult / selected |
| `portrait_f02.elder.svg` | `assets/characters/portrait_f02/elder_detail.svg` | 512×512 | 有 | `[50, 40, 412, 472]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f02 / elder |
| `portrait_f02.elder.png` | `assets/characters/portrait_f02/elder_detail.png` | 768×768 | 有 | `[75, 60, 618, 708]` | 人物详情透明源；不含姓名或游戏属性。 portrait_f02 / elder |
| `portrait_f02.elder.detail.sick` | `assets/characters/portrait_f02/elder_detail_sick.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f02 / elder / sick |
| `portrait_f02.elder.detail.deceased` | `assets/characters/portrait_f02/elder_detail_deceased.png` | 768×768 | 有 | `[0, 0, 768, 768]` | 同一原画色阶衍生；不重新生成脸。 portrait_f02 / elder / deceased |
| `portrait_f02.elder.normal` | `assets/characters/portrait_f02/elder_normal_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / elder / normal |
| `portrait_f02.elder.sick` | `assets/characters/portrait_f02/elder_sick_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / elder / sick |
| `portrait_f02.elder.deceased` | `assets/characters/portrait_f02/elder_deceased_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / elder / deceased |
| `portrait_f02.elder.selected` | `assets/characters/portrait_f02/elder_selected_256.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 圆形头像；状态色阶/边框，不改美术身份。 portrait_f02 / elder / selected |
| `house.rented.normal.svg` | `assets/houses/rented_normal.svg` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 normal / rented |
| `house.rented.normal.png` | `assets/houses/rented_normal.png` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 normal / rented |
| `house.rented.damaged.svg` | `assets/houses/rented_damaged.svg` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 damaged / rented |
| `house.rented.damaged.png` | `assets/houses/rented_damaged.png` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 damaged / rented |
| `house.rented.upgraded.svg` | `assets/houses/rented_upgraded.svg` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 upgraded / rented |
| `house.rented.upgraded.png` | `assets/houses/rented_upgraded.png` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 upgraded / rented |
| `house.rented.relocated.svg` | `assets/houses/rented_relocated.svg` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 relocated / rented |
| `house.rented.relocated.png` | `assets/houses/rented_relocated.png` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 relocated / rented |
| `house.simple.normal.svg` | `assets/houses/simple_normal.svg` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 normal / simple |
| `house.simple.normal.png` | `assets/houses/simple_normal.png` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 normal / simple |
| `house.simple.damaged.svg` | `assets/houses/simple_damaged.svg` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 damaged / simple |
| `house.simple.damaged.png` | `assets/houses/simple_damaged.png` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 damaged / simple |
| `house.simple.upgraded.svg` | `assets/houses/simple_upgraded.svg` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 upgraded / simple |
| `house.simple.upgraded.png` | `assets/houses/simple_upgraded.png` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 upgraded / simple |
| `house.simple.relocated.svg` | `assets/houses/simple_relocated.svg` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 relocated / simple |
| `house.simple.relocated.png` | `assets/houses/simple_relocated.png` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 relocated / simple |
| `house.courtyard.normal.svg` | `assets/houses/courtyard_normal.svg` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 normal / courtyard |
| `house.courtyard.normal.png` | `assets/houses/courtyard_normal.png` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 normal / courtyard |
| `house.courtyard.damaged.svg` | `assets/houses/courtyard_damaged.svg` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 damaged / courtyard |
| `house.courtyard.damaged.png` | `assets/houses/courtyard_damaged.png` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 damaged / courtyard |
| `house.courtyard.upgraded.svg` | `assets/houses/courtyard_upgraded.svg` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 upgraded / courtyard |
| `house.courtyard.upgraded.png` | `assets/houses/courtyard_upgraded.png` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 upgraded / courtyard |
| `house.courtyard.relocated.svg` | `assets/houses/courtyard_relocated.svg` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 relocated / courtyard |
| `house.courtyard.relocated.png` | `assets/houses/courtyard_relocated.png` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 relocated / courtyard |
| `house.estate.normal.svg` | `assets/houses/estate_normal.svg` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 normal / estate |
| `house.estate.normal.png` | `assets/houses/estate_normal.png` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 normal / estate |
| `house.estate.damaged.svg` | `assets/houses/estate_damaged.svg` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 damaged / estate |
| `house.estate.damaged.png` | `assets/houses/estate_damaged.png` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 damaged / estate |
| `house.estate.upgraded.svg` | `assets/houses/estate_upgraded.svg` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 upgraded / estate |
| `house.estate.upgraded.png` | `assets/houses/estate_upgraded.png` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 upgraded / estate |
| `house.estate.relocated.svg` | `assets/houses/estate_relocated.svg` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 relocated / estate |
| `house.estate.relocated.png` | `assets/houses/estate_relocated.png` | 1200×560 | 无 | `[75, 55, 1050, 475]` | 家宅状态完整横图；不透明米白底，不决定资产或游戏规则。 relocated / estate |
| `relic.ruler.svg` | `assets/relics/ruler.svg` | 512×512 | 有 | `[45, 85, 425, 355]` | 信物本体透明图；不含玩家姓名和收益文案。 ruler |
| `relic.ruler.png` | `assets/relics/ruler.png` | 512×512 | 有 | `[45, 85, 425, 355]` | 信物本体透明图；不含玩家姓名和收益文案。 ruler |
| `relic.book.svg` | `assets/relics/book.svg` | 512×512 | 有 | `[45, 85, 425, 355]` | 信物本体透明图；不含玩家姓名和收益文案。 book |
| `relic.book.png` | `assets/relics/book.png` | 512×512 | 有 | `[45, 85, 425, 355]` | 信物本体透明图；不含玩家姓名和收益文案。 book |
| `relic.letter.svg` | `assets/relics/letter.svg` | 512×512 | 有 | `[45, 85, 425, 355]` | 信物本体透明图；不含玩家姓名和收益文案。 letter |
| `relic.letter.png` | `assets/relics/letter.png` | 512×512 | 有 | `[45, 85, 425, 355]` | 信物本体透明图；不含玩家姓名和收益文案。 letter |
| `relic.plan.svg` | `assets/relics/plan.svg` | 512×512 | 有 | `[45, 85, 425, 355]` | 信物本体透明图；不含玩家姓名和收益文案。 plan |
| `relic.plan.png` | `assets/relics/plan.png` | 512×512 | 有 | `[45, 85, 425, 355]` | 信物本体透明图；不含玩家姓名和收益文案。 plan |
| `relic.newbook.svg` | `assets/relics/newbook.svg` | 512×512 | 有 | `[45, 85, 425, 355]` | 信物本体透明图；不含玩家姓名和收益文案。 newbook |
| `relic.newbook.png` | `assets/relics/newbook.png` | 512×512 | 有 | `[45, 85, 425, 355]` | 信物本体透明图；不含玩家姓名和收益文案。 newbook |
| `relic.jade.svg` | `assets/relics/jade.svg` | 512×512 | 有 | `[45, 85, 425, 355]` | 信物本体透明图；不含玩家姓名和收益文案。 jade |
| `relic.jade.png` | `assets/relics/jade.png` | 512×512 | 有 | `[45, 85, 425, 355]` | 信物本体透明图；不含玩家姓名和收益文案。 jade |
| `relic.notes.svg` | `assets/relics/notes.svg` | 512×512 | 有 | `[45, 85, 425, 355]` | 信物本体透明图；不含玩家姓名和收益文案。 notes |
| `relic.notes.png` | `assets/relics/notes.png` | 512×512 | 有 | `[45, 85, 425, 355]` | 信物本体透明图；不含玩家姓名和收益文案。 notes |
| `event.ruler.svg` | `assets/events/ruler.svg` | 1200×560 | 无 | `[110, 45, 980, 465]` | 木尺旧匠号。事件卡顶图，无正文或按钮。 ruler |
| `event.ruler.png` | `assets/events/ruler.png` | 1200×560 | 无 | `[110, 45, 980, 465]` | 木尺旧匠号。事件卡顶图，无正文或按钮。 ruler |
| `event.book.svg` | `assets/events/book.svg` | 1200×560 | 无 | `[110, 45, 980, 465]` | 族谱缺页。事件卡顶图，无正文或按钮。 book |
| `event.book.png` | `assets/events/book.png` | 1200×560 | 无 | `[110, 45, 980, 465]` | 族谱缺页。事件卡顶图，无正文或按钮。 book |
| `event.letter.svg` | `assets/events/letter.svg` | 1200×560 | 无 | `[110, 45, 980, 465]` | 家书旧约。事件卡顶图，无正文或按钮。 letter |
| `event.letter.png` | `assets/events/letter.png` | 1200×560 | 无 | `[110, 45, 980, 465]` | 家书旧约。事件卡顶图，无正文或按钮。 letter |
| `event.medical.svg` | `assets/events/medical.svg` | 1200×560 | 无 | `[110, 45, 980, 465]` | 医案与问诊。事件卡顶图，无正文或按钮。 medical |
| `event.medical.png` | `assets/events/medical.png` | 1200×560 | 无 | `[110, 45, 980, 465]` | 医案与问诊。事件卡顶图，无正文或按钮。 medical |
| `event.repair.svg` | `assets/events/repair.svg` | 1200×560 | 无 | `[110, 45, 980, 465]` | 修缮营造。事件卡顶图，无正文或按钮。 repair |
| `event.repair.png` | `assets/events/repair.png` | 1200×560 | 无 | `[110, 45, 980, 465]` | 修缮营造。事件卡顶图，无正文或按钮。 repair |
| `event.neighbors.svg` | `assets/events/neighbors.svg` | 1200×560 | 无 | `[110, 45, 980, 465]` | 邻里互助。事件卡顶图，无正文或按钮。 neighbors |
| `event.neighbors.png` | `assets/events/neighbors.png` | 1200×560 | 无 | `[110, 45, 980, 465]` | 邻里互助。事件卡顶图，无正文或按钮。 neighbors |
| `event.school.svg` | `assets/events/school.svg` | 1200×560 | 无 | `[110, 45, 980, 465]` | 求学应试。事件卡顶图，无正文或按钮。 school |
| `event.school.png` | `assets/events/school.png` | 1200×560 | 无 | `[110, 45, 980, 465]` | 求学应试。事件卡顶图，无正文或按钮。 school |
| `event.roof.svg` | `assets/events/roof.svg` | 1200×560 | 无 | `[110, 45, 980, 465]` | 风雨屋顶。事件卡顶图，无正文或按钮。 roof |
| `event.roof.png` | `assets/events/roof.png` | 1200×560 | 无 | `[110, 45, 980, 465]` | 风雨屋顶。事件卡顶图，无正文或按钮。 roof |
| `event.jade.svg` | `assets/events/jade.svg` | 1200×560 | 无 | `[110, 45, 980, 465]` | 故人玉佩。事件卡顶图，无正文或按钮。 jade |
| `event.jade.png` | `assets/events/jade.png` | 1200×560 | 无 | `[110, 45, 980, 465]` | 故人玉佩。事件卡顶图，无正文或按钮。 jade |
| `event.reunion.svg` | `assets/events/reunion.svg` | 1200×560 | 无 | `[110, 45, 980, 465]` | 旁支归家。事件卡顶图，无正文或按钮。 reunion |
| `event.reunion.png` | `assets/events/reunion.png` | 1200×560 | 无 | `[110, 45, 980, 465]` | 旁支归家。事件卡顶图，无正文或按钮。 reunion |
| `event.leadership.svg` | `assets/events/leadership.svg` | 1200×560 | 无 | `[110, 45, 980, 465]` | 族长交接。事件卡顶图，无正文或按钮。 leadership |
| `event.leadership.png` | `assets/events/leadership.png` | 1200×560 | 无 | `[110, 45, 980, 465]` | 族长交接。事件卡顶图，无正文或按钮。 leadership |
| `event.migration.svg` | `assets/events/migration.svg` | 1200×560 | 无 | `[110, 45, 980, 465]` | 迁居新址。事件卡顶图，无正文或按钮。 migration |
| `event.migration.png` | `assets/events/migration.png` | 1200×560 | 无 | `[110, 45, 980, 465]` | 迁居新址。事件卡顶图，无正文或按钮。 migration |
| `icon.family.ink.svg` | `assets/icons/family_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 family / ink |
| `icon.family.ink@1x.png` | `assets/icons/family_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 family / ink |
| `icon.family.ink@2x.png` | `assets/icons/family_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 family / ink |
| `icon.family.ink@3x.png` | `assets/icons/family_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 family / ink |
| `icon.family.paper.svg` | `assets/icons/family_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 family / paper |
| `icon.family.paper@1x.png` | `assets/icons/family_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 family / paper |
| `icon.family.paper@2x.png` | `assets/icons/family_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 family / paper |
| `icon.family.paper@3x.png` | `assets/icons/family_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 family / paper |
| `icon.family.muted.svg` | `assets/icons/family_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 family / muted |
| `icon.family.muted@1x.png` | `assets/icons/family_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 family / muted |
| `icon.family.muted@2x.png` | `assets/icons/family_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 family / muted |
| `icon.family.muted@3x.png` | `assets/icons/family_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 family / muted |
| `icon.people.ink.svg` | `assets/icons/people_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 people / ink |
| `icon.people.ink@1x.png` | `assets/icons/people_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 people / ink |
| `icon.people.ink@2x.png` | `assets/icons/people_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 people / ink |
| `icon.people.ink@3x.png` | `assets/icons/people_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 people / ink |
| `icon.people.paper.svg` | `assets/icons/people_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 people / paper |
| `icon.people.paper@1x.png` | `assets/icons/people_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 people / paper |
| `icon.people.paper@2x.png` | `assets/icons/people_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 people / paper |
| `icon.people.paper@3x.png` | `assets/icons/people_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 people / paper |
| `icon.people.muted.svg` | `assets/icons/people_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 people / muted |
| `icon.people.muted@1x.png` | `assets/icons/people_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 people / muted |
| `icon.people.muted@2x.png` | `assets/icons/people_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 people / muted |
| `icon.people.muted@3x.png` | `assets/icons/people_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 people / muted |
| `icon.estate.ink.svg` | `assets/icons/estate_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 estate / ink |
| `icon.estate.ink@1x.png` | `assets/icons/estate_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 estate / ink |
| `icon.estate.ink@2x.png` | `assets/icons/estate_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 estate / ink |
| `icon.estate.ink@3x.png` | `assets/icons/estate_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 estate / ink |
| `icon.estate.paper.svg` | `assets/icons/estate_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 estate / paper |
| `icon.estate.paper@1x.png` | `assets/icons/estate_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 estate / paper |
| `icon.estate.paper@2x.png` | `assets/icons/estate_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 estate / paper |
| `icon.estate.paper@3x.png` | `assets/icons/estate_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 estate / paper |
| `icon.estate.muted.svg` | `assets/icons/estate_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 estate / muted |
| `icon.estate.muted@1x.png` | `assets/icons/estate_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 estate / muted |
| `icon.estate.muted@2x.png` | `assets/icons/estate_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 estate / muted |
| `icon.estate.muted@3x.png` | `assets/icons/estate_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 estate / muted |
| `icon.relics.ink.svg` | `assets/icons/relics_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relics / ink |
| `icon.relics.ink@1x.png` | `assets/icons/relics_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relics / ink |
| `icon.relics.ink@2x.png` | `assets/icons/relics_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relics / ink |
| `icon.relics.ink@3x.png` | `assets/icons/relics_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relics / ink |
| `icon.relics.paper.svg` | `assets/icons/relics_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relics / paper |
| `icon.relics.paper@1x.png` | `assets/icons/relics_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relics / paper |
| `icon.relics.paper@2x.png` | `assets/icons/relics_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relics / paper |
| `icon.relics.paper@3x.png` | `assets/icons/relics_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relics / paper |
| `icon.relics.muted.svg` | `assets/icons/relics_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relics / muted |
| `icon.relics.muted@1x.png` | `assets/icons/relics_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relics / muted |
| `icon.relics.muted@2x.png` | `assets/icons/relics_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relics / muted |
| `icon.relics.muted@3x.png` | `assets/icons/relics_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relics / muted |
| `icon.history.ink.svg` | `assets/icons/history_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 history / ink |
| `icon.history.ink@1x.png` | `assets/icons/history_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 history / ink |
| `icon.history.ink@2x.png` | `assets/icons/history_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 history / ink |
| `icon.history.ink@3x.png` | `assets/icons/history_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 history / ink |
| `icon.history.paper.svg` | `assets/icons/history_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 history / paper |
| `icon.history.paper@1x.png` | `assets/icons/history_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 history / paper |
| `icon.history.paper@2x.png` | `assets/icons/history_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 history / paper |
| `icon.history.paper@3x.png` | `assets/icons/history_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 history / paper |
| `icon.history.muted.svg` | `assets/icons/history_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 history / muted |
| `icon.history.muted@1x.png` | `assets/icons/history_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 history / muted |
| `icon.history.muted@2x.png` | `assets/icons/history_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 history / muted |
| `icon.history.muted@3x.png` | `assets/icons/history_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 history / muted |
| `icon.money.ink.svg` | `assets/icons/money_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 money / ink |
| `icon.money.ink@1x.png` | `assets/icons/money_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 money / ink |
| `icon.money.ink@2x.png` | `assets/icons/money_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 money / ink |
| `icon.money.ink@3x.png` | `assets/icons/money_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 money / ink |
| `icon.money.paper.svg` | `assets/icons/money_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 money / paper |
| `icon.money.paper@1x.png` | `assets/icons/money_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 money / paper |
| `icon.money.paper@2x.png` | `assets/icons/money_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 money / paper |
| `icon.money.paper@3x.png` | `assets/icons/money_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 money / paper |
| `icon.money.muted.svg` | `assets/icons/money_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 money / muted |
| `icon.money.muted@1x.png` | `assets/icons/money_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 money / muted |
| `icon.money.muted@2x.png` | `assets/icons/money_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 money / muted |
| `icon.money.muted@3x.png` | `assets/icons/money_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 money / muted |
| `icon.grain.ink.svg` | `assets/icons/grain_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 grain / ink |
| `icon.grain.ink@1x.png` | `assets/icons/grain_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 grain / ink |
| `icon.grain.ink@2x.png` | `assets/icons/grain_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 grain / ink |
| `icon.grain.ink@3x.png` | `assets/icons/grain_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 grain / ink |
| `icon.grain.paper.svg` | `assets/icons/grain_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 grain / paper |
| `icon.grain.paper@1x.png` | `assets/icons/grain_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 grain / paper |
| `icon.grain.paper@2x.png` | `assets/icons/grain_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 grain / paper |
| `icon.grain.paper@3x.png` | `assets/icons/grain_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 grain / paper |
| `icon.grain.muted.svg` | `assets/icons/grain_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 grain / muted |
| `icon.grain.muted@1x.png` | `assets/icons/grain_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 grain / muted |
| `icon.grain.muted@2x.png` | `assets/icons/grain_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 grain / muted |
| `icon.grain.muted@3x.png` | `assets/icons/grain_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 grain / muted |
| `icon.land.ink.svg` | `assets/icons/land_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 land / ink |
| `icon.land.ink@1x.png` | `assets/icons/land_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 land / ink |
| `icon.land.ink@2x.png` | `assets/icons/land_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 land / ink |
| `icon.land.ink@3x.png` | `assets/icons/land_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 land / ink |
| `icon.land.paper.svg` | `assets/icons/land_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 land / paper |
| `icon.land.paper@1x.png` | `assets/icons/land_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 land / paper |
| `icon.land.paper@2x.png` | `assets/icons/land_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 land / paper |
| `icon.land.paper@3x.png` | `assets/icons/land_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 land / paper |
| `icon.land.muted.svg` | `assets/icons/land_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 land / muted |
| `icon.land.muted@1x.png` | `assets/icons/land_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 land / muted |
| `icon.land.muted@2x.png` | `assets/icons/land_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 land / muted |
| `icon.land.muted@3x.png` | `assets/icons/land_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 land / muted |
| `icon.relationship.ink.svg` | `assets/icons/relationship_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relationship / ink |
| `icon.relationship.ink@1x.png` | `assets/icons/relationship_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relationship / ink |
| `icon.relationship.ink@2x.png` | `assets/icons/relationship_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relationship / ink |
| `icon.relationship.ink@3x.png` | `assets/icons/relationship_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relationship / ink |
| `icon.relationship.paper.svg` | `assets/icons/relationship_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relationship / paper |
| `icon.relationship.paper@1x.png` | `assets/icons/relationship_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relationship / paper |
| `icon.relationship.paper@2x.png` | `assets/icons/relationship_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relationship / paper |
| `icon.relationship.paper@3x.png` | `assets/icons/relationship_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relationship / paper |
| `icon.relationship.muted.svg` | `assets/icons/relationship_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relationship / muted |
| `icon.relationship.muted@1x.png` | `assets/icons/relationship_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relationship / muted |
| `icon.relationship.muted@2x.png` | `assets/icons/relationship_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relationship / muted |
| `icon.relationship.muted@3x.png` | `assets/icons/relationship_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 relationship / muted |
| `icon.lock.ink.svg` | `assets/icons/lock_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 lock / ink |
| `icon.lock.ink@1x.png` | `assets/icons/lock_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 lock / ink |
| `icon.lock.ink@2x.png` | `assets/icons/lock_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 lock / ink |
| `icon.lock.ink@3x.png` | `assets/icons/lock_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 lock / ink |
| `icon.lock.paper.svg` | `assets/icons/lock_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 lock / paper |
| `icon.lock.paper@1x.png` | `assets/icons/lock_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 lock / paper |
| `icon.lock.paper@2x.png` | `assets/icons/lock_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 lock / paper |
| `icon.lock.paper@3x.png` | `assets/icons/lock_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 lock / paper |
| `icon.lock.muted.svg` | `assets/icons/lock_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 lock / muted |
| `icon.lock.muted@1x.png` | `assets/icons/lock_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 lock / muted |
| `icon.lock.muted@2x.png` | `assets/icons/lock_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 lock / muted |
| `icon.lock.muted@3x.png` | `assets/icons/lock_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 lock / muted |
| `icon.unlock.ink.svg` | `assets/icons/unlock_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 unlock / ink |
| `icon.unlock.ink@1x.png` | `assets/icons/unlock_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 unlock / ink |
| `icon.unlock.ink@2x.png` | `assets/icons/unlock_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 unlock / ink |
| `icon.unlock.ink@3x.png` | `assets/icons/unlock_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 unlock / ink |
| `icon.unlock.paper.svg` | `assets/icons/unlock_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 unlock / paper |
| `icon.unlock.paper@1x.png` | `assets/icons/unlock_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 unlock / paper |
| `icon.unlock.paper@2x.png` | `assets/icons/unlock_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 unlock / paper |
| `icon.unlock.paper@3x.png` | `assets/icons/unlock_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 unlock / paper |
| `icon.unlock.muted.svg` | `assets/icons/unlock_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 unlock / muted |
| `icon.unlock.muted@1x.png` | `assets/icons/unlock_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 unlock / muted |
| `icon.unlock.muted@2x.png` | `assets/icons/unlock_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 unlock / muted |
| `icon.unlock.muted@3x.png` | `assets/icons/unlock_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 unlock / muted |
| `icon.back.ink.svg` | `assets/icons/back_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 back / ink |
| `icon.back.ink@1x.png` | `assets/icons/back_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 back / ink |
| `icon.back.ink@2x.png` | `assets/icons/back_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 back / ink |
| `icon.back.ink@3x.png` | `assets/icons/back_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 back / ink |
| `icon.back.paper.svg` | `assets/icons/back_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 back / paper |
| `icon.back.paper@1x.png` | `assets/icons/back_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 back / paper |
| `icon.back.paper@2x.png` | `assets/icons/back_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 back / paper |
| `icon.back.paper@3x.png` | `assets/icons/back_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 back / paper |
| `icon.back.muted.svg` | `assets/icons/back_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 back / muted |
| `icon.back.muted@1x.png` | `assets/icons/back_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 back / muted |
| `icon.back.muted@2x.png` | `assets/icons/back_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 back / muted |
| `icon.back.muted@3x.png` | `assets/icons/back_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 back / muted |
| `icon.forward.ink.svg` | `assets/icons/forward_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 forward / ink |
| `icon.forward.ink@1x.png` | `assets/icons/forward_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 forward / ink |
| `icon.forward.ink@2x.png` | `assets/icons/forward_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 forward / ink |
| `icon.forward.ink@3x.png` | `assets/icons/forward_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 forward / ink |
| `icon.forward.paper.svg` | `assets/icons/forward_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 forward / paper |
| `icon.forward.paper@1x.png` | `assets/icons/forward_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 forward / paper |
| `icon.forward.paper@2x.png` | `assets/icons/forward_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 forward / paper |
| `icon.forward.paper@3x.png` | `assets/icons/forward_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 forward / paper |
| `icon.forward.muted.svg` | `assets/icons/forward_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 forward / muted |
| `icon.forward.muted@1x.png` | `assets/icons/forward_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 forward / muted |
| `icon.forward.muted@2x.png` | `assets/icons/forward_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 forward / muted |
| `icon.forward.muted@3x.png` | `assets/icons/forward_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 forward / muted |
| `icon.random.ink.svg` | `assets/icons/random_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 random / ink |
| `icon.random.ink@1x.png` | `assets/icons/random_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 random / ink |
| `icon.random.ink@2x.png` | `assets/icons/random_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 random / ink |
| `icon.random.ink@3x.png` | `assets/icons/random_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 random / ink |
| `icon.random.paper.svg` | `assets/icons/random_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 random / paper |
| `icon.random.paper@1x.png` | `assets/icons/random_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 random / paper |
| `icon.random.paper@2x.png` | `assets/icons/random_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 random / paper |
| `icon.random.paper@3x.png` | `assets/icons/random_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 random / paper |
| `icon.random.muted.svg` | `assets/icons/random_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 random / muted |
| `icon.random.muted@1x.png` | `assets/icons/random_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 random / muted |
| `icon.random.muted@2x.png` | `assets/icons/random_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 random / muted |
| `icon.random.muted@3x.png` | `assets/icons/random_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 random / muted |
| `icon.edit.ink.svg` | `assets/icons/edit_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 edit / ink |
| `icon.edit.ink@1x.png` | `assets/icons/edit_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 edit / ink |
| `icon.edit.ink@2x.png` | `assets/icons/edit_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 edit / ink |
| `icon.edit.ink@3x.png` | `assets/icons/edit_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 edit / ink |
| `icon.edit.paper.svg` | `assets/icons/edit_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 edit / paper |
| `icon.edit.paper@1x.png` | `assets/icons/edit_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 edit / paper |
| `icon.edit.paper@2x.png` | `assets/icons/edit_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 edit / paper |
| `icon.edit.paper@3x.png` | `assets/icons/edit_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 edit / paper |
| `icon.edit.muted.svg` | `assets/icons/edit_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 edit / muted |
| `icon.edit.muted@1x.png` | `assets/icons/edit_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 edit / muted |
| `icon.edit.muted@2x.png` | `assets/icons/edit_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 edit / muted |
| `icon.edit.muted@3x.png` | `assets/icons/edit_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 edit / muted |
| `icon.close.ink.svg` | `assets/icons/close_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 close / ink |
| `icon.close.ink@1x.png` | `assets/icons/close_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 close / ink |
| `icon.close.ink@2x.png` | `assets/icons/close_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 close / ink |
| `icon.close.ink@3x.png` | `assets/icons/close_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 close / ink |
| `icon.close.paper.svg` | `assets/icons/close_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 close / paper |
| `icon.close.paper@1x.png` | `assets/icons/close_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 close / paper |
| `icon.close.paper@2x.png` | `assets/icons/close_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 close / paper |
| `icon.close.paper@3x.png` | `assets/icons/close_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 close / paper |
| `icon.close.muted.svg` | `assets/icons/close_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 close / muted |
| `icon.close.muted@1x.png` | `assets/icons/close_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 close / muted |
| `icon.close.muted@2x.png` | `assets/icons/close_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 close / muted |
| `icon.close.muted@3x.png` | `assets/icons/close_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 close / muted |
| `icon.check.ink.svg` | `assets/icons/check_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 check / ink |
| `icon.check.ink@1x.png` | `assets/icons/check_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 check / ink |
| `icon.check.ink@2x.png` | `assets/icons/check_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 check / ink |
| `icon.check.ink@3x.png` | `assets/icons/check_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 check / ink |
| `icon.check.paper.svg` | `assets/icons/check_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 check / paper |
| `icon.check.paper@1x.png` | `assets/icons/check_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 check / paper |
| `icon.check.paper@2x.png` | `assets/icons/check_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 check / paper |
| `icon.check.paper@3x.png` | `assets/icons/check_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 check / paper |
| `icon.check.muted.svg` | `assets/icons/check_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 check / muted |
| `icon.check.muted@1x.png` | `assets/icons/check_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 check / muted |
| `icon.check.muted@2x.png` | `assets/icons/check_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 check / muted |
| `icon.check.muted@3x.png` | `assets/icons/check_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 check / muted |
| `icon.plus.ink.svg` | `assets/icons/plus_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 plus / ink |
| `icon.plus.ink@1x.png` | `assets/icons/plus_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 plus / ink |
| `icon.plus.ink@2x.png` | `assets/icons/plus_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 plus / ink |
| `icon.plus.ink@3x.png` | `assets/icons/plus_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 plus / ink |
| `icon.plus.paper.svg` | `assets/icons/plus_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 plus / paper |
| `icon.plus.paper@1x.png` | `assets/icons/plus_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 plus / paper |
| `icon.plus.paper@2x.png` | `assets/icons/plus_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 plus / paper |
| `icon.plus.paper@3x.png` | `assets/icons/plus_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 plus / paper |
| `icon.plus.muted.svg` | `assets/icons/plus_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 plus / muted |
| `icon.plus.muted@1x.png` | `assets/icons/plus_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 plus / muted |
| `icon.plus.muted@2x.png` | `assets/icons/plus_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 plus / muted |
| `icon.plus.muted@3x.png` | `assets/icons/plus_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 plus / muted |
| `icon.minus.ink.svg` | `assets/icons/minus_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 minus / ink |
| `icon.minus.ink@1x.png` | `assets/icons/minus_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 minus / ink |
| `icon.minus.ink@2x.png` | `assets/icons/minus_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 minus / ink |
| `icon.minus.ink@3x.png` | `assets/icons/minus_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 minus / ink |
| `icon.minus.paper.svg` | `assets/icons/minus_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 minus / paper |
| `icon.minus.paper@1x.png` | `assets/icons/minus_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 minus / paper |
| `icon.minus.paper@2x.png` | `assets/icons/minus_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 minus / paper |
| `icon.minus.paper@3x.png` | `assets/icons/minus_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 minus / paper |
| `icon.minus.muted.svg` | `assets/icons/minus_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 minus / muted |
| `icon.minus.muted@1x.png` | `assets/icons/minus_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 minus / muted |
| `icon.minus.muted@2x.png` | `assets/icons/minus_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 minus / muted |
| `icon.minus.muted@3x.png` | `assets/icons/minus_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 minus / muted |
| `icon.info.ink.svg` | `assets/icons/info_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 info / ink |
| `icon.info.ink@1x.png` | `assets/icons/info_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 info / ink |
| `icon.info.ink@2x.png` | `assets/icons/info_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 info / ink |
| `icon.info.ink@3x.png` | `assets/icons/info_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 info / ink |
| `icon.info.paper.svg` | `assets/icons/info_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 info / paper |
| `icon.info.paper@1x.png` | `assets/icons/info_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 info / paper |
| `icon.info.paper@2x.png` | `assets/icons/info_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 info / paper |
| `icon.info.paper@3x.png` | `assets/icons/info_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 info / paper |
| `icon.info.muted.svg` | `assets/icons/info_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 info / muted |
| `icon.info.muted@1x.png` | `assets/icons/info_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 info / muted |
| `icon.info.muted@2x.png` | `assets/icons/info_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 info / muted |
| `icon.info.muted@3x.png` | `assets/icons/info_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 info / muted |
| `icon.warning.ink.svg` | `assets/icons/warning_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 warning / ink |
| `icon.warning.ink@1x.png` | `assets/icons/warning_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 warning / ink |
| `icon.warning.ink@2x.png` | `assets/icons/warning_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 warning / ink |
| `icon.warning.ink@3x.png` | `assets/icons/warning_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 warning / ink |
| `icon.warning.paper.svg` | `assets/icons/warning_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 warning / paper |
| `icon.warning.paper@1x.png` | `assets/icons/warning_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 warning / paper |
| `icon.warning.paper@2x.png` | `assets/icons/warning_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 warning / paper |
| `icon.warning.paper@3x.png` | `assets/icons/warning_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 warning / paper |
| `icon.warning.muted.svg` | `assets/icons/warning_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 warning / muted |
| `icon.warning.muted@1x.png` | `assets/icons/warning_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 warning / muted |
| `icon.warning.muted@2x.png` | `assets/icons/warning_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 warning / muted |
| `icon.warning.muted@3x.png` | `assets/icons/warning_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 warning / muted |
| `icon.year.ink.svg` | `assets/icons/year_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 year / ink |
| `icon.year.ink@1x.png` | `assets/icons/year_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 year / ink |
| `icon.year.ink@2x.png` | `assets/icons/year_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 year / ink |
| `icon.year.ink@3x.png` | `assets/icons/year_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 year / ink |
| `icon.year.paper.svg` | `assets/icons/year_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 year / paper |
| `icon.year.paper@1x.png` | `assets/icons/year_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 year / paper |
| `icon.year.paper@2x.png` | `assets/icons/year_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 year / paper |
| `icon.year.paper@3x.png` | `assets/icons/year_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 year / paper |
| `icon.year.muted.svg` | `assets/icons/year_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 year / muted |
| `icon.year.muted@1x.png` | `assets/icons/year_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 year / muted |
| `icon.year.muted@2x.png` | `assets/icons/year_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 year / muted |
| `icon.year.muted@3x.png` | `assets/icons/year_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 year / muted |
| `icon.save.ink.svg` | `assets/icons/save_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 save / ink |
| `icon.save.ink@1x.png` | `assets/icons/save_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 save / ink |
| `icon.save.ink@2x.png` | `assets/icons/save_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 save / ink |
| `icon.save.ink@3x.png` | `assets/icons/save_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 save / ink |
| `icon.save.paper.svg` | `assets/icons/save_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 save / paper |
| `icon.save.paper@1x.png` | `assets/icons/save_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 save / paper |
| `icon.save.paper@2x.png` | `assets/icons/save_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 save / paper |
| `icon.save.paper@3x.png` | `assets/icons/save_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 save / paper |
| `icon.save.muted.svg` | `assets/icons/save_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 save / muted |
| `icon.save.muted@1x.png` | `assets/icons/save_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 save / muted |
| `icon.save.muted@2x.png` | `assets/icons/save_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 save / muted |
| `icon.save.muted@3x.png` | `assets/icons/save_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 save / muted |
| `icon.search.ink.svg` | `assets/icons/search_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 search / ink |
| `icon.search.ink@1x.png` | `assets/icons/search_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 search / ink |
| `icon.search.ink@2x.png` | `assets/icons/search_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 search / ink |
| `icon.search.ink@3x.png` | `assets/icons/search_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 search / ink |
| `icon.search.paper.svg` | `assets/icons/search_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 search / paper |
| `icon.search.paper@1x.png` | `assets/icons/search_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 search / paper |
| `icon.search.paper@2x.png` | `assets/icons/search_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 search / paper |
| `icon.search.paper@3x.png` | `assets/icons/search_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 search / paper |
| `icon.search.muted.svg` | `assets/icons/search_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 search / muted |
| `icon.search.muted@1x.png` | `assets/icons/search_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 search / muted |
| `icon.search.muted@2x.png` | `assets/icons/search_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 search / muted |
| `icon.search.muted@3x.png` | `assets/icons/search_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 search / muted |
| `icon.leader.ink.svg` | `assets/icons/leader_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 leader / ink |
| `icon.leader.ink@1x.png` | `assets/icons/leader_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 leader / ink |
| `icon.leader.ink@2x.png` | `assets/icons/leader_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 leader / ink |
| `icon.leader.ink@3x.png` | `assets/icons/leader_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 leader / ink |
| `icon.leader.paper.svg` | `assets/icons/leader_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 leader / paper |
| `icon.leader.paper@1x.png` | `assets/icons/leader_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 leader / paper |
| `icon.leader.paper@2x.png` | `assets/icons/leader_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 leader / paper |
| `icon.leader.paper@3x.png` | `assets/icons/leader_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 leader / paper |
| `icon.leader.muted.svg` | `assets/icons/leader_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 leader / muted |
| `icon.leader.muted@1x.png` | `assets/icons/leader_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 leader / muted |
| `icon.leader.muted@2x.png` | `assets/icons/leader_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 leader / muted |
| `icon.leader.muted@3x.png` | `assets/icons/leader_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 leader / muted |
| `icon.sick.ink.svg` | `assets/icons/sick_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 sick / ink |
| `icon.sick.ink@1x.png` | `assets/icons/sick_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 sick / ink |
| `icon.sick.ink@2x.png` | `assets/icons/sick_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 sick / ink |
| `icon.sick.ink@3x.png` | `assets/icons/sick_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 sick / ink |
| `icon.sick.paper.svg` | `assets/icons/sick_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 sick / paper |
| `icon.sick.paper@1x.png` | `assets/icons/sick_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 sick / paper |
| `icon.sick.paper@2x.png` | `assets/icons/sick_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 sick / paper |
| `icon.sick.paper@3x.png` | `assets/icons/sick_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 sick / paper |
| `icon.sick.muted.svg` | `assets/icons/sick_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 sick / muted |
| `icon.sick.muted@1x.png` | `assets/icons/sick_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 sick / muted |
| `icon.sick.muted@2x.png` | `assets/icons/sick_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 sick / muted |
| `icon.sick.muted@3x.png` | `assets/icons/sick_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 sick / muted |
| `icon.deceased.ink.svg` | `assets/icons/deceased_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 deceased / ink |
| `icon.deceased.ink@1x.png` | `assets/icons/deceased_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 deceased / ink |
| `icon.deceased.ink@2x.png` | `assets/icons/deceased_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 deceased / ink |
| `icon.deceased.ink@3x.png` | `assets/icons/deceased_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 deceased / ink |
| `icon.deceased.paper.svg` | `assets/icons/deceased_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 deceased / paper |
| `icon.deceased.paper@1x.png` | `assets/icons/deceased_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 deceased / paper |
| `icon.deceased.paper@2x.png` | `assets/icons/deceased_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 deceased / paper |
| `icon.deceased.paper@3x.png` | `assets/icons/deceased_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 deceased / paper |
| `icon.deceased.muted.svg` | `assets/icons/deceased_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 deceased / muted |
| `icon.deceased.muted@1x.png` | `assets/icons/deceased_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 deceased / muted |
| `icon.deceased.muted@2x.png` | `assets/icons/deceased_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 deceased / muted |
| `icon.deceased.muted@3x.png` | `assets/icons/deceased_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 deceased / muted |
| `icon.house.ink.svg` | `assets/icons/house_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 house / ink |
| `icon.house.ink@1x.png` | `assets/icons/house_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 house / ink |
| `icon.house.ink@2x.png` | `assets/icons/house_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 house / ink |
| `icon.house.ink@3x.png` | `assets/icons/house_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 house / ink |
| `icon.house.paper.svg` | `assets/icons/house_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 house / paper |
| `icon.house.paper@1x.png` | `assets/icons/house_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 house / paper |
| `icon.house.paper@2x.png` | `assets/icons/house_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 house / paper |
| `icon.house.paper@3x.png` | `assets/icons/house_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 house / paper |
| `icon.house.muted.svg` | `assets/icons/house_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 house / muted |
| `icon.house.muted@1x.png` | `assets/icons/house_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 house / muted |
| `icon.house.muted@2x.png` | `assets/icons/house_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 house / muted |
| `icon.house.muted@3x.png` | `assets/icons/house_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 house / muted |
| `icon.restore.ink.svg` | `assets/icons/restore_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 restore / ink |
| `icon.restore.ink@1x.png` | `assets/icons/restore_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 restore / ink |
| `icon.restore.ink@2x.png` | `assets/icons/restore_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 restore / ink |
| `icon.restore.ink@3x.png` | `assets/icons/restore_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 restore / ink |
| `icon.restore.paper.svg` | `assets/icons/restore_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 restore / paper |
| `icon.restore.paper@1x.png` | `assets/icons/restore_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 restore / paper |
| `icon.restore.paper@2x.png` | `assets/icons/restore_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 restore / paper |
| `icon.restore.paper@3x.png` | `assets/icons/restore_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 restore / paper |
| `icon.restore.muted.svg` | `assets/icons/restore_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 restore / muted |
| `icon.restore.muted@1x.png` | `assets/icons/restore_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 restore / muted |
| `icon.restore.muted@2x.png` | `assets/icons/restore_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 restore / muted |
| `icon.restore.muted@3x.png` | `assets/icons/restore_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 restore / muted |
| `icon.more.ink.svg` | `assets/icons/more_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 more / ink |
| `icon.more.ink@1x.png` | `assets/icons/more_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 more / ink |
| `icon.more.ink@2x.png` | `assets/icons/more_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 more / ink |
| `icon.more.ink@3x.png` | `assets/icons/more_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 more / ink |
| `icon.more.paper.svg` | `assets/icons/more_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 more / paper |
| `icon.more.paper@1x.png` | `assets/icons/more_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 more / paper |
| `icon.more.paper@2x.png` | `assets/icons/more_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 more / paper |
| `icon.more.paper@3x.png` | `assets/icons/more_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 more / paper |
| `icon.more.muted.svg` | `assets/icons/more_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 more / muted |
| `icon.more.muted@1x.png` | `assets/icons/more_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 more / muted |
| `icon.more.muted@2x.png` | `assets/icons/more_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 more / muted |
| `icon.more.muted@3x.png` | `assets/icons/more_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 more / muted |
| `icon.loading.ink.svg` | `assets/icons/loading_ink.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 loading / ink |
| `icon.loading.ink@1x.png` | `assets/icons/loading_ink@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 loading / ink |
| `icon.loading.ink@2x.png` | `assets/icons/loading_ink@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 loading / ink |
| `icon.loading.ink@3x.png` | `assets/icons/loading_ink@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 loading / ink |
| `icon.loading.paper.svg` | `assets/icons/loading_paper.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 loading / paper |
| `icon.loading.paper@1x.png` | `assets/icons/loading_paper@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 loading / paper |
| `icon.loading.paper@2x.png` | `assets/icons/loading_paper@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 loading / paper |
| `icon.loading.paper@3x.png` | `assets/icons/loading_paper@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 loading / paper |
| `icon.loading.muted.svg` | `assets/icons/loading_muted.svg` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 loading / muted |
| `icon.loading.muted@1x.png` | `assets/icons/loading_muted@1x.png` | 24×24 | 有 | `[1, 1, 22, 22]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 loading / muted |
| `icon.loading.muted@2x.png` | `assets/icons/loading_muted@2x.png` | 48×48 | 有 | `[2, 2, 44, 44]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 loading / muted |
| `icon.loading.muted@3x.png` | `assets/icons/loading_muted@3x.png` | 72×72 | 有 | `[3, 3, 66, 66]` | 24逻辑画布，实际热区另设44；浅/深/弱化版本。 loading / muted |
| `button.primary.default.svg` | `assets/ui/buttons/primary_default.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 default |
| `button.primary.default@2x.png` | `assets/ui/buttons/primary_default@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 default |
| `button.primary.pressed.svg` | `assets/ui/buttons/primary_pressed.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 pressed |
| `button.primary.pressed@2x.png` | `assets/ui/buttons/primary_pressed@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 pressed |
| `button.primary.selected.svg` | `assets/ui/buttons/primary_selected.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 selected |
| `button.primary.selected@2x.png` | `assets/ui/buttons/primary_selected@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 selected |
| `button.primary.disabled.svg` | `assets/ui/buttons/primary_disabled.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 disabled |
| `button.primary.disabled@2x.png` | `assets/ui/buttons/primary_disabled@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 disabled |
| `button.primary.focus.svg` | `assets/ui/buttons/primary_focus.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 focus |
| `button.primary.focus@2x.png` | `assets/ui/buttons/primary_focus@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 focus |
| `button.primary.confirm.svg` | `assets/ui/buttons/primary_confirm.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 confirm |
| `button.primary.confirm@2x.png` | `assets/ui/buttons/primary_confirm@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 confirm |
| `button.primary.busy.svg` | `assets/ui/buttons/primary_busy.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 busy |
| `button.primary.busy@2x.png` | `assets/ui/buttons/primary_busy@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 busy |
| `button.secondary.default.svg` | `assets/ui/buttons/secondary_default.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 default |
| `button.secondary.default@2x.png` | `assets/ui/buttons/secondary_default@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 default |
| `button.secondary.pressed.svg` | `assets/ui/buttons/secondary_pressed.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 pressed |
| `button.secondary.pressed@2x.png` | `assets/ui/buttons/secondary_pressed@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 pressed |
| `button.secondary.selected.svg` | `assets/ui/buttons/secondary_selected.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 selected |
| `button.secondary.selected@2x.png` | `assets/ui/buttons/secondary_selected@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 selected |
| `button.secondary.disabled.svg` | `assets/ui/buttons/secondary_disabled.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 disabled |
| `button.secondary.disabled@2x.png` | `assets/ui/buttons/secondary_disabled@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 disabled |
| `button.secondary.focus.svg` | `assets/ui/buttons/secondary_focus.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 focus |
| `button.secondary.focus@2x.png` | `assets/ui/buttons/secondary_focus@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 focus |
| `button.secondary.confirm.svg` | `assets/ui/buttons/secondary_confirm.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 confirm |
| `button.secondary.confirm@2x.png` | `assets/ui/buttons/secondary_confirm@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 confirm |
| `button.secondary.busy.svg` | `assets/ui/buttons/secondary_busy.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 busy |
| `button.secondary.busy@2x.png` | `assets/ui/buttons/secondary_busy@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 busy |
| `button.danger.default.svg` | `assets/ui/buttons/danger_default.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 default |
| `button.danger.default@2x.png` | `assets/ui/buttons/danger_default@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 default |
| `button.danger.pressed.svg` | `assets/ui/buttons/danger_pressed.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 pressed |
| `button.danger.pressed@2x.png` | `assets/ui/buttons/danger_pressed@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 pressed |
| `button.danger.selected.svg` | `assets/ui/buttons/danger_selected.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 selected |
| `button.danger.selected@2x.png` | `assets/ui/buttons/danger_selected@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 selected |
| `button.danger.disabled.svg` | `assets/ui/buttons/danger_disabled.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 disabled |
| `button.danger.disabled@2x.png` | `assets/ui/buttons/danger_disabled@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 disabled |
| `button.danger.focus.svg` | `assets/ui/buttons/danger_focus.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 focus |
| `button.danger.focus@2x.png` | `assets/ui/buttons/danger_focus@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 focus |
| `button.danger.confirm.svg` | `assets/ui/buttons/danger_confirm.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 confirm |
| `button.danger.confirm@2x.png` | `assets/ui/buttons/danger_confirm@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 confirm |
| `button.danger.busy.svg` | `assets/ui/buttons/danger_busy.svg` | 240×96 | 有 | `[38, 18, 164, 60]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 busy |
| `button.danger.busy@2x.png` | `assets/ui/buttons/danger_busy@2x.png` | 480×192 | 有 | `[76, 36, 328, 120]` | 无文字按钮皮肤；图标单独叠加，使用九宫格。 busy |
| `panel.default.svg` | `assets/ui/panels/default.svg` | 360×200 | 有 | `[20, 20, 320, 160]` | 纸面内容容器；文字及交互独立。 default |
| `panel.default@2x.png` | `assets/ui/panels/default@2x.png` | 720×400 | 有 | `[40, 40, 640, 320]` | 纸面内容容器；文字及交互独立。 default |
| `panel.selected.svg` | `assets/ui/panels/selected.svg` | 360×200 | 有 | `[20, 20, 320, 160]` | 纸面内容容器；文字及交互独立。 selected |
| `panel.selected@2x.png` | `assets/ui/panels/selected@2x.png` | 720×400 | 有 | `[40, 40, 640, 320]` | 纸面内容容器；文字及交互独立。 selected |
| `panel.disabled.svg` | `assets/ui/panels/disabled.svg` | 360×200 | 有 | `[20, 20, 320, 160]` | 纸面内容容器；文字及交互独立。 disabled |
| `panel.disabled@2x.png` | `assets/ui/panels/disabled@2x.png` | 720×400 | 有 | `[40, 40, 640, 320]` | 纸面内容容器；文字及交互独立。 disabled |
| `panel.danger.svg` | `assets/ui/panels/danger.svg` | 360×200 | 有 | `[20, 20, 320, 160]` | 纸面内容容器；文字及交互独立。 danger |
| `panel.danger@2x.png` | `assets/ui/panels/danger@2x.png` | 720×400 | 有 | `[40, 40, 640, 320]` | 纸面内容容器；文字及交互独立。 danger |
| `panel.confirmation.svg` | `assets/ui/panels/confirmation.svg` | 360×200 | 有 | `[20, 20, 320, 160]` | 纸面内容容器；文字及交互独立。 confirmation |
| `panel.confirmation@2x.png` | `assets/ui/panels/confirmation@2x.png` | 720×400 | 有 | `[40, 40, 640, 320]` | 纸面内容容器；文字及交互独立。 confirmation |
| `portrait-overlay.selected.svg` | `assets/ui/portrait_selected.svg` | 256×256 | 有 | `[0, 0, 256, 256]` | 透明状态层；可与病弱/已故头像共同叠加，不换脸。 selected |
| `portrait-overlay.selected.png` | `assets/ui/portrait_selected.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 透明状态层；可与病弱/已故头像共同叠加，不换脸。 selected |
| `portrait-overlay.leader.svg` | `assets/ui/portrait_leader.svg` | 256×256 | 有 | `[0, 0, 256, 256]` | 透明状态层；可与病弱/已故头像共同叠加，不换脸。 leader |
| `portrait-overlay.leader.png` | `assets/ui/portrait_leader.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 透明状态层；可与病弱/已故头像共同叠加，不换脸。 leader |
| `portrait-overlay.sick.svg` | `assets/ui/portrait_sick.svg` | 256×256 | 有 | `[0, 0, 256, 256]` | 透明状态层；可与病弱/已故头像共同叠加，不换脸。 sick |
| `portrait-overlay.sick.png` | `assets/ui/portrait_sick.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 透明状态层；可与病弱/已故头像共同叠加，不换脸。 sick |
| `portrait-overlay.deceased.svg` | `assets/ui/portrait_deceased.svg` | 256×256 | 有 | `[0, 0, 256, 256]` | 透明状态层；可与病弱/已故头像共同叠加，不换脸。 deceased |
| `portrait-overlay.deceased.png` | `assets/ui/portrait_deceased.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 透明状态层；可与病弱/已故头像共同叠加，不换脸。 deceased |
| `portrait-overlay.focus.svg` | `assets/ui/portrait_focus.svg` | 256×256 | 有 | `[0, 0, 256, 256]` | 透明状态层；可与病弱/已故头像共同叠加，不换脸。 focus |
| `portrait-overlay.focus.png` | `assets/ui/portrait_focus.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 透明状态层；可与病弱/已故头像共同叠加，不换脸。 focus |
| `control.checkbox.default.svg` | `assets/ui/controls/checkbox_default.svg` | 32×32 | 有 | `[0, 0, 32, 32]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 default |
| `control.checkbox.default@2x.png` | `assets/ui/controls/checkbox_default@2x.png` | 64×64 | 有 | `[0, 0, 64, 64]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 default |
| `control.checkbox.selected.svg` | `assets/ui/controls/checkbox_selected.svg` | 32×32 | 有 | `[0, 0, 32, 32]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 selected |
| `control.checkbox.selected@2x.png` | `assets/ui/controls/checkbox_selected@2x.png` | 64×64 | 有 | `[0, 0, 64, 64]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 selected |
| `control.checkbox.disabled.svg` | `assets/ui/controls/checkbox_disabled.svg` | 32×32 | 有 | `[0, 0, 32, 32]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 disabled |
| `control.checkbox.disabled@2x.png` | `assets/ui/controls/checkbox_disabled@2x.png` | 64×64 | 有 | `[0, 0, 64, 64]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 disabled |
| `control.checkbox.invalid.svg` | `assets/ui/controls/checkbox_invalid.svg` | 32×32 | 有 | `[0, 0, 32, 32]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 invalid |
| `control.checkbox.invalid@2x.png` | `assets/ui/controls/checkbox_invalid@2x.png` | 64×64 | 有 | `[0, 0, 64, 64]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 invalid |
| `control.radio.default.svg` | `assets/ui/controls/radio_default.svg` | 32×32 | 有 | `[0, 0, 32, 32]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 default |
| `control.radio.default@2x.png` | `assets/ui/controls/radio_default@2x.png` | 64×64 | 有 | `[0, 0, 64, 64]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 default |
| `control.radio.selected.svg` | `assets/ui/controls/radio_selected.svg` | 32×32 | 有 | `[0, 0, 32, 32]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 selected |
| `control.radio.selected@2x.png` | `assets/ui/controls/radio_selected@2x.png` | 64×64 | 有 | `[0, 0, 64, 64]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 selected |
| `control.radio.disabled.svg` | `assets/ui/controls/radio_disabled.svg` | 32×32 | 有 | `[0, 0, 32, 32]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 disabled |
| `control.radio.disabled@2x.png` | `assets/ui/controls/radio_disabled@2x.png` | 64×64 | 有 | `[0, 0, 64, 64]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 disabled |
| `control.radio.invalid.svg` | `assets/ui/controls/radio_invalid.svg` | 32×32 | 有 | `[0, 0, 32, 32]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 invalid |
| `control.radio.invalid@2x.png` | `assets/ui/controls/radio_invalid@2x.png` | 64×64 | 有 | `[0, 0, 64, 64]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 invalid |
| `control.toggle.off.svg` | `assets/ui/controls/toggle_off.svg` | 52×32 | 有 | `[0, 0, 52, 32]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 off |
| `control.toggle.off@2x.png` | `assets/ui/controls/toggle_off@2x.png` | 104×64 | 有 | `[0, 0, 104, 64]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 off |
| `control.toggle.on.svg` | `assets/ui/controls/toggle_on.svg` | 52×32 | 有 | `[0, 0, 52, 32]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 on |
| `control.toggle.on@2x.png` | `assets/ui/controls/toggle_on@2x.png` | 104×64 | 有 | `[0, 0, 104, 64]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 on |
| `control.toggle.disabled.svg` | `assets/ui/controls/toggle_disabled.svg` | 52×32 | 有 | `[0, 0, 52, 32]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 disabled |
| `control.toggle.disabled@2x.png` | `assets/ui/controls/toggle_disabled@2x.png` | 104×64 | 有 | `[0, 0, 104, 64]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 disabled |
| `control.input.default.svg` | `assets/ui/controls/input_default.svg` | 320×48 | 有 | `[0, 0, 320, 48]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 default |
| `control.input.default@2x.png` | `assets/ui/controls/input_default@2x.png` | 640×96 | 有 | `[0, 0, 640, 96]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 default |
| `control.input.selected.svg` | `assets/ui/controls/input_selected.svg` | 320×48 | 有 | `[0, 0, 320, 48]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 selected |
| `control.input.selected@2x.png` | `assets/ui/controls/input_selected@2x.png` | 640×96 | 有 | `[0, 0, 640, 96]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 selected |
| `control.input.disabled.svg` | `assets/ui/controls/input_disabled.svg` | 320×48 | 有 | `[0, 0, 320, 48]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 disabled |
| `control.input.disabled@2x.png` | `assets/ui/controls/input_disabled@2x.png` | 640×96 | 有 | `[0, 0, 640, 96]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 disabled |
| `control.input.invalid.svg` | `assets/ui/controls/input_invalid.svg` | 320×48 | 有 | `[0, 0, 320, 48]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 invalid |
| `control.input.invalid@2x.png` | `assets/ui/controls/input_invalid@2x.png` | 640×96 | 有 | `[0, 0, 640, 96]` | 表单控件皮肤；选中/禁用必须由实际控件实现。 invalid |
| `decor.mountains.svg` | `assets/decor/mountains.svg` | 1200×400 | 有 | `[0, 0, 1200, 400]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.mountains.png` | `assets/decor/mountains.png` | 1200×400 | 有 | `[0, 0, 1200, 400]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.tree.svg` | `assets/decor/tree.svg` | 512×768 | 有 | `[0, 0, 512, 768]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.tree.png` | `assets/decor/tree.png` | 512×768 | 有 | `[0, 0, 512, 768]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.bamboo.svg` | `assets/decor/bamboo.svg` | 512×768 | 有 | `[0, 0, 512, 768]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.bamboo.png` | `assets/decor/bamboo.png` | 512×768 | 有 | `[0, 0, 512, 768]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.clouds.svg` | `assets/decor/clouds.svg` | 800×240 | 有 | `[0, 0, 800, 240]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.clouds.png` | `assets/decor/clouds.png` | 800×240 | 有 | `[0, 0, 800, 240]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.paper_edge.svg` | `assets/decor/paper_edge.svg` | 900×140 | 有 | `[0, 0, 900, 140]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.paper_edge.png` | `assets/decor/paper_edge.png` | 900×140 | 有 | `[0, 0, 900, 140]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.divider.svg` | `assets/decor/divider.svg` | 900×60 | 有 | `[0, 0, 900, 60]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.divider.png` | `assets/decor/divider.png` | 900×60 | 有 | `[0, 0, 900, 60]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.corner.svg` | `assets/decor/corner.svg` | 96×96 | 有 | `[0, 0, 96, 96]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.corner.png` | `assets/decor/corner.png` | 96×96 | 有 | `[0, 0, 96, 96]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.seal_square.svg` | `assets/decor/seal_square.svg` | 128×128 | 有 | `[0, 0, 128, 128]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.seal_square.png` | `assets/decor/seal_square.png` | 128×128 | 有 | `[0, 0, 128, 128]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.seal_round.svg` | `assets/decor/seal_round.svg` | 128×128 | 有 | `[0, 0, 128, 128]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.seal_round.png` | `assets/decor/seal_round.png` | 128×128 | 有 | `[0, 0, 128, 128]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.portrait_backplate.svg` | `assets/decor/portrait_backplate.svg` | 256×256 | 有 | `[0, 0, 256, 256]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.portrait_backplate.png` | `assets/decor/portrait_backplate.png` | 256×256 | 有 | `[0, 0, 256, 256]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.branch_line.svg` | `assets/decor/branch_line.svg` | 240×100 | 有 | `[0, 0, 240, 100]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.branch_line.png` | `assets/decor/branch_line.png` | 240×100 | 有 | `[0, 0, 240, 100]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.spouse_line.svg` | `assets/decor/spouse_line.svg` | 240×40 | 有 | `[0, 0, 240, 40]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `decor.spouse_line.png` | `assets/decor/spouse_line.png` | 240×40 | 有 | `[0, 0, 240, 40]` | 透明装饰层；低透明度使用，不拦截输入。  |
| `paper.subtle` | `assets/textures/paper_subtle_512.png` | 512×512 | 无 | `[0, 0, 512, 512]` | 周期函数生成，可平铺纸纹；subtle作正文底，aged仅装饰。  |
| `paper.medium` | `assets/textures/paper_medium_512.png` | 512×512 | 无 | `[0, 0, 512, 512]` | 周期函数生成，可平铺纸纹；subtle作正文底，aged仅装饰。  |
| `paper.aged` | `assets/textures/paper_aged_512.png` | 512×512 | 无 | `[0, 0, 512, 512]` | 周期函数生成，可平铺纸纹；subtle作正文底，aged仅装饰。  |
| `paper.alpha` | `assets/textures/paper_fiber_alpha_512.png` | 512×512 | 有 | `[0, 0, 512, 512]` | 透明纸纤维；建议整体opacity0.35，不叠加厚重纹理。  |

## 检查边界

只检查实际路径、PNG尺寸/alpha和映射，未跑全量游戏测试、UrhoX或物理手机。所有字节数与SHA256见data/asset_registry.json。
