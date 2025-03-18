-- 每日挑战模组
local TheInput = GLOBAL.TheInput
local STRINGS = GLOBAL.STRINGS

-- 挑战状态
local CHALLENGE_STATE = {
    NONE = 0,
    ACTIVE = 1,
    COMPLETED = 2,
    FAILED = 3
}

-- 当前挑战信息
local current_challenge = {
    title = "",
    description = "",
    state = CHALLENGE_STATE.NONE,
    start_time = nil,
    end_time = nil,
    challenge_type = nil,
    target = nil,
    reward = nil,
    punishment = nil,
    is_nightmare = false
}

-- 挑战类型列表
local CHALLENGE_TYPES = {
    KILL_BOSS = 1
}

-- 可能的挑战目标
local CHALLENGE_TARGETS = {
    -- 巨鹿挑战
    {type = CHALLENGE_TYPES.KILL_BOSS, target = "deerclops", title = "巨鹿挑战", description = "在一天内击杀巨鹿", reward = "获得永久增加2点保暖值和1.5%攻击力", punishment = "体温降低50度"},
    -- 巨鹿噩梦版本
    {type = CHALLENGE_TYPES.KILL_BOSS, target = "deerclops", title = "噩梦巨鹿挑战", description = "在不使用护甲的情况下，半天内击杀巨鹿", reward = "获得永久增加4点保暖值和3%攻击力", punishment = "体温降低100度", is_nightmare = true},
    -- 龙蝇挑战
    {type = CHALLENGE_TYPES.KILL_BOSS, target = "dragonfly", title = "龙蝇挑战", description = "击杀龙蝇和15只岩浆虫", reward = "获得永久增加10点抗火、1%攻击力和2个龙蝇皮", punishment = "体温增加50度"},
    -- 龙蝇噩梦版本
    {type = CHALLENGE_TYPES.KILL_BOSS, target = "dragonfly", title = "噩梦龙蝇挑战", description = "在1/3天内击杀龙蝇和15只岩浆虫", reward = "获得永久增加20点抗火、2%攻击力和4个龙蝇皮", punishment = "体温增加100度", is_nightmare = true}
}

-- 刷新挑战的冷却时间
local last_refresh_day = -10  -- 初始设为-10，这样游戏开始就可以刷新

-- 保存挑战进度
local function SaveChallengeProgress()
    if not GLOBAL.TheWorld.ismastersim then return end
    
    local data = {
        challenge = current_challenge,
        player_tags = {}
    }
    
    -- 在多人游戏中，保存所有玩家的标签
    for i, v in ipairs(GLOBAL.AllPlayers) do
        local player_data = {
            userid = v.userid,
            tags = {}
        }
        
        for _, tag in ipairs({"shadowmaster", "beefriend", "blowdartmaster", "dailyhealer", 
                              "spiderwhisperer", "ancientbuilder", "fireimmune", "beefoe", 
                              "easyburning", "pacifist", "spidertarget", "ancientguardianfoe"}) do
            if v:HasTag(tag) then
                table.insert(player_data.tags, tag)
            end
        end
        
        table.insert(data.player_tags, player_data)
    end
    
    -- 保存到世界持久数据
    if GLOBAL.TheWorld.components.challengesaver then
        GLOBAL.TheWorld.components.challengesaver:SetData(data)
    end
end

-- 加载挑战进度
local function LoadChallengeProgress(data)
    if not data then return end
    
    if data.challenge then
        current_challenge = data.challenge
    end
    
    -- 在多人游戏中，为每个玩家加载正确的标签
    if data.player_tags then
        for i, player_data in ipairs(data.player_tags) do
            for _, player in ipairs(GLOBAL.AllPlayers) do
                if player.userid == player_data.userid then
                    for _, tag in ipairs(player_data.tags) do
                        player:AddTag(tag)
                    end
                    break
                end
            end
        end
    end
end

