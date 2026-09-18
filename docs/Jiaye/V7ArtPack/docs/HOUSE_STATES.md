# 家宅状态

rented=租屋，simple=土屋，courtyard=小院，estate=深院/旧宅。每种normal/damaged/upgraded/relocated四图，总16图，PNG1200×560并附SVG。

normal为正常；damaged为局部破损；upgraded为当前类型修整完成。实际升到新住宅等级时使用目标homeId的normal，不能图片一换就增加资产。relocated为同类住宅在新址的环境表达，不决定迁居规则。

主体安全区[75,55,1050,475]。推荐15:7，不透明背景。机器映射data/house_asset_map.json。仅绑定已有业务状态，资源不擅自引入费用或新玩法。
