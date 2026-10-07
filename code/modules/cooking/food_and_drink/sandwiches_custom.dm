// For the time being, these will be referred to as 'new_sandwich', until all sandwiches are made to
// exist in the form of these new sandwiches.
// The nomenclature of 'sandwich' is up for debate here, considering a sandwich
// could be nothing more than a slice of bread with a single piece of lettuce on top.

/*
== STATUS BASED ON LATEST PUSH ==
Sandwiches physically act as you'd expect. Gameplay features that seem to be working correctly:
1.  Assembling sandwich-compatible items to form sandwiches
2.  Removing items from sandwiches, starting from the topmost layer
3.  Eating sandwiches to regain health
4.  The amount of bites a sandwich takes to eat scales with bites_left of ingredients
5.  Removing partially-eaten ingredients will have them actually be partially eaten
6.  Reagents transfer from ingredients into each bite
7.  Reagents can be applied as condiments to each layer which also transfer into each bite
8.  The amount of space a bite from a sandwich occupies in your stomach is dependent on its ingredients
9.  The quality of a sandwich is the average of its ingredients (unless any have a quality below 0, wherein it becomes the sum of all negative qualities)
10. Sandwiches inherit their effects from their ingredients

-- UNIMPLEMENTED FEATURES --
none, all major features seemingly added :)

== NEX TODOS ==
- sandwich-specific sprites for the overlays
- add sandwich ingredient element to appropriate food items
- fix burgers.dmi (weird namings and aberrant sprites)
- examine text to display ingredients
- general performance pass
- eliminate all todos that don't have entries here in this list
- when a sandwich spawns, it should have the same x/y offsets as the base ingredient it came from
- "you manage to salvage [x] from the sandwich!" message when an ingredient with <1 bites left is removed,
  and "too much of [x] has been eaten, there's nothing to salvage!" if it fails with <1 bites left
- look at how reagents are transferred from ingredients to consumer on_bite(). looks like it may be a little overtuned??
  also make sure, if it's the final bite, that all reagents are transferred regardless of how much is left

shit 2 test more rigorously:
- reagent mechanics

STRAY TODOS COMPLETED:


DONES
- "create or add to sandwich" proc
- contingency for if an ingredient gets randomly deleted. just make the sandwich fuckin burst its ingredients out, screw it
- or just proc for removing a specific ingredient safely
- basic reagent functionality. needs more work and testing.
- Applying reagents to layers as condiments
- reagents left on removed layers spill onto floor
- Transferring reagents to user upon consumption,
 including: Reagents in each ingredient, src.ingredients[n]["reagents"]
 The exact behavior of src.reagents has yet to be determined, but will likely be used for reagent consumption
- food quality
- fill_amt
- food effects
- Transferring of effects, quality, and fill_amt to each bite of the sandwich
- reagent smear overlay
- Application of bite masks on removed ingredients and upon sandwich assembly
- Make it so that sandwiches don't take 50 years to eat (scale bites_left somehow)
- what if someone eats it all in one bite with matter eater? FUCK
  nothing done. turns out matter eater only takes 1 bite :D
- deletion handling. some deletes should just delete all ingredients and reagents too, others should
  cause items and reagents to spill out

ASSORTED IMPORTANT NOTES THAT SHOULD BE DOCUMENTED
- Every layer should *always* have an ingredient datum in it. The code works on this assumption.
  If there's *just* a reagent datum left the layer should still be deleted and the reagents disposed of somehow.
- The "reagents" slot being empty is not strictly necessary, it just saves us from having to constantly make
  new ones for each layer

DON'T FORGET TO MENTION THESE IN THE PR DESCRIPTION
- changes to food_and_drink.dm (apply_bite_mask() proc, adding the bite/B to on_bite() args, tweaking on_bite())

*/
/// Somewhat abstract food item that includes most things sandwich and sandwich-adjacent
/obj/item/reagent_containers/food/snacks/new_sandwich
	name = "incomplete sandwich"
	var/custom_name = ""
	desc = "A prospective sandwich, awaiting the addition of (hopefully) delicious layers."
	bites_left = 0 // Prevents bite masks from being applied from on_bite(), so we can use our own special ones
	flags = OPENCONTAINER | TABLEPASS | OPENCONTAINER | TGUI_INTERACTIVE
	appearance_flags = KEEP_TOGETHER

	/// Matrix of our ingredients as their sandwich datums. See below for examples.
	/// Note that if an ingredient occupies multiple slots, its reference is stored in each slot.
	var/list/ingredients = null
