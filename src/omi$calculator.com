$	goto start$
$!
$!******************************************************************************
$!*                                                                            *
$!*    MODULE NAME:                                                            *
$!*    ============                                                            *
$!*      Omi$Calculator.Com                                                    *
$!*                                                                            *
$!*    CALLED BY:                                                              *
$!*    ==========                                                              *
$!*      Omi$Menu.Com, Omi$Toolbox.com                                         *
$!*                                                                            *
$!*    DESCRIPTION:                                                            *
$!*    ============                                                            *
$!*      This module performs all calculations. This includes the use of       *
$!*      floating points, which are by default not included in DCL.            *
$!*      Results are returned in the global symbol OMI$CALCULATED.             *
$!*                                                                            *
$!******************************************************************************

$!******************************************************************************
$!
$ start$:
$!
$	if f$trnlnm("calc$_subresults") .nes. "" then $ close calc$_subresults
$	formula$_master = "''p1'''p2'''p3'''p4'''p5'''p6'''p7'''p8'"
$	formula$_master = f$edit(formula$_master, "collapse")
$	if f$locate ("?", formula$_master) .lt. f$length(formula$_master)
$	   then
$		formula$_master = formula$_master - "?"
$		calc$show_subresults = 1
$		open /write calc$_subresults sys$scratch:calc$_subresults._tmp$
$	   else $ calc$show_subresults = 0
$	endif
$!
$	_parentheses = 0
$	_formula_pointer = 0
$!
$ calc$match_parentheses:
$!
$	if f$extract(_formula_pointer, 1, formula$_master) .eqs. "(" then -
	   $ _parentheses = _parentheses + 1
$	if f$extract(_formula_pointer, 1, formula$_master) .eqs. ")" then -
	   $ _parentheses = _parentheses - 1
$	_formula_pointer = _formula_pointer + 1
$	if _formula_pointer .lt. f$length(formula$_master) then -
	   $ goto calc$match_parentheses
$	if _parentheses .ne. 0 then $  goto calc$parenth_error
$!
$ calc$find_parentheses:
$!
$	formula$_work = formula$_master
$	if f$locate("(", formula$_master) .eq. f$length(formula$_master)
$	   then
$		gosub calc$_next
$		goto calc$_end
$	endif
$!
$ parenth$_extract:
$!
$	formula$_work = f$extract(f$locate("(", formula$_work) + 1, -
	   f$length(formula$_work) - f$locate("(", formula$_work), -
	   formula$_work)
$	if f$locate("(", formula$_work) .lt. f$locate(")", formula$_work) then -
	   $ goto parenth$_extract
$	formula$_work = f$element(0, ")", formula$_work)
$	formula$saved_work = "(''formula$_work')"
$	gosub calc$_next
$!
$	omi$substitute "''formula$saved_work'" "''_result'" "''formula$_master'"
$	if $status .ne. omi$_ok
$	   then
$		calc$_status = $status
$		goto calc$_fault
$	endif
$	if calc$show_subresults then -
	   $ write calc$_subresults "-> ''formula$_master' = ''omi$substituted'"
$	formula$_master = omi$substituted

$!
$	goto calc$find_parentheses
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Calculate a part of the formula that was enclosed by parentheses
$!
$ calc$_next:
$!
$ do$_divide:
$!
$	if f$locate("/", formula$_work) .eq. f$length(formula$_work) -
	   then $ goto do$_product
$!
$	_pointer = f$locate("/", formula$_work)
$	gosub formula$extract_current
$	gosub calc$_quotient
$	gosub calc$update_formula
$	goto do$_divide
$!
$ do$_product:
$!
$	if f$locate("*", formula$_work) .eq. f$length(formula$_work) -
	   then $ goto do$_add
$	_pointer = f$locate("*", formula$_work)
$	gosub formula$extract_current
$	gosub calc$_product
$	gosub calc$update_formula
$	goto do$_product
$!
$ do$_add:
$!
$	if f$locate("+", formula$_work) .eq. f$length(formula$_work) -
	   then $ goto do$_less
