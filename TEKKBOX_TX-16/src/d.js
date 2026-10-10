/* ---------- Pixel-Anzeigen ---------- */
const LW=240,LH=144,LS=6,OW=177,OH=20,OS=4;
const mk=(w,h)=>{const c=document.createElement('canvas');c.width=w;c.height=h;return c;};
const lcdSrc=mk(LW,LH),lcdGrid=mk(LW*LS,LH*LS),oledSrc=[mk(OW,OH),mk(OW,OH)],oledGrid=mk(OW*OS,OH*OS);
function makeGrid(c,w,h,S,bg,off){const g=c.getContext('2d');g.fillStyle=bg;g.fillRect(0,0,c.width,c.height);g.fillStyle=off;for(let y=0;y<h;y++)for(let x=0;x<w;x++)g.fillRect(x*S,y*S,S-1,S-1);}
{const g=lcdGrid.getContext('2d');g.fillStyle='#070b10';g.fillRect(0,0,lcdGrid.width,lcdGrid.height);}makeGrid(oledGrid,OW,OH,OS,'#020203','#0b0b0e');
function pixelate(src,dst,gridC,S,on,solid){const sw=src.width,sh=src.height,d=src.getContext('2d').getImageData(0,0,sw,sh).data,g=dst.getContext('2d'),q=solid?S:S-1;g.drawImage(gridC,0,0);g.fillStyle=on;for(let y=0;y<sh;y++)for(let x=0;x<sw;x++)if(d[(y*sw+x)*4+3]>110)g.fillRect(x*S,y*S,q,q);}
function L(g,s,x,y,size=8,align='left'){g.font=`${size}px ${LF}`;g.textAlign='left';g.textBaseline='top';const w=g.measureText(s).width;g.fillText(s,Math.round(align==='center'?x-w/2:align==='right'?x-w:x),Math.round(y));return w;}
function inv(g,fn){g.globalCompositeOperation='destination-out';fn();g.globalCompositeOperation='source-over';g.fillStyle='#fff';}
function hdr(g,l,c,r){g.fillStyle='#fff';g.fillRect(0,0,LW,11);inv(g,()=>{L(g,l,3,2);if(c)L(g,c,LW/2,2,8,'center');if(r)L(g,r,LW-3,2,8,'right');});}
function box(g,x,y,w,h){g.fillRect(x,y,w,1);g.fillRect(x,y+h-1,w,1);g.fillRect(x,y,1,h);g.fillRect(x+w-1,y,1,h);}
function barG(g,x,y,w,h,v){box(g,x,y,w,h);g.fillRect(x+2,y+2,Math.round((w-4)*clamp(v)),h-4);}
const scopeBuf=new Float32Array(2048);
function envShape(g,x0,y0,w,amp,P){
  const gs=gateSteps(P.dec),aw=P.egOn?4+P.att*P.att*70:2,dw=8+P.dec*P.dec*150,hold=P.egOn&&P.dec>.97,gw=Math.min(w-4,14+Math.log2(gs*4)/8*(w-30));
  const S=P.egOn&&!hold?(P.egS||0):0,gx=aw+dw*1.3+16,rw=6+Math.pow(P.egR??.15,2)*110;
  const env=x=>P.egOn?(x<aw?x/aw:hold?1:S>.005?(x<gx?S+(1-S)*Math.exp(-(x-aw)/dw*2.2):S*Math.exp(-(x-gx)/rw*2.2)):Math.exp(-(x-aw)/dw*2.2)):(x<gw?1:0);
  let py=null;for(let x=0;x<w;x++){const e=env(x),y=Math.round(y0-Math.sin(x*.55)*amp*e);const a=py===null?y:py;g.fillRect(x0+x,Math.min(y,a),1,Math.abs(y-a)+1);py=y;
    if(x%3===0){g.fillRect(x0+x,Math.round(y0-amp*e)-1,1,1);}}
}
const SCR={
  off(g){hdr(g,'TX-16','POWER OFF','');L(g,'TEKKBOX',LW/2,26,24,'center');L(g,'PRESS EINSCHALTEN',LW/2,62,8,'center');L(g,'REV 2.0 · EMX OSC + SAMPLE + TUBE',LW/2,80,8,'center');},
  fill(g,p){const F=ui.fill;if(!F){L(g,'FILL DONE',LW/2,40,16,'center');return;}const nb=cur.last/16,w=Math.floor((LW-8)/nb);hdr(g,'FILL · '+(F.all?'ALL PARTS':'PART '+pad2(ui.part+1)+' '+PARTS[ui.part]),null,F.stage==='src'?'1/2':'2/2');
    L(g,F.stage==='src'?'SOURCE BAR?':'TARGET BARS?',3,15,16);L(g,F.stage==='src'?'PAD 17-24 = BAR':'BAR '+(F.src+1)+' >',LW-3,18,8,'right');
    for(let b=0;b<nb;b++){const x=4+b*w,on=b===F.src||F.dst.has(b);if(on){g.fillRect(x,42,w-3,30);inv(g,()=>{L(g,String(b+1),x+(w-3)/2,46,16,'center');L(g,b===F.src?'SRC':'DST',x+(w-3)/2,62,8,'center');});}else{box(g,x,42,w-3,30);L(g,String(b+1),x+(w-3)/2,46,16,'center');}}
    L(g,p.err||(F.dst.size?'TO BARS '+[...F.dst].sort((a,b)=>a-b).map(b=>b+1).join(','):'NO TARGET = ALL BARS'),3,80);
    g.fillRect(3,96,LW-6,14);inv(g,()=>L(g,'FILL / ENTER = COPY   EXIT = CANCEL',LW/2,99,8,'center'));},
  home(g,p,t){
    const P=cur.parts[ui.part];hdr(g,patStr()+(ui.pendingPat?'>'+pad3(ui.pendingPat):'')+(ui.paused?' PAUSE':''),'PART '+pad2(ui.part+1)+' '+PARTS[ui.part],(ui.ramp?'>':'')+G.bpm.toFixed(1));
    L(g,patName()+(ui.saved?'':'*'),3,15,16);L(g,KEYS[cur.key]+' '+SCALES[cur.scale].slice(0,5),LW-3,15,8,'right');L(g,TLOCK[G.tlock]==='OFF'?'':'T.'+TLOCK[G.tlock],LW-3,24,8,'right');
    L(g,partSrcName(P).slice(0,24),3,34);L(g,MODE_SHORT[ui.mode]+' OCT'+(P.oct>=0?'+':'')+P.oct+' '+['MONO1','MONO2','POLY1','POLY2'][P.voice??0]+(P.choke?' CH'+P.choke:''),LW-3,34,8,'right');
    box(g,3,45,94,37);
    if(E){E.anOut.getFloatTimeDomainData(scopeBuf);let py=null;for(let x=0;x<90;x++){const v=scopeBuf[x*20]||0,y=Math.round(63-clamp(v,-1,1)*16);const a=py===null?y:py;g.fillRect(5+x,Math.min(y,a),1,Math.abs(y-a)+1);py=y;}}else g.fillRect(5,63,90,1);
    const on=P.fx.map((f,k)=>f.on?k:-1).filter(k=>k>=0),m=ui.mfx[0];
    L(g,'IFX '+(on.length?on.length+' ON: '+NUM.fxType(P.fx[on[0]].type).slice(0,14):'OFF'),102,46);
    L(g,'EG '+(P.egOn?'ON':'OFF > GATE')+(P.send?'':' · NO MFX'),102,55);
    L(g,(ui.padMode===1?'ARP '+NUM.arp(cur.gateArp||0):ui.padMode===2?'T.SCALE '+SCALES[cur.scale]:'MFX '+NUM.mfx(m.type)).slice(0,22)+(ui.rec?' >P'+pad2(ui.part+1):''),102,64);L(g,'ROLL '+NUM.roll(ui.rollType),102,73);
    const bar=curBar(),page=ui.pageSel,s=ui.dispStep%16;
    if(ui.part>=NSEQ)L(g,'LIVE PART · PADS 17-24 · NO STEPS',3,87);else for(let i=0;i<16;i++){const x=3+i*12,st=page*16+i,on2=cur.steps[ui.part][st];if(on2)g.fillRect(x,86,10,8);else box(g,x,86,10,8);if(ui.playing&&page===bar&&i===s)g.fillRect(x,96,10,2);}
    L(g,'B'+(page+1)+'/'+(cur.last/16),LW-3,87,8,'right');
    L(g,NUM.ftype(P.ftype)+(P.ftrack?' TRK '+Math.round(voiceCut(P,57))+' HZ':' '+Math.round(cutHzOf(P))+' HZ')+'  RES '+pad3(Math.round(P.reso*127)),3,102);L(g,(P.tube?'TUBE':'CLEAN')+(P.glueOn?' GLUE':''),LW-3,102,8,'right');
    if(ui.limHot&&t-ui.limHot<1500&&Math.floor(t/300)%2){g.fillRect(0,110,LW,12);inv(g,()=>L(g,'LIMIT! ZU LAUT · LEVEL/MASTER RUNTER',LW/2,112,8,'center'));}else L(g,'EQ DRV '+Math.round(P.eqD*100)+'% MIX '+Math.round(P.eqX*100)+'%  SC '+Math.round(P.sc*100)+'%',3,112);L(g,(P.loopN?'LOOP/'+P.loopN+' ':'')+MODE_SHORT[ui.mode],LW-3,112,8,'right');
  },
  sound(g){const P=cur.parts[ui.part];hdr(g,'SOUND · PART '+pad2(ui.part+1)+' '+PARTS[ui.part],null,'TOUCH');
    SOUNDROWS.forEach(([k,id],j)=>{const x=j<6?3:122,y=15+(j%6)*14,v=valStr(CTRL[id]).slice(0,12);if(ui.lastCtrl===id){g.fillRect(x-2,y-2,117,12);inv(g,()=>{L(g,k,x,y);L(g,v,x+113,y,8,'right');});}else{L(g,k,x,y);L(g,v,x+113,y,8,'right');}});
    L(g,'TAP = SELECT   VALUE = CHANGE',LW/2,104,8,'center');},
  param(g,p){const d=p.d;hdr(g,(d.sect||d.label)+(d.g?'':' · PART '+pad2(ui.part+1)));L(g,d.label,3,16,16);L(g,valStr(d),LW-3,40,d.id==='sc'?16:24,'right');
    if(isCen(d)){const v=knobGet(d);box(g,3,76,LW-6,10);g.fillRect(LW/2,74,1,14);const a=Math.round((LW-10)*(v-.5));g.fillRect(a<0?LW/2+a:LW/2,78,Math.abs(a),6);}else barG(g,3,76,LW-6,10,knobGet(d));
    L(g,d.id==='sc'?'SHIFT + TURN = SOURCE PART':shiftNow()?(d.det?'SHIFT: X10':'SHIFT: FINE'):d.det==='center'?'CENTER = STOP':'',3,90);},
  type(g,p){const n=p.list.length,it=String(p.list[p.idx]),m=it.match(/^(\d+)\s+(.*)$/),num=m?m[1]:pad2(p.idx+1),name=m?m[2]:it;hdr(g,p.title,null,'NO. '+num+' / '+n);
    g.fillRect(3,15,58,30);inv(g,()=>L(g,num,32,19,24,'center'));L(g,name.slice(0,11),66,17,16);L(g,name.slice(11,30),66,35);
    L(g,'< '+String(p.list[(p.idx+n-1)%n]).slice(0,17),3,52);L(g,String(p.list[(p.idx+1)%n]).slice(0,17)+' >',LW-3,64,8,'right');if(p.extra)L(g,p.extra.slice(0,38),3,78);L(g,shiftNow()?'SHIFT: JUMP 10':'',3,90);},
  pattern(g){hdr(g,'PATTERN');const n=ui.pendingPat||ui.pattern;L(g,patStr(n),LW/2,18,24,'center');L(g,patName(n),LW/2,48,8,'center');
    L(g,ui.pendingPat?'SWITCH AT NEXT BAR':ui.saved?'LOADED · '+cur.bpm.toFixed(0)+' BPM':'NOT SAVED *',LW/2,62,8,'center');L(g,'TEMPO LOCK '+TLOCK[G.tlock]+(G.tlock===2?' '+G.rampBars+' BARS':''),LW/2,76,8,'center');L(g,'SHIFT + TURN = 10ER SPRUNG',LW/2,88,8,'center');},
  write(g,p,t){const w=ui.write;hdr(g,w.stage==='as'?'SAVE AS':'SAVE PATTERN');
    if(w.stage==='confirm'){L(g,patStr()+'  '+patName(),3,16);L(g,'PRESS SAVE AGAIN',LW/2,36,16,'center');L(g,'TO STORE '+patStr(),LW/2,62,8,'center');}
    else if(w.stage==='as'){L(g,'FROM '+patStr(),3,16);L(g,'TO '+patStr(w.target),LW/2,32,24,'center');L(g,'TURN PATTERN OR VALUE',LW/2,66,8,'center');L(g,'SAVE = STORE   EXIT = CANCEL',LW/2,80,8,'center');}
    else if(w.stage==='writing'){L(g,'SAVING '+patStr(w.target||ui.pattern),LW/2,34,16,'center');barG(g,20,62,LW-40,10,(t-w.t)/900);}
    else if(w.stage==='fail'){L(g,'NO STORAGE',LW/2,34,16,'center');L(g,'BROWSER BLOCKS SAVING',LW/2,62,8,'center');}
    else{L(g,'COMPLETE!',LW/2,34,16,'center');L(g,'STORED IN THIS BROWSER',LW/2,62,8,'center');}},
  mode(g){hdr(g,'PLAY MODE');L(g,ui.mode,LW/2,18,16,'center');L(g,MODE_DESC[ui.mode],LW/2,40,8,'center');
    for(let i=0;i<16;i++){const x=8+i*14,on=ui.mode==='SEQUENCER'||ui.mode==='STEP JUMP'?(cur.steps[ui.part]||[])[ui.pageSel*16+i]:ui.mode==='KEYBOARD'||ui.mode==='CHORD'?1:!ui.muted.has(i);if(on)g.fillRect(x,60,12,16);else box(g,x,60,12,16);}
    L(g,'SHIFT + PAD = SELECT PART',LW/2,86,8,'center');},
  msg(g,p){hdr(g,p.t);L(g,p.b,LW/2,24,16,'center');if(p.s)L(g,p.s,LW/2,52,8,'center');},
  mute(g){grid16(g,'PART MUTE · SHIFT+MUTE = ALL ON',i=>!ui.muted.has(i),'MUTE');},
  solo(g){grid16(g,ui.solo.size?'SOLO · HOLD MUTE + PAD · SHIFT+MUTE = ALL':'SOLO OFF · ALL PARTS PLAY',i=>ui.solo.size?ui.solo.has(i):true,'-');},
  menu(g){const m=MENU[ui.menu],n=m.items.length,top=clamp(ui.menuItem-1,0,Math.max(0,n-4));hdr(g,'MENU '+(ui.menu+1)+'/'+MENU.length,ui.menuEdit?'EDIT':null,(ui.menuItem+1)+'/'+n);L(g,m.t,3,14,16);
    for(let j=top;j<Math.min(n,top+4);j++){const it=m.items[j],y=34+(j-top)*12,v=String(it.v()),sel=j===ui.menuItem;
      if(sel&&ui.menuEdit){L(g,'> '+it.k,4,y);const w=g.measureText(v).width;g.fillRect(LW-10-w,y-2,w+8,11);inv(g,()=>L(g,v,LW-6,y,8,'right'));}
      else if(sel){g.fillRect(0,y-2,LW,11);inv(g,()=>{L(g,it.k,4,y);L(g,v,LW-4,y,8,'right');});}
      else{L(g,it.k,4,y);L(g,v,LW-4,y,8,'right');}}
    if(m.t==='STEP EDIT'&&ui.part<NSEQ){const ss=clamp(ui.stepSel,0,cur.last-1),b0=Math.floor(ss/16)*16;for(let i=0;i<16;i++){const x=4+i*14.6,st=b0+i;if(cur.steps[ui.part][st])g.fillRect(x,100,12,9);else box(g,x,100,12,9);if(st===ss)g.fillRect(x,111,12,2);}}
    const it=m.items[ui.menuItem];L(g,ui.menuEdit?'VALUE = CHANGE   ENTER = DONE':it.enter?'VALUE = UP/DOWN   ENTER = DO IT':it.adj?'VALUE = UP/DOWN   ENTER = EDIT':'VALUE = UP/DOWN   PAGE = NEXT',LW/2,89,8,'center');},
  xy(g,p){const m=ui.mfx[p.i],t=m.touch;hdr(g,'MASTER FX '+(p.i+1),null,m.hold?'HOLD':'');L(g,MFXS[m.type],3,16,16);L(g,m.on?'FX ON':'FX OFF',3,38);
    L(g,'X '+(t?pad3(Math.round(t[0]*127)):'---'),3,50);L(g,'Y '+(t?pad3(Math.round((1-t[1])*127)):'---'),3,60);L(g,ui.rec?'REC: ONLY PART '+pad2(ui.part+1):'ON ALL PARTS WITH SEND',3,72);L(g,XYP[m.type],3,84);
    box(g,150,14,86,84);if(t){const x=151+Math.round(t[0]*82),y=15+Math.round(t[1]*80);g.fillRect(x,15,1,82);g.fillRect(151,y,84,1);g.fillRect(x-3,y-3,7,7);}},
  stretch(g){const P=cur.parts[ui.part],m=P.stretch,nb=cur.last/16,ln=stretchSteps(P)/16,N=P.loopN;hdr(g,'STRETCH + LOOP · PART '+pad2(ui.part+1));
    L(g,['OFF','KEEP LENGTH','BPM SYNC'][m],3,15,16);L(g,m===2?'FITS '+stretchSteps(P)+' STEPS @ '+G.bpm.toFixed(1):m===1?'SAME SECONDS':'PITCH = SPEED',LW-3,18,8,'right');
    L(g,'LENGTH '+stretchSteps(P)+' STEPS',3,36);L(g,N?'LOOP EVERY '+N+(N>1?' BARS':' BAR'):'LOOP OFF',LW/2,36,8,'center');L(g,N?Math.ceil(nb/N)+'X PER PATTERN':'STEPS ONLY',LW-3,36,8,'right');
    const w=Math.floor((LW-8)/Math.max(1,nb));for(let b=0;b<nb;b++){const x=4+b*w;box(g,x,50,w-2,22);L(g,String(b+1),x+3,52);}
    if(N)for(let b=0;b<nb;b+=N){const x=4+b*w,len=Math.min(ln,N,nb-b);g.fillRect(x+2,61,len*w-6,8);}
    L(g,'MENU > PART: STRETCH LENGTH, LOOP EVERY',3,80);L(g,m===2?'MELODY FOLLOWS THE TEMPO':'STRETCH = BPM SYNC FOR MELODIES',3,92);},
  eg(g){const P=cur.parts[ui.part];if(P.egOn)return SCR.egedit(g);hdr(g,'AMP EG · PART '+pad2(ui.part+1),null,P.egOn?'EG ON':'EG OFF');L(g,P.egOn?'ATTACK + DECAY':'GATE TIME',3,14,16);
    box(g,3,32,LW-6,46);envShape(g,6,55,LW-12,19,P);
    L(g,P.egOn?'A '+pad3(Math.round(P.att*127))+' D '+(P.dec>.97?'HOLD':pad3(Math.round(P.dec*127)))+' S '+((P.egS||0)<.005?'OFF':pad3(Math.round(P.egS*127)))+' R '+Math.round(egRelT(P)*1000)+'MS':'DECAY KNOB = '+gateSteps(P.dec)+' STEPS · FLAT',3,82);L(g,P.egOn?'DECAY = WAVE GETS SMALLER':'EG ON = DECAY CURVE',3,91);},
  ifx(g,p){const P=cur.parts[ui.part];hdr(g,'INSERT FX · PART '+pad2(ui.part+1),null,'SELECT '+(ui.fxSel+1)+'/5');
    for(let k=0;k<5;k++){const f=P.fx[k],x=3+k*47,sel=k===ui.fxSel;
      if(f.on){g.fillRect(x,14,45,32);inv(g,()=>{L(g,'IFX '+(k+1),x+22,16,8,'center');L(g,pad3(f.type+1),x+22,26,8,'center');L(g,'ON',x+22,36,8,'center');});}
      else{box(g,x,14,45,32);L(g,'IFX '+(k+1),x+22,16,8,'center');L(g,pad3(f.type+1),x+22,26,8,'center');L(g,'OFF',x+22,36,8,'center');}
      if(sel){g.fillRect(x+16,48,13,3);}}
    const f=selFx();g.fillRect(3,52,50,19);inv(g,()=>L(g,pad3(f.type+1),28,54,16,'center'));L(g,IFXS[f.type].slice(0,16),58,55,16);barG(g,3,73,LW-6,8,f.edit);L(g,'- + = SELECT   IFX 1-5 = ON / OFF',3,89);},
  roll(g){hdr(g,'ROLL',null,ui.rollHeld?'ACTIVE':'');const n=ROLLS.length;L(g,ROLLS[ui.rollType],LW/2,20,16,'center');
    L(g,'< '+ROLLS[(ui.rollType+n-1)%n],3,44);L(g,ROLLS[(ui.rollType+1)%n]+' >',LW-3,56,8,'right');
    L(g,ui.rollType<5?'AUDIO LOOP LIKE EMX LOOPER':'RETRIGGERS THE NOTES',LW/2,70,8,'center');L(g,ui.rec?'REC: ONLY PART '+pad2(ui.part+1)+' + RECORDED':'ROLL TYPE KNOB = TYPE',LW/2,84,8,'center');},
  vel(g,p){const s=p.s,v=cur.vel[ui.part][s];hdr(g,'STEP '+(s+1)+' · PART '+pad2(ui.part+1),null,cur.steps[ui.part][s]?'ON':'OFF');L(g,'VELOCITY',3,16,16);L(g,pad3(v),LW-3,34,24,'right');barG(g,3,68,LW-6,10,v/127);L(g,'HOLD STEP + TURN VALUE',3,86);}
};
/* EG EDIT im 7"-Touch-Display (Plan: ADSR, X = Zeit, Y = Pegel). 9 Punkte: DELAY, ATTACK (X/Y), HOLD, DECAY (X/Y), SUSTAIN (X = Zeit bis dahin, Y = Pegel), RELEASE, 3 Kurven */
const EGL={x0:6,top:18,base:90,dl:24,at:38,hl:22,dc:42,st:30,su:18,rl:40};
const egMs=s=>s<1?Math.round(s*1000)+' MS':s.toFixed(2)+' S';
function egLay(P){const L=EGL,hold=P.dec>.97,AL=P.egAL??1,S=hold?AL:(P.egS||0),DL=hold?AL:(P.egDL??S),kA=egK.a(P),kD=egK.d(P),kR=egK.r(P),Y=v=>L.base-(L.base-L.top)*v;
  const xd=L.x0+L.dl*(P.egDl||0),xa=xd+L.at*P.att,xh=xa+L.hl*(P.egH||0),xdc=xh+L.dc*Math.min(1,P.dec),xs=xdc+L.st*(P.egST||0),xe=xs+L.su,xr=xe+L.rl*(P.egR??.15),u=(x,a,b)=>(x-a)/Math.max(1e-3,b-a);
  const val=x=>x<xd?0:x<xa?AL*egShp(kA,u(x,xd,xa)):x<xh?AL:x<xdc?AL-(AL-DL)*egShp(kD,u(x,xh,xdc)):x<xs?DL+(S-DL)*u(x,xdc,xs):x<xe?S:x<xr?S*(1-egShp(kR,u(x,xe,xr))):0;
  const H=[['DELAY',xd,L.base],['ATTACK',xa,Y(AL)],['HOLD',xh,Y(AL)],['DECAY',xdc,Y(DL)],['SUSTAIN',xs,Y(S)],['RELEASE',xr,L.base],
    ['A-KURVE',(xd+xa)/2,Y(AL*egShp(kA,.5))],['D-KURVE',(xh+xdc)/2,Y(AL-(AL-DL)*egShp(kD,.5))],['R-KURVE',(xe+xr)/2,Y(S*(1-egShp(kR,.5)))]];
  return{H,val,Y,S,DL,AL,hold,xd,xa,xh,xdc,xs,xe,xr};}