/*  EXAMPLES
	Submarine sandwich:
	ingredients = list(
	list("reagents" = reagents, "ingredients" = list(sub base, sub base, sub base)),
	list("reagents" = null, "ingredients" = list(lettuce1, lettuce2, lettuce3)),
	list("reagents" = null, "ingredients" = list(bacon1, onion, bacon2)),
	list("reagents" = reagents, "ingredients" = list(tomato1, tomato2, cheese1)),
	list("reagents" = reagents, "ingredients" = list(cheese2, cheese3, tomato3)),
	list("reagents" = null, "ingredients" = list(sub top, sub top, sub top))
	)
	Burger:
	ingredients = list(
	list("reagents" = reagents, "ingredients" = list(bottom bun)),
	list("reagents" = reagents, "ingredients" = list(lettuce)),
	list("reagents" = reagents, "ingredients" = list(patty)),
	list("reagents" = reagents, "ingredients" = list(cheese)),
	list("reagents" = reagents, "ingredients" = list(top bun))
	)
*/
	/// Stores each unique ingredient datum, as src.ingredients can contain duplicates and is more unwieldy
	var/list/unique_ingredients = null
	/// How tall is this sandwich?
	var/height = 0
	/// How many ingredients can fit per layer?
	var/width = 1
	var/max_height = 20 // Arbitrary, felt like a reasonable number

	/// From 0-1, what % of each ingredient should we remove per bite?
	var/percent_eaten_per_bite = 0

	var/list/datum/contextAction/sandwichContextActions

	/// Instead of storing reagents, this is a pointer to the topmost exposed reagent layer in the sandwich
	reagents = null


/obj/item/reagent_containers/food/snacks/new_sandwich/New(mob/user, list/ingredient_list)
	. = ..()
	src.ingredients = new
	src.unique_ingredients = new
	src.setup(user, ingredient_list)

/// Internal proc to generatee the sandwich with ingredient_list
/// ingredient_list's contents must be either sandwich or reagent datums
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/setup(mob/user, list/ingredient_list)
	if(length(ingredient_list) <= 1) // we need at least 2 ingredients to be considered a sandwich
		CRASH()
	for(var/ingredient in ingredient_list)
		if(istype(ingredient, /datum/reagents))
			var/datum/reagents/reagent_ingredient = ingredient
			reagent_ingredient.trans_to(src, reagent_ingredient.total_volume)
		else
			src.add_ingredient(user, ingredient)
	src.render()


/// We use src.reagents as a placeholder for the topmost layer's reagents, sticking it into said layer when actually modified
/obj/item/reagent_containers/food/snacks/new_sandwich/on_reagent_change(add)
	. = ..()
	if(!add)
		return
	var/list/topmost_layer = src.get_topmost_layer()
	topmost_layer["reagents"] = src.reagents
	src.render() //todo remove, added so newly added condiments would render immediately

