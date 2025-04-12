TYPEINFO(/obj/machinery/phone)
	mats = 25

/obj/machinery/phone
	name = "phone"
	icon = 'icons/obj/machines/phones.dmi'
	desc = "A landline phone. In space. Where there is no land. Hmm."
	icon_state = "phone"
	anchored = ANCHORED
	density = 0
	deconstruct_flags = DECON_SCREWDRIVER | DECON_WIRECUTTERS | DECON_MULTITOOL
	_health = 25
	color = null
	custom_suicide = TRUE
	var/obj/item/phone_handset/handset = null
	var/obj/machinery/phone/linked = null
	var/answered_icon = "phone_answered"
	var/dialicon = "phone_dial"
	var/phone_icon = "phone"
	var/ringing_icon = "phone_ringing"
	var/last_called = null
	var/caller_id_message = null
	var/phone_category = null
	var/phone_id = null
	var/stripe_color = null
	var/handset_taken = FALSE
	// todo: make do something. currently does nothing.
	var/can_talk_across_z_levels = TRUE
	var/connected = TRUE
	// Deprecated. todo: remove all instances of this var
	var/emagged = FALSE
	var/labelling = FALSE
	var/unlisted = FALSE
	/// What switchboard (phone network) should our phone component register to while initializing
	/// Safe to map edit. Doing anything other than "NT13" will isolate your phone from station phones
	var/switchboard = "NT13"
	/// Locally-stored phonebook we use for emag shenanigans
	var/list/phonebook
	/// Ring message to display when emagged
	var/prank_caller

/obj/machinery/phone/New()
	. = ..() // Set up power usage, subscribe to loop, yada yada yada
	src.icon_state = "[phone_icon]"
	var/area/location = get_area(src)

	// Give the phone an appropriate departmental color. Jesus christ thats fancy.
	if (isnull(src.stripe_color)) // maps can override it now
		if (istype(location,/area/station/security))
			src.stripe_color = "#ff0000"
			src.phone_category = "security"
		else if (istype(location,/area/station/bridge))
			src.stripe_color = "#00ff00"
			src.phone_category = "bridge"
		else if (istype(location, /area/station/engine) || istype(location, /area/station/quartermaster) || istype(location, /area/station/mining))
			src.stripe_color = "#ffff00"
			src.phone_category = "engineering"
		else if (istype(location, /area/station/science))
			src.stripe_color = "#8409ff"
			src.phone_category = "research"
		else if (istype(location, /area/station/medical))
			src.stripe_color = "#3838ff"
			src.phone_category = "medical"
		else
			src.stripe_color = "#b65f08"
			src.phone_category = "uncategorized"
	else
		src.phone_category = "uncategorized"

	src.UpdateOverlays(image('icons/obj/machines/phones.dmi',"[src.dialicon]"), "dial")
	var/image/stripe_image = image('icons/obj/machines/phones.dmi',"[src.icon_state]-stripe")
	stripe_image.color = src.stripe_color
	stripe_image.appearance_flags = RESET_COLOR | PIXEL_SCALE
	src.UpdateOverlays(stripe_image, "stripe")

	// Generate a name for the phone.
	if (isnull(src.phone_id))
		var/temp_name = src.name
		if ((temp_name == src::name) && location)
			temp_name = location.name

		var/name_counter = 1
		for_by_tcl(M, /obj/machinery/phone)
			if (M.phone_id && (M.phone_id == temp_name))
				name_counter++

		if (name_counter > 1)
			temp_name = "[temp_name] [name_counter]"

		src.phone_id = temp_name

	src.add_components()
	src.handset = new /obj/item/phone_handset(src)

	RegisterSignal(src, COMSIG_CORD_RETRACT, PROC_REF(hang_up))
	// ringer component just handles the sound, we gotta do the icon stuff ourselves
	RegisterSignal(src, COMSIG_PHONE_START_RING, PROC_REF(start_ring))
	RegisterSignal(src, COMSIG_PHONE_STOP_RING, PROC_REF(stop_ring))
	RegisterSignal(src, COMSIG_PHONE_BOOK_DATA, PROC_REF(update_phonebook))
	START_TRACKING

/obj/machinery/phone/disposing()
	qdel(src.handset)
	UnregisterSignal(src, COMSIG_CORD_RETRACT)
	STOP_TRACKING
	. = ..()

/obj/machinery/phone/get_desc()
	if (!isnull(src.phone_id))
		return " There is a small label on the phone that reads \"[src.phone_id]\"."

/obj/machinery/phone/proc/add_components()
	var/datum/component/phone_networker/net_comp = src.AddComponent(/datum/component/phone_networker, phone_id, phone_category, switchboard)
	src.AddComponent(/datum/component/phone_ui, src, phone_id, net_comp)
	src.AddComponent(/datum/component/phone_ringer_atom, src, net_comp, TRUE)

