/*
	Defines a firing mode for a gun.

	A firemode is created from a list of fire mode settings. Each setting modifies the value of the gun var with the same name.
	If the fire mode value for a setting is null, it will be replaced with the initial value of that gun's variable when the firemode is created.
	Obviously not compatible with variables that take a null value. If a setting is not present, then the corresponding var will not be modified.
*/
/datum/firemode
	var/name = "default"
	var/list/settings = list()

/datum/firemode/New(obj/item/weapon/gun/gun, list/properties = null)
	..()
	if(!properties) return

	for(var/propname in properties)
		var/propvalue = properties[propname]

		if(propname == "mode_name")
			name = propvalue
		if(isnull(propvalue))
			settings[propname] = gun.vars[propname] //better than initial() as it handles list vars like burst_accuracy
		else
			settings[propname] = propvalue

/datum/firemode/proc/apply_to(obj/item/weapon/gun/gun)
	for(var/propname in settings)
		gun.vars[propname] = settings[propname]

//Parent gun type. Guns are weapons that can be aimed at mobs and act over a distance
/obj/item/weapon/gun
	name = "gun"
	desc = "Its a gun. It's pretty terrible, though."
	icon = 'icons/obj/gun.dmi'
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_guns.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_guns.dmi',
		)
	icon_state = "detective"
	item_state = "gun"
	flags =  CONDUCT
	slot_flags = SLOT_BELT|SLOT_HOLSTER
	matter = list(DEFAULT_WALL_MATERIAL = 2000)
	w_class = 3
	throwforce = 5
	throw_speed = 4
	throw_range = 5
	force = 5
	origin_tech = list(TECH_COMBAT = 1)
	attack_verb = list("struck", "hit", "bashed")
	zoomdevicename = "scope"

	var/burst = 1
	var/fire_delay = 6 	//delay after shooting before the gun can be used again
	var/burst_delay = 2	//delay between shots, if firing in bursts
	var/move_delay = 1
	var/fire_sound = 'sound/weapons/Gunshot.ogg'
	var/fire_sound_text = "gunshot"
	var/recoil = 0		//screen shake
	var/silenced = 0
	var/muzzle_flash = 3
	var/accuracy = 0   //accuracy is measured in tiles. +1 accuracy means that everything is effectively one tile closer for the purpose of miss chance, -1 means the opposite. launchers are not supported, at the moment.
	var/scoped_accuracy = null
	var/list/burst_accuracy = list(0) //allows for different accuracies for each shot in a burst. Applied on top of accuracy
	var/list/dispersion = list(0)
	var/mode_name = null
	var/requires_two_hands
	var/wielded_icon = "gun_wielded"
	var/one_handed_penalty = 0 // Penalty applied if someone fires a two-handed gun with one hand.

	var/next_fire_time = 0

	var/sel_mode = 1 //index of the currently selected mode
	var/list/firemodes = list()

	//aiming system stuff
	var/keep_aim = 1 	//1 for keep shooting until aim is lowered
						//0 for one bullet after tarrget moves and aim is lowered
	var/multi_aim = 0 //Used to determine if you can target multiple people.
	var/tmp/list/mob/living/aim_targets //List of who yer targeting.
	var/tmp/mob/living/last_moved_mob //Used to fire faster at more than one person.
	var/tmp/told_cant_shoot = 0 //So that it doesn't spam them with the fact they cannot hit them.
	var/tmp/lock_time = -100

	var/dna_lock = 0				//whether or not the gun is locked to dna
	var/obj/item/dnalockingchip/attached_lock

/obj/item/weapon/gun/New()
	..()
	for(var/i in 1 to firemodes.len)
		firemodes[i] = new /datum/firemode(src, firemodes[i])

	if(isnull(scoped_accuracy))
		scoped_accuracy = accuracy

	if(dna_lock)
		attached_lock = new /obj/item/dnalockingchip(src)
	if(!dna_lock)
		verbs -= /obj/item/weapon/gun/verb/remove_dna
		verbs -= /obj/item/weapon/gun/verb/give_dna
		verbs -= /obj/item/weapon/gun/verb/allow_dna

/obj/item/weapon/gun/update_held_icon()
	if(requires_two_hands)
		var/mob/living/M = loc
		if(istype(M))
			if(M.item_is_in_hands(src) && !M.hands_are_full())
				name = "[initial(name)] (wielded)"
				item_state = wielded_icon
			else
				name = initial(name)
				item_state = initial(item_state)
				update_icon(ignore_inhands=1) // In case item_state is set somewhere else.
	..()