/// Adds a ingredient reagent to the sandwich, moving its respective atom (if applicable) to inside the sandwich
/// Always places on top, returning TRUE if successful and FALSE otherwise
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/add_ingredient(mob/user, datum/sandwich_ingredient/ingredient)
	var/list/current_layer = null
	if(!length(src.ingredients)) // this is our first ingredient!
		src.width = ingredient.width
		current_layer = src.add_layer()
		if(ismob(ingredient.parent.loc))
			var/mob/mob_holder = ingredient.parent.loc
			mob_holder.drop_item(ingredient.parent)
			mob_holder.put_in_hand_or_drop(src)
		else
			src.set_loc(ingredient.parent.loc)
	else
		current_layer = src.get_topmost_layer()
	if(!length(src.get_open_indexes()))
		current_layer = src.add_layer()

	var/can_fit = src.can_this_fit_on_top(ingredient)
	if(istext(can_fit))
		boutput(user, SPAN_ALERT(can_fit))
		return FALSE
	var/list/open_indexes = can_fit
	for(var/index in open_indexes)
		current_layer["ingredients"][index] = ingredient
	ingredient.occupied_layer = current_layer
	src.unique_ingredients += ingredient
	if(user)
		user.drop_item(ingredient.parent)
	ingredient.parent.set_loc(src)
	ingredient.sandwich_holder = src
	boutput(user, SPAN_NOTICE("You add [ingredient.parent] to [src]."))
	src.simulate()
	src.render()
	src.generate_name()
	src.update_context()
	return TRUE

/// Adds a new layer to the sandwich with an empty reagents datum and appropriately sized ingredients list
/// Returns the new layer
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/add_layer()
	if(length(src.ingredients))
		var/list/previous_layer = src.get_topmost_layer()
		previous_layer["reagents"] = src.reagents // just in case this hasn't been done yet for some reason
		src.new_reagents_datum()
	var/list/ingredient_list[src.width]
	var/list/new_layer = list("reagents" = src.reagents, "ingredients" = ingredient_list)
	src.ingredients += list(new_layer) // the only way to add the list without just combining them i could think of
	return new_layer

/// Returns the list reference for the current topmost layer of the sandwich
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/get_topmost_layer(var/ingredients_only)
	RETURN_TYPE(/list)
	if(ingredients_only)
		return src.ingredients[length(src.ingredients)]["ingredients"]
	return src.ingredients[length(src.ingredients)]

/// If there's space for the ingredient (e.g no top bun, ingredient not too wide for current layer), returns a list of indexes it should go into
/// Otherwise, returns a message saying why the ingredient can't fit, to be given to a user
/// Assumes the topmost layer has at least one open slot already
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/can_this_fit_on_top(datum/sandwich_ingredient/ingredient)
	if(ingredient.width > src.width)
		return "[ingredient.parent] is too wide to fit on [src]!"
	if((src.height + ingredient.height) > src.max_height)
		return "[src] is already too thick to support [ingredient.parent]!"
	// we need to search through the layer for the first series of open slots that will fit our ingredient
	var/open_width = 0
	var/list/open_slots = list()
	var/list/topmost_ingredients = src.get_topmost_layer(ingredients_only = TRUE)
	for(var/index = 1, index <= src.width, index++)
		if(!isnull(topmost_ingredients[index]))
			open_width = 0
			for(var/entry in open_slots)
				open_slots -= entry
			continue
		open_width++
		open_slots += index
		if(open_width == ingredient.width)
			break
	if(length(open_slots))
		return open_slots
	else
		return "You need more space on the topmost layer to add [ingredient.parent]!"

/// Returns a list of "ingredients" indexes that are open (null) on the current topmost layer
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/get_open_indexes()
	RETURN_TYPE(/list)
	var/list/return_list = list()
	var/list/topmost_layer = src.get_topmost_layer(ingredients_only = TRUE)
	for(var/index = 1, index <= length(topmost_layer), index++)
		if(isnull(topmost_layer[index]))
			return_list += index
	return return_list

// placeholder, todo actual names
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/generate_name()
	src.name = "test sandwich of [TIME]"

// How many pixels wide is each ingredient?
#define SANDWICH_BASE_WIDTH 8

