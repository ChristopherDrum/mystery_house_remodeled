temps = {
	{
		picture = pic_cabinet_interior,
		decorations = {matches = 1}
	},
	{
		picture = pic_fridge_interior,
		decorations = {empty_pitcher = 1}
	},
	{
		picture = pic_sink_interior,
		decorations = {butterknife = 1}
	},
	{
		picture = pic_hole_interior,
		decorations = {small_key = 1}
	},	
	{
		picture = pic_chest_interior,
		decorations = {gun = 1}
	},
	{--6
		picture = pic_jewel_note
	},
	{
		picture = pic_math_note
	},
	{
		picture = pic_taunt_note
	},
	{
		picture = pic_basement_note
	},
	{
		picture = pic_trapdoor
	}
}

room_start_pictures = {
pic_frontyard,
pic_front_door_closed,
pic_entryhall_crowded,
pic_kitchen_closed,
pic_forest,
pic_forest,
pic_forest,
pic_forest,
pic_forest,
pic_forest,
pic_forest,
pic_forest,
pic_tree,
pic_library_closed,
pic_sideyard_closed,
pic_dining_room_closed,
pic_backyard_house_closed,
pic_cemetary_open,
pic_pantry,
pic_passageway,
pic_basement,
pic_tunnel,
pic_treetop,
pic_junction,
pic_doorway,
pic_large_bedroom,
pic_doorway,
pic_small_bedroom,
pic_doorway,
pic_nursery,
pic_doorway,
pic_boys_bedroom,
pic_at_stairway,
pic_doorway,
pic_study_closed,
pic_crawlspace,
pic_on_stairway,
pic_bathroom,
pic_attic,
pic_storage_room,
pic_tower
}