$	_pointer = f$locate("+", formula$_work)
$	if _pointer .eq. 0
$	   then
$		_tmp = f$element(1, "+", formula$_work)
$		_pointer = f$locate("+", _tmp) + 1
$	endif
$	gosub formula$extract_current
$	gosub calc$_plus
$	gosub calc$update_formula
$	goto do$_add
$!
$ do$_less:
$!
$	if f$locate("-", formula$_work) .eq. f$length(formula$_work) -
	   then $ return
$!
$	_pointer = f$locate("-", formula$_work)
$	if _pointer .eq. 0
$	   then
$		_tmp = f$element(1, "-", formula$_work)
$		_pointer = f$locate("-", _tmp)
$		if _pointer .eq. f$length(_tmp) .and. -
		   f$length(_tmp) .eq. f$length(formula$_work) - 1 -
		   then $ return
$	endif
$	gosub formula$extract_current
$	gosub calc$_less
$	gosub calc$update_formula
$	goto do$_less
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	We've got a pointer to the operator that's currently being processed.
$!	Extract a function with the two digits to use
$!
$ formula$extract_current:
$!
$	_fc_start = _pointer
$	_fc_end   = _pointer
$!
$ extract$find_start:
$!
$	if _fc_start .eq. 0 then $ goto extract$find_end
$	_fc_start = _fc_start - 1
$	_chk = f$extract(_fc_start, 1, formula$_work)
$	if f$type(_chk) .eqs. "INTEGER" .or. _chk .eqs. "." -
	   .or. _chk .eqs. "," then $ goto extract$find_start
$	if _fc_start .eq. 0
$	   then
$		if _chk .nes. "+" .and. _chk .nes. "-"
$		   then $ goto calc$calc_error
$		   else $ goto extract$find_end
$		endif
$	endif
$!
$	if (_chk .eqs. "+" .or. _chk .eqs. "-") .and. ( -
	   f$extract(_fc_start-1, 1, formula$_work) .eqs. "/" .or. -
	   f$extract(_fc_start-1, 1, formula$_work) .eqs. "*" .or. -
	   f$extract(_fc_start-1, 1, formula$_work) .eqs. "+" .or. -
	   f$extract(_fc_start-1, 1, formula$_work) .eqs. "-") then -
	   $ _fc_start = _fc_start - 1
$	_fc_start = _fc_start + 1
$!
$ extract$find_end:
$!
$	_fc_end = _fc_end + 1
$	if _fc_end .eq. f$length(formula$_work) then $ goto extract$_done
$	_chk = f$extract(_fc_end, 1, formula$_work)
$	if f$type(_chk) .eqs. "INTEGER" .or. _chk .eqs. "." -
	   .or. _chk .eqs. "," then $ goto extract$find_end
$	if (_chk .eqs. "+" .or. _chk .eqs. "-") .and. -
	   (_pointer + 1) .eq. _fc_end then $ goto extract$find_end
$!
$ extract$_done:
$!
$	_sz = _fc_end - _fc_start
$	formula$_current = f$extract(_fc_start, _sz, formula$_work)
$	formula$saved_current = formula$_current
$	return
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	A part of the formula has been calculated; replace it by the result
$!
$ calc$update_formula:
$!
$	omi$substitute "''formula$saved_current'" "''_result'" "''formula$_work'"
$	if $status .ne. omi$_ok
$	   then
$		calc$_status = $status
$		goto calc$_fault
$	endif
$	if calc$show_subresults then -
	   $ write calc$_subresults "-> ''formula$_work' = ''omi$substituted'"
