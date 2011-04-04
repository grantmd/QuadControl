/*
* Talk to my quadcopter for debugging/control
*/

import processing.serial.*;

int windowWidth = 1024;
int windowHeight = 640;
int bgcolor = 0;			     // Background color
int fgcolor = 255;			     // Fill color
Serial myPort;                       // The serial port
char[] serialInArray = new char[128];    // Where we'll put what we receive
int serialCount = 0;                 // A count of how many bytes we receive
boolean firstContact = false;        // Whether we've heard from the microcontroller
PFont f;
boolean modifyingThrottle = false;
char[] newThrottle = new char[4];
int throttleIndex = 0;

int deltaTime = 0;
int isArmed = 0;

// Sensor data
float roll, pitch, heading;

// Engine speeds
int throttle = 0;
int ENGINE_COUNT = 4;
int[] engineSpeeds = new int[ENGINE_COUNT];

// Buttons
int buttonColor = 180;
int buttonWidth = 120;
int buttonHeight = 30;

void setup() {
  size(windowWidth, windowHeight);  // Stage size
  //noStroke();      // No border on the next thing drawn
  
  f = loadFont("Monospaced-14.vlw");

  // Print a list of the serial ports, for debugging purposes:
  //println(Serial.list());

  // I know that the first port in the serial list on my mac
  // is always my  FTDI adaptor, so I open Serial.list()[0].
  // On Windows machines, this generally opens COM1.
  // Open whatever port is the one you're using.
  String portName = Serial.list()[0];
  myPort = new Serial(this, portName, 115200);
}

