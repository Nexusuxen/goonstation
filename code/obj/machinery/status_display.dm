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
	icon_state = "ai_frame"
	name = "\improper AI display"
	desc = "This AI Display is equipped with a camera and intercom for interfacing with the on-board AI."
	anchored = 1
	density = 0
	open_to_sound = 1
	mats = list("MET-1"=2, "CON-1"=6, "CRY-1"=6)
	deconstruct_flags = DECON_SCREWDRIVER | DECON_WRENCH | DECON_CROWBAR | DECON_WELDER | DECON_MULTITOOL | DECON_DESTRUCT

	machine_registry_idx = MACHINES_STATUSDISPLAYS
	var/is_on = FALSE //Distinct from being powered

	var/image/face_image = null //AI expression, optionally the entire screen for the red & BSOD faces
	var/image/back_image = null //The bit that gets coloured
	var/image/glow_image = null //glowy lines
	var/mob/living/silicon/ai/owner //Let's have AIs play tug-of-war with status screens

	//Variables of our current state, these get checked against variables in the AI to check if anything needs updating
	var/emotion = null //an icon state
	var/message = null //displays on examine
	var/face_color = null

	var/datum/light/screen_glow

	var/canRequestPresence = TRUE // anti-spam measures

	var/has_radio = TRUE // for if you want a radio-less display for whatever reason
	var/obj/item/device/radio/intercom/aiDisplay/internal_radio // intercom/aiDisplay should be located after/beneath /ai_status_display
	var/has_camera = TRUE // that face is looking back at you :)
	var/obj/machinery/camera/ai/internal_camera // gotta keep track of our camera, too

	_health = 100
	_max_health = 100
	var/repairStep = 0 // 7 steps (not including 0) to fix, detailed in repairProcess()
	var/repairHint = "unscrew the broken screen from the casing" // we wanna let the user know what they should do next to continue repairs. starts at first step
	var/lastAlert = 0 // when did we last tell the ai that we got hurt??

	New()
		..()
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

		internal_radio = new /obj/item/device/radio/intercom/aiDisplay
		internal_radio.set_loc(src)

		internal_camera = new /obj/machinery/camera/ai
		internal_camera.set_loc(src)

		_health = _max_health // for if you want to set max health in a map editor. for some reason.

	disposing()
		if (screen_glow)
			screen_glow.dispose()
		..()

	qdel()
		if (internal_radio)
			qdel(internal_radio)
		if (internal_camera)
			qdel(internal_camera)
		..()

	process()
		if (status & NOPOWER || status & BROKEN || !is_on || !owner)
			UpdateOverlays(null, "emotion_img")
			UpdateOverlays(null, "back_img")
			UpdateOverlays(null, "glow_img")
			screen_glow.disable()
			if (internal_camera)
				src.internal_camera.camera_status = 0
				src.internal_camera.updateCoverage()
			if (internal_radio)
				src.internal_radio.broadcasting = FALSE
				src.internal_radio.listening = FALSE
			return
		update()
		use_power(200)

	proc/update()
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
			// we don't turn the radio back on, gotta do it manually
		message = owner.status_message
		name = initial(name) + " ([owner.name])"

	proc/accessIntercom() // handles opening UI, BE SURE TO FIX THIS WITH THE TGUI ITERATION THANK YOU
		if (internal_radio.loc)
			internal_radio.ui_interact(owner.get_message_mob()) // get_message_mob to find the mainframe or eye the player is in
