// WeatherSystem.as
// Main controller for the weather system.
// Attaches to CRules to run globally.

#include "Timers.as";
#include "extinguished.as"; 
#include "Hitters.as";     

// State variables stored on CRules for persistence and sync
const string s_rain_level = "s_rain_level";
const string s_state_timer = "s_state_timer";
const string s_master_rain_timer = "s_master_rain_timer";
const string s_master_clear_timer = "s_master_clear_timer";
const string s_is_forcing_down = "s_is_forcing_down";
const string s_last_rain_was_long = "s_last_rain_was_long";
const string s_extinguish_timer = "s_extinguish_timer";

// Client-side state tracking
const string ACTIVE_RAIN_LEVEL_VAR = "active_rain_level"; 
const string WAS_UNDER_COVER_VAR = "weather_was_under_cover";
const string FADE_FLAG_VAR = "weather_sound_fading";
const string FADE_START_VOL_VAR = "weather_fade_start_vol";
const string FADE_TARGET_VOL_VAR = "weather_fade_target_vol";
const string FADE_START_TIME_VAR = "weather_fade_start_time";


// NEW, ROBUST FUNCTION to check if a blob is under cover.
// This casts three rays (left, center, right) to a very high point in the sky
// to ensure accuracy even at the edges of blocks.
bool IsBlobUnderCover(CBlob@ blob, CMap@ map)
{
    if (blob is null || map is null) return true; // Assume cover if something is wrong

    // A Y-coordinate guaranteed to be above the map. 500 tiles * 8 pixels/tile = 4000.
    // We use a negative value since Y increases downwards.
    const f32 SKY_Y_COORD = -5000.0f; 

    Vec2f myPos = blob.getPosition();
    float halfWidth = blob.getWidth() / 2.0f * 0.9f; // 90% of half-width for a slight inset

    // The point in the sky we are casting to.
    Vec2f skyTarget(myPos.x, SKY_Y_COORD);

    // 1. Center Raycast
    if (map.rayCastSolid(myPos, skyTarget)) return true;
    
    // 2. Left Raycast
    skyTarget.x = myPos.x - halfWidth;
    if (map.rayCastSolid(Vec2f(myPos.x - halfWidth, myPos.y), skyTarget)) return true;

    // 3. Right Raycast
    skyTarget.x = myPos.x + halfWidth;
    if (map.rayCastSolid(Vec2f(myPos.x + halfWidth, myPos.y), skyTarget)) return true;

    // If none of the rays hit anything, the blob is exposed.
    return false;
}


void onInit(CRules@ this)
{
    if (isServer())
    {
        if (!this.exists(s_rain_level))
        {
            this.set_u8(s_rain_level, 0);
            this.set_u32(s_state_timer, 0);
            this.set_u32(s_master_rain_timer, 0);
            this.set_u32(s_master_clear_timer, 0);
            this.set_bool(s_is_forcing_down, false);
            this.set_bool(s_last_rain_was_long, false);
            this.set_u32(s_extinguish_timer, 0);
        }
    }
}

void ChangeRainLevel(CRules@ this, int newLevel)
{
    if (!isServer()) return;
    newLevel = Maths::Clamp(newLevel, 0, 3);
    u8 oldLevel = this.get_u8(s_rain_level);
    if (newLevel == oldLevel) return;
    print("Weather: Changing rain level from " + oldLevel + " to " + newLevel);
    this.set_u8(s_rain_level, newLevel);
    this.set_u32(s_state_timer, 0);
    if (oldLevel == 0 && newLevel > 0) {
        this.set_u32(s_master_rain_timer, 0);
        this.set_u32(s_master_clear_timer, 0);
        this.set_bool(s_last_rain_was_long, false);
    } else if (newLevel == 0 && oldLevel > 0) {
        if (this.get_bool(s_is_forcing_down)) {
            this.set_bool(s_last_rain_was_long, true);
            this.Sync(s_last_rain_was_long, true);
        }
        this.set_bool(s_is_forcing_down, false);
        this.set_u32(s_master_rain_timer, 0);
        this.set_u32(s_master_clear_timer, 0);
    }
    this.Sync(s_rain_level, true);
    this.Sync(s_is_forcing_down, true);
}

