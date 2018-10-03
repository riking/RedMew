--[[-- info
    Provides the ability to collapse caves when digging.
]]

-- dependencies
require 'utils.list_utils'

local Event = require 'utils.event'
local Template = require 'map_gen.Diggy.Template'
local Mask = require 'map_gen.Diggy.Mask'
local StressMap = require 'map_gen.Diggy.StressMap'
local Debug = require'map_gen.Diggy.Debug'
local Task = require 'utils.Task'
local Token = require 'utils.global_token'

-- this
local DiggyCaveCollapse = {}

local config = {}

DiggyCaveCollapse.events = {
    --[[--
        When stress at certain position is above the collapse threshold
         - position LuaPosition
         - surface LuaSurface
    ]]
    on_collapse_triggered = script.generate_event_name()
}

local function create_collapse_template(positions, surface)
    local entities = {}
    local tiles = {}
    for _, position in pairs(positions) do
        table.insert(entities, {position = {x = position.x, y = position.y - 1}, name = 'sand-rock-big'})
        table.insert(entities, {position = {x = position.x + 1, y = position.y}, name = 'sand-rock-big'})
        table.insert(entities, {position = {x = position.x, y = position.y + 1}, name = 'sand-rock-big'})
        table.insert(entities, {position = {x = position.x - 1, y = position.y}, name = 'sand-rock-big'})
        table.insert(tiles, {position = {x = position.x, y = position.y}, name = 'out-of-map'})
    end
    for _, new_spawn in pairs({entities, tiles}) do
        for _, tile in pairs(new_spawn) do
            for _, entity in pairs(surface.find_entities_filtered({position = tile.position})) do
                pcall(function() entity.die() end)
                pcall(function() entity.destroy() end)
            end
        end
    end
    for key,entity in pairs(entities) do
        if not entity.valid then
            entities[key] = nil
        end
    end
    return tiles, entities
end

--[[--
    @param surface LuaSurface
    @param position Position with x and y
    @param strength positive increases stress, negative decreases stress
]]
local function update_stress_map(surface, position, strength)
    local max_value
    Mask.disc_blur(position.x, position.y, strength, function (x, y, fraction)
        max_value = max_value or StressMap.add(surface, {x = x, y = y}, fraction)
    end)

    if max_value then
        script.raise_event(DiggyCaveCollapse.events.on_collapse_triggered, {surface = surface, position = position})
    end
end

local function collapse(surface, position)
    local positions = {}

    Mask.disc_blur(position.x, position.y, config.collapse_threshold_total_strength, function(x, y, value)
        StressMap.check_stress_in_threshold(surface, {x = x, y = y}, value, function(_, position)
            table.insert(positions, position)
        end)

    end)
    local tiles, entities = create_collapse_template(positions, surface)
    Template.insert(surface, tiles, entities)
end

local on_collapse_timeout_finished = Token.register(function(params)
    collapse(params.surface, params.position)
end)


