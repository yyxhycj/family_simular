# ASSET_MANIFEST · 水墨素材拆分交付 v2

**实际完成：68幅独立画面裁片、236个PNG导出。来源是图集，不是68张分别生成的原生高清原画。**

人物20，家宅16，事件12，信物20；状态/尺寸变体不算新人物或新原画。

旧v1完整752个归档文件另在 `legacy_v1/`，其中原manifest登记722项运行资源。不得把其数量说成本次新增手绘原画。

## 来源

| 类别 | 源文件 | 尺寸 | 用途 |
|---|---|---|---|
| portraits | `sources/portraits_age_sheet.png` | 1448×1086 | 拆分来源 |
| states | `references/portrait_state_sheet_unbound.png` | 1448×1086 | 仅参考，不绑定角色状态 |
| houses | `sources/houses_sheet.png` | 1448×1086 | 拆分来源 |
| events | `sources/events_sheet.png` | 1448×1086 | 拆分来源 |
| relics | `sources/relic_forms_sheet.png` | 1448×1086 | 拆分来源 |

## 透明、裁切和背景

RGBA透明图包括人物和信物，alpha保留。场景为不透明图。原生裁片与适配导出均列明；自带浅纸背景的场景不可当透明贴纸。完整原坐标、trim、安全区和SHA256见 `data/asset_registry.json` 与 `data/crop_map.json`。

## 全部本轮导出

