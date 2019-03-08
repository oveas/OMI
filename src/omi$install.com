$!*****
$! Find the distribution set
$!
$	i_am_here = f$environment("default")
$!
$ find_set:
$!
$	omi_set = f$search ("''i_am_here'omi-v*_*.*")
$	if omi_set .eqs. ""
$	   then
$		write sys$error "%OMI-W-NOSET, distribution set not found"
$		read /end=bye /prompt="_Location [''i_am_here']: " -
		   sys$command _here
$		if _here .nes. "" then $ i_am_here = _here
$		goto find_set
$	endif
$	set_type = f$parse(omi_set,,,"type")
$	if set_type .eqs. ".DIR" then $ goto find_set
$	if set_type .eqs. ".ZIP"
$	then
$		on warning then $ goto nozip
$		assign nla0: sys$output
$		assign nla0: sys$error
$		unzip
$		deassign sys$output
$		deassign sys$error
$		on warning then $ continue
$		write sys$error -
		   "%OMI-I-INS_ZIP, installing the ZIP distribution"
$		omi_unpack = "unzip ""-X"" "
$	   else
$		if set_type .eqs. ".COM"
$		   then
$			write sys$error -
			   "%OMI-I-INS_SHARE, installing the SHARE distribution"
$			omi_unpack = "@"
$ 		   else
$			write sys$error -
			   "%OMI-E-UNKNOWN_SET, distribution type unknown"
$			write sys$error -
			   "  /''f$parse(omi_set,,,"name")'''set_type'/"
$			goto bye
$ 		endif
$	endif
$!
$!*****
$! Get the install destination
$!
$ get_dest:
$!
$	def_dest = "''f$environment("default")'"
$	if f$trnlnm("omi$") .nes. "" then -
	   $ def_dest = f$trnlnm("omi$") - "]["
$	read /end=bye /prompt="_Install in [''def_dest']: " sys$command omi_dest
$	if omi_dest .eqs. "" then $ omi_dest = def_dest
$	if f$parse(omi_dest,,,,"syntax_only") .eqs. ""
$	   then
$		write sys$error "%OMI-E-INVDIR, invalid directory specification"
$		goto get_dest
$	endif
$	if f$parse(omi_dest) .eqs. ""
$	   then
$		read /end=bye -
		   /prompt="_Do you want to create this directory ? (Y/[N]): " -
		   sys$command create_dest
$		if f$edit(f$extract(0,1,create_dest),"upcase") .nes. "Y" then -
		   $ goto get_dest
$		assign nla0: sys$error
$		set noon
$		create /dir 'omi_dest' /protection=(s:rwe,o:rwed,g:rwe,w:re)
$		_status = $status
$		set on
$		deassign sys$error
$		if .not. _status
$		   then
$			write sys$error -
$			write sys$error f$message(_status)
				"%OMI-F-CREERR, error creating directory"
$			goto get_dest
$		endif
$	endif
$	omi_source = "[.''f$parse(omi_set,,,"name")']"
$!
$!*****
$! Unpack
$!
$	write sys$error "%OMI-I-UNPACK, please wait - unpacking distribution"
$	'omi_unpack''omi_set'
$	delete_ /confirm 'omi_set'
$!
$!*****
$! Copy & Cleanup
$!
$	if f$search("''omi_dest'omi$menu.com") .nes. ""
$	   then $ set_prot = 0
$	   else $ set_prot = 1
$	endif
$	if f$search("''omi_dest'omi$toolbox.ini") .nes. ""
$	   then
$		write sys$error "%OMI-I-EXISTS, OMI$TOOLBOX.INI exists"
$		gosub patch_toolbox_ini
$	endif
$	if f$search("''omi_dest'omi$menu.cfg") .nes. ""
$	   then
$		write sys$error "%OMI-I-EXISTS, OMI$MENU.CFG exists"
$		rename_ 'omi_source'omi$menu.cfg 'omi_source'omi$menu.cfg_new
$		write sys$error -
	   "-OMI-I-NEWNAME, installing new config file as OMI$MENU.CFG_NEW"
