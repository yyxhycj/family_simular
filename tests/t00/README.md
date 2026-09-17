# T00 直接模块复核

从项目根运行。Python 只负责 Lua 5.4 宿主、JSON 桥接及证据落盘，游戏规则仍由现有 Lua 模块执行。

```sh
python3 -m venv /private/tmp/jiaye-t00-venv
/private/tmp/jiaye-t00-venv/bin/python -m pip install -r tests/t00/requirements.txt
/private/tmp/jiaye-t00-venv/bin/python tests/t00/run.py --out /private/tmp/jiaye-t00-recheck
```

输出目录必须尚不存在，避免覆盖冻结证据。脚本不联网，不读写玩家真实存档，不提交代码，不触发 Maker 构建。首次安装依赖需要访问包源。Python 虚拟环境和下载缓存不放入工程。

结果按**正确产品行为**断言：PASS 代表该组有限断言成立；FAIL 代表当前实现不满足要求；进程有失败就返回 1，不用 XFAIL 把已知缺陷涂绿。意外错误会中止，不冒充缺陷复现。当前冻结结果为 16 组、4 PASS、12 FAIL。

## 覆盖边界

- 直接 `require Jiaye.Data/State/Simulation/App`；没有摘录生产函数，没有替换计分、年度、继任、死亡或 PRNG。
- P01–P08 是历史八个场景的当前模块复核；P03/P04 经完整 `AdvanceYear`，P05 经真实 `Marry`，P06/P07 以真实 seed=1 的年度死亡触发继任。断言目标不再是 `ISSUE_REPRODUCED`。
- G01–G04 是必要正常对照：开局闸门、稳定草案、存取往返、正常年度、事件入口继任、非法/重复操作与出售取消奖励。它们不是整个模块的正式验收。
- F01–F04 补启动收藏、坏导入/保存反馈、预算组件回调，以及开局合法性缺口。
- UI 替身仅保存组件声明、执行已有回调并接收 Toast。没有 Yoga/NanoVG、触控、布局或屏幕录制；F03 证明声明与草案不同步，不测可见像素。
- `File` 是隔离的内存文件替身；`cjson` 用 Python JSON 桥接。往返验证生产 Save/Load 调用链，不证明 UrhoX 的真实落盘、原子性、磁盘故障、WASM 持久化。空 Lua table 按默认约定写成 `{}`；未模拟 JSON null 的 UrhoX userdata 行为。
- 测试的 WriteString 返回 0 分支是返回值处理检查，不是物理磁盘故障复现。导出打开失败也是注入边界失败。
- 默认 fixture 只将 `runId` 固定为 `t00-default`，其他值来自真实模块。其他情境保留实际运行 ID；跨次复测可忽略这些时间派生 ID，不能忽略草案/RNG/事件/费用差异。

## 输出

- `manifest.json`：目标/历史 SHA、五个源码字节摘要、全部交付参考文件摘要、测试程序摘要、解释器及证据层级。
- `v5-default.json`：原交付快照中的草案与计分，未执行 V5 HTML，也不是 Lua 可直接导入的存档。
- `current-default.json`：当前 Profile/Draft/Run 与分组计分；是基线夹具，不允许产品把它当随机家庭池。
- `current-cases.json`：历史151条、饥荒、唯一成年继任（处理前与卡住后）、真实信物解锁存档。每个键下为 Save/Load envelope。不是建议导入玩家存档。
- `results.json`：每组正确预期、实际状态、PASS/FAIL。

原 `jiaye-review-design-handoff/review/probes/` 完全不改写、不重跑，不作为本轮通过证据。测试及产物不由 `scripts/main.lua` 引用，不进入游戏启动流程。后续步骤修复时复跑本入口，并为该步骤补齐真实引擎/设备证据；不得据此宣称 T01–T11 完成。
