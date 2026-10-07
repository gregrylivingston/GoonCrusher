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
	overlayGrime(x,S,S,.12); return cv; }
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
		put(o,c); o[3]=a*255; if(j<e&&hash2(i,j,374)>.995){ o[0]+=20;o[1]+=20;o[2]+=20; } }); }
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
	draw(c,R,v){ canopy(c,R,120+v*8,[['#53642f','#5f7036','#6a7a3e'],['#4f5f2e','#5b6b33','#687a3c'],['#5a6630','#667238','#748048']][v]); }},
pine:{cls:'TALL',box:[230,230],n:3,shadow:9,grime:.08,core(c){ ell(c,0,0,36,36); c.fillStyle='#000'; c.fill(); },
	draw(c,R,v){ const r=96+v*6, cols=['#3e5134','#47593a','#506241']; for(let k=0;k<4;k++){ const rk=r*(1-k*.22), n=11+((rk/r)*7|0), col=shade(C(cols[k%3]),k*.05);
		for(let i=0;i<n;i++){ const a=i/n*TAU+R()*.25+k*.45, sp=.32+R()*.08; c.beginPath(); c.moveTo(Math.cos(a-sp)*rk*.3,Math.sin(a-sp)*rk*.3); c.lineTo(Math.cos(a)*rk*(.92+R()*.12),Math.sin(a)*rk*(.92+R()*.12)); c.lineTo(Math.cos(a+sp)*rk*.3,Math.sin(a+sp)*rk*.3); c.closePath();
			const g=c.createLinearGradient(0,0,Math.cos(a)*rk,Math.sin(a)*rk); g.addColorStop(0,css(shade(col,.12))); g.addColorStop(1,css(shade(col,-.32))); c.fillStyle=g; c.fill(); } }
		vol(c,0,0,r*.1,r*.1,'#5a6a46',{hi:.3});
		atop(c,()=>{ c.lineWidth=.8; for(let i=0;i<r*5;i++){ const a=R()*TAU, d=R()*r, l=3+R()*4; c.beginPath(); c.moveTo(Math.cos(a)*d,Math.sin(a)*d); c.lineTo(Math.cos(a)*(d+l),Math.sin(a)*(d+l)); c.strokeStyle=R()<.5?'rgba(14,22,10,.35)':'rgba(160,176,130,.2)'; c.stroke(); }
			if(v===2) for(let i=0;i<60;i++){ const a=R()*TAU, d=r*(.3+R()*.6); ell(c,Math.cos(a)*d,Math.sin(a)*d,4+R()*6,3+R()*4,a); c.fillStyle='rgba(226,232,236,.75)'; c.fill(); } });
		crown(c,0,0,r,.1,.3); }},
