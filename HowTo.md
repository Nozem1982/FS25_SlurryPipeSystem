## Fill Arm Setup

1. Select the vehicle you are adding SPS to and open the example i3d, the example xml, and the vehicle xml.

2. Import the vehicle into the example i3d. If the vehicle has multiple configurations, 
hide any that are not relevant — in this example the OXBO has both a slurry and manure layout, so the manure configuration is hidden.

![OXBO imported into example i3d with manure config hidden](images/Pic1.png)
![Manure config hidden](images/Pic2.png)

3. To set up the fill arm, find the last node in the arm hierarchy that the tip follows. 
On the OXBO this is `loadingArm03` — rotating this node moves the tip, which means SPS must follow this same path.

![Selecting loadingArm03 in the scene tree](images/Pic3.png)

4. The easiest way to position the SPS fill arm node correctly is to middle-mouse drag and drop it onto `loadingArm03` in the scene tree, 
then zero out all translation and rotation values. This is a critical step — the SPS node must share the exact same name, 
position and rotation as the node it is linked to, otherwise it will not work.

![Select the correct node to move onto loadingArm03](images/Pic4.png)
![SPS node dropped onto loadingArm03 with zeroed transforms](images/Pic5.png)

5. Move the now renamed and zero positoned node back from loadingArm03 to fillArmNodes while maintaing the exact position of loadingArm03, then
move the SPS_fillArmTip01 or SPS_fillArmCentre01 to the correct position on tip of the arm. 

![SPS node dropped back to fillArms, keeping the loadingArm03 rotation and position](images/Pic6.png)