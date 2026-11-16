# ALCHEMON — Documento de Design de Jogo (GDD)

**Versão:** atualização de estado do protótipo  
**Engine declarada no GDD existente:** Godot 4.6, renderer GL Compatibility e física Jolt.


## Legenda de status

- **[OK]** Implementado no código consultado.
- **[Parcial]** Implementado com limitações, integração incompleta ou divergência em relação ao design.
- **[Pendente]** Planejado, mas não identificado como implementado.
- **[Extra]** Recurso implementado que não fazia parte do escopo original documentado.

---

## 0. Resumo do estado do protótipo

| Área | Status | Estado observado |
|---|---|---|
| Cenas, portas e spawn | [OK] | `SceneManager`, `SceneDoor` e duas fases de teste. |
| Exploração | [Parcial] | Movimento, interação e câmera funcional; corrida e atalhos F5/F9 não identificados. |
| Encontros | [Parcial] | Encontros por tempo e áreas de colisão; não por passos ou cone de visão. |
| Combate 2×2 por turnos | [OK] | Máquina de fases, iniciativa, comandos, resolução e encerramento. |
| Tipos e efetividade | [OK] | Ciclo Metal > Metaloide > Ametal > Metal; multiplicadores 1,5 / 0,66 / 1,0. |
| Atributos e IV | [Parcial] | Fórmulas de atributos e IV implementados; correspondência química dos atributos-base ainda não consolidada. |
| Personalidades | [Extra] | Modificadores de +10% e −10% em atributos. |
| Temperatura e estados físicos | [Parcial] | Aquecimento do alvo, transições, dano térmico e estados do Composto; a temperatura global da arena não propaga o calor para todos os combatentes. |
| Misturas | [Parcial] | Vínculo entre exatamente dois Alchemons; bônus em HP e energia, não em todos os atributos. |
| Compostos iônicos e covalentes | [Parcial] | Regras químicas suportam grupos de até quatro Alchemons e até quatro elementos distintos; transferência de atributos ainda usa 70% fixos. |
| Captura | [Parcial] | Fórmula e preservação da instância implementadas; métodos de captura ainda são categorias provisórias. |
| Ataques por nível | [OK]/[Parcial] | Desbloqueio por nível e limite de quatro golpes implementados; a escolha de substituição depende da interface. |
| XP e níveis | [OK] | Curva de XP acumulada N³, recompensa por derrota e distribuição ao grupo vivo do lado que venceu a ação. |
| Insígnias e obediência | [Parcial] | Insígnia do Metal é concedida; regras de obediência não foram identificadas. |
| Economia e loja | [OK]/[Parcial] | Compra e venda implementadas; itens e valores ainda precisam de balanceamento. |
| PC e armazenamento | [Parcial] | Troca de equipe, armazenamento e configuração de vínculos; sem caixas organizadas. |
| Cura | [Parcial] | NPC Enfermeiro restaura HP e energia; não há cena de hospital ou teleporte após derrota. |
| Salvamento | [OK] | JSON, gravação atômica, backup, posição, inventário e progresso de NPCs. |
| Menus | [Parcial] | Menu unificado e páginas funcionais; opções previstas originalmente não estão todas presentes. |
| Testes automatizados | [Extra] | Há suítes GdUnit4. A contagem de testes diverge entre o GDD e a documentação técnica e precisa ser reconciliada. |

---

## 1. Visão geral

Alchemon é um jogo 3D de captura e colecionismo de criaturas inspirado no gênero *creature capture*. Cada criatura representa um elemento químico da Tabela Periódica. As propriedades químicas dos elementos são utilizadas como referência para atributos, ataques, formação de vínculos e mecânicas térmicas.

A proposta combina exploração, captura, treinamento, combate por turnos e experimentação com combinações químicas. O objetivo pedagógico é apresentar conceitos de Química Geral por meio de sistemas que o jogador utiliza para progredir.

### 1.1 Público-alvo

- Estudantes do Ensino Médio;
- adultos interessados em Química;
- jogadores interessados em jogos de captura e treinamento de criaturas.

### 1.2 Direção visual e áudio

A direção visual utiliza modelos 3D low-poly com referências estéticas à era PSX e a jogos como *Digimon World*. A trilha sonora deve acompanhar o tom de aventura.

- **Visual 3D low-poly:** [OK] identificado no projeto.
- **Áudio:** [Pendente de verificação] não foi possível confirmar o estado de implementação dos recursos sonoros apenas pelos scripts consultados.

### 1.3 Objetivos do jogador

| Objetivo | Status |
|---|---|
| Capturar e colecionar Alchemons | [Parcial] sistema de captura funcional, catálogo ainda limitado. |
| Treinar Alchemons e desbloquear ataques | [OK] progressão e aprendizado de ataques implementados. |
| Formar Misturas e Compostos | [Parcial] regras implementadas, com limitações de balanceamento e integração. |
| Conquistar insígnias de ginásio | [Parcial] existe a Insígnia do Metal. |
| Derrotar o campeão da Super Liga | [Pendente] |
| Localizar criaturas raras ou lendárias | [Pendente] |
| Recuperar elementos artificiais fugitivos | [Pendente] |

---

## 2. Estrutura do jogo e cenários

O jogo é dividido em cenários independentes, sem um mundo aberto contínuo. A cena principal mantém o jogador, a câmera, os seguidores, os gerenciadores de cena e os pontos de ancoragem utilizados pelo combate.

### 2.1 Transição entre cenários — [OK]

