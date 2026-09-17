# T02 直接模块合同

该合同直接载入当前 `scripts/Jiaye` 的 Lua 5.4 模块。UI 只替换 UrhoX 组件声明，存档只替换 File 与 JSON 边界；不替换开局、预算、随机或年度规则。

```sh
python3 -m venv /private/tmp/jiaye-t02-venv
/private/tmp/jiaye-t02-venv/bin/python -m pip install -r tests/t00/requirements.txt
/private/tmp/jiaye-t02-venv/bin/python tests/t02/run.py --out qa/t02/final
```

覆盖：100/101 与非步进家底拒绝、展示草案快照、只读同源预估、来历/关系/地点叠加、运行期既有价格表、本页随机与跨页撤销隔离。

不覆盖：整户生成（T03）、手机布局/触控（T04/T11）、完整编辑器（T05）、运行期购粮入口（T06/T09）。
