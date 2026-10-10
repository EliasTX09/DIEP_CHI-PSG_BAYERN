/* ---------- Sequencer ---------- */
const seq={next:0,step:0},visQ=[];let rollSet=null,br=null,kbShift=false;
const PADVEL=100/127;
const curBar=()=>Math.floor(ui.dispStep/16);
const patStr=(n=ui.pattern)=>'A.'+pad3(n);
const patName=(n=ui.pattern)=>n===ui.pattern&&cur&&cur.name?cur.name:PATNAMES[(n-1)%PATNAMES.length];
/* BEAT (16, 32, 8 TRI, 16 TRI) und SWING gehören zum Pattern. LAST STEP pro Part = eigene Loop-Länge (Polymetrik) */
function stepDur(s){const b=stepLen(),sw=(cur.beat||0)<2?(cur.swing-.5)*.6:0;return s%2===0?b*(1+sw):b*(1-sw);}
const pStep=(p,s)=>{const L=cur.parts[p].lastStep;return L?s%L:s;};
/* TRIGGER-Modus: solange ein Pad gehalten wird, spielt nur das Pad, die Sequenz dieses Parts pausiert */
const trigHeld=p=>{for(const h of ui.held.values())if(h.trigPart===p)return true;return false;};
/* SOLO (Plan): gewählte Parts spielen, egal ob gemutet */
function isOn(p,s){if(trigHeld(p))return false;if(ui.solo.size){if(!ui.solo.has(p))return false;}else if(ui.muted.has(p))return false;if(ui.drop&&p>1)return false;
  if(ui.fillBar===Math.floor(s/16)&&p===2&&s%16>=8&&s%2===0)return true;return!!cur.steps[p][pStep(p,s)];}
function velFor(p,s){let v=cur.vel[p][s]/127;if(ui.accent&&s%4===0)v=Math.min(1,v*1.3);else if(ui.accent)v*=.85;return v;}
function seqMfx(){const m=ui.mfx[0];if(m.on&&m.touch){const k=MFX_KIND[m.type];if(k==='beatrep'||k==='revroll')return{k,m};}return null;}
const ROLL_DIV=[1,.5,.25,.125,1];
function trigger(p,t,note,vel,opts){const v=voice(p,t,note,vel,opts);duck(p,t);midiNote(p,t,note,vel,opts&&opts.gate);return v;}
function doStep(s,t){
  if(s%16===0&&ui.fillBar>=0&&(s>>4)!==ui.fillBar)ui.fillBar=-1;
  if(ui.resample&&s%16===0&&!E.rec)startRecord(t,E.master,'RESAMPLE');
  if(ui.inRec&&s%16===0&&!E.rec&&E.in){ui.inRec=false;startRecord(t,E.in.out,'INPUT');}
  if(ui.rec&&ui.playing){const m=ui.mfx[0];if((m.touch&&m.user)||ui.rollHeld)undoKind('mrec');if(m.touch&&m.user)rec(ui.part,s,'_fx',[m.touch[0],m.touch[1]]);if(ui.rollHeld)rec(ui.part,s,'_roll',ui.rollType+1);}
  /* Motion-Wiedergabe */
  let anyFx=null,rollM=0;
  for(let p=0;p<16;p++){const mm=cur.parts[p].motionMode??1,mo=ui.motion&&mm&&!(ui.rec&&p===ui.part)&&(mm!==2||isOn(p,s))?cur.motion[p][pStep(p,s)]:null;motionFx[p]=null;if(!mo)continue;let ch=false;
    for(const k in mo){if(k==='_fx'){motionFx[p]=mo._fx;if(!anyFx)anyFx=mo._fx;}else if(k==='_roll'){motionFx[p]=motionFx[p]||[.5,.5];rollM=mo._roll;}
      else if(k.startsWith('fx')){const f=cur.parts[p].fx[+k.slice(2)];if(f){f.edit=mo[k];ch=true;}}else{cur.parts[p][k]=mo[k];ch=true;}}
    if(ch){applyChannel(p);if('cut' in mo||'reso' in mo)liveFilter(p);}}
  const m0=ui.mfx[0];if(!m0.user){if(anyFx){m0.touch=anyFx;m0.byMotion=true;E.mfx[0].update();}else if(m0.byMotion){m0.touch=null;m0.byMotion=false;E.mfx[0].update();}}
  if(!ui.rollHeld){if(rollM&&!E.loop.on){engageLoop(t,rollM-1);E.loop.byMotion=true;}else if(!rollM&&E.loop.on&&E.loop.byMotion){E.loop.release(t);E.loop.byMotion=false;}}
  applyRouting();
  const routed=p=>fxRouted(p)||!!motionFx[p];
  const sm=seqMfx();let ps=s;
  if(sm){if(!br)br={start:s-(s%4)};const len=[1,2,4,8][Math.round(sm.m.touch[0]*3)];ps=br.start+(((s-br.start)%len)+len)%len;}else br=null;
  const nr=ui.rollOn&&ui.rollType>=5;
  if(nr){
    /* NOTE-ROLL: alle Parts mit ROLL SEND, die in diesem Takt spielen. Triolen liegen fest auf dem Beat-Raster, egal wann ROLL gedrückt wird */
    const bar=s>>4;rollSet=[];for(let p=0;p<16;p++){if(!rollRouted(p)||ui.muted.has(p)||(ui.solo.size&&!ui.solo.has(p))||(ui.drop&&p>1))continue;for(let q=bar*16;q<bar*16+16;q++)if(cur.steps[p][pStep(p,q)]){rollSet.push(p);break;}}
    if(!rollSet.length)rollSet=[ui.part<NSEQ?ui.part:0];
    const ty=ROLLS[ui.rollType],d=stepDur(s),beatD=stepLen()*4,b0=t-(s%4)*stepLen();let hits;
    if(ty.includes('1/12')){hits=[];for(let k=0;k<3;k++){const tk=b0+k*beatD/3;if(tk>=t-1e-4&&tk<t+d-1e-4)hits.push(tk-t);}}else hits=ty.includes('1/32')?[0,d/2]:[0];
    const lastNote=p=>{for(let q=s;q>=bar*16;q--)if(cur.steps[p][pStep(p,q)])return cur.notes[p][pStep(p,q)];for(let q=bar*16;q<bar*16+16;q++)if(cur.steps[p][pStep(p,q)])return cur.notes[p][pStep(p,q)];return 57;};
    rollSet.forEach(p=>{const n=lastNote(p);hits.forEach(o=>trigger(p,t+o,n,.8,{gate:Math.min(d,beatD/3)*.45}));});
    if(ui.rec&&ui.playing&&rollSet.includes(ui.part)){undoKind('rollrec');cur.steps[ui.part][s]=1;cur.rat[ui.part][s]=ty.includes('1/32')?2:1;dirty();}
  }else rollSet=null;
  if(s%16===0)for(let p=0;p<PARTS.length;p++){const P=cur.parts[p];if(!P.loopN||ui.muted.has(p)||(ui.drop&&p>1)||(s>>4)%P.loopN)continue;
    E.voices.forEach(v=>{if(v.part===p&&!v.dead&&!v.rel)releaseVoice(v,t,.008);});trigger(p,t,57,.85,{gate:Math.min(stretchSteps(P),P.loopN*16)*stepLen()});}
  const skip=ui.skipFirst&&s===ui.skipFirst.s?ui.skipFirst.p:-1;ui.skipFirst=null;
  for(let p=0;p<16;p++){if(nr&&rollSet&&rollSet.includes(p))continue;if(p===skip)continue;const q0=sm&&routed(p)?ps:s;if(!isOn(p,q0))continue;const q=pStep(p,q0),P=cur.parts[p];
    const r=Math.max(1,cur.rat[p][q]),d=stepDur(s),g=cur.gate[p][q],gr=GROOVEDATA[P.grooveT||0][q%16],gd=P.grooveD??.5,tt=t+Math.max(0,gr[0]*gd*d),vv=clamp(velFor(p,q)*(1+(gr[1]-1)*gd));
    /* bis 4 Noten pro Step (Electribe 2), GATE TIE = Ton hält bis zum nächsten Step (MONO 1 bindet ohne neuen Anschlag) */
    const xs=(cur.xn&&cur.xn[p]&&cur.xn[p][q])||[],gate=g===255?d*1.04:g?g/4*stepLen():null;
    for(let k=0;k<r;k++){const o={gate:r>1?d/r*.8:gate,rev:sm&&sm.k==='revroll'&&routed(p)};trigger(p,tt+k*d/r,cur.notes[p][q],vv,o);xs.forEach(n=>trigger(p,tt+k*d/r,n,vv,Object.assign({},o)));}}
  if(G.metro===4||(G.metro>=1&&G.metro<=3&&ui.rec))if(s%4===0)metroClick(t,s%16===0);
}
/* Metronom (GLOBAL PARAMETER) */
/* Metronom-Klänge (GLOBAL > METRO SOUND). Beim Auswählen wird 1 Takt im aktuellen Tempo vorgespielt, wie ein Klingelton */
function metroClick(t,one,k=G.metroSnd){const L=G.metroLvl*(one?1:.7),out=gainN(L*1.4);out.connect(E.master);
  const osc=(type,f,f2,dur,g=1)=>{const o=ctx.createOscillator(),e=gainN(0);o.type=type;o.frequency.setValueAtTime(f,t);if(f2)o.frequency.exponentialRampToValueAtTime(f2,t+dur*.6);o.connect(e);e.connect(out);e.gain.setValueAtTime(g,t);e.gain.setTargetAtTime(0,t+.002,dur/4);o.start(t);o.stop(t+dur*1.5);};
  const nz=(type,f,q,dur,g=1)=>{const n=ctx.createBufferSource(),b=biqN(type,f,q),e=gainN(0);n.buffer=E.noise;n.connect(b);b.connect(e);e.connect(out);e.gain.setValueAtTime(g,t);e.gain.setTargetAtTime(0,t+.001,dur/4);n.start(t);n.stop(t+dur*1.5);};
  const up=one?1.5:1;
  switch(METROSND[k]){case 'BEEP':osc('sine',1000*up,0,.07,.7);break;case 'WOOD BLOCK':osc('sine',800*up,620*up,.05,.9);nz('bandpass',2200,3,.02,.4);break;
    case 'COWBELL':osc('square',540,0,.16,.3);osc('square',800,0,.16,.3);break;case 'RIMSHOT':osc('triangle',1700*up,0,.03,.6);nz('bandpass',3500,2,.03,.6);break;
    case 'CLAVE':osc('sine',2500*up,0,.05,.8);break;case 'HI-HAT':nz('highpass',one?6000:8000,.7,one?.08:.04,.9);break;case 'KICK':osc('sine',160*up,48,.14,1);break;
    case '8-BIT BLIP':osc('square',880*up,0,.04,.35);break;case 'STICKS':nz('bandpass',3000*up,4,.025,1);osc('triangle',2400,0,.015,.4);break;
    case 'TOK':osc('sine',700*up,330*up,.05,.9);break;case 'SONAR':osc('sine',1500*up,0,.35,.5);break;default:osc('sine',(one?2000:1200),0,.02,.8);nz('highpass',4000,.7,.006,.5);}
  setTimeout(()=>{try{out.disconnect();}catch(e){}},(t-now()+1)*1000);}
function metroPreview(){if(!E)return;const t0=now()+.05,bd=60/G.bpm;for(let k=0;k<4;k++)metroClick(t0+k*bd,k===0);}
function schedule(){
  if(!ready||!ui.playing)return;
  while(seq.next<now()+.12){
    if(seq.step%16===0&&ui.pendingPat){switchPattern(ui.pendingPat);seq.step=0;}
    if(ui.ramp){const r=ui.ramp;r.done++;setBPM(r.from+(r.to-r.from)*Math.min(1,r.done/r.total),true);if(r.done>=r.total){ui.ramp=null;setBPM(r.to);}}
    evStep();const d=stepDur(seq.step);doStep(seq.step,seq.next);midiClock(seq.next,d);visQ.push({t:seq.next,s:seq.step});
    seq.next+=d;seq.step=(seq.step+1)%cur.last;ui.absStep++;
    /* CHAIN TO / CHAIN REPEAT: nach N Durchläufen automatisch zum nächsten Pattern */
    if(seq.step===0){ui.chainCount++;if(G.chainMode&&cur.chainTo&&ui.chainCount>=cur.chainRep&&!ui.pendingPat)ui.pendingPat=cur.chainTo;}}
}
/* EVENT RECORD / PLAY: Pattern-Wechsel, Mutes, Solo, DROP und MFX-Bewegungen werden mitgeschrieben und wieder abgespielt */
function evLog(k,v){const V=ui.ev;if(!V.rec||!ui.playing)return;V.list.push({s:ui.absStep-V.t0,k,v:JSON.parse(JSON.stringify(v))});}
function evApply(e){switch(e.k){case 'pat':queuePattern(e.v,true);break;case 'mute':ui.muted=new Set(e.v);break;case 'solo':ui.solo=new Set(e.v);break;case 'drop':ui.drop=e.v;setLed(FN.DROP,ui.drop);break;
  case 'xy':{const m=ui.mfx[0];m.touch=e.v;m.byMotion=true;E.mfx[0].update();drawMFXPad(0);break;}}}
function evStep(){const V=ui.ev;if(V.rec){const m=ui.mfx[0];if(m.user&&m.touch&&!ui.padMode)evLog('xy',m.touch);else if(V.lastXY&&!m.touch)evLog('xy',null);V.lastXY=!!m.touch;}
  if(!V.play)return;const pos=ui.absStep-V.t0;while(V.k<V.list.length&&V.list[V.k].s<=pos)evApply(V.list[V.k++]);if(V.k>=V.list.length&&pos>(V.list.length?V.list[V.list.length-1].s:0)+16){V.play=false;popup('msg',{t:'EVENT PLAY',b:'END'},1500);}}
setInterval(()=>{schedule();arpRun();modIfxTick();},20);
setInterval(()=>{if(ready){glueAutoGain();druckAutoGain();}},60);
/* MOD-Ziel IFX: LFO bzw. EG verändert das EDIT aller aktiven Insert-Effekte des Parts (ca. 50 x pro Sekunde) */
function modIfxTick(){if(!ready||!E)return;const t=now();for(let i=0;i<PARTS.length;i++){const P=cur.parts[i],M=modInfo(P.mtype),c=E.ch[i];if(!M||M.dst!=='IFX'||P.depth<.005){if(c.ifxMod){c.ifxMod=false;syncSlots(i);}continue;}
  let v;if(M.eg){const dt=t-E.partHit[i];v=E.partHit[i]<0||dt<0?0:Math.exp(-dt/modEgT(P))*M.sign;}
  else{const ph=((t-(c.lfoT0||0))*lfoRate(P))%1;v=M.src==='tri'?1-4*Math.abs(ph-.5):M.src==='saw'?ph*2-1:M.src==='squ'?(ph<.5?1:-1):hr(Math.floor((t-(c.lfoT0||0))*lfoRate(P)))*2-1;v*=M.sign;}
  c.ifxMod=true;P.fx.forEach((f,k)=>{const sl=c.slots[k];if(f.on&&sl&&sl.fx)sl.fx.set(clamp(f.edit+v*P.depth*.5));});}}
function startRecord(t,node,name){
  const dur=16*60/G.bpm/4,sp=ctx.createScriptProcessor(4096,2,2),L=[],Rr=[];E.rec=sp;
  sp.onaudioprocess=e=>{const pt=e.playbackTime;if(pt+e.inputBuffer.duration<t)return;if(pt>t+dur){finish();return;}L.push(new Float32Array(e.inputBuffer.getChannelData(0)));Rr.push(new Float32Array(e.inputBuffer.getChannelData(1)));};
  let done=false;const finish=()=>{if(done)return;done=true;try{node.disconnect(sp);sp.disconnect();}catch(e){}E.rec=null;
    const len=L.reduce((a,b)=>a+b.length,0),b=ctx.createBuffer(2,Math.max(1,len),ctx.sampleRate);let o=0;L.forEach((a,k)=>{b.getChannelData(0).set(a,o);b.getChannelData(1).set(Rr[k],o);o+=a.length;});
    SRC.push({n:name+' '+(SRC.length-N_FACTORY+1),buf:norm(b),f0:detectF0(b)});cur.parts[ui.part].src=SRC.length-1;ui.resample=false;setLed(CTRL.resample,false);refreshKnobs();dirty();
    popup('msg',{t:name==='INPUT'?'SAMPLING':'RESAMPLING',b:'DONE',s:'NEW SAMPLE ON PART '+pad2(ui.part+1)});};
  node.connect(sp);sp.connect(ctx.destination);
}

