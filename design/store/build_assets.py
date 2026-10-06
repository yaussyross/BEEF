#!/usr/bin/env python3
"""BEEF store production assets — app icon, onboarding, store listing screenshots."""
import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = '/home/team/shared/design/store/'
F   = OUT + 'fonts/'
MOD = '/home/team/shared/design/'

# ---------- brand tokens ----------
RED    = (214, 40, 57)     # D62839
BROWN  = (111, 42, 30)     # 6F2A1E
CHAR   = (30, 27, 24)      # 1E1B18
CREAM  = (251, 243, 232)   # FBF3E8
ORANGE = (247, 127, 0)     # F77F00
LIME   = (164, 198, 57)    # A4C639
BERRY  = (179, 20, 107)    # B3146B
WHITE  = (255, 255, 255)
GRAD = [RED, ORANGE, BERRY]  # D62839 -> F77F00 -> B3146B

MODELS = ['beef-model-01-pink-satin.jpg','beef-model-02-coral-tank.jpg',
          'beef-model-03-emerald-bomber.jpg','beef-model-04-hawaiian.jpg',
          'beef-model-05-striped-tee.jpg','beef-model-06-neon-yellow.jpg']

def font(size, wght, fam='unbounded'):
    path = F + ('Unbounded.ttf' if fam=='unbounded' else 'SpaceGrotesk.ttf')
    f = ImageFont.truetype(path, size)
    f.set_variation_by_axes([wght])
    return f

DISPLAY = lambda s: font(s, 900, 'unbounded')
BOLD    = lambda s: font(s, 700, 'unbounded')
BODY    = lambda s: font(s, 400, 'space')
BODY_B  = lambda s: font(s, 700, 'space')
MED     = lambda s: font(s, 500, 'space')

def vgrad(size, stops=GRAD):
    w,h = size
    grad = Image.new('RGB',(1,len(stops)))
    for i,c in enumerate(stops): grad.putpixel((0,i), c)
    grad = grad.resize((w,h))
    return grad

def lerp(a,b,t): return tuple(int(a[i]+(b[i]-a[i])*t) for i in range(3))

def show_grad(size, c1, c2, vertical=True):
    w,h=size
    im=Image.new('RGB',(w,h))
    d=ImageDraw.Draw(im)
    n = min(w,h) if False else (h if vertical else w)
    for i in range(n):
        c=lerp(c1,c2, i/max(1,n-1))
        if vertical: d.line([(0,i),(w,i)],fill=c)
        else: d.line([(i,0),(i,h)],fill=c)
    return im

def text_len(t, f, ls=0):
    if not t: return 0
    return sum(f.getlength(c)+ls for c in t) - ls

def draw_ls(draw, cx, y, t, f, fill, ls=0, anchor_mid=True, anchor_y='m'):
    if not t: return
    total = text_len(t,f,ls)
    x = cx - total/2 if anchor_mid else cx
    for c in t:
        draw.text((x,y), c, font=f, fill=fill, anchor='lm')
        x += f.getlength(c)+ls

def wrap(t, f, max_w, ls=0):
    """Return list of lines fitting max_w."""
    words = t.split()
    lines=[]; cur=''
    for w in words:
        trial=(cur+' '+w).strip()
        if text_len(trial,f,ls)<=max_w or not cur:
            cur=trial
        else:
            lines.append(cur); cur=w
    if cur: lines.append(cur)
    return lines

def draw_para(draw, cx, y, t, f, fill, max_w, ls=0, lh=1.35, align_mid=True):
    lines=wrap(t,f,max_w,ls)
    fh=f.getbbox('Hg')[3]-f.getbbox('Hg')[1]
    for ln in lines:
        if align_mid:
            draw_ls(draw, cx, y, ln, f, fill, ls=ls)
        else:
            draw.text((cx,y),ln,font=f,fill=fill,anchor='lm')
        y+=fh*lh
    return y

def circle_crop(src, size, box=None):
    im=Image.open(src).convert('RGB')
    w,h=im.size
    s=min(w,h)
    left=(w-s)//2; top=(h-s)//2
    if box: left,top=box
    im=im.crop((left,top,left+s,top+s)).resize((size,size),Image.LANCZOS)
    mask=Image.new('L',(size,size),0)
    ImageDraw.Draw(mask).ellipse((0,0,size,size),fill=255)
    out=Image.new('RGBA',(size,size),(0,0,0,0))
    out.paste(im,(0,0),mask)
    return out

