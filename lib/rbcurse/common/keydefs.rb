# ----------------------------------------------------------------------------- #
#         File: keydefs.rb
#  Description: Some common keys used in app. Earlier part of rwidget.rb
#       Author: rkumar http://github.com/rkumar/rbcurse/
#         Date: 08.11.11 - 14:57
#      License: Same as Ruby's License (http://www.ruby-lang.org/LICENSE.txt)
#  Last update: 08.11.11 - 14:57
# ----------------------------------------------------------------------------- #
#

# some common definition that we use throughout app. Do not add more, only what is common.
# I should not have added Sh-F9 and C-left since they are rare, but only to show they exist.
#
KEY_TAB    = 9
KEY_F1  = FFI::NCurses::KEY_F1
KEY_F10  = FFI::NCurses::KEY_F10
KEY_ENTER  = 10 # FFI::NCurses::KEY_ENTER gives 343
KEY_BTAB  = 353 # nc gives same
KEY_RETURN = 13  # Nc gives 343 for KEY_ENTER
KEY_DELETE = 330
KEY_BACKSPACE = KEY_BSPACE = 127 # Nc gives 263 for BACKSPACE
KEY_CC     = 3   # C-c
KEY_LEFT  = FFI::NCurses::KEY_LEFT
KEY_RIGHT  = FFI::NCurses::KEY_RIGHT
KEY_UP  = FFI::NCurses::KEY_UP
KEY_DOWN  = FFI::NCurses::KEY_DOWN
C_LEFT = 18168
C_RIGHT = 18167
S_F9 = 17949126
META_KEY = 128
