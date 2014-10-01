# dfix

Tool for automatically upggrading D source code

## Features

* Updates old-style alias syntax to new-style
* Fixes implicit concatenation of string literals
* Replaces uses of the catch-all syntax with an explicit "catch (Throwable)"

## Notes

dfix will edit your files in-place. Do not use dfix on files that have no
backup copies. Source control solves this problem for you. Double-check the
results before checking in the modified code.
