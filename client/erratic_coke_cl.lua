ESX = nil

Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
    end

ESX.PlayerData = ESX.GetPlayerData()
end)

local inUse = false
local process 
local coord 
local location = nil
local enroute
local fueling
local dodo
local delivering
local hangar
local jerrycan
local checkPlane
local flying
local landing
local hasLanded
local pilot
local airplane
local planehash
local driveHangar
local blip
local isProcessing = false
local player

Citizen.CreateThread(function()
	while ESX == nil do TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end) Wait(0) end
    ESX.TriggerServerCallback('coke:processcoords', function(servercoords)
        process = servercoords
	end)
end)

Citizen.CreateThread(function()
	while ESX == nil do TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end) Wait(0) end
    ESX.TriggerServerCallback('coke:startcoords', function(servercoords)
        coord = servercoords
	end)
end)

Citizen.CreateThread(function()
	local sleep
	while not coord do
		Citizen.Wait(0)
	end
	while true do
		sleep = 5
		local player = GetPlayerPed(-1)
		local playercoords = GetEntityCoords(player)
		local dist = #(vector3(playercoords.x, playercoords.y, playercoords.z)-vector3(coord.x, coord.y, coord.z))
		if not inUse then
			if dist <= 1 then
				sleep = 5
				DrawText3Ds(coord.x, coord.y, coord.z, _U'press_start')			
				if IsControlJustPressed(1, 51) then
					ESX.TriggerServerCallback('coke:pay', function(success)
						if success then
							main()
						end
					end)
				end
			else
				sleep = 2000
			end
		elseif dist <= 3 and inUse then
			sleep = 5
			DrawText3Ds(coord.x, coord.y, coord.z, _U'unavailable')
		else
			sleep = 3000
		end
		Citizen.Wait(sleep)
	end
end)

RegisterNetEvent('coke:syncTable')
AddEventHandler('coke:syncTable', function(bool)
    inUse = bool
end)

RegisterNetEvent('coke:onUse')
AddEventHandler('coke:onUse', function(source)
	if Config.useMythic then
		exports['mythic_notify']:DoLongHudText('inform', _U'coke_use')
	end
	local crackhead = GetPlayerPed(-1)
	SetPedArmour(crackhead, 30)
	SetTimecycleModifier("DRUG_gas_huffin")
	Citizen.Wait(Config.cokeTime)
	DoScreenFadeOut(1000)
	Citizen.Wait(1000)
	DoScreenFadeIn(2000)
	if Config.useMythic then
		exports['mythic_notify']:DoLongHudText('inform', _U'coke_off')
	end
	SetPedArmour(crackhead, 0)
	ClearTimecycleModifier()
end)

