/*
* Talk to my quadcopter for debugging/control
*/

import processing.serial.*;

int windowWidth = 1024;
int windowHeight = 640;
int bgcolor = 0;			     // Background color
int fgcolor = 255;			     // Fill color
PFont f;

Serial myPort;                       // The serial port
PrintWriter output;
char[] serialInArray = new char[1024];    // Where we'll put what we receive
int serialCount = 0;                 // A count of how many bytes we receive
int lastData = 0;
int readMode = 1; // 0: Sensor data, 1: PIDs

boolean modifyingThrottle = false;
char[] newThrottle = new char[4];
int throttleIndex = 0;

int deltaTime = 0;
int isArmed = 0;
int systemMode = 0;
int altHold = 0;

// Sensor data
float roll, pitch, heading, aRoll, aPitch, aYaw, gRoll, gPitch, gYaw;
int historyCount = windowWidth-100;
float[] pitchHistory = new float[historyCount];
float[] rollHistory = new float[historyCount];
float[] headingHistory = new float[historyCount];
int updateCount = 0;

float rollAvg, rollMin, rollMax;
float pitchAvg, pitchMin, pitchMax;
float headingAvg, headingMin, headingMax;

float altitude;
float voltage;

// Engine speeds
int throttle = 0;
int ENGINE_COUNT = 4;
int[] engineSpeeds = new int[ENGINE_COUNT];

// PIDs
float[] levelRollPID = new float[3];
float[] levelPitchPID = new float[3];

// Buttons
int buttonColor = 180;
int buttonWidth = 120;
int buttonHeight = 30;

// Positions
int firstPosition = 70;
int center = windowWidth/2;
int lineOffset = windowWidth/4;
int vertCenter = windowHeight/2;
int lineWidth = 75;

int gaugeCenter = vertCenter - 100;
int graphCenter = vertCenter + 100;

