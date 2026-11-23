"""Read-only checks for the 20 generated PNG deliverables and offline gallery."""
import json
from pathlib import Path
from PIL import Image

root=Path(__file__).resolve().parents[1]
folder=root/'assets'/'dragon-ball'
manifest=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
errors=[]
report=[]
assert len(manifest['heroes'])==20
for hero in manifest['heroes']:
 path=folder/hero['file']
 if not path.exists():
  errors.append('Missing: '+path.name)
  continue
 with Image.open(path) as image:
  image.load()
  if image.mode!='RGBA':
   errors.append('No alpha channel: '+path.name)
   continue
  alpha=image.getchannel('A')
  corners=[alpha.getpixel((x,y)) for x,y in [(0,0),(image.width-1,0),(0,image.height-1),(image.width-1,image.height-1)]]
  if max(corners)>5: errors.append('Nontransparent canvas corner: '+path.name)
  if alpha.getextrema()[1]<200: errors.append('No opaque character: '+path.name)
  report.append({'file':path.name,'size':list(image.size),'mode':image.mode,'corner_alpha':corners,'bytes':path.stat().st_size})
(root/'artifacts'/'dragon-ball-art-qa.json').write_text(json.dumps({'status':'FAIL' if errors else 'PASS','count':len(report),'errors':errors,'images':report},indent=2),encoding='utf-8')
if errors: raise SystemExit('\n'.join(errors))
print('DRAGON_BALL_ART_QA: PASS - 20 individual transparent PNG files')
