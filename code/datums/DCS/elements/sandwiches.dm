//TODO NAMESPACE
var/alist/ingredient_details = alist()

// Handles the creation of custom sandwich items when circumstances are right, adding parent to the
// newly created sandwich as its base, and generating sandwich datums as appropriate.
// This element is to be added to anything that can be considered the bottom-most layer of a sandwich
// e.g bread slices

/datum/element/sandwich_base

/datum/element/sandwich_base/Attach(obj/item/target, sandwich_datum_type)
	. = ..()
	if(!istype(target))
		return DCS::ERR::ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_ATTACKBY, PROC_REF(attackby))

// todo make sure you can start a sandwich with nothing but just bread and a squirt of ketchup or something
/datum/element/sandwich_base/proc/attackby(obj/item/target, obj/item/W, mob/user)
	return SEND_SIGNAL(W, COMSIG_ADD_TO_SANDWICH, user, target)

/// Whether or not, upon clicking a sandwich item or atom with element/sandwich_base with us, we are to be added to it as an ingredient
/datum/element/sandwich_ingredient

/datum/element/sandwich_ingredient/Attach(obj/item/target, overlay, icon_state, datum_type)
	. = ..()
	if(!istype(target))
		return DCS::ERR::ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_ADD_TO_SANDWICH, PROC_REF(add_to_sandwich))
	if(icon_state)
		overlay = image('icons/obj/items/burgers3.dmi', null, icon_state)
	if(!datum_type)
		if(istype(target, /obj/item/reagent_containers/food/snacks))
			datum_type = /datum/sandwich_ingredient/snacks
		else
			datum_type = /datum/sandwich_ingredient
	// this is a bit of memory overhead, but it means faster lookups when building and rendering sandwiches
	ingredient_details["\ref[target]"] = list(
		"overlay" = overlay,
		"datum_type" = datum_type)

/// Attempts to add target to a specified sandwich or eligible sandwich base
/// Generates a sandwich datum for the target and, if add_to isn't a sandwich obj, generates a sandwich datum for it, too
/datum/element/sandwich_ingredient/proc/add_to_sandwich(obj/item/target, mob/user, obj/item/add_to)
	var/datum/sandwich_ingredient/target_ingredient = generate_sandwich_datum(target)
	var/obj/item/reagent_containers/food/snacks/new_sandwich/sandwich = null
	if(istype(add_to, /obj/item/reagent_containers/food/snacks/new_sandwich))
		sandwich = add_to
		sandwich.add_ingredient(user, target_ingredient)
		return 1
	var/datum/sandwich_ingredient/added_to_ingredient = generate_sandwich_datum(add_to)
	sandwich = new(user, list(added_to_ingredient, target_ingredient))

// TODO NAMESPACE
proc/generate_sandwich_datum(obj/item/target)
	var/list/details = ingredient_details["\ref[target]"]
	var/type = details["datum_type"]
	var/overlay = details["overlay"]
	return new type(target, overlay)