const EGCK=['egCA','egCD','egCR'];
const pc=v=>pad3(Math.round(clamp(v)*100))+'%';
function egVal(P,k){const Lo=egLay(P);if(k>=6){const c=Math.round(((P[EGCK[k-6]]??.5)-.5)*126);return(c>0?'+':'')+c+(Math.abs(c)<3?' GERADE':c>0?' KNACKIG':' WEICH');}
  return[egMs(egDlT(P)),egMs(.0015+P.att*P.att*1.5)+' L '+pc(Lo.AL),egMs(egHT(P)),(P.dec>.97?'HOLD':egMs((.03+P.dec*P.dec*3.5)*1.2))+' L '+pc(Lo.DL),
    egMs(egSTT(P))+' L '+((P.egS||0)<.005?'OFF':pc(P.egS)),egMs(egRelT(P))][k];}
SCR.egedit=function(g){const P=cur.parts[ui.part],Lo=egLay(P),EL=EGL,sel=ui.egSel??1;hdr(g,'EG EDIT · PART '+pad2(ui.part+1)+' '+PARTS[ui.part],null,P.egOn?'X+Y · 9 PKT':'EG OFF');
  g.fillRect(EL.x0,EL.base+1,LW-12,1);for(let x=EL.x0;x<LW-6;x+=4)g.fillRect(x,EL.top-1,1,1);
  let py=null;for(let x=EL.x0;x<=Math.min(LW-6,Lo.xr+2);x++){const y=Math.round(Lo.Y(Lo.val(x+.5)));const a=py===null?y:py;g.fillRect(x,Math.min(y,a),1,Math.abs(y-a)+1);py=y;}
  [Lo.xd,Lo.xa,Lo.xh,Lo.xdc,Lo.xs,Lo.xe].forEach(x=>{for(let y=EL.top+2;y<EL.base;y+=3)g.fillRect(Math.round(x),y,1,1);});
  Lo.H.forEach(([n,x,y],k)=>{const X=Math.round(x),Yy=Math.round(y),cv=k>=6;if(k===sel){g.fillRect(X-3,Yy-3,7,7);}else if(cv){g.fillRect(X-1,Yy-1,3,3);}else box(g,X-2,Yy-2,5,5);});
  const[n]=Lo.H[sel];g.fillRect(0,96,LW,13);inv(g,()=>{L(g,pad2(sel+1)+' '+n,3,99);L(g,egVal(P,sel),LW-3,99,8,'right');});
  L(g,'ZIEHEN · VALUE = X · SHIFT+VALUE = Y · EXIT',LW/2,113,8,'center');};
