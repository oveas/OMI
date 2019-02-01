$	goto start$
$!
$!******************************************************************************
$!*                                                                            *
$!*    MODULE NAME:                                                            *
$!*    ============                                                            *
$!*      Omi$Config.Com                                                        *
$!*                                                                            *
$!*    CALLED BY:                                                              *
$!*    ==========                                                              *
$!*      Omi$Menu.Com                                                          *
$!*      Omi$Edit_Cmd.Com                                                      *
$!*                                                                            *
$!*    DESCRIPTION:                                                            *
$!*    ============                                                            *
$!*      This module reads and interprets the configuration- and menu files,   *
$!*      and takes care of all updates via the SET and EDIT commands.          *
$!*                                                                            *
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Open and read the configuration file for the current user
$!
$ start$:
$!
$	if p1 .eqs. "SETUP"
$	   then
$		_config_file = f$trnlnm("Omi$Config")
$		if _config_file .eqs. "" then $ _config_file = "Sys$Login:Omi$Menu.Cfg"
$		if f$search("''_config_file'") .eqs. "" then -
		   $ _config_file = "Omi$:Omi$Menu.Cfg"
$		if f$search("''_config_file'") .eqs. ""
$		   then
$			if p3 .nes. "CLEANUP"
$			   then
$				write sys$error "%OMI-W-NOCFG, Configuration file OMI$MENU.CFG not found"
$				write sys$error "-OMI-I-DEFCFG, using default configuration settings"
$			endif
$			gosub config$_defaults
$			exit
$		endif
$	endif
$	if p1 .eqs. "MENU"
$	   then
$		_config_file = p2
$		if _config_file .eqs. ""
$		   then
$			if p3 .nes. "CLEANUP"
$			   then
$				if f$type(omi$current_menu) .eqs. "" then -
				   $ omi$call list_files omi$menu_directory:*.mnu name
$				omi$signal omi nomenu
$			endif
$			exit omi$_warning
$		endif
$		if p4 .eqs. "OMI$INCLUDE"
$		   then $ _config_file = f$parse(_config_file,".OML")
$		   else $ _config_file = f$parse(_config_file,".MNU")
$		endif
$		_config_file = f$parse(_config_file,,,"name") + f$parse(_config_file,,,"type")
$		if f$trnlnm("Omi$Menu_Directory") .nes. ""
$		   then
$			if f$search("Omi$Menu_Directory:''_config_file'") .nes. ""
$		           then $ _config_file = "Omi$Menu_Directory:''_config_file'"
$		           else $ _config_file = "Omi$:''_config_file'"
$			endif
$	           else $ _config_file = "Omi$:''_config_file'"
$		endif
$		omi$menu_location == f$element(0,":",_config_file) + ":"
$	endif
$!
$	if f$search("''_config_file'") .eqs. ""
$	   then
$		if p3 .nes. "CLEANUP"
$		   then
$			if f$type(omi$current_menu) .eqs. "" then -
			   $ omi$call list_files omi$:*.mnu,omi$menu_directory:*.mnu name
$			omi$signal omi mnunotfound,'_config_file'
$		endif
$		exit omi$_warning
$	endif
$!
$	if p3 .eqs. "VALIDATE" .and. p4 .nes. "OMI$INCLUDE"
$	   then
$		if validate$log_file .eqs. ""
$		   then $ wval := write sys$error
$		   else
$			open /write /error=validate$fopenerr val_log 'validate$log_file
$			wval := write val_log
$		endif
$		val$_warnings = 0
$		val$_errors = 0
$		lead$_values = 0
$	   else $ if omi$validate_mode then $ lead$_values = 0
$	endif
$!
$	if f$type(omi$progress) .nes. ""
$	   then
$		if .not. omi$progress
$		   then $ main$show_progress == 0
$		   else $ main$show_progress == 1
$		endif
$	endif
$	if f$type(main$show_progress) .nes. ""
$	   then
$		if p1 .nes. "MENU" .or. p3 .eqs. "CLEANUP" .or. -
		   p3 .eqs. "SETCMD" .or. p3 .eqs. "UPDATE" .or. -
		   p3 .eqs. "VALIDATE" then $ main$show_progress == 0
