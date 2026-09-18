from pathlib import Path
import json, math, random, hashlib, re, collections
from PIL import Image, ImageDraw, ImageEnhance
import numpy as np
import cairosvg
R=Path(__file__).resolve().parents[1]
for folder in ['assets/characters','assets/houses','assets/events','assets/relics','assets/icons','assets/ui/buttons','assets/ui/panels','assets/ui/controls','assets/decor','assets/textures','data','docs','previews']: (R/folder).mkdir(parents=True,exist_ok=True)
P={'paper':'#f7f0df','light':'#fff9eb','ink':'#293f37','muted':'#737466','green':'#355c49','select':'#e2e8d8','gold':'#a48b58','line':'#d5c7a7','danger':'#a2533b'}
REG=[]
def pa(d,f='none',s=None,sw=1,ex=''):return f'<path d="{d}" fill="{f}"'+(f' stroke="{s}" stroke-width="{sw}"' if s else '')+f' {ex}/>'
def rc(x,y,w,h,f,s=None,sw=1,r=0,ex=''):return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{f}"'+(f' stroke="{s}" stroke-width="{sw}"' if s else '')+f' {ex}/>'
def el(x,y,rx,ry,f,s=None,sw=1,ex=''):return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{f}"'+(f' stroke="{s}" stroke-width="{sw}"' if s else '')+f' {ex}/>'
def ci(x,y,r,f,s=None,sw=1,ex=''):return el(x,y,r,r,f,s,sw,ex)
def ln(x1,y1,x2,y2,s,sw=1,ex=''):return pa(f'M{x1} {y1} L{x2} {y2}',s=s,sw=sw,ex=ex)
def gp(b,id='',tf='',ex=''):return '<g'+(f' id="{id}"' if id else '')+(f' transform="{tf}"' if tf else '')+f' {ex}>'+b+'</g>'
def svg(b,w,h,defs='',title=''):return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" stroke-linecap="round" stroke-linejoin="round"><title>{title}</title><defs>{defs}</defs>{b}</svg>'
def add(rel,w,h,cat,aid,alpha,usage,safe=None,**meta):REG.append(dict(id=aid,path=rel,width=w,height=h,category=cat,alpha=alpha,usage=usage,safeRect=safe or [0,0,w,h],**meta))
def save(rel,body,w,h,cat,aid,usage='',sizes=(),alpha=True,safe=None,**meta):
 p=R/rel;p.parent.mkdir(exist_ok=True,parents=True);p.write_text(body,encoding='utf8');add(rel,w,h,cat,aid+'.svg',alpha,usage,safe,editable=True,**meta)
 for suffix,ow,oh in sizes:
  dest=p.with_name(p.stem+suffix+'.png');cairosvg.svg2png(bytestring=body.encode(),write_to=str(dest),output_width=ow,output_height=oh)
  ns=[round(safe[0]*ow/w),round(safe[1]*oh/h),round(safe[2]*ow/w),round(safe[3]*oh/h)] if safe else None
  add(str(dest.relative_to(R)),ow,oh,cat,aid+suffix+'.png',alpha,usage,ns,derivedFrom=rel,editable=False,**meta)
def dump(path,obj):(R/path).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
def grain(w,h,seed=2,n=160):
 q=random.Random(seed);return ''.join(el(round(q.uniform(0,w),2),round(q.uniform(0,h),2),round(q.uniform(.3,1.4),2),round(q.uniform(.2,.5),2),'#6a604e',ex=f'opacity="{q.uniform(.02,.06):.3f}"') for _ in range(n))
