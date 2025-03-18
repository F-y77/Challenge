local ChallengeSaver = Class(function(self, inst)
    self.inst = inst
    self.challenge_data = nil
end)

function ChallengeSaver:SetData(data)
    self.challenge_data = data
end

function ChallengeSaver:GetData()
    return self.challenge_data
end

function ChallengeSaver:OnSave()
    return self.challenge_data
end

function ChallengeSaver:OnLoad(data)
    self.challenge_data = data
end

return ChallengeSaver 