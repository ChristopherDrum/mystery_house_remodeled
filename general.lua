general = {

	help = {
		[""] = function()
			if (rooms[current_room].picture == pic_forest) then
				transcribe("if only i could tell if i'd been here before...")
			else
				transcribe("try going in some direction ex:north, south, east, west, up, down")
			end
		end
	},

	with = {
		gun = function(held)
			if (held and var_gun_was_shot == false) then
				var_gun_was_shot = true
				transcribe("your gun is empty")
			else
				command_handled = false
			end
		end
	},

	go = {
		window = "windows are boarded up except the attic window",
	},

	u = {
		tree = function()
			if (rooms[current_room].picture == pic_forest) then 
				transcribe("there is nothing special")
			else
				command_handled = false
			end
		end
	},

	look = {
		window = "windows are boarded up except the attic window",

		note = function(held)
			if (held) then
				transcribe("there is writing on it")
			else
				--in original, what triggers  "im not carrying that"?
				transcribe("im not carrying that")
			end
		end,

		room = function()
			temp_room = 0
		end, --NOP; side effect sets command_handled to true

		tree = function()
			if (rooms[current_room].picture == pic_forest) then
				transcribe("there is nothing special")
			else
				command_handled = false
			end
		end,

		--bug in the original; description ALWAYS reads one bullet
		gun = "there is one bullet in the gun"
	},

	read = {
		note = function(held)
			if (held) temp_room = objects[held][temp_num]
		end
	},

	light = {
		matches = function(held)
			if (held) then
				var_match_duration = 4
				transcribe("ok")
			else
				transcribe("you are not carrying it")
			end
		end,
		candle = function(held)
			if (key_in_inventory("matches")) then
				swap(inventory, "unlit_candle", "lit_candle", "ok", "you don't have it")
			else
				transcribe("you have nothing to light it with")
			end
		end
	},

	unlight = {
		candle = function(held)
			if (held) then 
				swap(inventory, "lit_candle", "unlit_candle")
			else
				command_handled = false
			end
		end
	},

	drink = {
		water = function()
			swap(inventory, "full_pitcher", "empty_pitcher", "ok", "i dont understand what you mean")
		end	},

	pour = {
		water = function()
			swap(inventory, "full_pitcher", "empty_pitcher", "the pitcher is empty", "i see no water")
		end
	},

	["break"] = {
		window = "windows are boarded up except the attic window"
	},

	quit = {
		[""] = replay_game
	},

	fuck = {
		[""] = function()
			transcribe("if you feel that way i refuse to play with you...")
			quit_game()
		end
	},

	sleep = {
		[""] = "i feel much more rested now"
	},

	save = {
		game = save_game
	},

	restore = {
		game = restore_game
	},

	inventor = {
		[""] = list_inventory
	}
}