/* ---------- Roll (Brrrp) ---------- */
function loopLen(type){return stepLen()*ROLL_DIV[type];}
function engageLoop(t,type){const L=loopLen(type);if(type===4)E.loop.engage(t,L,L/8,16*stepLen());else E.loop.engage(t,L);}
function rollDown(){
  if(shiftNow()){consumeShift();openMenuItem('PATTERN SET','ROLL TYPE');return;}   // SHIFT + ROLL = ROLL-TYPE-Menü (VALUE), bleibt bis EXIT
  ui.rollHeld=true;ui.rollOn=true;setLed(CTRL.roll,true);popup('roll',{},99999);
  if(ui.rollType<5){let t=now()+.004;if(ui.playing&&ui.dispT){const L=loopLen(ui.rollType),k=Math.ceil((t-ui.dispT)/L);t=ui.dispT+Math.max(0,k)*L;}E.loop.byMotion=false;engageLoop(t,ui.rollType);}
  applyRouting();
}
function rollUp(){if(!ui.rollHeld)return;ui.rollHeld=false;ui.rollOn=false;setLed(CTRL.roll,false);rollSet=null;if(E.loop.on)E.loop.release(now());ui.popup=null;}

/* ---------- MIDI (Web MIDI: Keyboards, Clock, Start/Stop, Programmwechsel) ---------- */
const MIDI={acc:null,ins:[],outs:[],ticks:[],lastTick:0,act:0,clkAct:0};
const CCMAP={1:'depth',7:'level',10:'pan',71:'reso',72:'decay',73:'attack',74:'cutoff',75:'egint',76:'speed',77:'edit',78:'tubemix',79:'eqD',86:'eqX',80:'sc',82:'ifxedit',83:'eqL',84:'eqM',85:'eqH',87:'driveA',88:'driveB'};
async function midiConnect(){
  if(MIDI.acc)return true;if(!navigator.requestMIDIAccess){popup('msg',{t:'MIDI',b:'NOT AVAILABLE',s:'THIS BROWSER HAS NO WEB MIDI'},2600);return false;}
  try{MIDI.acc=await navigator.requestMIDIAccess({sysex:false});}catch(e){popup('msg',{t:'MIDI',b:'BLOCKED',s:'NO PERMISSION FOR MIDI'},2600);return false;}
  const scan=()=>{MIDI.ins=[...MIDI.acc.inputs.values()];MIDI.outs=[...MIDI.acc.outputs.values()];MIDI.ins.forEach(i=>i.onmidimessage=onMidi);};
  scan();MIDI.acc.onstatechange=scan;popup('msg',{t:'MIDI',b:MIDI.ins.length+' IN · '+MIDI.outs.length+' OUT',s:MIDI.ins.map(i=>i.name).join(', ').toUpperCase().slice(0,38)||'NO DEVICE FOUND'},3000);return true;
}
const audioToMs=t=>(t-now())*1000+performance.now();
function midiSend(data,t){const ty=data[0]&0xF0;if(G.txFilter>=1&&(ty===0x90||ty===0x80||ty===0xB0))return;if(G.txFilter===2&&ty===0xC0)return;MIDI.outs.forEach(o=>{try{o.send(data,t!=null?audioToMs(t):undefined);}catch(e){}});}
function midiClock(t,d){if(!MIDI.outs.length||!G.midi.clockOut||ui.extClock)return;for(let k=0;k<6;k++)midiSend([0xF8],t+k*d/6);}
function midiNote(p,t,note,vel,gate){if(!MIDI.outs.length||!G.midi.notesOut)return;const n=clamp(partNote(cur.parts[p],note),0,127)|0;midiSend([0x90|p,n,Math.max(1,Math.round(vel*127))],t);midiSend([0x80|p,n,0],t+(gate||.1));}
function onMidi(e){
  const[st,d1,d2]=e.data,ty=st&0xF0,ch=st&15;MIDI.act=performance.now();
  if(G.midi.thru&&st<0xF8)midiSend(e.data);
  if(st===0xF8){if(G.midi.clock===0)return;const t=performance.now();MIDI.ticks.push(t);if(MIDI.ticks.length>25)MIDI.ticks.shift();MIDI.lastTick=t;MIDI.clkAct=t;ui.extClock=true;
    if(MIDI.ticks.length>12){const iv=(MIDI.ticks[MIDI.ticks.length-1]-MIDI.ticks[0])/(MIDI.ticks.length-1),b=60000/(iv*24);if(Math.abs(b-G.bpm)>.4&&b>40&&b<320)setBPM(Math.round(b*10)/10);}return;}
  if(st===0xFA&&G.midi.clock){seq.step=0;ui.dispStep=0;setPlaying(true);return;}
  if(st===0xFB&&G.midi.clock){setPlaying(true);return;}
  if(st===0xFC&&G.midi.clock){setPlaying(false);return;}
  if(!ready)return;
  /* MIDI RECEIVE FILTER: SHORT = keine Noten/CC, SHORT+PROGRAM = auch keine Programmwechsel */
  if(G.rxFilter>=1&&(ty===0x90||ty===0x80||ty===0xB0))return;if(G.rxFilter===2&&ty===0xC0)return;
  if(G.midi.keyb===0&&ch!==(G.midiCh||1)-1&&ty!==0xC0)return;
  const part=G.midi.keyb===1?ch:ui.part;
  if(ty===0x90&&d2>0){const v=velCurve(d2/127),id='m'+ch+'.'+d1;trigger(part,now(),d1-(cur.parts[part].oct*12+cur.parts[part].tr),v,{held:true,id});ui.padFlash[part]=performance.now();
    const s=recordHit(part,d1-(cur.parts[part].oct*12+cur.parts[part].tr),v);if(s>=0)ui.midiHeld=Object.assign(ui.midiHeld||{},{[id]:{s,part,t:now()}});return;}
  if(ty===0x80||(ty===0x90&&d2===0)){const id='m'+ch+'.'+d1;noteOff(part,id,now());const h=ui.midiHeld&&ui.midiHeld[id];if(h){cur.gate[h.part][h.s]=clamp(Math.round((now()-h.t)/stepLen()*4),1,255);delete ui.midiHeld[id];}return;}
  if(ty===0xB0&&G.midi.ccIn&&CCMAP[d1]){const d=CTRL[CCMAP[d1]];if(!d)return;const keep=ui.part;if(part!==ui.part)ui.part=part;
    /* KNOB MODE für externe Regler: JUMP = sofort, CATCH = erst wenn der Regler den Wert erreicht, VALUE SCALE = relativ */
    const nv=d2/127,cv=knobGet(d),K=(MIDI.cc||(MIDI.cc={}));const last=K[d1];K[d1]=nv;let target=nv;
    if(G.knobMode===1){if(!(d.caught&&last!=null)){if(last!=null&&((last-cv)*(nv-cv)<=0||Math.abs(nv-cv)<.02))d.caught=true;else{if(part!==keep)ui.part=keep;return;}}}
    else if(G.knobMode===2&&last!=null){target=clamp(cv+(nv-last)*(nv>last?(1-cv)/Math.max(.01,1-last):cv/Math.max(.01,last)));}
    if(d.det&&d.det!=='center'){const L=d.det==='list'?listInfo(d):null;if(L)tickKnob(d,Math.round(target*(L.n-1))-L.i);}else knobSet(d,target);if(part!==keep)ui.part=keep;else{refreshKnob(d);knobChanged(d);}return;}
  if(ty===0xC0&&G.midi.pc){queuePattern(d1+1);return;}
}

/* ---------- Bedienlogik ---------- */
function popup(type,data={},ms=1700){ui.popup=Object.assign({type},data);ui.popupUntil=performance.now()+ms;}
function seg(msg,ms=1300){ui.segMsg=msg;ui.segUntil=performance.now()+ms;}
const shiftNow=()=>ui.shift||kbShift;
function consumeShift(){ui.shiftUsed=true;if(ui.shiftLatch){ui.shiftLatch=false;ui.shift=false;setLed(CTRL.shift,false);}}
function sh(){const s=shiftNow();if(s)consumeShift();return s;}
function setPlaying(p){if(!ready)return;if(p===ui.playing&&p)return;ui.playing=p;
  if(p){seq.next=now()+.06;visQ.length=0;
    /* METRONOME REC 1 / REC 2: 1 bzw. 2 Takte Vorzähler vor der Aufnahme */
    if(ui.rec&&!ui.recAuto&&(G.metro===2||G.metro===3)&&seq.step===0){const bars=G.metro-1,bd=4*60/G.bpm;for(let k=0;k<bars*4;k++)metroClick(seq.next+k*bd/4,k%4===0);seq.next+=bars*bd;popup('msg',{t:'METRONOME',b:'COUNT IN '+bars+(bars>1?' BARS':' BAR')},bars*bd*1000);}if(MIDI.outs.length&&G.midi.clockOut&&!ui.extClock)midiSend([seq.step===0?0xFA:0xFB],seq.next);}
  else{ui.recAuto=false;if(MIDI.outs.length&&G.midi.clockOut&&!ui.extClock)midiSend([0xFC]);if(E.loop.on&&!ui.rollHeld)E.loop.release(now());}
  setLed(CTRL.play,p);}
function setBPM(b,ramping){G.bpm=Math.round(clamp(b,40,300)*10)/10;if(!ramping&&G.tlock===0)cur.bpm=G.bpm;refreshKnob(CTRL.tempo);
  if(!E)return;PARTS.forEach((_,i)=>{const P=cur.parts[i];if(P.stretch===2)scheduleStretch(i);const M=modInfo(P.mtype);if(M&&!M.eg&&M.bpm)setLfoWave(E.ch[i],LFOW[M.src],lfoRate(P),now(),M.sign);});}
function partLeds(){const P=cur.parts[ui.part];setLed(CTRL.tubeon,P.tube);setLed(CTRL.glue,P.glueOn);setLed(CTRL.reverse,P.reverse);setLed(CTRL.stretch,P.stretch>0);setLed(CTRL.bpmsync,P.sync);setLed(CTRL.egon,P.egOn);setLed(CTRL.send,P.send);setLed(CTRL.rollsend,P.rollSend!==false);setLed(CTRL.mono,(P.voice??0)<2);setLed(CTRL.oktsend,!!P.oktSend);setLed(CTRL.bw,!!ui.bw);ifxLeds();}
function ifxLeds(){const P=cur.parts[ui.part];ifxPageEl.textContent='SELECT · IFX '+(ui.fxSel+1);for(let k=0;k<5;k++){const d=CTRL['ifxon'+k],f=P.fx[k];setLed(d,!!(f&&f.on));d.el.classList.toggle('sel',k===ui.fxSel);}}
function setPart(i,quiet){ui.part=i;ALLK.forEach(d=>d.caught=false);partLeds();refreshKnobs();if(!quiet)popup('msg',{t:'PART SELECT',b:'PART '+pad2(i+1),s:PARTS[i]+' · '+partSrcName(cur.parts[i])});}
const partSrcName=P=>P.src?pad3(P.src)+' '+SRC[P.src].n:P.osc?'OSC '+pad2(P.osc)+' '+OSCS[P.osc]:'SILENT';
function queuePattern(n,byEvent){n=clamp(Math.round(n),1,250);if(ui.write&&ui.write.stage==='as'){ui.write.target=n;popup('write',{},8000);return;}
  if(!byEvent)evLog('pat',n);if(ui.playing){ui.pendingPat=n===ui.pattern?null:n;popup('pattern',{},1500);seg('P.'+pad3(n));}else switchPattern(n);}
function switchPattern(n){
  const prev=G.bpm;ui.pattern=n;cur=loadPattern(n);ui.pendingPat=null;ui.saved=true;pcmPreload();
  if(G.tlock===0)setBPM(cur.bpm);else if(G.tlock===2&&Math.abs(cur.bpm-prev)>.05){ui.ramp={from:prev,to:cur.bpm,total:G.rampBars*16,done:0};}else G.bpm=prev;
  loadPatState();applyGlobals();PARTS.forEach((_,i)=>{applyChannel(i);if(cur.parts[i].stretch)scheduleStretch(i);});partLeds();refreshKnobs();padLabels();resetUndo();popup('pattern');seg('P.'+pad3(n));
}
/* Beim Pattern-Wechsel kommt alles aus dem neuen Pattern (MFX, Roll-Typ, Mutes, Swing, Level …). Live-Zustände werden zurückgesetzt, nichts schleppt sich mit. */
function loadPatState(){motionFx.fill(null);ui.chainCount=0;ui.solo.clear();ui.fill=null;ui.pageSel=0;ui.copy=!!ui.copy;tsRelease();
  ui.muted=new Set(cur.mutes||[]);ui.rollType=cur.rollType??2;
  (cur.mfx||[]).forEach((x,i)=>{const m=ui.mfx[i];if(!m)return;m.type=x.type;m.on=x.on;if(!m.user){m.touch=null;m.hold=false;m.byMotion=false;}});
  if(E){if(E.loop.on&&!ui.rollHeld)E.loop.release(now());setPartRate(1,.05,PARTS.map((_,p)=>p));E.mfx.forEach(x=>x.update());}
  padModeLeds();setLed(CTRL.mfxhold,ui.mfx[0].hold);if(CTRL.mfxon2){setLed(CTRL.mfxon2,ui.mfx[1].on);setLed(CTRL.mfxhold2,ui.mfx[1].hold);}
  [0,1].forEach(i=>{drawMFXPad(i);drawOLED(i);});refreshKnob(CTRL.mfxtype);refreshKnob(CTRL.mfxtype2);refreshKnob(CTRL.rolltype);}
const saveMutes=()=>{cur.mutes=[...ui.muted];dirty();evLog('mute',cur.mutes);};
/* UNDO / REDO: bis zu 60 Schritte. Schnelle Änderungen (Regler drehen, Steps tippen) werden zu einem Schritt zusammengefasst */
function snap(){const o={steps:cur.steps.map(a=>a.slice()),notes:cur.notes.map(a=>a.slice()),vel:cur.vel.map(a=>a.slice()),gate:cur.gate.map(a=>a.slice()),rat:cur.rat.map(a=>a.slice()),
  motion:JSON.parse(JSON.stringify(cur.motion)),parts:JSON.parse(JSON.stringify(cur.parts))};PATKEYS.forEach(k=>{if(cur[k]!==undefined)o[k]=JSON.parse(JSON.stringify(cur[k]));});
  o.g={};UNDO_G.forEach(k=>o.g[k]=G[k]);return o;}
/* globale Klang-Einstellungen, die UNDO auch zurückholt */
const UNDO_G=['bpm','color','analog','tubeOn'];
function restore(s){const{g,...p}=s;Object.assign(cur,p);if(g){const bpm=G.bpm;UNDO_G.forEach(k=>{if(g[k]!==undefined)G[k]=g[k];});if(G.bpm!==bpm)setBPM(G.bpm,true);applyColor();}
  ui.muted=new Set(cur.mutes||[]);if(E){applyGlobals();PARTS.forEach((_,i)=>applyChannel(i));applyRouting();}partLeds();refreshKnobs();padLabels(true);}
const UNDO_MAX=60;let undoStable=null,undoT=null,undoK=null,undoN=0;ui.undoS=[];ui.redoS=[];
function undoBurst(){clearTimeout(undoT);undoT=setTimeout(()=>{undoT=null;undoStable=snap();},700);}
function undoPush(st){ui.undoS.push(st);if(ui.undoS.length>UNDO_MAX)ui.undoS.shift();ui.redoS=[];}
/* Vor jeder Änderung aufrufen: etwas anderes als eben (anderer Regler, neuer Ton, andere Taste) = eigener UNDO-Schritt */
function undoKind(k){if(undoT&&k!==undoK){clearTimeout(undoT);undoT=null;undoStable=snap();}undoK=k;}
function pushUndo(k){undoKind(k||'op'+(++undoN));if(!undoT)undoPush(snap());undoBurst();}
function dirty(){ui.saved=false;if(!undoT&&undoStable)undoPush(undoStable);undoBurst();}
function resetUndo(){ui.undoS=[];ui.redoS=[];clearTimeout(undoT);undoT=null;undoStable=snap();}
function undoFlush(){if(undoT){clearTimeout(undoT);undoT=null;undoStable=snap();}}
function doUndo(){undoFlush();const u=ui.undoS.pop();if(!u){popup('msg',{t:'UNDO',b:'NOTHING',s:'NO EDIT TO UNDO'});return;}ui.redoS.push(snap());restore(u);undoStable=snap();ui.saved=false;popup('msg',{t:'UNDO',b:'STEP BACK',s:ui.undoS.length+' MORE · SHIFT+PAGE> = REDO'},1200);}
function doRedo(){undoFlush();const r=ui.redoS.pop();if(!r){popup('msg',{t:'REDO',b:'NOTHING'});return;}ui.undoS.push(snap());restore(r);undoStable=snap();ui.saved=false;popup('msg',{t:'REDO',b:'STEP FORWARD',s:ui.redoS.length+' MORE'},1200);}
function rec(p,s,k,v){const m=cur.motion[p];(m[s]||(m[s]={}))[k]=v;dirty();}
function showIFX(){popup('ifx',{},1800);}
function tap(){const t=performance.now();ui.taps=ui.taps.filter(x=>t-x<2500);ui.taps.push(t);if(ui.taps.length>=2){setBPM(60000/((ui.taps[ui.taps.length-1]-ui.taps[0])/(ui.taps.length-1)));dirty();}
  popup('msg',{t:'TAP TEMPO',b:G.bpm.toFixed(1)+' BPM',s:ui.taps.length<2?'KEEP TAPPING':'TAPS: '+ui.taps.length});}