`SceneDoor` detecta a entrada do jogador e solicita a mudança ao `SceneManager`. O gerenciador remove a fase atual, instancia a próxima em `LevelHolder` e posiciona o jogador no `Marker3D` indicado.

O sistema também registra a fase, posição e rotação do jogador para retomada após o carregamento de um salvamento.

Fases identificadas no GDD existente:

- `scene_1.tscn`: NPCs, loja, Enfermeiro, ginásio e área de mato alto;
- `scene_2.tscn`: segunda fase de teste.

**Ponto de atenção:** as portas devem ser posicionadas de modo que o ponto de entrada não sobreponha a área de saída, evitando transições repetidas.

---

## 3. Exploração

### 3.1 Controles

O jogador é um `CharacterBody3D` composto por componentes de movimentação, interação, inventário e integração com o combate.

| Entrada | Ação | Status |
|---|---|---|
| W/A/S/D e setas | Caminhar em oito direções | [OK] |
| E | Interagir com itens, NPCs e estações | [OK] |
| Tab | Abrir o menu unificado | [OK] |
| F5 / F9 | Salvar / carregar rapidamente | [Pendente] |
| Corrida | Deslocamento acelerado | [Pendente] |

Os menus também aceitam navegação por teclado, confirmação, retorno e mouse em listas.

### 3.2 Câmera

A câmera mantém altura e ângulo fixos e acompanha o jogador por uma zona morta, com parâmetros de velocidade de seguimento e distância de reposicionamento. Não há controle livre de câmera pelo jogador.

**Divergência:** o comportamento atual não corresponde a uma câmera rigidamente presa atrás do avatar; o seguimento utiliza zona morta.

### 3.3 Movimentação e colisões — [OK]

O jogador utiliza colisões do cenário para impedir a passagem por obstáculos. Não foi identificado sistema de pulo como ação de exploração. A gravidade permanece ativa.

### 3.4 Itens e NPCs — [OK]/[Extra]

- Itens coletáveis são identificados pelo sistema de interação e adicionados ao inventário.
- NPCs apresentam diálogos com texto progressivo e permitem avançar ou encerrar a exibição.
- Há diálogos de confirmação Sim/Não, utilizados pelo Enfermeiro.
- NPCs podem assumir os papéis de treinador, líder de ginásio, lojista e Enfermeiro. Esses papéis são configurados nos pontos de spawn.
- NPCs derrotados recebem identificadores persistentes para impedir que o mesmo combate seja iniciado novamente após o progresso ser salvo.

### 3.5 Estruturas do mapa — [Parcial]

Loja, cura e ginásio são representados por NPCs e pontos de interação dentro das fases. Não foram identificadas cenas independentes completas para hospital, loja ou ginásio.

---

## 4. Encontros e início de combate

O sinal `CombatSignal.combat_start` inicia a integração entre exploração e combate. `CombatSceneManager` posiciona os participantes nos pontos de batalha e prepara equipe, inventário, banco de espécies, armazenamento e vínculos.

### 4.1 Encontros com treinadores — [Parcial]

O combate começa quando o jogador entra na área `CombatCollision` do NPC. A implementação utiliza uma área de colisão, não um cone de visão.

O NPC define o nível e as espécies adversárias. Após a derrota, seu identificador é registrado e o encontro é desativado. Líderes de ginásio podem conceder uma insígnia.

### 4.2 Encontros selvagens — [Parcial]

`WildernessEncounter` utiliza uma área configurável e uma rolagem temporal:

- intervalo de verificação configurável;
- chance de encontro configurável;
- exigência de movimento do jogador;
- possibilidade de rolagem ao entrar na área;
- intervalo de recarga após o combate;
- bloqueio de novos encontros durante uma batalha;
- seleção de espécie e nível a partir dos parâmetros da área.

A lista de espécies é selecionada de forma uniforme no estado documentado. Tabelas ponderadas e específicas para cada região permanecem como trabalho futuro.

---

## 5. Sistema de combate

O combate utiliza formato 2×2, com até duas criaturas de cada lado. O estado da batalha é separado dos recursos persistentes das criaturas.

### 5.1 Fluxo de turno — [OK]

A máquina de fases controla o ciclo:

`ENCOUNTER_START → SELECTING_ACTIONS → RESOLVING_ACTIONS → END_OF_ROUND → SELECTING_ACTIONS / COMBAT_OVER → VICTORY / DEFEAT`

1. **Iniciativa:** calculada por criatura e utilizada para ordenar as ações.
2. **Seleção:** o jogador escolhe comandos e alvos; a IA seleciona ações para seus participantes.
3. **Resolução:** as regras produzem resultados, e `CombatResultApplier` aplica as alterações ao estado da batalha.
4. **Encerramento:** o combate termina quando um dos lados não possui participantes vivos.

A iniciativa é calculada no início do combate; não foi identificada uma nova rolagem obrigatória a cada rodada.

### 5.2 Ações disponíveis — [Parcial]

- **Ataque:** utiliza um dos golpes equipados, respeitando o custo de energia.
- **Item:** utiliza itens válidos da mochila em aliados.
- **Captura:** permite tentar capturar criaturas selvagens; não deve ser utilizada contra treinadores.
- **Fuga:** utiliza chance fixa de sucesso de 5/6. A implementação consultada não restringe a ação a encontros selvagens.
- **Slap:** [Extra] quando a energia de ação chega a zero, o ataque selecionado é substituído por Slap, com poder 10, custo zero e efetividade neutra. Slap não injeta energia térmica.

