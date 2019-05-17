$	omi$_message = f$environment("message")
$	i_am_here = f$environment("default")
$	exit_status = %x1
$	on control_y then $ goto user_abort
$	goto start$
$!
$!******************************************************************************
$!*                                                                            *
$!*  FILENAME:                                                                 *
$!*  =========                                                                 *
$!*     Omi$Install.Com       Installer for OMI - Oscar's Menu Interface       *
$!*                                                                            *
$!*  DESCRIPTION:                                                              *
$!*  ============                                                              *
$!*      This tool unpacks the OMI distribution kit and installs it in the     *
$!*      requested location.                                                   *
$!*                                                                            *
$!*      After the installation, OMI$USER_INSTALL should be called for every   *
$!*      user or systemwide (see documentation) to give users access to OMI.   *
$!*                                                                            *
$!*  FILES NEEDED:                                                             *
$!*  =============                                                             *
$!*     OMI-Vx_y.ZIP          The OMI distribution kit as a ZIP file           *
$!*                                                                            *
$!******************************************************************************
$!
$ start$:
$	gosub get_distribution_set
$	gosub get_destination
$	gosub unpack_kit
$	gosub copy_files
$	set default 'omi_dest'
$	gosub install_kit
$	set default 'i_am_here'
$	write sys$error "%OMI-S-INSTALLED, OMI succesfully installed"
$	goto bye
$!-----

$!-----
$! Error and exit routines
$ nozip:
$!
$	set message 'omi$_message
$	write sys$error "%OMI-E-NOZIP, unzip command not found - please download the SHARE distribution"
$	exit_status = %x2c
$	goto bye
$!
$ user_abort:
$	write sys$error "%OMI-W-ABORT, installation aborted by the user"
$	exit_status = %x28
$	goto bye
$!
$ bye:
$	exit 'exit_status'
$!-----

$!-----
$! Find the distribution set. This must be a .ZIP, named OMI-Vx_y.ZIP,
$! where x_y is the OMI version
$!
$ get_distribution_set:
$	omi_set = f$search ("''i_am_here'omi-v*_*.zip")
$	if omi_set .eqs. ""
$	   then
$		write sys$error "%OMI-W-NOSET, distribution set not found"
$		read /end=bye /prompt="_Location [''i_am_here']: " sys$command _here
$		if _here .nes. "" then $ i_am_here = _here
$		goto get_distribution_set
$	endif
$	on warning then $ goto nozip
$	set message /nofacility /noseverity /noidentification /notext
$	assign /user nla0: sys$output
$	unzip
$	set message 'omi$_message'
$	on warning then $ continue
$	write sys$error "%OMI-I-INS_ZIP, installing the ZIP distribution"
$	omi_unpack = "unzip ""-X"" "
$	return
$!-----

$!-----
$! Get the install destination
$!
$ get_destination:
$!
$	def_dest = "''f$environment("default")'"
$	if f$trnlnm("omi$") .nes. "" then $ def_dest = f$trnlnm("omi$") - "]["
$	read /end=user_abort /prompt="_Install in [''def_dest']: " sys$command omi_dest
$	if omi_dest .eqs. "" then $ omi_dest = def_dest
$	if f$parse(omi_dest,,,,"syntax_only") .eqs. ""
$	   then
$		write sys$error "%OMI-E-INVDIR, invalid directory specification"
$		goto get_destination
$	endif
$	if f$parse(omi_dest) .eqs. ""
$	   then
$		read /end=user_abort sys$command create_dest -
		   /prompt="_Do you want to create this directory ? (Y/[N]): "
$		if f$edit(f$extract(0,1,create_dest),"upcase") .nes. "Y" then $ goto get_dest
$		set noon
$		create /directory 'omi_dest' /protection=(s:rwe,o:rwed,g:rwe,w:re)
$		_status = $status
$		set on
$		if .not. _status
$		   then
$			write sys$error "%OMI-F-CREERR, error creating directory"
$			write sys$error f$message(_status)
$			goto get_destination
$		endif
$	endif
$	omi_source = "[.''f$parse(omi_set,,,"name")']"
$	return
$!-----

