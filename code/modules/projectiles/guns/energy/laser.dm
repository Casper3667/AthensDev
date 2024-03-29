/obj/item/weapon/gun/energy/laser
	name = "laser carbine"
	desc = "An Hesphaistos Industries G40E carbine, designed to kill with concentrated energy blasts.  This varient has the ability to \
	switch between standard fire and a more efficent but weaker 'suppressive' fire."
	icon_state = "laser"
	item_state = "laser"
	fire_sound = 'sound/weapons/Laser.ogg'
	slot_flags = SLOT_BELT|SLOT_BACK
	w_class = 4
	force = 10
	origin_tech = list(TECH_COMBAT = 3, TECH_MAGNET = 2)
	matter = list(DEFAULT_WALL_MATERIAL = 2000)
	projectile_type = /obj/item/projectile/beam/midlaser
//	requires_two_hands = 1
	one_handed_penalty = 2

	firemodes = list(
		list(mode_name="normal", projectile_type=/obj/item/projectile/beam/midlaser, charge_cost = 200),
		list(mode_name="suppressive", projectile_type=/obj/item/projectile/beam/weaklaser, charge_cost = 50),
		)

/obj/item/weapon/gun/energy/laser/mounted
	self_recharge = 1
	use_external_power = 1
	requires_two_hands = 0 // Not sure if two-handing gets checked for mounted weapons, but better safe than sorry.

/obj/item/weapon/gun/energy/laser/practice
	name = "practice laser carbine"
	desc = "A modified version of the HI G40E, this one fires less concentrated energy bolts designed for target practice."
	projectile_type = /obj/item/projectile/beam/practice

	firemodes = list(
		list(mode_name="normal", projectile_type=/obj/item/projectile/beam/practice, charge_cost = 200),
		list(mode_name="suppressive", projectile_type=/obj/item/projectile/beam/practice, charge_cost = 50),
		)

obj/item/weapon/gun/energy/retro
	name = "retro laser"
	icon_state = "retro"
	item_state = "retro"
	desc = "An older model of the basic lasergun. Nevertheless, it is still quite deadly and easy to maintain, making it a favorite amongst pirates and other outlaws."
	fire_sound = 'sound/weapons/Laser.ogg'
	slot_flags = SLOT_BELT
	w_class = 3
	projectile_type = /obj/item/projectile/beam
	fire_delay = 10 //old technology

/obj/item/weapon/gun/energy/captain
	name = "antique laser gun"
	icon_state = "caplaser"
	item_state = "caplaser"
	desc = "A rare weapon, handcrafted by a now defunct specialty manufacturer on Luna for a small fortune. It's certainly aged well."
	force = 5
	fire_sound = 'sound/weapons/Laser.ogg'
	slot_flags = SLOT_BELT
	w_class = 3
	projectile_type = /obj/item/projectile/beam
	origin_tech = null
	max_shots = 5 //to compensate a bit for self-recharging
	self_recharge = 1

/obj/item/weapon/gun/energy/lasercannon
	name = "laser cannon"
	desc = "With the laser cannon, the lasing medium is enclosed in a tube lined with uranium-235 and subjected to high neutron \
	flux in a nuclear reactor core. This incredible technology may help YOU achieve high excitation rates with small laser volumes!"
	icon_state = "lasercannon"
	item_state = null
	fire_sound = 'sound/weapons/lasercannonfire.ogg'
	origin_tech = list(TECH_COMBAT = 4, TECH_MATERIAL = 3, TECH_POWER = 3)
	slot_flags = SLOT_BELT|SLOT_BACK
	projectile_type = /obj/item/projectile/beam/heavylaser/cannon
	max_shots = 4
	fire_delay = 20
	w_class = 4
//	requires_two_hands = 1
	one_handed_penalty = 6 // The thing's heavy and huge.
	accuracy = 3
	charge_cost = 400


/obj/item/weapon/gun/energy/lasercannon/mounted
	name = "mounted laser cannon"
	self_recharge = 1
	use_external_power = 1
	recharge_time = 10
	accuracy = 0 // Mounted cannons are just fine the way they are.
	requires_two_hands = 0 // Not sure if two-handing gets checked for mounted weapons, but better safe than sorry.
	projectile_type = /obj/item/projectile/beam/heavylaser
	charge_cost = 400
	max_shots = 6
	fire_delay = 20

/obj/item/weapon/gun/energy/xray
	name = "xray laser gun"
	desc = "A high-power laser gun capable of expelling concentrated xray blasts, which are able to penetrate matter easier than \
	standard photonic beams, resulting in an effective 'anti-armor' energy weapon."
	icon_state = "xray"
	item_state = "xray"
	fire_sound = 'sound/weapons/eluger.ogg'
	origin_tech = list(TECH_COMBAT = 5, TECH_MATERIAL = 3, TECH_MAGNET = 2)
	projectile_type = /obj/item/projectile/beam/xray
	charge_cost = 100
	max_shots = 12

/obj/item/weapon/gun/energy/sniperrifle
	name = "marksman energy rifle"
	desc = "The HI DMR 9E is an older design of Hesphaistos Industries. A designated marksman rifle capable of shooting powerful \
	ionized beams, this is a weapon to kill from a distance."
	icon_state = "sniper"
	item_state_slots = list(slot_r_hand_str = "laser", slot_l_hand_str = "laser") //placeholder
	fire_sound = 'sound/weapons/gauss_shoot.ogg'
	origin_tech = list(TECH_COMBAT = 6, TECH_MATERIAL = 5, TECH_POWER = 4)
	projectile_type = /obj/item/projectile/beam/sniper
	slot_flags = SLOT_BACK
	charge_cost = 400
	max_shots = 4
	fire_delay = 35
	force = 10
	w_class = 5 // So it can't fit in a backpack.
	accuracy = -3 //shooting at the hip
	scoped_accuracy = 0
//	requires_two_hands = 1
	one_handed_penalty = 4 // The weapon itself is heavy, and the long barrel makes it hard to hold steady with just one hand.

/obj/item/weapon/gun/energy/sniperrifle/verb/scope()
	set category = "Object"
	set name = "Use Scope"
	set popup_menu = 1

	toggle_scope(2.0)

////////Laser Tag////////////////////

/obj/item/weapon/gun/energy/lasertag
	name = "laser tag gun"
	item_state = "laser"
	desc = "Standard issue weapon of the Imperial Guard"
	origin_tech = list(TECH_COMBAT = 1, TECH_MAGNET = 2)
	self_recharge = 1
	matter = list(DEFAULT_WALL_MATERIAL = 2000)
	fire_sound = 'sound/weapons/Laser.ogg'
	projectile_type = /obj/item/projectile/beam/lastertag/blue
	var/required_vest

/obj/item/weapon/gun/energy/lasertag/special_check(var/mob/living/carbon/human/M)
	if(ishuman(M))
		if(!istype(M.wear_suit, required_vest))
			M << "<span class='warning'>You need to be wearing your laser tag vest!</span>"
			return 0
	return ..()

/obj/item/weapon/gun/energy/lasertag/blue
	icon_state = "bluetag"
	item_state = "bluetag"
	projectile_type = /obj/item/projectile/beam/lastertag/blue
	required_vest = /obj/item/clothing/suit/bluetag

/obj/item/weapon/gun/energy/lasertag/red
	icon_state = "redtag"
	item_state = "redtag"
	projectile_type = /obj/item/projectile/beam/lastertag/red
	required_vest = /obj/item/clothing/suit/redtag
