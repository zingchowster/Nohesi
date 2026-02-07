-- Full Nohesi HUD + Points for FiveM (GTA font UI removed)
-- Works with Config.lua and server.lua
-- Handles:
--  - Near-miss points
--  - Timer that starts on first point
--  - Crash / full stop -> save & reward
--  - Personal best (PB) synced with DB and shown in HUD
--  - Configurable crash timeout before you can earn points again

local hudVisible = false
local hudData = {
    points = 0,
    time = (Config and Config.TimerSeconds) or 1449,
    speedMultiplier = 1.0,
    proximityMultiplier = 1.0,
    comboMultiplier = 1.0,
    totalMultiplier = 1.0,
    personalBest = 0
}

local points = 0
local highestPoints = 0        -- from DB
local lastUpdate = 0
local crashCooldown = 0        -- short cooldown so crash event doesn't spam
local stopCooldown = 0
local crashTimeoutEnd = 0      -- long timeout after crash (from config)

local personalBest = 0         -- this player PB (session + DB)
local timerActive = false      -- only runs after first point

-------------------------------------------------------
-- Ask server for PB on spawn
-------------------------------------------------------
CreateThread(function()
    TriggerServerEvent('nohesi:getHighest')
end)

RegisterNetEvent('nohesi:sendHighest', function(best)
    highestPoints = best or 0
    personalBest = highestPoints
    hudData.personalBest = personalBest

    SendNUIMessage({
        action = 'update',
        personalBest = hudData.personalBest
    })
end)

-------------------------------------------------------
-- HUD helpers
-------------------------------------------------------
local function ShowNohesiHUD()
    if not hudVisible then
        hudVisible = true

        hudData.time = (Config and Config.TimerSeconds) or 1449
        timerActive = false
        hudData.personalBest = personalBest

        SendNUIMessage({
            action = 'show',
            startTimer = false
        })

        SendNUIMessage({
            action = 'update',
            points = hudData.points,
            time = hudData.time,
            speedMultiplier = hudData.speedMultiplier,
            proximityMultiplier = hudData.proximityMultiplier,
            comboMultiplier = hudData.comboMultiplier,
            totalMultiplier = hudData.totalMultiplier,
            personalBest = hudData.personalBest
        })

        SetNuiFocus(false, false)
    end
end

local function HideNohesiHUD()
    if hudVisible then
        hudVisible = false
        SendNUIMessage({ action = 'hide' })
    end
end

local function ResetNohesiHUD()
    points = 0
    timerActive = false
    crashTimeoutEnd = 0 -- clear any crash timeout on hard reset

    hudData.points = 0
    hudData.time = (Config and Config.TimerSeconds) or 1449
    hudData.speedMultiplier = 1.0
    hudData.proximityMultiplier = 1.0
    hudData.comboMultiplier = 1.0
    hudData.totalMultiplier = 1.0
    hudData.personalBest = personalBest

    SendNUIMessage({ action = 'reset' })

    SendNUIMessage({
        action = 'update',
        points = hudData.points,
        time = hudData.time,
        speedMultiplier = hudData.speedMultiplier,
        proximityMultiplier = hudData.proximityMultiplier,
        comboMultiplier = hudData.comboMultiplier,
        totalMultiplier = hudData.totalMultiplier,
        personalBest = hudData.personalBest
    })
end

-------------------------------------------------------
-- Show / hide HUD when entering / exiting vehicle
-------------------------------------------------------
CreateThread(function()
    while true do
        Wait(500)

        local ped = PlayerPedId()
        local inVehicle = IsPedInAnyVehicle(ped, false)

        if inVehicle and not hudVisible then
            ShowNohesiHUD()
        elseif not inVehicle and hudVisible then
            HideNohesiHUD()
            timerActive = false
        end
    end
end)

-------------------------------------------------------
-- TIMER THREAD: counts down only after first point
-------------------------------------------------------
CreateThread(function()
    while true do
        Wait(1000)

        if hudVisible and timerActive then
            if hudData.time > 0 then
                hudData.time = hudData.time - 1

                SendNUIMessage({
                    action = 'update',
                    time = hudData.time
                })

                -- Timer finished -> reset run
                if hudData.time <= 0 then
                    points = 0
                    hudData.points = 0
                    hudData.speedMultiplier = 1.0
                    hudData.proximityMultiplier = 1.0
                    hudData.comboMultiplier = 1.0
                    hudData.totalMultiplier = 1.0
                    hudData.time = (Config and Config.TimerSeconds) or 1449
                    timerActive = false

                    SendNUIMessage({
                        action = 'update',
                        points = hudData.points,
                        time = hudData.time,
                        speedMultiplier = hudData.speedMultiplier,
                        proximityMultiplier = hudData.proximityMultiplier,
                        comboMultiplier = hudData.comboMultiplier,
                        totalMultiplier = hudData.totalMultiplier,
                        personalBest = personalBest
                    })
                end
            end
        end
    end
end)

