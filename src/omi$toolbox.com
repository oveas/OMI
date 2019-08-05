$	goto start$
$!
$!******************************************************************************
$!*                                                                            *
$!*    MODULE NAME:                                                            *
$!*    ============                                                            *
$!*      Omi$Toolbox.Com                                                       *
$!*                                                                            *
$!*    CALLED BY:                                                              *
$!*    ==========                                                              *
$!*      Omi$Menu.Com                                                          *
$!*                                                                            *
$!*    DESCRIPTION:                                                            *
$!*    ============                                                            *
$!*      Additional tools for OMI, called by the several internal OMI commands.*
$!*      These commands will be called whenever one of the OMI commands is     *
$!*      specified in a called module, returning the resulting values in       *
$!*      global symbols.                                                       *
$!*                                                                            *
$!******************************************************************************

$!******************************************************************************
$!
$ start$:
$!
$	gosub 'p1'$
$	exit $status
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	The Omi$Calc command; this command just checks for existance of the
$!	required parameter(s), then calls the file Omi$Calculator.Com,
$!	which performs all calculations
$!
$ calc$:
$!
$	if p2 .eqs. ""
$	   then
$		omi$signal omi insarg,"OMI$CALC"
$		return omi$_warning
$	endif
$!
$	@omi$:omi$calculator "''p2'" "''p3'" "''p4'" "''p5'" "''p6'" "''p7'" "''p8'"
$	return $status
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Popus a message box. The message is given as a parameter. This
$!	routine decides how wide the message box can be, breaks the input
$!	line if necessary, and draws the box.
$!	After a confirm (depeinding on options) the screen is redrawn.
$!
$ popup$:
$!
$	_msg_length = p2
$	_maxlen = screen$menu_width / 2
$	_widest = 0
$	_lc = 1
$	_ec = 0
$!
$	_msg_string'_lc' = f$element(_ec, " ", p2)
$!
$ popup$_nextword:
$!
$	_ec = _ec + 1
$	_next_word = f$element(_ec, " ", p2)
$	if _next_word .eqs. " " .or. _next_word .eqs. "" then -
	   $ goto popup$end_nextword
$	if (f$length(_msg_string'_lc') + f$length(_next_word) + 1) -
	   .lt. _maxlen
$	   then $ _msg_string'_lc' = _msg_string'_lc' + " " + _next_word
$	   else
$		if f$length(_msg_string'_lc') .gt. _widest then -
		   $ _widest = f$length(_msg_string'_lc')
$		_lc = _lc + 1
$		_msg_string'_lc' = _next_word
$	endif
$	goto popup$_nextword
$!
$ popup$end_nextword:
$!
$	if f$length(_msg_string'_lc') .gt. _widest then -
 	   $ _widest = f$length(_msg_string'_lc')
$	_ln_count = _lc
$	_t_width = _widest + 2
$	_lc = 1
$	_t_loc = screen$line_header + -
	   ((screen$line_command - screen$line_header - _ln_count) / 2)
