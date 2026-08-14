-- Source: https://isaac.huijiwiki.com/wiki/成就 (Data:Achievement.tabx)
-- Vanilla-readable reward metadata is used to infer save-file completion.
local function a(number, zhName, enName, zhDetail, enDetail, rewardId)
  local goal = {
    id="achievement_" .. number, achievementId=number, category="achievement",
    zh={name=string.format("#%02d %s", number, zhName), detail=zhDetail},
    en={name=string.format("#%02d %s", number, enName), detail=enDetail}
  }
  if rewardId then goal.reward={kind="collectible", id=rewardId} end
  return goal
end

local achievements = {
  a(1,"抹大拉","Magdalene","在一局游戏中，同时拥有七个心之容器。","Have seven heart containers at one time."),
  a(2,"该隐","Cain","在一局游戏中，同时拥有55枚硬币。","Hold 55 coins at one time."),
  a(3,"犹大","Judas","击败撒但1次。","Defeat Satan once."),
  a(4,"子宫","The Womb","击败妈妈1次。","Defeat Mom once."),
  a(5,"天启骑士","The Harbingers","击败妈妈1次。","Defeat Mom once."),
  a(6,"肉块","A Cube of Meat","击败妈妈1次。","Defeat Mom once.",73),
  a(7,"启示录","The Book of Revelations","击败任意天启骑士1次。","Defeat any Harbinger once.",78),
  a(8,"超凡升天","Transcendence","击败妈妈的心脏3次。","Defeat Mom's Heart three times.",20),
  a(9,"钉子","The Nail","用阿撒泻勒获得Boss Rush通关标记。","Complete Boss Rush as Azazel.",83),
  a(10,"25美分","A Quarter","击败妈妈的心脏8次。","Defeat Mom's Heart eight times.",74),
  a(11,"胎儿博士","A Fetus in a Jar","击败妈妈的心脏9次。","Defeat Mom's Heart nine times.",52),
  a(12,"小石头","A Small Rock","摧毁标记石头100次。","Destroy 100 tinted rocks.",90),
  a(13,"萌死戳的牙","Monstro's Tooth","通过第一章1次。","Complete Chapter 1 once.",86),
  a(14,"小胖蛆","Lil Chubby","通过第二章1次。","Complete Chapter 2 once.",88),
  a(15,"洛基的角","Loki's Horns","击败洛基1次。","Defeat Loki once.",87),
  a(16,"来自未来的东西！","Something From The Future!","通过地下室40次。","Complete the Basement 40 times."),
  a(17,"可爱的家伙","Something Cute","通过第二章30次。","Complete Chapter 2 thirty times."),
  a(18,"粘粘的家伙","Something Sticky","通过深牢20次。","Complete the Depths 20 times."),
  a(19,"超级绷带女孩","Super Bandage Girl","生成1个4级绷带妹。","Create a level-four Bandage Girl.",92),
  a(20,"圣遗物","The Relic","用抹大拉获得以撒通关标记。","Defeat Isaac as Magdalene.",98),
  a(21,"硬币袋","The Coin Bag","用该隐获得以撒通关标记。","Defeat Isaac as Cain.",94),
  a(22,"七原罪之书","The Book of Sin","分别击败七种致命罪孽。","Defeat each of the seven Deadly Sins.",97),
  a(23,"吉什宝宝","Little Gish","击败吉什1次。","Defeat Gish once.",99),
  a(24,"史蒂文宝宝","Little Steven","击败史蒂文1次。","Defeat Steven once.",100),
  a(25,"查德宝宝","Little C.H.A.D.","击败查德1次。","Defeat C.H.A.D. once.",96),
  a(26,"游戏掌机","The Gamekid","进入10个赌博房。","Enter ten Arcades.",93),
  a(27,"光环","The Halo","使用圣经击败妈妈、妈妈的心脏或它还活着。","Use the Bible to defeat Mom, Mom's Heart, or It Lives.",101),
  a(28,"大爆弹先生","Mr. Mega!","摧毁标记石头10次。","Destroy ten tinted rocks.",106),
  a(29,"六面骰","The D6","用???获得以撒通关标记。","Defeat Isaac as ???.",105),
  a(30,"剪刀","The Scissors","统计数据中的死亡次数达到100次。","Reach 100 deaths in the statistics.",325),
  a(31,"寄生虫","The Parasite","在一局游戏中，拾取2个死亡标签道具。","Collect two Dead Things-tagged items in one run.",104),
  a(32,"???","???","击败妈妈的心脏10次。","Defeat Mom's Heart ten times."),
  a(33,"一切都好可怕！！！","Everything is Terrible!!!","击败妈妈的心脏5次。","Defeat Mom's Heart five times."),
  a(34,"它还活着！","It Lives!","击败妈妈的心脏11次。","Defeat Mom's Heart eleven times."),
  a(35,"妈妈的美瞳","Mom's Contact","在一局游戏中，拾取3个妈妈标签道具。","Collect three Mom-tagged items in one run.",110),
  a(36,"死灵之书","The Necronomicon","使用XIII-死亡4次。","Use the XIII - Death card four times.",35),
  a(37,"地下室小子","Basement Boy","在不受到伤害的情况下通过第一章。","Complete Chapter 1 without taking damage."),
  a(38,"探窟小子","Spelunker Boy","在不受到伤害的情况下通过第二章。","Complete Chapter 2 without taking damage."),
  a(39,"黑暗小子","Dark Boy","在不受到伤害的情况下通过第三章。","Complete Chapter 3 without taking damage."),
  a(40,"妈宝小子","Mama's Boy","在不受到伤害的情况下通过第四章。","Complete Chapter 4 without taking damage."),
  a(41,"黄金大神","Golden God","分别击败???和羔羊1次。","Defeat ??? and The Lamb once each."),
  a(42,"夏娃","Eve","在不拾取心的情况下连续通过两层。","Complete two consecutive floors without collecting hearts."),
  a(43,"妈妈的菜刀","Mom's Knife","用以撒获得撒但通关标记。","Defeat Satan as Isaac.",114),
  a(44,"剃刀片","The Razor","用夏娃获得撒但通关标记。","Defeat Satan as Eve.",126),
  a(45,"守护天使","Guardian Angel","用抹大拉获得撒但通关标记。","Defeat Satan as Magdalene.",112),
  a(46,"炸弹袋","The Bomb Bag","用该隐获得撒但通关标记。","Defeat Satan as Cain.",131),
  a(47,"恶魔宝宝","A Demon Baby","用阿撒泻勒获得羔羊通关标记。","Defeat The Lamb as Azazel.",113),
  a(48,"遗忘药","A Forget Me Now","用???获得撒但通关标记。","Defeat Satan as ???.",127),
  a(49,"二十面骰！","The D20!","用以撒获得???通关标记。","Defeat ??? as Isaac.",166),
  a(50,"凯尔特十字","The Celtic Cross","用抹大拉获得???通关标记。","Defeat ??? as Magdalene.",162)
}

local observations = {
  achievement_1={kind="player", values={1}},       -- Magdalene
  achievement_2={kind="player", values={2}},       -- Cain
  achievement_3={kind="player", values={3}},       -- Judas
  achievement_4={kind="stage", values={7,8}},      -- Womb/Utero floors
  achievement_5={kind="boss", values={{63},{64},{65},{66}}},
  achievement_16={kind="boss", values={{79,1}}},   -- Steven
  achievement_17={kind="boss", values={{28,1}}},   -- C.H.A.D.
  achievement_18={kind="boss", values={{43,1}}},   -- Gish
  achievement_32={kind="player", values={4}},      -- ???
  achievement_34={kind="boss", values={{78,1}}},   -- It Lives
  achievement_42={kind="player", values={5}}       -- Eve
}
for _, goal in ipairs(achievements) do goal.observation=observations[goal.id] end

return achievements