/obj/machinery/phone/attack_ai(mob/user)
	return

/obj/machinery/phone/attackby(obj/item/P, mob/living/user)
	if (istype(P, /obj/item/phone_handset))
		var/obj/item/phone_handset/PH = P
		if (PH.parent == src)
			src.hang_up()
		return

	if (issnippingtool(P))
		if (src.connected)
			if (user)
				boutput(user,"You cut the phone line leading to the phone.")
			src.connected = FALSE
			if(!src.emagged)
				SEND_SIGNAL(src, COMSIG_PHONE_SWITCHBOARD_UNREGISTER)
		else
			if (user)
				boutput(user,"You repair the line leading to the phone.")
			src.connected = TRUE
			if(!src.emagged)
				SEND_SIGNAL(src, COMSIG_PHONE_SWITCHBOARD_REGISTER, switchboard)
		return

	if (ispulsingtool(P))
		if (src.labelling)
			return
		src.labelling = TRUE

		var/text = tgui_input_text(user, "What do you want to name this phone?", null, null, max_length = 50)
		src.labelling = FALSE
		text = sanitize(html_encode(text))
		if (!text || !in_interact_range(src, user))
			return

		src.phone_id = text
		boutput(user, SPAN_NOTICE("You rename the phone to \"[src.phone_id]\"."))
		update_info()
		return

	. = ..()
	src._health -= P.force
	attack_particle(user, src)
	user.lastattacked = get_weakref(src)
	hit_twitch(src)
	playsound(src.loc, 'sound/impact_sounds/Metal_Hit_Light_1.ogg', 50, 1)

	if (src._health <= 0)
		src.gib(src.loc)
		qdel(src)

/obj/machinery/phone/attack_hand(mob/living/user)
	. = ..(user)

	if (src.handset.loc != src)
		return

	if (src.emagged)
		src.explode()
		return

	src.AddComponent(/datum/component/cord, src.handset, base_offset_x = -4, base_offset_y = -1)
	user.put_in_hand_or_drop(src.handset)
	src.handset_taken = TRUE

	src.icon_state = "[answered_icon]"
	src.UpdateIcon()
	playsound(user, 'sound/machines/phones/pick_up.ogg', 50, FALSE)

	if(!(SEND_SIGNAL(src, COMSIG_PHONE_PICKUP) & PHONE_ANSWERED))
		if(!src.connected)
			boutput(user,SPAN_ALERT("As you pick up the phone you notice that the cord has been cut!"))
		else
			SEND_SIGNAL(src, COMSIG_PHONE_UI_INTERACT, user, FALSE)

/obj/machinery/phone/proc/update_phonebook(var/signal_parent, var/list/phonebook_new, var/append = FALSE)
	if(!append)
		phonebook = phonebook_new
		return
	phonebook.Add(phonebook_new)

/obj/machinery/phone/emag_act(mob/user, obj/item/card/emag/E)
	src.icon_state = "[ringing_icon]"
	src.UpdateIcon()

	if (src.emagged)
		return FALSE

	if (user)
		boutput(user, SPAN_ALERT("You short out the control circuit on the [src]."))
	src.emagged = TRUE

	if (length(phonebook))
		var/list/prank_category = pick(phonebook)["category"]
		var/prank_name = prank_category["phones"]["id"]
		var/prank_color = "#b65f08"
		switch(prank_category)
			if("security")
				prank_color = "#ff0000"
			if ("bridge")
				prank_color = "#00ff00"
			if ("engineering")
				prank_color = "#ffff00"
			if ("research")
				prank_color = "#8409ff"
			if ("medical")
				prank_color = "#3838ff"
		prank_caller = "<span style=\"color: [prank_color];\">[prank_name]</span>"
	else
		prank_caller = "<span style=\"color: #cccccc;\">???</span>"
	SEND_SIGNAL(src, COMSIG_PHONE_SWITCHBOARD_UNREGISTER) // can't handle phonecalls while emagged

	return TRUE

/obj/machinery/phone/demag(var/mob/user)
	if(!src.emagged)
		return FALSE
	if (user)
		boutput(user, SPAN_ALERT("You repair the control circuit on the [src]."))
	src.emagged = FALSE

	src.icon_state = "[answered_icon]"
	src.UpdateIcon()

	if(src.connected)
		SEND_SIGNAL(src, COMSIG_PHONE_SWITCHBOARD_REGISTER)

/obj/machinery/phone/process()
	if (src.emagged)
		playsound(src.loc,'sound/machines/phones/ring_incoming.ogg', 100, 1)
		if (!src.handset_taken)
			src.say("Call from [src.prank_caller].", flags = SAYFLAG_IGNORE_HTML)
			src.icon_state = "[ringing_icon]"
			UpdateIcon()
		return

	if (!src.connected)
		return

	if (..())
		return

