#!/usr/bin/env python3
"""
gen_items.py — источник правды для нового контента Planetoria (предметы из Items-Sheet.png).

Запуск из корня пака:   python3 tools/gen_items.py
Результат:              misc/Content/Items/*.tres, common/Translations/strings.json (merge), BALANCE.md

Правила экономики (зашиты в генератор, проверяются tools/ItemAudit.gd):
  • Оружие и кирки ПОЛУЧАЕМ за монеты (craft_gold_cost) — никаких ресурсов в рецепте покупки
    (единственное исключение: кирка-апгрейд забирает прошлую кирку — «обмен»).
  • Чинится ТОЛЬКО за ресурсы (repair_ingredients) и ВСЕГДА полностью (repair_amount = 0).
"""
import json, math, os, re, sys, zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ITEMS_DIR = os.path.join(ROOT, "misc/Content/Items")
os.makedirs(ITEMS_DIR, exist_ok=True)

SHEET = "res://Assets/Textures/SpriteSheets/Items-Sheet.png"
P = "res://misc/Content/Items/"
SCRIPT = {
    "equip":  "res://scr/Resources/ItemData/Equip_item_data.gd",
    "food":   "res://scr/Resources/ItemData/Food_item_data.gd",
    "acc":    "res://scr/Resources/ItemData/AcsesoryData.gd",
    "item":   "res://scr/Resources/ItemData/ItemData.gd",
    "effect": "res://scr/Resources/effects/EffectResource.gd",
    "ing":    "res://scr/Systems/Craft/SimpleCraft/CraftIngeridents.gd",
}
CLASS = {"equip": "equip_data", "food": "FoodData", "acc": "AccessoryData", "item": "ItemData"}
PROJ = {k: f"res://misc/Projectiles/{v}.tscn" for k, v in
        dict(arrow="Arrow", bullet="Bullet", web="Web", snow="Snowball", axe="AxenRang", bomb="Bomb").items()}
EFF_ICON = {n: f"res://Assets/Textures/UI/Effects/Effect{n}.png" for n in range(1, 13)}
EFF_PARTICLE = "res://misc/Particles/Effect.tscn"
DRINK = "res://Assets/Audio/SFX/Player/Drink.wav"
EAT = "res://Assets/Audio/SFX/Player/Eating.wav"

# StationRestriction: ANY=0, SMITH_ONLY=1, WORKBENCH_ONLY=2
ANY, SMITH, BENCH = 0, 1, 2
# craft_category: 0 Weapons, 1 Pickaxe, 2 Food, 3 Materials, 4 Acsesories
C_WEAPON, C_PICK, C_FOOD, C_MAT, C_ACC = 0, 1, 2, 3, 4

# ─────────────────────────────────────────────────────────────────────────────
#  .tres writer
# ─────────────────────────────────────────────────────────────────────────────
def q(s): return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'

class Tres:
    def __init__(self, kind, uid=None):
        self.kind, self.uid = kind, uid
        self.exts, self.subs, self.props = {}, [], []
        self._n = 0
    def ext(self, typ, path):
        if path not in self.exts:
            self._n += 1
            self.exts[path] = (typ, f"{self._n}_{zlib.crc32(path.encode()) % 99999:x}")
        return f'ExtResource("{self.exts[path][1]}")'
    def sub(self, typ, props):
        self._n += 1
        sid = f"{typ}_{self._n}"
        self.subs.append((typ, sid, props))
        return f'SubResource("{sid}")'
    def atlas(self, cell):
        c, r = cell
        return self.sub("AtlasTexture", [("atlas", self.ext("Texture2D", SHEET)), ("region", f"Rect2({c*16}, {r*16}, 16, 16)")])
    def arr(self, typ_ref, items):  # typed array literal
        return f"Array[{typ_ref}]([{', '.join(items)}])"
    def set(self, k, v): self.props.append((k, v))
    def render(self):
        head = f'[gd_resource type="Resource" script_class="{CLASS[self.kind]}" format=3'
        head += f' uid="{self.uid}"]' if self.uid else "]"
        out = [head, ""]
        for path, (typ, i) in self.exts.items():
            out.append(f'[ext_resource type="{typ}" path="{path}" id="{i}"]')
        out.append("")
        for typ, sid, props in self.subs:
            out.append(f'[sub_resource type="{typ}" id="{sid}"]')
            out += [f"{k} = {v}" for k, v in props]
            out.append("")
        out.append("[resource]")
        out += [f"{k} = {v}" for k, v in self.props]
        return "\n".join(out) + "\n"

def fmt(v):
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, float): return repr(v)
    return str(v)

def ingredient(t, item_file, amount):
    ref = t.ext("Resource", P + item_file)
    return t.sub("Resource", [("script", t.ext("Script", SCRIPT["ing"])), ("item", ref), ("amount", amount)])

def ing_list(t, pairs):
    sref = f'ExtResource("{t.exts[SCRIPT["ing"]][1]}")' if SCRIPT["ing"] in t.exts else None
    items = [ingredient(t, f, a) for f, a in pairs]
    sref = f'ExtResource("{t.exts[SCRIPT["ing"]][1]}")'
    return t.arr(sref, items)

