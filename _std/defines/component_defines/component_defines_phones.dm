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
	/// When we pick up the phone, accepting any call requests or starting a session with the switchboard
	#define COMSIG_PHONE_PICKUP "phone_pickup"
	/// When we deny or terminate a pending or active call
	#define COMSIG_PHONE_HANGUP "phone_hangup"

	/// When a phone transmits speech
	#define COMSIG_PHONE_SPEECH_OUT "phone_speech_out"
	/// When a phone transmits some nerd's vape exhale
	#define COMSIG_PHONE_VAPE_OUT "phone_vape_out"
	/// When a phone transmits a voltron-using nerd
	#define COMSIG_PHONE_VOLTRON_OUT "phone_voltron_out"
	/// When a phone transmits a sound (currently only supports sound file and volume as arguments)
	#define COMSIG_PHONE_SOUND_OUT "phone_sound_out" // maybe add support for more playsound() args?

// Inbound signals

	/// When another phone starts calling us
	#define COMSIG_PHONE_INBOUND_CONNECTION "phone_inbound_connection_attempt"
	/// Signals that a call has successfully been started and that we should ring if possible
	#define COMSIG_PHONE_START_RING "phone_start_ring"
	/// Signals that a call has ended and that we should stop ringing if we already are
	#define COMSIG_PHONE_STOP_RING "phone_stop_ring"

	/// When a phone receives speech
	#define COMSIG_PHONE_SPEECH_IN "phone_speech_in"
	/// When a phone receives some nerd's vape exhale
	#define COMSIG_PHONE_VAPE_IN "phone_vape_in"
	/// When a phone receives a voltron-using nerd
	#define COMSIG_PHONE_VOLTRON_IN "phone_voltron_in"
	/// When a phone receives a sound (currently only supports sound file and volume as arguments)
	#define COMSIG_PHONE_SOUND_IN "phone_sound_in"

// Internal signals

	/// When speech is picked up by the microphone
	#define COMSIG_PHONE_SPOKEN_INTO "phone_spoken_into"
	/// When a phone holder wants to use the phone_ui UI
	/// args: user, force_ui = FALSE
	#define COMSIG_PHONE_UI_INTERACT "phone_ui_interact"
	/// Signals a ui_component to close the UI
	#define COMSIG_PHONE_UI_CLOSE "phone_ui_close"
	/// Sent by /datum/controller/process/phone_ringing to ring phones
	#define COMSIG_PHONE_RINGER_PROCESS_TICK "phone_ring_process_tick"
	/// Sent to update any changes to things like name and category
	#define COMSIG_PHONE_UPDATE_INFO "phone_update_info"

// Misc junk

	/// Default ring sound heard through a phone's speaker
	#define PHONE_DEFAULT_RING_SPEAKER 'sound/machines/phones/ring_outgoing.ogg'
	/// Default ring sound that a phone will play on its parent
	#define PHONE_DEFAULT_RING_EXTERNAL 'sound/machines/phones/ring_incoming.ogg'
	/// When you want to try entering a microphone with a voltron
	#define COMSIG_PHONE_ATTEMPT_VOLTRON "phone_attempt_voltron"
	/// When you want to try vaping into a microphone
	#define COMSIG_PHONE_ATTEMPT_VAPE "phone_attempt_vape"
