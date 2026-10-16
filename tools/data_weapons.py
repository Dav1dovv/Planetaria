# name, ru, hy, (desc en, ru, hy), sprite, props, recipe, repair, extras
NEWP='res://misc/Projectiles/%s.tscn'
W=[]
def w(**k): W.append(k)
w(f='Slingshot',n='Slingshot',ru='Рогатка',hy='Պարսատիկ',d=('Fires slime globs. Slows enemies. Cheap and cheerful.','Стреляет комками слизи. Замедляет врагов. Дёшево и весело.','Արձակում է լորձի գնդիկներ։ Դանդաղեցնում է թշնամուն։'),
  s=(9,6),p=dict(Damage=6,Atk_speed=1.5,max_durability=120,knockback=3.0,play_anim='Shoot',one_shot_attack=False,num_projectiles=1,spread_degrees=6.0,durability_per_shot=1,price=14,quality=0,
  on_hit_effect='slow',on_hit_chance=0.5,on_hit_duration=2.0,on_hit_potency=0.3),proj='SlimeGlob',craft=[('Wood',8),('Coin',6)],rep=([('Wood',6)],3))
w(f='Stiletto',n='Stiletto',ru='Стилет',hy='Դաշույն',d=('Tiny, quick, and annoying. Weave in and out.','Маленький, быстрый и назойливый. Коли и отскакивай.','Փոքր, արագ ու նյարդայնացնող։ Հարվածիր և հեռացիր։'),
  s=(1,7),p=dict(Damage=6,Atk_speed=1.8,hit_distance=10.0,max_durability=140,knockback=1.0,price=22,quality=1),craft=[('Stone',6),('Coin',18)],rep=([('Stone',5)],4))
w(f='CactusClub',n='Cactus Club',ru='Кактусовая дубина',hy='Կակտուսի մահակ',d=('Thorns poison what they touch. Golems and skeletons are immune.','Шипы отравляют врага. Големы и скелеты неуязвимы к яду.','Փշերը թունավորում են թշնամուն։ Գոլեմներն ու կմախքները անձեռնմխելի են։'),
  s=(10,5),p=dict(Damage=12,Atk_speed=0.95,hit_distance=14.0,max_durability=110,knockback=10.0,price=34,quality=1,
  on_hit_effect='poison',on_hit_chance=0.6,on_hit_duration=5.0,on_hit_potency=2.0),craft=[('Wood',10),('Gel',4),('Coin',15)],rep=([('Wood',8)],6))
w(f='SpikedMace',n='Spiked Mace',ru='Шипастая булава',hy='Փշավոր մահակ',d=('Slow and brutal. Sends enemies flying.','Медленная и жестокая. Отбрасывает врагов далеко.','Դանդաղ և դաժան։ Թշնամուն հեռու է նետում։'),
  s=(3,7),p=dict(Damage=17,Atk_speed=0.9,hit_distance=13.0,max_durability=130,knockback=30.0,price=48,quality=2),craft=[('Stone',18),('Wood',6),('Coin',30)],rep=([('Stone',12)],8))
w(f='BoneSickle',n='Bone Sickle',ru='Костяной серп',hy='Ոսկրե մանգաղ',d=('Fast cuts that make enemies bleed. Great against tough foes.','Быстрые удары вызывают кровотечение. Хорош против крепких врагов.','Արագ հարվածներ՝ արյունահոսություն։ Լավ է ամուր թշնամիների դեմ։'),
  s=(8,5),p=dict(Damage=10,Atk_speed=1.4,hit_distance=13.0,max_durability=100,knockback=4.0,price=42,quality=2,
  on_hit_effect='bleed',on_hit_chance=0.5,on_hit_duration=5.0,on_hit_bleed_percent=0.03),craft=[('Stone',10),('Coin',40)],rep=([('Stone',8)],6))
w(f='FrostStaff',n='Frost Staff',ru='Ледяной посох',hy='Սառցե գավազան',d=('Hurls snowballs that freeze and slow enemies.','Метает снежки, замораживающие и замедляющие врагов.','Նետում է ձնագնդիկներ՝ սառեցնելով թշնամուն։'),
  s=(5,6),p=dict(Damage=8,Atk_speed=1.1,max_durability=100,knockback=3.0,play_anim='Shoot',one_shot_attack=False,durability_per_shot=1,price=70,quality=3,
  on_hit_effect='freeze',on_hit_chance=0.6,on_hit_duration=3.0,on_hit_potency=0.4),proj='Snowball',craft=[('Wood',12),('Piece',2),('Coin',40)],rep=([('Wood',8)],10))