def effect(t, etype, value, duration, icon, name, desc="", tick=1.0, color="Color(1, 1, 1, 1)"):
    return t.sub("Resource", [
        ("script", t.ext("Script", SCRIPT["effect"])),
        ("effect_icon", t.ext("Texture2D", EFF_ICON[icon])),
        ("effect_type", etype), ("value", value), ("duration", duration), ("tick_interval", tick),
        ("particle_color", color), ("particle", t.ext("PackedScene", EFF_PARTICLE)),
        ("display_name", q(name)), ("description", q(desc)),
    ])
def eff_list(t, effs):
    return t.arr(f'ExtResource("{t.exts[SCRIPT["effect"]][1]}")', effs)

# Effect.EffectType
HEAL, SPEED, DMG, REGEN, DEF, MINING, INVIS, SLOW, POISON, BURN, FREEZE, COLD, INFRES, INVINC, DLOOT, BLEED, CORR = \
    0, 1, 2, 3, 4, 5, 6, 9, 8, 10, 11, 12, 13, 14, 15, 16, 17

# ─────────────────────────────────────────────────────────────────────────────
#  ТАБЛИЦЫ КОНТЕНТА
# ─────────────────────────────────────────────────────────────────────────────
# Ремонт: только ресурсы, всегда полный.
R1 = [("Wood.tres", 4), ("Stone.tres", 3)]
R2 = [("Wood.tres", 3), ("Stone.tres", 8)]
R3 = [("Stone.tres", 10), ("Gold_Ore.tres", 2)]
R4 = [("Stone.tres", 12), ("Gold_Ore.tres", 3), ("Crystal_Shard.tres", 2)]
R_BOW1 = [("Wood.tres", 3), ("Stone.tres", 1)]
R_BOW2 = [("Wood.tres", 6), ("Stone.tres", 2)]
R_BOW3 = [("Wood.tres", 6), ("Gold_Ore.tres", 2)]
R_XBOW = [("Wood.tres", 4), ("Crystal_Shard.tres", 2), ("Stone.tres", 6)]
R_BOMB = [("Stone.tres", 8), ("Wood.tres", 2)]

