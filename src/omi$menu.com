$	if f$type(omi$_debug) .eqs. "" then $ omi$_debug = 0
$	if .not. omi$_debug then $ omi$_verify = f$verify(0)
$	on control_y then $ goto main$_interrupt
$	on error then $ goto main$_fatal
$	on severe_error then $ goto main$_fatal
$	goto main$_start
$!
$!******************************************************************************
$!*                                                                            *
$!*  FILENAME:                                                                 *
$!*  =========                                                                 *
$!*     Omi$Menu.Com       Oscar's Menu Interpreter                            *
$!*                                                                            *
$!* ************************************************************************** *
$!* *                                                                        * *
$!* * (c) 1997 - 2020, Oscar van Eijk - Oveas Funtionality Provider          * *
$!* *   This tool is delivered as is, and has no warranties whatsoever.      * *
$!* *   It may be freely distributed as long as the distribution set is      * *
$!* *   complete. It is not allowed to change any of the files, without      * *
$!* *   permission of the author.                                            * *
$!* *                                                                        * *
$!* ************************************************************************** *
$!*                                                                            *
$!*  DESCRIPTION:                                                              *
$!*  ============                                                              *
$!*                                                                            *
$!*      Oscar's Menu Interpreter is a DCL procedure that reads menu files and *
$!*      represents the menu structure on a ChUI based window.                 *
$!*                                                                            *
$!*      OMI does not perform any actions on its own. Additional procedures    *
$!*      are required to handle upon the users input. OMI is strictly created  *
$!*      to create a standard user interface for all kinds of actions, with a  *
$!*      clear structure, support for different security levels and password   *
$!*      protection.                                                           *
$!*                                                                            *
$!*      The additional procedures that are required for any actions are       *
$!*      referred to 'callable jobs'. A section in the help file describes     *
$!*      how several commands, defined in OMI, can be used to create such      *
$!*      procedures.                                                           *
$!*                                                                            *
$!*  FILES NEEDED:                                                             *
$!*  =============                                                             *
$!*     OMI$Config.COM        The procedure that sets up the configuration     *
$!*                           and the menu environments by reading the files   *
$!*                           and defining global symbols. On exit, this       *
$!*                           procedure also cleans up all symbols.            *
$!*     OMI$Screen.COM        All screen related material is handled by this   *
$!*                           procedure. The window and layout that's defined, *
$!*                           is based upon the settings by Omi$Config.Com.    *
$!*     OMI$Edit_Cmd.COM      This module, introduced in v1.3, handles all     *
$!*                           EDIT commands.                                   *
$!*     OMI$Calculator.COM    This module, introduced in v2.0, handles all     *
$!*                           calculations.                                    *
$!*     OMI$ToolBox.COM       A set of routines that will are called by OMI,   *
$!*                           but which are also available for OMI modules.    *
$!*                           Most OMI commands call routines from this        *
$!*                           procedure.                                       *
$!*     OMI$ToolBox.Ini       Initialisation file for the ToolBox. All         *
$!*                           that are available via the ToolBox should be     *
$!*                           added here. This file can also define additional *
$!*                           ToolBox files.                                   *
$!*     OMI$Library.OML       A standard library with some useful select lists *
$!*                           that can be included with the #INCLUDE directive.*
$!*     OMI$Menu.CFG          This is the configuration file in which  the     *
$!*                           layout can be defined, and many option of the    *
$!*                           behaviour can be changed. It should be located in*
$!*                           SYS$LOGIN of the current user. If not there,     *
$!*                           the procedure looks for the  file in OMI$.       *
$!*                           If the logical OMI$CONFIG is defined, this over- *
$!*                           writes all other files.                          *
$!*     OMI$Messages.DAT      This file contains all messages that can be      *
$!*                           signalled by OMI.                                *
$!*     <facil>$Messages.DAT  These files can be created for all facilities    *
$!*                           that have been created using OMI.                *
$!*     <file>.MNU            One or more MNU files can be created, containing *
$!*                           the menus. The procedure looks for the MNU files *
$!*                           in OMI$MENU_DIRECTORY, if set, and in OMI$       *
$!*     <file>.OMH            Each menu file can have an optional Help file,   *
$!*                           which is read by the INFO command to provide     *
$!*                           menu specific help.                              *
$!*                                                                            *
$!*  LOGICALS NEEDED:                                                          *
$!*  ================                                                          *
$!*     OMI$                  This logical points to the directory where this  *
$!*                           procedure, and its subprocedures, is located.    *
$!*                           It's also part of the search-path for the CFG    *
$!*                           file, and the MNU files. When not set, it's done *
$!*                           dynamically.                                     *
$!*     OMI$MENU_DIRECTORY    If set, this points to the default directory     *
$!*                           where all menu files are stored.                 *
$!*     OMI$CONFIG            This logical can point to the configuration file.*
$!*                           When it's not set, OMI looks for the file        *
$!*                           Omi$Menu.Cfg in SYS$LOGIN first, then in OMI$    *
$!*     OMI$STARTMENU         If defined, this is the menu file with which the *
$!*                           procedure starts.                                *
$!*                                                                            *
$!*  PARAMETERS NEEDED:                                                        *
$!*  ==================                                                        *
$!*     P1                    If this parameter is specified, it should point  *
$!*                           to the menu file to start with.                  *
$!*     P2 - P3               If specified, P2 contains the name of the menu   *
$!*                           which will be started first, and P3 selects an   *
$!*                           option in the specified menu.                    *
$!*                           If the parameters are used, P1 is required.      *
$!*                                                                            *
$!*  HISTORY:                                                                  *
$!*  ========                                                                  *
$!*     (For descriptions, refer to HISTORY.TXT)                               *
$!*     Version:  Date:       Author:                                          *
$!*     --------  -----       -------                                          *
$!*     0.0       11-03-1997  Oscar van Eijk, OVEAS                            *
$!*     1.0b1     14-03-1997  Oscar van Eijk, OVEAS                            *
$!*     1.0b2     15-04-1997  Oscar van Eijk, OVEAS                            *
$!*     1.0b3     09-05-1997  Oscar van Eijk, OVEAS                            *
$!*     1.0b4     13-05-1997  Oscar van Eijk, OVEAS                            *
$!*     1.0       30-05-1997  Oscar van Eijk, OVEAS                            *
$!*     1.1       21-06-1997  Oscar van Eijk, OVEAS                            *
$!*     1.2       10-09-1997  Oscar van Eijk, OVEAS                            *
$!*     1.3       19-11-1997  Oscar van Eijk, OVEAS                            *
$!*     1.4       19-02-1998  Oscar van Eijk, OVEAS                            *
$!*     1.41      01-05-1998  Oscar van Eijk, OVEAS                            *
$!*     2.0b1     10-11-1998  Oscar van Eijk, OVEAS                            *
$!*     2.0       22-06-1999  Oscar van Eijk, OVEAS                            *
$!*     2.1       25-08-2001  Oscar van Eijk, OVEAS                            *
$!*     2.2       29-08-2002  Oscar van Eijk, OVEAS                            *
$!*                           With thanks to Edward Vlak, EDS                  *
$!*     2.3       25-06-2004  Oscar van Eijk, OVEAS                            *
$!*     2.4       04-10-2018  Oscar van Eijk, OVEAS                            *
$!*     2.5       17-03-2019  Oscar van Eijk, OVEAS                            *
$!*     2.6       16-05-2019  Oscar van Eijk, OVEAS                            *
$!*     2.7       21-02-2020  Oscar van Eijk, OVEAS                            *
$!*                                                                            *
$!******************************************************************************

$!******************************************************************************
$!
$!==>	These initials settings setup the menu environment by calling all
$!	proper subroutines and -procedures.
$!	The first menu will allways be called 'menu'.
$!
$ main$_start:
$!
$	omi$option = ""
$	if f$type(omi$current_menu) .nes.""
$	   then
$		if f$edit(omi$current_menu, "upcase") .eqs. "OTF_MENU"
$		   then
$			'omi$current_menu'$previous = ""
$			omi$otf_menu = 1
$			init_def$search_string = "otf_menu$input"
$			gosub main$default_values
$		endif
$		goto main$do_menu   ! Buggy ????
$	   else $ omi$otf_menu = 0
$	endif
$!
$	omi$_control = f$environment("control")
$	omi$_message = f$environment("message")
$	gosub main$_parse_options
$	if f$type(omi$validate_mode) .eqs. ""
$	   then $ omi$validate_mode = 0
$	   else $ omi$batch_mode = 1
$	endif
$	if f$type(omi$backgr_mode) .eqs. "" then $ omi$backgr_mode = 0
$	if f$type(omi$batch_mode) .eqs. "" then $ omi$batch_mode = 0
$	if omi$batch_mode
$	   then
$		ws := "!"
$		cls := "!"
$	   else
$		ws := "write sys$output"
$		cls := "type/page nla0:"
$		omi$terminal_app_mode = f$getdvi("tt:", "tt_app_keypad")
$!		recall /output=sys$scratch:omi$saved_recall_buffer._tmp$
$!		recall /erase
$	endif
$	omi$version = "2.7"
$	if f$trnlnm("omi$menu_directory") .eqs. "" then -
	   $ define /nolog omi$menu_directory omi$
$	gosub main$_initialize
$	gosub main$_getstart
$	if omi$backgr_mode
$	   then
$		omi$_jumping = 1
$		options$_menuname  = "main"
$		options$_jumps  = "Exit"
$		omi$menu_file = "Omi$:Omi$Background_Module.Mnu"
$		omi$background_module = "''omi$startmenu'"
$	   else $ omi$menu_file = "''omi$startmenu'"
$	endif
$!
$ main$_startmenu:
$!
$	omi$signal omi init
$	omi$config 'omi$menu_file
$	omi$status = $status
$	omi$cmdline_clear
$	if omi$status .eq. omi$_warning
$	   then
$!
$	 main$_askfor_start:
$!
$		read /end_of_file=main$_exit sys$command omi$startmenu -
		   /prompt="''screen$prompt_position'Menu file: "
$		omi$cmdline_clear
$		omi$msgline_clear
$		omi$variable = "omi$startmenu"
$		omi$input_validate
$		if $status .ge. omi$_warning
$		   then
$			omi$signal omi tranerr
$			goto main$_askfor_start
$		endif
$		omi$menu_file = "''omi$startmenu'"
$		goto main$_startmenu
$	endif
$	if omi$status .eq. omi$_error then $ goto main$_fatal
$	if f$type(menu$log_session) .nes. ""
$	   then
$		if menu$log_session then $ omi$log_session "INIT_SESSIONLOG"
$	endif
$	omi$current_menu = "menu"
$	'omi$current_menu'$previous = ""
$	init_def$search_string = "$input"
$	omi$setting_defaults = 1
$	gosub main$default_values
$	delete\ /symbol /local omi$setting_defaults
$	gosub main$check_security
$	if 'omi$current_menu'$security_level .lt. 0
$	   then
$		if 'omi$current_menu'$security_level .eq. -1 then -
		   $ omi$signal omi ivpwd
$		goto main$_interrupt
$	endif
$	if 'omi$current_menu'$security_level .eq. 0
$	   then
$		omi$signal omi nomnuauth
$		goto main$_interrupt
$	endif
$!
$	if omi$validate_mode
$	   then
$		if 'omi$current_menu'$security_level .lt. 3
$		   then $ omi$signal omi nopriv
$		   else $ omi$config 'omi$menu_file validate
$		endif
$		goto main$_exit
$	endif
$!
$	omi$msgline_clear
$!
$	omi$signal omi info
$	if options$_menuname .nes. ""
$	   then
$		omi$_jumping = 1
$		omi$_p1 = options$_menuname
$		jump$_norefresh = 1
$		gosub main$execcmd_jump
$	   else $ omi$_jumping = 0
$	endif
$	options$_jumpcounter = 0
$	goto main$do_menu
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	We've found and initialized a menu. Display it, and start prompting
$!	the user to navigate through the options.
$!
$ main$do_menu:
$!
$	if f$type('omi$current_menu'$on_init) .nes. "" .and. perf$init_exit
$	   then
$		omi$init_job = f$element(0, " ", 'omi$current_menu'$on_init)
$		_params = 'omi$current_menu'$on_init - omi$init_job
$  !!!		omi$init_job  = f$parse(omi$init_job,".OMI", -
   !!!		   "OMI$Menu_Directory:",,"syntax_only")
$  		if .not. omi$_debug then -
		   $ set message /nofacility /noseverity /noidentification /notext
$  !!!		@'omi$init_job '_params'
$  		omi$call 'omi$init_job '_params'
$		if $status .eq. omi$_warning
$		   then
$			perf$init_exit = 0
$			set message 'omi$_message
$			goto option$cancel_input
$		endif
$		set message 'omi$_message
$	endif
$	omi$screen menu
$!
$ main$get_option:
$!
$	'omi$current_menu'$highest_item = inputs$highest_item
$	perf$init_exit = 1
$	if (f$type('omi$current_menu'$prompt) .eqs. "" .and. -
	   f$type(menu$prompt) .eqs. "") .or. main$protect_prompt
$	   then $ _current_prompt = questions$option
$	   else
$		if f$type('omi$current_menu'$prompt) .eqs. ""
$		   then $ _current_prompt = menu$prompt
$		   else $ _current_prompt = 'omi$current_menu'$prompt
$		endif
$	endif
$!
$	omi$prompt_timeout = "/notime_out"
$	if f$type('omi$current_menu'$auto_refresh) .nes. ""
$	   then
$		_timeout = 'omi$current_menu'$auto_refresh
$		if _timeout .gt. 0 .and _timeout .le. 255
$		   then
$			omi$prompt_timeout = "/time_out=''_timeout'"
$			omi$prompt_timeout = omi$prompt_timeout + -
			   "/error=main$do_menu"
$		endif
$	endif
$!
$	if omi$_jumping
$	   then
$		omi$option = f$element(options$_jumpcounter,",",options$_jumps)
$		if omi$option .eqs. "" .or. omi$option .eqs. ","
$		   then
$			read /end_of_file=option$cancel_input 'omi$prompt_timeout' -
			   /prompt="''screen$prompt_position'''_current_prompt' " -
			   sys$command omi$option
$			if f$type(jump$_norefresh) .nes. "" then -
			   $ delete\ /symbol /local jump$_norefresh
$			omi$_jumping = 0
$			omi$log_session "''omi$option'"
$		   else $ options$_jumpcounter = options$_jumpcounter + 1
$		endif
$	   else
$		read /end_of_file=option$cancel_input 'omi$prompt_timeout' -
		   /prompt="''screen$prompt_position'''_current_prompt' " -
		   sys$command omi$option
$		omi$log_session "''omi$option'"
$	endif
$	omi$variable = "omi$option"
$	omi$input_validate
$	if $status .ge. omi$_warning
$	   then
$		omi$signal omi tranerr
$		omi$cmdline_clear
$		goto main$get_option
$	endif
$	omi$cmdline_clear
$	omi$msgline_clear
$	if omi$option .eqs. "" then $ goto main$get_option
$!
$	if 'omi$current_menu'$security_level .eq. 1
$	   then
$		omi$signal omi notauth
$		goto main$get_option
$	endif
$!
$	if f$type(omi$option) .eqs. "INTEGER"
$	   then
$		if omi$option .eq. 0 then $ goto option$cancel_input
$		if f$type('omi$current_menu'$item'omi$option') .eqs. ""
$		   then
$			_input = omi$option - inputs$highest_item
$			if f$type('omi$current_menu'$input'_input') .eqs. ""
$			   then
$				omi$signal omi invopt
$				goto main$get_option
$			   else
$				gosub main$askfor_input
$				goto main$get_option
$			endif
$		endif
$		goto main$option_eval
$	endif
$!
$	omi$_command = f$edit(omi$option, "upcase")
$	if f$extract(0, 1, f$edit(omi$_command, "trim")) .eqs "$" then -
	   $ omi$_command = "DCL " + (omi$_command - "$")
$	gosub main$omi_command
$ !	if f$type(omi$previous_menu_file) .nes. ""
$ !	   then
$ !		delete\/symbol/local omi$previous_menu_file
$ !		goto main$_startmenu
$ !	endif
$	goto main$get_option
$!
$ option$cancel_input:
$!
$	if f$type(omi$option) .nes. ""
$	   then
$		if omi$option .eq. 0
$		   then
$			if f$type(omi$option) .eqs. "INTEGER" .and. omi$option .eq. 0
$			   then
$				delete\ /symbol /local omi$option
$				omi$signal omi toplevel
$				goto main$get_option
$			endif
$		   else $ omi$log_session "<Ctrl/Z>"
$		endif
$	   else $ omi$log_session "<Ctrl/Z>"
$	endif
$!
$	gosub main$perf_onexit
$	if $status .eq. omi$_warning then $ goto main$get_option
$	if omi$otf_menu then $ goto main$otf_exit
$	if 'omi$current_menu'$previous .eqs. "" then $ goto main$_exit
$!
$	omi$current_menu = 'omi$current_menu'$previous
$	omi$cmdline_clear
$	omi$msgline_clear
$	goto main$do_menu
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Check to see if an On_Exit job is defined for this menu. If so,
$!	execute if (if the execute bit PERF$INIT_EXIT is set to true)
$!	and return the status. If there was an error or warning, set the
$!	execute bit to false, to make sure the INIT procedure is not
$!	executed again.
$!
$ main$perf_onexit:
$!
$	_status = omi$_ok
$	if f$type('omi$current_menu'$on_exit) .nes. "" .and. perf$init_exit
$	   then
$		if f$extract(0,1,f$edit('omi$current_menu'$on_exit,"collapse")) .eqs. ":"
$		   then
$			omi$_command = f$edit('omi$current_menu'$on_exit - ":", "trim,compress,upcase")
$			gosub main$omi_command
$			_status = $status
$			goto main$perfd_onexit
$		endif
$		omi$exit_job = f$element(0, " ", 'omi$current_menu'$on_exit)
$		_params = 'omi$current_menu'$on_exit - omi$exit_job
$ !!! 		omi$exit_job  = f$parse(omi$exit_job,".OMI", -
  !!! 		   "OMI$Menu_Directory:",,"syntax_only")
$ !!!		if f$locate(".",omi$exit_job) .eq. f$length(omi$exit_job) -
  !!!		   then $ omi$exit_job = omi$exit_job + ".OMI"
$		if .not. omi$_debug then -
		   $ set message /nofacility /noseverity /noidentification /notext
$ !!!		@'omi$exit_job '_params'
$		omi$call 'omi$exit_job '_params'
$		_status = $status
$		set message 'omi$_message
$	endif
$!
$  main$perfd_onexit:
$!
$	perf$init_exit = 0
$	return _status
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	If the current menu contains input options, this routine asks the
$!	user for input.
$!
$ main$askfor_input:
$!
$	if f$type('omi$current_menu'$required_order) .nes. ""
$	   then
$		gosub input$validate_req_order
$		if $status .ne. omi$_ok then $ return $status
$	endif
$!
$	_all_inputs = 0
$	_variable = f$element(1,"#",'omi$current_menu'$input'_input')
$!
$	if f$extract(0,8,f$edit(_variable,"upcase")) .eqs. "{HIDDEN}"
$	   then
$		_variable = f$extract(8, f$length(_variable)-8, _variable)
$		_hidden = 1
$	   else $ _hidden = 0
$	endif
$!
$	if f$extract(0,5,f$edit(_variable,"upcase")) .eqs. "{TAG|"
$	   then
$		gosub main$_taglist
$		return omi$_ok
$	endif
$!
$	_sel_list = (f$extract(0,1,_variable) .eqs. "{")
$!
$	if _sel_list
$	   then
$		_select_list = f$extract(0, f$locate("}", _variable) + 1, _variable)
$		_variable = _variable - _select_list
$		_select_list = f$edit(_select_list,"upcase") - "{SEL|" - "}"
$		if f$type('_select_list'$filename) .nes. ""
$		   then
$			_blockname = _select_list
$			gosub input$_from_file
$			if $status .ne. omi$_ok then $ return $status
$		endif
$		if f$type('_select_list'$module) .nes. ""
$		   then
$			_blockname = _select_list
$			gosub input$_from_module
$			if $status .ne. omi$_ok then $ return $status
$		endif
$		omi$screen select_list
$	endif
$!
$ input$_prompt:
$!
$	if f$type(list$_scroll) .nes. "" then -
	   $ delete\ /symbol /local list$_scroll
