from pathlib import Path
from datetime import datetime,timezone
from playwright.sync_api import sync_playwright
import json,sys
root=Path.cwd(); artifact=root/'review/PROVENANCE_CX_R8_PRODUCTION_AUTHORITY_R3_REVIEW_STANDALONE.html'; html=artifact.read_text().replace('<head>','<head><script>window.__PV_FORCE_NO_WEBGL__=true</script>',1)
report={'generatedAt':datetime.now(timezone.utc).isoformat(),'artifact':str(artifact),'engines':[]}
with sync_playwright() as p:
 for name,browser_type in [('chromium',p.chromium),('firefox',p.firefox),('webkit',p.webkit)]:
  engine={'engine':name,'viewports':[],'pass':True}
  executable='/usr/bin/chromium' if name=='chromium' else browser_type.executable_path
  if not Path(executable).exists(): engine.update({'pass':False,'unavailable':True,'launchError':f'Executable unavailable: {executable}'});report['engines'].append(engine);continue
  try: browser=browser_type.launch(headless=True,executable_path=executable,args=['--no-sandbox','--disable-gpu'] if name=='chromium' else [])
  except Exception as e: engine.update({'pass':False,'launchError':str(e)});report['engines'].append(engine);continue
  for vp in [{'name':'desktop','width':1440,'height':1000},{'name':'mobile','width':390,'height':844}]:
   errors=[];requests=[];page=browser.new_page(viewport={'width':vp['width'],'height':vp['height']},reduced_motion='reduce')
   page.on('console',lambda msg,errors=errors: errors.append(f'{msg.type}:{msg.text}') if msg.type=='error' else None)
   page.on('pageerror',lambda exc,errors=errors: errors.append(f'pageerror:{exc}'))
   page.on('request',lambda req,requests=requests: requests.append(req.url) if req.url.startswith(('http://','https://')) else None)
   try:
    page.set_content(html,wait_until='load',timeout=60000);page.wait_for_timeout(1000)
    title=page.title(); launcher=page.get_by_role('button',name='R3 authority review'); launcher_visible=launcher.is_visible(); launcher.click();page.wait_for_timeout(100)
    dialog_visible=page.get_by_role('dialog',name='Production authority plane review').is_visible();tabs=page.locator('[data-r3-state]');tab_count=tabs.count()
    for i in range(tab_count): tabs.nth(i).click(); page.wait_for_timeout(25)
    page.keyboard.press('Escape'); closed=page.locator('#pv-r3-review-scrim').is_hidden()
    overflow=page.evaluate('Math.max(0,document.documentElement.scrollWidth-document.documentElement.clientWidth)')
    headings=page.get_by_role('heading').count();links=page.get_by_role('link').count()
    ok=title.startswith('PROVENANCE.CX') and launcher_visible and dialog_visible and closed and tab_count==4 and overflow==0 and not errors and not requests and headings>10 and links>10
    engine['viewports'].append({**vp,'title':title,'launcherVisible':launcher_visible,'dialogVisible':dialog_visible,'tabCount':tab_count,'escapeClosed':closed,'horizontalOverflow':overflow,'headings':headings,'links':links,'consoleOrPageErrors':errors,'externalRequests':requests,'pass':ok});engine['pass']=engine['pass'] and ok
   except Exception as e:
    engine['viewports'].append({**vp,'pass':False,'error':str(e),'consoleOrPageErrors':errors,'externalRequests':requests});engine['pass']=False
   finally: page.close()
  browser.close();report['engines'].append(engine)
report['localChromiumPass']=next((e['pass'] for e in report['engines'] if e['engine']=='chromium'),False);report['fullBrowserPass']=all(e['pass'] for e in report['engines']);report['pass']=report['localChromiumPass'];(root/'evidence/r3/r3-cross-browser-standalone.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2));sys.exit(0 if report['pass'] else 1)
