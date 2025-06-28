// Game Music

#define CLIENT_ONLY

// A global variable to remember what kind of music is currently playing.
// We initialize it to -1 to signify "no state yet".
int currentMusicState = -1;

enum GameMusicTags
{
	world_ambient,
	world_ambient_underground,
	world_ambient_mountain,
	world_ambient_night,
	world_custom_combat, 
	world_custom_peaceful, 
	world_intro,
	world_home,
	world_calm,
	world_battle,
	world_battle_2,
	world_outro,
	world_quick_out,
};

void onInit(CRules@ this)
{
	CMixer@ mixer = getMixer();
	if (mixer is null) return;
	
	AddGameMusic(this, mixer);
}

// Add an onRestart function to reset our state tracker between rounds.
void onRestart(CRules@ this)
{
    currentMusicState = -1;
}

void onTick(CRules@ this)
{
	// This check makes the logic run less frequently to save performance. It's good to keep.
	if (getGameTime() % 90 != 0) return;

	CMixer@ mixer = getMixer();
	if (mixer is null) return;

	GameMusicLogic(this, mixer);
}

//sound references with tag
void AddGameMusic(CRules@ this, CMixer@ mixer)
{
	mixer.ResetMixer();
	
	// Combat songs
	mixer.AddTrack("Soundtrack/combat/Craftsdwarfship.ogg", world_custom_combat);
	mixer.AddTrack("Soundtrack/combat/DeathSpiral.ogg", world_custom_combat);
	mixer.AddTrack("Soundtrack/combat/DrinkAndIndustry.ogg", world_custom_combat);
	mixer.AddTrack("Soundtrack/combat/ExpansiveCavern.ogg", world_custom_combat);
	mixer.AddTrack("Soundtrack/combat/FirstYear.ogg", world_custom_combat);
	mixer.AddTrack("Soundtrack/combat/ForgottenBeast.ogg", world_custom_combat);
	mixer.AddTrack("Soundtrack/combat/Koganusan.ogg", world_custom_combat);
	mixer.AddTrack("Soundtrack/combat/StrangeMoods.ogg", world_custom_combat);
	mixer.AddTrack("Soundtrack/combat/VileForceOfDarkness.ogg", world_custom_combat);
	// Peaceful songs
	mixer.AddTrack("Soundtrack/peaceful/AnotherYear.ogg", world_custom_peaceful);
	mixer.AddTrack("Soundtrack/peaceful/HillDwarf.ogg", world_custom_peaceful);
	mixer.AddTrack("Soundtrack/peaceful/Mountainhome.ogg", world_custom_peaceful);
	mixer.AddTrack("Soundtrack/peaceful/StrikeTheEarth.ogg", world_custom_peaceful);
	mixer.AddTrack("Soundtrack/peaceful/WinterEntombsYou.ogg", world_custom_peaceful);
}

void GameMusicLogic(CRules@ this, CMixer@ mixer)
{
	CMap@ map = getMap();
	if (map is null) return;

	CBlob@ blob = getLocalPlayerBlob();
	if (blob is null)
	{
		mixer.FadeOutAll(0.0f, 6.0f);
		return;
	}
	
	// Get game state variables
	const u16 undead_count = this.get_u16("undead count");
	
	// --- NEW STATE-AWARE MUSIC LOGIC ---

	// 1. Determine what the music SHOULD be right now.
	int desiredMusicState;
	if (undead_count > 8)
	{
		desiredMusicState = world_custom_combat;
	}
	else
	{
		desiredMusicState = world_custom_peaceful;
	}

	// 2. Check if the desired state is DIFFERENT from the current state.
	if (desiredMusicState != currentMusicState)
	{
		// A TRANSITION is happening!
		print("Music state changing from " + currentMusicState + " to " + desiredMusicState);

		if (desiredMusicState == world_custom_peaceful)
		{
			// --- THIS IS YOUR REQUESTED CHANGE ---
			// We are going from COMBAT to PEACEFUL.
			changeMusic(mixer, world_custom_peaceful, 5.0f, 5.0f);
		}
		else // This means desiredMusicState is world_custom_combat
		{
			// We are going from PEACEFUL to COMBAT.
			changeMusic(mixer, world_custom_combat, 2.0f, 3.0f);
		}
		
		// 3. Update the tracker to remember the new state for the next check.
		currentMusicState = desiredMusicState;
	}
	else
	{
		// NO state change. This is a "sustained" state.
		// This block handles starting a new song if the previous one finished.
		if (currentMusicState == world_custom_combat)
		{
			// Sustain combat music with fast fades between tracks.
			changeMusic(mixer, world_custom_combat, 3.0f, 3.0f);
		}
		else if (currentMusicState == world_custom_peaceful)
		{
			// Sustain peaceful music with slow fades between tracks.
			changeMusic(mixer, world_custom_peaceful, 5.0f, 5.0f);
		}
	}
}

// This helper function is perfect as-is.
void changeMusic(CMixer@ mixer, int nextTrack, f32 fadeoutTime = 1.6f, f32 fadeinTime = 1.6f)
{
	if (!mixer.isPlaying(nextTrack))
	{
		mixer.FadeOutAll(0.0f, fadeoutTime);
	}

	mixer.FadeInRandom(nextTrack, fadeinTime);
}