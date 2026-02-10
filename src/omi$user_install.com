$	on control_y then $ goto user_abort
$	goto start$
$!
$!******************************************************************************
$!*                                                                            *
$!*  FILENAME:                                                                 *
$!*  =========                                                                 *
$!*     Omi$User_Install.Com  Create the userspecific OMI setup                *
$!*                                                                            *
$!*  DESCRIPTION:                                                              *
$!*  ============                                                              *
$!*      This tool installs OMI generated the userspecific setup procedure     *
$!*      and places the configurationfile in the user's login directory.       *
$!*                                                                            *
$!******************************************************************************
$!

$ start$:
$	omi_dir = f$environment("procedure")
$	omi_dir = f$parse(omi_dir,,,"device","no_conceal") + -
	   f$parse(omi_dir,,,"directory","no_conceal")
$	omi_dir = omi_dir - "]["
$	lgi_dir = f$trnlnm("sys$login") - "]["
$	mnu_dir = lgi_dir - "]" + ".OMI]"
$!
$ get_mnu_directory:
$	write sys$output "Where do you want to store your Menu files (*.MNU) ?"
$	read /prompt="[''mnu_dir']: " /end=user_abort sys$command mnudir
$	if mnudir .eqs. "" then $ mnudir = mnu_dir
$	if f$parse(mnudir) .eqs. ""
$	   then
$		read /prompt="Create this directory ? ([Y]/N) " /end=user_abort sys$command create_it
$		if f$edit(f$extract(0,1,create_it),"upcase") .eqs. "N" then $ goto get_mnu_directory
$		create /directory 'mnudir
$!		write sys$output "Copying the example files to ''mnudir'..."
$!		copy\ /log 'omi_dir'Omi$Example.*; 'mnudir
$	endif
$!
$	read /prompt="What will be your default printer ? [SYS$PRINT]: " -
	   /end=user_abort sys$command defprt
$	if defprt .eqs. "" .or. f$edit(defprt,"upcase") .eqs. "SYS$PRINT"
$	   then $ copy /log 'omi_dir'omi$menu.cfg 'lgi_dir'
$	   else
$		open /write make_config sys$scratch:omi$$mk_config._tmp$
$		write make_config "$ assign/user nla0: sys$output"
$		write make_config "$ assign/user sys$input sys$command"
$		write make_config "$ editt /edt /output=''lgi_dir' ''omi_dir'omi$menu.cfg"
$		write make_config "s/sys$print/''defprt'/w"
$		write make_config "exit"
$		write make_config "$ exit"
$		close make_config
$		@sys$scratch:omi$$mk_config._tmp$
$		delete\ /nolog /noconfirm sys$scratch:omi$$mk_config._tmp$;
$	endif
$!
$	open /write omi_setup 'lgi_dir'omi$setup.com
$!
$	write omi_setup "$!-----"
$	write omi_setup "$! This ommand procedure sets up the process environment for using"
$	write omi_setup "$! OMI, Oscar's Menu Interpreter"
$	write omi_setup "$! It was generated nu OMI$USER_INSTALL at ''F$Time()'"
$	write omi_setup "$!"
$	write omi_setup "$	omi :== @''omi_dir'OMI$WRAPPER.COM"
$	write omi_setup "$	_menu_dir  = ""''mnudir'"" - ""]"""
$	write omi_setup "$	_omi_menus = ""'","'_menu_dir']"""
$	write omi_setup "$!"
$	write omi_setup "$! All subdirectories of ''mnudir'"
$	write omi_setup "$! will be added to the OMI$MENU_DIRECTORY searchpath"
$	write omi_setup "$ omi$_build_list:"
$	write omi_setup "$!"
$	write omi_setup "$	 _sub_dir = f$search(""'","'_menu_dir']*.dir"")"
$	write omi_setup "$	if _sub_dir .eqs. """" then $ goto omi$end_build_list"
$	write omi_setup "$	_dir_name = f$parse(_sub_dir,,,""name"")"
$	write omi_setup "$	_omi_menus = _omi_menus + "",'","'_menu_dir'.'","'_dir_name']"""
$	write omi_setup "$	goto omi$_build_list"
$	write omi_setup "$!"
$	write omi_setup "$ omi$end_build_list:"
$	write omi_setup "$! Uncomment the following if more directories need to be added to the"
$	write omi_setup "$! OMI$MENU_DIRECTORY search list"
$	write omi_setup "$!	_omi_menus = _omi_menus + "",<Put the full path here>"""
$	write omi_setup "$!"
$	write omi_setup "$! Now the installation directory is added to OMI$MENU_DIRECTORY"
$	write omi_setup "$	_omi_menus = _omi_menus + "",''omi_dir'"""
$	write omi_setup "$!"
$	write omi_setup "$	define /nolog /job Omi$Menu_Directory	'_omi_menus'"
$	write omi_setup "$!"
$	write omi_setup "$! Use the following command if you want to start OMI with a default menu file."
$	write omi_setup "$! You can always overwrite this by using a parameter"
$	write omi_setup "$!	define /nolog OMI$StartMenu <Name of the menu file>"
$	write omi_setup "$!"
$	write omi_setup "$! By default, the menu file OMI$MENU.CFG in your SYS$LOGIN: will be used for"
$	write omi_setup "$! your personal configuration. If it's not there, the configuration file"
$	write omi_setup "$! from ''omi_dir' is used."
$	write omi_setup "$! You can also move and/or rename you personal config file, if you specify"
$	write omi_setup "$! the full path and filename below."
$	write omi_setup "$!	define /nolog OMI$Config    <Path and name of your configuration file>"
$	write omi_setup "$!"
$	write omi_setup "$! *** NOTE *** "
$	write omi_setup "$! The definition of OMI$SetupProcedure below should not be removed or modified!"
$	write omi_setup "$! It's required by OMI to work in background mode (detached or in batch)."
$	write omi_setup "$	_setup_proc = f$parse(f$environment(""procedure""),,,,""no_conceal"")-""][""""
$	write omi_setup "$	define /nolog /job OMI$SetupProcedure    '_setup_proc'"
$	write omi_setup "$!"
$	write omi_setup "$	write sys$error ""%OMI-S-SETUP, OMI environment succesfully initialized"""
$	write omi_setup "$	write sys$error ""-OMI-I-NEWCMD, the new command OMI has been defined"""
$	write omi_setup "$	exit"
$	write omi_setup "$!-----"
$	close omi_setup
$!
$	write sys$output ""
$	write sys$output "  The file OMI$SETUP.COM has been created in your LOGIN directory. To be able"
$	write sys$output "  to use OMI every time you log in, add the command"
$	write sys$output "    $ @SYS$LOGIN:OMI$SETUP.COM"
$	write sys$output "  to your LOGIN.COM"
$	write sys$output "  For modifications to the setup file, refer to the comments."
$	write sys$output ""
$!
$	@'lgi_dir'omi$setup
$	exit
$!
$ user_abort:
$	write sys$output "OMI Setup has been cancelled"
$	exit %X28
