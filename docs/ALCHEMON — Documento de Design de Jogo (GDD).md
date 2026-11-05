# ALCHEMON — Documento de Design de Jogo (GDD)

**Versão de protótipo — atualizada com o estado real do código** (repositório `mnedel-ops/TCC-Jogo`, branch `main`, Godot 4.6, renderer GL Compatibility, física Jolt).

Creature capture baseado na Tabela Periódica. Este documento mantém o design original e acrescenta, em cada seção, o que **já existe no código**, onde está (arquivo/classe/função) e onde o código **diverge** do design.

**Legenda de status:** \[OK\] Implementado · \[Parcial\] Parcial ou diverge do design · \[Pendente\] Não implementado (planejado) · \[Extra\] Implementado, mas não previsto no GDD original

---

## 0. Resumo do estado do protótipo

| Área | Status | Observação |
| --- | --- | --- |
| Cenas, portas e spawn | \[OK\] | `SceneManager`, `SceneDoor`, 2 fases de teste |
| Exploração (movimento, interação, câmera) | \[Parcial\] | Sem corrida; sem F5/F9; câmera com zona morta |
| Encontros selvagens e de treinador | \[Parcial\] | Por tempo (não por passo); área de colisão (não cone de visão) |
| Combate 2×2 por turnos | \[OK\] | Máquina de fases, iniciativa, ataque/item/captura/fuga |
| Tipos e efetividade | \[OK\] | Ciclo ×1,5 / ×0,66 / ×1,0 |
| Atributos, IV, personalidade | \[Parcial\] | Fórmula de HP difere; personalidade é extra |
| Temperatura e estado físico | \[Parcial\] | Aquecimento e mudança de estado existem; regras de dano nulo e Laço por temperatura não |
| Misturas e Compostos | \[Parcial\] | Funcionam com 2 elementos; sem Compostos de 3+ e sem ruptura por temperatura |
| Captura | \[Parcial\] | Fórmula \[OK\]; métodos de separação são placeholders por tipo |
| XP e níveis | \[OK\] | XP segue a fórmula $N^3$|
| Obediência por insígnias | \[Pendente\] | Insígnia existe e é concedida; obediência não |
| Economia (moeda, loja) | \[Parcial\] | Moeda \[OK\]; loja abre mas Comprar/Vender são "Em breve" |
| PC / Armazenamento | \[Parcial\] | Troca de time e Compostos \[OK\]; sem caixas e sem troca de ataques |
| Cura / Hospital | \[Parcial\] | NPC curandeiro e teleporte na derrota  \[OK\]; sem hospital como cena|
| Salvamento | \[OK\] | JSON atômico + backup, posição, inventário, NPCs derrotados |
| Menus e interface | \[Parcial\] | Menu unificado \[OK\]; entradas diferem do GDD |
| Testes automatizados | \[Extra\] | 74 testes GdUnit4 |

---

## 1. Visão Geral

Alchemon é um jogo de captura de criaturas cujas mecânicas traduzem regras da Química Geral para o gameplay. Cada criatura representa um elemento químico e seus atributos derivam de propriedades químicas desse elemento.

### 1.1 Público-Alvo

- Estudantes do Ensino Médio
- Adultos interessados em Química
- Entusiastas do gênero creature capture

### 1.2 Estética e Áudio

Modelos poligonais no estilo PSX, inspirados visualmente em Digimon World. Trilha de tom aventuresco. *Status: \[OK\] visual 3D low-poly; áudio não verificado no código.*

### 1.3 Objetivos do Jogador

- Coletar insígnias de ginásio — \[Parcial\] `PlayerData.award_badge()` e `BadgeData` existem; 1 insígnia (Metal) cadastrada.
- Derrotar o campeão da Super Liga — \[Pendente\]
- Localizar criaturas raras ou lendárias — \[Pendente\]
- Recuperar elementos artificiais fugitivos — \[Pendente\]

---

## 2. Estrutura do Jogo e Cenários

Jogo dividido em cenários independentes (sem mundo aberto contínuo). Tudo roda dentro de `scenes/main.tscn`, que contém `Player`, `CameraRig`, `FollowerManager`, `SceneManager`, `CombatSceneManager`, `LevelHolder` e `BattleAnchors`. Autoloads: `GameSession` e `CombatSignal`.

### 2.1 Transição entre Cenários — \[OK\]

