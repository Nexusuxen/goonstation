/// Handles connections between phones
/datum/phone_switchboard

	/// Assoc list, stores registered phones as [phone_id = phone],
	/// where 'phone' is the datum holding the phone components
	var/list/registered_phones = list()
	/// Assoc list, stores what phone is linked to a given phone
	/// phone_id = (linked phone_id)
	var/list/phone_links = list()

	New()
		. = ..()
		// Phones send more signals but we listen to their comp holders, so we register for them later
		RegisterSignal(src, COMSIG_PHONE_SWITCHBOARD_REGISTER, PROC_REF(tryRegister))
		RegisterSignal(src, COMSIG_PHONE_SWITCHBOARD_UNREGISTER, PROC_REF(unregisterPhone))
		//RegisterSignal(src, , PROC_REF())
		//RegisterSignal(src, , PROC_REF())

	/// Called to request a register with a new phone
	/// Children should call this if they're not returning
	proc/tryRegister(var/target_id, var/datum/target)
		if(isRegistered(target_id))
			SEND_SIGNAL(target, COMSIG_PHONE_SWITCHBOARD_REGISTER_FAILED, src) // should we tell the requester what something went wrong, like if we're already registered?
			// not a rhetorical question, review please
		registered_phones[target_id] += target
		SEND_SIGNAL(target, COMSIG_PHONE_SWITCHBOARD_REGISTER_SUCCESSFUL, switchboard = src)

	/// Called to unregister a phone. Use either target or target_id
	proc/unregisterPhone(var/target_id, var/datum/target, var/responded = FALSE)
		if(!target_id)
			target_id = get_id_by_holder(target)
		if(!target)
			target = registered_phones[target_id]
		// there's gonna be odd behavior if we're already in a call, make sure to do something about that here
		registered_phones.Remove(target_id)
		if(!responded)
			SEND_SIGNAL(target, COMSIG_PHONE_SWITCHBOARD_UNREGISTER, target = src, responded = TRUE)

	/// Checks if a phone is registered. If provided both target and target_id it will just check target_id.
	/// Using target_id is probably a bit faster
	proc/isRegistered(var/target_id, var/datum/target)
		. = FALSE
		if(target_id)
			return (target_id in registered_phones ? TRUE : FALSE)
		return (get_id_by_holder(target) ? TRUE : FALSE)

	proc/get_id_by_holder(var/datum/target)
		for(var/id in registered_phones)
			if(registered_phones[id] == target)
				return id

	proc/relayCallRequest(caller_id, datum/caller, target_id, datum/phone_switchboard)
		var/datum/target = registered_phones[target_id]
		if(!target)
			SEND_SIGNAL(caller, COMSIG_PHONE_CALL_REQUEST_CLOSED, src, target_id)
			return
		SEND_SIGNAL(target, COMSIG_PHONE_CALL_REQUEST_IN, caller_id, caller, target_id, src)

	proc/callRequestDenied(datum/target, caller_id, datum/caller, target_id, datum/phone_switchboard)
		SEND_SIGNAL(caller, COMSIG_PHONE_CALL_REQUEST_CLOSED, src, target_id)

	proc/callRequestAccepted(datum/target, caller_id, datum/caller, target_id, datum/phone_switchboard)
		SEND_SIGNAL(caller, COMSIG_PHONE_CALL_REQUEST_ACCEPTED, src, target_id)
		linkPhones(caller_id, target_id)

	/// Links a phone ID to its partner's phone object and vice versa
	proc/linkPhones(caller_id, target_id)
		phone_links[caller_id] += registered_phones[target_id]
		phone_links[target_id] += registered_phones[caller_id]

	proc/hangUp(caller_id)
		var/datum/partner = phone_links[caller_id]
		var/partner_id = get_id_by_holder(partner)
		terminateCall(caller_id, partner_id)

	proc/terminateCall(caller_id, partner_id)
		phone_links.Remove(caller_id)
		phone_links.Remove(partner_id)
		var/datum/caller = src.registered_phones[caller_id]
		var/datum/partner = src.registered_phones[partner_id]
		SEND_SIGNAL(caller, COMSIG_PHONE_CALL_ENDED, src)
		SEND_SIGNAL(partner, COMSIG_PHONE_CALL_ENDED, src)
