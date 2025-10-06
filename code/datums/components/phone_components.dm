/* orted notes:
- All kinds of data should be immune to a null response. If blocked, then nothing happens.
- When starting a call, listen for COMSIGs from the recipient
  phone_packets should be transmitted this way rather than broadcasted to all phones
- Networks! Phones only see what's on their network. For now just have the "NT13 Network".
 - Maybe later on we can get switchboards or magic phones that allow seeing other networks

PHONES SHOULD NOT GIVE A DAMN ABOUT HEARING ANYTHING THAT A SPEAKER CANNOT PICK UP
the switchboard should handle all of the call logic, the phones themselves just send/receive signals
*/

/// Stores all addresss as address = parent
var/global/list/phone_numbers = list()
/// Stores all phoneids as parent = address
var/global/list/phone_numbers_inv = list()

// kinda meh approach but
proc/generate_phone_name()

/// Handles interfacing with a switchboard and the rest of the phone
/datum/component/phone_networker

	/// Our unique identifier. Currently this is just a unique name.
	/// In the future proper phone numbers should be the unique identifier we use
	var/address = null
	/// Our display name in UIs. Currently indistinguishable from address
	var/phone_name = null
	/// Our category in the phonebook
	var/address_category = null
	/// Determines if we should show up in phonebooks
	var/unlisted = FALSE
	var/color = "#b65f08"
	/// Keeps track of the switchboard we're registered to, if any
	/// Still try to use signals when possible, in case we're meant to not have a switchboard
	var/datum/phone_switchboard/our_switchboard = null
	// Maybe we could have multiple switchboards in the future, but for now it's just the one
	/// Our local copy of the phonebook
	var/list/phonebook = null
	/// A list of information on whoever's calling us
	/// list(phone number, name)
	var/list/current_caller_info
	/// Are we currently in an active call?
	var/pending_call = FALSE //todo: REMOVE?

	/// Bitfield. Stores various conditions about the overall status of the phone.
	var/status = 0

	var/datum/our_ui
	var/datum/our_mic
	var/datum/our_speaker
	var/datum/our_ringer

	/// Leave switchboard_name null to not immediately try to connect to a switchboard
	Initialize(var/_phone_name, var/_address_category, var/switchboard_name = null, var/desired_phone_number = null, var/do_unlisted = FALSE, var/desired_color = "#b65f08")
		. = ..()
		RegisterSignal(parent, COMSIG_PHONE_SWITCHBOARD_REGISTER, PROC_REF(try_register_switchboard))
		RegisterSignal(parent, COMSIG_PHONE_SWITCHBOARD_UNREGISTER, PROC_REF(unregister_switchboard))
		RegisterSignal(parent, COMSIG_PHONE_BOOK_DATA, PROC_REF(update_phonebook))
		RegisterSignal(parent, COMSIG_PHONE_INBOUND_CONNECTION, PROC_REF(inbound_connection))
		RegisterSignal(parent, COMSIG_PHONE_UPDATE_INFO, PROC_REF(update_info))
		if(isnull(_phone_name)) // remove when phone numbers are added
			CRASH("Tried to generate a phone without a name from [parent]!")
		address = _phone_name // replace with actual phone numbers sometime
		// They should probably in the format of 131234, with the first 2 digits denoting some kind of group
		// Rendered as 13-1234 or (13) 1234 or whatever
		// This would be in-line with the 7 beeps you hear when dialing a number (6 digits, 1 to enter)
		// and looks kinda nice. We probably wouldn't need more than 9999 phone numbers anyways, god willing.
		phone_name = _phone_name
		// todo: make it impossible to have duplicate names
		address_category = _address_category
		unlisted = do_unlisted
		color = desired_color
		add_phone_to_global_list()
		try_register_switchboard(src, switchboard_name)

	disposing()
		unregister_switchboard(src)
		remove_phone_from_global_list()
		. = ..()

	proc/add_phone_to_global_list()
		phone_numbers[address] = parent
		phone_numbers_inv[parent] = address

	proc/remove_phone_from_global_list()
		phone_numbers.Remove(address)
		phone_numbers_inv.Remove(parent)

	proc/try_register_switchboard(var/signal_parent, switchboard_name)
		if(!switchboard_name)
			return
		var/sb = global_switchboards.Find(switchboard_name)
		var/datum/phone_switchboard/switchboard
		if(sb)
			switchboard = global_switchboards[global_switchboards[sb]]
		else
			switchboard = new(switchboard_name)
		if(SEND_SIGNAL(switchboard, COMSIG_PHONE_SWITCHBOARD_REGISTER, parent, address, phone_name, address_category, unlisted, color))
			our_switchboard = switchboard
		else
			// This runtime call should be removed when a phone is added that's meant to not have a switchboard
			// For now it may be helpful in diagnosing bugs, since phones should ALWAYS succeed in registering,
			// at least for now
			CRASH("[src], belonging to [src.parent], attempted to register to switchboard [switchboard] and failed!")

	proc/unregister_switchboard()
		if(!isnull(our_switchboard))
			SEND_SIGNAL(our_switchboard, COMSIG_PHONE_SWITCHBOARD_UNREGISTER, parent)

	// we might not need this, just the UI component
	proc/update_phonebook()

	/// Handles inbound call requests
	proc/inbound_connection(var/signal_parent, caller_info)
		current_caller_info = caller_info
		pending_call = TRUE

	proc/update_info(signal_parent, new_name, new_category, new_unlisted)
		phone_name = new_name
		address_category = new_category
		unlisted = new_unlisted

