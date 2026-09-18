# 事件类型与插画对应表

对照V7与历史审查提交2540b6e，不是对当前main重新评审。同一relic_resolution必须再按信物ID细分。图像不包含玩家姓名、费用、正文或按钮，不决定事件效果。

| 事件类型 | 二级条件 | 文件 | 画面 |
|---|---|---|---|
| `relic_resolution` | `ruler` | `assets/events/ruler.png` | 木尺旧匠号 |
| `relic_resolution` | `book` | `assets/events/book.png` | 族谱缺页 |
| `relic_resolution` | `letter` | `assets/events/letter.png` | 家书旧约 |
| `relic_resolution` | `plan` | `assets/events/repair.png` | 修缮营造 |
| `relic_resolution` | `newbook` | `assets/events/reunion.png` | 旁支归家 |
| `relic_resolution` | `jade` | `assets/events/jade.png` | 故人玉佩 |
| `relic_resolution` | `notes` | `assets/events/medical.png` | 医案与问诊 |
| `medical_find` | `—` | `assets/events/medical.png` | 医案与问诊 |
| `notes_choice` | `—` | `assets/events/medical.png` | 医案与问诊 |
| `plan_work` | `—` | `assets/events/repair.png` | 修缮营造 |
| `community_request` | `—` | `assets/events/neighbors.png` | 邻里互助 |
| `school` | `—` | `assets/events/school.png` | 求学应试 |
| `roof` | `—` | `assets/events/roof.png` | 风雨屋顶 |
| `jade_search` | `—` | `assets/events/jade.png` | 故人玉佩 |
| `leader` | `—` | `assets/events/leadership.png` | 族长交接 |
| `migration` | `—` | `assets/events/migration.png` | 迁居新址 |
| `invite_branch` | `—` | `assets/events/reunion.png` | 旁支归家 |
| `growth` | `doctor` | `assets/events/medical.png` | 医案与问诊 |
| `growth` | `craft` | `assets/events/repair.png` | 修缮营造 |
| `growth` | `—` | `assets/events/school.png` | 求学应试 |

所有事件：1200×560 PNG与可编辑SVG；建议15:7横图，图下另放不透明纸面正文。默认安全区[x=110,y=45,w=980,h=465]。不透明背景，不用于抠图贴纸。参与人头像另取真实成员artId。

migration/invite_branch用于行动与家史展示，不新建玩法。未知类型返回无插画纸面，不随机用不相关事件图片。完整机器表：data/event_asset_map.json。