function save(as){const t=performance.now(),w=ui.write;
  if(as){ui.write={stage:'as',t,target:ui.pattern};popup('write',{},8000);return;}
  if(w&&(w.stage==='confirm'||w.stage==='as')&&t-w.t<8000){const target=w.stage==='as'?w.target:ui.pattern;ui.write={stage:'writing',t,target};popup('write',{},2700);
    setTimeout(()=>{const ok=storePattern(target);ui.write.stage=ok?'done':'fail';if(ok){if(target!==ui.pattern){ui.pattern=target;}ui.saved=true;seg('SAVE',1500);}},900);}
  else{ui.write={stage:'confirm',t};popup('write',{},4000);}}
/* SCALE MODE (Part): AN = Pads spielen nur Töne der Tonleiter, AUS = chromatisch */
function scaleRun(k){const set=SCALESET[cur.scale],L=set.length;return 48+cur.key+set[((k%L)+L)%L]+12*Math.floor(k/L);}
const kbNote=i=>{const q=padRC(i),P=cur.parts[ui.part],o=12*(ui.kbOct||0);return P&&P.scaleMode?scaleRun(q.r*(SCALESET[cur.scale].length<12?7:12)+q.c)+o:48+o+q.r*12+q.c;};
/* CHORD SET (Pattern) wie Electribe 2: welche Akkorde CHORD-Modus und Gate Arp spielen */
/* CHORD SET 1-5 wie Electribe 2: Dichte des Akkords. Töne werden in Terzen aus der gewählten Skala geschichtet */
function chordOf(n){const set=SCALESET[cur.scale],L=set.length,rel=((n-cur.key)%12+12)%12,cnt=(cur.chordSet??1)+2;
  if(L>=12){const iv=[0,3,7,10,14,17];return iv.slice(0,cnt).map(x=>n+x);}
  let di=set.indexOf(rel);if(di<0){di=0;for(let k=0;k<L;k++)if(set[k]<=rel)di=k;}const base=n-(rel-set[di]),st=L<=5?1:2,o=[];
  for(let k=0;k<cnt;k++){const j=di+k*st;o.push(base+set[j%L]+12*Math.floor(j/L)+(k===0?rel-set[di]:0));}return o;}
const inScale=n=>SCALESET[cur.scale].includes(((n-cur.key)%12+12)%12);
/* FILL: Quelle wählen (Bar-Pad 17-24), dann Ziel-Bars antippen, FILL nochmal = kopieren. Ohne Ziele = auf alle Bars. SHIFT + FILL = alle Parts */
function fillStart(all){if(!all&&ui.part>=NSEQ){popup('msg',{t:'FILL',b:'LIVE PART',s:'NOT IN THE SEQUENCER'},1400);return;}
  if(cur.last<32){popup('msg',{t:'FILL',b:'ONLY 1 BAR',s:'SHIFT + BAR> = LONGER PATTERN'},1600);return;}
  ui.fill={all,src:clamp(ui.pageSel,0,cur.last/16-1),dst:new Set(),stage:'src'};popup('fill',{},600000);}
function fillBar(b){const F=ui.fill,nb=cur.last/16;if(!F)return;if(b>=nb){popup('fill',{err:'BAR '+(b+1)+' NOT IN PATTERN'},600000);return;}
  if(F.stage==='src'){F.src=b;F.stage='dst';F.dst.clear();}else if(b!==F.src){F.dst.has(b)?F.dst.delete(b):F.dst.add(b);}popup('fill',{},600000);}
function fillExec(){const F=ui.fill;if(!F)return;const nb=cur.last/16,dst=F.dst.size?[...F.dst].sort((a,b)=>a-b):Array.from({length:nb},(_,b)=>b).filter(b=>b!==F.src);ui.fill=null;pushUndo();
  (F.all?Array.from({length:NSEQ},(_,i)=>i):[ui.part]).forEach(p=>{['steps','notes','vel','gate','rat'].forEach(k=>{const a=cur[k][p];dst.forEach(b=>{for(let q=0;q<16;q++)a[b*16+q]=a[F.src*16+q];});});
    const m=cur.motion[p];dst.forEach(b=>{for(let q=0;q<16;q++){const v=m[F.src*16+q];if(v)m[b*16+q]=JSON.parse(JSON.stringify(v));else delete m[b*16+q];}});});dirty();
  popup('msg',{t:'FILL · '+(F.all?'ALL PARTS':'PART '+pad2(ui.part+1)+' '+PARTS[ui.part]),b:'BAR '+(F.src+1)+' > '+(dst.length===nb-1?'ALL':dst.map(b=>b+1).join(',')),s:'COPIED · UNDO = BACK'},2200);}
function fillCancel(){if(ui.fill){ui.fill=null;popup('msg',{t:'FILL',b:'CANCELLED'},800);}}
/* TOUCH SCALE wie Electribe 2: Pad = Tastatur in KEY/SCALE über TOUCH SCALE RANGE (Global, 1-4 Oktaven), Oktave über OCT -/+ des Parts.
   Rutschen spielt die Töne nacheinander (wie auf dem Pad der Korg). Y = Anschlagstärke (oben laut) */
function scaleNotes(){const set=SCALESET[cur.scale],r=48+cur.key,o=[];for(let k=0;k<(G.tsRange||2);k++)set.forEach(d=>o.push(r+d+12*k));o.push(r+12*(G.tsRange||2));return o;}
const tsNote=x=>{const ns=scaleNotes();return ns[clamp(Math.floor(x*ns.length),0,ns.length-1)];};
function tsTouch(x,y){const n=tsNote(x),v=.35+(1-y)*.65,T=ui.ts;if(T&&T.n===n)return;if(T&&T.id)noteOff(T.p,T.id,now());const id='ts'+performance.now();
  trigger(ui.part,now(),n,v,{held:true,id});ui.ts={n,id,p:ui.part};ui.padFlash[ui.part]=performance.now();if(ui.rec&&ui.playing)recordHit(ui.part,n,v);}
function tsRelease(){const T=ui.ts;if(T&&T.id)noteOff(T.p,T.id,now());ui.ts=null;}
/* GATE ARP wie Electribe 2: gehaltene Trigger-Pads (TRIGGER = Part, KEYBOARD/CHORD = Töne) werden im gewählten Muster (GATE ARP 1-50) gespielt.
   Touchpad X = Gate-Tempo (1/4 … 1/64), Y = Tonlänge (oben lang). Ohne gehaltenes Pad spielt der gewählte Part */
function arpItems(){const it=[];ui.held.forEach(h=>{if(h.notes)h.notes.forEach(n=>it.push({p:h.notesPart??ui.part,n}));else if(h.arpPart!==undefined)it.push({p:h.arpPart,n:57});});
  if(!it.length)it.push({p:ui.part,n:57});return it.sort((a,b)=>a.n-b.n||a.p-b.p);}
function arpTouch(x,y){const A=ui.arp;A.x=x;A.y=y;if(!A.on){A.on=true;A.k=0;A.next=ui.playing?seq.next:now()+.01;}}
function arpRelease(){ui.arp.on=false;}
function arpRun(){const A=ui.arp;if(!A.on||!ready)return;const GA=GATEARPS[cur.gateArp||0],rate=ARP_RATES[clamp(Math.floor(A.x*ARP_RATES.length),0,ARP_RATES.length-1)],iv=stepLen()*rate[1];
  while(A.next<now()+.1){const t=Math.max(A.next,now()),k=A.k,it=arpItems(),n=it.length;
    if(GA[1][k%16]==='1'){let pick;const j=Math.floor(k);
      switch(GA[2]){case 'REPEAT':pick=it;break;case 'UP':pick=[it[j%n]];break;case 'DOWN':pick=[it[n-1-j%n]];break;
        case 'UP-DOWN':{const L=Math.max(1,2*n-2),q=j%L;pick=[it[q<n?q:L-q]];break;}default:pick=[it[Math.floor(Math.random()*n)]];}
      const gl=iv*(.06+(1-A.y)*.92);pick.forEach(o=>{trigger(o.p,t,o.n,.85,{gate:gl});ui.padFlash[o.p]=performance.now();if(ui.rec&&ui.playing)recordHit(o.p,o.n,.85);});}
    A.k++;A.next+=iv;}}
/* COPY über Patterns hinweg: COPY nimmt den Part in die Zwischenablage, Pattern wechseln, Pad drücken = einfügen */
function clipPart(p){return{from:patStr()+' P'+pad2(p+1)+' '+PARTS[p],part:JSON.parse(JSON.stringify(cur.parts[p])),seq:p<NSEQ?{steps:cur.steps[p].slice(),notes:cur.notes[p].slice(),vel:cur.vel[p].slice(),gate:cur.gate[p].slice(),rat:cur.rat[p].slice()}:null,motion:JSON.parse(JSON.stringify(cur.motion[p]||{}))};}
function pasteClip(C,i){pushUndo();cur.parts[i]=JSON.parse(JSON.stringify(C.part));if(C.seq&&i<NSEQ){['steps','notes','vel','gate','rat'].forEach(k=>cur[k][i]=C.seq[k].slice());cur.motion[i]=JSON.parse(JSON.stringify(C.motion));}
  applyChannel(i);if(cur.parts[i].stretch)scheduleStretch(i);dirty();if(i===ui.part){partLeds();refreshKnobs();}}
function clipFrom(n,p){const keep=cur;cur=n===ui.pattern?keep:loadPattern(n);const C=clipPart(p);cur=keep;return C;}
const noteName=n=>KEYS[((n%12)+12)%12]+(Math.floor(n/12)-1);
function initPattern(){pushUndo();ui.fill=null;const b=blankPattern(ui.pattern);b.bpm=G.bpm;cur=b;dirty();motionFx.fill(null);PARTS.forEach((_,i)=>applyChannel(i));partLeds();refreshKnobs();padLabels();popup('msg',{t:'INIT PATTERN',b:'PATTERN EMPTY',s:'ALL STEPS + MOTION CLEARED (UNDO)'},2200);}
function clearPart(i){pushUndo();if(i<NSEQ){['steps','gate'].forEach(k=>cur[k][i].fill(0));cur.rat[i].fill(1);cur.vel[i].fill(100);cur.notes[i].fill(57);}cur.motion[i]={};cur.parts[i]=newPart(i);applyChannel(i);dirty();if(i===ui.part){partLeds();refreshKnobs();}
  popup('msg',{t:'CLEAR PART '+pad2(i+1),b:'PART CLEARED',s:i<NSEQ?'STEPS + MOTION + SOUND RESET':'SOUND RESET'},1800);}
/* Der Sequencer bleibt auf der gewählten Bar, auch beim Abspielen. Nur < BAR > oder die Bar-Pads wechseln. */
function pageMove(dir){const n=cur.last/16;ui.pageSel=clamp(ui.pageSel+dir,0,n-1);
  popup('msg',{t:'BAR',b:'BAR '+(ui.pageSel+1)+' / '+n,s:'STEPS '+(ui.pageSel*16+1)+'-'+(ui.pageSel*16+16)+' · STAYS WHILE PLAYING'},1100);}
function setLength(dir){const o=[16,32,48,64,80,96,112,128];cur.last=o[clamp(o.indexOf(cur.last)+dir,0,7)];if(seq.step>=cur.last)seq.step=0;ui.pageSel=clamp(ui.pageSel,0,cur.last/16-1);dirty();
  popup('msg',{t:'PATTERN LENGTH',b:(cur.last/16)+(cur.last>16?' BARS':' BAR'),s:cur.last+' STEPS'},1300);}
function func(d){
  const f=d.fn,P=cur.parts[ui.part],s=sh();
  if(d.mode){
    if(s&&f==='MUTE'){ui.muted.clear();ui.solo.clear();saveMutes();evLog('solo',[]);popup('msg',{t:'MUTE + SOLO',b:'ALL PARTS ON',s:'SHIFT + MUTE'},1200);return;}
    if(s&&f==='ERASE'){const t=performance.now();if(t-ui.initConfirm<3000){ui.initConfirm=0;initPattern();}else{ui.initConfirm=t;popup('msg',{t:'INIT PATTERN '+patStr(),b:'SHIFT+ERASE AGAIN',s:'EMPTY PATTERN, SOUNDS STAY'},3000);}return;}
    if(s&&f==='KEYBOARD'){cur.key=(cur.key+1)%12;dirty();padLabels();popup('msg',{t:'PATTERN KEY',b:KEYS[cur.key]+' '+SCALES[cur.scale],s:'SHIFT + KEYBOARD = NEXT KEY'},1400);return;}
    if(s&&f==='CHORD'){cur.scale=(cur.scale+1)%SCALES.length;dirty();padLabels();popup('msg',{t:'PATTERN SCALE',b:KEYS[cur.key]+' '+SCALES[cur.scale],s:'SHIFT + CHORD = NEXT SCALE'},1400);return;}
    /* SHIFT + SEQU. = FILL (Plan: keine eigene FILL-Taste mehr). Nochmal SHIFT + SEQU. oder ENTER = kopieren */
    if(s&&f==='SEQUENCER'){if(ui.fill)fillExec();else fillStart(false);return;}
    const m=f;if(f==='TRIGGER'||f==='MUTE')ui.modeHold={f,prev:ui.mode,used:false};setMode(m);popup(m==='MUTE'?(ui.solo.size?'solo':'mute'):'mode');return;}
  switch(f){
    case 'COPY':if(ui.copy){ui.copy=false;setLed(d,false);popup('msg',{t:'COPY',b:'CANCELLED'},900);break;}ui.clip=clipPart(ui.part);ui.copy=true;setLed(d,true);
      popup('msg',{t:'COPY · '+ui.clip.from,b:'PAD = PASTE',s:'OTHER PATTERN OK · COPY AGAIN = CANCEL'},3000);break;
    case 'FILL':if(ui.fill)fillExec();else fillStart(s);break;
    case 'DROP':ui.drop=!ui.drop;evLog('drop',ui.drop);setLed(d,ui.drop);popup('msg',{t:'DROP',b:ui.drop?'DROP!':'BACK IN',s:ui.drop?'ONLY KICK + TOK':'ALL PARTS PLAYING'});break;
    /* OKT − / OKT + (Plan): Oktave des aktuellen Parts. SOLO halten = Solo-Parts, OKT. SEND halten = alle Send-Parts, KEYB./CHORD = Tastatur, SHIFT = Halbton */
    case 'OCT -':case 'OCT +':{const dir=f==='OCT +'?1:-1;
      if(CTRL.solo.down&&ui.soloHold){soloOct(dir);break;}
      if(CTRL.oktsend.down&&ui.oktHold){ui.oktHold.used=true;oktShift(dir);break;}
      if(!s&&(ui.mode==='KEYBOARD'||ui.mode==='CHORD')){ui.kbOct=clamp((ui.kbOct||0)+dir,-4,4);padLabels(true);const lo=partNote(P,kbNote(0)),hi=partNote(P,kbNote(23));
        popup('msg',{t:'KEYBOARD OCTAVE '+(ui.kbOct>0?'+':'')+ui.kbOct,b:noteName(lo)+' - '+noteName(hi),s:'OKT -/+ = 8 OCTAVES · SHIFT = SEMITONE'},1400);break;}
      if(s)P.tr=clamp(P.tr+dir,-12,12);else P.oct=clamp(P.oct+dir,-5,5);dirty();padLabels();
      popup('msg',{t:'PART '+pad2(ui.part+1)+' '+PARTS[ui.part],b:'OCT '+(P.oct>0?'+':'')+P.oct+(P.tr?'  TR '+(P.tr>0?'+':'')+P.tr:''),s:'ONLY THIS PART · -5 TO +5'},1200);break;}
  }
}
function padModeLeds(){setLed(CTRL.mfxon,ui.padMode===0);setLed(CTRL.gatearp,ui.padMode===1);setLed(CTRL.padmode,ui.padMode===2);}
function openMenuItem(page,item){const k=MENU.findIndex(m=>m.t===page);if(k<0)return;ui.menu=k;ui.menuItem=Math.max(0,MENU[k].items.findIndex(x=>x.k===item));ui.menuEdit=true;ui.popup=null;}
function setMode(m){ui.mode=m;BT.forEach(b=>{if(b.mode)setLed(b,b.mode===m);});padLabels();}
/* TRIGGER bzw. MUTE losgelassen: wurde damit ein Pad gewählt/gesoloed, geht es zurück in den vorigen Modus */
function modeRelease(d){const H=ui.modeHold;if(!H||!d.fn||H.f!==d.fn)return;ui.modeHold=null;if(H.used&&H.prev!==ui.mode)setMode(H.prev);}
/* COPY (SHIFT + <P): Part in die Zwischenablage, Pad drücken = einfügen (auch nach Pattern-Wechsel) */
function copyToggle(){if(ui.copy){ui.copy=false;popup('msg',{t:'COPY',b:'CANCELLED'},900);return;}ui.clip=clipPart(ui.part);ui.copy=true;
  popup('msg',{t:'COPY · '+ui.clip.from,b:'PAD = PASTE',s:'OTHER PATTERN OK · SHIFT + <P = CANCEL'},3000);}
