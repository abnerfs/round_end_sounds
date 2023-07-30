# Round End Sounds

![Downloads](https://img.shields.io/github/downloads/abnerfs/round_end_sounds/total) ![Last commit](https://img.shields.io/github/last-commit/abnerfs/round_end_sounds "Last commit") ![Open issues](https://img.shields.io/github/issues/abnerfs/round_end_sounds "Open Issues") ![Closed issues](https://img.shields.io/github/issues-closed/abnerfs/round_end_sounds "Closed Issues") ![Size](https://img.shields.io/github/repo-size/abnerfs/dontpad-api "Size")

Play songs when the round ends!

- CSS/CS:GO support.
- Sounds are loaded automatically from the specified folders.
- Supports both mp3 and wav files.
- Default CSGO round end sound is stopped.
- Map custom musics are stopped to prevent playing two sounds together. 
- Type !res to choose if you want to listen the sounds and to set the volume

# Cvars
Cvars can be found in [cfg/sourcemod/abner_res.cfg]
- res_tr_path - Path of sounds played when Ts wins.
- res_ct_path - Path of sounds played when CTs wins.
- res_draw_path - Path of sounds played when the round draws: 0 - No sounds, 1 - T sounds, 2 - CT sounds.
- res_play_type - 1 - Random, 2 - Play in order.
- res_stop_map_music - Stop map music.
- res_print_to_chat_sound_name - Print sound name in chat (requires setting up configs/abner_res.txt).
- res_default_volume - Default volume.
- res_play_to_the_end - Play sounds to the end ignoring mp_round_restart_delay (requires soundlib).

# Music format
- CSGO/CSS is able to play sounds with the maximum of 44100hz of sample rate, it supports both mp3 and wav files.
  

# Admin Commands
- !res_refresh - Refresh sounds


# Commands
- !res - Open config menu
