import * as THREE from 'three';
import type { GlyphName } from './contracts';

function barBetween(a: THREE.Vector2, b: THREE.Vector2, width: number, material: THREE.Material, z = .44): THREE.Mesh {
  const delta = b.clone().sub(a);
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(delta.length(), width, .085, 1, 1, 1), material);
  mesh.position.set((a.x + b.x) / 2, (a.y + b.y) / 2, z);
  mesh.rotation.z = Math.atan2(delta.y, delta.x);
  mesh.castShadow = true;
  return mesh;
}

function tube(points: THREE.Vector3[], radius: number, material: THREE.Material): THREE.Mesh {
  const curve = new THREE.CatmullRomCurve3(points, false, 'centripetal');
  const mesh = new THREE.Mesh(new THREE.TubeGeometry(curve, 48, radius, 10, false), material);
  mesh.castShadow = true;
  return mesh;
}

function ring(radius: number, tubeRadius: number, material: THREE.Material, scaleX = 1): THREE.Mesh {
  const mesh = new THREE.Mesh(new THREE.TorusGeometry(radius, tubeRadius, 16, 96), material);
  mesh.scale.x = scaleX;
  mesh.position.z = .44;
  mesh.castShadow = true;
  return mesh;
}

function triangleShape(material: THREE.Material): THREE.Mesh {
  const shape = new THREE.Shape();
  shape.moveTo(0, .6); shape.lineTo(-.55, -.45); shape.lineTo(.55, -.45); shape.closePath();
  const hole = new THREE.Path();
  hole.moveTo(0, .42); hole.lineTo(-.37, -.32); hole.lineTo(.37, -.32); hole.closePath();
  shape.holes.push(hole);
  const geo = new THREE.ExtrudeGeometry(shape, {depth:.075, bevelEnabled:true, bevelThickness:.025, bevelSize:.018, bevelSegments:3});
  geo.center();
  const mesh = new THREE.Mesh(geo, material); mesh.position.z=.44; mesh.castShadow=true; return mesh;
}

export interface GlyphBuild {
  group: THREE.Group;
  pulseParts: THREE.Object3D[];
}