/* OKT. SEND (Plan): pro Part einschaltbar. OKT. SEND halten + OKT -/+ (oder BAR < >) = Oktave aller Send-Parts hoch/runter.
   Parts mit CUTOFF auf 0, LEVEL auf 0 oder gemutet werden nicht gepitcht */
const oktSilent=p=>{const P=cur.parts[p];return ui.muted.has(p)||P.lvl<.01||(!P.ftrack&&P.cut<.01&&/^LPF|LADDER|ACID|DIODE|JUNO|POLY|P-5|MG|E-LPF|OB SVF LP|MS-20 LP/.test(FILTERS[P.ftype]));};
function oktShift(dir){const ps=cur.parts.map((P,p)=>p).filter(p=>cur.parts[p].oktSend);let n=0;undoKind('okt'+(++undoN));
  ps.forEach(p=>{if(oktSilent(p))return;const P=cur.parts[p],o=clamp(P.oct+dir,-5,5);if(o!==P.oct){P.oct=o;n++;}});if(n)dirty();padLabels(true);
  popup('msg',{t:'OKT. SEND '+(dir>0?'+1':'-1'),b:n+(n===1?' PART':' PARTS')+' PITCHED',s:ps.length?ps.map(p=>pad2(p+1)).join(' ').slice(0,38):'NO PART HAS OKT. SEND'},99999);}
function oktToggle(p){const P=cur.parts[p];undoKind('okts'+(++undoN));P.oktSend=!P.oktSend;dirty();if(p===ui.part)setLed(CTRL.oktsend,P.oktSend);
  popup('msg',{t:'OKT. SEND · PART '+pad2(p+1),b:P.oktSend?'ON':'OFF',s:PARTS[p]+(P.oktSend?' FOLLOWS OKT -/+':'')},99999);}
/* SOLO (Plan): gedrückt halten, Pads wählen die Parts. Egal ob gemutet. OKT -/+ (oder BAR < >) = Oktave der Solo-Parts. Loslassen = alles wie vorher */
function soloOct(dir){if(!ui.solo.size){popup('msg',{t:'SOLO',b:'PICK PADS FIRST'},99999);return;}const H=ui.soloHold;
  ui.solo.forEach(p=>{const P=cur.parts[p];if(!(p in H.oct))H.oct[p]=P.oct;P.oct=clamp(P.oct+dir,-5,5);});padLabels(true);
  popup('msg',{t:'SOLO · OCTAVE',b:[...ui.solo].map(p=>pad2(p+1)+(cur.parts[p].oct>0?'+':'')+cur.parts[p].oct).join(' ').slice(0,20),s:'RELEASE SOLO = BACK'},99999);}
/* Taste losgelassen (SOLO, OKT. SEND) */
function btnUp(d){
  if(d.id==='solo'&&ui.soloHold){const H=ui.soloHold;ui.soloHold=null;for(const p in H.oct)cur.parts[p].oct=H.oct[p];ui.solo.clear();evLog('solo',[]);padLabels(true);ui.popup=null;}
  if(d.id==='oktsend'&&ui.oktHold){const H=ui.oktHold;ui.oktHold=null;ui.popup=null;if(!H.used)oktToggle(ui.part);}}
/* PARAMETRIC EQ Presets (Plan S. 2) */
const EQ_PRESETS=[['FLAT',{lc:0,hc:1,eqL:.5,eqM:.5,eqH:.5,eqLQ:0,eqHQ:0,eqMQ:.347,eqLF:.434,eqF:.5,eqHF:.593}],
  ['30 HZ + 18 KHZ CUT',{lc:.01,hc:.994}],['40 HZ + 18 KHZ CUT',{lc:.099,hc:.994}],
  ['OLD TELEPHONE',{lc:.814,hc:.532,eqL:.5,eqH:.5,eqM:.767,eqF:.554,eqMQ:.42,eqLQ:0,eqHQ:0}],
  ['KICK',{lc:.0,hc:1,eqL:.633,eqLF:.25,eqLQ:.3,eqM:.333,eqF:.204,eqMQ:.45,eqH:.633,eqHF:.377,eqHQ:.3}]];
function eqPreset(k){const P=cur.parts[ui.part],pr=EQ_PRESETS[k];undoKind('eqp'+(++undoN));Object.assign(P,EQ_PRESETS[0][1],pr[1]);P.eqPre=k;dirty();applyChannel(ui.part);refreshKnobs();popup('eqedit',{},600000);}
function eqPresetNext(){const P=cur.parts[ui.part];eqPreset(((P.eqPre??0)+1)%EQ_PRESETS.length);}
function act(d){
  const id=d.id,P=cur.parts[ui.part];undoKind('b'+id+(++undoN));
  if(d.fn){func(d);return;}
  if(d.ifxOn!==undefined){sh();const f=P.fx[d.ifxOn];f.on=!f.on;dirty();applyChannel(ui.part);ifxLeds();popup('ifx',{flash:d.ifxOn},1800);return;}
  if(d.mfxHold!==undefined){const i=d.mfxHold,m=ui.mfx[i];m.hold=!m.hold;setLed(d,m.hold);if(!m.hold)xyRelease(i,true);drawMFXPad(i);drawOLED(i);popup('xy',{i});return;}
  if(id==='mfxon'||id==='gatearp'||id==='padmode'){const md=id==='mfxon'?0:id==='gatearp'?1:2;
    if(sh()){openMenuItem('PATTERN SET',['MFX TYPE','GATE ARP','SCALE'][md]);return;}   // SHIFT + MFX = MFX-Typ-Menü (VALUE), bleibt bis EXIT
    tsRelease();arpRelease();const m=ui.mfx[0];if(m.touch&&!m.hold)xyRelease(0,true);ui.padMode=md;padModeLeds();drawMFXPad(0);drawOLED(0);
    popup('msg',{t:'TOUCH PAD',b:PADMODES[md],s:['X/Y = MASTER FX '+NUM.mfx(m.type),'X = GATE SPEED · Y = LENGTH · '+NUM.arp(cur.gateArp||0),'X = '+KEYS[cur.key]+' '+SCALES[cur.scale]+' · '+(G.tsRange||2)+' OCT'][md]},2000);return;}
  if(d.mfxOn!==undefined){const i=d.mfxOn,m=ui.mfx[i];m.on=!m.on;cur.mfx[i].on=m.on;dirty();setLed(d,m.on);E.mfx[i].update();drawMFXPad(i);drawOLED(i);popup('msg',{t:'MASTER FX '+(i+1),b:m.on?'FX ON':'FX OFF',s:MFXS[m.type]});return;}
  switch(id){
    case 'menu':if(sh()){ui.menu=MENU.findIndex(m=>m.t==='MIDI');ui.menuItem=0;}else{ui.menu=ui.menu<0?0:-1;ui.menuItem=0;}ui.menuEdit=false;ui.popup=null;break;
    case 'exit':sh();if(ui.fill){fillCancel();break;}if(ui.menuEdit)ui.menuEdit=false;else{ui.menu=-1;ui.write=null;}ui.popup=null;break;
    case 'enter':if(ui.fill){fillExec();break;}if(ui.menu>=0){const it=MENU[ui.menu].items[ui.menuItem];if(ui.menuEdit)ui.menuEdit=false;else if(it.enter)it.enter();else if(it.adj)ui.menuEdit=true;}else popup('msg',{t:'ENTER',b:'OK',s:'MENU = SETTINGS'});break;
    case 'pgprev':case 'pgnext':if(sh()){if(id==='pgprev')doUndo();else doRedo();break;}ui.menu=ui.menu<0?0:(ui.menu+(id==='pgnext'?1:-1)+MENU.length)%MENU.length;ui.menuItem=0;ui.menuEdit=false;ui.popup=null;break;
    case 'tubeon':if(sh()){const on=!cur.parts.some(x=>x.tube);cur.parts.forEach(x=>x.tube=on);popup('msg',{t:'TUBE · ALL PARTS',b:on?'ALL THROUGH TUBE':'ALL CLEAN',s:'SHIFT + TUBE ON'});}
      else{P.tube=!P.tube;popup('msg',{t:'TUBE · PART '+pad2(ui.part+1),b:P.tube?(G.warm<1?'WARMING UP':'TUBE ON'):'CLEAN',s:P.tube?PARTS[ui.part]+' GOES THROUGH THE ECC82':PARTS[ui.part]+' BYPASSES THE TUBE'});}
      dirty();setLed(d,P.tube);applyGlobals();refreshKnobs();break;
    case 'smpedit':case 'stepedit':{const t=id==='smpedit'?'SAMPLE EDIT':'STEP EDIT',k=MENU.findIndex(m=>m.t===t);ui.menu=ui.menu===k?-1:k;ui.menuItem=0;ui.menuEdit=false;ui.popup=null;
      if(id==='stepedit')ui.stepSel=ui.pageSel*16;setLed(CTRL.smpedit,ui.menu>=0&&MENU[ui.menu].t==='SAMPLE EDIT');setLed(CTRL.stepedit,ui.menu>=0&&MENU[ui.menu].t==='STEP EDIT');break;}
    case 'inrec':(async()=>{if(!E.in){const ok=await inputOn();syncInBtn();if(!ok){popup('msg',{t:'AUDIO IN',b:'NO INPUT',s:'MICROPHONE PERMISSION NEEDED'},2600);return;}}ui.inRec=true;setLed(d,true);if(!ui.playing)setPlaying(true);popup('msg',{t:'SAMPLING',b:'NEXT BAR',s:'INPUT > PART '+pad2(ui.part+1)+' · 1 BAR'},1800);})();break;
    case 'reverse':P.reverse=!P.reverse;partLeds();dirty();if(P.stretch)scheduleStretch(ui.part);popup('msg',{t:'REVERSE · PART '+pad2(ui.part+1),b:P.reverse?'REVERSE ON':'FORWARD',s:P.src?SRC[P.src].n:'NO SAMPLE ON THIS PART'});break;
    case 'stretch':P.stretch=(P.stretch+1)%3;partLeds();dirty();if(P.stretch)scheduleStretch(ui.part);popup('stretch',{},2600);break;
    case 'bpmsync':P.sync=!P.sync;setLed(d,P.sync);applyChannel(ui.part);popup('msg',{t:'MODULATION',b:P.sync?'BPM SYNC':'FREE RUN',s:MODS[P.mtype]});break;
    case 'mono':if(sh()){P.choke=(P.choke+1)%5;dirty();popup('msg',{t:'CHOKE · PART '+pad2(ui.part+1),b:P.choke?'GROUP '+P.choke:'OFF',s:P.choke?'PARTS IN GROUP '+P.choke+' CUT EACH OTHER':'NO CHOKE'},1800);break;}
      P.voice=((P.voice??0)+1)%4;P.mono=P.voice<2;setLed(d,P.voice<2);dirty();popup('msg',{t:'VOICE ASSIGN · PART '+pad2(ui.part+1),b:VOICES[P.voice].split(' · ')[0],s:VOICES[P.voice].split(' · ')[1]||(P.voice===2?'NOTES OVERLAP':'')},1600);break;
    case 'egon':if(sh()){if(ui.popup&&ui.popup.type==='egedit'){ui.popup=null;break;}if(ui.egSel==null)ui.egSel=1;if(!P.egOn){P.egOn=true;setLed(d,true);dirty();}ui.menu=-1;popup('egedit',{},600000);break;}
      P.egOn=!P.egOn;setLed(d,P.egOn);dirty();popup('eg',{},2200);break;
    case 'glue':P.glueOn=!P.glueOn;setLed(d,P.glueOn);dirty();applyRouting();popup('msg',{t:'BASS GLUE · PART '+pad2(ui.part+1),b:P.glueOn?'DISTORTS WITH BASS':'CLEAN, SEPARATE',s:P.glueOn?'SHARES THE GLUE SATURATION':'NO SHARED SATURATION'});break;
    case 'send':P.send=!P.send;setLed(d,P.send);dirty();applyRouting();popup('msg',{t:'MFX SEND · PART '+pad2(ui.part+1),b:P.send?'MFX + ROLL ON':'MFX + ROLL OFF',s:ui.rec?'REC: MFX ONLY ON SELECTED PART':PARTS[ui.part]});break;
    case 'ifxdn':case 'ifxup':{const up=id==='ifxup';ui.fxSel=sh()?(up?4:0):clamp(ui.fxSel+(up?1:-1),0,4);ifxLeds();refreshKnob(CTRL.ifxtype);refreshKnob(CTRL.ifxedit);showIFX();break;}
    case 'inmon':(async()=>{if(!E.in){const ok=await inputOn();syncInBtn();if(!ok){popup('msg',{t:'AUDIO IN',b:'NO INPUT',s:'MICROPHONE PERMISSION NEEDED'},2600);return;}}G.inMon=!G.inMon;setLed(d,G.inMon);applyInput();popup('msg',{t:'AUDIO IN',b:G.inMon?'MONITOR ON':'MONITOR OFF',s:'LIMITER ACTIVE · NO CLIPPING'});})();break;
    case 'partprev':if(sh()){copyToggle();break;}   // SHIFT + <P = COPY (dann Pad = einfügen, auch in anderem Pattern)
    case 'partnext':setPart((ui.part+(id==='partnext'?1:PARTS.length-1))%PARTS.length);break;
    /* ◁ ▷: Takt wählen. SHIFT = Länge. OKT SEND halten = Oktave der Send-Parts. SOLO halten = Oktave der Solo-Parts (nur solange gehalten) */
    case 'bardn':case 'barup':{const dir=id==='barup'?1:-1;
      if(CTRL.oktsend.down&&ui.oktHold){ui.oktHold.used=true;oktShift(dir);break;}
      if(CTRL.solo.down&&ui.soloHold){soloOct(dir);break;}
      if(sh()){setLength(dir);break;}
      pageMove(dir);break;}
    case 'bw':if(sh()){eqPresetNext();break;}ui.bw=!ui.bw;setLed(d,ui.bw);ui.eqBand=ui.eqBand??1;refreshKnobs();popup('eqedit',{},600000);break;
    case 'solo':if(sh()){ui.drop=!ui.drop;evLog('drop',ui.drop);popup('msg',{t:'DROP',b:ui.drop?'DROP!':'BACK IN',s:ui.drop?'ONLY KICK + TOK':'ALL PARTS PLAYING'});break;}
      ui.soloHold={oct:{}};popup('msg',{t:'SOLO',b:'HOLD + PADS',s:'OKT -/+ = OCTAVE · RELEASE = END'},99999);break;
    case 'oktsend':ui.oktHold={used:false};popup('msg',{t:'OKT. SEND',b:'HOLD + PADS / OKT -/+',s:'TAP = PART '+pad2(ui.part+1)+' ON/OFF'},99999);break;
    case 'rec':if(sh()){ui.resample=!ui.resample;setLed(d,ui.resample);popup('msg',{t:'RESAMPLING',b:ui.resample?'ARMED':'OFF',s:ui.resample?'NEXT BAR > NEW SAMPLE':'SHIFT + REC'});if(ui.resample&&!ui.playing)setPlaying(true);break;}
      ui.rec=!ui.rec;setLed(d,ui.rec);applyRouting();popup('msg',{t:'RECORD',b:ui.rec?'REC ARMED':'REC OFF',s:ui.rec?'PADS, KNOBS + MFX ONLY ON PART '+pad2(ui.part+1):''});break;
    case 'stop':if(sh()){panic();popup('msg',{t:'PANIC',b:'ALL NOTES OFF'},1000);}setPlaying(false);ui.paused=false;seq.step=0;ui.dispStep=0;break;
    case 'play':if(sh()){seq.step=0;ui.dispStep=0;ui.paused=false;if(ui.playing){seq.next=now()+.03;visQ.length=0;}else setPlaying(true);popup('msg',{t:'RESTART',b:'FROM STEP 1'},800);}
      else if(ui.playing){setPlaying(false);ui.paused=true;popup('msg',{t:'PAUSE',b:'STEP '+(ui.dispStep+1),s:'PLAY = GO ON · STOP = BACK TO 1'},1000);}else{ui.paused=false;setPlaying(true);}break;
    case 'tap':if(sh()){openMenuItem('PATTERN SET','BPM');break;}tap();break;   // SHIFT + TAP = BPM-Menü (Plan: BPM ins Menü)
    case 'rollsend':P.rollSend=P.rollSend===false;setLed(d,P.rollSend);dirty();applyRouting();popup('msg',{t:'ROLL SEND · PART '+pad2(ui.part+1),b:P.rollSend?'ROLL ON':'NO ROLL',s:P.rollSend?PARTS[ui.part]+' ROLLS WITH ROLL':'ROLL LEAVES '+PARTS[ui.part]+' ALONE'},1400);break;
    case 'save':save(sh());break;
    case 'motion':if(sh()){pushUndo();cur.motion[ui.part]={};dirty();popup('msg',{t:'MOTION · PART '+pad2(ui.part+1),b:'CLEARED',s:'KNOB + MFX MOVES DELETED'});}
      else{ui.motion=!ui.motion;setLed(d,ui.motion);popup('msg',{t:'MOTION SEQ',b:ui.motion?'PLAYBACK ON':'PLAYBACK OFF',s:'REC + PLAY RECORDS KNOBS AUTOMATICALLY'});}break;
    case 'accent':ui.accent=!ui.accent;setLed(d,ui.accent);popup('msg',{t:'ACCENT',b:ui.accent?'ON':'OFF',s:'QUARTER NOTES LOUDER'});break;
    case 'resample':ui.resample=!ui.resample;setLed(d,ui.resample);popup('msg',{t:'RESAMPLING',b:ui.resample?'ARMED':'OFF',s:ui.resample?'NEXT BAR > NEW SAMPLE':''});if(ui.resample&&!ui.playing)setPlaying(true);break;
    case 'tlock':G.tlock=(G.tlock+1)%3;popup('msg',{t:'TEMPO LOCK',b:TLOCK[G.tlock],s:['NEW PATTERN = ITS OWN BPM','BPM STAYS WHEN YOU SWITCH','BPM GLIDES IN '+G.rampBars+' BARS TO NEW PATTERN'][G.tlock]},2200);break;
  }
}
function recordHit(p,note,vel){undoKind('r'+(++undoN));
  /* REC an und Sequencer steht: der erste Ton startet sofort bei Step 1 und wird dort aufgenommen */
  if(ui.rec&&!ui.playing&&ready&&p<NSEQ){seq.step=0;ui.dispStep=0;ui.paused=false;ui.recAuto=true;setPlaying(true);seq.next=now()+.002;ui.dispT=seq.next;ui.skipFirst={p,s:0};
    cur.steps[p][0]=1;cur.notes[p][0]=note;cur.vel[p][0]=Math.round(vel*127);cur.gate[p][0]=0;cur.rat[p][0]=1;dirty();popup('msg',{t:'RECORDING',b:'GO!',s:'STARTED WITH YOUR FIRST NOTE'},900);return 0;}
  if(!(ui.rec&&ui.playing)||p>=NSEQ)return -1;const late=now()-(ui.dispT||0)>stepDur(ui.dispStep)/2,s=(ui.dispStep+(late?1:0))%cur.last;
  cur.steps[p][s]=1;cur.notes[p][s]=note;cur.vel[p][s]=Math.round(vel*127);cur.gate[p][s]=0;cur.rat[p][s]=1;dirty();return s;
}
/* TRIGGER MODE (Global) wie Electribe 2: NORMAL = Grundton, SEQ 1ST = erster aufgenommener Ton, SEQ PLAY = Part-Sequenz läuft solange das Pad gehalten wird */
function trigNote(i){if(G.trigMode===1&&i<NSEQ){const a=cur.steps[i];for(let s=0;s<cur.last;s++)if(a[s])return cur.notes[i][s];}return 57;}
/* VELOCITY CURVE (Global) */
const velCurve=v=>{switch(G.velCurve){case 0:return Math.pow(v,1.6);case 2:return Math.pow(v,.6);case 3:return 96/127;default:return v;}};
function padPress(i,pv){
  ui.padFlash[i]=performance.now();undoKind('p'+(++undoN));const vel=cur.parts[i<NSEQ&&ui.mode==='TRIGGER'?i:ui.part]?.trgVel&&pv!=null?velCurve(pv):PADVEL;const m=ui.mode,page=ui.pageSel,P=cur.parts[ui.part],h={id:'p'+i+'.'+performance.now(),t:now(),edited:false,toggled:false,rec:[]},hi=i>=NSEQ;ui.held.set(i,h);
  if(ui.fill&&hi){h.done=true;fillBar(i-NSEQ);return;}
  if(CTRL.solo.down&&ui.soloHold){h.done=true;if(hi)return;ui.solo.has(i)?ui.solo.delete(i):ui.solo.add(i);evLog('solo',[...ui.solo]);popup('solo',{},99999);return;}
  if(CTRL.oktsend.down&&ui.oktHold){h.done=true;ui.oktHold.used=true;oktToggle(i);return;}
  if(FN.TRIGGER.down&&ui.modeHold){h.done=true;ui.modeHold.used=true;setPart(i);return;}
  if(FN.MUTE.down&&ui.modeHold){h.done=true;ui.modeHold.used=true;if(hi)return;ui.solo.has(i)?ui.solo.delete(i):ui.solo.add(i);evLog('solo',[...ui.solo]);popup('solo',{},1500);return;}
  const s=sh();
  if(ui.copy&&ui.clip){const C=ui.clip;pasteClip(C,i);ui.copy=false;setLed(FN.COPY,false);popup('msg',{t:'PASTE',b:C.from.split(' ').slice(0,2).join(' ')+' > P'+pad2(i+1),s:C.seq&&i<NSEQ?'SOUND + STEPS + MOTION':'SOUND ONLY'});h.done=true;return;}
  if((m==='SEQUENCER'||m==='STEP JUMP')&&hi&&!s){const b=i-NSEQ;h.done=true;if(b>=cur.last/16){popup('msg',{t:'BAR '+(b+1),b:'NOT IN PATTERN',s:'SHIFT + BAR> = LONGER PATTERN'},1200);return;}
    if(m==='STEP JUMP'){seq.step=b*16;ui.pageSel=b;popup('msg',{t:'STEP JUMP',b:'BAR '+(b+1)},800);}
    else{ui.pageSel=b;popup('msg',{t:'BAR',b:'BAR '+(b+1)+' / '+cur.last/16,s:'STEPS '+(b*16+1)+'-'+(b*16+16)+' · STAYS WHILE PLAYING'},1000);}return;}
  if(m==='ERASE'){h.done=true;if(s)clearPart(i);else if(!hi){pushUndo();cur.steps[i].fill(0);dirty();popup('msg',{t:'ERASE',b:'PART '+pad2(i+1),s:'STEPS CLEARED (UNDO) · SHIFT = CLEAR ALL'});}return;}
  if(s){setPart(i);h.done=true;return;}
  if(m==='KEYBOARD'||m==='CHORD'){
    const n=kbNote(i),notes=m==='CHORD'?chordOf(n):[n];h.notes=notes;h.notesPart=ui.part;
    if(ready&&!(ui.padMode===1&&ui.arp.on)){h.part=ui.part;notes.forEach(x=>trigger(ui.part,now(),x,vel,{held:true,id:h.id}));const rs=recordHit(ui.part,n,vel);h.rec.push([ui.part,rs]);
      if(rs>=0&&ui.part<NSEQ){if(notes.length>1)cur.xn[ui.part][rs]=notes.slice(1,4);else delete cur.xn[ui.part][rs];}}
    const real=partNote(P,n);popup('msg',{t:m+' · PART '+pad2(ui.part+1),b:m==='CHORD'?noteName(real)+(chordOf(n)[1]-n===3?' MIN':' MAJ'):noteName(real),s:KEYS[cur.key]+' '+SCALES[cur.scale]+(inScale(n)?' · IN SCALE':' · OUTSIDE SCALE')},900);return;}
  if(m==='TRIGGER'){setPart(i,true);if(ui.padMode===1&&ui.arp.on){h.arpPart=i;return;}
    if(ready){const tn=trigNote(i);if(G.trigMode===2&&!ui.playing&&i<NSEQ){h.seqPlay=true;ui.solo=new Set([i]);seq.step=0;setPlaying(true);}else{trigger(i,now(),tn,vel,{held:true,id:h.id});h.rec.push([i,recordHit(i,tn,vel)]);h.part=i;h.trigPart=i;}}popup('wave',{p:i,t0:now()},1600);return;}   // Plan: beim Anschlagen die Welle zeigen, nicht den Sample-Namen
  if(hi){h.done=true;return;}
  if(m==='SEQUENCER'){if(ui.part>=NSEQ){h.done=true;popup('msg',{t:'PART '+pad2(ui.part+1)+' '+PARTS[ui.part],b:'LIVE PART',s:'NO STEPS · SHIFT + PAD 1-16 = SEQ PART'},1600);return;}
    const st=page*16+i;h.step=st;ui.stepSel=st;if(!cur.steps[ui.part][st]){pushUndo();cur.steps[ui.part][st]=1;cur.gate[ui.part][st]=0;cur.rat[ui.part][st]=1;h.toggled=true;dirty();
      if(!ui.playing&&ready)trigger(ui.part,now(),cur.notes[ui.part][st],cur.vel[ui.part][st]/127,{gate:stepLen()});}
    popup('vel',{s:st},1200);}
  else if(m==='MUTE'){ui.muted.has(i)?ui.muted.delete(i):ui.muted.add(i);saveMutes();popup('mute');}
  else if(m==='STEP JUMP'){const st=page*16+i;seq.step=st;popup('msg',{t:'STEP JUMP',b:'STEP '+(st+1),s:'BAR '+(page+1)},900);}
}
function padRelease(i){
  const h=ui.held.get(i);if(!h)return;ui.held.delete(i);if(h.seqPlay){setPlaying(false);ui.solo.clear();seq.step=0;return;}if(h.done)return;
  if(h.part!==undefined&&ready){noteOff(h.part,h.id,now());const g=clamp(Math.round((now()-h.t)/stepLen()*4),1,255);h.rec.forEach(([p,s])=>{if(s>=0)cur.gate[p][s]=g;});}
  if(ui.mode==='SEQUENCER'&&h.step!==undefined&&!h.toggled&&!h.edited){pushUndo();cur.steps[ui.part][h.step]=0;dirty();popup('msg',{t:'STEP EDIT · PART '+pad2(ui.part+1),b:'STEP '+(h.step+1)+' OFF'},700);}
}

