# tts-aos-carlscribe

An army spawner/annotator for Age of Sigmar on Tabletop Simulator, inspired by Battlescribe2TTS/Yellowscribe. Very much an unfinished work in progress.

## How to Use In-Game in TTS

The Beta of this is available at https://steamcommunity.com/sharedfiles/filedetails/?id=3344564440

1. Spawn any models you wanted to use, and make sure their names include the particular model names you'll use (e.g. "Moonclan Shoota Musician", not "Moonclan Shootas Musician"). This might become more flexible in the future.
2. Export a list to **text** from New Recruit or ListBot, and copy+paste that into the text field.
3. Click Generate. It could take a few seconds.
4. Each model spawned should have a useful name and description. If you spot any errors, let me know on Discord. The mod should also have a notepad explaining how to use the script that each model gets.

## Internal Info for My Fellow Supernerds

[Trello board to track feature progress: https://trello.com/b/km5A7YHY/carlscribe](https://trello.com/b/km5A7YHY/carlscribe)

The script uses faction data from [BSData](https://github.com/BSData/age-of-sigmar-4th). It can retrieve and parse the XML in-game, but that's really slow (TTS's lua implementation is really dumb) so I have a python script (aos-carlscribe-updater.py) & helper lua script (aos-carlscribe-preprocess.lua) that will retrieve the data and pre-process it, then append the info to the script to be more quickly used in-game. The python script (aos-carlscribe-updater.py) also assumes that you have [tts-wargaming-model-script](https://github.com/khaaarl/tts-wargaming-model-script) also cloned in a sibling directory, so that it can append that as well.

Similar to [tts-wargaming-model-script](https://github.com/khaaarl/tts-wargaming-model-script)'s updater script, the aos-carlscribe-updater.py can be conveniently used to update a save game by running `python aos-carlscribe-updater.py pathtosavegamefile.json` or dragging the save game onto it in Windows.

There are unit tests in aos-carlscribe-test.lua, which you can run on the command line: `lua aos-carlscribe-test.lua`.

There are a bunch of lua libraries checked in here for testing, coverage, profiling. This is because I'm lazy.
