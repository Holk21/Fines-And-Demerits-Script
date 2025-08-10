local QBCore = exports['qb-core']:GetCoreObject()

-- ==========================
-- Notify → forward to client
-- ==========================
local function SNotify(src, msg, nType, length)
    TriggerClientEvent('qb-fines:client:_notify', src, tostring(msg), nType or 'info', length or 5000)
end

local function isPolice(src)
    local xPlayer = QBCore.Functions.GetPlayer(src)
    return xPlayer and xPlayer.PlayerData.job and xPlayer.PlayerData.job.name == "police"
end

-- =====================================================
-- Recalc rolling demerits & manage licence suspension
-- =====================================================
local function RecalcDemeritsForCitizen(citizenid, srcForNotify)
    if not citizenid then return 0 end
    local months = tonumber(Config.DemeritWindowMonths or 24)

    -- Build SQL (can't bind INTERVAL ? MONTH)
    local sql = ('SELECT COALESCE(SUM(points),0) AS total FROM player_demerits WHERE citizenid = ? AND created_at >= (NOW() - INTERVAL %d MONTH)'):format(months)

    local rows
    local ok, err = pcall(function()
        rows = MySQL.query.await(sql, { citizenid })
    end)

    -- Fallback to all-time sum if created_at missing
    if not ok then
        print(('^3[qb-fines-demerits]^7 Warning during rolling calc: %s. Falling back to ALL-TIME sum. Ensure player_demerits has `created_at`!'):format(err))
        rows = MySQL.query.await('SELECT COALESCE(SUM(points),0) AS total FROM player_demerits WHERE citizenid = ?', { citizenid })
    end

    local total = (rows and rows[1] and tonumber(rows[1].total)) or 0

    -- Update if online
    for _, pid in pairs(QBCore.Functions.GetPlayers()) do
        local xp = QBCore.Functions.GetPlayer(pid)
        if xp and xp.PlayerData.citizenid == citizenid then
            xp.Functions.SetMetaData('demerit_points', total)

            local threshold = tonumber(Config.DemeritSuspensionThreshold or 100)
            if total >= threshold then
                if not (xp.PlayerData.metadata and xp.PlayerData.metadata.license_suspended) then
                    xp.Functions.SetMetaData('license_suspended', true)
                    if srcForNotify then
                        SNotify(srcForNotify, (Config.Locales.suspended or "Your licence is suspended."):format(Config.SuspensionMonths or 3, total), 'error')
                    end
                    SNotify(xp.PlayerData.source, (Config.Locales.suspended or "Your licence is suspended."):format(Config.SuspensionMonths or 3, total), 'error')
                end
            else
                if xp.PlayerData.metadata and xp.PlayerData.metadata.license_suspended then
                    xp.Functions.SetMetaData('license_suspended', false)
                end
            end
            break
        end
    end

    return total
end

-- =======================================
-- Issue fine (called by tablet or command)
-- =======================================
RegisterNetEvent("qb-fines:server:issueFine", function(data)
    local src = source
    if not isPolice(src) then
        DropPlayer(src, "Attempted to use police-only event")
        return
    end

    if type(data) ~= 'table' then return end
    local targetId = tonumber(data.target)
    if not targetId then return end

    local officer = QBCore.Functions.GetPlayer(src)
    local target  = QBCore.Functions.GetPlayer(targetId)
    if not target then
        SNotify(src, "Target not online", "error")
        return
    end

    local offence = data.offence or {}
    local method  = (data.method == 'cash' or data.method == 'bank') and data.method or (data.method == 'unpaid' and 'unpaid' or 'unpaid')
    local note    = tostring(data.note or ""):sub(1, 120)

    local amount  = tonumber(offence.amount) or 0
    local points  = tonumber(offence.points) or 0
    local code    = offence.code or "UNKNOWN"
    local label   = offence.label or "Unknown Offence"

    -- Insert demerit history row (source of truth)
    MySQL.insert('INSERT INTO player_demerits (citizenid, points, offence_code, offence_label) VALUES (?, ?, ?, ?)', {
        target.PlayerData.citizenid, points, code, label
    })

    -- Handle payment or ticket
    local paid = 0
    local paid_method = nil
    if method == 'cash' or method == 'bank' then
        local removed = true
        if amount > 0 then
            removed = target.Functions.RemoveMoney(method, amount, ('Fine: %s'):format(label))
        end
        if not removed then
            SNotify(src, Config.Locales.noMoney or "Insufficient funds.", 'error')
            return
        end
        paid = 1
        paid_method = method
        SNotify(targetId, (Config.Locales.fineReceived or "You were fined for %s: $%s and %s points."):format(label, amount, points), 'error')
        SNotify(src, (Config.Locales.fineIssued or "Fine issued to %s for %s ($%s, %s points)."):format(("%s %s"):format(target.PlayerData.charinfo.firstname, target.PlayerData.charinfo.lastname), label, amount, points), 'success')
    else
        -- Issue ticket (unpaid)
        SNotify(targetId, (Config.Locales.fineReceived or "You were fined for %s: $%s and %s points."):format(label, amount, points), 'error')
        SNotify(src, (Config.Locales.fineQueued or "Ticket issued to %s for %s ($%s, %s points)."):format(("%s %s"):format(target.PlayerData.charinfo.firstname, target.PlayerData.charinfo.lastname), label, amount, points), 'success')
    end

    -- Log fine
    MySQL.insert('INSERT INTO player_fines (officer_id, officer_name, target_id, target_name, offence_code, offence_label, amount, demerit_points, payment_method, note, paid, paid_at, target_cid) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, IF(?=1, NOW(), NULL), ?)', {
        officer.PlayerData.citizenid,
        ("%s %s"):format(officer.PlayerData.charinfo.firstname, officer.PlayerData.charinfo.lastname),
        target.PlayerData.citizenid,
        ("%s %s"):format(target.PlayerData.charinfo.firstname, target.PlayerData.charinfo.lastname),
        code, label, amount, points,
        paid_method or 'unpaid',
        note,
        paid,
        paid,
        target.PlayerData.citizenid
    })

    -- Recalc totals/suspension from rolling window
    RecalcDemeritsForCitizen(target.PlayerData.citizenid, targetId)
end)

-- ========================================
-- Callback: get unpaid fines for requester
-- ========================================
QBCore.Functions.CreateCallback('qb-fines:server:getUnpaidFines', function(source, cb)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer then cb({}, 0); return end
    local cid = xPlayer.PlayerData.citizenid
    MySQL.query('SELECT id, created_at, offence_label, amount, demerit_points FROM player_fines WHERE target_cid = ? AND paid = 0 ORDER BY created_at DESC', { cid }, function(rows)
        local total = 0
        for _, r in ipairs(rows or {}) do total = total + (r.amount or 0) end
        cb(rows or {}, total)
    end)
end)

-- ====================
-- Pay a specific fine
-- ====================
RegisterNetEvent('qb-fines:server:payFine', function(fineId, method)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    method = (method == 'cash') and 'cash' or 'bank'

    local rows = MySQL.query.await('SELECT id, amount, target_cid FROM player_fines WHERE id = ? AND paid = 0', { tonumber(fineId) })
    if not rows or not rows[1] then
        SNotify(src, "Ticket not found or already paid.", 'error')
        return
    end
    local row = rows[1]
    if row.target_cid ~= xPlayer.PlayerData.citizenid then
        SNotify(src, "This ticket is not yours.", 'error')
        return
    end

    local amount = tonumber(row.amount) or 0
    local removed = true
    if amount > 0 then
        removed = xPlayer.Functions.RemoveMoney(method, amount, 'Pay Fine')
    end
    if not removed then
        SNotify(src, Config.Locales.noMoney or "Insufficient funds.", 'error')
        return
    end

    MySQL.update('UPDATE player_fines SET paid = 1, paid_at = NOW(), payment_method = ? WHERE id = ?', { method, row.id })
    SNotify(src, (Config.Locales.paidFine or "Paid ticket #%s: $%s via %s."):format(row.id, amount, method), 'success')
end)

-- ==========
-- Commands
-- ==========
QBCore.Commands.Add('demerits', 'Check your demerit points (rolling 24 months)', {}, false, function(source)
    local xPlayer = QBCore.Functions.GetPlayer(source)
    if not xPlayer then return end
    local total = RecalcDemeritsForCitizen(xPlayer.PlayerData.citizenid)
    SNotify(source, ("You have %s demerit points (last %s months)."):format(total, Config.DemeritWindowMonths or 24), 'info')
end)

QBCore.Commands.Add('resetdemerits', 'Reset a player\'s demerit points (Admin/Police)', {{name='id', help='Server ID'}}, true, function(source, args)
    local src = source
    local id = tonumber(args[1]); if not id then return end
    local caller = QBCore.Functions.GetPlayer(src); if not caller then return end
    local isAdmin = IsPlayerAceAllowed(src, "command") or (caller.PlayerData.job and caller.PlayerData.job.name == 'police' and caller.PlayerData.job.grade and caller.PlayerData.job.grade.level >= 3)
    if not isAdmin then SNotify(src, "Not authorised", 'error'); return end

    local target = QBCore.Functions.GetPlayer(id); if not target then SNotify(src, "Target not online", 'error'); return end
    MySQL.query.await('DELETE FROM player_demerits WHERE citizenid = ?', { target.PlayerData.citizenid })
    target.Functions.SetMetaData('demerit_points', 0)
    target.Functions.SetMetaData('license_suspended', false)
    SNotify(src, "Demerits reset.", 'success')
    SNotify(id, "Your demerit points were reset.", 'info')
end)

-- Recalc when player loads in
AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if player and player.PlayerData and player.PlayerData.citizenid then
        RecalcDemeritsForCitizen(player.PlayerData.citizenid)
    end
end)
