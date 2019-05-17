$!
$! Simple tool to help building the OMI version.
$! Oscar van Eijk, October 4, 2018
$!
$! Note: The symbol or foreign command ZIP must exist!
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
$	zip "-V" OMI-'omiVersion'.ZIP [.'omiSource']*.* -x *build_kit.com
$!
$	create /directory [.omi_distro]
$	rename /nolog omi-'omiVersion'.zip [.omi_distro]
$	copy /nolog [.'omiSource']readme.txt [.omi_distro]
$!	copy /nolog [.'omiSource']freeware_readme.txt [.omi_distro]
$	copy /nolog [.'omiSource']omi$install.com [.omi_distro]
$	directory\ /col=1 [.omi_distro]
$!
$	exit
