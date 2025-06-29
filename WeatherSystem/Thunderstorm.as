// Thunderstorm.as
#include "RainManager.as"

void onTick(CBlob@ this)
{
    CRules@ rules = getRules();
    float wind_speed = rules.get_f32("s_current_wind") * 3.0f; // Tripled horizontal shear
    float synchronized_wind_angle = rules.get_f32("s_rain_wind_angle");

    // Increased particle count for intensity
    CreateManagedRain(this, 75, false, wind_speed, synchronized_wind_angle, 5.0f); 
    UpdateManagedRain(this);
}