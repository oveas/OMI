$!
$! Simple tool to help building the OMI version.
$! Oscar van Eijk, October 4, 2018
$!
$! Note: The symbols or foreign commands ZIP and VMS_SHARE must exist!
$!
$	omiSource = F$Search("OMI-V*.DIR")
$	if omiSource .eqs. ""
$	   then
$		write sys$output "No OMI version found - make sure the directory OMI-Vx_y exists"
$		exit %x28
$	endif
$	omiSource = F$Parse(omiSource,,,"NAME")
$	omiVersion = omiSource - "OMI-"
$	write sys$output "Start building distribution for OMI ''omiVersion'..."
$!
$	vms_share [.'omiSource']*.*; omi-'omiVersion' /part_size=1500
$	zip "-V" OMI-'omiVersion'.ZIP [.'omiSource']*.*
$!
$	create /directory [.omi_distro]
$	rename /nolog omi-'omiVersion'.1-OF-1; [.omi_distro]omi-'omiVersion'.com
$	rename /nolog omi-'omiVersion'.zip [.omi_distro]
$	copy /nolog [.'omiSource']readme.txt [.omi_distro]
$	copy /nolog [.'omiSource']freeware_readme.txt [.omi_distro]
$	copy /nolog [.'omiSource']omi$install.com [.omi_distro]
$	directory\ /col=1 [.omi_distro]
$!
$	exit
