//Contains:
//-Status display
//-AI status display

// // Status display
// // (formerly Countdown timer display)

// // Use to show shuttle ETA/ETD times
// // Alert status
// // And arbitrary messages set by comms computer

#define MAX_LEN 5
/obj/machinery/status_display
	icon = 'icons/obj/status_display.dmi'
	icon_state = "frame"
	name = "status display"
	anchored = 1
	density = 0
	mats = 14
	deconstruct_flags = DECON_SCREWDRIVER | DECON_WRENCH | DECON_CROWBAR | DECON_WELDER | DECON_MULTITOOL

	var/mode = 1	// 0 = Blank
					// 1 = Shuttle timer
					// 2 = Arbitrary message(s)
					// 3 = alert picture
					// 4 = Supply shuttle timer  -- NO LONGER SUPPORTED
					// 5 = Research station destruct timer
					// 6 = Mining Ore Score Tracking -- NO LONGER SUPPORTED

	var/picture_state	// icon_state of alert picture
	var/message1 = ""	// message line 1
	var/message2 = ""	// message line 2
	var/index1			// display index for scrolling messages or 0 if non-scrolling
	var/index2
	var/use_maptext = TRUE

	var/lastdisplayline1 = ""		// the cached last displays
	var/lastdisplayline2 = ""

	var/frequency = 1435		// radio frequency

	var/display_type = 0		// bitmask of messages types to display: 0=normal  1=supply shuttle  2=reseach stn destruct

	var/repeat_update = FALSE	// true if we are going to update again this ptick

	var/image/crt_image = null

	// new display
	// register for radio system
	New()
		..()
		src.layer -= 0.2
		crt_image = SafeGetOverlayImage("crt", src.icon, "crt")
		crt_image.layer = src.layer + 0.1
		crt_image.plane = PLANE_DEFAULT
		crt_image.appearance_flags = NO_CLIENT_COLOR | RESET_ALPHA | KEEP_APART
		crt_image.alpha = 255
		crt_image.mouse_opacity = 0
		UpdateOverlays(crt_image, "crt")

		MAKE_DEFAULT_RADIO_PACKET_COMPONENT(null, frequency)

	// timed process
	process()
		if(status & NOPOWER)
			ClearAllOverlays()
			return

		use_power(200)

		update()


	// set what is displayed
	proc/update()

		switch(mode)
			if(0)
				maptext = ""
				ClearAllOverlays()

			if(1)	// shuttle timer
				if(emergency_shuttle.online)
					var/displayloc
					if(emergency_shuttle.location == SHUTTLE_LOC_STATION)
						displayloc = "ETD "
					else
						displayloc = "ETA "

					var/displaytime = get_shuttle_timer()
					if(length(displaytime) > MAX_LEN)
						displaytime = "**~**"

					update_display_lines(displayloc, displaytime)

					if(repeat_update)
						var/delay = src.base_tick_spacing * PROCESSING_TIER_MULTI(src)
						SPAWN_DBG(0.5 SECONDS)
							repeat_update = FALSE
							var/iterations = round(delay/5)
							for(var/i in 1 to iterations)
								if(mode != 1 || repeat_update) // kill early if message or mode changed
									break
								update()
								if(i != iterations)
									sleep(0.5 SECONDS) // set to update again in 5 ticks
							repeat_update = TRUE
				else
					set_picture("default")

			if(2)
				var/line1
				var/line2
				var/line_len = use_maptext ? 4 : 5

				if(!index1)
					line1 = message1
				else
					line1 = copytext(message1+message1, index1, index1+line_len)
					if(index1++ > (length(message1)))
						index1 = 1

				if(!index2)
					line2 = message2
				else
					line2 = copytext(message2+message2, index2, index2+line_len)
					if(index2++ > (length(message2)))
						index2 = 1

				// the following allows 2 updates per process, giving faster scrolling
				if((index1 || index2) && repeat_update)	// if either line is scrolling
														// and we haven't forced an update yet
					var/delay = src.base_tick_spacing * PROCESSING_TIER_MULTI(src)
					SPAWN_DBG(0.5 SECONDS)
						repeat_update = FALSE
						var/iterations = round(delay/5)
						for(var/i in 1 to iterations)
							if(mode != 2 || repeat_update) // kill early if message or mode changed
								break
							update()
							if(i != iterations)
								sleep(0.5 SECONDS) // set to update again in 5 ticks
						repeat_update = TRUE

				update_display_lines(line1,line2)

	proc/set_message(var/m1, var/m2)
		if(m1)
			index1 = (length(m1) > MAX_LEN)
			message1 = uppertext(m1)
		else
			message1 = ""
			index1 = 0

		if(m2)
			index2 = (length(m2) > MAX_LEN)
			message2 = uppertext(m2)
		else
			message2 = null
			index2 = 0
		repeat_update = TRUE
		desc = "[message1] [message2]"
		lastdisplayline1 = null
		lastdisplayline2 = null