/// Handles UI actions for phones. Displaying TGUI to a client, relaying input to the networker, etc.
/// May have a different parent than its networker
/datum/component/phone_ui

	/// The parent holder containing our networker
	var/datum/networker_parent
	/// Our list of phones we can see in the UI
	var/list/phonebook
	var/our_name
	/// The name of the last phone we tried to dial
	var/last_called = "None"
	/// If we're in the middle of dialing
	var/dialing = FALSE

	var/ringing = FALSE

	Initialize(var/datum/net_parent, var/to_name = "placeholder name")
		. = ..()
		networker_parent = net_parent
		our_name = to_name

		RegisterSignal(networker_parent, COMSIG_PHONE_UI_INTERACT, PROC_REF(phone_ui_interact))
		RegisterSignal(networker_parent, COMSIG_PHONE_UI_CLOSE, PROC_REF(phone_ui_close))
		RegisterSignal(networker_parent, COMSIG_PHONE_BOOK_DATA, PROC_REF(update_phonebook))
		RegisterSignal(networker_parent, COMSIG_PHONE_HANGUP, PROC_REF(hangup))
		RegisterSignal(networker_parent, COMSIG_PHONE_START_RING, PROC_REF(start_ring))
		RegisterSignal(networker_parent, COMSIG_PHONE_STOP_RING, PROC_REF(stop_ring))

	proc/update_phonebook(var/signal_parent, var/list/new_phonebook, var/append = FALSE)
		//todo: if append, just stick it to the end of our existing phonebook
		//good for if someone wants to make themselves visible to just us
		phonebook = new_phonebook

	proc/phone_ui_interact(var/signal_parent, var/mob/user, var/force_ui = FALSE)
		// todo: if force_ui false, check if we're ringing or something
		ui_interact(user)

	proc/phone_ui_close()
		tgui_process.close_uis(src)

	proc/hangup()
		dialing = FALSE

	proc/start_ring()
		ringing = TRUE

	proc/stop_ring()
		ringing = FALSE

	ui_interact(mob/user, datum/tgui/ui)
		ui = tgui_process.try_update_ui(user, src, ui)
		if(!ui)
			ui = new(user, src, "Phone")
			ui.open()

	ui_data(mob/user)
		. = list(
			"dialing" = FALSE,
			"inCall" = null,
			"lastCalled" = last_called,
			"name" = our_name
		)

		.["phonebook"] = phonebook

	ui_act(action, params)
		. = ..()
		if (.)
			return
		switch (action)
			if ("call")
				. = TRUE
				var/id = params["target"]
				call_target(id)

	proc/call_target(target)
		if(dialing || ringing)
			return
		SEND_SIGNAL(networker_parent, COMSIG_PHONE_SOUND_IN, 'sound/machines/phones/dial.ogg')
		dialing = TRUE
		SPAWN(4 SECONDS)
			if(!dialing) // we've been interrupted!
				return
			dialing = FALSE
			last_called = target
			SEND_SIGNAL(networker_parent, COMSIG_PHONE_ATTEMPT_CONNECT, target)

