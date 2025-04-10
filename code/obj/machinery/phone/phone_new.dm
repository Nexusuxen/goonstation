/*/obj/machinery/phone_new
	name = "phone"
	icon = 'icons/obj/machines/phones.dmi'
	desc = "A landline phone. In space. Where there is no land. Hmm."
	icon_state = "phone"
	anchored = ANCHORED
	density = 0
	deconstruct_flags = DECON_SCREWDRIVER | DECON_WIRECUTTERS | DECON_MULTITOOL
	_health = 25
	color = null
	var/obj/item/phone_handset_new/handset = null
	var/obj/machinery/phone/linked = null
	var/answered_icon = "phone_answered"
	var/dialicon = "phone_dial"
	var/phone_icon = "phone"
	var/ringing_icon = "phone_ringing"
	var/phone_category = null
	var/phone_id = null // for convenience
	var/stripe_color = null
	var/last_ring = 0 // just for our effects
	///
	var/handset_taken = FALSE // unsure about this one, chief
	var/can_talk_across_z_levels = TRUE // for convenience; keep the functionality on the comp side
	var/connected = TRUE
	var/dialing = FALSE // used for delay between clicking target phone in UI and call actually starting
	// maybe remove and replace with 'dialspeed' var and have delay handled by comp?
	var/emagged = FALSE
	var/labelling = FALSE
	var/ringing = FALSE // comp should tell us when we have inbound call but we handle the effects ourselves
	var/unlisted = FALSE // for convenience
/* removed vars (compared to old phones)
last_called - datum keeps track of this
answered - was only used to handle inbound/outgoing calls, now handled by handset_taken
*/

	/// Adds and configures phone components and registers us for signals
	proc/add_components()
		//todo remove phone_ui dependency on net_comp here
		var/datum/component/phone_networker/net_comp = src.AddComponent(/datum/component/phone_networker)
		src.AddComponent(/datum/component/phone_ui, src, src.name, net_comp)
		src.AddComponent(/datum/component/phone_ringer_atom, src)

	New()
		..() // Set up power usage, subscribe to loop, yada yada yada
		src.icon_state = "[phone_icon]"
		var/area/location = get_area(src)

		// Give the phone an appropriate departmental color. Jesus christ thats fancy.
		if(isnull(stripe_color)) // maps can override it now
			if(istype(location,/area/station/security))
				stripe_color = "#ff0000"
				phone_category = "security"
			else if(istype(location,/area/station/bridge))
				stripe_color = "#00ff00"
				phone_category = "bridge"
			else if(istype(location, /area/station/engine) || istype(location, /area/station/quartermaster) || istype(location, /area/station/mining))
				stripe_color = "#ffff00"
				phone_category = "engineering"
			else if(istype(location, /area/station/science))
				stripe_color = "#8409ff"
				phone_category = "research"
			else if(istype(location, /area/station/medical))
				stripe_color = "#3838ff"
				phone_category = "medical"
			else
				stripe_color = "#b65f08"
				phone_category = "uncategorized"
		else
			phone_category = "uncategorized"
		src.UpdateOverlays(image('icons/obj/machines/phones.dmi',"[dialicon]"), "dial")
		var/image/stripe_image = image('icons/obj/machines/phones.dmi',"[src.icon_state]-stripe")
		stripe_image.color = stripe_color
		stripe_image.appearance_flags = RESET_COLOR | PIXEL_SCALE
		src.UpdateOverlays(stripe_image, "stripe")

		// Generate a name for the phone.
		if(isnull(src.phone_id))
			var/temp_name = src.name
			if(temp_name == initial(src.name) && location)
				temp_name = location.name
			var/name_counter = 1
			for_by_tcl(M, /obj/machinery/phone)
				if(M.phone_id && M.phone_id == temp_name)
					name_counter++
			if(name_counter > 1)
				temp_name = "[temp_name] [name_counter]"
			src.phone_id = temp_name

		START_TRACKING

		src.handset = new /obj/item/phone_handset_new(src)
		src.handset.loc = src

		src.add_components()

	disposing()