//Checks whether a given mob can use the gun
//Any checks that shouldn't result in handle_click_empty() being called if they fail should go here.
//Otherwise, if you want handle_click_empty() to be called, check in consume_next_projectile() and return null there.
/obj/item/weapon/gun/proc/special_check(var/mob/user)

	if(!istype(user, /mob/living))
		return 0
	if(!user.IsAdvancedToolUser())
		return 0

	var/mob/living/M = user
	if(dna_lock && attached_lock.stored_dna)
		if(!authorized_user(user))
			if(attached_lock.safety_level == 0)
				M << "<span class='danger'>\The [src] buzzes in dissapoint and displays an invalid DNA symbol.</span>"
				return 0
			if(!attached_lock.exploding)
				if(attached_lock.safety_level == 1)
					M << "<span class='danger'>\The [src] hisses in dissapointment.</span>"
					visible_message("<span class='game say'><span class='name'>\The [src]</span> announces, \"Self-destruct occurring in ten seconds.\"</span>", "<span class='game say'><span class='name'>\The [src]</span> announces, \"Self-destruct occurring in ten seconds.\"</span>")
					spawn(100)
						explosion(src, 0, 0, 3, 4)
						attached_lock.exploding = 1
						sleep(1)
						qdel(src)
					return 0
	if(HULK in M.mutations)
		M << "<span class='danger'>Your fingers are much too large for the trigger guard!</span>"
		return 0
	if((CLUMSY in M.mutations) && prob(40)) //Clumsy handling
		var/obj/P = consume_next_projectile()
		if(P)
			if(process_projectile(P, user, user, pick("l_foot", "r_foot")))
				handle_post_fire(user, user)
				user.visible_message(
					"<span class='danger'>\The [user] shoots \himself in the foot with \the [src]!</span>",
					"<span class='danger'>You shoot yourself in the foot with \the [src]!</span>"
					)
				M.drop_item()
		else
			handle_click_empty(user)
		return 0
	return 1

/obj/item/weapon/gun/emp_act(severity)
	for(var/obj/O in contents)
		O.emp_act(severity)

/obj/item/weapon/gun/afterattack(atom/A, mob/living/user, adjacent, params)
	if(adjacent) return //A is adjacent, is the user, or is on the user's person

	if(!user.aiming)
		user.aiming = new(user)

	if(user && user.client && user.aiming && user.aiming.active && user.aiming.aiming_at != A)
		PreFire(A,user,params) //They're using the new gun system, locate what they're aiming at.
		return

	if(user && user.a_intent == I_HELP && user.is_preference_enabled(/datum/client_preference/safefiring)) //regardless of what happens, refuse to shoot if help intent is on
		user << "<span class='warning'>You refrain from firing your [src] as your intent is set to help.</span>"
	else
		Fire(A,user,params) //Otherwise, fire normally.

/obj/item/weapon/gun/attack(atom/A, mob/living/user, def_zone)
	if (A == user && user.zone_sel.selecting == O_MOUTH && !mouthshoot)
		handle_suicide(user)
	else if(user.a_intent == I_HURT) //point blank shooting
		Fire(A, user, pointblank=1)
	else
		return ..() //Pistolwhippin'

/obj/item/weapon/gun/attackby(var/obj/item/A as obj, mob/user as mob)
	if(istype(A, /obj/item/dnalockingchip))
		if(dna_lock)
			user << "<span class='notice'>\The [src] already has a [attached_lock].</span>"
			return
		user << "<span class='notice'>You insert \the [A] into \the [src].</span>"
		user.drop_item()
		A.loc = src
		attached_lock = A
		dna_lock = 1
		verbs += /obj/item/weapon/gun/verb/remove_dna
		verbs += /obj/item/weapon/gun/verb/give_dna
		verbs += /obj/item/weapon/gun/verb/allow_dna
		return

	if(istype(A, /obj/item/weapon/screwdriver))
		if(dna_lock && attached_lock && !attached_lock.controller_lock)
			user << "<span class='notice'>You begin removing \the [attached_lock] from \the [src].</span>"
			if(do_after(user, 25))
				user << "<span class='notice'>You remove \the [attached_lock] from \the [src].</span>"
				user.put_in_hands(attached_lock)
				dna_lock = 0
				attached_lock = null
				verbs -= /obj/item/weapon/gun/verb/remove_dna
				verbs -= /obj/item/weapon/gun/verb/give_dna
				verbs -= /obj/item/weapon/gun/verb/allow_dna
		else
			user << "<span class='warning'>\The [src] is not accepting modifications at this time.</span>"

