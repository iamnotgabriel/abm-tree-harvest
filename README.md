# Agent Based Model - Tree harvest
_TO DO project decription_

## Different implementations
### [model_regen_percent](https://github.com/gfborges/abm-tree-harvest/blob/master/modelo_regen_percent.lua)
Increment based on percentages of number of trees inside the given class.

### [model_regen_const](https://github.com/gfborges/abm-tree-harvest/blob/master/modelo_regen_const.lua)
Increment is constant in all classes and is based on a mean diameter.

### [model_regen_groups](https://github.com/gfborges/abm-tree-harvest/blob/master/modelo_regen_groups.lua)
Classes are a collection of tree groups, each group has a mean diameter.

## Folders
### Authors
There is a paste for results of every author(Annual diametric increment)

### Notebooks
_TODO change of notebook to script_
Generate all charts

### Dados
Input (CELL_GRID_ENTRADA_MODELO) and output of all runs 

## .csv files endings
Results of runs have one of the four endings :
* pp is adding new trees, but there is no extraction
* ex is adding new trees with extration (a number in the end is a change in equation of the model)
* _no sufix means result without new trees and no extration_ 