# file, name, cell, tier, stats..., repair, price(coins)
W = [
 # ─── ближний бой ───
 dict(f="Weapon_CactusClub", n="Cactus Club", cell=(10,5), tier=1, dmg=9,  spd=0.95, reach=12, kb=12.0, dur=80,  price=25,  rep=R1,
      hold=True, hit=("poison", 0.25, 4.0, 1.5)),
 dict(f="Weapon_IronLongsword", n="Iron Longsword", cell=(0,7), tier=2, dmg=12, spd=1.0, reach=14, kb=6.0, dur=100, price=45, rep=R2, hold=True),
 dict(f="Weapon_GlintDagger", n="Glint Dagger", cell=(6,5), tier=2, dmg=5, spd=2.0, reach=10, kb=3.0, dur=90, price=40, rep=R2, hold=True, deflect=False),
 dict(f="Weapon_MoonSpear", n="Moon Spear", cell=(4,7), tier=2, dmg=11, spd=1.0, reach=24, kb=5.0, dur=100, price=55, rep=R2, hold=True),
 dict(f="Weapon_BoneScimitar", n="Bone Scimitar", cell=(8,5), tier=2, dmg=11, spd=1.15, reach=13, kb=5.0, dur=100, price=60, rep=R2, hold=True,
      hit=("bleed", 0.35, 4.0, 0.0, 0.03)),
 dict(f="Weapon_MorningStar", n="Morning Star", cell=(3,7), tier=2, dmg=15, spd=0.9, reach=13, kb=16.0, dur=110, price=65, rep=R2, hold=False),
 dict(f="Weapon_Sunblade", n="Sunblade", cell=(4,5), tier=3, dmg=15, spd=1.1, reach=14, kb=6.0, dur=140, price=90, rep=R3, hold=True,
      light=("Color(1, 0.86, 0.45, 1)", 200.0, 1.0)),
 dict(f="Weapon_FrostBlade", n="Frost Blade", cell=(3,5), tier=3, dmg=14, spd=1.15, reach=14, kb=4.0, dur=140, price=105, rep=R3, hold=True,
      hit=("freeze", 0.35, 3.0, 35.0)),
 dict(f="Weapon_RubyBlade", n="Ruby Blade", cell=(0,4), tier=3, dmg=15, spd=1.0, reach=14, kb=6.0, dur=140, price=110, rep=R3, hold=True,
      hit=("burn", 0.30, 3.0, 2.0), light=("Color(1, 0.35, 0.25, 1)", 120.0, 0.7)),
 dict(f="Weapon_BattleAxe", n="Battle Axe", cell=(2,7), tier=3, dmg=24, spd=0.85, reach=16, kb=16.0, dur=140, price=120, rep=R3, hold=False),
 dict(f="Weapon_CrystalSword", n="Crystal Sword", cell=(7,0), tier=4, dmg=24, spd=1.1, reach=16, kb=6.0, dur=200, price=220, rep=R4, hold=True,
      hit=("freeze", 0.20, 2.0, 25.0), light=("Color(0.5, 0.9, 1, 1)", 160.0, 0.8)),
 dict(f="Weapon_CrystalBattleAxe", n="Crystal Battle Axe", cell=(5,7), tier=4, dmg=30, spd=0.85, reach=17, kb=20.0, dur=200, price=240, rep=R4, hold=False),
 dict(f="Weapon_AbyssBlade", n="Abyss Blade", cell=(9,5), tier=4, dmg=26, spd=1.2, reach=14, kb=6.0, dur=180, price=200, rep=R4, hold=True,
      hit=("corruption", 0.35, 5.0, 2.0, 0.03, 0.15), passive=("poison", 0.25)),
 # ─── дальний бой / метание ───
 dict(f="Weapon_SnowSling", n="Snow Sling", cell=(9,6), tier=1, dmg=5, spd=1.2, reach=10, kb=2.0, dur=70, price=30, rep=R_BOW1, hold=True,
      proj="snow", hit=("slow", 0.60, 2.0, 20.0)),
 dict(f="Weapon_NightshadeBow", n="Nightshade Bow", cell=(8,6), tier=2, dmg=8, spd=1.0, reach=10, kb=2.0, dur=90, price=60, rep=R_BOW2, hold=True,
      proj="arrow", hit=("poison", 0.50, 4.0, 1.5)),
 dict(f="Weapon_AxeRang", n="Axe-rang", cell=(7,5), tier=2, dmg=10, spd=0.9, reach=10, kb=4.0, dur=60, price=50, rep=R_BOW2, hold=False,
      proj="axe", deflect=False),
 dict(f="Weapon_Webcaster", n="Webcaster", cell=(11,5), tier=3, dmg=4, spd=1.0, reach=10, kb=0.0, dur=100, price=80, rep=R_BOW3, hold=True,
      proj="web", hit=("slow", 1.0, 3.0, 40.0)),
 dict(f="Weapon_MoonBow", n="Moon Bow", cell=(5,6), tier=3, dmg=6, spd=1.0, reach=10, kb=2.0, dur=110, price=100, rep=R_BOW3, hold=True,
      proj="arrow", n_proj=3, spread=22.0),
 dict(f="Weapon_CrystalCrossbow", n="Crystal Crossbow", cell=(4,6), tier=3, dmg=22, spd=0.85, reach=10, kb=8.0, dur=100, price=120, rep=R_XBOW, hold=False,
      proj="bullet"),
 dict(f="Weapon_BombSack", n="Bomb Sack", cell=(7,6), tier=3, dmg=35, spd=0.85, reach=10, kb=10.0, dur=12, price=70, rep=R_BOMB, hold=False,
      proj="bomb", deflect=False),
]
TOOLS = [
 dict(f="Tool_StonebreakerHammer", n="Stonebreaker Hammer", cell=(11,6), tier=2, dmg=18, spd=0.85, reach=12, kb=18.0, dur=90, price=70, rep=[("Stone.tres",10),("Wood.tres",3)], lvl=2, hold=False),
 dict(f="Tool_GoldenPickaxe", n="Golden Pickaxe", cell=(6,6), tier=4, dmg=20, spd=1.8, reach=10, kb=4.0, dur=220, price=90, rep=[("Stone.tres",10),("Gold_Ore.tres",3)], lvl=4, hold=True,
      trade_in="Pickaxe_LVL3.tres"),
]

