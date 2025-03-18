local ChallengeComponent = Class(function(self, inst)
    self.inst = inst
    self.data = nil
end)

function ChallengeComponent:SetData(data)
    self.data = data
    print("挑战数据已保存")
end

function ChallengeComponent:GetData()
    return self.data
end

function ChallengeComponent:OnSave()
    return self.data
end

function ChallengeComponent:OnLoad(data)
    self.data = data
    print("挑战数据已加载")
end

return ChallengeComponent 