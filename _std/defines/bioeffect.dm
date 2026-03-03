#define EFFECT_TYPE_MUTANTRACE 1
#define EFFECT_TYPE_DISABILITY 2
#define EFFECT_TYPE_POWER 3
#define EFFECT_TYPE_FOOD 4

#define EFFECT_RESEARCH_NONE 0
#define EFFECT_RESEARCH_IN_PROGRESS 1
#define EFFECT_RESEARCH_DONE 2
#define EFFECT_RESEARCH_ACTIVATED 3

/*
* (1 + (src.gene_data & EFFECT_EMPOWERED)) is used to maintain parity before and after chromosomes
 have been refactored. Since it used to be * 2 for empowered genes, this retains the *2 multiplier
*/

#define EFFECT_CANNOT_SPLICE (1 << 0)
#define EFFECT_STABILIZED (1 << 1)
#define EFFECT_EMPOWERED (1 << 2)
#define EFFECT_ENERGIZED (1 << 3)
#define EFFECT_SYNCHRONIZED (1 << 4)
#define EFFECT_REINFORCED (1 << 5)
#define EFFECT_WEAKENED (1 << 6)
#define EFFECT_CAMOUFLAGED (1 << 7)


