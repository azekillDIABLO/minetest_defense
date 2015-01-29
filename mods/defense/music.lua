defense.music = {}
local music = defense.music
music.loop_length = 6.0 - 0.1

-- State tracking stuff
local current_level = 0
local current_music = nil
local last_intensity = 0
local last_update_time = 0

function music:update()
	local time = os.time()
	if current_level > 0 then
		if time < last_update_time + music.loop_length then
			return
		end
	end
	last_update_time = time

	local intensity = defense.director.intensity
	if not defense:is_dark() then
		intensity = intensity * 0.1
	end
	last_intensity = intensity
	intensity = intensity + (intensity - last_intensity) * 3

	local il = {0.1, 0.5, 0.8, 0.99}
	local last_level = current_level
	if intensity <= il[1] then
		if current_level > 0 then
			current_level = current_level - 1
		end
	elseif intensity > il[1] and intensity <= il[2] then
		if current_level > 1 then
			current_level = current_level - 1
		elseif current_level < 1 then
			current_level = current_level + 1
		end
	elseif intensity > il[2] and intensity <= il[3] then
		if current_level > 2 then
			current_level = current_level - 1
		elseif current_level < 2 then
			current_level = current_level + 1
		end
	elseif intensity > il[3] and intensity <= il[4] then
		if current_level > 3 then
			current_level = current_level - 1
		elseif current_level < 3 then
			current_level = current_level + 1
		end
	elseif intensity > il[4] then
		if current_level < 4 then
			current_level = current_level + 1
		end
	end

	if last_level ~= current_level then
		if defense.debug then
			minetest.chat_send_all("Level: " .. current_level)
		end
		minetest.sound_play("defense_music_transit", {
			gain = 0.1 + last_level * 0.1
		})
		if current_music then
			minetest.sound_stop(current_music)
		end
		if current_level > 0 then
			current_music = minetest.sound_play("defense_music_level" .. current_level, {
				pos = nil,
				gain = 0.1 + current_level * 0.2,
				loop = true,
			})
		end
	end
end

minetest.register_globalstep(function(dtime)
	music:update()
end)