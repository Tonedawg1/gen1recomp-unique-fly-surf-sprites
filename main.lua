-- Unique Fly/Surf Sprites 0.2.5
-- Wilds + PokePC (v0.5.4 follower_%03d.png)
-- Forced PokePC no longer depends on SPRITE_PIKACHU (Wilds may own that)

return function(mod)
  local function fsExists(path)
    if type(path) ~= "string" or path == "" then return false end
    if not (love and love.filesystem and love.filesystem.getInfo) then return false end
    local ok, info = pcall(love.filesystem.getInfo, path)
    return ok and info ~= nil
  end

  local function findPokePcHandle()
    return mod.find("PokePCFollowers_VoxelMerge")
      or mod.find("pokepcfollowers")
      or mod.find("PokePCFollowers")
      or mod.find("PokePCFollowers-main")
  end

  local function hasWilds()
    return mod.find("overworld_wild_spawns") ~= nil
  end

  local function hasPokePcInstalled()
    return findPokePcHandle() ~= nil
  end

  local POKEPC_ROOT_CANDIDATES = {
    "mods/PokePCFollowers_VoxelMerge",
    "mods/PokePCFollowers-main",
    "mods/PokePCFollowers",
    "mods/pokepcfollowers",
  }

  local function pokePcDirFromSpriteDef()
    local def = mod.content and mod.content.sprites and mod.content.sprites:get("SPRITE_PIKACHU")
    local img = def and def.image
    if type(img) ~= "string" then return nil end
    return img:match("^(.-/)follower_[^/]+%.png$")
  end

  local function collectPokePcRoots()
    local roots, seen = {}, {}
    local function add(root)
      if type(root) ~= "string" or root == "" then return end
      root = root:gsub("[/\\]+$", "")
      if seen[root] then return end
      seen[root] = true
      roots[#roots + 1] = root
    end

    local dir = pokePcDirFromSpriteDef()
    if dir then
      local root = dir:match("^(.-)/assets/sprites/?$")
      if root then add(root) end
    end

    local handle = findPokePcHandle()
    if handle and type(handle.path) == "string" then
      add(handle.path)
    end
    -- Some loaders expose id as the folder name under mods/
    if handle and type(handle.id) == "string" and handle.id ~= "" then
      add("mods/" .. handle.id)
    end

    for _, root in ipairs(POKEPC_ROOT_CANDIDATES) do
      add(root)
    end
    return roots
  end

  local function buildProviderChoices()
    local choices = { { "Auto", "auto" } }
    if hasWilds() then
      table.insert(choices, { "Wilds of Kanto", "wilds" })
    end
    if hasPokePcInstalled() then
      table.insert(choices, { "PokePC Followers", "pokepc" })
    end
    return choices
  end

  mod.options:define({
    {
      key = "surf_sprites",
      type = "toggle",
      label = "SURF SPRITES",
      default = true,
      description = "Show the Surfing Pokémon instead of the default surf sprite.",
    },
    {
      key = "fly_sprites",
      type = "toggle",
      label = "FLY SPRITES",
      default = true,
      description = "Show the Flying Pokémon instead of the default bird during normal Fly.",
    },
    {
      key = "sprite_provider",
      type = "choice",
      label = "SPRITE SOURCE",
      default = "auto",
      choices = buildProviderChoices(),
      description = "Auto prefers Wilds, then PokePC. Force either when both are installed.",
    },
  })

  local state = {
    originalSurfSprite = nil,
    originalSurfPikaSprite = nil,
    activeSurfSpecies = nil,
    activeSurfRenderer = nil,
    wasSurfing = false,

    originalBirdSprite = nil,
    activeFlySpecies = nil,
    activeFlyRenderer = nil,
    wasFlying = false,
  }

  local function getGame()
    local ok, Game = pcall(require, "src.core.Game")
    return ok and Game or nil
  end

  local function defFromResult(result)
    if type(result) ~= "table" then return nil end
    if result.image then return result end
    if result.def and result.def.image then return result.def end
    return nil
  end

  ------------------------------------------------------------------
  -- Wilds
  ------------------------------------------------------------------
  local function tryWilds(speciesId, isShiny, mode)
    local handle = mod.find("overworld_wild_spawns")
    local exports = handle and handle.exports
    if not exports then return nil end
    local game = getGame()
    local shiny = isShiny and true or false

    if type(exports.resolveFollowerSprite) == "function" then
      if mode == "surf" then
        local ok, result = pcall(exports.resolveFollowerSprite, {
          species = speciesId,
          shiny = shiny,
          surface = "water",
          game = game,
        })
        local def = ok and defFromResult(result)
        if def then return def end
      end
      local ok, result = pcall(exports.resolveFollowerSprite, {
        species = speciesId,
        shiny = shiny,
        surface = "land",
        game = game,
      })
      local def = ok and defFromResult(result)
      if def then return def end
    end

    if mode == "surf" and type(exports.resolveWaterSprite) == "function" then
      local ok, result = pcall(exports.resolveWaterSprite, speciesId, shiny, nil, { game = game })
      local def = ok and defFromResult(result)
      if def then return def end
    end

    local sp = exports.spriteProviders
    if sp and type(sp.resolve) == "function" then
      local variant = shiny and "shiny" or "normal"
      local ok, result = pcall(function()
        return sp:resolve(nil, speciesId, variant, game)
      end)
      local def = ok and defFromResult(result)
      if def then return def end
    end
    return nil
  end

  ------------------------------------------------------------------
  -- PokePC v0.5.4
  ------------------------------------------------------------------
  local POKEPC_SPECIES_TO_DEX = {
    BULBASAUR=1, IVYSAUR=2, VENUSAUR=3, CHARMANDER=4, CHARMELEON=5, CHARIZARD=6,
    SQUIRTLE=7, WARTORTLE=8, BLASTOISE=9, CATERPIE=10, METAPOD=11, BUTTERFREE=12,
    WEEDLE=13, KAKUNA=14, BEEDRILL=15, PIDGEY=16, PIDGEOTTO=17, PIDGEOT=18,
    RATTATA=19, RATICATE=20, SPEAROW=21, FEAROW=22, EKANS=23, ARBOK=24,
    PIKACHU=25, RAICHU=26, SANDSHREW=27, SANDSLASH=28, NIDORAN_F=29, NIDORINA=30,
    NIDOQUEEN=31, NIDORAN_M=32, NIDORINO=33, NIDOKING=34, CLEFAIRY=35, CLEFABLE=36,
    VULPIX=37, NINETALES=38, JIGGLYPUFF=39, WIGGLYTUFF=40, ZUBAT=41, GOLBAT=42,
    ODDISH=43, GLOOM=44, VILEPLUME=45, PARAS=46, PARASECT=47, VENONAT=48, VENOMOTH=49,
    DIGLETT=50, DUGTRIO=51, MEOWTH=52, PERSIAN=53, PSYDUCK=54, GOLDUCK=55,
    MANKEY=56, PRIMEAPE=57, GROWLITHE=58, ARCANINE=59, POLIWAG=60, POLIWHIRL=61,
    POLIWRATH=62, ABRA=63, KADABRA=64, ALAKAZAM=65, MACHOP=66, MACHOKE=67, MACHAMP=68,
    BELLSPROUT=69, WEEPINBELL=70, VICTREEBEL=71, TENTACOOL=72, TENTACRUEL=73,
    GEODUDE=74, GRAVELER=75, GOLEM=76, PONYTA=77, RAPIDASH=78, SLOWPOKE=79, SLOWBRO=80,
    MAGNEMITE=81, MAGNETON=82, FARFETCHD=83, DODUO=84, DODRIO=85, SEEL=86, DEWGONG=87,
    GRIMER=88, MUK=89, SHELLDER=90, CLOYSTER=91, GASTLY=92, HAUNTER=93, GENGAR=94,
    ONIX=95, DROWZEE=96, HYPNO=97, KRABBY=98, KINGLER=99, VOLTORB=100, ELECTRODE=101,
    EXEGGCUTE=102, EXEGGUTOR=103, CUBONE=104, MAROWAK=105, HITMONLEE=106, HITMONCHAN=107,
    LICKITUNG=108, KOFFING=109, WEEZING=110, RHYHORN=111, RHYDON=112, CHANSEY=113,
    TANGELA=114, KANGASKHAN=115, HORSEA=116, SEADRA=117, GOLDEEN=118, SEAKING=119,
    STARYU=120, STARMIE=121, MR_MIME=122, SCYTHER=123, JYNX=124, ELECTABUZZ=125,
    MAGMAR=126, PINSIR=127, TAUROS=128, MAGIKARP=129, GYARADOS=130, LAPRAS=131,
    DITTO=132, EEVEE=133, VAPOREON=134, JOLTEON=135, FLAREON=136, PORYGON=137,
    OMANYTE=138, OMASTAR=139, KABUTO=140, KABUTOPS=141, AERODACTYL=142, SNORLAX=143,
    ARTICUNO=144, ZAPDOS=145, MOLTRES=146, DRATINI=147, DRAGONAIR=148, DRAGONITE=149,
    MEWTWO=150, MEW=151,
  }

  local function tryPokePC(speciesId, isShiny, mode)
    local upper = string.upper(tostring(speciesId or "CHARMANDER"))
    local dex = POKEPC_SPECIES_TO_DEX[upper] or tonumber(speciesId)
    if not dex then return nil end
    local dex3 = string.format("%03d", dex)

    local candidates = {}
    local function addPath(path)
      if type(path) == "string" and path ~= "" then
        candidates[#candidates + 1] = path
      end
    end

    -- 1) Live SPRITE_PIKACHU dir only if it still points at follower_*.png
    local dir = pokePcDirFromSpriteDef()
    if dir then
      addPath(dir .. "follower_" .. dex3 .. ".png")
      addPath(dir .. "follower_" .. tostring(dex) .. ".png")
      addPath(dir .. "follower_" .. upper .. ".png")
    end

    -- 2) Every known pack root (does not require SPRITE_PIKACHU)
    for _, root in ipairs(collectPokePcRoots()) do
      addPath(root .. "/assets/sprites/follower_" .. dex3 .. ".png")
      addPath(root .. "/assets/sprites/follower_" .. tostring(dex) .. ".png")
      addPath(root .. "/assets/sprites/follower_" .. upper .. ".png")
      addPath(root .. "/sprites/follower_" .. dex3 .. ".png")
    end

    if #candidates == 0 then return nil end

    local Assets
    pcall(function() Assets = require("src.render.Assets") end)

    for _, path in ipairs(candidates) do
      local okLoad = false
      if Assets and type(Assets.image) == "function" then
        local ok, img = pcall(Assets.image, path)
        okLoad = ok and img ~= nil
      end
      if okLoad or fsExists(path) then
        return {
          image = path,
          frames = 6,
          walker = true,
          trueColor = true,
          id = "SPRITE_UFS_POKEPC_" .. dex3,
        }
      end
    end

    -- Last resort: first canonical dex path under first root
    local roots = collectPokePcRoots()
    if roots[1] then
      return {
        image = roots[1] .. "/assets/sprites/follower_" .. dex3 .. ".png",
        frames = 6,
        walker = true,
        trueColor = true,
        id = "SPRITE_UFS_POKEPC_" .. dex3,
      }
    end
    return nil
  end

  local RESOLVERS = {
    wilds = tryWilds,
    pokepc = tryPokePC,
  }
  local AUTO_ORDER = { "wilds", "pokepc" }

  local function resolveSprite(speciesId, isShiny, mode)
    mode = mode or "land"
    local preference = mod.options:get("sprite_provider") or "auto"

    local function run(key)
      local fn = RESOLVERS[key]
      return fn and fn(speciesId, isShiny, mode) or nil
    end

    if preference ~= "auto" and RESOLVERS[preference] then
      return run(preference)
    end
    for _, key in ipairs(AUTO_ORDER) do
      local def = run(key)
      if def then return def end
    end
    return nil
  end

  ------------------------------------------------------------------
  -- Engine access
  ------------------------------------------------------------------
  local function getPlayer()
    if mod.world and mod.world.player then return mod.world.player end
    local Game = getGame()
    if not Game then return nil end
    if Game.world and Game.world.player then return Game.world.player end
    if Game.overworld and Game.overworld.player then return Game.overworld.player end
    return Game.player
  end

  local function getOverworld()
    local Game = getGame()
    if Game and Game.stack and Game.stack.top then
      local top = Game.stack:top()
      if top and top.player then return top end
    end
    if mod.world and mod.world.player then return mod.world end
    if Game then
      if Game.world and Game.world.player then return Game.world end
      if Game.overworld and Game.overworld.player then return Game.overworld end
    end
    return nil
  end

  local function findMoveMon(names)
    local Game = getGame()
    local save = Game and Game.save
    if not save or not save.party then return nil end
    for _, mon in ipairs(save.party) do
      if mon and mon.moves then
        for _, move in ipairs(mon.moves) do
          local id = type(move) == "table" and (move.id or move.move or move.name) or move
          if type(id) == "string" then id = string.upper(id) end
          for _, want in ipairs(names) do
            if id == want then return mon end
          end
        end
      end
    end
    return nil
  end

  local function speciesKey(mon)
    if not mon then return nil end
    return mon.species or mon.id or mon.speciesId or mon.dex
  end

  local function makeRenderer(def)
    local okR, SpriteRenderer = pcall(require, "src.render.SpriteRenderer")
    if not okR or not SpriteRenderer then return nil end
    local ok, renderer = pcall(SpriteRenderer.new, def)
    if ok and renderer then return renderer end
    ok, renderer = pcall(SpriteRenderer.new, def, "player")
    if ok then return renderer end
    return nil
  end

  ------------------------------------------------------------------
  -- Surf / Fly
  ------------------------------------------------------------------
  local function applySurfSprite(player, mon)
    if not player or not mon or not mod.options:get("surf_sprites") then return end
    local key = speciesKey(mon)
    if not key then return end
    if state.activeSurfSpecies == key and state.activeSurfRenderer then return end

    local def = resolveSprite(key, mon.shiny or mon.isShiny, "surf")
    if not def then return end

    if not state.originalSurfSprite then state.originalSurfSprite = player.surfSprite end
    if not state.originalSurfPikaSprite then state.originalSurfPikaSprite = player.surfPikachuSprite end

    local renderer = makeRenderer(def)
    if not renderer then return end

    state.activeSurfRenderer = renderer
    state.activeSurfSpecies = key
    player.surfSprite = renderer
    player.surfPikachuSprite = renderer
  end

  local function restoreSurfSprites(player)
    if not player then return end
    if state.originalSurfSprite then player.surfSprite = state.originalSurfSprite end
    if state.originalSurfPikaSprite then player.surfPikachuSprite = state.originalSurfPikaSprite end
    state.activeSurfRenderer = nil
    state.activeSurfSpecies = nil
  end

  local function isVanillaFlying(ow)
    return ow and (ow.flyFade or ow.flyAnim or ow.flyArrive) and true or false
  end

  local function ensureFlyRenderer(mon)
    local key = speciesKey(mon)
    if not key then return nil end
    if state.activeFlySpecies == key and state.activeFlyRenderer then
      return state.activeFlyRenderer
    end
    local def = resolveSprite(key, mon.shiny or mon.isShiny, "fly")
    if not def then return nil end
    local renderer = makeRenderer(def)
    if not renderer then return nil end
    state.activeFlyRenderer = renderer
    state.activeFlySpecies = key
    return renderer
  end

  local function applyFlySprite(ow, mon)
    if not ow or not mon or not mod.options:get("fly_sprites") then return end
    local renderer = ensureFlyRenderer(mon)
    if not renderer then return end
    if ow.birdSprite and ow.birdSprite ~= renderer and state.originalBirdSprite == nil then
      state.originalBirdSprite = ow.birdSprite
    end
    ow.birdSprite = renderer
  end

  local function restoreFlySprite(ow)
    if not ow then return end
    if state.originalBirdSprite ~= nil then
      ow.birdSprite = state.originalBirdSprite
    else
      ow.birdSprite = nil
    end
    state.activeFlyRenderer = nil
    state.activeFlySpecies = nil
    state.originalBirdSprite = nil
  end

  local function tick()
    local player = getPlayer()
    local ow = getOverworld()

    if player then
      local surfing = not not player.surfing
      if surfing and not state.wasSurfing then
        local mon = findMoveMon({ "SURF", 57 })
        if mon then applySurfSprite(player, mon) end
      elseif not surfing and state.wasSurfing then
        restoreSurfSprites(player)
      elseif surfing and state.activeSurfRenderer then
        if player.surfSprite ~= state.activeSurfRenderer then
          player.surfSprite = state.activeSurfRenderer
          player.surfPikachuSprite = state.activeSurfRenderer
        end
      end
      state.wasSurfing = surfing
    end

    local flying = isVanillaFlying(ow)
    if flying then
      local mon = findMoveMon({ "FLY", 19 })
      if mon then applyFlySprite(ow, mon) end
    elseif state.wasFlying then
      restoreFlySprite(ow)
    end
    state.wasFlying = flying
  end

  local function cleanup()
    restoreSurfSprites(getPlayer())
    restoreFlySprite(getOverworld())
    state.wasSurfing = false
    state.wasFlying = false
  end

  mod.hooks:wrap("movement.speed", function(next, frames, ctx)
    frames = next(frames, ctx)
    tick()
    return frames
  end)

  pcall(function()
    mod.hooks:wrap("input.step", function(next, game, dt)
      next(game, dt)
      tick()
    end)
  end)

  pcall(function()
    mod.hooks:wrap("world.update", function(next, ...)
      local results = { next(...) }
      tick()
      return unpack(results)
    end)
  end)

  mod.events:on("overworld.enter", function()
    state.wasSurfing = false
    state.wasFlying = false
    tick()
  end)

  mod.events:on("mod.unload", cleanup)

  if mod.onOptionsChanged then
    mod:onOptionsChanged(cleanup)
  end

  mod.log:info(
    "Unique Fly/Surf Sprites 0.2.5 | Surf=%s Fly=%s | Wilds=%s PokePC=%s",
    tostring(mod.options:get("surf_sprites")),
    tostring(mod.options:get("fly_sprites")),
    hasWilds() and "yes" or "no",
    hasPokePcInstalled() and "yes" or "no"
  )
end