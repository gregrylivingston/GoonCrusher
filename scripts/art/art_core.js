/* GoonCrusher shared art helpers: seeded random, integer hash, value noise, fbm, colour maths, overhead-lit
   volumes, the grime pattern and the alpha-mask convex hull. Copied from car_gen.js and goon_gen.js (which keep
   their own copies so their output never changes) and extended with periodic noise so ground tiles and edge
   strips are seamless. Used by world_gen.js (docs/WORLD_ART.md). Pure: no Math.random, no Date. */
(function(){
"use strict";
const TAU=Math.PI*2;

/* ---------- maths and noise (identical to car_gen.js / goon_gen.js) ---------- */
function rng(seed){ let s=(seed>>>0)||1; return ()=>{ s^=s<<13; s>>>=0; s^=s>>17; s^=s<<5; s>>>=0; return s/4294967296; }; }
function hash2(x,y,seed){ let h=(Math.imul(x,374761393)+Math.imul(y,668265263)+Math.imul(seed,1442695041))|0; h=Math.imul(h^(h>>>13),1274126177); return ((h^(h>>>16))>>>0)/4294967296; }
function wrapi(i,p){ return p?((i%p)+p)%p:i; }
/* value noise; px/py (optional, integers) make the lattice wrap so the noise repeats every px/py units */
function vnoise(x,y,seed,px,py){ const xi=Math.floor(x), yi=Math.floor(y), xf=x-xi, yf=y-yi; const u=xf*xf*(3-2*xf), v=yf*yf*(3-2*yf);
	const x0=wrapi(xi,px), x1=wrapi(xi+1,px), y0=wrapi(yi,py), y1=wrapi(yi+1,py);
	const a=hash2(x0,y0,seed), b=hash2(x1,y0,seed), c=hash2(x0,y1,seed), d=hash2(x1,y1,seed); return a+(b-a)*u+(c-a)*v+(a-b-c+d)*u*v; }
/* fbm; without a period it matches the car/goon generators (lacunarity 2.03). With a period (lattice units across
   the tile, integer) every octave doubles exactly and wraps, so the result tiles. periodY defaults to periodX;
   pass 0 for no wrap on that axis (edge strips wrap in x only). */
function fbm(x,y,seed,oct,period,periodY){ oct=oct||4; let f=0,amp=.5,fr=1,n=0;
	if(!period&&!periodY){ for(let i=0;i<oct;i++){ f+=amp*vnoise(x*fr,y*fr,seed+i*17); n+=amp; amp*=.5; fr*=2.03; } return f/n; }
	const py=periodY==null?period:periodY;
	for(let i=0;i<oct;i++){ f+=amp*vnoise(x*fr,y*fr,seed+i*17,period?period*fr:0,py?py*fr:0); n+=amp; amp*=.5; fr*=2; } return f/n; }
/* periodic cellular noise: f1/f2 = nearest and second nearest feature distance in cell units, id = nearest cell hash */
function worley(x,y,seed,px,py){ const xi=Math.floor(x), yi=Math.floor(y); let f1=9,f2=9,id=0;
	for(let j=-1;j<=1;j++) for(let i=-1;i<=1;i++){ const cx=xi+i, cy=yi+j, wx=wrapi(cx,px), wy=wrapi(cy,py);
		const fx=cx+hash2(wx,wy,seed), fy=cy+hash2(wx,wy,seed+7), d=Math.hypot(fx-x,fy-y);
		if(d<f1){ f2=f1; f1=d; id=hash2(wx,wy,seed+13); } else if(d<f2) f2=d; }
	return {f1,f2,id}; }
function smooth(a,b,x){ const t=Math.min(1,Math.max(0,(x-a)/(b-a))); return t*t*(3-2*t); }
function ease(t){ return smooth(0,1,t); }
function lerp(a,b,t){ return a+(b-a)*t; }
function clamp01(x){ return x<0?0:x>1?1:x; }

/* ---------- colour ---------- */
function hexRgb(h){ h=h.replace('#',''); const n=parseInt(h,16); return [n>>16&255,n>>8&255,n&255]; }
function mixc(a,b,t){ return [a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t]; }
function css(c,a){ return 'rgba('+(c[0]|0)+','+(c[1]|0)+','+(c[2]|0)+','+(a==null?1:a)+')'; }
function shade(c,t){ return t<0?mixc(c,[0,0,0],-t):mixc(c,[255,255,255],t); }
function sat(c,t){ const g=(c[0]+c[1]+c[2])/3; return [g+(c[0]-g)*t,g+(c[1]-g)*t,g+(c[2]-g)*t].map(v=>Math.max(0,Math.min(255,v))); }
function C(h){ return typeof h==='string'?hexRgb(h):h; }

/* ---------- drawing (goon_gen.js vocabulary) ---------- */
function ell(ctx,x,y,rx,ry,rot){ ctx.beginPath(); ctx.ellipse(x,y,Math.max(.01,rx),Math.max(.01,ry),rot||0,0,TAU); }
function rr(ctx,x,y,w,h,r){ r=Math.min(r,w/2,h/2); ctx.moveTo(x+r,y); ctx.arcTo(x+w,y,x+w,y+h,r); ctx.arcTo(x+w,y+h,x,y+h,r); ctx.arcTo(x,y+h,x,y,r); ctx.arcTo(x,y,x+w,y,r); ctx.closePath(); }
/* overhead-lit volume: bright crown, dark rim */
function vol(ctx,x,y,rx,ry,col,o){ o=o||{}; col=C(col); ell(ctx,x,y,rx,ry,o.rot); const r=Math.max(rx,ry);
	const g=ctx.createRadialGradient(x,y-ry*(o.fy==null?.12:o.fy),r*.04,x,y,r*1.06);
	g.addColorStop(0,css(shade(col,o.hi==null?.24:o.hi))); g.addColorStop(.55,css(col)); g.addColorStop(1,css(shade(col,o.lo==null?-.42:o.lo))); ctx.fillStyle=g; ctx.fill(); }
function polyPath(ctx,pts){ ctx.beginPath(); ctx.moveTo(pts[0][0],pts[0][1]); for(let i=1;i<pts.length;i++) ctx.lineTo(pts[i][0],pts[i][1]); ctx.closePath(); }
function polyVol(ctx,pts,cx,cy,r,col,o){ o=o||{}; col=C(col); polyPath(ctx,pts);
	const g=ctx.createRadialGradient(cx,cy-r*.12,r*.05,cx,cy,r*1.1); g.addColorStop(0,css(shade(col,o.hi==null?.22:o.hi))); g.addColorStop(.55,css(col)); g.addColorStop(1,css(shade(col,o.lo==null?-.45:o.lo))); ctx.fillStyle=g; ctx.fill(); }
function limb(ctx,a,b,w,col){ col=C(col); ctx.lineCap='round'; ctx.beginPath(); ctx.moveTo(a[0],a[1]); ctx.lineTo(b[0],b[1]); ctx.strokeStyle=css(shade(col,-.4)); ctx.lineWidth=w; ctx.stroke();
	ctx.beginPath(); ctx.moveTo(a[0],a[1]); ctx.lineTo(b[0],b[1]); ctx.strokeStyle=css(col); ctx.lineWidth=w*.6; ctx.stroke(); }
function rust(ctx,x,y,r,seed){ const R=rng(seed); for(let i=0;i<3;i++){ ell(ctx,x+(R()-.5)*r*1.4,y+(R()-.5)*r*1.4,r*(.18+R()*.22),r*(.14+R()*.2),R()*3); ctx.fillStyle='rgba(122,62,30,'+(.35+R()*.3)+')'; ctx.fill(); } }
/* the boulder goon's faceted rock (goon_gen.js facetRock), so real rocks and the Boulder goon match */
function facetRock(ctx,x,y,r,col,seed,base,o){ o=o||{}; const Rr=rng(seed), N=base?base.length:9, pts=[]; for(let i=0;i<N;i++){ const a=i/N*TAU+Rr()*.2, k=base?base[i]:(.85+Rr()*.3); pts.push([x+Math.cos(a)*r*k*(o.sx||1),y+Math.sin(a)*r*k*(o.sy||1)]); }
	polyVol(ctx,pts,x,y,r,col,{hi:.2,lo:-.5}); for(let i=0;i<N;i++){ const a=pts[i], b=pts[(i+1)%N]; ctx.beginPath(); ctx.moveTo(x+(a[0]-x)*.35,y+(a[1]-y)*.35); ctx.lineTo(a[0],a[1]); ctx.lineTo(b[0],b[1]); ctx.closePath();
		ctx.fillStyle=Rr()>.5?'rgba(255,255,255,.07)':'rgba(0,0,0,.12)'; ctx.fill(); }
	if(o.lichen!==false){ ctx.fillStyle=o.lichen||'rgba(110,130,80,.35)'; for(let i=0;i<3;i++){ ell(ctx,x+(Rr()-.5)*r,y+(Rr()-.5)*r,r*.18,r*.12); ctx.fill(); } }
	return pts; }
/* the Scrap Gang tyre (goon_gen.js tire) */
function tire(ctx,x,y,w,h,t,spin){ ctx.save(); ctx.beginPath(); rr(ctx,x-w/2,y-h/2,w,h,Math.min(w,h)*.32); ctx.fillStyle='#1b1a1c'; ctx.fill(); ctx.clip();
	ctx.strokeStyle='rgba(120,118,115,.5)'; ctx.lineWidth=Math.max(.6,h*.07); const step=h/4, off=((t*spin)%1)*step; for(let y2=y-h/2-step+off;y2<y+h/2+step;y2+=step){ ctx.beginPath(); ctx.moveTo(x-w/2,y2); ctx.lineTo(x+w/2,y2+step*.35); ctx.stroke(); } ctx.restore(); }

/* ---------- grime ---------- */
/* goon_gen.js's 128 px grime (not seamless; kept for parity) and a periodic twin for tiled world art */
let GRIME=null, GRIME_T=null;
function grime(){ if(GRIME) return GRIME; const n=128, c=document.createElement('canvas'); c.width=c.height=n; const x=c.getContext('2d'), im=x.createImageData(n,n);
	for(let y=0;y<n;y++) for(let i=0;i<n;i++){ const f=fbm(i/11,y/11,7,4), s=hash2(i,y,3), o=(y*n+i)*4; const a=smooth(.5,.82,f)*120+(s>.94?70:0);
		im.data[o]=46; im.data[o+1]=34; im.data[o+2]=24; im.data[o+3]=a; } x.putImageData(im,0,0); GRIME=c; return c; }
function grimeTile(){ if(GRIME_T) return GRIME_T; const n=128, P=12, c=document.createElement('canvas'); c.width=c.height=n; const x=c.getContext('2d'), im=x.createImageData(n,n);
	for(let y=0;y<n;y++) for(let i=0;i<n;i++){ const f=fbm(i/n*P,y/n*P,7,4,P), s=hash2(i,y,3), o=(y*n+i)*4; const a=smooth(.5,.82,f)*120+(s>.94?70:0);
		im.data[o]=46; im.data[o+1]=34; im.data[o+2]=24; im.data[o+3]=a; } x.putImageData(im,0,0); GRIME_T=c; return c; }

/* ---------- hull ---------- */
/* convex hull of the pixels with alpha > cut (the soft shadow stays below it), reduced to at most max vertices by
   dropping the vertex that removes the least area, returned in game px around the canvas centre (bake_goons.html) */
function hull(cv,res,o){ o=o||{}; const cut=o.cut==null?140:o.cut, max=o.max||10, w=cv.width, h=cv.height, data=cv.getContext('2d').getImageData(0,0,w,h).data, pts=[];
	for(let y=0;y<h;y++){ let first=-1,last=-1; for(let x=0;x<w;x++) if(data[(y*w+x)*4+3]>cut){ if(first<0) first=x; last=x; } if(first>=0){ pts.push([first,y]); pts.push([last+1,y]); pts.push([first,y+1]); pts.push([last+1,y+1]); } }
	if(pts.length<3) return [];
	pts.sort((a,b)=>a[0]-b[0]||a[1]-b[1]);
	const cross=(o2,a,b)=>(a[0]-o2[0])*(b[1]-o2[1])-(a[1]-o2[1])*(b[0]-o2[0]);
	const lower=[], upper=[];
	for(const p of pts){ while(lower.length>=2&&cross(lower[lower.length-2],lower[lower.length-1],p)<=0) lower.pop(); lower.push(p); }
	for(let i=pts.length-1;i>=0;i--){ const p=pts[i]; while(upper.length>=2&&cross(upper[upper.length-2],upper[upper.length-1],p)<=0) upper.pop(); upper.push(p); }
	let poly=lower.slice(0,-1).concat(upper.slice(0,-1));
	const area=(a,b,c)=>Math.abs(cross(a,b,c))/2;
	while(poly.length>max){ let best=0,bestA=Infinity;
		for(let i=0;i<poly.length;i++){ const a=area(poly[(i+poly.length-1)%poly.length],poly[i],poly[(i+1)%poly.length]); if(a<bestA){ bestA=a; best=i; } }
		poly.splice(best,1); }
	return poly.map(p=>[+((p[0]-w/2)/res).toFixed(1),+((p[1]-h/2)/res).toFixed(1)]);
}
/* bounding box of the pixels with alpha > cut, in game px around the centre */
function bounds(cv,res,cut){ cut=cut==null?140:cut; const w=cv.width,h=cv.height,d=cv.getContext('2d').getImageData(0,0,w,h).data; let x0=w,y0=h,x1=-1,y1=-1;
	for(let y=0;y<h;y++) for(let x=0;x<w;x++) if(d[(y*w+x)*4+3]>cut){ if(x<x0)x0=x; if(x>x1)x1=x; if(y<y0)y0=y; if(y>y1)y1=y; }
	if(x1<0) return [0,0]; return [Math.round((x1-x0+1)/res),Math.round((y1-y0+1)/res)]; }

function canvas(w,h){ const c=document.createElement('canvas'); c.width=w; c.height=h; return c; }

window.ArtCore={TAU,rng,hash2,vnoise,fbm,worley,smooth,ease,lerp,clamp01,hexRgb,mixc,css,shade,sat,C,ell,rr,vol,polyPath,polyVol,limb,rust,facetRock,tire,grime,grimeTile,hull,bounds,canvas};
})();
