# Adding a game

## 1. Create the module folder

Copy `games/_template` to `games/<short-name>`. Keep the folder name lowercase and
without spaces. Add feature modules beside `init.lua`, for example:

```text
games/<short-name>/
    init.lua
    esp.lua
    misc.lua
```

Every feature module is loaded remotely by `init.lua`, so a missing file will stop
that game's hub from starting.

## 2. Register the place ID

Add the Roblox place ID to `games.lua`:

```lua
[123456789] = "games/<short-name>/init.lua",
```

Use the root place ID that `game.PlaceId` reports. Do not register individual
subplaces unless they need a different module set.

## 3. Load shared modules first

The initializer should load `shared/windui.lua`, `shared/utils.lua` when needed,
and `shared/config.lua` before feature modules. Feature modules can then use:

```lua
local WindUI = undeltedhub.WindUI
local utils = undeltedhub.Utils
local config = undeltedhub.Config
```

Register long-running connections or loops in `undeltedhub.Toggles` and clean them
up when the toggle is disabled. Keep feature names unique within the game folder.

## 4. Run the smoke check

From the repository root:

```sh
./tools/validate.sh
```

This checks the entrypoints, shared modules, game initializers, and every path in
the game registry.
