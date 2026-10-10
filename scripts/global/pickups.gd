class_name Pickups extends RefCounted
## Every pickup: its kind, rarity, drop weight, icon, text and tuning. Tune pickups here, like goons in
## Goons.DATA. docs/PICKUPS.md describes the whole system.
##
## A crushed goon still drops something about 5% of the time (walker.gd, plus Clover). What it drops is
## rolled in two steps: a rarity tier (TIER_WEIGHTS, raised by Dice), then an item of that tier by its
## weight `w`, filtered by mode and night and scaled by the goon's faction (`fac`). The 14 original
## pickups keep their own scenes (`scene`); every other id is the generic scene/pickups/pickup.tscn,
## and PickupEffects does what it does.

enum K { SUPPLY, TUNE, BOOST, GADGET, LOOT, CASINO, SKILL, MODE, MOVE }
const KIND_NAMES := ["Supplies", "Tune-ups", "Power-ups", "Gadgets", "Loot", "Casino & Chance", "Skill Challenges", "Mode Specials", "Boosts"]
const KIND_NOTES := [
	"Instant refills and repairs: fuel, hull and the five car systems.",
	"Stat gains for the rest of the run.",
	"Timed effects. Their rings drain above the systems strip.",
	"Held in one slot and fired with the Fire button (E).",
	"Coins, gems and stars.",
	"Prizes of chance. Most play out in the HUD corner; a few pause.",
	"Driving tests in the world. Clear one for its prize.",
	"Only drop in the mode they help.",
	"Held in a second slot and fired with the Boost button (Shift): bursts of speed and jumps.",
]

enum R { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, SYSTEM }
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Always on"]
const RARITY_COLORS := [Color(0.902, 0.863, 0.796), Color(0.384, 0.824, 0.435), Color(0.373, 0.722, 1.0), Color(0.878, 0.439, 1.0), Color(1.0, 0.761, 0.239), Color(0.58, 0.533, 0.478)]

## Mirrors Root.gameModes (same order), because an autoload's enum can't be used in a const.
enum M { COUNTDOWN, SPRINT, MARATHON, DEFENSE, POCALYPSE }
## Mirrors Goons.faction.
enum F { WILD, TRIBE, SCRAP }

## Tier odds before Dice. Each tier above Common is scaled by (1 + Dice / DICE_DIVISOR[tier]).
const TIER_WEIGHTS := [64.0, 26.0, 8.0, 1.6, 0.4]
const DICE_DIVISOR := [0.0, 40.0, 25.0, 18.0, 12.0]
## Ordinary drops: before the tier roll, this share of plain goon drops is a single Coin. It starts at
## ORDINARY_SHARE.x and eases to .y as droppable pickups open (ORDINARY_OPEN_SPAN of them), so the Coin stays
## a big part of the mix however much is unlocked. Giants and bosses (bump > 0) skip it.
const ORDINARY_SHARE := Vector2(0.5, 0.35)
const ORDINARY_OPEN_SPAN := 50.0
## Every PITY-th drop without a Rare or better is a Rare.
const PITY := 25
const GENERIC_SCENE := "res://scene/pickups/pickup.tscn"
## A drop table holding this key is rolled here instead of by weight (Walker.dropTable, Root.getPowerupFromWeights).
const ROLL := "pickups_roll"
const TICKS := 60 #physics ticks per second (never changes; see CLAUDE.md)

