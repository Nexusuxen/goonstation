/* orted notes:
- All kinds of data should be immune to a null response. If blocked, then nothing happens.
- When starting a call, listen for COMSIGs from the recipient
  phone_packets should be transmitted this way rather than broadcasted to all phones
- Networks! Phones only see what's on their network. For now just have the "NT13 Network".
 - Maybe later on we can get switchboards or magic phones that allow seeing other networks
*/


/// Handles interfacing with a switchboard and the rest of the phone
/datum/component/phone_networker

	/// Our unique identifier
	var/phone_id = null
	var/datum/phone_switchboard/our_switchboard = null

	New()
		. = ..()
		RegisterSignal(parent, COMSIG_PHONE_SWITCHBOARD_REGISTER_SUCCESSFUL, PROC_REF(register_success))
		RegisterSignal(parent, COMSIG_PHONE_SWITCHBOARD_REGISTER_FAILED, PROC_REF(register_failed))
		RegisterSignal(parent, COMSIG_PHONE_CALL_REQUEST, PROC_REF(call_request))
		RegisterSignal(parent, COMSIG_PHONE_CALL_REQUEST_DENIED, PROC_REF(call_request_denied))
		RegisterSignal(parent, COMSIG_PHONE_CALL_REQUEST_ACCEPTED, PROC_REF(call_request_accepted))
		RegisterSignal(parent, COMSIG_PHONE_CALL_ENDED, PROC_REF(call_ended))

		// THIS IS A HACKJOB FOR DEV PURPOSES
		phone_id = num2text(rand(1, 10000))
		find_switchboard(global.nt13_switchboard)


	proc/find_switchboard(datum/phone_switchboard/switchboard)
		SEND_SIGNAL(switchboard, COMSIG_PHONE_SWITCHBOARD_REGISTER, target_id = phone_id, target = parent)

	proc/register_success(datum/phone_switchboard/switchboard)
		our_switchboard = switchboard

	proc/register_failed()

	/// Handles inbound call requests from our switchboard
	proc/call_request(caller_id, datum/caller, target_id, datum/phone_switchboard)
		// todo: figure out how to make it so that when the handset is picked up we'll never accept
		SEND_SIGNAL(our_switchboard, COMSIG_PHONE_CALL_REQUEST_ACCEPTED, caller_id, caller, target_id, phone_switchboard)

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
		// BIG TODO: We need some kind of main phone coordinator looking for these signals to then forward to
		// the relevant phones. On New() we tell the coordinator "hi register us pls", they do that, then
		// whenever we do COMSIG_PHONE_CALL_REQUEST it'll signal to the correct phone
		SEND_SIGNAL(parent, COMSIG_PHONE_CALL_REQUEST, phone_id, parent, target_id)

	proc/call_ended(datum/phone_switchboard/switchboard)

/// Handles UI actions for phones. Displaying TGUI to a client, relaying input to the coordinator, etc.
/// May have a different owner than its coordinator
/datum/component/phone_ui



/// Hears anything spoken into its owner and sends to coordinator.
/// May have a different owner than its coordinator
/datum/component/phone_microphone



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





	/*proc/get_parent()
		RETURN_TYPE(/mob)
		if(ismob(parent.loc))
			. = src.loc*/


/// Handles the output from a phone. Speech, vapes, outgoing rings, voltrons, etc.
/// May have a different owner than its coordinator
/datum/component/phone_speaker



/// Handles animations and noises for inbound ringing
/// This component is optional, as are the animations and noises
/// May have a different owner than its coordinator
/datum/component/phone_ringer


