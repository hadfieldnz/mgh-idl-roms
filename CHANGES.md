# Change log for the IDL-ROMS Library

Mark Hadfield

IDL-ROMS is a library of IDL code written largely by me at NIWA for processing input and output from
the [ROMS ocean model](https://www.myroms.org/) and its siblings.. This document describes major and/or widespread changes to the
routines in the library. For a routine-specific change log, see the individual documentation headers.

Entries are in reverse chronological order (most recent first).

### *2019-05-01*

Added a class, MGHromsRegrid, to represent ROMS forcing files with longitude and latitude data, to be regridded
in ROMS. Moved the Lslice methods (recently added to MGHromsHistory and only partially implemented) to this class.

### *2018-08-06*

The library can now be installed with the new IDL Package Manager, to be bundled with IDL 8.7.1. Version 1.0 has been released.

### *2017-07-05*

The library is now stored in a Git repository and hosted at GitHub as
project [hadfieldnz/idl-roms](https://github.com/hadfieldnz/idl-roms).

### *2016-11-02*

Created the subdirectories san and roms and moved routines into them as appropriate.

### *2016-11-01*

Moved some 110 ROMS-related routines from my general NIWA library into MGH-ROMS. There are 88 left behind.
There's still quite a lot of work to do removing or resolving dependencies of the MGH-ROMS code on my general library.

Moved the MGH_SAN routines for generalised remote file access from my general NIWA library into MGH-ROMS.

### *2016-10-31*

Created project mgh-roms in Sourceforge, cloned it to my hard disk and added this file.
