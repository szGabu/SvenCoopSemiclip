# ⚠️ Not working for Sven Co-op 5.26

Newer version means broken signatures which is expected. Unfortunately, on a surprising turns of events, the developers removed DWARF information from the Linux binaries making it a gargantuan task to find the new signatures. It's gonna take a long time to find the new signatures even if it's possible at all, so this plugin will remain non-functional for the time being.

So, what are the next steps? I don't really have a lot of options but the following:

- The Sven Co-op developers restoring DWARF information. (unlikely, but even if they did it the ShouldBypassEntity() function may not exist in the code anymore)
    - A new third party module providing access to these functions. (Also unlikely and prone to breaking since the devs will not care about any sort of modding unless it relies directly on AS)
- Go back to the groupinfo method.
    - Is it working in 5.26?
    - A complete rework is needed. (Compared to the original AS script)
    - Would still like to see how to fix the unhearable sounds.
- Using the new iuser4 method
    - An initial prototype I made revealed the feature doesn't work as reported in the patch notes, clients try to pass through each other but they are pushed away by the native unstuck feature of the game.
    - Will probably be enough assuming it's working?
    - Assuming it's working, it will provide me less flexibility to work on, making the plugin more complex if I wanted to implement all the features I had in the -dev build of the plugin.
- Painstakingly keep using Ghidra to try to find the new sigs.
    - I'm using an older server binary to try to find and match patterns in the decompiled code. It's what I've been doing.
    - Unfortunately, I don't really have too much free time to keep slamming my head in my desk.

You're free to use the code of this plugin for any other project, I just ask for credit where it's due. 

Original README.md below.

---

# Sven Co-op Semiclip

Sven Co-op Semiclip is an AMXX plugin [that provides exactly what it says](https://tvtropes.org/pmwiki/pmwiki.php/Main/ExactlyWhatItSaysOnTheTin). This new version of Semiclip plugin works after all updates broke the previous methods.

### Current Problems

* Due to the great amount of engine changes Svengine suffered over the time, the older Metamod implementation broke and apparently there wasn't a way to fix it.
* anggaranothing released a [new version of Semiclip using Sven Co-op's own scripting language, AngelScript](https://gitlab.com/an-sc-projects/svencoop-as-semiclip). However, there are several problems that affect the functionality and make playing with this plugin more a hassle than an improvement:
  * This implementation uses groupinfo, making the players invisible when nearby.
  * This may also break custom maps that make use of this.
  * AngelScript doesn't have AddToFullPack, so it's actually impossible to render players using AS alone, [you could in theory "fix" this by using AMXX](https://github.com/szGabu/Sven_Semiclip_Utils). 
  * Sven Co-op made a small change that automatically unstuck colliding players, so if you try to boost someone there are high chances that you will be sent flying away.


### Solution (This plugin)

* This plugin uses Orpheu and hooks directly in the function responsible for allowing collision between entities.
AddToFullPack is also implemented, so players will not rubberband when going through each other.
* Boosting between players feels extremely smooth, almost native. Although it still a little trickier to reach higher places, because you need to jump before the player below stands up or else you'll fall through.
* It gives us more liberty on a easy to read code, it will allow us to implement more features like PVP support on maps that support it. (Which is currently a to-do!)


### Requirements

* [Orpheu](https://github.com/Arkshine/Orpheu/releases)
* [Updated Orpheu signatures for Svengine](https://github.com/szGabu/OrpheuSignatures/archive/refs/heads/Svengine.zip) (click to get the latest version of the signatures I made)


### Cvars

* **amx_semiclip_enabled**
  * Enables the plugin. Takes effect on map start. Default 1.

### Credits

* [Th3-822](https://github.com/Th3-822)
   * Helped me a lot with Orpheu and explaining me how the game works internally, and pretty much this plugin wouldn't be possible if it wasn't for him.