export function buildGlyph(kind: GlyphName, material: THREE.Material, darkMaterial: THREE.Material): GlyphBuild {
  const group = new THREE.Group();
  const pulseParts: THREE.Object3D[] = [];
  const v = (x:number,y:number) => new THREE.Vector2(x,y);
  const add = (...items: THREE.Object3D[]) => { items.forEach(i => group.add(i)); pulseParts.push(...items); };

  switch (kind) {
    case 'verify':
    case 'approve': {
      add(barBetween(v(-.5,-.02),v(-.18,-.34),.11,material), barBetween(v(-.18,-.34),v(.55,.42),.11,material));
      break;
    }
    case 'prove': {
      const pts = [new THREE.Vector3(-.52,-.3,.44),new THREE.Vector3(-.2,.18,.44),new THREE.Vector3(.12,-.08,.44),new THREE.Vector3(.48,.32,.44)];
      add(tube(pts,.055,material));
      const dot = new THREE.Mesh(new THREE.SphereGeometry(.095,24,18),material); dot.position.set(.52,.36,.44); add(dot);
      break;
    }
    case 'secure': {
      const body = new THREE.Mesh(new THREE.BoxGeometry(.78,.54,.10,1,1,1), darkMaterial);
      body.position.set(0,-.14,.42); body.castShadow=true; group.add(body);
      add(
        barBetween(v(-.39,.13),v(-.39,-.41),.055,material,.5),
        barBetween(v(.39,.13),v(.39,-.41),.055,material,.5),
        barBetween(v(-.39,-.41),v(.39,-.41),.055,material,.5),
        barBetween(v(-.39,.13),v(.39,.13),.055,material,.5),
        barBetween(v(-.25,.14),v(-.25,.48),.075,material,.5),
        barBetween(v(.25,.14),v(.25,.48),.075,material,.5),
        barBetween(v(-.25,.48),v(.25,.48),.075,material,.5)
      );
      const key = new THREE.Mesh(new THREE.SphereGeometry(.075,18,14),material); key.position.set(0,-.13,.53); add(key);
      break;
    }
    case 'check': {
      add(ring(.38,.055,material));
      add(barBetween(v(.27,-.27),v(.58,-.58),.095,material));
      break;
    }
    case 'attest': {
      const shield = new THREE.Shape(); shield.moveTo(0,.56); shield.lineTo(-.5,.34); shield.lineTo(-.43,-.18); shield.quadraticCurveTo(0,-.6,.43,-.18); shield.lineTo(.5,.34); shield.closePath();
      const hole = new THREE.Path(); hole.moveTo(0,.37); hole.lineTo(-.31,.22); hole.lineTo(-.26,-.09); hole.quadraticCurveTo(0,-.38,.26,-.09); hole.lineTo(.31,.22); hole.closePath(); shield.holes.push(hole);
      const mesh = new THREE.Mesh(new THREE.ExtrudeGeometry(shield,{depth:.08,bevelEnabled:true,bevelThickness:.02,bevelSize:.015,bevelSegments:3}),material); mesh.geometry.center(); mesh.position.z=.42; add(mesh);
      add(barBetween(v(-.18,-.02),v(-.02,-.18),.065,material,.54),barBetween(v(-.02,-.18),v(.26,.16),.065,material,.54));
      break;
    }
    case 'policy': {
      const page = new THREE.Mesh(new THREE.BoxGeometry(.72,.92,.09,1,1,1),darkMaterial); page.position.z=.42; page.castShadow=true; group.add(page);
      add(
        barBetween(v(-.36,.46),v(.36,.46),.045,material,.51),
        barBetween(v(-.36,-.46),v(.36,-.46),.045,material,.51),
        barBetween(v(-.36,-.46),v(-.36,.46),.045,material,.51),
        barBetween(v(.36,-.46),v(.36,.46),.045,material,.51),
        barBetween(v(-.23,.22),v(.23,.22),.055,material,.53),
        barBetween(v(-.23,0),v(.16,0),.055,material,.53),
        barBetween(v(-.23,-.22),v(.08,-.22),.055,material,.53)
      );
      break;
    }
    case 'observe': {
      const eyePts:THREE.Vector3[]=[]; for(let i=0;i<=28;i++){const t=i/28; const x=-.62+t*1.24; const y=Math.sin(t*Math.PI)*.38; eyePts.push(new THREE.Vector3(x,y,.44));}
      const eyePts2:THREE.Vector3[]=[]; for(let i=0;i<=28;i++){const t=i/28; const x=.62-t*1.24; const y=-Math.sin(t*Math.PI)*.38; eyePts2.push(new THREE.Vector3(x,y,.44));}
      add(tube(eyePts,.045,material),tube(eyePts2,.045,material));
      const pupil = new THREE.Mesh(new THREE.SphereGeometry(.17,32,24),material); pupil.position.z=.45; add(pupil);
      break;
    }
    case 'pending': {
      const outline = new THREE.Group();
      outline.add(barBetween(v(-.42,.46),v(.42,.46),.08,material),barBetween(v(-.42,-.46),v(.42,-.46),.08,material));
      outline.add(tube([new THREE.Vector3(-.35,.38,.44),new THREE.Vector3(0,.02,.44),new THREE.Vector3(.35,.38,.44)],.045,material));
      outline.add(tube([new THREE.Vector3(-.35,-.38,.44),new THREE.Vector3(0,-.02,.44),new THREE.Vector3(.35,-.38,.44)],.045,material));
      group.add(outline); pulseParts.push(outline); break;
    }
    case 'failed': {
      add(barBetween(v(-.46,-.46),v(.46,.46),.11,material),barBetween(v(-.46,.46),v(.46,-.46),.11,material)); break;
    }
    case 'revoked': {
      add(ring(.5,.055,material),barBetween(v(-.39,-.39),v(.39,.39),.105,material)); break;
    }
    case 'exception': {
      add(triangleShape(material));
      add(barBetween(v(0,.18),v(0,-.17),.075,material,.55));
      const dot = new THREE.Mesh(new THREE.SphereGeometry(.055,20,16),material); dot.position.set(0,-.3,.55); add(dot); break;
    }
  }
  return {group,pulseParts};
}
