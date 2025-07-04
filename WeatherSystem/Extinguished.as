// extinguished.as
// Custom splash logic for rain putting out fires.

#include "Hitters.as";

void Splash(CBlob@ this, const uint splash_halfwidth, const uint splash_halfheight,
            const f32 splash_offset, const bool shouldStun = true)
{
	CMap@ map = this.getMap();

	// MODIFICATION: Play a steam/sizzle sound at a lower volume
	Sound::Play("steam.ogg", this.getPosition(), 1.5f);

	if (map !is null)
	{
		bool is_server = getNet().isServer();
		Vec2f pos = this.getPosition() +
		            Vec2f(this.isFacingLeft() ?
		                  -splash_halfwidth * map.tilesize*splash_offset :
		                  splash_halfwidth * map.tilesize * splash_offset,
		                  0);

		for (int x_step = -splash_halfwidth - 2; x_step < splash_halfwidth + 2; ++x_step)
		{
			for (int y_step = -splash_halfheight - 2; y_step < splash_halfheight + 2; ++y_step)
			{
				Vec2f wpos = pos + Vec2f(x_step * map.tilesize, y_step * map.tilesize);
				Vec2f outpos;

				if (is_server)
				{
					map.server_setFireWorldspace(wpos, false);
				}

				bool random_fact = ((x_step + y_step + getGameTime() + 125678) % 7 > 3);

				if (x_step >= -splash_halfwidth && x_step < splash_halfwidth &&
				        y_step >= -splash_halfheight && y_step < splash_halfheight &&
				        (random_fact || y_step == 0 || x_step == 0))
				{
					// MODIFICATION: Create a much smaller splash effect
					map.SplashEffect(wpos, Vec2f(0, 5), 3.0f);
				}
			}
		}

		const f32 radius = Maths::Max(splash_halfwidth * map.tilesize + map.tilesize, splash_halfheight * map.tilesize + map.tilesize);
		u8 hitter = shouldStun ? Hitters::water_stun : Hitters::water;
		Vec2f offset = Vec2f(splash_halfwidth * map.tilesize + map.tilesize, splash_halfheight * map.tilesize + map.tilesize);
		Vec2f tl = pos - offset * 0.5f;
		Vec2f br = pos + offset * 0.5f;
		if (is_server)
		{
			CBlob@ ownerBlob;
			CPlayer@ damagePlayer = this.getDamageOwnerPlayer();
			if (damagePlayer !is null)
			{
				@ownerBlob = damagePlayer.getBlob();
			}

			CBlob@[] blobs;
			map.getBlobsInBox(tl, br, @blobs);
			for (uint i = 0; i < blobs.length; i++)
			{
				CBlob@ blob = blobs[i];
				bool hitHard = blob.getTeamNum() != this.getTeamNum() || ownerBlob is blob;
				Vec2f hit_blob_pos = blob.getPosition();
				f32 scale;
				Vec2f bombforce = getBombForce(this, radius, hit_blob_pos, pos, blob.getMass(), scale);
				if (shouldStun && (ownerBlob is blob || (this.isOverlapping(blob) && hitHard)))
				{
					this.server_Hit(blob, pos, bombforce, 0.0f, Hitters::water_stun_force, true);
				}
				else if (hitHard)
				{
					this.server_Hit(blob, pos, bombforce, 0.0f, hitter, true);
				}
				else
				{
					this.server_Hit(blob, pos, bombforce, 0.0f, Hitters::water, true);
				}
			}
		}
	}
}

Vec2f getBombForce(CBlob@ this, f32 radius, Vec2f hit_blob_pos, Vec2f pos, f32 hit_blob_mass, f32 &out scale)
{
	Vec2f offset = hit_blob_pos - pos;
	f32 distance = offset.Length();
	scale = (distance > (radius * 0.7)) ? 0.5f : 1.0f;
	Vec2f bombforce = offset;
	bombforce.Normalize();
	bombforce *= 2.0f;
	bombforce.y -= 0.2f;
	bombforce.x = Maths::Round(bombforce.x);
	bombforce.y = Maths::Round(bombforce.y);
	bombforce /= 2.0f;
	bombforce *= hit_blob_mass * (3.0f) * scale;
	return bombforce;
}