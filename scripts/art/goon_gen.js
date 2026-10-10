/* GoonCrusher goon art generator. Every goon is a design entry of about 15 numbers (bottom of this file) drawn by one of
   eleven rigs. bake_goons.py opens bake_goons.html in headless Edge, which calls GoonArt.bake for each frame.
   Units are game pixels; every goon faces up (-y), like the cars. See docs/GOONS.md. */
/* Light comes from straight overhead and the contact shadow is centered: goons turn all the time, so nothing
   in a frame may imply a sun direction. Frames are baked once and blitted, exactly as the game would use them. */
(function(){
"use strict";
const TAU=Math.PI*2;
function rng(seed){ let s=(seed>>>0)||1; return ()=>{ s^=s<<13; s>>>=0; s^=s>>17; s^=s<<5; s>>>=0; return s/4294967296; }; }
function hash2(x,y,seed){ let h=(Math.imul(x,374761393)+Math.imul(y,668265263)+Math.imul(seed,1442695041))|0; h=Math.imul(h^(h>>>13),1274126177); return ((h^(h>>>16))>>>0)/4294967296; }
function vnoise(x,y,seed){ const xi=Math.floor(x), yi=Math.floor(y), xf=x-xi, yf=y-yi; const u=xf*xf*(3-2*xf), v=yf*yf*(3-2*yf);
	const a=hash2(xi,yi,seed), b=hash2(xi+1,yi,seed), c=hash2(xi,yi+1,seed), d=hash2(xi+1,yi+1,seed); return a+(b-a)*u+(c-a)*v+(a-b-c+d)*u*v; }
function fbm(x,y,seed,oct){ oct=oct||4; let f=0,amp=.5,fr=1,n=0; for(let i=0;i<oct;i++){ f+=amp*vnoise(x*fr,y*fr,seed+i*17); n+=amp; amp*=.5; fr*=2.03; } return f/n; }
function smooth(a,b,x){ const t=Math.min(1,Math.max(0,(x-a)/(b-a))); return t*t*(3-2*t); }
function ease(t){ return smooth(0,1,t); }
function lerp(a,b,t){ return a+(b-a)*t; }
function hexRgb(h){ h=h.replace('#',''); const n=parseInt(h,16); return [n>>16&255,n>>8&255,n&255]; }
function mixc(a,b,t){ return [a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t]; }
function css(c,a){ return 'rgba('+(c[0]|0)+','+(c[1]|0)+','+(c[2]|0)+','+(a==null?1:a)+')'; }
function shade(c,t){ return t<0?mixc(c,[0,0,0],-t):mixc(c,[255,255,255],t); }
function C(h){ return typeof h==='string'?hexRgb(h):h; }

const GOON_SKIN='#9a8aa8', GOON_ORANGE='#e0782c', GOO='#3a3046';

/* ---------- shared paint ---------- */
let GRIME=null;
function grime(){ if(GRIME) return GRIME; const n=128, c=document.createElement('canvas'); c.width=c.height=n; const x=c.getContext('2d'), im=x.createImageData(n,n);
	for(let y=0;y<n;y++) for(let i=0;i<n;i++){ const f=fbm(i/11,y/11,7,4), s=hash2(i,y,3), o=(y*n+i)*4; const a=smooth(.5,.82,f)*120+(s>.94?70:0);
		im.data[o]=46; im.data[o+1]=34; im.data[o+2]=24; im.data[o+3]=a; } x.putImageData(im,0,0); GRIME=c; return c; }
function ell(ctx,x,y,rx,ry,rot){ ctx.beginPath(); ctx.ellipse(x,y,Math.max(.01,rx),Math.max(.01,ry),rot||0,0,TAU); }
/* overhead-lit volume: bright crown, dark rim */
function vol(ctx,x,y,rx,ry,col,o){ o=o||{}; col=C(col); ell(ctx,x,y,rx,ry,o.rot); const r=Math.max(rx,ry);
	const g=ctx.createRadialGradient(x,y-ry*(o.fy==null?.12:o.fy),r*.04,x,y,r*1.06);
	g.addColorStop(0,css(shade(col,o.hi==null?.24:o.hi))); g.addColorStop(.55,css(col)); g.addColorStop(1,css(shade(col,o.lo==null?-.42:o.lo))); ctx.fillStyle=g; ctx.fill(); }
function polyVol(ctx,pts,cx,cy,r,col,o){ o=o||{}; col=C(col); ctx.beginPath(); ctx.moveTo(pts[0][0],pts[0][1]); for(let i=1;i<pts.length;i++) ctx.lineTo(pts[i][0],pts[i][1]); ctx.closePath();
	const g=ctx.createRadialGradient(cx,cy-r*.12,r*.05,cx,cy,r*1.1); g.addColorStop(0,css(shade(col,o.hi==null?.22:o.hi))); g.addColorStop(.55,css(col)); g.addColorStop(1,css(shade(col,o.lo==null?-.45:o.lo))); ctx.fillStyle=g; ctx.fill(); }
function limb(ctx,a,b,w,col){ col=C(col); ctx.lineCap='round'; ctx.beginPath(); ctx.moveTo(a[0],a[1]); ctx.lineTo(b[0],b[1]); ctx.strokeStyle=css(shade(col,-.4)); ctx.lineWidth=w; ctx.stroke();
	ctx.beginPath(); ctx.moveTo(a[0],a[1]); ctx.lineTo(b[0],b[1]); ctx.strokeStyle=css(col); ctx.lineWidth=w*.6; ctx.stroke(); }
function eye(meta,ctx,x,y,r,col){ ell(ctx,x,y,r,r*1.1); ctx.fillStyle=col||'#16121a'; ctx.fill(); ell(ctx,x-r*.3,y-r*.35,r*.35,r*.35); ctx.fillStyle='rgba(255,250,235,.85)'; ctx.fill();
	if(meta){ const p=ctx.getTransform().transformPoint(new DOMPoint(x,y)); meta.eyes.push([p.x,p.y]); } }
function rust(ctx,x,y,r,seed){ const R=rng(seed); for(let i=0;i<3;i++){ ell(ctx,x+(R()-.5)*r*1.4,y+(R()-.5)*r*1.4,r*(.18+R()*.22),r*(.14+R()*.2),R()*3); ctx.fillStyle='rgba(122,62,30,'+(.35+R()*.3)+')'; ctx.fill(); } }
function rag(ctx,x,y,len,ph,acc){ acc=C(acc||GOON_ORANGE); for(const s of [1]){ const w=Math.sin(ph*TAU+s)*len*.25; ctx.beginPath(); ctx.moveTo(x+s*len*.12,y); ctx.quadraticCurveTo(x+s*len*.35+w*.5,y+len*.5,x+s*len*.3+w,y+len);
	ctx.lineTo(x+s*len*.08+w,y+len*.85); ctx.quadraticCurveTo(x+s*len*.1,y+len*.4,x,y); ctx.closePath(); ctx.fillStyle=css(shade(acc,s>0?-.12:0)); ctx.fill(); } ell(ctx,x,y,len*.18,len*.14); ctx.fillStyle=css(shade(acc,-.2)); ctx.fill(); }

/* ---------- weapons and props (drawn from a hand, pointing along angle a; -PI/2 is forward) ---------- */
const PROPS={
	pipe(ctx,h,a,R){ const L=R*1.2, x0=h[0]-Math.cos(a)*R*.25, y0=h[1]-Math.sin(a)*R*.25, x1=h[0]+Math.cos(a)*L, y1=h[1]+Math.sin(a)*L;
		limb(ctx,[x0,y0],[x1,y1],R*.17,'#6d6a66'); ell(ctx,x1,y1,R*.15,R*.15); ctx.fillStyle='#4e4b48'; ctx.fill(); ell(ctx,x1-Math.cos(a)*R*.5,y1-Math.sin(a)*R*.5,R*.1,R*.1); ctx.fillStyle='rgba(130,64,32,.8)'; ctx.fill(); },
	wrench(ctx,h,a,R){ const L=R*1.1, x1=h[0]+Math.cos(a)*L, y1=h[1]+Math.sin(a)*L; limb(ctx,h,[x1,y1],R*.15,'#8b8d90'); ctx.save(); ctx.translate(x1,y1); ctx.rotate(a);
		ctx.beginPath(); ctx.arc(0,0,R*.26,.6,TAU-.6); ctx.lineWidth=R*.14; ctx.strokeStyle='#9a9c9f'; ctx.stroke(); ctx.restore(); },
	flare(ctx,h,a,R,t){ const L=R*.7, x1=h[0]+Math.cos(a)*L, y1=h[1]+Math.sin(a)*L; limb(ctx,h,[x1,y1],R*.16,'#7a2f22'); const f=.8+.35*Math.sin(t*TAU*3);
		const g=ctx.createRadialGradient(x1,y1,0,x1,y1,R*.55*f); g.addColorStop(0,'rgba(255,246,200,1)'); g.addColorStop(.35,'rgba(255,170,60,.9)'); g.addColorStop(1,'rgba(255,90,20,0)'); ctx.fillStyle=g; ell(ctx,x1,y1,R*.55*f,R*.55*f); ctx.fill(); },
	megaphone(ctx,h,a,R){ ctx.save(); ctx.translate(h[0],h[1]); ctx.rotate(a+Math.PI/2); ctx.beginPath(); ctx.moveTo(-R*.14,0); ctx.lineTo(R*.14,0); ctx.lineTo(R*.42,-R*.8); ctx.lineTo(-R*.42,-R*.8); ctx.closePath();
		const g=ctx.createLinearGradient(-R*.4,0,R*.4,0); g.addColorStop(0,'#c9c4b6'); g.addColorStop(.5,'#f1ece0'); g.addColorStop(1,'#a8a294'); ctx.fillStyle=g; ctx.fill(); ell(ctx,0,-R*.8,R*.42,R*.12); ctx.fillStyle='#d7672a'; ctx.fill(); ctx.restore(); },
	none(){}
};

/* ---------- headgear ---------- */
const HATS={
	bucket(ctx,h,d,ph){ vol(ctx,0,0,h*1.12,h*1.08,'#8a8c89',{hi:.3}); ctx.lineWidth=h*.12; ctx.strokeStyle='rgba(40,40,40,.45)'; ell(ctx,0,0,h*.86,h*.82); ctx.stroke(); rust(ctx,h*.2,h*.1,h*.8,5);
		ctx.beginPath(); ctx.arc(0,0,h*1.0,-.4,Math.PI+.4,true); ctx.strokeStyle='rgba(30,30,30,.55)'; ctx.lineWidth=h*.08; ctx.stroke(); },
	moto(ctx,h,d){ vol(ctx,0,0,h*1.1,h*1.12,d.helmCol||'#7a2a26',{hi:.35}); ctx.beginPath(); ctx.ellipse(0,-h*.25,h*.95,h*.8,0,Math.PI*1.08,Math.PI*1.92); ctx.lineWidth=h*.32; ctx.strokeStyle='#17191c'; ctx.stroke();
		ctx.fillStyle='rgba(240,236,226,.8)'; ctx.fillRect(-h*.08,-h*.2,h*.16,h*1.2); },
	goggles(ctx,h,d,ph,meta){ ell(ctx,0,0,h*.98,h*.98); ctx.lineWidth=h*.16; ctx.strokeStyle='#2a2522'; ctx.stroke();
		for(const s of [-1,1]){ vol(ctx,s*h*.4,-h*.62,h*.3,h*.27,'#c58a2c',{hi:.5}); ell(ctx,s*h*.4,-h*.62,h*.3,h*.27); ctx.lineWidth=h*.09; ctx.strokeStyle='#3a3530'; ctx.stroke(); }
		if(meta){ const T=ctx.getTransform(); for(const s of [-1,1]){ const p=T.transformPoint(new DOMPoint(s*h*.4,-h*.62)); meta.eyes.push([p.x,p.y]); } } return 'lens'; },
	gasmask(ctx,h,d,ph,meta){ vol(ctx,0,0,h*1.05,h*1.05,'#34373a'); for(const s of [-1,1]){ vol(ctx,s*h*.42,-h*.55,h*.27,h*.25,'#7f9a82',{hi:.55}); ell(ctx,s*h*.42,-h*.55,h*.27,h*.25); ctx.lineWidth=h*.08; ctx.strokeStyle='#222'; ctx.stroke(); }
		vol(ctx,0,-h*1.12,h*.36,h*.34,'#5d6440'); ctx.lineWidth=h*.06; ctx.strokeStyle='rgba(0,0,0,.4)'; ell(ctx,0,-h*1.12,h*.24,h*.22); ctx.stroke();
		if(meta){ const T=ctx.getTransform(); for(const s of [-1,1]){ const p=T.transformPoint(new DOMPoint(s*h*.42,-h*.55)); meta.eyes.push([p.x,p.y]); } } return 'lens'; },
	cone(ctx,h){ ctx.save(); ctx.rotate(.25); ctx.beginPath(); const b=h*.82; ctx.rect(-b,-b,b*2,b*2); ctx.fillStyle='#b14d1f'; ctx.fill(); ctx.restore();
		vol(ctx,0,0,h*.78,h*.78,'#e0682a',{hi:.2}); ell(ctx,0,0,h*.5,h*.5); ctx.lineWidth=h*.16; ctx.strokeStyle='#eceae2'; ctx.stroke(); ell(ctx,0,0,h*.18,h*.18); ctx.fillStyle='#2a1a12'; ctx.fill(); },
	hardhat(ctx,h){ ell(ctx,0,-h*.18,h*1.18,h*1.22); ctx.fillStyle='#a8861c'; ctx.fill(); vol(ctx,0,0,h*1.0,h*1.04,'#e0b52a',{hi:.3}); ctx.fillStyle='rgba(255,255,255,.35)'; ctx.fillRect(-h*.09,-h*.95,h*.18,h*1.9); },
	welding(ctx,h,d,ph,meta){ vol(ctx,0,0,h*1.02,h*1.0,'#4a4a48'); ctx.beginPath(); ctx.moveTo(-h*.95,-h*.2); ctx.quadraticCurveTo(0,-h*1.6,h*.95,-h*.2); ctx.closePath(); ctx.fillStyle='#2b2c2d'; ctx.fill();
		ctx.fillStyle='#0d1210'; ctx.fillRect(-h*.5,-h*.82,h*1.0,h*.2); if(meta){ const T=ctx.getTransform(); for(const s of [-1,1]){ const p=T.transformPoint(new DOMPoint(s*h*.25,-h*.72)); meta.eyes.push([p.x,p.y]); } } return 'lens'; },
	hood(ctx,h,d,ph,meta){ vol(ctx,0,h*.12,h*1.18,h*1.22,d.hoodCol||'#2f2a35',{hi:.18}); ell(ctx,0,-h*.48,h*.66,h*.5); ctx.fillStyle='#0c0a0f'; ctx.fill();
		for(const s of [-1,1]) eye(meta,ctx,s*h*.28,-h*.52,h*.15,'#d9d2a0'); return 'lens'; },
	cap(ctx,h,d){ ctx.beginPath(); rr(ctx,-h*.62,h*.55,h*1.24,h*.75,h*.3); ctx.fillStyle=css(shade(C(d.capCol||'#2b4f6b'),-.2)); ctx.fill(); vol(ctx,0,0,h*1.0,h*1.0,d.capCol||'#2b4f6b',{hi:.25}); },
	football(ctx,h,d,ph){ vol(ctx,0,0,h*1.12,h*1.12,d.helmCol||'#c8c2b0',{hi:.3}); ctx.fillStyle='rgba(150,40,30,.85)'; ctx.fillRect(-h*.16,-h*1.1,h*.32,h*2.2);
		ctx.strokeStyle='#5c5e60'; ctx.lineWidth=h*.1; for(const k of [0,1]){ ctx.beginPath(); ctx.arc(0,-h*.3,h*(1.0+k*.22),-2.4,-.74); ctx.stroke(); } },
	bandana(ctx,h,d){ vol(ctx,0,0,h*1.02,h*1.02,d.bandCol||'#7e2b25',{hi:.2}); ctx.strokeStyle='rgba(255,255,255,.35)'; ctx.lineWidth=h*.06; for(let i=0;i<5;i++){ ell(ctx,(i-2)*h*.36,(i%2)*h*.3-h*.15,h*.1,h*.1); ctx.stroke(); } },
	mohawk(ctx,h,d){ ctx.fillStyle=d.crestCol||'#2aa6a1'; for(let i=0;i<6;i++){ const y=-h*.85+i*h*.34; ctx.beginPath(); ctx.moveTo(-h*.16,y+h*.2); ctx.lineTo(0,y-h*.12); ctx.lineTo(h*.16,y+h*.2); ctx.closePath(); ctx.fill(); } },
	none(){}
};
function rr(ctx,x,y,w,h,r){ r=Math.min(r,w/2,h/2); ctx.moveTo(x+r,y); ctx.arcTo(x+w,y,x+w,y+h,r); ctx.arcTo(x+w,y+h,x,y+h,r); ctx.arcTo(x,y+h,x,y,r); ctx.arcTo(x,y,x+w,y,r); ctx.closePath(); }

/* ---------- biped rig ---------- */
function bipedPose(d,anim,t){
	const R=d.R, st=R*.82*(d.stride||1), arm=d.arm||1;
	const p={fL:[-R*.42,0],fR:[R*.42,0],hL:[-R*1.0*arm,-R*.05],hR:[R*1.0*arm,-R*.05],a:-1.25,rot:0,sc:1,dx:0,dy:0,ph:0,crouch:0,mouth:0,anim,t,R};
	const orbit=(a)=>[R*.86+Math.cos(a)*R*.5*arm,Math.sin(a)*R*.5*arm];
	if(anim==='walk'){ const s=Math.sin(TAU*t); p.fL[1]=-st*s; p.fR[1]=st*s; p.hL[1]=st*s*.75-R*.05; p.hR[1]=-st*s*.75-R*.05; p.rot=.07*s; p.sc=1+.025*Math.cos(2*TAU*t); p.a=-1.25+.14*s; p.ph=t; p.hR=orbit(p.a); }
	else if(anim==='idle'){ const s=Math.sin(TAU*t); p.sc=1+.02*s; p.hL[1]+=R*.05*s; p.a=-1.1+.06*s; p.hR=orbit(p.a); p.ph=t*.5; }
	else if(anim==='windup'){ const e=ease(t/.75); p.fL=[-R*.54,-R*.34*e]; p.fR=[R*.54,R*.36*e]; p.rot=-.34*e; p.a=lerp(-1.25,1.3,e); p.hR=orbit(p.a); p.hL=[-R*1.05,lerp(-R*.05,-R*.6,e)]; p.sc=1+.05*e; p.crouch=e; p.mouth=e; if(t>.75) p.dx=Math.sin(t*95)*R*.04; p.ph=.25; }
	else if(anim==='attack'){ const e=ease(Math.min(1,t*1.5)); p.fL=[-R*.5,-R*.62]; p.fR=[R*.5,R*.52]; p.rot=lerp(-.34,.46,e); p.a=lerp(1.3,-2.75,e); p.hR=orbit(p.a); p.hL=[-R*1.0,lerp(-R*.6,R*.25,e)]; p.dy=-R*.3*Math.sin(Math.PI*Math.min(1,t*1.2)); p.mouth=1; p.ph=.5; }
	else if(anim==='stun'){ const s=Math.sin(TAU*t); p.rot=s*.3; p.hL=[-R*1.25,R*.25]; p.hR=[R*1.25,R*.2]; p.a=.9; p.sc=.97; p.ph=t; }
	else if(anim==='splat'){ p.fL=[-R*.72,R*.9]; p.fR=[R*.78,R*.82]; p.hL=[-R*1.45,-R*.55]; p.hR=[R*1.5,-R*.2]; p.a=.35; p.ph=.3; }
	else if(anim==='special'){ p.ph=t; p.hR=orbit(p.a); }
	else if(anim==='ride'){ p.fL=[-R*.62,R*.18]; p.fR=[R*.62,R*.18]; p.ph=t*.5; }
	if(d.grip==='two'){ /* two-handed tools: both hands meet on the haft */ p.two=true; }
	if(anim==='special'&&d.specialPose) d.specialPose(p,t,R);
	return p;
}
function drawBiped(ctx,d,anim,t,meta){
	const R=d.R, p=bipedPose(d,anim,t), skin=C(d.skin||GOON_SKIN), cloth=C(d.cloth), boots=C(d.boots||'#3a3029'), sleeve=d.sleeve?C(d.sleeve):cloth, h=R*(d.head||.7);
	ctx.save(); ctx.translate(p.dx,p.dy); ctx.scale(p.sc,p.sc);
	for(const f of [p.fL,p.fR]){ vol(ctx,f[0],f[1],R*.22,R*.34,boots,{hi:.15}); }
	if(d.scarf){ const w=Math.sin(p.ph*TAU)*R*.4; ctx.beginPath(); ctx.moveTo(-R*.2,-R*.1); ctx.bezierCurveTo(-R*.3+w,R*.9,R*.3-w,R*1.5,w*.8,R*2.3); ctx.lineTo(w*.8+R*.22,R*2.2); ctx.bezierCurveTo(R*.4-w,R*1.4,-R*.05+w,R*.8,R*.2,-R*.1); ctx.closePath(); ctx.fillStyle=css(C(d.accent||GOON_ORANGE)); ctx.fill(); }
	ctx.save(); ctx.rotate(p.rot);
	if(d.back==='spikeroll'){ ctx.save(); ctx.translate(0,R*.62); ctx.beginPath(); rr(ctx,-R*.95,-R*.26,R*1.9,R*.52,R*.24); ctx.fillStyle='#2a2826'; ctx.fill(); ctx.fillStyle='#b9bbbd';
		for(let i=-4;i<=4;i++){ ctx.beginPath(); ctx.moveTo(i*R*.2-R*.06,-R*.26); ctx.lineTo(i*R*.2,-R*.42); ctx.lineTo(i*R*.2+R*.06,-R*.26); ctx.fill(); ctx.beginPath(); ctx.moveTo(i*R*.2-R*.06,R*.26); ctx.lineTo(i*R*.2,R*.42); ctx.lineTo(i*R*.2+R*.06,R*.26); ctx.fill(); } ctx.restore(); }
	const shL=[-R*.84,R*.02], shR=[R*.84,R*.02];
	if(p.two){ const g=d.twoGrip(p,R); p.hL=g[0]; p.hR=g[1]; }
	limb(ctx,shL,p.hL,R*.32,sleeve); limb(ctx,shR,p.hR,R*.32,sleeve);
	/* torso */
	const dep=d.dep||.62;
	if(d.fur){ furBlob(ctx,0,R*.05,R*1.02,R*dep*1.05,d.cloth,d.seed||3,p.ph); } else vol(ctx,0,R*.05,R,R*dep,cloth,{hi:.2});
	if(d.belly){ vol(ctx,0,-R*.18,R*.62,R*.42,shade(cloth,.06),{hi:.18,lo:-.2}); }
	if(d.vest){ ctx.save(); ell(ctx,0,R*.05,R,R*dep); ctx.clip(); ctx.fillStyle='rgba(226,122,30,.92)'; ctx.fillRect(-R,-R,R*2,R*2); ctx.fillStyle='rgba(225,228,224,.85)'; ctx.fillRect(-R*.58,-R,R*.16,R*2); ctx.fillRect(R*.42,-R,R*.16,R*2);
		ctx.fillStyle=css(shade(cloth,-.1)); ctx.fillRect(-R*.12,-R,R*.24,R*2); ctx.restore(); }
	if(d.apron){ ctx.save(); ell(ctx,0,R*.05,R,R*dep); ctx.clip(); ctx.fillStyle='#5b3b25'; ctx.fillRect(-R*.62,-R*1.0,R*1.24,R*.85); ctx.restore(); }
	if(d.pads==='tire') for(const s of [-1,1]){ ell(ctx,s*R*.8,0,R*.38,R*.32); ctx.fillStyle='#1f1e20'; ctx.fill(); ell(ctx,s*R*.8,0,R*.2,R*.16); ctx.fillStyle=css(sleeve); ctx.fill();
		ctx.strokeStyle='rgba(120,120,120,.35)'; ctx.lineWidth=R*.05; for(let k=0;k<8;k++){ const a=k/8*TAU; ctx.beginPath(); ctx.moveTo(s*R*.8+Math.cos(a)*R*.26,Math.sin(a)*R*.22); ctx.lineTo(s*R*.8+Math.cos(a)*R*.36,Math.sin(a)*R*.3); ctx.stroke(); } }
	if(d.pads==='plates') for(const s of [-1,1]){ vol(ctx,s*R*.78,-R*.02,R*.36,R*.42,d.padCol||'#c8c2b0',{hi:.3}); }
	if(d.back==='gascan'){ ctx.beginPath(); rr(ctx,-R*.1,R*.3,R*.62,R*.5,R*.08); ctx.fillStyle='#9e3226'; ctx.fill(); ctx.fillStyle='#2b2b2b'; ctx.fillRect(R*.34,R*.32,R*.12,R*.12); }
	if(d.back==='tanks') for(const s of [-1,1]){ vol(ctx,s*R*.3,R*.55,R*.24,R*.3,'#6a7a4a'); }
	if(d.back==='pack'){ ctx.beginPath(); rr(ctx,-R*.5,R*.28,R*1.0,R*.55,R*.14); ctx.fillStyle='#5f5c3c'; ctx.fill(); ctx.fillStyle='rgba(0,0,0,.25)'; ctx.fillRect(-R*.5,R*.5,R*1.0,R*.06); }
	/* head */
	ctx.save(); ctx.translate(0,-R*.08-p.crouch*R*.06);
	if(d.horns) for(const s of [-1,1]){ ctx.beginPath(); ctx.moveTo(s*h*.6,-h*.3); ctx.quadraticCurveTo(s*h*1.6,-h*.4,s*h*1.5,-h*1.25); ctx.quadraticCurveTo(s*h*1.25,-h*.55,s*h*.62,h*.15); ctx.closePath(); ctx.fillStyle='#d8cdb4'; ctx.fill(); }
	if(d.ears==='big') for(const s of [-1,1]){ ctx.beginPath(); ctx.moveTo(s*h*.55,-h*.35); ctx.quadraticCurveTo(s*h*2.0,-h*.2,s*h*2.1,h*.55); ctx.quadraticCurveTo(s*h*1.2,h*.3,s*h*.6,h*.35); ctx.closePath();
		ctx.fillStyle=css(skin); ctx.fill(); ctx.beginPath(); ctx.moveTo(s*h*.75,-h*.12); ctx.quadraticCurveTo(s*h*1.7,-h*.02,s*h*1.8,h*.4); ctx.quadraticCurveTo(s*h*1.2,h*.2,s*h*.75,h*.2); ctx.closePath(); ctx.fillStyle='rgba(200,120,140,.6)'; ctx.fill(); }
	else if(!d.human) for(const s of [-1,1]){ ctx.beginPath(); ctx.moveTo(s*h*.7,-h*.3); ctx.lineTo(s*h*1.35,-h*.05); ctx.lineTo(s*h*.75,h*.3); ctx.closePath(); ctx.fillStyle=css(shade(skin,-.08)); ctx.fill(); }
	if(d.fur){ furBlob(ctx,0,0,h*1.05,h*1.05,d.cloth,(d.seed||3)+9,p.ph); vol(ctx,0,-h*.42,h*.56,h*.44,skin,{hi:.2}); } else vol(ctx,0,0,h,h,skin,{hi:.22});
	if(!d.hat||d.hat==='none'||d.hat==='hardhat'||d.hat==='cap'||d.hat==='football'||d.hat==='moto'||d.hat==='bucket'||d.hat==='cone'||d.hat==='bandana'){
		ell(ctx,0,-h*.55,h*.62,h*.3); ctx.fillStyle='rgba(30,20,40,.22)'; ctx.fill(); }
	if(d.rag!==false) rag(ctx,h*.25,h*.72,h*.85,p.ph,d.accent);
	let lens=null; if(d.hat&&HATS[d.hat]){ const small=!/^(gasmask|welding|hood|goggles)$/.test(d.hat); if(small){ ctx.save(); ctx.translate(0,h*.08); ctx.scale(.8,.8); } lens=HATS[d.hat](ctx,h,d,p.ph,meta); if(small) ctx.restore(); }
	if(!lens){ for(const s of [-1,1]) eye(meta,ctx,s*h*.36,-h*.78,h*.15,d.eyeCol); }
	if(p.mouth>.3&&!d.fur&&!lens){ ell(ctx,0,-h*.98,h*.28*p.mouth,h*.1*p.mouth); ctx.fillStyle='rgba(30,10,20,.8)'; ctx.fill(); }
	ctx.restore();
	/* hands and tools on top */
	const glove=C(d.glove||d.skin||GOON_SKIN);
	if(d.shield){ const e=anim==='windup'?ease(t/.75):anim==='attack'?1:0, sx=lerp(-R*.62,-R*.25,e), sy=lerp(-R*.86,-R*1.1,e); p.hL=[sx+R*.1,sy+R*.25]; shieldDraw(ctx,sx,sy,R*.66,d); }
	for(const hnd of [p.hL,p.hR]){ vol(ctx,hnd[0],hnd[1],R*.18,R*.18,glove,{hi:.2}); }
	if(d.tool&&PROPS[d.tool]) PROPS[d.tool](ctx,p.hR,p.a,R,t);
	if(d.drawTool) d.drawTool(ctx,p,R,anim,t);
	ctx.restore(); ctx.restore();
}
function shieldDraw(ctx,x,y,r,d){ if(d.shield==='sign'){ ctx.beginPath(); for(let i=0;i<8;i++){ const a=i/8*TAU+TAU/16; ctx.lineTo(x+Math.cos(a)*r,y+Math.sin(a)*r*.55); } ctx.closePath(); ctx.fillStyle='#a8302a'; ctx.fill(); ctx.lineWidth=r*.1; ctx.strokeStyle='#e8e2d6'; ctx.stroke(); rust(ctx,x,y,r*.6,31); return; }
	const g=ctx.createRadialGradient(x,y-r*.1,r*.05,x,y,r); g.addColorStop(0,'#f3f2ee'); g.addColorStop(.45,'#a9abad'); g.addColorStop(.7,'#d9dad7'); g.addColorStop(1,'#5d6064');
	ell(ctx,x,y,r,r*.62); ctx.fillStyle=g; ctx.fill(); ctx.fillStyle='rgba(40,42,46,.65)'; for(let i=0;i<6;i++){ const a=i/6*TAU; ell(ctx,x+Math.cos(a)*r*.58,y+Math.sin(a)*r*.36,r*.13,r*.08,a); ctx.fill(); }
	ell(ctx,x,y,r*.22,r*.15); ctx.fillStyle='#4a4d52'; ctx.fill(); rust(ctx,x+r*.3,y,r*.5,17); }
function furBlob(ctx,x,y,rx,ry,col,seed,ph){ col=C(col); const N=34, pts=[]; for(let i=0;i<N;i++){ const a=i/N*TAU, k=(i%2?1.0:1.13)+(hash2(i,seed,5)-.5)*.12+Math.sin(a*3+ph*TAU)*.015; pts.push([x+Math.cos(a)*rx*k,y+Math.sin(a)*ry*k]); }
	polyVol(ctx,pts,x,y,Math.max(rx,ry),col,{hi:.18}); }

/* ---------- critter rig (four legs) ---------- */
function drawQuad(ctx,d,anim,t,meta){
	const R=d.R, L=R*(d.len||1.2), W=R*(d.wid||.62), fur=C(d.fur), skin=C(d.skin||GOON_SKIN), lizard=d.lizard;
	let s=0,sy=1,headF=0,mouth=0,rot=0,ph=0,emerge=1;
	if(anim==='walk'){ s=Math.sin(TAU*t); rot=(lizard?.14:.06)*s; ph=t; }
	else if(anim==='idle'){ ph=t*.5; sy=1+.02*Math.sin(TAU*t); }
	else if(anim==='windup'){ const e=ease(t/.75); sy=1-.12*e; headF=-R*.18*e; mouth=e*.4; }
	else if(anim==='attack'){ const k=Math.sin(Math.PI*Math.min(1,t*1.3)); sy=1+.16*k; headF=R*.42*k; mouth=k; }
	else if(anim==='stun'){ rot=Math.sin(TAU*t)*.35; }
	else if(anim==='special'){ if(d.burrow||d.log) emerge=t; else { s=Math.sin(TAU*t*2); ph=t*2; sy=1.06; } }
	else if(anim==='splat'){ sy=1.1; }
	const st=R*.42*(d.stride||1);
	if(d.log&&emerge<1){ const m=1-emerge; ctx.save(); ctx.globalAlpha=m; ctx.beginPath(); rr(ctx,-R*.7,-L*1.1,R*1.4,L*2.3,R*.6); const lg=ctx.createLinearGradient(-R*.7,0,R*.7,0); lg.addColorStop(0,'#2e2318'); lg.addColorStop(.5,'#6b5034'); lg.addColorStop(1,'#2e2318'); ctx.fillStyle=lg; ctx.fill();
		ctx.strokeStyle='rgba(30,20,12,.6)'; ctx.lineWidth=R*.06; for(let i=0;i<6;i++){ ctx.beginPath(); ctx.moveTo(-R*.5,-L*.9+i*L*.35); ctx.quadraticCurveTo(0,-L*.8+i*L*.35,R*.5,-L*.9+i*L*.35); ctx.stroke(); } ell(ctx,0,-L*1.1,R*.55,R*.25); ctx.fillStyle='#a88a5c'; ctx.fill(); ctx.restore();
		for(const k of [-1,1]) eye(meta,ctx,k*R*.3,-L*.55,R*.1,'#d9c25a'); if(emerge<=0.02) return; ctx.globalAlpha=emerge; }
	else if(d.burrow&&emerge<1){ const m=1-emerge; ell(ctx,0,0,R*1.15*m+R*.2,L*1.0*m+R*.2); ctx.fillStyle='rgba(88,70,48,'+(.95*m)+')'; ctx.fill();
		const R2=rng(4); for(let i=0;i<9;i++){ ell(ctx,(R2()-.5)*R*1.8*m,(R2()-.5)*L*1.6*m,R*.12,R*.1); ctx.fillStyle='rgba(60,46,30,'+(.8*m)+')'; ctx.fill(); }
		for(const k of [-1,1]) eye(meta,ctx,k*R*.22,-L*.62*m-R*.2,R*.1,'#e8d26a'); if(emerge<=0.02) return; ctx.globalAlpha=emerge; ctx.scale(.75+.25*emerge,.75+.25*emerge); }
	ctx.save(); ctx.rotate(rot); ctx.scale(1,sy);
	/* tail */
	if(d.tail){ const tl=R*d.tail, w0=lizard?R*.42:R*.14; ctx.beginPath(); const sw=Math.sin(TAU*ph+1)*R*(lizard?.7:.5);
		ctx.moveTo(-w0,L*.75); ctx.bezierCurveTo(-w0*.8,L+tl*.4,sw-w0*.3,L+tl*.7,sw,L+tl); ctx.bezierCurveTo(sw+w0*.3,L+tl*.7,w0*.8,L+tl*.4,w0,L*.75); ctx.closePath();
		ctx.fillStyle=css(d.tailSkin?shade(skin,-.05):shade(fur,-.1)); ctx.fill(); }
	/* legs */
	const legs=[[-1,-1,-1],[1,-1,1],[-1,1,1],[1,1,-1]];
	for(const [sx,sy2,ph2] of legs){ const fx=sx*W*(lizard?1.75:1.05), fy=sy2*L*(lizard?.45:.5)+ph2*st*s;
		if(lizard){ limb(ctx,[sx*W*.6,sy2*L*.42],[fx,fy],R*.2,fur); for(let k=-1;k<=1;k++){ ctx.beginPath(); ctx.moveTo(fx,fy); ctx.lineTo(fx+sx*R*.22+k*R*.06,fy+k*R*.16-sy2*R*.06); ctx.lineWidth=R*.06; ctx.strokeStyle=css(shade(fur,-.3)); ctx.stroke(); } }
		else vol(ctx,fx,fy,R*.2,R*.26,d.paw?C(d.paw):shade(fur,-.2),{hi:.15}); }
	/* body */
	if(d.furry) furBlob(ctx,0,0,W,L,fur,d.seed||5,ph); else vol(ctx,0,0,W,L,fur,{hi:.2});
	if(d.stripe){ ctx.beginPath(); ctx.ellipse(0,0,W*.28,L*.85,0,0,TAU); ctx.fillStyle=css(shade(fur,-.18)); ctx.fill(); }
	if(lizard){ const R3=rng(9); for(let i=0;i<22;i++){ const a=R3()*TAU, rr2=Math.sqrt(R3()); ell(ctx,Math.cos(a)*W*.8*rr2,Math.sin(a)*L*.85*rr2,R*.09,R*.08); ctx.fillStyle=i%3?'rgba(40,52,24,.45)':'rgba(154,138,168,.75)'; ctx.fill(); } }
	if(d.collar){ ctx.beginPath(); ctx.ellipse(0,-L*.72,W*.62,R*.2,0,0,TAU); ctx.fillStyle=css(C(d.accent||GOON_ORANGE)); ctx.fill(); }
	/* head */
	const hy=-L*.98-headF, hr=R*(d.headR||.44);
	if(d.ears==='rat') for(const k of [-1,1]){ vol(ctx,k*hr*.85,hy+hr*.35,hr*.48,hr*.42,skin,{hi:.2}); ell(ctx,k*hr*.85,hy+hr*.35,hr*.26,hr*.22); ctx.fillStyle='rgba(205,135,150,.7)'; ctx.fill(); }
	if(d.ears==='long') for(const k of [-1,1]){ ctx.save(); ctx.translate(k*hr*.4,hy+hr*.3); ctx.rotate(k*.35); vol(ctx,0,hr*1.1,hr*.36,hr*1.25,fur,{hi:.18}); ell(ctx,0,hr*1.1,hr*.18,hr*.95); ctx.fillStyle='rgba(205,150,140,.55)'; ctx.fill(); ctx.restore(); }
	vol(ctx,0,hy,hr,hr*(lizard?1.25:1.2),fur,{hi:.22});
	if(lizard){ const j=d.jaw||1; ctx.beginPath(); ctx.moveTo(-hr*.7,hy-hr*.4); ctx.quadraticCurveTo(-hr*.5,hy-hr*1.9*j,0,hy-hr*2.0*j); ctx.quadraticCurveTo(hr*.5,hy-hr*1.9*j,hr*.7,hy-hr*.4); ctx.closePath(); ctx.fillStyle=css(shade(fur,-.05)); ctx.fill();
		if(d.jaw){ ctx.fillStyle='#ece4cc'; for(const k of [-1,1]) for(let i=0;i<4;i++){ const y=hy-hr*(.6+i*.32)*j; ctx.beginPath(); ctx.moveTo(k*hr*.42*(1-i*.15),y); ctx.lineTo(k*hr*.58*(1-i*.15),y-hr*.08); ctx.lineTo(k*hr*.42*(1-i*.15),y-hr*.16); ctx.fill(); } }
		if(d.ridges){ ctx.fillStyle=css(shade(fur,-.3)); for(let i=0;i<7;i++) for(const k of [-1,1]){ ell(ctx,k*W*.35,-L*.6+i*L*.2,R*.1,R*.08); ctx.fill(); } } }
	else { ell(ctx,0,hy-hr*1.05,hr*.24,hr*.2); ctx.fillStyle=css(d.nose?C(d.nose):skin); ctx.fill(); }
	if(mouth>.2){ ell(ctx,0,hy-hr*(lizard?1.2:.9),hr*.42*mouth,hr*.22*mouth); ctx.fillStyle='rgba(60,10,25,.85)'; ctx.fill(); }
	for(const k of [-1,1]) eye(meta,ctx,k*hr*(lizard?.5:.42),hy-hr*.42,hr*.17,d.eyeCol||'#140e12');
	if(d.whiskers){ ctx.strokeStyle='rgba(230,225,215,.5)'; ctx.lineWidth=R*.03; for(const k of [-1,1]) for(const j of [0,1]){ ctx.beginPath(); ctx.moveTo(k*hr*.2,hy-hr*.95); ctx.lineTo(k*hr*1.2,hy-hr*(1.1-j*.35)); ctx.stroke(); } }
	ctx.restore();
}

/* ---------- shell rig (shellback: a goon living under a car roof) ---------- */
function drawShell(ctx,d,anim,t,meta){
	const R=d.R, skin=C(d.skin||GOON_SKIN); let k=0,s=0,head=0,rot=0,ph=0;
	if(anim==='walk'){ s=Math.sin(TAU*t); ph=t; }
	else if(anim==='windup'){ head=-.25*ease(t/.75); }
	else if(anim==='attack'){ head=.55*Math.sin(Math.PI*Math.min(1,t*1.3)); }
	else if(anim==='special'){ k=ease(Math.min(1,t*1.6)); }
	else if(anim==='stun'){ rot=Math.sin(TAU*t)*.25; k=.2; }
	else if(anim==='idle'){ ph=t*.5; }
	ctx.save(); ctx.rotate(rot);
	const st=R*.32, out=1-k;
	const limbs=[[-1,-.62,-1],[1,-.62,1],[-1,.7,1],[1,.7,-1]];
	for(const [sx,sy,p2] of limbs){ const x=sx*R*(.6+.5*out), y=R*sy*(.85+.25*out)+p2*st*s*out; vol(ctx,x,y,R*.22,R*.26,skin,{hi:.2}); }
	if(out>.15){ const hy=-R*(1.0+.38*out+head*.6); vol(ctx,0,hy,R*.36,R*.38,skin,{hi:.22}); if(d.rag!==false) { ell(ctx,0,hy+R*.32,R*.3,R*.1); ctx.fillStyle=css(C(GOON_ORANGE)); ctx.fill(); }
		for(const q of [-1,1]) eye(meta,ctx,q*R*.15,hy-R*.18,R*.08); }
	if(d.bands){ vol(ctx,0,0,R*1.0,R*1.18,d.shellCol,{hi:.2}); ctx.strokeStyle='rgba(40,30,20,.45)'; ctx.lineWidth=R*.07; for(let i=-3;i<=3;i++){ ctx.beginPath(); ctx.ellipse(0,i*R*.3,R*.98*Math.sqrt(1-Math.pow(i/3.8,2)),R*.16,0,Math.PI,TAU); ctx.stroke(); } }
	else { const sc=C(d.shellCol||'#4f7d7a'); ctx.beginPath(); rr(ctx,-R,-R*1.12,R*2,R*2.26,R*.52); const g=ctx.createRadialGradient(0,-R*.1,R*.1,0,0,R*1.45);
		g.addColorStop(0,css(shade(sc,.25))); g.addColorStop(.6,css(sc)); g.addColorStop(1,css(shade(sc,-.45))); ctx.fillStyle=g; ctx.fill();
		ctx.beginPath(); rr(ctx,-R*.84,-R*.96,R*1.68,R*1.94,R*.4); ctx.lineWidth=R*.06; ctx.strokeStyle='rgba(20,20,20,.35)'; ctx.stroke();
		ctx.beginPath(); rr(ctx,-R*.42,-R*.62,R*.84,R*.6,R*.08); ctx.fillStyle='#1c2226'; ctx.fill(); ctx.fillStyle='rgba(160,190,200,.25)'; ctx.fillRect(-R*.36,-R*.58,R*.3,R*.14);
		ctx.strokeStyle='rgba(30,30,30,.35)'; ctx.lineWidth=R*.05; for(const yy of [R*.25,R*.55]){ ctx.beginPath(); ctx.moveTo(-R*.8,yy); ctx.lineTo(R*.8,yy); ctx.stroke(); }
		rust(ctx,R*.55,R*.6,R*.7,23); rust(ctx,-R*.6,-R*.5,R*.5,29); }
	ctx.restore();
}

/* ---------- blob rig (splitter, toad) ---------- */
function drawBlob(ctx,d,anim,t,meta){
	const R=d.R, col=C(d.body); let sx=1,sy=1,ph=0,sac=0,mouth=0,rot=0;
	if(anim==='walk'){ ph=t; sx=1+.07*Math.sin(TAU*t*2); sy=1-.07*Math.sin(TAU*t*2); }
	else if(anim==='idle'){ ph=t; sx=1+.03*Math.sin(TAU*t); }
	else if(anim==='windup'){ const e=ease(t/.75); sx=1+.12*e; sy=1-.1*e; sac=e; mouth=e*.3; }
	else if(anim==='attack'){ const k=Math.sin(Math.PI*Math.min(1,t*1.3)); sy=1+.2*k; sx=1-.1*k; mouth=k; }
	else if(anim==='stun'){ rot=Math.sin(TAU*t)*.3; ph=t; }
	else if(anim==='splat'){ sx=1.25; sy=1.2; }
	else if(anim==='special'){ ph=t; sx=1+.15*Math.sin(TAU*t*3); sy=1-.12*Math.sin(TAU*t*3); }
	ctx.save(); ctx.rotate(rot); ctx.scale(sx,sy);
	for(const k of [-1,1]){ const w=Math.sin(TAU*ph+k)*R*.2; vol(ctx,k*R*1.02,-R*.1+w,R*.24,R*.22,d.toad?shade(col,-.1):C(GOON_SKIN),{hi:.2}); }
	const N=30, pts=[]; for(let i=0;i<N;i++){ const a=i/N*TAU, r=R*(1+.07*Math.sin(3*a+TAU*ph)+(hash2(i,d.seed||2,1)-.5)*.1); pts.push([Math.cos(a)*r,Math.sin(a)*r*1.05]); }
	polyVol(ctx,pts,0,0,R,col,{hi:.24});
	const Rr=rng(d.seed||2); for(let i=0;i<7;i++){ const a=Rr()*TAU, q=Math.sqrt(Rr())*R*.7; ell(ctx,Math.cos(a)*q,Math.sin(a)*q,R*(.1+Rr()*.12),R*(.08+Rr()*.1)); ctx.fillStyle=d.toad?'rgba(70,90,40,.5)':'rgba(154,138,168,.55)'; ctx.fill(); }
	if(sac>0){ vol(ctx,0,-R*.82,R*.45*sac+R*.05,R*.32*sac+R*.05,'#d8c9a2',{hi:.3}); }
	if(mouth>.15){ ctx.beginPath(); ctx.ellipse(0,-R*.82,R*.55,R*.2*mouth+R*.04,0,0,Math.PI); ctx.fillStyle='rgba(40,10,20,.85)'; ctx.fill(); }
	else { ctx.beginPath(); ctx.ellipse(0,-R*.8,R*.5,R*.12,0,.15,Math.PI-.15); ctx.lineWidth=R*.06; ctx.strokeStyle='rgba(30,15,20,.7)'; ctx.stroke(); }
	if(d.toad){ for(const k of [-1,1]){ vol(ctx,k*R*.48,-R*.55,R*.3,R*.3,shade(col,.05),{hi:.3}); eye(meta,ctx,k*R*.5,-R*.6,R*.16,'#c9a227'); } }
	else { eye(meta,ctx,-R*.36,-R*.5,R*.16,'#16121a'); eye(meta,ctx,R*.36,-R*.5,R*.16,'#16121a'); eye(meta,ctx,0,-R*.62,R*.13,'#16121a');
		ell(ctx,0,R*.62,R*.3,R*.1); ctx.fillStyle=css(C(GOON_ORANGE)); ctx.fill(); }
	ctx.restore();
}

/* ---------- boulder rig ---------- */
function drawBoulder(ctx,d,anim,t,meta){
	const R=d.R, rock=C(d.rock||'#8a8178'); let ball=0,s=0,roll=0,rot=0,armA=0,ph=0;
	if(anim==='walk'){ s=Math.sin(TAU*t); rot=.08*s; ph=t; }
	else if(anim==='idle'){ ph=t*.5; }
	else if(anim==='windup'){ ball=ease(t/.75); }
	else if(anim==='special'){ ball=1; roll=t; }
	else if(anim==='attack'){ armA=Math.sin(Math.PI*t); }
	else if(anim==='stun'){ rot=Math.sin(TAU*t)*.3; }
	else if(anim==='splat'){ ball=0; }
	ctx.save(); ctx.rotate(rot);
	const Rr=rng(d.seed||8), N=11, base=[]; for(let i=0;i<N;i++) base.push(.86+Rr()*.26);
	if(ball<1){ const o=1-ball; for(const k of [-1,1]){ const fy=k*R*.0+(k>0?-1:1)*s*R*.3*o - (k>0?armA*R*.6:0); facetRock(ctx,k*R*(1.05+.1*o)*o+k*R*.4,fy-R*.15,R*.42*(.6+.4*o),rock,(d.seed||8)+k*7); }
		for(const k of [-1,1]) vol(ctx,k*R*.45*o,R*(.75*o)+k*s*R*.25,R*.2,R*.24,'#4b453f'); }
	const r=R*(1-.12*ball); facetRock(ctx,0,0,r,rock,d.seed||8,base);
	if(roll>0){ ctx.save(); ell(ctx,0,0,r*.95,r*.95); ctx.clip(); ctx.strokeStyle='rgba(30,25,20,.55)'; ctx.lineWidth=R*.08; for(let i=0;i<4;i++){ const y=((i/4+roll)%1)*r*2.4-r*1.2; ctx.beginPath(); ctx.moveTo(-r,y); ctx.quadraticCurveTo(0,y-r*.25,r,y+r*.1); ctx.stroke(); } ctx.restore(); }
	if(ball<.7){ const o=1-ball/.7; ctx.globalAlpha=o; vol(ctx,0,-R*.62,R*.34,R*.3,GOON_SKIN,{hi:.2}); for(const k of [-1,1]) eye(meta,ctx,k*R*.14,-R*.78,R*.08,'#ff8a2a'); ctx.globalAlpha=1; }
	ell(ctx,R*.1,R*.45,R*.25,R*.12); ctx.fillStyle=css(C(GOON_ORANGE),.9*(1-ball)); ctx.fill();
	ctx.restore();
}
function facetRock(ctx,x,y,r,col,seed,base){ const Rr=rng(seed), N=base?base.length:9, pts=[]; for(let i=0;i<N;i++){ const a=i/N*TAU+Rr()*.2, k=base?base[i]:(.85+Rr()*.3); pts.push([x+Math.cos(a)*r*k,y+Math.sin(a)*r*k]); }
	polyVol(ctx,pts,x,y,r,col,{hi:.2,lo:-.5}); for(let i=0;i<N;i++){ const a=pts[i], b=pts[(i+1)%N]; ctx.beginPath(); ctx.moveTo(x+(a[0]-x)*.35,y+(a[1]-y)*.35); ctx.lineTo(a[0],a[1]); ctx.lineTo(b[0],b[1]); ctx.closePath();
		ctx.fillStyle=Rr()>.5?'rgba(255,255,255,.07)':'rgba(0,0,0,.12)'; ctx.fill(); }
	ctx.fillStyle='rgba(110,130,80,.35)'; for(let i=0;i<3;i++){ ell(ctx,x+(Rr()-.5)*r,y+(Rr()-.5)*r,r*.18,r*.12); ctx.fill(); } }

/* ---------- doomcart: a goon pushing a shopping cart of fuel ---------- */
function drawCart(ctx,d,anim,t,meta){
	const R=d.R, lit=anim==='special', cy=-R*2.05;
	ctx.save(); ctx.translate(0,R*1.0);
	const bob=anim==='walk'?Math.sin(TAU*t*2)*R*.03:0;
	ctx.save(); ctx.translate(0,cy+bob);
	for(const [x,y] of [[-.85,-1.05],[.85,-1.05],[-.8,.95],[.8,.95]]){ vol(ctx,x*R,y*R,R*.14,R*.18,'#1e1d1f'); }
	ctx.beginPath(); rr(ctx,-R*.98,-R*1.15,R*1.96,R*2.15,R*.12); ctx.fillStyle='rgba(30,30,32,.55)'; ctx.fill(); ctx.lineWidth=R*.08; ctx.strokeStyle='#a9abae'; ctx.stroke();
	ctx.save(); ctx.beginPath(); rr(ctx,-R*.98,-R*1.15,R*1.96,R*2.15,R*.12); ctx.clip(); ctx.strokeStyle='rgba(190,192,195,.55)'; ctx.lineWidth=R*.03; for(let i=-6;i<=6;i++){ ctx.beginPath(); ctx.moveTo(i*R*.16,-R*1.2); ctx.lineTo(i*R*.16,R*1.1); ctx.stroke(); } for(let i=-7;i<=7;i++){ ctx.beginPath(); ctx.moveTo(-R,i*R*.16); ctx.lineTo(R,i*R*.16); ctx.stroke(); } ctx.restore();
	for(const [x,y,c] of [[-.52,.42,'#9e3226'],[.5,.5,'#a8862a']]){ ctx.beginPath(); rr(ctx,x*R-R*.28,y*R-R*.36,R*.56,R*.72,R*.08); ctx.fillStyle=c; ctx.fill(); ctx.fillStyle='#262626'; ctx.fillRect(x*R+R*.08,y*R-R*.34,R*.12,R*.12); }
	vol(ctx,0,-R*.4,R*.62,R*.62,'#b23a26',{hi:.25}); ctx.lineWidth=R*.12; ctx.setLineDash([R*.18,R*.18]); ell(ctx,0,-R*.4,R*.5,R*.5); ctx.strokeStyle='#e8c44a'; ctx.stroke(); ctx.setLineDash([]);
	ell(ctx,0,-R*.4,R*.22,R*.22); ctx.fillStyle='#4a2a20'; ctx.fill();
	ctx.beginPath(); ctx.moveTo(0,-R*.4); ctx.quadraticCurveTo(R*.5,-R*.9,R*.35,-R*1.25); ctx.lineWidth=R*.05; ctx.strokeStyle='#3a2a1a'; ctx.stroke();
	const blink=lit?(Math.floor(t*8)%2===0):false;
	const g=ctx.createRadialGradient(R*.35,-R*1.25,0,R*.35,-R*1.25,R*(lit?.6:.25)); g.addColorStop(0,'rgba(255,250,210,1)'); g.addColorStop(.4,lit?'rgba(255,150,40,.9)':'rgba(120,60,30,.6)'); g.addColorStop(1,'rgba(255,80,20,0)'); ctx.fillStyle=g; ell(ctx,R*.35,-R*1.25,R*.6,R*.6); ctx.fill();
	ell(ctx,-R*.62,-R*.85,R*.12,R*.12); ctx.fillStyle=blink?'#ff3b2a':'#5a1a14'; ctx.fill();
	if(meta){ const p=ctx.getTransform().transformPoint(new DOMPoint(-R*.62,-R*.85)); meta.lamp=[p.x,p.y]; }
	ctx.restore();
	ctx.beginPath(); ctx.moveTo(-R*.9,cy+R*1.02+bob); ctx.lineTo(R*.9,cy+R*1.02+bob); ctx.lineWidth=R*.1; ctx.strokeStyle='#c7c9cc'; ctx.stroke();
	drawBiped(ctx,d,anim==='special'?'walk':anim,t,meta);
	ctx.restore();
}

/* ---------- beast rig: wild mammals (boar, raccoon, coyote, porcupine, moose, bison, jackalope) ---------- */
function drawBeast(ctx,d,anim,t,meta){
	const R=d.R, L=R*(d.len||1.25), W=R*(d.wid||.66), fur=C(d.fur), dark=d.dark?C(d.dark):shade(fur,-.3);
	let s=0,sy=1,headF=0,mouth=0,rot=0,ph=0,hop=0,curl=0,gait=1;
	if(anim==='walk'){ s=Math.sin(TAU*t); rot=.05*s; ph=t; if(d.hop) hop=Math.max(0,Math.sin(TAU*t)); }
	else if(anim==='idle'){ ph=t*.5; sy=1+.02*Math.sin(TAU*t); }
	else if(anim==='windup'){ const e=ease(t/.75); sy=1-.1*e; headF=-R*.22*e; mouth=e*.3; curl=d.quills?e:0; if(t>.75) rot=Math.sin(t*90)*.04; }
	else if(anim==='attack'){ const k=Math.sin(Math.PI*Math.min(1,t*1.3)); sy=1+.14*k; headF=R*.45*k; mouth=k; curl=d.quills?1:0; }
	else if(anim==='stun'){ rot=Math.sin(TAU*t)*.35; ph=t; }
	else if(anim==='special'){ if(d.hop){ hop=Math.sin(Math.PI*t); } else if(d.quills){ curl=1; sy=.94; } else { s=Math.sin(TAU*t*2); ph=t*2; gait=1.4; headF=-R*.1; mouth=d.mask?.6:0; } }
	else if(anim==='splat'){ sy=1.1; }
	const st=R*.45*(d.stride||1)*gait, sc=1+hop*.25;
	ctx.save(); ctx.rotate(rot); ctx.scale(sc,sy*sc);
	/* tail */
	const tw=Math.sin(TAU*ph+1)*R*.35;
	if(d.tail==='bushy'||d.tail==='ring'){ const tl=R*(d.tailLen||1.3); ctx.save(); ctx.translate(0,L*.85); ctx.rotate(tw/R*.4);
		vol(ctx,0,tl*.55,R*.3,tl*.6,d.tail==='ring'?fur:shade(fur,.05),{hi:.2});
		if(d.tail==='ring'){ ctx.save(); ell(ctx,0,tl*.55,R*.3,tl*.6); ctx.clip(); ctx.fillStyle=css(dark); for(let k=0;k<4;k++) ctx.fillRect(-R,tl*(.2+k*.22),R*2,tl*.1); ctx.restore(); }
		else { ell(ctx,0,tl*1.0,R*.18,R*.2); ctx.fillStyle=css(shade(fur,.35)); ctx.fill(); } ctx.restore(); }
	else if(d.tail==='stub'){ ctx.beginPath(); ctx.arc(0,L*.95,R*.14,0,Math.PI*1.6); ctx.lineWidth=R*.07; ctx.strokeStyle=css(dark); ctx.stroke(); }
	else if(d.tail==='puff'){ vol(ctx,0,L*.95,R*.24,R*.22,'#efe9dc',{hi:.15}); }
	else if(d.tail==='tuft'){ limb(ctx,[0,L*.8],[tw*.3,L*1.25],R*.08,dark); vol(ctx,tw*.3,L*1.28,R*.1,R*.14,dark); }
	/* legs */
	const legs=d.hop?[[-1,-1,0],[1,-1,0],[-1,1,0],[1,1,0]]:[[-1,-1,-1],[1,-1,1],[-1,1,1],[1,1,-1]];
	for(const [sx,sy2,p2] of legs){ const fx=sx*W*(sy2>0&&d.hop?1.15:1.0), fy=sy2*L*(d.hop&&sy2>0?.62:.52)+(d.hop?-hop*sy2*R*.3:p2*st*s);
		vol(ctx,fx,fy,R*(d.hoof?.17:.2),R*(d.hoof?.22:.26),d.hoof?'#2a221c':shade(fur,-.25),{hi:.12}); }
	/* body */
	if(d.furry) furBlob(ctx,0,0,W,L,fur,d.seed||5,ph); else vol(ctx,0,0,W,L,fur,{hi:.2});
	if(d.hump){ furBlob(ctx,0,-L*.32,W*1.12,L*.55,d.mane||shade(fur,.12),(d.seed||5)+3,ph); }
	if(d.bristle){ ctx.strokeStyle=css(dark); ctx.lineWidth=R*.06; for(let i=0;i<9;i++){ const y=-L*.7+i*L*.17; ctx.beginPath(); ctx.moveTo(-R*.12,y); ctx.lineTo(0,y-R*.18); ctx.lineTo(R*.12,y); ctx.stroke(); } }
	if(d.quills){ const Rq=rng(d.seed||9), n=44, len=R*(.55+.45*curl); for(let i=0;i<n;i++){ const a=Rq()*TAU, q=Math.sqrt(Rq())*.85, x=Math.cos(a)*W*q, y=Math.sin(a)*L*q;
			const ang=Math.atan2(y*.6,x)+(Rq()-.5)*.5, l=len*(.6+Rq()*.5); ctx.beginPath(); ctx.moveTo(x,y); ctx.lineTo(x+Math.cos(ang)*l,y+Math.sin(ang)*l+(curl?0:l*.6)); ctx.lineWidth=R*.05; ctx.strokeStyle='#2c241e'; ctx.stroke();
			ctx.beginPath(); ctx.moveTo(x+Math.cos(ang)*l*.7,y+Math.sin(ang)*l*.7+(curl?0:l*.42)); ctx.lineTo(x+Math.cos(ang)*l,y+Math.sin(ang)*l+(curl?0:l*.6)); ctx.strokeStyle='#e8e0cc'; ctx.stroke(); } }
	if(d.stripe){ ell(ctx,0,0,W*.25,L*.8); ctx.fillStyle=css(dark,.5); ctx.fill(); }
	/* head */
	const hy=-L*.98-headF, hr=R*(d.headR||.44), sn=d.snout||1;
	if(d.antlers==='palm') for(const k of [-1,1]){ ctx.save(); ctx.translate(k*hr*.6,hy+hr*.2); ctx.scale(k,1); ctx.beginPath(); ctx.moveTo(0,0); ctx.quadraticCurveTo(hr*1.2,-hr*.6,hr*2.6,-hr*.5);
		for(let i=0;i<5;i++) ctx.lineTo(hr*(2.6-i*.35),-hr*(.5+(i%2?.25:.55))); ctx.quadraticCurveTo(hr*1.4,hr*.6,0,hr*.3); ctx.closePath(); ctx.fillStyle='#cbb894'; ctx.fill(); ctx.lineWidth=R*.04; ctx.strokeStyle='rgba(60,45,30,.6)'; ctx.stroke(); ctx.restore(); }
	if(d.antlers==='small') for(const k of [-1,1]){ ctx.strokeStyle='#cbb894'; ctx.lineWidth=R*.07; ctx.lineCap='round'; ctx.beginPath(); ctx.moveTo(k*hr*.35,hy); ctx.lineTo(k*hr*1.3,hy-hr*.9); ctx.moveTo(k*hr*.9,hy-hr*.5); ctx.lineTo(k*hr*.7,hy-hr*1.2); ctx.stroke(); }
	if(d.horns) for(const k of [-1,1]){ ctx.beginPath(); ctx.moveTo(k*hr*.55,hy-hr*.1); ctx.quadraticCurveTo(k*hr*1.5,hy-hr*.1,k*hr*1.35,hy-hr*.85); ctx.lineWidth=R*.12; ctx.lineCap='round'; ctx.strokeStyle='#d8cdb4'; ctx.stroke(); }
	if(d.ears==='long') for(const k of [-1,1]){ ctx.save(); ctx.translate(k*hr*.4,hy+hr*.3); ctx.rotate(k*.35); vol(ctx,0,hr*1.1,hr*.34,hr*1.2,fur,{hi:.18}); ell(ctx,0,hr*1.1,hr*.16,hr*.9); ctx.fillStyle='rgba(205,150,140,.55)'; ctx.fill(); ctx.restore(); }
	if(d.ears==='pointy') for(const k of [-1,1]){ ctx.beginPath(); ctx.moveTo(k*hr*.25,hy+hr*.1); ctx.lineTo(k*hr*1.05,hy+hr*.05); ctx.lineTo(k*hr*.75,hy+hr*.75); ctx.closePath(); ctx.fillStyle=css(shade(fur,-.1)); ctx.fill(); }
	if(d.ears==='round') for(const k of [-1,1]){ vol(ctx,k*hr*.82,hy+hr*.15,hr*.32,hr*.3,dark,{hi:.15}); }
	vol(ctx,0,hy,hr,hr*1.1,fur,{hi:.22});
	vol(ctx,0,hy-hr*(.8*sn),hr*.52,hr*.62*sn,d.muzzle?C(d.muzzle):shade(fur,.08),{hi:.18});
	if(d.mask){ ctx.save(); ell(ctx,0,hy,hr,hr*1.1); ctx.clip(); ctx.fillStyle='#1d1b1a'; ctx.fillRect(-hr,hy-hr*.55,hr*2,hr*.42); ctx.restore(); }
	ell(ctx,0,hy-hr*(.8*sn)-hr*.5*sn,hr*.2,hr*.15); ctx.fillStyle='#1c1614'; ctx.fill();
	if(d.tusks) for(const k of [-1,1]){ ctx.beginPath(); ctx.moveTo(k*hr*.35,hy-hr*.9*sn); ctx.quadraticCurveTo(k*hr*.85,hy-hr*1.25*sn,k*hr*.6,hy-hr*1.55*sn); ctx.lineWidth=R*.08; ctx.lineCap='round'; ctx.strokeStyle='#efe6cf'; ctx.stroke(); }
	if(mouth>.25){ ell(ctx,0,hy-hr*(.8*sn)-hr*.15,hr*.32*mouth,hr*.2*mouth); ctx.fillStyle='rgba(60,10,25,.85)'; ctx.fill(); }
	for(const k of [-1,1]) eye(meta,ctx,k*hr*.45,hy-hr*.35,hr*.15,d.eyeCol||'#d2a23a');
	ctx.restore();
}

/* ---------- scorpion rig ---------- */
function drawScorp(ctx,d,anim,t,meta){
	const R=d.R, col=C(d.col), L=R*1.3, W=R*.62; let s=0,curl=2.5,lift=0,reach=0,pinch=.35,rot=0;
	if(anim==='walk'){ s=Math.sin(TAU*t); }
	else if(anim==='idle'){ pinch=.3+.1*Math.sin(TAU*t); }
	else if(anim==='windup'){ const e=ease(t/.75); curl=lerp(2.5,3.05,e); lift=e; pinch=.6*e; }
	else if(anim==='attack'){ const k=Math.sin(Math.PI*Math.min(1,t*1.4)); curl=lerp(3.05,3.5,k); reach=k; lift=1-k*.4; pinch=.7; }
	else if(anim==='stun'){ rot=Math.sin(TAU*t)*.35; curl=1.6; }
	else if(anim==='special'){ pinch=Math.abs(Math.sin(TAU*t*2))*.8; }
	else if(anim==='splat'){ curl=1.2; }
	ctx.save(); ctx.rotate(rot);
	for(const sx of [-1,1]) for(let i=0;i<4;i++){ const by=L*(-.32+i*.24), g=(i%2?1:-1)*sx*s*R*.25, knee=[sx*W*1.35,by-R*.1+g*.5], foot=[sx*W*1.9,by+R*.15+g];
		limb(ctx,[sx*W*.5,by],knee,R*.11,shade(col,-.15)); limb(ctx,knee,foot,R*.08,shade(col,-.25)); }
	for(let i=0;i<4;i++) vol(ctx,0,L*(.12+i*.17),W*(.92-i*.12),L*.14,shade(col,-.04*i),{hi:.2});
	vol(ctx,0,-L*.28,W,L*.36,col,{hi:.24});
	for(const sx of [-1,1]){ const b=[sx*W*.6,-L*.55], el=[sx*W*1.15,-L*.8], c=[sx*W*.9,-L*1.15]; limb(ctx,b,el,R*.14,col); limb(ctx,el,c,R*.13,col);
		ctx.save(); ctx.translate(c[0],c[1]); ctx.rotate(sx*.25); vol(ctx,0,0,R*.28,R*.24,shade(col,.05),{hi:.25});
		for(const j of [-1,1]){ ctx.save(); ctx.rotate(j*pinch*.6); vol(ctx,j*R*.08,-R*.38,R*.1,R*.24,shade(col,-.1)); ctx.restore(); } ctx.restore(); }
	for(const sx of [-1,1]) eye(meta,ctx,sx*R*.12,-L*.52,R*.06,'#120c08');
	/* tail: five segments from the abdomen tip curling forward over the back */
	let x=0,y=L*.68,a=Math.PI/2; const segs=5, sl=R*.42*(1+reach*.35);
	for(let i=0;i<segs;i++){ a-=curl/segs; const nx=x+Math.cos(a)*sl, ny=y+Math.sin(a)*sl, up=Math.sin(Math.PI*(i+1)/(segs+1))*(.25+lift*.25);
		vol(ctx,(x+nx)/2,(y+ny)/2,R*.2*(1+up),R*.24*(1+up),shade(col,.04*i),{hi:.28}); x=nx; y=ny; }
	ctx.save(); ctx.translate(x,y); ctx.rotate(a); vol(ctx,R*.12,0,R*.2*(1+lift*.3),R*.15*(1+lift*.3),'#4a2a1a'); ctx.beginPath(); ctx.moveTo(R*.25,-R*.06); ctx.quadraticCurveTo(R*.5,0,R*.32,R*.14); ctx.lineWidth=R*.06; ctx.strokeStyle='#1b100a'; ctx.stroke();
	if(lift>.3){ const g=ctx.createRadialGradient(R*.4,0,0,R*.4,0,R*.3); g.addColorStop(0,'rgba(190,255,120,.8)'); g.addColorStop(1,'rgba(120,255,60,0)'); ctx.fillStyle=g; ell(ctx,R*.4,0,R*.3,R*.3); ctx.fill(); }
	ctx.restore(); ctx.restore();
}

/* ---------- bird rig (flies; the game draws its ground shadow separately) ---------- */
function drawBird(ctx,d,anim,t,meta){
	const R=d.R, col=C(d.col); let span=1,sweep=0,folded=0,head=0,rot=0,peck=0;
	if(anim==='walk'){ span=.82+.18*Math.cos(TAU*t); sweep=.15*Math.sin(TAU*t); }
	else if(anim==='windup'){ const e=ease(t/.75); sweep=.35*e; span=1-.15*e; }
	else if(anim==='attack'){ sweep=.8; span=.7; head=R*.25; }
	else if(anim==='stun'){ rot=TAU*t; span=.9; sweep=.2*Math.sin(TAU*t*3); }
	else if(anim==='idle'){ folded=1; }
	else if(anim==='special'){ folded=1; peck=Math.max(0,Math.sin(TAU*t*2)); }
	else if(anim==='splat'){ span=1.05; sweep=-.1; }
	ctx.save(); ctx.rotate(rot);
	/* tail fan */
	ctx.save(); ctx.translate(0,R*.75); for(let i=-2;i<=2;i++){ ctx.save(); ctx.rotate(i*.18); vol(ctx,0,R*.4,R*.14,R*.45,shade(col,-.1+i*.02),{hi:.15}); ctx.restore(); } ctx.restore();
	if(folded<1) for(const k of [-1,1]){ ctx.save(); ctx.translate(k*R*.3,-R*.15); ctx.scale(k,1); ctx.rotate(sweep); const S=R*2.6*span;
		ctx.beginPath(); ctx.moveTo(0,-R*.25); ctx.quadraticCurveTo(S*.5,-R*.55,S,-R*.2);
		for(let i=0;i<5;i++){ const fx=S-i*S*.11, fy=-R*.2+i*R*.16; ctx.lineTo(fx+S*.04,fy+R*.3); ctx.lineTo(fx-S*.05,fy+R*.18); }
		ctx.quadraticCurveTo(S*.3,R*.55,0,R*.35); ctx.closePath(); const g=ctx.createLinearGradient(0,0,S,0); g.addColorStop(0,css(shade(col,.12))); g.addColorStop(.6,css(col)); g.addColorStop(1,css(shade(col,-.35))); ctx.fillStyle=g; ctx.fill();
		ctx.strokeStyle='rgba(0,0,0,.25)'; ctx.lineWidth=R*.04; for(let i=1;i<5;i++){ ctx.beginPath(); ctx.moveTo(S*.25,R*.05); ctx.lineTo(S-i*S*.11,-R*.2+i*R*.16+R*.25); ctx.stroke(); } ctx.restore(); }
	else for(const k of [-1,1]) vol(ctx,k*R*.42,R*.15,R*.32,R*.75,shade(col,-.08),{hi:.15});
	vol(ctx,0,0,R*.45,R*.7,col,{hi:.2});
	const hy=-R*.75-head+peck*R*.25; ell(ctx,0,hy+R*.2,R*.3,R*.15); ctx.fillStyle='rgba(225,215,200,.8)'; ctx.fill();
	vol(ctx,0,hy,R*.25,R*.28,d.headCol||'#b05a4a',{hi:.25});
	ctx.beginPath(); ctx.moveTo(-R*.1,hy-R*.2); ctx.quadraticCurveTo(0,hy-R*.6,R*.06,hy-R*.45); ctx.lineTo(R*.1,hy-R*.2); ctx.closePath(); ctx.fillStyle=d.beak||'#d8c27a'; ctx.fill();
	for(const k of [-1,1]) eye(meta,ctx,k*R*.15,hy-R*.08,R*.06,'#1a1210');
	ctx.restore();
}

/* ---------- snake rig ---------- */
function drawSnake(ctx,d,anim,t,meta){
	const R=d.R, col=C(d.col), pat=C(d.pat||'#5d4a2e'); let A=R*.75,k=1.15,len=R*5.2,ph=t,head=1,strike=0,rattle=0,rot=0;
	if(anim==='idle'){ A=R*.5; ph=t*.3; }
	else if(anim==='windup'){ const e=ease(t/.75); A=lerp(R*.75,R*1.35,e); k=lerp(1.15,1.8,e); len=lerp(R*5.2,R*3.6,e); head=1+.15*e; rattle=e; ph=.2; }
	else if(anim==='attack'){ strike=Math.sin(Math.PI*Math.min(1,t*1.4)); A=R*1.2*(1-strike*.7); len=R*(3.6+3.0*strike); k=1.6; ph=.2; }
	else if(anim==='stun'){ rot=Math.sin(TAU*t)*.4; A=R*.9; ph=t*.4; }
	else if(anim==='special'){ rattle=1; A=R*1.1; k=1.7; len=R*3.8; ph=.25; }
	else if(anim==='splat'){ A=R*.4; ph=0; }
	ctx.save(); ctx.rotate(rot);
	const N=26, pts=[]; for(let i=0;i<=N;i++){ const u=i/N, env=Math.min(1,u*3)*(strike>0?Math.min(1,(u)*1.6):1), y=-len*.45+u*len, x=A*Math.sin(k*u*TAU-TAU*ph)*env; pts.push([x,y,u]); }
	for(let i=N;i>=0;i--){ const [x,y,u]=pts[i], r=R*.5*(u<.12?.8+u*1.7:1-.55*Math.pow(u,1.4)); vol(ctx,x,y,r,r,i%4===1?pat:col,{hi:.25,lo:-.35}); }
	const tail=pts[N]; for(let j=0;j<4;j++){ const jx=tail[0]+(rattle?Math.sin(t*80+j)*R*.12:0); vol(ctx,jx,tail[1]+R*.18*(j+1),R*.16-j*R*.02,R*.12,'#d8c9a6',{hi:.3}); }
	const h=pts[0]; ctx.save(); ctx.translate(h[0],h[1]-R*.15); ctx.scale(head,head);
	ctx.beginPath(); ctx.moveTo(0,-R*.75); ctx.quadraticCurveTo(R*.62,-R*.45,R*.45,R*.2); ctx.quadraticCurveTo(0,R*.45,-R*.45,R*.2); ctx.quadraticCurveTo(-R*.62,-R*.45,0,-R*.75); ctx.closePath();
	const g=ctx.createRadialGradient(0,-R*.2,R*.05,0,0,R*.8); g.addColorStop(0,css(shade(col,.2))); g.addColorStop(1,css(shade(col,-.35))); ctx.fillStyle=g; ctx.fill();
	for(const q of [-1,1]) eye(meta,ctx,q*R*.25,-R*.25,R*.09,'#d6b43a');
	if(anim==='walk'&&t>.5||anim==='windup'){ ctx.beginPath(); ctx.moveTo(0,-R*.75); ctx.lineTo(0,-R*1.05); ctx.lineTo(-R*.1,-R*1.2); ctx.moveTo(0,-R*1.05); ctx.lineTo(R*.1,-R*1.2); ctx.lineWidth=R*.06; ctx.strokeStyle='#b8323a'; ctx.stroke(); }
	ctx.restore(); ctx.restore();
}

/* ---------- vehicle rig: the Scrap Gang (raiders, goon drivers, junk machines) ---------- */
const SCRAP_TEAL='#2aa6a1';
function tire(ctx,x,y,w,h,t,spin,spikes){ ctx.save(); ctx.beginPath(); rr(ctx,x-w/2,y-h/2,w,h,Math.min(w,h)*.32); ctx.fillStyle='#1b1a1c'; ctx.fill(); ctx.clip();
	ctx.strokeStyle='rgba(120,118,115,.5)'; ctx.lineWidth=Math.max(.6,h*.07); const step=h/4, off=((t*spin)%1)*step; for(let y2=y-h/2-step+off;y2<y+h/2+step;y2+=step){ ctx.beginPath(); ctx.moveTo(x-w/2,y2); ctx.lineTo(x+w/2,y2+step*.35); ctx.stroke(); } ctx.restore();
	if(spikes){ ctx.fillStyle='#d3d5d7'; for(const s of [-1,1]) for(const k of [-.28,0,.28]){ const kk=k+((t*spin)%1)*.0; ctx.beginPath(); ctx.moveTo(x+s*w/2,y+kk*h-h*.08); ctx.lineTo(x+s*(w/2+w*.6),y+kk*h); ctx.lineTo(x+s*w/2,y+kk*h+h*.08); ctx.fill(); } } }
function boxBody(ctx,x,y,w,h,r,col){ col=C(col); ctx.beginPath(); rr(ctx,x-w/2,y-h/2,w,h,r); const g=ctx.createLinearGradient(x-w/2,0,x+w/2,0);
	g.addColorStop(0,css(shade(col,-.45))); g.addColorStop(.16,css(shade(col,-.08))); g.addColorStop(.5,css(shade(col,.16))); g.addColorStop(.84,css(shade(col,-.08))); g.addColorStop(1,css(shade(col,-.45))); ctx.fillStyle=g; ctx.fill(); }
function chrome(ctx,a,b,w){ ctx.lineCap='round'; ctx.beginPath(); ctx.moveTo(a[0],a[1]); ctx.lineTo(b[0],b[1]); ctx.strokeStyle='#4b4d50'; ctx.lineWidth=w; ctx.stroke(); ctx.beginPath(); ctx.moveTo(a[0],a[1]); ctx.lineTo(b[0],b[1]); ctx.strokeStyle='#c9cbcd'; ctx.lineWidth=w*.45; ctx.stroke(); }
function puffs(ctx,x,y,t,s,dir){ dir=dir||1; for(let k=0;k<3;k++){ const u=(t*2+k/3)%1; ell(ctx,x+Math.sin(k*2.1)*s*.3,y+dir*u*s*2.2,s*(.25+u*.55),s*(.25+u*.55)); ctx.fillStyle='rgba(70,66,62,'+(.4*(1-u))+')'; ctx.fill(); } }
function jetFlame(ctx,x,y,len,w,t){ const f=.85+.25*Math.sin(t*TAU*7); const g=ctx.createLinearGradient(x,y,x,y+len*f); g.addColorStop(0,'rgba(255,250,215,1)'); g.addColorStop(.35,'rgba(255,170,50,.95)'); g.addColorStop(1,'rgba(255,70,20,0)');
	ctx.beginPath(); ctx.moveTo(x-w/2,y); ctx.quadraticCurveTo(x,y+len*f*1.2,x+w/2,y); ctx.closePath(); ctx.fillStyle=g; ctx.fill(); }
function gangStripe(ctx,x,y,w,h,P){ ctx.fillStyle=css(C(P.gang)); ctx.fillRect(x-w/2,y-h/2,w,h); }
function rider(ctx,P,x,y,grips,o){ const rd=Object.assign({kind:'biped',grip:'two'},P.d.rider||{},o||{}); rd.R=rd.R||P.R*.6; rd.twoGrip=()=>grips.map(g=>[g[0]-x,g[1]-y]); rd.vAnim=P.anim; rd.act=P.act;
	ctx.save(); ctx.translate(x,y); drawBiped(ctx,rd,'ride',P.t,P.meta); ctx.restore(); }
const VEH={
	bike(ctx,P,side){ const R=P.R, L=R*2.4, x0=side||0; ctx.save(); ctx.translate(x0,0);
		tire(ctx,0,-L*.37,R*.3,R*.62,P.t,P.spin); tire(ctx,0,L*.36,R*.34,R*.66,P.t,P.spin);
		chrome(ctx,[-R*.12,-L*.33],[-R*.12,-L*.18],R*.07); chrome(ctx,[R*.12,-L*.33],[R*.12,-L*.18],R*.07);
		vol(ctx,0,L*.3,R*.22,R*.42,shade(C(P.paint),-.2)); chrome(ctx,[R*.24,-L*.02],[R*.3,L*.4],R*.1);
		vol(ctx,0,-L*.1,R*.3,R*.44,P.paint,{hi:.3}); gangStripe(ctx,0,-L*.1,R*.1,R*.6,P);
		vol(ctx,0,L*.1,R*.24,R*.34,'#2a2624',{hi:.15}); chrome(ctx,[-R*.62,-L*.22],[R*.62,-L*.22],R*.08);
		vol(ctx,0,-L*.3,R*.12,R*.09,'#f1e7b8',{hi:.4});
		if(P.spin>0) puffs(ctx,R*.3,L*.48,P.t,R*.3); if(P.flame) jetFlame(ctx,R*.3,L*.42,R*1.0*P.flame,R*.2,P.t);
		if(!side) rider(ctx,P,0,L*.02,[[-R*.6,-L*.22],[R*.6,-L*.22]]); ctx.restore(); },
	sidecar(ctx,P){ const R=P.R, L=R*2.4; VEH.bike(ctx,P,-R*.4); rider(ctx,P,-R*.4,L*.02,[[-R*1.0,-L*.22],[R*.2,-L*.22]]);
		tire(ctx,R*1.3,L*.05,R*.26,R*.5,P.t,P.spin); chrome(ctx,[-R*.2,L*.0],[R*1.2,L*.05],R*.08);
		ctx.beginPath(); ctx.ellipse(R*.75,0,R*.5,R*.85,0,0,TAU); const g=ctx.createRadialGradient(R*.75,-R*.1,R*.1,R*.75,0,R*.9); g.addColorStop(0,css(shade(C(P.paint),.25))); g.addColorStop(1,css(shade(C(P.paint),-.4))); ctx.fillStyle=g; ctx.fill();
		gangStripe(ctx,R*.75,-R*.5,R*.5,R*.08,P);
		const thr=P.anim==='attack'?P.act:0, hx=R*(.75+.3*thr), hy=-R*(.3+.6*thr);
		const gd={kind:'biped',R:R*.42,cloth:'#4e4a42',hat:'goggles',tool:'none',grip:'two',twoGrip:()=>[[-R*.3,-R*.15],[hx-R*.75,hy]]};
		ctx.save(); ctx.translate(R*.75,R*.1); drawBiped(ctx,gd,'ride',P.t,P.meta); ctx.restore();
		if(P.anim!=='attack'||P.t<.4){ ctx.save(); ctx.translate(hx,hy); ctx.rotate(.4); ctx.fillStyle='#5c5f63'; ctx.fillRect(-R*.08,-R*.22,R*.16,R*.44); ctx.fillStyle='#d8b23a'; ctx.fillRect(-R*.02,-R*.34,R*.04,R*.12); ctx.restore(); } },
	trike(ctx,P){ const R=P.R, L=R*2.5; tire(ctx,0,-L*.4,R*.3,R*.6,P.t,P.spin); tire(ctx,-R*.85,L*.28,R*.36,R*.66,P.t,P.spin); tire(ctx,R*.85,L*.28,R*.36,R*.66,P.t,P.spin);
		chrome(ctx,[-R*.85,L*.28],[R*.85,L*.28],R*.12); chrome(ctx,[0,-L*.36],[0,L*.2],R*.12);
		for(const k of [-1,1]) vol(ctx,k*R*.36,L*.36,R*.26,R*.42,'#9e3226',{hi:.3}); vol(ctx,0,L*.48,R*.16,R*.16,'#3a3a3c');
		vol(ctx,0,-L*.12,R*.3,R*.4,P.paint,{hi:.3}); gangStripe(ctx,0,-L*.12,R*.1,R*.5,P); chrome(ctx,[-R*.66,-L*.25],[R*.66,-L*.25],R*.08);
		chrome(ctx,[0,L*.45],[0,L*.62],R*.14);
		if(P.anim==='attack'||P.anim==='special'){ const k=P.anim==='special'?1:P.act; jetFlame(ctx,0,L*.62,R*2.6*k,R*1.0*k,P.t); }
		rider(ctx,P,0,L*.0,[[-R*.64,-L*.25],[R*.64,-L*.25]]); },
	quad(ctx,P){ const R=P.R, L=R*2.1; for(const sx of [-1,1]) for(const sy of [-1,1]) tire(ctx,sx*R*.95,sy*L*.32,R*.5,R*.62,P.t,P.spin,true);
		boxBody(ctx,0,0,R*1.3,L*.95,R*.35,P.paint); gangStripe(ctx,0,-L*.3,R*1.1,R*.1,P); chrome(ctx,[-R*.55,-L*.45],[R*.55,-L*.45],R*.08);
		vol(ctx,0,L*.12,R*.3,R*.38,'#2a2624'); if(P.spin>0) puffs(ctx,-R*.4,L*.55,P.t,R*.25);
		rider(ctx,P,0,L*.05,[[-R*.62,-L*.26],[R*.62,-L*.26]]); },
	kart(ctx,P){ const R=P.R, L=R*2.2; for(const sx of [-1,1]){ tire(ctx,sx*R*.85,-L*.34,R*.32,R*.44,P.t,P.spin); tire(ctx,sx*R*.9,L*.32,R*.4,R*.5,P.t,P.spin); }
		ctx.beginPath(); rr(ctx,-R*.7,-L*.45,R*1.4,L*.9,R*.2); ctx.lineWidth=R*.12; ctx.strokeStyle=css(C(P.gang)); ctx.stroke();
		boxBody(ctx,0,L*.36,R*.9,R*.62,R*.1,'#5a5856'); ctx.fillStyle='#2a2a2a'; ctx.fillRect(-R*.3,L*.3,R*.6,R*.1); ell(ctx,R*.3,L*.45,R*.08,R*.08); ctx.fillStyle='#b0302a'; ctx.fill();
		chrome(ctx,[-R*.75,-L*.5],[R*.75,-L*.5],R*.12); if(P.spin>0) puffs(ctx,R*.35,L*.6,P.t,R*.25);
		ctx.beginPath(); ctx.arc(0,-L*.2,R*.26,0,TAU); ctx.lineWidth=R*.07; ctx.strokeStyle='#2b2b2d'; ctx.stroke();
		rider(ctx,P,0,L*.02,[[-R*.24,-L*.22],[R*.24,-L*.22]]); },
	buggy(ctx,P){ const R=P.R, L=R*2.6; for(const sx of [-1,1]){ tire(ctx,sx*R*1.0,-L*.3,R*.42,R*.62,P.t,P.spin); tire(ctx,sx*R*1.05,L*.3,R*.5,R*.72,P.t,P.spin); }
		boxBody(ctx,0,L*.32,R*1.2,R*.8,R*.15,'#5e5a52'); ctx.lineWidth=R*.1; ctx.strokeStyle='#3a3836'; ctx.beginPath(); rr(ctx,-R*.75,-L*.35,R*1.5,L*.62,R*.12); ctx.stroke();
		ctx.beginPath(); ctx.moveTo(-R*.75,-L*.35); ctx.lineTo(R*.75,L*.27); ctx.moveTo(R*.75,-L*.35); ctx.lineTo(-R*.75,L*.27); ctx.stroke(); gangStripe(ctx,0,L*.32,R*1.0,R*.12,P);
		rider(ctx,P,0,L*.02,[[-R*.26,-L*.12],[R*.26,-L*.12]]);
		const fired=P.anim==='attack'&&P.t>.25, ang=P.anim==='windup'?Math.sin(P.t*12)*.08:0; ctx.save(); ctx.translate(0,-L*.32); ctx.rotate(ang); vol(ctx,0,0,R*.22,R*.22,'#3d3f42');
		chrome(ctx,[0,0],[0,-R*.9],R*.16); if(!fired){ ctx.beginPath(); ctx.moveTo(0,-R*1.3); ctx.lineTo(-R*.14,-R*.95); ctx.lineTo(R*.14,-R*.95); ctx.closePath(); ctx.fillStyle='#c9cbcd'; ctx.fill(); }
		else { ctx.beginPath(); ctx.moveTo(0,-R*.9); ctx.lineTo(0,-R*3.5); ctx.setLineDash([R*.12,R*.08]); ctx.lineWidth=R*.05; ctx.strokeStyle='#d8cdb4'; ctx.stroke(); ctx.setLineDash([]); } ctx.restore(); },
	van(ctx,P){ const R=P.R, L=R*2.9; for(const sx of [-1,1]) for(const sy of [-.32,.32]) tire(ctx,sx*R*1.0,sy*L,R*.3,R*.56,P.t,P.spin);
		boxBody(ctx,0,0,R*2.0,L*1.0,R*.4,P.paint); ctx.beginPath(); rr(ctx,-R*.82,-L*.26,R*1.64,L*.7,R*.2); ctx.fillStyle=css(shade(C(P.paint),.14)); ctx.fill();
		ctx.beginPath(); ctx.moveTo(-R*.85,-L*.42); ctx.lineTo(R*.85,-L*.42); ctx.lineTo(R*.7,-L*.3); ctx.lineTo(-R*.7,-L*.3); ctx.closePath(); ctx.fillStyle='#1c2226'; ctx.fill();
		gangStripe(ctx,-R*.92,0,R*.1,L*.8,P); gangStripe(ctx,R*.92,0,R*.1,L*.8,P); rust(ctx,R*.5,L*.3,R*.5,61);
		ctx.beginPath(); ctx.moveTo(-R*.3,-L*.12); ctx.lineTo(R*.3,-L*.12); ctx.lineTo(0,L*.15); ctx.closePath(); ctx.fillStyle='#d6b27a'; ctx.fill(); vol(ctx,0,-L*.16,R*.36,R*.32,'#e8a0b4',{hi:.35}); vol(ctx,R*.1,-L*.22,R*.14,R*.14,'#f5ede0',{hi:.3});
		ctx.beginPath(); rr(ctx,-R*.3,L*.3,R*.6,R*.3,R*.06); ctx.fillStyle='#2b2b2b'; ctx.fill();
		const arm=P.anim==='walk'?Math.sin(TAU*P.t)*R*.15:0; limb(ctx,[-R*1.0,-L*.18],[-R*1.45,-L*.24+arm],R*.18,GOON_SKIN); vol(ctx,-R*1.48,-L*.25+arm,R*.13,R*.13,GOON_SKIN);
		if(P.anim==='attack'||P.anim==='special'){ const k=P.anim==='special'?1:P.act; ell(ctx,0,L*.6+R*.5*k,R*.7*k+R*.1,R*.5*k+R*.1); ctx.fillStyle='rgba(18,16,20,.85)'; ctx.fill(); } },
	plow(ctx,P){ const R=P.R, L=R*2.8; for(const sx of [-1,1]) for(const sy of [-.18,.18,.38]) tire(ctx,sx*R*1.05,sy*L,R*.36,R*.6,P.t,P.spin);
		boxBody(ctx,0,L*.18,R*2.0,L*.68,R*.18,shade(C(P.paint),-.12)); boxBody(ctx,0,-L*.2,R*1.8,L*.34,R*.25,P.paint);
		ctx.fillStyle='#1c2226'; ctx.fillRect(-R*.7,-L*.32,R*1.4,R*.25); for(const sx of [-1,1]){ vol(ctx,sx*R*.75,-L*.02,R*.14,R*.14,'#9a9c9f',{hi:.5}); if(P.spin>0) puffs(ctx,sx*R*.75,-L*.02,P.t,R*.22,-1); }
		ctx.save(); ctx.translate(0,-L*.42); ctx.beginPath(); ctx.moveTo(-R*1.45,R*.15); ctx.lineTo(0,-R*.65); ctx.lineTo(R*1.45,R*.15); ctx.lineTo(R*1.3,R*.45); ctx.lineTo(0,-R*.25); ctx.lineTo(-R*1.3,R*.45); ctx.closePath();
		const g=ctx.createLinearGradient(0,-R*.6,0,R*.45); g.addColorStop(0,'#c9cbcd'); g.addColorStop(.5,'#6a6d70'); g.addColorStop(1,'#3a3c3e'); ctx.fillStyle=g; ctx.fill();
		ctx.save(); ctx.clip(); ctx.fillStyle=css(C(P.gang),.85); for(let i=-6;i<6;i++){ ctx.beginPath(); ctx.moveTo(i*R*.3,-R); ctx.lineTo(i*R*.3+R*.15,-R); ctx.lineTo(i*R*.3+R*.45,R); ctx.lineTo(i*R*.3+R*.3,R); ctx.fill(); } ctx.restore();
		for(let i=-4;i<=4;i++){ ctx.beginPath(); const x=i*R*.32, y=-R*.65+Math.abs(i)*R*.2; ctx.moveTo(x-R*.07,y); ctx.lineTo(x,y-R*.3); ctx.lineTo(x+R*.07,y); ctx.fillStyle='#d3d5d7'; ctx.fill(); } ctx.restore(); rust(ctx,R*.6,L*.3,R*.6,73); },
	tow(ctx,P){ const R=P.R, L=R*2.8; for(const sx of [-1,1]) for(const sy of [-.3,.3]) tire(ctx,sx*R*1.0,sy*L,R*.34,R*.6,P.t,P.spin);
		boxBody(ctx,0,L*.2,R*1.9,L*.55,R*.12,shade(C(P.paint),-.15)); boxBody(ctx,0,-L*.24,R*1.85,L*.4,R*.35,P.paint); ctx.fillStyle='#1c2226'; ctx.fillRect(-R*.7,-L*.38,R*1.4,R*.22);
		vol(ctx,-R*.5,-L*.22,R*.12,R*.08,'#e0782c',{hi:.4}); vol(ctx,R*.5,-L*.22,R*.12,R*.08,'#e0782c',{hi:.4}); gangStripe(ctx,0,-L*.08,R*1.8,R*.1,P);
		chrome(ctx,[0,L*.35],[0,-L*.62],R*.22); const pull=P.anim==='attack'||P.anim==='special'?1:P.anim==='windup'?ease(P.t/.75)*.5:0;
		ctx.save(); ctx.translate(0,-L*.68); vol(ctx,0,0,R*.62,R*.5,'#4a4c4f',{hi:.3}); ell(ctx,0,0,R*.42,R*.32); ctx.fillStyle='#b8733a'; ctx.fill();
		for(let k=0;k<3;k++){ ell(ctx,0,0,R*(.12+k*.1),R*(.09+k*.08)); ctx.lineWidth=R*.04; ctx.strokeStyle='rgba(60,30,10,.6)'; ctx.stroke(); }
		if(pull>0) for(let k=0;k<3;k++){ const u=(P.t*2+k/3)%1; ctx.beginPath(); ctx.ellipse(0,-R*(.3+u*1.6),R*(.4+u*.8),R*(.15+u*.3),0,Math.PI,TAU); ctx.lineWidth=R*.08; ctx.strokeStyle='rgba(140,220,255,'+(pull*(1-u)*.8)+')'; ctx.stroke(); }
		ctx.restore(); },
	chair(ctx,P){ const R=P.R; const sp=(P.t*P.spin*.25)%1*TAU; for(let i=0;i<5;i++){ const a=sp+i/5*TAU; chrome(ctx,[0,0],[Math.cos(a)*R*.95,Math.sin(a)*R*.95],R*.12); vol(ctx,Math.cos(a)*R*.95,Math.sin(a)*R*.95,R*.13,R*.13,'#1d1c1e'); }
		vol(ctx,0,R*.05,R*.68,R*.62,'#3a3438',{hi:.2}); ctx.beginPath(); rr(ctx,-R*.6,R*.55,R*1.2,R*.38,R*.15); ctx.fillStyle='#2b2629'; ctx.fill();
		ctx.save(); ctx.translate(0,R*1.05); boxBody(ctx,0,R*.25,R*.42,R*.95,R*.2,'#c9c4b6'); gangStripe(ctx,0,R*.1,R*.42,R*.12,P);
		for(const k of [-1,1]){ ctx.beginPath(); ctx.moveTo(k*R*.21,R*.5); ctx.lineTo(k*R*.45,R*.78); ctx.lineTo(k*R*.21,R*.72); ctx.closePath(); ctx.fillStyle='#b0302a'; ctx.fill(); }
		jetFlame(ctx,0,R*.72,R*(P.anim==='special'||P.anim==='attack'?2.4:P.spin>0?1.1:.4),R*.36,P.t); ctx.restore();
		rider(ctx,P,0,-R*.05,[[-R*.6,-R*.1],[R*.6,-R*.1]]);
		if(P.anim==='special'){ const g=ctx.createRadialGradient(R*.5,-R*.5,0,R*.5,-R*.5,R*.5); g.addColorStop(0,'rgba(255,240,200,1)'); g.addColorStop(1,'rgba(255,120,30,0)'); ctx.fillStyle=g; ell(ctx,R*.5,-R*.5,R*.5,R*.5); ctx.fill(); } },
	saw(ctx,P){ const R=P.R; tire(ctx,0,R*.05,R*.5,R*1.25,P.t,P.spin); for(const k of [-1,1]) chrome(ctx,[k*R*.55,-R*.1],[k*R*.55,-R*.85],R*.14);
		const sp=P.t*TAU*(P.anim==='attack'?3:P.anim==='walk'?1.5:.5); ctx.save(); ctx.translate(0,-R*1.05); ctx.rotate(sp); ctx.beginPath(); for(let i=0;i<24;i++){ const a=i/24*TAU, r=i%2?R*.62:R*.76; ctx.lineTo(Math.cos(a)*r,Math.sin(a)*r); } ctx.closePath();
		const g=ctx.createRadialGradient(0,0,R*.1,0,0,R*.76); g.addColorStop(0,'#5d6064'); g.addColorStop(.6,'#c9cbcd'); g.addColorStop(1,'#8a8d90'); ctx.fillStyle=g; ctx.fill(); vol(ctx,0,0,R*.14,R*.14,'#3a3c3e'); ctx.restore();
		if(P.anim==='attack'){ for(let i=0;i<6;i++){ const a=-Math.PI/2+(i-2.5)*.25; ctx.beginPath(); ctx.moveTo(Math.cos(a)*R*.8,-R*1.05+Math.sin(a)*R*.8); ctx.lineTo(Math.cos(a)*R*1.4,-R*1.05+Math.sin(a)*R*1.4); ctx.strokeStyle='rgba(255,220,140,.9)'; ctx.lineWidth=R*.05; ctx.stroke(); } }
		vol(ctx,0,R*.15,R*.78,R*.72,'#7d7f7c',{hi:.35}); rust(ctx,R*.3,R*.3,R*.5,81); ell(ctx,0,R*.15,R*.78,R*.72); ctx.lineWidth=R*.06; ctx.strokeStyle='rgba(30,30,30,.4)'; ctx.stroke();
		gangStripe(ctx,0,R*.45,R*1.0,R*.1,P); for(let i=0;i<6;i++){ const a=i/6*TAU; vol(ctx,Math.cos(a)*R*.6,R*.15+Math.sin(a)*R*.55,R*.05,R*.05,'#4a4c4f'); }
		chrome(ctx,[R*.3,R*.3],[R*.55,R*.95],R*.05); vol(ctx,R*.55,R*.97,R*.07,R*.07,'#e0782c');
		vol(ctx,0,-R*.3,R*.26,R*.24,'#2a2c2e'); eye(P.meta,ctx,0,-R*.32,R*.14,'#ff3b2a'); },
	turret(ctx,P){ const R=P.R; for(const sx of [-1,1]) for(const sy of [-1,1]) tire(ctx,sx*R*.9,sy*R*.75,R*.3,R*.45,P.t,P.spin);
		boxBody(ctx,0,0,R*1.6,R*1.9,R*.2,'#5a5650'); ctx.beginPath(); rr(ctx,-R*.6,R*.45,R*1.2,R*.4,R*.06); ctx.fillStyle='#4f5a33'; ctx.fill();
		const rec=P.anim==='attack'?Math.max(0,1-P.t*3)*R*.3:0, aim=P.anim==='windup'?Math.sin(P.t*14)*.06:0; ctx.save(); ctx.rotate(aim);
		chrome(ctx,[0,-R*.2+rec],[0,-R*1.55+rec],R*.24); vol(ctx,0,-R*.1,R*.62,R*.58,'#6d6f72',{hi:.35}); gangStripe(ctx,0,-R*.1,R*1.2,R*.12,P);
		if(P.anim==='attack'&&P.t<.34){ const g=ctx.createRadialGradient(0,-R*1.7,0,0,-R*1.7,R*.55); g.addColorStop(0,'rgba(255,245,200,1)'); g.addColorStop(1,'rgba(255,140,40,0)'); ctx.fillStyle=g; ell(ctx,0,-R*1.7,R*.55,R*.55); ctx.fill(); }
		eye(P.meta,ctx,R*.3,-R*.35,R*.1,'#ff3b2a'); ctx.restore(); }
};
function drawVehicle(ctx,d,anim,t,meta){
	const R=d.R; let bob=0,shake=0,lean=0,act=0,rot=0,spin=1,flame=0;
	if(anim==='walk'){ bob=Math.sin(TAU*t*2)*R*.02; lean=Math.sin(TAU*t)*.04; }
	else if(anim==='idle'){ spin=0; bob=Math.sin(TAU*t)*R*.01; }
	else if(anim==='windup'){ const e=ease(t/.75); shake=Math.sin(t*120)*R*.035*e; spin=.3; flame=d.veh==='bike'?e*.6:0; }
	else if(anim==='attack'){ act=Math.sin(Math.PI*Math.min(1,t*1.2)); spin=2; }
	else if(anim==='special'){ act=t; spin=3; flame=d.veh==='bike'?1:0; }
	else if(anim==='stun'){ rot=Math.sin(TAU*t)*.5; spin=0; }
	else if(anim==='splat'){ spin=0; rot=.35; }
	const P={R,t,anim,act,spin,flame,paint:d.paint||'#7a6a55',gang:d.gang||SCRAP_TEAL,d,meta};
	ctx.save(); ctx.translate(shake,bob); ctx.rotate(rot+(d.veh==='bike'||d.veh==='sidecar'?lean:0));
	if(anim==='splat'){ ctx.scale(1.06,.9); }
	VEH[d.veh](ctx,P);
	if(anim==='splat'){ ctx.globalCompositeOperation='source-atop'; ctx.fillStyle='rgba(20,16,14,.4)'; ctx.fillRect(-R*4,-R*4,R*8,R*8); ctx.globalCompositeOperation='source-over';
		const Rr=rng(d.seed||3); for(let i=0;i<8;i++){ const a=Rr()*TAU, q=R*(1.3+Rr()); ctx.save(); ctx.translate(Math.cos(a)*q,Math.sin(a)*q); ctx.rotate(Rr()*3); ctx.fillStyle=i%2?'#6d6f72':css(C(P.gang)); ctx.fillRect(-R*.12,-R*.08,R*.24,R*.16); ctx.restore(); } }
	ctx.restore();
}

const KIND={biped:drawBiped,quad:drawQuad,shell:drawShell,blob:drawBlob,boulder:drawBoulder,cart:drawCart,beast:drawBeast,scorp:drawScorp,bird:drawBird,snake:drawSnake,vehicle:drawVehicle};
const FRAMES={walk:8,idle:4,windup:4,attack:6,special:8,stun:4,splat:1};

/* ---------- bake ---------- */
const cache=new Map();
let RIM=1.6;
function setRim(w){ if(w!==RIM){ RIM=w; cache.clear(); } }
function frameT(anim,i){ const n=FRAMES[anim]; return anim==='windup'||anim==='special'?(n>1?i/(n-1):0):i/n; }
function bake(d,anim,i,res){
	res=res||2; const key=d.id+'|'+anim+'|'+i+'|'+res+'|'+RIM; let f=cache.get(key); if(f) return f;
	const box=d.box||104, W=Math.ceil(box*res), cv=document.createElement('canvas'); cv.width=cv.height=W;
	const B=document.createElement('canvas'); B.width=B.height=W; const b=B.getContext('2d'); b.setTransform(res,0,0,res,W/2,W/2); b.lineJoin='round';
	const meta={eyes:[]}, t=frameT(anim,i);
	if(anim==='splat'){ const Rr=rng(d.seed||1); b.fillStyle=GOO; for(let k=0;k<9;k++){ const a=Rr()*TAU, q=d.R*(.6+Rr()*1.1); ell(b,Math.cos(a)*q,Math.sin(a)*q,d.R*(.12+Rr()*.3),d.R*(.1+Rr()*.22),a); b.globalAlpha=.75; b.fill(); } b.globalAlpha=1; b.save(); b.scale(1.18,1.22); }
	KIND[d.kind](b,d,anim,t,meta);
	if(anim==='splat') b.restore();
	b.setTransform(1,0,0,1,0,0);
	b.globalCompositeOperation='source-atop'; b.globalAlpha=d.grime==null?.38:d.grime; b.fillStyle=b.createPattern(grime(),'repeat'); b.fillRect(0,0,W,W); b.globalAlpha=1;
	if(anim==='splat'){ b.fillStyle='rgba(28,18,32,.32)'; b.fillRect(0,0,W,W); }
	b.globalCompositeOperation='source-over';
	const o=cv.getContext('2d');
	if(anim!=='splat'&&!d.flyer){ const r=(d.shadowR||d.R*1.25)*res, g=o.createRadialGradient(W/2,W/2+res,0,W/2,W/2+res,r*1.15); g.addColorStop(0,'rgba(10,8,6,.42)'); g.addColorStop(.6,'rgba(10,8,6,.22)'); g.addColorStop(1,'rgba(10,8,6,0)'); o.fillStyle=g; o.fillRect(0,0,W,W); }
	if(RIM>0){ const S=document.createElement('canvas'); S.width=S.height=W; const s=S.getContext('2d'); s.drawImage(B,0,0); s.globalCompositeOperation='source-in'; s.fillStyle='rgba(18,13,16,.9)'; s.fillRect(0,0,W,W);
		const k=RIM*res; for(let a=0;a<12;a++) o.drawImage(S,Math.cos(a/12*TAU)*k,Math.sin(a/12*TAU)*k); }
	o.drawImage(B,0,0);
	f={cv,res,box,eyes:meta.eyes.map(p=>[(p[0]-W/2)/res,(p[1]-W/2)/res]),lamp:meta.lamp?[(meta.lamp[0]-W/2)/res,(meta.lamp[1]-W/2)/res]:null};
	cache.set(key,f); return f;
}
window.GoonArt={bake,vol,limb,rust,ell:ell,FRAMES,setRim,get rim(){return RIM;},GOON_SKIN,GOON_ORANGE,GOO,hexRgb,css,shade,mixc,fbm,hash2,rng,rr};
})();

