-- Derived from Momo-Tori/isaac_unlock_planner's beginner-9.10 profile at
-- fc005d0c608715629e494d93810eedfd05c9fd14. Unlisted achievements are normal.
local Recommendations = {}

Recommendations.SCORE = { strong=3, recommended=2, normal=1, discouraged=0 }

local tiers = {
  strong = {
    29,43,49,52,54,90,91,92,93,94,96,98,101,103,108,126,128,130,133,
    186,190,198,199,218,219,225,226,231,239,282,283,288,291,294,295,299,
    332,396,419,429,431,432,433,441,444,448,452,458,459,463,464,467,470,
    491,494,501,502,507,518,541,542,543,544,549,584,586,587,589,592,595,
    597,618,620,625,627
  },
  recommended = {
    9,20,21,44,46,48,50,55,56,60,62,63,71,77,97,100,104,109,112,113,
    116,118,119,121,122,124,125,129,131,132,149,180,184,187,188,191,192,
    203,204,220,221,222,224,227,233,236,238,289,292,293,297,298,303,309,
    318,333,392,394,395,397,398,401,417,418,422,425,434,435,436,437,443,
    445,447,451,453,454,455,457,492,495,496,497,499,503,504,505,506,520,
    524,527,528,529,530,532,533,535,536,539,540,551,552,554,558,559,560,
    563,564,569,571,572,577,581,585,590,599,601,602,604,607,609,610,612,
    613,616,617,623,624,626,628,629,630,631,632,634
  },
  discouraged = { 240,500,611 }
}

local priorities = {}
for priority, achievementIds in pairs(tiers) do
  for _, achievementId in ipairs(achievementIds) do
    priorities[achievementId] = priority
  end
end

function Recommendations.priority(goal)
  local achievementId = type(goal) == "table" and goal.achievementId or tonumber(goal)
  return priorities[achievementId] or "normal"
end

function Recommendations.rank(goal)
  return Recommendations.SCORE[Recommendations.priority(goal)]
end

return Recommendations