$		if main$show_progress then $ gosub setupmnu$_get_size
$	endif
$!
$	if p3 .eqs. "SETCMD" .or. p3 .eqs. "UPDATE"
$	   then
$		open /write omi_config sys$scratch:omi$mnufile_update._tmp$
$		omi$signal omi writing,'_config_file
$	endif
$	if p4 .eqs. "OMI$INCLUDE"
$	   then $ cfg$including = 1
$	   else $ cfg$including = 0
$	endif
$	if cfg$including
$	   then $ open /read /share=write omi$confinclu '_config_file
$	   else $ open /read /share=write omi$configure '_config_file
$	endif
$	_section = "main"
$	_update_written = 0
$	_cont_line = 0
$	if cfg$including
$	   then $ main$show_progress = 0
$	   else $ lead$_values == ""
$	endif
$!
$ readcfg$_loop:
$!
$	if cfg$including
$	   then $ read /end_of_file=readcfg$end_loop omi$confinclu _config
$	   else $ read /end_of_file=readcfg$end_loop omi$configure _config
$	endif
$	if f$type(main$show_progress) .nes. ""
$	   then
$		if main$show_progress
$		   then
$			_number_of_lines_read = _number_of_lines_read + 100
$			_percent = _number_of_lines_read / mnu$lines
$!			omi$signal omi readmnu,_percent
$			omi$display_message -
			 "%OMI-I-READMNU, reading menu file - ''_percent'% done"
$		endif
$	endif
$!
$!-->	Include library
$!
$	if f$edit(f$element(0, " ", f$edit(_config, "trim,compress")), -
	   "upcase") .eqs. "#INCLUDE"
$	   then
$		if (p3 .nes. "CLEANUP" .and. p3 .nes. "") .and. -
		   p2 .nes. "MENU" then $ goto readcfg$_loop
$		if cfg$including
$		   then
$			if p3 .nes. "CLEANUP"
$			   then
$				omi$msgline_clear
$				omi$signal omi nestincl
$				omi$wait
$			endif
$			goto readcfg$_loop
$		endif
$		_include_file = f$parse(f$edit(f$element(1, " ", -
		   f$edit(_config, "trim,compress")),"upcase"),,,"name")
$		if f$search("omi$menu_directory:''_include_file'.oml") .eqs. ""
$		   then
$			if p3 .nes. "CLEANUP"
$			   then
$				omi$signal omi inclfnf,"''_include_file'.OML"
$				if main$show_progress then $ omi$wait
$			endif
$		   else $ @'f$environment("procedure") "''p1'" "''_include_file'" -
			   "''p3'" omi$include 
$		endif
$		goto readcfg$_loop
$	endif
$!
$	if p3 .eqs. "SETCMD"
$	   then 
$		gosub config$_setcmd
$		goto readcfg$_loop
$	endif
$!
$	if p3 .eqs. "UPDATE"
$	   then 
$		gosub config$_update
$		goto readcfg$_loop
$	endif
$!
$	_config = f$edit(_config,"uncomment,compress,trim")
$	if _config .eqs. "" then $ goto readcfg$_loop
$!
$	if _cont_line
$	   then
$		_config = _stored + _config
$		_cont_line = 0
$	endif
$!
$ 	if f$extract(f$length(_config) - 1, 1, _config) .eqs. "-"
$ 	   then
$ 		_stored = f$edit(f$extract(0, f$length(_config) - 1, _config),"trim")
$ 		_cont_line = 1
$ 		goto readcfg$_loop
$ 	endif
$!
$	if f$edit(_config,"upcase") .eqs. "<EOF>" then $ goto readcfg$end_loop
$	if f$extract(0, 1, _config) .eqs. "["
$	   then
$		_section = f$edit(f$extract(1, f$length(_config) - 2, -
		   _config), "upcase")
