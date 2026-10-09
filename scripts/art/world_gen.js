/* GoonCrusher world art generator (docs/WORLD_ART.md). bake_world.py opens bake_world.html in headless Edge, which
   calls WorldArt for each file. Everything is lit from straight overhead: height reads only through ambient occlusion
   (dark contact bands at the foot of things, a lighter lip on top edges), so every sprite and strip may be rotated
   and flipped freely. Palette "Dust & Rust": ground mid-value and less saturated than the actors; telegraph red
   #ff5c30, HUD orange #f0a030 and Scrap teal #2aa6a1 never as large fills (teal only as small daubs on Scrap props).
   Deterministic: no Math.random, no Date. Units are world px unless a name says texels. */
(function(){
"use strict";
const A=window.ArtCore;
const {TAU,rng,hash2,fbm,worley,smooth,lerp,clamp01,mixc,css,shade,sat,C,ell,rr,vol,polyPath,polyVol,limb,rust,facetRock,tire,canvas}=A;

const GROUND_TEXELS=512, GROUND_DENSITY=.5;   /* one 512 tile covers 1024 world px */
const PROP_RES=.75;                           /* props, strips and decor: texels per world px */
const TEAL='#2aa6a1', RAG='#e0782c', INK='rgba(18,13,16,.9)', AO='18,13,16';
const ROCK='#8a8178', LIP='#b3aa9c';

/* ---------- tile helpers ---------- */
function pixels(W,H,fn){ const cv=canvas(W,H), x=cv.getContext('2d'), im=x.createImageData(W,H), d=im.data, o=[0,0,0,255];
	for(let j=0;j<H;j++) for(let i=0;i<W;i++){ o[3]=255; fn(i/W,j/H,i,j,o); const k=(j*W+i)*4; d[k]=o[0]; d[k+1]=o[1]; d[k+2]=o[2]; d[k+3]=o[3]; }
	x.putImageData(im,0,0); return cv; }
/* draw fn at (x,y) and at its wrapped copies when it is within r of an edge (wx/wy = tile size, 0 = no wrap) */
function wrapAt(ctx,wx,wy,x,y,r,fn){ const xs=[0], ys=[0];
	if(wx){ if(x<r) xs.push(wx); if(x>wx-r) xs.push(-wx); } if(wy){ if(y<r) ys.push(wy); if(y>wy-r) ys.push(-wy); }
	for(const dx of xs) for(const dy of ys){ ctx.save(); ctx.translate(x+dx,y+dy); fn(ctx); ctx.restore(); } }
function scatter(ctx,W,H,n,seed,r,fn,wrapY){ const R=rng(seed); for(let i=0;i<n;i++){ const x=R()*W, y=R()*H; wrapAt(ctx,W,wrapY===false?0:H,x,y,r,c=>fn(c,R,i,x,y)); } }
function overlayGrime(ctx,W,H,a){ ctx.save(); ctx.globalAlpha=a; ctx.fillStyle=ctx.createPattern(A.grimeTile(),'repeat'); ctx.fillRect(0,0,W,H); ctx.restore(); }
function jitter(o,i,j,seed,amt){ const g=(hash2(i,j,seed)-.5)*amt; o[0]+=g; o[1]+=g; o[2]+=g*.85; }
function put(o,c){ o[0]=c[0]; o[1]=c[1]; o[2]=c[2]; }
function stroke(ctx,pts,w,col){ ctx.beginPath(); ctx.moveTo(pts[0][0],pts[0][1]); for(let i=1;i<pts.length;i++) ctx.lineTo(pts[i][0],pts[i][1]); ctx.lineWidth=w; ctx.strokeStyle=col; ctx.lineCap='round'; ctx.lineJoin='round'; ctx.stroke(); }
function pebble(ctx,R,r,cols){ const c=C(cols[(R()*cols.length)|0]); ell(ctx,0,0,r*1.3,r*1.15); ctx.fillStyle='rgba('+AO+',.22)'; ctx.fill(); vol(ctx,0,0,r,r*(.7+R()*.3),c,{hi:.12,lo:-.3,rot:R()*3}); }
function crackWalk(ctx,R,len,w,col,branch){ let x=0,y=0,a=R()*TAU; const pts=[[0,0]]; for(let k=0;k<len;k++){ a+=(R()-.5)*1.1; x+=Math.cos(a)*4; y+=Math.sin(a)*4; pts.push([x,y]); if(branch&&R()<.08){ ctx.save(); ctx.translate(x,y); crackWalk(ctx,R,(len*.4)|0,w*.7,col,false); ctx.restore(); } } stroke(ctx,pts,w,col); }

/* ---------- ground materials: 512 texels, seamless (periodic noise + wrapped strokes) ---------- */
const GROUND={
grass(S){ const base=C('#6b7f4a'), dark=C('#52633a'), light=C('#849456'), dry=C('#958a64');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*4,v*4,11,4,4), m=fbm(u*16,v*16,12,3,16), d=fbm(u*3,v*3,13,3,3), h=fbm(u*64,v*64,17,2,64);
		let c=mixc(dark,base,.3+.7*smooth(.22,.68,n)); c=mixc(c,light,smooth(.55,.8,m)*.45); c=mixc(c,dry,smooth(.6,.74,d)*.5); c=shade(c,(h-.5)*.16); put(o,c); jitter(o,i,j,14,16); });
	const x=cv.getContext('2d');
	scatter(x,S,S,9000,15,8,(c,R)=>{ const a=R()*TAU, l=2+R()*4, k=R(); c.beginPath(); c.moveTo(0,0); c.lineTo(Math.cos(a)*l,Math.sin(a)*l); c.lineWidth=.7+R()*.6;
		c.strokeStyle=k<.5?'rgba(50,64,32,.6)':k<.85?'rgba(146,160,98,.5)':'rgba(166,156,110,.5)'; c.stroke(); });
	scatter(x,S,S,70,16,3,(c,R)=>{ ell(c,0,0,1,1); c.fillStyle=R()<.5?'rgba(214,206,170,.8)':'rgba(186,172,200,.7)'; c.fill(); });
	overlayGrime(x,S,S,.12); return cv; },
moss(S){ const base=C('#5d6a3f'), dark=C('#434e2f'), light=C('#78834e');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*6,v*6,21,4,6), m=fbm(u*40,v*40,22,2,40);
		let c=mixc(dark,base,.3+.7*smooth(.3,.62,n)); c=mixc(c,light,smooth(.5,.75,m)*.4); put(o,c); jitter(o,i,j,23,12); });
	const x=cv.getContext('2d');
	scatter(x,S,S,2600,24,6,(c,R)=>{ const r=1.2+R()*2.6; vol(c,0,0,r,r*(.8+R()*.3),R()<.6?'#5f6c3c':'#717d48',{hi:.22,lo:-.32}); });
	scatter(x,S,S,300,25,4,(c,R)=>{ ell(c,0,0,.8,.8); c.fillStyle='rgba(176,170,120,.6)'; c.fill(); });
	overlayGrime(x,S,S,.14); return cv; },
dirt(S){ const base=C('#7a6248'), dark=C('#5b4636'), light=C('#957c60');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*4,v*4,31,4,4), m=fbm(u*20,v*20,32,3,20);
		let c=mixc(dark,base,smooth(.25,.6,n)); c=mixc(c,light,smooth(.5,.75,m)*.5); put(o,c); jitter(o,i,j,33,18); });
	const x=cv.getContext('2d');
	scatter(x,S,S,60,34,40,(c,R)=>crackWalk(c,R,6+(R()*10|0),.8,'rgba(52,38,28,.35)',true));
	scatter(x,S,S,360,35,6,(c,R)=>pebble(c,R,.8+R()*2,['#7f7368','#6d6258','#8f8576','#5b4f44']));
	overlayGrime(x,S,S,.18); return cv; },
sand(S){ const base=C('#ab9672'), dark=C('#93805e'), light=C('#c0ad86');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*3,v*3,41,4,3), w=fbm(u*4,v*4,42,3,4);
		const rip=Math.sin(TAU*(v*28+u*2+w*1.6)), crest=Math.pow(Math.max(0,rip),3), trough=Math.pow(Math.max(0,-rip),2);
		let c=mixc(dark,base,smooth(.25,.65,n)); c=shade(c,crest*.07-trough*.06); c=mixc(c,light,smooth(.6,.8,fbm(u*8,v*8,43,3,8))*.35); put(o,c); jitter(o,i,j,44,10); });
	const x=cv.getContext('2d');
	scatter(x,S,S,160,45,5,(c,R)=>pebble(c,R,.8+R()*1.6,['#8a7a62','#6d6258','#b5a68a']));
	overlayGrime(x,S,S,.1); return cv; },
mud(S){ const base=C('#645341'), dark=C('#4b3d30'), wet=C('#3d332a'), sheen=C('#837f74');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*4,v*4,51,4,4), p=fbm(u*5,v*5,52,4,5), m=fbm(u*24,v*24,53,2,24);
		let c=mixc(dark,base,smooth(.3,.62,n)); const pud=smooth(.38,.33,p); c=mixc(c,wet,pud*.85);
		c=mixc(c,sheen,pud*smooth(.55,.75,m)*.35); c=shade(c,(1-pud)*(m-.5)*.12); put(o,c); jitter(o,i,j,54,12); });
	const x=cv.getContext('2d');
	scatter(x,S,S,420,55,6,(c,R)=>{ vol(c,0,0,1+R()*2.2,1+R()*1.8,'#6e5c48',{hi:.3,lo:-.4,rot:R()*3}); });
	scatter(x,S,S,40,56,30,(c,R)=>{ c.rotate(R()*TAU); for(const s of [-1,1]){ c.beginPath(); c.moveTo(-14,s*5); c.bezierCurveTo(-4,s*6,4,s*4,14,s*5); c.lineWidth=2.4; c.strokeStyle='rgba(40,32,26,.3)'; c.stroke(); } });
	overlayGrime(x,S,S,.15); return cv; },
mudpit(S){ const base=C('#4f3f30'), dark=C('#382c22'), gloss=C('#8d8a80');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*3,v*3,61,4,3), s=fbm(u*6+fbm(u*2,v*2,62,2,2)*2,v*6,63,3,6);
		let c=mixc(dark,base,smooth(.3,.7,n)); const sw=Math.sin(TAU*(s*5)); c=shade(c,sw*.05); c=mixc(c,gloss,Math.pow(smooth(.62,.8,s),2)*.4); put(o,c); jitter(o,i,j,64,8); });
	const x=cv.getContext('2d');
	scatter(x,S,S,110,65,14,(c,R)=>{ const r=2+R()*7; ell(c,0,0,r,r); c.lineWidth=1.1; c.strokeStyle='rgba(30,24,18,.5)'; c.stroke(); ell(c,-r*.25,-r*.3,r*.55,r*.35); c.fillStyle='rgba(190,186,170,.35)'; c.fill(); });
	scatter(x,S,S,30,66,30,(c,R)=>{ const r=6+R()*16; for(let k=1;k<3;k++){ ell(c,0,0,r*k*.6,r*k*.5); c.lineWidth=.8; c.strokeStyle='rgba(150,146,134,'+(.22/k)+')'; c.stroke(); } });
	overlayGrime(x,S,S,.12); return cv; },
snow(S){ const base=C('#c5cbd1'), shadow=C('#aab4c0'), dark=C('#95a2b4');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*3,v*3,71,4,3), w=fbm(u*3,v*36,72,4,3,36), g=fbm(u*24,v*24,76,2,24), sas=1-Math.abs(2*w-1);
		let c=mixc(shadow,base,.45+.55*smooth(.25,.7,n)); c=mixc(c,dark,smooth(.32,.2,n)*.3); c=shade(c,(sas-.6)*.1+(g-.5)*.06); put(o,c);
		if(hash2(i,j,73)>.996){ o[0]+=30; o[1]+=30; o[2]+=30; } jitter(o,i,j,74,8); });
	const x=cv.getContext('2d');
	scatter(x,S,S,90,75,6,(c,R)=>{ ell(c,0,0,2+R()*2,1.5+R()*1.5,R()*3); c.fillStyle='rgba(120,134,156,.25)'; c.fill(); });
	overlayGrime(x,S,S,.05); return cv; },
deepsnow(S){ const base=C('#ccd2d8'), shadow=C('#a3afbe'), crest=C('#dde1e5');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*4,v*3,81,4,4,3), l=fbm(u*10,v*10,82,3,10), w=fbm(u*4,v*30,86,3,4,30);
		let c=mixc(shadow,base,.4+.6*smooth(.25,.7,n)); c=mixc(c,crest,smooth(.55,.75,l)*.5); c=mixc(c,shadow,smooth(.42,.25,l)*.5); c=shade(c,(1-Math.abs(2*w-1)-.6)*.08); put(o,c);
		if(hash2(i,j,83)>.996){ o[0]+=26; o[1]+=26; o[2]+=26; } jitter(o,i,j,84,6); });
	const x=cv.getContext('2d');
	scatter(x,S,S,160,85,10,(c,R)=>{ const r=2+R()*4; ell(c,0,0,r*1.2,r); c.fillStyle='rgba(110,124,148,.32)'; c.fill(); ell(c,0,r*.35,r*1.1,r*.6); c.fillStyle='rgba(235,238,242,.35)'; c.fill(); });
	overlayGrime(x,S,S,.04); return cv; },
ice(S){ const base=C('#8ea6b4'), deep=C('#64808f'), frost=C('#c0ccd4');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*3,v*3,91,4,3), f=fbm(u*8,v*8,92,3,8), wx=fbm(u*4,v*4,97,2,4)*.5, w=worley(u*5+wx,v*5,93,5,5), mask=smooth(.5,.62,fbm(u*3,v*3,98,3,3));
		let c=mixc(deep,base,.3+.7*smooth(.25,.62,n)); c=mixc(c,frost,smooth(.6,.82,f)*.5);
		const e=w.f2-w.f1, m2=mask*smooth(.35,.65,fbm(u*6,v*6,99,2,6)); c=mixc(c,[208,218,226],smooth(.012,.003,e)*.16*m2); c=shade(c,-smooth(.003,0,e)*.07*m2); put(o,c); jitter(o,i,j,95,6); });
	const x=cv.getContext('2d');
	scatter(x,S,S,26,96,90,(c,R)=>{ c.rotate(R()*TAU); c.beginPath(); c.moveTo(-40-R()*40,0); c.quadraticCurveTo(0,R()*14-7,40+R()*40,R()*8-4); c.lineWidth=.8; c.strokeStyle='rgba(235,242,246,.35)'; c.stroke(); });
	overlayGrime(x,S,S,.04); return cv; },
asphalt(S){ const base=C('#4b4a4c'), worn=C('#5e5c5c'), dark=C('#3a393b');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*4,v*4,101,4,4), m=fbm(u*10,v*10,102,3,10), w=worley(u*4,v*4,103,4,4);
		let c=mixc(dark,base,smooth(.25,.6,n)); c=mixc(c,worn,smooth(.55,.75,m)*.6);
		c=shade(c,-smooth(.025,.008,w.f2-w.f1)*.55*smooth(.5,.62,fbm(u*6,v*6,104,2,6))); put(o,c); jitter(o,i,j,105,26); });
	const x=cv.getContext('2d');
	scatter(x,S,S,700,106,3,(c,R)=>{ ell(c,0,0,.6+R()*.9,.6+R()*.8); c.fillStyle=R()<.5?'rgba(140,136,128,.55)':'rgba(24,22,24,.5)'; c.fill(); });
	scatter(x,S,S,14,107,60,(c,R)=>crackWalk(c,R,10+(R()*14|0),2.2,'rgba(28,27,30,.6)',true));
	scatter(x,S,S,18,108,16,(c,R)=>{ ell(c,0,0,3+R()*10,2+R()*7,R()*3); c.fillStyle='rgba(20,18,20,.28)'; c.fill(); });
	overlayGrime(x,S,S,.1); return cv; },
lot(S){ const base=C('#8a867e'), dark=C('#706b63'), joint=C('#5a554e'), SL=128;
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const sx=(i/SL)|0, sy=(j/SL)|0, t=(hash2(sx,sy,111)-.5)*.1, n=fbm(u*6,v*6,112,4,6), m=fbm(u*32,v*32,113,2,32);
		let c=mixc(dark,base,smooth(.25,.6,n)); c=shade(c,t+(m-.5)*.06); const jx=Math.min(i%SL,SL-i%SL), jy=Math.min(j%SL,SL-j%SL), jd=Math.min(jx,jy);
		if(jd<1.5) c=mixc(c,joint,.85); else if(jd<3) c=shade(c,.06); put(o,c); jitter(o,i,j,114,14); });
	const x=cv.getContext('2d');
	scatter(x,S,S,10,115,40,(c,R)=>{ ell(c,0,0,8+R()*22,6+R()*14,R()*3); c.fillStyle='rgba(30,26,24,'+(.1+R()*.15)+')'; c.fill(); });
	scatter(x,S,S,8,116,40,(c,R)=>{ ell(c,0,0,6+R()*16,4+R()*10,R()*3); c.fillStyle='rgba(128,66,34,.12)'; c.fill(); });
	scatter(x,S,S,16,117,50,(c,R)=>crackWalk(c,R,6+(R()*10|0),.8,'rgba(50,46,42,.5)',false));
	overlayGrime(x,S,S,.16); return cv; },
wash(S){ const base=C('#a3977d'), dark=C('#8c806a'), light=C('#b5aa90');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*3,v*3,121,4,3), f=fbm(u*2,v*24,122,3,2,24), w=worley(u*9+fbm(u*4,v*4,123,2,4)*.7,v*9,124,9,9), mask=smooth(.4,.55,fbm(u*4,v*4,127,3,4));
		let c=mixc(dark,base,.35+.65*smooth(.25,.6,n)); c=mixc(c,light,smooth(.55,.75,f)*.5); const e=w.f2-w.f1;
		c=shade(c,(-smooth(.045,.015,e)*.26+smooth(.08,.045,e)*smooth(.015,.045,e)*.06)*mask); put(o,c); jitter(o,i,j,125,10); });
	const x=cv.getContext('2d');
	scatter(x,S,S,240,126,5,(c,R)=>pebble(c,R,.8+R()*1.8,['#8a8178','#9a8a74','#6d6258']));
	overlayGrime(x,S,S,.1); return cv; },
oil(S){ const base=C('#2c2824'), sheen=C('#57524b'), irid=[C('#5c4c66'),C('#56603e'),C('#6a5236')];
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*3,v*3,131,4,3), s=fbm(u*5,v*5,132,4,5), b=fbm(u*2,v*2,133,3,2);
		let c=mixc(base,sheen,smooth(.6,.85,s)*.6); c=shade(c,(n-.5)*.15); const band=(b*6)%1, k=(b*6)|0; c=mixc(c,irid[k%3],smooth(.3,.5,band)*smooth(.8,.6,band)*.22); put(o,c); jitter(o,i,j,134,6); });
	const x=cv.getContext('2d');
	scatter(x,S,S,40,135,24,(c,R)=>{ ell(c,0,0,4+R()*12,2+R()*6,R()*3); c.fillStyle='rgba(150,146,140,.12)'; c.fill(); });
	return cv; },
shallows(S){ const sand=C('#8f8768'), tint=C('#3f6468'), light=C('#a7b8b0');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*4,v*4,141,4,4), b=fbm(u*16,v*16,148,3,16), wx=fbm(u*3,v*3,142,3,3)*.8, r=fbm(u*6,v*20,144,3,6,20);
		let c=mixc(shade(sand,-.2),sand,.3+.7*smooth(.3,.7,n)); c=shade(c,(b-.5)*.2); c=mixc(c,tint,.5);
		const rd=1-Math.abs(2*fbm(u*7+wx,v*7+wx*.6,143,3,7)-1); c=mixc(c,light,smooth(.88,.98,rd)*.13*smooth(.4,.65,fbm(u*5,v*5,149,2,5))); c=shade(c,(r-.5)*.08); put(o,c); jitter(o,i,j,145,6); });
	const x=cv.getContext('2d');
	scatter(x,S,S,240,146,6,(c,R)=>{ ell(c,0,0,1+R()*3,1+R()*2.4,R()*3); c.fillStyle=R()<.5?'rgba(46,60,56,.3)':'rgba(150,156,136,.22)'; c.fill(); });
	scatter(x,S,S,60,147,20,(c,R)=>{ c.beginPath(); c.arc(0,0,6+R()*10,Math.PI*1.1,Math.PI*1.9); c.lineWidth=.9; c.strokeStyle='rgba(196,208,204,.28)'; c.stroke(); });
	return cv; },
water(S){ const deep=C('#284a57'), mid=C('#33606b'), dark=C('#1f3d49');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*3,v*3,151,4,3), m=fbm(u*8,v*20,152,3,8,20);
		let c=mixc(dark,deep,smooth(.2,.5,n)); c=mixc(c,mid,smooth(.5,.8,n)*.7); c=shade(c,(m-.5)*.1); put(o,c); jitter(o,i,j,153,4); });
	const x=cv.getContext('2d');
	scatter(x,S,S,380,154,16,(c,R)=>{ const l=4+R()*10; c.beginPath(); c.moveTo(-l,0); c.quadraticCurveTo(0,-2-R()*2,l,0); c.lineWidth=.9+R()*.6; c.strokeStyle='rgba(120,160,168,'+(.15+R()*.2)+')'; c.stroke(); });
	return cv; },
conveyor(S){ const rub=C('#383733'), dark=C('#2a2926'), paint=C('#9a8a58'), P=32;
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*4,v*4,161,3,4), wl=fbm(u*2,v*64,162,3,2,64), k=i%P;
		let c=mixc(dark,rub,.3+.7*smooth(.3,.7,n)); c=shade(c,(wl-.5)*.12);
		if(k<2) c=shade(c,-.45); else if(k<6) c=shade(c,.2-(k-2)*.04); else if(k<8) c=shade(c,-.3);
		put(o,c); jitter(o,i,j,163,8); });
	const x=cv.getContext('2d'), pc=canvas(S,S), p=pc.getContext('2d');
	for(let cx=96;cx<S;cx+=128) for(let cy=64;cy<S;cy+=128){ p.save(); p.translate(cx,cy); p.beginPath(); p.moveTo(-24,-30); p.lineTo(8,0); p.lineTo(-24,30); p.lineWidth=9; p.lineCap='butt'; p.lineJoin='miter'; p.strokeStyle=css(paint,.8); p.stroke(); p.restore(); }
	const m=pixels(S,S,(u,v,i,j,o)=>{ const w=fbm(u*16,v*16,164,3,16); o[0]=o[1]=o[2]=0; o[3]=smooth(.56,.7,w)*255; });
	p.globalCompositeOperation='destination-out'; p.drawImage(m,0,0); x.drawImage(pc,0,0);
	overlayGrime(x,S,S,.2); return cv; },
rock(S){ const base=C(ROCK), dark=C('#655c53'), lip=C(LIP), lichen=C('#7d8a5a'), pale=C('#b4ae94');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const wx=fbm(u*4,v*4,171,3,4), w=worley(u*4+wx*.9,v*4+wx*.5,172,4,4), n=fbm(u*16,v*16,173,3,16), l=fbm(u*5,v*5,174,3,5),
		g=fbm(u*6,v*6,177,4,6), rid=1-Math.abs(2*fbm(u*10,v*14,178,3,10,14)-1), mask=smooth(.38,.5,fbm(u*3,v*3,179,2,3));
		const e=w.f2-w.f1; let c=mixc(dark,base,.45+.35*w.id+.3*(g-.5)); c=mixc(c,lip,smooth(.7,.95,rid)*.3); c=shade(c,(n-.5)*.16);
		c=shade(c,-smooth(.06,.01,e)*.45*mask); c=mixc(c,w.id<.5?lichen:pale,smooth(.7,.8,l)*.45); put(o,c); jitter(o,i,j,175,14); });
	const x=cv.getContext('2d');
	scatter(x,S,S,40,176,40,(c,R)=>crackWalk(c,R,5+(R()*8|0),1,'rgba('+AO+',.35)',false));
	overlayGrime(x,S,S,.14); return cv; },
roof(S){ const base=C('#6b6762'), dark=C('#57534f'), seam=C('#85807a'), SP=128;
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*4,v*4,181,4,4), st=fbm(u*6,v*6,182,3,6), k=j%SP;
		let c=mixc(dark,base,smooth(.3,.65,n)); c=shade(c,-smooth(.55,.75,st)*.12);
		if(k<4) c=mixc(c,seam,.7); else if(k<6) c=shade(c,-.15); put(o,c); jitter(o,i,j,183,30); });
	const x=cv.getContext('2d');
	scatter(x,S,S,6,184,60,(c,R)=>{ const w=30+R()*50, h=20+R()*40; c.fillStyle='rgba(40,38,36,.18)'; c.fillRect(-w/2,-h/2,w,h); c.strokeStyle='rgba(30,28,26,.3)'; c.lineWidth=1; c.strokeRect(-w/2,-h/2,w,h); });
	overlayGrime(x,S,S,.18); return cv; },
bridge(S){ const wood=C('#7a6a56'), grey=C('#86807a'), gap=C('#2a2420'), PW=32;
	const joints=[]; for(let k=0;k<S/PW;k++){ const j0=(hash2(k,0,191)*256)|0; joints.push([j0,j0+256]); }
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const k=(i/PW)|0, ki=i%PW, jt=joints[k], seg=j<jt[0]||j>=jt[1]?0:1, t=hash2(k,seg,192), g=fbm(u*64,v*4+t*3,193,3,64,4);
		let c=mixc(wood,grey,.35+t*.4); c=shade(c,(g-.5)*.22+(t-.5)*.08);
		const dj=Math.min(Math.abs(j-jt[0]),Math.abs(j-jt[1]),Math.abs(j-jt[0]-S),Math.abs(j-jt[1]+S));
		if(ki<2||dj<1.2) c=mixc(c,gap,.85); else if(ki<3||ki>PW-2) c=shade(c,-.12); put(o,c); jitter(o,i,j,194,8); });
	const x=cv.getContext('2d');
	for(let k=0;k<S/PW;k++) for(const jy of joints[k]) for(const s of [-1,1]) for(const dx of [9,PW-7]){ const y=((jy+s*5)%S+S)%S; ell(x,k*PW+dx,y,1.3,1.3); x.fillStyle='rgba(40,36,34,.8)'; x.fill(); }
	overlayGrime(x,S,S,.2); return cv; },
gravel(S){ const base=C('#807a70'), dark=C('#655f56');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*5,v*5,201,4,5); put(o,mixc(dark,base,smooth(.25,.7,n))); jitter(o,i,j,202,22); });
	const x=cv.getContext('2d');
	scatter(x,S,S,3200,203,5,(c,R)=>pebble(c,R,.8+R()*2,['#8a8178','#a39c8f','#6f6a62','#7d6f5f','#968a7a']));
	overlayGrime(x,S,S,.12); return cv; },
/* ---- Road Atlas landscapes (forest, coast, ghost town, salt flats, volcano, suburbs) ---- */
/* forest floor: pine needle litter over dark humus, mossy patches, twigs and cones; a warm brown next to grass and moss */
needles(S){ const base=C('#7f6246'), dark=C('#563f2b'), rust=C('#8e6a46'), olive=C('#62603c');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*4,v*4,221,4,4), m=fbm(u*18,v*18,222,3,18), d=fbm(u*3,v*3,223,3,3), h=fbm(u*48,v*48,224,2,48);
		let c=mixc(dark,base,.3+.7*smooth(.25,.66,n)); c=mixc(c,rust,smooth(.55,.75,m)*.35); c=mixc(c,olive,smooth(.6,.74,d)*.55); c=shade(c,(h-.5)*.14); put(o,c); jitter(o,i,j,225,14); });
	const x=cv.getContext('2d'), moss=(px,py)=>fbm(px/S*3,py/S*3,223,3,3);
	scatter(x,S,S,21000,226,8,(c,R,k,px,py)=>{ const a=R()*TAU, l=5+R()*4.5, q=R(); c.beginPath(); c.moveTo(-Math.cos(a)*l/2,-Math.sin(a)*l/2); c.lineTo(Math.cos(a)*l/2,Math.sin(a)*l/2); c.lineWidth=.6+R()*.4;
		c.strokeStyle=q<.35?'rgba(184,138,86,.7)':q<.75?'rgba(124,84,48,.65)':'rgba(52,36,22,.6)'; c.stroke(); });
	scatter(x,S,S,700,227,6,(c,R,k,px,py)=>{ if(moss(px,py)<.58) return; const r=1.4+R()*2.4; vol(c,0,0,r,r*(.8+R()*.3),R()<.6?'#5c6236':'#6c7040',{hi:.22,lo:-.32}); });
	scatter(x,S,S,70,228,18,(c,R)=>{ const a=R()*TAU, l=8+R()*14; limb(c,[-Math.cos(a)*l/2,-Math.sin(a)*l/2],[Math.cos(a)*l/2,Math.sin(a)*l/2],1.2+R()*1.2,'#5e4a36'); });
	scatter(x,S,S,46,229,8,(c,R)=>{ c.rotate(R()*TAU); ell(c,0,0,4.6,3.1); c.fillStyle='rgba('+AO+',.3)'; c.fill(); vol(c,0,0,3.8,2.5,'#7a5636',{hi:.25,lo:-.4}); c.strokeStyle='rgba(40,26,14,.6)'; c.lineWidth=.6; for(let k=-2;k<=2;k++){ c.beginPath(); c.moveTo(k*1.4,-2); c.lineTo(k*1.4+.8,2); c.stroke(); } });
	overlayGrime(x,S,S,.12); return cv; },
/* pale coast sand: cooler and greyer than desert sand, soft swash ripples, wet patches, shells and wrack lines */
beach(S){ const base=C('#a99f88'), dark=C('#928872'), light=C('#bab29c'), wet=C('#867e6c');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*3,v*3,231,4,3), w=fbm(u*4,v*4,232,3,4);
		const rip=Math.sin(TAU*(v*14+u+w*1.3)), crest=Math.pow(Math.max(0,rip),3), trough=Math.pow(Math.max(0,-rip),2);
		let c=mixc(dark,base,smooth(.25,.65,n)); c=shade(c,crest*.04-trough*.035); c=mixc(c,light,smooth(.6,.8,fbm(u*8,v*8,233,3,8))*.35);
		c=mixc(c,wet,smooth(.6,.72,fbm(u*2,v*2,234,3,2))*.5); put(o,c); jitter(o,i,j,235,9); });
	const x=cv.getContext('2d');
	scatter(x,S,S,7,236,120,(c,R)=>{ c.rotate(R()*TAU); const L=90+R()*90; for(let k=0;k<70;k++){ const t=k/70, px=(t-.5)*L, py=Math.sin(t*5+R()*.4)*8+(R()-.5)*5; ell(c,px,py,1+R()*2,.7+R()*1.2,R()*3); c.fillStyle=R()<.6?'rgba(58,62,44,.5)':'rgba(96,84,60,.45)'; c.fill(); } });
	scatter(x,S,S,110,237,6,(c,R)=>{ c.rotate(R()*TAU); const r=2+R()*2.4; c.beginPath(); c.moveTo(0,r*.6); c.arc(0,r*.6,r*1.3,-Math.PI*.82,-Math.PI*.18); c.closePath(); c.fillStyle=R()<.6?'#d6cdbb':'#c4a798'; c.fill();
		c.strokeStyle='rgba(120,100,84,.5)'; c.lineWidth=.5; for(let k=-2;k<=2;k++){ c.beginPath(); c.moveTo(0,r*.6); c.lineTo(Math.sin(k*.3)*r*1.2,r*.6-Math.cos(k*.3)*r*1.2); c.stroke(); } });
	scatter(x,S,S,160,238,5,(c,R)=>pebble(c,R,.8+R()*1.4,['#8a8272','#a49c8a','#6f6a60']));
	scatter(x,S,S,6,239,24,(c,R)=>{ const a=R()*TAU, l=14+R()*16; limb(c,[-Math.cos(a)*l/2,-Math.sin(a)*l/2],[Math.cos(a)*l/2,Math.sin(a)*l/2],2.4+R()*1.6,'#9a8e7c'); });
	overlayGrime(x,S,S,.07); return cv; },
/* salt crust: pale polygons with raised pressure ridges and a hairline crack along each; bright like snow (an exception) */
salt(S){ const base=C('#bab5aa'), dark=C('#a39e93'), ridge=C('#d3cfc6'), dirt=C('#978c7c');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const wx=fbm(u*4,v*4,241,3,4)*.4, w=worley(u*7+wx,v*7+wx*.7,242,7,7), e=w.f2-w.f1, n=fbm(u*3,v*3,243,4,3), m=fbm(u*24,v*24,244,2,24),
		mask=.45+.55*smooth(.32,.6,fbm(u*5,v*5,245,2,5));
		let c=mixc(dark,base,.35+.65*smooth(.25,.65,n)); c=shade(c,(w.id-.5)*.05+(m-.5)*.05);
		c=shade(c,-smooth(.12,.07,e)*smooth(.03,.07,e)*.05); c=mixc(c,ridge,smooth(.07,.02,e)*.75*mask); c=shade(c,-smooth(.012,0,e)*.32*mask);
		c=mixc(c,dirt,smooth(.66,.8,fbm(u*2,v*2,246,3,2))*.32); put(o,c); if(hash2(i,j,247)>.997){ o[0]+=18; o[1]+=18; o[2]+=18; } jitter(o,i,j,248,7); });
	const x=cv.getContext('2d');
	scatter(x,S,S,50,249,6,(c,R)=>{ ell(c,0,0,1+R()*1.6,1+R()*1.3); c.fillStyle='rgba(110,102,90,.35)'; c.fill(); });
	overlayGrime(x,S,S,.04); return cv; },
/* volcanic ash: soft grey-brown drifts with wind ripples, cinders and the odd pumice stone */
ash(S){ const base=C('#6b6662'), dark=C('#55514f'), light=C('#7e7873'), warm=C('#6f6259');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*3,v*3,251,4,3), m=fbm(u*20,v*20,253,3,20), rip=Math.sin(TAU*(v*20+u*2+fbm(u*4,v*4,254,3,4)*1.5));
		let c=mixc(dark,base,.3+.7*smooth(.25,.65,n)); c=shade(c,Math.pow(Math.max(0,rip),3)*.05-Math.pow(Math.max(0,-rip),2)*.04);
		c=mixc(c,light,smooth(.55,.8,m)*.3); c=mixc(c,warm,smooth(.58,.74,fbm(u*2,v*2,255,3,2))*.45); put(o,c); jitter(o,i,j,256,10); });
	const x=cv.getContext('2d');
	scatter(x,S,S,1100,257,5,(c,R)=>pebble(c,R,.7+R()*1.5,['#3e3a38','#4a4442','#55504b','#5e4a40']));
	scatter(x,S,S,40,258,6,(c,R)=>pebble(c,R,1.6+R()*2,['#8a837a','#958c80']));
	overlayGrime(x,S,S,.1); return cv; },
/* tar: glossy near-black with slow folds, a soft sheen and domed bubbles (some popped); below the band like oil */
tar(S){ const base=C('#1f1c1a'), sheen=C('#4d4842'), brown=C('#2f251d');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const s=fbm(u*6+fbm(u*2,v*2,262,2,2)*1.5,v*6,263,4,6), b=fbm(u*2,v*2,264,3,2), rd=1-Math.abs(2*fbm(u*5,v*5,265,3,5)-1);
		let c=mixc(base,brown,smooth(.4,.7,b)*.6); c=shade(c,Math.sin(TAU*s*3)*.05); c=mixc(c,sheen,Math.pow(smooth(.6,.85,s),2)*.55); c=mixc(c,[118,112,104],Math.pow(rd,7)*.42); put(o,c); jitter(o,i,j,266,4); });
	const x=cv.getContext('2d');
	scatter(x,S,S,30,267,30,(c,R)=>{ const r=6+R()*16; for(let k=1;k<3;k++){ ell(c,0,0,r*k*.6,r*k*.5); c.lineWidth=.8; c.strokeStyle='rgba(120,114,104,'+(.16/k)+')'; c.stroke(); } });
	scatter(x,S,S,150,268,14,(c,R)=>{ const r=2+R()*7;
		if(R()<.3){ ell(c,0,0,r,r); c.lineWidth=1; c.strokeStyle='rgba(130,124,114,.35)'; c.stroke(); ell(c,0,0,r*.7,r*.7); c.fillStyle='rgba(8,6,5,.55)'; c.fill(); return; }
		ell(c,0,0,r*1.15,r*1.15); c.fillStyle='rgba(6,5,4,.5)'; c.fill(); vol(c,0,0,r,r,'#2c2723',{hi:.35,lo:-.4,fy:0}); ell(c,0,0,r*.32,r*.26); c.fillStyle='rgba(176,170,160,.5)'; c.fill(); });
	return cv; },
/* lava, drawn in the water layer: dark cooled crust plates over a molten network; the brightest cores stay thin */
lava(S){ const crust=C('#2b2320'), crustL=C('#463a33'), deep=C('#6e2210'), mid=C('#a8421b'), hot=C('#d2712e'), core=C('#e8a85a');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const wx=fbm(u*3,v*3,271,3,3)*.6, w=worley(u*6+wx,v*6+wx*.8,272,6,6), e=w.f2-w.f1, cw=.035+.07*fbm(u*4,v*4,273,3,4);
		const pool=smooth(.6,.72,fbm(u*2,v*2,274,4,2)), fl=fbm(u*10+wx*3,v*10,275,3,10), g=smooth(cw,0,e), heat=Math.max(g*(.75+.25*w.id),pool*(.55+.45*fl));
		let c=mixc(crust,crustL,smooth(.3,.7,fbm(u*16,v*16,276,3,16))*.6); c=shade(c,(w.id-.5)*.08); c=mixc(c,deep,smooth(.62,.82,fbm(u*5,v*5,277,2,5))*.3);
		c=shade(c,smooth(cw+.05,cw,e)*smooth(cw*.6,cw,e)*.12);
		const t=Math.min(1,heat*(.8+.3*fl)), col=t<.5?mixc(deep,mid,t/.5):t<.85?mixc(mid,hot,(t-.5)/.35):mixc(hot,core,(t-.85)/.15);
		c=mixc(c,col,smooth(0,.3,heat)); put(o,c); jitter(o,i,j,278,6); });
	const x=cv.getContext('2d');
	scatter(x,S,S,40,279,40,(c,R)=>crackWalk(c,R,4+(R()*6|0),.9,'rgba(176,66,26,.45)',true));
	return cv; },
/* basalt: hexagonal column tops (volcano wall tops), each at its own height, dark joints with ash in them */
basalt(S){ const dark=C('#3f3c3a'), light=C('#6c6763'), joint=C('#211e1d'), ash=C('#6b6662');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const wx=fbm(u*4,v*4,281,3,4)*.25, w=worley(u*12+wx,v*12,282,12,12), e=w.f2-w.f1, g=fbm(u*48,v*48,283,2,48), l=fbm(u*5,v*5,284,3,5);
		let c=mixc(dark,light,.08+w.id*.84); c=shade(c,(g-.5)*.12-w.f1*.12); c=mixc(c,C('#76705a'),smooth(.7,.8,l)*.35);
		c=mixc(c,ash,smooth(.55,.78,fbm(u*4,v*4,285,3,4))*(1-w.id)*.5);
		c=shade(c,smooth(.11,.06,e)*smooth(.025,.06,e)*.15); c=mixc(c,joint,smooth(.05,.014,e)*.92); put(o,c); jitter(o,i,j,286,12); });
	const x=cv.getContext('2d');
	scatter(x,S,S,40,287,30,(c,R)=>crackWalk(c,R,3+(R()*4|0),.9,'rgba('+AO+',.4)',false));
	overlayGrime(x,S,S,.1); return cv; },
/* ghost town roofs: sun-bleached wooden shakes in courses along x, butt ends shaded, a few missing, tin patches */
roof_timber(S){ const RH=32, cols=[C('#7d7262'),C('#6e5f4e'),C('#8a7f70'),C('#746856')], rows=[];
	for(let r=0;r<S/RH;r++){ const R=rng(291+r*7), cuts=[]; let x=R()*30; const x0=x; while(x<x0+S-16){ cuts.push(x); x+=11+R()*14; } rows.push(cuts); }
	const shakeAt=(row,i)=>{ const cuts=rows[row], n=cuts.length; let k=n-1; for(let q=0;q<n;q++){ const a=cuts[q], b=q+1<n?cuts[q+1]:cuts[0]+S; if(((i-a)%S+S)%S<b-a){ k=q; break; } } const a=cuts[k], b=k+1<n?cuts[k+1]:cuts[0]+S; return [k,((i-a)%S+S)%S,b-a]; };
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const row=(j/RH)|0, kk=j%RH, [k,di,w]=shakeAt(row,i), t=hash2(k,row,292), g=fbm(u*64+t*5,v*6,293,3,64,6), lm=fbm(u*4,v*4,294,3,4);
		let c=mixc(cols[(t*4)|0],cols[((t*13)|0)%4],.4); c=shade(c,(g-.5)*.26+(t-.5)*.06); c=shade(c,-kk/RH*.08);
		if(kk>RH-4) c=shade(c,-.32*(kk-(RH-4))/4); if(kk<2) c=shade(c,.06); if(di<1.5||di>w-1) c=shade(c,-.45);
		if(t>.985&&kk<RH-4){ c=mixc(C('#2a221c'),c,.4); if(Math.abs(kk-12)<2) c=C('#5a4a3a'); }
		c=mixc(c,C('#6a6e48'),smooth(.68,.8,lm)*.4); put(o,c); jitter(o,i,j,295,10); });
	const x=cv.getContext('2d');
	scatter(x,S,S,3,296,70,(c,R)=>{ c.rotate((R()-.5)*.1); sheet(c,0,0,50+R()*40,40+R()*30,R()<.5?'#7a6a5a':'#6d6a64',R,{rib:5,rust:.9}); for(const s of [-1,1]) for(const t of [-1,1]){ ell(c,s*20,t*14,1,1); c.fillStyle='#2a2826'; c.fill(); } });
	overlayGrime(x,S,S,.18); return cv; },
/* suburb roofs: slate-grey three-tab asphalt shingles, granular, butt edges shaded, algae streaks running downslope */
roof_shingle(S){ const RH=24, TW=48, base=C('#5d6065');
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const row=(j/RH)|0, off=(row%2)*TW/2, tab=(((i+off)/TW)|0)%(S/TW), t=hash2(tab,row,301), k=j%RH, st=fbm(u*8,v*2,302,3,8,2), m=fbm(u*5,v*5,303,3,5);
		let c=shade(base,(t-.5)*.16); if(t>.975) c=mixc(c,C('#64584f'),.6); c=shade(c,-smooth(.55,.72,st)*.14);
		if(k>RH-3) c=shade(c,-.3*(k-(RH-3))/3); if(k<1.5) c=shade(c,.06); if((i+off)%TW<1.6&&k>4) c=shade(c,-.4);
		c=mixc(c,C('#5c6648'),smooth(.7,.8,m)*.35); put(o,c); jitter(o,i,j,304,24); });
	overlayGrime(cv.getContext('2d'),S,S,.14); return cv; },
/* suburb lawn: mown stripes 128 px wide (soft light/dark bands along y), short blades, clover and daisies */
lawn(S){ const base=C('#6b8648'), dark=C('#5a7440'), light=C('#7b9450'), dry=C('#8e8a5c'), SW=64;
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const n=fbm(u*4,v*4,311,4,4), m=fbm(u*24,v*24,312,3,24), k=i%SW, st=((i/SW)|0)%2, edge=smooth(0,6,Math.min(k,SW-k));
		let c=mixc(dark,base,.35+.65*smooth(.25,.65,n)); c=mixc(c,light,smooth(.55,.8,m)*.35); c=mixc(c,dry,smooth(.68,.78,fbm(u*3,v*3,313,3,3))*.35);
		c=shade(c,(st?.045:-.04)*edge); put(o,c); jitter(o,i,j,314,12); });
	const x=cv.getContext('2d');
	scatter(x,S,S,13000,315,5,(c,R,k,px)=>{ const st=((px/SW)|0)%2, a=Math.PI/2+(st?.35:-.35)+(R()-.5)*.6, l=1.6+R()*2; c.beginPath(); c.moveTo(0,0); c.lineTo(Math.cos(a)*l,Math.sin(a)*l); c.lineWidth=.7;
		c.strokeStyle=R()<.5?(st?'rgba(150,170,104,.45)':'rgba(64,84,40,.5)'):'rgba(96,120,62,.5)'; c.stroke(); });
	scatter(x,S,S,60,316,6,(c,R)=>{ for(let k=0;k<3;k++){ const a=k/3*TAU+R(); ell(c,Math.cos(a)*1.4,Math.sin(a)*1.4,1.3,1.1); c.fillStyle='rgba(84,116,58,.8)'; c.fill(); } });
	scatter(x,S,S,40,317,4,(c,R)=>{ ell(c,0,0,1.3,1.3); c.fillStyle='rgba(226,222,206,.85)'; c.fill(); ell(c,0,0,.5,.5); c.fillStyle='#c8a848'; c.fill(); });
	overlayGrime(x,S,S,.06); return cv; }
};
function renderGround(name){ return GROUND[name](GROUND_TEXELS); }
/* 256 px tileable greyscale noise for macro variation and organic borders in the ground shader */
function renderMacro(){ const S=256, vals=new Float32Array(S*S); let lo=9,hi=-9;
	for(let j=0;j<S;j++) for(let i=0;i<S;i++){ const u=i/S, v=j/S, f=fbm(u*4,v*4,211,5,4)*.7+fbm(u*16,v*16,212,3,16)*.3; vals[j*S+i]=f; lo=Math.min(lo,f); hi=Math.max(hi,f); }
	return pixels(S,S,(u,v,i,j,o)=>{ const g=(vals[j*S+i]-lo)/(hi-lo)*255; o[0]=o[1]=o[2]=g; }); }

/* ---------- edge strips: 512x96 texels, tile along x, the feature (water, cliff top, wall) at the top ---------- */
const EW=512, EH=96;
function stripAO(ctx,y0,y1,a){ const g=ctx.createLinearGradient(0,y0,0,y1); g.addColorStop(0,'rgba('+AO+','+a+')'); g.addColorStop(.45,'rgba('+AO+','+(a*.4)+')'); g.addColorStop(1,'rgba('+AO+',0)'); ctx.fillStyle=g; ctx.fillRect(0,y0,EW,y1-y0); }
/* an opaque band whose lower boundary wobbles: y(u) = y0 + amp * noise, returns the edge function */
function wobble(seed,y0,amp,freq){ return u=>y0+(fbm(u*freq,0,seed,4,freq,0)-.5)*2*amp; }
const EDGE={
shore_foam(){ const top=wobble(301,30,9,6), top2=wobble(302,16,7,5);
	return pixels(EW,EH,(u,v,i,j,o)=>{ const y=j, f=top(u), f2=top2(u), h=hash2(i,j,303);
		let a=0, c=[216,214,200];
		const d=y-f; if(d>-3&&d<4){ a=.85*(1-Math.abs(d+.5)/4); if(h>.86) a*=.3; }
		const d2=Math.abs(y-f2); if(d2<1.6&&a<.5){ a=Math.max(a,.4*(1-d2/1.6)*smooth(.3,.6,fbm(u*12,0,304,3,12,0))); }
		if(y<f-3){ const t=smooth(f-3,0,y); if(a<.15){ c=[190,206,204]; a=.16*t*(.6+.4*fbm(u*20,v*4,305,2,20,0)); } }
		if(y>f+3){ const w=1-smooth(f+3,f+46,y); if(a<.4){ c=[40,32,24]; a=.3*w; } }
		o[0]=c[0]; o[1]=c[1]; o[2]=c[2]; o[3]=a*255; }); },
cliff_lip(){ const edge=wobble(311,34,7,8), base=C(ROCK), lip=C(LIP), dark=C('#655c53');
	const cv=pixels(EW,EH,(u,v,i,j,o)=>{ const e=edge(u), n=fbm(u*24,v*6,312,3,24,0), g=fbm(u*8,v*2,316,3,8,0), rid=1-Math.abs(2*fbm(u*16,v*3,313,3,16,0)-1);
		let c, a;
		if(j<e-12){ c=mixc(dark,base,.5+g*.5); c=shade(c,(n-.5)*.16); a=smooth(0,14,j); }
		else if(j<e){ c=mixc(base,lip,.55+n*.45); c=shade(c,(rid-.6)*.15); a=1; }
		else { c=[18,13,16]; a=.55*(1-smooth(e,e+52,j)); }
		put(o,c); o[3]=a*255; if(j<e) jitter(o,i,j,314,14); });
	const x=cv.getContext('2d');
	scatter(x,EW,EH,24,317,30,(c,R,k,px,py)=>{ c.translate(0,-py+6+R()*20); crackWalk(c,R,3+(R()*4|0),1,'rgba('+AO+',.35)',false); },false);
	scatter(x,EW,EH,60,315,10,(c,R,k,px,py)=>{ c.translate(0,edge(px/EW)-py+R()*14); vol(c,0,0,1.5+R()*3.5,1.3+R()*2.5,R()<.5?'#8a8178':'#a39a8c',{hi:.3,lo:-.45}); },false);
	return cv; },
canyon_rim(){ const edge=wobble(321,46,8,7), deep=C('#4a3326'), wall=C('#7a4e38'), lip=C('#b88e72');
	const cv=pixels(EW,EH,(u,v,i,j,o)=>{ const e=edge(u), n=fbm(u*20,v*4,322,3,20,0), strata=Math.sin(j*.9+fbm(u*6,v,323,2,6,0)*8);
		let c,a=1;
		if(j<e-14){ c=mixc(deep,wall,smooth(0,e-14,j)*.8); c=shade(c,strata*.06+(n-.5)*.12); }
		else if(j<e){ c=mixc(wall,lip,smooth(e-14,e-2,j)); c=shade(c,(n-.5)*.18); }
		else { c=[60,40,28]; a=.3*(1-smooth(e,e+30,j)); }
		put(o,c); o[3]=a*255; if(j<e) jitter(o,i,j,324,12); });
	const x=cv.getContext('2d');
	scatter(x,EW,EH,50,325,10,(c,R,k,px,py)=>{ c.translate(0,edge(px/EW)-py+2+R()*12); vol(c,0,0,1.4+R()*3,1.2+R()*2.4,R()<.5?'#9a6e54':'#7a5a46',{hi:.3,lo:-.45}); },false);
	return cv; },
mesa_lip(){ const edge=wobble(331,30,6,7), top=C('#a4765a'), lip=C('#c49c7e'), face=[C('#8a5a42'),C('#a36a4a'),C('#7a4c38')];
	const cv=pixels(EW,EH,(u,v,i,j,o)=>{ const e=edge(u), n=fbm(u*22,v*5,332,3,22,0);
		let c,a=1;
		if(j<e-10){ c=mixc(top,lip,n*.4); a=smooth(0,12,j); }
		else if(j<e){ c=mixc(top,lip,.6+n*.4); }
		else if(j<e+14){ const b=((j-e)/4.7)|0; c=shade(face[b%3],(n-.5)*.2-(j-e)/14*.15); }
		else { c=[18,13,16]; a=.5*(1-smooth(e+14,e+60,j)); }
		put(o,c); o[3]=a*255; if(j<e+14) jitter(o,i,j,333,12); });
	const x=cv.getContext('2d');
	scatter(x,EW,EH,40,334,10,(c,R,k,px,py)=>{ c.translate(0,edge(px/EW)-py+16+R()*14); vol(c,0,0,1.4+R()*3,1.2+R()*2.4,'#9a6a50',{hi:.3,lo:-.45}); },false);
	return cv; },
kerb(){ const stone=C('#9d978c');
	return pixels(EW,EH,(u,v,i,j,o)=>{ const n=fbm(u*32,v*8,341,3,32,0), blk=(i/64)|0, t=(hash2(blk,0,342)-.5)*.08; let c,a=1;
		if(j<30){ c=shade(stone,t+(n-.5)*.12); if(i%64<2) c=shade(c,-.3); if(j<3) c=shade(c,-.1); if(j>24) c=shade(c,.08); }
		else if(j<36){ c=shade(stone,-.32+(n-.5)*.1); }
		else { c=[24,20,18]; a=.42*(1-smooth(36,60,j)); }
		put(o,c); o[3]=a*255; if(j<36) jitter(o,i,j,343,10); }); },
/* city blocks: the roof's parapet inside the contour (v < .5), the building's AO on the pavement outside */
roof_edge(){ const coping=C('#a39d93'), inner=C('#4c4844'), outer=C('#3a3633');
	return pixels(EW,EH,(u,v,i,j,o)=>{ const n=fbm(u*28,v*6,381,3,28,0), blk=(i/40)|0, t=(hash2(blk,0,382)-.5)*.07; let c=[18,13,16], a=0;
		if(j<16){ a=0; }
		else if(j<27){ a=.32*smooth(16,27,j); }
		else if(j<30){ c=shade(inner,(n-.5)*.1); a=1; }
		else if(j<44){ c=shade(coping,t+(n-.5)*.1+(j<33?-.06:0)+(j>40?.06:0)); if(i%40<2) c=shade(c,-.22); a=1; }
		else if(j<48){ c=shade(outer,(n-.5)*.1); a=1; }
		else { a=.4*(1-smooth(48,78,j)); }
		put(o,c); o[3]=a*255; if(j>=27&&j<48) jitter(o,i,j,383,10); }); },
hedge(){ const cv=canvas(EW,EH), x=cv.getContext('2d');
	for(const [y0,y1] of [[0,30],[66,96]]){ const g=x.createLinearGradient(0,y0,0,y1); const up=y0===0; g.addColorStop(up?0:1,'rgba('+AO+',0)'); g.addColorStop(up?1:0,'rgba('+AO+',.5)'); x.fillStyle=g; x.fillRect(0,y0,EW,y1-y0); }
	scatter(x,EW,EH,220,351,20,(c,R,k,px,py)=>{ c.translate(0,-py+30+R()*36); vol(c,0,0,9+R()*6,8+R()*6,'#435229',{hi:.1,lo:-.45}); },false);
	scatter(x,EW,EH,200,353,18,(c,R,k,px,py)=>{ c.translate(0,-py+34+R()*28); vol(c,0,0,7+R()*6,7+R()*5,R()<.5?'#4c5c32':'#58693a',{hi:.24,lo:-.38}); },false);
	scatter(x,EW,EH,900,352,4,(c,R,k,px,py)=>{ c.translate(0,-py+28+R()*40); ell(c,0,0,1+R()*1.4,.8+R()); c.fillStyle=R()<.5?'rgba(150,164,100,.45)':'rgba(20,28,12,.45)'; c.fill(); },false);
	return cv; },
scrapwall(){ const cv=canvas(EW,EH), x=cv.getContext('2d');
	for(const [y0,y1] of [[0,26],[70,96]]){ const g=x.createLinearGradient(0,y0,0,y1); const up=y0===0; g.addColorStop(up?0:1,'rgba('+AO+',0)'); g.addColorStop(up?1:0,'rgba('+AO+',.55)'); x.fillStyle=g; x.fillRect(0,y0,EW,y1-y0); }
	const R=rng(361); let px=0; const cols=['#6d6a64','#7a4a32','#5a6068','#4e4a42','#806a4a','#5c5f3a'];
	while(px<EW){ const w=26+R()*40, c=C(cols[(R()*cols.length)|0]); const y0=22+R()*6, h=72-R()*6-y0, sk=(R()-.5)*.08, rs=(R()*999)|0;
		wrapAt(x,EW,0,px+w/2,0,w,ctx=>{ ctx.rotate(sk); ctx.beginPath(); rr(ctx,-w/2,y0,w,h,2); const g=ctx.createLinearGradient(-w/2,0,w/2,0); g.addColorStop(0,css(shade(c,-.3))); g.addColorStop(.5,css(shade(c,.12))); g.addColorStop(1,css(shade(c,-.3))); ctx.fillStyle=g; ctx.fill();
			ctx.save(); ctx.clip(); ctx.strokeStyle='rgba(0,0,0,.25)'; ctx.lineWidth=.8; for(let k=-w/2+5;k<w/2;k+=6){ ctx.beginPath(); ctx.moveTo(k,y0+2); ctx.lineTo(k,y0+h-2); ctx.stroke(); }
			const R2=rng(rs); for(let q=0;q<2;q++){ ell(ctx,(R2()-.5)*w*.6,y0+h*(.3+R2()*.4),w*.18,h*.14,R2()*3); ctx.fillStyle='rgba(118,60,30,.35)'; ctx.fill(); } ctx.restore();
			for(const s of [-1,1]){ ell(ctx,s*(w/2-3),y0+4,1,1); ctx.fillStyle='#2a2826'; ctx.fill(); } });
		if(R()<.22) wrapAt(x,EW,0,px+w*.6,0,30,ctx=>{ ell(ctx,0,48,15,13); ctx.fillStyle='#1b1a1c'; ctx.fill(); ell(ctx,0,48,7,6); ctx.fillStyle='#3a3836'; ctx.fill(); });
		if(R()<.18){ const yy=42+R()*10; wrapAt(x,EW,0,px+w*.4,0,10,ctx=>{ ctx.fillStyle=css(C(TEAL),.85); ctx.fillRect(-4,yy,8,4); }); }
		px+=w*.82; }
	return cv; },
snow_ridge(){ const edge=wobble(371,50,9,6), crest=wobble(372,24,6,5), snow=C('#d2d8dd'), sh=C('#a6b2c0');
	return pixels(EW,EH,(u,v,i,j,o)=>{ const e=edge(u), c0=crest(u), n=fbm(u*16,v*4,373,3,16,0), l=fbm(u*10,v*3,375,3,10,0); let c,a=1;
		if(j<e){ const t=j<c0?(c0-j)/c0:(j-c0)/Math.max(8,e-c0); c=mixc(snow,sh,smooth(.15,1,t)*.65); c=shade(c,(n-.5)*.06+(l-.5)*.05); a=j<c0?smooth(0,c0,j):1-smooth(e-6,e,j)*.25; }
		else { c=[110,124,148]; a=.22*(1-smooth(e,e+36,j)); }
		put(o,c); o[3]=a*255; if(j<e&&hash2(i,j,374)>.995){ o[0]+=20;o[1]+=20;o[2]+=20; } }); },
/* volcano walls: basalt column tops fading in, the lit broken ends of the columns, a grooved face, AO and fallen
   column chunks at the foot */
basalt_lip(){ const edge=wobble(391,38,7,8), dark=C('#3f3c3a'), light=C('#6c6763'), joint=C('#211e1d');
	const cv=pixels(EW,EH,(u,v,i,j,o)=>{ const e=edge(u), w=worley(u*8,j/64,392,8,0), d=w.f2-w.f1, g=fbm(u*64,v*12,393,2,64,0); let c,a=1;
		if(j<e){ c=mixc(dark,light,.08+w.id*.84); c=shade(c,(g-.5)*.12); if(j>e-12) c=shade(c,.06+.1*smooth(e-12,e-2,j)); c=shade(c,smooth(.11,.06,d)*smooth(.025,.06,d)*.15); c=mixc(c,joint,smooth(.05,.014,d)*.92); a=smooth(0,16,j); }
		else if(j<e+7){ const gr=Math.sin(i*.8+fbm(u*20,0,394,2,20,0)*6); c=shade(dark,-.25+gr*.08-(j-e)/7*.2); }
		else { c=[18,13,16]; a=.6*(1-smooth(e+7,e+56,j)); }
		put(o,c); o[3]=a*255; if(j<e+7) jitter(o,i,j,395,12); });
	const x=cv.getContext('2d');
	scatter(x,EW,EH,46,396,10,(c,R,k,px,py)=>{ c.translate(0,edge(px/EW)-py+10+R()*16); const r=2.5+R()*4.5, pts=[]; for(let q=0;q<6;q++){ const a=q/6*TAU+R()*.3; pts.push([Math.cos(a)*r,Math.sin(a)*r]); } polyVol(c,pts,0,0,r,R()<.5?'#4c4845':'#5a5551',{hi:.25,lo:-.5}); },false);
	return cv; },
/* ghost town roofs: the last courses of shakes fading in from the roof, ragged butt ends, a lit fascia board and the
   building's AO on the street */
timber_edge(){ const cols=[C('#7d7262'),C('#6e5f4e'),C('#8a7f70'),C('#746856')], R=rng(401), cuts=[], ends=[]; let px=0; while(px<EW-20){ cuts.push(px); ends.push(39+R()*6); px+=11+R()*14; }
	const at=i=>{ let k=0; for(let q=0;q<cuts.length;q++) if(i>=cuts[q]) k=q; return k; };
	return pixels(EW,EH,(u,v,i,j,o)=>{ const k=at(i), di=i-cuts[k], w=(k+1<cuts.length?cuts[k+1]:EW)-cuts[k], t=hash2(k,0,402), g=fbm(u*64+t*5,v*6,403,3,64,0), end=ends[k];
		let c=[18,13,16], a=0;
		if(j<14) a=0;
		else if(j<end){ c=mixc(cols[(t*4)|0],cols[((t*13)|0)%4],.4); c=shade(c,(g-.5)*.26+(t-.5)*.06); if(di<1.5||di>w-1) c=shade(c,-.45); if(j>end-3) c=shade(c,-.25); if(Math.abs(j-26)<1.5) c=shade(c,-.3); a=smooth(14,24,j); }
		else if(j<47){ a=.75; }
		else if(j<52){ c=shade(C('#8a7d6c'),(fbm(u*40,0,404,2,40,0)-.5)*.14+(j<49?.08:-.1)); a=1; }
		else { a=.45*(1-smooth(52,84,j)); }
		put(o,c); o[3]=a*255; if(a>.9) jitter(o,i,j,405,10); }); },
/* suburb roofs: a starter course of three-tab shingles, the metal drip edge, a half-round gutter with leaves in it
   and the house's AO on the lawn */
/* Region 1: the unbreakable hedgerow as one continuous run (symmetric across v like hedge, but tall and dark on a
   dry-stone base with a hard lit top edge and deep AO), and the thicket wall's lip (crowns at the top) */
hedgerow(){ const cv=canvas(EW,EH), x=cv.getContext('2d');
	for(const [y0,y1] of [[0,16],[80,96]]){ const g=x.createLinearGradient(0,y0,0,y1), up=y0===0; g.addColorStop(up?0:1,'rgba('+AO+',0)'); g.addColorStop(up?1:0,'rgba('+AO+',.7)'); x.fillStyle=g; x.fillRect(0,y0,EW,y1-y0); }
	x.fillStyle='#4e4840'; x.fillRect(0,16,EW,64);
	scatter(x,EW,EH,170,421,12,(c,R,k,px,py)=>{ c.translate(0,-py+19+R()*58); facetRock(c,0,0,4.5+R()*3.8,['#7d766c','#8a8276','#6e675e','#968c7e'][(R()*4)|0],(R()*99999)|0,null,{lichen:R()<.2?'rgba(110,120,80,.35)':false}); },false);
	x.fillStyle='rgba('+AO+',.55)'; x.fillRect(0,22,EW,52); x.fillStyle='#253119'; x.fillRect(0,24,EW,48);
	x.save(); x.beginPath(); x.rect(0,24,EW,48); x.clip(); scatter(x,EW,EH,260,422,14,(c,R,k,px,py)=>{ c.translate(0,-py+26+R()*44); const r=6+R()*5.5; vol(c,0,0,r,r*.9,['#26331d','#2d3b22','#334328','#3a4a2c'][(R()*4)|0],{hi:.16,lo:-.5}); },false); x.restore();
	x.fillStyle='rgba(126,146,84,.55)'; x.fillRect(0,25,EW,2); x.fillRect(0,69,EW,2); x.fillStyle='rgba(12,16,8,.85)'; x.fillRect(0,23.5,EW,1.4); x.fillRect(0,71.2,EW,1.4);
	return cv; },
treeline(){ const cv=canvas(EW,EH), x=cv.getContext('2d');
	const ao=x.createLinearGradient(0,30,0,92); ao.addColorStop(0,'rgba('+AO+',.65)'); ao.addColorStop(1,'rgba('+AO+',0)'); x.fillStyle=ao; x.fillRect(0,30,EW,62);
	scatter(x,EW,EH,500,431,6,(c,R,k,px,py)=>{ c.translate(0,-py+46+R()*44); const a=R()*TAU, l=3+R()*3; c.beginPath(); c.moveTo(0,0); c.lineTo(Math.cos(a)*l,Math.sin(a)*l); c.lineWidth=.8; c.strokeStyle=R()<.5?'rgba(140,104,66,.45)':'rgba(70,52,34,.45)'; c.stroke(); },false);
	const g=x.createLinearGradient(0,0,0,16); g.addColorStop(0,'rgba(38,52,32,0)'); g.addColorStop(1,'rgba(38,52,32,1)'); x.fillStyle=g; x.fillRect(0,0,EW,16); x.fillStyle='#26341f'; x.fillRect(0,16,EW,14);
	scatter(x,EW,EH,30,432,56,(c,R,k,px,py)=>{ c.translate(0,-py+20+R()*12); thicketCrown(c,R,0,0,22+R()*12); },false);
	return cv; },
shingle_edge(){ const base=C('#5d6065'), TW=48, RH=12;
	const cv=pixels(EW,EH,(u,v,i,j,o)=>{ const row=((j-14)/RH)|0, off=(row%2)*TW/2, tab=(((i+off)/TW)|0)%(EW/TW), t=hash2(tab,row,411), k=(j-14)%RH; let c=[18,13,16], a=0;
		if(j<14) a=0;
		else if(j<38){ c=shade(base,(t-.5)*.16); if(k>RH-3) c=shade(c,-.3); if((i+off)%TW<1.6&&k>2) c=shade(c,-.4); a=smooth(14,22,j); }
		else if(j<41){ c=shade(C('#8c8e8e'),j===38?.1:-.05); a=1; }
		else if(j<48){ const y=(j-41)/7; c=shade(C('#9a9890'),.12-Math.pow(Math.abs(y-.35)*2,2)*.3); if(y>.15&&y<.55) c=shade(c,-.3); a=1; }
		else { a=.42*(1-smooth(48,78,j)); }
		put(o,c); o[3]=a*255; if(j>=22&&j<38) jitter(o,i,j,412,22); });
	const x=cv.getContext('2d');
	scatter(x,EW,EH,30,413,6,(c,R,k,px,py)=>{ c.translate(0,-py+42.5+R()*2); ell(c,0,0,2+R()*2,1.2+R(),R()*3); c.fillStyle=R()<.5?'rgba(110,86,48,.85)':'rgba(84,96,52,.85)'; c.fill(); },false);
	return cv; }
};
function renderEdge(name){ return EDGE[name](); }

/* ---------- sprite bake: shadow, 1.0 px rim, body (goon_gen.js bake, thinner rim) ---------- */
const RIM=1.0;
function body(W,H,res,fn){ const B=canvas(W,H), b=B.getContext('2d'); b.setTransform(res,0,0,res,W/2,H/2); b.lineJoin='round'; fn(b); b.setTransform(1,0,0,1,0,0); return B; }
function finish(B,o){ const W=B.width, H=B.height, b=B.getContext('2d');
	if(o.grime){ b.save(); b.globalCompositeOperation='source-atop'; b.globalAlpha=o.grime; b.fillStyle=b.createPattern(A.grime(),'repeat'); b.fillRect(0,0,W,H); b.restore(); }
	const cv=canvas(W,H), x=cv.getContext('2d'), S=canvas(W,H), s=S.getContext('2d');
	s.drawImage(B,0,0); s.globalCompositeOperation='source-in'; s.fillStyle='#0a0806'; s.fillRect(0,0,W,H);
	if(o.shadow){ x.save(); x.filter='blur('+(o.shadow*o.res).toFixed(2)+'px)'; x.globalAlpha=o.shadowA||.45; x.translate(W/2,H/2); x.scale(1.06,1.06); x.translate(-W/2,-H/2); x.drawImage(S,0,0); x.restore(); }
	if(o.rim!==false){ s.fillStyle=INK; s.fillRect(0,0,W,H); const k=RIM*o.res; for(let a=0;a<12;a++) x.drawImage(S,Math.cos(a/12*TAU)*k,Math.sin(a/12*TAU)*k); }
	x.drawImage(B,0,0); return cv; }
function sizeFor(box,res,pad){ return [Math.ceil((box[0]+pad*2)*res/2)*2,Math.ceil((box[1]+pad*2)*res/2)*2]; }

/* ---------- shared rigs ---------- */
function crown(c,x,y,r,hi,lo){ c.save(); c.globalCompositeOperation='source-atop'; const g=c.createRadialGradient(x,y-r*.08,r*.05,x,y,r);
	g.addColorStop(0,'rgba(255,248,230,'+hi+')'); g.addColorStop(.5,'rgba(0,0,0,0)'); g.addColorStop(1,'rgba('+AO+','+lo+')'); c.fillStyle=g; c.fillRect(x-r*1.2,y-r*1.2,r*2.4,r*2.4); c.restore(); }
function atop(c,fn){ c.save(); c.globalCompositeOperation='source-atop'; fn(); c.restore(); }
function speckle(c,R,n,rx,ry,cols,sz){ atop(c,()=>{ for(let i=0;i<n;i++){ const a=R()*TAU, d=Math.sqrt(R()); ell(c,Math.cos(a)*d*rx,Math.sin(a)*d*ry,(sz||1.4)*(.6+R()),(sz||1.4)*(.5+R()*.8),R()*3); c.fillStyle=cols[(R()*cols.length)|0]; c.fill(); } }); }
function canopy(c,R,r,cols,o){ o=o||{}; const n=o.n||16, sy=o.sy||1;
	for(let i=0;i<n;i++){ const a=i/n*TAU+(R()-.5)*.9, d=r*(.48+R()*.34), q=r*(.22+R()*.22); vol(c,Math.cos(a)*d,Math.sin(a)*d*sy,q,q*(.9+R()*.15),shade(C(cols[0]),-.12),{hi:.12,lo:-.5}); }
	for(let i=0;i<n*.8;i++){ const a=R()*TAU, d=r*R()*.55, q=r*(.26+R()*.14); vol(c,Math.cos(a)*d,Math.sin(a)*d*sy,q,q,cols[(R()*cols.length)|0],{hi:.24,lo:-.38}); }
	vol(c,0,0,r*.34,r*.32,cols[cols.length-1],{hi:.28,lo:-.25});
	speckle(c,R,r*7,r,r*sy,['rgba(18,26,10,.35)','rgba(190,198,140,.22)','rgba(40,50,24,.3)'],1.6);
	crown(c,0,0,r*1.05,.1,.32); }
/* a tree's ground layer under its canopy (docs/WORLD_ART.md, "Layered props"): root flare, the trunk's cut top,
   cypress knees */
function trunk(c,R,r,col,o){ o=o||{}; const bark=shade(C(col),-.05), n=o.roots||5;
	for(let i=0;i<n;i++){ const a=i/n*TAU+R()*.6, l=(o.reach||60)*(.7+R()*.3), w=r*.42*(.7+R()*.3), b=a+(R()-.5)*.5, mx=Math.cos(a)*l*.55, my=Math.sin(a)*l*.55;
		limb(c,[Math.cos(a)*r*.5,Math.sin(a)*r*.5],[mx,my],w,bark); limb(c,[mx,my],[mx+Math.cos(b)*l*.45,my+Math.sin(b)*l*.45],w*.55,bark); }
	for(let i=0;i<(o.knees||0);i++){ const a=R()*TAU, d=r*1.6+R()*r*1.2; vol(c,Math.cos(a)*d,Math.sin(a)*d,6+R()*4,6+R()*4,bark,{hi:.3,lo:-.4}); }
	vol(c,0,0,r,r*.96,col,{hi:.2,lo:-.45}); c.strokeStyle='rgba(40,28,18,.45)'; c.lineWidth=1; for(let k=1;k<4;k++){ ell(c,(R()-.5)*2,(R()-.5)*2,r*k/4.4,r*k/4.6); c.stroke(); }
	atop(c,()=>{ c.lineWidth=1.4; for(let i=0;i<10;i++){ const a=R()*TAU; c.beginPath(); c.moveTo(Math.cos(a)*r*.75,Math.sin(a)*r*.75); c.lineTo(Math.cos(a)*r,Math.sin(a)*r); c.strokeStyle='rgba(30,20,12,.4)'; c.stroke(); } }); }
/* fallen leaves or needles under the crown: flat, no rim */
function litter(c,R,r,cols,n,needle){ for(let i=0;i<n;i++){ const a=R()*TAU, d=r*Math.sqrt(R()), x=Math.cos(a)*d, y=Math.sin(a)*d; c.fillStyle=cols[(R()*cols.length)|0];
	if(needle){ c.save(); c.translate(x,y); c.rotate(R()*TAU); c.fillRect(-3,-.5,6,1); c.restore(); } else { ell(c,x,y,1.6+R()*1.6,1.1+R(),R()*3); c.fill(); } } }
/* falling bits for a layered prop's leaves strip, one per LEAF_CELL cell */
function leaf(c,R,col,k){ c.save(); c.rotate(k*.7); c.beginPath(); c.moveTo(-9,0); c.quadraticCurveTo(0,-6,9,0); c.quadraticCurveTo(0,6,-9,0); c.closePath(); const g=c.createLinearGradient(0,-6,0,6); g.addColorStop(0,css(shade(C(col),.15))); g.addColorStop(1,css(shade(C(col),-.25))); c.fillStyle=g; c.fill();
	c.beginPath(); c.moveTo(-8,0); c.lineTo(8,0); c.lineWidth=.7; c.strokeStyle='rgba(30,36,16,.5)'; c.stroke(); c.restore(); }
function needles(c,R){ c.lineWidth=1.3; for(let i=0;i<7;i++){ const a=-.6+i*.2+(R()-.5)*.1; c.beginPath(); c.moveTo(0,4); c.lineTo(Math.cos(a-Math.PI/2)*10,4+Math.sin(a-Math.PI/2)*10); c.strokeStyle=R()<.5?'#47593a':'#3e5134'; c.stroke(); } limb(c,[0,6],[0,0],2,'#5e4a3a'); }
function snowClump(c,R,k){ for(let i=0;i<4+k;i++) vol(c,(R()-.5)*10,(R()-.5)*8,3+R()*3,3+R()*2.4,'#dde1e5',{hi:.25,lo:-.25}); }
function moss(c,R){ c.lineWidth=1.2; for(let i=0;i<5;i++){ c.beginPath(); let x=(R()-.5)*6, y=-8; c.moveTo(x,y); for(let s=0;s<4;s++){ x+=(R()-.5)*5; y+=4; c.lineTo(x,y); } c.strokeStyle='rgba(168,170,146,.9)'; c.stroke(); } }
function twig(c,R,k){ limb(c,[-10,2],[10,-2],2.2,'#6b5e52'); limb(c,[0,0],[5+k,-7],1.4,'#6b5e52'); if(k%2) limb(c,[-4,1],[-8,7],1.2,'#75685b'); }
function ribbed(c,x,y,r,col,R,n){ vol(c,x,y,r,r,col,{hi:.25,lo:-.45}); n=n||14; c.lineWidth=Math.max(.8,r*.08);
	for(let i=0;i<n;i++){ const a=i/n*TAU; c.beginPath(); c.moveTo(x+Math.cos(a)*r*.18,y+Math.sin(a)*r*.18); c.lineTo(x+Math.cos(a)*r*.96,y+Math.sin(a)*r*.96); c.strokeStyle=i%2?'rgba(20,30,16,.35)':'rgba(220,226,190,.18)'; c.stroke();
		ell(c,x+Math.cos(a)*r*.98,y+Math.sin(a)*r*.98,.9,.9); c.fillStyle='rgba(230,222,190,.7)'; c.fill(); } }
function plank(c,x,y,w,h,col,R,o){ o=o||{}; col=C(col); c.save(); c.translate(x,y); if(o.rot) c.rotate(o.rot); c.beginPath(); rr(c,-w/2,-h/2,w,h,Math.min(w,h)*.18);
	const g=o.alongY?c.createLinearGradient(-w/2,0,w/2,0):c.createLinearGradient(0,-h/2,0,h/2); g.addColorStop(0,css(shade(col,-.25))); g.addColorStop(.45,css(shade(col,.1))); g.addColorStop(1,css(shade(col,-.3))); c.fillStyle=g; c.fill();
	c.save(); c.clip(); c.strokeStyle='rgba(30,20,12,.28)'; c.lineWidth=.8; const L=o.alongY?h:w, Wd=o.alongY?w:h;
	for(let i=0;i<4;i++){ const k=(R()-.5)*Wd*.8; c.beginPath(); if(o.alongY){ c.moveTo(k,-h/2); c.lineTo(k+(R()-.5)*2,h/2); } else { c.moveTo(-w/2,k); c.lineTo(w/2,k+(R()-.5)*2); } c.stroke(); }
	c.restore(); if(o.nails){ c.fillStyle='rgba(40,36,34,.85)'; for(const s of [-1,1]){ const d=(L/2-4)*s; ell(c,o.alongY?0:d,o.alongY?d:0,1,1); c.fill(); } } c.restore(); }
function sheet(c,x,y,w,h,col,R,o){ o=o||{}; col=C(col); c.save(); c.translate(x,y); if(o.rot) c.rotate(o.rot); c.beginPath(); rr(c,-w/2,-h/2,w,h,1.5);
	const g=c.createLinearGradient(-w/2,0,w/2,0); g.addColorStop(0,css(shade(col,-.22))); g.addColorStop(.5,css(shade(col,.1))); g.addColorStop(1,css(shade(col,-.25))); c.fillStyle=g; c.fill();
	c.save(); c.clip(); c.lineWidth=1; const step=o.rib||5; for(let k=-w/2+step/2;k<w/2;k+=step){ c.beginPath(); c.moveTo(k,-h/2); c.lineTo(k,h/2); c.strokeStyle='rgba(0,0,0,.2)'; c.stroke(); c.beginPath(); c.moveTo(k+1.2,-h/2); c.lineTo(k+1.2,h/2); c.strokeStyle='rgba(255,255,255,.08)'; c.stroke(); }
	if(o.rust!==false&&R()<(o.rust==null?.45:o.rust)){ c.globalAlpha=.7; rust(c,(R()-.5)*w*.5,(R()-.5)*h*.5,Math.min(w,h)*.45,(R()*999)|0); c.globalAlpha=1; } c.restore(); c.restore(); }
function ring(c,x,y,ro,ri,R,col){ col=C(col||'#1d1c1e'); ell(c,x,y,ro,ro); const g=c.createRadialGradient(x,y,ri,x,y,ro); g.addColorStop(0,css(shade(col,-.3))); g.addColorStop(.5,css(shade(col,.22))); g.addColorStop(1,css(shade(col,-.2))); c.fillStyle=g; c.fill();
	c.lineWidth=Math.max(.8,ro*.05); c.strokeStyle='rgba(120,118,115,.35)'; const n=Math.round(ro*.9); for(let i=0;i<n;i++){ const a=i/n*TAU; c.beginPath(); c.moveTo(x+Math.cos(a)*(ri+(ro-ri)*.55),y+Math.sin(a)*(ri+(ro-ri)*.55)); c.lineTo(x+Math.cos(a+.06)*ro*.98,y+Math.sin(a+.06)*ro*.98); c.stroke(); }
	ell(c,x,y,ri,ri); c.fillStyle='#0d0c0d'; c.fill(); }
function rag(c,x,y,len,ang,R,col){ col=C(col||RAG); c.save(); c.translate(x,y); c.rotate(ang); const w=len*.22, wv=(R()-.5)*len*.3;
	c.beginPath(); c.moveTo(0,-w*.5); c.quadraticCurveTo(len*.5,-w*.6+wv,len,-w*.2+wv*1.4); c.lineTo(len*.92,w*.4+wv*1.3); c.quadraticCurveTo(len*.5,w*.6+wv,0,w*.5); c.closePath();
	const g=c.createLinearGradient(0,-w,0,w); g.addColorStop(0,css(shade(col,.1))); g.addColorStop(1,css(shade(col,-.3))); c.fillStyle=g; c.fill(); c.restore(); }
function daub(c,x,y,w,h,rot){ c.save(); c.translate(x,y); c.rotate(rot||0); c.fillStyle=css(C(TEAL),.82); c.beginPath(); rr(c,-w/2,-h/2,w,h,h*.4); c.fill(); c.restore(); }
function bone(c,a,b,w){ limb(c,a,b,w,'#cfc4aa'); for(const p of [a,b]) for(const s of [-1,1]){ const dx=b[0]-a[0], dy=b[1]-a[1], l=Math.hypot(dx,dy)||1; vol(c,p[0]-dy/l*w*.45*s,p[1]+dx/l*w*.45*s,w*.42,w*.42,'#d8cdb4',{hi:.25,lo:-.35}); } }
function skull(c,x,y,s,rot,o){ o=o||{}; c.save(); c.translate(x,y); c.rotate(rot||0); c.scale(s,s);
	if(o.horns) for(const k of [-1,1]){ c.beginPath(); c.moveTo(k*10,-6); c.quadraticCurveTo(k*34,-14,k*40,-34); c.quadraticCurveTo(k*28,-12,k*8,2); c.closePath(); c.fillStyle='#c9bc9c'; c.fill(); c.strokeStyle='rgba(60,50,36,.4)'; c.lineWidth=.8; c.stroke(); }
	c.beginPath(); c.moveTo(-12,-10); c.quadraticCurveTo(-14,8,-7,22); c.lineTo(-4,30); c.lineTo(4,30); c.lineTo(7,22); c.quadraticCurveTo(14,8,12,-10); c.quadraticCurveTo(0,-18,-12,-10); c.closePath();
	const g=c.createRadialGradient(0,0,2,0,4,24); g.addColorStop(0,'#ece4d0'); g.addColorStop(1,'#b3a68a'); c.fillStyle=g; c.fill();
	for(const k of [-1,1]){ ell(c,k*6,2,3.4,4.2); c.fillStyle='#2a2018'; c.fill(); } ell(c,-1.5,24,1.2,2); ell(c,1.5,24,1.2,2); c.fillStyle='#3a2e22'; c.fill(); c.restore(); }
function glowAt(c,x,y,r,col,a){ const g=c.createRadialGradient(x,y,0,x,y,r); g.addColorStop(0,css(C(col),a)); g.addColorStop(1,css(C(col),0)); c.fillStyle=g; ell(c,x,y,r,r); c.fill(); }
function stone(c,x,y,r,R,col){ facetRock(c,x,y,r,col||ROCK,(R()*99999)|0,null,{lichen:false}); }
/* a hipped roof seen from overhead: four facets darkening from the ridge to the eaves, lit hips and ridge (Road Atlas) */
function hipRoof(c,w,h,col,R,cy){ cy=cy||0; col=C(col); const hw=w/2, hh=h/2, rx=Math.max(0,(w-h)/2), ry=Math.max(0,(h-w)/2);
	const facets=[[[-hw,-hh],[hw,-hh],[rx,-ry],[-rx,-ry]],[[hw,-hh],[hw,hh],[rx,ry],[rx,-ry]],[[hw,hh],[-hw,hh],[-rx,ry],[rx,ry]],[[-hw,hh],[-hw,-hh],[-rx,-ry],[-rx,ry]]];
	c.save(); c.translate(0,cy); facets.forEach((f,i)=>{ polyPath(c,f); const mx=(f[0][0]+f[1][0])/2, my=(f[0][1]+f[1][1])/2, g=c.createLinearGradient(mx,my,(f[2][0]+f[3][0])/2,(f[2][1]+f[3][1])/2);
		const cc=shade(col,(i%2?-.04:.02)+(R()-.5)*.04); g.addColorStop(0,css(shade(cc,-.28))); g.addColorStop(1,css(shade(cc,.12))); c.fillStyle=g; c.fill(); });
	c.save(); polyPath(c,[[-hw,-hh],[hw,-hh],[hw,hh],[-hw,hh]]); c.clip(); c.strokeStyle='rgba(0,0,0,.14)'; c.lineWidth=1; for(let k=-hw;k<hw;k+=7){ c.beginPath(); c.moveTo(k,-hh); c.lineTo(k,hh); c.stroke(); } c.restore();
	c.strokeStyle='rgba(235,228,210,.4)'; c.lineWidth=2.2; c.beginPath(); for(const [a,b] of [[[-hw,-hh],[-rx,-ry]],[[hw,-hh],[rx,-ry]],[[hw,hh],[rx,ry]],[[-hw,hh],[-rx,ry]],[[-rx,-ry],[rx,ry]]]){ c.moveTo(a[0],a[1]); c.lineTo(b[0],b[1]); } c.stroke();
	c.strokeStyle='rgba('+AO+',.6)'; c.lineWidth=1.4; c.strokeRect(-hw,-hh,w,h); c.restore(); }
/* the pine's tiers of needle spikes (pine_snow's crown under its snow) */
function pineTiers(c,R,r,cols){ for(let k=0;k<4;k++){ const rk=r*(1-k*.22), n=11+((rk/r)*7|0), col=shade(C(cols[k%3]),k*.05);
	for(let i=0;i<n;i++){ const a=i/n*TAU+R()*.25+k*.45, sp=.32+R()*.08; c.beginPath(); c.moveTo(Math.cos(a-sp)*rk*.3,Math.sin(a-sp)*rk*.3); c.lineTo(Math.cos(a)*rk*(.92+R()*.12),Math.sin(a)*rk*(.92+R()*.12)); c.lineTo(Math.cos(a+sp)*rk*.3,Math.sin(a+sp)*rk*.3); c.closePath();
		const g=c.createLinearGradient(0,0,Math.cos(a)*rk,Math.sin(a)*rk); g.addColorStop(0,css(shade(col,.12))); g.addColorStop(1,css(shade(col,-.32))); c.fillStyle=g; c.fill(); } } }
/* a palm frond along +x from the origin: a curving midrib with paired leaflets swept toward the tip */
function frond(c,R,curl,len,cols,droop){ const N=22; let px=0, py=0, a=0; const pts=[];
	for(let k=0;k<=N;k++){ const t=k/N; a=curl*t; px+=Math.cos(a)*len/N; py+=Math.sin(a)*len/N; pts.push([px,py,a,t]); }
	for(const s of [-1,1]) for(let k=1;k<N;k++){ const [x,y,ang,t]=pts[k], l=(30*Math.pow(Math.sin(Math.PI*Math.min(1,t*1.15)),.7)+5)*(1-droop*t*.5), la=ang+s*(1.05-t*.25);
		c.beginPath(); c.moveTo(x,y); c.quadraticCurveTo(x+Math.cos(la-s*.2)*l*.6,y+Math.sin(la-s*.2)*l*.6,x+Math.cos(la)*l,y+Math.sin(la)*l); c.lineWidth=3.4*(1-t*.5); c.lineCap='round';
		c.strokeStyle=css(shade(C(cols[(k+(s>0?1:0))%cols.length]),-.15+(R()-.5)*.1)); c.stroke(); c.lineWidth=1.2*(1-t*.5); c.strokeStyle=css(shade(C(cols[k%cols.length]),.18)); c.stroke(); }
	c.beginPath(); c.moveTo(0,0); for(const p of pts) c.lineTo(p[0],p[1]); c.lineWidth=2.6; c.strokeStyle=css(shade(C(cols[0]),.25)); c.stroke(); }
function frondBit(c,R,col){ c.beginPath(); c.moveTo(-11,0); c.lineTo(11,0); c.lineWidth=1.4; c.strokeStyle=css(shade(C(col),.2)); c.stroke();
	for(let k=0;k<4;k++) for(const s of [-1,1]){ const x=-8+k*5.5; c.beginPath(); c.moveTo(x,0); c.lineTo(x+5,s*9); c.lineWidth=2.4; c.lineCap='round'; c.strokeStyle=css(shade(C(col),(R()-.5)*.15)); c.stroke(); } }
/* a cart wheel lying flat: rim, spokes and hub */
function wheel(c,x,y,r,R){ ell(c,x,y,r,r); c.lineWidth=Math.max(2,r*.16); c.strokeStyle='#4a3a2a'; c.stroke(); ell(c,x,y,r,r); c.lineWidth=1.2; c.strokeStyle='#6b6a66'; c.stroke();
	for(let i=0;i<10;i++){ const a=i/10*TAU; limb(c,[x+Math.cos(a)*r*.2,y+Math.sin(a)*r*.2],[x+Math.cos(a)*r*.9,y+Math.sin(a)*r*.9],Math.max(1.5,r*.1),'#7d6247'); } vol(c,x,y,r*.22,r*.22,'#5c4632',{hi:.3}); }
/* a tied bin bag: a lumpy dark volume, plastic sheen, creases and a knotted neck */
function bag(c,R,x,y,r,col){ c.save(); c.translate(x,y); c.rotate(R()*TAU); const pts=[]; for(let i=0;i<9;i++){ const a=i/9*TAU, k=.8+R()*.3; pts.push([Math.cos(a)*r*k,Math.sin(a)*r*k*.9]); }
	polyVol(c,pts,0,0,r,col,{hi:.3,lo:-.5}); atop(c,()=>{ c.lineWidth=1.2; for(let i=0;i<6;i++){ const a=R()*TAU; c.beginPath(); c.moveTo(Math.cos(a)*r*.2,Math.sin(a)*r*.2); c.quadraticCurveTo(Math.cos(a+.4)*r*.6,Math.sin(a+.4)*r*.6,Math.cos(a)*r,Math.sin(a)*r); c.strokeStyle=R()<.5?'rgba(190,196,204,.28)':'rgba(0,0,0,.35)'; c.stroke(); }
		ell(c,-r*.2,-r*.25,r*.35,r*.18,-.5); c.fillStyle='rgba(200,206,214,.18)'; c.fill(); });
	vol(c,r*.1,0,r*.18,r*.16,shade(C(col),.15),{hi:.4}); for(const s of [-1,1]){ c.beginPath(); c.moveTo(r*.1,0); c.quadraticCurveTo(r*.3,s*r*.25,r*.45,s*r*.12); c.lineWidth=2; c.strokeStyle=css(shade(C(col),.2)); c.stroke(); } c.restore(); }
/* loose rubbish: 0 paper, 1 can, 2 peel, 3 bottle, 4 food carton */
function trash(c,R,x,y,k){ c.save(); c.translate(x,y); c.rotate(R()*TAU);
	if(k===0){ c.fillStyle='#d8d2c0'; c.beginPath(); c.moveTo(-8,-6); c.lineTo(7,-8); c.lineTo(9,5); c.lineTo(-6,8); c.closePath(); c.fill(); c.strokeStyle='rgba(80,76,70,.4)'; c.lineWidth=.6; c.stroke(); }
	else if(k===1){ c.beginPath(); rr(c,-8,-4,16,8,3); const g=c.createLinearGradient(0,-4,0,4); g.addColorStop(0,'#5a6066'); g.addColorStop(.5,'#b8bcc0'); g.addColorStop(1,'#4a5056'); c.fillStyle=g; c.fill(); c.fillStyle='rgba(150,60,40,.7)'; c.fillRect(-3,-4,6,8); }
	else if(k===2){ for(const s of [-1,1,0]){ c.beginPath(); c.moveTo(0,0); c.quadraticCurveTo(s*6+3,-5,s*9+6,2); c.lineWidth=3; c.lineCap='round'; c.strokeStyle='#b89a40'; c.stroke(); } }
	else if(k===3){ c.beginPath(); rr(c,-10,-3.5,16,7,3); c.rect(6,-1.5,5,3); c.fillStyle='rgba(90,110,70,.85)'; c.fill(); c.fillStyle='rgba(220,230,210,.4)'; c.fillRect(-8,-2.5,10,1.4); }
	else { c.fillStyle='#a8784a'; c.fillRect(-7,-6,14,12); c.fillStyle='rgba(200,180,140,.7)'; c.fillRect(-7,-6,14,3); }
	c.restore(); }
/* a spray-paint daub in a given colour (the Sprawl's marks; Scrap teal stays daub()) */
function daub2(c,x,y,w,h,col,rot){ c.save(); c.translate(x,y); c.rotate(rot||0); c.fillStyle=css(C(col),.8); c.beginPath(); rr(c,-w/2,-h/2,w,h,h*.4); c.fill(); c.restore(); }
/* ---- Region 1 (The Wilds) helpers ---- */
/* a burlap loot sack with coins peeking out (the den's stash overlay) */
function sack(c,R,x,y,s){ s=s||1; c.save(); c.translate(x,y); c.rotate(R()*TAU); c.scale(s,s); const pts=[]; for(let i=0;i<10;i++){ const a=i/10*TAU, k=.86+R()*.2; pts.push([Math.cos(a)*20*k,Math.sin(a)*17*k]); }
	polyVol(c,pts,0,0,20,'#a08a5c',{hi:.3,lo:-.5}); atop(c,()=>{ c.lineWidth=.8; for(let i=0;i<14;i++){ const yy=-16+i*2.4; c.beginPath(); c.moveTo(-20,yy); c.lineTo(20,yy+(R()-.5)*2); c.strokeStyle='rgba(80,60,34,.25)'; c.stroke(); } });
	vol(c,12,-2,6,5,'#8a7448',{hi:.3}); c.lineWidth=1.6; c.strokeStyle='#5a4428'; ell(c,12,-2,6,5); c.stroke();
	for(let i=0;i<3;i++){ ell(c,-4+i*5,-8+(R()-.5)*4,3.2,2.6); c.fillStyle='#d8b84a'; c.fill(); c.strokeStyle='rgba(90,64,20,.7)'; c.lineWidth=.6; c.stroke(); } c.restore(); }
/* a white box hive (beehive variants 2 and 3): telescoping lid seen from above, a brick on top, the entrance slit */
function boxHive(c,R,v){ c.beginPath(); rr(c,-46,-40,92,82,3); c.fillStyle='#4a4238'; c.fill();
	if(v===3){ c.beginPath(); rr(c,-40,-36,84,78,2); c.fillStyle='#cfcab8'; c.fill(); c.strokeStyle='rgba(60,56,48,.5)'; c.lineWidth=1; c.stroke(); }
	c.save(); if(v===3) c.translate(-4,-4); c.beginPath(); rr(c,-42,-38,84,74,3); const g=c.createLinearGradient(0,-38,0,36); g.addColorStop(0,'#ece8dc'); g.addColorStop(.5,'#e2ddd0'); g.addColorStop(1,'#bdb8aa'); c.fillStyle=g; c.fill();
	c.beginPath(); rr(c,-36,-32,72,62,2); c.fillStyle=v===3?'#b4b6b2':'#d8d4c6'; c.fill(); atop(c,()=>{ c.strokeStyle='rgba(120,116,104,.3)'; c.lineWidth=1; for(let x=-34;x<36;x+=6){ c.beginPath(); c.moveTo(x,-32); c.lineTo(x,30); c.stroke(); } rust(c,20,10,14,600+v); });
	c.save(); c.translate(-6,-4); c.rotate(.25); c.beginPath(); rr(c,-16,-7,32,14,2); c.fillStyle='#8e4a34'; c.fill(); c.strokeStyle='rgba(40,20,12,.5)'; c.lineWidth=.8; c.stroke(); c.restore(); c.restore();
	c.fillStyle='#1c1612'; c.fillRect(-20,36,40,4);
	for(let i=0;i<9;i++){ const a=Math.PI/2+(R()-.5)*1.6, d=44+R()*16; ell(c,Math.cos(a)*d,Math.sin(a)*d,2.4,1.6,a); c.fillStyle='#2a2216'; c.fill(); ell(c,Math.cos(a)*d+1,Math.sin(a)*d,1.2,1.2); c.fillStyle='#e0b23c'; c.fill(); } }
/* a pumpkin: ribbed lobes, stem, a vine and a leaf */
function pumpkin(c,R,x,y,r,col){ c.save(); c.translate(x,y); vol(c,0,0,r,r*.92,col,{hi:.3,lo:-.42}); c.lineWidth=Math.max(1,r*.07);
	for(let i=0;i<10;i++){ const a=i/10*TAU; c.beginPath(); c.moveTo(Math.cos(a)*r*.18,Math.sin(a)*r*.17); c.quadraticCurveTo(Math.cos(a+.18)*r*.7,Math.sin(a+.18)*r*.64,Math.cos(a)*r*.96,Math.sin(a)*r*.88); c.strokeStyle='rgba(80,34,10,.35)'; c.stroke(); }
	crown(c,0,0,r,.14,.2); vol(c,0,0,r*.18,r*.18,'#5a5030',{hi:.3}); c.restore(); }
/* a red rock, faceted like the canyon's (rockpile, rock_roll) */
const REDS=['#9a5c42','#a0603f','#86503c','#8e5440','#a86a48'];
function redRock(c,R,x,y,r){ facetRock(c,x,y,r,REDS[(R()*REDS.length)|0],(R()*99999)|0,null,{lichen:false}); }
/* the hedgerow's pieces: a dry-stone base under a tall, dark, flat-topped hedge, a hard lit edge and deep AO.
   Units are world px in a 192 px cell; every piece shares the same cross-section, and the strip of foliage and
   stones within SEAM px of a joint comes from one fixed set (point-symmetric), so pieces join end to end and at
   right angles without a seam (docs/WORLD_ART.md "Hedgerow") */
const HR={cell:192,base:56,body:40,ao:28,seam:30};
const HR_SEAM=(()=>{ const R=rng(7731), stones=[], leaves=[];
	for(let i=0;i<9;i++){ const s={x:(R()-.5)*2*HR.seam,y:(R()-.5)*2*(HR.base-6),r:6+R()*5,k:(R()*99999)|0,c:R()}; stones.push(s,{x:-s.x,y:-s.y,r:s.r,k:s.k+1,c:s.c}); }
	for(let i=0;i<16;i++){ const l={x:(R()-.5)*2*HR.seam,y:(R()-.5)*2*(HR.body-8),r:8+R()*7,c:R(),q:(R()*99999)|0}; leaves.push(l,{x:-l.x,y:-l.y,r:l.r,c:l.c,q:l.q+1}); }
	return {stones,leaves}; })();
function hrPath(c,kind,hw){ c.beginPath(); const E=HR.cell/2+16;
	if(kind==='straight'){ c.rect(-E,-hw,2*E,2*hw); }
	else if(kind==='end'){ const cx=24; c.moveTo(-E,-hw); c.lineTo(cx,-hw); c.arc(cx,0,hw,-Math.PI/2,Math.PI/2); c.lineTo(-E,hw); c.closePath(); }
	else { c.moveTo(-E,-hw); c.lineTo(0,-hw); c.arc(0,0,hw,-Math.PI/2,0); c.lineTo(hw,E); c.lineTo(-hw,E); c.lineTo(-hw,hw); c.lineTo(-E,hw); c.closePath(); } }
function hrStone(c,s){ const col=['#7d766c','#8a8276','#6e675e','#968c7e'][(s.c*4)|0]; facetRock(c,s.x,s.y,s.r,col,s.k,null,{lichen:s.c>.7?'rgba(110,120,80,.35)':false}); }
function hrLeaf(c,l){ const cols=['#26331d','#2d3b22','#334328','#3a4a2c']; vol(c,l.x,l.y,l.r,l.r*.9,cols[(l.c*4)|0],{hi:.16,lo:-.5}); }
function hedgerowPiece(c,R,kind){ const H=HR.cell/2, seams=kind==='straight'?[[-H,0,0],[H,0,0]]:kind==='end'?[[-H,0,0]]:[[-H,0,0],[0,H,-Math.PI/2]];
	const nearSeam=(x,y,m)=>seams.some(([sx,sy,a])=>a?Math.abs(y-sy)<HR.seam+m:Math.abs(x-sx)<HR.seam+m);
	c.save(); c.lineJoin='round'; for(let k=10;k>=1;k--){ hrPath(c,kind,HR.base); c.lineWidth=k*HR.ao/5; c.strokeStyle='rgba('+AO+','+(.07)+')'; c.stroke(); } c.restore();
	hrPath(c,kind,HR.base); c.fillStyle='#4e4840'; c.fill();
	c.save(); hrPath(c,kind,HR.base); c.clip();
	for(const [sx,sy,a] of seams){ c.save(); c.translate(sx,sy); c.rotate(a); for(const s of HR_SEAM.stones) hrStone(c,s); c.restore(); }
	for(let i=0;i<60;i++){ const x=(R()-.5)*2*H, y=(R()-.5)*2*H, r=6+R()*5; if(nearSeam(x,y,r)) continue; hrStone(c,{x,y,r,k:(R()*99999)|0,c:R()}); }
	c.restore();
	hrPath(c,kind,HR.body+3); c.fillStyle='rgba('+AO+',.55)'; c.fill();
	hrPath(c,kind,HR.body); c.fillStyle='#253119'; c.fill();
	c.save(); hrPath(c,kind,HR.body); c.clip();
	for(const [sx,sy,a] of seams){ c.save(); c.translate(sx,sy); c.rotate(a); for(const l of HR_SEAM.leaves) hrLeaf(c,l); c.restore(); }
	for(let i=0;i<90;i++){ const x=(R()-.5)*2*H, y=(R()-.5)*2*H, r=8+R()*7; if(nearSeam(x,y,r)) continue; hrLeaf(c,{x,y,r,c:R()}); }
	c.restore();
	c.save(); c.lineJoin='round'; hrPath(c,kind,HR.body-2.5); c.lineWidth=3; c.strokeStyle='rgba(126,146,84,.55)'; c.stroke(); hrPath(c,kind,HR.body); c.lineWidth=1.6; c.strokeStyle='rgba(12,16,8,.85)'; c.stroke(); c.restore(); }
/* a pine crown cluster for thicket walls (pine_crown decor): dark tiers, needle speckle, lit tips for headlights */
/* fallen_trunk's leaning variant: the root plate on the ground at -x, the trunk propped on a stump at +x; height
   reads only through the wide soft gap under the raised end and the trunk widening toward it */
function leaningTrunk(c,R){ ell(c,60,0,150,46); c.fillStyle='rgba('+AO+',.18)'; ell(c,-90,0,90,34); c.fill(); ell(c,40,0,120,36); c.fillStyle='rgba('+AO+',.2)'; c.fill();
	for(let i=0;i<5;i++){ const a=i/5*TAU+R()*.5; limb(c,[130,0],[130+Math.cos(a)*(36+R()*10),Math.sin(a)*(36+R()*10)],9-i*.6,'#5c4632'); } ell(c,130,0,30,28); c.fillStyle='#3e2e20'; c.fill(); vol(c,130,0,26,24,'#a3875c',{hi:.15,lo:-.25});
	for(let i=0;i<6;i++){ const x=-130+i*48+R()*14, s=i%2?1:-1; limb(c,[x,s*20],[x+10,s*(40+R()*16+i*2)],5+R()*3,'#5a4836'); }
	c.beginPath(); c.moveTo(-180,-24); c.quadraticCurveTo(0,-30,168,-32); c.lineTo(168,32); c.quadraticCurveTo(0,30,-180,24); c.closePath();
	const g=c.createLinearGradient(0,-32,0,32); g.addColorStop(0,'#30241a'); g.addColorStop(.4,'#86684d'); g.addColorStop(.6,'#70573e'); g.addColorStop(1,'#271d15'); c.fillStyle=g; c.fill();
	atop(c,()=>{ for(let i=0;i<20;i++){ const y=(R()-.5)*44; c.beginPath(); c.moveTo(-180,y*.8); for(let x=-180;x<170;x+=12) c.lineTo(x,y*(.8+(x+180)/350*.25)+(R()-.5)*3); c.strokeStyle='rgba(26,18,10,.42)'; c.lineWidth=1+R()*1.4; c.stroke(); } const h=c.createLinearGradient(-180,0,170,0); h.addColorStop(0,'rgba(0,0,0,.12)'); h.addColorStop(1,'rgba(255,240,210,.12)'); c.fillStyle=h; c.fillRect(-180,-34,350,68); });
	c.save(); c.translate(-190,0); ell(c,0,0,28,80); c.fillStyle='#3a2c20'; c.fill(); vol(c,0,0,24,74,'#5a4836',{hi:.12,lo:-.45}); for(let i=0;i<22;i++){ const a=R()*TAU, d=R()*.8; limb(c,[Math.cos(a)*20*d,Math.sin(a)*66*d],[Math.cos(a)*28+(R()-.5)*20,Math.sin(a)*(74+R()*14)],2.2+R()*2.4,'#6a5440'); } c.restore();
	c.save(); c.translate(166,0); ell(c,0,0,6,30); c.fillStyle='#a88a5c'; c.fill(); c.strokeStyle='rgba(90,62,36,.6)'; c.lineWidth=.8; for(let k=1;k<4;k++){ ell(c,0,0,6*k/4,30*k/4); c.stroke(); } c.restore(); }
function thicketCrown(c,R,x,y,r){ c.save(); c.translate(x,y); ell(c,0,0,r*1.04,r*1.04); c.fillStyle='rgba('+AO+',.35)'; c.fill(); pineTiers(c,R,r,['#2b3a26','#33432c','#3a4a31']);
	atop(c,()=>{ c.lineWidth=.8; for(let i=0;i<r*4;i++){ const a=R()*TAU, d=R()*r, l=3+R()*4; c.beginPath(); c.moveTo(Math.cos(a)*d,Math.sin(a)*d); c.lineTo(Math.cos(a)*(d+l),Math.sin(a)*(d+l)); c.strokeStyle=R()<.55?'rgba(10,16,8,.4)':'rgba(150,170,120,.26)'; c.stroke(); } });
	vol(c,0,0,r*.1,r*.1,'#4e5c3e',{hi:.3}); crown(c,0,0,r,.12,.34); c.restore(); }

function snowCover(c,x0,y0,w,h,amt,seed,res){ const k=2, cw=Math.ceil(w/k), ch=Math.ceil(h/k);
	const m=pixels(cw,ch,(u,v,i,j,o)=>{ const X=x0+i*k, Y=y0+j*k, f=A.fbm(X*.012,Y*.012,seed,4)+(A.fbm(X*.05,Y*.05,seed+3,2)-.5)*.25, a=smooth(1-amt-.03,1-amt+.03,f);
		const t=A.fbm(X*.03,Y*.03,seed+7,3); o[0]=214+t*22; o[1]=220+t*20; o[2]=228+t*18; o[3]=a*240; });
	c.save(); c.imageSmoothingEnabled=true; c.drawImage(m,x0,y0,cw*k,ch*k); c.restore(); }
const WOOD='#7d6247', GREYWOOD='#837363', BONE='#d8cdb4', STEEL='#8d8f8c', HIDE='#9c8466';
const CARS_WRECK=['sedan','van','taxi','pickup','police'];

/* ---------- the catalog: class, box (world px the drawing may use), variants, draw(ctx, rng, variant) ---------- */
const PROPS={
rock:{cls:'TALL',box:[170,150],n:3,shadow:6,grime:.25,draw(c,R,v){ const N=9+v, base=[]; for(let i=0;i<N;i++) base.push(.82+R()*.3);
	facetRock(c,0,0,68,v===2?'#7e766d':ROCK,40+v*7,base,{sx:1.08,sy:.92}); if(v===1) facetRock(c,38,22,26,'#958c82',51,null,{});
	c.strokeStyle='rgba('+AO+',.4)'; c.lineWidth=1.2; c.beginPath(); c.moveTo(-20,-30); c.lineTo(-6,-8); c.lineTo(-12,14); c.stroke(); crown(c,0,0,74,.1,.2); }},
boulder:{cls:'TALL',box:[320,280],n:2,shadow:9,grime:.25,draw(c,R,v){ facetRock(c,-34,10,104,ROCK,60+v,null,{}); facetRock(c,56,-30,72,'#857c73',61+v*3,null,{}); facetRock(c,40,62,52,'#91887e',62+v*5,null,{});
	c.strokeStyle='rgba('+AO+',.45)'; c.lineWidth=1.6; for(let k=0;k<3;k++){ c.beginPath(); let x=(R()-.5)*120, y=(R()-.5)*120; c.moveTo(x,y); for(let s=0;s<5;s++){ x+=(R()-.5)*30; y+=(R()-.5)*30; c.lineTo(x,y); } c.stroke(); } crown(c,0,0,150,.08,.18); }},
rock_white:{cls:'TALL',box:[190,160],n:2,shadow:6,grime:.2,draw(c,R,v){ const N=10, base=[]; for(let i=0;i<N;i++) base.push(.8+R()*.28);
	facetRock(c,0,0,72,'#a7a196',90+v*11,base,{sx:1.1,sy:.88,lichen:'rgba(150,146,120,.3)'}); if(v===1) facetRock(c,-44,26,26,'#b0aa9e',97,null,{lichen:false});
	atop(c,()=>{ c.strokeStyle='rgba(90,84,74,.22)'; c.lineWidth=1.1; for(let k=-4;k<=4;k++){ c.beginPath(); c.moveTo(-90,k*15+v*5); c.quadraticCurveTo(0,k*15+6+v*5+(R()-.5)*8,90,k*15+10+v*5); c.stroke(); } }); crown(c,0,0,80,.06,.22); }},
rock_ice:{cls:'TALL',box:[190,170],n:2,shadow:6,grime:.05,draw(c,R,v){ const N=8, pts=[]; for(let i=0;i<N;i++){ const a=i/N*TAU+R()*.3, k=.78+R()*.28; pts.push([Math.cos(a)*74*k,Math.sin(a)*66*k]); }
	polyVol(c,pts,0,0,76,'#a2b9c6',{hi:.3,lo:-.35}); for(let i=0;i<N;i++){ const a=pts[i], b=pts[(i+1)%N]; c.beginPath(); c.moveTo(a[0]*.3,a[1]*.3); c.lineTo(a[0],a[1]); c.lineTo(b[0],b[1]); c.closePath(); c.fillStyle=R()<.5?'rgba(240,248,252,.18)':'rgba(40,70,90,.14)'; c.fill(); }
	atop(c,()=>{ c.strokeStyle='rgba(60,90,110,.35)'; c.lineWidth=1; for(let k=0;k<4;k++){ c.beginPath(); c.moveTo((R()-.5)*100,(R()-.5)*100); c.lineTo((R()-.5)*100,(R()-.5)*100); c.stroke(); }
		if(v===0){ for(let k=0;k<6;k++){ ell(c,(R()-.5)*50,(R()-.5)*40,14+R()*14,10+R()*10); c.fillStyle='rgba(228,234,238,.85)'; c.fill(); } } }); crown(c,0,0,80,.15,.18); }},
rock_red:{cls:'TALL',box:[170,150],n:3,shadow:6,grime:.2,draw(c,R,v){ const N=9+v, base=[]; for(let i=0;i<N;i++) base.push(.82+R()*.3);
	const cols=['#9a5c42','#a8743f','#86503c'];
	facetRock(c,0,0,68,cols[v],440+v*7,base,{sx:1.08,sy:.92,lichen:false}); if(v===1) facetRock(c,38,22,26,'#b4844e',451,null,{lichen:false});
	atop(c,()=>{ c.strokeStyle='rgba(70,30,18,.22)'; c.lineWidth=1.3; for(let k=-4;k<=4;k++){ c.beginPath(); c.moveTo(-90,k*15+v*4); c.quadraticCurveTo(0,k*15+5+v*4+(R()-.5)*8,90,k*15+9+v*4); c.stroke(); } });
	c.strokeStyle='rgba('+AO+',.4)'; c.lineWidth=1.2; c.beginPath(); c.moveTo(-20,-30); c.lineTo(-6,-8); c.lineTo(-12,14); c.stroke(); crown(c,0,0,74,.1,.2); }},
boulder_red:{cls:'TALL',box:[320,280],n:2,shadow:9,grime:.2,draw(c,R,v){ facetRock(c,-34,10,104,'#9a5c42',460+v,null,{lichen:false}); facetRock(c,56,-30,72,'#a8743f',461+v*3,null,{lichen:false}); facetRock(c,40,62,52,'#8e5440',462+v*5,null,{lichen:false});
	atop(c,()=>{ c.strokeStyle='rgba(70,30,18,.2)'; c.lineWidth=1.6; for(let k=-7;k<=7;k++){ c.beginPath(); c.moveTo(-160,k*18+v*6); c.quadraticCurveTo(0,k*18+8+v*6+(R()-.5)*10,160,k*18+14+v*6); c.stroke(); } });
	c.strokeStyle='rgba('+AO+',.45)'; c.lineWidth=1.6; for(let k=0;k<3;k++){ c.beginPath(); let x=(R()-.5)*120, y=(R()-.5)*120; c.moveTo(x,y); for(let s2=0;s2<5;s2++){ x+=(R()-.5)*30; y+=(R()-.5)*30; c.lineTo(x,y); } c.stroke(); } crown(c,0,0,150,.08,.18); }},
oak:{cls:'TALL',box:[300,300],n:3,shadow:10,grime:.1,core(c){ ell(c,0,0,58,58); c.fillStyle='#000'; c.fill(); },
	draw(c,R,v){ trunk(c,R,34,'#6b5440',{roots:6,reach:76}); },
	litter(c,R,v){ litter(c,R,118,['rgba(96,88,46,.5)','rgba(120,96,52,.45)','rgba(70,84,40,.5)'],260); },
	canopy(c,R,v){ canopy(c,R,120+v*8,[['#53642f','#5f7036','#6a7a3e'],['#4f5f2e','#5b6b33','#687a3c'],['#5a6630','#667238','#748048']][v]); },
	leaves(c,R,k){ leaf(c,R,['#5f7036','#6a7a3e','#8a7a3e','#748048'][k],k); }},
pine:{cls:'TALL',box:[230,230],n:3,shadow:9,grime:.08,core(c){ ell(c,0,0,36,36); c.fillStyle='#000'; c.fill(); },
	draw(c,R,v){ trunk(c,R,22,'#5e4a3a',{roots:5,reach:48}); },
	litter(c,R,v){ litter(c,R,90,['rgba(110,84,52,.5)','rgba(80,64,44,.45)'],200,true); },
	leaves(c,R,k){ if(k<2) needles(c,R); else snowClump(c,R,k); },
	canopy(c,R,v){ const r=96+v*6, cols=['#3e5134','#47593a','#506241']; for(let k=0;k<4;k++){ const rk=r*(1-k*.22), n=11+((rk/r)*7|0), col=shade(C(cols[k%3]),k*.05);
		for(let i=0;i<n;i++){ const a=i/n*TAU+R()*.25+k*.45, sp=.32+R()*.08; c.beginPath(); c.moveTo(Math.cos(a-sp)*rk*.3,Math.sin(a-sp)*rk*.3); c.lineTo(Math.cos(a)*rk*(.92+R()*.12),Math.sin(a)*rk*(.92+R()*.12)); c.lineTo(Math.cos(a+sp)*rk*.3,Math.sin(a+sp)*rk*.3); c.closePath();
			const g=c.createLinearGradient(0,0,Math.cos(a)*rk,Math.sin(a)*rk); g.addColorStop(0,css(shade(col,.12))); g.addColorStop(1,css(shade(col,-.32))); c.fillStyle=g; c.fill(); } }
		vol(c,0,0,r*.1,r*.1,'#5a6a46',{hi:.3});
		atop(c,()=>{ c.lineWidth=.8; for(let i=0;i<r*5;i++){ const a=R()*TAU, d=R()*r, l=3+R()*4; c.beginPath(); c.moveTo(Math.cos(a)*d,Math.sin(a)*d); c.lineTo(Math.cos(a)*(d+l),Math.sin(a)*(d+l)); c.strokeStyle=R()<.5?'rgba(14,22,10,.35)':'rgba(160,176,130,.2)'; c.stroke(); }
			if(v===2) for(let i=0;i<60;i++){ const a=R()*TAU, d=r*(.3+R()*.6); ell(c,Math.cos(a)*d,Math.sin(a)*d,4+R()*6,3+R()*4,a); c.fillStyle='rgba(226,232,236,.75)'; c.fill(); } });
		crown(c,0,0,r,.1,.3); }},
cypress:{cls:'TALL',box:[260,250],n:2,shadow:9,grime:.1,core(c){ ell(c,0,0,48,48); c.fillStyle='#000'; c.fill(); },
	draw(c,R,v){ trunk(c,R,36,'#6e6252',{roots:7,reach:62,knees:6}); },
	litter(c,R,v){ litter(c,R,100,['rgba(96,98,62,.45)','rgba(70,74,48,.45)'],180); },
	leaves(c,R,k){ if(k<3) leaf(c,R,['#6c7542','#7a8250','#606a3a'][k],k); else moss(c,R); },
	canopy(c,R,v){ canopy(c,R,104+v*6,['#606a3a','#6c7542','#7a8250'],{n:20,sy:.92});
		atop(c,()=>{ c.lineWidth=1.4; for(let i=0;i<46;i++){ const a=R()*TAU, d=R()*96, x=Math.cos(a)*d, y=Math.sin(a)*d; c.beginPath(); c.moveTo(x,y); c.bezierCurveTo(x+4,y+6,x-4,y+12,x+2,y+18+R()*8); c.strokeStyle='rgba(168,170,146,.55)'; c.stroke(); } }); }},
log:{cls:'LOW',box:[280,90],n:2,shadow:5,grime:.25,draw(c,R,v){ const L=240+v*20, W=56; c.beginPath(); rr(c,-L/2,-W/2,L,W,W*.42);
	const g=c.createLinearGradient(0,-W/2,0,W/2); g.addColorStop(0,'#33281c'); g.addColorStop(.42,'#7a5d40'); g.addColorStop(.58,'#6a5036'); g.addColorStop(1,'#2a2017'); c.fillStyle=g; c.fill();
	atop(c,()=>{ for(let i=0;i<16;i++){ const y=(R()-.5)*W*.9; c.beginPath(); c.moveTo(-L/2,y); for(let x=-L/2;x<L/2;x+=14) c.lineTo(x,y+(R()-.5)*3); c.strokeStyle='rgba(26,18,10,.4)'; c.lineWidth=1+R(); c.stroke(); }
		for(let i=0;i<5;i++){ ell(c,(R()-.5)*L*.8,(R()-.5)*W*.5,10+R()*18,6+R()*8); c.fillStyle='rgba(96,118,58,.45)'; c.fill(); } });
	for(const s of [-1,1]){ const ex=s*(L/2-6); ell(c,ex,0,7,W*.44); c.fillStyle='#a88a5c'; c.fill(); c.strokeStyle='rgba(90,62,36,.6)'; c.lineWidth=.8; for(let k=1;k<4;k++){ ell(c,ex,0,7*k/4,W*.44*k/4); c.stroke(); } }
	if(v===1){ limb(c,[-20,-W/2+4],[-6,-W/2-26],8,'#5c4630'); limb(c,[40,W/2-4],[62,W/2+20],7,'#5c4630'); } }},
stump:{cls:'LOW',box:[130,130],n:2,shadow:5,grime:.2,draw(c,R,v){ for(let i=0;i<5;i++){ const a=i/5*TAU+R()*.5; limb(c,[0,0],[Math.cos(a)*(48+R()*14),Math.sin(a)*(48+R()*14)],12-i*.6,'#5c4632'); }
	ell(c,0,0,38,36); c.fillStyle='#3e2e20'; c.fill(); vol(c,0,0,32,30,'#a3875c',{hi:.15,lo:-.25}); c.strokeStyle='rgba(98,70,42,.55)'; c.lineWidth=1; for(let k=1;k<6;k++){ ell(c,(R()-.5)*2,(R()-.5)*2,32*k/6,30*k/6); c.stroke(); }
	c.strokeStyle='rgba(40,28,18,.7)'; c.lineWidth=1.6; for(let k=0;k<2+v;k++){ const a=R()*TAU; c.beginPath(); c.moveTo(Math.cos(a)*4,Math.sin(a)*4); c.lineTo(Math.cos(a)*30,Math.sin(a)*30); c.stroke(); } }},
saguaro:{cls:'TALL',box:[180,180],n:2,shadow:6,grime:.08,core(c){ ell(c,0,0,34,34); c.fillStyle='#000'; c.fill(); },
	/* Road Atlas Region 1: toppled along +y from its snapped base, and the chunks a topple throws */
	states:{fallen:{box:[240,480],shadow:5,draw(c,R){ const col='#5f7150'; ribbed(c,0,0,24,col,R,12); ell(c,0,0,12,12); c.fillStyle='#b8c08a'; c.fill();
		for(let i=0;i<40;i++){ const a=R()*TAU, d=30+R()*40; c.beginPath(); c.moveTo(Math.cos(a)*d,Math.sin(a)*d); c.lineTo(Math.cos(a)*(d+5),Math.sin(a)*(d+5)); c.lineWidth=1; c.strokeStyle='rgba(230,222,190,.75)'; c.stroke(); }
		c.save(); c.translate(0,44); for(const [s,y] of [[-1,60],[1,106]]){ limb(c,[0,y],[s*62,y+6],22,col); limb(c,[s*62,y+6],[s*66,y+64],20,col); ribbed(c,s*66,y+66,11,col,R,8); }
		c.beginPath(); rr(c,-28,0,56,186,26); const g=c.createLinearGradient(-28,0,28,0); g.addColorStop(0,css(shade(C(col),-.35))); g.addColorStop(.5,css(shade(C(col),.18))); g.addColorStop(1,css(shade(C(col),-.35))); c.fillStyle=g; c.fill();
		c.save(); c.clip(); c.lineWidth=1.4; for(let k=-3;k<=3;k++){ c.beginPath(); c.moveTo(k*8,0); c.lineTo(k*8,186); c.strokeStyle=k%2?'rgba(20,30,16,.35)':'rgba(220,226,190,.18)'; c.stroke(); } for(let i=0;i<50;i++){ ell(c,(R()-.5)*50,R()*186,.9,.9); c.fillStyle='rgba(230,222,190,.7)'; c.fill(); } c.restore();
		ell(c,0,4,18,8); c.fillStyle='#b8c08a'; c.fill(); for(let i=0;i<5;i++){ const a=i/5*TAU; vol(c,Math.cos(a)*8,178+Math.sin(a)*8,4,4,'#cdb27a',{hi:.3}); } c.restore(); }},
		chunks:{cell:48,strip(c,R,k){ c.rotate(k*.8); c.beginPath(); rr(c,-14,-9,28,18,7); c.fillStyle='#5f7150'; c.fill(); c.lineWidth=1; for(let j=-1;j<=1;j++){ c.beginPath(); c.moveTo(-14,j*5); c.lineTo(14,j*5); c.strokeStyle='rgba(20,30,16,.4)'; c.stroke(); } for(let i=0;i<6;i++){ ell(c,(R()-.5)*24,(R()-.5)*14,.9,.9); c.fillStyle='rgba(230,222,190,.8)'; c.fill(); } ell(c,13,0,3,8); c.fillStyle='#b8c08a'; c.fill(); }}},
	draw(c,R,v){ const col='#5f7150', arms=v?3:2; for(let i=0;i<arms;i++){ const a=i/arms*TAU+R()*.8+.3, d=46+R()*20; limb(c,[Math.cos(a)*20,Math.sin(a)*20],[Math.cos(a)*d,Math.sin(a)*d],22,col); ribbed(c,Math.cos(a)*d,Math.sin(a)*d,15,col,R,10); }
		ribbed(c,0,0,32,col,R,16); if(v){ for(let i=0;i<5;i++){ const a=i/5*TAU; vol(c,Math.cos(a)*8,Math.sin(a)*8,4,4,'#cdb27a',{hi:.3}); } } }},
deadtree:{cls:'TALL',box:[300,300],n:2,shadow:7,grime:.15,core(c){ ell(c,0,0,22,22); c.fillStyle='#000'; c.fill(); },
	draw(c,R,v){ trunk(c,R,20,'#75685b',{roots:4,reach:40}); },
	leaves(c,R,k){ twig(c,R,k); },
	canopy(c,R,v){ const col='#6b5e52'; function br(x,y,a,l,w,d){ const x2=x+Math.cos(a)*l, y2=y+Math.sin(a)*l; limb(c,[x,y],[x2,y2],w,col); if(d>0){ const k=1+(R()<.6); for(let i=0;i<=k;i++) br(x2,y2,a+(R()-.5)*1.2,l*(.5+R()*.15),w*.62,d-1); } }
		const n=5+v; for(let i=0;i<n;i++) br(0,0,i/n*TAU+R()*.5,44+R()*18,12,3); vol(c,0,0,18,18,'#75685b',{hi:.25,lo:-.4}); c.strokeStyle='rgba(50,40,32,.5)'; c.lineWidth=1; for(let k=1;k<3;k++){ ell(c,0,0,6*k,6*k); c.stroke(); } }},
carcass:{cls:'LOW',box:[230,150],n:2,shadow:4,grime:.15,draw(c,R,v){ ell(c,0,4,82,40); c.fillStyle='rgba(88,64,46,.55)'; c.fill();
	for(let i=0;i<8;i++){ const x=-56+i*14; for(const s of [-1,1]){ c.beginPath(); c.moveTo(x,0); c.quadraticCurveTo(x+6,s*32,x-2,s*(44-Math.abs(i-3.5)*3)); c.lineWidth=4; c.strokeStyle='#5a4c3a'; c.stroke(); c.lineWidth=2.6; c.strokeStyle=BONE; c.stroke(); } }
	for(let i=0;i<12;i++) vol(c,-80+i*12,0,5,4,'#d2c6aa',{hi:.3,lo:-.35}); skull(c,86,0,1.2,-Math.PI/2,{horns:v===0}); if(v===1) bone(c,[-90,30],[-60,52],5); }},
haybale:{cls:'STATEFUL',box:[180,140],n:2,shadow:6,grime:.12,
	draw(c,R,v){ const col='#b09a62'; if(v===0){ vol(c,0,0,62,62,col,{hi:.18,lo:-.35}); c.lineWidth=1.4; for(let a=0;a<TAU*5;a+=.08){ const r1=4+a*1.85; c.beginPath(); c.arc(0,0,r1,a,a+.12); c.strokeStyle=R()<.5?'rgba(110,88,46,.45)':'rgba(220,206,150,.3)'; c.stroke(); } }
		else { c.beginPath(); rr(c,-80,-46,160,92,10); const g=c.createLinearGradient(0,-46,0,46); g.addColorStop(0,css(shade(C(col),-.2))); g.addColorStop(.45,css(shade(C(col),.1))); g.addColorStop(1,css(shade(C(col),-.3))); c.fillStyle=g; c.fill();
			atop(c,()=>{ c.lineWidth=1; for(let i=0;i<220;i++){ const x=(R()-.5)*160, y=(R()-.5)*92; c.beginPath(); c.moveTo(x,y); c.lineTo(x+6+R()*8,y+(R()-.5)*2); c.strokeStyle=R()<.5?'rgba(110,88,46,.4)':'rgba(220,206,150,.3)'; c.stroke(); }
				for(const x of [-40,40]){ c.fillStyle='rgba(60,40,26,.7)'; c.fillRect(x-1.5,-46,3,92); } }); }
		speckle(c,R,80,60,46,['rgba(230,214,160,.4)','rgba(90,70,40,.35)'],1.2); },
	breakable:{smashSpeed:250,box:[220,170],rim:false,broken(c,R){ for(let i=0;i<520;i++){ const a=R()*TAU, d=Math.sqrt(R()), x=Math.cos(a)*d*92, y=Math.sin(a)*d*62; c.beginPath(); c.moveTo(x,y); const b=R()*TAU; c.lineTo(x+Math.cos(b)*(4+R()*7),y+Math.sin(b)*(4+R()*7)); c.lineWidth=1.2; c.strokeStyle=R()<.5?'rgba(176,154,98,.9)':'rgba(130,108,64,.85)'; c.stroke(); }
		for(let i=0;i<5;i++) vol(c,(R()-.5)*120,(R()-.5)*70,10+R()*8,8+R()*6,'#a8925c',{hi:.18,lo:-.35}); },
		cell:48,debris(c,R,k){ vol(c,0,0,14+k*2,11,'#b09a62',{hi:.2,lo:-.4}); c.lineWidth=1; for(let i=0;i<30;i++){ const a=R()*TAU; c.beginPath(); c.moveTo(Math.cos(a)*6,Math.sin(a)*5); c.lineTo(Math.cos(a)*(14+R()*8),Math.sin(a)*(11+R()*6)); c.strokeStyle='rgba(176,154,98,.9)'; c.stroke(); } }}},
fence:{cls:'STATEFUL',box:[330,50],n:2,shadow:4,grime:.2,occluder:false,
	draw(c,R,v){ if(v===0){ for(const y of [-7,7]) plank(c,0,y,312,8,GREYWOOD,R,{nails:true}); }
		else { c.lineWidth=1; for(const y of [-6,0,6]){ c.beginPath(); c.moveTo(-156,y); for(let x=-156;x<=156;x+=26) c.lineTo(x,y+(R()-.5)*1.2); c.strokeStyle='#5b5d5e'; c.stroke(); for(let x=-150;x<156;x+=18){ c.beginPath(); c.moveTo(x-2,y-2); c.lineTo(x+2,y+2); c.moveTo(x+2,y-2); c.lineTo(x-2,y+2); c.stroke(); } } }
		for(const x of [-150,0,150]){ c.beginPath(); rr(c,x-8,-8,16,16,3); c.fillStyle='#5f5244'; c.fill(); vol(c,x,0,6.5,6.5,'#8a7a66',{hi:.2,lo:-.3}); } },
	breakable:{smashSpeed:180,box:[340,110],rim:false,broken(c,R){ for(const x of [-150,0,150]){ vol(c,x,0,7,7,'#6e6050',{hi:.15}); c.strokeStyle='rgba(40,30,20,.7)'; c.lineWidth=1; c.beginPath(); c.moveTo(x-5,-3); c.lineTo(x+4,2); c.stroke(); }
		plank(c,-80,26,120,8,GREYWOOD,R,{rot:.25}); plank(c,70,-24,100,8,GREYWOOD,R,{rot:-.4}); for(let i=0;i<14;i++) plank(c,(R()-.5)*300,(R()-.5)*60,8+R()*14,3,GREYWOOD,R,{rot:R()*3}); },
		cell:56,debris(c,R,k){ plank(c,0,0,30+k*4,7,GREYWOOD,R,{rot:(R()-.5)*.6,nails:k%2===0}); }}},
hedge:{cls:'STATEFUL',box:[400,100],n:2,shadow:6,grime:.08,occluder:true,
	draw(c,R,v){ const cols=['#4b5b30','#566739','#5f7040']; for(let i=0;i<54;i++){ const x=-178+R()*356, y=(R()-.5)*44, r=16+R()*12; vol(c,x,y,r,r*(.85+R()*.2),shade(C(cols[0]),-.15),{hi:.1,lo:-.45}); }
		for(let i=0;i<40;i++){ const x=-170+R()*340, y=(R()-.5)*30, r=13+R()*10; vol(c,x,y,r,r,cols[(R()*3)|0],{hi:.22,lo:-.35}); }
		speckle(c,R,900,190,44,['rgba(18,26,10,.35)','rgba(186,196,138,.25)'],1.4); if(v===1) speckle(c,R,40,170,34,['rgba(214,206,176,.8)','rgba(190,170,200,.7)'],1.6); },
	breakable:{smashSpeed:300,box:[410,120],rim:false,broken(c,R){ for(let i=0;i<60;i++){ const x=-180+R()*360, y=(R()-.5)*50; const a=R()*TAU; limb(c,[x,y],[x+Math.cos(a)*(8+R()*14),y+Math.sin(a)*(8+R()*14)],2.2,'#5a4a36'); }
		for(let i=0;i<260;i++){ ell(c,-190+R()*380,(R()-.5)*80,2+R()*2.5,1.5+R()*2,R()*3); c.fillStyle=R()<.5?'rgba(80,98,52,.9)':'rgba(60,76,40,.9)'; c.fill(); } },
		cell:48,debris(c,R,k){ for(let i=0;i<6;i++) vol(c,(R()-.5)*16,(R()-.5)*16,6+R()*4,6+R()*4,'#566739',{hi:.2,lo:-.4}); limb(c,[-12,8],[12,-6],2,'#5a4a36'); }}},
crate:{cls:'STATEFUL',box:[100,100],n:3,shadow:5,grime:.22,occluder:false,tags:{bait:true},
	draw(c,R,v){ const col=v===1?'#6e5438':'#8a6a44'; c.beginPath(); rr(c,-44,-44,88,88,4); c.fillStyle=css(shade(C(col),-.35)); c.fill();
		for(let k=0;k<4;k++) plank(c,0,-30+k*20,80,17,col,R,{}); plank(c,0,0,96,12,shade(C(col),-.1),R,{rot:Math.PI/4,nails:true});
		for(const s of [-1,1]) for(const t of [-1,1]){ c.fillStyle='rgba(60,58,56,.9)'; c.fillRect(s*40-4,t*40-4,8,8); }
		if(v===1){ rag(c,-30,-36,30,-.6,R); } if(v===2) daub(c,18,20,22,7,-.2); crown(c,0,0,60,.08,.2); },
	breakable:{smashSpeed:150,box:[150,150],broken(c,R){ for(let i=0;i<7;i++) plank(c,(R()-.5)*90,(R()-.5)*90,40+R()*40,15,'#8a6a44',R,{rot:R()*3,nails:R()<.5}); for(let i=0;i<16;i++) plank(c,(R()-.5)*120,(R()-.5)*120,6+R()*12,3,'#7a5c3a',R,{rot:R()*3}); },
		cell:56,debris(c,R,k){ plank(c,0,0,26+k*5,14,'#8a6a44',R,{rot:(R()-.5)*.8,nails:true}); }}},
shack:{cls:'TALL',box:[380,320],n:2,shadow:10,grime:.3,draw(c,R,v){ c.beginPath(); rr(c,-180,-150,360,300,6); c.fillStyle='rgba(30,24,20,.9)'; c.fill();
	if(v===0){ const cols=['#7a7570','#806a52','#6d6a64','#7a4a32','#73706a']; for(let row=0;row<2;row++) for(let k=0;k<5;k++) sheet(c,-144+k*72+(R()-.5)*6,row?72:-72,78,146,cols[(R()*cols.length)|0],R,{rib:6,rot:(R()-.5)*.03}); }
	else { for(let k=0;k<17;k++) plank(c,-170+k*21.3,0,22,300,shade(C(WOOD),(R()-.5)*.2),R,{alongY:true,nails:true}); c.fillStyle='rgba(40,34,30,.55)'; c.fillRect(-60,-40,90,70); }
	c.fillStyle='rgba(255,255,255,.12)'; c.fillRect(-180,-3,360,6); c.fillStyle='rgba(0,0,0,.18)'; c.fillRect(-180,3,360,3);
	vol(c,110,-90,14,14,'#4a4846',{hi:.3}); ell(c,110,-90,7,7); c.fillStyle='#121010'; c.fill(); ring(c,-120,100,22,9,R); stone(c,-60,-110,10,R); crown(c,0,0,240,.06,.25); }},
tent:{cls:'TALL',box:[230,230],n:2,shadow:8,grime:.2,core(c){ ell(c,0,0,80,80); c.fillStyle='#000'; c.fill(); },
	draw(c,R,v){ const r=92, n=7, cols=['#8a7056','#76604a','#957c5c']; for(let i=0;i<n;i++){ const a0=i/n*TAU, a1=(i+1)/n*TAU; c.beginPath(); c.moveTo(0,0); c.lineTo(Math.cos(a0)*r,Math.sin(a0)*r); c.quadraticCurveTo(Math.cos((a0+a1)/2)*r*1.08,Math.sin((a0+a1)/2)*r*1.08,Math.cos(a1)*r,Math.sin(a1)*r); c.closePath();
		const g=c.createRadialGradient(0,0,4,0,0,r); g.addColorStop(0,css(shade(C(cols[i%3]),.2))); g.addColorStop(1,css(shade(C(cols[i%3]),-.35))); c.fillStyle=g; c.fill(); c.strokeStyle='rgba(50,36,24,.6)'; c.lineWidth=1.4; c.stroke(); }
		for(let i=0;i<4;i++){ c.save(); c.rotate(R()*TAU); const px=24+R()*36; c.fillStyle='rgba(60,44,30,.45)'; c.fillRect(px,-8,18,15); c.strokeStyle='rgba(40,28,18,.55)'; c.lineWidth=.8; c.strokeRect(px,-8,18,15); c.restore(); }
		ell(c,0,0,12,12); c.fillStyle='#1c1612'; c.fill(); for(let i=0;i<5;i++){ const a=i/5*TAU+R()*.3; limb(c,[Math.cos(a)*4,Math.sin(a)*4],[Math.cos(a)*26,Math.sin(a)*26],3.4,'#8a6a44'); }
		rag(c,0,0,46,R()*TAU,R); if(v===1) skull(c,0,-46,.8,0,{}); for(let i=0;i<n;i++){ const a=(i+.5)/n*TAU; ell(c,Math.cos(a)*(r+6),Math.sin(a)*(r+6),2.4,2.4); c.fillStyle='#5a4430'; c.fill(); } }},
totem:{cls:'TALL',box:[150,150],n:2,shadow:6,grime:.2,core(c){ ell(c,0,0,30,30); c.fillStyle='#000'; c.fill(); },
	draw(c,R,v){ for(let i=0;i<9;i++){ const a=i/9*TAU+R()*.3; stone(c,Math.cos(a)*36,Math.sin(a)*36,10+R()*4,R); }
		for(let i=0;i<5;i++) rag(c,0,0,44+R()*16,i/5*TAU+R()*.5,R,i%2?RAG:'#c86a2a');
		vol(c,0,0,26,26,'#6b5034',{hi:.25,lo:-.45}); c.strokeStyle='rgba(30,20,12,.55)'; c.lineWidth=1.4; for(let k=1;k<3;k++){ ell(c,0,0,9*k,9*k); c.stroke(); }
		if(v===0) skull(c,0,-4,.9,0,{horns:true}); else { for(let i=0;i<6;i++){ const a=i/6*TAU; limb(c,[0,0],[Math.cos(a)*30,Math.sin(a)*30],3,'#d8cdb4'); } vol(c,0,0,10,10,'#e0782c',{hi:.2}); } }},
firepit:{cls:'LOW',box:[150,150],n:1,shadow:4,grime:.15,draw(c,R){ ell(c,0,0,46,46); c.fillStyle='#2e2a26'; c.fill(); const g=c.createRadialGradient(0,0,2,0,0,40); g.addColorStop(0,'rgba(120,110,100,.7)'); g.addColorStop(1,'rgba(40,36,32,0)'); c.fillStyle=g; c.fill();
	for(let i=0;i<4;i++){ const a=i/4*Math.PI+R()*.3; limb(c,[Math.cos(a)*-28,Math.sin(a)*-28],[Math.cos(a)*28,Math.sin(a)*28],8,'#2a1e16'); }
	for(let i=0;i<14;i++){ const a=R()*TAU, d=R()*24; glowAt(c,Math.cos(a)*d,Math.sin(a)*d,5+R()*6,'#c8642a',.7); ell(c,Math.cos(a)*d,Math.sin(a)*d,1.4,1.4); c.fillStyle='#e8a050'; c.fill(); }
	for(let i=0;i<10;i++){ const a=i/10*TAU; stone(c,Math.cos(a)*54,Math.sin(a)*54,12+R()*3,R); } }},
tyres:{cls:'LOW',box:[200,160],n:3,shadow:6,grime:.25,tags:{faction:['scrap','tribe']},draw(c,R,v){
	if(v===0){ for(let k=2;k>=0;k--) ring(c,k*3-3,k*4-4,46,20,R,shade(C('#1d1c1e'),-k*.05)); }
	else if(v===1){ for(const s of [-1,1]) for(let k=1;k>=0;k--) ring(c,s*48+k*3,k*4,44,19,R); daub(c,-40,-30,16,5,.3); }
	else { ring(c,-50,-20,40,17,R); ring(c,40,-30,38,16,R); ring(c,0,40,42,18,R); daub(c,30,-48,14,5,-.4); } }},
barricade:{cls:'STATEFUL',box:[280,110],n:2,shadow:6,grime:.3,tags:{faction:['tribe','scrap']},
	draw(c,R,v){ for(let i=0;i<9;i++){ const x=-110+i*27; c.save(); c.translate(x,14); c.rotate(.25+(R()-.5)*.2); c.beginPath(); c.moveTo(-5,-30); c.lineTo(5,-30); c.lineTo(4,24); c.lineTo(0,36); c.lineTo(-4,24); c.closePath(); c.fillStyle='#6b5034'; c.fill(); c.restore(); }
		sheet(c,-60,-6,90,40,'#6d6a64',R,{rot:-.05}); sheet(c,40,-4,100,36,v?'#7a4a32':'#5a6068',R,{rot:.06}); plank(c,0,-20,250,12,WOOD,R,{nails:true,rot:.03}); plank(c,-20,10,220,10,GREYWOOD,R,{rot:-.05});
		c.strokeStyle='#5b5d5e'; c.lineWidth=1.2; c.beginPath(); for(let a=0;a<TAU*9;a+=.3){ c.lineTo(-120+a*4.3,-34+Math.sin(a)*6); } c.stroke(); rag(c,-90,-20,30,-1.2,R); if(v) daub(c,60,-4,16,6,0); },
	breakable:{smashSpeed:350,box:[300,160],broken(c,R){ for(let i=0;i<6;i++) plank(c,(R()-.5)*240,(R()-.5)*80,50+R()*60,11,R()<.5?WOOD:GREYWOOD,R,{rot:R()*3,nails:true}); sheet(c,(R()-.5)*100,(R()-.5)*40,70,34,'#6d6a64',R,{rot:R()*3}); for(let i=0;i<5;i++){ c.save(); c.translate((R()-.5)*240,(R()-.5)*90); c.rotate(R()*3); c.fillStyle='#6b5034'; c.fillRect(-4,-14,8,28); c.restore(); } },
		cell:64,debris(c,R,k){ if(k%2) sheet(c,0,0,30,18,'#6d6a64',R,{rot:R()}); else plank(c,0,0,40,9,WOOD,R,{rot:R()-.5,nails:true}); }}},
barrel:{cls:'STATEFUL',box:[70,70],n:3,shadow:4,grime:.25,explosive:true,occluder:false,
	draw(c,R,v){ const col=v===1?'#7d3426':'#8e3a2a'; vol(c,0,0,27,27,col,{hi:.2,lo:-.4}); c.lineWidth=2; c.strokeStyle='rgba(30,14,10,.6)'; ell(c,0,0,23,23); c.stroke(); c.strokeStyle='rgba(230,200,180,.25)'; c.lineWidth=1; ell(c,0,0,25.5,25.5); c.stroke();
		for(const p of [[-11,-8],[12,6]]){ vol(c,p[0],p[1],4,4,'#5a5856',{hi:.3}); }
		c.save(); c.translate(2,-2); c.rotate(Math.PI/4); c.fillStyle='rgba(214,190,120,.85)'; c.fillRect(-6,-6,12,12); c.restore(); c.beginPath(); c.moveTo(2,-7); c.quadraticCurveTo(7,-1,2,4); c.quadraticCurveTo(-3,-1,2,-7); c.fillStyle='#7a2a1e'; c.fill();
		rust(c,8,10,16,70+v); if(v===1){ ell(c,-12,10,9,6); c.fillStyle='rgba(30,14,10,.35)'; c.fill(); } if(v===2) daub(c,-10,14,14,4,.4); },
	breakable:{smashSpeed:120,box:[200,200],rim:false,broken(c,R){ const g=c.createRadialGradient(0,0,10,0,0,92); g.addColorStop(0,'rgba(14,12,10,.85)'); g.addColorStop(.6,'rgba(24,20,16,.45)'); g.addColorStop(1,'rgba(24,20,16,0)'); c.fillStyle=g; ell(c,0,0,92,92); c.fill();
		const pts=[]; for(let i=0;i<14;i++){ const a=i/14*TAU, r=i%2?20:36+R()*10; pts.push([Math.cos(a)*r,Math.sin(a)*r]); } polyPath(c,pts); c.fillStyle='#5a2a20'; c.fill(); ell(c,0,0,18,18); c.fillStyle='#120e0c'; c.fill(); },
		cell:40,debris(c,R,k){ c.beginPath(); c.moveTo(-12,-6); c.quadraticCurveTo(0,-12,12,-4); c.lineTo(8,8); c.quadraticCurveTo(0,2,-10,6); c.closePath(); c.fillStyle=k%2?'#8e3a2a':'#5a2a20'; c.fill(); c.strokeStyle='rgba(20,10,8,.6)'; c.lineWidth=1; c.stroke(); }}},
crane:{cls:'TALL',box:[620,280],n:1,shadow:12,baseShadow:10,grime:.3,core(c){ c.fillStyle='#000'; c.fillRect(-275,-110,250,220); },
	draw(c,R){ c.translate(-125,0); for(const s of [-1,1]){ c.beginPath(); rr(c,-140,s*84-24,250,48,18); c.fillStyle='#232221'; c.fill(); c.save(); c.clip(); c.strokeStyle='rgba(120,118,112,.45)'; c.lineWidth=2; for(let x=-140;x<110;x+=9){ c.beginPath(); c.moveTo(x,s*84-24); c.lineTo(x,s*84+24); c.stroke(); } c.restore(); }
		c.save(); c.rotate(-.06); c.beginPath(); rr(c,-130,-62,210,124,10); const g=c.createLinearGradient(0,-62,0,62); g.addColorStop(0,'#7a6a34'); g.addColorStop(.5,'#a08a46'); g.addColorStop(1,'#6a5a2c'); c.fillStyle=g; c.fill();
		c.fillStyle='#5f5d58'; c.fillRect(-130,-56,46,112); c.strokeStyle='rgba(0,0,0,.3)'; c.lineWidth=1.4; for(let y=-50;y<56;y+=14){ c.beginPath(); c.moveTo(-128,y); c.lineTo(-86,y); c.stroke(); }
		c.beginPath(); rr(c,10,-58,56,50,6); c.fillStyle='#3a3c3e'; c.fill(); c.fillStyle='rgba(120,150,170,.45)'; c.fillRect(44,-52,18,38); c.globalAlpha=.7; rust(c,-20,20,40,91); c.globalAlpha=1;
		c.restore(); daub(c,-40,40,22,6,0); crown(c,-20,0,200,.06,.18); },
	/* the jib reaches past the hull (the cab and tracks), so it is drawn over the car */
	canopy(c,R){ c.translate(-125,0); c.save(); c.rotate(-.06);
		const bx=70; for(const s of [-1,1]) limb(c,[bx,s*16],[bx+320,s*6],5,'#8a7a3a'); c.strokeStyle='#7a6a32'; c.lineWidth=2.4; c.beginPath(); for(let x=bx;x<bx+320;x+=22){ const t=(x-bx)/320, w=16-10*t; c.moveTo(x,-w); c.lineTo(x+22,w-1); c.moveTo(x,w); c.lineTo(x+22,-w+1); } c.stroke();
		vol(c,bx+322,0,9,9,'#4a4846',{hi:.3}); c.fillStyle='rgba(214,190,120,.8)'; c.fillRect(bx+316,-3,12,6); c.restore(); }},
fortwall:{cls:'WALL',box:[420,110],n:2,shadow:7,grime:.3,tags:{faction:['tribe','scrap']},draw(c,R,v){
	for(let i=0;i<16;i++){ const x=-195+i*26; c.beginPath(); c.moveTo(x-8,-34); c.lineTo(x+8,-34); c.lineTo(x+7,-10); c.lineTo(x,-2); c.lineTo(x-7,-10); c.closePath(); c.fillStyle='#5c4630'; c.fill(); vol(c,x,-30,6.5,6.5,'#7a5c3e',{hi:.25}); }
	const cols=['#6d6a64','#7a4a32','#5a6068','#4e4a42','#806a4a']; for(let k=0;k<7;k++) sheet(c,-170+k*56+(R()-.5)*8,6+(R()-.5)*6,60,40,cols[(R()*cols.length)|0],R,{rot:(R()-.5)*.08});
	for(let k=0;k<3;k++) ring(c,-140+k*140+(R()-.5)*30,30,17,7,R); for(let i=0;i<12;i++){ const x=-190+i*34; c.save(); c.translate(x,30); c.fillStyle='#b9bbbd'; c.beginPath(); c.moveTo(-3,0); c.lineTo(0,14); c.lineTo(3,0); c.fill(); c.restore(); }
	rag(c,-120,-30,34,-1.3,R); rag(c,80,-30,30,-1.8,R); if(v) daub(c,20,10,20,6,.1); }},
cabin:{cls:'TALL',box:[360,300],n:2,shadow:10,grime:.2,draw(c,R,v){ c.beginPath(); rr(c,-170,-140,340,280,4); c.fillStyle='#2a2018'; c.fill();
	c.save(); c.beginPath(); rr(c,-170,-140,340,280,4); c.clip();
	for(const s of [-1,1]) for(let row=0;row<9;row++){ const y=s*(8+row*14.5); for(let k=0;k<13;k++){ c.beginPath(); rr(c,-166+k*28+(row%2)*14,y-7.5,30,15,2); c.fillStyle=css(shade(C('#6b5440'),(R()-.5)*.2-row*.02)); c.fill(); c.strokeStyle='rgba(30,20,14,.5)'; c.lineWidth=.8; c.stroke(); } } c.restore();
	c.fillStyle='#4a3a2c'; c.fillRect(-170,-4,340,8); c.save(); c.beginPath(); rr(c,-170,-140,340,280,4); c.clip();
	snowCover(c,-170,-140,340,280,v?.45:.72,301+v); c.fillStyle='rgba(222,228,234,.85)'; c.fillRect(-170,-6,340,12); c.restore();
	c.beginPath(); rr(c,90,-110,40,40,4); c.fillStyle='#6d6660'; c.fill(); for(let i=0;i<6;i++) stone(c,96+(i%3)*14,-104+((i/3)|0)*20,6,R,'#7d766e'); ell(c,110,-90,8,8); c.fillStyle='#141010'; c.fill(); crown(c,0,0,220,.05,.22); }},
snowcat:{cls:'TALL',box:[290,190],n:1,shadow:8,grime:.3,tags:{faction:['scrap']},draw(c,R){ for(const s of [-1,1]){ c.beginPath(); rr(c,-120,s*56-22,240,44,14); c.fillStyle='#1f1e1d'; c.fill(); c.save(); c.clip(); c.strokeStyle='rgba(130,128,124,.45)'; c.lineWidth=2.2; for(let x=-120;x<120;x+=10){ c.beginPath(); c.moveTo(x,s*56-22); c.lineTo(x,s*56+22); c.stroke(); } c.restore(); }
	c.beginPath(); rr(c,-100,-40,200,80,10); const g=c.createLinearGradient(0,-40,0,40); g.addColorStop(0,'#5e2a20'); g.addColorStop(.5,'#8a3a2c'); g.addColorStop(1,'#552620'); c.fillStyle=g; c.fill();
	c.beginPath(); rr(c,-10,-34,80,68,8); c.fillStyle='#743226'; c.fill(); c.fillStyle='#1c2226'; c.fillRect(58,-28,10,56); c.fillStyle='rgba(150,180,200,.25)'; c.fillRect(60,-26,4,20);
	c.save(); c.translate(132,0); c.beginPath(); c.moveTo(-6,-80); c.lineTo(8,-74); c.lineTo(8,74); c.lineTo(-6,80); c.closePath(); const pg=c.createLinearGradient(-6,0,8,0); pg.addColorStop(0,'#5a5c5e'); pg.addColorStop(1,'#a0a2a4'); c.fillStyle=pg; c.fill(); c.restore(); limb(c,[100,-30],[126,-40],5,'#3a3c3e'); limb(c,[100,30],[126,40],5,'#3a3c3e');
	c.globalAlpha=.7; rust(c,-60,10,40,93); c.globalAlpha=1; c.save(); c.beginPath(); rr(c,-100,-40,200,80,10); c.clip(); snowCover(c,-100,-40,200,80,.22,311); c.restore(); daub(c,-70,-28,24,7,0); crown(c,0,0,160,.06,.2); }},
wreck:{cls:'LOW',box:[150,300],n:5,shadow:7,grime:.35,wreck:true},
jersey:{cls:'WALL',box:[330,70],n:2,shadow:6,grime:.25,draw(c,R,v){ c.beginPath(); rr(c,-160,-26,320,52,10); const g=c.createLinearGradient(0,-26,0,26); g.addColorStop(0,'#77736b'); g.addColorStop(.35,'#a39e94'); g.addColorStop(.5,'#b3aea3'); g.addColorStop(.65,'#a39e94'); g.addColorStop(1,'#6e6a62'); c.fillStyle=g; c.fill();
	atop(c,()=>{ for(let i=0;i<14;i++){ ell(c,(R()-.5)*300,(R()-.5)*40,6+R()*16,2+R()*4,R()*.4); c.fillStyle=R()<.5?'rgba(40,36,32,.18)':'rgba(128,66,34,.12)'; c.fill(); }
		for(const s of [-1,1]){ c.fillStyle='rgba(30,28,26,.6)'; c.fillRect(s*150-4,-6,8,12); } if(v===1){ c.beginPath(); c.moveTo(60,-26); c.lineTo(80,-14); c.lineTo(96,-26); c.closePath(); c.fillStyle='rgba(60,56,50,.7)'; c.fill(); for(let i=0;i<8;i++){ c.fillStyle='rgba(30,28,26,.6)'; c.fillRect(70+R()*30,-20+R()*14,2,2); } } }); }},
cone:{cls:'LOW',box:[56,56],n:2,shadow:3,grime:.15,draw(c,R,v){ c.save(); c.rotate(v?.6:.15); c.beginPath(); rr(c,-20,-20,40,40,5); c.fillStyle='#a44e24'; c.fill(); c.restore(); vol(c,0,0,15,15,'#c8602c',{hi:.25,lo:-.3}); ell(c,0,0,10,10); c.lineWidth=3.6; c.strokeStyle='#dcd8ce'; c.stroke(); ell(c,0,0,3.6,3.6); c.fillStyle='#2a1a12'; c.fill(); }},
gaspump:{cls:'LOW',box:[200,90],n:2,shadow:5,grime:.25,draw(c,R,v){ c.beginPath(); rr(c,-90,-32,180,64,26); const g=c.createLinearGradient(0,-32,0,32); g.addColorStop(0,'#77736b'); g.addColorStop(.5,'#9a958b'); g.addColorStop(1,'#6e6a62'); c.fillStyle=g; c.fill(); c.lineWidth=3; c.strokeStyle='rgba(168,146,90,.7)'; c.beginPath(); rr(c,-88,-30,176,60,24); c.stroke();
	for(const s of [-1,1]){ const x=s*46; c.beginPath(); rr(c,x-18,-14,36,28,3); c.fillStyle=v?'#5a6068':'#8a3a2c'; c.fill(); c.fillStyle='#dcd8ce'; c.fillRect(x-14,-10,28,10); c.fillStyle='#1c2226'; c.fillRect(x-8,-8,16,6);
		c.beginPath(); c.moveTo(x+s*16,4); c.bezierCurveTo(x+s*34,20,x+s*10,34,x+s*28,30); c.lineWidth=2.4; c.strokeStyle='#1d1c1e'; c.stroke(); vol(c,x+s*28,30,3,3,'#3a3836'); }
	vol(c,0,0,10,10,'#8d8f8c',{hi:.35}); rust(c,-60,10,14,95+v); }},
sign:{cls:'LOW',box:[110,80],n:3,shadow:3,grime:.2,draw(c,R,v){ if(v===0){ limb(c,[0,0],[46,10],5,'#6d6f72'); c.save(); c.rotate(.2); c.beginPath(); for(let i=0;i<8;i++){ const a=i/8*TAU+TAU/16; c.lineTo(Math.cos(a)*24,Math.sin(a)*24); } c.closePath(); c.fillStyle='#8e3228'; c.fill(); c.lineWidth=2.6; c.strokeStyle='#d8d2c6'; c.stroke(); c.fillStyle='rgba(216,210,198,.8)'; c.fillRect(-12,-3,24,6); c.restore(); rust(c,10,6,12,97); }
	else if(v===1){ c.fillStyle='#3a3c3e'; c.fillRect(-36,-3,72,6); c.fillStyle='rgba(230,226,214,.5)'; c.fillRect(-36,-3,72,1.4); vol(c,0,5,4,4,'#6d6f72',{hi:.3}); }
	else { vol(c,0,0,7,7,'#6b5034',{hi:.3}); for(const a of [-.4,2.5]){ c.save(); c.rotate(a); c.beginPath(); c.moveTo(4,-8); c.lineTo(40,-8); c.lineTo(50,0); c.lineTo(40,8); c.lineTo(4,8); c.closePath(); c.fillStyle='#8a6a44'; c.fill(); c.strokeStyle='rgba(40,28,18,.5)'; c.lineWidth=1; c.stroke(); c.restore(); } } }},
billboard:{cls:'TALL',box:[400,100],n:2,shadow:8,grime:.3,draw(c,R,v){ c.fillStyle='#8b8d8c'; c.fillRect(-180,6,360,20); c.strokeStyle='rgba(40,40,40,.45)'; c.lineWidth=1; for(let x=-180;x<180;x+=6){ c.beginPath(); c.moveTo(x,6); c.lineTo(x,26); c.stroke(); } c.beginPath(); c.moveTo(-180,26); c.lineTo(180,26); c.lineWidth=2; c.strokeStyle='#5c5e60'; c.stroke();
	c.beginPath(); rr(c,-190,-8,380,12,2); c.fillStyle='#2f2d2b'; c.fill(); c.fillStyle=v?'rgba(150,120,90,.6)':'rgba(170,80,60,.5)'; c.fillRect(-190,-8,380,3);
	for(const x of [-120,120]){ vol(c,x,-2,10,10,'#6d6f72',{hi:.35}); } for(const x of [-150,-50,50,150]){ limb(c,[x,4],[x,30],3,'#4a4c4e'); c.fillStyle='#d8d4c0'; c.fillRect(x-6,28,12,5); } rust(c,0,16,40,99+v); },
	/* toppled (Spill "fall"): the board lies face up on its +y side, the posts snapped at the base */
	breakable:{smashSpeed:360,box:[420,330],rim:false,broken(c,R){ for(const x of [-120,120]){ vol(c,x,-2,10,10,'#6d6f72',{hi:.35}); c.strokeStyle='#4a4c4e'; c.lineWidth=5; c.beginPath(); c.moveTo(x,6); c.lineTo(x+(R()-.5)*10,24); c.stroke(); }
		c.save(); c.translate(0,82); c.rotate((R()-.5)*.05); c.fillStyle='rgba(18,13,16,.35)'; c.fillRect(-196,-58,392,124); c.beginPath(); rr(c,-190,-60,380,118,3); c.fillStyle='#2f2d2b'; c.fill();
		c.fillStyle='#b8ac8c'; c.fillRect(-182,-52,364,102); c.fillStyle='rgba(150,64,42,.85)'; c.fillRect(-182,-52,150,102); c.fillStyle='rgba(40,74,87,.8)'; c.fillRect(-20,-30,180,22); c.fillStyle='rgba(40,74,87,.6)'; c.fillRect(-20,2,120,14);
		ell(c,-107,-1,30,30); c.fillStyle='rgba(230,214,170,.85)'; c.fill(); c.strokeStyle='rgba(30,28,26,.3)'; c.lineWidth=1; for(let x=-182;x<182;x+=46){ c.beginPath(); c.moveTo(x,-52); c.lineTo(x,50); c.stroke(); }
		atop(c,()=>{ for(let i=0;i<6;i++){ ell(c,(R()-.5)*360,(R()-.5)*90,10+R()*30,4+R()*8,R()*.4); c.fillStyle='rgba(30,26,22,.22)'; c.fill(); } }); c.restore(); },
		cell:56,debris(c,R,k){ if(k%2) sheet(c,0,0,30,16,'#8b8d8c',R,{rot:R()}); else { c.fillStyle=['#b8ac8c','#963e2a'][k%2?1:0]; c.fillRect(-14,-8,28,16); } }}},
hydrant:{cls:'LOW',box:[50,50],n:1,shadow:3,grime:.25,draw(c,R){ for(const a of [0,Math.PI,Math.PI/2]){ vol(c,Math.cos(a)*15,Math.sin(a)*15,6,6,'#7a2e22',{hi:.3}); } vol(c,0,0,15,15,'#9a3a2c',{hi:.3,lo:-.4}); c.beginPath(); for(let i=0;i<5;i++){ const a=i/5*TAU; c.lineTo(Math.cos(a)*5,Math.sin(a)*5); } c.closePath(); c.fillStyle='#5a5856'; c.fill(); rust(c,5,5,8,101); }},
dumpster:{cls:'LOW',box:[190,120],n:2,shadow:6,grime:.35,draw(c,R,v){ const col=v?'#3e5466':'#4a5a46'; c.beginPath(); rr(c,-84,-48,168,96,6); c.fillStyle=css(shade(C(col),-.35)); c.fill();
	for(const s of [-1,1]){ c.save(); c.translate(s*42,0); if(s>0) c.rotate(.04); c.beginPath(); rr(c,-40,-44,80,88,4); const g=c.createLinearGradient(0,-44,0,44); g.addColorStop(0,css(shade(C(col),-.15))); g.addColorStop(.5,css(shade(C(col),.12))); g.addColorStop(1,css(shade(C(col),-.25))); c.fillStyle=g; c.fill();
		c.strokeStyle='rgba(0,0,0,.25)'; c.lineWidth=1; for(let y=-36;y<44;y+=10){ c.beginPath(); c.moveTo(-38,y); c.lineTo(38,y); c.stroke(); } c.restore(); }
	if(v===0){ vol(c,60,-30,16,12,'#1c1c1e',{hi:.3}); vol(c,72,-20,12,10,'#2a2a2c',{hi:.3}); } rust(c,-40,20,30,103+v); rust(c,30,-20,20,104); }},
busstop:{cls:'LOW',box:[280,120],n:1,shadow:7,grime:.25,draw(c,R){ c.beginPath(); rr(c,-128,-44,256,88,4); c.fillStyle='#3a3c3e'; c.fill(); c.fillStyle='#7a6a54'; c.fillRect(-100,-10,200,22);
	for(let k=0;k<4;k++){ c.fillStyle='rgba(150,168,176,.82)'; c.fillRect(-122+k*62,-38,56,76); c.fillStyle='rgba(255,255,255,.12)'; c.fillRect(-118+k*62,-34,12,68); } c.fillStyle='rgba(200,170,130,.85)'; c.fillRect(110,-40,14,80); rust(c,-60,20,20,105); }},
manhole:{cls:'STATEFUL',box:[70,70],n:1,shadow:0,grime:.3,rim:false,occluder:false,solid:false,draw(c,R){ ell(c,0,0,30,30); c.fillStyle='#3a3836'; c.fill(); vol(c,0,0,27,27,'#4f4c49',{hi:.12,lo:-.3});
	c.strokeStyle='rgba(20,18,16,.6)'; c.lineWidth=2; for(let k=-2;k<=2;k++){ c.beginPath(); c.moveTo(-24,k*9); c.lineTo(24,k*9); c.stroke(); c.beginPath(); c.moveTo(k*9,-24); c.lineTo(k*9,24); c.stroke(); } ell(c,0,0,24,24); c.stroke();
	for(const s of [-1,1]){ ell(c,s*16,0,2.2,2.2); c.fillStyle='#0c0a0a'; c.fill(); } ell(c,0,0,30,30); c.strokeStyle='rgba(128,66,34,.45)'; c.lineWidth=2; c.stroke(); }},
scrapheap:{cls:'TALL',box:[340,320],n:3,shadow:10,grime:.3,tags:{faction:['scrap']},draw(c,R,v){ const cols=['#6d6a64','#7a4a32','#5a6068','#4e4a42','#806a4a','#5c5f3a','#8d8f8c','#3e5466'];
	const base=[]; for(let i=0;i<18;i++){ const a=i/18*TAU, r=(118+R()*30)*(i%2?.92:1); base.push([Math.cos(a)*r,Math.sin(a)*r*.9]); } polyPath(c,base); c.fillStyle='#3a332c'; c.fill();
	atop(c,()=>{ for(let i=0;i<200;i++){ const a=R()*TAU, d=Math.sqrt(R())*140; ell(c,Math.cos(a)*d,Math.sin(a)*d*.9,3+R()*6,2+R()*4,R()*3); c.fillStyle=R()<.5?'rgba(20,18,16,.5)':'rgba(120,110,96,.35)'; c.fill(); } });
	for(let layer=0;layer<5;layer++){ const rad=128-layer*26, n=34-layer*5; for(let i=0;i<n;i++){ const a=R()*TAU, d=rad*Math.sqrt(R()), x=Math.cos(a)*d, y=Math.sin(a)*d*.9, t=R(), sh=-.32+layer*.11;
		c.save(); c.translate(x,y); c.rotate(R()*TAU);
		if(t<.45) sheet(c,0,0,24+R()*28,14+R()*18,shade(C(cols[(R()*cols.length)|0]),sh),R,{rib:4,rust:.25});
		else if(t<.58) ring(c,0,0,13+R()*6,6,R,shade(C('#1d1c1e'),sh*.5));
		else if(t<.76) limb(c,[-16,0],[16,0],6,shade(C('#6d6f72'),sh));
		else if(t<.9){ c.beginPath(); rr(c,-18,-12,36,24,4); c.fillStyle=css(shade(C(cols[(R()*cols.length)|0]),sh)); c.fill(); c.fillStyle='rgba(28,34,38,.8)'; c.fillRect(-12,-8,16,10); }
		else { vol(c,0,0,12,9,shade(C('#4a4c4f'),sh),{hi:.3}); }
		c.restore(); } }
	for(let i=0;i<3;i++) daub(c,(R()-.5)*140,(R()-.5)*120,12,4,R()*3); crown(c,0,0,165,.16,.42); }},
container:{cls:'TALL',box:[500,210],n:3,shadow:9,grime:.3,draw(c,R,v){ const col=C(['#7d3a26','#3e5466','#5a5e3a'][v]); c.beginPath(); rr(c,-240,-94,480,188,3); c.fillStyle=css(shade(col,-.3)); c.fill();
	for(let x=-236;x<236;x+=12){ const g=c.createLinearGradient(x,0,x+12,0); g.addColorStop(0,css(shade(col,-.12))); g.addColorStop(.5,css(shade(col,.1))); g.addColorStop(1,css(shade(col,-.18))); c.fillStyle=g; c.fillRect(x,-90,12,180); }
	atop(c,()=>{ for(let i=0;i<5;i++){ ell(c,(R()-.5)*400,(R()-.5)*140,20+R()*30,14+R()*20); c.fillStyle='rgba(0,0,0,.12)'; c.fill(); } rust(c,-120,30,70,107+v); rust(c,140,-30,60,108+v);
		for(let i=0;i<6;i++){ const x=(R()-.5)*440; c.fillStyle='rgba(110,54,28,.28)'; c.fillRect(x,-90,4+R()*6,180); } });
	for(const sx of [-1,1]) for(const sy of [-1,1]){ c.fillStyle='#2a2826'; c.fillRect(sx*232-8,sy*86-8,16,16); }
	if(v===2) daub(c,-160,-60,40,10,0); }},
tank:{cls:'STATEFUL',box:[330,330],n:1,shadow:12,grime:.3,explosive:true,occluder:true,tags:{faction:['scrap']},
	draw(c,R){ vol(c,0,0,150,150,'#a29d92',{hi:.18,lo:-.32}); c.strokeStyle='rgba(60,56,50,.4)'; c.lineWidth=1.4; for(let k=1;k<6;k++){ ell(c,0,0,150*k/6,150*k/6); c.stroke(); } for(let i=0;i<16;i++){ const a=i/16*TAU; c.beginPath(); c.moveTo(Math.cos(a)*25,Math.sin(a)*25); c.lineTo(Math.cos(a)*150,Math.sin(a)*150); c.stroke(); }
		atop(c,()=>{ for(let i=0;i<10;i++){ const a=R()*TAU; c.save(); c.rotate(a); c.fillStyle='rgba(120,60,30,.22)'; c.fillRect(60+R()*40,-3,80,4+R()*4); c.restore(); } });
		ell(c,0,0,146,146); c.lineWidth=3; c.strokeStyle='#5c5e60'; c.stroke(); for(let i=0;i<36;i++){ const a=i/36*TAU; ell(c,Math.cos(a)*146,Math.sin(a)*146,1.8,1.8); c.fillStyle='#4a4c4e'; c.fill(); }
		c.save(); c.rotate(.7); c.fillStyle='#5c5e60'; c.fillRect(120,-14,30,28); c.strokeStyle='#3a3c3e'; c.lineWidth=1; for(let y=-12;y<14;y+=4){ c.beginPath(); c.moveTo(122,y); c.lineTo(148,y); c.stroke(); } c.restore();
		vol(c,0,0,22,22,'#7d7f7c',{hi:.35}); vol(c,50,-40,10,10,'#6d6f72',{hi:.35}); vol(c,-60,30,8,8,'#6d6f72',{hi:.35});
		c.save(); c.translate(-40,-70); c.rotate(Math.PI/4); c.fillStyle='rgba(214,190,120,.85)'; c.fillRect(-12,-12,24,24); c.restore(); c.beginPath(); c.moveTo(-40,-82); c.quadraticCurveTo(-30,-70,-40,-58); c.quadraticCurveTo(-50,-70,-40,-82); c.fillStyle='#7a2a1e'; c.fill(); daub(c,70,60,30,8,.6); },
	breakable:{smashSpeed:100000,blastOnly:true,box:[400,400],rim:false,broken(c,R){ const g=c.createRadialGradient(0,0,60,0,0,195); g.addColorStop(0,'rgba(14,12,10,.9)'); g.addColorStop(.75,'rgba(24,20,16,.5)'); g.addColorStop(1,'rgba(24,20,16,0)'); c.fillStyle=g; ell(c,0,0,195,195); c.fill();
		ell(c,0,0,146,146); c.lineWidth=10; c.strokeStyle='#3a3230'; c.stroke(); for(let i=0;i<9;i++){ c.save(); c.rotate(R()*TAU); sheet(c,40+R()*60,0,60+R()*40,40+R()*30,'#4a4440',R,{rib:8,rot:R()}); c.restore(); } for(let i=0;i<20;i++){ const a=R()*TAU, d=R()*130; glowAt(c,Math.cos(a)*d,Math.sin(a)*d,6+R()*8,'#a0461e',.5); } },
		cell:72,debris(c,R,k){ c.beginPath(); c.moveTo(-26,-10); c.quadraticCurveTo(0,-20,26,-8); c.lineTo(20,12); c.quadraticCurveTo(0,4,-22,10); c.closePath(); c.fillStyle=k%2?'#a29d92':'#5a5450'; c.fill(); c.strokeStyle='rgba(20,18,16,.6)'; c.lineWidth=1.2; c.stroke(); }}},
landmark_wild:{cls:'TALL',box:[460,460],n:1,shadow:12,grime:.18,tags:{faction:['wild']},core(c){ ell(c,0,0,120,110); c.fillStyle='#000'; c.fill(); },
	draw(c,R){ for(let i=0;i<9;i++){ const a=i/9*TAU+R()*.2; facetRock(c,Math.cos(a)*190,Math.sin(a)*190,24+R()*8,ROCK,200+i,null,{}); }
		for(let i=0;i<3;i++){ const a=i/3*TAU+.6, x=Math.cos(a)*120, y=Math.sin(a)*120; ell(c,x,y,30,26); c.fillStyle='#4a3826'; c.fill(); for(let k=0;k<26;k++){ const b=R()*TAU; limb(c,[x+Math.cos(b)*14,y+Math.sin(b)*12],[x+Math.cos(b+.8)*28,y+Math.sin(b+.8)*24],2.2,'#7a6046'); } for(let k=0;k<3;k++) vol(c,x+(R()-.5)*14,y+(R()-.5)*12,5,6,'#d6cfbe',{hi:.35}); }
		for(let i=0;i<10;i++){ const a=R()*TAU, d=60+R()*100; bone(c,[Math.cos(a)*d,Math.sin(a)*d],[Math.cos(a)*d+(R()-.5)*30,Math.sin(a)*d+(R()-.5)*30],5); }
		skull(c,0,-10,4.2,Math.PI,{horns:true}); crown(c,0,0,230,.05,.12); },
	beacon(c){ glowAt(c,0,-10,150,'#ffb25a',.42); glowAt(c,0,-10,60,'#ffd08a',.55); for(let i=0;i<3;i++){ const a=i/3*TAU+.6; glowAt(c,Math.cos(a)*120,Math.sin(a)*120,46,'#ff9a48',.5); } }},
landmark_tribe:{cls:'TALL',box:[460,460],n:1,shadow:12,grime:.2,tags:{faction:['tribe']},core(c){ ell(c,0,0,110,110); c.fillStyle='#000'; c.fill(); },
	draw(c,R){ for(let i=0;i<6;i++){ const a=i/6*TAU, x=Math.cos(a)*185, y=Math.sin(a)*185; for(let k=0;k<4;k++) rag(c,x,y,30+R()*10,k/4*TAU+R(),R); vol(c,x,y,16,16,'#6b5034',{hi:.25}); skull(c,x,y,.5,a+Math.PI/2,{}); }
		for(let i=0;i<4;i++){ const a=i/4*TAU+TAU/8, x=Math.cos(a)*140, y=Math.sin(a)*140; vol(c,x,y,20,20,'#4a4440',{hi:.3}); ell(c,x,y,13,13); c.fillStyle='#1a1410'; c.fill(); glowAt(c,x,y,14,'#c8642a',.8); }
		for(const s of [-1,1]){ c.beginPath(); c.moveTo(s*80,-10); c.quadraticCurveTo(s*150,-40,s*168,-96); c.quadraticCurveTo(s*120,-40,s*88,30); c.closePath(); const g=c.createLinearGradient(s*80,0,s*168,-96); g.addColorStop(0,'#7a6c8c'); g.addColorStop(1,'#9a8aa8'); c.fillStyle=g; c.fill(); }
		vol(c,0,0,100,104,'#8f80a0',{hi:.22,lo:-.45}); atop(c,()=>{ for(let i=0;i<60;i++){ c.strokeStyle='rgba(40,30,50,.22)'; c.lineWidth=1.2; const a=R()*TAU, d=R()*96; c.beginPath(); c.moveTo(Math.cos(a)*d,Math.sin(a)*d); c.lineTo(Math.cos(a)*d+(R()-.5)*18,Math.sin(a)*d+(R()-.5)*18); c.stroke(); } });
		ell(c,0,4,84,86); c.lineWidth=14; c.strokeStyle=css(C(RAG),.95); c.stroke(); ell(c,0,4,84,86); c.lineWidth=2; c.strokeStyle='rgba(80,30,10,.5)'; c.stroke(); for(let k=0;k<3;k++) rag(c,-58,58,46,2.0+k*.35,R);
		ell(c,0,-50,40,20); c.fillStyle='rgba(60,40,70,.35)'; c.fill(); for(const s of [-1,1]){ ell(c,s*34,-74,13,9); c.fillStyle='#1a1418'; c.fill(); glowAt(c,s*34,-74,12,'#ffd27a',.9); ell(c,s*34,-74,4,3); c.fillStyle='#fff0c8'; c.fill(); } crown(c,0,0,230,.06,.15); },
	beacon(c){ glowAt(c,0,0,170,'#e0782c',.32); for(const s of [-1,1]){ glowAt(c,s*34,-74,34,'#ffd27a',.85); glowAt(c,s*34,-74,10,'#fff4d8',.9); } for(let i=0;i<4;i++){ const a=i/4*TAU+TAU/8; glowAt(c,Math.cos(a)*140,Math.sin(a)*140,40,'#e8843a',.55); } }},
landmark_scrap:{cls:'TALL',box:[460,460],n:1,shadow:14,grime:.3,tags:{faction:['scrap']},core(c){ ell(c,0,0,120,120); c.fillStyle='#000'; c.fill(); },
	draw(c,R){ for(let i=0;i<14;i++){ const a=i/14*TAU; ring(c,Math.cos(a)*190,Math.sin(a)*190,24,10,R); }
		const cols=['#7a4a32','#5a6068','#806a4a','#3e5466','#6d6a64','#5c5f3a']; for(let k=0;k<5;k++){ c.save(); c.rotate(k*1.1); const sh=-.3+k*.1; c.beginPath(); rr(c,-70+k*3,-120+k*8,140-k*6,240-k*16,22); c.fillStyle=css(shade(C(cols[k]),sh)); c.fill();
			c.fillStyle=css(shade(C('#1c2226'),sh*.5)); c.fillRect(-46,-50+k*6,92,40); c.strokeStyle='rgba(0,0,0,.35)'; c.lineWidth=2; c.beginPath(); c.moveTo(-60,10); c.lineTo(60,30); c.stroke(); rust(c,20,60,40,300+k); c.restore(); }
		limb(c,[0,0],[0,-150],6,'#6d6f72'); c.beginPath(); c.moveTo(0,-150); c.lineTo(56,-138); c.lineTo(48,-124); c.lineTo(0,-128); c.closePath(); c.fillStyle=css(C(TEAL),.9); c.fill(); crown(c,0,0,230,.08,.2); },
	beacon(c){ glowAt(c,0,-150,90,'#5fe0d6',.5); glowAt(c,0,-150,26,'#d8fffb',.95); glowAt(c,0,0,150,'#3fb8b0',.16); }},
/* interactive props (package 14, P-4): Spill (scripts/world/spill.gd) says what comes out of each */
logpile:{cls:'STATEFUL',box:[320,220],n:2,shadow:7,grime:.2,occluder:true,core(c){ c.fillStyle='#000'; c.beginPath(); rr(c,-140,-80,280,160,20); c.fill(); },
	draw(c,R,v){ const L=270, W=50;
		for(let k=0;k<3;k++){ const y=-62+k*62; c.save(); c.translate(0,y); c.beginPath(); rr(c,-L/2,-W/2,L,W,W*.42);
			const g=c.createLinearGradient(0,-W/2,0,W/2); g.addColorStop(0,'#33281c'); g.addColorStop(.42,'#7a5d40'); g.addColorStop(.58,'#6a5036'); g.addColorStop(1,'#2a2017'); c.fillStyle=g; c.fill();
			atop(c,()=>{ for(let i=0;i<10;i++){ const yy=(R()-.5)*W*.9; c.beginPath(); c.moveTo(-L/2,yy); for(let x=-L/2;x<L/2;x+=14) c.lineTo(x,yy+(R()-.5)*3); c.strokeStyle='rgba(26,18,10,.4)'; c.lineWidth=1+R(); c.stroke(); } });
			for(const s2 of [-1,1]){ const ex=s2*(L/2-6); ell(c,ex,0,7,W*.44); c.fillStyle='#a88a5c'; c.fill(); c.strokeStyle='rgba(90,62,36,.6)'; c.lineWidth=.8; for(let q=1;q<4;q++){ ell(c,ex,0,7*q/4,W*.44*q/4); c.stroke(); } }
			c.restore(); }
		for(let k=0;k<2;k++){ const y=-31+k*62; c.save(); c.translate(0,y); c.beginPath(); rr(c,-L/2+20,-W/2,L-40,W,W*.42); const g=c.createLinearGradient(0,-W/2,0,W/2); g.addColorStop(0,'#3d3022'); g.addColorStop(.45,'#86684a'); g.addColorStop(1,'#33281c'); c.fillStyle=g; c.fill(); c.restore(); }
		for(const x of [-80,80]){ c.strokeStyle='#4a4846'; c.lineWidth=5; c.beginPath(); c.moveTo(x,-96); c.lineTo(x+(R()-.5)*6,96); c.stroke(); c.strokeStyle='rgba(200,198,190,.5)'; c.lineWidth=1.4; for(let y=-92;y<96;y+=9){ ell(c,x,y,2.6,3.6); c.stroke(); } }
		for(const x of [-130,130]) for(const y of [-100,100]) vol(c,x,y,8,8,'#6b5034',{hi:.3});
		if(v) rag(c,-120,-90,30,-.6,R); },
	breakable:{smashSpeed:350,box:[340,240],rim:false,broken(c,R){ for(const x of [-130,130]) for(const y of [-100,100]) vol(c,x,y,8,8,'#6b5034',{hi:.3});
		for(let i=0;i<70;i++){ ell(c,(R()-.5)*280,(R()-.5)*190,2+R()*4,1.5+R()*2.5,R()*3); c.fillStyle=R()<.5?'rgba(110,84,52,.85)':'rgba(70,52,34,.8)'; c.fill(); }
		for(const x of [-80,80]){ c.strokeStyle='#4a4846'; c.lineWidth=3; c.beginPath(); c.moveTo(x,-90); c.quadraticCurveTo(x+30,0,x-10,80); c.stroke(); } },
		cell:48,debris(c,R,k){ ell(c,0,0,10+k*2,6,R()*3); c.fillStyle=k%2?'#7a5d40':'#a88a5c'; c.fill(); c.strokeStyle='rgba(40,28,18,.6)'; c.lineWidth=1; c.stroke(); }}},
watertower:{cls:'STATEFUL',box:[280,280],n:2,shadow:11,grime:.25,occluder:true,core(c){ ell(c,0,0,100,100); c.fillStyle='#000'; c.fill(); },
	draw(c,R,v){ for(const a of [.785,2.356,3.927,5.498]){ const x=Math.cos(a)*112, y=Math.sin(a)*112; limb(c,[x*.6,y*.6],[x,y],9,'#5c5e60'); vol(c,x,y,9,9,'#4a4c4e',{hi:.3}); }
		c.strokeStyle='rgba(60,62,64,.8)'; c.lineWidth=2.4; c.beginPath(); for(let i=0;i<4;i++){ const a=.785+i*TAU/4, b=a+TAU/4; c.moveTo(Math.cos(a)*108,Math.sin(a)*108); c.lineTo(Math.cos(b)*108,Math.sin(b)*108); } c.stroke();
		ell(c,0,0,96,96); c.fillStyle='#3a2e24'; c.fill(); const col=v?'#7d6247':'#8a7356';
		for(let i=0;i<36;i++){ const a0=i/36*TAU, a1=(i+1)/36*TAU; c.beginPath(); c.moveTo(0,0); c.arc(0,0,92,a0,a1); c.closePath(); c.fillStyle=css(shade(C(col),(R()-.5)*.16)); c.fill(); }
		for(const r of [92,70]){ ell(c,0,0,r,r); c.lineWidth=3; c.strokeStyle='#4a4c4e'; c.stroke(); }
		c.strokeStyle='rgba(30,22,16,.35)'; c.lineWidth=1; for(let i=0;i<16;i++){ const a=i/16*TAU; c.beginPath(); c.moveTo(Math.cos(a)*14,Math.sin(a)*14); c.lineTo(Math.cos(a)*92,Math.sin(a)*92); c.stroke(); }
		vol(c,0,0,16,16,'#6d6f72',{hi:.35}); crown(c,0,0,100,.12,.3); if(v) daub(c,40,30,22,7,.4); },
	breakable:{smashSpeed:420,box:[420,420],rim:false,broken(c,R){ const g=c.createRadialGradient(0,0,20,0,0,190); g.addColorStop(0,'rgba(30,44,50,.55)'); g.addColorStop(1,'rgba(30,44,50,0)'); c.fillStyle=g; ell(c,0,0,190,190); c.fill();
		for(let i=0;i<22;i++){ c.save(); c.rotate(R()*TAU); plank(c,40+R()*110,0,40+R()*30,12,'#8a7356',R,{rot:R()*3}); c.restore(); }
		for(const a of [.785,2.356,3.927,5.498]){ limb(c,[Math.cos(a)*112,Math.sin(a)*112],[Math.cos(a+.6)*60,Math.sin(a+.6)*60],7,'#5c5e60'); }
		ell(c,20,10,80,40,.4); c.lineWidth=4; c.strokeStyle='#4a4c4e'; c.stroke(); },
		cell:56,debris(c,R,k){ plank(c,0,0,26+k*4,10,'#8a7356',R,{rot:(R()-.5)*.6}); }}},
beehive:{cls:'STATEFUL',box:[120,120],n:4,shadow:4,grime:.15,occluder:false,
	draw(c,R,v){ if(v>=2){ boxHive(c,R,v); return; } c.beginPath(); rr(c,-46,-40,92,80,4); c.fillStyle='#5a4a36'; c.fill(); c.beginPath(); rr(c,-42,-36,84,72,3); c.fillStyle=v?'#cfc6ae':'#d8c48a'; c.fill();
		c.strokeStyle='rgba(60,48,30,.45)'; c.lineWidth=1.2; for(const y of [-12,12]){ c.beginPath(); c.moveTo(-42,y); c.lineTo(42,y); c.stroke(); }
		c.save(); c.translate(6,-4); c.rotate(.2); c.beginPath(); rr(c,-20,-9,40,18,2); c.fillStyle='#8e4a34'; c.fill(); c.restore();
		for(let i=0;i<9;i++){ const a=R()*TAU, d=50+R()*14; ell(c,Math.cos(a)*d,Math.sin(a)*d,2.4,1.6,a); c.fillStyle='#2a2216'; c.fill(); ell(c,Math.cos(a)*d+1,Math.sin(a)*d,1.2,1.2); c.fillStyle='#e0b23c'; c.fill(); } },
	breakable:{smashSpeed:100,box:[180,180],rim:false,broken(c,R){ const g=c.createRadialGradient(0,0,4,0,0,60); g.addColorStop(0,'rgba(214,160,40,.65)'); g.addColorStop(1,'rgba(214,160,40,0)'); c.fillStyle=g; ell(c,0,0,60,60); c.fill();
		for(let i=0;i<6;i++){ c.save(); c.translate((R()-.5)*120,(R()-.5)*120); c.rotate(R()*3); c.fillStyle=R()<.5?'#cfc6ae':'#d8c48a'; c.fillRect(-18,-6,36,12); c.strokeStyle='rgba(60,48,30,.5)'; c.strokeRect(-18,-6,36,12); c.restore(); } },
		cell:40,debris(c,R,k){ c.save(); c.rotate(R()*3); c.fillStyle=k%2?'#cfc6ae':'#d8c48a'; c.fillRect(-12,-5,24,10); c.restore(); }}},
/* ---- Road Atlas props (forest, coast, ghost town, salt flats, volcano, suburbs, the hunting and sprawl overlays,
   three landmarks). Tags name the landscape or region they were made for; the levels' dressing adds the rest. */
ranger_tower:{cls:'TALL',box:[300,300],n:2,shadow:11,grime:.22,tags:{landscape:['forest','forest_snow']},core(c){ c.fillStyle='#000'; c.fillRect(-112,-112,224,224); },
	draw(c,R,v){ for(const sx of [-1,1]) for(const sy of [-1,1]){ limb(c,[sx*62,sy*62],[sx*116,sy*116],9,'#6b5a48'); c.fillStyle='#8a867e'; c.fillRect(sx*116-9,sy*116-9,18,18); }
		c.strokeStyle='#5c4c3c'; c.lineWidth=3.2; c.beginPath(); for(const s of [-1,1]){ c.moveTo(-116,s*116); c.lineTo(116,-s*116*.0+s*116); } c.stroke();
		c.beginPath(); for(const s of [-1,1]){ c.moveTo(-116,s*116); c.lineTo(0,s*70); c.lineTo(116,s*116); c.moveTo(s*116,-116); c.lineTo(s*70,0); c.lineTo(s*116,116); } c.stroke();
		c.save(); c.translate(84,40); for(let k=0;k<6;k++) plank(c,0,k*13,26,10,GREYWOOD,R,{}); c.restore(); limb(c,[72,34],[72,116],3,'#5c4c3c'); limb(c,[96,34],[96,116],3,'#5c4c3c');
		c.beginPath(); rr(c,-80,-80,160,160,3); c.fillStyle='#3a2e24'; c.fill(); for(let k=0;k<10;k++) plank(c,-72+k*16,0,15,156,shade(C(GREYWOOD),(R()-.5)*.16),R,{alongY:true});
		c.strokeStyle='#4a3c30'; c.lineWidth=4; c.strokeRect(-77,-77,154,154); for(let k=0;k<8;k++){ const p=-77+k*22; for(const q of [[p,-77],[p,77],[-77,p],[77,p]]) vol(c,q[0],q[1],3.4,3.4,'#6b5a48',{hi:.3}); }
		hipRoof(c,124,124,v?'#7a4a38':'#5d6a50',R); vol(c,0,0,5,5,'#8d8f8c',{hi:.4}); limb(c,[0,0],[0,-20],2,'#8d8f8c'); crown(c,0,0,170,.06,.2); },
	/* toppled (Spill "fall"): the footings stay, the frame lies along +y and the cab is crushed at its end */
	breakable:{smashSpeed:420,box:[340,760],rim:false,broken(c,R){ for(const sx of [-1,1]) for(const sy of [-1,1]){ c.fillStyle='#8a867e'; c.fillRect(sx*116-9,sy*116-9,18,18); limb(c,[sx*116,sy*116],[sx*(116-14),sy*116+10],8,'#6b5a48'); }
		for(let i=0;i<40;i++){ ell(c,(R()-.5)*300,120+R()*240,2+R()*5,1.4+R()*3,R()*3); c.fillStyle='rgba(120,96,64,.4)'; c.fill(); }
		for(const s of [-1,1]){ limb(c,[s*110,110],[s*80,270],9,'#6b5a48'); limb(c,[s*70,124],[s*56,270],8,'#5c4c3c'); }
		c.strokeStyle='#5c4c3c'; c.lineWidth=3.2; c.beginPath(); for(let k=0;k<3;k++){ const y0=124+k*48, y1=y0+48, w0=106-k*8, w1=w0-8; c.moveTo(-w0,y0); c.lineTo(w1,y1); c.moveTo(w0,y0); c.lineTo(-w1,y1); } c.stroke();
		c.save(); c.translate(6,310); c.rotate(.12); c.beginPath(); c.moveTo(-84,-62); c.lineTo(80,-70); c.lineTo(90,58); c.lineTo(-88,64); c.closePath(); c.fillStyle='#3a2e24'; c.fill();
		for(let k=0;k<9;k++) plank(c,-70+k*17,0,16,120,shade(C(GREYWOOD),(R()-.5)*.16),R,{alongY:true,rot:(R()-.5)*.08}); c.rotate(-.3); hipRoof(c,104,96,'#5d6a50',R,6); c.restore();
		for(let i=0;i<10;i++) plank(c,(R()-.5)*260,200+R()*140,20+R()*40,8,GREYWOOD,R,{rot:R()*3});
		for(let i=0;i<8;i++){ c.save(); c.translate((R()-.5)*220,250+R()*110); c.rotate(R()*3); c.beginPath(); c.moveTo(-6,-4); c.lineTo(7,-6); c.lineTo(3,6); c.closePath(); c.fillStyle='rgba(170,196,206,.75)'; c.fill(); c.restore(); } },
		cell:56,debris(c,R,k){ if(k===0) plank(c,0,0,30,9,GREYWOOD,R,{rot:R()}); else if(k===1) sheet(c,0,0,28,22,'#5d6a50',R,{rot:R()}); else if(k===2) limb(c,[-16,8],[16,-8],5,'#6b5a48'); else { c.beginPath(); c.moveTo(-10,-6); c.lineTo(12,-8); c.lineTo(4,10); c.closePath(); c.fillStyle='rgba(170,196,206,.8)'; c.fill(); } }}},
fallen_trunk:{cls:'STATEFUL',box:[440,180],n:3,shadow:6,grime:.22,occluder:false,tags:{landscape:['forest','forest_snow']},
	breakable:{smashSpeed:300,box:[480,260],rim:false,broken(c,R){ for(let i=0;i<80;i++){ ell(c,(R()-.5)*420,(R()-.5)*200,2+R()*4,1+R()*2,R()*3); c.fillStyle=R()<.5?'rgba(140,108,70,.6)':'rgba(96,70,44,.55)'; c.fill(); }
		for(const [x0,x1,a] of [[-200,-10,.04],[10,190,-.08]]){ c.save(); c.rotate(a); c.beginPath(); rr(c,x0,-27,x1-x0,54,22); const g=c.createLinearGradient(0,-27,0,27); g.addColorStop(0,'#30241a'); g.addColorStop(.4,'#80634a'); g.addColorStop(.6,'#6c533c'); g.addColorStop(1,'#271d15'); c.fillStyle=g; c.fill();
			for(const xe of [x0===-200?x1:x0]){ c.beginPath(); c.moveTo(xe,-27); for(let k=0;k<=8;k++) c.lineTo(xe+(x0===-200?1:-1)*(4+R()*14),-27+k*6.75); c.lineTo(xe,27); c.fillStyle='#b08a5c'; c.fill(); } c.restore(); }
		for(let i=0;i<8;i++) limb(c,[(R()-.5)*380,(R()-.5)*40],[(R()-.5)*420,(R()-.5)*160],3+R()*3,'#5a4836'); },
		cell:48,debris(c,R,k){ if(k===0) vol(c,0,0,12,7,'#5a4836',{hi:.25,lo:-.4,rot:R()}); else if(k===1){ c.save(); c.rotate(R()*3); c.beginPath(); c.moveTo(-14,-2); c.lineTo(14,-4); c.lineTo(12,3); c.lineTo(-12,3); c.closePath(); c.fillStyle='#b08a5c'; c.fill(); c.restore(); } else if(k===2) needles(c,R); else limb(c,[-12,6],[12,-6],3,'#5a4836'); }},
	draw(c,R,v){ if(v===2){ leaningTrunk(c,R); return; } const L=v?330:360, x0=-180, W0=v?52:60, W1=34;
		for(let i=0;i<7;i++){ const x=x0+40+i*44+R()*16, s=i%2?1:-1, l=16+R()*20; limb(c,[x,s*W0*.3],[x+10+R()*10,s*(W0*.45+l)],5+R()*3,'#5a4836'); }
		c.beginPath(); c.moveTo(x0,-W0/2); c.quadraticCurveTo(x0+L*.5,-W0*.45,x0+L,-W1/2); c.lineTo(x0+L,W1/2); c.quadraticCurveTo(x0+L*.5,W0*.45,x0,W0/2); c.closePath();
		const g=c.createLinearGradient(0,-W0/2,0,W0/2); g.addColorStop(0,'#30241a'); g.addColorStop(.4,'#80634a'); g.addColorStop(.6,'#6c533c'); g.addColorStop(1,'#271d15'); c.fillStyle=g; c.fill();
		atop(c,()=>{ for(let i=0;i<22;i++){ const y=(R()-.5)*W0*.9; c.beginPath(); c.moveTo(x0,y); for(let x=x0;x<x0+L;x+=12) c.lineTo(x,y*(1-(x-x0)/L*.4)+(R()-.5)*3); c.strokeStyle='rgba(26,18,10,.42)'; c.lineWidth=1+R()*1.4; c.stroke(); }
			for(let i=0;i<4;i++){ ell(c,x0+R()*L,(R()-.5)*W0*.5,10+R()*18,5+R()*7); c.fillStyle='rgba(96,110,58,.32)'; c.fill(); } });
		if(v===0){ c.save(); c.translate(x0-8,0); ell(c,0,0,30,86); c.fillStyle='#3a2c20'; c.fill(); vol(c,0,0,26,80,'#5a4836',{hi:.12,lo:-.45});
			for(let i=0;i<26;i++){ const a=R()*TAU, d=R()*.8; limb(c,[Math.cos(a)*22*d,Math.sin(a)*72*d],[Math.cos(a)*30+(R()-.5)*20,Math.sin(a)*(80+R()*16)],2.4+R()*2.6,'#6a5440'); }
			for(let i=0;i<9;i++) stone(c,(R()-.5)*30,(R()-.5)*120,5+R()*6,R); c.restore(); }
		else { c.save(); c.translate(x0,0); c.beginPath(); c.moveTo(0,-W0/2); for(let k=0;k<=8;k++) c.lineTo(-6-R()*16,-W0/2+k*W0/8); c.lineTo(0,W0/2); c.closePath(); c.fillStyle='#b08a5c'; c.fill(); c.strokeStyle='rgba(70,48,28,.6)'; c.lineWidth=1; c.stroke(); c.restore();
			for(let i=0;i<4;i++){ const x=x0+L*(.55+R()*.4); for(let k=0;k<5;k++){ const a=R()*TAU; c.beginPath(); c.moveTo(x,0); c.lineTo(x+Math.cos(a)*14,Math.sin(a)*14+(R()-.5)*W0); c.strokeStyle='rgba(120,90,56,.7)'; c.lineWidth=1.4; c.stroke(); } } }
		c.save(); c.translate(x0+L-2,0); ell(c,0,0,5,W1*.46); c.fillStyle='#a88a5c'; c.fill(); c.strokeStyle='rgba(90,62,36,.6)'; c.lineWidth=.8; for(let k=1;k<4;k++){ ell(c,0,0,5*k/4,W1*.46*k/4); c.stroke(); } c.restore(); }},
/* a snow-laden pine: the pine's ground layer and tiers, its crown heavy with snow */
pine_snow:{cls:'TALL',box:[230,230],n:3,shadow:9,grime:.06,tags:{landscape:['forest_snow']},core(c){ ell(c,0,0,36,36); c.fillStyle='#000'; c.fill(); },
	draw(c,R,v){ trunk(c,R,22,'#5e4a3a',{roots:5,reach:48}); },
	litter(c,R,v){ litter(c,R,90,['rgba(110,84,52,.45)','rgba(80,64,44,.4)'],120,true); for(let i=0;i<26;i++){ const a=R()*TAU, d=60+R()*40; ell(c,Math.cos(a)*d,Math.sin(a)*d,5+R()*9,4+R()*6,R()*3); c.fillStyle='rgba(222,228,234,.7)'; c.fill(); } },
	leaves(c,R,k){ if(k<3) snowClump(c,R,k+1); else needles(c,R); },
	canopy(c,R,v){ const r=94+v*7; pineTiers(c,R,r,['#3a4c34','#43553a','#4b5c40']);
		atop(c,()=>{ for(let k=0;k<4;k++){ const rk=r*(1-k*.22), n=10+k*2; for(let i=0;i<n;i++){ const a=i/n*TAU+R()*.4+k*.45, d=rk*(.3+R()*.42); ell(c,Math.cos(a)*d,Math.sin(a)*d,rk*(.1+R()*.07),rk*(.06+R()*.04),a); c.fillStyle='rgba(222,228,234,.88)'; c.fill(); } }
			snowCover(c,-r,-r,r*2,r*2,.28+v*.08,331+v); for(let i=0;i<40;i++){ const a=R()*TAU, d=R()*r; ell(c,Math.cos(a)*d,Math.sin(a)*d,1.5+R()*2,1+R()*1.4); c.fillStyle='rgba(120,134,156,.3)'; c.fill(); } });
		vol(c,0,0,r*.12,r*.12,'#e4e8ec',{hi:.2,lo:-.2}); crown(c,0,0,r,.06,.32); }},
palm:{cls:'TALL',box:[310,310],n:3,shadow:9,grime:.08,tags:{landscape:['coast']},core(c){ ell(c,0,0,22,22); c.fillStyle='#000'; c.fill(); },
	draw(c,R,v){ for(let i=0;i<14;i++){ const a=i/14*TAU+R()*.3; limb(c,[Math.cos(a)*12,Math.sin(a)*12],[Math.cos(a)*(24+R()*8),Math.sin(a)*(24+R()*8)],3,'#5e4e3c'); }
		vol(c,0,0,18,18,'#7a6a54',{hi:.25,lo:-.45}); c.strokeStyle='rgba(50,38,26,.55)'; c.lineWidth=1.2; for(let k=0;k<3;k++){ ell(c,0,0,5+k*4.5,5+k*4.5); c.stroke(); } },
	litter(c,R,v){ for(let i=0;i<2;i++){ c.save(); c.rotate(R()*TAU); c.translate(40+R()*30,0); frond(c,R,0,90+R()*30,['#8a7650','#7a6844','#9a8458'],.15); c.restore(); }
		for(let i=0;i<2+v;i++){ const a=R()*TAU, d=30+R()*60; vol(c,Math.cos(a)*d,Math.sin(a)*d,7,6.5,'#5e4a32',{hi:.3,lo:-.4}); } },
	leaves(c,R,k){ if(k<3){ c.rotate(k*.9); frondBit(c,R,['#5f7a3c','#6b8444','#56703a'][k]); } else { c.rotate(.6); frondBit(c,R,'#8a7650'); } },
	canopy(c,R,v){ const n=9+v, len=124+v*8; for(let i=0;i<3;i++){ c.save(); c.rotate(R()*TAU); frond(c,R,0,len*.8,['#7a6a46','#6e5e3e','#86744c'],.3); c.restore(); }
		for(let i=0;i<n;i++){ c.save(); c.rotate(i/n*TAU+R()*.3); frond(c,R,(R()-.5)*.6,len*(.85+R()*.2),[['#56703a','#5f7a3c','#4c6534'],['#5a7038','#647c40','#506634'],['#5e7440','#6a8048','#526a38']][v],.35); c.restore(); }
		for(let i=0;i<5;i++){ const a=i/5*TAU+R()*.4; vol(c,Math.cos(a)*11,Math.sin(a)*11,7.5,7,'#6b5a36',{hi:.3,lo:-.45}); } vol(c,0,0,9,9,'#7a8a48',{hi:.3});
		crown(c,0,0,len,.06,.3); }},
beach_hut:{cls:'TALL',box:[250,240],n:2,shadow:9,grime:.2,tags:{landscape:['coast']},core(c){ c.fillStyle='#000'; c.fillRect(-104,-84,208,168); },
	draw(c,R,v){ c.save(); c.translate(0,98); for(let k=0;k<7;k++) plank(c,-90+k*30,0,29,26,GREYWOOD,R,{alongY:true}); c.restore();
		if(v===0){ c.beginPath(); rr(c,-104,-84,208,168,3); c.fillStyle='#2a221c'; c.fill(); const cols=['#7e8f96','#c4baa2'];
			for(const s of [-1,1]){ c.save(); c.beginPath(); c.rect(-102,s<0?-82:0,204,82); c.clip(); for(let k=0;k<13;k++) plank(c,-96+k*16,s*41,15,82,shade(C(cols[k%2]),(R()-.5)*.1),R,{alongY:true});
				const g=c.createLinearGradient(0,0,0,s*82); g.addColorStop(0,'rgba(255,250,235,.1)'); g.addColorStop(1,'rgba('+AO+',.28)'); c.fillStyle=g; c.fillRect(-104,s<0?-84:0,208,84); c.restore(); }
			plank(c,0,0,212,10,'#8a7d6c',R,{nails:true}); c.save(); c.translate(40,104); c.rotate(.15); vol(c,0,0,44,11,'#b8946a',{hi:.3}); c.fillStyle='rgba(120,60,40,.6)'; c.fillRect(-40,-1.5,80,3); c.restore(); }
		else { ell(c,0,0,112,112); c.fillStyle='#4a3a26'; c.fill(); for(let ring=0;ring<6;ring++){ const r0=108-ring*18; for(let i=0;i<Math.round(r0*1.6);i++){ const a=R()*TAU, l=10+R()*12; c.beginPath(); c.moveTo(Math.cos(a)*(r0-l),Math.sin(a)*(r0-l)); c.lineTo(Math.cos(a+(R()-.5)*.05)*r0,Math.sin(a)*r0); c.lineWidth=2+R(); c.strokeStyle=css(shade(C(R()<.5?'#a8925c':'#94804e'),-ring*.02+(R()-.5)*.1)); c.stroke(); }
				ell(c,0,0,r0-14,r0-14); c.strokeStyle='rgba(40,28,14,.25)'; c.lineWidth=2; c.stroke(); } vol(c,0,0,12,12,'#7a6440',{hi:.3}); for(let i=0;i<6;i++) limb(c,[0,0],[Math.cos(i)*16,Math.sin(i)*16],2,'#5a4a30'); }
		crown(c,0,0,140,.06,.2); }},
lifeguard_tower:{cls:'TALL',box:[230,300],n:2,shadow:9,grime:.2,tags:{landscape:['coast']},core(c){ c.fillStyle='#000'; c.fillRect(-70,-80,140,140); },
	draw(c,R,v){ for(const sx of [-1,1]) for(const sy of [-1,1]) limb(c,[sx*44,sy*44-10],[sx*66,sy*66-10],7,'#8a7d6c');
		c.save(); c.translate(0,54); for(let k=0;k<11;k++) plank(c,0,k*8,40,7,GREYWOOD,R,{}); for(const s of [-1,1]) limb(c,[s*21,0],[s*21,88],3,'#6d6f72'); c.restore();
		c.beginPath(); rr(c,-62,-72,124,124,3); c.fillStyle='#3a2e24'; c.fill(); for(let k=0;k<8;k++) plank(c,-55+k*15.7,-10,15,120,GREYWOOD,R,{alongY:true});
		c.strokeStyle='#d4cfc2'; c.lineWidth=3; c.strokeRect(-58,-68,116,116); hipRoof(c,92,84,v?'#6f8290':'#8e4a3a',R,-14);
		ring(c,54,30,11,6,R,'#c86a30'); limb(c,[-50,-60],[-50,-96],2.2,'#8d8f8c'); rag(c,-50,-96,30,-.3,R,v?'#c8b848':RAG); crown(c,0,-10,120,.06,.2); }},
wagon:{cls:'STATEFUL',box:[190,350],n:2,shadow:7,grime:.3,occluder:true,tags:{landscape:['ghosttown']},core(c){ c.fillStyle='#000'; c.fillRect(-72,-112,144,236); },
	draw(c,R,v){ limb(c,[0,-110],[0,-168],6,'#5c4632'); limb(c,[-26,-160],[26,-160],5,'#5c4632');
		for(const [y,r] of [[-74,26],[78,32]]) for(const s of [-1,1]){ c.save(); c.translate(s*66,y); c.beginPath(); rr(c,-6,-r,12,r*2,4); c.fillStyle='#2a221a'; c.fill(); c.strokeStyle='#6b6a66'; c.lineWidth=2.4; c.stroke(); c.restore(); }
		c.beginPath(); rr(c,-60,-108,120,228,4); c.fillStyle='#3a2c20'; c.fill(); for(let k=0;k<6;k++) plank(c,-50+k*20,6,19,224,WOOD,R,{alongY:true,nails:true});
		if(v===0){ c.beginPath(); rr(c,-70,-96,140,200,30); const g=c.createLinearGradient(-70,0,70,0); g.addColorStop(0,'#8f8670'); g.addColorStop(.3,'#cbc1a2'); g.addColorStop(.5,'#d6ccae'); g.addColorStop(.7,'#cbc1a2'); g.addColorStop(1,'#8a8068'); c.fillStyle=g; c.fill();
			atop(c,()=>{ for(let k=0;k<6;k++){ const y=-80+k*34; c.beginPath(); c.moveTo(-70,y); c.quadraticCurveTo(0,y-6,70,y); c.lineWidth=3; c.strokeStyle='rgba(90,76,54,.45)'; c.stroke(); }
				for(let i=0;i<10;i++){ c.beginPath(); const y=-90+R()*180; c.moveTo(-70,y); c.quadraticCurveTo(-30,y+(R()-.5)*10,-10,y+4); c.lineWidth=1; c.strokeStyle='rgba(100,88,64,.3)'; c.stroke(); }
				c.fillStyle='rgba(150,130,96,.5)'; c.fillRect(10,10,26,22); rust(c,-30,60,30,412); }); plank(c,0,-110,100,14,WOOD,R,{nails:true}); }
		else { for(let i=0;i<3;i++){ c.save(); c.translate((R()-.5)*60,-70+i*56); c.rotate((R()-.5)*.4); c.beginPath(); rr(c,-22,-20,44,40,3); c.fillStyle='#6e5438'; c.fill(); plank(c,0,0,46,10,'#8a6a44',R,{rot:.6}); c.restore(); }
			vol(c,30,70,20,20,'#6b4e32',{hi:.25}); c.strokeStyle='#4a4c4e'; c.lineWidth=2; ell(c,30,70,17,17); c.stroke(); vol(c,-24,74,18,14,'#a8986c',{hi:.2,lo:-.35}); plank(c,0,-106,100,14,WOOD,R,{nails:true}); }
		crown(c,0,0,180,.06,.2); },
	breakable:{smashSpeed:380,box:[300,380],rim:false,broken(c,R){ for(let i=0;i<9;i++) plank(c,(R()-.5)*200,(R()-.5)*280,60+R()*90,18,WOOD,R,{rot:R()*3,nails:R()<.5});
		c.save(); c.translate(40,-60); c.rotate(R()*3); c.beginPath(); c.moveTo(-60,-40); for(let k=0;k<10;k++) c.lineTo(-60+k*13+(R()-.5)*8,-40+(R()-.5)*18); c.lineTo(70,50); for(let k=0;k<10;k++) c.lineTo(70-k*13,50+(R()-.5)*16); c.closePath(); c.fillStyle='#bfb496'; c.fill(); c.strokeStyle='rgba(90,76,54,.5)'; c.lineWidth=1.4; c.stroke(); c.restore();
		wheel(c,-60,90,32,R); for(let i=0;i<8;i++) plank(c,(R()-.5)*240,(R()-.5)*320,8+R()*16,4,'#6e5438',R,{rot:R()*3}); },
		cell:56,debris(c,R,k){ if(k===1) wheel(c,0,0,18,R); else if(k===2){ c.beginPath(); c.moveTo(-18,-12); c.lineTo(16,-8); c.lineTo(12,14); c.lineTo(-14,10); c.closePath(); c.fillStyle='#c4ba9c'; c.fill(); } else plank(c,0,0,30+k*4,10,WOOD,R,{rot:(R()-.5)*.6,nails:true}); }}},
water_trough:{cls:'STATEFUL',box:[200,100],n:2,shadow:4,grime:.25,occluder:false,tags:{landscape:['ghosttown']},
	draw(c,R,v){ if(v===0){ c.beginPath(); rr(c,-86,-34,172,68,4); c.fillStyle='#3a2c20'; c.fill(); for(const s of [-1,1]){ plank(c,0,s*29,172,11,WOOD,R,{nails:true}); plank(c,s*80,0,11,58,WOOD,R,{alongY:true}); } }
		else { c.beginPath(); rr(c,-86,-32,172,64,30); const g=c.createLinearGradient(0,-32,0,32); g.addColorStop(0,'#6d6f72'); g.addColorStop(.5,'#9a9c9a'); g.addColorStop(1,'#606264'); c.fillStyle=g; c.fill(); rust(c,-50,20,22,421); rust(c,60,-18,16,422); }
		c.beginPath(); rr(c,-74,-22,148,44,v?20:2); const w=c.createLinearGradient(0,-22,0,22); w.addColorStop(0,'#1f3540'); w.addColorStop(.5,'#2f5260'); w.addColorStop(1,'#223a46'); c.fillStyle=w; c.fill();
		atop(c,()=>{ c.strokeStyle='rgba(150,184,190,.35)'; c.lineWidth=1.2; for(let k=0;k<3;k++){ c.beginPath(); const x=-50+k*40; c.moveTo(x,-8); c.quadraticCurveTo(x+12,-11,x+24,-8); c.stroke(); }
			for(let i=0;i<5;i++){ ell(c,-60+R()*120,(R()-.5)*30,3+R()*3,2,R()*3); c.fillStyle=R()<.5?'rgba(110,120,60,.7)':'rgba(130,96,52,.7)'; c.fill(); } }); },
	breakable:{smashSpeed:220,box:[260,180],rim:false,broken(c,R){ const g=c.createRadialGradient(0,0,10,0,0,120); g.addColorStop(0,'rgba(24,36,42,.55)'); g.addColorStop(1,'rgba(24,36,42,0)'); c.fillStyle=g; ell(c,0,0,120,74); c.fill();
		for(let i=0;i<6;i++) plank(c,(R()-.5)*150,(R()-.5)*90,40+R()*60,11,WOOD,R,{rot:R()*3,nails:true}); for(let i=0;i<12;i++){ ell(c,(R()-.5)*200,(R()-.5)*120,3+R()*6,2+R()*4,R()*3); c.fillStyle='rgba(60,92,104,.45)'; c.fill(); } },
		cell:48,debris(c,R,k){ if(k%2) plank(c,0,0,28+k*3,10,WOOD,R,{rot:(R()-.5)*.6,nails:true}); else { ell(c,0,0,8+k*2,6+k,R()); c.fillStyle='rgba(120,160,176,.7)'; c.fill(); ell(c,-2,-2,3,2); c.fillStyle='rgba(220,236,240,.6)'; c.fill(); } }}},
mile_marker:{cls:'LOW',box:[90,60],n:2,shadow:3,grime:.2,tags:{landscape:['saltflats']},draw(c,R,v){
	if(v===0){ c.beginPath(); rr(c,-20,-20,40,40,2); c.fillStyle='#8a867e'; c.fill(); for(const [a,b,col] of [[[-17,-17],[17,-17],'#c4c0b4'],[[17,-17],[17,17],'#a8a49a'],[[17,17],[-17,17],'#9a968c'],[[-17,17],[-17,-17],'#b6b2a6']]){ c.beginPath(); c.moveTo(a[0],a[1]); c.lineTo(b[0],b[1]); c.lineTo(0,0); c.closePath(); c.fillStyle=col; c.fill(); }
		c.fillStyle='rgba(40,38,34,.75)'; c.fillRect(-12,22,7,9); c.fillRect(-2,22,7,9); c.fillRect(8,22,3,9); }
	else { for(const s of [-1,1]) vol(c,s*26,0,4,4,'#6d6f72',{hi:.35}); c.beginPath(); rr(c,-36,-5,72,10,2); c.fillStyle='#4a5c4c'; c.fill(); c.fillStyle='rgba(214,210,198,.8)'; c.fillRect(-36,-5,72,2); c.fillStyle='rgba(214,190,120,.85)'; c.fillRect(-6,-5,12,2); } }},
salt_mound:{cls:'TALL',box:[240,220],n:3,shadow:8,grime:.05,tags:{landscape:['saltflats']},draw(c,R,v){
	const humps=v===2?[[-40,10,74],[48,-12,62]]:[[0,0,92-v*12]];
	for(const [x,y,r] of humps){ c.beginPath(); for(let i=0;i<28;i++){ const a=i/28*TAU, k=.9+.16*fbm(Math.cos(a)*2+x,Math.sin(a)*2+y,520+v,3); c.lineTo(x+Math.cos(a)*r*1.1*k,y+Math.sin(a)*r*k); } c.closePath(); const g=c.createRadialGradient(x,y,2,x,y,r*1.1); g.addColorStop(0,'#dcd8ce'); g.addColorStop(.6,'#c4bfb2'); g.addColorStop(1,'#9c968a'); c.fillStyle=g; c.fill(); }
	atop(c,()=>{ for(const [x,y,r] of humps) for(let i=0;i<34;i++){ const a=R()*TAU, d0=r*(.1+R()*.3); c.beginPath(); c.moveTo(x+Math.cos(a)*d0,y+Math.sin(a)*d0); c.lineTo(x+Math.cos(a+(R()-.5)*.1)*r*1.1,y+Math.sin(a)*r); c.lineWidth=1+R()*1.6; c.strokeStyle=R()<.6?'rgba(120,112,98,.25)':'rgba(240,238,232,.35)'; c.stroke(); }
		for(let i=0;i<10;i++){ ell(c,(R()-.5)*160,(R()-.5)*140,6+R()*12,4+R()*8,R()*3); c.fillStyle='rgba(150,136,112,.22)'; c.fill(); } });
	if(v===2) crown(c,0,0,150,.1,.2); else crown(c,0,0,100,.14,.22); }},
rock_black:{cls:'TALL',box:[170,150],n:3,shadow:6,grime:.12,tags:{landscape:['volcano']},draw(c,R,v){ const N=9+v, base=[]; for(let i=0;i<N;i++) base.push(.8+R()*.32);
	facetRock(c,0,0,68,['#46413e','#3c3836','#4e3a33'][v],470+v*7,base,{sx:1.06,sy:.94,lichen:false}); if(v===1) facetRock(c,40,24,24,'#4a4542',481,null,{lichen:false});
	atop(c,()=>{ for(let i=0;i<5;i++){ const a=R()*TAU, d=R()*40; c.beginPath(); c.moveTo(Math.cos(a)*d,Math.sin(a)*d); c.lineTo(Math.cos(a)*d+12,Math.sin(a)*d-14); c.lineTo(Math.cos(a)*d+20,Math.sin(a)*d+2); c.closePath(); c.fillStyle='rgba(170,180,190,.16)'; c.fill(); }
		if(v===2) for(let i=0;i<40;i++){ ell(c,(R()-.5)*110,(R()-.5)*100,1+R()*2.4,1+R()*2); c.fillStyle='rgba(16,12,10,.5)'; c.fill(); } });
	crown(c,0,0,74,.12,.22); }},
mailbox:{cls:'STATEFUL',box:[80,50],n:3,shadow:3,grime:.2,occluder:false,tags:{landscape:['suburbs']},
	draw(c,R,v){ c.fillStyle='#5e4a38'; c.fillRect(-7,-7,14,14); const col=C(['#8d8f8c','#46525c','#8a3e2e'][v]); c.beginPath(); rr(c,-30,-12,60,24,5);
		const g=c.createLinearGradient(0,-12,0,12); g.addColorStop(0,css(shade(col,-.35))); g.addColorStop(.45,css(shade(col,.22))); g.addColorStop(1,css(shade(col,-.4))); c.fillStyle=g; c.fill();
		c.fillStyle=css(shade(col,-.25)); c.fillRect(25,-12,5,24); c.save(); c.translate(-6,-12); c.fillStyle='#b8452a'; c.fillRect(-2,-11,4,12); c.fillRect(-2,-11,10,4); c.restore(); if(v===0) rust(c,-12,4,8,431); },
	breakable:{smashSpeed:260,box:[150,120],rim:false,broken(c,R){ c.fillStyle='#5e4a38'; c.fillRect(-7,-7,14,14); c.fillStyle='rgba(40,28,18,.8)'; c.fillRect(-5,-5,10,10);
		c.save(); c.translate(26,14); c.rotate(.5); c.beginPath(); c.moveTo(-28,-8); c.lineTo(26,-12); c.lineTo(30,6); c.lineTo(-24,10); c.closePath(); c.fillStyle='#7a7c7a'; c.fill(); c.strokeStyle='rgba(30,28,26,.6)'; c.lineWidth=1; c.stroke(); c.restore();
		for(let i=0;i<7;i++){ c.save(); c.translate((R()-.5)*120,(R()-.5)*90); c.rotate(R()*3); c.fillStyle=R()<.7?'#e2ddd0':'#c8b48a'; c.fillRect(-7,-5,14,10); c.strokeStyle='rgba(60,56,50,.4)'; c.lineWidth=.6; c.strokeRect(-7,-5,14,10); c.restore(); } },
		cell:40,debris(c,R,k){ c.rotate(R()*3); if(k<2){ c.fillStyle='#e2ddd0'; c.fillRect(-10,-7,20,14); c.strokeStyle='rgba(60,56,50,.5)'; c.lineWidth=.8; c.beginPath(); c.moveTo(-10,-7); c.lineTo(0,1); c.lineTo(10,-7); c.stroke(); } else if(k===2){ c.fillStyle='#b8452a'; c.fillRect(-3,-12,6,20); } else { c.fillStyle='#7a7c7a'; c.fillRect(-12,-8,24,16); } }}},
swingset:{cls:'LOW',box:[330,170],n:2,shadow:6,grime:.2,occluder:false,tags:{landscape:['suburbs']},
	draw(c,R,v){ const col=v?'#8a5a3e':'#6f7f86'; for(const s of [-1,1]) for(const t of [-1,1]){ limb(c,[s*142,0],[s*152,t*70],7,col); vol(c,s*152,t*70,5,5,'#6d6f72',{hi:.3}); }
		const seats=v?[-80,-20,50]:[-60,10,70]; seats.forEach((x,i)=>{ c.save(); c.translate(x,(R()-.5)*10); if(v&&i===2){ vol(c,0,0,16,16,'#4a5a6a',{hi:.25}); ell(c,0,0,9,9); c.fillStyle='#1c1e20'; c.fill(); } else { c.beginPath(); rr(c,-17,-6,34,12,4); c.fillStyle='#2e2c2a'; c.fill(); c.strokeStyle='rgba(150,150,146,.5)'; c.lineWidth=1; c.stroke(); } c.restore(); });
		limb(c,[-150,0],[150,0],9,col); for(const s of [-1,1]) vol(c,s*146,0,7,7,shade(C(col),.1),{hi:.3}); if(v){ c.save(); c.translate(130,0); c.rotate(.05); c.beginPath(); rr(c,-8,8,22,120,6); const g=c.createLinearGradient(-8,0,14,0); g.addColorStop(0,'#8a8c8a'); g.addColorStop(.5,'#c4c6c2'); g.addColorStop(1,'#7a7c7a'); c.fillStyle=g; c.fill(); c.restore(); rust(c,-120,0,12,441); } }},
trampoline:{cls:'LOW',box:[230,230],n:2,shadow:6,grime:.12,occluder:false,tags:{landscape:['suburbs']},
	draw(c,R,v){ ell(c,0,0,104,104); c.lineWidth=6; c.strokeStyle='#7d7f7c'; c.stroke(); ell(c,0,0,104,104); c.lineWidth=2; c.strokeStyle='rgba(220,222,216,.35)'; c.stroke();
		ell(c,0,0,100,100); c.lineWidth=18; c.strokeStyle=v?'#5a7048':'#4f6878'; c.stroke(); atop(c,()=>{ for(let i=0;i<24;i++){ const a=i/24*TAU; c.beginPath(); c.moveTo(Math.cos(a)*92,Math.sin(a)*92); c.lineTo(Math.cos(a)*108,Math.sin(a)*108); c.lineWidth=1; c.strokeStyle='rgba(0,0,0,.2)'; c.stroke(); } });
		ell(c,0,0,90,90); c.fillStyle='#1d1c1e'; c.fill(); const g=c.createRadialGradient(0,0,4,0,0,86); g.addColorStop(0,'rgba(110,108,104,.35)'); g.addColorStop(.6,'rgba(60,58,56,.12)'); g.addColorStop(1,'rgba(0,0,0,.25)'); c.fillStyle=g; ell(c,0,0,86,86); c.fill();
		atop(c,()=>{ c.lineWidth=.6; c.strokeStyle='rgba(120,118,112,.18)'; for(let k=-84;k<86;k+=5){ c.beginPath(); c.moveTo(k,-86); c.lineTo(k,86); c.stroke(); c.beginPath(); c.moveTo(-86,k); c.lineTo(86,k); c.stroke(); } });
		if(v){ for(let i=0;i<8;i++){ const a=i/8*TAU; vol(c,Math.cos(a)*110,Math.sin(a)*110,5,5,'#4a4c4e',{hi:.35}); } ell(c,0,0,110,110); c.lineWidth=1; c.strokeStyle='rgba(30,30,30,.4)'; c.setLineDash([2,2]); c.stroke(); c.setLineDash([]); }
		else { for(let i=0;i<4;i++){ ell(c,(R()-.5)*120,(R()-.5)*120,6+R()*6,4+R()*4,R()*3); c.fillStyle='rgba(120,96,60,.35)'; c.fill(); } } }},
hunting_stand:{cls:'TALL',box:[200,220],n:2,shadow:9,grime:.25,tags:{region:['hunting']},core(c){ c.fillStyle='#000'; c.fillRect(-60,-60,120,120); },
	draw(c,R,v){ for(const sx of [-1,1]) for(const sy of [-1,1]) limb(c,[sx*36,sy*36],[sx*80,sy*80],7,v?'#6d6f72':'#6b5a48');
		c.strokeStyle=v?'#5c5e60':'#5c4c3c'; c.lineWidth=2.6; c.beginPath(); for(const s of [-1,1]){ c.moveTo(-80,s*80); c.lineTo(80,s*80); c.moveTo(s*80,-80); c.lineTo(s*80,80); } c.stroke();
		for(const s of [-1,1]) limb(c,[s*12,40],[s*12,104],3.4,'#6b5a48'); for(let y=50;y<104;y+=11) limb(c,[-12,y],[12,y],2.4,'#7a6a54');
		if(v===0){ c.beginPath(); rr(c,-50,-50,100,100,3); c.fillStyle='#5a5a3e'; c.fill(); atop(c,()=>{ for(let i=0;i<26;i++){ ell(c,(R()-.5)*100,(R()-.5)*100,6+R()*14,4+R()*9,R()*3); c.fillStyle=['#4a4a30','#6e6648','#3e3a2c','#5e6a44'][(R()*4)|0]; c.fill(); } });
			const g=c.createLinearGradient(0,-50,0,50); g.addColorStop(0,'rgba('+AO+',.25)'); g.addColorStop(.5,'rgba(255,250,230,.06)'); g.addColorStop(1,'rgba('+AO+',.25)'); c.fillStyle=g; c.fillRect(-50,-50,100,100); plank(c,0,0,104,6,'#5a4a3a',R,{}); }
		else { c.beginPath(); rr(c,-42,-38,84,76,3); c.fillStyle='#3a2e24'; c.fill(); for(let k=0;k<5;k++) plank(c,-34+k*17,0,16,72,WOOD,R,{alongY:true}); limb(c,[-44,-40],[44,-40],5,'#5c5e60'); c.beginPath(); rr(c,-18,-4,36,30,6); c.fillStyle='#4a4a30'; c.fill(); }
		crown(c,0,0,110,.06,.2); }},
trashbags:{cls:'STATEFUL',box:[150,130],n:3,shadow:4,grime:.15,occluder:false,tags:{region:['sprawl']},
	draw(c,R,v){ const bags=[[-30,-14,30],[24,-20,26],[4,22,28],[-40,30,20],[44,22,20]].slice(0,3+v);
		if(v===2){ c.save(); c.translate(36,-36); c.rotate(.3); c.beginPath(); rr(c,-22,-18,44,36,2); c.fillStyle='#8a7050'; c.fill(); c.strokeStyle='rgba(60,44,28,.6)'; c.lineWidth=1.4; c.beginPath(); c.moveTo(-22,0); c.lineTo(22,0); c.stroke(); c.restore(); }
		bags.forEach(([x,y,r],i)=>{ bag(c,R,x,y,r,['#1f2022','#2a2c2e','#3e4a34','#4a4c4e'][(i*7+v)%4]); });
		if(v>0){ vol(c,-58,-4,6,6,'#8d8f8c',{hi:.4}); c.save(); c.translate(56,-6); c.rotate(.7); c.fillStyle='#d8d2c0'; c.fillRect(-7,-5,14,10); c.restore(); } },
	breakable:{smashSpeed:140,box:[230,200],rim:false,broken(c,R){ const g=c.createRadialGradient(0,0,6,0,0,90); g.addColorStop(0,'rgba(40,38,24,.35)'); g.addColorStop(1,'rgba(40,38,24,0)'); c.fillStyle=g; ell(c,0,0,95,80); c.fill();
		for(let i=0;i<4;i++){ c.save(); c.translate((R()-.5)*120,(R()-.5)*90); c.rotate(R()*3); c.beginPath(); c.moveTo(-26,-10); for(let k=0;k<8;k++) c.lineTo(-26+k*7+(R()-.5)*4,-10-R()*8); c.lineTo(28,12); c.lineTo(-20,16); c.closePath(); c.fillStyle='#232426'; c.fill(); c.restore(); }
		for(let i=0;i<22;i++) trash(c,R,(R()-.5)*190,(R()-.5)*150,(R()*5)|0); },
		cell:40,debris(c,R,k){ if(k===0){ c.rotate(R()*3); c.beginPath(); c.moveTo(-14,-8); c.lineTo(12,-10); c.lineTo(14,8); c.lineTo(-10,12); c.closePath(); c.fillStyle='#232426'; c.fill(); } else trash(c,R,0,0,k); }}},
/* the region landmarks (with beacon glows): Hunting Grounds' giant skull cairn, the Sprawl's junk throne, the Works' smokestack */
landmark_big:{cls:'TALL',box:[460,460],n:1,shadow:12,grime:.2,tags:{region:['hunting']},core(c){ ell(c,0,0,128,128); c.fillStyle='#000'; c.fill(); },
	draw(c,R){ for(let i=0;i<4;i++){ const a=i/4*TAU+TAU/8, x=Math.cos(a)*186, y=Math.sin(a)*186; limb(c,[x,y],[x*.92,y*.92],8,'#5c4632'); ell(c,x,y,15,15); c.fillStyle='#3a3430'; c.fill(); ell(c,x,y,10,10); c.fillStyle='#1a1410'; c.fill(); glowAt(c,x,y,10,'#c8642a',.8); }
		for(let i=0;i<12;i++){ const a=R()*TAU, d=150+R()*50; bone(c,[Math.cos(a)*d,Math.sin(a)*d],[Math.cos(a)*d+(R()-.5)*40,Math.sin(a)*d+(R()-.5)*40],5+R()*2); }
		for(let ring=0;ring<4;ring++){ const rad=150-ring*34, n=18-ring*3; for(let i=0;i<n;i++){ const a=i/n*TAU+R()*.3+ring; stone(c,Math.cos(a)*rad,Math.sin(a)*rad,22-ring*2+R()*6,R,shade(C('#7a736a'),-.2+ring*.08)); } }
		c.save(); c.translate(0,-10); for(const s of [-1,1]){ c.beginPath(); c.moveTo(s*30,60); c.bezierCurveTo(s*110,90,s*150,10,s*120,-70); c.bezierCurveTo(s*112,-36,s*96,40,s*20,30); c.closePath();
			const g=c.createLinearGradient(s*30,60,s*120,-70); g.addColorStop(0,'#b8ab8e'); g.addColorStop(1,'#ece4d0'); c.fillStyle=g; c.fill(); c.strokeStyle='rgba(70,58,40,.45)'; c.lineWidth=1.4; c.stroke();
			for(let k=1;k<6;k++){ const t=k/6; c.beginPath(); c.arc(s*(30+90*t),60-70*t,10-t*5,0,TAU); c.strokeStyle='rgba(120,104,80,.25)'; c.stroke(); } }
		c.beginPath(); c.moveTo(-70,-60); c.bezierCurveTo(-96,10,-60,80,-30,120); c.lineTo(30,120); c.bezierCurveTo(60,80,96,10,70,-60); c.bezierCurveTo(40,-110,-40,-110,-70,-60); c.closePath();
		const sg=c.createRadialGradient(0,-20,6,0,10,130); sg.addColorStop(0,'#efe7d4'); sg.addColorStop(.7,'#c9bc9e'); sg.addColorStop(1,'#a89a7c'); c.fillStyle=sg; c.fill(); c.strokeStyle='rgba(60,50,36,.5)'; c.lineWidth=2; c.stroke();
		atop(c,()=>{ c.strokeStyle='rgba(90,76,56,.35)'; c.lineWidth=1.4; c.beginPath(); c.moveTo(0,-96); c.lineTo(0,-30); c.moveTo(-40,-80); c.quadraticCurveTo(-20,-60,-6,-70); c.moveTo(30,-84); c.lineTo(44,-60); c.stroke(); });
		for(const s of [-1,1]){ ell(c,s*36,-6,22,26,s*.3); c.fillStyle='#21180f'; c.fill(); ell(c,s*36,-6,12,14,s*.3); c.fillStyle='#3a1a0e'; c.fill(); }
		c.beginPath(); c.moveTo(-10,50); c.lineTo(0,34); c.lineTo(10,50); c.lineTo(0,62); c.closePath(); c.fillStyle='#2a2018'; c.fill(); for(let k=0;k<7;k++) for(const s of [-1,1]){ vol(c,s*(26-k*.5),70+k*7,4,3.2,'#e4dcc6',{hi:.3}); }
		c.restore(); crown(c,0,0,230,.05,.14); },
	beacon(c){ glowAt(c,0,-16,160,'#e8783a',.3); for(const s of [-1,1]){ glowAt(c,s*36,-16,44,'#ff8a3a',.75); glowAt(c,s*36,-16,12,'#ffd8a0',.9); } for(let i=0;i<4;i++){ const a=i/4*TAU+TAU/8; glowAt(c,Math.cos(a)*186,Math.sin(a)*186,44,'#ff9a48',.55); } }},
landmark_swarm:{cls:'TALL',box:[460,460],n:1,shadow:12,grime:.3,tags:{region:['sprawl']},core(c){ ell(c,0,0,124,124); c.fillStyle='#000'; c.fill(); },
	draw(c,R){ for(let i=0;i<12;i++){ const a=i/12*TAU+R()*.2, d=170+R()*30; if(i%3===0) ring(c,Math.cos(a)*d,Math.sin(a)*d,22,9,R); else bag(c,R,Math.cos(a)*d,Math.sin(a)*d,18+R()*8,['#1f2022','#2a2c2e','#3e4a34'][i%3]); }
		for(let i=0;i<5;i++){ c.save(); c.rotate(i/5*TAU+.3); c.translate(0,104); c.beginPath(); rr(c,-50,-30,100,60,3); c.fillStyle='#5a4632'; c.fill(); for(let k=0;k<5;k++) plank(c,0,-24+k*12,96,10,shade(C(WOOD),-.1),R,{}); c.restore(); }
		for(let i=0;i<18;i++) trash(c,R,(R()-.5)*300,(R()-.5)*300,(R()*5)|0);
		const back=[]; for(let i=0;i<9;i++) back.push([-120+i*30,-96+(R()-.5)*12]); back.forEach((p,i)=>{ if(i%2) ring(c,p[0],p[1]-10,28,12,R); else sheet(c,p[0],p[1],34,64,['#7a4a32','#5a6068','#806a4a','#6d6a64','#5a4a6a'][i%5],R,{rot:(R()-.5)*.3}); });
		for(let i=0;i<9;i++) ring(c,-112+i*28,-132,17,7,R); daub2(c,-80,-118,22,6,'#7a5aa0'); daub2(c,60,-112,18,6,'#7a5aa0');
		for(const s of [-1,1]){ vol(c,s*92,0,30,30,'#5a2a22',{hi:.2}); c.lineWidth=2; c.strokeStyle='rgba(30,14,10,.6)'; ell(c,s*92,0,25,25); c.stroke(); ell(c,s*92,0,20,20); c.fillStyle='#140c08'; c.fill(); glowAt(c,s*92,0,18,'#c8642a',.8); }
		c.beginPath(); rr(c,-64,-60,128,120,18); c.fillStyle='#4a2e3a'; c.fill(); c.beginPath(); rr(c,-58,-54,116,108,14); const g=c.createRadialGradient(0,0,6,0,0,80); g.addColorStop(0,'#86607a'); g.addColorStop(1,'#5a3a4c'); c.fillStyle=g; c.fill();
		c.strokeStyle='rgba(30,16,24,.5)'; c.lineWidth=1.6; c.beginPath(); c.moveTo(0,-54); c.lineTo(0,54); c.stroke(); for(let i=0;i<6;i++){ ell(c,(R()-.5)*90,(R()-.5)*80,2,2); c.fillStyle='rgba(30,16,24,.6)'; c.fill(); } ell(c,30,30,14,9); c.fillStyle='rgba(200,180,150,.6)'; c.fill();
		c.save(); c.translate(0,0); const n=7; c.beginPath(); for(let i=0;i<n*2;i++){ const a=i/(n*2)*TAU, r=i%2?26:40; c.lineTo(Math.cos(a)*r,Math.sin(a)*r); } c.closePath(); const cg=c.createRadialGradient(0,0,4,0,0,40); cg.addColorStop(0,'#f0d080'); cg.addColorStop(.6,'#c89a3c'); cg.addColorStop(1,'#8a6420'); c.fillStyle=cg; c.fill(); c.strokeStyle='rgba(70,48,14,.7)'; c.lineWidth=1.4; c.stroke();
		ell(c,0,0,22,22); c.fillStyle='#5a2a2e'; c.fill(); for(let i=0;i<n;i++){ const a=(i+.5)/n*TAU*1; vol(c,Math.cos(i/n*TAU)*36,Math.sin(i/n*TAU)*36,4,4,i%2?'#7a4aa0':'#4a8a6a',{hi:.5}); } c.restore();
		limb(c,[60,40],[110,110],6,'#8d8f8c'); vol(c,112,112,8,8,'#c89a3c',{hi:.4}); crown(c,0,0,230,.06,.18); },
	beacon(c){ glowAt(c,0,0,90,'#ffd27a',.45); glowAt(c,0,0,26,'#fff0c8',.8); for(const s of [-1,1]) glowAt(c,s*92,0,46,'#ff9a48',.65); for(let i=0;i<9;i++) glowAt(c,-112+i*28,-132,8,i%2?'#d0a0ff':'#ffd27a',.8); }},
landmark_war:{cls:'TALL',box:[460,460],n:1,shadow:14,grime:.32,tags:{region:['works']},core(c){ ell(c,0,0,116,116); c.fillStyle='#000'; c.fill(); },
	draw(c,R){ c.beginPath(); rr(c,-196,-196,392,392,8); c.fillStyle='#6e6a62'; c.fill(); atop(c,()=>{ for(let i=0;i<12;i++){ ell(c,(R()-.5)*380,(R()-.5)*380,20+R()*40,14+R()*30,R()*3); c.fillStyle='rgba(20,16,14,.2)'; c.fill(); } });
		c.save(); c.beginPath(); rr(c,-196,-196,392,392,8); c.lineWidth=10; c.setLineDash([16,16]); c.strokeStyle='rgba(200,170,70,.75)'; c.stroke(); c.setLineDash([]); c.restore();
		for(const [x,y] of [[-150,-120],[150,-140],[-140,150]]) { vol(c,x,y,34,34,'#8a8478',{hi:.25}); c.lineWidth=2; c.strokeStyle='rgba(40,38,34,.5)'; ell(c,x,y,28,28); c.stroke(); limb(c,[x*.6,y*.6],[x*.85,y*.85],9,'#5c5e60'); }
		for(let i=0;i<40;i++){ const a=R()*.8+2.2, d=120+R()*60; vol(c,Math.cos(a)*d,Math.sin(a)*d,5+R()*6,4+R()*5,'#2a2826',{hi:.35}); }
		c.save(); c.translate(120,60); c.beginPath(); rr(c,-46,-36,92,72,4); c.fillStyle='#4a3a32'; c.fill(); c.fillStyle='#1a120e'; c.fillRect(-30,-20,60,40); c.strokeStyle='#6d4a30'; c.lineWidth=3; for(let k=-24;k<30;k+=10){ c.beginPath(); c.moveTo(k,-20); c.lineTo(k,20); c.stroke(); } glowAt(c,0,0,30,'#c8642a',.7); c.restore();
		for(let ring=0;ring<7;ring++){ const r=112-ring*8; ell(c,0,0,r,r); c.fillStyle=css(shade(C('#7a4a38'),(ring%2?-.06:.04)-ring*.02)); c.fill(); }
		atop(c,()=>{ c.strokeStyle='rgba(40,24,18,.45)'; c.lineWidth=1; for(let ring=0;ring<7;ring++){ const r=112-ring*8, n=Math.round(r/4.5); for(let i=0;i<n;i++){ const a=(i+(ring%2)*.5)/n*TAU; c.beginPath(); c.moveTo(Math.cos(a)*(r-8),Math.sin(a)*(r-8)); c.lineTo(Math.cos(a)*r,Math.sin(a)*r); c.stroke(); } ell(c,0,0,r,r); c.stroke(); } });
		for(const r of [104,80]){ ell(c,0,0,r,r); c.lineWidth=3.4; c.strokeStyle='#4a4c4e'; c.stroke(); }
		ell(c,0,0,56,56); c.fillStyle='#120c0a'; c.fill(); const g=c.createRadialGradient(0,0,4,0,0,56); g.addColorStop(0,'rgba(140,40,16,.85)'); g.addColorStop(.55,'rgba(70,20,10,.6)'); g.addColorStop(1,'rgba(20,12,10,0)'); c.fillStyle=g; ell(c,0,0,56,56); c.fill();
		ell(c,0,0,60,60); c.lineWidth=6; c.strokeStyle='rgba(20,16,14,.8)'; c.stroke();
		for(let k=0;k<9;k++){ const y=-50+k*12; limb(c,[-116,y],[-104,y],2,'#8d8f8c'); } limb(c,[-110,-56],[-110,56],1.6,'#8d8f8c');
		for(const s of [-1,1]) vol(c,s*96,s*30,5,5,'#5a2a22',{hi:.4}); crown(c,0,0,230,.06,.16); },
	beacon(c){ glowAt(c,0,0,140,'#d8602a',.42); glowAt(c,0,0,56,'#ffa060',.7); glowAt(c,0,0,18,'#ffe0b0',.8); glowAt(c,120,60,60,'#ff8a3a',.6); for(const s of [-1,1]){ glowAt(c,s*96,s*30,20,'#ff5040',.85); glowAt(c,s*96,s*30,5,'#ffd0c0',.9); } }},
/* ---- Region 1 (The Wilds) props (docs/WORLD_ART.md "Region 1 props") ---- */
den:{cls:'STATEFUL',box:[210,190],n:2,shadow:7,grime:.3,occluder:true,tags:{region:['wilds']},core(c){ ell(c,0,0,80,70); c.fillStyle='#000'; c.fill(); },
	draw(c,R,v){ ell(c,0,46,66,40); c.fillStyle='rgba(92,72,50,.55)'; c.fill(); for(let i=0;i<14;i++){ ell(c,(R()-.5)*110,40+(R()-.5)*50,2+R()*3,1.4+R()*2,R()*3); c.fillStyle='rgba(70,54,38,.6)'; c.fill(); }
		if(v===0){ ell(c,0,-4,80,70); c.fillStyle='#33281e'; c.fill();
			for(let i=0;i<80;i++){ const a=R()*TAU, r0=R()*26, r1=58+R()*22; limb(c,[Math.cos(a)*r0,Math.sin(a)*r0*.88-4],[Math.cos(a+(R()-.5)*.3)*r1,Math.sin(a+(R()-.5)*.3)*r1*.88-4],2+R()*2.4,R()<.5?'#7a6448':'#5e4a38'); }
			sheet(c,-30,-26,46,34,'#6d6a64',R,{rot:.3}); sheet(c,34,8,40,30,'#7a4a32',R,{rot:-.4}); ring(c,6,-12,19,8,R); rag(c,-52,-30,30,-2.2,R,'#8a7a5a');
			ell(c,0,56,24,15); c.fillStyle='#120e0c'; c.fill(); }
		else { c.beginPath(); c.moveTo(-82,-58); c.lineTo(76,-64); c.lineTo(84,50); c.lineTo(-78,58); c.closePath(); c.fillStyle='#2e2620'; c.fill();
			c.beginPath(); c.moveTo(-76,-54); c.quadraticCurveTo(0,-70,70,-58); c.lineTo(78,30); c.quadraticCurveTo(0,44,-72,36); c.closePath(); const g=c.createLinearGradient(0,-60,0,40); g.addColorStop(0,'#4e5a64'); g.addColorStop(.5,'#64707a'); g.addColorStop(1,'#46505a'); c.fillStyle=g; c.fill();
			atop(c,()=>{ for(let i=0;i<9;i++){ c.beginPath(); const x=-70+i*17+(R()-.5)*6; c.moveTo(x,-60); c.quadraticCurveTo(x+(R()-.5)*14,-10,x+(R()-.5)*10,40); c.lineWidth=2; c.strokeStyle=i%2?'rgba(20,26,32,.3)':'rgba(200,210,220,.12)'; c.stroke(); } });
			for(const [x,y] of [[-60,-40],[56,-46],[60,20],[-56,22]]) ring(c,x,y,13,5,R); plank(c,-10,-6,120,10,GREYWOOD,R,{rot:.1}); c.save(); c.translate(30,48); c.beginPath(); rr(c,-26,-14,52,28,2); c.fillStyle='#6e5438'; c.fill(); c.restore();
			c.beginPath(); rr(c,-22,44,30,16,3); c.fillStyle='#120e0c'; c.fill(); }
		crown(c,0,-4,100,.06,.22); },
	overlay:{name:'sacks',frames:4,draw(c,R,k){ const spots=[[-42,34,1],[44,30,.9],[2,-30,1.1]]; for(let i=0;i<k;i++) sack(c,R,spots[i][0],spots[i][1],spots[i][2]); }},
	breakable:{smashSpeed:250,box:[300,260],rim:false,broken(c,R){ for(let i=0;i<70;i++){ const x=(R()-.5)*230, y=(R()-.5)*170, a=R()*TAU, l=10+R()*26; limb(c,[x,y],[x+Math.cos(a)*l,y+Math.sin(a)*l],1.6+R()*2,R()<.5?'#7a6448':'#5e4a38'); }
		sheet(c,-50,30,44,32,'#6d6a64',R,{rot:R()*3}); sheet(c,60,-30,40,28,'#7a4a32',R,{rot:R()*3}); ring(c,-70,-40,19,8,R);
		c.save(); c.translate(30,40); c.rotate(.6); c.beginPath(); c.moveTo(-40,-20); c.lineTo(30,-28); c.lineTo(44,14); c.lineTo(-30,24); c.closePath(); c.fillStyle='#56626c'; c.fill(); c.restore(); },
		cell:48,debris(c,R,k){ if(k===0){ for(let i=0;i<5;i++) limb(c,[(R()-.5)*20,(R()-.5)*20],[(R()-.5)*30,(R()-.5)*30],2.2,'#7a6448'); } else if(k===1) sheet(c,0,0,28,20,'#6d6a64',R,{rot:R()}); else if(k===2){ c.beginPath(); c.moveTo(-14,-8); c.lineTo(12,-12); c.lineTo(14,10); c.lineTo(-10,12); c.closePath(); c.fillStyle='#a08a5c'; c.fill(); } else ring(c,0,0,14,6,R); }}},
burrow:{cls:'STATEFUL',box:[140,120],n:2,shadow:3,grime:.2,occluder:false,tags:{region:['wilds']},core(c){ ell(c,0,0,42,34); c.fillStyle='#000'; c.fill(); },
	draw(c,R,v){ for(let i=0;i<46;i++){ const a=R()*TAU, d=42+R()*24; ell(c,Math.cos(a)*d,Math.sin(a)*d*.85,1.6+R()*3,1.2+R()*2,R()*3); c.fillStyle=R()<.5?'rgba(116,90,62,.85)':'rgba(84,64,44,.8)'; c.fill(); }
		vol(c,0,0,50,42,'#7a5e42',{hi:.24,lo:-.42}); speckle(c,R,60,46,38,['rgba(60,44,30,.5)','rgba(160,130,96,.4)'],1.6);
		c.lineCap='round'; for(let i=0;i<9;i++){ const a=R()*TAU; c.beginPath(); c.moveTo(Math.cos(a)*44,Math.sin(a)*37); c.lineTo(Math.cos(a)*(52+R()*8),Math.sin(a)*(44+R()*8)); c.lineWidth=1.4; c.strokeStyle='#66773f'; c.stroke(); }
		const holes=v?[[-14,8,15,12],[22,-14,10,8]]:[[8,-4,18,14]];
		for(const [x,y,rx,ry] of holes){ ell(c,x,y,rx+4,ry+3.5); c.fillStyle='rgba(176,146,104,.55)'; c.fill(); ell(c,x,y,rx,ry); const g=c.createRadialGradient(x,y,1,x,y,rx); g.addColorStop(0,'#0c0806'); g.addColorStop(.7,'#1a120c'); g.addColorStop(1,'#3a2a1c'); c.fillStyle=g; c.fill(); }
		if(v) bone(c,[30,24],[48,14],3.4); },
	breakable:{smashSpeed:120,box:[180,150],rim:false,broken(c,R){ ell(c,0,0,64,52); c.fillStyle='rgba(104,80,56,.75)'; c.fill(); ell(c,4,-2,30,24); const g=c.createRadialGradient(4,-2,2,4,-2,30); g.addColorStop(0,'rgba(40,28,18,.7)'); g.addColorStop(1,'rgba(40,28,18,0)'); c.fillStyle=g; c.fill();
		for(let i=0;i<40;i++){ const a=R()*TAU, d=R()*60; vol(c,Math.cos(a)*d,Math.sin(a)*d*.8,2+R()*4,1.6+R()*3,'#7a5e42',{hi:.3,lo:-.4}); } },
		cell:32,debris(c,R,k){ for(let i=0;i<2+k;i++) vol(c,(R()-.5)*14,(R()-.5)*14,3+R()*4,3+R()*3,'#7a5e42',{hi:.3,lo:-.4}); }}},
honeyshed:{cls:'TALL',box:[270,220],n:1,shadow:9,grime:.22,tags:{region:['wilds']},core(c){ c.fillStyle='#000'; c.fillRect(-92,-74,184,148); },
	draw(c,R){ c.beginPath(); rr(c,-92,-74,184,148,3); c.fillStyle='#2a221c'; c.fill();
		for(const s of [-1,1]){ c.save(); c.beginPath(); c.rect(-90,s<0?-72:0,180,72); c.clip(); for(let k=0;k<6;k++) sheet(c,-75+k*30,s*36,32,72,['#8a8478','#7a7468','#8e8a80'][k%3],R,{rib:5,rust:.6});
			const g=c.createLinearGradient(0,0,0,s*72); g.addColorStop(0,'rgba(255,250,235,.1)'); g.addColorStop(1,'rgba('+AO+',.3)'); c.fillStyle=g; c.fillRect(-92,s<0?-74:0,184,74); c.restore(); }
		plank(c,0,0,188,9,'#6e6a62',R,{}); for(let i=0;i<3;i++){ c.save(); c.translate(110,-50+i*36); c.beginPath(); rr(c,-18,-15,36,30,2); c.fillStyle='#ddd8ca'; c.fill(); c.strokeStyle='rgba(60,56,48,.5)'; c.lineWidth=1; c.stroke(); c.restore(); }
		for(const [x,y] of [[-114,40],[-112,-6]]){ vol(c,x,y,19,19,'#b07a2a',{hi:.3,lo:-.4}); c.lineWidth=1.6; c.strokeStyle='rgba(60,36,10,.6)'; ell(c,x,y,15,15); c.stroke(); ell(c,x+5,y+4,5,3); c.fillStyle='rgba(240,190,90,.6)'; c.fill(); }
		crown(c,0,0,150,.06,.2); }},
bell:{cls:'TALL',box:[180,160],n:2,shadow:4,grime:.2,tags:{region:['wilds']},core(c){ c.fillStyle='#000'; c.fillRect(-15,-15,30,30); },
	draw(c,R,v){ c.scale(1.5,1.5); ell(c,0,0,20,20); c.fillStyle='rgba(92,72,50,.45)'; c.fill(); c.beginPath(); rr(c,-9,-9,18,18,2); c.fillStyle='#5e4a38'; c.fill(); vol(c,0,0,6,6,'#7a6448',{hi:.3});
		if(v===0){ limb(c,[0,0],[44,0],5,'#4a3c30'); limb(c,[34,-10],[34,10],3,'#2e2a26'); vol(c,40,0,15,15,'#a87a3a',{hi:.55,lo:-.45}); c.lineWidth=1.4; c.strokeStyle='rgba(60,36,14,.6)'; ell(c,40,0,10,10); c.stroke(); ell(c,40,0,4,4); c.fillStyle='#3a2a1a'; c.fill();
			c.beginPath(); c.moveTo(48,6); c.bezierCurveTo(56,22,44,30,50,42); c.lineWidth=2; c.strokeStyle='#b09a6a'; c.stroke(); }
		else { limb(c,[0,0],[36,0],4,'#4a3c30'); c.beginPath(); c.moveTo(38,-14); c.lineTo(58,8); c.lineTo(28,12); c.closePath(); c.lineWidth=3.4; c.strokeStyle='#8d8f8c'; c.stroke(); c.lineWidth=1; c.strokeStyle='rgba(230,230,224,.6)'; c.stroke(); limb(c,[30,20],[52,30],2.4,'#8d8f8c'); } }},
saltlick:{cls:'LOW',box:[120,120],n:1,shadow:4,grime:.18,tags:{region:['wilds']},draw(c,R){ ell(c,0,0,52,48); c.fillStyle='rgba(92,72,50,.45)'; c.fill();
	for(let i=0;i<12;i++){ const a=R()*TAU, d=38+R()*14; c.save(); c.translate(Math.cos(a)*d,Math.sin(a)*d); c.rotate(a); for(const s of [-1,1]){ ell(c,0,s*2.6,3.4,2); c.fillStyle='rgba(50,36,24,.55)'; c.fill(); } c.restore(); }
	for(let i=0;i<5;i++){ const a=i/5*TAU+R()*.5; limb(c,[0,0],[Math.cos(a)*(36+R()*8),Math.sin(a)*(36+R()*8)],9-i*.5,'#5c4632'); }
	ell(c,0,0,28,27); c.fillStyle='#3e2e20'; c.fill(); vol(c,0,0,24,23,'#a3875c',{hi:.15,lo:-.25}); c.strokeStyle='rgba(98,70,42,.55)'; c.lineWidth=1; for(let k=1;k<4;k++){ ell(c,0,0,24*k/4,23*k/4); c.stroke(); }
	c.save(); c.rotate(.2); c.beginPath(); rr(c,-17,-17,34,34,3); c.fillStyle='#d8cdc6'; c.fill(); const g=c.createRadialGradient(3,4,2,3,4,16); g.addColorStop(0,'rgba(170,140,140,.55)'); g.addColorStop(1,'rgba(170,140,140,0)'); c.fillStyle=g; c.fillRect(-17,-17,34,34);
	c.strokeStyle='rgba(120,104,98,.5)'; c.lineWidth=1; c.strokeRect(-17,-17,34,34); c.restore(); crown(c,0,0,40,.12,.18); }},
scarecrow:{cls:'TALL',box:[170,150],n:2,shadow:5,grime:.22,tags:{region:['wilds']},core(c){ ell(c,0,0,18,18); c.fillStyle='#000'; c.fill(); },
	draw(c,R,v){ const cloth=v?'#4e5f74':'#8a4a3a';
		limb(c,[-72,0],[72,0],6,'#6b5440'); for(const s of [-1,1]) for(let i=0;i<9;i++){ const a=(s>0?0:Math.PI)+(R()-.5)*1.2; c.beginPath(); c.moveTo(s*56,0); c.lineTo(s*56+Math.cos(a)*(10+R()*10),Math.sin(a)*(10+R()*10)); c.lineWidth=1.4; c.strokeStyle='#c8b070'; c.stroke(); }
		c.beginPath(); rr(c,-56,-12,112,24,6); c.fillStyle=cloth; c.fill(); atop(c,()=>{ c.lineWidth=1.2; for(let x=-54;x<56;x+=8){ c.beginPath(); c.moveTo(x,-12); c.lineTo(x,12); c.strokeStyle='rgba(20,14,10,.25)'; c.stroke(); } for(let y=-8;y<12;y+=8){ c.beginPath(); c.moveTo(-56,y); c.lineTo(56,y); c.strokeStyle='rgba(230,210,180,.18)'; c.stroke(); } c.fillStyle='rgba(180,150,100,.6)'; c.fillRect(20,-6,10,8); });
		vol(c,0,0,26,22,shade(C(cloth),-.08),{hi:.2,lo:-.4}); for(const s of [-1,1]){ c.beginPath(); c.moveTo(s*20,8); c.lineTo(s*28,22); c.lineWidth=1.4; c.strokeStyle='#c8b070'; c.stroke(); }
		const hat=v?'#4a3e34':'#b8a060'; ell(c,0,0,27,27); c.fillStyle=hat; c.fill(); c.lineWidth=1; c.strokeStyle='rgba(60,44,24,.4)'; for(let k=1;k<4;k++){ ell(c,0,0,27-k*3.6,27-k*3.6); c.stroke(); } vol(c,0,0,14,14,shade(C(hat),-.05),{hi:.3}); ell(c,0,0,15,15); c.lineWidth=2.4; c.strokeStyle=v?'#2a221c':'#7a3a2a'; c.stroke(); },
	breakable:{smashSpeed:400,box:[240,220],rim:false,broken(c,R){ limb(c,[-80,30],[60,-10],6,'#6b5440'); limb(c,[-30,-50],[-20,40],5,'#6b5440');
		for(let i=0;i<60;i++){ const x=(R()-.5)*180, y=(R()-.5)*140, a=R()*TAU; c.beginPath(); c.moveTo(x,y); c.lineTo(x+Math.cos(a)*(6+R()*8),y+Math.sin(a)*(6+R()*8)); c.lineWidth=1.3; c.strokeStyle='#c8b070'; c.stroke(); }
		c.save(); c.translate(10,20); c.rotate(.5); c.beginPath(); rr(c,-50,-14,100,28,8); c.fillStyle='#8a4a3a'; c.fill(); c.restore(); ell(c,70,50,26,26); c.fillStyle='#b8a060'; c.fill(); vol(c,70,50,13,13,'#a89050',{hi:.3}); },
		cell:44,debris(c,R,k){ if(k===0){ for(let i=0;i<10;i++){ const a=R()*TAU; c.beginPath(); c.moveTo(0,0); c.lineTo(Math.cos(a)*12,Math.sin(a)*12); c.lineWidth=1.4; c.strokeStyle='#c8b070'; c.stroke(); } } else if(k===1){ c.fillStyle='#8a4a3a'; c.fillRect(-12,-8,24,16); } else if(k===2){ ell(c,0,0,14,14); c.fillStyle='#b8a060'; c.fill(); vol(c,0,0,7,7,'#a89050'); } else limb(c,[-14,4],[14,-4],4,'#6b5440'); }}},
farmgate:{cls:'STATEFUL',box:[340,80],n:2,shadow:4,grime:.2,occluder:false,tags:{region:['wilds']},
	draw(c,R,v){ const paint=v?'#9a4a36':'#d4cfc0', brace=v?'#d4cfc0':'#b8b2a2';
		for(const x of [-158,158]){ c.beginPath(); rr(c,x-13,-13,26,26,3); c.fillStyle='#4f4438'; c.fill(); vol(c,x,0,10,10,'#7a6a56',{hi:.25,lo:-.35}); }
		const bars=[-24,-12,0,12,24], line=(pts,w,col)=>{ c.beginPath(); c.moveTo(pts[0][0],pts[0][1]); for(let i=1;i<pts.length;i++) c.lineTo(pts[i][0],pts[i][1]); c.lineWidth=w; c.strokeStyle=col; c.lineCap='round'; c.stroke(); };
		for(const pass of [[8,'rgba(24,18,14,.85)'],[5,paint]]){ for(const y of bars) line([[-144,y],[144,y]],pass[0]*(y===-24||y===24?1.15:.85),pass[1]); for(const x of [-144,-72,0,72,144]) line([[x,-24],[x,24]],pass[0],pass[1]); }
		for(const pass of [[7,'rgba(24,18,14,.85)'],[4,brace]]) line([[-144,24],[0,-24],[144,24]],pass[0],pass[1]);
		atop(c,()=>{ for(let i=0;i<10;i++){ ell(c,(R()-.5)*280,(R()-.5)*40,4+R()*8,1.6+R()*2,0); c.fillStyle='rgba(110,84,52,.35)'; c.fill(); } });
		vol(c,-146,-24,3.4,3.4,'#3a3836',{hi:.3}); vol(c,-146,24,3.4,3.4,'#3a3836',{hi:.3}); c.fillStyle='#2a2826'; c.fillRect(140,-5,12,10); },
	breakable:{smashSpeed:180,box:[360,160],rim:false,broken(c,R){ for(const x of [-158,158]){ vol(c,x,0,10,10,'#6e6050',{hi:.15}); }
		const col=['#d4cfc0','#9a4a36']; for(let i=0;i<8;i++) plank(c,(R()-.5)*280,(R()-.5)*90,40+R()*70,6,col[i%2?1:0],R,{rot:R()*3}); for(let i=0;i<12;i++) plank(c,(R()-.5)*300,(R()-.5)*110,8+R()*14,3,'#c4bfb0',R,{rot:R()*3}); },
		cell:56,debris(c,R,k){ plank(c,0,0,28+k*5,6,k%2?'#9a4a36':'#d4cfc0',R,{rot:(R()-.5)*.6}); }}},
pumpkin:{cls:'STATEFUL',box:[120,120],n:3,shadow:3,grime:.12,occluder:false,tags:{region:['wilds']},
	draw(c,R,v){ c.scale(1.35,1.35); const col=['#c0642a','#b8722e','#a8a060'][v], r=[24,19,26][v]; c.beginPath(); c.moveTo(0,0); c.bezierCurveTo(20,-30,34,-6,40,-30); c.lineWidth=2.4; c.strokeStyle='#4e6a30'; c.stroke();
		c.save(); c.translate(30,-28); c.rotate(-.6); for(let i=0;i<5;i++){ const a=(i-2)*.55; vol(c,Math.cos(a)*8,Math.sin(a)*8,8,6,'#56703a',{hi:.2,lo:-.4,rot:a}); } c.restore(); pumpkin(c,R,0,0,r,col); },
	breakable:{smashSpeed:40,box:[150,150],rim:false,broken(c,R){ for(let i=0;i<14;i++){ const a=R()*TAU, d=R()*46; ell(c,Math.cos(a)*d,Math.sin(a)*d,6+R()*10,4+R()*7,R()*3); c.fillStyle=R()<.6?'rgba(200,106,42,.9)':'rgba(214,150,70,.85)'; c.fill(); }
		for(let i=0;i<26;i++){ const a=R()*TAU, d=R()*50; ell(c,Math.cos(a)*d,Math.sin(a)*d,1.8,1.1,R()*3); c.fillStyle='#e8dcb0'; c.fill(); }
		for(let i=0;i<5;i++){ c.save(); c.translate((R()-.5)*90,(R()-.5)*90); c.rotate(R()*3); c.beginPath(); c.arc(0,0,12,0,Math.PI*.8); c.lineWidth=5; c.strokeStyle='#b05a26'; c.stroke(); c.restore(); } vol(c,0,0,4,4,'#5a5030'); },
		cell:32,debris(c,R,k){ if(k===3){ for(let i=0;i<6;i++){ ell(c,(R()-.5)*14,(R()-.5)*14,2,1.2,R()*3); c.fillStyle='#e8dcb0'; c.fill(); } } else { c.beginPath(); c.arc(0,0,8+k*2,0,Math.PI*.9); c.lineWidth=5; c.strokeStyle=k%2?'#c0642a':'#b05a26'; c.stroke(); } }}},
still:{cls:'STATEFUL',box:[190,150],n:1,shadow:5,grime:.25,explosive:true,occluder:false,tags:{region:['wilds']},
	draw(c,R){ c.beginPath(); rr(c,-68,-30,64,60,4); c.fillStyle='#2a2420'; c.fill(); for(let i=0;i<8;i++) stone(c,-68+(i%4)*21,i<4?-32:32,7,R,'#7d766e'); glowAt(c,-36,24,16,'#c8642a',.7);
		vol(c,-36,-2,32,32,'#b06a3a',{hi:.45,lo:-.45}); for(let i=0;i<14;i++){ const a=i/14*TAU; vol(c,-36+Math.cos(a)*27,-2+Math.sin(a)*27,1.6,1.6,'#6a3a1a',{hi:.4}); } vol(c,-36,-2,12,12,'#c88050',{hi:.5});
		limb(c,[-28,-8],[16,-20],5,'#a86434'); for(let k=0;k<4;k++){ ell(c,40,-14,20-k*4,18-k*4); c.lineWidth=3; c.strokeStyle=k%2?'#a86434':'#c07a44'; c.stroke(); }
		vol(c,44,30,18,18,'#6b4e32',{hi:.25}); c.lineWidth=2; c.strokeStyle='#3a3c3e'; ell(c,44,30,14,14); c.stroke(); limb(c,[40,-2],[44,22],3.4,'#a86434');
		for(const [x,y] of [[78,4],[80,40],[66,54]]){ vol(c,x,y,9,9,'#c8b896',{hi:.3,lo:-.35}); vol(c,x,y,3.4,3.4,'#4a3a2a'); } },
	breakable:{smashSpeed:120,box:[260,260],rim:false,broken(c,R){ const g=c.createRadialGradient(0,0,10,0,0,110); g.addColorStop(0,'rgba(14,12,10,.85)'); g.addColorStop(.6,'rgba(24,20,16,.45)'); g.addColorStop(1,'rgba(24,20,16,0)'); c.fillStyle=g; ell(c,0,0,110,110); c.fill();
		const pts=[]; for(let i=0;i<12;i++){ const a=i/12*TAU, r=i%2?16:30+R()*10; pts.push([Math.cos(a)*r-10,Math.sin(a)*r]); } polyPath(c,pts); c.fillStyle='#7a4424'; c.fill();
		for(let i=0;i<3;i++){ c.beginPath(); c.arc(30+i*6,-30+i*10,10+i*4,0,Math.PI*1.2); c.lineWidth=3; c.strokeStyle='#8a5430'; c.stroke(); } for(let i=0;i<5;i++) plank(c,(R()-.5)*160,(R()-.5)*160,20+R()*20,8,'#6b4e32',R,{rot:R()*3}); },
		cell:40,debris(c,R,k){ if(k===0){ c.beginPath(); c.moveTo(-12,-6); c.quadraticCurveTo(0,-12,12,-4); c.lineTo(8,8); c.quadraticCurveTo(0,2,-10,6); c.closePath(); c.fillStyle='#b06a3a'; c.fill(); } else if(k===1){ c.beginPath(); c.arc(0,0,10,0,Math.PI); c.lineWidth=3; c.strokeStyle='#a86434'; c.stroke(); } else if(k===2){ c.beginPath(); c.moveTo(-8,-8); c.lineTo(10,-4); c.lineTo(4,10); c.closePath(); c.fillStyle='#c8b896'; c.fill(); } else plank(c,0,0,24,8,'#6b4e32',R,{rot:R()}); }}},
sluice:{cls:'STATEFUL',box:[290,120],n:1,shadow:5,grime:.28,occluder:false,tags:{region:['wilds']},
	draw(c,R){ c.beginPath(); rr(c,-104,-26,208,52,3); c.fillStyle='#2e241c'; c.fill(); for(let k=0;k<5;k++) plank(c,0,-20+k*10,204,9,shade(C(WOOD),(R()-.5)*.14),R,{nails:true});
		for(const x of [-118,118]){ c.beginPath(); rr(c,x-20,-20,40,40,3); c.fillStyle='#4a3a2c'; c.fill(); vol(c,x,0,16,16,'#6b5440',{hi:.2,lo:-.4}); c.strokeStyle='rgba(30,22,16,.5)'; c.lineWidth=1; for(let k=1;k<3;k++){ ell(c,x,0,5*k,5*k); c.stroke(); } c.fillStyle='#3a3c3e'; c.fillRect(x-20,-4,40,8); }
		ring(c,118,-2,14,4,R,'#4a4c4e'); for(let i=0;i<6;i++){ const a=i/6*TAU; limb(c,[118,-2],[118+Math.cos(a)*12,-2+Math.sin(a)*12],2,'#5c5e60'); }
		c.strokeStyle='#5b5d5e'; c.lineWidth=2; c.beginPath(); for(let x=-100;x<104;x+=6){ c.moveTo(x,-30); c.lineTo(x+3,-26); } c.stroke(); rust(c,-60,10,16,621); },
	breakable:{smashSpeed:350,box:[330,200],rim:false,broken(c,R){ const g=c.createRadialGradient(0,0,10,0,0,140); g.addColorStop(0,'rgba(24,36,42,.5)'); g.addColorStop(1,'rgba(24,36,42,0)'); c.fillStyle=g; ell(c,0,10,150,80); c.fill();
		for(const x of [-118,118]) vol(c,x,0,16,16,'#6b5440',{hi:.2,lo:-.4}); for(let i=0;i<7;i++) plank(c,(R()-.5)*230,(R()-.5)*120,50+R()*80,9,WOOD,R,{rot:(R()-.5)*1.2,nails:true}); },
		cell:56,debris(c,R,k){ plank(c,0,0,30+k*5,9,WOOD,R,{rot:(R()-.5)*.6,nails:true}); }}},
rockpile:{cls:'STATEFUL',box:[240,210],n:2,shadow:7,grime:.18,occluder:true,tags:{region:['wilds']},core(c){ ell(c,0,0,86,74); c.fillStyle='#000'; c.fill(); },
	draw(c,R,v){ for(let i=0;i<9;i++){ const a=i/9*TAU+R()*.3; redRock(c,R,Math.cos(a)*68,Math.sin(a)*56,24+R()*8); }
		for(let i=0;i<5;i++){ const a=i/5*TAU+R()*.4; redRock(c,R,Math.cos(a)*34,Math.sin(a)*28,22+R()*6); } redRock(c,R,0,0,24);
		if(v){ limb(c,[-90,40],[-30,64],7,'#6b5440'); limb(c,[70,-56],[96,-10],6,'#6b5440'); }
		atop(c,()=>{ c.strokeStyle='rgba(70,30,18,.2)'; c.lineWidth=1.2; for(let k=-6;k<=6;k++){ c.beginPath(); c.moveTo(-110,k*16); c.quadraticCurveTo(0,k*16+6,110,k*16+10); c.stroke(); } }); crown(c,0,0,110,.1,.22); },
	breakable:{smashSpeed:350,box:[300,260],rim:false,broken(c,R){ for(let i=0;i<10;i++) redRock(c,R,(R()-.5)*220,(R()-.5)*170,8+R()*10); for(let i=0;i<60;i++) pebble(c,R,1+R()*2.4,['#9a6e54','#7a5a46','#a8743f']); },
		cell:36,debris(c,R,k){ redRock(c,R,0,0,7+k*1.6); }}},
rock_roll:{cls:'LOW',box:[120,120],n:2,shadow:4,grime:.18,tags:{region:['wilds']},draw(c,R,v){ const base=[]; for(let i=0;i<13;i++) base.push(.93+R()*.1);
	facetRock(c,0,0,46,v?'#8e5440':'#9a5c42',690+v*5,base,{lichen:false}); atop(c,()=>{ c.strokeStyle='rgba(70,30,18,.25)'; c.lineWidth=1.2; for(let k=-3;k<=3;k++){ c.beginPath(); c.moveTo(-50,k*12); c.quadraticCurveTo(0,k*12+5,50,k*12+8); c.stroke(); } c.strokeStyle='rgba(230,200,170,.25)'; c.lineWidth=2; for(let i=0;i<3;i++){ c.beginPath(); c.arc(0,0,20+i*8,R()*3,R()*3+.6); c.stroke(); } }); crown(c,0,0,52,.12,.24); }},
tnt:{cls:'STATEFUL',box:[150,130],n:2,shadow:4,grime:.25,explosive:true,occluder:false,tags:{region:['wilds']},
	draw(c,R,v){ c.save(); c.translate(-10,0); c.rotate(-.08); c.beginPath(); rr(c,-38,-30,76,60,3); c.fillStyle='#4a3622'; c.fill(); c.beginPath(); rr(c,-33,-25,66,50,2); c.fillStyle='#2a1e14'; c.fill();
		for(let j=0;j<4;j++) for(let i=0;i<5;i++){ const x=-26+i*13, y=-18+j*12; vol(c,x,y,5.6,5.6,'#a83a2a',{hi:.3,lo:-.4}); ell(c,x,y,1.6,1.6); c.fillStyle='#1a1210'; c.fill(); if((i+j)%3===0){ c.beginPath(); c.moveTo(x,y); c.quadraticCurveTo(x+4,y-6,x+7,y-3); c.lineWidth=1; c.strokeStyle='#e0dccc'; c.stroke(); } }
		for(const s of [-1,1]) plank(c,0,s*30,80,7,'#8a6a44',R,{}); c.restore();
		c.save(); c.translate(44,-26); c.rotate(.5); c.beginPath(); rr(c,-30,-22,60,44,2); c.fillStyle='#7a5a3a'; c.fill(); for(let k=0;k<3;k++) plank(c,0,-14+k*14,58,12,'#8a6a44',R,{}); c.fillStyle='rgba(30,26,20,.85)'; c.fillRect(-30,-4,60,8); c.fillStyle='rgba(200,170,70,.85)'; for(let x=-28;x<30;x+=10) c.fillRect(x,-4,5,8); c.restore();
		for(let i=0;i<2+v;i++){ c.save(); c.translate(30+R()*30,30+R()*20); c.rotate(R()*3); c.beginPath(); rr(c,-14,-3.6,28,7.2,3); c.fillStyle='#a83a2a'; c.fill(); c.beginPath(); c.moveTo(14,0); c.quadraticCurveTo(20,-4,24,2); c.lineWidth=1; c.strokeStyle='#e0dccc'; c.stroke(); c.restore(); }
		if(v){ c.save(); c.translate(-58,40); c.beginPath(); rr(c,-12,-9,24,18,2); c.fillStyle='#5a3a26'; c.fill(); limb(c,[0,-8],[0,-20],2.4,'#6d6f72'); limb(c,[-8,-20],[8,-20],3,'#3a3c3e'); c.restore(); c.beginPath(); c.moveTo(-58,48); c.bezierCurveTo(-30,70,0,50,10,30); c.lineWidth=1.2; c.strokeStyle='#2a2422'; c.stroke(); } },
	breakable:{smashSpeed:120,box:[240,240],rim:false,broken(c,R){ const g=c.createRadialGradient(0,0,10,0,0,110); g.addColorStop(0,'rgba(14,12,10,.88)'); g.addColorStop(.6,'rgba(24,20,16,.45)'); g.addColorStop(1,'rgba(24,20,16,0)'); c.fillStyle=g; ell(c,0,0,110,110); c.fill();
		for(let i=0;i<8;i++) plank(c,(R()-.5)*170,(R()-.5)*170,18+R()*26,7,'#5a4632',R,{rot:R()*3}); for(let i=0;i<10;i++){ const a=R()*TAU, d=R()*80; glowAt(c,Math.cos(a)*d,Math.sin(a)*d,5+R()*6,'#a0461e',.45); } },
		cell:40,debris(c,R,k){ if(k%2===0){ c.save(); c.rotate(R()*3); c.beginPath(); rr(c,-12,-3.4,24,6.8,3); c.fillStyle='#a83a2a'; c.fill(); c.restore(); } else plank(c,0,0,22+k*3,7,'#8a6a44',R,{rot:R()}); }}},
/* decor: atlases of 4 cells in a row (one MultiMesh per id; the variant picks the cell) */
tufts:{cls:'DECOR',cell:72,n:4,shadow:2,grime:0,rim:false,draw(c,R,v){ const cols=v===3?['#8c8460','#a39770','#7a744e']:['#55663a','#66773f','#7d8a4e']; for(let i=0;i<34;i++){ const a=R()*TAU, l=10+R()*20; c.beginPath(); c.moveTo((R()-.5)*6,(R()-.5)*6); c.quadraticCurveTo(Math.cos(a+.3)*l*.6,Math.sin(a+.3)*l*.6,Math.cos(a)*l,Math.sin(a)*l); c.lineWidth=1.6+R(); c.strokeStyle=cols[(R()*3)|0]; c.lineCap='round'; c.stroke(); }
	if(v===2) for(let i=0;i<5;i++){ ell(c,(R()-.5)*30,(R()-.5)*30,2,2); c.fillStyle=R()<.5?'#d6ceaa':'#b9a7c4'; c.fill(); } }},
pebbles:{cls:'DECOR',cell:64,n:4,shadow:1.5,grime:0,rim:false,draw(c,R,v){ const n=3+v*1.5; for(let i=0;i<n;i++) { c.save(); c.translate((R()-.5)*34,(R()-.5)*34); pebble(c,R,3+R()*5,['#8a8178','#7d7268','#9a9184','#6d6258']); c.restore(); } }},
cracks:{cls:'DECOR',cell:160,n:4,shadow:0,grime:0,rim:false,draw(c,R,v){ for(let k=0;k<2+v%2;k++){ c.save(); c.translate((R()-.5)*30,(R()-.5)*30); crackWalk(c,R,12+(R()*8|0),2.2,'rgba(30,24,20,.55)',true); c.restore(); } }},
bones:{cls:'DECOR',cell:96,n:4,shadow:1.5,grime:.1,rim:false,draw(c,R,v){ if(v===0) skull(c,0,0,.9,R()*TAU,{horns:true}); else if(v===1){ bone(c,[-24,-6],[22,8],5); bone(c,[-8,14],[16,-16],4); } else if(v===2){ for(let i=0;i<5;i++){ c.beginPath(); c.arc(0,10,14+i*5,Math.PI*1.15,Math.PI*1.85); c.lineWidth=2.4; c.strokeStyle=BONE; c.stroke(); } } else { skull(c,-10,0,.6,1.2,{}); bone(c,[4,-20],[20,18],4); } }},
paint:{cls:'DECOR',cell:192,n:4,shadow:0,grime:0,rim:false,draw(c,R,v){ const y='rgba(216,197,138,.85)', w='rgba(214,210,198,.85)'; c.fillStyle=v===0?y:w;
	if(v===0) c.fillRect(-70,-6,140,12); else if(v===1){ c.beginPath(); c.moveTo(-60,-7); c.lineTo(20,-7); c.lineTo(20,-24); c.lineTo(66,0); c.lineTo(20,24); c.lineTo(20,7); c.lineTo(-60,7); c.closePath(); c.fill(); }
	else if(v===2){ for(let k=-2;k<=2;k++) c.fillRect(k*34-12,-80,24,160); } else c.fillRect(-16,-90,32,180);
	c.globalCompositeOperation='destination-out'; for(let i=0;i<260;i++){ ell(c,(R()-.5)*190,(R()-.5)*190,1+R()*5,1+R()*3,R()*3); c.fillStyle='rgba(0,0,0,'+(.3+R()*.6)+')'; c.fill(); } c.globalCompositeOperation='source-over'; }},
oilstain:{cls:'DECOR',cell:160,n:4,shadow:0,grime:0,rim:false,draw(c,R,v){ for(let i=0;i<7;i++){ ell(c,(R()-.5)*60,(R()-.5)*50,20+R()*30,14+R()*20,R()*3); c.fillStyle='rgba(18,16,14,.28)'; c.fill(); }
	if(v===3){ for(const s of [-1,1]){ c.beginPath(); c.moveTo(-70,s*14); c.bezierCurveTo(-20,s*18,20,s*8,70,s*16); c.lineWidth=10; c.strokeStyle='rgba(16,14,14,.35)'; c.stroke(); } }
	else { const g=c.createRadialGradient(0,0,10,0,0,60); g.addColorStop(0,'rgba(90,74,110,0)'); g.addColorStop(.7,'rgba(90,96,60,.14)'); g.addColorStop(1,'rgba(110,80,50,0)'); c.fillStyle=g; ell(c,0,0,60,50); c.fill(); } }},
reeds:{cls:'DECOR',cell:112,n:4,shadow:2,grime:0,rim:false,draw(c,R,v){ for(let i=0;i<26;i++){ const a=R()*TAU, l=14+R()*30, x0=(R()-.5)*16, y0=(R()-.5)*16; c.beginPath(); c.moveTo(x0,y0); c.lineTo(x0+Math.cos(a)*l,y0+Math.sin(a)*l); c.lineWidth=1.4; c.strokeStyle=R()<.5?'#6f7a46':'#8a8a5a'; c.stroke();
	if(R()<.35){ c.save(); c.translate(x0+Math.cos(a)*l,y0+Math.sin(a)*l); c.rotate(a); ell(c,0,0,5,2); c.fillStyle='#5c4630'; c.fill(); c.restore(); } } }},
/* city rooftops (ChunkRecipe's roof pass, on BUILDING cells): AC unit, vents, water tank, skylight */
rooftop:{cls:'DECOR',cell:160,n:4,shadow:3,grime:.12,rim:false,draw(c,R,v){
	if(v===0){ c.beginPath(); rr(c,-46,-34,92,68,5); c.fillStyle='#8f8c86'; c.fill(); c.strokeStyle='rgba(30,28,26,.55)'; c.lineWidth=1.4; c.stroke();
		ring(c,-14,0,25,8,R,'#3a3a3c'); c.strokeStyle='rgba(200,198,190,.5)'; c.lineWidth=1; for(let k=0;k<6;k++){ const a=k/6*TAU; c.beginPath(); c.moveTo(-14,0); c.lineTo(-14+Math.cos(a)*22,Math.sin(a)*22); c.stroke(); }
		c.fillStyle='rgba(40,38,36,.45)'; for(let y=-24;y<26;y+=6) c.fillRect(22,y,18,2.2); limb(c,[46,20],[70,26],6,'#6d6f72'); }
	else if(v===1){ for(const [x,y,r] of [[-30,-20,17],[16,-26,14],[-6,22,15]]){ vol(c,x,y,r,r,'#9a9894',{hi:.3,lo:-.4}); c.strokeStyle='rgba(40,38,36,.5)'; c.lineWidth=1; for(let k=0;k<10;k++){ const a=k/10*TAU; c.beginPath(); c.moveTo(x+Math.cos(a)*r*.25,y+Math.sin(a)*r*.25); c.lineTo(x+Math.cos(a+.5)*r*.95,y+Math.sin(a+.5)*r*.95); c.stroke(); } vol(c,x,y,r*.22,r*.22,'#6d6b68',{hi:.3}); }
		c.beginPath(); rr(c,22,6,34,30,3); c.fillStyle='#7d7a75'; c.fill(); c.fillStyle='rgba(20,18,16,.55)'; c.fillRect(26,10,26,8); }
	else if(v===2){ ell(c,0,0,52,52); c.fillStyle='rgba('+AO+',.35)'; c.fill(); vol(c,0,0,46,46,'#7d6247',{hi:.2,lo:-.45}); c.strokeStyle='rgba(40,28,18,.55)'; c.lineWidth=1.2; for(let k=0;k<16;k++){ const a=k/16*TAU; c.beginPath(); c.moveTo(Math.cos(a)*12,Math.sin(a)*12); c.lineTo(Math.cos(a)*45,Math.sin(a)*45); c.stroke(); }
		for(const r of [30,44]){ ell(c,0,0,r,r); c.strokeStyle='rgba(60,62,64,.75)'; c.lineWidth=2; c.stroke(); } vol(c,0,0,10,10,'#8a7a62',{hi:.35}); limb(c,[38,26],[60,46],4,'#5c5e60'); }
	else { c.beginPath(); rr(c,-50,-34,100,68,3); c.fillStyle='#55585a'; c.fill(); const g=c.createLinearGradient(-46,-30,46,30); g.addColorStop(0,'#8fa6b2'); g.addColorStop(.5,'#5d7380'); g.addColorStop(1,'#7e96a3'); c.fillStyle=g; c.fillRect(-45,-29,90,58);
		c.fillStyle='#55585a'; c.fillRect(-2,-29,4,58); c.fillRect(-45,-2,90,4); c.strokeStyle='rgba(230,240,244,.35)'; c.lineWidth=2; c.beginPath(); c.moveTo(-38,22); c.lineTo(-14,-22); c.stroke(); c.beginPath(); c.moveTo(10,22); c.lineTo(30,-14); c.stroke(); } }},
streetglow:{cls:'DECOR',cell:384,n:4,shadow:0,grime:0,rim:false,blend:'add',draw(c,R,v){ const col=v===3?[214,224,232]:[232,196,140], sx=v===1?1.3:1, sy=v===1?.8:1; c.save(); c.scale(sx,sy);
	const g=c.createRadialGradient(0,0,0,0,0,180); g.addColorStop(0,css(col,.55)); g.addColorStop(.35,css(col,.3)); g.addColorStop(.7,css(col,.1)); g.addColorStop(1,css(col,0)); c.fillStyle=g; ell(c,0,0,180,180); c.fill(); c.restore();
	if(v===2){ const g2=c.createRadialGradient(50,30,0,50,30,90); g2.addColorStop(0,css(col,.2)); g2.addColorStop(1,css(col,0)); c.fillStyle=g2; ell(c,50,30,90,90); c.fill(); } }},
/* ghost town tumbleweeds: tangled balls of dry twigs, darker inside */
tumbleweed:{cls:'DECOR',cell:112,n:4,shadow:2,grime:0,rim:false,tags:{landscape:['ghosttown','saltflats']},draw(c,R,v){ const r=26+v*4; ell(c,0,2,r*1.05,r); c.fillStyle='rgba('+AO+',.25)'; c.fill(); ell(c,0,0,r*.8,r*.8); c.fillStyle='rgba(74,60,42,.55)'; c.fill();
	for(let i=0;i<150;i++){ const a=R()*TAU, d=r*Math.sqrt(R()), x=Math.cos(a)*d, y=Math.sin(a)*d, b=R()*TAU, l=6+R()*12; c.beginPath(); c.moveTo(x,y); c.quadraticCurveTo(x+Math.cos(b+1)*l*.6,y+Math.sin(b+1)*l*.6,x+Math.cos(b)*l,y+Math.sin(b)*l); c.lineWidth=.9+R()*.6; c.strokeStyle=['#9a8460','#7d6a4c','#b09a70','#6a583e'][(R()*4)|0]; c.lineCap='round'; c.stroke(); }
	crown(c,0,0,r,.12,.2); }},
/* volcano steam vents: a fissure or a crusted hole, sulphur and mineral rims, a faint puff of steam */
steam_vent:{cls:'DECOR',cell:160,n:4,shadow:0,grime:0,rim:false,tags:{landscape:['volcano']},draw(c,R,v){
	for(let i=0;i<10;i++){ ell(c,(R()-.5)*60,(R()-.5)*50,6+R()*12,5+R()*8,R()*3); c.fillStyle=R()<.5?'rgba(160,146,92,.28)':'rgba(200,196,184,.26)'; c.fill(); }
	if(v===3){ ell(c,0,0,18,15); c.fillStyle='#5a5240'; c.fill(); ell(c,0,0,12,10); c.fillStyle='#120e0c'; c.fill(); }
	else { c.save(); c.rotate(R()*3); c.beginPath(); c.moveTo(-50,0); for(let k=1;k<=10;k++) c.lineTo(-50+k*10,(R()-.5)*10); c.lineWidth=6; c.strokeStyle='#5a5240'; c.lineCap='round'; c.stroke(); c.lineWidth=3; c.strokeStyle='#120e0c'; c.stroke(); c.restore(); }
	for(let i=0;i<5;i++){ const x=(R()-.5)*40, y=(R()-.5)*40, r=14+R()*20; const g=c.createRadialGradient(x,y,0,x,y,r); g.addColorStop(0,'rgba(226,228,230,'+(.28+v*.04)+')'); g.addColorStop(1,'rgba(226,228,230,0)'); c.fillStyle=g; ell(c,x,y,r,r); c.fill(); } }},
/* Region 1: the unbreakable hedgerow as wall pieces (cells: straight, straight, end cap, corner; docs/WORLD_ART.md
   "Hedgerow"), the thicket's pine crowns (laid on wall cells like rooftop), and windfall apples under orchard oaks */
hedgerow:{cls:'DECOR',cell:192,n:4,fill:true,shadow:0,grime:0,rim:false,tags:{region:['wilds']},draw(c,R,v){ hedgerowPiece(c,R,['straight','straight','end','corner'][v]); }},
pine_crown:{cls:'DECOR',cell:256,n:4,shadow:3,grime:0,rim:false,tags:{landscape:['forest']},draw(c,R,v){ const sets=[[[0,0,110]],[[-36,-12,86],[40,18,82]],[[-42,-32,72],[40,-28,68],[0,42,76]],[[-48,-46,60],[48,-42,58],[-42,46,62],[46,48,60]]]; for(const [x,y,r] of sets[v]) thicketCrown(c,R,x,y,r); }},
apples:{cls:'DECOR',cell:40,n:4,shadow:1.5,grime:0,rim:false,tags:{region:['wilds']},draw(c,R,v){ const apple=(x,y,col,bite)=>{ vol(c,x,y,8,7.6,col,{hi:.35,lo:-.4}); if(bite){ c.save(); c.globalCompositeOperation='destination-out'; ell(c,x+7,y-2,5,4.4); c.fill(); c.restore(); ell(c,x+3.6,y-1.6,2.8,3.4); c.fillStyle='#e8e0b8'; c.fill(); }
		limb(c,[x,y],[x+1.6,y-5],1.6,'#4a3a2a'); ell(c,x+4,y-6,3.4,1.6,.6); c.fillStyle='#5a7036'; c.fill(); };
	if(v===0) apple(0,0,'#9a3a2a'); else if(v===1) apple(0,0,'#a8a048'); else if(v===2) apple(0,0,'#9a3a2a',true); else { apple(-6,4,'#9a3a2a'); apple(7,-3,'#a84a2a'); apple(2,8,'#a8a048'); } }}
};

/* rusted wrecks of the player's own cars: car_gen.js stage 2, then rust, moss and fade */
function renderWreck(key,res){ const W=window.CarArt, src=W.render(key,{style:'A',stage:2,res,shadow:false}), cv=canvas(src.width,src.height), x=cv.getContext('2d');
	x.filter='saturate(.55) brightness(.82) contrast(.95)'; x.drawImage(src,0,0); x.filter='none';
	const n=pixels(cv.width,cv.height,(u,v,i,j,o)=>{ const f=fbm(i/res*.05,j/res*.05,500+key.length,4), g=fbm(i/res*.2,j/res*.2,510,2); o[0]=112+(g-.5)*40; o[1]=60+(g-.5)*20; o[2]=34; o[3]=smooth(.55,.66,f)*150; });
	const m=pixels(cv.width,cv.height,(u,v,i,j,o)=>{ const f=fbm(i/res*.06,j/res*.06,520+key.length,4); o[0]=86; o[1]=100; o[2]=56; o[3]=smooth(.66,.74,f)*110; });
	x.globalCompositeOperation='source-atop'; x.drawImage(n,0,0); x.drawImage(m,0,0); x.globalCompositeOperation='source-over'; return cv; }

/* bake one catalog entry: every variant (with shadow and rim), the broken state and debris strip for breakables,
   the hull from the alpha mask (or the core drawing), and the manifest metadata */
const LEAF_CELL=28; /* world px per cell of a layered prop's leaves strip */
/* a drawing's silhouette as a soft ground shadow (a canopy's shade on the ground layer under it) */
function shadowOf(B,blur,a){ const W=B.width, H=B.height, S=canvas(W,H), s=S.getContext('2d'); s.drawImage(B,0,0); s.globalCompositeOperation='source-in'; s.fillStyle='#0a0806'; s.fillRect(0,0,W,H);
	const cv=canvas(W,H), x=cv.getContext('2d'); x.filter='blur('+blur.toFixed(2)+'px)'; x.globalAlpha=a; x.drawImage(S,0,0); return cv; }
function bakeProp(id){ const d=PROPS[id]; if(!d) throw new Error('unknown prop '+id); const res=PROP_RES, files={}, variants=[], canopies=[];
	if(d.cls==='DECOR'){ const cell=Math.round(d.cell*res), cv=canvas(cell*d.n,cell), x=cv.getContext('2d');
		const inset=d.fill?1:.82; /* fill: the drawing uses the whole cell (pieces that join at the cell edges) */
		for(let v=0;v<d.n;v++){ const R=rng(2000+v*97+id.charCodeAt(0)); const B=body(cell,cell,res,b=>{ b.save(); b.scale(inset,inset); d.draw(b,R,v); b.restore(); });
			const f=finish(B,{res,grime:d.grime,shadow:d.shadow,rim:false,shadowA:.3}); x.drawImage(f,v*cell,0); }
		files[id+'.png']=cv;
		return {files,meta:{class:'DECOR',res,variants:[id+'.png'],hull:[],sizePx:[d.cell,d.cell],occluder:false,breakable:null,explosive:false,tags:d.tags||{},solid:false,
			atlas:{cells:d.n,cellPx:[d.cell,d.cell],cellTexels:cell,blend:d.blend||'mix'}}}; }
	const pad=Math.max(8,(d.shadow||0)*2.2+3), [W,H]=sizeFor(d.box,res,pad);
	let first=null, hullCv=null;
	for(let v=0;v<d.n;v++){ const R=rng(3000+v*131+id.charCodeAt(0)*13+id.length);
		const name=id+(v?'_v'+v:'')+'.png';
		if(d.canopy){ /* layered: the canopy keeps the variant's stream (its look predates the split), the ground layer gets its own */
			const Cn=body(W,H,res,b=>d.canopy(b,R,v)), R2=rng(6000+v*131+id.charCodeAt(0)*13+id.length), B=body(W,H,res,b=>d.draw(b,R2,v));
			if(v===0){ first=canvas(W,H); const f=first.getContext('2d'); f.drawImage(B,0,0); f.drawImage(Cn,0,0); hullCv=d.core?body(W,H,res,b=>d.core(b)):B; }
			const base=canvas(W,H), bx=base.getContext('2d'); bx.drawImage(shadowOf(Cn,d.shadow*res*1.3,.4),0,0);
			if(d.litter) bx.drawImage(body(W,H,res,b=>d.litter(b,R2,v)),0,0);
			bx.drawImage(finish(B,{res,grime:d.grime,shadow:d.baseShadow||3,rim:d.rim}),0,0); files[name]=base; variants.push(name);
			const cname=id+'_canopy'+(v?'_v'+v:'')+'.png'; files[cname]=finish(Cn,{res,grime:d.grime,shadow:0,rim:d.rim}); canopies.push(cname); continue; }
		let B; if(d.wreck){ const src=renderWreck(CARS_WRECK[v],res); B=canvas(W,H); B.getContext('2d').drawImage(src,(W-src.width)/2,(H-src.height)/2); }
		else B=body(W,H,res,b=>d.draw(b,R,v));
		if(v===0){ first=B; hullCv=d.core?body(W,H,res,b=>d.core(b)):B; }
		files[name]=finish(B,{res,grime:d.grime,shadow:d.shadow,rim:d.rim}); variants.push(name); }
	const hull=A.hull(hullCv,res,{max:10}), sizePx=A.bounds(first,res);
	let leaves=null; if(d.leaves){ const cell=Math.round(LEAF_CELL*res), strip=canvas(cell*4,cell), sx=strip.getContext('2d');
		for(let k=0;k<4;k++){ const Rk=rng(7000+k*17+id.charCodeAt(0)); sx.drawImage(finish(body(cell,cell,res,x=>d.leaves(x,Rk,k)),{res,grime:0,shadow:0,rim:false}),k*cell,0); }
		files[id+'_leaves.png']=strip; leaves=id+'_leaves.png'; }
	const cls=d.cls, occluder=d.occluder!=null?d.occluder:(cls==='TALL'||cls==='WALL');
	let breakable=null;
	if(d.breakable){ const b=d.breakable, [bw,bh]=sizeFor(b.box||d.box,res,pad), R=rng(4000+id.charCodeAt(0));
		files[id+'_broken.png']=finish(body(bw,bh,res,x=>b.broken(x,R)),{res,grime:d.grime,shadow:b.rim===false?1.5:2,rim:b.rim===false?false:d.rim,shadowA:.3});
		const cell=Math.round(b.cell*res), strip=canvas(cell*4,cell), sx=strip.getContext('2d');
		for(let k=0;k<4;k++){ const Rk=rng(5000+k*17+id.charCodeAt(0)); sx.drawImage(finish(body(cell,cell,res,x=>b.debris(x,Rk,k)),{res,grime:d.grime,shadow:1.5,shadowA:.35}),k*cell,0); }
		files[id+'_debris.png']=strip;
		breakable={smashSpeed:b.smashSpeed,broken:id+'_broken.png',debris:id+'_debris.png',debrisCells:4}; if(b.blastOnly) breakable.blastOnly=true; }
	let beacon=null; if(d.beacon){ files[id+'_beacon.png']=body(W,H,res,b=>d.beacon(b)); beacon=id+'_beacon.png'; }
	/* an overlay: a strip of frames the size of the sprite (same centre), shown by a child sprite (the den's loot sacks) */
	let overlays=null; if(d.overlay){ const o=d.overlay, strip=canvas(W*o.frames,H), sx=strip.getContext('2d');
		for(let k=0;k<o.frames;k++){ const Rk=rng(8000+k*17+id.charCodeAt(0)); sx.drawImage(finish(body(W,H,res,x=>o.draw(x,Rk,k)),{res,grime:d.grime,shadow:1.5,rim:d.rim,shadowA:.35}),k*W,0); }
		const name=id+'_'+o.name+'.png'; files[name]=strip; overlays={[o.name]:{path:name,frames:o.frames}}; }
	/* extra states the code may adopt later (a toppled saguaro): a sprite ({box, draw}) or a 4-cell strip ({cell, strip}) */
	let states=null; if(d.states){ states={}; for(const name in d.states){ const st=d.states[name], Rs=rng(9000+name.length*31+id.charCodeAt(0)), file=id+'_'+name+'.png';
		if(st.strip){ const cell=Math.round(st.cell*res), strip=canvas(cell*4,cell), sx=strip.getContext('2d'); for(let k=0;k<4;k++) sx.drawImage(finish(body(cell,cell,res,x=>st.strip(x,Rs,k)),{res,grime:d.grime,shadow:1.5,shadowA:.35}),k*cell,0); files[file]=strip; }
		else { const [sw,sh]=sizeFor(st.box,res,pad); files[file]=finish(body(sw,sh,res,x=>st.draw(x,Rs)),{res,grime:d.grime,shadow:st.shadow||d.shadow,rim:d.rim}); }
		states[name]=file; } }
	const tags=Object.assign({},d.tags||{}); delete tags.bait; if(d.tags&&d.tags.bait) tags.bait=true;
	return {files,meta:{class:cls,res,variants,hull,sizePx,occluder,breakable,explosive:!!d.explosive,tags,solid:d.solid!==false,beacon,canopy:canopies.length?canopies:null,leaves,overlays,states}}; }
const PROP_IDS=Object.keys(PROPS).filter(k=>PROPS[k].cls!=='DECOR'), DECOR_IDS=Object.keys(PROPS).filter(k=>PROPS[k].cls==='DECOR');

/* ---------- station set piece: tiles, wall strip and two sprites (replace the photo textures) ---------- */
const STATION={
station_lot(){ const S=GROUND_TEXELS, base=C('#858179'), dark=C('#6c675f'), joint=C('#56514a'), SL=256;
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const sx=(i/SL)|0, sy=(j/SL)|0, t=(hash2(sx,sy,601)-.5)*.08, n=fbm(u*5,v*5,602,4,5), m=fbm(u*32,v*32,603,2,32), st=fbm(u*3,v*3,604,3,3);
		let c=mixc(dark,base,.35+.65*smooth(.25,.6,n)); c=shade(c,t+(m-.5)*.06-smooth(.6,.8,st)*.14); const jd=Math.min(i%SL,SL-i%SL,j%SL,SL-j%SL);
		if(jd<1.5) c=mixc(c,joint,.85); else if(jd<3) c=shade(c,.05); put(o,c); jitter(o,i,j,605,14); });
	const x=cv.getContext('2d');
	scatter(x,S,S,16,606,50,(c,R)=>{ ell(c,0,0,8+R()*26,6+R()*16,R()*3); c.fillStyle='rgba(26,22,20,'+(.12+R()*.18)+')'; c.fill(); });
	scatter(x,S,S,6,607,30,(c,R)=>{ c.rotate(R()*TAU); for(const s of [-1,1]){ c.beginPath(); c.moveTo(-60,s*9); c.bezierCurveTo(-20,s*11,20,s*7,60,s*10); c.lineWidth=5; c.strokeStyle='rgba(20,18,18,.18)'; c.stroke(); } });
	scatter(x,S,S,14,608,50,(c,R)=>crackWalk(c,R,6+(R()*10|0),.8,'rgba(48,44,40,.5)',false));
	overlayGrime(x,S,S,.18); return cv; },
station_roof(){ const S=GROUND_TEXELS, base=C('#6e4c40'), RH=32, TW=48;
	const cv=pixels(S,S,(u,v,i,j,o)=>{ const row=(j/RH)|0, off=(row%2)*TW/2, tab=(((i+off)/TW)|0)%(S/TW), t=hash2(tab,row,611), k=j%RH, n=fbm(u*8,v*8,612,3,8), mo=fbm(u*4,v*4,613,3,4);
		let c=shade(base,(t-.5)*.18+(n-.5)*.1); if(k>RH-5) c=shade(c,-.32*(k-(RH-5))/5); if(k<2) c=shade(c,.08); if((i+off)%TW<1.5) c=shade(c,-.3);
		if(t>.93) c=mixc(c,C('#3a2a24'),.7); c=mixc(c,C('#5c6a3a'),smooth(.66,.78,mo)*.55); put(o,c); jitter(o,i,j,614,16); });
	overlayGrime(cv.getContext('2d'),S,S,.2); return cv; },
station_wall(){ const base=C('#9a958b');
	return pixels(EW,EH,(u,v,i,j,o)=>{ const n=fbm(u*32,v*6,621,3,32,0), blk=(i/64)|0, t=(hash2(blk,0,622)-.5)*.1; let c,a=1;
		if(j<34){ c=shade(base,t+(n-.5)*.12); if(i%64<2) c=shade(c,-.32); if(j<3||j>30) c=shade(c,-.22); else if(j>8&&j<26) c=shade(c,.05); }
		else { c=[18,13,16]; a=.5*(1-smooth(34,80,j)); }
		put(o,c); o[3]=a*255; if(j<34) jitter(o,i,j,623,10); }); },
station_lamp(){ const res=PROP_RES, [W,H]=sizeFor([150,70],res,8); return finish(body(W,H,res,c=>{ vol(c,-52,0,10,10,'#5c5e60',{hi:.35}); limb(c,[-52,0],[34,0],6,'#6d6f72');
	c.beginPath(); rr(c,22,-14,48,28,8); c.fillStyle='#3a3c3e'; c.fill(); c.beginPath(); rr(c,27,-9,38,18,6); const g=c.createLinearGradient(27,0,65,0); g.addColorStop(0,'#f2e2b8'); g.addColorStop(1,'#d8c08a'); c.fillStyle=g; c.fill(); glowAt(c,46,0,24,'#ffe2a8',.35); }),{res,grime:.2,shadow:4}); },
station_pump(){ const res=PROP_RES, [W,H]=sizeFor([260,120],res,10); return finish(body(W,H,res,c=>{ c.scale(1.3,1.3); PROPS.gaspump.draw(c,rng(631),0); }),{res,grime:.25,shadow:6}); }
};
function renderStation(name){ return STATION[name](); }

/* ---------- posters: 1792x1024 top-down vignettes of each level's signature, from the same generators ---------- */
const PW=1792, PH=1024, PSC=.75, WW=PW/PSC, WH=PH/PSC;   /* poster px per world px; the window is 2389 x 1365 world px */
const FOAM=[216,214,200], AOC=[18,13,16];
function n1(x,s){ return fbm(x,0,s,4); }
function bandDist(Y,yc,hw){ return Math.abs(Y-yc)-hw; }
/* a rutted dirt track d px from its centre line: half width hw, wheel ruts ro px out (Road Atlas posters) */
function rutsAt(o,d,hw,ro,X,Y,seed){ if(d<hw){ o.a='dirt'; o.b=fbm(X*.008,Y*.008,seed,2)>.62?'mud':null; o.t=.6; o.tint=[1.02,1,.95]; o.lip=0; if(Math.abs(d-ro)<9) o.tint=[.84,.82,.78]; }
	else if(d<hw+14) o.ao=Math.max(o.ao,.12*(1-(d-hw)/14)); }
/* signed distance into an axis-aligned rect (negative outside) */
function rectE(X,Y,x0,y0,x1,y1){ const e=Math.min(X-x0,x1-X,Y-y0,y1-Y); if(e>=0) return e; const dx=Math.max(x0-X,0,X-x1), dy=Math.max(y0-Y,0,Y-y1); return -Math.hypot(dx,dy); }
/* a building e px inside its outline: roof material, a lit eave and the roof's own shade inside it; AO on the ground
   around it. true when the point is on the roof */
function bldg(o,e,mat){ if(e>=0){ o.a=mat; o.b=null; o.t=0; o.tint=null; o.paint=null; o.foam=0; o.wet=0; o.ao=0; o.lip=0; if(e<5) o.lip=.35*(1-e/5); else if(e<16) o.ao=.22*(1-(e-5)/11); return true; }
	if(e>-18) o.ao=Math.max(o.ao,.55*(1+e/18)); return false; }
const POSTER={
prairie:{mats:['grass','moss','dirt','shallows','water','mud'],seed:11,
	creek(X){ return 700+160*Math.sin(X*.0024+.6)+120*(n1(X*.0015,701)-.5); },
	track(X){ return 1230-X*.42+70*Math.sin(X*.0035); },
	ford(){ if(this._ford!=null) return this._ford; let best=1500,bd=1e9; for(let X=900;X<2100;X+=4){ const d=Math.abs(this.creek(X)-this.track(X)); if(d<bd){ bd=d; best=X; } } return this._ford=best; },
	ground(X,Y,o){ const n=fbm(X*.003,Y*.003,702,4), fd=Math.exp(-Math.pow((X-this.ford())/260,2));
		if(n>.6){ o.b='moss'; o.t=smooth(.6,.7,n); }
		if(X>1640&&Y>840){ const st=Math.floor((X-1640)/56)%2; o.tint=st?[1.06,1.04,.94]:[.97,.97,.95]; }
		const dt=Math.abs(Y-this.track(X)), rut=Math.abs(dt-26); if(dt<60){ o.b='dirt'; o.t=.25*smooth(60,30,dt); o.tint=[1.03,1.01,.94]; } if(rut<14){ o.b='dirt'; o.t=smooth(14,5,rut)*.95; }
		const hw=72+30*fbm(X*.004,5,703,3), d=bandDist(Y,this.creek(X),hw);
		if(d<70&&d>=0){ o.wet=smooth(70,0,d)*.5; if(d<26){ o.b='mud'; o.t=smooth(26,6,d)*.8; } }
		if(d<0){ const depth=-d; o.a='shallows'; o.b='water'; o.t=smooth(16,46,depth)*(1-fd*.97); o.wet=0; if(fd>.5&&fbm(X*.05,Y*.05,705,2)>.55) o.paint=[150,140,112,.35*fd]; if(rut<14) o.paint=[110,92,64,.3*smooth(14,5,rut)]; }
		if(Math.abs(d)<5){ o.foam=.55*(1-Math.abs(d)/5)*smooth(.35,.6,fbm(X*.05,Y*.05,704,2)); } },
	dress(p){ const R=p.rng, fx=this.ford();
		const T=X=>this.track(X), ang=X=>Math.atan2(T(X+10)-T(X),10);
		const trk=[]; for(let X=860;X<=1360;X+=20) trk.push([X,T(X)]); p.tracks(trk,9,.28,24);
		p.car('sedan',1380,T(1380),ang(1380),1);
		for(let X=1660;X<WW;X+=48) if(Math.abs(X-2000)>70) p.prop('hedge',X+24,820,0,X%96<48?0:1,.5);
		for(let Y=880;Y<WH;Y+=150) p.prop('hedge',1630,Y+60,Math.PI/2,0,.5);
		for(let X=80;X<1150;X+=300) p.prop('fence',X+150,330+X*.02,.02,X%600<300?0:1);
		const bales=[[1820,1000],[2010,1110],[2200,960],[2120,1250],[1880,1240]]; bales.forEach((b,i)=>p.prop('haybale',b[0],b[1],i*.7,i%2));
		p.prop('haybale',2290,1150,0,0,1,'broken');
		const oaks=[[130,140],[330,90],[520,210],[240,330],[900,170],[2270,170],[2080,360],[640,1180],[420,1050],[1100,1230],[160,820],[1500,320]];
		oaks.forEach((q,i)=>p.prop('oak',q[0],q[1],i*1.3,i%3,.85+R()*.3));
		p.prop('rock',fx+200,this.creek(fx+200)-140,1,0); p.prop('rock',760,this.creek(760)+150,2,1); p.prop('stump',1180,560,0,1); p.prop('carcass',960,1060,.4,0); p.prop('log',300,this.creek(300)-120,.3,0);
		p.scatterDecor('tufts',140,(X,Y)=>{ const o=p.ground(X,Y); return o.a==='grass'; }); p.scatterDecor('pebbles',30,(X,Y)=>{ const d=bandDist(Y,this.creek(X),90); return d>-10&&d<60; });
		p.scatterDecor('reeds',26,(X,Y)=>{ const d=bandDist(Y,this.creek(X),80); return d>-30&&d<0&&Math.abs(X-fx)>180; });
		p.goon('jackalope',1900,900,2.2,1); p.goon('jackalope',2050,1180,3.6,4); p.goon('tusker',1560,640,2.8,2); p.goon('bandit',1000,1030,.6,3); p.goon('grunt',600,300,1.2,0); p.goon('grunt',700,380,1.6,5); p.goon('hubcap',520,420,.8,2); }},
bayou:{mats:['moss','mud','grass','shallows','water','bridge'],seed:23,
	lake(X,Y){ return fbm(X*.0013,Y*.0016,711,5)+(.5-Math.abs(fbm(X*.0009,Y*.0012,712,3)-.5))*.25; },
	ground(X,Y,o){ const L=this.lake(X,Y), m=fbm(X*.004,Y*.004,713,3);
		o.a='moss'; if(m>.55){ o.b='grass'; o.t=smooth(.55,.66,m)*.7; }
		if(L>.5){ o.b='mud'; o.t=smooth(.5,.56,L)*.85; o.wet=smooth(.52,.58,L)*.4; }
		if(L>.58){ o.a='shallows'; o.b='water'; o.t=smooth(.6,.66,L); o.wet=0; }
		if(Math.abs(L-.58)<.004) o.foam=.4*(1-Math.abs(L-.58)/.004)*smooth(.3,.6,fbm(X*.04,Y*.04,714,2));
		const bw=Math.abs(Y-700-X*.06); if(X>520&&X<1900&&bw<46){ o.a='bridge'; o.b=null; o.t=0; o.wet=0; o.foam=0; if(bw>40) o.ao=.6; }
		else if(X>520&&X<1900&&bw<70&&L>.58) o.ao=.35*smooth(70,46,bw); },
	dress(p){ const R=p.rng;
		for(let X=540;X<1900;X+=60) for(const s of [-1,1]) p.dot(X,700+X*.06+s*44,7,'#3a2c20');
		p.car('pickup',1180,700+1180*.06,.06,0); const trk=[]; for(let X=700;X<1150;X+=20) trk.push([X,700+X*.06]); p.tracks(trk,9,.18,26);
		const water=(X,Y)=>this.lake(X,Y)>.6, bank=(X,Y)=>{ const L=this.lake(X,Y); return L>.5&&L<.6; };
		p.scatterProp('cypress',14,bank,(X,Y,i)=>[i*1.7,i%2,.8+R()*.4]); p.scatterDecor('reeds',60,(X,Y)=>{ const L=this.lake(X,Y); return L>.56&&L<.64; });
		p.scatterProp('log',4,water,(X,Y,i)=>[R()*3,i%2,.7]); p.scatterDecor('tufts',60,(X,Y)=>this.lake(X,Y)<.48);
		for(let i=0;i<40;i++){ const X=R()*WW, Y=R()*WH; if(this.lake(X,Y)>.63) p.lily(X,Y,10+R()*12); }
		const sh=p.find(bank,R); if(sh) p.prop('shack',sh[0],sh[1],.3,1,.8); p.scatterProp('barrel',3,bank,()=>[R()*3,0,1]); p.scatterProp('tyres',2,bank,()=>[R()*3,2,1]); p.scatterProp('stump',4,bank,()=>[R()*3,0,1]); p.scatterProp('totem',1,bank,()=>[0,0,1]);
		const lg=p.find(water,R); if(lg) p.goon('snapper',lg[0]+60,lg[1],R()*6,2);
		p.scatterGoon('spitter',2,bank); p.scatterGoon('bandit',2,(X,Y)=>this.lake(X,Y)<.5); p.scatterGoon('splitter',2,(X,Y)=>this.lake(X,Y)<.5); p.scatterGoon('skink',2,bank); }},
canyon:{mats:['sand','dirt','wash','rock','gravel'],seed:31,
	red:[1.13,.9,.8],
	canyonY(X){ return 260+X*.18+90*Math.sin(X*.003)+60*(n1(X*.002,721)-.5); },
	washY(X){ return 860+70*Math.sin(X*.0022+1)+40*(n1(X*.003,722)-.5); },
	mesa(X,Y){ const dx=(X-420)/360, dy=(Y-1160)/260; return 1-Math.hypot(dx,dy)+(fbm(X*.006,Y*.006,723,3)-.5)*.35; },
	ground(X,Y,o){ o.a='dirt'; o.tint=this.red; const s=fbm(X*.002,Y*.002,724,3); if(s>.55){ o.b='sand'; o.t=smooth(.55,.65,s); }
		const wd=bandDist(Y,this.washY(X),110+20*fbm(X*.004,1,725,2)); if(wd<0){ o.b='wash'; o.t=smooth(0,-30,wd); } else if(wd<40) o.ao=.12*(1-wd/40);
		const cd=bandDist(Y,this.canyonY(X),150+30*fbm(X*.003,2,726,3));
		if(cd<0){ const dep=-cd, WALL=56; o.a='rock'; o.b=null; o.t=0;
			if(dep<WALL){ const band=Math.floor((dep+6*fbm(X*.01,Y*.01,727,2))/9)%3; o.tint=[[1.08,.8,.66],[.96,.7,.58],[1.14,.86,.7]][band]; o.ao=.15+.55*(dep/WALL); }
			else { o.b='dirt'; o.t=.6; o.tint=[.9,.7,.6]; o.ao=.7-.45*smooth(WALL,WALL+120,dep); } }
		else if(cd<18){ o.a='rock'; o.b=null; o.t=0; o.tint=[1.22,.96,.82]; o.lip=.55*(1-cd/18); }
		const m=this.mesa(X,Y); if(m>.09){ o.a='rock'; o.b='sand'; o.t=.3; o.tint=[1.18,.9,.78]; if(m<.13) o.lip=.6*(1-(m-.09)/.04); }
		else if(m>0){ const band=Math.floor(m/.022)%3; o.a='rock'; o.b=null; o.t=0; o.tint=[[1.08,.8,.66],[.96,.7,.58],[1.14,.86,.7]][band]; o.ao=.1+.35*(1-m/.09); }
		else if(m>-.1){ o.ao=Math.max(o.ao,.75*(1+m/.1)); o.b=o.b||'gravel'; o.t=Math.max(o.t,.4); } },
	dress(p){ const R=p.rng, W=X=>this.washY(X), ang=X=>Math.atan2(W(X+10)-W(X),10);
		const trk=[]; for(let X=700;X<=1250;X+=20) trk.push([X,W(X)+8]); p.tracks(trk,10,.22,26); p.dust(1180,W(1180)+10,90);
		p.car('racer',1280,W(1280)+8,ang(1280),0);
		const open=(X,Y)=>{ const o=p.ground(X,Y); return o.a!=='rock'&&o.ao<.1&&bandDist(Y,W(X),130)>0; };
		p.scatterProp('saguaro',9,open,(X,Y,i)=>[R()*6,i%2,.9+R()*.3]); p.scatterProp('deadtree',2,open,()=>[R()*6,0,.8]);
		for(let i=0;i<7;i++){ const X=200+i*330+R()*80, Y=this.canyonY(X)+ (i%2?190:-190); p.prop(i%3?'rock':'boulder',X,Y,R()*6,i%2,.7+R()*.3); }
		const cc=[1700,1180]; p.prop('carcass',cc[0],cc[1],.3,0); p.goon('buzzard',cc[0]+10,cc[1]-10,1,2);
		p.prop('tent',2150,1120,0,0,.8); p.prop('totem',2000,1010,0,1); p.prop('firepit',2160,970,0,0); p.prop('tyres',2280,980,1,0);
		p.scatterDecor('bones',16,open); p.scatterDecor('pebbles',40,open); p.scatterDecor('cracks',12,(X,Y)=>bandDist(Y,W(X),100)<0);
		p.goon('rattler',900,1060,.4,2); p.goon('stinger',1500,700,2.2,1); p.goon('yipper',1050,640,.3,3); p.goon('yipper',1120,600,.5,5); p.goon('torch',2050,1060,2.6,0); p.goon('quill',600,700,1.4,2); }},
quarry:{mats:['dirt','gravel','rock','mud','mudpit','lot'],seed:41,
	C0:[1300,640],
	pit(X,Y){ const a=Math.atan2(Y-this.C0[1],X-this.C0[0]), r=Math.hypot(X-this.C0[0],(Y-this.C0[1])*1.25); return r*(1+(fbm(Math.cos(a)*2+5,Math.sin(a)*2+5,731,3)-.5)*.28); },
	ramp(X,Y){ const ax=Math.cos(-.5), ay=Math.sin(-.5), dx=X-this.C0[0], dy=Y-this.C0[1], t=dx*ax+dy*ay, s=Math.abs(-dx*ay+dy*ax); return t>60?s:1e9; },
	ground(X,Y,o){ o.a='dirt'; const g=fbm(X*.003,Y*.003,732,3); if(g>.55){ o.b='gravel'; o.t=smooth(.55,.66,g)*.8; }
		const r=this.pit(X,Y), rp=this.ramp(X,Y), onRamp=rp<80; const rings=[460,330,200];
		if(r<rings[0]){ o.a='gravel'; o.b='rock'; o.t=.5; o.tint=[.98,.97,.95]; let lvl=0; for(const q of rings) if(r<q) lvl++;
			o.ao=.12*lvl; if(lvl>=3){ o.a='mud'; o.b='mudpit'; o.t=smooth(150,90,r); o.ao=.3; }
			if(!onRamp) for(const q of rings){ const e=r-q; if(e>-34&&e<0) o.ao=Math.max(o.ao,.8*(1+e/34)); if(e>=0&&e<14) o.lip=.6*(1-e/14); } }
		if(onRamp&&r<rings[0]+40){ o.a='dirt'; o.b=null; o.t=0; o.lip=0; o.ao=.1+.2*smooth(rings[0],0,r); if(rp>66) o.ao=.5; }
		const hd=Math.abs(Y-(this.C0[1]-Math.tan(.5)*(X-this.C0[0]))); if(X>this.C0[0]+380&&hd<70){ o.a='dirt'; o.b='lot'; o.t=.25; const rut=Math.abs(hd-26); if(rut<8) o.tint=[.85,.82,.78]; }
		const fd=Math.hypot(X-330,Y-420); if(fd<250){ o.b='mud'; o.t=.35; } },
	dress(p){ const R=p.rng, C0=this.C0, fx=330, fy=420, fr=262;
		for(let i=0;i<22;i++){ const a=i/22*TAU; if(Math.abs(Math.sin(a-.3))<.12) continue; if(Math.abs(Math.sin(a+1.2))<.1) continue; p.prop('fortwall',fx+Math.cos(a)*fr,fy+Math.sin(a)*fr,a+Math.PI/2,i%2,.6); }
		for(const a of [.3,.3+Math.PI,-1.2,-1.2+Math.PI]) p.prop('totem',fx+Math.cos(a)*(fr+40),fy+Math.sin(a)*(fr+40),0,a>0?0:1);
		p.prop('tent',fx-80,fy-60,0,0,.8); p.prop('tent',fx+90,fy+40,1,1,.75); p.prop('firepit',fx,fy+20,0,0); p.prop('tyres',fx-110,fy+110,0,1); p.prop('crate',fx+40,fy-120,.3,1);
		p.prop('crane',C0[0]-120,C0[1]-560,.3,0,.85); p.prop('scrapheap',2200,1200,0,0,.9); p.prop('scrapheap',2330,1000,1,2,.7);
		for(let i=0;i<7;i++){ const a=R()*TAU, rr2=230+R()*200; p.prop('rock_white',C0[0]+Math.cos(a)*rr2,C0[1]+Math.sin(a)*rr2/1.25,R()*6,i%2,.5+R()*.3); }
		p.scatterProp('barrel',5,(X,Y)=>this.pit(X,Y)>500&&Math.hypot(X-fx,Y-fy)>300,()=>[R()*3,(R()*3)|0,1]);
		const hy=X=>C0[1]-Math.tan(.5)*(X-C0[0]); p.car('semi',1950,hy(1950)+26,-.5+Math.PI,0); const trk=[]; for(let X=2350;X>2050;X-=20) trk.push([X,hy(X)+26]); p.tracks(trk,10,.2,30);
		p.scatterDecor('pebbles',40,(X,Y)=>this.pit(X,Y)<460); p.scatterDecor('cracks',10,(X,Y)=>this.pit(X,Y)>500);
		p.goon('grunt',fx+300,fy-40,0,1); p.goon('grunt',fx+330,fy+30,.3,4); p.goon('spiker',fx+280,fy+90,-.2,2); p.goon('foreman',fx+120,fy-200,.6,0);
		p.goon('wrecker',C0[0]+260,C0[1]-90,2.6,2); p.goon('rammer',C0[0]+40,C0[1]+60,-.8,3); p.goon('doomcart',1800,240,.4,1); }},
frostbite:{mats:['snow','deepsnow','ice','rock'],seed:53,
	road(X){ return 660+120*Math.sin(X*.0019+.4)+50*(n1(X*.003,741)-.5); },
	ridge(X,Y){ const top=smooth(470,60,Y)*1.0, bot=smooth(1000,1365,Y)*smooth(1400,500,X)*1.0; return top+bot+(fbm(X*.004,Y*.004,742,4)-.5)*.55+(1-Math.abs(2*fbm(X*.0025,Y*.0025,743,3)-1))*.2; },
	lake(X,Y){ return 1-Math.hypot((X-1850)/430,(Y-1080)/230)+(fbm(X*.005,Y*.005,744,3)-.5)*.3; },
	ground(X,Y,o){ o.a='snow'; const ds=fbm(X*.003,Y*.003,745,3); if(ds>.52){ o.b='deepsnow'; o.t=smooth(.52,.62,ds); }
		const rd=bandDist(Y,this.road(X),90); if(rd<0){ o.b=null; o.t=0; o.tint=[.97,.97,.98]; const rut=Math.abs(Math.abs(Y-this.road(X))-26); if(rut<8) o.tint=[.92,.93,.95]; } else if(rd<30) o.lip=.25*(1-rd/30);
		const L=this.lake(X,Y); if(L>0){ o.a='ice'; o.b=null; o.t=0; o.tint=null; } else if(L>-.1){ o.lip=.5*(1+L/.1)*(L<-.04?1:0); if(L>-.04) o.ao=.35*(1+L/.04); }
		const r=this.ridge(X,Y), thr=.6, STEP=.13; if(r>thr){ const q=(r-thr)/STEP, k=Math.floor(q), u=q-k; o.a='rock'; o.b='snow'; o.t=smooth(thr+STEP*1.2,thr+STEP*2.4,r)*.92; o.tint=[1-k*.0,1,1].map(v=>v+k*.04); o.ao=0;
			if(u>.78&&k<3) o.ao=.55*(u-.78)/.22; if(u<.14) o.lip=.55*(1-u/.14); }
		else if(r>thr-.07){ o.ao=Math.max(o.ao,.55*smooth(thr-.07,thr,r)); } },
	dress(p){ const R=p.rng, RD=X=>this.road(X), ang=X=>Math.atan2(RD(X+10)-RD(X),10);
		const trk=[]; for(let X=420;X<=980;X+=20) trk.push([X,RD(X)-26],[X,RD(X)+26]); p.tracks(trk.filter((q,i)=>i%2===0),9,.2,26); p.tracks(trk.filter((q,i)=>i%2===1),9,.2,26);
		p.car('van',1000,RD(1000),ang(1000),1);
		const free=(X,Y)=>{ const o=p.ground(X,Y); return (o.a==='snow')&&bandDist(Y,RD(X),130)>0; };
		for(let k=0;k<4;k++){ const c=p.find(free,R); if(!c) continue; for(let i=0;i<6;i++){ const X=c[0]+(R()-.5)*300, Y=c[1]+(R()-.5)*200; if(free(X,Y)) p.prop('pine',X,Y,R()*6,R()<.6?2:(i%2),.8+R()*.4); } }
		p.prop('cabin',1500,880,.15,0,.8); p.prop('snowcat',700,980,-.4,0,.9); p.prop('firepit',1320,960,0,0);
		p.scatterProp('rock_ice',4,(X,Y)=>{ const L=this.lake(X,Y); return L>-.15&&L<-.02; },()=>[R()*6,(R()*2)|0,.6+R()*.3]); p.scatterProp('rock_white',3,free,()=>[R()*6,1,.6]);
		p.goon('yeti',1350,760,2.9,2); p.goon('jackalope',820,820,.4,1); p.goon('jackalope',870,880,.6,5); p.goon('skink',1950,1050,2,3); p.goon('sawbot',300,560,.2,2); p.goon('bullmoose',2100,600,3.3,1); }},
highway:{mats:['asphalt','sand','dirt','gravel','lot','oil'],seed:61,
	hy(X){ return 560+70*Math.sin(X*.0013); },
	ground(X,Y,o){ o.a='sand'; o.tint=[1.04,1,.96]; const s=fbm(X*.003,Y*.003,751,3); if(s<.42){ o.b='dirt'; o.t=smooth(.42,.34,s)*.7; }
		const y0=this.hy(X), d=Math.abs(Y-y0);
		if(d<230){ o.a='asphalt'; o.b=null; o.t=0; o.tint=null; const L=(Y-y0);
			if(Math.abs(Math.abs(L)-6)<3) o.paint=[216,197,138,.85]; if(Math.abs(Math.abs(L)-218)<4) o.paint=[214,210,198,.8];
			if(Math.abs(Math.abs(L)-112)<3&&((X%120)<64)) o.paint=[214,210,198,.75]; const oi=fbm(X*.006,Y*.006,752,3); if(oi>.66){ o.b='oil'; o.t=smooth(.66,.72,oi)*.85; } }
		else if(d<290){ o.a='gravel'; o.ao=.15*smooth(290,230,d); }
		const bx=X-(Y-y0)*.55; if(Y>y0+230&&Math.abs(bx-520)<70&&Y<1040){ o.a='asphalt'; o.b=null; o.tint=null; o.paint=null; }
		if(X>120&&X<900&&Y>1020&&Y<WH){ o.a='lot'; o.b=null; o.tint=null; o.paint=null; if(Math.abs(Y-1020)<6) o.ao=.3; } },
	dress(p){ const R=p.rng, H=X=>this.hy(X), ang=X=>Math.atan2(H(X+10)-H(X),10);
		const sk=[]; for(let X=820;X<=1240;X+=20) sk.push([X,H(X)+60+Math.sin((X-820)*.012)*40]); p.tracks(sk,10,.3,24);
		p.car('taxi',1250,H(1250)+62,ang(1250)+.25,0); p.car('sedan',1900,H(1900)-60,Math.PI+ang(1900),2);
		const pile=[[2000,H(2000)+70,.8,0],[2100,H(2100)-10,2.2,1],[2220,H(2220)+120,-.6,2],[2160,H(2160)+150,1.4,3]]; pile.forEach(w=>p.prop('wreck',w[0],w[1],w[2],w[3]));
		for(let i=0;i<6;i++) p.prop('cone',1720+i*40,H(1720+i*40)+(i%2?-30:30),R()*3,i%2); p.prop('barrel',2060,H(2060)-90,0,0); p.prop('tyres',2300,H(2300)+40,1,2); p.prop('barricade',1820,H(1820)+150,.3,0);
		for(let X=200;X<1500;X+=330) p.prop('jersey',X,H(X),ang(X),X%660<330?0:1,.95);
		p.prop('billboard',700,H(700)-330,ang(700),0); p.prop('gaspump',360,1150,0,0); p.prop('gaspump',620,1150,0,1); p.prop('shack',300,1300,0,0,.6); p.prop('sign',980,H(980)+270,0,1); p.prop('sign',150,H(150)-270,1.2,2);
		const desert=(X,Y)=>Math.abs(Y-H(X))>320&&!(X<920&&Y>990);
		p.scatterProp('saguaro',8,desert,(X,Y,i)=>[R()*6,i%2,.8+R()*.3]); p.scatterProp('rock',4,desert,()=>[R()*6,(R()*3)|0,.6]); p.scatterDecor('bones',8,desert); p.scatterDecor('pebbles',30,desert);
		p.scatterDecor('oilstain',8,(X,Y)=>Math.abs(Y-H(X))<200); p.prop('carcass',1500,1150,.5,1);
		p.goon('karter',1500,H(1500)+40,ang(1500),1); p.goon('spoke',1580,H(1580)-80,ang(1580)+.2,3); p.goon('chainer',2350,H(2350)-120,Math.PI,2); p.goon('slick',2300,H(2300)+260,Math.PI+.3,0); p.goon('spiker',1650,H(1650)+180,-1.2,2); p.goon('buzzard',2150,H(2150)+60,1,4); }},
city:{mats:['asphalt','lot','roof','grass','water','bridge'],seed:71,grade:'dusk',
	SX:[600,1560], SY:[330,1000], SW:110, PV:150,
	blocks(){ if(this._b) return this._b; const xs=[[0,450],[750,960],[1200,1410],[1710,WW]], ys=[[0,180],[480,850],[1150,WH]], kinds=[['B','B','B','B'],['P','B','P','L'],['B','L','B','B']], out=[];
		ys.forEach((yy,j)=>xs.forEach((xx,i)=>out.push({x0:xx[0],x1:xx[1],y0:yy[0],y1:yy[1],k:kinds[j][i]}))); return this._b=out; },
	ground(X,Y,o){ const SW=this.SW, PV=this.PV; let street=false, walk=false;
		for(const q of this.SX){ const e=Math.abs(X-q); if(e<SW) street=true; else if(e<PV) walk=true; } for(const q of this.SY){ const e=Math.abs(Y-q); if(e<SW) street=true; else if(e<PV) walk=true; }
		const canal=Math.abs(X-1080)<120;
		if(street){ o.a='asphalt'; for(const q of this.SX){ const e=Math.abs(X-q); if(e<SW&&e>SW-10) o.ao=.45*(e-(SW-10))/10; if(e<3&&(Y%110)<60&&Math.abs(Y-330)>SW&&Math.abs(Y-1000)>SW) o.paint=[216,197,138,.7]; }
			for(const q of this.SY){ const e=Math.abs(Y-q); if(e<SW&&e>SW-10) o.ao=Math.max(o.ao,.45*(e-(SW-10))/10); if(e<3&&(X%110)<60&&Math.abs(X-600)>SW&&Math.abs(X-1560)>SW) o.paint=[216,197,138,.7]; }
			if(canal&&Math.abs(X-600)>=SW&&Math.abs(X-1560)>=SW){ o.a='bridge'; o.paint=null; const e=Math.abs(X-1080); if(e>112) o.ao=.7; } return; }
		if(walk){ o.a='lot'; o.tint=[1.04,1.03,1.0]; let e=1e9; for(const q of this.SX) e=Math.min(e,Math.abs(Math.abs(X-q)-SW)); for(const q of this.SY) e=Math.min(e,Math.abs(Math.abs(Y-q)-SW)); if(e<7) { o.lip=.35; } return; }
		if(canal){ const e=Math.abs(X-1080); o.a='water'; if(e>100){ o.a='lot'; o.tint=[.86,.84,.82]; o.lip=e>114?.3:0; o.ao=e<=114?.6*(e-100)/14:0; } else if(e>94) o.foam=.25; else if(e>80) o.ao=.35*(e-80)/14; return; }
		o.a='lot'; const b=this.blocks().find(q=>X>=q.x0&&X<q.x1&&Y>=q.y0&&Y<q.y1); if(!b) return;
		if(b.k==='P'){ o.a='grass'; const pd=Math.abs((X-b.x0)-(Y-b.y0)*.55-40); if(pd<22){ o.a='lot'; o.tint=[1.05,1.02,.96]; } return; }
		if(b.k==='L'){ o.a='lot'; o.tint=[.94,.93,.92]; if(((X-b.x0)%90)<4&&((Y-b.y0)%250)>30&&((Y-b.y0)%250)<170) o.paint=[214,210,198,.6]; return; }
		const mid=(b.x0+b.x1)/2, alley=b.x1-b.x0>300&&Math.abs(X-mid)<14; if(alley){ o.a='asphalt'; o.ao=.55; return; }
		const bx0=alley?0:(b.x1-b.x0>300?(X<mid?b.x0:mid+14):b.x0), bx1=b.x1-b.x0>300?(X<mid?mid-14:b.x1):b.x1, ins=10;
		const ex=Math.min(X-bx0,bx1-X)-ins, ey=Math.min(Y-b.y0,b.y1-Y)-ins, e=Math.min(ex,ey);
		if(e<0){ o.a='lot'; o.ao=.5; return; }
		o.a='roof'; o.tint=[.88,.88,.9]; if(e<12){ o.a='lot'; o.tint=[1.0,.98,.95]; o.lip=.25+.2*(1-e/12); } else if(e<28) o.ao=.55*(1-(e-12)/16); },
	dress(p){ const R=p.rng, SX=this.SX, SY=this.SY;
		for(const X of SX) for(const Y of SY){ p.lamp(X-136,Y-136,Math.PI/4); p.lamp(X+136,Y+136,-Math.PI*.75); }
		p.lamp(1080,SY[0]-136,Math.PI/2); p.lamp(1080,SY[1]+136,-Math.PI/2);
		const roofs=this.blocks().filter(b=>b.k==='B').map(b=>[(b.x0+b.x1)/2,(b.y0+b.y1)/2,(b.x1-b.x0)/2-40,(b.y1-b.y0)/2-40]); p.roofStuff(roofs,R);
		p.prop('busstop',820,SY[0]-150+14,0,0,.9); p.prop('oak',1290,600,0,0,.7); p.prop('oak',1330,780,1,1,.6); p.prop('oak',160,560,2,2,.7); p.prop('oak',330,770,1,0,.6);
		p.prop('hydrant',470,470,0,0); p.prop('hydrant',1700,860,0,0); p.prop('dumpster',1770,1200,.1,0); p.prop('dumpster',1260,1220,1.4,1);
		p.prop('wreck',1840,600,.2,4,1); p.prop('wreck',1960,760,1.5,0,1); p.prop('wreck',2150,640,.1,1,1);
		p.prop('manhole',600,560,0,0); p.prop('manhole',1560,200,0,0); p.prop('manhole',900,1000,0,0); p.prop('barricade',1560,700,Math.PI/2,1,.8); p.prop('cone',1520,600,0,0); p.prop('cone',1600,610,0,1); p.prop('crate',860,560,.2,2);
		p.scatterDecor('oilstain',8,(X,Y)=>{ for(const q of SY) if(Math.abs(Y-q)<100) return true; return false; }); p.scatterDecor('tufts',20,(X,Y)=>p.ground(X,Y).a==='grass');
		p.car('police',820,SY[1]+50,0,0); p.headlights(820,SY[1]+50,0); p.siren(820,SY[1]+50);
		const trk=[]; for(let X=380;X<760;X+=20) trk.push([X,SY[1]+50]); p.tracks(trk,9,.16,26);
		p.goon('rat',1110,600,1.5,1); p.goon('rat',1140,640,1.7,4); p.goon('rat',1060,700,1.4,6); p.goon('gremlin',1000,1040,3.1,2); p.goon('turret',1560,520,1.6,0); p.goon('magnet',2000,1000,Math.PI,2); p.goon('grunt',460,380,.3,3); p.goon('boostjack',1300,330,3.3,1); }},
crusher:{mats:['dirt','lot','gravel','conveyor','oil'],seed:83,
	ground(X,Y,o){ o.a='dirt'; o.tint=[.92,.9,.88]; const g=fbm(X*.003,Y*.003,761,3); if(g>.5){ o.b='lot'; o.t=smooth(.5,.6,g)*.8; }
		const oi=fbm(X*.004,Y*.004,762,3); if(oi>.64){ o.b='oil'; o.t=smooth(.64,.72,oi)*.8; }
		const hp=1-Math.hypot((X-380)/520,(Y-300)/380)+(fbm(X*.006,Y*.006,763,3)-.5)*.3; if(hp>0){ o.a='gravel'; o.b=null; o.tint=[.62,.58,.55]; o.ao=.35; } else if(hp>-.08) o.ao=.5*(1+hp/.08);
		for(const cy of [760,980]){ const e=Math.abs(Y-cy); if(X>500&&e<70){ o.a='conveyor'; o.b=null; o.tint=null; o.ao=0; if(e>58){ o.a='lot'; o.tint=[.55,.55,.56]; o.ao=0; o.lip=e<64?.35:0; } } } },
	dress(p){ const R=p.rng;
		for(let i=0;i<12;i++){ const a=R()*TAU, d=Math.sqrt(R())*300; p.prop('scrapheap',380+Math.cos(a)*d*1.3,300+Math.sin(a)*d,R()*6,i%3,1.1+R()*.5); }
		for(let r=0;r<3;r++) for(let k=0;k<3;k++) p.prop('container',1500+k*250+(R()-.5)*20,210+r*150+(k%2)*8,(R()-.5)*.04,(r+k)%3,.5);
		p.prop('crane',1300,520,Math.PI*.95,0,.75); for(const t of [[1700,1180],[2000,1160],[2280,1220]]) p.prop('tank',t[0],t[1],R()*6,0,.85); p.prop('tank',1850,1340,0,0,.7,'broken');
		for(let i=0;i<6;i++) p.prop('barrel',1450+R()*200,1150+R()*150,R()*3,(R()*3)|0); p.prop('tyres',1350,1250,0,0); p.prop('tyres',1100,1300,1,1); p.prop('barricade',900,1160,.2,1); p.prop('crate',1000,1220,.6,2);
		for(let X=560;X<WW;X+=160) for(const cy of [760,980]) for(const s of [-1,1]) p.dot(X,cy+s*64,6,'#3a3836');
		p.car('semi',1150,980,0,1); const trk=[]; for(let X=700;X<1080;X+=20) trk.push([X,980]); p.tracks(trk,10,.14,30);
		p.scatterDecor('oilstain',14,(X,Y)=>p.ground(X,Y).a==='dirt'); p.scatterDecor('pebbles',20,(X,Y)=>p.ground(X,Y).a==='dirt');
		p.goon('plowboss',1700,860,Math.PI,2); p.goon('magnet',2200,620,2.4,1); p.goon('shredder',900,620,.6,3); p.goon('sawbot',1250,1150,-.5,2); p.goon('harpooner',600,1100,-.2,4); p.goon('wrecker',1450,700,2,1); }},
/* ---- Road Atlas posters: one per new level (docs/WORLD_ART.md "Posters"). Shared pieces: rutted tracks (rutsAt),
   water bands (wetBand), building blocks (blockAt) and the api's spaced/pack/line helpers ---- */
orchard:{mats:['grass','dirt','mud','moss','gravel'],seed:101,
	laneY(X){ return 700+35*Math.sin(X*.0021+.3); }, laneX(Y){ return 1240+30*Math.sin(Y*.003+1); },
	ground(X,Y,o){ o.a='grass'; const n=fbm(X*.003,Y*.003,1011,3); if(n>.6){ o.b='moss'; o.t=smooth(.6,.7,n)*.6; }
		if(X<1120&&Y>840){ const f=Math.sin((Y+X*.08)*.085)*.5+.5; o.b='dirt'; o.t=.8; o.tint=[1-.1*f,1-.1*f,1-.09*f]; }
		if(X<1120&&Y<580){ const r=Math.abs(((X-40)%150+150)%150-75); if(r>40){ o.tint=[1.05,1.05,.98]; } }
		const d=Math.min(Math.abs(Y-this.laneY(X)),Math.abs(X-this.laneX(Y))); rutsAt(o,d,64,24,X,Y,1012);
		if(d>=64&&d<80) o.ao=.12*(1-(d-64)/16); },
	dress(p){ const R=p.rng, LY=X=>this.laneY(X), LX=Y=>this.laneX(Y), lx=LX(700);
		for(const s of [-1,1]){ for(let X=40;X<WW;X+=300){ if(Math.abs(X+150-lx)<260) continue; if(s>0&&Math.abs(X-400)<160) continue; if(s<0&&Math.abs(X-1700)<160) continue; p.prop('hedge',X+150,LY(X+150)+s*112,Math.atan2(LY(X+160)-LY(X+140),20),(X/300|0)%2,.75); }
			for(let Y=0;Y<WH;Y+=300){ if(Math.abs(Y+150-700)<260) continue; if(s<0&&Math.abs(Y-1100)<160) continue; p.prop('hedge',LX(Y+150)+s*112,Y+150,Math.PI/2,(Y/300|0)%2,.75); } }
		for(let k=0;k<3;k++) for(let j=0;j<7;j++){ const X=115+j*150+(R()-.5)*20, Y=110+k*170+(R()-.5)*20; if(X>1060) continue; p.prop('oak',X,Y,R()*6,(j+k)%3,.45+R()*.06); }
		p.line('fence',1400,180,2300,180,330,.8); p.line('fence',1400,180,1400,520,330,.8); p.line('fence',1400,520,2300,520,330,.8,null,t=>t>.4&&t<.62);
		for(let i=0;i<6;i++) p.prop('beehive',1560+(i%3)*150,280+((i/3)|0)*130,(R()-.5)*.3,i%2,.9);
		p.prop('beehive',1860,420,0,0,1,'broken');
		for(const [X,Y,v] of [[1700,860,0],[1780,900,1],[1730,960,2]]) p.prop('crate',X,Y,R(),v,.9); p.prop('crate',1880,880,0,0,1,'broken');
		for(const b of [[300,980],[560,1120],[860,1000],[420,1260]]) p.prop('haybale',b[0],b[1],R()*3,(b[0]/100|0)%2,.85);
		p.prop('stump',1500,1150,0,1,.9); p.prop('carcass',2050,1180,.6,1,.9); p.prop('oak',2200,1000,1,1,.8); p.prop('oak',1650,1280,2,0,.7);
		p.scatterDecor('tufts',90,(X,Y)=>p.ground(X,Y).a==='grass'&&Math.min(Math.abs(Y-LY(X)),Math.abs(X-LX(Y)))>130);
		const trk=[]; for(let X=200;X<=760;X+=20) trk.push([X,LY(X)+14]); p.tracks(trk,9,.28,22); p.dust(250,LY(250)+14,110);
		p.car('pickup',800,LY(800)+14,Math.atan2(LY(810)-LY(790),20),1);
		for(let i=0;i<5;i++) p.goon('yipper',LX(240+i*70)+(i%2?-30:30),240+i*70+(R()-.5)*20,Math.PI/2+(R()-.5)*.3,i*2);
		p.goon('bandit',1810,830,-2.2,3); p.goon('bandit',1950,960,2.6,5); p.goon('jackalope',520,1000,.4,2); p.goon('jackalope',700,1180,-.6,6); p.goon('jackalope',1060,840,2.4,1);
		p.goon('buzzard',2060,1160,1.2,2); p.goon('buzzard',1500,320,-.4,4); }},
moosewoods:{mats:['needles','grass','moss','dirt','mud'],seed:113,
	clear(X,Y){ return 1-Math.hypot((X-1320)/600,(Y-700)/330)+(fbm(X*.004,Y*.004,1131,3)-.5)*.45; },
	trail(X){ return 1000-X*.24+60*Math.sin(X*.003); },
	ground(X,Y,o){ o.a='needles'; const m=fbm(X*.004,Y*.004,1132,3); if(m>.62){ o.b='moss'; o.t=smooth(.62,.72,m)*.6; }
		const c=this.clear(X,Y); if(c>0){ o.a='grass'; o.b=null; o.t=0; const g=fbm(X*.005,Y*.005,1133,3); if(g>.56){ o.b='moss'; o.t=.5; } } else if(c>-.12){ o.b='grass'; o.t=smooth(-.12,0,c); }
		rutsAt(o,Math.abs(Y-this.trail(X)),50,20,X,Y,1134); },
	dress(p){ const R=p.rng, T=X=>this.trail(X), ang=X=>Math.atan2(T(X+10)-T(X),10);
		p.reserve(1880,420,150); p.reserve(640,930,160);
		p.reserve(1900,700,110); p.spaced('pine',70,(X,Y)=>this.clear(X,Y)<-.06&&Math.abs(Y-T(X))>120,150,(X,Y)=>[R()*6,(R()*2)|0,.85+R()*.3]);
		p.prop('ranger_tower',1880,420,.1,0,.8); p.prop('fallen_trunk',640,930,.5,0,.9); p.prop('fallen_trunk',2150,1200,-.3,1,.8);
		for(const [X,Y] of [[1000,560],[1640,930],[1150,880],[1700,520]]) p.prop('stump',X,Y,R()*3,(X|0)%2,.8); p.prop('log',1450,960,.2,0,.8); p.prop('deadtree',980,420,1,0,.8);
		p.scatterDecor('tufts',60,(X,Y)=>this.clear(X,Y)>.05); p.scatterDecor('pebbles',20,(X,Y)=>Math.abs(Y-T(X))<60);
		const trk=[]; for(let X=380;X<=1060;X+=20) trk.push([X,T(X)]); p.tracks(trk,9,.26,22); p.car('van',1100,T(1100),ang(1100),1);
		for(let i=0;i<6;i++){ const X=1250+i*95+(R()-.5)*40, Y=760+(i%3)*70+(R()-.5)*30; p.goon('thunderhoof',X,Y,Math.PI+.25+(R()-.5)*.2,i); p.dust(X+70,Y+10,80,[150,128,90,.4]); }
		p.goon('bullmoose',1870,700,Math.PI+.15,2); p.dust(1950,690,120,[120,100,72,.45]); for(let i=0;i<5;i++) p.decor('pebbles',1910+R()*60,650+R()*90,R()*6,(R()*4)|0,1);
		p.goon('tusker',900,700,.2,3); p.goon('yipper',1480,460,1.9,1); p.goon('yipper',1550,430,2.1,5); }},
mudlick:{mats:['mud','mudpit','moss','shallows','water','dirt'],seed:127,
	wet(X,Y){ return fbm(X*.0016,Y*.002,1271,5)+(.5-Math.abs(fbm(X*.001,Y*.0013,1272,3)-.5))*.2; },
	track(X){ return 700+120*Math.sin(X*.0018+2)+40*(n1(X*.003,1273)-.5); },
	ground(X,Y,o){ const cd=Math.hypot(X-330,(Y-260)*1.2), W=this.wet(X,Y)-.3*smooth(460,280,cd); o.a='moss'; o.b='mud'; o.t=smooth(.36,.48,W);
		if(W>.5){ o.a='mud'; o.b='mudpit'; o.t=smooth(.52,.58,W)*.9; o.wet=.2; }
		if(W>.61){ o.a='shallows'; o.b='water'; o.t=smooth(.63,.72,W); o.wet=0; }
		if(Math.abs(W-.61)<.004) o.foam=.35*smooth(.3,.6,fbm(X*.04,Y*.04,1274,2));
		if(cd<330&&W<.61){ const k=smooth(330,250,cd); if(k>=1){ o.a='dirt'; o.b='mud'; o.t=.3*fbm(X*.01,Y*.01,1275,2); } else { o.b='dirt'; o.t=k; } o.wet*=1-k; }
		const dt=Math.abs(Y-this.track(X)); if(dt<54){ if(W>.61){ o.a='shallows'; o.b=null; o.t=0; } else { o.a='mud'; o.b='mudpit'; o.t=.4; const rut=Math.abs(dt-22); if(rut<9) o.tint=[.78,.76,.72]; } } },
	dress(p){ const R=p.rng, T=X=>this.track(X), ang=X=>Math.atan2(T(X+10)-T(X),10), dry=(X,Y)=>this.wet(X,Y)<.46&&Math.abs(Y-T(X))>90&&Math.hypot(X-330,Y-260)>330, bank=(X,Y)=>{ const W=this.wet(X,Y); return W>.55&&W<.6; };
		p.prop('tent',220,170,.3,0,.8); p.prop('tent',470,330,1.2,1,.75); p.prop('totem',360,90,0,0); p.prop('firepit',330,280,0,0); p.prop('tyres',140,380,0,1,.9); p.prop('crate',560,170,.4,1,.9);
		for(let i=0;i<9;i++){ const a=.6+i*.32; if(i===4) continue; p.prop('fortwall',330+Math.cos(a)*330,260+Math.sin(a)*300,a+Math.PI/2,i%2,.55); }
		p.spaced('cypress',10,bank,170,(X,Y,i)=>[i*1.7,i%2,.75+R()*.3]); p.scatterProp('deadtree',2,dry,()=>[R()*6,(R()*2)|0,.8]); p.scatterProp('log',3,(X,Y)=>this.wet(X,Y)>.66,()=>[R()*3,(R()*2)|0,.7]);
		p.scatterDecor('reeds',60,(X,Y)=>{ const W=this.wet(X,Y); return W>.57&&W<.65; }); for(let i=0;i<30;i++){ const X=R()*WW, Y=R()*WH; if(this.wet(X,Y)>.68) p.lily(X,Y,10+R()*10); }
		const trk=[]; for(let X=700;X<=1240;X+=20) trk.push([X,T(X)]); p.tracks(trk,11,.35,24); p.car('pickup',1290,T(1290),ang(1290),2);
		for(let i=0;i<4;i++) p.dust(1210-i*30,T(1210-i*30)+(i%2?30:-30),50,[70,56,40,.55]);
		p.goon('splitter',1560,T(1560)-20,Math.PI+.2,2); p.goon('goonling',1610,T(1610)+30,Math.PI,1); p.goon('goonling',1650,T(1650)-50,Math.PI-.4,5); p.goon('goonling',1680,T(1680)+10,Math.PI+.3,3);
		p.goon('splitter',900,T(900)+110,-.4,4); p.goon('shellback',1900,560,2.8,2); p.goon('shellback',2150,980,3.6,6);
		p.goon('grunt',420,200,2.4,1); p.goon('grunt',260,330,.4,3); p.goon('grunt',600,420,-.8,5); p.goon('grunt',760,300,.2,0); }},
stilttown:{mats:['beach','shallows','water','bridge','grass'],seed:131,
	bar(X){ return 980-X*.2+50*Math.sin(X*.0025)+30*(n1(X*.003,1311)-.5); },
	decks:[[220,520,700,560,'h'],[640,250,680,580,'v'],[520,140,780,300,'p'],[1500,220,1540,700,'v'],[1360,90,1680,260,'p'],[1900,140,2389,180,'h'],[2000,40,2200,140,'p']],
	onDeck(X,Y){ for(const [x0,y0,x1,y1] of this.decks){ const ex=Math.min(X-x0,x1-X), ey=Math.min(Y-y0,y1-Y); if(ex>=0&&ey>=0) return Math.min(ex,ey); } return -1; },
	ground(X,Y,o){ const b=this.bar(X), d=Math.abs(Y-b)-(110+50*fbm(X*.004,1,1312,3));
		o.a='shallows'; o.b='water'; o.t=smooth(30,240,d)*.95;
		if(d<0){ o.a='beach'; o.b=null; o.t=0; if(d>-34) o.wet=.4*(1+d/34); if(d<-70&&fbm(X*.006,Y*.006,1313,3)>.55){ o.b='grass'; o.t=.45; } }
		if(Math.abs(d)<6) o.foam=.55*(1-Math.abs(d)/6)*smooth(.3,.6,fbm(X*.05,Y*.05,1314,2)); else if(d>6&&d<22) o.foam=.18*smooth(.6,.75,fbm(X*.03,Y*.03,1315,2))*(1-(d-6)/16);
		const e=this.onDeck(X,Y); if(e>=0){ o.a='bridge'; o.b=null; o.t=0; o.foam=0; o.wet=0; if(e<4) o.ao=.35; } else if(d>0){ let near=1e9; for(const [x0,y0,x1,y1] of this.decks){ const dx=Math.max(x0-X,0,X-x1), dy=Math.max(y0-Y,0,Y-y1); near=Math.min(near,Math.hypot(dx,dy)); } if(near<14) o.ao=.4*(1-near/14); } },
	dress(p){ const R=p.rng, B=X=>this.bar(X), ang=X=>Math.atan2(B(X+10)-B(X),10);
		for(const [x0,y0,x1,y1] of this.decks){ for(let X=x0+8;X<=x1;X+=60) for(const Y of [y0-4,y1+4]) p.dot(X,Y,5,'#4a3c30'); }
		p.prop('beach_hut',650,220,0,0,.75); p.prop('beach_hut',1520,170,Math.PI/2,1,.8); p.prop('beach_hut',2100,90,0,0,.6); p.prop('barrel',560,540,0,1,.9); p.prop('crate',760,280,.3,0,.8); p.prop('crate',1440,240,1,1,.8);
		p.prop('lifeguard_tower',1180,B(1180)-40,-.2,0,.9);
		p.reserve(880,this.bar(880)+10,130); p.reserve(1180,this.bar(1180)-40,100); p.spaced('palm',9,(X,Y)=>Math.abs(Y-B(X))<70&&Math.abs(X-1000)>220,200,(X,Y,i)=>[R()*6,i%3,.75+R()*.2]);
		p.scatterDecor('pebbles',16,(X,Y)=>Math.abs(Y-B(X))<90);
		const trk=[]; for(let X=200;X<=820;X+=20) trk.push([X,B(X)+10]); p.tracks(trk,9,.22,22); p.car('van',880,B(880)+10,ang(880),0); p.dust(260,B(260)+10,90,[190,180,150,.4]);
		p.goon('hubcap',1080,B(1080)+16,Math.PI+ang(1080),2); p.goon('grunt',1150,B(1150)+60,Math.PI,4); p.goon('dasher',1400,B(1400)-20,Math.PI+.3,1); p.goon('dasher',1460,B(1460)+40,Math.PI-.2,5);
		p.goon('slinger',690,330,1.6,3); p.goon('slinger',1520,300,2.2,2); p.goon('grunt',400,540,.1,6); p.goon('grunt',1520,560,-1.5,0); }},
lantern:{mats:['moss','mud','shallows','water','bridge','grass'],seed:137,grade:'night',
	walk:[[0,900],[380,820],[700,640],[1050,600],[1300,420],[1700,380],[2000,250],[2389,220]],
	lake(X,Y){ return fbm(X*.0014,Y*.0017,1371,5)+(.5-Math.abs(fbm(X*.0009,Y*.0012,1372,3)-.5))*.25; },
	walkDist(X,Y){ let best=1e9; const w=this.walk; for(let i=1;i<w.length;i++){ const [ax,ay]=w[i-1], [bx,by]=w[i], dx=bx-ax, dy=by-ay, t=Math.max(0,Math.min(1,((X-ax)*dx+(Y-ay)*dy)/(dx*dx+dy*dy))); best=Math.min(best,Math.hypot(X-ax-dx*t,Y-ay-dy*t)); } return best; },
	ground(X,Y,o){ const L=this.lake(X,Y); o.a='moss'; const m=fbm(X*.004,Y*.004,1373,3); if(m>.55){ o.b='grass'; o.t=smooth(.55,.66,m)*.6; }
		if(L>.5){ o.b='mud'; o.t=smooth(.5,.56,L)*.85; o.wet=smooth(.52,.58,L)*.4; }
		if(L>.57){ o.a='shallows'; o.b='water'; o.t=smooth(.59,.66,L); o.wet=0; }
		if(Math.abs(L-.57)<.004) o.foam=.35*smooth(.3,.6,fbm(X*.04,Y*.04,1374,2));
		const wd=this.walkDist(X,Y); if(wd<40){ o.a='bridge'; o.b=null; o.t=0; o.wet=0; o.foam=0; if(wd>35) o.ao=.5; } else if(wd<56&&L>.57) o.ao=.35*smooth(56,40,wd); },
	dress(p){ const R=p.rng, w=this.walk, at=t=>{ const k=Math.min(w.length-2,Math.floor(t)), f=t-k; return [w[k][0]+(w[k+1][0]-w[k][0])*f,w[k][1]+(w[k+1][1]-w[k][1])*f,Math.atan2(w[k+1][1]-w[k][1],w[k+1][0]-w[k][0])]; };
		for(let t=.3;t<w.length-1;t+=.55){ const [X,Y,a]=at(t), s=(Math.round(t/.55)%2)?1:-1; p.lantern(X-Math.sin(a)*s*58,Y+Math.cos(a)*s*58); }
		const bank=(X,Y)=>{ const L=this.lake(X,Y); return L>.5&&L<.58&&this.walkDist(X,Y)>120; };
		p.spaced('cypress',16,bank,190,(X,Y,i)=>[i*1.7,i%2,.8+R()*.4]); p.scatterDecor('reeds',70,(X,Y)=>{ const L=this.lake(X,Y); return L>.55&&L<.63&&this.walkDist(X,Y)>60; });
		for(let i=0;i<40;i++){ const X=R()*WW, Y=R()*WH; if(this.lake(X,Y)>.63&&this.walkDist(X,Y)>60) p.lily(X,Y,10+R()*12); }
		const sh=p.find((X,Y)=>bank(X,Y)&&X>1500&&Y>700,R); if(sh){ p.prop('shack',sh[0],sh[1],.3,1,.75); p.glowAdd(sh[0]+40,sh[1]-20,160,[255,200,120],.35); }
		p.scatterProp('log',3,(X,Y)=>this.lake(X,Y)>.63,()=>[R()*3,(R()*2)|0,.7]); p.scatterProp('stump',4,bank,()=>[R()*3,0,.9]);
		const [cx,cy,ca]=at(2.55); p.car('sedan',cx,cy,ca,1); p.headlights(cx,cy,ca); const trk=[]; for(let t=1.4;t<2.5;t+=.05){ const q=at(t); trk.push([q[0],q[1]]); } p.tracks(trk,8,.2,22);
		p.goon('gremlin',cx-30,cy+18,ca+.4,2);
		const [lx,ly]=at(3.3); p.goon('nightcrawler',lx+30,ly+90,-1.8,1); p.goon('nightcrawler',lx+200,ly+60,-2.6,4);
		p.goon('skink',cx+330,cy-40,Math.PI+.2,3); p.goon('skink',900,900,-.6,1);
		p.pack('rat',cx+560,cy-150,4,Math.PI+.5,70); p.pack('rat',520,1050,3,-1,60); }},
sawmill:{mats:['needles','dirt','gravel','mud','grass'],seed:149,
	yard(X,Y){ return 1-Math.hypot((X-1000)/680,(Y-640)/390)+(fbm(X*.004,Y*.004,1491,3)-.5)*.4; },
	haul(X){ return 1180-X*.32+40*Math.sin(X*.004); },
	ground(X,Y,o){ o.a='needles'; const m=fbm(X*.004,Y*.004,1492,3); if(m>.62){ o.b='grass'; o.t=.4; }
		const yd=this.yard(X,Y); if(yd>0){ o.a='dirt'; o.b='gravel'; o.t=smooth(.5,.7,fbm(X*.005,Y*.005,1493,3))*.7; const sd=Math.hypot(X-620,Y-430); if(sd<240){ o.tint=[1.12,1.06,.92]; o.b=null; } } else if(yd>-.08){ o.b='dirt'; o.t=smooth(-.08,0,yd); }
		rutsAt(o,Math.abs(Y-this.haul(X)),56,24,X,Y,1494); },
	dress(p){ const R=p.rng, H=X=>this.haul(X), ang=X=>Math.atan2(H(X+10)-H(X),10);
		p.spaced('pine',50,(X,Y)=>this.yard(X,Y)<-.1&&Math.abs(Y-H(X))>120,150,(X,Y)=>[R()*6,(R()*2)|0,.85+R()*.3]);
		p.prop('shack',620,380,.05,1,.85); p.dust(700,520,130,[214,190,130,.5]); p.prop('crane',1300,330,Math.PI*.1,0,.7);
		p.prop('logpile',1000,330,.1,0,.85); p.prop('logpile',1560,560,-.2,1,.85); p.prop('logpile',1120,880,.05,0,.85,'broken');
		for(let i=0;i<5;i++) p.prop('log',1150+i*60+(R()-.5)*30,H(1150+i*60)-30+(R()-.5)*70,(R()-.5)*.6+1.4,i%2,.6);
		for(let i=0;i<16;i++){ const c=p.find((X,Y)=>{ const yd=this.yard(X,Y); return yd>.0&&yd<.35&&Math.abs(Y-H(X))>90; },R); if(c) p.prop('stump',c[0],c[1],R()*3,i%2,.6+R()*.25); }
		p.prop('fallen_trunk',1800,1050,.3,1,.8); p.prop('firepit',780,680,0,0,.8); p.fire(780,680,16);
		const trk=[]; for(let X=200;X<=820;X+=20) trk.push([X,H(X)]); p.tracks(trk,10,.3,24); p.car('pickup',870,H(870),ang(870),1);
		p.goon('spiker',1330,H(1330)+20,Math.PI-.3,2); p.goon('rammer',1700,H(1700)-10,Math.PI+ang(1700),1); p.dust(1770,H(1770)-10,90);
		p.goon('grunt',1060,420,1.4,1); p.goon('grunt',950,250,.8,4); p.goon('splitter',1600,660,2.2,3); p.goon('splitter',1490,460,-2.5,5); p.goon('torch',760,620,.4,2); p.goon('grunt',1180,960,2.8,6); }},
ghosttown:{mats:['dirt','sand','roof_timber','oil','bridge','gravel'],seed:151,
	MY:690, SX:1470,
	lots:[[60,250,420,540],[470,250,790,540],[850,230,1160,540],[1620,240,1920,540],[1980,250,2389,540],[100,860,500,1140],[560,860,900,1160],[960,860,1300,1120],[1640,860,2010,1150],[2070,860,2389,1140]],
	ground(X,Y,o){ o.a='sand'; o.b='dirt'; o.t=.55*smooth(.4,.62,fbm(X*.003,Y*.003,1511,3));
		const dm=Math.abs(Y-this.MY), ds=Math.abs(X-this.SX);
		if(dm<150||ds<110){ o.a='dirt'; o.b='sand'; o.t=.35*smooth(.45,.65,fbm(X*.006,Y*.006,1512,2)); o.tint=[1.04,1.01,.95]; for(const r of [30,70,110]) if(Math.abs(dm-r)<7&&dm<150) o.tint=[.88,.86,.82];
			if(dm<90&&X>1380&&X<2240){ const s=fbm(X*.004,Y*.012,1513,3)+(1-Math.abs(Y-this.MY-10)/90)*.3; if(s>.62){ o.b='oil'; o.t=smooth(.62,.7,s)*.9; o.tint=null; } } }
		for(const [x0,y0,x1,y1] of this.lots){ const north=y1<this.MY, wy0=north?y1:y0-46, wy1=north?y1+46:y0;
			if(X>=x0&&X<=x1&&Y>=wy0&&Y<=wy1){ o.a='bridge'; o.b=null; o.t=0; o.tint=[.92,.9,.88]; const e=Math.min(X-x0,x1-X,north?wy1-Y:Y-wy0); if(e<5) o.ao=.3; }
			if(bldg(o,rectE(X,Y,x0,y0,x1,y1),'roof_timber')){ const my=(y0+y1)/2; if(Y>my) o.tint=[.9,.9,.9]; if(Math.abs(Y-my)<4){ o.lip=.35; o.tint=[.85,.82,.78]; } return; } } },
	dress(p){ const R=p.rng, MY=this.MY;
		for(const [x0,y0,x1,y1] of this.lots){ const north=y1<MY, y=north?y1+52:y0-52; for(let X=x0+40;X<x1;X+=120) p.dot(X,y,6,'#5c4632'); }
		p.prop('water_trough',640,MY-122,0,0,.85); p.prop('water_trough',1760,MY+128,0,1,.85); p.prop('water_trough',1120,MY+125,0,0,.85,'broken');
		p.prop('wagon',300,MY+60,Math.PI/2+.1,0,.9); p.prop('wagon',2060,MY-40,Math.PI/2-.4,1,.9,'broken'); p.prop('barrel',820,MY-120,0,0,.9); p.prop('barrel',850,MY-112,0,2,.9); p.prop('crate',1880,MY-118,.3,0,.8);
		for(let i=0;i<12;i++){ const X=R()*WW, Y=MY+(R()-.5)*260; p.decor('tumbleweed',X,Y,R()*6,(R()*4)|0,.9+R()*.3); }
		p.scatterDecor('tumbleweed',8,(X,Y)=>Math.abs(X-this.SX)<100); p.scatterDecor('pebbles',20,(X,Y)=>Math.abs(Y-MY)<140);
		const trk=[]; for(let X=200;X<=860;X+=20) trk.push([X,MY+30]); p.tracks(trk,9,.25,22); p.car('racer',900,MY+30,0,1); p.dust(260,MY+30,120);
		p.goon('slick',1600,MY-10,Math.PI,2); p.goon('karter',1300,MY+80,Math.PI+.15,1); p.goon('karter',1180,MY-70,Math.PI-.2,4); p.goon('sidecar',1960,MY+40,Math.PI,3);
		p.goon('torcher',1440,MY-180,Math.PI/2,2); p.fire(1400,MY-210,22); p.fire(1700,560,14); }},
saltflats:{mats:['salt','asphalt','sand','gravel'],seed:157,
	road(X){ return 300+X*.1; },
	ground(X,Y,o){ o.a='salt'; const s=fbm(X*.002,Y*.002,1571,3); if(s>.64){ o.b='sand'; o.t=smooth(.64,.74,s)*.35; }
		const d=Math.abs(Y-this.road(X)), ed=95+18*fbm(X*.01,1,1573,2); if(d<ed){ o.a='asphalt'; o.b='salt'; o.t=Math.min(1,smooth(.58,.72,fbm(X*.005,Y*.005,1572,3))*.55+smooth(ed-30,ed,d)*.8); o.tint=[1.1,1.08,1.05]; if(d<4&&(X%160)<90) o.paint=[216,197,138,.55*(1-o.t)]; if(Math.abs(d-84)<3) o.paint=[214,210,198,.4*(1-o.t)]; }
		else if(d<130) o.ao=.06; },
	dress(p){ const R=p.rng, RD=X=>this.road(X);
		for(let X=150;X<WW;X+=560) p.prop('mile_marker',X,RD(X)+140,0,(X/560|0)%2,1);
		const mounds=[[300,1050,0],[470,1180,1],[230,1250,2],[620,1050,1],[2100,180,0],[2250,320,2]]; mounds.forEach(m=>p.prop('salt_mound',m[0],m[1],R()*6,m[2],.85));
		p.prop('wreck',1950,1120,.4,2,1); p.prop('tyres',2050,1040,1,2,.8); p.decor('tumbleweed',1500,1200,0,1,1); p.decor('tumbleweed',800,260,0,2,1);
		const cy=X=>820-X*.12; const trk=[]; for(let X=0;X<=1060;X+=20) trk.push([X,cy(X)]); p.tracks(trk,8,.18,22);
		for(let k=0;k<7;k++){ const X=980-k*150; p.dust(X,cy(X),90+k*20,[176,166,148,.42-k*.04]); }
		p.car('audi',1100,cy(1100),-.12,0);
		const sp=[]; for(let X=500;X<=1180;X+=20) sp.push([X,cy(X)-150]); p.tracks(sp,4,.14,0); p.goon('spoke',1200,cy(1200)-150,-.12,2);
		p.goon('shredder',1650,cy(1650)+10,Math.PI-.1,1); p.goon('sawbot',700,cy(700)+120,-.1,3); p.goon('sawbot',780,cy(780)+200,-.2,6);
		p.goon('harpooner',1500,cy(1500)+330,-2.3,2); p.rope(1490,cy(1490)+320,1050,cy(1050)+16,60); }},
raiderpass:{mats:['dirt','sand','rock','gravel','wash'],seed:163,
	red:[1.13,.9,.8],
	cY(X){ return 700+150*Math.sin(X*.0017+.4)+40*(n1(X*.003,1631)-.5); }, hw(X){ return 170+40*fbm(X*.004,3,1632,3); },
	ground(X,Y,o){ o.a='dirt'; o.tint=this.red; const s=fbm(X*.003,Y*.003,1633,3); if(s>.55){ o.b='sand'; o.t=smooth(.55,.65,s)*.6; }
		const d=Math.abs(Y-this.cY(X))-this.hw(X);
		if(d<0){ o.b='wash'; o.t=smooth(-40,-120,d)*.6; if(d>-36) o.ao=.6*(1+d/36); o.tint=[1.06,.88,.8]; }
		else if(d<56){ const band=Math.floor((d+6*fbm(X*.01,Y*.01,1634,2))/9)%3; o.a='rock'; o.b=null; o.t=0; o.tint=[[1.08,.8,.66],[.96,.7,.58],[1.14,.86,.7]][band]; o.ao=.15+.4*(1-d/56); }
		else { o.a='rock'; o.b='sand'; o.t=.3; o.tint=[1.18,.9,.78]; if(d<72) o.lip=.6*(1-(d-56)/16); } },
	dress(p){ const R=p.rng, C=X=>this.cY(X), ang=X=>Math.atan2(C(X+10)-C(X),10), up=(X,Y)=>Math.abs(Y-C(X))-this.hw(X)>110;
		const bx=1450; p.prop('barricade',bx,C(bx)-90,Math.PI/2+.2,0,.8); p.prop('jersey',bx+40,C(bx+40)+40,Math.PI/2-.1,1,.8); p.prop('wreck',bx+150,C(bx+150)-20,.8,1,1); p.prop('wreck',bx+230,C(bx+230)+90,2.2,3,1); p.prop('wreck',bx+120,C(bx+120)+130,1.4,0,1);
		p.prop('tyres',bx-40,C(bx-40)+130,0,1,.8); p.prop('cone',bx-90,C(bx-90)+60,0,0); p.prop('cone',bx-100,C(bx-100)+100,0,1); p.prop('barrel',bx+60,C(bx+60)-140,0,0,.9);
		p.scatterProp('rock_red',6,up,()=>[R()*6,(R()*3)|0,.6+R()*.3]); p.scatterProp('saguaro',5,up,(X,Y,i)=>[R()*6,i%2,.8]); p.scatterDecor('bones',10,(X,Y)=>!up(X,Y)); p.scatterDecor('pebbles',30,(X,Y)=>!up(X,Y));
		const trk=[]; for(let X=250;X<=830;X+=20) trk.push([X,C(X)+20]); p.tracks(trk,9,.24,22); p.car('police',880,C(880)+20,ang(880),1); p.dust(300,C(300)+20,100);
		const tx=2030; for(const s of [-1,1]) p.goon('turret',tx+s*40,C(tx)+s*(this.hw(tx)+90),s>0?-Math.PI/2-.4:Math.PI/2+.4,2);
		p.goon('chainer',bx-120,C(bx-120)-40,Math.PI,1); p.goon('torcher',bx+20,C(bx+20)-180,Math.PI/2,3); p.fire(bx+10,C(bx+10)-120,16);
		p.goon('boostjack',1180,C(1180)+60,Math.PI+ang(1180),2); p.dust(1260,C(1260)+60,80); p.goon('chainer',1700,C(1700)-60,Math.PI,5); }},
thunderroad:{mats:['asphalt','sand','dirt','gravel','oil'],seed:167,
	hy(X){ return 600+60*Math.sin(X*.0012+.5); },
	ground(X,Y,o){ o.a='sand'; o.tint=[1.04,1,.96]; const s=fbm(X*.003,Y*.003,1671,3); if(s<.42){ o.b='dirt'; o.t=smooth(.42,.34,s)*.7; }
		const L=Y-this.hy(X), d=Math.abs(L);
		if(d<240){ o.a='asphalt'; o.b=null; o.t=0; o.tint=null; if(Math.abs(d-6)<3) o.paint=[216,197,138,.85]; if(Math.abs(d-228)<4) o.paint=[214,210,198,.8]; if(Math.abs(d-118)<3&&(X%120)<64) o.paint=[214,210,198,.75];
			const oi=fbm(X*.006,Y*.006,1672,3); if(oi>.68){ o.b='oil'; o.t=smooth(.68,.74,oi)*.85; } }
		else if(d<300){ o.a='gravel'; o.ao=.15*smooth(300,240,d); } },
	dress(p){ const R=p.rng, H=X=>this.hy(X), ang=X=>Math.atan2(H(X+10)-H(X),10);
		p.prop('billboard',1560,H(1560)-170,ang(1560),0,1,'broken'); p.prop('billboard',600,H(600)-330,ang(600),1); p.prop('billboard',2150,H(2150)+330,ang(2150)+Math.PI,0);
		p.prop('tank',380,H(380)+440,0,0,.7); p.prop('tank',1200,H(1200)+450,0,0,.7,'broken'); p.flash(1200,H(1200)+450,150); p.fire(1150,H(1150)+430,24); p.fire(1260,H(1260)+470,18); p.prop('tank',1950,H(1950)-450,0,0,.7);
		for(let i=0;i<4;i++) p.prop('barrel',1330+i*50,H(1330)+330+(i%2)*30,R()*3,(R()*3)|0,.9);
		p.scatterProp('saguaro',6,(X,Y)=>Math.abs(Y-H(X))>380&&Math.hypot(X-1200,Y-H(1200)-450)>260,(X,Y,i)=>[R()*6,i%2,.85]); p.scatterDecor('oilstain',8,(X,Y)=>Math.abs(Y-H(X))<200);
		const trk=[]; for(let X=200;X<=860;X+=20) trk.push([X,H(X)+60]); p.tracks(trk,9,.25,22); p.car('audi',900,H(900)+60,ang(900),1);
		p.goon('plowboss',1250,H(1250)+50,Math.PI+ang(1250),2); p.goon('magnet',1900,H(1900)-120,Math.PI,1); p.goon('spoke',1100,H(1100)-60,ang(1100),3); p.goon('spoke',1700,H(1700)+150,Math.PI,5);
		p.goon('sidecar',2050,H(2050)+60,Math.PI,2); p.goon('slick',2250,H(2250)-60,Math.PI,4); }},
frozenlake:{mats:['ice','snow','deepsnow','rock','water'],seed:173,
	lake(X,Y){ return 1-Math.hypot((X-1200)/1180,(Y-700)/560)+(fbm(X*.003,Y*.003,1731,3)-.5)*.3; },
	ground(X,Y,o){ o.a='snow'; const ds=fbm(X*.003,Y*.003,1732,3); if(ds>.55){ o.b='deepsnow'; o.t=smooth(.55,.65,ds); }
		const L=this.lake(X,Y); if(L>0){ o.a='ice'; o.b='snow'; o.t=.35*smooth(.6,.75,fbm(X*.004,Y*.004,1733,3)); if(L<.03) o.lip=.4; }
		else if(L>-.06){ o.ao=.3*(1+L/.06); }
		const hd=Math.hypot(X-1640,Y-420); if(hd<70){ o.a='water'; o.b=null; o.t=0; if(hd>58) o.foam=.5; } else if(hd<80){ o.a='ice'; o.b=null; o.lip=.5; }
 },
	dress(p){ const R=p.rng, shore=(X,Y)=>{ const L=this.lake(X,Y); return L<-.04&&L>-.4; };
		p.spaced('pine_snow',12,(X,Y)=>this.lake(X,Y)<-.12,170,(X,Y)=>[R()*6,(R()*3)|0,.8+R()*.25]); p.scatterProp('rock_ice',6,shore,()=>[R()*6,(R()*2)|0,.6+R()*.3]); p.prop('boulder',180,220,.3,0,.6);
		const loop=[]; for(let t=0;t<=1;t+=.02){ const a=-1.2+t*5.2, r=260-t*80; loop.push([1050+Math.cos(a)*r*1.4,760+Math.sin(a)*r]); } p.tracks(loop,9,.2,22);
		const straight=[]; for(let X=150;X<=780;X+=20) straight.push([X,980-X*.2]); p.tracks(straight,9,.18,22);
		const end=loop[loop.length-1]; p.car('pickup',end[0],end[1],-.9,1); p.dust(end[0]-50,end[1]+30,90,[230,236,242,.45]);
		p.goon('snapper',1590,410,.3,2); p.goon('harpooner',1900,1080,-2.6,3); p.rope(1890,1070,end[0]+20,end[1]+10,40); p.goon('tusker',1350,980,-.6,1); p.goon('tusker',700,520,.8,5); p.goon('plowboss',1950,560,Math.PI+.4,2); }},
timberline:{mats:['snow','deepsnow','needles','dirt','ice'],seed:179,
	road(X){ return 1000-X*.2+50*Math.sin(X*.003); },
	ground(X,Y,o){ o.a='snow'; const ds=fbm(X*.003,Y*.003,1791,3); if(ds>.55){ o.b='deepsnow'; o.t=smooth(.55,.65,ds); }
		const tr=fbm(X*.004,Y*.004,1792,3); if(tr>.58){ o.b='needles'; o.t=smooth(.58,.68,tr)*.55; }
		const cm=Math.hypot((X-1300)/430,(Y-420)/250); if(cm<1){ o.b='dirt'; o.t=.25*(1-cm); }
		const d=Math.abs(Y-this.road(X)); if(d<60){ o.a='snow'; o.b='dirt'; o.t=.18; o.tint=[.93,.94,.96]; if(Math.abs(d-24)<8){ o.b='dirt'; o.t=.55; } } else if(d<74) o.lip=.3*(1-(d-60)/14); },
	dress(p){ const R=p.rng, RD=X=>this.road(X), ang=X=>Math.atan2(RD(X+10)-RD(X),10);
		p.reserve(1150,380,180); p.reserve(1500,470,150); p.reserve(1700,780,140);
		p.spaced('pine_snow',55,(X,Y)=>Math.abs(Y-RD(X))>120&&Math.hypot((X-1300)/430,(Y-420)/250)>1.05,150,(X,Y)=>[R()*6,(R()*3)|0,.8+R()*.3]);
		p.prop('cabin',1150,380,.08,0,.7); p.prop('cabin',1500,470,-.1,1,.6); p.prop('snowcat',1700,780,.3,0,.75); p.prop('logpile',1000,600,.2,0,.75); p.prop('logpile',1600,260,-.3,1,.7); p.prop('firepit',1350,560,0,0,.8); p.fire(1350,560,15);
		const trk=[]; for(let X=200;X<=820;X+=20) trk.push([X,RD(X)]); p.tracks(trk,10,.22,24); p.car('van',870,RD(870),ang(870),1); p.dust(840,RD(840),70,[232,236,242,.4]);
		for(let i=0;i<4;i++){ const X=1250+i*90, Y=RD(1250+i*90)-60+i*40; p.goon('thunderhoof',X,Y,Math.PI/2+.3,i*2); p.dust(X,Y-60,60,[232,236,242,.35]); }
		p.goon('wrecker',1450,640,2.4,1); p.goon('rammer',1050,RD(1050)-120,1.2,3); p.goon('yeti',2000,700,Math.PI+.3,2); p.goon('yeti',600,450,.4,5); }},
tarpits:{mats:['ash','tar','lava','basalt','gravel'],seed:181,
	lavaY(X){ return 1100-X*.18+70*Math.sin(X*.0025+1); },
	pit(X,Y){ return fbm(X*.0024,Y*.0024,1811,4)+(.5-Math.abs(fbm(X*.0012,Y*.0015,1812,3)-.5))*.18; },
	hi(X,Y){ return 1-Math.hypot((X-2150)/520,(Y-150)/360)+(fbm(X*.004,Y*.004,1813,3)-.5)*.3; },
	ground(X,Y,o){ o.a='ash'; const g=fbm(X*.004,Y*.004,1814,3); if(g>.6){ o.b='gravel'; o.t=smooth(.6,.7,g)*.4; o.tint=[.8,.78,.78]; }
		const T=this.pit(X,Y); if(T>.62){ o.a='tar'; o.b=null; o.t=0; o.tint=null; if(T<.64) o.ao=.4; } else if(T>.58) o.ao=.3*smooth(.58,.62,T);
		const d=Math.abs(Y-this.lavaY(X))-(44+24*fbm(X*.004,2,1815,3)); if(d<0){ o.a='lava'; o.b=null; o.t=0; o.tint=null; o.ao=0; } else if(d<40){ o.tint=[1-.3*(1-d/40),1-.34*(1-d/40),1-.36*(1-d/40)]; if(d<8) o.lip=.15; }
		const h=this.hi(X,Y); if(h>.08){ o.a='basalt'; o.b=null; o.t=0; o.tint=null; if(h<.12) o.lip=.5*(1-(h-.08)/.04); } else if(h>-.05){ o.ao=Math.max(o.ao,.65*smooth(-.05,.08,h)); } },
	dress(p){ const R=p.rng, LY=X=>this.lavaY(X), ash=(X,Y)=>this.pit(X,Y)<.56&&Math.abs(Y-LY(X))>150&&this.hi(X,Y)<-.08;
		for(let X=0;X<WW;X+=110) p.glowAdd(X,LY(X),150,[255,120,50],.28);
		p.scatterProp('rock_black',7,ash,()=>[R()*6,(R()*3)|0,.6+R()*.3]); p.scatterDecor('steam_vent',10,ash); p.scatterDecor('bones',12,ash); p.prop('carcass',700,300,.4,0,.9); p.prop('deadtree',420,560,1,1,.8);
		const pits=[]; for(let t=0;t<600&&pits.length<3;t++){ const X=300+R()*1700, Y=150+R()*900; if(this.pit(X,Y)>.69&&pits.every(q=>Math.hypot(q[0]-X,q[1]-Y)>350)&&Math.abs(Y-LY(X))>200) pits.push([X,Y]); }
		const heavy=['bullmoose','thunderhoof','thunderhoof']; pits.forEach((q,i)=>{ p.goon(heavy[i],q[0],q[1],R()*6,i*2); p.dust(q[0],q[1],60,[20,18,16,.5]); });
		const c=[1000,620]; let cx=c[0], cyy=c[1]; for(let t=0;t<200;t++){ const X=600+R()*1000, Y=300+R()*700; if(ash(X,Y)&&ash(X-150,Y)&&ash(X+150,Y)){ cx=X; cyy=Y; break; } }
		const trk=[]; for(let k=0;k<26;k++) trk.push([cx-520+k*20,cyy+Math.sin(k*.2)*20]); p.tracks(trk,9,.25,22); p.car('pickup',cx,cyy,0,2); p.dust(cx-480,cyy,100,[120,114,108,.4]);
		p.goon('rammer',cx+330,cyy-30,Math.PI,3); p.goon('boulder',1900,560,2.6,1); p.goon('boulder',2080,640,3,4); }},
summit:{mats:['snow','deepsnow','rock','ice'],seed:191,
	path(X){ return 1250-X*.42+80*Math.sin(X*.004); },
	plateau(X,Y){ return 1-Math.hypot((X-1760)/620,(Y-330)/300)+(fbm(X*.004,Y*.004,1911,3)-.5)*.25; },
	ground(X,Y,o){ const P=this.plateau(X,Y), d=Math.abs(Y-this.path(X))-(120+30*fbm(X*.005,1,1912,3));
		if(P>0){ o.a='deepsnow'; o.b='snow'; o.t=.3*fbm(X*.005,Y*.005,1913,2); if(P<.05) o.lip=.4*(1-P/.05); return; }
		if(P>-.06&&d>0){ o.ao=.5*(1+P/.06); }
		if(d<0){ o.a='snow'; o.b='deepsnow'; o.t=smooth(-30,-100,d)*.5; if(d>-30) o.ao=.45*(1+d/30); return; }
		const r=fbm(X*.002,Y*.002,1914,3), STEP=.16, q=(r+d/1400)/STEP, k=Math.floor(q), u=q-k; o.a='rock'; o.b='snow'; o.t=.3+.55*smooth(.4,.7,fbm(X*.006,Y*.006,1915,3)); o.tint=[1+k*.03,1+k*.03,1+k*.035];
		if(u>.86) o.ao=.45*(u-.86)/.14; if(u<.08) o.lip=.45*(1-u/.08); if(d<26) o.lip=Math.max(o.lip,.5*(1-d/26)); },
	dress(p){ const R=p.rng, PT=X=>this.path(X), ang=X=>Math.atan2(PT(X+10)-PT(X),10), rocky=(X,Y)=>Math.abs(Y-PT(X))>230&&this.plateau(X,Y)<-.1;
		for(let X=60;X<1400;X+=150){ for(const s of [-1,1]){ const Y=PT(X)+s*(190+R()*40); if(this.plateau(X,Y)<-.05) p.prop(R()<.4?'boulder':'rock_white',X+(R()-.5)*40,Y,R()*6,(R()*2)|0,.45+R()*.2); } }
		p.scatterProp('rock_ice',4,rocky,()=>[R()*6,(R()*2)|0,.6]); p.prop('landmark_big',1820,300,0,0,.75); p.glowAdd(1800,290,120,[255,140,60],.25);
		p.scatterProp('pine_snow',5,rocky,()=>[R()*6,(R()*3)|0,.8]);
		const trk=[]; for(let X=150;X<=880;X+=20) trk.push([X,PT(X)]); p.tracks(trk,10,.2,24); p.car('semi',930,PT(930),ang(930),1);
		p.goon('yeti',1400,640,Math.PI+.4,2); p.goon('yeti',1500,400,2.6,6); p.goon('bullmoose',1150,PT(1150)+30,Math.PI+ang(1150),1); p.goon('boulder',1240,PT(1240)-140,2.2,3); p.goon('plowboss',1650,560,Math.PI+.6,2); p.goon('wrecker',2050,520,-2.6,4); }},
manhole:{mats:['asphalt','lot','roof','water','bridge'],seed:193,
	SX:[480,1300,2080], SY:[360,1040], CX:[890,1690],
	ground(X,Y,o){ let st=1e9, sy=1e9, cn=1e9; for(const q of this.SX) st=Math.min(st,Math.abs(X-q)); for(const q of this.SY) sy=Math.min(sy,Math.abs(Y-q)); for(const q of this.CX) cn=Math.min(cn,Math.abs(X-q)); const s=Math.min(st,sy);
		if(s<96){ o.a='asphalt'; if(cn<96&&sy<96){ o.a='bridge'; o.tint=[.95,.95,.95]; if(cn>88) o.ao=.6; return; } if(s>86) o.ao=.4*(s-86)/10;
			if(st<3&&sy>=96&&(Y%110)<60) o.paint=[216,197,138,.7]; if(sy<3&&st>=96&&(X%110)<60) o.paint=[216,197,138,.7]; return; }
		if(s<136){ o.a='lot'; o.tint=[1.04,1.03,1]; if(s<103) o.lip=.35; return; }
		if(cn<80){ o.a='water'; if(cn>72) o.foam=.25; else if(cn>58) o.ao=.35*(cn-58)/14; return; } if(cn<96){ o.a='lot'; o.tint=[.86,.84,.82]; o.ao=.5*(1-(cn-80)/16); return; }
		o.a='lot'; o.tint=[.9,.9,.9]; if(bldg(o,Math.min(s-150,cn-110),'roof')) o.tint=[.88,.88,.9]; },
	dress(p){ const R=p.rng, SX=this.SX, SY=this.SY;
		const holes=[]; for(const X of SX) for(let Y=120;Y<WH;Y+=300){ if(SY.some(q=>Math.abs(Y-q)<150)) continue; holes.push([X+(R()-.5)*40,Y]); } for(const Y of SY) for(let X=200;X<WW;X+=330){ if(SX.some(q=>Math.abs(X-q)<150)||this.CX.some(q=>Math.abs(X-q)<110)) continue; holes.push([X,Y+(R()-.5)*40]); }
		holes.forEach(h=>p.prop('manhole',h[0],h[1],R()*6,0));
		holes.filter((h,i)=>i%3===1).slice(0,5).forEach((h,k)=>{ for(let i=0;i<11;i++){ const a=R()*TAU, d=26+i*13+R()*16; p.goon('rat',h[0]+Math.cos(a)*d,h[1]+Math.sin(a)*d,a+(R()-.5)*.6,(i+k)%8); } });
		for(const X of this.CX) for(const Y of SY) for(const s of [-1,1]) for(let k=-1;k<=1;k+=2) p.dot(X+k*90,Y+s*90,5,'#55585a');
		const blocks=[[0,480,0,360],[480,1300,0,360],[1300,2080,0,360],[2080,WW,0,360],[0,480,360,1040],[480,1300,360,1040],[1300,2080,360,1040],[2080,WW,360,1040],[0,480,1040,WH],[480,1300,1040,WH],[1300,2080,1040,WH]];
		const roofs=[]; for(const [x0,x1,y0,y1] of blocks){ for(const half of [[x0,Math.min(x1,(x0+x1)/2)],[Math.max(x0,(x0+x1)/2),x1]]){ const cx=(half[0]+half[1])/2, cy=(y0+y1)/2; if(this.CX.some(q=>Math.abs(cx-q)<200)) continue; roofs.push([cx,cy,(half[1]-half[0])/2-180,(y1-y0)/2-180]); } }
		p.roofStuff(roofs.filter(r=>r[2]>20&&r[3]>20),R);
		p.prop('dumpster',600,230,0,0,.9); p.prop('trashbags',700,235,0,1,.9); p.prop('trashbags',1450,1175,0,2,.9); p.prop('hydrant',1160,470,0,0); p.prop('dumpster',1950,1180,.1,1,.9); p.prop('trashbags',1880,240,1,0,.9);
		const trk=[]; for(let X=200;X<=820;X+=20) trk.push([X,SY[1]+40]); p.tracks(trk,9,.16,24); p.car('taxi',870,SY[1]+40,0,1); p.goon('gremlin',890,SY[1]+30,.3,2);
		p.goon('splitter',1500,SY[1]-30,Math.PI,3); p.goon('goonling',1560,SY[1]+30,Math.PI+.3,1); p.goon('goonling',1600,SY[1]-60,Math.PI-.3,4); p.goon('splitter',1300,640,1.7,6); p.goon('gremlin',2000,700,2.4,5); }},
culdesac:{mats:['lawn','asphalt','lot','roof_shingle','water','grass'],seed:197,grade:'night',
	B:[1380,690], BR:230,
	houses(){ if(this._h) return this._h; const out=[], [bx,by]=this.B; for(const a of [-2.25,-1.4,-.5,.45,1.35,2.2]) out.push({cx:bx+Math.cos(a)*540,cy:by+Math.sin(a)*500,a,d:540-this.BR,w:300,h:220,pool:out.length%2===0});
		for(const [X,s] of [[260,-1],[680,-1],[260,1],[680,1]]) out.push({cx:X,cy:by+s*380,a:s*Math.PI/2,d:300,w:300,h:220,pool:X<400}); return this._h=out; },
	local(H,X,Y){ const dx=X-H.cx, dy=Y-H.cy, c=Math.cos(H.a), s=Math.sin(H.a); return [-dx*s+dy*c, dx*c+dy*s]; },
	ground(X,Y,o){ o.a='lawn'; const g=fbm(X*.004,Y*.004,1971,3); if(g>.62){ o.b='grass'; o.t=.4; }
		const [bx,by]=this.B, rb=Math.hypot(X-bx,Y-by), dr=X<bx?Math.abs(Y-by):1e9, road=Math.min(rb-this.BR,dr-80);
		if(road<0){ o.a='asphalt'; o.b=null; o.t=0; if(road>-8) o.ao=.3; if(Math.abs(Y-by)<3&&X<bx-this.BR&&(X%110)<60) o.paint=[216,197,138,.6]; return; }
		if(road<12){ o.a='lot'; o.b=null; o.t=0; o.lip=.3; return; }
		for(const H of this.houses()){ const [lx,ly]=this.local(H,X,Y);
			if(lx>30&&lx<110&&ly<-H.h/2&&ly>-(H.d+40)){ o.a='lot'; o.b=null; o.t=0; o.tint=[.96,.95,.93]; if(lx<36||lx>104) o.ao=.2; }
			if(H.pool&&lx>-110&&lx<40&&ly>H.h/2+50&&ly<H.h/2+200){ const e=Math.min(lx+110,40-lx,ly-H.h/2-50,H.h/2+200-ly); o.b=null; o.t=0; if(e<14){ o.a='lot'; o.tint=[1.05,1.04,1.02]; } else { o.a='water'; o.tint=[.9,1.08,1.12]; if(e<20) o.ao=.4*(1-(e-14)/6); } }
			const e=Math.min(H.w/2-Math.abs(lx),H.h/2-Math.abs(ly)); if(e>-18&&Math.abs(lx)<H.w/2+18&&Math.abs(ly)<H.h/2+18){ if(bldg(o,e>=0?e:-Math.hypot(Math.max(0,Math.abs(lx)-H.w/2),Math.max(0,Math.abs(ly)-H.h/2)),'roof_shingle')){ o.u=lx+4000; o.v=ly+4000; const rx=H.w/2-H.h/2, ax=Math.abs(lx)-rx;
					if(ax<Math.abs(ly)){ if(ly>0) o.tint=[.92,.92,.94]; } else o.tint=[.97,.97,.99]; if((Math.abs(ly)<2.5&&Math.abs(lx)<rx)||(ax>0&&Math.abs(ax-Math.abs(ly))<2.5)) o.lip=Math.max(o.lip,.3); return; } } } },
	dress(p){ const R=p.rng, [bx,by]=this.B, W=(H,lx,ly)=>{ const c=Math.cos(H.a), s=Math.sin(H.a); return [H.cx-lx*s+ly*c, H.cy+lx*c+ly*s]; };
		this.houses().forEach((H,i)=>{ const [mx,my]=W(H,120,-H.d+10); p.prop('mailbox',mx,my,H.a+Math.PI/2,i%3,1); if(i%2){ const [tx,ty]=W(H,150,-H.d+30); p.prop('trashbags',tx,ty,R()*3,i%3,.8); }
			const [gx,gy]=W(H,-60,-H.h/2-30); if(i%3!==1) p.glowAdd(gx,gy,90,[255,200,130],.32);
			if(i===1){ const [qx,qy]=W(H,-20,H.h/2+150); p.prop('trampoline',qx,qy,0,0,.85); } if(i===3){ const [qx,qy]=W(H,40,H.h/2+150); p.prop('swingset',qx,qy,H.a,1,.8); } if(i===5){ const [qx,qy]=W(H,60,H.h/2+150); p.prop('trampoline',qx,qy,0,1,.8); } if(i===7){ const [qx,qy]=W(H,60,H.h/2+150); p.prop('swingset',qx,qy,H.a,0,.8); }
			const [ax,ay]=W(H,H.w/2+40,0), [cx2,cy2]=W(H,H.w/2+40,H.h/2+260); p.line(i%2?'hedge':'fence',ax,ay,cx2,cy2,i%2?400:330,.7,i); });
		for(const a of [-1.85,0,1.85]) p.lamp(bx+Math.cos(a)*(this.BR+30),by+Math.sin(a)*(this.BR+30),a+Math.PI); p.lamp(560,by-110,Math.PI/2); p.lamp(900,by+110,-Math.PI/2);
		p.car('sedan',1000,by+30,0,0); p.headlights(1000,by+30,0); const trk=[]; for(let X=300;X<960;X+=20) trk.push([X,by+30]); p.tracks(trk,8,.14,22);
		const H1=this.houses()[1]; const [yx,yy]=W(H1,120,H1.h/2+110); p.pack('yipper',yx,yy,5,H1.a+Math.PI,70);
		p.goon('jackalope',1300,1100,-1.2,2); p.goon('jackalope',1720,980,-2.2,5); const H4=this.houses()[4]; const [bx2,by2]=W(H4,150,-H4.d+50); p.goon('bandit',bx2+20,by2,2.4,3);
		p.goon('splitter',1300,by+60,Math.PI,2); p.goon('splitter',1500,by-90,Math.PI+.4,6); }},
gridlock:{mats:['asphalt','sand','gravel','dirt','lot'],seed:199,
	N:[250,630], S:[730,1110],
	ground(X,Y,o){ o.a='sand'; o.tint=[1.04,1,.96]; const s=fbm(X*.003,Y*.003,1991,3); if(s<.44){ o.b='dirt'; o.t=.6*smooth(.44,.36,s); }
		for(const [y0,y1] of [this.N,this.S]){ if(Y>=y0&&Y<=y1){ o.a='asphalt'; o.b=null; o.t=0; o.tint=null; const k=Y-y0; if(k<6||y1-Y<6) o.paint=[214,210,198,.75]; else if(((k%95)<3||(k%95)>92)&&(X%130)<70) o.paint=[214,210,198,.7]; return; } if(Y>y0-60&&Y<y0) o.ao=Math.max(o.ao,.15*(1-(y0-Y)/60)); if(Y>y1&&Y<y1+60){ o.a='gravel'; o.ao=.12*(1-(Y-y1)/60); } }
		if(Y>this.N[1]&&Y<this.S[0]){ o.a='gravel'; o.b='dirt'; o.t=.3; o.ao=.25; } },
	dress(p){ const R=p.rng, keys=['sedan','van','taxi','pickup','semi','audi','sedan','van','ambulance'];
		for(let X=150;X<WW;X+=330) p.prop('jersey',X,680,0,(X/330|0)%2,.8);
		const lanes=[[297,Math.PI],[392,Math.PI],[487,Math.PI],[582,Math.PI],[777,0],[872,0],[967,0],[1062,0]]; let k=0;
		lanes.forEach(([Y,a],li)=>{ let X=60+R()*120; while(X<WW+100){ const key=keys[(k++)%keys.length], L=key==='semi'?400:260;
			const skip=(li===5||li===6)&&X>700&&X<1150||(li>=4&&X>1480&&X<1900);
			if(!skip) p.car(key,X+L/2,Y+(R()-.5)*14,a+(R()-.5)*.08,(R()*3)|0); X+=L+40+R()*120; } });
		p.prop('wreck',1560,820,.9,0,1); p.prop('wreck',1700,930,2.4,2,1); p.prop('wreck',1800,800,-.4,4,1); p.prop('wreck',1640,1040,1.6,1,1); p.dust(1700,900,160,[90,84,76,.4]); p.fire(1720,880,14);
		for(let i=0;i<5;i++) p.prop('cone',1430,780+i*70,R()*3,i%2); p.prop('barrel',1880,1050,0,0,.9); p.prop('tyres',1500,1060,1,0,.8);
		const trk=[]; for(let X=300;X<=880;X+=20) trk.push([X,920]); p.tracks(trk,8,.16,20); p.car('racer',930,920,0,0);
		p.goon('karter',1250,440,Math.PI+.1,2); p.goon('karter',1100,535,Math.PI-.1,5); p.goon('spoke',1300,920,Math.PI,1); p.goon('spoke',600,440,Math.PI,4); p.goon('dasher',2000,820,Math.PI+.3,2); p.goon('sawbot',1750,1000,2.6,3); p.goon('sawbot',1900,700,-2.6,6); }},
blockparty:{mats:['lot','asphalt','roof','grass'],seed:211,grade:'dusk',
	P:[420,200,1970,1160], C:[1200,680],
	ground(X,Y,o){ const [x0,y0,x1,y1]=this.P, e=rectE(X,Y,x0,y0,x1,y1), [cx,cy]=this.C;
		if(e>=0){ o.a='lot'; const r=Math.hypot(X-cx,Y-cy), band=Math.floor(r/90)%2, ang=Math.atan2(Y-cy,X-cx); o.tint=band?[1.06,1.04,1.0]:[.96,.95,.93]; if(r%90<3||(r>120&&Math.abs(((ang*16/TAU)%1+1)%1-.5)>.49)) o.tint=[.82,.8,.78];
			for(const [px,py] of [[x0+120,y0+120],[x1-120,y0+120],[x0+120,y1-120],[x1-120,y1-120]]){ const d=Math.hypot(X-px,Y-py); if(d<70){ o.a='grass'; o.tint=null; if(d>62) o.lip=.4; } else if(d<80) o.ao=.3; }
			if(e<10) o.lip=.3; return; }
		if(e>-120){ o.a='asphalt'; if(e>-10) o.ao=.3; if(Math.abs(e+60)<3&&((X+Y)%110)<60) o.paint=[216,197,138,.6]; return; }
		o.a='lot'; o.tint=[.9,.9,.9]; const ax=Math.abs(((X-x0)%520+520)%520-260), ay=Math.abs(((Y-y0)%520+520)%520-260); if(bldg(o,Math.min(-e-140,Math.max(ax,ay)>240?-1:99),'roof')) o.tint=[.88,.88,.9]; },
	dress(p){ const R=p.rng, [x0,y0,x1,y1]=this.P, [cx,cy]=this.C;
		p.prop('landmark_swarm',cx,cy,0,0,.85); p.glowAdd(cx,cy,140,[255,210,130],.35);
		for(const [px,py] of [[x0+120,y0+120],[x1-120,y0+120],[x0+120,y1-120],[x1-120,y1-120]]){ p.prop('oak',px,py,R()*6,(R()*3)|0,.55); for(let t=.1;t<1;t+=.1){ const X=px+(cx-px)*t, Y=py+(cy-py)*t+Math.sin(t*Math.PI)*40; p.glowAdd(X,Y,40,[[255,200,120],[200,150,255],[150,230,200]][(t*10|0)%3],.6); } }
		for(const [X,Y,a] of [[x0+40,cy,0],[x1-40,cy,Math.PI],[cx,y0+40,Math.PI/2],[cx,y1-40,-Math.PI/2]]) p.lamp(X,Y,a);
		p.prop('dumpster',x0+260,y0+50,0,0,.9); p.prop('trashbags',x0+380,y0+50,0,1,.9); p.prop('trashbags',x1-300,y1-50,1,2,.9); p.prop('dumpster',x1-180,y1-50,0,1,.9); p.prop('trashbags',x1-60,y0+300,2,0,.9);
		const crowd=['rat','rat','rat','yipper','yipper','karter','spoke','dasher','gremlin','rat']; let n=0;
		for(let t=0;t<900&&n<60;t++){ const X=x0+60+R()*(x1-x0-120), Y=y0+60+R()*(y1-y0-120); if(Math.hypot(X-cx,Y-cy)<210||Math.hypot(X-600,Y-cy)<170) continue; const id=crowd[n%crowd.length]; p.goon(id,X,Y,Math.atan2(cy-Y,cx-X)+(R()-.5)*1.6,n%8); n++; }
		const trk=[]; for(let X=0;X<=500;X+=20) trk.push([X,cy+20]); p.tracks(trk,9,.2,24); p.car('police',560,cy+20,0,1); p.headlights(560,cy+20,0); p.siren(560,cy+20); }},
blastpits:{mats:['dirt','gravel','rock','mud','lot'],seed:223,
	pits:[[600,430,[360,250,140]],[1850,960,[400,280,160]]],
	road(X){ return 1100-X*.356+30*Math.sin(X*.004); },
	pr(X,Y,P){ const a=Math.atan2(Y-P[1],X-P[0]), r=Math.hypot(X-P[0],(Y-P[1])*1.2); return r*(1+(fbm(Math.cos(a)*2+5,Math.sin(a)*2+5,2231+P[0],3)-.5)*.28); },
	ground(X,Y,o){ o.a='dirt'; o.tint=[.97,.95,.93]; const g=fbm(X*.003,Y*.003,2232,3); if(g>.55){ o.b='gravel'; o.t=smooth(.55,.66,g)*.8; }
		for(const P of this.pits){ const r=this.pr(X,Y,P), rings=P[2]; if(r<rings[0]){ o.a='gravel'; o.b='rock'; o.t=.45; let lvl=0; for(const q of rings) if(r<q) lvl++; o.ao=.12*lvl; if(lvl>=3){ o.a='mud'; o.b='gravel'; o.t=.3; o.ao=.32; }
			for(const q of rings){ const e=r-q; if(e>-34&&e<0) o.ao=Math.max(o.ao,.75*(1+e/34)); if(e>=0&&e<14) o.lip=.55*(1-e/14); } } }
		rutsAt(o,Math.abs(Y-this.road(X)),58,24,X,Y,2233); },
	dress(p){ const R=p.rng, RD=X=>this.road(X), ang=X=>Math.atan2(RD(X+10)-RD(X),10), [P1,P2]=this.pits;
		for(let i=0;i<14;i++){ const a=R()*TAU, d=R()*200; p.prop('barrel',P2[0]+Math.cos(a)*d,P2[1]+Math.sin(a)*d/1.2,R()*3,(R()*3)|0,.9); }
		for(let i=0;i<8;i++){ const a=R()*TAU; p.prop('barrel',P1[0]+Math.cos(a)*(380+R()*40),P1[1]+Math.sin(a)*(380+R()*40)/1.2,R()*3,(R()*3)|0,.9); }
		p.prop('tank',2200,560,0,0,.6); p.prop('tank',1500,1240,0,0,.55); p.prop('crate',1300,300,.3,1,.9); p.prop('crate',1380,330,1,2,.9);
		for(let i=0;i<4;i++){ const a=i*1.6; p.prop('barrel',P1[0]+60+Math.cos(a)*70,P1[1]+40+Math.sin(a)*60,0,0,1,'broken'); } p.flash(P1[0]+60,P1[1]+40,190); p.fire(P1[0]+30,P1[1]+20,22); p.fire(P1[0]+110,P1[1]+70,16); p.dust(P1[0]+60,P1[1]+40,260,[70,62,54,.45]);
		p.scatterDecor('pebbles',40,(X,Y)=>this.pr(X,Y,P2)<400); p.scatterDecor('cracks',10,(X,Y)=>Math.abs(Y-RD(X))>100);
		const trk=[]; for(let X=500;X<=1080;X+=20) trk.push([X,RD(X)]); p.tracks(trk,10,.26,24); p.car('pickup',1130,RD(1130),ang(1130),2);
		p.goon('doomcart',1450,RD(1450)+20,Math.PI+ang(1450),2); p.goon('sidecar',1700,RD(1700)-40,Math.PI+ang(1700),1); p.goon('boostjack',900,RD(900)-160,.2,3); p.goon('slinger',1720,620,1.4,2); p.goon('slinger',2050,820,2.6,5); p.goon('doomcart',1900,980,-2.6,4); }},
tankfarm:{mats:['dirt','lot','gravel','oil'],seed:227,
	pads:[[420,330],[1200,330],[1980,330],[420,1040],[1200,1040],[1980,1040]],
	ground(X,Y,o){ o.a='dirt'; o.tint=[.94,.92,.9]; const g=fbm(X*.003,Y*.003,2271,3); if(g>.56){ o.b='gravel'; o.t=smooth(.56,.66,g)*.7; }
		for(const [px,py] of this.pads){ const e=rectE(X,Y,px-270,py-200,px+270,py+200); if(e>=0){ o.a='lot'; o.b=null; o.t=0; o.tint=[.96,.95,.94]; if(e<14) o.ao=.25*(1-e/14); } }
		const oi=fbm(X*.004,Y*.004,2272,4); if(oi>.6&&o.a==='dirt'){ o.b='oil'; o.t=smooth(.6,.66,oi)*.9; }
		rutsAt(o,Math.abs(Y-690),70,26,X,Y,2273); if(o.a==='dirt'&&o.b==='mud') o.b=null; },
	dress(p){ const R=p.rng;
		this.pads.forEach(([px,py],i)=>{ const broken=i===1; p.prop('tank',px,py,R()*6,0,.72,broken?'broken':undefined);
			for(const [x0,y0,x1,y1] of [[px-260,py-190,px+260,py-190],[px-260,py+190,px+260,py+190],[px-260,py-190,px-260,py+190],[px+260,py-190,px+260,py+190]]) p.line('jersey',x0,y0,x1,y1,330,.75,i,(t,k)=>y0===y1&&((py<690&&y0>py)||(py>690&&y0<py))&&t>.35&&t<.65); });
		p.pipe([[0,560],[600,560],[620,600],[1800,600],[1820,560],[WW,560]],8,'#6d6f72'); p.pipe([[0,820],[WW,820]],6,'#7a5a46');
		p.flash(1200,330,260); p.fire(1150,300,26); p.fire(1260,360,22); p.fire(1990,300,18); p.dust(1200,330,320,[50,44,40,.45]);
		for(let i=0;i<5;i++) p.prop('barrel',700+i*44,760+(i%2)*26,R()*3,(R()*3)|0,.9); p.scatterDecor('oilstain',12,(X,Y)=>Math.abs(Y-690)<140);
		const trk=[]; for(let X=200;X<=840;X+=20) trk.push([X,700]); p.tracks(trk,10,.28,24); p.car('semi',900,700,0,1);
		p.goon('torch',1100,560,1.6,2); p.goon('torch',1350,520,2.4,5); p.goon('torcher',1600,700,Math.PI,1); p.fire(1540,700,12); p.goon('spitter',1900,760,Math.PI+.4,3); p.goon('spitter',1300,860,-2.4,6); }},
slagfields:{mats:['ash','lava','basalt','gravel','tar'],seed:229,
	ch1(Y){ return 640+120*Math.sin(Y*.003+.5); }, ch2(Y){ return 1460+150*Math.sin(Y*.0025+2); },
	hi(X,Y){ return X-1960-90*fbm(Y*.004,3,2291,3); },
	ground(X,Y,o){ o.a='ash'; o.tint=[.94,.92,.92]; const g=fbm(X*.004,Y*.004,2292,3); if(g>.55){ o.b='gravel'; o.t=smooth(.55,.65,g)*.7; }
		const s=fbm(X*.006,Y*.006,2293,3); if(s>.66){ o.b='tar'; o.t=smooth(.66,.72,s)*.6; }
		for(const [d,w] of [[Math.abs(X-this.ch1(Y)),46],[Math.abs(X-this.ch2(Y)),Y>300?54:0]]){ const e=d-w-14*fbm(X*.01,Y*.01,2294,2); if(e<0){ o.a='lava'; o.b=null; o.t=0; o.tint=null; return; } if(e<36){ const k=1-e/36; o.tint=[.94-.3*k,.92-.36*k,.92-.38*k]; } }
		const h=this.hi(X,Y); if(h>0){ o.a='basalt'; o.b=null; o.t=0; o.tint=null; if(h<14) o.lip=.5*(1-h/14); } else if(h>-60) o.ao=Math.max(o.ao,.6*(1+h/60)); },
	dress(p){ const R=p.rng, flat=(X,Y)=>Math.abs(X-this.ch1(Y))>140&&Math.abs(X-this.ch2(Y))>150&&this.hi(X,Y)<-80;
		for(let Y=0;Y<WH;Y+=110){ p.glowAdd(this.ch1(Y),Y,150,[255,120,50],.3); if(Y>300) p.glowAdd(this.ch2(Y),Y,160,[255,120,50],.3); }
		p.prop('landmark_war',230,200,0,0,.7); p.reserve(230,200,180);
		p.spaced('rock_black',12,flat,140,()=>[R()*6,(R()*3)|0,.6+R()*.4]); p.scatterDecor('steam_vent',12,flat); p.scatterProp('scrapheap',2,flat,()=>[R()*6,(R()*3)|0,.6]);
		for(let Y=250;Y<WH;Y+=330) p.goon('turret',1990+90*fbm(Y*.004,3,2291,3),Y,Math.PI,(Y/330|0)%8);
		const trk=[]; for(let k=0;k<30;k++){ const Y=1300-k*22; trk.push([(this.ch1(Y)+this.ch2(Y))/2+Math.sin(k*.3)*30,Y]); } p.tracks(trk,9,.24,22);
		const cy=640, cx=(this.ch1(cy)+this.ch2(cy))/2; p.car('racer',cx,cy,-Math.PI/2+.1,1);
		p.goon('doomcart',cx+40,cy-330,Math.PI/2,2); p.goon('torcher',cx-200,cy-120,0,3); p.fire(cx-160,cy-120,14); p.goon('spitter',cx+260,cy+120,Math.PI,1); p.goon('spitter',700,1150,-1,5); p.goon('doomcart',1700,200,2,6); }},
theline:{mats:['conveyor','lot','dirt','oil','gravel'],seed:233,
	belts:[230,560,890,1220],
	ground(X,Y,o){ o.a='lot'; o.tint=[.84,.83,.82]; const oi=fbm(X*.004,Y*.004,2331,3); if(oi>.62){ o.b='oil'; o.t=smooth(.62,.7,oi)*.7; }
		for(const b of this.belts){ const d=Math.abs(Y-b); if(d<92){ o.a='conveyor'; o.b=null; o.t=0; o.tint=null; return; } if(d<104){ o.a='lot'; o.b=null; o.tint=[.55,.55,.56]; o.lip=d<98?.35:0; o.ao=d>=98?.4:0; return; } } },
	dress(p){ const R=p.rng, B=this.belts;
		for(let X=40;X<WW;X+=160) for(const b of B) for(const s of [-1,1]) p.dot(X,b+s*98,5,'#3a3836');
		p.prop('container',600,B[0],0,0,.42); p.prop('container',1700,B[0],0,1,.42); p.prop('container',2150,B[2],0,2,.42); p.prop('crate',1500,B[2],.1,1,.8); p.prop('crate',300,B[3],.3,2,.8); p.prop('barrel',900,B[3],0,1,.9); p.prop('scrapheap',1900,B[3],0,1,.5);
		p.prop('crane',1300,395,Math.PI*.98,0,.7); for(let i=0;i<4;i++) p.prop('barrel',200+i*40,395+(i%2)*30,R()*3,(R()*3)|0,.9); p.prop('tyres',2100,725,0,1,.8);
		const cx=1050, cy=B[1]+30; p.car('van',cx,cy,.12,1); p.field(cx+40,cy+40,1150,725);
		p.goon('magnet',1150,735,-Math.PI/2-.3,2); p.goon('turret',500,725,-Math.PI/2,1); p.goon('turret',1700,395,Math.PI/2,3); p.goon('turret',2200,1055,-Math.PI/2,5);
		p.goon('slinger',800,1055,-1.4,2); p.goon('slinger',1900,725,-2,6); p.goon('magnet',2000,395,2.4,4); }}
};
/* the drawing API a poster's dress() uses; everything is queued by layer, then drawn in order */
function posterApi(P,x,ground){ const q=[], R=rng(P.seed*977+5), cache={}, S=PSC;
	const spr=id=>cache[id]||(cache[id]=bakeProp(id)); const name=(id,v,st)=>st==='broken'?id+'_broken.png':id+(v?'_v'+v:'')+'.png';
	const push=(layer,Y,fn)=>q.push({layer,Y,fn});
	const api={rng:R,ground,
		prop(id,X,Y,rot,v,s,st){ if(st==='none') return; const d=PROPS[id]; v=Math.min(v||0,(d.n||1)-1); const cv=spr(id).files[name(id,v,st)]; const layer=st==='broken'?1:d.cls==='TALL'?4:2;
			const top=d.canopy&&st!=='broken'?spr(id).files[id+'_canopy'+(v?'_v'+v:'')+'.png']:null;
			push(layer,Y,()=>{ x.save(); x.translate(X*S,Y*S); x.rotate(rot||0); const k=S/PROP_RES*(s||1); x.scale(k,k); x.drawImage(cv,-cv.width/2,-cv.height/2); if(top) x.drawImage(top,-top.width/2,-top.height/2); x.restore(); }); },
		decor(id,X,Y,rot,cell,s){ const d=PROPS[id], cv=spr(id).files[id+'.png'], cw=cv.height; push(1,Y,()=>{ x.save(); x.translate(X*S,Y*S); x.rotate(rot); const k=S/PROP_RES*(s||1); x.scale(k,k); x.drawImage(cv,cell*cw,0,cw,cw,-cw/2,-cw/2,cw,cw); x.restore(); }); },
		car(key,X,Y,ang,stage){ const W=window.CarArt, cv=W.render(key,{style:'A',stage:stage||0,res:S,shadow:false}), sh=W.renderShadow(key,S);
			push(3,Y,()=>{ x.save(); x.translate(X*S,Y*S); x.rotate(ang+Math.PI/2); x.globalAlpha=.85; x.drawImage(sh,-sh.width/2,-sh.height/2); x.globalAlpha=1; x.drawImage(cv,-cv.width/2,-cv.height/2); x.restore(); }); },
		goon(id,X,Y,ang,frame){ const G=window.GoonArt, d=window.GOONS[id]; if(!d) return; const f=G.bake(d,'walk',(frame||0)%8,S*1.15).cv;
			push(3,Y,()=>{ x.save(); x.translate(X*S,Y*S); x.rotate(ang+Math.PI/2); x.drawImage(f,-f.width/2,-f.height/2); x.restore(); }); },
		tracks(pts,w,a,gap){ push(0,0,()=>{ x.save(); x.lineCap='round'; x.lineJoin='round'; for(const s of [-1,1]){ x.beginPath(); pts.forEach((p2,i)=>{ const nx=pts[Math.min(i+1,pts.length-1)], pv=pts[Math.max(i-1,0)], dx=nx[0]-pv[0], dy=nx[1]-pv[1], l=Math.hypot(dx,dy)||1, ox=-dy/l*(gap||24)*s, oy=dx/l*(gap||24)*s;
			const px=(p2[0]+ox)*S, py=(p2[1]+oy)*S; i?x.lineTo(px,py):x.moveTo(px,py); }); x.lineWidth=w*S; x.strokeStyle='rgba(22,18,14,'+a+')'; x.stroke(); } x.restore(); }); },
		dust(X,Y,r,col){ const c0=col||[200,170,130]; push(3.5,Y,()=>{ const g=x.createRadialGradient(X*S,Y*S,0,X*S,Y*S,r*S); g.addColorStop(0,css(c0,c0[3]==null?.45:c0[3])); g.addColorStop(1,css(c0,0)); x.fillStyle=g; x.fillRect((X-r)*S,(Y-r)*S,r*2*S,r*2*S); }); },
		dot(X,Y,r,col){ push(1,Y,()=>{ vol(x,X*S,Y*S,r*S,r*S,col,{hi:.25}); }); },
		lily(X,Y,r){ push(1,Y,()=>{ x.save(); x.translate(X*S,Y*S); x.rotate(X); x.beginPath(); x.moveTo(0,0); x.arc(0,0,r*S,.35,TAU-.05); x.closePath(); x.fillStyle='#55683a'; x.fill(); x.strokeStyle='rgba(20,30,12,.5)'; x.lineWidth=1; x.stroke(); x.restore(); }); },
		lamp(X,Y,rot){ const cv=cache.lamp||(cache.lamp=STATION.station_lamp()); push(4,Y,()=>{ x.save(); x.translate(X*S,Y*S); x.rotate(rot||0); const k=S/PROP_RES*.8; x.scale(k,k); x.drawImage(cv,-cv.width/2,-cv.height/2); x.restore(); });
			const fx=X+Math.cos(rot||0)*36, fy=Y+Math.sin(rot||0)*36; api.glowAdd(fx,fy,230,[255,210,150],.32); },
		glowAdd(X,Y,r,col,a){ push(9,Y,()=>{ x.save(); x.globalCompositeOperation='lighter'; const g=x.createRadialGradient(X*S,Y*S,0,X*S,Y*S,r*S); g.addColorStop(0,css(col,a)); g.addColorStop(.5,css(col,a*.35)); g.addColorStop(1,css(col,0)); x.fillStyle=g; x.fillRect((X-r)*S,(Y-r)*S,r*2*S,r*2*S); x.restore(); }); },
		headlights(X,Y,ang){ push(9,Y,()=>{ const L=canvas(PW,PH), l=L.getContext('2d'); l.translate(X*S,Y*S); l.rotate(ang); for(const s of [-1,1]){ const g=l.createRadialGradient(100*S,s*26*S,0,100*S,s*26*S,560*S); g.addColorStop(0,'rgba(255,236,190,.42)'); g.addColorStop(.6,'rgba(255,236,190,.12)'); g.addColorStop(1,'rgba(255,236,190,0)'); l.fillStyle=g; l.beginPath(); l.moveTo(100*S,s*26*S); l.lineTo(660*S,s*26*S-190*S); l.lineTo(660*S,s*26*S+190*S); l.closePath(); l.fill(); }
			x.save(); x.globalCompositeOperation='lighter'; x.filter='blur(6px)'; x.drawImage(L,0,0); x.restore(); }); },
		siren(X,Y){ api.glowAdd(X-6,Y-14,60,[255,60,50],.5); api.glowAdd(X+6,Y+14,60,[70,120,255],.5); },
		roofStuff(blocks,R2){ for(const [cx,cy,hw,hh] of blocks){ const n=2+((R2()*3)|0); for(let i=0;i<n;i++){ const X=cx+(R2()-.5)*hw*1.2, Y=cy+(R2()-.5)*hh*1.2, k=R2();
			push(2,Y,()=>{ x.save(); x.translate(X*S,Y*S); if(k<.4){ x.fillStyle='#8d8f8c'; x.fillRect(-26*S,-18*S,52*S,36*S); x.fillStyle='#5c5e60'; x.beginPath(); x.arc(0,0,12*S,0,TAU); x.fill(); x.strokeStyle='rgba(30,30,30,.5)'; x.lineWidth=1; x.strokeRect(-26*S,-18*S,52*S,36*S); }
				else if(k<.7){ vol(x,0,0,30*S,30*S,'#6b5e52',{hi:.25}); x.strokeStyle='rgba(30,24,20,.5)'; x.lineWidth=1.2; x.beginPath(); x.arc(0,0,22*S,0,TAU); x.stroke(); }
				else { x.fillStyle='rgba(150,170,180,.6)'; x.fillRect(-30*S,-20*S,60*S,40*S); x.strokeStyle='#3a3c3e'; x.lineWidth=2; x.strokeRect(-30*S,-20*S,60*S,40*S); }
				x.restore(); }); } } },
		find(test,R2){ for(let t=0;t<400;t++){ const X=R2()*WW, Y=R2()*WH; if(test(X,Y)) return [X,Y]; } return null; },
		scatterProp(id,n,test,fn){ for(let i=0;i<n;i++){ const c=api.find(test,R); if(!c) continue; const [rot,v,s]=fn(c[0],c[1],i); api.prop(id,c[0],c[1],rot,v,s); } },
		scatterDecor(id,n,test){ for(let i=0;i<n;i++){ const c=api.find(test,R); if(!c) continue; api.decor(id,c[0],c[1],R()*TAU,(R()*4)|0,.8+R()*.4); } },
		scatterGoon(id,n,test){ for(let i=0;i<n;i++){ const c=api.find(test,R); if(c) api.goon(id,c[0],c[1],R()*TAU,i*3); } },
		/* Road Atlas helpers: props kept apart, a pack of goons, ropes, fires, lanterns, pipes and lines of props */
		taken:[],
		spaced(id,n,test,minD,fn){ let k=0; for(let t=0;t<n*30&&k<n;t++){ const X=R()*WW, Y=R()*WH; if(!test(X,Y)) continue; if(api.taken.some(q=>Math.hypot(q[0]-X,q[1]-Y)<(minD+q[2])*.5)) continue;
			api.taken.push([X,Y,minD]); const [rot,v,s]=fn(X,Y,k); api.prop(id,X,Y,rot,v,s); k++; } },
		reserve(X,Y,r){ api.taken.push([X,Y,r*2]); },
		pack(id,X,Y,n,ang,spread,R2){ R2=R2||R; for(let i=0;i<n;i++){ const a=R2()*TAU, d=spread*Math.sqrt(R2()); api.goon(id,X+Math.cos(a)*d,Y+Math.sin(a)*d,ang+(R2()-.5)*.5,(i*3+1)%8); } },
		rope(X1,Y1,X2,Y2,sag){ push(3.6,Math.max(Y1,Y2),()=>{ x.save(); x.beginPath(); x.moveTo(X1*S,Y1*S); x.quadraticCurveTo((X1+X2)/2*S,((Y1+Y2)/2+(sag||30))*S,X2*S,Y2*S); x.lineWidth=2.6; x.strokeStyle='rgba(30,24,18,.85)'; x.stroke(); x.lineWidth=1; x.strokeStyle='rgba(190,170,130,.8)'; x.stroke(); x.restore(); }); },
		fire(X,Y,r){ push(3.4,Y,()=>{ for(let i=0;i<9;i++){ const a=i*2.4, d=r*.4*(i%3)/2; vol(x,(X+Math.cos(a)*d)*S,(Y+Math.sin(a)*d)*S,r*(.45-.03*i)*S,r*(.4-.03*i)*S,i%2?'#d2702a':'#e8a050',{hi:.4,lo:-.2}); } }); api.glowAdd(X,Y,r*5,[255,150,70],.5); },
		lantern(X,Y){ push(4,Y,()=>{ vol(x,X*S,Y*S,6*S,6*S,'#5c4632',{hi:.3}); x.save(); x.translate(X*S,Y*S); x.fillStyle='#2a2420'; x.fillRect(4*S,-5*S,16*S,10*S); vol(x,14*S,0,7*S,7*S,'#f0c070',{hi:.5,lo:-.1}); x.restore(); }); api.glowAdd(X+14,Y,190,[255,196,120],.42); },
		pipe(pts,w,col){ push(2,pts[0][1],()=>{ x.save(); x.scale(S,S); for(let i=1;i<pts.length;i++) limb(x,pts[i-1],pts[i],w,col||'#6d6f72'); x.restore(); }); },
		line(id,X0,Y0,X1,Y1,len,s,v,skip){ const L=Math.hypot(X1-X0,Y1-Y0), a=Math.atan2(Y1-Y0,X1-X0), n=Math.max(1,Math.round(L/(len*s))); for(let i=0;i<n;i++){ const t=(i+.5)/n; if(skip&&skip(t,i)) continue; api.prop(id,X0+(X1-X0)*t,Y0+(Y1-Y0)*t,a,(v==null?i:v)%2,s); } },
		field(X1,Y1,X2,Y2){ push(3.6,Math.max(Y1,Y2),()=>{ x.save(); x.setLineDash([6,5]); x.lineCap='round'; for(let k=-2;k<=2;k++){ x.beginPath(); x.moveTo(X1*S,Y1*S); const mx=(X1+X2)/2, my=(Y1+Y2)/2, nx=-(Y2-Y1), ny=X2-X1, l=Math.hypot(nx,ny)||1;
			x.quadraticCurveTo((mx+nx/l*k*28)*S,(my+ny/l*k*28)*S,X2*S,Y2*S); x.lineWidth=2.2; x.strokeStyle='rgba(150,200,255,'+(.75-Math.abs(k)*.18)+')'; x.stroke(); } x.restore(); }); api.glowAdd(X2,Y2,90,[140,190,255],.45); },
		flash(X,Y,r){ push(3.7,Y,()=>{ const g=x.createRadialGradient(X*S,Y*S,0,X*S,Y*S,r*S); g.addColorStop(0,'rgba(255,236,190,.9)'); g.addColorStop(.3,'rgba(255,170,80,.7)'); g.addColorStop(.7,'rgba(200,80,30,.25)'); g.addColorStop(1,'rgba(120,40,20,0)'); x.fillStyle=g; x.fillRect((X-r)*S,(Y-r)*S,r*2*S,r*2*S); }); api.glowAdd(X,Y,r*2.2,[255,160,80],.55); },
		flush(f){ q.sort((a,b)=>a.layer-b.layer||a.Y-b.Y); for(const it of q) if(!f||f(it.layer)) it.fn(); }};
	return api; }
function renderPoster(id){ const P=POSTER[id], S=PSC, mats={}, offs={};
	for(const m of P.mats){ mats[m]=GROUND[m](GROUND_TEXELS).getContext('2d').getImageData(0,0,GROUND_TEXELS,GROUND_TEXELS).data; offs[m]=[(hash2(m.length,m.charCodeAt(0),801)*512)|0,(hash2(m.charCodeAt(1),7,802)*512)|0]; }
	const o={}; const reset=()=>{ o.a=P.mats[0]; o.b=null; o.t=0; o.tint=null; o.ao=0; o.lip=0; o.foam=0; o.wet=0; o.paint=null; o.u=null; o.v=null; };
	const ground=(X,Y)=>{ reset(); P.ground(X,Y,o); return o; };
	const samp=(m,tx,ty,out)=>{ const D=mats[m]; if(!D) throw new Error(id+': material '+m+' not in mats'); tx+=offs[m][0]; ty+=offs[m][1]; const x0=Math.floor(tx), y0=Math.floor(ty), fx=tx-x0, fy=ty-y0, M=511;
		const i00=(((y0&M)<<9)|(x0&M))<<2, i10=(((y0&M)<<9)|((x0+1)&M))<<2, i01=((((y0+1)&M)<<9)|(x0&M))<<2, i11=((((y0+1)&M)<<9)|((x0+1)&M))<<2;
		for(let k=0;k<3;k++) out[k]=(D[i00+k]*(1-fx)+D[i10+k]*fx)*(1-fy)+(D[i01+k]*(1-fx)+D[i11+k]*fx)*fy; };
	const cv=canvas(PW,PH), x=cv.getContext('2d'), im=x.createImageData(PW,PH), d=im.data, ca=[0,0,0], cb=[0,0,0];
	for(let j=0;j<PH;j++) for(let i=0;i<PW;i++){ const X=i/S, Y=j/S; ground(X,Y); const U=o.u!=null?o.u:X, V=o.v!=null?o.v:Y; samp(o.a,U*GROUND_DENSITY,V*GROUND_DENSITY,ca);
		if(o.b&&o.t>0){ samp(o.b,X*GROUND_DENSITY,Y*GROUND_DENSITY,cb); for(let k=0;k<3;k++) ca[k]+=(cb[k]-ca[k])*o.t; }
		if(o.tint) for(let k=0;k<3;k++) ca[k]*=o.tint[k];
		if(o.wet) for(let k=0;k<3;k++) ca[k]*=1-.35*o.wet;
		if(o.lip) for(let k=0;k<3;k++) ca[k]+=(235-ca[k])*.4*o.lip;
		if(o.ao) for(let k=0;k<3;k++) ca[k]+=(AOC[k]-ca[k])*.62*o.ao;
		if(o.foam) for(let k=0;k<3;k++) ca[k]+=(FOAM[k]-ca[k])*o.foam;
		if(o.paint) for(let k=0;k<3;k++) ca[k]+=(o.paint[k]-ca[k])*o.paint[3];
		const q=(j*PW+i)*4; d[q]=ca[0]; d[q+1]=ca[1]; d[q+2]=ca[2]; d[q+3]=255; }
	x.putImageData(im,0,0);
	const api=posterApi(P,x,ground); P.dress(api);
	api.flush(l=>l<9);
	if(P.grade==='dusk'){ x.save(); x.globalCompositeOperation='multiply'; x.fillStyle='#77749c'; x.fillRect(0,0,PW,PH); x.restore(); }
	if(P.grade==='night'){ x.save(); x.globalCompositeOperation='multiply'; x.fillStyle='#5c648a'; x.fillRect(0,0,PW,PH); x.restore(); }
	api.flush(l=>l>=9);
	const v=x.createRadialGradient(PW/2,PH/2,PH*.35,PW/2,PH/2,PW*.62); v.addColorStop(0,'rgba(10,8,6,0)'); v.addColorStop(1,'rgba(10,8,6,.42)'); x.fillStyle=v; x.fillRect(0,0,PW,PH);
	return cv; }

window.WorldArt={GROUND_TEXELS,GROUND_DENSITY,PROP_RES,GROUNDS:Object.keys(GROUND),EDGES:Object.keys(EDGE),PROPS:PROP_IDS,DECOR:DECOR_IDS,bakeProp,STATION:Object.keys(STATION),POSTERS:Object.keys(POSTER),renderStation,renderPoster,renderGround,renderMacro,renderEdge};
})();
