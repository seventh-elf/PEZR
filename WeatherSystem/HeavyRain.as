// HeavyRain.as
#include "RainManager.as"

void onTick(CBlob@ this)
{
    CRules@ rules = getRules();
    float wind_speed = rules.get_f32("s_current_wind");
    float synchronized_wind_angle = rules.get_f32("s_rain_wind_angle");

    CreateManagedRain(this, 50, false, wind_speed, synchronized_wind_angle, 5.0f);
    UpdateManagedRain(this);
}