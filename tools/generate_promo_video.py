#!/usr/bin/env python3
"""
Arcane Dark — Real Promo Video (60s, 1920x1080, 30fps)
Generates docs/assets/video/arcane-dark-promo.mp4 + store/promo.mp4 + docs/store/promo.mp4
Uses Pillow for frames, MoviePy for encoding, ambient_tavern.ogg for audio.
"""
import pathlib, math, os, textwrap
from PIL import Image, ImageDraw, ImageFont

BASE = pathlib.Path(r"H:\dnd-mobile")
W, H = 1920, 1080
FPS = 30

# Colors (from site + app theme)
BG = (15,13,23)
SURFACE = (26,22,43)
SURFACE_CARD = (30,27,46)
SURFACE_ELEV = (36,32,58)
BORDER = (46,42,68)
VIOLET = (139,92,246)
GOLD = (201,162,39)
GREEN = (61,214,140)
GREEN_BG = (45,214,140,30)
TEXT_PRIM = (245,243,255)
TEXT_SEC = (184,178,208)
TEXT_MUT = (124,120,146)
RED = (176,38,58)

def get_font(size, bold=False):
    cands = [
        r"C:\Windows\Fonts\segoeuib.ttf" if bold else r"C:\Windows\Fonts\segoeui.ttf",
        r"C:\Windows\Fonts\arialbd.ttf" if bold else r"C:\Windows\Fonts\arial.ttf",
    ]
    for c in cands:
        if os.path.exists(c):
            try:
                return ImageFont.truetype(c, size)
            except: pass
    return ImageFont.load_default()

def draw_star(draw, cx, cy, outer, inner, fill):
    pts=[]
    for i in range(8):
        ang = math.radians(-90 + i*45)
        r = outer if i%2==0 else inner
        pts.append((cx + r*math.cos(ang), cy + r*math.sin(ang)))
    draw.polygon(pts, fill=fill)