/* ---------- Regler ↔ Parameter ---------- */
const LISTS={src:()=>SRC.length,osc:()=>OSCS.length,len:()=>8,ftype:()=>FILTERS.length,mtype:()=>MODS.length,fxType:()=>IFXS.length};
/* Nummern überall: so sieht man, auf welcher Nummer man gerade ist */
const NUM={src:i=>i?pad3(i)+' '+SRC[i].n:'000 OFF',osc:i=>pad2(i)+' '+OSCS[i],ftype:i=>pad2(i+1)+' '+FILTERS[i],mtype:i=>pad2(i+1)+' '+MODS[i],fxType:i=>pad3(i+1)+' '+IFXS[i],
  mfx:i=>pad2(i+1)+' '+MFXS[i],roll:i=>pad2(i+1)+' '+ROLLS[i],arp:i=>pad2(i+1)+' '+GATEARPS[i][0],chord:i=>CHORDSETS[i],groove:i=>pad2(i)+' '+GROOVES[i],beat:i=>BEATS[i],scale:i=>pad2(i+1)+' '+SCALES[i]};
const selFx=()=>{const P=cur.parts[ui.part];while(P.fx.length<=ui.fxSel)P.fx.push(emptyFx());return P.fx[ui.fxSel];};
function listInfo(d){if(d.mfx!==undefined)return{n:MFXS.length,i:ui.mfx[d.mfx].type};const P=cur.parts[ui.part];
  if(d.p==='fxType')return{n:IFXS.length,i:selFx().type};return{n:LISTS[d.p](),i:P[d.p]};}
const CZ=.08;
const rawFromV=v=>v<.5?v*(1-CZ):v>.5?.5+CZ/2+(v-.5)*(1-CZ):.5;
const vFromRaw=r=>r<.5-CZ/2?r/(1-CZ):r>.5+CZ/2?.5+(r-.5-CZ/2)/(1-CZ):.5;
/* Welcher Parameter ein Regler gerade bedient. EQ (Plan): LOW/MID/HIGH = Gain, mit BW an = Bandbreite. FREQ = Frequenz des gewählten Bands */
const EQK={g:['eqL','eqM','eqH'],q:['eqLQ','eqMQ','eqHQ'],f:['eqLF','eqF','eqHF']};
const EQDEF={eqLQ:0,eqMQ:.347,eqHQ:0,eqLF:.434,eqF:.5,eqHF:.593,hc:1};
function keyOf(d){if(d.eq!=null){if(d.eq<3)return ui.bw?EQK.q[d.eq]:d.p;if(d.eq===3)return EQK.f[ui.eqBand??1];}return d.p;}
function pget(P,k){const v=P[k];if(v!=null)return v;if(k==='egDL')return P.egS||0;if(k in EQDEF)return EQDEF[k];if(k==='egAL')return 1;if(k==='egCR'||k==='edit2')return .5;if(k==='mEgT')return P.speed??.45;return 0;}
function knobGet(d){
  if(d.endless)return d.raw||0;
  if(d.det==='list'){const L=listInfo(d);return L.n>1?L.i/(L.n-1):0;}
  if(d.g){switch(d.id){case 'master':return G.master;case 'phones':return G.phones;case 'rolltype':return ui.rollType/(ROLLS.length-1);}}
  const P=cur.parts[ui.part],k=keyOf(d);
  switch(k){case 'pitch':return P.pitch/48+.5;case 'fxEdit':return selFx().edit;default:return pget(P,k);}
}
function knobSet(d,v){
  v=clamp(v);const P=cur.parts[ui.part];
  if(d.g){switch(d.id){case 'master':G.master=v;break;case 'phones':G.phones=v;break;}applyGlobals();return;}
  if(d.eq!=null&&d.eq<3)ui.eqBand=ui.eqSel=d.eq;
  const key=keyOf(d),before=key==='fxEdit'?selFx().edit:P[key];undoKind('k'+ui.part+':'+(key==='fxEdit'?'fx'+ui.fxSel:key));
  switch(key){case 'pitch':P.pitch=Math.round((v-.5)*48);break;case 'fxEdit':selFx().edit=v;break;default:P[key]=v;}
  const after=key==='fxEdit'?selFx().edit:P[key];if(after===before)return;
  afterPartChange(key);
  if(ui.rec&&ui.playing){const k=key==='fxEdit'?'fx'+ui.fxSel:key;rec(ui.part,ui.dispStep,k,after);}
}
function afterPartChange(p){dirty();const P=cur.parts[ui.part];if(['src','pitch','len','lenSt'].includes(p)&&P.stretch)scheduleStretch(ui.part);
  if(['eqL','eqM','eqF','eqH','lc','hc','eqLQ','eqMQ','eqHQ','eqLF','eqHF'].includes(p))delete P.eqPre;   // von Hand verändert = kein Preset mehr
  if(['lvl','pan','mtype','speed','depth','fxType','fxEdit','eqL','eqM','eqF','eqH','eqD','eqX','lc','hc','eqLQ','eqMQ','eqHQ','eqLF','eqHF'].includes(p))applyChannel(ui.part);
  if(p==='cut'||p==='reso'||(p==='pitch'&&cur.parts[ui.part].ftrack))liveFilter(ui.part);
  if(['driveA','driveB','tubeMix'].includes(p)&&E)applyTube(ui.part);if(p==='glueDrv')applyRouting();}
function tickKnob(d,n){
  const s=shiftNow(),step=s?10:1;if(d.det!=='pattern')undoKind('t'+ui.part+':'+d.id);
  if(d.det==='pattern'){if(G.ptnLock&&!s&&!(ui.write&&ui.write.stage==='as')){popup('msg',{t:'PTN. CHANGE LOCK',b:'HOLD SHIFT',s:'GLOBAL PARAMETER'},1200);return;}if(G.ptnLock&&s){queuePattern((ui.pendingPat||ui.pattern)+n);return;}queuePattern((ui.write&&ui.write.stage==='as'?ui.write.target:(ui.pendingPat||ui.pattern))+n*step);return;}
  if(d.det==='tube'){const P=cur.parts[ui.part];P.tubeMix=clamp(Math.round(P.tubeMix*20+n)/20);dirty();E&&applyTube(ui.part);return;}
  if(d.mfx!==undefined){const m=ui.mfx[d.mfx],t=clamp(m.type+n*step,0,MFXS.length-1);if(t!==m.type){m.type=t;cur.mfx[d.mfx].type=t;dirty();E&&E.mfx[d.mfx].update();drawOLED(d.mfx);drawMFXPad(d.mfx);}return;}
  if(d.p==='ftype'&&s){const P=cur.parts[ui.part];setTrack(P,n>0);dirty();liveFilter(ui.part);refreshKnob(CTRL.cutoff);popup('msg',{t:'FILTER TRACK · PART '+pad2(ui.part+1),b:P.ftrack?'TRACK ON':'TRACK OFF',s:P.ftrack?'RESO FOLLOWS THE SOUND · TONE '+Math.round(toneHz(P,57))+' HZ':'CUTOFF IN HZ'},2000);return;}
  const L=listInfo(d),P=cur.parts[ui.part],i=clamp(L.i+n*step,0,L.n-1);if(i===L.i)return;
  /* SAMPLE und OSC schließen sich aus: der zuletzt gedrehte Regler bestimmt die Klangquelle */
  if(d.p==='fxType'){selFx().type=i;}else if(d.p==='src'){P.src=i;if(i){P.osc=0;if(P.edit>.6)P.edit=0;}}
  else if(d.p==='osc'){P.osc=i;if(i){P.src=0;P.wave=clamp(P.wave|0,0,emxWaves(i).length-1);if(i===14||i===15)emxPcmLoad(P.wave);}}else P[d.p]=i;afterPartChange(d.p);
}
/* EMX-Anzeige der EDIT-Regler: Name + Wert wie auf der EMX (0..127, -63..+63, Harmonische, Akkord, Voicing) */
function emxEditStr(P,k){const T=P.osc,ex=EMX[T];if(!ex)return'-';const v=clamp(k===1?(P.edit??0):(P.edit2??.5)),m=k===1?(T===3?'chord':ex.m1||'u'):ex.m2;
  const val=m==='pm'?((v-.5)*126>=.5?'+':'')+Math.round((v-.5)*126):m==='h'?'x'+emxH(v).toFixed(2):m==='v'?((v>.5?'+':'')+Math.round((v-.5)*6)):m==='chord'?EMX_CHORDS[Math.round(v*15)][0]:pad3(Math.round(v*127));
  return(k===1?ex.e1:ex.e2)+' '+val;}
