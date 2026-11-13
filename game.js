import * as THREE from 'https://unpkg.com/three@0.160.1/build/three.module.js';

const $ = (id) => document.getElementById(id);
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x91b8ca);
scene.fog = new THREE.Fog(0x91b8ca, 24, 62);
const camera = new THREE.PerspectiveCamera(76, innerWidth / innerHeight, 0.1, 100);
const renderer = new THREE.WebGLRenderer({ antialias: false, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(devicePixelRatio || 1, 1.5));
renderer.setSize(innerWidth, innerHeight);
renderer.outputColorSpace = THREE.SRGBColorSpace;
$('game').prepend(renderer.domElement);

scene.add(new THREE.HemisphereLight(0xe4f6ff, 0x34402a, 2.0));
const sun = new THREE.DirectionalLight(0xffe6c1, 2.4);
sun.position.set(-7, 14, 8);
scene.add(sun);
const ground = new THREE.Mesh(new THREE.PlaneGeometry(90, 90), new THREE.MeshStandardMaterial({ color: 0x52644a, roughness: 1 }));
ground.rotation.x = -Math.PI / 2;
scene.add(ground);
const grid = new THREE.GridHelper(80, 40, 0x879879, 0x718064);
grid.position.y = 0.015;
scene.add(grid);

const player = new THREE.Group();
scene.add(player);
const pivot = new THREE.Object3D();
pivot.position.y = 1.55;
player.add(pivot);
pivot.add(camera);
const raycaster = new THREE.Raycaster();
const enemyGroup = new THREE.Group();
scene.add(enemyGroup);
const enemies = [];
const clock = new THREE.Clock();
const state = { running:false, over:false, health:100, score:0, wave:1, ammo:12, maxAmmo:12, yaw:0, pitch:0, fireAt:0, reloadUntil:0, waveDelay:0 };
const input = { x:0, y:0, firing:false, joyId:null, lookId:null, lookX:0, lookY:0 };

// Simple cover pillars around the arena.
const coverMat = new THREE.MeshStandardMaterial({ color:0x85745b, roughness:.9 });
for(let i=0;i<8;i++){
  const a=i*Math.PI/4, r=10;
  const block=new THREE.Mesh(new THREE.BoxGeometry(1.7,2.1,1.7),coverMat);
  block.position.set(Math.cos(a)*r,1.05,Math.sin(a)*r);
  scene.add(block);
}

function hud(){ $('health').textContent=Math.ceil(state.health); $('score').textContent=state.score; $('wave').textContent=state.wave; $('ammo').textContent=`${state.ammo} / ${state.maxAmmo}`; }
let toastTimer;
function toast(text){ const el=$('toast');el.textContent=text;el.classList.add('show');clearTimeout(toastTimer);toastTimer=setTimeout(()=>el.classList.remove('show'),1100); }
function makeEnemy(){
  const material=new THREE.MeshStandardMaterial({color:0xc6453c,roughness:.72});
  const body=new THREE.Mesh(new THREE.CapsuleGeometry(.43,.85,4,8),material);
  const angle=Math.random()*Math.PI*2, radius=15+Math.random()*7;
  body.position.set(Math.cos(angle)*radius,.88,Math.sin(angle)*radius);
  enemyGroup.add(body);
  enemies.push({mesh:body,hp:70,speed:1.25+Math.random()*.55,attack:0});
}
function startWave(){
  const count=Math.min(3+state.wave*2,18);
  for(let i=0;i<count;i++) makeEnemy();
  toast(`الموجة ${state.wave} — ${count} أعداء`);
}
function begin(){
  state.running=true;state.over=false;state.health=100;state.score=0;state.wave=1;state.ammo=state.maxAmmo;state.yaw=0;state.pitch=0;state.fireAt=0;state.reloadUntil=0;state.waveDelay=0;
  player.position.set(0,0,0);
  enemies.splice(0,enemies.length);enemyGroup.clear();
  $('overlay').classList.add('hidden');$('controls').style.display='block';
  hud();startWave();clock.start();
}
function finish(){state.running=false;state.over=true;$('title').textContent='انتهت اللعبة';$('message').textContent=`النقاط: ${state.score} — وصلت إلى الموجة ${state.wave}.`; $('start').textContent='العب مرة ثانية';$('overlay').classList.remove('hidden');}
function reload(){if(!state.running||state.ammo===state.maxAmmo||performance.now()<state.reloadUntil)return;state.reloadUntil=performance.now()+1000;toast('إعادة تلقيم...');setTimeout(()=>{if(state.running){state.ammo=state.maxAmmo;state.reloadUntil=0;hud();}},1000);}
function shoot(){
  const now=performance.now();
  if(!state.running||now<state.fireAt||now<state.reloadUntil)return;
  if(state.ammo<=0){toast('الذخيرة فارغة');reload();return;}
  state.ammo--;state.fireAt=now+180;hud();
  camera.updateMatrixWorld();
  raycaster.setFromCamera(new THREE.Vector2(0,0),camera);
  const hits=raycaster.intersectObjects(enemies.map(e=>e.mesh),false);
  if(hits.length){
    const target=enemies.find(e=>e.mesh===hits[0].object);
    if(target){target.hp-=35;target.mesh.material.color.set(0xff9a5c);setTimeout(()=>{if(target.mesh.parent)target.mesh.material.color.set(0xc6453c)},80);
      if(target.hp<=0){enemyGroup.remove(target.mesh);enemies.splice(enemies.indexOf(target),1);state.score+=100;hud();}
    }
  }
  if(state.ammo===0)toast('اضغط إعادة تلقيم');
}
function updateEnemies(dt){
  for(const enemy of [...enemies]){
    const dx=player.position.x-enemy.mesh.position.x,dz=player.position.z-enemy.mesh.position.z;
    const dist=Math.hypot(dx,dz);
    if(dist>1.25){enemy.mesh.position.x+=dx/dist*enemy.speed*dt;enemy.mesh.position.z+=dz/dist*enemy.speed*dt;enemy.mesh.lookAt(player.position.x,enemy.mesh.position.y,player.position.z);}
    else{enemy.attack+=dt;if(enemy.attack>.6){state.health-=7;enemy.attack=0;hud();if(state.health<=0){state.health=0;hud();finish();return;}}}
  }
  if(enemies.length===0&&state.waveDelay===0){state.waveDelay=2;toast('تم اجتياز الموجة!');setTimeout(()=>{if(state.running){state.wave++;state.waveDelay=0;startWave();hud();}},2000);}
}
function update(dt){
  if(!state.running)return;
  const f=-input.y, s=input.x;
  const forward=new THREE.Vector3(-Math.sin(state.yaw),0,-Math.cos(state.yaw));
  const right=new THREE.Vector3(Math.cos(state.yaw),0,-Math.sin(state.yaw));
  const move=forward.multiplyScalar(f).add(right.multiplyScalar(s));
  if(move.lengthSq()>1)move.normalize();
  player.position.addScaledVector(move,5.2*dt);
  const d=Math.hypot(player.position.x,player.position.z);if(d>18){player.position.x*=18/d;player.position.z*=18/d;}
  player.rotation.y=state.yaw;pivot.rotation.x=state.pitch;
  updateEnemies(dt);
  if(input.firing)shoot();
}
function frame(){requestAnimationFrame(frame);const dt=Math.min(clock.getDelta()||0,.04);update(dt);renderer.render(scene,camera);}
frame();

function resize(){camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight);renderer.setPixelRatio(Math.min(devicePixelRatio||1,1.5));}
addEventListener('resize',resize);
$('start').addEventListener('click',begin);
$('reload').addEventListener('pointerdown',e=>{e.preventDefault();reload();});
$('fire').addEventListener('pointerdown',e=>{e.preventDefault();input.firing=true;shoot();});
for(const type of ['pointerup','pointercancel','pointerleave'])$('fire').addEventListener(type,()=>input.firing=false);

