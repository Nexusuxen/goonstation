/*
The switchboard here is meant to handle the bulk of the logic for handling phone connections
Ideally a phone should only be concerned with its own I/O, and rely almost entirely on signals
Multiple switchboards can coexist, though presently there's no way to communicate between them
 (AZone-specific phone networks are one application of this)
The code here is likely flawed, and it isn't 100% complete, but hopefully it's good enough to build new
 stuff off of with minimal need to modify existing code

IMPORTANT: "phone_id", "phone number", "phone_name", etc. all refer to the same thing: The unique identifier
 for each phone. In the future, this is intended to be split into unique phone numbers, and non-unique names

TODO (The initial PR is focused solely on a refactor, with minimal changes/features)
- Add actual phone numbers that function as the unique identifiers for phones
- Add a keypad to phone UI, so that there can be unlisted phones where you need to find the number
*/

// registered_phones key defines
#define REG_NUMBER 1
#define REG_NAME 2
#define REG_CATEGORY 3
#define REG_UNLISTED 4
#define REG_COLOR 5
#define REG_RINGING 6

/// Handles connections between phones
/datum/phone_switchboard
	/// List of all phones we have registered. Structure:
	/// phone = list(phone number, name, category, unlisted (bool), color (optional), ringing)
	var/list/registered_phones = list()
	/// Stores what phones are linked to a given phone, including pending and active calls
	/// Assoc list, caller = target. Target can be null if a phone has started trying to make a call, but hasn't dialed anyone yet
	var/phone_links[0]
	/// Data for the UI we distribute to every phone
	var/list/phonebook
	var/name = null

/datum/phone_switchboard/New(var/_name)
		. = ..()
		// Phones send more signals but we listen to their comp holders, so we register for them later
		RegisterSignal(src, COMSIG_PHONE_SWITCHBOARD_REGISTER, PROC_REF(tryRegister))
		RegisterSignal(src, COMSIG_PHONE_SWITCHBOARD_UNREGISTER, PROC_REF(unregisterPhone))
		name = _name
		global_switchboards[name] += src
		//RegisterSignal(src, , PROC_REF())
		//RegisterSignal(src, , PROC_REF())

/// Registers a provided phone with the provided info
/datum/phone_switchboard/proc/tryRegister(var/datum/phone_switchboard/us, var/datum/target, var/target_id, var/phone_name, var/category, var/unlisted = FALSE, var/color = "#b65f08")
	if(target in src.registered_phones)
		logTheThing(LOG_DEBUG, "[target] attempted to register with [src] while already registered!")
		return 1
	registerPhoneSignals(target)
	src.registered_phones += target
	src.registered_phones[target] = list(target_id, phone_name, category, unlisted, color, FALSE)
	SPAWN(0 SECONDS) // waiting a moment lets a phone that may have just spawned initialize its ui component
		updatePhonebooks() // otherwise it may be left with an empty phonebook
	return 1

/datum/phone_switchboard/proc/unregisterPhone(var/datum/phone_switchboard/us, var/datum/target)
	if(isnull(target))
		CRASH("phone_switchboard/proc/unregisterPhone() called with a null target!")
	closeConnection(target)
	src.registered_phones.Remove(target)
	unregisterPhoneSignals(target)
	updatePhonebooks()

/datum/phone_switchboard/proc/registerPhoneSignals(var/datum/target)
	RegisterSignal(target, COMSIG_PHONE_ATTEMPT_CONNECT, PROC_REF(attemptConnection))
	RegisterSignal(target, COMSIG_PHONE_HANGUP, PROC_REF(closeConnection))
	RegisterSignal(target, COMSIG_PHONE_PICKUP, PROC_REF(phonePickedUp))
	RegisterSignal(target, COMSIG_PHONE_SPEECH_OUT, PROC_REF(relaySpeech))
	RegisterSignal(target, COMSIG_PHONE_SOUND_OUT, PROC_REF(relaySound))
	RegisterSignal(target, COMSIG_PHONE_VAPE_OUT, PROC_REF(relayVape))
	RegisterSignal(target, COMSIG_PHONE_VOLTRON_OUT, PROC_REF(relayVoltron))
	RegisterSignal(target, COMSIG_PHONE_UPDATE_INFO, PROC_REF(update_info))

/datum/phone_switchboard/proc/unregisterPhoneSignals(var/datum/target)
	UnregisterSignal(target, COMSIG_PHONE_ATTEMPT_CONNECT)
	UnregisterSignal(target, COMSIG_PHONE_HANGUP)
	UnregisterSignal(target, COMSIG_PHONE_PICKUP)
	UnregisterSignal(target, COMSIG_PHONE_SPEECH_OUT)
	UnregisterSignal(target, COMSIG_PHONE_SOUND_OUT)
	UnregisterSignal(target, COMSIG_PHONE_VAPE_OUT)
	UnregisterSignal(target, COMSIG_PHONE_VOLTRON_OUT)
	UnregisterSignal(target, COMSIG_PHONE_UPDATE_INFO)