-- 生成新的每日挑战
local function GenerateDailyChallenge()
    local day = GLOBAL.TheWorld.state.cycles
    print("生成第 " .. day .. " 天的挑战")
    
    -- 随机选择一个挑战（只选择非噩梦版本）
    local available_challenges = {}
    for _, challenge in ipairs(CHALLENGE_TARGETS) do
        if not challenge.is_nightmare then
            table.insert(available_challenges, challenge)
        end
    end
    
    local challenge = available_challenges[math.random(#available_challenges)]
    
    print("选择了挑战: " .. challenge.title)
    
    current_challenge.title = challenge.title
    current_challenge.description = challenge.description
    current_challenge.state = CHALLENGE_STATE.NONE
    current_challenge.start_time = GLOBAL.GetTime()
    current_challenge.end_time = current_challenge.start_time + GLOBAL.TUNING.TOTAL_DAY_TIME  -- 一天的时间
    current_challenge.challenge_type = challenge.type
    current_challenge.target = challenge.target
    current_challenge.reward = challenge.reward
    current_challenge.punishment = challenge.punishment
    current_challenge.is_nightmare = false
    
    print("新的每日挑战已生成: " .. current_challenge.title)
    
    -- 通知所有玩家新挑战已生成
    for i, player in ipairs(GLOBAL.AllPlayers) do
        if player and player.components.talker then
            player.components.talker:Say("新的挑战已生成: " .. current_challenge.title)
        end
    end
    
    -- 保存挑战状态
    SaveChallengeProgress()
end

-- 检查挑战是否完成
local function CheckChallengeCompletion()
    if current_challenge.state ~= CHALLENGE_STATE.ACTIVE then
        return
    end
    
    -- 检查是否超时
    if GLOBAL.GetTime() > current_challenge.end_time then
        CompleteChallengeFailure()
    end
end

-- 升级为噩梦挑战
local function UpgradeToNightmareChallenge(player)
    if current_challenge.state ~= CHALLENGE_STATE.NONE then
        if player and player.components.talker then
            player.components.talker:Say("只能在接受挑战前升级为噩梦挑战！")
        end
        return
    end
    
    if current_challenge.is_nightmare then
        if player and player.components.talker then
            player.components.talker:Say("当前已经是噩梦挑战！")
        end
        return
    end
    
    -- 找到对应的噩梦挑战
    local nightmare_challenge = nil
    for _, challenge in ipairs(CHALLENGE_TARGETS) do
        if challenge.is_nightmare and challenge.target == current_challenge.target then
            nightmare_challenge = challenge
            break
        end
    end
    
    if nightmare_challenge then
        print("升级为噩梦挑战: " .. nightmare_challenge.title)
        
        current_challenge.title = nightmare_challenge.title
        current_challenge.description = nightmare_challenge.description
        current_challenge.reward = nightmare_challenge.reward
        current_challenge.punishment = nightmare_challenge.punishment
        current_challenge.is_nightmare = true
        
        -- 根据挑战类型设置时间
        if current_challenge.target == "deerclops" then
            -- 噩梦巨鹿挑战时间减半
            current_challenge.end_time = current_challenge.start_time + GLOBAL.TUNING.TOTAL_DAY_TIME / 2
        elseif current_challenge.target == "dragonfly" then
            -- 噩梦龙蝇挑战时间为1/3天
            current_challenge.end_time = current_challenge.start_time + GLOBAL.TUNING.TOTAL_DAY_TIME / 3
        end
        
        if player then
            if player.components.talker then
                player.components.talker:Say("挑战已升级为噩梦模式: " .. current_challenge.title)
            end
            
            -- 播放声音和特效
            player.SoundEmitter:PlaySound("dontstarve/common/nightmaretriumph_stinger")
            
            local fx = GLOBAL.SpawnPrefab("shadow_bishop_fx")
            if fx then
                fx.Transform:SetPosition(player.Transform:GetWorldPosition())
            end
        end
        
        -- 保存挑战状态
        SaveChallengeProgress()
    else
        print("找不到对应的噩梦挑战")
    end
end

-- 成功完成挑战
local function CompleteChallengeSuccess(player)
    if current_challenge.state == CHALLENGE_STATE.COMPLETED then
        print("挑战已经完成，不重复奖励")
        return -- 防止重复触发
    end
    
    print("挑战成功，发放奖励: " .. current_challenge.title)
    current_challenge.state = CHALLENGE_STATE.COMPLETED
    
    if player then
        -- 给予奖励
        if player.components.talker then
            player.components.talker:Say("挑战成功！" .. current_challenge.reward)
        end
        
        if current_challenge.target == "deerclops" then
            -- 巨鹿挑战奖励
            print("发放巨鹿挑战奖励")
            
            -- 1. 保暖值奖励
            if player.components.temperature then
                local insulation_bonus = current_challenge.is_nightmare and 4 or 2
                
                -- 添加保暖值标签
                local tag_name = "insulation_bonus_" .. tostring(insulation_bonus)
                if not player:HasTag(tag_name) then
                    player:AddTag(tag_name)
                    print("添加保暖值标签: " .. tag_name)
                end
            else
                print("玩家没有temperature组件")
            end
            
            -- 2. 攻击力奖励
            if player.components.combat then
                local damage_bonus = current_challenge.is_nightmare and 1.03 or 1.015
                local original_damage = player.components.combat.damagemultiplier or 1
                player.components.combat.damagemultiplier = original_damage * damage_bonus
                print("攻击力从 " .. original_damage .. " 增加到 " .. player.components.combat.damagemultiplier)
            else
                print("玩家没有combat组件")
            end
        elseif current_challenge.target == "dragonfly" then
            -- 龙蝇挑战奖励
            print("发放龙蝇挑战奖励")
            
            -- 1. 抗火奖励
            local fire_resist_bonus = current_challenge.is_nightmare and 20 or 10
            local tag_name = "fire_resist_bonus_" .. tostring(fire_resist_bonus)
            if not player:HasTag(tag_name) then
                player:AddTag(tag_name)
                print("添加抗火标签: " .. tag_name)
            end
            
            -- 2. 攻击力奖励
            if player.components.combat then
                local damage_bonus = current_challenge.is_nightmare and 1.02 or 1.01
                local original_damage = player.components.combat.damagemultiplier or 1
                player.components.combat.damagemultiplier = original_damage * damage_bonus
                print("攻击力从 " .. original_damage .. " 增加到 " .. player.components.combat.damagemultiplier)
            else
                print("玩家没有combat组件")
            end
            
            -- 3. 给予龙蝇皮
            if player.components.inventory then
                local scales_count = current_challenge.is_nightmare and 4 or 2
                for i = 1, scales_count do
                    local scales = GLOBAL.SpawnPrefab("dragon_scales")
                    if scales then
                        player.components.inventory:GiveItem(scales)
                    end
                end
                print("给予龙蝇皮 x" .. scales_count)
            else
                print("玩家没有inventory组件")
            end
        end
        
        -- 给予一个视觉反馈
        local fx = GLOBAL.SpawnPrefab("explode_small")
        if fx then
            fx.Transform:SetPosition(player.Transform:GetWorldPosition())
        end
        
        -- 刷新玩家状态
        player:PushEvent("ms_playerreroll")
        
        -- 保存挑战完成状态
        SaveChallengeProgress()
        print("挑战进度已保存")
    else
        print("无法找到玩家，无法发放奖励")
    end
end

-- 挑战失败
local function CompleteChallengeFailure(player)
    if current_challenge.state == CHALLENGE_STATE.FAILED then
        return -- 防止重复触发
    end
    
    current_challenge.state = CHALLENGE_STATE.FAILED
    
    if player then
        -- 实施惩罚
        if player.components.talker then
            player.components.talker:Say("挑战失败！" .. current_challenge.punishment)
        end
        
        if current_challenge.target == "deerclops" then
            -- 巨鹿挑战惩罚 - 降低体温
            if player.components.temperature then
                local temp_penalty = current_challenge.is_nightmare and 100 or 50
                local current_temp = player.components.temperature:GetCurrent()
                player.components.temperature:SetTemperature(current_temp - temp_penalty)
                print("体温从 " .. current_temp .. " 降低到 " .. (current_temp - temp_penalty))
                
                -- 添加视觉效果
                local fx = GLOBAL.SpawnPrefab("icespike_fx_1")
                if fx then
                    fx.Transform:SetPosition(player.Transform:GetWorldPosition())
                end
                
                -- 播放冰冻音效
                player.SoundEmitter:PlaySound("dontstarve/common/freezecreature")
            end
        elseif current_challenge.target == "dragonfly" then
            -- 龙蝇挑战惩罚 - 增加体温
            if player.components.temperature then
                local temp_penalty = current_challenge.is_nightmare and 100 or 50
                local current_temp = player.components.temperature:GetCurrent()
                player.components.temperature:SetTemperature(current_temp + temp_penalty)
                print("体温从 " .. current_temp .. " 增加到 " .. (current_temp + temp_penalty))
                
                -- 添加视觉效果
                local fx = GLOBAL.SpawnPrefab("firesplash_fx")
                if fx then
                    fx.Transform:SetPosition(player.Transform:GetWorldPosition())
                end
                
                -- 播放火焰音效
                player.SoundEmitter:PlaySound("dontstarve/common/fireAddFuel")
            end
        end
        
        -- 保存挑战失败状态
        SaveChallengeProgress()
    end
end

-- 接受挑战
local function AcceptChallenge(player)
    if current_challenge.state == CHALLENGE_STATE.NONE then
        print("玩家接受挑战: " .. current_challenge.title)
        current_challenge.state = CHALLENGE_STATE.ACTIVE
        
        if player then
            -- 视觉和声音反馈
            if player.components.talker then
                player.components.talker:Say("挑战已接受: " .. current_challenge.title)
            end
            
            -- 播放声音
            player.SoundEmitter:PlaySound("dontstarve/HUD/research_available")
            
            -- 显示特效
            local fx = GLOBAL.SpawnPrefab("statue_transition")
            if fx then
                fx.Transform:SetPosition(player.Transform:GetWorldPosition())
            end
            
            -- 显示挑战描述
            GLOBAL.TheNet:Announce("挑战开始: " .. current_challenge.title .. " - " .. current_challenge.description)
            
            -- 根据挑战类型生成不同的Boss
            if GLOBAL.TheWorld.ismastersim then
                local x, y, z = player.Transform:GetWorldPosition()
                
                if current_challenge.target == "deerclops" then
                    -- 在玩家前方20-30单位的位置生成巨鹿
                    local angle = player.Transform:GetRotation() * GLOBAL.DEGREES
                    local spawn_distance = math.random(20, 30)
                    local spawn_x = x + spawn_distance * math.cos(angle)
                    local spawn_z = z - spawn_distance * math.sin(angle)
                    
                    -- 确保生成位置是有效的
                    local is_valid_pos = GLOBAL.TheWorld.Map:IsPassableAtPoint(spawn_x, 0, spawn_z)
                    if not is_valid_pos then
                        -- 如果位置无效，尝试在玩家周围找一个有效位置
                        for attempt = 1, 8 do
                            local test_angle = math.random() * 2 * math.pi
                            local test_x = x + spawn_distance * math.cos(test_angle)
                            local test_z = z + spawn_distance * math.sin(test_angle)
                            if GLOBAL.TheWorld.Map:IsPassableAtPoint(test_x, 0, test_z) then
                                spawn_x, spawn_z = test_x, test_z
                                is_valid_pos = true
                                break
                            end
                        end
                    end
                    
                    if is_valid_pos then
                        print("在位置 (" .. spawn_x .. ", " .. spawn_z .. ") 生成巨鹿")
                        local deerclops = GLOBAL.SpawnPrefab("deerclops")
                        if deerclops then
                            deerclops.Transform:SetPosition(spawn_x, 0, spawn_z)
                            -- 让巨鹿立即注意到玩家
                            if deerclops.components.combat then
                                deerclops.components.combat:SetTarget(player)
                            end
                            
                            -- 添加特效
                            local spawn_fx = GLOBAL.SpawnPrefab("statue_transition_2")
                            if spawn_fx then
                                spawn_fx.Transform:SetPosition(spawn_x, 0, spawn_z)
                            end
                        else
                            print("无法生成巨鹿")
                        end
                    else
                        print("无法找到有效的生成位置")
                        if player.components.talker then
                            player.components.talker:Say("无法找到合适的位置生成巨鹿，请到开阔地带重试！")
                        end
                        current_challenge.state = CHALLENGE_STATE.NONE
                        return
                    end
                elseif current_challenge.target == "dragonfly" then
                    -- 在玩家前方30-40单位的位置生成龙蝇
                    local angle = player.Transform:GetRotation() * GLOBAL.DEGREES
                    local spawn_distance = math.random(30, 40)
                    local spawn_x = x + spawn_distance * math.cos(angle)
                    local spawn_z = z - spawn_distance * math.sin(angle)
                    
                    -- 确保生成位置是有效的
                    local is_valid_pos = GLOBAL.TheWorld.Map:IsPassableAtPoint(spawn_x, 0, spawn_z)
                    if not is_valid_pos then
                        -- 如果位置无效，尝试在玩家周围找一个有效位置
                        for attempt = 1, 8 do
                            local test_angle = math.random() * 2 * math.pi
                            local test_x = x + spawn_distance * math.cos(test_angle)
                            local test_z = z + spawn_distance * math.sin(test_angle)
                            if GLOBAL.TheWorld.Map:IsPassableAtPoint(test_x, 0, test_z) then
                                spawn_x, spawn_z = test_x, test_z
                                is_valid_pos = true
                                break
                            end
                        end
                    end
                    
                    if is_valid_pos then
                        print("在位置 (" .. spawn_x .. ", " .. spawn_z .. ") 生成龙蝇")
                        local dragonfly = GLOBAL.SpawnPrefab("dragonfly")
                        if dragonfly then
                            dragonfly.Transform:SetPosition(spawn_x, 0, spawn_z)
                            -- 让龙蝇立即注意到玩家
                            if dragonfly.components.combat then
                                dragonfly.components.combat:SetTarget(player)
                            end
                            
                            -- 添加特效
                            local spawn_fx = GLOBAL.SpawnPrefab("statue_transition_2")
                            if spawn_fx then
                                spawn_fx.Transform:SetPosition(spawn_x, 0, spawn_z)
                            end
                            
                            -- 生成15只岩浆虫
                            for i = 1, 15 do
                                local offset_angle = math.random() * 2 * math.pi
                                local offset_distance = math.random(5, 15)
                                local lavae_x = spawn_x + offset_distance * math.cos(offset_angle)
                                local lavae_z = spawn_z + offset_distance * math.sin(offset_angle)
                                
                                if GLOBAL.TheWorld.Map:IsPassableAtPoint(lavae_x, 0, lavae_z) then
                                    local lavae = GLOBAL.SpawnPrefab("lavae")
                                    if lavae then
                                        lavae.Transform:SetPosition(lavae_x, 0, lavae_z)
                                        -- 让岩浆虫立即注意到玩家
                                        if lavae.components.combat then
                                            lavae.components.combat:SetTarget(player)
                                        end
                                    end
                                end
                            end
                        else
                            print("无法生成龙蝇")
                        end
                    else
                        print("无法找到有效的生成位置")
                        if player.components.talker then
                            player.components.talker:Say("无法找到合适的位置生成龙蝇，请到开阔地带重试！")
                        end
                        current_challenge.state = CHALLENGE_STATE.NONE
                        return
                    end
                end
            end
        end
        
        -- 保存挑战状态
        SaveChallengeProgress()
        print("挑战状态已保存")
    else
        print("无法接受挑战，当前状态: " .. tostring(current_challenge.state))
    end
end

-- 拒绝挑战
local function RejectChallenge(player)
    if current_challenge.state == CHALLENGE_STATE.NONE then
        if player and player.components.talker then
            player.components.talker:Say("拒绝挑战")
        end
    end
end

-- 显示挑战信息
local function ShowChallengeInfo(player)
    if player and player.components.talker then
        local status = ""
        if current_challenge.state == CHALLENGE_STATE.NONE then
            status = "未接受"
        elseif current_challenge.state == CHALLENGE_STATE.ACTIVE then
            status = "进行中"
        elseif current_challenge.state == CHALLENGE_STATE.COMPLETED then
            status = "已完成"
        elseif current_challenge.state == CHALLENGE_STATE.FAILED then
            status = "已失败"
        end
        
        local nightmare_text = current_challenge.is_nightmare and "【噩梦模式】" or ""
        
        player.components.talker:Say(
            nightmare_text .. "挑战: " .. current_challenge.title .. 
            "\n描述: " .. current_challenge.description .. 
            "\n状态: " .. status .. 
            "\n奖励: " .. current_challenge.reward .. 
            "\n惩罚: " .. current_challenge.punishment
        )
    end
end

-- 刷新当天挑战
local function RefreshDailyChallenge(player)
    local current_day = GLOBAL.TheWorld.state.cycles
    
    -- 检查冷却时间
    if current_day - last_refresh_day < 10 then
        local days_left = 10 - (current_day - last_refresh_day)
        if player and player.components.talker then
            player.components.talker:Say("刷新挑战还需要等待 " .. days_left .. " 天")
        end
        return
    end
    
    -- 如果挑战正在进行中，不允许刷新
    if current_challenge.state == CHALLENGE_STATE.ACTIVE then
        if player and player.components.talker then
            player.components.talker:Say("挑战正在进行中，无法刷新")
        end
        return
    end
    
    -- 更新冷却时间
    last_refresh_day = current_day
    
    -- 目前只有一个挑战，所以只是重置当前挑战
    GenerateDailyChallenge()
    
    if player and player.components.talker then
        player.components.talker:Say("挑战已刷新！下次刷新需要等待10天")
        
        -- 播放刷新音效和特效
        player.SoundEmitter:PlaySound("dontstarve/common/together/celestial_orb/active")
        
        local fx = GLOBAL.SpawnPrefab("pandorachest_reset")
        if fx then
            fx.Transform:SetPosition(player.Transform:GetWorldPosition())
        end
    end
end

-- 监听按键事件
TheInput:AddKeyHandler(function(key, down)
    if not down then return end
    
    local player = GLOBAL.ThePlayer
    if not player then return end
    
    if key == GLOBAL.KEY_F1 then
        ShowChallengeInfo(player)
    elseif key == GLOBAL.KEY_F2 then
        AcceptChallenge(player)
    elseif key == GLOBAL.KEY_F3 then
        UpgradeToNightmareChallenge(player)
    elseif key == GLOBAL.KEY_F4 then
        RefreshDailyChallenge(player)
    end
end)

-- 监听白天开始事件，生成新的挑战
AddPrefabPostInit("world", function(inst)
    if GLOBAL.TheWorld.ismastersim then
        -- 记录上一次生成挑战的天数
        local last_challenge_day = -7
        
        -- 每秒检查一次是否需要刷新挑战
        inst:DoPeriodicTask(1, function()
            local current_day = GLOBAL.TheWorld.state.cycles
            
            -- 如果是新的一周且是白天，生成新挑战
            if current_day > last_challenge_day and (current_day % 7 == 0) and GLOBAL.TheWorld.state.isday then
                print("新的一周，生成新挑战")
                last_challenge_day = current_day
                GenerateDailyChallenge()
            end
            
            -- 检查挑战完成情况
            CheckChallengeCompletion()
        end)
        
        -- 也保留原来的白天事件监听，以防万一
        inst:ListenForEvent("daytime", function(inst)
            local current_day = GLOBAL.TheWorld.state.cycles
            if current_day % 7 == 0 then
                print("白天事件触发，生成新挑战")
                GenerateDailyChallenge()
            end
        end)
    end
end)

-- 确保在洞穴世界也能正确工作
AddPrefabPostInit("cave", function(inst)
    if GLOBAL.TheWorld.ismastersim then
        -- 记录上一次生成挑战的天数
        local last_challenge_day = -7
        
        -- 每秒检查一次是否需要刷新挑战
        inst:DoPeriodicTask(1, function()
            local current_day = GLOBAL.TheWorld.state.cycles
            
            -- 如果是新的一周且是白天，生成新挑战
            if current_day > last_challenge_day and (current_day % 7 == 0) then
                print("洞穴：新的一周，生成新挑战")
                last_challenge_day = current_day
                GenerateDailyChallenge()
            end
            
            -- 检查挑战完成情况
            CheckChallengeCompletion()
        end)
    end
end)

-- 游戏开始时生成一次挑战
AddSimPostInit(function()
    GenerateDailyChallenge()
end)

-- 添加世界组件来保存/加载挑战数据
AddPrefabPostInit("world", function(inst)
    if GLOBAL.TheWorld.ismastersim then
        inst:AddComponent("challengesaver")
        
        inst:ListenForEvent("ms_savechallengedata", function(world, data)
            if world.components.challengesaver then
                world.components.challengesaver:SetData(data)
            end
        end)
        
        -- 加载时恢复数据
        inst:DoTaskInTime(1, function()
            if inst.components.challengesaver then
                local data = inst.components.challengesaver:GetData()
                if data then
                    LoadChallengeProgress(data)
                end
            end
        end)
    end
end)

-- 添加Boss死亡监听
local function AddBossDeathListeners()
    -- 监听巨鹿死亡
    AddPrefabPostInit("deerclops", function(inst)
        if GLOBAL.TheWorld.ismastersim then
            inst:ListenForEvent("death", function(inst, data)
                print("巨鹿死亡事件触发")
                
                if current_challenge.state == CHALLENGE_STATE.ACTIVE and 
                   current_challenge.challenge_type == CHALLENGE_TYPES.KILL_BOSS and
                   current_challenge.target == "deerclops" then
                    
                    print("当前挑战是巨鹿挑战，检查条件")
                    
                    -- 检查是否是玩家击杀的
                    local player = data.afflicter
                    if player and player:HasTag("player") then
                        print("击杀者是玩家: " .. tostring(player))
                        
                        -- 如果是噩梦模式，检查是否穿戴护甲
                        if current_challenge.is_nightmare then
                            local has_armor = false
                            if player.components.inventory then
                                -- 检查身体装备
                                local body = player.components.inventory:GetEquippedItem(GLOBAL.EQUIPSLOTS.BODY)
                                if body and body.components.armor then
                                    has_armor = true
                                    print("玩家装备了护甲: " .. tostring(body.prefab))
                                end
                            end
                            
                            if has_armor then
                                print("噩梦挑战失败：使用了护甲")
                                if player.components.talker then
                                    player.components.talker:Say("你使用了护甲，噩梦挑战失败！")
                                end
                                CompleteChallengeFailure(player)
                                return
                            end
                        end
                        
                        CompleteChallengeSuccess(player)
                    else
                        print("击杀者不是玩家或无法识别: " .. tostring(data.afflicter))
                        -- 如果无法确定是谁击杀的，默认成功
                        if #GLOBAL.AllPlayers > 0 then
                            local player = GLOBAL.AllPlayers[1]
                            print("默认将挑战标记为成功")
                            CompleteChallengeSuccess(player)
                        end
                    end
                else
                    print("当前挑战不是巨鹿挑战或状态不正确")
                    print("当前挑战状态: " .. tostring(current_challenge.state))
                    print("当前挑战类型: " .. tostring(current_challenge.challenge_type))
                    print("当前挑战目标: " .. tostring(current_challenge.target))
                end
            end)
        end
    end)
    
    -- 监听龙蝇死亡
    AddPrefabPostInit("dragonfly", function(inst)
        if GLOBAL.TheWorld.ismastersim then
            inst:ListenForEvent("death", function(inst, data)
                print("龙蝇死亡事件触发")
                
                if current_challenge.state == CHALLENGE_STATE.ACTIVE and 
                   current_challenge.challenge_type == CHALLENGE_TYPES.KILL_BOSS and
                   current_challenge.target == "dragonfly" then
                    
                    print("当前挑战是龙蝇挑战，检查条件")
                    
                    -- 检查是否是玩家击杀的
                    local player = data.afflicter
                    if player and player:HasTag("player") then
                        print("击杀者是玩家: " .. tostring(player))
                        CompleteChallengeSuccess(player)
                    else
                        print("击杀者不是玩家或无法识别: " .. tostring(data.afflicter))
                        -- 如果无法确定是谁击杀的，默认成功
                        if #GLOBAL.AllPlayers > 0 then
                            local player = GLOBAL.AllPlayers[1]
                            print("默认将挑战标记为成功")
                            CompleteChallengeSuccess(player)
                        end
                    end
                else
                    print("当前挑战不是龙蝇挑战或状态不正确")
                    print("当前挑战状态: " .. tostring(current_challenge.state))
                    print("当前挑战类型: " .. tostring(current_challenge.challenge_type))
                    print("当前挑战目标: " .. tostring(current_challenge.target))
                end
            end)
        end
    end)
end

-- 添加所有监听器
AddBossDeathListeners()

-- 监听玩家死亡事件
AddPlayerPostInit(function(player)
    if GLOBAL.TheWorld.ismastersim then
        player:ListenForEvent("death", function(inst, data)
            if current_challenge.state == CHALLENGE_STATE.ACTIVE then
                print("玩家死亡，挑战失败")
                CompleteChallengeFailure(player)
            end
        end)
        
        -- 添加保暖值和抗火效果
        player:ListenForEvent("temperaturedelta", function(inst)
            if player.components.temperature then
                -- 保暖值效果
                local insulation = 0
                
                -- 检查玩家是否有保暖值标签
                for bonus = 1, 10 do  -- 支持1-10点保暖值
                    local tag_name = "insulation_bonus_" .. tostring(bonus)
                    if player:HasTag(tag_name) then
                        insulation = insulation + bonus
                    end
                end
                
                if insulation > 0 then
                    -- 应用保暖值效果
                    player.components.temperature.inherentinsulation = insulation
                end
                
                -- 抗火效果
                local fire_resist = 0
                
                -- 检查玩家是否有抗火标签
                for bonus = 1, 20 do  -- 支持1-20点抗火
                    local tag_name = "fire_resist_bonus_" .. tostring(bonus)
                    if player:HasTag(tag_name) then
                        fire_resist = fire_resist + bonus
                    end
                end
                
                if fire_resist > 0 then
                    -- 应用抗火效果（降低高温对玩家的影响）
                    player.components.temperature.inherentinsulation_heat = fire_resist
                end
            end
        end)
    end
end)

-- 注册挑战保存组件
AddModRPCHandler("DailyChallenge", "SaveChallenge", function(player, data_string)
    if GLOBAL.TheWorld.ismastersim then
        local success, data = pcall(function() return GLOBAL.json.decode(data_string) end)
        if success and data then
            print("通过RPC保存挑战数据")
            if GLOBAL.TheWorld.components.challengesaver then
                GLOBAL.TheWorld.components.challengesaver:SetData(data)
            end
        else
            print("RPC数据解析失败")
        end
    end
end) 