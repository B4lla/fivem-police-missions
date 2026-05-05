local function randomFrom(list)
    return list[math.random(1, #list)]
end

local function setPedInjuredLoop(ped)
    RequestAnimDict('combat@damage@writhe')
    while not HasAnimDictLoaded('combat@damage@writhe') do
        Wait(0)
    end

    TaskPlayAnim(ped, 'combat@damage@writhe', 'writhe_loop', 4.0, -4.0, -1, 1, 0.0, false, false, false)
end

MissionCore.RegisterRunner('ems_street_assistance', function()
    local point = randomFrom(Config.EmsPatientPoints)

    local ok = MissionCore.GoToPoint(point, 'Acude al paciente reportado', 3.5, 1)
    if not ok then
        return false
    end

    local patient = MissionCore.SpawnMissionPed(`a_m_m_skater_01`, vector3(point.x, point.y, point.z), point.w or 0.0, nil)
    if not patient then
        return false
    end

    FreezeEntityPosition(patient, true)
    setPedInjuredLoop(patient)

    ok = MissionCore.WaitForKeyPressAt(point, 2.0, 'Pulsa ~INPUT_CONTEXT~ para iniciar valoracion primaria')
    if not ok then
        return false
    end

    MissionCore.AlignPlayerToEntity(patient)
    ok = MissionCore.DoTimedAction('Aplicando atencion primaria...', 7200, 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest', nil)
    if not ok then
        return false
    end

    ClearPedTasks(patient)
    TaskStartScenarioInPlace(patient, 'WORLD_HUMAN_STAND_MOBILE', 0, true)

    return true
end)

MissionCore.RegisterRunner('ems_patient_transfer', function()
    local pickup = randomFrom(Config.EmsPatientPoints)
    local dropOff = vector3(307.11, -595.05, 43.28)
    local pickupHeading = pickup.w or 0.0
    local spawnOffset = GetOffsetFromCoordAndHeadingInWorldCoords(pickup.x, pickup.y, pickup.z, pickupHeading, -8.0, -3.2, 0.0)
    local ambulanceSpawn = vector4(spawnOffset.x, spawnOffset.y, pickup.z + 0.1, pickupHeading)

    local ok = MissionCore.GoToPoint(pickup, 'Dirigete al punto de recogida', 4.0, 1)
    if not ok then
        return false
    end

    local patient = MissionCore.SpawnMissionPed(`a_m_m_eastsa_02`, vector3(pickup.x, pickup.y, pickup.z), pickupHeading, nil, false)
    local ambulance = MissionCore.SpawnMissionVehicle(`ambulance`, vector3(ambulanceSpawn.x, ambulanceSpawn.y, ambulanceSpawn.z), ambulanceSpawn.w)

    if not patient or not ambulance then
        return false
    end

    ok = MissionCore.WaitForKeyPressAt(pickup, 2.0, 'Pulsa ~INPUT_CONTEXT~ para estabilizar al paciente')
    if not ok then
        return false
    end

    MissionCore.AlignPlayerToEntity(patient)
    ok = MissionCore.DoTimedAction('Estabilizando y asegurando traslado...', 6500, 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest', nil)
    if not ok then
        return false
    end

    FreezeEntityPosition(patient, false)
    TaskWarpPedIntoVehicle(patient, ambulance, 2)

    ok = MissionCore.GoToPoint(vector3(ambulanceSpawn.x, ambulanceSpawn.y, ambulanceSpawn.z), 'Sube a la ambulancia', 4.5, 1)
    if not ok then
        return false
    end

    ok = MissionCore.WaitForVehicleSeat(ambulance, -1)
    if not ok then
        return false
    end

    ok = MissionCore.GoToPoint(dropOff, 'Traslada al paciente al hospital', 13.0, 1)
    if not ok then
        return false
    end

    local rearPoint = GetOffsetFromEntityInWorldCoords(ambulance, 0.0, -3.0, 0.0)
    ok = MissionCore.WaitForKeyPressAt(rearPoint, 2.0, 'Pulsa ~INPUT_CONTEXT~ para descargar al paciente')
    if not ok then
        return false
    end

    if IsPedInVehicle(patient, ambulance, false) then
        TaskLeaveVehicle(patient, ambulance, 0)
        Wait(1600)
        TaskStartScenarioInPlace(patient, 'WORLD_HUMAN_STAND_MOBILE', 0, true)
    end

    return true
end)

MissionCore.RegisterRunner('ems_overdose_response', function()
    local incident = vector4(353.02, -593.72, 28.79, 153.82)

    local ok = MissionCore.GoToPoint(incident, 'Acude a posible sobredosis', 3.5, 1)
    if not ok then
        return false
    end

    local patient = MissionCore.SpawnMissionPed(`a_m_y_stwhi_02`, vector3(incident.x, incident.y, incident.z), incident.w, nil)
    if not patient then
        return false
    end

    FreezeEntityPosition(patient, true)
    setPedInjuredLoop(patient)

    ok = MissionCore.WaitForKeyPressAt(incident, 1.8, 'Pulsa ~INPUT_CONTEXT~ para administrar naloxona')
    if not ok then
        return false
    end

    MissionCore.AlignPlayerToEntity(patient)
    ok = MissionCore.DoTimedAction('Administrando dosis de emergencia...', 7000, 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest', nil)
    if not ok then
        return false
    end

    ok = MissionCore.DoTimedAction('Monitoreando signos y respuesta...', 5600, nil, nil, 'CODE_HUMAN_MEDIC_TIME_OF_DEATH')
    if not ok then
        return false
    end

    ClearPedTasks(patient)
    TaskStartScenarioInPlace(patient, 'WORLD_HUMAN_STAND_MOBILE', 0, true)

    return true
end)

MissionCore.RegisterRunner('ems_home_checkup', function()
    local home = randomFrom(Config.EmsHomeCheckPoints)

    local ok = MissionCore.GoToPoint(home, 'Dirigete al domicilio asignado', 3.5, 1)
    if not ok then
        return false
    end

    local resident = MissionCore.SpawnMissionPed(`a_f_o_genstreet_01`, vector3(home.x, home.y, home.z), home.w or 0.0, 'WORLD_HUMAN_STAND_IMPATIENT')
    if not resident then
        return false
    end

    ok = MissionCore.InteractWithPed(resident, 'Pulsa ~INPUT_CONTEXT~ para iniciar chequeo', 2.0)
    if not ok then
        return false
    end

    MissionCore.AlignPlayerToEntity(resident)
    ok = MissionCore.DoTimedAction('Revisando historial y signos...', 6200, 'amb@world_human_clipboard@male@base', 'base', nil)
    if not ok then
        return false
    end

    ok = MissionCore.DoTimedAction('Completando control preventivo...', 4200, nil, nil, 'WORLD_HUMAN_STAND_MOBILE')
    if not ok then
        return false
    end

    return true
end)

MissionCore.RegisterRunner('ems_supply_delivery', function()
    local storagePoint = vector4(309.26, -599.35, 43.28, 65.0)
    local ambulanceSpawn = vector4(293.38, -605.11, 43.34, 70.19)
    local deliveryPoint = randomFrom(Config.EmsDeliveryPoints)

    local ok = MissionCore.GoToPoint(storagePoint, 'Recoge paquete medico en almacen', 2.5, 1)
    if not ok then
        return false
    end

    ok = MissionCore.WaitForKeyPressAt(storagePoint, 2.0, 'Pulsa ~INPUT_CONTEXT~ para recoger paquete medico')
    if not ok then
        return false
    end

    MissionCore.AlignPlayerToHeading(storagePoint.w)
    ok = MissionCore.DoTimedAction('Preparando insumos medicos...', 4500, 'mini@repair', 'fixing_a_player', nil)
    if not ok then
        return false
    end

    local carried = MissionCore.AttachPropToPlayer(
        `prop_box_wood05a`,
        60309,
        vector3(0.12, 0.0, -0.04),
        vector3(250.0, 280.0, 80.0)
    )

    if not carried then
        return false
    end

    local ambulance = MissionCore.SpawnMissionVehicle(`ambulance`, vector3(ambulanceSpawn.x, ambulanceSpawn.y, ambulanceSpawn.z), ambulanceSpawn.w)
    if not ambulance then
        return false
    end

    local rearPoint = GetOffsetFromEntityInWorldCoords(ambulance, 0.0, -2.8, 0.0)
    ok = MissionCore.GoToPoint(rearPoint, 'Carga los insumos en la ambulancia', 2.2, 1)
    if not ok then
        return false
    end

    ok = MissionCore.WaitForKeyPressAt(rearPoint, 2.0, 'Pulsa ~INPUT_CONTEXT~ para guardar el paquete')
    if not ok then
        return false
    end

    MissionCore.AlignPlayerToEntity(ambulance)
    MissionCore.DropAttachedProp()

    ok = MissionCore.WaitForVehicleSeat(ambulance, -1)
    if not ok then
        return false
    end

    ok = MissionCore.GoToPoint(deliveryPoint, 'Entrega insumos en destino medico', 10.5, 1)
    if not ok then
        return false
    end

    local doctor = MissionCore.SpawnMissionPed(`s_m_m_doctor_01`, vector3(deliveryPoint.x + 1.2, deliveryPoint.y - 0.5, deliveryPoint.z), deliveryPoint.w or 0.0, 'WORLD_HUMAN_CLIPBOARD')
    if not doctor then
        return false
    end

    ok = MissionCore.InteractWithPed(doctor, 'Pulsa ~INPUT_CONTEXT~ para entregar suministros', 2.0)
    if not ok then
        return false
    end

    MissionCore.AlignPlayerToEntity(doctor)
    ok = MissionCore.DoTimedAction('Firmando entrega de insumos...', 4400, 'amb@world_human_clipboard@male@base', 'base', nil)
    if not ok then
        return false
    end

    return true
end)

MissionCore.RegisterRunner('ems_accident_scene', function()
    local scene = vector4(236.43, -1388.79, 30.52, 142.30)

    local ok = MissionCore.GoToPoint(scene, 'Acude a la escena del accidente', 5.0, 1)
    if not ok then
        return false
    end

    local crashedCar = MissionCore.SpawnMissionVehicle(`sultan`, vector3(scene.x, scene.y, scene.z), scene.w)
    if not crashedCar then
        return false
    end

    SetVehicleEngineHealth(crashedCar, 200.0)
    SetVehicleBodyHealth(crashedCar, 420.0)
    SetVehicleDoorBroken(crashedCar, 0, true)

    local patientA = MissionCore.SpawnMissionPed(`a_m_m_hillbilly_01`, vector3(scene.x + 1.2, scene.y + 1.0, scene.z), 0.0, nil)
    local patientB = MissionCore.SpawnMissionPed(`a_f_y_tourist_01`, vector3(scene.x - 1.3, scene.y - 0.9, scene.z), 0.0, nil)

    if not patientA or not patientB then
        return false
    end

    FreezeEntityPosition(patientA, true)
    FreezeEntityPosition(patientB, true)
    setPedInjuredLoop(patientA)
    setPedInjuredLoop(patientB)

    MissionCore.SpawnMissionProp(`prop_roadcone02a`, vector3(scene.x + 2.2, scene.y + 0.2, scene.z - 1.0), scene.w + 35.0, true)
    MissionCore.SpawnMissionProp(`prop_roadcone02a`, vector3(scene.x - 2.0, scene.y + 1.4, scene.z - 1.0), scene.w - 25.0, true)
    MissionCore.SpawnMissionProp(`prop_roadcone02a`, vector3(scene.x + 0.2, scene.y - 2.4, scene.z - 1.0), scene.w + 155.0, true)

    ok = MissionCore.GoToPoint(vector3(scene.x + 1.2, scene.y + 1.0, scene.z), 'Atiende al primer paciente', 2.0, 1)
    if not ok then
        return false
    end

    MissionCore.AlignPlayerToEntity(patientA)
    ok = MissionCore.DoTimedAction('Aplicando protocolo trauma A...', 7000, 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest', nil)
    if not ok then
        return false
    end

    ok = MissionCore.GoToPoint(vector3(scene.x - 1.3, scene.y - 0.9, scene.z), 'Atiende al segundo paciente', 2.0, 1)
    if not ok then
        return false
    end

    MissionCore.AlignPlayerToEntity(patientB)
    ok = MissionCore.DoTimedAction('Aplicando protocolo trauma B...', 7000, 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest', nil)
    if not ok then
        return false
    end

    ClearPedTasks(patientA)
    ClearPedTasks(patientB)
    TaskStartScenarioInPlace(patientA, 'WORLD_HUMAN_STAND_MOBILE', 0, true)
    TaskStartScenarioInPlace(patientB, 'WORLD_HUMAN_STAND_MOBILE', 0, true)

    return true
end)