## Keys: name, kind, rarity, w (weight inside its tier; 0 = never dropped by goons), icon (texture/icon/<icon>.svg),
## text (the Goonopedia line), ui (the HUD group its flyer lands on), ai (worth to the AI driver, a crush is
## about 12), modes (M values it drops in; missing = all), night (only drops at night), fac (faction ->
## weight multiplier), scene (an original pickup's own scene), secs (a timed effect's length), charges
## (a gadget's or boost's uses), plus each item's own numbers.
## The unlock tree (Unlocks): a pickup with no `parent` is a root of its kind's tree; `start` marks the few
## that are open on a new save (Fuel Can, Coin, Claw Crane), and the other roots are bought. `parent` is the pickup that
## must be open first, `after` more pickups that must all be open too before it can be bought (the Toolbox
## needs all four system parts), `needs` play conditions that open it instead of a price, `price` a price
## other than the one its rarity and depth give it (Unlocks.pickupPrice). Locked pickups never drop and are never offered.
const DATA := {
	#---------------------------------------------------------------- the original 14
	"fuel": {"start":true, "name":"Fuel Can", "kind":K.SUPPLY, "rarity":R.UNCOMMON, "w":32, "icon":"fuel", "scene":"res://scene/powerup/fuel.tscn", "ui":"fuelui", "fac":{F.SCRAP:1.4},
		"text":"Adds 20 fuel."},
	"health": {"price":{"coin":250}, "name":"Repair Kit", "kind":K.SUPPLY, "rarity":R.UNCOMMON, "w":15, "icon":"health", "scene":"res://scene/powerup/health.tscn", "ui":"healthui", "fac":{F.WILD:1.3},
		"text":"Patches up 20 hull."},
	"coin": {"start":true, "name":"Coin", "kind":K.LOOT, "rarity":R.COMMON, "w":20, "icon":"coin", "scene":"res://scene/powerup/coin.tscn", "ui":"coinui",
		"text":"+1 coin. Stars multiply what a run pays."},
	"engine": {"name":"Engine", "kind":K.TUNE, "rarity":R.COMMON, "w":2, "icon":"engine", "scene":"res://scene/powerup/engine.tscn", "ui":"engineui", "stat":true,
		"text":"+1 Engine for this run: harder acceleration."},
	"steering": {"parent":"engine", "name":"Steering", "kind":K.TUNE, "rarity":R.COMMON, "w":2, "icon":"steering", "scene":"res://scene/powerup/steering.tscn", "ui":"steeringui", "stat":true,
		"text":"+1 Steering for this run: the wheels turn further."},
	"traction": {"parent":"steering", "name":"Traction", "kind":K.TUNE, "rarity":R.COMMON, "w":2, "icon":"traction", "scene":"res://scene/powerup/traction.tscn", "ui":"tractionui", "stat":true,
		"text":"+1 Traction for this run: more grip and better brakes."},
	"armor": {"parent":"engine", "name":"Armor", "kind":K.TUNE, "rarity":R.COMMON, "w":2, "icon":"armor", "scene":"res://scene/powerup/armor.tscn", "ui":"armorui", "stat":true,
		"text":"+1 Armor for this run: every hit does less damage."},
	"headlights": {"parent":"engine", "needs":["nights:1"], "name":"Headlights", "kind":K.TUNE, "rarity":R.COMMON, "w":2, "icon":"headlights", "scene":"res://scene/powerup/headlights.tscn", "ui":"headlightsui", "stat":true,
		"text":"+1 Headlights for this run: you see further at night."},
	"oil": {"parent":"armor", "name":"Oil", "kind":K.TUNE, "rarity":R.COMMON, "w":2, "icon":"oil", "scene":"res://scene/powerup/oil.tscn", "ui":"oilui", "stat":true,
		"text":"+1 Oil for this run: the engine burns less fuel."},
	"clover": {"parent":"engine", "name":"Clover", "kind":K.TUNE, "rarity":R.COMMON, "w":2, "icon":"clover", "scene":"res://scene/powerup/clover.tscn", "ui":"cloverui", "stat":true,
		"text":"+1 Clover for this run: crushed goons drop pickups more often."},
	"luck": {"parent":"clover", "name":"Dice", "kind":K.TUNE, "rarity":R.COMMON, "w":2, "icon":"luck", "scene":"res://scene/powerup/luck.tscn", "ui":"luckui", "stat":true,
		"text":"+1 Dice for this run: drops are rarer more often, and slot reels land on better prizes."},
	"purse": {"parent":"coin", "name":"Purse", "kind":K.LOOT, "rarity":R.UNCOMMON, "w":14, "icon":"purse", "scene":"res://scene/powerup/purse.tscn", "ui":"coinui",
		"text":"15 to 100 coins in one go."},
	"gem": {"parent":"coin", "name":"Gem", "kind":K.LOOT, "rarity":R.UNCOMMON, "w":14, "icon":"gem", "scene":"res://scene/powerup/gem.tscn", "ui":"gemui",
		"text":"+1 gem. Gems buy starting gadgets, boosts and unlocks, and are kept after the run."},
	"slotmachine": {"parent":"deal", "price":{"coin":40000}, "name":"Slot Machine", "kind":K.CASINO, "rarity":R.EPIC, "w":10, "icon":"slotMachine", "scene":"res://scene/powerup/slotMachine.tscn", "ui":"slotmachineui", "ai":50,
		"text":"Opens the slot machine. Pairs pay twice, triples five times, and three stars are the jackpot. Bet run coins for better reels."},

	#---------------------------------------------------------------- supplies
	"jerry": {"parent":"fuel", "name":"Jerry Can", "kind":K.SUPPLY, "rarity":R.RARE, "w":8, "icon":"jerry", "ui":"fuelui", "fuel":50.0, "fac":{F.SCRAP:3.0}, "ai":30,
		"text":"Adds 50 fuel in one go. Scrap Gang vehicles carry them."},
	"wrench": {"parent":"health", "name":"Wrench", "kind":K.SUPPLY, "rarity":R.UNCOMMON, "w":6, "icon":"wrench", "ui":"healthui", "repair":35.0, "fac":{F.TRIBE:1.5}, "ai":14,
		"text":"Repairs your most damaged system by 35."},
	"tyre": {"parent":"wrench", "name":"Spare Tire", "kind":K.SUPPLY, "rarity":R.COMMON, "w":1, "icon":"tyre", "ui":"tractionui", "system":"tires", "fac":{F.WILD:2.0}, "ai":10,
		"text":"Puts the tires back to 100. Rattlers, Quills and Shredders wear them."},
	"bulb": {"parent":"wrench", "name":"Bulb", "kind":K.SUPPLY, "rarity":R.COMMON, "w":1, "icon":"bulb", "ui":"headlightsui", "system":"lights", "fac":{F.WILD:2.0}, "ai":8,
		"text":"Puts the lights back to 100. Buzzards dive at them."},
	"sparkplug": {"parent":"wrench", "name":"Spark Plug", "kind":K.SUPPLY, "rarity":R.COMMON, "w":1, "icon":"sparkplug", "ui":"engineui", "system":"engine", "fac":{F.SCRAP:2.0}, "ai":10,
		"text":"Puts the engine back to 100."},
	"tierod": {"parent":"wrench", "name":"Tie Rod", "kind":K.SUPPLY, "rarity":R.COMMON, "w":1, "icon":"tierod", "ui":"steeringui", "system":"steering", "fac":{F.TRIBE:2.0}, "ai":10,
		"text":"Puts the steering back to 100."},
	"tankpatch": {"parent":"jerry", "name":"Tank Patch", "kind":K.SUPPLY, "rarity":R.COMMON, "w":1, "icon":"tankpatch", "ui":"oilui", "system":"tank", "fac":{F.SCRAP:2.0}, "ai":10,
		"text":"Puts the tank back to 100, which stops a leak."},
	"toolbox": {"parent":"tyre", "after":["bulb", "sparkplug", "tierod"], "name":"Toolbox", "kind":K.SUPPLY, "rarity":R.RARE, "w":6, "icon":"toolbox", "ui":"healthui", "repair":40.0, "fac":{F.TRIBE:2.0}, "ai":22,
		"text":"+40 to all five systems."},
	"service": {"parent":"toolbox", "name":"Full Service", "kind":K.SUPPLY, "rarity":R.EPIC, "w":10, "icon":"service", "ui":"healthui", "ai":45,
		"text":"Fuel, hull and every system to full."},

	#---------------------------------------------------------------- tune-ups
	"crate": {"parent":"engine", "name":"Tune-up Crate", "kind":K.TUNE, "rarity":R.UNCOMMON, "w":10, "icon":"crate", "ui":"engineui", "amount":3, "ai":20,
		"text":"+3 to one stat for the run, picked from the car's three weakest."},
	"overhaul": {"parent":"crate", "name":"Overhaul", "kind":K.TUNE, "rarity":R.RARE, "w":10, "icon":"overhaul", "ui":"engineui", "amount":2, "ai":40,
		"text":"+2 to all eight stats for the run."},
	"turbo": {"parent":"overhaul", "name":"Turbo Kit", "kind":K.TUNE, "rarity":R.EPIC, "w":10, "icon":"turbo", "ui":"engineui", "amount":12, "ai":60,
		"text":"+12 Engine for the run, and exhaust flames at full throttle."},
	"blueprint": {"parent":"overhaul", "needs":["open:canyon"], "name":"Blueprint", "kind":K.TUNE, "rarity":R.LEGENDARY, "w":10, "icon":"blueprint", "ui":"starui", "ai":90,
		"text":"Kept after the run: a free garage upgrade for this car's lowest stat, credited on the results ticket however the run ends."},

	#---------------------------------------------------------------- power-ups (timed)
	"magnet": {"name":"Magnet", "kind":K.BOOST, "rarity":R.COMMON, "w":3, "icon":"magnet", "ui":"buffui", "secs":15.0, "radius":700.0, "ai":18,
		"text":"For 15 s: pickups within 700 px fly to the car."},
	"frenzy": {"parent":"magnet", "name":"Coin Frenzy", "kind":K.BOOST, "rarity":R.UNCOMMON, "w":6, "icon":"frenzy", "ui":"buffui", "secs":20.0, "ai":22,
		"text":"For 20 s: every coin counts double, and every crush drops a coin."},
	"freetank": {"parent":"magnet", "name":"Free Tank", "kind":K.BOOST, "rarity":R.RARE, "w":5, "icon":"infinity", "ui":"buffui", "secs":20.0, "fac":{F.SCRAP:2.0}, "ai":20,
		"text":"For 20 s: the engine burns no fuel."},
	"shield": {"parent":"magnet", "name":"Bubble Shield", "kind":K.BOOST, "rarity":R.UNCOMMON, "w":7, "icon":"shield", "ui":"buffui", "secs":15.0, "hits":3, "ai":24,
		"text":"For 15 s, or three hits: blocks every hit, and bumps don't scuff the car."},
	"plow": {"parent":"magnet", "name":"Ram Plow", "kind":K.BOOST, "rarity":R.UNCOMMON, "w":7, "icon":"plow", "ui":"buffui", "secs":15.0, "fac":{F.TRIBE:1.5}, "ai":24,
		"text":"For 15 s: a blade on the front. Head-on hits crush at any speed and ignore armour, shields and shells."},
	"spikes": {"parent":"magnet", "name":"Spiked Rims", "kind":K.BOOST, "rarity":R.UNCOMMON, "w":5, "icon":"spikes", "ui":"buffui", "secs":15.0, "ai":20,
		"text":"For 15 s: goons that touch your sides are crushed, and the tires take no wear."},
	"flood": {"parent":"magnet", "needs":["nights:3"], "name":"Floodlights", "kind":K.BOOST, "rarity":R.UNCOMMON, "w":6, "icon":"flood", "ui":"buffui", "secs":40.0, "night":true, "reach":1.8, "ai":16,
		"text":"For 40 s: headlight reach x1.8, all round the car. Only drops at night."},
	"firetrail": {"parent":"spikes", "name":"Fire Trail", "kind":K.BOOST, "rarity":R.UNCOMMON, "w":5, "icon":"firetrail", "ui":"buffui", "secs":10.0, "ai":20,
		"text":"For 10 s: the tires leave fire. Goons that walk into it burn, and count as crushes."},
	"monster": {"parent":"plow", "needs":["giants:10"], "name":"Monster Tires", "kind":K.BOOST, "rarity":R.RARE, "w":8, "icon":"monster", "ui":"buffui", "secs":10.0, "scale":1.35, "ai":40,
		"text":"For 10 s: a bigger car that crushes every goon at any speed, shells, boulders and giants included."},
	"timewarp": {"parent":"shield", "name":"Time Warp", "kind":K.BOOST, "rarity":R.RARE, "w":8, "icon":"timewarp", "ui":"buffui", "secs":8.0, "rate":0.4, "ai":35,
		"text":"For 8 s: goons move at 40% speed. Your car doesn't."},
	"wrecking": {"parent":"firetrail", "name":"Wrecking Ball", "kind":K.BOOST, "rarity":R.RARE, "w":6, "icon":"wrecking", "ui":"buffui", "secs":20.0, "ai":38,
		"text":"For 20 s: a ball on a chain swings behind the car. Anything it hits is crushed."},
	"golden": {"parent":"frenzy", "name":"Golden Ride", "kind":K.BOOST, "rarity":R.LEGENDARY, "w":10, "icon":"golden", "ui":"buffui", "secs":15.0, "coins":5, "ai":90,
		"text":"For 15 s: invulnerable, crushes at any speed, and every crush pays 5 coins."},

	#---------------------------------------------------------------- gadgets (held, Fire)
	"horn": {"name":"Air Horn", "kind":K.GADGET, "rarity":R.COMMON, "w":2, "icon":"horn", "ui":"itemui", "charges":3, "radius":350.0, "stun":1.5, "fac":{F.TRIBE:2.0}, "ai":14,
		"text":"3 uses. Stuns goons within 350 px for 1.5 s and throws off anything riding the car."},
	"oilslick": {"parent":"horn", "name":"Oil Slick", "kind":K.GADGET, "rarity":R.COMMON, "w":2, "icon":"oilslick", "ui":"itemui", "charges":3, "radius":110.0, "ai":12,
		"text":"3 uses. Drops a slick behind the car; goons that cross it spin out for 2 s."},
	"flare": {"parent":"horn", "needs":["nights:1"], "name":"Flare", "kind":K.GADGET, "rarity":R.COMMON, "w":2, "icon":"flare", "ui":"itemui", "charges":1, "night":true, "secs":25.0, "ai":10,
		"text":"Lights a wide circle for 25 s. Buzzards circle it instead of diving at your lights. Only drops at night."},
	"mine": {"parent":"oilslick", "name":"Land Mine", "kind":K.GADGET, "rarity":R.UNCOMMON, "w":6, "icon":"mine", "ui":"itemui", "charges":3, "radius":190.0, "fac":{F.TRIBE:2.0}, "ai":20,
		"text":"3 uses. Drops a mine behind the car. Goons it blows up count as crushes."},
	"emp": {"parent":"horn", "needs":["crushed:scrap:150"], "name":"EMP", "kind":K.GADGET, "rarity":R.UNCOMMON, "w":5, "icon":"emp", "ui":"itemui", "charges":1, "radius":900.0, "fac":{F.SCRAP:2.5}, "ai":20,
		"text":"Scrap Gang vehicles within 900 px stall for 5 s, harpoons and tow magnets let go, and riders fall off."},
	"bait": {"parent":"horn", "name":"Goon Bait", "kind":K.GADGET, "rarity":R.UNCOMMON, "w":4, "icon":"bait", "ui":"itemui", "charges":1, "radius":1200.0, "secs":8.0, "fac":{F.WILD:2.0}, "ai":16,
		"text":"Drops a steak. Goons within 1200 px go for it for 8 s. In Defense it pulls goons off their march on the station."},
	"hubcap": {"parent":"bait", "name":"Homing Hubcap", "kind":K.GADGET, "rarity":R.RARE, "w":8, "icon":"hubcap", "ui":"itemui", "charges":1, "bounces":6, "ai":28,
		"text":"Throws a spinning hubcap that bounces between up to 6 goons, crushing each."},
	"airstrike": {"parent":"mine", "name":"Airstrike", "kind":K.GADGET, "rarity":R.RARE, "w":8, "icon":"mortar", "ui":"itemui", "charges":1, "radius":230.0, "ai":30,
		"text":"Three blasts walk forward from 400 px ahead of the car."},
	"pocket": {"parent":"flare", "name":"Pocket Station", "kind":K.GADGET, "rarity":R.EPIC, "w":6, "icon":"pocket", "ui":"itemui", "charges":1, "modes":[M.COUNTDOWN, M.SPRINT, M.MARATHON, M.POCALYPSE], "ai":35,
		"text":"A pit stop when you choose: fuel, hull and every system to full."},
	"nuke": {"parent":"airstrike", "name":"Goon Nuke", "kind":K.GADGET, "rarity":R.LEGENDARY, "w":10, "icon":"nuke", "ui":"itemui", "charges":1, "ai":80,
		"text":"Every goon on screen dies, and every one counts as a crush."},

	#---------------------------------------------------------------- boosts (held in the second slot, Boost)
	"nitro": {"name":"Nitro", "kind":K.MOVE, "rarity":R.COMMON, "w":3, "icon":"nitro", "ui":"moveui", "charges":2, "secs":3.0, "thrust":1.8, "top":1.4, "fac":{F.SCRAP:3.0}, "ai":20,
		"text":"2 uses. Each fires 3 s of harder acceleration and a higher top speed."},
	"jets": {"parent":"hop", "name":"Jump Jets", "kind":K.MOVE, "rarity":R.RARE, "w":6, "icon":"jets", "ui":"moveui", "charges":2, "secs":0.8, "radius":160.0, "ai":28,
		"text":"2 uses. A short hop over goons, slime and spikes. Landing crushes everything around the car."},
	"hop": {"parent":"nitro", "name":"Hop", "kind":K.MOVE, "rarity":R.COMMON, "w":3, "icon":"hop", "ui":"moveui", "charges":3, "secs":0.45, "lift":1.15, "ai":12,
		"text":"3 uses. A quick hop over goons, slime and spikes. No landing blast: that takes Jump Jets."},

	#---------------------------------------------------------------- loot
	"coinstack": {"parent":"coin", "name":"Coin Stack", "kind":K.LOOT, "rarity":R.COMMON, "w":6, "icon":"coinstack", "ui":"coinui", "coins":5, "ai":12,
		"text":"+5 coins."},
	"strongbox": {"parent":"purse", "name":"Strongbox", "kind":K.LOOT, "rarity":R.RARE, "w":8, "icon":"strongbox", "ui":"coinui", "ai":40,
		"text":"Drops a heavy box. Ram it three times above 300 px/s to burst it for 150 to 400 coins and a gem."},
	"gemcluster": {"parent":"gem", "name":"Gem Cluster", "kind":K.LOOT, "rarity":R.RARE, "w":10, "icon":"gemcluster", "ui":"gemui", "gems":3, "fac":{F.SCRAP:1.5}, "ai":45,
		"text":"+3 gems."},
	"starfrag": {"parent":"gem", "name":"Star Fragment", "kind":K.LOOT, "rarity":R.RARE, "w":12, "icon":"starfrag", "ui":"starui", "ai":40,
		"text":"Three make a star, and a star multiplies the whole run's payout."},
	"goldgoon": {"parent":"starfrag", "name":"Golden Goon", "kind":K.LOOT, "rarity":R.EPIC, "w":8, "icon":"goldgoon", "ui":"coinui", "coins":250, "secs":25.0, "ai":30,
		"text":"Lets loose a golden goon that runs from you for 25 s. Crush it for 250 coins and a Star Fragment."},

	#---------------------------------------------------------------- casino and chance
	#One tree, weakest first, from the Claw Crane (open on a new save) down three lines: the box-only games
	#(Hubcap Shuffle, Goon Press, Pachinko Drop, Coin Pusher), the tickets (Scratch Card, Lottery Ticket,
	#Prize Wheel) and the gambles (Mystery Box, Double or Nothing, The Deal, Slot Machine). The eight that
	#are also gift box games (CrushPrizes.GAMES) are one unlock: it opens the drop and puts the game in the boxes.
	"scratch": {"parent":"claw", "price":{"coin":3000}, "name":"Scratch Card", "kind":K.CASINO, "rarity":R.RARE, "w":6, "icon":"scratch", "ui":"coinui", "ai":18,
		"text":"Scratches itself in the HUD corner while you drive. Three of a kind pays that prize three times; two of a kind pays it once."},
	"mystery": {"parent":"claw", "name":"Mystery Box", "kind":K.CASINO, "rarity":R.RARE, "w":6, "icon":"mystery", "ui":"buffui", "ai":20,
		"text":"Any pickup from any kind. Its rarity is rolled again, with Dice."},
	"double": {"parent":"mystery", "name":"Double or Nothing", "kind":K.CASINO, "rarity":R.RARE, "w":5, "icon":"double", "ui":"coinui", "secs":4.0, "odds":0.5, "ai":8,
		"text":"Bet the coins earned since your last bet: Accelerate rolls, Brake walks away. Even odds, a little better with Dice."},
	"lottery": {"parent":"scratch", "name":"Lottery Ticket", "kind":K.CASINO, "rarity":R.RARE, "w":4, "icon":"lottery", "ui":"coinui", "ai":10,
		"text":"Three numbers from 0 to 9, checked on the results ticket against the last digit of your crushes, top speed and coins. Each match pays 50; all three pay 500."},
	"wheel": {"parent":"scratch", "name":"Prize Wheel", "kind":K.CASINO, "rarity":R.RARE, "w":0, "icon":"wheel", "ui":"coinui",
		"text":"Found in the world. Drive across it and your speed sets the spin, from BUST to JACKPOT."},
	"deal": {"parent":"double", "price":{"coin":18000}, "name":"The Deal", "kind":K.CASINO, "rarity":R.EPIC, "w":6, "icon":"deal", "ui":"slotmachineui", "ai":40,
		"text":"Pick one of three cards. A gem deals a new hand; run coins raise the hand's rarity. It can also come in a gift box."},
	"claw": {"start":true, "name":"Claw Crane", "kind":K.CASINO, "rarity":R.RARE, "w":5, "icon":"claw", "ui":"slotmachineui", "ai":25, #the weakest prize game (CrushPrizes), so the cheapest (Rare) of them
		"text":"Steer the claw over a heap of prizes and drop it with Accelerate. Prizes can slip on the way up. Run coins buy another grab."},
	#gift box games that goons don't drop (w 0): unlocking one only adds it to the boxes
	"shuffle": {"parent":"claw", "price":{"coin":2000}, "name":"Hubcap Shuffle", "kind":K.CASINO, "rarity":R.RARE, "w":0, "icon":"hubcap", "ui":"slotmachineui",
		"text":"A prize, a coin and some junk go under three hubcaps and they shuffle. Find the prize, then keep it or go again."},
	"press": {"parent":"shuffle", "price":{"coin":6000}, "name":"Goon Press", "kind":K.CASINO, "rarity":R.RARE, "w":0, "icon":"wrecking", "ui":"slotmachineui",
		"text":"Three slams on a fast conveyor: whatever is under the press is yours. Crates pay prizes, goons coins, bombs hurt."},
	"pachinko": {"parent":"press", "price":{"coin":25000}, "name":"Pachinko Drop", "kind":K.CASINO, "rarity":R.EPIC, "w":0, "icon":"bullseye", "ui":"slotmachineui",
		"text":"The dropper slides and swings by itself: time your drops, as many balls at once as you like. The outer cups pay best."},
	"pusher": {"parent":"pachinko", "price":{"coin":60000, "gem":5}, "name":"Coin Pusher", "kind":K.CASINO, "rarity":R.EPIC, "w":0, "icon":"coinstack", "ui":"slotmachineui",
		"text":"Drop coins on the pile and push prizes over the ledge. Can pay several things at once."},

	#---------------------------------------------------------------- skill challenges
	"rings": {"parent":"speedtrap", "name":"Ring Run", "kind":K.SKILL, "rarity":R.UNCOMMON, "w":0, "icon":"ring", "ui":"coinui",
		"text":"Found in the world. Driving through the gold ring starts a chain of 8, each 3 s from the last. Each pays 5 coins; all 8 pay a Rare pickup."},
	"bowling": {"parent":"donut", "name":"Goon Bowling", "kind":K.SKILL, "rarity":R.RARE, "w":0, "icon":"bowling", "ui":"coinui",
		"text":"Ten goons stand in a triangle. A strike pays a Star Fragment and 100 coins, a spare 50."},
	"speedtrap": {"name":"Speed Trap", "kind":K.SKILL, "rarity":R.COMMON, "w":0, "icon":"speedtrap", "ui":"coinui",
		"text":"Found in the world. The camera pays your speed in MPH / 2 as coins."},
	"donut": {"parent":"speedtrap", "name":"Donut Zone", "kind":K.SKILL, "rarity":R.UNCOMMON, "w":0, "icon":"cone", "ui":"engineui",
		"text":"Found in the world. Circle the cone inside its ring for 5 s to win a Tune-up Crate."},
	"bullseye": {"parent":"speedtrap", "name":"Bullseye", "kind":K.SKILL, "rarity":R.UNCOMMON, "w":0, "icon":"bullseye", "ui":"gemui",
		"text":"Found in the world. Come in above 40 MPH and stop on the target. The centre pays a gem, the rings pay coins."},
	"potato": {"parent":"bullseye", "name":"Hot Potato", "kind":K.SKILL, "rarity":R.RARE, "w":5, "icon":"bomb", "ui":"buffui", "secs":10.0, "need":5, "radius":320.0, "ai":10,
		"text":"A bomb lands on your roof. Drive into 5 or more goons within 10 s to blow them all up. Miss, and it costs 25 hull."},
	"truck": {"parent":"rings", "name":"Loot Truck", "kind":K.SKILL, "rarity":R.EPIC, "w":6, "icon":"truck", "ui":"coinui", "secs":40.0, "rams":5, "ai":30,
		"text":"A Scrap Gang loot truck makes a run for it. Every ram spills coins; five rams burst it for a Rare pickup."},
	"delivery": {"parent":"rings", "needs":["wins:sprint:1"], "name":"Delivery", "kind":K.SKILL, "rarity":R.UNCOMMON, "w":3, "icon":"parcel", "ui":"starui", "modes":[M.SPRINT, M.MARATHON], "minHealth":30.0, "ai":25,
		"text":"Carry the parcel to the station without dropping below 30 hull for +1 star."},
	"combo": {"name":"Crush Combo", "kind":K.SKILL, "rarity":R.SYSTEM, "w":0, "icon":"combo", "ui":"coinui", "gap":1.5,
		"text":"Crushes less than 1.5 s apart chain. A chain of 3 doubles coins, and it climbs to x5 at 12."},

	#---------------------------------------------------------------- mode specials
	"stopwatch": {"parent":"ffwd", "needs":["mode:sprint"], "name":"Stopwatch", "kind":K.MODE, "rarity":R.RARE, "w":10, "icon":"stopwatch", "ui":"clockui", "modes":[M.SPRINT, M.MARATHON], "seconds":10.0, "ai":30,
		"text":"+10 s on the clock. Sprint and Marathon."},
	"ffwd": {"name":"Fast Forward", "kind":K.MODE, "rarity":R.RARE, "w":10, "icon":"ffwd", "ui":"clockui", "modes":[M.COUNTDOWN, M.DEFENSE], "seconds":10.0, "ai":30,
		"text":"Takes 10 s off the clock, which these modes win at. Countdown and Defense."},
	"barricade": {"parent":"ffwd", "needs":["mode:defense"], "name":"Barricade Kit", "kind":K.MODE, "rarity":R.UNCOMMON, "w":10, "icon":"barricade", "ui":"itemui", "modes":[M.DEFENSE], "barrier":150.0, "ai":25,
		"text":"Bring it into the station's lot for +150 barrier. Defense."},
	"turret": {"parent":"barricade", "name":"Sentry Turret", "kind":K.MODE, "rarity":R.EPIC, "w":10, "icon":"turret", "ui":"buffui", "modes":[M.DEFENSE], "secs":30.0, "ai":40,
		"text":"Sets up by the station's pumps and shoots goons for 30 s. Kills count. Defense."},
	"compass": {"parent":"stopwatch", "name":"Shortcut Map", "kind":K.MODE, "rarity":R.UNCOMMON, "w":6, "icon":"compass", "ui":"buffui", "modes":[M.SPRINT, M.MARATHON], "secs":15.0, "ai":12,
		"text":"For 15 s: arrows mark a route to the station around water and hills. Sprint and Marathon."},
	"panic": {"parent":"ffwd", "needs":["survive:180"], "name":"Panic Button", "kind":K.MODE, "rarity":R.EPIC, "w":10, "icon":"panic", "ui":"buffui", "modes":[M.POCALYPSE], "secs":30.0, "ai":30,
		"text":"For 30 s: the horde stops getting worse. The clock keeps counting. Goonpocalypse."},
}

