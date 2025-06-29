// WeatherLights.as

// A simple data structure to hold light information
class LightInfo
{
    Vec2f pos;
    float radius;
};

// The global list key
const string g_weather_lights_list = "g_weather_lights_list";

// Any light source calls this function on tick when it's on
void AddWeatherLight(Vec2f pos, float radius)
{
    CRules@ rules = getRules();
    if (rules is null) return;

    LightInfo[]@ light_list;
    if (rules.get(g_weather_lights_list, @light_list))
    {
        LightInfo info;
        info.pos = pos;
        info.radius = radius;
        light_list.push_back(info);
    }
}