### 5.3 Dano e efetividade — [OK]

A fórmula de dano considera nível, poder do ataque, Ataque do usuário, Defesa do alvo e efetividade elemental. A Defesa utilizada no denominador possui limite mínimo de 1.

Multiplicadores:

| Relação | Multiplicador |
|---|---:|
| Super efetivo | 1,5 |
| Resistido | 0,66 |
| Neutro | 1,0 |

### 5.4 Críticos e erros — [Parcial]

- Chance global de crítico: 12,5%.
- Multiplicador crítico atual: 1,5.
- Chance global de erro: 1/6.

As probabilidades são globais no código consultado, não configuradas individualmente por ataque. O multiplicador crítico também diverge da fórmula originalmente prevista no GDD.

### 5.5 Vitória e derrota — [Parcial]

A tela de recompensas é exibida antes de o controle retornar à exploração.

- Vitórias contra treinadores concedem 100 moedas.
- Encontros selvagens não concedem moedas no estado documentado.
- A derrota encerra o combate e retorna à exploração.
- Não foi identificado teletransporte automático para um hospital após a derrota.
- Criaturas derrotadas não são automaticamente revividas no início do combate seguinte.

---

## 6. Sistema de tipos — [OK]

Os tipos de combate são Metal, Ametal e Metaloide. A relação de efetividade segue o ciclo:

`Metal > Metaloide > Ametal > Metal`

A efetividade é calculada entre o tipo do ataque e o tipo da espécie atingida. Ataques contra o próprio tipo são neutros.

---

## 7. Atributos e dados dos Alchemons

### 7.1 Atributos-base e propriedades químicas — [Parcial]

`AlchemonSheet` armazena os dados de cada espécie, incluindo massa atômica, atributos-base, energia de ação, propriedades de valência e propriedades térmicas.

Os atributos-base de combate ainda devem ser tratados como parâmetros de balanceamento quando não houver uma fórmula química formal que justifique sua conversão. Não se deve afirmar que HP, Ataque, Defesa e Velocidade já são calculados automaticamente a partir de massa atômica ou eletronegatividade.

### 7.2 Fórmulas de atributos — [Parcial]

Para Ataque, Defesa e Velocidade Mecânica, o código utiliza:

\[
\operatorname{Stat}(B, IV, N) =
\left\lfloor 0{,}01(2B+IV)N \right\rfloor + 5
\]

Onde:

- \(B\): atributo-base da espécie;
- \(IV\): valor individual sorteado;
- \(N\): nível da criatura.

O IV é sorteado entre 1 e 31 na criação da instância.

**HP:** o comportamento registrado no código é calculado a partir do HP-base e da diferença entre o atributo calculado no novo nível e no nível anterior. Portanto, o HP no nível 1 permanece igual ao HP-base da ficha. Essa implementação diverge da fórmula de HP originalmente proposta no GDD e deve ser considerada a referência do protótipo até que uma decisão de projeto altere o código.

### 7.3 Personalidades — [Extra]

As instâncias recebem uma personalidade que aumenta um atributo em 10% e reduz outro em 10%. As personalidades identificadas no GDD existente são:

- neutral;
- bold;
- stoic;
- hasty;
- calm;
- keen.

A personalidade é sorteada na criação da criatura e integra os dados individuais da instância.

### 7.4 Energia de ação — [Parcial]

A energia é representada no combate por `valence_electrons`, com limite associado à ficha da espécie. Os ataques consomem energia conforme o custo cadastrado. O valor atual persiste entre combates e é restaurado pelo Enfermeiro.

Quando a energia chega a zero, o ataque é substituído por Slap. Não foi identificado consumo adicional de energia ao receber dano.

### 7.5 Cadastro de uma nova espécie

Para cadastrar uma espécie, preencher os dados correspondentes no recurso `AlchemonSheet` e nos recursos associados:

1. **Identificação:** nome da criatura, elemento químico, símbolo e número atômico.
2. **Classificação:** tipo de combate e categoria química.
3. **Propriedades químicas:** massa atômica, elétrons de valência, alvo de estabilidade, eletronegatividade e estados de oxidação.
4. **Atributos-base:** HP, Ataque, Defesa, Velocidade Mecânica e Energia de Ação.
5. **Propriedades térmicas:** ponto de fusão, ponto de ebulição e calor específico, conforme os campos do recurso.
6. **Combate:** ataques associados, poder, tipo, custo de energia e nível de desbloqueio.
7. **Progressão:** recompensa de XP.
8. **Representação:** modelo 3D, retrato e demais recursos visuais.

UID, nível, IV, personalidade, HP atual, energia atual e lista de golpes equipados são dados da instância individual, não da espécie.

### 7.6 Elementos documentados no GDD

O documento anterior apresenta seis elementos de referência:

| Elemento | Símbolo | Número atômico | Categoria |
|---|---|---:|---|
| Hidrogênio | H | 1 | Ametal |
| Oxigênio | O | 8 | Ametal |
| Silício | Si | 14 | Metaloide |
| Arsênio | As | 33 | Metaloide |
| Ferro | Fe | 26 | Metal de transição |
| Ouro | Au | 79 | Metal de transição |

Os valores detalhados de massa, eletronegatividade, estados de oxidação, propriedades térmicas e atributos-base devem permanecer associados às fichas individuais e ser revisados com fontes químicas confiáveis.