/// Returns target datum from target_id if target is valid, returns null otherwise
/// Target is valid if they are registered properly and also open to calls
/datum/phone_switchboard/proc/checkAvailableAndReturnTarget(var/target_id)
	var/datum/target
	if(target_id in phone_numbers)
		target = phone_numbers[target_id]
	if((target in src.registered_phones) && !(target in phone_links))
		return target
	// if we're not in phone_links and we are registered, we MUST be available

/datum/phone_switchboard/proc/attemptConnection(datum/phone_caller, target_id)
	if(!(phone_caller in src.registered_phones))
		CRASH("Unregistered caller [phone_caller] attempted to start calling [target_id] through [src]!")
	if(phone_caller in phone_links)
		if(!isnull(phone_links[phone_caller]))
			logTheThing(LOG_DEBUG, src, "[phone_caller] somehow attempted to call someone else while already in a call.")
			return // could probably add support for 3+ party calls but for now, no thank you
	else
		CRASH("[phone_caller] somehow tried starting a call when not properly in phone_links in [src]!")
		// Phones MUST send a pickup signal *before* an attempt_connection signal

	var/datum/target = checkAvailableAndReturnTarget(target_id)
	if(!target || (phone_caller == target))
		SEND_SIGNAL(phone_caller, COMSIG_PHONE_SOUND_IN, 'sound/machines/phones/phone_busy.ogg')
		return //todo: add special case for trying to call self
		// and also make calling self via phonebook impossible, ideally

	var/caller_id = src.registered_phones[phone_caller][REG_NUMBER]
	var/caller_name = src.registered_phones[phone_caller][REG_NAME]
	var/caller_color = src.registered_phones[phone_caller][REG_COLOR]
	// adding more stuff to this list as needed shouldn't break anything
	var/caller_info = list(caller_id, caller_name, caller_color)

	linkPhones(phone_caller, target)
	SEND_SIGNAL(target, COMSIG_PHONE_INBOUND_CONNECTION, caller_info)
	start_ring(target)
	start_ring(phone_caller)
	return

/datum/phone_switchboard/proc/start_ring(var/datum/target)
	SEND_SIGNAL(target, COMSIG_PHONE_START_RING)
	src.registered_phones[target][REG_RINGING] = TRUE

/datum/phone_switchboard/proc/stop_ring(var/datum/target)
	SEND_SIGNAL(target, COMSIG_PHONE_STOP_RING)
	src.registered_phones[target][REG_RINGING] = FALSE

/// Terminates a connection, ending an ongoing or pending call/session
/datum/phone_switchboard/proc/closeConnection(datum/closer)
	if(!(closer in phone_links))
		return

	var/datum/other_party = phone_links[closer]
	phone_links.Remove(closer)
	if(isnull(other_party))
		return

	phone_links.Remove(closer)
	phone_links[other_party] = null
	// so the other line is still seen as 'busy' until they also hang up

	stop_ring(closer)
	stop_ring(other_party)

/datum/phone_switchboard/proc/phonePickedUp(datum/pickerUpper)
	if(!(pickerUpper in phone_links))
		phone_links[pickerUpper] = null // Starting a session, we're now busy!
		return
	if(isnull(phone_links[pickerUpper]))
		CRASH("Duplicate COMSIG_PHONE_PICKUP signal sent by [pickerUpper] and received by [src]! Did we forget a COMSIG_PHONE_HANGUP?")
	var/datum/phone_caller = phone_links[pickerUpper]
	stop_ring(pickerUpper)
	stop_ring(phone_caller)

/// Links two phones together. Does NOT check for existing links.
/datum/phone_switchboard/proc/linkPhones(phone_caller, target)
	phone_links[phone_caller] += target
	phone_links[target] += phone_caller

/datum/phone_switchboard/proc/relaySpeech(var/datum/phone_caller, message)
	var/datum/target = phone_links[phone_caller]
	if(isnull(target))
		return
	if(src.registered_phones[target][REG_RINGING])
		return
	SEND_SIGNAL(phone_caller, COMSIG_PHONE_SPEECH_IN, message)
	// we send it back to them to maintain feature parity with the pre-refactor version
	// since you previously would hear yourself speaking when the other phone has been answered
	SEND_SIGNAL(target, COMSIG_PHONE_SPEECH_IN, message)