$	formula$_work = omi$substituted
$!
$	return
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Error messages for the calculator.
$!
$ calc$calc_error:
$!
$	omi$signal omi ivdigit
$	calc$_status = $status
$	goto calc$_fault
$!
$ calc$oper_error:
$!
$	omi$signal omi ivoprat
$	calc$_status = $status
$	goto calc$_fault
$!
$ calc$divzero_error:
$!
$	omi$signal omi divzero
$	calc$_status = $status
$	goto calc$_fault
$!
$ calc$ldigit_error:
$!
$	omi$signal omi ldigit
$	calc$_status = $status
$	goto calc$_fault
$!
$ calc$parenth_error:
$!
$	omi$signal omi parnotmatch
$	calc$_status = $status
$	goto calc$_fault
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	The actual calculations
$!
$ calc$_plus:
$!
$	_operator = "+"
$	gosub calc$_analyze
$!
$	if _float
$	   then
$		if _a_min then $ _a1 = "-''_a1'"
$		if _b_min then $ _b1 = "-''_b1'"
$		_a = "''_a1'''_a2'"
$		_b = "''_b1'''_b2'"
$		_r = f$integer(_a) + f$integer(_b)
$		_r1 = "''f$extract(0,f$length(_r)-f$length(_a2),_r)'"
$		_r2 = "''f$extract(f$length(_r)-f$length(_a2),f$length(_a2),_r)'"
$		if _r1 .eqs. "" then $ _r1 = "0"
$		if _r1 .eqs. "-" then $ _r1 = "-0"
$		_result = "''_r1'''float$_char'''_r2'"
$		if calc$round_steps then $ gosub calc$_round_result
$	   else
$		if _a_min then $ _a = "-''_a'"
$		if _b_min then $ _b = "-''_b'"
$		_result = f$integer(_a) + f$integer(_b)
$	endif
$	return
$!
$!******************************************************************************
$!
$ calc$_less:
$!
$	_operator = "-"
$	gosub calc$_analyze
$	if _float
$	   then
$		if _a_min then $ _a1 = "-''_a1'"
$		if _b_min then $ _b1 = "-''_b1'"
$		_a = "''_a1'''_a2'"
$		_b = "''_b1'''_b2'"
$		_r = f$integer(_a) - f$integer(_b)
$		_r1 = "''f$extract(0,f$length(_r)-f$length(_a2),_r)'"
$		_r2 = "''f$extract(f$length(_r)-f$length(_a2),f$length(_a2),_r)'"
$		if _r1 .eqs. "" then $ _r1 = "0"
$		if _r1 .eqs. "-" then $ _r1 = "-0"
$		_result = "''_r1'''float$_char'''_r2'"
$		if calc$round_steps then $ gosub calc$_round_result
$	   else
$		if _a_min then $ _a = "-''_a'"
$		if _b_min then $ _b = "-''_b'"
$		_result = f$integer(_a) - f$integer(_b)
$	endif
$	return
$!
$!******************************************************************************
$!
$ calc$_product:
$!
$	_operator = "*"
$	gosub calc$_analyze
$	if _float
$	   then
$		if (2147483647 / f$integer(_full_a)) .lt. f$integer(_full_b)
$		   then
$			omi$signal omi prooutra,"''_full_a'*''_full_b'"
$			calc$_status = $status
$			omi$wait
$		endif
$		_r = f$integer(_full_a) * f$integer(_full_b)
$		if _r .lt. 0
$		   then
$			_r = 0 - _r
$			_sign = "-"
$		   else $ _sign = ""
$		endif
$		if f$length(_r) .le. _total_decs
$		   then
$			_r1 = 0
$			_addz = _total_decs - f$length(_r)
$			if _addz .gt. 0
$			   then $ _r2 = f$fao("!''_addz'*0!AS", "''_r'")
$			   else $ _r2 = _r
$			endif
$		   else
$			_r1 = "''f$extract(0,f$length(_r)-_total_decs,_r)'"
$			_r2 = "''f$extract(f$length(_r)-_total_decs,_total_decs,_r)'"
$		endif
$		_result = "''_sign'''_r1'''float$_char'''_r2'"
$		if calc$round_steps then $ gosub calc$_round_result
$	   else
$		if (2147483647 / f$integer(_a)) .lt. f$integer(_b)
$		   then
$			omi$signal omi prooutra,"''_a'*''_b'"
$			calc$_status = $status
$			omi$wait
$		endif
$		_result = f$integer(_a) * f$integer(_b)
$	endif
$	if (_a_min .and. .not. _b_min) .or. (.not. _a_min .and. _b_min) then -
	   _result = "-''_result'"