- `SceneDoor` (Area3D, `porta.gd`) possui `target_level_path` e `target_spawn_point`. Ao detectar o jogador (grupo `player`), chama `SceneManager.change_level()`.
- `SceneManager.change_level(scene, spawn)`: remove a fase atual, instancia a nova em `LevelHolder` e posiciona o jogador no `Marker3D` de destino (`_place_player`), recentralizando a câmera.
- `SceneManager.get_save_position()` e `_resume_saved_position()` permitem retomar fase, posição e rotação após carregar um save.
- Fases existentes: `scene_1.tscn` (NPCs, loja, curandeiro, ginásio, mato alto) e `scene_2.tscn`.
- *Em aberto (mantido):* evitar posicionar a porta de entrada sobre a área de saída para não gerar loop de transição.

---

## 3. Exploração

### 3.1 Controles

O jogador é um `CharacterBody3D` (`player.gd`) composto por `MovementComponent`, `InteractionComponent`, `InventoryComponent` e `CombatHandler`.

| Tecla | Ação | Status |
| --- | --- | --- |
| W/A/S/D (e setas/direcional) | Caminhar em 8 direções (`move_*`, `Input.get_vector`) | \[OK\] (velocidade fixa 5.0) |
| Correr | Corrida | \[Pendente\] não há ação de corrida |
| E (`ui_interact`) | Interagir com item, NPC, PC | \[OK\] |
| Tab (`ui_menu`) | Abre o menu unificado do jogo | \[Parcial\] no GDD era "inventário"; hoje abre o menu completo |
| Esc (`ui_cancel`) | Voltar/fechar menu | \[Parcial\] no GDD abria configurações |
| F5 / F9 | Salvar / carregar rápido | \[Pendente\] não há ação mapeada |

Nos menus e popups o código também aceita setas, Enter/Espaço e botões de gamepad; o GDD previa só teclado.

### 3.2 Câmera — \[Parcial\]

`CameraRig` mantém altura fixa e ângulo fixo, sem controle do jogador. Diferente do GDD, ela **segue com zona morta** (`dead_zone`, `follow_speed`, `snap_distance`) em vez de ficar rigidamente atrás do avatar. A rotação do avatar é instantânea (`mesh.rotation.y = atan2(...)`), sem suavização — \[OK\] conforme o GDD.

### 3.3 Movimentação e Bloqueios — \[OK\]

Colisões do cenário bloqueiam o jogador; não há pulo (apenas gravidade). Camadas físicas: Player, Environment, Item, NPC. Quedas de borda controladas não foram verificadas.

### 3.4 Interação com Itens e NPCs

- **Itens:** `InteractableItem` (grupo `collectible`) entra na área do `InteractionComponent`; ao pressionar E, `InventoryComponent.collect_from_area()` adiciona o item à mochila (`InventoryData.add_item`) e remove o objeto. \[OK\]
- **NPCs (`npc.gd`)**: diálogo com texto digitado (`DialogueBox`: `show_text`, `skip_typing`, `close`). \[OK\] Além de falar, o NPC pode assumir papéis \[Extra\]: **treinador**, **líder de ginásio**, **lojista** e **curandeiro**, configurados por `NPCSpawnPoint` e instanciados por `Level.place_npcs()`. Cada NPC recebe um ID estável (`fase/marcador`) usado para lembrar derrotas.
- Caixa de diálogo com opções Sim/Não existe (`DialogueBox.ask`) — usada pelo curandeiro. O GDD previa diálogo apenas unidirecional.

### 3.5 Estruturas do Mapa — \[Parcial\]

Casas, hospitais, lojas e ginásios ainda **não são cenas separadas**: loja, centro de cura e líder de ginásio são NPCs dentro de `scene_1`.

### 3.6 Mapas — \[Pendente\]

Não há mapa-múndi nem mapas de cidade. O item de menu "Table" é a Tabela Periódica/Wiki (ver seção 18).

---

## 4. Início de Combate

O evento é `CombatSignal.combat_start(a, b)`; `CombatSceneManager._on_combat_start()` cria a cena de combate, move os atores para os `BattleAnchors` e injeta equipe, inventário, banco de espécies, armazenamento e vínculo.

### 4.1 Encontros com Treinadores — \[Parcial\]

`NPC._on_combat_area_entered()` inicia o combate quando o jogador entra na `CombatCollision` do NPC (uma área, **não um cone de visão**). Define `is_trainer_battle = true`, nível e as duas espécies. Só ocorre se `GameSession.can_fight()` (há criatura viva). Após a vitória, `mark_defeated()` desativa o NPC e grava o ID no save; em líder de ginásio, concede a insígnia.

### 4.2 Encontros Selvagens — \[Parcial\]

