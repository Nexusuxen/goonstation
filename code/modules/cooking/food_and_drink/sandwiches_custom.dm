// For the time being, these will be referred to as 'new_sandwich', until all sandwiches are made to
// exist in the form of these new sandwiches.
/*
== STATUS BASED ON LATEST PUSH ==
Sandwiches physically act as you'd expect. Gameplay features that seem to be working correctly:
1. Assembling sandwich-compatible items to form sandwiches
2. Removing items from sandwiches, starting from the topmost layer
3. Eating sandwiches to regain health
4. The amount of bites a sandwich takes to eat scales with bites_left of ingredients
5. Removing partially-eaten ingredients will have them actually be partially eaten

-- UNIMPLEMENTED FEATURES --
1. Applying reagents to layers as condiments
2. Transferring reagents to user upon consumption,
 including: Reagents in each ingredient, src.ingredients[n]["reagents"]
 The exact behavior of src.reagents has yet to be determined, but will likely be used for reagent consumption
3. Transferring of effects, quality, and fill_amt to each bite of the sandwich

== NEX TODOS ==
- food quality
- food effects
- fill_amt
- reagents OOOUUUGHH
- Application of bite masks on removed ingredients and upon sandwich assembly
- Make it so that sandwiches don't take 50 years to eat (scale bites_left somehow)

- sandwich-specific sprites for the overlays
- general performance pass
- eliminate all todos that don't have entries here in this list
STRAY TODOS COMPLETED:

DONES
- "create or add to sandwich" proc
- contingency for if an ingredient gets randomly deleted. just make the sandwich fuckin burst its ingredients out, screw it
- or just proc for removing a specific ingredient safely

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
	list("reagent" = reagents, "ingredients" = list(sub base, sub base, sub base)),
	list("reagent" = null, "ingredients" = list(lettuce1, lettuce2, lettuce3)),
	list("reagent" = null, "ingredients" = list(bacon1, onion, bacon2)),
	list("reagent" = reagents, "ingredients" = list(tomato1, tomato2, cheese1)),
	list("reagent" = reagents, "ingredients" = list(cheese2, cheese3, tomato3)),
	list("reagent" = null, "ingredients" = list(sub top, sub top, sub top))
	)
	Burger:
	ingredients = list(
	list("reagent" = reagents, "ingredients" = list(bottom bun)),
	list("reagent" = reagents, "ingredients" = list(lettuce)),
	list("reagent" = reagents, "ingredients" = list(patty)),
	list("reagent" = reagents, "ingredients" = list(cheese)),
	list("reagent" = reagents, "ingredients" = list(top bun))
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
			src.add_reagent(user, ingredient)
		else
			src.add_ingredient(user, ingredient)
	src.render()

/obj/item/reagent_containers/food/snacks/new_sandwich/proc/add_reagent(mob/user, datum/reagents)

/// Adds a ingredient reagent to the sandwich, moving its respective atom (if applicable) to inside the sandwich
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
		return
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

/// Adds a new layer to the sandwich with appropriate width and a placeholder null for the reagent slot
/// Returns the new layer
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/add_layer()
	var/list/ingredient_list[src.width]
	var/list/new_layer = list("reagents" = null, "ingredients" = ingredient_list)
	src.ingredients += list(new_layer) // the only way to add the list without just combining them i could think of
	return new_layer

/// Returns the list reference for the current topmost layer of the sandwich
RETURN_TYPE(/list)
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/get_topmost_layer(var/ingredients_only)
	if(ingredients_only)
		return src.ingredients[length(src.ingredients)]["ingredients"]
	return src.ingredients[length(src.ingredients)]

// we will need more checks eventually

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

RETURN_TYPE(/list)
/// Returns a list of indexes that are open on the current topmost layer
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/get_open_indexes()
	var/list/return_list = list()
	var/list/topmost_layer = src.get_topmost_layer(ingredients_only = TRUE)
	for(var/index = 1, index <= length(topmost_layer), index++)
		if(isnull(topmost_layer[index]))
			return_list += index
	return return_list

/*RETURN_TYPE(/datum/sandwich_ingredient)
/// Returns the topmost ingredient, ignoring reagent layers
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/get_top_atom_ingredient()
	var/datum/sandwich_ingredient/top_ingredient = src.ingredients[length(src.ingredients)]
	if(!top_ingredient.is_reagent_layer)
		return top_ingredient
	return src.ingredients[length(src.ingredients) - 1]
*/
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/generate_name()
	src.name = "test sandwich of [TIME]"

// How many pixels wide is each ingredient?
#define SANDWICH_BASE_WIDTH 8

/obj/item/reagent_containers/food/snacks/new_sandwich/proc/render()
	src.ClearAllOverlays()
	// we need to generate the whole thing then center it
	// go through it one layer at a time and place the ingredients
	var/x_index = 0
	var/height_offset = 0
	for(var/list/layer in src.ingredients)
		for(var/datum/sandwich_ingredient/ingredient in layer["ingredients"])
			//todo account for width and offset accordingly. somehow.
			var/image/to_display = ingredient.get_appearance()
			to_display.pixel_x = SANDWICH_BASE_WIDTH * x_index
			to_display.pixel_y = height_offset
			x_index += ingredient.width
			src.AddOverlays(to_display, ingredient)
		height_offset += 2 //todo make this based on ingredient height
		x_index = 0

