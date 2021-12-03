/obj/machinery/phone
	name = "phone"
	icon = 'icons/obj/machines/phones.dmi'
	desc = "A landline phone. In space. Where there is no land. Hmm."
	icon_state = "phone"
	anchored = 1
	density = 0
	mats = 25
	deconstruct_flags = DECON_SCREWDRIVER | DECON_WIRECUTTERS | DECON_MULTITOOL
	_health = 50
	var/can_talk_across_z_levels = 0
	var/phone_id = null
	var/obj/machinery/phone/linked = null
	var/ringing = 0
	var/answered = 0
	var/last_ring = 0
	var/connected = 1
	var/emagged = 0
	var/dialing = 0
	var/labelling = 0
	var/unlisted = FALSE
	var/obj/item/phone_handset/handset = null
	var/chui/window/phonecall/phonebook
	var/phoneicon = "phone"
	var/ringingicon = "phone_ringing"
	var/answeredicon = "phone_answered"
	var/dialicon = "phone_dial"
	var/mob/living/silicon/ai/mainframe = null // for AI phones, but defining it here makes the code cleaner so we can just do if(mainframe) instead of if(istype- blah blah




	New()
		..() // Set up power usage, subscribe to loop, yada yada yada
		src.icon_state = "[phoneicon]"
		var/area/location = get_area(src)

		// Give the phone an appropriate departmental color. Jesus christ thats fancy.
		if(istype(location,/area/station/security))
			src.color = "#ff0000"
		else if(istype(location,/area/station/bridge))
			src.color = "#00aa00"
		else if(istype(location, /area/station/engine) || istype(location, /area/station/quartermaster) || istype(location, /area/station/mining))
			src.color = "#aaaa00"
		else if(istype(location, /area/station/science))
			src.color = "#9933ff"
		else if(istype(location, /area/station/medical))
			src.color = "#0000ff"
		else
			src.color = "#663300"
		src.overlays += image('icons/obj/machines/phones.dmi',"[dialicon]")
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

		src.desc += " There is a small label on the phone that reads \"[src.phone_id]\""

		START_TRACKING

		return

	disposing()

		if (linked)
			linked.linked = null
			linked = null
			linked.ringing = 0
			linked.dialing = 0

		answered = 0
		ringing = 0
		dialing = 0

		if (handset)
			handset.parent = null
		handset = null

		STOP_TRACKING
		..()

	// Attempt to pick up the handset
	attack_hand(mob/living/user as mob)
		..(user)
		if(src.answered == 1)
			return

		src.handset = new /obj/item/phone_handset(src,user)
		user.put_in_hand_or_drop(src.handset)
		src.answered = 1

		src.icon_state = "[answeredicon]"
		playsound(user, "sound/machines/phones/pick_up.ogg", 50, 0)

		if(src.ringing == 0) // we are making an outgoing call
			if(src.connected == 1)
				if(user)
					if(!src.phonebook)
						src.phonebook = new /chui/window/phonecall(src)
					phonebook.Subscribe(user.client)
			else
				if(user)
					boutput(user,"<span class='alert'>As you pick up the phone you notice that the cord has been cut!</span>")
		else
			src.answerPhone()
		return

	attack_ai(mob/user as mob)
		return

	attackby(obj/item/P as obj, mob/living/user as mob)
		if(istype(P, /obj/item/phone_handset))
			var/obj/item/phone_handset/PH = P
			if(PH.parent == src)
				user.drop_item(PH)
				qdel(PH)
				hang_up()
			return
		if(istype(P,/obj/item/wirecutters))
			if(src.connected == 1)
				if(user)
					boutput(user,"You cut the phone line leading to the phone.")
				src.connected = 0
			else
				if(user)
					boutput(user,"You repair the line leading to the phone.")
				src.connected = 1
			return
		if(istype(P,/obj/item/device/multitool))
			if(src.labelling == 1)
				return
			src.labelling = 1
			var/t = input(user, "What do you want to name this phone?", null, null) as null|text
			t = sanitize(html_encode(t))
			if(t && length(t) > 50)
				return
			if(t)
				src.phone_id = t
			src.labelling = 0
			return
		..()
		src._health -= P.force
		attack_particle(user,src)
		if(src._health <= 0)
			if(src.linked)
				hang_up()
			src.gib(src.loc)
			qdel(src)

	emag_act(var/mob/user, var/obj/item/card/emag/E)
		src.icon_state = "[ringingicon]"
		if (!src.emagged)
			if(user)
				boutput(user, "<span class='alert'>You short out the ringer circuit on the [src].</span>")
			src.emagged = 1
			return 1
		return 0

	process()
		if(src.emagged == 1)
			playsound(src.loc,"sound/machines/phones/ring_incoming.ogg" ,100,1)
			if(src.answered == 0)
				src.icon_state = "[ringingicon]"
			return

		if(src.connected == 0)
			return

		if(..())
			return

		if(src.ringing) // Are we calling someone
			src.last_ring++
			if(src.linked && src.linked.answered == 0)
				if(src.last_ring >= 2)
					doRing()
			else
				if(src.last_ring >= 2)
					doRing()

	receive_silicon_hotkey(var/mob/user)
		..()

		if (!isAI(user))
			return

		var/mob/living/silicon/ai/userAI
		if (isAIeye(user))
			var/mob/dead/aieye/eye = user
			userAI = eye.mainframe
		else userAI = user
		var/obj/machinery/phone/ai/internal_phone = userAI.internal_phone

		if (user.client.check_key(KEY_OPEN))
			if (!src.connected || src.unlisted)
				boutput(user, "<span class='alert'>You can't access this phone!</span>")
				return
			. = 1
			internal_phone.engagePhone(user, src)
			return

	proc/hang_up(var/destroyed = FALSE) // are we hanging up because we got fucking destroyed?
		src.answered = 0
		if(src.linked) // Other phone needs updating
			if(!src.linked.answered) // nobody picked up. Go back to not-ringing state
				src.linked.icon_state = "[src.linked.phoneicon]"
			else if(src.linked.handset && src.linked.handset.holder)
				if(src.linked.mainframe)
					var/obj/machinery/phone/ai/aiPhone = src.linked
					var/mob/ai = aiPhone.mainframe.get_message_mob()
					ai.playsound_local(ai,"sound/machines/phones/remote_hangup.ogg",35,0)
					aiPhone.phoneButton.icon_state = "phone_pickedup"
					flick("phone_failed_animated", aiPhone.phoneButton)
					aiPhone.disengagePhone()
				else
					src.linked.handset.holder.playsound_local(src.linked.handset.holder,"sound/machines/phones/remote_hangup.ogg",50,0)
			if(src.linked) // aiPhone.disengagePhone() sets linked to null, so we gotta check to prevent runtimes
				src.linked.ringing = 0
				src.linked.linked = null
				src.linked = null

		if(mainframe)
			var/mob/ai = mainframe.get_message_mob() // we're making this not sound like the ai is literally putting a phone down
			ai.playsound_local(ai,"sound/machines/phones/remote_hangup.ogg",35,0)
			mainframe.hud.phone.icon_state = "phone"
			flick("phone_hangup", mainframe.hud.phone)

		else
			playsound(src.loc,"sound/machines/phones/hang_up.ogg" ,50,0)

		src.ringing = 0
		src.handset = null
		src.icon_state = "[phoneicon]"

	// This makes phones do that thing that phones do
	proc/call_other(var/obj/machinery/phone/target)
		// Dial the number
		if(!src.handset || src.dialing) // we're already dialing, we can't do it more than once at a time, doofus!
			return
		src.dialing = 1

		var/mob/recipient = src.handset.holder // this is so we know what mob to play sounds to
		if(mainframe) // since AIs can be either in their eye or mainframe
			recipient = mainframe.get_message_mob()

		if(!isnull(recipient))
			if(mainframe)
				// source: https://freesound.org/people/wtermini/sounds/546450/ (cropped)
				recipient.playsound_local(recipient,"sound/machines/phones/speed_dial.ogg",50,0)
			else
				recipient.playsound_local(recipient,"sound/machines/phones/dial.ogg",50,0)
		SPAWN_DBG(4 SECONDS)
			if(!src.handset) // did we hang up when dialing, for some reason?
				return
			// Is it busy?
			if(target.answered || target.linked || target.connected == 0)
				if(!isnull(recipient))
					recipient.playsound_local(recipient,"sound/machines/phones/phone_busy.ogg",50,0)
				if(mainframe)
					var/atom/movable/screen/phoneButton = mainframe.hud.phone
					phoneButton.icon_state = "phone_pickedup"
					flick("phone_failed_animated", phoneButton)
				src.dialing = 0
				return

			// Start ringing the other phone (handled by process)
			src.linked = target
			target.linked = src
			src.ringing = 1
			src.linked.ringing = 1
			src.dialing = 0
			// this is to make the ringing more responsive/instantaneous rather than waiting for process() to catch up
			// also lets us know when we start ringing to set icons for the AI!
			src.doRing(start = TRUE)
			src.linked.doRing(start = TRUE)
			return

	/// Handles specifically ringing; either receiving or outgoing. Does NOT handle dialtone. This is intended to be called on both the caller and linked phone
	proc/doRing(var/start = FALSE) // we wanna know if we've just started ringing or not
		if(!ringing)
			return
		if(linked.linked != src)
			linked = null
			return // couldn't figure out why phones sometimes didn't properly unlink so this bandaid is here until that's fixed
		last_ring = 0
		if(answered && !linked.answered && handset?.holder) // they haven't picked up yet
			handset.holder.playsound_local(handset,"sound/machines/phones/ring_outgoing.ogg",40,0)
			if(mainframe && start)
				mainframe.hud.phone.icon_state = "phone_pending"
		else if(!answered && linked.answered) // we're getting a call!
			playsound(src, "sound/machines/phones/ring_incoming.ogg",40,0)
			src.icon_state = "[ringingicon]"

	/// Handles answering the phone. Call on phone that is *answering*. Answered = 1 is assume to have been set prior.
	proc/answerPhone()
		src.ringing = 0
		src.linked.ringing = 0
		var/mob/recipient = src.linked.handset?.holder
		if(src.linked.mainframe)
			recipient = src.linked.mainframe.get_message_mob()
		if(recipient)
			recipient.playsound_local(recipient,"sound/machines/phones/remote_answer.ogg",50,0)
		if(src.linked.mainframe)
			src.linked.mainframe.hud.phone.icon_state = "phone_answered"
		if(src.mainframe)
			src.mainframe.hud.phone.icon_state = "phone_answered"




