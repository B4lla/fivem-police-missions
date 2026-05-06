Config = Config or {}

Config.Debug = true
Config.PoliceJob = 'police'
Config.EmsJob = 'ambulance'
Config.CooldownSeconds = 120
Config.MinimumMissionDuration = 35
Config.MissionTimeoutSeconds = 900
Config.InteractionKey = 38
Config.InteractionDistance = 1.8
Config.DrawTextDistance = 18.0

Config.Team = {
    MaxMembers = 4,
    InviteRange = 12.0,
    InviteTimeoutSeconds = 14,
    CheckpointRadius = 24.0,
    MinCheckpointsForPayout = 2,
    MaxPayoutDistanceFromLeader = 55.0,
    MemberPayoutMultiplier = 1.0
}

Config.Payout = {
    min = 120,
    max = 250
}

Config.DifficultyMultiplier = {
    easy = 1.00,
    normal = 1.15,
    hard = 1.30
}

Config.NPCs = {
    police = {
        model = `s_m_y_cop_01`,
        coords = vector4(441.06, -981.98, 30.69, 179.22),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        icon = 'fas fa-shield-halved'
    },
    ambulance = {
        model = `s_m_m_paramedic_01`,
        coords = vector4(307.72, -595.45, 43.28, 69.31),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        icon = 'fas fa-briefcase-medical'
    }
}

Config.PoliceRadarPoints = {
    vector4(409.15, -1023.77, 29.29, 89.41),
    vector4(250.34, -878.02, 30.49, 340.88),
    vector4(-253.95, -992.16, 29.29, 158.42),
    vector4(101.89, -818.57, 31.28, 66.44)
}

Config.PoliceTrafficConePoints = {
    vector4(405.45, -1045.14, 29.34, 267.12),
    vector4(407.88, -1046.10, 29.33, 267.12),
    vector4(410.35, -1046.93, 29.31, 267.12)
}

Config.PolicePatrolRoute = {
    vector3(441.4, -981.8, 30.7),
    vector3(375.8, -1037.2, 29.3),
    vector3(289.4, -996.2, 29.3),
    vector3(312.2, -907.3, 29.3)
}

Config.EmsPatientPoints = {
    vector4(300.84, -582.99, 43.26, 249.42),
    vector4(319.10, -570.90, 28.80, 337.66),
    vector4(345.36, -584.18, 28.80, 72.18),
    vector4(264.49, -626.43, 40.60, 157.93)
}

Config.EmsHomeCheckPoints = {
    vector4(-661.59, -859.73, 24.49, 358.40),
    vector4(93.31, -217.89, 54.64, 338.63),
    vector4(-1317.12, -390.99, 36.70, 321.40)
}

Config.EmsDeliveryPoints = {
    vector4(1836.36, 3678.89, 34.27, 209.71),
    vector4(-247.19, 6331.31, 32.43, 47.23),
    vector4(1691.61, 3585.17, 35.62, 206.22)
}

function Config.GetPayout(difficulty)
    local base = math.random(Config.Payout.min, Config.Payout.max)
    local multiplier = Config.DifficultyMultiplier[difficulty or 'normal'] or 1.0
    return math.floor(base * multiplier)
end