/obj/item/weapon/gun/emag_act(var/remaining_charges, var/mob/user)
	if(dna_lock && attached_lock.controller_lock)
		user << "<span class='notice'>You short circuit the internal locking mechanisms of \the [src]!</span>"
		attached_lock.controller_dna = null
		attached_lock.controller_lock = 0
		attached_lock.stored_dna = list()
		return 1

/obj/item/weapon/gun/proc/Fire(atom/target, mob/living/user, clickparams, pointblank=0, reflex=0)
	if(!user || !target) return

	add_fingerprint(user)

	user.break_cloak()

	if(!special_check(user))
		return

	if(world.time < next_fire_time)
		if (world.time % 3) //to prevent spam
			user << "<span class='warning'>[src] is not ready to fire again!</span>"
		return

	var/shoot_time = (burst - 1)* burst_delay
	user.setClickCooldown(shoot_time) //no clicking on things while shooting
	user.setMoveCooldown(shoot_time) //no moving while shooting either
	next_fire_time = world.time + shoot_time

	var/held_acc_mod = 0
	var/held_disp_mod = 0
	if(requires_two_hands)
		if(user.item_is_in_hands(src) && user.hands_are_full())
			held_acc_mod = held_acc_mod - one_handed_penalty
			held_disp_mod = held_disp_mod - round(one_handed_penalty / 2)

	//actually attempt to shoot
	var/turf/targloc = get_turf(target) //cache this in case target gets deleted during shooting, e.g. if it was a securitron that got destroyed.
	for(var/i in 1 to burst)
		var/obj/projectile = consume_next_projectile(user)
		if(!projectile)
			handle_click_empty(user)
			break

		var/acc = burst_accuracy[min(i, burst_accuracy.len)] + held_acc_mod
		var/disp = dispersion[min(i, dispersion.len)] + held_disp_mod
		process_accuracy(projectile, user, target, acc, disp)

		if(pointblank)
			process_point_blank(projectile, user, target)

		if(process_projectile(projectile, user, target, user.zone_sel.selecting, clickparams))
			handle_post_fire(user, target, pointblank, reflex)
			update_icon()

		if(i < burst)
			sleep(burst_delay)

		if(!(target && target.loc))
			target = targloc
			pointblank = 0

	// We do this down here, so we don't get the message if we fire an empty gun.
	if(requires_two_hands)
		if(user.item_is_in_hands(src) && user.hands_are_full())
			if(one_handed_penalty >= 2)
				user << "<span class='warning'>You struggle to keep \the [src] pointed at the correct position with just one hand!</span>"

	admin_attack_log(usr, attacker_message="Fired [src]", admin_message="fired a gun ([src]) (MODE: [src.mode_name]) [reflex ? "by reflex" : "manually"].")

	//update timing
	user.setClickCooldown(DEFAULT_QUICK_COOLDOWN)
	user.setMoveCooldown(move_delay)
	next_fire_time = world.time + fire_delay

	if(muzzle_flash)
		set_light(0)

// Similar to the above proc, but does not require a user, which is ideal for things like turrets.
/obj/item/weapon/gun/proc/Fire_userless(atom/target)
	if(!target)
		return

	if(world.time < next_fire_time)
		return

	var/shoot_time = (burst - 1)* burst_delay
	next_fire_time = world.time + shoot_time

	var/turf/targloc = get_turf(target) //cache this in case target gets deleted during shooting, e.g. if it was a securitron that got destroyed.
	for(var/i in 1 to burst)
		var/obj/projectile = consume_next_projectile()
		if(!projectile)
			handle_click_empty()
			break

		if(istype(projectile, /obj/item/projectile))
			var/obj/item/projectile/P = projectile

			var/acc = burst_accuracy[min(i, burst_accuracy.len)]
			var/disp = dispersion[min(i, dispersion.len)]

			P.accuracy = accuracy + acc
			P.dispersion = disp

			P.shot_from = src.name
			P.silenced = silenced

			P.launch(target)

			if(silenced)
				playsound(src, fire_sound, 10, 1)
			else
				playsound(src, fire_sound, 50, 1)

			if(muzzle_flash)
				set_light(muzzle_flash)
			update_icon()

		//process_accuracy(projectile, user, target, acc, disp)

	//	if(pointblank)
	//		process_point_blank(projectile, user, target)

	//	if(process_projectile(projectile, null, target, user.zone_sel.selecting, clickparams))
	//		handle_post_fire(null, target, pointblank, reflex)

	//	update_icon()

		if(i < burst)
			sleep(burst_delay)

		if(!(target && target.loc))
			target = targloc
			//pointblank = 0

	log_and_message_admins("Fired [src].")

	//admin_attack_log(usr, attacker_message="Fired [src]", admin_message="fired a gun ([src]) (MODE: [src.mode_name]) [reflex ? "by reflex" : "manually"].")

	//update timing
	next_fire_time = world.time + fire_delay

	if(muzzle_flash)
		set_light(0)



