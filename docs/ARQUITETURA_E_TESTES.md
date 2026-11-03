# Arquitetura técnica e testes internos

Este documento descreve a organização interna do **TCC-Jogo**, os fluxos
principais entre cenas e sistemas, a máquina de estados do combate e a
estratégia de testes automatizados.

## 1. Organização interna do código

O projeto é organizado por responsabilidade:

| Diretório | Responsabilidade |
|---|---|
| `scenes/` | Cenas de entrada, carregamento de fases, portas, NPCs e gerenciamento do nível atual. |
| `EXPLORATION/` | Jogador, movimentação, câmera, seguidores, NPCs e encontros no mapa. |
| `COMBAT/` | Estado da batalha, regras, fases, ações, campo de batalha, recompensas e sincronização das criaturas. |
| `DATABASE/` | Modelos e recursos persistentes do jogador, criaturas, inventário e salvamento. |
| `INTERFACES/` | Menus, HUD, comandos de batalha, inventário e telas de resultado. |
| `autoload/` | Serviços globais de sessão e sinais de comunicação entre sistemas. |
| `test/` | Suítes automatizadas executadas pelo GdUnit4. |

### 1.1 Cena principal e cenas de exploração

`scenes/main.tscn` funciona como composição da sessão de exploração. Ela
contém o `Player`, `CameraRig`, `FollowerManager`, `SceneManager`,
`CombatSceneManager`, `LevelHolder`, `BattleAnchors` e os elementos de HUD.
As fases (`scenes/scene_1.tscn`, `scenes/scene_2.tscn`) são carregadas
dinamicamente pelo `SceneManager`, que remove a fase anterior, instancia a
nova e posiciona o jogador no `Marker3D` de destino.

O jogador é uma `CharacterBody3D` composta por componentes:

- `MovementComponent`: lê as ações de entrada e aplica deslocamento e
  gravidade;
- `InteractionComponent`: identifica objetos interagíveis;
- `InventoryComponent`: coleta e manipula itens;
- `CombatHandler`: inicia e encerra a integração com o combate.

Essa composição evita concentrar movimentação, interação e inventário em uma
única classe monolítica.

### 1.2 Gerenciadores globais e comunicação

O projeto utiliza dois autoloads registrados em `project.godot`:

- `GameSession`: mantém o progresso em memória, controla novo jogo,
  carregamento, salvamento, posição no mundo e autosave;
- `CombatSignal`: concentra sinais de ciclo de combate, sincronização de
  criaturas, mudança de grupo e comunicação com NPCs e seguidores.

Os sinais permitem que os participantes reajam sem referências diretas entre
as cenas. Por exemplo, o `CombatSceneManager` cria a cena de combate quando
recebe `combat_start`, enquanto `FollowerManager`, `SceneManager` e o jogador
reagem aos eventos de encerramento ou mudança de grupo.

```mermaid
flowchart LR
    Menu["Menu"] -->|novo jogo / carregar| Session["GameSession"]
    Session --> Main["main.tscn"]
    Main --> SceneManager["SceneManager"]
    SceneManager --> Levels["Fases em LevelHolder"]
    Main --> Player["Player + componentes"]
    Main --> Followers["FollowerManager"]
    Player -->|interação| Encounter["NPC / encontro selvagem"]
    Encounter -->|CombatSignal.combat_start| CombatManager["CombatSceneManager"]
    CombatManager --> Combat["combat_refactored.tscn"]
    Combat -->|creatures_synced / battle_finished| Signals["CombatSignal"]
    Signals --> Session
    Signals --> Followers
    Signals --> Encounter
```

### 1.3 Camadas do combate

O combate é dividido em camadas com responsabilidades distintas:

1. `CombatSceneManager` integra o combate à cena de exploração: move
   personagens para os marcadores, instancia adversários e restaura a
   posição ao final.
2. `CombatControllerStates` orquestra a batalha e traduz comandos da
   interface em ações.
3. `CombatState` e `CombatantState` representam exclusivamente os dados
   transitórios da batalha.
4. `CombatRules`, `BattlefieldRules`, `BondRules` e `BattleRewards` aplicam
   regras de domínio.
5. `CombatResultApplier` e `CreatureSync` transferem o resultado para os
   recursos persistentes.
6. `INTERFACES/` apresenta opções e resultados, sem decidir regras de
   batalha.

O `CombatStateFactory` cria o estado inicial a partir do grupo do jogador,
dos adversários, dos recursos de dados e do vínculo alquímico ativo. Assim,
os objetos persistentes (`AlchemonInstance`) não são usados como estado
mutável de cada rodada.

## 2. Máquina de estados do jogador e do combate

### 2.1 Estado do jogador durante a exploração

O jogador não possui uma enumeração explícita de estados; sua composição
define dois fluxos operacionais:

- **Exploração**: `Player` executa `MovementComponent` a cada frame e aceita
  interação pelo `InteractionComponent`;
- **Combate**: `CombatHandler` reage ao sinal de início, enquanto o
  `CombatSceneManager` desativa temporariamente a câmera e desloca os
  personagens para as posições de batalha. Depois do resultado, os
  personagens retornam aos pontos originais e a exploração é liberada.

```mermaid
stateDiagram-v2
    [*] --> Exploracao
    Exploracao --> PreparandoCombate: encontro / NPC emite combat_start
    PreparandoCombate --> Combate: personagens chegam aos BattleAnchors
    Combate --> Retornando: combat_ended
    Retornando --> Exploracao: personagens em casa e câmera reativada
```

