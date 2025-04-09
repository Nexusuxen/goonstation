/image/maptext/appraisal
	alpha = 180
	respect_maptext_preferences = FALSE
	// Many of the artifacts are upside down and stuff, it makes text a bit hard to read!
	appearance_flags = RESET_TRANSFORM | RESET_COLOR | RESET_ALPHA | PIXEL_SCALE


/// A constructor proc for `/image/maptext/appraisal`.
/proc/appraisal_maptext(sell_value)
	var/image/maptext/text = new /image/maptext/appraisal
	if (sell_value <= 0)
		text.maptext = "<span class='pixel c ol' style=\"color: #bbbbbb;\">No value</span>"
	else
		text.maptext = "<span class='pixel c ol'>[round(sell_value)][CREDIT_SIGN]</span>"

	return text


/// Displays the appraisal maptext to a specified recipient.
/proc/display_appraisal_maptext(mob/target, mob/recipient, sell_value)
	if (!recipient.client)
		return

	target.maptext_manager ||= new /atom/movable/maptext_manager(target)
	target.maptext_manager.add_maptext(recipient.client, global.appraisal_maptext(sell_value))
