# Mystery House (Remodeled)
A ground-up recreation, for the Pico-8, of the public domain classic that the first graphic adventure game.

# The Goal
The intention of this project is to recreate the original game, including all known bugs, for the Pico-8. It seems that the original source code has long since been lost, so I consider this a kind of continuation of the archaelogical detective work done by J. Aycock and K. Biittner in their research essay "Inspecting the Foundation of Mystery House". The output posted to Aycock's GitHub at https://github.com/aycock/mh proved immensely helpful.

## Overcoming Limitations
Basically I wanted to take a system with harsh limitations, in this case the Pico-8, and try to put myself in the mindset of the original creators. Why did they make the decisions they did? Why do certain classes of bugs exist? What would I have done differently and why? I also wanted the challenge of fitting the entire 140K original into 64K. There are various conversations within the Pico-8 community about making graphic adventure games, and it seemed to me that the best approach to solving the "could it be done" question that arises again and again was to just start at the beginning. "If an Apple 2 could do it, surely a Pico-8 could also do it," I mused. Eventually this musing turned into stubbornness and this project was born.

## Versawriter and Versawriter-8
Recreating the game meant, to my way of thinking, recreating the process of construction as well. To this end, all graphics in this version are uniquely hand-drawn using a technique somewhat similar to the original work done by Ken and Roberta Williams. They used a device called a Versawriter for the Apple 2 which allowed them to trace their paper drawings into plot points for a kind of "vector" style graphics. This allowed them to squeeze a lot of high-res images into a small 140K floppy disk, which was a unique solution to overcoming a hard technical limit of the system. Wanting to do something similar for the Pico-8 was the driving force behind the entire project. Basically, I created Mystery House *because* I wanted to create Versawriter-8.

I have created a companion application for this project called Versawriter-8. That is what I used to do all of the drawings for this rebuild of the game. It allows one to draw, point by point, an image and receive a compact string that represents the drawing instructions for that image. It also allows you to drag-and-drop a 128px-wide image to use as a tracing template and draw on top of that. I took screenshots of the original game, down-sampled them to 128px wide, and used those as the stencil for my drawings, much like Ken and Roberta did with the original.

The source code to Versawriter-8 will be uploaded shortly after this project goes live, along with information on how to use it and the short-term future growth ideas.

## 1 Bit Wonder
Additionally, to squeeze everything into the ROM address space of a Pico-8 cartridge file, I developed another mini-application I call "1 Bit Wonder." This squeezes 1-bit graphics into 1/4 the storage space in the spritesheet. Compression routines for images in Pico-8 are prevalent, but all have the overhead of a decompression routine. This method does not; sprites can be drawn in their compressed form using simple SSPR commands. The novel compression routine relies on the fact that Pico-8 uses 4-bit color. By assigning images to one of four "bitplanes" we can use the colors to denote which pixel belongs to which bitplane. Then, using a simple PAL and PALT command (to do a palette shift) we can extract individual sprites from individual planes as easily as drawing a sprite without compression.

"But if 4 1-bit images can coexist in a single 4-bit color image, surely other combinations are possible?" Yes, on the Pico-8 we could have 4 1-bit, 2 2-bit, a 1-bit and a 3-bit image compressed in similar fashion. In fact, in a 32-bit color image (not targetting Pico-8) we could have 4 8-bit color images squeezed together similarly. This might be useful for older system development, or perhaps just a neat technique for other fantasy consoles, or maybe this project represents the one and only use case. 🤷

The source code to 1 Bit Wonder will be uploaded shortly after this project goes live. It needs a little more tweaking to make it more generally useful before sharing it with the community at large.

# The Future of Mystery House for the Pico-8
There are definitely areas of the code that need to be refactored a bit to align more closely with what I perceive to be the implementations used by the original. Most specifically, the way room inventory is handled remained somewhat opaque to me, and I used very Lua-esque solutions. Only late in development did I arrive at a way to handle inventory objects that *feels* correct for the limitations the Williams's had at the time.

So, getting the game to be more and more "accurate" (and I have to use this word in spirit, if not in implementation) remains the primary goal.

# The Secret Secondary Goal
I hope that with the bones of this project polished (i.e. remove the bugs that exist solely for this project) and with an updated version of Versawriter-8 a kind of "road map" for making graphic adventure games might be available to those looking for one. At the very least it should provide a set of tools and ideas that can be remixed by industrious developers into something new.

Owners of Pico-8 could then make standalone builds of their graphic adventures to sell on itch.io or even Steam, should they be so inclined.