/// Hears anything spoken into its owner and sends to networker.
/// May have a different owner than its networker
/// MUST be on an atom
/datum/component/phone_microphone

	/// The parent holder containing our networker
	var/datum/networker_parent
	/// Are we able to transmit voltron-wielding nerds?
	var/voltronnable
	/// Can we send sick vapes through the wires?
	var/vapeable

	Initialize(var/net_parent, var/do_voltron = TRUE, var/do_vape = TRUE)
		. = ..()
		if(!istype(parent, /atom))
			return COMPONENT_INCOMPATIBLE
		networker_parent = net_parent
		voltronnable = do_voltron
		vapeable = do_vape
		RegisterSignal(parent, COMSIG_PHONE_ATTEMPT_VOLTRON, PROC_REF(attempt_voltron))
		RegisterSignal(parent, COMSIG_PHONE_ATTEMPT_VAPE, PROC_REF(attempt_vape))

	proc/transmit_speech(var/list/said_message)
		SEND_SIGNAL(networker_parent, COMSIG_PHONE_SPEECH_OUT, said_message)

	proc/attempt_vape(var/signal_parent, var/vape)
		if(vapeable)
			SEND_SIGNAL(networker_parent, COMSIG_PHONE_VAPE_OUT, vape)

	proc/attempt_voltron(var/signal_parent, var/voltron)
		if(voltronnable)
			return SEND_SIGNAL(networker_parent, COMSIG_PHONE_VOLTRON_OUT, voltron)

	/*proc/get_parent()
		RETURN_TYPE(/mob)
		if(ismob(parent.loc))
			. = src.loc*/


/// Handles the output from a phone. Speech, vapes, outgoing rings, voltrons, etc.
/// May have a different owner than its networker
/// MUST be in an atom. Make a new component if your speaker isn't one.
/datum/component/phone_speaker_atom

	/// The parent holder containing our networker
	var/datum/networker_parent = null
	/// Can a voltron user travel to us?
	var/voltronnable
	/// Can a nerd blow their vape to us?
	var/vapeable

	var/ringing = FALSE

	Initialize(var/net_parent, var/do_voltron = TRUE, var/do_vape = TRUE)
		. = ..()
		if(!istype(parent, /atom))
			return COMPONENT_INCOMPATIBLE
		networker_parent = net_parent
		voltronnable = do_voltron
		vapeable = do_vape
		RegisterSignal(networker_parent, COMSIG_PHONE_SPEECH_IN, PROC_REF(receive_speech))
		RegisterSignal(networker_parent, COMSIG_PHONE_VAPE_IN, PROC_REF(receive_vape))
		RegisterSignal(networker_parent, COMSIG_PHONE_VOLTRON_IN, PROC_REF(receive_voltron))
		RegisterSignal(networker_parent, COMSIG_PHONE_SOUND_IN, PROC_REF(receive_sound))

		RegisterSignal(networker_parent, COMSIG_PHONE_START_RING, PROC_REF(start_ring))
		RegisterSignal(networker_parent, COMSIG_PHONE_STOP_RING, PROC_REF(stop_ring))

	proc/start_ring()
		ringing = TRUE

	proc/stop_ring()
		ringing = FALSE

	proc/get_user()
		var/atom/P = parent
		if(istype(P.loc, /mob))
			return P.loc

	proc/receive_speech(var/signal_parent, var/datum/say_message/message)
		if(!istype(message, /datum/say_message))
			CRASH("[src].receive_speech() (Parent: [parent]) received [message], expected type /datum/say_message!")
		if(ringing)
			return
		var/atom/P = parent
		message = message.Copy()
		message.speaker = P
		message.message_origin = P
		P.ensure_speech_tree().process(message)

	proc/receive_vape(var/signal_parent, var/obj/item/reagent_containers/vape/vape)
		if(!vapeable)
			return
		var/user = get_user()
		if(user)
			vape.phone_target_holder = user
		vape.phone_target = parent

	proc/receive_voltron(var/signal_parent, var/obj/item/device/voltron/voltron)
		if(!voltronnable)
			return
		if(!isatom(parent))
			return
		var/atom/A = parent
		var/turf/destination = get_turf(A)
		if(isrestrictedz(destination.z)) //REVIEW: is this sufficient or should there be more restrictions?
			return
		voltron.target_atom = parent
		return

	proc/receive_sound(var/signal_parent, var/sound_to_play, var/vol = 30)
		var/mob/user = get_user()
		if(user)
			user.playsound_local(user, sound_to_play, vol, 0)


