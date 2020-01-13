$	goto start$
$!
$!******************************************************************************
$!*                                                                            *
$!*    MODULE NAME:                                                            *
$!*    ============                                                            *
$!*      Omi$Edit_Cmd.Com                                                      *
$!*                                                                            *
$!*    CALLED BY:                                                              *
$!*    ==========                                                              *
$!*      Omi$Menu.Com                                                          *
$!*                                                                            *
$!*    DESCRIPTION:                                                            *
$!*    ============                                                            *
$!*      This module takes care of the execution of the EDIT command.          *
$!*                                                                            *
$!******************************************************************************

$!******************************************************************************
$!
$ start$:
$!
$	if omi$_p1 .eqs. ""
$	   then
$		omi$ask "Edit what: "
$		if $status .eq. omi$_cancelled then $ exit omi$_cancelled
$		omi$_p1 = omi$response
$		deletee/symbol/global omi$response
$		goto start$
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. -
	   f$extract(0, f$length(omi$_p1), "VALUE_FILE") then -
	   $ goto edit$value_file
$!
$!      **** Edit commands below are not available in OTF Menus
$!
$	if omi$otf_menu
$	   then
$		omi$signal omi cmdnotav
$		exit $status
$	endif
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. -
	   f$extract(0, f$length(omi$_p1), "ELEMENT") then -
	   $ goto edit$element
$!
$	if f$length(omi$_p1) .ge. 3 .and. omi$_p1 .eqs. -
	   f$extract(0, f$length(omi$_p1), "MENU_FILE") then -
	   $ goto edit$menu_file
$!
$	omi$signal omi ivopt,edit
$	exit $status
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Edit an element from the current menu level. Find out if it's an
$!	item or an input element, and call the proper subroutine for it.
$!
$ edit$element:
$!
$	gosub get$_element
$!
$	if f$type('omi$current_menu'$item'omi$_p2') .eqs. ""
$	   then
$		omi$_p2 = omi$_p2 - 'omi$current_menu'$highest_item
$		if f$type('omi$current_menu'$input'omi$_p2') .eqs. ""
$		   then
$			omi$signal omi invopt
$			exit $status
$		endif
$		edit$_type = "input"
$	   else $ edit$_type = "item"
$	endif
$!
$	edit$_element_name  == "''edit$_type'''omi$_p2'"
$	edit$_element_value == 'omi$current_menu'$'edit$_element_name
$!
$	otf_menu$on_exit == "edit_element"
$	otf_menu$all_inputs == 0
$	otf_menu$prompt == "EditOTF> "
$	otf_menu$item1 == "Exit without update#command#back noexit_module"
$	otf_menu$item2 == "Write changes and exit#command#back"
$	otf_menu$input1 == "Text on display#edit_element_p1#" + -
	   f$element(0, "#", edit$_element_value)
$!
$	gosub edit$'edit$_type'_element
$	omi$create_otf
$!
$	goto end$
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	The edit command was invoked to modify the current menu file.
$!	First, it's erased from menu. After the edit session it's started
$!	again.
$!
$ edit$menu_file:
$!
$	if f$edit(omi$current_menu, "upcase") .nes. "MENU"
$	   then
$		omi$signal omi toponly
$		exit $status
$	endif
$!
$	_file = "''omi$menu_location'''omi$menu_file'"
$	omi$signal omi erasemnu
$	omi$config "''omi$menu_file'" Cleanup
$!
$	assign /user TT: sys$input
$	'main$editor' '_file
$	deassign sys$input
$!
$	omi$signal omi init
$	omi$config 'omi$menu_file
$	omi$refresh
$!
$	goto end$
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	The edit command was invoked to modify a select- or tag list that
$!	retrieves values from a file. Call the editor that's defined in the
$!	users configuration file to modify the file.
$!
$ edit$value_file:
$!
$	gosub get$_element
$!
$	_input = omi$_p2 - 'omi$current_menu'$highest_item 
$	_block = f$edit(f$element(1, "{", f$element(0, "}", -
	   'omi$current_menu'$input'_input')), "upcase") - "SEL|" - "TAG|"
