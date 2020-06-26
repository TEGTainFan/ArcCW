function SWEP:Reload()
    if self:GetOwner():IsNPC() then
        return
    end

    if self:GetNextPrimaryFire() >= CurTime() then return end
    if self:GetNextSecondaryFire() > CurTime() then return end

    if self.Throwing then return end
    if self.PrimaryBash then return end

    if self:GetNWBool("ubgl") then
        self:ReloadUBGL()
        return
    end

    if self:Ammo1() <= 0 then return end

    self.LastClip1 = self:Clip1()

    local reserve = self:Ammo1()

    reserve = reserve + self:Clip1()

    local clip = self:GetCapacity()

    local chamber = math.Clamp(self:Clip1(), 0, self:GetBuff_Override("Override_ChamberSize") or self.ChamberSize)

    local load = math.Clamp(clip + chamber, 0, reserve)

    if load <= self:Clip1() then return end

    if !self.ReloadInSights then
        self:ExitSights()
        self.Sighted = false
    end

    self:SetNWBool("reqend", false)
    self.BurstCount = 0

    local shouldshotgunreload = self.ShotgunReload

    if self:GetBuff_Override("Override_ShotgunReload") then
        shouldshotgunreload = true
    end

    if self:GetBuff_Override("Override_ShotgunReload") == false then
        shouldshotgunreload = false
    end

    if self.HybridReload or self:GetBuff_Override("Override_HybridReload") then
        if self:Clip1() == 0 then
            shouldshotgunreload = false
        else
            shouldshotgunreload = true
        end
    end

    local mult = self:GetBuff_Mult("Mult_ReloadTime")

    if shouldshotgunreload then
        local anim = "sgreload_start"
        local insertcount = 0

        local empty = (self:Clip1() == 0) or self:GetNWBool("cycle", false)

        if self.Animations.sgreload_start_empty and empty then
            anim = "sgreload_start_empty"
            empty = false

            insertcount = (self.Animations.sgreload_start_empty or {}).RestoreAmmo or 1
        end

        anim = self:GetBuff_Hook("Hook_SelectReloadAnimation", anim) or anim

        self:GetOwner():SetAmmo(self:Ammo1() - insertcount, self.Primary.Ammo)
        self:SetClip1(self:Clip1() + insertcount)

        self:PlayAnimation(anim, mult, true, 0, true)

        self:SetTimer(self:GetAnimKeyTime(anim) * mult,
        function()
            self:ReloadInsert(empty)
        end)
    else
        local anim = self:SelectReloadAnimation()

        if self:Clip1() == 0 then
            self:SetNWBool("cycle", false)
        end

        if !self.Animations[anim] then print("Invalid animation \"" .. anim .. "\"") return end

        self:PlayAnimation(anim, mult, true, 0, true)
        self:SetTimer(self:GetAnimKeyTime(anim) * mult,
        function()
            self:SetNWBool("reloading", false)
        end)
        self.CheckpointAnimation = anim
        self.CheckpointTime = 0

        if SERVER then
            self:GetOwner():GiveAmmo(self:Clip1(), self.Primary.Ammo, true)
            self:SetClip1(0)
            self:TakePrimaryAmmo(load)
            self:SetClip1(load)
        end

        if self.RevolverReload then
            self.LastClip1 = load
        end
    end

    self:SetNWBool("reloading", true)

    self.Primary.Automatic = false
end

local lastframeclip1 = 0

SWEP.LastClipOutTime = 0

function SWEP:GetVisualBullets()
    if self.LastClipOutTime > CurTime() then
        return self.LastClip1_B or self:Clip1()
    else
        self.LastClip1_B = self:Clip1()

        return self:Clip1()
    end
end

function SWEP:GetVisualClip()
    if self.LastClipOutTime > CurTime() then
        return self.LastClip1 or self:Clip1()
    else
        if !self.RevolverReload then
            self.LastClip1 = self:Clip1()
        else
            if self:Clip1() > lastframeclip1 then
                self.LastClip1 = self:Clip1()
            end

            lastframeclip1 = self:Clip1()
        end

        return self:Clip1()
    end
end

function SWEP:SelectReloadAnimation()
    local ret

    if self.Animations.reload_empty and self:Clip1() == 0 then
        ret = "reload_empty"
    else
        ret = "reload"
    end

    ret = self:GetBuff_Hook("Hook_SelectReloadAnimation", ret) or ret

    return ret
end

function SWEP:ReloadInsert(empty)
    local total = self:GetCapacity()

    if !empty then
        total = total + (self:GetBuff_Override("Override_ChamberSize") or self.ChamberSize)
    end

    self:SetNWBool("reloading", true)

    local mult = self:GetBuff_Mult("Mult_ReloadTime")

    self:SetNWBool("reloading", false)

    if self:Clip1() >= total or self:Ammo1() == 0 or self:GetNWBool("reqend", false) then
        local ret = "sgreload_finish"

        if empty then
            ret = "sgreload_finish_empty"
            if self:GetNWBool("cycle") then
                self:SetNWBool("cycle", false)
            end
        end

        ret = self:GetBuff_Hook("Hook_SelectReloadAnimation", ret) or ret

        self:PlayAnimation(ret, mult, true, 0, true)
            self:SetTimer(self:GetAnimKeyTime(ret) * mult,
            function()
                self:SetNWBool("reloading", false)
            end)

        self:SetNWBool("reqend", false)
    else
        local insertcount = 1
        local insertanim = "sgreload_insert"

        local ret = self:GetBuff_Hook("Hook_SelectInsertAnimation", {count = insertcount, anim = insertanim, empty = empty})

        if ret then
            insertcount = ret.count
            insertanim = ret.anim
        end

        self:GetOwner():SetAmmo(self:Ammo1() - insertcount, self.Primary.Ammo)
        self:SetClip1(self:Clip1() + insertcount)

        self:PlayAnimation(insertanim, mult, true, 0, true)
        self:SetTimer(self:GetAnimKeyTime(insertanim) * mult,
        function()
            self:ReloadInsert(empty)
        end)
    end

    self:SetNWBool("reloading", true)
end

function SWEP:GetCapacity()
    local clip = self.RegularClipSize or self.Primary.ClipSize
    local level = 1

    if self:GetBuff_Override("MagExtender") then
        level = level + 1
    end

    if self:GetBuff_Override("MagReducer") then
        level = level - 1
    end

    if level == 0 then
        clip = self.ReducedClipSize
    elseif level == 2 then
        clip = self.ExtendedClipSize
    end

    clip = self:GetBuff_Override("Override_ClipSize") or clip

    clip = clip + self:GetBuff_Add("Add_ClipSize")

    local ret = self:GetBuff_Hook("Hook_GetCapacity", clip)

    clip = ret or clip

    clip = math.Clamp(clip, 0, math.huge)

    self.Primary.ClipSize = clip

    return clip
end