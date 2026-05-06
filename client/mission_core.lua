local QBCore = exports['qb-core']:GetCoreObject()

MissionCore = MissionCore or {}
MissionCore.Runners = {}
MissionCore.ActiveMission = nil
MissionCore.CancelRequested = false
MissionCore.FailReason = nil
MissionCore.ManagedEntities = {}
MissionCore.ManagedBlips = {}
MissionCore.AttachedProp = nil
MissionCore.CarryAnim = nil
MissionCore.MarkerDisabled = false
MissionCore.TimerLastRemaining = nil
MissionCore.TeamData = nil
MissionCore.IsLeader = true
MissionCore.SupportBlip = nil

local function debugLog(message)
    if Config.Debug then
        print(('[qb-servicejobs] %s'):format(message))
    end
end

local function drawFloatingText(coords, text)
    local maxDistance = Config.DrawTextDistance or 18.0
    local playerCoords = GetEntityCoords(PlayerPedId())
    if #(playerCoords - coords) > maxDistance then
        return
    end

    local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then
        return
    end

    SetTextScale(0.31, 0.31)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 225)
    SetTextEntry('STRING')
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(screenX, screenY)

    local backgroundWidth = (string.len(text) or 10) / 370
    DrawRect(screenX, screenY + 0.0125, backgroundWidth, 0.028, 15, 15, 15, 120)
end

local function safeDrawMarker(markerType, x, y, z, dirX, dirY, dirZ, rotX, rotY, rotZ, scaleX, scaleY, scaleZ, r, g, b, a, bobUpAndDown, faceCamera, p19, rotate, textureDict, textureName, drawOnEnts)
    if MissionCore.MarkerDisabled then
        return
    end

    local ok, err = pcall(function()
        DrawMarker(
            markerType,
            x,
            y,
            z,
            dirX,
            dirY,
            dirZ,
            rotX,
            rotY,
            rotZ,
            scaleX,
            scaleY,
            scaleZ,
            r,
            g,
            b,
            a,
            bobUpAndDown,
            faceCamera,
            p19,
            rotate,
            textureDict,
            textureName,
            drawOnEnts
        )
    end)

    if not ok then
        MissionCore.MarkerDisabled = true
        debugLog(('DrawMarker disabled after native error: %s'):format(tostring(err)))
    end
end

local function drawMissionTimer(force)
    if not MissionCore.ActiveMission then
        if force then
            SendNUIMessage({
                action = 'missionTimer',
                payload = {
                    show = false
                }
            })
        end

        MissionCore.TimerLastRemaining = nil
        return
    end

    local elapsed = math.floor((GetGameTimer() - MissionCore.ActiveMission.startedAt) / 1000)
    local remaining = math.max(0, Config.MissionTimeoutSeconds - elapsed)

    if not force and MissionCore.TimerLastRemaining == remaining then
        return
    end

    MissionCore.TimerLastRemaining = remaining
    SendNUIMessage({
        action = 'missionTimer',
        payload = {
            show = true,
            remaining = remaining
        }
    })
end

local function showHelpText(message)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function requestModel(model)
    if not IsModelInCdimage(model) then
        return false
    end

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end

    return true
end

local function requestAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(0)
    end
end

