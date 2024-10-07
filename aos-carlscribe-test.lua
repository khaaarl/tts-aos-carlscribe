require('aos-carlscribe')
local json = require('json')
local lu = require('luaunit')

local testArmyNewRecruit = [[
blah (450 points) - General's Handbook 2024-25

Gloomspite Gitz
Drops: 1

Manifestation Lore - Dank Manifestations
Spell Lore - Lore of the Clammy Dank

General's Regiment
Fungoid Cave-Shaman (100)
• General
Moonclan Shootas (150)
• 1x Champion
• 1x Musician
• 1x Standard Bearer
Squig Herd (200)
• Reinforced

Faction Terrain
Bad Moon Loonshrine

Created with New Recruit
Data Version: v1
]]

local testArmyListbot = [[
Gloomspite Gitz

Webspinner Shaman on Arachnarok Spider (290)
[General]
- 5 x Spider Riders (110)
- 10 x Spider Riders (220)
- 1 x Arachnarok Spider with Flinger (270)

Bad Moon Loonshrine

[Lore of the Clammy Dank]
[Dank Manifestations]

890/2000pts
1 drop

Generated by Listbot 4.0
]]


local gitzXml = io.open("BSData/Gloomspite Gitz - Library.cat", "r"):read("*all")

TestCarlscribe = {} --class
function TestCarlscribe:testGetArmyFaction()
  lu.assertEquals(GetArmyFaction(testArmyNewRecruit), "Gloomspite Gitz")
  lu.assertEquals(GetArmyFaction(testArmyListbot), "Gloomspite Gitz")
end

