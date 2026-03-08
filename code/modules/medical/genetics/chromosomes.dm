/datum/dna_chromosome
	var/name = "Stabilizer"
	var/desc = {"Prevents a gene from causing any genetic instability when given to an organism.
	It will do nothing to genes that are already present in an organism."}

	proc/check_apply(datum/bioEffect/BE)
		if(!istype(BE))
			return "Invalid gene."
		if(BE.altered || (BE.EFFECT_FLAGS & EFFECT_CANNOT_SPLICE))
			return "This gene has already been altered."
		if(!BE.stability_loss)
			return "This chromosome can only be applied to genes that cause stability loss."
		return null

	proc/apply(datum/bioEffect/BE)
		. = src.check_apply(BE)
		if (.)
			return

		BE.EFFECT_FLAGS |= EFFECT_STABILIZED
		BE.name = "Stabilized " + BE.name
		BE.addFlag(EFFECT_CANNOT_SPLICE)
		BE.EFFECT_FLAGS |= EFFECT_CANNOT_SPLICE
		BE.holder.calculateStability()

/datum/dna_chromosome/anti_mutadone
	name = "Reinforcer"
	desc = "Prevents a gene from being removed by mutadone."

	check_apply(datum/bioEffect/BE)
		if(!istype(BE))
			return "Invalid gene."
		if(BE.altered || (BE.EFFECT_FLAGS & EFFECT_CANNOT_SPLICE))
			return "This gene has already been altered."
		if(BE.isReinforced())
			return "This gene is already immune to mutadone."
		return null

	apply(datum/bioEffect/BE)
		. = src.check_apply(BE)
		if (.)
			return

		BE.EFFECT_FLAGS |= EFFECT_REINFORCED
		BE.name = "Reinforced " + BE.name
		BE.addFlag(EFFECT_CANNOT_SPLICE)
		BE.EFFECT_FLAGS |= EFFECT_CANNOT_SPLICE

/datum/dna_chromosome/reclaimer
	name = "Weakener"
	desc = "Makes a gene easier to reclaim and doubles the amount of materials you get from reclaiming it."

	check_apply(datum/bioEffect/BE)
		if(!istype(BE))
			return "Invalid gene."
		if(BE.altered || (BE.EFFECT_FLAGS & EFFECT_CANNOT_SPLICE))
			return "This gene has already been altered."
		return null

	apply(datum/bioEffect/BE)
		. = src.check_apply(BE)
		if (.)
			return

		BE.EFFECT_FLAGS |= EFFECT_WEAKENED
		BE.name = "Weakened " + BE.name
		BE.addFlag(EFFECT_CANNOT_SPLICE)
		BE.EFFECT_FLAGS |= EFFECT_CANNOT_SPLICE

/datum/dna_chromosome/stealth
	name = "Camouflager"
	desc = "Enables a gene to be added to a subject without them noticing immediately."

	check_apply(datum/bioEffect/BE)
		if(!istype(BE))
			return "Invalid gene."
		if(BE.altered || (BE.EFFECT_FLAGS & EFFECT_CANNOT_SPLICE))
			return "This gene has already been altered."
		return null

	apply(datum/bioEffect/BE)
		. = src.check_apply(BE)
		if (.)
			return

		BE.msgGain = ""
		BE.msgLose = ""
		BE.EFFECT_FLAGS |= EFFECT_CAMOUFLAGED
		BE.name = "Camouflaged " + BE.name
		BE.addFlag(EFFECT_CANNOT_SPLICE)
		BE.EFFECT_FLAGS |= EFFECT_CANNOT_SPLICE

// Powers

/datum/dna_chromosome/power_enhancer
	name = "Power Booster"
	desc = "Makes abilities granted by genes more powerful."

	check_apply(datum/bioEffect/BE)
		if(!istype(BE))
			return "Invalid Gene."
		if(BE.altered || (BE.EFFECT_FLAGS & EFFECT_CANNOT_SPLICE))
			return "This gene has already been altered."
		return null

	apply(datum/bioEffect/power/BE)
		. = src.check_apply(BE)
		if (.)
			return
		BE.EFFECT_FLAGS |= EFFECT_EMPOWERED
		BE.name = "Empowered " + BE.name
		BE.addFlag(EFFECT_CANNOT_SPLICE)
		BE.EFFECT_FLAGS |= EFFECT_CANNOT_SPLICE
		BE.onPowerChange()

/datum/dna_chromosome/cooldown_reducer
	name = "Energy Booster"
	desc = "Allows abilities granted by genes to be used more often."

	check_apply(datum/bioEffect/power/BE)
		if(!istype(BE))
			return "This chromosome can only be applied to power-granting genes."
		if(BE.altered || (BE.EFFECT_FLAGS & EFFECT_CANNOT_SPLICE))
			return "This gene has already been altered."
		if(!BE.cooldown)
			return "This chromosome cannot be applied to this power gene."
		return null

	apply(datum/bioEffect/power/BE)
		. = src.check_apply(BE)
		if (.)
			return

		BE.EFFECT_FLAGS |= EFFECT_ENERGIZED
		BE.name = "Energized " + BE.name
		BE.addFlag(EFFECT_CANNOT_SPLICE)
		BE.EFFECT_FLAGS |= EFFECT_CANNOT_SPLICE

/datum/dna_chromosome/safety
	name = "Synchronizer"
	desc = "Allows dangerous abilities to be used without harm to the user."

	check_apply(datum/bioEffect/power/BE)
		if(!istype(BE))
			return "This chromosome can only be applied to power-granting genes."
		if(BE.altered || (BE.EFFECT_FLAGS & EFFECT_CANNOT_SPLICE))
			return "This gene has already been altered."
		if(BE.isSynchronized())
			return "This chromosome cannot be applied to this power gene."
		return null

	apply(datum/bioEffect/power/BE)
		. = src.check_apply(BE)
		if (.)
			return

		BE.EFFECT_FLAGS |= EFFECT_SYNCHRONIZED
		BE.name = "Synchronized " + BE.name
		BE.addFlag(EFFECT_CANNOT_SPLICE)
		BE.EFFECT_FLAGS |= EFFECT_CANNOT_SPLICE
