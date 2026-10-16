# effects: key -> (display en,ru,hy, desc(en,ru,hy), type, value, duration, tick, max_stacks, iconIdx, color)
EFF={
 'RootRegen':('Root Tonic',  'Корневой тоник','Արմատների թուրմ',3,2.0,15.0,1.0,1,3,(0.4,0.8,0.3,1)),
 'RageDamage':('Rage',       'Ярость','Կատաղություն',2,0.30,40.0,1.0,1,2,(1.0,0.3,0.2,1)),
 'AntidoteResist':('Antidote','Противоядие','Հակաթույն',13,0.5,120.0,1.0,1,8,(0.7,0.3,0.9,1)),
 'GrogCold':('Fire Grog',    'Огненный грог','Կրակե գրոգ',12,0.0,180.0,1.0,1,7,(1.0,0.5,0.1,1)),
 'GrogDefense':('Warm Belly','Тёплое брюхо','Տաք փորիկ',4,0.15,180.0,1.0,1,4,(1.0,0.6,0.2,1)),
 'MeadSpeed':('Mead Rush',   'Медовый азарт','Մեղրային եռանդ',1,0.25,60.0,1.0,1,1,(1.0,0.8,0.3,1)),
 'MeadMining':('Miner\'s Mead','Шахтёрская медовуха','Հանքագործի մեղրագինի',5,0.30,60.0,1.0,1,1,(1.0,0.8,0.3,1)),
 'WineDefense':('Stout Wine','Стойкое вино','Կայուն գինի',4,0.35,30.0,1.0,1,4,(0.6,0.1,0.2,1)),
 'StarInvincible':('Starlight','Звёздный свет','Աստղային լույս',14,0.0,4.0,1.0,1,4,(1.0,1.0,0.4,1)),
 'StarSpeed':('Starry Dash', 'Звёздный рывок','Աստղային վազք',1,0.40,8.0,1.0,1,1,(1.0,1.0,0.4,1)),
 'RelicResist':('Elar\'s Ward','Оберег Элара','Էլարի պահպանություն',13,0.8,-1.0,1.0,1,8,(0.4,0.8,1.0,1)),
 'RelicRegenSoft':('Elar\'s Grace','Милость Элара','Էլարի շնորհ',3,0.5,-1.0,2.0,3,3,(0.4,0.8,1.0,1)),
 'RelicMining':('Miner\'s Pride','Гордость шахтёра','Հանքագործի հպարտություն',5,0.35,-1.0,1.0,1,1,(0.9,0.7,0.2,1)),
 'RelicRegenStrong':('Planet Pulse','Пульс планеты','Մոլորակի զարկ',3,1.5,-1.0,2.0,3,3,(1.0,0.3,0.2,1)),
 'RelicDefense15':('Knight\'s Guard','Стойкость рыцаря','Ասպետի պաշտպանություն',4,0.15,-1.0,1.0,3,4,(0.3,0.5,1.0,1)),
 'RelicDamage20':('Forbidden Power','Запретная сила','Արգելված ուժ',2,0.20,-1.0,1.0,2,2,(0.6,0.2,0.8,1)),
 'RelicTaint':('Tainted Pages','Осквернённые страницы','Ապականված էջեր',13,1.5,-1.0,1.0,1,12,(0.6,0.2,0.8,1)),
 'RelicLoot':('Fortune','Удача','Բախտ',15,0.2,-1.0,1.0,1,3,(1.0,0.85,0.3,1)),
 'RelicSpeed12':('Light Step','Лёгкий шаг','Թեթև քայլ',1,0.12,-1.0,1.0,3,1,(0.9,0.9,0.8,1)),
 'RelicCold':('Warding Crystal','Защитный кристалл','Պաշտպան բյուրեղ',12,0.0,-1.0,1.0,1,7,(0.5,0.9,1.0,1)),
 'RelicDefense8':('Crystal Skin','Кристальная кожа','Բյուրեղյա մաշկ',4,0.08,-1.0,1.0,3,4,(0.5,0.9,1.0,1)),
}
# icon idx map from effect type
ICON={3:3,2:2,13:8,12:7,4:4,1:1,5:1,14:4,15:9}
# potions: file,name,ru,hy,desc,(c,r),effects,props,recipe,amount
P=[
 dict(f='RootTonic',n='Root Tonic',ru='Корневой тоник',hy='Արմատների թուրմ',d=('Slowly mends wounds for 15 seconds.','Медленно лечит раны 15 секунд.','15 վայրկյան դանդաղ բուժում է վերքերը։'),
  s=(8,3),eff=['RootRegen'],hp=0.0,price=16,q=1,craft=[('Jar',1),('Wood',4),('Gel',1)],amount=2),
 dict(f='RageElixir',n='Rage Elixir',ru='Эликсир ярости',hy='Կատաղության էլիքսիր',d=('+30% damage for 40 seconds.','+30% к урону на 40 секунд.','+30% վնաս 40 վայրկյան։'),
  s=(9,3),eff=['RageDamage'],hp=0.0,price=28,q=2,craft=[('Jar',1),('Gel',2),('Fuel',2)],amount=1),
 dict(f='Antidote',n='Antidote',ru='Противоядие',hy='Հակաթույն',d=('Cleanses infection and halves new infection for 2 minutes.','Очищает заражение и вдвое замедляет новое на 2 минуты.','Մաքրում է վարակը և կիսով չափ դանդաղեցնում նորը 2 րոպե։'),
  s=(10,3),eff=['AntidoteResist'],hp=0.0,cure=40.0,rmv=20,price=30,q=2,craft=[('Jar',1),('Gel',3),('Coin',5)],amount=1),
 dict(f='FireGrog',n='Fire Grog',ru='Огненный грог',hy='Կրակե գրոգ',d=('Warms you up: immune to freezing for 3 minutes.','Согревает: иммунитет к заморозке на 3 минуты.','Տաքացնում է․ անձեռնմխելի սառեցման դեմ 3 րոպե։'),
  s=(9,4),eff=['GrogCold','GrogDefense'],hp=15.0,price=26,q=2,craft=[('Jar',1),('Fuel',5),('Coin',10)],amount=1),
 dict(f='HoneyMead',n='Honey Mead',ru='Медовуха',hy='Մեղրագինի',d=('Faster feet and faster pickaxe for a minute.','Быстрые ноги и быстрая кирка на минуту.','Արագ ոտքեր և արագ քլունգ մեկ րոպե։'),
  s=(10,4),eff=['MeadSpeed','MeadMining'],hp=10.0,price=24,q=2,craft=[('Jar',1),('Gel',1),('Coin',12)],amount=1),
 dict(f='DarkWine',n='Dark Wine',ru='Тёмное вино',hy='Մութ գինի',d=('Thick as blood. -35% damage taken for 30 seconds.','Густое, как кровь. -35% получаемого урона на 30 секунд.','Արյան պես թանձր։ -35% ստացվող վնաս 30 վայրկյան։'),
  s=(11,4),eff=['WineDefense'],hp=10.0,price=40,q=3),
 dict(f='StarShard',n='Star Shard',ru='Звёздный осколок',hy='Աստղի բեկոր',d=('Rare! A few seconds of invincibility and a burst of speed.','Редкость! Несколько секунд неуязвимости и рывок скорости.','Հազվագյուտ։ Մի քանի վայրկյան անխոցելիություն և արագություն։'),
  s=(5,0),eff=['StarInvincible','StarSpeed'],hp=0.0,price=80,q=5,anim='Eating'),
]
MAT=[
 dict(f='SlimeGel',n='Slime Gel',ru='Слизь',hy='Լորձ',d=('Sticky goo from slimes. A cauldron staple.','Липкая слизь. Основа многих зелий.','Կպչուն լորձ։ Շատ խմիչքների հիմքը։'),s=(0,1),price=4),
 dict(f='EmptyJar',n='Empty Jar',ru='Пустая банка',hy='Դատարկ բանկա',d=('Needed for potions and flasks.','Нужна для зелий и колб.','Անհրաժեշտ է խմիչքների և շշերի համար։'),s=(7,3),price=5,
  craft=[('Stone',3),('Fuel',1)],amount=2),
]
# relics: file,name,ru,hy,desc,(c,r),effects,quality,price
R=[
 dict(f='AmuletOfElar',n='Amulet of Elar',ru='Амулет Элара',hy='Էլարի ամուլետ',d=('Gift of the Elder. Slows infection, mends wounds. Works from the hotbar.','Дар Старейшины. Замедляет заражение и лечит. Работает в хотбаре.','Երեցի պարգևը։ Դանդաղեցնում է վարակը, բուժում է։ Աշխատում է արագ տողից։'),s=(2,2),eff=['RelicResist','RelicRegenSoft'],q=3),
 dict(f='MinersMedal',n="Miner's Medal",ru='Медаль шахтёра',hy='Հանքագործի մեդալ',d=('Awarded for stone brought to Bern. Mine 35% faster.','Награда за камень для Берна. Добыча быстрее на 35%.','Պարգև Բեռնին բերված քարի համար։ Արդյունահանում 35%-ով արագ։'),s=(11,3),eff=['RelicMining'],q=3),
 dict(f='HeartOfVehana',n='Heart of Vehana',ru='Сердце Ваханы',hy='Վեհանայի սիրտ',d=('Still beats. Heals you continuously. Reward for hunting elites.','Всё ещё бьётся. Постоянно лечит. Награда за охоту на элиту.','Դեռ բաբախում է։ Անընդհատ բուժում է։ Պարգև էլիտա որսալու համար։'),s=(1,1),eff=['RelicRegenStrong'],q=4),
 dict(f='CopperKnightHelm',n="Copper Knight's Helm",ru='Шлем Медного Рыцаря',hy='Պղնձե ասպետի սաղավարտ',d=('Taken from the fallen guardian. Reduces damage taken by 15%.','Снят с павшего стража. Снижает получаемый урон на 15%.','Վերցված է ընկած պահապանից։ Նվազեցնում է վնասը 15%-ով։'),s=(3,1),eff=['RelicDefense15'],q=4),
 dict(f='BoneRing',n='Bone Ring',ru='Костяное кольцо',hy='Ոսկրե մատանի',d=('Light as a feather. +12% move speed. Found on relic hunts.','Лёгкое, как перо. +12% к скорости. Находится в охоте за реликвиями.','Փետուրի պես թեթև։ +12% արագություն։ Գտնվում է մասունքների որսում։'),s=(6,1),eff=['RelicSpeed12'],q=2),
 dict(f='FortuneRing',n='Fortune Ring',ru='Кольцо удачи',hy='Բախտի մատանի',d=('20% chance to double loot drops. Found on relic hunts.','20% шанс удвоить добычу. Находится в охоте за реликвиями.','20% հավանականություն՝ ավարը կրկնապատկելու։ Գտնվում է մասունքների որսում։'),s=(5,1),eff=['RelicLoot'],q=3),
 dict(f='DarkGrimoire',n='Dark Grimoire',ru='Тёмный гримуар',hy='Մութ գրիմուար',d=('+20% damage, but infection builds 50% faster. Found on relic hunts.','+20% к урону, но заражение растёт на 50% быстрее. Находится в охоте за реликвиями.','+20% վնաս, բայց վարակը 50%-ով արագ է աճում։ Գտնվում է մասունքների որսում։'),s=(7,1),eff=['RelicDamage20','RelicTaint'],q=4),
 dict(f='GuardianCrystal',n='Guardian Crystal',ru='Кристалл-хранитель',hy='Պահապան բյուրեղ',d=('Immune to freezing, +8% defense. Found on relic hunts.','Иммунитет к заморозке, +8% защиты. Находится в охоте за реликвиями.','Անձեռնմխելի սառեցման դեմ, +8% պաշտպանություն։ Գտնվում է մասունքների որսում։'),s=(6,0),eff=['RelicCold','RelicDefense8'],q=4),
]
PROJ_NEW={ # name: (base scene, region, extra node props)
 'SlimeGlob':('Bullet',(67,1,10,10),{'speed':200.0,'lifetime':1.2,'damage':6.0},None),
 'AbyssBolt':('Bullet',(3,19,10,10),{'speed':240.0,'lifetime':1.2,'damage':19.0},'Color(0.75, 0.35, 1.0, 1)'),
 'LaserBolt':('Bullet',(18,23,12,3),{'speed':340.0,'lifetime':1.0,'damage':24.0},None),
 'Molotov':('Bomb',(112,112,16,16),{'speed':140.0,'bomb_timer':1.1,'damage':14.0,'explosion_radius':64.0},None),
 'FrostFlask':('Bomb',(96,112,16,16),{'speed':140.0,'bomb_timer':1.1,'damage':10.0,'explosion_radius':64.0},None),
}