/obj/machinery/phone/custom_suicide = 1
/obj/machinery/phone/suicide(var/mob/user as mob)
	if (!src.user_can_suicide(user))
		return 0
	if (ishuman(user))
		user.visible_message("<span class='alert'><b>[user] bashes the [src] into their head repeatedly!</b></span>")
		user.TakeDamage("head", 150, 0)
		return 1



// Interface for placing a call
/chui/window/phonecall
	name = "phonebook"
	windowSize = "250x500"
	var/obj/machinery/phone/owner = null

	New(var/obj/machinery/phone/creator)
		..()
		src.owner = creator

	GetBody()
		var/html = ""
		for_by_tcl(P, /obj/machinery/phone)
			if (P.unlisted) continue
			html += "[theme.generateButton(P.phone_id, "[P.phone_id]")] <br/>"
		return html

	OnClick(var/client/who, var/id, var/data)
		if(src.owner.dialing == 1 || src.owner.linked)
			return
		if(owner)
			for_by_tcl(P, /obj/machinery/phone)
				if(P.phone_id == id)
					owner.call_other(P)
					return
		Unsubscribe(who)

	/// Handles disengaging the AI's internal phone in this context, so it doesn't have to disengage it by hitting the button the re-engage it to reopen the UI
	Unsubscribe(client/who)
		..()
		if(!owner?.mainframe)
			return
		var/obj/machinery/phone/ai/_owner = owner
		if((owner?.dialing || owner?.linked) && !_owner.disengaging) // without disengaging disengage() can't distinguish between the button and this calling it since pressing button can call this
			return // we only 'hang up' if the ai hasn't tried to dial to anyone
		_owner.disengagePhone(fromUnsubscribe = TRUE)