$!
$	_format = f$element(3, "#", 'omi$current_menu'$input'_input')
$	if _format .nes. "" .and. _format .nes. "#"
$	   then
$		if f$edit('_format'$type, "upcase") .eqs. "TEXTAREA" then -
		   $ goto input$dont_ask
$	endif
$!
$	if f$type(questions$input) .eqs. ""
$	   then $ _prompt = f$element(0, "#", 'omi$current_menu'$input'_input')
$	   else $ _prompt = questions$input
$	endif
$	if _sel_list .and. f$type(questions$sellist_input) .nes. "" then -
	   $ _prompt = questions$sellist_input
$!
$	if f$type(_saved_value) .nes. "" then $ delete\ /symbol _saved_value
$	if omi$_jumping
$	   then
$		'_variable' = f$element(options$_jumpcounter,",",options$_jumps)
$		if '_variable' .eqs. "" .or. '_variable' .eqs. ","
$		   then
$			if _hidden then $ set terminal /noecho
$			if f$type('_variable') .nes. "" then $ _saved_value = '_variable'
$			read /end_of_file=input$cancel_input /prompt="''screen$prompt_position'''_prompt': " sys$command '_variable'
$			omi$log_session '_variable'
$			if _hidden then $ set terminal /echo
$			if f$type(jump$_norefresh) .nes. "" then -
			   $ delete\ /symbol /local jump$_norefresh
$			omi$_jumping = 0
$			omi$msgline_clear
$		   else $ options$_jumpcounter = options$_jumpcounter + 1
$		endif
$	   else
$		if _hidden then $ set terminal /noecho
$		if f$type('_variable') .nes. "" then $ _saved_value = '_variable'
$		read /end_of_file=input$cancel_input /prompt="''screen$prompt_position'''_prompt': " sys$command '_variable'
$		omi$log_session '_variable'
$		if _hidden then $ set terminal /echo
$		omi$msgline_clear
$	endif
$!
$	omi$variable = "''_variable'"
$	omi$input_validate
$	if $status .ge. omi$_warning
$	   then
$		omi$signal omi tranerr
$		omi$cmdline_clear
$		goto input$_prompt
$	endif
$!
$ input$dont_ask:
$!
$	if _format .nes. "" .and. _format .nes. "#"
$	   then
$		gosub input$_format
$		_status = $status
$		omi$cmdline_clear
$		if _status .eq. omi$_error then $ return _status
$		if _status .eq. omi$_warning
$		   then
$			if f$type(jump$_norefresh) .nes. "" then -
			   $ delete\ /symbol /local jump$_norefresh
$			omi$_jumping = 0
$			goto input$_prompt
$		endif
$		if f$type('_variable') .eqs. "" then $ goto input$cancel_input
$	endif
$	if _sel_list
$	   then
$		if f$edit(f$extract(0, 1, '_variable'),"upcase") .eqs. "N"
$		   then
$			delete\ /symbol /local '_variable'
$			list$_scroll = "NEXT"
$			omi$screen select_list
$			omi$cmdline_clear
$			goto input$_prompt
$		endif
$		if f$edit(f$extract(0, 1, '_variable'),"upcase") .eqs. "P"
$		   then
$			delete\ /symbol /local '_variable'
$			list$_scroll = "PREVIOUS"
$			omi$screen select_list
$			omi$cmdline_clear
$			goto input$_prompt
$		endif
$		_selected = '_variable'
$		if f$type(_selected) .nes. "INTEGER"
$		   then
$			omi$signal omi ivchoice
$			omi$cmdline_clear
$			if f$type(jump$_norefresh) .nes. "" then -
			   $ delete\ /symbol /local jump$_norefresh
$			if f$type('_variable') .nes. "" then -
			   $ '_variable' = ""
$			omi$_jumping = 0
$			goto input$_prompt
$		endif
$		if f$type('_select_list'$value'_selected') .eqs. ""
$		   then
$			omi$signal omi ivchoice
$			omi$cmdline_clear
$			if f$type(jump$_norefresh) .nes. "" then -
			   $ delete\ /symbol /local jump$_norefresh
$			if f$type('_variable') .nes. "" then -
			   $ '_variable' = ""
$			omi$_jumping = 0
$			goto input$_prompt
$		endif
$		'_variable' = '_select_list'$value'_selected'
$		if f$extract(0, 1, '_variable') .eqs. "{"
$		   then
$			_prompt = '_variable' - "{" - "}"
$!
$		 sellist$get_free_input:
$!
$			omi$cmdline_clear
$			read /end_of_file=input$cancel_input /prompt="''screen$prompt_position'''_prompt': " sys$command '_variable'
$			omi$log_session '_variable'
$			omi$variable = "''_variable'"
$			omi$input_validate
$			if $status .ge. omi$_warning
$			   then
$				omi$signal omi tranerr
$				goto sellist$get_free_input
$			endif
$		endif
$		if f$type(scroll$previous_page) .nes. "" then -
		   $ delete\/symbol/global scroll$previous_page
$		if f$type(scroll$this_page) .nes. "" then -
		   $ delete\/symbol/global scroll$this_page
$		if f$type(scroll$next_page) .nes. "" then -
		   $ delete\/symbol/global scroll$next_page
$		if f$type(scroll$max_on_page) .nes. "" then -
		   $ delete\/symbol/global scroll$max_on_page
$		omi$refresh inside_only
$	endif
$	_line = inputs$first_line - 1 + '_input'
$	_value = '_variable'
$!
$	if _hidden
$	   then
$		_astrlen = f$length(_value)
$		_display_value = f$fao("!''_astrlen'**")
$	   else $ _display_value = _value
$	endif
$	if f$locate("''CR$'", _display_value) .lt. f$length(_display_value) then -
	   $ _display_value = f$extract(0, f$locate("''CR$'", _display_value), -
	   _display_value) + "''ESC$'(0d''ESC$'(B"
$	_blanks = inputs$max_size - f$length(_display_value) + 1
$	if f$length(_display_value) .le. inputs$max_size
$	   then $ ws f$fao("''ESC$'[''_line';''inputs$value_location'H''_display_value'!''_blanks'* ")
$	   else $ ws "''ESC$'[''_line';''inputs$value_location'H''f$extract(0,inputs$max_size,_display_value)'''ESC$'(0`''ESC$'(B"
$	endif
$!
$	omi$cmdline_clear
$!	omi$msgline_clear
$	return omi$_ok
$!
$ input$validate_req_order:
$!
$	if f$locate(_input, 'omi$current_menu'$required_order) .eq. -
	   f$length('omi$current_menu'$required_order) then $ return omi$_ok
$!
$	if f$type('omi$current_menu'$reqwork_order) .eqs. "" then -
	   $ 'omi$current_menu'$reqwork_order = -
	   f$edit('omi$current_menu'$required_order, "collapse")
$!
$	_remember_work_order_list = 'omi$current_menu'$reqwork_order ! Reset on Ctrl/Z
$!
$! Added by Edward Vlak:
$	if 'omi$current_menu'$reqwork_order .eqs. "" then $ return omi$_ok
$!
$	if 'omi$current_menu'$reqwork_order .eqs. _input
$	   then
$		'omi$current_menu'$reqwork_order = ""
$		return omi$_ok
$	endif
$!
$	if f$element(0, ",", 'omi$current_menu'$reqwork_order) .nes. _input -
	   then $ goto input$invalid_req_order
$	'omi$current_menu'$reqwork_order = 'omi$current_menu'$reqwork_order - -
	   "''_input'" - ","