## The run setup's loadout, bought with banked gems (main2): a gadget for the Fire slot (LOADOUT) and a
## boost for the Boost slot (BOOST_LOADOUT), each with its price in gems.
const LOADOUT := {"horn": 1, "oilslick": 1, "mine": 2, "emp": 2, "bait": 2, "hubcap": 4, "airstrike": 4}
const BOOST_LOADOUT := {"hop": 1, "nitro": 2, "jets": 4}

## Kinds in the order the Goonopedia lists them.
const KIND_ORDER := [K.SUPPLY, K.TUNE, K.BOOST, K.GADGET, K.MOVE, K.LOOT, K.CASINO, K.SKILL, K.MODE]

#--- run state ----------------------------------------------------------------------------------
static var dropsSinceRare := 0
static var loadout := "" #a gadget bought in run setup; the player's car takes it in _ready
static var boostLoadout := "" #...and a boost
static var textures := {}
static var timeWarp := false #Time Warp: goons skip most physics ticks (Walker._physics_process)
## A lure goons walk to instead of the car (Goon Bait, Flare, the Dinner Bell, a Salt Lick): {pos, until (msec),
## radius, only (verb or &"")}, and optionally rank (only goons of at least this rank), loose (px: it lets go of
## a goon while the car is this close to it) and key (to take it back, removeLure).
static var lures: Array = []
const FOREVER := 1 << 62 #msec: a lure that lasts until it is taken back