// it's like this since i plan to implement tgui visible to both humans and AIs so I might have to do weird complex stuff that I wanna have just in 1 place

	proc/requestPresence(mob/user as mob) // someone wants to ask for the AI to talk to them!
		// note: this is to be used AFTER we've already confirmed user is human and able to interact with the display and such

		// temp note: include a href so the ai can jump to the turf that the display is on
		// include a cooldown & have the display say it's on cooldown and for how much longer

		if(!src.owner) // who you gonna call?! no one.
			return 0
		if(!src.canRequestPresence)
			return 1
		// NOTE: WHEN TERMOS PR GETS MERGED, USE TEXT_TO_AI AND SOUND_TO_AI OR WHATEVER THEY WERE CALLED AND REPLACE THE FOLLOWING CODE WITH IT THANK U
		// need both an internal camera to jump to by default, and a backup thing to find an active camera in view if our internal camera is disabled
		var/mob/target_mob = owner.get_message_mob() // get the mainframe or eye that the player is currently in

		var/nearest_camera = src.getNearestCamera() // not actually nearest, just whatever the below loop finds first in nearby visible cameras
		var/href_camera // what's the text to render for the href camera link??
		if (!nearest_camera) // no cameras :(
			href_camera = "<i>No cameras in view of display!</i>"
		else
			href_camera = "<a href='byond://?src=\ref[owner];switchcamera=\ref[nearest_camera]'><u>Jump to nearby camera</u></a>"

		var/href_intercom // what's the text to render for the href intercom ui shortcut?
		if (internal_radio)
			href_intercom = "<a href='byond://?src=\ref[src];accessIntercom=\ref[owner]'><u>Access intercom</u>"

		var/href = "[href_camera] | [href_intercom]"
		boutput(target_mob, "--- Notice: [user.name] is requesting your attention via status display intercom!<br>- [href]")
		canRequestPresence = FALSE
		SPAWN_DBG(60 SECONDS) // should be set to a var for ease of adjustability
			canRequestPresence = TRUE
		return 2

	proc/getNearestCamera()
		var/obj/machinery/camera/nearest_camera = null
		if (internal_camera.camera_status) // do we have an active camera??
			nearest_camera = internal_camera
		else
			for (var/obj/machinery/camera/nearby_camera in view(src))
				if (!nearby_camera.camera_status)
					continue
				if (!(nearby_camera.network == "SS13" || nearby_camera.network == "Zeta" || nearby_camera.network == "Robots" || nearby_camera.network == "AI"))
					continue // if we can see through cameras that are none of the above then uh... someone fix that??
				nearest_camera = nearby_camera
				break
		return nearest_camera

	// ripped from manufacturer code because good god why dont we have some universal handling for this
	proc/take_damage(var/damage_amount = 0)
		if (!damage_amount || (src.status & BROKEN)) // can only trigger it breaking if it's not already broken
			return
		src._health -= damage_amount
		src._health = max(0,min(src._health,src._max_health))
		playsound(src.loc, 'sound/impact_sounds/Metal_Hit_Light_1.ogg', 50, 2)

		if (src._health == 0)
			src.visible_message("<span class='alert'><b>[src.name] breaks!</b></span>")
			playsound(src.loc, 'sound/impact_sounds/Machinery_Break_1.ogg', 50, 2)
			elecflash(src, radius=1, power=3, exclude_center = 0)
			src.status |= BROKEN
			src.owner = null
			name = "\improper broken [initial(name)]"
			return // no alerts for when we die :(
		else // displays can get concussions and memory loss too, so we better see if it'll forget its owner
			if ((src._health <= 70) && prob(damage_amount * 2) && owner) // coefficient of 2 is so that 5 damage has a 10% chance to trigger reset and 50 damage has a 100% chance
				src.owner = null
				src.visible_message("<span class='alert'><i>[src.name] loudly buzzes as its memory is reset!</i></span>")
				playsound(src.loc, 'sound/machines/buzz-sigh.ogg', 50, 2)
				name = initial(name)
				return // we forgot our owner, we don't know who to alert! lets just return.
				// process() will handle things from here to disable intercom & camera & etc

		if((src.lastAlert + 100 < world.time) && owner) // ow! lets check to see if we can tell our owner (if we have one) we got hurt!
			var/mob/target_mob = owner.get_message_mob()
			src.lastAlert = world.time + 100
			var/nearest_camera = getNearestCamera()
			var/href
			if (nearest_camera)
				href = "<a href='byond://?src=\ref[owner];switchcamera=\ref[nearest_camera]'><u>Jump to nearby camera</u></a>"
			else
				href = "<i>No cameras in view of display!</i>"
			boutput(target_mob, "- Alert: A Status Display in [get_area(src)] is taking damage.<b>[href]")

	proc/repairProcess(obj/item/W as obj, mob/user as mob)
		// oh boy a billion if statements, sorry
		if (src.repairStep == 0 && isscrewingtool(W))
			src.repairStep ++
			playsound(src.loc, "sound/items/Screwdriver.ogg", 50, 1)
			boutput(user, "<span class='notice'>You unscrew the broken screen.</span>")
			src.repairHint = "pry out the broken glass"
			return
		if (src.repairStep == 1 && ispryingtool(W))
			src.repairStep ++
			playsound(src.loc, "sound/items/Crowbar.ogg", 50, 1)
			boutput(user, "<span class='notice'>You pry the broken glass from the screen.</span>")
			src.repairHint = "cut out the burnt wires"
			var/obj/item/raw_material/shard/glass/G = new /obj/item/raw_material/shard/glass
			G.set_loc(src.loc)
			return
		if (src.repairStep == 2 && issnippingtool(W))
			src.repairStep ++
			playsound(src.loc, "sound/items/Wirecutter.ogg", 50, 1)
			boutput(user, "<span class='notice'>You cut and remove the burnt up wires from the display.</span>")
			src.repairHint = "replace the burnt wires"
			return
		if (src.repairStep == 3 && istype(W, /obj/item/cable_coil))
			if (!(W.amount >= 5))
				boutput(user, "<span class='notice'>You need at least 5 lengths of coil to repair the wires!</span>")
				return
			src.repairStep ++
			W.change_stack_amount(-5)
			playsound(src.loc, "sound/items/Deconstruct.ogg", 50, 1)
			boutput(user, "<span class='notice'>You replace the missing wires.</span>")
			src.repairHint = "replace the missing glass"
			return
		if (src.repairStep == 4 && istype(W, /obj/item/sheet))
			if (!(W.material.material_flags & MATERIAL_CRYSTAL))
				boutput(user, "<span class='notice'>You need some kind of glass or crystal sheet to replace the screen!</span>")
				return
			// only need 1 sheet, no check if we have enough
			src.repairStep ++
			W.change_stack_amount(-1)
			playsound(src.loc, "sound/items/Deconstruct.ogg", 50, 1)
			boutput(user, "<span class='notice'>You replace the missing screen.</span>")
			src.repairHint = "screw the screen back into the display"
			return
		if (src.repairStep == 5 && isscrewingtool(W))
			src.repairStep = 0
			src.repairHint = "unscrew the broken screen from the casing"
			src.status = 0 // no idea how bit stuff works please yell at nex if this is stupid thank u
			src._health = 100
			playsound(src.loc, "sound/items/Screwdriver.ogg", 50, 1)
			boutput(user, "<span class='notice'>You secure the screen back into the display, fully repairing it!</span>")
			return
		boutput(user, "<span class='notice'>You're not sure how to use [W] right now; it looks like you need to [repairHint].</span>")

	ex_act(severity)
		switch(severity)
			if(1.0)
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
		src.take_damage(rand(5,10))
		//if (internal_radio)
		//	src.internal_radio.emp_act()
		//if (internal_camera && internal_camera.camera_status)
		//	src.internal_camera.emp_act()
		//see if emp goes through into the display's children; if not, we'll have to emp_act() the things ourselves

	get_desc()
		..()
		if (status & NOPOWER)
			return
		if (src.message && !(src.status & BROKEN))
			. += "<br>[owner.name] says: \"[src.message]\""
		else if (src.status & BROKEN)
			. += "<br>[src.name] is broken! It looks like you'll need to [repairHint]."

	attack_hand(mob/user as mob)
		if(!isdead(user) && !isAI(user))
			switch(requestPresence(user))
				if(0)
					boutput(user, "<span class='alert'>Error: No connected AI detected.</span>")
				if(1)
					boutput(user, "<span class='alert'>Unable to request attention; system on cooldown.</span>")
				if(2)
					boutput(user, "<span class='alert'>[src.owner] has been notified of your request for their attention.</span>")
			return
		boutput(user, "<span class='alert'>You're dead, knock that off!</span>")

	attack_ai(mob/user as mob)
		if (!isAI(user))
			return
		var/mob/living/silicon/ai/A = user
		if (isAIeye(user))
			var/mob/dead/aieye/AE = user
			A = AE.mainframe
		if (src.status & BROKEN)
			boutput(user, "<span class='alert'><i>You can't tune a broken display to yourself!</i></span>")
			return
		if (owner == A) // lets open up the display's intercom!
			src.accessIntercom(A)
			return
		boutput(user, "<span class='notice'>You tune the display to your core.</span>") //Captain said it's my turn on the status display
		owner = A
		is_on = TRUE
		if (!(status & NOPOWER))
			update()

