OMI v2.5 - (c) 1997-2019, Oscar van Eijk, Oveas Functionality Provider
======================================================================

Oscar's Menu Interpreter is a DCL procedure that reads menu files and
represents the menu structure on a ChUI based window.

OMI does not perform any actions on its own. Additional procedures
are required to handle upon the users input. OMI is strictly created
to create a standard user interface for all kinds of actions, with a
clear structure, support for different security levels and password
protection.

The additional procedures that are required for any actions are
referred to 'callable jobs'. A section in the help file describes
how several commands, defined in OMI, can be used to create such
procedures.

Documentation and support
-------------------------
Full documentation for OMI can be found at GitHub:
https://github.com/oveas/OMI.
An online HELP is also provided, but since v2.0 the printable documentation
is completely reviewed. This has not (yet?) been done with the online
HELP, except for the interactive OMI command section.

GitHub also offers a  tracker (https://github.com/oveas/OMI/issues)
where you can get support.
Please note OMI comes without any warranty, but I'll try to give as much
support as possible via this forum.

Installation instructions
-------------------------
To install OMI, download one of the distributions: either
the ZIP file (download in BINary format) or the COM file
(download in ASCII format).
Also, download OMI$INSTALL.COM in ASCII format.

Next, set default to the directory where the installation
script is located, and issue the command:
$ @OMI$INSTALL

Follow the instruction to install OMI.
The procedure extracts the distribution and moves all
files to the desired location (that you will be prompted for).
Site specific files will not be overwritten.
If the file OMI$TOOLBOX.INI exists, it will be patched.

The installation procedure also creates the HELP library,
and repairs message datafiles, which have been corrupted
by the distribution.

If this is a new installtion, let all the users who will be
using OMI execute the procedure OMI$USER_INSTALL once.
This is not required for upgrades of existing OMI installations.

Installation is now complete. All users can optionally change
the behaviour of OMI by modifying the file OMI$MENU.CFG, located
in their SYS$LOGIN:.

To test OMI, you can use the example menu file OMI$EXAMPLE.MNU
which comes with this distribution. Start this menu with the command
OMI OMI$EXAMPLE.

This menu performs no other action than displaying information.
The 'Protected menu' is protected with the password "test123456789".
(Note: passwords are case sensitive!)

More information can be obtained from the online HELP and the documentation.
