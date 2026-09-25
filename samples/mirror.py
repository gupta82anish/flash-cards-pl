# Line-by-line Python mirror of Analyzer.swift, for logic testing.
import re, statistics
from pair import lang as tag
def median(v):
    v=sorted(v); n=len(v)
    return 0 if not n else (v[n//2] if n%2 else (v[n//2-1]+v[n//2])/2)
MR=re.compile(r'^(\d{1,2})[.,]$'); IR=re.compile(r'^(\d{1,2})[.,]\s+(\S.*)$')
def S(text,x,y,w,h,page=0): return dict(text=text,x=x,y=y,w=w,h=h,page=page,mid=y+h/2,maxx=x+w)
def hasl(t): return any(c.isalpha() for c in t)
def analyze(inp):
    segs=[s for s in inp if hasl(s['text']) or MR.match(s['text'])]
    for s in segs: s['lang']=tag(s['text'])
    R=dict(title=None,table=[],num=[],prob=[],left=[])
    mh=median([s['h'] for s in segs]); H={i for i,s in enumerate(segs) if s['h']>1.6*mh}
    pages=sorted({s['page'] for s in segs}); used=set()
    tc=[i for i in H if segs[i]['page']==pages[0] and segs[i]['mid']<0.35 and hasl(segs[i]['text'])]
    if tc: R['title']=re.sub(r'^\s*\d{1,2}[.,]?\s*','',segs[max(tc,key=lambda i:segs[i]['h'])]['text'])
    M=[]
    for i,s in enumerate(segs):
        if i in H: continue
        m=MR.match(s['text']); n=IR.match(s['text'])
        if m: M.append(dict(n=int(m[1]),i=i,page=s['page'],x=s['x'],y=s['mid'],h=s['h'],mx=s['maxx'],tx=None,lines=[]))
        elif n:
            f=(len(s['text'])-len(n[2]))/max(len(s['text']),1)
            M.append(dict(n=int(n[1]),i=i,page=s['page'],x=s['x'],y=s['mid'],h=s['h'],mx=s['maxx'],tx=s['x']+s['w']*f,lines=[(s['mid'],n[2])]))
    for m in M: used.add(m['i'])
    for m in M:
        if m['tx'] is not None: continue
        best=None
        for j,s in enumerate(segs):
            if j in used or j in H or s['page']!=m['page']: continue
            if not(s['x']>m['x'] and s['x']-m['mx']<0.15 and abs(s['mid']-m['y'])<1.5*m['h']): continue
            d=abs(s['mid']-m['y'])
            if best is None or d<best[0]: best=(d,j)
        if best: m['tx']=segs[best[1]]['x']
    lists=[]
    for p in pages:
        pm=sorted([m for m in M if m['page']==p and m['tx'] is not None],key=lambda m:m['x']); cur=[]
        for m in pm:
            if cur and m['x']-cur[-1]['x']>=0.05: lists.append(cur); cur=[]
            cur.append(m)
        if cur: lists.append(cur)
    NL=[]
    for L in lists:
        if len(L)<3: continue
        L.sort(key=lambda m:m['y']); tx=median([m['tx'] for m in L]); pitch=median([b['y']-a['y'] for a,b in zip(L,L[1:])])
        lo=L[0]['y']-pitch; hi=L[-1]['y']+pitch; page=L[0]['page']
        for j,s in enumerate(segs):
            if j in used or j in H or s['page']!=page: continue
            if not(abs(s['x']-tx)<=0.025 and lo<=s['mid']<=hi): continue
            nr=min(L,key=lambda m:abs(m['y']-s['mid']))
            if abs(nr['y']-s['mid'])<1.2*pitch: nr['lines'].append((s['mid'],s['text'])); used.add(j)
        items={m['n']:' '.join(t for _,t in sorted(m['lines'])) for m in L}
        tags=[tag(v) for v in items.values()]; pl=tags.count('pl'); en=tags.count('en')
        NL.append(dict(lang='pl' if pl>en else 'en' if en>pl else '?',items=items,page=page))
    upl=set()
    for e in [k for k in range(len(NL)) if NL[k]['lang']=='en']:
        best=None
        for p in range(len(NL)):
            if NL[p]['lang']!='pl' or p in upl: continue
            ov=len(set(NL[e]['items'])&set(NL[p]['items']))
            if best is None or ov>best[0]: best=(ov,p)
        if not best or best[0]==0: R['prob'].append('no polish list'); continue
        upl.add(best[1]); E=NL[e]['items']; P=NL[best[1]]['items']
        for n in range(1,max(set(E)|set(P))+1):
            if n in P and n in E: R['num'].append((n,P[n],E[n]))
            elif n not in P and n in E: R['prob'].append(f'#{n} pl missing')
            elif n in P: R['prob'].append(f'#{n} en missing')
            else: R['prob'].append(f'#{n} both missing')
    for p in pages:
        rest=sorted([j for j,s in enumerate(segs) if j not in used and j not in H and s['page']==p and not MR.match(s['text'])],key=lambda j:segs[j]['x'])
        cols=[]
        for j in rest:
            if cols and segs[j]['x']-segs[cols[-1][-1]]['x']<0.04: cols[-1].append(j)
            else: cols.append([j])
        runs=[]
        def mk(ix): return dict(ix=ix,minx=min(segs[k]['x'] for k in ix),top=min(segs[k]['y'] for k in ix),bot=max(segs[k]['y']+segs[k]['h'] for k in ix))
        for c in cols:
            cur=[]
            for j in sorted(c,key=lambda j:segs[j]['mid']):
                if cur and segs[j]['mid']-segs[cur[-1]]['mid']>4*mh: runs.append(mk(cur)); cur=[]
                cur.append(j)
            if cur: runs.append(mk(cur))
        def share(r,l): return sum(segs[k]['lang']==l for k in r['ix'])/len(r['ix'])
        ur=set()
        for pi in sorted([k for k in range(len(runs)) if len(runs[k]['ix'])>=3 and share(runs[k],'pl')>=0.6],key=lambda k:runs[k]['minx']):
            P=runs[pi]; best=None
            for ei,E in enumerate(runs):
                if ei==pi or ei in ur: continue
                if not(E['minx']>P['minx'] and len(E['ix'])>=3 and share(E,'en')>=0.6): continue
                ov=min(P['bot'],E['bot'])-max(P['top'],E['top']); sm=min(P['bot']-P['top'],E['bot']-E['top'])
                if not(sm>0 and ov/sm>=0.5): continue
                if best is None or E['minx']<runs[best]['minx']: best=ei
            if best is None: continue
            ur|={pi,best}
            rows=sorted(P['ix'],key=lambda k:segs[k]['mid'])
            pitch=median([segs[b]['mid']-segs[a]['mid'] for a,b in zip(rows,rows[1:])]) if len(rows)>1 else 2*mh
            ans={}
            for j in runs[best]['ix']:
                r=min(rows,key=lambda k:abs(segs[k]['mid']-segs[j]['mid']))
                if abs(segs[r]['mid']-segs[j]['mid'])<0.6*pitch: ans.setdefault(r,[]).append((segs[j]['mid'],segs[j]['text'])); used.add(j)
            for r in rows:
                if r in ans: R['table'].append((segs[r]['text'],' '.join(t for _,t in sorted(ans[r])))); used.add(r)
    R['left']=[segs[j]['text'] for j in range(len(segs)) if j not in used and j not in H and hasl(segs[j]['text'])]
    return R
def show(R):
    print('TITLE',R['title']); print('TABLE',len(R['table']))
    for t in R['table']: print('  ',t)
    print('NUM',len(R['num']))
    for t in R['num']: print('  ',t)
    print('PROB',R['prob']); print('LEFT',R['left'])