def eff(*a, **k): return dict(a=a, k=k)
POTIONS = [
 dict(f="Potion_RegrowthTonic", n="Regrowth Tonic", cell=(8,3), price=12, heal=5.0, craft=12,
      fx=[(REGEN, 2.0, 20.0, 9, "Regeneration", "Heals over time.", 2.0, "Color(0.4, 1, 0.5, 1)")]),
 dict(f="Potion_WarriorsTonic", n="Warrior's Tonic", cell=(9,3), price=18, heal=0.0, craft=18,
      fx=[(DMG, 0.25, 45.0, 2, "Attack Up", "Hit harder.", 1.0, "Color(1, 0.7, 0.2, 1)")]),
 dict(f="Potion_HeartJar", n="Heart Jar", cell=(10,3), price=25, heal=40.0, craft=25, fx=[]),
 dict(f="Potion_FrostfireElixir", n="Frostfire Elixir", cell=(9,4), price=20, heal=0.0, craft=20,
      fx=[(DEF, 0.25, 20.0, 4, "Defense Up", "Take less damage.", 1.0, "Color(0.4, 0.6, 1, 1)")]),
 dict(f="Potion_HoneyDraught", n="Honey Draught", cell=(10,4), price=10, heal=0.0, craft=10,
      fx=[(SPEED, 0.25, 30.0, 1, "Speed Up", "Move faster.", 1.0, "Color(1, 0.8, 0.3, 1)")]),
 dict(f="Potion_ShadeElixir", n="Shade Elixir", cell=(11,4), price=30, heal=0.0, craft=30,
      fx=[(INVIS, 0.0, 20.0, 12, "Invisibility", "Spirits and the possessed ignore you.", 1.0, "Color(0.6, 0.3, 0.9, 1)")]),
 dict(f="Potion_SlimeAntidote", n="Slime Antidote", cell=(6,7), price=22, heal=0.0, craft=22, cure=25.0,
      fx=[(INFRES, 0.5, 60.0, 8, "Infection Resist", "Infection builds up slower.", 1.0, "Color(0.4, 0.9, 0.7, 1)")]),
 dict(f="Potion_FireGrog", n="Fire Grog", cell=(7,7), price=15, heal=8.0, craft=15,
      fx=[(COLD, 0.0, 180.0, 7, "Cold Immunity", "Frost can't slow you.", 1.0, "Color(1, 0.5, 0.15, 1)")]),
 dict(f="Potion_LuckyStar", n="Lucky Star", cell=(5,0), price=60, heal=0.0, craft=0, anim="Eating", maxc=5,
      fx=[(INVINC, 0.0, 4.0, 4, "Invincibility", "Nothing can touch you. Briefly.", 1.0, "Color(1, 1, 0.5, 1)")]),
]
ARTIFACTS = [
 dict(f="Artifact_HornedHelm", n="Horned Helm", cell=(3,1), price=40, craft=40, mats=[("Stone.tres", 15)],
      fx=[(DEF, 0.12, "Defense Up", 4)]),
 dict(f="Artifact_CrystalAmulet", n="Crystal Amulet", cell=(2,2), price=60, craft=60, mats=[("Crystal_Shard.tres", 3)],
      fx=[(REGEN, 0.6, "Regeneration", 9, 2.0)]),
 dict(f="Artifact_WanderersRing", n="Wanderer's Ring", cell=(6,1), price=35, craft=35, mats=[("Gold_Ore.tres", 3)],
      fx=[(SPEED, 0.10, "Speed Up", 1)]),
 dict(f="Artifact_SonamirTome", n="Sonamir Tome", cell=(7,1), price=50, craft=50, mats=[("Artefact_Piece.tres", 8)],
      fx=[(INFRES, 0.7, "Infection Resist", 8)]),
 dict(f="Artifact_MinersMedal", n="Miner's Medal", cell=(11,3), price=45, craft=45, mats=[("Gold_Ore.tres", 4), ("Stone.tres", 10)],
      fx=[(MINING, 0.25, "Mining Speed", 1)]),
]
MATERIALS = [
 dict(f="Gold_Ore", n="Gold Ore", cell=(2,1), price=8),
 dict(f="Crystal_Shard", n="Crystal Shard", cell=(6,0), price=15),
]