$!-----
$! Unpack the distribution kit.
$!
$ unpack_kit:
$	write sys$error "%OMI-I-UNPACK, please wait - unpacking distribution"
$	'omi_unpack''omi_set'
$	delete\ /confirm 'omi_set'
$	return
$!-----

$!-----
$! Copy all files to the destination and cleanup the distribution directory.
$!
$ copy_files:
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
$		write sys$error "-OMI-I-NEWNAME, installing new config file as OMI$MENU.CFG_NEW"
$		copy\ 'omi_source'omi$menu.cfg 'omi_source'omi$menu.cfg_new
$		delete\ 'omi_source'omi$menu.cfg;
$	endif
$!
$	copy\ 'omi_source'*.*; 'omi_dest'*.*;0
$	delete\ 'omi_source'*.*;*
$	delete\ 'f$parse(omi_set,,,"name")'.dir;
$	if set_prot .eq. 1 then $ set file 'omi_dest'*.*; /protection=(s:rwe,o:rwed,g:re,w:re)
$	return
$!-----

$!-----
$! Finish the installation
$!
$ install_kit:
$! (Re)build the Help library
$	write sys$error "%OMI-I-CREHELP, creating the help library"
$	if f$search("omi$menu.hlb") .nes. "" then $ delete\ omi$menu.hlb;*
$	library /help /create omi$menu omi$menu.hlp
$	library /help /insert omi$menu omi$calling_modules.hlp
$	library /help /insert omi$menu omi$commands.hlp
$	library /help /insert omi$menu omi$config_file.hlp
$	library /help /insert omi$menu omi$logicals.hlp
$	library /help /insert omi$menu omi$menu_file.hlp
$	set file /protection=(s:re,o:rwe,g:re,w:re) omi$menu.hlb
$!
$! Repair the message files
$	write sys$error "%OMI-I-MSGREPAIR, repairing the message datafiles - ignore BADMSGFIL messages"
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
$	message_file = f$search("''look_in'*$messages.dat;")
$	if message_file .eqs. "" then $ goto got_msg_files
$	if f$locate ("/''f$element(0,"$",f$parse(message_file,,,"name"))'/", -
	   files_that_need_repair) .lt. f$length(files_that_need_repair) then -
	   $ omi$_jumps = omi$_jumps + "9,''cnt',7,"
$	cnt = cnt + 1
$	goto get_msg_files
$!
$ got_msg_files:
$	omi$_jumps = omi$_jumps + "exit"
$	@omi$menu omi$manage /submenu=messages /jumps='omi$_jumps' /batch
$	return
$!-----

$!-----
$! An existing TOOLBOX.INI has been found in the destination directory.
$! Don't overwrite it, but patch it with the new version if necessary.
$!
$ patch_toolbox_ini:
$	open /read new_tb 'omi_source'omi$toolbox.ini
$	open /read old_tb 'omi_dest'omi$toolbox.ini
$	open /write p_tb 'omi_source'omi$toolbox.ini_new
$	in_omi_tb = 1
$!
$ read_new_tb:
$	read /end_of_file=read_old_tb new_tb line
$	check=f$edit(line,"collapse,uncomment,upcase")
$	if check .eqs. "<EOF>" then $ goto read_old_tb
$	write p_tb line
$	goto read_new_tb
$!
$ read_old_tb:
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
$	close new_tb
$	close old_tb
$	close p_tb
$	delete\ 'omi_source'omi$toolbox.ini;
$	rename\ 'omi_source'omi$toolbox.ini_new 'omi_source'omi$toolbox.ini
$	write sys$error "%OMI-S-TBPATCHED, OMI$TOOLBOX.INI successfully patched"
$	return
$!-----
