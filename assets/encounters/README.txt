ENCONTROS DA CAMPANHA E TORRE

100 inimigos, 30 chefoes e 40 cenarios com artes proprias.
Artes geradas com a ferramenta imagegen integrada. Prompts: art-prompts.json.
Dados editaveis: catalog.json. Logica: scripts/activities/encounter_catalog.gd.

Campanha: chefe a cada 10 fases; cenario muda a cada 10 fases.
Torre: chefe a cada 5 andares; cenario muda a cada 5 andares.
Os intervalos ficam em rules no catalog.json.
Os 30 chefes aparecem ate a fase 300 / andar 150.
Os 40 cenarios aparecem ate a fase 391 / andar 196.
Depois o catalogo cicla, mantendo o aumento gradual de dificuldade.
A torre percorre os mesmos cenarios em uma ordem deslocada da campanha.
Cada encontro tem cinco adversarios; encontros de chefe incluem quatro guardas.
Repetir uma fase ou andar mantem os mesmos adversarios.
Progressao anterior e arquivos de save continuam compativeis.

Sprites: enemies-01 a enemies-04, cada atlas 5 colunas x 5 linhas.
Chefes: bosses-01 a bosses-03, cada atlas 5 colunas x 2 linhas.
Cenarios: scenery-01 a scenery-04, cada atlas 2 colunas x 5 linhas.
As regioes sao calculadas pela dimensao real da imagem (nao por tamanho fixo).
O jogo carrega e guarda cada atlas em cache conforme necessario.
Todos os inimigos compartilham seis familias de animacao/efeito de ataque;
nomes, sprites, atributos e nomes dos golpes estao definidos por entrada.

Validacao: tools/encounters_qa.gd testa contagem, unicidade, alcance dos
catalogos, cadencia, limites dos atlas, spawns reais e progressao da torre.
