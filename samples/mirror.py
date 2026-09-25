# Line-by-line Python mirror of Analyzer.swift, for logic testing.
import re, statistics
from pair import lang as tag
def median(v):
    v=sorted(v); n=len(v)
    return 0 if not n else (v[n//2] if n%2 else (v[n//2-1]+v[n//2])/2)
MR=re.compile(r'^(\d{1,2})[.,]$'); IR=re.compile(r'^(\d{1,2})[.,]\s+(\S.*)$')
def S(text,x,y,w,h,page=0): return dict(text=text,x=x,y=y,w=w,h=h,page=page,mid=y+h/2,maxx=x+w)
def hasl(t): return any(c.isalpha() for c in t)
def analyze(inp,mode='auto'):   # mode: 'auto' | 'table' | 'numbered'
    rn=mode!='table'; rt=mode!='numbered'   # run Layout B / Layout A
    segs=[s for s in inp if hasl(s['text']) or MR.match(s['text'])]
    for s in segs: s.setdefault('lang',tag(s['text']))   # fixtures may pre-set real device tags
    R=dict(table=[],num=[],prob=[],left=[])
    mh=median([s['h'] for s in segs])
    pages=sorted({s['page'] for s in segs}); used=set()
    # Markers over ALL segments (headings not excluded yet). A lone tall title can
    # match IR, but survives only if it joins a list of >=3, so it can never
    # masquerade as numbered item 1.
    M=[]
    for i,s in enumerate(segs):
        m=MR.match(s['text']); n=IR.match(s['text'])
        if m: M.append(dict(n=int(m[1]),i=i,page=s['page'],x=s['x'],y=s['mid'],h=s['h'],mx=s['maxx'],tx=None,lines=[]))
        elif n:
            f=(len(s['text'])-len(n[2]))/max(len(s['text']),1)
            M.append(dict(n=int(n[1]),i=i,page=s['page'],x=s['x'],y=s['mid'],h=s['h'],mx=s['maxx'],tx=s['x']+s['w']*f,lines=[(s['mid'],n[2])]))
    markeridx={m['i'] for m in M}
    for m in M:
        if m['tx'] is not None: continue
        best=None
        for j,s in enumerate(segs):
            if j in markeridx or s['page']!=m['page']: continue
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
    if not rn: lists=[]   # Layout B off: don't detect or consume numbered items
    members=set()  # seg indices belonging to a real (>=3) numbered list
    NL=[]
    for L in lists:
        if len(L)<3: continue
        for m in L: used.add(m['i']); members.add(m['i'])
        L.sort(key=lambda m:m['y']); tx=median([m['tx'] for m in L]); pitch=median([b['y']-a['y'] for a,b in zip(L,L[1:])])
        lo=L[0]['y']-pitch; hi=L[-1]['y']+pitch; page=L[0]['page']
        # A bare marker ("1.") claims the text on its own row to the right. Done
        # per-row so a skewed page (text column drifting in x) can't strand it,
        # unlike the column band below.
        for m in L:
            if m['lines']: continue
            best=None
            for j,s in enumerate(segs):
                if j in used or s['page']!=page: continue
                if not(s['x']>m['x'] and s['x']-m['mx']<0.15 and abs(s['mid']-m['y'])<1.5*m['h']): continue
                d=abs(s['mid']-m['y'])
                if best is None or d<best[0]: best=(d,j)
            if best: m['lines'].append((segs[best[1]]['mid'],segs[best[1]]['text'])); used.add(best[1]); members.add(best[1])
        for j,s in enumerate(segs):
            if j in used or s['page']!=page: continue
            if s['h']<0.5*mh: continue  # footer / page-number bleed, not a real line
            if not(abs(s['x']-tx)<=0.025 and lo<=s['mid']<=hi): continue
            nr=min(L,key=lambda m:abs(m['y']-s['mid']))
            if abs(nr['y']-s['mid'])<1.2*pitch: nr['lines'].append((s['mid'],s['text'])); used.add(j); members.add(j)
        items={m['n']:' '.join(t for _,t in sorted(m['lines'])) for m in L}
        tags=[tag(v) for v in items.values()]; pl=tags.count('pl'); en=tags.count('en')
        NL.append(dict(lang='pl' if pl>en else 'en' if en>pl else '?',items=items,page=page))
    # Headings = tall lines that are NOT part of a numbered list (a large page
    # title, not an inflated body item). We don't surface a deck title, but still
    # set these aside so a big title can't be mispaired in Layout A.
    H={i for i,s in enumerate(segs) if s['h']>1.6*mh and i not in members}
    upl=set()
    for e in [k for k in range(len(NL)) if NL[k]['lang']=='en']:
        best=None
        for p in range(len(NL)):
            if NL[p]['lang']!='pl' or p in upl: continue
            ov=len(set(NL[e]['items'])&set(NL[p]['items']))
            if best is None or ov>best[0]: best=(ov,p)
        if not best or best[0]==0: R['prob'].append('no polish list'); continue
        upl.add(best[1]); E=NL[e]['items']; P=NL[best[1]]['items']
        ks=set(E)|set(P)   # only the numbers this page covers (exercises don't start at 1)
        for n in range(min(ks),max(ks)+1):
            if n in P and n in E: R['num'].append((n,P[n],E[n]))
            elif n in E: R['prob'].append(f'#{n} pl missing')
            elif n in P: R['prob'].append(f'#{n} en missing')
            else: R['prob'].append(f'#{n} both missing')
    for p in (pages if rt else []):   # Layout A off in 'numbered' mode
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
            rows=sorted(P['ix'],key=lambda k:segs[k]['mid'])           # polish lines
            ens=sorted(runs[best]['ix'],key=lambda k:segs[k]['mid'])   # english lines
            pitch=median([segs[b]['mid']-segs[a]['mid'] for a,b in zip(rows,rows[1:])]) if len(rows)>1 else 2*mh
            band=0.75*pitch    # a line links to the nearest opposite-column line within this
            mergeT=0.8*pitch   # wrapped/gendered lines are tighter than the entry pitch
            def M(k): return segs[k]['mid']
            par={}
            def find(a):
                par.setdefault(a,a); root=a
                while par[root]!=root: root=par[root]
                while par[a]!=root: par[a],a=root,par[a]
                return root
            def uni(a,b): par[find(a)]=find(b)
            for a in [('p',r) for r in rows]+[('e',e) for e in ens]: find(a)
            # R1: mutual-nearest cross-link within `band` (2 English for 1 Polish, or vice versa).
            nE={r:(min(ens,key=lambda e:abs(M(e)-M(r))) if ens else None) for r in rows}
            nP={e:(min(rows,key=lambda r:abs(M(r)-M(e))) if rows else None) for e in ens}
            crossed=set()
            for e in ens:
                r=nP[e]
                if r is not None and abs(M(r)-M(e))<band: uni(('e',e),('p',r)); crossed|={('e',e),('p',r)}
            for r in rows:
                e=nE[r]
                if e is not None and abs(M(e)-M(r))<band: uni(('p',r),('e',e)); crossed|={('p',r),('e',e)}
            # R2a: an orphan line (no cross-link) joins its nearest same-column neighbour.
            for col,seq in (('p',rows),('e',ens)):
                for i,k in enumerate(seq):
                    if (col,k) in crossed: continue
                    nb=[seq[j] for j in (i-1,i+1) if 0<=j<len(seq)]
                    if nb:
                        o=min(nb,key=lambda q:abs(M(q)-M(k)))
                        if abs(M(o)-M(k))<mergeT: uni((col,k),(col,o))
            # R2b: merge two adjacent cells that are ONE entry wrapped in both columns
            #      (e.g. "Wszystko"/"w porządku." <-> "Everything's"/"fine."). A wrap gap is a
            #      LOCAL MINIMUM — tighter on both sides than the neighbouring entry gaps — which
            #      is what tells it apart from two separate but tightly-spaced entries
            #      (narzeczony/narzeczona = fiancé/fiancée). Conservative at the column edges.
            for i in range(len(rows)-1):
                a,b=rows[i],rows[i+1]; g=M(b)-M(a)
                if g>=mergeT or i-1<0 or i+2>=len(rows): continue
                if not (g<M(a)-M(rows[i-1]) and g<M(rows[i+2])-M(b)): continue
                ea,eb=nE[a],nE[b]
                if ea is not None and eb is not None and ea!=eb and abs(M(ea)-M(eb))<mergeT:
                    uni(('p',a),('p',b))
            comp={}
            for a in par: comp.setdefault(find(a),[]).append(a)
            cards=[]
            for mem in comp.values():
                pl=sorted([n[1] for n in mem if n[0]=='p'],key=lambda k:segs[k]['mid'])
                en=sorted([n[1] for n in mem if n[0]=='e'],key=lambda k:segs[k]['mid'])
                if pl and en:
                    cards.append((segs[pl[0]]['mid'],' '.join(segs[k]['text'] for k in pl),' '.join(segs[k]['text'] for k in en)))
                    for k in pl+en: used.add(k)
            for _,pt,et in sorted(cards): R['table'].append((pt,et))
    R['left']=[segs[j]['text'] for j in range(len(segs)) if j not in used and j not in H and hasl(segs[j]['text'])]
    return R
def show(R):
    print('TABLE',len(R['table']))
    for t in R['table']: print('  ',t)
    print('NUM',len(R['num']))
    for t in R['num']: print('  ',t)
    print('PROB',R['prob']); print('LEFT',R['left'])
