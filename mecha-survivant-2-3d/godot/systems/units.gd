class_name Units
extends RefCounted
## Échelle : la v2 compte en pixels, ce jeu en mètres. Une case de la v2
## (32 px) fait 2 m, donc 16 px = 1 m. Toutes les stats reprises de la v2
## (vitesses, portées, rayons) passent par ce facteur, ce qui garde intacts les
## rapports de vitesse et de portée entre le mech, la horde et les tirs.
const PX: float = 1.0 / 16.0