// Item generated when someone picks up a phone
/obj/item/phone_handset

	name = "phone handset"
	icon = 'icons/obj/machines/phones.dmi'
	desc = "I wonder if the last crewmember to use this washed their hands before touching it."
	var/obj/machinery/phone/parent = null
	var/mob/holder = null //GC WOES (just dont use this var, get holder using loc)
	flags = TALK_INTO_HAND
	w_class = 1

	New(var/obj/machinery/phone/parent_phone, var/mob/living/picker_upper)
		if(!parent_phone)
			return
		..()
		icon_state = "handset"
		src.parent = parent_phone
		src.color = parent_phone.color
		if(picker_upper)
			src.holder = picker_upper
		processing_items.Add(src)

	disposing()
		parent = null
		holder = null
		processing_items.Remove(src)
		..()

	process()
		if(!src.parent)
			qdel(src)
			return
		if(src.parent.answered == 1 && get_dist(src,src.parent) > 1)
			boutput(src.holder,"<span class='alert'>The phone cord reaches it limit and the handset is yanked back to its base!</span>")
			src.holder.drop_item(src)
			src.parent.hang_up()
			processing_items.Remove(src)
			qdel(src)

	talk_into(mob/M as mob, text, secure, real_name, lang_id)
		..()
		if(get_dist(src,holder) > 0 || !src.parent.linked || !src.parent.linked.handset) // Guess they dropped it? *shrug
			return
		var/processed = "<span class='game say'><span class='bold'>[M.name] \[<span style=\"color:[src.color]\"> [bicon(src)] [src.parent.phone_id]</span>\] says, </span> <span class='message'>\"[text[1]]\"</span></span>"
		var/mob/T = src.parent.linked.handset.holder
		//if(T?.client)
		T.show_message(processed, 2)
		M.show_message(processed, 2)

		for (var/obj/item/device/radio/intercom/I in range(3, T))
			I.talk_into(M, text, null, M.real_name, lang_id)

	// Attempt to pick up the handset
	attack_hand(mob/living/user as mob)
		..(user)
		holder = user

