local QBCore = exports['qb-core']:GetCoreObject()

local uiOpen = false
local pendingMission = nil
local pendingJob = nil
local pendingInviteId = nil
local lastMissionByJob = {}

local function getPlayerJob()
    local playerData = QBCore.Functions.GetPlayerData()
    if not playerData or not playerData.job then
        return nil
    end

    return playerData.job.name
end

local function closeMissionUi(sendClose, shouldCloseLobby)
    if sendClose then
        SendNUIMessage({ action = 'close' })
    end

    if shouldCloseLobby and pendingMission and pendingJob then
        TriggerServerEvent('qb-servicejobs:server:closeLobby')
    end

    SetNuiFocus(false, false)
    uiOpen = false
    pendingMission = nil
    pendingJob = nil
end

RegisterNetEvent('qb-servicejobs:client:openMissionUI', function(targetJob)
    if uiOpen then
        return
    end

    if MissionCore and MissionCore.HasActiveMission and MissionCore.HasActiveMission() then
        QBCore.Functions.Notify(Lang:t('error.already_on_mission'), 'error')
        return
    end

    local playerJob = getPlayerJob()
    if not playerJob or playerJob ~= targetJob then
        QBCore.Functions.Notify(Lang:t('error.job_not_allowed'), 'error')
        return
    end

    local mission = ServiceMissions.GetRandomForJob(playerJob, lastMissionByJob[playerJob])
    if not mission then
        QBCore.Functions.Notify(Lang:t('error.no_mission_found'), 'error')
        return
    end

    QBCore.Functions.TriggerCallback('qb-servicejobs:server:prepareLobby', function(ok, lobbyData, reason, cooldownLeft)
        if not ok then
            if reason == 'cooldown' then
                QBCore.Functions.Notify(Lang:t('error.cooldown', { seconds = cooldownLeft or Config.CooldownSeconds }), 'error')
            elseif reason == 'already' then
                QBCore.Functions.Notify(Lang:t('error.already_on_mission'), 'error')
            else
                QBCore.Functions.Notify(Lang:t('error.job_not_allowed'), 'error')
            end

            return
        end

        pendingMission = mission
        pendingJob = playerJob
        uiOpen = true

        SendNUIMessage({
            action = 'open',
            payload = {
                title = mission.title,
                issuer = mission.issuer,
                briefing = mission.briefing,
                difficulty = mission.difficulty,
                cashMin = Config.Payout.min,
                cashMax = Config.Payout.max,
                job = playerJob,
                maxMembers = lobbyData.maxMembers or Config.Team.MaxMembers,
                members = lobbyData.members or {},
                nearby = lobbyData.nearby or {}
            }
        })

        SetNuiFocus(true, true)
    end, mission.id, playerJob)
end)

RegisterNUICallback('invitePlayer', function(data, cb)
    if not uiOpen then
        cb({ ok = false })
        return
    end

    local targetServerId = tonumber(data and data.serverId)
    if not targetServerId then
        cb({ ok = false })
        return
    end

    TriggerServerEvent('qb-servicejobs:server:invitePlayer', targetServerId)
    cb({ ok = true })
end)

RegisterNUICallback('acceptMission', function(_, cb)
    if not pendingMission or not pendingJob then
        cb({ ok = false })
        return
    end

    TriggerServerEvent('qb-servicejobs:server:startMission', pendingMission.id, pendingJob)
    closeMissionUi(true, false)
    cb({ ok = true })
end)

RegisterNUICallback('rejectMission', function(_, cb)
    QBCore.Functions.Notify(Lang:t('info.mission_rejected'), 'primary')
    closeMissionUi(true, true)
    cb({ ok = true })
end)

RegisterNUICallback('closeUi', function(_, cb)
    closeMissionUi(false, true)
    cb({ ok = true })
end)

RegisterNUICallback('acceptInvite', function(data, cb)
    local inviteId = tostring(data and data.inviteId or '')
    if inviteId ~= '' then
        TriggerServerEvent('qb-servicejobs:server:respondInvite', inviteId, true)
    end

    pendingInviteId = nil
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

RegisterNUICallback('declineInvite', function(data, cb)
    local inviteId = tostring(data and data.inviteId or '')
    if inviteId ~= '' then
        TriggerServerEvent('qb-servicejobs:server:respondInvite', inviteId, false)
    end

    pendingInviteId = nil
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

RegisterNetEvent('qb-servicejobs:client:updateLobbyData', function(members, nearby, maxMembers)
    if not uiOpen then
        return
    end

    SendNUIMessage({
        action = 'updateLobby',
        payload = {
            members = members or {},
            nearby = nearby or {},
            maxMembers = maxMembers or Config.Team.MaxMembers
        }
    })
end)

RegisterNetEvent('qb-servicejobs:client:receiveMissionInvite', function(payload)
    pendingInviteId = payload.inviteId

    SendNUIMessage({
        action = 'incomingInvite',
        payload = payload
    })

    QBCore.Functions.Notify(Lang:t('info.invite_received', { leader = payload.leaderName or 'Lider' }), 'primary', 4500)
    SetNuiFocus(true, true)
end)

RegisterNetEvent('qb-servicejobs:client:startTeamMission', function(mission, jobName, teamData, isLeader)
    SendNUIMessage({ action = 'closeInvite' })
    pendingInviteId = nil

    if uiOpen then
        closeMissionUi(true, false)
    else
        SetNuiFocus(false, false)
    end

    lastMissionByJob[jobName] = mission.id

    if isLeader then
        MissionCore.StartMission(mission, jobName, teamData, true)
    else
        MissionCore.StartSupportMission(mission, jobName, teamData)
    end
end)

RegisterNetEvent('qb-servicejobs:client:teamMissionStopped', function(reason)
    if not MissionCore or not MissionCore.HasActiveMission or not MissionCore.HasActiveMission() then
        return
    end

    if reason ~= 'completed' then
        QBCore.Functions.Notify(Lang:t('error.mission_failed'), 'error')
    end

    MissionCore.Cleanup(false)
end)

RegisterNetEvent('qb-servicejobs:client:noPayout', function(reason)
    if reason == 'activity' then
        QBCore.Functions.Notify(Lang:t('error.no_payout_activity'), 'error', 4500)
    elseif reason == 'distance' then
        QBCore.Functions.Notify(Lang:t('error.no_payout_distance'), 'error', 4500)
    end
end)

RegisterNetEvent('qb-servicejobs:client:forceCloseUi', function()
    closeMissionUi(true, false)
end)