function egPick(x,y){const H=egLay(cur.parts[ui.part]).H;let best=-1,bd=1e9;H.forEach(([,hx,hy],k)=>{const d=Math.hypot(hx-x,hy-y)+(k>=6?2:0);if(d<bd){bd=d;best=k;}});
  /* ATTACK und HOLD liegen bei HOLD 0 übereinander: rechts davon tippen = HOLD */
  if(best===1&&Math.abs(H[2][1]-H[1][1])<4&&x>H[1][1]+1)best=2;return bd<26?best:-1;}
function egApply(P,k,x,y,first){const Lo=egLay(P),L=EGL,c=v=>clamp(v),yv=c((L.base-y)/(L.base-L.top));
  switch(k){case 0:P.egDl=c((x-L.x0)/L.dl);break;case 1:P.att=c((x-Lo.xd)/L.at);P.egAL=Math.max(.05,yv);break;case 2:P.egH=c((x-Lo.xa)/L.hl);break;
    case 3:P.dec=Math.min(.97,c((x-Lo.xh)/L.dc));P.egDL=yv;break;
    case 4:P.egST=c((x-Lo.xdc)/L.st);P.egS=yv<.03?0:yv;break;
    case 5:P.egR=c((x-Lo.xe)/L.rl);break;
    default:{if(!first){const key=EGCK[k-6];P[key]=c((P[key]??.5)+(ui.egLastY-y)/(k===6?60:-60));}}}
  ui.egLastY=y;}
const egRefresh=()=>['attack','decay','sustain','release'].forEach(id=>refreshKnob(CTRL[id]));
function egLcd(x,y,first){const P=cur.parts[ui.part];if(first){const k=egPick(x,y);if(k<0){ui.egDrag=false;return;}ui.egSel=k;ui.egDrag=true;}if(ui.egSel==null)return;
  undoKind('egl'+ui.part+':'+ui.egSel);if(!P.egOn)P.egOn=true;egApply(P,ui.egSel,x,y,first);dirty();egRefresh();popup('egedit',{},600000);}
/* VALUE im EG EDIT: X des gewählten Punkts, SHIFT + VALUE = Y (wie die ADSR-Regler) */
function egAdj(n){const P=cur.parts[ui.part],k=ui.egSel??1,d=n/127*4,s=shiftNow();undoKind('egv'+ui.part+':'+k+(s?'y':''));if(!P.egOn)P.egOn=true;
  const key=s&&[1,3,4,5].includes(k)?{1:'egAL',3:'egDL',4:'egS',5:'egCR'}[k]:(['egDl','att','egH','dec','egST','egR'][k]||EGCK[k-6]);
  const base=key==='egDL'?(P.egDL??(P.egS||0)):key==='egAL'?(P.egAL??1):(P[key]??(k>=6||key==='egCR'?.5:0));P[key]=clamp(base+d);if(key==='dec'&&P.dec>.97&&n>0)P.dec=1;dirty();egRefresh();popup('egedit',{},600000);}

/* PARAMETRIC EQ im Touch-Display (Plan: Drehen eines EQ-Reglers öffnet diese Seite, auch per Touch steuerbar) */
const EQG={x0:6,x1:234,top:15,bot:85,db:15};
const eqX=f=>EQG.x0+(EQG.x1-EQG.x0)*Math.log10(clamp(f,20,20000)/20)/3,eqFofX=x=>20*Math.pow(10,clamp((x-EQG.x0)/(EQG.x1-EQG.x0))*3);
const eqY=db=>(EQG.top+EQG.bot)/2-db*(EQG.bot-EQG.top)/2/EQG.db;
let eqAna=null;const eqFr=new Float32Array(EQG.x1-EQG.x0+1).map((_,i)=>eqFofX(EQG.x0+i)),eqMag=new Float32Array(eqFr.length),eqPh=new Float32Array(eqFr.length);
function eqResponse(P){if(!ctx)return null;if(!eqAna)eqAna=[biqN('lowshelf',100),biqN('peaking',1000,1),biqN('highshelf',7000),biqN('highpass',10),biqN('lowpass',22000,.707)];
  const[l,m,h,hp,lp]=eqAna,lq=P.eqLQ??0,hq=P.eqHQ??0;l.type=lq<.02?'lowshelf':'peaking';h.type=hq<.02?'highshelf':'peaking';
  l.frequency.value=eqLHz(P.eqLF??.434);l.Q.value=eqQ(lq);l.gain.value=eqDb(P.eqL);m.frequency.value=eqFHz(P.eqF);m.Q.value=eqQ(P.eqMQ??.347);m.gain.value=eqDb(P.eqM);
  h.frequency.value=eqHHz(P.eqHF??.593);h.Q.value=eqQ(hq);h.gain.value=eqDb(P.eqH);hp.frequency.value=lcHz(P.lc);lp.frequency.value=hcHz(P.hc??1);
  const tot=new Float32Array(eqFr.length).fill(1);eqAna.forEach(b=>{b.getFrequencyResponse(eqFr,eqMag,eqPh);for(let i=0;i<tot.length;i++)tot[i]*=eqMag[i];});return tot;}
function eqHandles(P){return[['LOW',eqX(eqLHz(P.eqLF??.434)),eqY(eqDb(P.eqL))],['MID',eqX(eqFHz(P.eqF)),eqY(eqDb(P.eqM))],['HIGH',eqX(eqHHz(P.eqHF??.593)),eqY(eqDb(P.eqH))],
  ['LOW CUT',eqX(lcHz(P.lc)),EQG.bot],['HIGH CUT',eqX(hcHz(P.hc??1)),EQG.bot]];}
SCR.eqedit=function(g){const P=cur.parts[ui.part],sel=ui.eqSel??1,G2=EQG;hdr(g,'PARAMETRIC EQ · PART '+pad2(ui.part+1),null,ui.bw?'BW = Q':'GAIN');
  for(const db of[-12,-6,0,6,12]){const y=Math.round(eqY(db));for(let x=G2.x0;x<=G2.x1;x+=db?4:2)g.fillRect(x,y,1,1);}
  for(const f of[50,100,200,500,1000,2000,5000,10000]){const x=Math.round(eqX(f));for(let y=G2.top;y<G2.bot;y+=4)g.fillRect(x,y,1,1);}
  L(g,'100',eqX(100),G2.bot+1,8,'center');L(g,'1K',eqX(1000),G2.bot+1,8,'center');L(g,'10K',eqX(10000),G2.bot+1,8,'center');
  const r=eqResponse(P);if(r){let py=null;for(let i=0;i<r.length;i++){const db=20*Math.log10(Math.max(1e-4,r[i])),y=Math.round(clamp(eqY(db),G2.top,G2.bot+6));const a=py===null?y:py;g.fillRect(G2.x0+i,Math.min(y,a),1,Math.abs(y-a)+1);py=y;}}
  eqHandles(P).forEach(([n,x,y],k)=>{const X=Math.round(x),Yy=Math.round(clamp(y,G2.top,G2.bot));if(k===sel)g.fillRect(X-3,Yy-3,7,7);else box(g,X-2,Yy-2,5,5);});
  const nm=['LOW','MID','HIGH','LOW CUT','HIGH CUT'][sel],info=sel<3?eqStr(P,EQK.f[sel]).replace(/^(LOW|MID|HIGH) /,'')+' '+eqStr(P,EQK.g[sel])+' '+eqStr(P,EQK.q[sel]):eqStr(P,sel===3?'lc':'hc');
  g.fillRect(0,96,LW,13);inv(g,()=>{L(g,nm,3,99);L(g,info,LW-3,99,8,'right');});
  L(g,'PRESET: '+(P.eqPre!=null?EQ_PRESETS[P.eqPre][0]:'EDIT'),3,113);L(g,ui.bw?'[BW ON]':'[BW OFF]',LW-3,113,8,'right');};
function eqLcd(x,y,first){const P=cur.parts[ui.part];
  if(first){if(y>=111){if(x>LW-60){ui.bw=!ui.bw;setLed(CTRL.bw,ui.bw);}else eqPresetNext();popup('eqedit',{},600000);return;}
    const H=eqHandles(P);let best=-1,bd=1e9;H.forEach(([,hx,hy],k)=>{const d=Math.hypot(hx-x,clamp(hy,EQG.top,EQG.bot)-y);if(d<bd){bd=d;best=k;}});if(best<0||bd>30){ui.eqDrag=false;return;}
    ui.eqSel=best;if(best<3)ui.eqBand=best;ui.eqDrag=true;}
  const s=ui.eqSel??1,f=eqFofX(x),db=clamp(((EQG.top+EQG.bot)/2-y)/((EQG.bot-EQG.top)/2)*EQG.db,-15,15);undoKind('eql'+ui.part+':'+s);
  if(s===0){P.eqLF=clamp(Math.log2(f/30)/4);P.eqL=clamp(.5+db/30);}else if(s===1){P.eqF=clamp(Math.log2(f/150)/6);P.eqM=clamp(.5+db/30);}else if(s===2){P.eqHF=clamp(Math.log2(f/1500)/3.75);P.eqH=clamp(.5+db/30);}
  else if(s===3)P.lc=f<25?0:clamp(.01+Math.log2(f/30)/4.6*.99);else P.hc=f>17500?1:clamp(Math.log2(f/500)/5.2,0,.998);
  delete P.eqPre;applyChannel(ui.part);dirty();refreshKnobs();popup('eqedit',{},600000);}

/* SYNTH OSCILLATOR-Seite: TYPE, WAVE (VALUE), EDIT 1 + 2 wie auf der EMX */
SCR.oscedit=function(g){const P=cur.parts[ui.part];hdr(g,'SYNTH OSCILLATOR · PART '+pad2(ui.part+1),null,'EMX');
  if(!P.osc){L(g,'OSC OFF',LW/2,22,16,'center');L(g,'SAMPLE: '+(P.src?pad3(P.src)+' '+SRC[P.src].n:'---'),LW/2,48,8,'center');L(g,'TYPE ODER WAVE DREHEN = OSZILLATOR',LW/2,66,8,'center');return;}
  const gi=emxIdx(P.osc,P.wave),pcm=P.osc===14||P.osc===15;
  g.fillRect(3,14,36,22);inv(g,()=>L(g,pad2(P.osc),21,17,16,'center'));L(g,OSCS[P.osc],44,15,16);
  L(g,pad3(gi+1)+'/'+EMX_ALL.length+(pcm&&!PCM[P.wave|0]?' LOADING':''),LW-3,15,8,'right');
  /* Liste wie beim Durchdrehen: 2 davor, die aktuelle, 2 danach – läuft über die Typgrenzen */
  for(let r=-2;r<=2;r++){const k=gi+r;if(k<0||k>=EMX_ALL.length)continue;const[t,w]=EMX_ALL[k],y=62+r*10,a=pad3(w+1)+' '+String(emxWaves(t)[w]).slice(0,15),b=OSCS[t].slice(0,10);
    if(r===0){g.fillRect(3,y-1,LW-6,10);inv(g,()=>{L(g,a,6,y);L(g,b,LW-6,y,8,'right');});}else{L(g,a,6,y);L(g,b,LW-6,y,8,'right');}}
  L(g,'EDIT 1',3,92);L(g,emxEditStr(P,1),LW-3,92,8,'right');barG(g,3,101,LW-6,4,P.edit??0);
  L(g,'EDIT 2',3,108);L(g,emxEditStr(P,2),LW-3,108,8,'right');barG(g,3,117,LW-6,4,P.edit2??.5);};

