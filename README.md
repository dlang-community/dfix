# dfix [![CI status](https://travis-ci.org/dlang-community/dfix.svg?branch=master)](https://travis-ci.org/dlang-community/dfix/)

Tool for automatically upgrading D source code

## Features

* Updates old-style alias syntax to new-style
* Fixes implicit concatenation of string literals
* Automatic conversion of C-style array declarations and parameters to D-style.
* Upgrades code to comply with DIP64 when the ```--dip64``` switch is specified. (Not recommended)
* Upgrades code to comply with DIP65 unless the ```--dip65=false``` switch is specified.
* Upgrades code to comply with DIP1003 unless the ```--dip1003=false``` switch is specified.
* Rewrites functions declared ```const```, ```immutable``` and ```inout``` to be more clear by moving these keywords from the left side of the return type to the right side of the parameter list.

## Notes

dfix will edit your files in-place. Do not use dfix on files that have no
backup copies. Source control solves this problem for you. Double-check the
results before checking in the modified code.

## Installation

OS X users with homebrew should be able to install via ```brew install dfix``` for the latest stable release or ```brew install dfix --HEAD``` for the latest git master branch.

Other users should manually install, e.g. on *nix systems:

* ```git clone https://github.com/Hackerpilot/dfix && git submodule update --init```
* ```cd dfix```
* ```git checkout v0.3.1``` if you want the stable release
* ```make``` to build
* ```make test``` to test
* either add the ```bin``` directory to your path or copy to another directory that is on your path.

### Installing with DUB

```sh
> dub fetch --version='~master' dfix && dub run dfix
```