$	_m_loc = screen$default_position + (screen$menu_width / 4)
$	ws f$fao("''BELL$'''BELL$'''ESC$'[''_t_loc';''_m_loc'H''ESC$'(0l!''_t_width'*qk''ESC$'(B")
$!
$ popup$_write:
$!
$	_t_loc = _t_loc + 1
$	if _lc .gt. _ln_count then $ goto popup$end_write
$	_blank_fill = _t_width - f$length(_msg_string'_lc') - 2
$	ws f$fao("''ESC$'[''_t_loc';''_m_loc'H''ESC$'(0x''ESC$'(B !AS!''_blank_fill'*  ''ESC$'(0x''ESC$'(B", _msg_string'_lc')
$	_lc = _lc + 1
$	goto popup$_write
$!
$ popup$end_write:
$!
$	ws f$fao("''ESC$'[''_t_loc';''_m_loc'H''ESC$'(0m!''_t_width'*qj''ESC$'(B")
$	_refresh = 1
$	_wait    = 1
$	_confirm = 0
$	_cnt = 0
$!
$ popup$check_options:
$!
$	_opt = f$element(_cnt, ",", p3)
$	if _opt .eqs. "," .or. _opt .eqs. "" then $ goto popup$checked_options
$	if f$extract(0,5,_opt) .eqs. "NOREF" then $ _refresh = 0
$	if f$extract(0,5,_opt) .eqs. "NOWAI" then $ _wait    = 0
$	if f$extract(0,5,_opt) .eqs. "CONFI"
$	   then
$		_confirm = 1
$		_wait    = 0
$	endif
$	_cnt = _cnt + 1
$	goto popup$check_options
$!
$ popup$checked_options:
$!
$	if _confirm
$	   then
$		omi$confirm "''questions$default_confirm'"
$		if .not. omi$confirmed
$		   then
$			if _refresh then $ omi$refresh
$			return omi$_warning
$		endif
$	endif
$	if _wait    then $ omi$wait
$	if _refresh then $ omi$refresh
$	return omi$_ok
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	This is a small imported tool, written a few years ago, which does what
$!	'F$EDIT(string,"REVERSE")' should do.
$!	It returns the global symbol OMI$REVERSED, which contains the 
$!	reversed value of the complete input string.
$!
$ reverse$:
$!
$	inputs$ = "''p2' ''p3' ''p4' ''p5' ''p6' ''p7' ''p8'"
$	inputs$ = f$edit(inputs$ ,"trim")
$	if inputs$ .eqs. ""
$	   then
$		omi$signal omi insarg,"OMI$REVERSE"
$		return omi$_error
$	endif
$!
$	ilen$ = f$length(inputs$)
$	ipos$ = 0
$	reversed$ = ""
$!
$ string$_reverse:
$!
$	if ipos$ .lt. ilen$
$	   then
$		rpos$ = ilen$ - ipos$
$		tmp$ = f$extract(ipos$, 1, inputs$)
$		reversed$[rpos$,1] := "''tmp$'"
$!		reversed$[rpos$,1] := f$extract(ipos$, 1, inputs$)
$		ipos$ = ipos$ + 1
$		goto string$_reverse
$	endif
$	omi$reversed == f$edit(reversed$, "trim")
$	return omi$_ok
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Dump all OMI$RECORDs to a file
$!
$ dump_info$:
$!
$	if p2 .eqs. ""
$	   then
$		omi$signal omi insarg,"OMI$DUMP_INFO"
$		return omi$_error
$	endif
$!
$	records = 1
$	if f$search(p2) .eqs. ""
$	   then $ open /write /error=dinf$_fopenerr dumpfile 'p2
$	   else $ open /append /error=dinf$_fopenerr dumpfile 'p2
$	endif
$!
$ dinf$_loop:
$!
$	if f$type(omi$record'records') .eqs. "" then $ goto dinf$end_loop
$	if omi$record'records' .eqs. "" then $ goto dinf$end_loop
$	write dumpfile omi$record'records'
$	records = records + 1
$	goto dinf$_loop
$!
$ dinf$end_loop:
$!
$	close dumpfile 
$	return omi$_ok
$!
$ dinf$_fopenerr:
$!
$	omi$signal omi dmp_openerr,'p2
$	return omi$_error
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Call another OMI module.
$!
$ call$:
$!
$	if p2 .eqs. ""
$	   then
$		omi$signal omi insarg,"OMI$CALL"
$		return omi$_warning
$	endif
$!
$	_input_module = p2
$	_module = ""
$	_log_index = 0
$!
$ call$check_path:
$	_menu_directory = f$trnlnm("Omi$Menu_Directory",,'_log_index')
$	if _menu_directory .eqs. "" then $ goto call$end_of_list
$	if f$extract(f$length(_menu_directory)-1, 1, _menu_directory) .nes. "]" -
	   .and. f$extract(f$length(_menu_directory)-1, 1, _menu_directory) .nes. ":" -
	   then $ _menu_directory = "''_menu_directory':"
$	_module = f$search(f$parse(_input_module, "''_menu_directory'.Omi"))
$	if _module .eqs. ""
$	   then
$		_log_index = _log_index + 1
$		goto call$check_path
$	endif
$!
$ call$end_of_list:
$	if _module .eqs. "" then -
	   $ _module = f$search(f$parse(_input_module, "Omi$:.Omi"))
$	if f$search(_module) .eqs. ""
$	   then
$		omi$signal omi modnotfound,'p2'
$		return $status
$	endif
$!
$	@'_module' "''p3'" "''p4'" "''p5'" "''p6'" "''p7'" "''p8'"
$	return $status
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	An old routine, written a few years ago, imported here to support
$!	mailboxes in OMI. It opens a temporary mailbox for read and write.
$!	The logical pointing to this mailbox is OMI$MAILBOX. There's also a
$!	global symbol with the same name, containing the device name of the
$!	temporary mailbox (MBAxxx:)
$!	Change in v1.41: the logical OMI$MAILBOX is still the default, but
$!	using a parameter, another logical name can now be specified.
$!
$ create_mbx$:
$!
$	if p2 .eqs. ""
$	   then $ _mailbox_name = "Omi$Mailbox"
$	   else $ _mailbox_name = p2
$	endif
$!
$	if f$trnlnm(_mailbox_name) .nes. ""
$	   then
$		omi$signal omi mbxalrex,'_mailbox_name'
$		return omi$_warning
$	endif
$!
$!* The second parameter is not (yet) supported since this module needs
$!* to write to the mailbox. Perhaps this can be solved in a future release.
$!
$!	if p3 .eqs. "" then $ p3 = "read,write"
$	p3 = "read,write"
$!
$	omi$signal omi crembx
$!
$	open/write CrMbxSub Sys$Scratch:Omi_CrMbxSub._Tmp$
$	write CrMbxSub -
	   "$ delete/nolog/noconfirm 'f$environment(""procedure"")'"
