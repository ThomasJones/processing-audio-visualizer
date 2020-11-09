/**
 * Accept MIDI note events 
 */
public interface MIDINoteListener {
  void noteOn(MIDINote note);
  void noteOff(MIDINote note);
}

// Indexible array that can take a 'normalized' note-in-octave pitch and convert to readable note.
public final String[] NOTE_NAMES = new String[] {
  "C","C#","D","D#","E","F","F#","G","G#","A","A#","B"
};

public final int MIN_OCTAVE = -2;
public final int MAX_OCTAVE = 8;

public float getNormalizedOctave(int octave) {
  return ((float)octave - (float)MIN_OCTAVE) / (float)(MAX_OCTAVE - MIN_OCTAVE);
}

/**
 * MIDI note instance
 **/
class MIDINote {
  int channel;
  int pitch;
  int velocity;
  
  public MIDINote(int channel, int pitch, int velocity) {
    this.channel = channel;
    this.pitch = pitch;
    this.velocity = velocity;
  }
  
  public int channel() {
    return channel;
  }
  
  public int channelOneIndexed() {
    return channel + 1;
  }
  
  public int pitch() {
    return pitch;
  }
  
  public int velocity() {
    return velocity;
  }
  
  // The notes in an octave starting with C at 0 up to B at 11.
  public int noteInOctave() {
    return pitch % 12;
  }
  
  // The octave the note is in, from 0 to 5 or so?
  public int octave() {
    return (pitch / 12) - 2;
  }
  
  // C5, C#5, G8, B-1, etc
  public String readableNote() {
     return NOTE_NAMES[noteInOctave()] + octave(); 
  }
  
  public String toString() {
    return "Note pitch " + pitch + ", " + readableNote() + ", octave: " + octave() + ", note: " + noteInOctave() + " norm-octave: " + getNormalizedOctave(octave());  
  }
}

/**
 * Interface with MIDI Bus library, collecting and dispatching MIDI note events.
 **/
public class MIDIManager {
  
  private MidiBus midiBus;
  private ArrayList<MIDINoteListener> noteListeners = new ArrayList<MIDINoteListener>();
  private ArrayList<MIDINote> noteOnQueue = new ArrayList<MIDINote>();
  private ArrayList<MIDINote> noteOffQueue = new ArrayList<MIDINote>();
  
  public MIDIManager() {
    MidiBus.list(); // List all available Midi devices on STDOUT. This will show each device's index and name.
    midiBus = new MidiBus(this, "Bus 1", -1);
  }
  
  public void update() {
    // Copy notes to avoid potential thread issues, maybe a lock or mutex instead?
    ArrayList<MIDINote> onNotes = new ArrayList<MIDINote>(noteOnQueue);
    noteOnQueue.clear();
    ArrayList<MIDINote> offNotes = new ArrayList<MIDINote>(noteOffQueue);
    noteOffQueue.clear();
    
    // Dispatch on-notes
    for (MIDINote note: onNotes) {
      for (MIDINoteListener listener : noteListeners) {
        listener.noteOn(note);
      }
    }
    
    // Dispatch off-notes
    for (MIDINote note: offNotes) {
      for (MIDINoteListener listener : noteListeners) {
        listener.noteOff(note);
      }
    }
  }
  
  public void addNoteListener(MIDINoteListener listener) {
    noteListeners.add(listener);
  }  
  
  public void removeNoteListener(MIDINoteListener listener) {
    noteListeners.remove(listener);
  }
  
  public synchronized void noteOn(int channel, int pitch, int velocity) {
    MIDINote note = new MIDINote(channel, pitch, velocity);
    noteOnQueue.add(note);
  }
  
  public synchronized void noteOff(int channel, int pitch, int velocity) {
    MIDINote note = new MIDINote(channel, pitch, velocity);
    noteOffQueue.add(note);
  }

  public synchronized void controllerChange(int channel, int number, int value) {
    // TODO - handle these
  }
}