$	if f$type('_block'$filename) .eqs. ""
$	   then
$		omi$signal omi ivvalfil
$		exit $status
$	endif
$	_file = f$parse('_block'$filename,"Omi$Menu_Directory:",".dat")
$!
$	assign /user TT: sys$input
$	'main$editor' '_file
$	deassign sys$input
$	omi$refresh
$!
$	goto end$
$!
$!******************************************************************************

$!******************************************************************************
$!
$ end$:
$!
$	exit omi$_ok
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Find out if the element nr. was specified. If not, prompt for it.
$!
$ get$_element:
$!
$	if omi$_p2 .eqs. ""
$	   then
$		omi$ask "Element #: "
$		if $status .eq. omi$_cancelled then $ exit omi$_cancelled
$		omi$_p2 = omi$response
$		deletee/symbol/global omi$response
$		goto get$_element
$	endif
$	return
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Prompt the user for new values for the selected input element that
$!	should be modified by creating an OTF menu.
$!
$ edit$input_element:
$!
$	_i_type    = f$edit(f$element(1, "#", edit$_element_value),"upcase")
$	_i_default = f$edit(f$element(2, "#", edit$_element_value),"upcase")
$	_i_format  = f$edit(f$element(3, "#", edit$_element_value),"upcase")
$!
$	if _i_default .eqs. "#" then $ _i_default = ""
$	if _i_format  .eqs. "#" then $ _i_format  = ""
$!
$	_def_value = "value1"
$	_var_name  = _i_type
$	_list_name = ""
$!
$	if f$locate("SEL|", f$edit(_i_type,"upcase")) .lt. f$length(_i_type)
$	   then
$		_def_value = "value2"
$		_var_name  = f$element(1, "}", _i_type)
$		_list_name = f$element(1, "|", f$element(0, "}", _i_type))
$		_list_type = "Select"
$	endif
$!
$	if f$locate("TAG|", f$edit(_i_type,"upcase")) .lt. f$length(_i_type)
$	   then
$		_def_value = "value3"
$		_var_name  = f$element(1, "}", _i_type)
$		_list_name = f$element(1, "|", f$element(0, "}", _i_type))
$		_list_type = "Tag"
$	endif
$!
$	otf_menu$input2 == "Input type#{sel|otf_menu_sellst}edit_elem_inptype#''_def_value'"
$	otf_menu$input3 == "Variable Name#edit_elem_varname#''_var_name'#otf_menu_intname"
$	if _list_name .nes. ""
$	   then $ otf_menu$input4 == -
		   "''_list_type' name#edit_elem_lstname#''_list_name'#otf_menu_intname"
$	   else $ otf_menu$input4 == -
		   "Format section#edit_element_p4#''_i_format'#otf_menu_intname"
$	endif
$	otf_menu$input5 == -
	   "Default value#edit_element_p3#''_i_default'"
$!
$	otf_menu_sellst$value1 = "Straight input"
$	otf_menu_sellst$value2 = "Select list"
$	otf_menu_sellst$value3 = "Tag list"
$!
$	otf_menu_intname$type        = "string"
$	otf_menu_intnames$ivchars    = "@#$%^&*()'?/|\+`~{}[]<>"
$	otf_menu_intnames$collapse   = omi$_true 
$	otf_menu_intnames$minlength  = 2
$!
$	return
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Prompt the user for new values for the selected item element that
$!	should be modified by creating an OTF menu.
$!
$ edit$item_element:
$!
$	_i_type = f$edit(f$element(1, "#", edit$_element_value),"upcase")
$	if _i_type .eqs. "CALL"
$	   then
$		_def_value = "value1"
$		_prompt    = "Module"
$	endif
$!
$	if _i_type .eqs. "COMMAND"
$	   then
$		_def_value = "value2"
$		_prompt    = "OMI Command"
$	endif
$!
$	if _i_type .eqs. "SUBMENU"
$	   then
$		_def_value = "value3"
$		_prompt    = "Submenu"
$	endif
$!
$	otf_menu$input2 == "Item type#{sel|otf_menu_sellst}edit_element_p2#''_def_value'"
$	otf_menu$input3 == "''_prompt'#edit_element_p3#" + -
	   f$element(2, "#", edit$_element_value)
$!
$	otf_menu_sellst$value1 = "Call"
$	otf_menu_sellst$value2 = "Command"
$	otf_menu_sellst$value3 = "Submenu"
$!
$	return
$!
$!******************************************************************************

edit$_element_name
edit$_element_value