/obj/item/reagent_containers/food/snacks/new_sandwich/proc/update_context()
	src.sandwichContextActions = list()
	var/remove = FALSE
	if(length(src.ingredients) > 1)
		src.sandwichContextActions += new /datum/contextAction/sandwich/remove
		remove = TRUE
	if(remove)
		sandwichContextActions += new /datum/contextAction/sandwich/pickup

/// Attempts to remove the topmost (most recently added) ingredient and, if applicable, place it in a user's hand
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/try_remove(mob/user)
	var/list/topmost_layer = src.get_topmost_layer(ingredients_only = TRUE)
	var/datum/sandwich_ingredient/target = null
	for(var/index = length(topmost_layer), index > 0, index--)
		if(isnull(topmost_layer[index]))
			continue
		target = topmost_layer[index]
		src.remove_ingredient(user, target)
	if(!target)
		CRASH()
	/*

	src.unique_ingredients.Remove(target)
	src.render() //todo remove just the ingredient's overlay
	if(user)
		user.put_in_hand_or_drop(target.parent)
	else
		target.parent.set_loc(src.loc)
	target.on_remove()*/


/// Removes a specific ingredient from somewhere in the sandwich
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/remove_ingredient(mob/user, datum/sandwich_ingredient/target)
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
		src.ingredients.Remove(list(target.occupied_layer))
	src.unique_ingredients.Remove(target)
	if(user)
		user.put_in_hand_or_drop(target.parent)
	else
		target.parent.set_loc(src.loc)
	target.on_remove()

	SPAWN(0 SECONDS) // we wait a sec to let any updates finish first
		if(!src.one_layer_left_check())
			src.simulate() // todo make more performant
			src.render() // ditto

/// Checks if all we are is the bottom layer, and deletes us (spitting out that final ingredient) if so
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/one_layer_left_check()
	// just the base ingredient left. if there's no reagents on it let's just stop pretending we're a sandwich anymore
	if(length(src.ingredients) == 1)
		var/list/topmost_layer = src.get_topmost_layer()
		if(!isnull(topmost_layer["reagents"]))
			return FALSE // i dont care if you dont consider a single slice of bread with ketchup on it a "sandwich"
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
 total effects - and distribute those effects across each bite.
 Then we just make sure that, if an ingredient is removed, it has bites taken out of it and possibly
 outright destroyed depending on how little is left

 TODO: REAGENT HANDLING. FUCK.
*/


/// Updates several key variables for the sandwich and its ingredients
/obj/item/reagent_containers/food/snacks/new_sandwich/proc/simulate()
	var/bites_left_sum = 0
	var/uneaten_bites_left_sum = 0
	var/heal_amt_sum = 0

	for(var/datum/sandwich_ingredient/ingredient in src.unique_ingredients)
		uneaten_bites_left_sum += ingredient.get_uneaten_bites_left()
		bites_left_sum += ingredient.get_bites_left()
		heal_amt_sum += ingredient.get_heal_amt()

	if(!bites_left_sum)
		qdel(src) //todo find better way to ensure sandwich removed upon fully consumed
		return

	src.uneaten_bites_left = uneaten_bites_left_sum
	src.bites_left = bites_left_sum
	src.percent_eaten_per_bite = 1 / src.uneaten_bites_left // from 0 to 1
	src.heal_amt = heal_amt_sum / src.bites_left

	src.fill_amt = 0 // todo fix
	//todo add buffs too

/*
	// This math is for adjusting heal_amt so that when you finish eating, each ingredient would've healed you the same as if you ate it alone
	// Same for buffs. This is a lot of checking/processing for a loop so try not to call this too often.
	for(var/datum/sandwich_ingredient/ingredient in src.ingredients)
		var/healing = ingredient.uneaten_bites_left * ingredient.original_heal_amt
		healing *= ingredient.amount_left
		ingredient.our_snack.bites_left = src.bites_left
		ingredient.bites_left = src.bites_left
		healing /= ingredient.bites_left
		ingredient.our_snack.heal_amt = healing
		ingredient.heal_amt = healing
		var/buff_time = 0
		var/buffs = ingredient.original_effects
		for (var/effect in buffs)
			if((buffs[effect]))
				buff_time = buffs[effect]
			else
				buff_time = 1 MINUTE // currently the default buff time
			buff_time *= ingredient.max_bites_left
			buff_time *= ingredient.amount_left
			buff_time /= ingredient.bites_left
			ingredient.our_snack.food_effects[effect] = buff_time
*/

/obj/item/reagent_containers/food/snacks/new_sandwich/take_a_bite()
	. = ..()
	// god this sucks but i cant think of any other sane way to do this
	for(var/datum/sandwich_ingredient/ingredient in src.unique_ingredients)
		ingredient.bitten_into(src.percent_eaten_per_bite)




// FUCK
/obj/item/reagent_containers/food/snacks/new_sandwich/on_reagent_transfer()


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
			src.try_remove(user)
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