const emxWaveName=P=>{const W=emxWaves(P.osc);return W[clamp(P.wave|0,0,W.length-1)]||'-';};
const msStr=s=>s<1?Math.round(s*1000)+' MS':s.toFixed(2)+' S';
const hzStr=f=>f>=1000?(f/1000).toFixed(f>=10000?1:2)+' KHZ':Math.round(f)+' HZ';
const pctStr=v=>Math.round(v*100)+' %';
function eqStr(P,k){const v=pget(P,k);switch(k){case 'eqL':case 'eqM':case 'eqH':{const n=eqDb(v);return(n>0?'+':'')+n+' DB';}
  case 'eqLQ':case 'eqHQ':return v<.02?'SHELF':'Q '+eqQ(v).toFixed(2);case 'eqMQ':return 'Q '+eqQ(v).toFixed(2);
  case 'eqLF':return 'LOW '+hzStr(eqLHz(v));case 'eqF':return 'MID '+hzStr(eqFHz(v));case 'eqHF':return 'HIGH '+hzStr(eqHHz(v));
  case 'lc':return v<.01?'OFF':hzStr(lcHz(v));case 'hc':return v>=.999?'OFF':hzStr(hcHz(v));}return pctStr(v);}
function valStr(d){
  if(d.endless){if(!d.wave)return'VALUE';const P=cur.parts[ui.part];return P.osc?NUM.osc(P.osc)+' · '+emxWaveName(P):'OSC OFF';}
  const P=cur.parts[ui.part],v=knobGet(d);
  if(d.eq!=null&&d.eq<4)return eqStr(P,keyOf(d));
  switch(d.id){case 'rolltype':return NUM.roll(ui.rollType);
    case 'master':case 'phones':return v<.02?'-INF DB':(20*Math.log10(v*v*1.15)).toFixed(1)+' DB';case 'tubemix':return Math.round(P.tubeMix*100)+' %'+(P.tube?'':' (OFF)');
    case 'driveA':case 'driveB':return pad3(Math.round(v*127))+(P.tube?'':' (OFF)');
    case 'mfxtype2':return NUM.mfx(ui.mfx[1].type);case 'ingain':return(-18+v*36).toFixed(1)+' DB';
    case 'sample':return NUM.src(P.src);case 'osc':return P.osc?NUM.osc(P.osc)+' · '+emxWaveName(P):'00 OFF · SAMPLE';case 'pitch':return(P.pitch>0?'+':'')+P.pitch+' ST';
    case 'edit':return P.osc?emxEditStr(P,1):P.src?'PUNCH '+pad3(Math.round(v*127)):'-';
    case 'edit2':return P.osc?emxEditStr(P,2):'-';
    case 'ftype':return NUM.ftype(P.ftype);case 'mtype':return NUM.mtype(P.mtype);case 'ifxtype':return NUM.fxType(selFx().type);
    case 'pan':{const n=Math.round((v-.5)*126);return n===0?'CENTER':(n<0?'L'+(-n):'R'+n);}
    case 'egint':{const n=Math.round((v-.5)*126);return(n>0?'+':'')+n;}
    case 'attack':return P.egOn?msStr(.0015+P.att*P.att*1.5):'(EG OFF)';
    case 'decay':return P.egOn?(P.dec>.97?'HOLD':msStr(.03+P.dec*P.dec*3.5)):'GATE '+gateSteps(v)+' ST';
    case 'sustain':return 'TIME '+msStr(egSTT(P));case 'release':return msStr(egRelT(P));
    case 'egal':case 'egdl':case 'egs':return pctStr(v);
    case 'egcr':{const n=Math.round((v-.5)*126);return(n>0?'+':'')+n+(Math.abs(n)<3?' GERADE':n>0?' KNACKIG':' WEICH');}
    case 'speed':{const M=modInfo(P.mtype);if(M&&M.eg)return '(EG = EG TIME)';if(M&&M.bpm)return SYNCDIV[syncIdx(P)][0];return lfoRate(P).toFixed(2)+' HZ';}
    case 'egtime':{const M=modInfo(P.mtype);if(M&&M.eg&&M.bpm)return SYNCDIV[Math.round(clamp(v)*(SYNCDIV.length-1))][0]+' EG';return msStr(modEgT(P))+(M&&M.eg?'':' (EG TYPES)');}
    case 'start':return(v*100).toFixed(1)+' %'+(P.src?'':' (SAMPLE)');
    case 'depth':{const M=modInfo(P.mtype);return pad3(Math.round(v*127))+' > '+(M?M.dst:'-');}
    case 'gluedrv':return pad3(Math.round(v*127))+(P.glueOn?' · GLUE ON':' · GLUE OFF');
    case 'glide':return v<.01?'OFF':Math.round((.01+v*v*.6)*1000)+' MS';
    case 'eqD':return v<.01?'CLEAN':Math.round(v*100)+' %';case 'eqX':return Math.round(v*100)+' %';
    case 'cutoff':{if(P.ftrack){const st=Math.round(trackSemis(P)),f=voiceCut(P,57);return 'TRK '+(st>0?'+':'')+st+' ST '+Math.round(f)+'HZ';}const f=cutHzOf(P),m=Math.round(12*Math.log2(f/440))+69;return Math.round(f)+' HZ '+noteName(m);}
    case 'sc':return Math.round(v*100)+' % < '+pad2(P.scSrc+1)+' '+PARTS[P.scSrc];}
  return pad3(Math.round(v*127));
}
/* Regler gedreht: EQ -> PARAMETRIC EQ im Touch-Display, ADSR -> EG EDIT, Oszillator -> OSC-Seite. Diese Seiten bleiben bis EXIT (Plan) */
const EG_SEL={attack:1,decay:3,sustain:4,release:5,egal:1,egdl:3,egs:4,egcr:8};
function knobChanged(d){
  if(!d.endless)ui.lastCtrl=d.id;
  if(d.p==='fxType'||d.p==='fxEdit')return showIFX();
  if(d.mfx!==undefined){const m=ui.mfx[d.mfx];return popup('type',{title:'MASTER FX '+(d.mfx+1),list:MFXS.map((_,k)=>NUM.mfx(k)),idx:m.type,extra:(m.on?'FX ON':'FX OFF')+' · '+XYP[m.type]});}
  if(d.eq!=null){if(d.eq<3)ui.eqBand=ui.eqSel=d.eq;else if(d.eq===3)ui.eqSel=ui.eqBand??1;ui.menu=-1;return popup('eqedit',{},600000);}
  if(EG_SEL[d.id]!=null){ui.egSel=EG_SEL[d.id];ui.menu=-1;return popup('egedit',{},600000);}
  if(d.id==='osc'||((d.id==='edit'||d.id==='edit2')&&cur.parts[ui.part].osc)){ui.menu=-1;return popup('oscedit',{},600000);}
  if(d.det==='list'){const P=cur.parts[ui.part],L=LISTS[d.p](),list=Array.from({length:L},(_,k)=>NUM[d.p](k));
    return popup('type',{title:d.sect+' · PART '+pad2(ui.part+1),list,idx:P[d.p],extra:d.p==='src'?(P.src?'OSC EDIT 1 = PUNCH':'NO SAMPLE · OSC '+(P.osc?OSCS[P.osc]:'OFF')):''});}
  popup('param',{d});
}
/* WAVE des EMX-Oszillators (OSC-Seite offen: VALUE wählt die Welle, bei PCM-Typen das Sample) */
/* WAVE: läuft am Stück durch alle 258 EMX-Kombinationen (über die Typen hinweg). Aus OSC OFF startet es bei 001 WAVEFORM SAW. SHIFT = 10er */
function waveAdj(n){const P=cur.parts[ui.part],g=P.osc?emxIdx(P.osc,P.wave):-1,g2=g<0?(n>0?0:-1):clamp(g+n*(shiftNow()?10:1),0,EMX_ALL.length-1);if(g2===g||g2<0)return;
  undoKind('wave'+ui.part);const[t,w]=EMX_ALL[g2];if(!P.osc){P.src=0;if(P.edit>.6)P.edit=0;}P.osc=t;P.wave=w;dirty();refreshKnob(CTRL.osc);
  if(t===14||t===15)[w+1,w-1,w].forEach(emxPcmLoad);/* die gewählte zuletzt = wird zuerst gerechnet */popup('oscedit',{},600000);}
/* WAVE-Rad (wie das zweite Rad der EMX): läuft durch alle 258 Kombinationen, n = 0: nur die OSC-Seite zeigen */
function waveTurn(n){ui.menu=-1;if(n){waveAdj(n);refreshKnob(CTRL.wave,true);}popup('oscedit',{},600000);}
/* PARAMETRIC EQ im Display: VALUE = Gain des gewählten Bands (BW an = Bandbreite), bei LOW CUT/HIGH CUT = Frequenz */
function eqAdj(n){const P=cur.parts[ui.part],s=ui.eqSel??1,k=s<3?(ui.bw?EQK.q[s]:EQK.g[s]):s===3?'lc':'hc';undoKind('eqv'+ui.part+':'+k);P[k]=clamp(pget(P,k)+n/127*(shiftNow()?1:3));delete P.eqPre;afterPartChange(k);refreshKnobs();popup('eqedit',{},600000);}
function valueKnob(n){
  const held=[...ui.held.entries()].find(([,h])=>h.step!==undefined);
  if(held&&ui.mode==='SEQUENCER'){const h=held[1],a=cur.vel[ui.part];undoKind('vel'+h.id);a[h.step]=clamp(a[h.step]+n*(shiftNow()?1:4),1,127);h.edited=true;dirty();popup('vel',{s:h.step},1500);return;}
  if(ui.rollHeld){ui.rollType=cur.rollType=clamp(ui.rollType+n,0,ROLLS.length-1);if(ui.rollType<5&&E.loop.on){E.loop.length(loopLen(ui.rollType),now());}popup('roll',{},99999);return;}
  if(ui.write&&ui.write.stage==='as'){queuePattern(ui.write.target+n);return;}
  const pop=ui.popup&&performance.now()<ui.popupUntil?ui.popup.type:null;
  if(pop==='egedit'){egAdj(n);return;}
  if(pop==='eqedit'){eqAdj(n);return;}
  if(pop==='oscedit'){waveAdj(n);return;}
  if(ui.menu>=0){const items=MENU[ui.menu].items;if(ui.menuEdit){const it=items[ui.menuItem];undoKind('m'+ui.menu+':'+ui.menuItem);if(it.adj)it.adj(n);}else ui.menuItem=clamp(ui.menuItem+n,0,items.length-1);return;}
  /* gerade gedrehter Regler wird noch angezeigt: VALUE stellt ihn fein */
  const t=CTRL[ui.lastCtrl];
  if((pop==='param'||pop==='type')&&t&&t.kind==='knob'&&!t.endless){
    if(t.det&&t.det!=='center'){tickKnob(t,n);}else{t.raw=clamp((t.raw??knobGet(t))+n*(shiftNow()?.002:.01));knobSet(t,t.det==='center'?vFromRaw(t.raw):t.raw);}
    refreshKnob(t);knobChanged(t);return;}
  /* Normalzustand: VALUE / PATTERN wechselt das Pattern (Plan) */
  tickKnob({det:'pattern',id:'pattern'},n);
}
const savedCount=()=>{let n=0;try{for(let k=1;k<=250;k++)if(localStorage.getItem('tx16.v6.pat.'+k))n++;}catch(e){}return n;};
const onOff=b=>b?'ON':'OFF';
/* Hilfsfunktionen für PART UTILITY / DATA UTILITY */
function clearSeq(p){if(p>=NSEQ)return;cur.steps[p].fill(0);cur.notes[p].fill(57);cur.gate[p].fill(0);cur.vel[p].fill(100);cur.rat[p].fill(1);cur.xn[p]={};}
let fileReq=null;
function wavBlob(chs,sr){const n=chs[0].length,b=new ArrayBuffer(44+n*4),v=new DataView(b),w=(o,str)=>{for(let k=0;k<str.length;k++)v.setUint8(o+k,str.charCodeAt(k));};
  w(0,'RIFF');v.setUint32(4,36+n*4,true);w(8,'WAVE');w(12,'fmt ');v.setUint32(16,16,true);v.setUint16(20,1,true);v.setUint16(22,2,true);v.setUint32(24,sr,true);v.setUint32(28,sr*4,true);v.setUint16(32,4,true);v.setUint16(34,16,true);w(36,'data');v.setUint32(40,n*4,true);
  let o=44;for(let k=0;k<n;k++)for(let c=0;c<2;c++){v.setInt16(o,Math.round(clamp(chs[c][k],-1,1)*32767),true);o+=2;}return new Blob([b],{type:'audio/wav'});}
function download(blob,name){const u=URL.createObjectURL(blob),l=document.createElement('a');l.href=u;l.download=name;document.body.appendChild(l);l.click();l.remove();setTimeout(()=>URL.revokeObjectURL(u),3000);}
/* EXPORT AUDIO: spielt das Pattern (bzw. die Chain) einmal ab und speichert die Summe als WAV */
function exportAudio(chain){if(E.rec){popup('msg',{t:'EXPORT AUDIO',b:'BUSY'},1200);return;}const pats=[ui.pattern];if(chain){let n=cur.chainTo,guard=0;const keep=cur;while(n&&!pats.includes(n)&&guard++<64){pats.push(n);const P2=loadPattern(n);n=P2.chainTo;}cur=keep;}
  const durOf=n=>{const P2=n===ui.pattern?cur:loadPattern(n);return P2.last*(60/(G.tlock?G.bpm:P2.bpm)/4)*BEATLEN[P2.beat||0];};let dur=pats.reduce((a,n)=>a+durOf(n),0)+.8;
  setPlaying(false);seq.step=0;const sp=ctx.createScriptProcessor(4096,2,2),L=[],Rr=[];E.rec=sp;let t0=null;
  sp.onaudioprocess=e=>{if(t0===null)return;const pt=e.playbackTime;if(pt+e.inputBuffer.duration<t0)return;if(pt>t0+dur){fin();return;}L.push(new Float32Array(e.inputBuffer.getChannelData(0)));Rr.push(new Float32Array(e.inputBuffer.getChannelData(1)));};
  let done=false;const fin=()=>{if(done)return;done=true;try{E.master.disconnect(sp);sp.disconnect();}catch(e){}E.rec=null;setPlaying(false);const n=L.reduce((a,b)=>a+b.length,0),cl=new Float32Array(n),cr=new Float32Array(n);let o=0;L.forEach((a,k)=>{cl.set(a,o);cr.set(Rr[k],o);o+=a.length;});
    download(wavBlob([cl,cr],ctx.sampleRate),'TX16_'+patStr().replace('.','')+(chain?'_CHAIN':'')+'.wav');popup('msg',{t:'EXPORT AUDIO',b:'WAV SAVED',s:dur.toFixed(1)+' S · '+pats.length+' PATTERN'},2500);};
  E.master.connect(sp);sp.connect(ctx.destination);setPlaying(true);t0=seq.next;popup('msg',{t:'EXPORT AUDIO',b:'RECORDING…',s:dur.toFixed(1)+' S'},dur*1000);}
function exportAll(){const all={tx16all:'1.1',global:JSON.parse(JSON.stringify(G)),patterns:{}};for(let k=1;k<=250;k++){try{const r=localStorage.getItem('tx16.v6.pat.'+k);if(r)all.patterns[k]=JSON.parse(r);}catch(e){}}
  all.patterns[ui.pattern]=patternToObj();download(new Blob([JSON.stringify(all)],{type:'application/json'}),'TX16_ALLPATTERN.json');popup('msg',{t:'EXPORT ALL PATTERN',b:Object.keys(all.patterns).length+' PATTERNS',s:'+ GLOBAL PARAMETERS'},2200);}
