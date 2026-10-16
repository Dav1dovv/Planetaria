import re,os,json,glob
P='/home/claude/proj'; O='/mnt/user-data/outputs/ContentPack'
def exists(path):
    rel=path.replace('res://','')
    return os.path.exists(os.path.join(O,rel)) or os.path.exists(os.path.join(P,rel))
errs=[]; names={}
tr=json.load(open(O+'/common/Translations/strings.json',encoding='utf-8'))
known_uids=set()
for f in glob.glob(P+'/**/*',recursive=True):
    if f.endswith('.uid'): known_uids.add(open(f).read().strip())
    elif f.endswith(('.tres','.tscn','.import')) and os.path.isfile(f):
        m=re.search(r'uid="(uid://[^"]+)"',open(f,encoding='utf-8',errors='ignore').read(2000)); 
        if m: known_uids.add(m.group(1))
files=glob.glob(O+'/**/*.tres',recursive=True)+glob.glob(O+'/**/*.tscn',recursive=True)
for f in files:
    t=open(f,encoding='utf-8').read(); rel=f[len(O)+1:]
    ids=set(re.findall(r'\[ext_resource [^\]]*id="([^"]+)"',t))
    sids=set(re.findall(r'\[sub_resource [^\]]*id="([^"]+)"',t))
    if len(ids)!=len(re.findall(r'\[ext_resource ',t)): errs.append((rel,'dup ext id'))
    for m in re.finditer(r'\[ext_resource ([^\]]*)\]',t):
        a=m.group(1); p=re.search(r'path="([^"]+)"',a).group(1)
        if not exists(p): errs.append((rel,'missing file '+p))
        u=re.search(r'uid="([^"]+)"',a)
        if u and u.group(1) not in known_uids and not u.group(1) in ('uid://dp5snq7fa0jqr',): errs.append((rel,'unknown uid '+u.group(1)+' '+p))
    for r in re.findall(r'ExtResource\("([^"]+)"\)',t):
        if r not in ids: errs.append((rel,'bad ExtResource '+r))
    for r in re.findall(r'SubResource\("([^"]+)"\)',t):
        if r not in sids: errs.append((rel,'bad SubResource '+r))
    for m in re.finditer(r'region = Rect2\((\d+), (\d+), (\d+), (\d+)\)',t):
        x,y,w,h=map(int,m.groups())
        if x+w>192 or y+h>160: errs.append((rel,'region OOB'))
    m=re.search(r'^item_name = "(.*)"$',t,re.M)
    if m and rel.startswith('misc/Content'):
        n=m.group(1); 
        if n in names: errs.append((rel,'dup item_name %s (also %s)'%(n,names[n])))
        names[n]=rel
        if n not in tr: errs.append((rel,'no translation for name'))
        d=re.search(r'^description = "(.*)"$',t,re.M)
        if d and d.group(1) not in tr: errs.append((rel,'no translation for desc'))
    d=re.search(r'^display_name = "(.*)"$',t,re.M)
    if d and d.group(1).replace("\\'","'") not in tr: errs.append((rel,'no tr display_name '+d.group(1)))
# existing item names
for f in glob.glob(P+'/misc/Content/Items/*.tres'):
    m=re.search(r'^item_name = "(.*)"$',open(f,encoding='utf-8').read(),re.M)
    if m:
        n=m.group(1)
        if f.endswith('TestBow.tres'): n='Test Bow'
        if n in names: errs.append((f,'dup with existing '+n))
        names[n]=f
# translations complete
for k,v in tr.items():
    for l in('en','ru','hy'):
        if not v.get(l): errs.append(('strings',k+' missing '+l))
# gd checks
for f in glob.glob(O+'/**/*.gd',recursive=True):
    t=open(f,encoding='utf-8').read(); rel=f[len(O)+1:]
    for i,l in enumerate(t.split('\n'),1):
        if re.match(r'^ +\S',l): errs.append((rel,'space indent line %d'%i))
    if t.count('(')!=t.count(')') or t.count('[')!=t.count(']') or t.count('{')!=t.count('}'): errs.append((rel,'unbalanced brackets'))
# json
json.load(open(O+'/common/Translations/strings.json',encoding='utf-8'))
print('files',len(files),'items',len(names),'errors',len(errs))
for e in errs: print(e)