// todo make this less ass. considerations:
// - option to remove specific ingredient's layer. maybe generate an id for it using \ref or w/e
// - option to not remove overlays when we're just adding one new image
// todo custom sandwich overlays using the very pretty sprites erinexx made... like 3 years ago oops
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/render()
	src.ClearAllOverlays()
	// we need to generate the whole thing then center it
	// go through it one layer at a time and place the ingredients
	var/x_index = 0
	var/height_offset = 0
	var/layer_index = 1
	for(var/list/layer in src.ingredients)
		for(var/datum/sandwich_ingredient/ingredient in layer["ingredients"])
			//todo account for width and then offset accordingly. somehow.
			var/image/to_display = src.get_overlay_image(ingredient)
			to_display.pixel_x = SANDWICH_BASE_WIDTH * x_index
			to_display.pixel_y = height_offset
			x_index += ingredient.width
			src.AddOverlays(to_display, "\ref[ingredient]")
		if(src.has_condiments(layer))
			var/image/to_display = src.get_overlay_image(layer["reagents"])
			//todo wider sandwich handling
			to_display.pixel_y = height_offset
			src.AddOverlays(to_display, "Layer [layer_index] Reagents")
		height_offset += 2 //todo make this based on ingredient height
		x_index = 0
		layer_index++

//todo performance improvements. a little silly to keep rebuilding this when it's usually gonna not change
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/update_context()
	src.sandwichContextActions ||= list()
	src.sandwichContextActions.Cut() // just gotta clear it is all, no need to make a new one
	var/remove = FALSE
	if(length(src.ingredients) > 1)
		src.sandwichContextActions += new /datum/contextAction/sandwich/remove
		remove = TRUE
	if(remove)
		sandwichContextActions += new /datum/contextAction/sandwich/pickup

/// Attempts to remove the topmost (most recently added) ingredient and, if applicable, place it in a user's hand
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/remove_from_top(mob/user)
	var/list/topmost_layer = src.get_topmost_layer(ingredients_only = TRUE)
	var/datum/sandwich_ingredient/target = null
	for(var/index = length(topmost_layer), index > 0, index--)
		if(isnull(topmost_layer[index]))
			continue
		target = topmost_layer[index]
		src.remove_ingredient(user, target)
	if(!target)
		src.remove_layer(topmost_layer)
		CRASH("[src] somehow has an empty top layer which was never deleted! Removing [topmost_layer] now to try and fix this.")

/// Removes a specific ingredient from somewhere in the sandwich
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/remove_ingredient(mob/user, datum/sandwich_ingredient/target, forceful = FALSE)
	var/list/layer_ingredients = target.occupied_layer["ingredients"]
	for(var/index = 1, index <= length(layer_ingredients), index++)
		if(layer_ingredients[index] != target)
			continue
		layer_ingredients[index] = null
	// todo take reagents and either try splashing them onto the removed ingredient or splashing them
	// onto the floor. mind the possibility of wide sandwiches. maybe remove 1/x reagents, x being width

	var/anything_left = FALSE
	for(var/datum/sandwich_ingredient/remainder in layer_ingredients)
		anything_left = TRUE
		break
	if(!anything_left)
		src.remove_layer(target.occupied_layer, forceful)
	src.unique_ingredients.Remove(target)
	var/obj/item/target_parent = target.parent
	target.on_remove()

	SPAWN(0 SECONDS) // we wait a sec to let any updates finish first
		if(!src.one_layer_left_check())
			src.simulate() // todo make more performant
			src.render() // ditto

	if(target_parent.qdeled)
		return
	else if(user)
		user.put_in_hand_or_drop(target_parent)
	else
		src.spill_ingredient_item(target_parent, forceful)

/// Checks if all we are is the bottom layer, and deletes us (spitting out that final ingredient) if so
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/one_layer_left_check()
	// just the base ingredient left. if there's no reagents on it let's just stop pretending we're a sandwich anymore
	if(length(src.ingredients) == 1)
		var/list/topmost_layer = src.get_topmost_layer()
		if(src.has_condiments(topmost_layer))
			return FALSE // i dont care if you dont consider a single slice of bread with ketchup on it a "sandwich"
			// though if we get the ability to coat items in reagents, we should just do that here and delete src
		var/datum/sandwich_ingredient/target = topmost_layer["ingredients"][1] // safe to assume the first index will always work
		src.unique_ingredients.Remove(target)
		if(ismob(src.loc))
			var/mob/user = src.loc
			user.drop_item(src)
			user.put_in_hand_or_drop(target.parent)
		else
			target.parent.set_loc(src.loc)
		target.on_remove()
		qdel(src)
		return TRUE