$	return omi$_ok
$!
$ input$invalid_req_order:
$!
$	_cnt = 0
$	_msg_string = ""
$!
$ inv_req_ord$_msg_string:
$!
$	_opt_first = f$element (_cnt, ",", 'omi$current_menu'$reqwork_order)
$	if (_opt_first .eq. _input) .or. (_opt_first .eqs. ",") then $ goto inv_req_ord$end_msg_string
$	_opt_first = _opt_first + inputs$highest_item
$	_msg_string = _msg_string + "''_opt_first'/"
$	_cnt = _cnt + 1
$	goto inv_req_ord$_msg_string
$!
$ inv_req_ord$end_msg_string:
$!
$	_msg_string = f$extract(0, f$length(_msg_string)-1, _msg_string)
$	omi$signal omi ivorder,_msg_string
$	return $status
$!
$ input$cancel_input:
$!
$	omi$log_session "<Ctrl/Z>"
$	if _hidden then $ set terminal /echo
$	if f$type(_remember_work_order_list) .nes. ""
$	   then
$		'omi$current_menu'$reqwork_order = _remember_work_order_list
$		delete\ /symbol /global _remember_work_order_list
$	endif
$!
$	if _sel_list
$	   then $ omi$refresh inside_only
$	   else
$		omi$cmdline_clear
$		omi$msgline_clear
$	endif
$	return omi$_ok
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	An input is selected that requires values to be read from file.
$!	This can be a TAG or SELECT list. The 'filename' argument in the list
$!	block contains the filename that should contain the values.
$!
$ input$_from_file:
$!
$!*** F$Parse translates to the first level of a search list only :-(
$!
$!	_values_file = f$parse('_blockname'$filename,"Omi$Menu_Directory:",".dat")
$	_values_file = f$search('_blockname'$filename)
$	if _values_file .eqs. "" then -
	   $ _values_file = f$search("Omi$Menu_Directory:"+'_blockname'$filename)
$	if _values_file .eqs. "" then -
	   $ _values_file = f$search("Omi$:"+'_blockname'$filename)
$	if _values_file .eqs. ""
$	   then
$		omi$signal omi novalfile,'_blockname'$filename
$		return $status
$	endif
$!
$	open /read /share=write /error=valfile$_openerr valfile '_values_file
$	_value_cnt = 1
$!
$ valfile$_get_values:
$!
$	read /end_of_file=valfile$end_get_values -
	   valfile '_blockname'$value'_value_cnt'
$	_value_cnt = _value_cnt + 1
$	goto valfile$_get_values
$!
$ valfile$end_get_values:
$!
$	close valfile
$!
$ valfile$_clear_values:
$!
$! Cleanup symbols in case the file got shorter since last call
$!
$	if f$type('_select_list'$value'_value_cnt') .eqs. "" then $ return omi$_ok
$	delete\ /symbol /local '_select_list'$value'_value_cnt'
$	_value_cnt = _value_cnt + 1
$	goto valfile$_clear_values
$!
$ valfile$_openerr:
$!
$	if f$search(_values_file) .eqs. ""
$	   then
$		omi$signal omi valopenerr,'_values_file
$		return $status
$	endif
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	An input (tag- or selectlist) is selected that requires values to be set
$!	by a module. These must be global symbols, but they won't be cleaned up, so
$!	translate them to local symbols immediatly.
$!
$ input$_from_module:
$!
$	_val_module = f$element(0, " ", f$edit('_blockname'$module,"trim, compress"))
$	_params = f$extract(f$length(_val_module), -
	   f$length(f$edit('_blockname'$module,"trim, compress")) - f$length(_val_module), -
	   f$edit('_blockname'$module,"trim, compress"))
$	omi$call '_val_module' '_blockname' '_params'
$	_status = $status
$	if _status .ne. omi$_ok
$	   then
$		omi$signal omi valmoderr,'_val_module',_status
$		return $status
$	endif
$!
$!	We must translate the global symbols to local since cleanup won't work here
$	assign sys$scratch:omi$module_values._tmp$ sys$output
$	show symbol '_blockname'$value*
$	_status = $status
$	deassign sys$output
$	if _status .eq. %X00038140 ! %DCL-W-UNDSYM
$	   then
$		delete\ sys$scratch:omi$module_values._tmp$;
$		omi$signal omi novalues,'_val_module'
$		return $status
$	endif
$!
$	open /read /error=valmod$_readerr valfile sys$scratch:omi$module_values._tmp$
$!
$ valmod$_getvalues:
$!
$	read /end_of_file=valmod$_gotvalues valfile _value
$	_name  = f$edit(f$element(0, "=", _value), "trim")
$	_value = f$element(2, "=", _value)
$	'_name' = '_value'
$	delete\ /symbol /global '_name'
$	goto valmod$_getvalues
$!
$ valmod$_gotvalues:
$!
$	close valfile
$	delete\ sys$scratch:omi$module_values._tmp$;
$	return omi$_ok
$!
$ valmod$_readerr:
$!
$	delete\ sys$scratch:omi$module_values._tmp$;
$	omi$signal omi valreaderr,'_val_module'
$	return $status
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	The 4th argument of the input item in the menu file can specify a block
$!	that will be called here for string formatting.
$!	The string
$!
$ input$_format:
$!
$	if f$type('_format'$type) .eqs. ""
$	   then
$		omi$signal omi nofrmtype,'_format'
$		return omi$_error
$	endif
$	on warning then $ goto input$invalid_format
$	if .not. omi$_debug then -
	   $ set message /nofacility /noseverity /noidentification /notext
$	_req_format = f$edit('_format'$type,"collapse,upcase")
$!
$	assign /user nla0: sys$output
$	search 'f$environment("procedure")' "input$''_req_format'_format:"
$	if $status .eq. omi$_nomatch
$	   then
$		omi$signal omi nosuchfrm,'_req_format'
$		return $status
$	endif
$	gosub input$'_req_format'_format
$	_status = $status
$	if _status .ge. omi$_warning
$	   then
$		if f$type(_saved_value) .eqs. ""
$		   then $ delete\ /symbol '_variable'
$		   else $ '_variable' = "''_saved_value'"
$		endif
$	endif
$	return _status
$!
$!******************************************************************************
$!
$!==>	Validate the STRING type
$!
$ input$string_format:
$!
$	if f$type('_variable') .nes. "STRING" .and. -
	   f$type('_variable') .nes. "INTEGER" then -
	   $ goto input$invalid_format
$!
$	if f$type('_format'$upcase) .eqs. ""
$	   then $ _upcase = omi$_false
$	   else
$		if '_format'$upcase
$		   then $ _upcase = omi$_true
$		   else $ _upcase = omi$_false
$		endif
$	endif
$!
$	if f$type('_format'$lowercase) .eqs. ""
$	   then $ _lowercase = omi$_false
$	   else
$		if '_format'$lowercase
$		   then $ _lowercase = omi$_true
$		   else $ _lowercase = omi$_false
$		endif
$	endif
$!
$!	The "BLANKS" setting is pretty inconsequent; if set to TRUE,
$!	blanks will be removed...
$!	This one will remain in here for backwards compatibility, but
$!	the keyword will be replaced (and overwritten!!) by COLLAPSE
$!
$	if f$type('_format'$blanks) .eqs. ""
$	   then $ _collapse = omi$_false
$	   else
$		if '_format'$blanks
$		   then $ _collapse = omi$_true
$		   else $ _collapse = omi$_false
$		endif
$	endif
$!
$!	COLLAPSE keyword replaces he BLANKS keyword, OvE, 20040315
$!
$	if f$type('_format'$collapse) .eqs. ""
$	   then
$		! Only overwrite if the obsolete keyword BLANKS was not used
$		if f$type('_format'$blanks) .eqs. "" then -
			$ _collapse = omi$_false
$	   else
$		if '_format'$collapse
$		   then $ _collapse = omi$_true
$		   else $ _collapse = omi$_false
$		endif
$	endif
$!
$	if _upcase    then $ '_variable' = f$edit('_variable',"upcase")
$	if _lowercase then $ '_variable' = f$edit('_variable',"lowercase")
$	if _collapse  then $ '_variable' = f$edit('_variable',"collapse")
$!
$	if f$type('_format'$minlength) .nes. ""
$	   then
$		if f$length('_variable') .lt. f$integer('_format'$minlength)
$		   then
$			on warning then $ continue
$			set message 'omi$_message'
$			omi$signal omi tooshort,'_format'$minlength
$			return omi$_warning
$		endif
$	endif
$!
$	if f$type('_format'$maxlength) .nes. ""
$	   then
$		if f$length('_variable') .gt. f$integer('_format'$maxlength)
$		   then
$			on warning then $ continue
$			set message 'omi$_message'
$			omi$signal omi toolong,'_format'$maxlength
$			return omi$_warning
$		endif
$	endif
$!
$	if f$type('_format'$alfanum) .nes. ""
$	   then
$		if '_format'$alfanum then -
		   $ '_format'$ivchars = "`'~^!?@#$%&* -+=(){}[]<>:;,.\|/"
$	endif
$	if f$type('_format'$ivchars) .eqs. "" then $ goto input$end_format
$!
$	_char_c = 0
$!
$ format$stringchars:
$!
$	_char = f$extract(_char_c, 1, '_format'$ivchars)
$	if f$locate(_char, '_variable') .lt. f$length('_variable')
$	   then
$		on warning then $ continue
$		set message 'omi$_message'
$		omi$signal omi ivchar,_char
$		return omi$_warning
$	endif
$!
$	_char_c = _char_c + 1
$	if _char_c .lt. f$length('_format'$ivchars) then $ goto format$stringchars
$	goto input$end_format
$!
$!******************************************************************************
$!
$!==>	Validate the FILESPEC type
$!
$ input$filespec_format:
$!
$	if f$type('_variable') .nes. "STRING" then $ goto input$invalid_format
$!
$	if f$type('_format'$wildcards) .eqs. ""
$	   then $ _allow_wc = omi$_false
$	   else
$		if '_format'$wildcards
$		   then $ _allow_wc = omi$_true
$		   else $ _allow_wc = omi$_false
$		endif
$	endif
$!
$	if .not. _allow_wc .and. (f$locate("%", '_variable') .lt. -
	   f$length('_variable') .or. f$locate("*", '_variable') .lt. -
	   f$length('_variable'))
$	   then
$		on warning then $ continue
$		set message 'omi$_message'
$		omi$signal omi nowildcard
$		return omi$_warning
$	endif
$!
$	'_variable' = f$edit('_variable',"upcase,collapse")
$!
$	_storformsg = '_variable'
$	_parse = ""
$	if f$type('_format'$fdevice) .nes. ""
$	   then
$		'_format'$fdevice = '_format'$fdevice - ":"
$		_parse = _parse + '_format'$fdevice + ":"
$	endif
$	if f$type('_format'$fdirectory) .nes. ""
$	   then
$		'_format'$fdirectory = '_format'$fdirectory - "[" - "]"
$		 _parse = _parse  + "[" + '_format'$fdirectory + "]"
$	endif
$	if f$type('_format'$ftype) .nes. ""
$	   then
$		'_format'$ftype = '_format'$ftype - "."
$		_parse = _parse + "." + '_format'$ftype
$	endif
$	'_variable' = f$parse('_variable',"''_parse'")
$!
$	if '_variable' .eqs. ""
$	   then
$		on warning then $ continue
$		omi$signal omi ivfnam,'_storformsg'
$		return omi$_warning
$	endif
$!
$	if f$type('_format'$required) .eqs. ""
$	   then $ _existreq = omi$_false
$	   else
$		if '_format'$required
$		   then $ _existreq = omi$_true
$		   else $ _existreq = omi$_false
$		endif
$	endif
$!
$	if _existreq
$	   then
$		_excheck = '_variable'
$		if f$extract(f$length(_excheck) - 1, 1, _excheck) .eqs. "]" -
		   then $ _excheck = _excheck + "*.*"
$		if f$search(_excheck) .eqs. ""
$		   then
$			on warning then $ continue
$			set message 'omi$_message'
$			omi$signal omi fnf,'_variable'
$			return omi$_warning
$		endif
$	endif
$	goto input$end_format
$!
$!******************************************************************************
$!
$!==>	Validate the INTEGER type
$!
$ input$integer_format:
$!
$	if f$type('_format'$float) .eqs. ""
$	   then
$		_float = 0
$		_float_point = "" !Added by Edward Vlak
$	   else
$		_float = '_format'$float
$		if f$type('_format'$float_point) .eqs. ""
$		   then $ _float_point = main$float_point
$		   else $ _float_point = '_format'$float_point
$		endif
$	endif
$!
$	if _float
$	   then
$		_whole = f$element(0, "''_float_point'", '_variable')
$		_tmp = '_variable' - "''_float_point'"
$	   else
$		_whole = '_variable'
$		_tmp = '_variable'
$	endif
$	if f$type(_tmp) .nes. "INTEGER" then $ goto input$invalid_format
$!
$	if f$type('_format'$min) .nes. ""
$	   then
$		if _whole .lt. '_format'$min
$		   then
$			on warning then $ continue
$			set message 'omi$_message'
$			omi$signal omi lowval,'_format'$min
$			return omi$_warning
$		endif
$	endif
$!
$	if f$type('_format'$max) .nes. ""
$	   then
$		if _whole .gt. '_format'$max
$		   then
$			on warning then $ continue
$			set message 'omi$_message'
$			omi$signal omi hival,'_format'$max
$			return omi$_warning
$		endif
$	endif
$!
$	if _float .and. f$locate(_float_point, '_variable') .eq. -
	   f$length('_variable') then -
	   $ '_variable' = '_variable' + "''_float_point'0"
$!
$	goto input$end_format
$!
$!******************************************************************************
$!
$!==>	Validate the FLOAT type
$!
$ input$float_format:
$!
$	if f$type('_format'$float_point) .eqs. ""
$	   then $ _float_point = main$float_point
$	   else $ _float_point = '_format'$float_point
$	endif
$!
$	_var_int = f$element(0, "''_float_point'", '_variable')
$	if _var_int .eqs. "" then $ _var_int = 0
$	_var_dec = f$element(1, "''_float_point'", '_variable')
$	if _var_dec .eqs. "" .or. _var_dec .eqs. _float_point then $ _var_dec = 0
$	if f$type(_var_int) .nes. "INTEGER" .or. f$type(_var_dec) .nes. "INTEGER" -
	   then $ goto input$invalid_format
$!
$	if f$type('_format'$min) .nes. ""
$	   then
$		_min_int = f$element(0, "''_float_point'", '_format'$min)
$		if _min_int .eqs. "" then $ _min_int = 0
$		_min_dec = f$element(1, "''_float_point'", '_format'$min)
$		if _min_dec .eqs. "" .or. _min_dec .eqs. _float_point then $ _min_dec = 0
$		if _var_int .lt. _min_int .or. -
		   (_var_int .ge. 0 .and. (_var_int .eq. _min_int .and. _var_dec .lt. _min_dec)) .or. -
		   (_var_int .lt. 0 .and. (_var_int .eq. _min_int .and. _var_dec .gt. _min_dec))
$		   then
$			on warning then $ continue
$			set message 'omi$_message'
$			omi$signal omi lowval,'_format'$min
$			return omi$_warning
$		endif
$	endif
$!
$	if f$type('_format'$max) .nes. ""
$	   then
$		_max_int = f$element(0, "''_float_point'", '_format'$max)
$		if _max_int .eqs. "" then $ _max_int = 0
$		_max_dec = f$element(1, "''_float_point'", '_format'$max)
$		if _max_dec .eqs. "" .or. _max_dec .eqs. _float_point then $ _max_dec = 0
$		if _var_int .gt. _max_int .or. -
		   (_var_int .ge. 0 .and. (_var_int .eq. _max_int .and. _var_dec .gt. _max_dec)) .or. -
		   (_var_int .lt. 0 .and. (_var_int .eq. _max_int .and. _var_dec .lt. _max_dec))
$		   then
$			on warning then $ continue
$			set message 'omi$_message'
$			omi$signal omi hival,'_format'$max
$			return omi$_warning
$		endif
$	endif
$!
$	if f$locate(_float_point, '_variable') .eq. f$length('_variable') -
	   then $ '_variable' = '_variable' + "''_float_point'0"
$!
$	goto input$end_format
$!
$!******************************************************************************
$!
$!==>	Validate the DATETIME type
$!
$ input$datetime_format:
$!
$	omi$signal omi notyet,_req_format
$	goto input$end_format
$!
$!******************************************************************************
$!
$!==>	Validate the TEXTAREA type
$!
$ input$textarea_format:
$!
$	on warning then $ continue
$	if f$type('_format'$filename) .nes. ""
$	   then $ _ta_file = '_format'$filename
$	   else $ _ta_file = "ta_''omi$current_menu'$input''_input'"
$	endif
$	_ta_file = f$parse(_ta_file, "Omi$Menu_Directory:", ".txt")
$!
$	if f$type('_format'$large) .eqs. ""
$	   then $ _ta_max_size = 255
$	   else
$		if '_format'$large
$		   then $ _ta_max_size = 1024
$		   else $ _ta_max_size = 255
$		endif
$	endif
$!
$	if f$type('_format'$history) .eqs. ""
$	   then $ _ta_keep_history = 0
$	   else
$		if '_format'$history
$		   then $ _ta_keep_history = 1
$		   else $ _ta_keep_history = 0
$		endif
$	endif
$!
$	if f$type('_format'$keep) .eqs. ""
$	   then $ _ta_keep_file = 0
$	   else
$		if '_format'$keep
$		   then $ _ta_keep_file = 1
$		   else $ _ta_keep_file = 0
$		endif
$	endif
$!
$	if .not. _ta_keep_file
$	   then
$		if f$type(ta$remove_files) .eqs. ""
$		   then $ ta$remove_files = _ta_file
$		   else $ ta$remove_files = ta$remove_files + "," + _ta_file
$		endif
$		_ta_keep_history = 0
$	endif
$!
$	if f$type(omi$setting_defaults) .eqs. ""
$	   then
$		if f$search(_ta_file) .eqs. "" .and. -
		   '_variable' .nes. main$empty_value
$		   then
$			open /write ta_default '_ta_file'
$			write ta_default '_variable'
$			close ta_default
$		endif
$		assign /user TT: sys$input
$		'main$editor' '_ta_file
$		if .not. _ta_keep_history then -
		   $ purgee /nolog /keep=1 /noconfirm 'f$element(0, ";", _ta_file)
$		omi$refresh inside_only
$		gosub textarea$_readfile
$	endif
$	goto input$end_format
$!
$ textarea$_readfile:
$!
$	if f$search(_ta_file) .eqs. "" then $ goto textarea$_nofile
$	open /read /share=write t_area '_ta_file' /error=textarea$_locked
$	read /end_of_file=textarea$_nofile t_area '_variable'
$	_total_size = f$length('_variable')
$!
$ textarea$_readloop:
$!
$	read /end_of_file=textarea$end_readloop t_area _nextline
$	_total_size = _total_size + 2 + f$length(_nextline)
$	if _total_size .ge. _ta_max_size
$	   then
$		omi$signal omi tatrunc,_ta_max_size
$		goto textarea$end_readloop
$	endif
$	'_variable' = '_variable' + F$Fao("!/") + _nextline
$	goto textarea$_readloop
$!
$ textarea$end_readloop:
$!
$	close t_area
$	return omi$_ok
$!
$ textarea$_nofile:
$!
$	return omi$_ok
$!
$ textarea$_locked:
$!
$	omi$signal omi talock
$	return $status
$!
$!******************************************************************************
$!
$!==>	Validate the DATE type
$!
$ input$date_format:
$!
$	if f$type('_format'$format) .eqs. ""
$	   then
$		_dformat = "absolute"
$		goto format$frm_date
$	endif
$!
$	if f$edit(f$extract(0, 1, '_format'$format), "upcase") .eqs. "A" then -
	   $ _dformat = "absolute"
$	if f$edit(f$extract(0, 1, '_format'$format), "upcase") .eqs. "C" then -
	   $ _dformat = "comparison"
$	if f$edit(f$extract(0, 1, '_format'$format), "upcase") .eqs. "D" then -
	   $ _dformat = "delta"
$!
$ format$frm_date:
$!
$	_d_in = '_variable'
$	if f$locate("-",_d_in) .eq. f$length(_d_in) then -
	   $ _d_in = _d_in + "-" + f$cvtime("today","absolute","month")
$	'_variable' = f$cvtime("''_d_in'","''_dformat'","date")
$	goto input$end_format
$!
$!******************************************************************************
$!
$!==>	Validate the TIME type
$!
$ input$time_format:
$!
$	_t_in = f$edit('_variable',"collapse,upcase")
$!
$	if f$type('_format'$trzero) .eqs. "" then -
	   '_format'$trzero = 0
$	if f$type('_format'$hours) .eqs. "" then -
	   '_format'$hours = main$time_format
$	if f$type('_format'$separator) .eqs. "" then -
	   '_format'$separator = ":"
$	if f$type('_format'$upcase) .eqs. "" then -
	   '_format'$upcase = 0
$!
$	_noon =  ((f$integer(f$extract(0, 1, _t_in)) .ge. 1 .and. -
	   f$integer(f$extract(1, 1, _t_in)) .ge. 2) .or. -
	   (f$integer(f$extract(0, 1, _t_in)) .eq. 2 .and. -
	   f$integer(f$extract(1, 1, _t_in)) .ge. 1))
$!
$	if f$locate("AM", _t_in) .lt. f$len(_t_in)
$	   then
$		if _noon then $ goto input$invalid_format
$		_t_in = _t_in - "AM"
$	endif
$!
$	if f$locate("PM", _t_in) .lt. f$len(_t_in)
$	   then
$		_noon = 1
$		_t_in = _t_in - "PM"
$	endif
$!
$	if f$locate(":", _t_in) .lt. f$length(_t_in)
$	   then
$		_hrs  = f$element(0, ":", _t_in)
$		_mins = f$element(1, ":", _t_in)
$		goto format$frm_time
$	endif
$!
$	if f$locate(".", _t_in) .lt. f$length(_t_in)
$	   then
$		_hrs  = f$element(0, ".", _t_in)
$		_mins = f$element(1, ".", _t_in)
$		goto format$frm_time
$	endif
$!
$	goto input$invalid_format
$!
$ format$frm_time:
$!
$	if f$type(_hrs) .nes. "INTEGER" .or. f$type(_mins) .nes. "INTEGER" -
	   then $ goto input$invalid_format
$	if _noon .and. _hrs .lt. 12 then $ _hrs = _hrs + 12
$	if _hrs .eq. 24
$	   then
$		_hrs = 0
$		_noon = 0
$	endif
$	if _hrs .lt. 0 .or. _hrs .ge. 24 .or. _mins .lt. 0 .or. _mins .ge. 60 -
	   then $ goto input$invalid_format
$!
$	_addstr = ""
$	if '_format'$hours .eq. 12
$	   then
$		if _noon
$		   then
$			if _hrs .gt. 12 then $ _hrs = _hrs - 12
$			_addstr = "pm"
$		   else $ _addstr = "am"
$		endif
$		if '_format'$upcase then $ _addstr = f$edit(_addstr,"upcase")
$	endif
$!
$	if _mins .lt. 10 then $ _mins = "0''f$integer(_mins)'"
$	if _hrs .lt. 10 .and. '_format'$trzero then -
	   $ _hrs = "0''f$integer(_hrs)'"
$!
$	'_variable' = "''_hrs'"+'_format'$separator+"''_mins'''_addstr'"
$	goto input$end_format
$!
$ input$end_format:
$!
$	set message 'omi$_message'
$	on warning then $ continue
$	return omi$_ok
$!
$ input$invalid_format:
$!
$	on warning then $ continue
$	set message 'omi$_message'
$	omi$signal omi ivfrm,_req_format
$	return omi$_warning
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	An option has been entered and validated. This routine translates
$!	the option to the menu definition and acts upon that.
$!
$ main$option_eval:
$!
$	_selected_item = 'omi$current_menu'$item'omi$option'
$!
$ eval$lookfor_substitutions:
$!
$	if f$locate("~?",_selected_item) .lt. f$length(_selected_item)
$	   then
$		gosub main$input_substitute
$		if $status .eq. omi$_cancelled then $ goto main$get_option
$		goto eval$lookfor_substitutions
$	endif
$!
$	omi$option_type = f$edit(f$element(1,"#",_selected_item),"upcase")
$	if omi$option_type .eqs. "SUBMENU"
$	   then
$		if f$extract(0, 1, f$element(2,"#",_selected_item)) .eqs. "{"
$		   then $ gosub main$_dynamic_menu
$		   else
$			'f$element(2,"#",_selected_item)'$previous = omi$current_menu
$			omi$current_menu = "''f$element(2,"#",_selected_item)'"
$		endif
$		gosub main$check_security
$		if 'omi$current_menu'$security_level .lt. 0
$		   then
$			if 'omi$current_menu'$security_level .eq. -1 then -
			   $ omi$signal omi ivpwd
$			omi$current_menu = 'omi$current_menu'$previous
$		endif
$		if 'omi$current_menu'$security_level .eq. 0
$		   then
$			omi$signal omi nopriv
$			omi$current_menu = 'omi$current_menu'$previous
$		endif
$		if f$type('omi$current_menu'$counter) .nes. ""
$		   then
$			_menu_counter = 'omi$current_menu'$counter
$			if f$type('omi$current_menu'$auto_increase) .eqs. ""
$			   then $ counter$'_menu_counter' == counter$'_menu_counter' + 1
$			   else
$				if 'omi$current_menu'$auto_increase then -
				   $ counter$'_menu_counter' == counter$'_menu_counter' + 1
$			endif
$			init_def$search_string = -
			   "''omi$current_menu'$input,counter$ /match=and"
$			gosub main$default_values
$		endif
$		goto main$do_menu
$	endif
$!
$	if omi$option_type .eqs. "COMMAND"
$	   then
$		omi$_command = f$edit(f$element(2,"#",_selected_item),"upcase")
$		gosub main$omi_command
$		if f$type(omi$previous_menu_file) .nes. ""
$		   then
$			delete\/symbol/local omi$previous_menu_file
$			goto main$_startmenu
$		endif
$		goto main$get_option
$	endif
$!
$	if omi$option_type .eqs. "CALL"
$	   then
$		omi$call_info = f$edit(f$element(2,"#",_selected_item), -
		   "trim,compress")
$ !!		if f$extract(0,1,omi$call_info) .eqs. "@" then -
  !!		   $ omi$call_info = omi$call_info - "@"
$		omi$job_call  = f$element(0," ",omi$call_info)
$		omi$call_parm = f$edit((omi$call_info - omi$job_call),"trim")
$ !!! 		omi$job_call  = f$parse(omi$job_call,".OMI", -
  !!! 		   "OMI$Menu_Directory:",,"syntax_only")
$! The above line is outcommented; it doesn't work when there's a variable
$! in the filename (eg. 'DIRECTORIES$OMI_JOBS'MY_MODULE)
$! Below is the wordaround.
$!!!! Left in for a while.....
$  !!!		if f$locate(".",omi$job_call) .eq. f$length(omi$job_call) -
   !!!		   then $ omi$job_call = omi$job_call + ".OMI"
$		if .not. omi$_debug then -
		   $ set message /nofacility /noseverity /noidentification /notext
$  !!!		if f$search("''omi$job_call'") .eqs. ""
$  !!!		   then $ omi$signal omi modnotfound,omi$job_call
$  !!!		   else
$  !!!			@'omi$job_call' 'omi$call_parm'
$			omi$call 'omi$job_call' 'omi$call_parm'
$  			_status = $status
$  !!!		endif
$		set message 'omi$_message
$		goto main$get_option
$	endif
$!
$	omi$signal omi badopt
$	goto main$get_option
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Handle the Dynamic Menu items
$!
$ main$_dynamic_menu:
$!
$	_menu_list = f$element(2,"#",_selected_item)
$	_dynmenu_count = 0
$!
$ dynmenu$_get_options:
$!
$	_dynmenu_count = _dynmenu_count + 1
$	_dynmenu'_dynmenu_count' = f$extract(0, f$locate("}", _menu_list)+1, _menu_list)
$	_menu_list = _menu_list - _dynmenu'_dynmenu_count'
$	_dynmenu'_dynmenu_count' = _dynmenu'_dynmenu_count' - "{" - "}"
$	if f$extract(0, 1, _menu_list) .eqs. "{" then $ goto dynmenu$_get_options
$	omi$screen dynamic_menu
$!
$ dynmenu$_prompt:
$!
$	if omi$_jumping
$	   then
$		_selected_menu = f$element(options$_jumpcounter,",",options$_jumps)
$		if _selected_menu .eqs. "" .or. _selected_menu .eqs. ","
$		   then
$			read /end_of_file=dynmnu$cancel_input /prompt="''screen$prompt_position'''_menu_list' " sys$command _selected_menu
$			omi$log_session "''_selected_menu'"
$			if f$type(jump$_norefresh) .nes. "" then -
			   $ delete\ /symbol /local jump$_norefresh
$			omi$_jumping = 0
$		   else $ options$_jumpcounter = options$_jumpcounter + 1
$		endif
$	   else
$		read /end_of_file=dynmnu$cancel_input /prompt="''screen$prompt_position'''_menu_list' " sys$command _selected_menu
$		omi$log_session "''_selected_menu'"
$	endif
$	omi$variable = "_selected_menu"
$	omi$input_validate
$	if $status .ge. omi$_warning
$	   then
$		omi$signal omi tranerr
$		omi$cmdline_clear
$		goto dynmenu$_prompt
$	endif
$	if f$type(_selected_menu) .nes. "INTEGER" .or. -
	   f$type(_dynmenu'_selected_menu') .eqs. ""
$	   then
$		omi$signal omi ivchoice
$		omi$cmdline_clear
$		goto dynmenu$_prompt
$	endif
$	_selected_menu = f$element(1, "|", _dynmenu'_selected_menu')
$	'_selected_menu'$previous = omi$current_menu
$	omi$current_menu = "''_selected_menu'"
$!
$ dynmnu$cancel_input:
$!
$	omi$log_session "<Ctrl/Z>"
$	omi$cmdline_clear
$	return omi$_cancelled
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	An OMI command was found in the menu file, which requires extra
$!	input. This was recorgnized by the string '~?' If this was immediatly
$!	followed by '{any text}', 'any text' will be used to prompt the user
$!	for the required input. '~?' will be substituted by the user input in
$!	the command.
$!	If '{any text}' if optionally split by a "|" ('{any text|block}'),
$!	'block' points to a format block.
$!
$ main$input_substitute:
$!
$	_string1 = f$extract(0, f$locate("~?",_selected_item), _selected_item)
$	_selected_item = _selected_item - _string1
$!
$	if f$type(_format) .nes. "" then $ delete\ /symbol /local _format
$	if f$locate("~?{",_selected_item) .lt. f$length(_selected_item)
$	   then
$		_prompt_info = f$extract(3, f$locate("}",_selected_item)-3, _selected_item)
$		_selected_item = _selected_item - "{''_prompt_info'}"
$		_prompt = f$element(0, "|", _prompt_info)
$		if f$length(_prompt) .lt. f$length(_prompt_info) - 1 then -
		   $ _format = f$element(1, "|", _prompt_info)
$	   else $ _prompt = "''questions$default_input':"
$	endif
$!
$ main$input_to_subst:
$!
$	read /end_of_file=main$subst_cancelled sys$command _value -
	   /prompt="''screen$prompt_position'''_prompt' "
$	omi$log_session "''_value'"
$	omi$msgline_clear
$	omi$variable = "_value"
$	omi$input_validate
$	if $status .ge. omi$_warning
$	   then
$		omi$signal omi tranerr
$		omi$cmdline_clear
$		goto main$input_to_subst
$	endif
$!
$	if f$type(_format) .nes. ""
$	   then
$		_variable = "_value"
$		gosub input$_format
$		if $status .eq. omi$_warning ! Ignore errors; they'll cause looping
$		   then
$			omi$cmdline_clear
$			goto main$input_to_subst
$		endif
$	endif
$!
$	omi$cmdline_clear
$	omi$msgline_clear
$!
$	_selected_item = _string1 + _value + f$extract(2, -
	   f$length(_selected_item)-2, _selected_item)
$!
$	return omi$_ok
$!
$ main$subst_cancelled:
$!
$	omi$log_session "<Ctrl/Z>"
$	omi$msgline_clear
$	omi$cmdline_clear
$	return omi$_cancelled
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>
$!
$ main$_taglist:
$!
$	_tagblock = f$extract(0, f$locate("}", _variable) + 1, _variable)
$	_taglist = _variable - _tagblock
$	_tagblock = f$edit(_tagblock,"upcase") - "{TAG|" - "}"
$	if f$type ('_taglist') .eqs. "" then $ '_taglist' = ""
$	if f$type('_tagblock'$delimiter) .eqs. ""
$	   then
$		omi$signal omi nodelim
$		return omi$_warning
$	endif
$	_tagdelim = '_tagblock'$delimiter
$	if f$type('_tagblock'$filename) .nes. ""
$	   then
$		_blockname = _tagblock
$		gosub input$_from_file
$		if $status .ne. omi$_ok then $ return $status
$	endif
$	if f$type('_tagblock'$module) .nes. ""
$	   then
$		_blockname = _tagblock
$		gosub input$_from_module
$		if $status .ne. omi$_ok then $ return $status
$	endif
$!
$	omi$screen taglist
$!
$ taglist$_prompt:
$!
$	if omi$_jumping
$	   then
$		_tag_sel = f$element(options$_jumpcounter,",",options$_jumps)
$		if _tag_sel .eqs. "" .or. _tag_sel .eqs. ","
$		   then
$			read /end_of_file=main$end_taglist sys$command _tag_sel -
			   /prompt="''screen$prompt_position'''questions$taglist_input' "
$			omi$log_session "''_tag_sel'"
$			if f$type(jump$_norefresh) .nes. "" then -
			   $ delete\ /symbol /local jump$_norefresh
$			omi$_jumping = 0
$		   else $ options$_jumpcounter = options$_jumpcounter + 1
$		endif
$	   else
$		read /end_of_file=main$end_taglist sys$command _tag_sel -
		   /prompt="''screen$prompt_position'''questions$taglist_input' "
$		omi$log_session "''_tag_sel'"
$	endif
$	if f$edit(_tag_sel,"upcase") .eqs. "^Z" then $ goto main$end_taglist
$	omi$cmdline_clear
$	omi$msgline_clear
$!
$	if _tag_sel .eqs. "" then $ goto taglist$_prompt
$	if f$type(_tag_sel) .nes. "INTEGER"
$	   then
$		omi$signal omi intonly
$		if f$type(jump$_norefresh) .nes. "" then -
		   $ delete\ /symbol /local jump$_norefresh
$		omi$_jumping = 0
$		goto taglist$_prompt
$	endif
$	_reverse = 0
$!
$	if _tag_sel .lt. 0
$	   then
$		omi$signal omi ivsel
$		if f$type(jump$_norefresh) .nes. "" then -
		   $ delete\ /symbol /local jump$_norefresh
$		omi$_jumping = 0
$		goto taglist$_prompt
$	endif
$!
$	if f$type('_tagblock'$value'_tag_sel') .eqs. ""
$	   then
$		_sel_m_1 = _tag_sel - 1
$		if _sel_m_1 .lt. 0 then $ _sel_m_1 = 0
$		if f$type('_tagblock'$value'_sel_m_1') .eqs. ""
$		   then
$			omi$signal omi ivsel
$			if f$type(jump$_norefresh) .nes. "" then -
			   $ delete\ /symbol /local jump$_norefresh
$			omi$_jumping = 0
$			goto taglist$_prompt
$		   else $ _reverse = 1
$		endif
$	endif
$!
$	if _reverse then $ _tag_sel = 1
$!
$ tag$_reverse:
$!
$	_tag_value = '_tagblock'$value'_tag_sel'
$	if f$locate("''_tagdelim'''_tag_value'''_tagdelim'",'_taglist') .lt. -
	   f$length('_taglist') .or. (f$length('_taglist') .ne. 0 .and. -
	   f$locate("''_tag_value'''_tagdelim'",'_taglist') .eq. 0)
$	   then $ '_taglist' = '_taglist' - ('_tagblock'$value'_tag_sel' + "''_tagdelim'")
$	   else $ '_taglist' = '_taglist' + '_tagblock'$value'_tag_sel' + "''_tagdelim'"
$	endif
$	omi$screen taglist '_tag_sel'
$!
$	if _reverse
$	   then
$		_tag_sel = _tag_sel + 1
$		if _tag_sel .le. _sel_m_1 then $ goto tag$_reverse
$	endif
$!
$	goto taglist$_prompt
$!
$ main$end_taglist:
$!
$	omi$log_session "<Ctrl/Z>"
$	omi$refresh inside_only
$	return omi$_ok
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	The option was recognized as an internal OMI command, or an OMI
$!	command has been entered as input. Validate the command, and execute it.
$!
$ main$omi_command:
$!
$	omi$_command = f$edit(omi$_command,"trim,compress")
$	omi$_p1 = f$edit(f$element(1, " ", omi$_command),"trim")
$	omi$_p2 = f$edit(f$element(2, " ", omi$_command),"trim")
$	omi$_p3 = f$edit(f$element(3, " ", omi$_command),"trim")
$	omi$_p4 = f$edit(f$element(4, " ", omi$_command),"trim")
$	omi$_p5 = f$edit(f$element(5, " ", omi$_command),"trim")
$	omi$_command = f$element(0, " ", omi$_command)
$	_cmd_match = 0
$	_cmd_cnt = 0
$!
$ main$_validate_cmd:
$!
$	if f$element(_cmd_cnt, "#", omi$valid_commands) .eqs. "#" then -
	   $ goto main$end_validate_cmd
$	if omi$_command .eqs. f$extract(0, f$length(omi$_command), -
	   f$element(0, ",", f$element(_cmd_cnt, "#", omi$valid_commands)))
$	   then
$		omi$command = f$element(0, ",", f$element(_cmd_cnt, "#", omi$valid_commands))
$		_available_in_otf = f$element(1, ",", f$element(_cmd_cnt, "#", omi$valid_commands))
$		_cmd_match = _cmd_match + 1
$	endif
$!
$	_cmd_cnt = _cmd_cnt + 1
$	goto main$_validate_cmd
$!
$ main$end_validate_cmd:
$!
$	if _cmd_match .eq. 0
$	   then
$		omi$signal omi ivcmd,omi$_command
$		return omi$_warning
$	endif
$!
$	if _cmd_match .ge. 2
$	   then
$		omi$signal omi abcmd,omi$_command
$		return omi$_warning
$	endif
$!
$	if omi$otf_menu .and. .not. _available_in_otf
$	   then
$		omi$signal omi cmdnotav
$		return $status
$	endif
$!
$	gosub main$execcmd_'omi$command'
$	return $status
$!
$!******************************************************************************
$!
$ main$execcmd_back:
$!
$!==>	The OMI command BACK
$!
$	if 'omi$current_menu'$previous .eqs. "" .and. .not. omi$otf_menu
$	   then
$		omi$signal omi toplevel
$		return $status
$	endif
$!
$	if f$length(omi$_p1) .lt. 3 .or. omi$_p1 .nes. f$extract(0, f$length(omi$_p1), "NOEXIT_MODULE")
$	   then
$		gosub main$perf_onexit
$		if $status .eq. omi$_warning then $ return omi$_warning
$	endif
$!
$	if omi$otf_menu then $ goto main$otf_exit
$	omi$current_menu = 'omi$current_menu'$previous
$	omi$screen menu
$	return omi$_ok
$!
$!******************************************************************************
$!
$ main$execcmd_calc:
$!
$!==>	The OMI command CALC
$!
$	@Omi$:Omi$Calculator 'omi$_p1 'omi$_p2 'omi$_p3 'omi$_p4 'omi$_p5
$	_status = $status
$	if _status .eq. omi$_ok
$	   then
$		omi$signal omi calcres,'omi$calculated
$		delete\ /symbol /global omi$calculated
$	endif
$	return _status
$!
$!******************************************************************************
$!
$ main$execcmd_edit:
$!
$!==>	The OMI command EDIT
$!
$	if 'omi$current_menu'$security_level .lt. 3
$	   then
$		omi$signal omi nopriv
$		return omi$_warning
$	endif
$!
$	@Omi$:Omi$Edit_Cmd
$	return $status
$!
$!******************************************************************************
$!
$ main$execcmd_exit:
$ main$execcmd_quit:
$!
$!==>	The OMI commands EXIT and QIUT
$!
$	gosub main$perf_onexit
$	if $status .eq. omi$_warning then $ return omi$_warning
$	if f$edit(omi$current_menu,"upcase") .nes. "MENU"
$	   then
$		perf$init_exit = 1
$		omi$current_menu = "menu"
$		gosub main$perf_onexit
$		if $status .eq. omi$_warning
$		   then
$			omi$screen menu
$			return omi$_warning
$		endif
$	endif
$	goto main$_exit
$!
$!******************************************************************************
$!
$ main$execcmd_encrypt:
$!
$!==>	The OMI command ENCRYPT
$!
$	if 'omi$current_menu'$security_level .lt. 3
$	   then
$		omi$signal omi nopriv
$		return omi$_warning
$	endif
$!
$	if omi$_p1 .eqs. ""
$	   then
$		read /end_of_file=encrypt_command$_cancelled sys$command _encr_sect -
		   /prompt="''screen$prompt_position'_From section: "
$		omi$log_session "''_encr_secr'"
$		omi$cmdline_clear
$	   else $ _encr_sect = omi$_p1
$	endif
$	_encr_sect = _encr_sect - "[" - "]"
$	if omi$_p2 .eqs. ""
$	   then
$		read /end_of_file=encrypt_command$_cancelled sys$command _encr_item -
		   /prompt="''screen$prompt_position'_Item: "
$		omi$log_session "''_encr_item'"
$		omi$cmdline_clear
$	   else $ _encr_item = omi$_p2
$	endif
$!
$	if f$type('_encr_sect'$'_encr_item') .eqs. ""
$	   then
$		omi$signal omi nosuchitm,_encr_item,_encr_sect
$		return omi$_warning
$	endif
$!
$	if omi$_p3 .nes. ""
$	   then
$		if f$type(keyring$'omi$_p3') .eqs. ""
$		   then
$			omi$signal omi ivkey,omi$_p3
$			return omi$_warning
$		endif
$	endif
$!
$	_encr = '_encr_sect'$'_encr_item'
$	omi$encrypt "''_encr'" 'omi$_p3'
$	_encr = omi$encrypted
$	delete\ /symbol /global omi$encrypted
$	omi$config 'omi$menu_file' update "''_encr_sect'" "''_encr_item'" "''_encr'"
$	if $status .eq. omi$_ok then -
	   $ omi$signal omi encrypt
$	return omi$_ok
$!
$ encrypt_command$_cancelled:
$!
$	omi$log_session "<Ctrl/Z>"
$	omi$cmdline_clear
$	return omi$_ok
$!
$!******************************************************************************
$!
$ main$execcmd_export:
$!
$!==>	The OMI command EXPORT
$!
$	if omi$_p1 .eqs. ""
$	   then
$		read /end_of_file=export_command$_cancelled sys$command omi$_p1 -
		   /prompt="''screen$prompt_position'_What: "
$		omi$log_session "''omi$_p1'"
$		omi$_p1 = f$edit(omi$_p1,"uncomment,trim,compress,upcase")
$		omi$cmdline_clear
$		goto main$execcmd_export
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "KEY")
$	   then
$!
$	 export_cmd$export_key:
$!
$		if omi$_p2 .eqs. ""
$		   then
$			read /end_of_file=export_command$_cancelled sys$command omi$_p2 -
			   /prompt="''screen$prompt_position'_Key name: "
