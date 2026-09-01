const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.resolve(__dirname, "..");
const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
const recommendationPath = path.join(root, "scripts/data/recommendations.lua");

const EXPECTED = {
  strong: [
    29,43,49,52,54,90,91,92,93,94,96,98,101,103,108,126,128,130,133,
    186,190,198,199,218,219,225,226,231,239,282,283,288,291,294,295,299,
    332,396,419,429,431,432,433,441,444,448,452,458,459,463,464,467,470,
    491,494,501,502,507,518,541,542,543,544,549,584,586,587,589,592,595,
    597,618,620,625,627,
  ],
  recommended: [
    9,20,21,44,46,48,50,55,56,60,62,63,71,77,97,100,104,109,112,113,
    116,118,119,121,122,124,125,129,131,132,149,180,184,187,188,191,192,
    203,204,220,221,222,224,227,233,236,238,289,292,293,297,298,303,309,
    318,333,392,394,395,397,398,401,417,418,422,425,434,435,436,437,443,
    445,447,451,453,454,455,457,492,495,496,497,499,503,504,505,506,520,
    524,527,528,529,530,532,533,535,536,539,540,551,552,554,558,559,560,
    563,564,569,571,572,577,581,585,590,599,601,602,604,607,609,610,612,
    613,616,617,623,624,626,628,629,630,631,632,634,
  ],
  discouraged: [240,500,611],
};

function recommendationSource() {
  assert.ok(fs.existsSync(recommendationPath),
    "the built-in recommendation data module must exist");
  return fs.readFileSync(recommendationPath, "utf8");
}

function tierIds(source, tier) {
  const body = source.match(new RegExp(`${tier}\\s*=\\s*\\{([\\s\\S]*?)\\}`))?.[1];
  assert.ok(body, `missing ${tier} recommendation tier`);
  return [...body.matchAll(/\d+/g)].map((match) => Number(match[0]));
}

test("built-in beginner profile matches the approved upstream achievement priorities", () => {
  const source = recommendationSource();
  const all = [];
  for (const tier of ["strong", "recommended", "discouraged"]) {
    const actual = tierIds(source, tier);
    assert.deepEqual(actual, EXPECTED[tier], `${tier} ids must match beginner-9.10`);
    all.push(...actual);
  }
  assert.equal(new Set(all).size, all.length, "an achievement may have only one priority");
  assert.ok(all.every((id) => id >= 1 && id <= 641));
  assert.match(source, /beginner-9\.10/);
  assert.match(source, /fc005d0c608715629e494d93810eedfd05c9fd14/);
});

test("recommendation module exposes four stable tiers and defaults unknown goals to normal", () => {
  const source = recommendationSource();
  assert.match(source,
    /Recommendations\.SCORE\s*=\s*\{\s*strong=3,\s*recommended=2,\s*normal=1,\s*discouraged=0\s*\}/);
  assert.match(source, /function Recommendations\.priority\(goal\)/);
  assert.match(source, /return priorities\[achievementId\] or "normal"/);
  assert.match(source, /function Recommendations\.rank\(goal\)/);
});

test("F3 sorts untracked status buckets by recommendations without disturbing explicit orders", () => {
  const menu = read("scripts/ui/menu.lua");
  assert.match(menu, /require\("scripts\.data\.recommendations"\)/);
  for (const bucket of [
    "currentPending", "convertiblePending", "otherCharacterPending", "unavailable", "completed",
  ]) {
    assert.match(menu, new RegExp(`sortByRecommendation\\(${bucket}\\)`));
  }
  assert.doesNotMatch(menu, /sortByRecommendation\((?:tracked|scenePending)\)/);
  assert.match(menu, /recommendationRank=Recommendations\.rank\(goal\)/);

  const searchSort = menu.match(/if state\.menu\.query ~= "" then[\s\S]*?\n  end\n  state\.menu\.goals/)?.[0] ?? "";
  const scoreIndex = searchSort.indexOf("left.score ~= right.score");
  const recommendationIndex = searchSort.indexOf("left.recommendationRank ~= right.recommendationRank");
  assert.ok(scoreIndex >= 0 && recommendationIndex > scoreIndex,
    "fuzzy-search relevance must remain ahead of recommendation rank");
});

test("F3 renders four full-row priority backgrounds beneath status and selection layers", () => {
  const menu = read("scripts/ui/menu.lua");
  const icons = read("scripts/ui/reward_icons.lua");
  const text = read("scripts/ui/text.lua");

  assert.match(icons, /local PRIORITY_BACKGROUNDS\s*=\s*\{/);
  for (const tier of ["strong", "recommended", "normal", "discouraged"]) {
    assert.match(icons, new RegExp(`${tier}\\s*=\\s*Color\\(`), `missing ${tier} background`);
  }
  assert.match(icons, /function RewardIcons\.renderPriorityBackground\(priority, x, y, width, height\)/);

  const tileRender = menu.match(/for index = state\.menu\.offset, last do[\s\S]*?\n  end\n\n  local detailY/)?.[0] ?? "";
  const backgroundIndex = tileRender.indexOf("RewardIcons.renderPriorityBackground");
  const selectionIndex = tileRender.indexOf("RewardIcons.renderSelection");
  const statusIndex = tileRender.indexOf("RewardIcons.renderStatus");
  assert.ok(backgroundIndex >= 0 && selectionIndex > backgroundIndex && statusIndex > selectionIndex,
    "priority background must render below the selected border and status icon");

  assert.match(menu, /labels\.recommendationPriorities\[priority\]/);
  for (const label of ["强烈推荐", "推荐", "普通", "不建议提前解锁"]) assert.match(text, new RegExp(label));
  for (const label of ["Strongly recommended", "Recommended", "Normal", "Avoid early unlock"]) {
    assert.match(text, new RegExp(label));
  }
});

test("documentation attributes the derived recommendation profile and explains F3 behavior", () => {
  const readme = read("README.md");
  const notices = read("THIRD_PARTY_NOTICES.md");
  assert.match(readme, /强烈推荐.*推荐.*普通.*不建议提前解锁/);
  assert.match(readme, /F3[\s\S]*?推荐/);
  assert.match(notices, /Unlock recommendations/);
  assert.match(notices, /Momo-Tori\/isaac_unlock_planner/);
  assert.match(notices, /beginner-9\.10/);
  assert.match(notices, /fc005d0c608715629e494d93810eedfd05c9fd14/);
});