`WildernessEncounter` (Area3D com polígono editável) usa uma **rolagem por tempo**, não por passo:

- `check_interval` (1 s) e `encounter_chance` (30%) configuráveis; exige movimento do jogador (`require_movement`).
- Rola um encontro também ao entrar na área; respeita `cooldown` (3 s) após o combate; nunca durante outro combate.
- Duas decisões: chance de lutar → espécie sorteada de `alchemons[]` (uniforme) com nível sorteado entre `min_level` e `max_level`.
- *Em aberto:* tabelas por área com pesos e níveis definitivos (a lista atual é uniforme).

---

## 5. Combate

Formato 2×2 — \[OK\] (`BattlefieldSlot`: 2 slots do jogador e 2 do oponente; `Battlefield`, `BattlefieldRules`).

### 5.1 Fluxo do Turno — \[OK\]

Máquina de fases `BattlePhaseMachine`: `ENCOUNTER_START → SELECTING_ACTIONS → RESOLVING_ACTIONS → END_OF_ROUND → (SELECTING_ACTIONS | COMBAT_OVER) → VICTORY | DEFEAT`. Transições inválidas são rejeitadas (`is_valid_transition`).

1. **Ordem:** `CombatRules.roll_initiative()` calcula a iniciativa de cada criatura e ordena de forma decrescente em `turn_order_ids`. \[Parcial\] É calculada **uma vez no início do combate**, não a cada rodada.
2. **Seleção:** o jogador escolhe ação e alvo de cada criatura (uma por vez) em `BattleCommands`; a IA enfileira em `_queue_enemy_commands()` (ataque e alvo aleatórios). `CombatRules.has_all_commands()` garante que todas as criaturas ativas tenham comando antes de resolver.
3. **Resolução:** `CombatRules.resolve_action()` produz um `CombatResult`; **somente** `CombatResultApplier.apply()` altera o `CombatState`. Alvo morto é redirecionado (`_retarget_if_dead`).
4. Repete até um lado ficar sem criaturas vivas (`CombatRules.check_combat_end()`).

### 5.2 Ações do Turno — \[Parcial\]

- **Ataque** \[OK\]: o menu lista até 4 ataques da espécie (`MAX_ATTACKS = 4`). Hoje cada espécie cadastrada tem 3.
- **Item** \[OK\]: usa item da mochila em aliado (`_resolve_item`); consome o item. Os itens atuais são genéricos (`heal_amount = 0`); a Poção real ainda não existe.
- **Captura** \[OK\] (ver seção 11), bloqueada em batalha de treinador.
- **Fuga** \[Parcial\]: chance fixa 5/6 (`FLEE_CHANCE`) \[OK\]. Se falha, os inimigos atacam. O código **não restringe fuga a criaturas selvagens**.
- **Slap** \[Extra\] \[OK\]: quando `valence_electrons <= 0`, qualquer ataque vira SLAP (poder 10, custo 0, neutro, sem aquecer a arena).

### 5.3 Fim de Combate — \[Parcial\]

- `BattleRewards.build()` monta a tela de recompensas (`BattleRewardsScreen`), exibida **antes** de `combat_ended` liberar a exploração. \[OK\]
- **Vitória:** XP e, contra treinador, 100 moedas (`TRAINER_WIN_MONEY`). Selvagens não dão moeda. \[Parcial\] O GDD diz "ganho de EXP e moeda" em toda vitória.
- **Derrota:** o combate encerra e volta à exploração. \[Pendente\] **Não há teletransporte ao último hospital**; a cura é manual no NPC curandeiro. Criaturas com 0 HP não entram no próximo combate (`REVIVE_FAINTED_ON_BATTLE_START = false`) e `can_fight()` impede novos combates sem criatura viva.
- Não há evolução nem fusão permanente. \[OK\]

---

## 6. Sistema de Tipos — \[OK\]

`AlchemonType`: Metal, Ametal, Metaloide. Ciclo Metal > Metaloide > Ametal > Metal. Multiplicadores: `SUPER_EFFECTIVE = 1.5`, `RESISTED = 0.66`, `NEUTRAL = 1.0`. A efetividade usa o **tipo do ataque** contra o **tipo da espécie alvo** (`AlchemonType.effectiveness`). O mesmo tipo é neutro.

---

## 7. Atributos

### 7.1 Correspondência Química — \[Parcial\]