$			omi$log_session "''omi$_p2'"
$			omi$cmdline_clear
$			goto export_cmd$export_key
$		endif
$!
$		if f$type(keyring$'omi$_p2') .eqs. ""
$		   then
$			omi$signal omi ivkey,omi$_p2
$			return omi$_warning
$		endif
$		if f$search("omi$:omi$global_keyring.dat") .eqs. ""
$		   then $ open /write /error=export_cmd$nopriv -
			omi$_keyring omi$:omi$global_keyring.dat
$		   else
$			search /output=nla0: omi$:omi$global_keyring.dat "''omi$_p2'"
$			if $status .ne. omi$_nomatch
$			   then
$				omi$signal omi glkeyex,omi$_p2
$				return $status
$			endif
$			open /append /error=export_cmd$nopriv -
			   omi$_keyring omi$:omi$global_keyring.dat
$		endif
$!
$		write omi$_keyring "''omi$_p2'=",keyring$'omi$_p2',"="
$		close omi$_keyring
$		omi$signal omi expkey,omi$_p2
$		return omi$_ok
$	endif
$
$	omi$signal omi ivopt,export
$!
$ export_command$_cancelled:
$!
$	omi$log_session "<Ctrl/Z>"
$	omi$cmdline_clear
$	return omi$_ok
$!
$ export_cmd$nopriv:
$!
$	omi$signal omi noexprv
$	return $status
$!
$!******************************************************************************
$!
$ main$execcmd_import:
$!
$!==>	The OMI command IMPORT
$!
$	if omi$_p1 .eqs. ""
$	   then
$		read /end_of_file=import_command$_cancelled sys$command omi$_p1 -
		   /prompt="''screen$prompt_position'_What: "
$		omi$log_session "''omi$_p1'"
$		omi$_p1 = f$edit(omi$_p1,"uncomment,trim,compress,upcase")
$		omi$cmdline_clear
$		goto main$execcmd_import
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "KEY")
$	   then
$!
$	 import_cmd$import_key:
$!
$		if omi$_p2 .eqs. ""
$		   then
$			read /end_of_file=import_command$_cancelled sys$command omi$_p2 -
			   /prompt="''screen$prompt_position'_Key name: "
$			omi$log_session "''omi$_p2'"
$			omi$cmdline_clear
$			goto import_cmd$import_key
$		endif
$!
$		if f$type(keyring$'omi$_p2') .nes. ""
$		   then
$			omi$signal omi exkey,omi$_p2
$			return omi$_warning
$		endif
$!
$		if f$search("omi$:omi$global_keyring.dat") .eqs. ""
$		   then
$			omi$signal omi glkeynf,omi$_p2
$			return omi$_warning
$		endif
$!
$		open /read /error=import_cmd$nopriv imp$_key omi$:omi$global_keyring.dat
$!
$	 import_cmd$_read_global_key:
$!
$		read /end_of_file=import_cmd$end_read_global_key imp$_key _keys
$		if f$edit(f$element(0, "=", _keys), "upcase") .eqs. -
		   f$edit(omi$_p2, "upcase") then $ goto import_cmd$_key_found
$		goto import_cmd$_read_global_key
$!
$	 import_cmd$end_read_global_key:
$!
$		omi$signal omi glkeynf,omi$_p2
$		return omi$_warning
$!
$	 import_cmd$_key_found:
$!
$		close imp$_key
$		_key = f$element(1, "=", _keys)
$		_new_line = "  ''omi$_p2' = ''_key'"
$!
$		_config_file = f$trnlnm("Omi$Config")
$		if _config_file .eqs. "" then $ _config_file = "Sys$Login:Omi$Menu.Cfg"
$		if f$search("''_config_file'") .eqs. ""
$		   then
$			omi$signal omi nocfg
$			return omi$_warning
$		endif
$!
$		search '_config_file' "[keyring]" /output=nla0:
$		if $status .eq. omi$_nomatch
$		   then
$			open /append cfgfi '_config_file'
$			write cfgfi ""
$			write cfgfi "[keyring]"
$			write cfgfi "''_new_line'"
$			close cfgfi
$		   else
$			open /read cfgfi '_config_file'
$			open /write cfgfo Sys$Scratch:Omi$NewCfg._Tmp$
$!
$		 main$execcmd_importkey:
$!
$			read /end_of_file=main$execcmd_key_imported cfgfi _cfgin
$			write cfgfo _cfgin
$			if f$locate("[keyring]", f$edit(_cfgin, "lowercase")) -
			   .lt. f$length(_cfgin) then $ write cfgfo "''_new_line'"
$			goto main$execcmd_importkey
$!
$		 main$execcmd_key_imported:
$!
$			close cfgfi
$			close cfgfo
$			delete\ /nolog /noconfirm '_config_file';
$			copy /nolog Sys$Scratch:Omi$NewCfg._Tmp$ '_config_file'
$			delete\ /nolog /noconfirm Sys$Scratch:Omi$NewCfg._Tmp$;*
$		endif
$		keyring$'omi$_p2' == _key
$		omi$signal omi impkey,omi$_p2
$		return omi$_ok
$	endif
$
$	omi$signal omi ivopt,import
$!
$ import_command$_cancelled:
$!
$	omi$log_session "<Ctrl/Z>"
$	omi$cmdline_clear
$	return omi$_ok
$!
$ import_cmd$nopriv:
$!
$	omi$signal omi noimprv
$	return $status
$!
$!******************************************************************************
$!
$ main$execcmd_help:
$!
$!==>	The OMI command HELP
$!
$	assign /user /nolog TT: sys$input
$	help /library=Omi$:Omi$Menu 'omi$_p1 'omi$_p2 'omi$_p3 'omi$_p4
$	omi$refresh
$	return omi$_ok
$!
$!******************************************************************************
$!
$ main$execcmd_increase:
$!
$!==>	The OMI command INCREASE
$!
$	if f$type('omi$current_menu'$counter) .eqs. ""
$	   then
$		omi$signal omi nocntinc
$		return omi$_warning
$	endif
$!
$	_menu_counter = 'omi$current_menu'$counter
$	counter$'_menu_counter' == counter$'_menu_counter' + 1
$	init_def$search_string = "''omi$current_menu'$input,counter$ /match=and"
$	gosub main$default_values
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "REFRESH") -
	   then $ omi$refresh inside_only
$!
$	return omi$_ok
$!
$!******************************************************************************
$!
$ main$execcmd_info:
$!
$!==>	The OMI command INFO
$!
$ !	omi$signal omi not_yet
$ !	return omi$_warning
$!
$	_hlp_file = f$parse(omi$menu_file,,,"name")
$	_hlp_file = f$search("omi$menu_directory:''_hlp_file'.omh")
$	if _hlp_file .eqs. ""
$	   then
$		omi$signal omi nohlpfil
$		return $status
$	endif
$	_info_key = f$edit(omi$current_menu,"upcase")
$	if _info_key .eqs. "OTF_MENU"
$	   then
$		if f$type(otf_menu$info_key) .nes. "" then -
		   $ _info_key = f$edit(otf_menu$info_key, "upcase")