$	return
$!
$!******************************************************************************
$!
$ calc$_quotient:
$!
$	_operator = "/"
$	gosub calc$_analyze
$	if .not. _float
$	   then $ float$_char = "."
$	   else
$		_a = "''_a1'''_a2'"
$		_b = "''_b1'''_b2'"
$	endif
$	if f$integer(_b) .eq. 0 then $ goto calc$divzero_error
$	_addz = 9 - f$length(_a)
$	if _addz .gt. 0 then $ _a = f$fao("!AS!''_addz'*0", "''_a'")
$	_r = f$integer(_a) / f$integer(_b)
$	if _addz .le. 0
$	   then
$		_result = _r
$		if (_a_min .and. .not. _b_min) .or. (.not. _a_min .and. _b_min) then -
		   _result = "-''_result'"
$		return
$	endif
$	_addd = _addz - f$length(_r)
$	if _addd .gt. 0 then $ _r = f$fao("!''_addd'!AS", "''_r'")
$	_r1 = "''f$extract(0,f$length(_r)-_addz,_r)'"
$	_r2 = "''f$extract(f$length(_r)-_addz,_addz,_r)'"
$	if _r1 .eqs. "" then $ _r1 = "0"
$	if _r1 .eqs. "-" then $ _r1 = "-0"
$	_result = "''_r1'''float$_char'''_r2'"
$	if (_a_min .and. .not. _b_min) .or. (.not. _a_min .and. _b_min) then -
	   _result = "-''_result'"
$	if calc$round_steps then $ gosub calc$_round_result
$	return
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Calculations have been made. Now put the floating point back in the
$!	proper position if there was one, and set the global value.
$!
$ calc$_fault:
$!
$	if calc$show_subresults
$	   then
$		close calc$_subresults
$		omi$call type_file sys$scratch:calc$_subresults._tmp$
$		delete\ /nolog /noconfirm sys$scratch:calc$_subresults._tmp$;
$	endif
$	exit calc$_status
$!
$ calc$_end:
$!
$	if f$type(_result) .eqs. ""
$	   then
$		omi$signal omi nocalc,formula$_master
$		calc$_status = $status
$		goto calc$_fault
$	endif
$	gosub calc$_round_result
$	omi$calculated == _result
$	if calc$show_subresults
$	   then
$		close calc$_subresults
$		omi$call type_file sys$scratch:calc$_subresults._tmp$
$		delete\ /nolog /noconfirm sys$scratch:calc$_subresults._tmp$;
$	endif
$	exit omi$_ok
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==> Round the result if desired
$!
$ calc$_round_result:
$!
$	if f$integer(f$element(1, ".", _result)) .eq. 0
$	   then $ _result = f$element(0, ".", _result)
$	   else
$		_dec = f$element(1, ".", _result)
$		_result = "''f$element(0, ".", _result)'"
$	 calc_round$remove_zeros:
$		if f$extract(f$length(_dec)-1, 1, _dec) .eqs. "0"
$		   then
$			_dec = _dec / 10
$			goto calc_round$remove_zeros
$		endif
$		calc$precision = f$integer(calc$precision)
$		if f$length(_dec) .gt. calc$precision
$		   then
$			_d = f$integer(f$extract(calc$precision, 1, _dec))
$			_dec = f$extract(0, calc$precision, _dec)
$			if _d .ge. 5
$			   then
$				_dec = f$integer(_dec) + 1
$				if f$length(_dec) .eq. calc$precision+1 .and. -
				   f$extract(1, calc$precision, _dec) .eqs. "000"
$				   then
$					_result = f$integer(_result) + 1
$					return
$				endif
$			endif
$		endif
$		_result = _result + ".''_dec'"
$	endif
$	return
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Check for existance of a floating point, and create normal integers
$!	if they are found.
$!
$ calc$_analyze:
$!
$	_a_min = 0
$	_b_min = 0
$	if f$extract(0, 1, formula$_current) .eqs. "-"
$	   then
$		formula$_current = formula$_current - "-"
$		_a_min = 1
$	endif
$	if f$locate ("''_operator'-", formula$_current) .lt. f$length(formula$_current)
$	   then
$		formula$_current = formula$_current - "-"
$		_b_min = 1
$	endif
$	_a = f$element(0, "''_operator'", formula$_current)
$	_b = f$element(1, "''_operator'", formula$_current)
$!
$	_float = 0
$	if f$locate(".", _a) .lt. f$length(_a) .or. f$locate(".", _b) .lt. f$length(_b)
$	   then
$		_float = 1
$		float$_char = "."
$	endif
$!
$	if f$locate(",", _a) .lt. f$length(_a) .or. f$locate(",", _b) .lt. f$length(_b)
$	   then
$		_float = 1
$		float$_char = ","
$	endif
$!
$	if .not. _float
$	   then
$		if f$type (_a) .nes. "INTEGER" .or. f$type(_b) .nes. "INTEGER" then -
		   $ goto calc$calc_error
