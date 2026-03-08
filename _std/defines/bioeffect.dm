#define EFFECT_TYPE_MUTANTRACE 1
#define EFFECT_TYPE_DISABILITY 2
#define EFFECT_TYPE_POWER 3
#define EFFECT_TYPE_FOOD 4

#define EFFECT_RESEARCH_NONE 0
#define EFFECT_RESEARCH_IN_PROGRESS 1
#define EFFECT_RESEARCH_DONE 2
#define EFFECT_RESEARCH_ACTIVATED 3

// Effect flags
// Currently the chromosome functionalities work well enough for our needs, but feel free to add additional flags for more nuanced logic
// (e.g 'EFFECT_IGNORE_STABILITY' if a gene changes its behavior when stabilized but we want a version that doesn't do this)
// At some point we'll also probably want things like EFFECT_INNATE (replacing is_innate) in here too
#define EFFECT_CANNOT_SPLICE (1 << 0)
#define EFFECT_STABILIZED (1 << 1)
#define EFFECT_EMPOWERED (1 << 2)
#define EFFECT_ENERGIZED (1 << 3)
#define EFFECT_SYNCHRONIZED (1 << 4)
#define EFFECT_REINFORCED (1 << 5)
#define EFFECT_WEAKENED (1 << 6)
#define EFFECT_CAMOUFLAGED (1 << 7)
#define EFFECT_FROM_POOL (1 << 8)
#define EFFECT_METASTABLE (1 << 9) // stable until moved out of its	 current bioholder
