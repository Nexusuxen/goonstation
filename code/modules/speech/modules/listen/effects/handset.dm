/datum/listen_module/effect/handset
	id = LISTEN_EFFECT_HANDSET

/datum/listen_module/effect/handset/process(datum/say_message/message)
	var/obj/item/phone_handset/handset = src.parent_tree.listener_parent
	if (!istype(handset))
		return

	SEND_SIGNAL(handset.parent, COMSIG_PHONE_SPEECH_OUT, message)

	handset.last_talk = TIME
