/* ---------- Zustand ---------- */
const G={bpm:186,master:.8,metro:0,metroLvl:.6,metroSnd:0,color:1,analog:.5,tsRange:2,trigMode:0,velCurve:1,midiCh:1,rxFilter:0,txFilter:0,syncPol:0,syncUnit:0,knobMode:0,lcd:13,autoOff:1,powerSave:0,ptnLock:false,chainMode:true,phones:.85,tubeOn:true,warm:0,scRel:.5,glueDrive:.5,limiter:true,led:.16,
  tlock:0,rampBars:4,inGain:.5,inMon:false,inAuto:true,midi:{clock:2,clockOut:true,keyb:0,notesOut:false,ccIn:true,pc:true,thru:false},syncOut:2,syncIn:2};
const ui={mode:'SEQUENCER',part:10,pattern:1,saved:true,playing:false,rec:false,shift:false,shiftLatch:false,shiftT:0,shiftUsed:false,
  muted:new Set(),solo:new Set(),pageSel:0,padMode:0,fill:null,arp:{on:false,next:0,k:0},ts:null,modeHold:null,clip:null,chainCount:0,stepSel:0,absStep:0,ev:{rec:false,play:false,list:[],t0:0,k:0},util:{pat:1,part:0,swap:0,dst:2},motion:true,accent:false,drop:false,resample:false,fillBar:-1,menu:-1,menuItem:0,
  popup:null,popupUntil:0,write:null,segMsg:'',segUntil:0,lastCtrl:'cutoff',taps:[],copy:false,undo:null,redo:null,
  padFlash:new Array(24).fill(-1e9),dispStep:0,dispT:0,fxPage:0,fxSel:0,rollType:2,rollOn:false,rollHeld:false,held:new Map(),
  pendingPat:null,ramp:null,initConfirm:0,dock:false,
  mfx:[{type:0,on:true,hold:false,touch:null},{type:5,on:true,hold:false,touch:null}]};
const ONE_SHOT=0,CUT=1;
const DEF=[
  {src:'KICK HARD',lvl:.9,dec:.75},{src:'KICK TOK',lvl:.5,dec:.4},{src:'CLAP TEKK',lvl:.66,dec:.6,lc:.45},{src:'HAT 909 C',lvl:.48,dec:.3,pan:.44,lc:.7},
  {src:'HAT 909 O',lvl:.55,dec:.5,pan:.56,lc:.7},{src:'RIDE',lvl:.4,dec:.75,pan:.6,lc:.7},{src:'PERC',lvl:.5,dec:.4,pan:.36,lc:.45},{src:'CRASH',lvl:.45,dec:.95,lc:.5},
  {src:'BASS ROLL',lvl:.78,dec:.36,cut:.62,reso:.3,eg:.7,mono:true,glue:true},
  {src:'OFF',osc:'SINE',lvl:.6,dec:.4,mono:true,edit:.15,voice:0},
  {src:'OFF',osc:'SUPERSAW',lvl:.6,dec:.5,cut:.78,reso:.22,eg:.62,edit:.45,sc:.45,lc:.5,glue:true,fx:[['DELAY 1/8.',.45],['HALL',.35]]},
  {src:'OFF',osc:'HOOVER',lvl:.45,dec:.42,cut:.85,edit:.5,sc:.4,lc:.5,mono:true},
  {src:'HT MELO AM',lvl:.5,dec:1,stretch:2,len:3,loop:4,sc:.4,lc:.5},{src:'VOX HEY',lvl:.55,dec:1,lc:.5},
  {src:'RISER',lvl:.48,dec:1,lc:.45},{src:'IMPACT',lvl:.6,dec:1},
  {src:'VOX HO',lvl:.6,dec:1,lc:.5},{src:'VOX YEAH',lvl:.6,dec:1,lc:.5},{src:'LASER',lvl:.5,dec:1,lc:.4},{src:'SIREN',lvl:.45,dec:1,lc:.4},
  {src:'NOISE UP',lvl:.5,dec:1,lc:.5},{src:'SUB DROP',lvl:.6,dec:1},{src:'STAB MINOR',lvl:.5,dec:1,lc:.45},{src:'HOOVER STAB',lvl:.45,dec:1,lc:.45}
];
const srcIdx=n=>Math.max(0,SRC.findIndex(s=>s.n===n));
const FX_DEF=IFXS.indexOf('DELAY 1/8');
const emptyFx=()=>({on:false,type:FX_DEF,edit:.4});
function newPart(i){const d=DEF[i],fx=Array.from({length:5},emptyFx),om=d.osc?OSC_MAP[d.osc]:null;(d.fx||[]).forEach(([t,e],k)=>{fx[k]={on:true,type:IFXS.indexOf(t),edit:e};});
  return{src:srcIdx(d.src),osc:om?om[0]:0,wave:om?om[1]:0,blend:d.blend??.5,pitch:0,edit:om?om[2]:0,edit2:om?om[3]:.5,mEgT:.45,egAL:1,egDL:null,egST:0,oktSend:false,lenSt:((d.len??3)+1)*16,
    eqLF:.434,eqHF:.593,eqLQ:0,eqMQ:.347,eqHQ:0,hc:1,start:0,smpEnd:1,loopOn:false,loopStart:0,smpLvl:1,tune:0,len:d.len??3,stretch:d.stretch??0,reverse:false,
    ftype:0,cut:d.cut??1,reso:d.reso??.1,eg:d.eg??.5,mtype:MODS.indexOf('LFOTRIB FILTER'),speed:.45,depth:0,sync:true,lvl:d.lvl/Math.SQRT2,druck:0,egS:0,egR:.15,egDl:0,egH:0,egCA:.5,egCD:.5,egCR:.5,pan:d.pan??.5,att:0,dec:d.dec,egOn:true,mono:d.mono??true,
    voice:d.voice??(d.mono===false?3:1),prio:i<2?1:0,motionMode:1,scaleMode:0,grooveT:0,grooveD:.5,lastStep:0,glide:0,trgVel:false,
    oct:0,tr:0,eqL:.5,eqM:.5,eqF:.5,eqH:.5,eqD:0,eqX:1,glueOn:!!d.glue,sc:d.sc??0,scSrc:0,lc:d.lc??0,send:true,rollSend:true,glueDrv:.5,tube:true,tubeMix:.45,driveA:i<8?.3:.4,driveB:.25,choke:0,ftrack:false,loopN:d.loop??0,rel:i<8||i>=NSEQ?ONE_SHOT:CUT,fx};}
const PROG=[[0,-4,3,-2],[0,0,-4,-2],[0,3,-2,-4],[0,-2,-4,-5]];
const LEAD=[[0,12],[2,15],[3,19],[5,24],[7,22],[8,19],[10,15],[13,17],[14,12]];
/* Alles, was zum Pattern gehört (wie Electribe 2), wird mit dem Pattern gespeichert und beim Wechsel komplett geladen */
const PATKEYS=['bpm','key','scale','last','level','beat','swing','chordSet','gateArp','alt2122','alt2324','chainTo','chainRep','mfx','rollType','mutes','xn','name','glue'];
function blankPattern(n){const P={parts:PARTS.map((_,i)=>newPart(i)),steps:[],notes:[],vel:[],gate:[],rat:[],motion:PARTS.map(()=>({})),bpm:PATBPM[(n-1)%PATBPM.length],key:9,scale:6,last:128,
    level:100,beat:0,swing:.5,chordSet:1,gateArp:0,alt2122:false,alt2324:false,chainTo:0,chainRep:1,mfx:[{type:0,on:true},{type:5,on:true}],rollType:2,mutes:[],
    xn:Array.from({length:16},()=>({})),name:PATNAMES[(n-1)%PATNAMES.length],glue:.5};
  for(let p=0;p<16;p++){P.steps.push(new Uint8Array(128));P.notes.push(new Int8Array(128).fill(57));P.vel.push(new Uint8Array(128).fill(100));P.gate.push(new Uint8Array(128));P.rat.push(new Uint8Array(128).fill(1));}
  return P;}
function genPattern(n){
  const r=srand(n*7919+13),P=blankPattern(n),prog=PROG[(n-1)%PROG.length],rot=(n-1)%5;
  const percMask=[3,11,14].filter(()=>r()<.8);
  for(let s=0;s<128;s++){
    const b=s>>4,q=s%16,root=prog[b%4],on=(p,v=100,nt=57)=>{P.steps[p][s]=1;P.vel[p][s]=v;P.notes[p][s]=nt;};
    if(s%4===0)on(0,112);
    if(s%4===0)on(1,90);
    if(q===4||q===12)on(2,105);
    if(s%2===1)on(3,s%4===3?78:58);
    if(s%4===2)on(4,92);
    if(b>=4&&s%4===0)on(5,70);
    if(percMask.includes(q))on(6,85);
    if(s===0||s===64)on(7,100);
    if(s%4===2||s%4===3)on(8,s%4===2?110:92,33+root);
    if(s%4===2)on(9,100,33+root);
    const l=LEAD.find(x=>x[0]===(q+rot)%16);if(l)on(10,100,57+root+l[1]);
    if(q%8===0||q%8===3||q%8===6)on(11,95,45+root+12);
    if(s===60||s===124)on(13,100,57);
    if(s===96)on(14,100,57);
    if(s===0)on(15,110,57);
  }
  [3,7].forEach(b=>{for(let q=12;q<16;q++)P.steps[2][b*16+q]=1;});
  return P;
}
let cur=genPattern(1);
const ARR=['steps','notes','vel','gate','rat'],ARRT={steps:Uint8Array,notes:Int8Array,vel:Uint8Array,gate:Uint8Array,rat:Uint8Array};
function fixPart(p,i){const d=newPart(i);for(const k in d)if(p[k]===undefined)p[k]=d[k];if(!Array.isArray(p.fx)||!p.fx.length)p.fx=d.fx;p.fx=p.fx.slice(0,5);while(p.fx.length<5)p.fx.push(emptyFx());return p;}
function patternFromObj(o,n){const P=blankPattern(n),ver=parseFloat(o.tx16)||0;if(ver<.8)o.parts.forEach(p=>p.mono=true); // ab 0.8: CUT ITSELF (MONO) ist Standard
  if(ver<.9)o.parts.forEach(p=>{if(p.src>0&&p.osc>0){if((p.blend??.5)>=.5)p.src=0;else p.osc=0;}}); // ab 0.9: Sample ODER Oszillator, kein BLEND mehr
  /* Modulation, Voice Assign, Skalen, Grooves auf Electribe-2-Listen umrechnen */
  const E2M=(src,dst)=>Math.max(0,MODS.indexOf((src+' '+dst).toUpperCase()));
  if(ver<1)o.parts.forEach(p=>{const OLD={0:['LFOTriB','Filter'],1:['SawUpB','Filter'],2:['SquUpB','Filter'],3:['S&HBPM','Filter'],4:['EG+','Filter'],5:['EG+','Pitch'],6:['LFOTriB','Pan'],7:['LFOTriB','Level']}[p.mtype]||['LFOTriB','Filter'];
    p.mtype=E2M(...OLD);if(p.voice===undefined)p.voice=p.mono===false?2:0;if(p.src>0&&!p.osc)p.edit=0;delete p.asOsc;p.v10=1;});
  if(ver<1.1){o.parts.forEach(p=>{if(!p.v10){const W={1:'LFOTriB',2:'LFOTriB',3:'SawUpB',4:'SawDwnB',5:'SquUpB',6:'S&HBPM',7:'Random'},D=['Pitch','Filter','Level','Pan'];const m=p.mtype|0;
        p.mtype=m===0?E2M('LFOTriB','Filter'):m<=28?E2M(W[(m-1)%7+1],D[Math.floor((m-1)/7)]):E2M(m===31?'EG+':m===30?'EG-':'EG+',m===31?'Filter':'Pitch');if(m===0)p.depth=0;}
      delete p.v10;p.voice=[1,0,3,3][p.voice|0];p.grooveT=[0,19,19,1,21,20,15,16,4,19][p.grooveT|0]??0;});
    o.scale=[6,8,3,1,0][o.scale|0]??6;o.gateArp=0;o.chordSet=1;}
  if(ver<1.1){o.parts.forEach(p=>(p.fx||[]).forEach(f=>{if(f.type>=97)f.type+=11;}));(o.mfx||[]).forEach(m=>{if(m.type>=24)m.type+=3;});} // Rev 1.0: 11 IFX + 3 MFX eingefügt
  /* Rev 1.2: LEVEL geht bis doppelt so laut (+6 dB). Alte Werte so umrechnen, dass sie gleich laut bleiben */
  if(ver<1.2){o.parts.forEach(p=>{if(typeof p.lvl==='number')p.lvl/=Math.SQRT2;});(o.motion||[]).forEach(m=>{for(const s in m)if(m[s]&&typeof m[s].lvl==='number')m[s].lvl/=Math.SQRT2;});}
  /* Rev 2.0 (Plan 10.10.): SYNTH OSCILLATOR = Korg EMX, alte 88 OSCs auf den ähnlichsten EMX-Typ umrechnen. Stretch-Länge jetzt in Steps, EG TIME eigener Regler */
  if(ver<1.3)o.parts.forEach(p=>{const nm=OLD_OSCS[p.osc|0];if(p.osc>0&&nm){const m=OSC_MAP[nm]||[1,0,0,.5];p.osc=m[0];p.wave=m[1];p.edit=m[2];p.edit2=m[3];}else p.osc=0;
    p.lenSt=((p.len??3)+1)*16;p.mEgT=p.speed??.45;});
  /* Rev 2.2: PCM OSC+COMB / PCM OSC+WS haben jetzt die 76 EMX-PCM-Wellen. Vorher war dort ein TX-Sample gewählt -> der Part spielt dieses Sample direkt */
  if(ver<1.4)o.parts.forEach(p=>{if(p.osc===14||p.osc===15){p.src=(p.wave|0)+1;p.osc=0;p.wave=0;}});
  P.parts=o.parts.map(fixPart);while(P.parts.length<PARTS.length)P.parts.push(newPart(P.parts.length));
  ARR.forEach(k=>{if(o[k])P[k]=o[k].map(a=>ARRT[k].from(a));});P.motion=o.motion||P.motion;while(P.motion.length<PARTS.length)P.motion.push({});
  PATKEYS.forEach(k=>{if(o[k]!==undefined)P[k]=o[k];});return P;}
function patternToObj(){const o={tx16:'1.4',parts:cur.parts,motion:cur.motion};PATKEYS.forEach(k=>o[k]=cur[k]);ARR.forEach(k=>o[k]=cur[k].map(a=>Array.from(a)));return o;}
function loadPattern(n){
  try{const raw=localStorage.getItem('tx16.v6.pat.'+n);if(raw)return patternFromObj(JSON.parse(raw),n);}catch(e){}
  return genPattern(n);
}
function storePattern(n){try{localStorage.setItem('tx16.v6.pat.'+n,JSON.stringify(patternToObj()));return true;}catch(e){return false;}}

/* ---------- Audio-Engine ---------- */
let ctx=null,E=null,ready=false;
const IFX_KIND=FXLIB.map(x=>x[1]),MFX_KIND=MFXL.map(x=>x[1]);
const SEQ_MFX=new Set(['tape','vinyl','pdrop','beatrep','revroll','doubler','oddstep','evenstep']);
const SHF={tube:x=>Math.tanh(x+.25)-Math.tanh(.25),soft:x=>Math.tanh(x),hard:x=>clamp(x,-1,1),diode:x=>x>0?1-Math.exp(-x):-.4*(1-Math.exp(x)),diode2:x=>x>0?Math.tanh(x*1.5):Math.tanh(x*.4)*.8,
  fold:x=>Math.sin(x*Math.PI/2),linfold:x=>{const y=((x+1)%4+4)%4;return y<2?y-1:3-y;},zero:x=>Math.sign(x)*Math.min(1,x*x),rect:x=>Math.abs(Math.tanh(x)),half:x=>Math.max(0,Math.tanh(x)),
  asym:x=>x>0?Math.tanh(x):Math.tanh(x*.35),xshape:x=>{const y=Math.tanh(x);return 1.5*y-.5*y*y*y;},fuzz:x=>Math.sign(x)*(1-Math.exp(-Math.abs(x)*3)),od:x=>x/(1+Math.abs(x)),
  dist:x=>Math.tanh(x*1.5)*.9+.1*clamp(x,-1,1),distheavy:x=>Math.sign(x)*Math.pow(Math.abs(Math.tanh(x*2)),.6),disttekk:x=>{const y=Math.tanh(x*2.2+.15)-Math.tanh(.15);return clamp(y*1.25,-1,1);}};
const SHK={dist:22,distheavy:30,disttekk:26,tube:12,soft:14,hard:16,diode:12,diode2:12,fold:6,linfold:5,zero:4,rect:6,half:6,asym:12,xshape:4,fuzz:20,od:14};
const now=()=>ctx.currentTime;
const gainN=(v=1)=>{const g=ctx.createGain();g.gain.value=v;return g;};
const biqN=(type,f,q=.7)=>{const b=ctx.createBiquadFilter();b.type=type;b.frequency.value=f;b.Q.value=q;return b;};
function curve(fn,n=4096){const c=new Float32Array(n);let mx=1e-9;for(let k=0;k<n;k++){c[k]=fn(k/(n-1)*2-1);mx=Math.max(mx,Math.abs(c[k]));}for(let k=0;k<n;k++)c[k]/=mx;return c;}
function irGen(sec,shape,dark=0){const R=ctx.sampleRate,len=Math.ceil(sec*R),b=ctx.createBuffer(2,len,R);for(let c=0;c<2;c++){const d=b.getChannelData(c);let lp=0;for(let k=0;k<len;k++){let n=Math.random()*2-1;if(dark){lp+=(n-lp)*dark;n=lp*2.2;}d[k]=n*shape(k/len,k/R);}}return b;}
function makeIR(sec,decay){const len=Math.ceil(sec*ctx.sampleRate),b=ctx.createBuffer(2,len,ctx.sampleRate);for(let c=0;c<2;c++){const d=b.getChannelData(c);for(let k=0;k<len;k++)d[k]=(Math.random()*2-1)*Math.pow(1-k/len,decay);}return b;}
const stepLen=()=>60/G.bpm/4*BEATLEN[cur.beat||0];
function syncTime(div){return 60/G.bpm*div;}
const hold=(p,t)=>{if(p.cancelAndHoldAtTime)p.cancelAndHoldAtTime(t);else{p.cancelScheduledValues(t);}};

/* Looper: Delay mit 100 % Rückkopplung. Beim Einrasten werden die letzten L Sekunden endlos wiederholt (Brrrp). */
let LOOPC=0;
/* WaveShaper mit Oversampling verzögert um 128-192 Samples. Trockene Parallelwege bekommen dieselbe Verzögerung, sonst entsteht ein Kammfilter (Bass schwingt lauter/leiser). */
const SHL={'2x':128,'4x':192};
async function calibrateShaper(){try{for(const os of ['2x','4x']){const sr=ctx.sampleRate,oc=new OfflineAudioContext(1,4096,sr),b=oc.createBuffer(1,4096,sr);b.getChannelData(0)[1000]=.5;
  const s=oc.createBufferSource(),w=oc.createWaveShaper(),c=new Float32Array(1024);for(let k=0;k<1024;k++)c[k]=k/1023*2-1;s.buffer=b;w.curve=c;w.oversample=os;s.connect(w);w.connect(oc.destination);s.start();
  const d=(await oc.startRendering()).getChannelData(0);let mi=0;for(let k=0;k<d.length;k++)if(Math.abs(d[k])>Math.abs(d[mi]))mi=k;SHL[os]=Math.max(0,mi-1000);}
  if(E)E.ch.forEach(c=>{c.tdly.delayTime.value=2*SHL['2x']/ctx.sampleRate;c.eqDl=-1;});}catch(e){}}
const shDelay=os=>{const d=ctx.createDelay(.05);d.delayTime.value=SHL[os]/ctx.sampleRate;return d;};
const tubeDelay=()=>{const d=ctx.createDelay(.05);d.delayTime.value=2*SHL['2x']/ctx.sampleRate;return d;};
/* Browser hängen im Rückkopplungs-Kreis oft einen Audio-Block an. Einmal messen und abziehen. */
async function calibrateLoop(){try{const sr=ctx.sampleRate,oc=new OfflineAudioContext(1,Math.round(sr*.5),sr),g=v=>{const x=oc.createGain();x.gain.value=v;return x;};
  const gate=g(1),dl=oc.createDelay(1),fb=g(0),o=oc.createOscillator(),L=Math.round(sr*.02);o.frequency.setValueAtTime(150,0);o.frequency.linearRampToValueAtTime(1800,.5);o.start();
  o.connect(gate);gate.connect(dl);dl.connect(fb);fb.connect(dl);dl.connect(oc.destination);dl.delayTime.value=.1;
  dl.delayTime.setValueAtTime(L/sr,.2);gate.gain.setValueAtTime(0,.2);fb.gain.setValueAtTime(1,.2);
  const d=(await oc.startRendering()).getChannelData(0),a0=Math.round(sr*.34);let best=-2,bl=L;
  for(let lag=L-16;lag<L+400;lag++){let s=0,e1=0,e2=0;for(let k=0;k<1200;k++){const x=d[a0+k],y=d[a0+k+lag];s+=x*y;e1+=x*x;e2+=y*y;}const c=s/Math.sqrt(e1*e2+1e-12);if(c>best){best=c;bl=lag;}}
  if(best>.98)LOOPC=clamp((bl-L)/sr,0,.012);}catch(e){}}
const loopDT=L=>Math.max(160/ctx.sampleRate,L-LOOPC);
class Looper{
  constructor(){this.inp=gainN();this.out=gainN();this.dry=gainN(1);this.gate=gainN(1);this.dl=ctx.createDelay(2);this.fb=gainN(0);this.wet=gainN(0);this.dl.delayTime.value=.5;
    this.inp.connect(this.dry);this.dry.connect(this.out);this.inp.connect(this.gate);this.gate.connect(this.dl);this.dl.connect(this.fb);this.fb.connect(this.dl);this.dl.connect(this.wet);this.wet.connect(this.out);this.on=false;this.L=0;}
  engage(t,L,toL,dur,mix=1){const d=this.dl.delayTime;hold(d,t);d.setValueAtTime(loopDT(L),t);if(toL)d.exponentialRampToValueAtTime(loopDT(toL),t+dur);this.L=L;
    [[this.gate,0],[this.fb,.999],[this.wet,mix],[this.dry,1-mix]].forEach(([g,v])=>{hold(g.gain,t);g.gain.setTargetAtTime(v,t,.0015);});this.on=true;}
  length(L,t){this.L=L;this.dl.delayTime.setTargetAtTime(loopDT(L),t,.03);}
  mix(m,t){if(!this.on)return;this.wet.gain.setTargetAtTime(m,t,.01);this.dry.gain.setTargetAtTime(1-m,t,.01);}
  release(t){[[this.wet,0],[this.dry,1]].forEach(([g,v])=>{hold(g.gain,t);g.gain.setTargetAtTime(v,t,.004);});[[this.fb,0],[this.gate,1]].forEach(([g,v])=>{hold(g.gain,t);g.gain.setValueAtTime(v,t+.03);});this.on=false;}
}