$		if f$extract(0, 5, _section) .eqs. "MENU_"
$		   then
$			_section = _section - "MENU_"
$			block$type_menu = 1
$		   else $ block$type_menu = 0
$		endif
$		goto readcfg$_loop
$	endif                                
$	_item  = f$edit(f$element(0, "=", _config), "trim")
$	_value = f$edit((_config - _item - "="), "trim")
$	_item  = f$edit(_item,"trim,upcase")
$	if f$element(1, "#", _item) .eqs. "LEADING"
$	   then
$		_item = f$element(0, "#", _item)
$		lead$_bool = 1
$	   else $ lead$_bool = 0
$	endif
$	if p3 .eqs. "CLEANUP"
$	   then
$		if f$type('_section'$'_item') .nes. "" then -
		   $ delete\/symbol/global '_section'$'_item'
$	   else
$		if _section .eqs. "SCREEN" .and. _value .le. 0 -
		   .and. (_item .eqs. "WIDTH" .or. _item .eqs. "EXIT_WIDTH" .or. -
		   _item .eqs. "HEIGHT" .or. _item .eqs. "EXIT_HEIGHT")
$		   then
$			if _item .eqs. "HEIGHT" .or. _item .eqs. "EXIT_HEIGHT"
$			   then
$				_value = f$getdvi("tt:", "tt_page")
$				if _item .eqs. "HEIGHT" then $ screen$height_inquired == "true"
$			   else
$				_value = f$getdvi("tt:", "devbufsiz")
$				if _item .eqs. "WIDTH" then $ screen$width_inquired == "true"
$			endif
$		endif
$		if f$type('_section'$'_item') .nes. "" .and. p3 .nes. -
		   "VALIDATE" .and. f$locate ("<''_section'$''_item'>", -
		   lead$_values) .eq. f$length(lead$_values)
$		   then
$			if .not. lead$_bool
$			   then
$				if omi$validate_mode
$				   then
$					lead$_value'lead$_values' == "[''_section']:''_item'"
$					lead$_values = lead$_values + 1
$				   else
$					if f$locate("ignore=dupl", omi$steering) .eq. f$length(omi$steering)
$					   then
$						_message = "%OMI-W-DUPL, duplicate item encountered"
$						if f$type(omi$display_message) .nes. ""
$						   then
$							_ovw_encountered = 1
$							_prpos   = "''ESC$'[''screen$line_command';''screen$default_position'H"
$							omi$display_message _message
$						   else
$							_prpos   = ""
$							write sys$error _message
$						endif
$					   else
$						_overwrite_all = 1
$					endif
$					if f$type(_overwrite_all) .eqs. "" then $ _overwrite_all = 0
$					if .not. _overwrite_all
$					   then
$						read /end_of_file=config$_dont_overwrite -
 						   /prompt="''_prpos'Overwrite [''_section']:''_item' ? (Y/[N]/A) " sys$command _overwrite
$						if f$edit(f$extract(0,1,_overwrite),"upcase") .eqs. "A"
$						   then
$							_overwrite = "Y"
$							_overwrite_all = 1
$						endif
$						if .not. _overwrite then $ goto config$_dont_overwrite
$					endif
$				endif
$			endif
$		endif
$		if p1 .eqs. "MENU" .and. p3 .eqs. "VALIDATE"
$		   then $ gosub config$validate_mnuline
$		   else
$			if f$locate ("<''_section'$''_item'>", -
		   	   lead$_values) .eq. f$length(lead$_values)
$			   then
$				if lead$_bool then -
				   lead$_values == lead$_values + "<''_section'$''_item'>"
