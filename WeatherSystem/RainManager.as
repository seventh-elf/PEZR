// RainManager.as
// Contains the logic to create, track, and update rain particles.

const string RAIN_PARTICLES_VAR = "rain_particles";

// This function now also adds the new particle to a managed list
void CreateManagedRain(CBlob@ this, int particles_per_tick, bool red_mode, float wind_speed)
{
    // Get or create the particle array on the blob
    CParticle@[]@ particles;
    if (!this.get(RAIN_PARTICLES_VAR, @particles))
    {
        CParticle@[] new_particles;
        @particles = new_particles;
        this.set(RAIN_PARTICLES_VAR, @particles);
    }

    Driver@ driver = getDriver();
    if (driver is null) return;
    
    // MODIFICATION: Get the map to determine a fixed sky height
    CMap@ map = getMap();
    if (map is null) return;

    // --- NEW SPAWN LOGIC ---
    // Get the screen's coordinates for HORIZONTAL bounds only.
    Vec2f screen_topleft_world = driver.getWorldPosFromScreenPos(Vec2f(0, 0));
    Vec2f screen_bottomright_world = driver.getWorldPosFromScreenPos(driver.getScreenDimensions());

    // NEW: Define a FIXED vertical spawn height, just above the top of the map (Y=0).
    // This ensures rain always comes from the sky, regardless of camera position.
    const float sky_level_y = map.tilesize * -2.0f; // Two tiles above the map boundary
    const float spawn_depth_y = 50.0f;             // How "deep" the spawn area is vertically

    float horizontal_buffer = 100.0f; 

    // Combine the camera's horizontal view with the fixed sky height.
    Vec2f spawn_topleft(
        screen_topleft_world.x - horizontal_buffer, 
        sky_level_y
    );
    Vec2f spawn_bottomright(
        screen_bottomright_world.x + horizontal_buffer,
        sky_level_y + spawn_depth_y
    );
    // --- END NEW SPAWN LOGIC ---

    SColor color = red_mode ? SColor(255, 255, 25, 0) : SColor(128, 100, 100, 200);

    for (int i = 0; i < particles_per_tick; ++i)
    {
        Vec2f pos(spawn_topleft.x + XORRandom(uint(spawn_bottomright.x - spawn_topleft.x)), spawn_topleft.y + XORRandom(uint(spawn_bottomright.y - spawn_topleft.y)));
        
        // Apply wind speed to the particle's horizontal velocity
        float flutter = (XORRandom(100) / 100.0f) - 0.5f;
        Vec2f vel(wind_speed + flutter, 5.0f + XORRandom(10) * 0.2f);
        
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

// This function checks every active particle each frame
void UpdateManagedRain(CBlob@ this)
{
    CParticle@[]@ particles;
    if (!this.get(RAIN_PARTICLES_VAR, @particles)) return; // No particles to manage

    CMap@ map = getMap();
    if (map is null) return;

    const float kill_offset_y = 3.1f * map.tilesize;

    // Loop backwards to safely remove items from the array
    for (int i = particles.length - 1; i >= 0; --i)
    {
        CParticle@ p = particles[i];

        // Cleanup: remove dead or null particles from the list
        if (p is null || p.timeout <= 1)
        {
            particles.removeAt(i);
            continue;
        }

        // --- PREDICTIVE WATER COLLISION ---
        Vec2f look_ahead_pos = p.position + Vec2f(0, kill_offset_y);
        if (map.isInWater(look_ahead_pos))
        {
            p.timeout = 1;
            continue;
        }
        
        // --- CUSTOM SPLASH LOGIC ---
        if (p.get_resting())
        {
            // Create a new, more transparent color for the splash
            SColor splash_color = p.colour;
            splash_color.setAlpha(splash_color.getAlpha() / 2); // 50% of the raindrop's transparency

            for (int j = 0; j < 1 + XORRandom(2); ++j)
            {
                // The splash velocity is NOT affected by the wind_speed variable.
                Vec2f splash_vel(
                    (XORRandom(100) / 100.0f) - 0.5f,
                    -(XORRandom(100) / 150.0f + 0.2f)
                );

                CParticle@ splash = ParticlePixel(p.position, splash_vel, splash_color, false);
                if (splash !is null)
                {
                    // Reduce lifespan to less than a second (max 20 ticks)
                    splash.timeout = 5 + XORRandom(15); 
                    splash.gravity = Vec2f(0.0f, 0.2f);
                }
            }
            
            p.timeout = 1;
        }
    }
}