function makeFX(kind,o={}){
  const inp=gainN(),out=gainN(),T=()=>now();let set=()=>{},stops=[],extra={};
  const lfo=(type,f)=>{const x=ctx.createOscillator();x.type=type;x.frequency.value=f;x.start();stops.push(x);return x;};
  const dryWetD=(wetNode,dry,os)=>{const dl=shDelay(os),d=gainN(dry),w=gainN(1);inp.connect(dl);dl.connect(d);d.connect(out);wetNode.connect(w);w.connect(out);return{d,w};};
  const dryWet=(wetNode,dry=1)=>{const d=gainN(dry),w=gainN(1);inp.connect(d);d.connect(out);wetNode.connect(w);w.connect(out);return{d,w};};
  const fq=a=>20*Math.pow(2,clamp(a)*10),tg=(p,v,tc=.02)=>p.setTargetAtTime(v,T(),tc);
  const ser=(...n)=>{for(let k=0;k<n.length-1;k++)n[k].connect(n[k+1]);return n[n.length-1];};
  const hz=div=>1/syncTime(div),mixer=(w,d,m)=>{w.gain.value=m;d.gain.value=1-m;};
  const stereoIn=()=>{const up=gainN(1);up.channelCount=2;up.channelCountMode='explicit';up.channelInterpretation='speakers';inp.connect(up);const sp=ctx.createChannelSplitter(2);up.connect(sp);return sp;};
  switch(kind){
    case 'filt':{const fs=[];let n=inp;
      if(o.drive||o.acid){const pre=ctx.createWaveShaper();pre.curve=curve(x=>Math.tanh(x*(o.acid?2:1.4)));pre.oversample='2x';n.connect(pre);n=pre;}
      for(let k=0;k<o.n;k++){const f=biqN(o.t,1000,.7);n.connect(f);n=f;fs.push(f);}
      let post=null;if(o.ms){post=ctx.createWaveShaper();n.connect(post);n=post;}
      const mk=gainN(1);n.connect(mk);mk.connect(out);
      set=(a,b)=>{const x=o.inv?1-a:a,f=fq(o.t==='highpass'?x*.92:.04+x*.96),r=o.res?(b??.3):(o.acid?.75:o.ms?.6:.35),bp=o.t==='bandpass'||o.t==='notch';
        fs.forEach((F,k)=>{tg(F.frequency,f,.015);F.Q.value=bp?.6+r*r*22:o.t==='peaking'?1+r*8:r*r*(o.acid?34:26)*(fs.length>1?(k?.35:.65):1);if(o.t==='peaking')F.gain.value=6+r*12;});
        if(post)post.curve=curve(x=>Math.tanh(x*(1+r*5)));mk.gain.value=o.t==='bandpass'?1+r*1.5:1/(1+r*(o.acid?.6:.35));};break;}
    case 'shelf':{const f=biqN(o.t,o.f,.7);let n=ser(inp,f);if(o.sat){const w=ctx.createWaveShaper();w.curve=curve(x=>Math.tanh(1.3*x));n.connect(w);n=w;}n.connect(out);
      set=a=>{f.gain.value=o.sat?a*12:(a-.5)*36;};break;}
    case 'tilt':{const lo=biqN('lowshelf',300),hi=biqN('highshelf',3000);ser(inp,lo,hi,out);set=a=>{const g=(a-.5)*24;lo.gain.value=-g;hi.gain.value=g;};break;}
    case 'eq':{const lo=biqN('lowshelf',120),mid=biqN('peaking',1100,.9),hi=biqN('highshelf',7500);ser(inp,lo,mid,hi,out);set=a=>{lo.gain.value=a*8;mid.gain.value=-a*4;hi.gain.value=a*7;};break;}
    case 'dj':{const lp=biqN('lowpass',20000),hp=biqN('highpass',20);ser(inp,lp,hp,out);
      set=(a,b)=>{const r=o.res?(b??.3)*20:6;if(a<.47){tg(lp.frequency,fq(.15+a/.47*.85));tg(hp.frequency,20);}else if(a>.53){tg(hp.frequency,fq((a-.53)/.47*.85));tg(lp.frequency,20000);}else{tg(lp.frequency,20000);tg(hp.frequency,20);}lp.Q.value=r;hp.Q.value=r;};break;}
    case 'formant':{const sum=gainN(1.8),bs=[0,1,2].map(()=>{const b=biqN('bandpass',800,8);inp.connect(b);b.connect(sum);return b;});const{d,w}=dryWet(sum,0);
      set=(a,b)=>{const v=clamp(a)*(VOWELS.length-1.001),i0=Math.floor(v),fr=v-i0,A=VOWELS[i0],B=VOWELS[i0+1];bs.forEach((bp,k)=>{tg(bp.frequency,A[k]+(B[k]-A[k])*fr,.03);bp.Q.value=6+k*3;});mixer(w,d,o.res?(b??.7):.85);};break;}
    case 'comb':{const dl=ctx.createDelay(.2),fb=gainN(.6);inp.connect(dl);dl.connect(fb);fb.connect(dl);const{d,w}=dryWet(dl,.6);
      set=(a,b)=>{const f=40*Math.pow(2,a*7),r=o.res?(b??.6):.75;tg(dl.delayTime,loopDT(1/f),.02);fb.gain.value=(o.neg?-1:1)*(.3+r*.65);w.gain.value=.7;};break;}
    case 'reson':{const sum=gainN(1),R=o.metal?[1,2.76,5.4,8.93]:[1,2,3,4],bs=R.map(()=>{const b=biqN('bandpass',500,30);inp.connect(b);b.connect(sum);return b;});const{d,w}=dryWet(sum,1);
      set=a=>{const f=o.hi?1500*Math.pow(2,a*2.4):60*Math.pow(2,a*6);bs.forEach((b,k)=>{tg(b.frequency,Math.min(18000,f*R[k]),.03);b.Q.value=o.hi?60:35;});w.gain.value=o.hi?3:2.2;d.gain.value=o.hi?.8:.5;};break;}
    case 'autof':{const f=biqN(o.t,o.f,o.wah?6:8),dep=gainN(0),l=lfo(o.wah?'triangle':'sine',2);l.connect(dep);dep.connect(f.detune);ser(inp,f,out);
      set=(a,b)=>{const divs=[2,1,.5,.25,.125];if(o.div){l.frequency.value=hz(o.div);dep.gain.value=1200+a*3600;f.frequency.value=o.f*Math.pow(2,a*2);}
        else if(o.sync){l.frequency.value=hz(divs[Math.round(a*4)]);dep.gain.value=600+(b??.7)*4200;}else{l.frequency.value=.1+a*a*8;dep.gain.value=2400;}};break;}
    case 'tok':{const c=ctx.createDynamicsCompressor(),pk=biqN('peaking',1600,1.2);c.threshold.value=-20;c.ratio.value=4;c.attack.value=.03;c.release.value=.08;ser(inp,c,pk,out);set=a=>{pk.gain.value=a*12;};break;}
    case 'shape':{const pre=gainN(1),sh=ctx.createWaveShaper(),hp=biqN('highpass',18),post=gainN(.9);sh.oversample='4x';ser(inp,pre,sh,hp,post);const{d,w}=dryWetD(post,0,'4x');let la=-1;
      set=(a,b)=>{if(Math.abs(a-la)>.004){la=a;const k=1+a*(o.gentle?4:SHK[o.f]||10);sh.curve=curve(x=>SHF[o.f](x*k));}mixer(w,d,b??1);};break;}
    case 'deci':case 'crush':{const sh=ctx.createWaveShaper(),lp=biqN('lowpass',16000),{d,w}=dryWet(lp,0);inp.connect(sh);sh.connect(lp);let la=-1;
      set=(a,b=1)=>{if(Math.abs(a-la)>.01){la=a;const bits=Math.max(2,Math.round(14-a*11)),lv=Math.pow(2,bits);sh.curve=curve(x=>Math.round(x*lv)/lv,8192);}lp.frequency.value=kind==='deci'?16000-a*14000:18000;mixer(w,d,b);};break;}
    case 'lofi':{const lp=biqN('lowpass',5000),sh=ctx.createWaveShaper(),n=ctx.createBufferSource(),ng=gainN(0);n.buffer=E.noise;n.loop=true;n.start();stops.push(n);n.connect(ng);ser(inp,sh,lp);ng.connect(lp);const{d,w}=dryWet(lp,0);let la=-1;
      set=(a,b)=>{if(Math.abs(a-la)>.01){la=a;const lv=Math.pow(2,Math.round(12-a*8));sh.curve=curve(x=>Math.round(x*lv)/lv,8192);}tg(lp.frequency,9000-a*7000);ng.gain.value=.004+a*.02;mixer(w,d,b??1);};break;}
    case 'vinylfx':{const lp=biqN('lowpass',7000),hp=biqN('highpass',60),cr=ctx.createBufferSource(),cg=gainN(0),dl=ctx.createDelay(.05),wl=lfo('sine',.55),wd=gainN(.0012);cr.buffer=E.crackle;cr.loop=true;cr.start();stops.push(cr);
      dl.delayTime.value=.006;wl.connect(wd);wd.connect(dl.delayTime);ser(inp,dl,hp,lp,out);cr.connect(cg);cg.connect(out);set=a=>{cg.gain.value=a*.25;wd.gain.value=.0003+a*.002;tg(lp.frequency,9000-a*5000);};break;}
    case 'radio':{const hp=biqN('highpass',o.phone?350:o.mega?700:400,.9),lp=biqN('lowpass',o.phone?3200:o.mega?4500:5000,.9),sh=ctx.createWaveShaper(),pk=biqN('peaking',o.mega?2000:1400,1);pk.gain.value=6;
      ser(inp,hp,lp,pk,sh);const{d,w}=dryWet(sh,0);let la=-1;set=a=>{if(Math.abs(a-la)>.01){la=a;sh.curve=curve(x=>Math.tanh(x*(1+a*(o.mega?18:6))));}w.gain.value=.4+a*.6;d.gain.value=0;};break;}
    case 'cassette':{const dl=ctx.createDelay(.05),wl=lfo('sine',.7),wd=gainN(.001),lp=biqN('lowpass',9000),sh=ctx.createWaveShaper();sh.curve=curve(x=>Math.tanh(1.4*x));dl.delayTime.value=.008;wl.connect(wd);wd.connect(dl.delayTime);ser(inp,dl,sh,lp,out);
      set=a=>{wd.gain.value=.0003+a*.003;wl.frequency.value=.4+a*1.2;tg(lp.frequency,12000-a*8000);};break;}
    case 'chorus':case 'flanger':case 'flangerJet':{const dl=ctx.createDelay(.05),dep=gainN(),fb=gainN(0),l=lfo('sine',.5);l.connect(dep);dep.connect(dl.delayTime);inp.connect(dl);dl.connect(fb);fb.connect(dl);dryWet(dl,1);
      set=(a,b=.5)=>{if(kind==='chorus'){dl.delayTime.value=.018;dep.gain.value=.002+a*.006;l.frequency.value=.3+a*1.5;}else{dl.delayTime.value=.004;dep.gain.value=.0032;l.frequency.value=.08+a*(kind==='flangerJet'?3:1.2);fb.gain.value=kind==='flangerJet'?.4+b*.55:.55;}};break;}
    case 'dimension':case 'spacedim':{const sum=gainN(.5),N=o.wide?6:4,deps=[];for(let k=0;k<N;k++){const dl=ctx.createDelay(.06),dep=gainN(.0025),l=lfo('sine',.2+k*.17),p=ctx.createStereoPanner();dl.delayTime.value=.008+k*.004;p.pan.value=k%2?.8:-.8;l.connect(dep);dep.connect(dl.delayTime);ser(inp,dl,p,sum);deps.push(dep);}
      let wetSrc=sum;if(kind==='spacedim'){const cv=ctx.createConvolver();cv.buffer=E.ir.plate;const s2=gainN(1);sum.connect(s2);sum.connect(cv);cv.connect(s2);wetSrc=s2;}
      const{d,w}=dryWet(wetSrc,1);set=(a,b)=>{deps.forEach(x=>x.gain.value=.001+a*.004);const m=b??a;w.gain.value=(o.wide?.9:.7)*m+.1;d.gain.value=1-m*.3;};break;}
    case 'phaser':{let n=inp;const aps=[];for(let k=0;k<(o.n||4);k++){const ap=biqN('allpass',700,.6);n.connect(ap);n=ap;aps.push(ap);}let l=null,dep=null;if(!o.stat){l=lfo('sine',.4);dep=gainN(600);l.connect(dep);aps.forEach(ap=>dep.connect(ap.frequency));}dryWet(n,1);
      set=(a,b)=>{if(o.stat)aps.forEach(ap=>tg(ap.frequency,fq(a)));else{l.frequency.value=.05+a*a*6;dep.gain.value=300+(b??.6)*900;}};break;}
    case 'vibrato':{const dl=ctx.createDelay(.05),dep=gainN(.002),l=lfo('sine',5);dl.delayTime.value=.006;l.connect(dep);dep.connect(dl.delayTime);ser(inp,dl,out);set=a=>{l.frequency.value=2+a*8;dep.gain.value=.0005+a*.004;};break;}
    case 'trem':{const g=gainN(1),l=lfo('sine',4),dep=gainN(0);l.connect(dep);dep.connect(g.gain);ser(inp,g,out);set=a=>{l.frequency.value=hz([1,.5,.25,.125][Math.round(a*3)]);dep.gain.value=.45;g.gain.value=.55;};break;}
    case 'autopan':{const p=ctx.createStereoPanner(),l=lfo('sine',1),dep=gainN(.9);l.connect(dep);dep.connect(p.pan);ser(inp,p,out);set=a=>{l.frequency.value=hz([2,1,.5,.25][Math.round(a*3)]);};break;}
    case 'ring':{const g=gainN(0),l=lfo('sine',300);l.connect(g.gain);inp.connect(g);const{w}=dryWet(g,.4);set=a=>{l.frequency.value=30*Math.pow(2,a*6.5);w.gain.value=.9;};break;}
    case 'ringsweep':case 'siren':{const g=gainN(0),m=lfo('sine',300),sw=lfo(kind==='siren'?'triangle':'sine',.25),sd=gainN(1200);sw.connect(sd);sd.connect(m.detune);m.connect(g.gain);inp.connect(g);const{d,w}=dryWet(g,1);
      set=(a,b)=>{if(kind==='siren'){sw.frequency.value=.2+a*4;m.frequency.value=400+a*800;}else{m.frequency.value=80*Math.pow(2,a*5);sw.frequency.value=.1+a*2;}const mx=b??.8;w.gain.value=mx;d.gain.value=1-mx*.8;};break;}
    case 'pump':{const g=gainN(1),l=lfo('sawtooth',2),dep=gainN(0);l.connect(dep);dep.connect(g.gain);ser(inp,g,out);set=(a,b)=>{l.frequency.value=hz([1,.5,.25][Math.round((b??0)*2)]);const dp=a*.48;dep.gain.value=dp;g.gain.value=1-dp;};break;}
    case 'gate':case 'grain':case 'gate16':case 'stutter':{const g=gainN(1),l=lfo('square',4),dep=gainN(0);l.connect(dep);dep.connect(g.gain);ser(inp,g,out);
      set=(a,b)=>{const div=kind==='grain'?.125:kind==='gate'?[.5,.25,.125][Math.round(a*2)]:kind==='gate16'?(b===undefined?.25:[.5,.25,.125][Math.round(a*2)]):[.5,.25,.125,.0625][Math.round(a*3)];
        l.frequency.value=1/syncTime(div);const dp=kind==='gate16'&&b===undefined?.25+a*.25:kind==='grain'||kind==='gate'?.3+a*.2:.5*(b??.8);dep.gain.value=dp;g.gain.value=1-dp;};break;}
    case 'talk':{const sum=gainN(.6);[[650,8],[1100,10]].forEach(([f,q])=>{const b=biqN('bandpass',f,q),dep=gainN(f*.6),l=lfo('triangle',.7);l.connect(dep);dep.connect(b.frequency);inp.connect(b);b.connect(sum);});sum.connect(out);
      set=a=>{stops.forEach(x=>x.frequency.value=.2+a*5);};break;}
    case 'isolator':{const lo=biqN('lowshelf',250),mid=biqN('peaking',1200,.7),hi=biqN('highshelf',4000);ser(inp,lo,mid,hi,out);set=a=>{lo.gain.value=a<.5?-(.5-a)*80:0;hi.gain.value=a>.5?-(a-.5)*80:0;};break;}
    case 'delay':{const dl=ctx.createDelay(2),fb=gainN(.4),lp=biqN('lowpass',o.tape?3500:o.dub?2500:6000),hp=biqN('highpass',o.dub?400:o.hpd?700:80),wet=gainN(.55);if(o.mod){const l=lfo('sine',.35),dp=gainN(.004);l.connect(dp);dp.connect(dl.delayTime);}
      inp.connect(out);inp.connect(dl);dl.connect(lp);lp.connect(hp);
      if(o.dub){const s=ctx.createWaveShaper();s.curve=curve(x=>Math.tanh(1.5*x));hp.connect(s);s.connect(fb);}else hp.connect(fb);fb.connect(dl);hp.connect(wet);wet.connect(out);
      if(o.tape){const l=lfo('sine',.6),dp=gainN(.0015);l.connect(dp);dp.connect(dl.delayTime);}
      set=(a,b)=>{let t;if(o.short)t=o.slap?.06+a*.08:.012+a*a*.15;else if(o.div==='xy')t=syncTime([.125,.25,.375,.5,.75,1][Math.round(a*5)]);else t=syncTime(o.div);
        tg(dl.delayTime,loopDT(t),.04);const f=b??(o.short?(o.slap?.15:.35):a);fb.gain.value=o.one?0:o.slap?.1+f*.3:.15+f*(o.dub?.75:.68);wet.gain.value=o.one?.4+a*.5:o.short?.6:.5;};break;}
    case 'pingpong':{const dL=ctx.createDelay(2),dR=ctx.createDelay(2),fb=gainN(.4),pL=ctx.createStereoPanner(),pR=ctx.createStereoPanner();pL.pan.value=-.9;pR.pan.value=.9;
      const d=gainN(1);inp.connect(d);d.connect(out);inp.connect(dL);dL.connect(pL);pL.connect(out);dL.connect(dR);dR.connect(pR);pR.connect(out);dR.connect(fb);fb.connect(dL);
      set=(a,b=.5)=>{const t=syncTime([.25,.375,.5,.75][Math.round(a*3)]);tg(dL.delayTime,Math.max(.003,t-LOOPC/2),.05);tg(dR.delayTime,Math.max(.003,t-LOOPC/2),.05);fb.gain.value=.2+b*.6;};break;}
    case 'multitap':{const taps=[.25,.5,.75].map((dv,k)=>{const dl=ctx.createDelay(2),g=gainN(.5-k*.12),p=ctx.createStereoPanner();p.pan.value=[-.6,.6,0][k];ser(inp,dl,g,p,out);return{dl,dv};});inp.connect(out);
      set=a=>{taps.forEach(x=>tg(x.dl.delayTime,syncTime(x.dv*(a<.5?1:2)),.04));};break;}
    case 'reverb':{const cv=ctx.createConvolver();cv.buffer=E.ir[o.ir]||E.ir.hall;const pre=biqN('highpass',o.ghost?600:200),tone=biqN('lowpass',8000);ser(inp,pre,cv,tone);const{d,w}=dryWet(tone,1);
      set=(a,b)=>{w.gain.value=a*(o.ir==='gated'?1.2:.9);d.gain.value=o.ghost?1-a*.5:1-a*.3;tone.frequency.value=b===undefined?(o.ir==='plate'?12000:7000):1500*Math.pow(2,b*3.5);};break;}
    case 'comp':case 'transient':{const c=ctx.createDynamicsCompressor(),mk=gainN();ser(inp,c,mk,out);
      set=a=>{c.threshold.value=-8-a*32;c.ratio.value=kind==='comp'?3+a*9:6;c.attack.value=kind==='comp'?.004:.03;c.release.value=.12;mk.gain.value=1+a*(kind==='comp'?1.4:.8);};break;}
    case 'limit':{const c=ctx.createDynamicsCompressor(),mk=gainN(1);c.knee.value=0;c.ratio.value=20;c.attack.value=.001;c.release.value=.06;ser(inp,c,mk,out);set=a=>{c.threshold.value=-a*24;mk.gain.value=Math.pow(10,a*18/20);};break;}
    case 'ott':case 'brett':{const sum=gainN(1),bands=[['lowpass',120],['band'],['highpass',2500]].map(([t,f])=>{let n;if(t==='band'){const h=biqN('highpass',120),l=biqN('lowpass',2500);inp.connect(h);h.connect(l);n=l;}else{const b1=biqN(t,f),b2=biqN(t,f);inp.connect(b1);b1.connect(b2);n=b2;}
        const c=ctx.createDynamicsCompressor();c.threshold.value=-30;c.ratio.value=8;c.knee.value=6;c.attack.value=.003;c.release.value=.08;const mk=gainN(2);n.connect(c);c.connect(mk);mk.connect(sum);return{c,mk};});
      let src=sum,hs=null,sh=null;if(kind==='brett'){hs=biqN('highshelf',5000);sh=ctx.createWaveShaper();sum.connect(hs);hs.connect(sh);src=sh;}
      const{d,w}=dryWet(src,0);let la=-1;set=(a,b)=>{bands.forEach(B=>{B.c.threshold.value=-10-a*35;B.mk.gain.value=1+a*3;});if(kind==='brett'){hs.gain.value=a*6;if(Math.abs(a-la)>.01){la=a;sh.curve=curve(x=>clamp(x*(1+a*2),-1,1));}mixer(w,d,1);}else mixer(w,d,b??a);};break;}
    case 'haas':{const sp=stereoIn(),mg=ctx.createChannelMerger(2),dl=ctx.createDelay(.05);sp.connect(mg,0,0);sp.connect(dl,1);dl.connect(mg,0,1);mg.connect(out);set=a=>{dl.delayTime.value=.001+a*.025;};break;}
    case 'ms':{const sp=stereoIn(),mg=ctx.createChannelMerger(2),mid=gainN(.5),sL=gainN(.5),sR=gainN(-.5),side=gainN(1),sideN=gainN(-1);
      sp.connect(mid,0);sp.connect(mid,1);sp.connect(sL,0);sp.connect(sR,1);sL.connect(side);sR.connect(side);side.connect(sideN);mid.connect(mg,0,0);mid.connect(mg,0,1);side.connect(mg,0,0);sideN.connect(mg,0,1);mg.connect(out);
      set=a=>{side.gain.value=o.mono?1-a:1+a*2.5;};break;}
    case 'scream':{const bp=biqN('bandpass',1200,6),l=lfo('sine',3),dep=gainN(1800),sh=ctx.createWaveShaper();l.connect(dep);dep.connect(bp.detune);sh.oversample='4x';ser(inp,bp,sh);const{d,w}=dryWetD(sh,1,'4x');let la=-1;
      set=(a,b)=>{if(Math.abs(a-la)>.01){la=a;sh.curve=curve(x=>Math.sin(x*(2+a*10)));}l.frequency.value=1+a*7;bp.Q.value=4+a*10;const m=b??.6;w.gain.value=m*1.2;d.gain.value=1-m*.6;};break;}
    case 'laser':{const dl=ctx.createDelay(.1),fb=gainN(.8),l=lfo('sawtooth',4),dep=gainN(.004);dl.delayTime.value=.009;l.connect(dep);dep.connect(dl.delayTime);inp.connect(dl);dl.connect(fb);fb.connect(dl);const{d,w}=dryWet(dl,1);
      set=(a,b)=>{l.frequency.value=hz([1,.5,.25,.125][Math.round(a*3)]);dep.gain.value=.002+a*.004;const m=b??.6;w.gain.value=m;d.gain.value=1-m*.5;};break;}
    case 'kirmes':{const dl=ctx.createDelay(.05),dep=gainN(.003),l=lfo('sine',5.5),g=gainN(1),tl=lfo('sine',7),td=gainN(.25);dl.delayTime.value=.008;l.connect(dep);dep.connect(dl.delayTime);tl.connect(td);td.connect(g.gain);ser(inp,dl,g);const{w}=dryWet(g,.5);
      set=a=>{dep.gain.value=.001+a*.004;l.frequency.value=3+a*5;td.gain.value=a*.35;g.gain.value=1-a*.35;w.gain.value=.8;};break;}
    case 'bassglue':{const ls=biqN('lowshelf',90),sh=ctx.createWaveShaper(),c=ctx.createDynamicsCompressor();c.threshold.value=-18;c.ratio.value=3;c.attack.value=.01;c.release.value=.12;ser(inp,ls,sh,c,out);let la=-1;
      set=a=>{ls.gain.value=a*6;if(Math.abs(a-la)>.01){la=a;sh.curve=curve(x=>Math.tanh(x*(1+a*3)));}};break;}
    case 'neon':{const sh=ctx.createWaveShaper();let n=ser(inp,sh);const aps=[];for(let k=0;k<4;k++){const ap=biqN('allpass',900,.7);n.connect(ap);n=ap;aps.push(ap);}const l=lfo('sine',.5),dep=gainN(700);l.connect(dep);aps.forEach(ap=>dep.connect(ap.frequency));
      const{d,w}=dryWet(n,.3);sh.connect(w);let la=-1;set=a=>{if(Math.abs(a-la)>.01){la=a;sh.curve=curve(x=>Math.sin(x*(1.5+a*6)));}l.frequency.value=.2+a*2;w.gain.value=.7;};break;}
    case 'nacht':{const dl=ctx.createDelay(2),fb=gainN(.6),bp=biqN('bandpass',1200,.8),cv=ctx.createConvolver(),hp=biqN('highpass',300),wv=gainN(.5),wd=gainN(.5);cv.buffer=E.ir.hall;
      inp.connect(out);inp.connect(dl);dl.connect(bp);bp.connect(fb);fb.connect(dl);bp.connect(cv);cv.connect(hp);hp.connect(wv);wv.connect(out);bp.connect(wd);wd.connect(out);
      set=a=>{tg(dl.delayTime,loopDT(syncTime(.75)),.05);fb.gain.value=.3+a*.6;wv.gain.value=a*.8;wd.gain.value=.3+a*.4;};break;}
    case 'cloud':{const sum=gainN(.4),lp=biqN('lowpass',5000);for(let k=0;k<5;k++){const dl=ctx.createDelay(1),l=lfo('sine',.07+k*.05),dep=gainN(.02),fb=gainN(.35),p=ctx.createStereoPanner();p.pan.value=(k/2-1)*.8;dl.delayTime.value=.05+k*.06;
        l.connect(dep);dep.connect(dl.delayTime);inp.connect(dl);dl.connect(fb);fb.connect(dl);dl.connect(p);p.connect(sum);}
      sum.connect(lp);const{d,w}=dryWet(lp,1);set=(a,b)=>{const m=b??a;w.gain.value=m*1.2;d.gain.value=1-m*.4;lp.frequency.value=2000+a*8000;};break;}
    case 'riser':{const n=ctx.createBufferSource();n.buffer=E.noise;n.loop=true;n.start();stops.push(n);const bp=biqN('bandpass',800,4),g=gainN(0);n.connect(bp);bp.connect(g);g.connect(out);inp.connect(out);
      set=(a,b=.5)=>{bp.frequency.setTargetAtTime(200*Math.pow(2,a*5.5),T(),.05);g.gain.setTargetAtTime(b*.45,T(),.05);};break;}
    case 'looper':{const Lp=new Looper();inp.connect(Lp.inp);Lp.out.connect(out);const lens=[1,.5,.25,.125,.0625];let li=-1;
      set=(a,b=.8)=>{const k=Math.round(a*4),len=syncTime(lens[k]);if(!Lp.on){Lp.engage(T()+.004,len,0,0,.5+b*.5);li=k;}else{if(k!==li){Lp.length(len,T());li=k;}Lp.mix(.5+b*.5,T());}};extra.off=()=>Lp.release(T());break;}
    /* DISTORTION: Vorfilter (kein Matsch), Mitten-Anhebung, starke 4x-Sättigung, DC-Filter, Lautsprecher-Tiefpass, Pegelausgleich */
    case 'dist':{const md=o.mode,hp=biqN('highpass',md==='tekk'?28:md==='fuzz'?90:70,.7),mid=biqN('peaking',md==='heavy'?650:1100,.8),pre=gainN(1),sh=ctx.createWaveShaper(),dc=biqN('highpass',22,.6),
        lp=biqN('lowpass',7000,.8),cab=biqN('peaking',md==='heavy'?2400:2800,1.2),post=gainN(.5);sh.oversample='4x';
      const C={classic:x=>x>0?Math.tanh(x):Math.tanh(x*.85)/.85*.97,crunch:x=>Math.tanh(x)*.7+.3*clamp(x,-1,1),heavy:x=>Math.sign(x)*(1-Math.exp(-Math.abs(x)*2.2)),
        tekk:x=>clamp((Math.tanh(1.6*x+.22)-Math.tanh(.22))*1.15,-.97,.97),fuzz:x=>{const y=Math.tanh(x*2.5);return y*Math.abs(y)*.55+y*.45;}}[md]||Math.tanh;sh.curve=curve(C,8192);
      ser(inp,hp,mid,pre,sh,dc,lp,cab,post);const{d,w}=dryWetD(post,0,'4x');
      /* HARDTEKK: Sub unter 110 Hz bleibt sauber und tight, verzerrt wird nur der Rest */
      if(md==='tekk'){const sl=biqN('lowpass',110,.7),sd=shDelay('4x'),sg=gainN(.9);inp.connect(sl);sl.connect(sd);sd.connect(sg);sg.connect(w);}
      mid.gain.value=md==='heavy'?-5:md==='fuzz'?2:5;cab.gain.value=md==='heavy'?4:3;
      set=(a,b)=>{const dr=1+a*a*(md==='heavy'||o.amp?90:md==='crunch'?18:45);tg(pre.gain,dr);tg(post.gain,.75/Math.pow(dr,.42));tg(lp.frequency,(o.amp?5200:8500)-a*3200);mixer(w,d,b??1);};break;}
    case 'eqband':{const f=biqN(o.t,o.f,.8);ser(inp,f,out);set=a=>{tg(f.gain,(a-.5)*30);};break;}
    case 'bandplus':{const b=biqN('bandpass',1000,2),g=gainN(0);inp.connect(out);inp.connect(b);b.connect(g);g.connect(out);set=a=>{tg(b.frequency,80*Math.pow(2,a*7));g.gain.value=1.6;};break;}
    case 'ringdelay':{const dl=ctx.createDelay(2),fb=gainN(.5),rg=gainN(0),m=lfo('sine',600),wet=gainN(.6);m.connect(rg.gain);inp.connect(out);inp.connect(dl);dl.connect(rg);rg.connect(fb);fb.connect(dl);rg.connect(wet);wet.connect(out);
      set=(a,b)=>{tg(dl.delayTime,loopDT(syncTime(.375)));m.frequency.value=o.sweep?100+a*2400:600;fb.gain.value=.3+(b??a)*.55;};break;}
    case 'flangerman':{const dl=ctx.createDelay(.05),fb=gainN(o.neg?-.75:.75);inp.connect(dl);dl.connect(fb);fb.connect(dl);dryWet(dl,1);set=a=>{tg(dl.delayTime,.0005+a*a*.012,.03);};break;}
    case 'jag':{const f=biqN('lowpass',800,6),src=ctx.createBufferSource(),dep=gainN(2400);src.buffer=E.lfoBuf['S&H'];src.loop=true;src.start();stops.push(src);src.connect(dep);dep.connect(f.detune);ser(inp,f,out);
      set=(a,b)=>{src.playbackRate.value=syncTime(1)>0?(1/syncTime([1,.5,.25,.125][Math.round(a*3)]))/16:1;dep.gain.value=600+(b??.6)*3000;};break;}
    case 'tubeeq':{const lo=biqN('lowshelf',100),hi=biqN('highshelf',8000),sh=ctx.createWaveShaper();sh.curve=curve(x=>Math.tanh(x*1.4+.1)-Math.tanh(.1));sh.oversample='2x';const dc=biqN('highpass',20,.6);ser(inp,lo,hi,sh,dc);const{d,w}=dryWetD(dc,0,'2x');
      set=(a,b)=>{tg(lo.gain,a*12);tg(hi.gain,(b??.5)*12);};break;}
    case 'pitchloop':{const Lp=new Looper();inp.connect(Lp.inp);Lp.out.connect(out);const lens=[1,.5,.25,.125];let li=-1;
      set=(a,b=.5)=>{const k=Math.round(a*3),len=syncTime(lens[k]);if(!Lp.on||k!==li){Lp.engage(T()+.004,len,len*Math.pow(2,-(b-.5)*2),syncTime(1),1);li=k;}};extra.off=()=>Lp.release(T());break;}
    default:inp.connect(out);
  }
  return{inp,out,set,stop(){stops.forEach(s=>{try{s.stop();}catch(e){}});},...extra};
}
class FXSlot{
  constructor(){this.inp=gainN();this.out=gainN();this.dry=gainN();this.inp.connect(this.dry);this.dry.connect(this.out);this.fx=null;this.type=-1;}
  set(cfg){
    if(cfg&&cfg.on){
      if(!this.fx||this.type!==cfg.type){this.kill();this.fx=makeFX(IFX_KIND[cfg.type],FXLIB[cfg.type][2]);this.type=cfg.type;this.inp.connect(this.fx.inp);this.fx.out.connect(this.out);}
      this.fx.set(cfg.edit);this.dry.gain.setTargetAtTime(0,now(),.01);
    }else{this.dry.gain.setTargetAtTime(1,now(),.01);if(this.fx){const f=this.fx;this.fx=null;this.type=-1;setTimeout(()=>{try{this.inp.disconnect(f.inp);}catch(e){}try{f.out.disconnect();}catch(e){}f.stop();},60);}}
  }
  kill(){if(this.fx){try{this.inp.disconnect(this.fx.inp);}catch(e){}try{this.fx.out.disconnect();}catch(e){}this.fx.stop();this.fx=null;this.type=-1;}}
}
class MFXSlot{
  constructor(i){this.i=i;this.inp=gainN();this.out=gainN();this.dry=gainN();this.inp.connect(this.dry);this.dry.connect(this.out);this.fx=null;this.gate=null;this.kind=null;}
  update(){
    const m=ui.mfx[this.i],kind=MFX_KIND[m.type],active=m.on&&!!m.touch&&(this.i===0||ui.dock);
    if(m.type!==this.type){this.drop();this.type=m.type;}
    if(active&&!this.fx&&!SEQ_MFX.has(kind)){this.fx=makeFX(kind,MFXL[m.type][2]);this.gate=gainN(0);this.inp.connect(this.gate);this.gate.connect(this.fx.inp);this.fx.out.connect(this.out);}
    if(this.fx){if(m.touch)this.fx.set(m.touch[0],1-m.touch[1]);this.gate.gain.setTargetAtTime(active?1:0,now(),.008);if(!active&&this.fx.off){this.fx.off();}}
    if(!active&&this.fx&&this.fx.off){this.drop();}
    this.dry.gain.setTargetAtTime(active&&this.fx?0:1,now(),.008);
  }
  drop(){if(this.fx){const f=this.fx,g=this.gate;this.fx=null;setTimeout(()=>{try{this.inp.disconnect(g);}catch(e){}try{f.out.disconnect();}catch(e){}f.stop();},80);}}
}
/* LFO-Puffer für S&H (Stufen) und RANDOM (weich): 16 Zufallswerte pro Durchlauf */
function mkLfoBuf(smooth){const R=ctx.sampleRate,b=ctx.createBuffer(1,R,R),d=b.getChannelData(0),v=Array.from({length:17},(_,k)=>k===16?0:Math.random()*2-1);v[16]=v[0];
  for(let k=0;k<R;k++){const p=k/R*16,i=Math.floor(p),f=p-i;d[k]=smooth?v[i]+(v[i+1]-v[i])*(.5-.5*Math.cos(Math.PI*f)):v[i];}return b;}