$				if f$type(_value) .eqs. "INTEGER"
$				   then $ '_section'$'_item' == f$integer(_value)
$				   else $ '_section'$'_item' == "''_value'"
$				endif
$			endif
$		endif
$	endif
$!
$ config$_dont_overwrite:
$!
$	if f$type(_ovw_encountered) .nes. ""
$	   then
$		delete\ /symbol /local _ovw_encountered
$		omi$cmdline_clear
$		omi$msgline_clear
$	endif
$	goto readcfg$_loop
$!
$ readcfg$end_loop:
$!
$	if cfg$including
$	   then $ close omi$confinclu
$	   else
$		close omi$configure
$		if f$type(lead$_values) .nes. "" then -
		   $ delete\ /symbol /global lead$_values
$	endif
$	if p1 .eqs. "SETUP" then $ gosub config$_defaults
$	if p3 .eqs. "SETCMD" .or. p3 .eqs. "UPDATE"
$	   then
$		close omi_config
$		_ren_to = f$element (0, ";", f$search (_config_file))
$		copy /nolog sys$scratch:omi$mnufile_update._tmp$ '_ren_to';0
$		delete /nolog /noconfirm sys$scratch:omi$mnufile_update._tmp$;*
$		if p5 .eqs. "RESET" then -
		   delete\/symbol/global 'omi$current_menu'$'p4'
$		omi$msgline_clear
$	endif
$!
$	if  p1 .eqs. "MENU" .and. f$type(menu$item1) .eqs. "" .and. -
	   f$type(menu$input1) .eqs. "" .and. p3 .nes. "CLEANUP"
$	   then
$		omi$signal omi badmnu
$		exit omi$_error
$	endif
$	if p3 .eqs. "CLEANUP" .and. f$type(omi$menu_location) .nes. "" -
	   then $ delete\ /symbol /global omi$menu_location
