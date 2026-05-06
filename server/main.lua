local QBCore = exports['qb-core']:GetCoreObject()

local ActiveMissions = {}
local TeamMissions = {}
local CooldownByCitizen = {}
local PendingLobbies = {}
local PendingInvites = {}
local InviteCounter = 0

local function now()
    return os.time()
end

local function getPlayer(source)
    return QBCore.Functions.GetPlayer(source)
end

local function getPlayerJob(source)
    local player = getPlayer(source)
    if not player or not player.PlayerData or not player.PlayerData.job then
        return nil
    end

    return player.PlayerData.job.name
end

local function getPlayerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then
        return nil
    end

    return GetEntityCoords(ped)
end

local function getPlayerNameBySource(source)
    local player = getPlayer(source)
    if not player then
        return GetPlayerName(source) or ('ID %s'):format(source)
    end

    local charinfo = player.PlayerData and player.PlayerData.charinfo
    if charinfo and charinfo.firstname and charinfo.lastname then
        return ('%s %s'):format(charinfo.firstname, charinfo.lastname)
    end

    return GetPlayerName(source) or ('ID %s'):format(source)
end

local function countKeys(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end

    return count
end

local function isServiceJob(jobName)
    return jobName == Config.PoliceJob or jobName == Config.EmsJob
end

local function getAllPlayerSources()
    local qbPlayers = QBCore.Functions.GetPlayers()
    if type(qbPlayers) == 'table' then
        return qbPlayers
    end

    local fallback = {}
    for _, source in ipairs(GetPlayers()) do
        fallback[#fallback + 1] = tonumber(source)
    end

    return fallback
end

local function canInviteTarget(leaderSource, targetSource, jobName)
    if leaderSource == targetSource then
        return false
    end

    if ActiveMissions[targetSource] then
        return false
    end

    if PendingLobbies[targetSource] then
        return false
    end

    local target = getPlayer(targetSource)
    if not target then
        return false
    end

    local targetJob = getPlayerJob(targetSource)
    if targetJob ~= jobName then
        return false
    end

    local leaderCoords = getPlayerCoords(leaderSource)
    local targetCoords = getPlayerCoords(targetSource)
    if not leaderCoords or not targetCoords then
        return false
    end

    return #(leaderCoords - targetCoords) <= Config.Team.InviteRange
end

local function buildMemberList(memberSet)
    local members = {}

    for source, _ in pairs(memberSet) do
        if getPlayer(source) then
            members[#members + 1] = {
                id = source,
                name = getPlayerNameBySource(source)
            }
        end
    end

    table.sort(members, function(a, b)
        return a.name < b.name
    end)

    return members
end

local function buildNearbyList(leaderSource, jobName, memberSet)
    local nearby = {}

    for _, targetSource in ipairs(getAllPlayerSources()) do
        local parsedSource = tonumber(targetSource)
        if parsedSource and not memberSet[parsedSource] and canInviteTarget(leaderSource, parsedSource, jobName) then
            nearby[#nearby + 1] = {
                id = parsedSource,
                name = getPlayerNameBySource(parsedSource)
            }
        end
    end

    table.sort(nearby, function(a, b)
        return a.name < b.name
    end)

    return nearby
end

local function deleteLeaderInvites(leaderSource)
    for inviteId, invite in pairs(PendingInvites) do
        if invite.leader == leaderSource then
            PendingInvites[inviteId] = nil
        end
    end
end

local function pushLobbyUpdate(leaderSource)
    local lobby = PendingLobbies[leaderSource]
    if not lobby then
        return
    end

    TriggerClientEvent(
        'qb-servicejobs:client:updateLobbyData',
        leaderSource,
        buildMemberList(lobby.members),
        buildNearbyList(leaderSource, lobby.jobName, lobby.members),
        Config.Team.MaxMembers
    )
end

local function validateMissionRequest(source, missionId, jobName)
    local player = getPlayer(source)
    if not player then
        return false, 'invalid_player', 0
    end

    local mission = ServiceMissions.GetById(missionId)
    if not mission then
        return false, 'invalid_mission', 0
    end

    local currentJob = getPlayerJob(source)
    if not currentJob or currentJob ~= jobName then
        return false, 'job', 0
    end

    if not isServiceJob(currentJob) then
        return false, 'job', 0
    end

    if ActiveMissions[source] then
        return false, 'already', 0
    end

    local citizenId = player.PlayerData.citizenid
    local cooldownUntil = CooldownByCitizen[citizenId] or 0
    if cooldownUntil > now() then
        return false, 'cooldown', cooldownUntil - now()
    end

    return true, mission, 0
end

local function clearTeamMission(leaderSource, reason)
    local team = TeamMissions[leaderSource]
    if not team then
        return
    end

    for _, memberSource in ipairs(team.members) do
        ActiveMissions[memberSource] = nil
        TriggerClientEvent('qb-servicejobs:client:teamMissionStopped', memberSource, reason)
    end

    TeamMissions[leaderSource] = nil
end

QBCore.Functions.CreateCallback('qb-servicejobs:server:prepareLobby', function(source, cb, missionId, jobName)
    local canStart, reason, cooldownLeft = validateMissionRequest(source, missionId, jobName)

    if not canStart then
        cb(false, nil, reason, cooldownLeft)
        return
    end

    PendingLobbies[source] = {
        leader = source,
        missionId = missionId,
        jobName = jobName,
        members = {
            [source] = true
        },
        createdAt = now()
    }

    deleteLeaderInvites(source)

    cb(true, {
        maxMembers = Config.Team.MaxMembers,
        members = buildMemberList(PendingLobbies[source].members),
        nearby = buildNearbyList(source, jobName, PendingLobbies[source].members)
    })
end)

RegisterNetEvent('qb-servicejobs:server:closeLobby', function()
    local source = source

    if not PendingLobbies[source] then
        return
    end

    deleteLeaderInvites(source)
    PendingLobbies[source] = nil
end)

RegisterNetEvent('qb-servicejobs:server:invitePlayer', function(targetSource)
    local leaderSource = source
    local lobby = PendingLobbies[leaderSource]
    if not lobby then
        return
    end

    if countKeys(lobby.members) >= Config.Team.MaxMembers then
        TriggerClientEvent('QBCore:Notify', leaderSource, Lang:t('error.invite_limit'), 'error')
        return
    end

    local parsedTarget = tonumber(targetSource)
    if not parsedTarget or not canInviteTarget(leaderSource, parsedTarget, lobby.jobName) then
        TriggerClientEvent('QBCore:Notify', leaderSource, Lang:t('error.invite_only_near'), 'error')
        return
    end

    for _, invite in pairs(PendingInvites) do
        if invite.leader == leaderSource and invite.target == parsedTarget then
            return
        end
    end

    InviteCounter = InviteCounter + 1
    local inviteId = ('%s:%s:%s'):format(leaderSource, parsedTarget, InviteCounter)

    PendingInvites[inviteId] = {
        id = inviteId,
        leader = leaderSource,
        target = parsedTarget,
        jobName = lobby.jobName,
        missionId = lobby.missionId,
        expiresAt = now() + Config.Team.InviteTimeoutSeconds
    }

    local mission = ServiceMissions.GetById(lobby.missionId)

    TriggerClientEvent('qb-servicejobs:client:receiveMissionInvite', parsedTarget, {
        inviteId = inviteId,
        leaderId = leaderSource,
        leaderName = getPlayerNameBySource(leaderSource),
        missionId = lobby.missionId,
        missionTitle = mission and mission.title or 'Mision de servicio',
        jobName = lobby.jobName
    })

    TriggerClientEvent('QBCore:Notify', leaderSource, Lang:t('success.invited_player', {
        name = getPlayerNameBySource(parsedTarget)
    }), 'success')

    pushLobbyUpdate(leaderSource)
end)

RegisterNetEvent('qb-servicejobs:server:respondInvite', function(inviteId, accepted)
    local targetSource = source
    local parsedInviteId = tostring(inviteId or '')
    local invite = PendingInvites[parsedInviteId]

    if not invite or invite.target ~= targetSource then
        return
    end

    PendingInvites[parsedInviteId] = nil

    local leaderSource = invite.leader
    local lobby = PendingLobbies[leaderSource]

    if not lobby then
        TriggerClientEvent('QBCore:Notify', targetSource, 'La invitacion ya no esta disponible.', 'error')
        return
    end

    if now() > invite.expiresAt then
        TriggerClientEvent('QBCore:Notify', targetSource, 'La invitacion ha expirado.', 'error')
        pushLobbyUpdate(leaderSource)
        return
    end

    if not accepted then
        TriggerClientEvent('QBCore:Notify', targetSource, Lang:t('info.invite_declined'), 'primary')
        pushLobbyUpdate(leaderSource)
        return
    end

    if countKeys(lobby.members) >= Config.Team.MaxMembers then
        TriggerClientEvent('QBCore:Notify', targetSource, Lang:t('error.invite_limit'), 'error')
        pushLobbyUpdate(leaderSource)
        return
    end

    if not canInviteTarget(leaderSource, targetSource, lobby.jobName) then
        TriggerClientEvent('QBCore:Notify', targetSource, Lang:t('error.invite_only_near'), 'error')
        pushLobbyUpdate(leaderSource)
        return
    end

    lobby.members[targetSource] = true

    TriggerClientEvent('QBCore:Notify', leaderSource, Lang:t('success.invite_accepted', {
        name = getPlayerNameBySource(targetSource)
    }), 'success')

    TriggerClientEvent('QBCore:Notify', targetSource, 'Te has unido al equipo de mision.', 'success')

    pushLobbyUpdate(leaderSource)
end)

RegisterNetEvent('qb-servicejobs:server:startMission', function(missionId, jobName)
    local leaderSource = source
    local lobby = PendingLobbies[leaderSource]

    if Config.Debug then
        print(('[qb-servicejobs] startMission requested by=%s missionId=%s jobName=%s lobby=%s'):format(tostring(leaderSource), tostring(missionId), tostring(jobName), tostring(lobby ~= nil)))
    end

    if not lobby then
        TriggerClientEvent('QBCore:Notify', leaderSource, 'No tienes un lobby activo.', 'error')
        if Config.Debug then
            print(('[qb-servicejobs] startMission aborted: no lobby for leader=%s'):format(leaderSource))
        end
        return
    end

    if lobby.missionId ~= missionId or lobby.jobName ~= jobName then
        TriggerClientEvent('QBCore:Notify', leaderSource, 'Lobby invalido para esta mision.', 'error')
        if Config.Debug then
            print(('[qb-servicejobs] startMission aborted: lobby mismatch leader=%s lobbyMission=%s lobbyJob=%s'):format(leaderSource, tostring(lobby.missionId), tostring(lobby.jobName)))
        end
        return
    end

    local canStart, reason = validateMissionRequest(leaderSource, missionId, jobName)
    if not canStart then
        if reason == 'cooldown' then
            TriggerClientEvent('QBCore:Notify', leaderSource, 'Todavia estas en enfriamiento de mision.', 'error')
        else
            TriggerClientEvent('QBCore:Notify', leaderSource, 'No puedes iniciar esta mision.', 'error')
        end
        if Config.Debug then
            print(('[qb-servicejobs] startMission aborted: validate failed leader=%s reason=%s'):format(leaderSource, tostring(reason)))
        end
        return
    end

    local mission = ServiceMissions.GetById(missionId)
    if not mission then
        TriggerClientEvent('QBCore:Notify', leaderSource, 'Mision invalida.', 'error')
        if Config.Debug then
            print(('[qb-servicejobs] startMission aborted: mission not found missionId=%s'):format(tostring(missionId)))
        end
        return
    end

    local finalMembers = {}

    if lobby.members[leaderSource] then
        finalMembers[#finalMembers + 1] = leaderSource
    end

    for memberSource, _ in pairs(lobby.members) do
        if memberSource ~= leaderSource and #finalMembers < Config.Team.MaxMembers then
            if canInviteTarget(leaderSource, memberSource, jobName) then
                finalMembers[#finalMembers + 1] = memberSource
            end
        end
    end

    if #finalMembers == 0 then
        TriggerClientEvent('QBCore:Notify', leaderSource, 'No hay miembros validos para iniciar.', 'error')
        if Config.Debug then
            print(('[qb-servicejobs] startMission aborted: no valid members for leader=%s'):format(leaderSource))
        end
        return
    end

    local teamMembersPayload = {}
    local progressHits = {}

    for _, memberSource in ipairs(finalMembers) do
        progressHits[memberSource] = 0
        teamMembersPayload[#teamMembersPayload + 1] = {
            id = memberSource,
            name = getPlayerNameBySource(memberSource)
        }
    end

    progressHits[leaderSource] = 1

    TeamMissions[leaderSource] = {
        leader = leaderSource,
        missionId = missionId,
        jobName = jobName,
        members = finalMembers,
        startedAt = now(),
        progressHits = progressHits,
        lastCheckpointAt = 0,
        lastCheckpointCoords = nil
    }

    local teamData = {
        leaderServerId = leaderSource,
        members = teamMembersPayload,
        count = #finalMembers
    }

    for _, memberSource in ipairs(finalMembers) do
        local player = getPlayer(memberSource)
        if player then
            ActiveMissions[memberSource] = {
                missionId = missionId,
                jobName = jobName,
                leader = leaderSource,
                startedAt = now(),
                citizenId = player.PlayerData.citizenid
            }

            TriggerClientEvent(
                'qb-servicejobs:client:startTeamMission',
                memberSource,
                mission,
                jobName,
                teamData,
                memberSource == leaderSource
            )
            if Config.Debug then
                print(('[qb-servicejobs] sent startTeamMission to %s (leader=%s)'):format(tostring(memberSource), tostring(leaderSource)))
            end
        end
    end

    PendingLobbies[leaderSource] = nil
    deleteLeaderInvites(leaderSource)

    TriggerClientEvent('QBCore:Notify', leaderSource, Lang:t('success.team_started', {
        count = #finalMembers
    }), 'success')
end)

RegisterNetEvent('qb-servicejobs:server:announceCheckpoint', function(x, y, z)
    local leaderSource = source
    local active = ActiveMissions[leaderSource]

    if not active or active.leader ~= leaderSource then
        return
    end

    local team = TeamMissions[leaderSource]
    if not team then
        return
    end

    local currentTime = now()
    if currentTime - (team.lastCheckpointAt or 0) < 3 then
        return
    end

    local checkpoint = vector3(tonumber(x) or 0.0, tonumber(y) or 0.0, tonumber(z) or 0.0)

    if team.lastCheckpointCoords and #(checkpoint - team.lastCheckpointCoords) < 5.0 then
        return
    end

    team.lastCheckpointAt = currentTime
    team.lastCheckpointCoords = checkpoint

    for _, memberSource in ipairs(team.members) do
        local memberCoords = getPlayerCoords(memberSource)
        if memberCoords and #(memberCoords - checkpoint) <= Config.Team.CheckpointRadius then
            team.progressHits[memberSource] = (team.progressHits[memberSource] or 0) + 1
        end
    end
end)

RegisterNetEvent('qb-servicejobs:server:cancelMission', function(missionId, jobName, reason)
    local source = source
    local active = ActiveMissions[source]

    if not active then
        return
    end

    if active.missionId ~= missionId or active.jobName ~= jobName then
        return
    end

    local leaderSource = active.leader

    if source == leaderSource then
        clearTeamMission(leaderSource, reason or 'failed')
    else
        ActiveMissions[source] = nil

        local team = TeamMissions[leaderSource]
        if team then
            for index = #team.members, 1, -1 do
                if team.members[index] == source then
                    table.remove(team.members, index)
                    break
                end
            end

            team.progressHits[source] = nil
        end

        TriggerClientEvent('qb-servicejobs:client:teamMissionStopped', source, reason or 'cancelled')
    end

    if Config.Debug then
        print(('[qb-servicejobs] cancel source=%s mission=%s reason=%s'):format(source, missionId, tostring(reason)))
    end
end)

RegisterNetEvent('qb-servicejobs:server:completeMission', function(missionId, jobName, elapsedSeconds)
    local leaderSource = source
    local active = ActiveMissions[leaderSource]

    if not active or active.leader ~= leaderSource then
        TriggerClientEvent('QBCore:Notify', leaderSource, 'Solo el lider puede cerrar esta mision.', 'error')
        return
    end

    if active.missionId ~= missionId or active.jobName ~= jobName then
        TriggerClientEvent('QBCore:Notify', leaderSource, 'Integridad de mision invalida.', 'error')
        return
    end

    local mission = ServiceMissions.GetById(missionId)
    local team = TeamMissions[leaderSource]

    if not mission or not team then
        TriggerClientEvent('QBCore:Notify', leaderSource, 'Estado de mision invalido.', 'error')
        return
    end

    local duration = tonumber(elapsedSeconds) or 0
    if duration < Config.MinimumMissionDuration then
        TriggerClientEvent('QBCore:Notify', leaderSource, 'Mision demasiado corta para recompensa.', 'error')
        clearTeamMission(leaderSource, 'failed')
        return
    end

    if duration > (Config.MissionTimeoutSeconds + 60) then
        TriggerClientEvent('QBCore:Notify', leaderSource, 'Mision expirada.', 'error')
        clearTeamMission(leaderSource, 'failed')
        return
    end

    local leaderCoords = getPlayerCoords(leaderSource)

    for _, memberSource in ipairs(team.members) do
        local memberPlayer = getPlayer(memberSource)

        if memberPlayer then
            local progressHits = team.progressHits[memberSource] or 0
            local enoughCheckpoints = progressHits >= Config.Team.MinCheckpointsForPayout

            local closeToLeader = memberSource == leaderSource
            if leaderCoords and memberSource ~= leaderSource then
                local memberCoords = getPlayerCoords(memberSource)
                if memberCoords then
                    closeToLeader = #(memberCoords - leaderCoords) <= Config.Team.MaxPayoutDistanceFromLeader
                end
            elseif not leaderCoords then
                closeToLeader = true
            end

            if enoughCheckpoints and closeToLeader then
                local payout = Config.GetPayout(mission.difficulty)
                if memberSource ~= leaderSource then
                    payout = math.floor(payout * Config.Team.MemberPayoutMultiplier)
                end

                if payout < 1 then
                    payout = 1
                end

                memberPlayer.Functions.AddMoney('cash', payout, 'service-job-mission-team')
                TriggerClientEvent('qb-servicejobs:client:receivePayout', memberSource, payout)
            else
                if not enoughCheckpoints then
                    TriggerClientEvent('qb-servicejobs:client:noPayout', memberSource, 'activity')
                elseif not closeToLeader then
                    TriggerClientEvent('qb-servicejobs:client:noPayout', memberSource, 'distance')
                end
            end

            CooldownByCitizen[memberPlayer.PlayerData.citizenid] = now() + Config.CooldownSeconds
        end
    end

    clearTeamMission(leaderSource, 'completed')

    if Config.Debug then
        print(('[qb-servicejobs] team paid leader=%s mission=%s members=%s'):format(leaderSource, missionId, #team.members))
    end
end)

AddEventHandler('playerDropped', function()
    local source = source

    if PendingLobbies[source] then
        deleteLeaderInvites(source)
        PendingLobbies[source] = nil
    end

    for inviteId, invite in pairs(PendingInvites) do
        if invite.target == source or invite.leader == source then
            PendingInvites[inviteId] = nil
        end
    end

    local active = ActiveMissions[source]
    if not active then
        return
    end

    if active.leader == source then
        clearTeamMission(source, 'failed')
        return
    end

    local team = TeamMissions[active.leader]
    if team then
        for index = #team.members, 1, -1 do
            if team.members[index] == source then
                table.remove(team.members, index)
                break
            end
        end

        team.progressHits[source] = nil
    end

    ActiveMissions[source] = nil
end)

CreateThread(function()
    while true do
        Wait(5000)

        local currentTime = now()
        for inviteId, invite in pairs(PendingInvites) do
            if invite.expiresAt <= currentTime then
                PendingInvites[inviteId] = nil

                if getPlayer(invite.target) then
                    TriggerClientEvent('QBCore:Notify', invite.target, 'La invitacion de equipo ha expirado.', 'error')
                end

                pushLobbyUpdate(invite.leader)
            end
        end
    end
end)
