local _, ns = ...
local A = ns.A

-- Numeric profession skill thresholds extracted from OneForAll Forever.
-- Source: https://github.com/smoergi/OneForAll_Forever
-- OneForAll license: GPL-3.0-or-later. See DATA_SOURCES.md.
-- Records: [spellID] = {requiredSkill, yellowAt, greenAt, grayAt}.
-- Values are game-data facts; spell names and recipes are not copied.
local colors = {
  [171] = { -- Alchemy
  },
  [197] = { -- Tailoring
  },
  [164] = { -- Blacksmithing
  },
  [165] = { -- Leatherworking
  },
  [202] = { -- Engineering
  },
  [333] = { -- Enchanting
  },
  [185] = { -- Cooking
  },
  [129] = { -- FirstAid
  },
}

function A:GetOneForAllSkillColor(skillID, spellID, level)
  local profession = colors[tonumber(skillID)]
  local row = profession and profession[tonumber(spellID)]
  if not row then return nil end
  level = tonumber(level) or 0
  if level < row[1] then return "locked", row[1] end
  if level < row[2] then return "orange", row[1] end
  if level < row[3] then return "yellow", row[1] end
  if level < row[4] then return "green", row[1] end
  return "gray", row[1]
end

function A:GetOneForAllSkillThresholds(skillID, spellID)
  local profession = colors[tonumber(skillID)]
  return profession and profession[tonumber(spellID)] or nil
end