## Called when a run starts (Level._ready).
static func resetRun() -> void:
	dropsSinceRare = 0
	timeWarp = false
	lures.clear()
	_lureFrame = -1

## Time Warp: goons act on 2 physics ticks of every 5.
static func goonTickSkipped() -> bool:
	return timeWarp && Engine.get_physics_frames() % 5 >= 2

## Which goons need ask about lures this physics tick (Walker): the lowest rank any lure takes, and whether
## any lure is timed. Worked out once per tick, not per goon, so a permanent rank-gated lure (a Salt Lick) costs
## the fodder nothing and the heavies one look every LURE_POLL ticks.
const LURE_POLL := 8
static var _lureFrame := -1
static var _lureMinRank := 0
static var _lureTimed := false

static func lureCheckDue(rank: int, lured: bool, phase: int) -> bool:
	if lures.is_empty(): return false
	var frame := Engine.get_physics_frames()
	if frame != _lureFrame:
		_lureFrame = frame
		_lureMinRank = 1 << 30
		_lureTimed = false
		for l in lures:
			_lureMinRank = mini(_lureMinRank, int(l.get("rank", 0)))
			if int(l.until) != FOREVER: _lureTimed = true
	if rank < _lureMinRank: return false
	return lured || _lureTimed || (frame + phase) % LURE_POLL == 0