$	endif
$	search '_hlp_file "[''_info_key']" /output=nla0:
$	if $status .eq. omi$_nomatch
$	   then
$		omi$signal omi nohlp,'omi$current_menu
$		return $status
$	endif
$!
$	open /read omi$hlp '_hlp_file
$!
$ info$_find:
$!
$	read /end_of_file=info$_notfound omi$hlp _mnu_info
$	if _mnu_info .eqs. "<EOF>" then $ goto info$_notfound
$	if f$edit(_mnu_info, "uncomment,collapse,upcase") .nes. -
	   "[''_info_key']" then -
	   $ goto info$_find
$	available_lines = screen$line_command - screen$line_header - -
	   screen$window_topmargin - 2
$	rec_counter = 1
$!
$ info$_read:
$!
$	read /end_of_file=info$end_read omi$hlp omi$record'rec_counter'
$	if omi$record'rec_counter' .eqs. "" then -
	   $ omi$record'rec_counter' = " " ! Workaround for a known bug
$	if f$extract(0,1,f$edit(omi$record'rec_counter',"trim")) .eqs. "[" then -
	   $ goto info$end_read
$	if omi$record'rec_counter' .eqs. "<EOF>" then $ goto info$end_read
$	if omi$record'rec_counter' .eqs. "<FF>" then $ goto info$_display
$!
$	rec_counter = rec_counter + 1
$	if rec_counter .gt. available_lines then $ goto info$_display
$	goto info$_read
$!
$ info$_display:
$!
$	omi$record'rec_counter' = ""
$	omi$display_info
$	omi$wait
$	if $status .eq. omi$_cancelled then $ goto info$_done
$	rec_counter = 1
$	goto info$_read
$!
$ info$_notfound:
$!
$	close omi$hlp
$	omi$signal omi nohlp,'omi$current_menu
$	return $status
$!
$ info$end_read:
$!
$	omi$record'rec_counter' = ""
$	omi$display_info
$ !	if f$type(omi$record'rec_counter') .nes. "" then -
  !	   delete\ /symbol /global omi$record'rec_counter'
$!
$	omi$wait
$!
$ info$_reset_records:
$!
$	omi$record'rec_counter' = ""
$	rec_counter = rec_counter - 1
$	if rec_counter .ge. 1 then $ goto info$_reset_records
$!
$ info$_done:
$!
$	close omi$hlp
$	omi$refresh inside_only
$	return omi$_ok
$!
$!******************************************************************************
$!
$ main$execcmd_jump:
$!
$!==>	The OMI command JUMP
$!
$	if omi$_p1 .eqs. ""
$	   then
$		read /end_of_file=jump$_ignored sys$command omi$_p1 -
		   /prompt="''screen$prompt_position'_Submenu: "
$		omi$log_session "''omi$_p1'"
$		omi$cmdline_clear
$		omi$msgline_clear
$		goto main$execcmd_jump
$	endif
$	assign sys$scratch:omi$jump_submenu._tmp$ sys$output
$	show symbol /global *$name
$	deassign sys$output
$	if .not. omi$_debug then -
	   $ set message /nofacility /noseverity /noidentification /notext
$	search sys$scratch:omi$jump_submenu._tmp$ """''omi$_p1'""" -
	   /output=sys$scratch:omi$jump_submenu_found._tmp$
$	_status = $status
$	delete /nolog /noconfirm sys$scratch:omi$jump_submenu._tmp$;
$	if _status .eq. omi$_nomatch
$	   then
$		delete /nolog /noconfirm sys$scratch:omi$jump_submenu_found._tmp$;
$		omi$signal omi nosuchname,'f$edit(omi$_p1,"upcase")
$		return omi$_warning
$	endif
$	open /read jump sys$scratch:omi$jump_submenu_found._tmp$
$	read jump _mnu_name
$	close jump
$	delete /nolog /noconfirm sys$scratch:omi$jump_submenu_found._tmp$;
$!
$	if f$type (omi$current_menu) .eqs. "" then $ omi$current_menu = ""
$	'f$edit(f$element(0, "$", _mnu_name), "collapse")'$previous = omi$current_menu
$	omi$current_menu = f$edit(f$element(0, "$", _mnu_name), "collapse")
$!
$	gosub main$check_security
$	if 'omi$current_menu'$security_level .eq. -1
$	   then
$		omi$msgline_clear
$		omi$signal omi ivpwd
$		omi$current_menu = 'omi$current_menu'$previous
$		return omi$_warning
$	endif
$	if 'omi$current_menu'$security_level .eq. 0
$	   then
$		omi$msgline_clear
$		omi$signal omi nopriv
$		omi$current_menu = 'omi$current_menu'$previous
$		return omi$_warning
$	endif
$!
$	if f$type('omi$current_menu'$on_init) .nes. "" .and. perf$init_exit
$	   then
$		perf$init_exit = 0
$		if f$extract(0,1,f$edit('omi$current_menu'$on_init,"collapse")) .eqs. ":"
$		   then
$			omi$_command = f$edit('omi$current_menu'$on_init - ":", "trim,compress,upcase")
$			gosub main$omi_command
$			_status = $status
$			goto main$perfd_oninit
$		endif
$		omi$init_job = f$element(0, " ", 'omi$current_menu'$on_init)
$		_params = 'omi$current_menu'$on_init - omi$init_job
$ !!! 		omi$init_job  = f$parse(omi$init_job,".OMI", -
  !!! 		   "OMI$Menu_Directory:",,"syntax_only")
$ !!!		if f$locate(".",omi$init_job) .eq. f$length(omi$init_job) -
  !!!		   then $ omi$init_job = omi$init_job + ".OMI"
$ !!!		@'omi$init_job '_params'
$		omi$call 'omi$init_job '_params'
$		_status = $status
$!
$ main$perfd_oninit:
$!
$		if _status .ge. omi$_warning
$		   then
$			omi$current_menu = 'omi$current_menu'$previous
$			return omi$_warning
$		endif
$	endif
$!
$	if f$type('omi$current_menu'$counter) .nes. ""
$	   then
$		_menu_counter = 'omi$current_menu'$counter
$		counter$'_menu_counter' == counter$'_menu_counter' + 1
$		init_def$search_string = -
		   "''omi$current_menu'$input,counter$ /match=and"
$		gosub main$default_values
$	endif
$!
$	if f$type(omi$_p2) .nes. ""
$	   then
$		if omi$_p2 .eqs. ""
$		   then $ omi$_jumping = 0
$		   else $ omi$_jumping = 1
$		endif
$	endif
$	if f$type(jump$_norefresh) .eqs. "" then $ omi$refresh
$	return omi$_ok
$!
$ jump$_ignored:
$!
$	omi$log_session "<Ctrl/Z>"
$	return omi$_ok
$!
$!******************************************************************************
$!
$ main$execcmd_reset:
$!
$!==>	The OMI command RESET
$!
$	if omi$_p1 .eqs. ""
$	   then
$		read /end_of_file=resetcommand$_cancelled sys$command omi$_p1 -
		   /prompt="''screen$prompt_position'_What: "
$		omi$log_session "''omi$_p1'"
$		omi$_p1 = f$edit(omi$_p1,"uncomment,trim,compress,upcase")
$		omi$cmdline_clear
$		goto main$execcmd_reset
$	endif
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "COUNTER")
$	   then
$		if f$type('omi$current_menu'$counter) .eqs. ""
$		   then $ omi$signal omi nocount
$		   else
$			_menu_counter = 'omi$current_menu'$counter
$			counter$'_menu_counter' == 0
$		endif
$		return omi$_ok
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "AUTO_REFRESH")
$	   then
$		'omi$current_menu'$auto_refresh = 0
$		return omi$_ok
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "ORDER")
$	   then
$		if f$type('omi$current_menu'$required_order) .eqs. ""
$		   then $ omi$signal omi noorder
$		   else $ 'omi$current_menu'$reqwork_order = -
			f$edit('omi$current_menu'$required_order, "collapse")
$		endif
$		return omi$_ok
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "VARIABLES")
$	   then
$		varreset$ = 0
$		init_def$search_string =  "''omi$current_menu'$input"
$		gosub main$default_values
$!
$		if f$type('omi$current_menu'$counter) .nes. ""
$		   then
$!			* Check for arrays (counters)
$			init_def$search_string = -
 			   "''omi$current_menu'$input,counter$ /match=and"
$			gosub main$default_values
$		endif
$		if varreset$ .eq. 0
$		   then
$			delete\ /symbol /local varreset$
$			omi$signal omi novars
$			return $status
$		endif
$		delete\ /symbol /local varreset$
$		if f$extract(0, 3, f$edit(omi$_p2, "upcase")) .nes. "BAC" !Background
$		   then
$			omi$refresh inside_only
$			omi$signal omi resetvar
$		endif
$		return $status
$	endif
$!
$!	**** Reset commands below are not available in OTF Menus
$!
$	if omi$otf_menu
$	   then
$		omi$signal omi cmdnotav
$		return $status
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "PASSWORD")
$	   then
$		if 'omi$current_menu'$security_level .lt. 3
$		   then
$			omi$signal omi nopriv
$			return omi$_warning
$		endif
$		if f$type('omi$current_menu'$password) .eqs. ""
$		   then $ omi$signal omi nopwd
$		   else
$			omi$config 'omi$menu_file' setcmd password reset
$			if $status .eq. omi$_ok then $ omi$signal omi rempwd
$		endif
$		return omi$_ok
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "NAME")
$	   then
$		if 'omi$current_menu'$security_level .lt. 3
$		   then
$			omi$signal omi nopriv
$			return omi$_warning
$		endif
$		if f$type('omi$current_menu'$name) .eqs. ""
$		   then $ omi$signal omi nomnuname
$		   else
$			omi$config 'omi$menu_file' setcmd name reset
$			if $status .eq. omi$_ok then $ omi$signal omi remname
$		endif
$		return omi$_ok
$	endif
$!
$	omi$signal omi ivopt,reset
$!
$ resetcommand$_cancelled:
$!
$	omi$log_session "<Ctrl/Z>"
$	omi$cmdline_clear
$	return omi$_ok
$!
$!******************************************************************************
$!
$ main$execcmd_set:
$!
$!==>	The OMI command SET
$!
$	if omi$_p1 .eqs. ""
$	   then
$		read /end_of_file=setcommand$_cancelled sys$command omi$_p1 -
		   /prompt="''screen$prompt_position'_What: "
$		omi$log_session "''omi$_p1'"
$		omi$_p1 = f$edit(omi$_p1,"uncomment,trim,compress,upcase")
$		omi$cmdline_clear
$		goto main$execcmd_set
$	endif
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "COUNTER")
$	   then
$		if omi$_p2 .eqs. ""
$		   then
$			read /end_of_file=setcommand$_cancelled sys$command omi$_p2 -
			   /prompt="''screen$prompt_position'_Value: "
$			omi$log_session "''omi$_p2'"
$			omi$_p2 = f$edit(omi$_p2,"uncomment,trim,compress")
$			omi$cmdline_clear
$			goto main$execcmd_set
$		endif
$!
$		if f$type('omi$current_menu'$counter) .eqs. ""
$		   then $ omi$signal omi nocount
$		   else
$			_menu_counter = 'omi$current_menu'$counter
$			counter$'_menu_counter' == omi$_p2
$			init_def$search_string = -
			   "''omi$current_menu'$input,counter$ /match=and"
$			gosub main$default_values
$		endif
$		return omi$_ok
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "AUTO_REFRESH")
$	   then
$		if omi$_p2 .eqs. ""
$		   then
$			read /end_of_file=setcommand$_cancelled sys$command omi$_p2 -
			   /prompt="''screen$prompt_position'_Value: "
$			omi$log_session "''omi$_p2'"
$			omi$_p2 = f$edit(omi$_p2,"uncomment,trim,compress")
$			omi$cmdline_clear
$			goto main$execcmd_set
$		endif
$!
$		if omi$_p2 .lt. 0
$		   then
$			omi$signal omi lowval,0
$			return $status
$		endif
$		if omi$_p2 .gt. 255
$		   then
$			omi$signal omi hival,255
$			return $status
$		endif
$		'omi$current_menu'$auto_refresh = omi$_p2
$		return omi$_ok
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "WIDTH")
$	   then
$		if omi$_p2 .eqs. ""
$		   then
$			read /end_of_file=setcommand$_cancelled sys$command omi$_p2 -
			   /prompt="''screen$prompt_position'_Value: "
$			omi$log_session "''omi$_p2'"
$			omi$_p2 = f$edit(omi$_p2,"uncomment,trim,compress")
$			omi$cmdline_clear
$			goto main$execcmd_set
$		endif
$		if omi$_p2 .ne. 80 .and. omi$_p2 .ne. 132
$		   then
$			omi$signal omi ivswval
$			omi$cmdline_clear
$			omi$_p2 = ""
$			goto main$execcmd_set
$		   else
$			screen$width == omi$_p2
$			@Omi$:Omi$Screen Setup
$			omi$refresh
$			return omi$_ok
$		endif
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "KEY")
$	   then
$		_config_file = f$trnlnm("Omi$Config")
$		if _config_file .eqs. "" then $ _config_file = "Sys$Login:Omi$Menu.Cfg"
$		if f$search("''_config_file'") .eqs. ""
$		   then
$			omi$signal omi nocfg
$			return omi$_warning
$		endif
$!
$	 main$execcmd_setkey_getname:
$!
$		if omi$_p2 .eqs ""
$		   then
$			omi$ask "_Key name: "
$			omi$_p2 = omi$response
$			if $status .eq. omi$_cancelled then $ return omi$_ok
$			delete\ /symbol /global omi$response
$		endif
$!
$		if f$type(keyring$'omi$_p2') .nes. ""
$		   then
$			omi$signal omi exkey,'omi$_p2
$			omi$_p2 = ""
$			goto main$execcmd_setkey_getname
$		endif
$!
$		search '_config_file' "[keyring]" /output=nla0:
$		if $status .eq. omi$_nomatch
$		   then
$			open /append cfgfi '_config_file'
$			write cfgfi ""
$			write cfgfi "[keyring]"
$			write cfgfi "  ''omi$_p2' = "
$			close cfgfi
$		   else
$			open /read cfgfi '_config_file'
$			open /write cfgfo Sys$Scratch:Omi$NewCfg._Tmp$
$!
$		 main$execcmd_setkey_init:
$!
$			read /end_of_file=main$execcmd_setkey_inited cfgfi _cfgin
$			write cfgfo _cfgin
$			if f$locate("[keyring]", f$edit(_cfgin, "lowercase")) -
			   .lt. f$length(_cfgin) then $ write cfgfo "  ''omi$_p2' = "
$			goto main$execcmd_setkey_init
$!
$		 main$execcmd_setkey_inited:
$!
$			close cfgfi
$			close cfgfo
$			delete\ /nolog /noconfirm '_config_file';
$			copy /nolog Sys$Scratch:Omi$NewCfg._Tmp$ '_config_file'
$			delete\ /nolog /noconfirm Sys$Scratch:Omi$NewCfg._Tmp$;*
$		endif
$!
$	 main$execcmd_setkey:
$!
$		if omi$_p3 .eqs. ""
$		   then
$			read /end_of_file=setcommand$_cancelled sys$command omi$_p3 -
			   /prompt="''screen$prompt_position'_Key: "
$			omi$log_session "''omi$_p3'"
$			omi$_p3 = f$edit(omi$_p3,"uncomment,trim,compress")
$			omi$msgline_clear
$			omi$cmdline_clear
$			goto main$execcmd_setkey
$		endif
$!
$		_validate_key = "omi$_p3"
$		gosub security$key_validate
$		if omi$_p3 .eq. 0 then $ goto main$execcmd_setkey
$		_key = "      "
$		_key[16,8] = %x81
$		_key[24,8] = %xb8
$		_key[32,8] = %x98
$		_key[40,8] = %xb9
$		_key[0,8]  = %X1
$		_key[8,8]  = f$integer(omi$_p3)
$		@Omi$:Omi$Config setup "" UPDATE "keyring" "''omi$_p2'" "''_key'"
$!
$		if $status .eq. omi$_ok then $ omi$signal omi setkey
$		omi$cmdline_clear
$		return omi$_ok
$	endif
$!
$!	**** Set commands below are not available in OTF Menus
$!
$	if omi$otf_menu
$	   then
$		omi$signal omi cmdnotav
$		return $status
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "PASSWORD")
$	   then
$		if 'omi$current_menu'$security_level .lt. 3
$		   then
$			omi$signal omi nopriv
$			return omi$_warning
$		endif
$		set terminal /noecho
$!
$	  setpwd$_prompt:
$!
$		read /end_of_file=setpasswrd$_cancelled sys$command _pwd_1 -
		   /prompt="''screen$prompt_position'_New password: "
$		omi$cmdline_clear
$		if f$length(_pwd_1) .lt. 5
$		   then
$			omi$signal omi shortpwd
$			goto setpwd$_prompt
$		endif
$		read /end_of_file=setpasswrd$_cancelled sys$command _pwd_2 -
		   /prompt="''screen$prompt_position'_Verification: "
$		if _pwd_1 .nes. _pwd_2
$		   then
$			omi$signal omi pwdverfail
$			goto setpasswrd$_cancelled
$		endif
$!
$		set terminal /echo
$		omi$encrypt "''_pwd_1'" p$_key
$		_new_password = omi$encrypted
$		delete\/symbol/global omi$encrypted
$		omi$log_session "''_new_password'"
$		omi$log_session "''_new_password'" ! Yeah I'm cheeting here ;)
$		omi$config 'omi$menu_file' setcmd password "''_new_password'"
$		if $status .eq. omi$_ok then $ omi$signal omi setpwd
$		omi$cmdline_clear
$		return omi$_ok
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "NAME")
$	   then
$		if 'omi$current_menu'$security_level .lt. 3
$		   then
$			omi$signal omi nopriv
$			return omi$_warning
$		endif
$		if omi$_p2 .eqs. ""
$		   then
$			read /end_of_file=setcommand$_cancelled sys$command _new_name -
			   /prompt="''screen$prompt_position'_New name : "
$			omi$log_session "''_new_name'"
$		   else $ _new_name = omi$_p2
$		endif
$		omi$cmdline_clear
$!
$		omi$config 'omi$menu_file' setcmd name "''f$edit(_new_name,"collapse")'"
$		if $status .eq. omi$_ok then $ omi$signal omi setname
$		omi$cmdline_clear
$		return omi$_ok
$	endif
$!
$	omi$signal omi ivopt,set
$!
$ setcommand$_cancelled:
$!
$	omi$log_session "<Ctrl/Z>"
$	omi$cmdline_clear
$	return omi$_ok
$!
$ setpasswrd$_cancelled:
$!
$	set terminal /echo
$	omi$cmdline_clear
$	return omi$_ok
$!
$!******************************************************************************
$!
$ main$execcmd_show:
$!
$!==>	The OMI command SHOW
$!
$	if omi$_p1 .eqs. ""
$	   then
$		read /end_of_file=showcommand$_cancelled sys$command omi$_p1 -
		   /prompt="''screen$prompt_position'_What: "