/// Handles animations and noises for inbound ringing
/// Optional, and can have a different parent from its networker
/// Set speaker_ring_sound and/or parent_ring_sound to FALSE to disable that form of ringing
/// or instead set a specific sound to play instead of the default
/datum/component/phone_ringer_atom

	/// The parent holder containing our networker
	var/datum/networker_parent
	/// Info on whoever's trying to call us
	var/list/current_caller_info

	var/datum/controller/process/phone_ringing/ring_process = null
	var/announce_incoming
	var/speaker_ring_sound = null
	var/parent_ring_sound = null
	var/wait2ring = FALSE


// Review: I dislike this method of changing parent appearance. Is there a way you, reviewer, would recommend?
// (just feels like a good deal of boilerplate, but maybe I'm overreacting)
	Initialize(
	var/datum/net_parent,
	var/_announce_incoming = TRUE,
	var/_speaker_ring_sound = PHONE_DEFAULT_RING_SPEAKER,
	var/_parent_ring_sound = PHONE_DEFAULT_RING_EXTERNAL)
		. = ..()
		networker_parent = net_parent
		announce_incoming = _announce_incoming
		speaker_ring_sound = _speaker_ring_sound
		parent_ring_sound = _parent_ring_sound
		RegisterSignal(parent, COMSIG_PHONE_INBOUND_CONNECTION, PROC_REF(inbound_connection))
		RegisterSignal(networker_parent, COMSIG_PHONE_START_RING, PROC_REF(start_ring))
		RegisterSignal(networker_parent, COMSIG_PHONE_STOP_RING, PROC_REF(stop_ring))

	proc/inbound_connection(var/signal_parent, var/caller_info)
		current_caller_info = caller_info

	proc/start_ring()
		if(processScheduler)
			for(var/datum/controller/process/phone_ringing/P in processScheduler.processes)
				ring_process = P
				break
		// we do this to give the switchboard a moment to fully register us as in a call
		// otherwise, the mic would hear the first ring message and the switchboard would just send it to our partner
		SPAWN(0 SECONDS)
			do_ring()
			wait2ring = TRUE
		RegisterSignal(ring_process, COMSIG_PHONE_RINGER_PROCESS_TICK, PROC_REF(do_ring))
		// so we can immediately ring without risking rings overlapping
		SPAWN(4 SECONDS)
			wait2ring = FALSE

	proc/stop_ring()
		UnregisterSignal(ring_process, COMSIG_PHONE_RINGER_PROCESS_TICK)
		current_caller_info = null

	proc/do_ring()
		if(wait2ring) return
		if(speaker_ring_sound && isnull(current_caller_info))
			SEND_SIGNAL(networker_parent, COMSIG_PHONE_SOUND_IN, PHONE_DEFAULT_RING_SPEAKER)
		else if(istype(parent, /atom) && !isnull(current_caller_info))
			var/atom/P = parent
			if(parent_ring_sound)
				playsound(P, parent_ring_sound, 40, 0)
			if(announce_incoming)
				var/name2announce = current_caller_info[2]
				var/color2announce = current_caller_info[3]
				P.say("Call from <span style=\"color: [color2announce];\">[name2announce]</span>", flags = SAYFLAG_IGNORE_HTML)
