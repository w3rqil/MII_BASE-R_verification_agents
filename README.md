# 1.6TBASE-R signal checker

![img](img/BASER_257b_checker_block_diagram.png)
![img](img/BASER_66b_checker_block_diagram.png)

## Descripción General

Este proyecto consiste en dos agentes de verificación -`BASER_257b_checker` y `BASER_66b_checker`- que analizan las tramas de PCS 256b/257b y 64b/66b respectivamente. Estos poseen contadores que indican la cantidad de tramas inválidas recibidas.

### Contadores

- `o_block_count`: Total de tramas recibidas, de las cuales:
    - `o_data_count`: Tramas con todos los bloques/octetos de dato.
    - `o_ctrl_count`: Tramas con al menos un bloque/octeto de control.
- `o_inv_block_count`: Total de tramas inválidas, de las cuales:
    - `o_inv_pattern_count`: Tramas con un patrón de caracter diferente al especificado en los parámetros.
    - `o_inv_format_count`: Tramas con un formato que no existe en la norma.
    - `o_inv_sh_count`: Tramas con sync header inválido.