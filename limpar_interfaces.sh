#!/bin/sh
# Rode na raiz do projeto Godot (pasta que tem project.godot).
# Apaga arquivos mortos de INTERFACES (ninguém referencia). Use depois de copiar game_settings.gd.
for f in \
  INTERFACES/menu.gd INTERFACES/menu.tscn \
  INTERFACES/AlchemonComponent.gd INTERFACES/bag_component.gd \
  INTERFACES/exit_flow_component.gd INTERFACES/navigation_component.gd \
  INTERFACES/pages/menu_game.gd \
  INTERFACES/ui_inventory.gd INTERFACES/ui_inventory.tscn \
  INTERFACES/assets/barras.png INTERFACES/assets/barras-energia.png
do
  for x in "$f" "$f.uid" "$f.import"; do [ -e "$x" ] && rm -v "$x"; done
done
