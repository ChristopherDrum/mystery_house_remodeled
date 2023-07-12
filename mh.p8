pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
--mystery house 1.0
--by christopher drum
local cartdata_name = "drum_mystery_house_10"

local ticks = 0

first_launch = true
show_image = true
blank_image = false --for darkness
did_show_splashscreen = false
did_start_game = false
did_prompt_replay = false
command_handled = false

local max_lines = 8
local transcript = {}

local input = ""
local command = ""
local start_prompt = "g (gAME) OR i (iNSTRUCTIONS)"
local cmd_prompt = "------ enter command?"
local que_prompt = "?"
local again_prompt = "would you like to play again?"
local prompt = start_prompt

local curs = chr(19)
local curs_pos = 1
local curs_blink = 12

local image_bounds = {0,0,128,80}
local text_bounds = {0,80,128,48}
local screen_bounds = {0,0,128,128}

local delimiter = chr(255)

local init_start = 0x800
local init_lengths = "569,2661,1138,421,52,61,147,144,158,219,624,208,344,219,222,233,65,64,81,31,52,76,20,14,111,50,414,384,149,262,57,74,67,68,302,426,227,291,286,101,41,113,247,260,38,20,57,88,39,284,125,19,398,98,185,119,110,125,310,128,191,189,262,86,252,197,16"
local instructions = ""
local public_domain = ""

local lspr_pal = {
	{7,0,7,0,7,0,7,0,7,0,7,0,7,0,7},
	{0,7,7,0,0,7,7,0,0,7,7,0,0,7,7},
	{0,0,0,7,7,7,7,0,0,0,0,7,7,7,7},
	{0,0,0,0,0,0,0,7,7,7,7,7,7,7,7}
}
local lspr_palt = {0xaaaa, 0xcccc, 0xf0f0, 0xff00}
pictures = {}

inventory = {}

next_room = 0
current_room = -1
temp_room = 0
current_verb = nil
current_noun = nil


function wait_async(t)
	local i=1
	while i<=t do
		i+=1
		yield()
	end
end

function wait_for_key(key)
	while (stat(30) == false) yield()
	poke(0x5f30,1)
	local k = stat(31)
	if (key) then
		if (k == key) return k
		wait_for_key(key)
	end
	return k
end

--object keys with meaningless values
function add_key_to_inventory(obj_key)
	inventory[obj_key] = 1
end

function del_key_from_inventory(obj_key)
	inventory[obj_key] = nil
end

function find_noun_in(noun, inv)
	if (not inv) return nil
	for i = 1, #object_order do
		local obj_key = object_order[i]
		if (inv[obj_key]) then
			local obj_noun = objects[obj_key][dict_name]
			if (noun == obj_noun) return obj_key
		end
	end
	return nil
end

function find_key_in(obj_key, inv)
	return inv[obj_key]
end

function key_in_inventory(obj_key)
	return find_key_in(obj_key, inventory)
end

function noun_in_inventory(noun)
	return find_noun_in(noun, inventory)
end

function decorate(room, obj_key)
	room.decorations[obj_key] = 1
end

function add_key_to_room(obj_key, room)
	room.inventory[obj_key] = 1
end

function del_key_from_room(obj_key, room)
	local room = room or rooms[current_room]
	if (temp_room > 0) then 
		if (temps[temp_room].decorations) then
			temps[temp_room].decorations[obj_key] = nil
		end
	end
	room.decorations[obj_key] = nil
	room.inventory[obj_key] = nil
end

function noun_in_room(noun, room)
	local room = room or rooms[current_room]
	local found = false
	if (temp_room > 0) found = find_noun_in(noun, temps[temp_room].decorations)
	if (not found) found = find_noun_in(noun, room.inventory)
	if ((temp_room == 0) and not found) found = find_noun_in(noun, room.decorations)
	return found
end

function key_in_room(obj_key, room)
	local room = room or rooms[current_room]
	local found = false
	if (temp_room > 0) found = find_key_in(obj_key, temps[temp_room].decorations)
	if (not found) found = find_key_in(obj_key, room.inventory)
	if ((temp_room == 0) and not found) found = find_key_in(obj_key, room.decorations)
	return found
end

function list_inventory()
	for o = 1, #object_order do
		local obj_name = object_order[o]
		if (inventory[obj_name]) then
			transcribe(objects[obj_name][descr])
			wait_async(4)
		end
	end
end

