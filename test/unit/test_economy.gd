extends GutTest

var economy: Economy

func before_each() -> void:
	economy = Economy.new()

func test_starting_values() -> void:
	assert_eq(economy.gold, 120)
	assert_eq(economy.lives, 20)
	assert_eq(economy.summons_done, 0)

func test_summon_cost_increases_within_a_wave() -> void:
	var first := economy.summon_cost()
	economy.pay_summon()
	var second := economy.summon_cost()
	economy.pay_summon()
	assert_gt(second, first, "同一波內每買一次就該貴一點")
	assert_gt(economy.summon_cost(), second)

func test_new_wave_resets_the_within_wave_surcharge() -> void:
	# 波內加成若不重置，費用就會回到舊版那種二次成長，
	# 玩家中期買不起任何東西，階級再也推不上去。
	for i in 6:
		economy.pay_summon()
	var late_in_wave := economy.summon_cost()
	economy.set_wave(2)
	assert_lt(economy.summon_cost(), late_in_wave, "換波後費用應該回到基準")

func test_summon_cost_base_grows_with_wave() -> void:
	economy.set_wave(1)
	var first := economy.summon_cost()
	economy.set_wave(80)
	assert_gt(economy.summon_cost(), first * 2,
		"費用基準要跟著波次成長，否則後期召喚變得毫無代價")

func test_income_outgrows_summon_cost() -> void:
	# 這是整個長局的前提：收入成長必須快過召喚費用，玩家才能在後期
	# 一波塞滿棋盤。兩者同速的話中期就卡死，實測會停在第 20 波以內。
	assert_gt(Economy.KILL_REWARD_GROWTH, Economy.SUMMON_WAVE_GROWTH)
	assert_gt(Economy.WAVE_REWARD_GROWTH, Economy.SUMMON_WAVE_GROWTH)

func test_pay_summon_deducts_gold() -> void:
	economy.pay_summon()
	assert_eq(economy.gold, 100, "120 減去第一次的 20")

func test_cannot_afford_when_gold_below_cost() -> void:
	economy.gold = 19
	assert_false(economy.can_afford_summon())
	economy.gold = 20
	assert_true(economy.can_afford_summon())

func test_salvage_refund_grows_with_tier() -> void:
	assert_eq(Economy.salvage_refund(1), 12)
	assert_eq(Economy.salvage_refund(2), 24)
	assert_gt(Economy.salvage_refund(6), Economy.salvage_refund(5))

func test_rewards_start_small() -> void:
	assert_eq(Economy.kill_reward(1), 2)
	assert_eq(Economy.wave_reward(1), 15)

func test_rewards_grow_geometrically() -> void:
	# 召喚費用是線性成長，獎勵必須是等比，玩家才可能在後期
	# 一波買下好幾隻、把階級推上去。兩者都線性的話中期就卡死。
	assert_gt(Economy.kill_reward(100), Economy.kill_reward(50) * 5)
	assert_gt(Economy.wave_reward(100), Economy.wave_reward(50) * 5)

func test_rewards_are_monotonic() -> void:
	for wave in range(1, 120):
		assert_gte(Economy.kill_reward(wave + 1), Economy.kill_reward(wave))
		assert_gte(Economy.wave_reward(wave + 1), Economy.wave_reward(wave))

func test_losing_all_lives_is_defeat() -> void:
	assert_false(economy.is_defeated())
	economy.lose_lives(20)
	assert_true(economy.is_defeated())

func test_lives_never_go_below_zero() -> void:
	# 大盜一次偷 3 點，剩 1 點生命時不該變成負數，否則 HUD 會顯示負值
	economy.lives = 1
	economy.lose_lives(3)
	assert_eq(economy.lives, 0)

func test_reset_restores_starting_state() -> void:
	economy.pay_summon()
	economy.lose_lives(5)
	economy.reset()
	assert_eq(economy.gold, 120)
	assert_eq(economy.lives, 20)
	assert_eq(economy.summons_done, 0)
