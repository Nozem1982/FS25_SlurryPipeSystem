## Fill Arm Setup

Add a new folder into configs/vehicleConfigs. 
##ATTENTION## 
##THIS FOLDER MUST BE NAMED THE EXACT NAME OF THE VEHICLE XML OR IT WILL NOT WORK. 
##YOU CAN ADD A FOLDER IN A FOLDER BUT THE NODETREE AND FILLPOINTS XML MUST BE INSIDE THE FOLDER THAT HAS THE VEHICLE XML NAME.

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
The rotation of the SPS_fillArmTip01 or SPS_fillArmCentre01 does not matter, just the position.

![SPS node dropped back to fillArms, keeping the loadingArm03 rotation and position](images/Pic6.png)

6. Then remove the vehicle from the i3d and save as nodeTree.i3d in your newly created folder.

7. Now add in the parts of the fillPoints xml that are relevent for you vehicle (follow other files) and add the fill speed from the veh xml.

![Set fill speed from the vehicle xml](images/Pic7.png)

## Rubber Boot Setup

1. Now follow the same process for the rubber boot, first find the mesh that the rubber boot is part of. In the FRC65 it is the frc_vis.

![Set the rubber boot node the same as the parent from the i3d and the same location](images/Pic8.png)

2. Name the rubberBootNode to the same name 

![Same name](images/Pic9.png)

3. Place the lower and upper nodes in the middle of the rubber boot. Upper at the top of the boot, lower at the lower part.

![Place the nodes, rotation is not important](images/Pic10.png)

4. Remove docking station it not wanted.

RubberBoot done.

## Pipe Coupler Setup

1. Like the rubber boot, you need to find the the mesh name for the couplers. In the frc65 it is the same frc65_vis.
Add as many couplers as you like and add a number.

![Name must match parent also same loaction, rotation](images/Pic11.png)

2. At this point I would suggest adding the pipe from the i3d so you can position the coupler node correctly.
Then drag the pipe into the SPS_pipeCoupler01 node.

![Add the pipe from the i3d folder (Remove when done)](images/Pic12.png)
![Add pipe to the pipeCoupler node](images/Pic13.png)

This is important.. The blue arrow of SPS_pipeCouplerxx must face into the coupler as seen in the pic.
Repeat this part for each coupler making sure to move only the SPS_pipeCouplerxx and not the pipe.

![Position pipe by moving the SPS_pipeCouplerxx node](images/Pic14.png)

## Pump Control

1. As above, use the main vis node name 

![](images/Pic15.png)

2. rearControlNode can be positoned anywhere that the user feels is most likely to have outside controls.
The TSA tanker (pictured) is in the rear left corner.
Node rotation does not matter. 

![](images/Pic16.png)