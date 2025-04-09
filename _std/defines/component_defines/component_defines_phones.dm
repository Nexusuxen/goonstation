// Switchboard connection signals

	/// When a phone wants to register to a switchboard. Sent on datum/switchboard as origin
	/// (target_id, target)
	#define COMSIG_PHONE_SWITCHBOARD_REGISTER "phone_switchboard_register"
	/// When a switchboard successfully registers with a phone
	#define COMSIG_PHONE_SWITCHBOARD_REGISTER_SUCCESSFUL "phone_switchboard_register_successful"
	/// When a switchboard fails to register with a phone
	#define COMSIG_PHONE_SWITCHBOARD_REGISTER_FAILED "phone_switchboard_register_failed"
	/// Signals when an unregister occurs. Sent on datum/switchboard as origin
	/// (target_id, datum, responded)
	#define COMSIG_PHONE_SWITCHBOARD_UNREGISTER "phone_switchboard_unregister"

// Outbound signals

	/// Request to dial the provided phone ID
	#define COMSIG_PHONE_ATTEMPT_CONNECT "phone_attempt_connect"
	/// When we pick up the phone, accepting any call requests
	#define COMSIG_PHONE_PICKUP "phone_pickup"
	/// When we deny or terminate a pending or active call
	#define COMSIG_PHONE_HANGUP "phone_hangup"

	/// When a phone transmits speech
	#define COMSIG_PHONE_SPEECH_OUT "phone_speech_out"
	/// When a phone transmits some nerd's vape exhale
	#define COMSIG_PHONE_VAPE_OUT "phone_vape_out"
	/// When a phone transmits a voltron-using nerd
	#define COMSIG_PHONE_VOLTRON_OUT "phone_voltron_out"

// Inbound signals

	/// When another phone wants to start calling us
	/// Expected to return 0 if ignored, 1 if accepted (even if we don't pick up yet)
	#define COMSIG_PHONE_INBOUND_CONNECTION_ATTEMPT "phone_inbound_connection_attempt"
	/// When the phone is picked up
	#define COMSIG_PHONE_CALL_REQUEST_ACCEPTED "phone_call_request_accepted"
	/// When a call is denied or ends
	#define COMSIG_PHONE_CONNECTION_CLOSED "phone_connection_closed"

	/// When a phone receives speech
	#define COMSIG_PHONE_SPEECH_IN "phone_speech_in"
	/// When a phone receives some nerd's vape exhale
	#define COMSIG_PHONE_VAPE_IN "phone_vape_in"
	/// When a phone receives a voltron-using nerd
	#define COMSIG_PHONE_VOLTRON_IN "phone_voltron_in"

// Internal signals

	/// When speech is picked up by the microphone
	#define COMSIG_PHONE_SPOKEN_INTO "phone_spoken_into"
	/// When a phone holder wants to use the phone_ui UI
	/// args: user, force_ui = FALSE
	#define COMSIG_PHONE_UI_INTERACT "phone_ui_interact"
	/// orders the ringer component (if any) to start ringing
	#define COMSIG_PHONE_START_RING "phone_start_ring"
	/// orders the ringer component (if any) to stop ringing
	#define COMSIG_PHONE_STOP_RING "phone_stop_ring"
	/// Sent by /datum/controller/process/phone_ringing to ring phones
	#define COMSIG_PHONE_RINGER_PROCESS_TICK "phone_ring_process_tick"
