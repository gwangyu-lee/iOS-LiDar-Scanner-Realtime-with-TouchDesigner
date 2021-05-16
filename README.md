# iOS-LiDar-Scanner-Realtime-Test
An example application using a LiDar sensor on iOS with TouchDesigner. 

This application contains copyrighted software under MIT License.
SwiftOSC - Copyright (c) 2017 Devin Roth

## How to build

Open Lidar_Scanner_Realtime.xcworkspace.   
Connect iOS device with a LiDar Sensor(iPhone 12 Pro Max is recommended).  
Build it

## Settings
Swipe to the right edge of the screen.   
Set IP address and port and press the button “Set”

### Realtime
If the switch is ON, Realtime mode is ON.

### Statistics
If the switch is ON, it'll show you the statistics on screen.

## Reset
Reset the frame.

## Export .obj file
Export .obj file and can send it to other devices or can save it on you iPhone.

## How to work with TouchDesigner
#### In iOS
Run the application.   
Set IP address and port.   
Turn the realtime ON.   

![Lidar](https://user-images.githubusercontent.com/79373845/118382020-badfa500-b62b-11eb-8505-d214b44be920.gif)

#### In TouchDesigner
Open LiDar_Scanner_Realtime.toe.   
Click the OSC In DAT.   
Set the port.

![Lidar-1](https://user-images.githubusercontent.com/79373845/118382040-042ff480-b62c-11eb-928e-96b3ed0e518f.gif)

