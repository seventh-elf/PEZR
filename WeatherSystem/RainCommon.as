// RainCommon.as
// Contains the shared logic for creating rain particles.

void CreateRainFall(int particles_per_tick, bool red_mode)
{
    // Ensure we are on the client and have a driver to work with
    if (!isClient()) return;

    Driver@ driver = getDriver();
    if (driver is null) return;

    // Get the world coordinates of the visible screen corners.
    // This is the correct way to handle zoom, as it's independent of the camera's distance.
    Vec2f screen_topleft_world = driver.getWorldPosFromScreenPos(Vec2f(0, 0));
    Vec2f screen_bottomright_world = driver.getWorldPosFromScreenPos(driver.getScreenDimensions());

    // Define a spawn area that is slightly wider and is positioned just above the screen view.
    float horizontal_buffer = 100.0f; 
    float vertical_spawn_height = 50.0f;
    float vertical_offset = 100.0f;

    Vec2f spawn_topleft(
        screen_topleft_world.x - horizontal_buffer, 
        screen_topleft_world.y - vertical_offset - vertical_spawn_height
    );
    Vec2f spawn_bottomright(
        screen_bottomright_world.x + horizontal_buffer,
        screen_topleft_world.y - vertical_offset
    );
    
    // Set rain color
    // MODIFICATION: Normal rain is now 50% transparent (128 alpha), debug rain remains opaque (255 alpha)
    SColor color = red_mode ? SColor(255, 255, 25, 0) : SColor(128, 100, 100, 200);

    for (int i = 0; i < particles_per_tick; ++i)
    {
        // Random position within the spawn area
        Vec2f pos(
            spawn_topleft.x + XORRandom(uint(spawn_bottomright.x - spawn_topleft.x)),
            spawn_topleft.y + XORRandom(uint(spawn_bottomright.y - spawn_topleft.y))
        );

        // Downward velocity with some variation
        Vec2f vel(XORRandom(10) * 0.05f - 0.25f, 5.0f + XORRandom(10) * 0.2f);

        CParticle@ p = ParticlePixel(pos, vel, color, false);
        if (p !is null)
        {
            // Make the particle collide but not die instantly
            p.set_collides(true);
            p.set_diesoncollide(false);

            // Restore the long lifetime to ensure particles always reach the ground
            p.timeout = 120; // 4 seconds at 30TPS, should be enough for any fall distance

            // Add some slide for a more natural look on surfaces
            p.slide = 0.5f;

            // A little extra gravity to pull it down
            p.gravity = Vec2f(0.0f, 0.1f); 

            // THE KEY CHANGE: Set bounce to a very low value for a tiny splash.
            // A value of 0.1 means it will only bounce up with 10% of its impact velocity.
            p.bounce = 0.1f;
        }
    }
}