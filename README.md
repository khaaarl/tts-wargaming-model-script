# tts-wargaming-model-script

A script to use on models in wargaming on Tabletop Simulator. It is a collection of features from elsewhere (primarily stolen from Yellowscribe), plus a few new ones.

There is also an updater python script to propagate updates to models in your save games that have older versions of this script.

## Usage in-game

If the script is attached to a model, you get the following features:

1. Numpad 2/3 while hovering will decrement/increment health on a model if its name is formatted with number/number. For example, if your model is named "3/3 Space Marine", hitting Numpad 2 while hovering over him will change his name to "2/3 Space Marine".
    1. To handle Age of Sigmar's damage counter mechanism, you should instead count up. If a unit has all its models' names first lines start with "number/number [any bbcode] ..." like "0/2 [B2E3FF][i]Xar'tep's Warped Initiates[/i][-]", and the model's description has the M H C S stats of AoS, the script will infer that all models whose names start the same are in the same unit, so will receive the same damage count.
2. Numpad 4/5/6/7/8/9 deal with aura rings.
    1. 4/5 will alter the radius of the aura, in inches.
    2. 6/7 will change the base size, in case the auto-detected base size was incorrect.
    3. 8 will change back and forth from rectangular measuring, useful for models not on round/oval bases but instead are more boxy, like a lot of transport vehicles.
    4. 9 will cycle through colors.
3. Stabilization can be enabled by including "STABILIZEME" anywhere in the model's description. If you don't want it to show when hovering, consider placing it in bbcode color tag with zero alpha, like "[00000000]STABILIZEME[-]".
4. Hovering Counters can be added to a model by including counter info in the description.
    1. Each should look like "COUNTER:Noble Deeds, 77bb77, 0, 6" where "Noble Deeds" will be the name/label of the counter, "77bb77" is any hexadecimal color, 0 is the minimum, and 6 is the maximum. Only the name/label is required; the others are optional. You may include multiple counters if desired.
    2. Optionally, add "BUTTON_OFFSET=4.5" in the description somewhere to indicate the height of the hovering counters in inches (4.5 inches in this example).
    3. After changing the model's description, pick it up and drop it to trigger the code reevaluation of your description.
    4. Left-clicking and right-clicking on a counter will cause its number to go up or down, bounded by the specified minimum and maximum.

## Usage of the updater python script

1. Install Python if you haven't already.
2. Download this repo to your computer somewhere.
3. Drag a save file or save folder onto `tts_wargaming_model_script_updater.py`. You should see a window with text in it, it should work for a while, then tell you to press enter to exit.

This will search through the file(s)/folder(s) for save files that contain older versions of the script attached to models, and replace them with the script currently in this repo as you have downloaded it.
 
