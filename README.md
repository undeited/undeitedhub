# Undelted Hub

Just a basic script hub with a bunch of upcoming supported games. I made this script hub using the [WindUI](https://footagesus.github.io/WindUI-Docs/docs) documentation. I am going to try and make this script hub support all executors.

## Supported Games

- [Murder Mystery 2](https://www.roblox.com/games/142823291/Murder-Mystery-2)
- [Giant Simulator: REBORN](https://www.roblox.com/games/12645083079/Giant-Simulator-REBORN)
- [Free Boombox/Radio](https://www.roblox.com/games/6116002492/Free-Boombox-Radio)
- [Fling Things And People](https://www.roblox.com/games/6961824067/Fling-Things-and-People)
- [Muscle Legends](https://www.roblox.com/games/3623096087/Muscle-Legends)

Hydroxide is bundled as the single `shared/hydroxide.lua` file and can be started
from the Universal tab.

## Repository Layout

- `main.lua` is the public loader and selects a game by place ID.
- `games.lua` maps place IDs to game initializers.
- `games/` contains one initializer and its feature modules per game.
- `shared/` contains common configuration, settings, utilities, and WindUI setup.
- `docs/adding-a-game.md` explains how to add another supported game.

Run `./tools/validate.sh` before publishing changes to catch missing module paths.

### Loadstring

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/undelted/undeltedhub/main/main.lua"))()
```
