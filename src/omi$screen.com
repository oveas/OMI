$	goto start$
$!
$!******************************************************************************
$!*                                                                            *
$!*    MODULE NAME:                                                            *
$!*    ============                                                            *
$!*      Omi$Screen.Com                                                        *
$!*                                                                            *
$!*    CALLED BY:                                                              *
$!*    ==========                                                              *
$!*      Omi$Menu.Com                                                          *
$!*                                                                            *
$!*    DESCRIPTION:                                                            *
$!*    ============                                                            *
$!*      This module handles all terminal I/O.                                 *
$!*                                                                            *
$!******************************************************************************

$!******************************************************************************
$!
$ start$:
$!
$!==>	Evaluate the parameter.
$!
$	if f$type(menu$title) .eqs. "" then -
	   $ menu$title = "Oscar's Menu Interpreter v''omi$version' - (c)1997-2019, Oveas"
$!
$	if p1 .eqs. "CLEANUP"      then $ gosub screen$_erase
$	if p1 .eqs. "CLEAR"        then $ gosub screen$erase_window
$	if p1 .eqs. "SETUP"
$	   then
$		gosub screen$_values
$		if .not. omi$batch_mode then $ gosub screen$_initialize
$	endif
$!
$	if p1 .eqs. "DISPLAY_INFO"   then $ gosub screen$display_information
$	if p1 .eqs. "DYNAMIC_MENU"   then $ gosub screen$setup_dynamic_menu
$	if p1 .eqs. "MENU"           then $ gosub screen$setup_window
$	if p1 .eqs. "SELECT_LIST"    then $ gosub screen$setup_select_list
$	if p1 .eqs. "TAGLIST"        then $ gosub screen$setup_tag_list
$	if p1 .eqs. "KEYSELECT_DOWN" then $ gosub screen$keyselect_down
$	if p1 .eqs. "KEYSELECT_UP"   then $ gosub screen$keyselect_up
$!
$	if omi$batch_mode then $ goto screen$_exit
$!
$	if p1 .eqs. "REFRESH"
$	   then
$		gosub screen$_initialize 
$		gosub screen$setup_window
$	endif
$	if p1 .eqs. "SETUP_SCROLL_REGION"
$	   then
$		gosub screen$erase_window
$		_top = screen$line_header + 1 + screen$window_topmargin
$		_size = screen$height + 1 - (screen$height - screen$line_command)  - _top
$		ws "''ESC$'[''_top';''_size'r"
$	endif
$	if p1 .eqs. "ERASE_SCROLL_REGION"
$	   then
$		ws "''ESC$'[1;''screen$height'r"
$		gosub screen$_initialize
$		gosub screen$setup_window
$	endif
$!
$ screen$_exit:
$!
$	exit omi$_ok
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Write all menu items to the screen
$!
$ screen$setup_window:
$!
$	gosub screen$erase_window
$	_menu = "''omi$current_menu'"
$	if f$type('_menu'$title') .nes. ""
$	   then
$		_menu_title = '_menu'$title
$		_menu_title_loc = (screen$menu_width / 2) - -
		   (f$length(_menu_title) / 2) + screen$width_margin
$		ws f$fao("''ESC$'[''screen$line_header';''screen$width_margin'H''ESC$'[7m!''screen$menu_width'* ''ESC$'[0m")
$		ws "''ESC$'[''screen$line_header';''_menu_title_loc'H''ESC$'[7m''_menu_title'''ESC$'[0m"
$	endif
$!
$	if f$type('_menu'$comment) .nes. ""
$	   then $ gosub screen$comment_line
$	   else $ _comment_counter = 0
$	endif
$	_item_cnt = 1
$!
$ setup$_items:
$!
$	if f$type('_menu'$item'_item_cnt') .eqs. "" then $ goto screen$_input
$	_item = f$element(0, "#", '_menu'$item'_item_cnt')
$	if f$edit(f$element(1, "#", '_menu'$item'_item_cnt'),"upcase") -
	   .eqs. "SUBMENU" .and. screen$display_names
$	   then
$		_submnu = f$element(2, "#", '_menu'$item'_item_cnt')
$		if f$type('_submnu'$name) .nes. ""
$		   then
$			_item = "''_item' (" + '_submnu'$name + ")"
$		   else $ _item = _item +  " (no name)"
$		endif
$	endif
$	_line = screen$line_header + _item_cnt + screen$window_topmargin + _comment_counter
$!	if (_line + 1) .eq. screen$line_command then $ goto setup$_overflow
$	if _line .eq. screen$line_command then $ goto setup$_overflow
$	_blank = ""
$	if _item_cnt .lt. 10 then $ _blank = " "
$	ws "''ESC$'[''_line';''screen$default_position'H''ESC$'[1m''_blank'''_item_cnt'>''ESC$'[0m ''_item'"
$	_item_cnt = _item_cnt + 1
$	goto setup$_items
$!
$ screen$comment_line:
$!
$	_line = screen$line_header + screen$window_topmargin + 1
$	_comment = '_menu'$comment
$!
$ comment$substitute:
$!
$	if f$locate("{",_comment) .eq. f$length(_comment)
$	   then
$		ws "''ESC$'[''_line';''screen$default_position'H''_comment'"
$		_comment_counter = 2
$		return
$	endif
$!
$	_comment1 = f$extract(0, f$locate("{",_comment), _comment)
$	_comment = _comment - _comment1
$	_comment_var = f$extract(0, f$locate("}",_comment) + 1, _comment)
$	_comment = _comment - _comment_var
$	_comment_var = _comment_var - "{" - "}"
$!
$	if f$type('_comment_var) .eqs. ""
$	   then $ _comment = "''_comment1'***''_comment'"
$	   else
$		_comment_val = '_comment_var
$		_comment = "''_comment1'''_comment_val'''_comment'"
$	endif
$	goto comment$substitute
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	If this menu screen can also read inputs, they are written to the
$!	screen in this routine. The layout is separated by a horizonal line,
$!	and the choices are displayed just like the menu items.
$!
$ screen$_input:
$!
$	inputs$highest_item == _item_cnt - 1
$	_input_cnt = 1
$	if f$type('_menu'$input'_input_cnt') .eqs. "" then $ return
$!
$	if f$type('_menu'$all_inputs) .nes. ""
$	   then
$		if '_menu'$all_inputs
$		   then $ omi$inputs == 1
$		   else $ omi$inputs == 0
$		endif
$	   else $ omi$inputs == 1
$	endif
$	_line = _line + 1
$!	if (_line + 1) .eq. screen$line_command then $ goto setup$_overflow
$	if _line .eq. screen$line_command then $ goto setup$_overflow
$!	_size_separator = screen$width - (2 * screen$width_margin) - 3
$	_size_separator = screen$line_length - 2
$!
$	_position = ((screen$width / 2) - 3)
$	_longest_record = f$length(questions$all_inputs)
$!
$	if f$type(screen$separate_inputs) .nes. ""
$	   then
$		if (screen$separate_inputs)
$		   then
$			ws f$fao("''ESC$'[''_line';''screen$default_position'H''ESC$'(0!''_size_separator'*q''ESC$'(B")
$			_line = _line + 1
$!			if (_line + 1) .eq. screen$line_command then $ goto setup$_overflow
$			if _line .eq. screen$line_command then $ goto setup$_overflow
$			ws "''ESC$'[''_line';''_position'H''ESC$'[1;4mInputs''ESC$'[0m"
$			_line = _line + 1
$!			if (_line + 1) .eq. screen$line_command then $ goto setup$_overflow
$			if _line .eq. screen$line_command then $ goto setup$_overflow
$			inputs$first_line == _line
$		   else $ inputs$first_line == _line
$		endif
$	   else $ inputs$first_line == _line
$	endif
$!
$ screen$_inputs:
$!
$	_choice = _input_cnt + _item_cnt - 1
$	_input = f$element(0, "#", '_menu'$input'_input_cnt')
$	_blank = ""
$	if _choice .lt. 10 then $ _blank = " "
$	ws "''ESC$'[''_line';''screen$default_position'H''ESC$'[1m''_blank'''_choice'>''ESC$'[0m ''_input'"
$	if f$length(_input) .gt. _longest_record then -
	   $ _longest_record = f$length(_input)
$	_input_cnt = _input_cnt + 1
$	if f$type('_menu'$input'_input_cnt') .eqs. "" then $ goto screen$end_inputs
$	_line = _line + 1
$!	if (_line + 1) .eq. screen$line_command then $ goto setup$_overflow
$	if _line .eq. screen$line_command then $ goto setup$_overflow
$	goto screen$_inputs
$!
$ screen$end_inputs:
$!
$	inputs$last_line == _line
$	inputs$value_location == -
	   screen$default_position + _longest_record + screen$tab
$      	inputs$max_size == -
	   (screen$width - screen$width_margin) - inputs$value_location - 1
$	_line = _line + 1
$!	if (_line + 1) .eq. screen$line_command then $ goto setup$_overflow
$	if _line .eq. screen$line_command then $ goto setup$_overflow
$	_choice = _choice + 1
$	_item_cnt = _choice
$	if f$type('omi$current_menu'$all_inputs) .eqs. ""
$	   then $ _display_allinp_prompt = 1
$	   else $ _display_allinp_prompt = 'omi$current_menu'$all_inputs
$	endif
$	if f$type('omi$current_menu'$required_order) .nes. "" then -
	   $ _display_allinp_prompt = 0
$	if _display_allinp_prompt
$	   then
$		'_menu'$item'_item_cnt' == "''questions$all_inputs'#command#all"
$		_blank = ""
$		if _choice .lt. 10 then $ _blank = " "
$		ws "''ESC$'[''_line';''screen$default_position'H''ESC$'[1m''_blank'''_choice'>''ESC$'[0m ''questions$all_inputs'"
$	endif
$!
$	_line = inputs$first_line
$!
$ screen$value_column:
$!
$	_input = _line - inputs$first_line + 1
$	_variable = f$element(1, "#", '_menu'$input'_input')
$!
$	if f$extract(0,8,f$edit(_variable,"upcase")) .eqs. "{HIDDEN}"
$	   then
$		_variable = f$extract(8, f$length(_variable)-8, _variable)
$		_hidden = 1
$	   else $ _hidden = 0
$	endif
$!
$	if f$extract(0, 1, _variable) .eqs. "{"
$	   then
$		_select_list = f$extract(0, f$locate("}", _variable) + 1, _variable)
$		_variable = _variable - _select_list
$		_select_list = _select_list - "{" - "}"
$	endif
$!
$	if f$type('_variable') .eqs. ""
$	   then
$		if f$element(2, "#", '_menu'$input'_input') .eqs. "#" .or. -
		   f$element(2, "#", '_menu'$input'_input') .eqs. ""
$		   then $ _value = main$empty_value
$		   else $ _value = f$element(2, "#", '_menu'$input'_input')
$		endif
$	   else
$		if '_variable' .eqs. ""
$		   then $ _value = main$empty_value
$		   else $ _value = '_variable'
$		endif
$	endif
$!
$	if _hidden .and. _value .nes. main$empty_value
$	   then
$		_astrlen = f$length(_value)
$		_display_value = f$fao("!''_astrlen'**")
$	   else $ _display_value = _value
$	endif
$!
$	if f$locate("''CR$'", _display_value) .lt. f$length(_display_value) then -
	   $ _display_value = f$extract(0, f$locate("''CR$'", _display_value), -
	   _display_value) + "''ESC$'(0d''ESC$'(B"
$	_blanks = inputs$max_size - f$length(_display_value) + 1
$	if f$length(_display_value) .le. inputs$max_size
$	   then $ ws "''ESC$'[''_line';''inputs$value_location'H''_display_value'"
$	   else $ ws "''ESC$'[''_line';''inputs$value_location'H''f$extract(0,inputs$max_size,_display_value)'''ESC$'(0`''ESC$'(B"
$	endif
$	_line = _line + 1
$	if _line .le. inputs$last_line then $ goto screen$value_column
$	return
$!
$ setup$_overflow:
$!
$	omi$signal omi scroverfl
$	exit omi$_error
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Create a small window with all possible options of the current
$!	selection list
$!
$ screen$setup_select_list:
$!
$	if f$type(list$_scroll) .nes. ""
$	   then
$		if list$_scroll .eqs. "NEXT" .and. -
		   f$type(scroll$next_page) .eqs. ""
$			then
$				omi$signal omi last
$				exit omi$_warning
$		endif
$!
$		if list$_scroll .eqs. "PREVIOUS" .and. -
		   f$type(scroll$previous_page) .eqs. ""
$			then
$				omi$signal omi first
$				exit omi$_warning
$		endif
$		scroll$_start_at = scroll$'list$_scroll'_page
$	endif
$	if f$type(scroll$next_page) .nes. "" then -
	   $ delete\/symbol/global scroll$next_page
$	if f$type(scroll$previous_page) .nes. "" then -
	   $ delete\/symbol/global scroll$previous_page
$!
$	_sel_opt = 1
$	_sel_size = 0
$	_subwin_pos = screen$default_position + 2
$	_available_lines = screen$line_command - (screen$line_header + -
	   screen$window_topmargin) - 4
$!
$ sellst$_find_longest:
$!
$	if f$type('_select_list'$value'_sel_opt') .eqs. "" then $ goto sellst$end_find_longest
$	if f$length(('_select_list'$value'_sel_opt' - "{" - "}")) .gt. _sel_size then -
	   $ _sel_size = f$length(('_select_list'$value'_sel_opt' - "{" - "}"))
$	_sel_opt = _sel_opt + 1
$	goto sellst$_find_longest
$!
$ sellst$end_find_longest:
$!
$	_columns = ((_sel_opt - 2) / _available_lines) + 1
$	if f$type(scroll$_start_at) .eqs. ""
$	   then $ _sel_opt = 1
$	   else $ _sel_opt = scroll$_start_at
$	endif
$	scroll$this_page == _sel_opt
$	_sel_size = _sel_size + 4
$	_longest = _sel_size
$	_sel_size = _sel_size + 6
$	if _columns .ne. 1 then $ _sel_size = ((_columns * _sel_size) + -
	   ((_columns - 1) * screen$tab)) - 6
$	_sel_loc = _subwin_pos + 2
$	if (_sel_size + _sel_loc) .ge. (screen$line_length + -
	   screen$default_position) then $ _sel_size = screen$line_length - -
	   (_sel_loc - screen$default_position) 
$	_line = screen$line_header + screen$window_topmargin + 1
$!	_first_line = _line
$	ws f$fao("''ESC$'[''_line';''_subwin_pos'H''ESC$'(0l!''_sel_size'*qk''ESC$'(B")
$	_cur_col = 1
$!
$ sellst$_setup:
$!
$	if f$type('_select_list'$value'_sel_opt') .eqs. "" then $ goto sellst$end_setup
$	_this_col = _sel_loc + ((_cur_col - 1) * (screen$tab + _longest))
$	_line = (screen$line_header + screen$window_topmargin + (_sel_opt - -
	   scroll$this_page + 1)) - ((_cur_col - 1) * _available_lines) + 1
$	if _cur_col .eq. 1 then -
	   $ ws f$fao("''ESC$'[''_line';''_subwin_pos'H''ESC$'(0x''ESC$'(B!''_sel_size'* ''ESC$'(0x''ESC$'(B")
$	if _sel_opt .lt. 10
$	   then $ _blank = " "
$	   else $ _blank = ""
$	endif
$	_to_screen = '_select_list'$value'_sel_opt'
$	if f$extract(0,1,_to_screen) .eqs. "{" then -
	   $ _to_screen = _to_screen - "{" - "}"
$	if f$type('_variable') .eqs. ""
$	   then $ ws "''ESC$'[''_line';''_this_col'H''ESC$'[1m''_blank'''_sel_opt'>''ESC$'[0m ''_to_screen'"
$	   else
$		if '_variable' .eqs. '_select_list'$value'_sel_opt' .and. _all_inputs
$		   then $ ws "''ESC$'[''_line';''_this_col'H''ESC$'[1m''_sel_opt'>''ESC$'[0m ''ESC$'[7m''_to_screen'''ESC$'[0m"
$		   else $ ws "''ESC$'[''_line';''_this_col'H''ESC$'[1m''_sel_opt'>''ESC$'[0m ''_to_screen'"
$		endif
$	endif
$	_sel_opt = _sel_opt + 1
$	if (_line + 3) .eq. screen$line_command
$	   then
$		if _cur_col .eq. 1
$		   then
$			_line = _line + 1
$			__closing_line_written__ = 1
$			_line_size = _sel_size
$			_check_next = _sel_opt + 1
$ 			if f$type('_select_list'$value'_sel_opt') .eqs. ""
$			   then $ _show_next = ""
$			   else
$				_line_size = _line_size - 6
$				_show_next = "''ESC$'(B''ESC$'[1mN''ESC$'[0mext>''ESC$'(0q"
$			endif
$			if scroll$this_page .eq. 1
$			   then $ _show_prev = ""
$			   else
$				_line_size = _line_size - 10
$				_show_prev = "q''ESC$'(B<''ESC$'[1mP''ESC$'[0mrevious''ESC$'(0"
$			endif
$			ws f$fao("''ESC$'[''_line';''_subwin_pos'H''ESC$'(0m''_show_prev'!''_line_size'*q''_show_next'j''ESC$'(B")
$		endif
$		_cur_col = _cur_col + 1
$		if (_sel_loc + ((_cur_col - 1) * (screen$tab + _longest)) + -
		   _longest) .ge. (_sel_size + _subwin_pos )
$		   then
$			_cur_col = _cur_col - 1
$			if f$type('_select_list'$value'_sel_opt') .nes. "" -
			   then $ scroll$next_page == _sel_opt
$			goto sellst$end_setup
$		endif
$	endif
$	goto sellst$_setup
$!
$ sellst$end_setup:
$!
$	if f$type(scroll$max_on_page) .eqs. "" .and. -
	   f$type(scroll$next_page) .nes. "" then -
	   $ scroll$max_on_page == _sel_opt - scroll$this_page
$	if scroll$this_page .ne. 1 then $ scroll$previous_page == -
	   scroll$this_page - scroll$max_on_page
$	if _cur_col .eq. 1 .and. f$type(__closing_line_written__) .eqs. ""
$	   then
$		_line = _line + 1
$		_line_size = _sel_size
$		if f$type (scroll$next_page) .eqs. ""
$		   then $ _show_next = ""
$		   else
$			_line_size = _line_size - 6
$			_show_next = "''ESC$'(B''ESC$[1mN''ESC$'[0mext>''ESC$'(0q"
$		endif
$		if f$type (scroll$previous_page) .eqs. ""
$		   then $ _show_prev = ""
$		   else
$			_line_size = _line_size - 10
$			_show_prev = "q''ESC$'(B<''ESC$'[1mP''ESC$'[0mrevious''ESC$'(0"
$		endif
$!
$	 sellst$fill_subwin:
$!
$		if (_line + 3) .le. screen$line_command .and. -
		   f$type (scroll$previous_page) .nes. ""
$		   then
$			ws f$fao("''ESC$'[''_line';''_subwin_pos'H''ESC$'(0x!''_sel_size'* x''ESC$'(B")
$			_line = _line + 1
$			goto sellst$fill_subwin
$		endif
$		ws f$fao("''ESC$'[''_line';''_subwin_pos'H''ESC$'(0m''_show_prev'!''_line_size'*q''_show_next'j''ESC$'(B")
$	endif
$	return
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Create a small window with all possible options when a dynamic menu
$!	has been selected
$!
$ screen$setup_dynamic_menu:
$!
$	_mnu_opt = 1
$	_mnu_size = 0
$!
$ dynmnu$_find_longest:
$!
$	if f$type(_dynmenu'_mnu_opt') .eqs. "" then $ goto dynmnu$end_find_longest
$	if f$length(f$element(0, "|", _dynmenu'_mnu_opt')) .gt. _mnu_size then -
 	   $ _mnu_size = f$length(f$element(0, "|", _dynmenu'_mnu_opt'))
$	_mnu_opt = _mnu_opt + 1
$	goto dynmnu$_find_longest
$!
$ dynmnu$end_find_longest:
$!
$	_mnu_size = _mnu_size + 4
$	_mnu_loc = screen$default_position + 2
$	_mnu_line = (screen$height - screen$height_margin - -
	   screen$window_topmargin - _mnu_opt) / 2
$	_mnu_opt = 1
$	ws f$fao("''ESC$'[''_mnu_line';''_mnu_loc'H''ESC$'(0l!''_mnu_size'*qqqk''ESC$'(B")
$	_mnuopt_loc = _mnu_loc + 2
$!
$ dynmnu$_setup:
$!
$	if f$type(_dynmenu'_mnu_opt') .eqs. "" then $ goto dynmnu$end_setup
$	_line = _mnu_line + _mnu_opt
$	ws f$fao("''ESC$'[''_line';''_mnu_loc'H''ESC$'(0x''ESC$'(B!''_mnu_size'*   ''ESC$'(0x''ESC$'(B")
$	ws "''ESC$'[''_line';''_mnuopt_loc'H''ESC$'[1m''_mnu_opt'>''ESC$'[0m ", f$element(0, "|", _dynmenu'_mnu_opt')
$	_mnu_opt = _mnu_opt + 1
$	goto dynmnu$_setup
$!
$ dynmnu$end_setup:
$!
$	_line = _line + 1
$	ws f$fao("''ESC$'[''_line';''_mnu_loc'H''ESC$'(0m!''_mnu_size'*qqqj''ESC$'(B")
$	return
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>
$!
$ screen$setup_tag_list:
$!
$	_longest_record = 0
$	_position = screen$default_position
$	_tag_msg = 0
$	if p2 .eqs. ""
$	   then
$		gosub screen$erase_window
$		_tag_cnt = 1
$	   else $ _tag_cnt = 1
$!	   else $ _tag_cnt = f$integer(p2)
$	endif
$	if f$type('_tagblock'$message) .nes. ""
$	   then
$		_line = screen$line_header + screen$window_topmargin
$		ws "''ESC$'[''_line';''_position'H''ESC$'[1m",'_tagblock'$message,"''ESC$'[0m"
$		_tag_msg = 2
$	endif
$	_line = screen$line_header + screen$window_topmargin + _tag_msg
$	_back_up = 0
$!
$ screen$_tag_list:
$!
$	_line = _line + 1
$	if (_line + 2) .gt. screen$line_command
$	   then
$		_line = _line - _back_up
$		_back_up = 0
$		_position = _position + screen$tab + _longest_record + 4
$		_longest_record = 0
$	endif
$	_back_up = _back_up + 1
$	_blank = ""
$	if _tag_cnt .lt. 10 then $ _blank = " "
$	_tag_value = '_tagblock'$value'_tag_cnt' 
$	if f$length(_tag_value) .gt. _longest_record then -
	   $ _longest_record = f$length(_tag_value)
$!
$	if p2 .eqs. "" .or. _tag_cnt .eq. p2
$	   then
$		if (f$length("''_blank'''_tag_cnt'> ''_tag_value'") + -
		   _position) .gt. (screen$default_position + screen$line_length)
$		   then
$			omi$signal omi overflow
$			exit omi$_error
$		endif
$		if f$locate("''_tagdelim'''_tag_value'''_tagdelim'",'_taglist') .lt. -
		   f$length('_taglist') .or. (f$length('_taglist') .ne. 0 -
		   .and. f$locate("''_tag_value'''_tagdelim'",'_taglist') .eq. 0)
$		   then $ ws "''ESC$'[''_line';''_position'H''ESC$'[1m''_blank'''_tag_cnt'>''ESC$'[0m ''ESC$'[7m''_tag_value'''ESC$'[0m"
$		   else $ ws "''ESC$'[''_line';''_position'H''ESC$'[1m''_blank'''_tag_cnt'>''ESC$'[0m ''_tag_value'"
$		endif
$	endif
$	_tag_cnt = _tag_cnt + 1
$!
$	if f$type('_tagblock'$value'_tag_cnt') .eqs. ""
$	   then
$		_line = _line + 1
$		if (_line + 2) .gt. screen$line_command
$		   then
$			_position = _position + screen$tab + _longest_record + 4
$			_line = _line - _back_up
$		endif
$		if (f$length("''_blank'''_tag_cnt'> ''questions$reverse_tags'") + -
		   _position) .gt. (screen$default_position + screen$line_length)
$		   then
$			omi$signal omi overflow
$			exit omi$_error
$		endif
$		ws "''ESC$'[''_line';''_position'H''ESC$'[1m''_blank'''_tag_cnt'>''ESC$'[0m ''questions$reverse_tags'"
$		return
$	endif
$	goto screen$_tag_list
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Display a list of information records (no options) in the window.
$!	The records are presented as 'omi$record1, omi$record2 ....'
$!
$ screen$display_information:
$!
$	gosub screen$erase_window
$	_record_cnt = 1
$!
$ displ_info$records:
$!
$	if f$type(omi$record'_record_cnt') .eqs. "" then $ return
$	if omi$record'_record_cnt' .eqs. "" then $ return
$!
$	_line = screen$line_header + _record_cnt + screen$window_topmargin
$	_record = omi$record'_record_cnt'
$	ws "''ESC$'[''_line';''screen$default_position'H",_record
$	omi$record'_record_cnt' = ""
$	_record_cnt = _record_cnt + 1
$	goto displ_info$records
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Clear the window in which all output and menu items are displayed
$!
$ screen$erase_window:
$!
$	_line = screen$line_header + 1
$!
$ line$_clear:
$!
$	ws f$fao("''ESC$'[''_line';''screen$default_position'H!''screen$line_length'* ")
$	_line = _line + 1
$	if _line .lt. (screen$line_command - 1) then $ goto line$_clear
$	_linelength = screen$menu_width - 1
$!
$	return
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Calculate the values for all variables used in this procedure.
$!	The values are stores a globals, so they don't have to be recalculated
$!	each time this procedure is called.
$!
$ screen$_values:
$!
$	if .not. screen$width_inquired
$	   then
$		if screen$width .gt. 80
$		   then $ screen$width == 132
$		   else $ screen$width == 80
$		endif
$	endif
$	_screenheight = screen$height - screen$height_margin 
$!
$	screen$menu_width   == screen$width - (2 * screen$width_margin)
$	screen$line_length  == screen$menu_width - 2
$	screen$line_command == _screenheight - 2
$	screen$line_message == _screenheight
$	screen$line_header  == screen$height_margin
$	screen$default_position == screen$width_margin + 2
$	screen$prompt_position ==  "''ESC$'[''screen$line_command';''screen$default_position'H"
$	if (f$extract(0,1,f$edit(screen$scrollregion_autodisable,"upcase")) -
	   .eqs. "Y" .or. screen$scrollregion_autodisable .eq. 1) -
	   .and. screen$width_margin .ne. 0 then -
	   $ screen$scroll_region == "disabled"
$!
$	return
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	This routine writes all lines to the screen, thus creating the main
$!	window, as specified in the configuration files. The window will later
$!	on be filled with the per-menu items.
$!
$ screen$_initialize:
$!
$	screen$terminal_app_mode == f$getdvi("tt:", "tt_app_keypad")
$!	if .not. screen$terminal_app_mode then $ set terminal /application_keypad
$!
$!	define\/key/echo/nolog/terminate kp2 "omikey_down"
$!	define\/key/echo/nolog/terminate kp8 "omikey_up"
$!
$	_cmdline = screen$line_command - 1
$	_msgline = screen$line_message - 1
$!
$	_leftline  = screen$width_margin  
$      	_rightline = screen$width - screen$width_margin  
$!
$	if screen$width_inquired
$	   then $ cls
$!	   else $ ws "''ESC$'[''screen$width'$"
$	   else $ set terminal/width='screen$width'
$	endif
$	if .not. screen$height_inquired then $ ws "''ESC$'[''screen$height't"
$	set terminal /inquire
$!
$	if screen$width_margin .eq. 0
$	   then $ _blank = ""
$	   else $ _blank = " "
$	endif
$!
$	ws f$fao("''ESC$'[''screen$line_header';''screen$width_margin'H''ESC$'[7m!''screen$menu_width'* ''_blank'''ESC$'[0m")
$	if screen$width_margin .eq. 0 then $ goto line$_nomargin
$	ws "''ESC$'[''screen$line_command';''_leftline'H''ESC$'(0x''ESC$'(B''ESC$'[''screen$line_command';''_rightline'H''ESC$'(0x''ESC$'(B"
$	_line = screen$line_header + 1
$!
$ line$_setup:
$!
$	ws "''ESC$'[''_line';''_leftline'H''ESC$'(0x''ESC$'(B''ESC$'[''_line';''_rightline'H''ESC$'(0x''ESC$'(B"
$	_line = _line + 1
$	if _line .lt. _cmdline then $ goto line$_setup
$	goto line$end_setup
$!
$ line$_nomargin:
$!
$	ws f$fao("''ESC$'[''_cmdline';''screen$width_margin'H''ESC$'(0!''screen$menu_width'*q''ESC$'(B")
$	ws f$fao("''ESC$'[''_msgline';''screen$width_margin'H''ESC$'(0!''screen$menu_width'*q''ESC$'(B")
$!
$	return
$!
$ line$end_setup:
$!
$	_linelength = screen$menu_width - 1
$!
$	if f$type(menu$item1) .eqs. ""
$	   then
$		_logo_location = (screen$width / 2 ) - 26
$		_line = screen$line_header + ((_cmdline - (screen$line_header + 1) - 4) / 2)
$		ws "''ESC$'[''_line';''_logo_location'H      OOOOO        MMMM MM       MM MMM     III III"
$		_line = _line + 1
$		ws "''ESC$'[''_line';''_logo_location'H   O OO   OO O       MMM MM     MMM MM       II II "
$		_line = _line + 1
$		ws "''ESC$'[''_line';''_logo_location'H OO OO     OO OO     MMMM MM   MM MM MM      II II "
$		_line = _line + 1
$		ws "''ESC$'[''_line';''_logo_location'HOO OO       OO OO   MM  MM MM MM  MM MM      II II "
$		_line = _line + 1
$		ws "''ESC$'[''_line';''_logo_location'HOO OO       OO OO   MM   MM MMM   MM MM      II II "
$		_line = _line + 1
$		ws "''ESC$'[''_line';''_logo_location'H OO OO     OO OO    MM    MM MM   MM MM      II II "
$		_line = _line + 1
$		ws "''ESC$'[''_line';''_logo_location'H   O OO   OO O     MM      MM      MM MM     II II "
$		_line = _line + 1
$		ws "''ESC$'[''_line';''_logo_location'H      OOOOO       MMM             MMM MMM   III III"
$	endif
$!
$	ws f$fao("''ESC$'[''_cmdline';''screen$width_margin'H''ESC$'(0t!''_linelength'*qu''ESC$'(B")
$	ws f$fao("''ESC$'[''_msgline';''screen$width_margin'H''ESC$'(0m!''_linelength'*qj''ESC$'(B")
$	return
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Handle the (keypad) Arrow Down key
$!
$ screen$keyselect_down:
$!
$	omi$signal omi not_yet
$	return
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Handle the (keypad) Arrow Up key
$!
$ screen$keyselect_up:
$!
$	omi$signal omi not_yet
$	return
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	
$!
$ screen$_erase:
$!
$!	if .not. omi$batch_mode
$!	   then
$!		if .not. screen$terminal_app_mode then $ set terminal /numeric_keypad
$!		delete\/key/nolog kp2
$!		delete\/key/nolog kp8
$!	endif
$!
$	delete\/symbol/global screen$terminal_app_mode
$	delete\/symbol/global screen$menu_width
$	delete\/symbol/global screen$line_command
$	delete\/symbol/global screen$line_message
$	delete\/symbol/global screen$line_header
$	delete\/symbol/global screen$line_length
$	delete\/symbol/global screen$default_position
$	delete\/symbol/global screen$prompt_position
$!
$	if f$type(inputs$first_line) .nes. "" then -
	   $ delete\/symbol/global inputs$first_line
$	if f$type(inputs$last_line) .nes. "" then -
	   $ delete\/symbol/global inputs$last_line
$	if f$type(inputs$value_location) .nes. "" then -
	   $ delete\/symbol/global inputs$value_location
$	if f$type(inputs$highest_item) .nes. "" then -
	   $ delete\/symbol/global inputs$highest_item
$	if f$type(inputs$max_size) .nes. "" then -
	   $ delete\/symbol/global inputs$max_size 
$!
$	if f$type(scroll$max_on_page) .nes. "" then -
	   $ delete\/symbol/global scroll$max_on_page
$	if f$type(scroll$this_page) .nes. "" then -
	   $ delete\/symbol/global scroll$this_page
$	if f$type(scroll$next_page) .nes. "" then -
	   $ delete\/symbol/global scroll$next_page
$	if f$type(scroll$previous_page) .nes. "" then -
	   $ delete\/symbol/global scroll$previous_page
$!
$	if f$type(omi$confirmed) .nes. "" then -
	   $ delete\/symbol/global omi$confirmed
$!
$	if p2 .nes. "NOCLS" .and. .not. omi$batch_mode
$	   then
$!		if screen$width_inquired
$!		   then $ cls
$!!		   else $ ws "''ESC$'[''screen$exit_width'$"
$!		   else $ set terminal/width = 'screen$exit_width'
$!		endif
$		set terminal/width = 'screen$exit_width'
$!		if .not. screen$height_inquired then $ ws "''ESC$'[''screen$exit_height't"
$		ws "''ESC$'[''screen$exit_height't"
$	endif
$	set terminal /inquire
$!
$	return
$!
$!******************************************************************************
