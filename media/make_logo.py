import cairosvg, io, random, math
from PIL import Image, ImageFilter, ImageChops, ImageEnhance
S=512
def svg(body, w=S, h=S):
    s=f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {S} {S}">{body}</svg>'
    return Image.open(io.BytesIO(cairosvg.svg2png(bytestring=s.encode(),output_width=w,output_height=h))).convert("RGBA")
DEFS='''<defs>
<radialGradient id="bg" cx="50%" cy="62%" r="65%"><stop offset="0" stop-color="#7a2a08"/><stop offset=".35" stop-color="#3a1608"/><stop offset=".75" stop-color="#160b10"/><stop offset="1" stop-color="#07050a"/></radialGradient>
<linearGradient id="steel" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#d9dee4"/><stop offset=".18" stop-color="#8d97a3"/><stop offset=".55" stop-color="#4b525c"/><stop offset="1" stop-color="#1e2228"/></linearGradient>
<linearGradient id="steelside" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#2a2f36"/><stop offset=".5" stop-color="#5c6570"/><stop offset="1" stop-color="#22262c"/></linearGradient>
<linearGradient id="hot" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#ff5a00"/><stop offset=".5" stop-color="#fff2b0"/><stop offset="1" stop-color="#ff5a00"/></linearGradient>
<linearGradient id="parch" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff4cf"/><stop offset=".5" stop-color="#f2c76a"/><stop offset="1" stop-color="#b8741e"/></linearGradient>
<linearGradient id="feather" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffffff"/><stop offset=".5" stop-color="#d8e8ff"/><stop offset="1" stop-color="#7fa6d6"/></linearGradient>
</defs>'''
# background
img=svg(DEFS+'<rect width="512" height="512" fill="url(#bg)"/>')
# stone noise
random.seed(7)
noise=Image.effect_noise((S,S),40).convert("L").filter(ImageFilter.GaussianBlur(1.2))
noise=ImageEnhance.Contrast(noise).enhance(1.6)
img=Image.composite(ImageChops.multiply(img,Image.merge("RGBA",[noise]*3+[Image.new("L",(S,S),255)])),img,Image.new("L",(S,S),70))
# rising glow behind scene
glow=svg('<ellipse cx="256" cy="300" rx="170" ry="120" fill="#ff7a18"/>').filter(ImageFilter.GaussianBlur(60))
glow.putalpha(glow.getchannel("A").point(lambda a:a*0.45))
img.alpha_composite(glow)
# runic circle
runes=''.join(f'<rect x="{256+150*math.cos(t)-4}" y="{230+150*math.sin(t)-9}" width="8" height="18" rx="2" transform="rotate({math.degrees(t)+90} {256+150*math.cos(t)} {230+150*math.sin(t)})"/>' for t in [i*math.pi/12 for i in range(24)])
rc=svg(f'<g fill="none" stroke="#ffb040" stroke-width="3" opacity=".55"><circle cx="256" cy="230" r="164"/><circle cx="256" cy="230" r="136"/></g><g fill="#ffcf70" opacity=".6">{runes}</g>')
rcg=rc.filter(ImageFilter.GaussianBlur(6)); img.alpha_composite(rcg); img.alpha_composite(rc)
# scroll / nameplate banner (glowing)
scroll='''
<path d="M120 150 Q256 125 392 150 L392 222 Q256 197 120 222 Z" fill="url(#parch)" stroke="#5a3208" stroke-width="5"/>
<path d="M120 150 q-28 4 -28 38 q0 34 28 34" fill="#d9a043" stroke="#5a3208" stroke-width="5"/>
<path d="M392 150 q28 4 28 38 q0 34 -28 34" fill="#d9a043" stroke="#5a3208" stroke-width="5"/>
<g stroke="#6b3a0c" stroke-width="7" stroke-linecap="round" fill="none" opacity=".85">
<path d="M160 178 q12 -14 24 0 t24 0 t24 0"/><path d="M252 174 q14 -12 28 0 t28 0 t28 2"/>
<path d="M180 202 q16 -10 32 0 t32 0 t32 0 t32 0"/></g>'''
sc=svg(DEFS+scroll)
scg=svg('<path d="M110 145 Q256 118 402 145 L402 228 Q256 202 110 228 Z" fill="#ffd070"/>').filter(ImageFilter.GaussianBlur(22))
img.alpha_composite(scg); img.alpha_composite(sc)
# anvil
anvil='''
<path d="M88 300 H352 C388 300 420 288 440 270 C430 300 404 322 362 326 L338 334 C326 352 318 362 318 384 H196 C196 362 186 350 174 334 L150 326 C118 322 96 316 88 300 Z" fill="url(#steel)" stroke="#0c0e12" stroke-width="5"/>
<path d="M92 300 H352 C380 300 404 292 424 282" fill="none" stroke="#ffffff" stroke-width="3" opacity=".6"/>
<path d="M196 384 H318 L350 418 H164 Z" fill="url(#steelside)" stroke="#0c0e12" stroke-width="5"/>
<rect x="150" y="414" width="214" height="22" rx="4" fill="#1c2026" stroke="#0c0e12" stroke-width="4"/>
<path d="M150 304 H350 C368 304 380 306 392 302" stroke="url(#hot)" stroke-width="6" fill="none"/>'''
an=svg(DEFS+anvil)
hotg=svg('<ellipse cx="260" cy="302" rx="140" ry="18" fill="#ffae40"/>').filter(ImageFilter.GaussianBlur(14))
img.alpha_composite(an); img.alpha_composite(hotg)
# quill striking anvil
quill='''
<g transform="rotate(-32 300 200)">
<path d="M300 296 C286 250 278 170 300 96 C324 150 330 230 300 296 Z" fill="url(#feather)" stroke="#2c3e66" stroke-width="4"/>
<path d="M300 296 L300 110" stroke="#2c3e66" stroke-width="3"/>
<g stroke="#9db8e0" stroke-width="2"><path d="M300 150 l-14 -10"/><path d="M300 175 l-16 -10"/><path d="M300 200 l-16 -10"/><path d="M300 160 l14 -12"/><path d="M300 185 l15 -12"/><path d="M300 210 l14 -12"/></g>
<path d="M300 296 L294 320 L300 334 L306 320 Z" fill="#ffd36b" stroke="#6b3a0c" stroke-width="3"/>
</g>'''
q=svg(DEFS+quill); qg=q.copy().filter(ImageFilter.GaussianBlur(10))
qg=Image.merge("RGBA",[Image.new("L",(S,S),v) for v in (150,200,255)]+[qg.getchannel("A").point(lambda a:a*0.8)])
img.alpha_composite(qg); img.alpha_composite(q)
# sparks
sp=''
random.seed(3)
for i in range(26):
    a=random.uniform(math.pi*1.05,math.pi*1.95); d=random.uniform(30,150); r=random.uniform(1.5,4.5)
    x=256+d*math.cos(a)*1.3; y=300+d*math.sin(a)*0.55
    sp+=f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="#fff0b0"/>'
