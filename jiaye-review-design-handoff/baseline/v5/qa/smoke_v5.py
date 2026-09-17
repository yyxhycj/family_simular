#!/usr/bin/env python3
"""V5 handoff smoke checks. Requires Python Playwright + a Chromium executable.
Uses set_content and an explicit in-memory Storage substitute; does not verify
file:// persistence, device Safari, hardware keyboards or native app packaging.
"""
from pathlib import Path
import argparse,json,shutil,traceback
from datetime import datetime,timezone
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--chromium',default=shutil.which('chromium'));args=parser.parse_args()
REPORT=ROOT/'qa/current-smoke.json';imgs=ROOT/'assets/previews';imgs.mkdir(parents=True,exist_ok=True)
report={'date':datetime.now(timezone.utc).isoformat(),'scope':'Frozen V5 only; selected smoke cases, not full acceptance','environment':{'method':'set_content; in-memory localStorage substitute','real_device':False,'file_persistence_verified':False},'checks':[],'browser_errors':[],'screenshots':[]}
def check(name,ok,detail='',level='engine'):
 report['checks'].append({'name':name,'passed':bool(ok),'level':level,'detail':detail})
def snap(page,name):
 page.wait_for_timeout(150);p=imgs/(name+'.png');page.screenshot(path=str(p));report['screenshots'].append('assets/previews/'+p.name)
def reset(page):
 page.evaluate('''()=>{closeModal();draft=clone(window.__baseDraft);store.profile=freshProfile();state=null;store.game=null;screen='setup';step=0;page='overview';pageRandomUndo={};allRandomUndo=null;render();window.scrollTo(0,0)}''')