local function trackEntity(entity)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        MissionCore.ManagedEntities[#MissionCore.ManagedEntities + 1] = entity
    end

    return entity
end

local function trackBlip(blip)
    if blip and blip ~= 0 then
        MissionCore.ManagedBlips[#MissionCore.ManagedBlips + 1] = blip
    end

    return blip
end

local function isTimedOut()
    if not MissionCore.ActiveMission then
        return true
    end

    local elapsed = math.floor((GetGameTimer() - MissionCore.ActiveMission.startedAt) / 1000)
    if elapsed > Config.MissionTimeoutSeconds then
        MissionCore.FailReason = 'timeout'
        return true
    end

    return false
end

local function announceCheckpoint(coords)
    if not MissionCore.ActiveMission or not MissionCore.IsLeader then
        return
    end

    TriggerServerEvent('qb-servicejobs:server:announceCheckpoint', coords.x, coords.y, coords.z)
end

function MissionCore.Notify(message, messageType, length)
    QBCore.Functions.Notify(message, messageType or 'primary', length or 3500)
end

function MissionCore.HasActiveMission()
    return MissionCore.ActiveMission ~= nil
end

function MissionCore.RegisterRunner(scriptName, handler)
    MissionCore.Runners[scriptName] = handler
end

function MissionCore.GetPlayerCoords()
    return GetEntityCoords(PlayerPedId())
end

function MissionCore.AlignPlayerToHeading(heading)
    if type(heading) ~= 'number' then
        return
    end

    SetEntityHeading(PlayerPedId(), heading + 0.0)
end

function MissionCore.AlignPlayerToCoords(coords)
    if not coords then
        return
    end

    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, 550)
    Wait(550)
end

function MissionCore.AlignPlayerToEntity(entity)
    if not entity or not DoesEntityExist(entity) then
        return
    end

    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, entity, 550)
    Wait(550)
end

function MissionCore.CreateRouteBlip(coords, sprite, color, text)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite or 1)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.9)
    SetBlipColour(blip, color or 3)
    SetBlipAsShortRange(blip, false)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, color or 3)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(text or 'Mision en curso')
    EndTextCommandSetBlipName(blip)

    return trackBlip(blip)
end

function MissionCore.Wait(ms)
    local start = GetGameTimer()
    while (GetGameTimer() - start) < ms do
        if MissionCore.CancelRequested or isTimedOut() then
            return false
        end

        drawMissionTimer()
        Wait(0)
    end

    return true
end

function MissionCore.GoToPoint(coords, label, radius, markerColor)
    local target = vector3(coords.x, coords.y, coords.z)
    local blip = MissionCore.CreateRouteBlip(target, 280, markerColor or 3, label)

    while true do
        if MissionCore.CancelRequested or isTimedOut() then
            return false
        end

        local playerCoords = MissionCore.GetPlayerCoords()
        local distance = #(playerCoords - target)

        if distance < (radius or 3.0) then
            -- Count checkpoint participation when the player actually reaches the target.
            announceCheckpoint(target)
            break
        end

        safeDrawMarker(
            2,
            target.x,
            target.y,
            target.z + 0.1,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            0.23,
            0.23,
            0.23,
            0,
            180,
            255,
            190,
            false,
            true,
            2,
            false,
            '',
            '',
            false
        )

        drawFloatingText(target + vector3(0.0, 0.0, 0.45), label)
        drawMissionTimer()
        Wait(0)
    end

    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end

    return true
end

function MissionCore.DoTimedAction(label, durationMs, animDict, animName, scenario)
    local ped = PlayerPedId()

    if scenario then
        TaskStartScenarioInPlace(ped, scenario, 0, true)
    elseif animDict and animName then
        requestAnimDict(animDict)
        TaskPlayAnim(ped, animDict, animName, 4.0, -4.0, durationMs, 1, 0.0, false, false, false)
    end

    local started = GetGameTimer()
    while (GetGameTimer() - started) < durationMs do
        if MissionCore.CancelRequested or isTimedOut() then
            ClearPedTasks(ped)
            return false
        end

        showHelpText(label)
        drawMissionTimer()
        Wait(0)
    end

    ClearPedTasks(ped)
    return true
end

function MissionCore.WaitForKeyPressAt(coords, radius, prompt)
    local target = vector3(coords.x, coords.y, coords.z)

    while true do
        if MissionCore.CancelRequested or isTimedOut() then
            return false
        end

        local playerCoords = MissionCore.GetPlayerCoords()
        local distance = #(playerCoords - target)

        if distance <= radius then
            showHelpText(prompt)
            safeDrawMarker(
                2,
                target.x,
                target.y,
                target.z + 0.1,
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
                0.0,
                0.2,
                0.2,
                0.2,
                0,
                210,
                160,
                170,
                false,
                true,
                2,
                false,
                '',
                '',
                false
            )

            if IsControlJustPressed(0, Config.InteractionKey) then
                -- Count checkpoint participation on successful interaction at the target.
                announceCheckpoint(target)
                return true
            end
        end

        drawMissionTimer()
        Wait(0)
    end