def icon_image(size):
    bg=(15,13,23); violet=VIOLET; gold=GOLD
    img=Image.new("RGBA",(size,size), bg+(255,))
    d=ImageDraw.Draw(img)
    inset=int(size*0.125); radius=int(size*0.12)
    d.rounded_rectangle((inset-2,inset-2,size-inset+2,size-inset+2), radius=radius+4, fill=SURFACE_CARD+(255,))
    d.rounded_rectangle((inset,inset,size-inset,size-inset), radius=radius, fill=violet+(255,))
    d.rounded_rectangle((inset,inset,size-inset,size-inset), radius=radius, outline=gold+(180,), width=max(2,size//256))
    cx,cy=size//2,size//2
    outer=int(size*0.22); inner=int(size*0.07)
    draw_star(d,cx+int(size*0.015),cy+int(size*0.015),outer,inner,fill=(0,0,0,70))
    draw_star(d,cx,cy,outer,inner,fill=(255,255,255,255))
    sr=int(size*0.06); si=int(size*0.018)
    draw_star(d,int(size*0.72),int(size*0.28),sr,si,fill=(255,255,255,180))
    draw_star(d,int(size*0.30),int(size*0.72),int(size*0.045),int(size*0.014),fill=(255,255,255,140))
    return img

def gradient_bg(draw, W, H):
    for y in range(H):
        t=y/H
        # subtle vertical gradient BG -> SURFACE*0.3
        r=int(BG[0] + (SURFACE[0]-BG[0])*t*0.35)
        g=int(BG[1] + (SURFACE[1]-BG[1])*t*0.35)
        b=int(BG[2] + (SURFACE[2]-BG[2])*t*0.35)
        draw.line((0,y,W,y), fill=(r,g,b))
    # vignette orbs (soft circles) - draw semi-transparent ellipses via overlay?
    # We'll just add two faint orbs at corners
    pass

def phone_frame(screenshot_path, target_h=920):
    """Load portrait screenshot, scale to target_h, return image with shadow and rounded border"""
    src = Image.open(screenshot_path).convert("RGBA")
    # scale preserving aspect: src 1080x1920
    scale = target_h / src.height
    tw = int(src.width * scale)
    th = target_h
    resized = src.resize((tw, th), Image.LANCZOS)
    # create phone image with border
    pad = 14
    outer_w = tw + pad*2
    outer_h = th + pad*2 + 24  # extra for notch area
    phone = Image.new("RGBA", (outer_w, outer_h), (0,0,0,0))
    d = ImageDraw.Draw(phone)
    # outer rounded rect (phone body)
    d.rounded_rectangle((0,0,outer_w,outer_h), radius=28, fill=(18,16,28,255), outline=BORDER+(255,), width=2)
    # inner screen
    d.rounded_rectangle((pad, 22, pad+tw, 22+th), radius=16, fill=(0,0,0,255))
    phone.paste(resized, (pad, 22), resized if resized.mode=="RGBA" else None)
    # notch
    notch_w = 110
    notch_h = 14
    nx = (outer_w - notch_w)//2
    d.rounded_rectangle((nx, 2, nx+notch_w, 2+notch_h), radius=7, fill=(0,0,0,255), outline=BORDER+(255,), width=1)
    d.ellipse((nx+18, 5, nx+28, 15), fill=(30,27,46,255))
    # add soft shadow by creating larger image with shadow? We'll just return phone; caller will composite onto bg with shadow offset
    return phone

# Pre-load screenshots
SCREEN = {
    "01": BASE/"docs"/"store"/"phone"/"01-onboarding.png",
    "02": BASE/"docs"/"store"/"phone"/"02-character-creation.png",
    "03": BASE/"docs"/"store"/"phone"/"03-campaign-hub.png",
    "04": BASE/"docs"/"store"/"phone"/"04-gameplay.png",
    "05": BASE/"docs"/"store"/"phone"/"05-multiplayer.png",
}
# Fallback to docs/screenshots if not found
for k,p in list(SCREEN.items()):
    if not p.exists():
        alt = BASE/"docs"/"screenshots"/f"{k}-*.svg"
        print(f"missing {p}")

# Cached icon
ICON_512 = icon_image(512)
ICON_260 = icon_image(260)
ICON_200 = icon_image(200)
ICON_120 = icon_image(120)

def scene_splash():
    img = Image.new("RGB", (W,H), BG)
    d = ImageDraw.Draw(img)
    gradient_bg(d, W, H)
    # glow orbs (simulate website)
    # violet orb top-left, gold bottom-right via radial gradient approximation (simple ellipse with alpha overlay)
    orb = Image.new("RGBA", (W,H), (0,0,0,0))
    od = ImageDraw.Draw(orb)
    # violet large orb behind icon
    od.ellipse((-200, -120, 900, 900), fill=(139,92,246,22))
    od.ellipse((1100, 600, 2100, 1400), fill=(201,162,39,18))
    img = Image.alpha_composite(img.convert("RGBA"), orb).convert("RGB")
    d = ImageDraw.Draw(img)
    # left icon 420
    icon = icon_image(420)
    ix = 260
    iy = (H - 420)//2 - 10
    img.paste(icon, (ix, iy), icon)
    # right text block at x=780
    tx = 780
    # pill COMING SOON
    pill = "COMING SOON TO GOOGLE PLAY  •  ANDROID FIRST  •  iOS LATER"
    pf = get_font(14, bold=True)
    bbox = d.textbbox((0,0), pill, font=pf)
    pw = bbox[2]-bbox[0]+32
    ph = bbox[3]-bbox[1]+18
    py = 220
    # pill bg
    overlay = Image.new("RGBA", (W,H), (0,0,0,0))
    od2 = ImageDraw.Draw(overlay)
    od2.rounded_rectangle((tx, py, tx+pw, py+ph), radius=ph//2, fill=(61,214,140,22), outline=(61,214,140,55), width=1)
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")
    d = ImageDraw.Draw(img)
    d.text((tx+16, py+9), pill, font=pf, fill=GREEN)
    # Title ARCANE DARK
    d.text((tx, 280), "ARCANE", font=get_font(96, bold=True), fill=TEXT_PRIM)
    d.text((tx, 380), "DARK", font=get_font(96, bold=True), fill=TEXT_PRIM)
    # accent underline
    d.rounded_rectangle((tx, 500, tx+420, 508), radius=4, fill=VIOLET)
    # subtitle
    d.text((tx, 540), "Your AI Dungeon Master", font=get_font(36, bold=True), fill=VIOLET)
    d.text((tx, 590), "lives on your phone.", font=get_font(36, bold=True), fill=TEXT_PRIM)
    d.text((tx, 660), "A cozy, torch-lit D&D adventure — solo & private,", font=get_font(20), fill=TEXT_SEC)
    d.text((tx, 692), "or with up to 5 friends around one table.", font=get_font(20), fill=TEXT_SEC)
    # bottom chips
    chip_y = 760
    chips = ["Private — solo on device", "Offline — no signal", "Co-op — up to 6"]
    chip_colors = [GREEN, GOLD, VIOLET]
    cw = 300
    gap = 18
    for i, (txt, col) in enumerate(zip(chips, chip_colors)):
        x = tx + i*(cw+gap)
        # chip bg
        d.rounded_rectangle((x, chip_y, x+cw, chip_y+44), radius=12, fill=SURFACE, outline=BORDER, width=1)
        # dot
        d.ellipse((x+14, chip_y+14, x+28, chip_y+28), fill=col)
        d.text((x+38, chip_y+12), txt, font=get_font(14, bold=True), fill=TEXT_PRIM)
    # bottom bar
    d.text((tx, 860), "FREE  •  No account needed for solo  •  chartmann1590.github.io/arcane-dark", font=get_font(16), fill=TEXT_MUT)
    return img

def scene_private():
    img = Image.new("RGB", (W,H), BG)
    d = ImageDraw.Draw(img)
    gradient_bg(d, W, H)
    # title top
    d.text((W//2, 90), "YOUR STORY STAYS PRIVATE", font=get_font(18, bold=True), fill=GREEN, anchor="mm")
    d.text((W//2, 140), "Solo stays on your phone. Period.", font=get_font(48, bold=True), fill=TEXT_PRIM, anchor="mm")
    d.text((W//2, 200), "No cloud saves. No training on your story. Just you, your dice, and your tavern.", font=get_font(20), fill=TEXT_SEC, anchor="mm")
    # two cards: left private, right offline
    card_w = 820
    card_h = 620
    gap = 40
    left_x = (W - (card_w*2+gap))//2
    y = 260
    # left card private
    d.rounded_rectangle((left_x, y, left_x+card_w, y+card_h), radius=24, fill=SURFACE_CARD, outline=BORDER, width=2)
    # icon circle top
    d.ellipse((left_x+40, y+36, left_x+112, y+108), fill=(61,214,140,28), outline=GREEN, width=2)
    d.text((left_x+76, y+72), "◈", font=get_font(32, bold=True), fill=GREEN, anchor="mm")
    d.text((left_x+136, y+48), "Private — on device", font=get_font(26, bold=True), fill=TEXT_PRIM)
    d.text((left_x+40, y+140), "When you play alone, nothing", font=get_font(18), fill=TEXT_SEC)
    d.text((left_x+40, y+172), "leaves your phone — not your", font=get_font(18), fill=TEXT_SEC)
    d.text((left_x+40, y+204), "hero, not your choices, not a", font=get_font(18), fill=TEXT_SEC)
    d.text((left_x+40, y+236), "single line of the story.", font=get_font(18), fill=TEXT_SEC)
    # checklist
    checks = ["No account needed for solo", "Stays on your device", "Delete anytime with a tap"]
    cy = y+300
    for txt in checks:
        d.ellipse((left_x+40, cy, left_x+64, cy+24), fill=GREEN)
        d.text((left_x+50, cy+12), "✓", font=get_font(14, bold=True), fill=(0,0,0), anchor="mm")
        d.text((left_x+78, cy+2), txt, font=get_font(16), fill=TEXT_PRIM)
        cy+=44
    # right card offline
    rx = left_x+card_w+gap
    d.rounded_rectangle((rx, y, rx+card_w, y+card_h), radius=24, fill=SURFACE_CARD, outline=BORDER, width=2)
    d.ellipse((rx+40, y+36, rx+112, y+108), fill=(201,162,39,28), outline=GOLD, width=2)
    d.text((rx+76, y+72), "✦", font=get_font(28, bold=True), fill=GOLD, anchor="mm")
    d.text((rx+136, y+48), "Offline — no signal needed", font=get_font(26, bold=True), fill=TEXT_PRIM)
    d.text((rx+40, y+140), "After a quick one-time setup,", font=get_font(18), fill=TEXT_SEC)
    d.text((rx+40, y+172), "solo works fully offline.", font=get_font(18), fill=TEXT_SEC)
    d.text((rx+40, y+204), "Planes, cabins, couch — the", font=get_font(18), fill=TEXT_SEC)
    d.text((rx+40, y+236), "dungeon goes where you go.", font=get_font(18), fill=TEXT_SEC)
    checks2 = ["Works offline for solo", "Quick one-time setup", "Resumes where you paused"]
    cy = y+300
    for txt in checks2:
        d.ellipse((rx+40, cy, rx+64, cy+24), fill=GOLD)
        d.text((rx+50, cy+12), "✓", font=get_font(14, bold=True), fill=(0,0,0), anchor="mm")
        d.text((rx+78, cy+2), txt, font=get_font(16), fill=TEXT_PRIM)
        cy+=44
    # badge bottom
    d.text((W//2, 940), "Solo = offline & private  •  Multiplayer only shares what the table needs", font=get_font(14), fill=TEXT_MUT, anchor="mm")
    # phone preview top-right small? we already have cards; add subtle phone screenshot behind text? We'll overlay 01 onboarding faint
    # paste small phone on right card? Already have text, keep clean
    return img

def scene_hero():
    img = Image.new("RGB", (W,H), BG)
    d = ImageDraw.Draw(img)
    gradient_bg(d, W, H)
    # left phone
    phone = phone_frame(SCREEN["02"], target_h=880)
    # shadow
    shadow = Image.new("RGBA", (W,H), (0,0,0,0))
    sd = ImageDraw.Draw(shadow)
    # simple drop shadow ellipse under phone
    # We'll just paste phone with offset
    px = 180
    py = (H - phone.height)//2 + 10
    img.paste(phone, (px, py), phone)
    # right text block
    tx = 760  # after phone outer_w ~ 506+28 => ~ 734, so 760
    # Actually phone outer_w let's calc: tw ~ 495, outer_w 523, so px+523=703, tx 760 leaves gap
    d.text((tx, 180), "MAKE A HERO", font=get_font(18, bold=True), fill=VIOLET)
    d.text((tx, 220), "YOU LOVE", font=get_font(18, bold=True), fill=VIOLET)
    d.text((tx, 270), "Choose your", font=get_font(52, bold=True), fill=TEXT_PRIM)
    d.text((tx, 340), "legend.", font=get_font(52, bold=True), fill=TEXT_PRIM)
    d.rounded_rectangle((tx, 418, tx+260, 424), radius=3, fill=GOLD)
    points = ["Ancestry, calling & background", "Point-buy the tabletop way", "Step-by-step portrait preview"]
    y = 460
    for pt in points:
        d.ellipse((tx, y, tx+26, y+26), fill=VIOLET)
        d.text((tx+13, y+13), "✓", font=get_font(12, bold=True), fill=(255,255,255), anchor="mm")
        d.text((tx+38, y+2), pt, font=get_font(20), fill=TEXT_SEC)
        y+=46
    d.rounded_rectangle((tx, y+10, tx+420, y+60), radius=12, fill=VIOLET)
    d.text((tx+210, y+35), "LIVE PORTRAIT PREVIEW  →", font=get_font(14, bold=True), fill=(255,255,255), anchor="mm")
    d.text((tx, y+80), "Many races & classes — Elf, Human, Dwarf, Orc, Halfling and more.", font=get_font(14), fill=TEXT_MUT)
    return img

def scene_dungeon():
    img = Image.new("RGB", (W,H), BG)
    d = ImageDraw.Draw(img)
    gradient_bg(d, W, H)
    # right phone (gameplay)
    phone = phone_frame(SCREEN["04"], target_h=880)
    px = W - phone.width - 180
    py = (H - phone.height)//2 + 10
    img.paste(phone, (px, py), phone)
    # left text
    tx = 140
    d.text((tx, 180), "A NEW DUNGEON", font=get_font(18, bold=True), fill=GOLD)
    d.text((tx, 220), "EVERY TIME", font=get_font(18, bold=True), fill=GOLD)
    d.text((tx, 270), "Ever-changing", font=get_font(52, bold=True), fill=TEXT_PRIM)
    d.text((tx, 340), "maps.", font=get_font(52, bold=True), fill=TEXT_PRIM)
    d.rounded_rectangle((tx, 418, tx+260, 424), radius=3, fill=VIOLET)
    d.text((tx, 460), "Cozy fog-of-war, torch-lit halls,", font=get_font(20), fill=TEXT_SEC)
    d.text((tx, 494), "and secrets that reward curiosity.", font=get_font(20), fill=TEXT_SEC)
    chips = ["Never the same twice", "Cozy torch-lit maps", "Explore at your pace"]
    y=550
    for ch in chips:
        d.rounded_rectangle((tx, y, tx+360, y+42), radius=10, fill=SURFACE, outline=BORDER, width=1)
        d.ellipse((tx+12, y+12, tx+28, y+28), fill=VIOLET)
        d.text((tx+40, y+10), ch, font=get_font(15, bold=True), fill=TEXT_PRIM)
        y+=56
    return img

def scene_friends():
    img = Image.new("RGB", (W,H), BG)
    d = ImageDraw.Draw(img)
    gradient_bg(d, W, H)
    # left phone multiplayer
    phone = phone_frame(SCREEN["05"], target_h=880)
    px = 180
    py = (H - phone.height)//2 + 10
    img.paste(phone, (px, py), phone)
    # right text
    tx = 760
    d.text((tx, 180), "BRING YOUR", font=get_font(18, bold=True), fill=VIOLET)
    d.text((tx, 220), "FRIENDS", font=get_font(18, bold=True), fill=VIOLET)
    d.text((tx, 270), "Up to 6 at", font=get_font(52, bold=True), fill=TEXT_PRIM)
    d.text((tx, 340), "one table.", font=get_font(52, bold=True), fill=TEXT_PRIM)
    d.rounded_rectangle((tx, 418, tx+260, 424), radius=3, fill=GOLD)
    d.text((tx, 460), "Host or join — everyone shares", font=get_font(20), fill=TEXT_SEC)
    d.text((tx, 494), "the same map and living story.", font=get_font(20), fill=TEXT_SEC)
    # QR highlight box
    d.rounded_rectangle((tx, 550, tx+520, 640), radius=16, fill=SURFACE_CARD, outline=GOLD, width=1)
    d.text((tx+24, 572), "Invite with", font=get_font(16, bold=True), fill=TEXT_MUT)
    d.text((tx+24, 598), "CODE  •  QR", font=get_font(22, bold=True), fill=GOLD)
    d.text((tx+280, 572), "CODE:  AD42 — 9X", font=get_font(16, bold=True), fill=TEXT_PRIM)
    d.text((tx+280, 600), "Tap QR to scan & join", font=get_font(14), fill=TEXT_MUT)
    d.text((tx, 680), "The Dungeon Master keeps everyone in sync — no split lobbies.", font=get_font(14), fill=TEXT_MUT)
    return img

def scene_carousel():
    img = Image.new("RGB", (W,H), BG)
    d = ImageDraw.Draw(img)
    gradient_bg(d, W, H)
    d.text((W//2, 90), "EVERY SCREEN, SAME WARMTH", font=get_font(18, bold=True), fill=GOLD, anchor="mm")
    d.text((W//2, 140), "Phone  •  7″ Tablet  •  10″ Tablet", font=get_font(22, bold=True), fill=TEXT_SEC, anchor="mm")
    # row of 5 phones
    y = 200
    # Load all 5 screenshots as small phones
    phones = []
    for key in ["01","02","03","04","05"]:
        p = phone_frame(SCREEN[key], target_h=620)
        phones.append(p)
    total_w = sum(p.width for p in phones) + 28*4
    start_x = (W - total_w)//2
    x = start_x
    for p in phones:
        img.paste(p, (x, y), p)
        x += p.width + 28
    # caption
    d.text((W//2, 880), "Five moments — Welcome, Your Hero, Home, At the Table, With Friends", font=get_font(16), fill=TEXT_SEC, anchor="mm")
    d.text((W//2, 920), "Portrait captures for every Play Store form factor", font=get_font(14), fill=TEXT_MUT, anchor="mm")
    return img

def scene_home():
    img = Image.new("RGB", (W,H), BG)
    d = ImageDraw.Draw(img)
    gradient_bg(d, W, H)
    # similar to hero but with 03 campaign hub on right
    phone = phone_frame(SCREEN["03"], target_h=880)
    px = W - phone.width - 180
    py = (H - phone.height)//2 + 10
    img.paste(phone, (px, py), phone)
    tx = 140
    d.text((tx, 180), "YOUR CAMPAIGNS", font=get_font(18, bold=True), fill=VIOLET)
    d.text((tx, 270), "Resume in", font=get_font(52, bold=True), fill=TEXT_PRIM)
    d.text((tx, 340), "a tap.", font=get_font(52, bold=True), fill=TEXT_PRIM)
    d.rounded_rectangle((tx, 418, tx+260, 424), radius=3, fill=GOLD)
    d.text((tx, 460), "Current campaign + heroes roster", font=get_font(20), fill=TEXT_SEC)
    d.text((tx, 494), "wait right where you left them.", font=get_font(20), fill=TEXT_SEC)
    # feature list
    feats = [
        ("Whispers of the Forgotten Crypt", "The village sleeps. Beneath it, something stirs..."),
        ("3 heroes ready", "Lyra • Thorn • Mira — swap anytime"),
        ("RESUME →", "Continue solo or invite friends"),
    ]
    y=560
    for title, desc in feats:
        d.rounded_rectangle((tx, y, tx+460, y+68), radius=12, fill=SURFACE_CARD, outline=BORDER, width=1)
        if "RESUME" in title:
            d.rounded_rectangle((tx+12, y+12, tx+120, y+44), radius=8, fill=GOLD)
            d.text((tx+66, y+28), title, font=get_font(12, bold=True), fill=(0,0,0), anchor="mm")
        else:
            d.ellipse((tx+20, y+20, tx+48, y+48), fill=VIOLET)
            d.text((tx+34, y+34), "◈", font=get_font(14, bold=True), fill=(255,255,255), anchor="mm")
            d.text((tx+62, y+16), title, font=get_font(14, bold=True), fill=TEXT_PRIM)
        d.text((tx+140 if "RESUME" in title else tx+62, y+38 if "RESUME" not in title else y+38), desc, font=get_font(12), fill=TEXT_MUT)
        y+=86
    return img

def scene_free():
    img = Image.new("RGB", (W,H), BG)
    d = ImageDraw.Draw(img)
    gradient_bg(d, W, H)
    d.text((W//2, 100), "FREE TO START, FAIR TO PLAY", font=get_font(18, bold=True), fill=GREEN, anchor="mm")
    d.text((W//2, 150), "No paywalls on your story.", font=get_font(44, bold=True), fill=TEXT_PRIM, anchor="mm")
    d.text((W//2, 210), "Jump in for free — ads keep the lights on, you’re in control.", font=get_font(18), fill=TEXT_SEC, anchor="mm")
    # three cards
    card_w = 520
    card_h = 360
    gap = 36
    start_x = (W - (card_w*3+gap*2))//2
    y = 280
    cards = [
        ("Free to play", "Jump in for free — no\npaywalls on your story.", VIOLET),
        ("Private by design", "Review the plain-English\nprivacy policy anytime.", GOLD),
        ("Coming soon", "Android first, iOS later.\nFollow GitHub for launch day.", GREEN),
    ]
    for i, (title, body, col) in enumerate(cards):
        x = start_x + i*(card_w+gap)
        d.rounded_rectangle((x, y, x+card_w, y+card_h), radius=20, fill=SURFACE_CARD, outline=BORDER, width=2)
        # icon
        d.rounded_rectangle((x+24, y+24, x+84, y+84), radius=14, fill=col, outline=None)
        icon_char = "◈" if i==0 else "✓" if i==1 else "▶"
        d.text((x+54, y+54), icon_char, font=get_font(28, bold=True), fill=(255,255,255) if col==VIOLET else (0,0,0), anchor="mm")
        d.text((x+24, y+118), title, font=get_font(20, bold=True), fill=TEXT_PRIM)
        # body split lines
        lines = body.split("\n")
        ly = y+158
        for line in lines:
            d.text((x+24, ly), line, font=get_font(16), fill=TEXT_SEC)
            ly+=28
        if i==1:
            d.text((x+24, y+320), "chartmann1590.github.io/arcane-dark/privacy.html", font=get_font(11), fill=VIOLET)
        if i==2:
            d.rounded_rectangle((x+24, y+318, x+card_w-24, y+348), radius=8, fill=(0,0,0,28), outline=BORDER, width=1)
            d.text((x+card_w//2, y+333), "FOLLOW ON GITHUB  →", font=get_font(11, bold=True), fill=TEXT_MUT, anchor="mm")
    # bottom trust bar
    d.rounded_rectangle((start_x, 700, start_x+card_w*3+gap*2, 760), radius=14, fill=SURFACE, outline=BORDER, width=1)
    d.text((W//2, 730), "Solo = offline & private    •    Ads help keep the tavern warm    •    Delete a hero or campaign with a tap", font=get_font(13), fill=TEXT_MUT, anchor="mm")
    return img

def scene_end():
    img = Image.new("RGB", (W,H), BG)
    d = ImageDraw.Draw(img)
    gradient_bg(d, W, H)
    # glow orbs
    orb = Image.new("RGBA", (W,H), (0,0,0,0))
    od = ImageDraw.Draw(orb)
    od.ellipse((W//2-600, H//2-600, W//2+600, H//2+600), fill=(139,92,246,12))
    img = Image.alpha_composite(img.convert("RGBA"), orb).convert("RGB")
    d = ImageDraw.Draw(img)
    # large icon centered top
    icon = icon_image(220)
    ix = (W - 220)//2
    iy = 100
    img.paste(icon, (ix, iy), icon)
    # title
    d.text((W//2, 380), "ARCANE DARK", font=get_font(64, bold=True), fill=TEXT_PRIM, anchor="mm")
    d.text((W//2, 440), "Your AI Dungeon Master lives on your phone.", font=get_font(22, bold=True), fill=VIOLET, anchor="mm")
    d.text((W//2, 480), "Solo offline & private  •  Co-op with up to 5 friends", font=get_font(18), fill=TEXT_SEC, anchor="mm")
    # coming soon badge
    d.rounded_rectangle((W//2-200, 530, W//2+200, 590), radius=14, fill=(0,0,0,255), outline=BORDER, width=1)
    d.text((W//2-110, 560), "▶", font=get_font(16, bold=True), fill=GREEN, anchor="mm")
    d.text((W//2-80, 554), "COMING SOON ON", font=get_font(12, bold=True), fill=(255,255,255,180), anchor="lm")
    d.text((W//2-80, 574), "Google Play", font=get_font(18, bold=True), fill=(255,255,255), anchor="lm")
    d.rounded_rectangle((W//2+110, 544, W//2+160, 576), radius=12, fill=(255,255,255,18), outline=(255,255,255,22), width=1)
    d.text((W//2+135, 560), "FREE", font=get_font(12, bold=True), fill=(255,255,255), anchor="mm")
    # website + support row
    d.rounded_rectangle((W//2-480, 640, W//2+480, 740), radius=16, fill=SURFACE_CARD, outline=BORDER, width=1)
    d.text((W//2-440, 672), "🌐", font=get_font(20), fill=TEXT_PRIM)
    d.text((W//2-410, 672), "chartmann1590.github.io/arcane-dark", font=get_font(16, bold=True), fill=TEXT_PRIM)
    d.text((W//2-410, 700), "Privacy  •  Screenshots  •  GitHub", font=get_font(13), fill=TEXT_MUT)
    # right side buy me coffee
    d.rounded_rectangle((W//2+160, 656, W//2+440, 724), radius=12, fill=(255,221,0,255), outline=(255,221,0,255), width=1)
    d.text((W//2+300, 690), "☕  Buy me a coffee", font=get_font(14, bold=True), fill=(0,0,0), anchor="mm")
    # footer
    d.text((W//2, 800), "© 2026 Arcane Dark  •  No account needed for solo  •  Your story stays on your phone", font=get_font(14), fill=TEXT_MUT, anchor="mm")
    # end play icon subtle
    d.text((W//2, 960), "▶  PROMO  •  0:60", font=get_font(14, bold=True), fill=(255,255,255,60), anchor="mm")
    return img

def build_video():
    from moviepy.editor import ImageClip, AudioFileClip, CompositeVideoClip, concatenate_videoclips
    import numpy as np
    import tempfile

    scenes = [
        (scene_splash, 5.0),
        (scene_private, 6.0),
        (scene_hero, 7.0),
        (scene_dungeon, 6.0),
        (scene_friends, 6.0),
        (scene_carousel, 7.0),
        (scene_home, 7.0),
        (scene_free, 6.0),
        (scene_end, 10.0),
    ]
    clips = []
    total = sum(d for _, d in scenes)
    print(f"Total scene duration {total}s, target 60s")
    for idx, (fn, dur) in enumerate(scenes):
        print(f"Rendering scene {idx+1}/{len(scenes)}: {fn.__name__} {dur}s ...")
        pil = fn()
        # Convert PIL to numpy for moviepy
        arr = np.array(pil)
        clip = ImageClip(arr).set_duration(dur)
        # Add subtle zoom-in effect? Keep static for now
        clips.append(clip)

    # Concatenate with 0.3s crossfade where possible (use compose)
    # Simple concat without crossfade for stability
    final = concatenate_videoclips(clips, method="compose")

    # Add audio: ambient_tavern.ogg looped/truncated to duration
    audio_path = BASE/"assets"/"audio"/"ambient_tavern.ogg"
    if audio_path.exists():
        print(f"Adding audio {audio_path}")
        try:
            audio = AudioFileClip(str(audio_path)).set_duration(final.duration).audio_fadein(0.6).audio_fadeout(1.2).volumex(0.55)
            final = final.set_audio(audio)
        except Exception as e:
            print(f"Audio attach failed: {e}")

    out_dirs = [
        BASE/"docs"/"assets"/"video",
        BASE/"store",
        BASE/"docs"/"store",
    ]
    for d in out_dirs:
        d.mkdir(parents=True, exist_ok=True)

    out_main = BASE/"docs"/"assets"/"video"/"arcane-dark-promo.mp4"
    print(f"Writing video to {out_main} ...")
    final.write_videofile(str(out_main), fps=FPS, codec="libx264", audio_codec="aac", bitrate="4500k", threads=4, preset="medium", ffmpeg_params=["-movflags","faststart","-pix_fmt","yuv420p"])
    print(f"Done {out_main} exists={out_main.exists()} size={out_main.stat().st_size if out_main.exists() else 0}")

    # Copy to other locations (store/promo.mp4)
    import shutil
    for extra in [BASE/"store"/"arcane-dark-promo.mp4", BASE/"docs"/"store"/"arcane-dark-promo.mp4"]:
        shutil.copy2(out_main, extra)
        print(f"Copied to {extra}")

    # Also create a webm fallback? Not needed
    # Create poster thumbnail already exists, but ensure it matches video first frame
    # Extract first frame as jpg for social?
    print("All done")

if __name__ == "__main__":
    build_video()