//obtains the next projectile to fire
/obj/item/weapon/gun/proc/consume_next_projectile()
	return null

//used by aiming code
/obj/item/weapon/gun/proc/can_hit(atom/target as mob, var/mob/living/user as mob)
	if(!special_check(user))
		return 2
	//just assume we can shoot through glass and stuff. No big deal, the player can just choose to not target someone
	//on the other side of a window if it makes a difference. Or if they run behind a window, too bad.
	return check_trajectory(target, user)

//called if there was no projectile to shoot
/obj/item/weapon/gun/proc/handle_click_empty(mob/user)
	if (user)
		user.visible_message("*click click*", "<span class='danger'>*click*</span>")
	else
		src.visible_message("*click click*")
	playsound(src.loc, 'sound/weapons/empty.ogg', 100, 1)

//called after successfully firing
/obj/item/weapon/gun/proc/handle_post_fire(mob/user, atom/target, var/pointblank=0, var/reflex=0)
	if(silenced)
		playsound(user, fire_sound, 10, 1)
	else
		playsound(user, fire_sound, 50, 1)

		if(reflex)
			user.visible_message(
				"<span class='reflex_shoot'><b>\The [user] fires \the [src][pointblank ? " point blank at \the [target]":""] by reflex!</b></span>",
				"<span class='reflex_shoot'>You fire \the [src] by reflex!</span>",
				"You hear a [fire_sound_text]!"
			)
		else
			user.visible_message(
				"<span class='danger'>\The [user] fires \the [src][pointblank ? " point blank at \the [target]":""]!</span>",
				"<span class='warning'>You fire \the [src]!</span>",
				"You hear a [fire_sound_text]!"
				)

		if(muzzle_flash)
			set_light(muzzle_flash)

	if(recoil)
		spawn()
			shake_camera(user, recoil+1, recoil)
	update_icon()


/obj/item/weapon/gun/proc/process_point_blank(obj/projectile, mob/user, atom/target)
	var/obj/item/projectile/P = projectile
	if(!istype(P))
		return //default behaviour only applies to true projectiles

	//default point blank multiplier
	var/damage_mult = 1.3

	//determine multiplier due to the target being grabbed
	if(ismob(target))
		var/mob/M = target
		if(M.grabbed_by.len)
			var/grabstate = 0
			for(var/obj/item/weapon/grab/G in M.grabbed_by)
				grabstate = max(grabstate, G.state)
			if(grabstate >= GRAB_NECK)
				damage_mult = 2.5
			else if(grabstate >= GRAB_AGGRESSIVE)
				damage_mult = 1.5
	P.damage *= damage_mult

/obj/item/weapon/gun/proc/process_accuracy(obj/projectile, mob/user, atom/target, acc_mod, dispersion)
	var/obj/item/projectile/P = projectile
	if(!istype(P))
		return //default behaviour only applies to true projectiles

	//Accuracy modifiers
	P.accuracy = accuracy + acc_mod
	P.dispersion = dispersion

	// Certain statuses make it harder to aim, blindness especially.  Same chances as melee, however guns accuracy uses multiples of 15.
	if(user.eye_blind)
		accuracy -= 5
	if(user.eye_blurry)
		accuracy -= 2
	if(user.confused)
		accuracy -= 3

	//accuracy bonus from aiming
	if (aim_targets && (target in aim_targets))
		//If you aim at someone beforehead, it'll hit more often.
		//Kinda balanced by fact you need like 2 seconds to aim
		//As opposed to no-delay pew pew
		P.accuracy += 2