cypress:{cls:'TALL',box:[260,250],n:2,shadow:9,grime:.1,core(c){ ell(c,0,0,48,48); c.fillStyle='#000'; c.fill(); },
	draw(c,R,v){ canopy(c,R,104+v*6,['#606a3a','#6c7542','#7a8250'],{n:20,sy:.92});
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
	draw(c,R,v){ const col='#5f7150', arms=v?3:2; for(let i=0;i<arms;i++){ const a=i/arms*TAU+R()*.8+.3, d=46+R()*20; limb(c,[Math.cos(a)*20,Math.sin(a)*20],[Math.cos(a)*d,Math.sin(a)*d],22,col); ribbed(c,Math.cos(a)*d,Math.sin(a)*d,15,col,R,10); }
		ribbed(c,0,0,32,col,R,16); if(v){ for(let i=0;i<5;i++){ const a=i/5*TAU; vol(c,Math.cos(a)*8,Math.sin(a)*8,4,4,'#cdb27a',{hi:.3}); } } }},
deadtree:{cls:'TALL',box:[300,300],n:2,shadow:7,grime:.15,core(c){ ell(c,0,0,22,22); c.fillStyle='#000'; c.fill(); },
	draw(c,R,v){ const col='#6b5e52'; function br(x,y,a,l,w,d){ const x2=x+Math.cos(a)*l, y2=y+Math.sin(a)*l; limb(c,[x,y],[x2,y2],w,col); if(d>0){ const k=1+(R()<.6); for(let i=0;i<=k;i++) br(x2,y2,a+(R()-.5)*1.2,l*(.5+R()*.15),w*.62,d-1); } }
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
crane:{cls:'TALL',box:[620,280],n:1,shadow:12,grime:.3,core(c){ c.fillStyle='#000'; c.fillRect(-275,-110,250,220); },
	draw(c,R){ c.translate(-125,0); for(const s of [-1,1]){ c.beginPath(); rr(c,-140,s*84-24,250,48,18); c.fillStyle='#232221'; c.fill(); c.save(); c.clip(); c.strokeStyle='rgba(120,118,112,.45)'; c.lineWidth=2; for(let x=-140;x<110;x+=9){ c.beginPath(); c.moveTo(x,s*84-24); c.lineTo(x,s*84+24); c.stroke(); } c.restore(); }
		c.save(); c.rotate(-.06); c.beginPath(); rr(c,-130,-62,210,124,10); const g=c.createLinearGradient(0,-62,0,62); g.addColorStop(0,'#7a6a34'); g.addColorStop(.5,'#a08a46'); g.addColorStop(1,'#6a5a2c'); c.fillStyle=g; c.fill();
		c.fillStyle='#5f5d58'; c.fillRect(-130,-56,46,112); c.strokeStyle='rgba(0,0,0,.3)'; c.lineWidth=1.4; for(let y=-50;y<56;y+=14){ c.beginPath(); c.moveTo(-128,y); c.lineTo(-86,y); c.stroke(); }
		c.beginPath(); rr(c,10,-58,56,50,6); c.fillStyle='#3a3c3e'; c.fill(); c.fillStyle='rgba(120,150,170,.45)'; c.fillRect(44,-52,18,38); c.globalAlpha=.7; rust(c,-20,20,40,91); c.globalAlpha=1;
		const bx=70; for(const s of [-1,1]) limb(c,[bx,s*16],[bx+320,s*6],5,'#8a7a3a'); c.strokeStyle='#7a6a32'; c.lineWidth=2.4; c.beginPath(); for(let x=bx;x<bx+320;x+=22){ const t=(x-bx)/320, w=16-10*t; c.moveTo(x,-w); c.lineTo(x+22,w-1); c.moveTo(x,w); c.lineTo(x+22,-w+1); } c.stroke();
		vol(c,bx+322,0,9,9,'#4a4846',{hi:.3}); c.fillStyle='rgba(214,190,120,.8)'; c.fillRect(bx+316,-3,12,6); c.restore(); daub(c,-40,40,22,6,0); crown(c,-20,0,200,.06,.18); }},
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
	for(const x of [-120,120]){ vol(c,x,-2,10,10,'#6d6f72',{hi:.35}); } for(const x of [-150,-50,50,150]){ limb(c,[x,4],[x,30],3,'#4a4c4e'); c.fillStyle='#d8d4c0'; c.fillRect(x-6,28,12,5); } rust(c,0,16,40,99+v); }},
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
	if(v===2){ const g2=c.createRadialGradient(50,30,0,50,30,90); g2.addColorStop(0,css(col,.2)); g2.addColorStop(1,css(col,0)); c.fillStyle=g2; ell(c,50,30,90,90); c.fill(); } }}
};