**Inconsistência documental a resolver:** a versão anterior do GDD afirma que seis elementos estão documentados, mas a seção de espécies disponíveis descreve três espécies placeholder e uma espécie de debug. A quantidade de fichas documentadas não deve ser confundida com a quantidade de espécies efetivamente configuradas e selecionáveis no jogo.

---

## 8. Temperatura e estados físicos

### 8.1 Temperatura de combate — [Parcial]

O sistema utiliza Kelvin. A temperatura inicial da arena registrada no GDD anterior é 273,15 K.

Quando um ataque acerta, o código calcula um incremento térmico:

\[
\Delta T_{\text{golpe}} =
\left(\frac{N}{10}+1\right)
\left(\frac{P}{10}\right)
\left(\frac{A}{100}\right)
\]

Onde \(N\) é o nível do atacante, \(P\) é o poder do golpe e \(A\) é o Ataque do atacante. O valor é decimal; não há arredondamento por `floor` nessa função.

O valor térmico do golpe é convertido em energia \(Q\) por um fator de escala de balanceamento. Para criaturas individuais, a variação de temperatura segue:

\[
\Delta T = \frac{Q}{m \cdot c_p}
\]

Onde \(m\) é a massa atômica utilizada pelo sistema e \(c_p\) é o calor específico cadastrado.

**Limitação importante:** o código também atualiza `arena_temperature`, mas a rotina consultada não propaga essa temperatura global para todos os participantes. O aquecimento efetivo por golpe é aplicado ao alvo atingido. Portanto, não documentar a arena como um campo térmico que aquece automaticamente todas as criaturas.

### 8.2 Transições de estado físico — [Parcial]

As criaturas individuais podem transitar entre sólido, líquido e gasoso conforme a temperatura e os pontos de fusão e ebulição da ficha.

As transições implementadas provocam dano calculado sobre o HP máximo:

| Transição | Parcela do HP máximo | Parcela por nível |
|---|---:|---:|
| Sólido → Líquido (fusão) | 10% | +1 × nível |
| Líquido → Gasoso (ebulição) | 20% | +2 × nível |
| Gasoso → Líquido (condensação) | 15% | +1,5 × nível (arredondamento inteiro do código) |
| Líquido → Sólido (solidificação) | 10% | +1 × nível |

A mudança de estado pode percorrer mais de uma transição em um único aquecimento ou resfriamento, aplicando o dano de cada etapa atravessada.

**Não implementado no comportamento consultado:** bônus ou penalidades diretas de Ataque, Defesa, Velocidade ou outros atributos por estado físico. O efeito atual é térmico e relacionado ao dano de transição.

### 8.3 Temperatura dos Compostos — [Parcial]

Um Composto possui temperatura própria, separada da temperatura individual de seus participantes. Suas propriedades térmicas são calculadas no momento da formação:

- massa total: soma das massas dos participantes;
- ponto de fusão e ebulição: médias ponderadas pela massa;
- calor específico: parâmetro de balanceamento de acordo com o tipo de ligação;
- limite de surto térmico: definido pelo tipo de ligação;
- temperatura de cisão: calculada conforme a ligação iônica ou covalente.

A mudança de estado físico do Composto provoca dano de transição no participante ativo do vínculo.

### 8.4 Ruptura térmica e Sobrecarga — [Parcial]

A cisão do Composto ocorre quando a temperatura interna alcança a temperatura de cisão ou quando um único golpe provoca uma variação térmica superior ao limite de surto.

As fórmulas registradas no código são:

**Ligação iônica:**

\[
T_{\text{cisão}} =
T_{\text{ebulição do ânion}}
+ 250|\Delta E|
+ 100|Z_{\text{cátion}}|
\]

**Ligação covalente:**

\[
T_{\text{cisão}} =
\max(T_{\text{ebulição dos participantes}})
+ 150P
\]

Onde \(\Delta E\) é a diferença de eletronegatividade, \(Z_{\text{cátion}}\) é a carga positiva de referência do cátion e \(P\) é a maior ordem de ligação compartilhada identificada no Composto.

Após a cisão:

- o vínculo é desfeito;
- os participantes sobreviventes são liberados;
- ocorre choque térmico de 20 pontos de dano nos participantes elegíveis;
- cada Alchemon recebe o choque no máximo uma vez por combate;
- inicia-se Sobrecarga Térmica por dois turnos completos;
- os participantes liberados herdam a temperatura interna do Composto.

Os valores de calor específico, limites de surto e dano de choque são parâmetros de balanceamento do jogo, não constantes físico-químicas universais.

---

## 9. Misturas e Compostos

Os vínculos são configurados no PC e revalidados quando o combate é iniciado. O sistema mantém o vínculo no estado transitório de batalha, sem gravar os bônus temporários nos atributos permanentes da instância.

### 9.1 Misturas — [Parcial]

Uma Mistura é formada por exatamente dois Alchemons quando a combinação não satisfaz as regras de formação de um Composto iônico ou covalente.

Exemplos de combinações que podem resultar em Mistura incluem metal + metal, combinações com metaloides, gases nobres ou pares sem ligação válida segundo o modelo do jogo.

Efeito atual:

- +8 no HP máximo de cada participante;
- +8 no HP atual de cada participante;
- +8 na energia máxima de cada participante;
- +8 na energia atual de cada participante.

**Divergência:** o design anterior previa bônus em todos os atributos. O código aplica o bônus somente a HP e energia.

### 9.2 Compostos iônicos e covalentes — [Parcial]

`CompoundRules` classifica as combinações e calcula a composição química. A estação de alquimia aceita grupos de dois a quatro Alchemons.