### 2.2 Máquina de estados da batalha

`BattlePhaseMachine` define as transições válidas. A classe
`BattlePhaseRules` expõe os mesmos contratos para o controlador e para as
regras, evitando tabelas de transição duplicadas.

```mermaid
stateDiagram-v2
    [*] --> ENCOUNTER_START
    ENCOUNTER_START --> SELECTING_ACTIONS
    SELECTING_ACTIONS --> RESOLVING_ACTIONS
    RESOLVING_ACTIONS --> END_OF_ROUND
    RESOLVING_ACTIONS --> COMBAT_OVER
    END_OF_ROUND --> SELECTING_ACTIONS
    END_OF_ROUND --> COMBAT_OVER
    COMBAT_OVER --> VICTORY
    COMBAT_OVER --> DEFEAT
    VICTORY --> [*]
    DEFEAT --> [*]
```

Durante `SELECTING_ACTIONS`, os comandos do jogador são coletados e as
ações da inteligência artificial são enfileiradas. Em
`RESOLVING_ACTIONS`, `CombatRules` resolve a ordem e os efeitos. A rodada
volta para `END_OF_ROUND` ou termina em `COMBAT_OVER`; a tela de recompensas
é exibida antes da liberação definitiva do jogador.

## 3. Diagrama de classes e dependências

O diagrama abaixo apresenta as relações centrais, sem representar todos os
recursos artísticos e nós puramente visuais.

```mermaid
classDiagram
    class GameSession {
        +save_game()
        +load_game()
        +new_game()
        +take_resume_position()
    }
    class SceneManager {
        +change_level(scene, spawn)
        +get_save_position()
    }
    class CombatSceneManager {
        +on_combat_start()
        +on_combat_ended()
    }
    class CombatControllerStates {
        +state: CombatState
        +advance_phase()
    }
    class CombatState {
        +combatants
        +phase
        +pending_actions
        +captured_instances
    }
    class BattlePhaseMachine {
        +is_valid_transition()
        +transition()
    }
    class CombatRules {
        +resolve_action()
        +capture_roll_succeeds()
    }
    class CombatResultApplier {
        +apply()
    }
    class CreatureSync {
        +apply_battle()
    }
    class AlchemonInstance {
        +compute_stats()
        +to_dict()
        +from_dict()
    }
    class SaveGame {
        +serialize()
        +apply()
        +write_file()
        +read_file()
    }

    GameSession --> SaveGame
    GameSession --> SceneManager
    CombatSceneManager --> CombatControllerStates
    CombatControllerStates --> CombatState
    CombatControllerStates --> CombatRules
    CombatState --> BattlePhaseMachine
    CombatResultApplier --> CreatureSync
    CreatureSync --> AlchemonInstance
    SaveGame --> AlchemonInstance
```

## 4. Desacoplamento e independência de engine

O desacoplamento foi aplicado separando **dados e regras** da
**orquestração de cenas**:

- regras como fórmulas, transições, cálculo de captura, recompensas e
  sincronização são implementadas em classes `RefCounted`, `Resource` ou
  funções sem dependência de uma cena específica;
- `CombatState` representa o estado transitório sem assumir a árvore de
  nós;
- `SaveGame` concentra serialização e leitura, permitindo testes sem
  inicializar uma fase;
- componentes de Godot (`Node`, `CharacterBody3D`, `CanvasLayer` e cenas)
  funcionam como adaptadores de entrada, apresentação e ciclo de vida;
- os recursos persistentes são atualizados apenas nas fronteiras definidas,
  principalmente por `CreatureSync`, `CombatResultApplier` e `GameSession`.

Essa organização não elimina a dependência de Godot — cenas, recursos e
entrada continuam sendo responsabilidades da engine —, mas mantém o núcleo
de regras independente da árvore visual. Como resultado, fórmulas e fluxos
podem ser exercitados em testes sem reproduzir uma partida completa.

## 5. Testes internos

O projeto usa o plugin **GdUnit4**, habilitado em `project.godot`. As suítes
atuais em `test/` cobrem:

| Suíte | Escopo |
|---|---|
| `test_alchemonGrowth.gd` | Fórmulas de atributos, evolução, energia e estado físico. |
| `test_capture_formula.gd` | Valor de captura, limites, redução de oito bits, rolagem, ferramenta correta/incorreta e resolução probabilística. |
| `test_creature_persistence.gd` | UID, serialização JSON, saneamento de dados, atributos derivados, HP, sincronização de batalha e captura do indivíduo correto. |
| `test_battle_rewards.gd` | Moedas, experiência, level up, textos da tela de recompensa, entrada de teclado/controle e ordem de encerramento do combate. |

Os testes validam tanto unidades de domínio quanto fronteiras importantes do
fluxo de jogo. Entre os contratos protegidos estão:

- uma criatura capturada preserva o indivíduo que foi combatido;
- resultados são sincronizados por UID, não pela posição no grupo;
- dados inválidos de salvamento são normalizados ou rejeitados;
- bônus temporários de vínculo não vazam para a criatura persistente;
- a tela de recompensas aparece antes de `combat_ended` liberar a exploração;
- valores de captura permanecem entre 1 e 255.

### Execução

Com o Godot 4 disponível no ambiente, a execução pode ser feita pelo
runner do GdUnit4 no editor ou pela ferramenta de linha de comando do
plugin, apontando para o projeto `tcc-jogo/`. O arquivo
`addons/gdUnit4/GdUnitRunner.cfg` mantém o inventário dos testes descobertos
e seus caminhos `res://test/*.gd`.

