"""Author the deterministic campaign/tower content catalog (no image editing)."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'encounters'
OUT.mkdir(parents=True, exist_ok=True)
ENEMIES = [
 'Batedor Goblin|Lanceiro Goblin|Xamã Goblin|Lobo da Floresta|Javali Chifrudo|Cogumelo Venenoso|Diabrete de Raiz|Ent de Espinhos|Besouro de Pedra|Slime Esmeralda|Bandido das Adagas|Arqueiro Bandido|Escudeiro Bandido|Mago Bandido|Chefe dos Bandidos|Vassoura Animada|Grimório Maldito|Armadura Assombrada|Gárgula Jovem|Morcego Demoníaco|Esqueleto Espadachim|Esqueleto Arqueiro|Cão de Ossos|Fantasma Aprendiz|Diabrete do Túmulo',
 'Lobo Glacial|Goblin da Geada|Golem de Gelo|Harpia da Neve|Cavaleiro Glacial|Escorpião das Dunas|Bandido do Deserto|Múmia Feiticeira|Golem de Arenito|Guerreiro Naja|Diabrete de Coral|Caranguejo Guardião|Soldado Tubarão|Elemental da Água|Cavaleiro Afogado|Slime de Lava|Diabrete de Fogo|Golem de Magma|Cão de Brasas|Feiticeiro das Cinzas|Espírito do Trovão|Falcão da Tempestade|Besouro Elétrico|Soldado da Tormenta|Elemental das Nuvens',
 'Duelista Elfo Sombrio|Arqueiro Elfo Sombrio|Bruxa Elfa Sombria|Pantera Sombria|Ent Amaldiçoado|Cultista Carmesim|Bruxo Mascarado|Acólito Demoníaco|Sentinela Chifruda|Verme do Abismo|Aranha de Cristal|Golem de Ametista|Mariposa de Joias|Cavaleiro de Cristal|Elemental do Prisma|Soldado Mecânico|Autômato de Latão|Cão de Engrenagens|Andarilho Rúnico|Mago Mecânico|Renegado Real|Clérigo Corrompido|Armadura Dourada|Grifo Rebelde|Assassino do Palácio',
 'Predador Abissal|Medusa do Vazio|Cavalo do Pesadelo|Ceifador Sombrio|Demônio da Chama Negra|Filhote de Dragão|Serpe Alada|Soldado Dracônico|Xamã Dracônico|Tartaruga de Obsidiana|Sentinela Celestial|Querubim Caído|Mago Astral|Lobo Lunar|Leão Solar|Médico da Peste|Slime Tóxico|Brutamontes Fúngico|Harpia Venenosa|Filhote de Hidra|Berserker Infernal|Cavaleiro Demoníaco|Feiticeiro do Caos|Golem do Vazio|Vigia Ancestral',
]
BOSSES = 'Rei Goblin|Lobo Alfa Ancestral|Ent Milenar|Senhor dos Bandidos|Arqui-Lich|Titã Glacial|Rainha das Harpias|Imperador Escorpião|Faraó das Dunas|Serpente do Deserto|Kraken Abissal|Rei dos Tubarões|Leviatã das Marés|Colosso de Magma|Fênix das Cinzas|Dragão da Tempestade|Rei dos Elfos Sombrios|Aranha Rainha de Cristal|Imperador Autômato|Grifo Dourado|Ceifador do Eclipse|Dragão de Obsidiana|Hidra Venenosa|Anjo Caído|Leão Solar Ancestral|Arquidemônio das Chamas|Titã do Vazio|Serpente Cósmica|Rei do Caos|Guardião do Último Grimório'.split('|')
SCENES = 'Clareira de Hage|Bosque dos Grimórios|Ruínas da Vila|Estrada dos Bandidos|Cemitério Esquecido|Vale da Geada|Santuário Glacial|Dunas Douradas|Templo Soterrado|Oásis das Serpentes|Costa dos Corais|Porto das Marés|Templo Submerso|Ponte Vulcânica|Caldeira das Cinzas|Penhasco da Tempestade|Floresta Sombria|Jardim dos Cristais|Fábrica Rúnica|Pátio do Palácio|Necrópole do Eclipse|Fortaleza de Obsidiana|Pântano Venenoso|Catedral Caída|Santuário Solar|Abismo das Chamas|Escadaria do Vazio|Observatório Astral|Trono do Caos|Biblioteca Ancestral|Jardim Suspenso|Cânion Rubro|Mosteiro da Lua|Vale dos Cogumelos|Palácio de Jade|Fortaleza de Diamante|Desfiladeiro dos Dragões|Ilhas Celestiais|Portal das Sombras|Coração do Grimório'.split('|')
SKILLS = ['Corte Maldito','Rajada Selvagem','Pulso Restaurador','Golpe Esmagador','Explosão Arcana','Descarga Rúnica']
catalog = {'version':1, 'rules':{'campaign_boss_every':10,'tower_boss_every':5,'campaign_scene_every':10,'tower_scene_every':5}, 'enemies':[], 'bosses':[], 'scenes':[]}
for group, names in enumerate(ENEMIES):
 for cell,name in enumerate(names.split('|')):
  i=group*25+cell; behavior=i%6
  catalog['enemies'].append({'id':i,'name':name,'sheet':f'enemies-{group+1:02}.png','cell':cell,'columns':5,'rows':5,'behavior':behavior,'element':behavior,'skill':SKILLS[behavior],'hp':1.0+(i%5)*0.09,'attack':0.85+(i%7)*0.055})
for i,name in enumerate(BOSSES):
 catalog['bosses'].append({'id':i,'name':name,'sheet':f'bosses-{i//10+1:02}.png','cell':i%10,'columns':5,'rows':2,'behavior':i%6,'element':i%6,'skill':['Cataclismo','Fúria Ancestral','Ruptura do Mana','Julgamento','Devastação'][i%5],'hp':3.0+(i%5)*0.25,'attack':1.35+(i%4)*0.1})
for i,name in enumerate(SCENES):
 catalog['scenes'].append({'id':i,'name':name,'sheet':f'scenery-{i//10+1:02}.png','cell':i%10,'columns':2,'rows':5})
biomes = [(0,10),(0,10),(10,20),(10,15),(20,25),(25,30),(25,30),(30,35),(30,35),(30,35),(35,40),(35,40),(35,40),(40,45),(40,45),(45,50),(50,60),(60,65),(65,70),(70,75),(75,80),(80,85),(90,95),(85,90),(85,90),(95,100),(75,80),(85,90),(95,100),(15,25),(85,90),(30,35),(75,80),(90,95),(50,55),(60,70),(80,85),(45,50),(75,80),(95,100)]
for scene,(start,end) in zip(catalog['scenes'],biomes):
 scene['enemy_pool'] = list(range(start,end))
assert len(catalog['enemies'])==100 and len(catalog['bosses'])==30 and len(catalog['scenes'])==40
(OUT/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2),encoding='utf-8')
print('Catalog: 100 enemies, 30 bosses, 40 environments')
