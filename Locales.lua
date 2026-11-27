local addonName, T = ...

-- The tracker's own strings. Anything not here falls back to Story Mode's
-- (its "Addon Prefix", "Quest Status In Progress", ...), and then to the key.

local strings = {}

strings.enUS = {
    ["Tracker Tooltip Left Click"] = "{lclick} Show the way",
    ["Tracker Tooltip Left Click Stop"] = "{lclick} Stop showing the way",
    ["Tracker Quest To Pick Up"] = "To pick up",
    ["Tracker Quest Ready"] = "Ready to turn in",
    ["Tracker Tooltip Right Click"] = "{rclick} Open the story",
    ["Tracker Tooltip Shift Click Log"] = "{shift} + {lclick} Open in the quest log",
    ["Tracker Tooltip Plate"] = "{lclick} Open the story",
    ["Tracker Tooltip Plate Untrack"] = "{shift} + {lclick} Stop tracking this story",
    ["Tracker Tooltip Plate Journal"] = "{rclick} View Journal",
    ["Tracker Tooltip Heading"] = "{lclick} Fold   {rclick} Stop tracking this chapter",
    ["Tracker Node Track"] = "{shift} + {lclick} Track this chapter",
    ["Tracker Node Untrack"] = "{shift} + {lclick} Stop tracking this chapter",
    ["Tracker Explorer Unreached"] = "In Explorer mode you can track a chapter once you've reached it.",
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
    ["Settings Title"] = "Story Mode - Tracker",
    ["Settings Subtitle"] = "The story you're following, step by step, at the top of the quest tracker.",
    ["Show Tracker"] = "Show the tracker",
    ["Show Tracker Text"] = "Shows the story you're following above the quest tracker. The same as typing /sm tracker.",
    ["Preview Title"] = "Preview",
    ["Preview Text"] = "How a quest looks on the tracker in each state, normally and while it's the quest you're tracking (left-click it on the tracker).",
    ["Preview Normal"] = "Normal",
    ["Preview Tracked"] = "Tracked",
    ["Preview To Pick Up"] = "To pick up",
    ["Preview In Progress"] = "In progress",
    ["Preview Ready"] = "Ready to turn in",
    ["Preview Locked"] = "Locked (a requirement)",
    ["Preview Dungeon Step"] = "A dungeon or raid step",
    ["Tooltip Help"] = "Show help in tooltips",
    ["Tooltip Help Text"] = "Adds what each click does (left-click, right-click, shift + left-click) at the bottom of the tracker's tooltips, the story cards' and the chapters' on the Progress track. Turn it off once you know them.",
    ["Journey Mode"] = "Journey Mode",
    ["Journey Mode Text"] = "While you're tracking a story, the standard quest tracker is hidden and only the story's next steps show on screen. Stop tracking the story, or turn this off, and the quest tracker comes back.|n|nIn combat the change waits until the fight is over.",
}

strings.esES = {
    ["Tracker Tooltip Left Click"] = "{lclick} Mostrar el camino",
    ["Tracker Tooltip Left Click Stop"] = "{lclick} Dejar de mostrar el camino",
    ["Tracker Quest To Pick Up"] = "Por recoger",
    ["Tracker Quest Ready"] = "Lista para entregar",
    ["Tracker Tooltip Right Click"] = "{rclick} Abrir la historia",
    ["Tracker Tooltip Shift Click Log"] = "{shift} + {lclick} Abrir en el registro de misiones",
    ["Tracker Tooltip Plate"] = "{lclick} Abrir la historia",
    ["Tracker Tooltip Plate Untrack"] = "{shift} + {lclick} Dejar de seguir esta historia",
    ["Tracker Tooltip Plate Journal"] = "{rclick} Ver Diario",
    ["Tracker Tooltip Heading"] = "{lclick} Plegar   {rclick} Dejar de seguir este capítulo",
    ["Tracker Node Track"] = "{shift} + {lclick} Seguir este capítulo",
    ["Tracker Node Untrack"] = "{shift} + {lclick} Dejar de seguir este capítulo",
    ["Tracker Explorer Unreached"] = "En el modo Explorador puedes seguir un capítulo cuando ya lo hayas alcanzado.",
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
    ["Settings Title"] = "Story Mode - Tracker",
    ["Settings Subtitle"] = "La historia que sigues, paso a paso, encima del seguimiento de misiones.",
    ["Show Tracker"] = "Mostrar el seguimiento",
    ["Show Tracker Text"] = "Muestra la historia que sigues encima del seguimiento de misiones. Lo mismo que escribir /sm tracker.",
    ["Preview Title"] = "Vista previa",
    ["Preview Text"] = "Cómo se ve una misión en el seguimiento en cada estado, normalmente y cuando es la misión que sigues (clic izquierdo sobre ella en el seguimiento).",
    ["Preview Normal"] = "Normal",
    ["Preview Tracked"] = "Seguida",
    ["Preview To Pick Up"] = "Por recoger",
    ["Preview In Progress"] = "En curso",
    ["Preview Ready"] = "Lista para entregar",
    ["Preview Locked"] = "Bloqueada (un requisito)",
    ["Preview Dungeon Step"] = "Un paso de mazmorra o banda",
    ["Tooltip Help"] = "Mostrar ayuda",
    ["Tooltip Help Text"] = "Añade lo que hace cada clic (clic izquierdo, clic derecho, Mayús + clic izquierdo) al final de las descripciones del seguimiento, de las tarjetas de historia y de los capítulos de la pestaña de progreso. Desactívala cuando ya te los sepas.",
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
