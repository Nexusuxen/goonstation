// Switchboard connection signals

	/// Signals to register phone to switchboard
	/// (phone parent, phone_number, phone_name, category, hidden)
	#define COMSIG_PHONE_SWITCHBOARD_REGISTER "phone_switchboard_register"
	/// Signals to unregister phone from switchboard
	/// (phone parent)
	#define COMSIG_PHONE_SWITCHBOARD_UNREGISTER "phone_switchboard_unregister"
	/// Carries phonebook data to update phones' phonebooks
	/// (phonebook (list), append (bool))
	#define COMSIG_PHONE_BOOK_DATA "phone_book_data"

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
	/// When a phone transmits a sound
	#define COMSIG_PHONE_SOUND_OUT "phone_sound_out"

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
	/// When a phone receives a sound
	#define COMSIG_PHONE_SOUND_IN "phone_sound_in" //todo add handling for more args

// Internal signals

	/// When speech is picked up by the microphone
	#define COMSIG_PHONE_SPOKEN_INTO "phone_spoken_into"
	/// When a phone holder wants to use the phone_ui UI
	/// args: user, force_ui = FALSE
	#define COMSIG_PHONE_UI_INTERACT "phone_ui_interact"
	/// Signals a ui_component to close the UI
	#define COMSIG_PHONE_UI_CLOSE "phone_ui_close"
	/// orders the ringer component (if any) to start ringing
	#define COMSIG_PHONE_START_RING "phone_start_ring"
	/// orders the ringer component (if any) to stop ringing
	#define COMSIG_PHONE_STOP_RING "phone_stop_ring"
	/// Sent by /datum/controller/process/phone_ringing to ring phones
	#define COMSIG_PHONE_RINGER_PROCESS_TICK "phone_ring_process_tick"
	/// Sent to update any changes to things like name and category
	#define COMSIG_PHONE_UPDATE_INFO "phone_update_info"

// Return bitflags

	/// attempted action failed
	#define PHONE_FAIL (1<<0)
	/// attempted action successful
	#define PHONE_SUCCESS (1<<1)
	/// action resulted in a phonecall being answered
	#define PHONE_ANSWERED (1<<2)
	/// if a phone is already connected or registered to a phone/switchboard
	#define PHONE_ALREADY_CONNECTED (1<<3)

// Misc junk

	/// Default ring sound heard through a phone's speaker
	#define PHONE_DEFAULT_RING_SPEAKER 'sound/machines/phones/ring_outgoing.ogg'
	/// Default ring sound that a phone will play on its parent
	#define PHONE_DEFAULT_RING_EXTERNAL 'sound/machines/phones/ring_incoming.ogg'
	/// When you want to try entering a microphone with a voltron
	#define COMSIG_PHONE_ATTEMPT_VOLTRON "phone_attempt_voltron"
	/// When you want to try vaping into a microphone
	#define COMSIG_PHONE_ATTEMPT_VAPE "phone_attempt_vape"
