This is a simple controller for Celestron AstroFi telescope mounts based on a PIC16F1825 mc. 
You can control the telescope simply via a thumbstick. 
There are 5 speed rates available for every direction (up/down/left/right). But there are no comfort features
like "go to" or "automatic tracing". Its possible to work parallel with the ceslestron skyportal app.
The conection to the telescope is made by a 6 wire rj12 cable to the aux-1 plug of the mount. The controller 
has a RJ12 plug on the pcb. The power for the controller is supplied by the telescope-mount (<5mA). 
The initial speed setting after poweron is the faster mode, wich means you can select the speed-rates 6, 7 and 9 via
the position of the thumbstick. Pressing the button of the thumbstick change to the slower mode with the speed-rates 
3,4 and 6. The modes are toggled with every press of the thumbstick-button.

files:

PicAstro.asm        Assemblerfile with the program for the PIC16F1825.

PicAstro-Kicad.zip  Projectfolder with KiCad-Files for the PCB. 