/* Pad angeschlagen (Plan): Welle zeigen statt Sample-Name */
const wavePeaks=new WeakMap();
function bufPeaks(buf,n){let c=wavePeaks.get(buf);if(c&&c.length===n*2)return c;const d=buf.getChannelData(0),per=d.length/n;c=new Float32Array(n*2);
  for(let i=0;i<n;i++){let lo=0,hi=0;const a=Math.floor(i*per),b=Math.min(d.length,Math.floor((i+1)*per));for(let k=a;k<b;k++){const v=d[k];if(v<lo)lo=v;if(v>hi)hi=v;}c[i*2]=lo;c[i*2+1]=hi;}wavePeaks.set(buf,c);return c;}
SCR.wave=function(g,p){const i=p.p??ui.part,P=cur.parts[i];hdr(g,'PART '+pad2(i+1)+' '+PARTS[i],null,P.osc?'OSC '+pad2(P.osc):P.src?'SAMPLE':'-');
  const y0=58,hgt=40,x0=4,w=LW-8;g.fillRect(x0,y0,w,1);
  const S=P.osc?null:SRC[P.src];
  if(S&&S.buf){const pk=bufPeaks(S.buf,w);for(let x=0;x<w;x++){const lo=pk[x*2],hi=pk[x*2+1];const a=Math.round(y0-hi*hgt),b=Math.round(y0-lo*hgt);g.fillRect(x0+x,Math.min(a,b),1,Math.max(1,Math.abs(b-a)));}
    const st=Math.round(x0+w*(P.start||0)),en=Math.round(x0+w*(P.smpEnd??1));g.fillRect(st,16,1,86);g.fillRect(en-1,16,1,86);
    if(ctx&&p.t0!=null){const rate=Math.pow(2,(P.pitch+(P.tune||0)/100)/12),pos=(P.start||0)+(now()-p.t0)*rate/S.buf.duration;if(pos<(P.smpEnd??1))g.fillRect(Math.round(x0+w*pos),14,2,90);}}
  else if(E){E.anOut.getFloatTimeDomainData(scopeBuf);let z=0;for(let k=1;k<scopeBuf.length-w;k++)if(scopeBuf[k-1]<0&&scopeBuf[k]>=0){z=k;break;}
    let py=null;for(let x=0;x<w;x++){const v=scopeBuf[z+x*2]||0,y=Math.round(y0-clamp(v*2.5,-1,1)*hgt);const a=py===null?y:py;g.fillRect(x0+x,Math.min(y,a),1,Math.abs(y-a)+1);py=y;}}
  else L(g,'---',LW/2,y0-4,8,'center');};
function grid16(g,title,lit,word){hdr(g,title);for(let i=0;i<16;i++){const x=6+(i%8)*29,y=16+(i>>3)*41;
  if(!lit(i)){box(g,x,y,26,36);L(g,pad2(i+1),x+13,y+6,8,'center');L(g,word,x+13,y+20,8,'center');}
  else{g.fillRect(x,y,26,36);inv(g,()=>{L(g,pad2(i+1),x+13,y+6,8,'center');L(g,PARTS[i].slice(0,4),x+13,y+20,8,'center');});}}}
function drawLCD(t){if(t===undefined)t=performance.now();const g=lcdSrc.getContext('2d');g.clearRect(0,0,LW,LH);g.fillStyle='#fff';
  let p=ready&&ui.popup&&t<ui.popupUntil?ui.popup:null;if(!p&&ready&&ui.fill)p={type:'fill'};if(!p&&ready&&ui.menu>=0)p={type:'menu'};if(p&&p.type==='write'&&!ui.write)p=null;ui.scr=p?p.type:'home';
  (SCR[!ready&&!p?(ctx?'msg':'off'):p?p.type:'home'])(g,p||{t:'TX-16',b:'LOADING...',s:'RENDERING SOUNDS'},t);
  if(ready)SOFTKEYS.forEach((k,j)=>{const x=j*48+1,act=SOFTSCR[j]===ui.scr;if(act){g.fillRect(x,126,46,17);inv(g,()=>L(g,k,x+23,131,8,'center'));}else{box(g,x,126,46,17);L(g,k,x+23,131,8,'center');}});
  pixelate(lcdSrc,lcdCanvas,lcdGrid,LS,'#e4f3ff',true);const fl='brightness('+(.55+G.lcd/25*.6).toFixed(2)+')';if(lcdCanvas.style.filter!==fl)lcdCanvas.style.filter=fl;}
function drawOLED(i){const c=oledCanvas[i];if(!c)return;const g=oledSrc[i].getContext('2d'),m=ui.mfx[i];g.clearRect(0,0,OW,OH);g.fillStyle='#fff';g.fillRect(0,0,30,OH);inv(g,()=>L(g,'MFX'+(i+1),15,6,8,'center'));
  if(i===0&&ui.padMode===1){const A=ui.arp;L(g,'ARP '+NUM.arp(cur.gateArp||0).slice(0,14),35,6);L(g,m.touch?ARP_RATES[clamp(Math.floor(m.touch[0]*ARP_RATES.length),0,7)][0]:'P'+pad2(ui.part+1),OW-2,6,8,'right');pixelate(oledSrc[i],c,oledGrid,OS,V.accent2);return;}
  if(i===0&&ui.padMode===2){L(g,'SCALE '+SCALES[cur.scale].slice(0,10),35,6);L(g,ui.ts?noteName(ui.ts.n+12):KEYS[cur.key]+' '+(G.tsRange||2)+'OCT',OW-2,6,8,'right');pixelate(oledSrc[i],c,oledGrid,OS,V.accent2);return;}
  L(g,pad2(m.type+1)+' '+MFXS[m.type],35,6);L(g,!m.on?'OFF':ui.rec?'P'+pad2(ui.part+1):m.hold?'HOLD':m.touch?'ON':'',OW-2,6,8,'right');pixelate(oledSrc[i],c,oledGrid,OS,V.accent2);}
function drawMFXPad(i){const c=xyCanvas[i];if(!c)return;const g=c.getContext('2d'),W=512,H=496,m=ui.mfx[i];g.fillStyle='#060709';g.fillRect(0,0,W,H);
  if(i===0&&ui.padMode){const arp=ui.padMode===1,labels=arp?ARP_RATES.map(r=>r[0]):scaleNotes().map(n=>noteName(n+12)),n=labels.length,cw=(W-16)/n,col=arp?'#ffb000':V.accent,L0=SCALESET[cur.scale].length;
    g.strokeStyle=hexA(col,.7);g.lineWidth=4;g.strokeRect(8,8,W-16,H-16);g.textAlign='center';g.textBaseline='alphabetic';
    for(let k=0;k<n;k++){const x=8+k*cw,root=!arp&&k%L0===0;g.fillStyle=hexA(col,root?.24:k%2?.05:.1);g.fillRect(x+1,10,cw-2,H-20);
      if(arp||n<=29){g.save();g.translate(x+cw/2,H-24);g.font=`500 ${arp?20:Math.min(16,cw*.55)|0}px ${FM}`;g.fillStyle=hexA(col,.85);g.fillText(arp||root||n<=15?labels[k]:labels[k].replace(/\d/g,''),0,0);g.restore();}}
    if(arp){g.strokeStyle=hexA(col,.35);g.setLineDash([6,8]);for(let y=1;y<4;y++){g.beginPath();g.moveTo(10,H*y/4);g.lineTo(W-10,H*y/4);g.stroke();}g.setLineDash([]);}
    g.font=`500 18px ${FM}`;g.fillStyle=hexA(col,.7);g.textAlign='left';g.fillText(arp?'GATE ARP '+NUM.arp(cur.gateArp||0)+' · X SPEED · Y LENGTH':'TOUCH SCALE '+KEYS[cur.key]+' '+SCALES[cur.scale]+' · '+(G.tsRange||2)+' OCT',22,34);
    if(m.touch){const tx=m.touch[0]*W,ty=m.touch[1]*H,gr=g.createRadialGradient(tx,ty,0,tx,ty,90);gr.addColorStop(0,hexA(col,1));gr.addColorStop(1,hexA(col,0));g.fillStyle=gr;g.fillRect(tx-90,ty-90,180,180);}
    return;}g.strokeStyle=hexA(V.accent2,m.on?.22:.08);g.lineWidth=1.5;
  for(let x=16;x<W;x+=32){g.beginPath();g.moveTo(x,0);g.lineTo(x,H);g.stroke();}for(let y=16;y<H;y+=32){g.beginPath();g.moveTo(0,y);g.lineTo(W,y);g.stroke();}
  g.strokeStyle=hexA(V.accent2,m.on?.7:.25);g.lineWidth=4;g.strokeRect(8,8,W-16,H-16);g.font=`500 18px ${FM}`;g.fillStyle=hexA(V.accent2,.65);g.textAlign='left';g.textBaseline='alphabetic';g.fillText(XYP[m.type],22,H-22);
  if(m.touch&&m.on){const tx=m.touch[0]*W,ty=m.touch[1]*H;g.strokeStyle=hexA(V.accent,.55);g.lineWidth=2;g.beginPath();g.moveTo(tx,8);g.lineTo(tx,H-8);g.moveTo(8,ty);g.lineTo(W-8,ty);g.stroke();
    const gr=g.createRadialGradient(tx,ty,0,tx,ty,100);gr.addColorStop(0,hexA(V.accent,1));gr.addColorStop(.25,hexA(V.accent,.55));gr.addColorStop(1,hexA(V.accent,0));g.fillStyle=gr;g.fillRect(tx-100,ty-100,200,200);}}
const SEG7={'0':'abcdef','1':'bc','2':'abdeg','3':'abcdg','4':'bcfg','5':'acdfg','6':'acdefg','7':'abc','8':'abcdefg','9':'abcdfg','A':'abcefg','C':'adef','E':'adefg','P':'abefg','S':'acdfg','U':'bcdef','V':'bcdef','-':'g',' ':''};
function hexSeg(g,x,y,w,h){g.beginPath();if(w>h){const k=h/2;g.moveTo(x,y+k);g.lineTo(x+k,y);g.lineTo(x+w-k,y);g.lineTo(x+w,y+k);g.lineTo(x+w-k,y+h);g.lineTo(x+k,y+h);}else{const k=w/2;g.moveTo(x+k,y);g.lineTo(x+w,y+k);g.lineTo(x+w,y+h-k);g.lineTo(x+k,y+h);g.lineTo(x,y+h-k);g.lineTo(x,y+k);}g.closePath();g.fill();}
let segShown=null;
function drawSeg(str){if(!segCanvas||str===segShown)return;segShown=str;const g=segCanvas.getContext('2d');g.fillStyle='#0b0303';g.fillRect(0,0,480,130);
  const cells=[];for(const ch of str){if(ch==='.'&&cells.length)cells[cells.length-1].dp=true;else cells.push({c:ch,dp:false});}while(cells.length<4)cells.unshift({c:' ',dp:false});
  cells.slice(-4).forEach((cell,i)=>{const x=48+i*104,y=14,w=62,h=100,t=11,on=SEG7[cell.c]||'';const S={a:[x+3,y,w-6,t],g:[x+3,y+h/2-t/2,w-6,t],d:[x+3,y+h-t,w-6,t],f:[x,y+3,t,h/2-4],b:[x+w-t,y+3,t,h/2-4],e:[x,y+h/2+1,t,h/2-4],c:[x+w-t,y+h/2+1,t,h/2-4]};
    g.save();g.transform(1,0,-.09,1,9,0);for(const k of 'abcdefg'){const lit=on.includes(k);g.fillStyle=lit?'#ff3b2f':'#2e0c0a';g.shadowColor='#ff3b2f';g.shadowBlur=lit?14:0;hexSeg(g,...S[k]);}
    g.fillStyle=cell.dp?'#ff3b2f':'#2e0c0a';g.shadowBlur=cell.dp?14:0;g.beginPath();g.arc(x+w+12,y+h-6,7,0,TAU);g.fill();g.restore();});}

/* ---------- Oberfläche bauen (Rev 2.0, Plan 10.10.2026) ---------- */
const dev=$('#dev'),dock=$('#dock'),NS='http://www.w3.org/2000/svg';
const U=v=>`calc(var(--u)*${(+v).toFixed(3)})`;
let host={el:dev,ox:HX,oz:HZ};
function at(cls,x,z,w,d,center=true,tag='div'){const e=document.createElement(tag);e.className='a '+cls+(center?' c':'');e.style.left=U(x+host.ox);e.style.top=U(z+host.oz);if(w!=null)e.style.width=U(w);if(d!=null)e.style.height=U(d);host.el.appendChild(e);return e;}
const esc=s=>s.replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
function arrowLabel(s){if(s==='<'||s==='>')return '<span class="tri'+(s==='>'?' r':'')+'" style="margin:0"></span>';if(s.startsWith('<'))return'<span class="tri"></span>'+esc(s.slice(1));if(s.endsWith('>'))return esc(s.slice(0,-1))+'<span class="tri r"></span>';return esc(s);}
function txt(s,x,z,size,color,align='center',ls=.06,cls='lbl'){const e=at(cls,x,z,null,null,false);e.style.fontSize=U(size);if(color)e.style.color=color;e.style.letterSpacing=ls+'em';
  e.style.transform=align==='center'?'translate(-50%,-50%)':align==='right'?'translate(-100%,-50%)':'translate(0,-50%)';e.innerHTML=arrowLabel(s);return e;}
