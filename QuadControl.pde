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

int deltaTime = 0;
boolean isArmed = false;

// Sensor data
int gyroRoll, gyroPitch, gyroYaw;
int accelRoll, accelPitch, accelYaw;

// Engine speeds
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
    myPort.write('S');
  }
  
  background(bgcolor);
  
  // Update sensor data
  textFont(f, 14);
  fill(fgcolor);
  int firstPosition = 101;
  textAlign(LEFT);
  text("Gyro: ", 10, 14);
  textAlign(RIGHT);
  text(gyroRoll, firstPosition, 14);
  textAlign(RIGHT);
  text(gyroPitch, firstPosition+45, 14);
  textAlign(RIGHT);
  text(gyroYaw, firstPosition+90, 14);
  
  textAlign(LEFT);
  text("Accel: ", 10, 34);
  textAlign(RIGHT);
  text(accelRoll, firstPosition, 34);
  textAlign(RIGHT);
  text(accelPitch, firstPosition+45, 34);
  textAlign(RIGHT);
  text(accelYaw, firstPosition+90, 34);
  
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
  
  // Update stats
  textAlign(RIGHT);
  text("Rate: "+(deltaTime/1000)+"ms", windowWidth-10, 14);
  if (isArmed){
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
  if (mouseX >= 10 && mouseX <= 10+buttonWidth && 
      mouseY >= windowHeight-40 && mouseY <= windowHeight-40+buttonHeight) {
    fill(210);
    
    if (mousePressed == true){
      myPort.write('b');
      delay(100);
      myPort.write('c');
      delay(100);
      myPort.write('S');
    }
  }
  else{
    fill(buttonColor);
  }
  rect(10, windowHeight-40, buttonWidth, buttonHeight);
  fill(0);
  textAlign(CENTER);
  text("Re-Calibrate", 10+(buttonWidth/2), windowHeight-40+(buttonHeight/2)+5);
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
    int[] data = int(split(new String(serialInArray, 0, serialCount), ','));
    
    deltaTime = data[0];
    
    gyroRoll = data[1];
    gyroPitch = data[2];
    gyroYaw = data[3];
    
    accelRoll = data[13];
    accelPitch = data[14];
    accelYaw = data[15];
    
    for (int i=0; i<ENGINE_COUNT; i++){
      engineSpeeds[0] = data[9+i];
    }
    
    isArmed = boolean(data[16]);
    
    serialCount = 0;
  }
}
