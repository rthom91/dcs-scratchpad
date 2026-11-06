-- Help text for the Apit help button. Loaded on demand.
helper = [=[
# aeronautes-pit (Apit)

This is an extension to github.com/rkusa/scratchpad for DCS. At a high
level it provides the ability to configure your aircraft, assist with
mission planning and other automation tasks. There are some features
for specific capabilities, such as single button latlong input, as
well as a generalized environment for cockpit customization. At a low
level this extension provides a system to create, modify and execute
Lua code and access DCS's Lua client API. Some convenience features
provided on top of DCS's macro system let you interact with all the
buttons, dials, switches and controls in the cockpit without having to
look up the macro details. You can use this without any knowledge of
Lua or typing in any commands using its base functionality available
as button clicks. If you want to do more, then modifying or creating
Lua code is an option.

## Installation

Unzip the github download into your Windows user Saved Games
directory. In order to enable an extension in scratchpad, the
extension Lua file must be present in
Saved Games\DCS\Scripts\Scratchpad\Extensions\. Copy the
aeronautes-pit.lua file from Scripts\Scratchpad\Extensions\Disabled\
to the parent Scripts\Scratchpad\Extensions\ directory.

- Required file - aeronautes-pit.lua is necessary for base
functionality. This needs to be copied from
Scripts\Scratchpad\Extensions\Disabled\ to the parent Extensions\
directory. On the next start of DCS you should see the apit menu
buttons when the scratchpad window is open. This is how scratchpad
enables extensions.

- Optional files - For each DCS module an optional customization file,
such as F-16C_50.lua, is searched for when slotting into the
aircraft. Generally these are input commands that are grouped into
functions. Examples of functions include 'start' to start the
aircraft or 'mfd' to configure MFD pages. If no file is found,
base apit functionality is still available. These files are searched
for in Scripts\Scratchpad\Extensions\aeronautes\modules\

- Scratchpad page aeronautes-pit.txt is created in
Saved Games\DCS\Scratchpad if it does not exist on DCS startup.
Because the extension creates the file after scratchpad starts you
will need to reload pages using the scratchpad reload key bind
(ctrl-shift-r). If the file already exists you won't need the reload.
This page is used when Apit needs to display text. For example when
the user clicks on buttons such as log or mod, the content of those
overwrite the aeronautes-pit page. You should not put anything onto
this page that you want to keep around. That said the last contents
of this page are saved to file when scratchpad switches to another
page. You can go into the Scratchpad\pages\ directory and copy that file
if it has something you want to keep.

## Feature/Module matrix

This matrix shows apit features and the amount of DCS modules
supported by each.

| Feature       | All | Subset | Note |
| ------------- | --- | ------ | ---- |
| DCS macros    |  X  |        |  1   |
| Convenience   |  X  |        |  2   |
| Lua/DCS API   |  X  |        |  3   |
| Waypoint      |     |   X    |  4   |
| Customization |     |   X    |  5   |

- 1. Automatic detection and configuration of devices[] and
device.actions[] defined in the modules Cockpit\Scripts
directory. Specifically API calls push_start_command() and
push_stop_command() and their necessary arguments. These are
automatically handled for any full fidelity module installed without
need for user configuration.
* All modules supported.

- 2. Convenience functions allow access to the cockpit devices without
having to look up the codes in Lua. Instead you can use the tool
tips to refer to the buttons and switches. These API calls include
tt(), ttt(), etc. It's automatically configured based on the
module's Cockpit\Scripts\clickabledata.lua.
* All modules supported, paid or community, provided the module
includes a working clickabledata.lua.

- 3. DCS APIs as defined in DCS World\API\DCS_ControlAPI.html
are available. The level of functionality and support is entirely up
to ED. Lua is executed in a scratchpad page with the Buf or Sel buttons.
* All modules supported.

- 4. Waypoint functions provide the ability to input latlong and certain
other input without having to know or program which specific buttons
to press. These have been adapted for specific aircraft as each one
has its own particular sequence of input. The API for this includes
wp(), wpseq(), press() and the UI buttons LatLon and wp.

* Waypoint input is currently supported for A-10C, AV-8B, CH-47,
F-15E, F-16C, FA-18C, Hercules (Anubis), Ka-50_3, OH-58.

- 5. Customizations are higher level capabilities that utilize any
combination of the above features. These are separated per module in
the Scripts\Scratchpad\Extensions\aeronautes\modules\ directory. The level of
support and functions vary by module as apit updates are made. You
can modify these yourself to make your own customizations for your
aircraft. They can be utilized by clicking on the function buttons,
1, 2, ...

* Customizations are provided for A-10C, AV8, CH-47, F-15E, F-16C,
FA-18C, Hercules (Anubis), Ka-50_3, Mi-8, Mi-24, OH-58, Combined Arms and
Global (applies to all modules).

## UI

The UI is comprised of the scratchpad buffer with the same name as
the extension, aeronautes-pit. This buffer is used to display
information such as module specific notes and custom lua or to
show the help information. Anything in this buffer should not be
considered permanent as the contents can be overwritten. If you
want to save anything then place it in one of the other
buffers. The UI also includes several rows of buttons. The first
row contains buttons that interact with the cockpit or execute lua
directly. The second row of buttons may output to the scratchpad
buffer but do not affect the cockpit systems. The third and fourth
rows of buttons are module specific functionality. The current
module that you are slotted as is labeled as the left most button
of the third row. Generically this is the mod button but can be
for example Hercules or F-16C_50. The fourth row are dynamic
buttons that are each associated with a module specific
function. These functions are defined in the module customization
file. The contents of the file can be viewed by pressing the mod
button. Whenever apit is processing some lua the mod button will
display a progress spinner. The progress spinner will indicate the
current state of system input with the following symbols:

- -\|/ any instance of the lines represents a rotating bar and
indicates the system is processing some input.

- D capital D indicates delay() was called. Once the amount of
time requested for delay has passed the spinner should change to
one of the previous indicators.

Button labels that are capitalized will cause some type of input
to the cockpit: LatLon, Sel, Buf, Cancel. Those without
capitalization do not cause cockpit input.

- LatLon - Using the camera's current location, the latlong is
entered into the aircraft's coordinate input system. In F10 map view
this is the location at the center of the screen. In any other view,
cockpit or external, it is the 3d location of the camera
position. This button will be visible only for modules that are
supported and hidden for those that are not. Some aircraft may have
prerequisites before using LatLon. For example, F-18 currently
requires Precise coordinates enabled. Per module notes should
describe these requirements and are viewable by pressing the button
labeled with the name of the module, eg Hercules, F-16C_50. The
default behavior upon click is for the sequencer to increment the
current waypoint and enter latlong. The next click will carry out
the same steps. You can modify this behavior using the wpseq()
function (see below). You can also disable wpseq() to prevent any
waypoint number change, leaving it up to you to set the correct
number.

- Sel - This will take the current text selection as Lua. If no text
is selected, then the current line the cursor is on is
executed. This is a convenience feature to handle single line
commands without the need to carefully highlight the line.

This also has an added feature of detecting if the current line or
selection matches a DDM coordinate and will automatically enter the
latlong into the aircraft's input panel if available. The format of
the coordinate must be L NN°NN.NNN', L NNN°NN.NNN'. L = letter, N =
number, single quote is optional, degree symbol can be replaced with
one or more spaces. Altitude is not currently supported since the
scratchpad +L/L is not the same across all modules. The format
varies among the aircraft.

- Buf - This will attempt to execute everything in the current
scratchpad page as a Lua script.

- Cancel - If the system is processing a series of cockpit inputs,
this will stop and cancel any outstanding inputs remaining. If you
reslot in the middle of a sequence, it will be canceled.

- wp - This works similarly to LatLon, but instead of directly entering
the latlong, it will print the equivalent wp() command at
the current cursor location in scratchpad. This is useful for
building a mission plan that can be reused or passed along.

- mod - scratchpad will switch to the page named aeronautes-pit and
overwrite the page with a copy of the module customization
file. This is useful to see the module specific aeronautes-pit
documentation as well as the code for the customization. This is
useful if you want to see the startup sequence in checklist form,
for example. The name of this button will change based on which
module you have slotted into. Also this button will show a progress
spinner when the extension is processing commands.

- modload - Convenience and customization code for the current
aircraft are immediately reloaded and made available. This is useful
if you are modifying or adding apit Customization files
(Extensions\aeronautes\modules), or if you have messed up certain values from a
scratchpad page and want to reset using Customization file values.
Module-specific buttons only appear after you are slotted into an
aircraft. Clicking modload with no unit type only reloads Globalcustom.

- log - aeronautes-pit keeps a log of its execution in a buffer.
Clicking this button switches to the scratchpad page aeronautes-pit
and overwrites it with the log.

- loglvl - This is used to change the debug level of apit
logging. Each click changes the button label to indicate the level
with a rollover to zero after 9.

- help - This will overwrite the aeronautes-pit scratchpad page with
a copy of this help text (loaded from helper.lua).

- 1, 2,... - These dynamic function buttons provide one-click
access to functions defined in the per module customization files in
Scratchpad\Extensions\aeronautes\modules\<module>.lua. The button titles
will match the name of the function. The number of buttons will vary
based on how many functions are defined in the associated Lua custom
file. The first row of buttons below modload are indented and
specifically for the loaded module. The second row of buttons below
modload are for functions defined in Globalcustom.lua. These exist
no matter what module is loaded.

## apit API

The Lua functions provided by apit are as follows:

- push_start_command(int, {table}), push_stop_command() these
calls are exactly the same format as those defined by ED and
used in Macro_sequences.lua (the autostart/stop) for each
aircraft. It doesn't matter which you use, start or stop. They
perform the same. Apit currently supports a subset of the
capability, devices, actions, delays, enough to manipulate
cockpit elements. It does not support conditionals that are
defined in module DLL. Any unsupported calls are ignored. This
means you should be able to take the modules Macro_sequences.lua
and use them directly in apit. The F-16 apit customization
function fence is built this way.

Example for F16:

push_stop_command(dt, {device = devices.ECM_INTERFACE, action = ecm_commands.PwrSw, value = 1.0})
push_stop_command(dt, {device = devices.ECM_INTERFACE, action = ecm_commands.XmitSw, value = -1.0})

- wp('string') enters a latlong into the modules keypad interface if
available. It takes a string comprised of characters that
correlate to device/actions used in push_stop_command(). The
character mapping can be seen in the kp[] table.

Example for F16:
--janatabad
wp('N 2814775edE 05638257ed3569')
wp('N 3015749edE 05657384ed5746') --kerman rwy

- wpseq({table}) interface for setting the next steerpoint number.
Param is a table with any number of the following members. Default
values in parens (). Generally the default behavior upon click
of the LatLon button is to increment the current waypoint, input
latlong and stop. The next click will do the same,
increment/enter LL/stop.

* initialize = true/false (false) -- boolean that causes seq
to default values

* enable = true/false (true) -- disables sequencing while
inputting latlongs

* diff = number (1) -- the value to increment, can be negative
or positive number. Zero will prevent any change of waypoint
number while inputting. Zero value is useful if you want to
manage the assignment of waypoint number yourself

* cur = number (-1) -- this sets the starting waypoint number
when wpseq() is executed. After that it will be changed by the
value of diff member if nonzero. Negative one, -1, will
prevent wp() from attempting to set the starting wp, but
will apply diff each time. You can set this to any value
that is valid for the aircraft you are slotted in (F15 max
99, F16 max 699). Behavior is determined in the LT[] table.

* route = string ('') -- if the aircraft has a route naming
aside from waypoint number, this member can be used to add
the current to indicate the waypoint and route you want to start
at and increment/decrement next. Valid values are taken from
the kp[] table for the particular DCS module (unittype). For
example F15 has A,B,C,D.

* menus = string ('') -- if you want to add extra inputs in
the UFC/ICP of the aircraft you are in before the latlong
entry. The values are derived from the kp[] table and the same
as those used for press()

Example:
wpseq({initialize=true}) -- reset values to default
wpseq({enable=false}) -- disables any sequencing of subsequent waypoints

sets the next instance of LatLon or wp() to set the waypoint to
3.A, enter the latlong. After that the next waypoint will be
incremented and entered (4.A):

wpseq({cur=3, diff=1, route='.A'})

- press('string') lets you press an arbitrary sequence of buttons
as defined in the kp table. press() can also be used to schedule
functions during the input of controls. This is useful when
combined with the DCS api library to create conditional
behavior. See Extensions\aeronautes\modules\F-15ESE customization to see how
engines are spooled up using this.

Example:

enters 7.A in F15 scratchpad followed by push of UFC button 1:

press('7.Aa')

schedules the Customization function 'start' to run with
argument 'engspool' after 1 second. This applies to F15E

press('',{delay=1,fn=ft['start'],arg='engspool'})

- tt('string') interface to cockpit interface associated with a tool tip

- ttn('string') tool tip on, equivalent to tt(,{value=1})

- ttf('string') tool tip off, equivalent to tt(,{value=0})

- ttt('string') tool tip toggle, equivalent to ttn() ttf()

- delay(number) delay in input for the scheduled sequence

- loglocal('string', [number]) log message to the Logs\Scratchpad.log file

- switchPage(pagename) When no argument is passed, returns a page
record of the current page of scratchpad. Otherwise pagename is the
full path and filename of the scratchpad page you want to load,
Saved Games\DCS\Scratchpad\pages\<name>.txt. Returns nil on failure.

- setitval(number) sets the base time interval in seconds between
cockpit inputs. If you find some of your inputs are getting lost
then you can start by extending this time until all your inputs
are received. This time applies to all inputs. Some inputs can
have extra time added per the kp[] table. Default .1 seconds

Example:
setitval(.2)
loglocal(itval) -- to see value of itval in Scratchpad.log

- unittab[]

## Supported API

Other APIs provided through apit:

- scratchpad

- DCS Lua environment -
See C:\Program Files\Eagle Dynamics\DCS World\API

## Howto/FAQ

- Where are apit logging messages? Apit sends messages to the
scratchpad log located in
Saved Games\DCS\Logs\Scratchpad.log. You can monitor this file
by opening a powershell window, cd into the Logs directory and run
this command, "Get-Content .\Scratchpad.log -wait". This will update
as the file is written to.

- How to change log level? You can press the loglvl button to set
the logging level. This is intended for users who are not able
to run the loglevel() function. Or you can run this command in a
scratchpad page: "loglocal('',{debug=5})" while setting the 5 to any
number you want. Generally zero 0 up to 9 for increasing verbosity
is typical.

- How can I see the wpseq() settings? The waypoint sequencer values
can be viewed when setting a value. If you just want to see current
settings, invoke wpseq() with no members, "wpseq({})". The results
will be logged to Scratchpad.log.

- Why are module buttons missing? Module-specific customizations
only load after you slot into an aircraft. If you click modload
before slotting, only Globalcustom functions are reloaded.
Globalcustom.lua itself loads even without a unit type.

## Acknowledgements

- https://github.com/rkusa for building a great platform and making it open source
- https://www.twitch.tv/aurora_juutilainen for early testing and feedback
- https://github.com/aronCiucu/DCSTheWay for insight into performClickableAction()
- hoggit #scripting discord a useful resource for anyone developing for DCS
- https://github.com/asherao bailey's example of using setText() for panel widgets

]=]
