# dfix

Tool for automatically upgrading D source code

## Features

* Updates old-style alias syntax to new-style
* Fixes implicit concatenation of string literals
* Automatic conversion of C-style array declarations and parameters to D-style.
* Upgrades code to comply with DIP64 when the ```--dip64``` switch is specified. (Not recommended)
* Upgrades code to comply with DIP65 unless the ```--dip65=false``` switch is specified.
* Rewrites functions declared ```const```, ```immutable``` and ```inout``` to be more clear by moving these keywords from the left side of the return type to the right side of the parameter list.

## Notes

dfix will edit your files in-place. Do not use dfix on files that have no
backup copies. Source control solves this problem for you. Double-check the
results before checking in the modified code.
