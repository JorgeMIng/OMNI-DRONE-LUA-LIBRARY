# OMNI-DRONE-LUA-LIBRARY

So far Sep 8, 2024: 
the VS+Tournament devs are still working on puting back the API in recent versions for MC 1.20.1. That makes it less convenient to build an omni-drone using Tournament thrusters on 1.20.1 than on 1.18.2. Until then, maybe you can still have fun in 1.18.2 :)

You should still be able to use Kontraption tho on 1.20.1.


In new VS+Kontraption versions for 1.20.1, the 'shipControllerInterface` peripheral from MC 1.18.2 was renamed to 'ShipControllerInterface` with a capital "S". Recently the devs were talking about renaming the peripheral again for the next update...

If you are trying to use the class in 1.20.2
1, please edit `lib>tilt_ship>DroneBaseClassKontraption.lua` and rename the peripheral with a capital "S" instead... or you know, you could wait for me to just add a new class specific for 1.20.1 in the next update...

Also... I haven't updated the class to work with liquid fuel multiblock thrusters yet. I'll update the class... Soon :)