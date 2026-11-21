local addonName, T = ...

-- The tracker's own strings. Anything not here falls back to Story Mode's
-- (its "Addon Prefix", "Quest Status In Progress", ...), and then to the key.

local strings = {}

strings.enUS = {
    ["Tracker Tooltip Left Click"] = "{lclick} Show the way",
    ["Tracker Quest To Pick Up"] = "To pick up",
    ["Tracker Quest Ready"] = "Ready to turn in",
    ["Tracker Tooltip Right Click"] = "{rclick} Open the story",
    ["Tracker Tooltip Plate"] = "{lclick} Open the story",
    ["Tracker Tooltip Journal"] = "View Journal",
    ["Tracker Tooltip Close"] = "Stop Tracking",
    ["Tracker Tooltip Heading"] = "{lclick} Fold   {rclick} Stop tracking this chapter",
    ["Tracker Node Track"] = "{shift} + {lclick} Track this chapter",
    ["Tracker Node Untrack"] = "{shift} + {lclick} Stop tracking this chapter",
    ["Tracker Chapter Tracked Format"] = "Tracking %s.",
    ["Tracker Chapter Untracked Format"] = "No longer tracking %s.",
    ["Tracker Explorer Unreached"] = "In Explorer mode you can track a chapter once you've reached it.",
    ["Tracker Unfollowed"] = "No longer following that story. Shift-click any story to follow it.",
    ["Story Card Untrack"] = "Tracked. {shift} + {lclick} Stop tracking this story",
    ["Story Card Track"] = "{shift} + {lclick} Track this story",
    ["Hotkey Left Click"] = "Left-click:",
    ["Hotkey Right Click"] = "Right-click:",
    ["Hotkey Shift"] = "Shift",
    ["Explorer Hint Giver Format"] = "Someone in %s has work for you.",
    ["Explorer Hint Search Format"] = "Search %s for something out of the ordinary.",
    ["Explorer Hint Explore"] = "Explore to find where the story goes next.",
    ["Tracker Hidden"] = "Next-step tracker hidden. Type /sm tracker to show it again.",
    ["Tracker Shown"] = "Next-step tracker shown.",
    ["Journey Mode"] = "Journey Mode",
    ["Journey Mode Text"] = "While you're tracking a story, the standard quest tracker is hidden and only the story's next steps show on screen. Stop tracking the story, or turn this off, and the quest tracker comes back.|n|nIn combat the change waits until the fight is over.",
}

strings.esES = {
    ["Tracker Tooltip Left Click"] = "{lclick} Mostrar el camino",
    ["Tracker Quest To Pick Up"] = "Por recoger",
    ["Tracker Quest Ready"] = "Lista para entregar",
    ["Tracker Tooltip Right Click"] = "{rclick} Abrir la historia",
    ["Tracker Tooltip Plate"] = "{lclick} Abrir la historia",
    ["Tracker Tooltip Journal"] = "Ver Diario",
    ["Tracker Tooltip Close"] = "Cerrar Seguimiento",
    ["Tracker Tooltip Heading"] = "{lclick} Plegar   {rclick} Dejar de seguir este capítulo",
    ["Tracker Node Track"] = "{shift} + {lclick} Seguir este capítulo",
    ["Tracker Node Untrack"] = "{shift} + {lclick} Dejar de seguir este capítulo",
    ["Tracker Chapter Tracked Format"] = "Siguiendo %s.",
    ["Tracker Chapter Untracked Format"] = "Ya no sigues %s.",
    ["Tracker Explorer Unreached"] = "En el modo Explorador puedes seguir un capítulo cuando ya lo hayas alcanzado.",
    ["Tracker Unfollowed"] = "Ya no sigues esa historia. Usa Mayús + clic en cualquier historia para seguirla.",
    ["Story Card Untrack"] = "En seguimiento. {shift} + {lclick} Dejar de seguir esta historia",
    ["Story Card Track"] = "{shift} + {lclick} Seguir esta historia",
    ["Hotkey Left Click"] = "Clic izquierdo:",
    ["Hotkey Right Click"] = "Clic derecho:",
    ["Hotkey Shift"] = "Mayús",
    ["Explorer Hint Giver Format"] = "Alguien en %s tiene trabajo para ti.",
    ["Explorer Hint Search Format"] = "Busca en %s algo fuera de lo común.",
    ["Explorer Hint Explore"] = "Explora para descubrir cómo sigue la historia.",
    ["Tracker Hidden"] = "Seguimiento del siguiente paso oculto. Escribe /sm tracker para volver a mostrarlo.",
    ["Tracker Shown"] = "Seguimiento del siguiente paso visible.",
    ["Journey Mode"] = "Modo Travesía",
    ["Journey Mode Text"] = "Mientras sigues una historia, el seguimiento de misiones habitual se oculta y en pantalla solo quedan los siguientes pasos de la historia. Deja de seguir la historia, o desactiva esta opción, y el seguimiento de misiones vuelve.|n|nEn combate, el cambio espera a que termine la pelea.",
}
strings.esMX = strings.esES

local ownStrings = strings[GetLocale()] or {}
local english = strings.enUS

-- Own strings in the client's language, then English, then Story Mode's.
T.L = setmetatable({}, {
    __index = function(_, key)
        local value = ownStrings[key] or english[key]
        if value then return value end
        local base = _G.StoryMode and _G.StoryMode.L
        return base and base[key] or key
    end,
})