function TestCarlscribe:testGetArmyUnits()
  local data = ParseBSData(gitzXml)

  local nrUnits = GetArmyUnits(testArmyNewRecruit, data)
  lu.assertEquals(#nrUnits, 4)
  lu.assertEquals(nrUnits[1].warscroll.name, "Fungoid Cave-Shaman")
  lu.assertTrue(nrUnits[1].isGeneral)
  lu.assertFalse(nrUnits[2].isGeneral)
  lu.assertFalse(nrUnits[2].reinforced)
  lu.assertTrue(nrUnits[3].reinforced)

  local lbUnits = GetArmyUnits(testArmyListbot, data)
  lu.assertEquals(#lbUnits, 5)
  lu.assertEquals(lbUnits[1].warscroll.name, "Webspinner Shaman on Arachnarok Spider")
  lu.assertTrue(lbUnits[1].isGeneral)
  lu.assertFalse(lbUnits[2].reinforced)
  lu.assertEquals(lbUnits[2].annotatedModelCounts["Spider Rider Champ"], 1)
  lu.assertEquals(lbUnits[2].annotatedModelCounts["Spider Rider Music"], 1)
  lu.assertTrue(lbUnits[3].reinforced)
  lu.assertEquals(lbUnits[3].annotatedModelCounts["Spider Rider Champ"], 1)
  lu.assertEquals(lbUnits[3].annotatedModelCounts["Spider Rider Music"], 2)
end

function TestCarlscribe:testParseXML()
  lu.assertEquals(json.encode(ParseXML([[<asdf />]])),
    '[{"elementName":"asdf","childTags":[],"textContents":""}]')
end

function TestCarlscribe:testParseBSData()
  local data = ParseBSData(gitzXml)
  lu.assertEquals(#data.units, 43)
  lu.assertEquals(data.units[1].name, "Dankhold Troggoth")
  -- print(json.encode(data))
  -- print(json.encode(ParseXML(gitzXml)))
end

function TestCarlscribe:testBBCodify()
  lu.assertEquals(BBCodify("asdf"), "asdf")
  lu.assertEquals(BBCodify(""), "")
  lu.assertEquals(BBCodify("asdf **^^blah^^** foo"), "asdf [b]blah[/b] foo")
  lu.assertEquals(BBCodify("asdf **blah** foo"), "asdf [b]blah[/b] foo")
end

function TestCarlscribe:testFinalModelName()
  local data = ParseBSData(gitzXml)
  local dankhold, rockguts = {}, {}
  for _, unit in ipairs(data.units) do
    if unit.name == "Dankhold Troggoth" then
      dankhold = unit
    elseif unit.name == "Rockgut Troggoths" then
      rockguts = unit
    end
  end
  lu.assertEquals(FinalModelName("Dankhold Troggoth", dankhold), [=[
0/10 [-]Dankhold Troggoth[-][sup]]=])
  lu.assertEquals(FinalModelName("Rockgut Troggoth", rockguts), [=[
0/5 [-]Rockgut Troggoths[-][sup]
Rockgut Troggoth]=])
  lu.assertEquals(FinalModelName("Rockgut Troggoth", rockguts, "Da Rollin' Stonaz"), [=[
0/5 [-]Da Rollin' Stonaz[-][sup]
Rockgut Troggoth]=])
end

function TestCarlscribe:testFinalModelDescription()
  local data = ParseBSData(gitzXml)
  local dankhold, rockguts, spid, shootas = {}, {}, {}, {}
  for _, unit in ipairs(data.units) do
    if unit.name == "Dankhold Troggoth" then
      dankhold = unit
    elseif unit.name == "Rockgut Troggoths" then
      rockguts = unit
    elseif unit.name == "Webspinner Shaman on Arachnarok Spider" then
      spid = unit
    elseif unit.name == "Moonclan Shootas" then
      shootas = unit
    end
  end
  local dankExpected = TrimString([[
[-][sup]Monster, Troggoth[/sup]
[56f442]Move  Health  Control  Save[-]
   6"       10          5        4+

[e85545]Melee Weapons[-]
[c6c930]Colossal Boulder Club[-]
A:4 H:4+ W:2+ R:2 D:D3+3

[dc61ed]Abilities[-][sup]
[u]Wade and Smash[/u]  1/T(Army),Any Combat;[b]Rampage[/b]
Effect: If this unit is in combat, it can move 6" but must end that move in combat. Then, roll a D3 for each enemy unit within 1" of this unit. On a 2+, inflict an amount of mortal damage on that unit equal to the roll.
[u]Magical Resistance[/u]  Reaction: Opponent declared a [b]Spell[/b] ability
Effect: If this unit was picked to be the target of that spell, roll a dice. On a 4+, ignore the effect of that spell on this unit.
[u]Regeneration[/u]  Start of Any Turn
Effect: [b]Heal (D3)[/b] this unit.
]])
  lu.assertEquals(FinalModelDescription(dankhold), dankExpected)
  local rockyExpected = TrimString([[
[-][sup]Infantry, Troggoth[/sup]
[56f442]Move  Health  Control  Save/Ward[-]
   6"        5          2         4+/5+++

[e85545]Ranged Weapons[-]
[c6c930]Throwin' Boulders[-]
10" A:1 H:5+ W:2+ R:2 D:D3
[e85545]Melee Weapons[-]
[c6c930]Stone Maul or Craggy Hands[-]
A:2 H:4+ W:2+ R:2 D:3

[dc61ed]Abilities[-][sup]
[u]Regeneration[/u]  Start of Any Turn
Effect: [b]Heal (D3)[/b] this unit.
]])
  lu.assertEquals(FinalModelDescription(rockguts), rockyExpected)
  local spidExpected = TrimString([[
[-][sup]Monster, Hero, Arachnarok, Spiderfang, Wizard(1)[/sup]
[56f442]Move  Health  Control  Save[-]
  10"      16          5        4+

[e85545]Ranged Weapons[-]
[c6c930]Spider-bows[-]
18" A:10 H:4+ W:5+ R:- D:1
[e85545]Melee Weapons[-]
[c6c930]Crooked Spears[-]
A:10 H:4+ W:5+ R:-  D:1
[c6c930]Monstrous Spider Fangs[-]
A:4   H:3+ W:2+ R:1 D:3   [sup]Crit(Mortal),Companion[/sup]
[c6c930]Chitinous Legs[-]
A:8   H:4+ W:2+ R:1 D:1   [sup]Companion[/sup]
[c6c930]Spider God Staff[-]
A:3   H:4+ W:5+ R:- D:D3 [sup]Crit(Mortal)[/sup]

[dc61ed]Abilities[-][sup]
[u]Battle Damaged[/u]
Effect: While this unit has 10 or more damage points, the Attacks characteristic of its [b]Chitinous Legs[/b] is 6.
[u]Catchweb Spidershrine[/u]
Effect: Add 1 to casting rolls for friendly [b]Spiderfang Wizards[/b] while they are wholly within 12" of this unit.
[u]Ensnaring Webbing[/u]  1/T(Army),Any Combat;[b]Rampage[/b]
Declare: Target an enemy [b]Infantry Hero[/b] within 1".
Effect: Roll a dice. On a 3+, the target has [b]Strike-last[/b] for the rest of the turn.
]])
  lu.assertEquals(FinalModelDescription(spid), spidExpected)
  local shootasExpected = TrimString([[
[-][sup]Infantry,Champ,Music(1/20),Standard(1/20),Moonclan[/sup]
[56f442]Move  Health  Control  Save[-]
   5"        1          1        6+

[e85545]Ranged Weapons[-]
[c6c930]Moonclan Bow[-]
18" A:2 H:4+ W:5+ R:- D:1
[e85545]Melee Weapons[-]
[c6c930]Moonclan Bow[-]
A:1 H:4+ W:5+ R:- D:1

[dc61ed]Abilities[-][sup]
[u]Netters[/u]  Any Combat
Declare: Target an enemy [b]Infantry[/b] unit in combat.
Effect: Roll a dice. On a 3+, subtract 1 from hit rolls for the target's attacks for the rest of the turn.
]])
  lu.assertEquals(FinalModelDescription(shootas), shootasExpected)
end

function TestCarlscribe:testGetBestMatchingObjects()
  local annotatedObjects = {
    { name = "Moonclan Shoota 1" },
    { name = "Moonclan Shoota 2" },
    { name = "Moonclan Shoota Musician" },
    { name = "Moonclan Shoota Champion" },
    { name = "Unrelated Thing" }
  }
  lu.assertEquals(
    GetBestMatchingObjects("Does not match", annotatedObjects), {})
  lu.assertEquals(
    GetBestMatchingObjects("Moonclan Shoota", annotatedObjects),
    { { name = "Moonclan Shoota 1" }, { name = "Moonclan Shoota 2" } })
  lu.assertEquals(
    GetBestMatchingObjects("Moonclan Shoota Music", annotatedObjects),
    { { name = "Moonclan Shoota Musician" } })
  lu.assertEquals(
    GetBestMatchingObjects("Moonclan Shoota Standard", annotatedObjects),
    { { name = "Moonclan Shoota 1" }, { name = "Moonclan Shoota 2" } })
end

lu.LuaUnit.verbosity = 2
os.exit(lu.LuaUnit.run())