w(f='RubyBlade',n='Ruby Blade',ru='Рубиновый клинок',hy='Սուտակե սայր',d=('Drinks a little life from every hit.','Каждый удар возвращает немного здоровья.','Յուրաքանչյուր հարվածից մի քիչ կյանք է վերադարձնում։'),
  s=(0,4),p=dict(Damage=14,Atk_speed=1.15,hit_distance=13.0,max_durability=120,price=95,quality=3,
  on_hit_effect='heal_on_hit',on_hit_chance=0.5,on_hit_potency=2.0),craft=[('Coin',70),('Stone',20),('Fuel',6)],rep=([('Stone',10)],15))
w(f='SolarBlade',n='Solar Blade',ru='Солнечный клинок',hy='Արևային սայր',d=('Burns what it cuts and glows warmly.','Поджигает врагов и тепло светится.','Այրում է թշնամուն և տաք լույս է արձակում։'),
  s=(4,5),p=dict(Damage=15,Atk_speed=1.2,hit_distance=13.0,max_durability=90,price=100,quality=3,
  on_hit_effect='burn',on_hit_chance=0.35,on_hit_duration=3.0,on_hit_potency=3.0,
  passive_emits_light=True,passive_light_color=(1.0,0.7,0.35,1.0),passive_light_radius=120.0,passive_light_energy=0.7),craft=[('Coin',85),('Fuel',12),('Stone',15)],rep=([('Fuel',6)],15))
w(f='DiamondSword',n='Diamond Sword',ru='Алмазный меч',hy='Ադամանդե սուր',d=('No tricks. Just a very good sword.','Без фокусов. Просто очень хороший меч.','Առանց հնարքների։ Պարզապես շատ լավ սուր։'),
  s=(3,5),p=dict(Damage=21,Atk_speed=1.05,hit_distance=14.0,max_durability=220,price=150,quality=3),craft=[('Coin',140),('Stone',30),('Fuel',10)],rep=([('Stone',15)],20))
w(f='FrostBlade',n='Frost Blade',ru='Клинок инея',hy='Սառցե սայր',d=('Chills enemies, slowing them down.','Охлаждает врагов, замедляя их.','Սառեցնում է թշնամուն՝ դանդաղեցնելով։'),
  s=(7,0),p=dict(Damage=13,Atk_speed=1.15,hit_distance=13.0,max_durability=130,price=105,quality=3,
  on_hit_effect='freeze',on_hit_chance=0.4,on_hit_duration=3.0,on_hit_potency=0.35),craft=[('Coin',95),('Piece',2),('Fuel',8)],rep=([('Fuel',5)],15))
w(f='WarHammer',n='War Hammer',ru='Боевой молот',hy='Մարտական մուրճ',d=('Huge damage and knockback. Swing it carefully.','Огромный урон и отбрасывание. Замахивайся осторожно.','Հսկայական վնաս և հետ նետում։ Զգույշ թափահարիր։'),
  s=(11,6),p=dict(Damage=30,Atk_speed=0.85,hit_distance=15.0,max_durability=200,knockback=35.0,price=120,quality=3),craft=[('Stone',40),('Wood',10),('Coin',60)],rep=([('Stone',20)],20))
w(f='TemplarSpear',n='Templar Spear',ru='Копьё храмовника',hy='Տաճարականի նիզակ',d=('Long reach. Each thrust lunges you forward.','Большая дальность. Каждый удар — рывок вперёд.','Երկար հասողություն։ Յուրաքանչյուր հարված առաջ է նետում։'),
  s=(4,7),p=dict(Damage=13,Atk_speed=1.0,hit_distance=22.0,max_durability=140,knockback=6.0,price=75,quality=2,
  lunge_enabled=True,lunge_speed=90.0,lunge_duration=0.2,lunge_damage_multiplier=1.3,lunge_invincible=False),craft=[('Wood',14),('Stone',10),('Coin',45)],rep=([('Wood',8)],10))