function setLfoWave(c,w,rate,t,sign=1,force){const osc={SINE:'sine',TRI:'triangle','SAW UP':'sawtooth',SQUARE:'square'}[w];
  if(!c.lfoSrc||c.lfoW!==w||force){const old=c.lfoSrc;if(old){try{old.stop(t);}catch(e){}setTimeout(()=>{try{old.disconnect();}catch(e){}},Math.max(50,(t-now())*1000+60));}
    if(osc){c.lfoSrc=ctx.createOscillator();c.lfoSrc.type=osc;c.lfoSrc.frequency.value=rate;}else{c.lfoSrc=ctx.createBufferSource();c.lfoSrc.buffer=E.lfoBuf[w];c.lfoSrc.loop=true;c.lfoSrc.playbackRate.value=rate/16;}
    c.lfoSrc.connect(c.lfoG);c.lfoSrc.start(Math.max(t,now()));c.lfoW=w;c.lfoT0=Math.max(t,now());}
  c.lfoG.gain.setTargetAtTime(sign,t,.005);if(osc)c.lfoSrc.frequency.setTargetAtTime(rate,t,.05);else c.lfoSrc.playbackRate.setTargetAtTime(rate/16,t,.05);}
const LFOW={tri:'TRI',saw:'SAW UP',squ:'SQUARE',sh:'S&H',rnd:'RANDOM'};
function buildEngine(){
  E={voices:[],lastNote:new Array(PARTS.length).fill(null),partHit:new Array(PARTS.length).fill(-1),gRate:new Array(PARTS.length).fill(1),vid:1};
  E.ir={room:irGen(.6,t=>Math.pow(1-t,3)),hall:irGen(3,t=>Math.pow(1-t,2.2),.35),plate:irGen(1.8,t=>Math.pow(1-t,2.5)),spring:irGen(1.5,(t,s)=>Math.pow(1-t,2.6)*(1+.7*Math.sin(TAU*28*s))),
    gated:irGen(.32,t=>t<.85?1:(1-t)/.15),reverse:irGen(.9,t=>t*t*(t<.97?1:(1-t)/.03)),wash:irGen(5,t=>Math.pow(1-t,1.6),.25)};
  const R=ctx.sampleRate,mkBuf=fn=>{const b=ctx.createBuffer(1,R*2,R),d=b.getChannelData(0);fn(d);return b;};
  E.noise=mkBuf(d=>{for(let k=0;k<d.length;k++)d[k]=Math.random()*2-1;});
  E.pink=mkBuf(d=>{let b0=0,b1=0,b2=0;for(let k=0;k<d.length;k++){const w=Math.random()*2-1;b0=.99765*b0+w*.099;b1=.963*b1+w*.2965;b2=.57*b2+w*1.0526;d[k]=(b0+b1+b2+w*.1848)*.2;}});
  E.crackle=mkBuf(d=>{for(let k=0;k<d.length;k++)if(Math.random()<.0007){const a=(Math.random()*2-1)*.9;for(let j=0;j<40&&k+j<d.length;j++)d[k+j]+=a*Math.exp(-j/6);}});
  E.dry=gainN();E.fx=gainN();E.mix=gainN();E.limiter=ctx.createDynamicsCompressor();E.master=gainN();E.phones=gainN();E.tubeTap=gainN();
  E.anOut=ctx.createAnalyser();E.anOut.fftSize=2048;E.anTube=ctx.createAnalyser();E.anTube.fftSize=1024;
  E.mfx=[new MFXSlot(0),new MFXSlot(1)];E.loopF=new Looper();E.loopD=new Looper();E.fxR=gainN();E.dryR=gainN();
  /* ROLL SEND pro Part: Parts mit Roll-Send laufen durch den Looper (vor dem MFX), die anderen nicht */
  E.loop={get on(){return E.loopF.on;},byMotion:false,engage:(...a)=>{E.loopF.engage(...a);E.loopD.engage(...a);},length:(...a)=>{E.loopF.length(...a);E.loopD.length(...a);},
    mix:(...a)=>{E.loopF.mix(...a);E.loopD.mix(...a);},release:t=>{E.loopF.release(t);E.loopD.release(t);}};
  E.fxR.connect(E.loopF.inp);E.loopF.out.connect(E.fx);E.dryR.connect(E.loopD.inp);E.loopD.out.connect(E.dry);
  E.fx.connect(E.mfx[0].inp);E.mfx[0].out.connect(E.mfx[1].inp);E.mfx[1].out.connect(E.mix);E.dry.connect(E.mix);
  E.glue={inp:gainN(),hp:biqN('highpass',28),pre:gainN(),sh:ctx.createWaveShaper(),dc:biqN('highpass',24,.6),mud:biqN('peaking',260,1.1),bite:biqN('peaking',2200,.8),lp:biqN('lowpass',9000),comp:ctx.createDynamicsCompressor(),post:gainN()};
  E.glue.mud.gain.value=-3;E.glue.bite.gain.value=3;E.glue.mIn=ctx.createAnalyser();E.glue.mOut=ctx.createAnalyser();E.glue.mIn.fftSize=E.glue.mOut.fftSize=2048;E.glue.auto=1;E.glue.sh.curve=curve(x=>Math.tanh(1.7*x+.15)-Math.tanh(.15));E.glue.sh.oversample='2x';
  {const k=E.glue.comp;k.threshold.value=-16;k.knee.value=6;k.ratio.value=4;k.attack.value=.006;k.release.value=.12;}
  E.glue.inp.connect(E.glue.hp);E.glue.hp.connect(E.glue.pre);E.glue.pre.connect(E.glue.sh);E.glue.sh.connect(E.glue.dc);E.glue.dc.connect(E.glue.mud);E.glue.mud.connect(E.glue.bite);E.glue.bite.connect(E.glue.lp);E.glue.lp.connect(E.glue.comp);E.glue.comp.connect(E.glue.post);E.glue.inp.connect(E.glue.mIn);E.glue.comp.connect(E.glue.mOut);E.glue.post.connect(E.fxR);
  E.patLvl=gainN(1);E.col={pre:gainN(1),sh:ctx.createWaveShaper(),dc:biqN('highpass',16,.6),lo:biqN('lowshelf',90),mid:biqN('peaking',1600,.7),hi:biqN('highshelf',11000),post:gainN(1),dry:gainN(0),wet:gainN(1),dly:shDelay('2x')};
  {const C=E.col;C.sh.oversample='2x';E.mix.connect(E.patLvl);E.patLvl.connect(C.pre);C.pre.connect(C.sh);C.sh.connect(C.dc);C.dc.connect(C.lo);C.lo.connect(C.mid);C.mid.connect(C.hi);C.hi.connect(C.post);C.post.connect(C.wet);C.wet.connect(E.limiter);
    E.patLvl.connect(C.dly);C.dly.connect(C.dry);C.dry.connect(E.limiter);}E.limiter.connect(E.master);E.master.connect(E.phones);E.phones.connect(ctx.destination);E.master.connect(E.anOut);E.tubeTap.connect(E.anTube);
  E.tubeCurve=curve(x=>Math.tanh(x+.15)-Math.tanh(.15));E.glueCurve=curve(x=>Math.tanh(x));E.tubeCurve2=curve(x=>Math.tanh(x+.08)-Math.tanh(.08));
  E.ch=PARTS.map((_,i)=>{const c={inp:gainN(),slots:[],eqL:biqN('lowshelf',100),eqM:biqN('peaking',1000,1),eqH:biqN('highshelf',7000),hp:biqN('highpass',10),lp:biqN('lowpass',22000,.707),trem:gainN(),lvl:gainN(),sc:gainN(),
      tpre:gainN(),tsh:ctx.createWaveShaper(),tpost:gainN(),tpre2:gainN(),tsh2:ctx.createWaveShaper(),tpost2:gainN(),tdc:biqN('highpass',18,.6),ttone:biqN('lowpass',9500),twet:gainN(0),tdry:gainN(1),tdly:tubeDelay(),eqDly:ctx.createDelay(.05),pan:ctx.createStereoPanner(),toFx:gainN(1),toDry:gainN(0),toFxR:gainN(0),toDryR:gainN(0),glue:gainN(0),gpre:gainN(1),gsh:ctx.createWaveShaper(),gpost:gainN(1),fxEnd:gainN(),
      eqDry:gainN(0),eqSh:ctx.createWaveShaper(),eqPost:gainN(1),eqWet:gainN(1),eqSum:gainN(1),eqDl:-1};
    c.tsh.curve=E.tubeCurve;c.tsh.oversample='2x';c.tsh2.curve=E.tubeCurve2;c.tsh2.oversample='2x';c.eqSh.oversample='2x';
    c.inp.connect(c.fxEnd);c.fxEnd.connect(c.eqDly);c.eqDly.connect(c.eqDry);c.eqDry.connect(c.eqSum);c.fxEnd.connect(c.eqL);c.eqL.connect(c.eqM);c.eqM.connect(c.eqH);c.eqH.connect(c.eqSh);c.eqSh.connect(c.eqPost);c.eqPost.connect(c.eqWet);c.eqWet.connect(c.eqSum);c.eqSum.connect(c.hp);c.hp.connect(c.lp);c.lp.connect(c.trem);c.trem.connect(c.lvl);c.lvl.connect(c.sc);
    c.sc.connect(c.tdly);c.tdly.connect(c.tdry);c.sc.connect(c.tpre);c.tpre.connect(c.tsh);c.tsh.connect(c.tpost);c.tpost.connect(c.tpre2);c.tpre2.connect(c.tsh2);c.tsh2.connect(c.tpost2);c.tpost2.connect(c.tdc);c.tdc.connect(c.ttone);c.ttone.connect(c.twet);c.twet.connect(E.tubeTap);
    c.tdry.connect(c.pan);c.twet.connect(c.pan);c.pan.connect(c.toFx);c.pan.connect(c.toDry);c.pan.connect(c.toFxR);c.pan.connect(c.toDryR);c.pan.connect(c.glue);c.toFx.connect(E.fx);c.toDry.connect(E.dry);c.toFxR.connect(E.fxR);c.toDryR.connect(E.dryR);
    c.gsh.curve=E.glueCurve;c.gsh.oversample='2x';c.glue.connect(c.gpre);c.gpre.connect(c.gsh);c.gsh.connect(c.gpost);c.gpost.connect(E.glue.inp);
    c.lfoG=gainN(1);c.lfoF=gainN(0);c.lfoT=gainN(0);c.lfoP=gainN(0);c.lfoPi=gainN(0);c.lfoO=gainN(0);c.lfoW=null;[c.lfoF,c.lfoT,c.lfoP,c.lfoPi,c.lfoO].forEach(g=>c.lfoG.connect(g));c.lfoT.connect(c.trem.gain);c.lfoP.connect(c.pan.pan);
    /* DRUCK-Pegelausgleich: misst den Part ohne und mit DRUCK, die Lautstärke bleibt gleich */
    c.dkRef=ctx.createAnalyser();c.dkOut=ctx.createAnalyser();c.dkRef.fftSize=c.dkOut.fftSize=2048;c.dkC=ctx.createConstantSource();c.dkC.offset.value=.45;c.dkC.start();c.dkAuto=.45;return c;});
  E.lfoBuf={'S&H':mkLfoBuf(false),'RANDOM':mkLfoBuf(true)};
  applyGlobals();PARTS.forEach((_,i)=>applyChannel(i));
}
/* IFX-Kette pro Part: beliebig viele Slots, nur aktive kosten Rechenzeit */
function syncSlots(i){
  const P=cur.parts[i],c=E.ch[i],need=P.fx.length;
  if(c.slots.length!==need){
    try{c.inp.disconnect();}catch(e){}c.slots.forEach(s=>{try{s.out.disconnect();}catch(e){}});
    while(c.slots.length<need)c.slots.push(new FXSlot());while(c.slots.length>need){c.slots.pop().kill();}
    let n=c.inp;c.slots.forEach(s=>{n.connect(s.inp);n=s.out;});n.connect(c.fxEnd);
  }
  c.slots.forEach((s,k)=>s.set(P.fx[k]));
}
/* Röhre pro Pad: DRIVE A = 1. Triode, DRIVE B = 2. Triode, TUBE MIX = Anteil (trocken + Röhre parallel, gleich verzögert) */
function applyTube(i,t=now()){const c=E.ch[i],P=cur.parts[i],m=G.tubeOn&&P.tube?P.tubeMix*G.warm:0,a=1+P.driveA*10,b=1+P.driveB*6;
  c.tpre.gain.setTargetAtTime(a,t,.02);c.tpost.gain.setTargetAtTime(.9/Math.sqrt(a),t,.02);c.tpre2.gain.setTargetAtTime(b,t,.02);c.tpost2.gain.setTargetAtTime(1/Math.sqrt(b),t,.02);
  c.twet.gain.setTargetAtTime(m,t,.05);c.tdry.gain.setTargetAtTime(1-m*.8,t,.05);}