/* rusted wrecks of the player's own cars: car_gen.js stage 2, then rust, moss and fade */
function renderWreck(key,res){ const W=window.CarArt, src=W.render(key,{style:'A',stage:2,res,shadow:false}), cv=canvas(src.width,src.height), x=cv.getContext('2d');
	x.filter='saturate(.55) brightness(.82) contrast(.95)'; x.drawImage(src,0,0); x.filter='none';
	const n=pixels(cv.width,cv.height,(u,v,i,j,o)=>{ const f=fbm(i/res*.05,j/res*.05,500+key.length,4), g=fbm(i/res*.2,j/res*.2,510,2); o[0]=112+(g-.5)*40; o[1]=60+(g-.5)*20; o[2]=34; o[3]=smooth(.55,.66,f)*150; });
	const m=pixels(cv.width,cv.height,(u,v,i,j,o)=>{ const f=fbm(i/res*.06,j/res*.06,520+key.length,4); o[0]=86; o[1]=100; o[2]=56; o[3]=smooth(.66,.74,f)*110; });
	x.globalCompositeOperation='source-atop'; x.drawImage(n,0,0); x.drawImage(m,0,0); x.globalCompositeOperation='source-over'; return cv; }

/* bake one catalog entry: every variant (with shadow and rim), the broken state and debris strip for breakables,
   the hull from the alpha mask (or the core drawing), and the manifest metadata */