//does the actual launching of the projectile
/obj/item/weapon/gun/proc/process_projectile(obj/projectile, mob/user, atom/target, var/target_zone, var/params=null)
	var/obj/item/projectile/P = projectile
	if(!istype(P))
		return 0 //default behaviour only applies to true projectiles

	if(params)
		P.set_clickpoint(params)

	//shooting while in shock
	var/x_offset = 0
	var/y_offset = 0
	if(istype(user, /mob/living/carbon))
		var/mob/living/carbon/mob = user
		if(mob.shock_stage > 120)
			y_offset = rand(-2,2)
			x_offset = rand(-2,2)
		else if(mob.shock_stage > 70)
			y_offset = rand(-1,1)
			x_offset = rand(-1,1)

	return !P.launch_from_gun(target, user, src, target_zone, x_offset, y_offset)

//apart of reskins that have two sprites, touching may result in frustration and breaks
/obj/item/weapon/gun/projectile/colt/detective/attack_hand(var/mob/living/user)
	if(!unique_reskin && loc == user)
		reskin_gun(user)
		return
	..()

//Suicide handling.
/obj/item/weapon/gun/var/mouthshoot = 0 //To stop people from suiciding twice... >.>
/obj/item/weapon/gun/proc/handle_suicide(mob/living/user)
	if(!ishuman(user))
		return
	var/mob/living/carbon/human/M = user

	mouthshoot = 1
	M.visible_message("\red [user] sticks their gun in their mouth, ready to pull the trigger...")
	if(!do_after(user, 40))
		M.visible_message("\blue [user] decided life was worth living")
		mouthshoot = 0
		return
	var/obj/item/projectile/in_chamber = consume_next_projectile()
	if (istype(in_chamber))
		user.visible_message("<span class = 'warning'>[user] pulls the trigger.</span>")
		if(silenced)
			playsound(user, fire_sound, 10, 1)
		else
			playsound(user, fire_sound, 50, 1)
		if(istype(in_chamber, /obj/item/projectile/beam/lastertag))
			user.show_message("<span class = 'warning'>You feel rather silly, trying to commit suicide with a toy.</span>")
			mouthshoot = 0
			return

		in_chamber.on_hit(M)
		if (in_chamber.damage_type != HALLOSS)
			log_and_message_admins("[key_name(user)] commited suicide using \a [src]")
			user.apply_damage(in_chamber.damage*2.5, in_chamber.damage_type, "head", used_weapon = "Point blank shot in the mouth with \a [in_chamber]", sharp=1)
			user.death()
		else
			user << "<span class = 'notice'>Ow...</span>"
			user.apply_effect(110,AGONY,0)
		qdel(in_chamber)
		mouthshoot = 0
		return
	else
		handle_click_empty(user)
		mouthshoot = 0
		return

/obj/item/weapon/gun/proc/toggle_scope(var/zoom_amount=2.0)
	//looking through a scope limits your periphereal vision
	//still, increase the view size by a tiny amount so that sniping isn't too restricted to NSEW
	var/zoom_offset = round(world.view * zoom_amount)
	var/view_size = round(world.view + zoom_amount)
	var/scoped_accuracy_mod = zoom_offset

	zoom(zoom_offset, view_size)
	if(zoom)
		accuracy = scoped_accuracy + scoped_accuracy_mod
		if(recoil)
			recoil = round(recoil*zoom_amount+1) //recoil is worse when looking through a scope

//make sure accuracy and recoil are reset regardless of how the item is unzoomed.
/obj/item/weapon/gun/zoom()
	..()
	if(!zoom)
		accuracy = initial(accuracy)
		recoil = initial(recoil)

/obj/item/weapon/gun/examine(mob/user)
	..()
	if(firemodes.len > 1)
		var/datum/firemode/current_mode = firemodes[sel_mode]
		user << "The fire selector is set to [current_mode.name]."

/obj/item/weapon/gun/proc/switch_firemodes(mob/user)
	if(firemodes.len <= 1)
		return null

	sel_mode++
	if(sel_mode > firemodes.len)
		sel_mode = 1
	var/datum/firemode/new_mode = firemodes[sel_mode]
	new_mode.apply_to(src)
	user << "<span class='notice'>\The [src] is now set to [mode_name].</span>"

	return new_mode

/obj/item/weapon/gun/attack_self(mob/user)
	switch_firemodes(user)