void setup() {
  size(windowWidth, windowHeight);  // Stage size
  smooth();
  
  f = loadFont("Monospaced-14.vlw");
  
  output = createWriter(day()+"-"+month()+"-"+year()+"_"+hour()+"-"+minute()+"-"+second()+".csv"); 

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
  if (millis() - lastData >= 120){
    // Ask for data
    if (readMode == 1){
      myPort.write('F');
    }
    else{
      myPort.write('&');
    }
  }
  
  background(bgcolor);
  
  // Update sensor data
  textFont(f, 14);
  fill(fgcolor);
  
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
  
  textAlign(RIGHT);
  text(aRoll, firstPosition, 54);
  textAlign(RIGHT);
  text(aPitch, firstPosition+70, 54);
  textAlign(RIGHT);  
  text(aYaw, firstPosition+140, 54);
  
  textAlign(RIGHT);
  text(gRoll, firstPosition, 74);
  textAlign(RIGHT);
  text(gPitch, firstPosition+70, 74);
  textAlign(RIGHT);  
  text(gYaw, firstPosition+140, 74);
  
  // Update engine speeds
  textAlign(CENTER);
  text("Engines", center, 14);
  textAlign(LEFT);
  text(engineSpeeds[0], center-60, 34);
  text(engineSpeeds[2], center-60, 54);
  textAlign(RIGHT);
  text(engineSpeeds[1], center+60, 34);
  text(engineSpeeds[3], center+60, 54);
  textAlign(CENTER);
  text(throttle, center, 44);
  
  // Update stats
  textAlign(RIGHT);
  text("Last data: "+(millis() - lastData)+"ms", windowWidth-10, 14);
  text("Rate: "+(deltaTime/1000)+"ms", windowWidth-10, 34);
  text("Power: "+(voltage)+"v", windowWidth-10, 54);
  text("Altitude: "+(altitude)+"m", windowWidth-10, 74);
  
  // Orientation
  noStroke();
  
  pushMatrix();
  translate(lineOffset, gaugeCenter);
  rotate(radians(roll));
  fill(255, 0, 0);
  rect(-10, -3, 20, 3);
  rect(-lineWidth, 0, lineWidth*2, 2);
  popMatrix();
  
  pushMatrix();
  translate(lineOffset*2, gaugeCenter);
  rotate(radians(pitch));
  fill(0, 0, 255);
  rect(-10, -3, 20, 3);
  rect(-lineWidth, 0, lineWidth*2, 2);
  popMatrix();
  
  pushMatrix();
  translate(lineOffset*3, gaugeCenter);
  rotate(radians(heading));
  fill(fgcolor);
  rect(-10, -3, 20, 3);
  rect(-lineWidth, 0, lineWidth*2, 2);
  popMatrix();
  
  // Graph
  rollAvg = 0;
  rollMin = 0;
  rollMax = 0;
  pitchAvg = 0;
  pitchMin = 0;
  pitchMax = 0;
  headingAvg = 0;
  headingMin = 0;
  headingMax = 0;
  
  strokeWeight(2);
  
  int maxPos = min(historyCount, updateCount);
  if (maxPos > 1){
    for (int i=0; i<maxPos; i++){
      stroke(255, 0, 0);
      point(historyCount+50-i, round(graphCenter+rollHistory[i]));
      stroke(0, 0, 255);
      point(historyCount+50-i, round(graphCenter+pitchHistory[i]));
      stroke(255);
      point(historyCount+50-i, round(graphCenter+headingHistory[i]));
      
      rollAvg += rollHistory[i];
      pitchAvg += pitchHistory[i];
      headingAvg += headingHistory[i];
      
      if (rollHistory[i] < rollMin) rollMin = rollHistory[i];
      if (rollHistory[i] > rollMax) rollMax = rollHistory[i];
      
      if (pitchHistory[i] < pitchMin) pitchMin = pitchHistory[i];
      if (pitchHistory[i] > pitchMax) pitchMax = pitchHistory[i];
      
      if (headingHistory[i] < headingMin) headingMin = headingHistory[i];
      if (headingHistory[i] > headingMax) headingMax = headingHistory[i];
    }
    
    rollAvg = rollAvg/maxPos;
    pitchAvg = pitchAvg/maxPos;
    headingAvg = headingAvg/maxPos;
  }
  
  stroke(255);
  textAlign(LEFT);
  text("Avg:", 10, windowHeight-100);
  text("Min:", 10, windowHeight-80);
  text("Max:", 10, windowHeight-60);
  
  fill(255, 0, 0);
  textAlign(RIGHT);
  text(rollAvg, 120, windowHeight-100);
  text(rollMin, 120, windowHeight-80);
  text(rollMax, 120, windowHeight-60);
  
  fill(0, 0, 255);
  textAlign(RIGHT);
  text(pitchAvg, 200, windowHeight-100);
  text(pitchMin, 200, windowHeight-80);
  text(pitchMax, 200, windowHeight-60);
  
  fill(255);
  textAlign(RIGHT);
  text(headingAvg, 280, windowHeight-100);
  text(headingMin, 280, windowHeight-80);
  text(headingMax, 280, windowHeight-60);
  
  ///////////
  
  stroke(255);
  textAlign(LEFT);
  text("P", windowWidth-170, windowHeight-100);
  text("I", windowWidth-110, windowHeight-100);
  text("D", windowWidth-50, windowHeight-100);
 
  fill(255, 0, 0);
  textAlign(RIGHT);
  text(levelRollPID[0], windowWidth-130, windowHeight-80);
  text(levelRollPID[1], windowWidth-70, windowHeight-80);
  text(levelRollPID[2], windowWidth-10, windowHeight-80);
  
  fill(0, 0, 255);
  textAlign(RIGHT);
  text(levelPitchPID[0], windowWidth-130, windowHeight-60);
  text(levelPitchPID[1], windowWidth-70, windowHeight-60);
  text(levelPitchPID[2], windowWidth-10, windowHeight-60);
  
  // Draw buttons
  stroke(255);
  strokeWeight(1);
  int xOffset = 10;
  
  if (mouseX >= xOffset && mouseX <= xOffset+buttonWidth && 
      mouseY >= windowHeight-40 && mouseY <= windowHeight-40+buttonHeight) {
    fill(210);
    
    if (mousePressed == true){
      myPort.write("X");
      myPort.clear();
      myPort.write('b');
      delay(100);
      myPort.write('c');
      delay(100);
      myPort.write('f');
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
      myPort.write("X");
      myPort.clear();
      if (isArmed == 1){
        sendDisarm();
      }
      else{
        sendArm();
      }
      delay(100);
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
  
  //////
  xOffset += buttonWidth + 10;
  if (mouseX >= xOffset && mouseX <= xOffset+buttonWidth && 
      mouseY >= windowHeight-40 && mouseY <= windowHeight-40+buttonHeight) {
    fill(210);
    
    if (mousePressed == true){
      if (systemMode == 0){
        sendMode(1);
        systemMode = 1;
      }
      else{
        sendMode(0);
        systemMode = 0;
      }
      delay(100);
    }
  }
  else{
    fill(buttonColor);
  }
  rect(xOffset, windowHeight-40, buttonWidth, buttonHeight);
  fill(0);
  textAlign(CENTER);
  if (systemMode == 1){
    text("AUTO", xOffset+(buttonWidth/2), windowHeight-40+(buttonHeight/2)+5);
  }
  else if (systemMode == 2){
    text("AUTO (PID)", xOffset+(buttonWidth/2), windowHeight-40+(buttonHeight/2)+5);
  }
  else{
    text("MANUAL", xOffset+(buttonWidth/2), windowHeight-40+(buttonHeight/2)+5);
  }
  
  //////
  xOffset += buttonWidth + 10;
  if (mouseX >= xOffset && mouseX <= xOffset+buttonWidth && 
      mouseY >= windowHeight-40 && mouseY <= windowHeight-40+buttonHeight) {
    fill(210);
    
    if (mousePressed == true){
      if (altHold == 0){
        sendAltHold(1);
        altHold = 1;
      }
      else{
        sendAltHold(0);
        altHold = 0;
      }
      delay(100);
    }
  }
  else{
    fill(buttonColor);
  }
  rect(xOffset, windowHeight-40, buttonWidth, buttonHeight);
  fill(0);
  textAlign(CENTER);
  if (altHold == 1){
    text("ALT HOLD: On", xOffset+(buttonWidth/2), windowHeight-40+(buttonHeight/2)+5);
  }
  else{
    text("ALT HOLD: Off", xOffset+(buttonWidth/2), windowHeight-40+(buttonHeight/2)+5);
  }
}

void serialEvent(Serial myPort){
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
    
    println("Length: "+data.length);
    println("Read mode: "+readMode);
    println(new String(serialInArray, 0, serialCount));
    
    if (readMode == 0 && data.length == 17){
      
      deltaTime = int(data[0]);
          
      roll = data[1] * -1;
      pitch = data[2];
      heading = data[3];
      
      aRoll = data[4];
      aPitch = data[5];
      aYaw = data[6];
      
      gRoll = data[7];
      gPitch = data[8];
      gYaw = data[9];
      
      throttle = int(data[10]);
      
      for (int i=0; i<ENGINE_COUNT; i++){
        engineSpeeds[i] = int(data[11+i]);
      }
      
      isArmed = int(data[15]);
      systemMode = int(data[16]);
      
      for (int i=min(historyCount, updateCount)-1; i>0; i--){
        pitchHistory[i] = pitchHistory[i-1];
        rollHistory[i] = rollHistory[i-1];
        headingHistory[i] = headingHistory[i-1];
      }
      
      pitchHistory[0] = pitch;
      rollHistory[0] = roll;
      headingHistory[0] = heading;
      
      output.println(new String(serialInArray, 0, serialCount));
    }
    else if (readMode == 1 && data.length == 7){
      
      levelRollPID[0] = data[0];
      levelRollPID[1] = data[1];
      levelRollPID[2] = data[2];
      
      levelPitchPID[0] = data[3];
      levelPitchPID[1] = data[4];
      levelPitchPID[2] = data[5];
      
      readMode = 0;
      myPort.write('&');
    }
    
    updateCount++;
    serialCount = 0;
    
    lastData = millis();
  }
}

void keyReleased(){
  if (key == CODED){
    if (keyCode == UP){
      if (systemMode == 0){
        int tmp = throttle+10;
        myPort.write("$"+tmp+";&");
      }
      else{
        levelRollPID[0] += 0.5;
        levelPitchPID[0] += 0.5;
        sendRollPitchPID();
      }
    }
    else if (keyCode == DOWN){
      if (systemMode == 0){
        int tmp = throttle-10;
        myPort.write("$"+tmp+";&");
      }
      else{
        levelRollPID[0] -= 0.5;
        levelPitchPID[0] -= 0.5;
        sendRollPitchPID();
      }
    }
    else if (keyCode == LEFT){
      if (systemMode == 2){
        levelRollPID[2] -= 0.5;
        levelPitchPID[2] -= 0.5;
        sendRollPitchPID();
      }
    }
    else if (keyCode == RIGHT){
      if (systemMode == 2){
        levelRollPID[2] += 0.5;
        levelPitchPID[2] += 0.5;
        sendRollPitchPID();
      }
    }
  }
  else if (isArmed == 1 && key == 's'){
    myPort.write("X");
    myPort.clear();
    sendDisarm();
  }
  else if (isArmed == 0 && key == 's'){
    myPort.write("X");
    myPort.clear();
    sendArm();
  }
  else if (systemMode == 1 && key == 'p'){
    sendMode(2);
    systemMode = 2;
  }
  else if (modifyingThrottle && throttleIndex < 4){
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
  myPort.write("X");
  myPort.clear();
  myPort.write("$"+tmp+";&");
  modifyingThrottle = false;
}

void sendDisarm(){
  myPort.write('4');
}

void sendArm(){
  myPort.write('2');
}

void sendMode(int mode){
  myPort.write("X");
  myPort.clear();
  myPort.write("S"+mode+";&");
}

void sendAltHold(int mode){
  myPort.write("X");
  myPort.clear();
  myPort.write("S"+mode+";&");
}

void sendRollPitchPID(){
  myPort.write("X");
  myPort.clear();
  myPort.write("E");
  
  for (int i=0; i<3; i++) myPort.write(levelRollPID[i]+";");
  for (int i=0; i<3; i++) myPort.write(levelPitchPID[i]+";");
  
  myPort.write("&");
}
