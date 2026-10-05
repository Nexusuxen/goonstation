/* notes, remove before PRing
TODO RENAME ALL THIS COMSIG SHIT TO NOT COMSIG BECAUSE COMSIG IS THE WRONG TERM. FUCK.

*/

/**
 *	todo put documentation here
 */
/datum/sandwich_ingredient
	/// What item does this ingredient belong to?
	var/obj/item/parent = null
	/// What sandwich are we inside of?
	var/obj/item/reagent_containers/food/snacks/new_sandwich/sandwich_holder = null
	/// The pointer to our parent's reagents datum, assuming a player should ingest them on consumption
	var/datum/reagents/reagents = null
	/// The image to display for our layer in the sandwich
	var/image/sandwich_overlay = null
	/// How many pixels thick is this ingredient? (Controls how far up the overlay is offset)
	var/height = 1
	/// How many 'slots' does this ingredient support/occupy?
	var/width = 1
	/// How much of us remains, measured in the same units as bites_left
	var/fractional_bites_left = 0
	/// Pointer to the list in sandwich_holder.ingredients that we belong to
	var/list/occupied_layer = null

	/// If a user applies a valid sandwich ingredient to us, and this is TRUE, we form a new sandwich
	var/is_sandwich_base = FALSE
	/// Can we be put in the middle of a sandwich, regardless of if we're eligible for the base?
	var/is_sandwich_middle = TRUE
	/// If applied to an existing sandwich, nothing may be added atop it
	var/is_sandwich_top = FALSE

/datum/sandwich_ingredient/New(obj/item/source)
	. = ..()
	src.parent = source
	// our parent should set everything up for us
	SEND_SIGNAL(parent, COMSIG_SANDWICH_DATUM_CREATED, src)
	// ...but if not, we default to some things
	src.fallback()
	var/bites_left = src.get_bites_left()
	if(bites_left)
		src.fractional_bites_left = bites_left

/datum/sandwich_ingredient/proc/fallback()
	if(!src.sandwich_overlay)
		src.sandwich_overlay = image(parent.icon, null, parent.icon_state)

/datum/sandwich_ingredient/proc/get_appearance()
	return src.sandwich_overlay

/datum/sandwich_ingredient/proc/on_remove()
	if(src.fractional_bites_left < 1)
		if(prob(100 - (src.fractional_bites_left * 100)) || (src.fractional_bites_left < 0.05))
			qdel(parent)
	src.occupied_layer = null
	qdel(src)

/datum/sandwich_ingredient/proc/get_uneaten_bites_left()
	return

/datum/sandwich_ingredient/proc/get_bites_left()
	return

/datum/sandwich_ingredient/proc/get_heal_amt()
	return

// Because ingredients can be removed at any time, we have to go through each ingredient
// to see how much of it we're eating. It sucks but whatever. Thankfully several vars, such as heal_amt,
// are intended to be 1:1 with bites_left, meaning it's very easy to preemptively calculate those instead
/datum/sandwich_ingredient/proc/bitten_into(percentage_eaten, mob/consumer, do_reagents, obj/item/reagent_containers/food/snacks/bite/B)
	var/uneaten_bites_left = src.get_uneaten_bites_left()
	if(!uneaten_bites_left)
		return
	if(do_reagents && src.reagents?.total_volume)
		var/transfer_amount = src.reagents.maximum_volume * percentage_eaten
		src.reagents.trans_to(B, min(src.reagents.total_volume, transfer_amount), do_fluid_react = FALSE)
	src.fractional_bites_left -= uneaten_bites_left * percentage_eaten
	if(src.fractional_bites_left <= 0.01)
		src.sandwich_holder.remove_ingredient(null, src)

/datum/sandwich_ingredient/snacks
	var/obj/item/reagent_containers/food/snacks/snack_parent = null

/datum/sandwich_ingredient/snacks/New(obj/item/source)
	src.snack_parent = source
	src.reagents = source.reagents
	. = ..(source)

/datum/sandwich_ingredient/snacks/get_uneaten_bites_left()
	return snack_parent.uneaten_bites_left

/datum/sandwich_ingredient/snacks/get_bites_left()
	return snack_parent.bites_left

/datum/sandwich_ingredient/snacks/get_heal_amt()
	return snack_parent.heal_amt

/datum/sandwich_ingredient/snacks/on_remove()
	snack_parent.bites_left = floor(src.fractional_bites_left)
	if(snack_parent.bites_left == 0)
		snack_parent.bites_left = 1 // we wanna round down but not set it to 0
	. = ..() // since we'll risk deletion below 1 anyways