const defs=document.createElementNS(NS,'svg');defs.setAttribute('width','0');defs.setAttribute('height','0');defs.style.position='absolute';
defs.innerHTML='<defs><radialGradient id="kb" cx="40%" cy="35%" r="70%"><stop offset="0" stop-color="#3b3c43"/><stop offset="1" stop-color="#121216"/></radialGradient><radialGradient id="kc" cx="40%" cy="35%" r="70%"><stop offset="0" stop-color="#4d4f57"/><stop offset="1" stop-color="#202126"/></radialGradient><radialGradient id="ka" cx="38%" cy="32%" r="75%"><stop offset="0" stop-color="#f3f4f7"/><stop offset="1" stop-color="#8d929b"/></radialGradient></defs>';
document.body.appendChild(defs);
const P2='#8b8e99';
at('band',-HX,BAND_Z,PW,PB-BAND_Z,false);
SECTS.forEach(s=>{at('frame'+(s.cls?' '+s.cls:''),s.x0,s.z0,s.x1-s.x0,s.z1-s.z0,false);if(s.n)txt(s.n,s.x0+.3,s.z0+.38,.24,s.cls==='emx'?'#dfe9ff':V.accent2,'left',.16);});
REAR.forEach(r=>txt('▲ '+r.l,r.x,PT+.3,.14,P2,'center',.06));
/* Röhren: 3 × ECC82 stehend unter einer Haube mit Lüftungsschlitzen (Plan) */
at('hood',(WIN.x0+WIN.x1)/2,WIN.z0-.55,WIN.x1-WIN.x0,.7);
txt('BELÜFTUNG · HAUBE',(WIN.x0+WIN.x1)/2,WIN.z0-1.25,.15,'#5d606b','center',.12);
const win=at('win',(WIN.x0+WIN.x1)/2,(WIN.z0+WIN.z1)/2,WIN.x1-WIN.x0,WIN.z1-WIN.z0);
[14,39,64].forEach(l=>{const t=document.createElement('div');t.className='tube up';t.style.left=l+'%';t.innerHTML='<i></i>';win.appendChild(t);});
txt('3 × ECC82 / 12AU7 · 30 S WARM-UP',WIN.x0,WIN.z1+.45,.17,P2,'left',.08);
/* Status-LEDs + Pegel-Anzeigen (Röhre / Ausgang) unter TUBE · OUTPUT */
SLEDS.forEach((s,k)=>{s.el=at('sled',SLED_X(k),SLED_Z,.26,.26);txt(s.l,SLED_X(k)+.25,SLED_Z,.15,P2,'left',.06);});
const meterEls=METERS.z.map(z=>Array.from({length:METERS.n},(_,k)=>at('mled',METERS.x0+k*METERS.pitch,z,.36,.26)));
txt('T',METERS.x0-.45,METERS.z[0],.15,P2);txt('O',METERS.x0-.45,METERS.z[1],.15,P2);
at('bezel',LCD.x,LCD.z,LCD.w+.6,LCD.d+.6);const lcdCanvas=at('',LCD.x,LCD.z,LCD.w,LCD.d,true,'canvas');lcdCanvas.width=LW*LS;lcdCanvas.height=LH*LS;
const segCanvas=null;
lcdCanvas.classList.add('lcdt');lcdCanvas.setAttribute('aria-label','7-Zoll-Touch-Display');
txt('7" TOUCH · 800 × 480',LCD.x+LCD.w/2,LCD.z+LCD.d/2+.55,.14,'#5d606b','right',.1);
const oledCanvas=[],xyCanvas=[];
function buildMFX(i,o,p){at('bezel',o.x,o.z,o.w,o.d);const c=at('',o.x,o.z,o.w-.2,o.d-.2,true,'canvas');c.width=OW*OS;c.height=OH*OS;oledCanvas[i]=c;
  at('bezel',p.x,p.z,p.w+.3,p.d+.3);const x=at('xy',p.x,p.z,p.w-.1,p.d-.1,true,'canvas');x.width=512;x.height=496;x.setAttribute('aria-label','Master FX '+(i+1)+' X/Y-Pad');xyCanvas[i]=x;}
buildMFX(0,OLED,XYPAD);
function buildKnob(d){
  const S=d.r+.62,e=at('knob',d.x,d.z,2*S,2*S);e.tabIndex=0;e.setAttribute('role','slider');e.setAttribute('aria-label',d.aria||d.label);
  const svg=document.createElementNS(NS,'svg');svg.setAttribute('viewBox',`${-S} ${-S} ${2*S} ${2*S}`);e.appendChild(svg);d.dots=[];
  const add=(tag,attrs,p=svg)=>{const n=document.createElementNS(NS,tag);for(const k in attrs)n.setAttribute(k,attrs[k]);p.appendChild(n);return n;};
  if(d.ring||d.ticks){const n=d.ring?15:11,R0=d.r+.3;for(let k=0;k<n;k++){const a=(-135+k*270/(n-1))*D2R;const c=add('circle',{cx:(Math.sin(a)*R0).toFixed(3),cy:(-Math.cos(a)*R0).toFixed(3),r:d.ring?.075:.045,fill:d.ring?'#26272d':'#6f7380'});if(d.ring)d.dots.push(c);}}
  add('circle',{r:d.r*1.06,fill:'#0b0b0d'});add('circle',{r:d.r*.95,fill:'url(#kb)'});add('circle',{r:d.r*.74,fill:d.cap||d.emxRing||d.hero?'url(#ka)':'url(#kc)'});
  if(d.pot){d.rot=add('g',{});add('rect',{x:-d.r*.06,y:-d.r*.9,width:d.r*.12,height:d.r*.45,rx:d.r*.04,fill:d.cap?'#16171b':'#fff'},d.rot);}
  else add('circle',{r:d.r*.86,fill:'none',stroke:'#4a4c55','stroke-width':d.r*.1,'stroke-dasharray':(d.r*.07)+' '+(d.r*.07)});d.el=e;
  /* Räder (VALUE, WAVE): Fingermulde, dreht sich mit */
  if(d.endless){d.rot=add('g',{});add('circle',{cx:0,cy:-d.r*.52,r:d.r*.14,fill:'#121216',stroke:'#5a5c64','stroke-width':d.r*.025},d.rot);}
  /* EMX-Oszillator: 16 Beschriftungen + LED rundherum wie bei der Korg EMX */
  if(d.emxRing){d.typeLeds=[];for(let k=0;k<16;k++){const a=oscAng(k),lx=d.x+Math.sin(a)*OSCT.lr,lz=d.z-Math.cos(a)*OSCT.lr,dx=d.x+Math.sin(a)*(d.r+.32),dz=d.z-Math.cos(a)*(d.r+.32);
      d.typeLeds.push(at('oled16',dx,dz,.16,.16));const s=Math.sin(a),al=Math.abs(s)<.25?'center':s<0?'right':'left';txt(OSCS[k+1],lx+(al==='center'?0:s*.05),lz,.17,'#dfe9ff',al,.02,'olbl');}
    txt('TYPE',d.x,d.z+d.r+.55,.2,'#dfe9ff');}
  else if(d.id==='value')txt('VALUE / PATTERN',d.x,d.z+d.r+.72,.26,'#e6e8ee');
  else txt(d.label,d.x,d.z+d.r+.73,d.r>=.9?.27:.24,d.emx?'#dfe9ff':d.det&&d.det!=='center'?V.accent2:'#e6e8ee');
  if(d.sh)txt(d.sh,d.x+d.r+.45,d.z-d.r-.3,.17,V.accent2,'center',.05);
}
function refreshKnob(d,keep){if(!d||!d.el)return;
  if(d.typeLeds){const i=cur.parts[ui.part].osc|0;d.typeLeds.forEach((el,k)=>{const on=k===i-1,c=on?V.accent:'#0a1a33';if(el._c!==c){el._c=c;el.style.background=c;el.style.boxShadow=on?'0 0 6px '+V.accent:'';}});d.el.setAttribute('aria-valuetext',valStr(d));return;}
  if(!d.rot&&!d.dots.length){if(!keep)d.raw=knobGet(d);d.el.setAttribute('aria-valuetext',valStr(d));return;}let v=knobGet(d);if(d.endless)v=((v%1)+1)%1;
  if(!keep&&!d.endless)d.raw=isCen(d)?rawFromV(knobGet(d)):knobGet(d);if(d.rot)d.rot.setAttribute('transform',`rotate(${(d.endless?360*v:-135+270*v).toFixed(1)})`);
  const dot=d.endless||d.det==='list'||d.det==='pattern'||d.det==='roll',ctr=isCen(d);
  d.dots.forEach((c,k)=>{const p=k/14;let lit=dot?Math.abs(p-v)<.036:ctr?(v>=.5?p>=.5&&p<=v+1e-6:p<=.5&&p>=v-1e-6):p<=v+1e-6;let col=lit?V.accent:'#26272d';if(ctr&&k===7)col=Math.abs(v-.5)<.01?'#ffffff':lit?V.accent:'#4a4c55';c.setAttribute('fill',col);});
  d.el.setAttribute('aria-valuetext',valStr(d));}
const isCen=d=>d.det==='center'||(d.id==='cutoff'&&cur.parts[ui.part].ftrack)||((d.id==='edit2')&&cur.parts[ui.part].osc&&['pm','v'].includes((EMX[cur.parts[ui.part].osc]||{}).m2));
const refreshKnobs=()=>K.forEach(d=>refreshKnob(d));
const LEDC={A:V.accent,B:V.accent2,red:'#ff2a2a',green:'#2bff6a',tube:'#ff8a20',white:'#f2f4ff'};
const SYM={rec:'<svg viewBox="-1 -1 2 2" width="42%" height="60%"><circle r=".72" fill="none" stroke="currentColor" stroke-width=".2"/></svg>',
  stop:'<svg viewBox="-1 -1 2 2" width="42%" height="60%"><rect x="-.66" y="-.66" width="1.32" height="1.32" fill="none" stroke="currentColor" stroke-width=".2"/></svg>',
  play:'<svg viewBox="-1.3 -1 2.6 2" width="52%" height="60%"><path d="M-1 -.8 L.45 0 L-1 .8 Z" fill="none" stroke="currentColor" stroke-width=".18"/><rect x=".72" y="-.8" width=".38" height="1.6" fill="none" stroke="currentColor" stroke-width=".16"/></svg>'};
function buildButton(d){const e=at('btn'+(d.latch?' latch':''),d.x,d.z,d.w,d.d);e.tabIndex=0;e.setAttribute('role','button');e.setAttribute('aria-label',d.aria||(d.label.startsWith('<')?d.label.slice(1)+' zurück':d.label.endsWith('>')?d.label.slice(0,-1)+' weiter':d.label));e.style.setProperty('--led',LEDC[d.led]||'#9aa6bd');d.el=e;
  if(d.noLbl||d.sym||d.tall||d.label==='<'||d.label==='>'){e.style.display='flex';e.style.alignItems='center';e.style.justifyContent='center';e.style.fontWeight='700';e.style.color='#e6e8ee';
    if(d.sym){e.innerHTML=SYM[d.sym];d.lblEl=txt(d.label,d.x,d.z+d.d/2+.33,.21,'#e6e8ee');}
    else if(d.tall){e.style.flexDirection='column';e.style.fontSize=U(.32);e.style.lineHeight='1.05';e.innerHTML=d.label.split('').map(c=>'<span>'+esc(c)+'</span>').join('');}
    else if(d.label==='<'||d.label==='>'){e.innerHTML='<svg viewBox="-1 -1 2 2" width="55%" height="70%"><path d="'+(d.label==='<'?'M.7 -.8 L-.8 0 L.7 .8 Z':'M-.7 -.8 L.8 0 L-.7 .8 Z')+'" fill="none" stroke="currentColor" stroke-width=".16"/><text x="'+(d.label==='<'?'.12':'-.12')+'" y=".22" font-size=".7" text-anchor="middle" fill="currentColor">'+(d.label==='<'?'−':'+')+'</text></svg>';}
    else{e.style.fontSize=U(.42);e.textContent=d.label==='-'?'−':'+';}}
  else d.lblEl=txt(d.label,d.x,d.z+d.d/2+.33,d.fn?.25:.23,d.id==='save'?V.accent:'#e6e8ee');
  if(d.sh)txt(d.sh,d.x,d.z-d.d/2-.27,.17,V.accent2,'center',.05);}
