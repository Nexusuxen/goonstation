ABSTRACT_TYPE(/datum/dna_chromosome)
/datum/dna_chromosome
	var/name = "Chromosome Parent WHICH YOU SHOULD NOT BE SEEING"
	var/desc = "An abstract type that should NOT show up and you should absolutely file a bug report"

	proc/check_apply(datum/bioEffect/BE)
		if(!istype(BE))
			return "Invalid gene."
		if(BE.alreadySpliced())
			return "This gene has already been altered."
		return null

	proc/apply(datum/bioEffect/BE)
		. = src.check_apply(BE)
		if (.)
			return
		BE.addFlag(EFFECT_CANNOT_SPLICE)

/datum/dna_chromosome/stabilizer
	name = "Stabilizer"
	desc = {"Prevents a gene from causing any genetic instability when given to an organism.
	It will do nothing to genes that are already present in an organism."}

	check_apply(datum/bioEffect/BE)
		. = ..()
		if(.) return
		if(!BE.stability_loss)
			return "This chromosome can only be applied to genes that cause stability loss."
		return null

	apply(datum/bioEffect/BE)
		. = ..()
		if(.) return
		BE.name = "Stabilized " + BE.name
		BE.addFlag(EFFECT_STABILIZED)
		if(BE.holder)
			BE.holder.calculateStability()

/datum/dna_chromosome/anti_mutadone
	name = "Reinforcer"
	desc = "Prevents a gene from being removed by mutadone."

	check_apply(datum/bioEffect/BE)
		. = ..()
		if(.) return
		if(BE.isReinforced())
			return "This gene is already immune to mutadone."
		return null

	apply(datum/bioEffect/BE)
		. = ..()
		if(.) return
		BE.name = "Reinforced " + BE.name
		BE.addFlag(EFFECT_REINFORCED)

/datum/dna_chromosome/reclaimer
	name = "Weakener"
	desc = "Makes a gene easier to reclaim and doubles the amount of materials you get from reclaiming it."

	apply(datum/bioEffect/BE)
		. = ..()
		if(.) return
		BE.name = "Weakened " + BE.name
		BE.addFlag(EFFECT_WEAKENED)

/datum/dna_chromosome/stealth
	name = "Camouflager"
	desc = "Enables a gene to be added to a subject without them noticing immediately."

	apply(datum/bioEffect/BE)
		. = ..()
		if(.) return
		BE.name = "Camouflaged " + BE.name
		BE.addFlag(EFFECT_CAMOUFLAGED)

// Powers

/datum/dna_chromosome/power_enhancer
	name = "Power Booster"
	desc = "Makes abilities granted by genes more powerful."

	apply(datum/bioEffect/BE)
		. = ..()
		if(.) return
		BE.name = "Empowered " + BE.name
		BE.addFlag(EFFECT_EMPOWERED)
		BE.onPowerChange()

/datum/dna_chromosome/cooldown_reducer
	name = "Energy Booster"
	desc = "Allows abilities granted by genes to be used more often."

	check_apply(datum/bioEffect/power/BE)
		. = ..()
		if(.) return
		if(!istype(BE)) // there doesn't seem to be a reason for this requirement. should we get rid of it?
			return "This chromosome can only be applied to power-granting genes."

	apply(datum/bioEffect/BE)
		. = ..()
		if(.) return
		BE.name = "Energized " + BE.name
		BE.addFlag(EFFECT_ENERGIZED)

/datum/dna_chromosome/safety
	name = "Synchronizer"
	desc = "Allows dangerous abilities to be used without harm to the user."

	check_apply(datum/bioEffect/power/BE)
		. = ..()
		if(.) return
		if(!istype(BE))
			return "This chromosome can only be applied to power-granting genes."
		return null

	apply(datum/bioEffect/power/BE)
		. = ..()
		if(.) return
		BE.name = "Synchronized " + BE.name
		BE.addFlag(EFFECT_SYNCHRONIZED)