void draw(){
  if (!firstContact){
    // Ask for data
    myPort.write('&');
  }
  
  background(bgcolor);
  
  // Update sensor data
  textFont(f, 14);
  fill(fgcolor);
  int firstPosition = 70;
  
  textAlign(RIGHT);
  text("Roll", firstPosition, 14);
  textAlign(RIGHT);
  text("Pitch", firstPosition+70, 14);
  textAlign(RIGHT);
  text("Heading", firstPosition+140, 14);
  
  textAlign(RIGHT);
  text(roll, firstPosition, 34);
  textAlign(RIGHT);
  text(pitch, firstPosition+70, 34);
  textAlign(RIGHT);  
  text(heading, firstPosition+140, 34);
  
  // Update engine speeds
  int center = windowWidth/2;
  textAlign(CENTER);
  text("Engines", center, 14);
  textAlign(LEFT);
  text(engineSpeeds[0], center-50, 34);
  text(engineSpeeds[2], center-50, 54);
  textAlign(RIGHT);
  text(engineSpeeds[1], center+50, 34);
  text(engineSpeeds[3], center+50, 54);
  textAlign(CENTER);
  text(throttle, center, 74);
  
  // Update stats
  textAlign(RIGHT);
  text("Rate: "+(deltaTime/1000)+"ms", windowWidth-10, 14);
  if (isArmed == 1){
    text("Armed: Yes", windowWidth-10, 34);
  }
  else{
    text("Armed: No", windowWidth-10, 34);
  }
  
  // Orientation
  int lineOffset = windowWidth/4;
  int vertCenter = windowHeight/2;
  int lineWidth = 75;
  
  strokeWeight(2);
  line(lineOffset-10, vertCenter-3, lineOffset+10, vertCenter-3);
  line(lineOffset-lineWidth, vertCenter, lineOffset+lineWidth, vertCenter);
  
  line((lineOffset*2)-10, vertCenter-3, (lineOffset*2)+10, vertCenter-3);
  line((lineOffset*2)-lineWidth, vertCenter, (lineOffset*2)+lineWidth, vertCenter);
  
  line((lineOffset*3)-10, vertCenter-3, (lineOffset*3)+10, vertCenter-3);
  line((lineOffset*3)-lineWidth, vertCenter, (lineOffset*3)+lineWidth, vertCenter);
  
  
  // Draw buttons
  stroke(255);
  strokeWeight(1);
  int xOffset = 10;
  
  if (mouseX >= xOffset && mouseX <= xOffset+buttonWidth && 
      mouseY >= windowHeight-40 && mouseY <= windowHeight-40+buttonHeight) {
    fill(210);
    
    if (mousePressed == true){
      myPort.write('b');
      delay(100);
      myPort.write('c');
      delay(100);
      myPort.write('&');
    }
  }
  else{
    fill(buttonColor);
  }
  rect(xOffset, windowHeight-40, buttonWidth, buttonHeight);
  fill(0);
  textAlign(CENTER);
  text("Re-Calibrate", xOffset+(buttonWidth/2), windowHeight-40+(buttonHeight/2)+5);
  
  //////
  xOffset += buttonWidth + 10;
  if (mouseX >= xOffset && mouseX <= xOffset+buttonWidth && 
      mouseY >= windowHeight-40 && mouseY <= windowHeight-40+buttonHeight) {
    fill(210);
    
    if (mousePressed == true){
      if (isArmed == 1){
        myPort.write('4');
      }
      else{
        myPort.write('2');
      }
      delay(100);
      myPort.write('&');
    }
  }
  else{
    fill(buttonColor);
  }
  rect(xOffset, windowHeight-40, buttonWidth, buttonHeight);
  fill(0);
  textAlign(CENTER);
  if (isArmed == 1){
    text("Disarm", xOffset+(buttonWidth/2), windowHeight-40+(buttonHeight/2)+5);
  }
  else{
    text("Arm", xOffset+(buttonWidth/2), windowHeight-40+(buttonHeight/2)+5);
  }
  
  //////
  xOffset += buttonWidth + 10;
  if (mouseX >= xOffset && mouseX <= xOffset+buttonWidth && 
      mouseY >= windowHeight-40 && mouseY <= windowHeight-40+buttonHeight) {
    fill(210);
    
    if (mousePressed == true){
      if (modifyingThrottle == true){
        sendNewThrottle();
      }
      else{
        modifyingThrottle = true;
        for (int i=0; i<4; i++){
          newThrottle[i] = '\0';
        }
        throttleIndex = 0;
        delay(100);
      }
    }
  }
  else{
    fill(buttonColor);
  }
  rect(xOffset, windowHeight-40, buttonWidth, buttonHeight);
  fill(0);
  textAlign(CENTER);
  if (modifyingThrottle == true){
    int tmp = int(new String(newThrottle, 0, throttleIndex));
    text(tmp, xOffset+(buttonWidth/2), windowHeight-40+(buttonHeight/2)+5);
  }
  else{
    text("Set Throttle", xOffset+(buttonWidth/2), windowHeight-40+(buttonHeight/2)+5);
  }
}

void serialEvent(Serial myPort){
  if (!firstContact) firstContact = true;
  
  // read a byte from the serial port:
  char inByte = myPort.readChar();

  // Add the latest byte from the serial port to array:
  if (inByte != 10){
    serialInArray[serialCount] = inByte;
    serialCount++;
  }
  
  // All done
  if (inByte == 13){
    float[] data = float(split(new String(serialInArray, 0, serialCount), ','));
    
    deltaTime = int(data[0]);
        
    roll = data[1];
    pitch = data[2];
    heading = data[3];
    
    throttle = int(data[4]);
    
    for (int i=0; i<ENGINE_COUNT; i++){
      engineSpeeds[i] = int(data[5+i]);
    }
    
    isArmed = int(data[9]);
    
    serialCount = 0;
  }
}

void keyReleased() {
  if (modifyingThrottle && throttleIndex < 4){
    if (int(key) == 10){
      sendNewThrottle();
    }
    else{
      newThrottle[throttleIndex] = key;
      throttleIndex++;
    }
  }
}

void sendNewThrottle(){
  String tmp = new String(newThrottle, 0, throttleIndex);
  myPort.write("$"+tmp);
  modifyingThrottle = false;
  delay(100);
  myPort.write('&');
}