function setLed(d,on,dim){if(!d||!d.el)return;d.on=on;d.el.classList.toggle('on',!!on&&!dim);d.el.classList.toggle('dim',!!on&&!!dim);}
K.forEach(buildKnob);BT.forEach(buildButton);
const ifxPageEl=txt('SELECT · IFX 1',(IFXON_X(0)+IFXON_X(4))/2,.8,.17,P2);
txt('+ SHIFT = Y-ACHSE (PEGEL)',-20.4,4.25,.16,'#5d606b','center',.08);
txt('BW = BANDBREITE',-13.2,-6.42,.13,'#5d606b','center',.04);
/* Bars (blau) + Oktave des aktuellen Parts (rot) */
txt('BARS',BARLED_X(0)-.55,BARLED_Z,.15,V.accent2,'right',.1);txt('OKT',BARLED_X(0)-.55,OCTLED_Z,.15,'#ff5a5a','right',.1);
const barEls=Array.from({length:8},(_,k)=>at('bled',BARLED_X(k),BARLED_Z,.34,.34));
const octEls=Array.from({length:8},(_,k)=>{const e=at('bled',BARLED_X(k),OCTLED_Z,.34,.34);return e;});
txt('-4',BARLED_X(0),OCTLED_Z+.42,.12,'#5d606b');txt('+3',BARLED_X(7),OCTLED_Z+.42,.12,'#5d606b');
/* Anzeige im EMX-Block: Typ + Welle – zeigt sofort, was TYPE und WAVE gerade eingestellt haben */
at('bezel',OSCLCD.x,OSCLCD.z,OSCLCD.w+.3,OSCLCD.d+.3);const oscLcd=at('osclcd',OSCLCD.x,OSCLCD.z,OSCLCD.w,OSCLCD.d);oscLcd.setAttribute('aria-live','polite');
oscLcd.innerHTML='<div class="l1"><b></b><i></i></div><div class="l2"><b></b><i></i></div>';const OL=[...oscLcd.querySelectorAll('b,i')];let oscLcdSig='';
function oscLcdUpdate(){const P=cur.parts[ui.part],sig=ui.part+'|'+P.osc+'|'+P.wave+'|'+P.src;if(sig===oscLcdSig)return;oscLcdSig=sig;
  /* oben: Typ + Position in allen 258 (wie weit man gedreht hat), unten groß: Welle */
  const v=P.osc?[pad2(P.osc)+' '+OSCS[P.osc],pad3(emxIdx(P.osc,P.wave)+1)+'/'+EMX_ALL.length,pad3((P.wave|0)+1)+' '+String(emxWaveName(P)).slice(0,12),'']
    :['OSC OFF · SAMPLE','PART '+pad2(ui.part+1),P.src?pad3(P.src)+' '+SRC[P.src].n.slice(0,12):'--- NO SOUND',''];
  v.forEach((x,k)=>{if(OL[k].textContent!==x)OL[k].textContent=x;});}
SLOTS.forEach(o=>{const s=at('slot',o.x,o.z,o.w,o.d);s.setAttribute('aria-label','Freier Slot für Add-ons');txt(o.t,o.x,o.z-.12,.2,'#5d606b');txt(o.s,o.x,o.z+.25,.14,'#4a4c55');});
const padEls=[],padTxt=[];for(let i=0;i<24;i++){const e=at('pad',PADX(i),PADZI(i),PADW,PADD);e.setAttribute('role','button');e.setAttribute('aria-label','Pad '+(i+1));e.style.fontSize=U(.22);
  const r1=document.createElement('span'),r2=document.createElement('span'),a=document.createElement('i'),b=document.createElement('i'),c=document.createElement('i');[a,b,c].forEach(x=>x.style.fontStyle='normal');
  r1.append(a,b);r2.append(c);e.append(r1,r2);padEls.push(e);padTxt.push([a,b,c]);}
{txt('TX-16',29.4,20.45,.46,'#e6e8ee','right');const b=txt('TEKKBOX',25.6,20.4,.66,V.accent,'right',.02);b.style.fontStyle='italic';}
txt('TUBE HYBRID GROOVE SAMPLER  ·  16 PARTS  ·  8 BARS  ·  16 EMX OSC TYPES  ·  '+FILTERS.length+' FILTERS',-19.2,20.45,.2,P2,'left',.12);
txt('▼ PHONES 6,3 + 3,5',-24.6,20.45,.16,P2,'center',.08);
{const e=txt('◀ ADD-ON DOCK · MFX PAD 2',-29.55,-2,.17,P2,'center',.08);e.style.transform='translate(-50%,-50%) rotate(-90deg)';}
let padSig='';
txt('SEQUENCER · PARTS 1-16 · STEPS',(colX(0)+colX(7))/2,19.95,.15,'#5d606b','center',.12);txt('KEYS · LIVE SAMPLES 17-24',(colX(8)+colX(11))/2,19.95,.15,'#5d606b','center',.12);
function padLabels(force){const m=ui.mode,P=cur.parts[ui.part],page=ui.pageSel,sig=m+'|'+page+'|'+P.oct+'|'+P.tr+'|'+cur.key+'|'+cur.scale+'|'+ui.part;if(sig===padSig&&!force)return;padSig=sig;
  for(let i=0;i<24;i++){const L2=padTxt[i];let a='',b='',c=String(i+1);
    if(m==='KEYBOARD'||m==='CHORD'){const n=partNote(P,kbNote(i));a=noteName(n);b=inScale(kbNote(i))?'':'·';}
    else if(m==='SEQUENCER'||m==='STEP JUMP'){if(i<16){a='STEP';b=String(page*16+i+1);}else{a='BAR';b=String(i-15);}}
    else if(i<16||m==='TRIGGER'){a=PARTS[i];if(i>=NSEQ)b='LIVE';}else{c='';}
    L2[0].textContent=a;L2[1].textContent=b;L2[2].textContent=c;}}
/* Add-on-Modul: 2. MFX-Pad, steckt links am Dock */
host={el:dock,ox:4.6,oz:0};
txt('MFX 2 · ADD-ON',0,.7,.22,V.accent2,'center',.14);
buildMFX(1,{x:0,z:1.8,w:6.6,d:.9},{x:0,z:6.1,w:6.6,d:6.4});
const DK=[];kd('mfxtype2','FX TYPE',-1.8,11.5,.62,{g:true,det:'list',mfx:1,sect:'MASTER FX 2',aria:'MFX 2 TYPE'});DK.push(K.pop());
bd('mfxon2','FX ON',2,10.9,1.9,.8,{led:'A',mfxOn:1});bd('mfxhold2','HOLD',2,12.4,1.9,.8,{led:'B',mfxHold:1});DK.push(BT.pop(),BT.pop());
DK.forEach(d=>{CTRL[d.id]=d;d.kind==='knob'?buildKnob(d):buildButton(d);});
for(let k=0;k<5;k++)at('vent',4.25,3+k*.9,.18,.5);
host={el:dev,ox:HX,oz:HZ};
const ALLK=K.concat(DK.filter(d=>d.kind==='knob')),ALLB=BT.concat(DK.filter(d=>d.kind==='button'));
function sizeDev(){const u=dev.clientWidth/PW;dev.style.setProperty('--u',u+'px');dock.style.setProperty('--u',u+'px');dock.style.width=(9.2*u)+'px';dock.style.height=(14*u)+'px';}
new ResizeObserver(sizeDev).observe(dev);sizeDev();

/* ---------- Bedienung mit Maus, Touch und Tastatur ---------- */
function syncMidiBtn(){$('#midiBtn').setAttribute('aria-pressed',String(!!MIDI.acc));$('#midiBtn').textContent=MIDI.acc?'MIDI: '+MIDI.ins.length+' rein · '+MIDI.outs.length+' raus':'MIDI verbinden';}
function syncInBtn(){const on=!!(E&&E.in);$('#inBtn').setAttribute('aria-pressed',String(on));$('#inBtn').textContent=on?'Audio-In aktiv':'Audio-In an';}
ALLK.forEach(d=>{
  d.el.addEventListener('pointerdown',e=>{if(!ready)return;e.preventDefault();d.el.setPointerCapture(e.pointerId);d.acc=0;if(d.raw==null)d.raw=isCen(d)?rawFromV(knobGet(d)):knobGet(d);d.drag=e.clientY;if(!d.endless)knobChanged(d);else if(d.wave)waveTurn(0);});
  d.el.addEventListener('pointermove',e=>{if(d.drag==null)return;const dy=d.drag-e.clientY;d.drag=e.clientY;if(dy)turn(d,dy,(ui.shift||e.shiftKey));});
  const end=()=>{if(d.drag!=null){d.drag=null;if(shiftNow())consumeShift();refreshKnob(d);}};d.el.addEventListener('pointerup',end);d.el.addEventListener('pointercancel',end);
  d.el.addEventListener('wheel',e=>{if(!ready)return;e.preventDefault();const s=-Math.sign(e.deltaY);if(d.endless)endlessTick(d,s);else if(d.det&&d.det!=='center'){tickKnob(d,s);refreshKnob(d);knobChanged(d);}else turn(d,s*4,ui.shift||e.shiftKey);refreshKnob(d,true);},{passive:false});
  d.el.addEventListener('keydown',e=>{if(!ready)return;const s=e.key==='ArrowUp'||e.key==='ArrowRight'?1:e.key==='ArrowDown'||e.key==='ArrowLeft'?-1:0;if(!s)return;e.preventDefault();
    if(d.endless)endlessTick(d,s);else if(d.det&&d.det!=='center'){tickKnob(d,s);knobChanged(d);}else turn(d,s*4,e.shiftKey);refreshKnob(d,true);});
});
/* Räder: VALUE (Menü/Pattern) oder WAVE (Welle des EMX-Oszillators) */
const endlessTick=(d,s)=>d.wave?waveTurn(s):valueKnob(s);
function turn(d,dy,fine){
  /* SHIFT-Ebene (Plan): PITCH -> GLIDE, OSC EDIT 1 -> DRUCK, ADSR -> Y-Achse (Pegel / Release-Kurve) */
  if(d.shp&&(fine||shiftNow())){const D=CTRL[d.shp];D.raw=clamp(knobGet(D)+dy*.005);knobSet(D,D.raw);knobChanged(D);return;}
  /* EQ-Regler wechseln ihren Parameter (BW / Band): Startwert jedes Mal frisch holen, sonst springt der Wert */
  if(d.eq!=null){const k=keyOf(d);if(d.rawKey!==k){d.rawKey=k;d.raw=knobGet(d);}}
  if(d.id==='sc'&&fine){const P=cur.parts[ui.part];d.acc+=dy;while(Math.abs(d.acc)>=9){const s=Math.sign(d.acc);d.acc-=s*9;P.scSrc=(P.scSrc+s+16)%16;dirty();}popup('param',{d});return;}
  if(d.endless){d.acc+=dy;d.raw=(d.raw||0)+dy*.004;refreshKnob(d,true);while(Math.abs(d.acc)>=8){const s=Math.sign(d.acc);d.acc-=s*8;endlessTick(d,s);}return;}
  if(d.det&&d.det!=='center'){d.acc+=dy;while(Math.abs(d.acc)>=9){const s=Math.sign(d.acc);d.acc-=s*9;tickKnob(d,s);}refreshKnob(d,true);knobChanged(d);return;}
  d.raw=clamp((d.raw??knobGet(d))+dy*(fine?.0012:.005));knobSet(d,isCen(d)?vFromRaw(d.raw):d.raw);refreshKnob(d,true);knobChanged(d);}
