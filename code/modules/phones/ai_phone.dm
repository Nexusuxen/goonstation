/*
Note: Behavior is necessarily split up between a few files. At this time:
/machines/phone.dm handles hotkey-calling, silicon/ai.dm handles initialization/creation and setting a var or two,
living.dm handles routing :4 speech to the phone, and /hud/ai.dm calls handlePhoneAccess


*/

/datum/phone/ai
	var/mob/living/silicon/ai/mainframe // instead of ourHolder, since this is a bit more clear
	var/canVape = TRUE // as an avid ai player: lmao
	var/datum/hud/ai/phone/phoneButton = null // set in ai.New()
	phoneName = "AI Internal Landline"

	proc/handlePhoneAccess(var/mob/living/silicon/ai/user)
		if (incomingCall)
			joinPhoneCall(incomingCall)
		