ARTS=[dict(id='m01',sex='男',robe='#718875',dark='#354d43',accent='#ad9870',eye=-2,jaw=345,anchor='方下颌、平眉、右眼外侧小痣、青灰衣'),dict(id='m02',sex='男',robe='#6f8290',dark='#364e5b',accent='#afa487',eye=1,jaw=353,anchor='长椭圆脸、细长眼、左眉外挑、灰蓝衣'),dict(id='f01',sex='女',robe='#839582',dark='#496b59',accent='#c8bda0',eye=0,jaw=345,anchor='椭圆脸、弯眉、左耳青玉坠、素绿衣'),dict(id='f02',sex='女',robe='#b19d83',dark='#7e6656',accent='#d7b2a0',eye=3,jaw=336,anchor='圆脸、额前碎发、米杏衣')]
STAGES=['infant','child','young','adult','elder']
def portrait(a,st):
 skin='#dfbfa3' if a['id']=='m01' else '#edcdb3';hair='#8b8c80' if st=='elder' else '#303b35';hi='#c5c4b1' if st=='elder' else '#657063'
 if st=='infant':
  s=pa('M146 324 Q101 373 111 495 Q244 527 383 493 Q403 408 361 327 Z',a['robe'],P['ink'],1.8)+pa('M145 340 L344 446 L373 490 M361 341 L148 472 M141 365 L350 478',s=a['dark'],sw=2)
  s+=el(253,275,104,107,skin,P['ink'],1.8)+pa('M152 269 Q133 148 250 151 Q370 160 354 267 Q335 193 283 192 Q221 172 172 234 Z','#354439',P['ink'],1.4)+pa('M237 175 Q239 153 260 151 M247 175 Q260 163 270 166',s='#71826c',sw=2)
  s+=pa('M193 276 Q211 268 227 278 M277 277 Q296 266 313 275',s=P['ink'],sw=2)+el(256,304,4,3,'#bb9277')+pa('M239 333 Q256 343 272 331',s='#a87965',sw=2)+el(197,306,18,9,'#d5a18c',ex='opacity=".22"')+el(309,305,18,9,'#d5a18c',ex='opacity=".22"')
  if a['id']=='m01':s+=ci(326,285,1.8,'#806049')
  return svg(gp(s,'infant'),512,512,title=a['id']+' infant, visual only')
 female=a['sex']=='女';elder=st=='elder';child=st=='child';by=107 if child else 77
 defs=f'<linearGradient id="skin" x1="0" y1="0" x2="1" y2="0"><stop stop-color="{skin}"/><stop offset=".5" stop-color="#f5dcc5"/><stop offset="1" stop-color="{skin}"/></linearGradient><linearGradient id="robe" x1="0" y1="0" x2="1" y2="1"><stop stop-color="{a["robe"]}"/><stop offset="1" stop-color="{a["dark"]}"/></linearGradient>'
 s=gp(pa('M170 178 C147 135 173 88 217 83 C278 44 350 90 350 170 L370 374 Q325 411 315 430 L164 404 Q172 310 151 275 Z',hair,P['ink'],1.8),'hair-back')
 s+=gp(el(257,by,27 if child else 40,22 if child else 32,hair,P['ink'],1.6)+pa(f'M227 {by+3} Q258 {by-24} 287 {by+4} M230 {by+13} Q255 {by-8} 281 {by+14}',s=hi,sw=1.1)+rc(222,by+21,72,8,a['accent'],P['ink'],1.1,3),'knot')
 if female:s+=ln(201,by+24,314,by+8,a['accent'],4)+ci(314,by+8,6,'#91a58b',P['ink'],1)
 s+=gp(pa('M160 365 Q112 377 79 413 L57 512 L454 512 L432 411 Q398 381 345 365 L304 341 L211 342 Z','url(#robe)',P['ink'],2.1),'clothing')
 s+=gp(pa('M218 309 L211 355 L250 392 L301 352 L297 307 Z','url(#skin)',P['ink'],1.3)+pa('M218 326 Q257 356 296 324 L294 349 Q257 367 215 345 Z','#ac8f73',ex='opacity=".28"'),'neck')
 s+=gp(pa('M204 346 L255 381 L313 343 L333 365 L250 464 L177 369 Z','#efe7d2',P['ink'],1.5)+pa('M195 349 L250 400 L321 348 L334 365 L252 472 L238 448 L300 371 L255 412 L181 368 Z',a['accent'],P['ink'],1.2)+pa('M250 465 L316 385 L362 393 L304 512 L258 512 Z',a['dark'],P['ink'],1.2),'collars')
 s+=gp(''.join(pa(d,s='#263d32',sw=1.5,ex='opacity=".52"') for d in ['M116 405 Q137 450 118 512','M147 394 Q172 457 158 498','M358 400 Q328 455 331 512','M399 419 Q375 466 390 512','M165 455 L206 510']),'cloth-folds')
 lo=324 if child else a['jaw']
 s+=gp(el(171,239,16,28,skin,P['ink'],1.3)+el(339,239,15,28,skin,P['ink'],1.3)+pa('M165 227 Q181 236 170 250 M345 227 Q332 237 341 249',s='#a98266',sw=1.2),'ears')
 s+=gp(pa(f'M176 182 Q180 124 253 124 Q326 126 336 179 L329 262 Q319 306 281 {lo-4} Q256 {lo+12} 232 {lo-4} Q188 303 180 263 Z','url(#skin)',P['ink'],1.6)+pa('M325 191 Q323 275 283 323 Q329 308 334 242 Z','#b68e71',ex='opacity=".2"')+el(200,270,23,10,'#cc9a88',ex='opacity=".13"')+el(312,270,22,10,'#cc9a88',ex='opacity=".12"'),'face')
 s+=gp(pa('M169 215 Q163 156 194 119 Q232 85 283 115 Q327 109 343 162 L337 225 L323 187 Q292 175 277 142 Q270 173 242 183 L249 152 Q228 180 186 192 L181 225 Z',hair,P['ink'],1.6),'hair-front')
 s+=gp(''.join(pa(d,s=hi,sw=1.1,ex='opacity=".65"') for d in ['M188 169 Q204 123 248 125','M194 179 Q225 151 251 133','M207 172 Q236 137 262 126','M248 167 Q273 141 270 126','M284 132 Q302 165 321 174','M295 123 Q328 138 333 166','M185 155 Q191 127 217 113']),'hair-lines')
 ey=226 if child else 222;oh=12 if child else 7 if elder else 10;eyes=''
 for side,cx in [(-1,211),(1,299)]:
  up=ey-7+(a['eye'] if side<0 else -a['eye'])/2
  eyes+=pa(f'M{cx-21} {ey+1} Q{cx} {up-6} {cx+20} {ey} Q{cx+4} {ey+oh} {cx-21} {ey+1} Z','#faf0dc',P['ink'],1.5)+el(cx+1,ey+1,6.4,7 if child else 5.7,'#514b36',P['ink'],.8)+el(cx+1,ey+2,3,4,P['ink'])+ci(cx-1,ey-.5,1.5,P['light'])
  eyes+=pa(f'M{cx-23} {ey-17} Q{cx-3} {ey-24-a["eye"]} {cx+22} {ey-18}',s=hair,sw=2.6 if female else 4)+pa(f'M{cx-19} {ey+13} Q{cx} {ey+17} {cx+14} {ey+12}',s='#b8947b',sw=.9)
 s+=gp(eyes,'eyes-brows')+gp(pa('M257 230 Q250 248 250 266 L259 271 M246 273 Q254 277 264 273',s='#a77e66',sw=1.2)+pa('M237 294 Q254 298 274 292 Q257 305 241 299','#b47b6b',ex='opacity=".45"')+pa('M238 295 Q255 294 272 293',s='#875e53',sw=1.2)+pa('M246 314 Q257 317 268 311',s='#b38f77',sw=.9),'nose-mouth')
 if female and st=='adult':s+=gp(pa('M186 235 Q195 243 201 242 M316 239 L326 243 M228 278 Q223 286 226 292 M282 278 Q289 284 287 291',s='#bb9980',sw=.8),'adult-face-lines')
 if a['id']=='m01':s+=ci(324,247,1.8,'#735943')
 if a['id']=='m02':s+=pa('M198 199 L224 195',s=hair,sw=2.2)
 if female:s+=ln(173,260,173,280,P['gold'],1.4)+el(173,286,4.5,7,'#779583',P['ink'],.8)+pa('M174 196 Q152 260 189 339 M332 184 Q359 270 324 342',s=hair,sw=7)
 if not female and st in ['adult','elder']:
  beard='#aaa899' if elder else '#465046'
  if a['id']=='m01':
   s+=pa('M233 286 Q243 278 253 286 L260 284 Q271 278 280 283 Q266 297 257 291 Q244 298 233 286 Z',beard)+pa('M222 319 Q256 342 287 318 Q275 358 254 374 Q232 352 222 319 Z',beard)
   s+=''.join(pa(f'M{x} 331 Q{x+5} 350 255 366',s=hi,sw=1) for x in [233,242,251,263,275])
  else:s+=pa('M238 286 Q254 279 273 285 M249 323 Q255 332 263 321',s=beard,sw=2.7)
 if elder:s+=gp(''.join(pa(d,s='#a78971',sw=1.15) for d in ['M184 231 L176 228','M189 239 L178 241','M326 231 L337 230','M326 239 L337 244','M233 276 Q220 284 224 302','M278 272 Q289 283 287 302','M212 193 Q253 184 299 193','M219 185 Q251 178 287 186','M207 256 Q212 260 225 257','M287 257 Q300 263 312 257']),'age-lines')
 return svg(s,512,512,defs,title=a['id']+' '+st+'; original editable portrait')
