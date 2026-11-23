Atlas compartilhado de ataques - Godot e Phaser 4

elements-atlas.png: 1024 x 1536, RGBA transparente.
Grade: 4 colunas x 6 linhas; cada quadro mede 256 x 256 pixels.
Linhas: antimagia, vento, agua, escuridao, fogo, eletricidade.
Colunas: carga, golpe, impacto, particulas finais.
Ataque normal: quadros 1, 2, 3. Especial: quadros 0, 1, 2, 3.

Godot: scripts/visuals/combat_sprite_fx.gd, integrado em clover_idle.gd.
Phaser 4: phaser/combat-sprite-fx.mjs, integrado em phaser/main.js.
O adaptador Phaser registra animacoes e remove os sprites ao terminar.

Direcao de arte usada na geracao:
Transparent sprite sheet for a premium 3D chibi anime fantasy RPG.
Exact four columns and six rows, isolated effects with generous padding.
Each row shows charge, directional slash, impact burst, fading motes.
Rows: black-red antimagic, emerald wind, blue water dragon, violet dark
magic, orange fire, cyan-yellow lightning. Consistent polished volumetric
lighting, clean readable silhouettes, no characters, text, UI or borders.
