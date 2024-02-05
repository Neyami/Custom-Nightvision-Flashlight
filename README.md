Adds customizable flashlight and nightvision  
Edit flcolors.txt to add/remove colors.

# Commands
.flashlight      - Toggles custom flashlight on/off with default values  
.flashlight help - Prints information about the command to console  
.flashlight color - Toggles the flashlight with the chosen color from the list. Default is white if no color is specified  
.flashlight list - Prints flashlight colors to console  
.flashlight r g b - Toggles the flashlight with custom RGB-values  
.flashlight random - Toggles the flashlight with random RGB  
.flashlight randomcolor - Toggles the flashlight with a random color from the list  
.flashlight rainbow - Toggles the flashlight with shifting colors  

<BR>

.nightvision      - Toggles custom nightvision on/off with default values  
.nightvision help - Prints information about the command to console  
.nightvision color - Toggles nightvision with the chosen color from the list. Default is green if no color is specified  
.nightvision list - Prints nightvision colors to console  
.nightvision r g b - Toggles nightvision with custom RGB-values  
.nightvision random - Toggles nightvision with random RGB  
.nightvision randomcolor - Toggles nightvision with a random color from the list  
.nightvision rainbow - Toggles nightvision with shifting colors  

<BR>

.fl_radius (#)    -  Sets the corresponding CVar.  
.nv_radius (#)    -  Sets the corresponding CVar.  
.flnv_drain (#)   -  Sets the corresponding CVar.  
.flnv_charge (#)  -  Sets the corresponding CVar.

<BR>

# CVars
Can be put in server and map configs

as_command .fl-radius (#)    -  Size of the flashlight light. (default: 9)  
as_command .nv-radius (#)    -  Size of the nightvision light. (default: 40)  
as_command .flnv-drain (#)   -  Rate at which the battery drains. (default: 1.2)  
as_command .flnv-charge (#)  -  Rate at which the battery charges. (default: 0.2)