$	write CrMbxSub "$ define/job _mbox mba'f$getjpi(0,""tmbu"")':"
$	write CrMbxSub -
	   "$ set process/resume/identification='f$getjpi(0,""owner"")'"
$	write CrMbxSub "$ open/read mbx 'f$trnlnm(""_mbox"")'"
$	write CrMbxSub "$ read mbx command"
$	write CrMbxSub "$ close mbx"
$	write CrMbxSub "$ 'command'"
$	close CrMbxSub
$!
$	spawn/nowait/output=nl:/nolog @Sys$Scratch:Omi_CrMbxSub._Tmp$
$	set process/suspended/identification=0
$	'_mailbox_name' == f$trnlnm("_mbox")
$!
$	_mode = ""
$	if f$locate("rea", f$edit(p3, "lowercase")) .lt. f$length(p3) then -
	   $ _mode = _mode + "/read"
$	if f$locate("wri", f$edit(p3, "lowercase")) .lt. f$length(p3) then -
	   $ _mode = _mode + "/write"
$!
$ 	open '_mode' /share=write /error=crembx$_error -
  	   '_mailbox_name' f$trnlnm("_mbox")
$ 	write /error=crembx$_error '_mailbox_name' "exit"
$	omi$msgline_clear
$	deassign/job _mbox
$	if f$type(Omi$Open_Mailbox_List) .eqs. ""
$	   then $ Omi$Open_Mailbox_List == "''_mailbox_name'"
$	   else $ Omi$Open_Mailbox_List == Omi$Open_Mailbox_List + -
		   "#''_mailbox_name'"
$	endif
$	return omi$_ok
$!
$ crembx$_error:
$!
$	omi$msgline_clear
$	omi$signal omi crembxerr
$	if f$trnlnm('_mailbox_name') .nes. "" then $ close '_mailbox_name'
$	deassign/job _mbox
$	return omi$_error
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Calculate the current day-, week- and monthnumber. They're returned
$!	as the following global symbols:
$!		omi$daynumber
$!		omi$weeknumber
$!		omi$monthnumber
$!
$ date_info$:
$!
$	if p2 .eqs. "" then $ p2 = "today"
$       months$  = "+#january#31+#february#28+#march#31+#april#30+#may#31+#june#30+#july#31+#august#31+#september#30+#october#31+#november#30+#december#31"
$       year$    = f$integer(f$cvtime(p2,,"year"))
$       imonth$  = f$integer(f$cvtime(p2,,"month"))
$       iday$    = f$integer(f$cvtime(p2,,"day"))
$       year$_4  = (((year$/4)*4 .eq. year$) .and. ((year$/100)*100 .ne. year$))
$       lyear$_4 = ((((year$-1)/4)*4 .eq. (year$-1)) .and. -
	   (((year$-1)/100)*100 .ne. (year$-1)))
$!
$       month$_info = f$element(imonth$,"+",months$)
$       month_of_year$ = f$element( 1, "#", month$_info )
$!
$       month$_counter = imonth$
$!
$ d_info$count_days:
$!
$	if month$_counter .gt. 1
$	   then
$       	month$_counter = month$_counter - 1
$		month$_info = f$element( month$_counter, "+", months$ )
$       	iday$ = iday$ + f$element( 2, "#", month$_info )
$		goto d_info$count_days
$	endif
$!
$       if year$_4 .and. imonth$ .gt. 2 then iday$ = iday$ + 1
$!
$	if f$cvtime(,,"weekday") .eqs. "Monday"    then $ iday$_tmp = iday$ + 9
$	if f$cvtime(,,"weekday") .eqs. "Tuesday"   then $ iday$_tmp = iday$ + 8
$	if f$cvtime(,,"weekday") .eqs. "Wednesday" then $ iday$_tmp = iday$ + 7
$	if f$cvtime(,,"weekday") .eqs. "Thursday"  then $ iday$_tmp = iday$ + 6
$	if f$cvtime(,,"weekday") .eqs. "Friday"    then $ iday$_tmp = iday$ + 5
$	if f$cvtime(,,"weekday") .eqs. "Saturday"  then $ iday$_tmp = iday$ + 4
$	if f$cvtime(,,"weekday") .eqs. "Sunday"    then $ iday$_tmp = iday$ + 3
$!
$       if iday$_tmp .lt. 7
$          then
$       	iday$_tmp = iday$_tmp + 365
$       	if lyear$_4 then $ iday$_tmp = iday$_tmp + 1
$       endif
$       iweek$ = iday$_tmp / 7
$       if iday$_tmp .gt. 371
$          then
$       	iweek$ = 1
$       	if ( iday$_tmp .eq. 372 ) .and. ( year$_4 .or. lyear$_4 ) -
		   then $ iweek$ = 53