LIB={}
for a in ARTS:
 aid='portrait_'+a['id'];LIB[aid]={'sexPresentation':a['sex'],'identityAnchors':a['anchor'],'stages':{}}
 for st in STAGES:
  base=f'assets/characters/{aid}/{st}';save(base+'_detail.svg',portrait(a,st),512,512,'character',aid+'.'+st,'人物详情透明源；不含姓名或游戏属性。',sizes=[('',768,768)],safe=[50,40,412,472],artId=aid,ageStage=st)
  raw=Image.open(R/(base+'_detail.png')).convert('RGBA');detailStates={}
  for status in ['sick','deceased']:
   toned=ImageEnhance.Color(raw.convert('RGB')).enhance(.25 if status=='sick' else 0);toned=Image.blend(toned,Image.new('RGB',raw.size,'#bfc7b3' if status=='sick' else P['paper']),.13 if status=='sick' else .17).convert('RGBA');toned.putalpha(raw.getchannel('A'))
   rel=base+'_detail_'+status+'.png';toned.save(R/rel);detailStates['detail_'+status]=rel;add(rel,768,768,'character-state',aid+'.'+st+'.detail.'+status,True,'同一原画色阶衍生；不重新生成脸。',artId=aid,ageStage=st,state=status,derivedFrom=base+'_detail.svg')
  bg=Image.new('RGBA',raw.size,P['paper']);bg.alpha_composite(raw);bg=bg.resize((256,256),Image.Resampling.LANCZOS);mask=Image.new('L',(1024,1024));ImageDraw.Draw(mask).ellipse((8,8,1016,1016),fill=255);mask=mask.resize((256,256),Image.Resampling.LANCZOS);bg.putalpha(mask)
  for status in ['normal','sick','deceased','selected']:
   im=bg.copy()
   if status in ['sick','deceased']:
    al=im.getchannel('A');im=ImageEnhance.Color(im.convert('RGB')).enhance(.25 if status=='sick' else 0);im=Image.blend(im,Image.new('RGB',im.size,'#bfc7b3' if status=='sick' else P['paper']),.13 if status=='sick' else .17).convert('RGBA');im.putalpha(al)
   if status=='selected':
    d=ImageDraw.Draw(im);d.ellipse((3,3,252,252),outline=P['gold'],width=5);d.ellipse((10,10,245,245),outline=P['green'],width=2)
   rel=base+'_'+status+'_256.png';im.save(R/rel);add(rel,256,256,'character-state',aid+'.'+st+'.'+status,True,'圆形头像；状态色阶/边框，不改美术身份。',artId=aid,ageStage=st,state=status,derivedFrom=base+'_detail.svg')
  LIB[aid]['stages'][st]={'detail':base+'_detail.png','source':base+'_detail.svg',**detailStates,**{k:base+'_'+k+'_256.png' for k in ['normal','sick','deceased','selected']}}

def mountains(w=1200,h=560,seed=2):
 q=random.Random(seed);s=''
 for n,(base,col,op) in enumerate([(365,'#b9c5b9',.33),(385,'#9eafa3',.35),(414,'#809988',.25)]):
  if h<560:base=int(base*h/560)
  pts=[(-40,base)]+[(x,base-q.randint(50,180)+n*24) for x in range(0,w+140,95)]
  s+=pa('M-40 '+str(h)+' L'+' L'.join(f'{x} {y}' for x,y in pts)+f' L{w+100} {h} Z',col,ex=f'opacity="{op}"')
  for x,y in pts[2:-1]:s+=pa(f'M{x} {y+5} Q{x-17} {y+63} {x-36} {base+3}',s='#788f7d',ex='opacity=".25"')
 return s

def tree(x,y,sc=1,seed=4):
 q=random.Random(seed);s=pa('M0 0 C12 -64 0 -145 42 -202 L57 -232 L49 -207 Q74 -242 108 -247 Q82 -231 64 -206 L72 -165 Q115 -184 155 -181 Q98 -169 68 -139 L44 -104 L40 -55 L55 0 Z','#8e8a71',P['ink'],2)+pa('M10 -12 Q34 -65 30 -118 Q22 -168 53 -211 M35 -90 Q58 -116 67 -162',s='#b5b49a',sw=3)
 for j in range(42):
  cx=q.gauss(63,68);cy=q.gauss(-219,27);rr=q.uniform(13,35);s+=el(round(cx,1),round(cy,1),round(rr,1),round(rr*.65,1),q.choice(['#819886','#607c69','#aab39a','#456653']),ex=f'opacity="{q.uniform(.34,.70):.2f}"')
 return gp(s,tf=f'translate({x} {y}) scale({sc})')

def building(x,y,w=450,h=210,kind='simple',state='normal',sc=1):
 wall='#c2aa7e' if kind in ['simple','rented'] else '#e5dcc2';wood='#72644b';roof='#a79669' if kind=='rented' else '#6f8174'
 b=rc(0,-h,w,h,wall,P['ink'],2)+pa(f'M{w} 0 L{w+65} -25 L{w+65} {-h-22} L{w} {-h} Z','#b3a78a',P['ink'],1.6)+rc(-12,-10,w+27,15,'#9a9580',P['ink'],1.3)
 for xx,yy,ww,hh in [(12,-h+17,105,40),(w-123,-80,97,64),(w*.52,-h+10,88,32)]:b+=pa(f'M{xx} {yy} l{ww} 6 l-12 {hh} l{-ww+14} -4 Z','#ac9e7c',ex='opacity=".16"')
 for xx in [6,w*.31,w*.69,w-12]:b+=rc(xx,-h+10,10,h-10,wood,P['ink'],1)
 dw=w*.18;dx=w*.43-dw*.2;dy=-h*.69;b+=rc(dx,dy,dw,-dy,'#5d5946',P['ink'],1.5)+ln(dx+dw/2,dy,dx+dw/2,0,'#a79972',1.5)+ci(dx+dw*.43,-h*.23,3,P['gold'])+ci(dx+dw*.57,-h*.23,3,P['gold'])
 for wx in [w*.08,w*.75]:
  wy=-h*.69;ww=w*.16;hh=h*.35;b+=rc(wx,wy,ww,hh,'#abb69b',P['ink'],2)
  for j in range(1,5):b+=ln(wx+ww*j/5,wy,wx+ww*j/5,wy+hh,wood,1.5)
  for j in range(1,4):b+=ln(wx,wy+hh*j/4,wx+ww,wy+hh*j/4,wood,1.2)
 ry=-h;pk=-h-112;roofpath=f'M-39 {ry+12} Q15 {ry-4} 66 {pk+15} Q{w*.45} {pk+27} {w-34} {pk-3} Q{w+9} {ry-15} {w+51} {ry+2} L{w+39} {ry+26} Q{w*.5} {ry+6} -39 {ry+30} Z'
 b+=pa(roofpath,roof,P['ink'],2.7)+pa(f'M66 {pk+15} Q{w*.45} {pk+27} {w-34} {pk-3}',s='#334e41',sw=8)
 tiles=''
 for j in range(23):
  t=j/22;xx=65+(w-100)*t;ex=-29+(w+70)*t;yy=pk+13-14*t
  tiles+=pa(f'M{xx:.1f} {yy:.1f} Q{(xx+ex)/2:.1f} {ry-17} {ex:.1f} {ry+12}',s='#786d4c' if kind=='rented' else '#455e4e',sw=1.5)+pa(f'M{xx+4:.1f} {yy+3:.1f} Q{(xx+ex)/2+4:.1f} {ry-16} {ex+4:.1f} {ry+10}',s='#d0ceb0',sw=.8,ex='opacity=".72"')
 b+=tiles
 for j in range(1,4):
  yy=pk+27+j*21;b+=pa(f'M{55-j*19} {yy} Q{w*.5} {yy+12} {w-23+j*16} {yy-5}',s='#364f42',ex='opacity=".58"')
 b+=ln(-25,ry+30,w+37,ry+25,wood,7)
 if state=='damaged':b+=pa(f'M{w*.28} {pk+37} l42 15 l-15 47 l-59 -3 Z','#343f33',P['ink'],1.5)+pa(f'M{w*.21} -80 l16 12 l-9 17 l11 16 l-5 26 M{w*.8} -100 l-11 19 l16 25',s='#756349',sw=2)+pa('M50 -10 l40 12 l-7 5 l-34 -8 Z',roof,P['ink'],1)+ln(w-49,-35,w-19,-10,wood,5)
 if state=='upgraded':
  b+=rc(-25,0,w+51,8,'#ada58b',P['ink'],1.2)+rc(-37,8,w+78,8,'#bbb39a',P['ink'],1.2)
  for xx in [-13,w+16]:b+=ln(xx,ry+22,xx,-20,wood,3)+el(xx,-h*.68,13,18,'#c2a56d',P['ink'],1.2)+ln(xx,-h*.59,xx,-h*.50,P['gold'],2)
 return gp(b,tf=f'translate({x} {y}) scale({sc})')