# ─────────────────────────────────────────────────────────────────────────────
#  ПЕРЕВОДЫ  (en — ключ, ru, hy)
# ─────────────────────────────────────────────────────────────────────────────
TR = {
 # names
 "Gold Ore": ("Золотая руда", "Ոսկու հանքաքար"),
 "Crystal Shard": ("Осколок кристалла", "Բյուրեղի բեկոր"),
 "Cactus Club": ("Кактусовая дубина", "Կակտուսե մահակ"),
 "Iron Longsword": ("Железный длинный меч", "Երկաթե երկար սուր"),
 "Glint Dagger": ("Сверкающий кинжал", "Շողացող դաշույն"),
 "Moon Spear": ("Лунное копьё", "Լուսնային նիզակ"),
 "Bone Scimitar": ("Костяной ятаган", "Ոսկրե ղիլիչ"),
 "Morning Star": ("Моргенштерн", "Մորգենշտերն"),
 "Sunblade": ("Солнечный клинок", "Արևի շեղբ"),
 "Frost Blade": ("Ледяной клинок", "Սառցե շեղբ"),
 "Ruby Blade": ("Рубиновый клинок", "Սուտակե շեղբ"),
 "Battle Axe": ("Боевой топор", "Մարտական կացին"),
 "Abyss Blade": ("Клинок Бездны", "Անդունդի շեղբ"),
 "Crystal Sword": ("Кристальный меч", "Բյուրեղե սուր"),
 "Crystal Battle Axe": ("Кристальный боевой топор", "Բյուրեղե մարտական կացին"),
 "Snow Sling": ("Снежная рогатка", "Ձնագնդի պարսատիկ"),
 "Nightshade Bow": ("Ядовитый лук", "Թունավոր աղեղ"),
 "Moon Bow": ("Лунный лук", "Լուսնային աղեղ"),
 "Crystal Crossbow": ("Кристальный арбалет", "Բյուրեղե աղեղնազեն"),
 "Webcaster": ("Паутинник", "Սարդոստայնանետ"),
 "Axe-rang": ("Топор-бумеранг", "Կացին-բումերանգ"),
 "Bomb Sack": ("Мешок бомб", "Ռումբերի պարկ"),
 "Stonebreaker Hammer": ("Кувалда-камнеруб", "Քարաջարդ մուրճ"),
 "Golden Pickaxe": ("Золотая кирка", "Ոսկե քլունգ"),
 "Regrowth Tonic": ("Тоник регенерации", "Վերականգնող թուրմ"),
 "Warrior's Tonic": ("Тоник воина", "Մարտիկի թուրմ"),
 "Heart Jar": ("Банка сердца", "Սրտի ամանը"),
 "Frostfire Elixir": ("Эликсир льда и огня", "Սառնակրակ էլիքսիր"),
 "Honey Draught": ("Медовый отвар", "Մեղրային ըմպելիք"),
 "Shade Elixir": ("Эликсир тени", "Ստվերի էլիքսիր"),
 "Slime Antidote": ("Слизевое противоядие", "Լորձային հակաթույն"),
 "Fire Grog": ("Огненный грог", "Կրակե գրոգ"),
 "Lucky Star": ("Звезда удачи", "Հաջողության աստղ"),
 "Horned Helm": ("Рогатый шлем", "Եղջյուրավոր սաղավարտ"),
 "Crystal Amulet": ("Кристальный амулет", "Բյուրեղե ամուլետ"),
 "Wanderer's Ring": ("Кольцо странника", "Թափառականի մատանի"),
 "Sonamir Tome": ("Фолиант Сонамира", "Սոնամիրի մատյան"),
 "Miner's Medal": ("Медаль шахтёра", "Հանքագործի մեդալ"),
 # descriptions
 "Heavy and shiny. Needed to mend better gear.": ("Тяжёлая и блестящая. Нужна, чтобы чинить хорошее снаряжение.", "Ծանր ու փայլուն։ Անհրաժեշտ է լավ սարքավորումը նորոգելու համար։"),
 "Hums faintly. Master smiths mend with it.": ("Тихо звенит. Мастера чинят им лучшее оружие.", "Թույլ թնդում է։ Վարպետները դրանով են նորոգում լավագույն զենքերը։"),
 "Prickly and cheap. Shoves foes back hard.": ("Колючая и дешёвая. Сильно отбрасывает врагов.", "Փշոտ և էժան։ Թշնամիներին ուժեղ հետ է շպրտում։"),
 "A steady blade with a little extra reach.": ("Надёжный клинок с чуть большим радиусом.", "Հուսալի սայր՝ մի փոքր ավելի երկար հասողությամբ։"),
 "Hold the button for a flurry of quick stabs.": ("Зажми кнопку — и посыплется град быстрых уколов.", "Պահիր կոճակը՝ արագ խոցումների տարափի համար։"),
 "Long reach: poke them before they poke you.": ("Длинный выпад: ударь раньше, чем ударят тебя.", "Երկար հասողություն՝ խոցիր նախքան քեզ կխոցեն։"),
 "Curved blade that leaves foes bleeding.": ("Изогнутый клинок. Враги истекают кровью.", "Կորացած սայր։ Թշնամիները արյունահոսում են։"),
 "Heavy swings send enemies flying.": ("Тяжёлые удары отправляют врагов в полёт.", "Ծանր հարվածները թշնամիներին օդ են նետում։"),
 "Glows warmly. Perfect for dark nights and caves.": ("Тёплое сияние. Идеален для ночей и пещер.", "Տաք լույս է արձակում։ Իդեալական է գիշերների և քարանձավների համար։"),
 "Chilling strikes slow enemies down.": ("Ледяные удары замедляют врагов.", "Սառցե հարվածները դանդաղեցնում են թշնամիներին։"),
 "Sets enemies ablaze. They panic and run in circles!": ("Поджигает врагов — они в панике бегают кругами!", "Այրում է թշնամիներին. նրանք խուճապահար պտտվում են։"),
 "Slow and mighty. Make every swing count.": ("Медленный и мощный. Каждый взмах на счету.", "Դանդաղ ու հզոր։ Յուրաքանչյուր հարված կարևոր է։"),
 "Huge power, but its dark hunger drains your health.": ("Огромная сила, но тёмный голод тянет твоё здоровье.", "Հսկայական ուժ, բայց մութ քաղցը քամում է քո առողջությունը։"),
 "Singing crystal edge. Glows and chills.": ("Поющее кристальное лезвие. Светится и морозит.", "Երգող բյուրեղե շեղբ։ Լուսավորում և սառեցնում է։"),
 "The heaviest hit in the game. Mind the swing speed.": ("Самый тяжёлый удар в игре. Следи за скоростью.", "Խաղի ամենածանր հարվածը։ Հետևիր արագությանդ։"),
 "Flings chilly snowballs that slow enemies.": ("Метает ледяные снежки, замедляющие врагов.", "Նետում է սառը ձնագնդեր, որոնք դանդաղեցնում են թշնամիներին։"),
 "Poisoned arrows. Tick, tick, gone.": ("Отравленные стрелы. Тик-так — и готово.", "Թունավոր նետեր։ Թիկ-թակ՝ և վերջ։"),
 "Fires three arrows in a fan.": ("Выпускает три стрелы веером.", "Արձակում է երեք նետ՝ հովհարաձև։"),
 "Slow to reload, hits like a truck.": ("Медленная перезарядка, удар как таран.", "Դանդաղ է լիցքավորվում, հարվածում է ամուր։"),
 "Tangles foes in sticky webs.": ("Опутывает врагов липкой паутиной.", "Թշնամիներին փաթաթում է կպչուն սարդոստայնով։"),
 "Throw it, it comes back. Catch it!": ("Брось — вернётся. Лови!", "Նետիր՝ կվերադառնա։ Բռնիր։"),
 "Each swing throws a bomb. Refill at the smith.": ("Каждый бросок — бомба. Пополни у кузнеца.", "Յուրաքանչյուր նետում՝ ռումբ։ Համալրիր դարբնի մոտ։"),
 "Smashes rocks in huge blows. Slow but satisfying.": ("Крушит камни огромными ударами. Медленно, но приятно.", "Քարերը ջարդում է հզոր հարվածներով։ Դանդաղ է, բայց հաճելի։"),
 "Digs the toughest ore in a blink.": ("Добывает самую крепкую руду в мгновение ока.", "Ամենակարծր հանքաքարը հանում է աչքթարթելու ընթացքում։"),
 "Slowly knits your wounds back together.": ("Медленно затягивает раны.", "Դանդաղ սպիացնում է վերքերդ։"),
 "A bold sip: hit harder for a while.": ("Смелый глоток: бей сильнее какое-то время.", "Համարձակ կում՝ որոշ ժամանակ ավելի ուժեղ հարվածիր։"),
 "A big instant heal in a jar.": ("Большое мгновенное лечение в банке.", "Մեծ ակնթարթային բուժում ամանում։"),
 "Toughens your skin: take less damage.": ("Закаляет кожу: получаешь меньше урона.", "Կարծրացնում է մաշկդ՝ ավելի քիչ վնաս ես ստանում։"),
 "Sweet and zippy. Run faster for a while.": ("Сладкий и бодрящий. Бегай быстрее.", "Քաղցր և աշխույժ։ Որոշ ժամանակ ավելի արագ վազիր։"),
 "Spirits and the possessed lose track of you.": ("Духи и одержимые теряют тебя из виду.", "Ոգիներն ու բռնվածները կորցնում են քեզ։"),
 "Calms the infection inside you.": ("Усмиряет заражение внутри тебя.", "Հանգստացնում է քո ներսի վարակը։"),
 "Warm belly, no frostbite. Perfect for the North.": ("Тепло внутри — никакого обморожения. Для Севера.", "Տաք փոր՝ առանց ցրտահարության։ Հյուսիսի համար։"),
 "A rare find. Makes you untouchable for a moment.": ("Редкая находка. На миг делает тебя неуязвимым.", "Հազվագյուտ գտածո։ Մի պահ անխոցելի է դարձնում։"),
 "Keep it in your hotbar: take less damage.": ("Держи в хотбаре: получаешь меньше урона.", "Պահիր արագ գոտում՝ ավելի քիչ վնաս ես ստանում։"),
 "Keep it in your hotbar: slowly regain health.": ("Держи в хотбаре: здоровье медленно восстанавливается.", "Պահիր արագ գոտում՝ առողջությունդ դանդաղ վերականգնվում է։"),
 "Keep it in your hotbar: walk a bit faster.": ("Держи в хотбаре: ходишь чуть быстрее.", "Պահիր արագ գոտում՝ մի փոքր ավելի արագ ես քայլում։"),
 "Keep it in your hotbar: infection creeps in slower.": ("Держи в хотбаре: заражение накапливается медленнее.", "Պահիր արագ գոտում՝ վարակը ավելի դանդաղ է կուտակվում։"),
 "Keep it in your hotbar: mine faster.": ("Держи в хотбаре: добываешь быстрее.", "Պահիր արագ գոտում՝ ավելի արագ ես արդյունահանում։"),
 # effects
 "Regeneration": ("Регенерация", "Վերականգնում"), "Heals over time.": ("Лечит со временем.", "Բուժում է ժամանակի ընթացքում։"),
 "Attack Up": ("Усиление атаки", "Հարձակման աճ"), "Hit harder.": ("Бей сильнее.", "Հարվածիր ավելի ուժեղ։"),
 "Defense Up": ("Усиление защиты", "Պաշտպանության աճ"), "Take less damage.": ("Меньше получаемый урон.", "Ավելի քիչ վնաս։"),
 "Speed Up": ("Ускорение", "Արագացում"), "Move faster.": ("Двигайся быстрее.", "Շարժվիր ավելի արագ։"),
 "Invisibility": ("Невидимость", "Անտեսանելիություն"), "Spirits and the possessed ignore you.": ("Духи и одержимые тебя не замечают.", "Ոգիներն ու բռնվածները քեզ չեն նկատում։"),
 "Infection Resist": ("Сопротивление заражению", "Վարակի դիմադրություն"), "Infection builds up slower.": ("Заражение копится медленнее.", "Վարակը ավելի դանդաղ է կուտակվում։"),
 "Cold Immunity": ("Иммунитет к холоду", "Սառնամանիքի անձեռնմխելիություն"), "Frost can't slow you.": ("Мороз тебя не замедлит.", "Ցրտահարությունը քեզ չի դանդաղեցնի։"),
 "Invincibility": ("Неуязвимость", "Անխոցելիություն"), "Nothing can touch you. Briefly.": ("Ничто не может тебя коснуться. Ненадолго.", "Ոչինչ չի կարող քեզ դիպչել։ Կարճ ժամանակով։"),
 "Mining Speed": ("Скорость добычи", "Արդյունահանման արագություն"),
 # tooltip labels
 "SPD": ("СКР", "ԱՐԳ"), "Reach": ("Дальность", "Հասողություն"), "On hit": ("При ударе", "Հարվածի ժամանակ"),
 "While held": ("В руках", "Ձեռքում"), "Emits light": ("Излучает свет", "Լույս է արձակում"),
 "Projectiles": ("Снарядов", "Արկեր"), "Cures infection": ("Лечит заражение", "Բուժում է վարակը"),
 "Heals": ("Лечит", "Բուժում է"), "Hotbar": ("Хотбар", "Արագ գոտի"),
 "Freeze": ("Заморозка", "Սառեցում"), "Burn": ("Обжиг", "Այրում"), "Poison": ("Яд", "Թույն"),
 "Bleed": ("Кровотечение", "Արյունահոսություն"), "Corruption": ("Заражение", "Ապականում"), "Slow": ("Замедление", "Դանդաղեցում"),
 "Drains health": ("Тянет здоровье", "Քամում է առողջությունը"),
 "Full repair": ("Полный ремонт", "Լրիվ նորոգում"), "Item is not damaged": ("Предмет не повреждён", "Իրը վնասված չէ"),
 "Bring the item to repair it": ("Принеси предмет для ремонта", "Բեր իրը նորոգելու համար"),
 "Durability": ("Прочность", "Դիմացկունություն"),
}
DESC = {  # item name -> description key
 "Gold Ore": "Heavy and shiny. Needed to mend better gear.", "Crystal Shard": "Hums faintly. Master smiths mend with it.",
 "Cactus Club": "Prickly and cheap. Shoves foes back hard.", "Iron Longsword": "A steady blade with a little extra reach.",
 "Glint Dagger": "Hold the button for a flurry of quick stabs.", "Moon Spear": "Long reach: poke them before they poke you.",
 "Bone Scimitar": "Curved blade that leaves foes bleeding.", "Morning Star": "Heavy swings send enemies flying.",
 "Sunblade": "Glows warmly. Perfect for dark nights and caves.", "Frost Blade": "Chilling strikes slow enemies down.",
 "Ruby Blade": "Sets enemies ablaze. They panic and run in circles!", "Battle Axe": "Slow and mighty. Make every swing count.",
 "Abyss Blade": "Huge power, but its dark hunger drains your health.", "Crystal Sword": "Singing crystal edge. Glows and chills.",
 "Crystal Battle Axe": "The heaviest hit in the game. Mind the swing speed.", "Snow Sling": "Flings chilly snowballs that slow enemies.",
 "Nightshade Bow": "Poisoned arrows. Tick, tick, gone.", "Moon Bow": "Fires three arrows in a fan.",
 "Crystal Crossbow": "Slow to reload, hits like a truck.", "Webcaster": "Tangles foes in sticky webs.",
 "Axe-rang": "Throw it, it comes back. Catch it!", "Bomb Sack": "Each swing throws a bomb. Refill at the smith.",
 "Stonebreaker Hammer": "Smashes rocks in huge blows. Slow but satisfying.", "Golden Pickaxe": "Digs the toughest ore in a blink.",
 "Regrowth Tonic": "Slowly knits your wounds back together.", "Warrior's Tonic": "A bold sip: hit harder for a while.",
 "Heart Jar": "A big instant heal in a jar.", "Frostfire Elixir": "Toughens your skin: take less damage.",
 "Honey Draught": "Sweet and zippy. Run faster for a while.", "Shade Elixir": "Spirits and the possessed lose track of you.",
 "Slime Antidote": "Calms the infection inside you.", "Fire Grog": "Warm belly, no frostbite. Perfect for the North.",
 "Lucky Star": "A rare find. Makes you untouchable for a moment.",
 "Horned Helm": "Keep it in your hotbar: take less damage.", "Crystal Amulet": "Keep it in your hotbar: slowly regain health.",
 "Wanderer's Ring": "Keep it in your hotbar: walk a bit faster.", "Sonamir Tome": "Keep it in your hotbar: infection creeps in slower.",
 "Miner's Medal": "Keep it in your hotbar: mine faster.",
}