void onTick(CRules@ this)
{
    // Server handles all logic
    if (isServer())
    {
        u8 currentLevel = this.get_u8(s_rain_level);
        this.add_u32(s_extinguish_timer, 1);

        // Run checks every 10 ticks
        if (this.get_u32(s_extinguish_timer) > 10)
        {
            this.set_u32(s_extinguish_timer, 0);
            CMap@ map = getMap();

            // Fire extinguishing logic
            if (currentLevel >= 2)
            {
                CBlob@[] blobs;
                if (getBlobs(blobs))
                {
                    for (uint i = 0; i < blobs.length; i++)
                    {
                        CBlob@ b = blobs[i];
                        if (b !is null && b.isFlammable() && b.isInFlames())
                        {
                            // Use our new cover check for server-side logic too!
                            if (!IsBlobUnderCover(b, map))
                            {
                                CBlob@ splasher = server_CreateBlob("arrow", -1, b.getPosition());
                                if (splasher !is null)
                                {
                                    Splash(splasher, 2, 2, 0.0f, false);
                                    splasher.server_Die();
                                }
                            }
                        }
                    }
                }
            }

            // Wraith de-enraging logic
            if (currentLevel == 3)
            {
                CBlob@[] wraiths;
                if (getBlobsByName("wraith", wraiths))
                {
                    for (uint i = 0; i < wraiths.length; i++)
                    {
                        CBlob@ wraith = wraiths[i];
                        if (wraith.hasTag("exploding"))
                        {
                            if (!IsBlobUnderCover(wraith, map))
                            {
                                wraith.server_Hit(wraith, wraith.getPosition(), Vec2f(0,0), 0.0f, Hitters::water, true);
                            }
                        }
                    }
                }
            }
        }
        
        // --- WEATHER STATE CHANGE LOGIC ---
        // ... (This section is unchanged)
        if (currentLevel > 0) { this.add_u32(s_master_rain_timer, 1); }
        else { this.add_u32(s_master_clear_timer, 1); }
        this.add_u32(s_state_timer, 1);
        bool isForcingDown = this.get_bool(s_is_forcing_down);
        if (isForcingDown) {
            if (this.get_u32(s_state_timer) > 2 * 60 * getTicksASecond()) {
                ChangeRainLevel(this, currentLevel - 1);
            }
            return;
        }
        if (currentLevel > 0) {
            u32 masterRainTimer = this.get_u32(s_master_rain_timer);
            if (masterRainTimer > 30 * 60 * getTicksASecond()) {
                print("Weather: 30 minute rain limit reached.");
                this.set_bool(s_is_forcing_down, true);
                ChangeRainLevel(this, currentLevel - 1);
                return;
            }
            if (this.get_u32(s_state_timer) > (XORRandom(60) + 30) * getTicksASecond()) {
                int roll = XORRandom(100);
                int nextLevel = currentLevel;
                if (currentLevel == 1) { if (roll < 30) nextLevel++; else if (roll < 50) nextLevel--; }
                else if (currentLevel == 2) { if (roll < 30) nextLevel++; else if (roll < 60) nextLevel--; }
                else if (currentLevel == 3) { if (roll < 40) nextLevel--; }
                if (nextLevel == 0 && masterRainTimer < 10 * 60 * getTicksASecond()) {
                    nextLevel = 1; print("Weather: Vetoing rain stop, min duration not met.");
                }
                if (nextLevel != currentLevel) { ChangeRainLevel(this, nextLevel); }
                else { this.set_u32(s_state_timer, 0); }
            }
        } else {
            u32 masterClearTimer = this.get_u32(s_master_clear_timer);
            bool lastRainWasLong = this.get_bool(s_last_rain_was_long);
            uint minClearTimeTicks = (lastRainWasLong ? 15 : 5) * 60 * getTicksASecond();
            uint maxClearTimeTicks = 60 * 60 * getTicksASecond();
            if (masterClearTimer > maxClearTimeTicks) {
                print("Weather: Max clear time reached.");
                ChangeRainLevel(this, 1); return;
            }
            if (masterClearTimer > minClearTimeTicks) {
                if (this.get_u32(s_state_timer) > (XORRandom(60) + 30) * getTicksASecond()) {
                    if (XORRandom(100) < 15) { ChangeRainLevel(this, 1); }
                    else { this.set_u32(s_state_timer, 0); }
                }
            }
        }
    }

    // Client handles the visual effects and sounds
    if (isClient())
    {
        CBlob@ blob = getLocalPlayerBlob();
        if (blob is null) return;
        CSprite@ sprite = blob.getSprite();
        if (sprite is null) return;
        CMap@ map = getMap();
        if (map is null) return;
        u8 desiredLevel = this.get_u8(s_rain_level);

        // MODIFIED: Use the new, more reliable cover check
        bool isUnderCover = IsBlobUnderCover(blob, map);

        u8 activeLevel = blob.exists(ACTIVE_RAIN_LEVEL_VAR) ? blob.get_u8(ACTIVE_RAIN_LEVEL_VAR) : 0;
        bool wasUnderCover = blob.get_bool(WAS_UNDER_COVER_VAR);

        if (desiredLevel != activeLevel || isUnderCover != wasUnderCover) 
        {
            if (desiredLevel != activeLevel) 
            {
                blob.RemoveScript("LightRain.as");
                blob.RemoveScript("ModerateRain.as");
                blob.RemoveScript("HeavyRain.as");
                if (desiredLevel == 1) blob.AddScript("LightRain.as");
                else if (desiredLevel == 2) blob.AddScript("ModerateRain.as");
                else if (desiredLevel == 3) blob.AddScript("HeavyRain.as");
            }
            float target_volume = 0.0f;
            if (desiredLevel == 1) target_volume = 0.25f;
            else if (desiredLevel == 2) target_volume = 0.50f;
            else if (desiredLevel == 3) target_volume = 0.80f;

            if (isUnderCover) { target_volume *= 0.3f; }

            if (desiredLevel > 0 && activeLevel == 0) { sprite.SetEmitSound("Sounds/Rain.ogg"); }
            sprite.SetEmitSoundPaused(false);
            
            blob.set_bool(FADE_FLAG_VAR, true);
            blob.set_f32(FADE_START_VOL_VAR, sprite.getEmitSoundVolume());
            blob.set_f32(FADE_TARGET_VOL_VAR, target_volume);
            blob.set_u32(FADE_START_TIME_VAR, getGameTime());
            
            blob.set_u8(ACTIVE_RAIN_LEVEL_VAR, desiredLevel);
            blob.set_bool(WAS_UNDER_COVER_VAR, isUnderCover);
        }

        if (blob.get_bool(FADE_FLAG_VAR)) 
        {
            // ... (Fading logic is unchanged)
            float start_vol = blob.get_f32(FADE_START_VOL_VAR);
            float target_vol = blob.get_f32(FADE_TARGET_VOL_VAR);
            u32 start_time = blob.get_u32(FADE_START_TIME_VAR);
            const float fade_duration_ticks = 5.0f * getTicksASecond();
            float elapsed_ticks = float(getGameTime() - start_time);
            float progress = Maths::Clamp01(elapsed_ticks / fade_duration_ticks);
            float new_volume = Maths::Lerp(start_vol, target_vol, progress);
            sprite.SetEmitSoundVolume(new_volume);
            if (progress >= 1.0f) {
                blob.set_bool(FADE_FLAG_VAR, false);
                if (target_vol <= 0.0f) {
                    sprite.SetEmitSoundPaused(true);
                }
            }
        }
    }
}

// These functions are empty because the debug menu was removed
void onRender(CRules@ this) {}
void onCommand(CRules@ this, u8 cmd, CBitStream@ params) {}