function bakeProp(id){ const d=PROPS[id]; if(!d) throw new Error('unknown prop '+id); const res=PROP_RES, files={}, variants=[];
	if(d.cls==='DECOR'){ const cell=Math.round(d.cell*res), cv=canvas(cell*d.n,cell), x=cv.getContext('2d');
		for(let v=0;v<d.n;v++){ const R=rng(2000+v*97+id.charCodeAt(0)); const B=body(cell,cell,res,b=>{ b.save(); b.scale(.82,.82); d.draw(b,R,v); b.restore(); });
			const f=finish(B,{res,grime:d.grime,shadow:d.shadow,rim:false,shadowA:.3}); x.drawImage(f,v*cell,0); }
		files[id+'.png']=cv;
		return {files,meta:{class:'DECOR',res,variants:[id+'.png'],hull:[],sizePx:[d.cell,d.cell],occluder:false,breakable:null,explosive:false,tags:d.tags||{},solid:false,
			atlas:{cells:d.n,cellPx:[d.cell,d.cell],cellTexels:cell,blend:d.blend||'mix'}}}; }
	const pad=Math.max(8,(d.shadow||0)*2.2+3), [W,H]=sizeFor(d.box,res,pad);
	let first=null, hullCv=null;
	for(let v=0;v<d.n;v++){ const R=rng(3000+v*131+id.charCodeAt(0)*13+id.length);
		let B; if(d.wreck){ const src=renderWreck(CARS_WRECK[v],res); B=canvas(W,H); B.getContext('2d').drawImage(src,(W-src.width)/2,(H-src.height)/2); }
		else B=body(W,H,res,b=>d.draw(b,R,v));
		if(v===0){ first=B; hullCv=d.core?body(W,H,res,b=>d.core(b)):B; }
		const name=id+(v?'_v'+v:'')+'.png'; files[name]=finish(B,{res,grime:d.grime,shadow:d.shadow,rim:d.rim}); variants.push(name); }
	const hull=A.hull(hullCv,res,{max:10}), sizePx=A.bounds(first,res);
	const cls=d.cls, occluder=d.occluder!=null?d.occluder:(cls==='TALL'||cls==='WALL');
	let breakable=null;
	if(d.breakable){ const b=d.breakable, [bw,bh]=sizeFor(b.box||d.box,res,pad), R=rng(4000+id.charCodeAt(0));
		files[id+'_broken.png']=finish(body(bw,bh,res,x=>b.broken(x,R)),{res,grime:d.grime,shadow:b.rim===false?1.5:2,rim:b.rim===false?false:d.rim,shadowA:.3});
		const cell=Math.round(b.cell*res), strip=canvas(cell*4,cell), sx=strip.getContext('2d');
		for(let k=0;k<4;k++){ const Rk=rng(5000+k*17+id.charCodeAt(0)); sx.drawImage(finish(body(cell,cell,res,x=>b.debris(x,Rk,k)),{res,grime:d.grime,shadow:1.5,shadowA:.35}),k*cell,0); }
		files[id+'_debris.png']=strip;
		breakable={smashSpeed:b.smashSpeed,broken:id+'_broken.png',debris:id+'_debris.png',debrisCells:4}; if(b.blastOnly) breakable.blastOnly=true; }
	let beacon=null; if(d.beacon){ files[id+'_beacon.png']=body(W,H,res,b=>d.beacon(b)); beacon=id+'_beacon.png'; }
	const tags=Object.assign({},d.tags||{}); delete tags.bait; if(d.tags&&d.tags.bait) tags.bait=true;
	return {files,meta:{class:cls,res,variants,hull,sizePx,occluder,breakable,explosive:!!d.explosive,tags,solid:d.solid!==false,beacon}}; }
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
		p.goon('plowboss',1700,860,Math.PI,2); p.goon('magnet',2200,620,2.4,1); p.goon('shredder',900,620,.6,3); p.goon('sawbot',1250,1150,-.5,2); p.goon('harpooner',600,1100,-.2,4); p.goon('wrecker',1450,700,2,1); }}
};
/* the drawing API a poster's dress() uses; everything is queued by layer, then drawn in order */
function posterApi(P,x,ground){ const q=[], R=rng(P.seed*977+5), cache={}, S=PSC;
	const spr=id=>cache[id]||(cache[id]=bakeProp(id)); const name=(id,v,st)=>st==='broken'?id+'_broken.png':id+(v?'_v'+v:'')+'.png';
	const push=(layer,Y,fn)=>q.push({layer,Y,fn});
	const api={rng:R,ground,
		prop(id,X,Y,rot,v,s,st){ if(st==='none') return; const d=PROPS[id]; v=Math.min(v||0,(d.n||1)-1); const cv=spr(id).files[name(id,v,st)]; const layer=st==='broken'?1:d.cls==='TALL'?4:2;
			push(layer,Y,()=>{ x.save(); x.translate(X*S,Y*S); x.rotate(rot||0); const k=S/PROP_RES*(s||1); x.scale(k,k); x.drawImage(cv,-cv.width/2,-cv.height/2); x.restore(); }); },
		decor(id,X,Y,rot,cell,s){ const d=PROPS[id], cv=spr(id).files[id+'.png'], cw=cv.height; push(1,Y,()=>{ x.save(); x.translate(X*S,Y*S); x.rotate(rot); const k=S/PROP_RES*(s||1); x.scale(k,k); x.drawImage(cv,cell*cw,0,cw,cw,-cw/2,-cw/2,cw,cw); x.restore(); }); },
		car(key,X,Y,ang,stage){ const W=window.CarArt, cv=W.render(key,{style:'A',stage:stage||0,res:S,shadow:false}), sh=W.renderShadow(key,S);
			push(3,Y,()=>{ x.save(); x.translate(X*S,Y*S); x.rotate(ang+Math.PI/2); x.globalAlpha=.85; x.drawImage(sh,-sh.width/2,-sh.height/2); x.globalAlpha=1; x.drawImage(cv,-cv.width/2,-cv.height/2); x.restore(); }); },
		goon(id,X,Y,ang,frame){ const G=window.GoonArt, d=window.GOONS[id]; if(!d) return; const f=G.bake(d,'walk',(frame||0)%8,S*1.15).cv;
			push(3,Y,()=>{ x.save(); x.translate(X*S,Y*S); x.rotate(ang+Math.PI/2); x.drawImage(f,-f.width/2,-f.height/2); x.restore(); }); },
		tracks(pts,w,a,gap){ push(0,0,()=>{ x.save(); x.lineCap='round'; x.lineJoin='round'; for(const s of [-1,1]){ x.beginPath(); pts.forEach((p2,i)=>{ const nx=pts[Math.min(i+1,pts.length-1)], pv=pts[Math.max(i-1,0)], dx=nx[0]-pv[0], dy=nx[1]-pv[1], l=Math.hypot(dx,dy)||1, ox=-dy/l*(gap||24)*s, oy=dx/l*(gap||24)*s;
			const px=(p2[0]+ox)*S, py=(p2[1]+oy)*S; i?x.lineTo(px,py):x.moveTo(px,py); }); x.lineWidth=w*S; x.strokeStyle='rgba(22,18,14,'+a+')'; x.stroke(); } x.restore(); }); },
		dust(X,Y,r){ push(3.5,Y,()=>{ const g=x.createRadialGradient(X*S,Y*S,0,X*S,Y*S,r*S); g.addColorStop(0,'rgba(200,170,130,.45)'); g.addColorStop(1,'rgba(200,170,130,0)'); x.fillStyle=g; x.fillRect((X-r)*S,(Y-r)*S,r*2*S,r*2*S); }); },
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
		flush(f){ q.sort((a,b)=>a.layer-b.layer||a.Y-b.Y); for(const it of q) if(!f||f(it.layer)) it.fn(); }};
	return api; }
