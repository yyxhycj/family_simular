# Chrome 真实 UrhoX 录屏索引

全部是桌面 Chrome 真实引擎，不是真机。360/390/430 指 QA 入口设置的逻辑 frame，DPR=2。视频保留本地原件，未剪辑，失败过程也保留。

| 视频 | 时长 | 证据 |
|---|---:|---|
| [01-formal-draft-cancel.mp4](01-formal-draft-cancel.mp4) | 41.6秒 | 正式旧局→整户生成、姓名骰子、账本、换一家、取消保护 |
| [02-360-overflow-and-start.mp4](02-360-overflow-and-start.mp4) | 67.5秒 | 历史失败：360首屏净变化溢出；随后真实开局写入隔离存档 |
| [03-widths-360-390-430.mp4](03-widths-360-390-430.mp4) | 71.8秒 | 修复后360/390与430六人布局（360仍有冗余信物换行） |
| [04-name-and-single-edit.mp4](04-name-and-single-edit.mp4) | 77.4秒 | 手改完整姓名、家族复姓、外姓保留、地区下拉98→100 |
| [05-budget-cancel-and-settlement.mp4](05-budget-cancel-and-settlement.mp4) | 57.1秒 | 作坊超分取消、102点开始禁用、读回与首年50/0→65/8 |
| [06-restart-load.mp4](06-restart-load.mp4) | 1.9秒 | 重新加载引擎后读回yearIndex1、65两8石 |
| [07-controls-and-360-final.mp4](07-controls-and-360-final.mp4) | 65.5秒 | 最终360首屏、钱粮田加减保存、年龄加1、新增取消 |
| [08-page-random-undo.mp4](08-page-random-undo.mp4) | 12.1秒 | 本页随机94→82，撤销回94，钱粮田保留60/4/2 |
| [09-formal-entry-old-save.mp4](09-formal-entry-old-save.mp4) | 28.9秒 | 最终正式入口、原顾氏第6年九条历史、新草案取消回原局 |

代码版本：01为b41a095；02为7a11470；03—06为741ae36；07—08为5660579；09为0134a28正式main.lua，Maker元数据同步后HEAD为1de8c23。

对应JSON只保留时间与游戏日志；verification.json为固定03/04日志的11项观察核验，包含430夹具不同的预期说明。源码与视频哈希、正式存档回读、未验证边界见 ../delivery.json。

未验收：真实手机触控、中文输入法/软键盘、安全区。桌面自动化全选快捷键未替换输入框内容，本轮完整改名通过退格清空后输入验证。