def house(kind,state):
 b=gp(rc(0,0,1200,560,P['paper']),'paper')+gp(mountains(seed=15 if state=='relocated' else 6),'mountains')+gp(pa('M0 447 Q296 405 503 447 Q767 494 1200 426 L1200 560 L0 560 Z','#dce0ca')+pa('M0 490 Q293 452 566 491 Q849 526 1200 474 L1200 560 L0 560 Z','#c9d0b5',ex='opacity=".5"'),'ground')
 if state=='relocated':b+=gp(pa('M0 385 Q241 425 318 488 Q208 468 0 447 Z','#9eb7af',ex='opacity=".7"')+pa('M0 399 Q205 434 258 467',s='#edf0dc',sw=3),'river')
 b+=gp(tree(990,465,.91,7)+tree(94,460,.63,1),'trees')+gp(pa('M116 424 L113 374 L416 342 L1077 384 L1074 443 Z','#d0cbb3',P['ink'],1.3)+pa('M106 371 L413 337 L1080 379 L1080 386 L113 379 Z','#718474',P['ink'],1.3),'wall')
 x,y,w,h={'rented':(318,423,430,138),'simple':(310,438,469,160),'courtyard':(337,416,480,190),'estate':(367,387,453,202)}[kind]
 if kind=='courtyard':b+=gp(building(120,454,225,128,kind,state)+building(897,452,201,128,kind,state,.9),'wings')
 if kind=='estate':b+=gp(building(142,421,262,174,kind,state,.86)+building(838,420,265,178,kind,state,.88),'wings')
 b+=gp(building(x,y,w,h,kind,state),'main-house')
 if kind=='estate':b+=gp(pa('M285 484 L285 421 L890 421 L890 484 Z','#e0d6b6',P['ink'],1.5)+rc(539,431,105,53,'#665e46',P['ink'],1.6)+pa('M273 422 Q328 401 354 387 L823 387 Q855 410 901 421 Z','#667e6c',P['ink'],2),'court')
 b+=gp(pa('M545 560 L562 446 L636 446 L713 560 Z','#e8e1ca',P['line'],1)+''.join(ln(552-i*7,470+i*22,652+i*13,470+i*22,'#bfb89e') for i in range(4)),'path')
 p=el(244,449,21,29,'#92816b',P['ink'],1.4)+el(244,424,19,5,'#554e3e',P['ink'],1.4)+''.join(ln(826+i*7,442,867+i*7,431,'#9d845a',5) for i in range(5));q=random.Random(38)
 for _ in range(55):
  xx=q.randint(45,1148);yy=q.randint(445,545)
  if not 548<xx<710:p+=pa(f'M{xx} {yy} l-3 -9 M{xx} {yy} l5 -13',s='#899673',sw=1.3,ex='opacity=".7"')
 if state=='relocated':p+=rc(884,447,54,33,'#a9986f',P['ink'],1.5)+pa('M930 481 L998 481 L977 450 L938 450 Z','#968766',P['ink'],1.4)+ci(947,485,11,'#695f46',P['ink'],1.3)+ci(986,485,11,'#695f46',P['ink'],1.3)
 b+=gp(p,'props')+gp(grain(1200,560,17,440),'paper-grain');return svg(b,1200,560,title=f'Jiaye {kind} {state}; layered vector scene')
HOUSES={}
for k in ['rented','simple','courtyard','estate']:
 HOUSES[k]={}
 for st in ['normal','damaged','upgraded','relocated']:
  rel=f'assets/houses/{k}_{st}.svg';save(rel,house(k,st),1200,560,'house',f'house.{k}.{st}','家宅状态完整横图；不透明米白底，不决定资产或游戏规则。',sizes=[('',1200,560)],alpha=False,safe=[75,55,1050,475],homeId=k,state=st);HOUSES[k][st]=rel.replace('.svg','.png')

def herbs():
 b=''
 for rot in [-45,-15,15,42]:
  p=pa('M0 0 Q-3 -50 0 -98',s='#66734e',sw=2.4)
  for i in range(3):
   y=-20-i*23;p+=pa(f'M0 {y} Q-37 {y-3} -28 {y-22} Q-7 {y-25} 0 {y} Z','#7e9267',P['ink'],.7)+pa(f'M0 {y-10} Q30 {y-38} 37 {y-24} Q29 {y-5} 0 {y-10} Z','#93a478',P['ink'],.7)
  b+=gp(p,tf=f'rotate({rot})')
 return b

