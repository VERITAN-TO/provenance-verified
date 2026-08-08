from pathlib import Path
from datetime import datetime, timezone
import json,re,sys
from playwright.sync_api import sync_playwright
root=Path.cwd(); target=root/'review/PROVENANCE_CX_R8_PRODUCTION_AUTHORITY_R3_REVIEW_STANDALONE.html'
html=target.read_text().replace('<head>','<head><script>window.__PV_FORCE_NO_WEBGL__=true</script>',1)
routes=['/','/verify','/registry','/registry/PV-TEST-T4D004','/developers','/docs','/docs/api','/docs/webhooks','/docs/mcp','/trust','/security','/company','/contact','/access','/sign-in','/status','/changelog','/brand/trademark','/provenance-verified','/legal/certification-policy','/legal/evidence-policy','/legal/revocation-policy','/app','/app/lots','/app/intake','/app/batches','/app/batches/batch-001','/app/search','/app/review','/app/labels','/app/exceptions','/app/audit']
report={'generatedAt':datetime.now(timezone.utc).isoformat(),'target':str(target.relative_to(root)),'routes':[],'interactions':[],'consoleErrors':[],'pageErrors':[],'externalRequests':[],'viewports':[]}
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--disable-gpu','--disable-software-rasterizer','--disable-background-networking','--no-first-run'])
 page=b.new_page(viewport={'width':1440,'height':1000},reduced_motion='reduce')
 page.on('console',lambda m: report['consoleErrors'].append(m.text) if m.type=='error' else None); page.on('pageerror',lambda e: report['pageErrors'].append(str(e))); page.on('request',lambda r: report['externalRequests'].append(r.url) if r.url.startswith(('http://','https://')) else None)
 page.set_content(html,wait_until='load',timeout=60000); page.wait_for_timeout(2000)
 for route in routes:
  page.evaluate("r=>location.hash='#'+r",route); page.wait_for_timeout(100)
  state=page.evaluate("""()=>({path:location.hash.slice(1)||'/',notFound:/Review route not found/i.test(document.body.innerText),text:(document.querySelector('main')?.innerText||document.body.innerText).length,overflow:Math.max(0,document.documentElement.scrollWidth-document.documentElement.clientWidth),duplicateIds:[...document.querySelectorAll('[id]')].map(x=>x.id).filter((id,i,a)=>a.indexOf(id)!==i)})""")
  state['requested']=route; state['pass']=state['path']==route and not state['notFound'] and state['text']>40 and state['overflow']==0 and not state['duplicateIds']; report['routes'].append(state)
 page.evaluate("location.hash='#/'"); page.wait_for_timeout(150)
 launch=page.get_by_role('button',name='R3 authority review'); launch.click(); page.wait_for_timeout(100)
 dialog=page.get_by_role('dialog',name='Production authority plane review')
 report['interactions'].append({'id':'r3-dialog-open','pass':dialog.count()==1 and dialog.is_visible()})
 required=['Sandbox','Pilot','Production','Authority chain','Credential lifecycle','Certification-mark separation','Fifteen production gates']
 text=dialog.inner_text(); report['interactions'].append({'id':'r3-complete-review-sections','pass':all(v in text for v in required),'required':required})
 for label,expected in [('Denied','DENIED'),('Dependency failure','DEPENDENCY FAILURE'),('Recovery','RECOVERY'),('Loading','LOADING')]:
  page.get_by_role('button',name=label,exact=True).click(); page.wait_for_timeout(50); value=page.locator('#pv-r3-state-readout').inner_text(); report['interactions'].append({'id':'r3-state-'+label.lower().replace(' ','-'),'pass':expected in value})
 report['interactions'].append({'id':'r3-fifteen-gates','pass':dialog.locator('.pv-r3-gate').count()==15})
 page.keyboard.press('Escape'); report['interactions'].append({'id':'r3-dialog-escape-close','pass':not dialog.is_visible()})
 for width,height in [(1440,1000),(820,1180),(390,844)]:
  page.set_viewport_size({'width':width,'height':height}); page.wait_for_timeout(80); launch.click(); page.wait_for_timeout(50)
  overflow=page.evaluate("Math.max(0,document.documentElement.scrollWidth-document.documentElement.clientWidth)")
  report['viewports'].append({'width':width,'height':height,'overflow':overflow,'pass':overflow==0 and dialog.is_visible()}); page.keyboard.press('Escape')
 b.close()
report['externalRequests']=sorted(set(report['externalRequests'])); report['summary']={'routes':len(report['routes']),'routesPassed':sum(x['pass'] for x in report['routes']),'interactions':len(report['interactions']),'interactionsPassed':sum(x['pass'] for x in report['interactions']),'viewports':len(report['viewports']),'viewportsPassed':sum(x['pass'] for x in report['viewports']),'consoleErrors':len(report['consoleErrors']),'pageErrors':len(report['pageErrors']),'externalRequests':len(report['externalRequests'])}; report['pass']=report['summary']['routes']==report['summary']['routesPassed'] and report['summary']['interactions']==report['summary']['interactionsPassed'] and report['summary']['viewports']==report['summary']['viewportsPassed'] and not report['consoleErrors'] and not report['pageErrors'] and not report['externalRequests']
out=root/'evidence/r3/r3-standalone-browser-audit.json'; out.write_text(json.dumps(report,indent=2)+'\n'); print(json.dumps({'pass':report['pass'],'summary':report['summary'],'failedRoutes':[x['requested'] for x in report['routes'] if not x['pass']],'failedInteractions':[x['id'] for x in report['interactions'] if not x['pass']]},indent=2)); sys.exit(0 if report['pass'] else 1)
