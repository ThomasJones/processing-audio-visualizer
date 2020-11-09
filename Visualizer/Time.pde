/**
 * Keeps track of time, current frame, and delta time.
 **/
class Time {
  int frame = 0;
  int current = 0;
  int previous = 0;
  int delta = 0;
  float deltaSeconds = 0;
  
  public Time() {}
  
  public void tick() {
    frame += 1;
    previous = current;
    current = millis();
    delta = current - previous;
    deltaSeconds = (float)delta / 1000.0f;
  }
  
  public int deltaMillis() {
    return delta;
  }
  
  public float deltaSeconds() {
    return deltaSeconds;
  }
  
  public int frame() {
    return frame;
  }
}
