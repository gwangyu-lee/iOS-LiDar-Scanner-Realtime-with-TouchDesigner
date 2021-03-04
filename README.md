# iOS-LiDar-Scanner-Realtime

An example application using a LiDar sensor on iOS with TouchDesigner. 

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
#### In TouchDesigner
Open LiDar_Scanner_Realtime.toe.   
Click the OSC In DAT.   
Set the port.

#### In iOS
Run the application.   
Set IP address and port.   
Turn the realtime ON.   

See the Geometry Viewer in TouchDesigner.