| ID | 文件 | 像素尺寸 | Alpha | 原裁片尺寸 | 处理 |
|---|---|---|---|---|
| `portrait_m01.infant.native` | `assets/characters/ink_v2/portrait_m01/infant_native.png` | 239×257 | 有 | 239×257 | native_crop |
| `portrait_m01.infant.detail` | `assets/characters/ink_v2/portrait_m01/infant_detail_768.png` | 768×768 | 有 | 239×257 | resampled_contain |
| `portrait_m01.infant.normal` | `assets/characters/ink_v2/portrait_m01/infant_normal_256.png` | 256×256 | 有 | 239×257 | same_base_rgba_state_overlay |
| `portrait_m01.infant.sick` | `assets/characters/ink_v2/portrait_m01/infant_sick_256.png` | 256×256 | 有 | 239×257 | same_base_rgba_state_overlay |
| `portrait_m01.infant.deceased` | `assets/characters/ink_v2/portrait_m01/infant_deceased_256.png` | 256×256 | 有 | 239×257 | same_base_rgba_state_overlay |
| `portrait_m01.infant.selected` | `assets/characters/ink_v2/portrait_m01/infant_selected_256.png` | 256×256 | 有 | 239×257 | same_base_rgba_state_overlay |
| `portrait_m01.child.native` | `assets/characters/ink_v2/portrait_m01/child_native.png` | 234×286 | 有 | 234×286 | native_crop |
| `portrait_m01.child.detail` | `assets/characters/ink_v2/portrait_m01/child_detail_768.png` | 768×768 | 有 | 234×286 | resampled_contain |
| `portrait_m01.child.normal` | `assets/characters/ink_v2/portrait_m01/child_normal_256.png` | 256×256 | 有 | 234×286 | same_base_rgba_state_overlay |
| `portrait_m01.child.sick` | `assets/characters/ink_v2/portrait_m01/child_sick_256.png` | 256×256 | 有 | 234×286 | same_base_rgba_state_overlay |
| `portrait_m01.child.deceased` | `assets/characters/ink_v2/portrait_m01/child_deceased_256.png` | 256×256 | 有 | 234×286 | same_base_rgba_state_overlay |
| `portrait_m01.child.selected` | `assets/characters/ink_v2/portrait_m01/child_selected_256.png` | 256×256 | 有 | 234×286 | same_base_rgba_state_overlay |
| `portrait_m01.young.native` | `assets/characters/ink_v2/portrait_m01/young_native.png` | 282×295 | 有 | 282×295 | native_crop |
| `portrait_m01.young.detail` | `assets/characters/ink_v2/portrait_m01/young_detail_768.png` | 768×768 | 有 | 282×295 | resampled_contain |
| `portrait_m01.young.normal` | `assets/characters/ink_v2/portrait_m01/young_normal_256.png` | 256×256 | 有 | 282×295 | same_base_rgba_state_overlay |
| `portrait_m01.young.sick` | `assets/characters/ink_v2/portrait_m01/young_sick_256.png` | 256×256 | 有 | 282×295 | same_base_rgba_state_overlay |
| `portrait_m01.young.deceased` | `assets/characters/ink_v2/portrait_m01/young_deceased_256.png` | 256×256 | 有 | 282×295 | same_base_rgba_state_overlay |
| `portrait_m01.young.selected` | `assets/characters/ink_v2/portrait_m01/young_selected_256.png` | 256×256 | 有 | 282×295 | same_base_rgba_state_overlay |
| `portrait_m01.adult.native` | `assets/characters/ink_v2/portrait_m01/adult_native.png` | 281×295 | 有 | 281×295 | native_crop |
| `portrait_m01.adult.detail` | `assets/characters/ink_v2/portrait_m01/adult_detail_768.png` | 768×768 | 有 | 281×295 | resampled_contain |
| `portrait_m01.adult.normal` | `assets/characters/ink_v2/portrait_m01/adult_normal_256.png` | 256×256 | 有 | 281×295 | same_base_rgba_state_overlay |
| `portrait_m01.adult.sick` | `assets/characters/ink_v2/portrait_m01/adult_sick_256.png` | 256×256 | 有 | 281×295 | same_base_rgba_state_overlay |
| `portrait_m01.adult.deceased` | `assets/characters/ink_v2/portrait_m01/adult_deceased_256.png` | 256×256 | 有 | 281×295 | same_base_rgba_state_overlay |
| `portrait_m01.adult.selected` | `assets/characters/ink_v2/portrait_m01/adult_selected_256.png` | 256×256 | 有 | 281×295 | same_base_rgba_state_overlay |
| `portrait_m01.elder.native` | `assets/characters/ink_v2/portrait_m01/elder_native.png` | 284×295 | 有 | 284×295 | native_crop |
| `portrait_m01.elder.detail` | `assets/characters/ink_v2/portrait_m01/elder_detail_768.png` | 768×768 | 有 | 284×295 | resampled_contain |
| `portrait_m01.elder.normal` | `assets/characters/ink_v2/portrait_m01/elder_normal_256.png` | 256×256 | 有 | 284×295 | same_base_rgba_state_overlay |
| `portrait_m01.elder.sick` | `assets/characters/ink_v2/portrait_m01/elder_sick_256.png` | 256×256 | 有 | 284×295 | same_base_rgba_state_overlay |
| `portrait_m01.elder.deceased` | `assets/characters/ink_v2/portrait_m01/elder_deceased_256.png` | 256×256 | 有 | 284×295 | same_base_rgba_state_overlay |
| `portrait_m01.elder.selected` | `assets/characters/ink_v2/portrait_m01/elder_selected_256.png` | 256×256 | 有 | 284×295 | same_base_rgba_state_overlay |
| `portrait_f01.infant.native` | `assets/characters/ink_v2/portrait_f01/infant_native.png` | 245×231 | 有 | 245×231 | native_crop |
| `portrait_f01.infant.detail` | `assets/characters/ink_v2/portrait_f01/infant_detail_768.png` | 768×768 | 有 | 245×231 | resampled_contain |
| `portrait_f01.infant.normal` | `assets/characters/ink_v2/portrait_f01/infant_normal_256.png` | 256×256 | 有 | 245×231 | same_base_rgba_state_overlay |
| `portrait_f01.infant.sick` | `assets/characters/ink_v2/portrait_f01/infant_sick_256.png` | 256×256 | 有 | 245×231 | same_base_rgba_state_overlay |
| `portrait_f01.infant.deceased` | `assets/characters/ink_v2/portrait_f01/infant_deceased_256.png` | 256×256 | 有 | 245×231 | same_base_rgba_state_overlay |
| `portrait_f01.infant.selected` | `assets/characters/ink_v2/portrait_f01/infant_selected_256.png` | 256×256 | 有 | 245×231 | same_base_rgba_state_overlay |
| `portrait_f01.child.native` | `assets/characters/ink_v2/portrait_f01/child_native.png` | 241×273 | 有 | 241×273 | native_crop |
| `portrait_f01.child.detail` | `assets/characters/ink_v2/portrait_f01/child_detail_768.png` | 768×768 | 有 | 241×273 | resampled_contain |
| `portrait_f01.child.normal` | `assets/characters/ink_v2/portrait_f01/child_normal_256.png` | 256×256 | 有 | 241×273 | same_base_rgba_state_overlay |
| `portrait_f01.child.sick` | `assets/characters/ink_v2/portrait_f01/child_sick_256.png` | 256×256 | 有 | 241×273 | same_base_rgba_state_overlay |
| `portrait_f01.child.deceased` | `assets/characters/ink_v2/portrait_f01/child_deceased_256.png` | 256×256 | 有 | 241×273 | same_base_rgba_state_overlay |
| `portrait_f01.child.selected` | `assets/characters/ink_v2/portrait_f01/child_selected_256.png` | 256×256 | 有 | 241×273 | same_base_rgba_state_overlay |
| `portrait_f01.young.native` | `assets/characters/ink_v2/portrait_f01/young_native.png` | 262×273 | 有 | 262×273 | native_crop |
| `portrait_f01.young.detail` | `assets/characters/ink_v2/portrait_f01/young_detail_768.png` | 768×768 | 有 | 262×273 | resampled_contain |
| `portrait_f01.young.normal` | `assets/characters/ink_v2/portrait_f01/young_normal_256.png` | 256×256 | 有 | 262×273 | same_base_rgba_state_overlay |
| `portrait_f01.young.sick` | `assets/characters/ink_v2/portrait_f01/young_sick_256.png` | 256×256 | 有 | 262×273 | same_base_rgba_state_overlay |
| `portrait_f01.young.deceased` | `assets/characters/ink_v2/portrait_f01/young_deceased_256.png` | 256×256 | 有 | 262×273 | same_base_rgba_state_overlay |
| `portrait_f01.young.selected` | `assets/characters/ink_v2/portrait_f01/young_selected_256.png` | 256×256 | 有 | 262×273 | same_base_rgba_state_overlay |
| `portrait_f01.adult.native` | `assets/characters/ink_v2/portrait_f01/adult_native.png` | 255×273 | 有 | 255×273 | native_crop |
| `portrait_f01.adult.detail` | `assets/characters/ink_v2/portrait_f01/adult_detail_768.png` | 768×768 | 有 | 255×273 | resampled_contain |
| `portrait_f01.adult.normal` | `assets/characters/ink_v2/portrait_f01/adult_normal_256.png` | 256×256 | 有 | 255×273 | same_base_rgba_state_overlay |
| `portrait_f01.adult.sick` | `assets/characters/ink_v2/portrait_f01/adult_sick_256.png` | 256×256 | 有 | 255×273 | same_base_rgba_state_overlay |
| `portrait_f01.adult.deceased` | `assets/characters/ink_v2/portrait_f01/adult_deceased_256.png` | 256×256 | 有 | 255×273 | same_base_rgba_state_overlay |
| `portrait_f01.adult.selected` | `assets/characters/ink_v2/portrait_f01/adult_selected_256.png` | 256×256 | 有 | 255×273 | same_base_rgba_state_overlay |
| `portrait_f01.elder.native` | `assets/characters/ink_v2/portrait_f01/elder_native.png` | 252×273 | 有 | 252×273 | native_crop |
| `portrait_f01.elder.detail` | `assets/characters/ink_v2/portrait_f01/elder_detail_768.png` | 768×768 | 有 | 252×273 | resampled_contain |
| `portrait_f01.elder.normal` | `assets/characters/ink_v2/portrait_f01/elder_normal_256.png` | 256×256 | 有 | 252×273 | same_base_rgba_state_overlay |
| `portrait_f01.elder.sick` | `assets/characters/ink_v2/portrait_f01/elder_sick_256.png` | 256×256 | 有 | 252×273 | same_base_rgba_state_overlay |
| `portrait_f01.elder.deceased` | `assets/characters/ink_v2/portrait_f01/elder_deceased_256.png` | 256×256 | 有 | 252×273 | same_base_rgba_state_overlay |
| `portrait_f01.elder.selected` | `assets/characters/ink_v2/portrait_f01/elder_selected_256.png` | 256×256 | 有 | 252×273 | same_base_rgba_state_overlay |
| `portrait_m02.infant.native` | `assets/characters/ink_v2/portrait_m02/infant_native.png` | 249×255 | 有 | 249×255 | native_crop |
| `portrait_m02.infant.detail` | `assets/characters/ink_v2/portrait_m02/infant_detail_768.png` | 768×768 | 有 | 249×255 | resampled_contain |
| `portrait_m02.infant.normal` | `assets/characters/ink_v2/portrait_m02/infant_normal_256.png` | 256×256 | 有 | 249×255 | same_base_rgba_state_overlay |
| `portrait_m02.infant.sick` | `assets/characters/ink_v2/portrait_m02/infant_sick_256.png` | 256×256 | 有 | 249×255 | same_base_rgba_state_overlay |
| `portrait_m02.infant.deceased` | `assets/characters/ink_v2/portrait_m02/infant_deceased_256.png` | 256×256 | 有 | 249×255 | same_base_rgba_state_overlay |
| `portrait_m02.infant.selected` | `assets/characters/ink_v2/portrait_m02/infant_selected_256.png` | 256×256 | 有 | 249×255 | same_base_rgba_state_overlay |
| `portrait_m02.child.native` | `assets/characters/ink_v2/portrait_m02/child_native.png` | 255×267 | 有 | 255×267 | native_crop |
| `portrait_m02.child.detail` | `assets/characters/ink_v2/portrait_m02/child_detail_768.png` | 768×768 | 有 | 255×267 | resampled_contain |
| `portrait_m02.child.normal` | `assets/characters/ink_v2/portrait_m02/child_normal_256.png` | 256×256 | 有 | 255×267 | same_base_rgba_state_overlay |
| `portrait_m02.child.sick` | `assets/characters/ink_v2/portrait_m02/child_sick_256.png` | 256×256 | 有 | 255×267 | same_base_rgba_state_overlay |
| `portrait_m02.child.deceased` | `assets/characters/ink_v2/portrait_m02/child_deceased_256.png` | 256×256 | 有 | 255×267 | same_base_rgba_state_overlay |
| `portrait_m02.child.selected` | `assets/characters/ink_v2/portrait_m02/child_selected_256.png` | 256×256 | 有 | 255×267 | same_base_rgba_state_overlay |
| `portrait_m02.young.native` | `assets/characters/ink_v2/portrait_m02/young_native.png` | 259×267 | 有 | 259×267 | native_crop |
| `portrait_m02.young.detail` | `assets/characters/ink_v2/portrait_m02/young_detail_768.png` | 768×768 | 有 | 259×267 | resampled_contain |
| `portrait_m02.young.normal` | `assets/characters/ink_v2/portrait_m02/young_normal_256.png` | 256×256 | 有 | 259×267 | same_base_rgba_state_overlay |
| `portrait_m02.young.sick` | `assets/characters/ink_v2/portrait_m02/young_sick_256.png` | 256×256 | 有 | 259×267 | same_base_rgba_state_overlay |
| `portrait_m02.young.deceased` | `assets/characters/ink_v2/portrait_m02/young_deceased_256.png` | 256×256 | 有 | 259×267 | same_base_rgba_state_overlay |
| `portrait_m02.young.selected` | `assets/characters/ink_v2/portrait_m02/young_selected_256.png` | 256×256 | 有 | 259×267 | same_base_rgba_state_overlay |
| `portrait_m02.adult.native` | `assets/characters/ink_v2/portrait_m02/adult_native.png` | 266×267 | 有 | 266×267 | native_crop |
| `portrait_m02.adult.detail` | `assets/characters/ink_v2/portrait_m02/adult_detail_768.png` | 768×768 | 有 | 266×267 | resampled_contain |
| `portrait_m02.adult.normal` | `assets/characters/ink_v2/portrait_m02/adult_normal_256.png` | 256×256 | 有 | 266×267 | same_base_rgba_state_overlay |
| `portrait_m02.adult.sick` | `assets/characters/ink_v2/portrait_m02/adult_sick_256.png` | 256×256 | 有 | 266×267 | same_base_rgba_state_overlay |
| `portrait_m02.adult.deceased` | `assets/characters/ink_v2/portrait_m02/adult_deceased_256.png` | 256×256 | 有 | 266×267 | same_base_rgba_state_overlay |
| `portrait_m02.adult.selected` | `assets/characters/ink_v2/portrait_m02/adult_selected_256.png` | 256×256 | 有 | 266×267 | same_base_rgba_state_overlay |
| `portrait_m02.elder.native` | `assets/characters/ink_v2/portrait_m02/elder_native.png` | 289×267 | 有 | 289×267 | native_crop |
| `portrait_m02.elder.detail` | `assets/characters/ink_v2/portrait_m02/elder_detail_768.png` | 768×768 | 有 | 289×267 | resampled_contain |
| `portrait_m02.elder.normal` | `assets/characters/ink_v2/portrait_m02/elder_normal_256.png` | 256×256 | 有 | 289×267 | same_base_rgba_state_overlay |
| `portrait_m02.elder.sick` | `assets/characters/ink_v2/portrait_m02/elder_sick_256.png` | 256×256 | 有 | 289×267 | same_base_rgba_state_overlay |
| `portrait_m02.elder.deceased` | `assets/characters/ink_v2/portrait_m02/elder_deceased_256.png` | 256×256 | 有 | 289×267 | same_base_rgba_state_overlay |
| `portrait_m02.elder.selected` | `assets/characters/ink_v2/portrait_m02/elder_selected_256.png` | 256×256 | 有 | 289×267 | same_base_rgba_state_overlay |
| `portrait_f02.infant.native` | `assets/characters/ink_v2/portrait_f02/infant_native.png` | 231×234 | 有 | 231×234 | native_crop |
| `portrait_f02.infant.detail` | `assets/characters/ink_v2/portrait_f02/infant_detail_768.png` | 768×768 | 有 | 231×234 | resampled_contain |
| `portrait_f02.infant.normal` | `assets/characters/ink_v2/portrait_f02/infant_normal_256.png` | 256×256 | 有 | 231×234 | same_base_rgba_state_overlay |
| `portrait_f02.infant.sick` | `assets/characters/ink_v2/portrait_f02/infant_sick_256.png` | 256×256 | 有 | 231×234 | same_base_rgba_state_overlay |
| `portrait_f02.infant.deceased` | `assets/characters/ink_v2/portrait_f02/infant_deceased_256.png` | 256×256 | 有 | 231×234 | same_base_rgba_state_overlay |
| `portrait_f02.infant.selected` | `assets/characters/ink_v2/portrait_f02/infant_selected_256.png` | 256×256 | 有 | 231×234 | same_base_rgba_state_overlay |
| `portrait_f02.child.native` | `assets/characters/ink_v2/portrait_f02/child_native.png` | 236×251 | 有 | 236×251 | native_crop |
| `portrait_f02.child.detail` | `assets/characters/ink_v2/portrait_f02/child_detail_768.png` | 768×768 | 有 | 236×251 | resampled_contain |
| `portrait_f02.child.normal` | `assets/characters/ink_v2/portrait_f02/child_normal_256.png` | 256×256 | 有 | 236×251 | same_base_rgba_state_overlay |
| `portrait_f02.child.sick` | `assets/characters/ink_v2/portrait_f02/child_sick_256.png` | 256×256 | 有 | 236×251 | same_base_rgba_state_overlay |
| `portrait_f02.child.deceased` | `assets/characters/ink_v2/portrait_f02/child_deceased_256.png` | 256×256 | 有 | 236×251 | same_base_rgba_state_overlay |
| `portrait_f02.child.selected` | `assets/characters/ink_v2/portrait_f02/child_selected_256.png` | 256×256 | 有 | 236×251 | same_base_rgba_state_overlay |
| `portrait_f02.young.native` | `assets/characters/ink_v2/portrait_f02/young_native.png` | 259×251 | 有 | 259×251 | native_crop |
| `portrait_f02.young.detail` | `assets/characters/ink_v2/portrait_f02/young_detail_768.png` | 768×768 | 有 | 259×251 | resampled_contain |
| `portrait_f02.young.normal` | `assets/characters/ink_v2/portrait_f02/young_normal_256.png` | 256×256 | 有 | 259×251 | same_base_rgba_state_overlay |
| `portrait_f02.young.sick` | `assets/characters/ink_v2/portrait_f02/young_sick_256.png` | 256×256 | 有 | 259×251 | same_base_rgba_state_overlay |
| `portrait_f02.young.deceased` | `assets/characters/ink_v2/portrait_f02/young_deceased_256.png` | 256×256 | 有 | 259×251 | same_base_rgba_state_overlay |
| `portrait_f02.young.selected` | `assets/characters/ink_v2/portrait_f02/young_selected_256.png` | 256×256 | 有 | 259×251 | same_base_rgba_state_overlay |
| `portrait_f02.adult.native` | `assets/characters/ink_v2/portrait_f02/adult_native.png` | 264×251 | 有 | 264×251 | native_crop |
| `portrait_f02.adult.detail` | `assets/characters/ink_v2/portrait_f02/adult_detail_768.png` | 768×768 | 有 | 264×251 | resampled_contain |
| `portrait_f02.adult.normal` | `assets/characters/ink_v2/portrait_f02/adult_normal_256.png` | 256×256 | 有 | 264×251 | same_base_rgba_state_overlay |
| `portrait_f02.adult.sick` | `assets/characters/ink_v2/portrait_f02/adult_sick_256.png` | 256×256 | 有 | 264×251 | same_base_rgba_state_overlay |
| `portrait_f02.adult.deceased` | `assets/characters/ink_v2/portrait_f02/adult_deceased_256.png` | 256×256 | 有 | 264×251 | same_base_rgba_state_overlay |
| `portrait_f02.adult.selected` | `assets/characters/ink_v2/portrait_f02/adult_selected_256.png` | 256×256 | 有 | 264×251 | same_base_rgba_state_overlay |
| `portrait_f02.elder.native` | `assets/characters/ink_v2/portrait_f02/elder_native.png` | 258×251 | 有 | 258×251 | native_crop |
| `portrait_f02.elder.detail` | `assets/characters/ink_v2/portrait_f02/elder_detail_768.png` | 768×768 | 有 | 258×251 | resampled_contain |
| `portrait_f02.elder.normal` | `assets/characters/ink_v2/portrait_f02/elder_normal_256.png` | 256×256 | 有 | 258×251 | same_base_rgba_state_overlay |
| `portrait_f02.elder.sick` | `assets/characters/ink_v2/portrait_f02/elder_sick_256.png` | 256×256 | 有 | 258×251 | same_base_rgba_state_overlay |
| `portrait_f02.elder.deceased` | `assets/characters/ink_v2/portrait_f02/elder_deceased_256.png` | 256×256 | 有 | 258×251 | same_base_rgba_state_overlay |
| `portrait_f02.elder.selected` | `assets/characters/ink_v2/portrait_f02/elder_selected_256.png` | 256×256 | 有 | 258×251 | same_base_rgba_state_overlay |
| `rented.normal.native` | `assets/houses/ink_v2/rented_normal_native.png` | 362×277 | 无 | 362×277 | native_crop |
| `rented.normal.display` | `assets/houses/ink_v2/rented_normal_1200x560.png` | 1200×560 | 无 | 362×277 | resampled_contain_with_padding |
| `rented.damaged.native` | `assets/houses/ink_v2/rented_damaged_native.png` | 362×277 | 无 | 362×277 | native_crop |
| `rented.damaged.display` | `assets/houses/ink_v2/rented_damaged_1200x560.png` | 1200×560 | 无 | 362×277 | resampled_contain_with_padding |
| `rented.upgraded.native` | `assets/houses/ink_v2/rented_upgraded_native.png` | 362×277 | 无 | 362×277 | native_crop |
| `rented.upgraded.display` | `assets/houses/ink_v2/rented_upgraded_1200x560.png` | 1200×560 | 无 | 362×277 | resampled_contain_with_padding |
| `rented.relocated.native` | `assets/houses/ink_v2/rented_relocated_native.png` | 362×277 | 无 | 362×277 | native_crop |
| `rented.relocated.display` | `assets/houses/ink_v2/rented_relocated_1200x560.png` | 1200×560 | 无 | 362×277 | resampled_contain_with_padding |
| `simple.normal.native` | `assets/houses/ink_v2/simple_normal_native.png` | 362×269 | 无 | 362×269 | native_crop |
| `simple.normal.display` | `assets/houses/ink_v2/simple_normal_1200x560.png` | 1200×560 | 无 | 362×269 | resampled_contain_with_padding |
| `simple.damaged.native` | `assets/houses/ink_v2/simple_damaged_native.png` | 362×269 | 无 | 362×269 | native_crop |
| `simple.damaged.display` | `assets/houses/ink_v2/simple_damaged_1200x560.png` | 1200×560 | 无 | 362×269 | resampled_contain_with_padding |
| `simple.upgraded.native` | `assets/houses/ink_v2/simple_upgraded_native.png` | 362×269 | 无 | 362×269 | native_crop |
| `simple.upgraded.display` | `assets/houses/ink_v2/simple_upgraded_1200x560.png` | 1200×560 | 无 | 362×269 | resampled_contain_with_padding |
| `simple.relocated.native` | `assets/houses/ink_v2/simple_relocated_native.png` | 362×269 | 无 | 362×269 | native_crop |
| `simple.relocated.display` | `assets/houses/ink_v2/simple_relocated_1200x560.png` | 1200×560 | 无 | 362×269 | resampled_contain_with_padding |
| `courtyard.normal.native` | `assets/houses/ink_v2/courtyard_normal_native.png` | 362×256 | 无 | 362×256 | native_crop |
| `courtyard.normal.display` | `assets/houses/ink_v2/courtyard_normal_1200x560.png` | 1200×560 | 无 | 362×256 | resampled_contain_with_padding |
| `courtyard.damaged.native` | `assets/houses/ink_v2/courtyard_damaged_native.png` | 362×256 | 无 | 362×256 | native_crop |
| `courtyard.damaged.display` | `assets/houses/ink_v2/courtyard_damaged_1200x560.png` | 1200×560 | 无 | 362×256 | resampled_contain_with_padding |
| `courtyard.upgraded.native` | `assets/houses/ink_v2/courtyard_upgraded_native.png` | 362×256 | 无 | 362×256 | native_crop |
| `courtyard.upgraded.display` | `assets/houses/ink_v2/courtyard_upgraded_1200x560.png` | 1200×560 | 无 | 362×256 | resampled_contain_with_padding |
| `courtyard.relocated.native` | `assets/houses/ink_v2/courtyard_relocated_native.png` | 362×256 | 无 | 362×256 | native_crop |
| `courtyard.relocated.display` | `assets/houses/ink_v2/courtyard_relocated_1200x560.png` | 1200×560 | 无 | 362×256 | resampled_contain_with_padding |
| `estate.normal.native` | `assets/houses/ink_v2/estate_normal_native.png` | 362×284 | 无 | 362×284 | native_crop |
| `estate.normal.display` | `assets/houses/ink_v2/estate_normal_1200x560.png` | 1200×560 | 无 | 362×284 | resampled_contain_with_padding |
| `estate.damaged.native` | `assets/houses/ink_v2/estate_damaged_native.png` | 362×284 | 无 | 362×284 | native_crop |
| `estate.damaged.display` | `assets/houses/ink_v2/estate_damaged_1200x560.png` | 1200×560 | 无 | 362×284 | resampled_contain_with_padding |
| `estate.upgraded.native` | `assets/houses/ink_v2/estate_upgraded_native.png` | 362×284 | 无 | 362×284 | native_crop |
| `estate.upgraded.display` | `assets/houses/ink_v2/estate_upgraded_1200x560.png` | 1200×560 | 无 | 362×284 | resampled_contain_with_padding |
| `estate.relocated.native` | `assets/houses/ink_v2/estate_relocated_native.png` | 362×284 | 无 | 362×284 | native_crop |
| `estate.relocated.display` | `assets/houses/ink_v2/estate_relocated_1200x560.png` | 1200×560 | 无 | 362×284 | resampled_contain_with_padding |
| `ruler.native` | `assets/events/ink_v2/ruler_native.png` | 471×259 | 无 | 471×259 | native_crop |
| `ruler.display` | `assets/events/ink_v2/ruler_1200x560.png` | 1200×560 | 无 | 471×259 | resampled_contain_with_padding |
| `book.native` | `assets/events/ink_v2/book_native.png` | 469×259 | 无 | 469×259 | native_crop |
| `book.display` | `assets/events/ink_v2/book_1200x560.png` | 1200×560 | 无 | 469×259 | resampled_contain_with_padding |
| `letter.native` | `assets/events/ink_v2/letter_native.png` | 470×259 | 无 | 470×259 | native_crop |
| `letter.display` | `assets/events/ink_v2/letter_1200x560.png` | 1200×560 | 无 | 470×259 | resampled_contain_with_padding |
| `medical.native` | `assets/events/ink_v2/medical_native.png` | 471×259 | 无 | 471×259 | native_crop |
| `medical.display` | `assets/events/ink_v2/medical_1200x560.png` | 1200×560 | 无 | 471×259 | resampled_contain_with_padding |
| `repair.native` | `assets/events/ink_v2/repair_native.png` | 469×259 | 无 | 469×259 | native_crop |
| `repair.display` | `assets/events/ink_v2/repair_1200x560.png` | 1200×560 | 无 | 469×259 | resampled_contain_with_padding |
| `neighbors.native` | `assets/events/ink_v2/neighbors_native.png` | 470×259 | 无 | 470×259 | native_crop |
| `neighbors.display` | `assets/events/ink_v2/neighbors_1200x560.png` | 1200×560 | 无 | 470×259 | resampled_contain_with_padding |
| `school.native` | `assets/events/ink_v2/school_native.png` | 471×259 | 无 | 471×259 | native_crop |
| `school.display` | `assets/events/ink_v2/school_1200x560.png` | 1200×560 | 无 | 471×259 | resampled_contain_with_padding |
| `roof.native` | `assets/events/ink_v2/roof_native.png` | 469×259 | 无 | 469×259 | native_crop |
| `roof.display` | `assets/events/ink_v2/roof_1200x560.png` | 1200×560 | 无 | 469×259 | resampled_contain_with_padding |
| `jade.native` | `assets/events/ink_v2/jade_native.png` | 470×259 | 无 | 470×259 | native_crop |
| `jade.display` | `assets/events/ink_v2/jade_1200x560.png` | 1200×560 | 无 | 470×259 | resampled_contain_with_padding |
| `reunion.native` | `assets/events/ink_v2/reunion_native.png` | 471×260 | 无 | 471×260 | native_crop |
| `reunion.display` | `assets/events/ink_v2/reunion_1200x560.png` | 1200×560 | 无 | 471×260 | resampled_contain_with_padding |
| `leadership.native` | `assets/events/ink_v2/leadership_native.png` | 469×260 | 无 | 469×260 | native_crop |
| `leadership.display` | `assets/events/ink_v2/leadership_1200x560.png` | 1200×560 | 无 | 469×260 | resampled_contain_with_padding |
| `migration.native` | `assets/events/ink_v2/migration_native.png` | 470×260 | 无 | 470×260 | native_crop |
| `migration.display` | `assets/events/ink_v2/migration_1200x560.png` | 1200×560 | 无 | 470×260 | resampled_contain_with_padding |
| `genealogy.1.native` | `assets/relics/ink_v2/genealogy_1_native.png` | 245×243 | 有 | 245×243 | native_crop |
| `genealogy.1.display` | `assets/relics/ink_v2/genealogy_1_512.png` | 512×512 | 有 | 245×243 | resampled_contain |
| `genealogy.1.icon` | `assets/relics/ink_v2/genealogy_1_128.png` | 128×128 | 有 | 245×243 | downsampled_contain |
| `genealogy.2.native` | `assets/relics/ink_v2/genealogy_2_native.png` | 251×240 | 有 | 251×240 | native_crop |
| `genealogy.2.display` | `assets/relics/ink_v2/genealogy_2_512.png` | 512×512 | 有 | 251×240 | resampled_contain |
| `genealogy.2.icon` | `assets/relics/ink_v2/genealogy_2_128.png` | 128×128 | 有 | 251×240 | downsampled_contain |
| `genealogy.3.native` | `assets/relics/ink_v2/genealogy_3_native.png` | 284×239 | 有 | 284×239 | native_crop |
| `genealogy.3.display` | `assets/relics/ink_v2/genealogy_3_512.png` | 512×512 | 有 | 284×239 | resampled_contain |
| `genealogy.3.icon` | `assets/relics/ink_v2/genealogy_3_128.png` | 128×128 | 有 | 284×239 | downsampled_contain |
| `ruler.1.native` | `assets/relics/ink_v2/ruler_1_native.png` | 241×235 | 有 | 241×235 | native_crop |
| `ruler.1.display` | `assets/relics/ink_v2/ruler_1_512.png` | 512×512 | 有 | 241×235 | resampled_contain |
| `ruler.1.icon` | `assets/relics/ink_v2/ruler_1_128.png` | 128×128 | 有 | 241×235 | downsampled_contain |
| `ruler.2.native` | `assets/relics/ink_v2/ruler_2_native.png` | 255×235 | 有 | 255×235 | native_crop |
| `ruler.2.display` | `assets/relics/ink_v2/ruler_2_512.png` | 512×512 | 有 | 255×235 | resampled_contain |
| `ruler.2.icon` | `assets/relics/ink_v2/ruler_2_128.png` | 128×128 | 有 | 255×235 | downsampled_contain |
| `ruler.3.native` | `assets/relics/ink_v2/ruler_3_native.png` | 254×245 | 有 | 254×245 | native_crop |
| `ruler.3.display` | `assets/relics/ink_v2/ruler_3_512.png` | 512×512 | 有 | 254×245 | resampled_contain |
| `ruler.3.icon` | `assets/relics/ink_v2/ruler_3_128.png` | 128×128 | 有 | 254×245 | downsampled_contain |
| `letter.1.native` | `assets/relics/ink_v2/letter_1_native.png` | 273×234 | 有 | 273×234 | native_crop |
| `letter.1.display` | `assets/relics/ink_v2/letter_1_512.png` | 512×512 | 有 | 273×234 | resampled_contain |
| `letter.1.icon` | `assets/relics/ink_v2/letter_1_128.png` | 128×128 | 有 | 273×234 | downsampled_contain |
| `letter.2.native` | `assets/relics/ink_v2/letter_2_native.png` | 277×258 | 有 | 277×258 | native_crop |
| `letter.2.display` | `assets/relics/ink_v2/letter_2_512.png` | 512×512 | 有 | 277×258 | resampled_contain |
| `letter.2.icon` | `assets/relics/ink_v2/letter_2_128.png` | 128×128 | 有 | 277×258 | downsampled_contain |
| `letter.3.native` | `assets/relics/ink_v2/letter_3_native.png` | 261×219 | 有 | 261×219 | native_crop |
| `letter.3.display` | `assets/relics/ink_v2/letter_3_512.png` | 512×512 | 有 | 261×219 | resampled_contain |
| `letter.3.icon` | `assets/relics/ink_v2/letter_3_128.png` | 128×128 | 有 | 261×219 | downsampled_contain |
| `plan.1.native` | `assets/relics/ink_v2/plan_1_native.png` | 283×207 | 有 | 283×207 | native_crop |
| `plan.1.display` | `assets/relics/ink_v2/plan_1_512.png` | 512×512 | 有 | 283×207 | resampled_contain |
| `plan.1.icon` | `assets/relics/ink_v2/plan_1_128.png` | 128×128 | 有 | 283×207 | downsampled_contain |
| `plan.2.native` | `assets/relics/ink_v2/plan_2_native.png` | 292×220 | 有 | 292×220 | native_crop |
| `plan.2.display` | `assets/relics/ink_v2/plan_2_512.png` | 512×512 | 有 | 292×220 | resampled_contain |
| `plan.2.icon` | `assets/relics/ink_v2/plan_2_128.png` | 128×128 | 有 | 292×220 | downsampled_contain |
| `plan.3.native` | `assets/relics/ink_v2/plan_3_native.png` | 305×229 | 有 | 305×229 | native_crop |
| `plan.3.display` | `assets/relics/ink_v2/plan_3_512.png` | 512×512 | 有 | 305×229 | resampled_contain |
| `plan.3.icon` | `assets/relics/ink_v2/plan_3_128.png` | 128×128 | 有 | 305×229 | downsampled_contain |
| `jade.1.native` | `assets/relics/ink_v2/jade_1_native.png` | 156×216 | 有 | 156×216 | native_crop |
| `jade.1.display` | `assets/relics/ink_v2/jade_1_512.png` | 512×512 | 有 | 156×216 | resampled_contain |
| `jade.1.icon` | `assets/relics/ink_v2/jade_1_128.png` | 128×128 | 有 | 156×216 | downsampled_contain |
| `jade.2.native` | `assets/relics/ink_v2/jade_2_native.png` | 232×210 | 有 | 232×210 | native_crop |
| `jade.2.display` | `assets/relics/ink_v2/jade_2_512.png` | 512×512 | 有 | 232×210 | resampled_contain |
| `jade.2.icon` | `assets/relics/ink_v2/jade_2_128.png` | 128×128 | 有 | 232×210 | downsampled_contain |
| `jade.3.heirloom.native` | `assets/relics/ink_v2/jade_3_heirloom_native.png` | 236×226 | 有 | 236×226 | native_crop |
| `jade.3.heirloom.display` | `assets/relics/ink_v2/jade_3_heirloom_512.png` | 512×512 | 有 | 236×226 | resampled_contain |
| `jade.3.heirloom.icon` | `assets/relics/ink_v2/jade_3_heirloom_128.png` | 128×128 | 有 | 236×226 | downsampled_contain |
| `jade.3.alliance.native` | `assets/relics/ink_v2/jade_3_alliance_native.png` | 257×224 | 有 | 257×224 | native_crop |
| `jade.3.alliance.display` | `assets/relics/ink_v2/jade_3_alliance_512.png` | 512×512 | 有 | 257×224 | resampled_contain |
| `jade.3.alliance.icon` | `assets/relics/ink_v2/jade_3_alliance_128.png` | 128×128 | 有 | 257×224 | downsampled_contain |
| `notes.1.native` | `assets/relics/ink_v2/notes_1_native.png` | 268×250 | 有 | 268×250 | native_crop |
| `notes.1.display` | `assets/relics/ink_v2/notes_1_512.png` | 512×512 | 有 | 268×250 | resampled_contain |
| `notes.1.icon` | `assets/relics/ink_v2/notes_1_128.png` | 128×128 | 有 | 268×250 | downsampled_contain |
| `notes.2.native` | `assets/relics/ink_v2/notes_2_native.png` | 280×244 | 有 | 280×244 | native_crop |
| `notes.2.display` | `assets/relics/ink_v2/notes_2_512.png` | 512×512 | 有 | 280×244 | resampled_contain |
| `notes.2.icon` | `assets/relics/ink_v2/notes_2_128.png` | 128×128 | 有 | 280×244 | downsampled_contain |
| `notes.3.private.native` | `assets/relics/ink_v2/notes_3_private_native.png` | 263×248 | 有 | 263×248 | native_crop |
| `notes.3.private.display` | `assets/relics/ink_v2/notes_3_private_512.png` | 512×512 | 有 | 263×248 | resampled_contain |
| `notes.3.private.icon` | `assets/relics/ink_v2/notes_3_private_128.png` | 128×128 | 有 | 263×248 | downsampled_contain |
| `notes.3.public.native` | `assets/relics/ink_v2/notes_3_public_native.png` | 260×244 | 有 | 260×244 | native_crop |
| `notes.3.public.display` | `assets/relics/ink_v2/notes_3_public_512.png` | 512×512 | 有 | 260×244 | resampled_contain |
| `notes.3.public.icon` | `assets/relics/ink_v2/notes_3_public_128.png` | 128×128 | 有 | 260×244 | downsampled_contain |

## 交付边界

本批可用于游戏内美术接入/对照，不等于高清原画视觉终验。人物身份、家宅形体、书页笔迹和高分辨率细节的缺口见 `DELIVERY_STATUS.md`。

不包含字体文件、PSD、原生Figma。旧v1才有SVG分层源；本轮水墨只有扁平PNG来源与导出记录。未改动游戏仓库。