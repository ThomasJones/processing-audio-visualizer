/**
 * Halftone visual effect that accepts MIDI notes to drive some of the visualization.
 * It works by mapping MIDI notes of various MIDI channels to visual 'pulses', and
 * having those pulses affect the display of the halftone grid. 
 * Notes on MIDI channel once cycle between a visual configuration, allowig the changing of a 'style'.
 **/
class HalftoneVisualization implements Drawable, MIDINoteListener {
  
  /**
   * Visual representation of a note in the halftone grid
   **/
  class Pulse {
    PVector pos;
    float radius;
    float maxRadius;
    float duration;
    float totalDuration;
    boolean alive = true;
    boolean interpolating = false;
    int colorIndex = 0;
  }
     
  /**
   * Color configuration properties.
   **/
  class ColorConfig {
    boolean drawCircle;
    int blendMode;
    int alpha;
    color[] colorPerChannel;
    
    public ColorConfig(boolean drawCircle, int blendMode, int alpha, color[] colorPerChannel) {
      this.drawCircle = drawCircle;
      this.blendMode = blendMode;
      this.alpha = alpha;
      this.colorPerChannel = colorPerChannel;
    }
    
    color getColor(int channel) {
      if (channel >= 0 && channel < colorPerChannel.length) {
        return colorPerChannel[channel];
      }
      return color(255, 0, 255);
    }    
  }
  
  /**
   * Visual configuration or style properties, cyclable / triggerable via input on one of the MIDI channels
   **/
  class Config {
    static final int SHAPE_TYPE_ELLIPSE = 0;
    static final int SHAPE_TYPE_SQUARE = 1;
    
    color background;
    color foreground;
    boolean invertHalftone;
    float radiusScale = 1.5;
    int shapeType = SHAPE_TYPE_ELLIPSE;
    ColorConfig colorConfig;
    
    public Config(color background, color foreground, boolean invertHalftone, float radiusScale, int shapeType, ColorConfig colorConfig) {
      this.background = background;
      this.foreground = foreground;
      this.invertHalftone = invertHalftone;
      this.radiusScale = radiusScale;
      this.shapeType = shapeType;
      this.colorConfig = colorConfig;
    }
  }
  
  
  int gridWidth;
  int gridHeight;
  ArrayList<Pulse> pulses = new ArrayList<Pulse>();
  HashMap<String, Pulse> heldNotes = new HashMap<String, Pulse>();
  final int configChannel = 1;    // MIDI chanel that changes the config (visual style)
  
  ArrayList<Config> configs = new ArrayList<Config>();
  Config config;
  
  HalftoneVisualization(int gridWidth, int gridHeight) {
    this.gridWidth = gridWidth;
    this.gridHeight = gridHeight;
     
    // Colors, index cooresponds to MIDI channel
    int[] defaultColors = new int[] {
      color(184, 242, 230), 
      color(240, 166, 158)
    };
    
    // Create all color and visual configurations that get cycled between
    ColorConfig black = new ColorConfig(false, 0, 0, new int[] { color(0), color(0) });
    ColorConfig white = new ColorConfig(false, 0, 0, new int[] { color(255), color(255) }) ;
    ColorConfig difference = new ColorConfig(true, DIFFERENCE, 255, defaultColors);
    ColorConfig blend = new ColorConfig(true, BLEND, 100, defaultColors);
    ColorConfig lightest = new ColorConfig(true, LIGHTEST, 75, defaultColors);    // good on black backgroud
    ColorConfig darkest = new ColorConfig(true, DARKEST, 75, defaultColors);  // good on light background
        
    // color on white
    configs.add(new Config(color(255), color(0), true, 1.5, Config.SHAPE_TYPE_ELLIPSE, black));
    // white dots on black
    configs.add(new Config(color(0), color(0), false, 0.95, Config.SHAPE_TYPE_ELLIPSE, white));   
    // invert black dots on white
    configs.add(new Config(color(255), color(255), false, 0.95, Config.SHAPE_TYPE_ELLIPSE, black));
    // dots on black
    configs.add(new Config(color(0), color(0), true, 1.5, Config.SHAPE_TYPE_ELLIPSE, white));
    
    // disco ball on light
    configs.add(new Config(color(255), color(0), true, 0.85, Config.SHAPE_TYPE_SQUARE, darkest));
    // disco ball on black 
    configs.add(new Config(color(0), color(0), true, 0.95, Config.SHAPE_TYPE_SQUARE, lightest));
    // disco ball on black inverted
    configs.add(new Config(color(0), color(0), false, 0.95, Config.SHAPE_TYPE_SQUARE, difference));
    
    // small grids 
    configs.add(new Config(color(0), color(75), false, 0.5, Config.SHAPE_TYPE_ELLIPSE, blend));
    // difference dots
    configs.add(new Config(color(0), color(0), true, 1.8, Config.SHAPE_TYPE_ELLIPSE, difference));
    // gray background, lager circles
    configs.add(new Config(color(100), color(0), true, 2.0, Config.SHAPE_TYPE_ELLIPSE, lightest));
    configs.add(new Config(color(20), color(0), false, 1.0, Config.SHAPE_TYPE_ELLIPSE, blend));
       
    config = configs.get(0);
  }
  
  void update(Time time) {
    ArrayList<Pulse> currentPulses = new ArrayList<Pulse>(pulses);
    
    // Remove dead pulses
    ArrayList<Pulse> dead = new ArrayList<Pulse>();
    for (Pulse pulse : currentPulses) {
      if (!pulse.alive) {
        dead.add(pulse);
      }
    }
    pulses.removeAll(dead);
    currentPulses = new ArrayList<Pulse>(pulses);
    
    // Update alive pulses
    for (Pulse pulse : currentPulses) {
      if (pulse.interpolating) {
        pulse.duration -= time.deltaSeconds();
        float t = max(0, pulse.duration) / pulse.totalDuration;
        // TODO - configurable radius interpolation method here...
        pulse.radius = pulse.maxRadius * pow(t, 2);
        pulse.alive = pulse.duration > 0.0f;
      }
    }
  }
  