rooms = {
	--1 Front Yard
	{
		description = "you are in the front yard of a large abandoned victorian house. stone steps lead up to a wide porch",

		go = {
			stairs = 2, tree = 5, u = 2
		},

		u = {
			stairs = 2,
			fence = "it is too high"
		},

		look = {
			fence = "it is very high",
			tree = "there is a forest"
		},

		jump = {
			fence = "it is too high"
		},
	},

	--2 Porch
	{
		description = "you are on the porch. stone steps lead down to the front yard",

		d = {
			stairs = 1
		},

		open = {
			door = function(self)
				if (var_front_door_open == true) then 
					transcribe("it is open")
				else
					self.picture = pic_front_door_open
					var_front_door_open = true
				end
			end
		},

		close = {
			door = function(self)
				if (var_front_door_open == true) then 
					self.picture = pic_front_door_closed
					var_front_door_open = false
				else
					transcribe("the door is closed")
				end
			end
		},

		go = {
			door = function(self)
				if (var_front_door_open == true) then
					var_front_door_open = false
					var_front_door_locked = true
					next_room = 3
					transcribe("the door has been closed and locked")
				else
					transcribe("the door is closed")
				end
			end,
			stairs = 1,
			d = 1
		}
	},

	--3 EntryHall
	{
		description = "you are in an entry hall. doorways go east, west and south. a stairway goes up",

		after = function(self)
			if (self.picture ~= pic_entryhall_crowded) then
				del_key_from_room("tom")
				del_key_from_room("sam")
				del_key_from_room("sally")
				del_key_from_room("doctor")
				del_key_from_room("joe")
				del_key_from_room("bill")
				del_key_from_room("daisy")
			end
		end,

		go = {
			n = function(self)
					if (self.picture == pic_entryhall_open) then
						self.picture = pic_entryhall_closed
						next_room = 2
					else
						transcribe("the door is closed")
					end
				end,
			s = function(self)
					if (self.picture == pic_entryhall_crowded) self.picture = pic_entryhall_closed
					next_room = 16
				end,
			e = function(self)
					if (self.picture == pic_entryhall_crowded) self.picture = pic_entryhall_closed
					next_room = 14
				end,
			w = function(self)
					if (self.picture == pic_entryhall_crowded) self.picture = pic_entryhall_closed
					next_room = 4
				end,
			u = function(self)
					if (self.picture == pic_entryhall_crowded) self.picture = pic_entryhall_closed
					next_room = 24
				end,
			stairs = function(self)
					if (self.picture == pic_entryhall_crowded) self.picture = pic_entryhall_closed
					next_room = 24
				end,
			door = "which direction?"
		},

		u = {
			--BUG: 'up stairs' does not swap room pic
			stairs = 24
		},

		look = {
			person = function(self)
				if (self.picture == pic_entryhall_crowded) then
					transcribe("the people were explained at the beginning of the game.")
				end
			end
		},

		unlock = {
			door = function(self)
				if (key_in_inventory("small_key")) then
					var_front_door_locked = false
					transcribe("ok")
				else
					transcribe("you have nothing to unlock it with")
				end
			end
		},

		open = {
			door = function(self)
				if (var_front_door_locked == true) then
					transcribe("it is locked")
				else
					self.picture = pic_entryhall_open
				end
			end
		},

		["break"] = {
			door = "it is too heavy"
		}
	},

	--4 kitchen
	{
		description = "you are in the kitchen. there is a refrigerator, stove and cabinet",

		go = {
			door = "which direction?",
			w = function(self)
				if (self.picture == pic_kitchen_open) then
					next_room = 5
				else
					transcribe("the door is closed")
				end
			end,
			e = 3,
			hole = function()
				if (key_in_room("kitchen_hole")) then
					next_room = 19
				else
					command_handled = false
				end
			end
		},

		get = {
			cabinet = "it's too heavy to lift",
			water = function()
				if (var_kitchen_water_running == true) then
					swap(inventory, "empty_pitcher", "full_pitcher", "your pitcher is full", "you have no container")
				else
					transcribe("i see no water")
				end
			end
		},

		light = {
			stove = function()
				transcribe("the stove explodes, you are dead")
				replay_game()
			end
		},

		move = {
			cabinet = function(self)
				if (var_cabinet_moved == true) then
					transcribe("it won't move any further")
				else
					var_cabinet_moved = true
					objects.cabinet[draw_pos] = {33,8}
					decorate(self,"kitchen_bricks")
					transcribe("the wall is bricked up behind it")
				end
			end
		},

		open = {
			cabinet = function()
				objects.cabinet[pic_num] = pic_cabinet_open
			end,
			refriger = function()
				if (objects.refrigerator[pic_num] == pic_fridge_open) then
					transcribe("it is open")
				else
					objects.refrigerator[pic_num] = pic_fridge_open
				end
			end,
			door = function(self)
				if (self.picture == pic_kitchen_open) then
					transcribe("it is open")
				else
					self.picture = pic_kitchen_open
					var_kitchen_open = true
				end
			end
		},

		close = {
			cabinet = function()
				objects.cabinet[pic_num] = pic_cabinet_closed
				temp_room = 0
			end,
			refriger = function()
				if (objects.refrigerator[pic_num] == pic_fridge_closed) then
					transcribe("it is not open")
				else
					objects.refrigerator[pic_num] = pic_fridge_closed
					temp_room = 0
				end
			end,
			door = function(self)
				if (self.picture == pic_kitchen_closed) then
					transcribe("the door is closed")
				else
					self.picture = pic_kitchen_closed
					var_kitchen_open = false
				end
			end
		},

		look = {
			cabinet = function()
				look_inside(objects.cabinet, pic_cabinet_open, 1, "it is not open")
			end,

			refriger = function()
				look_inside(objects.refrigerator, pic_fridge_open, 2, "the door is closed")
			end,
			
			sink = function()
				if (temps[3].decorations["butterknife"]) transcribe("there is a butterknife here")
				temp_room = 3
			end
		},

		faucet = {
			on = function()
				var_kitchen_water_running = true
				transcribe("water is running into the sink")
			end,
			off = function()
				var_kitchen_water_running = false
				transcribe("ok")
			end
		},

		["break"] = {
			wall = function(self)
				if (key_in_inventory("sledgehammer")) then
					swap(self.decorations, "kitchen_bricks", "kitchen_hole","the bricks break apart leaving a large hole")
				else
					transcribe("you have nothing strong enough")
				end
			end,
			bricks = function(self)
				self["break"].wall(self)
			end
		}
	},

	--5 forest maze
	{
		description = "you are in a forest",
		go = {
			n = 12, s = 10, e = 6, w = 8, 
			u = function()
				if (var_kitchen_open == true) then
					next_room = 4
				else
					transcribe("the kitchen door is closed")
				end
			end,
		},
		open = { --there is no "close" routine, just as original
			door = function()
				var_kitchen_open = true
				rooms[4].picture = pic_kitchen_open
				transcribe("the kitchen door is open")
			end
		}
	},
	{ --6
		description = "you are in a forest",
		go = { n = 5, s = 8, e = 7, w = 9 }
	},
	{--7
		description = "you are in a forest",
		go = { n = 6, s = 7, e = 8, w = 10 }
	},
	{--8
		description = "you are in a forest",
		go = { n = 7, s = 5, e = 9, w = 6 }
	},
	{--9
		description = "you are in a forest",
		go = { n = 8, e = 10, w = 6 }
	},
	{--10
		description = "you are in a forest",
		go = { n = 9, s = 7, e = 11, w = 5 }
	},
	{--11
		description = "you are in a forest",
		go = { n = 10, e = 12 }
	},
	{--12
		description = "you are in a forest",
		go = { n = 11, e = 5 }
	},
	{--13
		description = "there is a very tall pine tree in front of you",
		go = { u = 23, d = 9 },
		look = {
			tree = "there is nothing special"
		},
		u = { tree = 23 }
	},

	-- 14 Library
	{
		description = "you are in the old, dusty library",
		go = {
			e = function(self)
				if (self.picture == pic_library_closed) then
					transcribe("the door is closed")
				else
					next_room = 15
				end
			end, 
			w = 3,
			door = "which direction?"
		},
		open = {
			door = function(self)
				if (self.picture == pic_library_open) then
					transcribe("it is open")
				else
					self.picture = pic_library_open
					rooms[15].picture = pic_sideyard_open
				end
			end
		},
		close = {
			door = function(self)
				if (self.picture == pic_library_closed) then
					transcribe("the door is closed")
				else
					self.picture = pic_library_closed
					rooms[15].picture = pic_sideyard_closed
				end
			end
		},
		look = {
			shelves = "there are not many books left"
		},
		get = {
			books = "it does not remove",
			couch = "it is too heavy",
			table = "it is too heavy",
			chair = "it is too heavy"
		}
	},

	--15 Side yard
	{
		description = "you are in the side yard. you can follow the fence to the south",
		go = {
			s = 17, w = 14, --BUG: 'w' doesn't check for open door
			door = function(self)
				if (self.picture == pic_sideyard_closed) then
					transcribe("the door is closed")
				else
					next_room = 14
				end
			end
		},
		open = {
			door = function(self)
				if (self.picture == pic_sideyard_open) then
					transcribe("it is open")
				else
					self.picture = pic_sideyard_open
					rooms[14].picture = pic_library_open
				end
			end
		},
		close = {
			door = function(self)
				if (self.picture == pic_sideyard_closed) then
					transcribe("the door is closed")
				else
					self.picture = pic_sideyard_closed
					rooms[14].picture = pic_library_closed
				end
			end
		},
		u = {
			fence = "it is too high"
		},
		climb = {
			fence = "it is too high"
		}
	},

	--16 Dining Room
	{
		description = "you are in the dining room",

		before = function(self)
			if (key_in_inventory("lit_candle") and var_rug_on_fire == false) then
				var_rug_on_fire = true
				transcribe("you trip over rug and fall. oh,oh, you started a fire with your candle!")
				decorate(self,"dining_room_fire")
			elseif (key_in_room("dining_room_fire")) then
				--this is the only action allowed when the room is on fire
				if (current_verb == "pour" and current_noun == "water" and key_in_inventory("full_pitcher")) then
					command_handled = false
				else
					transcribe("the fire is out of control. you are dead")
					replay_game()
				end
			else
				command_handled = false
			end
		end,

		go = {
			door = "which direction?",
			n = 3,
			s = function(self)
				if (self.picture == pic_dining_room_closed) then
					transcribe("the door is closed")
				else
					next_room = 17
				end
			end
		},

		open = {
			door = function(self)
				if (self.picture == pic_dining_room_open) then
					transcribe("it is open")
				else
					self.picture = pic_dining_room_open
					rooms[17].picture = pic_backyard_house_open
				end
			end
		},

		close = {
			door = function(self)
				if (self.picture == pic_dining_room_closed) then
					transcribe("the door is closed")
				else
					self.picture = pic_dining_room_closed
					rooms[17].picture = pic_backyard_house_closed
				end
			end
		},

		get = {
			rug = "it is too heavy",
			table = "it is too heavy",
			lamp = "it is fastened down"
		},

		light = {
			lamp = "there is no wick"
		},

		pour = {
			water = function(self)
				if (key_in_inventory("full_pitcher") and key_in_room("dining_room_fire")) then
					swap(self.decorations, "dining_room_fire","dining_room_hole", "the fire is out")
					swap(inventory, "full_pitcher", "empty_pitcher", "the pitcher is empty")
				end
			end
		},

		look = { --BUG; hole accessible at all times
			hole = function()
				temp_room = 4
			end
		}
	},

	--17 Backyard
	{
		description = "you are in the fenced back yard. the fence follows the side of the house to the north. there is a dead body here",

		open = {
			door = function(self) --BUG?  open/closed doors don't tell you
				self.picture = pic_backyard_house_open
				rooms[16].picture = pic_dining_room_open
			end,
			gate = function()
				objects.backyard_fence[pic_num] = pic_backyard_fence_open
			end
		},
		close = {
			door = function(self)
				self.picture = pic_backyard_house_closed
				rooms[16].picture = pic_dining_room_closed
			end,
			gate = function()
				objects.backyard_fence[pic_num] = pic_backyard_fence_closed
			end
		},
		go = {
			n = 15,
			door = function(self)
				if (self.picture == pic_backyard_house_closed) then
					transcribe("the door is closed")
				else
					next_room = 16
				end
			end,
			gate = function(self)
				if (objects.backyard_fence[pic_num] == pic_backyard_fence_closed) then
					transcribe("it is not open")
				else
					next_room = 18
				end
			end
		},
		u = {
			fence = "it is too high"
		},
		jump = {
			fence = "it is too high"
		},
		look = {
			body = "it is sam, the mechanic. he has been hit in the head by a blunt object"
		},
		get = {
			body = "it is too heavy"
		}
	},

	--18 Cemetary
	{
		description = "you are in a small fenced cemetary. there are six newly dug graves",

		open = {
			gate = function(self)
				if (self.picture == pic_cemetary_open) then
					transcribe("it is open")
				else
					self.picture = pic_cemetary_open
				end
			end
		},
		closed = {
			gate = function(self)
				if (self.picture == pic_cemetary_closed) then
					transcribe("the door is closed")
				else
					self.picture = pic_cemetary_closed
				end
			end
		},
		go = {
			gate = function(self)
				if (self.picture == pic_cemetary_closed) then
					transcribe("the door is closed")
				else
					next_room = 17
				end
			end,
			graves = function()
				if (var_joe_dead == false) then
					transcribe("you fall in one and joe buries you. you are dead")
					replay_game()
				else
					transcribe("you fall in one and climb out again")
				end
			end
		},
		u = {
			fence = "it is too high"
		},
		jump = {
			fence = "it is too high"
		},
		get = {
			gravesto = "it is too heavy",
			body = "it is too heavy",
			person = "i don't understand you",
			joe = "i don't understand you",
			shovel = function()
				if (var_joe_dead == false) then
					transcribe("joe won't let you")

				else --BUG; teleport shovel
					for r in all(rooms) do
						del_key_from_room("shovel", r)
					end
					add_key_to_inventory("shovel")
				end
			end
		},
		look = {
			gravesto = "the writing is worn down"
		},
		read = {
			gravesto = "the writing is worn down"
		},
		look = {
			joe = "it is joe, the gravedigger. he has just finished digging the six graves",
			person = "it is joe, the gravedigger. he has just finished digging the six graves",
			body = "it is joe, the gravedigger"
		},
		talk = {
			joe = "he doesn't talk much",
			person = "he doesn't talk much"
		},
		kill = {
			joe = "with what?",
			person = "with what?"
		},
		with = {
			dagger = function(self)
				if (key_in_inventory("dagger")) then
					--BUG; dots do not swap for x's
					decorate(self,"joe_xs")
					var_joe_dead = true
					transcribe("there is a dead body here")
				else
					transcribe("you are not carrying it")
					del_key_from_room("joe_dots") --BUG; removes joe's eyes!
				end
			end,
			gun = function(self)
				if (key_in_inventory("gun")) then
					decorate(self,"joe_xs")
					var_joe_dead = true
					var_gun_was_shot = true
					transcribe("there is a dead body here")
					transcribe("your gun is empty")
				end
			end
		}
	},

	--19 pantry
	{
		description = "you are in a small pantry",

		go = {
			d = 20,
			stairs = 20,
			hole = function()
				if (key_in_room("kitchen_hole", rooms[4])) then
					next_room = 4
				else
					transcribe("you go in the hole but cannot continue and have to return")
				end
			end
		},
		
		u = {
			stairs = 20 --BUG; contradicts image
		},

		get = {
			food = "it does not remove",
			jars = "it does not remove",
			boxes = "it does not remove"
		}
	},

	--20 north/south passageway
	{
		description = "you are at the north end of a narrow north/south passageway",

		go = {
			s = 21,
			u = 19,
			stairs = 19
		},

		u = {
			stairs = 19
		}
	},

	--21 basement
	{
		description = "you are in a moist basement. algae covers the walls. there is a dead body here.",

		go = {
			n = 20,
			u = 37,
			hole = 22,
			stairs = 37,
			door = 20
		},

		get = {
			table = "it is too heavy",
			algae = "i don't understand you",
			body = "it is too heavy",
			daisy = "i don't understand you",
			bricks = function(self) --BUG; jewels will teleport to room
				if (key_in_room("bricks")) then
					--we have to do a little extra to recreate this bug
					for r in all(rooms) do
						del_key_from_room("jewels", r)
					end
					del_key_from_inventory("jewels")
					add_key_to_inventory("bricks")

					swap(self.inventory, "bricks", "jewels", nil, nil)
					swap(self.decorations, "bricks", "jewels", "you have found the jewels!", "you have found the jewels!")
				end
			end
		},

		look = {
			body = "it is tom, the plumber. he seems to have been stabbed. there is a daisy in his hand",
			table = "there is a skeleton key here",
			bricks = "it is loose",
			jewels = "they are jewels, all right!"
		},

		wipe = {
			algae = function(self)
				if (key_in_inventory("towel")) then
					if (key_in_room("bricks")) then
						transcribe("ok")
					else
						transcribe("the wall is exposed. there is a loose brick")
						decorate(self,"bricks")
					end
				else
					transcribe("you have nothing to wipe it with")
				end
			end
		},

		["break"] = {
			wall = "it is too hard"
		}
	},

	--22 tunnel
	{
		description = "you are at the south end of a north/south tunnel",
		go = {
			n = 13,
			hole = 21
		},
		look = {
			tunnel = "it is very long"
		}
	},

	--23 treetop
	{
		description = "you are at the top of a very tall pine tree",
		go = {
			d = 13,
			house = "you had better climb down first"
		},
		up = {
			tree = 13 --BUG; "up tree" goes "down"
		},
		get = {
			telescop = "it is fastened down"
		},
		look = {
			telescop = function()
				temp_room = 10
				transcribe("you are looking through the attic window. you see a trapdoor in the attic ceiling")
				decorate(rooms[39], "trapdoor_closed")
			end
		}
	},

	--24 junction
	{
		description = "you are at the junction of an east/west hallway and a north/south hallway",
		go = {
			n = 33,
			e = 25,
			w = 29,
			d = 3,
			stairs = 3,
			hall = "which direction?",
			door = "where?"
		},
		look = {
			door = "where?",
			hall = "which direction?"
		}
	},

	--25 doorway to large bedroom
	{
		description = "there is a doorway here",
		go = {
			e = 27,
			w = 24,
			door = function()
				if (key_in_room("line", rooms[26])) then
					transcribe("a dagger is thrown at you from outside the room. it misses!")
				end
				next_room = 26
			end
		}
	},

	--26 large bedroom
	{
		description = "you are in a large bedroom",
		go = {
			door = function()
				del_key_from_room("line")
				next_room = 25
			end
		},
		get = {
			dagger = function()
				del_key_from_room("line")
				command_handled = false
				-- take_key("dagger")
			end,
			bed = "it is too heavy",
			trunk = "it is too heavy"
		}
	},

	--27 doorway to small bedroom
	{
		description = "there is a doorway here",
		go = {
			w = 25,
			door = 28
		}
	},

	--28 small bedroom
	{
		description = "you are in a small bedroom. there is a dead body here.",
		go = {
			door = 27
		},
		get = {
			body = "it is too heavy",
			bed = "it is too heavy"
		},
		look = {
			body = "it is sally, the seamstress. she has a large lump on her head. there is a blond hair on her dress"
		}
	},

	--29 doorway to nursery
	{
		description = "there is a doorway here",
		go = {
			e = 24,
			w = 31,
			door = 30
		}
	},

	--30 nursery
	{
		description = "you are in an old nursery. there is a dead body here.",
		go = {
			door = 29
		},
		look = {
			body = "it is dr. green. it appears he has been stabbed"
		},
		get = {
			body = "it is too heavy",
			chair = "it is too heavy",
			trunk = "it is too heavy",
			cradle = "it is too heavy"
		}
	},

	--31 doorway to boys bedroom
	{
		description = "there is a doorway here",
		go = {
			e = 29,
			door = 32
		}
	},

	--32 boys bedroom
	{
		description = "you are in a boys bedroom",
		go = {
			door = 31
		},
		get = {
			bed = "it is too heavy",
			trunk = "it is too heavy"
		}
	},

	--33 stairway
	{
		description = "you are at a stairway",
		go = {
			n = 34,
			s = 24,
			u = 39,
			stairs = 39
		},
		u = {
			stairs = 39
		}
	},

	--34 doorway
	{
		description = "there is a doorway here",
		go = {
			s = 33,
			door = 35
		}
	},

	--35 study
	{
		description = "you are in the study",
		go = {
			n = 34,
			e = 38,
			door = "which direction?",
			wall = function(self)
				if (self.picture == pic_study_open) then
					self.picture = pic_study_closed
					objects.picture[draw_pos] = {32,5}
					objects.button[draw_pos] = {51,13}
					self.picture = pic_study_closed
					transcribe("the wall closes behind you with a bang")
					next_room = 36
				else
					command_handled = false
				end
			end
		},
		look = {
			picture = "its nice but not exactly my cup of tea. thanx for the look though."
		},
		get = {
			table = "it is too heavy",
			chair = "it is too heavy",
			picture = function(self)
				if (var_picture_loose == true) then
					decorate(self, "button")
					transcribe("there is a button on the wall")
					command_handled = false
				else
					transcribe("it is fastened to the wall with four bolts")
				end
			end
		},
		unscrew = {
			bolts = "with what?"
		},
		with = {
			butterkn = function()
				if (key_in_inventory("butterknife")) then
					var_picture_loose = true
					transcribe("the picture is loose")
				else
					transcribe("you are not carrying it")
				end
			end
		},
		close = {
			wall = function(self)
				self.picture = pic_study_closed
			end
		},
		press = {
			button = function(self)
				if (self.picture == pic_study_closed) then --BUG; button does not need to be revealed first
					objects.picture[draw_pos] = {200,200}
					objects.button[draw_pos] = {200,200}
					self.picture = pic_study_open
					transcribe("part of the wall opens")
				else
					objects.picture[draw_pos] = {32,5}
					objects.button[draw_pos] = {51,13}
					self.picture = pic_study_closed
				end
			end
		}
	},

	--36 crawlspace
	{
		description = "you are in a musty crawlspace",
		go = {
			d = 37,
			stairs = 37
		},
		open = {
			wall = "it won't open"
		},
		["break"] = {
			wall = "it is too hard"
		}
	},

	--37 on a stairway
	{
		description = "you are on a stairway",
		go = {
			u = 36,
			d = 21,
			stairs = "which direction?"
		}
	},

	--38 bathroom
	{
		description = "you are in the bathroom. there is a dead body here",
		go = {
			door = 35, --BUG; east to get to this room, but west won't go back
			toilet = "thanx. that feels ever so much better"
		},
		faucet = {
			on = function()
				transcribe("water is running into the sink")
				var_bathroom_water_running = true
			end,
			off = function()
				transcribe("ok")
				var_bathroom_water_running = false
			end
		},
		get = {
			water = function()
				if (var_bathroom_water_running == true) then
					swap(inventory, "empty_pitcher", "full_pitcher", "your pitcher is full", "you have no container")
				else
					transcribe("i see no water")
				end
			end,
			body = "it is too heavy",
			shower = "thank you. i love to feel clean. thats much better."
		},
		look = {
			body = "it is bill, the butcher. he has been strangled with a pair of pantyhose"
		},
		flush = {
			toilet = "ok"
		}
	},

	--39 attic
	{
		description = "you are in the attic",
		go = {
			d = 33,
			stairs = 33,
			door = 40,
			window = function()
				transcribe("you fall to earth. luckily you have only minor injuries.")
				transcribe("unfortunately the ambulance driver smashes into a volkwagen. no survivors. you are dead.")
				replay_game()
			end,
			trapdoor = function()
				if (key_in_room("trapdoor_open")) then
					next_room = 41
				elseif (key_in_room("trapdoor_closed")) then
					transcribe("it is not open")
				else
					transcribe("what trapdoor?")
				end
			end
		},
		u = {
			ladder = function()
				if (key_in_room("trapdoor_open")) then
					next_room = 41
				else
					transcribe("you climb up bump your head on the ceiling and fall, dazed but alive.")
				end
			end
		},
		open = {
			trapdoor = function(self)
				if (key_in_room("trapdoor_open")) then
					transcribe("it is open")
				elseif (key_in_room("trapdoor_closed")) then
					del_key_from_room("trapdoor_closed")
					decorate(self,"trapdoor_open")
				else
					transcribe("what trapdoor?")
				end
			end
		},
		close = {
			trapdoor = function(self)
				if (key_in_room("trapdoor_open")) then
					del_key_from_room("trapdoor_open")
					decorate(self,"trapdoor_closed")
				elseif (key_in_room("trapdoor_closed")) then
					transcribe("the door is closed")
				else
					transcribe("what trapdoor?")
				end
			end
		},
		look = {
			window = "you see a forest"
		},
		get = {
			ladder = "it does not remove"
		},
		["break"] = {
			window = "ok"
		}
	},

	--40 storage room
	{
		description = "you are in a storage room",
		go = {
			door = 39,
			window = function()
				transcribe("you fall to earth. luckily you have only minor injuries.")
				transcribe("unfortunately the ambulance driver smashes into a volkwagen. no survivors. you are dead.")
				replay_game()
			end
		},
		get = {
			boxes = "it does not remove",
			trunk = "it is too heavy"
		},
		open = {
			trunk = function(self)
				if (var_trunk_unlocked == true) then
					swap(self.decorations, "trunk_closed", "trunk_open", nil, "it is open")
				else
					transcribe("it is locked")
				end
			end
		},
		close = {
			trunk = function(self)
				swap(self.decorations, "trunk_open", "trunk_closed", nil, "it is not open")
			end
		},
		look = {
			trunk = function()
				if (var_trunk_unlocked == true) then
					if (key_in_room("trunk_open")) then
						temp_room = 5
					else
						transcribe("it is not open")
					end
				else
					transcribe("it is locked")
				end
			end
		},
		unlock = {
			trunk = function()
				if (var_trunk_unlocked == true) then
					transcribe("it is unlocked")
				else
					if (key_in_inventory("small_key")) then
						transcribe("ok")
						var_trunk_unlocked = true
					else
						transcribe("you have nothing to unlock it with")
					end
				end
			end
		}
	},

	--41 tower
	{
		description = "you are in the tower",
		go = {
			trapdoor = 39
		},
		look = {
			daisy = function()
				if (var_daisy_dead == false) then
					transcribe("she is going to kill you")
				else
					transcribe("she is dead")
				end
			end,
			person = function(self)
				self.look.daisy()
			end,
			body = "she is dead" --BUG; does not check for dead state
		},
		kill = {
			daisy = "with what?" --BUG; does not check for dead state
		},
		with = {
			_default = function(msg)
				local msg = msg or "you are not carrying it"
				if (not noun_in_inventory(current_noun)) transcribe(msg)
				transcribe("daisy stabbed you. you are dead")
				replay_game()
			end,
			gun = function(self)
				if (var_daisy_dead == true) then
					transcribe("daisy is already dead")
				else
					if (key_in_inventory("gun")) then
						if (var_gun_was_shot == true) then
							self.with._default("your gun is empty")
						else
							transcribe("your gun is empty")
							var_gun_was_shot = true
							var_daisy_dead = true
							swap(self.decorations, "daisy_dots", "daisy_xs", "daisy is now dead")
						end
					else
						self.with._default()
					end
				end
			end,
			dagger = function(self)
				self.with._default()
			end,
			butterkn = function(self)
				self.with._default()
			end,
			sledgeha = function(self)
				self.with._default()
			end
		},
		get = {
			body = "it is too heavy",
			knife = "i don't understand you",
			note = function()
				if (var_daisy_dead == false) then
					transcribe("daisy won't let you")
				else
					transcribe("ok")
					command_handled = false
				end
			end
		},
		close = {
			trapdoor = "it wont close here"
		}
	}
}

rooms[0] = {
	picture = nil
}