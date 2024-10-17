--[[ AoS Carlscribe ]]

-- Raw Github URLs from https://github.com/BSData/age-of-sigmar-4th
local BSDATA_URL_ROOT = "https://raw.githubusercontent.com/BSData/age-of-sigmar-4th/refs/heads/main/"
local BSDATA_URLS = {}
-- Misc AoS things, needed for generic endless spells
BSDATA_URLS["__misc__"] = "Age of Sigmar 4.0.gst"
BSDATA_URLS["Beasts of Chaos"] = "Beasts of Chaos - Library.cat"
BSDATA_URLS["Blades of Khorne"] = "Blades of Khorne - Library.cat"
BSDATA_URLS["Bonesplitterz"] = "Bonesplitterz - Library.cat"
BSDATA_URLS["Cities of Sigmar"] = "Cities of Sigmar - Library.cat"
BSDATA_URLS["Daughters of Khaine"] = "Daughters of Khaine - Library.cat"
BSDATA_URLS["Disciples of Tzeentch"] = "Disciples of Tzeentch - Library.cat"
BSDATA_URLS["Flesh-eater Courts"] = "Flesh-eater Courts - Library.cat"
BSDATA_URLS["Fyreslayers"] = "Fyreslayers - Library.cat"
BSDATA_URLS["Gloomspite Gitz"] = "Gloomspite Gitz - Library.cat"
BSDATA_URLS["Hedonites of Slaanesh"] = "Hedonites of Slaanesh - Library.cat"
BSDATA_URLS["Idoneth Deepkin"] = "Idoneth Deepkin - Library.cat"
BSDATA_URLS["Ironjawz"] = "Ironjawz - Library.cat"
BSDATA_URLS["Kharadron Overlords"] = "Kharadron Overlords - Library.cat"
BSDATA_URLS["Kruleboyz"] = "Kruleboyz - Library.cat"
BSDATA_URLS["Lumineth Realm-lords"] = "Lumineth Realm-lords - Library.cat"
BSDATA_URLS["Maggotkin of Nurgle"] = "Maggotkin of Nurgle - Library.cat"
BSDATA_URLS["Nighthaunt"] = "Nighthaunt - Library.cat"
BSDATA_URLS["Ogor Mawtribes"] = "Ogor Mawtribes - Library.cat"
BSDATA_URLS["Ossiarch Bonereapers"] = "Ossiarch Bonereapers - Library.cat"
BSDATA_URLS["Seraphon"] = "Seraphon - Library.cat"
BSDATA_URLS["Skaven"] = "Skaven - Library.cat"
BSDATA_URLS["Slaves to Darkness"] = "Slaves to Darkness - Library.cat"
BSDATA_URLS["Sons of Behemat"] = "Sons of Behemat - Library.cat"
BSDATA_URLS["Soulblight Gravelords"] = "Soulblight Gravelords - Library.cat"
BSDATA_URLS["Stormcast Eternals"] = "Stormcast Eternals - Library.cat"
BSDATA_URLS["Sylvaneth"] = "Sylvaneth - Library.cat"
local BSDATA_CACHE = {}
local BSDATA_JSONS = {}
-- From https://github.com/khaaarl/tts-wargaming-model-script and that repo needs to be adjacent to this repo.
local MINIFIED_MODEL_SCRIPT = ""
local thisObject = nil
local currentArmyText = nil
local currentArmy = nil

function GetBSData(factionName, callback)
  if BSDATA_JSONS[factionName] and not BSDATA_CACHE[factionName] then
    BSDATA_CACHE[factionName] = JSON.decode(BSDATA_JSONS[factionName])
  end
  if BSDATA_CACHE[factionName] then
    callback(BSDATA_CACHE[factionName])
    return
  end
  local url = BSDATA_URL_ROOT .. assert(BSDATA_URLS[factionName])
  WebRequest.get(url, function(request)
    if request.is_error then
      log(request.error)
    else
      BSDATA_CACHE[factionName] = ParseBSData(request.text)
      callback(BSDATA_CACHE[factionName])
    end
  end)
end

-- Army parsing

-- NOTE: in the future, there will have to be another step of picking specific models for whichever unit etc. Also to customize unit names.
-- TODO: also need to include some kind of logic around unit ID, placed in GMNotes; maybe UNIT_ID=somerandomstring. Then, we can prefer back on that rather than unit name for determining which models are in which unit in the models' script.
function SpawnArmy(armyText)
  local faction = GetArmyFaction(armyText)
  GetBSData(faction, function(factionInfo)
    --GetBSData("__misc__", function(miscInfo)
    local annotatedObjects = GetAnnotatedObjects()
    local armyObjectInfos = PrepArmyObjects(
      armyText, factionInfo, nil, annotatedObjects)
    for _, item in ipairs(armyObjectInfos) do
      local o = item.source.clone({ position = item.position })
      o.setName(item.name)
      o.setDescription(item.description)
      o.setGMNotes(item.gmNotes)
      o.setLuaScript(MINIFIED_MODEL_SCRIPT)
    end
    --end)
  end)
