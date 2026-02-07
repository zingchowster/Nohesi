local ESX = nil
local QBCore = nil
local FrameworkType = (Config.Framework or 'none'):lower()  -- 'qbox' | 'qb-core' | 'esx' | 'none'

print(('[nohesi] Framework mode: %s'):format(FrameworkType))

-- ========= Framework init =========
CreateThread(function()
    if FrameworkType == 'esx' then
        local ok, obj = pcall(function()
            return exports['es_extended']:getSharedObject()
        end)

        if ok and obj then
            ESX = obj
        else
            TriggerEvent('esx:getSharedObject', function(o) ESX = o end)
            while not ESX do
                Wait(100)
            end
        end

        print('[nohesi] ESX initialized')

    elseif FrameworkType == 'qb-core' then
        local ok, core = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)

        if ok and core then
            QBCore = core
            print('[nohesi] QB-Core initialized')
        else
            print('[nohesi] ERROR: Could not get QBCore object')
            FrameworkType = 'none'
        end

    elseif FrameworkType == 'qbox' then
        -- Qbox: we don't need qb-core here, we use qbx_core directly
        print('[nohesi] Qbox mode (using qbx_core:AddMoney)')

    else
        print('[nohesi] Running in standalone (no framework money will be given)')
    end
end)

-- ========= Helpers =========

local function GetIdentifier(src)
    -- Use license: as persistent key
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then
            return id
        end
    end
    return GetPlayerIdentifier(src, 1) or ('unknown:' .. tostring(src))
end

local function GetBestFromDB(identifier, cb)
    print(('[nohesi] Fetching PB for %s'):format(identifier))

    exports.oxmysql:scalar(
        'SELECT best_points FROM nohesi_best WHERE identifier = ?',
        { identifier },
        function(best)
            best = best or 0
            print(('[nohesi] Current PB in DB: %s'):format(best))
            cb(best)
        end
    )
end

local function UpdateBestInDB(identifier, points)
    print(('[nohesi] Updating PB in DB to %s for %s'):format(points, identifier))

    exports.oxmysql:execute(
        [[
        INSERT INTO nohesi_best (identifier, best_points)
        VALUES (?, ?)
        ON DUPLICATE KEY UPDATE best_points = GREATEST(best_points, VALUES(best_points))
        ]],
        { identifier, points },
        function(affected)
            print(('[nohesi] DB update result, affected rows: %s'):format(affected or 'nil'))
        end
    )
end

local function GiveMoney(src, points, best)
    local moneyPerPoint = Config.MoneyPerPoint or 0
    if moneyPerPoint <= 0 then
        print('[nohesi] MoneyPerPoint <= 0, no reward will be given')
        return
    end

    local reward = math.floor(points * moneyPerPoint)
    if reward <= 0 then
        print(('[nohesi] Reward calculated is 0 (points=%s, MoneyPerPoint=%s)'):format(points, moneyPerPoint))
        return
    end

    local account = Config.Account or 'cash'

    print(('[nohesi] Giving reward $%s to src %s (framework=%s, account=%s)'):format(
        reward, src, FrameworkType, account
    ))

    if FrameworkType == 'qbox' then
        -- Qbox money: exports['qbx_core']:AddMoney(source, account, amount, reason)
        local ok, success = pcall(function()
            return exports['qbx_core']:AddMoney(src, account, reward, 'nohesi-reward')
        end)
        print(('[nohesi] Qbox AddMoney ok=%s, success=%s'):format(ok, tostring(success)))

    elseif FrameworkType == 'qb-core' and QBCore then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            Player.Functions.AddMoney(account, reward, 'nohesi-reward')
            print('[nohesi] QB-Core AddMoney done')
        else
            print('[nohesi] QB-Core: Player not found for src ' .. src)
        end

    elseif FrameworkType == 'esx' and ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            if account == 'bank' then
                xPlayer.addAccountMoney('bank', reward)
            else
                xPlayer.addMoney(reward)
            end
            print('[nohesi] ESX money given')
        else
            print('[nohesi] ESX: Player not found for src ' .. src)
        end

    else
        print(('[nohesi] No framework active – would give $%s to %s'):format(reward, src))
    end

    if Config.ShowRewardNotification and reward > 0 then
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 255, 0},
            args = {
                'Nohesi',
                ('You earned $%s (PB: %s pts)'):format(reward, best or points)
            }
        })
    end
end

-- ========= Events =========

-- PB request from client (optional, not used in HUD right now)
RegisterNetEvent('nohesi:getHighest', function()
    local src = source
    local identifier = GetIdentifier(src)

    print(('[nohesi] nohesi:getHighest from %s (%s)'):format(src, identifier))

    GetBestFromDB(identifier, function(best)
        TriggerClientEvent('nohesi:sendHighest', src, best)
    end)
end)

-- Save + reward on crash / full stop
RegisterNetEvent('nohesi:saveAndReward', function(points)
    local src = source
    points = tonumber(points) or 0

    print(('[nohesi] nohesi:saveAndReward from %s (points=%s)'):format(src, points))

    if points <= 0 then
        print('[nohesi] Points <= 0, skipping save/reward')
        return
    end

    local identifier = GetIdentifier(src)

    GetBestFromDB(identifier, function(currentBest)
        local newBest = currentBest

        if points > currentBest then
            newBest = points
            UpdateBestInDB(identifier, points)
        end

        GiveMoney(src, points, newBest)
    end)
end)