end

function MissionCore.SpawnMissionPed(model, coords, heading, scenario, freezePed)
    if not requestModel(model) then
        return nil
    end

    local ped = CreatePed(4, model, coords.x, coords.y, coords.z - 1.0, heading, true, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityInvincible(ped, true)

    if freezePed ~= false then
        FreezeEntityPosition(ped, true)
    else
        FreezeEntityPosition(ped, false)
    end

    if scenario then
        TaskStartScenarioInPlace(ped, scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(model)
    return trackEntity(ped)
end

function MissionCore.SpawnMissionVehicle(model, coords, heading)
    if not requestModel(model) then
        return nil
    end

    local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, heading, true, false)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleEngineOn(vehicle, false, true, true)

    SetModelAsNoLongerNeeded(model)
    return trackEntity(vehicle)
end

function MissionCore.SpawnMissionProp(model, coords, heading, freeze)
    if not requestModel(model) then
        return nil
    end

    local prop = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    SetEntityAsMissionEntity(prop, true, true)
    SetEntityHeading(prop, heading or 0.0)
    PlaceObjectOnGroundProperly(prop)

    if freeze then
        FreezeEntityPosition(prop, true)
    end

    SetModelAsNoLongerNeeded(model)
    return trackEntity(prop)
end

function MissionCore.AttachPropToPlayer(model, bone, offset, rotation, options)
    local ped = PlayerPedId()
    options = options or {}

    if not requestModel(model) then
        return nil
    end

    local attachBone = bone or 60309
    local attachOffset = offset or vector3(0.03, 0.06, -0.19)
    local attachRotation = rotation or vector3(15.0, 285.0, 180.0)

    local coords = GetEntityCoords(ped)
    local prop = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    SetEntityAsMissionEntity(prop, true, true)

    if options.disableCollision ~= false then
        SetEntityCollision(prop, false, false)
    end

    AttachEntityToEntity(
        prop,
        ped,
        GetPedBoneIndex(ped, attachBone),
        attachOffset.x,
        attachOffset.y,
        attachOffset.z,
        attachRotation.x,
        attachRotation.y,
        attachRotation.z,
        true,
        true,
        false,
        true,
        1,
        true
    )

    SetModelAsNoLongerNeeded(model)
    MissionCore.AttachedProp = trackEntity(prop)

    local shouldCarry = options.carry ~= false
    if shouldCarry then
        local animDict = options.animDict or 'anim@heists@box_carry@'
        local animName = options.animName or 'idle'

        MissionCore.CarryAnim = {
            dict = animDict,
            name = animName
        }

        requestAnimDict(animDict)
        TaskPlayAnim(ped, animDict, animName, 4.0, -4.0, -1, 49, 0.0, false, false, false)

        local attachedProp = MissionCore.AttachedProp
        CreateThread(function()
            while MissionCore.AttachedProp == attachedProp and DoesEntityExist(attachedProp) do
                local currentPed = PlayerPedId()
                if not IsPedInAnyVehicle(currentPed, false) and not IsEntityPlayingAnim(currentPed, animDict, animName, 3) then
                    TaskPlayAnim(currentPed, animDict, animName, 4.0, -4.0, -1, 49, 0.0, false, false, false)
                end

                Wait(800)
            end
        end)
    else
        MissionCore.CarryAnim = nil
    end

    return MissionCore.AttachedProp
end

function MissionCore.DropAttachedProp()
    local ped = PlayerPedId()

    if MissionCore.AttachedProp and DoesEntityExist(MissionCore.AttachedProp) then
        DetachEntity(MissionCore.AttachedProp, true, true)
        DeleteEntity(MissionCore.AttachedProp)
    end

    MissionCore.AttachedProp = nil

    if MissionCore.CarryAnim then
        StopAnimTask(ped, MissionCore.CarryAnim.dict, MissionCore.CarryAnim.name, 0.2)
        ClearPedSecondaryTask(ped)
        MissionCore.CarryAnim = nil
    end
end

function MissionCore.WaitForVehicleSeat(vehicle, seat)
    while true do
        if MissionCore.CancelRequested or isTimedOut() then
            return false
        end

        if IsPedInVehicle(PlayerPedId(), vehicle, false) then
            return true
        end

        showHelpText('Sube al vehiculo para continuar la mision.')
        drawMissionTimer()
        Wait(0)
    end
end

function MissionCore.PatrolRoute(points)
    for index, point in ipairs(points) do
        local ok = MissionCore.GoToPoint(point, ('Punto de patrulla %s/%s'):format(index, #points), 12.0, 29)
        if not ok then
            return false
        end

        MissionCore.Notify(Lang:t('info.stage_done'), 'success', 1800)
    end

    return true
end

function MissionCore.InteractWithPed(ped, text, radius)
    while true do
        if MissionCore.CancelRequested or isTimedOut() then
            return false
        end

        if not DoesEntityExist(ped) then
            return false
        end

        local playerCoords = MissionCore.GetPlayerCoords()
        local npcCoords = GetEntityCoords(ped)
        local distance = #(playerCoords - npcCoords)

        if distance <= (radius or 2.0) then
            showHelpText(text)
            if IsControlJustPressed(0, Config.InteractionKey) then
                return true
            end
        end

        drawMissionTimer()
        Wait(0)
    end
end

function MissionCore.CancelActiveMission(reason)
    if not MissionCore.ActiveMission then
        return
    end

    MissionCore.CancelRequested = true
    MissionCore.FailReason = reason or 'cancelled'
    TriggerServerEvent(
        'qb-servicejobs:server:cancelMission',
        MissionCore.ActiveMission.mission.id,
        MissionCore.ActiveMission.job,
        MissionCore.FailReason
    )

    if not MissionCore.IsLeader then
        MissionCore.Cleanup(false)
    end

    MissionCore.Notify('Mision cancelada por el usuario.', 'error')
end

function MissionCore.Cleanup(keepState)
    MissionCore.DropAttachedProp()
    drawMissionTimer(true)

    for _, blip in ipairs(MissionCore.ManagedBlips) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end

    for _, entity in ipairs(MissionCore.ManagedEntities) do
        if entity and DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end

    if MissionCore.SupportBlip and DoesBlipExist(MissionCore.SupportBlip) then
        RemoveBlip(MissionCore.SupportBlip)
    end

    MissionCore.ManagedBlips = {}
    MissionCore.ManagedEntities = {}
    MissionCore.SupportBlip = nil

    if not keepState then
        MissionCore.ActiveMission = nil
        MissionCore.CancelRequested = false
        MissionCore.FailReason = nil
        MissionCore.TimerLastRemaining = nil
        MissionCore.TeamData = nil
        MissionCore.IsLeader = true
    end
end

function MissionCore.StartMission(mission, jobName, teamData, isLeader)
    if MissionCore.ActiveMission then
        MissionCore.Notify(Lang:t('error.already_on_mission'), 'error')
        return
    end

    local runner = MissionCore.Runners[mission.script]
    if not runner then
        MissionCore.Notify('No existe logica para esta mision.', 'error')
        return
    end

    MissionCore.ActiveMission = {
        mission = mission,
        job = jobName,
        startedAt = GetGameTimer(),
        teamData = teamData
    }
    MissionCore.TeamData = teamData
    MissionCore.IsLeader = isLeader ~= false
    MissionCore.CancelRequested = false
    MissionCore.FailReason = nil

    MissionCore.Notify(Lang:t('success.mission_started'), 'success')
    MissionCore.Notify(Lang:t('info.cancel_tip'), 'primary', 4500)
    drawMissionTimer(true)

    if teamData and teamData.count and teamData.count > 1 then
        MissionCore.Notify(Lang:t('success.team_started', { count = teamData.count }), 'success', 4000)
    end

    CreateThread(function()
       Wait(500)

        if Config.Debug then debugLog('Starting mission runner after delay') end

        local ok, result = pcall(function()
            return runner(MissionCore.ActiveMission)
        end)

        local elapsedSeconds = math.floor((GetGameTimer() - MissionCore.ActiveMission.startedAt) / 1000)

        if not ok then
            debugLog(('Mission runner crashed (%s): %s'):format(mission.id, tostring(result)))
            MissionCore.FailReason = 'crash'
            result = false
        end

        if result and not MissionCore.CancelRequested and MissionCore.IsLeader then
            TriggerServerEvent('qb-servicejobs:server:completeMission', mission.id, jobName, elapsedSeconds)
        elseif MissionCore.IsLeader then
            TriggerServerEvent('qb-servicejobs:server:cancelMission', mission.id, jobName, MissionCore.FailReason or 'failed')
            if MissionCore.FailReason == 'timeout' then
                MissionCore.Notify('Se agoto el tiempo de la mision.', 'error')
            elseif MissionCore.FailReason ~= 'cancelled' then
                MissionCore.Notify(Lang:t('error.mission_failed'), 'error')
            end
        end

        MissionCore.Cleanup(false)
    end)
end

function MissionCore.StartSupportMission(mission, jobName, teamData)
    if MissionCore.ActiveMission then
        MissionCore.Notify(Lang:t('error.already_on_mission'), 'error')
        return
    end

    MissionCore.ActiveMission = {
        mission = mission,
        job = jobName,
        startedAt = GetGameTimer(),
        teamData = teamData
    }
    MissionCore.TeamData = teamData
    MissionCore.IsLeader = false
    MissionCore.CancelRequested = false
    MissionCore.FailReason = nil

    MissionCore.Notify(Lang:t('success.mission_started'), 'success')
    MissionCore.Notify('Modo apoyo activo: mantente cerca del equipo para recibir pago.', 'primary', 5000)
    MissionCore.Notify(Lang:t('info.cancel_tip'), 'primary', 4500)
    drawMissionTimer(true)

    if teamData and teamData.count and teamData.count > 1 then
        MissionCore.Notify(Lang:t('success.team_started', { count = teamData.count }), 'success', 4000)
    end

    CreateThread(function()
        Wait(500)
        while MissionCore.ActiveMission and not MissionCore.CancelRequested do
            if isTimedOut() then
                MissionCore.FailReason = 'timeout'
                MissionCore.Notify('Se agoto el tiempo de la mision.', 'error')
                TriggerServerEvent('qb-servicejobs:server:cancelMission', mission.id, jobName, 'timeout')
                MissionCore.Cleanup(false)
                break
            end

            if teamData and teamData.leaderServerId then
                local leaderPlayer = GetPlayerFromServerId(teamData.leaderServerId)
                if leaderPlayer and leaderPlayer ~= -1 then
                    local leaderPed = GetPlayerPed(leaderPlayer)
                    if leaderPed and leaderPed ~= 0 then
                        local leaderCoords = GetEntityCoords(leaderPed)

                        if not MissionCore.SupportBlip or not DoesBlipExist(MissionCore.SupportBlip) then
                            MissionCore.SupportBlip = AddBlipForCoord(leaderCoords.x, leaderCoords.y, leaderCoords.z)
                            SetBlipSprite(MissionCore.SupportBlip, 280)
                            SetBlipColour(MissionCore.SupportBlip, 2)
                            SetBlipScale(MissionCore.SupportBlip, 0.75)
                            SetBlipRoute(MissionCore.SupportBlip, true)
                            BeginTextCommandSetBlipName('STRING')
                            AddTextComponentString('Seguir al lider de mision')
                            EndTextCommandSetBlipName(MissionCore.SupportBlip)
                        else
                            SetBlipCoords(MissionCore.SupportBlip, leaderCoords.x, leaderCoords.y, leaderCoords.z)
                        end
                    end
                end
            end

            drawMissionTimer()
            Wait(1000)
        end
    end)
end

RegisterCommand('cancelservicio', function()
    MissionCore.CancelActiveMission('cancelled')
end, false)

RegisterNetEvent('qb-servicejobs:client:receivePayout', function(amount)
    MissionCore.Notify(Lang:t('success.mission_completed', { amount = amount }), 'success', 4500)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    MissionCore.Cleanup(false)
end)