Limites identificados:

- até quatro Alchemons no grupo;
- até quatro elementos químicos distintos;
- até seis unidades de cada elemento;
- até doze átomos na composição calculada.

As quantidades estequiométricas são calculadas pelo sistema. Criaturas repetidas do mesmo elemento contribuem para a quantidade daquele elemento na fórmula.

**Ligação iônica:** ocorre entre metais e ametais quando a diferença de eletronegatividade atinge o limiar de 2,0 e as cargas podem ser neutralizadas. O sistema procura estados de oxidação e quantidades que resultem em carga total zero.

**Ligação covalente:** ocorre entre ametais quando a diferença de eletronegatividade é inferior ao limiar de 2,0. O algoritmo procura uma composição e ordens de ligação que satisfaçam as capacidades de ligação do modelo.

O sistema inclui fórmulas conhecidas para combinações como H₂, O₂, O₃, H₂O, NH₃, HCl, CH₄, CO₂, NaCl, MgCl₂, Na₂O, MgO e Al₂O₃, entre outras registradas em `CompoundRules`.

A classificação didática é uma simplificação: não substitui uma descrição química completa de estruturas moleculares, ressonância, coordenação ou exceções à regra do octeto.

### 9.3 Participante ativo, cátion e parceiros — [Parcial]

`BondRules` seleciona o participante ativo do Composto. A regra atual escolhe o participante de maior nível, evitando selecionar um metal como ativo quando há metal no grupo.

Os participantes não ativos ficam inativos durante o vínculo. No caso iônico, o metal é marcado como cátion e recebe as propriedades de proteção previstas pelo sistema de combate, incluindo não ser selecionado como alvo direto.

### 9.4 Transferência de atributos — [Parcial]

A implementação consultada ainda utiliza uma transferência fixa de 70% do HP máximo e da energia máxima dos participantes não ativos para o participante ativo:

\[
X_{\text{transferido}} =
\left\lfloor 0{,}70 \cdot X_{\text{participante}} \right\rfloor
\]

O código aplica essa transferência a HP máximo, HP atual, energia máxima e energia atual. Ao desfazer o vínculo, os valores transferidos são removidos do ativo.

**Importante:** a fórmula variável de transferência por eletronegatividade e carga do cátion, discutida anteriormente no projeto, não está implementada no código consultado. O arquivo `composto_alpha.patch` não deve ser tratado como funcionalidade integrada enquanto não estiver aplicado e confirmado na branch principal.

### 9.5 Liberação dos participantes — [Parcial]

Quando o participante ativo cai, os parceiros são liberados. A regra atual restaura os participantes liberados com 30% do HP máximo e utiliza a energia do participante que caiu, com um valor mínimo de fallback quando necessário.

A cisão térmica também desfaz o vínculo e aplica choque térmico conforme as regras da seção 8.

---

## 10. Ataques e aprendizado

### 10.1 Cadastro e lista de ataques — [Parcial]

Os ataques possuem identificador, nome, poder, custo de energia, tipo e nível de desbloqueio. O banco global de ataques é utilizado para compor uma lista comum de golpes, ordenada pelo nível necessário.

Ataques de debug não entram na lista normal.

### 10.2 Limite de golpes — [OK]

Cada instância pode manter até quatro ataques equipados. Na criação, o sistema seleciona os ataques já desbloqueados até o nível atual, respeitando o limite de quatro.

### 10.3 Aprendizado por nível — [OK]/[Parcial]

Quando uma criatura alcança um nível com novo ataque disponível:

- se houver espaço, o golpe é adicionado automaticamente;
- se o conjunto estiver cheio, o golpe fica pendente para o jogador;
- o jogador pode substituir um golpe equipado ou recusar o novo aprendizado;
- para adversários controlados pela IA, o sistema substitui automaticamente o golpe de menor poder.

A lógica de aprendizado está implementada em `AttackLearning` e é chamada durante o avanço de nível.

### 10.4 Dano, crítico e erro — [Parcial]

O dano considera nível, poder, Ataque, Defesa e efetividade elemental. A chance de crítico e a chance de erro ainda são globais, e o multiplicador crítico atual é fixo em 1,5.

---

## 11. Captura de criaturas

### 11.1 Fluxo — [Parcial]

1. O jogador seleciona um item identificado como método de captura.
2. O sistema valida se o alvo é um inimigo vivo.
3. A compatibilidade entre o método e o tipo da criatura determina o multiplicador.
4. Uma rolagem aleatória determina o sucesso.
5. Em caso de sucesso, a criatura capturada é transferida para o armazenamento.

A captura é bloqueada em batalhas contra treinadores.

### 11.2 Multiplicadores atuais — [Parcial]

- método compatível: 255;
- método incompatível: 127.

Os métodos atuais são categorias provisórias associadas aos tipos Metal, Ametal e Metaloide. A lista definitiva de ferramentas físicas ou químicas e seus critérios de utilização permanece pendente.

### 11.3 Fórmula de captura — [OK]

O valor de captura aumenta conforme o HP do alvo diminui:

\[
a =
\max\left(
\left\lfloor
\frac{(3HP_{\max}-2HP_{\text{atual}})X}{3HP_{\max}}
\right\rfloor,
1
\right)
\]

O resultado é limitado ao intervalo de 1 a 255. Quando necessário, o sistema reduz os termos para caber no limite de oito bits. A rolagem ocorre entre 0 e 254, e a captura é bem-sucedida quando o valor sorteado é menor que \(a\).

