$! Small wrapper for OMI$MENU.COM that functions as a try-catch.
$! Mainly meant for debugging purposes.
$!
$	env_msg = f$environment("message")
$	env_prc = f$environment("procedure")
$	env_prc = f$parse(env_prc,,,"device") + f$parse(env_prc,,,"directory")
$	@'env_prc'omi$menu.com 'p1' 'p2' 'p3' 'p4' 'p5' 'p6' 'p7' 'p8' 
$	_status = $status
$	if .not. _status
$	   then
$		set message 'env_msg'
$		write sys$error ""
$		write sys$error "%OMI-F-CRASH, unexpected exit with code ''_status':"
$	endif
$	exit _status