# ─────────────────────────────────────────────────────────────────────────────
#  ГЕНЕРАЦИЯ
# ─────────────────────────────────────────────────────────────────────────────
def write(fname, text):
    with open(os.path.join(ITEMS_DIR, fname + ".tres"), "w", encoding="utf-8") as fh: fh.write(text)

def base_props(t, kind, d, stackable=False, max_count=1):
    t.set("script", t.ext("Script", SCRIPT[kind]))
    ic = t.atlas(d["cell"])
    t.set("icon", ic)
    t.set("item_name", q(d["n"]))
    if d["n"] in DESC: t.set("description", q(DESC[d["n"]]))
    t.set("stackable", fmt(stackable)); t.set("max_count", max_count)
    t.set("price", d["price"])
    return ic

def gen_equip(d, tool=False):
    t = Tres("equip")
    ic = base_props(t, "equip", d)
    t.set("equiped_weapon_sprite", ic)
    t.set("lvl", d.get("lvl", d["tier"]))
    t.set("max_durability", d["dur"]); t.set("Damage", d["dmg"]); t.set("Atk_speed", d["spd"])
    t.set("hit_distance", float(d["reach"])); t.set("knockback", float(d["kb"]))
    t.set("is_weapon", fmt(not tool)); t.set("one_shot_attack", fmt(not d["hold"]))
    t.set("can_deflect_curse", fmt(d.get("deflect", True) and not tool))
    if "proj" in d:
        t.set("play_anim", q("Shoot")); t.set("projectile", t.ext("PackedScene", PROJ[d["proj"]]))
        if d.get("n_proj", 1) > 1: t.set("num_projectiles", d["n_proj"]); t.set("spread_degrees", d["spread"])
    if "hit" in d:
        h = d["hit"]
        t.set("on_hit_effect", q(h[0])); t.set("on_hit_chance", float(h[1])); t.set("on_hit_duration", float(h[2]))
        t.set("on_hit_potency", float(h[3]))
        if h[0] == "bleed": t.set("on_hit_bleed_percent", float(h[4]))
        if h[0] == "corruption": t.set("on_hit_bleed_percent", 0.03); t.set("on_hit_corruption_bonus", float(h[5]))
    if "light" in d:
        col, rad, en = d["light"]
        t.set("passive_emits_light", "true"); t.set("passive_light_color", col)
        t.set("passive_light_radius", rad); t.set("passive_light_energy", en)
    if "passive" in d:
        t.set("passive_player_effect", q(d["passive"][0])); t.set("passive_player_potency", float(d["passive"][1]))
    # ── ПОЛУЧЕНИЕ: только монеты (+ обмен прошлой кирки) ──
    cat = C_PICK if tool else C_WEAPON
    t.set("craft_category", cat); t.set("craft_smith_level", d["tier"]); t.set("craft_station", SMITH)
    t.set("craft_gold_cost", d["price"])
    if d.get("trade_in"):
        t.set("craft_ingredients", ing_list(t, [(d["trade_in"], 1)]))
    # ── РЕМОНТ: только ресурсы, всегда полный (repair_amount = 0 по умолчанию) ──
    t.set("repair_ingredients", ing_list(t, d["rep"])); t.set("repair_station", ANY)
    write(d["f"], t.render())

