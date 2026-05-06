local QBCore = exports['qb-core']:GetCoreObject()

local spawnedPeds = {}
local playerJob = nil

local function requestModel(model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
end

local function updateJobData()
    local playerData = QBCore.Functions.GetPlayerData()
    playerJob = playerData and playerData.job and playerData.job.name or nil
end

local function cleanupNpcs()
    for key, ped in pairs(spawnedPeds) do
        if ped and DoesEntityExist(ped) then
            DeleteEntity(ped)
        end

        spawnedPeds[key] = nil
    end
end

local function spawnInteractionNpc(key, npcData, requiredJob)
    if spawnedPeds[key] and DoesEntityExist(spawnedPeds[key]) then
        return
    end

    requestModel(npcData.model)

    local ped = CreatePed(
        4,
        npcData.model,
        npcData.coords.x,
        npcData.coords.y,
        npcData.coords.z - 1.0,
        npcData.coords.w,
        false,
        true
    )

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityAsMissionEntity(ped, true, true)

    if npcData.scenario then
        TaskStartScenarioInPlace(ped, npcData.scenario, 0, true)
    end

    local label = requiredJob == Config.PoliceJob and 'Solicitar tarea policial' or 'Solicitar tarea EMS'

    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            {
                icon = npcData.icon,
                label = label,
                canInteract = function()
                    if MissionCore and MissionCore.HasActiveMission and MissionCore.HasActiveMission() then
                        return false
                    end

                    return playerJob == requiredJob
                end,
                action = function()
                    TriggerEvent('qb-servicejobs:client:openMissionUI', requiredJob)
                end
            }
        },
        distance = 2.0
    })

    spawnedPeds[key] = ped
    SetModelAsNoLongerNeeded(npcData.model)
end

local function spawnAllNpcs()
    if not Config.NPCs then
        return
    end

    spawnInteractionNpc('police', Config.NPCs.police, Config.PoliceJob)
    spawnInteractionNpc('ambulance', Config.NPCs.ambulance, Config.EmsJob)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    updateJobData()
    spawnAllNpcs()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if job then
        playerJob = job.name
    else
        updateJobData()
    end
end)

CreateThread(function()
    while not LocalPlayer.state.isLoggedIn do
        Wait(250)
    end

    updateJobData()
    spawnAllNpcs()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    updateJobData()
    spawnAllNpcs()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    cleanupNpcs()
end)
