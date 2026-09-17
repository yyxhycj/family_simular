# T10 直接模块验收

运行 `venv/bin/python tests/t10/run.py --out qa/t10/<new-run>`。

该验收调用生产 `State.lua` 与 `Simulation.lua`，每组使用独立磁盘目录和新的 Lua VM。它验证当前格式往返、V5 schema 3 显式迁移、终局保留、损坏备份隔离及导出写失败。真实 UrhoX 入口另由 `scripts/QA/T10.lua` 负责。
