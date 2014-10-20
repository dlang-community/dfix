# dfix

Tool for automatically upgrading D source code

## Features

* Updates old-style alias syntax to new-style
* Fixes implicit concatenation of string literals
* Automatic conversion of C-style array declarations and parameters to D-style.
* Upgrades code to comply with DIP64 when the ```--dip64``` switch is specified.
* Upgrades code to comply with DIP65 when the ```--dip65``` switch is specified.

## Planned Features

* Movement of function attributes from the left side of the function name to the
right.

## Notes

dfix will edit your files in-place. Do not use dfix on files that have no
backup copies. Source control solves this problem for you. Double-check the
results before checking in the modified code.
