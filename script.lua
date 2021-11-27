-- Battle Matchmaker
-- Version 1.5.1

g_players={}
g_popups={}
g_status_text=nil
g_vehicles={}
g_spawned_vehicles={}
g_status_dirty=false
g_finish_dirty=false
g_in_game=false
g_in_countdown=false
g_pause=false
g_timer=0
g_remind_interval=3600

g_ammo_supply_buttons={
	MG_K={42,50},
	MG_AP={45,50},
	MG_I={46,50},

	LA_K={47,50},
	LA_HE={48,50},
	LA_F={49,50},
	LA_AP={50,50},
	LA_I={51,50},

	RA_K={52,25},
	RA_HE={53,25},
	RA_F={54,25},
	RA_AP={55,25},
	RA_I={56,25},

	HA_K={57,10},
	HA_HE={58,10},
	HA_F={59,10},
	HA_AP={60,10},
	HA_I={61,10},

	BS_K={62,1},
	BS_HE={63,1},
	BS_F={64,1},
	BS_AP={65,1},
	BS_I={66,1},

	AS_HE={68,1},
	AS_F={66,1},
	AS_AP={70,1},
}

g_classes={
	ground_light	={hp=300},
	ground_medium	={hp=1200},
	ground_heavy	={hp=2400},
	ground_mega		={hp=3000},
	ground_boss		={hp=20000},
}

g_item_supply_buttons={
	['Take Extinguisher']	={1,10,0,  9},
	['Take Torch']			={1,27,0,400},
	['Take Welder']			={1,26,0,250},
	['Take FlashLight']		={2,15,0,100},
	['Take Binoculars']		={2, 6,0,  0},
	['Take NightVision']	={2,17,0,100},
	['Take Compass']		={2, 8,0,  0},
	['Take FirstAidKit']	={2,11,4,  0},
}

g_default_savedata={
	base_hp				=property.slider('Default Vehicle HP', 0, 5000, 100, 2000),
	battery_name		='killed',
	supply_ammo_amount	=property.slider('Default Ammo Supply', 0, 100, 1, 40),
	order_command		=property.checkbox('Default Order Command Enabled', true),
	cd_time_sec			=property.slider('Default Countdown time (sec)', 5, 60, 1, 10),
	game_time_min		=property.slider('Default Game time (min)', 1, 60, 1, 20),
	remind_time_min		=property.slider('Default Remind time (min)', 1, 10, 1, 1),
	tps_enable			=property.checkbox('Default Third Person Enabled', false),
	extinguisher_volume	=property.slider('Default Extinguisher Volume (%)', 1, 100, 1, 100),
	torch_volume		=property.slider('Default Torch Volume (%)', 1, 100, 1, 100),
	welder_volume		=property.slider('Default Welder Volume (%)', 1, 100, 1, 100),
	supply_vehicles={},
	flag_vehicles={},
}

-- Commands --