function main()
	TriggerServerEvent('coke:updateTable', true)
	player = GetPlayerPed(-1)
	FreezeEntityPosition(player, true)
	SetEntityCoords(player, coord.x-0.1,coord.y-0.1,coord.z-1, 0.0,0.0,0.0, false)
	SetEntityHeading(player, Config.doorHeading)
	playAnim("timetable@jimmy@doorknock@", "knockdoor_idle", 3000)
	Citizen.Wait(3000)
	FreezeEntityPosition(player, false)
	if Config.useMythic then
		exports['mythic_notify']:DoLongHudText('inform', _U'go_airfield')
	end
	rand = math.random(1,#Config.locations)
	location = Config.locations[rand]
	blip = AddBlipForCoord(location.fuel.x,location.fuel.y,location.fuel.z)
	SetBlipRoute(blip, true)
	enroute = true
	Citizen.CreateThread(function()
		while enroute do
			sleep = 5	
			local player = GetPlayerPed(-1)
			playerpos = GetEntityCoords(player)
			local disttocoord = #(vector3(location.fuel.x,location.fuel.y,location.fuel.z)-vector3(playerpos.x,playerpos.y,playerpos.z))
			if disttocoord <= 100 and not Config.landPlane then
				planeGround()
				enroute = false
			elseif disttocoord <= 300 and Config.landPlane then
				planeFly()
				enroute = false
			else
				sleep = 1500
			end
			Citizen.Wait(sleep)
		end
	end)
end

function planeGround()
	local planehash = GetHashKey("dodo")
	RequestModel(planehash)
	while not HasModelLoaded(planehash) do
		Citizen.Wait(0)
	end
	airplane = CreateVehicle(planehash, location.stationary.x,location.stationary.y,location.stationary.z, location.stationary.h, true, true)
	FreezeEntityPosition(airplane, true)
	SetVehicleDoorsLocked(airplane, 2)
	if Config.useMythic then
        exports['mythic_notify']:DoLongHudText('inform', _U'no_fuel')
    end
	fuel(location.fuel.x,location.fuel.y,location.fuel.z)
end

function planeFly()
	local pilothash = GetHashKey(Config.pilotPed)
    RequestModel(pilothash)
    while not HasModelLoaded(pilothash) do
        Citizen.Wait(0)
    end
    local planehash = GetHashKey("dodo")
	RequestModel(planehash)
	while not HasModelLoaded(planehash) do
		Citizen.Wait(0)
	end
	if Config.useMythic then
		exports['mythic_notify']:DoLongHudText('inform', _U'wait_plane')
	end
	airplane = CreateVehicle(planehash, location.plane.x,location.plane.y,location.plane.z, location.plane.h, true, true)

    SetEntityDynamic(airplane, true)
    ActivatePhysics(airplane)
    SetVehicleForwardSpeed(airplane, 100.0)
    SetHeliBladesFullSpeed(airplane) 
    SetVehicleEngineOn(airplane, true, true, false)
    ControlLandingGear(airplane, 0) 
    SetEntityProofs(airplane, true, false, true, false, false, false, false, false)
    SetPlaneTurbulenceMultiplier(airplane, 0.0)

    pilot = CreatePedInsideVehicle(airplane, 1, pilothash, -1, true, true)
    SetBlockingOfNonTemporaryEvents(pilot, true) 
    SetPedRandomComponentVariation(pilot, false)
    SetPedKeepTask(pilot, true)
    SetTaskVehicleGotoPlaneMinHeightAboveTerrain(airplane, 93.0) 
    Citizen.CreateThread(function()
        flying = true
        local planecoords
        while flying do
            Citizen.Wait(100)
            planecoords = GetEntityCoords(airplane)
            local disttocoord = #(vector3(location.plane.x,location.plane.y,location.plane.z)-vector3(planecoords.x,planecoords.y,planecoords.z))
            if disttocoord < 100 then
                flying = false
                taskLand()       
                return
            else
                TaskVehicleDriveToCoord(pilot, airplane, location.plane.x,location.plane.y,location.plane.z, 100.0, 0, planehash, 262144, 15.0, -1.0)
                Citizen.Wait(1000)
            end
        end
    end)
end

function taskLand()
	landing = true 
	if landing then
		TaskPlaneLand(pilot, airplane, location.runwayEnd.x,location.runwayEnd.y,location.runwayEnd.z, location.runwayStart.x,location.runwayStart.y,location.runwayStart.z)
	end
	 Citizen.CreateThread(function()
        local planecoords
        while landing do
            sleep = 1000
            planecoords = GetEntityCoords(airplane)
            local disttocoord = #(vector3(location.runwayStart.x,location.runwayStart.y,location.runwayStart.z)-vector3(planecoords.x,planecoords.y,planecoords.z))
            if disttocoord <= 30 then
            	landing = false
            	landed()
            else
                sleep = 1500
            end
            Citizen.Wait(sleep)
        end
    end)
end

function landed()
	hasLanded = true
	local sleep
	RemoveBlip(blip)
	SetBlipRoute(blip, false)
	while hasLanded do
		sleep = 500
		planecoords = GetEntityCoords(airplane)
        local disttocoord = #(vector3(location.landingLoc.x, location.landingLoc.y, location.landingLoc.z)-vector3(planecoords.x,planecoords.y,planecoords.z))
        SetDriveTaskDrivingStyle(pilot, 2883621)
		TaskVehicleDriveToCoord(pilot, airplane, location.landingLoc.x, location.landingLoc.y, location.landingLoc.z, 10.0, 156, planehash, 786603, 1.0, true)
		if disttocoord <= 10 then
			hasLanded = false
			parkHangar()
		end
		Citizen.Wait(sleep)
	end
end

function parkHangar()
	driveHangar = true
	local player = GetPlayerPed(-1)
	local sleep
	while driveHangar do
		sleep = 500
		planecoords = GetEntityCoords(airplane)
        local disttocoord = #(vector3(location.parking.x, location.parking.y, location.parking.z)-vector3(planecoords.x,planecoords.y,planecoords.z))
        SetDriveTaskDrivingStyle(pilot, 2883621)
		TaskVehicleDriveToCoord(pilot, airplane, location.parking.x, location.parking.y, location.parking.z, 10.0, 156, planehash, 786603, 1.0, true)
        if disttocoord <= 2 then
        	FreezeEntityPosition(airplane, true) 	
        	Citizen.Wait(1000)
        	TaskLeaveVehicle(pilot, airplane, 0)
        	Citizen.Wait(2000)
        	if Config.useMythic then
        		exports['mythic_notify']:DoLongHudText('inform', _U'no_fuel')
        	end
        	TaskTurnPedToFaceEntity(pilot, player, 5000)
        	fuel(location.fuel.x,location.fuel.y,location.fuel.z)
        	playAnimPed("anim@mp_player_intincarsalutestd@ds@", "idle_a", 5000)
        	Citizen.Wait(5000)
        	SetEntityAsNoLongerNeeded(pilot)
        	driveHangar = false
        end
        Citizen.Wait(sleep)
	end
end

function fuel(x,y,z)
	local prop = GetHashKey("prop_ld_jerrycan_01")
	RequestModel(prop)
	while not HasModelLoaded(prop) do
		Citizen.Wait(0)
	end
	RemoveBlip(blip)
	SetBlipRoute(blip, false)
	jerrycan = GetHashKey("WEAPON_PETROLCAN")
	local fuelSpawn = CreateObject(prop, x,y,z-1, true, true, false)
	local player = GetPlayerPed(-1)
	local fuelCoords = GetEntityCoords(fuelSpawn)
	FreezeEntityPosition(fuelSpawn, true)
	fueling = true
	Citizen.CreateThread(function()
		while fueling do
			sleep = 5	
			local playerpos = GetEntityCoords(player)
			local disttocoord = #(vector3(fuelCoords.x,fuelCoords.y,fuelCoords.z)-vector3(playerpos.x,playerpos.y,playerpos.z))
			if disttocoord <= 3 then
				DrawText3Ds(fuelCoords.x,fuelCoords.y,fuelCoords.z, _U'pick_jerry')
				if IsControlJustPressed(1, 51) then
					TaskTurnPedToFaceEntity(player, fuelSpawn, 3000)
					FreezeEntityPosition(player, true)
					if Config.progBar then
						exports['progressBars']:startUI(1000, _U'picking_jerry')
					end
					DoScreenFadeOut(1000)
					Citizen.Wait(1000)
					DeleteEntity(fuelSpawn)
					Citizen.Wait(500)
					DoScreenFadeIn(2000)
					GiveWeaponToPed(player, jerrycan, 0, false, true)
					FreezeEntityPosition(player, false)
					if Config.useMythic then
						exports['mythic_notify']:DoLongHudText('inform', _U'fill_plane')
					end
					plane(fuel)
					fueling = false
					dodo = true
				end
			else
				sleep = 1500
			end
			Citizen.Wait(sleep)
		end
	end)
end

function plane(fuel)
	local player = GetPlayerPed(-1)
	Citizen.CreateThread(function()
		while dodo do
			sleep = 5	
			local playerpos = GetEntityCoords(player)
			local disttocoord = #(vector3(location.parking.x,location.parking.y,location.parking.z)-vector3(playerpos.x,playerpos.y,playerpos.z))
			if disttocoord <= 5 then
				DrawText3Ds(location.parking.x,location.parking.y,location.parking.z, _U'refuel')
				DrawMarker(27, location.parking.x,location.parking.y,location.parking.z-0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 0.2, 3, 252, 152, 100, false, true, 2, false, false, false, false)
				if IsControlJustPressed(1, 51) then
					dodo = false
					delivering = true
					SetCurrentPedWeapon(player, jerrycan, true)
					TaskTurnPedToFaceEntity(player, airplane, 20000)
					FreezeEntityPosition(player, true)
					playAnim("weapon@w_sp_jerrycan", "fire", 20000)
					if Config.progBar then
						exports['progressBars']:startUI(20000, _U'refueling')
					end
					Citizen.Wait(20000)
					if Config.useMythic then
						exports['mythic_notify']:DoLongHudText('success', _U'finish_refuel')
					end
					RemoveWeaponFromPed(player, jerrycan)
					FreezeEntityPosition(airplane, false)
					SetVehicleDoorsLocked(airplane, 0)
					FreezeEntityPosition(player, false)
					ClearPedTasksImmediately(player)
					delivery()
				end
			else
				sleep = 1500
			end
			Citizen.Wait(sleep)
		end
	end)
end

Citizen.CreateThread(function()
	checkPlane = true
	while checkPlane do
		sleep = 100 
		if DoesEntityExist(airplane) then
			if GetVehicleEngineHealth(airplane) < 0 then
				if Config.useMythic then
					exports['mythic_notify']:DoLongHudText('error', _U'fail')
				end
				TriggerServerEvent('coke:updateTable', false)
				RemoveBlip(blip)
				SetBlipRoute(blip, false)
				DeleteEntity(pickupSpawn)
				delivering = false
				checkPlane = false
				hangar = false
			end
		else
			sleep = 3000
		end
		Citizen.Wait(sleep)
	end
end)

function delivery()
	if Config.useMythic then
		exports['mythic_notify']:DoLongHudText('inform', _U'deliver')
	end
	local pickup = GetHashKey("prop_barrel_float_1")
	blip = AddBlipForCoord(location.delivery.x,location.delivery.y,location.delivery.z)
	SetBlipRoute(blip, true)
	RequestModel(pickup)
	while not HasModelLoaded(pickup) do
		Citizen.Wait(0)
	end
	local pickupSpawn = CreateObject(pickup, location.delivery.x,location.delivery.y,location.delivery.z, true, true, true)
	local player = GetPlayerPed(-1)
	Citizen.CreateThread(function()
		while delivering do
			sleep = 5	
			local playerpos = GetEntityCoords(player)
			local disttocoord = #(vector3(location.delivery.x,location.delivery.y,location.delivery.z)-vector3(playerpos.x,playerpos.y,playerpos.z))
			
			if disttocoord <= 20 then
				RemoveBlip(blip)
				SetBlipRoute(blip, false)

				if IsPedInAnyPlane(GetPlayerPed(-1)) then
					DrawText3Ds(location.delivery.x,location.delivery.y,location.delivery.z-1, _U'pick_deliv')
					if IsControlJustPressed(1, 51) then
						delivering = false
						if Config.progBar then
							exports['progressBars']:startUI(Config.pickupTime, _U'picking_deliv')
						end
						Citizen.Wait(Config.pickupTime)
						if Config.useMythic then
							exports['mythic_notify']:DoLongHudText('success', _U'picked_deliv')
						end
						DeleteEntity(pickupSpawn)
						Citizen.Wait(2000)
						final()
					end
				else
					delivering = false
					if Config.useMythic then
						exports['mythic_notify']:DoLongHudText('error', 'Where you gonna put this, you need a plane')
					end
					TriggerServerEvent('coke:updateTable', false)
				end
			else
				sleep = 1500
			end
			Citizen.Wait(sleep)
		end
	end)
end

function final()
	if Config.useMythic then
		exports['mythic_notify']:DoLongHudText('inform', _U'deliv_plane')
	end
	blip = AddBlipForCoord(location.hangar.x,location.hangar.y,location.hangar.z)
	SetBlipRoute(blip, true)
	hangar = true
	local player = GetPlayerPed(-1)
	Citizen.CreateThread(function()
		while hangar do
			sleep = 5	
			local playerpos = GetEntityCoords(player)
			local disttocoord = #(vector3(location.hangar.x,location.hangar.y,location.hangar.z)-vector3(playerpos.x,playerpos.y,playerpos.z))
			if disttocoord <= 5 then
				RemoveBlip(blip)
				SetBlipRoute(blip, false)
				DrawText3Ds(location.hangar.x,location.hangar.y,location.hangar.z-1, _U'park_plane')
				DrawMarker(27, location.hangar.x,location.hangar.y,location.hangar.z-0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 2.0, 3, 252, 152, 100, false, true, 2, false, false, false, false)
				if IsControlJustPressed(1, 51) then
					hangar = false
					FreezeEntityPosition(airplane, true)
					if Config.progBar then
						exports['progressBars']:startUI(2000, _U'leaving_key')
					end
					Citizen.Wait(2000)
					TriggerServerEvent('coke:GiveItem')
					TaskLeaveVehicle(player, airplane, 0)
					SetVehicleDoorsLocked(airplane, 2)
					Citizen.Wait(30000)
					DeleteEntity(airplane)	
					if Config.useCD then		
						cooldown()
					else
						TriggerServerEvent('coke:updateTable', false)
					end
				end
			else
				sleep = 1500
			end
			Citizen.Wait(sleep)
		end
	end)
end

Citizen.CreateThread(function()
	local sleep
	while not process do
		Citizen.Wait(0)
	end
	while true do
		sleep = 5
		local player = GetPlayerPed(-1)
		local playercoords = GetEntityCoords(player)
		local dist = #(vector3(playercoords.x,playercoords.y,playercoords.z)-vector3(process.x,process.y,process.z))
		if dist <= 3 and not isProcessing then
			sleep = 5
			DrawText3Ds(process.x, process.y, process.z, _U'break_coke')			
			if IsControlJustPressed(1, 51) then		
				isProcessing = true
				ESX.TriggerServerCallback('coke:process', function(success)
					if success then					
						processing()
					else
						isProcessing = false
					end
				end)
			end
		else
			sleep = 1500
		end
		Citizen.Wait(sleep)
	end
end)

function processing()
	local player = GetPlayerPed(-1)
	SetEntityCoords(player, process.x,process.y,process.z-1, 0.0, 0.0, 0.0, false)
	SetEntityHeading(player, 232.84)
	FreezeEntityPosition(player, true)
	if Config.progBar then
		exports['progressBars']:startUI(6000, _U'breaking_coke')
	end
	playAnim("anim@amb@clubhouse@tutorial@bkr_tut_ig3@", "machinic_loop_mechandplayer", 6000)
	Citizen.Wait(6000)
	FreezeEntityPosition(player, false)
	TriggerServerEvent('coke:processed')
	isProcessing = false
end

function cooldown()
	Citizen.Wait(Config.cdTime)
	TriggerServerEvent('coke:updateTable', false)
end

function playAnimPed(animDict, animName, duration, buyer, x,y,z)
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do 
      Citizen.Wait(0) 
    end
    TaskPlayAnim(pilot, animDict, animName, 1.0, -1.0, duration, 49, 1, false, false, false)
    RemoveAnimDict(animDict)
end

function playAnim(animDict, animName, duration)
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do 
      Citizen.Wait(0) 
    end
    TaskPlayAnim(GetPlayerPed(-1), animDict, animName, 1.0, -1.0, duration, 49, 1, false, false, false)
    RemoveAnimDict(animDict)
end

function DrawText3Ds(x,y,z, text)
    local onScreen,_x,_y=World3dToScreen2d(x,y,z)
    local px,py,pz=table.unpack(GetGameplayCamCoords())
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x,_y)
    local factor = (string.len(text)) / 370
    DrawRect(_x,_y+0.0125, 0.015+ factor, 0.03, 41, 11, 41, 68)
end

-- (Optional) Shows your coords, useful if you want to add new locations.

if Config.getCoords then
	RegisterCommand("mycoords", function()
		local player = GetPlayerPed(-1)
	    local x,y,z = table.unpack(GetEntityCoords(player))
	    print("X: "..x.." Y: "..y.." Z: "..z)
	end)
end