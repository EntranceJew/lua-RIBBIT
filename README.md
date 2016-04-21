# lua-RIBBIT
Obtain tips for FROG operations.

## Quick Start
```lua
local RIBBITClient = require('RIBBIT')
local myFROG = RIBBITClient()
myFROG:croak()
for i=1,50 do
	print(i,myFROG:frog_tip())
end
```