$!
$	if p3 .eqs. "VALIDATE"
$	   then
$		if val$_errors .eq 0 .and. val$_warnings .eq. 0
$		   then $ omi$signal omi valok
$		   else $ omi$signal omi valresult,'val$_errors,'val$_warnings
$		endif
$!
$		if validate$log_file .nes. ""
$		   then
$			close val_log
$			if val$_errors .eq 0 .and. val$_warnings .eq. 0 then -
			   $ delete\ /nolog /noconfirm f$search('validate$log_file)
$		endif
$		
$	endif
$	exit omi$_ok
$!
$ validate$fopenerr:
$!
$	omi$signal omi vallogerr,'validate$log_file
$	exit $status
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	When OMI is called with the qualifier /VALIDATE, the menu- file is read
$!	for the second time, checking each line for errors and/or warnings.
$!
$ config$validate_mnuline:
$!
$	_item = f$edit(_item, "upcase")
$	if f$type('_section'$'_item') .eqs. ""
$	   then
$		wval "Error - element ''_item' in section ''_section' has not been defined", F$Fao("!/"),
		   "        Unknown error - might be in the previous line"
$		val$_errors = val$_errors + 1
$		return
$	endif
$	if _value .eqs. ""
$	   then
$		_tmpaddln = ""
$		if block$type_menu then $ _tmpaddln = "MENU_"
$		wval "Warning - element ''_item' in section ''_tmpaddln'''_section' has no value"
$		val$_warnings = val$_warnings + 1
$		return
$	endif
$!
$!-->	Skip the following if we've got leading values here
$!
$	if lead$_bool then $ goto val$_leading_dupl
$!
$!-->	Check for different values
$!
$	if '_section'$'f$element (0, "#", _item)' .nes. _value
$	   then
$		wval "Warning - element ''_item' in section ''_section' has been defined with another value"
$		wval "          This is oke if the first value was LEADING"
$		val$_warnings = val$_warnings + 1
$	endif
$!
$!-->	Check for duplicate values
$!
$	if f$type (lead$_value'lead$_values') .nes. ""
$	   then
$		if f$edit(lead$_value'lead$_values',"upcase") .eqs. -
		   f$edit("[''_section']:''_item'","upcase")
$		   then 
$			wval "Warning - element ''_item' in section ''_section' has been defined twice"
$			val$_warnings = val$_warnings + 1
$			delete\ /symbol /global lead$_value'lead$_values'
$			lead$_values = lead$_values + 1
$		endif
$	endif
$!
$ val$_leading_dupl:
$!
$	if .not. block$type_menu then $ return
$	if f$edit(f$extract(0,4,_item), "upcase") .eqs. "ITEM" then -
	   $ goto validate$_item
$	if f$edit(f$extract(0,5,_item), "upcase") .eqs. "INPUT" then -
	   $ goto validate$_input
$!
$	return
$!
$!******************************************************************************
$!
$!	Validate the Item element
$!
$ validate$_item:
$!
$	_this_element = "ITEM"
$	gosub validate$_seq_order
$	_this_item_type  = f$edit(f$element (1, "#", _value), "upcase")
$	_this_item_value = f$edit(f$element (2, "#", _value), "upcase")
$	if _this_item_type .eqs. "SUBMENU" then $ goto validate$_submenu
$	if _this_item_type .eqs. "CALL"    then $ goto validate$_call
$	if _this_item_type .eqs. "COMMAND" then $ goto validate$_command
$	wval "Error - invalid item type ''_this_item_type' for ''_item' in section MENU_''_section'"
$	val$_errors = val$_errors + 1
$	return
$!
$!******************************************************************************
$!
$!	Validate the Submenu item type
$!
$ validate$_submenu:
$!
$	if _this_item_value .eqs. "" .or. _this_item_value .eqs. "#"
$	   then
$		wval "Error - no submenu specified in element ''_item' in section MENU_''_section'"
$		val$_errors = val$_errors + 1
$		return
$	endif
$!
$	if f$extract(0, 1, _this_item_value) .nes. ""
$	   then
$		if f$type('_this_item_value'$item1) .eqs. "" .and. -
		   f$type('_this_item_value'$input1) .eqs. ""
$		   then
$			wval "Error - element ''_item' in section MENU_''_section' calls an non- existing", F$Fao("!/"),
			   "        submenu ''_this_item_value'"
$			val$_errors = val$_errors + 1
$		endif
$		return
$	endif
$	_mnuc = 0
$!
$ validate$dyn_submenu:
$!
$	if f$locate ("}", _this_item_value) .eq. f$length(_this_item_value) -
	   then $ return
$	_this_dyn_menu = f$element(_mnuc, "}", _this_item_value)
$	_this_item_value = _this_item_value - _this_dyn_menu - "}"
$	_this_dyn_menu = _this_dyn_menu - "{"
$	if f$locate("|", _this_dyn_menu) .eq. f$length(_this_dyn_menu)
$	   then
$		wval "Warning - no text-on-display for dynamic submenu ''_this_dyn_menu'", F$Fao("!/"),
		   "          in element ''_item' in section MENU_''_section'"
$		val$_warnings = val$_warnings + 1
$	   else $ _this_dyn_menu = f$element(1, "|", _this_dyn_menu)
$	endif
$!
$	if f$type('_this_item_value'$item1) .eqs. "" .and. -
 	   f$type('_this_item_value'$input1) .eqs. ""
$	   then
$		wval "Error - element ''_item' in section MENU_''_section' calls an non- existing", F$Fao("!/"), -
		   "        dynamic submenu ''_this_item_value'"
$		val$_errors = val$_errors + 1
$	endif
$!
$	goto validate$dyn_submenu
$!
$!******************************************************************************
$!
$!	Validate the Call item type
$!
$ validate$_call:
$!
$	if _this_item_value .eqs. "" .or. _this_item_value .eqs. "#"
$	   then
$		wval "Error - no module called in element ''_item' in section MENU_''_section'"
$		val$_errors = val$_errors + 1
$		return
$	endif
$!
$! The Parse command below might return an empty string if the module name
$! contains variables. The Main Menu has a workaround for this, this is not
$! required here.
$	_called_module = f$search(f$parse(_this_item_value, "Omi$Menu_Directory:.Omi"))
$	if _called_module .eqs. "" then $ _called_module = f$search(f$parse(_this_item_value, "Omi$:.Omi"))
$	if _called_module .eqs. ""
$	   then
$		wval "Warning - element ''_item' calls a non- existing module in section MENU_''_section'"
$		val$_warnings = val$_warnings + 1
$		return
$	endif
$!
$	return
$!
$!******************************************************************************
$!
$!	Validate the Command item type
$!
$ validate$_command:
$!
$	if _this_item_value .eqs. "" .or. _this_item_value .eqs. "#"
$	   then
$		wval "Error - no command given in element ''_item' in section MENU_''_section'"
$		val$_errors = val$_errors + 1
$		return
$	endif
$	_this_command = f$element(0, " ", _this_item_value)
$!
$	if f$length(_this_command) .lt. 3
$	   then
$		wval "Warning - command ''_this_command' too short in element ''_item' in section MENU_''_section'"
$		val$_warnings = val$_warnings + 1
$		return
$	endif
$!
$	if f$locate("#''_this_command'", omi$valid_commands) .eq. -
	   f$length(omi$valid_commands)
$	   then
$		wval "Error - invalid command ''_this_command' in element ''_item' in section MENU_''_section'"
$		val$_errors = val$_errors + 1
$		return
$	endif
$!
$	if _this_command .eqs. f$extract (0, f$length(_this_command), "JUMP")
$	   then
$		_jump_to = f$element(1, " ", _this_item_value)
$		if _jump_to .eqs. ""
$		   then
$			wval "Error - jumping to nowhere in element ''_item' in section MENU_''_section'"
$			val$_errors = val$_errors + 1
$			return
$		endif
$		assign sys$scratch:omi$jump_submenu._tmp$ sys$output
$		show symbol /global *$name
$		deassign sys$output
$		if .not. omi$_debug then -
		   $ set message /nofacility /noseverity /noidentification /notext
$		search sys$scratch:omi$jump_submenu._tmp$ """''_jump_to'""" -
		   /output=sys$scratch:omi$jump_submenu_found._tmp$
$		_status = $status
$		delete\ /nolog /noconfirm sys$scratch:omi$jump_submenu._tmp$;
$		delete\ /nolog /noconfirm sys$scratch:omi$jump_submenu_found._tmp;*
$		if _status .eq. omi$_nomatch
$		   then
$			wval "Error - jumping to non-existing menu ''_jump_to' in element ''_item' in section MENU_''_section'"
$			val$_errors = val$_errors + 1
$			return
$		endif
$       endif
$	return
$!
$!******************************************************************************
$!
$!	Validate the Input element
$!
$ validate$_input:
$!
$	_this_element = "INPUT"
$	gosub validate$_seq_order

$!
$	return
$!
$!******************************************************************************
$!
$!	Check to see if items and/or inputs were specified in the correct order
$!
$ validate$_seq_order:
$!
$	_seq_nr = _item - _this_element
$	if _seq_nr .eq. 1 then $ return
$	if _seq_nr .lt. 1 .or. f$type(_seq_nr) .nes. "INTEGER"
$	   then
$		wval "Warning - value ''_seq_nr' not alowed for element type ''_this_element' in section MENU_''_section'"
$		val$_warnings = val$_warnings + 1
$		return
$	endif
$	_seq_nr = _seq_nr - 1
$	if f$type('_section'$'_this_element''_seq_nr') .eqs. ""
$	   then
$		wval "Error - missing element ''_this_element'''_seq_nr' in section MENU_''_section'"
$		val$_errors = val$_errors + 1
$		return
$	endif
$	return
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	A modification to the menu file is requested using the SET command.
$!	This section looks for the current menu (SET can only update in
$!	menu sections) and updates the selected item.
$!
$ config$_setcmd:
$!
$	if f$extract(0, 1, f$edit(_config,"uncomment,compress,trim")) .eqs. "["
$	   then
$		_section = f$edit(f$extract(1, f$length(f$edit(_config,"uncomment,compress,trim")) - 2, f$edit(_config,"uncomment,compress,trim")), "upcase")
$		write omi_config _config
$		return
$	endif
$!
$	if f$extract(f$length(f$edit(_config,"trim")) - 1, 1, -
	   f$edit(_config,"trim")) .eqs. "-"
$	   then
$		write omi_config _config
$		return
$	endif
$!
$	if f$locate("=", _config) .eq. f$length(_config)
$	   then
$		write omi_config _config
$		return
$	endif
$!
$	if (f$edit(_section,"upcase") - "MENU_") .nes. f$edit(omi$current_menu,"upcase")
$	   then
$		write omi_config _config
$		return
$	endif
$!
$	if f$edit(f$element(0,"=",_config),"upcase,collapse") .eqs. p4 -
 	   then $ return
$	if .not. _update_written .and. p5 .nes. "RESET"
$	   then
$		write omi_config "  ''f$edit(p4,"lowercase")' = ''p5'"
$		'omi$current_menu'$'p4' == "''p5'"
$		_update_written = 1
$	endif
$	write omi_config _config
$!
$	return
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	A modification to the menu file is requested using the ENCRYPT command,
$!	or a personal key will be defined for the current user.
$!	This section looks for the selected section and updates the selected
$!	item.
$!
$ config$_update:
$!
$	if f$extract(0, 1, f$edit(_config,"uncomment,compress,trim")) .eqs. "["
$	   then
$		_section = f$edit(f$extract(1, f$length(f$edit(_config,"uncomment,compress,trim")) - 2, f$edit(_config,"uncomment,compress,trim")), "upcase")
$		write omi_config _config
$		return
$	endif
$!
$	if f$extract(f$length(f$edit(_config,"trim")) - 1, 1, -
	   f$edit(_config,"trim")) .eqs. "-"
$	   then
$		write omi_config _config
$		return
$	endif
$!
$	if f$locate("=", _config) .eq. f$length(_config)
$	   then
$		write omi_config _config
$		return
$	endif
$!
$	if f$edit(_section,"upcase") .nes. f$edit(p4,"upcase")
$	   then
$		write omi_config _config
$		return
$	endif
$!
$!	if f$edit(f$element(0,"=",_config),"upcase,collapse") .eqs. -
 !	   f$edit(p5,"upcase") then $ return
$!	if .not. _update_written ! .and. p5 .nes. "RESET"
$!	   then
$!		write omi_config "  ''f$edit(p5,"lowercase")' = ''p6'"
$!!		if f$edit(f$extract(0, 5, p4), "upcase") .eqs. "MENU_" then -
 !		   $ p4 = p4 - f$extract(0, 5, p4)
$!!		'p4'$'p5' == "''p6'"
$!		_update_written = 1
$!	endif
$	if f$edit(f$element(0,"=",_config),"upcase,collapse") .eqs. f$edit(p5,"upcase")
$!	if .not. _update_written
$	   then
$		write omi_config "''f$element(0,"=",_config)'= ''p6'"
$		if f$edit(f$extract(0, 5, p4), "upcase") .eqs. "MENU_" then -
 		   $ p4 = p4 - f$extract(0, 5, p4)
$		'p4'$'p5' == "''p6'"
$		_update_written = 1
$		return
$	endif
$	write omi_config _config
$!
$	return
$!
$!******************************************************************************

$!******************************************************************************
$!
$!
$!==>	To display how far initialisation of the menu file is, which is useful
$!	for large menu files, this routin counts the number of lines.
$!
$ setupmnu$_get_size:
$!
$	if p4 .eqs. "OMI$INCLUDE"
$	   then
$		omi$display_message -
 		 "%OMI-I-INCLUDE, including menu file of unknown size - please wait"
$		return
$	endif
$!
$	open /read /share=write omi$configure '_config_file
$	mnu$lines = 0
$!
$ setupmnu$_read:
$!
$	read /end_of_file=setupmnu$end_read omi$configure _dummy
$	if f$edit(_dummy,"uncomment,collapse,upcase") .eqs. "<EOF>" -
	   then $ goto setupmnu$end_read
$	mnu$lines = mnu$lines + 1
$	goto setupmnu$_read
$!
$ setupmnu$end_read:
$!
$	close omi$configure
$	_number_of_lines_read = 0
$	return
$!
$!******************************************************************************

$!******************************************************************************
$!
$!
$!==>	This routine was added to set in default values for the OMI
$!	configuration. When new items are added to configuration files in a
$!	new OMI version, the user was required to copy the new file.
$!	Due to these defaults, a notification will do fine.
$!
$ config$_defaults:
$!
$	_cleanup == p3
$	call config$_set_defaults main$empty_value		"....."
$	call config$_set_defaults main$silent_output		"NLA0:"
$	call config$_set_defaults main$editor			"edit"
$	call config$_set_defaults main$version_id		"0"
$	call config$_set_defaults main$printer			"SYS$PRINT"
$	call config$_set_defaults main$protect_prompt		"0"
$	call config$_set_defaults main$show_progress 		"1"
$	call config$_set_defaults main$time_format   		"12"
$	call config$_set_defaults main$float_point   		"."
$!
$	call config$_set_defaults screen$width_margin		"4"
$	call config$_set_defaults screen$height_margin		"1"
$	call config$_set_defaults screen$width			"80"
$	call config$_set_defaults screen$height			"24"
$	call config$_set_defaults screen$exit_width		"0"
$	call config$_set_defaults screen$exit_height		"0"
$	call config$_set_defaults screen$window_topmargin	"1"
$	call config$_set_defaults screen$scroll_region		"enabled"
$	call config$_set_defaults screen$scrollregion_autodisable	"y"
$	call config$_set_defaults screen$separate_inputs	"true"
$	call config$_set_defaults screen$display_names		"false"
$	call config$_set_defaults screen$tab			"15"
$	call config$_set_defaults screen$width_inquired		"false"
$	call config$_set_defaults screen$height_inquired	"false"
$!
$	call config$_set_defaults questions$all_inputs		"All Inputs"
$	call config$_set_defaults questions$option		"OMI>"
$	call config$_set_defaults questions$reverse_tags	"Reverse selection"
$	call config$_set_defaults questions$input		"Enter Value"
$	call config$_set_defaults questions$dcl_command		"DCL Command"
$	call config$_set_defaults questions$default_input	"Input"
$	call config$_set_defaults questions$wait_prompt		"Press <Return> to continue"
$	call config$_set_defaults questions$confirm		"1"
$	call config$_set_defaults questions$answer_yes		"Y"
$	call config$_set_defaults questions$answer_no		"N"
$!
$	call config$_set_defaults bgrprocess$batch_queue	"sys$batch"
$	call config$_set_defaults bgrprocess$detach_lgicmd	"sys$login:login.com"
$	call config$_set_defaults bgrprocess$logfile		""
$	call config$_set_defaults bgrprocess$options_bat	""
$	call config$_set_defaults bgrprocess$options_det	""
$!
$	delete\ /symbol /global _cleanup
$	return
$!
$ config$_set_defaults: subroutine
$!
$	if _cleanup .eqs. "CLEANUP"
$	   then $ if f$type('p1') .nes. "" then $ delete\ /symbol /global 'p1'
$	   else $ if f$type('p1') .eqs. "" then $ 'p1' == "''p2'"
$	endif
$	exit
$ endsubroutine
$!
$!******************************************************************************
