return {
    ['testburger'] = {
        label = 'Test Burger',
        weight = 220,
        degrade = 60,
        client = {
            image = 'burger_chicken.png',
            status = { hunger = 200000 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            export = 'ox_inventory_examples.testburger'
        },
        server = {
            export = 'ox_inventory_examples.testburger',
            test = 'what an amazingly delicious burger, amirite?'
        },
        buttons = {
            {
                label = 'Lick it',
                action = function(slot)
                    print('You licked the burger')
                end
            },
            {
                label = 'Squeeze it',
                action = function(slot)
                    print('You squeezed the burger :(')
                end
            },
            {
                label = 'What do you call a vegan burger?',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('A misteak.')
                end
            },
            {
                label = 'What do frogs like to eat with their hamburgers?',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('French flies.')
                end
            },
            {
                label = 'Why were the burger and fries running?',
                group = 'Hamburger Puns',
                action = function(slot)
                    print('Because they\'re fast food.')
                end
            }
        },
        consume = 0.3
    },

    ['bandage'] = {
        label = 'Bandage',
        weight = 115,
    },

    ['burger'] = {
        label = 'Burger',
        weight = 220,
        client = {
            status = { hunger = 200000 },
            anim = 'eating',
            prop = 'burger',
            usetime = 2500,
            notification = 'You ate a delicious burger'
        },
    },

    ['sprunk'] = {
        label = 'Sprunk',
        weight = 350,
        client = {
            status = { thirst = 200000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_can_01`, pos = vec3(0.01, 0.01, 0.06), rot = vec3(5.0, 5.0, -180.5) },
            usetime = 2500,
            notification = 'You quenched your thirst with a sprunk'
        }
    },

    ['parachute'] = {
        label = 'Parachute',
        weight = 8000,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 1500
        }
    },

    ['garbage'] = {
        label = 'Garbage',
    },

    ['paperbag'] = {
        label = 'Paper Bag',
        weight = 1,
        stack = false,
        close = false,
        consume = 0
    },

    ['panties'] = {
        label = 'Knickers',
        weight = 10,
        consume = 0,
        client = {
            status = { thirst = -100000, stress = -25000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_cs_panties_02`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, -13.5, -1.5) },
            usetime = 2500,
        }
    },

    ['lockpick'] = {
        label = 'Lockpick',
        weight = 160,
    },

    ['phone'] = {
        label = 'Phone',
        weight = 190,
        stack = false,
        consume = 0,
        client = {
            add = function(total)
                if total > 0 then
                    pcall(function() return exports.npwd:setPhoneDisabled(false) end)
                end
            end,

            remove = function(total)
                if total < 1 then
                    pcall(function() return exports.npwd:setPhoneDisabled(true) end)
                end
            end
        }
    },

    ['mustard'] = {
        label = 'Mustard',
        weight = 500,
        client = {
            status = { hunger = 25000, thirst = 25000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_food_mustard`, pos = vec3(0.01, 0.0, -0.07), rot = vec3(1.0, 1.0, -1.5) },
            usetime = 2500,
            notification = 'You... drank mustard'
        }
    },

    ['water'] = {
        label = 'Water',
        weight = 500,
        client = {
            status = { thirst = 200000 },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            prop = { model = `prop_ld_flow_bottle`, pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
            usetime = 2500,
            cancel = true,
            notification = 'You drank some refreshing water'
        }
    },

    ['armour'] = {
        label = 'Bulletproof Vest',
        weight = 3000,
        stack = false,
        client = {
            anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
            usetime = 3500
        }
    },

    ['clothing'] = {
        label = 'Clothing',
        consume = 0,
    },

    ['money'] = {
        label = 'Money',
    },

    ['black_money'] = {
        label = 'Dirty Money',
    },

    ['id_card'] = {
        label = 'Identification Card',
    },

    ['driver_license'] = {
        label = 'Drivers License',
    },

    ['weaponlicense'] = {
        label = 'Weapon License',
    },

    ['lawyerpass'] = {
        label = 'Lawyer Pass',
    },

    ['radio'] = {
        label = 'Radio',
        weight = 1000,
        allowArmed = true,
        consume = 0,
        client = {
            event = 'mm_radio:client:use'
        }
    },

    ['jammer'] = {
        label = 'Radio Jammer',
        weight = 10000,
        allowArmed = true,
        client = {
            event = 'mm_radio:client:usejammer'
        }
    },

    ['radiocell'] = {
        label = 'AAA Cells',
        weight = 1000,
        stack = true,
        allowArmed = true,
        client = {
            event = 'mm_radio:client:recharge'
        }
    },

    ['advancedlockpick'] = {
        label = 'Advanced Lockpick',
        weight = 500,
    },

    ['screwdriverset'] = {
        label = 'Screwdriver Set',
        weight = 500,
    },

    ['electronickit'] = {
        label = 'Electronic Kit',
        weight = 500,
    },

    ['cleaningkit'] = {
        label = 'Cleaning Kit',
        weight = 500,
    },

    ['repairkit'] = {
        label = 'Repair Kit',
        weight = 2500,
    },

    ['advancedrepairkit'] = {
        label = 'Advanced Repair Kit',
        weight = 4000,
    },

    ['diamond'] = {
        label = 'Diamond',
        weight = 1500,
    },

    ['diamond_ring'] = {
        label = 'Diamond Ring',
        weight = 1500,
    },

    ['rolex'] = {
        label = 'Golden Watch',
        weight = 1500,
    },

    ['goldbar'] = {
        label = 'Gold Bar',
        weight = 1500,
    },

    ['goldchain'] = {
        label = 'Golden Chain',
        weight = 1500,
    },

    ['10kgoldchain'] = {
        label = '10k Gold Chain',
        weight = 1500,
    },

    ['crack_baggy'] = {
        label = 'Crack Baggy',
        weight = 100,
    },

    ['cokebaggy'] = {
        label = 'Bag of Coke',
        weight = 100,
    },

    ['coke_brick'] = {
        label = 'Coke Brick',
        weight = 2000,
    },

    ['coke_small_brick'] = {
        label = 'Coke Package',
        weight = 1000,
    },

    ['xtcbaggy'] = {
        label = 'Bag of Ecstasy',
        weight = 100,
    },

    ['meth'] = {
        label = 'Methamphetamine',
        weight = 100,
    },

    ['oxy'] = {
        label = 'Oxycodone',
        weight = 100,
    },

    ['weed_ak47'] = {
        label = 'AK47 2g',
        weight = 200,
    },

    ['weed_ak47_seed'] = {
        label = 'AK47 Seed',
        weight = 1,
    },

    ['weed_skunk'] = {
        label = 'Skunk 2g',
        weight = 200,
    },

    ['weed_skunk_seed'] = {
        label = 'Skunk Seed',
        weight = 1,
    },

    ['weed_amnesia'] = {
        label = 'Amnesia 2g',
        weight = 200,
    },

    ['weed_amnesia_seed'] = {
        label = 'Amnesia Seed',
        weight = 1,
    },

    ['weed_og-kush'] = {
        label = 'OGKush 2g',
        weight = 200,
    },

    ['weed_og-kush_seed'] = {
        label = 'OGKush Seed',
        weight = 1,
    },

    ['weed_white-widow'] = {
        label = 'OGKush 2g',
        weight = 200,
    },

    ['weed_white-widow_seed'] = {
        label = 'White Widow Seed',
        weight = 1,
    },

    ['weed_purple-haze'] = {
        label = 'Purple Haze 2g',
        weight = 200,
    },

    ['weed_purple-haze_seed'] = {
        label = 'Purple Haze Seed',
        weight = 1,
    },

    ['weed_brick'] = {
        label = 'Weed Brick',
        weight = 2000,
    },

    ['weed_nutrition'] = {
        label = 'Plant Fertilizer',
        weight = 2000,
    },

    ['joint'] = {
        label = 'Joint',
        weight = 200,
    },

    ['rolling_paper'] = {
        label = 'Rolling Paper',
        weight = 0,
    },

    ['empty_weed_bag'] = {
        label = 'Empty Weed Bag',
        weight = 0,
    },

    ['firstaid'] = {
        label = 'First Aid',
        weight = 2500,
    },

    ['ifaks'] = {
        label = 'Individual First Aid Kit',
        weight = 2500,
    },

    ['painkillers'] = {
        label = 'Painkillers',
        weight = 400,
    },

    ['firework1'] = {
        label = '2Brothers',
        weight = 1000,
    },

    ['firework2'] = {
        label = 'Poppelers',
        weight = 1000,
    },

    ['firework3'] = {
        label = 'WipeOut',
        weight = 1000,
    },

    ['firework4'] = {
        label = 'Weeping Willow',
        weight = 1000,
    },

    ['steel'] = {
        label = 'Steel',
        weight = 100,
    },

    ['rubber'] = {
        label = 'Rubber',
        weight = 100,
    },

    ['metalscrap'] = {
        label = 'Metal Scrap',
        weight = 100,
    },

    ['iron'] = {
        label = 'Iron',
        weight = 100,
    },

    ['copper'] = {
        label = 'Copper',
        weight = 100,
    },

    ['aluminum'] = {
        label = 'Aluminium',
        weight = 100,
    },

    ['plastic'] = {
        label = 'Plastic',
        weight = 100,
    },

    ['glass'] = {
        label = 'Glass',
        weight = 100,
    },

    ['gatecrack'] = {
        label = 'Gatecrack',
        weight = 1000,
    },

    ['cryptostick'] = {
        label = 'Crypto Stick',
        weight = 100,
    },

    ['trojan_usb'] = {
        label = 'Trojan USB',
        weight = 100,
    },

    ['toaster'] = {
        label = 'Toaster',
        weight = 5000,
    },

    ['small_tv'] = {
        label = 'Small TV',
        weight = 100,
    },

    ['security_card_01'] = {
        label = 'Security Card A',
        weight = 100,
    },

    ['security_card_02'] = {
        label = 'Security Card B',
        weight = 100,
    },

    ['drill'] = {
        label = 'Drill',
        weight = 5000,
    },

    ['thermite'] = {
        label = 'Thermite',
        weight = 1000,
    },

    ['diving_gear'] = {
        label = 'Diving Gear',
        weight = 30000,
    },

    ['diving_fill'] = {
        label = 'Diving Tube',
        weight = 3000,
    },

    ['antipatharia_coral'] = {
        label = 'Antipatharia',
        weight = 1000,
    },

    ['dendrogyra_coral'] = {
        label = 'Dendrogyra',
        weight = 1000,
    },

    ['jerry_can'] = {
        label = 'Jerrycan',
        weight = 3000,
    },

    ['nitrous'] = {
        label = 'Nitrous',
        weight = 1000,
    },

    ['wine'] = {
        label = 'Wine',
        weight = 500,
    },

    ['grape'] = {
        label = 'Grape',
        weight = 10,
    },

    ['grapejuice'] = {
        label = 'Grape Juice',
        weight = 200,
    },

    ['coffee'] = {
        label = 'Coffee',
        weight = 200,
    },

    ['vodka'] = {
        label = 'Vodka',
        weight = 500,
    },

    ['whiskey'] = {
        label = 'Whiskey',
        weight = 200,
    },

    ['beer'] = {
        label = 'Beer',
        weight = 200,
    },

    ['sandwich'] = {
        label = 'Sandwich',
        weight = 200,
    },

    ['walking_stick'] = {
        label = 'Walking Stick',
        weight = 1000,
    },

    ['lighter'] = {
        label = 'Lighter',
        weight = 200,
    },

    ['binoculars'] = {
        label = 'Binoculars',
        weight = 800,
    },

    ['stickynote'] = {
        label = 'Sticky Note',
        weight = 0,
    },

    ['empty_evidence_bag'] = {
        label = 'Empty Evidence Bag',
        weight = 200,
    },

    ['filled_evidence_bag'] = {
        label = 'Filled Evidence Bag',
        weight = 200,
    },

    ['harness'] = {
        label = 'Harness',
        weight = 200,
    },

    ['handcuffs'] = {
        label = 'Handcuffs',
        weight = 200,
    },

    -- Drogues : matières premières (récoltes)
    ['weed_leaf']       = { label = 'Feuille de weed',        weight = 20,  stack = true, close = true },
    ['coca_leaf']       = { label = 'Feuille de coca',        weight = 20,  stack = true, close = true },
    ['magic_mushroom']  = { label = 'Champignon',             weight = 20,  stack = true, close = true },
    ['meth_chemicals']  = { label = 'Produits chimiques',     weight = 250, stack = true, close = true },

    -- Drogues : produits finis (ateliers)
    ['weed_pouch']      = { label = 'Pochon de weed',         weight = 50,  stack = true, close = true },
    ['cocaine']         = { label = 'Cocaïne',                weight = 50,  stack = true, close = true },
    ['meth']            = { label = 'Méthamphétamine',        weight = 50,  stack = true, close = true },
    ['dried_mushroom']  = { label = 'Champignons séchés',     weight = 30,  stack = true, close = true },

    -- Armes : matériaux (fouilles)
    ['metal_scrap']     = { label = 'Ferraille',              weight = 200, stack = true, close = true },
    ['gun_parts_light'] = { label = "Pièces d'armes légères", weight = 300, stack = true, close = true },
    ['gun_parts_medium']= { label = "Pièces d'armes moyennes",weight = 500, stack = true, close = true },
    ['gun_parts_heavy'] = { label = "Pièces d'armes lourdes", weight = 800, stack = true, close = true },

    -- Outils de fouille
    ['crowbar']         = { label = 'Pied-de-biche',          weight = 1500, stack = false, close = true },
    -- ['lockpick']     = { label = 'Crochet',                weight = 160,  stack = true,  close = true },
    
	['crutch'] = {
		label = 'Crutch',
		weight = 100,
		stack = false,
		close = true,
	},

	['wheelchair'] = {
		label = 'Wheelchair',
		weight = 100,
		stack = false,
		close = true,
	},

	['stretcher'] = {
		label = 'Stretcher',
		weight = 100,
		stack = false,
		close = true,
	},

	['medical_kit'] = {
		label = 'Medical Kit',
		weight = 200,
		stack = false,
		close = false,
		description = 'A basic medical kit containing essential supplies for treating minor injuries and illnesses.',
	},

	['advanced_medical_kit'] = {
		label = 'Advanced Medical Kit',
		weight = 200,
		stack = false,
		close = false,
		description = 'A more advanced medical kit containing additional supplies and equipment for treating injuries and illnesses.',
	},

	['blood_bag_250'] = {
		label = 'Blood Bag 250ml',
		weight = 250,
		stack = true,
		close = false,
		description = 'A 250ml bag of blood used for blood transfusions.',
	},

	['blood_bag_500'] = {
		label = 'Blood Bag 500ml',
		weight = 500,
		stack = true,
		close = false,
		description = 'A 500ml bag of blood used for blood transfusions.',
	},

	['painkillers'] = {
		label = 'Painkillers',
		weight = 50,
		stack = true,
		close = false,
		description = 'A medication used to relieve pain and reduce fever.',
	},

	['adrenaline'] = {
		label = 'Adrenaline',
		weight = 50,
		stack = true,
		close = false,
	},

	['morphine'] = {
		label = 'Morphine',
		weight = 50,
		stack = true,
		close = false,
		description = 'A medication used to relieve pain and reduce fever.',
	},

	['suture_kit'] = {
		label = 'Suture Kit',
		weight = 100,
		stack = true,
		close = false,
		description = 'A medical device used to close wounds or surgical incisions.',
	},

	['icepack'] = {
		label = 'Ice Pack',
		weight = 100,
		stack = true,
		close = false,
		description = 'A bag of ice used to reduce swelling and numb pain.',
	},

	['splint'] = {
		label = 'Splint',
		weight = 100,
		stack = true,
		close = false,
		description = 'A device that is used to apply pressure to a limb.',
	},

	['defibrilator'] = {
		label = 'Defibrillator',
		weight = 500,
		stack = false,
		close = true,
	},

	['bodybag'] = {
		label = 'Body Bag',
		weight = 500,
		stack = true,
		close = false,
	},

	['gauze'] = {
		label = 'Gauze',
		weight = 20,
		stack = true,
		close = true,
		description = 'A thin, transparent fabric with a loose open weave, used for dressings, bandages, and surgical sponges.',
	},

	['bandage'] = {
		label = 'Bandage',
		description = 'Very good for stopping bleeding and small injuries',
		weight = 115,
		stack = true,
		close = true
	},

	['ointment'] = {
		label = 'Ointment',
		weight = 50,
		stack = true,
		close = true,
		description = 'A medical cream used to promote healing and prevent infection in minor cuts, scrapes, and burns.',
	},

	['disinfectant'] = {
		label = 'Disinfectant',
		weight = 50,
		stack = true,
		close = true,
		description = 'A liquid that kills bacteria and other microorganisms on surfaces.',
	},

	['cyclonamine'] = {
		label = 'Cyclonamine',
		weight = 50,
		stack = true,
		close = true,
	},

	['tourniquet'] = {
		label = 'Tourniquet',
		weight = 100,
		stack = true,
		close = true,
		description = 'A device that is used to apply pressure to a limb.',
	},

	['medicbag'] = {
		label = 'Medic Bag',
		weight = 500,
		stack = false,
		close = true,
		description = 'A bag containing medical supplies and equipment.',
	},

	['antipyretics'] = {
		label = 'Antipyretics',
		weight = 50,
		stack = true,
		close = true,
		description = 'A medication that reduces fever.',
	},

	['ambulance_gps'] = {
		label = 'Ambulance GPS',
		weight = 100,
		stack = false,
		close = true,
},
 ['vet_haut'] = {
    label = 'Haut', weight = 10, stack = false, close = true,
    description = 'Vêtement : clic droit > Porter.',
    client = { export = 'elyzea_clothing.useClothing' },
    buttons = {
        { label = 'Porter', action = function(slot) exports.elyzea_clothing:EquipFromSlot(slot) end },
        { label = 'Renommer', action = function(slot) exports.elyzea_clothing:RenameSlot(slot) end },
    },
},

['vet_tshirt'] = {
    label = 'T-shirt', weight = 10, stack = false, close = true,
    description = 'Vêtement : clic droit > Porter.',
    client = { export = 'elyzea_clothing.useClothing' },
    buttons = {
        { label = 'Porter', action = function(slot) exports.elyzea_clothing:EquipFromSlot(slot) end },
        { label = 'Renommer', action = function(slot) exports.elyzea_clothing:RenameSlot(slot) end },
    },
},

['vet_pantalon'] = {
    label = 'Pantalon', weight = 10, stack = false, close = true,
    description = 'Vêtement : clic droit > Porter.',
    client = { export = 'elyzea_clothing.useClothing' },
    buttons = {
        { label = 'Porter', action = function(slot) exports.elyzea_clothing:EquipFromSlot(slot) end },
        { label = 'Renommer', action = function(slot) exports.elyzea_clothing:RenameSlot(slot) end },
    },
},

['vet_chaussures'] = {
    label = 'Chaussures', weight = 10, stack = false, close = true,
    description = 'Vêtement : clic droit > Porter.',
    client = { export = 'elyzea_clothing.useClothing' },
    buttons = {
        { label = 'Porter', action = function(slot) exports.elyzea_clothing:EquipFromSlot(slot) end },
        { label = 'Renommer', action = function(slot) exports.elyzea_clothing:RenameSlot(slot) end },
    },
},

['vet_sac'] = {
    label = 'Sac', weight = 10, stack = false, close = true,
    description = 'Sac : +10 KG de capacité une fois porté.',
    client = { export = 'elyzea_clothing.useClothing' },
    buttons = {
        { label = 'Porter', action = function(slot) exports.elyzea_clothing:EquipFromSlot(slot) end },
        { label = 'Renommer', action = function(slot) exports.elyzea_clothing:RenameSlot(slot) end },
    },
},

['vet_gilet'] = {
    label = 'Gilet', weight = 10, stack = false, close = true,
    description = 'Vêtement : clic droit > Porter.',
    client = { export = 'elyzea_clothing.useClothing' },
    buttons = {
        { label = 'Porter', action = function(slot) exports.elyzea_clothing:EquipFromSlot(slot) end },
        { label = 'Renommer', action = function(slot) exports.elyzea_clothing:RenameSlot(slot) end },
    },
},

['vet_gants'] = {
    label = 'Gants', weight = 10, stack = false, close = true,
    description = 'Vêtement : clic droit > Porter.',
    client = { export = 'elyzea_clothing.useClothing' },
    buttons = {
        { label = 'Porter', action = function(slot) exports.elyzea_clothing:EquipFromSlot(slot) end },
        { label = 'Renommer', action = function(slot) exports.elyzea_clothing:RenameSlot(slot) end },
    },
},

['vet_collier'] = {
    label = 'Collier / cravate', weight = 10, stack = false, close = true,
    description = 'Vêtement : clic droit > Porter.',
    client = { export = 'elyzea_clothing.useClothing' },
    buttons = {
        { label = 'Porter', action = function(slot) exports.elyzea_clothing:EquipFromSlot(slot) end },
        { label = 'Renommer', action = function(slot) exports.elyzea_clothing:RenameSlot(slot) end },
    },
},

['vet_masque'] = {
    label = 'Masque', weight = 10, stack = false, close = true,
    description = 'Vêtement : clic droit > Porter.',
    client = { export = 'elyzea_clothing.useClothing' },
    buttons = {
        { label = 'Porter', action = function(slot) exports.elyzea_clothing:EquipFromSlot(slot) end },
        { label = 'Renommer', action = function(slot) exports.elyzea_clothing:RenameSlot(slot) end },
    },
},

['vet_logo'] = {
    label = 'Logo', weight = 10, stack = false, close = true,
    description = 'Vêtement : clic droit > Porter.',
    client = { export = 'elyzea_clothing.useClothing' },
    buttons = {
        { label = 'Porter', action = function(slot) exports.elyzea_clothing:EquipFromSlot(slot) end },
        { label = 'Renommer', action = function(slot) exports.elyzea_clothing:RenameSlot(slot) end },
    },
},

['vet_chapeau'] = {
    label = 'Chapeau', weight = 10, stack = false, close = true,
    description = 'Vêtement : clic droit > Porter.',
    client = { export = 'elyzea_clothing.useClothing' },
    buttons = {
        { label = 'Porter', action = function(slot) exports.elyzea_clothing:EquipFromSlot(slot) end },
        { label = 'Renommer', action = function(slot) exports.elyzea_clothing:RenameSlot(slot) end },
    },
},

['vet_lunettes'] = {
    label = 'Lunettes', weight = 10, stack = false, close = true,
    description = 'Vêtement : clic droit > Porter.',
    client = { export = 'elyzea_clothing.useClothing' },
    buttons = {
        { label = 'Porter', action = function(slot) exports.elyzea_clothing:EquipFromSlot(slot) end },
        { label = 'Renommer', action = function(slot) exports.elyzea_clothing:RenameSlot(slot) end },
    },
},

['vet_boucles'] = {
    label = 'Boucles d\'oreilles', weight = 10, stack = false, close = true,
    description = 'Vêtement : clic droit > Porter.',
    client = { export = 'elyzea_clothing.useClothing' },
    buttons = {
        { label = 'Porter', action = function(slot) exports.elyzea_clothing:EquipFromSlot(slot) end },
        { label = 'Renommer', action = function(slot) exports.elyzea_clothing:RenameSlot(slot) end },
    },
},

['vet_montre'] = {
    label = 'Montre', weight = 10, stack = false, close = true,
    description = 'Vêtement : clic droit > Porter.',
    client = { export = 'elyzea_clothing.useClothing' },
    buttons = {
        { label = 'Porter', action = function(slot) exports.elyzea_clothing:EquipFromSlot(slot) end },
        { label = 'Renommer', action = function(slot) exports.elyzea_clothing:RenameSlot(slot) end },
    },
},

['vet_bracelet'] = {
    label = 'Bracelet', weight = 10, stack = false, close = true,
    description = 'Vêtement : clic droit > Porter.',
    client = { export = 'elyzea_clothing.useClothing' },
    buttons = {
        { label = 'Porter', action = function(slot) exports.elyzea_clothing:EquipFromSlot(slot) end },
        { label = 'Renommer', action = function(slot) exports.elyzea_clothing:RenameSlot(slot) end },
    },
},
}
