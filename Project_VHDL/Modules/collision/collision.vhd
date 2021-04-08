-- COLLISION
-- IN: Graphics
-- OUT: Tracker

-- The Collision module checks each frame for overlaps between the
-- bird's hitbox and any objects, and reports the type of collision
-- (if any) to the Tracker module.

-- Collision is checked by evaluating the pixels the bird's hitbox
-- overlaps, and determining the type of collision by ...
-- ... [use method below - unique rgb?]. This is encoded to a
-- simple bit vector and then sent to the Tracker.




-- NOTE: Since non-zero collision bits will be sparse, and we need
-- a relatively wide range (a discrete code for each pickup) we may
-- want to use an alternative to grid memory assignment.

-- A simpler solution would be for each collidable object to have
-- a unique rgb value, which would be checked (in addition to a one
-- bit flag to enable/disable collision checking). 
