from pathlib import Path
from datetime import datetime,timezone
from playwright.sync_api import sync_playwright
from PIL import Image,ImageChops
import json,io,sys
import numpy as np
root=Path.cwd(); source=root/'review/PROVENANCE_CX_R8_PRODUCTION_CAMPAIGN_REVIEW_STANDALONE.html'; r3=root/'review/PROVENANCE_CX_R8_PRODUCTION_AUTHORITY_R3_REVIEW_STANDALONE.html'
outdir=root/'evidence/r3/browser'; outdir.mkdir(parents=True,exist_ok=True)
report={'generatedAt':datetime.now(timezone.utc).isoformat(),'comparisons':[],'accessibility':{},'zoom':[]}
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--disable-gpu','--disable-software-rasterizer','--disable-background-networking'])
 for width,height,name in [(1440,1000,'desktop'),(390,844,'mobile')]:
  shots=[]
  for file,label in [(source,'source'),(r3,'r3')]:
   page=b.new_page(viewport={'width':width,'height':height},reduced_motion='reduce')
   html=file.read_text().replace('<head>','<head><script>window.__PV_FORCE_NO_WEBGL__=true</script>',1)
   page.set_content(html,wait_until='load',timeout=60000); page.wait_for_timeout(1800)
   data=page.screenshot(full_page=False); (outdir/f'{name}-{label}.png').write_bytes(data); shots.append(Image.open(io.BytesIO(data)).convert('RGBA')); page.close()
  diff=ImageChops.difference(shots[0],shots[1]); rgb=diff.convert('RGB'); bbox=rgb.getbbox(); pixels=width*height; changed=int(np.count_nonzero(np.any(np.asarray(rgb)!=0,axis=2)))
  if bbox:
   rgb.save(outdir/f'{name}-diff.png')
  report['comparisons'].append({'viewport':name,'width':width,'height':height,'changedPixels':changed,'ratio':changed/pixels,'boundingBox':bbox,'pass':changed/pixels<0.02})
 page=b.new_page(viewport={'width':1440,'height':1000},reduced_motion='reduce')
 page.set_content(r3.read_text().replace('<head>','<head><script>window.__PV_FORCE_NO_WEBGL__=true</script>',1),wait_until='load',timeout=60000); page.wait_for_timeout(1500); page.get_by_role('button',name='R3 authority review').click(); page.wait_for_timeout(100)
 client=page.context.new_cdp_session(page); tree=client.send('Accessibility.getFullAXTree')['nodes']; roles=[(n.get('role') or {}).get('value') for n in tree]; names=[(n.get('name') or {}).get('value') for n in tree]
 report['accessibility']={'dialogRole':roles.count('dialog')>=1,'dialogName':'Production authority plane review' in names,'buttons':roles.count('button'),'headings':roles.count('heading'),'focusOnClose':page.evaluate("document.activeElement?.id==='pv-r3-review-close'"),'pass':roles.count('dialog')>=1 and 'Production authority plane review' in names and page.evaluate("document.activeElement?.id==='pv-r3-review-close'")}
 page.keyboard.press('Escape')
 for zoom in [1.5,2.0,4.0]:
  page.set_viewport_size({'width':1280,'height':900}); page.evaluate("z=>{document.documentElement.style.zoom=String(z)}",zoom); page.wait_for_timeout(100)
  overflow=page.evaluate("Math.max(0,document.documentElement.scrollWidth-document.documentElement.clientWidth)"); launch=page.get_by_role('button',name='R3 authority review'); visible=launch.is_visible(); report['zoom'].append({'zoom':zoom,'overflow':overflow,'launcherVisible':visible,'pass':visible and overflow==0})
 b.close()
report['pass']=all(x['pass'] for x in report['comparisons']) and report['accessibility']['pass'] and all(x['pass'] for x in report['zoom']); (root/'evidence/r3/r3-standalone-visual-a11y.json').write_text(json.dumps(report,indent=2)+'\n'); print(json.dumps(report,indent=2)); sys.exit(0 if report['pass'] else 1)