/* Goon designs: about 15 numbers and a few part names each. Bipeds share the Goon species (violet putty skin, pointed ears,
   an orange rag); critters carry the same orange and violet so the whole roster reads as one world. */
(function(){
"use strict";
const GA=window.GoonArt, TAU=Math.PI*2, SKIN=GA.GOON_SKIN;
const lerp=(a,b,t)=>a+(b-a)*t, ease=t=>{t=t<0?0:t>1?1:t;return t*t*(3-2*t);};
const {vol,limb,rust,ell}=GA;

/* two-handed tools read the pose's anim and time */
function sledgeK(p){ const R=p.R;
	if(p.anim==='windup'){ const e=ease(p.t/.75); return {gx:lerp(R*.55,R*.12,e),gy:lerp(-R*.15,R*.35,e),hx:lerp(R*1.0,R*.2,e),hy:lerp(R*1.05,R*1.8,e),hs:1+.35*e}; }
	if(p.anim==='attack'){ const e=ease(Math.min(1,p.t*1.6)); return {gx:R*.1,gy:lerp(R*.35,-R*.8,e),hx:R*.15,hy:lerp(R*1.8,-R*2.05,e),hs:1+.45*Math.sin(Math.PI*e)}; }
	if(p.anim==='splat') return {gx:R*1.3,gy:-R*.6,hx:R*1.95,hy:-R*1.55,hs:1};
	return {gx:R*.6,gy:-R*.15,hx:R*1.0,hy:R*1.05,hs:1}; }
function sledgeGrip(p,R){ const k=sledgeK(p), dx=k.hx-k.gx, dy=k.hy-k.gy, l=Math.hypot(dx,dy)||1; return [[k.gx-dx/l*R*.32,k.gy-dy/l*R*.32],[k.gx,k.gy]]; }
function sledgeDraw(ctx,p,R){ const k=sledgeK(p), dx=k.hx-k.gx, dy=k.hy-k.gy, l=Math.hypot(dx,dy)||1, a=Math.atan2(dy,dx);
	limb(ctx,[k.gx-dx/l*R*.5,k.gy-dy/l*R*.5],[k.hx,k.hy],R*.16,'#6b5034'); ctx.save(); ctx.translate(k.hx,k.hy); ctx.rotate(a); ctx.scale(k.hs,k.hs);
	ctx.beginPath(); GA.rr(ctx,-R*.24,-R*.42,R*.48,R*.84,R*.08); const g=ctx.createLinearGradient(-R*.24,0,R*.24,0); g.addColorStop(0,'#3d3f42'); g.addColorStop(.5,'#8d9093'); g.addColorStop(1,'#2e3033'); ctx.fillStyle=g; ctx.fill(); rust(ctx,0,R*.15,R*.35,41); ctx.restore(); }
function ramPush(p){ const R=p.R; if(p.anim==='windup') return R*.35*ease(p.t/.75); if(p.anim==='attack') return -R*.45*Math.sin(Math.PI*Math.min(1,p.t*1.2)); if(p.anim==='walk') return Math.sin(TAU*p.t)*R*.05; return 0; }
function ramGrip(p,R){ const q=ramPush(p); return [[-R*.3,-R*.78+q],[R*.3,-R*.98+q]]; }
function ramDraw(ctx,p,R){ if(p.anim==='splat') return; const q=ramPush(p), y0=-R*.45+q, y1=-R*2.75+q;
	ctx.beginPath(); GA.rr(ctx,-R*.21,y1,R*.42,y0-y1,R*.18); const g=ctx.createLinearGradient(-R*.21,0,R*.21,0); g.addColorStop(0,'#4a3322'); g.addColorStop(.5,'#8a6440'); g.addColorStop(1,'#3e2a1a'); ctx.fillStyle=g; ctx.fill();
	ctx.strokeStyle='rgba(30,20,10,.45)'; ctx.lineWidth=R*.04; for(let i=0;i<5;i++){ ctx.beginPath(); ctx.moveTo(-R*.12,y0-(i+.5)*(y0-y1)/5); ctx.lineTo(R*.1,y0-(i+.8)*(y0-y1)/5); ctx.stroke(); }
	ctx.fillStyle=GA.GOON_ORANGE; ctx.fillRect(-R*.22,y0-R*.55,R*.44,R*.12);
	ell(ctx,0,y1+R*.05,R*.5,R*.34); ctx.fillStyle='#1d1c1e'; ctx.fill(); ell(ctx,0,y1+R*.05,R*.26,R*.16); ctx.fillStyle='#55575a'; ctx.fill(); }
function slingE(p){ if(p.anim==='windup') return ease(p.t/.75); if(p.anim==='attack') return Math.max(0,1-p.t*4); return 0; }
function slingGrip(p,R){ const e=slingE(p); return [[-R*.28,-R*1.2],[R*.12,-R*.92+R*1.05*e]]; }
function slingDraw(ctx,p,R){ if(p.anim==='splat') return; const e=slingE(p), hx=-R*.28, hy=-R*1.2, hr=[R*.12,-R*.92+R*1.05*e];
	ctx.lineCap='round'; ctx.strokeStyle='#5b4330'; ctx.lineWidth=R*.12; ctx.beginPath(); ctx.moveTo(hx,hy); ctx.lineTo(hx,hy-R*.3); ctx.moveTo(hx,hy-R*.3); ctx.lineTo(hx-R*.24,hy-R*.62); ctx.moveTo(hx,hy-R*.3); ctx.lineTo(hx+R*.24,hy-R*.62); ctx.stroke();
	ctx.strokeStyle='#6a2a22'; ctx.lineWidth=R*.07; ctx.beginPath(); ctx.moveTo(hx-R*.24,hy-R*.62); ctx.lineTo(hr[0],hr[1]-R*.1); ctx.lineTo(hx+R*.24,hy-R*.62); ctx.stroke(); }
function spikerLay(p,t,R){ p.hL=[-R*.45,-R*1.0]; p.hR=[R*.45,-R*1.0]; p.crouch=1; p.sc=.96; p.fL=[-R*.5,R*.2]; p.fR=[R*.5,R*.2]; }
function spikerStrip(ctx,p,R,anim,t){ if(anim!=='special') return; const L=R*3.2*t; ctx.save(); ctx.translate(0,-R*1.05); ctx.fillStyle='#262422'; ctx.fillRect(-R*.6,-L,R*1.2,L); ctx.fillStyle='#c5c7c9';
	for(let y=0;y<L;y+=R*.3){ for(const x of [-.4,0,.4]){ ctx.beginPath(); ctx.moveTo(x*R-R*.07,-y); ctx.lineTo(x*R,-y-R*.18); ctx.lineTo(x*R+R*.07,-y); ctx.fill(); } } vol(ctx,0,-L,R*.62,R*.26,'#2a2826'); ctx.restore(); }
function torchBottle(ctx,p,R,anim,t){ if(anim==='windup'||(anim==='attack'&&t<.34)){ const h=p.hL; ctx.save(); ctx.translate(h[0],h[1]-R*.15); ctx.fillStyle='#4f6b3a'; ctx.beginPath(); GA.rr(ctx,-R*.13,-R*.3,R*.26,R*.42,R*.08); ctx.fill();
	const g=ctx.createRadialGradient(0,-R*.4,0,0,-R*.4,R*.3); g.addColorStop(0,'rgba(255,240,180,1)'); g.addColorStop(1,'rgba(255,120,30,0)'); ctx.fillStyle=g; ell(ctx,0,-R*.4,R*.3,R*.3); ctx.fill(); ctx.restore(); } }
function gremlinLeap(p,t,R){ const k=Math.sin(Math.PI*t); p.sc=1+.5*k; p.hL=[-R*1.35,-R*.7]; p.hR=[R*1.35,-R*.7]; p.fL=[-R*.6,R*.6]; p.fR=[R*.6,R*.6]; p.a=-1.9; p.mouth=1; }
function foremanShout(p,t,R){ p.hL=[-R*1.25,-R*.75+Math.sin(t*TAU*2)*R*.25]; p.hR=[R*.32,-R*.95]; p.a=-1.57; p.mouth=1; p.sc=1+.03*Math.sin(t*TAU*4); }
function dasherDodge(p,t,R){ p.rot=.55*Math.sin(Math.PI*t); p.hL=[-R*1.25,R*.45]; p.hR=[R*1.2,R*.35]; p.fL=[-R*.75,R*.35]; p.fR=[R*.6,-R*.25]; p.ph=t*2; }
function cartGrip(p,R){ return [[-R*.55,-R*1.0],[R*.55,-R*1.0]]; }

const D={
grunt:{kind:'biped',R:17,box:112,cloth:'#6b5a48',hat:'none',tool:'pipe',seed:3},
hubcap:{kind:'biped',R:18,box:116,cloth:'#4f5b66',sleeve:'#3e4852',hat:'moto',tool:'pipe',shield:'hubcap',seed:5},
dasher:{kind:'biped',R:15,box:124,dep:.5,cloth:'#5d5f4a',hat:'goggles',tool:'wrench',scarf:true,rag:false,stride:1.25,seed:7,specialPose:dasherDodge},
torch:{kind:'biped',R:16,box:112,cloth:'#6e4a33',hat:'gasmask',tool:'flare',back:'tanks',seed:9,drawTool:torchBottle},
spiker:{kind:'biped',R:16,box:132,cloth:'#585a3c',hat:'cone',tool:'none',back:'spikeroll',seed:11,specialPose:spikerLay,drawTool:spikerStrip},
yeti:{kind:'biped',R:25,box:140,cloth:'#d6d0c6',fur:true,head:.6,dep:.78,horns:true,human:true,glove:'#8f7f9e',tool:'none',stride:.9,arm:1.15,seed:13,shadowR:34},
doomcart:{kind:'cart',R:16,box:124,cloth:'#4e4a42',hat:'bandana',bandCol:'#7e2b25',tool:'none',grip:'two',twoGrip:cartGrip,seed:15,shadowR:32},
gremlin:{kind:'biped',R:12,box:88,head:.8,cloth:'#5a4a5e',ears:'big',hat:'none',tool:'wrench',seed:17,specialPose:gremlinLeap},
shellback:{kind:'shell',R:19,box:100,shellCol:'#4f7d7a',seed:19},
foreman:{kind:'biped',R:18,box:116,belly:true,cloth:'#5a5e66',vest:true,hat:'hardhat',tool:'megaphone',seed:21,specialPose:foremanShout},
skink:{kind:'quad',R:12,box:110,len:1.5,wid:.62,tail:2.3,fur:'#6f7d48',lizard:true,burrow:true,stride:1.2,seed:23,eyeCol:'#d9c25a',collar:true},
rat:{kind:'quad',R:8,box:64,len:1.25,wid:.62,tail:2.2,fur:'#6e6460',furry:true,ears:'rat',whiskers:true,tailSkin:true,nose:'#c48a9a',stripe:true,collar:true,seed:25,eyeCol:'#2a0c0c'},
boulder:{kind:'boulder',R:21,box:124,rock:'#8a8178',seed:27,shadowR:30},
nightcrawler:{kind:'biped',R:15,box:120,dep:.48,arm:1.35,skin:'#b8aac6',cloth:'#2c2733',hat:'hood',hoodCol:'#2a2430',tool:'none',seed:29,eyeCol:'#e8f0a0',stride:1.1},
wrecker:{kind:'biped',R:21,box:156,dep:.72,belly:true,cloth:'#5e5249',apron:true,hat:'welding',tool:'none',grip:'two',twoGrip:sledgeGrip,drawTool:sledgeDraw,pads:'tire',seed:31,shadowR:28},
slinger:{kind:'biped',R:16,box:116,cloth:'#55613f',hat:'cap',capCol:'#2b4f6b',tool:'none',grip:'two',twoGrip:slingGrip,drawTool:slingDraw,back:'pack',seed:33},
rammer:{kind:'biped',R:18,box:156,cloth:'#4a3f36',hat:'football',helmCol:'#3b4a5e',pads:'plates',padCol:'#6a5040',tool:'none',grip:'two',twoGrip:ramGrip,drawTool:ramDraw,seed:35},
splitter:{kind:'blob',R:21,box:104,body:'#6b5a3e',seed:37,shadowR:28},
goonling:{kind:'biped',R:10,box:72,head:.74,cloth:'#6b5a48',hat:'none',tool:'none',seed:39,stride:1.2},
};

/* ---------- Wild Things (tier 1): mutant wildlife, natural colors, no gear ---------- */
Object.assign(D,{
jackalope:{kind:'beast',R:12,box:96,len:1.15,wid:.72,fur:'#b39a74',furry:true,ears:'long',antlers:'small',tail:'puff',hop:true,headR:.5,seed:51},
tusker:{kind:'beast',R:16,box:110,len:1.35,wid:.74,fur:'#5b4636',bristle:true,tusks:true,snout:1.35,ears:'pointy',tail:'stub',hoof:true,headR:.5,seed:52},
bandit:{kind:'beast',R:11,box:96,len:1.2,wid:.66,fur:'#7d7a76',dark:'#2a2726',mask:true,muzzle:'#d8d2c6',tail:'ring',tailLen:1.5,ears:'round',headR:.5,seed:53},
stinger:{kind:'scorp',R:12,box:104,col:'#b0864a',seed:54},
buzzard:{kind:'bird',R:13,box:110,col:'#3d342e',headCol:'#b05a4a',beak:'#d8c27a',flyer:true,seed:55},
rattler:{kind:'snake',R:12,box:150,col:'#a8915f',pat:'#5d4a2e',seed:56},
quill:{kind:'beast',R:13,box:110,len:1.1,wid:.82,fur:'#4f4338',quills:true,snout:.9,tail:'stub',headR:.42,seed:57},
spitter:{kind:'blob',R:17,box:92,body:'#6f7d45',toad:true,seed:58},
snapper:{kind:'quad',R:14,box:140,len:1.9,wid:.7,tail:2.6,fur:'#4e5a38',lizard:true,jaw:1.6,ridges:true,log:true,stride:1.0,headR:.5,seed:59,eyeCol:'#d9c25a'},
yipper:{kind:'beast',R:11,box:100,len:1.3,wid:.55,fur:'#a08664',muzzle:'#cdb894',ears:'pointy',tail:'bushy',snout:1.3,headR:.42,stride:1.2,seed:60},
bullmoose:{kind:'beast',R:24,box:150,len:1.4,wid:.72,fur:'#4a3426',antlers:'palm',snout:1.5,hump:true,mane:'#3b2a1f',hoof:true,tail:'stub',headR:.46,seed:61,shadowR:36},
thunderhoof:{kind:'beast',R:21,box:130,len:1.35,wid:.8,fur:'#4b3526',hump:true,mane:'#6b4c33',horns:true,hoof:true,tail:'tuft',snout:.9,headR:.5,seed:62,shadowR:32}
});

/* ---------- Scrap Gang (tier 3): anything with an engine or wheels, in gang teal ---------- */
function chainTool(ctx,p,R){ const a=p.vAnim==='attack'?p.t*TAU*2:p.vAnim==='windup'?p.t*TAU*1.2:-.6, h=p.hR, L=R*1.5;
	const x=h[0]+Math.cos(a)*L, y=h[1]+Math.sin(a)*L; ctx.setLineDash([R*.12,R*.06]); ctx.beginPath(); ctx.moveTo(h[0],h[1]); ctx.quadraticCurveTo((h[0]+x)/2+R*.2,(h[1]+y)/2+R*.2,x,y); ctx.lineWidth=R*.1; ctx.strokeStyle='#a9abae'; ctx.stroke(); ctx.setLineDash([]);
	vol(ctx,x,y,R*.16,R*.16,'#6d6f72',{hi:.4}); }
const RAIDER={human:true,head:.5,glove:'#2b2622',accent:'#2aa6a1',tool:'none'};
const GOONDRV={cloth:'#4e4a42',tool:'none'};
const raider=o=>Object.assign({},RAIDER,o), driver=o=>Object.assign({},GOONDRV,o);
Object.assign(D,{
spoke:{kind:'vehicle',veh:'bike',R:20,box:140,paint:'#4a3c34',rider:raider({skin:'#c08a68',cloth:'#3b302a',hat:'moto',helmCol:'#24282c'}),seed:71},
chainer:{kind:'vehicle',veh:'bike',R:20,box:150,paint:'#6a2a22',rider:raider({skin:'#8a5d42',cloth:'#2e3238',hat:'mohawk',drawTool:chainTool}),seed:72},
torcher:{kind:'vehicle',veh:'trike',R:19,box:180,paint:'#3e3a36',rider:raider({skin:'#b98a6c',cloth:'#4e3d30',hat:'gasmask'}),seed:73},
harpooner:{kind:'vehicle',veh:'buggy',R:18,box:166,paint:'#5e5a52',rider:raider({skin:'#c9a184',cloth:'#5a5040',hat:'goggles'}),seed:74},
sidecar:{kind:'vehicle',veh:'sidecar',R:19,box:150,paint:'#2f3d4a',rider:raider({skin:'#7b5440',cloth:'#3b3a3a',hat:'bandana',bandCol:'#2aa6a1'}),seed:75},
plowboss:{kind:'vehicle',veh:'plow',R:22,box:164,paint:'#6d6252',seed:76,shadowR:40},
karter:{kind:'vehicle',veh:'kart',R:17,box:120,paint:'#5a5856',rider:driver({hat:'goggles'}),seed:77},
slick:{kind:'vehicle',veh:'van',R:20,box:156,paint:'#8fb8a8',seed:78,shadowR:38},
boostjack:{kind:'vehicle',veh:'chair',R:16,box:136,rider:driver({hat:'goggles',cloth:'#5a4a5e'}),seed:79},
shredder:{kind:'vehicle',veh:'quad',R:17,box:130,paint:'#6b3a2a',rider:driver({hat:'bucket',cloth:'#585a3c'}),seed:80},
sawbot:{kind:'vehicle',veh:'saw',R:15,box:104,seed:81},
turret:{kind:'vehicle',veh:'turret',R:16,box:110,seed:82},
magnet:{kind:'vehicle',veh:'tow',R:20,box:156,paint:'#b08a2a',seed:83,shadowR:38}
});
for(const k in D) D[k].id=k;
window.GOONS=D;
})();
