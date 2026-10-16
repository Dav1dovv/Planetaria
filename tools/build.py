import re,json,shutil,os
from lib import *
import data_weapons as DW, data_misc as DM
SRC='/home/claude/proj'
STR={}  # translations
def tr(key,ru,hy): STR[key]={'en':key,'ru':ru,'hy':hy}
def trd(d): tr(d[0],d[1],d[2])
def common(r,it,props):
    r.props.append(('icon',r.atlas(*it['s'])))
    return r
# ---------- effects
effpath={}
for k,(n,ru,hy,t,val,dur,tick,ms,ic,col) in DM.EFF.items():
    r=Res('effect'); sc=r.E('Script',SCRIPTS['effect'][1],SCRIPTS['effect'][0])
    idx=ic; tex=r.E('Texture2D','res://Assets/Textures/UI/Effects/Effect%d.png'%idx,EFFICON.get(idx))
    pr=r.E('PackedScene',PARTICLE[1],PARTICLE[0])
    r.props=[('script',sc),('effect_icon',tex),('effect_type',t)]
    if val: r.props.append(('value',val))
    if dur!=0: r.props.append(('duration',dur))
    if tick!=1.0: r.props.append(('tick_interval',tick))
    if ms>1: r.props.append(('max_stacks',ms))
    r.props+= [('particle_color',col),('particle',pr),('display_name',n)]
    rel='misc/Content/Effects/%s.tres'%k; effpath[k]=rel; write(rel,r.render()); tr(n,ru,hy)
def effs(r,keys):
    sc=r.E('Script',SCRIPTS['effect'][1],SCRIPTS['effect'][0])
    refs=[r.E('Resource','res://'+effpath[k]) for k in keys]
    return Raw('Array[ExtResource("%s")]([%s])'%(r.ext[SCRIPTS['effect'][1]],', '.join(refs)))
def base(kind,it):
    r=Res(kind); sc=r.E('Script',SCRIPTS[kind][1],SCRIPTS[kind][0]); r.props.append(('script',sc))
    r.props.append(('icon',r.atlas(*it['s'])))
    return r
def finish(r,it,folder,props_extra=()):
    for k,v in props_extra: r.props.append((k,v))
    write('%s/%s.tres'%(folder,it['f']),r.render())
    tr(it['n'],it['ru'],it['hy']); trd(it['d'])
ORDER=['lvl','Damage','Atk_speed','hit_distance','max_durability','equiped_weapon_sprite','projectile','is_weapon','num_projectiles','spread_degrees','projectile_speed','knockback','one_shot_attack','consumable','durability_per_shot']
# ---------- materials
for m in DM.MAT:
    r=base('item',m); r.props+= [('item_name',m['n']),('description',m['d'][0]),('price',m['price'])]
    if 'craft' in m: r.props+= [('craft_ingredients',r.ings(m['craft'])),('craft_amount',m['amount']),('craft_category',3)]
    finish(r,m,'misc/Content/Items/Materials')
