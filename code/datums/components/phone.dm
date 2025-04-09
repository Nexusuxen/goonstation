/* orted notes:
- All kinds of data should be immune to a null response. If blocked, then nothing happens.
- When starting a call, listen for COMSIGs from the recipient
  phone_packets should be transmitted this way rather than broadcasted to all phones
- Networks! Phones only see what's on their network. For now just have the "NT13 Network".
 - Maybe later on we can get switchboards or magic phones that allow seeing other networks
*/

/// Stores all phone_ids as phone_id = parent
var/global/list/phone_numbers = list()
/// Stores all phoneids as parent = phone_id
var/global/list/phone_numbers_inv = list()

#define FAIL 0
#define SUCCESS 1

/// Handles interfacing with a switchboard and the rest of the phone
/datum/component/phone_networker

	/// Our unique identifier
	var/phone_id = null
	var/datum/phone_switchboard/our_switchboard = null
	/// Are we on the line and unable to accept inbound calls?
	var/busy = FALSE

	var/datum/our_ui
	var/datum/our_mic
	var/datum/our_speaker
	var/datum/our_ringer

	Initialize()
		. = ..()
		RegisterSignal(parent, COMSIG_PHONE_SWITCHBOARD_REGISTER_SUCCESSFUL, PROC_REF(register_success))
		RegisterSignal(parent, COMSIG_PHONE_SWITCHBOARD_REGISTER_FAILED, PROC_REF(register_failed))
		RegisterSignal(parent, COMSIG_PHONE_INBOUND_CONNECTION_ATTEMPT, PROC_REF(inbound_connection_attempt))
		RegisterSignal(parent, COMSIG_PHONE_CONNECTION_CLOSED, PROC_REF(connection_closed))
		RegisterSignal(parent, COMSIG_PHONE_CALL_REQUEST_ACCEPTED, PROC_REF(call_request_accepted))
		RegisterSignal(parent, COMSIG_PHONE_PICKUP, PROC_REF(picked_up))
		RegisterSignal(parent, COMSIG_PHONE_HANGUP, PROC_REF(hanged_up))
		//RegisterSignal()

		// THIS IS A HACKJOB FOR DEV PURPOSES
		// TODO: MAKE PROPER PHONE NUMBERS
		phone_id = num2text(rand(1, 10000))
		phone_numbers[phone_id] += parent
		phone_numbers_inv[parent] += phone_id
		try_register_switchboard(global.nt13_switchboard)


	proc/try_register_switchboard(datum/phone_switchboard/switchboard)
		SEND_SIGNAL(switchboard, COMSIG_PHONE_SWITCHBOARD_REGISTER, parent, phone_id)

	proc/register_success(var/signal_parent, datum/phone_switchboard/switchboard)
		our_switchboard = switchboard

	proc/register_failed(var/signal_parent)

	/// Handles inbound call requests
	proc/inbound_connection_attempt(var/signal_parent, caller_id)
		if(busy)
			return FAIL
		else
			SEND_SIGNAL(parent, COMSIG_PHONE_START_RING)
			return SUCCESS

	proc/connection_closed(var/signal_parent, datum/partner)
		SEND_SIGNAL(parent, COMSIG_PHONE_STOP_RING)
		// todo: relay CLICK sound to speaker

	proc/call_request_accepted(var/signal_parent, datum/partner)
		SEND_SIGNAL(parent, COMSIG_PHONE_STOP_RING)

	proc/picked_up()
		busy = TRUE
		SEND_SIGNAL(parent, COMSIG_PHONE_STOP_RING)
	proc/hanged_up()
		busy = FALSE

