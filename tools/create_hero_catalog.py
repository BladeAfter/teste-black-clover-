"""Author the 100 original heroes; existing Black Clover IDs stay unchanged."""
import json
from pathlib import Path
OUT=Path(__file__).resolve().parents[1]/'assets'/'roster'
OUT.mkdir(parents=True,exist_ok=True)
NAMES=[
'Kael|Ignia|Brann|Cindra|Orven|Solara|Ravel|Ambera|Danteo|Seraphina',
'Nerio|Marielle|Borgan|Talia|Ondren|Coralia|Pelian|Nymia|Torran|Aqualis',
'Zephir|Aelina|Galdor|Veyra|Eolmar|Sylphia|Arvent|Celina|Tavren|Aurelia',
'Doran|Petra|Granvik|Sienna|Rochan|Terrina|Flint|Adara|Basalt|Georia',
'Raiken|Voltara|Thorgun|Zyra|Fulgar|Electra|Veyron|Lumira|Storman|Raelia',
'Iskar|Nevia|Frostan|Cryssa|Glacien|Eirwen|Nivor|Alva|Hailan|Ysilra',
'Lucan|Aurielle|Helion|Elara|Dayron|Solenna|Lior|Clariel|Phoeran|Luxara',
'Noctis|Nyxara|Duskhan|Umbra|Morthen|Vespera|Ravik|Nerissa|Tenebran|Eclipsia',
'Sylvan|Florielle|Oakren|Thalya|Verdan|Lysena|Briar|Roselia|Thornan|Gaiana',
'Azer|Valkira|Bastion|Kuroha|Nullen|Revena|Silas|Abyssia|Zerkan|Oblivienne']
ELEMENTS=['Fogo','Água','Vento','Terra','Relâmpago','Gelo','Luz','Trevas','Natureza','Antimagia']
COLORS=['f29164','78cff1','8ad9a1','c5a675','f7d975','a4e6ef','fff0a0','ba97ed','8cd17b','e97691']
VFX=[4,2,1,1,5,2,5,3,1,0]
ROLES=['Guerreiro','Mago','Guardião','Assassino','Mago','Guerreiro','Arqueiro','Suporte','Lutador','Mago']
PATTERNS=[0,1,3,5,4,0,5,2,3,4]
RARITIES=['Incomum']*2+['Raro']*3+['Épico']*3+['Lendário']*2
SKILLS=['Lâmina','Espiral','Bastião','Dança das Adagas','Cataclismo','Lança','Flecha','Bênção','Punho','Julgamento']
data={'version':1,'original_heroes':6,'summon_weights':{'Incomum':50,'Raro':30,'Épico':17,'Lendário':3},'elements':ELEMENTS,'rarities':['Incomum','Raro','Épico','Lendário'],'heroes':[]}
for element,names in enumerate(NAMES):
 for order,name in enumerate(names.split('|')):
  index=element*10+order
  rarity=RARITIES[order]
  rank=data['rarities'].index(rarity)
  data['heroes'].append({'id':index+6,'name':name,'element':ELEMENTS[element],'element_id':element,'color':COLORS[element],'rarity':rarity,'stars':rank+2,'role':ROLES[order],'behavior':PATTERNS[order],'vfx':VFX[element],'skill':f'{SKILLS[order]} de {ELEMENTS[element]}','hp':1.0+rank*.08+(.12 if order==2 else 0),'attack':1.0+rank*.07+(.08 if order in [3,8] else 0),'sheet':f'heroes-{index//25+1:02}.png','cell':index%25,'columns':5,'rows':5,'origin':'Cavaleiro original'})
assert len(data['heroes'])==100
assert len({h['name'] for h in data['heroes']})==100
(OUT/'catalog.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
print('100 heroes: 20 uncommon / 30 rare / 30 epic / 20 legendary; 10 per element')