/* BASS GLUE Pegelausgleich: misst Lautheit vor und nach der Verzerrung und gleicht an. GLUE ändert den Charakter, nicht die Lautstärke */
const glueBuf=new Float32Array(2048);
/* DRUCK ändert den Druck, nicht die Lautstärke: Pegel vor und nach DRUCK vergleichen und angleichen */
function druckAutoGain(){if(!E)return;const rms=an=>{an.getFloatTimeDomainData(glueBuf);let s=0;for(const v of glueBuf)s+=v*v;return Math.sqrt(s/glueBuf.length);};
  E.ch.forEach((c,i)=>{if(!(cur.parts[i].druck>.01))return;const a=rms(c.dkRef),b=rms(c.dkOut);if(a<.003||b<1e-4)return;const want=clamp(a/b,.05,2);c.dkAuto+=(want-c.dkAuto)*.3;c.dkC.offset.setTargetAtTime(c.dkAuto,now(),.03);});}
function glueAutoGain(){const g=E&&E.glue;if(!g)return;const rms=an=>{an.getFloatTimeDomainData(glueBuf);let s=0;for(const v of glueBuf)s+=v*v;return Math.sqrt(s/glueBuf.length);};
  const a=rms(g.mIn),b=rms(g.mOut);if(a<.004||b<1e-4)return;const want=clamp(a/b*1.05,.08,6);g.auto+=(want-g.auto)*.15;g.post.gain.setTargetAtTime(g.auto,now(),.08);}
/* TX CHARACTER: eigene Klangfarbe der TX-16 auf der Summe (OFF, TUBE, TAPE, HARDTEKK) – damit sie nicht nach Electribe klingt */
const COLORS=['OFF','TUBE','TAPE','HARDTEKK'];
function applyColor(t=now()){const C=E.col,k=G.color;if(!C)return;C.wet.gain.setTargetAtTime(k?1:0,t,.03);C.dry.gain.setTargetAtTime(k?0:1,t,.03);if(!k)return;
  const cv=curve([null,x=>Math.tanh(x*1.15+.07)-Math.tanh(.07),x=>x/(1+Math.abs(x)*.6),x=>Math.tanh(x*1.8)*.82+.18*clamp(x,-1,1)][k]),n=cv.length;C.sh.curve=cv;
  /* Pegel ausgleichen beim typischen Summenpegel (ca. -9 dBFS): Färbung ändert den Klang, nicht die Lautstärke */
  const pre=[1,1.35,1.6,2.1][k],at=x=>{const p=(clamp(x,-1,1)+1)/2*(n-1),i=Math.floor(p),f=p-i;return cv[i]*(1-f)+(cv[Math.min(n-1,i+1)]||0)*f;},ref=.35,g=(at(pre*ref)-at(-pre*ref))/(2*ref);
  C.pre.gain.setTargetAtTime(pre,t,.03);C.post.gain.setTargetAtTime([1,.86,.77,.65][k]/g,t,.03);
  C.lo.gain.setTargetAtTime([0,1.5,2.5,3][k],t,.03);C.mid.gain.setTargetAtTime([0,.5,-1,2.5][k],t,.03);C.hi.gain.setTargetAtTime([0,-1,-3,1][k],t,.03);}
function applyGlobals(){
  if(!E)return;const t=now(),L=E.limiter;
  if(G.limiter){L.threshold.value=-1;L.knee.value=0;L.ratio.value=20;L.attack.value=.001;L.release.value=.16;}else{L.threshold.value=0;L.ratio.value=1;}
  E.master.gain.setTargetAtTime(G.master*G.master*1.15,t,.02);E.phones.gain.setTargetAtTime(.4+G.phones*.6,t,.02);
  E.ch.forEach((c,i)=>applyTube(i,t));
  const gv=cur.glue??G.glueDrive,gd=1+gv*12;E.glue.pre.gain.setTargetAtTime(gd,t,.02);E.glue.post.gain.setTargetAtTime(E.glue.auto,t,.02);E.glue.bite.gain.setTargetAtTime(1+gv*4,t,.02);E.glue.lp.frequency.setTargetAtTime(11000-gv*4000,t,.02);
  applyColor(t);if(E.in)applyInput();
}
/* Gain-Staging: Parts summieren sich mit Reserve, der Limiter fängt nur seltene Spitzen (sonst pumpt der Bass) */
const MIXG=.38;
/* PARAMETRIC EQ: LOW CUT 30-730 Hz, HIGH CUT 0,5-18 kHz (ganz rechts = aus), Bänder mit Frequenz + Bandbreite (Q). LOW/HIGH: BW ganz links = Shelf */
const lcHz=v=>v<.01?10:30*Math.pow(2,(v-.01)/.99*4.6);
const hcHz=v=>v>=.999?22000:500*Math.pow(2,v*5.2);
const eqLHz=v=>30*Math.pow(2,v*4),eqHHz=v=>1500*Math.pow(2,v*3.75),eqQ=v=>.3*Math.pow(2,v*5);
const eqDb=v=>Math.round((v-.5)*30);
const eqFHz=v=>150*Math.pow(2,v*6);
const SYNCDIV=[['8 BARS',32],['4 BARS',16],['2 BARS',8],['1 BAR',4],['1/2',2],['1/4',1],['1/8',.5],['1/8 TRI',1/3],['1/16',.25],['1/16 TRI',1/6],['1/32',.125],['1/64',.0625]];
const syncIdx=P=>Math.round(clamp(P.speed)*(SYNCDIV.length-1));
function lfoRate(P){const M=modInfo(P.mtype);return M&&M.bpm?G.bpm/60/SYNCDIV[syncIdx(P)][1]:.05*Math.pow(2,P.speed*9);}
/* EG-Zeit: frei = SPEED, BPM-Typen = Notenwert */
/* EG-Zeit der Modulation: eigener Regler EG TIME (Plan). BPM-Typen = Notenwert aus EG TIME */
function modEgT(P){const M=modInfo(P.mtype),v=P.mEgT??P.speed;return M&&M.bpm?60/G.bpm*SYNCDIV[Math.round(clamp(v)*(SYNCDIV.length-1))][1]/3:.008+Math.pow(1-v,2)*1.6;}
function fxRouted(p){if(ui.rec)return p===ui.part;return cur.parts[p].send;}
function rollRouted(p){if(ui.rec)return p===ui.part;return cur.parts[p].rollSend!==false;}
function applyRouting(){if(!E)return;const t=now();E.ch.forEach((c,p)=>{const P=cur.parts[p],r=fxRouted(p)||!!motionFx[p],ro=rollRouted(p),gl=P.glueOn?1:0,dir=1-gl,set=(g,v)=>g.gain.setTargetAtTime(v,t,.006);
  set(c.toFx,r&&!ro?dir:0);set(c.toDry,!r&&!ro?dir:0);set(c.toFxR,r&&ro?dir:0);set(c.toDryR,!r&&ro?dir:0);set(c.glue,gl);
  /* GLUE DRIVE pro Part: wie hart der Part in die gemeinsame Verzerrung fährt */
  const gd=1+(P.glueDrv??.5)*8;c.gpre.gain.setTargetAtTime(gd,t,.02);c.gpost.gain.setTargetAtTime(1/Math.pow(gd,.55),t,.02);});}
const motionFx=new Array(PARTS.length).fill(null);
function applyChannel(i){
  if(!E)return;const P=cur.parts[i],c=E.ch[i],t=now(),mt=MODS[P.mtype];
  c.lvl.gain.setTargetAtTime(2*P.lvl*P.lvl*MIXG,t,.02);c.pan.pan.setTargetAtTime((P.pan-.5)*2,t,.02);
  /* PARAMETRIC EQ: LOW/MID/HIGH mit Frequenz + Bandbreite, LOW CUT + HIGH CUT */
  const lq=P.eqLQ??0,hq=P.eqHQ??0,lt=lq<.02?'lowshelf':'peaking',ht=hq<.02?'highshelf':'peaking';if(c.eqL.type!==lt)c.eqL.type=lt;if(c.eqH.type!==ht)c.eqH.type=ht;
  c.eqL.frequency.setTargetAtTime(eqLHz(P.eqLF??.434),t,.02);c.eqL.Q.setTargetAtTime(eqQ(lq),t,.02);c.eqL.gain.setTargetAtTime(eqDb(P.eqL),t,.02);
  c.eqM.frequency.setTargetAtTime(eqFHz(P.eqF),t,.02);c.eqM.Q.setTargetAtTime(eqQ(P.eqMQ??.347),t,.02);c.eqM.gain.setTargetAtTime(eqDb(P.eqM),t,.02);
  c.eqH.frequency.setTargetAtTime(eqHHz(P.eqHF??.593),t,.02);c.eqH.Q.setTargetAtTime(eqQ(hq),t,.02);c.eqH.gain.setTargetAtTime(eqDb(P.eqH),t,.02);
  c.hp.frequency.setTargetAtTime(lcHz(P.lc),t,.02);c.lp.frequency.setTargetAtTime(hcHz(P.hc??1),t,.02);
  c.eqWet.gain.setTargetAtTime(P.eqX,t,.02);c.eqDry.gain.setTargetAtTime(1-P.eqX,t,.02);
  if(c.eqDl!==P.eqD){c.eqDl=P.eqD;c.eqDly.delayTime.value=P.eqD<.01?0:SHL['2x']/ctx.sampleRate;c.eqSh.curve=P.eqD<.01?null:curve(x=>Math.tanh(x*(1+P.eqD*14)));c.eqPost.gain.value=P.eqD<.01?1:.85;}
  /* Modulation: LFO-Typen laufen pro Part (Key-Sync startet sie bei jedem Ton neu), EG-Typen wirken pro Ton in voice() */
  const M=modInfo(P.mtype),dp=P.depth,lfo=M&&!M.eg,on=k=>lfo&&M.dst===k;if(lfo)setLfoWave(c,LFOW[M.src],lfoRate(P),t,M.sign);
  c.lfoPi.gain.setTargetAtTime(on('PITCH')?dp*dp*1200:0,t,.02);c.lfoF.gain.setTargetAtTime(on('FILTER')?dp*4800:0,t,.02);c.lfoO.gain.setTargetAtTime(on('OSC')?dp*18:0,t,.02);
  c.lfoT.gain.setTargetAtTime(on('LEVEL')?dp*.5:0,t,.02);c.trem.gain.setTargetAtTime(on('LEVEL')?1-dp*.5:1,t,.02);c.lfoP.gain.setTargetAtTime(on('PAN')?dp:0,t,.02);
  E.patLvl.gain.setTargetAtTime(Math.pow(cur.level/100,1.5),t,.03);
  syncSlots(i);applyRouting();
}

/* ---------- Audio-In mit Limiter (kann nicht übersteuern) ---------- */
async function inputOn(){
  if(!ctx)await powerOn();if(E.in)return true;
  try{const st=await navigator.mediaDevices.getUserMedia({audio:{echoCancellation:false,noiseSuppression:false,autoGainControl:false}});
    const I={st,src:ctx.createMediaStreamSource(st),gain:gainN(1),lim:ctx.createDynamicsCompressor(),clip:ctx.createWaveShaper(),out:gainN(1),an:ctx.createAnalyser(),pre:ctx.createAnalyser(),mon:gainN(0)};
    I.clip.curve=curve(x=>Math.tanh(1.3*x));I.clip.oversample='4x';I.an.fftSize=1024;I.pre.fftSize=1024;
    I.src.connect(I.pre);I.src.connect(I.gain);I.gain.connect(I.lim);I.lim.connect(I.clip);I.clip.connect(I.out);I.out.connect(I.an);I.out.connect(I.mon);I.mon.connect(E.mix);
    E.in=I;applyInput();return true;}catch(e){return false;}
}
function applyInput(){const I=E.in;if(!I)return;const t=now(),L=I.lim;L.threshold.value=-9;L.knee.value=3;L.ratio.value=20;L.attack.value=.001;L.release.value=.08;
  I.gain.gain.setTargetAtTime(Math.pow(10,(-18+G.inGain*36)/20),t,.03);I.mon.gain.setTargetAtTime(G.inMon?.8:0,t,.03);}

