# P2 farm atmosphere

Day birds, night crickets, rain and three original quiet music loops. WeatherEffects retains the existing wind loop so wind is never doubled. Environment uses Ambience; scores use the independent Music bus.

Recordings: Joseph SARDIN / BigSoundBank, CC0-1.0. Exact source URLs, source/output hashes, processing and peak levels: manifest.json. Original scores and rendered music are project assets with no third-party samples. License: https://creativecommons.org/publicdomain/zero/1.0/legalcode

Rebuild: `py scripts/audio/build_p2_audio.py` (numpy, ffmpeg, bundled Godot skill renderer). Cached public recordings live in the OS temporary folder.

Runtime: 3s environment fade, 5s music crossfade; the same farm timeline and debug hour as lighting. Rain reduces wildlife to 20%; wind reduces it to 55%. Music defaults to 45% and is further reduced during rain. Players belong to the world and pause/free with it.