A estrutura existe em `AlchemonSheet` (`atomic_mass`, `max_hp`, `base_attack`, `base_defense`, `base_mechanical_speed`, `base_action_energy`, `max_valence_electrons`, `octet_target`). **Os valores atuais são placeholders** (ex.: base 70 padrão) e ainda não derivam das propriedades químicas reais.

### 7.2 Fórmulas — \[Parcial\]

`AlchemonFormulas.compute_stat(base, iv, level) = floor(0,01 × (2×base + IV) × nível) + 5` \[OK\] (Ataque, Defesa, Velocidade Mecânica).

**HP — diverge:** `compute_max_hp = base_hp + compute_stat(nível) − compute_stat(1)`. No nível 1 o HP é igual ao HP base da ficha; a fórmula do GDD (`floor(...) + nível + 10`) **não** é usada. *Decisão pendente: atualizar o código ou o GDD.*

IV: sorteado de 1 a 31 por `CreatureFactory.create()` e guardado na criatura. Sem EV. \[OK\] Atributos derivados **não são salvos**: são recalculados por `AlchemonInstance.compute_stats()` no início de cada combate.

&#91;Extra\] **Personalidade** (`AlchemonPersonality`): neutral, bold, stoic, hasty, calm, keen. Cada uma dá +10% em um atributo e −10% em outro. Sorteada na criação. Não estava no GDD original.

### 7.3 Energia de Ação — \[Parcial\]

O recurso em combate é `valence_electrons` (máximo = `max_valence_electrons` da espécie). É gasto por ataque (`energy_cost`, padrão 2) e persiste entre combates (`PERSIST_ENERGY`). Recarrega no curandeiro (`GameSession.heal_party`). \[Parcial\] O GDD diz que a energia também **diminui ao sofrer golpes**; o código não faz isso. Sem energia → SLAP \[OK\].

---

## 8. Temperatura da Arena

### 8.1 Regras Gerais — \[Parcial\]

- Valor interno em Kelvin; HUD mostra "Temperatura da Arena: X K" \[OK\].
- &#91;Parcial\] Valor inicial: **273,15 K** (`CombatState.arena_temperature`); o GDD prevê 25 °C (298,15 K).
- Afeta todas as criaturas em campo \[OK\].
- Golpes que acertam somam `compute_temperature_delta = (nível/10 + 1) × (poder/10) × (ataque/100)`. \[Parcial\] Sem `floor` (valor decimal); o GDD usa `floor`. Slap não aquece. O GDD diz que golpes **recebidos** também alteram; o código aplica o aumento uma vez por golpe que acerta.

### 8.2 Mudança de Estado Físico — \[Parcial\]

`AlchemonSheet.state_at(temp)` retorna sólido (≤ ponto de fusão `temperature`), líquido (≤ `boiling_point`) ou gasoso. `CombatResultApplier._apply_arena_heat()` reavalia o estado de cada criatura viva; ao mudar, emite `arena_hotter_than_myself` e causa **5 de dano** (`STATE_CHANGE_DAMAGE`). Cátions de Composto são imunes. \[Pendente\] Não implementado: alteração proporcional de atributos por estado e a regra de "fora do estado ativo = não causa nem sofre dano".

### 8.3 Ruptura de Laço por Temperatura — \[Pendente\]

No código, um Composto só se desfaz quando o **Ânion cai** (`BondRules.release_compound_partners`). A Energia de Dissociação de Ligação ainda não é usada.

---

## 9. Laços entre Alchemons

O jogador define o vínculo no PC (`PlayerBondData`: `kind` + índices). Ao iniciar o combate, `CombatStateFactory._apply_player_bond()` revalida e aplica; a IA também forma laços (`_try_bond`). Bônus ficam só no estado transitório de batalha e **não vazam** para a criatura salva.

### 9.1 Misturas — \[Parcial\]

`AlchemyStation.is_mixture()`: duas criaturas **Metal**. `BondRules.MIXTURE_BONUS = 8`, aplicado a **HP máximo e energia máxima** (e valores atuais) de ambos. \[Parcial\] O GDD diz "todos os atributos".

### 9.2 Compostos — \[Parcial\]

`AlchemyStation.validate_stoichiometry()` valida a Regra do Octeto:

