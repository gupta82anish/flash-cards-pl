from mirror import *
# Synthetic "good OCR" of the verbs page, per the photo (after scanner flattening).
T=[]
T.append(S('1.',0.07,0.24,0.06,0.07)); T.append(S('USEFUL VERBS. PART 1',0.19,0.25,0.35,0.06))
c1=[('być',['to be']),('czekać',['to wait']),('czytać',['to read']),('dziękować',['to thank']),('gotować',['to cook']),('kochać',['to love']),('lubić',['to like']),('mieć',['to have']),('mieszkać',['to live','(somewhere)']),('mówić',['to speak'])]
c2=[('myśleć',['to think']),('odpoczywać',['to rest']),('oglądać',['to watch']),('pamiętać',['to remember']),('płacić',['to pay']),('podróżować',['to travel']),('pracować',['to work']),('przepraszać',['to be sorry,','to apologise']),('robić',['to do, to make']),('rozumieć',['to understand'])]
c3=[('słuchać',['to listen']),('słyszeć',['to hear']),('spieszyć się',['to be in a hurry']),('spóźniać się',['to be late']),('studiować',['to study','(at university)']),('zaczynać',['to start,','to begin']),('zamykać',['to close']),('zapraszać',['to invite'])]
def table(c,px,ex,y0):
    y=y0; lh=0.02; step=0.034
    for pl,en in c:
        if len(en)==1:
            T.append(S(pl,px,y,0.08,lh)); T.append(S(en[0],ex,y,0.09,lh)); y+=step
        else:
            T.append(S(pl,px,y+step*0.4,0.08,lh)); T.append(S(en[0],ex,y,0.09,lh)); T.append(S(en[1],ex,y+step*0.8,0.1,lh)); y+=step*1.8
table(c1,0.05,0.19,0.35); table(c2,0.34,0.48,0.36); table(c3,0.62,0.76,0.36)
T.append(S('1.',0.05,0.92,0.015,0.02)); T.append(S('What are you doing?',0.085,0.92,0.2,0.02))
show(analyze(T))
print('==========')
# Synthetic spread scanned as 2 pages: page0 English list (item 11 number next to 2nd line), page1 Polish list + margin notes + endings table
E=['What are you doing?','I understand everything.','They watch Netflix every day.','I live there.',"I'm sorry, but I don't remember.","He doesn't speak Polish.",'We often watch it.',"She doesn't understand anything.",'We usually rest here.',"I'm waiting for the bus.",None,'You never listen!','You speak all the time!',"We're paying together.",'Honey, what are you cooking?']
P=['Co robisz?','Wszystko rozumiem.','Codziennie oglądają Netflixa.','Mieszkam tam.','Przepraszam, ale nie pamiętam.','(On) nie mówi po polsku.','Często to oglądamy.','(Ona) nic nie rozumie.','Zwykle tu/tutaj odpoczywamy.','Czekam na autobus.',None,'Nigdy nie słuchasz!','Cały czas mówisz!','Płacimy razem.','Kochanie, co gotujesz?']
T=[S('mówić',0.04,0.02,0.1,0.025)]
y=0.08
for i,t in enumerate(E):
    n=i+1
    if t is None:
        T.append(S('Unfortunately, we are already closing.',0.07,y,0.4,0.02)); T.append(S('11.',0.03,y+0.022,0.02,0.02)); T.append(S('Please, come back tomorrow (lit. We invite',0.07,y+0.022,0.45,0.02)); T.append(S('tomorrow).',0.07,y+0.044,0.1,0.02)); y+=0.07
    else:
        T.append(S(f'{n}.',0.03,y,0.02,0.02)); T.append(S(t,0.07,y,0.35,0.02)); y+=0.052
y=0.13
for i,t in enumerate(P):
    n=i+1
    if t is None:
        T.append(S('11. Niestety już zamykamy. Zapraszamy',0.02,y,0.5,0.02,1)); T.append(S('jutro.',0.07,y+0.022,0.08,0.02,1)); y+=0.07
    else:
        T.append(S(f'{n}. {t}',0.02,y,0.4,0.02,1)); y+=0.052
for k,(a,b) in enumerate([('my (we)','-my'),('wy (you)','-cie'),('oni/one (they)','-ją/-ą*')]):
    T.append(S(a,0.10,0.01+k*0.025,0.12,0.02,1)); T.append(S(b,0.26,0.01+k*0.025,0.05,0.02,1))
for k,(num,t) in enumerate([('3','To watch Netflix).'),('11','niestety – unfortunately'),('12','nie piję kawy')]):
    T.append(S(num,0.88,0.15+k*0.2,0.02,0.02,1)); T.append(S(t,0.91,0.15+k*0.2,0.08,0.02,1))
show(analyze(T))