function spawn_cracking_sound_text(surface, position)
    local text = config.cracking_sounds[math.random(1, #config.cracking_sounds)]

    local color = {
        r = 1,
        g = math.random(1, 100) / 100,
        b = 0
    }

    for i = 1, #text do
      local x_offset = (i - #text / 2 - 1) / 3
      local char = text:sub(i, i)
      surface.create_entity{
          name = 'flying-text',
          color = color,
          text = char ,
          position = {x = position.x +  x_offset, y = position.y - ((i + 1) % 2) / 4}
      }.active = true
    end
end

--[[--
    Registers all event handlers.]

    @param global_config Table {@see Diggy.Config}.
]]
function DiggyCaveCollapse.register(global_config)
    config = global_config.features.DiggyCaveCollapse
    local support_beam_entities = config.support_beam_entities;

    if (config.enable_stress_grid) then
        Event.add(StressMap.events.on_stress_changed, function(event)
            Debug.print_grid_value(event.value, event.surface, event.position)
        end)
    end

    Event.add(DiggyCaveCollapse.events.on_collapse_triggered, function(event)
        spawn_cracking_sound_text(event.surface, event.position)

        Task.set_timeout(
            math.random(config.collapse_delay_min * 10, config.collapse_delay_max * 10) / 10,
            on_collapse_timeout_finished,
            {surface = event.surface, position = event.position}
        )
    end)

    Event.add(defines.events.on_robot_built_entity, function(event)
        local strength = support_beam_entities[event.created_entity.name]

        if (not strength) then
            return
        end

        update_stress_map(event.created_entity.surface, event.created_entity.position, -1 * strength)
    end)

    Event.add(defines.events.on_robot_built_tile, function(event)
        local strength = support_beam_entities[event.item.name]

        if (not strength) then
            return
        end

        for _, tile in pairs(event.tiles) do
            update_stress_map(event.robot.surface, tile.position, -1 * strength)
        end
    end)

    Event.add(defines.events.on_player_built_tile, function(event)
        local strength = support_beam_entities[event.item.name]

        if (not strength) then
            return
        end
        local surface = game.surfaces[event.surface_index]
        for _, tile in pairs(event.tiles) do
            update_stress_map(surface, tile.position, -1 * strength)
        end
    end)

    Event.add(defines.events.on_robot_mined_tile, function(event)
        for _, tile in pairs(event.tiles) do
            local strength = support_beam_entities[tile.old_tile.name]

            if (strength) then
                update_stress_map(event.robot.surface, tile.position, strength)
            end
        end
    end)

    Event.add(defines.events.on_player_mined_tile, function(event)
        local surface = game.surfaces[event.surface_index]
        for _, tile in pairs(event.tiles) do
            local strength = support_beam_entities[tile.old_tile.name]

            if (strength) then
                update_stress_map(surface, tile.position, strength)
            end
        end
    end)

    Event.add(defines.events.on_robot_mined_entity, function(event)
        local strength = support_beam_entities[event.entity.name]

        if (not strength) then
            return
        end

        update_stress_map(event.entity.surface, event.entity.position, strength)
    end)

    Event.add(defines.events.on_built_entity, function(event)
        local strength = support_beam_entities[event.created_entity.name]

        if (not strength) then
            return
        end

        update_stress_map(event.created_entity.surface, event.created_entity.position, -1 * strength)
    end)

    Event.add(Template.events.on_placed_entity, function(event)
        local strength = support_beam_entities[event.entity.name]

        if (not strength) then
            return
        end

        update_stress_map(event.entity.surface, event.entity.position, -1 * strength)
    end)

    Event.add(defines.events.on_entity_died, function(event)
        local strength = support_beam_entities[event.entity.name]

        if (not strength) then
            return
        end

        update_stress_map(event.entity.surface, event.entity.position, strength)
    end)

    Event.add(defines.events.on_player_mined_entity, function(event)
        local strength = support_beam_entities[event.entity.name]

        if (not strength) then
            return
        end

        update_stress_map(event.entity.surface, event.entity.position, strength)
    end)

    Event.add(Template.events.on_void_removed, function(event)
        local strength = support_beam_entities['out-of-map']

        update_stress_map(event.surface, event.old_tile.position, strength)
    end)

    Event.add(Template.events.on_void_added, function(event)
        local strength = support_beam_entities['out-of-map']

        update_stress_map(event.surface, event.old_tile.position, -1  * strength)
    end)
end

--[[--
    Initializes the Feature.

    @param config Table {@see Diggy.Config}.
]]
function DiggyCaveCollapse.initialize(global_config)
    config = global_config.features.DiggyCaveCollapse

    Mask.init(config)
    if (config.enable_mask_debug) then
        local surface = game.surfaces.nauvis
        Mask.disc_blur(0, 0, 10, function (x, y, fraction)
            Debug.print_grid_value(fraction, surface, {x=x, y=y})
        end)
    end
end

return DiggyCaveCollapse