def book(k='book'):
 cover={'book':'#586e64','newbook':'#6f8166','notes':'#9c8462'}.get(k,'#637568');b=pa('M110 356 L283 387 L407 162 L226 130 Z','#e9dab9',P['ink'],2)
 for i in range(4):b+=pa(f'M116 {348-i*5} L280 {379-i*5} L402 {157-i*3}',s='#ae9e7c')
 b+=pa('M108 340 L281 372 L399 147 L225 116 Z',cover,P['ink'],2.3)+pa('M127 340 L298 134',s='#d5c7a6',sw=2)
 for t in range(5):
  x=210-t*18;y=152+t*35;b+=pa(f'M{x} {y} l12 2 l8 -9',s='#e1d3b0',sw=2)
 b+=pa('M254 139 L288 145 L229 259 L196 251 Z','#e9dfc1',P['ink'],1)
 for x,y in [(259,161),(249,180),(239,200),(229,221)]:b+=pa(f'M{x-3} {y} l10 2 m-7 -5 l-4 11',s='#7a8063')
 if k=='book':b+=pa('M304 357 l-8 -26 l24 -10 l8 -20',s='#cab997',sw=2)
 if k=='newbook':b+=pa('M176 276 L318 294 L298 326 L156 311 Z','#9c6656',P['ink'],1.1)
 if k=='notes':b+=gp(herbs(),tf='translate(235 323) scale(.35)')
 return b

def ruler():
 b=pa('M65 322 L410 164 L437 209 L91 365 Z','#ae8c52',P['ink'],2.2)+pa('M92 355 L430 205',s='#d2b677',sw=3)
 for i in range(22):
  x=82+i*14.8;y=319-i*6.78;b+=ln(x,y,x+(10 if i%5==0 else 6),y+(19 if i%5==0 else 11),'#5d5639',1.5)
 return b+pa('M131 340 Q157 319 197 319 M272 271 Q320 244 392 223',s='#796440',ex='opacity=".7"')+pa('M350 226 l11 -20 l17 7 l-10 17 Z',s='#5e583e',sw=2)
def letter():return pa('M121 156 L403 186 L368 376 L84 342 Z','#e7d8b5',P['ink'],2)+pa('M121 156 L240 282 L403 186 M84 342 L226 263 M368 376 L259 276',s='#ae9873',sw=1.8)+ci(240,280,19,P['danger'],P['gold'],1)+pa('M228 275 L249 278 M232 268 L232 289 M245 271 L241 288',s='#f1d8b5',sw=1.4)+pa('M284 151 L323 120 L390 145 L385 184 Z','#f4e8cf',P['ink'],1)
def jade():return pa('M236 150 A108 108 0 0 1 347 300 L261 273 L287 242 L255 222 L273 196 L233 184 Z','#809e8b',P['ink'],2.2)+pa('M260 167 Q318 185 326 242 M325 267 Q310 258 293 258',s='#bbcbad',sw=4)+ci(274,170,7,'#e4dbc1',P['ink'],1.3)+pa('M274 168 Q202 104 178 180 Q189 215 253 166',s='#a5785f',sw=4)+pa('M275 168 Q223 130 207 156',s='#d1ac85',sw=1.5)+pa('M334 218 Q323 207 310 219 Q300 233 315 239',s='#567661',sw=1.5)
def plan():return pa('M74 199 L370 122 L441 323 L138 401 Z','#e8dbb8',P['ink'],1.8)+pa('M77 197 Q49 208 68 227 L143 413 Q163 427 165 404 Z','#c6b086',P['ink'],1.8)+pa('M367 120 Q389 110 396 129 L463 312 Q465 334 441 326 Z','#bba279',P['ink'],1.8)+pa('M157 292 L236 208 L340 242 L266 323 Z M183 275 L231 251 L266 262 L299 247 M236 208 L236 280 M266 323 L266 263',s='#768877',sw=2)+pa('M156 327 L206 300 M284 193 L354 211 M284 207 L358 223',s='#9b9b79',sw=1.5)
def brush():return pa('M119 350 L367 135 L382 151 L135 366 Z','#84694b',P['ink'],1.8)+pa('M119 350 Q89 358 78 399 Q123 388 135 366 Z','#384a3d',P['ink'],1.5)+ln(154,345,370,148,'#ba9b68',2)
def bowl():
 b=pa('M112 243 Q135 370 263 366 Q379 364 408 243 Z','#a39470',P['ink'],2.1)+el(260,243,148,44,'#e6d8b9',P['ink'],2)+el(260,242,133,32,'#847652',P['ink'],1.1);q=random.Random(90)
 for _ in range(60):
  x=q.gauss(261,67);y=q.gauss(243,15)
  if ((x-260)/128)**2+((y-243)/29)**2<1:b+=el(round(x,2),round(y,2),5,2.5,'#d8c491',ex=f'transform="rotate({q.randint(-50,50)} {x} {y})"')
 return b+pa('M161 307 Q258 344 357 300',s='#c6b68e',sw=2)