w(f='DawnHalberd',n='Dawn Halberd',ru='Алебарда рассвета',hy='Լուսաբացի հալբերդ',d=('Longest reach in the land. Keep your distance.','Самая большая дальность. Держи врагов на расстоянии.','Ամենաերկար հասողությունը։ Պահիր հեռավորություն։'),
  s=(5,7),p=dict(Damage=19,Atk_speed=0.9,hit_distance=28.0,max_durability=160,knockback=14.0,price=130,quality=3),craft=[('Coin',110),('Stone',25),('Piece',3)],rep=([('Stone',12)],20))
w(f='GlacierAxe',n='Glacier Axe',ru='Ледниковый топор',hy='Սառցադաշտի կացին',d=('Heavy chops that always slow the target.','Тяжёлые удары всегда замедляют цель.','Ծանր հարվածները միշտ դանդաղեցնում են թիրախին։'),
  s=(7,5),p=dict(Damage=22,Atk_speed=0.9,hit_distance=14.0,max_durability=150,knockback=14.0,price=85,quality=2,
  on_hit_effect='slow',on_hit_chance=1.0,on_hit_duration=2.5,on_hit_potency=0.5),craft=[('Coin',75),('Stone',25),('Wood',10)],rep=([('Stone',14)],12))
w(f='KnightsBlade',n="Knight's Blade",ru='Палаш рыцаря',hy='Ասպետի թուր',d=('Dropped by the Copper Knight. Its weight steadies you.','Выпадает с Медного Рыцаря. Его вес придаёт стойкости.','Ընկնում է Պղնձե ասպետից։ Նրա ծանրությունը կայունություն է տալիս։'),
  s=(0,7),p=dict(Damage=28,Atk_speed=0.95,hit_distance=16.0,max_durability=300,knockback=14.0,price=220,quality=4,
  passive_player_effect='defense_boost',passive_player_potency=0.08),rep=([('Coin',30)],40))
w(f='AbyssBlade',n='Abyss Blade',ru='Клинок Бездны',hy='Անդունդի սայր',d=('Corrupts enemies, but the blade gnaws at its holder.','Заражает врагов, но клинок точит и владельца.','Ապականում է թշնամուն, բայց սայրը կրծում է նաև տիրոջը։'),
  s=(9,5),p=dict(Damage=30,Atk_speed=1.0,hit_distance=15.0,max_durability=160,price=260,quality=5,
  on_hit_effect='corruption',on_hit_chance=0.3,on_hit_duration=6.0,on_hit_potency=2.0,on_hit_corruption_bonus=0.15,
  passive_player_effect='poison',passive_player_potency=0.4),rep=([('Coin',40)],60))
w(f='AbyssBow',n='Abyss Bow',ru='Лук Бездны',hy='Անդունդի աղեղ',d=('Violet bolts that spread corruption.','Фиолетовые болты разносят заражение.','Մանուշակագույն նետեր, որոնք տարածում են ապականություն։'),
  s=(8,6),p=dict(Damage=19,Atk_speed=0.95,max_durability=100,knockback=5.0,play_anim='Shoot',one_shot_attack=True,durability_per_shot=1,price=240,quality=5,
  on_hit_effect='corruption',on_hit_chance=0.3,on_hit_duration=6.0,on_hit_potency=2.0,on_hit_corruption_bonus=0.15),proj='AbyssBolt',rep=([('Coin',40)],60))
w(f='RailCarbine',n='Rail Carbine',ru='Рельсовый карабин',hy='Ռելսային կարաբին',d=('Slow, precise, fast bolts. One shot at a time.','Медленный, точный, с быстрыми болтами. Выстрел за выстрелом.','Դանդաղ, ճշգրիտ, արագ նետեր։ Մեկ կրակոց մեկ անգամ։'),
  s=(4,6),p=dict(Damage=24,Atk_speed=0.85,max_durability=90,knockback=12.0,play_anim='Shoot',one_shot_attack=True,durability_per_shot=1,price=175,quality=4),proj='LaserBolt',craft=[('Coin',130),('Fuel',25),('Stone',10)],rep=([('Fuel',20)],30))
w(f='Axenrang',n='Axenrang',ru='Топор-бумеранг',hy='Կացին-բումերանգ',d=('Throw it. It comes back. Hit things twice.','Брось — и он вернётся. Бьёт дважды.','Նետիր, կվերադառնա։ Երկու անգամ է հարվածում։'),
  s=(2,7),p=dict(Damage=20,Atk_speed=0.9,max_durability=120,knockback=8.0,play_anim='Shoot',one_shot_attack=True,durability_per_shot=1,price=100,quality=3),proj='AxenRang',craft=[('Coin',90),('Wood',12),('Stone',20)],rep=([('Wood',8)],15))
