local function randomFrom(list)
    return list[math.random(1, #list)]
end

local function uniqueRadarPoints(amount)
    local cloned = {}
    for i = 1, #Config.PoliceRadarPoints do
        cloned[#cloned + 1] = Config.PoliceRadarPoints[i]
    end

    local selected = {}
    for i = 1, amount do
        local pick = math.random(1, #cloned)
        selected[#selected + 1] = cloned[pick]
        table.remove(cloned, pick)
    end

    return selected
end

MissionCore.RegisterRunner('police_radar_grid', function()
    local points = uniqueRadarPoints(3)

    for index, point in ipairs(points) do
        local ok = MissionCore.GoToPoint(point, ('Instala radar %s/3'):format(index), 3.0, 38)
        if not ok then
            return false
        end

        ok = MissionCore.WaitForKeyPressAt(point, 2.0, 'Pulsa ~INPUT_CONTEXT~ para desplegar el radar')
        if not ok then
            return false
        end

        MissionCore.AlignPlayerToHeading(point.w or GetEntityHeading(PlayerPedId()))
        ok = MissionCore.DoTimedAction('Instalando radar portatil...', 5200, 'mini@repair', 'fixing_a_player', nil)
        if not ok then
            return false
        end

        MissionCore.SpawnMissionProp(`prop_roadcone02a`, vector3(point.x, point.y, point.z - 1.0), point.w or 0.0, true)
        MissionCore.Notify(Lang:t('info.stage_done'), 'success', 1800)
    end

    return true
end)

MissionCore.RegisterRunner('police_traffic_control', function()
    local anchor = Config.PoliceTrafficConePoints[1]

    local ok = MissionCore.GoToPoint(anchor, 'Acude al cruce asignado', 4.0, 26)
    if not ok then
        return false
    end

    for index, conePoint in ipairs(Config.PoliceTrafficConePoints) do
        ok = MissionCore.WaitForKeyPressAt(conePoint, 1.9, ('Pulsa ~INPUT_CONTEXT~ para colocar cono %s/3'):format(index))
        if not ok then
            return false
        end

        MissionCore.AlignPlayerToHeading(conePoint.w or GetEntityHeading(PlayerPedId()))
        ok = MissionCore.DoTimedAction('Asegurando carril...', 2400, 'mini@repair', 'fixing_a_ped', nil)
        if not ok then
            return false
        end

        MissionCore.SpawnMissionProp(`prop_roadcone02a`, vector3(conePoint.x, conePoint.y, conePoint.z - 1.0), conePoint.w or 0.0, true)
    end

    local witness = MissionCore.SpawnMissionPed(`a_m_m_business_01`, vector3(401.75, -1047.58, 29.35), 91.0, 'WORLD_HUMAN_STAND_IMPATIENT')
    if not witness then
        return false
    end

    ok = MissionCore.InteractWithPed(witness, 'Pulsa ~INPUT_CONTEXT~ para pedir evaluacion de trafico', 2.0)
    if not ok then
        return false
    end

    MissionCore.AlignPlayerToEntity(witness)
    ok = MissionCore.DoTimedAction('Dirigiendo trafico y evaluando flujo...', 9500, nil, nil, 'WORLD_HUMAN_CAR_PARK_ATTENDANT')
    if not ok then
        return false
    end

    return true
end)

MissionCore.RegisterRunner('police_vehicle_inspection', function()
    local zone = vector4(486.98, -1024.28, 28.12, 270.0)
    local ok = MissionCore.GoToPoint(zone, 'Dirigete al vehiculo reportado', 4.0, 38)
    if not ok then
        return false
    end

    local vehicle = MissionCore.SpawnMissionVehicle(`blista`, vector3(zone.x, zone.y, zone.z), zone.w)
    if not vehicle then
        return false
    end

    local driverSpot = GetOffsetFromEntityInWorldCoords(vehicle, -2.0, 0.6, 0.0)
    local driverHeading = (zone.w + 90.0) % 360.0
    local driver = MissionCore.SpawnMissionPed(`a_m_m_soucent_01`, vector3(driverSpot.x, driverSpot.y, driverSpot.z), driverHeading, nil)
    if not driver then
        return false
    end

    SetEntityHeading(driver, driverHeading)
    FreezeEntityPosition(driver, true)

    ok = MissionCore.InteractWithPed(driver, 'Pulsa ~INPUT_CONTEXT~ para iniciar entrevista vehicular', 2.0)
    if not ok then
        return false
    end

    MissionCore.AlignPlayerToEntity(driver)
    ok = MissionCore.DoTimedAction('Verificando documentacion...', 5500, 'amb@world_human_clipboard@male@base', 'base', nil)
    if not ok then
        return false
    end

    SetVehicleDoorOpen(vehicle, 4, false, false)
    local hoodPoint = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, 2.0, 0.0)
    ok = MissionCore.GoToPoint(hoodPoint, 'Inspecciona el compartimento frontal', 1.8, 38)
    if not ok then
        return false
    end

    MissionCore.AlignPlayerToEntity(vehicle)
    ok = MissionCore.DoTimedAction('Inspeccion mecanica frontal...', 6200, 'mini@repair', 'fixing_a_player', nil)
    if not ok then
        return false
    end

    SetVehicleDoorShut(vehicle, 4, false)
    SetVehicleDoorOpen(vehicle, 5, false, false)
    local trunkPoint = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -2.0, 0.0)
    ok = MissionCore.GoToPoint(trunkPoint, 'Inspecciona zona trasera', 1.8, 38)
    if not ok then
        return false
    end

    MissionCore.AlignPlayerToEntity(vehicle)
    ok = MissionCore.DoTimedAction('Revisando maletero...', 5600, 'mini@repair', 'fixing_a_ped', nil)
    if not ok then
        return false
    end

    SetVehicleDoorShut(vehicle, 5, false)
    return true
end)

MissionCore.RegisterRunner('police_hotzone_patrol', function()
    local vehicleSpawn = vector4(455.95, -1017.57, 28.45, 88.2)

    local ok = MissionCore.GoToPoint(vehicleSpawn, 'Recoge la unidad de patrulla', 5.0, 29)
    if not ok then
        return false
    end

    local patrolVehicle = MissionCore.SpawnMissionVehicle(`police`, vector3(vehicleSpawn.x, vehicleSpawn.y, vehicleSpawn.z), vehicleSpawn.w)
    if not patrolVehicle then
        return false
    end

    ok = MissionCore.WaitForVehicleSeat(patrolVehicle, -1)
    if not ok then
        return false
    end

    ok = MissionCore.PatrolRoute(Config.PolicePatrolRoute)
    if not ok then
        return false
    end

    ok = MissionCore.GoToPoint(vector3(441.06, -981.98, 30.69), 'Regresa a central LSPD', 10.0, 38)
    if not ok then
        return false
    end

    return true
end)

MissionCore.RegisterRunner('police_suspect_interview', function()
    local suspectPoint = vector4(153.94, -1037.67, 29.34, 247.0)

    local ok = MissionCore.GoToPoint(suspectPoint, 'Ubica al sospechoso citado', 4.0, 38)
    if not ok then
        return false
    end

    local suspect = MissionCore.SpawnMissionPed(`g_m_y_mexgoon_01`, vector3(suspectPoint.x, suspectPoint.y, suspectPoint.z), suspectPoint.w, 'WORLD_HUMAN_AA_SMOKE')
    if not suspect then
        return false
    end

    ok = MissionCore.InteractWithPed(suspect, 'Pulsa ~INPUT_CONTEXT~ para comenzar entrevista', 2.0)
    if not ok then
        return false
    end

    MissionCore.AlignPlayerToEntity(suspect)
    ok = MissionCore.DoTimedAction('Tomando declaracion en libreta...', 7600, 'amb@world_human_clipboard@male@base', 'base', nil)
    if not ok then
        return false
    end

    FreezeEntityPosition(suspect, false)
    local escortPoint = vector3(145.47, -1044.59, 29.37)
    TaskFollowToOffsetOfEntity(suspect, PlayerPedId(), 0.0, 1.0, 0.0, 1.1, -1, 2.0, true)

    ok = MissionCore.GoToPoint(escortPoint, 'Acompana al sospechoso al punto de salida', 4.0, 38)
    if not ok then
        return false
    end

    ClearPedTasks(suspect)
    TaskWanderStandard(suspect, 10.0, 10)

    return true
end)

MissionCore.RegisterRunner('police_evidence_recovery', function()
    local stashPoint = vector4(120.45, -1313.22, 29.21, 114.2)
    local lockerPoint = vector4(452.84, -980.13, 30.69, 270.0)

    local ok = MissionCore.GoToPoint(stashPoint, 'Dirigete al callejon de evidencia', 3.0, 38)
    if not ok then
        return false
    end

    ok = MissionCore.WaitForKeyPressAt(stashPoint, 2.0, 'Pulsa ~INPUT_CONTEXT~ para inspeccionar la zona')
    if not ok then
        return false
    end

    MissionCore.AlignPlayerToHeading(stashPoint.w)
    ok = MissionCore.DoTimedAction('Buscando paquete de evidencia...', 6400, 'mini@repair', 'fixing_a_player', nil)
    if not ok then
        return false
    end

    local package = MissionCore.AttachPropToPlayer(
        `prop_cs_package_01`,
        60309,
        vector3(0.05, 0.03, -0.02),
        vector3(300.0, 250.0, 20.0)
    )

    if not package then
        return false
    end

    ok = MissionCore.GoToPoint(lockerPoint, 'Entrega la evidencia en LSPD', 2.3, 2)
    if not ok then
        return false
    end

    ok = MissionCore.WaitForKeyPressAt(lockerPoint, 2.1, 'Pulsa ~INPUT_CONTEXT~ para guardar la evidencia')
    if not ok then
        return false
    end

    MissionCore.AlignPlayerToHeading(lockerPoint.w)
    ok = MissionCore.DoTimedAction('Registrando evidencia...', 4500, 'amb@world_human_clipboard@male@base', 'base', nil)
    if not ok then
        return false
    end

    MissionCore.DropAttachedProp()
    return true
end)
