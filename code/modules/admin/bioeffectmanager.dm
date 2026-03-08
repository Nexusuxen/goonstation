/datum/bioeffectmanager
	var/mob/target_mob

/datum/bioeffectmanager/ui_state(mob/user)
	return tgui_admin_state.can_use_topic(src, user)

/datum/bioeffectmanager/ui_status(mob/user)
	return tgui_admin_state.can_use_topic(src, user)

/datum/bioeffectmanager/ui_interact(mob/user, datum/tgui/ui)
	ui = tgui_process.try_update_ui(user, src, ui)
	if (!ui)
		ui = new(user, src, "BioEffectManager")
		ui.open()

/datum/bioeffectmanager/ui_data(mob/user)
	var/list/bioEffects = list()
	for (var/index as anything in target_mob.bioHolder?.effects)
		var/datum/bioEffect/BE = target_mob.bioHolder.effects[index]
		bioEffects += list(list(
			"name" = BE,
			"id" = BE.id,
			"stabilized" = BE.isStabilized(),
			"reinforced" = BE.isReinforced(),
			"boosted" = BE.isEmpowered(),
			"synced" = BE.isSynchronized(),
			"cooldown" = BE.isEnergized(),
			"is_power" = istype(BE, /datum/bioEffect/power)))
	. = list(
		"target_name" = target_mob,
		"bioEffects" = bioEffects,
		"stability" = target_mob.bioHolder?.genetic_stability
		)

/datum/bioeffectmanager/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if (.)
		return
	if (!target_mob?.bioHolder)
		return // mob was qdeleted
	var/datum/bioEffect/BE = target_mob.bioHolder.effects[params["id"]]
	switch(action)
		if ("addBioEffect")
			var/input = tgui_input_text(ui.user, "Enter a /datum/bioEffect path or partial name.", "Add a Bioeffect", null, allowEmpty = TRUE)
			var/datum/bioEffect/type_to_add = get_one_match(input, /datum/bioEffect, use_concrete_types=TRUE, cmp_proc=/proc/cmp_text_asc)
			if (!type_to_add)
				return
			target_mob.bioHolder.AddEffect(initial(type_to_add.id))
			target_mob.onProcCalled("addBioEffect", list(initial(type_to_add.id)))
			logTheThing(LOG_ADMIN, ui.user, "Added bioeffect [initial(type_to_add.id)] to [constructName(target_mob)]")
			. = TRUE
		if ("updateStability")
			var/new_stability = round(text2num(params["value"]))
			if (new_stability == -1) // set to -1 to clear forced stability
				target_mob.bioHolder.forced_stability = null
			else
				target_mob.bioHolder.forced_stability = isnull(new_stability) ? 0 : max(new_stability, 0)
			target_mob.bioHolder.calculateStability()
			. = TRUE
		if ("updateCooldown")
			var/new_cooldown = round(text2num(params["value"]))
			BE.cooldown = isnull(new_cooldown) ? 0 : max(new_cooldown, 0)
			. = TRUE
		if ("resetCooldown")
			var/datum/bioEffect/power/power = BE
			power.ability.last_cast = 0
		if ("toggleBoosted")
			if(!BE.isEmpowered())
				BE.addFlag(EFFECT_EMPOWERED)
			else
				BE.removeFlag(EFFECT_EMPOWERED)
			. = TRUE
		if ("toggleReinforced")
			if(!BE.isReinforced())
				BE.addFlag(EFFECT_REINFORCED)
			else
				BE.removeFlag(EFFECT_REINFORCED)
			. = TRUE
		if ("toggleStabilized")
			if (!BE.isStabilized())
				BE.addFlag(EFFECT_STABILIZED)
			else
				BE.removeFlag(EFFECT_STABILIZED)
			. = TRUE
		if ("toggleSynced")
			if(BE.isSynchronized())
				BE.removeFlag(EFFECT_SYNCHRONIZED)
			else
				BE.addFlag(EFFECT_SYNCHRONIZED)
			. = TRUE
		if ("manageBioEffect")
			ui.user.client.debug_variables(BE)
			. = TRUE
		if ("deleteBioEffect")
			target_mob.bioHolder.RemoveEffect(params["id"])
			logTheThing(LOG_ADMIN, ui.user, "Removed bioeffect [params["id"]] from [constructName(target_mob)]")
			BE.holder.calculateStability()
			. = TRUE