def round_crop(src, size, rad, center='center'):
    im=Image.open(src).convert('RGB')
    w,h=im.size
    s=min(w,h)
    if center=='top': 
        pass
    left=(w-s)//2; top=(h-s)//2
    if center=='top': top=0
    im=im.crop((left,top,left+s,top+s)).resize((size,size),Image.LANCZOS)
    mask=Image.new('L',(size,size),0)
    ImageDraw.Draw(mask).rounded_rectangle((0,0,size,size),radius=rad,fill=255)
    out=Image.new('RGBA',(size,size),(0,0,0,0))
    out.paste(im,(0,0),mask)
    return out

def logo(draw, cx, y, scale=1.0, color=RED):
    f=DISPLAY(int(88*scale)); f2=MED(int(30*scale))
    draw_ls(draw, cx, y, 'BEEF', f, color, ls=int(6*scale))
    draw_ls(draw, cx, y+int(58*scale), 'aged to perfection', f2, lerp(color,(0,0,0),0.25), ls=int(1*scale))
    return y+int(58*scale)

def dots(draw, cx, y, n, active, color=RED, r=16):
    gap=r*2+r*3
    x0=cx-(n-1)*gap/2
    for i in range(n):
        if i==active:
            draw.ellipse([x0-r,y-r,x0+r,y+r],fill=color)
        else:
            draw.ellipse([x0-r,y-r,x0+r,y+r],fill=lerp(color,WHITE,0.55))
        x0+=gap

def pill(draw, cx, y, w, h, text, f, fg, bg, ls=1):
    draw.rounded_rectangle([cx-w/2,y-h/2,cx+w/2,y+h/2],radius=h/2,fill=bg)
    draw_ls(draw, cx, y, text, f, fg, ls=ls)
    return y

def shield(draw, cx, cy, s, color=RED):
    """Draw a shield outline in given color."""
    pts=[]
    top=cx-s; bot=cx+s
    pts=[(top,cy-s*0.9),(bot,cy-s*0.9),(bot,cy+s*0.1),(cx-s*0.25,cy+s*0.95),(cx,cy+s*0.55)]
    # symmetric
    pts=[(top,cy-s*0.9),(bot,cy-s*0.9),(bot,cy+s*0.1),(cx+s*0.4,cy+s*0.55),(cx,cy+s*0.95),(cx-s*0.4,cy+s*0.55),(top,cy+s*0.1)]
    draw.polygon(pts,fill=None,outline=color,width=int(s*0.12))

# =========================================================
# 1) APP ICON  1024x1024
# =========================================================
W=H=1024
icon=Image.new('RGB',(W,H))
# vertical gradient red->orange->berry
icon=Image.blend(show_grad((W,H),RED,ORANGE), show_grad((W,H),ORANGE,BERRY), 0.5)
d=ImageDraw.Draw(icon)
# subtle radial highlight
hl=Image.new('L',(W,H),0)
ImageDraw.Draw(hl).ellipse((W*0.15,W*0.06,W*0.95,H*0.7),fill=90)
hl=hl.filter(ImageFilter.GaussianBlur(160))
icon=Image.composite(Image.new('RGB',(W,H),lerp(WHITE,RED,0.2)), icon, hl)
d=ImageDraw.Draw(icon)
# BEEF wordmark
f=DISPLAY(360)
draw_ls(d, W/2, H/2-20, 'BEEF', f, CREAM, ls=0)
# subtle marbling spark underline: small sizzle flame in lime + berry
yy=H/2+250
# small gem/spark above top-left of BEEF
d.polygon([(W/2-430,yy-30),(W/2-420,yy-70),(W/2-400,yy-30)],fill=LIME)
icon.save(OUT+'app-icon-1024.png')
print('saved app-icon-1024.png')

# =========================================================
# Onboarding + store canvas helpers
# =========================================================
W,H=1290,2796
M=130

def base_screen(bg=CREAM, status=True):
    im=Image.new('RGB',(W,H),bg)
    if status:
        d=ImageDraw.Draw(im)
        d.text((M,70),'9:41',font=MED(44),fill=CHAR,anchor='lm')
        d.ellipse([W-M-70,66,W-M-38,98],outline=CHAR,width=4)
        d.line([(W-M-16,82),(W-M-4,82)],fill=CHAR,width=4)
    return im