/* ---------- Sample-Bibliothek (wird beim Einschalten erzeugt) ---------- */
function norm(b,peak=.89){let mx=1e-9;for(let c=0;c<b.numberOfChannels;c++){const d=b.getChannelData(c);for(let k=0;k<d.length;k++)mx=Math.max(mx,Math.abs(d[k]));}const g=peak/mx;for(let c=0;c<b.numberOfChannels;c++){const d=b.getChannelData(c);for(let k=0;k<d.length;k++)d[k]*=g;}return b;}
async function renderLibrary(){
  const R=ctx.sampleRate;
  const off=(sec,ch,fn)=>{const oc=new OfflineAudioContext(ch,Math.ceil(sec*R),R);fn(oc,oc.destination);return oc.startRendering().then(b=>norm(b));};
  const nb=(oc,sec)=>{const b=oc.createBuffer(1,Math.ceil(sec*R),R),d=b.getChannelData(0);for(let k=0;k<d.length;k++)d[k]=Math.random()*2-1;return b;};
  const ns=(oc,sec,t=0)=>{const s=oc.createBufferSource();s.buffer=nb(oc,sec);s.start(t);return s;};
  const sh=(oc,amt,asym=0)=>{const w=oc.createWaveShaper();w.curve=curve(x=>Math.tanh(amt*x+asym)-Math.tanh(asym),2048);w.oversample='4x';return w;};
  const bq=(oc,type,f,q=.7)=>{const b=oc.createBiquadFilter();b.type=type;b.frequency.value=f;b.Q.value=q;return b;};
  const os=(oc,type,f,t=0,stop)=>{const o=oc.createOscillator();o.type=type;o.frequency.setValueAtTime(f,t);o.start(t);if(stop)o.stop(stop);return o;};
  const ge=(oc,t,a,peak,dec)=>{const g=oc.createGain();g.gain.setValueAtTime(0,t);g.gain.linearRampToValueAtTime(peak,t+a);g.gain.setTargetAtTime(0,t+a,dec);return g;};
  const chain=(...n)=>{for(let k=0;k<n.length-1;k++)n[k].connect(n[k+1]);return n[n.length-1];};
  const kick=(len,f0,f1,pd,drive,click,pf,pa,pdc)=>off(len,1,(oc,d)=>{const o=os(oc,'sine',f0,0,len);o.frequency.exponentialRampToValueAtTime(f1,pd);const g=oc.createGain();g.gain.setValueAtTime(1,0);g.gain.setValueAtTime(1,len*.4);g.gain.linearRampToValueAtTime(0,len);
    chain(o,g,sh(oc,drive,.12),bq(oc,'lowpass',7500),d);chain(ns(oc,.02),bq(oc,'highpass',1800),ge(oc,0,.0005,click,.004),d);
    if(pf){const p=os(oc,'sine',pf,0,len);p.frequency.exponentialRampToValueAtTime(pf*.78,pdc*3);chain(p,ge(oc,0,.002,pa,pdc),d);}});
  const mf=n=>440*Math.pow(2,(n-69)/12);
  const revB=b=>{for(let c=0;c<b.numberOfChannels;c++)b.getChannelData(c).reverse();return b;};
  const metal=(oc,base,g)=>[205.3,304.4,369.6,522.7,540,800].forEach(f=>os(oc,'square',f*base).connect(g));
  const synthNote=(oc,d,t,f,dur,types,detune,cut,pan=0,vol=.3)=>{const g=oc.createGain();g.gain.setValueAtTime(0,t);g.gain.linearRampToValueAtTime(vol,t+.004);g.gain.setTargetAtTime(0,t+.01,dur);const lp=bq(oc,'lowpass',cut*2.2,2);lp.frequency.setValueAtTime(cut*2.2,t);lp.frequency.setTargetAtTime(cut*.6,t,dur);
    const p=oc.createStereoPanner();p.pan.value=pan;types.forEach((ty,k)=>{const o=os(oc,ty,f,t,t+dur*6+.05);o.detune.value=detune[k]||0;o.connect(lp);});chain(lp,g,p,d);};
  const formant=(oc,d,f0,forms,len,breath)=>{const o=os(oc,'sawtooth',f0,0,len);const vib=os(oc,'sine',5.5);const vg=oc.createGain();vg.gain.value=f0*.015;vib.connect(vg);vg.connect(o.frequency);
    const g=ge(oc,0,.02,1,len*.45);forms.forEach(([f,q,a])=>{const b=bq(oc,'bandpass',f,q),bg=oc.createGain();bg.gain.value=a;chain(o,b,bg,g);});g.connect(d);
    if(breath)chain(ns(oc,.08),bq(oc,'bandpass',1600,1),ge(oc,0,.005,.5,.02),d);};
  const sd=60/186/4,AM=[[57,60,64],[53,57,60],[60,64,67],[55,59,62]],arp=[0,1,2,1,0,2,1,2,0,1,2,1,0,2,1,2];
  const gens={
    'KICK HARD':()=>kick(.5,320,52,.07,5,.5),'KICK TOK':()=>kick(.22,620,160,.025,3,.6),'KICK LONG':()=>kick(1,230,45,.12,7,.3),
    'TOK':()=>off(.15,1,(oc,d)=>{const o=os(oc,'sine',900,0,.15);o.frequency.exponentialRampToValueAtTime(330,.04);chain(o,sh(oc,2),ge(oc,0,.001,1,.03),d);chain(ns(oc,.01),bq(oc,'highpass',3000),ge(oc,0,.0005,.6,.003),d);}),
    'CLAP TEKK':()=>off(.6,1,(oc,d)=>{const g=oc.createGain();g.gain.setValueAtTime(0,0);[0,.011,.023,.036].forEach(t=>{g.gain.setValueAtTime(1,t);g.gain.setTargetAtTime(.05,t+.001,.004);});g.gain.setValueAtTime(.9,.045);g.gain.setTargetAtTime(0,.046,.08);chain(ns(oc,.6),bq(oc,'bandpass',1300,.9),g,d);}),
    'SNARE':()=>off(.4,1,(oc,d)=>{chain(ns(oc,.4),bq(oc,'bandpass',2200,.6),ge(oc,0,.001,.9,.07),d);const o=os(oc,'sine',190,0,.3);o.frequency.exponentialRampToValueAtTime(160,.05);chain(o,ge(oc,0,.001,.8,.05),d);}),
    'HAT 909 C':()=>off(.15,1,(oc,d)=>{const g=ge(oc,0,.0008,1,.022);chain(ns(oc,.15),bq(oc,'highpass',7500),g,d);metal(oc,2,(()=>{const m=ge(oc,0,.0008,.15,.02);chain(m,bq(oc,'highpass',8000),d);return m;})());}),
    'HAT 909 O':()=>off(.7,1,(oc,d)=>{const g=ge(oc,0,.001,1,.17);chain(ns(oc,.7),bq(oc,'highpass',7000),g,d);const m=ge(oc,0,.001,.18,.15);metal(oc,2,m);chain(m,bq(oc,'highpass',8000),d);}),
    'RIDE':()=>off(1.8,1,(oc,d)=>{const m=ge(oc,0,.001,.5,.5);metal(oc,1.6,m);chain(m,bq(oc,'bandpass',8000,.8),d);chain(ns(oc,1.8),bq(oc,'highpass',6000),ge(oc,0,.001,.25,.45),d);}),
    'CRASH':()=>off(2.4,1,(oc,d)=>{chain(ns(oc,2.4),bq(oc,'highpass',3500),ge(oc,0,.002,1,.7),d);const m=ge(oc,0,.001,.3,.6);metal(oc,1.3,m);chain(m,bq(oc,'highpass',5000),d);}),
    'PERC':()=>off(.3,1,(oc,d)=>{const o=os(oc,'sine',720,0,.3);o.frequency.exponentialRampToValueAtTime(520,.05);chain(o,ge(oc,0,.001,1,.06),d);chain(os(oc,'square',1400,0,.1),bq(oc,'bandpass',1400,3),ge(oc,0,.001,.3,.015),d);}),
    'RIM':()=>off(.12,1,(oc,d)=>{chain(os(oc,'square',1750,0,.1),bq(oc,'highpass',1500),ge(oc,0,.0005,.8,.012),d);chain(os(oc,'sine',480,0,.1),ge(oc,0,.0005,.6,.02),d);}),
    'BASS ROLL':()=>off(.5,1,(oc,d)=>{const lp=bq(oc,'lowpass',2200,3);lp.frequency.setValueAtTime(2200,0);lp.frequency.setTargetAtTime(280,0,.06);[-8,8].forEach(dt=>{const o=os(oc,'sawtooth',220,0,.5);o.detune.value=dt;o.connect(lp);});chain(lp,sh(oc,2),ge(oc,0,.002,1,.16),d);}),
    'SUB SINE':()=>off(.8,1,(oc,d)=>{chain(os(oc,'sine',220,0,.8),sh(oc,1.3),ge(oc,0,.003,1,.3),d);}),
    'SAW SHOT':()=>off(1.3,1,(oc,d)=>synthNote(oc,d,0,220,.45,['sawtooth','sawtooth'],[-7,7],2600,0,1)),
    'HOOVER SHOT':()=>off(1.4,1,(oc,d)=>{const lp=bq(oc,'lowpass',3200,1.5),g=ge(oc,0,.01,1,.5);[-22,0,22].forEach(dt=>{const o=os(oc,'sawtooth',196,0,1.4);o.frequency.setTargetAtTime(220,0,.05);o.detune.value=dt;o.connect(lp);});chain(lp,sh(oc,1.6),g,d);}),
    'PAD SHOT':()=>off(2.6,1,(oc,d)=>{const lp=bq(oc,'lowpass',1800),g=oc.createGain();g.gain.setValueAtTime(0,0);g.gain.linearRampToValueAtTime(1,.35);g.gain.setTargetAtTime(0,1,.5);[220,261.6,329.6].forEach(f=>[-9,9].forEach(dt=>{const o=os(oc,'sawtooth',f,0,2.6);o.detune.value=dt;o.connect(lp);}));chain(lp,g,d);}),
    'VOX HEY':()=>off(.75,1,(oc,d)=>formant(oc,d,165,[[530,8,1],[1840,10,.6],[2480,12,.35]],.7,true)),
    'VOX CHOP':()=>off(.35,1,(oc,d)=>formant(oc,d,200,[[800,8,1],[1150,9,.6],[2900,12,.3]],.3,true)),
    'HT MELO AM':()=>off(sd*64+.4,2,(oc,d)=>{for(let s=0;s<64;s++){const ch=AM[s>>4],n=ch[arp[s%16]]+12+(s%8===7?12:0);synthNote(oc,d,s*sd,440*Math.pow(2,(n-69)/12),.07,['sawtooth','sawtooth','square'],[-12,12,0],3400,s%2?.3:-.3,.32);}}),
    'HT MELO DM':()=>off(sd*32+.4,2,(oc,d)=>{const riff=[62,0,65,62,69,0,67,65,62,0,65,67,69,72,69,65];for(let s=0;s<32;s++){const n=riff[s%16];if(n)synthNote(oc,d,s*sd,440*Math.pow(2,(n+(s>=16?-2:0)-69)/12),.09,['square','sawtooth'],[0,9],2800,s%2?.25:-.25,.35);}}),
    'RISER':()=>off(sd*32+.1,1,(oc,d)=>{const L=sd*32,bp=bq(oc,'bandpass',200,5),g=oc.createGain();bp.frequency.setValueAtTime(200,0);bp.frequency.exponentialRampToValueAtTime(9000,L);g.gain.setValueAtTime(.05,0);g.gain.linearRampToValueAtTime(1,L);g.gain.linearRampToValueAtTime(0,L+.08);chain(ns(oc,L+.1),bp,g,d);
      const o=os(oc,'sawtooth',110,0,L);o.frequency.exponentialRampToValueAtTime(880,L);const og=oc.createGain();og.gain.setValueAtTime(0,0);og.gain.linearRampToValueAtTime(.12,L);og.gain.linearRampToValueAtTime(0,L+.05);chain(o,bq(oc,'lowpass',3000),og,d);}),
    'IMPACT':()=>off(2.2,1,(oc,d)=>{const o=os(oc,'sine',75,0,2.2);o.frequency.exponentialRampToValueAtTime(32,.6);chain(o,sh(oc,2.2),ge(oc,0,.002,1,.7),d);chain(ns(oc,1),bq(oc,'lowpass',900),ge(oc,0,.002,.7,.25),d);}),
    'ZAP':()=>off(.3,1,(oc,d)=>{const o=os(oc,'sine',2600,0,.3);o.frequency.exponentialRampToValueAtTime(60,.18);chain(o,ge(oc,0,.001,1,.08),d);}),
    'KICK PIEP':()=>kick(.6,300,52,.06,6,.4,1900,.6,.07),'KICK PIEP HI':()=>kick(.5,320,55,.05,7,.35,3200,.5,.05),
    'KICK DIST':()=>kick(.5,350,50,.06,14,.4),'KICK GABBER':()=>kick(.7,300,48,.05,30,.3),'KICK 909':()=>kick(.45,240,52,.035,1.4,.7),
    'KICK BOOM':()=>kick(1.3,170,38,.16,2.5,.2),'KICK SHORT':()=>kick(.16,520,70,.02,4,.7),'KICK ZAPP':()=>kick(.35,1500,58,.045,5,.3),'KICK TEKK 2':()=>kick(.55,330,50,.07,9,.55),
    'BASS TOK':()=>off(.25,1,(oc,d)=>{chain(os(oc,'sawtooth',220,0,.25),bq(oc,'lowpass',1400,4),sh(oc,3),ge(oc,0,.002,1,.05),d);chain(os(oc,'sine',220,0,.25),ge(oc,0,.002,.8,.07),d);}),
    'BASS REESE':()=>off(1.2,1,(oc,d)=>{const lp=bq(oc,'lowpass',1200,1);[-14,14].forEach(dt=>{const o=os(oc,'sawtooth',220,0,1.2);o.detune.value=dt;o.connect(lp);});chain(lp,sh(oc,1.5),ge(oc,0,.01,1,.6),d);}),
    'BASS ACID':()=>off(.45,1,(oc,d)=>{const lp=bq(oc,'lowpass',4000,18);lp.frequency.setValueAtTime(4000,0);lp.frequency.exponentialRampToValueAtTime(400,.2);chain(os(oc,'sawtooth',220,0,.45),lp,sh(oc,2),ge(oc,0,.002,1,.12),d);}),
    'BASS 808':()=>off(1.6,1,(oc,d)=>{const o=os(oc,'sine',300,0,1.6);o.frequency.exponentialRampToValueAtTime(220,.08);chain(o,sh(oc,2.2),ge(oc,0,.003,1,.6),d);}),
    'BASS HOOVER':()=>off(.7,1,(oc,d)=>{const lp=bq(oc,'lowpass',2600,1.5);[-20,0,20].forEach(dt=>{const o=os(oc,'sawtooth',196,0,.7);o.frequency.setTargetAtTime(220,0,.04);o.detune.value=dt;o.connect(lp);});chain(lp,sh(oc,1.8),ge(oc,0,.005,1,.25),d);}),
    'BASS OFFBEAT':()=>off(.3,1,(oc,d)=>{const lp=bq(oc,'lowpass',2400,6);lp.frequency.setValueAtTime(2400,0);lp.frequency.setTargetAtTime(500,0,.04);[-6,6].forEach(dt=>{const o=os(oc,'sawtooth',220,0,.3);o.detune.value=dt;o.connect(lp);});chain(lp,sh(oc,2.5),ge(oc,0,.002,1,.08),d);}),
    'CLAP 909':()=>off(.5,1,(oc,d)=>{const g=oc.createGain();g.gain.setValueAtTime(0,0);[0,.009,.018].forEach(t=>{g.gain.setValueAtTime(1,t);g.gain.setTargetAtTime(.1,t+.001,.003);});g.gain.setValueAtTime(.8,.026);g.gain.setTargetAtTime(0,.027,.06);chain(ns(oc,.5),bq(oc,'bandpass',1100,1.2),g,d);}),
    'CLAP BIG':()=>off(1,1,(oc,d)=>{const g=oc.createGain();g.gain.setValueAtTime(0,0);[0,.012,.025,.04].forEach(t=>{g.gain.setValueAtTime(1,t);g.gain.setTargetAtTime(.08,t+.001,.005);});g.gain.setValueAtTime(.9,.05);g.gain.setTargetAtTime(0,.051,.18);chain(ns(oc,1),bq(oc,'bandpass',1500,.7),g,d);}),
    'SNARE TEKK':()=>off(.45,1,(oc,d)=>{chain(ns(oc,.45),bq(oc,'bandpass',2600,.7),sh(oc,2),ge(oc,0,.001,1,.09),d);const o=os(oc,'triangle',230,0,.3);o.frequency.exponentialRampToValueAtTime(180,.05);chain(o,ge(oc,0,.001,.9,.05),d);}),
    'RIM 808':()=>off(.1,1,(oc,d)=>{chain(os(oc,'square',1700,0,.08),bq(oc,'bandpass',1700,4),ge(oc,0,.0003,1,.008),d);chain(os(oc,'sine',500,0,.08),ge(oc,0,.0003,.6,.012),d);}),
    'HAT 808 C':()=>off(.12,1,(oc,d)=>{const m=ge(oc,0,.0005,.6,.015);metal(oc,2.4,m);chain(m,bq(oc,'highpass',9000),d);}),
    'HAT 808 O':()=>off(.9,1,(oc,d)=>{const m=ge(oc,0,.0005,.6,.22);metal(oc,2.4,m);chain(m,bq(oc,'highpass',8500),d);}),
    'SHAKER':()=>off(.18,1,(oc,d)=>{const g=oc.createGain();g.gain.setValueAtTime(0,0);g.gain.linearRampToValueAtTime(1,.015);g.gain.setTargetAtTime(0,.02,.03);chain(ns(oc,.18),bq(oc,'highpass',6500),g,d);}),
    'TAMBOURINE':()=>off(.4,1,(oc,d)=>{chain(ns(oc,.4),bq(oc,'highpass',7500),ge(oc,0,.001,.7,.08),d);const m=ge(oc,0,.001,.4,.1);metal(oc,3.2,m);chain(m,bq(oc,'bandpass',6000,2),d);}),
    'COWBELL':()=>off(.4,1,(oc,d)=>{const g=ge(oc,0,.001,1,.08);[540,800].forEach(f=>os(oc,'square',f,0,.4).connect(g));chain(g,bq(oc,'bandpass',800,2),d);}),
    'CONGA':()=>off(.35,1,(oc,d)=>{const o=os(oc,'sine',230,0,.35);o.frequency.exponentialRampToValueAtTime(200,.04);chain(o,ge(oc,0,.001,1,.07),d);}),
    'TOM LOW':()=>off(.6,1,(oc,d)=>{const o=os(oc,'sine',140,0,.6);o.frequency.exponentialRampToValueAtTime(90,.2);chain(o,ge(oc,0,.001,1,.15),d);}),
    'TOM HIGH':()=>off(.45,1,(oc,d)=>{const o=os(oc,'sine',230,0,.45);o.frequency.exponentialRampToValueAtTime(160,.15);chain(o,ge(oc,0,.001,1,.11),d);}),
    'CLAVE':()=>off(.08,1,(oc,d)=>{chain(os(oc,'sine',2500,0,.08),ge(oc,0,.0003,1,.012),d);}),
    'VOX HO':()=>off(.5,1,(oc,d)=>formant(oc,d,150,[[570,8,1],[840,9,.5],[2410,12,.25]],.45,true)),
    'VOX YEAH':()=>off(.7,1,(oc,d)=>formant(oc,d,170,[[530,8,1],[1840,10,.6],[2480,12,.35]],.65,true)),
    'VOX AAH':()=>off(1.4,1,(oc,d)=>formant(oc,d,180,[[730,8,1],[1090,9,.6],[2440,12,.3]],1.3,false)),
    'VOX OOH':()=>off(1.4,1,(oc,d)=>formant(oc,d,180,[[300,8,1],[870,9,.5],[2240,12,.2]],1.3,false)),
    'STAB MINOR':()=>off(1,1,(oc,d)=>[57,60,64,69].forEach(n=>synthNote(oc,d,0,mf(n),.3,['sawtooth','sawtooth'],[-9,9],3000,0,.35))),
    'STAB MAJOR':()=>off(1,1,(oc,d)=>[57,61,64,69].forEach(n=>synthNote(oc,d,0,mf(n),.3,['sawtooth','sawtooth'],[-9,9],3000,0,.35))),
    'HOOVER STAB':()=>off(1,1,(oc,d)=>{const lp=bq(oc,'lowpass',3500,1.2),g=ge(oc,0,.01,1,.35);[57,64].forEach(n=>[-25,0,25].forEach(dt=>{const o=os(oc,'sawtooth',mf(n)*.89,0,1);o.frequency.setTargetAtTime(mf(n),0,.05);o.detune.value=dt;o.connect(lp);}));chain(lp,sh(oc,1.5),g,d);}),
    'PLUCK SHOT':()=>off(.6,1,(oc,d)=>{const lp=bq(oc,'lowpass',8000,3);lp.frequency.setValueAtTime(8000,0);lp.frequency.exponentialRampToValueAtTime(400,.15);chain(os(oc,'sawtooth',220,0,.6),lp,ge(oc,0,.001,1,.15),d);}),
    'BELL SHOT':()=>off(2,1,(oc,d)=>{const c=os(oc,'sine',440,0,2),m=os(oc,'sine',1540,0,2),mg=oc.createGain();mg.gain.setValueAtTime(2200,0);mg.gain.setTargetAtTime(100,0,.5);m.connect(mg);mg.connect(c.frequency);chain(c,ge(oc,0,.001,1,.6),d);}),
    'ORGAN STAB':()=>off(.8,1,(oc,d)=>{const g=ge(oc,0,.005,1,.25);[57,64,69].forEach(n=>[1,2,3,4].forEach((h,k)=>{const o=os(oc,'sine',mf(n)*h,0,.8),hg=oc.createGain();hg.gain.value=[.5,.35,.2,.15][k];o.connect(hg);hg.connect(g);}));g.connect(d);}),
    'LEAD SHOT':()=>off(.8,1,(oc,d)=>synthNote(oc,d,0,440,.3,['square','sawtooth'],[0,7],4000,0,1)),
    'LASER':()=>off(.35,1,(oc,d)=>{const o=os(oc,'sawtooth',4000,0,.35);o.frequency.exponentialRampToValueAtTime(150,.3);chain(o,bq(oc,'lowpass',6000),ge(oc,0,.001,.8,.1),d);}),
    'SIREN':()=>off(1.6,1,(oc,d)=>{const o=os(oc,'square',800,0,1.6),l=os(oc,'sine',3),lg=oc.createGain();lg.gain.value=300;l.connect(lg);lg.connect(o.frequency);chain(o,bq(oc,'lowpass',3000),ge(oc,0,.01,.6,.8),d);}),
    'NOISE UP':()=>off(sd*32+.05,1,(oc,d)=>{const L=sd*32,hp=bq(oc,'highpass',100,2),g=oc.createGain();hp.frequency.setValueAtTime(100,0);hp.frequency.exponentialRampToValueAtTime(8000,L);g.gain.setValueAtTime(.1,0);g.gain.linearRampToValueAtTime(1,L);g.gain.linearRampToValueAtTime(0,L+.04);chain(ns(oc,L+.05),hp,g,d);}),
    'NOISE DOWN':()=>off(2,1,(oc,d)=>{const lp=bq(oc,'lowpass',12000,2),g=oc.createGain();lp.frequency.setValueAtTime(12000,0);lp.frequency.exponentialRampToValueAtTime(150,2);g.gain.setValueAtTime(1,0);g.gain.linearRampToValueAtTime(0,2);chain(ns(oc,2),lp,g,d);}),
    'REVERSE CRASH':()=>gens['CRASH']().then(revB),
    'SUB DROP':()=>off(1.6,1,(oc,d)=>{const o=os(oc,'sine',90,0,1.6);o.frequency.exponentialRampToValueAtTime(28,1.5);chain(o,sh(oc,1.5),ge(oc,0,.005,1,.7),d);}),
    'ZAP 2':()=>off(.2,1,(oc,d)=>{const o=os(oc,'square',3000,0,.2);o.frequency.exponentialRampToValueAtTime(100,.12);chain(o,bq(oc,'lowpass',5000),ge(oc,0,.001,.6,.05),d);}),
    'HT MELO FM':()=>off(sd*32+.6,2,(oc,d)=>{const riff=[69,0,72,69,76,0,74,72,69,0,72,74,76,79,76,72];for(let s=0;s<32;s++){const n=riff[s%16];if(!n)continue;const t=s*sd,c=os(oc,'sine',mf(n),t,t+.5),m=os(oc,'sine',mf(n)*3.5,t,t+.5),mg=oc.createGain();mg.gain.setValueAtTime(mf(n)*5,t);mg.gain.setTargetAtTime(mf(n)*.3,t,.1);m.connect(mg);mg.connect(c.frequency);const p=oc.createStereoPanner();p.pan.value=s%2?.3:-.3;chain(c,ge(oc,t,.001,.3,.12),p,d);}}),
    'HT HOOVER LOOP':()=>off(sd*32+.4,2,(oc,d)=>{const riff=[57,0,57,60,0,57,64,0,57,0,57,60,0,62,60,0];for(let s=0;s<32;s++){const n=riff[s%16];if(!n)continue;const t=s*sd,lp=bq(oc,'lowpass',3000,1.2);[-22,0,22].forEach(dt=>{const o=os(oc,'sawtooth',mf(n)*.89,t,t+sd*1.6);o.frequency.setTargetAtTime(mf(n),t,.03);o.detune.value=dt;o.connect(lp);});chain(lp,ge(oc,t,.004,.28,sd*.6),d);}}),
    'TEKK BASS LOOP':()=>off(sd*16+.3,1,(oc,d)=>{for(let s=0;s<16;s++){if(s%4===0)continue;const t=s*sd,lp=bq(oc,'lowpass',1500,5);lp.frequency.setValueAtTime(1500,t);lp.frequency.setTargetAtTime(300,t,.04);[-6,6].forEach(dt=>{const o=os(oc,'sawtooth',55,t,t+sd);o.detune.value=dt;o.connect(lp);});chain(lp,ge(oc,t,.002,.6,sd*.35),d);}}),
  };
  await Promise.all(SRC.map(async s=>{if(!s.off&&gens[s.n])s.buf=await gens[s.n]();}));
  SRC.forEach(s=>{if(s.buf&&!s.loop)s.f0=detectF0(s.buf);});
}

/* ---------- EMX-1 SYNTH PCM: die 76 Wellen der PCM-Typen (PCM OSC+COMB, PCM OSC+WS) ----------
   Namen + Reihenfolge wie die Synth PCM List im EMX-1-Handbuch (S. 40). Die Klänge sind hier nachgebaut, es sind keine Korg-Samples.
   Tonale Wellen stehen auf A3 = 220 Hz wie die übrigen Samples. Gehaltene Klänge haben eine Schleife (Übergang überblendet), Anschläge nicht.
   66-72 Chord Sets: die Oktave wählt den Akkord (A3-Oktave C3-H3 = Dur, C4-H4 = Moll, C5-H5 = Maj7, sonst min7; Gitarren Dur/Moll/sus4/7).
   73-76 Drum Sets: der Ton wählt den Drum-Sound (A3 = erster). Gerechnet wird erst, wenn eine Welle gebraucht wird, in kleinen Häppchen,
   damit Sequencer und Oberfläche nicht stocken. Danach bleibt sie im Speicher. */
const PF=220,PCM=[],pcmJobs=new Map();
const CH4=[[0,4,7,12],[0,3,7,12],[0,4,7,11],[0,3,7,10]],CHG=[[0,7,12,16,19,24],[0,7,12,15,19,24],[0,7,12,17,19,24],[0,7,10,16,19,24]];
const PCM_DRUMS=[['KICK HARD','KICK TOK','KICK LONG','KICK PIEP','KICK PIEP HI','KICK DIST','KICK GABBER','KICK 909','KICK BOOM','KICK SHORT','KICK ZAPP','KICK TEKK 2'],
  ['SNARE','SNARE TEKK','CLAP TEKK','CLAP 909','CLAP BIG','RIM','RIM 808'],['HAT 909 C','HAT 909 O','HAT 808 C','HAT 808 O','RIDE','CRASH','REVERSE CRASH','TOM LOW','TOM HIGH'],
  ['PERC','TOK','CONGA','COWBELL','CLAVE','SHAKER','TAMBOURINE']];
const st2=s=>Math.pow(2,s/12),ct2=c=>Math.pow(2,c/1200),nz=()=>Math.random()*2-1,envAD=(t,a,dec)=>t<a?t/a:(dec?Math.exp(-(t-a)/dec):1);
/* Bausteine: Oszillator mit PolyBLEP (kein Aliasing-Kratzen), Zustandsvariablen-Filter */
const pblep=(t,dt)=>{if(t<dt){t/=dt;return t+t-t*t-1;}if(t>1-dt){t=(t-1)/dt;return t*t+t+t+1;}return 0;};
function pOsc(R){let p=Math.random();return{
  saw(f){const dt=f/R,v=2*p-1-pblep(p,dt);p+=dt;if(p>=1)p-=1;return v;},
  sq(f,w=.5){const dt=f/R,v=(p<w?1:-1)+pblep(p,dt)-pblep((p-w+1)%1,dt);p+=dt;if(p>=1)p-=1;return v;},
  sin(f){const v=Math.sin(TAU*p);p+=f/R;if(p>=1)p-=1;return v;}};}
function pSVF(R){let a=0,b=0;const o={lp:0,bp:0,hp:0,run(x,fc,q){const g=Math.tan(Math.PI*Math.min(fc,R*.45)/R),k=1/q,a1=1/(1+g*(g+k)),a2=g*a1,a3=g*a2,v3=x-b,v1=a1*a+a2*v3,v2=b+a2*a+a3*v3;
  a=2*v1-a;b=2*v2-b;o.lp=v2;o.bp=v1;o.hp=x-k*v1-v2;return v2;}};return o;}
/* Additiv: Teiltöne [Verhältnis, Pegel, Ausklingzeit s (0 = gehalten)], ch = Akkord in Halbtönen, det = Schwebung (zweite Saite) */
const gAdd=(parts,{att=.003,dec=0,ch=[0],det=0,hammer=0,hCut=2500,trem=0,tremR=5.5}={})=>(R)=>{
  const ps=[];ch.forEach(s=>parts.forEach(([r,a,dc],k)=>{ps.push({f:PF*st2(s)*r,a,m:dc?Math.exp(-1/(R*dc)):1,e:1,o:pOsc(R)});if(det&&k<6)ps.push({f:PF*st2(s)*r*(1+det),a:a*.7,m:dc?Math.exp(-1/(R*dc)):1,e:1,o:pOsc(R)});}));
  const sv=pSVF(R),g=1/ch.length;
  return i=>{const t=i/R;let v=0;for(const p of ps){v+=p.a*p.e*p.o.sin(p.f);p.e*=p.m;}v*=g*envAD(t,att,dec);
    if(trem)v*=1-trem*.5*(1-Math.cos(TAU*tremR*t));if(hammer&&t<.06)v+=hammer*Math.exp(-t/.006)*sv.run(nz(),hCut,.7);return v;};};
/* FM: Modulator m1 (Index i0 -> i1 in it Sekunden), m2/j0/jt = kurzer Glockenanteil (E-Piano-Tine), lfo = Wackeln am Modulator */
const gFM=({m1=1,i0=2,i1=.4,it=.4,m2=0,j0=0,jt=.03,att=.002,dec=1,ch=[0],lfo=0,lfoR=0}={})=>(R)=>{
  const vs=ch.map(s=>({f:PF*st2(s),c:0,m:0,m2:0})),g=1/ch.length;
  return i=>{const t=i/R,I=i1+(i0-i1)*Math.exp(-t/it),J=j0*Math.exp(-t/jt),lm=1+lfo*Math.sin(TAU*lfoR*t);let v=0;
    for(const x of vs){v+=Math.sin(TAU*x.c+I*Math.sin(TAU*x.m)+J*Math.sin(TAU*x.m2));x.c=(x.c+x.f/R)%1;x.m=(x.m+x.f*m1*lm/R)%1;x.m2=(x.m2+x.f*m2/R)%1;}
    return v*g*envAD(t,att,dec);};};
/* Oszillator-Stapel + Filter: vs = [[Welle saw|sq|sin, Verhältnis, Cent, Pegel]]. cut0 -> cut in ct Sekunden, mode lp|bp, hp = Hochpass,
   sat = Sättigung, scoop = Tonhöhe kommt von +/- Cent (Zeit sct), noise = Anschlag-Rauschen */
const gSyn=(vs,{att=.005,dec=0,cut=8000,cut0=0,ct=.1,q=.7,mode='lp',hp=0,sat=0,pw=.5,vib=0,vibR=5.5,vibD=.25,scoop=0,sct=.04,ch=[0],noise=0,nDec=.03,nCut=3000}={})=>(R)=>{
  const os=[];ch.forEach(s=>vs.forEach(([ty,r,c,a])=>os.push({ty,f:PF*st2(s)*r*ct2(c),a,o:pOsc(R)})));
  const f1=pSVF(R),f2=pSVF(R),f3=pSVF(R),g=1/Math.sqrt(ch.length);
  return i=>{const t=i/R,pm=(vib&&t>vibD?1+vib*Math.sin(TAU*vibR*(t-vibD)):1)*(scoop?ct2(scoop*Math.exp(-t/sct)):1);let v=0;
    for(const x of os){const ff=x.f*pm;v+=x.a*(x.ty==='saw'?x.o.saw(ff):x.ty==='sq'?x.o.sq(ff,pw):x.o.sin(ff));}
    v*=g;if(noise)v+=noise*Math.exp(-t/nDec)*f3.run(nz(),nCut,.8);
    f1.run(v,cut0?cut+(cut0-cut)*Math.exp(-t/ct):cut,q);v=mode==='bp'?f1.bp:f1.lp;if(hp){f2.run(v,hp,.7);v=f2.hp;}
    if(sat)v=Math.tanh(v*sat);return v*envAD(t,att,dec);};};
/* Gezupfte Saite (Karplus-Strong): dec = Ausklingzeit, br = Helligkeit 0..1, pk = Anschlagpunkt, buzz = Sitar-Schnarren,
   ch = Akkord (gestrummt, strum = Abstand), body = Korpus-Resonanz, pop = Slap-Knacken */
const gPluck=({dec=1.5,br=.6,pk=.15,buzz=0,ch=[0],strum=.012,body=.25,pop=0}={})=>(R,n)=>{
  const vs=ch.map((s,k)=>{const f=PF*st2(s),L=R/f,sm=.5-br*.42,E=Math.ceil(L),ex=new Float32Array(E);let lp=0;
    for(let j=0;j<E;j++){lp+=(nz()-lp)*(.12+br*.88);ex[j]=lp;}const pS=Math.max(1,Math.round(pk*L));for(let j=E-1;j>=pS;j--)ex[j]-=ex[j-pS];
    return{st:Math.round(k*strum*R),D:L-sm,y:new Float32Array(n),ex,E,sm,g:Math.pow(.001,1/(f*dec))};});
  const b1=pSVF(R),b2=pSVF(R),g=1/Math.sqrt(ch.length);
  return i=>{let v=0;for(const x of vs){const j=i-x.st;if(j<0)continue;let s=j<x.E?x.ex[j]:0;const p=j-x.D*(buzz?1-buzz*Math.min(1,Math.abs(x.y[j-1]||0)):1);
      if(p>=1){const q=Math.floor(p),fr=p-q,a0=x.y[q]+(x.y[q+1]-x.y[q])*fr,a1=x.y[q-1]+(x.y[q]-x.y[q-1])*fr;s+=x.g*((1-x.sm)*a0+x.sm*a1);}x.y[j]=s;v+=s;}
    v*=g;if(body){b1.run(v,240,1.4);b2.run(v,480,1.8);v+=body*(b1.bp+.6*b2.bp);}if(pop&&i<R*.02)v+=pop*Math.exp(-i/R/.002)*nz();return v;};};