/// Handles UI actions for phones. Displaying TGUI to a client, relaying input to the networker, etc.
/// May have a different owner than its networker
/datum/component/phone_ui

	/// The parent holder containing our networker
	var/datum/networker_parent

	// todo remove before pr
	var/datum/component/phone_networker/our_net_comp

	/// what we should be called, i guess
	var/our_name

	Initialize(var/datum/net_parent, var/to_name = "placeholder name", var/net_component)
		. = ..()
		networker_parent = net_parent
		our_name = to_name
		our_net_comp = net_component

		RegisterSignal(networker_parent, COMSIG_PHONE_UI_INTERACT, PROC_REF(phone_ui_interact))

	proc/phone_ui_interact(var/signal_parent, var/mob/user, var/force_ui = FALSE)
		// todo: if force_ui false, check if we're ringing or something
		ui_interact(user)

	ui_interact(mob/user, datum/tgui/ui)
		ui = tgui_process.try_update_ui(user, src, ui)
		if(!ui)
			ui = new(user, src, "Phone")
			ui.open()

	ui_data(mob/user)
		var/list/list/list/phonebook = list()

		for(var/P in phone_numbers_inv)
			if(phone_numbers_inv[P] == our_net_comp.phone_id)
				continue
			var/match_found = FALSE
			if(length(phonebook))
				for(var/i in 1 to length(phonebook))
					if(phonebook[i]["category"] == "uncategorized")
						match_found = TRUE
						phonebook[i]["phones"] += list(list(
							"id" = phone_numbers_inv[P]
						))
						break
			if(!match_found)
				phonebook += list(list(
					"category" = "uncategorized",
					"phones" = list(list(
						"id" = phone_numbers_inv[P]
					))
				))

		. = list(
			"dialing" = FALSE,
			"inCall" = null,
			"lastCalled" = "lastCalled",
			"name" = "fart"
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
				if(SEND_SIGNAL(networker_parent, COMSIG_PHONE_ATTEMPT_CONNECT, id))
					SEND_SIGNAL(networker_parent, COMSIG_PHONE_START_RING)
					return
				boutput(usr, SPAN_ALERT("Unable to connect!"))
				// todo: dial-tone here!

/// Hears anything spoken into its owner and sends to networker.
/// May have a different owner than its networker
/datum/component/phone_microphone

	/// The parent holder containing our networker
	var/datum/networker_parent

	Initialize(var/net_parent)
		. = ..()
		networker_parent = net_parent
		RegisterSignal(parent, COMSIG_PHONE_SPOKEN_INTO, PROC_REF(talked_into))

	proc/talked_into(datum/microphone, mob/M as mob, text, secure, real_name, lang_id)
		/*if(GET_DIST(src, get_parent()) > 0) // Only the person holding the handset can talk into it
			return // (could be fun if you could overhear others through the phone though...)
		*/
		boutput(M, "your voice has been HEARD!")

		var/heard_name = M.get_heard_name(just_name_itself=TRUE)
		if(M.mind)
			heard_name = "<span class='name' data-ctx='\ref[M.mind]'>[heard_name]</span>"

		// we need a proper solution but for now i want things working
		//var/phone_ident = "\[ <span style=\"color:[src.parent.stripe_color]\">[bicon(src.handset_icon)] [src.parent.phone_id]</span> \]"
		// Currently it doesn't properly color the bicon. Since coloring the phone is unique to the landline phones,
		// maybe we should have a signal to ask it for an icon? Or find a way to get a properly colored icon
		// with something other than bicon
		var/phone_ident = "\[ <span style=\"color:red\">[bicon(microphone)] test ID</span> \]"
		var/said_message = SPAN_SAY("[SPAN_BOLD("[heard_name] [phone_ident]")]  [SPAN_MESSAGE(M.say_quote(text[1]))]")

		transmit_speech(said_message)

	proc/transmit_speech(var/list/said_message)
		SEND_SIGNAL(networker_parent, COMSIG_PHONE_SPEECH_OUT, said_message)

	proc/transmit_vape()

	proc/transmit_voltron()


	/*proc/get_parent()
		RETURN_TYPE(/mob)
		if(ismob(parent.loc))
			. = src.loc*/


/// Handles the output from a phone. Speech, vapes, outgoing rings, voltrons, etc.
/// May have a different owner than its networker
/// MUST be in an atom. Make a new component if your speaker isn't one.
/datum/component/phone_speaker_atom

	/// The parent holder containing our networker
	var/atom/networker_parent

	var/datum/controller/process/phone_ringing/ring_process = null

	Initialize(var/net_parent)
		. = ..()
		networker_parent = net_parent
		RegisterSignal(networker_parent, COMSIG_PHONE_SPEECH_IN, PROC_REF(receive_speech))
		RegisterSignal(networker_parent, COMSIG_PHONE_VAPE_IN, PROC_REF(receive_vape))
		RegisterSignal(networker_parent, COMSIG_PHONE_VOLTRON_IN, PROC_REF(receive_voltron))
		RegisterSignal(networker_parent, COMSIG_PHONE_CALL_REQUEST_ACCEPTED, PROC_REF(call_request_accepted))
		if(processScheduler)
			for(var/datum/controller/process/phone_ringing/P in processScheduler.processes)
				ring_process = P
				break
		RegisterSignal(networker_parent, COMSIG_PHONE_START_RING, PROC_REF(start_ring))
		RegisterSignal(networker_parent, COMSIG_PHONE_STOP_RING, PROC_REF(stop_ring))

	proc/get_user()
		if(istype(parent, /atom))
			var/atom/A = parent
			if(istype(A.loc, /mob))
				return A.loc

	proc/receive_speech(var/signal_parent, var/list/speech)
		// this is kinda ass since it'll ONLY work if someone's holding us or something
		// this works for now. this is a simple comp anyways so making a new one for other purposes is fine
		var/mob/user = get_user()
		if(user)
			user.show_message(speech, 2)

	proc/receive_vape(var/signal_parent, datum/partner)

	proc/receive_voltron(var/signal_parent, datum/partner)

	proc/call_request_accepted()
		var/mob/user = get_user()
		if(user)
			user.playsound_local(user,'sound/machines/phones/remote_answer.ogg',50,0)

	proc/start_ring()
		RegisterSignal(ring_process, COMSIG_PHONE_RINGER_PROCESS_TICK, PROC_REF(do_ring))
	proc/stop_ring()
		UnregisterSignal(ring_process, COMSIG_PHONE_RINGER_PROCESS_TICK)
	proc/do_ring()
		if(istype(parent, /atom))
			var/atom/A = parent
			if(istype(A.loc, /mob))
				var/mob/M = A.loc
				M.playsound_local(M,'sound/machines/phones/ring_outgoing.ogg' ,40,0)

/// Handles animations and noises for inbound ringing
/// Optional, but MUST be on an atom
/// May have a different owner than its networker
/datum/component/phone_ringer_atom

	/// The parent holder containing our networker
	var/atom/networker_parent
	var/datum/controller/process/phone_ringing/ring_process = null

	Initialize(var/atom/net_parent)
		. = ..()
		networker_parent = net_parent
		if(processScheduler)
			for(var/datum/controller/process/phone_ringing/P in processScheduler.processes)
				ring_process = P
				break
		RegisterSignal(networker_parent, COMSIG_PHONE_START_RING, PROC_REF(start_ring))
		RegisterSignal(networker_parent, COMSIG_PHONE_STOP_RING, PROC_REF(stop_ring))

	proc/start_ring()
		RegisterSignal(ring_process, COMSIG_PHONE_RINGER_PROCESS_TICK, PROC_REF(do_ring))
	proc/stop_ring()
		UnregisterSignal(ring_process, COMSIG_PHONE_RINGER_PROCESS_TICK)
	proc/do_ring()
		if(istype(parent, /atom))
			var/atom/A = parent
			playsound(A.loc,'sound/machines/phones/ring_incoming.ogg' ,40,0)

#undef FAIL
#undef SUCCESS