function shiftDown(){ui.wasLatched=ui.shiftLatch;ui.shift=true;ui.shiftT=performance.now();ui.shiftUsed=false;setLed(CTRL.shift,true);}
function shiftUp(){const tap=performance.now()-ui.shiftT<300&&!ui.shiftUsed;if(ui.wasLatched||!tap){ui.shiftLatch=false;ui.shift=false;}else{ui.shiftLatch=true;ui.shift=true;}setLed(CTRL.shift,ui.shift);}
ALLB.forEach(d=>{
  d.el.addEventListener('pointerdown',e=>{if(!ready)return;e.preventDefault();d.el.setPointerCapture(e.pointerId);d.el.classList.add('press');d.down=true;
    if(d.id==='shift')shiftDown();else if(d.id==='roll')rollDown();else act(d);});
  const up=()=>{d.el.classList.remove('press');const was=d.down;d.down=false;if(!ready)return;if(d.id==='shift')shiftUp();if(d.id==='roll')rollUp();if(was){modeRelease(d);btnUp(d);}};
  d.el.addEventListener('pointerup',up);d.el.addEventListener('pointercancel',up);
  d.el.addEventListener('keydown',e=>{if(ready&&(e.key==='Enter'||e.key===' ')&&!e.repeat){e.preventDefault();e.stopPropagation();d.down=true;if(d.id==='shift'){ui.shiftLatch=!ui.shiftLatch;ui.shift=ui.shiftLatch;setLed(d,ui.shift);}else if(d.id==='roll')rollDown();else act(d);}});
  d.el.addEventListener('keyup',e=>{if(e.key==='Enter'||e.key===' '){if(d.id==='roll')rollUp();if(d.down){d.down=false;modeRelease(d);btnUp(d);}}});
});
padEls.forEach((el,i)=>{
  el.addEventListener('pointerdown',e=>{if(!ready)return;e.preventDefault();el.setPointerCapture(e.pointerId);el.classList.add('press');const r=el.getBoundingClientRect();padPress(i,clamp(1-(e.clientY-r.top)/r.height*.9));});
  const up=()=>{el.classList.remove('press');if(ready)padRelease(i);};el.addEventListener('pointerup',up);el.addEventListener('pointercancel',up);
});
const GLOBAL_RATE={tape:x=>[.04,.12+x*.7],vinyl:x=>[.02,.35+x*1.2],pdrop:(x,y)=>[Math.pow(2,-(.2+y*.8)),.03+x*.25]};
const routedParts=()=>PARTS.map((_,p)=>p).filter(p=>fxRouted(p)||!!motionFx[p]);
function xyMove(i,x,y){if(i===0&&ui.padMode){const m=ui.mfx[0];m.touch=[clamp(x),clamp(y)];if(ui.padMode===1)arpTouch(m.touch[0],m.touch[1]);else tsTouch(m.touch[0],m.touch[1]);drawMFXPad(0);drawOLED(0);return;}
  const m=ui.mfx[i],was=!!m.touch;m.touch=[clamp(x),clamp(y)];m.user=true;m.byMotion=false;const k=MFX_KIND[m.type];
  if(m.on&&GLOBAL_RATE[k]&&(!was||k==='pdrop')){const[tg,tc]=GLOBAL_RATE[k](m.touch[0],1-m.touch[1]);setPartRate(tg,tc,routedParts());}
  if(ui.rec&&ui.playing&&i===0)rec(ui.part,ui.dispStep,'_fx',[m.touch[0],m.touch[1]]);
  E.mfx[i].update();drawMFXPad(i);drawOLED(i);popup('xy',{i},1400);}
function xyRelease(i,force){if(i===0&&ui.padMode){if(ui.mfx[0].hold&&!force)return;ui.mfx[0].touch=null;tsRelease();arpRelease();drawMFXPad(0);drawOLED(0);return;}
  const m=ui.mfx[i];m.user=false;if(m.hold&&!force)return;const k=MFX_KIND[m.type];m.touch=null;if(GLOBAL_RATE[k])setPartRate(1,.06,PARTS.map((_,p)=>p));br=null;E.mfx[i].update();drawMFXPad(i);drawOLED(i);}
xyCanvas.forEach((c,i)=>{
  const pos=e=>{const r=c.getBoundingClientRect();if(!r.width||!r.height)return[.5,.5];return[(e.clientX-r.left)/r.width,(e.clientY-r.top)/r.height];};
  c.addEventListener('pointerdown',e=>{if(!ready)return;e.preventDefault();c.setPointerCapture(e.pointerId);c._down=true;xyMove(i,...pos(e));});
  c.addEventListener('pointermove',e=>{if(c._down)xyMove(i,...pos(e));});
  const up=()=>{if(c._down){c._down=false;xyRelease(i);}};c.addEventListener('pointerup',up);c.addEventListener('pointercancel',up);
});
const KEYPAD=k=>padAt(k<12?0:1,k%12);
const KEYCODES=['KeyQ','KeyW','KeyE','KeyR','KeyT','KeyY','KeyU','KeyI','KeyO','KeyP','BracketLeft','BracketRight','KeyA','KeyS','KeyD','KeyF','KeyG','KeyH','KeyJ','KeyK','KeyL','Semicolon','Quote','Backslash'];
window.addEventListener('keydown',e=>{
  if(e.key==='Shift'){kbShift=true;return;}
  if(!ready||e.metaKey||e.ctrlKey||e.altKey||e.repeat)return;if(e.target.closest&&e.target.closest('.knob,.btn,button,label'))return;
  if(e.key===' '){e.preventDefault();setPlaying(!ui.playing);return;}
  const k0=KEYCODES.indexOf(e.code);if(k0>=0){const k=KEYPAD(k0);e.preventDefault();padPress(k);padEls[k].classList.add('press');}
});
window.addEventListener('keyup',e=>{if(e.key==='Shift'){kbShift=false;return;}const k0=KEYCODES.indexOf(e.code),k=k0>=0?KEYPAD(k0):-1;if(k>=0){padEls[k].classList.remove('press');if(ready)padRelease(k);}});
window.addEventListener('blur',()=>{kbShift=false;});

/* ---------- 7-Zoll-Touch-Display ---------- */
const SOFTKEYS=['HOME','SOUND','IFX','MFX','MENU'],SOFTSCR=['home','sound','ifx','xy','menu'];
const SOUNDROWS=[['SAMPLE','sample'],['OSC TYPE','osc'],['EDIT 1','edit'],['EDIT 2','edit2'],['CUTOFF','cutoff'],['RESO','reso'],['ATTACK','attack'],['DECAY','decay'],['SUSTAIN','sustain'],['RELEASE','release'],['PITCH','pitch'],['MOD TYPE','mtype']];
function lcdTouch(x,y){undoKind('lcd'+(++undoN));
  if(y>=124){const k=Math.min(4,Math.floor(x/48));ui.menuEdit=false;
    if(k===0){ui.menu=-1;ui.popup=null;}else if(k===1){ui.menu=-1;popup('sound',{},12000);}else if(k===2){ui.menu=-1;popup('ifx',{},12000);}else if(k===3){ui.menu=-1;popup('xy',{i:0},12000);}else{ui.menu=ui.menu<0?0:-1;ui.menuItem=0;ui.popup=null;}return;}
  const sc=ui.scr;
  if(sc==='egedit'&&y<120){egLcd(x,y,true);return;}
  if(sc==='eqedit'&&y<122){eqLcd(x,y,true);return;}
  if(sc==='menu'){const m=MENU[ui.menu],n=m.items.length,top=clamp(ui.menuItem-1,0,Math.max(0,n-4)),j=top+Math.floor((y-32)/12);if(y<32||j>=Math.min(n,top+4))return;const it=m.items[j];
    if(j!==ui.menuItem){ui.menuItem=j;ui.menuEdit=false;}else if(it.enter)it.enter();else if(it.adj){if(!ui.menuEdit)ui.menuEdit=true;else it.adj(x>LW/2?1:-1);}return;}
  if(sc==='ifx'){if(y>=14&&y<=46){const k=clamp(Math.floor((x-3)/47),0,4),P=cur.parts[ui.part];if(k===ui.fxSel){P.fx[k].on=!P.fx[k].on;dirty();applyChannel(ui.part);}else ui.fxSel=k;ifxLeds();refreshKnob(CTRL.ifxtype);refreshKnob(CTRL.ifxedit);}popup('ifx',{},12000);return;}
  if(sc==='sound'){const col=x<120?0:1,r=Math.floor((y-13)/14);if(r>=0&&r<6){ui.lastCtrl=SOUNDROWS[col*6+r][1];}popup('sound',{},12000);return;}
  if(sc==='xy'){popup('xy',{i:0},12000);return;}
  if(sc==='fill'){if(y>=40&&y<=74){fillBar(clamp(Math.floor((x-4)/((LW-8)/(cur.last/16))),0,cur.last/16-1));}else if(y>=96&&y<124)fillExec();return;}
  if(sc==='home'){const page=ui.pageSel;
    if(y>=84&&y<=98&&x<195&&ui.part<NSEQ){const i=clamp(Math.floor((x-3)/12),0,15),st=page*16+i;pushUndo();cur.steps[ui.part][st]^=1;dirty();return;}
    if(y>=44&&y<=82&&x>=100){popup(y<62?'ifx':'xy',y<62?{}:{i:0},12000);return;}
    if(y>=32&&y<44){popup('sound',{},12000);return;}
    if(y<32){popup('pattern',{},2500);return;}}
  if(ui.popup)ui.popup=null;
}
lcdCanvas.addEventListener('pointerdown',e=>{if(!ready)return;e.preventDefault();try{lcdCanvas.setPointerCapture(e.pointerId);}catch(err){}const r=lcdCanvas.getBoundingClientRect();lcdTouch((e.clientX-r.left)/r.width*LW,(e.clientY-r.top)/r.height*LH);});
/* EG EDIT: Punkte ziehen */
lcdCanvas.addEventListener('pointermove',e=>{const r=lcdCanvas.getBoundingClientRect(),x=(e.clientX-r.left)/r.width*LW,y=(e.clientY-r.top)/r.height*LH;if(ui.egDrag&&ui.scr==='egedit')egLcd(x,y,false);else if(ui.eqDrag&&ui.scr==='eqedit')eqLcd(x,y,false);});
['pointerup','pointercancel'].forEach(t=>lcdCanvas.addEventListener(t,()=>{ui.egDrag=false;ui.eqDrag=false;}));

/* ---------- Samples vom USB-Stick ---------- */
async function loadSamples(files){
  if(!files||!files.length)return;if(!ctx)await powerOn();let ok=0,last=null;
  for(const file of files){try{const buf=await ctx.decodeAudioData(await file.arrayBuffer());SRC.push({n:'USR '+file.name.replace(/\.[^.]+$/,'').toUpperCase().slice(0,14),buf:norm(buf),f0:detectF0(buf)});ok++;last=buf;}catch(err){}}
  if(!ok){popup('msg',{t:'USB STICK',b:'ERROR',s:'FORMAT NOT SUPPORTED'},2500);return;}
  const P=cur.parts[ui.part];P.src=SRC.length-1;dirty();if(P.stretch)scheduleStretch(ui.part);refreshKnobs();
  popup('msg',{t:'USB STICK · '+ok+' FILE'+(ok>1?'S':''),b:'PART '+pad2(ui.part+1),s:SRC[P.src].n+' · '+last.duration.toFixed(2)+' S'},2500);
}
$('#file').addEventListener('change',e=>{loadSamples([...e.target.files]);e.target.value='';});
$('#fileLbl').addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();$('#file').click();}});
const drop=$('#drop');let dragDepth=0;
window.addEventListener('dragenter',e=>{if(e.dataTransfer&&[...e.dataTransfer.types].includes('Files')){dragDepth++;drop.hidden=false;}});
window.addEventListener('dragleave',()=>{dragDepth=Math.max(0,dragDepth-1);if(!dragDepth)drop.hidden=true;});
window.addEventListener('dragover',e=>e.preventDefault());
window.addEventListener('drop',e=>{e.preventDefault();dragDepth=0;drop.hidden=true;if(e.dataTransfer.files)loadSamples([...e.dataTransfer.files]);});

/* ---------- Einschalten ---------- */
async function powerOn(){
  if(ctx)return;ctx=new(window.AudioContext||window.webkitAudioContext)({latencyHint:'interactive'});
  $('#offScreen').hidden=true;['#power','#power2'].forEach(s=>{const b=$(s);b.textContent='Lädt …';b.disabled=true;});
  buildEngine();await Promise.all([renderLibrary(),calibrateLoop(),calibrateShaper()]);pcmPreload();ready=true;G.warm=0;ui.warmT0=performance.now();
  PARTS.forEach((_,i)=>{applyChannel(i);if(cur.parts[i].stretch)scheduleStretch(i);});runStretch();
  $('#power').textContent='Eingeschaltet';partLeds();refreshKnobs();E.mfx.forEach(s=>s.update());
  popup('msg',{t:'TX-16 READY',b:'PRESS PLAY',s:'TUBES WARM UP · OR SPACE BAR'},2500);
}
$('#power').addEventListener('click',powerOn);$('#power2').addEventListener('click',powerOn);
$('#midiBtn').addEventListener('click',async()=>{if(!ctx)await powerOn();await midiConnect();syncMidiBtn();});
$('#inBtn').addEventListener('click',async()=>{const ok=await inputOn();syncInBtn();if(!ok)popup('msg',{t:'AUDIO IN',b:'NO INPUT',s:'MICROPHONE PERMISSION NEEDED'},2600);else popup('msg',{t:'AUDIO IN',b:'CONNECTED',s:'LIMITER ON · IN MON = LISTEN'},2200);});
$('#expBtn').addEventListener('click',()=>{const b=new Blob([JSON.stringify(patternToObj())],{type:'application/json'}),u=URL.createObjectURL(b),l=document.createElement('a');l.href=u;l.download='TX16_'+patStr().replace('.','')+'_'+(cur.name||patName()).replace(/[^A-Z0-9]+/gi,'_')+'.json';document.body.appendChild(l);l.click();l.remove();setTimeout(()=>URL.revokeObjectURL(u),2000);if(ready)popup('msg',{t:'EXPORT',b:patStr(),s:'SAVED AS FILE'},1600);});
$('#impFile').addEventListener('change',async e=>{const f=e.target.files[0];e.target.value='';if(!f)return;
  try{const o=JSON.parse(await f.text());if(!ctx)await powerOn();
    if(o.tx16all){let n=0;for(const k in o.patterns){try{localStorage.setItem('tx16.v6.pat.'+k,JSON.stringify(o.patterns[k]));n++;}catch(err){}}if(o.global)Object.keys(o.global).forEach(k=>{if(typeof G[k]!=='object')G[k]=o.global[k];});
      switchPattern(ui.pattern);popup('msg',{t:'IMPORT ALL PATTERN',b:n+' PATTERNS',s:'+ GLOBAL PARAMETERS'},2400);return;}
    if(!Array.isArray(o.parts)||!Array.isArray(o.steps))throw new Error('format');
    cur=patternFromObj(o,ui.pattern);if(G.tlock===0)setBPM(cur.bpm);loadPatState();applyGlobals();PARTS.forEach((_,i)=>{applyChannel(i);if(cur.parts[i].stretch)scheduleStretch(i);});
    const ok=storePattern(ui.pattern);ui.saved=ok;resetUndo();partLeds();refreshKnobs();padLabels(true);
    popup('msg',{t:'IMPORT PATTERN > '+patStr(),b:(cur.name||patName()).slice(0,16),s:f.name.toUpperCase().slice(0,24)+' · '+cur.bpm.toFixed(1)+' BPM'+(ok?' · SAVED':'')},2600);}
  catch(err){popup('msg',{t:'IMPORT',b:'ERROR',s:'NOT A TX-16 PATTERN'},2000);}});
