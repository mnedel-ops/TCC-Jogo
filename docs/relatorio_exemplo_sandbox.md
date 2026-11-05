# Relatório de performance — TCC-Jogo

## 1. Ambiente

| Item | Valor |
|---|---|
| Data | 2026-11-05 19:48:46 |
| Commit | sw |
| Sistema operacional | Linux 24.04 |
| CPU | Intel(R) Xeon(R) Processor @ 2.80GHz (1 threads) |
| GPU | llvmpipe (LLVM 20.1.2, 256 bits) (Mesa) |
| RAM total | 3990 MB |
| Resolução | 1280x720 |
| Renderer | gl_compatibility |
| Godot | 4.6-stable (official) |
| Tipo de build | debug |
| DisplayServer | X11 |

## 2. Critérios de avaliação

| Métrica | Critério aplicado |
|---|---|
| FPS | Média >= 54 FPS (meta 60 com tolerância de 10%) e nenhum período de mais de 2 s abaixo de 30 FPS |
| Carregamento | apenas registrar; alerta se uma execução passar de 2.0× a mediana |
| Memória RAM | Após o 1º ciclo exploração-combate-retorno, crescimento <= 5.0% até o último ciclo e sem crescimento de nós órfãos (tolerância 0) |
| Estabilidade | Todas as execuções terminam com código 0, sem erros do engine no log e sem crescimento contínuo de memória |

## 3. Tempos de carregamento (ms)

| Operação | Execução 1 | Média | Desvio | Mín | Máx |
|---|---:|---:|---:|---:|---:|
| Inicialização | 1361.0 | 1361.0 | 0.0 | 1361.0 | 1361.0 |
| Carregamento da exploração | 1460.0 | 1460.0 | 0.0 | 1460.0 | 1460.0 |
| Carregamento do combate | 629.0 | 629.0 | 0.0 | 629.0 | 629.0 |
| Troca de fase (cena 1 → 2) (adicional) | 55.0 | 55.0 | 0.0 | 55.0 | 55.0 |
| Retorno do combate à exploração (adicional) | 715.0 | 715.0 | 0.0 | 715.0 | 715.0 |

Cada execução é um processo novo. **Inicialização**: do início do engine ao primeiro frame (inclui autoloads). **Exploração/combate**: do comando de carga ao primeiro frame desenhado da cena.

## 4. FPS

| Cenário | Amostras | FPS médio | FPS mínimo | 1% inferior | Frame máx (ms) | Maior período < 30 FPS (s) | Veredito |
|---|---:|---:|---:|---:|---:|---:|---|
| Exploração (2 fases) | 8 | 47.9 | 42.0 | 34.5 | 29.9 | 0 | Reprovado |
| Combate | 8 | 22.4 | 20.0 | 16.2 | 62.8 | 8 | Reprovado |

Amostra de FPS 1 vez por segundo, após 3 s de aquecimento. '1% inferior' = 1000 / percentil 99 do tempo de frame.

## 5. Memória (RAM / VRAM)

| Momento | RAM do processo (MB) | Memória estática (MB) | VRAM (MB) | Objetos | Nós | Órfãos |
|---|---:|---:|---:|---:|---:|---:|
| Início | 224.7 | 29.5 | 13.2 | 1565 | 4 | 0 |
| Após exploração | 254.7 | 71.8 | 14.8 | 1916 | 145 | 0 |
| Durante combate | 265.6 | 73.2 | 15.1 | 2153 | 238 | 0 |
| Após ciclo 1 | 266.2 | 72.4 | 15.0 | 1919 | 145 | 0 |
| Após ciclo 2 | 267.9 | 72.9 | 15.1 | 2044 | 220 | 0 |
| Após ciclo 3 | 267.9 | 72.4 | 15.0 | 1920 | 145 | 0 |

RAM do processo = memória residente (Linux/macOS) ou working set (Windows). Referência de estabilidade: ciclo 1 (aquecimento de caches).

## 6. Estabilidade

- Execuções concluídas: 2 de 2
- Códigos de saída diferentes de 0: nenhum
- Erros do engine nos logs: 2
  - `perf_load_1.log: ERROR: Condition "status < 0" is true. Returning: ERR_CANT_OPEN`
  - `perf_sustained.log: ERROR: Condition "status < 0" is true. Returning: ERR_CANT_OPEN`

## 7. Resultado

| Métrica | Veredito | Detalhe |
|---|---|---|
| FPS | Reprovado | Exploração (2 fases): média 47.9 FPS, 0 s abaixo de 30; Combate: média 22.4 FPS, 8 s abaixo de 30 |
| Carregamento | Registrado | tempos registrados, sem outliers |
| Memória RAM | Aprovado | RAM +0.6% do ciclo 1 ao 3, VRAM +0.0%, órfãos +0, sem crescimento monotônico |
| Estabilidade | Atenção | 2 erro(s) do engine nos logs |

**Resultado geral: Reprovado**
