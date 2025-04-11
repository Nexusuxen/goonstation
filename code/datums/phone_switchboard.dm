/*
nex notes:
Phone components should largely not interact with the switchboard directly, and just do signals
It could probably work if we sent signals to the switchboard directly but that seems messier
and also laggier, and less flexible (what if we want things to tap into phones?)
*/

#define FAIL 0
#define SUCCESS 1

/// Handles connections between phones
/datum/phone_switchboard

	// We mess around with IDs to make it easier to transition to proper phone numbers in the future
	// Is this necessary? No, just referring to phone comp parents would be easier and cleaner.
	// But it sure is neat. And having unlisted phone numbers for espionage and
	// secret content are actual possible use cases, so fuck it, why not.
	// However, we should stick to referring to the component parents when possible for cleanliness.

	/// List of all phones we have registered. Structure:
	/// phone = list(phone number, name, category, hidden (bool))
	var/list/registered_phones = list()
	/// Stores what phones are linked to a given phone, including pending and active calls
	var/phone_links[0]
	var/name = null

	New(var/_name)
		. = ..()
		// Phones send more signals but we listen to their comp holders, so we register for them later
		RegisterSignal(src, COMSIG_PHONE_SWITCHBOARD_REGISTER, PROC_REF(tryRegister))
		RegisterSignal(src, COMSIG_PHONE_SWITCHBOARD_UNREGISTER, PROC_REF(unregisterPhone))
		name = _name
		global_switchboards[name] += src
		//RegisterSignal(src, , PROC_REF())
		//RegisterSignal(src, , PROC_REF())

	/// Registers a provided phone with the provided info
	proc/tryRegister(src, var/datum/target, var/target_id, var/phone_name, var/category, var/hidden = FALSE)
		if(target in registered_phones)
			. |= PHONE_SUCCESS
			. |= PHONE_ALREADY_CONNECTED
			return
		registerPhoneSignals(target)
		registered_phones += target
		registered_phones[target] = list(target_id, phone_name, category, hidden)
		SPAWN(0 SECONDS) // waiting a moment lets a phone that may have just spawned initialize its ui component
			updatePhonebooks() // otherwise it may be left with an empty phonebook
		return PHONE_SUCCESS

	proc/unregisterPhone(src, var/datum/target)
		closeConnection(target)
		registered_phones.Remove(target)
		unregisterPhoneSignals(target)
		updatePhonebooks()

	proc/registerPhoneSignals(var/datum/target)
		RegisterSignal(target, COMSIG_PHONE_ATTEMPT_CONNECT, PROC_REF(relayConnectAttempt))
		RegisterSignal(target, COMSIG_PHONE_HANGUP, PROC_REF(closeConnection))
		RegisterSignal(target, COMSIG_PHONE_PICKUP, PROC_REF(callPickedUp))
		RegisterSignal(target, COMSIG_PHONE_SPEECH_OUT, PROC_REF(relaySpeech))
		RegisterSignal(target, COMSIG_PHONE_VAPE_OUT, PROC_REF(relayVape))
		RegisterSignal(target, COMSIG_PHONE_VOLTRON_OUT, PROC_REF(relayVoltron))
		RegisterSignal(target, COMSIG_PHONE_UPDATE_INFO, PROC_REF(update_info))

	proc/unregisterPhoneSignals(var/datum/target)
		UnregisterSignal(target, COMSIG_PHONE_ATTEMPT_CONNECT)
		UnregisterSignal(target, COMSIG_PHONE_HANGUP)
		UnregisterSignal(target, COMSIG_PHONE_PICKUP)
		UnregisterSignal(target, COMSIG_PHONE_SPEECH_OUT)
		UnregisterSignal(target, COMSIG_PHONE_VAPE_OUT)
		UnregisterSignal(target, COMSIG_PHONE_VOLTRON_OUT)
		UnregisterSignal(target, COMSIG_PHONE_UPDATE_INFO)

	proc/relayConnectAttempt(datum/caller, target_id)
		if(!(caller in registered_phones))
			logTheThing(LOG_DEBUG, src, "Unregistered caller [caller] attempted to make a connection through [src]!")
			return
		if((caller in phone_links))
			return FAIL // could probably add support for 3+ party calls but for now, no thank you
		var/datum/target = phone_numbers[target_id]
		if(!target || (caller == target) || !(target in registered_phones))
			return FAIL //todo: add special case for trying to call self
			// and also make calling self via phonebook impossible, ideally
		var/caller_id = registered_phones[caller][1]
		var/caller_name = registered_phones[caller][2]
		// adding more stuff to this list as needed shouldn't break anything
		var/caller_info = list(caller_id, caller_name)
		if(!SEND_SIGNAL(target, COMSIG_PHONE_INBOUND_CONNECTION_ATTEMPT, caller_info))
			return FAIL
		linkPhones(caller, target)
		return SUCCESS

	proc/closeConnection(datum/closer)
		if(!(closer in phone_links))
			return
		var/datum/other_party = phone_links[closer]
		terminateCall(other_party, closer)

	proc/callPickedUp(datum/pickerUpper)
		if(!pickerUpper)
			logTheThing(LOG_DEBUG, src, "COMSIG_PHONE_PICKUP received with a null sender")
			return
		if(!(pickerUpper in phone_links))
			return
		var/datum/caller = phone_links[pickerUpper]
		return SEND_SIGNAL(caller, COMSIG_PHONE_CALL_REQUEST_ACCEPTED, src)

	/// Links two phones together. Does NOT check for existing links.
	proc/linkPhones(caller, target)
		phone_links[caller] += target
		phone_links[target] += caller

	/// Terminates a phone call between 2 specified phones
	proc/terminateCall(var/datum/phone_1, var/datum/phone_2)
		phone_links.Remove(phone_1)
		phone_links.Remove(phone_2)
		SEND_SIGNAL(phone_1, COMSIG_PHONE_CONNECTION_CLOSED, src)
		SEND_SIGNAL(phone_2, COMSIG_PHONE_CONNECTION_CLOSED, src)

	proc/relaySpeech(caller, message)
		var/datum/target = phone_links[caller]
		return SEND_SIGNAL(target, COMSIG_PHONE_SPEECH_IN, message)

	proc/relayVape(caller, vape)
		var/datum/target = phone_links[caller]
		if(target)
			SEND_SIGNAL(target, COMSIG_PHONE_VAPE_IN, vape)

	proc/relayVoltron(caller, voltron)
		var/datum/target = phone_links[caller]
		if(target)
			return SEND_SIGNAL(target, COMSIG_PHONE_VOLTRON_IN, voltron)

	proc/update_info(signal_parent, new_name, new_category, new_hidden)
		var/phone_number = registered_phones[signal_parent][1]
		var/new_info = list(phone_number, new_name, new_category, new_hidden)
		registered_phones[signal_parent] = new_info
		//todo check if Hidden changed, and if so, update phonebook
		updatePhonebooks()

// todo: make the UI show name *and* phone number
// This may be a little performance intensive at roundstart due to how many phones are spawning, so maybe
// figure out a way to prevent this from proc'ing during preround, and force it to proc at roundstart?
	/// Updates connected phones' phonebooks with a format compatible with standard phone ui
	proc/updatePhonebooks()
		var/list/new_phonebook
		for(var/P in registered_phones)
			var/match_found = FALSE
			var/number = registered_phones[P][1]
			var/phone_name = registered_phones[P][2]
			var/phone_category = registered_phones[P][3]
			var/hidden = registered_phones[P][4]
			if (hidden)
				continue
			if (length(new_phonebook))
				for (var/i in 1 to length(new_phonebook))
					if (new_phonebook[i]["category"] == phone_category)
						match_found = TRUE
						new_phonebook[i]["phones"] += list(list(
							"id" = number
						))
						break
			if (!match_found)
				new_phonebook += list(list(
					"category" = phone_category,
					"phones" = list(list(
						"id" = number
					))
				))
		for(var/datum/P in registered_phones)
			SEND_SIGNAL(P, COMSIG_PHONE_BOOK_DATA, new_phonebook)

#undef FAIL
#undef SUCCESS