## The lure a goon at `pos` with this verb and rank, `carDist` from the car, should walk to, or Vector2.INF. The
## newest lure in reach wins. Every goon asks every tick while a lure is out, so it walks the list backwards,
## dropping spent lures as it goes, and allocates nothing (it used to copy the list per call).
static func lureFor(pos: Vector2, verb: StringName, rank := 0, carDist := INF) -> Vector2:
	if lures.is_empty(): return Vector2.INF
	var now := Time.get_ticks_msec()
	for i in range(lures.size() - 1, -1, -1):
		var l: Dictionary = lures[i]
		if now > l.until:
			lures.remove_at(i)
			continue
		if l.only != &"" && l.only != verb: continue
		if rank < int(l.get("rank", 0)) || carDist < float(l.get("loose", 0.0)): continue
		if pos.distance_squared_to(l.pos) < l.radius * l.radius: return l.pos
	return Vector2.INF

## Puts a lure out for `seconds` (FOREVER: until removeLure(key)); see lures
static func addLure(pos: Vector2, radius: float, seconds: float, only := &"", rank := 0, loose := 0.0, key := 0) -> void:
	var until := FOREVER if seconds == INF else Time.get_ticks_msec() + int(seconds * 1000.0)
	lures.push_back({"pos": pos, "until": until, "radius": radius, "only": only, "rank": rank, "loose": loose, "key": key})
	_lureFrame = -1