### 11.4 Preservação da instância — [OK]

A captura preserva a instância exata utilizada no combate, incluindo UID, IV, personalidade, nível e estado de HP. O HP armazenado não pode ser inferior a 1. A instância é transferida para `CapturedStorage`.

---

## 12. Progressão, experiência e níveis

### 12.1 Curva de experiência — [OK]

A experiência acumulada necessária para alcançar o nível \(N\) segue a curva cúbica:

\[
XP_{\text{acumulada}}(N)=N^3
\]

O custo para avançar do nível \(N\) para \(N+1\) é:

\[
XP_{\text{próximo}}=(N+1)^3-N^3
\]

O excedente de experiência permanece após o avanço, e uma única recompensa pode conceder múltiplos níveis.

### 12.2 Experiência por derrota — [OK]

A recompensa utiliza a fórmula:

\[
XP = \left\lfloor \frac{a \cdot b \cdot L}{10} \right\rfloor
\]

Onde:

- \(a=1\) em encontros selvagens;
- \(a=1{,}5\) em batalhas contra treinadores;
- \(b\) é a recompensa-base de XP da espécie derrotada;
- \(L\) é o nível da criatura derrotada.

O resultado possui mínimo de 1 ponto de experiência.

### 12.3 Distribuição de experiência — [OK]

A implementação atual concede a experiência aos participantes vivos do lado responsável pela derrota do alvo, não apenas à criatura que executou o golpe final. Isso inclui os membros vivos da equipe do jogador e, conforme o lado que realizou a ação, os participantes vivos da equipe adversária.

### 12.4 Efeitos do avanço de nível — [OK]/[Parcial]

O avanço recalcula Ataque, Defesa e Velocidade, aumenta o HP máximo e a energia máxima e aciona o sistema de aprendizado de ataques.

O aumento de HP máximo também é acrescentado ao HP atual quando a criatura está viva. O aumento do limite de energia não restaura automaticamente a energia atual.

**Pendente:** definir e implementar um teto de nível, caso o limite 20 previsto no design original continue desejado.

### 12.5 Insígnias e obediência — [Parcial]

A estrutura de insígnias existe, e o NPC líder do ginásio Metal concede a Insígnia do Metal. A implementação de regras de obediência por nível e quantidade de insígnias não foi identificada.

---

## 13. Economia e itens

### 13.1 Moeda — [OK]/[Parcial]

O jogador inicia com 500 moedas. A vitória contra treinadores concede 100 moedas. A venda de itens também pode gerar moeda.

Os valores de recompensa e preços ainda precisam de balanceamento.

### 13.2 Itens — [Parcial]

Os itens são definidos por dados que incluem identificador, nome, descrição, ícone, valor de cura, identificação de método de captura, tipo de captura e valor de venda.

Os itens de cura e recuperação de energia devem ser conferidos no banco atual antes de serem descritos como conteúdo final. A versão anterior do GDD registrava apenas itens genéricos e métodos de captura provisórios.

### 13.3 Lojas — [OK]

O NPC lojista oferece opções de compra e venda. O preço de compra utiliza o valor de venda cadastrado; a venda pelo jogador ocorre por metade desse valor, arredondado para baixo. Itens com valor não positivo não são negociados.

---

## 14. PC e armazenamento de criaturas

O PC permite acessar páginas de alquimia, armazenamento e saída.

- **Equipe:** limite atual de duas criaturas; o jogador não pode deixar a equipe vazia.
- **Armazenamento:** transfere instâncias entre equipe e armazenamento, preservando UID e dados individuais.
- **Alquimia:** seleciona participantes para formar Misturas ou Compostos, conforme as regras químicas.

**Limitações:** o armazenamento é uma lista, não um sistema completo de caixas. A organização prevista originalmente em caixas e a troca de ataques por meio do PC ainda precisam ser verificadas ou implementadas.

---

## 15. NPCs e diálogos

NPCs podem apresentar diálogos iniciais e falas alternativas após serem derrotados. O Enfermeiro possui fluxo de confirmação e mensagem específica após a cura.

Papéis identificados:

- treinador;
- líder de ginásio;
- lojista;
- Enfermeiro.

A persistência do estado de NPC derrotado utiliza identificadores estáveis associados à fase e ao ponto de spawn.

---

## 16. Cura e hospital

### 16.1 Enfermeiro — [OK]

O NPC Enfermeiro solicita confirmação, aguarda o tempo configurado e executa a cura da equipe. O sistema restaura HP e energia das criaturas.

### 16.2 Hospital — [Pendente]

Não foi identificada uma cena de hospital independente, o rastreamento de último hospital ou o teletransporte automático para esse local após a derrota.

---

## 17. Salvamento e carregamento — [OK]

O sistema utiliza `GameSession` e `SaveGame`. O salvamento manual é acessado pelo menu e utiliza arquivo JSON em `user://saves/slot_1.json`.

Os dados registrados incluem:

- equipe e armazenamento;
- vínculos alquímicos;
- moedas e dados do jogador;
- tempo de jogo;
- insígnias;
- inventário;
- NPCs derrotados;
- fase, posição e rotação do jogador.

A gravação é atômica, utiliza arquivo temporário e mantém backup `.bak`. O carregamento valida os dados antes de alterar o estado da sessão, trata dados malformados e pode recuperar o backup quando o arquivo principal está corrompido.

O autosave existe como opção, mas permanece desligado por padrão no estado documentado. Atalhos F5/F9 não foram identificados.