/obj/machinery/phone/wall
	name = "wall phone"
	icon = 'icons/obj/machines/phones.dmi'
	desc = "A landline phone. In space. Where there is no land. Hmm."
	icon_state = "wallphone"
	anchored = 1
	density = 0
	mats = 25
	_health = 50
	phoneicon = "wallphone"
	ringingicon = "wallphone_ringing"
	answeredicon = "wallphone_answered"
	dialicon = "wallphone_dial"

/obj/machinery/phone/unlisted
	unlisted = TRUE

/* nex notes

We'll wanna route everything to the AI mainframe, then route it to the eye and maybe shell as needed

Button in AI UI somewhere, likely top left panel, labeled PHONE. Clicking should behave the same as clicking a phone
Color change from blue to orange when 'picked up'. Shift click to mute/disable, turning UI dark red

mainframe.hud.phone is the datum path to the ui element controlling the phone

*/

// It's slightly hacky slapping this into an AI, but refactoring nearly 70 references to handset alone is a LOT of work
/obj/machinery/phone/ai
	name = "AI Internal Landline"
	desc = "If you are reading this and know how I became visible, file a bug report!! Also how does an AI have a landline?!"
	var/atom/movable/screen/phoneButton = null // keep track of our ai's phone hud obj so we can more easily reference it to change its appearance
	// silicon/ai.New() handles assigning the hud obj to phoneButton
	var/disengaging // lets Unsubscribe() know if it should directly call disengage()


	/// Called by the phone UI element for AIs when clicked
	proc/handlePhoneAccess(var/mob/user) // user needs to be inhabited mob (i.e eye or mainframe)
		if(!user)
			return
		if(answered)
			disengagePhone(user)
		else
			engagePhone(user)

	/// Handles the AI 'putting down' the phone, disengaging it.
	proc/disengagePhone(var/mob/user, var/fromUnsubscribe = FALSE)
		if(!fromUnsubscribe)
			src.disengaging = TRUE
		//chui is ass, fucking hell, i see why it's deprecated
		var/mob/ai = mainframe.get_message_mob()
		if(phonebook?.IsSubscribed(ai.client) && !fromUnsubscribe) // we first call Unsubscribe unless Unsubscribe called us, in which case we move to the next step. prevents loops & double hangup sounds
			phonebook.Unsubscribe(ai.client)
			return
		phoneButton.underlays = list("button")
		phoneButton.icon_state = "phone"
		// if you dial then immediately hang up
		src.answered = 0
		src.dialing = 0
		var/handsetRef = src.handset
		src.hang_up()
		if (handsetRef)
			qdel(handsetRef)
		src.disengaging = FALSE

	/// Handles the AI 'picking up' the phone, engaging it.
	proc/engagePhone(var/mob/user, var/autoCall) // set autocall to the phone id you want to automatically call
		src.answered = 1
		phoneButton.underlays = list("button_orange")
		if(!src.handset)
			src.handset = new /obj/item/phone_handset(src)
		src.handset.holder = mainframe

		if(autoCall)
			if(src.ringing || src.linked)
				boutput(user, "<span class='alert'>Your phone is already in use, hang up before trying to call another phone!</span>")
				return
			phoneButton.icon_state = "phone_pickedup"
			boutput(user, "<span class='notice'>Speed-dialing target phone...</span>")
			src.call_other(autoCall)
			return

		if(src.ringing)
			src.phoneButton.icon_state = "phone"
			src.answerPhone()

		else if(user)
			phoneButton.icon_state = "phone_pickedup"
			if(!src.phonebook)
				src.phonebook = new /chui/window/phonecall(src)
			phonebook.Subscribe(user.client)

	doRing(var/start) // we have to have our own handling for playing sounds to the AI
		if(!ringing)
			return
		src.last_ring = 0
		var/mob/ai = mainframe.get_message_mob()
		if(answered && !linked.answered) // they haven't picked up yet
			phoneButton.icon_state = "phone_pending"
			ai.playsound_local(ai,"sound/machines/phones/ring_outgoing.ogg",20,0)
		else if(!answered && linked.answered) // we're getting a call!!
			//https://freesound.org/people/infobandit/sounds/29621/
			ai.playsound_local(ai, "sound/machines/phones/ring_incoming_ai.ogg",20,0)
			if(start)
				phoneButton.underlays = list("button_flashing_orange")
			flick("phone_ringing", phoneButton)


	attack_hand(var/mob/user)
		if (!isAI(src.loc))
			qdel(src)
		boutput(user, "<span class='alert'>HOW DID YOU DO THAT, FILE A BUG REPORT, WHAT THE FUCK.</span>")
		// idk if I should make an admin log here for debugging but this should never happen anyways