  void setCurrentConfig(int index) {
    if (configs.size() > index) {
      config = configs.get(index);
    }
  }
  
  synchronized void noteOn(MIDINote note) {
    // Notes on a certain channel switch color config
    if (note.channelOneIndexed() == configChannel) {
      setCurrentConfig(note.noteInOctave());
      return;
    }
    
    // All other notes get added as pulses
    Pulse pulse = createPulseForNote(note);
    heldNotes.put(hashNote(note), pulse);
    pulses.add(pulse);
  }
  
  void noteOff(MIDINote note) {
    if (note.channelOneIndexed() == configChannel) {
      return;
    }
    
    String hash = hashNote(note);
    Pulse pulse = heldNotes.get(hash);
    if (pulse != null) {
      pulse.interpolating = true;
      heldNotes.remove(hash);
    } else {
      print(" **** Couldn't find held note : " + note.readableNote());
    }
  }
  
  void draw() {
    ArrayList<Pulse> currentPulses = new ArrayList<Pulse>(pulses);
    
    blendMode(NORMAL);
    background(config.background);
    fill(config.foreground);
    noStroke();
    boolean invertHalftone = config.invertHalftone;
    
    float radiusX = width / (float)gridWidth;
    float radiusY = height / (float)gridHeight;
    float halfRadiusX = radiusX * 0.5;
    float halfRadiusY = radiusY * 0.5;
    float radScale = config.radiusScale;
    //float maxDist = 200;
    
    // Iterate through all the circles on the halftone grid..
    for (int x = 0; x < gridWidth; ++x) {
      for (int y = 0; y < gridHeight; ++y) {
        
        float xT = ((float)x / (float)gridWidth);
        float yT = ((float)y / (float)gridHeight);
        
        float screenX = (xT * width) + halfRadiusX;
        float screenY = (yT * height) + halfRadiusY;
                
        float currentRadX = radiusX * radScale;
        float currentRadY = radiusY * radScale;
        float minRadX = currentRadX;
        float minRadY = currentRadY;

        color c = config.foreground;
        
        // The size and color of halftone dot based on nearby pulses
        for (Pulse pulse : currentPulses) {
          float dist = dist(pulse.pos.x, pulse.pos.y, screenX, screenY);
          
          // Normalized value that indidcates the halftone dot size fall-off based on the distance to the pulse center
          float distT = min(dist / (pulse.radius * 0.6), 1.0);
          distT = pow(distT, 2);          
          float newRadX = currentRadX * distT;
          float newRadY = currentRadY * distT;
          
          // Keep track of the 'closest' pulse and the properties most relevant to this particular halftone dot 
          if (newRadX < minRadX) {
            minRadX = newRadX;
            c = config.colorConfig.getColor(pulse.colorIndex);
          }
          if (newRadY < minRadY) {
            minRadY = newRadY;
            c = config.colorConfig.getColor(pulse.colorIndex);
          }
        }
        
        // Draw the halftone dot, size and color based on nearby pulse properties and distance
        fill(c);
        float finalRadX = invertHalftone ? (currentRadX - minRadX) : minRadX;
        float finalRadY = invertHalftone ? (currentRadY - minRadY) : minRadY;        
        if (config.shapeType == Config.SHAPE_TYPE_ELLIPSE) {
          ellipse(screenX, screenY, finalRadX, finalRadY);
        } else if (config.shapeType == Config.SHAPE_TYPE_SQUARE) {
          rectMode(CENTER);
          rect(screenX, screenY, finalRadX, finalRadY);
        }
      }
    }
    
    // Draw additional pulse on top of halftone grid based on config properties
    stroke(color(0,0,0));
    noFill();       
    ColorConfig colorConfig = config.colorConfig;
    if (colorConfig.drawCircle) {
      blendMode(colorConfig.blendMode);
      noStroke();
      for (Pulse pulse : currentPulses) {
        color c = colorConfig.getColor(pulse.colorIndex);
        fill(c, colorConfig.alpha);
        circle(pulse.pos.x, pulse.pos.y, pulse.radius* 1.25);
      }
    }
  }
  
  boolean isAlive() {
    return true;
  }
  
  // Transform MIDI note into a visual pulse 
  private Pulse createPulseForNote(MIDINote note) {         
    // Note pitch, normalized 0->1 based on range defined by min and max
    float minNote = 30;
    float maxNote = 95;
    float ty = (maxNote - (float)note.pitch()) / (maxNote - minNote);  
    
    // Screen Y pos, based on normalized pitch value
    float screenY = ty * height;   
    
    //Panning is driven by the note velocity, mapped 0 -> 1
    float panning = lerp(0, 1.0, (note.velocity() - 1)/127.0); 
    float screenX = width * panning;
    
    // Velocity (and hence radius) are hard-coded for now since velocity is diving panning 
    float velocityT = 0.8;  //(float)note.velocity() / 127.0;    
    float radius = lerp(40, 300, velocityT);
    
    // Create the pulse with the visual properties tansformed from the MIDI note
    Pulse pulse = new Pulse();
    pulse.pos = new PVector(screenX, screenY);
    pulse.radius = radius;
    pulse.maxRadius = radius;
    pulse.duration = 2.0;    
    pulse.totalDuration = pulse.duration;
    pulse.colorIndex = note.channel() - 1;    
        
    return pulse;
  }
  
  private String hashNote(MIDINote note) {
    return "[" + note.pitch() + ", " + note.channel() + "]";
  }
}