def lantern():return ln(252,93,252,155,'#7c6a4d',3)+el(252,250,88,102,'#c7a06b',P['ink'],2)+pa('M165 250 L339 250 M252 149 L252 352 M211 160 Q183 254 211 339 M293 160 Q323 254 293 338',s='#987644',sw=1.5)+rc(207,147,92,17,'#816c46',P['ink'],1)+rc(210,340,86,15,'#816c46',P['ink'],1)+pa('M230 355 L233 397 M252 355 L252 401 M274 355 L271 397',s=P['danger'],sw=3)
PROPS={'ruler':ruler,'book':book,'letter':letter,'plan':plan,'newbook':lambda:book('newbook'),'jade':jade,'notes':lambda:book('notes')}
for id,fn in PROPS.items():save(f'assets/relics/{id}.svg',svg(gp(fn(),'object'),512,512,title='Jiaye relic '+id),512,512,'relic','relic.'+id,'信物本体透明图；不含玩家姓名和收益文案。',sizes=[('',512,512)],safe=[45,85,425,355],relicId=id)
EVENTS={'ruler':'木尺旧匠号','book':'族谱缺页','letter':'家书旧约','medical':'医案与问诊','repair':'修缮营造','neighbors':'邻里互助','school':'求学应试','roof':'风雨屋顶','jade':'故人玉佩','reunion':'旁支归家','leadership':'族长交接','migration':'迁居新址'}
def event(id):
 b=rc(0,0,1200,560,P['paper'])
 if id in ['repair','roof','migration']:
  b+=gp(mountains(seed=22),'mountains')+gp(tree(1052,459,.7,19),'tree')+gp(building(384,463,484,198,'courtyard','damaged' if id=='roof' else 'normal'),'house')
  if id=='roof':
   b+=rc(0,0,1200,560,'#7e9991',ex='opacity=".18"')
   for x in range(20,1200,48):b+=ln(x,40+x%83,x-95,350+x%127,'#94a39b',1.3,ex='opacity=".42"')
   b+=pa('M426 510 Q667 527 880 503',s='#adc3b4',sw=5)
  elif id=='repair':
   for x in [306,371]:b+=ln(x,480,x+95,166,'#826c48',8)
   for j in range(8):b+=ln(313+j*11,466-j*38,378+j*11,466-j*38,'#ad9769',6)
   b+=gp(plan(),tf='translate(90 192) scale(.70)')
  else:b+=pa('M0 503 Q335 448 602 484 Q920 521 1200 442 L1200 560 H0 Z','#d7caad')+gp(rc(80,324,193,117,'#c5ae7e',P['ink'],2)+rc(100,281,80,63,'#9d8c61',P['ink'],2)+rc(183,299,91,42,'#ded0a8',P['ink'],2)+ci(115,453,31,'#8a7854',P['ink'],2.2)+ci(252,453,31,'#8a7854',P['ink'],2.2)+ln(279,421,339,396,P['ink'],5),'cart')
 else:
  b+=gp(pa('M0 357 Q511 329 1200 353 L1200 560 H0 Z','#d8c7a1')+pa('M0 385 Q477 365 1200 385 M0 466 Q527 448 1200 468',s='#b7a780',sw=1.5),'table')
  b+=gp(rc(882,40,228,266,'#dae0c8',P['ink'],2)+''.join(ln(x,40,x,307,'#9a8d6b',4) for x in [892,950,1008,1066,1110])+''.join(ln(883,y,1110,y,'#9a8d6b',3) for y in [104,170,237]),'window')
  if id=='ruler':b+=gp(ruler(),tf='translate(161 95) scale(1.12)')+gp(book(),tf='translate(538 148) scale(.70)')+gp(brush(),tf='translate(680 102) scale(.64)')
  elif id=='book':b+=gp(book(),tf='translate(326 93) scale(1.11)')+gp(letter(),tf='translate(96 159) scale(.72)')
  elif id=='letter':b+=gp(letter(),tf='translate(245 75) scale(1.10)')+gp(brush(),tf='translate(651 180) scale(.73)')
  elif id=='medical':b+=gp(book('notes'),tf='translate(340 75) scale(.99)')+gp(herbs(),tf='translate(875 404) scale(1.5)')+gp(bowl(),tf='translate(73 205) scale(.68)')
  elif id=='neighbors':b+=gp(bowl(),tf='translate(314 88) scale(1.12)')+pa('M0 403 L266 387 L350 427 L336 451 L260 425 L0 465 Z','#899e8b',P['ink'],2)+pa('M263 390 Q314 382 355 406 L390 426 L384 441 Q357 447 331 428 L280 424 Z','#debda0',P['ink'],1.6)+pa('M1200 416 L886 408 L842 440 L906 470 L1200 489 Z','#b29c80',P['ink'],2)+pa('M887 409 Q844 391 810 416 L782 437 Q793 460 833 446 L886 444 Z','#e5c5a8',P['ink'],1.5)
  elif id=='school':b+=gp(book('newbook'),tf='translate(295 68) scale(1.03)')+gp(brush(),tf='translate(578 31) scale(.82)')+gp(book(),tf='translate(14 227) scale(.64)')
  elif id=='jade':b+=gp(jade(),tf='translate(369 101) scale(.95)')+gp(letter(),tf='translate(132 159) scale(.71)')
  elif id=='reunion':b+=gp(book('newbook'),tf='translate(380 101) scale(.95)')+gp(lantern(),tf='translate(64 37) scale(.64)')
  elif id=='leadership':b+=gp(book('newbook'),tf='translate(443 106) scale(.89)')+gp(lantern(),tf='translate(122 25) scale(.84)')+rc(766,400,63,38,P['danger'],P['ink'],1.2)+rc(782,377,34,30,'#b98e63',P['ink'],1.2)
 return svg(b+gp(grain(1200,560,33,400),'paper-grain'),1200,560,title='Jiaye event '+id)
for id,title in EVENTS.items():save(f'assets/events/{id}.svg',event(id),1200,560,'event','event.'+id,title+'。事件卡顶图，无正文或按钮。',sizes=[('',1200,560)],alpha=False,safe=[110,45,980,465],eventArtId=id)
# UI icons, consistent 24-unit line system
S='COLOR';ICONS={
'family':pa('M3 10 L12 3 L21 10 M5 9 V21 H19 V9 M10 21 V15 H14 V21 M8 9 H16',s=S,sw=1.65),
'people':ci(12,7,3.4,'none',S,1.65)+pa('M5 21 V17 Q5 12 12 12 Q19 12 19 17 V21 M3 10 Q1 12 2 16 M21 10 Q23 12 22 16',s=S,sw=1.65),
'estate':pa('M3 9 H21 L18 4 H6 Z M5 9 V21 H19 V9 M9 21 V14 H15 V21 M2 21 H22',s=S,sw=1.65),
'relics':pa('M4 9 H20 V21 H4 Z M3 9 L6 4 H18 L21 9 M4 14 H20 M10 12 H14 V16 H10 Z',s=S,sw=1.65),
'history':pa('M6 3 H20 V21 H6 Q3 21 3 18 V6 Q3 3 6 3 Z M7 3 V21 M11 8 H16 M11 12 H16 M11 16 H16',s=S,sw=1.65),
'money':el(9,8,6,3,'none',S,1.65)+pa('M3 8 V12 C3 16 15 16 15 12 V8 M4 15 V18 C4 22 18 22 18 18 V13 M15 7 Q22 8 22 12 V16 Q22 19 18 19',s=S,sw=1.65),
'grain':pa('M6 21 Q12 15 17 3 M10 16 Q3 16 6 11 Q11 10 11 15 M13 12 Q7 10 11 6 Q15 6 14 10 M15 9 Q22 11 21 6 Q18 3 16 7 M9 18 Q16 21 17 16 Q15 13 11 16',s=S,sw=1.65),
'land':pa('M6 4 H18 L22 20 H2 Z M4 12 H20 M12 4 V20 M5 8 L10 8 M14 16 H19',s=S,sw=1.65),
'relationship':ci(12,5,3,'none',S,1.65)+ci(5,19,3,'none',S,1.65)+ci(19,19,3,'none',S,1.65)+pa('M10 8 L6 16 M14 8 L18 16 M8 19 H16',s=S,sw=1.65),
'lock':rc(5,10,14,11,'none',S,1.65,2)+pa('M8 10 V6 A4 4 0 0 1 16 6 V10 M12 14 V17',s=S,sw=1.65),
'unlock':rc(5,10,14,11,'none',S,1.65,2)+pa('M8 10 V6 A4 4 0 0 1 16 6 M12 14 V17',s=S,sw=1.65),
'back':pa('M14 5 L7 12 L14 19 M7 12 H21',s=S,sw=1.65),
'forward':pa('M10 5 L17 12 L10 19 M3 12 H17',s=S,sw=1.65),
'random':rc(3,3,18,18,'none',S,1.65,3)+''.join(ci(x,y,1,S) for x,y in [(7,7),(17,7),(12,12),(7,17),(17,17)]),
'edit':pa('M4 17 L4 21 L8 20 L21 7 L17 3 Z M14 6 L18 10 M4 17 L8 20',s=S,sw=1.65),
'close':pa('M6 6 L18 18 M18 6 L6 18',s=S,sw=1.65),
'check':pa('M4 12 L9 17 L20 6',s=S,sw=1.9),
'plus':pa('M12 4 V20 M4 12 H20',s=S,sw=1.65),
'minus':pa('M4 12 H20',s=S,sw=1.65),
'info':ci(12,12,9,'none',S,1.65)+pa('M12 11 V17 M12 7 V7.1',s=S,sw=1.8),
'warning':pa('M12 3 L22 21 H2 Z M12 9 V14 M12 17 V17.2',s=S,sw=1.65),
'year':rc(3,5,18,16,'none',S,1.65,2)+pa('M7 2 V7 M17 2 V7 M3 10 H21 M7 14 H11 M14 14 H17 M7 18 H11',s=S,sw=1.65),
'save':pa('M4 3 H17 L21 7 V21 H3 V3 Z M7 3 V10 H17 V3 M7 21 V14 H17 V21',s=S,sw=1.65),
'search':ci(10,10,6.5,'none',S,1.65)+pa('M15 15 L21 21',s=S,sw=1.8),
'leader':pa('M4 9 L8 13 L12 5 L16 13 L20 9 L18 20 H6 Z M7 17 H17',s=S,sw=1.65),
'sick':pa('M8 4 Q11 1 14 4 L20 10 Q23 13 20 16 L16 20 Q13 23 10 20 L4 14 Q1 11 4 8 Z M7 17 L17 7 M9 9 H9.1 M12 12 H12.1 M15 15 H15.1',s=S,sw=1.65),
'deceased':pa('M7 3 H17 V21 H7 Z M10 7 H14 M10 11 H14 M5 21 H19 M12 15 V18',s=S,sw=1.65),
'house':pa('M2 11 L12 3 L22 11 M5 10 V21 H19 V10 M9 21 V14 H15 V21 M7 8 H17',s=S,sw=1.65),
'restore':pa('M5 8 A8 8 0 1 1 4 15 M5 3 V8 H10',s=S,sw=1.65),
'more':''.join(ci(x,12,1.6,S) for x in [5,12,19]),
'loading':pa('M21 12 A9 9 0 1 1 12 3',s=S,sw=1.65)
}
for id,shape in ICONS.items():
 for v,col in [('ink',P['ink']),('paper',P['light']),('muted','#858579')]:save(f'assets/icons/{id}_{v}.svg',svg(gp(shape.replace(S,col),'icon'),24,24,title=id+' '+v),24,24,'icon','icon.'+id+'.'+v,'24逻辑画布，实际热区另设44；浅/深/弱化版本。',sizes=[('@1x',24,24),('@2x',48,48),('@3x',72,72)],safe=[1,1,22,22],iconId=id,colorVariant=v)
