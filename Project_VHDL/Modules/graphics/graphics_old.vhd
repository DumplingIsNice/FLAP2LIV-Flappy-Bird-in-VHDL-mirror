-- GRAPHICS
-- IN: Controls, GUI, Generator
-- OUT: Collision, <output_device>

-- The Graphics module composites and renders the frames to be sent
-- to the display device (via a VGA formatter).
-- It must output at 640x480 at a 25MHz pixel rate (40ns per), for a
-- refresh rate of 60 Hz. We may need to alternate between two buffers,
-- one outputting while the other is being composited.

-- The inputs are layered with the following priority (low to high):
-- [background_layer +> objects] +> bird +> UI = Output_Render
-- Where background_layer and objects are pre-packaged when sent from
-- the Generator module [1].

-- The Graphics module also tracks the position of the bird, applying
-- primitive movement transforms to it to emulate physics (including
-- falling, and impulses upwards [2]).

-- Our frame buffer updates like a shift register, controlled by the
-- inputs from the Generator module. The bird sprite and GUI elements
-- are excepted from this, as they should remain within fixed bounds,
-- and so are overlayed between reading and outputting the buffer.

-- There are two channels for modifying the buffer:
-- * Parallel Shift Register: Input must be in form 480xNx..., replacing
--      the previous data. It is for populated arrays.
--      i.e. from Generator
-- * Indexed Pixels: Input must be in the form [x, y, R, G, B, ...],
--      replaces/overwrites the previous data, and is for what would
--      otherwise be sparse arrays.
--      i.e. GUI, Bird sprite




-- [1] NOTE: The Generator module sends (in parallel) a number of pixel
-- columns to the Graphics module each frame, the number increasing
-- with speed (as the difficulty gets harder). This data holds the
-- background layer with generated objects overlayed. The collision
-- bits are also set here.


-- [2] NOTE: For physics, use a simple model based on v, a, t?
-- Constant acceleration downwards, opposed by infrequent sustained
-- impulse upwards (for smooth movement). The impulse (+a) decays
-- linearly over a set number of frames. Change in y direction is
-- proportional to velocity, a function of 'a' and 't' (frames).
-- v = a*t
-- Modularise this logic into a small component, so that the main
-- Graphics module only handles the x,y to render the bird sprite to.