g_commands={
	{
		name='join',
		auth=true,
		action=function(peer_id, is_admin, is_auth, team_name, target_peer_id)
			if g_in_game and not is_admin then
				announce('Cannot join after game start..', peer_id)
				return
			end
			if not checkTargetPeerId(target_peer_id, peer_id, is_admin) then return end
			join(target_peer_id or peer_id, team_name, is_admin)
		end,
		args={
			{name='team_name', type='string', require=true},
			{name='peer_id', type='integer', require=false},
		},
	},
	{
		name='leave',
		auth=true,
		action=function(peer_id, is_admin, is_auth, target_peer_id)
			if not checkTargetPeerId(target_peer_id, peer_id, is_admin) then return end
			leave(target_peer_id or peer_id)
		end,
		args={
			{name='peer_id', type='integer', require=false},
		},
	},
	{
		name='die',
		auth=true,
		action=function(peer_id, is_admin, is_auth, target_peer_id)
			if not g_in_game then
				announce('Cannot die before game start.', peer_id)
				return
			end
			if not checkTargetPeerId(target_peer_id, peer_id, is_admin) then return end
			kill(target_peer_id or peer_id)
		end,
		args={
			{name='peer_id', type='integer', require=false},
		},
	},
	{
		name='ready',
		auth=true,
		action=function(peer_id, is_admin, is_auth, target_peer_id)
			if g_in_game then
				announce('Cannot ready after game start.', peer_id)
				return
			end
			if not checkTargetPeerId(target_peer_id, peer_id, is_admin) then return end
			ready(target_peer_id or peer_id)
		end,
		args={
			{name='peer_id', type='integer', require=false},
		},
	},
	{
		name='wait',
		auth=true,
		action=function(peer_id, is_admin, is_auth, target_peer_id)
			if g_in_game then
				announce('Cannot wait after game start.', peer_id)
				return
			end
			if not checkTargetPeerId(target_peer_id, peer_id, is_admin) then return end
			wait(target_peer_id or peer_id)
		end,
		args={
			{name='peer_id', type='integer', require=false},
		},
	},
	{
		name='order',
		auth=true,
		action=function(peer_id, is_admin, is_auth)
			if g_in_game then
				announce('Cannot order after game start.', peer_id)
				return
			end
			if not g_savedata.order_command then
				announce('Order command is not available.', peer_id)
				return
			end
			local player=g_players[peer_id]
			if not player then
				announce('Joind player not found. peer_id:'..tostring(peer_id), peer_id)
				return
			end
			if not player.alive then
				announce('Dead player cannot order vehicle.', peer_id)
				return
			end
			if player.vehicle_id<=0 then
				announce('Vehicle not found.', peer_id)
				return
			end

			server.setVehiclePos(player.vehicle_id, getAheadMatrix(peer_id, 2, 8))
			announce('Vehicle orderd.', peer_id)
		end,
	},
	{
		name='start',
		auth=true,
		action=function(peer_id, is_admin, is_auth)
			startCountdown(true, peer_id)
		end,
	},
	{
		name='stop',
		auth=true,
		action=function(peer_id, is_admin, is_auth)
			stopCountdown()
		end,
	},
	{
		name='supply',
		auth=true,
		action=function(peer_id, is_admin, is_auth)
			if g_in_game and not is_admin then
				announce('Cannot call supply after game start.', peer_id)
				return
			end
			spawnSupply(peer_id)
			announce('supply object deployed.', peer_id)
		end,
	},
	{
		name='delete_supply',
		auth=true,
		action=function(peer_id, is_admin, is_auth)
			despawnSupply(peer_id)
		end,
	},
	{
		name='clear_supply',
		admin=true,
		action=function(peer_id, is_admin, is_auth)
			clearSupplies()
			clearFlags()
			announce('All supplies cleared.', -1)
		end,
	},
	{
		name='flag',
		admin=true,
		action=function(peer_id, is_admin, is_auth, name)
			spawnFlag(peer_id, name:lower())
		end,
		args={
			{name='name', type='string', require=true},
		},
	},
	{
		name='delete_flag',
		admin=true,
		action=function(peer_id, is_admin, is_auth, name)
			despawnFlag(peer_id, name:lower())
		end,
		args={
			{name='name', type='string', require=true},
		},
	},
	{
		name='clear_flag',
		admin=true,
		action=function(peer_id, is_admin, is_auth)
			clearFlags()
			announce('All flags cleared.', -1)
		end,
	},
	{
		name='pause',
		admin=true,
		action=function(peer_id, is_admin, is_auth)
			if not g_in_game then
				announce('Cannot pause before game start.', peer_id)
				return
			end
			if g_pause then return end
			g_pause=true
			notify('Timer Operation', 'Game is paused.', 1, -1)
		end,
	},
	{
		name='resume',
		admin=true,
		action=function(peer_id, is_admin, is_auth)
			if not g_pause then
				announce('Cannot resume when not in pause.', peer_id)
				return
			end
			g_pause=false
			notify('Timer Operation', 'Game is resumed.', 1, -1)
		end,
	},
	{
		name='add_time',
		admin=true,
		action=function(peer_id, is_admin, is_auth, minute)
			if not g_in_game then
				announce('Cannot add time before game start.', peer_id)
				return
			end
			g_timer=g_timer+(minute*60*60//1|0)
			if g_timer>0 then
				local timerMin=g_timer//3600
				notify('Timer Updated', 'The remaining time has been changed to '..tostring(timerMin)..' minutes', 1, -1)
			end
		end,
		args={
			{name='minute', type='number', require=true},
		},
	},
	{
		name='reset',
		admin=true,
		action=function(peer_id, is_admin, is_auth)
			g_players={}
			g_vehicles={}
			g_status_dirty=true
			setPopup('status', false)
			clearSupplies()
			clearFlags()
			finishGame()
			announce('Reset game.', -1)
		end,
	},
	{
		name='reset_ui',
		auth=true,
		action=function(peer_id, is_admin, is_auth)
			renewPopupIds()
			announce('Refresh ui ids.', -1)
		end,
	},
	{
		name='set_hp',
		admin=true,
		action=function(peer_id, is_admin, is_auth, hp)
			g_savedata.base_hp=hp
			reregisterVehicles()
			announce('Set base vehicle hp to '..tostring(g_savedata.base_hp), -1)
		end,
		args={
			{name='hp', type='integer', require=true},
		},
	},
	{
		name='set_battery',
		admin=true,
		action=function(peer_id, is_admin, is_auth, battery_name)
			g_savedata.battery_name=battery_name
			reregisterVehicles()
			announce('Set lifeline battery name to '..tostring(g_savedata.battery_name), -1)
		end,
		args={
			{name='battery_name', type='string', require=true},
		},
	},
	{
		name='set_ammo',
		admin=true,
		action=function(peer_id, is_admin, is_auth, supply_ammo_amount)
			g_savedata.supply_ammo_amount=supply_ammo_amount
			reregisterVehicles()
			announce('Set supply ammo count to '..tostring(g_savedata.supply_ammo_amount), -1)
		end,
		args={
			{name='supply_ammo_amount', type='integer', require=true},
		},
	},
	{
		name='set_order',
		admin=true,
		action=function(peer_id, is_admin, is_auth, enabled)
			if enabled then
				announce('order command enabled.', -1)
				g_savedata.order_command=true
			else
				announce('order command disabled.', -1)
				g_savedata.order_command=false
			end
		end,
		args={
			{name='true|false', type='boolean', require=true},
		},
	},
	{
		name='set_cd_time',
		admin=true,
		action=function(peer_id, is_admin, is_auth, cd_time_sec)
			if cd_time_sec<1 then
				announce('Cannot set time under 1.', peer_id)
				return
			end
			g_savedata.cd_time_sec=cd_time_sec
			announce('Set countdown time to '..tostring(cd_time_sec)..' sec.', -1)
		end,
		args={
			{name='second', type='number', require=true},
		},
	},
	{
		name='set_game_time',
		admin=true,
		action=function(peer_id, is_admin, is_auth, game_time_min)
			if game_time_min<1 then
				announce('Cannot set time under 1.', peer_id)
				return
			end
			g_savedata.game_time_min=game_time_min
			announce('Set game time to '..tostring(game_time_min)..' min.', -1)
		end,
		args={
			{name='minute', type='number', require=true},
		},
	},
	{
		name='set_remind_time',
		admin=true,
		action=function(peer_id, is_admin, is_auth, remind_time_min)
			if remind_time_min<1 then
				announce('Cannot set time under 1.', peer_id)
				return
			end
			g_savedata.remind_time_min=remind_time_min
			announce('Set remind time to '..tostring(remind_time_min)..' min.', -1)
		end,
		args={
			{name='minute', type='number', require=true},
		},
	},
	{
		name='set_tps',
		admin=true,
		action=function(peer_id, is_admin, is_auth, enabled)
			if enabled then
				announce('Third person enabled.', -1)
				g_savedata.tps_enable=true
			else
				announce('Third person disabled.', -1)
				g_savedata.tps_enable=false
			end
		end,
		args={
			{name='true|false', type='boolean', require=true},
		},
	},
	{
		name='set_ext_volume',
		admin=true,
		action=function(peer_id, is_admin, is_auth, volume)
			volume=clamp(volume,1,100)
			g_savedata.extinguisher_volume=volume
			announce('Set extinguisher volume to '..tostring(volume)..'%.', -1)
		end,
		args={
			{name='volume(%)', type='number', require=true},
		},
	},
	{
		name='set_torch_volume',
		admin=true,
		action=function(peer_id, is_admin, is_auth, volume)
			volume=clamp(volume,1,100)
			g_savedata.torch_volume=volume
			announce('Set torch volume to '..tostring(volume)..'%.', -1)
		end,
		args={
			{name='volume(%)', type='number', require=true},
		},
	},
	{
		name='set_welder_volume',
		admin=true,
		action=function(peer_id, is_admin, is_auth, volume)
			volume=clamp(volume,1,100)
			g_savedata.welder_volume=volume
			announce('Set welder volume to '..tostring(volume)..'%.', -1)
		end,
		args={
			{name='volume(%)', type='number', require=true},
		},
	},
}

function findCommand(command)
	for i,command_define in ipairs(g_commands) do
		if command_define.name==command then
			return command_define
		end
	end
end

function showHelp(peer_id, is_admin, is_auth)
	local commands_help='Commands:\n'
	local any_commands=false
	for i,command_define in ipairs(g_commands) do
		if checkAuth(command_define, is_admin, is_auth) then
			local args=''
			if command_define.args then
				for i,arg in ipairs(command_define.args) do
					if arg.require then
						args=args..' ['..arg.name..']'
					else
						args=args..' ('..arg.name..')'
					end
				end
			end
			commands_help=commands_help..'  - ?mm '..command_define.name..args..'\n'
			any_commands=true
		end
	end
	if any_commands then
		announce(commands_help, peer_id)
	else
		announce('Permitted command is not found.', peer_id)
	end
end

function checkAuth(command, is_admin, is_auth)
	return is_admin or (not command.admin and (is_auth or not command.auth))
end

function checkTargetPeerId(target_peer_id, peer_id, is_admin)
	if not target_peer_id then return true end
	if not is_admin then
		announce('Permission denied. Only admin can specify target_peer_id.', peer_id)
		return false
	end
	local _, is_success=server.getPlayerName(target_peer_id)
	if not is_success then
		announce('Invalid peer_id.', peer_id)
		return false
	end
	return true
end

-- Callbacks --

function onCreate(is_world_create)
	for k,v in pairs(g_default_savedata) do
		if not g_savedata[k] then
			g_savedata[k]=v
		end
	end

	clearSupplies()
	clearFlags()

	registerPopup('status', -0.9, 0.2)
	registerPopup('countdown', 0, 0.8)

	setSettingsToStandby()
end

function onDestroy()
	clearPopups()
	clearSupplies()
	clearFlags()
end

function onTick()
	for i=1,#g_vehicles do
		updateVehicle(g_vehicles[i])
	end

	if g_in_countdown then
		if g_timer>0 then
			local sec=g_timer//60
			g_timer=g_timer-1
			g_countdown_text=string.format('Start in\n%.0f', sec)
			setPopup('countdown', true, string.format('Start in\n%.0f', sec))
		else
			startGame()
			notify('Game Start', 'Panzer Vor!', 9, -1)
		end
	end
	if g_in_game then
		if g_pause then
		elseif g_timer>0 then
			local sec=g_timer//60
			g_timer=g_timer-1
			local time_text=string.format('%02.f:%02.f', sec//60,sec%60)
			setPopup('countdown', true, time_text)

			if g_timer>0 and g_timer%g_remind_interval==0 then
				server.notify(-1, 'Time Reminder', time_text..' left.', 1)
			end
		else
			finishGame()
			notify('Game End', 'Timeup!', 9, -1)
		end
	end

	if g_finish_dirty then
		g_finish_dirty=false
		checkFinish()
	end

	if g_status_dirty then
		g_status_dirty=false
		updateStatus()
	end

	updatePopups()
end

function onPlayerJoin(steam_id, name, peer_id, is_admin, is_auth)
	renewPopupIds()
end

function onPlayerLeave(steam_id, name, peer_id, admin, auth)
	leave(peer_id)
	despawnSupply(peer_id)
end

function onPlayerDie(steam_id, name, peer_id, is_admin, is_auth)
	kill(peer_id)
end

function onButtonPress(vehicle_id, peer_id, button_name)
	if not peer_id or peer_id<0 then return end
	local character_id, is_success=server.getPlayerCharacterID(peer_id)
	if not is_success then return end

	if button_name=='?mm die' then
		kill(peer_id)
		return
	elseif button_name=='?mm ready' then
		ready(peer_id)
		return
	end

	if isSupply(vehicle_id) then
		if not server.getVehicleButton(vehicle_id, button_name).on then return end
		local item_supply=g_item_supply_buttons[button_name]
		if item_supply then
			local slot,equipment_id,v1,v2=table.unpack(item_supply)
			slot=findEmptySlot(character_id, slot)
			if not slot then
				announce('Inventory is full.', peer_id)
				return
			end
			if equipment_id==10 then
				v2=v2*g_savedata.extinguisher_volume*0.01
			elseif equipment_id==27 then
				v2=v2*g_savedata.torch_volume*0.01
			elseif equipment_id==26 then
				v2=v2*g_savedata.welder_volume*0.01
			end
			server.setCharacterItem(character_id, slot, equipment_id, false, v1, v2)
		elseif button_name=='Join RED' then
			join(peer_id, 'RED')
		elseif button_name=='Join BLUE' then
			join(peer_id, 'BLUE')
		elseif button_name=='Join PINK' then
			join(peer_id, 'PINK')
		elseif button_name=='Join YLW' then
			join(peer_id, 'YLW')
		elseif button_name=='Leave' then
			leave(peer_id)
		elseif button_name=='Clear Large Equipment' then
			server.setCharacterItem(character_id, 1, 0, false)
		elseif button_name=='Clear Small Equipments' then
			server.setCharacterItem(character_id, 2, 0, false)
			server.setCharacterItem(character_id, 3, 0, false)
			server.setCharacterItem(character_id, 4, 0, false)
			server.setCharacterItem(character_id, 5, 0, false)
		elseif button_name=='Clear Outfit' then
			server.setCharacterItem(character_id, 6, 0, false)
		end
		return
	end

	if g_savedata.supply_ammo_amount<=0 then return end

	local equipment_data=g_ammo_supply_buttons[button_name]
	if not equipment_data then return end
	local equipment_id=equipment_data[1]
	local equipment_amount=equipment_data[2]

	local current_equipment_id=server.getCharacterItem(character_id, 1)
	if current_equipment_id>0 then
		if current_equipment_id~=equipment_id then
			announce('Your large inventory is full.', peer_id)
		end
		return
	end

	local vehicle=findVehicle(vehicle_id)
	if vehicle and vehicle.remain_ammo<=0 then
		announce('Out of ammo.', peer_id)
		return
	end

	server.setCharacterItem(character_id, 1, equipment_id, true, equipment_amount)

	if vehicle then
		vehicle.remain_ammo=vehicle.remain_ammo-1
		announce('Ammo here! (Remain:'..tostring(vehicle.remain_ammo)..')', peer_id)
	else
		announce('Ammo here!', peer_id)
	end
end

function onPlayerSit(peer_id, vehicle_id, seat_name)
	local player=g_players[peer_id]
	if not player or not player.alive then return end

	local vehicle=registerVehicle(vehicle_id)
	if vehicle and vehicle.alive then
		player.vehicle_id=vehicle_id
	end
	g_status_dirty=true
end

function onVehicleSpawn(vehicle_id, peer_id, x, y, z, cost)
	if not peer_id or peer_id<0 then return end
	g_spawned_vehicles[vehicle_id]=peer_id
end

function onVehicleLoad(vehicle_id)
	local peer_id=g_spawned_vehicles[vehicle_id]
	if not peer_id then return end

	g_spawned_vehicles[vehicle_id]=nil
	local player=g_players[peer_id]
	if not player or not player.alive then return end

	local vehicle=registerVehicle(vehicle_id)
	if vehicle and vehicle.alive then
		player.vehicle_id=vehicle_id
	end
	g_status_dirty=true
end

function onVehicleDespawn(vehicle_id, peer_id)
	g_spawned_vehicles[vehicle_id]=nil
	unregisterVehicle(vehicle_id)
end

function onVehicleDamaged(vehicle_id, damage_amount, voxel_x, voxel_y, voxel_z)
	if not g_in_game then return end
	if damage_amount<=0 then return end

	local vehicle=findVehicle(vehicle_id)
	if not vehicle then return end

	if vehicle.hp then
		vehicle.hp=math.max(vehicle.hp-damage_amount,0)
		g_status_dirty=true
	end
end

function onCustomCommand(full_message, peer_id, is_admin, is_auth, command, one, two, three, four, five)
	if command~='?mm' then return end

	if not one then
		showHelp(peer_id, is_admin, is_auth)
		announce(
			'Current settings:\n'..
			'  - base hp: '..tostring(g_savedata.base_hp)..'\n'..
			'  - battery name: '..g_savedata.battery_name..'\n'..
			'  - ammo amount: '..tostring(g_savedata.supply_ammo_amount)..'\n'..
			'  - order command enabled: '..tostring(g_savedata.order_command)..'\n'..
			'  - countdown time: '..tostring(g_savedata.cd_time_sec)..'sec\n'..
			'  - game time: '..tostring(g_savedata.game_time_min)..'min\n'..
			'  - remind time: '..tostring(g_savedata.remind_time_min)..'min\n'..
			'  - third person enabled: '..tostring(g_savedata.tps_enable)..'\n'..
			'  - extinguisher volume: '..tostring(g_savedata.extinguisher_volume)..'%\n'..
			'  - torch volume: '..tostring(g_savedata.torch_volume)..'%\n'..
			'  - welder volume: '..tostring(g_savedata.welder_volume)..'%',
			peer_id)
		return
	end

	local command_define=findCommand(one)
	if not command_define then
		announce('Command "'..one..'" not found.', peer_id)
		return
	end
	if not checkAuth(command_define, is_admin, is_auth) then
		announce('Permission denied.', peer_id)
		return
	end

	local args={two, three, four, five}
	if command_define.args then
		for i,arg_define in ipairs(command_define.args) do
			if #args < i then
				if arg_define.require then
					announce('Argument not enough. Except ['..arg_define.name..'].', peer_id)
					return
				end
				break
			end
			local value=convert(args[i], arg_define.type)
			if value==nil then
				announce('Except '..arg_define.type..' to ['..arg_define.name..'].', peer_id)
				return
			end
			args[i]=value
		end
	end

	command_define.action(peer_id, is_admin, is_auth, table.unpack(args))
end

-- Player Functions --

function join(peer_id, team, force)
	if g_in_game and not force then return end
	local name, is_success=server.getPlayerName(peer_id)
	if not is_success then return end
	local player={
		name=name,
		team=team,
		alive=true,
		ready=g_in_game,
		vehicle_id=-1,
	}
	g_players[peer_id]=player

	local character_id=server.getPlayerCharacterID(peer_id)
	local vehicle_id, is_success=server.getCharacterVehicle(character_id)
	if is_success then
		local vehicle=registerVehicle(vehicle_id)
		if vehicle and vehicle.alive then
			player.vehicle_id=vehicle_id
		end
	end

	g_status_dirty=true

	announce('You joined to '..team..'.', peer_id)

	stopCountdown()
end

function leave(peer_id)
	local player=g_players[peer_id]
	if not player then return end
	g_players[peer_id]=nil
	g_status_dirty=true

	announce('You leaved from '..player.team..'.', peer_id)

	if g_in_game then
		g_finish_dirty=true
	else
		if player.ready then
			stopCountdown()
		else
			startCountdown()
		end
	end
end

function kill(peer_id)
	if not g_in_game then return end
	local player=g_players[peer_id]
	if not player or not player.alive then return end
	player.alive=false
	player.vehicle_id=-1
	g_status_dirty=true
	notify('Kill Log', player.name..' is dead.', 9, -1)
	g_finish_dirty=true
end

function ready(peer_id)
	if g_in_game then return end
	local player=g_players[peer_id]
	if not player or player.ready then return end
	if not player.alive then
		announce('Cannot ready for dead player.', peer_id)
		return
	end
	player.ready=true
	startCountdown()
	g_status_dirty=true
end

function wait(peer_id)
	if g_in_game then return end
	local player=g_players[peer_id]
	if not player or not player.ready then return end
	player.ready=false
	stopCountdown()
	g_status_dirty=true
end

-- Vehicle Functions --

function findVehicle(vehicle_id)
	for i=1,#g_vehicles do
		local vehicle=g_vehicles[i]
		if vehicle.vehicle_id==vehicle_id then
			return vehicle,i
		end
	end
end

function registerVehicle(vehicle_id)
	local vehicle=findVehicle(vehicle_id)
	if vehicle then return vehicle end
	if g_in_game then return end

	vehicle={
		vehicle_id=vehicle_id,
		alive=true,
		remain_ammo=g_savedata.supply_ammo_amount//1|0,
		gc_time=600,
	}

	local base_hp=g_savedata.base_hp
	for class_name,class in pairs(g_classes) do
		local sign_data, is_success = server.getVehicleSign(vehicle_id, class_name)
		if is_success then
			base_hp=class.hp
			break
		end
	end

	if base_hp and base_hp>0 then
		vehicle.hp=math.max(base_hp//1|0,1)
	end

	local battery_name=g_savedata.battery_name
	if battery_name then
		local battery, is_success=server.getVehicleBattery(vehicle_id, battery_name)
		if is_success and battery.charge>0 then
			vehicle.battery_name=battery_name
		end
	end

	if vehicle.hp or vehicle.battery_name then
		table.insert(g_vehicles, vehicle)
		return vehicle
	end
end

function unregisterVehicle(vehicle_id)
	local vehicle,index=findVehicle(vehicle_id)
	if not vehicle then return end
	table.remove(g_vehicles,index)

	for peer_id,player in pairs(g_players) do
		if player.vehicle_id==vehicle_id then
			player.vehicle_id=-1
			if g_in_game then
				kill(peer_id)
			end
		end
	end

	g_status_dirty=true
end

function reregisterVehicles()
	for i=1,#g_vehicles do
		local vehicle=g_vehicles[i]
		if vehicle.alive then
			vehicle.hp=nil
			local base_hp=g_savedata.base_hp
			if base_hp and base_hp>0 then
				vehicle.hp=math.max(base_hp//1|0,1)
			end

			vehicle.battery_name=nil
			local battery_name=g_savedata.battery_name
			if battery_name then
				local battery, is_success=server.getVehicleBattery(vehicle.vehicle_id, battery_name)
				if is_success and battery.charge>0 then
					vehicle.battery_name=battery_name
				end
			end

			vehicle.remain_ammo=g_savedata.supply_ammo_amount//1|0

			g_status_dirty=true
		end
	end
end

function updateVehicle(vehicle)
	if not vehicle.alive then
		if vehicle.gc_time>0 then
			vehicle.gc_time=vehicle.gc_time-1
		else
			server.despawnVehicle(vehicle.vehicle_id, true)
		end
		return
	end

	local vehicle_id=vehicle.vehicle_id

	if vehicle.battery_name then
		local battery, is_success=server.getVehicleBattery(vehicle_id, vehicle.battery_name)
		if is_success and battery.charge<=0 then
			vehicle.alive=false
		end
	end

	if vehicle.hp==0 then
		vehicle.alive=false
	end

	if vehicle.alive then
		return
	end

	-- explode
	local vehicle_matrix, is_success=server.getVehiclePos(vehicle_id)
	if is_success then
		server.spawnExplosion(vehicle_matrix, 0.17)
	end

	-- kill
	for peer_id,player in pairs(g_players) do
		if player.vehicle_id==vehicle_id then
			-- force getout
			local player_matrix, is_success=server.getPlayerPos(peer_id)
			if is_success then
				server.setPlayerPos(peer_id, player_matrix)
			end

			player.vehicle_id=-1
			kill(peer_id)
		end
	end

	server.setVehicleTooltip(vehicle_id, 'Destroyed')
	g_status_dirty=true
end

-- System Functions --

function updateStatus()
	local team_stats={}
	local any=false
	for _,player in pairs(g_players) do
		local stat=team_stats[player.team]
		if not stat then
			stat=''
		end

		local hp=nil
		local battery_name=nil
		if player.vehicle_id>=0 then
			local vehicle=findVehicle(player.vehicle_id)
			if vehicle then
				hp=vehicle.hp
				battery_name=vehicle.battery_name
			end
		end

		team_stats[player.team]=stat..'\n'..playerToString(player.name,player.alive,player.ready,hp,battery_name)
		any=true
	end

	if any then
		local status_text=''
		local first=true
		for team,stat in pairs(team_stats) do
			if not first then status_text=status_text..'\n\n' end
			status_text=status_text..'* Team '..team..' *'..stat
			first=false
		end
		setPopup('status', true, status_text)
	else
		setPopup('status', false)
	end
end

function playerToString(name, alive, ready, hp, bat)
	local stat_text=alive and (g_in_game and 'Alive' or (ready and 'Ready' or 'Wait')) or 'Dead'
	local hp_text=hp and string.format('\nHP:%.0f',hp) or ''
	local battery_text=bat and '\n(B)' or ''
	return name..'\nStat:'..stat_text..hp_text..battery_text
end

function startCountdown(force, peer_id)
	if g_in_game or g_in_countdown then return end
	local ready=true
	local teams={}
	for peer_id,player in pairs(g_players) do
		ready=ready and player.ready
		teams[player.team]=true
	end
	if not ready then
		if force then
			announce('There is unready player(s).', peer_id)
		end
		return
	end

	local team_count=getTableCount(teams)
	if team_count<1 or (team_count<2 and not force) then
		if force then
			announce('There are not enough registered teams.', peer_id)
		end
		return
	end
	announce('Countdown start.', -1)
	g_timer=g_savedata.cd_time_sec*60//1|0
	g_in_countdown=true
	g_status_dirty=true
end

function stopCountdown()
	if g_in_game or not g_in_countdown then return end
	announce('Countdown stop.', -1)
	setPopup('countdown', false)
	g_in_countdown=false
	g_status_dirty=true
end

function checkFinish()
	if not g_in_game then return end
	local team_aliver_counts={}
	local any=false
	for _,player in pairs(g_players) do
		local add=player.alive and 1 or 0
		local count=team_aliver_counts[player.team]
		team_aliver_counts[player.team]=count and (count+add) or add
		any=true
	end
	if not any then
		finishGame()
		notify('Game End', 'No player. Game is interrupted.', 6, -1)
		return
	end
	local alive_team_count=0
	local alive_team_name=''
	for team_name,team_aliver_count in pairs(team_aliver_counts) do
		if team_aliver_count>0 then
			alive_team_count=alive_team_count+1
			alive_team_name=team_name
		end
	end
	if alive_team_count>1 then return end

	finishGame()
	if alive_team_count==1 then
		notify('Game End', 'Team '..alive_team_name..' Win!', 9, -1)
	else
		notify('Game End', 'Draw Game!', 9, -1)
	end
end

function startGame()
	g_in_game=true
	g_in_countdown=false
	g_pause=false
	g_status_dirty=true
	g_timer=g_savedata.game_time_min*60*60//1|0
	g_remind_interval=g_savedata.remind_time_min*60*60//1|0

	for _,player in pairs(g_players) do
		player.ready=false
	end

	clearSupplies()
	setSettingsToBattle()
end

function finishGame()
	g_in_game=false
	g_in_countdown=false
	g_pause=false
	g_status_dirty=true
	setPopup('countdown', false)

	for i,player in pairs(server.getPlayers()) do
		local peer_id=player.id
		local object_id, is_success=server.getPlayerCharacterID(peer_id)
		if is_success then
			server.reviveCharacter(object_id)
			server.setCharacterData(object_id, 100, false, false)
		end
	end

	setSettingsToStandby()
end

function setSettingsToBattle()
	local tps_enable=g_savedata.tps_enable
	server.setGameSetting('third_person', tps_enable)
	server.setGameSetting('third_person_vehicle', tps_enable)
	server.setGameSetting('vehicle_damage', true)
	server.setGameSetting('player_damage', true)
	server.setGameSetting('map_show_players', false)
	server.setGameSetting('map_show_vehicles', false)
end

function setSettingsToStandby()
	server.setGameSetting('third_person', true)
	server.setGameSetting('third_person_vehicle', true)
	server.setGameSetting('vehicle_damage', false)
	server.setGameSetting('player_damage', false)
	server.setGameSetting('map_show_players', true)
	server.setGameSetting('map_show_vehicles', true)
end

-- UI

function registerPopup(name, x, y)
	table.insert(g_popups, {
		name=name,
		x=x,
		y=y,
		ui_id=server.getMapID(),
		is_show=false,
		text='',
		is_dirty=true,
	})
end
function findPopup(name)
	for i,popup in ipairs(g_popups) do
		if popup.name==name then
			return popup
		end
	end
end
function setPopup(name, is_show, text)
	local popup=findPopup(name)
	if not popup then return end
	if popup.is_show~=is_show then
		popup.is_show=is_show
		popup.is_dirty=true
	end
	if popup.text~=text then
		popup.text=text
		popup.is_dirty=true
	end
end
function updatePopups()
	for i,popup in ipairs(g_popups) do
		if popup.is_dirty then
			popup.is_dirty=false
			server.setPopupScreen(-1, popup.ui_id, popup.name, popup.is_show, popup.text, popup.x, popup.y)
		end
	end
end
function renewPopupIds()
	for i,popup in ipairs(g_popups) do
		server.removeMapID(-1, popup.ui_id)
		popup.ui_id=server.getMapID()
		popup.is_dirty=true
	end

	for peer_id,supply in pairs(g_savedata.supply_vehicles) do
		local vehicle_matrix, is_success = server.getVehiclePos(supply.vehicle_id)
		if is_success then
			server.removeMapID(-1, supply.ui_id)
			supply.ui_id=server.getMapID()
			local x,y,z = matrix.position(vehicle_matrix)
			server.addMapLabel(-1, supply.ui_id, 1, 'supply', x, z)
		end
	end

	for name,flag in pairs(g_savedata.flag_vehicles) do
		local vehicle_matrix, is_success = server.getVehiclePos(flag.vehicle_id)
		if is_success then
			server.removeMapID(-1, flag.ui_id)
			flag.ui_id=server.getMapID()
			local x,y,z = matrix.position(vehicle_matrix)
			local r,g,b,a=getColor(name)
			server.addMapObject(-1, flag.ui_id, 1, 9, x, z, 0, 0, flag.vehicle_id, 0, name, 30, name, r, g, b, a)
		end
	end
end
function clearPopups()
	for i,popup in ipairs(g_popups) do
		server.removeMapID(-1, popup.ui_id)
	end
	g_popups={}
end

-- Support vehicle

function spawnSupply(peer_id)
	despawnSupply(peer_id)
	local vehicle_matrix=getAheadMatrix(peer_id, 1, 8)
	local vehicle_id=spawnAddonVehicle('supply', vehicle_matrix)
	if vehicle_id then
		local ui_id=server.getMapID()
		local x,y,z=matrix.position(vehicle_matrix)
		server.addMapLabel(-1, ui_id, 1, 'supply', x, z)
		g_savedata.supply_vehicles[peer_id]={
			vehicle_id=vehicle_id,
			ui_id=ui_id,
		}
	end
end

function despawnSupply(peer_id)
	local supply=g_savedata.supply_vehicles[peer_id]
	if supply then
		server.despawnVehicle(supply.vehicle_id, true)
		server.removeMapID(-1, supply.ui_id)
		g_savedata.supply_vehicles[peer_id]=nil
	end
end

function clearSupplies()
	for peer_id,supply in pairs(g_savedata.supply_vehicles) do
		if type(supply)=='table' then
			server.despawnVehicle(supply.vehicle_id, true)
			server.removeMapID(-1, supply.ui_id)
		else
			-- for backward compertibility
			server.despawnVehicle(supply, true)
		end
	end
	g_savedata.supply_vehicles={}
end

function isSupply(vehicle_id)
	for peer_id,supply in pairs(g_savedata.supply_vehicles) do
		if supply.vehicle_id==vehicle_id then
			return true
		end
	end
	return false
end

function spawnFlag(peer_id, name)
	despawnFlag(peer_id, name)
	local vehicle_matrix=getAheadMatrix(peer_id, 9, 8)
	local vehicle_id=spawnAddonVehicle('flag', vehicle_matrix)

	if vehicle_id then
		server.setVehicleTooltip(vehicle_id, name)
		local ui_id=server.getMapID()
		local x,y,z=matrix.position(vehicle_matrix)
		local r,g,b,a=getColor(name)
		server.addMapObject(-1, ui_id, 1, 9, x, z, 0, 0, vehicle_id, 0, name, 30, name, r, g, b, a)
		g_savedata.flag_vehicles[name]={
			vehicle_id=vehicle_id,
			ui_id=ui_id,
		}
	end
end

function despawnFlag(peer_id, name)
	local flag=g_savedata.flag_vehicles[name]
	if flag then
		server.despawnVehicle(flag.vehicle_id, true)
		server.removeMapID(-1, flag.ui_id)
		g_savedata.flag_vehicles[name]=nil
	end
end

function clearFlags()
	for name,flag in pairs(g_savedata.flag_vehicles) do
		server.despawnVehicle(flag.vehicle_id, true)
		server.removeMapID(-1, flag.ui_id)
	end
	g_savedata.flag_vehicles={}
end

-- Utility Functions --

function announce(text, peer_id)
	server.announce('[Matchmaker]', text, peer_id)
end

function notify(title, text, type, peer_id)
	server.notify(-1, title, text, type)
	announce(title..'\n'..text, peer_id)
end

function getTableCount(table)
	local count=0
	for idx,p in pairs(table) do
		count=count+1
	end
	return count
end

function clamp(x,a,b)
	return x<a and a or x>b and b or x
end

function convert(value, type)
	local converter=g_converters[type]
	if converter then
		return converter(value)
	end
	return value
end

g_converters={
	integer=function(v)
		v=tonumber(v)
		return v and v//1|0
	end,
	number=function(v)
		return tonumber(v)
	end,
	boolean=function(v)
		if v=='true' then return true end
		if v=='false' then return false end
	end,
}

function getAheadMatrix(peer_id, y, z)
	local look_x, look_y, look_z=server.getPlayerLookDirection(peer_id)
	local position=server.getPlayerPos(peer_id)
	local offset=matrix.translation(0, y, -z)
	local rotation=matrix.rotationToFaceXZ(-look_x, -look_z)
	return matrix.multiply(position, matrix.multiply(rotation, offset))
end

function spawnAddonVehicle(name, transform_matrix)
	local addon_index, is_success = server.getAddonIndex()
	if not is_success then return end

	local search_tag='name='..name
	local addon_data=server.getAddonData(addon_index)
	for location_index=0,addon_data.location_count-1 do
		local location_data=server.getLocationData(addon_index, location_index)
		for component_index=0,location_data.component_count-1 do
			local component_data= server.getLocationComponentData(addon_index, location_index, component_index)
			if component_data.type=='vehicle' then
				for _,tag_pair in pairs(component_data.tags) do
					if tag_pair==search_tag then
						return server.spawnAddonVehicle(transform_matrix, addon_index, component_data.id)
					end
				end
			end
		end
	end
end

function findEmptySlot(object_id, slot)
	local equipment_id=server.getCharacterItem(object_id, slot)
	if equipment_id==0 then
		return slot
	end
	if slot>=2 and slot<5 then
		return findEmptySlot(object_id, slot+1)
	end
end

function getColor(name)
	local color=g_colors[name]
	if color then
		return table.unpack(color)
	end
	return 255,127,39,255
end

g_colors={
	red		={255,0  ,0,  255},
	green	={0,  255,0,  255},
	blue	={0,  0,  255,255},
	yellow	={255,255,0,  255},
	ylw		={255,255,0,  255},
	pink	={255,0,  255,255},
	white	={255,255,255,255},
	black	={0,  0,  0,  255},
}