def corner(x,y,sx=1,sy=1,col=None):return gp(pa('M0 18 V0 H18 M4 13 V4 H13 M0 8 H8 V0',s=col or P['gold']),tf=f'translate({x} {y}) scale({sx} {sy})')
STATES=['default','pressed','selected','disabled','focus','confirm','busy']
for role in ['primary','secondary','danger']:
 for st in STATES:
  fill=P['green'] if role=='primary' else P['light'] if role=='secondary' else P['danger'];border=P['gold'];inner=P['line'] if role=='secondary' else '#97aa85'
  if st=='pressed':fill={'primary':'#264738','secondary':'#e9dec4','danger':'#813e2d'}[role]
  if st=='selected':fill=P['select'] if role=='secondary' else '#426b52' if role=='primary' else '#974936'
  if st=='disabled':fill='#dfddcf';border='#b9b7a7';inner='#c9c6b6'
  if st=='confirm':border='#a99251';inner='#cfb677'
  b=gp(rc(2,3,236,91,'#142b21',r=4,ex='opacity=".055"'),'shadow')+gp(rc(1.5,1.5,237,92,fill,border,1.5,3)+rc(5.5,5.5,229,84,'none',inner,1,1),'frame')+gp(''.join(corner(x,y,sx,sy,border) for x,y,sx,sy in [(6,6,1,1),(234,6,-1,1),(6,88,1,-1),(234,88,-1,-1)]),'corners')
  if st=='focus':b+=gp(rc(9,9,222,78,'none',P['light'] if role!='secondary' else P['green'],1.5,1,ex='stroke-dasharray="4 3"'),'focus')
  save(f'assets/ui/buttons/{role}_{st}.svg',svg(b,240,96,title=role+' '+st+' button skin, no text'),240,96,'ui',f'button.{role}.{st}','无文字按钮皮肤；图标单独叠加，使用九宫格。',sizes=[('@2x',480,192)],safe=[38,18,164,60],nineSlice=[18,18,18,18],role=role,state=st)
for st in ['default','selected','disabled','danger','confirmation']:
 border=P['gold'] if st in ['selected','confirmation'] else P['danger'] if st=='danger' else P['line'];fill=P['select'] if st=='selected' else '#e9e6d9' if st=='disabled' else P['light']
 b=rc(2,3,356,194,'#24392f',r=10,ex='opacity=".05"')+rc(1,1,358,196,fill,border,1.2,10)+rc(6,6,348,186,'none',P['line'],.8,6)
 save(f'assets/ui/panels/{st}.svg',svg(gp(b,'panel'),360,200),360,200,'ui','panel.'+st,'纸面内容容器；文字及交互独立。',sizes=[('@2x',720,400)],safe=[20,20,320,160],nineSlice=[16,16,16,16],state=st)
for st in ['selected','leader','sick','deceased','focus']:
 if st=='selected':b=ci(128,128,120,'none',P['gold'],4)+ci(128,128,113,'none',P['green'],1.5)
 elif st=='focus':b=ci(128,128,118,'none',P['ink'],2,ex='stroke-dasharray="5 6"')
 else:
  col=P['gold'] if st=='leader' else '#829174' if st=='sick' else '#777769';b=ci(211,211,32,P['light'],col,2)+gp(ICONS[st].replace(S,col),tf='translate(192 192) scale(1.6)')
 save(f'assets/ui/portrait_{st}.svg',svg(gp(b,'overlay'),256,256),256,256,'ui','portrait-overlay.'+st,'透明状态层；可与病弱/已故头像共同叠加，不换脸。',sizes=[('',256,256)],state=st)