/* NOTES
STEPS2FIX SCREEN:
1) Screwdriver
2) Crowbar
3) Wirecutters
4) Wires
5) Glass
6) Screwdriver
*/

	attackby(obj/item/W as obj, mob/user as mob)
		if (isdead(user))
			return ..()
		if (src.status & BROKEN && (isscrewingtool(W) || ispryingtool(W) || issnippingtool(W) || istype(W, /obj/item/sheet) || istype(W, /obj/item/cable_coil)))
			repairProcess(W, user)
			return
		if (istype(W,/obj/item/electronics/scanner) || istype(W,/obj/item/deconstructor))
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

	Topic(href, href_list)
		..()
		if(isdead(usr))
			boutput(src, "You cannot access the intercom because you are dead!")
			return
		if((locate(href_list["accessIntercom"]) == src.owner) && isAI(usr)) // accessIntercom href should set "accessIntercom" = owner
			src.accessIntercom(usr)


/obj/item/device/radio/intercom/aiDisplay
	name = "AI Display Radio"
	desc = "If you're reading this, something has gone terribly wrong and you should file a bug report if you know how this somehow ended up being visible!"
	frequency = R_FREQ_INTERCOM_AI
	set_loc(newloc) // should only ever be inside a display
		if (!istype(newloc, /obj/machinery/ai_status_display))
			qdel(src)
		else ..()
	speech_bubble() // /radio proc override, we want the speech bubble on top of the display so we can actually see it
		if ((src.listening && src.wires & WIRE_RECEIVE))
			src.loc.UpdateOverlays(speech_bubble, "speech_bubble")
			SPAWN_DBG(1.5 SECONDS)
				src.loc.UpdateOverlays(null, "speech_bubble")
