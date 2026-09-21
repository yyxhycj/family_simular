# 《家业》六项背景机会

本文对应 `origin-opportunities-1.0`，描述六项开局来历机会的静态费用、条件、结果和 UI 接口。每局每项机会最多正式开启 1 次；确认前关闭、返回或留待以后不会消费资格，也不会扣款。

## 六项静态描述

### 河埠换种 `origin.seed_exchange`

- 条件：办理人须在世、成年、当前主业为耕作；家族田地至少 1 亩；公库至少 4 石粮；额外事务名额空闲。
- 费用：确认试种立即支付 4 石粮；完成 1 个有效耕作年后不再收费。完成后选择留下种或分给邻人另付 2 石粮，留作家用不再付费。
- 结果：试种完成自动到账 8 石粮一次。留下种后，接下来 3 个有效耕作年每年全家额外收粮 2 石，整条路线净变化 +8 石；分给邻人后声望 +4，整条路线净变化 +2 石；留作家用整条路线净变化 +4 石。
- 时间：暂停、缺少田地或缺少有效耕作者时不发放后续增产，也不消耗次数；后续增产无自然到期。

### 旧坊修缮 `origin.workshop_repair`

- 条件：办理人须在世、成年、手艺至少 35；公库至少 8 两；额外事务名额空闲。自有作坊、主业为手艺谋生、豪宅与声望均不构成前置条件。
- 费用：确认修缮立即支付 8 两工料费；完成 1 个有效工作年后不再收费。可选挂载当前未出售的老木尺或营造图，挂载不另收费，资格由报价校验。
- 完工：最后实际办理人手艺 +3，工程事实写入家史，再选择一条报酬分支。
- 领足工钱：到账 22 两，其中工料报销 8 两、净劳动报酬 14 两；全流程现金净变化 +14 两。
- 留下置办便利：到账 14 两，其中工料报销 8 两、现金报酬 6 两；获得一次本局购买作坊最多减免 16 两；当下现金净变化 +6 两，优惠使用前不计入公库余额。

### 旧账重开 `origin.old_accounts`

- 对账条件：任一在世成年人；公库至少 2 两。
- 对账费用：确认立即支付 2 两文书/核账成本；对账即时完成，不占多年事务名额，固定核实旧欠 12 两。核实金额进入应收记录，未结清前不进入公库。
- 折价结清：即时到账 12 两旧账回收；自对账起全流程净变化 +10 两。
- 续做一单条件：对账完成后指定在世成年人，经营至少 25；额外事务名额空闲；公库另有 12 两交易投入。
- 续做一单费用与时间：选择时另付 12 两商货投入，完成 1 个有效工作年。
- 续做一单结果：到账 30 两，拆分为本金返还 12 两、旧账回收 12 两、新单利润 6 两；办理人经营 +3；自对账起全流程净变化 +16 两。
- 两条后续路径互斥。该契约不增加随机失败；明确放弃已接受续单时，已投入商货不退，也不改回即时结清。

### 旧卷借阅 `origin.scroll_loan`

- 条件：读者须在世、年满 5 岁、当前可实际读书并有合法读书安排；公库至少 8 两。
- 费用：确认借入立即支付 8 两，其中整理服务费 2 两为真实支出，押金 6 两转为家族押金资产；借期为借入后的 3 个自然年度。
- 学习帮助：借期内最多 2 个有效读书年，每年额外学识 +3，最多 +6。普通学费、主业培养和有效读书事实仍需由年度系统确认。
- 换读者：可免费改为另一位合格族人，不重置已得收益、剩余次数、借入年或归还日；读者离世后可换人或托还。
- 按时归还：退押金 6 两；整理费不退；只读 1 个有效年度时，全程正常归还净支出 2 两。
- 逾期：每个完整逾期年度从押金扣 2 两，累计最多扣 6 两。第 3 个完整逾期年度末自动收回书卷，押金退回 0 两；逾期期间不再产生借卷学识帮助。

### 旧营护送 `origin.escort`

- 条件：办理人须在世、成年、武艺至少 35、年初体魄至少 50；额外事务名额空闲。
- 稳路：确认立即支付 6 两，完成 1 个有效工作年；到账 18 两，拆分为盘缠报销 6 两和报酬 12 两；武艺 +2；净变化 +12 两。
- 急件：确认立即支付 8 两，完成同一个有效工作年。成功到账 32 两，拆分为盘缠报销 8 两和报酬 24 两；武艺 +3；净变化 +24 两。
- 急件失败：退回未用盘缠 6 两；体魄 -8、武艺 +1；原支付 8 两的净变化为 -2 两。退回盘缠不计为利润。
- 急件成功率：使用年初办理人武艺快照，`clamp(70% + floor((武艺 - 35) / 5) × 2% - 动荡时世10%, 50%, 90%)`。接受急件时只生成并保存一次 `riskDraw`；读档、暂停、查看报价和换办理人均不重新抽签。
- 路线确认后不可改路；暂停不增加路费，工作前失格时转为等待合格办理人。

