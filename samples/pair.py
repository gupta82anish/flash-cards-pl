import re,statistics as st
from seg import segments
PLCH=set('ąćęłńóśźżĄĆĘŁŃÓŚŹŻ')
EN=set('to the you we i are be at a and is it he she they my your what for all of in never'.split())
PLW=set('nie co jak tam tu się na po ale już razem czas cały'.split())
def lang(t):
    if any(c in PLCH for c in t): return 'pl'
    ws=re.findall(r"[a-zA-Z']+",t.lower())
    if sum(len(w) for w in ws)<3: return '?'
    e=sum(w in EN for w in ws); p=sum(w in PLW for w in ws)
    if e>p: return 'en'
    if p>e: return 'pl'
    return '?'
def mid(s): return s['y']+s['h']/2
MARK=re.compile(r'^(\d{1,2})[.,]$'); INL=re.compile(r'^(\d{1,2})[.,]\s+(\S.*)$')
def analyze(segs):
    medh=st.median(s['h'] for s in segs)
    segs=[s for s in segs if re.search(r'[A-Za-zÀ-ž]',s['text']) or MARK.match(s['text'])]
    heading=[s for s in segs if s['h']>1.6*medh]
    body=[s for s in segs if s['h']<=1.6*medh]
    used=set()
    # --- numbered lists
    markers=[]
    for i,s in enumerate(body):
        m=MARK.match(s['text']); n=INL.match(s['text'])
        if m: markers.append(dict(n=int(m[1]),seg=i,x=s['x'],y=mid(s),h=s['h'],textx=None,lines=[]))
        elif n:
            frac=(len(s['text'])-len(n[2]))/len(s['text'])
            markers.append(dict(n=int(n[1]),seg=i,x=s['x'],y=mid(s),h=s['h'],textx=s['x']+s['w']*frac,lines=[(mid(s),n[2])]))
    for mk in markers:
        used.add(mk['seg'])
        if mk['textx'] is None:
            cand=[(abs(mid(s)-mk['y']),j) for j,s in enumerate(body) if j not in used and s['x']>body[mk['seg']]['x'] and s['x']-(mk['x']+body[mk['seg']]['w'])<0.15 and abs(mid(s)-mk['y'])<1.5*mk['h']]
            if cand:
                j=min(cand)[1]; mk['textx']=body[j]['x']
    # group markers into lists by x
    lists=[]
    for mk in sorted(markers,key=lambda m:m['x']):
        if lists and mk['x']-lists[-1][-1]['x']<0.05: lists[-1].append(mk)
        else: lists.append([mk])
    out_lists=[]
    for L in lists:
        L=[m for m in L if m['textx'] is not None]
        if len(L)<3: continue
        L.sort(key=lambda m:m['y'])
        tx=st.median(m['textx'] for m in L)
        pitch=st.median(b['y']-a['y'] for a,b in zip(L,L[1:]))
        lo=L[0]['y']-pitch; hi=L[-1]['y']+pitch
        for j,s in enumerate(body):
            if j in used or abs(s['x']-tx)>0.025 or not(lo<=mid(s)<=hi): continue
            d,mk=min((abs(mid(s)-m['y']),id(m),m) for m in L)[0::2]
            if d<1.2*pitch: mk['lines'].append((mid(s),s['text'])); used.add(j)
        items={m['n']:' '.join(t for _,t in sorted(m['lines'])) for m in L}
        lg=lang(' '.join(items.values()))
        out_lists.append((lg,items))
    pairs_b=[];missing=[]
    ens=[l for l in out_lists if l[0]=='en']; pls=[l for l in out_lists if l[0]=='pl']
    for e,p in zip(ens,pls):
        nums=sorted(set(e[1])|set(p[1]))
        for n in nums:
            if n in e[1] and n in p[1]: pairs_b.append((n,p[1][n],e[1][n]))
            else: missing.append((n,'pl' if n not in p[1] else 'en'))
    # --- tables
    rest=[(j,s) for j,s in enumerate(body) if j not in used]
    rest.sort(key=lambda t:t[1]['x'])
    cols=[]
    for j,s in rest:
        if cols and s['x']-cols[-1][-1][1]['x']<0.04: cols[-1].append((j,s))
        else: cols.append([(j,s)])
    def share(col,l): 
        tags=[lang(s['text']) for _,s in col]; return tags.count(l)/len(tags)
    pairs_a=[];left=[]
    i=0
    while i<len(cols)-1:
        P,E=cols[i],cols[i+1]
        if len(P)>=3 and len(E)>=3 and share(P,'pl')>=0.6 and share(E,'en')>=0.6:
            Ps=sorted(P,key=lambda t:mid(t[1])); pitch=st.median(mid(b[1])-mid(a[1]) for a,b in zip(Ps,Ps[1:]))
            got={j:[] for j,_ in Ps}
            for j,s in E:
                d,pj=min((abs(mid(s)-mid(ps)),pj) for pj,ps in Ps)
                if d<0.6*pitch: got[pj].append((mid(s),s['text']))
                else: left.append(('en',s['text']))
            for pj,ps in Ps:
                if got[pj]: pairs_a.append((ps['text'],' '.join(t for _,t in sorted(got[pj]))))
                else: left.append(('pl',ps['text']))
            i+=2
        else: i+=1
    title=max(heading,key=lambda s:s['h'])['text'] if heading else None
    return title,pairs_a,pairs_b,missing,left
if __name__=='__main__':
    import sys
    t,a,b,m,l=analyze(segments(sys.argv[1]))
    print(t,a,b,m,l)