def model_hero(im, src, box=None, top_fade=True):
    """Place a full-width model crop into upper region with fade into bg."""
    x0,y0,x1,y1=box if box else (0,0,W,int(H*0.62))
    m=Image.open(MOD+src).convert('RGB')
    mw,mh=m.size
    target_w=x1-x0; target_h=y1-y0
    sc=max(target_w/mw,target_h/mh)
    m=m.resize((int(mw*sc)+1,int(mh*sc)+1))
    # center-ish
    mw2,mh2=m.size
    left=max(0,(mw2-target_w)//2); top=max(0,(mh2-target_h)//2)
    m=m.crop((left,top,left+target_w,top+target_h))
    im.paste(m,(x0,y0))
    if top_fade:
        # bottom fade into bg cream
        fade=Image.new('L',(target_w,int(H*0.16)))
        fd=ImageDraw.Draw(fade)
        for i in range(fade.size[1]):
            fd.line([(0,i),(target_w,i)],fill=int(255*(i/fade.size[1])))
        black=Image.new('RGB',(target_w,int(H*0.16)),bg) if False else None
        overlay=Image.new('RGBA',(target_w,int(H*0.16)),(0,0,0,0))
        # blend solid color fade using alpha ramp
        ramp=Image.new('RGBA',(target_w,int(H*0.16)),(0,0,0,0))
        for i in range(ramp.size[1]):
            a=int(255*(i/ramp.size[1]))
            for x in range(0,ramp.size[0],20):
                ramp.paste((251,243,232,a),(x,i,x+20,i+1))
        ramp=ramp.filter(ImageFilter.GaussianBlur(4))
        fy0 = y1 - int(H*0.16)
        if fy0 < y0: fy0 = y0
        im.paste(ramp,(x0,fy0),ramp)
    return im

def bottom_button(d, text, cy, width, h, fg=CREAM, bg=RED, fsize=46, ls=2):
    pill(d, W/2, cy, width, h, text, DISPLAY(fsize), fg, bg, ls=ls)
    return cy

def top_bar(d, title='BEEF', cx=M, cy=250):
    d.text((cx,cy),title,font=BOLD(52),fill=CHAR,anchor='lm')

# =========================================================
# 2) ONBOARDING SCREENS (4)
# =========================================================
# --- 2.1 18+ gate ---
im=base_screen()
d=ImageDraw.Draw(im)
lo=logo(d, W/2, 200, 0.8)
im=model_hero(im, MODELS[1], box=(0,int(330),W,int(H*0.55)))
d=ImageDraw.Draw(im)
# big 18+ stamp
stamp_cx=W/2; stamp_cy=int(H*0.46)
d.rounded_rectangle([stamp_cx-190,stamp_cy-190,stamp_cx+190,stamp_cy+190],radius=60,fill=RED)
d.text((stamp_cx-130,stamp_cy),'18',font=DISPLAY(230),fill=CREAM,anchor='lm')
d.text((stamp_cx+20,stamp_cy),'+',font=DISPLAY(150),fill=CREAM,anchor='lm')
# text block
ty=int(H*0.62)
draw_ls(d, W/2, ty, 'PROVE YOU\u2019RE LEGAL.', DISPLAY(104), CHAR, ls=2)
ty=int(ty+150)
draw_para(d, W/2, ty, 'BEEF is a strictly 18+ space, no exceptions. Not there yet? Come back when the grill\u2019s ready for you.', BODY(52), CHAR, W-2*M+40, lh=1.4)
bottom_button(d, 'I\u2019M 18 OR OLDER', int(H*0.80), W*0.55, 130)
dots(d, W/2, int(H*0.90), 4, 0)
im.save(OUT+'onboarding-1-18plus.png'); print('saved onboarding-1')

# --- 2.2 intent ---
im=base_screen()
d=ImageDraw.Draw(im); logo(d, W/2, 200, 0.8)
im=model_hero(im, MODELS[0], box=(0,330,W,int(H*0.55)))
d=ImageDraw.Draw(im)
ty=int(H*0.62)
draw_ls(d, W/2, ty, 'WHAT\u2019S YOUR BEEF TODAY?', DISPLAY(96), CHAR, ls=1)
ty+=150
draw_para(d, W/2, ty, 'Friends, dates, or hookups \u2014 set your intent and let the grid do the rest. Your call, your cut.', BODY(52), CHAR, W-2*M+40, lh=1.4)
# intent chips
cy=int(H*0.72)
chips=[('FRIEND',LIME),('DATE',ORANGE),('HOOKUP',BERRY)]
tot=3; gap=36; cw=300; ch=120
start=W/2-(tot*cw+(tot-1)*gap)/2
x=start
for name,c in chips:
    pill(d, x+cw/2, cy, cw, ch, name, DISPLAY(42), CHAR, c, ls=1)
    x+=cw+gap
bottom_button(d, 'PICK A FLAVOR', int(H*0.83), W*0.55, 130)
dots(d, W/2, int(H*0.90), 4, 1)
im.save(OUT+'onboarding-2-intent.png'); print('saved onboarding-2')

# --- 2.3 privacy trust ---
im=base_screen()
d=ImageDraw.Draw(im); logo(d, W/2, 200, 0.8)
im=model_hero(im, MODELS[3], box=(0,330,W,int(H*0.55)))
d=ImageDraw.Draw(im)
ty=int(H*0.60)
# shield graphic behind headline
shield(d, W-2*M-120, ty+10, 130)
draw_ls(d, W/2, ty, 'YOUR LOCATION IS YOURS.', DISPLAY(92), CHAR, ls=1)
ty+=140
draw_para(d, W/2, ty, 'We never sell your location to advertisers. Coarse mode. Opt-in sharing. Full control \u2014 the way it should be.', BODY(52), CHAR, W-2*M+40, lh=1.4)
# mini trust ticks
ty+=170
for i,txt in enumerate(['Never sold to ad partners','Coarse-mode location by default','Opt-in precise sharing']):
    cx=M+60; d.ellipse([cx,ty,cx+46,ty+46],fill=LIME)
    draw_ls(d, cx+120, ty+23, txt, BODY(48), CHAR, ls=1)
    ty+=95
bottom_button(d, 'KEEP IT PRIVATE', int(H*0.83), W*0.55, 130)
dots(d, W/2, int(H*0.90), 4, 2)
im.save(OUT+'onboarding-3-privacy.png'); print('saved onboarding-3')

# --- 2.4 waitlist / beta ---
im=base_screen()
d=ImageDraw.Draw(im); logo(d, W/2, 250, 0.9)
im=model_hero(im, MODELS[5], box=(0,430,W,int(H*0.60)))
d=ImageDraw.Draw(im)
ty=int(H*0.64)
draw_ls(d, W/2, ty, 'GET ON THE GRILL.', DISPLAY(120), CHAR, ls=2)
ty+=175
draw_para(d, W/2, ty, 'Be first to the butcher\u2019s block. Join the beta waitlist and get a taste before anyone else.', BODY(52), CHAR, W-2*M+40, lh=1.4)
# faux input
iny=int(H*0.78)
INW=int(W*0.62)
d.rounded_rectangle([W/2-INW/2,iny-56,W/2+INW/2,iny+56],radius=56,outline=CHAR,width=5,fill=WHITE)
d.text((W/2,iny),'you@email.com',font=BODY(46),fill=(150,145,140),anchor='lm')
bottom_button(d, 'JOIN THE WAITLIST', int(H*0.86), W*0.62, 130)
dots(d, W/2, int(H*0.93), 4, 3)
im.save(OUT+'onboarding-4-waitlist.png'); print('saved onboarding-4')

# =========================================================
# 3) STORE SCREENSHOTS (6)
# =========================================================
def profile_tile(d, x, y, s, rad, img, name, dist, intent=None, accent=RED):
    tile=round_crop(MOD+img, s, rad, center='top')
    d=ImageDraw.Draw(tile)
    d.rounded_rectangle([0,0,s,s],radius=rad,outline=(255,255,255),width=10)
    return tile, (x,y)

def grid_tile(im, d, x, y, s, img, name, dist, intent):
    tile=round_crop(MOD+img, s, 28, center='top')
    d=ImageDraw.Draw(tile)
    # name + distance bar
    bar=Image.new('RGBA',(s,96),(20,18,16,120))
    tile.paste(bar,(0,s-96),bar)
    dd=ImageDraw.Draw(tile)
    dd.text((22,s-72),name,font=BODY_B(40),fill=WHITE,anchor='lm')
    dd.text((22,s-32),dist,font=MED(30),fill=(255,215,170),anchor='lm')
    if intent:
        ic=intent.center if hasattr(intent,'center') else intent
        # small tag top-right
    im.paste(tile,(x,y),tile)

# --- 3.1 Grid proximity ---
im=base_screen()
d=ImageDraw.Draw(im)
top_bar(d,'BEEF',300)
# top search-ish bar
d.rounded_rectangle([M,360,W-M,436],radius=38,outline=(230,220,208),width=4)
d.text((M+50,398),'Search a cut\u2026',font=BODY(42),fill=(170,163,155),anchor='lm')
# caption chip
chipw=420
pill(d, W/2, 540, chipw, 104, 'THE GRID', DISPLAY(46), CREAM, RED, ls=2)
# 3x2 tile grid
gw=int((W-2*M-60)/3); gh=int(gw*1.25); gx=M; gy=660; gap=30
grid=[(MODELS[0],'Marco','80 ft',''),(MODELS[1],'Jude','0.2 mi',''),
      (MODELS[2],'Lorenzo','0.4 mi',''),(MODELS[3],'Tomas','0.6 mi',''),
      (MODELS[4],'Kai','0.7 mi',''),(MODELS[5],'Dez','1.1 mi','')]
for i,(mod,name,dst,intent) in enumerate(grid):
    r=i//3; c=i%3
    grid_tile(im,d, gx+c*(gw+gap), gy+r*(gh+gap), gw, mod, name, dst, intent)
# bottom headline + caption
hy=int(H*0.845)
draw_para(d, W/2, hy, 'Nearby guys, one sizzling grid. Local. Fresh. Full of flavor.', BODY(52), CHAR, W-2*M, lh=1.35)
py=int(H*0.925)
pill(d, W/2, py, 560, 100, 'A CUT ABOVE THE REST.', DISPLAY(40), CREAM, BROWN, ls=2)
im.save(OUT+'store-1-grid.png'); print('saved store-1')

# --- 3.2 Intent tags ---
im=base_screen()
d=ImageDraw.Draw(im)
top_bar(d,'BEEF',300)
pill(d, W/2, 540, 560, 104, 'INTENT TAGS', DISPLAY(46), CREAM, ORANGE, ls=2)
# 3 large intent cards
iw=int(W*0.8); ih=int(H*0.10)
chips=[('FRIEND','Brunch? Gym? Museum? Find a buddy for it.',LIME),
       ('DATE','Someone worth the slow burn.',ORANGE),
       ('HOOKUP','No small talk required.',BERRY)]
start=W/2-iw/2; yy=760; gap=90
for name,desc,c in chips:
    d.rounded_rectangle([start,yy,start+iw,yy+ih],radius=60,fill=c)
    d.rounded_rectangle([start,yy,start+int(iw*0.30),yy+ih],radius=60,fill=lerp(c,CHAR,0.12))
    d.text((start+int(iw*0.30/2),yy+ih/2),name,font=DISPLAY(52),fill=CREAM,anchor='mm')
    d.text((start+int(iw*0.34),yy+ih/2),desc,font=BODY(44),fill=CHAR,anchor='lm')
    yy+=ih+gap
# row of small pill tags
tagy=yy+20
tags=['Gym','Bear','Twink','Bears','Travel','Brunch','Muscle','Film','Kink-light','Hiking']
start2=W/2
draw_para(d, W/2, tagy, 'or tag it: gym \u00b7 bear \u00b7 twink \u00b7 travel \u00b7 brunch \u00b7 muscle \u00b7 film \u00b7 hiking', BODY(46), CHAR, W-2*M, lh=1.35)
hy=int(H*0.885)
draw_ls(d,W/2,hy,'FRIENDS, DATES & HOOKUPS.',DISPLAY(84),CHAR,ls=1)
py=int(H*0.925)
pill(d, W/2, py, 560, 100, 'A CUT ABOVE THE REST.', DISPLAY(40), CREAM, BROWN, ls=2)
im.save(OUT+'store-2-intent.png'); print('saved store-2')

# --- 3.3 Chat ---
im=base_screen(bg=CREAM)
d=ImageDraw.Draw(im)
top_bar(d,'BEEF',300)
pill(d, W/2, 540, 520, 104, 'CHAT', DISPLAY(46), CREAM, RED, ls=2)
# chat bubbles
ty=760
def bub(text, left, y, w, h, color, fg):
    x = M+40 if left else W-M-40-w
    d.rounded_rectangle([x,y,x+w,y+h],radius=44,fill=color,outline=color)
    d_ = ImageDraw.Draw(im)
    # small tail
    if left:
        d.polygon([(x+56,y+h-14),(x+18,y+h+26),(x+90,y+h+6)],fill=color)
        d_.text((x+40,y+h/2),text,font=BODY(44),fill=fg,anchor='lm')
    else:
        d.polygon([(x+w-56,y+h-14),(x+w-18,y+h+26),(x+w-90,y+h+6)],fill=color)
        d_.text((x+w-40,y+h/2),text,font=BODY(44),fill=fg,anchor='rm')
bub('Hey, you look like a man who\u2019s marbled well.',True,ty,740,150,WHITE,CHAR); ty+=200
bub('Ha! Flattered. Watching the game later?',False,ty,640,150,lerp(RED,(0,0,0),0.15),WHITE); ty+=200
bub('Only if \u201cgame\u201d means brunch.',True,ty,600,150,WHITE,CHAR); ty+=200
bub('Deal. Saturday?',False,ty,480,150,lerp(RED,(0,0,0),0.15),WHITE); ty+=200
# typing indicator
d.rounded_rectangle([M+40,ty,M+320,ty+110],radius=55,fill=WHITE)
for i in range(3):
    d.ellipse([M+80+i*60,ty+40,M+122+i*60,ty+82],fill=(200,190,180))
hy=int(H*0.80)
draw_ls(d,W/2,hy,'NO SMALL TALK REQUIRED.',DISPLAY(84),CHAR,ls=1)
hy+=125
draw_para(d,W/2,hy,'Flirt, plan, meet. Message when it feels right \u2014 or skip straight to the good part.',BODY(48),CHAR,W-2*M,lh=1.32)
py=int(H*0.925)
pill(d, W/2, py, 560, 100, 'A CUT ABOVE THE REST.', DISPLAY(40), CREAM, BROWN, ls=2)
im.save(OUT+'store-3-chat.png'); print('saved store-3')

# --- 3.4 Privacy / trust ---
im=base_screen(bg=CREAM)
d=ImageDraw.Draw(im)
top_bar(d,'BEEF',300)
pill(d, W/2, 540, 560, 104, 'PRIVACY & TRUST', DISPLAY(46), CREAM, LIME, ls=2)
# shield visual (top-center, compact)
shx=int(W/2); shy=900
sg=Image.new('RGBA',(420,500),(0,0,0,0))
sd=ImageDraw.Draw(sg)
pts=[(210,28),(395,58),(395,260),(255,430),(210,458),(165,430),(25,260),(25,58)]
sd.polygon(pts,fill=LIME)
sd.polygon(pts,outline=lerp(LIME,(0,0,0),0.18),width=8)
sd.line([(210,150),(210,380)],fill=(255,255,255),width=9)
sd.line([(120,230),(300,230)],fill=(255,255,255),width=9)
im.paste(sg,(shx-210,shy-250),sg)   # spans y 650..1150
d=ImageDraw.Draw(im)
hy=1340
draw_ls(d,W/2,hy,'YOUR LOCATION IS YOURS.',DISPLAY(82),CHAR,ls=1)
hy=hy+130
draw_ls(d,W/2,hy,'The dating app that never sells your location to advertisers.',BODY(50),CHAR,ls=1)
hy=hy+100
draw_para(d,W/2,hy,'Coarse mode. Opt-in sharing. Total control \u2014 the way it should be.',BODY(50),CHAR,W-2*M,lh=1.35)
ty=1820
for i,txt in enumerate(['Never sold to ad partners','Coarse mode by default','Opt-in precise location','In-app safety tools']):
    cx=W/2-470
    d.ellipse([cx,ty,cx+44,ty+44],fill=LIME)
    d.text((cx+72,ty+22),txt,font=BODY(46),fill=CHAR,anchor='lm')
    ty+=104
py=int(H*0.925)
pill(d, W/2, py, 560, 100, 'A CUT ABOVE THE REST.', DISPLAY(40), CREAM, BROWN, ls=2)
im.save(OUT+'store-4-privacy.png'); print('saved store-4')

# --- 3.5 Discovery ---
im=base_screen(bg=CREAM)
d=ImageDraw.Draw(im)
top_bar(d,'BEEF',300)
pill(d, W/2, 540, 640, 104, 'INTEREST DISCOVERY', DISPLAY(46), CREAM, BERRY, ls=2)
# horizontal scroll of big cards
cy=820; ch=360
cards=[('GYM',LIME,MODELS[1]),('TRAVEL',ORANGE,MODELS[4]),('BRUNCH',RED,MODELS[2]),('FILM',BERRY,MODELS[5])]
cw2=int((W-2*M-3*40)/3.4); gap2=40
x=M
for name,c,mod in cards:
    card=round_crop(MOD+mod,cw2,50,center='top')
    dd=ImageDraw.Draw(card)
    bar=Image.new('RGBA',(cw2,120),(20,18,16,110)); card.paste(bar,(0,ch-120),bar)
    ImageDraw.Draw(card).text((30,ch-62),name,font=DISPLAY(60),fill=WHITE,anchor='lm')
    im.paste(card,(x,cy),card)
    x+=cw2+40
# next-arrow
d.polygon([(W-M-30,cy+ch/2),(W-M-130,cy+ch/2-70),(W-M-130,cy+ch/2+70)],fill=RED)
hy=int(H*0.60)
draw_ls(d,W/2,hy,'TASTE YOUR TYPE.',DISPLAY(96),CHAR,ls=1)
hy+=135
draw_para(d,W/2,hy,'Discover by what actually gets you. Interest-led discovery, matched to your marbling.',BODY(48),CHAR,W-2*M,lh=1.35)
hy+=160
draw_para(d,W/2,hy,'Gym \u00b7 Travel \u00b7 Brunch \u00b7 Film \u00b7 Bears \u00b7 Music \u00b7 Outdoors \u00b7 Art',BODY(46),(120,110,100),W-2*M,lh=1.4)
py=int(H*0.925)
pill(d, W/2, py, 560, 100, 'A CUT ABOVE THE REST.', DISPLAY(40), CREAM, BROWN, ls=2)
im.save(OUT+'store-5-discovery.png'); print('saved store-5')

# --- 3.6 Community / safety ---
im=base_screen(bg=CREAM)
d=ImageDraw.Draw(im)
top_bar(d,'BEEF',300)
pill(d, W/2, 540, 600, 104, 'SAFE & MODERATED', DISPLAY(46), CREAM, RED, ls=2)
# safety feature cards (2x2)
fw=int((W-2*M-60)/2); fh=int((H-760-2*60)/2 - 40); fh=430
x0=M; y0=760
feats=[('18+ VERIFIED',LIME),('BLOCK & REPORT',ORANGE),('PHOTO CHECK',BERRY),('COMMUNITY RULES',RED)]
fx=x0; fy=y0
for name,c in feats:
    d.rounded_rectangle([fx,fy,fx+fw,fy+fh],radius=50,fill=c)
    d.rounded_rectangle([fx,fy,fx+fw,fy+fh],radius=50,outline=lerp(c,(0,0,0),0.15),width=8)
    d.text((fx+fw/2,fy+fh/2-36),name,font=DISPLAY(56),fill=CREAM,anchor='mm')
    d.text((fx+fw/2,fy+fh/2+40),'\u2713',font=BODY(70),fill=(255,255,255),anchor='mm')
    fx+=fw+60
    if fx> W-M-fw+20: fx=x0; fy+=fh+60
hy=int(H*0.80)
draw_ls(d,W/2,hy,'A WINK, NOT A LEER.',DISPLAY(90),CHAR,ls=1)
hy+=125
draw_para(d,W/2,hy,'A stylish, respectful space to meet. Moderated, 18+ gated, and never explicit \u2014 just confident.',BODY(48),CHAR,W-2*M,lh=1.32)
py=int(H*0.925)
pill(d, W/2, py, 560, 100, 'A CUT ABOVE THE REST.', DISPLAY(40), CREAM, BROWN, ls=2)
im.save(OUT+'store-6-community.png'); print('saved store-6')
print('ALL DONE')
