from PIL import Image, ImageChops, ImageStat
from pathlib import Path
from datetime import datetime, timezone
import json, sys
root=Path.cwd()/'evidence/corrective/browser/fallback'
results={}
for name in ('desktop','mobile'):
    baseline=Image.open(root/f'baseline-{name}.png').convert('RGB')
    corrected=Image.open(root/f'corrected-{name}.png').convert('RGB')
    diff=ImageChops.difference(baseline,corrected)
    bbox=diff.getbbox()
    nonzero=sum(1 for px in diff.getdata() if px != (0,0,0))
    total=baseline.width*baseline.height
    ratio=nonzero/total
    localized_control_label = bbox is not None and bbox[1] <= 25 and bbox[3] <= 40 and ratio <= 0.003
    exact = nonzero == 0
    results[name]={
      'size':[baseline.width,baseline.height], 'pixelDifferenceCount':nonzero,
      'pixelDifferenceRatio':ratio, 'boundingBox':list(bbox) if bbox else None,
      'meanChannelDifference':ImageStat.Stat(diff).mean,
      'classification':'exact' if exact else ('intentional R7→R8.1 control-label correction' if localized_control_label else 'unexpected'),
      'pass': exact or localized_control_label,
    }
report={'generatedAt':datetime.now(timezone.utc).isoformat(),'scope':'locked R8.1 visual baseline versus corrected no-deployment standalone; no baseline replacement','results':results,'pass':all(v['pass'] for v in results.values())}
(root/'visual-regression.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
sys.exit(0 if report['pass'] else 1)
