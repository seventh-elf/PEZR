// RainManager.as
// Contains the logic to create, track, and update rain particles.

const string RAIN_PARTICLES_VAR = "rain_particles";

// MODIFIED: Signature changed to accept a base_angle and variance.
void CreateManagedRain(CBlob@ this, int particles_per_tick, bool red_mode, float wind_speed, float base_angle = 90.0f, float angle_variance = 0.0f)
{
    CParticle@[]@ particles;
    if (!this.get(RAIN_PARTICLES_VAR, @particles))
    {
        CParticle@[] new_particles;
        @particles = new_particles;
        this.set(RAIN_PARTICLES_VAR, @particles);
    }

    Driver@ driver = getDriver();
    if (driver is null) return;
    
    CMap@ map = getMap();
    if (map is null) return;

    Vec2f screen_topleft_world = driver.getWorldPosFromScreenPos(Vec2f(0, 0));
    Vec2f screen_bottomright_world = driver.getWorldPosFromScreenPos(driver.getScreenDimensions());
    const float sky_level_y = map.tilesize * -2.0f;
    const float spawn_depth_y = 50.0f;
    float horizontal_buffer = 100.0f; 

    Vec2f spawn_topleft(screen_topleft_world.x - horizontal_buffer, sky_level_y);
    Vec2f spawn_bottomright(screen_bottomright_world.x + horizontal_buffer, sky_level_y + spawn_depth_y);
    
    SColor color = red_mode ? SColor(255, 255, 25, 0) : SColor(128, 100, 100, 200);

    for (int i = 0; i < particles_per_tick; ++i)
    {
        Vec2f pos(spawn_topleft.x + XORRandom(uint(spawn_bottomright.x - spawn_topleft.x)), spawn_topleft.y + XORRandom(uint(spawn_bottomright.y - spawn_topleft.y)));
        
        Vec2f vel;
        if (angle_variance > 0.0f)
        {
            // NEW: Unified wind direction logic for thunderstorms
            // Each particle gets a slight deviation from the shared base_angle
            float particle_angle = base_angle - (angle_variance / 2.0f) + (XORRandom(uint(angle_variance * 100)) / 100.0f);
            float speed = 5.0f + XORRandom(10) * 0.2f;
            vel = Vec2f_lengthdir_deg(speed, particle_angle);
            vel.x += wind_speed; // Add horizontal wind shear
        }
        else
        {
            // Old logic for normal rain (mostly vertical)
            float flutter = (XORRandom(100) / 100.0f) - 0.5f;
            vel = Vec2f(wind_speed + flutter, 5.0f + XORRandom(10) * 0.2f);
        }
        
        CParticle@ p = ParticlePixel(pos, vel, color, false);
        if (p !is null)
        {
            p.set_collides(true);
            p.set_diesoncollide(false);
            p.timeout = 120;
            p.slide = 0.5f;
            p.gravity = Vec2f(0.0f, 0.1f); 
            p.bounce = 0.0f; 
            particles.push_back(p);
        }
    }
}

void UpdateManagedRain(CBlob@ this)
{
    CParticle@[]@ particles;
    if (!this.get(RAIN_PARTICLES_VAR, @particles)) return;

    CMap@ map = getMap();
    if (map is null) return;

    const float kill_offset_y = 3.1f * map.tilesize;

    for (int i = particles.length - 1; i >= 0; --i)
    {
        CParticle@ p = particles[i];

        if (p is null || p.timeout <= 1)
        {
            particles.removeAt(i);
            continue;
        }

        Vec2f look_ahead_pos = p.position + Vec2f(0, kill_offset_y);
        if (map.isInWater(look_ahead_pos))
        {
            p.timeout = 1;
            continue;
        }
        
        if (p.get_resting())
        {
            SColor splash_color = p.colour;
            splash_color.setAlpha(splash_color.getAlpha() / 2);

            for (int j = 0; j < 1 + XORRandom(2); ++j)
            {
                Vec2f splash_vel(
                    (XORRandom(100) / 100.0f) - 0.5f,
                    -(XORRandom(100) / 150.0f + 0.2f)
                );

                CParticle@ splash = ParticlePixel(p.position, splash_vel, splash_color, false);
                if (splash !is null)
                {
                    splash.timeout = 5 + XORRandom(15); 
                    splash.gravity = Vec2f(0.0f, 0.2f);
                }
            }
            
            p.timeout = 1;
        }
    }
}