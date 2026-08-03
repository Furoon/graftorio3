-- research.lua
-- Monitors technology research progress and queue
-- Tracks completed research and exports progress metrics per force

--- @class ResearchRecord
--- @field researched integer 1 if completed
--- @field name string Technology prototype name
--- @field level integer Technology level

--- Handle research completion event. Stores the last completed research per force in `storage`.
--- @param event EventData.on_research_finished
function on_research_finished(event)
	local research = event.research
	if not storage.last_research then
		--- @type table<string, ResearchRecord>
		storage.last_research = {}
	end

	local level = research.level
	-- Previous research is incorrect lvl if it has more than one research
	if level > 1 then
		level = level - 1
	end

	storage.last_research[research.force.name] = {
		researched = 1,
		name = research.name,
		level = level,
	}
end

--- Collect research queue metrics for a force. Called once per force per nth-tick.
--- Takes a LuaForce directly since the 2.1 port; the old signature took a LuaPlayer
--- and dereferenced player.force, which broke on player-less dedicated servers.
--- @param force LuaForce
--- @param event NthTickEventData
function on_research_tick(force, event)
	if event.tick then
		--- @type ResearchRecord|false
		local researched_queue = storage.last_research and storage.last_research[force.name] or false
		if researched_queue then
			gauge_research_queue:set(
				researched_queue.researched and 1 or 0,
				{ force.name, researched_queue.name, researched_queue.level, -1 }
			)
		end

		-- Levels dont get matched properly so store and save
		--- @type table<string, integer>
		local levels = {}
		for idx, tech in pairs(force.research_queue or { force.current_research }) do
			levels[tech.name] = levels[tech.name] and levels[tech.name] + 1 or tech.level
			gauge_research_queue:set(
				idx == 1 and force.research_progress or 0,
				{ force.name, tech.name, levels[tech.name], idx }
			)
		end
	end
end
