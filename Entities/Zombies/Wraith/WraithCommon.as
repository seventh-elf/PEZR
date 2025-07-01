﻿#include "WeatherCommon.as";

const u8 TIME_TO_EXPLODE = 5; //seconds
const s32 TIME_TO_ENRAGE = 45 * 30;

void server_SetEnraged(CBlob@ this, const bool&in enrage = true, const bool&in stun = true, const bool&in water_check = true)
{
	if (!isServer()) return;

	const bool inWater = water_check && this.isInWater();
	if (enrage && (this.hasTag("exploding") || inWater)) return;

	if (rainPutOut(this, enrage)) return;

	this.set_bool("exploding", enrage);

	this.server_SetTimeToDie(enrage ? TIME_TO_EXPLODE : -1);

	if (!enrage && stun)
	{
		this.getBrain().SetTarget(null);
		this.set_u8("brain_delay", 250); //do a fake stun

		this.setKeyPressed(key_left, false);
		this.setKeyPressed(key_right, false);
		this.setKeyPressed(key_up, false);
		this.setKeyPressed(key_down, false);
	}

	//why the fuck does kag need light on server to work. fuckers
	this.SetLight(enrage);
	this.SetLightRadius(this.get_f32("explosive_radius") * 0.5f);
	this.SetLightColor(SColor(255, 211, 121, 224));

	CBitStream params;
	params.write_bool(enrage);
	params.write_bool(stun);
	this.SendCommand(this.getCommandID("enrage_client"), params);
}

int getWeatherLevel()
{
	CRules@ rules = getRules();

	if (rules is null) return 0;

	return rules.get_u8(s_rain_level);
}

bool rainPutOut(CBlob@ this, const bool &in enrage)
{
	if (!enrage) return false;
	if (getWeatherLevel() < 3) return false;
	if (IsBlobUnderCover(this, getMap())) return false;

	return true;
}