end

function GetAnnotatedObjects()
  local allObjects = getObjects()
  local relevantObjects = {}
  for _, o in ipairs(allObjects) do
    local objectInfo = {}
    objectInfo.object = o
    objectInfo.name = o.getName() or ""
    objectInfo.description = o.getDescription() or ""
    objectInfo.gmNotes = o.getGMNotes() or ""
    objectInfo.modelSize = o.getBoundsNormalized().size
    table.insert(relevantObjects, objectInfo)
  end
  return relevantObjects
end

function GetArmyFaction(armyText)
  for k, _ in pairs(BSDATA_URLS) do
    local r = RegexOfString(k)
    if (string.find(armyText, "^\n*" .. r .. "\n") or
          string.find(armyText, "\n" .. r .. "\n")) then
      return k
    end
  end
  return ""
end

function PrepArmyObjects(armyText, factionInfo, miscInfo, annotatedObjects)
  local factionName = GetArmyFaction(armyText)
  local armyUnits = GetArmyUnits(armyText, factionInfo)
  local armyObjectInfos = {}
  local dz = 0
  local unitNameCounts = {}
  for _, unit in ipairs(armyUnits) do
    unitNameCounts[unit.warscroll.name] = (unitNameCounts[unit.warscroll.name] or 0) + 1
  end
  local unitNameCountIxs = {}
  for _, unit in ipairs(armyUnits) do
    unitNameCountIxs[unit.warscroll.name] = (unitNameCountIxs[unit.warscroll.name] or 0) + 1
    local unitNameCount = unitNameCounts[unit.warscroll.name]
    local unitNameCountIx = unitNameCountIxs[unit.warscroll.name]
    local unitId = RandomString(10)
    -- model name -> best matching object(s)
    local unitModels = {}
    local numModelTypes = 0
    local diameter = 1.0 -- diameter of thing in inches
    for modelName, _ in pairs(unit.annotatedModelCounts) do
      numModelTypes = numModelTypes + 1
      unitModels[modelName] = GetBestMatchingObjects(
        modelName, annotatedObjects)
      for _, obj in ipairs(unitModels[modelName]) do
        diameter = math.max(
          diameter, obj.modelSize.x + 0.1, obj.modelSize.z + 0.1)
      end
    end
    local ix = 0
    for modelName, numModels in pairs(unit.annotatedModelCounts) do
      local modelOptions = unitModels[modelName]
      for mIx = 1, numModels do
        if #modelOptions > 0 then
          local item = {}
          local objectInfo = modelOptions[(mIx % #modelOptions) + 1]
          item.source = objectInfo.object
          item.position = {
            diameter / 2.0 + (ix % 10) * diameter,
            3,
            diameter / 2.0 + dz + math.floor(ix / 10) * diameter
          }
          local customName = nil
          if unitNameCount > 1 then
            customName = unit.warscroll.name .. " " .. string.char(string.byte("A") + unitNameCountIx - 1)
          end
          item.name = FinalModelName(modelName, unit.warscroll, customName)
          item.description = FinalModelDescription(unit.warscroll)
          item.gmNotes = 'UNIT_ID="' .. unitId .. '"\n' .. objectInfo.gmNotes
          table.insert(armyObjectInfos, item)
          ix = ix + 1
        end
      end
    end
    dz = dz + math.ceil(ix / 10) * diameter + 1
  end
  return armyObjectInfos
end

function FinalModelName(modelName, unit, customName)
  local unitName = customName or unit.name
  unitName = "[-]" .. unitName .. "[-][sup]"
  local health = tonumber(unit.characteristics.Health)
  if health and health > 1 then
    unitName = "0/" .. health .. " " .. unitName
  end
  if string.find(modelName, "Champ$") then
    modelName = modelName .. "ion"
  end
  if string.find(modelName, "Music$") then
    modelName = modelName .. "ian"
  end
  if string.find(modelName, "Standard$") then
    modelName = modelName .. " Bearer"
  end
  if unit.numModels > 1 or customName then
    unitName = unitName .. "\n" .. modelName
  end
  return unitName
end

local FIRST_KEYWORDS = { INFANTRY = true, CAVALRY = true, MONSTER = true }
FIRST_KEYWORDS["WAR MACHINE"] = true
local SECOND_KEYWORDS = { HERO = true, CHAMPION = true, MUSICIAN = true, STANDARD = true }
local OMITTED_KEYWORDS = { DESTRUCTION = true, ORDER = true, DEATH = true, CHAOS = true }
for k, _ in pairs(BSDATA_URLS) do
  OMITTED_KEYWORDS[k:upper()] = true
end
local WEAPON_CHARACTERISTICS = {
  "Rng", "Atk", "Hit", "Wnd", "Rnd", "Dmg", "Ability" }

function FinalModelDescription(unit)
  local descriptionList = {}

  -- keywords
  local keywordList = {}
  local keywordSet = {}
  local bestWard = 7
  for _, keyword in ipairs(unit.keywords) do
    if not keywordSet[keyword] and FIRST_KEYWORDS[keyword] then
      table.insert(keywordList, ShorthandifyKeyword(keyword))
      keywordSet[keyword] = true
    end
  end
  for _, keyword in ipairs(unit.keywords) do
    if not keywordSet[keyword] and (SECOND_KEYWORDS[SplitString(keyword)[1]]) then
      table.insert(keywordList, ShorthandifyKeyword(keyword))
      keywordSet[keyword] = true
    end
  end
  for _, keyword in ipairs(unit.keywords) do
    local ward = tonumber(string.match(keyword, "WARD.*([1-6])"))
    if ward and ward < bestWard then
      bestWard = ward
    end
    if (not ward and not keywordSet[keyword] and
          not OMITTED_KEYWORDS[keyword]) then
      table.insert(keywordList, ShorthandifyKeyword(keyword))
      keywordSet[keyword] = true
    end
  end
  local keywordLine = "[-][sup]" .. table.concat(keywordList, ", ") .. "[/sup]"
  local shortKeywordLine = "[-][sup]" .. table.concat(keywordList, ",") .. "[/sup]"
  if EmWidth(keywordLine) > 30 and EmWidth(shortKeywordLine) <= 30 then
    keywordLine = shortKeywordLine
  end
  table.insert(descriptionList, keywordLine)

  -- characteristics
  local characteristicHeaders = {}
  local characteristicDatas = {}
  for _, c in ipairs({ "Move", "Health", "Control", "Banishment", "Save" }) do
    local val = unit.characteristics[c]
    if val then
      if c == "Banishment" then
        c = "Banish"
      elseif c == "Save" and bestWard < 7 then
        c = "Save/Ward"
        val = val .. "/" .. bestWard .. "+++"
      end
      table.insert(characteristicHeaders, c)
      table.insert(characteristicDatas, TrimString(val))
    end
  end
  table.insert(descriptionList, "[56f442]" .. table.concat(characteristicHeaders, " ") .. "[-]")
  table.insert(descriptionList, table.concat(characteristicDatas, " "))
  AlignTexts(descriptionList, { 2, 3 },
    { alignment = "center", separator = "  " })
  table.insert(descriptionList, "")

  -- weapons
  local rangedWeapons, meleeWeapons = {}, {}
  for _, weapon in ipairs(unit.weapons) do
    if weapon.typeName == "Ranged Weapon" then
      table.insert(rangedWeapons, weapon)
    elseif weapon.typeName == "Melee Weapon" then
      table.insert(meleeWeapons, weapon)
    end
  end
  local weaponRowIxs = { {}, {} }
  for ix = 1, 2 do
    local header, weapons = "Ranged Weapons", rangedWeapons
    if ix == 2 then
      header, weapons = "Melee Weapons", meleeWeapons
    end
    if #weapons > 0 then
      table.insert(descriptionList, "[e85545]" .. header .. "[-]")
    end
    for _, weapon in ipairs(weapons) do
      table.insert(descriptionList, "[c6c930]" .. BBCodify(weapon.name) .. "[-]")
      local weaponLine = {}
      for _, c in ipairs(WEAPON_CHARACTERISTICS) do
        if weapon[c] then
          local s = BBCodify(weapon[c])
          if c == "Atk" then
            s = "A:" .. s
          elseif c == "Hit" then
            s = "H:" .. s
          elseif c == "Wnd" then
            s = "W:" .. s
          elseif c == "Rnd" then
            s = "R:" .. s
          elseif c == "Dmg" then
            s = "D:" .. s
          elseif c == "Ability" then
            if s == "-" then
              s = ""
            else
              s = "[sup]" .. string.gsub(s, " ", "") .. "[/sup]"
            end
          end
          table.insert(weaponLine, s)
        end
      end
      table.insert(descriptionList, table.concat(weaponLine, " "))
      table.insert(weaponRowIxs[ix], #descriptionList)
    end
    AlignTexts(descriptionList, weaponRowIxs[ix], { alignment = "left" })
  end
  table.insert(descriptionList, "")

  -- Abilities
  table.insert(descriptionList, "[dc61ed]Abilities[-][sup]")
  for _, ability in ipairs(unit.abilities) do
    table.insert(descriptionList, FormatAbilityFirstLine(ability))
    local declare = ShorthandifyDeclare(BBCodify(ability.Declare or ""))
    if #declare > 0 then
      table.insert(descriptionList, "Declare: " .. declare)
    end
    local effect = BBCodify(ability.Effect or "")
    if #effect > 0 then
      table.insert(descriptionList, "Effect: " .. effect)
    end
  end

  for rowIx, line in ipairs(descriptionList) do
    -- trim trailing whitespace only
    local a = line:match('^%s*()')
    local b = line:match('()%s*$', a)
    descriptionList[rowIx] = line:sub(1, b - 1)
  end
  return table.concat(descriptionList, "\n")
end

function ShorthandifyKeyword(s)
  local accum = {}
  for _, x in ipairs(SplitString(string.lower(s))) do
    x = x:gsub("^%l", string.upper)
    table.insert(accum, x)
  end
  s = table.concat(accum, " ")
  s = string.gsub(s, " %(", "(")
  s = string.gsub(s, " */ *", "/")
  s = string.gsub(s, "Champion", "Champ")
  s = string.gsub(s, "Musician", "Music")
  s = string.gsub(s, "Standard Bearer", "Standard")
  return s
end

function ShorthandifyTiming(s)
  s = string.gsub(s, "Once Per ", "1/")
  s = string.gsub(s, "Deployment Phase", "Deployment")
  s = string.gsub(s, "Hero Phase", "Hero")
  s = string.gsub(s, "Move Phase", "Move")
  s = string.gsub(s, "Combat Phase", "Combat")
  return s
end

function FormatAbilityFirstLine(ability)
  local postName = {}
  local keywords = ability.Keywords or ""
  local timing = ShorthandifyTiming(ability.Timing or "")
  if #timing > 0 then
    if not (timing == "Your Hero" and string.find(keywords, "Spell")) then
      table.insert(postName, timing)
    end
  end
  if #keywords > 0 then
    table.insert(postName, keywords)
  end
  local castingValue = ability['Casting Value'] or ""
  if #castingValue > 0 then
    table.insert(postName, "CV:" .. castingValue .. "+")
  end
  local s = "[u]" .. BBCodify(ability.name) .. "[/u]  " .. BBCodify(table.concat(postName, "; "))
  local s2 = string.gsub(s, "1/Turn", "1/T")
  s2 = string.gsub(s2, "Reaction", "React")
  s2 = string.gsub(s2, " %(", "(")
  s2 = string.gsub(s2, ", ", ",")
  s2 = string.gsub(s2, "; ", ";")
  if EmWidth(s) > 30 and EmWidth(s2) <= 30 then
    s = s2
  end
  return TrimString(s)
end

function ShorthandifyDeclare(s)
  -- Pick an enemy [b]Infantry[/b] unit in combat with this unit to be the target
  local t1, t2 = string.find(s, "Pick a")
  local t3, t4 = string.find(s, " to be the target", t2)
  if t1 and t2 and t3 and t4 then
    s = "Target a" .. string.sub(s, t2 + 1, t3 - 1) .. string.sub(s, t4 + 1)
  end
  local d1, d2, d = string.find(s, 'within ([0-9]+") of this unit')
  if d1 and d2 and d then
    s = string.sub(s, 1, d1 - 1) .. "within " .. d .. string.sub(s, d2 + 1)
  end
  s = string.gsub(s, " in combat with this unit", " in combat")
  return s
end

function GetBestMatchingObjects(modelName, annotatedObjects)
  local modelNameRe = RegexOfString(modelName)
  local trimmedModelName, trimmedModelNameRe = nil, nil
  if string.find(modelName, "Champ$") then
    trimmedModelName = string.sub(modelName, 1, #modelName - 6)
  elseif string.find(modelName, "Music$") then
    trimmedModelName = string.sub(modelName, 1, #modelName - 6)
  elseif string.find(modelName, "Standard$") then
    trimmedModelName = string.sub(modelName, 1, #modelName - 9)
  end
  if trimmedModelName then
    trimmedModelNameRe = RegexOfString(trimmedModelName)
  end
  local bestScore = 0
  local bestObjects = {}
  for _, o in ipairs(annotatedObjects) do
    local score = 0
    for _, line in ipairs(SplitLines(o.name)) do
      if string.find(line, modelNameRe) then
        score = math.max(math.floor(100000 / (#line + 1)), score)
      elseif (trimmedModelNameRe and
            string.find(line, trimmedModelNameRe)) then
        score = math.max(math.floor(1000 / (#line + 1)), score)
      end
    end
    if score > 0 then
      if score > bestScore then
        bestObjects = { o }
        bestScore = score
      elseif score == bestScore then
        table.insert(bestObjects, o)
      end
    end
  end
  return bestObjects
end

function GetArmyUnits(armyText, factionBSData)
  local warscrollNameToWarscroll = {}
  for _, warscroll in ipairs(factionBSData.units) do
    if not warscrollNameToWarscroll[warscroll.name] then
      warscrollNameToWarscroll[warscroll.name] = warscroll
    end
  end
  local lines = SplitLines(armyText)
  local units = {}
  for _, line in ipairs(lines) do
    local warscroll = nil
    for k, v in pairs(warscrollNameToWarscroll) do
      if string.find(line, RegexOfString(k) .. "[ ()0-9]*$") then
        warscroll = v
      end
    end
    if warscroll then
      local unitInfo = { reinforced = false, isGeneral = false }
      unitInfo.warscroll = warscroll
      local ix1, ix2, numStr = string.find(
        line, "([0-9]+) *x +" .. RegexOfString(warscroll.name))
      if (ix1 and ix2 and tonumber(numStr) and
            tonumber(numStr) >= warscroll.numModels * 1.5) then
        unitInfo.reinforced = true
      end
      table.insert(units, unitInfo)
    elseif string.find(line, "Reinforced$") and #units > 0 then
      units[#units].reinforced = true
    elseif string.find(line, "General%]?$") and #units > 0 then
      units[#units].isGeneral = true
    end
  end
  for _, unit in ipairs(units) do
    local foundModel = false
    unit.annotatedModelCounts = {}
    for modelName, count in pairs(unit.warscroll.modelCounts) do
      foundModel = true
      local numChamps = 0
      local numMusicians = 0
      local numStandards = 0
      if unit.reinforced then
        count = count * 2
      end
      for _, keyword in ipairs(unit.warscroll.keywords) do
        if string.find(keyword, "CHAMPION") then
          local denominator = tonumber(string.match(keyword, "CHAMPION *[(] *1 */ *([0-9]+) *[)]"))
          if denominator then
            numChamps = math.floor(count / tonumber(denominator))
          else
            numChamps = 1
          end
        elseif string.find(keyword, "MUSICIAN") then
          local denominator = string.match(keyword, "MUSICIAN *[(] *1 */ *([0-9]+) *[)]")
          if denominator then
            numMusicians = math.floor(count / tonumber(denominator))
          else
            numMusicians = 1
          end
        elseif string.find(keyword, "STANDARD BEARER") then
          local denominator = string.match(keyword, "STANDARD BEARER *[(] *1 */ *([0-9]+) *[)]")
          if denominator then
            numStandards = math.floor(count / tonumber(denominator))
          else
            numStandards = 1
          end
        end
      end
      if numChamps > 0 then
        unit.annotatedModelCounts[modelName .. " Champ"] = numChamps
      end
      if numMusicians > 0 then
        unit.annotatedModelCounts[modelName .. " Music"] = numMusicians
      end
      if numStandards > 0 then
        unit.annotatedModelCounts[modelName .. " Standard"] = numStandards
      end
      unit.annotatedModelCounts[modelName] =
          count - (numChamps + numMusicians + numStandards)
    end
    if not foundModel then
      unit.annotatedModelCounts[unit.warscroll.name] = 1
    end
  end
  return units
end

local UNIT_FIXES = {}
UNIT_FIXES["Rockgut Troggoths"] = {
  addKeywords = { "WARD (5+)" }
}

--[[
ParseBSData

Given the xml text from BSData for a faction, return a structure of objects representing the units in it. Something like:

{units=[{name:"", numModels:5, champNumerator:1, musicianNumerator:1, musicianDenominator:5}]}
--]]
function ParseBSData(bsDataXml)
  local data = ParseXML(bsDataXml)
  local units = {}
  RecursiveSearchForUnits(data, units)
  for _, unit in ipairs(units) do
    unit.numModels = 0
    for _, k in pairs(unit.modelCounts) do
      unit.numModels = unit.numModels + k
    end
    if unit.numModels < 1 then
      unit.numModels = 1
    end
    local fixes = UNIT_FIXES[unit.name] or {}
    for _, keyword in ipairs(fixes.addKeywords or {}) do
      table.insert(unit.keywords, keyword)
    end
    table.sort(unit.keywords)
  end
  return { units = units }
end

function RecursiveSearchForUnits(
    data, units, path, parentUnit, parentAbility, parentWeapon)
  path = path or {}
  if (data.elementName == "selectionEntry" and
        data.type == "unit" and data.name) then
    local unit = {
      name = data.name,
      characteristics = {},
      keywords = {},
      modelCounts = {},
      abilities = {},
      weapons = {},
    }
    table.insert(units, unit)
    parentUnit = unit
  end
  if parentUnit then
    if data.elementName == "categoryLink" and data.name then
      table.insert(parentUnit.keywords, data.name)
    elseif (data.elementName == "constraint" and
          (data.type == "max" or data.type == "min") and
          data.scope == "parent" and
          tonumber(data.value) and #path >= 4) then
      local modelMaybe = path[#path - 1]
      if (modelMaybe.elementName == "selectionEntry" and
            modelMaybe.type == "model" and modelMaybe.name) then
        parentUnit.modelCounts[modelMaybe.name] = tonumber(data.value)
      end
    elseif data.elementName == "characteristic" and data.name then
      if parentAbility then
        parentAbility[data.name] = TrimString(data.textContents or "")
      elseif parentWeapon then
        parentWeapon[data.name] = TrimString(data.textContents or "")
      elseif (data.name == "Move" or data.name == "Health" or
            data.name == "Banishment" or data.name == "Save" or
            data.name == "Control") then
        parentUnit.characteristics[data.name] = data.textContents or ""
      end
    elseif (data.elementName == "profile" and data.name and
          string.find(data.typeName or "", "Ability")) then
      local ability = { name = data.name, typeName = data.typeName }
      table.insert(parentUnit.abilities, ability)
      parentAbility = ability
    elseif (data.elementName == "profile" and data.name and
          string.find(data.typeName or "", "Weapon")) then
      local weapon = { name = data.name, typeName = data.typeName }
      table.insert(parentUnit.weapons, weapon)
      parentWeapon = weapon
    end
  end
  local path2 = {}
  for _, x in ipairs(path) do
    table.insert(path2, x)
  end
  table.insert(path2, data)
  for _, v in ipairs(data) do
    RecursiveSearchForUnits(
      v, units, path2, parentUnit, parentAbility, parentWeapon)
  end
  for _, v in ipairs(data.childTags or {}) do
    RecursiveSearchForUnits(
      v, units, path2, parentUnit, parentAbility, parentWeapon)
  end
end

-- UI and loading

function SubmitButtonClicked()
  if not thisObject then return end
  if not (currentArmyText and #currentArmyText > 0) then return end
  -- TODO
  UpdateUI()
end

function GenerateButtonClicked()
  if not thisObject then return end
  if currentArmyText and #currentArmyText > 0 then
    SpawnArmy(currentArmyText)
  end
end

function UpdateUI()
  if not thisObject then return end
  -- TODO
end

function PostLoadCoroutine()
  coroutine.yield(0)
  thisObject = self
  UpdateUI()
  return 1
end

---@diagnostic disable-next-line: lowercase-global
function onSave()
  local state = {
    currentArmy = currentArmy,
    currentArmyText = currentArmyText
  }
  return JSON.encode(state)
end

---@diagnostic disable-next-line: lowercase-global
function onLoad(stateString)
  local state = JSON.decode(stateString or "{}")
  currentArmy = state.currentArmy
  currentArmyText = state.currentArmyText
  -- Be very slow here to handle weird TTS tick issues.
  Wait.frames(function()
    startLuaCoroutine(self, 'PostLoadCoroutine')
  end, 1)
end

function UpdatedTextInput(player, value, id)
  if thisObject then
    thisObject.UI.setAttribute(id, "text", value)
    local armyText = (thisObject.UI.getAttribute("armyTextInput", "text") or "")
    armyText = string.gsub(armyText, "\r\n", "\n")
    currentArmyText = armyText
  end
end

-- Homegrown XML parsing library

function ParseXML(xmlText)
  local tags = {}
  local ix = 1
  while ix <= #xmlText do
    local tag, _ix = ParseXMLTag(xmlText, ix)
    if not tag or not _ix then break end
    ix = _ix
    table.insert(tags, tag)
  end
  return tags
end

function ParseXMLTag(xmlText, ix)
  local tag = { childTags = {}, textContents = "" }
  local s0, s1
  s0, s1, tag.elementName = string.find(xmlText, "^%s*<%s*([a-zA-Z_?:.-]+)", ix)
  if not s0 or not s1 or not tag.elementName then return nil end
  ix = s1 + 1
  while ix <= #xmlText do
    local k, v, _ix = ParseXMLAttribute(xmlText, ix)
    if not k or not v or not _ix then break end
    ix = _ix
    if k ~= "elementName" and k ~= "childTags" then
      tag[k] = v
    end
  end
  s0, s1 = string.find(xmlText, "^%s*[?/]%S*>", ix)
  if s0 and s1 then
    return tag, s1 + 1
  end
  s0, s1 = string.find(xmlText, "^%s*>", ix)
  if not s0 or not s1 then return nil end
  ix = s1 + 1
  while ix <= #xmlText do
    local childTag, _ix = ParseXMLTag(xmlText, ix)
    if not childTag or not _ix then break end
    ix = _ix
    table.insert(tag.childTags, childTag)
  end
  local textStart = ix
  while ix <= #xmlText do
    -- TODO: this probably doesn't handle weird characters in element names.
    s0, s1 = string.find(xmlText, "^<%s*/%s*" .. RegexOfString(tag.elementName) .. ">", ix)
    if s0 and s1 then
      ix = s1 + 1
      break
    end
    ix = ix + 1
  end
  if s0 then
    tag.textContents = UnescapeXML(string.sub(xmlText, textStart, s0 - 1))
  end
  return tag, ix
end

function ParseXMLAttribute(xmlText, ix)
  local s0, s1, name, value = string.find(xmlText, '^%s*([a-zA-Z_?:.-]+)%s*=%s*"([^"]*)"', ix)
  if not s0 or not s1 or not name or not value then return nil end
  return name, UnescapeXML(value), s1 + 1
end

function UnescapeXML(text)
  text = string.gsub(text, "&quot;", '"')
  text = string.gsub(text, "&apos;", "'")
  text = string.gsub(text, "&lt;", "<")
  text = string.gsub(text, "&gt;", ">")
  text = string.gsub(text, "&amp;", "&")
  return text
end

--[[ UTILITIES ]] --

--[[
Notes on TTS ui:
- a little more than 22 lowercase "m"s can fit in a single line
  without wrapping.
--]]
local EM_WIDTH_OF_CHAR = {
  a = 22 / 33,
  b = 22 / 33,
  c = 22 / 45,
  d = 22 / 33,
  e = 22 / 40,
  f = 22 / 40,
  g = 22 / 33,
  h = 22 / 33,
  i = 22 / 67,
  j = 22 / 80,
  k = 22 / 36,
  l = 22 / 66,
  m = 1,
  n = 22 / 33,
  o = 22 / 36,
  p = 22 / 33,
  q = 22 / 33,
  r = 22 / 50,
  s = 22 / 44,
  t = 22 / 50,
  u = 22 / 33,
  v = 22 / 33,
  w = 22 / 23,
  x = 22 / 36,
  y = 22 / 33,
  z = 22 / 44,
  A = 22 / 31,
  B = 22 / 33,
  C = 22 / 33,
  D = 22 / 28,
  E = 22 / 36,
  F = 22 / 36,
  G = 22 / 31,
  H = 22 / 28,
  I = 22 / 66,
  J = 22 / 65,
  K = 22 / 30,
  L = 22 / 39,
  M = 22 / 22,
  N = 22 / 26,
  O = 22 / 26,
  P = 22 / 33,
  Q = 22 / 26,
  R = 22 / 30,
  S = 22 / 36,
  T = 22 / 36,
  U = 22 / 28,
  V = 22 / 29,
  W = 22 / 21,
  X = 22 / 29,
  Y = 22 / 31,
  Z = 22 / 31
}
EM_WIDTH_OF_CHAR["+"] = 22 / 36
EM_WIDTH_OF_CHAR["-"] = 22 / 49
EM_WIDTH_OF_CHAR["/"] = 22 / 44
EM_WIDTH_OF_CHAR["|"] = 22 / 57
EM_WIDTH_OF_CHAR[" "] = 22 / 66
EM_WIDTH_OF_CHAR["."] = 22 / 66
EM_WIDTH_OF_CHAR[","] = 22 / 66
EM_WIDTH_OF_CHAR['"'] = 22 / 49
local SUM_EM_WIDTHS = 0
local NUM_EM_WIDTHS = 0
for _, v in pairs(EM_WIDTH_OF_CHAR) do
  SUM_EM_WIDTHS = SUM_EM_WIDTHS + v
  NUM_EM_WIDTHS = NUM_EM_WIDTHS + 1
end
local AVG_EM_WIDTH = SUM_EM_WIDTHS / NUM_EM_WIDTHS

function EmWidth(s)
  -- get rid of any bbcode
  s = string.gsub(s, "%[[^%]]*%]", "")
  local width = 0
  for i = 1, #s do
    width = width + (EM_WIDTH_OF_CHAR[string.sub(s, i, i)] or AVG_EM_WIDTH)
  end
  return width
end

function AlignTexts(strArr, rowIxs, options)
  options = DeepCopy(options)
  options.alignment = options.alignment or "left"
  options.separator = options.separator or " "
  local widths = {}
  local rowIxWords = {}
  for _, rowIx in ipairs(rowIxs) do
    rowIxWords[rowIx] = SplitString(strArr[rowIx])
    for colIx, w in ipairs(rowIxWords[rowIx]) do
      widths[colIx] = math.max(widths[colIx] or 0, EmWidth(w))
    end
  end
  for _, rowIx in ipairs(rowIxs) do
    local accum = {}
    local widthSoFar = 0
    local myWidthSoFar = 0
    for colIx, w in ipairs(rowIxWords[rowIx]) do
      local widthDiff =
          widthSoFar + widths[colIx] - (myWidthSoFar + EmWidth(w))
      local totalSpacePadding = widthDiff / EM_WIDTH_OF_CHAR[" "]
      local prepad = 0
      local postpad = 0
      if options.alignment == "center" then
        prepad = math.floor(totalSpacePadding / 2.0 + 0.5)
        postpad = math.floor((totalSpacePadding - prepad) / 2.0 + 0.5)
      elseif options.alignment == "right" then
        prepad = math.floor(totalSpacePadding + 0.5)
      elseif options.alignment == "left" then
        postpad = math.floor(totalSpacePadding + 0.5)
      else
        assert(false)
      end
      for i = 1, prepad do
        w = " " .. w
      end
      for i = 1, postpad do
        w = w .. " "
      end
      table.insert(accum, w)
      widthSoFar = widthSoFar + widths[colIx]
      myWidthSoFar = myWidthSoFar + EmWidth(w)
    end
    strArr[rowIx] = table.concat(accum, options.separator)
  end
end

function TrimString(s)
  local a = s:match('^%s*()')
  local b = s:match('()%s*$', a)
  return s:sub(a, b - 1)
end

function SplitString(s, sep)
  if sep == nil then sep = "%s" end
  local output = {}
  for ss in string.gmatch(s, "([^" .. sep .. "]+)") do
    table.insert(output, ss)
  end
  return output
end

function BBCodify(s)
  s = string.gsub(s, "[*][*]%^%^([^^]*)%^%^[*][*]", function(a) return "[b]" .. a .. "[/b]" end)
  s = string.gsub(s, "[*][*]([^*]*)[*][*]", function(a) return "[b]" .. a .. "[/b]" end)
  s = string.gsub(s, " ", " ")
  s = string.gsub(s, "’", "'")
  s = string.gsub(s, "‘", "'")
  return s
end

function RegexOfString(s)
  local output = {}
  for i = 1, #s do
    local c = string.sub(s, i, i)
    if c == "-" or c == "\\" or string.find(c, "[.*+?^$]") then
      table.insert(output, "[")
      table.insert(output, c)
      table.insert(output, "]")
    else
      table.insert(output, c)
    end
  end
  return table.concat(output)
end

function DeepCopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[DeepCopy(orig_key)] = DeepCopy(orig_value)
    end
    setmetatable(copy, DeepCopy(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

function SplitLines(s)
  s = string.gsub(s, "\r\n", "\n")
  local lines = {}
  local delimiter = "\n"
  local from = 1
  local delim_from, delim_to = string.find(s, delimiter, from)
  while delim_from do
    table.insert(lines, string.sub(s, from, delim_from - 1))
    from = delim_to + 1
    delim_from, delim_to = string.find(s, delimiter, from)
  end
  table.insert(lines, string.sub(s, from))
  return lines
end

local _BASE64_ENCODE_ARR = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

function RandomString(n)
  local accum = {}
  for nIx = 1, n do
    local ix = math.random(#_BASE64_ENCODE_ARR)
    table.insert(accum, string.sub(_BASE64_ENCODE_ARR, ix, ix))
  end
  return table.concat(accum)
end
