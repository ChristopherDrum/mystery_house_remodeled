pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
--mystery house 1.0
--by christopher drum
local cartdata_name = "drum_mysteryhouse_10"

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
local init_lengths = "569,2609,1177,421,52,61,147,144,158,219,624,208,344,219,222,233,65,64,81,31,52,76,20,14,111,50,414,384,149,262,57,74,67,68,302,426,227,291,286,101,41,113,247,260,38,20,57,88,39,284,125,19,398,98,185,119,110,125,310,128,191,189,262,86,252,197,16"
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

function wait_for_key(key,x,y)
	while (stat(30) == false) do
		ticks += 1
		if (x and y) then
			if (ticks % (curs_blink*2) == 0) curs_display = not curs_display
			local curs_color = (curs_display == true) and 7 or 0
			print(curs, x, y, curs_color)
		end
		yield()
	end
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
	wait_for_key(nil, 117, 121)
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
		wait_for_key('\r', #lines[#lines]*4+1, ((#lines-1)*6+1))
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
	init_from_data()
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

--swap when you have parallel object key values, like filled/empty pitcher
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
96e6760297f657e2a00727563737022756475727e60247f60236f6e64796e65756ffa097f657020727f6762756373702478627f6577686024786560286f65737
56022697020727f667964696e676024777f60277f627460236f6d6d616e6460277869636860257375716c6c6970236f6e6471696e6021602675627260216e646
02478656e6021602e6f657e60226574702162756e672470216c6771697370296e6024786164702f627465627e202568716d607c6563702162756027277164756
2702f6e6720216e6460272f60756e60246f6f62772e202966602160237564702f6660277f62746370246f65637e64702375656d60247f60226560277f627b696
e676024727970246966666562756e64702475627d696e6f6c6f67697a0a096660297f657023786f657c646026696e6460216023747169627361637560297f657
02d616970247279702725707023747169627377202f627027276f60237471696273772e20237f6d65602f666024786560216364796f6e6370297f657023616e6
024716b6560216275602765647c2024627f607c20276f6c202c6f6f6b6c20227561646c20236c696d626c202d6f66756c202869647c202b696c6c602564736e2
a0a00727563737022756475727e60247f60236f6e64796e65756ffa0a0a097f65702d616970276f60296e6024786560246962756364796f6e63702e6f6274786
c20237f6574786c20256163747c20277563747c20257070216e6460246f677e6e2024797075602e6f627478602f62702e60247f60276f602e6f6274786e20247
865602f6478656270246962756364796f6e602d616970216c637f6022656021626262756679616475646021637027756c6c6e202778656e60297f65727027716
970296370226c6f636b656460216e6460297f657023616e67247025737560246962756364796f6e6370247f602d6f667560297f65702d6169702861667560247
f60227566656270247f602478656021636475716c602f626a65636470296e60297f6572702771697e20296e60247865637560236163756370297f6570236f657
c6460247970756027276f60246f6f62772c2027276f60286f6c65672c2027276f602761647567202564736e2a0a00727563737022756475727e60247f60236f6
e64796e65756ff96e6027656e6562716c6024786560247f60702f66602478656023736275656e60296e602e6f6274786e2024786560226f64747f6d602963702
37f6574786c20247865602c6566647023796465602963702775637470216e6460247865602279676864702379646560296370256163747e20226563616573756
02f666024786560246966666963657c6479702f666024627167796e6760246f6f627771697370247f6024786560237f657478602f627024786560226f64747f6
d602f66602478656023736275656e6c20247865627560216275602f6e65602f627024777f60227f6f6d637027786562756024786560246f6f627771697370246
f602e6f64702d6164736860257070247f60247865602e6f627d616c60246962756364796f6e637e2a0a096660297f657027716e64702160236c6f637562702c6
f6f6b60216470237f6d656478696e6760237169702c6f6f6b60282f626a656364792e20247f6022756475727e60247f60247865602d61696e602679656770237
169702c6f6f6b60227f6f6d6e2a0a03716675602761667560216e6460227563747f62756027616d65602d616970216c637f60226560257375646e2a0a0072756
3737022756475727e60247f60236f6e64796e65756ff1602e6f6475602f666023616574796f6e6a302361627279796e67602d6f6275602478616e602f6e65602
e6f6475602d616970226560236f6e666573796e676021637024786560236f6d60757475627027796c6c602162726964727162796c69702465636964656027786
96368602f6e6560247f6022756164602f627024627f607e2a0a03786f657c6460297f65702779637860247f60227566796567702071637470236f6d6d616e646
370297f65702d61697020727563737022756475727e60277964786f657470247970796e6760247f60266c69607f266c6f60702265647775656e6027627160786
9636370216e6460247568747e2a0a096660297f657270236f60797023786f657c646025667562702661696c60247f602c6f616460282f6270276564702d657e6
368656460226970216028657e676279702469637b60246279667569202275646f677e6c6f61646029647026627f6d6a3a0020296473686e296f6f23686279637
47f607865627462757d6a00202769647865726e236f6d6f2368627963747f607865627462757d6a00202c6568716c6f66666c656e236f6d6f2262637f2f34796
46133313734323a0a00727563737022756475727e60247f60236f6e64796e65756ffa016470247865602374716274702f66602478656027616d6560247865627
56027796c6c60226560237566756e602f647865627020756f607c6560296e6024786560286f657375602779647860297f657e202478656962702e616d65637c2
02f636365707164796f6e637c20216e646028616962736f6c6f627021627560216370266f6c6c6f67737a3a0a047f6d690903716d69090903716c6c697a026c6
f6e64690262757e6564747569027564686561646a007c657d626562790d656368616e6963690375616d6374727563737a0a04627e20276275656e690a6f65690
90902696c6c6a0262757e65647475690262757e6564747569026c6f6e646a03757277656f6e6909076271667564696767656279026574736865627a0a0461696
3797a026c6f6e646a036f6f6b6e2a0a00727563737022756475727e60247f60226567696e60207c616973716d6f546561646c23716d6c2e696c6c21373c23707
27f53716d6f546561646c26333c24333c7a6f656f526f64697c2a6f656c2e696c6c21383c2079636f57627166756469676765627c233c24323c7a6f656f546f6
4737c246f64737c2e696c6c21383c2370727f5a6f656f546f64737c21333c24353c7a6f656f58737c2877237c2e696c6c203c2370727f5a6f656f58737c21333
c24343c73786f66756c6c23786f66756c6c216023786f66756c6c21383c2370727f53786f66756c6c22353c24393c737b656c65647f6e6f5b65697c2b65697c2
160237b656c65647f6e602b65697c22313c2370727f537b656c65647f6e6f5b65697c28353c24313c726279636b637c226279636b637c2160226279636b6c203
c2370727f526279636b6c27383c21303c7a6567756c637c2a6567756c637c2a6567756c637c203c2370727f5a6567756c637c27383c21303c7471657e647f5e6
f64756c2e6f64756c21602e6f64756c23323c2370727f5e6f64756c24353c24313c283c707963647572756c207963647572756c2160207963647572756c23353
c2370727f507963647572756c23323c253c726574747f6e6c226574747f6e6c2e696c6c203c2370727f526574747f6e6c25313c21333c747f67756c6c247f677
56c6c2160247f67756c6c23383c2370727f547f67756c6c26333c21323c74727160746f6f627f536c6f6375646c24727160746f6f627c2e696c6c203c2370727
f54727160746f6f627f536c6f6375646c2130303c22323c74727160746f6f627f5f60756e6c24727160746f6f627c2e696c6c203c2079636f54727160746f6f6
27f5f60756e6c2130303c22323c737c6564676568616d6d65627c237c6564676568616c2160237c6564676568616d6d65627c23393c2370727f537c656467656
8616d6d65627c25313c26323c7472757e6b6f536c6f6375646c2472757e6b6c2e696c6c24303c2370727f5472757e6b6f536c6f6375646c24373c22323c74727
57e6b6f5f60756e6c2472757e6b6c2e696c6c203c2370727f5472757e6b6f5f60756e6c24373c22323c77657e6c27657e6c216027657e6c203c2079636f57657
e6c25323c23303c74616963797f546f64737c246f64737c2e696c6c24313c2370727f54616963797f546f64737c2130323c23343c74616963797f58737c28772
37c2e696c6c203c2370727f54616963797f58737c2130313c23343c726163756d656e647f5e6f64756c2e6f64756c21602e6f64756c24313c2370727f5e6f647
56c24393c25313c293c77756c636f6d656c27756c636f6d656c2e696c6c223c2370727f57756c636f6d656f5d61647c25333c25383c727566627967656271647
f627c22756662796765627c2e696c6c243c2079636f5662796467656f536c6f6375646c27383c293c7461676765627c2461676765627c21602461676765627c2
2363c2370727f5461676765627c28353c24333c7c696e656c2c696e656c2e696c6c22363c2079636f5c616277656f526564627f6f6d6f5461676765627f5c696
e65637c23363c21373c7261636b697162746f56656e63656c26656e63656c2e696c6c21373c2079636f5261636b697162746f56656e63656f536c6f6375646c2
03c2033786c78618b697b63786ff378637179757180718b6ff975797b6ff08a6a876f9769c87eb87fff976679796573707ff0b064a66db662b06ff7a667aa6ff
bb66bb37ffda867b867bb6dab6da96ff2b862ba6fff757f73aff08391639d5a8fff73a163ad5a9ff1639163aff863a8639ff1739173aff873a8749ffd7390709
0739ffc677c639ffc678d578ff667866e7ffc6e7d5e7fff6d787e78758074807c7ff47e74748ffb9277a277a77b977b927ff2a272a77ff88f749f74958885888
f7ffe8f7e858ff3a583a08ff0b580bf7abf7ab580b58ff5b485bf7ffeb47eba8f7a8fff7a878295c29ebb8ffc8b9f7b978f94cf90cc9fffb29fbf9ffdb29dbf9
ffc829c8f9fff829f8f9fff8b9dbb9ff4949e949e98949894949ff99499989ff2ab92a49aa49aab9ff4a895a89fffa59ab59ab890b890b59ff5b595b89ff78f9
787a4c7aff4cf94c8afff73a787affe9f9e98affe98a5aca7bca7baa3b7a3b6a1b3af93a2a5a2a8a7aaa7acaffdaf9da3aff7baa7aaaff2a5a2b5affccb8ec58
bc580de7dce76d77cdd79dd7cd48ad48cdc8dcc8ff3dc83df98df98dc8ffc9088a088a58d958d918167a16069d069d7a167aff16199d19ff191919e6dae6da19
ff69176a176a8779877917ff69d7a9d7a90889086918690859f759e726168d168d7a267a2626ff1609da09ff8c198d19ff090909e60be68c278c59ea19eae6ff
4b470c670cc74ba74b57fffb481c283c284c384c483c68fb48e5267d267d6ae56ae526fff56a27772c777d6aff96c89667077607a7ff27672726ff196719560a
560a67ff5976d976d9b659b65976fff86af83aaa3aaa6aff59e65907ff3c363c87ff5cc75c76ac17ac78ff8d476c586cc8ff6d281d281d884d19ff7dd85dd85d
290d190d69ff7d793dc9bcc9bc790d79ff1d78cc78ccc85cc85c29acc9ff6cd8bc69ffdc880d09ff2d385dc8d506cd06cd9ad59ad516ffe89ae86aca6aca9aff
d59a2757ff17061757ac57ffac06ac77bd7aff76d87647e676e6d7ff296729462a462a57ff59f659d6ff49e669e6ff6966f966f9a669a66966ffdcd7dc663d37
3de8ffcdb7ec88ece8ff3df8dcf8dc591df97df9ff2de92da9ecf8ff8d493d989d98ff2da96da9ff8d0acdc9ffcd389d389db8bd29ff8da98d39cd39d57ad5d5
cdd5cd7ae57affd56a2727ff17d517272a27ff292729265a262b462b673a273a26ff6a566a86faa6fa766a56ffead6fad6fae6ffe6a7e646761776d8ffe86ae8
3aca3aca7aff3b279c279cd5ff9c27cd6affcc97cc462df62db8ffcda7fc68fcd8ff3dd8ecd8ece8dce8dc392dc98dc9cd99ffece82d897d89ff2d892db9ff3d
d83d789d78ff3d789d199d79ff9d09bd09ffcd189d189d88bd09d6a7f5386638d5f816f8d539d5b938b9a71908196738a738e6a7ffa6b9a6e927e927b9ffc7c8
4868b76888f7f7f77877187788174817b8863907f80769670967a9e729e72a68d968ff99581a98c9986ad80ad8ba193a19ea5958590909980949c8e8c8798829
889958ff08797979ffd889d8b919b91989ff795979d9c9d9c959ff8a59ca79d979ff7b497bc9abc9ab49ff9cf6bb671c675bd7dbd74b68cd68cd582db7adb7ec
575d579cf6ff3c3a3c68ffec68ec2a4c2affd5d5cdd5cdaad5aad5f5ff2c49cb29fb19bb09ebf88bb81be83bf80b193b19fa491c49d60607967706ff7796a716
d7a6ff8776c776ff081608a668a6ff98269876b8a6e8a6f876f826ff19a6492699b6ff29867986ffc9b6c926f9262a461a86e9861a862aa60ab6c9b6ff5a265a
b6cab6ff6b26fa26fa763b76fa76fab66bb6ff76c6c6c6ffa6c69637965766575637ff47d6f6d6f6675767fff6173717ff77d69767c737e76718e6ffa8e648e6
4867a867ff58378837ffd8e6d8671967ff99f659f64907492799379957796749672957ff4a876af6ba87ff5a579a57ffda87daf62b072b270b472b87ffda370b
37ffabf66bf66b77bb77ff6b37ab37ff76977628ff76d7d6d7ffd697d628ff17971728ff57975728c708c7d797a75797fff797f728581858d70897ffc8978897
8828e828ff88e7c8e7ff192819a7593859a7ff5ab75a38ff8a388ab7da38dab7ff7ba7eba7ffbbb7bb38ff0cb70c38ff0cf74cf7ff4ca74c38ff8cb78c38ff1d
97ccb7dce71de70d28bc28bc18ff76787609ff76c8d6c8ffd678d609ff2778f6b8f6f8271957e857a83778ff877877e88709b709c7f8d778ff5878f788f7b838
e83809f709f7f8ffd878787878f8c8f8ff78b8c8b8fff8f819f8ffe6798679862aff86c9c6c9ff0779071aff371a3789770a7779ff9779d7a9d7e9971a9779ff
48790879081a481aff18c938c9ff681a6889b899b8c998c9a81aff68c998c9ff4969f889e8b939e9091ad8f9ff59c9b9c9ffd979d91aff3a79e9c92a1aff9a69
5a695a0aaa0aff4ac99ac9ff0b69ca69ca0a1b0affdac90bc9ff4b1a4b69ab899ba95bc9ff0c69cb69cb0a1c0affcbb9fbb9ff3c1a3c698c798ca95cd98c1aff
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
74966fa4ff74876c99ffca73dba4ffb57bb582bc99bf9cd39cd59affd598d5a3d3a3d3a0ffd49fbe9fbc9dba9db58ab482b581ffbf9fbfa3c1a3c19fffb486b48eb58effce60dc73ffdc60d064ffdc61d368ffdc61d76cffd260d666dc6cffb777b579b67cbf99c19ad29ad498c978c777b877ff6d9d7393ff709c719bff6f95
7193ff759581957589ff7495778dff74957d92ff74957a8fff759077907a937a945f6a85698570ff5f74db68ff846989668e669067906eff876d876bff6573656aff6a6a6a74ff6f726f6aff74697471ff78717869ff7c697c71ff81718169ff9067da61ff9467946fff986e9867ff9d679d6effa16da166ffa665a66dffab65
__map__
c39cc69cffd096cc97cb9acf9bd09ecfa0cba0cb9fffd3a0d5a0ff615dd95dd9a762a7625e7162c862c8a571a57162ff856a8b6a8871ff906e966eff9c699b6c9b719f709f6f9e6e9a6fffa36caa6cffa46eaa6effaf6aaf71ff80798879ff84798481ff8a798a80ff897e8f7eff8f798f80ff987992799281ff92809980ff93
7d977dff9b809b79a180a179ffaa79af79ffac79ac7fffa980af80ff879089888b90ff888d8b8dff8f908f88938d9688968fffa18fa187a688a98ba88ea58fa190ffac87b089b08caf8fac8fab8cab88ffb28fb287b88fb888ffbf87ba87ba8fbf8fffba8bbe8bffc285c28cffc18fc48fc291c28e6f61c761c7a66fa66f61ff
7b657e688165ff7e677e6cff8965896b856b846787658965ff8d658d6a906b9265ff9d649f6aa267a56aa863ffab64ab6affaf64af6ab46affb765b76abc6aff857685708976896fff916f8c6f8c769276ff8d739173ff93709576986fffa06e9b6e9b76a076ff9c729f72ffa276a26fa66fa870a872a372ffa672a875ff837a
7e7a7e82ff7e7e827eff877a8781ff8981897a8e818e7aff917a957b977d978095819181917affa37aa381ffa679ad79ffaa79aa80ffb177b17effb280b081b083b282ff8188818fff83878a87ff8787878fff8d858d878c88ff94878f878e888e8b918b938c938e908f8c8f8c8eff9c8e9d86a28eff9c8ba08bffa587a58eaa
8effad87ad8db38dff879d87958a9a8d958d9cff9395939cff989c98959d9c9d94ffa793a293a29ca79cffa298a698ffab93ab99ffaa9bab9bab9caa9cffb092b099ffb09bb39bb29db09db09c6d60c960c9a76da76d60ff85698571ff89698f69ff8c698c71ff92669269ff986a936a956d977191719170ffa869a871ffab71
ab69b071b069ff8a779277ff8f778f7fff9677967fff967b9a7bff9b779b7fffa777a077a07fa77fffa17ca67cff7b857b8f7f8d7e8b7c8bff7b867d867f887f8a7e8bff818f8485878fff828b868bff8e86898689888e8c8d8e8c8e898cff97869186918e968eff918a968aff9a8e9a869f8fa386a38effac87a687a68fad8f
ffa68bab8bffaf8eaf86b38fb386ffb687be87ffba87ba8fffc385c38effc390c391c191c190c491c4abc0a1c08eca9fcaabffca9edb9effc18ed68ed686db90ffc990cc91cc94c995c794c791c990ffd290d590d593d394d192d191ffd597d797d79ad49ad399d497ffd098d09bcc9bcb99ce97d098ff6e826e7274697483ff
707b7079ff8e7e8e75ffa57086707f74ff8e70ff8b708b6eff9570966d936c926dff866ba06ba0638663866bff936b9363ff9d7ea478a471ffa478aa78ff9b6e9b6fff7e757e7e9c7e9c757f75ff8d70877396739a70ff9c75a470ff5dabdcabdc5e5d5e5daa787b785fff797a7d7affd68edb9cffc65fc67cce8bd08dffcf89
cf76c96ec982cf8dc67dc65edc5edcaa5daa5d5ec55eff75807569826982807680ff80748076ff785f7868ff746a6e726e82ff74815ea9ffa1638663866ba06ba064ff9264926bffcf8acf76c96ec982ffdc92d587d58ddb9bffdb9ec99ec9a9ffc4a9c1a2c18ed48effc28fc99effc891c792c794cb95cc94cc92cb90c990ff
d592d594d194d194d093d092d190d591ffcd98cf98d19acf9cce9ccc9bcd98ffd49bd79bd799d698d598d39affa57086708372ff83769d769d7e837eff8f7d8f77ff9e75a471a47a9e7effa57aaa7aff8d6f8d6eff9a6f9a6eff9470966f946d916d916eff897299729674867489725d655d806c806c655d65ff5d65615d725d
70626c67ff725f727d707d7062ff727a6c80ff6c806c8269826980ff628062835d835d80ff6e6f6e726d73ff716d716f6d64725eff725d7264ff5e645e7f757f7577ff6e7e6e65ff7172716fff5d7f5d826282627fff6b7f6b826e826e7fff747774645f64ff75777977795d635d5e64655f656cff695f78675f6f5faaff78a2
62aaff786778a2b7a2b7677967ff9c679c967996ff9d96b5a1ff7ca37cab82ab82a3ffada3adabb3abb3a3ffa55fb667d570d5abb6a2ff5d5edc5edcab5dab5d5f5d60615d745d74736f755d755d61ff5d607060745dff70757060ff6063606b615d745d6f605d60615dff5d605d756675ff625f62715e75ff62716671ff6f60
666966806f766f60ff745d74726f75ff6975696c5d5edc5edcab5dab5d5fff7562b462b4a673a673626b5eff645f649f72a6ffa064a07e747effb3877287ffa188a19f749fffa29fb3a5ffb5a7bdaaffd8aad86eb562ffab5eb261ffa17eb3865d67635d63675d725d67ff6062606bff5d6c63625d615f5d64616469606d5d6a
5d619f66a466a4739f739f65ff9f76a275a4799f7b9c7a9c779f76ff6e689e68ffa468cd68cda16fa16f68ff9d727d727d9ac09ac072a572ffc09acda1ff7d9971a0ff6f687d72ffcc69c073ffb362b462b565b066af63b261ff8e61916193648f658b638d61ff5d5edc5edca95da95d609b5e8f6c966c8d7a957a898bbb8baf
7ab67aaf6cb66ca95fff9dab9d8dffa7aba78dff5d5edc5edcab5dab5d5fffa25da25d725e72725ea7ffc55ec572d9a7ffc97cc964d47cd499ffce89ce70ffd07ed081ffcc78cc7cff678f67746d656d80ff7272c572ff72639163ff726c916cff73667566756cff75687868786cff915e9172ffa85ea872ff8d63905fff8a63
8d60ff9161a861ff9861985effa161a15eff9166a866ff916aa86aff9872986ca16ca172ff916e986effa16ea86eff97699766ffa269a266ff9d659d61ffa863c563ffa86cc56cffbc6cbc6ab36ab36cffba6aba68af68af6ab36aff5f6d6c5eff7a948e91a89395987a95ff7b957b9c7d9c7d95ff9898989f969f9699ffa893
a89ca59ca595ffab90aa85ffab91b88eb881a985ffb780b07e9b7e92819084908c938ea690ff918d918f938f938effab91ab93ad93ad91ffb78eb791b491b48fffa690ab90ffa790a78e948c928dff93819488938cffaa7ea680a582a486ffa8869b86ffa786a68dff9d8c9e89a386ff5d5dd95dd9a75ea75e5dff616a606761
62665f6a5fff66645f5eff6665665eff65665e63ff6367636466626962ff65665f68ff79687a687a6bff9a6e9a71ff9f6e9f71ff9b709f70ff9e7f9b809b8694895d60dc60dca95da95d60ff716071755da9ff668f66756d686d80ff71669266ff716e946eff7176c476ff94759460ff9463ab63ff9468ab68ff946cac6cff9a
759a6ea56ea575ff94729b72ff9d709d75ff9d73a373ffa370a375ffa672ab72ffab75ab60ff9a609a62ffa560a562ff9f639f67ff9a689a6bffa568a56bff71687468746eff75697a697a6fff7769776effac6fc46fffbf6ebf6db26db26effb76db76effbc6dbc6bb26bb26cffc568d068d07dc57dc569ffc773ca73ffc972
c974ffd069da7ccf86cfa2d997ffd97dd99cdba8ffd07dd381ff8e659262ff8b658f62ff7a999b9bac988d947b977b9f7e9f7e99ff999b99a29ba29b9bffab97ab9fa99fa998ffb393bc91bc84af81a38194859289928f9592ae93ae96b296b293ffae93b193ffb393af88bb84ffb088ad8bad93ffac90978e9592ff95859689
968dff978c99899f889f84a281ffad81a985a889a18eff9f88ac8affbc91bc94ba94ba92ff9391939395939592ffab66cc66ffcc68cc5fffd391d393ffd492d2926261dc61dca662a66261ff629fdb9fff7d9f7d61ffc261c29fff7d96c296ff7d968791bc91c296ff8892888bbc8bbc90ff9b619b7da97da977ffaa76ae76ae
6fb26fffb38692869281b281ff898a9286ffbc8ab386ffb286b261ffae6fb273ffae76b279ffaa77b27cffa97db080ff92819b7dffb166a16e9d6f9d729f72a270b169ff8289967598749778947a828c818c818a82895e676d5eff5e6b765effdb66ce5effdc6ac65effdc77be7f9e6c827f5e74ff5f798282ffdb76b25effd6
77ac5eff65768e5d6a78965dff9f6c9f5eff787b9f62ca7bffc67c9f667c7cffbe9adca6ff927fab7fab8c928c927fff5f9b7d907d925e9eff5ea68299827fffd1a2d18fda90daa5ffcb81ce81c19fbf9fcb82ffc8a3d581d681caa4c8a3ffcc84d384ffcc86d286ffca8ad18affc98cd08cffc890ce90ffc792ce92ffc595cd
95ffc597cc97ffc39acb9affc39cca9cff5d5ddc5ddca75ea75e5eff8299bd99bd80ff809974996b9cff779c6b9c6ba063a063a4ff63a06a9eff63a45fa4ff62a15fa3ff9174ab74ff9871a671ff9f6c9873ff9f6ca374ff9f6c9d74955f958a618aff708a70758575858aff7a757a8aff787d7880ff7d7d7d7fff706d706485
64856d706dff7b6d7b64ff5f5edc5edcaa60aa605f955f958a8f8aff618b648bff7089668d667a707787778f7a8f8d868b8677ff7078708b858bff8c808c84ff69816984ff706e70648664866e716eff7b6e7b64ff5f5edc5edcaa60aa605f967ddc88ff9671bd76bd83ffbd77c376c776ca78ca85ffb675b682ffae81ae74ff
a873a880ffa07ea072ff9a719a7effcb78dc7bffd079d085ffd786d77affc77fc77c967db181ff9671b475ff9a719a7dffa07ea072ffa87fa874ffae75ae80ffdb7cca79ca84db88ffd085d07affd77bd786ffbd83bd77bc76b576b279b284bd83ffb47eb47b5e5fda5fdaa75fa75f5fff735f7375c675c65fff897589669666
9675ff75707c7181708672ff9b71a56faf71b86fbf71c270ffc675d8a7ff7475659dffca74cd77ce81d689d68eff6a6f6e6f717271786e7d697e65796573696fff5f856485648b6a8b6a916f91ff5f976497649e6a9e6aa464a45fa1ff5fa762a3ff64855f8bff648b5f92ff698b6497ff6f926f996aa4ff699e6f91ffab79c4
79d19eb89eab79ffab7aab82af82ffbb9ebba5c0a5c09effd19ed1a4ffce9ecea5d2a5ff8a8b7d997a98809077957593848980897d8a7b8888858c868e8b8b9588958a8cff818b878eff8e919694ff938d8f95ff8e939890ff7a98799b7e9f7d99ff7795739870947594ff8b868a808d7d907c947e968293868b86ff8e80917f
ff8f808e7eff91829482ff92819283ff8c828f84735f73768a76ff73775fa6ff707e70656976698effba63cd63cd7fb97fb963ffcd62ca5eca63ffbc60bd61ffc15fbf61c461c25fffc65fc661ff9b67b067b0699b699b67ff9376b476ff966a876a876e89718c718c76897788799479937791759171966e976aff8b6a8b68ff
926a9269ff896c946c906f8c6f896cff8e6a8e6dffd064d875d884d071d064ffd56ed57cffcd80d48bffdb9bc69bc598c898ffd486d88cd891d596d399cb99c796c592ffd68cd68dffd791d38ecd8dc78fc591c893cd94d791ffd38fd091c991cc8fd28effd99cdba5ff8d8c978a9f8d9c979a969c8f95988f91968d8f8e8d8c
ff8d8c8b8c8b8f8e8eff94978c9f889c8e96869985959092ff85967f95829b8699ff889d859f8aa38a9fff9f8fa298a5989f8dff9c8aa18ca68ba985ffa787a3839e839c869c8affa184a186ff9f85a385ffa587a589ffa388a688ffa088a28affa47da87caa80b083af87a985a781a37fa47dffa383a781ff9c889a889a8aff
a18cab8faa92a6909f8dff9b859d849f81ffa78ba98aff9a9698989a999c97ff5e5ddc5ddca65fa65f5effb962b55eb576b87dffd98ddb8dd886d486d48e6160dc60dca6ffdca562a56260ff71616b726b85756e7560ff70797068ff77607774ca74ca60ff8b738b6395639574ff78757287ff629a6c9a6ca5ff63986b877487
__sfx__
62c96aff27d7710646106071a2171a646186363ff312ad312dd771d2361d2763ff0226d022dd7726626266663ff5225d522cd7730226306563ff2324d232bd773a2263a2563ff7323d732bd7704716047463ff44
71ffcc8c0e3160e7463ff1521d1529d7717706173463f727032273b527385473456734900369100223702e772564725227292072f6763321734247262473ff34309743097437d2537d2502a0402a0437d3437d34
a69cae900cb4011b4011b6015b6015f7010f7010f310af310af7006f7006b600cb603ff513f9123f95108e0108e413fd7729a0031e002ce5022e5029a003fb4303a0404a530de030de3303e772fe7036e012ee61
796670ff3fb020da420fe021ae3119a020de7710e5017e500da3106a310fe50231462d146325762e1072e1762b5562b576255762555623576235071f5071e57620576221463f7562f57639546395363351639575
65ff726f2a5472b16731167321572d5473f306395653a5653c5063c51639d7725146261363f3562615628d77271262a1263f3362651623516201361d5461d5661e56624556261362652625d1525d151662616626
65915f910777607f7032d70325763f726251172fd7713726077763ff1516e340fe772593131d70391753914701347013753ff0438d5525e77391471f9323f30600237331373510602e772fd402ad402ad6025d60
5ddc5ddc3f3561167517e77365673056729d403f76601256012260ce7728d2025d201f9013f7160867508e77013762f24706b00013763ff042e93339d77017663b2673ff042d9043ed77376173b627033373f375
ff7b786c26675266751e5751f9651f96528675286751fd771f537325753f326305751f5362cd772d526211062a1463f776231261fd771f536215362612627116281063f7271f52730d3430d341fd773610720942
7dc391ff24e0524e733716737d772b9012b13731526319003ff343195528e770a3470a7160f7760fb403ff74309253a92513e770d7170d7373ff053dd0500e773f5673a90102b0102f1138d11389013fb003dd53
a066a3663de113de5101f5101f113f367132671be001be0013e7728e113da513ff6313e7735e1139a313de313ff6313a4318e773be1134e313fb0315a3314e7721675212763ff02209412e9522ed0220d771b626
c75ec76127626236362464626656252763ff51259712797129d61299612cd712ed713197133d71349223491230d1230d122ed772055625156281362a1262c1063417534107003073f3061e10628a5528a551fd77
d492ca983f7751ed551ed7731175201373f7061e5262fd7721575295463f3061f16623d772c1752a12626146201663f3062713625536215361ed77003160a3160a3473f2473f2163ff042bd042dd770a31614357
9b819b810ab10143573ff6408e640de770a7470d3773fb2512a5527e7735107219323ff73371673716624e0524a6417e770ab01017473fb003d9533d91410a1413257132570e6773dd773a90101b013f36713267
6a9b6dff14e7701f1101f513de513de113fb3213a631ae773de1136e413de1131e313fb1313a6317e772a9602a13730536305673fb021fd312ed422ed021fd771a6261f6262022622626276263fb712597128d51
6b6b71661b6361f2073fb2226d1229d222bd222dd7721206216663fb222dd1230d77206071e2171d227222272421721607225071f176205561d53622546225361f1261f1062312626116265652a1362c5062c546
75896a9e2f5662c507225072956530106311362f14629546215461d1261f10623175295651e5651b7651bb221f9221f5653f7751967719677219432194318a5518e771bf5133e51332260322603e511fd513ff40
6360ff682a97135d4035d7714256146273ff1009a23096652a106221361e5561e5561ed772c5753d5753d5162c5162c5753f7471e1571d5571ed772512625546241561d1563f7062911624d77235061e5061e106
ac9a979a251562453624d772657526506271162b1163f7362015620d7725526275362a5362c1263f7572455726166265751d9551d95525206252061ed773a527066361e21625216322363d6660636706f4039a31
658f689204e0139d203a527205651a7651af2221d22215653fb331e9330ee450ee770427504a70239703fb601e9603fd200de77182751823623236232753fb2226d230ee771b6261b20620206206263ff6025d70
a1b1a1ff289112cd312cd312fd1133d770d617136171320710207106660d6663ff1130d312cd7711676122663fb012cd0129d770f2460d6663ff7025d6027d7716275166563fb41269312cd7722d0213e023fb41
ff91969a37a0219b023fb0317e4517e7730a2119b213fb501461614e770ce310ce223ff501760617e7724941249023f7361763621e773094130d023f7172061717e773e9413e9023ff0020e0017e770da3116e22
bc9fffc625e770fe510fe023fb7016e7016e0114a0112e5012a5014a6016e7730a2130e012be0129e1129e212de212fa213fb7215e4325e772be2135e223ff5215e5221e772ee512ee023ff4318e431fe773ca41
72ffa56e18a341fe7709b4109f713fb2518a251fe7716b4116f711d5651c7651cb221e9221e5653f3171e1173394433d7709375097271cb123f3273357524e77032170360611606116173fb223392229d3329d33
a389a38f362763ff322cd422cd7727607296073fb132c9232cd770936717b6115f7133e7130e612427726267083673ff123ed1201a721fa1321e3521e351ee7723e2023e3024e502ca122ea223fb3521e4525e77
aa6db56d24e703fb2331913315651d13621d772a126361563f7472cd0031d77066170c237201061b3061bf121fd121f5063f3372113732d3432d3421d770c6070c21618216186073ff4231d42299332993331d77
9b8a97ff3ff522b9622bd7732656346563ff522f9622fd7732676336763f7373310622e772f9512fd503ed503e951309513f7071b60721e7734d5134d713f36620207202571be773e9513ed023f3571f2771fe30
98db91ff3e92103e7003e213f77714e3015e7704a3102a413f9513fb001aa0020e7703e3106e513fb2016a401ae771cb50153473d24704f601bf603ff0400e0500e771474711b0016f603fb733c97304a3418a45
89a5879d05f6006f313fb7306a6307e530ba040be770df410ab5105b6103b020bb020df610fb6114f6116b021bb023ff1518a351be551ce77073170a3373ff2105a2108a2110e3110e3109a6113e120ce6106a22
b197ac9903a5103e2105e771aa301aa503fb4107e6108e7715e0115a1118a1118a013ff2207e3209e320be220ba220ae771da1123a6127a4121e012ae312ca2122e603fb221ce1220e321ce3219e772ce2131e21
ff967d982ae313ff2103a1103e7000e703dd013dd013dd771164710267136671526715647126473ff113bd113bd7716257192571b67718a1015e103ff2104e2104e7711677146773fb113e91101e771726717277
7f7bb67b3dd770da000ee103fb513bd613cd7715e00186771e5651b7651bb321f9321f1753fb553ad322ad322c96503e771f9311cb313f356152560ce772996010b6010f313f3270d22702e1402e140ce773fd10
60ff7d6936a103fb303a93035962359623ad770b2270b60728607282273fb221e9222ed770f6560f2753ff122c9012c9012ed7726207262760d2760d207205751a7751ab3220932201063f3672016703a0403a04
ff77846d3f6463f76730d7330d773d5573f6573ff0403a5526e7708f10087670c747103471276712f100db300ab3009f103f3670460625e772dd212d1773956639d303f347086270866612e7733950309502dd60
ad70ffaa07e7735d2035d303ff1128d11269712697128d770a2570a2270d2270d2573ff313ad3138d5138d513ad7728a1027e00272772c2772de002da103fb423e9423c9623c9623ed7729207296662c6662d276
90ffd9812c9522b9622b9622cd7732207326663566636276362073ff132cd132bd232bd232c5062095520955266062660620d77112061125623256232063ff012a11626e771933704b4004f013ff4539d3408e34
d686da8a16f0016b3011b3011b600ab600af0103f0103f310cf123ff4519a2519a251da641da6423a3523e771ab3217f1219f023ff122ad140ae7708b7015b713ff540ca2519e770fb601af413fb1508a5510e77
7c66cb663fb3501a5505e7704b110db711d5751c7751cb521d9521d5753f7571f5573a17528e7726d412690038546389002b9002b1573f3562052625526371172911720d772d5062d5663f3673b9443bd5529e77
5f6366631bb703fb20259203ad770f6360f2573ff4127d413ad7725636252673ff0327d033ad773f6363f2573fb54279543cd771032710f503ff2501e2519e7719f5019f121d1751c3751cb521d9521d1063f356
ca67ca7c385072a1172a1171fd772c5752c1073f7571f5573a17529e773c557087571cf523f367269542696510e7705636052573ff7027d703ad7719636192573fb22279223ad7730636302573fb73279733cd77
628c74ff3fb05359050de7716b2016f513f3361923601637295373fd773151731d403f7760666606e772ed202ed303f7173e5173d1273d1751dd551dd5525275252751dd773217532527206273f7673456722960
ffa37ba3331371f9223ff341ed343595524e770c3170c3161531715b200c3173ff053ad052cd77003662626623666226272124722257053570674705347222473ff123692436d2433d142e9042cd770572705737
89ff88883f9323f9323bd77027570237704377047573ff2002a2005e3006e3004e2002e7708e1010e1019e2013a503fb700fa3012a300fe200da300aa3007e7706a500be600fa6011e4011a300de103fb600be70
93999c970ba403ff4007e4009e770ba300ea303ff6005e6007e7708e00086773ff2000e203fd7702e1001e103fb1006e0007e770ee600fe7012e7013a6010e503fb010be310be020da7110e610ea310ea4112a12
9f9e9b9a13e7716e1112e0114e3116a4114a5111a5112a410ea1110a013ff0115a1115e7719e6019a603ff5115a1210e2211a420fe7720e2128a4124a511fa313fb221aa421ca6218e4217a3219e771da4123e61
c283c28b3ff121de221fa1222e7122e021e2751d9651d96526275262751dd773217532547311573f31738d5038d772a247083473fb441d94438d5525e770fb500fb7005b7005f300ef303ff5402e1402a2408e77
7193ff6804b703fb3521a6421a6419a3519a3521e7712b110ab110cf513ff4413e441ba6421e77306373060603706037373f7563b1460324613e772892031920355573595031d1128d113f3663b1273bd7731d20
d45effbf13675246751dd551dd5525675256751dd77331753352708727087653ff021ed0235d772a2272a60639606392273fb44299531ed77087463f6653fb44299241dd77083460c7653fb44289051ed7708746
869a86a221d2420d5420d7422d77083371ab223ff1022e1024e7700a1200a223f3572225724e7737912379223ff101fe1014a300ea3019e770db100d7461333713f013f3273656608e7702e513ad5137d0203e02
5fa55f5e04a1204e713f7360920619e7720d7128d71289223f7460960709607202072166621e772f9022f9412cd712c9223f7761921718e77299122bd023f3461e2070ae772c9412cd512bd51205651b7651bf22
be5effc83f7171d51735d4106e41301271ed77341372cd403f3361f2070be772cd412d9313ff4137d443795524e770db200d3461473714b313ff0236d021ed772a2372a60639606392373fb44369441ed7708736
9e6ba369279241ed7708736123753fb4427d641dd77027060a7060d3163f7372563722e773ad223a9123fb0025a0022e770a6170c6170c2273f3751c6360a6070a6071c6762066620e772090228902289223f756
ff9e689e24e77279122e94130d213f7761867620e7702e513ad5137d0203e023fb1022a1024e7703a0203a2106a7006e1203e123fb301ce1022e5029d2127942279722997239942379113796039d770c2560c257
ffbc98bb37d771ed11239302e90129d021ed413f3753e1170e26626e773397005e4010a302ce2039a403ff740ea2511e5516e7734a313be7001f7001b4133e313fb5318a3320a0320a031ee331de7736e6137e31
c890ce8a1fe773ee413ee713ff5320a0420e1421e0423a5322a5321e773be703da5037a7036a0132a7035e603be303ff040fe140be2411e2415a4413e340de7705f6007f6007b5004f303fb530be430be430ae77
7dc07ebf0cb010ab1108b113fb2412e0415e0416e2414e770bb500bf403fb0509a1508e7710b6012b603ff7304e6306a4306e5302e733ed7703f303ea103f277007670436709777077770ff2004f300ab103ff14
616d6aff3fd770637709b003ff0402a1402a1403a2403a2404e771d5651a7651af321ed321e1753ff7306a140627520d4520d45262062620620d77211562a2562ae223f7061d6271d62725e772a256187063f706
8f78ff9329506341563f7072214728d7739146172460d216301163fb3121d3229d7723606312463ff532192424d77087060d7163fb1024d1024d2025d1026d0026d00245651e9651e9652a6652a66520d7707217
7d8f7bff3c97102e7722a2028e303f357349402cd2134d773d1173d1773fb112d9113ed770e6760e6663f7673ad513ad513ed771e5671b7673fb003d9003bd7704667046573ff303dd303bd770b6670b6573ff70
ffcc9ac015257156673fb413a9413dd772da5034a703fb2311e0415a2410a430ce7733e0136e5038a5038e6035a113ff1411e0515a051ae0414e7718f611ab711cb611bb5119b513ff051be4522e7717f121bb12
8473847022e773da1203f123ff5520a3220e221da021ba711be611ca511ae311ae1119e011ae701ce501ca401fa6021e3024e3026e5028e4029e770c26614266102560d2663ff0519a451de451aa1516e7706617
637f68870c2070c6170b6173ff60359013590137d773f1473f1370623706247002473fb6038d4038d40361752095520955272752727521d7732d32172271e22707b323f7651b606216262425627e772410621516
966d986b2cd6031d11359413bd413f34721527235272f5373956703e0008e200be770b6060423604207086470c6670f2773ff113890137d6033d602a9112696125d02259322ad32319323791238d771761716217
c79ac5961e65620276206071f6173fb6221d7224d132bd1333d0338d623dd3200e773d675013260275603727007773ae2035a4031a503ff152193527d253bd0505e7710b3012b3015f4015b0114b310ff510bb61
a0d3a4cf05b1107f600bb400fb303ff2415e0418e7319e7719f5117b0213b220fb322b506231261d106255652b5062a536211562212624565205261d55621156275062a11624d7705f2101b413fe413ff451be35
__music__
0d 2b6e7f30
0a 6b30657f
05 3564356c
0b 7f3a6a3a
06 647f3f64
0d 3f6b7f44
0a 6a44637f
05 4a624a69
0b 7f4f694f
06 627f5361
0d 53697f57
0a 6857617f
02 7500757a
00 76767b74
04 7e740078
0b 02017501
0b 7f247827
0a 712e6f33
0a 73347824
0e 787f4002
05 40774777
05 47714e71
05 4e775577
0f 55014101
0f 7f4c0850
0f 08500c55
0f 0c550f50
0f 0f50174b
0f 174b0f46
0f 0f460c4b
0f 0c4b087f
05 1a7f227f
0f 19091109
0d 1a7f7f10
0f 0b170c0d
0f 1705160f
0f 0b7f2a00
0f 32012b0c
0f 230c2a00
0f 7f370340
0f 043a0e32
0f 0e36037f
0f 2e103611
0f 2f1d261d
0f 2d117f20
0f 0d280f21
0f 1a171a20
03 0e7f5d5d
00 5f5d5f5e
04 616a0469
0b 7f046804
08 7162747f
00 656b6573
01 7f6a6a6a
02 737f6f6a
04 6f727f74
08 6974717f
00 78697872
01 7f7c697c
06 717f016a
0d 01717f5b
0a 6014677f
05 5b681b6e
0b 7f0f6913