/* Formanten (Stimme, Saxofon, Geige …): Sägezahn/Puls durch parallele Bandpässe [Hz, Güte, Pegel]; morph = Ziel-Formanten nach mt Sekunden */
const gVox=(forms,{att=.06,dec=0,vib=.005,vibR=5.2,vibD=.25,br=.03,voices=[0],src='saw',pw=.5,morph=null,mt=.6,scoop=0,ch=[0]}={})=>(R)=>{
  const os=[];ch.forEach(s=>voices.forEach(c=>os.push({f:PF*st2(s)*ct2(c),o:pOsc(R)})));const fl=forms.map(()=>pSVF(R)),g=1/os.length;
  return i=>{const t=i/R,pm=(vib&&t>vibD?1+vib*Math.sin(TAU*vibR*(t-vibD)):1)*(scoop?ct2(scoop*Math.exp(-t/.05)):1);let x=0;
    for(const u of os)x+=src==='saw'?u.o.saw(u.f*pm):u.o.sq(u.f*pm,pw);x=x*g+br*nz();let v=0;
    forms.forEach(([ff,q,a],k)=>{fl[k].run(x,morph?ff+(morph[k]-ff)*Math.min(1,t/mt):ff,q);v+=a*fl[k].bp;});return v*envAD(t,att,dec);};};
const gFlute=()=>(R)=>{const o1=pOsc(R),o2=pOsc(R),o3=pOsc(R),bn=pSVF(R);return i=>{const t=i/R,pm=t>.3?1+.005*Math.sin(TAU*5*(t-.3)):1;
  bn.run(nz(),2600,1.2);return(o1.sin(PF*pm)+.22*o2.sin(2*PF*pm)+.07*o3.sin(3*PF*pm)+.16*bn.bp*(1+.6*Math.exp(-t/.06)))*(t<.08?t/.08:1);};};
/* Endless: Shepard-Ton, steigt endlos (eine Oktave pro 2 s) */
const gEndless=()=>(R)=>{const K=9,ph=new Float64Array(K);return i=>{const t=i/R;let v=0;for(let k=0;k<K;k++){const x=(k+t/2)%K;ph[k]=(ph[k]+27.5*Math.pow(2,x)/R)%1;v+=Math.exp(-Math.pow((x-K/2)/(K/5),2))*Math.sin(TAU*ph[k]);}return v;};};
/* Syn-FX2: Rauschen durch wandernden Resonanzfilter (Wind) */
const gWind=()=>(R)=>{const f=pSVF(R),f2=pSVF(R);return i=>{const t=i/R,fc=900*Math.pow(2,1.6*Math.sin(TAU*.5*t)),x=nz();f.run(x,fc,8);f2.run(x,fc*2.03,10);return f.bp+.5*f2.bp;};};
const PIANO=Array.from({length:12},(_,k)=>{const n=k+1;return[n*Math.sqrt(1+.0004*n*n),(n===1?1:1.25)/Math.pow(n,1.15),1.9/(1+.42*k)];}),
  M1PIANO=Array.from({length:12},(_,k)=>{const n=k+1;return[n*Math.sqrt(1+.0003*n*n),1/Math.pow(n,.9),1.4/(1+.35*k)];}),
  M1ORG=[[.5,.45,0],[1,1,0],[1.5,.3,0],[2,.55,0],[2,.3,.12],[3,.3,0],[3,.25,.08],[4,.32,0],[6,.12,0],[8,.08,0]],
  HORG=[[.5,.8,0],[1,1,0],[1.5,.8,0],[2,.55,0],[3,.4,0],[3,.35,.15],[4,.3,0],[5,.15,0],[6,.15,0],[8,.12,0]],
  STR=[['saw',1,-12,.4],['saw',1,-5,.4],['saw',1,0,.4],['saw',1,6,.4],['saw',1,12,.4]];
/* Einträge: sec = Länge, mk = Generator, ls/le = Schleife (s), xf = Überblendung; chord 1 = Akkord-Set, chord 2 = Gitarren-Set; drum = Drum-Set */
const ONE=(sec,mk)=>({sec,mk}),SUS=(sec,mk,ls,le,xf=.12)=>({sec,mk,ls,le,xf}),PER=(mk)=>({sec:1.2,mk,ls:.4,le:.9,xf:.02});   // PER = periodische Welle, Schleife 0,5 s (ganze Perioden)
const EP=ch=>gFM({m1:1,i0:1.7,i1:.25,it:.45,m2:14,j0:1.1,jt:.018,dec:1.25,ch});
const PCM_GEN=[
  ONE(2.2,gAdd(PIANO,{det:.0009,hammer:.35})),ONE(2.2,EP([0])),ONE(1.4,gPluck({dec:.7,br:.95,pk:.07,body:0})),
  SUS(1.4,gAdd(M1ORG,{hammer:.12,hCut:4000}),.5,1,.02),SUS(1.4,gAdd(HORG,{hammer:.18,hCut:5000}),.5,1,.02),
  ONE(1.3,gAdd([[1,1,.45],[3.93,.38,.11],[9.2,.12,.035]],{att:.001,hammer:.15,hCut:2000})),
  ONE(2.4,gAdd([[1,1,1.7],[4,.32,.45],[10,.08,.12]],{att:.001,trem:.4,tremR:5.6,hammer:.08})),
  ONE(2.4,gAdd([[.56,.5,1.5],[.92,.45,1.1],[1,1,1.9],[1.19,.4,.9],[1.71,.35,.7],[2,.3,.8],[2.74,.25,.5],[3,.22,.4],[3.76,.15,.3],[4.07,.15,.25]],{att:.001})),
  SUS(1.8,gFlute(),.7,1.7),
  SUS(1.8,gVox([[520,4,1],[1450,5,.7],[2600,6,.35]],{src:'sq',pw:.42,br:.04,vib:.004,scoop:-35,att:.05}),.7,1.7),
  SUS(1.8,gVox([[430,4,1],[1200,5,.65],[2350,6,.3]],{br:.06,vib:.0045,vibR:5,scoop:-50,att:.05}),.7,1.7),
  SUS(1.8,gSyn([['saw',1,0,1]],{att:.03,cut:3200,cut0:500,ct:.05,q:1.3,vib:.004,vibD:.4,scoop:-45}),.7,1.7),
  SUS(1.8,gSyn([['saw',1,0,1]],{att:.03,mode:'bp',cut:1800,cut0:900,ct:.05,q:2.5,hp:500,vib:.004,vibD:.4,scoop:-30}),.7,1.7),
  SUS(1.8,gSyn([['saw',1,-9,.6],['saw',1,0,.6],['saw',1,9,.6],['saw',.5,4,.3]],{att:.05,cut:2800,cut0:600,ct:.08,q:.9,scoop:-25}),.7,1.7),
  SUS(1.8,gVox([[730,8,1],[1090,9,.5],[2440,12,.25]],{vib:.006,att:.1}),.7,1.7),
  SUS(2,gVox([[600,7,1],[1000,8,.45],[2600,10,.2]],{voices:[-11,-4,4,11],br:.02,att:.18,vib:.004}),.8,1.9,.15),
  SUS(1.9,gVox([[730,8,1],[1090,9,.5],[2440,12,.25]],{morph:[570,840,2410],mt:.6,vib:.005}),.8,1.8),
  SUS(1.8,gVox([[280,2,.8],[1000,2.5,1],[2600,3,.5]],{vib:.007,vibR:5.8,vibD:.15,att:.08,br:.01}),.7,1.7),
  SUS(2,gSyn(STR,{att:.14,cut:3600,q:.6,vib:.003,vibR:5,vibD:.2}),.8,1.9,.15),
  ONE(.8,gPluck({dec:.4,br:.45,pk:.22,body:.4})),ONE(2.2,gPluck({dec:2.2,br:.78,pk:.12,body:.3})),ONE(2,gPluck({dec:1.7,br:.45,pk:.2,body:.4})),
  ONE(.5,gPluck({dec:.13,br:.38,pk:.15,body:.3})),ONE(.8,gPluck({dec:.35,br:.92,pk:.07,body:.15})),ONE(2.4,gPluck({dec:2.6,br:.82,pk:.1,buzz:.35,body:.2})),
  ONE(1.6,gPluck({dec:1.3,br:.28,pk:.25,body:.5})),ONE(1.8,gPluck({dec:1.6,br:.5,pk:.2,body:.1})),ONE(1.6,gPluck({dec:1.4,br:.62,pk:.16,body:.15,pop:.15})),
  ONE(1.6,gPluck({dec:1.3,br:.85,pk:.1,body:.1,pop:.25})),ONE(1.4,gPluck({dec:1,br:1,pk:.05,body:.1,pop:.6})),
  ONE(1.2,gFM({m1:1,i0:3.2,i1:.5,it:.12,dec:.75})),ONE(1.2,gSyn([['sq',1,0,.7],['sin',.5,0,.6]],{att:.002,dec:.55,cut:500,cut0:3500,ct:.07,q:1.6})),
  PER(gSyn([['saw',1,0,1],['sin',1,0,.6]],{sat:2.2,cut:9000})),PER(gSyn([['saw',1,0,.6],['sq',2,0,.4]],{cut:9000})),PER(gSyn([['saw',1,0,1]],{cut:12000,hp:1400})),
  PER(gSyn([['saw',1,0,.7],['saw',.5,0,.7]],{cut:3500})),PER(gSyn([['sq',1,0,.6],['sq',.5,0,.6]],{cut:2600})),
  PER(gSyn([['saw',1,0,.7],['saw',1.5,0,.55]],{cut:8000})),PER(gSyn([['sq',1,0,.6],['sq',1.5,0,.5]],{cut:7000})),
  PER(gSyn([['sin',1,0,1]])),PER(gSyn([['sin',1,0,1],['sin',2,0,.4]])),PER(gSyn([['sin',1,0,1],['sin',3,0,.35],['sin',5,0,.12]])),
  PER(gSyn([['sin',1,0,1],['sin',1.5,0,.5],['sin',2,0,.25]])),PER(gSyn([['sin',1,0,1]],{sat:3})),
  PER(gSyn([['sq',1,0,1]],{pw:.08,cut:10000})),PER(gSyn([['sq',1,0,.7],['saw',3,0,.25]],{pw:.16,cut:6000,q:2.2})),
  PER(gFM({m1:2,i0:2.4,i1:2.4,dec:0})),PER(gFM({m1:3,i0:1.7,i1:1.7,dec:0})),PER(gFM({m1:.5,i0:3.4,i1:3.4,dec:0})),PER(gFM({m1:4,i0:1.2,i1:1.2,m2:7,j0:.6,jt:1e9,dec:0})),
  SUS(1.8,gVox([[300,10,1],[870,10,.4],[2240,12,.2]],{voices:[-7,7],vib:0,br:.01,att:.1}),.7,1.7),
  SUS(1.8,gVox([[270,10,1],[2290,12,.6],[3010,12,.3]],{voices:[-7,7],vib:0,br:.01,att:.1}),.7,1.7),
  SUS(2.5,gEndless(),.4,2.4,.2),SUS(2.2,gFM({m1:1.41,i0:4,i1:4,dec:0,lfo:.08,lfoR:2.5}),.6,2.2,.1),SUS(2.6,gWind(),.5,2.5,.2),
  ONE(1.2,gSyn([['saw',1,-8,.5],['saw',1,8,.5],['sq',.5,0,.3]],{ch:[0,4,7,12,16],att:.002,dec:.28,cut:5000,cut0:9000,ct:.1,noise:.5,nCut:2000})),
  ONE(1,gSyn([['saw',1,-7,.5],['saw',1,7,.5]],{ch:[0,4,7,12],att:.008,dec:.3,cut:3500,cut0:800,ct:.03,q:1,noise:.4,nDec:.05,nCut:5000})),
  ONE(1,gSyn([['saw',1,-7,.5],['saw',1,7,.5]],{ch:[0,3,7,10,12],att:.008,dec:.3,cut:4000,cut0:900,ct:.03,q:1,noise:.35,nDec:.05,nCut:5000})),
  ONE(1.4,gSyn([['saw',1,-10,.4],['saw',1,0,.4],['saw',1,10,.4]],{ch:[0,7,12,16,24],att:.004,dec:.45,cut:6000,noise:.2,nDec:.02})),
  ONE(1,gSyn([['saw',1,-15,.5],['saw',1,15,.5]],{ch:[0,3,7,12],att:.002,dec:.3,cut:5000,sat:1.8})),
  ONE(1.2,gSyn([['saw',1,-25,.5],['saw',1,0,.5],['saw',1,25,.5],['saw',.5,0,.4]],{ch:[0,12],att:.003,dec:.45,cut:4000,scoop:-300,sct:.06,sat:1.5})),
  ONE(1,gAdd(M1ORG,{ch:[0,3,7,12],dec:.3,hammer:.2})),ONE(1.6,gAdd(M1PIANO,{ch:[0,4,7,11],det:.0012,hammer:.4})),
  ONE(1,gSyn([['sq',1,-6,.5],['sq',1,6,.5]],{ch:[0,5,7,12],att:.002,dec:.28,cut:500,cut0:7000,ct:.07,q:4})),
  ONE(.9,gSyn([['saw',1,-12,.5],['saw',1,12,.5]],{ch:[0,7,12],att:.001,dec:.2,cut:7000,scoop:900,sct:.05,noise:.6,nDec:.02,nCut:8000})),
  {sec:2.2,chord:1,mk:ch=>gAdd(PIANO,{ch,det:.0009,hammer:.35})},{sec:2,chord:1,mk:ch=>gAdd(M1PIANO,{ch,det:.0012,hammer:.4})},{sec:2.2,chord:1,mk:EP},
  {sec:1.4,chord:1,mk:ch=>gAdd(HORG,{ch,hammer:.18,hCut:5000}),ls:.5,le:1,xf:.02},{sec:2,chord:1,mk:ch=>gSyn(STR,{ch,att:.14,cut:3600,q:.6,vib:.003,vibR:5,vibD:.2}),ls:.8,le:1.9,xf:.15},
  {sec:2.2,chord:2,mk:ch=>gPluck({ch,dec:2,br:.75,pk:.12,body:.3,strum:.014})},{sec:.8,chord:2,mk:ch=>gPluck({ch,dec:.25,br:.85,pk:.08,body:.15,strum:.008})},
  {drum:0},{drum:1},{drum:2},{drum:3}];
/* rechnet eine Welle in Häppchen (max. ~6 ms am Stück), entfernt Gleichanteil, gleicht die Lautheit an (RMS der ersten 0,4 s,
   Spitzen weich begrenzt – sonst wären gezupfte Wellen viel leiser als Orgeln), blendet Anschläge am Ende aus */
async function pRender(sec,mk,oneShot){const R=ctx.sampleRate,n=Math.ceil(sec*R),d=new Float32Array(n),step=mk(R,n);let i=0;
  while(i<n){const t0=performance.now();while(i<n&&performance.now()-t0<6){const e=Math.min(n,i+512);for(;i<e;i++)d[i]=step(i);}if(i<n)await new Promise(r=>setTimeout(r,0));}
  let x1=0,y1=0,ss=0,pk=1e-9;const wN=Math.min(n,Math.round(.4*R));for(let k=0;k<n;k++){const y=d[k]-x1+.9995*y1;x1=d[k];y1=y;d[k]=y;if(k<wN)ss+=y*y;pk=Math.max(pk,Math.abs(y));}
  const g=Math.min(.28/(Math.sqrt(ss/wN)+1e-9),2/pk),fo=oneShot?Math.round(.02*R):0;   // Ziel ca. -11 dBFS RMS wie die Synth-Typen
  for(let k=0;k<n;k++){let v=d[k]*g;const a=Math.abs(v);if(a>.8)v=Math.sign(v)*(.8+.2*Math.tanh((a-.8)/.2));d[k]=v*(k>=n-fo?(n-k)/fo:1);}
  const b=ctx.createBuffer(1,n,R);b.copyToChannel(d,0);return b;}
/* Schleife ohne Knacken: das Ende der Schleife wird in den Bereich vor dem Schleifenstart überblendet */
function bakeLoop(b,ls,le,xf){const R=b.sampleRate,d=b.getChannelData(0),s=Math.round(ls*R),e=Math.min(d.length,Math.round(le*R)),X=Math.min(Math.round(xf*R),s,e-s);
  for(let i=0;i<X;i++){const a=i/X,j=e-X+i;d[j]=d[j]*(1-a)+d[s-X+i]*a;}}
async function pcmMake(k){const Gn=PCM_GEN[k];let r;if(Gn.drum!=null)return{drum:PCM_DRUMS[Gn.drum].map(srcIdx).filter(x=>x>0)};
  if(Gn.chord){const bufs=[];for(const c of(Gn.chord===2?CHG:CH4))bufs.push(await pRender(Gn.sec,Gn.mk(c),!Gn.ls));r={bufs};}else r={buf:await pRender(Gn.sec,Gn.mk,!Gn.ls)};
  if(Gn.ls){(r.bufs||[r.buf]).forEach(b=>bakeLoop(b,Gn.ls,Gn.le,Gn.xf));r.ls=Gn.ls;r.le=Gn.le;}return r;}
/* Warteschlange: immer nur eine Welle gleichzeitig rechnen, die zuletzt gewünschte zuerst. Beim schnellen Durchdrehen
   werden nur die letzten 6 behalten, nicht alles, woran man vorbeigedreht hat */
const pcmWant=[];let pcmBusy=false;
function emxPcmLoad(k){k|=0;if(!ctx||k<0||k>=PCM_GEN.length||PCM[k]||pcmJobs.has(k))return;const i=pcmWant.indexOf(k);if(i>=0)pcmWant.splice(i,1);pcmWant.push(k);
  if(pcmWant.length>6)pcmWant.shift();if(!pcmBusy)pcmRun();}
async function pcmRun(){pcmBusy=true;while(pcmWant.length){const k=pcmWant.pop();if(PCM[k])continue;pcmJobs.set(k,1);
    try{PCM[k]=await pcmMake(k);}catch(e){console.warn('EMX PCM',k,e);}pcmJobs.delete(k);}pcmBusy=false;}
/* PCM-Wellen, die das Pattern benutzt, schon vorher rechnen (sonst bleibt der erste Ton stumm) */
function pcmPreload(){if(!cur)return;cur.parts.forEach(P=>{if(P.osc===14||P.osc===15)emxPcmLoad(P.wave|0);});}
/* Puffer + Tonhöhe für einen Ton: Chord Sets wählen den Akkord nach Oktave, Drum Sets den Sound nach Ton */
function emxPcmVoice(k,freq){const Q=PCM[k];if(!Q){emxPcmLoad(k);return null;}const note=Math.round(69+12*Math.log2(freq/440));
  if(Q.drum){if(!Q.drum.length)return null;const S=SRC[Q.drum[((note-57)%Q.drum.length+Q.drum.length)%Q.drum.length]];return S&&S.buf?{buf:S.buf,rate:1}:null;}
  return{buf:Q.bufs?Q.bufs[Math.floor((((note%48)+48)%48)/12)]:Q.buf,rate:freq/PF,ls:Q.ls,le:Q.le};}

/* ---------- Time-Stretch (WSOLA) ---------- */
function wsola(chs,alpha){
  const N=2048,Hs=N>>1,tol=512,inLen=chs[0].length,outLen=Math.ceil(inLen*alpha),win=new Float32Array(N);
  for(let k=0;k<N;k++)win[k]=.5-.5*Math.cos(TAU*k/N);
  const mono=new Float32Array(inLen);for(const a of chs)for(let k=0;k<inLen;k++)mono[k]+=a[k]/chs.length;
  const out=chs.map(()=>new Float32Array(outLen+N)),Ha=Hs/alpha,frames=Math.ceil(outLen/Hs);let prev=0;
  for(let m=0;m<frames;m++){
    let s=0;
    if(m>0){const nominal=Math.round(m*Ha),nat=prev+Hs,lo=Math.max(0,nominal-tol),hi=Math.min(inLen-N-1,nominal+tol);
      if(hi<lo)s=Math.max(0,Math.min(inLen-1,nominal));else{let best=lo,bc=-Infinity;for(let c=lo;c<=hi;c+=8){let cc=0;for(let k=0;k<Hs;k+=4)cc+=mono[c+k]*(mono[nat+k]||0);if(cc>bc){bc=cc;best=c;}}s=best;}}
    if(s>=inLen)break;const o=m*Hs,lim=Math.min(N,inLen-s);
    for(let c=0;c<chs.length;c++){const src=chs[c],dst=out[c];for(let k=0;k<lim;k++)dst[o+k]+=src[s+k]*win[k];}
    prev=s;
  }
  return out.map(a=>a.subarray(0,outLen));
}
function processBuf(buf,semis,tf){
  const r=Math.pow(2,semis/12),alpha=tf*r,chs=[];for(let c=0;c<buf.numberOfChannels;c++)chs.push(buf.getChannelData(c));
  const st=Math.abs(alpha-1)<.004?chs:wsola(chs,alpha),outLen=Math.max(1,Math.floor(st[0].length/r)),out=ctx.createBuffer(chs.length,outLen,buf.sampleRate);
  for(let c=0;c<chs.length;c++){const s=st[c],o=out.getChannelData(c);if(Math.abs(r-1)<1e-4)o.set(s.subarray(0,outLen));else for(let k=0;k<outLen;k++){const p=k*r,i0=p|0,fr=p-i0;o[k]=(s[i0]||0)*(1-fr)+(s[i0+1]||0)*fr;}}
  return out;
}
function revBuf(S){if(!S.rev){const b=ctx.createBuffer(S.buf.numberOfChannels,S.buf.length,S.buf.sampleRate);for(let c=0;c<b.numberOfChannels;c++){const s=S.buf.getChannelData(c),d=b.getChannelData(c),n=s.length;for(let k=0;k<n;k++)d[k]=s[n-1-k];}S.rev=b;}return S.rev;}
const bufCache=new Map();let stretchJobs=new Set(),stretchTimer=null;
/* STRETCH-Länge in Steps (Menü, Plan): auf wie viele Steps das Sample gestreckt wird */
const stretchSteps=P=>clamp(Math.round(P.lenSt??((P.len??3)+1)*16),1,128);
function stretchTF(P,S){return P.stretch===2?(stretchSteps(P)*stepLen())/S.buf.duration:1;}
function stretchKey(P){const S=SRC[P.src];return `${P.src}|${P.pitch}|${stretchTF(P,S).toFixed(3)}|${P.reverse?1:0}`;}
function scheduleStretch(i){stretchJobs.add(i);clearTimeout(stretchTimer);stretchTimer=setTimeout(runStretch,140);}
function runStretch(){
  for(const i of stretchJobs){const P=cur.parts[i],S=SRC[P.src];if(!S||!S.buf||!P.stretch)continue;const key=stretchKey(P);if(bufCache.has(key))continue;
    bufCache.set(key,processBuf(P.reverse?revBuf(S):S.buf,P.pitch,stretchTF(P,S)));if(bufCache.size>40)bufCache.delete(bufCache.keys().next().value);}
  stretchJobs.clear();
}
function playBuf(i){
  const P=cur.parts[i],S=SRC[P.src];if(!S||!S.buf)return null;
  if(P.stretch){const b=bufCache.get(stretchKey(P));if(b)return{buf:b,baked:true};scheduleStretch(i);}
  return{buf:P.reverse?revBuf(S):S.buf,baked:false};
}

