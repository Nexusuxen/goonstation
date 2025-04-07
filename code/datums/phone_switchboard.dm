/*
nex notes:
Phone components should largely not interact with the switchboard directly, and just do signals
It could probably work if we sent signals to the switchboard directly but that seems messier
and also laggier, and less flexible (what if we want things to tap into phones?)
*/

/// Handles connections between phones
/datum/phone_switchboard

	// We mess around with IDs to make it easier to transition to proper phone numbers in the future
	// Is this necessary? No, just referring to phone comp parents would be easier and cleaner.
	// But it sure is neat. And having unlisted phone numbers for espionage and
	// secret content are actual possible use cases, so fuck it, why not.
	// However, we should stick to referring to the component parents when possible for cleanliness.

	/// List of all phones we have registered
	var/list/registered_phones = list()
	/// Stores what phones are linked to a given phone, including pending and active calls
	var/list/phone_links = list()

	New()
		. = ..()
		// Phones send more signals but we listen to their comp holders, so we register for them later
		RegisterSignal(src, COMSIG_PHONE_SWITCHBOARD_REGISTER, PROC_REF(tryRegister))
		RegisterSignal(src, COMSIG_PHONE_SWITCHBOARD_UNREGISTER, PROC_REF(unregisterPhone))
		//RegisterSignal(src, , PROC_REF())
		//RegisterSignal(src, , PROC_REF())

	/// Called to request a register with a new phone
	proc/tryRegister(src, var/datum/target, var/target_id)
		if(target in registered_phones)
			SEND_SIGNAL(target, COMSIG_PHONE_SWITCHBOARD_REGISTER_FAILED, src) // should we tell the requester what something went wrong, like if we're already registered?
			// not a rhetorical question, review please
		registerPhoneSignals(target)
		registered_phones += target
		SEND_SIGNAL(target, COMSIG_PHONE_SWITCHBOARD_REGISTER_SUCCESSFUL, switchboard = src)

	/// Called to unregister a phone
	proc/unregisterPhone(src, var/datum/target)
		registered_phones.Remove(target)
		unregisterPhoneSignals(target)

	proc/registerPhoneSignals(var/datum/target)
		RegisterSignal(target, COMSIG_PHONE_CALL_REQUEST_OUT, PROC_REF(relayCallRequest))
		RegisterSignal(target, COMSIG_PHONE_CALL_DENY_REQUEST, PROC_REF(callRequestClosed))
		RegisterSignal(target, COMSIG_PHONE_CALL_ACCEPT_REQUEST, PROC_REF(callRequestAccepted))
		RegisterSignal(target, COMSIG_PHONE_CALL_HANGUP, PROC_REF(hangUp))
		RegisterSignal(target, COMSIG_PHONE_SPEECH_OUT, PROC_REF(relaySpeech))
		RegisterSignal(target, COMSIG_PHONE_VAPE_OUT, PROC_REF(relayVape))
		RegisterSignal(target, COMSIG_PHONE_VOLTRON_OUT, PROC_REF(relayVoltron))

	proc/unregisterPhoneSignals(var/datum/target)
		UnregisterSignal(target, COMSIG_PHONE_CALL_REQUEST_OUT)
		UnregisterSignal(target, COMSIG_PHONE_CALL_DENY_REQUEST)
		UnregisterSignal(target, COMSIG_PHONE_CALL_ACCEPT_REQUEST)
		UnregisterSignal(target, COMSIG_PHONE_CALL_HANGUP)
		UnregisterSignal(target, COMSIG_PHONE_SPEECH_OUT)
		UnregisterSignal(target, COMSIG_PHONE_VAPE_OUT)
		UnregisterSignal(target, COMSIG_PHONE_VOLTRON_OUT)

	proc/relayCallRequest(datum/caller, target_id)
		var/datum/target = phone_numbers[target_id]
		if(!target)
			SEND_SIGNAL(caller, COMSIG_PHONE_CALL_REQUEST_CLOSED)
			return
		var/caller_id = phone_numbers_inv[caller]
		// we send the caller ID since that's basically a phone number
		// todo: refine further before PR but for now it's fine
		if(!SEND_SIGNAL(target, COMSIG_PHONE_CALL_REQUEST_IN, caller_id))
			SEND_SIGNAL(caller, COMSIG_PHONE_CALL_REQUEST_CLOSED)
			return
		linkPhones(caller, target)

	proc/callRequestClosed(datum/target)
		var/datum/caller = phone_links[target]
		terminateCall(caller, target)
		SEND_SIGNAL(caller, COMSIG_PHONE_CALL_REQUEST_CLOSED)

	proc/callRequestAccepted(datum/target)
		var/datum/caller = phone_links[target]
		SEND_SIGNAL(caller, COMSIG_PHONE_CALL_REQUEST_ACCEPTED, src)

	/// Links two phones together. Does NOT check for existing links.
	proc/linkPhones(caller, target)
		phone_links[caller] += target
		phone_links[target] += caller

	/// When one phone wants to hang up the call
	proc/hangUp(hangerUpper)
		var/datum/partner = phone_links[hangerUpper]
		terminateCall(hangerUpper, partner)

	/// Terminates a phone call between 2 specified phones
	proc/terminateCall(var/datum/phone_1, var/datum/phone_2)
		phone_links.Remove(phone_1)
		phone_links.Remove(phone_2)
		SEND_SIGNAL(phone_1, COMSIG_PHONE_CALL_ENDED, src)
		SEND_SIGNAL(phone_2, COMSIG_PHONE_CALL_ENDED, src)

	proc/relaySpeech(caller, said_message)
		var/datum/target = phone_links[caller]
		SEND_SIGNAL(target, COMSIG_PHONE_SPEECH_IN, said_message)

	proc/relayVape()

	proc/relayVoltron()