const P_=()=>cur.parts[ui.part],cyc=(v,x,n)=>(v+x+n)%n,yes=b=>b?'ON':'OFF';
const stepLenP=()=>P_().lastStep||cur.last;
const SS=()=>clamp(ui.stepSel,0,stepLenP()-1);
let eraseT=0,resetT=0;
function swapParts(a,b){pushUndo();const A=clipPart(a),B=clipPart(b);pasteClip(B,a);pasteClip(A,b);}
function patSwap(n){if(n===ui.pattern)return;const keep=cur,other=loadPattern(n);storePattern(n);cur=other;storePattern(ui.pattern);cur=keep;switchPattern(ui.pattern);}
const NAMECH=' ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-!.#&+';
const xnAt=(k)=>{const a=cur.xn[ui.part]&&cur.xn[ui.part][SS()];return a&&a[k]!=null?a[k]:null;};
function setXn(k,v){const p=ui.part,s0=SS(),a=(cur.xn[p][s0]||[null,null,null]).slice(0,3);while(a.length<3)a.push(null);a[k]=v;const c=a.filter(x=>x!=null);if(c.length)cur.xn[p][s0]=c;else delete cur.xn[p][s0];dirty();}
const MENU=[
  {t:'PATTERN SET',items:[
    {k:'NAME',v:()=>cur.name||patName(),adj:x=>{const nm=(cur.name||patName()).padEnd(16,' ').slice(0,16).split(''),pos=clamp(ui.nameCur??0,0,15),ci=Math.max(0,NAMECH.indexOf(nm[pos]));nm[pos]=NAMECH[cyc(ci,x,NAMECH.length)];cur.name=nm.join('').trimEnd();dirty();}},
    {k:'NAME CURSOR',v:()=>String((ui.nameCur??0)+1),adj:x=>{ui.nameCur=clamp((ui.nameCur??0)+x,0,15);}},
    {k:'BPM',v:()=>G.bpm.toFixed(1),adj:x=>{setBPM(G.bpm+x*(shiftNow()?.1:1));dirty();}},
    {k:'SWING',v:()=>{const n=Math.round((cur.swing-.5)*100);return(n>0?'+':'')+n+' %';},adj:x=>{cur.swing=clamp(cur.swing+x*.01);dirty();}},
    {k:'BEAT',v:()=>BEATS[cur.beat||0],adj:x=>{cur.beat=cyc(cur.beat||0,x,4);dirty();}},
    {k:'LENGTH',v:()=>(cur.last/16)+(cur.last>16?' BARS':' BAR'),adj:x=>setLength(x)},
    {k:'PATTERN LEVEL',v:()=>pad3(cur.level),adj:x=>{cur.level=clamp(cur.level+x,0,127);dirty();applyChannel(0);}},
    {k:'MFX TYPE',v:()=>NUM.mfx(ui.mfx[0].type),adj:x=>{tickKnob({id:'mfxtype',mfx:0},x);}},
    {k:'ROLL TYPE',v:()=>NUM.roll(ui.rollType),adj:x=>{ui.rollType=cur.rollType=clamp(ui.rollType+x,0,ROLLS.length-1);dirty();if(ui.rollType<5&&E&&E.loop.on)E.loop.length(loopLen(ui.rollType),now());}},
    {k:'MOTION PLAY',v:()=>yes(ui.motion),adj:()=>{ui.motion=!ui.motion;}},
    {k:'ACCENT',v:()=>yes(ui.accent),adj:()=>{ui.accent=!ui.accent;}},
    {k:'CLEAR MFX MOTION',v:()=>'ENTER',enter:()=>{pushUndo();cur.motion.forEach(m=>{for(const s in m){delete m[s]._fx;delete m[s]._roll;if(!Object.keys(m[s]).length)delete m[s];}});dirty();popup('msg',{t:'CLEAR MFX MOTION',b:'DONE',s:'MFX + ROLL MOVES DELETED · UNDO'},1600);}},
    {k:'KEY',v:()=>KEYS[cur.key],adj:x=>{cur.key=cyc(cur.key,x,12);dirty();padLabels(true);}},
    {k:'SCALE',v:()=>NUM.scale(cur.scale),adj:x=>{cur.scale=cyc(cur.scale,x,SCALES.length);dirty();padLabels(true);drawMFXPad(0);}},
    {k:'CHORD SET',v:()=>NUM.chord(cur.chordSet??1),adj:x=>{cur.chordSet=clamp((cur.chordSet??1)+x,0,4);dirty();}},
    {k:'GATE ARP',v:()=>NUM.arp(cur.gateArp||0),adj:x=>{cur.gateArp=cyc(cur.gateArp||0,x*(shiftNow()?10:1),GATEARPS.length);dirty();drawMFXPad(0);drawOLED(0);}},
    {k:'ALTERNATE 21-22',v:()=>yes(cur.alt2122),adj:()=>{cur.alt2122=!cur.alt2122;dirty();}},
    {k:'ALTERNATE 23-24',v:()=>yes(cur.alt2324),adj:()=>{cur.alt2324=!cur.alt2324;dirty();}},
    {k:'CHAIN TO',v:()=>cur.chainTo?patStr(cur.chainTo):'OFF',adj:x=>{cur.chainTo=clamp(cur.chainTo+x*(shiftNow()?10:1),0,250);dirty();}},
    {k:'CHAIN REPEAT',v:()=>String(cur.chainRep),adj:x=>{cur.chainRep=clamp(cur.chainRep+x,1,64);dirty();}},
    {k:'GLUE BUS DRIVE',v:()=>pad3(Math.round((cur.glue??.5)*127)),adj:x=>{cur.glue=clamp((cur.glue??.5)+x/127*4);dirty();applyGlobals();}},
    {k:'PATTERN BPM (SAVED)',v:()=>cur.bpm.toFixed(1),adj:x=>{cur.bpm=clamp(cur.bpm+x,20,300);dirty();}}]},
  {t:'PART EDIT',items:[
    {k:'PART',v:()=>pad2(ui.part+1)+' '+PARTS[ui.part],adj:x=>setPart(cyc(ui.part,x,PARTS.length),true)},
    {k:'LAST STEP',v:()=>P_().lastStep?String(P_().lastStep):'PATTERN ('+cur.last+')',adj:x=>{const P=P_();P.lastStep=clamp(P.lastStep+x,0,cur.last);dirty();}},
    {k:'GROOVE TYPE',v:()=>NUM.groove(P_().grooveT||0),adj:x=>{const P=P_();P.grooveT=cyc(P.grooveT||0,x,GROOVES.length);dirty();}},
    {k:'GROOVE DEPTH',v:()=>pad3(Math.round((P_().grooveD??.5)*127)),adj:x=>{const P=P_();P.grooveD=clamp((P.grooveD??.5)+x/127*(shiftNow()?1:4));dirty();}},
    {k:'VOICE ASSIGN',v:()=>VOICES[P_().voice??1].split(' · ')[0],adj:x=>{const P=P_();P.voice=cyc(P.voice??1,x,4);P.mono=P.voice<2;partLeds();dirty();}},
    {k:'PART PRIORITY',v:()=>P_().prio?'HIGH':'NORMAL',adj:()=>{const P=P_();P.prio=P.prio?0:1;dirty();}},
    {k:'MOTION SEQ',v:()=>MOTIONMODES[P_().motionMode??1],adj:x=>{const P=P_();P.motionMode=cyc(P.motionMode??1,x,3);dirty();}},
    {k:'TRG.PAD VELOCITY',v:()=>yes(P_().trgVel),adj:()=>{const P=P_();P.trgVel=!P.trgVel;dirty();}},
    {k:'SCALE MODE',v:()=>yes(P_().scaleMode),adj:()=>{const P=P_();P.scaleMode=P.scaleMode?0:1;dirty();padLabels(true);}},
    {k:'GLIDE',v:()=>valStr(CTRL.glide),adj:x=>{const P=P_();P.glide=clamp((P.glide||0)+x*.02);dirty();}},
    {k:'WAVE',v:()=>P_().osc?(pad3((P_().wave|0)+1)+' '+emxWaveName(P_())).slice(0,18):'- (SAMPLE)',adj:x=>{waveAdj(x);ui.popup=null;}},
    {k:'AMP EG',v:()=>P_().egOn?'ON (ADSR)':'OFF (GATE)',adj:()=>{const P=P_();P.egOn=!P.egOn;dirty();}},
    {k:'OKT. SEND',v:()=>yes(P_().oktSend),adj:()=>{const P=P_();P.oktSend=!P.oktSend;dirty();setLed(CTRL.oktsend,P.oktSend);}},
    {k:'EQ PRESET',v:()=>EQ_PRESETS[P_().eqPre??0][0]+((P_().eqPre??-1)<0?' (EDIT)':''),adj:x=>{const P=P_();eqPreset(((P.eqPre??0)+x+EQ_PRESETS.length)%EQ_PRESETS.length);ui.popup=null;}},
    {k:'EQ DRIVE',v:()=>valStr(CTRL.eqD),adj:x=>{const P=P_();P.eqD=clamp((P.eqD||0)+x*.02);afterPartChange('eqD');}},
    {k:'HIGH CUT',v:()=>eqStr(P_(),'hc'),adj:x=>{const P=P_();P.hc=clamp(pget(P,'hc')+x*.01);delete P.eqPre;afterPartChange('hc');}},
    {k:'SUSTAIN',v:()=>(P_().egS||0)<.005?'OFF (AD)':pad3(Math.round(P_().egS*127)),adj:x=>{const P=P_();P.egS=clamp((P.egS||0)+x/127*(shiftNow()?1:4));dirty();if(ui.padMode===3)drawMFXPad(0);}},
    {k:'RELEASE',v:()=>Math.round(egRelT(P_())*1000)+' MS',adj:x=>{const P=P_();P.egR=clamp((P.egR??.15)+x/127*(shiftNow()?1:4));dirty();if(ui.padMode===3)drawMFXPad(0);}},
    {k:'EG DELAY',v:()=>Math.round(egDlT(P_())*1000)+' MS',adj:x=>{const P=P_();P.egDl=clamp((P.egDl||0)+x/127*(shiftNow()?1:4));dirty();}},
    {k:'EG HOLD',v:()=>Math.round(egHT(P_())*1000)+' MS',adj:x=>{const P=P_();P.egH=clamp((P.egH||0)+x/127*(shiftNow()?1:4));dirty();}},
    {k:'DRUCK',v:()=>pad3(Math.round((P_().druck||0)*127)),adj:x=>{const P=P_();P.druck=clamp((P.druck||0)+x/127*(shiftNow()?1:4));dirty();}},
    {k:'KEYBOARD OCTAVE',v:()=>{const o=ui.kbOct||0;return(o>0?'+':'')+o;},adj:x=>{ui.kbOct=clamp((ui.kbOct||0)+x,-4,4);padLabels(true);}},
    {k:'OCTAVE',v:()=>{const o=P_().oct;return(o>0?'+':'')+o;},adj:x=>{const P=P_();P.oct=clamp(P.oct+x,-5,5);dirty();}},
    {k:'TRANSPOSE',v:()=>{const o=P_().tr;return(o>0?'+':'')+o+' ST';},adj:x=>{const P=P_();P.tr=clamp(P.tr+x,-12,12);dirty();}},
    {k:'CHOKE GROUP',v:()=>{const n=P_().choke;return n?'GROUP '+n:'OFF';},adj:x=>{const P=P_();P.choke=cyc(P.choke,x,5);dirty();}},
    {k:'SIDECHAIN FROM',v:()=>{const P=P_();return pad2(P.scSrc+1)+' '+PARTS[P.scSrc];},adj:x=>{const P=P_();P.scSrc=cyc(P.scSrc,x,PARTS.length);dirty();}},
    {k:'FILTER TRACK',v:()=>yes(P_().ftrack),adj:()=>{const P=P_();setTrack(P,!P.ftrack);dirty();liveFilter(ui.part);refreshKnob(CTRL.cutoff);}},
    {k:'PAD RELEASE',v:()=>P_().rel===CUT?'CUT':'ONE SHOT',adj:()=>{const P=P_();P.rel=P.rel===CUT?ONE_SHOT:CUT;dirty();}},
    {k:'LOW CUT',v:()=>eqStr(P_(),'lc'),adj:x=>{const P=P_();P.lc=clamp(P.lc+x*.01);delete P.eqPre;afterPartChange('lc');}},
    {k:'STRETCH',v:()=>['OFF','KEEP LEN','BPM SYNC'][P_().stretch],adj:x=>{const P=P_();P.stretch=cyc(P.stretch,x,3);partLeds();if(P.stretch)scheduleStretch(ui.part);dirty();}},
    {k:'STRETCH LENGTH',v:()=>stretchSteps(P_())+' STEPS',adj:x=>{const P=P_();P.lenSt=clamp(stretchSteps(P)+x*(shiftNow()?16:1),1,128);dirty();if(P.stretch)scheduleStretch(ui.part);}},   // Plan: auf wie viele Steps gestreckt wird
    {k:'LOOP EVERY',v:()=>{const n=P_().loopN;return n?n+(n>1?' BARS':' BAR'):'OFF';},adj:x=>{const P=P_();P.loopN=clamp(P.loopN+x,0,8);dirty();}}]},
  {t:'STEP EDIT',items:[
    {k:'STEP NUMBER',v:()=>ui.part>=NSEQ?'LIVE PART':(Math.floor(SS()/16)+1)+'.'+pad2(SS()%16+1),adj:x=>{ui.stepSel=clamp(SS()+x*(shiftNow()?16:1),0,stepLenP()-1);ui.pageSel=Math.min(cur.last/16-1,Math.floor(ui.stepSel/16));}},
    {k:'TRIGGER',v:()=>ui.part>=NSEQ?'-':yes(cur.steps[ui.part][SS()]),adj:()=>{if(ui.part>=NSEQ)return;cur.steps[ui.part][SS()]^=1;dirty();}},
    {k:'NOTE 1',v:()=>ui.part>=NSEQ?'-':noteName(cur.notes[ui.part][SS()]+12),adj:x=>{if(ui.part>=NSEQ)return;const a=cur.notes[ui.part];a[SS()]=clamp(a[SS()]+x*(shiftNow()?12:1),0,127);dirty();}},
    ...[0,1,2].map(k=>({k:'NOTE '+(k+2),v:()=>{const n=ui.part<NSEQ?xnAt(k):null;return n==null?'---':noteName(n+12);},adj:x=>{if(ui.part>=NSEQ)return;let n=xnAt(k);n=n==null?(x>0?cur.notes[ui.part][SS()]+[4,7,12][k]:null):n+x*(shiftNow()?12:1);if(n!=null&&(n<0||n>127))n=null;setXn(k,n);}})),
    {k:'GATE TIME',v:()=>{if(ui.part>=NSEQ)return'-';const g=cur.gate[ui.part][SS()];return g===255?'TIE':g?pad2(Math.min(96,g*24))+(g>4?' +'+(g/4-1).toFixed(2)+' ST':''):'AUTO';},adj:x=>{if(ui.part>=NSEQ)return;const a=cur.gate[ui.part],g=a[SS()];a[SS()]=g===255?(x<0?16:255):clamp(g+x,0,16)===16&&x>0&&g===16?255:clamp(g+x,0,16);dirty();}},
    {k:'VELOCITY',v:()=>ui.part>=NSEQ?'-':pad3(cur.vel[ui.part][SS()]),adj:x=>{if(ui.part>=NSEQ)return;const a=cur.vel[ui.part];a[SS()]=clamp(a[SS()]+x*(shiftNow()?10:1),1,127);dirty();}},
    {k:'RATCHET',v:()=>ui.part>=NSEQ?'-':Math.max(1,cur.rat[ui.part][SS()])+'X',adj:x=>{if(ui.part>=NSEQ)return;const a=cur.rat[ui.part];a[SS()]=clamp(Math.max(1,a[SS()])+x,1,4);dirty();}},
    {k:'CLEAR STEP MOTION',v:()=>'ENTER',enter:()=>{delete cur.motion[ui.part][SS()];dirty();popup('msg',{t:'STEP '+(SS()+1),b:'MOTION CLEARED'},900);}}]},
  {t:'PART UTILITY',items:[
    {k:'COPY PART TO',v:()=>pad2(ui.util.swap+1)+' '+PARTS[ui.util.swap],adj:x=>{ui.util.swap=cyc(ui.util.swap,x,PARTS.length);}},
    {k:'COPY PART',v:()=>'ENTER',enter:()=>{if(ui.util.swap===ui.part)return;pasteClip(clipPart(ui.part),ui.util.swap);popup('msg',{t:'COPY PART',b:'P'+pad2(ui.part+1)+' > P'+pad2(ui.util.swap+1),s:'SOUND + SEQUENCE + MOTION'},1600);}},
    {k:'COPY PART SOUND',v:()=>'ENTER',enter:()=>{if(ui.util.swap===ui.part)return;pushUndo();cur.parts[ui.util.swap]=JSON.parse(JSON.stringify(cur.parts[ui.part]));applyChannel(ui.util.swap);dirty();popup('msg',{t:'COPY PART SOUND',b:'P'+pad2(ui.part+1)+' > P'+pad2(ui.util.swap+1),s:'ONLY THE SOUND'},1600);}},
    {k:'CLEAR SEQUENCE',v:()=>'ENTER',enter:()=>{if(ui.part>=NSEQ)return;pushUndo();clearSeq(ui.part);dirty();popup('msg',{t:'CLEAR SEQUENCE',b:'PART '+pad2(ui.part+1),s:'TRIGGER + NOTES + GATE · UNDO'},1600);}},
    {k:'CLEAR SEQUENCE ALL',v:()=>'ENTER',enter:()=>{pushUndo();for(let p=0;p<NSEQ;p++)clearSeq(p);dirty();popup('msg',{t:'CLEAR SEQUENCE',b:'ALL PARTS',s:'TRIGGER + NOTES + GATE · UNDO'},1600);}},
    {k:'CLEAR MOTION',v:()=>'ENTER',enter:()=>{pushUndo();cur.motion[ui.part]={};dirty();popup('msg',{t:'CLEAR MOTION',b:'PART '+pad2(ui.part+1)},1200);}},
    {k:'COPY FROM PATTERN',v:()=>patStr(ui.util.pat),adj:x=>{ui.util.pat=clamp(ui.util.pat+x*(shiftNow()?10:1),1,250);}},
    {k:'COPY FROM PART',v:()=>pad2(ui.util.part+1)+' '+PARTS[ui.util.part],adj:x=>{ui.util.part=cyc(ui.util.part,x,PARTS.length);}},
    {k:'COPY > THIS PART',v:()=>'ENTER',enter:()=>{const C=clipFrom(ui.util.pat,ui.util.part);pasteClip(C,ui.part);popup('msg',{t:'PART UTILITY',b:'COPIED',s:C.from+' > P'+pad2(ui.part+1)},2000);}},
    {k:'SWAP WITH PART TO',v:()=>'ENTER',enter:()=>{if(ui.util.swap===ui.part)return;swapParts(ui.part,ui.util.swap);popup('msg',{t:'PART UTILITY',b:'SWAPPED',s:'P'+pad2(ui.part+1)+' <> P'+pad2(ui.util.swap+1)},1600);}},
    {k:'INIT SOUND',v:()=>'ENTER',enter:()=>{pushUndo();cur.parts[ui.part]=newPart(ui.part);applyChannel(ui.part);partLeds();refreshKnobs();dirty();popup('msg',{t:'INIT SOUND',b:'PART '+pad2(ui.part+1)},1200);}},
    {k:'INIT PART',v:()=>'ENTER',enter:()=>clearPart(ui.part)},
    {k:'FILL ALL PARTS',v:()=>'ENTER',enter:()=>{ui.menu=-1;fillStart(true);}}]},
  {t:'SAMPLE EDIT',items:[
    {k:'SAMPLE',v:()=>NUM.src(P_().src).slice(0,18),adj:x=>{const P=P_();P.src=clamp(P.src+x*(shiftNow()?10:1),0,SRC.length-1);if(P.src)P.osc=0;dirty();refreshKnobs();if(P.stretch)scheduleStretch(ui.part);}},
    {k:'START',v:()=>(P_().start*100).toFixed(1)+' %',adj:x=>{const P=P_();P.start=clamp(P.start+x*(shiftNow()?.001:.005),0,Math.max(0,(P.smpEnd??1)-.01));dirty();}},
    {k:'END',v:()=>((P_().smpEnd??1)*100).toFixed(1)+' %',adj:x=>{const P=P_();P.smpEnd=clamp((P.smpEnd??1)+x*(shiftNow()?.001:.005),P.start+.01,1);dirty();}},
    {k:'LOOP',v:()=>yes(P_().loopOn),adj:()=>{const P=P_();P.loopOn=!P.loopOn;dirty();}},
    {k:'LOOP START',v:()=>Math.round((P_().loopStart||0)*100)+' %',adj:x=>{const P=P_();P.loopStart=clamp((P.loopStart||0)+x*.01,0,.98);dirty();}},
    {k:'LEVEL',v:()=>pad3(Math.round((P_().smpLvl??1)*100)),adj:x=>{const P=P_();P.smpLvl=clamp((P.smpLvl??1)+x*.01,0,1.5);dirty();}},
    {k:'TUNE',v:()=>{const n=P_().tune||0;return(n>0?'+':'')+n+' CENT';},adj:x=>{const P=P_();P.tune=clamp((P.tune||0)+x,-100,100);dirty();}},
    {k:'REVERSE',v:()=>yes(P_().reverse),adj:()=>{const P=P_();P.reverse=!P.reverse;dirty();if(P.stretch)scheduleStretch(ui.part);}},   // REVERSE-Taste gibt es nicht mehr (Plan) -> nur im Menü
    {k:'PUNCH (OSC EDIT)',v:()=>pad3(Math.round(P_().edit*127)),adj:x=>{const P=P_();P.edit=clamp(P.edit+x/127*(shiftNow()?1:4));dirty();refreshKnob(CTRL.edit);}}]},
  {t:'GLOBAL PARAMETER',items:[
    {k:'TRIGGER MODE',v:()=>['NORMAL','SEQ 1ST','SEQ PLAY'][G.trigMode],adj:x=>{G.trigMode=cyc(G.trigMode,x,3);}},
    {k:'VELOCITY CURVE',v:()=>['HEAVY','NORMAL','LIGHT','CONST96'][G.velCurve],adj:x=>{G.velCurve=cyc(G.velCurve,x,4);}},
    {k:'CLOCK MODE',v:()=>['INTERNAL','EXTERNAL','AUTO'][G.midi.clock],adj:x=>{G.midi.clock=cyc(G.midi.clock,x,3);ui.extClock=false;}},
    {k:'GLOBAL MIDI CH',v:()=>pad2(G.midiCh),adj:x=>{G.midiCh=cyc(G.midiCh-1,x,16)+1;}},
    {k:'MIDI RECEIVE FILTER',v:()=>['OFF','SHORT','SHORT+PROGRAM'][G.rxFilter],adj:x=>{G.rxFilter=cyc(G.rxFilter,x,3);}},
    {k:'MIDI SEND FILTER',v:()=>['OFF','SHORT','SHORT+PROGRAM'][G.txFilter],adj:x=>{G.txFilter=cyc(G.txFilter,x,3);}},
    {k:'SYNC POLARITY',v:()=>['HI','LO'][G.syncPol],adj:x=>{G.syncPol=cyc(G.syncPol,x,2);}},
    {k:'SYNC UNIT',v:()=>['1 STEP','2 STEPS'][G.syncUnit],adj:x=>{G.syncUnit=cyc(G.syncUnit,x,2);}},
    {k:'METRONOME',v:()=>['OFF','REC 0','REC 1','REC 2','ON'][G.metro],adj:x=>{G.metro=cyc(G.metro,x,5);if(G.metro)metroPreview();}},
    {k:'METRO SOUND',v:()=>pad2(G.metroSnd+1)+' '+METROSND[G.metroSnd],adj:x=>{G.metroSnd=cyc(G.metroSnd,x,METROSND.length);metroPreview();}},
    {k:'METRO LEVEL',v:()=>pad3(Math.round(G.metroLvl*127)),adj:x=>{G.metroLvl=clamp(G.metroLvl+x*.04);metroPreview();}},
    {k:'TX CHARACTER',v:()=>COLORS[G.color],adj:x=>{G.color=cyc(G.color,x,COLORS.length);applyColor();dirty();}},
    {k:'ANALOG DRIFT',v:()=>pad3(Math.round(G.analog*127)),adj:x=>{G.analog=clamp(G.analog+x*.05);dirty();}},
    {k:'TEMPO LOCK',v:()=>TLOCK[G.tlock],adj:x=>{G.tlock=cyc(G.tlock,x,3);}},
    {k:'KNOB MODE (MIDI CC)',v:()=>['JUMP','CATCH','VALUE SCALE'][G.knobMode],adj:x=>{G.knobMode=cyc(G.knobMode,x,3);}},
    {k:'TOUCH SCALE RANGE',v:()=>(G.tsRange||2)+' OCT',adj:x=>{G.tsRange=clamp((G.tsRange||2)+x,1,4);drawMFXPad(0);}},
    {k:'LCD CONTRAST',v:()=>pad2(G.lcd),adj:x=>{G.lcd=clamp(G.lcd+x,1,25);}},
    {k:'AUDIO IN THRU',v:()=>yes(G.inMon),adj:()=>{G.inMon=!G.inMon;setLed(CTRL.inmon,G.inMon);if(E&&E.in)applyInput();}},
    {k:'AUTO POWER OFF',v:()=>['DISABLE','4 HOURS'][G.autoOff],adj:x=>{G.autoOff=cyc(G.autoOff,x,2);}},
    {k:'POWER SAVE MODE',v:()=>['DISABLE','AUTO','ENABLE'][G.powerSave],adj:x=>{G.powerSave=cyc(G.powerSave,x,3);const lv=G.powerSave===2?.06:G.led;document.documentElement.style.setProperty('--dimlv',Math.round(lv*100)+'%');}},
    {k:'PTN. CHANGE LOCK',v:()=>yes(G.ptnLock),adj:()=>{G.ptnLock=!G.ptnLock;}},
    {k:'CHAIN MODE',v:()=>yes(G.chainMode),adj:()=>{G.chainMode=!G.chainMode;}},
    {k:'RAMP LENGTH',v:()=>G.rampBars+' BARS',adj:x=>{G.rampBars=clamp(G.rampBars+x,1,16);}},
    {k:'LIMITER',v:()=>yes(G.limiter),adj:()=>{G.limiter=!G.limiter;applyGlobals();}},
    {k:'SIDECHAIN RELEASE',v:()=>Math.round(30+G.scRel*180)+' MS',adj:x=>{G.scRel=clamp(G.scRel+x*.05);}},

    {k:'TUBES',v:()=>yes(G.tubeOn),adj:()=>{G.tubeOn=!G.tubeOn;applyGlobals();dirty();}},
    {k:'LED DIM LEVEL',v:()=>Math.round(G.led*100)+' %',adj:x=>{G.led=clamp(G.led+x*.02,0,.4);document.documentElement.style.setProperty('--dimlv',Math.round(G.led*100)+'%');}}]},
  {t:'DATA UTILITY',items:[
    {k:'EXPORT PATTERN',v:()=>'ENTER',enter:()=>$('#expBtn').click()},
    {k:'EXPORT ALL PATTERN',v:()=>'ENTER',enter:()=>exportAll()},
    {k:'IMPORT PATTERN',v:()=>'ENTER',enter:()=>$('#impFile').click()},
    {k:'IMPORT ALL PATTERN',v:()=>'ENTER',enter:()=>$('#impFile').click()},
    {k:'INITIALIZE PATTERN',v:()=>'ENTER',enter:()=>initPattern()},
    {k:'EXPORT AUDIO',v:()=>'ENTER',enter:()=>exportAudio(false)},
    {k:'EXPORT CHAIN AUDIO',v:()=>'ENTER',enter:()=>exportAudio(true)},
    {k:'PATTERN COPY TO',v:()=>patStr(ui.util.dst),adj:x=>{ui.util.dst=clamp(ui.util.dst+x*(shiftNow()?10:1),1,250);}},
    {k:'COPY NOW',v:()=>'ENTER',enter:()=>{const ok=storePattern(ui.util.dst);popup('msg',{t:'PATTERN COPY',b:ok?patStr()+' > '+patStr(ui.util.dst):'NO STORAGE'},1800);}},
    {k:'SWAP NOW',v:()=>'ENTER',enter:()=>{patSwap(ui.util.dst);popup('msg',{t:'PATTERN SWAP',b:patStr()+' <> '+patStr(ui.util.dst)},1800);}},
    {k:'FACTORY PATTERN',v:()=>'ENTER',enter:()=>{try{localStorage.removeItem('tx16.v6.pat.'+ui.pattern);}catch(e){}switchPattern(ui.pattern);}},
    {k:'SAVED',v:()=>savedCount()+' / 250'},
    {k:'FACTORY RESET',v:()=>'ENTER 2X',enter:()=>{const t=performance.now();if(t-resetT>3000){resetT=t;popup('msg',{t:'FACTORY RESET',b:'ENTER AGAIN',s:'ALL PATTERNS + GLOBAL SETTINGS'},3000);return;}
      resetT=0;try{for(let k=1;k<=250;k++)localStorage.removeItem('tx16.v6.pat.'+k);localStorage.removeItem('tx16.global');}catch(e){}location.reload();}}]},
  {t:'EVENT REC/PLAY',items:[
    {k:'EVENT SLOT',v:()=>pad3(ui.evSlot??1)+(evStored(ui.evSlot??1)?' ●':''),adj:x=>{ui.evSlot=clamp((ui.evSlot??1)+x,1,100);}},
    {k:'EVENT RECORDER',v:()=>ui.ev.rec?'REC ●':'ENTER = START',enter:()=>{const V=ui.ev;if(V.rec){V.rec=false;try{localStorage.setItem('tx16.ev.'+(ui.evSlot??1),JSON.stringify({list:V.list,startPat:V.startPat}));}catch(e){}popup('msg',{t:'EVENT RECORDER',b:'STOPPED',s:V.list.length+' EVENTS > SLOT '+pad3(ui.evSlot??1)},1600);return;}
      V.rec=true;V.play=false;V.list=[];V.startPat=ui.pattern;if(!ui.playing){seq.step=0;setPlaying(true);}V.t0=ui.absStep;evLog('mute',[...ui.muted]);popup('msg',{t:'EVENT RECORDER',b:'RECORDING',s:'PATTERNS, MUTES, SOLO, DROP, MFX'},1600);}},
    {k:'EVENT PLAYER',v:()=>ui.ev.play?'PLAYING':'ENTER = PLAY',enter:()=>{const V=ui.ev;try{const r=localStorage.getItem('tx16.ev.'+(ui.evSlot??1));if(r){const o=JSON.parse(r);V.list=o.list;V.startPat=o.startPat;}}catch(e){}
      if(!V.list.length){popup('msg',{t:'EVENT PLAYER',b:'NO EVENTS'},1200);return;}V.rec=false;if(V.startPat&&V.startPat!==ui.pattern)switchPattern(V.startPat);seq.step=0;V.k=0;V.t0=ui.absStep;V.play=true;if(!ui.playing)setPlaying(true);popup('msg',{t:'EVENT PLAYER',b:'PLAYING',s:V.list.length+' EVENTS'},1600);}},
    {k:'EVENTS',v:()=>String(ui.ev.list.length)}]},
  {t:'MIDI',items:[{k:'CONNECT',v:()=>MIDI.acc?MIDI.ins.length+' IN '+MIDI.outs.length+' OUT':'ENTER',enter:()=>midiConnect().then(syncMidiBtn)},
    {k:'CLOCK OUT',v:()=>yes(G.midi.clockOut),adj:()=>{G.midi.clockOut=!G.midi.clockOut;}},
    {k:'KEYBOARD',v:()=>G.midi.keyb?'CH = PART':'GLOBAL CH > PART',adj:()=>{G.midi.keyb=G.midi.keyb?0:1;}},{k:'NOTES OUT',v:()=>yes(G.midi.notesOut),adj:()=>{G.midi.notesOut=!G.midi.notesOut;}},
    {k:'CC IN',v:()=>yes(G.midi.ccIn),adj:()=>{G.midi.ccIn=!G.midi.ccIn;}},{k:'PROGRAM CHANGE',v:()=>yes(G.midi.pc),adj:()=>{G.midi.pc=!G.midi.pc;}},{k:'SOFT THRU',v:()=>yes(G.midi.thru),adj:()=>{G.midi.thru=!G.midi.thru;}}]},
  {t:'INPUT',items:[{k:'CONNECT',v:()=>E&&E.in?'ON':'ENTER',enter:()=>inputOn().then(syncInBtn)},{k:'AUTO GAIN',v:()=>yes(G.inAuto),adj:()=>{G.inAuto=!G.inAuto;}},
    {k:'IN GAIN',v:()=>(-18+G.inGain*36).toFixed(1)+' DB',adj:x=>{G.inGain=clamp(G.inGain+x*.02);G.inAuto=false;if(E&&E.in)applyInput();}},{k:'SAMPLE 1 BAR',v:()=>'ENTER',enter:()=>act({id:'inrec'})}]},   // IN REC-Taste gibt es nicht mehr (Plan) -> Menü
  {t:'USB STICK',items:[{k:'LOAD SAMPLES',v:()=>'ENTER',enter:()=>$('#file').click()},{k:'USER SAMPLES',v:()=>String(SRC.length-N_FACTORY)},{k:'SAMPLES',v:()=>String(SRC.length-1)},{k:'OSCILLATORS',v:()=>String(OSCS.length-1)},{k:'FILTERS',v:()=>String(FILTERS.length)},{k:'MOD TYPES',v:()=>String(MODS.length)}]},
  {t:'ABOUT',items:[{k:'TX-16 LIVE',v:()=>'REV 2.0'},{k:'ENGINE',v:()=>'32-BIT FLOAT'},{k:'SAMPLE RATE',v:()=>ctx?ctx.sampleRate+' HZ':'-'},{k:'VOICES',v:()=>E?String(E.voices.filter(v=>!v.dead).length)+' / '+MAXV:'0'}]}
];
const evStored=n=>{try{return !!localStorage.getItem('tx16.ev.'+n);}catch(e){return false;}};
