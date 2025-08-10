Config = {}

-- Notification Settings
Config.UseOkOkNotify = true
Config.OkOkTitle = "Police Fines"

-- Player search distance for tablet
Config.NearbyPlayerDistance = 5.0

-- Payment & Engine Block
Config.EnableTicketsCommand = true
Config.EnableEngineBlock = true
Config.EngineBlockNotifyInterval = 60000 -- ms

-- NPCs for paying fines
Config.FinesOfficerPeds = {
    {
        model = "s_m_y_cop_01",
        coords = vector3(233.59, -417.69, 48.10),
        heading = 6.0
    }
}

Config.FinesOfficerBlip = {
    enabled = true,
    sprite = 525,      -- icon (default: ticket icon)
    color = 3,         -- light blue
    scale = 0.8,
    label = "Fines Office"
}


-- NZ-inspired Offences
Config.OffenceCategories = {
    {
        label = "Speeding",
        offences = {
            { label = "Exceeding speed limit by 1–10 km/h", amount = 30, points = 10 },
            { label = "Exceeding speed limit by 11–15 km/h", amount = 80, points = 20 },
            { label = "Exceeding speed limit by 16–20 km/h", amount = 120, points = 35 },
            { label = "Exceeding speed limit by 21–25 km/h", amount = 170, points = 40 },
            { label = "Exceeding speed limit by 26–30 km/h", amount = 230, points = 50 },
            { label = "Exceeding speed limit by 31–35 km/h", amount = 300, points = 60 },
            { label = "Exceeding speed limit by 36–40 km/h", amount = 400, points = 70 },
            { label = "Exceeding speed limit by 41+ km/h", amount = 510, points = 80 },
        }
    },
    {
        label = "Traffic",
        offences = {
            { label = "Running red light", amount = 150, points = 20 },
            { label = "Failure to stop at stop sign", amount = 150, points = 20 },
            { label = "Dangerous driving", amount = 600, points = 100 },
            { label = "Reckless driving causing injury", amount = 1200, points = 150 },
        }
    },
    {
        label = "Licensing",
        offences = {
            { label = "Driving without licence", amount = 400, points = 50 },
            { label = "Driving while disqualified", amount = 600, points = 80 },
            { label = "Failing to display L plates", amount = 100, points = 10 },
        }
    }
}

Config.DefaultPaymentMethod = 'unpaid' -- bank, cash, unpaid

Config.Locales = {
    drivingSuspended = "Your licence is suspended — you cannot drive.",
    notPolice = "You must be a police officer to use this.",
    nothingToPay = "You have no unpaid fines."
}