spi=svg(sp); spg=svg(sp.replace('#fff0b0','#ff8a20')).filter(ImageFilter.GaussianBlur(5))
img.alpha_composite(spg); img.alpha_composite(spi)
# impact flash
fl=svg('<circle cx="250" cy="300" r="26" fill="#fffbe0"/>').filter(ImageFilter.GaussianBlur(16)); img.alpha_composite(fl)
# vignette
vg=svg('<defs><radialGradient id="v" cx="50%" cy="50%" r="72%"><stop offset=".6" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".85"/></radialGradient></defs><rect width="512" height="512" fill="url(#v)"/>')
img.alpha_composite(vg)
# ornate gold frame
frame='''<defs>
<linearGradient id="g1" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff1a8"/><stop offset=".25" stop-color="#e0a72e"/><stop offset=".5" stop-color="#8a5410"/><stop offset=".75" stop-color="#e8b43c"/><stop offset="1" stop-color="#6e400a"/></linearGradient>
<radialGradient id="gem" cx="40%" cy="35%" r="60%"><stop offset="0" stop-color="#ffd0d0"/><stop offset=".4" stop-color="#d8141e"/><stop offset="1" stop-color="#4a0208"/></radialGradient></defs>
<path fill-rule="evenodd" fill="url(#g1)" d="M0 0 H512 V512 H0 Z M30 30 V482 H482 V30 Z"/>
<rect x="2" y="2" width="508" height="508" fill="none" stroke="#2a1604" stroke-width="4"/>
<rect x="30" y="30" width="452" height="452" fill="none" stroke="#1a0d02" stroke-width="5"/>
<rect x="16" y="16" width="480" height="480" fill="none" stroke="#fff0b0" stroke-width="1.5" opacity=".6"/>
'''
for cx,cy in [(30,30),(482,30),(30,482),(482,482)]:
    frame+=f'<path d="M{cx} {cy-34} L{cx+34} {cy} L{cx} {cy+34} L{cx-34} {cy} Z" fill="url(#g1)" stroke="#2a1604" stroke-width="4"/><circle cx="{cx}" cy="{cy}" r="13" fill="url(#gem)" stroke="#2a1604" stroke-width="3"/>'
for cx,cy in [(256,15),(256,497),(15,256),(497,256)]:
    frame+=f'<circle cx="{cx}" cy="{cy}" r="8" fill="url(#g1)" stroke="#2a1604" stroke-width="3"/>'
fr=svg(frame)
inner=svg('<rect x="30" y="30" width="452" height="452" fill="none" stroke="#000" stroke-width="22"/>').filter(ImageFilter.GaussianBlur(8))
img.alpha_composite(inner); img.alpha_composite(fr)
img.convert("RGB").save("/home/claude/nameforge-icon.png")