$		omi$log_session "''omi$_p1'"
$		omi$_p1 = f$edit(omi$_p1,"uncomment,trim,compress,upcase")
$		omi$cmdline_clear
$		goto main$execcmd_show
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "COUNTER")
$	   then
$		if f$type('omi$current_menu'$counter) .nes. ""
$		   then
$			_menu_counter = 'omi$current_menu'$counter
$			omi$signal omi counter,counter$'_menu_counter'
$		   else $ omi$signal omi nocounter
$		endif
$		return omi$_ok
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "TEXTAREA")
$	   then
$		gosub textarea$_find_ta
$		if $status .ne. omi$_ok then $ return $status
$		if _areas_found .gt. 1 .and. omi$_p2 .eqs. ""
$		   then
$			omi$signal omi nouniqta
$			return $status
$		endif
$		if omi$_p2 .eqs. "" then $ omi$_p2 = 1
$!
$		if f$type ('omi$current_menu'$ta_list'omi$_p2'_name) .eqs. ""
$		   then
$			omi$signal omi nosuchta
$			return $status
$		endif
$!
$		_textarea = 'omi$current_menu'$ta_list'omi$_p2'_name
$		if f$type('_textarea) .eqs. ""
$		   then
$			omi$signal omi taempty
$			return $status
$		endif
$!
$		_window = ( f$extract(0,3,f$edit(screen$scroll_region,"upcase")) .eqs. "ENA")
$		if _window
$		   then $ omi$screen setup_scroll_region
$		   else $ cls
$		endif
$		ws '_textarea
$		ws ""
$		omi$wait
$		if _window
$		   then $ omi$screen erase_scroll_region
$		   else $ omi$refresh
$		endif
$!
$		return omi$_ok
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "VERSION")
$	   then
$		omi$signal omi version,omi$version
$		return omi$_ok
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "NAME")
$	   then
$		if f$type('omi$current_menu'$name) .eqs. ""
$		   then $ omi$signal omi noname
$		   else
$			_this_mnu_name = f$edit('omi$current_menu'$name,"upcase")
$			omi$signal omi name,_this_mnu_name
$		endif
$		return omi$_ok
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "VMS_MESSAGE")
$	   then
$!
$	 main$execcmd_show_vmsmsg:
$!
$		if omi$_p2 .eqs. ""
$		   then
$			read /end_of_file=setcommand$_cancelled sys$command omi$_p2 -
			   /prompt="''screen$prompt_position'_Status code: "
$			omi$log_session "''omi$_p2'"
$			omi$_p2 = f$edit(omi$_p2,"uncomment,trim,compress")
$			omi$msgline_clear
$			omi$cmdline_clear
$			goto main$execcmd_show_vmsmsg
$		endif
$		omi$get_vmsmessage 'omi$_p2
$		_status = $status
$		if _status .eq. omi$_warning then $ omi$signal omi novmsmsg,'omi$_p2
$		if _status .ne. omi$_ok then $ return _status
$		omi$display_message "''omi$vms_message'"
$		delete\ /symbol /global omi$vms_message
$		return omi$_ok
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "ORDER")
$	   then
$		if f$type('omi$current_menu'$required_order) .eqs. ""
$		   then
$			omi$signal omi noorder
$			return $status
$		endif
$		if f$type('omi$current_menu'$reqwork_order) .eqs. "" then -
		   $ 'omi$current_menu'$reqwork_order = -
		   f$edit('omi$current_menu'$required_order, "collapse")
$		_cnt = 0
$		_msg_string = ""
$!
$	 show$_order_lookup:
$!
$		_opt_first = f$element (_cnt, ",", 'omi$current_menu'$reqwork_order)
$		if _opt_first .eqs. "," .or. _opt_first .eq. "" then -
		   $ goto show$end_order_lookup
$		_opt_first = _opt_first + inputs$highest_item
$		_msg_string = _msg_string + "''_opt_first'/"
$		_cnt = _cnt + 1
$		goto show$_order_lookup
$!
$	 show$end_order_lookup:
$!
$		_msg_string = f$extract(0, f$length(_msg_string)-1, _msg_string)
$		if _msg_string .eqs. ""
$		   then $ omi$signal omi reqselected
$		   else $ omi$signal omi curorder,_msg_string
$		endif
$		return $status
$	endif
$!
$	omi$signal omi ivopt,show
$!
$ showcommand$_cancelled:
$!
$	omi$log_session "<Ctrl/Z>"
$	omi$cmdline_clear
$	return omi$_ok
$!
$!******************************************************************************
$!
$ main$execcmd_main:
$!
$!==>	The OMI command MAIN
$!
$	gosub main$perf_onexit
$	if $status .eq. omi$_warning then $ return omi$_warning
$	omi$current_menu = "menu"
$	omi$screen menu
$	return omi$_ok
$!
$!******************************************************************************
$!
$ main$execcmd_refresh:
$!
$!==>	The OMI command REFRESH
$!
$	omi$refresh
$	return omi$_ok
$!
$!******************************************************************************
$!
$ main$execcmd_cls:
$!
$!==>	The OMI command CLS
$!
$	omi$clear_screen
$	return omi$_ok
$!
$!******************************************************************************
$!
$ main$execcmd_spawn:
$!
$!==>	The OMI command SPAWN
$!
$	if (f$type(interactive_auth$'omi$current_user') .nes. "" .or. -
	   f$type(interactive_auth$all_users) .nes. "") .and. -
	   f$type(omi$option) .nes. "INTEGER"
$	   then
$		if f$type(interactive_auth$'omi$current_user') .eqs. ""
$		   then $ if .not. interactive_auth$all_users then -
			   $ goto interactive$_disallow
$		   else $ if .not. interactive_auth$'omi$current_user' then -
			   $ goto interactive$_disallow
$		endif
$	endif
$!
$	cls
$	set message 'omi$_message'
$	if f$locate("ignore=dcle", omi$steering) .lt. f$length(omi$steering) -
	   then $ on error then $ continue
$	if f$locate("ignore=dclf", omi$steering) .lt. f$length(omi$steering) -
	   then $ on severe_error then $ continue
$	spawn 'omi$_p1' 'omi$_p2' 'omi$_p3' 'omi$_p4' 'omi$_p5'
$	if f$locate("ignore=dcle", omi$steering) .lt. f$length(omi$steering) -
	   then $ on error then $ goto main$_fatal
$	if f$locate("ignore=dclf", omi$steering) .lt. f$length(omi$steering) -
	   then $ on severe_error then $ goto main$_fatal
$	if .not. omi$_debug then -
	   $ set message /nofacility /noseverity /noidentification /notext
$	ws ""
$	read /end_of_file=spawn$_ignore sys$command dummy -
	   /prompt="''ESC$'[?25l''questions$wait_prompt' "
$!
$ spawn$_ignore:
$!
$	ws "''ESC$'[?25h"
$	omi$refresh
$	return omi$_ok
$!
$!******************************************************************************
$!
$ main$execcmd_submit:
$!
$!==>	The OMI command SUBMIT
$!
$	if omi$_p1 .nes. ""
$	   then
$		omi$background_module = "''omi$_p1'"
$		omi$_p1 = ""
$	   else
$		read /end_of_file=submit$_ignore sys$command omi$background_module -
		   /prompt="''screen$prompt_position'Module: "
$		omi$log_session "''omi$background_module'"
$		omi$cmdline_clear
$		omi$msgline_clear
$	endif
$	omi$background_mode = "batch"
$	omi$call omi$background_module
$	return $status
$!
$ submit$_ignore:
$!
$	omi$log_session "<Ctrl/Z>"
$	return omi$_ok
$!
$!******************************************************************************
$!
$ main$execcmd_all:
$!
$!==>	The OMI command ALL
$!
$!	omi$cmdline_clear
$	if f$type('omi$current_menu'$input1) .eqs. ""
$	   then
$		omi$signal omi noinput
$		return omi$_ok
$	endif
$!
$	_all_inputs = 1
$	_input = 1
$	_pointer = screen$default_position - 1
$!
$ main$_getall_inputs:
$!
$	_line = inputs$first_line - 1 + _input
$	_variable = f$element(1,"#",'omi$current_menu'$input'_input')
$!
$	if f$extract(0,8,f$edit(_variable,"upcase")) .eqs. "{HIDDEN}"
$	   then
$		_variable = f$extract(8, f$length(_variable)-8, _variable)
$		_hidden = 1
$	   else $ _hidden = 0
$	endif
$!
$	if f$extract(0,5,f$edit(_variable,"upcase")) .eqs. "{TAG|"
$	   then
$		gosub main$_taglist
$		_input = _input + 1
$		if f$type('omi$current_menu'$input'_input') .nes. "" then -
		   $ goto main$_getall_inputs
$		return omi$_ok
$	endif
$	ws f$fao("''ESC$'[''_line';''inputs$value_location'H!''inputs$max_size'* ")
$	_sel_list = (f$extract(0,5,f$edit(_variable,"upcase")) .eqs. "{SEL|")
$	if _sel_list
$	   then
$		_select_list = f$extract(0, f$locate("}", _variable) + 1, _variable)
$		_variable = _variable - _select_list
$		_select_list = f$edit(_select_list,"upcase") - "{SEL|" - "}"
$		if f$type('_select_list'$filename) .nes. ""
$		   then
$			_blockname = _select_list
$			gosub input$_from_file
$			if $status .ne. omi$_ok then $ return $status
$		endif
$		omi$screen select_list
$	endif
$!
$ allinput$_prompt:
$!
$	if f$type(list$_scroll) .nes. "" then $ delete\/symbol/local list$_scroll
$	if _sel_list
$	   then
$		_prompt = f$element(0, "#",'omi$current_menu'$input'_input')
$		read /end_of_file=main$cancel_getall_inputs /prompt="''screen$prompt_position'''_prompt': " sys$command _value
$		omi$log_session "''_value'"
$	   else
$		if _hidden then $ set terminal /noecho
$		read /end_of_file=main$cancel_getall_inputs /prompt="''ESC$'[''_line';''inputs$value_location'H" sys$command _value
$		omi$log_session "''_value'"
$		if _hidden
$		   then
$			set terminal /echo
$!			_astrlen = f$length(_value)
$!			ws f$fao("!''_astrlen'**")
$		endif
$	endif
$!
$	if _value .eqs. ""
$	   then
$		if f$type('_variable') .eqs. ""
$		   then $ _value = main$empty_value
$		   else
$			_format = f$element(3, "#",'omi$current_menu'$input'_input')
$			if _format .nes. "" .and. _format .nes. "#"
$			   then
$				gosub input$_format
$				if $status .eq. omi$_warning
$				   then
$					omi$cmdline_clear
$					ws f$fao("''ESC$'[''_line';''inputs$value_location'H!''inputs$max_size'* ")
$					goto allinput$_prompt
$				endif
$				omi$cmdline_clear
$				_value = '_variable'
$			endif
$			_value = '_variable'
$		endif
$	   else
$		if _sel_list
$		   then
$			if f$edit(f$extract(0, 1, _value),"upcase") .eqs. "N"
$			   then
$				delete\ /symbol /local _value
$				list$_scroll = "NEXT"
$				omi$screen select_list
$				omi$cmdline_clear
$				goto allinput$_prompt
$			endif
$			if f$edit(f$extract(0, 1, _value),"upcase") .eqs. "P"
$			   then
$				delete\ /symbol /local _value
$				list$_scroll = "PREVIOUS"
$				omi$screen select_list
$				omi$cmdline_clear
$				goto allinput$_prompt
$			endif
$!
$			_selected = '_value'
$			if f$type(_selected) .nes. "INTEGER" .or. -
			   f$type('_select_list'$value'_selected') .eqs. ""
$			   then
$				omi$signal omi ivchoice
$				omi$cmdline_clear
$				ws f$fao("''ESC$'[''_line';''inputs$value_location'H!''inputs$max_size'* ")
$				goto allinput$_prompt
$			endif
$			if f$type(scroll$previous_page) .nes. "" then -
			   $ delete\/symbol/global scroll$previous_page
$			if f$type(scroll$this_page) .nes. "" then -
			   $ delete\/symbol/global scroll$this_page
$			if f$type(scroll$next_page) .nes. "" then -
			   $ delete\/symbol/global scroll$next_page
$			if f$type(scroll$max_on_page) .nes. "" then -
			   $ delete\/symbol/global scroll$max_on_page
$			'_variable' = '_select_list'$value'_selected'
$		   else
$			'_variable' = _value
$			_format = f$element(3, "#",'omi$current_menu'$input'_input')
$			if _format .nes. "" .and. _format .nes. "#"
$			   then
$				gosub input$_format
$				if $status .eq. omi$_warning
$				   then
$					omi$cmdline_clear
$					ws f$fao("''ESC$'[''_line';''inputs$value_location'H!''inputs$max_size'* ")
$					goto allinput$_prompt
$				endif
$				omi$cmdline_clear
$				_value = '_variable'
$			endif
$		endif
$	endif
$!
$	_blanks = inputs$max_size - f$length(_value) + 1
$	if _hidden
$	   then
$		_astrlen = f$length(_value)
$		_display_value = f$fao("!''_astrlen'**")
$	   else $ _display_value = _value
$	endif
$!
$	if _sel_list then $ omi$refresh inside_only
$	if f$length(_value) .le. inputs$max_size
$	   then $ ws f$fao("''ESC$'[''_line';''inputs$value_location'H''_display_value'!''_blanks'* ")
$	   else $ ws "''ESC$'[''_line';''inputs$value_location'H''f$extract(0,inputs$max_size,_display_value)'''ESC$'(0`''ESC$'(B"
$	endif
$	_input = _input + 1
$	if f$type('omi$current_menu'$input'_input') .nes. "" then -
	   $ goto main$_getall_inputs
$!
$ main$cancel_getall_inputs:
$!
$	omi$log_session "<Ctrl/Z>"
$	omi$refresh inside_only
$! fallthru
$ main$end_getall_inputs:
$!
$	if _hidden then $ set terminal /echo
$	return omi$_ok
$!
$!******************************************************************************
$!
$!==>	The OMI command (SILENT_)DCL
$!
$ main$execcmd_silent_dcl:
$!
$	_silent = 1
$	goto dclcommand$
$!
$ main$execcmd_dcl:
$!
$	_silent = 0
$	goto dclcommand$
$!
$ dclcommand$:
$!
$	if (f$type(interactive_auth$'omi$current_user') .nes. "" .or. -
	   f$type(interactive_auth$all_users) .nes. "") .and. -
	   f$type(omi$option) .nes. "INTEGER"
$	   then
$		if f$type(interactive_auth$'omi$current_user') .eqs. ""
$		   then $ if .not. interactive_auth$all_users then -
			   $ goto interactive$_disallow
$		   else $ if .not. interactive_auth$'omi$current_user' then -
			   $ goto interactive$_disallow
$		endif
$	endif
$!
$	if omi$_p1 .eqs. ""
$	   then
$		read /end_of_file=dclcommand$_cancelled sys$command omi$_p1 -
		   /prompt="''screen$prompt_position'''questions$dcl_command': "
$		omi$log_session "''omi$_p1'"
$		omi$_p1 = f$edit(omi$_p1,"uncomment,trim,compress")
$		if omi$_p1 .eqs. "" then $ goto  main$execcmd_dcl
$		omi$_p2 = f$edit(f$element(1," ",omi$_p1),"trim")
$		omi$_p3 = f$edit(f$element(2," ",omi$_p1),"trim")
$		omi$_p4 = f$edit(f$element(3," ",omi$_p1),"trim")
$		omi$_p5 = f$edit(f$element(4," ",omi$_p1),"trim")
$		omi$_p1 = f$edit(f$element(0," ",omi$_p1),"trim")
$	endif
$	if _silent
$	   then
$		assign /nolog "''main$silent_output'" sys$output
$		assign /nolog "''main$silent_output'" sys$error
$		goto dclcommand$do_it
$	endif
$	_window = ( f$extract(0,3,f$edit(screen$scroll_region,"upcase")) .eqs. "ENA")
$	if _window
$	   then $ omi$screen setup_scroll_region
$	   else $ cls
$	endif
$!
$ dclcommand$do_it:
$!
$	set message 'omi$_message'
$	if f$locate("ignore=dcle", omi$steering) .lt. f$length(omi$steering) -
	   then $ on error then $ continue
$	if f$locate("ignore=dclf", omi$steering) .lt. f$length(omi$steering) -
	   then $ on severe_error then $ continue
$	'omi$_p1' 'omi$_p2' 'omi$_p3' 'omi$_p4' 'omi$_p5'
$	set on
$	if f$locate("ignore=dcle", omi$steering) .lt. f$length(omi$steering) -
	   then $ on error then $ goto main$_fatal
$	if f$locate("ignore=dclf", omi$steering) .lt. f$length(omi$steering) -
	   then $ on severe_error then $ goto main$_fatal
$	if _silent
$	   then
$		_silent_status = $status
$		deassign sys$output
$		deassign sys$error
$		delete\ /symbol /local _silent
$		omi$display_message f$message(_silent_status)
$		goto dclcommand$_cancelled
$	endif
$!
$	ws ""
$  	read /end_of_file=dclcommand$_ignore sys$command dummy -
	   /prompt="''ESC$'[?25l''questions$wait_prompt' "
$!
$ dclcommand$_ignore:
$!
$	ws "''ESC$'[?25h"
$	if _window
$	   then $ omi$screen erase_scroll_region
$	   else $ omi$refresh
$	endif
$!
$ dclcommand$_cancelled:
$!
$	omi$log_session "<Ctrl/Z>"
$	if .not. omi$_debug then -
	   $ set message /nofacility /noseverity /noidentification /notext
$	omi$cmdline_clear
$	return omi$_ok
$!
$!******************************************************************************
$!
$ main$execcmd_delete:
$!
$!==>	The OMI command DELETE
$!
$	if omi$_p1 .eqs. ""
$	   then
$		read /end_of_file=deletecommand$_cancelled sys$command omi$_p1 -
		   /prompt="''screen$prompt_position'_What: "
