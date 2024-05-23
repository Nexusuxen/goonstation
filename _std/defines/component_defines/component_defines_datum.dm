// Component defines for datums.

// --- datum signals ---

	/// when a component is added to a datum: (/datum/component)
	#define COMSIG_COMPONENT_ADDED "component_added"
	/// before a component is removed from a datum because of RemoveComponent: (/datum/component)
	#define COMSIG_COMPONENT_REMOVING "component_removing"
	/// just before a datum's disposing()
	#define COMSIG_PARENT_PRE_DISPOSING "parent_pre_disposing"
	/// when a variable is changed by admin varedit
	#define COMSIG_VARIABLE_CHANGED "variable_changed"
	/// when a proc is called by admin proc-call
	#define COMSIG_PROC_CALLED "proc_called"

// ---- mind signals ----

	/// when a mind attaches to a mob (mind, new_mob, old_mob)
	#define COMSIG_MIND_ATTACH_TO_MOB "mind_attach_to_mob"
	/// when a mind detaches from a mob (mind, old_mob, new_mob)
	#define COMSIG_MIND_DETACH_FROM_MOB "mind_detach_from_mob"
	/// when a mind should update the contents of its memory
	#define COMSIG_MIND_UPDATE_MEMORY "update_dynamic_player_memory"

// ---- area signals ----

	/// area's active var set to true (when a client enters)
	#define COMSIG_AREA_ACTIVATED "area_activated"
	/// area's active var set to false (when all clients leave)
	#define COMSIG_AREA_DEACTIVATED "area_deactivated"

// ---- TGUI signals ----
	/// A TGUI window was opened by a user (receives tgui datum)
	#define COMSIG_TGUI_WINDOW_OPEN "tgui_window_open"

// ---- reagents signals ----
	/// When reagent scanned
	#define COMSIG_REAGENTS_ANALYZED "reagents_analyzed"

// ---- phone signals ----
	/// When a phone wants to register to a switchboard
	/// (target_id, target)
	#define COMSIG_PHONE_SWITCHBOARD_REGISTER "phone_switchboard_register"
	/// When a switchboard successfully registers with a phone
	#define COMSIG_PHONE_SWITCHBOARD_REGISTER_SUCCESSFUL "phone_switchboard_register_successful"
	/// When a switchboard fails to register with a phone
	#define COMSIG_PHONE_SWITCHBOARD_REGISTER_FAILED "phone_switchboard_register_failed"
	/// Signals when an unregister occurs
	/// (target_id, datum, responded)
	#define COMSIG_PHONE_SWITCHBOARD_UNREGISTER "phone_switchboard_unregister"
	/// When a phone dials another phone
	/// (caller_id, caller, target_id, switchboard)
	#define COMSIG_PHONE_CALL_REQUEST "phone_call_request"
	/// When a phone rejects a call request signal
	/// (switchboard, target_id)
	#define COMSIG_PHONE_CALL_REQUEST_DENIED "phone_call_request_denied"
	/// When a phone accepts a call request signal
	#define COMSIG_PHONE_CALL_REQUEST_ACCEPTED "phone_call_request_accepted"
	/// When a phone transmits speech
	#define COMSIG_PHONE_CALL_TRANSMIT_SPEECH "phone_call_transmit_speech"
	/// When a phone transmits some nerd's vape exhale
	#define COMSIG_PHONE_CALL_TRANSMIT_VAPE "phone_call_transmit_vape"
	/// When a phone transmits a voltron-using nerd
	#define COMSIG_PHONE_CALL_TRANSMIT_VOLTRON "phone_call_transmit_voltron"
	/// When a phonecall request is recognized and rejected
	#define COMSIG_PHONE_CALL_TRANSMIT_REJECTED "phone_call_transmit_rejected"
	/// When one phone wants to terminate the call
	#define COMSIG_PHONE_HANGUP "phone_call_hangup"
	/// When a phonecall has ended
	#define COMSIG_PHONE_CALL_ENDED "phone_call_ended"
	/// Signals a phone networker to dial the provided phone ID
	/// (target_id)
	#define COMSIG_PHONE_DIAL "phone_dial"
	/// When speech is picked up by the microphone
	#define COMSIG_PHONE_SPOKEN_INTO "phone_spoken_into"
