Feral Linux Scripts
======

This repository allows public access to the latest versions of some of the scripts used by Feral Interactive games on Linux.

Issues
------

We spend a good deal of time trying to make sure our games will work on a wide variety of Linux distributions, but some issues may still occur. Feel free to use the Issues tracker in this repository to report any problems that we can fix by making adjustments to these scripts or, alternatively, submit a pull request.

Any other general issues with Feral games should, as always, be reported directly to support@feralinteractive.com.

Scripts
------

### sysreport.sh

This is a fairly simple zero dependency (except bash) system report script that gathers information about the local system, installed games and game preferences. It outputs a file in HTML syntax.

Our games use this script when "Generate Report" is clicked on the SUPPORT tab of the options window.

Usage looks like:

```bash
./sysreport.sh "/path/to/game/install" "/path/to/outputfile.html"
```

### gamelaunchscript.template.sh

This is the template we use for our game launch scripts. It allows us to fix up the environment as needed to assist with running our games on a wide variety of Linux distributions.

It requires a configuration script

* config/game-settings.sh - To set up some game specific configuration variables

And optionally uses a set of other helper scripts that may be different per game

* config/steam-check.sh - Used to check if the game is launched in the steam runtime
* config/game-chooser.sh - Allows choosing which game binary to launch in some cases
* config/extra-environment.sh - Used to set any extra environment variables

License
------

All scripts here, unless otherwise stated, are licensed under the MIT license as shown below

> The MIT License (MIT)
>
> Copyright (c) 2017 Feral Interactive Limited
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
> 
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