---

## 18. Interface e menus

### 18.1 Menu unificado — [Parcial]

O menu do jogo reúne as seguintes páginas:

| Página | Conteúdo |
|---|---|
| Table | Catálogo de espécies, ficha, estatísticas e prévia 3D. |
| Bag | Itens do inventário e detalhes. |
| Alchemons | Equipe, estatísticas, ataques e informações das criaturas. |
| Player | Nome, equipe, moedas, tempo de jogo e insígnias. |
| Save | Salvamento manual. |
| Exit | Fluxo de confirmação e saída. |

A página de opções prevista no design original não foi identificada no menu atual.

### 18.2 Interface de combate — [Extra]

A interface de combate inclui comandos de ação, HUD de HP, energia, nível e XP, registro de eventos, seleção de alvo e indicadores de estado, como Selvagem, Mistura e Cátion.

A documentação visual deve ser atualizada conforme os elementos efetivamente presentes nas cenas e recursos de interface.

---

## 19. Espécies disponíveis no protótipo

O GDD anterior descreve três espécies placeholder — Metal, Ametal e Metaloide — e uma espécie de debug identificada pelo ID 999. Também documenta seis elementos químicos como referência de cadastro.

Essas duas informações representam coisas diferentes:

1. **Elementos documentados:** fichas químicas de referência descritas no GDD.
2. **Espécies utilizáveis no protótipo:** recursos efetivamente cadastrados no banco de dados e selecionáveis nas cenas.

A lista de espécies jogáveis deve ser confirmada diretamente no recurso `AlchemonDatabase` antes de cada versão de distribuição.

---

## 20. Ginásios e insígnias

Existe um NPC líder de ginásio Metal na primeira fase de teste. A vitória concede a Insígnia do Metal.

Ainda não foi identificada uma estrutura completa de ginásios como cenas independentes, progressão por múltiplas insígnias, Super Liga ou sistema de obediência associado às insígnias.

---

## 21. Arquitetura técnica

O projeto está organizado por responsabilidade:

| Diretório | Responsabilidade |
|---|---|
| `scenes/` | Cena principal, fases, portas, pontos de spawn e gerenciadores de cena. |
| `EXPLORATION/` | Jogador, componentes, câmera, NPCs, encontros e estação de alquimia. |
| `COMBAT/` | Estado da batalha, regras, fases, ações, vínculos, térmica e sincronização. |
| `DATABASE/` | Espécies, instâncias, ataques, inventário, jogador e salvamento. |
| `INTERFACES/` | Menus, HUD, comandos e páginas de interface. |
| `autoload/` | Serviços globais de sessão e sinais. |
| `test/` | Testes automatizados GdUnit4. |

### 21.1 Separação de responsabilidades

- `CombatRules` calcula resultados das ações.
- `CombatResultApplier` aplica os resultados ao estado transitório do combate.
- `BondRules` controla formação, efeitos e dissolução dos vínculos.
- `ThermalRules` calcula variações térmicas, transições e sobrecarga.
- `CompoundRules` analisa combinações químicas e determina a composição.
- `AttackLearning` controla desbloqueio, aprendizado e substituição de ataques.
- `CreatureSync` sincroniza os resultados da batalha com as instâncias persistentes por UID.

O estado transitório de combate não deve sobrescrever atributos permanentes com bônus temporários de Misturas ou Compostos.

---

## 22. Índice de sistemas e responsabilidades

| Sistema | Responsabilidade principal |
|---|---|
| `AlchemonFormulas` | Fórmulas de atributos, dano, iniciativa, temperatura e captura. |
| `AlchemonType` | Efetividade e identificação dos tipos. |
| `AlchemonGrowth` | XP, avanço de nível e atualização de atributos. |
| `AttackLearning` | Lista de ataques, desbloqueios, aprendizado e substituição. |
| `CombatRules` | Validação e resolução das ações de combate. |
| `CombatResultApplier` | Aplicação de dano, cura, captura, calor e XP. |
| `ThermalRules` | Aquecimento, resfriamento, transições e sobrecarga térmica. |
| `CompoundRules` | Classificação iônica/covalente e composição estequiométrica. |
| `BondRules` | Misturas, Compostos, transferência atual e liberação de parceiros. |
| `AlchemyStation` | Validação das seleções realizadas no PC. |
| `BattlePhaseMachine` | Controle das fases do combate. |
| `CombatStateFactory` | Criação do estado de batalha e aplicação de vínculos. |
| `BattleRewards` | Construção das recompensas após a batalha. |
| `CreatureSync` | Sincronização dos dados por UID. |
| `CreatureFactory` | Criação de instâncias, IV e personalidade. |
| `GameSession` | Novo jogo, cura, salvamento, carregamento e progresso. |
| `SaveGame` | Serialização, validação e persistência JSON. |
| `SceneManager` | Mudança de fase e retomada de posição. |
| `WildernessEncounter` | Encontros selvagens por tempo. |
| `NPC` | Diálogos, loja, cura e encontros com treinadores. |
| `PCStation` | Armazenamento e criação de vínculos. |

---

## 23. Testes e qualidade

O repositório contém testes automatizados GdUnit4 para regras de combate, crescimento, captura, persistência, vínculos e outros sistemas.

**Inconsistência da documentação:** o GDD anterior informa 76 testes, enquanto `docs/ARQUITETURA_E_TESTES.md` apresenta uma contagem diferente em seu conteúdo. Não consolidar uma quantidade definitiva sem executar a suíte completa na versão atual e atualizar os dois documentos.

