local jukebox_default_tracks_orig = MusicManager.jukebox_default_tracks
function MusicManager:jukebox_default_tracks(...)
	local default_options = jukebox_default_tracks_orig(self, ...)
	if managers.dlc:has_armored_transport() or managers.dlc:has_soundtrack_or_cce() then
		default_options.heist_arm_for = "track_09"
	else
		default_options.heist_arm_for = "all"
	end

	return default_options
end