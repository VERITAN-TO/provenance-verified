from pathlib import Path
from playwright.sync_api import sync_playwright
root=Path.cwd(); out=root/'evidence/corrective/browser/fallback'; out.mkdir(parents=True,exist_ok=True)
files={'baseline':Path('/mnt/data/PROVENANCE_CX_UNIFIED_FOUR_LAYER_R8_1_FOOTER_FINAL_STANDALONE.html'),'corrected':root/'review/PROVENANCE_CX_R8_PRODUCTION_CAMPAIGN_REVIEW_STANDALONE.html'}
with sync_playwright() as p:
  browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--disable-gpu','--disable-software-rasterizer','--disable-background-networking','--no-first-run'])
  for label,file in files.items():
    html=file.read_text().replace('<head>','<head><script>window.__PV_FORCE_NO_WEBGL__=true</script>',1)
    for name,viewport,scale,mobile in [('desktop',{'width':1440,'height':1000},1,False),('mobile',{'width':390,'height':844},2,True)]:
      page=browser.new_page(viewport=viewport,device_scale_factor=scale,is_mobile=mobile,reduced_motion='reduce')
      page.set_content(html,wait_until='load',timeout=60000); page.wait_for_timeout(2500)
      page.evaluate("document.documentElement.style.scrollBehavior='auto';scrollTo(0,0)"); page.wait_for_timeout(200)
      page.screenshot(path=str(out/f'{label}-{name}.png'),full_page=False)
      page.close()
  browser.close()
print('captured locked baseline and corrected standalone')
