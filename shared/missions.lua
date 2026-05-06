ServiceMissions = ServiceMissions or {}

ServiceMissions.Police = {
    {
        id = 'police_radar_grid',
        title = 'Despliegue de radares',
        issuer = 'Central LSPD',
        difficulty = 'easy',
        script = 'police_radar_grid',
        briefing = 'Coloca radares portatiles en puntos conflictivos para reducir accidentes y reforzar control de velocidad.'
    },
    {
        id = 'police_traffic_control',
        title = 'Control de trafico',
        issuer = 'Unidad de Movilidad',
        difficulty = 'easy',
        script = 'police_traffic_control',
        briefing = 'Monta un mini perimetro de trafico y estabiliza la circulacion en un cruce de alto flujo.'
    },
    {
        id = 'police_vehicle_inspection',
        title = 'Inspeccion de vehiculo',
        issuer = 'Division de Patrulla',
        difficulty = 'normal',
        script = 'police_vehicle_inspection',
        briefing = 'Realiza una inspeccion protocolaria a un vehiculo reportado y documenta hallazgos en campo.'
    },
    {
        id = 'police_hotzone_patrol',
        title = 'Patrullaje en zona caliente',
        issuer = 'Despacho LSPD',
        difficulty = 'normal',
        script = 'police_hotzone_patrol',
        briefing = 'Ejecuta patrullaje de presencia en una ruta dinamica para disuadir actividad delictiva.'
    },
    {
        id = 'police_suspect_interview',
        title = 'Entrevista de sospechoso',
        issuer = 'Unidad de Investigacion',
        difficulty = 'normal',
        script = 'police_suspect_interview',
        briefing = 'Ubica al sospechoso citado y realiza entrevista breve en via publica para ampliar datos.'
    },
    {
        id = 'police_evidence_recovery',
        title = 'Recuperacion de evidencia',
        issuer = 'Forense LSPD',
        difficulty = 'hard',
        script = 'police_evidence_recovery',
        briefing = 'Asegura un paquete de evidencia en un callejon, custodialo y entregalo en dependencia oficial.'
    }
}

ServiceMissions.Ambulance = {
    {
        id = 'ems_street_assistance',
        title = 'Atencion en via publica',
        issuer = 'Central EMS',
        difficulty = 'easy',
        script = 'ems_street_assistance',
        briefing = 'Un civil presenta malestar en la calle. Evalua signos basicos y aplica protocolo primario.'
    },
    {
        id = 'ems_patient_transfer',
        title = 'Traslado de paciente',
        issuer = 'Coordinacion de Ambulancias',
        difficulty = 'normal',
        script = 'ems_patient_transfer',
        briefing = 'Recoge un paciente en punto urbano y trasladalo de forma segura a zona hospitalaria.'
    },
    {
        id = 'ems_overdose_response',
        title = 'Respuesta por sobredosis',
        issuer = 'Urgencias Criticas',
        difficulty = 'hard',
        script = 'ems_overdose_response',
        briefing = 'Intervencion rapida en posible sobredosis. Estabiliza y supervisa respuesta inmediata.'
    },
    {
        id = 'ems_home_checkup',
        title = 'Revision domiciliaria',
        issuer = 'Atencion Comunitaria',
        difficulty = 'easy',
        script = 'ems_home_checkup',
        briefing = 'Realiza chequeo preventivo a paciente de riesgo y deja registro de atencion.'
    },
    {
        id = 'ems_supply_delivery',
        title = 'Entrega de insumos',
        issuer = 'Logistica Medica',
        difficulty = 'normal',
        script = 'ems_supply_delivery',
        briefing = 'Transporta un paquete de suministros medicos a un centro con faltante urgente.'
    },
    {
        id = 'ems_accident_scene',
        title = 'Escena de accidente',
        issuer = 'Respuesta Operativa',
        difficulty = 'hard',
        script = 'ems_accident_scene',
        briefing = 'Atiende dos afectados en escena de choque, estabiliza y reporta cierre de incidente.'
    }
}

function ServiceMissions.GetById(missionId)
    for _, mission in ipairs(ServiceMissions.Police) do
        if mission.id == missionId then
            return mission
        end
    end

    for _, mission in ipairs(ServiceMissions.Ambulance) do
        if mission.id == missionId then
            return mission
        end
    end

    return nil
end

function ServiceMissions.GetRandomForJob(jobName, lastMissionId)
    local pool = nil

    if jobName == Config.PoliceJob then
        pool = ServiceMissions.Police
    elseif jobName == Config.EmsJob then
        pool = ServiceMissions.Ambulance
    end

    if not pool or #pool == 0 then
        return nil
    end

    if #pool == 1 then
        return pool[1]
    end

    local selected = pool[math.random(1, #pool)]

    if selected.id == lastMissionId then
        selected = pool[math.random(1, #pool)]
    end

    return selected
end