/obj/machinery/phone_handset/ai
	name = "AI Internal Landline"
	desc = "If you are reading this and know how I became visible, file a bug report!! Also how does an AI have a landline?!"

	New(var/obj/machinery/phone/parent_phone, var/mob/living/picker_upper)
		if (!parent_phone)
			return // neither of these should happen but this is preemptive weirdness prevention
		if (!isAI(src.loc))
			return
		..()

	attack_hand(var/mob/user)
		if (!isAI(src.loc))
			qdel(src)
		boutput(user, "<span class='alert'>HOW DID YOU DO THAT, FILE A BUG REPORT, WHAT THE FUCK.</span>")



//
//		----------------- CELL PHONE STUFF STARTS HERE ---------------------
//


/*
		Radio Antennas. Cell phones require a signal to work!


/var/global/list/radio_antennas = list()

/obj/machinery/radio_antenna
	icon='icons/obj/large/32x64.dmi'
	icon_state = "commstower"
	var/range = 10
	var/active = 0

	process()
		..()

	proc/get_max_range()
		return range * 5

	proc/process_message()

/obj/machinery/radio_antenna/large
	range = 40

/obj/item/phone/cellphone
	icon_state = "cellphone"
	mats = 25
	_health = 20
	var/can_talk_across_z_levels = 0
	var/phone_id = null
	var/ringmode = 0 // 0 for silent, 1 for vibrate, 2 for ring
	var/ringing = 0
	var/answered = 0
	var/last_ring = 0
	var/dialing = 0
	var/labelling = 0
	var/chui/window/phonecall/phonebook
	var/phoneicon = "cellphone"
	var/ringingicon = "cellphone_ringing"
	var/answeredicon = "cellphone_answered"
	var/obj/item/ammo/power_cell/cell = new /obj/item/ammo/power_cell/med_power
	var/activated = 0


	New()
		..()

	attackby(obj/item/P as obj, mob/living/user as mob)
		if(istype(P,/obj/item/card/id))
			if(src.activated)
				if(alert("Do you want to un-register this phone?","yes","no") == "yes")
					registered = 0
					phone_id = ""
					phonelist.Remove(src)
			else
				var/obj/item/card/id/new_id = obj
				user.show_text("Activating the phone. Please wait!","blue")
				actions.start(new/datum/action/bar/icon/activate_cell_phone(src.icon_state,src,new_id), user)

		..()
		src._health -= P.force
		if(src._health <= 0)
			if(src.linked)
				hang_up()
			src.gib(src.loc)
			qdel(src)


	proc/ring()

	proc/talk_into()


	proc/find_nearest_radio_tower()
		var/min_distance = inf
		var/nearest_tower = null
		for(var/machinery/radio_tower/tower in radio_antennas)
			if(!tower.active || tower.z != src.z)
				continue
			if(max(abs(tower.x - src.x),abs(tower.y - src.y) < nearest_tower)
				nearest_tower = tower
		return nearest_tower


/obj/item/phone/cellphone/bananaphone
	name = "Banana Phone"
	icon = 'icons/obj/machines/phones.dmi'
	desc = "A cellular, bananular phone."
	icon_state = "bananaphone"
	phoneicon = "bananaphone"
	ringingicon = "bananaphone_ringing"
	answeredicon = "bananaphone_answered"

	ring()

/datum/action/bar/icon/activate_cell_phone
	duration = 50
	interrupt_flags = INTERRUPT_MOVE | INTERRUPT_ACT | INTERRUPT_STUNNED | INTERRUPT_ACTION
	id = "activate_cell_phone"
	icon = 'icons/obj/machines/phones.dmi'
	icon_state = "cellphone"
	var/obj/item/cellphone/phone
	var/registering_name

	New(icon,newphone,newid_name)
		icon_state = icon
		phone = newphone
		registering_name = newid_name
		..()


	onEnd()
		phone.registered = 1
		phone.phone_id = "[id.registered]'s Cell Phone"
		phonelist.Add(phone)
		..()

*/