$       endif
$!
$	if iday$   .lt. 10 then $ iday$   = "0''iday$'"
$	if iweek$  .lt. 10 then $ iweek$  = "0''iweek$'"
$	if imonth$ .lt. 10 then $ imonth$ = "0''imonth$'"
$!
$	omi$daynumber   == iday$
$	omi$weeknumber  == iweek$
$	omi$monthnumber == imonth$
$!
$	return omi$_ok
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Decrypt an encrypted string. The value will be returned in the global
$!	symbol OMI$DECRYPTED.
$!
$ decrypt$:
$!
$	if p2 .eqs. ""
$	   then
$		omi$signal omi insarg,"OMI$DECRYPT"
$		return omi$_error
$	endif
$s4=""
$s2="''p2'"
$rt1=-
"omi$decrypted"
$r1="("
$r2=0
$r3=r2+-
2
$r4=3*r3
$r5=r4-1
$s5=s4
$if f-
$loca-
te("''ESC$'(",-
s2)-
.lt.f-
$len-
gth-
(s2)
$then
$gosub -
11$
$goto -
18$
$endif
$n$=0
$gosub -
27$
$if -
$status.eq.-
omi$_error
$then return -
omi$_error
$endif
$19$:
$if n$-
.eq.f-
$length-
(s2)
$then
$s2=-
"''s2$'"
$ver$ver=1
$v$v=-
"t"
$goto-
 -
18$
$endif
$s2$[8*-
n$,-
8]=-
(f-
$cvui-
(n$*8,-
8,s2)/-
vac$)-oac$
$n$=-
n$+1
$goto -
19$
$11$:
$if -
f$-
loc-
ate-
("''ESC$'("-
,s2)-
.lt.f-
$length-
(s2)
$then
$r6=-
"%"+-
"''r5'"
$r7=-
r1+"''r2'"
$r6=r1-
+r6
$s2=s2-
-
-"''ESC$'''r1'B"--
"''ESC$'''r7'"--
"''ESC$'''r6'"
$goto -
11$
$endif
$-
ver$ver=4
$v$v="e"
$return
$18$:
$if -
(f$length-
(s2)*ver$ver).-
g'v$v'.-
f$len-
gth-
(p2)
$then -
goto -
13$
$else
$j=f$le-
ngth(s2)-1
$ods=f$ex-
tract-
(j,-
1,-
s2)
$if -
ods-
.nes."~"-
.and.-
ods.-
nes."`" -
then goto 13$
$s2=-
f$extract(0,-
j,s2)
$i=0
$16$:
$if -
(i/2).eq.((i+-
1)-
/2)
$then
$sl=4
$else
$sl=5
$endif
$s'sl'=-
s'sl'+f$-
extract-
(i,1,s2)
$i=i+1
$if -
i.lt.-
j then $ goto -
16$
$omi$reverse -
"''s4'"
$s4=-
omi$reversed
$delete-
e-
/symbol-
/global -
omi$reversed
$s5=f-
$extract(-
0,f$length-
(s5)-
--
1,s5)
$if -
ods-
.eqs."`" -
then -
$s5=f-
$extract-
(0,f-
$length(s5)-
-1,s5)
$'rt1'==s5+-
s4
$return
$endif
$12$:
$!
$	omi$signal omi ivencr
$	return omi$_error
$!
$ 13$:
$!
$	omi$signal omi decerr
$	return omi$_error
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	An imported older DCL routine which supposed to be unreadable; does
$!	some encryption (very rude, but it works till now).
$!	It reads the first parameter, encrypts it and returns the value in
$!	the global symbol OMI$ENCRYPTED.
$!
$ encrypt$:
$!
$	if p2 .eqs. ""
$	   then
$		omi$signal omi insarg,"OMI$ENCRYPT"
$		return omi$_error
$	endif
$s1=p2
$gosub -
27$
$gosub -
reverse$
$s5=-
omi-
$reversed
$delete-
e/symbol-
/global -
omi$reversed
$j=f-
$length-
(s1)
$if -
(j / -
2).eq.-
((j-
+1)/2)
$then -
$ods=-
%X60 
$else -
ods=%X7e
$endif
$j=-
(j-
/2)-
+1
$s8=""
$s1=-
f$ex-
tract(0,-
j,s1)
$s5=f-
$extract-
(0,j,-
s5)
$s2=-
"omi$encrypted"
$s3=""
$s4=""
$i=0
$s9=s8
$n=0
$gosub -
15$
$-
10$:
$c1=f-
$extract-
(i,1,s8)
$gosub -
30$
$i=i-
+-
1
$if -
i.eq.-
j*2!f$length(p2)
$then
$s9[i*8,8]=-
(ods+-
oac$)*vac$
$'s2'=-
=s9
$return
$endif
$goto -
10$
$30$:
$s9-
[i*8,-
8]=(f-
$cvui-
(0,8,-
c1)+-
oac$)*-
vac$
$return
$15$:
$s8=-
s8+f-
$ex-
tract-
(n,1,-
s5)+-
f$extra-
ct-
(n,1,-
s1)
$n=n+1
$if -
n.eq.j
$then
$return
$endif
$goto 15$
$27$:
$if p3.eqs.-
"".and.-
f$type(-
main$key).eqs.""
$then
$goto-
 -
