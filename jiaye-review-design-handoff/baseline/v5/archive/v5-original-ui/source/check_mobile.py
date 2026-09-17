from pathlib import Path
import json,re,subprocess,shutil,sys,time,traceback,zipfile
root=Path('/mnt/data'); work=root/'jiaye-v5-work'; report={'checks':[],'screenshots':[],'browser_errors':[],'environment':{}}
def check(name,ok,detail=''):
 report['checks'].append({'name':name,'passed':bool(ok),'detail':detail})
def persist():
 (root/'jiaye-v5-检查记录.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 paths=[root/'jiaye-demo-v5.html',root/'jiaye-v5-mobile-preview.html',root/'jiaye-v5-设计与试玩说明.md',root/'jiaye-v5-检查记录.json']
 with zipfile.ZipFile(root/'jiaye-v5-mobile-ui.zip','w',zipfile.ZIP_DEFLATED) as z:
  for p in paths:
   if p.exists(): z.write(p,p.name)
  for p in work.glob('*'):
   if p.suffix in ['.css','.js','.json'] and p.name not in ['all-scripts.js']: z.write(p,'src/'+p.name)
  for p in root.glob('jiaye-v5-*-screen.png'): z.write(p,'previews/'+p.name)
  p=root/'jiaye-v5-mobile-overview.png'
  if p.exists(): z.write(p,'previews/'+p.name)
try:
 source=(root/'jiaye-demo-v5.html').read_text()
 check('HTML文件非空',len(source)>10000,len(source))
 check('保留100点规则','LIMIT=100' in source.replace(' ','') or 'LIMIT = 100' in source)
 check('独立V5存储键','jiaye_mortal_demo_v5_0' in source)
 check('存在移动端界面脚本','jiaye-v5-view-adapter' in source)
 check('没有禁用缩放','user-scalable=no' not in source and 'maximum-scale=1' not in source)
 old=(root/'jiaye-demo-v4.html').read_text()
 scripts=lambda s:re.findall(r'<script(?:\s[^>]*)?>(.*?)</script\s*>',s,re.S|re.I)
 os=scripts(old); ns=scripts(source)
 check('所有原有JS脚本保留',all(x.replace('jiaye_mortal_demo_v4_0','jiaye_mortal_demo_v5_0') in ns for x in os),'除存储键外未改动原有游戏脚本')
 if shutil.which('node'):
  for i,s in enumerate(ns):
   p=work/('syntax-%s.js'%i);p.write_text(s)
   proc=subprocess.run(['node','--check',str(p)],capture_output=True,text=True,timeout=15)
   check('JS语法检查%s'%i,proc.returncode==0,proc.stderr[-2000:])
  wrapper=(root/'jiaye-v5-mobile-preview.html').read_text()
  wp=work/'wrapper-check.js';wp.write_text(scripts(wrapper)[-1]);proc=subprocess.run(['node','--check',str(wp)],capture_output=True,text=True,timeout=15)
  check('手机预览壳JS语法',proc.returncode==0,proc.stderr[-2000:])
 from playwright.sync_api import sync_playwright
 with sync_playwright() as pw:
  browser=None; attempts=[]
  try:browser=pw.chromium.launch(headless=True,args=['--no-sandbox'])
  except Exception as e:attempts.append(str(e)[:300])
  if browser is None:
   paths=[]
   for base in ['/root/.cache/ms-playwright','/opt','/usr/bin','/home/oai/share','/home/oai/.cache/ms-playwright']:
    b=Path(base)
    if b.exists():
     if base=='/usr/bin':paths += [p for p in [b/'chromium',b/'chromium-browser',b/'google-chrome'] if p.exists()]
     else:paths+=list(b.glob('**/chrome'))+list(b.glob('**/headless_shell'))
   for p in paths[:8]:
    try:browser=pw.chromium.launch(headless=True,executable_path=str(p),args=['--no-sandbox']);break
    except Exception as e:attempts.append(str(e)[:180])
  if browser is None:raise RuntimeError('无法启动浏览器: '+repr(attempts))
  report['environment']={'browser':'Chromium '+browser.version,'method':'file:// 本地文件 + 桌面浏览器窄屏模拟','real_device':False}
  context=browser.new_context(viewport={'width':390,'height':844},device_scale_factor=2,is_mobile=True,has_touch=True)
  page=context.new_page();page.on('pageerror',lambda e:report['browser_errors'].append(str(e)))
  page.goto((root/'jiaye-demo-v5.html').as_uri(),wait_until='load');page.wait_for_timeout(800)
  check('手机开局主界面渲染',page.locator('.v3-setup').count()>0)
  check('手机分步入口',page.locator('.m5-steps .m5-step').count()==5)
  check('底部开局操作区',page.locator('#m5-setup-dock').count()==1)
  check('下一步按钮存在',page.locator('#m5-start-next').count()==1)
  def overflow():return page.evaluate('({w:innerWidth,sw:document.documentElement.scrollWidth,bw:document.body.scrollWidth})')
  metrics=overflow();check('390px页面无横向溢出',metrics['sw']<=metrics['w']+1,metrics)
  page.screenshot(path=str(root/'jiaye-v5-creation-screen.png'),full_page=False);report['screenshots'].append('jiaye-v5-creation-screen.png')
  # Family summary should show real, existing data.
  page.evaluate('JIAYE_V5_UI.openFamily()');page.wait_for_timeout(150)
  check('实时家谱面板可打开',page.locator('#m5-overlay .family-preview').count()>0)
  page.screenshot(path=str(root/'jiaye-v5-family-screen.png'),full_page=False);report['screenshots'].append('jiaye-v5-family-screen.png')
  page.evaluate('JIAYE_V5_UI.close()');page.wait_for_timeout(100)
  page.locator('.m5-steps .m5-step').nth(1).click();page.wait_for_timeout(250)
  check('族人开局页可达',page.locator('.draft-person').count()>0)
  page.screenshot(path=str(root/'jiaye-v5-members-create-screen.png'),full_page=False);report['screenshots'].append('jiaye-v5-members-create-screen.png')
  page.locator('.m5-steps .m5-step').nth(3).click();page.wait_for_timeout(250)
  page.screenshot(path=str(root/'jiaye-v5-relics-create-screen.png'),full_page=False);report['screenshots'].append('jiaye-v5-relics-create-screen.png')
  page.locator('.m5-steps .m5-step').nth(4).click();page.wait_for_timeout(250)
  page.screenshot(path=str(root/'jiaye-v5-review-screen.png'),full_page=False);report['screenshots'].append('jiaye-v5-review-screen.png')
  if page.locator('#m5-start-next').count() and not page.locator('#m5-start-next').is_disabled():
   page.locator('#m5-start-next').click();page.wait_for_timeout(250)
   # Original start confirmation may open a modal. Its actual confirm button is used.
   for i in range(2):
    if page.locator('.game-shell').count():break
    buttons=page.locator('#modal-root button.btn.primary')
    if buttons.count() and not buttons.last.is_disabled():buttons.last.click();page.wait_for_timeout(300)
  game=page.locator('.game-shell').count()>0
  check('有效默认开局可进入游戏',game)
  if game:
   check('移动游戏主导航五个入口',page.locator('#m5-bottom-nav button').count()==5)
   page.screenshot(path=str(root/'jiaye-v5-home-screen.png'),full_page=False);report['screenshots'].append('jiaye-v5-home-screen.png')
   report['checks'].append({'name':'游戏主导航实际文案','passed':True,'detail':page.locator('#m5-bottom-nav').inner_text()})
   page.locator('#m5-bottom-nav button').nth(1).click();page.wait_for_timeout(200)
   check('族人列表可达',page.locator('.member-table tbody tr').count()>0)
   page.screenshot(path=str(root/'jiaye-v5-members-screen.png'),full_page=False);report['screenshots'].append('jiaye-v5-members-screen.png')
   act=page.locator('.member-table tbody tr button').first
   if act.count():
    act.click();page.wait_for_timeout(250)
    check('个人安排详情可打开',page.locator('#modal-root .dialog').count()>0)
    page.screenshot(path=str(root/'jiaye-v5-member-screen.png'),full_page=False);report['screenshots'].append('jiaye-v5-member-screen.png')
    close=page.locator('#modal-root .close').first
    if close.count():close.click();page.wait_for_timeout(150)
   page.locator('#m5-bottom-nav button').nth(2).click();page.wait_for_timeout(200)
   page.screenshot(path=str(root/'jiaye-v5-assets-screen.png'),full_page=False);report['screenshots'].append('jiaye-v5-assets-screen.png')
   page.locator('#m5-bottom-nav button').nth(3).click();page.wait_for_timeout(200)
   page.screenshot(path=str(root/'jiaye-v5-relics-screen.png'),full_page=False);report['screenshots'].append('jiaye-v5-relics-screen.png')
   page.locator('#m5-bottom-nav button').nth(4).click();page.wait_for_timeout(200)
   page.screenshot(path=str(root/'jiaye-v5-history-screen.png'),full_page=False);report['screenshots'].append('jiaye-v5-history-screen.png')
   check('家史次级入口未丢失',page.locator('.m5-subnav button').count()>=2)
   # Navigate all retained history/leadership/ending original controls.
   for label in ['族长','结局','终章']:
    buttons=page.locator('.sidebar .nav button').filter(has_text=label)
    if buttons.count():
     buttons.first.evaluate('(el)=>el.click()');page.wait_for_timeout(200)
     filename='jiaye-v5-'+('leaders' if label=='族长' else 'endings')+'-screen.png'
     page.screenshot(path=str(root/filename),full_page=False)
     if filename not in report['screenshots']:report['screenshots'].append(filename)
  # Responsive setup check in a separate fresh storage context.
  for width in [320,360,430,768,1280]:
   ctx=browser.new_context(viewport={'width':width,'height':900 if width>=768 else 844},device_scale_factor=1)
   p=ctx.new_page();p.goto((root/'jiaye-demo-v5.html').as_uri());p.wait_for_timeout(350)
   vals=p.evaluate('({width:innerWidth,scroll:document.documentElement.scrollWidth})')
   check(str(width)+'px开局无横向溢出',vals['scroll']<=vals['width']+1,vals)
   if width==1280:
    p.screenshot(path=str(root/'jiaye-v5-desktop-screen.png'),full_page=False);report['screenshots'].append('jiaye-v5-desktop-screen.png')
   ctx.close()
  # Verify the self-contained review wrapper contains a functioning frame.
  wrap=browser.new_context(viewport={'width':1440,'height':1050}); wp=wrap.new_page();wp.goto((root/'jiaye-v5-mobile-preview.html').as_uri());wp.wait_for_timeout(500)
  frame=wp.locator('#game').element_handle().content_frame()
  check('独立手机预览壳能运行游戏',bool(frame and frame.locator('.v3-setup').count()))
  wp.screenshot(path=str(root/'jiaye-v5-desktop-preview-screen.png'),full_page=False);report['screenshots'].append('jiaye-v5-desktop-preview-screen.png')
  wrap.close();context.close();browser.close()
  check('浏览器无未捕获JS异常',not report['browser_errors'],report['browser_errors'])
except Exception as e:
 report['incomplete']=str(e);report['traceback']=traceback.format_exc()
finally:
 # Create one contact sheet from real screenshots, only if they exist.
 try:
  from PIL import Image,ImageDraw,ImageFont
  names=[('jiaye-v5-creation-screen.png','01  /  开篇'),('jiaye-v5-home-screen.png','02  /  家族近况'),('jiaye-v5-members-screen.png','03  /  族人'),('jiaye-v5-member-screen.png','04  /  人物安排')]
  selected=[(root/n,t) for n,t in names if (root/n).is_file()]
  if selected:
   count=len(selected);pw=350;gap=24;pad=36;hh=round(pw*844/390);head=92
   canvas=Image.new('RGB',(pad*2+pw*count+gap*(count-1),head+hh+40),'#e9eddf');draw=ImageDraw.Draw(canvas)
   fontpath=next(iter(list(Path('/usr/share/fonts').glob('**/*CJK*.ttc'))+list(Path('/usr/share/fonts').glob('**/*[Ss]ans*.ttf'))),None)
   ft=ImageFont.truetype(str(fontpath),23) if fontpath else ImageFont.load_default()
   for i,(p,title) in enumerate(selected):
    x=pad+i*(pw+gap);img=Image.open(p).convert('RGB');img=img.resize((pw,hh),Image.Resampling.LANCZOS);canvas.paste(img,(x,head));draw.text((x,37),title,font=ft,fill='#526447')
   canvas.save(root/'jiaye-v5-mobile-overview.png')
 except Exception as e:report['montage_error']=str(e)
 persist()
 print(json.dumps(report,ensure_ascii=False,indent=2))
