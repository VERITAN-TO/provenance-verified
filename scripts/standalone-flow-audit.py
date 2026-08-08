from pathlib import Path
from datetime import datetime, timezone
import json, re, sys
from playwright.sync_api import sync_playwright

root=Path.cwd()
html_path=root/'review/PROVENANCE_CX_R8_PRODUCTION_CAMPAIGN_REVIEW_STANDALONE.html'
html=html_path.read_text()
html=html.replace('<head>','<head><script>window.__PV_FORCE_NO_WEBGL__=true</script>',1)
routes=[
 '/', '/verify','/registry','/registry/PV-TEST-T4D004','/developers','/docs','/docs/quickstart','/docs/api','/docs/webhooks','/docs/mcp',
 '/trust','/security','/company','/contact','/access','/sign-in','/status','/changelog','/brand/trademark','/provenance-verified',
 '/legal/certification-policy','/legal/evidence-policy','/legal/revocation-policy',
 '/app','/app/lots','/app/intake','/app/batches','/app/batches/batch-001','/app/search','/app/review','/app/labels','/app/exceptions','/app/audit'
]
report={'generatedAt':datetime.now(timezone.utc).isoformat(),'scope':'local standalone maintained-route and safe-interaction acceptance; no deployment','routes':[],'interactions':[],'consoleErrors':[],'pageErrors':[],'externalRequests':[]}
with sync_playwright() as p:
    browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--disable-gpu','--disable-software-rasterizer','--disable-background-networking','--no-first-run'])
    page=browser.new_page(viewport={'width':1440,'height':1000},reduced_motion='reduce')
    page.on('console',lambda msg: report['consoleErrors'].append(msg.text) if msg.type=='error' else None)
    page.on('pageerror',lambda exc: report['pageErrors'].append(str(exc)))
    page.on('request',lambda req: report['externalRequests'].append(req.url) if req.url.startswith(('http://','https://')) else None)
    page.set_content(html,wait_until='load',timeout=60000)
    page.wait_for_timeout(2500)
    for route in routes:
        page.evaluate("r=>{location.hash='#'+r}",route)
        page.wait_for_timeout(120)
        state=page.evaluate("""() => ({
          path: location.hash.slice(1)||'/', title:document.title,
          h1:[...document.querySelectorAll('h1')].map(e=>e.textContent.trim()),
          h2:[...document.querySelectorAll('h2')].slice(0,3).map(e=>e.textContent.trim()),
          textLength:document.querySelector('main')?.innerText.length||document.body.innerText.length,
          notFound:/Review route not found/i.test(document.body.innerText),
          emptyMain:!(document.querySelector('main')?.innerText||'').trim(),
          overflow:Math.max(0,document.documentElement.scrollWidth-document.documentElement.clientWidth),
          duplicateIds:[...document.querySelectorAll('[id]')].map(e=>e.id).filter((id,i,a)=>a.indexOf(id)!==i)
        })""")
        state['requested']=route
        state['pass']=state['path']==route and not state['notFound'] and not state['emptyMain'] and state['textLength']>40 and state['overflow']==0 and not state['duplicateIds']
        report['routes'].append(state)
    # Home proof transaction
    page.evaluate("location.hash='#/'"); page.wait_for_timeout(200)
    proof=page.get_by_role('button',name=re.compile('Run the proof transaction',re.I))
    before=page.locator('body').inner_text()
    proof.click(); page.wait_for_timeout(1800)
    after=page.locator('body').inner_text()
    report['interactions'].append({'id':'run-proof-transaction','pass':before!=after and bool(re.search(r'(complete|issued|verified|Tier 4)',after,re.I))})
    # Stage rail controls
    stage_buttons=page.locator('button').filter(has_text=re.compile(r'^(01Identify|02Bind|03Resolve|04Corroborate|05Sign|06Publish|07Control)'))
    stage_ok=stage_buttons.count()>=7
    seen=[]
    for i in range(min(stage_buttons.count(),7)):
        stage_buttons.nth(i).click(); page.wait_for_timeout(80)
        seen.append(stage_buttons.nth(i).get_attribute('class') or '')
    report['interactions'].append({'id':'seven-stage-rail','pass':stage_ok and len(seen)==7,'count':stage_buttons.count()})
    # Verify route form/control
    page.evaluate("location.hash='#/verify'"); page.wait_for_timeout(150)
    inputs=page.locator('input')
    verify_pass=inputs.count()>0
    if verify_pass:
        target=None
        for i in range(inputs.count()):
            typ=inputs.nth(i).get_attribute('type') or 'text'
            if typ in ('text','search','url'):
                target=inputs.nth(i); break
        if target:
            target.fill('PV-TEST-T4D004')
            buttons=page.get_by_role('button')
            clicked=False
            for i in range(buttons.count()):
                name=buttons.nth(i).inner_text().strip()
                if re.search(r'(verify|resolve|search)',name,re.I):
                    buttons.nth(i).click(); clicked=True; page.wait_for_timeout(300); break
            verify_pass=clicked and 'PV-TEST-T4D004' in page.locator('body').inner_text()
    report['interactions'].append({'id':'verify-record','pass':verify_pass})
    # Reduced motion + no WebGL toggles are named and mutable
    page.evaluate("location.hash='#/'"); page.set_viewport_size({'width':1440,'height':1000}); page.wait_for_timeout(150)
    webgl=page.locator('input[aria-label="Disable WebGL"]')
    motion=page.locator('input[aria-label="Enable reduced motion"]')
    toggles=webgl.count()==1 and motion.count()==1
    if toggles:
        if not webgl.is_checked(): webgl.check(force=True)
        if not motion.is_checked(): motion.check(force=True)
        toggles=webgl.is_checked() and motion.is_checked()
    report['interactions'].append({'id':'accessibility-toggles','pass':toggles})
    # Mobile menu
    page.set_viewport_size({'width':390,'height':844}); page.wait_for_timeout(150)
    menu=page.get_by_role('button',name=re.compile('menu',re.I))
    mobile_pass=menu.count()==1
    if mobile_pass:
        menu.click(); page.wait_for_timeout(100)
        mobile_pass=page.get_by_role('link',name='Registry').count()>0
    report['interactions'].append({'id':'mobile-menu','pass':mobile_pass})
    browser.close()

report['externalRequests']=sorted(set(report['externalRequests']))
report['summary']={
 'routes':len(report['routes']), 'routesPassed':sum(1 for x in report['routes'] if x['pass']),
 'interactions':len(report['interactions']), 'interactionsPassed':sum(1 for x in report['interactions'] if x['pass']),
 'consoleErrors':len(report['consoleErrors']), 'pageErrors':len(report['pageErrors']), 'externalRequests':len(report['externalRequests'])
}
report['pass']=report['summary']['routes']==report['summary']['routesPassed'] and report['summary']['interactions']==report['summary']['interactionsPassed'] and not report['consoleErrors'] and not report['pageErrors'] and not report['externalRequests']
out=root/'evidence/corrective/browser/standalone-flow-audit.json'
out.parent.mkdir(parents=True,exist_ok=True); out.write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'pass':report['pass'],'summary':report['summary'],'failedRoutes':[x['requested'] for x in report['routes'] if not x['pass']],'failedInteractions':[x['id'] for x in report['interactions'] if not x['pass']]},indent=2))
sys.exit(0 if report['pass'] else 1)