28$
$return
$endif
$if p3-
.eqs.""
$then -
$_key=main$key
$else
$if f-
$type(-
keyring-
$'p3')-
.eqs.""
$then
$goto -
29$
$endif
$_key=keyring$'p3
$p3=""
$endif
$vac$=-
f-
$cvui(0,-
8,_key)
$oac$=f-
$cv-
ui-
(8,8,-
_key)
$return
$!
$ 28$:
$!
$	omi$signal omi nokey,'p1'
$	return omi$_error
$ 29$:
$!
$	omi$signal omi ivkey,'p3'
$	return omi$_error
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	This rouine checks the existance of the variable.
$!	It returns OMI$_WARNING if the variable is empty, and OMI$_ERROR
$!	if it doesn't exist.
$!	Parameter 'P1' specifies that this routine needs to be called, 'P2'
$!	should contain the parameter that needs to be checked, and 'P3'
$!	optionally contains the message that should be displayed on errors
$!	or warnings.
$!	'P4' can contain the value "EMPTY_ALLOWED" if the variable just has to
$!	exist.
$!
$ check$:
$!
$	if p2 .eqs. ""
$	   then
$		omi$signal omi insarg,"OMI$CHECK"
$		return omi$_error
$	endif
$!
$	if f$type('p2) .eqs. ""
$	   then
$		gosub chkreq$_message
$		return omi$_error
$	endif
$!
$	if 'p2 .eqs. ""
$	   then
$		if f$length(p4) .lt. 3 .or. f$edit(p4,"upcase") .nes. -
		   f$extract(0,f$length(p4), "EMPTY_ALLOWED") then -
		   $ gosub chkreq$_message
$		return omi$_warning
$	endif
$	return omi$_ok
$!
$ chkreq$_message:
$!
$	if p3 .eqs. "" then $ return
$	omi$display_message "''p3'"
$	return
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Handle the OMI$CONFIRM command that is defined for use in additional
$!	procedures. This routines returnes the value OMI$CONFIRMED, which can
$!	be true (1) or false (0).
$!
$ confirm$:
$!
$	if f$type(omi$confirmed) .nes. "" then $ delete\/symbol/global omi$confirmed
$!
$	_def = "(''questions$answer_yes'/''questions$answer_no') "
$	if p3 .nes. ""
$	   then
$		if f$edit(f$extract(0,f$length(questions$answer_yes),p3), -
		   "upcase") .eqs. f$edit(questions$answer_yes,"upcase")
$		   then
$			p3 = "Y"
$			_def = "([''questions$answer_yes']/''questions$answer_no') "
$		endif
$		if f$edit(f$extract(0,f$length(questions$answer_no),p3), -
		   "upcase") .eqs. f$edit(questions$answer_no,"upcase")
$		   then
$			p3 = "N"
$			_def = "(''questions$answer_yes'/[''questions$answer_no']) "
$		endif
$	endif
$	p2 = p2 + " " + _def
$!
$ confirm$_ask:
$!
$	read /end_of_file=confirm$_cancelled sys$command _answer -
	  /prompt="''ESC$'[''screen$line_command';''screen$default_position'H''p2'"
$	omi$msgline_clear
$	omi$cmdline_clear
$	if f$edit(f$extract(0,f$length(questions$answer_yes),_answer), -
	   "upcase") .nes. f$edit(questions$answer_yes,"upcase") .and. -
	   f$edit(f$extract(0,f$length(questions$answer_no),_answer), -
	   "upcase") .nes. f$edit(questions$answer_no,"upcase") .and. -
	   _answer .nes. ""
$	   then
$		omi$signal omi ivans,questions$answer_yes,questions$answer_no
$		goto confirm$_ask
$	endif
$	if _answer .eqs. ""
$	   then
$		if p3 .eqs. "Y" then $ omi$confirmed == 1
$		if p3 .eqs. "N" then $ omi$confirmed == 0
$		if p3 .eqs. ""
$		   then
$			omi$signal omi nodef
$			goto confirm$_ask
$		endif
$		return
$	   else
$		if f$edit(f$extract(0,f$length(questions$answer_yes),_answer), -
	   	   "upcase") .eqs. f$edit(questions$answer_yes,"upcase") then -
		   $ omi$confirmed == 1
$		if f$edit(f$extract(0,f$length(questions$answer_no),_answer), -
	   	   "upcase") .eqs. f$edit(questions$answer_no,"upcase") then -
		   $ omi$confirmed == 0
$		return omi$_ok
$	endif
$	
$ confirm$_cancelled:
$!
$	omi$signal omi inpreq
$	omi$cmdline_clear
$	goto confirm$_ask
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Handle the OMI$ASK command that is defined for use in additional
$!	procedures. This routines returnes the value OMI$RESPONSE, which
$!	contains the user response on the question that will be prompted.
$!	If the user entered <Ctrl/Z>, OMI$RESPONSE will be defined empty.
$!	The question is specified in P2. If P2 is not specified, the value
$!	specified in as 'default_input' from the '[questions]' section in
$!	the configuration file will be used.
$!
$ ask$:
$!
$	if p2 .eqs. "" then p2 = "''questions$default_input': "
$!
$ ask$_ask:
$!
$	read /end_of_file=ask$_cancelled sys$command _answer -
	  /prompt="''ESC$'[''screen$line_command';''screen$default_position'H''p2'"
$	omi$msgline_clear
$	omi$cmdline_clear
$	if _answer .eqs. "" then $ goto ask$_ask
$	omi$response == "''_answer'"
$	return omi$_ok
$!
$ ask$_cancelled:
$!
$	omi$response == ""
$	return omi$_cancelled
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Handle the OMI$INPUT_VALIDATE command, which handles a bug pointed to
$!	by Henry Juengst.
$!
$ input_validate$:
$!
$	if f$type(omi$variable) .eqs. ""
$	   then
$		omi$signal omi insarg,"OMI$INPUT_VALIDATE"
$		return omi$_error
$	endif
$	if .not. omi$_debug then -
	   $ set message /nofacility /noseverity /noidentification /notext
$	if f$locate("'"+"'", 'omi$variable') .lt. f$length('omi$variable')
$	   then $ _stat_on_fail = omi$_error
$	   else
$		if f$locate("'", 'omi$variable') .lt. f$length('omi$variable') -
		   then $ _stat_on_fail = omi$_warning
$	endif
$	if f$type(_stat_on_fail) .eqs. "" then $ return omi$_ok
$	first_quote = f$locate("'", 'omi$variable')
$	_string = 'omi$variable' - "'" - "'" - "'"
$	_string = f$extract(first_quote, f$length(_string) - first_quote, _string)
$!
$	on warning then $ goto string$valid_failed
$	_status = omi$_ok
$	if f$type('_string') .eqs. "" then $ _status = _stat_on_fail
$	on warning then $ continue
$	return '_status
$!
$ string$valid_failed:
$!
$	on warning then $ continue
$	return '_stat_on_fail
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Handle the OMI$WAIT command, where OMI waits for the user to press
$!	<Return>.
$!
$ wait$:
$!
$	if omi$batch_mode then $ return omi$_ok
$	read /end_of_file=wait$_cancelled sys$command _dummy -
 	   /prompt="''ESC$'[''screen$line_command';''screen$default_position'H''ESC$'[?25l''questions$wait_prompt' "
$	omi$msgline_clear
$	omi$cmdline_clear
$	write sys$output "''ESC$'[?25h"
$	return omi$_ok
$!
$ wait$_cancelled:
$!
$	write sys$output "''ESC$'[?25h"
$	omi$msgline_clear
$	omi$cmdline_clear
$!	if omi$_verify then $ set verify
$	return omi$_cancelled
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Check the required values for on-the-fly menus, and call it if ok.
$!
$ create_otf$:
$!
$	assign sys$scratch:omi$check_otf_menu._tmp$ sys$output
$	show symbol otf_menu$*                      
$	deassign sys$output
$	purge /nolog /noconfirm /keep=1 sys$scratch:omi$check_otf_menu._tmp$
$!
$	_status = "omi$_ok"
$	assign nla0: sys$output
$	search sys$scratch:omi$check_otf_menu._tmp$ "otf_menu$"
$	if $status .eq. omi$_nomatch .and. _status .eqs. "omi$_ok" -
	   then $ _status = "NO_OTF"
$!
$	search sys$scratch:omi$check_otf_menu._tmp$ "$item"
$	if $status .eq. omi$_nomatch .and. _status .eqs. "omi$_ok" -
	   then $ _status = "NO_OTFITM"
$!
$  !	search sys$scratch:omi$check_otf_menu._tmp$ "$input"
$  !	if $status .eq. omi$_nomatch .and. _status .eqs. "omi$_ok" -
   !!	   .and. f$type(otf_menu$no_inputs) .eqs. "" -
   !	   then $ _status = "NO_OTFINP"
$!
$  !	search sys$scratch:omi$check_otf_menu._tmp$ "#submenu#"
$  !	if $status .ne. omi$_nomatch .and. _status .eqs. "omi$_ok" -
   !	   then $ _status = "OTFSUB"
$!
$	deassign sys$output
$!
$	if _status .nes. "omi$_ok"
$	   then
$		omi$signal omi '_status
$		return $status
$	endif
$!
$	omi$saved_current_menu	= omi$current_menu
$	omi$current_menu = "otf_menu"
$	if f$type(otf_menu$security_level) .eqs. "" then -
	   $ otf_menu$security_level == 2
$	if f$type(otf_menu$title) .eqs. "" then -
	   $ otf_menu$title == "OMI - On The Fly menu"
$	@Omi$:Omi$Menu
$!
$	omi$current_menu = omi$saved_current_menu
$	omi$screen menu
$	omi$cmdline_clear
$	omi$msgline_clear
$!
$	open /read otf_cleanup sys$scratch:omi$check_otf_menu._tmp$
$!
$ otf$_cleanup:
$!
$	read /end_of_file=otf$end_cleanup otf_cleanup otf_symbol
$	otf_symbol = f$edit(f$element(0,"=",otf_symbol),"collapse")
$	if f$type('otf_symbol') .nes. "" then -
	   $ delete\ /symbol /global 'otf_symbol'
$	goto otf$_cleanup
$!
$ otf$end_cleanup:
$!
$	close otf_cleanup
$	if f$type(otf_menu$security_level) .nes. "" then -
	   $ delete\ /symbol /global otf_menu$security_level
$	if f$type(otf_menu$title) .nes. "" then -
	   $ delete\ /symbol /global otf_menu$title
$	delete\ /nolog /noconfirm sys$scratch:omi$check_otf_menu._tmp$;
$	return omi$_ok
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Translate a status code to an VMS message and return it in
$!	OMI$VMS_MESSAGE
$!
$ get_vmsmessage$:
$!
$	if p2 .eqs. ""
$	   then
$		omi$signal omi insarg,"OMI$GET_VMSMESSAGE"
$		return omi$_error
$	endif
$!
$	if f$type(p2) .eqs. "STRING"
$	   then
$		p2 = p2 - "%x" - "%x"
$		p2 = "%x''p2'"
$	endif
$!
$	if f$type(p2) .nes. "INTEGER"
$	   then
$		omi$signal omi intonly
$		return omi$_error
$	endif
$	omi$vms_message == "%OMI-I-NOVMSMSG, no VMS message found for status ''p2'"
$!
$ vmsmsg$scan_files:
$!
$	_msg_file = f$search("sys$message:*msg*.exe;")
$	if _msg_file .eqs. "" then $ return omi$_warning
$!
$	if f$parse(_msg_file,,,"name") .eqs. "DDIF$VIEWMSG" then -
	   $ goto vmsmsg$scan_files 
$	set message '_msg_file
$	_message = f$message('p2')
$	if f$locate("-NOMSG",_message) .eq. f$length(_message)
$	   then
$		omi$vms_message == "''_message'"
$		return omi$_ok
$	endif
$	goto vmsmsg$scan_files 
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	Handle the OMI$SIGNAL command, which writes a message to the
$!	OMI message line.
$!
$ signal$:
$!
$	_signal_retval = omi$_ok
$	_facil = p2
$	_ident = f$fao("!15<!AS!>",f$element(0,",",p3))
$	open /read /error=sgn$_no_mnu_msgfile messages -
	   Omi$Menu_Directory:'_facil'$messages.dat
$!
$ sgn$_no_mnu_msgfile:
$!
$	open /read /error=sgn$_no_msgfile messages Omi$:'_facil'$messages.dat
$	read /key="''_ident'" /error=sgn$_no_message messages _message 
$	close messages
$	_ident = f$edit(_ident, "collapse")
$	_sever = f$extract(15, 1, _message)
$	_text  = f$extract(17, f$length(_message) - 17, _message)
$	if _sever .eqs. "W" then $ _signal_retval = omi$_warning
$	if _sever .eqs. "E" .or. _sever .eqs. "F" then -
	   $ _signal_retval = omi$_error
$	_s_cnt = 1
$!
$ sgn$_vars:
$!
$	if f$element(_s_cnt, ",", p3) .nes. "" .and. -
	   f$element(_s_cnt, ",", p3) .nes. ","
$	   then
$		_subst = f$element(_s_cnt, ",", p3)
$		on warning then $ goto sgn$_nosymbol
$		set message /noidentification /noseverity /nofacility /notext
$		if f$type('_subst') .nes. ""
$		   then
$			_subst = '_subst'
$		endif
$!
$	 sgn$_nosymbol:
$!
$		set message 'omi$_message
$		on warning then $ continue
$		omi$substitute "~S" "''_subst'" "''_text'"
$		_text = omi$substituted
$		_s_cnt = _s_cnt + 1
$		goto sgn$_vars
$	endif
$!
$	_message = "%"
$	if f$locate("/FACILITY", omi$_message) .lt. f$length(omi$_message)
$	   then
$		_message = _message + _facil
$	endif
$!
$	if f$locate("/SEVERITY", omi$_message) .lt. f$length(omi$_message)
$	   then
$		if _message .nes. "%" then $ _message = _message + "-"
$		_message = _message + _sever
$	endif
$!
$	if f$locate("/IDENTIFICATION", omi$_message) .lt. f$length(omi$_message)
$	   then
$		if _message .nes. "%" then $ _message = _message + "-"
$		_message = _message + _ident
$	endif
$!
$	if f$locate("/TEXT", omi$_message) .lt. f$length(omi$_message)
$	   then
$		if _message .nes. "%"
$		   then
$			_message = _message + ", "
$			_message = _message + _text
$		   else
$			_message = _text
$			_message[0,1] := "''f$edit(f$extract(0, 1, _message), "upcase")'"
$		endif
$	endif
$!
$	if _message .eqs. "%" then $ _message = "" 
$	if f$type(omi$display_message) .eqs. ""
$	   then $ write sys$error _message
$	   else $ omi$display_message "''_message'"
$	endif
$	return _signal_retval
$!
$ sgn$_no_msgfile:
$!
$	if f$search("Omi$:Omi$Messages.Dat") .eqs. ""
$	   then $ omi$display_message -
		   "%OMI-E-NOMSGFILE, no OMI message file found"
$	   else $ omi$signal omi nomsgfile,_facil
$	endif
$	return omi$_error
$!
$ sgn$_no_message:
$!
$	_status = $status
$	close messages
$	if _status .eq. %X18644
$	   then
$		omi$display_message -
		   "%OMI-F-BADMSGFIL, message file corrupt - please repair"
$		return omi$_error
$	endif
$	_ident = f$edit(_ident,"collapse")
$	omi$signal omi nomessage,'_ident'
$	return omi$_warning
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	The Omi$Submit command; this command starts an OMI module in the
$!	the background as a batch process.
$!
$ submit$:
$!
$	if p2 .eqs. ""
$	   then
$		omi$signal omi insarg,"OMI$SUBMIT"
$		return omi$_warning
$	endif
$!
$	omi$background_module = "''p2'"
$	omi$background_mode = "batch"
$	omi$call omi$background_module
$	return $status
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	This routine replaces the substring in the first argument with the
$!	substring in the second argument in the third argument.
$!
$ substitute$:
$!
$	if p2 .eqs. "" .or. p3 .eqs. "" .or. p4 .eqs. ""
$	   then
$		omi$signal omi insarg,"OMI$SUBSTITUTE"
$		return omi$_warning
$	endif
$      	_subst_location = f$locate(p2, p4)
$	_input_size     = f$length(p4)
$	if _subst_location .eq. _input_size then $ return omi$_warning
$!
$	_subst_size = f$length(p2)
$	_return_2   = f$extract(_subst_location + _subst_size, -
	   _input_size - (_subst_location + _subst_size), p4)
$	omi$substituted == f$extract(0, _subst_location, p4) + p3 + _return_2
$	return omi$_ok
$!
$!******************************************************************************

$!******************************************************************************
$!
$!==>	This routine is called when OMI exits. It checks for all global
$!	symbols that might have been set by any of the tools, and removes them.
$!
$ cleanup$:
$!
$	if f$type(omi$calculated) .nes. "" then -
	   $ delete\ /symbol /global omi$calculated
$	if f$type(omi$confirmed) .nes. "" then -
	   $ delete\/symbol/global omi$confirmed
$	if f$type(omi$daynumber) .nes. "" then -
	   $ delete\ /symbol /global omi$daynumber   
$	if f$type(omi$weeknumber) .nes. "" then -
	   $ delete\ /symbol /global omi$weeknumber  
$	if f$type(omi$monthnumber) .nes. "" then -
	   $ delete\ /symbol /global omi$monthnumber 
$	if f$type(omi$reversed) .nes. "" then -
	   $ delete\ /symbol /global omi$reversed
$	if f$type(omi$decrypted) .nes. "" then -
	   $ delete\ /symbol /global omi$decrypted
$	if f$type(omi$encrypted) .nes. "" then -
	   $ delete\ /symbol /global omi$encrypted
$	if f$type(omi$response) .nes. "" then -
	   $ delete\ /symbol /global omi$response
$	if f$type(omi$substituted) .nes. "" then -
	   $ delete\ /symbol /global omi$substituted
$	if f$type(omi$vms_message) .nes. "" then -
	   $ delete\ /symbol /global omi$vms_message
$!
$	if f$type(Omi$Open_Mailbox_List) .eqs. "" then -
	   $ goto cleanup$end_mailboxes
$	_mbx_count = 0
$!
$ cleanup$_mailboxes:
$!
$	_open_mailbox = f$element(_mbx_count, "#", Omi$Open_Mailbox_List)
$	if _open_mailbox .eqs. "#" .or. _open_mailbox .eqs. ""
$	   then
$		delete\ /symbol /global Omi$Open_Mailbox_List
$		goto cleanup$end_mailboxes
$	endif
$!
$	if f$type('_open_mailbox') .nes. "" then -
	   $ delete\ /symbol /global '_open_mailbox'
$	if f$trnlnm("''_open_mailbox'") .nes. "" then $ close '_open_mailbox'
$!
$	_mbx_count = _mbx_count + 1
$	goto cleanup$_mailboxes
$!
$ cleanup$end_mailboxes:
$!
$	return omi$_ok
$!
$!******************************************************************************