/datum/phone_switchboard/proc/relaySound(phone_caller, sound, var/vol = 30)
	var/datum/target = phone_links[phone_caller]
	if(isnull(target))
		return
	if(src.registered_phones[target][REG_RINGING])
		return
	SEND_SIGNAL(target, COMSIG_PHONE_SOUND_IN, sound, vol)

/datum/phone_switchboard/proc/relayVape(phone_caller, vape)
	var/datum/target = phone_links[phone_caller]
	if(isnull(target))
		return
	if(src.registered_phones[target][REG_RINGING])
		return
	SEND_SIGNAL(target, COMSIG_PHONE_VAPE_IN, vape)

/datum/phone_switchboard/proc/relayVoltron(phone_caller, voltron)
	var/datum/target = phone_links[phone_caller]
	if(isnull(target))
		return
	if(src.registered_phones[target][REG_RINGING])
		return
	SEND_SIGNAL(target, COMSIG_PHONE_VOLTRON_IN, voltron)

/datum/phone_switchboard/proc/update_info(signal_parent, new_name, new_category, new_unlisted, new_color)
	var/ringing = src.registered_phones[signal_parent][REG_RINGING]

	var/new_info = list(new_name, new_name, new_category, new_unlisted, new_color, ringing)
	src.registered_phones[signal_parent] = new_info

	updatePhonebooks()

/datum/phone_switchboard/proc/generatePhonebookEntry(var/datum/target)
	var/phone_name = src.registered_phones[target][REG_NAME]
	var/phone_category = src.registered_phones[target][REG_CATEGORY]
	var/unlisted = src.registered_phones[target][REG_UNLISTED]
/*
	/// Creates a new phonebook entry from scratch
	proc/regeneratePhonebook()
		var/list/new_phonebook
		for(var/P in src.registered_phones)
			var/match_found = FALSE
			//var/number = src.registered_phones[P][1]
			var/phone_name = src.registered_phones[P][REG_NAME]
			var/phone_category = src.registered_phones[P][REG_CATEGORY]
			var/unlisted = src.registered_phones[P][REG_UNLISTED]
			if (unlisted)
				continue
			if (length(new_phonebook))
				for (var/i in 1 to length(new_phonebook))
					if (new_phonebook[i]["category"] == phone_category)
						match_found = TRUE
						new_phonebook[i]["phones"] += list(list(
							"id" = phone_name
						))
						break
			if (!match_found)
				new_phonebook += list(list(
					"category" = phone_category,
					"phones" = list(list(
						"id" = phone_name
					))
				))
list(list("category" = CATEGORY, "phones" = list(list("id" = PHONE_ID))))
		phonebook = new_phonebook

PHONEBOOK STRUCTURE (if you're like me and find it impossible to parse the code here)

phonebook[
	cat_list1(
		"category" = CATEGORY1,
		"phones" = phone_list(
			"id" = "name1",
			"id" = "name2",
			"id" = "name3"
			)
		),
	cat_list2(
		"category" = CATEGORY2,
		"phones" = phone_list(
			"id" = "name1",
			"id" = "name2",
			"id" = "name3"
			)
		),
	cat_list3(
		"category" = CATEGORY3,
		"phones" = phone_list(
			"id" = "name1",
			"id" = "name2",
			"id" = "name3"
			)
		),
]
*/
//note: this way of doing things seems a little performance intensive (especially if someone spams wirecutters)
// but i can't for the life of me wrap my head around JSX right now. so, we're sticking with this.
/// Updates connected phones' phonebooks with a format compatible with standard phone ui
/datum/phone_switchboard/proc/updatePhonebooks()
	var/list/new_phonebook
	for(var/P in src.registered_phones)
		var/match_found = FALSE
		var/unlisted = src.registered_phones[P][REG_UNLISTED]
		if (unlisted)
			continue
		var/number = src.registered_phones[P][REG_NUMBER]
		var/phone_name = src.registered_phones[P][REG_NAME]
		var/phone_category = src.registered_phones[P][REG_CATEGORY]
		if (length(new_phonebook))
			for (var/i in 1 to length(new_phonebook))
				if (new_phonebook[i]["category"] == phone_category)
					match_found = TRUE
					new_phonebook[i]["phones"] += list(list(
						"id" = number,
						"name" = phone_name
					))
					break
		if (!match_found)
			new_phonebook += list(list(
				"category" = phone_category,
				"phones" = list(list(
					"id" = number,
					"name" = phone_name
				))
			))
	for(var/datum/P in src.registered_phones)
		SEND_SIGNAL(P, COMSIG_PHONE_BOOK_DATA, new_phonebook)
