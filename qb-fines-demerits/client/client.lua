local QBCore = exports['qb-core']:GetCoreObject()

-- ========================
-- Notify wrapper (okok/QB)
-- ========================
local function Notify(msg, nType, length)
    local title = Config.OkOkTitle or "Notice"
    local t = nType or 'info'
    local l = length or 5000
    if Config.UseOkOkNotify then
        local ok = pcall(function()
            exports['okokNotify']:Alert(title, tostring(msg), l, t)
        end)
        if not ok then
            QBCore.Functions.Notify(tostring(msg), t, l)
        end
    else
        QBCore.Functions.Notify(tostring(msg), t, l)
    end
end

-- ===========================
-- FORCE HIDE ON LOAD/JOIN
-- ===========================
CreateThread(function()
    Wait(500)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "forceHide" })
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "forceHide" })
end)

-- ===========================
-- Fines Officer NPC + Blip
-- ===========================
CreateThread(function()
    for _, data in ipairs(Config.FinesOfficerPeds or {}) do
        local model = data.model
        if type(model) == 'string' then model = joaat(model) end
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(0) end

        local ped = CreatePed(4, model, data.coords.x, data.coords.y, data.coords.z - 1.0, data.heading or 0.0, false, true)
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetEntityInvincible(ped, true)
        FreezeEntityPosition(ped, true)

        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    icon = "fas fa-file-invoice-dollar",
                    label = "View & Pay Fines",
                    action = function() OpenFinesMenu() end
                }
            },
            distance = 2.0
        })

        -- Add blip if enabled
        if Config.FinesOfficerBlip and Config.FinesOfficerBlip.enabled then
            local blip = AddBlipForCoord(data.coords.x, data.coords.y, data.coords.z)
            SetBlipSprite(blip, Config.FinesOfficerBlip.sprite or 525)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, Config.FinesOfficerBlip.scale or 0.8)
            SetBlipColour(blip, Config.FinesOfficerBlip.color or 3)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Config.FinesOfficerBlip.label or "Fines Office")
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- Optional: /tickets shortcut
if Config.EnableTicketsCommand then
    RegisterCommand('tickets', function()
        OpenFinesMenu()
    end)
end

-- =======================
-- Engine block (optional)
-- =======================
local lastNotify = 0
CreateThread(function()
    if not Config.EnableEngineBlock then return end
    while true do
        Wait(500)
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh and GetPedInVehicleSeat(veh, -1) == ped then
                local pdata = QBCore.Functions.GetPlayerData()
                local meta = pdata and pdata.metadata or {}
                if meta and meta.license_suspended then
                    SetVehicleEngineOn(veh, false, true, true)
                    if GetGameTimer() - lastNotify > (Config.EngineBlockNotifyInterval or 60000) then
                        Notify(Config.Locales.drivingSuspended or "Your licence is suspended — you cannot drive.", 'error')
                        lastNotify = GetGameTimer()
                    end
                end
            end
        end
    end
end)

-- ===========================
-- NPC menu: view & pay fines
-- ===========================
function OpenFinesMenu()
    QBCore.Functions.TriggerCallback('qb-fines:server:getUnpaidFines', function(fines, total)
        local menu = {
            { header = "Your Unpaid Fines", txt = ("Total Due: $%s"):format(total or 0), isMenuHeader = true }
        }
        if (not fines) or #fines == 0 then
            menu[#menu+1] = { header = "No unpaid fines", txt = Config.Locales.nothingToPay or "You have no unpaid fines.", disabled = true }
        else
            for _, f in ipairs(fines) do
                local hdr = ("#%d • %s"):format(f.id, f.offence_label)
                local txt = ("$%d • %s pts • %s"):format(f.amount or 0, f.demerit_points or 0, f.created_at or "")
                menu[#menu+1] = {
                    header = hdr,
                    txt = txt,
                    params = { event = "qb-fines:client:payFineChoice", args = { id = f.id, amount = f.amount } }
                }
            end
        end
        exports['qb-menu']:openMenu(menu)
    end)
end

RegisterNetEvent("qb-fines:client:payFineChoice", function(data)
    local id = data.id
    local amount = data.amount or 0
    local menu = {
        { header = ("Pay Ticket #%s"):format(id), txt = ("Amount: $%s"):format(amount), isMenuHeader = true },
        { header = "Pay from Bank", params = { event = "qb-fines:client:payFine", args = { id = id, method = 'bank' } } },
        { header = "Pay in Cash",  params = { event = "qb-fines:client:payFine", args = { id = id, method = 'cash' } } },
        { header = "< Back", params = { event = "tickets" } }
    }
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent("qb-fines:client:payFine", function(data)
    TriggerServerEvent('qb-fines:server:payFine', data.id, data.method or 'bank')
end)

-- =========================
-- Tablet UI for /fines (NUI)
-- =========================
local function GetNearbyPlayers(maxDist)
    local list = {}
    local me = PlayerPedId()
    local myCoords = GetEntityCoords(me)
    for _, pid in ipairs(GetActivePlayers()) do
        local sid = GetPlayerServerId(pid)
        if sid ~= GetPlayerServerId(PlayerId()) then
            local ped = GetPlayerPed(pid)
            local dist = #(myCoords - GetEntityCoords(ped))
            if dist <= (maxDist or Config.NearbyPlayerDistance or 5.0) then
                list[#list+1] = { id = sid, name = (GetPlayerName(pid) or ("ID "..sid)), dist = math.floor(dist) }
            end
        end
    end
    table.sort(list, function(a,b) return a.dist < b.dist end)
    return list
end

local function OpenFinesTablet()
    local pdata = QBCore.Functions.GetPlayerData()
    if not pdata or not pdata.job or pdata.job.name ~= 'police' then
        Notify(Config.Locales.notPolice or "You must be a police officer to use this.", 'error'); return
    end

    local payload = {
        action = "openTablet",
        data = {
            categories = Config.OffenceCategories,
            players = GetNearbyPlayers(),
            defaults = { payment = Config.DefaultPaymentMethod or 'unpaid' }
        }
    }
    SetNuiFocus(true, true)
    SendNUIMessage(payload)
end

RegisterCommand('fines', function()
    OpenFinesTablet()
end)

-- NUI → close tablet
RegisterNUICallback('closeTablet', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "forceHide" })
    cb({ ok = true })
end)

-- NUI → issue fine
RegisterNUICallback('issueFine', function(data, cb)
    if type(data) ~= 'table' or not data.target or not data.offence then
        cb({ ok = false, error = "Bad payload" }); return
    end
    TriggerServerEvent("qb-fines:server:issueFine", {
        target = tonumber(data.target),
        offence = {
            code = data.offence.code or "UNKNOWN",
            label = data.offence.label or "",
            amount = tonumber(data.offence.amount) or 0,
            points = tonumber(data.offence.points) or 0
        },
        method  = data.method or (Config.DefaultPaymentMethod or 'unpaid'),
        note    = tostring(data.note or ""):sub(1, 120)
    })
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "forceHide" })
    cb({ ok = true })
end)

-- Unified notify endpoint (server -> client)
RegisterNetEvent('qb-fines:client:_notify', function(msg, nType, length)
    Notify(msg, nType, length)
end)
