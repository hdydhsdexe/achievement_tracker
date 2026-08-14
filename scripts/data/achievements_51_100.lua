-- Source: https://isaac.huijiwiki.com/wiki/成就 (Data:Achievement.tabx)
local function reward(kind, id) return {kind=kind, id=id} end
local function a(number, zhName, enName, zhDetail, enDetail, unlockReward)
  return {
    id="achievement_" .. number, achievementId=number, category="achievement", reward=unlockReward,
    zh={name=string.format("#%02d %s",number,zhName),detail=zhDetail},
    en={name=string.format("#%02d %s",number,enName),detail=enDetail}
  }
end

local achievements = {
  a(51,"亚伯","Abel","用该隐获得羔羊通关标记。","Defeat The Lamb as Cain.",reward("collectible",188)),
  a(52,"弯羊角","The Curved Horn","用犹大获得羔羊通关标记。","Defeat The Lamb as Judas.",reward("trinket",35)),
  a(53,"献祭匕首","Sacrificial Knife","用夏娃获得???通关标记。","Defeat ??? as Eve.",reward("collectible",172)),
  a(54,"嗜血","Bloody Lust","用参孙获得以撒通关标记。","Defeat Isaac as Samson.",reward("collectible",157)),
  a(55,"染血硬币","The Bloody Penny","用参孙获得???通关标记。","Defeat ??? as Samson.",reward("trinket",49)),
  a(56,"血之权利","Blood Rights","用参孙获得撒但通关标记。","Defeat Satan as Samson.",reward("collectible",186)),
  a(57,"全家福","The Polaroid","击败以撒5次。","Defeat Isaac five times.",reward("collectible",327)),
  a(58,"爸爸的钥匙","Dad's Key","在一局游戏中同时拥有钥匙碎片1和钥匙碎片2。","Hold Key Piece 1 and Key Piece 2 at the same time.",reward("collectible",175)),
  a(59,"蓝蜡烛","A Blue Candle","向捐款机捐献900枚硬币。","Donate 900 coins to the Donation Machine.",reward("collectible",164)),
  a(60,"焦灼硬币","Burnt Penny","通过挑战#13：豆子！。","Complete challenge #13: Beans!",reward("trinket",50)),
  a(61,"幸运脚趾！","Lucky Toe!","消灭20个商店老板。","Destroy 20 Shopkeepers.",reward("trinket",42)),
  a(62,"史诗胎儿博士","Epic Fetus","通过挑战#19：顾家男人。","Complete challenge #19: The Family Man.",reward("collectible",168)),
  a(63,"超级食肉男孩死忠粉","Super Fan","通过挑战#14：尽在卡牌中。","Complete challenge #14: It's in the Cards.",reward("collectible",189)),
  a(64,"假币","Counterfeit Penny","在赌博乞丐处赌博100次。","Play a Shell Game 100 times.",reward("trinket",52)),
  a(65,"嗝屁猫的毛球","Guppy's Hairball","在一局游戏中拾取3个嗝屁猫标签道具。","Collect three Guppy-tagged items in one run.",reward("collectible",187)),
  a(66,"被遗忘的骑士","A Forgotten Horseman","在天使房中拾取10个道具。","Take ten items from Angel Rooms."),
  a(67,"参孙","Samson","在不受到伤害的情况下连续通过两层。","Complete two consecutive floors without taking damage."),
  a(68,"恶心的家伙！","Something Icky!","击败以撒10次。","Defeat Isaac ten times."),
  a(69,"白金大神！","Platinum God!","解锁重生中除游魂相关内容外的所有道具、结局和成就。","Unlock all Rebirth items, endings, and achievements except Lost-related content."),
  a(70,"以撒的头","Isaac's Head","用以撒获得Boss Rush通关标记。","Complete Boss Rush as Isaac.",reward("trinket",54)),
  a(71,"抹大拉的信仰","Maggy's Faith","用抹大拉获得羔羊通关标记。","Defeat The Lamb as Magdalene.",reward("trinket",55)),
  a(72,"犹大的舌头","Judas' Tongue","用犹大获得撒但通关标记。","Defeat Satan as Judas.",reward("trinket",56)),
  a(73,"???的灵魂","???'s Soul","用???获得羔羊通关标记。","Defeat The Lamb as ???.",reward("trinket",57)),
  a(74,"参孙的发髻","Samson's Lock","用参孙获得羔羊通关标记。","Defeat The Lamb as Samson.",reward("trinket",58)),
  a(75,"该隐的眼睛","Cain's Eye","用该隐获得???通关标记。","Defeat ??? as Cain.",reward("trinket",59)),
  a(76,"夏娃的鸟爪","Eve's Bird Foot","用夏娃获得以撒通关标记。","Defeat Isaac as Eve.",reward("trinket",60)),
  a(77,"左断手","The Left Hand","用犹大击败???，或击败究极傲慢1次。","Defeat ??? as Judas, or defeat Ultra Pride once.",reward("trinket",61)),
  a(78,"底片","The Negative","击败撒但5次。","Defeat Satan five times.",reward("collectible",328)),
  a(79,"阿撒泻勒","Azazel","在一局游戏中进行3次恶魔交易。","Make three Devil Deals in one run."),
  a(80,"拉撒路","Lazarus","在一局游戏中同时拥有四颗魂心。","Have four Soul Hearts at one time."),
  a(81,"伊甸","Eden","击败妈妈的心脏1次。","Defeat Mom's Heart once."),
  a(82,"游魂","The Lost","持有寻人启事时在献祭房死亡。","Die in a Sacrifice Room while holding Missing Poster."),
  a(83,"死亡小子","Dead Boy","在不受到伤害的情况下通过第六章。","Complete Chapter 6 without taking damage."),
  a(84,"真·白金大神！","Real Platinum God!","收集所有道具并解锁所有结局。","Collect every item and unlock every ending."),
  a(85,"幸运石","A Lucky Rock","摧毁100个石头。","Destroy 100 rocks.",reward("trinket",15)),
  a(86,"地窖","The Cellar","击败地下室中的所有头目各1次。","Defeat every Basement boss once."),
  a(87,"墓穴","The Catacombs","击败洞穴中的所有头目各1次。","Defeat every Caves boss once."),
  a(88,"坟场","Necropolis","击败深牢中的所有头目各1次。","Defeat every Depths boss once."),
  a(89,"冰雹符文","The Rune of Hagalaz","通过挑战#1：漆黑一片。","Complete challenge #1: Pitch Black.",reward("card",32)),
  a(90,"收获符文","The Rune of Jera","通过挑战#2：格调高雅。","Complete challenge #2: High Brow.",reward("card",33)),
  a(91,"马骑符文","The Rune of Ehwaz","通过挑战#3：头部创伤。","Complete challenge #3: Head Trauma.",reward("card",34)),
  a(92,"朝夕符文","The Rune of Dagaz","通过挑战#4：黑暗降临。","Complete challenge #4: Darkness Falls.",reward("card",35)),
  a(93,"诸神符文","The Rune of Ansuz","通过挑战#5：坦克。","Complete challenge #5: The Tank.",reward("card",36)),
  a(94,"签筒符文","The Rune of Perthro","通过挑战#6：太阳系。","Complete challenge #6: Solar System.",reward("card",37)),
  a(95,"桦木符文","The Rune of Berkano","通过挑战#20：返璞归真。","Complete challenge #20: Purist.",reward("card",38)),
  a(96,"保护符文","The Rune of Algiz","通过挑战#8：好奇害死猫。","Complete challenge #8: Cat Got Your Tongue.",reward("card",39)),
  a(97,"混沌卡","The Chaos Card","通过挑战#9：拆迁办。","Complete challenge #9: Demo Man.",reward("card",42)),
  a(98,"信用卡","The Credit Card","通过挑战#10：诅咒！。","Complete challenge #10: Cursed!",reward("card",43)),
  a(99,"规则卡","The Rules Card","通过挑战#11：玻璃大炮。","Complete challenge #11: Glass Cannon.",reward("card",44)),
  a(100,"反人类卡","Card Against Humanity","通过挑战#12：当生活充满酸意。","Complete challenge #12: When Life Gives You Lemons.",reward("card",45))
}

local observations = {
  achievement_66={kind="boss",values={{65,1}}},
  achievement_67={kind="player",values={6}},
  achievement_68={kind="boss",values={{101,1}}},
  achievement_79={kind="player",values={7}},
  achievement_80={kind="player",values={8}},
  achievement_81={kind="player",values={9}},
  achievement_82={kind="player",values={10}},
  achievement_86={kind="stage_type",values={{1,1},{2,1}}},
  achievement_87={kind="stage_type",values={{3,1},{4,1}}},
  achievement_88={kind="stage_type",values={{5,1},{6,1}}}
}
for _, goal in ipairs(achievements) do goal.observation=observations[goal.id] end

return achievements