#undef MAX_LEN

	proc/set_maptext(var/line1, var/line2)
		if(!line2)
			src.maptext = {"<span class='vm c' style="font-family: StatusDisp; font-size: 6px;  color: #09f">[line1]</span>"}
		else
			src.maptext = {"<span class='vm c' style="font-family: StatusDisp; font-size: 6px;  color: #09f">[line1]<BR/>[line2]</span>"}

	proc/set_picture(var/state)
		var/image/previous = GetOverlayImage("picture")
		if(previous?.icon_state == state)
			return
		src.maptext = ""
		picture_state = state
		UpdateOverlays(image('icons/obj/status_display.dmi', icon_state=picture_state), "picture")
		UpdateOverlays(null, "overlay_image")
		UpdateOverlays(crt_image, "crt")

	proc/set_picture_overlay(var/state, var/overlay)
		var/image/previous_state = GetOverlayImage("picture")
		var/image/previous_overlay = GetOverlayImage("overlay_image")
		if(previous_state?.icon_state == state && previous_overlay?.icon_state == overlay)
			return
		src.maptext = ""
		picture_state = state+overlay
		UpdateOverlays(image('icons/obj/status_display.dmi', icon_state=state), "picture")
		UpdateOverlays(image('icons/obj/status_display.dmi', icon_state=overlay), "overlay_image")
		UpdateOverlays(crt_image, "crt")

	proc/update_display_lines(var/line1, var/line2, var/image/override = null)
		if(line1 == lastdisplayline1 && line2 == lastdisplayline2)
			return			// no change, no need to update

		lastdisplayline1 = line1
		lastdisplayline2 = line2

		set_maptext(line1, line2)

		if(GetOverlayImage("picture") || GetOverlayImage("overlay_image") || !GetOverlayImage("crt"))
			UpdateOverlays(null, "picture")
			UpdateOverlays(null, "overlay_image")
			UpdateOverlays(crt_image, "crt")

	// return shuttle timer as text
	proc/get_shuttle_timer()
		var/timeleft = emergency_shuttle.timeleft()
		if(timeleft)
			return "[add_zero(num2text((timeleft / 60) % 60),2)]~[add_zero(num2text(timeleft % 60), 2)]"
			// note ~ translates into a smaller :
		return ""

	receive_signal(datum/signal/signal)

		switch(signal.data["command"])
			if("blank")
				mode = 0

			if("shuttle")
				mode = 1
				repeat_update = TRUE

			if("message")
				mode = 2
				set_message(signal.data["msg1"], signal.data["msg2"])

			if("alert")
				mode = 3
				set_picture(signal.data["picture_state"])

			if("destruct")
				if(display_type & 2)
					mode = 5
					var/timeleft = signal.data["time"]
					if(text2num(timeleft) <= 30)
						set_picture_overlay("destruct_small", "d[timeleft]")
					else
						set_picture("destruct")



/obj/machinery/status_display/supply_shuttle
	name = "status display"


/obj/machinery/status_display/research
	name = "status display"
	display_type = 2

/obj/machinery/status_display/mining
	name = "mining display"
	mode = 6

/obj/machinery/ai_status_display
	icon = 'icons/obj/status_display.dmi'
	icon_state = "ai_frame_cr"
	name = "\improper AI display"
	desc = "This AI Display is equipped with a camera and intercom for interfacing with the on-board AI."
	anchored = 1
	density = 0
	open_to_sound = 1 // we (probably) have an internal radio that needs to hear the outside world!
	mats = list("MET-1"=2, "CON-1"=6, "CRY-1"=6)
	deconstruct_flags = DECON_SCREWDRIVER | DECON_WRENCH | DECON_CROWBAR | DECON_WELDER | DECON_MULTITOOL

	machine_registry_idx = MACHINES_STATUSDISPLAYS
	var/emagged = FALSE //Are we emagged, permanently disabling our equipment?

	var/mob/living/silicon/ai/owner //Let's have AIs play tug-of-war with status screens
	var/image/face_image = null //AI expression, optionally the entire screen for the red & BSOD faces
	var/image/back_image = null //The bit that gets coloured
	var/image/glow_image = null //glowy lines

	var/image/damageOverlay = null // will either be cracks or a shattered screen to indicate how damaged we are or what repair step we're on
	var/image/cameraOverlay = null // blinking camera light for when the camera is active
	var/image/speakerOverlay = null // solid green light for when the display speaker is online
	// no, we don't let people know we're listening. the ai is always listening. :)

	var/manualConnectRequired = FALSE // controls whether or not manual reconnection to display is required; set to true by EMPs and occasionally by taking damage

	//Variables of our current state, these get checked against variables in the AI to check if anything needs updating
	var/emotion = null //an icon state
	var/message = null //displays on examine
	var/face_color = null

	var/datum/light/screen_glow

	var/lastPresenceRequest = 0 // anti-spam measures, 1 min cooldown between presence requests.
	var/lastDisrupted = 0 // keeps track of when the ai can reconnect to a display; used when a display glitches out from damage/EMP

	#define ON 1 // for legibility regarding setEquipmentState
	#define OFF 0

	var/has_radio = TRUE // for if you want a radio-less display for whatever reason
	var/obj/item/device/radio/intercom/AI/aiDisplay/internal_radio // intercom/aiDisplay should be located after/beneath /ai_status_display
	var/broadcastingByDefault = FALSE // these two will determine the initial mic/speaker status of the internal intercom respectively
	var/listeningByDefault = FALSE // for if you want a specific display to start with its mic and speaker on, for example

	var/has_camera = TRUE // that face is looking back at you :)
	var/obj/machinery/camera/ai/internal_camera // gotta keep track of our camera, too
	// camera/ai is defined under camera, right next to ranch camera in camera.dm

	var/equipmentState = OFF // should our radio and camera be online if we have them??

	_health = 100
	_max_health = 100
	var/repairStep = 0 // 7 steps (not including 0) to fix, detailed in repairProcess()
	var/repairHint = "unscrew the broken screen from the casing" // we wanna let the user know what they should do next to continue repairs. starts at first step

/*
Initially written for my own sanity but if you're reading this then I kept this in as sort of documentation

The following vars control the functionality of the display in different ways:
--- equipmentStatus
		Whether or not the radio/camera should be on or not
		Independent of NOPOWER and BROKEN, though those two will ALWAYS set this to FALSE/OFF
		May ONLY be true if owner is true. If otherwise, fix that shit.
--- Status (bitflag):
	BROKEN
		Whether or not the display has been broken; sets equipmentStatus & owner to 0/null respectively
		Does NOT set NOPOWER (unless BROKEN naturally does that)
	NOPOWER
		Whether or not there's any power. Sets equipmentStatus to 0 but keeps owner assuming nothing else reset it
--- manualConnectRequired:
		Set to true when a display is shut down via emp/brute force (but NOT by destroying it).
		Should not be true while equipmentPower or Owner
---
*/

	New()
		..()
		damageOverlay = image('icons/obj/status_display.dmi', icon_state = "", layer = FLOAT_LAYER + 1)
		face_image = image('icons/obj/status_display.dmi', icon_state = "", layer = FLOAT_LAYER)
		glow_image = image('icons/obj/status_display.dmi', icon_state = "ai_glow", layer = FLOAT_LAYER - 1)
		back_image = image('icons/obj/status_display.dmi', icon_state = "ai_white", layer = FLOAT_LAYER - 2)

		if(pixel_y == 0 && pixel_x == 0)
			if (map_settings.walls ==/turf/simulated/wall/auto/jen)
				pixel_y = 32
			else
				pixel_y = 29

		screen_glow = new /datum/light/point
		screen_glow.set_brightness(0.45)
		screen_glow.set_height(0.75)
		screen_glow.attach(src)

		if (has_radio)
			internal_radio = new(src)
			internal_radio.broadcasting = broadcastingByDefault
			internal_radio.listening = listeningByDefault
			speakerOverlay = image('icons/obj/status_display.dmi', icon_state = "r_overlay", layer = FLOAT_LAYER + 1)
		if (has_camera)
			internal_camera = new(src)
			cameraOverlay = image('icons/obj/status_display.dmi', icon_state = "c_overlay", layer = FLOAT_LAYER + 1)

	disposing()
		if (screen_glow)
			screen_glow.dispose()
		..()

	process()
		if (owner)
			if(!owner.get_inhabited_mob())
				resetDisplay() // we only wanna be on if our owner is in-game, it lets people know our owner is available!
		if (HAS_FLAG(status, NOPOWER) || !owner) // in addendum to above, that also lets a new AI automatically connect to all the displays if the old one left the game
			UpdateOverlays(null, "emotion_img")
			UpdateOverlays(null, "back_img")
			UpdateOverlays(null, "glow_img")
			screen_glow.disable()
			if(equipmentState)
				setEquipmentState(OFF)
			return
		update()
		use_power(200)

	proc/update(var/justClaimed = FALSE)
		//if (!owner)
			//return // runtime prevention, just in case something Fucky Wucky happens. leave commented during testing.

		if (!equipmentState && !emagged)
			setEquipmentState(ON)
		//Update backing colour
		if (face_color != owner.faceColor)
			face_color = owner.faceColor
			back_image.color = face_color
			UpdateOverlays(back_image, "back_img")
			//display light
			var/colors = GetColors(face_color)
			screen_glow.set_color(colors[1] / 255, colors[2] / 255, colors[3] / 255)

		//Update expression
		if (src.emotion != owner.faceEmotion)
			UpdateOverlays(owner.faceEmotion != "ai-tetris" ? glow_image : null, "glow_img")
			face_image.icon_state = owner.faceEmotion
			UpdateOverlays(face_image, "emotion_img")
			emotion = owner.faceEmotion

		//Re-enable all the stuff if we are powering on again
		if (!screen_glow.enabled)
			screen_glow.enable()
			UpdateOverlays(face_image, "emotion_img")
			UpdateOverlays(back_image, "back_img")
			UpdateOverlays(owner.faceEmotion != "ai-tetris" ? glow_image : null, "glow_img")
			if (internal_camera)
				src.internal_camera.camera_status = 1
				src.internal_camera.updateCoverage()
			// we don't turn the radio back on, ai's gotta do it manually
		if (message != owner.status_message)
			message = owner.status_message
			if (!justClaimed) // without this check we'd say the ai's new status every time it connects; imagine the spam from 2 ais spam clicking a display
				playsound(src.loc, 'sound/misc/talk/bottalk_1.ogg', 35, 2)
				speech_bubble()
				audible_message("<b>[src.name]</b> beeps, \"New message from [src.owner]!\"<br><i>'[message]'</i>")

		name = initial(name) + " ([owner.name])"

	/// For when a display is to be claimed. Includes checks for if this should happen or not.
	proc/tryClaimDisplay(var/mob/mainframe, var/mob/user, var/replaceOwner = FALSE) // ai code tries to auto-connect to displays but only to unused ones

		if((!replaceOwner && owner) || HAS_FLAG(status, NOPOWER) || HAS_FLAG(status, BROKEN) || (!replaceOwner && manualConnectRequired))
			if (HAS_FLAG(src.status, BROKEN) && user && replaceOwner)
				boutput(user, "<span class='alert'>You can't tune a broken display to yourself!</span>")
				return
			if (HAS_FLAG(status, NOPOWER) && user && replaceOwner)
				boutput(user, "<span class='alert'><b>This display has no power, you can't tune it to yourself!</b></span>")
				return
			return // replaceOwner = TRUE is only called when manually claiming a display; being glitched requires manual reset so the passive autoconnect won't work

		if(((lastDisrupted + 300) >= world.time) && user) // we wanna give people a brief window before the ai can reconnect if they emp or bash it
			boutput(user,"<span class='alert'><b>ERROR:\\\\ System still resetting.<b> Please wait [30 - ceil((world.time - lastDisrupted) / 10)] seconds.</span>")
			// the math here converts the decisecond times into seconds (rounding up to remove decimals) to get how much time has passed since last disrupt, and then subtracts that from 30 to get remaining time
			return
		owner = mainframe
		update(TRUE)
		if(!user)
			manualConnectRequired = FALSE
			return
		if(!manualConnectRequired)
			boutput(user, "<span class='notice'>You tune the display to your core.</span>")
		else
			boutput(user, "<span class='notice'>You reboot the display and tune it to your core.</span>")
		manualConnectRequired = FALSE

	/// Resets the display to not have an owner. Call with TRUE to cause glitch effects (buzzing noise & momentary static screen) and require manual reconnect by the AI
	proc/resetDisplay(var/doGlitch = FALSE)
		setEquipmentState(OFF)
		if (doGlitch)
			manualConnectRequired = TRUE
			lastDisrupted = world.time
			if (owner)
				emotion = "ai-static" // gotta set this so update() knows to fix it
				visible_message("<span class='alert'><i>[src.name] loudly buzzes as its memory is reset!</i></span>")
				playsound(loc, 'sound/machines/glitch4.ogg', 50, 2)
		else
			emotion = ""
		face_image.icon_state = emotion
		UpdateOverlays(face_image, "emotion_img")
		UpdateOverlays(null, "back_img")
		UpdateOverlays(null, "glow_img")
		face_color = null // game doesn't realize we've fucked with the ai screen's color otherwise oops
		name = initial(name)
		owner = null

	/// Call with ON or OFF to set camera/intercom (if the display has any) to specified state.
	proc/setEquipmentState(var/newState)
		equipmentState = newState
		if (internal_radio && !newState) // radio has to be manually turned back on
			internal_radio.listening = FALSE
			UpdateOverlays(null, "r_overlay")
			internal_radio.broadcasting = FALSE
		if (internal_camera)
			internal_camera.camera_status = newState
			internal_camera.updateCoverage()
		updateStatusOverlays()


	proc/setFixed()
		REMOVE_FLAG(status, BROKEN)
		_health = 100
		name = initial(name)
		updateDamageOverlay()

	proc/setBroken()
		ADD_FLAG(status, BROKEN)
		resetDisplay()
		screen_glow.disable() // we wanna have this happen immediately, not when process() gets around to it
		_health = 0 // mainly for testing purposes but lets this be used by other things to directly break it instead of dealing damage first
		updateDamageOverlay()

	proc/destroy()
		var/ownerOverride = src.owner
		playsound(src.loc, 'sound/impact_sounds/Machinery_Break_1.ogg', 50, 2)
		src.visible_message("<span class='alert'><b>[src.name] is destroyed!</b></span>")
		robogibs(src.loc, null)
		src.setEquipmentState(OFF) // qdel is dumb but we can at least make the intercom window nicely go away when destroy() is called
		src.sendAlert(ownerOverride)
		qdel(src)

	// This needs to be done in multiple places so we might as well have it all in 1 place
	proc/updateDamageOverlay()
		// when we reach 80 health, we'll start forming cracks, which worsen every 16 damage until we reach 0 and Die (there are 5 different crack types, so 80/5 = 16)
		var/overlay
		switch(_health)
			if(81 to 100)
				overlay = null
			if(65 to 80)
				overlay = "cracks1"
			if(49 to 64)
				overlay = "cracks2"
			if(33 to 48)
				overlay = "cracks3"
			if(17 to 32)
				overlay = "cracks4"
			if(1 to 16)
				overlay = "cracks5"
			if(0) // we're at 0 health, so we must be destroyed!
				switch(repairStep)
					if(0 to 1)
						overlay = "destroyed0"
					if(2)
						overlay = "destroyed1"
					if(3)
						overlay = "destroyed2"
					if(4)
						overlay = "destroyed3"
					else
						overlay = null // the last step has the screen look like normal
		damageOverlay.icon_state = overlay
		if (damageOverlay.icon_state)
			src.UpdateOverlays(damageOverlay, "damage_img")
		else
			src.UpdateOverlays(null, "damage_img")

	// Having this in one place makes it easier to maintain
	/// Handles updating the overlays for the camera and speaker indicator overlays
	proc/updateStatusOverlays()
		if (has_radio)
			if (internal_radio.listening)
				src.UpdateOverlays(speakerOverlay, "r_overlay")
			else
				src.UpdateOverlays(null, "r_overlay")
		if (has_camera)
			if (internal_camera.camera_status)
				src.UpdateOverlays(cameraOverlay, "c_overlay")
			else
				src.UpdateOverlays(null, "c_overlay")

	/// Naturally, handles opening intercom UI. Includes checks for if a user should or shouldn't be able to view the UI.
	proc/accessIntercom(var/mob/user) // since multiple things open the UI we need to compact this into one place

		if (!isAI(user) && !isshell(user))
			boutput(user, "<span class='alert'>You're not even an AI, you can't just access this!</span>")
			return
		if (!src.has_radio)
			boutput(user, "<span class='alert'>Error: No intercom detected in [src].</span>")
			return
		if (HAS_FLAG(src.status, NOPOWER) && user)
			boutput(user, "<span class='alert'>Unable to access intercom; equipment currently depowered.</span>")
			return
		if (src.emagged)
			boutput(user, "<span class='alert'>ERROR:\\\\ Equipment control systems corrupted; unable to access radio.</span>")
			return

		if (user != owner.get_inhabited_mob())
			boutput(user, "<span class='alert'>You don't own this display, you can't access its radio!</span>")
			return

		internal_radio.ui_interact(owner.get_message_mob())

	/// Will try to send a message to the owner AI that the mob arg user wants its attention (will also build href links)
	proc/requestPresence(mob/user as mob) // someone wants to ask for the AI to talk to them!
		if(!src.owner) // who you gonna call?! no one.
			return 0
		if(HAS_FLAG(src.status, BROKEN))
			return 1
		if(HAS_FLAG(src.status, NOPOWER))
			return 2
		if((src.lastPresenceRequest + 600) > world.time)
			return 3
		// NOTE: WHEN TERMOS PR GETS MERGED, USE TEXT_TO_AI AND SOUND_TO_AI OR WHATEVER THEY WERE CALLED AND REPLACE THE FOLLOWING CODE WITH IT THANK U
		// need both an internal camera to jump to by default, and a backup thing to find an active camera in view if our internal camera is disabled
		var/mob/target_mob = owner.get_message_mob() // get the mainframe or eye that the player is currently in

		var/nearest_camera = src.getNearestCamera() // not actually nearest, just whatever the below loop finds first in nearby visible cameras
		var/href_camera // what's the text to render for the href camera link??
		if (!nearest_camera)
			href_camera = "<i>No cameras in view of display!</i>"
		else
			href_camera = "<a href='byond://?src=\ref[owner];switchcamera=\ref[nearest_camera]'> <u>Jump to nearby camera</u></a>"

		var/href_intercom // what's the text to render for the href intercom ui shortcut?
		if (internal_radio)
			href_intercom = "<a href='byond://?src=\ref[src];accessIntercom=\ref[owner]'><u>Access intercom</u>"
		else
			href_intercom = "<i>No intercom detected</i>"

		var/href = "[href_camera] | [href_intercom]"
		boutput(target_mob, "--- Notice: [user.name] is requesting your attention via the status display in [get_area(src)]!<br>- [href]")
		src.lastPresenceRequest = world.time
		return 4

	// Not technically 'nearest' but whatever
	proc/getNearestCamera()
		var/obj/machinery/camera/nearest_camera = null
		if (internal_camera?.camera_status) // do we have an active camera??
			nearest_camera = internal_camera
		else
			for (var/obj/machinery/camera/nearby_camera in view(src))
				if (!nearby_camera.camera_status)
					continue
				if (!(nearby_camera.network == "SS13" || nearby_camera.network == "Zeta" || nearby_camera.network == "Robots" || nearby_camera.network == "AI")) // display cams are set to the "AI" network
					continue // if we can see through cameras that are none of the above then uh... someone fix that??
				nearest_camera = nearby_camera
				break
		return nearest_camera

	// ripped from manufacturer code because good god why dont we have some universal handling for this
	proc/take_damage(var/damage_amount = 0)
		if (!damage_amount || (HAS_FLAG(src.status, BROKEN))) // can only trigger it breaking if it's not already broken
			return
		var/ownerOverride = src.owner ? src.owner : null // we might lose src.owner at some point but still need it after
		src._health -= damage_amount
		src._health = max(0,min(src._health,src._max_health))
		playsound(src.loc, 'sound/impact_sounds/Glass_Hit_1.ogg', 50, 2)
		src.updateDamageOverlay()

		if (src._health == 0)
			src.visible_message("<span class='alert'><b>[src.name] breaks!</b></span>")
			playsound(src.loc, 'sound/impact_sounds/Crystal_Shatter_1.ogg', 50, 2)
			playsound(src.loc, 'sound/machines/romhack3.ogg', 50, 2)
			elecflash(src, radius=1, power=3, exclude_center = 0)
			src.setBroken()
			src.sendAlert(ownerOverride)
			name = "\improper broken [initial(name)]"

		else // displays can get concussions and memory loss too, so we better see if it'll forget its owner
			if ((src._health <= 70) && prob(damage_amount * 2) && owner) // coefficient of 2 is so that 5 damage has a 10% chance to trigger reset and 50 damage has a 100% chance
				src.resetDisplay(TRUE)
				src.sendAlert(ownerOverride)

	/// Used to alert the AI that the terminal broke/glitched if it has one
	proc/sendAlert(var/mob/living/silicon/ai/ownerOverride) // if you know there won't be an owner by the time this is called, keep the owner you wanted to alert as an arg for this
		if (!(owner || ownerOverride) || HAS_FLAG(status, NOPOWER) || emagged)
			return
		var/mob/target_mob = ownerOverride.get_message_mob()
		var/nearest_camera = getNearestCamera()
		var/href
		if (nearest_camera)
			href = "<a href='byond://?src=\ref[ownerOverride];switchcamera=\ref[nearest_camera]'> <u>Jump to nearby camera</u></a>"
		else
			href = "<i>No cameras in view of display!</i>"
		boutput(target_mob, "- Alert: Contact lost with a Status Display in [get_area(src)].<b>[href]")

	proc/repairProcess(obj/item/W as obj, mob/user as mob)
		// oh boy a billion if statements, sorry

		if (isweldingtool(W))
			_health += 10
			_health = min(_health, _max_health)
			playsound(loc, "sound/items/Welder.ogg", 50, 1)
			boutput(user, "<span class='notice'>You weld some of the cracks in the screen together.</span>")

		else if (repairStep == 0 && isscrewingtool(W))
			repairStep ++
			playsound(loc, "sound/items/Screwdriver.ogg", 50, 1)
			boutput(user, "<span class='notice'>You unscrew the broken screen.</span>")
			repairHint = "pry out the broken glass"
			return
		else if (repairStep == 1 && ispryingtool(W))
			repairStep ++
			playsound(loc, "sound/items/Crowbar.ogg", 50, 1)
			boutput(user, "<span class='notice'>You pry the broken glass from the screen.</span>")
			repairHint = "cut out the burnt wires"
			var/obj/item/raw_material/shard/glass/G = new /obj/item/raw_material/shard/glass
			G.set_loc(loc)
		else if (repairStep == 2 && issnippingtool(W))
			repairStep ++
			playsound(loc, "sound/items/Wirecutter.ogg", 50, 1)
			boutput(user, "<span class='notice'>You cut and remove the burnt up wires from the display.</span>")
			repairHint = "replace the burnt wires"
		else if (repairStep == 3 && istype(W, /obj/item/cable_coil))
			if (!(W.amount >= 5))
				boutput(user, "<span class='notice'>You need at least 5 lengths of cable to repair the wires!</span>")
				return
			repairStep ++
			W.change_stack_amount(-5)
			playsound(loc, "sound/items/Deconstruct.ogg", 50, 1)
			boutput(user, "<span class='notice'>You replace the missing wires.</span>")
			repairHint = "replace the missing glass"
		else if (repairStep == 4 && istype(W, /obj/item/sheet))
			if (!(HAS_FLAG(W.material.material_flags, MATERIAL_CRYSTAL)))
				boutput(user, "<span class='notice'>You need some kind of glass or crystal sheet to replace the screen!</span>")
				return
			// only need 1 sheet, no check if we have enough
			repairStep ++
			W.change_stack_amount(-1)
			playsound(loc, "sound/items/Deconstruct.ogg", 50, 1)
			boutput(user, "<span class='notice'>You replace the missing screen.</span>")
			repairHint = "screw the screen back into the display"
		else if (repairStep == 5 && isscrewingtool(W))
			repairStep = 0
			repairHint = "unscrew the broken screen from the casing"
			setFixed()
			playsound(loc, "sound/items/Screwdriver.ogg", 50, 1)
			boutput(user, "<span class='notice'>You secure the screen back into the display, fully repairing it!</span>")

		else boutput(user, "<span class='notice'>You're not sure how to use [W] right now; it looks like you need to [repairHint].</span>")

		updateDamageOverlay()

	was_deconstructed_to_frame()
		src.setEquipmentState(OFF)
		..()

	was_built_from_frame()
		if(!HAS_FLAG(src.status, BROKEN) && src.owner && !emagged)
			src.setEquipmentState(ON)
		..()

	ex_act(severity)
		switch(severity)
			if(1.0)
				// only 3 levels to explosion strength? really?? fine, rng it is
				if (prob(30))
					src.destroy()
				else
					src.take_damage(rand(100,120))
			if(2.0)
				src.take_damage(rand(40,80))
			if(3.0)
				src.take_damage(rand(20,40))
		return

	blob_act(var/power)
		src.take_damage(rand(power * 0.5, power * 1.5))

	meteorhit()
		src.take_damage(rand(15,45))

	emp_act()
		src.take_damage(rand(15,30))
		if(!HAS_FLAG(src.status, NOPOWER) && prob(90))
			var/nameOverride = owner
			src.resetDisplay(TRUE) // BZZZZZZZZ
			src.sendAlert(nameOverride)

	emag_act(var/mob/user)
		if(src.emagged)
			boutput(user, "<span class='alert'>You emag the already emagged display. To your surprise, nothing happens.</span>")
			return
		if(!src.has_camera && !src.has_radio)
			boutput(user, "<span class='alert'>There's no equipment circuit on this display to break; nothing happened.</span>")
			return
		if(HAS_FLAG(src.status, BROKEN))
			boutput(user, "<span class='alert'>You can't emag a broken screen, dumbass!</span>")
			return
		src.emagged = TRUE
		playsound(src.loc, 'sound/machines/glitch4.ogg', 50, 2)
		setEquipmentState(OFF)
		if(src.has_camera && src.has_radio)
			src.visible_message("<span class='alert'>[user.name] shorts out [src]'s equipment circuit, permanently shutting down its radio and camera!</span>")
		else if(src.has_camera)
			src.visible_message("<span class='alert'>[user.name] shorts out [src]'s equipment circuit, permanently shutting down its camera!</span>")
		else if(src.has_radio)
			src.visible_message("<span class='alert'>[user.name] shorts out [src]'s equipment circuit, permanently shutting down its radio!</span>")

	demag(var/mob/user)
		if(!src.emagged)
			if(user)
				boutput(user, "<span class='notice'>This is already fixed, you don't need to do it again, dummy!")
			return 0
		if(user)
			user.show_text("You repair the damage to [src]'s equipment control circuit.", "blue")
		src.emagged = FALSE
		return 1

	get_desc()
		..()
		if (HAS_FLAG(status, NOPOWER))
			return
		if (src.message && !(HAS_FLAG(src.status, BROKEN)) && src.owner)
			. += "<br>[src.owner.name] says: \"[src.message]\""
		else if (HAS_FLAG(src.status, BROKEN))
			. += " It is broken.<br>It looks like you'll need to [repairHint]."

	attack_hand(mob/user as mob)
		if(isdead(user) && !isAI(user))
			boutput(user, "<span class='alert'>You're dead, knock that off!</span>")

		if(user.a_intent == INTENT_HARM)
			user.lastattacked = src
			attack_particle(user,src)
			hit_twitch(src)
			playsound(src.loc, 'sound/impact_sounds/Generic_Hit_1.ogg', 50, 1)
			var/damage = rand(1,4)
			if (user.is_hulk())
				damage *= 3
			if (iscarbon(user))
				var/mob/living/carbon/C = user
				if (C.bioHolder && C.bioHolder.HasEffect("strong"))
					damage *= 1.5
			if (damage >= 3)
				src.visible_message("<span class='alert'>[user.name] beats at [src]!</span>")
				src.take_damage(damage)
			else
				src.visible_message("<span class='alert'>[user.name] uselessly beats [src]!</span>")
			return

		switch(requestPresence(user))
			if(0)
				boutput(user, "<span class='alert'>Error: No connected AI detected.</span>")
			if(1)
				boutput(user, "<span class='alert'>You can't ask for the AI's attention through a broken screen, knucklehead!</span>")
			if(2)
				boutput(user, "<span class='alert'>You push the button to summon the AI, but it has no power, dumbass!</span>")
			if(3)
				var/countdown = 60 - ceil((world.time - lastPresenceRequest) / 10)
				boutput(user, "<span class='alert'>Unable to request attention; system on cooldown for [countdown] seconds!</span>")
			if(4)
				boutput(user, "<span class='alert'>[src.owner] has been notified of your request for their attention.</span>")


	attack_ai(mob/user as mob)
		if (!isAI(user))
			return
		var/mob/living/silicon/ai/A = user
		if (isAIeye(user))
			var/mob/dead/aieye/AE = user
			A = AE.mainframe
		if (owner == A) // lets open up the display's intercom!
			src.accessIntercom(user)
			return
		src.tryClaimDisplay(A, user, TRUE) //Captain said it's my turn on the status display

	attackby(obj/item/W as obj, mob/user as mob)
		if (isdead(user))
			return ..()

		if (!(user.a_intent == INTENT_HARM)) // repairing, scanning, and deconning checks
			if (HAS_FLAG(src.status, BROKEN) && (isscrewingtool(W) || ispryingtool(W) || issnippingtool(W) || istype(W, /obj/item/sheet) || istype(W, /obj/item/cable_coil)))
				repairProcess(W, user) // gotta replace everything, these are the things we need for it!
				return
			if (src._max_health > src._health && src._health > 0 && isweldingtool(W))
				repairProcess(W, user) // just need to fix it up (yes we are welding glass, fuck your logic this is simpler for everyone involved)
				return
			if (istype(W,/obj/item/electronics/scanner) || istype(W,/obj/item/deconstructor) || istype(W,/obj/item/device/detective_scanner) || istype(W,/obj/item/device/pda2) || istype(W,/obj/item/card/emag))
				return

		..() // also shamelessly ripped from manufacturer code
		user.lastattacked = src
		attack_particle(user,src)
		hit_twitch(src)
		playsound(src.loc, 'sound/impact_sounds/Generic_Hit_1.ogg', 50, 1)
		if (W.force)
			var/damage = W.force
			if (user.is_hulk())
				damage *= 3
			if (iscarbon(user))
				var/mob/living/carbon/C = user
				if (C.bioHolder && C.bioHolder.HasEffect("strong"))
					damage *= 1.5
			if (damage >= 5)
				src.take_damage(damage)


	updateHealth()
		return // this would call onDestroy(), we already have our own 0-health handling of things!!

	proc/speech_bubble(var/bubbleOverride) // /radio proc override, we want the speech bubble on top of the display so we can actually see it
		if (!bubbleOverride) // bubbleOverride has been added in conjunction with PR #6844. if that is denied, best to remove bubbleOverride and its handling
			bubbleOverride = image('icons/mob/mob.dmi', "speech")
		src.UpdateOverlays(bubbleOverride, "speech_bubble")
		SPAWN_DBG(1.5 SECONDS)
		src.UpdateOverlays(null, "speech_bubble")

	Topic(href, href_list)
		..()
		if(isdead(usr))
			boutput(src, "You cannot do this because you are dead!")
			return
		if((locate(href_list["accessIntercom"]) == src.owner) && isAI(usr)) // accessIntercom href should set "accessIntercom" = owner
			src.accessIntercom(usr)

	receive_silicon_hotkey(var/mob/user)
		..()

		if (!isAI(user))
			return
		if (!user.client.check_key(KEY_OPEN) && !user.client.check_key(KEY_BOLT) && !user.client.check_key(KEY_SHOCK))
			return
		if (!src.has_radio)
			boutput(user, "<span class='alert'>Error: No radio detected</span>")
			return
		if (HAS_FLAG(src.status, NOPOWER))
			boutput(user, "<span class='alert'><b>The display doesn't have any power!</b></span>")
			return
		if (HAS_FLAG(src.status, BROKEN))
			boutput(user, "<span class='alert'><b>That display is broken, you can't do anything to it!</b></span>")
			return
		if (user != owner?.get_inhabited_mob())
			boutput(user, "<span class='alert'>You don't own this display!</span>")
			return

		// We're putting this in the middle of the checks because if we're emagged then we can't disconnect due to the equipmentstate check
		if(user.client.check_key(KEY_SHOCK)) // space, disconnect
			boutput(user, "<span class='alert'>You disconnect the display from your mainframe!</span>")
			src.resetDisplay()
			src.manualConnectRequired = TRUE
			return

		if (!src.equipmentState)
			boutput(user, "<span class='alert'><b>The internal radio is disabled!</b></span>")
			return

		if (user.client.check_key(KEY_OPEN)) // ctrl, toggle mic
			var/broadcasting = src.internal_radio.broadcasting
			if (broadcasting)
				broadcasting = FALSE
				boutput(user, "<span class='notice'>You disable the display's microphone.</span>")
			else
				broadcasting = TRUE
				boutput(user, "<span class='notice'>You enable the display's microphone.</span>")
			src.internal_radio.broadcasting = broadcasting
			return

		if (user.client.check_key(KEY_BOLT)) // shift, toggle speaker
			var/listening = src.internal_radio.listening
			if (listening)
				listening = FALSE
				boutput(user, "<span class='notice'>You disable the display's speaker.</span>")
			else
				listening = TRUE
				boutput(user, "<span class='notice'>You enable the display's speaker.</span>")
			src.internal_radio.listening = listening
			src.updateStatusOverlays()


// Decided to leave the ability to request the AI's attention in these despite the radioless ones making this feature not nearly as useful as normal
/obj/machinery/ai_status_display/radio_only
	has_camera = FALSE
	icon_state = "ai_frame_r"
	desc = "This AI Display is equipped with an intercom for interfacing with the on-board AI."

/obj/machinery/ai_status_display/camera_only
	has_radio = FALSE
	icon_state = "ai_frame_c"
	desc = "This AI Display is equipped with a camera for the on-board AI to see you through."

/obj/machinery/ai_status_display/noequipment
	has_camera = FALSE
	has_radio = FALSE
	icon_state = "ai_frame"
	desc = "This AI Display will show the on-board AI's current status."


/obj/item/device/radio/intercom/AI/aiDisplay
	name = "AI Display Radio"
	desc = "If you're reading this, something has gone terribly wrong and you should file a bug report if you know how this somehow ended up being visible!"
	// listening & broadcasting are set in ai_status_display.New()
	var/obj/machinery/ai_status_display/display = null

	New()
		..()
		if (istype(src.loc, /obj/machinery/ai_status_display))
			display = src.loc
		else
			qdel(src)

	set_loc(newloc) // should only ever be inside a display
		if (!istype(newloc, /obj/machinery/ai_status_display))
			qdel(src)
		else ..()
	speech_bubble(var/bubbleOverride) // /radio proc override, we want the speech bubble on top of the display so we can actually see it
		if ((src.listening && src.wires & WIRE_RECEIVE))
			src.display.speech_bubble(bubbleOverride) //bubbleOverride should be removed if PR #6844 is denied

	ui_status(mob/user, datum/ui_state/state)
		if (istype(src.loc, /obj/machinery/ai_status_display))
			var/obj/machinery/ai_status_display/display = src.loc
			if (display.equipmentState)
				. = ..(user, state)
			else
				. = UI_CLOSE // if the display ain't on, that radio shouldn't be either; stop touching it

	ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
		..()
		if (action == "toggle-listening")
			display.updateStatusOverlays()
		return TRUE

	// uncomment showMapText() below if PR #6488 is merged. delete if it is denied.
	// intended to make AI displays capable of displaying maptext from AIs, just like intercoms in 6488
	/*showMapText(var/mob/R, var/mob/M, receive, msg, secure, real_name, lang_id, textLoc)
		..(R, M, receive, msg, secure, real_name, lang_id, src.display)*/

#undef ON // pretty sure this is the only way to really ensure a local define :I
#undef OFF