- **Iônico** (metal + não metal): elétrons doados = elétrons necessários (`octet_target − max_valence_electrons`).
- **Covalente** (sem metal): `(Σ octeto − Σ valência)` par e ≥ `n − 1` ligações.
- O PC informa se a combinação é possível, sem ensinar a resposta ("Seu Composto foi criado!").
- Ativo: `BondRules._pick_active_index` — maior nível; se houver Metal, o Metal é o **Cátion** (`is_bond_cation`: invisível, inalvejável, imune).
- O membro ativo recebe `COMPOUND_TRANSFER_RATIO = 0,7` do HP máximo e da energia do outro. \[Parcial\] O GDD diz "70% de todos os atributos".
- Se o ativo cai, os parceiros são liberados com 30% do HP (`COMPOUND_RELEASE_HP_RATIO`) e a energia do caído.
- &#91;Parcial\] **Limitação:** `validate_stoichiometry` aceita apenas **2 elementos**; o exemplo H₂O (3 criaturas) ainda não é possível, embora `BondRules` já trate grupos maiores. Ainda não verificado se o Ânion é mostrado como "ativo" na UI do jogo além do rótulo do HUD.

---

## 10. Ataques

`AttackData`: `indexAttack`, `attack_name`, `power`, `energy_cost` (padrão 2), `element_type`. \[Parcial\] **Faltam** probabilidade de acerto e de crítico por ataque (o código usa valores globais). Ataques existentes: Tackle, Scratch, TailStrike, SLAP e ataques de debug. Cada espécie tem **3** ataques, não 4. Aprendizado de ataques por nível \[Pendente\].

### 10.1 Dano — \[OK\]/\[Parcial\]

`compute_damage = ((((2×nível/5 + 2) × poder × atq/def) / 50) + 2) × efetividade`, defesa mínima 1, resultado ≥ 0. Fórmula conforme o GDD. \[OK\]

### 10.2 Crítico — \[Parcial\]

`CRIT_CHANCE = 12,5%` \[OK\]. Multiplicador **fixo 1,5** (`CRIT_MULTIPLIER`); o GDD prevê `(2×nível + 5)/(nível + 5)`. Existe também **chance de erro global de 1/6** (`MISS_CHANCE`) no lugar da probabilidade por ataque.

### 10.3 Incremento de Temperatura — \[Parcial\]

Ver seção 8.1.

### 10.4 Iniciativa — \[OK\]

`compute_initiative = floor(((velocidade + IV) × 2 × nível) / 100) + 5`.

---

## 11. Captura de Criaturas Selvagens

### 11.1 Fluxo — \[Parcial\]

1. A interface envia o comando `capture` com um item de método de separação (`ItemData.is_capture_method`).
2. `CombatRules._resolve_capture()` valida alvo (inimigo vivo) e método.
3. **Método correto:** `tool_multiplier` = 255 se `capture_type` = tipo da espécie; 127 se errado. \[Parcial\] Hoje há 3 métodos placeholder (Metal, Ametal, Metaloide), **não** métodos físicos/químicos reais. O GDD exige perder o turno com dica textual no método incorreto — \[Pendente\] (hoje só reduz a chance).
4. Captura bloqueada em batalha de treinador (`CAPTURE_BLOCKED_TEXT`). \[OK\]
5. Em Composto inimigo, a regra de romper o laço antes de capturar o Cátion \[Pendente\].

### 11.2 Fórmula — \[OK\]

`compute_capture_value(hp_max, hp_atual, X) = max(floor((3·HPmax − 2·HPatual) × X / (3·HPmax)), 1)`, limitado a 255, com redução de 8 bits (duas divisões inteiras por 2) quando `3·HPmax > 255`. Rolagem `randi_range(0, 254)`; sucesso se `roll < a`.

### 11.3 Resultado da captura — \[Extra\]

`CombatResultApplier._apply_capture()` guarda **a mesma instância** combatida (`CombatState.enemy_instances`): UID, IV, personalidade e HP. A criatura nunca é armazenada com 0 HP (mínimo 1). Depois é transferida para `CapturedStorage`. O item é consumido a cada tentativa.

---

## 12. Progressão de Nível e Experiência

- **Nível:** \[Parcial\] não há teto de nível 20 no código.
- **Level up** (`AlchemonGrowth.level_up`): recalcula ataque, defesa e velocidade, aumenta o limite de energia (sem restaurar a atual) e o HP máximo (somado ao HP atual se vivo). Múltiplos níveis por recompensa \[OK\].
- **XP necessário:** \[Parcial\] fixo, `XP_TO_LEVEL_UP = 100` por nível, com sobra preservada.
- **XP ganho:** \[Parcial\] vem de `xp_reward` da espécie derrotada (padrão 100). A fórmula do GDD (seção 12.1) **não está implementada**.
- **Distribuição:** \[Parcial\] `_grant_xp` concede XP **somente à criatura que derrotou/capturou** o alvo, e não igualmente às duas.
- Tela de recompensas mostra XP, level up e moedas \[OK\] (`BattleRewards.entries`).