$		_a = f$integer(_a)
$		_b = f$integer(_b)
$		return                                     
$	endif
$!
$	_a1 = f$element (0, "''float$_char'", _a)
$	_a2 = f$element (1, "''float$_char'", _a)
$	_b1 = f$element (0, "''float$_char'", _b)
$	_b2 = f$element (1, "''float$_char'", _b)
$	if f$length(_b2) .gt. f$length(_a2)
$	   then
$		_zfill = f$length(_b2) - f$length(_a2)
$		_a2 = f$fao("!AS!''_zfill'*0", _a2)
$	endif
$	if f$length(_a2) .gt. f$length(_b2)
$	   then
$		_zfill = f$length(_a2) - f$length(_b2)
$		_b2 = f$fao("!AS!''_zfill'*0", _b2)
$	endif
$	_total_decs = f$length(_a2) + f$length(_b2)
$	if _a1 .eqs. "" then $ _a1 = "0"
$	if _b1 .eqs. "" then $ _b1 = "0"
$	if _a2 .eqs. float$_char
$	   then
$		_total_decs = _total_decs - 1
$		_a2 = ""
$	endif
$	if _b2 .eqs. float$_char
$	   then
$		_total_decs = _total_decs - 1
$		_b2 = ""
$	endif
$	if f$type (_a1) .nes. "INTEGER" .or. f$type(_b1) .nes. "INTEGER" .or. -
	   (f$type (_a2) .nes. "INTEGER" .and. _a2 .nes. "") .or. -
	   (f$type (_b2) .nes. "INTEGER" .and. _b2 .nes. "") then -
	   $ goto calc$calc_error
$!
$	_full_a = "''_a1'''_a2'"
$	_full_b = "''_b1'''_b2'"
$ 	gosub calc$_remove_zeros
$!
$! Should be a string overlay here......
$!	if f$fao("!10<!AS!>",_full_a) .gts. "2147483647"
$! .... but this is fine as a workaround.....
$	if f$integer(_full_a) .nes. "''_full_a'" .and. f$length(_full_a) .ge.10
$	   then
$		omi$signal omi outofra,_full_a
$		calc$_status = $status
$		goto calc$_fault
$	endif
$	if f$integer(_full_b) .nes. "''_full_b'" .and. f$length(_full_b) .ge.10
$	   then
$		omi$signal omi outofra,_full_b
$		calc$_status = $status
$		goto calc$_fault
$	endif
$!
$	if f$length(_a2) .gt. f$length(_b2)
$	   then
$		_addz = f$length(_a2) - f$length(_b2)
$		_b2 = f$fao("!AZ!''_addz'*0", _b2)
$	endif
$	if f$length(_b2) .gt. f$length(_a2)
$	   then
$		_addz = f$length(_b2) - f$length(_a2)
$		_a2 = f$fao("!AZ!''_addz'*0", _a2)
$	endif
$	_a1 = f$integer(_a1)
$	_b1 = f$integer(_b1)
$!
$	return
$!
$ calc$_remove_zeros:
$!
$! Remove trailing zeros behind the decimal point
$!
$	if f$extract(f$length(_full_a)-1, 1, _full_a) .eqs. "0" .and. -
	   f$extract(f$length(_full_b)-1, 1, _full_b) .eqs. "0"
$	   then
$		_full_a = f$extract(0, f$length(_full_a)-1, _full_a)
$		_full_b = f$extract(0, f$length(_full_b)-1, _full_b)
$		_total_decs = _total_decs - 2
$		goto calc$_remove_zeros
$	endif
$	return
$!

$!******************************************************************************
