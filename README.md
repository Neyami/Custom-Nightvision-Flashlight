Adds customizable flashlight and nightvision


# Commands
.flashlight  
.flashlight color - Toggles the flashlight. Default is white if no color is specified  
.flashlight help - Prints flashlight colors to console  
.flashlight list - Prints flashlight colors to console  
.flashlight r g b - Toggles the flashlight with custom RGB-values  
.flashlight random - Toggles the flashlight with random RGB  
.flashlight randomcolor - Toggles the flashlight with a random color from the list  
.flashlight rainbow - Toggles the flashlight with shifting colors  

<BR>

.nightvision  
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