/* To simulate a sandwich, we cheat a bit. Instead of taking a bite out of any of our ingredients,
 we instead see what *would* have happened if we bit into each ingredient, and add that to our
 total effects - and distribute those effects across each bite wherever possible
 Then we just make sure that, if an ingredient is removed, it has bites taken out of it and possibly
 outright destroyed depending on how little is left
*/

/*
 Improvement ideas:
- Only simulate once between the most recent edit and when we're being eaten
- Save the bites_left_sum and other variables so removed ingredients can remove them upon removal,
  eliminating the need to reiterate through the ingredients
*/

/// Goes through all ingredients to determine several consumption-related variables, such as fill_amt
/// Any changes to how food works will likely need to modify this proc, as well as on_bite()
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/simulate()
	var/bites_left_sum = 0
	var/uneaten_bites_left_sum = 0
	var/heal_amt_sum = 0
	var/quality_sum = 0
	var/how_yucky = 0
	var/fill_amt_sum = 0

	for(var/datum/sandwich_ingredient/ingredient in src.unique_ingredients)
		uneaten_bites_left_sum += ingredient.get_uneaten_bites_left()
		bites_left_sum += ingredient.get_bites_left()
		heal_amt_sum += ingredient.get_heal_amt()
		var/food_quality = ingredient.get_quality()
		if(food_quality < 0) // rancid meat in your otherwise delicious sandwich is still gonna get you sick
			how_yucky += food_quality // could instead set this to the lowest ingredient quality but this is simpler
		else
			quality_sum += food_quality
		fill_amt_sum += ingredient.get_fill_amt()
		// there's not a good way to dynamically scale the duration of effects
		// so i guess we could theoretically extend any effect!
		src.food_effects |= ingredient.get_food_effects()

	if(!bites_left_sum)
		qdel(src) //todo find better way to ensure sandwich removed upon fully consumed
		return

	// food code is inherently inconsistent, hence the inconsistencies here
	// certain other factors, namely reagents, are handled on_bite()
	src.uneaten_bites_left = scale_bites(uneaten_bites_left_sum)
	src.bites_left = scale_bites(bites_left_sum)
	src.percent_eaten_per_bite = 1 / src.uneaten_bites_left
	src.heal_amt = heal_amt_sum / src.bites_left
	if(how_yucky)
		src.quality = how_yucky
	else
		src.quality = quality_sum / length(src.unique_ingredients)
	src.fill_amt = fill_amt_sum

/// Arbitrary scaling to make sandwiches feel like they take a reasonable amount of time to eat
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/scale_bites(to_scale)
	return 1 + ceil(to_scale / 2)

/// We generate a /food/snacks/bite object to pass to ..() so it can behave as though we've bitten into every ingredient
/// Any changes to how food works will likely need to modify this proc, as well as simulate()
/obj/item/reagent_containers/food/snacks/new_sandwich/on_bite(mob/consumer, mob/feeder, ethereal_eater, obj/item/reagent_containers/food/snacks/bite/B)
	B ||= new
	B.reagents.maximum_volume = 1000 // setting to an arbitrarily high number so we can fit everything
	B.heal_amt = src.heal_amt
	B.quality = src.quality
	B.fill_amt = src.fill_amt / src.uneaten_bites_left
	var/do_reagents = FALSE
	if(!ethereal_eater && isliving(consumer))
		do_reagents = TRUE
	// I'm not a fan of iterating through every ingredient, but it's the only realistic solution I've found
	for(var/datum/sandwich_ingredient/ingredient in src.unique_ingredients)
		ingredient.bitten_into(src.percent_eaten_per_bite, consumer, do_reagents, B)
	if(do_reagents)
		for(var/list/layer in src.ingredients)
			if(!src.has_condiments(layer))
				continue
			var/datum/reagents/layer_reagents = layer["reagents"]
			var/transfer_amount = 0
			if(bites_left != 1) // making sure we get it all on the last bite! (otherwise it might spill)
				transfer_amount = layer_reagents.total_volume
			else
				transfer_amount = layer_reagents.maximum_volume / src.uneaten_bites_left
			layer_reagents.trans_to(B, min(layer_reagents.total_volume, transfer_amount), do_fluid_react = FALSE)
	. = ..(consumer, feeder, ethereal_eater, B)