-------------------------------------------------------
-- Main loop: crash, stop, near-miss logic
-------------------------------------------------------
CreateThread(function()
    while true do
        Wait(0)

        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped) then goto continue end

        local veh = GetVehiclePedIsIn(ped, false)
        local speed = GetEntitySpeed(veh) * 3.6 -- km/h
        local now = GetGameTimer()

        ---------------------------------------------------
        -- Crash detection -> save & reward, flash, reset
        ---------------------------------------------------
        if HasEntityCollidedWithAnything(veh) and now > crashCooldown then
            -- tell UI to flash red (handled in HTML)
            SendNUIMessage({ action = 'crashFlash' })

            -- send points to server
            TriggerServerEvent('nohesi:saveAndReward', points)

            -- reset HUD/points
            ResetNohesiHUD()

            -- short internal cooldown so 1 crash doesn't spam multiple times
            crashCooldown = now + 1000

            -- long crash timeout from config (blocks new points)
            local timeoutSec = (Config and Config.CrashTimeoutSeconds) or 0
            if timeoutSec > 0 then
                crashTimeoutEnd = now + (timeoutSec * 1000)
            else
                crashTimeoutEnd = 0
            end
        end

        ---------------------------------------------------
        -- Full stop reset (also saves & rewards)
        -- NOTE: full stop does NOT start crash timeout; only real crash does
        ---------------------------------------------------
        if speed < 1.0 and now > stopCooldown then
            TriggerServerEvent('nohesi:saveAndReward', points)
            ResetNohesiHUD()
            stopCooldown = now + 1500
        end

        ---------------------------------------------------
        -- Near-miss scoring (blocked during crash timeout)
        ---------------------------------------------------
        if now - lastUpdate > 200 then
            lastUpdate = now

            local minSpeed = (Config and Config.MinSpeed) or 40
            local maxDist  = (Config and Config.MaxNearMissDistance) or 7.0

            -- If we're still in crash timeout, skip awarding points
            if crashTimeoutEnd > 0 and now < crashTimeoutEnd then
                goto continue
            elseif crashTimeoutEnd > 0 and now >= crashTimeoutEnd then
                -- timeout finished; clear it
                crashTimeoutEnd = 0
            end

            if speed > minSpeed then
                local coords = GetEntityCoords(veh)

                for _, v in ipairs(GetGamePool('CVehicle')) do
                    if v ~= veh then
                        local dist = #(GetEntityCoords(v) - coords)

                        if dist < maxDist then
                            local reward = math.floor((maxDist - dist) * (speed / 20))
                            if reward > 0 then
                                -- first time earning points this run -> start timer
                                if not timerActive and points == 0 then
                                    timerActive = true
                                end

                                points = points + reward

                                -- update PB (local + HUD)
                                if points > personalBest then
                                    personalBest = points
                                end

                                -- Calculate multipliers
                                local speedMult = math.min(speed / minSpeed, 10.0)
                                local proximityMult = math.max(maxDist - dist, 0.0)
                                local comboMult = hudData.comboMultiplier + 0.1
                                local totalMult = (speedMult + proximityMult + comboMult) / 3

                                hudData.points = points
                                hudData.speedMultiplier = speedMult
                                hudData.proximityMultiplier = proximityMult
                                hudData.comboMultiplier = comboMult
                                hudData.totalMultiplier = totalMult
                                hudData.personalBest = personalBest

                                SendNUIMessage({
                                    action = 'update',
                                    points = hudData.points,
                                    speedMultiplier = hudData.speedMultiplier,
                                    proximityMultiplier = hudData.proximityMultiplier,
                                    comboMultiplier = hudData.comboMultiplier,
                                    totalMultiplier = hudData.totalMultiplier,
                                    personalBest = hudData.personalBest
                                })
                            end
                        end
                    end
                end
            end
        end

        ::continue::
    end
end)

-------------------------------------------------------
-- Optional debug commands
-------------------------------------------------------
RegisterCommand('nohesi_show', function()
    ShowNohesiHUD()
end, false)

RegisterCommand('nohesi_hide', function()
    HideNohesiHUD()
end, false)

RegisterCommand('nohesi_reset', function()
    ResetNohesiHUD()
end, false)
