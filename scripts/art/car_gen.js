/* GoonCrusher car art generator. scripts/art/bake_cars.py runs it in headless Edge (scripts/art/bake.html)
 and writes each car's sheets, zone mask, shadow and geometry into scene/car/<car>/art/.
 Units are game pixels; the car faces up (-y is the front). Change a car here, then re-bake. */
(function(){
"use strict";
const BOX_W = 136, BOX_H = 292;
/* a car's canvas in sheet units: BOX_W x BOX_H unless it sets box (the semi's tractor and trailer) */
const boxOf=sp=>sp.box||[BOX_W,BOX_H];

/* ---------- maths and noise ---------- */
function rng(seed){ let s=(seed>>>0)||1; return ()=>{ s^=s<<13; s>>>=0; s^=s>>17; s^=s<<5; s>>>=0; return s/4294967296; }; }
function hash2(x,y,seed){ let h=(Math.imul(x,374761393)+Math.imul(y,668265263)+Math.imul(seed,1442695041))|0; h=Math.imul(h^(h>>>13),1274126177); return ((h^(h>>>16))>>>0)/4294967296; }
function vnoise(x,y,seed){ const xi=Math.floor(x), yi=Math.floor(y), xf=x-xi, yf=y-yi; const u=xf*xf*(3-2*xf), v=yf*yf*(3-2*yf);
	const a=hash2(xi,yi,seed), b=hash2(xi+1,yi,seed), c=hash2(xi,yi+1,seed), d=hash2(xi+1,yi+1,seed); return a+(b-a)*u+(c-a)*v+(a-b-c+d)*u*v; }
function fbm(x,y,seed,oct){ oct=oct||4; let f=0,amp=.5,fr=1,n=0; for(let i=0;i<oct;i++){ f+=amp*vnoise(x*fr,y*fr,seed+i*17); n+=amp; amp*=.5; fr*=2.03; } return f/n; }
function smooth(a,b,x){ const t=Math.min(1,Math.max(0,(x-a)/(b-a))); return t*t*(3-2*t); }
function clamp01(x){ return x<0?0:x>1?1:x; }

/* ---------- colour ---------- */
function hexRgb(h){ h=h.replace('#',''); const n=parseInt(h,16); return [n>>16&255,n>>8&255,n&255]; }
function mixc(a,b,t){ return [a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t]; }
function css(c,a){ return 'rgba('+(c[0]|0)+','+(c[1]|0)+','+(c[2]|0)+','+(a==null?1:a)+')'; }
function shade(c,t){ return t<0?mixc(c,[0,0,0],-t):mixc(c,[255,255,255],t); }
function sat(c,t){ const g=(c[0]+c[1]+c[2])/3; return [g+(c[0]-g)*t,g+(c[1]-g)*t,g+(c[2]-g)*t].map(v=>Math.max(0,Math.min(255,v))); }

/* ---------- body outlines ---------- */
function hwAt(p,y,top){
	const rim=top?p.rim:0, yF=p.y0+(top?p.rimF:0), yR=p.y1-(top?p.rimR:0);
	if(y<=yF||y>=yR) return 0;
	const yc=(yF+yR)/2, hl=(yR-yF)/2, u=(y-yc)/hl, pw=u<0?p.pf:p.pr;
	const e=Math.pow(Math.max(0,1-Math.pow(Math.abs(u),pw)),1/pw);
	let hw=(p.W/2-rim)*e*(1-(u<0?(1-p.tf)*smooth(.15,1,-u):(1-p.tr)*smooth(.15,1,u)));
	for(const a of p.arches||[]) hw+=a[1]*Math.exp(-Math.pow((y-a[0])/a[2],2))*(top?.35:1)*e;
	return hw;
}
function shellSide(p,top,dm,side){
	let yF=p.y0+(top?p.rimF:0), yR=p.y1-(top?p.rimR:0);
	const st=dm&&dm.stage;
	if(st&&p.front) yF+=dm.crushF*(1+dm.skew*side);
	if(st&&p.rear) yR-=dm.crushR*(1-dm.skew*side*.6);
	const W2=p.W/2-(top?p.rim:0), yc=(yF+yR)/2, hl=(yR-yF)/2, N=84, pts=[];
	for(let i=0;i<=N;i++){
		const t=(1-Math.cos(Math.PI*i/N))/2; let y=yF+(yR-yF)*t;
		const u=(y-yc)/hl, pw=u<0?p.pf:p.pr;
		const e=Math.pow(Math.max(0,1-Math.pow(Math.abs(u),pw)),1/pw);
		let hw=W2*e*(1-(u<0?(1-p.tf)*smooth(.15,1,-u):(1-p.tr)*smooth(.15,1,u)));
		for(const a of p.arches||[]) hw+=a[1]*Math.exp(-Math.pow((y-a[0])/a[2],2))*(top?.35:1)*e;
		if(st){
			for(const d of dm.dents) if(d.side===side) hw-=d.amp*(top?.55:1)*Math.exp(-Math.pow((y-d.y)/d.len,2))*e;
			const nf=p.front?smooth(.5,1,-u):0, nr=p.rear?smooth(.55,1,u):0, j=nf*dm.jagF+nr*dm.jagR;
			if(j>0){ hw+=(fbm(i*.42,side*7+(top?3:0),dm.seed,2)-.5)*j*2.2; y+=(fbm(i*.55,side*11,dm.seed+5,2)-.5)*j*1.6; }
		}
		pts.push([Math.max(0,hw)*side,y]);
	}
	return pts;
}
function shellPoly(p,top,dm){ return shellSide(p,top,dm,1).concat(shellSide(p,top,dm,-1).reverse()); }
function poly(ctx,pts,noBegin){ if(!noBegin) ctx.beginPath(); ctx.moveTo(pts[0][0],pts[0][1]); for(let i=1;i<pts.length;i++) ctx.lineTo(pts[i][0],pts[i][1]); ctx.closePath(); }
function rrect(ctx,x,y,w,h,r,noBegin){ if(!noBegin) ctx.beginPath(); r=Math.min(r,w/2,h/2); ctx.moveTo(x+r,y); ctx.arcTo(x+w,y,x+w,y+h,r); ctx.arcTo(x+w,y+h,x,y+h,r); ctx.arcTo(x,y+h,x,y,r); ctx.arcTo(x,y,x+w,y,r); ctx.closePath(); }

/* ---------- car roster ----------
 Each part: y0/y1 front/rear, W width, rim = visible side band, pf/pr = corner squareness, tf/tr = nose/tail taper.
 Every feature listed in a car's feats is drawn on all of its sheets. */
const CARS = {
sedan:{ name:'Sedan', driver:'Anthony', cost:0, seed:11, paint:'#c95a2a', clean:'#e8632b', grime:{dirt:.6,rust:.72,fade:.45,moss:0},
	parts:[{y0:-103,y1:103,W:86,rim:7,rimF:5,rimR:5,pf:5,pr:6,tf:.95,tr:.96,arches:[[-62,1.3,14],[62,1.3,14]],front:1,rear:1,
		cabin:{wf:-30,rf:-15,rr:33,wr:50,gi:3,side:4.4,bowF:5,bowR:3,cp:7,bp:9},doors:[-13,12,38],hood:1,trunk:1,filler:[1,60]}],
	wheels:[[-62,37,10,26],[62,37,10,26]], lights:{f:'quad',r:'rect',grille:1}, bumper:{f:'chrome',r:'chrome',w:.9}, mirrors:-27,
	feats:['primerHood']},
van:{ name:'Van', driver:'Lester', cost:1000, seed:23, paint:'#d9d6cc', clean:'#f2f0ea', grime:{dirt:.5,rust:.45,fade:.2,moss:.75},
	parts:[{y0:-100,y1:100,W:90,rim:6,rimF:6,rimR:3,pf:5.5,pr:12,tf:.93,tr:.99,arches:[[-66,.8,14],[64,.8,14]],front:1,rear:1,
		cabin:{wf:-60,rf:-46,rr:96,wr:96,gi:3,side:5,bowF:4,bowR:0,cp:0,bp:-30},doors:[-38,12],hood:1,trunk:0,filler:[-1,40],
		roofRibs:[-20,92]}],
	wheels:[[-66,38,10,24],[64,38,10,24]], lights:{f:'rect',r:'vert',grille:1}, bumper:{f:'chrome',r:'chrome',w:.94}, mirrors:-56,
	feats:[]},
taxi:{ name:'Taxi', driver:'Andrew', cost:2000, seed:37, paint:'#d9a51f', clean:'#f5b912', grime:{dirt:.55,rust:.55,fade:.3,moss:0},
	parts:[{y0:-102,y1:102,W:88,rim:7.5,rimF:5,rimR:5,pf:5.2,pr:5.4,tf:.9,tr:.92,arches:[[-60,2.2,15],[60,2.2,15]],front:1,rear:1,
		cabin:{wf:-27,rf:-11,rr:31,wr:46,gi:3,side:4.4,bowF:6,bowR:4,cp:6,bp:10},doors:[-10,13,36],hood:1,trunk:1,filler:[-1,58]}],
	wheels:[[-60,37,10,25],[60,37,10,25]], lights:{f:'round',r:'round',grille:1}, bumper:{f:'chrome',r:'chrome',w:.86,guards:1}, mirrors:-24,
	feats:['checker','taxiSign']},
pickup:{ name:'Pickup', driver:'Karen', cost:2500, seed:41, paint:'#2c5a94', clean:'#2f6fc4', grime:{dirt:.6,rust:.5,fade:.4,moss:0},
	parts:[{y0:-107,y1:107,W:90,rim:6.5,rimF:5,rimR:4,pf:7,pr:12,tf:.97,tr:.99,arches:[[-68,1.6,15],[70,1.6,15]],front:1,rear:1,
		cabin:{wf:-38,rf:-26,rr:4,wr:8,gi:3,side:5,bowF:4,bowR:1,cp:0,bp:0},doors:[-24],hood:1,trunk:0,filler:[-1,40],bed:[14,103]}],
	wheels:[[-68,38,11,27],[70,38,11,27]], lights:{f:'rect',r:'vert',grille:1}, bumper:{f:'chrome',r:'chrome',w:.95}, mirrors:-34,
	feats:['bed']},
/* The semi is two cars that bake apart: the tractor (semi) and its trailer (semiTrailer), which the game
   hitches at the fifth wheel (CarTrailer). Each is authored centred on its own axles: the tractor between its
   steer axle and drive tandem, the trailer on its box. The tractor's frame runs on behind the cab, under
   where the trailer's nose sits: rails, the fifth-wheel plate (the kingpin at y 40), the drive tandem and
   mud flaps, so the mount shows as the trailer swings. The trailer is a US-style 53 ft box, about 2.2 times
   the tractor; its kingpin sits 18 behind its nose (y -137) and its tandem at the back. */
semi:{ name:'Semi', driver:'Tiffany', cost:5000, seed:53, paint:'#d8d7d1', clean:'#f4f4f0', grime:{dirt:.5,rust:.3,fade:.15,moss:0}, box:[136,160], stacksY:27,
	parts:[{y0:-66,y1:23,W:90,rim:6,rimF:5,rimR:1,pf:5,pr:30,tf:.93,tr:1,arches:[[-45,2,13]],front:1,rear:0,
		cabin:{wf:-25,rf:-15,rr:23,wr:23,gi:3,side:5,bowF:4,bowR:0,cp:0,bp:3},doors:[-7],hood:1,trunk:0,filler:[1,4],sleeper:1}],
	wheels:[[-45,39,11,26],[36,40,12,22],[54,40,12,22]], lights:{f:'rect',r:'none',grille:1}, bumper:{f:'chrome',r:'none',w:.96}, mirrors:-23, truckMirrors:1,
	feats:['fifthWheel','fuelTanks','stacks']},
semiTrailer:{ name:'Semi trailer', seed:59, paint:'#d8d7d1', clean:'#f4f4f0', grime:{dirt:.5,rust:.3,fade:.15,moss:0}, box:[136,330], zones:'trailer', mirrors:null,
	parts:[{y0:-155,y1:155,W:100,rim:4,rimF:2.5,rimR:3,pf:30,pr:30,tf:1,tr:1,arches:[],front:0,rear:1,box:'trailer'}],
	wheels:[[92,42,12,22],[110,42,12,22]], lights:{f:'none',r:'vert'}, bumper:{f:'none',r:'black',w:.9},
	feats:['trailer']},
audi:{ name:'Supercar', driver:'Snake', cost:10000, seed:67, paint:'#a8202c', clean:'#d4142a', grime:{dirt:.55,rust:.2,fade:.25,moss:0}, sideTint:'#2a2a2e',
	parts:[{y0:-98,y1:98,W:92,rim:8,rimF:5,rimR:5,pf:4,pr:5.4,tf:.78,tr:.9,arches:[[-58,2.6,16],[56,4.2,17]],front:1,rear:1,
		cabin:{wf:-24,rf:-9,rr:18,wr:30,gi:3.5,side:6,bowF:7,bowR:5,cp:9,bp:null},doors:[-6],hood:1,trunk:0,filler:[-1,26]}],
	wheels:[[-58,38,11,26],[56,39,12,27]], lights:{f:'led',r:'strip'}, bumper:{f:'none',r:'none',w:.8}, mirrors:-20,
	feats:['vents','intakes','wing','splitter']},
racer:{ name:'Racer', driver:'Kim', cost:10000, seed:71, paint:'#222326', clean:'#1c1d22', stripe:'#d8641c', grime:{dirt:.6,rust:.35,fade:.25,moss:0},
	parts:[{y0:-99,y1:99,W:94,rim:8.5,rimF:5,rimR:5,pf:4.2,pr:5.4,tf:.82,tr:.9,arches:[[-60,4.6,15],[60,5.2,16]],front:1,rear:1,
		cabin:{wf:-18,rf:-3,rr:28,wr:44,gi:3,side:4.4,bowF:6,bowR:4,cp:8,bp:null},doors:[2],hood:1,trunk:1,filler:[-1,52]}],
	wheels:[[-60,40,12,26],[60,41,13,27]], lights:{f:'round',r:'strip'}, bumper:{f:'none',r:'none',w:.8}, mirrors:-15,
	feats:['stripes','scoop','splitter']},
police:{ name:'Police', driver:'Nikita', cost:25000, seed:83, paint:'#1d2129', clean:'#14181f', roof:'#e3e2dc', grime:{dirt:.55,rust:.45,fade:.3,moss:0},
	parts:[{y0:-105,y1:105,W:88,rim:7,rimF:5,rimR:5,pf:5,pr:5.5,tf:.95,tr:.96,arches:[[-63,1.4,14],[63,1.4,14]],front:1,rear:1,
		cabin:{wf:-31,rf:-16,rr:33,wr:50,gi:3,side:4.4,bowF:5,bowR:3,cp:7,bp:9},doors:[-14,12,38],hood:1,trunk:1,filler:[1,62]}],
	wheels:[[-63,37,10,26],[63,37,10,26]], lights:{f:'quad',r:'rect',grille:1}, bumper:{f:'chrome',r:'chrome',w:.9}, mirrors:-28,
	feats:['twoTone','lightbar','roofNumber']},
ambulance:{ name:'Ambulance', driver:'Xavier', cost:35000, seed:97, paint:'#dedcd5', clean:'#f6f5f1', grime:{dirt:.55,rust:.35,fade:.2,moss:0},
	parts:[{y0:-113,y1:-36,W:90,rim:6,rimF:5,rimR:1,pf:6,pr:30,tf:.95,tr:1,arches:[[-90,1.8,14]],front:1,rear:0,
		cabin:{wf:-76,rf:-64,rr:-36,wr:-36,gi:3,side:5,bowF:4,bowR:0,cp:0,bp:null},doors:[-58],hood:1,trunk:0,filler:null,cabStripe:1},
		{y0:-46,y1:113,W:98,rim:4.5,rimF:2.5,rimR:3,pf:30,pr:30,tf:1,tr:1,arches:[],front:0,rear:1,box:'ambulance'}],
	wheels:[[-90,40,12,27],[84,43,13,27]], lights:{f:'rect',r:'vert',grille:1}, bumper:{f:'black',r:'black',w:.96}, mirrors:-72, truckMirrors:1,
	feats:['ambuBox']}
};
const ORDER=['sedan','van','taxi','pickup','semi','audi','racer','police','ambulance'];

/* ---------- looks per style ---------- */
function makeLook(sp,style){
	const paint=hexRgb(style==='C'?sp.clean:sp.paint);
	const base=style==='A'?sat(paint,.88):style==='B'?sat(paint,1.08):sat(paint,1.12);
	const side=sp.sideTint?mixc(hexRgb(sp.sideTint),base,.18):shade(base,-.36);
	return { style, base, side, sideLo:shade(side,-.35), roof:sp.roof?hexRgb(sp.roof):shade(base,.05),
		spec:style==='C'?.34:style==='A'?.14:0, flat:style==='B', ink:style==='B', inkC:'rgba(16,13,11,.95)',
		seam:style==='B'?'rgba(16,13,11,.85)':'rgba(0,0,0,.42)', seamW:style==='B'?.9:.55,
		glassTop:style==='C'?[64,92,120]:[58,70,80], glassBot:style==='C'?[14,22,34]:[17,21,26] };
}

/* ---------- damage descriptors (same dent positions at every stage, so stages line up) ---------- */
function makeDamage(sp,stage){
	const r=rng(sp.seed*7+3), dents=[];
	const p0=sp.parts[0], pl=sp.parts[sp.parts.length-1], y0=p0.y0, y1=pl.y1;
	for(const side of [1,-1]) for(let i=0;i<3;i++){ const y=y0+(y1-y0)*(.18+.64*r()); dents.push({side,y,len:7+r()*9,amp:(1+r()*1.4)*[0,1,2.7][stage]}); }
	return {stage, seed:sp.seed*13+1, dents, crushF:[0,2.2,14][stage], crushR:[0,1.6,10][stage], skew:r()*.7-.35, jagF:[0,.7,4.2][stage], jagR:[0,.5,3.4][stage]};
}

/* ---------- noise layers (cached per car and resolution so every stage shares them) ---------- */
const noiseCache={};
function noiseLayers(sp,res){
	const key=sp.seed+'@'+res+'@'+boxOf(sp).join('x'); if(noiseCache[key]) return noiseCache[key];
	const q=Math.max(.5,res/2), w=Math.round(boxOf(sp)[0]*q), h=Math.round(boxOf(sp)[1]*q);
	const mk=(fn)=>{ const cv=document.createElement('canvas'); cv.width=w; cv.height=h; const c=cv.getContext('2d'); const id=c.createImageData(w,h), d=id.data;
		for(let j=0;j<h;j++) for(let i=0;i<w;i++){ const x=(i-w/2)/q, y=(j-h/2)/q, v=fn(x,y), k=(j*w+i)*4; d[k]=v[0]; d[k+1]=v[1]; d[k+2]=v[2]; d[k+3]=v[3]; }
		c.putImageData(id,0,0); return cv; };
	const s=sp.seed, g=sp.grime;
	const L={
		dirt: mk((x,y)=>{ const n=fbm(x*.07,y*.022,s,4), m=fbm(x*.22,y*.22,s+9,2); const a=clamp01((n-.44)*2)*.5+clamp01((m-.56)*3)*.22; return [104,86,64,255*a*g.dirt]; }),
		fade: mk((x,y)=>{ const n=fbm(x*.03,y*.05,s+3,3); return [236,230,214,255*clamp01((n-.5)*2.4)*.32*g.fade]; }),
		rust: mk((x,y)=>{ const n=fbm(x*.06,y*.06,s+21,4)+ (fbm(x*.35,y*.35,s+5,2)-.5)*.25; const t=.86-g.rust*.18; const a=smooth(t,t+.05,n);
			const core=smooth(t+.06,t+.12,n); const c=mixc([128,66,34],[60,33,20],core); return [c[0],c[1],c[2],255*a*.92]; }),
		rust2: mk((x,y)=>{ const n=fbm(x*.06,y*.06,s+21,4)+ (fbm(x*.35,y*.35,s+5,2)-.5)*.25; const t=.76-g.rust*.14; const a=smooth(t,t+.05,n);
			const core=smooth(t+.06,t+.13,n); const c=mixc([134,70,36],[56,30,18],core); return [c[0],c[1],c[2],255*a*.95]; }),
		moss: mk((x,y)=>{ const n=fbm(x*.07,y*.07,s+41,4); return [92,112,52,255*clamp01((n-.55)*3)*.8*g.moss]; }),
		soot: mk((x,y)=>{ const n=fbm(x*.08,y*.08,s+61,4); return [14,12,10,255*clamp01((n-.3)*1.8)]; }),
		speck: mk((x,y)=>{ const n=hash2(Math.floor(x*2),Math.floor(y*2),s+77); return n>.997?[34,28,22,150]:[0,0,0,0]; })
	};
	noiseCache[key]=L; return L;
}

/* ---------- drawing helpers ---------- */
function seam(C,pts,w){ const ctx=C.ctx, L=C.look; ctx.beginPath(); ctx.moveTo(pts[0][0],pts[0][1]); for(let i=1;i<pts.length;i++) ctx.lineTo(pts[i][0],pts[i][1]);
	ctx.strokeStyle=L.seam; ctx.lineWidth=w||L.seamW; ctx.stroke();
	if(!L.flat){ ctx.save(); ctx.translate(.45,.45); ctx.strokeStyle='rgba(255,255,255,.13)'; ctx.lineWidth=.45; ctx.stroke(); ctx.restore(); } }
function chromeGrad(ctx,x0,y0,x1,y1){ const g=ctx.createLinearGradient(x0,y0,x1,y1); g.addColorStop(0,'#f2f2ee'); g.addColorStop(.45,'#9a9c9f'); g.addColorStop(.6,'#5f6265'); g.addColorStop(1,'#d5d6d4'); return g; }
function ringPath(ctx,outer,inner){ ctx.beginPath(); poly(ctx,outer,true); poly(ctx,inner,true); }

function drawShadow(C){
	const ctx=C.ctx, res=C.res, off=4000;
	ctx.save(); ctx.shadowColor='rgba(0,0,0,.6)'; ctx.shadowBlur=7*res; ctx.shadowOffsetX=(off+3)*res; ctx.shadowOffsetY=5*res;
	ctx.translate(-off,0); ctx.fillStyle='#000';
	for(const s of C.shells){ poly(ctx,s.outer); ctx.fill(); }
	ctx.restore();
}
function drawWheels(C){
	const ctx=C.ctx;
	for(const [y,x,w,l] of C.sp.wheels) for(const side of [1,-1]){
		const cx=side*x; rrect(ctx,cx-w/2,y-l/2,w,l,2.6); ctx.fillStyle='#17161a'; ctx.fill();
		ctx.save(); ctx.clip(); ctx.strokeStyle='#2e2d32'; ctx.lineWidth=1.1;
		for(let ty=y-l/2+1.5;ty<y+l/2;ty+=2.7){ ctx.beginPath(); ctx.moveTo(cx-w/2,ty); ctx.lineTo(cx+w/2,ty+side*.6); ctx.stroke(); }
		ctx.fillStyle='rgba(255,255,255,.07)'; ctx.fillRect(cx+side*(w/2-1.6)-.8,y-l/2,1.6,l); ctx.restore();
		if(C.look.ink){ rrect(ctx,cx-w/2,y-l/2,w,l,2.6); ctx.strokeStyle=C.look.inkC; ctx.lineWidth=1.2; ctx.stroke(); }
	}
}
function drawBumpers(C){
	const ctx=C.ctx, sp=C.sp, b=sp.bumper, dm=C.dm, st=C.stage;
	const pf=sp.parts[0], pr=sp.parts[sp.parts.length-1];
	const one=(p,front,kind)=>{ if(kind==='none') return;
		const y=front?p.y0+(st?dm.crushF:0):p.y1-(st?dm.crushR:0), w=p.W*b.w, h=6.5;
		ctx.save(); const yy=front?y-2.6:y-3.9; ctx.translate(0,yy+h/2);
		if(st===2){ ctx.rotate((front?1:-1)*dm.skew*.22); ctx.translate(dm.skew*6,front?-1.5:1.5); }
		rrect(ctx,-w/2,-h/2,w,h,3);
		ctx.fillStyle=kind==='chrome'?(C.look.flat?'#c9cacb':chromeGrad(ctx,0,-h/2,0,h/2)):(C.look.flat?'#2a2a2e':(()=>{const g=ctx.createLinearGradient(0,-h/2,0,h/2); g.addColorStop(0,'#45454b'); g.addColorStop(1,'#1d1d21'); return g;})());
		ctx.fill(); if(C.look.ink){ ctx.strokeStyle=C.look.inkC; ctx.lineWidth=1.1; ctx.stroke(); }
		if(b.guards&&kind==='chrome'){ for(const gx of [-w*.28,w*.28]){ rrect(ctx,gx-2.2,front?-h/2-3.4:h/2-2.2,4.4,5.6,2.2); ctx.fillStyle=chromeGrad(ctx,gx-2,0,gx+2,0); ctx.fill(); } }
		ctx.restore(); };
	one(pf,true,b.f); one(pr,false,b.r);
}
function drawBody(C,s){
	const ctx=C.ctx, L=C.look, p=s.p;
	poly(ctx,s.outer);
	if(L.flat) ctx.fillStyle=css(L.side);
	else { const g=ctx.createLinearGradient(-p.W/2,0,p.W/2,0); g.addColorStop(0,css(shade(L.side,.06))); g.addColorStop(.5,css(L.side)); g.addColorStop(1,css(L.sideLo)); ctx.fillStyle=g; }
	ctx.fill();
	poly(ctx,s.top); ctx.fillStyle=css(L.base); ctx.fill();
	ctx.save(); poly(ctx,s.top); ctx.clip();
	if(!L.flat){
		let g=ctx.createLinearGradient(-p.W/2,0,p.W/2,0);
		g.addColorStop(0,'rgba(0,0,0,.26)'); g.addColorStop(.17,'rgba(0,0,0,0)'); g.addColorStop(.33,'rgba(255,255,255,'+L.spec+')'); g.addColorStop(.47,'rgba(255,255,255,0)'); g.addColorStop(.78,'rgba(0,0,0,.05)'); g.addColorStop(1,'rgba(0,0,0,.34)');
		ctx.fillStyle=g; ctx.fillRect(-70,p.y0-10,140,p.y1-p.y0+20);
		g=ctx.createLinearGradient(0,p.y0,0,p.y1); g.addColorStop(0,'rgba(255,255,255,.08)'); g.addColorStop(.45,'rgba(0,0,0,0)'); g.addColorStop(1,'rgba(0,0,0,.18)');
		ctx.fillStyle=g; ctx.fillRect(-70,p.y0-10,140,p.y1-p.y0+20);
		if(L.style==='C'){ ctx.globalCompositeOperation='screen'; ctx.fillStyle='rgba(255,255,255,.22)'; ctx.beginPath(); ctx.moveTo(-p.W*.3,p.y0); ctx.lineTo(-p.W*.18,p.y0); ctx.lineTo(-p.W*.1,p.y1); ctx.lineTo(-p.W*.2,p.y1); ctx.fill(); ctx.globalCompositeOperation='source-over'; }
	} else { ctx.fillStyle='rgba(255,255,255,.14)'; ctx.fillRect(-p.W*.33,p.y0-5,p.W*.12,p.y1-p.y0+10); ctx.fillStyle='rgba(0,0,0,.14)'; ctx.fillRect(p.W*.22,p.y0-5,p.W*.4,p.y1-p.y0+10); }
	ctx.restore();
	poly(ctx,s.top); ctx.strokeStyle=L.flat?'rgba(16,13,11,.5)':'rgba(255,255,255,.14)'; ctx.lineWidth=L.flat?.8:.7; ctx.stroke();
}
function inkOutline(C,s){ if(!C.look.ink) return; const ctx=C.ctx; poly(ctx,s.outer); ctx.strokeStyle=C.look.inkC; ctx.lineWidth=2.2; ctx.lineJoin='round'; ctx.stroke(); }

function glassPoly(p){
	const c=p.cabin, hw=y=>Math.max(4,hwAt(p,y,true)-c.gi), pts=[], N=16;
	for(let i=0;i<=N;i++){ const t=i/N*2-1; pts.push([t*hw(c.wf), c.wf-c.bowF*(1-t*t)+(1-t*t)*0]); }
	for(let i=1;i<N;i++){ const y=c.wf+(c.wr-c.wf)*i/N; pts.push([hw(y),y]); }
	for(let i=0;i<=N;i++){ const t=1-i/N*2; pts.push([t*hw(c.wr), c.wr+c.bowR*(1-t*t)]); }
	for(let i=N-1;i>0;i--){ const y=c.wf+(c.wr-c.wf)*i/N; pts.push([-hw(y),y]); }
	return pts;
}
function roofRect(p){ const c=p.cabin, gy=(c.rf+c.rr)/2, rw=Math.min(hwAt(p,c.rf+4,true),hwAt(p,gy,true),hwAt(p,c.rr-2,true))-c.gi-c.side; return {x:-rw,y:c.rf,w:rw*2,h:c.rr-c.rf}; }
function drawCabin(C,s){
	const ctx=C.ctx, L=C.look, p=s.p, c=p.cabin, gp=glassPoly(p); s.glass=gp;
	poly(ctx,gp);
	if(L.flat) ctx.fillStyle=css(L.glassBot);
	else { const g=ctx.createLinearGradient(0,c.wf-c.bowF,0,c.rf+4); g.addColorStop(0,css(L.glassTop)); g.addColorStop(1,css(L.glassBot)); ctx.fillStyle=g; }
	ctx.fill();
	ctx.save(); poly(ctx,gp); ctx.clip();
	if(c.wr>c.rr+2){ const g=ctx.createLinearGradient(0,c.rr,0,c.wr+c.bowR); g.addColorStop(0,css(L.glassBot)); g.addColorStop(1,css(shade(L.glassTop,-.12))); ctx.fillStyle=g; ctx.fillRect(-60,c.rr,120,c.wr-c.rr+c.bowR+1); }
	ctx.fillStyle='rgba(8,9,10,.55)'; ctx.fillRect(-60,c.wf-c.bowF-1,120,2.2);
	ctx.fillStyle=L.flat?'rgba(255,255,255,.22)':'rgba(255,255,255,'+(L.style==='C'?.2:.1)+')';
	ctx.beginPath(); ctx.moveTo(-40,c.wf+2); ctx.lineTo(-22,c.wf-10); ctx.lineTo(-14,c.wf-10); ctx.lineTo(-32,c.wf+14); ctx.fill();
	ctx.beginPath(); ctx.moveTo(10,c.wr+6); ctx.lineTo(22,c.wr-8); ctx.lineTo(26,c.wr-8); ctx.lineTo(14,c.wr+6); ctx.fill();
	ctx.restore();
	if(L.ink){ poly(ctx,gp); ctx.strokeStyle=L.inkC; ctx.lineWidth=1; ctx.stroke(); }
	const r=roofRect(p), hwg=y=>Math.max(4,hwAt(p,y,true)-c.gi);
	ctx.fillStyle=css(L.base);
	for(const sd of [1,-1]){
		const rx=sd*(r.w/2), gx=sd*hwg(c.wf+1);
		ctx.beginPath(); ctx.moveTo(rx,c.rf+2); ctx.lineTo(rx-sd*2.6,c.rf+2); ctx.lineTo(gx-sd*1.8,c.wf+1); ctx.lineTo(gx+sd*.4,c.wf); ctx.closePath(); ctx.fillStyle=css(shade(L.roof,-.08)); ctx.fill();
		if(c.cp>0&&c.wr>c.rr+2){ const gx2=sd*hwg(c.wr-1); ctx.beginPath(); ctx.moveTo(rx,c.rr-3); ctx.lineTo(rx-sd*c.cp,c.rr-2); ctx.lineTo(gx2-sd*c.cp*.5,c.wr); ctx.lineTo(gx2+sd*.4,c.wr); ctx.closePath(); ctx.fill(); }
		if(c.bp!=null){ const by=c.bp; ctx.fillRect(sd>0?rx-1:-hwg(by)-.4,by-1.6,hwg(by)-r.w/2+1.4,3.2); }
	}
	ctx.save(); ctx.shadowColor='rgba(0,0,0,.55)'; ctx.shadowBlur=3*C.res; ctx.shadowOffsetY=1*C.res;
	rrect(ctx,r.x,r.y,r.w,r.h,Math.min(9,r.w*.22)); ctx.fillStyle=css(L.roof); ctx.fill(); ctx.restore();
	ctx.save(); rrect(ctx,r.x,r.y,r.w,r.h,Math.min(9,r.w*.22)); ctx.clip();
	if(!L.flat){ let g=ctx.createLinearGradient(r.x,0,r.x+r.w,0); g.addColorStop(0,'rgba(0,0,0,.18)'); g.addColorStop(.25,'rgba(255,255,255,'+(L.spec*.9)+')'); g.addColorStop(.45,'rgba(255,255,255,0)'); g.addColorStop(1,'rgba(0,0,0,.3)'); ctx.fillStyle=g; ctx.fillRect(r.x,r.y,r.w,r.h);
		g=ctx.createLinearGradient(0,r.y,0,r.y+r.h); g.addColorStop(0,'rgba(255,255,255,.1)'); g.addColorStop(1,'rgba(0,0,0,.12)'); ctx.fillStyle=g; ctx.fillRect(r.x,r.y,r.w,r.h); }
	else { ctx.fillStyle='rgba(255,255,255,.14)'; ctx.fillRect(r.x+r.w*.12,r.y,r.w*.18,r.h); ctx.fillStyle='rgba(0,0,0,.14)'; ctx.fillRect(r.x+r.w*.7,r.y,r.w*.3,r.h); }
	if(p.roofRibs){ ctx.strokeStyle='rgba(0,0,0,.22)'; ctx.lineWidth=.6; for(let y=p.roofRibs[0];y<p.roofRibs[1];y+=9){ ctx.beginPath(); ctx.moveTo(r.x+3,y); ctx.lineTo(r.x+r.w-3,y); ctx.stroke(); ctx.strokeStyle='rgba(255,255,255,.12)'; ctx.beginPath(); ctx.moveTo(r.x+3,y+.8); ctx.lineTo(r.x+r.w-3,y+.8); ctx.stroke(); ctx.strokeStyle='rgba(0,0,0,.22)'; } }
	ctx.restore();
	if(L.ink){ rrect(ctx,r.x,r.y,r.w,r.h,Math.min(9,r.w*.22)); ctx.strokeStyle=L.inkC; ctx.lineWidth=1.1; ctx.stroke(); }
	s.roof=r;
}
function drawPanels(C,s){
	const p=s.p, c=p.cabin, hT=y=>hwAt(p,y,true), hO=y=>hwAt(p,y,false);
	if(p.box) return;
	const yF=p.y0+p.rimF+(C.stage&&p.front?C.dm.crushF*.6:0);
	if(p.hood&&c){ const a=yF+5, b=c.wf-c.bowF-3; if(b>a+6){
		for(const sd of [1,-1]){ const pts=[]; for(let y=a;y<=b;y+=3) pts.push([sd*(hT(y)-2.4),y]); seam(C,pts); }
		const pts=[]; for(let x=-1;x<=1.001;x+=.1) pts.push([x*(hT(a)-2.4),a+ (1-x*x)*-1.5]); seam(C,pts);
		const pts2=[]; for(let x=-1;x<=1.001;x+=.1) pts2.push([x*(hT(b)-2.4),b]); seam(C,pts2);
		if(!C.look.flat){ const ctx=C.ctx; ctx.strokeStyle='rgba(255,255,255,.1)'; ctx.lineWidth=.8; for(const sd of [1,-1]){ ctx.beginPath(); ctx.moveTo(sd*hT(a)*.3,a+4); ctx.lineTo(sd*hT(b)*.3,b-2); ctx.stroke(); } }
	} }
	if(p.trunk&&c){ const a=c.wr+c.bowR+3, b=p.y1-p.rimR-4-(C.stage&&p.rear?C.dm.crushR*.6:0); if(b>a+6){
		for(const sd of [1,-1]){ const pts=[]; for(let y=a;y<=b;y+=3) pts.push([sd*(hT(y)-2.4),y]); seam(C,pts); }
		const pts=[]; for(let x=-1;x<=1.001;x+=.1) pts.push([x*(hT(a)-2.4),a]); seam(C,pts);
	} }
	for(const dy of p.doors||[]) for(const sd of [1,-1]) seam(C,[[sd*(hT(dy)+.3),dy],[sd*(hO(dy)-.4),dy+.4]],C.look.seamW*1.2);
	if(p.filler){ const [sd,fy]=p.filler, ctx=C.ctx, x=sd*(hO(fy)+hT(fy))/2; ctx.beginPath(); ctx.arc(x,fy,1.9,0,7); ctx.strokeStyle=C.look.seam; ctx.lineWidth=.5; ctx.stroke(); }
	if(p.cabStripe){ const ctx=C.ctx; ctx.save(); ringPath(ctx,s.outer,s.top); ctx.clip('evenodd'); ctx.fillStyle='#b8231d'; ctx.fillRect(-60,p.y0+14,120,p.y1-p.y0); ctx.restore(); }
}
function lens(C,x,y,r,col){ const ctx=C.ctx; ctx.beginPath(); ctx.arc(x,y,r,0,7);
	ctx.fillStyle=C.look.flat?'#d9d9d4':chromeGrad(ctx,x-r,y-r,x+r,y+r); ctx.fill();
	ctx.beginPath(); ctx.arc(x,y,r*.74,0,7); if(C.look.flat) ctx.fillStyle=css(col); else { const g=ctx.createRadialGradient(x-r*.25,y-r*.25,0,x,y,r*.74); g.addColorStop(0,'#fffef6'); g.addColorStop(.6,css(col)); g.addColorStop(1,css(shade(col,-.35))); ctx.fillStyle=g; } ctx.fill();
	if(C.look.ink){ ctx.beginPath(); ctx.arc(x,y,r,0,7); ctx.strokeStyle=C.look.inkC; ctx.lineWidth=.7; ctx.stroke(); } }
function lampRect(C,x,y,w,h,col,glow){ const ctx=C.ctx; rrect(ctx,x-w/2-.8,y-h/2-.8,w+1.6,h+1.6,1.6); ctx.fillStyle=C.look.flat?'#bdbdb8':chromeGrad(ctx,x,y-h,x,y+h); ctx.fill();
	rrect(ctx,x-w/2,y-h/2,w,h,1.2); if(C.look.flat) ctx.fillStyle=css(col); else { const g=ctx.createLinearGradient(x-w/2,y,x+w/2,y); g.addColorStop(0,css(shade(col,glow?.5:.25))); g.addColorStop(1,css(shade(col,-.25))); ctx.fillStyle=g; } ctx.fill();
	if(C.look.ink){ ctx.strokeStyle=C.look.inkC; ctx.lineWidth=.6; ctx.stroke(); } }
function lightPositions(C){
	const sp=C.sp, pf=sp.parts[0], pr=sp.parts[sp.parts.length-1], st=C.stage, dm=C.dm;
	const yF=pf.y0+(st?dm.crushF:0), yR=pr.y1-(st?dm.crushR:0);
	const hf=hwAt(pf,pf.y0+9,false), hr=hwAt(pr,pr.y1-9,false);
	const f=[], r=[];
	if(sp.lights.f==='quad') for(const sd of [1,-1]) f.push([sd*hf*.5,yF+3.6,3],[sd*hf*.77,yF+4,3]);
	if(sp.lights.f==='round') for(const sd of [1,-1]) f.push([sd*hf*.66,yF+4.6,4.3]);
	if(sp.lights.f==='rect') for(const sd of [1,-1]) f.push([sd*hf*.7,yF+3.4,0]);
	if(sp.lights.f==='led') for(const sd of [1,-1]) f.push([sd*hf*.62,yF+7,0]);
	if(sp.lights.r==='rect') for(const sd of [1,-1]) r.push([sd*hr*.68,yR-3]);
	if(sp.lights.r==='round') for(const sd of [1,-1]) r.push([sd*hr*.7,yR-4]);
	if(sp.lights.r==='strip') for(const sd of [1,-1]) r.push([sd*hr*.55,yR-3]);
	if(sp.lights.r==='vert') for(const sd of [1,-1]) r.push([sd*(hr-2.4),yR-4]);
	return {f,r,yF,yR,hf,hr};
}
function drawLights(C){
	const sp=C.sp, P=lightPositions(C), ctx=C.ctx, head=[244,234,206], tail=[176,24,22];
	C.lightPos=P;
	if(sp.lights.grille){ const gw=P.hf*.92, gy=P.yF+.6; ctx.save(); if(C.stage===2){ ctx.translate(0,gy); ctx.rotate(C.dm.skew*.08); ctx.translate(0,-gy); } rrect(ctx,-gw,gy,gw*2,6.2,2.2); ctx.fillStyle=C.look.flat?'#c8c9c8':chromeGrad(ctx,0,gy,0,gy+6); ctx.fill(); rrect(ctx,-gw+1,gy+1,gw*2-2,4.2,1.6); ctx.fillStyle='#121214'; ctx.fill();
		ctx.strokeStyle='rgba(150,152,155,.55)'; ctx.lineWidth=.45; for(let x=-gw+3;x<gw-2;x+=2.2){ ctx.beginPath(); ctx.moveTo(x,gy+1.2); ctx.lineTo(x,gy+5); ctx.stroke(); } if(C.look.ink){ rrect(ctx,-gw,gy,gw*2,6.2,2.2); ctx.strokeStyle=C.look.inkC; ctx.lineWidth=.8; ctx.stroke(); } ctx.restore(); }
	for(const [x,y,r] of P.f){
		if(sp.lights.f==='quad'||sp.lights.f==='round') lens(C,x,y,r,head);
		else if(sp.lights.f==='rect') lampRect(C,x,y,13,4.6,head,1);
		else { ctx.save(); ctx.translate(x,y); ctx.rotate(Math.sign(x)*.32); rrect(ctx,-8,-1.4,16,2.8,1.4); ctx.fillStyle='#1a1b1e'; ctx.fill(); rrect(ctx,-7,-.7,14,1.4,.7); ctx.fillStyle='#eaf4ff'; ctx.fill(); ctx.restore(); }
	}
	for(const [x,y] of P.r){
		if(sp.lights.r==='round') lens(C,x,y,3.2,tail);
		else if(sp.lights.r==='strip'){ ctx.save(); rrect(ctx,x-9,y-1.2,18,2.4,1.2); ctx.fillStyle='#7a1012'; ctx.fill(); rrect(ctx,x-8,y-.5,16,1,.5); ctx.fillStyle='#ff5a48'; ctx.fill(); ctx.restore(); }
		else if(sp.lights.r==='vert') lampRect(C,x,y-4,3.4,9,tail,0);
		else lampRect(C,x,y,12,3.8,tail,0);
	}
}
function drawMirrors(C){
	const sp=C.sp, ctx=C.ctx, p=sp.parts[0], y=sp.mirrors, L=C.look;
	if(y==null) return;
	for(const sd of [1,-1]){
		if(C.stage===2&&sd===(C.dm.skew>0?1:-1)){ ctx.fillStyle='#2a2a2c'; ctx.fillRect(sd*hwAt(p,y,false)-1,y-1,2,2); continue; }
		const x=sd*(hwAt(p,y,false)+(sp.truckMirrors?4.5:2.6));
		ctx.save(); ctx.translate(x,y); ctx.rotate(sd*.18);
		if(sp.truckMirrors){ ctx.fillStyle='#2b2c2f'; ctx.fillRect(-sd*4.5,-.6,sd*4.5,1.2); rrect(ctx,-2,-4.5,4,9,1.2); ctx.fillStyle='#232427'; ctx.fill(); }
		else { rrect(ctx,-3,-1.8,6,3.6,1.6); ctx.fillStyle=css(L.base); ctx.fill(); ctx.fillStyle='rgba(0,0,0,.35)'; ctx.fillRect(-3,.6,6,1.2); }
		if(L.ink){ ctx.strokeStyle=L.inkC; ctx.lineWidth=.6; ctx.stroke(); }
		ctx.restore();
	}
}

/* ---------- features ---------- */
const FEATS={
primerHood:{layer:'paint',fn(C,s){ const p=s.p, ctx=C.ctx; ctx.save(); poly(ctx,s.top); ctx.clip();
	ctx.beginPath(); ctx.moveTo(-60,p.y0-5); ctx.lineTo(60,p.y0-5); const b=p.cabin.wf-p.cabin.bowF-2.5; for(let x=60;x>=-60;x-=4) ctx.lineTo(x,b+(hash2(x,1,C.sp.seed)-.5)*1.2); ctx.closePath();
	ctx.fillStyle=C.look.style==='C'?'rgba(150,152,140,.95)':'rgba(116,120,104,.92)'; ctx.fill(); ctx.restore(); }},
twoTone:{layer:'paint',fn(C,s){ const p=s.p, ctx=C.ctx; ctx.save(); ringPath(ctx,s.outer,s.top); ctx.clip('evenodd');
	ctx.fillStyle=css(shade(hexRgb(C.sp.roof),C.look.flat?0:-.12)); ctx.fillRect(-60,p.cabin.wf+2,120,p.cabin.wr-p.cabin.wf+4); ctx.restore();
	ctx.save(); poly(ctx,s.top); ctx.clip(); ctx.fillStyle=css(hexRgb(C.sp.roof),.92); for(const sd of [1,-1]){ ctx.beginPath(); for(let y=p.cabin.wf+2;y<=p.cabin.wr+6;y+=4){ ctx.lineTo(sd*(hwAt(p,y,true)+1),y); } for(let y=p.cabin.wr+6;y>=p.cabin.wf+2;y-=4){ ctx.lineTo(sd*(hwAt(p,y,true)-2.6),y); } ctx.fill(); } ctx.restore(); }},
checker:{layer:'paint',fn(C,s){ const p=s.p, ctx=C.ctx; ctx.save(); ringPath(ctx,s.outer,s.top); ctx.clip('evenodd');
	for(let y=-62,k=0;y<80;y+=2.6,k++) for(const sd of [1,-1]) for(let row=0;row<2;row++){ const x=sd*(hwAt(p,y,false)-1.4-row*2.6); ctx.fillStyle=((k+row)%2)?'#151515':'#efeee6'; ctx.fillRect(x-1.3,y,2.6,2.6); }
	ctx.restore(); }},
stripes:{layer:'paint',fn(C,s){ const p=s.p, ctx=C.ctx, col=hexRgb(C.sp.stripe); ctx.save(); poly(ctx,s.top); ctx.clip(); ctx.fillStyle=css(C.look.style==='A'?sat(col,.85):col); ctx.fillRect(-12,p.y0-5,7,p.y1-p.y0+10); ctx.fillRect(5,p.y0-5,7,p.y1-p.y0+10); ctx.restore(); }},
stripesRoof:{layer:'roof',fn(C){ const s=C.shells[0], r=s.roof, p=s.p, ctx=C.ctx, col=hexRgb(C.sp.stripe); if(!r) return; ctx.save(); rrect(ctx,r.x,r.y,r.w,r.h,Math.min(9,r.w*.22)); ctx.clip(); ctx.fillStyle=css(C.look.style==='A'?sat(col,.85):col); ctx.fillRect(-12,r.y,7,r.h); ctx.fillRect(5,r.y,7,r.h);
	if(!C.look.flat){ const g=ctx.createLinearGradient(r.x,0,r.x+r.w,0); g.addColorStop(0,'rgba(0,0,0,.1)'); g.addColorStop(.3,'rgba(255,255,255,.1)'); g.addColorStop(1,'rgba(0,0,0,.25)'); ctx.fillStyle=g; ctx.fillRect(r.x,r.y,r.w,r.h); } ctx.restore(); }},
scoop:{layer:'paint',fn(C,s){ const ctx=C.ctx, y=s.p.cabin.wf-34; rrect(ctx,-9,y,18,20,3); ctx.fillStyle=css(shade(C.look.base,.08)); ctx.fill(); ctx.strokeStyle='rgba(0,0,0,.5)'; ctx.lineWidth=.6; ctx.stroke(); rrect(ctx,-6.5,y+1.2,13,4,1.5); ctx.fillStyle='#0b0b0c'; ctx.fill(); }},
splitter:{layer:'under',fn(C){ const p=C.sp.parts[0], ctx=C.ctx, y=p.y0+(C.stage?C.dm.crushF:0); ctx.save(); if(C.stage===2) ctx.rotate(C.dm.skew*.1); rrect(ctx,-p.W*.42,y-2.4,p.W*.84,5,2.4); ctx.fillStyle='#141416'; ctx.fill(); ctx.restore(); }},
wing:{layer:'over',fn(C){ const p=C.sp.parts[C.sp.parts.length-1], ctx=C.ctx, y=p.y1-9-(C.stage?C.dm.crushR*.8:0), w=p.W*.96;
	ctx.save(); if(C.stage===2) ctx.rotate(-C.dm.skew*.14);
	ctx.save(); ctx.shadowColor='rgba(0,0,0,.6)'; ctx.shadowBlur=3*C.res; ctx.shadowOffsetY=2*C.res; rrect(ctx,-w/2,y-4,w,7.5,2); ctx.fillStyle='#17171a'; ctx.fill(); ctx.restore();
	const g=ctx.createLinearGradient(0,y-4,0,y+3.5); g.addColorStop(0,'#4a4b50'); g.addColorStop(1,'#141416'); rrect(ctx,-w/2,y-4,w,7.5,2); ctx.fillStyle=C.look.flat?'#26262a':g; ctx.fill();
	ctx.fillStyle='#0d0d0f'; ctx.fillRect(-w/2-1,y-6,2.4,12); ctx.fillRect(w/2-1.4,y-6,2.4,12); if(C.look.ink){ rrect(ctx,-w/2,y-4,w,7.5,2); ctx.strokeStyle=C.look.inkC; ctx.lineWidth=1; ctx.stroke(); } ctx.restore(); }},
vents:{layer:'paint',fn(C,s){ const ctx=C.ctx, p=s.p, y0=p.cabin.wr+8; for(let i=0;i<7;i++){ const y=y0+i*5.4, w=hwAt(p,y,true)*1.15; rrect(ctx,-w/2,y,w,2.6,1.3); ctx.fillStyle='#101012'; ctx.fill(); ctx.fillStyle='rgba(255,255,255,.12)'; ctx.fillRect(-w/2+1,y+2.6,w-2,.5); } }},
intakes:{layer:'paint',fn(C,s){ const ctx=C.ctx, p=s.p; for(const sd of [1,-1]){ ctx.beginPath(); const y=p.cabin.rr-4; const x=sd*hwAt(p,y,false); ctx.moveTo(x,y-14); ctx.lineTo(x-sd*7,y+10); ctx.lineTo(x,y+14); ctx.closePath(); ctx.fillStyle='#0d0d0f'; ctx.fill(); } }},
taxiSign:{layer:'roof',fn(C){ const s=C.shells[0], r=s.roof, ctx=C.ctx; const y=r.y+10, w=Math.min(26,r.w-8);
	ctx.save(); ctx.shadowColor='rgba(0,0,0,.6)'; ctx.shadowBlur=3*C.res; ctx.shadowOffsetY=1.5*C.res; rrect(ctx,-w/2,y,w,9,2); ctx.fillStyle='#f0e7c8'; ctx.fill(); ctx.restore();
	rrect(ctx,-w/2+1.4,y+1.4,w-2.8,6.2,1.4); ctx.fillStyle=C.look.flat?'#f7c21b':(()=>{const g=ctx.createLinearGradient(0,y,0,y+9); g.addColorStop(0,'#ffe27a'); g.addColorStop(1,'#d9a516'); return g;})(); ctx.fill();
	ctx.fillStyle='#1a1408'; ctx.font='800 5.2px Arial, sans-serif'; ctx.textAlign='center'; ctx.textBaseline='middle'; ctx.fillText('TAXI',0,y+4.7);
	if(C.look.ink){ rrect(ctx,-w/2,y,w,9,2); ctx.strokeStyle=C.look.inkC; ctx.lineWidth=.9; ctx.stroke(); } }},
lightbar:{layer:'roof',fn(C){ const s=C.shells[0], r=s.roof, ctx=C.ctx, y=r.y+5, w=r.w+3;
	ctx.save(); ctx.shadowColor='rgba(0,0,0,.6)'; ctx.shadowBlur=3*C.res; ctx.shadowOffsetY=1.5*C.res; rrect(ctx,-w/2,y,w,7,3); ctx.fillStyle='#2b2d31'; ctx.fill(); ctx.restore();
	const seg=(x0,x1,c)=>{ rrect(ctx,x0,y+1,x1-x0,5,2); if(C.look.flat) ctx.fillStyle=c; else { const g=ctx.createLinearGradient(0,y,0,y+7); g.addColorStop(0,'#fff'); g.addColorStop(.35,c); g.addColorStop(1,'#111'); ctx.fillStyle=g; } ctx.fill(); };
	seg(-w/2+1.2,-3,'#2f64d8'); seg(3,w/2-1.2,'#d8322f'); rrect(ctx,-2.6,y+1,5.2,5,1); ctx.fillStyle='#d7d8d6'; ctx.fill();
	if(C.look.ink){ rrect(ctx,-w/2,y,w,7,3); ctx.strokeStyle=C.look.inkC; ctx.lineWidth=.9; ctx.stroke(); } }},
roofNumber:{layer:'roof',fn(C){ const r=C.shells[0].roof, ctx=C.ctx; ctx.fillStyle='rgba(20,22,28,.85)'; ctx.font='800 13px Arial, sans-serif'; ctx.textAlign='center'; ctx.textBaseline='middle'; ctx.fillText('07',0,r.y+r.h*.62); }},
bed:{layer:'paint',fn(C,s){ const p=s.p, ctx=C.ctx, [a,b]=p.bed, bb=b-(C.stage?C.dm.crushR*.7:0);
	const pts=[]; for(let y=a;y<=bb;y+=2) pts.push([hwAt(p,y,true)-2.6,y]); for(let y=bb;y>=a;y-=2) pts.push([-(hwAt(p,y,true)-2.6),y]);
	poly(ctx,pts); ctx.fillStyle=css(shade(C.look.base,-.45)); ctx.fill();
	ctx.save(); poly(ctx,pts); ctx.clip(); ctx.strokeStyle='rgba(0,0,0,.35)'; ctx.lineWidth=1.4; for(let x=-34;x<35;x+=7){ ctx.beginPath(); ctx.moveTo(x,a); ctx.lineTo(x,bb); ctx.stroke(); }
	ctx.strokeStyle='rgba(255,255,255,.08)'; ctx.lineWidth=.8; for(let x=-33;x<35;x+=7){ ctx.beginPath(); ctx.moveTo(x,a); ctx.lineTo(x,bb); ctx.stroke(); }
	const g=ctx.createLinearGradient(0,a,0,a+10); g.addColorStop(0,'rgba(0,0,0,.55)'); g.addColorStop(1,'rgba(0,0,0,0)'); ctx.fillStyle=g; ctx.fillRect(-50,a,100,10); ctx.restore();
	ctx.strokeStyle=css(shade(C.look.base,.12)); ctx.lineWidth=1; poly(ctx,pts); ctx.stroke(); seam(C,[[-30,bb-1],[30,bb-1]],.8); }},
fuelTanks:{layer:'under',fn(C){ const ctx=C.ctx; for(const sd of [1,-1]){ const x=sd*46; rrect(ctx,x-5,-22,10,22,4.5); ctx.fillStyle=chromeGrad(ctx,x-5,0,x+5,0); ctx.fill(); ctx.strokeStyle='rgba(0,0,0,.4)'; ctx.lineWidth=.6; for(const y of [-18,-4]){ ctx.beginPath(); ctx.moveTo(x-5,y); ctx.lineTo(x+5,y); ctx.stroke(); } } }},
stacks:{layer:'over',fn(C){ const ctx=C.ctx; for(const sd of [1,-1]){ const x=sd*36, y=C.sp.stacksY; ctx.beginPath(); ctx.arc(x,y,3.2,0,7); ctx.fillStyle=chromeGrad(ctx,x-3,y-3,x+3,y+3); ctx.fill(); ctx.beginPath(); ctx.arc(x,y,1.8,0,7); ctx.fillStyle='#111'; ctx.fill(); } }},
/* the tractor's chassis behind the cab: frame rails and cross members, air lines off the cab's back, the
   fifth-wheel plate with its kingpin slot (y 40), the drive tandem's mud flaps */
fifthWheel:{layer:'under',fn(C){ const ctx=C.ctx, L=C.look, y0=16, y1=72, flat=L.flat;
	for(const sd of [1,-1]){ ctx.fillStyle=flat?'#232327':(()=>{ const g=ctx.createLinearGradient(sd*13,0,sd*21,0); g.addColorStop(0,'#3a3a40'); g.addColorStop(1,'#18181b'); return g; })(); ctx.fillRect(sd>0?13:-21,y0,8,y1-y0); }
	ctx.fillStyle='#1d1d21'; for(const y of [30,50,68]) ctx.fillRect(-13,y,26,3);
	for(const [x,c] of [[-5,'#b8261e'],[5,'#2f5fc4']]){ ctx.strokeStyle=c; ctx.lineWidth=1.3; ctx.beginPath(); ctx.moveTo(x,24); ctx.bezierCurveTo(x*2.4,29,x*.4,31,x*1.6,35); ctx.stroke(); }
	ctx.save(); ctx.translate(0,40);
	ctx.beginPath(); ctx.arc(0,0,19,0,Math.PI*2); ctx.fillStyle=flat?'#2b2c30':(()=>{ const g=ctx.createRadialGradient(-5,-6,2,0,0,19); g.addColorStop(0,'#55575d'); g.addColorStop(1,'#1f2023'); return g; })(); ctx.fill();
	ctx.strokeStyle='rgba(0,0,0,.6)'; ctx.lineWidth=1; ctx.stroke();
	ctx.fillStyle='#0d0d0f'; ctx.beginPath(); ctx.moveTo(-7,19); ctx.lineTo(-2.2,1); ctx.lineTo(2.2,1); ctx.lineTo(7,19); ctx.closePath(); ctx.fill();
	ctx.beginPath(); ctx.arc(0,0,3.6,0,Math.PI*2); ctx.fill();
	ctx.strokeStyle='rgba(255,255,255,.16)'; ctx.lineWidth=.7; ctx.beginPath(); ctx.arc(0,0,15,Math.PI*1.05,Math.PI*1.95); ctx.stroke();
	ctx.restore();
	for(const sd of [1,-1]){ rrect(ctx,sd*40-7,65,14,4,1); ctx.fillStyle='#141416'; ctx.fill(); }
	if(L.ink){ ctx.strokeStyle=L.inkC; ctx.lineWidth=1; ctx.beginPath(); ctx.arc(0,40,19,0,Math.PI*2); ctx.stroke(); } }},
/* the trailer's roof: ribs, side rails, amber markers down both sides and the rear doors' seam */
trailer:{layer:'paint',fn(C,s){ const sh=C.shells.find(q=>q.p.box==='trailer'); if(s!==sh) return; const p=sh.p, ctx=C.ctx, y0=p.y0+p.rimF, y1=p.y1-p.rimR-(C.stage?C.dm.crushR:0), w=p.W/2-p.rim;
	ctx.save(); poly(ctx,sh.top); ctx.clip();
	for(let y=y0+4;y<y1;y+=6.5){ ctx.fillStyle='rgba(0,0,0,.13)'; ctx.fillRect(-w,y,w*2,1.1); ctx.fillStyle='rgba(255,255,255,.12)'; ctx.fillRect(-w,y+1.1,w*2,.8); }
	ctx.fillStyle='rgba(0,0,0,.18)'; ctx.fillRect(-w,y0,2.4,y1-y0); ctx.fillRect(w-2.4,y0,2.4,y1-y0);
	ctx.fillStyle='rgba(0,0,0,.28)'; ctx.fillRect(-.5,y1-26,1,26); ctx.fillRect(-w,y1-27,w*2,1);
	ctx.restore();
	for(let y=y0+20;y<y1-30;y+=48) for(const sd of [1,-1]){ rrect(ctx,sd*(p.W/2-1.6)-1.2,y-2.2,2.4,4.4,1); ctx.fillStyle='#e0a11b'; ctx.fill(); } }},
ambuBox:{layer:'paint',fn(C,s){ const p=C.sp.parts[1]; const sh=C.shells[1]; if(s!==sh) return; const ctx=C.ctx, y0=p.y0+p.rimF, y1=p.y1-p.rimR-(C.stage?C.dm.crushR:0), w=p.W/2-p.rim;
	ctx.save(); ringPath(ctx,sh.outer,sh.top); ctx.clip('evenodd'); ctx.fillStyle='#b8231d'; ctx.fillRect(-60,y0+8,120,y1-y0-16); ctx.restore();
	ctx.save(); poly(ctx,sh.top); ctx.clip(); ctx.strokeStyle='rgba(0,0,0,.16)'; ctx.lineWidth=.6; ctx.strokeRect(-w+4,y0+4,w*2-8,y1-y0-8); ctx.restore();
	const cy=(y0+y1)/2+10; ctx.fillStyle='#b8231d'; ctx.fillRect(-4.5,cy-15,9,30); ctx.fillRect(-15,cy-4.5,30,9);
	rrect(ctx,-13,y0+10,26,18,2); ctx.fillStyle=css(shade(C.look.base,-.12)); ctx.fill(); ctx.strokeStyle='rgba(0,0,0,.35)'; ctx.lineWidth=.6; ctx.stroke(); ctx.beginPath(); ctx.arc(0,y0+19,6,0,7); ctx.fillStyle='#2b2c2f'; ctx.fill(); ctx.strokeStyle='#55575b'; ctx.beginPath(); ctx.moveTo(-6,y0+19); ctx.lineTo(6,y0+19); ctx.moveTo(0,y0+13); ctx.lineTo(0,y0+25); ctx.stroke();
	rrect(ctx,-9,y1-30,18,14,1.5); ctx.fillStyle=css(shade(C.look.base,-.06)); ctx.fill(); ctx.strokeStyle='rgba(0,0,0,.3)'; ctx.stroke();
	const lamp=(x,y,c)=>{ rrect(ctx,x-3.5,y-2,7,4,1.4); ctx.fillStyle=c; ctx.fill(); ctx.fillStyle='rgba(255,255,255,.55)'; ctx.fillRect(x-2.5,y-1.4,3,1); };
	lamp(-w+3,y0+3,'#e3a21c'); lamp(w-3,y0+3,'#e3a21c'); lamp(-w+3,y1-3,'#c8221c'); lamp(w-3,y1-3,'#c8221c'); lamp(-6,y0+3,'#c8221c'); lamp(6,y0+3,'#2f64d8'); }}
};
function featList(sp){ const f=sp.feats.slice(); if(f.includes('stripes')) f.push('stripesRoof'); return f; }
function runLayer(C,list,layer,s){ for(const n of list){ const F=FEATS[n]; if(F&&F.layer===layer) F.fn(C,s||C.shells[0]); } }

/* ---------- weathering ---------- */
function weather(C){
	const ctx=C.ctx, N=noiseLayers(C.sp,C.res), st=C.style, g=C.sp.grime, W=boxOf(C.sp)[0], H=boxOf(C.sp)[1];
	const bodyClip=()=>{ ctx.beginPath(); for(const s of C.shells) poly(ctx,s.outer,true); };
	const paintClip=()=>{ ctx.beginPath(); for(const s of C.shells){ poly(ctx,s.outer,true); if(s.glass) poly(ctx,s.glass,true); if(s.roof) rrect(ctx,s.roof.x,s.roof.y,s.roof.w,s.roof.h,Math.min(9,s.roof.w*.22),true); } };
	if(st==='A'){
		ctx.save(); paintClip(); ctx.clip('evenodd');
		ctx.globalCompositeOperation='multiply'; ctx.drawImage(N.dirt,-W/2,-H/2,W,H);
		ctx.globalCompositeOperation='source-over'; ctx.globalAlpha=1; ctx.drawImage(N.fade,-W/2,-H/2,W,H);
		ctx.drawImage(N.moss,-W/2,-H/2,W,H); ctx.drawImage(N.speck,-W/2,-H/2,W,H);
		ctx.globalAlpha=.3; ctx.drawImage(N.rust,-W/2,-H/2,W,H); ctx.globalAlpha=1;
		ctx.restore();
		ctx.save(); ctx.beginPath(); for(const s of C.shells){ poly(ctx,s.outer,true); poly(ctx,shellPoly(Object.assign({},s.p,{rim:s.p.rim+8,rimF:s.p.rimF+9,rimR:s.p.rimR+9}),true,C.dm),true); } ctx.clip('evenodd');
		ctx.drawImage(N.rust,-W/2,-H/2,W,H); ctx.restore();
		ctx.save(); for(const s of C.shells){ ringPath(ctx,s.outer,s.top); } ctx.clip('evenodd'); ctx.globalCompositeOperation='multiply'; ctx.fillStyle='rgba(120,100,78,'+(.5*g.dirt)+')'; ctx.fillRect(-W/2,-H/2,W,H); ctx.restore();
		ctx.save(); for(const s of C.shells) if(s.glass){ poly(ctx,s.glass); ctx.clip(); ctx.globalCompositeOperation='screen'; ctx.globalAlpha=.4; ctx.drawImage(N.dirt,-W/2,-H/2,W,H); }
		ctx.restore();
		for(const s of C.shells){ ctx.save(); poly(ctx,s.top); ctx.clip(); ctx.globalCompositeOperation='multiply'; ctx.shadowColor='rgba(92,72,50,'+(.55+.4*g.dirt)+')'; ctx.shadowBlur=7*C.res;
			ctx.beginPath(); ctx.rect(-400,-400,800,800); poly(ctx,s.top,true); ctx.fillStyle='#000'; ctx.fill('evenodd'); ctx.restore(); }
		ctx.save(); bodyClip(); ctx.clip(); ctx.globalCompositeOperation='multiply';
		for(const [wy,wx,ww,wl] of C.sp.wheels) for(const sd of [1,-1]){ const gx=sd*(wx-2), gr=ctx.createRadialGradient(gx,wy,0,gx,wy,wl*.7); gr.addColorStop(0,'rgba(110,88,62,'+(.65*g.dirt)+')'); gr.addColorStop(1,'rgba(110,88,62,0)'); ctx.fillStyle=gr; ctx.fillRect(gx-wl,wy-wl,wl*2,wl*2); }
		ctx.restore();
		const r=rng(C.sp.seed+5); ctx.save(); paintClip(); ctx.clip('evenodd'); ctx.strokeStyle='rgba(235,230,215,.22)'; ctx.lineWidth=.4;
		for(let i=0;i<22;i++){ const x=(r()-.5)*90, y=(r()-.5)*(H-60), a=r()*Math.PI, l=3+r()*9; ctx.beginPath(); ctx.moveTo(x,y); ctx.lineTo(x+Math.cos(a)*l,y+Math.sin(a)*l*.4); ctx.stroke(); }
		ctx.restore();
	} else if(st==='B'){
		ctx.save(); paintClip(); ctx.clip('evenodd'); ctx.fillStyle='rgba(20,16,12,.32)';
		const r=rng(C.sp.seed+9);
		for(let y=-H/2;y<H/2;y+=2.4) for(let x=-W/2;x<W/2;x+=2.4){ const n=fbm((x+(y%4.8?1.2:0))*.045,y*.045,C.sp.seed,3); const k=clamp01((n-.5)*3.2)*g.dirt; if(k>.05){ ctx.beginPath(); ctx.arc(x+((y/2.4)%2?1.2:0),y,.95*k+.15,0,7); ctx.fill(); } }
		ctx.drawImage(N.rust,-W/2,-H/2,W,H); ctx.restore();
	}
}

/* ---------- damage overlays ---------- */
function crack(ctx,x,y,R,seed,rings){ const r=rng(seed); const n=6+Math.floor(r()*4); const arms=[];
	ctx.strokeStyle='rgba(225,232,238,.55)'; ctx.lineWidth=.32;
	for(let i=0;i<n;i++){ const a=i/n*6.283+r()*.5, l=R*(.6+r()*.5); let px=x,py=y; ctx.beginPath(); ctx.moveTo(px,py); const pts=[];
		for(let k=1;k<=4;k++){ const t=k/4; px=x+Math.cos(a+(r()-.5)*.5)*l*t*(.8+r()*.3); py=y+Math.sin(a+(r()-.5)*.5)*l*t*(.8+r()*.3); ctx.lineTo(px,py); pts.push([px,py]); } ctx.stroke(); arms.push(pts); }
	for(let k=0;k<rings;k++){ ctx.beginPath(); arms.forEach((pts,i)=>{ const q=pts[Math.min(3,k+1)]; if(i===0) ctx.moveTo(q[0],q[1]); else ctx.lineTo(q[0],q[1]); }); ctx.closePath(); ctx.stroke(); }
	ctx.beginPath(); ctx.arc(x,y,R*.09,0,7); ctx.fillStyle='rgba(225,232,238,.45)'; ctx.fill(); }
function dentMark(C,x,y,len,amp,side){ const ctx=C.ctx; ctx.save(); ctx.translate(x,y); ctx.scale(1,len/(2.5+amp));
	let g=ctx.createRadialGradient(0,0,0,0,0,2.5+amp); g.addColorStop(0,'rgba(0,0,0,'+(.18+amp*.06)+')'); g.addColorStop(1,'rgba(0,0,0,0)'); ctx.fillStyle=g; ctx.beginPath(); ctx.arc(0,0,2.5+amp,0,7); ctx.fill();
	g=ctx.createRadialGradient(-side*.8,-1.4,0,-side*.8,-1.4,(2.5+amp)*.7); g.addColorStop(0,'rgba(255,255,255,'+(.08+amp*.025)+')'); g.addColorStop(1,'rgba(255,255,255,0)'); ctx.fillStyle=g; ctx.beginPath(); ctx.arc(-side*.8,-1.4,(2.5+amp)*.7,0,7); ctx.fill(); ctx.restore(); }
function drawDamage(C){
	const ctx=C.ctx, st=C.stage, sp=C.sp, dm=C.dm, r=rng(sp.seed*3+st), N=noiseLayers(sp,C.res), W=boxOf(sp)[0], H=boxOf(sp)[1], ink=C.look.ink;
	const p=sp.parts[0], pl=sp.parts[sp.parts.length-1], main=C.shells[0];
	const bodyClip=()=>{ ctx.beginPath(); for(const s of C.shells) poly(ctx,s.outer,true); ctx.clip(); };
	ctx.save(); bodyClip();
	for(const d of dm.dents){ const part=sp.parts.find(q=>d.y>q.y0&&d.y<q.y1)||p; const x=d.side*(hwAt(part,d.y,false)-2.5-d.amp*.4); dentMark(C,x,d.y,d.len,d.amp,d.side); }
	if(st===2){ ctx.drawImage(N.rust2,-W/2,-H/2,W,H); }
	ctx.strokeStyle='rgba(222,220,212,.6)'; ctx.lineWidth=.45;
	for(let i=0;i<8*st;i++){ const sd=r()<.5?-1:1, y=p.y0+20+r()*(pl.y1-p.y0-40), part=sp.parts.find(q=>y>q.y0&&y<q.y1)||p, x=sd*(hwAt(part,y,false)-1-r()*6), l=4+r()*10; ctx.beginPath(); ctx.moveTo(x,y); ctx.lineTo(x-sd*r()*2,y+l); ctx.stroke(); }
	for(let i=0;i<5*st;i++){ const x=(r()-.5)*70, y=p.y0+10+r()*(pl.y1-p.y0-20); ctx.beginPath(); ctx.ellipse(x,y,.8+r()*1.6,.6+r()*1.2,r()*3,0,7); ctx.fillStyle=r()<.5?'rgba(150,146,136,.9)':'rgba(198,198,194,.9)'; ctx.fill(); }
	if(st===2){
		const sd=dm.skew>0?-1:1, a=p.y0+30, b=Math.min(pl.y1-30,a+95);
		ctx.beginPath(); for(let y=a;y<=b;y+=3){ const part=sp.parts.find(q=>y>q.y0&&y<q.y1)||p; ctx.lineTo(sd*(hwAt(part,y,false)+1),y); } for(let y=b;y>=a;y-=3){ const part=sp.parts.find(q=>y>q.y0&&y<q.y1)||p; ctx.lineTo(sd*(hwAt(part,y,false)-3.4-Math.sin(y*.3)*.8),y); } ctx.closePath();
		const g=ctx.createLinearGradient(sd*30,0,sd*46,0); g.addColorStop(0,'#8d9093'); g.addColorStop(1,'#d9dad8'); ctx.fillStyle=g; ctx.fill();
		ctx.strokeStyle='rgba(60,60,62,.6)'; ctx.lineWidth=.35; for(let k=0;k<5;k++){ ctx.beginPath(); const xo=sd*(hwAt(p,a+30,false)-.6-k*.6); ctx.moveTo(xo,a+5); ctx.lineTo(xo,b-5); ctx.stroke(); }
		const fy=p.y0+dm.crushF, ry=pl.y1-dm.crushR;
		const soot=(x,y,rad,al)=>{ ctx.save(); const g=ctx.createRadialGradient(x,y,0,x,y,rad); g.addColorStop(0,'rgba(0,0,0,1)'); g.addColorStop(1,'rgba(0,0,0,0)'); ctx.fillStyle=g; ctx.globalAlpha=al; ctx.fillRect(x-rad,y-rad,rad*2,rad*2);
			ctx.globalCompositeOperation='destination-out'; ctx.restore(); };
		if(p.front) soot(0,fy+16,30,.55); soot(dm.skew*20,ry-10,22,.4); soot(-sd*20,(p.y0+pl.y1)/2,16,.3);
		ctx.save(); ctx.beginPath(); if(p.front) ctx.ellipse(0,fy+14,40,34,0,0,7); ctx.ellipse(dm.skew*20,ry-6,36,26,0,0,7); ctx.clip(); ctx.globalCompositeOperation='multiply'; ctx.globalAlpha=.5; ctx.drawImage(N.soot,-W/2,-H/2,W,H); ctx.restore();
		if(!p.box){ const hw=hwAt(p,fy+14,true); ctx.lineCap='round';
			for(let k=0;k<2;k++){ const y=fy+13+k*12+r()*3; const pts=[]; let yy=y; for(let x=-hw*.9;x<=hw*.9;x+=hw/5){ yy=y+(r()-.5)*7*(1-k*.3)+(x<0?-x:x)*.06*(k?1:-1); pts.push([x,yy]); }
				ctx.beginPath(); pts.forEach((q,i)=>i?ctx.lineTo(q[0],q[1]):ctx.moveTo(q[0],q[1])); ctx.strokeStyle='rgba(0,0,0,.5)'; ctx.lineWidth=1.6; ctx.stroke();
				ctx.beginPath(); pts.forEach((q,i)=>i?ctx.lineTo(q[0]+.6,q[1]+1):ctx.moveTo(q[0]+.6,q[1]+1)); ctx.strokeStyle='rgba(255,255,255,.22)'; ctx.lineWidth=.7; ctx.stroke(); }
			const hp=[]; const hx=hw*.55; for(let i=0;i<=10;i++){ const t=i/10; hp.push([-hx+t*2*hx,fy-1]); } for(let i=0;i<=10;i++){ const t=1-i/10; hp.push([-hx+t*2*hx,fy+7+r()*7*Math.sin(t*3.14)]); }
			poly(ctx,hp); ctx.fillStyle='#141312'; ctx.fill();
			ctx.save(); poly(ctx,hp); ctx.clip(); ctx.strokeStyle='#5c5f63'; ctx.lineWidth=.6; for(let x=-hx;x<hx;x+=1.5){ ctx.beginPath(); ctx.moveTo(x,fy); ctx.lineTo(x,fy+5); ctx.stroke(); } ctx.fillStyle='#3a3836'; ctx.fillRect(-5,fy+6,10,6); ctx.restore();
		}
		if(p.trunk){ const ty=p.cabin.wr+p.cabin.bowR+3; ctx.strokeStyle='#0c0c0c'; ctx.lineWidth=1.8; ctx.beginPath(); ctx.moveTo(-hwAt(p,ty,true)+3,ty); ctx.lineTo(hwAt(p,ty,true)-3,ty+dm.skew*3); ctx.stroke();
			ctx.fillStyle='rgba(255,255,255,.08)'; ctx.fillRect(-30,ty+1,60,10); }
		if(p.filler){ const [fs,fy2]=p.filler, x=fs*(hwAt(p,fy2,false)+hwAt(p,fy2,true))/2; ctx.beginPath(); ctx.arc(x,fy2,2,0,7); ctx.fillStyle='#050505'; ctx.fill();
			const g2=ctx.createRadialGradient(x,fy2+6,0,x,fy2+6,9); g2.addColorStop(0,'rgba(30,24,40,.7)'); g2.addColorStop(.6,'rgba(60,40,70,.35)'); g2.addColorStop(1,'rgba(0,0,0,0)'); ctx.fillStyle=g2; ctx.beginPath(); ctx.ellipse(x,fy2+7,5,10,0,0,7); ctx.fill(); }
		for(const s of C.shells){ const q=s.p; if(!q.box) continue; const hw=q.W/2-q.rim; ctx.strokeStyle='rgba(0,0,0,.4)'; ctx.lineWidth=1.2; ctx.beginPath(); ctx.moveTo(-hw*.7,ry-12); ctx.lineTo(0,ry-20); ctx.lineTo(hw*.6,ry-11); ctx.stroke(); ctx.strokeStyle='rgba(255,255,255,.2)'; ctx.lineWidth=.6; ctx.beginPath(); ctx.moveTo(-hw*.7,ry-11); ctx.lineTo(0,ry-19); ctx.lineTo(hw*.6,ry-10); ctx.stroke(); }
	}
	ctx.restore();
	/* glass */
	for(const s of C.shells){ if(!s.glass) continue; const c=s.p.cabin; ctx.save(); poly(ctx,s.glass); ctx.clip();
		if(st===1) crack(ctx,dm.skew*30,c.wf+4,9,sp.seed,1);
		if(st===2){ ctx.fillStyle='rgba(200,206,210,.12)'; ctx.fillRect(-60,c.wf-10,120,c.rf-c.wf+10); crack(ctx,dm.skew*24,c.wf+3,20,sp.seed,2); crack(ctx,-dm.skew*20,c.wf+7,9,sp.seed+1,1);
			if(c.wr>c.rr+2){ ctx.fillStyle='rgba(6,6,7,.8)'; ctx.beginPath(); ctx.ellipse(dm.skew*-14,c.wr-2,9,5,0,0,7); ctx.fill(); crack(ctx,dm.skew*-14,c.wr-2,12,sp.seed+3,1); }
			for(const sd of [1,-1]){ ctx.fillStyle='rgba(8,8,9,.7)'; ctx.fillRect(sd>0?s.roof.x+s.roof.w:-60,c.rf+6,60+s.roof.x,c.rr-c.rf-12); } }
		ctx.restore();
		if(st===2&&s.roof){ const r2=s.roof; ctx.save(); rrect(ctx,r2.x,r2.y,r2.w,r2.h,6); ctx.clip(); dentMark(C,r2.x+r2.w*.62,r2.y+r2.h*.45,r2.h*.32,5,1); ctx.strokeStyle='rgba(0,0,0,.35)'; ctx.lineWidth=1; ctx.beginPath(); ctx.moveTo(r2.x,r2.y+r2.h*.3); ctx.lineTo(r2.x+r2.w*.55,r2.y+r2.h*.5); ctx.lineTo(r2.x+r2.w,r2.y+r2.h*.42); ctx.stroke(); ctx.restore(); }
	}
	/* lamps */
	const P=C.lightPos;
	if(P){ if(st>=1&&P.f.length){ const [x,y]=P.f[dm.skew>0?0:P.f.length-1]; ctx.strokeStyle='rgba(30,30,30,.7)'; ctx.lineWidth=.35; ctx.beginPath(); ctx.moveTo(x-2.5,y-1); ctx.lineTo(x+1,y+.5); ctx.lineTo(x+2,y-2); ctx.moveTo(x,y); ctx.lineTo(x-1,y+2.4); ctx.stroke(); }
		if(st===2){ for(const [x,y] of P.f){ ctx.beginPath(); ctx.arc(x,y,3.4,0,7); ctx.fillStyle='#0b0b0c'; ctx.fill(); ctx.fillStyle='rgba(230,235,240,.7)'; for(let k=0;k<3;k++){ ctx.beginPath(); const a=r()*6.28; ctx.moveTo(x+Math.cos(a)*3,y+Math.sin(a)*3); ctx.lineTo(x+Math.cos(a+.4)*1,y+Math.sin(a+.4)*1); ctx.lineTo(x+Math.cos(a+.7)*3,y+Math.sin(a+.7)*3); ctx.fill(); } }
			for(const [x,y] of P.r){ ctx.fillStyle='rgba(20,6,6,.85)'; ctx.fillRect(x-4,y-2,8,4); ctx.fillStyle='rgba(200,40,30,.8)'; ctx.fillRect(x-4,y-2,2.5,2); } } }
	/* shredded tyres */
	if(st===2){ for(const [y,x,w,l] of sp.wheels) for(const sd of [1,-1]){ const cx=sd*(x+w/2-1); ctx.fillStyle='#17161a'; for(let k=0;k<5;k++){ const yy=y-l/2+r()*l; ctx.beginPath(); ctx.moveTo(cx,yy); ctx.lineTo(cx+sd*(1.5+r()*3),yy+1+r()*2); ctx.lineTo(cx,yy+3); ctx.fill(); }
		ctx.fillStyle='#8d9094'; ctx.fillRect(cx-sd*.4-.6,y-l*.3,1.2,l*.6); } }
	if(ink){ ctx.save(); bodyClip(); ctx.restore(); }
}

/* ---------- main render ---------- */
function render(key,o){
	const sp=CARS[key], res=o.res||2, cv=document.createElement('canvas');
	cv.width=Math.round(boxOf(sp)[0]*res); cv.height=Math.round(boxOf(sp)[1]*res);
	const ctx=cv.getContext('2d'); ctx.setTransform(res,0,0,res,cv.width/2,cv.height/2); ctx.lineJoin='round';
	const stage=o.stage||0, dm=makeDamage(sp,stage);
	const C={sp,res,ctx,stage,dm,style:o.style||'A',look:makeLook(sp,o.style||'A')};
	C.shells=sp.parts.map(p=>({p,outer:shellPoly(p,false,dm),top:shellPoly(p,true,dm)}));
	const feats=featList(sp);
	if(o.shadow!==false) drawShadow(C); drawWheels(C); drawBumpers(C); runLayer(C,feats,'under');
	C.shells.forEach((s)=>{ drawBody(C,s); runLayer(C,feats,'paint',s); drawPanels(C,s); if(s.p.cabin) drawCabin(C,s); inkOutline(C,s); });
	drawLights(C); drawMirrors(C); runLayer(C,feats,'roof'); runLayer(C,feats,'over');
	weather(C);
	if(stage) drawDamage(C);
	return cv;
}

/* ---------- zone mask: which system each pixel belongs to and how far damage must spread to reach it ---------- */
const ZONES=['hull','lights','engine','steering','tires','tank'];
function zoneMask(key,res){
	const sp=CARS[key], w=Math.round(boxOf(sp)[0]*res), h=Math.round(boxOf(sp)[1]*res), zone=new Uint8Array(w*h), prog=new Float32Array(w*h);
	const y0=sp.parts[0].y0, y1=sp.parts[sp.parts.length-1].y1, yc=(y0+y1)/2, hl=(y1-y0)/2, W2=Math.max(...sp.parts.map(p=>p.W))/2;
	for(let j=0;j<h;j++) for(let i=0;i<w;i++){
		const x=(i-w/2)/res, y=(j-h/2)/res, u=x/W2, v=(y-yc)/hl, n1=(fbm(x*.07,y*.07,sp.seed+101,3)-.5)*.34, n2=(fbm(x*.25,y*.25,sp.seed+202,2)-.5)*.22;
		const vv=v+n1, uu=Math.abs(u)+n1*.7, au=Math.abs(u); let z, pr;
		if(sp.zones==='trailer') z=vv>.35&&uu>.55?4:0;
		else if(vv<-.64) { z=uu>.4?1:2; }
		else if(vv>.68) z=5;
		else if(uu>.62) z=vv<.02?3:4;
		else if(vv<-.3) z=2;
		else z=0;
		if(pr==null){
			if(z===1) pr=Math.hypot(au-.75,(v+1)*1.4)/.75;
			else if(z===2) pr=(v+1)/.72*.85+au*.2;
			else if(z===3) pr=Math.hypot(au-1,(v+.4)*.9)/.7;
			else if(z===4) pr=Math.hypot(au-1,(v-.36)*.9)/.7;
			else if(z===5) pr=(1-v)/.34;
			else pr=1-clamp01(fbm(x*.05,y*.05,sp.seed+303,3)*1.7-.35);
		}
		zone[j*w+i]=z; prog[j*w+i]=clamp01(pr+n2);
	}
	return {w,h,zone,prog};
}
/* compose the three stage sheets the way the in-game shader does */
function compose(out,sheets,mask,dmg){
	const w=mask.w, h=mask.h, o=out.getContext('2d'), id=o.createImageData(w,h), d=id.data, a=sheets[0], b=sheets[1], c=sheets[2];
	const dent=ZONES.map(z=>dmg[z]*1.6), wreck=ZONES.map(z=>(dmg[z]-.35)*1.55);
	for(let k=0,n=w*h;k<n;k++){ const z=mask.zone[k], pr=mask.prog[k], src=pr<wreck[z]?c:pr<dent[z]?b:a, q=k*4; d[q]=src[q]; d[q+1]=src[q+1]; d[q+2]=src[q+2]; d[q+3]=src[q+3]; }
	o.putImageData(id,0,0);
}
function geom(key){ const sp=CARS[key], p=sp.parts[0], pl=sp.parts[sp.parts.length-1], r=p.cabin?roofRect(p):null, L=lightPositions({sp,stage:0,dm:makeDamage(sp,0)}); let filler=null;
	for(const q of sp.parts) if(q.filler){ const [sd,fy]=q.filler; filler=[sd*(hwAt(q,fy,false)+hwAt(q,fy,true))/2,fy]; }
	return {roof:r, front:p.y0, rear:pl.y1, filler, wheels:sp.wheels, f:L.f, r:L.r, W:Math.max(...sp.parts.map(q=>q.W)), box:sp.parts[1]&&sp.parts[1].box?sp.parts[1]:null}; }
/* the soft shadow on its own: centred, so it reads right whichever way the car turns */
function renderShadow(key,res){
	const sp=CARS[key], cv=document.createElement('canvas'); cv.width=Math.round(boxOf(sp)[0]*res); cv.height=Math.round(boxOf(sp)[1]*res);
	const ctx=cv.getContext('2d'); ctx.setTransform(res,0,0,res,cv.width/2,cv.height/2);
	const C={sp,res,ctx,stage:0,dm:makeDamage(sp,0)}; C.shells=sp.parts.map(p=>({p,outer:shellPoly(p,false,null)}));
	const off=4000; ctx.shadowColor='rgba(0,0,0,.75)'; ctx.shadowBlur=8*res; ctx.shadowOffsetX=off*res; ctx.translate(-off,0); ctx.fillStyle='#000';
	for(const s of C.shells){ ctx.save(); ctx.translate(0,0); ctx.scale(1.04,1.02); poly(ctx,s.outer); ctx.fill(); ctx.restore(); }
	for(const [y,x,w,l] of sp.wheels) for(const sd of [1,-1]){ rrect(ctx,sd*x-w/2,y-l/2,w,l,2.6); ctx.fill(); }
	return cv;
}
/* zone mask as pixels: R = system id * 51, G = spread distance * 255 (what car_damage.gdshader reads) */
function maskCanvas(key,res){
	const m=zoneMask(key,res), cv=document.createElement('canvas'); cv.width=m.w; cv.height=m.h; const g=cv.getContext('2d'), id=g.createImageData(m.w,m.h), d=id.data;
	for(let k=0;k<m.w*m.h;k++){ d[k*4]=m.zone[k]*51; d[k*4+1]=Math.round(m.prog[k]*255); d[k*4+2]=0; d[k*4+3]=255; }
	g.putImageData(id,0,0); return cv;
}
/* geometry for the car scene, in car space (x forward, y to the car's right): silhouette, wheels, exhaust */
function sceneGeometry(key){
	const sp=CARS[key], toCar=([x,y])=>[-y,x], outline=[];
	for(const p of sp.parts) for(const q of shellPoly(p,false,null)) outline.push(toCar(q)); /* only for the bounds */
	const g=geom(key); const xs=outline.map(q=>q[0]), ys=outline.map(q=>q[1]);
	const front=Math.max(...xs)+3, rear=Math.min(...xs)-3, half=Math.max(...ys);
	const wheels=sp.wheels.map(([y,x])=>[x,y]);
	/* bumper shapes like the old scenes': the front 55 px of the first part, the rear 35 px of the last */
	const carPoly=p=>shellPoly(p,false,null).map(toCar);
	const clip=(pts,keep)=>{ const out=[]; for(let i=0;i<pts.length;i++){ const a=pts[i], b=pts[(i+1)%pts.length], ka=keep(a[0]), kb=keep(b[0]);
		if(ka) out.push(a); if(ka!==kb){ const cut=ka?b:a, t=(keep.cut-a[0])/(b[0]-a[0]); out.push([keep.cut,a[1]+(b[1]-a[1])*t]); } } return out; };
	const simplify=(pts,eps)=>{ if(pts.length<4) return pts; let best=0, idx=0; const [a,b]=[pts[0],pts[pts.length-1]];
		for(let i=1;i<pts.length-1;i++){ const d=Math.abs((b[0]-a[0])*(a[1]-pts[i][1])-(a[0]-pts[i][0])*(b[1]-a[1]))/Math.max(1e-6,Math.hypot(b[0]-a[0],b[1]-a[1])); if(d>best){ best=d; idx=i; } }
		return best>eps?simplify(pts.slice(0,idx+1),eps).slice(0,-1).concat(simplify(pts.slice(idx),eps)):[a,b]; };
	const simplifyClosed=(pts,eps)=>{ let far=0, fd=0; pts.forEach((q,i)=>{ const d=Math.hypot(q[0]-pts[0][0],q[1]-pts[0][1]); if(d>fd){ fd=d; far=i; } });
		const one=simplify(pts.slice(0,far+1),eps), two=simplify(pts.slice(far).concat([pts[0]]),eps);
		const out=one.slice(0,-1).concat(two.slice(0,-1)); return out.filter((q,i)=>{ const n=out[(i+1)%out.length]; return Math.hypot(q[0]-n[0],q[1]-n[1])>.3; }); };
	const round=pts=>pts.map(q=>[Math.round(q[0]*10)/10,Math.round(q[1]*10)/10]);
	const fp=carPoly(sp.parts[0]), fx=Math.max(...fp.map(q=>q[0])), kf=x=>x>=kf.cut; kf.cut=fx-55;
	const rp=carPoly(sp.parts[sp.parts.length-1]), rx=Math.min(...rp.map(q=>q[0])), kr=x=>x<=kr.cut; kr.cut=rx+35;
	const frontPoly=round(simplifyClosed(clip(fp,kf),.8)), rearPoly=round(simplifyClosed(clip(rp,kr),.8));
	/* where the damage FX come from, in car space */
	const hood=[g.front*-1-26,0], tank=g.filler?toCar(g.filler):[-(g.rear-12),0], fw=sp.wheels[0];
	return {front, rear, half, wheels, exhaust:sp.feats.includes('stacks')?[36,sp.stacksY]:[-g.W*.22,g.rear+6], frontPoly, rearPoly, hood, tank, frontWheel:[-fw[0],fw[1]+fw[2]/2], box:boxOf(sp)};
}
window.CarArt={geom,renderShadow,maskCanvas,sceneGeometry,CARS,ORDER,ZONES,BOX_W,BOX_H,render,zoneMask,compose,lightPositions:(key,stage)=>{ const sp=CARS[key]; return lightPositions({sp,stage:stage||0,dm:makeDamage(sp,stage||0)}); },hwAt};
})();
