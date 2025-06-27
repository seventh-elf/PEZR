// HeavyRain.as
#include "RainManager.as"

void onTick(CBlob@ this)
{
    CRules@ rules = getRules();
    bool red_mode = false; // rules.get_bool("cl_debug_red_rain");
    float wind_speed = rules.get_f32("s_current_wind");

    CreateManagedRain(this, 50, red_mode, wind_speed);
    UpdateManagedRain(this);
}