import themidibus.*;
import processing.sound.*;

Time time;
MIDIManager midi;
ArrayList<Drawable> drawables = new ArrayList<Drawable>();

void setup() {
  
  size(640, 640);
  background(0);

  time = new Time();
  midi = new MIDIManager();
  
  HalftoneVisualization visualization = new HalftoneVisualization(40, 40);
  drawables.add(visualization);
  midi.addNoteListener(visualization);
}


void draw() {
  time.tick();
  
  midi.update();

  // Update and draw all drawables, removing the ones that are no longer alive.
  ArrayList<Drawable> toDraw = new ArrayList<Drawable>(drawables);
  ArrayList<Drawable> toRemove = new ArrayList<Drawable>();
  for(Drawable drawable : toDraw) { 
    drawable.update(time);
    drawable.draw();
    if (!drawable.isAlive()) {
      toRemove.add(drawable);
    }
  }

  drawables.removeAll(toRemove);
}