# ---------- weapons
for it in DW.W:
    r=base('equip',it); p=dict(it['p'])
    r.props.append(('equiped_weapon_sprite',r.props[1][1]))
    if 'proj' in it:
        pn=it['proj']; 
        ref=r.E('PackedScene',(NEWP:=DW.NEWP)%pn,PROJ.get(pn))
        r.props.append(('projectile',ref))
    for k,v in p.items(): r.props.append((k,v))
    r.props.append(('item_name',it['n'])); r.props.append(('description',it['d'][0]))
    r.props.append(('stackable',p.pop('stackable',False)) if False else ('stackable',bool(p.get('stackable',False))))
    # remove duplicates (stackable in p already appended above) 
    seen=set(); out=[]
    for k,v in reversed(r.props):
        if k in seen: continue
        seen.add(k); out.append((k,v))
    r.props=list(reversed(out))
    if 'craft' in it:
        r.props.append(('craft_ingredients',r.ings(it['craft'])))
        if it.get('amount',1)>1: r.props.append(('craft_amount',it['amount']))
        # salvage: half
        sal=[(k,max(1,n//2)) for k,n in it['craft'] if k in('Coin','Stone','Wood','Fuel')]
        if sal and not p.get('consumable'): r.props.append(('salvage',r.ings(sal)))
    if 'rep' in it:
        ing,gold=it['rep']; r.props.append(('repair_ingredients',r.ings(ing))); r.props.append(('repair_gold_cost',gold))
    finish(r,it,'misc/Content/Items/Weapons')
# ---------- potions
for it in DM.P:
    r=base('food',it)
    r.props+= [('eat_sound',r.E('AudioStream',DRINK[1],DRINK[0])),('effects',effs(r,it['eff'])),('health_restore',it.get('hp',0.0))]
    if it.get('cure'): r.props.append(('cure_infection',it['cure']))
    if it.get('rmv'): r.props.append(('remove_corription',it['rmv']))
    r.props+= [('play_anim',it.get('anim','Drink')),('item_name',it['n']),('description',it['d'][0]),('price',it['price']),('quality',it['q'])]
    if 'craft' in it:
        r.props+= [('craft_ingredients',r.ings(it['craft'])),('craft_amount',it['amount']),('craft_category',2)]
    finish(r,it,'misc/Content/Items/Potions')
# ---------- relics
for it in DM.R:
    r=base('acc',it)
    r.props+= [('effects',effs(r,it['eff'])),('item_name',it['n']),('description',it['d'][0]),('stackable',False),('max_count',1),('price',100),('quality',it['q'])]
    finish(r,it,'misc/Content/Artifacts')
# ---------- projectile scenes
for name,(bs,reg,props,mod) in DM.PROJ_NEW.items():
    t=open('%s/misc/Projectiles/%s.tscn'%(SRC,bs),encoding='utf-8').read()
    t=re.sub(r'^\[gd_scene format=3 uid="[^"]*"\]','[gd_scene format=3]',t)
    t=re.sub(r'region_rect = Rect2\([^)]*\)','region_rect = Rect2(%d, %d, %d, %d)'%reg,t,count=1)
    lines=t.split('\n'); 
    i=next(j for j,l in enumerate(lines) if l.startswith('script = ExtResource') and j>0 and 'node' in ''.join(lines[max(0,j-2):j]))
    for k,v in props.items():
        pat=re.compile(r'^%s = '%k)
        # replace within root block (until first blank line after i)
        e=i
        while lines[e].strip()!='' : e+=1
        hit=[j for j in range(i,e) if pat.match(lines[j])]
        if hit: lines[hit[0]]='%s = %r'%(k,v)
        else: lines.insert(i+1,'%s = %r'%(k,v)); 
    t='\n'.join(lines)
    if mod: t=t.replace('region_rect = Rect2(%d, %d, %d, %d)'%reg,'region_rect = Rect2(%d, %d, %d, %d)\nmodulate = %s'%(reg+(mod,)),1)
    write('misc/Projectiles/%s.tscn'%name,t)
# ---------- translations merge
ui={'Slow':('Замедление','Դանդաղեցում'),'Burn':('Поджог','Այրոց'),'Poison':('Яд','Թույն'),'Freeze':('Заморозка','Սառեցում'),
 'Bleed':('Кровотечение','Արյունահոսություն'),'Corruption':('Заражение','Ապականում'),'Heal on hit':('Лечение при ударе','Բուժում հարվածից'),
 'On hit':('При ударе','Հարվածից'),'Chance':('Шанс','Հավանականություն'),'Passive':('Пассив','Պասիվ'),'Consumable':('Расходуется','Սպառվող'),
 'Works from hotbar':('Работает, пока лежит в хотбаре','Աշխատում է արագ տողում'),'Reach':('Дальность','Հասողություն'),'Speed':('Скорость атаки','Հարվածի արագություն'),
 'Emits light':('Излучает свет','Լույս է արձակում'),'Lunge':('Рывок при ударе','Նետում հարվածի ժամանակ'),'Holder takes poison':('Владелец отравляется','Տերը թունավորվում է'),
 'Defense':('Защита','Պաշտպանություն'),'RELIC HUNT!':('ОХОТА ЗА РЕЛИКВИЕЙ!','ՄԱՍՈՒՆՔԻ ՈՐՍ!'),'Find the relic — follow the arrow':('Найди реликвию — иди за стрелкой','Գտիր մասունքը՝ հետևիր սլաքին'),
 'Relic':('Реликвия','Մասունք'),'Relic found!':('Реликвия найдена!','Մասունքը գտնված է!'),'Relics of Vehana':('Реликвии Ваханы','Վեհանայի մասունքներ'),
 'Eight relics lie hidden across Vehana. Find them all.':('Восемь реликвий спрятаны на Вехане. Найди их все.','Ութ մասունք թաքնված է Վեհանայում։ Գտիր բոլորը։'),
 'Cooper Knight':('Медный Рыцарь','Պղնձե ասպետ'),'Relic obtained: ':('Получена реликвия: ','Ստացված մասունք՝ ')}
for k,(a,b) in ui.items(): tr(k,a,b)
p=SRC+'/common/Translations/strings.json'
d=json.load(open(p,encoding='utf-8'))
added=0
for k,v in STR.items():
    if k in d: 
        # don't overwrite existing
        continue
    d[k]=v; added+=1
write('common/Translations/strings.json',json.dumps(d,ensure_ascii=False,indent='\t')+'\n')
print('strings added',added,'total',len(d))