const joy=$('joystick'),stick=$('stick');
function joystickMove(e){const r=joy.getBoundingClientRect(),dx=e.clientX-(r.left+r.width/2),dy=e.clientY-(r.top+r.height/2),limit=39,len=Math.min(Math.hypot(dx,dy),limit),a=Math.atan2(dy,dx),x=Math.cos(a)*len,y=Math.sin(a)*len;stick.style.transform=`translate(${x}px,${y}px)`;input.x=x/limit;input.y=y/limit;}
joy.addEventListener('pointerdown',e=>{e.preventDefault();input.joyId=e.pointerId;joy.setPointerCapture(e.pointerId);joystickMove(e);});
joy.addEventListener('pointermove',e=>{if(e.pointerId===input.joyId)joystickMove(e);});
function resetJoy(){input.joyId=null;input.x=0;input.y=0;stick.style.transform='translate(0,0)';}
joy.addEventListener('pointerup',resetJoy);joy.addEventListener('pointercancel',resetJoy);

// Drag on the right half to look around; the left joystick and buttons remain independent.
renderer.domElement.addEventListener('pointerdown',e=>{if(!state.running||e.clientX<innerWidth*.42)return;input.lookId=e.pointerId;input.lookX=e.clientX;input.lookY=e.clientY;renderer.domElement.setPointerCapture(e.pointerId);});
renderer.domElement.addEventListener('pointermove',e=>{if(e.pointerId!==input.lookId)return;const dx=e.clientX-input.lookX,dy=e.clientY-input.lookY;input.lookX=e.clientX;input.lookY=e.clientY;state.yaw-=dx*.006;state.pitch-=dy*.005;state.pitch=THREE.MathUtils.clamp(state.pitch,-1.25,1.25);});
function stopLook(e){if(e.pointerId===input.lookId)input.lookId=null;}
renderer.domElement.addEventListener('pointerup',stopLook);renderer.domElement.addEventListener('pointercancel',stopLook);

// Keyboard support for desktop testing.
addEventListener('keydown',e=>{if(e.key==='w'||e.key==='ArrowUp')input.y=-1;if(e.key==='s'||e.key==='ArrowDown')input.y=1;if(e.key==='a'||e.key==='ArrowLeft')input.x=-1;if(e.key==='d'||e.key==='ArrowRight')input.x=1;if(e.code==='Space')shoot();if(e.key.toLowerCase()==='r')reload();});
addEventListener('keyup',e=>{if(['w','s','ArrowUp','ArrowDown'].includes(e.key))input.y=0;if(['a','d','ArrowLeft','ArrowRight'].includes(e.key))input.x=0;});
$('controls').style.display='none';hud();