w(f='GoldenBoomerang',n='Golden Boomerang',ru='Золотой бумеранг',hy='Ոսկե բումերանգ',d=('Light and quick. Always returns.','Лёгкий и быстрый. Всегда возвращается.','Թեթև և արագ։ Միշտ վերադառնում է։'),
  s=(6,6),p=dict(Damage=12,Atk_speed=1.0,max_durability=150,knockback=4.0,play_anim='Shoot',one_shot_attack=True,durability_per_shot=1,price=70,quality=2),proj='Bumerang',craft=[('Coin',70),('Wood',8),('Fuel',4)],rep=([('Wood',6)],10))
w(f='Bomb',n='Bomb',ru='Бомба',hy='Ռումբ',d=('Explodes after a short flight. Careful with friends.','Взрывается после короткого полёта. Осторожно с друзьями.','Պայթում է կարճ թռիչքից հետո։ Զգույշ եղիր ընկերների հետ։'),
  s=(7,6),p=dict(Damage=22,Atk_speed=0.9,max_durability=10,play_anim='Shoot',one_shot_attack=True,consumable=True,stackable=True,max_count=20,price=8,quality=0),proj='Bomb',craft=[('Stone',6),('Fuel',4),('Coin',6)],amount=3)
w(f='Molotov',n='Molotov',ru='Зажигательная колба',hy='Հրկիզող շիշ',d=('Bursts into flames. Burns everything nearby.','Вспыхивает при ударе. Поджигает всех рядом.','Պայթում է կրակով։ Այրում է շրջակայքը։'),
  s=(7,7),p=dict(Damage=14,Atk_speed=0.9,max_durability=10,play_anim='Shoot',one_shot_attack=True,consumable=True,stackable=True,max_count=20,price=12,quality=1,
  on_hit_effect='burn',on_hit_chance=1.0,on_hit_duration=4.0,on_hit_potency=3.0),proj='Molotov',craft=[('Jar',1),('Fuel',6),('Coin',5)],amount=2)
w(f='FrostFlask',n='Frost Flask',ru='Ледяная колба',hy='Սառցե շիշ',d=('Shatters into freezing mist, slowing everyone nearby.','Разбивается ледяным туманом, замедляя всех рядом.','Կոտրվում է սառցե մշուշով՝ դանդաղեցնելով բոլորին։'),
  s=(6,7),p=dict(Damage=10,Atk_speed=0.9,max_durability=10,play_anim='Shoot',one_shot_attack=True,consumable=True,stackable=True,max_count=20,price=14,quality=1,
  on_hit_effect='freeze',on_hit_chance=1.0,on_hit_duration=3.5,on_hit_potency=0.45),proj='FrostFlask')
w(f='SpiderCaster',n='Spider Caster',ru='Паучий метатель',hy='Սարդի նետիչ',d=('Shoots three webs that slow enemies. Kite and stab.','Бросает три паутины, замедляющие врагов. Отступай и коли.','Արձակում է երեք ոստայն՝ դանդաղեցնելով թշնամիներին։'),
  s=(11,5),p=dict(Damage=5,Atk_speed=1.0,max_durability=80,knockback=2.0,play_anim='Shoot',one_shot_attack=True,num_projectiles=3,spread_degrees=40.0,durability_per_shot=1,price=90,quality=3,
  on_hit_effect='slow',on_hit_chance=1.0,on_hit_duration=4.0,on_hit_potency=0.5),proj='Web',craft=[('Coin',60),('Gel',6),('Wood',6)],rep=([('Gel',3)],10))
w(f='SwordOfLight',n='Sword of Light',ru='Меч Света',hy='Լույսի սուր',d=('Forged from artefact shards. Lights up the dark.','Выкован из осколков артефакта. Освещает тьму.','Պատրաստված է արտեֆակտի բեկորներից։ Լուսավորում է մթությունը։'),
  s=(6,5),p=dict(Damage=12,Atk_speed=1.2,hit_distance=13.0,max_durability=150,price=160,quality=4,
  passive_emits_light=True,passive_light_color=(1.0,0.95,0.55,1.0),passive_light_radius=220.0,passive_light_energy=1.1),craft=[('Piece',5),('Coin',60),('Fuel',10)],rep=([('Fuel',6)],20))