def gen_potion(d):
    t = Tres("food")
    base_props(t, "food", d, stackable=True, max_count=d.get("maxc", 20))
    t.set("play_anim", q(d.get("anim", "Drink")))
    t.set("eat_sound", t.ext("AudioStream", EAT if d.get("anim") == "Eating" else DRINK))
    if d["fx"]:
        t.set("effects", eff_list(t, [effect(t, *[(f[0], f[1], f[2], f[3], f[4], f[5])][0], tick=f[6], color=f[7]) for f in d["fx"]]))
    t.set("health_restore", float(d["heal"]))
    if d.get("cure"): t.set("cure_infection", float(d["cure"]))
    if d["craft"] > 0:
        t.set("craft_category", C_FOOD); t.set("craft_gold_cost", d["craft"]); t.set("craft_amount", 1)
    write(d["f"], t.render())

def gen_artifact(d):
    t = Tres("acc")
    base_props(t, "acc", d)
    effs = []
    for f in d["fx"]:
        tick = f[4] if len(f) > 4 else 1.0
        effs.append(effect(t, f[0], f[1], -1.0, f[3], f[2], tick=tick))
    t.set("effects", eff_list(t, effs))
    t.set("craft_category", C_ACC); t.set("craft_station", ANY); t.set("craft_smith_level", 2)
    t.set("craft_gold_cost", d["craft"]); t.set("craft_ingredients", ing_list(t, d["mats"]))
    write(d["f"], t.render())