static func removeLure(key: int) -> void:
	for i in range(lures.size() - 1, -1, -1):
		if int(lures[i].get("key", 0)) == key: lures.remove_at(i)
	_lureFrame = -1

#--- lookups ------------------------------------------------------------------------------------

static func has(id: String) -> bool:
	return DATA.has(id)

static func def(id: String) -> Dictionary:
	return DATA.get(id, {})

static func displayName(id: String) -> String:
	return def(id).get("name", id.capitalize())

## Name tags (docs/PICKUPS.md, "Name tags"): the small label printed next to an icon in the HUD's gadget,
## boost and buff slots, on slot reels and in the prize games. The name itself unless it is too long for a
## tag (TAG_MAX_PX at TAG_SIZE, tests check every one).
const SHORT_NAMES := {"crate": "Tune-up", "shield": "Shield", "monster": "Big Tires", "wrecking": "Wreck Ball",
	"hubcap": "Hubcap", "shuffle": "Shuffle", "pachinko": "Pachinko", "pocket": "Pocket Stn", "starfrag": "Star Frag", "double": "Double Up", "lottery": "Lottery",
	"barricade": "Barricades", "turret": "Turret"}
const TAG_SIZE := 12
const TAG_MAX_PX := 84.0

static func shortName(id: String) -> String:
	return SHORT_NAMES.get(id, displayName(id))

