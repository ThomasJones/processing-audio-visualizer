/**
 * Common interface for anything that updates and draws.
 **/
interface Drawable {
  void update(Time time);
  
  void draw();
  
  boolean isAlive();
}