function renderPoster(id){ const P=POSTER[id], S=PSC, mats={}, offs={};
	for(const m of P.mats){ mats[m]=GROUND[m](GROUND_TEXELS).getContext('2d').getImageData(0,0,GROUND_TEXELS,GROUND_TEXELS).data; offs[m]=[(hash2(m.length,m.charCodeAt(0),801)*512)|0,(hash2(m.charCodeAt(1),7,802)*512)|0]; }
	const o={}; const reset=()=>{ o.a=P.mats[0]; o.b=null; o.t=0; o.tint=null; o.ao=0; o.lip=0; o.foam=0; o.wet=0; o.paint=null; };
	const ground=(X,Y)=>{ reset(); P.ground(X,Y,o); return o; };
	const samp=(m,tx,ty,out)=>{ const D=mats[m]; if(!D) throw new Error(id+': material '+m+' not in mats'); tx+=offs[m][0]; ty+=offs[m][1]; const x0=Math.floor(tx), y0=Math.floor(ty), fx=tx-x0, fy=ty-y0, M=511;
		const i00=(((y0&M)<<9)|(x0&M))<<2, i10=(((y0&M)<<9)|((x0+1)&M))<<2, i01=((((y0+1)&M)<<9)|(x0&M))<<2, i11=((((y0+1)&M)<<9)|((x0+1)&M))<<2;
		for(let k=0;k<3;k++) out[k]=(D[i00+k]*(1-fx)+D[i10+k]*fx)*(1-fy)+(D[i01+k]*(1-fx)+D[i11+k]*fx)*fy; };
	const cv=canvas(PW,PH), x=cv.getContext('2d'), im=x.createImageData(PW,PH), d=im.data, ca=[0,0,0], cb=[0,0,0];
	for(let j=0;j<PH;j++) for(let i=0;i<PW;i++){ const X=i/S, Y=j/S; ground(X,Y); samp(o.a,X*GROUND_DENSITY,Y*GROUND_DENSITY,ca);
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
	api.flush(l=>l>=9);
	const v=x.createRadialGradient(PW/2,PH/2,PH*.35,PW/2,PH/2,PW*.62); v.addColorStop(0,'rgba(10,8,6,0)'); v.addColorStop(1,'rgba(10,8,6,.42)'); x.fillStyle=v; x.fillRect(0,0,PW,PH);
	return cv; }

window.WorldArt={GROUND_TEXELS,GROUND_DENSITY,PROP_RES,GROUNDS:Object.keys(GROUND),EDGES:Object.keys(EDGE),PROPS:PROP_IDS,DECOR:DECOR_IDS,bakeProp,STATION:Object.keys(STATION),POSTERS:Object.keys(POSTER),renderStation,renderPoster,renderGround,renderMacro,renderEdge};
})();