/* ---------- SYNTH OSCILLATOR 1:1 wie Korg EMX-1 (16 Typen · WAVE · OSC EDIT 1 + 2, Owner's Manual S. 34-38) ---------- */
const waveCache=new Map();
function pwave(key,fnIm){if(!waveCache.has(key)){const N=96,re=new Float32Array(N),im=new Float32Array(N);for(let n=1;n<N;n++)im[n]=fnIm(n);waveCache.set(key,ctx.createPeriodicWave(re,im));}return waveCache.get(key);}
function pulseWave(w){const k='p'+w.toFixed(3);if(!waveCache.has(k)){const N=64,re=new Float32Array(N),im=new Float32Array(N);for(let n=1;n<N;n++)re[n]=2/(n*Math.PI)*Math.sin(n*Math.PI*w);waveCache.set(k,ctx.createPeriodicWave(re,im));}return waveCache.get(k);}
const VOWELS=[[730,1090,2440],[530,1840,2480],[270,2290,3010],[570,840,2410],[300,870,2240]];
const curveCache=new Map(),ccurve=(key,fn)=>{if(!curveCache.has(key))curveCache.set(key,curve(fn,2048));return curveCache.get(key);};
/* EDIT-Skalen wie auf der EMX: ±63 (47 = 1 Oktave, 63 = 2 Oktaven), 0..127 (31 = 1 Oktave … 127 = 4 Oktaven), Harmonische 0.25…32 */
const emxPm=v=>{const x=(v-.5)*126,a=Math.abs(x);return Math.sign(x)*(a<=47?a/47*12:12+(a-47)/16*12);};
const emxU=v=>Math.pow(2,clamp(v)*127/31.75);
const emxH=v=>EMX_HARM[Math.round(clamp(v)*(EMX_HARM.length-1))];
const semi=s=>Math.pow(2,s/12);
/* Wellenform an Phase ph (0..1) mit EDIT1-Formung q – für OSC SYNC */
function emxShapeAt(kind,q,ph){switch(kind){
  case 'SAW':{const s=1-2*ph,sq=ph<.5?1:-1;return s*(1-q)+sq*q;}
  case 'PULSE':return ph<Math.max(.012,.5*(1-q))?1:-1;
  case 'TRI':{const tr=ph<.25?ph*4:ph<.75?2-ph*4:ph*4-4;return Math.asin(Math.sin(Math.PI/2*tr*(1+q*2)))*2/Math.PI;}
  default:{const s=Math.sin(TAU*ph);return Math.sin(s*(1+q*3)*Math.PI/2);}}}
function syncPW(kind,q,r){const key='y'+kind+q+'|'+r;if(!waveCache.has(key)){const N=80,M=1024,x=new Float32Array(M);for(let j=0;j<M;j++)x[j]=emxShapeAt(kind,q,(j/M*r)%1);
  const re=new Float32Array(N),im=new Float32Array(N);for(let k=1;k<N;k++){let a=0,b=0;for(let j=0;j<M;j++){const an=TAU*k*j/M;a+=x[j]*Math.cos(an);b+=x[j]*Math.sin(an);}re[k]=a*2/M;im[k]=b*2/M;}
  waveCache.set(key,ctx.createPeriodicWave(re,im));}return waveCache.get(key);}
/* Eine Grundwelle. EDIT1 formt wie bei der EMX: SAW 0 = Sägezahn … 127 = Rechteck, PULSE = Pulsbreite (127 = still), TRI 127 = Oktave + Quinte höher, SIN = mehr Obertöne */
function emxWave(kind,q,f,gr,dest,vol,srcs,det=0){
  if(kind==='NS'||kind==='NOISE'){const n=ctx.createBufferSource();n.buffer=E.noise;n.loop=true;const g=gainN(vol*.6);n.connect(g);g.connect(dest);srcs.push({node:n,kind:'noise'});return null;}
  const o=ctx.createOscillator();q=Math.round(clamp(q)*24)/24;
  if(kind==='SAW')o.setPeriodicWave(pwave('saw'+q,n=>(n%2?1+q:1-q)/n));
  else if(kind==='PULSE')o.setPeriodicWave(pulseWave(Math.max(.012,.5*(1-q))));
  else o.type=kind==='TRI'?'triangle':kind==='SIN'?'sine':'square';
  o.frequency.value=f;o.detune.value=det+gr;let s=o;
  if((kind==='TRI'||kind==='SIN')&&q>.01){const w=ctx.createWaveShaper(),k=kind==='TRI'?1+q*2:1+q*3;w.curve=kind==='TRI'?ccurve('tf'+k,x=>Math.asin(Math.sin(Math.PI/2*x*k))):ccurve('sf'+k,x=>Math.sin(x*k*Math.PI/2));s.connect(w);s=w;}
  const g=gainN(vol);s.connect(g);g.connect(dest);srcs.push({node:o,kind:'osc',det});return o;}
/* Kammfilter (COMB, PCM+COMB, AUDIO IN+COMB). Rückkopplung braucht mind. einen Audio-Block Verzögerung -> bei hohen Tönen ein Vielfaches der Periode */
function emxComb(src,out,f,fb,lvl){fb=clamp(fb);const d=ctx.createDelay(.25),g=gainN(fb*.96),wet=gainN(fb*1.1),o=gainN(lvl/(1+fb*.55)),L=1/Math.max(20,f),minD=(160/ctx.sampleRate)+LOOPC,m=Math.max(1,Math.ceil(minD/L));
  d.delayTime.value=loopDT(m*L);src.connect(o);src.connect(d);d.connect(g);g.connect(d);d.connect(wet);wet.connect(o);o.connect(out);}   // Feedback 0 = reiner Ton (wie EMX)
function emxOsc(P,t,freq,gr,out,srcs){
  const T=P.osc|0,e1=clamp(P.edit??0),e2=clamp(P.edit2??.5),W=emxWaves(T),wv=W[clamp(P.wave|0,0,W.length-1)]||'SAW';
  const W2=s=>s==='SQUARE'?'SQU':s;
  switch(T){
    case 1:{const g2=clamp(Math.abs((e2-.5)*126)/3);emxWave(wv,e1,freq,gr,out,.55,srcs);if(g2>0)emxWave(wv,e1,freq*semi(emxPm(e2)),gr,out,.55*g2,srcs);break;}   // WAVE FORM
    case 2:{const[a,b]=wv.split('+');emxWave(a,0,freq,gr,out,.72*(1-e1),srcs);emxWave(b,0,freq*semi(emxPm(e2)),gr,out,.72*e1,srcs);break;}                  // DUAL OSC: EDIT1 = Balance
    case 3:{const ch=EMX_CHORDS[Math.round(e1*15)][1].slice(),v=Math.round((e2-.5)*6);                                                                // CHORD: EDIT1 = Akkord, EDIT2 = Voicing
      for(let k=0;k<Math.abs(v);k++){if(v>0){ch.sort((x,y)=>x-y);ch[0]+=12;}else{ch.sort((x,y)=>y-x);ch[0]-=12;}}
      ch.forEach(s=>emxWave(W2(wv),0,freq*semi(s),gr,out,.3,srcs));break;}
    case 4:{const nO=+wv[0],kind=wv.slice(1),sp=3+e1*e1*48;for(let k=0;k<nO;k++){const off=(k/((nO-1)||1)-.5)*2*sp;                                 // UNISON: EDIT1 = Detune, EDIT2 = Osc1 Pitch
      emxWave(kind,0,k===0?freq*semi(emxPm(e2)):freq,gr,out,.75/Math.sqrt(nO),srcs,off);}break;}
    case 5:{const[a,b]=wv.split('+'),o1=gainN(1),dry=gainN(1-e1),ringIn=gainN(0),wet=gainN(e1*2.3);                                                    // RING MOD: EDIT1 = Mod Depth, EDIT2 = Mod Pitch
      emxWave(a,0,freq,gr,o1,.75,srcs);o1.connect(dry);o1.connect(ringIn);dry.connect(out);ringIn.connect(wet);wet.connect(out);emxWave(b,0,freq*semi(emxPm(e2)),gr,ringIn.gain,1,srcs);break;}
    case 6:{const r=Math.round(emxU(e2)*8)/8,q=Math.round(e1*12)/12,o=ctx.createOscillator(),g=gainN(.55);                                              // OSC SYNC: EDIT1 = Wellenform, EDIT2 = Mod Pitch
      o.setPeriodicWave(syncPW(wv,q,r));o.frequency.value=freq;o.detune.value=gr;o.connect(g);g.connect(out);srcs.push({node:o,kind:'osc',det:0});break;}
    case 7:{const[a,b]=wv.split('+'),c=emxWave(a,0,freq,gr,out,.65,srcs),mg=gainN(e1*e1*freq*6);emxWave(b,0,freq*semi(emxPm(e2)),gr,mg,1,srcs);if(c)mg.connect(c.frequency);break;} // CROSS MOD
    case 8:{const h=emxH(e2),c=emxWave(wv,0,freq,gr,out,.65,srcs),mg=gainN(e1*e1*freq*h*3.5);emxWave('SIN',0,freq*h,gr,mg,1,srcs);if(c)mg.connect(c.frequency);break;}   // VPM: EDIT2 = Harmonische
    case 9:{const mx=gainN(1),sh=ctx.createWaveShaper(),d=Math.round(e1*16)/16,ty=wv==='TYPE2'?2:1,g=gainN(.6);                                       // WS: EDIT1 = Wave Shape, EDIT2 = Osc2 Pitch
      sh.curve=ccurve('ws'+ty+d,ty===1?x=>Math.sin(x*(1+d*7)*Math.PI/2):x=>Math.tanh(x*(1+d*5))*.6+Math.sin(x*(1+d*10)*Math.PI)*d*.5);sh.oversample='2x';
      emxWave('SIN',0,freq,gr,mx,.5,srcs);emxWave('SIN',0,freq*semi(emxPm(e2)),gr,mx,.5,srcs);mx.connect(sh);sh.connect(g);g.connect(out);break;}
    case 10:{emxWave(wv,0,freq,gr,out,.45,srcs);emxWave(wv,0,freq*emxH(e1),gr,out,.33,srcs);emxWave(wv,0,freq*emxH(e2),gr,out,.27,srcs);break;}      // ADDITIVE: Osc2/3 als Harmonische
    case 11:{const s=gainN(1);emxWave(wv,0,freq,gr,s,.6,srcs);emxComb(s,out,freq*emxU(e2),e1,1.2);break;}                                            // COMB: EDIT1 = Feedback, EDIT2 = Comb Pitch
    case 12:{const s=gainN(1),sum=gainN(7.5),v=e1*(VOWELS.length-1.001),i0=Math.floor(v),fr=v-i0,A=VOWELS[i0],B=VOWELS[i0+1],sh=Math.pow(2,emxPm(e2)/24);  // FORMANT
      emxWave('SAW',0,freq,gr,s,.8,srcs);[0,1].forEach(k=>{const bp=biqN('bandpass',(A[k]+(B[k]-A[k])*fr)*sh,7+k*2),bg=gainN(k?.6:1);s.connect(bp);bp.connect(bg);bg.connect(sum);});sum.connect(out);break;}
    case 13:{const nz=ctx.createBufferSource(),c=(e2-.5)*2,lp=biqN('lowpass',freq,6),hp=biqN('highpass',freq,6),gl=gainN(clamp(.5-c/2)*2),gh=gainN(clamp(.5+c/2)*2);  // NOISE: EDIT1 = Rate, EDIT2 = Color
      nz.buffer=E.noise;nz.loop=true;nz.playbackRate.value=Math.pow(2,-e1*7);nz.connect(lp);nz.connect(hp);lp.connect(gl);hp.connect(gh);gl.connect(out);gh.connect(out);srcs.push({node:nz,kind:'noise'});break;}
    case 14:case 15:{const V=emxPcmVoice(P.wave|0,freq);if(!V)break;const rate=V.rate,bs=ctx.createBufferSource(),s=gainN(1);bs.buffer=V.buf;bs.playbackRate.value=rate;  // PCM-Typen: WAVE = EMX-PCM-Welle 1-76
      let off=Math.min(V.buf.duration*.95,(P.start||0)*V.buf.duration);if(V.le){bs.loop=true;bs.loopStart=V.ls;bs.loopEnd=V.le;off=Math.min(off,V.ls);}
      bs.connect(s);bs.start(t,off);srcs.push({node:bs,kind:'buf',base:rate,rate});
      if(T===14)emxComb(s,out,freq*emxU(e2),e1,.9);
      else{const sh=ctx.createWaveShaper(),d=Math.round(e1*16)/16,ch=Math.round(e2*8)/8,g=gainN(.85);sh.curve=ccurve('pw'+d+'|'+ch,x=>(1-ch)*Math.tanh(x*(1+d*8))+ch*Math.sin(x*(1+d*6)*Math.PI/2));sh.oversample='2x';s.connect(sh);sh.connect(g);g.connect(out);}
      break;}
    case 16:{if(!E.in)break;const s=gainN(1.4);E.in.out.connect(s);emxComb(s,out,freq*emxU(e2),e1,.9);                                                // AUDIO IN + COMB
      srcs.push({node:{start(){},stop(at){setTimeout(()=>{try{E.in.out.disconnect(s);}catch(e){}},Math.max(0,(at-now())*1000)+60);}},kind:'ext'});break;}
  }
}

/* ---------- Stimmen ---------- */
/* Filter: echte Resonanz (bis ca. 30 dB), EG ±9 Oktaven, Cutoff/Reso/EG wirken live auf klingende Töne */
const cutHzOf=P=>Math.min(20000,20*Math.pow(2,P.cut*10));
/* FILTER TRACK: Resonanz folgt dem Grundton des Sounds. CUTOFF = Abstand in Halbtönen (Mitte = genau auf dem Ton) */
const trackSemis=P=>(P.cut-.5)*48;
function toneHz(P,n){const S=SRC[P.src];if(P.src>0&&S&&S.f0)return S.f0*Math.pow(2,(P.pitch+n-57)/12);return 440*Math.pow(2,(n+P.pitch-69)/12);}
function setTrack(P,on){if(on===P.ftrack)return;const f=voiceCut(P,57);P.ftrack=on;P.cut=on?.5:clamp(Math.log2(f/20)/10);}
function voiceCut(P,n){return P.ftrack?clamp(toneHz(P,n)*Math.pow(2,trackSemis(P)/12),20,20000):cutHzOf(P);}
/* Grundton eines Samples messen (Autokorrelation, 30-500 ms, auf 12 kHz verkleinert). 0 = kein klarer Ton */
function detectF0(buf){try{const sr=buf.sampleRate,d=buf.getChannelData(0),dec=Math.max(1,Math.round(sr/12000)),fs=sr/dec,a0=Math.floor(.03*sr),a1=Math.min(d.length,Math.floor(.5*sr));
  const x=[];for(let k=a0;k<a1;k+=dec)x.push(d[k]);const N=x.length;if(N<200)return 0;let e0=0;for(const v of x)e0+=v*v;if(e0<1e-6)return 0;
  const lo=Math.floor(fs/1000),hi=Math.min(Math.floor(fs/25),Math.floor(N/2));const r=new Float32Array(hi+1);
  for(let L=lo;L<=hi;L++){let s=0,e1=0,e2=0;for(let k=0;k+L<N;k++){s+=x[k]*x[k+L];e1+=x[k]*x[k];e2+=x[k+L]*x[k+L];}r[L]=s/Math.sqrt(e1*e2+1e-12);}
  let mx=0;for(let L=lo;L<=hi;L++)mx=Math.max(mx,r[L]);if(mx<.6)return 0;
  for(let L=lo+1;L<hi;L++)if(r[L]>=mx*.9&&r[L]>=r[L-1]&&r[L]>=r[L+1]){const y0=r[L-1],y1=r[L],y2=r[L+1],p=.5*(y0-y2)/(y0-2*y1+y2||1);return fs/(L+p);}
  return 0;}catch(e){return 0;}}
function filterChain(P,t,att,dec,src,note=57){
  /* EG INT wie Electribe: derselbe EG wie die Lautstärke. Cutoff startet am Grundwert, steigt im ATTACK um EG INT und fällt im DECAY zurück */
  const ty=FILTERS[P.ftype],cutHz=voiceCut(P,note),egOct=(P.eg-.5)*18,peak=clamp(cutHz*Math.pow(2,egOct),20,20000),holdEG=P.egOn&&P.dec>.97,fd=dec/3;
  const fc={st:[],list:[],ty,out:null,cg:null,comb:null,form:null,n:note,cut:cutHz,peak,t,att,fd,eg:Math.abs(egOct)>.01,holdEG};let n=src;
  const add=(type,share,mul=1)=>{const f=ctx.createBiquadFilter(),fr=f.frequency;f.type=type;fr.setValueAtTime(cutHz*mul,t);
    if(fc.eg){fr.exponentialRampToValueAtTime(clamp(peak*mul,20,20000),t+att);if(!holdEG)fr.setTargetAtTime(cutHz*mul,t+att,fd);}n.connect(f);n=f;fc.list.push(f);fc.st.push({f,share,type,mul});return f;};
  const shp=(k,os='2x')=>{const w=ctx.createWaveShaper();w.curve=curve(x=>Math.tanh(k*x));w.oversample=os;n.connect(w);n=w;};
  const par=(a,b)=>{const inp=n,sum=gainN(1);[a,b].forEach(([type,share,mul])=>{n=inp;add(type,share,mul);n.connect(sum);});n=sum;};
  switch(ty){
    case 'LPF 24':add('lowpass',.62);add('lowpass',.38);break;
    case 'LPF 12':add('lowpass',1);break;
    case 'LPF 36':add('lowpass',.5);add('lowpass',.3);add('lowpass',.2);break;
    case 'HPF 24':add('highpass',.62);add('highpass',.38);break;
    case 'HPF 12':add('highpass',1);break;
    case 'BPF 12':add('bandpass',1);break;
    case 'BPF 24':add('bandpass',.7);add('bandpass',.7);break;
    case 'NOTCH':add('notch',1);break;
    case 'PEAK':add('peaking',1);break;
    case 'LADDER LP':shp(1.6);add('lowpass',.6);add('lowpass',.4);{const ls=biqN('lowshelf',150);ls.gain.value=P.reso*8;n.connect(ls);n=ls;}break;
    case 'ACID LP':add('lowpass',.62);add('lowpass',.38);shp(1.8);break;
    case 'MS-20 LP':add('lowpass',1);shp(1+P.reso*4);break;
    case 'MS-20 HP':add('highpass',1);shp(1+P.reso*4);break;
    case 'FORMANT':{const sum=gainN(1.6);fc.form=[0,1,2].map(k=>{const b=biqN('bandpass',800,6+k*3);n.connect(b);b.connect(sum);return b;});n=sum;break;}
    case 'COMB':{const dl=ctx.createDelay(.1),fb=gainN(.5),sum=gainN(1);n.connect(sum);n.connect(dl);dl.connect(fb);fb.connect(dl);dl.connect(sum);n=sum;fc.comb={dl,fb};break;}
    case 'LPF 6':add('lowpass',.35);break;
    case 'LPF 18':add('lowpass',.55);add('lowpass',.45,1.15);break;
    case 'HPF 6':add('highpass',.35);break;
    case 'HPF 36':add('highpass',.5);add('highpass',.3);add('highpass',.2);break;
    case 'BPF 6':add('bandpass',.4);break;
    case 'NOTCH 24':add('notch',.7);add('notch',.7,1.06);break;
    case 'E-LPF DRIVE':shp(1.3);add('lowpass',.6);add('lowpass',.4);shp(1.2);break;
    case 'P-5 LPF':add('lowpass',.55);add('lowpass',.45);{const ls=biqN('lowshelf',120);ls.gain.value=-P.reso*4;n.connect(ls);n=ls;}break;
    case 'POLY-6 LPF':add('lowpass',.6);add('lowpass',.4);shp(1.5);break;
    case 'MG LADDER':shp(1.3);add('lowpass',.55);add('lowpass',.45);{const ls=biqN('lowshelf',180);ls.gain.value=P.reso*10;n.connect(ls);n=ls;}shp(1.1);break;
    case 'OB SVF LP':add('lowpass',.8);break;
    case 'OB SVF BP':add('bandpass',.8);break;
    case 'OB SVF HP':add('highpass',.8);break;
    case 'DIODE 303':add('lowpass',.45);add('lowpass',.35);add('lowpass',.2,1.3);shp(2);break;
    case 'JUNO LPF':add('lowpass',.5);add('lowpass',.5);{const hp=biqN('highpass',60);n.connect(hp);n=hp;}break;
    case 'SEM NOTCH':par(['lowpass',.6,1],['highpass',.6,1]);break;
    case 'DUAL PEAK':add('peaking',.6);add('peaking',.6,2.5);break;
    case 'LP+HP':add('highpass',.4,.25);add('lowpass',.7);break;
    case 'LPF DRIVE':shp(2.4);add('lowpass',.6);add('lowpass',.4);break;
    case 'HPF DRIVE':shp(2.4);add('highpass',.6);add('highpass',.4);break;
  }
  fc.cg=gainN(1);n.connect(fc.cg);fc.out=fc.cg;qApply(fc,P,t);return fc;
}
/* Resonanz: bis ca. 30 dB. Bei sehr tiefem Cutoff wird die Ausschwingzeit begrenzt (sonst schwillt der Bass an und schwebt).
   Die Grenze folgt dem Filter-EG: Beim Sweep nach oben darf es voll pfeifen, unten bleibt der Bass trotzdem stabil. */
const RING=.045;
const qCapDb=f=>20*Math.log10(Math.max(.75,Math.PI*Math.max(20,f)*RING));
function qApply(fc,P,t){
  const r=P.reso,acid=fc.ty==='ACID LP'||fc.ty==='DIODE 303',lin=Math.max(.75,Math.PI*Math.max(20,fc.cut)*RING);let qSum=0;
  fc.st.forEach(s=>{const f=s.f,base=fc.cut*s.mul,pk=fc.peak*s.mul;
    if(s.type==='bandpass'||s.type==='notch'){f.Q.value=Math.min(Math.max(.75,Math.PI*base*RING),.7+r*r*30*s.share);}
    else if(s.type==='peaking'){f.Q.value=Math.min(Math.max(.75,Math.PI*base*RING),1+r*14);f.gain.value=6+r*16;}
    else{const want=Math.pow(r,1.3)*(acid?38:30)*s.share,q0=Math.min(want,qCapDb(base)),q1=Math.min(want,qCapDb(pk));qSum+=q0;
      if(fc.eg&&t<=fc.t+fc.att+.001&&Math.abs(q1-q0)>.3){f.Q.cancelScheduledValues(0);f.Q.setValueAtTime(q0,fc.t);f.Q.linearRampToValueAtTime(q1,fc.t+fc.att);if(!fc.holdEG)f.Q.setTargetAtTime(q0,fc.t+fc.att,fc.fd);}
      else{hold(f.Q,t);f.Q.setTargetAtTime(q0,t,.01);}}});
  if(fc.form){const v=P.cut*(VOWELS.length-1.001),i0=Math.floor(v),fr=v-i0,A=VOWELS[i0],B=VOWELS[i0+1];fc.form.forEach((b,k)=>{b.frequency.setTargetAtTime(A[k]+(B[k]-A[k])*fr,t,.02);b.Q.value=4+k*3+r*20;});}
  if(fc.comb){fc.comb.dl.delayTime.setTargetAtTime(loopDT(1/clamp(fc.cut,40,4000)),t,.02);fc.comb.fb.gain.value=.2+r*.75;}
  const qdb=acid?qSum*30/38:qSum,bp=fc.st.length&&(fc.st[0].type==='bandpass'||fc.st[0].type==='peaking'||fc.st[0].type==='notch');
  /* Lautstärke-Ausgleich nur teilweise: Reso darf den Bass fetter machen wie bei Korg, Spitzen fängt der Limiter */
  fc.cg.gain.setTargetAtTime(bp||fc.form||fc.comb?1/(1+r*r*1.8):Math.pow(10,-(qdb*(acid?.42:.3)+(fc.ty==='LADDER LP'||fc.ty==='MG LADDER'?r*5:0))/20),t,.02);
}
function liveFilter(i){if(!E)return;const P=cur.parts[i],t=now();
  E.voices.forEach(v=>{if(v.part!==i||v.dead||!v.fc)return;const f=voiceCut(P,v.fc.n);v.fc.cut=f;v.fc.peak=f;v.fc.eg=false;v.fc.st.forEach(s=>{hold(s.f.frequency,t);s.f.frequency.setTargetAtTime(clamp(f*s.mul,20,20000),t,.012);});qApply(v.fc,P,t);});}