for family in ['checkbox','radio','toggle','input']:
 for st in (['off','on','disabled'] if family=='toggle' else ['default','selected','disabled','invalid']):
  fill=P['select'] if st in ['selected','on'] else P['light'];border=P['danger'] if st=='invalid' else '#aaa997' if st=='disabled' else P['gold']
  if family=='input':
   w,h=320,48;b=rc(1,1,318,46,fill,border,1.4,4)
   if st=='selected':b+=rc(4,4,312,40,'none',P['green'],1,2)
  elif family=='toggle':w,h=52,32;b=rc(2,4,48,24,P['green'] if st=='on' else '#d9d5c4',border,1,12)+ci(37 if st=='on' else 15,16,9,P['light'],P['line'],.7)
  elif family=='checkbox':
   w=h=32;b=rc(3,3,26,26,fill,border,1.5,4)
   if st=='selected':b+=pa('M9 16 L14 21 L24 10',s=P['green'],sw=2)
   if st=='disabled':b+=pa('M10 16 H22',s='#aaa997',sw=1.5)
  else:
   w=h=32;b=ci(16,16,13,fill,border,1.5)
   if st=='selected':b+=ci(16,16,6,P['green'])
   if st=='disabled':b+=ci(16,16,4,'#bbb7a6')
  save(f'assets/ui/controls/{family}_{st}.svg',svg(gp(b,'control'),w,h),w,h,'ui',f'control.{family}.{st}','表单控件皮肤；选中/禁用必须由实际控件实现。',sizes=[('@2x',w*2,h*2)],state=st,control=family)
DECOR=['mountains','tree','bamboo','clouds','paper_edge','divider','corner','seal_square','seal_round','portrait_backplate','branch_line','spouse_line']
for name in DECOR:
 if name=='mountains':w,h=1200,400;b=mountains(w,h,8)
 elif name=='tree':w,h=512,768;b=tree(225,690,2.2,21)
 elif name=='bamboo':
  w,h=512,768;b=''
  for x in [132,213,299,357]:
   b+=pa(f'M{x} 780 Q{x-49} 360 {x+30} 20',s='#6e846c',sw=4,ex='opacity=".65"')
   for y in [190,320,460,590]:
    b+=ln(x-9,y,x+8,y-3,'#4b654f',2)
    for sg in [-1,1]:b+=pa(f'M{x} {y} Q{x+sg*60} {y-60} {x+sg*125} {y-49} Q{x+sg*53} {y-26} {x} {y} Z','#8b9b7c',ex='opacity=".55"')
 elif name=='clouds':
  w,h=800,240;b=''
  for x,y,sc in [(70,80,1),(460,160,.8)]:b+=gp(pa('M0 20 Q36 -15 75 14 Q98 -42 153 -8 Q181 -22 213 19 Q253 5 279 30 Q186 59 0 47 Q-29 34 0 20 Z','#dce0ca',P['line'],1)+pa('M59 36 Q117 22 163 36 M182 35 L230 34',s='#b7bd9e'),tf=f'translate({x} {y}) scale({sc})')
 elif name=='paper_edge':w,h=900,140;b=pa('M0 29 L35 23 L66 29 L93 20 L129 25 L153 18 L195 26 L225 21 L251 30 L290 25 L335 31 L377 18 L420 26 L467 16 L515 26 L559 19 L614 31 L662 22 L711 28 L759 19 L804 25 L849 19 L900 27 V140 H0 Z',P['paper'],P['line'])
 elif name=='divider':w,h=900,60;b=ln(8,30,408,30,P['line'])+ln(492,30,892,30,P['line'])+pa('M450 15 L464 30 L450 45 L436 30 Z',s=P['gold'],sw=1.2)+pa('M419 30 L428 22 L436 30 L428 38 Z M464 30 L472 22 L481 30 L472 38 Z',P['select'],P['gold'],.8)
 elif name=='corner':w=h=96;b=gp(corner(6,6),tf='scale(3.8)')
 elif name.startswith('seal'):
  w=h=128;b=(pa('M15 8 L118 12 L120 113 L11 118 L7 24 Z',P['danger'])+pa('M21 21 H105 V105 H21 Z',s=P['light'],sw=2.6)) if name=='seal_square' else (ci(64,64,55,P['danger'])+ci(64,64,47,'none',P['light'],2))
  b+=pa('M33 57 L64 34 L94 57 M40 57 V94 H88 V57 M57 94 V72 H72 V94 M48 61 H80 M61 26 H68',s=P['light'],sw=3.2)+grain(128,128,53,70)
 elif name=='portrait_backplate':w=h=256;b=ci(128,128,124,P['paper'],P['gold'],2)+ci(128,128,116,'none',P['line'],1)
 elif name=='branch_line':w,h=240,100;b=pa('M120 4 V35 H12 V96 M120 35 H228 V96',s=P['gold'],sw=1.7)+ci(120,35,3,P['paper'],P['gold'],1.2)
 else:w,h=240,40;b=ln(5,17,235,17,P['gold'],1.5)+ln(5,23,235,23,P['gold'],1.5)+pa('M120 10 L130 20 L120 30 L110 20 Z',P['paper'],P['gold'],1)
 save(f'assets/decor/{name}.svg',svg(gp(b,name),w,h),w,h,'decor','decor.'+name,'透明装饰层；低透明度使用，不拦截输入。',sizes=[('',w,h)])
N=512;yy,xx=np.mgrid[0:N,0:N];rng=np.random.default_rng(812);noise=np.zeros((N,N))
for _ in range(60):
 kx=int(rng.integers(1,39));ky=int(rng.integers(1,39));ph=rng.uniform(0,math.tau);noise+=np.sin(math.tau*(kx*xx+ky*yy)/N+ph)/(1+(kx*kx+ky*ky)**.58)
noise/=max(abs(noise).max(),1e-9)
for name,strength in [('subtle',3),('medium',6),('aged',10)]:
 ar=np.clip(np.array([247,240,223])[None,None,:]+noise[:,:,None]*strength,0,255).astype('uint8');rel=f'assets/textures/paper_{name}_512.png';Image.fromarray(ar).save(R/rel);add(rel,512,512,'texture','paper.'+name,False,'周期函数生成，可平铺纸纹；subtle作正文底，aged仅装饰。',tileable=True)
a=np.zeros((512,512,4),dtype='uint8');a[:,:,:3]=[66,68,47];a[:,:,3]=((noise+1)/2*28).astype('uint8');rel='assets/textures/paper_fiber_alpha_512.png';Image.fromarray(a).save(R/rel);add(rel,512,512,'texture','paper.alpha',True,'透明纸纤维；建议整体opacity0.35，不叠加厚重纹理。',tileable=True)
dump('data/portrait_library.json',{'version':'1.0.0','artIds':LIB});dump('data/house_asset_map.json',{'version':'1.0.0','homes':HOUSES});dump('data/asset_registry.json',{'version':'1.0.0','assets':REG});dump('data/build_index.json',{'icons':list(ICONS),'eventNames':EVENTS,'decor':DECOR})
print('Generated actual assets:',len(REG))