function save_game()
	
	local address = 0x5e00
	memset(address,0,256)

	local bool_string = ""
	local bools = split(bool_names)
	for b = 1, #bools do
		bool_string ..= chr(tonum(_ENV[bools[b]]))
	end

	local var_string = chr(var_match_duration)..","..tostr(var_turn_count)
	local loc_string = chr(temp_room)..chr(next_room)..chr(current_room)
	local inv_string = gather_key_indices(inventory)

	local room_string = ""
	for r = 1, #rooms do
		local room = rooms[r]
		room_string ..= chr(room.picture).."|"..gather_key_indices(room.decorations).."|"..gather_key_indices(room.inventory)
		if (r < #rooms) room_string ..= ";"
	end

	local temp_string = ""
	for t = 1, 5 do
		local temp = temps[t]
		temp_string ..= gather_key_indices(temp.decorations)
		if (t < 5) temp_string ..= ";"
	end

	local object_string = ""
	local objs = split("cabinet,refrigerator,backyard_fence,picture,button")
	for o = 1, #objs do
		local obj = objs[o]
		object_string ..= chr(objects[obj][pic_num])
		object_string ..= chr(objects[obj][draw_pos][1])
		object_string ..= chr(objects[obj][draw_pos][2])
		if (o < #objs) object_string ..= ","
	end

	local save_string = bool_string..delimiter..var_string..delimiter..loc_string..delimiter..inv_string..delimiter..room_string..delimiter..temp_string..delimiter..object_string
	for i = 1, #save_string do
		poke(address, ord(save_string[i]))
		address += 1
	end
end

function restore_game()

	start_game()

	local address = 0x5e00

	local restore_string = ""
	for i = 0, 256 do
		restore_string ..= chr(peek(address+i))
	end
	
	local bool_string, var_string, loc_string, inv_string, room_string, temp_string, object_string = unpack(split(restore_string, delimiter, false))

	local bool_env = split(bool_names)
	for b = 1, #bool_string do
		_ENV[bool_env[b]] = false
		if (ord(bool_string[b]) ~= 0) _ENV[bool_env[b]] = true
	end

	var_match_duration, var_turn_count = unpack(split(var_string, ",", false))
	var_match_duration = ord(var_match_duration)
	var_turn_count = tonum(var_turn_count)

	temp_room = ord(loc_string[1])
	next_room = ord(loc_string[2])
	current_room = ord(loc_string[3])

	inventory = arr_from_key_indices(inv_string)

	local room_objects = split(room_string, ";", false)
	for r = 1, #rooms do
		local pic, deco, inv = unpack(split(room_objects[r], "|", false))
		rooms[r].picture = ord(pic)
		rooms[r].decorations = arr_from_key_indices(deco)
		rooms[r].inventory = arr_from_key_indices(inv)
	end

	local temp_objects = split(temp_string, ";", false)
	for t = 1, 5 do
		temps[t].decorations = arr_from_key_indices(temp_objects[t])
	end

	local objs = split("cabinet,refrigerator,backyard_fence,picture,button")
	local defs = split(object_string,",",false)
	for o = 1, #objs do
		local obj, def = objs[o], defs[o]
		objects[obj][pic_num] = ord(def[1])
		objects[obj][draw_pos][1] = ord(def[2])
		objects[obj][draw_pos][2] = ord(def[3])
	end
end

function replay_game()
	prompt = again_prompt
	did_prompt_replay = true
end


#include vars.lua
#include vocabulary.lua
#include objects.lua
#include rooms.lua
#include general.lua


-- called every frame for cursor feedback
local curs_display = true
function display_transcript()
	if (show_image == true) then
		clip(unpack(text_bounds))
	else
		clip()
	end
	rectfill(0,0,127,127,0)

	--suppress input prompt if we're handling a command
	local y_offset = 122

	if (command_handled == false) then
		if (ticks % curs_blink == 0) curs_display = not curs_display
		local user_input = input
		if (curs_display == true) then
			user_input = sub(input,1,curs_pos-1)..curs..sub(input,curs_pos+1)
		else
			-- suppress jumping when cursor crosses to second line
			if (curs_pos + #prompt == 33) y_offset -=6
		end
	
		local lines = split(prompt..user_input,32)
		for i = #lines, 1, -1 do
			print(lines[i], 1, y_offset, 7)
			y_offset -= 6
		end
	end
	local lines_remaining = min(20,#transcript)
	local last_line = max(1, #transcript-lines_remaining)
	for i = #transcript, last_line, -1 do
		print(transcript[i], 1, y_offset, 7)
		y_offset -= 6
	end

	flip()
	clip()
end

function draw_image(pic_num, offset, c)
	if (not pic_num) return
	local offset = offset or {0,0}
	local c = c or 7

	local pic = pictures[pic_num]
	if (type(pic) == "table") then
		local x,y,w,h,l = unpack(pic)
		lspr(x,y,w,h,offset[1],offset[2],l)
	else
		local islands = split(pic, delimiter)
		for i in all(islands) do
			line()
			for p = 1, #i, 2 do
				local x, y = ord(i[p])-93, ord(i[p+1])-93
				x += offset[1]
				x &= 0x7F --BUG; for room inventory
				y += offset[2]
				line(x,y,c)
			end
			line()
		end
	end
end

function draw_room_backdrop(room)
	local pic_num = room.picture
	if (temp_room > 0) pic_num = temps[temp_room].picture
	draw_image(pic_num)
end

function draw_room_decorations(room)
	if (current_room < 1) return
	local decorations = room.decorations

	if (temp_room > 0) then
		decorations = temps[temp_room].decorations
	end

	for k,v in pairs(decorations) do
		draw_image(objects[k][pic_num], objects[k][draw_pos])
	end	
end

function draw_room_inventory(room)
	if ((current_room < 1) or temp_room > 0) return

	--this is dumb, but its how the original works
	local j = 1
	for i = 1, #object_order do
		local obj_key = object_order[i]
		if (room.inventory[obj_key]) then
			local pn = objects[obj_key][pic_num]
			local dp = drop_positions[j]
			draw_image(pn, dp)
			j += 1
		end
	end
end

function draw_room(room)
	if (show_image == false) return
	if (prompt ~= que_prompt) venetian_blinds()

	clip(unpack(image_bounds))
	rectfill(0,0,127,127,0)

	if (current_room <= 0) then
		--splashscreen reuse
		lspr(0,0,33,22,3,4,1)
		lspr(33,0,48,18,36,4,1)
		lspr(81,0,18,22,83,4,1)
		lspr(0,0,71,20,54,27,2)
		lspr(0,0,62,28,18,41,3)
		lspr(62,18,32,11,80,59,3)

	elseif (blank_image == false) then
		draw_room_backdrop(room)
		draw_room_decorations(room)
		draw_room_inventory(room)
	end
	flip()
	clip()
end

function compose_lines(str)
	if (not str) return 
	local paragraphs = split(str, "\n", false)
	local lines = {}
	for i = 1, #paragraphs do
		local para = paragraphs[i]
		local words = split(para, " ", false)
		local line = words[1]

		for j = 2, #words do
			local word = words[j]
			line ..= " "
			if (print(line..word,0,-20) > 127) then
				add(lines, line)
				line = ""
			end
			line ..= word
		end
		add(lines, line)
	end
	return lines
end

function transcribe(str,wait)
	if (not str) return
	local wait = wait or 50
	local lines = compose_lines(str)
	for i = 1, #lines do
		add(transcript, lines[i])
		display_transcript()
		if (i % max_lines == 0) wait_for_key()
	end
	wait_async(wait)
end

function lspr(sx,sy,sw,sh,x,y,layer)
	pal(lspr_pal[layer],0)
	palt(lspr_palt[layer])
	sspr(sx,sy,sw,sh,x,y)
	pal()
end

function show_splashscreen()
	did_show_splashscreen = true
	draw_room()
	lspr(0,0,108,18,11,80,4)
	print("\f5bY kEN AND rOBERTA wILLIAMS\npICO-8 PORT BY cHRISTOPHER dRUM", 1, 116)
	flip()
	wait_async(180) --roughly match original pause time?
	cls()
	local lines = compose_lines(public_domain)
	for i = 1, #lines do
		print(lines[i],1,((i-1)*6)+1,7)
	end
	wait_for_key()
	cls()
	command_handled = true
end

function venetian_blinds()
	if (show_image == false) return
	clip(unpack(image_bounds))
	for j = 0, 7 do
		wait_async(2)
		for i = 0, 15 do
			local y = i<<3
			rectfill(0,y+j,128,y+j,0)
		end
		flip()
	end
	clip()
end

function show_instructions()
	for paragraph in all(instructions) do
		cls()
		local lines = compose_lines(paragraph)
		for i = 1, #lines do
			print(lines[i], 1, ((i-1)*6)+1, 7)
		end
		flip()
		wait_for_key('\r')
	end
	cls()
	start_game()
end

function init_vocabulary(raw_strings, vocab_table)
	for str in all(raw_strings) do
		local words = split(str)
		local common = sub(words[1],1,8)
		for i in all(words) do
			vocab_table[sub(i,1,8)] = common
		end
	end
end

function init_from_data()
	local base = init_start
	local lengths = split(init_lengths)

	for i = 1, #lengths do
		local raw = ""
		for j = 0, lengths[i]-1 do
			raw ..= chr(peek(base+j))
		end
		base += lengths[i]

		if (i == 1) public_domain = raw
		if (i == 2) instructions = split(raw, delimiter, false)
		if (i == 3) object_defs ..= raw --append the overflow
		if (i > 3) add(pictures, raw) 
	end

	for s = 1, #sprites do
		add(pictures, sprites[s])
	end
end

function init_objects()
	object_order = {}
	local objs = {}
	
	local all_defs = split(object_defs, "|")
	for d = 1, #all_defs do
		local obj_name, dict_name, descr, room, pic, posx, posy, temp = unpack(split(all_defs[d]))
		add(object_order, obj_name)
		if (descr == "nil") descr = nil
		pic = _ENV[pic]
		objs[obj_name] = {dict_name, descr, room, pic, {posx, posy}}
		if (temp) add(objs[obj_name], temp)
	end
	objects = objs
end

function init_rooms()
	for r = 0, #rooms do
		rooms[r].inventory = {}
		rooms[r].decorations = {}
		rooms[r].picture = room_start_pictures[r]
	end
	for k,v in pairs(objects) do
		local rn = tonum(v[room_num])
		decorate(rooms[rn], k)
	end
end

function start_game()
	init_objects()
	init_rooms()
	inventory = {}
	transcript = {}

	did_start_game = true
	prompt = cmd_prompt
	input = ""
	next_room = 1
	var_turn_count = -1 --because we run one extra "turn" on game start
	command_handled = true
	did_prompt_replay = false
	temp_room = 0
	current_verb = nil
	current_noun = nil

	var_front_door_open 	= false
	var_front_door_locked = false
	
	var_match_duration = 0
	var_darkness_arrived = false
	
	var_gun_was_shot = false
	var_cabinet_moved = false
	var_kitchen_open = false
	var_kitchen_water_running = false
	
	var_joe_dead = false
	var_picture_loose = false
	var_bathroom_water_running = false
	var_trunk_unlocked = false
	var_daisy_dead = false
	var_rug_on_fire = false

	transcribe("\n\n\n\n",0)

end

function _init()
	cartdata(cartdata_name)
	poke(0x5f2d,3)
	poke(0x5f36,0x40) --disable text scrolling
	init_from_data()
	init_vocabulary(raw_verbs, verb_table)
	init_vocabulary(raw_nouns, noun_table)
	cls(0)
end

function _update60()
	poke(0x5f30,1)
	ticks += 1
	if (did_show_splashscreen == false) show_splashscreen()

	if (command_handled == true) then
		current_room = next_room
		local room = rooms[current_room]
		draw_room(room)
		if (prompt == cmd_prompt) transcribe(room.description,0)
		command_handled = false
	end

	local keypress
	if (stat(30)) then
		keypress = stat(31)
	else 
		if (btnp(0)) keypress = '⬅️'
		if (btnp(1)) keypress = '➡️'
		if (btnp(2)) keypress = '⬆️'
		if (btnp(3)) keypress = '⬇️'
	end

	if (keypress) then
		if (keypress == '\r') then
			for line in all(split(prompt..input, 32)) do
				add(transcript, line)
			end
			parse_input()
		elseif (keypress == '\b') then
			input = sub(input,1,max(0,curs_pos-2))..sub(input,curs_pos)
			curs_pos -= 1
		elseif (keypress == '⬅️') then
			curs_pos -= 1
		elseif (keypress == '➡️') then
			curs_pos += 1
		elseif (keypress ~= '') then
			input = sub(input,1,curs_pos-1)..keypress..sub(input,curs_pos)
			curs_pos += 1
		end
		curs_pos = min(max(curs_pos,1), #input+1)
	end

	if (command_handled == true) run_timers()

	display_transcript()
end


function parse_input()

	command_handled = false

	if (did_start_game == false) then
		if (input == 'i') then 
			show_instructions()
		elseif (input == 'g') then
			start_game()
		else
			transcribe("\n\n\n\n",0)
		end
		return
	end

	if (did_prompt_replay == true) then
		if (input[1] == "n") then
			quit_game()
		else
			start_game()
		end
		return
	end

	--<RETURN> means "toggle image"
	if (input == nil or input == "") then
		show_image = not show_image
		command_handled = true
		prompt = que_prompt
		return
	end
	prompt = cmd_prompt

	--get the potential verb/noun pair
	local p_verb, p_noun = unpack(split(input, " "))
	p_verb = sub(p_verb, 1, min(#p_verb,8))
	if (not p_noun) p_noun = ""
	p_noun = sub(p_noun, 1, min(#p_noun,8))
	input = ""

	--normalize potential verb/noun against vocabulary list
	current_verb = verb_table[p_verb]
	if (directions[current_verb] and p_noun == "") then
		p_noun = current_verb
		current_verb = "go"
	end
	current_noun = noun_table[p_noun]


	local function try(_handler, _object)
		if (_handler) then
			command_handled = true
			if (type(_handler) == "string") then
				transcribe(_handler)
			elseif (type(_handler) == "number") then
				next_room = _handler
			elseif (type(_handler) == "function") then
				_handler(_object)
			end
		end
	end

	--rooms can intercept actions before/after parser; see dining room fire
	local room = rooms[current_room]

	local before_handler = room["before"]
	if (before_handler) try(before_handler, room)

	local verb_handler
	if (command_handled == false) then
		verb_handler = room[current_verb]
		if (verb_handler) then
			local noun_handler = verb_handler[current_noun]
			try(noun_handler, room)
			if (command_handled == true and current_verb == "go") temp_room = 0
		end
	end

	local player_obj = noun_in_inventory(current_noun)
	if (command_handled == false) then
		verb_handler = general[current_verb]
		if (verb_handler) then
			local noun_handler = verb_handler[current_noun]
			try(noun_handler, player_obj)
		end
	end

	if (command_handled == false) then
		command_handled = true
		local room_obj = noun_in_room(current_noun)

		if (not verb_table[current_verb]) then
			transcribe("i dont know how to "..p_verb.." something")

		elseif (not noun_table[current_noun]) then
			transcribe("i dont know how to "..p_verb.." a "..p_noun)
		else
			--handle verbs that work against multiple nouns
			if (current_verb == "get" and room_obj) then
				if (not objects[room_obj][descr]) then
					transcribe("it doesnt move")
				else
					-- objects[room_obj][draw_pos] = nil
					add_key_to_inventory(room_obj)
					del_key_from_room(room_obj)
				end

			elseif (current_verb == "get" and not room_obj) then
				transcribe("i dont see it here")

			elseif (current_verb == "drop" and player_obj) then
				temp_room = 0
				del_key_from_inventory(player_obj)
				add_key_to_room(player_obj, room)
		
			elseif (current_verb == "look") then
				transcribe("there is nothing special")

			elseif (current_verb == "go" and directions[current_noun]) then
				transcribe("i cant go in that direction")

			else
				transcribe("i dont understand what you mean")
			end
		end
	end

	local after_handler = room["after"]
	if (after_handler) try(after_handler, room)
end

function run_timers()
	if (did_prompt_replay == true) return

	blank_image = false

	if (var_match_duration == 1) transcribe("the match went out")
	var_match_duration = max(1,var_match_duration)
	var_match_duration -= 1

	if (var_turn_count >= 36 and var_match_duration == 0) then
		if (not key_in_inventory("lit_candle")) then
			blank_image = true
			transcribe("it is dark, you can't see")
		end
	end

	if (var_turn_count >= 20 and var_darkness_arrived == false) transcribe("it is getting dark")
	var_darkness_arrived = (var_turn_count >= 35)

	--win condition is off by one if we check "current room"
	if (next_room == 1) then
		if (key_in_inventory("jewels") and var_daisy_dead == true) then
			transcribe("congratulations you have beaten adventure and are declared a guru wizard")
			replay_game()
		end
	end

	while (#transcript > 25) do
		deli(transcript, 1)
	end

	var_turn_count += 1
end

--swap when you have exact object key values, like filled/empty pitcher
function swap(tabl, old, new, success, failure)
	if (tabl[old]) then
		tabl[old] = nil
		tabl[new] = 1
		if (success) transcribe(success)
	else
		--this duplicates bugs, as with breaking the wall with the sledgehammer
		local failure = failure or success
		if (failure) transcribe(failure)
	end
end

function look_inside(obj, valid_pic, temp_num, failure)
	if (obj[pic_num] == valid_pic) then
		temp_room = temp_num
	else
		transcribe(failure)
	end
end

function gather_key_indices(arr)
	local key_indices = ""
	for i = 1, #object_order do
		if (arr[object_order[i]]) key_indices ..= chr(i)
	end
	return key_indices
end

function arr_from_key_indices(str)
	local arr = {}
	for i = 1, #str do
		local index = ord(str[i])
		local key = object_order[index]
		if (key) arr[key] = 1
	end
	return arr
end

function quit_game()
	input = ""
	prompt = ""
	transcribe("thank you for playing hi-res adventure ... good-bye")
	cursor(0,0)
	extcmd("shutdown")
end

__gfx__
00000000044445fee665533333110000331100011111000000000111000000444444444444444444444444444440000000000001133328c8c888800444000000
0000000cee221ba98039eed88a221003102211188aa3300088883222333101773333211111100011111323333762222222222607204516800004800040000440
000000ce88030a8903ba89cc8002303300031008aa88331999bbb000002b9be8c4455744ccdcddd4444655444150005111400261022053a88899880444044444
0000448a80128a89132089995401223000112008a8883388aa888800089baac88c0051a8889998880002412600fa03ba02320625b9d604b38109100000000440
000440a88130aa9132009bab2441031021102003388a388a20088a21199aa059ae241db988998c88110207160ad219a0021002a8a8a10040b229000022000000
00040aa89328a8912002ba930051032221002112188ab8a2001aa83089a201ca9c259add8018c8d1111203560bd218a003308aecce403200801a224464200220
00440a89120aed56644b98920054010231021123888b913111ba8a109aa098e89641aed4400c89140102138e8bca98a8134cceeecc464132a118042200600202
04408a89020acd02002dc8120114d98a9803103188bb02200bb8a108b8219ac92655ed9008cdd544100213069a61982012620208aa2004108323e44002622802
0400aa91229e896602398d502108d88b9820147ccbb000209ba8a102b8a00be106328d8008d900051003100c90598001104042c8840401409140d2264444cc20
4400a99020be88214298890432016621112457fddb0000aa99aa132299a2016215001d888150051400033aafaafaaab326226288c004104108148148262680a0
4aaab98aabf882312598900670102621036403dcaa8888aa980230099aa8005204011c88915114040111008d01d8001104000c88004100501801c899400c6280
ca89988899c80310278890027102261103502898a8c8888bb0012a99aa0011420455444ddc444444554544dd10c80110040008cc44445dc80908950810680008
60098801dc8803002f881223140306102217c88b0888cc0562458bdea011226005100019880111111001089508c0010004440c80040008008891005c54a00008
62ba8037ba8033001aea32000433071020299c8304048c95426d9ea4010220405546655ddc44554444454444415011000000c880044400800800326905a0000a
41a88135a881332899d8990023702511379988416226eafaec1d8ead9fbbbbf7bba8a9889900011100011000154010022004ccc4440040811133555f55d11338
59a88369a89361aa88d889133140350044cce41144424c98c815eac8c888884ddcccfdccc5544444544455555441102002620000011151191311511b33b64008
43111249b912418aabcc8222110436000ccee3100020019888133aa888888099888b98880010000010000001100100200040262226744408200420e021820408
4222260a88020051322266011005173333331322222223333323133333333332333100000011111110022001001100022264440024072242804006c021f1536a
4444440200224000000004010005040004ccc888cc88cc8888ccc888ccc884400448ccccc888cceaacca8ed88ddcc88004026242040502620aece86013a4001c
040000022260404000000410001144004ccc44804c04440000454800c4404c4044484444000066600642056267666e2226226226620852060420404101bdec8d
040000000040004040002632233262266e22e62f77b77222267411944c4055d1440c400000264440464245025540c400040442408c08474204240647446c5285
226222222222626222202411110400044c80c405c44c41551564000d559144c0548cccceaa8ccc8aeccced9dfc88cc80044402408488023224640421002c14e1
31551111115140004020242020600024480ee407f57e60204460000c448040c4450ce66000046620444466266622222aa20004208048803020000602120c1081
3026600200236042602024222462002448a4c8ecacffb9bbddf9888ccc8cc8c4443e488888aecc8cc8cccc8ccc8cc8aa800004208260803002200400311d0081
b8aaecaaa88bc8e000202423753331177d7ff166846c21266420115c62a641d6621cc4c42a44c004404440044c46e21180004222a200d30000022622500c0090
b0202464200340e220202445000000004c4489cc88cc899dccecc8cec88cfaa5405c4eea88ccc88cc88cc888eeed998893262000a001a40000004004511d1180
b008888ccc890080002020010000000008008100800800091939111a208010b2001a2080080080000000222239108022a0544446c647c4400088c004050c0080
b0082000244d46e444646445444444444c44c544c44c444c446c445c46e455c4676e44c44c44c444444464556c46b300800150608061c00008004840041c0080
b008aaa8aa8922800020200100000000080081008008000088a0000900822080102a208008008000000002013a2080008022fbc88ac9c888808840c0445c0080
f408246826696680406024014040000008008100844c400000200009008002a102080280080080000000020029008000817580422041444c0c44c448410844c0
f048c8c8c8c944804460644144400000008081008048400000200008118001922000a280080080000000020208118011942084600040104804880c80410800c0
fffbffbbffbbeae26660626337333333333bbbaaaaeeeaaaaaa88888889998800222288888888888888888a8888899888446eaa888cccd999dddd111144ccc80
906627f6d6021602762756164702d6f6d656e6470296e60286963747f62797a302d69737475627970286f6573756c20247865602669627374702762716078696
360216466756e647572756c20277163702362756164756460296e602139383030226970237965627271602f6e6d2c696e6560266f657e64656273702b656e602
16e6460227f62656274716027796c6c69616d637c20216e646022756c656163756460296e647f60247865602075726c696360246f6d61696e60296e602139383
730247f6023656c6562627164756023796562727167237027347860216e6e69667562737162797e2a09077560256e636f657271676560297f6570247f6023786
1627560247869637027616d656e20296660297f65702861667560256e6a6f69756460296470297f65702d61697023756e64602160242530246f6e6164796f6e6
0247f602b656e60216e6460227f62656274716723702661667f6279647560236861627964797c2023796562727160286963747f6279636023796475637021637
37f63696164796f6e6c20207e2f6e20226f68702435313c202f616b68657273747023616029333634343a090e6f64756a3022656361657375602964702963702
e6f6770266275656c202379656272716723702769666470247f60297f657c2027756023616e602e6f602c6f6e6765627024716b656023616c6c63702f6e60247
869637027616d656e20296660297f65702e6565646028656c607c20207c6561637560236f6e63757c6470216027716c6b6478627f6577686e296e63747275736
4796f6e6370266f627028696d22756370216466756e647572756a0a016466756e64757275602963702f6e65602f6660247865602d6f637470266163696e61647
96e6760216e64602368616c6c656e67696e676027616d656370216671696c61626c6560266f6270297f6572702079636f6d283e2027796e6e696e67602963702
1757964756021602368616c6c656e676560296e60216027616d65602778656275602964702d61697024716b6560286f65727370247f602d6f667560216e64602
775656b6370247f60237f6c667560216020757a7a7c656e2028696d22756370216466756e647572756023213028272d69737475627970286f657375672920247
16b656370207c61636560296e60216e60286f6c6460286f6573756027796478602d616e6970227f6f6d637e20216370297f6570256e6475627024786560286f6
573756c20237566756e602f6478656270207562737f6e637027796c6c60226560296e60247865602c6966796e6760227f6f6d6e202566756e6475716c6c69702
47865697021627560246963707562737564602478627f6577686f65747024786560286f65737560216e6460297f657023747162747026696e64696e676024786
56d602d20246561646120297f65702d6573747026696e6460247865602b696c6c6562702265666f6275602865682378656f3920256e6463702570702b696c6c6
96e6760297f657e2a0c026020202020202020727563737022756475727e60247f60236f6e64796e65756ffa097f657020727f6762756373702478627f6577686
024786560286f6573756022697020727f667964696e676024777f60277f627460236f6d6d616e6460277869636860257375716c6c6970236f6e6471696e60216
02675627260216e64602478656e6021602e6f657e60226574702162756e672470216c6771697370296e6024786164702f627465627e202568716d607c6563702
1627560272771647562702f6e6720216e6460272f60756e60246f6f62772e202966602160237564702f6660277f62746370246f65637e64702375656d60247f6
0226560277f627b696e676024727970246966666562756e64702475627d696e6f6c6f67697a0a096660297f657023786f657c646026696e64602160237471696
27361637560297f65702d616970247279702725707023747169627377202f627027276f60237471696273772e20237f6d65602f666024786560216364796f6e6
370297f657023616e6024716b6560216275602765647c2024627f607c20276f6c202c6f6f6b6c20227561646c20236c696d626c202d6f66756c202869647c202
b696c6c602564736e2a0a0c026020202020202020727563737022756475727e60247f60236f6e64796e65756ffa0a0a097f65702d616970276f60296e6024786
560246962756364796f6e63702e6f6274786c20237f6574786c20256163747c20277563747c20257070216e6460246f677e6e2024797075602e6f627478602f6
2702e60247f60276f602e6f6274786e20247865602f6478656270246962756364796f6e602d616970216c637f602265602162626275667961647564602163702
7756c6c6e202778656e60297f65727027716970296370226c6f636b656460216e6460297f657023616e67247025737560246962756364796f6e6370247f602d6
f667560297f65702d6169702861667560247f60227566656270247f602478656021636475716c602f626a65636470296e60297f6572702771697e20296e60247
865637560236163756370297f6570236f657c6460247970756027276f60246f6f62772c2027276f60286f6c65672c2027276f602761647567202564736e2a0a0
c026020202020202020727563737022756475727e60247f60236f6e64796e65756ff96e6027656e6562716c6024786560247f60702f666024786560237362756
56e60296e602e6f6274786e2024786560226f64747f6d60296370237f6574786c20247865602c6566647023796465602963702775637470216e6460247865602
279676864702379646560296370256163747e2022656361657375602f666024786560246966666963657c6479702f666024627167796e6760246f6f627771697
370247f6024786560237f657478602f627024786560226f64747f6d602f66602478656023736275656e6c20247865627560216275602f6e65602f627024777f6
0227f6f6d637027786562756024786560246f6f627771697370246f602e6f64702d6164736860257070247f60247865602e6f627d616c60246962756364796f6
e637e2a0a096660297f657027716e64702160236c6f637562702c6f6f6b60216470237f6d656478696e6760237169702c6f6f6b60282f626a656364792e20247
f6022756475727e60247f60247865602d61696e602679656770237169702c6f6f6b60227f6f6d6e2a0a03716675602761667560216e6460227563747f6275602
7616d65602d616970216c637f60226560257375646e2a0a0c026020202020202020727563737022756475727e60247f60236f6e64796e65756ff1602e6f64756
02f666023616574796f6e6a302361627279796e67602d6f6275602478616e602f6e65602e6f6475602d616970226560236f6e666573796e67602163702478656
0236f6d60757475627027796c6c602162726964727162796c6970246563696465602778696368602f6e6560247f6022756164602f627024627f607e2a0a03786
f657c6460297f65702779637860247f60227566796567702071637470236f6d6d616e646370297f65702d61697020727563737022756475727e60277964786f6
57470247970796e6760247f60266c69607f266c6f60702265647775656e60276271607869636370216e6460247568747e2a0a096660297f657270236f6079702
3786f657c646025667562702661696c60247f602c6f616460282f6270276564702d657e6368656460226970216028657e676279702469637b602462796675692
02275646f677e6c6f61646029647026627f6d6a3a0020296473686e296f6f2368627963747f607865627462757d6a00202769647865726e236f6d6f236862796
3747f607865627462757d6a00202c6568716c6f66666c656e236f6d6f2262637f2f3479646133313734323a0a0c0260202020202020207275637370227564757
27e60247f60236f6e64796e65756ffa016470247865602374716274702f66602478656027616d656024786562756027796c6c60226560237566756e602f64786
5627020756f607c6560296e6024786560286f657375602779647860297f657e202478656962702e616d65637c202f636365707164796f6e637c20216e6460286
16962736f6c6f627021627560216370266f6c6c6f67737a3a0a047f6d690903716d69090903716c6c697a026c6f6e64690262757e65647475690275646865616
46a007c657d626562790d656368616e6963690375616d6374727563737a0a04627e20276275656e690a6f6569090902696c6c6a0262757e65647475690262757
e6564747569026c6f6e646a03757277656f6e6909076271667564696767656279026574736865627a0a04616963797a026c6f6e646a036f6f6b6e2a0a0c02602
020202020727563737022756475727e60247f60226567696e60207c61697a6f656f526f64697c2a6f656c2e696c6c21383c2079636f576271667564696767656
27c233c24323c7a6f656f546f64737c246f64737c2e696c6c21383c2370727f5a6f656f546f64737c21333c24353c7a6f656f58737c2877237c2e696c6c203c2
370727f5a6f656f58737c21333c24343c73786f66756c6c23786f66756c6c216023786f66756c6c21383c2370727f53786f66756c6c22353c24393c737b656c6
5647f6e6f5b65697c2b65697c2160237b656c65647f6e602b65697c22313c2370727f537b656c65647f6e6f5b65697c28353c24313c726279636b637c2262796
36b637c2160226279636b6c203c2370727f526279636b6c27383c21303c7a6567756c637c2a6567756c637c2a6567756c637c203c2370727f5a6567756c637c2
7383c21303c7471657e647f5e6f64756c2e6f64756c21602e6f64756c23323c2370727f5e6f64756c24353c24313c283c707963647572756c207963647572756
c2160207963647572756c23353c2370727f507963647572756c23323c253c726574747f6e6c226574747f6e6c2e696c6c203c2370727f526574747f6e6c25313
c21333c747f67756c6c247f67756c6c2160247f67756c6c23383c2370727f547f67756c6c26333c21323c74727160746f6f627f536c6f6375646c24727160746
f6f627c2e696c6c203c2370727f54727160746f6f627f536c6f6375646c2130303c22323c74727160746f6f627f5f60756e6c24727160746f6f627c2e696c6c2
03c2079636f54727160746f6f627f5f60756e6c2130303c22323c737c6564676568616d6d65627c237c6564676568616c2160237c6564676568616d6d65627c2
3393c2370727f537c6564676568616d6d65627c25313c26323c7472757e6b6f536c6f6375646c2472757e6b6c2e696c6c24303c2370727f5472757e6b6f536c6
f6375646c24373c22323c7472757e6b6f5f60756e6c2472757e6b6c2e696c6c203c2370727f5472757e6b6f5f60756e6c24373c22323c77657e6c27657e6c216
027657e6c203c2079636f57657e6c25323c23303c74616963797f546f64737c246f64737c2e696c6c24313c2370727f54616963797f546f64737c2130323c233
43c74616963797f58737c2877237c2e696c6c203c2370727f54616963797f58737c2130313c23343c726163756d656e647f5e6f64756c2e6f64756c21602e6f6
4756c24313c2370727f5e6f64756c24393c25313c293c77756c636f6d656c27756c636f6d656c2e696c6c223c2370727f57756c636f6d656f5d61647c25333c2
5383c727566627967656271647f627c22756662796765627c2e696c6c243c2079636f5662796467656f536c6f6375646c27383c293c7461676765627c2461676
765627c21602461676765627c22363c2370727f5461676765627c28353c24333c7c696e656c2c696e656c2e696c6c22363c2079636f5c616277656f526564627
f6f6d6f5461676765627f5c696e65637c23363c21373c7261636b697162746f56656e63656c26656e63656c2e696c6c21373c2079636f5261636b697162746f5
6656e63656f536c6f6375646c203c2033786c78618b697b63786ff378637179757180718b6ff975797b6ff08a6a876f9769c87eb87fff976679796573707ff0b
064a66db662b06ff7a667aa6ffbb66bb37ffda867b867bb6dab6da96ff2b862ba6fff757f73aff08391639d5a8fff73a163ad5a9ff1639163aff863a8639ff17
39173aff873a8749ffd73907090739ffc677c639ffc678d578ff667866e7ffc6e7d5e7fff6d787e78758074807c7ff47e74748ffb9277a277a77b977b927ff2a
272a77ff88f749f74958885888f7ffe8f7e858ff3a583a08ff0b580bf7abf7ab580b58ff5b485bf7ffeb47eba8f7a8fff7a878295c29ebb8ffc8b9f7b978f94c
f90cc9fffb29fbf9ffdb29dbf9ffc829c8f9fff829f8f9fff8b9dbb9ff4949e949e98949894949ff99499989ff2ab92a49aa49aab9ff4a895a89fffa59ab59ab
890b890b59ff5b595b89ff78f9787a4c7aff4cf94c8afff73a787affe9f9e98affe98a5aca7bca7baa3b7a3b6a1b3af93a2a5a2a8a7aaa7acaffdaf9da3aff7b
aa7aaaff2a5a2b5affccb8ec58bc580de7dce76d77cdd79dd7cd48ad48cdc8dcc8ff3dc83df98df98dc8ffc9088a088a58d958d918167a16069d069d7a167aff
16199d19ff191919e6dae6da19ff69176a176a8779877917ff69d7a9d7a90889086918690859f759e726168d168d7a267a2626ff1609da09ff8c198d19ff0909
09e60be68c278c59ea19eae6ff4b470c670cc74ba74b57fffb481c283c284c384c483c68fb48e5267d267d6ae56ae526fff56a27772c777d6aff96c896670776
07a7ff27672726ff196719560a560a67ff5976d976d9b659b65976fff86af83aaa3aaa6aff59e65907ff3c363c87ff5cc75c76ac17ac78ff8d476c586cc8ff6d
281d281d884d19ff7dd85dd85d290d190d69ff7d793dc9bcc9bc790d79ff1d78cc78ccc85cc85c29acc9ff6cd8bc69ffdc880d09ff2d385dc8d506cd06cd9ad5
9ad516ffe89ae86aca6aca9affd59a2757ff17061757ac57ffac06ac77bd7aff76d87647e676e6d7ff296729462a462a57ff59f659d6ff49e669e6ff6966f966
f9a669a66966ffdcd7dc663d373de8ffcdb7ec88ece8ff3df8dcf8dc591df97df9ff2de92da9ecf8ff8d493d989d98ff2da96da9ff8d0acdc9ffcd389d389db8
bd29ff8da98d39cd39d57ad5d5cdd5cd7ae57affd56a2727ff17d517272a27ff292729265a262b462b673a273a26ff6a566a86faa6fa766a56ffead6fad6fae6
ffe6a7e646761776d8ffe86ae83aca3aca7aff3b279c279cd5ff9c27cd6affcc97cc462df62db8ffcda7fc68fcd8ff3dd8ecd8ece8dce8dc392dc98dc9cd99ff
ece82d897d89ff2d892db9ff3dd83d789d78ff3d789d199d79ff9d09bd09ffcd189d189d88bd09d6a7f5386638d5f816f8d539d5b938b9a71908196738a738e6
a7ffa6b9a6e927e927b9ffc7c84868b76888f7f7f77877187788174817b8863907f80769670967a9e729e72a68d968ff99581a98c9986ad80ad8ba193a19ea59
58590909980949c8e8c8798829889958ff08797979ffd889d8b919b91989ff795979d9c9d9c959ff8a59ca79d979ff7b497bc9abc9ab49ff9cf6bb671c675bd7
dbd74b68cd68cd582db7adb7ec575d579cf6ff3c3a3c68ffec68ec2a4c2affd5d5cdd5cdaad5aad5f5ff2c49cb29fb19bb09ebf88bb81be83bf80b193b19fa49
1c49d60607967706ff7796a716d7a6ff8776c776ff081608a668a6ff98269876b8a6e8a6f876f826ff19a6492699b6ff29867986ffc9b6c926f9262a461a86e9
861a862aa60ab6c9b6ff5a265ab6cab6ff6b26fa26fa763b76fa76fab66bb6ff76c6c6c6ffa6c69637965766575637ff47d6f6d6f6675767fff6173717ff77d6
9767c737e76718e6ffa8e648e64867a867ff58378837ffd8e6d8671967ff99f659f64907492799379957796749672957ff4a876af6ba87ff5a579a57ffda87da
f62b072b270b472b87ffda370b37ffabf66bf66b77bb77ff6b37ab37ff76977628ff76d7d6d7ffd697d628ff17971728ff57975728c708c7d797a75797fff797
f728581858d70897ffc89788978828e828ff88e7c8e7ff192819a7593859a7ff5ab75a38ff8a388ab7da38dab7ff7ba7eba7ffbbb7bb38ff0cb70c38ff0cf74c
f7ff4ca74c38ff8cb78c38ff1d97ccb7dce71de70d28bc28bc18ff76787609ff76c8d6c8ffd678d609ff2778f6b8f6f8271957e857a83778ff877877e88709b7
09c7f8d778ff5878f788f7b838e83809f709f7f8ffd878787878f8c8f8ff78b8c8b8fff8f819f8ffe6798679862aff86c9c6c9ff0779071aff371a3789770a77
79ff9779d7a9d7e9971a9779ff48790879081a481aff18c938c9ff681a6889b899b8c998c9a81aff68c998c9ff4969f889e8b939e9091ad8f9ff59c9b9c9ffd9
79d91aff3a79e9c92a1aff9a695a695a0aaa0aff4ac99ac9ff0b69ca69ca0a1b0affdac90bc9ff4b1a4b69ab899ba95bc9ff0c69cb69cb0a1c0affcbb9fbb9ff
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000001111111111155555555115555555551151111111000000000
00000000000000000000000000000000000000000000000000000000000000000000000011111111115155551155555555555555555555555511110100000000
0000000000000000000000000000000000000000000111151555511111111111151151555555555555555555555555dd55d5dd5dddd55d555555511510000000
000000000000000000000000000000000001111555555555555555555555555555555555ddddd555dd5dd5dddddddddddddddddddddddddddd5d555511110000
000000000000000000001001001111155555555555555ddddddddddddd5dddddddddddddddddddddddddddddddddddddddddddd66dddddddd10100d555551000
000000000000001005555555555555555555ddddddddddddddddddddddddddddddddddddddddddddddd666ddd6d6dddddd66666666d66d6d10000055d5555100
00000000000011155555555ddddddd5dddddddd6dd6d6d6666666666666d66d666666666666d6dd6ddd66666666666d66d6666666666666600000001dd5d5515
0000000000555555ddddddddddddddddddddd6dd6666666666666666666666666666666666666666666666666666666666666666666666675000000d6dddd555
000000001155555dddddd6d6ddddd6666666666666666666666666666666666666666666666666666666666666666666666666666666666750000006666dddd0
000000115555ddddddd6666666666666666666666666666666666666666666666666666666666666666666666666d66666666666666677675000000666666650
00001555555dddddd6d666666666666666666666666666666666666666666666666666666666666666666666666616666666777777777777d000000676666d00
001155555ddddd6d6666666666666666666666666666666666666666666666666666666666666666666666666666166667776000000000000000000000000000
015555ddddddd6666666666666666666666666666666666666666666666666666666666666666666667666666676066667777500000000000000000000000000
15555ddddd6666666666666666666666666666666666666666666666666666767677767776666666766676677676077777777700000000000000000000000000
555dddd6666666666666666666666666666666666666666666677676677667777777767777777777777777777776167677777d00000000000000000000000000
55ddd66666666666666666666666666666666666666666666677777777777777777777777777777777777777776d015055055000000000000000000000000000
5ddd6666666666666666666666666666666666666666666667777777777777777777777777777777777777777710000000000000000000000000000000000000
dd6666666666666666666666666666666666666666666667677777777777777777777777777777777777777777d0000000000000000000000000000000000000
dd666666666666666666666666666666666666666666677777777777777777777777777777777777777777777600000000000000000000000000000000000000
d6666666666666666666666666666666666666666666767777777777777777777777777777777777777777776000000000000000000000000000000000000000
66666666666666666666666666666666666667677667777777777777777777777777777777777777777777770000000000000000000000000000000000000000
66666666666677766777776666766767667777777777777777777777777777777777777777777777777777710000000000000000000000000000000000000000
66666766677777777777777777776777777777777777777777777777777777777777777777777777777777600000000000000000000000000000000000000000
66666666777777777777777777777777777777777777777777777777777777777777777777777777777777775000000000000000000000000000000000000000
66666677777777777777777777777777777777777777777777777777777777777777777777777777777777777000000000000000000000000000000000000000
66777777777777777777777777777777777777777777777777777777777777777777777777777777777777777000000000000000000000000000000000000000
66777777777777777777777777777777777777777777777777777777777777777777777777777777777777777000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777777777777776777777777000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777777777777771056777777000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777777777777777000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777777777777777000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777777777777700000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777777777777000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777777777700000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777777777000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777777700000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777777000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777777700000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777776000000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777777777777770000000000000000000000000000000000000000000000000000000000000
777777777777777777777777777777777777777777777777777777777667777777777d0000000000000000000000000000000000000000000000000000000000
777777777777777777777777777777777777777777777777777777777d7777777777775000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777777777777767777777777777000000000000000000000000000000000000000000000000000000000
77777777777777777777777777777777777777777777777766777777667777777777777000000000000000000000000000000000000000000000000000000000
777777777777777777777777777777777777777777777776676d7776d66677777777777000000000000000000000000000000000000000000000000000000000
777777777777777777777777777777777767777776777776d7667666677677777777777000000000000000000000000000000000000000000000000000000000
7777777777777777777777777777777776dddd67756777676d6776776d6677766677777000000000000000000000000000000000000000000000000000000000
777777777777777777777777777777777776d55d6d5567d765676677776666667d555dd000000000000000000000000000000000000000000000000000000000
7777777777777777777777777777777777766665665dd7656d665dd6777776d77500000000000000000000000000000000000000000000000000000000000000
7777777777777777777777777777777777777676676757d5d55d665d566677567500000000000000000000000000000000000000000000000000000000000000
7777777777777777777777777776667666dd55d55d55555750677766567676575000000000000000008880000000000000000000000000000000000000000000
7777777777777777777777777777dd76666777776105d1575065675d557655d60000000000000000880808800000000000000000000000000000000000000000
77777777777777777777777777765775567776777501500d0d7d66d7d66157710000000000000008888088880000000000000000000000000000000000000000
777777777777777777777777776667d5777755651d56dd500d6157f65f7066500000000000000008888088888000000000000000000000000000000000000000
7777777777777777777777777d766566777d5665d7d5577601755f76577077100000000000000000000000000000000000000000000000000000000000000000
77777777777777777777777775777d76565d6716765d776550766567d76176650000000000000088888088888800000000000000000000000000000000000000
777777777777777777777777757775775d577707765dd6d5505d655776d0d5f750000061000000888880888e8800000000000000000000000000000000000000
777777777777777777777777757775d767d77617755d6655701655d7665066d66000177100000088888088888800000000000000000000000000000000000000
777777777777777777777777777776665717d76d6d65d56571076d67d7117776d005777100000088888088888800000000000000000000000000000000000000
77777777777777777777777777777776d7675f75d777657675057777771067777507777500000000000000000000000000000000000000000000000000000000
77777777777777777777777777777d5df776df6567777776660057777605d6677507777d00000088888088888800000000000000000000000000000000000000
77777777777777777777777677dd666666657651777dd76556d00d77d017df656006777d00000088888088808800000000000000000000000000000000000000
77777777777777777777777777d665776d666557676556dd7675007d06775f7d7506667d0000008e888088000800000000000000000000000000000000000000
7777777777777777777777776dd7f577665550d756dd6d6f66d70050577657777507dd7d00000088888080080000000000000000000000000000000000000000
7777777777777777777777776d777777776d7666d6d6d5777767500077767776dd076d7500000088888080888000000000000000000000000000000000000000
7777777777777777777777776d66777777516d767655d1677777d00d77777d01d106677d00000000000000000000000000000000000000000000000000000000
777777777777777777777776555556777515667d60677500000650077d7600677d066d7d00000088888088888800000000000000000000000000000000000000
777777777777777777777776667655675556d6757567d0015100000656700676760765760000008888808e888800000000000000000000000000000000000000
77777777777777777777777676556d5d56d75dd5756505777760000067d077767607767600000088888088888800000000000000000000000000000000000000
77777777777777777777776d655d7d555d561566757d667777700000770077767607777600000000000000000000000000000000000000000000000000000000
7777777777777777777777776d6665d7777750556565677767700005750076776707777600000000000000000000000000000000000000000000000000000000
777777777777777777777667d6665577765551500000577700100000000d77777707777600000000000000000000000000000000000000000000000000000000
7777777777777777777766566655566d5d6d7d66d6600d7760000000000777777707775000000000000000000000000000000000000000000000000000000000
77777777777777777777777d76576d6d67677d67d67d006775000000057777777706760000000000000000000000000000000000000000000000000000000000
7777777777777777777777716d67d575676766655776700175000000067777777706600000000000000000000000000000000000000000000000000000000000
7777777777777777777777705d7765756677667677567d0000000000077777777600000000000000000000000000000000000000000000000000000000000000
7777767777777777770776d005d7d5d5775676776d076f60000000000777777d0000000000000000000000000000000000000000000000000000000000000000
7777757777777077770771000006dd6d77566f771d66177700000000577777760000000000000000000000000000000000000000000000000000000000000000
777760677777d07777077d65d667756776776777677656775000000067777d000000000000000000000000000000000000000000000000000000000000000000
777610057777d07777077766d6677d777777f7777777d77750000000677d77000000000000000000000000000000000000000000000000000000000000000000
777100007777507777067766667777777777777777776777000000006775d0000000000000000000000000000000000000000000000000000000000000000000
777566d6777750777700576ddd777777777777777777777700000000575000000000000000000000000000000000000000000000000000000000000000000000
77766657777700777707065000577777777777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
7777d657777500777707700000067770777777777777777600000000000000000000000000000000000000000000000000000000000000000000000000000000
77775506771170777707700000007770777777777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000
7776000d7d07707777077700000d0060677770777777775000000000000000000000000000000000000000000000000000000000000000000000000000000000
777500006077707777077700000777001d6770777777600000000000000000000000000000000000000000000000000000000000000000000000000000000000
60000000017770777707770000077770000560777777001000000000000000000000000000000000000000000000000000000000000000000000000000000000
70d500000000007777077700000777707770006677dd000000000000000000000000000000000000000000000000000000000000000000000000000000000000
60d70000777770777700000000077770677770000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d0770000777770777707770000000770677770776000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
707700007777707777077700000777706777707d5000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70770000777770777707770000077770d77770d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70770000777770777707770000077770577760000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70770000777770777707770000077770565000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70770000777770777707770000077770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70770000777770777707770000077700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
70000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
629a6c9a6ca5ff63986b87748774966fa4ff74876c99ffca73dba4ffb57bb582bc99bf9cd39cd59affd598d5a3d3a3d3a0ffd49fbe9fbc9dba9db58ab482b581ffbf9fbfa3c1a3c19fffb486b48eb58effce60dc73ffdc60d064ffdc61d368ffdc61d76cffd260d666dc6cffb777b579b67cbf99c19ad29ad498c978c777b877
ff6d9d7393ff709c719bff6f957193ff759581957589ff7495778dff74957d92ff74957a8fff759077907a937a945f6a85698570ff5f74db68ff846989668e669067906eff876d876bff6573656aff6a6a6a74ff6f726f6aff74697471ff78717869ff7c697c71ff81718169ff9067da61ff9467946fff986e9867ff9d679d6e
__map__
c3a1c396c897c89ac59dc8a1ffc39cc69cffd096cc97cb9acf9bd09ecfa0cba0cb9fffd3a0d5a0ff615dd95dd9a762a7625e7162c862c8a571a57162ff856a8b6a8871ff906e966eff9c699b6c9b719f709f6f9e6e9a6fffa36caa6cffa46eaa6effaf6aaf71ff80798879ff84798481ff8a798a80ff897e8f7eff8f798f80ff
987992799281ff92809980ff937d977dff9b809b79a180a179ffaa79af79ffac79ac7fffa980af80ff879089888b90ff888d8b8dff8f908f88938d9688968fffa18fa187a688a98ba88ea58fa190ffac87b089b08caf8fac8fab8cab88ffb28fb287b88fb888ffbf87ba87ba8fbf8fffba8bbe8bffc285c28cffc18fc48fc291
c28e6f61c761c7a66fa66f61ff7b657e688165ff7e677e6cff8965896b856b846787658965ff8d658d6a906b9265ff9d649f6aa267a56aa863ffab64ab6affaf64af6ab46affb765b76abc6aff857685708976896fff916f8c6f8c769276ff8d739173ff93709576986fffa06e9b6e9b76a076ff9c729f72ffa276a26fa66fa8
70a872a372ffa672a875ff837a7e7a7e82ff7e7e827eff877a8781ff8981897a8e818e7aff917a957b977d978095819181917affa37aa381ffa679ad79ffaa79aa80ffb177b17effb280b081b083b282ff8188818fff83878a87ff8787878fff8d858d878c88ff94878f878e888e8b918b938c938e908f8c8f8c8eff9c8e9d86
a28eff9c8ba08bffa587a58eaa8effad87ad8db38dff879d87958a9a8d958d9cff9395939cff989c98959d9c9d94ffa793a293a29ca79cffa298a698ffab93ab99ffaa9bab9bab9caa9cffb092b099ffb09bb39bb29db09db09c6d60c960c9a76da76d60ff85698571ff89698f69ff8c698c71ff92669269ff986a936a956d97
7191719170ffa869a871ffab71ab69b071b069ff8a779277ff8f778f7fff9677967fff967b9a7bff9b779b7fffa777a077a07fa77fffa17ca67cff7b857b8f7f8d7e8b7c8bff7b867d867f887f8a7e8bff818f8485878fff828b868bff8e86898689888e8c8d8e8c8e898cff97869186918e968eff918a968aff9a8e9a869f8f
a386a38effac87a687a68fad8fffa68bab8bffaf8eaf86b38fb386ffb687be87ffba87ba8fffc385c38effc390c391c191c190c491c4abc0a1c08eca9fcaabffca9edb9effc18ed68ed686db90ffc990cc91cc94c995c794c791c990ffd290d590d593d394d192d191ffd597d797d79ad49ad399d497ffd098d09bcc9bcb99ce
97d098ff6e826e7274697483ff707b7079ff8e7e8e75ffa57086707f74ff8e70ff8b708b6eff9570966d936c926dff866ba06ba0638663866bff936b9363ff9d7ea478a471ffa478aa78ff9b6e9b6fff7e757e7e9c7e9c757f75ff8d70877396739a70ff9c75a470ff5dabdcabdc5e5d5e5daa787b785fff797a7d7affd68edb
9cffc65fc67cce8bd08dffcf89cf76c96ec982cf8dc67dc65edc5edcaa5daa5d5ec55eff75807569826982807680ff80748076ff785f7868ff746a6e726e82ff74815ea9ffa1638663866ba06ba064ff9264926bffcf8acf76c96ec982ffdc92d587d58ddb9bffdb9ec99ec9a9ffc4a9c1a2c18ed48effc28fc99effc891c792
c794cb95cc94cc92cb90c990ffd592d594d194d194d093d092d190d591ffcd98cf98d19acf9cce9ccc9bcd98ffd49bd79bd799d698d598d39affa57086708372ff83769d769d7e837eff8f7d8f77ff9e75a471a47a9e7effa57aaa7aff8d6f8d6eff9a6f9a6eff9470966f946d916d916eff897299729674867489725d655d80
6c806c655d65ff5d65615d725d70626c67ff725f727d707d7062ff727a6c80ff6c806c8269826980ff628062835d835d80ff6e6f6e726d73ff716d716f6d64725eff725d7264ff5e645e7f757f7577ff6e7e6e65ff7172716fff5d7f5d826282627fff6b7f6b826e826e7fff747774645f64ff75777977795d635d5e64655f65
6cff695f78675f6f5faaff78a262aaff786778a2b7a2b7677967ff9c679c967996ff9d96b5a1ff7ca37cab82ab82a3ffada3adabb3abb3a3ffa55fb667d570d5abb6a2ff5d5edc5edcab5dab5d5f5d60615d745d74736f755d755d61ff5d607060745dff70757060ff6063606b615d745d6f605d60615dff5d605d756675ff62
5f62715e75ff62716671ff6f60666966806f766f60ff745d74726f75ff6975696c5d5edc5edcab5dab5d5fff7562b462b4a673a673626b5eff645f649f72a6ffa064a07e747effb3877287ffa188a19f749fffa29fb3a5ffb5a7bdaaffd8aad86eb562ffab5eb261ffa17eb3865d67635d63675d725d67ff6062606bff5d6c63
625d615f5d64616469606d5d6a5d619f66a466a4739f739f65ff9f76a275a4799f7b9c7a9c779f76ff6e689e68ffa468cd68cda16fa16f68ff9d727d727d9ac09ac072a572ffc09acda1ff7d9971a0ff6f687d72ffcc69c073ffb362b462b565b066af63b261ff8e61916193648f658b638d61ff5d5edc5edca95da95d609b5e
8f6c966c8d7a957a898bbb8baf7ab67aaf6cb66ca95fff9dab9d8dffa7aba78dff5d5edc5edcab5dab5d5fffa25da25d725e72725ea7ffc55ec572d9a7ffc97cc964d47cd499ffce89ce70ffd07ed081ffcc78cc7cff678f67746d656d80ff7272c572ff72639163ff726c916cff73667566756cff75687868786cff915e9172
ffa85ea872ff8d63905fff8a638d60ff9161a861ff9861985effa161a15eff9166a866ff916aa86aff9872986ca16ca172ff916e986effa16ea86eff97699766ffa269a266ff9d659d61ffa863c563ffa86cc56cffbc6cbc6ab36ab36cffba6aba68af68af6ab36aff5f6d6c5eff7a948e91a89395987a95ff7b957b9c7d9c7d
95ff9898989f969f9699ffa893a89ca59ca595ffab90aa85ffab91b88eb881a985ffb780b07e9b7e92819084908c938ea690ff918d918f938f938effab91ab93ad93ad91ffb78eb791b491b48fffa690ab90ffa790a78e948c928dff93819488938cffaa7ea680a582a486ffa8869b86ffa786a68dff9d8c9e89a386ff5d5dd9
5dd9a75ea75e5dff616a60676162665f6a5fff66645f5eff6665665eff65665e63ff6367636466626962ff65665f68ff79687a687a6bff9a6e9a71ff9f6e9f71ff9b709f70ff9e7f9b809b8694895d60dc60dca95da95d60ff716071755da9ff668f66756d686d80ff71669266ff716e946eff7176c476ff94759460ff9463ab
63ff9468ab68ff946cac6cff9a759a6ea56ea575ff94729b72ff9d709d75ff9d73a373ffa370a375ffa672ab72ffab75ab60ff9a609a62ffa560a562ff9f639f67ff9a689a6bffa568a56bff71687468746eff75697a697a6fff7769776effac6fc46fffbf6ebf6db26db26effb76db76effbc6dbc6bb26bb26cffc568d068d0
7dc57dc569ffc773ca73ffc972c974ffd069da7ccf86cfa2d997ffd97dd99cdba8ffd07dd381ff8e659262ff8b658f62ff7a999b9bac988d947b977b9f7e9f7e99ff999b99a29ba29b9bffab97ab9fa99fa998ffb393bc91bc84af81a38194859289928f9592ae93ae96b296b293ffae93b193ffb393af88bb84ffb088ad8bad
93ffac90978e9592ff95859689968dff978c99899f889f84a281ffad81a985a889a18eff9f88ac8affbc91bc94ba94ba92ff9391939395939592ffab66cc66ffcc68cc5fffd391d393ffd492d2926261dc61dca662a66261ff629fdb9fff7d9f7d61ffc261c29fff7d96c296ff7d968791bc91c296ff8892888bbc8bbc90ff9b
619b7da97da977ffaa76ae76ae6fb26fffb38692869281b281ff898a9286ffbc8ab386ffb286b261ffae6fb273ffae76b279ffaa77b27cffa97db080ff92819b7dffb166a16e9d6f9d729f72a270b169ff8289967598749778947a828c818c818a82895e676d5eff5e6b765effdb66ce5effdc6ac65effdc77be7f9e6c827f5e
74ff5f798282ffdb76b25effd677ac5eff65768e5d6a78965dff9f6c9f5eff787b9f62ca7bffc67c9f667c7cffbe9adca6ff927fab7fab8c928c927fff5f9b7d907d925e9eff5ea68299827fffd1a2d18fda90daa5ffcb81ce81c19fbf9fcb82ffc8a3d581d681caa4c8a3ffcc84d384ffcc86d286ffca8ad18affc98cd08cff
c890ce90ffc792ce92ffc595cd95ffc597cc97ffc39acb9affc39cca9cff5d5ddc5ddca75ea75e5eff8299bd99bd80ff809974996b9cff779c6b9c6ba063a063a4ff63a06a9eff63a45fa4ff62a15fa3ff9174ab74ff9871a671ff9f6c9873ff9f6ca374ff9f6c9d74955f958a618aff708a70758575858aff7a757a8aff787d
7880ff7d7d7d7fff706d70648564856d706dff7b6d7b64ff5f5edc5edcaa60aa605f955f958a8f8aff618b648bff7089668d667a707787778f7a8f8d868b8677ff7078708b858bff8c808c84ff69816984ff706e70648664866e716eff7b6e7b64ff5f5edc5edcaa60aa605f967ddc88ff9671bd76bd83ffbd77c376c776ca78
ca85ffb675b682ffae81ae74ffa873a880ffa07ea072ff9a719a7effcb78dc7bffd079d085ffd786d77affc77fc77c967db181ff9671b475ff9a719a7dffa07ea072ffa87fa874ffae75ae80ffdb7cca79ca84db88ffd085d07affd77bd786ffbd83bd77bc76b576b279b284bd83ffb47eb47b5e5fda5fdaa75fa75f5fff735f
7375c675c65fff8975896696669675ff75707c7181708672ff9b71a56faf71b86fbf71c270ffc675d8a7ff7475659dffca74cd77ce81d689d68eff6a6f6e6f717271786e7d697e65796573696fff5f856485648b6a8b6a916f91ff5f976497649e6a9e6aa464a45fa1ff5fa762a3ff64855f8bff648b5f92ff698b6497ff6f92
6f996aa4ff699e6f91ffab79c479d19eb89eab79ffab7aab82af82ffbb9ebba5c0a5c09effd19ed1a4ffce9ecea5d2a5ff8a8b7d997a98809077957593848980897d8a7b8888858c868e8b8b9588958a8cff818b878eff8e919694ff938d8f95ff8e939890ff7a98799b7e9f7d99ff7795739870947594ff8b868a808d7d907c
947e968293868b86ff8e80917fff8f808e7eff91829482ff92819283ff8c828f84735f73768a76ff73775fa6ff707e70656976698effba63cd63cd7fb97fb963ffcd62ca5eca63ffbc60bd61ffc15fbf61c461c25fffc65fc661ff9b67b067b0699b699b67ff9376b476ff966a876a876e89718c718c76897788799479937791
759171966e976aff8b6a8b68ff926a9269ff896c946c906f8c6f896cff8e6a8e6dffd064d875d884d071d064ffd56ed57cffcd80d48bffdb9bc69bc598c898ffd486d88cd891d596d399cb99c796c592ffd68cd68dffd791d38ecd8dc78fc591c893cd94d791ffd38fd091c991cc8fd28effd99cdba5ff8d8c978a9f8d9c979a
969c8f95988f91968d8f8e8d8cff8d8c8b8c8b8f8e8eff94978c9f889c8e96869985959092ff85967f95829b8699ff889d859f8aa38a9fff9f8fa298a5989f8dff9c8aa18ca68ba985ffa787a3839e839c869c8affa184a186ff9f85a385ffa587a589ffa388a688ffa088a28affa47da87caa80b083af87a985a781a37fa47d
ffa383a781ff9c889a889a8affa18cab8faa92a6909f8dff9b859d849f81ffa78ba98aff9a9698989a999c97ff5e5ddc5ddca65fa65f5effb962b55eb576b87dffd98ddb8dd886d486d48e6160dc60dca6ffdca562a56260ff71616b726b85756e7560ff70797068ff77607774ca74ca60ff8b738b6395639574ff78757287ff
__sfx__
6affbf631b306146363ff5528d512ed770f646136363fb012990131951329512994127d7717256176663ff6126d612ed7721236216663fb32259322dd772b6262b2663fb03249032bd7735226356563fb5324953
ce77d5773f6563fb242392429d7709316093563fb742297429d7713706137463ff3521d3528d7735d103455735147391273d1270023702a10369103ff2239d2234d4230d722fd13329233893238d77073070e307
ba8db18d15b1000b100073707737077073fb640ca6408e0508e050ce250ce250fa050fa0517a5417a540fa340fa340ca640ce771b677226771aa4011a40196773ff4200e0301a620ba120be4200e7738e1000b20
68ff6b6f37e103ff720fa3311a721da321ca7210e7720e6028e7021a5117e4120e603fb010be310be6016a3016e700b61628566281172f176301762e5562b5562f5262f5262b5162f51631575311752f1062f116
6b6666662f5472954727517235471f547261073f356395563c5073c1173a56639d77205471d1571d16721167235473f7262813626d772a1362a1463f7362415624d7726136235162310626565295652d1752d126
76756082255261372613b3125931255263f3172fd342fd340f2170f2172fd7725526325763ff1525d342fd7713b3107f703f726166070f6471e54738d0438d041ed77013471bf223f7473857526e772090036517
c16dc07e3f77609256092560d6260d6261167511e772ad011fd313f3373d1073d54609e772dd002ad00249603f346056260567510e77239401f9403ff042ed723893400e042ed7701376366473ff042dd533cd77
755f75703ff3333d5335d1436d771e5651c7651cb321f9321f1751f5751c7751cb421f9421f5753f775371171fd77241071f575271663f766255062015628d772f516245753f7752750627136245362214620d77
90c290c207307077753f3373010628e773b1472c92211b223f6373c5373f75610656365072550700e77077071ab423fb543895423d742fd7408e770f3071435714f113ff6433d6437d771176711b003f7773d157
6effa160132471324710e77006673b66703f013ff6313e631be041be0413e773cd113cd5101e5101e113fb4213e631ae773de113ff2313e4316e6317e773de1138a413ff5313a2317e7730e2136a213ff021fd02
70c070ff182762a276212063ff512590226d1226d3225d1227922299322bd222ed771b6261e6361e6461d6461c2661f2761f6071e6171f227242272220723207232763f3062b5262a1462615624166201271e127
78bf62ff20175209421ab421a7753ff341ed3421d771f1751b3753f7071e10636d7721175255763f7061f54629d77205752c5163f3661e15624136281062cd77205362652627506271753fb04229542295438d73
7a8e7f7d01756017663fb54229253a92512a5418a5402a253ad770db400df603fb5439d643ed7714b111af323f7273050626e773f6373c5372c92211b220cf313fb5410e0439d77006673a66702b0102f113ad11
65a064a23f35710e0410e773cd113cd5101e5101a213ff0413e041be631be6313e7726e113ca513ff6313a3319e6313e0317e7732e113ce313f3560c25636107271073dd77206751727629276216753fb5125d71
6063646625d3225d771e6261e2461b2561b6663ff5127d7130d77242362364625656256663ff0220d022dd7724666232073fb023197132d61349123492232d0231116315752e1062b56527116291162757524575
9bb39bb3221361d1562616621166295562b507265762d16631116315461d107205072657628546295062956524575205161e5461d1751dd551dd5524675246751dd771fd413fd413f5063860638a411ab413ff55
6aff616924d1024d101b6751be7709627092561e2561e627096273fb212a92135d7703e4034e401d15620116261752b1752b1753f3661f5671f56723166231661fd77391753a5653b1753f72624526291262a565
62a562b2221263f71621175211752051620d77285262a126271263f3361f136215362255622d77271062a1063f72625536271562716624d773b1263b1362c1361f5651a7651af2220d22201753f3573593027971
ff9b659b26d632d9343c93409e4316a621ae311aa201164705257351061d9551d95525606256061dd773627536a7019b703fb201e9200e6160ee770c2750c67705e603fb411e94126d1226d121ed772423635a70
6bff9866209022090225d770d6260f6260f24612246122661726617676136173ff6033d1133d1130901309012dd602dd7713207172663ff012f9112cd7710266116463ff7028d602dd770f6260d6363fb311e931
987ea0ff162663f31621e1121e7718e0231e023ff3320e4520e7730e3119f313fb0314e4514e770aa21239213fb6017a6025e770be3121d313f3261822620e7727d3127d023f3071820721e773390233d313f377
ffae9bae01a0201e313ff6016a3125e7711a311ae223ff701be7021e770ea310fa3111a2110a110ba110aa210ca313fb0314a0311e5211e4213e4215e6215e7214e772ee2139e223ff5215e2325e772be212be02
6191619121e7739a4139e713fb6318a631fe7706b4106f713ff4418e441fe7714b4114f713fb3518a351f6651d9651d96524275242751dd773217532517087173ff441ed443596522e77345171f9223ff1032d10
87a48bac33d77246172464637646372173ff222e9332ed7727266292663ff3231d4231d7732266342663ff443cd351ce251fe131fa031da223e9323c9443cd772327723e002ee7132e0217f0217b713ff1205e12
629871ff22a7224e7716f0219f223ff1209e120fa220fe7734607326071d565265063f356241372ad7739166016073fb30339603610620d5520d55236752367521d77365063611707317077063fb603196022941
7a9bff7e296072964636646366073fb522dd232dd772b6562c6563fb132b9232bd772b6762c6763fb132fd132fd7737517209123f7761a6760b2770b2771a2071ae7731d5131d023f3271b2271fe772c90230902
79d180d61a27721e773ad713ed7107e510ae313f37714e100fe1015e773f92107e213fb2016a10186771ae7700a5100a023ff1017a301be7704a3108a513fb650ae2538d63389240de550de7701b0011b003fb25
949097900de773e2673ea2006b4118b411bf013ff240da3417e773ea303ce303be5000f503ff6419a541ae241ce1420e5420e641de741ca251da3520e5520e7713b4116f511bb613ff343295436d7715e2014a40
a49ca3a017e401ce1123a601da3024e4025e301de101ae1015e203fb5106a510ae7718e301da403ff2111e2112a4112a4110e7725e3027e4027e5025e5024a503ff6112e121ce3218e0211a5217a6214a120de77
7f947fff27a6127e413fb6215e0315e0317a6219a5217e7715e1012e100fa000f66711667116673ff01399013cd113dd213cd213991139d7713657136573fb313ad413ad513f94102e2103e7715a2015a203ff01
97ff748d1227712e003ff313cd313ed7716667186673ff6000a7003e771a6571d2673ff2101a413f1751dd551dd5526675266751ed771a35727256272661cf103f77516a6516e772ad212a9603f7460ca050ca05
a660a6603491003b1003b603f777036773b9333b93302e7706257066272c6272c2573ff5034d50319423194234d7724275242763ff702bd701ed772326610266102763fb32309322ed602ed60301061f9551f955
7888758820d773c1063cd1000f10003063f76729d7329d773d1073f2073f7673bd733bd7701f101ab323fb4403a443d96439905389153d91503e6406a5406e4403e773c92021d223f766156663e5472d54707e77
ac7cac7e2d9113f7170a2070a6660de77379202dd303f7270562707e7713246132361e2361e2463fb503a95034d6034d603ad7717257172471b2471b2573fb4202e3201e323e9623ed6201e6202e772827728267
ffd976c43ff4230d422d9622dd622ed6230d772a2662a6562c6562c2663fb13309132dd232d9332e93330d7733266336563565635266211061a3061ab3221932211063ff0120d012ad122ad1220d771125622932
d499ffcf08a2411e771974707b4007b013ff4501a3501a3506e0506e050ca540ca5411e1411e1417a6423e7719f4114f4114f610cf610cf1216f123fb5526e3523e4521e772325603b503fb440ee251ee770bb60
ff6d616d0ca5519e7712b401ab013fb3506a550ae7716f001af203fb2412e641e6651f9651f9652a6652a6651fd773b5753b1571e9423f33619236002472914700656006563ad772a10625526255373254632106
a35d5edc2dd773c557087571bf423f36726d5426d550ee7704626042573ff7027d703ad7719636192573ff2227d223cd7731636312573ff7327d733ad770a7360a3673fb05349050be7715f0015f413ff450be45
a47affb01e9652a6652a66520d772a57523136231473115632156325753f3661f16630d773b5753b1571ed423f3673b9443b9652be773c1360a3361cb013ff2027d203ad770f6360f2573ff4127d413ad7724636
ff725e72279033ad773e6363e2673fb54279543cd771072710f603fb3504a351be7726d4126d0037546375773f7073350709e772f9302d9303f3760527607e773317733567345671e5651b7651bf221ed221e565
c476c5733590235d773d1273d1160c2160c2273f7173657524e7707375077271ab223fb643296422d2532d2504a6432d7711357113663fb042c9322cd122d91235d02389123ad243a93439d243891238d7723237
8d8f8c9103376003663ff2435d2437d77236572367726677266573fb143b9143e9243e9243bd7705a1004e2007a3007a2005a103fb4003a0103e4105e110ae770ee7006a1106e7005e6006a5006e303fb300ae50
978ba18d09e0106e6003e770ce500fe403fb4008e5008e7709e3009e403ff5006a7006e770de200de303fb4001a403fd7705a00056773fb1003e0003e7702a3001e303fb700de700fa110fe110ca010be7710e50
a89cac981ea011da7016a7018a1122e1119a6117e113fb3113a1111a2117a3118a211ae011aa1118a7012a0110e7711e2112e213ff410de410ce771be2122a0125e0128e703fb0215a4218a221ae7116e7724a51
8ec587ce29e3126e413ff6118e121de711ee511ae7723e6125e7122a121fa1221a711e5651c7651cb321e9321e5653f3171e117395073ad77321470b2473fb523894438d7708765083471bf223ff740ae740ee24
8a71936807e770bb1003b1004b403fb1403a140ba240ee7716f020cf020cf4116f4116f023fb1512a5412a641be7709f1109f510cf023fb033790321d1421d1437d772b55728d1028d113f34604607046273b527
ffc868cc13e772c557345573f7070560713e7728d111f9221f5651b7651bf221fd221f5653f7171e51735944359441dd7721275216273fb523495221d4321d4334d77087463a2753fb4429d731dd770874604765
74766d881dd7708346103753fb44299251ed773f606053060b3060f3163fb443695524e7703a1203a223fb0022a0024e773a9123a9223f7372263724e7703e7103a2106a7006e413ff6402e6429d1536d1511e77
ff6c986c3fb101b2571b63721e1021a301aa3022a2022a201fe7727d4020d413f3061f2461f24624e7729d4031d403190230d022dd023f77620676182661f26624e772fd41329413f7462265621e772897130950
61b961b91b6561b2061dd551dd5525675256751ed77335653352719a3019207341753f3273616609e7726d7130d503f3661966616e7719637097371ab223ff6404e64289253792516e7721237212753fb5236952
6fa06da036d7708337083753fb44279731ed7708736043753fb44279151ed77087360d7653fb142195421d6422d7737d22379123f3572525722e7700e2200a123fb50339603396034d771e961279503195031961
ae79a8773f306202462024624e772b9712bd12299223f736222761820715e772f9412f9023fb101b2571b63721e1021e7702a1202a223ff1020e1014a300ea3023e1023e7706a6103a120b64615636286362e646
b6a0b0a0126370c6473fb602a9603ad771e2461e6373f3751361606276106462127519e771e177329702c9323f7170ee2009a0106a6205e4308e770fb7014f011bb313fb2316e530fe040fe0418e1317e773aa41
8dc78ac430a7137e613fb331de3317e773ca413be713fb7319a731fe773ba0200b0203f0201f123aa123ae023ff530fe630ae330ea3310a130ee230de5307e7701f7003f5005f0105f2108f1107f603ff240de34
7cc97fc707e773ae5039e5039a503fb4410a740aa6410a5412a4412e7704b1101f2101b3105b213ff540ae5409e7710f4012b403fb050ca150ce773fa203da3038a303ba103f2773ff1407a7302e733e9043d924
619d759d3fd7405a2407a5402e7703767003773f6773fb343ed4400e7701b1002b1002f1004f1004b203f7651d9551d95527275272751ed773fa3002b301e1061930619b3220932201063f7062a9522a95225e77
5d5edc5e35d223fb522a94521d77215062d1563f746211272ad7731116381463f74728d3128d602210722d7716606276463ff1221d0328d773b606043263fb4421d6423d77022260322605626032360123601226
7bff877d1cb521d9521d1063ff3032d7038d77132671ea103fb1204a4207e773a12708266152273f767325673ed7712666122773fb702f9702dd773d1571b2571b2773f3753dd553dd7700667006573fb203d920
9ad99aff076573ff503dd503bd770f6670f6573ff213ad213dd7718257186673ff620aa230ee7734e0101f2104b0138a603ff1311a330ba430aa430de2312e7703f0111f2110b5101b213fb451da551ea651ce55
6cffd19911f5119b123ff3523e5522e770cb5100b123ff6322e1423e771bb0226a0225e6120e511ee511da611aa5117a5113e4111a510fa610ba6108e710ce0207a2207a320ba4209e423fb602c9212c9012ad60
5d9b61a118f6119b5112b313fb303392033920309603096033d5033d770d62710627106373f7773857736930369303890038d770c24709247092371e1061a3061af321ed321e5063f31727e313497134d3426e77
a66aa771259222ad323f32620506235163f146072660d607136271865719e77385063551635576375473dd1001a4005e503ff50219202692030940399603dd703ed7713247106370d6170d256122361c62621626
86d286d526637222473ff3133931329312d9412b9712b9022e90231d7133d772c6062f2263365633617312472d66727a003ff631fd04249142bd14359043f95305e2308e030ae7713706167361575711f203fb05
a0d3a4cf09e2510a2516e741be541ce341ae2416e2412e340de5408e7406e7705f2101b413fe413ff451be3520e1524e74266562151624565205261d55621156275062a11624d7705f2101b413fe413ff451be35
__music__
0b 7f216d21
06 667f2665
0d 266d7f2b
0a 652b6e7f
05 306b3065
0b 7f356435
06 6c7f3a6a
0d 3a647f3f
0a 643f6b7f
05 446a4463
0b 7f4a624a
06 697f4f69
0d 4f627f53
0a 6153697f
05 57685761
05 7f750075
00 7a76767b
08 747e7400
06 78020175
07 017f2478
05 27712e6f
05 33733478
0d 24787f40
0b 02407747
0a 7747714e
0a 714e7755
0e 77550141
0f 017f4c08
0f 5008500c
0f 550c550f
0f 500f5017
0f 4b174b0f
0f 460f460c
0f 4b0c4b08
0b 7f1a7f22
0e 7f190911
0b 091a7f7f
0f 100b170c
0f 0d170516
0f 0f0b7f2a
0f 0032012b
0f 0c230c2a
0f 007f3703
0f 40043a0e
0f 320e3603
0f 7f2e1036
0f 112f1d26
0f 1d2d117f
0f 200d280f
0f 211a171a
07 200e7f5d
00 5d5f5d5f
08 5e616a04
06 697f0468
01 04716274
01 7f656b65
02 737f6a6a
04 6a737f6f
08 6a6f727f
00 74697471
01 7f786978
02 727f7c69
0c 7c717f01
0a 6a01717f