const GATES=[.25,.5,.75,1,1.5,2,3,4,6,8,12,16,24,32,48,64];
const gateSteps=dec=>GATES[Math.round(clamp(dec)*15)];
function partNote(P,note){return note+P.oct*12+P.tr;}
/* opts: gate (Sekunden) · held (klingt bis Note-Off) · rev · id */
const MAXV=32;
/* VOICE ASSIGN wie Electribe 2: MONO 1 = Legato (solange der alte Ton klingt, kein EG-Neustart, Tonhöhe gleitet), MONO 2 = jeder Ton startet neu und schneidet den alten,
   POLY 1 = bis 4 Stimmen, gemeinsamer EG (kein neuer Attack solange Töne klingen), POLY 2 = bis 4 Stimmen, jeder Ton mit eigenem EG */
function legato(v,t,n,opts,P){const gt=P&&P.glide>.01?.01+P.glide*P.glide*.6:.012;const f=Math.pow(2,(n-v.note)/12);v.note=n;if(opts.id)v.id=opts.id;if(opts.held)v.held=true;
  /* SUSTAIN-Ton: Legato verlängert den Ton, Release kommt erst am Ende des neuen Tons */
  if(v.sus){const tOff=opts.held?null:t+(opts.gate??stepLen());hold(v.amp.gain,t);v.amp.gain.setTargetAtTime(v.susLvl,t,.04);v.off=tOff??undefined;v.end=tOff?tOff+v.relTau*5.4:t+30;if(tOff)v.amp.gain.setTargetAtTime(0,tOff,v.relTau);v.srcs.forEach(s=>{try{s.node.stop(v.end+.06);}catch(e){}});try{v.tk.stop(v.end+.08);}catch(e){}}
  v.srcs.forEach(s=>{if(s.kind==='buf'){s.rate*=f;hold(s.node.playbackRate,t);s.node.playbackRate.setTargetAtTime(s.rate,t,gt);}else if(s.kind==='osc'&&s.f0){s.f0*=f;hold(s.node.frequency,t);s.node.frequency.setTargetAtTime(s.f0,t,gt);}});}
function voice(i,t,note,vel,opts={}){
  if(!E)return null;const P=cur.parts[i],c=E.ch[i],S=SRC[P.src];
  const sOn=P.src>0&&S&&S.buf,oOn=P.osc>0;if(!sOn&&!oOn)return null;
  const pfx=P.fx.find(f=>f.on&&f.type===FX_PSHIFT),pShift=pfx?Math.round((pfx.edit-.5)*24):0,tape=P.fx.find(f=>f.on&&f.type===FX_TSTOP);
  const n=partNote(P,note)+pShift,gr=1200*Math.log2(E.gRate[i]),VA=P.voice??0,live=v=>!v.dead&&!v.rel;
  const sameSrc=v=>v.src===P.src&&v.osc===P.osc;
  if(VA===0&&!opts.noLegato){const lv=E.voices.find(v=>v.part===i&&live(v)&&v.t0<t-.002&&t<(v.off??v.end)-.03&&sameSrc(v));if(lv){legato(lv,t,n,opts,P);E.lastNote[i]=n;E.partHit[i]=t;return lv;}}
  if(VA<=1)E.voices.forEach(v=>{if(v.part===i&&live(v)&&v.t0<t-.002)releaseVoice(v,t,.008);});
  const sharedEG=VA===2&&E.voices.some(v=>v.part===i&&live(v)&&v.t0<t-.002&&t<v.end);
  if(VA>=2){const mine=E.voices.filter(v=>v.part===i&&live(v));if(mine.length>=4)releaseVoice(mine[0],t,.006);}
  if(P.choke)E.voices.forEach(v=>{if(v.part!==i&&live(v)&&cur.parts[v.part].choke===P.choke)releaseVoice(v,t,.006);});
  /* ALTERNATE 21-22 / 23-24: die beiden Pads schneiden sich gegenseitig */
  const alt=(cur.alt2122&&(i===20||i===21))?41-i:(cur.alt2324&&(i===22||i===23))?45-i:-1;if(alt>=0)E.voices.forEach(v=>{if(v.part===alt&&live(v))releaseVoice(v,t,.006);});
  /* PART PRIORITY: sind alle Stimmen belegt, wird zuerst eine Stimme eines normalen Parts beendet */
  {const all=E.voices.filter(live);if(all.length>=MAXV){const low=all.filter(v=>!cur.parts[v.part].prio);releaseVoice((low.length?low:all)[0],t,.005);}}
  const egOn=P.egOn,att=sharedEG?.003:egOn?.0015+P.att*P.att*1.5:.002,dec=.03+P.dec*P.dec*3.5,holdEnv=egOn&&P.dec>.97,g=clamp(vel)*.95,mix=gainN(1),amp=gainN(0),srcs=[];
  const gS=sOn?(oOn?Math.cos(P.blend*Math.PI/2):1):0,gO=oOn?(sOn?Math.sin(P.blend*Math.PI/2):1):0,M=modInfo(P.mtype),egT=modEgT(P),dp=P.depth,egM=M&&M.eg&&dp>.005?M:null;
  if(M&&M.key&&!M.eg&&dp>.005)setLfoWave(c,LFOW[M.src],lfoRate(P),t,M.sign,true);
  let sEnd=Infinity;
  if(sOn){const pb=playBuf(i);if(pb){const buf=opts.rev&&!pb.baked?revBuf(S):pb.buf,semis=(pb.baked?0:P.pitch)+(n-57)+(P.tune||0)/100,rate=Math.pow(2,semis/12)*E.gRate[i];
    const bs=ctx.createBufferSource(),sg=gainN(gS*(P.smpLvl??1));bs.buffer=buf;bs.playbackRate.setValueAtTime(rate,t);bs.connect(sg);sg.connect(mix);
    const D=buf.duration,off=Math.min(D*.95,P.start*D),endT=Math.max(off+.005,Math.min(D,(P.smpEnd??1)*D));
    if(P.loopOn){bs.loop=true;bs.loopStart=off+(endT-off)*(P.loopStart||0);bs.loopEnd=endT;bs.start(t,off);}else{bs.start(t,off,endT-off);sEnd=t+(endT-off)/rate;}
    srcs.push({node:bs,kind:'buf',base:rate/E.gRate[i],rate});
    /* OSC EDIT bei Samples = PUNCH: kurzer Tonhöhen-Kick am Anfang (Kick wird knackiger, Clap zappt, Bass gleitet rein) */
    if(P.edit>.01){bs.playbackRate.setValueAtTime(rate*Math.pow(2,P.edit*P.edit*36/12),t);bs.playbackRate.setTargetAtTime(rate,t,.006+(1-P.edit)*.03);}
    if(tape)bs.playbackRate.setTargetAtTime(.04,t+.01,.05+(1-tape.edit)*.4);}}
  if(oOn){const og=gainN(gO),fq=440*Math.pow(2,(n+P.pitch-69)/12);og.connect(mix);const k0=srcs.length;emxOsc(P,t,fq,gr,og,srcs);
    srcs.slice(k0).forEach(s=>{if(s.kind==='osc')s.f0=s.node.frequency.value;});
    if(tape)srcs.slice(k0).filter(s=>s.kind==='osc').forEach(s=>s.node.detune.setTargetAtTime(-2400,t+.01,.05+(1-tape.edit)*.4));}
  /* GLIDE: der neue Ton gleitet von der vorigen Tonhöhe (Pitch/Glide wie Electribe 2) */
  const pv=E.lastNote[i];E.lastNote[i]=n;
  if(P.glide>.01&&pv!=null&&pv!==n&&VA<=1){const tau=.01+P.glide*P.glide*.6;srcs.forEach(s=>{if(s.kind==='buf'||s.kind==='osc'){const p=s.node.detune,d0=s.kind==='osc'?(s.det||0)+gr:0;p.setValueAtTime(d0+(pv-n)*100,t);p.setTargetAtTime(d0,t,tau);}});}
  /* EG-Modulation pro Ton (Electribe 2: EG+ / EG- auf Filter, Pitch, OSC, Level, Pan, IFX). Kurzer Anstieg, dann Abfall mit SPEED-Zeit */
  const egA=Math.min(.02,egT*.1),egS=egM?egM.sign:1,egOn2=k=>egM&&egM.dst===k,egApply=(p,base,peak)=>{p.setValueAtTime(base,t);p.linearRampToValueAtTime(base+peak,t+egA);p.setTargetAtTime(base,t+egA,egT);};
  if(egOn2('PITCH'))srcs.forEach(s=>{if(s.kind==='buf'||s.kind==='osc')egApply(s.node.detune,s.kind==='osc'?(s.det||0)+gr:0,egS*dp*2400);});
  /* OSC-Ziel: Klangfarbe des Oszillators/Samples (Präsenz-Band) wird moduliert */
  let tone=null,fin=mix;const oscMod=M&&M.dst==='OSC'&&dp>.005;if(oscMod){tone=biqN('peaking',1800,.8);tone.gain.value=0;mix.connect(tone);fin=tone;if(egOn2('OSC'))egApply(tone.gain,0,egS*dp*18);else c.lfoO.connect(tone.gain);}
  const fc=filterChain(P,t,att,dec,fin,n);let vm=null;
  /* DRUCK (SHIFT + OSC EDIT): Sub-Sinus unter dem Grundton, Tonhöhen-Kick, Klick-Transient und Sättigung – der Bass drückt und kracht */
  let post=fc.out,dkTap=null;const dk=P.druck||0;
  if(dk>.01){const fq0=oOn?440*Math.pow(2,(n+P.pitch-69)/12):sOn&&S.f0?toneHz(P,n):0,din=gainN(1),sh=ctx.createWaveShaper(),dc=biqN('highpass',22,.6),mk=gainN(.9),sum=gainN(1);fc.out.connect(din);
    /* Bass: Mitten-Biss + asymmetrische Sättigung (auch gerade Obertöne) = Knurren und Krachen */
    const bite=biqN('peaking',1000,.7);bite.gain.value=dk*12;sh.curve=druckCurve(1+dk*5);sh.oversample='2x';din.connect(sh);sh.connect(bite);bite.connect(mk);mk.connect(sum);
    /* Sub-Sinus sauber daneben (sonst frisst er die Verzerrung), nur leicht angedickt */
    if(fq0){let f=fq0;while(f>130)f/=2;const so=ctx.createOscillator(),sg=gainN(dk*.6),ss=ctx.createWaveShaper();ss.curve=druckCurve(1.6);so.frequency.value=f;so.detune.value=gr;so.connect(sg);sg.connect(ss);ss.connect(sum);srcs.push({node:so,kind:'osc',det:0,f0:f});}
    const nz=ctx.createBufferSource(),hp=biqN('highpass',1800),ng=gainN(0);nz.buffer=E.noise;nz.connect(hp);hp.connect(ng);ng.connect(sum);ng.gain.setValueAtTime(dk*.35,t);ng.gain.setTargetAtTime(0,t,.004);srcs.push({node:nz,kind:'noise'});
    /* Pegelausgleich (druckAutoGain): gleich laut wie ohne DRUCK */
    const vg=gainN(0);c.dkC.connect(vg.gain);fc.out.connect(c.dkRef);sum.connect(dc);dc.connect(c.dkOut);dc.connect(vg);post=vg;dkTap=[fc.out,dc,vg]; // asymmetrische Sättigung braucht den DC-Filter danach
    if(!(P.glide>.01)&&!egOn2('PITCH'))srcs.forEach(s=>{if(s.kind==='osc'){const p=s.node.detune,b=p.value;p.setValueAtTime(b+dk*1500,t);p.setTargetAtTime(b,t,.008+dk*.012);}});}
  if(egOn2('LEVEL')){vm=gainN(1);post.connect(amp);amp.connect(vm);vm.connect(c.inp);egApply(vm.gain,1,egS*dp);} // EG+ = Anschlag lauter (bis 2x), EG- = Anschlag leiser
  else{post.connect(amp);amp.connect(c.inp);}
  if(egOn2('FILTER'))fc.list.forEach(f=>egApply(f.detune,0,egS*dp*4800));
  if(egOn2('PAN')){const base=(P.pan-.5)*2,pp=c.pan.pan;hold(pp,t);pp.setValueAtTime(clamp(base+egS*dp,-1,1),t);pp.setTargetAtTime(base,t+egA,egT);}
  /* Resonanz schwingt nach dem Sample-Ende weiter: Ausklingzeit aus Güte und Frequenz */
  const ql=Math.pow(10,Math.pow(P.reso,1.3)*30/20),tail=FILTERS[P.ftype]==='OFF'?.02:clamp(4*ql/(Math.PI*Math.max(20,fc.cut)),.02,1.5);
  /* ANALOG DRIFT: jede Stimme minimal anders (Oszillator-Stimmung, Cutoff, Pegel) wie bei analogen Geräten */
  if(G.analog>.01){const a=G.analog,rd=()=>Math.random()-.5;if(oOn)srcs.forEach(s=>{if(s.kind==='osc')s.node.detune.value+=rd()*a*12;});fc.list.forEach(f=>{f.detune.value+=rd()*a*140;});}
  const lfoP=srcs.filter(s=>s.kind==='buf'||s.kind==='osc').map(s=>s.node.detune);
  fc.list.forEach(f=>c.lfoF.connect(f.detune));lfoP.forEach(p=>c.lfoPi.connect(p));
  const gA=G.analog>.01?g*(1+(Math.random()-.5)*G.analog*.12):g;amp.gain.setValueAtTime(0,t);amp.gain.linearRampToValueAtTime(gA,t+att);
  let end,envF=null;const egSus=egOn&&!holdEnv?(P.egS||0):0,relT=egRelT(P),adv=egOn&&egAdv(P);
  if(!egOn){const gt=opts.held?30:(opts.gate??gateSteps(P.dec)*stepLen());end=Math.min(t+gt,oOn?Infinity:sEnd+tail);
    if(!opts.held){amp.gain.setValueAtTime(g,Math.max(t+att,end-.006));amp.gain.linearRampToValueAtTime(0,end);}}
  /* Erweiterte AMP EG (Touch-Display): DELAY, ATTACK, HOLD, DECAY, SUSTAIN, RELEASE mit eigenen Kurven */
  else if(adv){const AL=P.egAL??1,dl=egDlT(P),hd=egHT(P),dc=(.03+P.dec*P.dec*3.5)*1.2,S=holdEnv?AL:(P.egS||0),DL=holdEnv?AL:(P.egDL??S),st=Math.max(.005,egSTT(P)),R=S>.005?relT:.012,kA=egK.a(P),kD=egK.d(P),kR=egK.r(P),a0=t+dl,a1=a0+Math.max(.002,att),h1=a1+hd+1e-4,d1=h1+dc,s1=d1+1e-4+st;
    /* Punkte wie im Plan: ATTACK (Zeit, Pegel AL) -> HOLD -> DECAY (Zeit, Pegel DL) -> SUSTAIN (Zeit bis dahin, Pegel S) -> RELEASE (Zeit, Kurve) */
    const lv=x=>x<a0?0:x<a1?gA*AL*egShp(kA,(x-a0)/(a1-a0)):x<h1?gA*AL:x<d1?gA*(AL-(AL-DL)*egShp(kD,(x-h1)/dc)):x<s1?gA*(DL+(S-DL)*clamp((x-d1)/st)):gA*S;
    amp.gain.cancelScheduledValues(t);amp.gain.setValueAtTime(0,t);egSeg(amp.gain,a0,a1-a0,0,gA*AL,kA);if(Math.abs(AL-DL)>.001)egSeg(amp.gain,h1,dc,gA*AL,gA*DL,kD);if(Math.abs(DL-S)>.001)egSeg(amp.gain,d1+1e-4,st,gA*DL,gA*S,0);
    const tOff=opts.held?null:S>.005?t+(opts.gate??stepLen()):(P.rel===CUT&&opts.gate!=null?t+opts.gate:null);
    if(tOff){hold(amp.gain,tOff);egSeg(amp.gain,tOff+.001,R,lv(tOff),0,kR);end=tOff+R+.004;}else end=S>.005?t+30:s1+.004;
    if(!oOn&&!P.loopOn)end=Math.min(end,sEnd+tail);envF={lv,R,k:kR};}
  else if(holdEnv){end=opts.held?t+30:Math.min(sOn&&!oOn?sEnd+tail:t+(opts.gate??60/G.bpm),t+30);if(!opts.held){amp.gain.setValueAtTime(g,Math.max(t+att,end-.015));amp.gain.linearRampToValueAtTime(0,end);}}
  /* SUSTAIN + RELEASE (Touchpad AMP EG): nach dem Decay bleibt der Pegel auf SUSTAIN, bis der Ton endet, dann RELEASE */
  else if(egSus>.005){const tOff=opts.held?null:Math.max(t+att,t+(opts.gate??stepLen()));amp.gain.setTargetAtTime(gA*egSus,t+att,dec/3);
    if(tOff){amp.gain.setTargetAtTime(0,tOff,relT/3);end=tOff+relT*1.8;}else end=t+30;if(!oOn&&!P.loopOn)end=Math.min(end,sEnd+tail);}
  else{amp.gain.setTargetAtTime(0,t+att,dec/3);end=Math.min(t+att+dec*1.8,oOn?Infinity:sEnd+tail);}
  if(!opts.held&&opts.gate!=null&&egOn&&!adv&&!holdEnv&&!(egSus>.005)&&P.rel===CUT&&t+opts.gate<end){hold(amp.gain,t+opts.gate);amp.gain.setTargetAtTime(0,t+opts.gate,.012);end=t+opts.gate+.08;}
  if(!isFinite(end))end=t+4;
  if(!opts.held){if(adv)hold(amp.gain,end);amp.gain.setTargetAtTime(0,end,.006);}
  srcs.forEach(s=>{if(s.kind!=='buf')s.node.start(t);s.node.stop(end+.06);});
  /* Abbau erst, wenn der Ausklang wirklich still ist (nicht beim Sample-Ende, sonst Klick) */
  const tk=ctx.createConstantSource();tk.offset.value=0;tk.start(t);tk.stop(end+.08);
  const v={part:i,t0:t,id:opts.id,note:n,src:P.src,osc:P.osc,srcs,amp,end,fc,tk,held:!!opts.held,cut:!egOn||P.rel===CUT||holdEnv||egSus>.005,relTau:egSus>.005?relT/3:.012,sus:egSus>.005,susLvl:gA*egSus,env:envF,off:egSus>.005&&!opts.held?Math.max(t+att,t+(opts.gate??stepLen())):undefined};E.voices.push(v);
  tk.onended=()=>{fc.list.forEach(f=>{try{c.lfoF.disconnect(f.detune);}catch(e){}});lfoP.forEach(p=>{try{c.lfoPi.disconnect(p);}catch(e){}});if(tone&&!egOn2('OSC'))try{c.lfoO.disconnect(tone.gain);}catch(e){}
    try{amp.disconnect();}catch(e){}if(vm)try{vm.disconnect();}catch(e){}if(dkTap){try{dkTap[0].disconnect(c.dkRef);}catch(e){}try{dkTap[1].disconnect(c.dkOut);}catch(e){}try{c.dkC.disconnect(dkTap[2].gain);}catch(e){}}v.dead=true;};
  if(E.voices.length>200)E.voices=E.voices.filter(x=>!x.dead);
  E.partHit[i]=t;return v;
}
/* RELEASE-Zeit der AMP EG (Touchpad): 5 ms bis 3 s */
const egRelT=P=>.005+Math.pow(P.egR??.15,2)*3;
/* Erweiterte AMP EG: Kurvenform (k=0 gerade, >0 schnell/knackig, <0 langsam), DELAY/HOLD bis 1 s */
const egShp=(k,u)=>Math.abs(k)<.01?u:(1-Math.exp(-k*u))/(1-Math.exp(-k));
const egK={a:P=>((P.egCA??.5)-.5)*12,d:P=>((P.egCD??.5)-.2)*16,r:P=>((P.egCR??.5)-.2)*16};
const egDlT=P=>Math.pow(P.egDl||0,2),egHT=P=>Math.pow(P.egH||0,2);
const egSTT=P=>Math.pow(P.egST||0,2)*2;                 // SUSTAIN-Regler (X): Zeit vom Decay-Pegel zum Sustain-Pegel, 0-2 s
const egAdv=P=>(P.egDl||0)>.005||(P.egH||0)>.005||['egCA','egCD','egCR'].some(k=>Math.abs((P[k]??.5)-.5)>.02)||(P.egAL??1)<.995||(P.egDL!=null&&Math.abs(P.egDL-(P.egS||0))>.005)||(P.egST||0)>.005;
function egSeg(p,t0,dur,a,b,k){const N=64,c=new Float32Array(N);for(let i=0;i<N;i++)c[i]=a+(b-a)*egShp(k,i/(N-1));p.setValueCurveAtTime(c,t0,Math.max(.002,dur));}
const DRK=new Map();
function druckCurve(k){const q=Math.round(k*4)/4;if(!DRK.has(q))DRK.set(q,curve(x=>Math.tanh(x*q+.25)-Math.tanh(.25)));return DRK.get(q);}
function releaseVoice(v,t,tau=.012){if(v.dead||v.rel)return;v.rel=true;hold(v.amp.gain,t);v.amp.gain.setTargetAtTime(0,t,tau);v.srcs.forEach(s=>{try{s.node.stop(t+tau*8+.02);}catch(e){}});try{v.tk.stop(t+tau*8+.06);}catch(e){}}
function noteOff(i,id,t){if(!E)return;E.voices.forEach(v=>{if(v.part===i&&v.id===id&&v.held){v.held=false;v.off=t;if(v.cut&&v.env&&!v.rel){v.rel=true;const L=v.env.lv(t);hold(v.amp.gain,t);egSeg(v.amp.gain,t+.001,v.env.R,L,0,v.env.k);v.srcs.forEach(s=>{try{s.node.stop(t+v.env.R+.05);}catch(e){}});try{v.tk.stop(t+v.env.R+.08);}catch(e){}}else if(v.cut)releaseVoice(v,t,v.relTau||.012);else v.srcs.forEach(s=>{try{s.node.stop(Math.max(t,v.end)+.06);}catch(e){}});}});}
function panic(){if(!E)return;const t=now();E.voices.forEach(v=>releaseVoice(v,t,.005));E.voices=[];}
function setPartRate(target,tc,parts){
  const t=now();E.voices=E.voices.filter(v=>!v.dead&&(v.end>t||v.held));
  parts.forEach(p=>E.gRate[p]=target);
  E.voices.forEach(v=>{if(!parts.includes(v.part))return;v.srcs.forEach(s=>{if(s.kind==='buf')s.node.playbackRate.setTargetAtTime(s.base*target,t,tc);else if(s.kind==='osc')s.node.detune.setTargetAtTime(s.det+1200*Math.log2(Math.max(.01,target)),t,tc);});});
}
function duck(src,t){for(let q=0;q<PARTS.length;q++){const P=cur.parts[q];if(q===src||P.sc<.01||P.scSrc!==src)continue;const p=E.ch[q].sc.gain;hold(p,t);p.setTargetAtTime(1-P.sc*.85,t,.003);p.setTargetAtTime(1,t+.018,.03+G.scRel*.18);}}