/obj/item/reagent_containers/food/snacks/new_sandwich/attackby(obj/item/W, mob/user)
	if(SEND_SIGNAL(W, COMSIG_ADD_TO_SANDWICH, user, src))
		return
	. = ..()

/obj/item/reagent_containers/food/snacks/new_sandwich/attack_hand(mob/user)
	//if (src.stored)
	//	return ..()
	// shortcuts for quick pickup/removal
	switch(user.a_intent)
		if(INTENT_DISARM)
			src.remove_from_top(user)
			return
		if(INTENT_GRAB)
			if(src.loc == user)
				user.u_equip(src)
			user.put_in_hand_or_drop(src)
			return
	if(length(sandwichContextActions))
		user.showContextActions(sandwichContextActions, src)
	else
		..()

/// Removes the designated layer from the sandwich, dropping any ingredients and reagents onto the floor
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/remove_layer(list/layer_to_remove, forceful = FALSE)
	var/do_render = FALSE
	if(!src.ingredients.Find(layer_to_remove, length(src.ingredients)))
		do_render = TRUE // whole sandwich has gotta visually shift down
	for(var/datum/sandwich_ingredient/ingredient in layer_to_remove["ingredients"])
		src.remove_ingredient(null, ingredient)
	src.spill_reagents(layer_to_remove, forceful)
	src.ingredients.Remove(list(layer_to_remove))
	if(do_render)
		src.render()

/obj/item/reagent_containers/food/snacks/new_sandwich/proc/get_overlay_image(datum/target)
	if(istype(target, /datum/sandwich_ingredient))
		var/datum/sandwich_ingredient/ingredient = target
		return ingredient.get_appearance()
	// safe to assume target is a reagents datum
	var/datum/reagents/target_reagents = target
	if(!target_reagents.total_volume)
		return null
	var/image/to_return = image('icons/obj/items/burgers.dmi', null, "overlay_chem")
	to_return.color = target_reagents.get_average_color().to_rgba()
	return to_return

/// Attempts to qdel all ingredients, their datums, and any condiment reagents
/obj/item/reagent_containers/food/snacks/new_sandwich/disposing()
	for(var/list/layer in src.ingredients)
		qdel(layer["reagents"])
		for(var/datum/sandwich_ingredient/ingredient in layer["ingredients"])
			qdel(ingredient.parent)
			qdel(ingredient)
	. = ..()

/// Spills all the ingredients and condiments onto the floor, then qdels src
/// Call with forceful to throw ingredients in a 3x3 area around src
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/topple_sandwich(forceful = FALSE)
	for(var/list/layer in src.ingredients)
		src.spill_reagents(layer, forceful)
		for(var/datum/sandwich_ingredient/ingredient in layer["ingredients"])
			src.remove_ingredient(target = ingredient, forceful = forceful)
	qdel(src)

/// Attempts to spill the specified item onto the floor from the sandwich.
/// Does NOT modify src.ingredients. Consider calling remove_ingredient(spill = TRUE)
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/spill_ingredient_item(obj/item/to_spill, forceful = FALSE)
	if(to_spill.qdeled)
		return
	to_spill.set_loc(get_turf(src))
	if(forceful)
		var/atom/target = src.find_a_target()
		to_spill.throw_at(target, 10, 2)