$		omi$log_session "''omi$_p1'"
$		omi$_p1 = f$edit(omi$_p1,"uncomment,trim,compress,upcase")
$		omi$cmdline_clear
$		goto main$execcmd_delete
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. f$extract(0, f$length(omi$_p1), "TEXTAREA")
$	   then
$		if 'omi$current_menu'$security_level .lt. 3
$		   then
$			omi$signal omi nopriv
$			return omi$_warning
$		endif
$		gosub textarea$_find_ta
$		if $status .ne. omi$_ok then $ return $status
$		if _areas_found .gt. 1 .and. omi$_p2 .eqs. ""
$		   then
$			omi$signal omi nouniqta
$			return $status
$		endif
$		if omi$_p2 .eqs. "" then $ omi$_p2 = 1
$!
$		if f$type ('omi$current_menu'$ta_list'omi$_p2'_name) .eqs. ""
$		   then
$			omi$signal omi nosuchta
$			return $status
$		endif
$!
$		if .not. 'omi$current_menu'$ta_list'omi$_p2'_keep
$		   then
$			omi$signal omi tatemp
$			return $status
$		endif
$!
$		_textarea_file = 'omi$current_menu'$ta_list'omi$_p2'_file
$		if f$search(_textarea_file) .eqs. ""
$		   then
$			omi$signal omi tafnf
$			return $status
$		endif
$!
$		if questions$confirm
$		   then
$			_cq = "Delete " + _textarea_file + "* ? "
$			omi$confirm "''_cq'" 'questions$answer_no
$			if .not. omi$confirmed then $ return omi$_ok
$		endif
$		delete\ /nolog /noconfirm '_textarea_file'*
$!
$		_textarea = 'omi$current_menu'$ta_list'omi$_p2'_name
$		if f$type('_textarea) .nes. ""
$		   then
$			delete\ /symbol /local '_textarea
$		endif
$!
$		return omi$_ok
$	endif
$!
$	omi$signal omi ivopt,delete
$!
$ deletecommand$_cancelled:
$!
$	omi$log_session "<Ctrl/Z>"
$	omi$cmdline_clear
$	return omi$_ok
$!
$!******************************************************************************
$!
$ main$execcmd_manage:
$!
$!==>	The OMI command MANAGE
$!
$	if omi$_p1 .eqs. "BACK"
$	   then
$		omi$_p1 = omi$manage_started_from
$	   else
$		if f$edit(omi$menu_file,"upcase") .eqs. "OMI$MANAGE"
$		   then
$			omi$signal omi manage
$			return omi$_ok
$		endif
$		omi$manage_started_from = "''omi$menu_file'"
$		omi$_p1 = "OMI$MANAGE"
$	endif
$	goto main$execcmd_menu
$!
$!******************************************************************************
$!
$ main$execcmd_menu:
$!
$!==>	The OMI command MENU
$!
$	gosub main$perf_onexit
$	if $status .eq. omi$_warning then $ return omi$_warning
$	if f$edit(omi$current_menu,"upcase") .nes. "MENU"
$	   then
$		omi$current_menu = "menu"
$		gosub main$perf_onexit
$		if $status .eq. omi$_warning
$		   then
$			omi$screen menu
$			return omi$_warning
$		endif
$	endif
$	_ref_on_cancel = 0
$!
$ newmenu$_get:
$!
$	if omi$_p1 .nes. ""
$	   then
$		omi$new_menu_file = "''omi$_p1'"
$		omi$_p1 = ""
$	   else
$		read /end_of_file=newmenu$_ignored sys$command omi$new_menu_file -
		   /prompt="''screen$prompt_position'Menu file: "
$		omi$log_session "''omi$new_menu_file'"
$		omi$cmdline_clear
$		omi$msgline_clear
$	endif
$	if omi$new_menu_file .eqs. "?"
$	   then
$		_ref_on_cancel = 1
$		omi$call list_files omi$:*.mnu,omi$menu_directory:*.mnu name
$		goto newmenu$_get
$	endif
$!
$	omi$previous_menu_file = "''omi$menu_file'"
$	omi$menu_file = "''omi$new_menu_file'"
$!
$	omi$signal omi erasmnu
$	omi$config "''omi$previous_menu_file'" Cleanup
$	omi$msgline_clear
$	omi$signal omi init
$	omi$config 'omi$menu_file
$	if $status .ge. omi$_warning
$	   then
$		omi$signal omi restmnu
$		omi$config "''omi$menu_file'" Cleanup
$		omi$msgline_clear
$		omi$menu_file = "''omi$previous_menu_file'"
$		omi$signal omi init
$		omi$config 'omi$menu_file
$	endif
$	omi$refresh
$	return omi$_ok
$!
$ newmenu$_ignored:
$!
$	omi$log_session "<Ctrl/Z>"
$	if _ref_on_cancel
$	   then $ omi$refresh
$	   else
$		omi$cmdline_clear
$		omi$msgline_clear
$	endif
$	return omi$_ok
$!
$!******************************************************************************
$!
$ main$execcmd_add:
$ main$execcmd_modify:
$ main$execcmd_remove:
$ main$execcmd_rename:
$!
$!==>	The OMI command ...     !Preparing...
$!
$	omi$signal omi not_yet
$	return omi$_ok
$!
$!******************************************************************************
$!
$!==>	Display an error message if users that don't have the privileges try
$!	to execute an interactive command (using SPAWN or DCL)
$!
$ interactive$_disallow:
$!
$	omi$signal omi nodclprv
$	return $status
$!
$!******************************************************************************


$!******************************************************************************
$!
$!==>	Handle the OMI function keys
$!
$ main$execcmd_omikey_down:
$!
$	omi$keyselect_down
$	return omi$_ok
$!
$ main$execcmd_omikey_up:
$!
$	omi$keyselect_up
$	return omi$_ok
$!
$!******************************************************************************


$!******************************************************************************
$!
$!==>	The enhanced textarea support in v1.41 comes with some extra commands.
$!	This routines is created to find the textareas in the current menu,
$!	and their attributes.
$!
$ textarea$_find_ta:
$!
$	_input_counter = 0
$	_areas_found   = 0
$!
$ textarea$_loop_ta:
$!
$	_input_counter = _input_counter + 1
$	if f$type('omi$current_menu'$input'_input_counter') .eqs. "" then -
	   $ goto textarea$end_loop_ta
$	_format = f$element(3, "#", 'omi$current_menu'$input'_input_counter')
$	if _format .eqs. "" .or. _format .eqs. "#" then $ goto textarea$_loop_ta
$	if f$edit('_format'$type, "upcase") .nes. "TEXTAREA" then $ goto textarea$_loop_ta
$	_areas_found = _areas_found + 1
$	'omi$current_menu'$ta_list'_areas_found'_name = -
	   f$element(1, "#", 'omi$current_menu'$input'_input_counter')
$!
$	if f$type('_format'$keep) .eqs. ""
$	   then $ 'omi$current_menu'$ta_list'_areas_found'_keep = 0
$	   else $ 'omi$current_menu'$ta_list'_areas_found'_keep = '_format'$keep
$	endif
$!
$	if f$type('_format'$filename) .nes. ""
$	   then $ 'omi$current_menu'$ta_list'_areas_found'_file = -
		   '_format'$filename
$	   else $ 'omi$current_menu'$ta_list'_areas_found'_file = -
		   "ta_''omi$current_menu'$input''_input_counter'"
$	endif
$	'omi$current_menu'$ta_list'_areas_found'_file = -
	   f$parse('omi$current_menu'$ta_list'_areas_found'_file, "Omi$Menu_Directory:", ".txt")
$!
$	goto textarea$_loop_ta
$!
$ textarea$end_loop_ta:
$!
$	if _areas_found .eq. 0
$	   then
$		omi$signal omi notextarea
$		return $status
$	endif
$!
$	return omi$_ok
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Find out is a securoty level is defined for the current menu. If so,
$!	act upon it. If there's no security, return the default value, which
$!	is '2', meaning read and exec access for all users.
$!	If the current user is the owner of this (sub) menu, the security
$!	level will allways be '3' (read, exec and write).
$!
$ main$check_security:
$!
$	if f$type('omi$current_menu'$owner) .nes. ""
$	   then $ _owner = 'omi$current_menu'$owner
$	   else
$		if f$type(menu$owner) .nes. ""
$		   then
$			_owner = menu$owner
$		endif
$	endif
$!
$	if f$type('omi$current_menu'$password) .nes. ""
$	   then
$		if f$type('omi$current_menu'$ip_pintr) .nes. ""
$		   then
$			if 'omi$current_menu'$ip_pintr .eq. 3
$			   then
$				'omi$current_menu'$security_level = -2
$				omi$signal omi suspintr
$				return omi$_warning
$			endif
$		endif
$		if 'omi$current_menu'$password .eqs. ""
$		   then
$			omi$encrypt "Omi$System" p$_key
$			'omi$current_menu'$password == omi$encrypted
$			delete\ /symbol /global omi$encrypted
$		endif
$		_retries = 1
$!
$	   password$get_input:
$!
$		on control_y then $ goto password$cancel_input
$		set terminal /noecho
$		read /end_of_file=password$cancel_input /prompt="''screen$prompt_position'Password: " sys$command _password
$		omi$log_session f$fao("!''f$length(_password)'**")
$		omi$msgline_clear
$		goto password$_decrypt
$!
$	   password$cancel_input:
$!
$		omi$log_session "<Ctrl/Z>"
$		'omi$current_menu'$security_level = -1
$		on control_y then $ goto main$_interrupt
$		omi$cmdline_clear
$		set terminal /echo
$		return omi$_ok
$!
$	   password$_decrypt:
$!
$		on control_y then $ goto main$_interrupt
$		omi$cmdline_clear
$		set terminal /echo
$		omi$variable = "_password"
$		omi$input_validate
$		if $status .eq. omi$_error
$		   then
$			'omi$current_menu'$security_level = -1
$			return omi$_warning
$		endif
$		_encryptd = 'omi$current_menu'$password
$		omi$decrypt "''_encryptd'" p$_key
$		_decryptd = "''omi$decrypted'"
$		delete\/symbol/local _encryptd
$		delete\/symbol/global omi$decrypted
$		if _password .nes. _decryptd
$		   then
$			'omi$current_menu'$security_level = -1
$			delete\/symbol/local _decryptd
$			if _retries .lt. 3
$			   then
$				_retries = _retries + 1
$				omi$signal omi ivpassw
$				goto password$get_input
$			endif
$			if f$type('omi$current_menu'$ip_pintr) .eqs. ""
$			   then $ 'omi$current_menu'$ip_pintr == 1
$			   else $ 'omi$current_menu'$ip_pintr == -
				   'omi$current_menu'$ip_pintr + 1
$			endif
$			return omi$_warning
$		endif
$		delete\/symbol/local _decryptd
$		if f$type('omi$current_menu'$ip_pintr) .nes. "" then -
		   $ delete\ /symbol /global 'omi$current_menu'$ip_pintr
$!
$		if f$type('omi$current_menu'$password_level) .nes. ""
$		   then
$			'omi$current_menu'$security_level = 'omi$current_menu'$password_level
$			return omi$_ok
$		endif
$	endif
$!
$	if f$type(_owner) .nes. ""
$	   then
$		if f$locate(omi$current_user, f$edit(_owner,"upcase")) .lt. -
		   f$length(f$edit(_owner,"upcase"))
$		   then
$			'omi$current_menu'$security_level = 3
$			delete\/symbol/local _owner
$			return omi$_ok
$		endif
$	endif
$!
$	if f$type('omi$current_menu'$security) .eqs. ""
$	   then
$		'omi$current_menu'$security_level = 2
$		return omi$_ok
$	endif
$!
$	_security = 'omi$current_menu'$security
$!
$	if f$type('_security'$'omi$current_user') .nes. ""
$	   then $ _authorisation = f$edit('_security'$'omi$current_user',"upcase")
$	   else $ if f$type('_security'$all_users) .nes. "" then -
		    $ _authorisation = f$edit('_security'$all_users,"upcase")
$	endif
$!
$	if f$type(_authorisation) .eqs. ""
$	   then
$		'omi$current_menu'$security_level = 0
$		return omi$_ok
$	endif
$!
$	if f$locate("WRITE",_authorisation) .lt. f$length(_authorisation)
$	   then
$		delete\/symbol/local _authorisation
$		'omi$current_menu'$security_level = 3
$		return omi$_ok
$	endif
$!
$	if f$locate("EXEC",_authorisation) .lt. f$length(_authorisation)
$	   then
$		delete\/symbol/local _authorisation
$		'omi$current_menu'$security_level = 2
$		return omi$_ok
$	endif
$!
$	if f$locate("READ",_authorisation) .lt. f$length(_authorisation)
$	   then
$		delete\/symbol/local _authorisation
$		'omi$current_menu'$security_level = 1
$		return omi$_ok
$	endif
$!
$	delete\/symbol/local _authorisation
$	'omi$current_menu'$security_level = 0
$	return omi$_ok
$!
$ security$key_validate:
$!
$	if f$type('_validate_key') .nes. "INTEGER"
$	   then
$		omi$signal omi ivkeyval
$		'_validate_key' = ""
$		return omi$_ok
$	endif
$!
$	if '_validate_key' .lt. 1 .or. '_validate_key' .gt. 1000000
$	   then
$		omi$signal omi ivkeyval
$		'_validate_key' = ""
$		return omi$_warning
$	endif
$	return omi$_ok
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	The main exit routines. The cleanup procedure is called with a parameter
$!	that indicates whether or not the screen should be erased. In case or
$!	errors, we don't want to, since that would also erase the messages.
$!
$ main$_interrupt:
$!
$	if f$type(_silent) .nes. ""
$	   then
$		if _silent      ! In case the interrupt was during SILENT_DCL
$		   then
$			deassign sys$output
$			deassign sys$error
$		endif
$	endif
$	omi$_cls = "NOCLS"
$	gosub main$_cleanup
$	ws "%OMI-S-BYEBYE, done!"
$	set message 'omi$_message'      ! Just in case...
$	if .not. omi$_debug
$	   then $ if omi$_verify then $ set verify
$	endif
$	exit %X28
$!
$ main$_fatal:
$!
$	if f$type(_silent) .nes. ""
$	   then
$		if _silent      ! In case the error was during SILENT_DCL
$		   then
$			deassign sys$output
$			deassign sys$error
$		endif
$	endif
$	omi$_cls = "NOCLS"
$	gosub main$_cleanup
$	ws "%OMI-S-BYEBYE, done!"
$	set message 'omi$_message'      ! Just in case...
$	if .not. omi$_debug
$ 	   then $ if omi$_verify then $ set verify
$	endif
$	exit %X2c
$!
$ main$_exit:
$!
$	omi$log_session "END_SESSIONLOG"
$	omi$_cls = "CLS"
$	gosub main$_cleanup
$	ws "%OMI-S-BYEBYE, done!"
$	set message 'omi$_message'      ! Workaround.... there's a bug somewhere
$	if .not. omi$_debug
$	   then $ if omi$_verify then $ set verify
$	endif
$	if f$trnlnm("omi$menu_directory") .eqs. "OMI$" then -
	   deassign omi$menu_directory
$!
$ main$_final_bye:
$!
$	exit 1
$!
$ main$otf_exit:
$!
$	exit 1
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	When this procedure initializes, following options are checked to
$!	find the start menu. If it ain't given as a parameter, the procedure
$!	looks for the file Omi$Menu.Mnu in the current directory. Next, a
$!	logical is checked to find a user specified default. Finally, the
$!	procedure looks for the file Omi$Menu.Mnu in Sys$Login.
$!	The order in which this takes place can be modified using the
$!	'search_path' variable in the 'main' section of the configuration
$!	file, except for the parameter; this will allways overrule everything
$!	else.
$!
$ main$_getstart:
$!
$	if options$_startmenu .nes. ""
$	   then
$		omi$startmenu = "''f$parse(options$_startmenu,,,"name")'.MNU"
$		if omi$startmenu .eqs. ".MNU" .and. f$trnlnm("''options$_startmenu'") .nes. "" -
		   .and. f$locate(".", options$_startmenu) .eq. f$length(options$_startmenu)
$		   then
$!			There's a logical with the same name pointing somewhere else, so force
$!			the menuname to be a filename by adding an extension and try again.
$			options$_startmenu = options$_startmenu + ".MNU"
$			omi$startmenu = "''f$parse(options$_startmenu,,,"name")'.MNU"
$		endif
$		return omi$_ok
$	endif
$!
$	if f$trnlnm("Omi$StartMenu") .nes. ""
$	   then
$		omi$startmenu = "''f$parse(f$trnlnm("Omi$StartMenu"),,,"name")'.MNU"
$		return omi$_ok
$	endif
$!
$	return omi$_ok
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Look for command line parameters. These can be regular options
$!	(menu name, jump options), or qualifiers, if they start with a slash.
$!	If qualifiers are used, the first parameter (menu name) is required.
$!
$ main$_parse_options:
$!
$	omi$steering = ""
$	param$_counter = 0
$	param$_regular = 1
$!
$ params$_loop:
$!
$	param$_counter = param$_counter + 1
$	if p'param$_counter .eqs. "" then $ goto params$end_loop
$	if f$extract(0,1,p'param$_counter) .eqs. "/" then $ goto params$_qualeval
$	if f$locate("/", p'param$_counter) .lt. f$length(p'param$_counter)
$	   then
$		_this_parameter = f$element(0, "/", p'param$_counter)
$		_this_qualifier = p'param$_counter - _this_parameter
$		p'param$_counter = _this_parameter
$		delete\ /symbol /local _this_parameter
$	endif
$	if param$_regular .eq. 1 then $ options$_startmenu = p'param$_counter
$	if param$_regular .eq. 2 then $ options$_menuname  = p'param$_counter
$	if param$_regular .eq. 3 then $ options$_jumps     = p'param$_counter
$	param$_regular = param$_regular + 1
$	if f$type(_this_qualifier) .nes. ""
$	   then
$		p'param$_counter = _this_qualifier
$		delete\ /symbol /local _this_qualifier
$		goto params$_qualeval
$	endif
$	goto params$_loop
$!
$ params$_qualeval:
$!
$	qual$_counter = 1
$!
$ quals$_loop:
$!
$	_qualifier = f$element(qual$_counter, "/", p'param$_counter)
$	if _qualifier .eqs. "/" then $ goto params$_loop
$	qual$_name  = f$edit(f$element(0, "=", _qualifier),"upcase")
$	qual$_value = f$edit(f$element(1, "=", _qualifier),"upcase")
$	if qual$_value .eqs. "=" then $ qual$_value = ""
$	_value_specified = (qual$_value .nes. "")
$!
$	if f$extract(0, 2, qual$_name) .eqs. "NO"
$	   then
$		qual$_name = f$extract(2, f$length(qual$_name) - 2, qual$_name)
$		_negate = 1
$	   else $ _negate = 0
$	endif
$!
$	if _negate .and. _value_specified then $ goto qual$notneg_error
$!
$	if f$length(qual$_name) .lt. 3 then $ goto qual$abkeyw_error
$	qual$_counter = qual$_counter + 1
$!
$!==>	/[NO]DEBUG qualifier
$!
$	if qual$_name .eqs. f$extract(0, f$length(qual$_name), "DEBUG")
$	   then
$		if _value_specified
$		   then $ omi$_debug = qual$_value
$		   else $ omi$_debug = (_negate .eq. 0)
$		endif
$		if omi$_debug
$		   then $ if omi$_verify then $ set verify
$		endif
$		goto quals$_loop
$	endif
$!
$!==>	/SUBMENU=menu-name qualifier
$!
$	if qual$_name .eqs. f$extract(0, f$length(qual$_name), "SUBMENU")
$	   then
$		if _negate then $ goto quals$_loop
$		if qual$_value .eqs. "" then $ goto qual$valreq_error
$		options$_menuname  = "''qual$_value'"
$		goto quals$_loop
$	endif
$!
$!==>	/JUMPS=jumps qualifier
$!
$	if qual$_name .eqs. f$extract(0, f$length(qual$_name), "JUMPS")
$	   then
$		if _negate then $ goto quals$_loop
$		if qual$_value .eqs. "" then $ goto qual$valreq_error
$		options$_jumps  = "''qual$_value'"
$		goto quals$_loop
$	endif
$!
$!==>	/VALIDATE[=log-file]
$!
$	if qual$_name .eqs. f$extract(0, f$length(qual$_name), "VALIDATE")
$	   then
$		if _negate then $ goto quals$_loop
$		omi$validate_mode = 1
$		if qual$_value .eqs. ""
$		   then $ validate$log_file = ""
$		   else $ validate$log_file = "''qual$_value'"
$		endif
$		omi$progress = 0
$		goto quals$_loop
$	endif
$!
$!==>	/BATCH qualifier
$!
$	if qual$_name .eqs. f$extract(0, f$length(qual$_name), "BATCH")
$	   then
$		if _negate
$		   then
$			omi$batch_mode = 0
$			omi$progress = 1
$		   else
$			omi$batch_mode = 1
$			omi$progress = 0
$		endif
$		goto quals$_loop
$	endif
$!
$!==>	/BACKGROUND=(BATCH|DETACH) qualifier
$!
$	if qual$_name .eqs. f$extract(0, f$length(qual$_name), "BACKGROUND")
$	   then
$		if _negate then $ goto quals$_loop
$		if qual$_value .eqs. "" then $ qual$_value = "BATCH"
$		if f$extract(0, 3, qual$_value) .eqs. "BAT" then -
		   $ omi$background_mode = "batch"
$		if f$extract(0, 3, qual$_value) .eqs. "DET" then -
		   $ omi$background_mode = "detach"
$		if f$type(omi$background_mode) .eqs. "" then -
		   $ goto qual$ivbgrmod_error
$		if f$type(omi$batch_mode) .eqs. "" then $ omi$batch_mode = 1
$		if f$type(omi$progress) .eqs. "" then $ omi$progress = 0
$		omi$backgr_mode = 1
$		goto quals$_loop
$	endif
$!
$!==>	/[NO]IGNORE=(keyword,...) qualifier
$!
$	if qual$_name .eqs. f$extract(0, f$length(qual$_name), "IGNORE")
$	   then
$		_ignores = ""
$		if _negate then $ goto quals$_loop
$		if qual$_value .eqs. "" then $ goto qual$valreq_error
$		qual$_value = f$edit(qual$_value,"collapse,upcase") - "(" - ")"
$		_ign_cnt = 0
$!
$	 ignore$_values:
$!
$		_this_ign = ""
$		_ignore_val = f$element(_ign_cnt, ",", qual$_value)
$		if _ignore_val .eqs. "" .or. _ignore_val .eqs. "," then -
		   $ goto ignore$got_values
$		if f$length(_ignore_val) .lt. 4 then $ goto qual$abkeyw_error
$!
$!		==> /IGNORE=DUPLICATES
$!
$		if f$extract(0, 4, _ignore_val) .eqs. "DUPL" then -
		   $ _this_ignore = "dupl"
$!
$!		==> /IGNORE=DCLWARNINGS
$!
$		if f$extract(0, 4, _ignore_val) .eqs. "DCLE" then -
		   $ _this_ignore = "dcle"
$!
$!		==> /IGNORE=DCLFATALS
$!
$		if f$extract(0, 4, _ignore_val) .eqs. "DCLF" then -
		   $ _this_ignore = "dclf"
$		if _this_ignore .eqs. "" then $ goto qual$ivkeyw_error
$		_ignores = "''_ignores',ignore=''_this_ignore'"
$		_ign_cnt = _ign_cnt + 1
$		goto ignore$_values
$!
$	 ignore$got_values:
$!
$		omi$steering = "''omi$steering',''_ignores'"
$		goto quals$_loop
$	endif
$!
$!==>	/[NO]PROGRESS qualifier
$!
$	if qual$_name .eqs. f$extract(0, f$length(qual$_name), "PROGRESS")
$	   then
$		if _negate
$		   then $ omi$progress = 0
$		   else $ omi$progress = 1
$		endif
$		goto quals$_loop
$	endif
$!
$ !     if qual$_name .eqs. f$extract(0, f$length(qual$_name), "")
$ !	then
$ !	     goto quals$_loop
$ !     endif
$!
$	goto qual$ivqual_error
$!
$ params$end_loop:
$!
$	if f$type(options$_startmenu) .eqs. "" then $ options$_startmenu = ""
$	if f$type(options$_menuname)  .eqs. "" then $ options$_menuname  = ""
$	if f$type(options$_jumps)     .eqs. "" then $ options$_jumps     = ""
$	return
$!
$!******************************************************************************
$!
$!==>	If any errors in the parsing routine show up, they're handled here.
$!	This is kept apart since this is the very first beginning of the
$!	initialision process, in which most of the OMI symbols are set up.
$!
$ qual$abkeyw_error:
$!
$	_message = "ABKEYW, ambiguous qualifier or keyword - supply more characters"
$	goto qual$_error
$!
$ qual$ivqual_error:
$!
$	_message = "IVQUAL, unrecognized qualifier - check validity, spelling, and placement"
$	goto qual$_error
$!
$ qual$valreq_error:
$!
$	_message = "VALREQ, missing qualifier or keyword value - supply all required values"
$	goto qual$_error
$!
$ qual$ivkeyw_error:
$!
$	_message = "IVKEYW, unrecognized keyword - check validity and spelling
$	qual$_name = qual$_value ! Dirty....
$	goto qual$_error
$!
$ qual$notneg_error:
$!
$	_message = "NOTNEG, qualifier or keyword not negatable - remove 'NO' or omit value
$	qual$_name = "NO''qual$_name'"
$	goto qual$_error
$!
$ qual$ivbgrmod_error:
$!
$	_message = "IVBGRMOD, invalid background mode - specify BATCH or DETACH"
$	qual$_name = "''qual$_value'"
$	goto qual$_error
$!
$ qual$_error:
$!
$	write sys$error "%OMI-W-''_message'"
$	write sys$error " \''qual$_name'\"
$	goto main$_final_bye
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Setup the environment. This is done by calling the subprocedures
$!	that will setup all global symbols, define the menus and
$!	the screen layout, and define some internally used foreign
$!	commands. Symbols defined in this routine can be local, since
$!	this is the master procedure.
$!
$ main$_initialize:
$!
$	if f$trnlnm("Omi$") .eqs. ""
$	   then
$		_thisfile_location = -
		   f$parse(f$environment("procedure"),,,"device","no_conceal") + -
		   f$parse(f$environment("procedure"),,,"directory","no_conceal") - "]["
$		define /nolog Omi$ "''_thisfile_location'"
$	endif
$	omi$nodename = f$edit(f$getsyi("scsnode"),"collapse")
$	omi$current_user = f$edit(f$getjpi(0,"username"),"collapse")
$	omi$_ok        = %X1fff3001
$	omi$_cancelled = %X1fff30ad
$	omi$_warning   = %X1fff30af
$	omi$_error     = %X1fff30b5
$!
$	omi$_true      = %X1fff3007
$	omi$_false     = %X1fff3008
$!
$	ESC$[0,8]  = %X1b
$	BELL$[0,8] = %X7
$	LF$[0,8]   = %Xa
$	CR$[0,8]   = %Xd
$	FF$[0,8]   = %Xc
$	if .not. omi$_debug then -
	   $ set message /nofacility /noseverity /noidentification /notext
$	search Nla0: DummyStringToSetOmi$_NoMatch /output=Nla0:
$	omi$_nomatch   = $status
$	set message 'omi$_message
$!	omi$_nomatch   = %X08d78053
$	keyring$p$_key = " W"
$	keyring$p$_key[0,8] = %X1
$	perf$init_exit = 1
$!
$	@Omi$:Omi$Config Setup
$	if $status .eq. omi$_error then $ exit %X2c
$!
$	@Omi$:Omi$Screen Setup
$!
$	omi$config       := "@Omi$:Omi$Config Menu"
$	omi$screen       := "@Omi$:Omi$Screen"
$	omi$clear_screen := "@Omi$:Omi$Screen clear"
$	omi$refresh      := "@Omi$:Omi$Screen refresh"
$	omi$display_info := "@Omi$:Omi$Screen display_info"
$!
$	omi$keyselect_down := "@Omi$:Omi$Screen keyselect_down"
$	omi$keyselect_up   := "@Omi$:Omi$Screen keyselect_up"
$!
$	if omi$batch_mode
$	   then
$		omi$cmdline_clear   := "!"
$		omi$msgline_clear   := "!"
$		omi$display_message := "write sys$error"
$	   else
$		omi$cmdline_clear   := "write sys$output f$fao(""''screen$prompt_position'!''screen$line_length'* "")"
$		omi$msgline_clear   := @Omi$:Omi$Screen MsgLine_Clear
$		omi$display_message := @Omi$:Omi$Screen Display_Message
$	endif
$!
$	open /read /share=read /error=main$notoolbox_ini -
	   tb$init Omi$:Omi$ToolBox.Ini
$!
$ main$_init_toolbox:
$!
$	read /end_of_file=main$end_init_toolbox tb$init _tool
$	_tool = f$edit(_tool,"uncomment,collapse,upcase")
$	if _tool .eqs. "" then $ goto main$_init_toolbox
$	if _tool .eqs. "<EOF>" then $ goto main$end_init_toolbox
$	if f$extract(0,1,_tool) .eqs. "["
$	   then
$		toolbox = _tool - "[" - "]"
$		toolbox = f$parse(toolbox,"OMI$:",".COM")
$		goto main$_init_toolbox
$	endif
$	if toolbox .eqs. ""
$	   then
$		omi$signal omi toolerr
$		goto main$end_init_toolbox
$	endif
$	if .not. omi$_debug then -
	   $ set message /nofacility /noseverity /noidentification /notext
$	search 'toolbox' "''_tool'$:" /output=nla0:
$	if $status .eq. omi$_nomatch
$	   then
$		set message 'omi$_message
$		omi$signal omi noroutine,_tool
$		read /end_of_file=mit$_no_routine sys$command _dummy -
		   /prompt="''screen$prompt_position'''questions$wait_prompt' "
$		omi$msgline_clear
$		omi$cmdline_clear
$		omi$signal omi checktoolbox
$		read /end_of_file=mit$_no_routine sys$command _dummy -
		   /prompt="''screen$prompt_position'''questions$wait_prompt' "
$		goto mit$_no_routine
$	endif
$!
$	set message 'omi$_message
$	omi$'_tool' := "@''toolbox' ''_tool'"
$	goto main$_init_toolbox
$!
$ mit$_no_routine:
$!
$	ws ""
$	omi$msgline_clear
$	omi$cmdline_clear
$	goto main$_init_toolbox
$!
$ main$end_init_toolbox:
$!
$	close tb$init
$!
$! Define the valid internal commands
$! The boolean following the command indicated wether or not this command
$! is available in Otf- menus
$!
$	omi$valid_commands = -
	   "#ADD,0#ALL,1#BACK,1#CALC,1#CLS,1#DCL,1#DELETE,1#EDIT,1#ENCRYPT,0#" + -
	   "EXIT,0#EXPORT,1#HELP,1#IMPORT,1#INCREASE,1#INFO,1#JUMP,0#" + -
	   "MAIN,0#MANAGE,0#MENU,0#MODIFY,0#QUIT,0#REFRESH,1#RENAME,0#" + -
	   "REMOVE,0#RESET,1#SET,1#SILENT_DCL,1#SHOW,1#SPAWN,1#SUBMIT,1#"
$!
$	return omi$_ok
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Find out if any default values where defined for input items. If so,
$!	set them.
$!	This has to be done in this procedure, since the symbols have to
$!	be local.
$!
$ main$default_values:
$!
$	if f$type(symbol_name) .eqs. ""
$	   then $ symbol_name = "input"
$	   else
$		if symbol_name .eqs. "input"
$		   then
$			symbol_name = "const"
$			init_def$search_string = "$const"
$		   else
$			delete\ /symbol /local symbol_name
$			return omi$_ok
$		endif
$	endif
$	assign sys$scratch:omi$setup_defaults._tmp1$ sys$output
$	assign /user nla0: sys$error
$	show symbol /global *$'symbol_name'*
$	deassign sys$output
$	search sys$scratch:omi$setup_defaults._tmp1$ 'init_def$search_string -
	   /output=sys$scratch:omi$setup_defaults._tmp$ /nowarnings
$	if $status .eq. omi$_nomatch
$	   then
$		delete\ /nolog /noconfirm sys$scratch:omi$setup_defaults._tmp1$;
$		delete\ /nolog /noconfirm sys$scratch:omi$setup_defaults._tmp$;
$		goto main$default_values
$	endif
$	delete\ /nolog /noconfirm sys$scratch:omi$setup_defaults._tmp1$;
$	open /read omi$setup_defaults sys$scratch:omi$setup_defaults._tmp$
$!
$ init$_defaults:
$!
$	read /end_of_file=init$end_defaults omi$setup_defaults omi$value
$!
$	if f$extract(0, 1, f$element(1,"#",omi$value)) .eqs. "{"
$	   then $ _varname = "''f$extract(f$locate("}",f$element(1,"#",omi$value))+1, f$length(f$element(1,"#",omi$value)), f$element(1,"#",omi$value))'"
$	   else $ _varname = "''f$element(1, "#", omi$value)'"
$	endif
$!
$	if f$element(2, "#", f$extract(0,f$length(omi$value)-1,omi$value)) -
	   .eqs. "#" .or. f$element(2, "#", f$extract(0,f$length(omi$value)-1,-
	   omi$value)) .eqs. ""
$	   then
$		if f$type (varreset$) .nes. ""
$		   then
$			_varname = _varname - """
$			varreset$ = varreset$ + 1
$			set message /nofacility /noseverity /noidentification /notext
$			if f$type ('_varname') .nes. "" then -
			   $ delete\ /symbol /local '_varname'
$			set message 'omi$_message
$		endif
$		goto init$_defaults
$	endif
$!
$	default_value = f$element(2, "#", omi$value) - """
$!
$	if f$edit(f$extract(0, 5, default_value),"upcase") .eqs. "CALL:"
$	   then
$		_def_module = f$extract(5, f$length(f$element(0," ", default_value))-5, default_value)
$		_params = f$extract(5+f$length(_def_module)+1,f$length(default_value)-(5+f$length(_def_module)+1),default_value)
$		omi$call '_def_module' '_varname' '_params'
$		default_value = OMI$DEFAULT_VALUE
$		delete\ /symbol /global OMI$DEFAULT_VALUE
$		_translate_from_block = 0
$	   else
$		_translate_from_block = 1
$	endif
$!
$	if f$extract(0, 1, f$element(1,"#",omi$value)) .eqs. "{" .and. f$edit(f$element(0,"}",f$element(1,"#",omi$value)),"upcase") .nes. "{HIDDEN"
$	   then
$		_block = f$extract(1, f$locate("}", f$element(1,"#",omi$value))-1, f$element(1,"#", omi$value))
$		_block = f$edit(_block,"upcase") - "SEL|"
$!
$		if f$type (varreset$) .nes. ""
$		   then
$			varreset$ = varreset$ + 1
$			set message /nofacility /noseverity /noidentification /notext
$			if f$type('_varname') .nes. "" then -
			   $ delete\ /symbol /local '_varname'  ! RESET VARIABLES
$			set message 'omi$_message
$		endif
$!
$		if _translate_from_block .eq. 1
$		   then
$			if f$type('_block'$filename) .nes. ""
$			   then
$				_blockname = _block
$				gosub input$_from_file
$				_status = $status
$				if _status .ne. omi$_ok then $ omi$wait
$			   else $ _status = omi$_ok
$			endif
$!
$			if f$extract(0,4,_block) .nes. "TAG|" .and. _status .eq. omi$_ok
$			   then
$!				When the actual value is given i.s.o. "VALUEn", this signals the warning:
$!				%DCL-W-UNDSYM, undefined symbol - check validity and spelling
$!				 \<blockname>$<actual_value>\
$!				so we need to check if the value == "VALUE<int>"
$!				NOTE: This will fail if the SELECT/TAGlist contains something
$!				      like:
$!				  VALUE1  = VALUE2
$!				But then.... 
$				value_pointer = f$edit(f$element(2,"#",omi$value),"upcase") - """
$				vcount_pointer = f$extract(5,f$length(value_pointer)-5,value_pointer)
$				if f$extract(0,5,value_pointer) .eqs. "VALUE" .and. -
				    f$type(vcount_pointer) .eqs. "INTEGER"
$				    then $ '_varname' = '_block'$'value_pointer'
$				    else $ '_varname' = value_pointer
$				endif
$			endif
$		   else
$			'_varname' = default_value
$		endif
$	   else
$		_default_value = f$element(2, "#", omi$value) - """
$		_variable = "default_value"
$		_format = f$element(3, "#",omi$value) - """
$!
$		if f$type (varreset$) .nes. ""
$		   then
$			varreset$ = varreset$ + 1
$			set message /nofacility /noseverity /noidentification /notext
$			if f$type('_varname') .nes. "" then -
			   $ delete\ /symbol /local '_varname'  ! RESET VARIABLES
$			set message 'omi$_message
$		endif
$!
$		if _format .nes. "" .and. _format .nes. "#" .and. '_variable' .nes. ""
$		   then
$			gosub input$_format
$			if $status .eq. omi$_warning
$			   then $ '_varname' = "Invalid default value"
$			   else $ '_varname' = '_variable'
$			endif
$		   else $ '_varname' = '_variable'
$		endif
$	endif
$	goto init$_defaults
$!
$ init$end_defaults:
$!
$	close omi$setup_defaults
$	delete/noconfirm/nolog sys$scratch:omi$setup_defaults._tmp$;
$	goto main$default_values
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Delete all symbols and all logicals that were set by this procedure,
$!	erase the screen (if not called from an error routine), and restore
$!	all original settings.
$!
$ main$_cleanup:
$!
$	@Omi$:Omi$Screen Cleanup "''omi$_cls'"
$	if omi$_cls .nes. "NOCLS" then $ delete\ /symbol /local omi$display_message
$!	if .not. omi$batch_mode then $ recall /input=sys$scratch:omi$saved_recall_buffer._tmp$
$	ws "%OMI-I-REMFILES, removing temporary files..."
$!
$	if f$trnlnm("calc$_subresults") .nes. "" then $ close calc$_subresults
$	if f$search("sys$scratch:calc$_subresults._tmp$") .nes. "" then -
	   $ delete\ /nolog /noconfirm sys$scratch:calc$_subresults._tmp$;*
$	if f$search("sys$scratch:omi$check_otf_menu._tmp$") .nes. "" then -
	   $ delete\ /nolog /noconfirm sys$scratch:omi$check_otf_menu._tmp$;*
$	if f$search("sys$scratch:omi$import_key._tmp$") .nes. "" then -
	   $ delete\ /nolog /noconfirm sys$scratch:omi$import_key._tmp$;*
$	if f$search("Sys$Scratch:Omi$NewCfg._Tmp$") .nes. "" then -
	   $ delete\ /nolog /noconfirm Sys$Scratch:Omi$NewCfg._Tmp$;*
$	if f$search("sys$scratch:omi$saved_recall_buffer._tmp$") .nes. "" then -
	   $ delete\/nolog/noconfirm sys$scratch:omi$saved_recall_buffer._tmp$;*
$	if f$type(ta$remove_files) .eqs. "" then $ goto cleanup$clearmem
$	_ta_counter = 0
$!
$ cleanup$delfiles:
$!
$	_ta_file = f$element(_ta_counter, ",", ta$remove_files)
$	if _ta_file .eqs. "" .or. _ta_file .eqs. "," then $ goto cleanup$clearmem
$	_ta_file = f$search(_ta_file)
$	if _ta_file .nes. "" then $ delete/nolog /noconfirm '_ta_file'
$	_ta_counter = _ta_counter + 1
$	goto cleanup$delfiles
$!
$ cleanup$clearmem:
$!
$	ws "%OMI-I-CLEARMEM, clearing memory..."
$	@Omi$:Omi$ToolBox Cleanup
$	if f$type(omi$menu_file) .nes. "" then $ omi$config "''omi$menu_file'" Cleanup
$	@Omi$:Omi$Config Setup "" Cleanup
$	if f$type(omi$inputs) .nes. "" then $ gosub cleanup$missing_items
$	if f$type(_thisfile_location) .nes. "" then $ deassign Omi$
$!
$	return omi$_ok
$!
$ cleanup$missing_items:
$!
$	if .not. omi$inputs
$	   then
$		delete\/symbol/global omi$inputs
$		return omi$_ok
$	endif
$	assign sys$scratch:omi$symbol_cleanup._tmp$ sys$output
$	define sys$error nla0: ! Added by Edward Vlak
$	show symbol /global *$item*
$	deassign sys$output
$	deassign sys$error
$	open /read omi$symbol_cleanup sys$scratch:omi$symbol_cleanup._tmp$
$!
$ cleanup$_symbols:
$!
$	read /end_of_file=cleanup$end_symbols omi$symbol_cleanup omi$symbol
$	if f$locate("command#all", f$edit(omi$symbol,"lowercase")) .lt. -
	   f$length(omi$symbol) then $ delete\/symbol/global -
	   'f$element(0, "=", f$edit(omi$symbol,"collapse"))
$	goto cleanup$_symbols
$!
$ cleanup$end_symbols:
$!
$	close omi$symbol_cleanup
$	delete/noconfirm/nolog sys$scratch:omi$symbol_cleanup._tmp$;
$	delete\/symbol/global omi$inputs
$	return omi$_ok
$!
$!******************************************************************************
