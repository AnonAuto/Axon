# Taser 7 Firmware 

# Strings Of Interest

The Taser 7 handle appears to have either (1) A debug UART/LOG or (2) A log that is kept on the app side which the handle sends messages to. It is possible the handle impliements both of these logging stratergies. Below is a list of strings that appear in the firmware of the t7 handle and some assumptions about the.

## A list of strings and guesses to be confirmed in the future
- `Writing default agency settings` - It is assumed the handle can be configured centrally at agency/department level and this config is pushed through the app to the handle
- `CART: Setting Major Fault; max errors`	- This and related messages would suggest that the cart and main proccessor communicate on some level to confirm functionality
- `HVM: Setting Major Fault; max errors` - As above it is likely that the main processor communicates with the HVM in one way or another
- `Trigger Pull Blackout`- This would sugest that either the handle lost power after a trigger pull or the trigger is currently disabled