### 12.3 Obediência por Insígnias — \[Pendente\]

Não há chance de desobediência. Existem apenas `BadgeData`, `PlayerData.award_badge()` (retorna `false` se já obtida) e a exibição na página do jogador. Insígnia atual: **Insígnia do Metal**, concedida ao vencer o NPC `is_gym_trainer`.

---

## 13. Economia

### 13.1 Moeda — \[Parcial\]

`PlayerData.money` inicia em **500**; `add_money()` nunca fica negativo. Vitória contra treinador = 100. Venda de itens \[Pendente\].

### 13.2 Itens — \[Parcial\]

`ItemDatabase` e `ItemData` (`index`, `nome`, `descricao`, `icone`, `heal_amount`, `is_capture_method`, `capture_type`). Cadastrados: 2 itens genéricos e 3 "métodos" de captura. Poção e Recuperador de Energia ainda **não existem como dados**.

### 13.3 Lojas — \[Parcial\]

NPC lojista abre `ShopDialogueBox` com Comprar / Vender / Sair, mas Comprar e Vender exibem "(Em breve...)". Custos \[Pendente\].

---

## 14. Armazenamento de Criaturas (PC)

`PCStation` (`pc.gd`) abre `pc_ui` ao pressionar E, travando o jogador. Páginas: **Alchemy**, **Stored**, **Exit**.

- **Time:** `max_party_size = 2` \[OK\]; não permite esvaziar o time (mínimo 1).
- **Stored:** troca entre time e `CapturedStorage` conservando a instância (UID, nível, XP, IV, HP). \[OK\]
- **Alchemy:** seleciona 2 criaturas, valida e cria Mistura/Composto. \[OK\]
- &#91;Parcial\] Armazenamento é uma **lista sem caixas** (o GDD prevê 5 caixas × 30 = 150).
- &#91;Pendente\] Troca de ataques equipados.
- &#91;Parcial\] O PC está em cena e **não exige hospital**.

---

## 15. NPCs e Diálogo

Ver 3.4. Diálogo de duas falas (`dialogue` / `dialogue_defeated`) para treinadores e extra `dialogue_healed` para curandeiro. \[OK\]

---

## 16. Hospital / Cura — \[Parcial\]

NPC curandeiro (`is_healer`): pergunta Sim/Não, espera 2,5 s e chama `GameSession.heal_party()`, que restaura HP e energia de todas as criaturas (gratuito \[OK\]). \[Pendente\] Teletransporte ao último hospital, rastreamento do último hospital e cena de hospital.

---

## 17. Sistema de Salvamento — \[OK\]

`GameSession` (autoload) e `SaveGame`:

- Manual pelo item **Save** do menu; arquivo `user://saves/slot_1.json`. \[Pendente\] Atalho F5.
- `SaveGame.serialize()` grava: equipe, armazenamento, vínculo (por UID), moedas, nome/time do jogador, tempo de jogo, insígnias, inventário, NPCs derrotados e posição (fase, x, y, z, rotação).
- `write_file()` é **atômico** (arquivo temporário + rename) e mantém `.bak`; `read_file()` recupera o backup se o principal estiver corrompido.
- `apply()` valida tudo **antes** de alterar o estado (versão futura ou dados malformados não mudam nada), repara UIDs duplicados e descarta criaturas sem espécie.
- Menu inicial: Novo Jogo (com confirmação de sobrescrita), Carregar e Sair. `autosave` existe e vem desligado.

---

## 18. Interface e Menus

### 18.1 Navegação — \[Parcial\]

Nos menus: W/S movem (`menu_up/down`), E confirma (`menu_interact`), D abre sublista (`menu_right`), Esc volta. A tecla A (`menu_left`) está mapeada. Também há suporte a mouse nas listas.

### 18.2 Menu do Jogo — \[Parcial\]

`GameMenu` unificado (pausa + menu) com itens modulares ícone + nome:

| Item implementado | Corresponde no GDD | Conteúdo |
| --- | --- | --- |
| **Table** | Wiki (Tabela Periódica) | Lista de espécies por massa atômica, ficha, estatísticas e prévia 3D girando |
| **Bag** | Bag | Itens empilhados, detalhe do item |
| **Alchemons** | Alchemon | Cartões do time, estatísticas, ataques e informações |
| **Player** | Name | Nome, equipe, moedas, tempo de jogo e insígnias |
| **Save** | Save | Salva e mostra aviso "Game saved." |
| **Exit** | Exit | Fluxo de saída |

