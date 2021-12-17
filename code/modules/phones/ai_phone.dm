/*
Note: Behavior is necessarily split up between a few files. At this time:
/machines/phone.dm handles hotkey-calling, silicon/ai.dm handles initialization/creation and setting a var or two,
living.dm handles routing :4 speech to the phone, and /hud/ai.dm calls handlePhoneAccess


*/

/datum/phone/ai
	var/mob/living/silicon/ai/mainframe /// mainframe instead of ourHolder, since this is a bit more clear as to what we're referring to
	canVape = TRUE // as an avid ai player: lmao
	var/atom/movable/screen/hudButton = null /// Reference to the HUD button which controls this phone
	var/atom/movable/screen/muteButton = null /// Reference to the HUD mute button
	var/datum/tgui/phoneUI = null /// Corresponds to the UI; since only the AI player should be able to open it, we can do this
	phoneName = "AI Internal Landline"
	diallingSound = 'sound/machines/phones/ai_dial.ogg'
	var/muted = FALSE /// Handles whether or not incoming rings are muted; *only* incoming rings, however.
	var/lastRing = 0 /// When we last rang; increments in 1 every time doRing() is proc'd by the lifeloop


	startPhoneCall(var/toCall, var/forceStart, var/doGroupCall = FALSE, var/manuallyDialled = FALSE)
		lastRing = 0 // we don't want it to make the ring noise when it's making other noises
		. = ..()
		if(.)
			doRing(callStart = TRUE)
		else
			flick("phone_failed_animated", hudButton)
		updateButton()


	receiveInvite()
		. = ..()
		if(.)
			doRing(callStart = TRUE)
		updateButton()


	/// Proc'd when the AI user clicks on the phone UI button; handles all the logic for accessing the phone
	proc/handlePhoneAccess(var/mob/living/silicon/ai/user)
		if (incomingCall && !joinPhoneCall(incomingCall))
			flick("phone_failed_animated", hudButton)
		else
			ui_interact(user)


	/// Proc'd when the AI user clicks on the toggle ringer button; handles all the logic for muting and unmuting the ringer
	proc/toggleRinger()
		if(!muted)
			muteButton.icon_state = "ringer_off"
			muted = TRUE
		else
			muteButton.icon_state = "ringer_on"
			muted = FALSE


	/// Checks what visual state our hud button should be in and updates it accordingly
	proc/updateButton()
		if (!isBusy() && !phoneUI)
			hudButton.icon_state = "phone"
			hudButton.underlays = list("button")

		else if (!isBusy() && phoneUI)
			hudButton.icon_state = "phone_pickedup"
			hudButton.underlays = list("button")

		else if (incomingCall)
			hudButton.icon_state = "phone" // The ring animation will flick() during each ring
			hudButton.underlays = list("button_flashing_orange")

		else if (length(currentPhoneCall?.pendingMembers))
			hudButton.icon_state = "phone_pending"
			hudButton.underlays = list("button")

		else if (length(currentPhoneCall?.getMembers()) >= 2)
			hudButton.icon_state = "phone_answered"
			hudButton.underlays = list("button")

		else if (!length(currentPhoneCall?.pendingMembers) && !currentPhoneCall?.isGroupCall && !dialing && !startingCall)
			hudButton.icon_state = "phone_failed"
			hudButton.underlays = list("button")


	/// callStart is only TRUE when we an incoming call is first received, forcing it to immediately ring the other end
	proc/doRing(callStart = FALSE)
		var/pendingCallMembers = currentPhoneCall?.pendingMembers
		lastRing++
		if(incomingCall && ((src.lastRing >= 3) || callStart))
			if(!muted)
				handleSound("sound/machines/phones/ai_incoming.ogg" ,40,0)
			flick("phone_ringing", hudButton)
			lastRing = 0

		else if((length(pendingCallMembers) > 0) && ((src.lastRing >= 3) || callStart))
			lastRing = 0
			handleSound("sound/machines/phones/ring_outgoing.ogg" ,40,0)


	ui_interact(mob/user, datum/tgui/ui)
		ui = tgui_process.try_update_ui(user, src, ui)
		if(!ui)
			ui = new(user, src, "PhoneDefault")
			ui.open()
			phoneUI = ui // and also im not sure how to carry over the ui var from a . = ..() call so fuck it we gotta redefine it yay
		updateButton() // *apparently* we can't call this after we call ui_interact() in another proc, for some god damn reason

	ui_close(mob/user)
		. = ..()
		phoneUI = null
		updateButton()

	handleSound(soundin, vol, vary, extrarange, pitch, ignore_flag, channel, flags)
		// not 100% sure if we should not play sounds to shell, hm
		mainframe.soundToPlayer(soundin, vol, vary, extrarange, pitch, ignore_flag, channel, flags)

	speechReceived(datum/phone/source, mob/M, text, secure, real_name, lang_id, initialText)
		mainframe.show_message(text)

	sendSpeech(mob/M, text, secure, real_name, lang_id, initialText)
		var/phone_icon = "<img class=\"icon misc\" style=\"position: relative; bottom: -3px;\" src=\"[resource("images/radio_icons/ai.png")]\">"
		initialText = text
		text = "<span class='game say'><span class='bold'>[M.name] \[<span style=\"color:#7F7FE2\">[phone_icon] AI Landline</span>\] says, </span> <span class='message'>\"[text[1]]\"</span></span>"
		. = ..()

	onRemoteJoin(datum/phone/connectedPhone)
		. = ..()
		updateButton()

	onRemoteDisconnect(datum/phone/disconnectedPhone)
		. = ..()
		updateButton()

/// handles ringing for the AI's phone
/datum/lifeprocess/ai_phone
	process()
		. = ..()
		if(isAI(owner))
			var/mob/living/silicon/ai/ai_owner = owner
			ai_owner.internal_phone.doRing()