// add component deletion here

		if (handset_taken)
			handset.parent_phone = null
		handset = null

		STOP_TRACKING
		..()

	update_icon()
		. = ..()
		src.UpdateOverlays(src.SafeGetOverlayImage("stripe", 'icons/obj/machines/phones.dmi',"[src.icon_state]-stripe"), "stripe")

	proc/explode()
		src.blowthefuckup(strength = 2.5, delete = TRUE)

	get_desc()
		if(!isnull(src.phone_id))
			return " There is a small label on the phone that reads \"[src.phone_id]\"."

	attack_ai(mob/user as mob)
		return

	attackby(obj/item/P, mob/living/user)
		if(istype(P, /obj/item/phone_handset_new))
			var/obj/item/phone_handset_new/PH = P
			if(PH.parent_phone == src)
				return_handset(user)
			else
				boutput(user,"Hey, that's not this phone's handset! Knock that off!")
			return
		if(issnippingtool(P))
			if(src.connected)
				if(user)
					boutput(user,"You cut the phone line leading to the phone.")
				src.connected = FALSE
			else
				if(user)
					boutput(user,"You repair the line leading to the phone.")
				src.connected = TRUE
			return
		if(ispulsingtool(P))
			if(src.labelling)
				return
			src.labelling = TRUE
			var/t = tgui_input_text(user, "What do you want to name this phone?", null, null, max_length = 50)
			src.labelling = FALSE
			t = sanitize(html_encode(t))
			if(!t)
				return
			if(!in_interact_range(src, user))
				return
			src.phone_id = t
			boutput(user, SPAN_NOTICE("You rename the phone to \"[src.phone_id]\"."))
			return
		..()
		src._health -= P.force
		attack_particle(user,src)
		user.lastattacked = src
		hit_twitch(src)
		playsound(src.loc, 'sound/impact_sounds/Metal_Hit_Light_1.ogg', 50, 1)
		if(src._health <= 0)
			if(src.linked)
				src.return_handset()
			src.gib(src.loc)
			qdel(src)

	attack_hand(mob/living/user)
		..(user)
		if (src.handset_taken)
			return

		if (src.emagged)
			src.explode()
			return

		src.AddComponent(/datum/component/cord, src.handset, base_offset_x = -4, base_offset_y = -1)
		user.put_in_hand_or_drop(src.handset)
		src.handset_taken = TRUE

		src.icon_state = "[answered_icon]"
		UpdateIcon()
		playsound(user, 'sound/machines/phones/pick_up.ogg', 50, FALSE)
		SEND_SIGNAL(src, COMSIG_PHONE_UI_INTERACT, user, FALSE)
		SEND_SIGNAL(src, COMSIG_PHONE_PICKUP)

	proc/return_handset(var/mob/living/user)
		if(user)
			user.drop_item(src.handset)
		src.handset.loc = src
		src.handset_taken = FALSE
		src.icon_state = "[phone_icon]"
		UpdateIcon()
		playsound(src.loc,'sound/machines/phones/hang_up.ogg' ,50,0)
		SEND_SIGNAL(src, COMSIG_PHONE_HANGUP)


/* Notes 4 Handsets
Instead of deleting the handset when we put it back, we just store it in our parent instead
We should be initialized during phone_new.New()!
*/
/obj/item/phone_handset_new
	name = "phone handset"
	icon = 'icons/obj/machines/phones.dmi'
	desc = "I wonder if the last crewmember to use this washed their hands before touching it."
	var/obj/machinery/phone_new/parent_phone = null
	flags = TALK_INTO_HAND
	w_class = W_CLASS_TINY
	var/icon/handset_icon = null

	New(var/obj/machinery/phone/our_parent_phone)
		if(!our_parent_phone)
			return
		..()
		icon_state = "handset"
		src.parent_phone = our_parent_phone
		var/image/stripe_image = image('icons/obj/machines/phones.dmi',"[src.icon_state]-stripe")
		stripe_image.color = parent_phone.stripe_color
		stripe_image.appearance_flags = RESET_COLOR | PIXEL_SCALE
		src.color = parent_phone.color
		src.UpdateOverlays(stripe_image, "stripe")
		src.handset_icon = getFlatIcon(src)
		processing_items.Add(src)
		add_components()

	/// Adds phone components to the handset
	proc/add_components()
		src.AddComponent(/datum/component/phone_microphone, parent_phone)
		src.AddComponent(/datum/component/phone_speaker_atom, parent_phone)

	talk_into(mob/M as mob, text, secure, real_name, lang_id)
		..()
		SEND_SIGNAL(src, COMSIG_PHONE_SPOKEN_INTO, M, text, secure, real_name, lang_id)



/*
/obj/item/brick/brick_phone
	name = "Ultrabrick 9000"
	desc = "Wow, a brick-phone! This is bleeding-edge technology!"

	/obj/item/brick/brick_phone/Topic(href, href_list)
		..()
		if(href_list[])

	attack_hand(mob/user)
		user.Browse(info, "window=Telecommunications Node")
*/


*/