### 旧客重访 `origin.old_guest`

- 接待条件：主持人须在世、成年；公库至少 8 两；额外事务名额空闲。主持人无需族长身份、豪宅或声望门槛。
- 接待费用与时间：确认立即支付 8 两；完成 1 个有效工作年后不再收费。
- 接待结果：声望 +8，并生成一份引荐资格。资格完成接待后仍可保留，指定对象前无自然期限。
- 求学引荐：指定在世、年满 5 岁的成员；指定后 6 个自然年度内最多 3 个有效读书年，每次额外学识 +2，最多 +6；普通学费照付。
- 谋生引荐：指定在世成年成员；指定后 4 个自然年度内最多 2 个合格工作年，每次额外到账 6 两，最多到账 12 两；扣接待费后全路径现金净变化 +4 两。合格主业为 `craft / trade / teach / doctor / guard`。
- 指定后不可换人；目标离世后剩余次数失效；无合格主业时不消费次数，窗口仍继续计时。

## 共用状态与记录

机会记录使用以下状态：

`available`、`active`、`paused`、`paused_actor`、`ready`、`settled`、`abandoned`、`settled_failure`、`returned`、`reclaimed`、`archived`。

`ready`、`paused`、`available`只提供提醒，不阻止年度推进。暂停保留已付费用与工作进度，释放人物额外事务名额；恢复与换人沿用同一机会实例，不重复扣原费用。明确放弃后已支付服务费、工料费和交易投入不退，未产生的收益不发。旧卷押金遵循独立的归还和逾期规则。

工作项目使用 `completedWorkYears / requiredWorkYears`。有效年度由模拟系统确认，UI 不凭余额、头像颜色或面板选择代替年度事实。机会结果、费用和资格消费需要在同一保存提交中完成，并以 `opportunityId + instanceId + stageId + claimKey` 防止重复结算。

## OriginView 接口

`OriginView` 只读取并提交 `OriginSystem` 合同，不直接修改 `run`：

```lua
local OriginSystem = require "Jiaye.OriginSystem"

OriginSystem.Get(run)
-- 返回 nil（旧 run）或当前背景机会记录。

OriginSystem.Summary(run)
-- { title, originName, statusText, detail, benefitsText }

OriginSystem.Actions(run)
-- { id, label, inputKind = "none|adult|study|study_target|work_target", attachments = boolean }

OriginSystem.Quote(run, actionId, input)
-- { allowed, reasons = {}, cost = { money = 0, grain = 0 }, workYears = 0,
--   label, description, successChance? }

OriginSystem.Execute(run, actionId, input)
-- input = { memberId = ?, attachedInstanceIds = {} }
-- 返回 ok, message。
```

UI 约定：

- `View.Card(app)` 在 `OriginSystem.Get(app.run)` 返回 `nil` 时返回 `nil`，当前新 run 才展示背景机会卡。
- `View.Open(app)` 展示摘要、当前状态、收益拆分和行动列表；行动详情使用滚动内容，不把长规则铺在主页面。
- 有人选的行动列出所有在世族人，逐人调用 `Quote`；每个人的禁用原因直接显示在该行，确认按钮也按当前报价禁用。
- `attachments = true` 时只列出当前未出售且属于 `ruler` 或 `plan` 的信物，允许多选或留空；其他行动不展示挂载区。
- 暂停、恢复、放弃、借卷、还卷、换读者、完成分支和普通开始动作全部通过 `app:ConfirmRunAction(title, quote.description, callback, ..., parentModal)` 提交。回调接收 `RunAction` 提供的候选 `run`，调用 `OriginSystem.Execute(run, actionId, input)`。

## 核心行动 ID

```text
start（由 `sourceOriginId` 区分 plain / artisan / gentry）
audit / settle / renew
borrow / return / assign_reader
safe / rush
keep_seed / share_seed / keep_food
take_cash / take_discount
study_referral / work_referral
pause / resume / abandon
```

行动返回的 `label`、条件和结果描述以 `Summary`、`Quote` 为准，View 不重复维护一份费用或收益计算。