$('#impLbl').addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();$('#impFile').click();}});
$('#dockBtn').addEventListener('click',e=>{ui.dock=!ui.dock;dock.hidden=!ui.dock;e.currentTarget.setAttribute('aria-pressed',String(ui.dock));sizeDev();if(E)E.mfx[1].update();[0,1].forEach(i=>{drawMFXPad(i);drawOLED(i);});refreshKnob(CTRL.mfxtype2);
  if(ready)popup('msg',{t:'ADD-ON DOCK',b:ui.dock?'MFX PAD 2 FOUND':'MFX PAD 2 REMOVED',s:ui.dock?'MFX 2 RUNS AFTER MFX 1':'STANDARD: ONE MFX PAD'},2200);});
$('#helpBtn').addEventListener('click',e=>{const h=$('#help'),open=h.hidden;h.hidden=!open;e.currentTarget.setAttribute('aria-expanded',String(open));});

/* ---------- Anzeige-Loop ---------- */
const PCOL=i=>i<8?V.accent:i<10?V.accent2:i<14?'#8a5cff':'#ffb000';
const padState=new Array(24).fill('');let lcdT=0,barState='',tBuf=new Float32Array(1024),oBuf=new Float32Array(2048),iBuf=new Float32Array(1024),meterV=[0,0],lastT=0,autoT=0,warmT=0;
function peakDb(an,buf){an.getFloatTimeDomainData(buf);let p=0;for(let k=0;k<buf.length;k++)p=Math.max(p,Math.abs(buf[k]));return 20*Math.log10(p+1e-6);}
function sled(i,c){const s=SLEDS[i],v=c||'#22232a';if(s.el._c!==v){s.el._c=v;s.el.style.background=v;s.el.style.boxShadow=c?'0 0 6px '+c:'';}}
function frame(t){
  requestAnimationFrame(frame);const dt=Math.min(.1,(t-lastT)/1000);lastT=t;
  if(ready){const ct=now();while(visQ.length&&visQ[0].t<=ct){const q=visQ.shift();ui.dispStep=q.s;ui.dispT=q.t;}}
  const ct=ready?now():0,s=ui.dispStep%16,bar=curBar(),page=ui.pageSel,P=cur.parts[ui.part];
  const grp={TRIGGER:'parts',MUTE:'mute',ERASE:'erase',SEQUENCER:'steps','STEP JUMP':'steps',KEYBOARD:'notes',CHORD:'notes'}[ui.mode],nbars=cur.last/16;
  padLabels();oscLcdUpdate();
  for(let i=0;i<24;i++){let col='#1c1d22',k=0;
    if(ui.fill&&i>=16){const b=i-16,F=ui.fill;if(b<nbars){col=b===F.src?V.accent2:F.dst.has(b)?'#ffd000':'#8a8d99';k=b===F.src||F.dst.has(b)?75:14;}else{col='#40414a';k=4;}}
    else if(grp==='steps'){if(i<16){if(ui.part>=NSEQ){col='#40414a';k=4;}else{const st=page*16+i,on=cur.steps[ui.part][st],head=ui.playing&&page===bar&&i===s;col=head?'#ffffff':on?PCOL(ui.part):V.accent2;k=head?85:on?40+cur.vel[ui.part][st]/127*40:9;}}
      else{const b=i-16;if(b<nbars){col=ui.pageSel===b?V.accent2:b===bar&&ui.playing?V.accent:'#8a8d99';k=ui.pageSel===b?70:b===bar&&ui.playing?55:10;}else{col='#40414a';k=4;}}}
    else if(grp==='notes'){const n=kbNote(i),rel=((n-cur.key)%12+12)%12,inS=inScale(n);col=rel===0?V.accent:V.accent2;k=rel===0?45:inS?24:5;}
    else if(grp==='parts'&&i>=NSEQ){const hit=ready&&E&&ct>=E.partHit[i]&&ct-E.partHit[i]<.11;col='#ffb000';k=hit?95:i===ui.part?60:22;}
    else if(i<16){const hit=ready&&E&&ct>=E.partHit[i]&&ct-E.partHit[i]<.11,mu=ui.muted.has(i);
      if(grp==='mute'){const so=ui.solo.size>0,on=so?ui.solo.has(i):!mu;col=so?(on?'#ffffff':'#40414a'):mu?'#ff2020':PCOL(i);k=so?(on?(hit?95:70):6):mu?30:hit?95:45;}
      else if(grp==='erase'){const has=cur.steps[i].some(x=>x);col=has?'#ff5030':'#40414a';k=has?(hit?90:35):10;}
      else{col=mu?'#ff2020':PCOL(i);k=mu?6:hit?95:i===ui.part?55:18;}}
    if(t-ui.padFlash[i]<160||ui.held.has(i)){col='#ffffff';k=95;}
    const key=col+k;if(padState[i]!==key){padState[i]=key;const el=padEls[i];el.style.background=`color-mix(in srgb,${col} ${k}%,#1c1d22)`;el.style.boxShadow=k>50?`0 0 ${(k/100*1.2).toFixed(2)}em ${col}, 0 .3em 0 #060607`:'';el.style.color=k>50?'rgba(0,0,0,.6)':'rgba(255,255,255,.55)';}}
  const nb=cur.last/16,bkey=bar+'|'+ui.pageSel+'|'+ui.playing+'|'+nb+'|'+(Math.floor(t/250)%2)+'|'+(ui.fill?ui.fill.src+[...ui.fill.dst].join():'');if(bkey!==barState){barState=bkey;barEls.forEach((el,i)=>{let c='#22232a',gl='';
    if(i<nb){c='#3a3b44';if(ui.pageSel===i){c=V.accent2;gl=c;}if(i===bar&&ui.playing){c=ui.pageSel===i?'#ffffff':V.accent;gl=c;}if(ui.fill&&(i===ui.fill.src||ui.fill.dst.has(i))&&Math.floor(t/250)%2){c=i===ui.fill.src?V.accent2:'#ffd000';gl=c;}}
    el.style.background=c;el.style.boxShadow=gl?'0 0 7px '+gl:'';});}
  /* rote LEDs = Oktave des aktuellen Parts (-4 … +3) */
  {const oi=clamp(P.oct+4,0,7),ok2=oi+'|'+P.oct;if(octEls._k!==ok2){octEls._k=ok2;octEls.forEach((el,k)=>{const on=k===oi;el.style.background=on?'#ff2a2a':'#22232a';el.style.boxShadow=on?'0 0 7px #ff2a2a':'';});}}
  if(ready){const beat=ui.playing&&s%4===0;if(CTRL.tap.on!==beat)setLed(CTRL.tap,beat);
    const blink=Math.floor(t/400)%2===0,fast=Math.floor(t/150)%2===0,sv=ui.write&&ui.write.stage==='writing'&&t<ui.popupUntil?fast:(!ui.saved&&blink);if(CTRL.save.on!==sv)setLed(CTRL.save,sv);
    const rc=ui.rec&&(!ui.playing||blink)||(ui.resample&&fast);if(CTRL.rec.on!==rc)setLed(CTRL.rec,rc);
    const so=!!ui.soloHold||(ui.solo.size>0&&blink)||(ui.drop&&fast);if(CTRL.solo.on!==so)setLed(CTRL.solo,so);const ok=!!P.oktSend||!!ui.oktHold;if(CTRL.oktsend.on!==ok)setLed(CTRL.oktsend,ok);if(CTRL.bw.on!==!!ui.bw)setLed(CTRL.bw,!!ui.bw);
    const sq=FN.SEQUENCER&&(ui.mode==='SEQUENCER'||(ui.fill&&blink));if(FN.SEQUENCER&&FN.SEQUENCER.on!==sq)setLed(FN.SEQUENCER,sq);
    const tl=G.tlock===1||(G.tlock===2&&(ui.ramp?fast:blink));if(CTRL.tlock.on!==tl)setLed(CTRL.tlock,tl);
    const tw=P.tube&&(G.warm>=1||blink);if(CTRL.tubeon.on!==tw)setLed(CTRL.tubeon,tw);
    const pl=ui.playing||(ui.paused&&blink);if(CTRL.play.on!==pl)setLed(CTRL.play,pl);
    if(G.warm<1){G.warm=Math.min(1,(t-ui.warmT0)/8000);if(t-warmT>250||G.warm>=1){warmT=t;applyGlobals();}}
    const dbs=[G.tubeOn?peakDb(E.anTube,tBuf):-99,peakDb(E.anOut,oBuf)];
    dbs.forEach((db,mi)=>{const v=clamp((db+30)/30);meterV[mi]=Math.max(v,meterV[mi]-.03);const n=Math.round(meterV[mi]*12);meterEls[mi].forEach((el,k)=>{const c=k<n?(k<8?'#2bff6a':k<10?'#ffd000':'#ff2a2a'):'#22232a';if(el._c!==c){el._c=c;el.style.background=c;el.style.boxShadow=k<n?'0 0 6px '+c:'';}});});
    sled(1,MIDI.acc?(t-MIDI.act<90?'#ffffff':V.accent):null);
    const ext=ui.extClock&&performance.now()-MIDI.lastTick<1000;if(ui.extClock&&!ext)ui.extClock=false;sled(2,ext?(Math.floor(t/120)%2?'#ffd000':null):ui.playing&&s%4===0?V.accent2:null);
    if(E.in){const db=peakDb(E.in.an,iBuf);sled(3,db>-1.5?'#ff2a2a':db>-30?'#2bff6a':'#1d4a2a');
      if(G.inAuto&&t-autoT>300){autoT=t;const pre=peakDb(E.in.pre,iBuf);if(pre>-60){const want=-12-pre,cur2=-18+G.inGain*36,nv=clamp((cur2+(want-cur2)*.25+18)/36);if(Math.abs(nv-G.inGain)>.005){G.inGain=nv;applyInput();refreshKnob(CTRL.ingain);}}}}else sled(3,null);
    const lh=G.limiter&&E.limiter.reduction<-3;if(lh)ui.limHot=t;sled(4,lh?'#ff2a2a':null);sled(5,ui.playing?'#3a7bff':null);}
  const fl=reduced?0:Math.sin(t/77)*.06+Math.sin(t/31)*.03,gv=ready?(G.tubeOn?(.15+.85*G.warm)*(.5+meterV[0]*.45+fl):.06):.35;win.style.setProperty('--g',gv.toFixed(3));
  if(t-lcdT>66){lcdT=t;drawLCD(t);}
  drawSeg(t<ui.segUntil?ui.segMsg:ui.pendingPat&&Math.floor(t/300)%2?'P.'+pad3(ui.pendingPat):G.bpm.toFixed(1).padStart(5,' '));
}

/* ---------- Start ---------- */
sled(0,V.accent2);
ALLB.forEach(d=>setLed(d,false));setLed(FN[ui.mode],true);padModeLeds();setLed(CTRL.tubeon,G.tubeOn);setLed(CTRL.mfxon2,true);setLed(CTRL.motion,ui.motion);partLeds();padLabels();
refreshKnobs();refreshKnob(CTRL.mfxtype2);[0,1].forEach(i=>{drawMFXPad(i);drawOLED(i);});
resetUndo();
requestAnimationFrame(frame);
Promise.race([document.fonts.load('8px Silkscreen'),new Promise(r=>setTimeout(r,2500))]).then(()=>{[0,1].forEach(drawOLED);});
})();
</script>

