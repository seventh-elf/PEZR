const string s_rain_level = "s_rain_level";
const string s_state_timer = "s_state_timer";
const string s_master_rain_timer = "s_master_rain_timer";
const string s_master_clear_timer = "s_master_clear_timer";
const string s_is_forcing_down = "s_is_forcing_down";
const string s_last_rain_was_long = "s_last_rain_was_long";
const string s_extinguish_timer = "s_extinguish_timer";

const string s_thunderstorm_chance = "s_thunderstorm_chance";
const string s_thunderstorm_check_timer = "s_thunderstorm_check_timer";
const string s_thunderstorm_cooldown = "s_thunderstorm_cooldown";
const string s_rain_wind_angle = "s_rain_wind_angle";

const string ACTIVE_RAIN_LEVEL_VAR = "active_rain_level"; 
const string WAS_UNDER_COVER_VAR = "weather_was_under_cover";
const string FADE_FLAG_VAR = "weather_sound_fading";
const string FADE_START_VOL_VAR = "weather_fade_start_vol";
const string FADE_TARGET_VOL_VAR = "weather_fade_target_vol";
const string FADE_START_TIME_VAR = "weather_fade_start_time";

bool IsBlobUnderCover(CBlob@ blob, CMap@ map)
{
    if (blob is null || map is null) return true;
    const f32 SKY_Y_COORD = -5000.0f; 
    Vec2f myPos = blob.getPosition();
    float halfWidth = blob.getWidth() / 2.0f * 0.9f;
    Vec2f skyTarget(myPos.x, SKY_Y_COORD);
    if (map.rayCastSolid(myPos, skyTarget)) return true;
    skyTarget.x = myPos.x - halfWidth;
    if (map.rayCastSolid(Vec2f(myPos.x - halfWidth, myPos.y), skyTarget)) return true;
    skyTarget.x = myPos.x + halfWidth;
    if (map.rayCastSolid(Vec2f(myPos.x + halfWidth, myPos.y), skyTarget)) return true;
    return false;
}