&#91;Parcial\] "Options" não existe. O menu é exibido como lista, mas a posição "lado direito da tela" não foi verificada.

### 18.3 Submenu Exit — \[OK\]

`ExitFlowComponent`: 1º pop-up "Do you wish to exit without saving?" (Yes/No) → 2º pop-up "You want to exit the game?" (Exit/Cancel) → `get_tree().quit()`.

### 18.4 Interface de combate — \[Extra\]

`BattleCommands` (Ataque / Item / Fuga, com menu de captura dentro de Item), `CombatBalloons` (HUD de HP/energia/nível/XP por criatura), `CombatLogBox` (log), destaque de alvo (`TargetHighlight`) e indicadores `[Selvagem]`, `[Mistura]`, `[Cátion]`.

---

## 19. Elementos Disponíveis (Protótipo) — \[Parcial\]

Atualmente existem **3 espécies placeholder** (Metal, Ametal, Metaloide) + 1 espécie de debug (id 999). O objetivo de 6 elementos (2 Metais, 1 Ametal, 1 Metaloide, 1 Radioativo, 1 Artificial) e as lendárias \[Pendente\].

---

## 20. Ginásios — \[Parcial\]

Não há cena de ginásio. Existe **um NPC líder de ginásio Metal** em `scene_1` (nível 8, espécies 1 e 2) que concede a **Insígnia do Metal**. A obediência garantida até nível 10 \[Pendente\].

---

## 21. Notas Técnicas de Implementação (Engine) — \[OK\]

### 21.1 Inventário (atualização)

- `inventory.tres` (`InventoryData`): lista de índices de itens; `add_item`, `remove_item`, `get_quantity`, `get_stacked_view`.
- `ItemDatabase.tres`: itens indexados (`get_item(index)`).
- Itens coletáveis pertencem ao grupo global `collectible`.

### 21.2 Arquitetura por responsabilidade

| Pasta | Responsabilidade |
| --- | --- |
| `scenes/` | Cena principal, fases, portas, NPC spawn, `SceneManager`, `FollowerManager`, PC |
| `EXPLORATION/` | Jogador e componentes, câmera, NPC, encontros, estação de alquimia |
| `COMBAT/` | Estado, regras, fases, ações, recompensas, sincronização |
| `DATABASE/` | Espécies, instâncias, ataques, inventário, jogador, `SaveGame` |
| `INTERFACES/` | Menus, HUD, comandos de batalha, páginas |
| `autoload/` | `GameSession`, `CombatSignal` |
| `test/` | Testes GdUnit4 |

### 21.3 Princípio de separação

`CombatRules` calcula o resultado; `CombatResultApplier` é o único que altera `CombatState`; `CreatureSync` grava de volta nível, XP, HP e energia por **UID** (nunca pela posição). Recursos persistentes são alterados só nessas fronteiras.

---

## 22. Índice de Funções Implementadas

| Classe / arquivo | Funções principais |
| --- | --- |
| `AlchemonFormulas` | `compute_stat`, `compute_max_hp`, `compute_damage`, `compute_initiative`, `compute_temperature_delta`, `compute_capture_value` |
| `AlchemonType` | `effectiveness`, `type_name` |
| `AlchemonGrowth` | `grant_experience`, `level_up` |
| `CombatRules` | `roll_initiative`, `resolve_action`, `_resolve_attack/_item/_capture`, `resolve_flee`, `tool_multiplier`, `capture_roll_succeeds`, `check_combat_end`, `has_all_commands` |
| `CombatResultApplier` | `apply`, `_apply_damage`, `_apply_heal`, `_apply_capture`, `_apply_arena_heat`, `_grant_xp` |
| `BondRules` | `apply_bond`, `release_compound_partners` |
| `AlchemyStation` | `determine_bond_kind`, `is_mixture`, `validate_stoichiometry` |
| `BattlePhaseMachine` | `is_valid_transition`, `transition`, `force_phase` |
| `CombatStateFactory` | `build` (com vínculo do jogador e da IA) |
| `CombatSceneManager` | `_on_combat_start`, `_on_battle_finished`, `_on_combat_ended` |
| `BattleRewards` | `build`, `money_for` |
| `CreatureSync` | `apply_battle`, `write_back` |
| `CreatureFactory` | `create` (IV, personalidade, UID) |
| `AlchemonInstance` | `compute_stats`, `to_dict`, `from_dict`, `hp_or_full`, `is_fainted` |
| `CapturedStorage` / `PlayerPartyData` | `add_instance`, `remove_instance`, `find_by_uid` |
| `PlayerData` | `add_money`, `award_badge`, `get_play_time` |
| `GameSession` | `new_game`, `save_game`, `load_game`, `heal_party`, `can_fight`, `mark_npc_defeated`, `take_resume_position` |
| `SaveGame` | `serialize`, `apply`, `write_file`, `read_file` |
| `SceneManager` / `SceneDoor` | `change_level`, `get_save_position` |
| `WildernessEncounter` | `_roll` (por tempo) |
| `NPC` | `talk`, `open_healer`, `open_shop`, `mark_defeated` |
| `PCStation` / `pc_ui` | `open_pc`, troca de time, criação de Mistura/Composto |
| `GameMenu`, `TablePage`, `BagPage`, `AlchemonsPage`, `PlayerPage` | Menu unificado e páginas |