static func rarity(id: String) -> int:
	return def(id).get("rarity", R.COMMON)

static func rarityColor(r: int) -> Color:
	return RARITY_COLORS[clampi(r, 0, RARITY_COLORS.size() - 1)]

static func texture(id: String) -> Texture2D:
	var icon: String = def(id).get("icon", id)
	if not textures.has(icon): textures[icon] = load("res://texture/icon/%s.svg" % icon)
	return textures[icon]

## The id of an original pickup scene ("" for any other scene).
static func idForScene(path: String) -> String:
	for id in DATA:
		if DATA[id].get("scene", "") == path: return id
	return ""

static func uiGroup(id: String) -> String:
	return def(id).get("ui", "buffui")

static func ticks(id: String) -> int:
	return int(def(id).get("secs", 0.0) * TICKS)

## Can this pickup turn up in `mode` (a Root.gameModes value)?
static func allowedIn(id: String, mode: int) -> bool:
	var modes: Array = def(id).get("modes", [])
	return modes.is_empty() || Modes.plays(mode) in modes #a variant drops what its base mode does

static func ids(kind := -1) -> Array:
	var out := []
	for id in DATA:
		if kind < 0 || DATA[id].kind == kind: out.push_back(id)
	return out

#--- the drop roll ------------------------------------------------------------------------------

## Tier weights after Dice; Common keeps its weight.
static func tierWeights(dice: float) -> Array:
	var out := []
	for t in TIER_WEIGHTS.size():
		out.push_back(TIER_WEIGHTS[t] if t == 0 else TIER_WEIGHTS[t] * (1.0 + maxf(dice, 0.0) / DICE_DIVISOR[t]))
	return out

## The tier for a 0..1 roll.
static func pickTier(weights: Array, roll: float) -> int:
	var total := 0.0
	for w in weights: total += w
	var r := roll * total
	for t in weights.size():
		r -= weights[t]
		if r < 0.0: return t
	return weights.size() - 1

## Items of a tier with their weights in this mode, at this time of day, for this faction (-1 = none).
static func candidates(tier: int, mode: int, night: bool, faction := -1) -> Dictionary:
	var out := {}
	for id in DATA:
		var d: Dictionary = DATA[id]
		if d.rarity != tier || d.get("w", 0) <= 0 || not allowedIn(id, mode) || not Unlocks.isPickupOpen(id): continue
		if d.get("night", false) && not night: continue
		out[id] = float(d.w) * float(d.get("fac", {}).get(faction, 1.0))
	return out

## A weighted pick from `weights` (id -> weight) for a 0..1 roll; "" when it is empty.
static func pickWeighted(weights: Dictionary, roll: float) -> String:
	var total := 0.0
	for k in weights: total += weights[k]
	if total <= 0.0: return ""
	var r := roll * total
	for k in weights:
		r -= weights[k]
		if r < 0.0: return k
	return weights.keys().back()

