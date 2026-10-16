import os
OUT='/mnt/user-data/outputs/ContentPack'
class Raw(str): pass
def Q(s): return '"'+s.replace('\\','\\\\').replace('"','\\"').replace('\n','\\n')+'"'
def fv(v):
    if isinstance(v,Raw): return str(v)
    if isinstance(v,bool): return 'true' if v else 'false'
    if isinstance(v,int): return str(v)
    if isinstance(v,float): return repr(v)
    if isinstance(v,str): return Q(v)
    if isinstance(v,tuple): return 'Color(%s)'%', '.join(repr(float(x)) for x in v)
    raise TypeError(v)
SCRIPTS={
 'equip':('uid://b2ovoyoflp1gw','res://scr/Resources/ItemData/Equip_item_data.gd','equip_data'),
 'item':('uid://wm1t8anytdyq','res://scr/Resources/ItemData/ItemData.gd','ItemData'),
 'food':('uid://bw7mfbq68vy23','res://scr/Resources/ItemData/Food_item_data.gd','FoodData'),
 'acc':('uid://di2yssv3uj7uc','res://scr/Resources/ItemData/AcsesoryData.gd','AccessoryData'),
 'ing':('uid://bcg5vwna4id5n','res://scr/Systems/Craft/SimpleCraft/CraftIngeridents.gd',None),
 'effect':('uid://dj4umu6271nxr','res://scr/Resources/effects/EffectResource.gd','Effect'),
}
ATLAS=('uid://cf3avrbvs0ues','res://Assets/Textures/SpriteSheets/Items-Sheet.png')
MATS={'Coin':('uid://6utu3axt82j5','res://misc/Content/Items/Coin.tres'),
 'Stone':('uid://nv0xua18bp8x','res://misc/Content/Items/Stone.tres'),
 'Wood':('uid://0yo6ssv0d2rr','res://misc/Content/Items/Wood.tres'),
 'Fuel':('uid://dwmw15dg8pwvd','res://misc/Content/Items/Fuel.tres'),
 'Piece':('uid://feu6mm5l4c0h','res://misc/Content/Items/Artefact_Piece.tres'),
 'Gel':(None,'res://misc/Content/Items/Materials/SlimeGel.tres'),
 'Jar':(None,'res://misc/Content/Items/Materials/EmptyJar.tres')}
PROJ={'Arrow':'uid://bgoo5cwnuj0lj','AxenRang':'uid://4xi3n2b4v2r6','Bumerang':'uid://ci5gno40fiu81',
 'Bomb':'uid://dp5snq7fa0jqr','Snowball':'uid://d05er26oijlnt','Web':'uid://jl6w7073r4nv'}
EFFICON={1:'uid://b64un2hdo8wht',2:'uid://dkj52eeo80ghu',3:'uid://bhs2ikxc2auo4',4:'uid://cndi010t3aj7d',
 7:'uid://b4cg2jfbnlvlg',8:'uid://c04w0fs4kr4ao',9:'uid://c7amqpf5oy3p2',10:'uid://xwtyqtdiv8nb'}
PARTICLE=('uid://bpj1sgib1xsqp','res://misc/Particles/Effect.tscn')
DRINK=('uid://b15uoyeoq3550','res://Assets/Audio/SFX/Player/Drink.wav')
class Res:
    def __init__(s,kind): s.kind=kind; s.ext={}; s.exl=[]; s.subs=[]; s.props=[]; s.n=0
    def E(s,typ,path,uid=None):
        if path not in s.ext:
            s.n+=1; i='%d_%s'%(s.n,typ[:3].lower()); s.ext[path]=i; s.exl.append((typ,path,uid,i))
        return Raw('ExtResource("%s")'%s.ext[path])
    def sub(s,typ,props):
        s.n+=1; i='%s_%d'%(typ,s.n); s.subs.append((typ,i,props)); return Raw('SubResource("%s")'%i)
    def atlas(s,c,r):
        a=s.E('Texture2D',ATLAS[1],ATLAS[0])
        return s.sub('AtlasTexture',[('atlas',a),('region',Raw('Rect2(%d, %d, 16, 16)'%(c*16,r*16)))])
    def ings(s,lst):
        sc=s.E('Script',SCRIPTS['ing'][1],SCRIPTS['ing'][0]); out=[]
        for k,n in lst:
            u,p=MATS[k]; it=s.E('Resource',p,u)
            out.append(s.sub('Resource',[('script',sc),('item',it),('amount',n)]))
        return Raw('Array[ExtResource("%s")]([%s])'%(s.ext[SCRIPTS['ing'][1]],', '.join(out)))
    def render(s):
        sk=SCRIPTS[s.kind]
        L=['[gd_resource type="Resource" script_class="%s" format=3]'%sk[2],'']
        for t,p,u,i in s.exl: L.append('[ext_resource type="%s"%s path="%s" id="%s"]'%(t,' uid="%s"'%u if u else '',p,i))
        L.append('')
        for t,i,pr in s.subs:
            L.append('[sub_resource type="%s" id="%s"]'%(t,i)); L+= ['%s = %s'%(k,fv(v)) for k,v in pr]; L.append('')
        L.append('[resource]'); L+=['%s = %s'%(k,fv(v)) for k,v in s.props]
        L.append('metadata/_custom_type_script = "%s"'%sk[0]); return '\n'.join(L)+'\n'
def write(rel,text):
    p=os.path.join(OUT,rel); os.makedirs(os.path.dirname(p),exist_ok=True); open(p,'w',encoding='utf-8').write(text)