---

## 23. Testes Automatizados (GdUnit4) — \[Extra\]

| Suíte | Testes | Escopo |
| --- | --- | --- |
| `test_alchemonGrowth` | 4 | Fórmula de atributo, level up, energia, estado físico |
| `test_capture_formula` | 13 | Valor de captura, limites 1–255, redução de 8 bits, rolagem, ferramenta |
| `test_battle_rewards` | 11 | Moeda, XP, tela de recompensas, ordem de encerramento |
| `test_creature_persistence` | 39 | UID, JSON, saneamento, sincronização por UID, save/load, posição, inventário |
| `test_player_bond_combat` | 5 | Vínculo do jogador em combate, vínculo obsoleto, cátion inalvejável |
| `test_badges` | 4 | Insígnia concedida uma vez, busca por nome, `player.tres` |
| **Total** | **76** |  |

A documentação técnica completa, a matriz de QA (RF01–RF14) e os testes de performance estão em `docs/ARQUITETURA_E_TESTES.md`.

---

## 24. Divergências GDD × Código (decisões pendentes)

1. **HP:** fórmula do GDD (`+ nível + 10`) × fórmula do código (base + ganho por nível).
2. **Crítico:** multiplicador `(2L+5)/(L+5)` × fixo 1,5; acerto por ataque × erro global 1/6.
3. **XP:** fórmula `√A·A²…` × XP fixo da espécie e 100 por nível; XP para ambas × só para quem derrotou.
4. **Temperatura inicial:** 25 °C × 273,15 K; ΔT com `floor` × decimal.
5. **Mistura/Composto:** "todos os atributos" × só HP e energia.
6. **Derrota e cura:** hospital com teleporte × NPC curandeiro sem teleporte.
7. **Fuga:** só contra selvagens × permitida sempre.
8. **Câmera:** fixa atrás do avatar × zona morta com seguimento.
9. **Energia:** reduzida ao sofrer golpes × só ao atacar.
10. **Menu:** Wiki/Alchemon/Bag/Name/Save/Options/Exit × Table/Bag/Alchemons/Player/Save/Exit; Tab abre o menu completo.

---

## 25. Questões em Aberto (mantidas do GDD original)

### 25.1 Temperatura

- Fator de conversão entre Energia de Dissociação (kJ/mol) e Kelvin para ruptura de laço.
- Proporção de alteração de atributos por estado físico.
- Unidades alternativas no HUD em confrontos especiais.

### 25.2 Misturas e Compostos

- Percentual de incremento da Mistura (hoje fixo em +8 em HP e energia).
- Ânion/Cátion em ligações covalentes.
- Se o jogador pode romper compostos adversários aquecendo a arena.
- Limite de Compostos por combate.
- *Novo:* suporte a Compostos de 3+ criaturas (ex.: H₂O).

### 25.3 Captura

- Lista final de métodos físicos/químicos e critério de acerto.
- Multiplicador X de cada categoria (hoje 255 / 127).
- Onde e a que custo a Ferramenta de Separação é obtida.

### 25.4 Atributos e Progressão

- Mapeamento nível → insígnias e implementação da obediência.
- Ataques e níveis de desbloqueio dos 6 elementos.
- XP Base fixo ou por criatura (hoje por espécie via `xp_reward`).
- Nível máximo (20 no protótipo) ainda não aplicado.

### 25.5 Economia

- Custos dos itens, valor de venda e recompensa por vitória.
- Implementar Comprar/Vender na loja.

### 25.6 Mundo e Encontros

- Tabelas de encontro por área com pesos.
- Cenas de hospital, loja e ginásio; mapas; Super Liga.
- Atalhos F5/F9 e ação de corrida.