def gen_material(d):
    t = Tres("item"); base_props(t, "item", d, stackable=True, max_count=99)
    write(d["f"], t.render())

for d in MATERIALS: gen_material(d)
for d in W: gen_equip(d)
for d in TOOLS: gen_equip(d, tool=True)
for d in POTIONS: gen_potion(d)
for d in ARTIFACTS: gen_artifact(d)

# ─── переводы: merge в strings.json (старые ключи не трогаем) ───
sp = os.path.join(ROOT, "common/Translations/strings.json")
if os.path.exists(sp):
    with open(sp, encoding="utf-8") as fh: table = json.load(fh)
    added = 0
    for key, (ru, hy) in TR.items():
        if key not in table:
            table[key] = {"en": key, "ru": ru, "hy": hy}; added += 1
    with open(sp, "w", encoding="utf-8") as fh:
        json.dump(table, fh, ensure_ascii=False, indent=1); fh.write("\n")
    print(f"strings.json: +{added} ключей (всего {len(table)})")

# ─── BALANCE.md ───
PIG, RAT, BOSS = 47, 30, 450
rows = ["| Предмет | Тир | Урон | Скор. | DPS | Ударов по свинье (47 HP) | Прочн. | Цена (монеты) | Починка (ресурсы, полная) |", "|---|---|---|---|---|---|---|---|---|"]
def rep_str(r): return ", ".join(f"{n.replace('.tres','').replace('_',' ')} ×{a}" for n, a in r)
for d in W + TOOLS:
    rows.append(f"| {d['n']} | T{d['tier']} | {d['dmg']}{'×3' if d.get('n_proj') else ''} | {d['spd']} | {d['dmg']*d['spd']*d.get('n_proj',1):.1f} | {math.ceil(PIG/d['dmg'])} | {d['dur']} | {d['price']} | {rep_str(d['rep'])} |")
open(os.path.join(ROOT, "BALANCE.md"), "w", encoding="utf-8").write("\n".join(rows) + "\n")
print("OK:", len(MATERIALS)+len(W)+len(TOOLS)+len(POTIONS)+len(ARTIFACTS), "предметов")