try:
 with sync_playwright() as p:
  kw={'headless':True,'args':['--no-sandbox']}
  if args.chromium:kw['executable_path']=args.chromium
  b=p.chromium.launch(**kw);report['environment']['browser']=b.version
  page=b.new_page(viewport={'width':390,'height':844},device_scale_factor=1)
  page.on('pageerror',lambda e:report['browser_errors'].append(str(e)))
  page.evaluate("Object.defineProperty(window,'localStorage',{value:(()=>{const d={};return {getItem:k=>d[k]??null,setItem:(k,v)=>d[k]=String(v),removeItem:k=>delete d[k],clear:()=>Object.keys(d).forEach(k=>delete d[k])}})(),configurable:true})")
  page.set_content((ROOT/'prototype/jiaye-demo-v5.html').read_text(),wait_until='load');page.wait_for_timeout(200)
  page.evaluate('window.__baseDraft=clone(draft)')
  check('默认总分为97',page.evaluate('totalPoints()')==97)
  check('四个分配页额度共享',page.evaluate('[0,1,2,3].every(i=>pageBudget(i).remaining===3&&pageBudget(i).capacity===100-pageBudget(i).other)'))
  check('初始解锁三个，带入一件',page.evaluate('store.profile.unlocked.length===3&&draft.relics.length===1'))
  check('七件信物、十三实际终章、144条历史设计',page.evaluate('RELICS.length===7&&ENDINGS.length===13&&ORIGINAL_CATALOG.length===144'))
  for w in [320,360,390,430,768,1280]:
   page.set_viewport_size({'width':w,'height':844});page.wait_for_timeout(120)
   check(f'开局{w}px无页面级横溢出',page.evaluate('document.documentElement.scrollWidth<=innerWidth+1'),level='layout')
  page.set_viewport_size({'width':390,'height':844});snap(page,'opening-390')
  page.locator('[data-opening-period="unrest"]').click();page.locator('#calendar-year').select_option('156')
  check('选择时期与年份联动时世',page.evaluate("draft.era==='unrest'&&draft.calendar===156&&totalPoints()===85"),'real UI card click + select','ui')
  check('家谱反映新年份及来历',page.evaluate("document.querySelector('.family-preview').innerText.includes('156')&&document.querySelector('.family-preview').innerText.includes('手艺人家')"),level='ui')
  reset(page);page.evaluate("setChoice('origin','gentry');goStep(4)");page.wait_for_timeout(180)
  check('超分移动开始按钮禁用',page.locator('#m5-start-next').is_disabled(),level='ui')
  page.evaluate('startGame();commitStart()');check('超分双入口不能建立家族',page.evaluate('state===null'))
  snap(page,'overbudget-390');reset(page)
  page.evaluate('draft.money=110;render()');check('100点合法',page.evaluate('totalPoints()===100&&validateDraft().length===0'))
  page.evaluate('draft.money=120;render()');check('101点被拒绝',page.evaluate('totalPoints()===101&&validateDraft().length>0'));reset(page)
  page.evaluate('draft.calendar=156');check('冲突时期年份被校验拒绝',page.evaluate('validateDraft().some(x=>x.includes("时期"))'));reset(page)
  r=page.evaluate('''()=>{let n=0;for(let i=0;i<4;i++)for(let k=0;k<25;k++){let c=generatePage(i,pageBudget(i).capacity,draft);if(!c)continue;const d={...clone(draft),...c};if(totalPoints(d)>100||validateDraft(d).length)return {ok:false,index:i,errors:validateDraft(d)};n++}return {ok:true,samples:n}}''')
  check('100个页级随机候选合法且不超总分',r['ok'],r)
  for i in range(4):
   reset(page)
   r=page.evaluate('''i=>{step=i;const before=clone(draft);randomizePage();const isolated=[0,1,2,3].filter(x=>x!==i).every(x=>JSON.stringify(snapshotPage(x,before))===JSON.stringify(snapshotPage(x,draft)));undoPageRandom();return {isolated,restored:JSON.stringify(before)===JSON.stringify(draft)}}''',i)
   check(f'第{i+1}页随机隔离与撤销',r['isolated'] and r['restored'],r)
  reset(page);page.evaluate('goStep(1)');snap(page,'setup-members-390');reset(page)
  page.evaluate('goStep(4)');page.wait_for_timeout(180);page.locator('#m5-start-next').click();page.wait_for_timeout(180)
  check('从移动开始按钮建立正常家族',page.evaluate('state!==null&&state.elapsed===0&&state.members.length===4'),level='ui')
  check('手机五主导航可见',page.locator('#m5-bottom-nav button').all_text_contents()==['家族','族人','家业','藏阁','家史'],level='ui')
  snap(page,'home-390');page.evaluate('openMember(3)');snap(page,'member-390')
  check('人物详情具备三章节和保存',page.locator('.m5-detail-tabs button').all_text_contents()==['概况','安排','经历'] and page.get_by_role('button',name='保存安排',exact=True).is_visible(),level='ui')
  page.evaluate("selectMemberJob('study');saveMemberJob()");check('成员安排保存',page.evaluate("get(3).job==='study'"))
  # Re-create baseline to test a genuine implemented relic path.
  reset(page);page.evaluate('commitStart()')
  page.evaluate('window.__event0=state.events[0].id;activeEventChoice=0;resolveEvent(window.__event0)')
  m=page.evaluate('state.money');page.evaluate('activeEventChoice=0;resolveEvent(window.__event0)');check('重复旧事件提交不再扣款',page.evaluate('state.money')==m)
  page.evaluate('advanceYear()');check('一年度推进实际年数加一',page.evaluate('state.elapsed===1'))
  check('老木尺后续按期出现',page.evaluate("state.events.some(e=>e.type==='relicFinish'&&e.relic==='ruler')"))
  page.evaluate('activeEventChoice=0;resolveEvent(state.events[0].id)')
  check('完成寻访解锁营造图但不加开局点数',page.evaluate("store.profile.unlocked.includes('plan')&&LIMIT===100&&state.flags.rulerRestored"))
  check('解锁资格不自动新增实体物件',page.evaluate("!state.relics.some(r=>r.id==='plan')"))
  page.evaluate("navigate('relics')");snap(page,'relics-390')
  r=page.evaluate('''()=>{const before=state.members.map(m=>({id:m.id,job:m.job,age:m.age,parents:m.parents,spouse:m.spouse}));openLeader();pickLeader(3);commitLeader();return {same:JSON.stringify(before)===JSON.stringify(state.members.map(m=>({id:m.id,job:m.job,age:m.age,parents:m.parents,spouse:m.spouse}))),leader:state.leader,ended:state.ended,handovers:handovers()}}''')
  check('主动换任保留成员与同一局',r['same'] and r['leader']==3 and r['ended'] is None,r)
  hv=page.evaluate('handovers()');page.evaluate('openLeader();pickLeader(1);commitLeader()');check('同年切换不追加有效传承',page.evaluate('handovers()')==hv)
  reset(page);page.evaluate('commitStart();activeEventChoice=0;resolveEvent(state.events[0].id);sellRelic("ruler");advanceYear()')
  check('出售取消后续且不解锁奖励',page.evaluate("!state.events.some(e=>e.relic==='ruler')&&!store.profile.unlocked.includes('plan')"))
  # Qualification fixture, not a claim that the end was organically played to.
  page.evaluate("state.events=[];state.elapsed=15;state.metrics.foodYears=10;state.grain=80;render()")
  check('满足发展条件不会自动结束',page.evaluate("readyEndings().some(e=>e.id==='grain')&&state.ended===null"),'constructed state fixture')
  page.evaluate("finishRun('grain')");check('确认主终章后进入只读',page.evaluate("state.ended.id==='grain'"))
  before=page.evaluate('JSON.stringify(state)');page.evaluate('advanceYear()');check('已终局不能推进年度',page.evaluate('JSON.stringify(state)')==before)
  reset(page);page.evaluate('commitStart()');page.evaluate('showCollection()');snap(page,'collection-390')
  check('本轮未发生未捕获页面异常',len(report['browser_errors'])==0,report['browser_errors'],'runtime')
  b.close()
except Exception as exc:
 report['incomplete']=str(exc);report['traceback']=traceback.format_exc()
finally:
 report['summary']={'passed':sum(c['passed'] for c in report['checks']),'failed':sum(not c['passed'] for c in report['checks']),'executed_checks':len(report['checks'])}
 REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report['summary'],ensure_ascii=False))
 if report.get('incomplete'):print(report['incomplete'])