/obj/machinery/phone/proc/start_ring(var/signal_parent, var/list/caller_info)
	if(isnull(caller_info))
		return // we're the one making the call, no need to shake
	src.icon_state = "[src.ringing_icon]"
	src.UpdateIcon()

/obj/machinery/phone/proc/stop_ring()
	if(handset_taken)
		return

	src.icon_state = "[phone_icon]"
	src.UpdateIcon()

/obj/machinery/phone/suicide(mob/user)
	if (!src.user_can_suicide(user))
		return FALSE

	if (ishuman(user))
		user.visible_message(SPAN_ALERT("<b>[user] bashes the [src] into [his_or_her(user)] head repeatedly!</b>"))
		user.TakeDamage("head", 150, 0)
		return TRUE
/* Deprecated, holding onto for reference for now just in case
/obj/machinery/phone/ui_interact(mob/user, datum/tgui/ui)
	ui = tgui_process.try_update_ui(user, src, ui)
	if (!ui)
		ui = new(user, src, "Phone")
		ui.open()

/obj/machinery/phone/ui_data(mob/user)
	var/list/list/list/phonebook = list()
	for_by_tcl(P, /obj/machinery/phone)
		var/match_found = FALSE
		if (P.unlisted || P == src)
			continue
		if (!(src.can_talk_across_z_levels && P.can_talk_across_z_levels) && (get_z(P) != get_z(src)))
			continue
		if (length(phonebook))
			for (var/i in 1 to length(phonebook))
				if (phonebook[i]["category"] == P.phone_category)
					match_found = TRUE
					phonebook[i]["phones"] += list(list(
						"id" = P.phone_id
					))
					break
		if (!match_found)
			phonebook += list(list(
				"category" = P.phone_category,
				"phones" = list(list(
					"id" = P.phone_id
				))
			))

	. = list(
		"dialing" = src.dialing,
		"inCall" = src.linked,
		"lastCalled" = src.last_called,
		"name" = src.name
	)

	.["phonebook"] = phonebook

/obj/machinery/phone/ui_act(action, params)
	. = ..()
	if (.)
		return
	switch (action)
		if ("call")
			if (src.dialing == TRUE || src.linked)
				return
			. = TRUE
			src.add_fingerprint(usr)
			var/id = params["target"]
			for_by_tcl(P, /obj/machinery/phone)
				if (P.phone_id == id)
					//src.call_other(P)
					SEND_SIGNAL()
					return
			boutput(usr, SPAN_ALERT("Unable to connect!"))
*/
/obj/machinery/phone/update_icon()
	. = ..()
	src.UpdateOverlays(src.SafeGetOverlayImage("stripe", 'icons/obj/machines/phones.dmi',"[src.icon_state]-stripe"), "stripe")

/obj/machinery/phone/proc/explode()
	src.blowthefuckup(strength = 2.5, delete = TRUE)

/obj/machinery/phone/proc/hang_up()
	src.handset_taken = FALSE
	SEND_SIGNAL(src, COMSIG_PHONE_HANGUP)
	src.RemoveComponentsOfType(/datum/component/cord)
	src.handset?.force_drop(sever = TRUE)
	src.handset.loc = src
	src.icon_state = "[phone_icon]"
	SEND_SIGNAL(src, COMSIG_PHONE_UI_CLOSE)
	src.UpdateIcon()
	playsound(src.loc, 'sound/machines/phones/hang_up.ogg', 50, 0)

/// Signals our phone component our current name, category, and hidden status
/obj/machinery/phone/proc/update_info()
	SEND_SIGNAL(src, COMSIG_PHONE_UPDATE_INFO, phone_id, phone_category, unlisted)


TYPEINFO(/obj/machinery/phone/wall)
	mats = 25

/obj/machinery/phone/wall
	name = "wall phone"
	icon = 'icons/obj/machines/phones.dmi'
	desc = "A landline phone. In space. Where there is no land. Hmm."
	icon_state = "wallphone"
	anchored = ANCHORED
	density = 0
	_health = 50
	phone_icon = "wallphone"
	ringing_icon = "wallphone_ringing"
	answered_icon = "wallphone_answered"
	dialicon = "wallphone_dial"


/obj/machinery/phone/unlisted
	unlisted = TRUE


/obj/item/electronics/frame/phone
	name = "Phone Frame"
	desc = "An undeployed telephone, looks like it could be deployed with a soldering iron. Phones are really that easy!"
	icon_state = "dbox"
	store_type = /obj/machinery/phone
	viewstat = 2
	secured = 2
