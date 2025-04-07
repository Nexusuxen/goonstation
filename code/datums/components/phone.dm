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

/// Handles interfacing with a switchboard and the rest of the phone
/datum/component/phone_networker

	/// Our unique identifier
	var/phone_id = null
	var/datum/phone_switchboard/our_switchboard = null

	var/datum/our_ui
	var/datum/our_mic
	var/datum/our_speaker
	var/datum/our_ringer

	New()
		. = ..()
		RegisterSignal(parent, COMSIG_PHONE_SWITCHBOARD_REGISTER_SUCCESSFUL, PROC_REF(register_success))
		RegisterSignal(parent, COMSIG_PHONE_SWITCHBOARD_REGISTER_FAILED, PROC_REF(register_failed))
		RegisterSignal(parent, COMSIG_PHONE_CALL_REQUEST_IN, PROC_REF(call_request_in))
		RegisterSignal(parent, COMSIG_PHONE_CALL_REQUEST_CLOSED, PROC_REF(call_request_denied))
		RegisterSignal(parent, COMSIG_PHONE_CALL_REQUEST_ACCEPTED, PROC_REF(call_request_accepted))
		RegisterSignal(parent, COMSIG_PHONE_SPEECH_IN, PROC_REF(receive_speech))
		RegisterSignal(parent, COMSIG_PHONE_VAPE_IN, PROC_REF(receive_vape))
		RegisterSignal(parent, COMSIG_PHONE_VOLTRON_IN, PROC_REF(receive_voltron))
		//RegisterSignal()

		// THIS IS A HACKJOB FOR DEV PURPOSES
		// TODO: MAKE PROPER PHONE NUMBERS
		phone_id = num2text(rand(1, 10000))
		phone_numbers[phone_id] += parent
		phone_numbers_inv[parent] += phone_id
		try_register_switchboard(global.nt13_switchboard)


	proc/try_register_switchboard(datum/phone_switchboard/switchboard)
		SEND_SIGNAL(switchboard, COMSIG_PHONE_SWITCHBOARD_REGISTER, parent, phone_id)

	proc/register_success(datum/phone_switchboard/switchboard)
		our_switchboard = switchboard

	proc/register_failed()

	/// Handles inbound call requests
	proc/call_request_in(caller_id)
		// todo: figure out how to make it so that when the handset is picked up we'll never accept
		SEND_SIGNAL(parent, COMSIG_PHONE_CALL_ACCEPT_REQUEST)

	proc/call_request_denied(datum/partner)
		// todo: relay to speaker

	proc/call_request_accepted(datum/partner)


	proc/receive_speech(datum/partner, var/list/speech)
		world << "DEBUG MESSAGE, WE'VE RECEIVED SPEECH"

	proc/receive_vape(datum/partner)

	proc/receive_voltron(datum/partner)

	proc/message_rejected(datum/partner)

		// todo: relay to speaker

	proc/transmit_speech(var/list/speech)

	proc/transmit_vape()

	proc/transmit_voltron()

	proc/reject_message()

	/// Sends the Switchboard a request to connect to the phone with the provided ID, with the optional
	/// check for if they're on the same network
	/// You should probably be calling a network var unless you want your phone to be able to call all phones
	proc/request_call(var/target_id)
		// BIG TODO: We need some kind of main phone networker looking for these signals to then forward to
		// the relevant phones. On New() we tell the networker "hi register us pls", they do that, then
		// whenever we do COMSIG_PHONE_CALL_REQUEST_IN it'll signal to the correct phone
		SEND_SIGNAL(parent, COMSIG_PHONE_CALL_REQUEST_IN, phone_id, parent, target_id)

	proc/call_ended(datum/phone_switchboard/switchboard)

/// Handles UI actions for phones. Displaying TGUI to a client, relaying input to the networker, etc.
/// May have a different owner than its networker
/datum/component/phone_ui

	/// The parent holder containing our networker
	var/datum/networker_parent

	/// what we should be called, i guess
	var/our_name

	ui_interact(mob/user, datum/tgui/ui)
		ui = tgui_process.try_update_ui(user, src, ui)
		if(!ui)
			ui = new(user, src, "Phone")
			ui.open()

	ui_data(mob/user)
		var/list/list/list/phonebook = list()

		for(var/P in phone_numbers_inv)
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
			"inCall" = "inCall",
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
				if(SEND_SIGNAL(networker_parent, COMSIG_PHONE_CALL_REQUEST_OUT, id))
					return
				boutput(usr, SPAN_ALERT("Unable to connect!"))

/// Hears anything spoken into its owner and sends to networker.
/// May have a different owner than its networker
/datum/component/phone_microphone

	/// The parent holder containing our networker
	var/datum/networker_parent

	New()
		..()
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

		SEND_SIGNAL(networker_parent, COMSIG_PHONE_SPEECH_OUT, said_message)



	/*proc/get_parent()
		RETURN_TYPE(/mob)
		if(ismob(parent.loc))
			. = src.loc*/


/// Handles the output from a phone. Speech, vapes, outgoing rings, voltrons, etc.
/// May have a different owner than its networker
/datum/component/phone_speaker

	/// The parent holder containing our networker
	var/datum/networker_parent

/// Handles animations and noises for inbound ringing
/// This component is optional, as are the animations and noises
/// May have a different owner than its networker
/datum/component/phone_ringer

	/// The parent holder containing our networker
	var/datum/networker_parent