/// Attempts to spill the specified layer's condiments reagent, deleting it in the process
/// Do forceful if you want the reagents to apply to any tile or mob in a 3x3 area
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/spill_reagents(list/layer, forceful = FALSE)
	if(has_condiments(layer))
		var/datum/reagents/condiments = layer["reagents"]
		var/atom/target = null
		if(forceful)
			target = src.find_a_target()
		target ||= get_turf(src)
		condiments.reaction(target)
		condiments.clear_reagents()
	layer["reagents"] = null
	qdel(layer["reagents"])

/// Attempts to find a suitable target (a turf or mob) within a 3x3 area of the sandwich
/// If it fails after a few attempts, it just returns the turf src occupies
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/find_a_target()
	var/atom/possible_target = null
	var/atom/target = null
	var/list/in_view = view(1, get_turf(src))
	for(var/tries = 1, tries <= 3, tries++)
		possible_target = pick(in_view)
		if(!ismob(possible_target)) // it's funniest to splatter onto mobs or the floor
			possible_target = get_turf(possible_target)
		if(in_interact_range(possible_target, src))
			target = possible_target
			break
	target ||= get_turf(src)
	return target

//todo move this define
#define SANDWICH_BASE_REAGENT_CAPACITY 10 // Seems like a reasonable amount
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/new_reagents_datum()
	src.reagents = new
	src.reagents.maximum_volume = SANDWICH_BASE_REAGENT_CAPACITY * src.width
	src.reagents.my_atom = src
#undef SANDWICH_BASE_REAGENT_CAPACITY

/// Returns TRUE if the layer has a non-empty reagents datum in "reagents"
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/has_condiments(list/layer)
	var/datum/reagents/condiments = layer["reagents"]
	if(!istype(condiments))
		return FALSE
	if(condiments.total_volume)
		return TRUE

// REVIEW NOTE: This does not have to be reviewed, as it can be added in a future PR. This has been included
// to aid in testing, and if it is not reviewed it will be removed prior to merging
/obj/spawner/sandwich
	desc = "Tries to spawn a sandwich with the specified ingredients"
	/// List of item types and reagent lists to generate ingredients
	var/list/starting_ingredients = null

/obj/spawner/sandwich/New()
	. = ..()
	if(!src.starting_ingredients)
		CRASH()
	var/list/ingredients_list = list()
	var/is_first_item = TRUE
	for(var/entry in src.starting_ingredients)
		if(islist(entry))
			if(is_first_item)
				CRASH()
			var/list/reagent_list = entry
			var/datum/reagents/reagents = new
			reagents.maximum_volume = 100 //sure whatever
			for(var/reagent in reagent_list)
				var/volume = reagent_list[reagent]
				volume ||= 10
				reagents.add_reagent(reagent, volume)
			ingredients_list += reagents
			continue
		var/obj/item/ingredient = new entry
		if(is_first_item)
			ingredient.AddElement(/datum/element/sandwich_base)
			ingredient.set_loc(get_turf(src))
			is_first_item = FALSE
		ingredient.AddElement(/datum/element/sandwich_ingredient)
		var/datum/sandwich_ingredient/ingredient_datum = generate_sandwich_datum(ingredient)
		ingredients_list += ingredient_datum
	new /obj/item/reagent_containers/food/snacks/new_sandwich(null, ingredients_list)
	qdel(src)

/obj/spawner/sandwich/blt
	starting_ingredients = list(
		/obj/item/reagent_containers/food/snacks/breadslice,
		list("mustard" = 10),
		/obj/item/reagent_containers/food/snacks/ingredient/meat/bacon,
		/obj/item/reagent_containers/food/snacks/plant/lettuce,
		/obj/item/reagent_containers/food/snacks/ingredient/tomatoslice,
		/obj/item/reagent_containers/food/snacks/breadslice
	)
