"""Arcade's BoxVehicle.emit draws a part's rear face only when pz0 >= z_lo, with pz0 = (z + length/2) + z0 (doubles) and
z_lo = the rear z of the bucket (= z). Checks for which rear positions the round trip loses the face."""
cam_z = 191.0
for name, length, z0 in [('bus 12.8 m', 12.8, -6.4), ('truck 16.5 m', 16.5, -8.25)]:
    for d in [20.3, 30.5, 60.3, 62.0, 150.3, 45.0, 110.0]:
        z = cam_z + d
        zc = z + length * 0.5
        pz0 = zc + z0
        print('%-13s d=%6.1f  z=%r  pz0=%r  Heck gezeichnet: %s' % (name, d, z, pz0, pz0 >= z))
    lost = 0
    n = 0
    z = 100.0
    while z < 5000.0:
        if (z + length * 0.5) + z0 < z:
            lost += 1
        n += 1
        z += 0.0173
    print('%s: Heckfläche verloren bei %d von %d Positionen (%.1f %%)' % (name, lost, n, 100.0 * lost / n))
