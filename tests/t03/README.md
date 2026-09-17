# T03 直接模块合同

```sh
/private/tmp/jiaye-t02-venv/bin/python tests/t03/run.py --out qa/t03/final
```

直接加载当前 Lua 5.4 模块，验证 128 个固定种子、合法家庭关系、2–6 人与成年族长、解锁池、整户换一家/恢复/无解隔离，以及整户、姓名和本页随机的作用范围。

UI、File 和 JSON 仅以边界适配器替换；不替换生成、规则或 PRNG。真机与手机布局不在本合同内。