## One drop: the tier (with Dice, the pity counter and `bump` tiers up for giants and bosses), then an
## item of that tier. Falls back a tier when nothing in it is allowed here.
static func roll(dice: float, mode: int, night: bool, faction := -1, bump := 0) -> String:
	if bump == 0 && randf() < ordinaryShare():
		dropsSinceRare += 1
		return "coin"
	var tier := pickTier(tierWeights(dice), randf())
	if dropsSinceRare + 1 >= PITY: tier = maxi(tier, R.RARE)
	tier = mini(tier + bump, R.LEGENDARY)
	dropsSinceRare = 0 if tier >= R.RARE else dropsSinceRare + 1
	while tier >= 0:
		var id := pickWeighted(candidates(tier, mode, night, faction), randf())
		if id != "": return id
		tier -= 1
	return "coin" #a tree root: always open

## The share of plain drops that are an ordinary Coin, by how many droppable pickups are open.
static func ordinaryShare() -> float:
	var open := 0
	for id in DATA:
		if DATA[id].get("w", 0) > 0 && Unlocks.isPickupOpen(id): open += 1
	return lerpf(ORDINARY_SHARE.x, ORDINARY_SHARE.y, clampf(open / ORDINARY_OPEN_SPAN, 0.0, 1.0))

## The roll for the player's car right now.
static func rollForCar(faction := -1, bump := 0) -> String:
	var car = Root.playerCar
	var dice: float = car.luck if is_instance_valid(car) else 0.0
	var night: bool = is_instance_valid(Root.spawnManager) && Root.spawnManager.isNight
	return roll(dice, SaveManager.playerData.gameMode, night, faction, bump)

## A drop of at least `minTier` (supply drops, chests, ring runs).
static func rollAtLeast(minTier: int) -> String:
	var car = Root.playerCar
	var dice: float = car.luck if is_instance_valid(car) else 0.0
	var night: bool = is_instance_valid(Root.spawnManager) && Root.spawnManager.isNight
	var tier := maxi(pickTier(tierWeights(dice), randf()), minTier)
	while tier >= 0:
		var id := pickWeighted(candidates(tier, SaveManager.playerData.gameMode, night), randf())
		if id != "": return id
		tier -= 1
	return "coin" #a tree root: always open

## `id` when it is open, else the nearest open pickup above it in its tree (every root is open). Fixed
## rewards (the Prize Wheel's wedges, the Donut Zone's crate, Coin Stack padding...) go through this, so a
## locked pickup never turns up.
static func openOr(id: String) -> String:
	while id != "" && not Unlocks.isPickupOpen(id):
		id = def(id).get("parent", "")
	return id if id != "" else "coin"

## The run setup's gadgets or boosts that are open (id -> gem price), in their listed order.
static func openLoadout(table: Dictionary) -> Dictionary:
	var out := {}
	for id in table:
		if Unlocks.isPickupOpen(id): out[id] = table[id]
	return out

## Prize games (every PickupMenu game and the Pit Shop) never pay these: each
## is a game of its own, or a box that could roll one. Every Casino pickup.
const NOT_IN_GAMES := ["slotmachine", "deal", "claw", "mystery", "scratch", "double", "lottery", "wheel", "shuffle", "press", "pachinko", "pusher"]

## A menu's offer (The Deal, the Pit Shop, the Claw): a drop of at least `minTier` that isn't in `never` or
## `taken`. With few pickups unlocked the tiers may hold nothing new, so it settles for lower tiers, then
## for a repeat, then the Coin.
static func rollOffer(minTier: int, never: Array, taken: Array) -> String:
	for attempt in 8:
		var id := rollAtLeast(minTier)
		if id not in never && id not in taken: return id
	var night: bool = is_instance_valid(Root.spawnManager) && Root.spawnManager.isNight
	var mode: int = SaveManager.playerData.gameMode if SaveManager.playerData else 0
	for allowRepeat in [false, true]:
		for tier in range(R.LEGENDARY, -1, -1):
			var options := candidates(tier, mode, night)
			for id in never: options.erase(id)
			if not allowRepeat:
				for id in taken: options.erase(id)
			var id := pickWeighted(options, randf())
			if id != "": return id
	return "coin"

## A pickup node for `id`, not yet in the tree.
static func make(id: String) -> Node2D:
	var d := def(id)
	if d.has("scene"): return load(d.scene).instantiate()
	var node = load(GENERIC_SCENE).instantiate()
	node.setId(id)
	return node

#--- the Goonopedia -----------------------------------------------------------------------------

## A pickup is shown in the Goonopedia once collected (meta.pickups).
static func isDiscovered(id: String) -> bool:
	return SaveManager.playerData != null && SaveManager.playerData.meta.get("pickups", {}).has(id)

## Marks a pickup as found. Only in memory: the run's save at the results ticket writes it.
static func discover(id: String) -> void:
	if not DATA.has(id) || SaveManager.playerData == null: return
	SaveManager.playerData.meta.get_or_add("pickups", {})[id] = true

## Counts a collected pickup on the car (pickedById), for the run log's pickups by kind.
static func countCollected(car, id: String) -> void:
	if DATA.has(id) && is_instance_valid(car) && "pickedById" in car: car.pickedById[id] = car.pickedById.get(id, 0) + 1

## A run's collected pickups (id -> count) as counts per kind, keyed by KIND_KEYS.
const KIND_KEYS := ["supply", "tune", "boost", "gadget", "loot", "casino", "skill", "mode", "move"]
static func countByKind(byId: Dictionary) -> Dictionary:
	var counts := {}
	for key in KIND_KEYS: counts[key] = 0
	for id in byId:
		if DATA.has(id): counts[KIND_KEYS[DATA[id].kind]] += int(byId[id])
	return counts