$	endif
$!
$	copy_ 'omi_source'*.*; 'omi_dest'*.*;0
$	delete_ 'omi_source'*.*;*
$	delete_ 'f$parse(omi_set,,,"name")'.dir;
$	if set_prot .eq. 1 then $ set file 'omi_dest'*.*; -
	   /protection=(s:rwe,o:rwed,g:re,w:re)
$!
$!*****
$! Install
$!
$	set default 'omi_dest'
$	write sys$error "%OMI-I-CREHELP, creating the help library"
$	if f$search("omi$menu.hlb") .nes. "" then $ delete_ omi$menu.hlb;*
$	library /help /create omi$menu omi$menu.hlp
$	library /help /insert omi$menu omi$calling_modules.hlp
$	library /help /insert omi$menu omi$commands.hlp
$	library /help /insert omi$menu omi$config_file.hlp
$	library /help /insert omi$menu omi$logicals.hlp
$	library /help /insert omi$menu omi$menu_file.hlp
$	set file /protection=(s:re,o:rwe,g:re,w:re) omi$menu.hlb
$!
$	write sys$error -
 "%OMI-I-MSGREPAIR, repairing the message datafiles - ignore BADMSGFIL messages"
$	if f$trnlnm("omi$menu_directory") .nes. ""
$	   then $ look_in = "omi$menu_directory:"
$	   else
$		if f$trnlnm("omi$") .nes. ""
$		   then $ look_in = "omi$:"
$		   else $ look_in = "[]"
$		endif
$	endif
$	files_that_need_repair = "/OMI/OMIMGT/"
$	cnt = 1
$	omi$_jumps = ""
$!
$ get_msg_files:
$!
$	message_file = f$search("''look_in'*$messages.dat;")
$	if message_file .eqs. "" then $ goto got_msg_files
$	if f$locate ("/''f$element(0,"$",f$parse(message_file,,,"name"))'/", -
	   files_that_need_repair) .lt. f$length(files_that_need_repair) then -
	   $ omi$_jumps = omi$_jumps + "9,''cnt',7,"
$	cnt = cnt + 1
$	goto get_msg_files
$!
$ got_msg_files:
$!
$	omi$_jumps = omi$_jumps + "exit"
$	@omi$menu omi$manage /submenu=messages /jumps='omi$_jumps' /batch
$	set default 'i_am_here'
$	write sys$error "%OMI-S-INSTALLED, OMI succesfully installed"
$	goto bye
$!
$ nozip:
$!
$	deassign sys$output
$	deassign sys$error
$	write sys$error "%OMI-E-NOZIP, unzip command not found - please download the SHARE distribution"
$	goto bye
$!
$ bye:
$!
$	exit
$!
$!*****
$! Patch the existing TOOLBOX.INI
$!
$ patch_toolbox_ini:
$!
$	open /read new_tb 'omi_source'omi$toolbox.ini
$	open /read old_tb 'omi_dest'omi$toolbox.ini
$	open /write p_tb 'omi_source'omi$toolbox.ini_new
$	in_omi_tb = 1
$!
$ read_new_tb:
$!
$	read /end_of_file=read_old_tb new_tb line
$	check=f$edit(line,"collapse,uncomment,upcase")
$	if check .eqs. "<EOF>" then $ goto read_old_tb
$	write p_tb line
$	goto read_new_tb
$!
$ read_old_tb:
$!
$	read /end_of_file=close_tb old_tb line
$	check=f$edit(line,"collapse,uncomment,upcase")
$	if check .eqs. ""
$	   then
$		write p_tb line
$		goto read_old_tb
$	endif
$	if f$extract(0,1,check) .eqs. "["
$	   then
$		if check .eqs. "[OMI$TOOLBOX]"
$		   then $ in_omi_tb = 1
$		   else $ in_omi_tb = 0
$		endif
$	endif
$	if in_omi_tb .eqs. 0 then $ write p_tb line
$	goto read_old_tb
$!
$ close_tb:
$!
$	close new_tb
$	close old_tb
$	close p_tb
$	delete_ 'omi_source'omi$toolbox.ini;
$	rename_ 'omi_source'omi$toolbox.ini_new 'omi_source'omi$toolbox.ini
$	write sys$error -
	   "-OMI-S-TBPATCHED, OMI$TOOLBOX.INI successfully patched"
$	return