A cobertura automatizada não substitui a verificação integrada das cenas. Os fluxos que dependem de física, entrada do jogador, HUD, animações, sinais e troca entre exploração e combate ainda precisam de execução manual no Godot.

### 23.1 Critérios de validação

- execução dos testes automatizados;
- verificação de encontros e transições de cena;
- execução de combate completo;
- teste de captura e preservação da instância;
- formação, uso e dissolução de Misturas e Compostos;
- aquecimento, transições térmicas, cisão e Sobrecarga;
- aprendizado e substituição de ataques;
- salvamento e carregamento de equipe, inventário e posição.

### 23.2 Performance e builds

O documento técnico existente descreve uma bateria de testes para FPS, carregamento de cenas, RAM, VRAM e integridade dos builds Windows. Os resultados quantitativos devem ser preenchidos somente após execução no ambiente-alvo. A presença de executáveis e pacotes exportados não comprova, isoladamente, desempenho ou execução correta.

---

## 24. Divergências e decisões de projeto

1. **HP:** a fórmula do código utiliza o HP-base e o ganho calculado por nível; não corresponde à fórmula de HP originalmente proposta.
2. **Crítico:** o código usa multiplicador fixo de 1,5, em vez da fórmula variável originalmente descrita.
3. **Erro:** a chance é global (1/6), não individual por ataque.
4. **Temperatura global:** `arena_temperature` é atualizada, mas a rotina consultada não propaga o calor para todos os combatentes.
5. **Temperatura individual:** o alvo atingido recebe energia térmica e pode sofrer dano ao atravessar transições de estado físico.
6. **Compostos:** a transferência de HP e energia permanece fixa em 70%; a fórmula variável por eletronegatividade e carga ainda não está integrada.
7. **Misturas:** o bônus atual é aplicado a HP e energia, não a todos os atributos.
8. **Compostos de múltiplos participantes:** a lógica atual aceita grupos de até quatro Alchemons, embora versões anteriores do GDD descrevessem somente pares.
9. **XP:** a curva atual é cúbica (N³); a recompensa é calculada pela espécie e pelo nível derrotado.
10. **Distribuição de XP:** o código atual concede XP aos participantes vivos do lado responsável pela derrota, e não somente ao autor do golpe final.
11. **Ataques por nível:** o sistema de desbloqueio e substituição está implementado; o GDD anterior ainda o classificava como pendente.
12. **Captura:** a fórmula está implementada, mas os métodos permanecem categorias provisórias.
13. **Derrota:** não há teletransporte automático para hospital.
14. **Encontros:** a rolagem é temporal, não por passos; treinadores usam área de colisão, não cone de visão.
15. **Obediência:** a insígnia existe, mas não há regra de desobediência identificada.
16. **Espécies:** o número de elementos descritos no GDD não corresponde necessariamente ao número de espécies cadastradas no banco do jogo.
17. **Testes:** a contagem informada no GDD diverge da documentação técnica e precisa de execução e reconciliação.

---

## 25. Trabalho futuro

### 25.1 Temperatura

- Definir se a temperatura da arena deve aquecer todos os participantes ou permanecer apenas como indicador global.
- Validar os valores de calor específico e o fator de escala térmica.
- Definir se estados físicos devem modificar atributos, além do dano de transição.
- Revisar a modelagem térmica de elementos que sublimam à pressão ambiente, como o Arsênio.
- Validar as fórmulas de temperatura de cisão e limites de surto com testes integrados.

### 25.2 Misturas e Compostos

- Integrar e testar a fórmula variável de transferência de atributos, caso ela permaneça como decisão de design.
- Definir formalmente a transferência ou preservação de energia de ação.
- Definir o HP inicial de Compostos formados fora de combate.
- Revisar a identificação de cátion e ânion em compostos com múltiplos participantes.
- Testar a seleção de grupos de três e quatro Alchemons na interface.
- Definir limites de Compostos simultâneos por combate.
- Verificar a possibilidade de o jogador provocar a cisão de Compostos adversários por aquecimento.

### 25.3 Captura

- Definir os métodos físicos e químicos definitivos.
- Estabelecer os multiplicadores e critérios pedagógicos de cada método.
- Implementar dicas para tentativas com método incompatível, se mantidas no design.
- Definir como capturar participantes de um Composto sem violar as regras de vínculo.

### 25.4 Progressão e combate

- Definir o nível máximo.
- Completar o balanceamento dos ataques e seus níveis de desbloqueio.
- Verificar visualmente a interface de escolha e substituição de ataques.
- Revisar as chances globais de erro e crítico.
- Avaliar a iniciativa por rodada ou por combate.

### 25.5 Mundo e conteúdo

- Criar tabelas de encontros ponderadas por região.
- Ampliar o banco de espécies jogáveis.
- Desenvolver ginásios, insígnias e sistema de obediência.
- Desenvolver hospital e retorno após derrota.
- Desenvolver Super Liga, criaturas raras e elementos artificiais.
- Implementar corrida e atalhos de salvamento/carregamento, se mantidos no escopo.

### 25.6 Validação

- Executar a suíte completa GdUnit4 e reconciliar a contagem de testes.
- Executar os fluxos manuais de integração no Godot.
- Medir FPS, carregamento, RAM e VRAM em builds de distribuição.
- Registrar versão do engine, sistema operacional, hardware, commit e data dos testes.
- Separar claramente testes automatizados, testes funcionais manuais e testes de desempenho.
