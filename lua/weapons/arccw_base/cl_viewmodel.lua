SWEP.ActualVMData = false

local function ApproachVector(vec1, vec2, d)
    local vec3 = Vector()
    vec3[1] = math.Approach(vec1[1], vec2[1], d)
    vec3[2] = math.Approach(vec1[2], vec2[2], d)
    vec3[3] = math.Approach(vec1[3], vec2[3], d)

    return vec3
end

local function ApproachAngleA(vec1, vec2, d)
    local vec3 = Angle()
    vec3[1] = math.ApproachAngle(vec1[1], vec2[1], d)
    vec3[2] = math.ApproachAngle(vec1[2], vec2[2], d)
    vec3[3] = math.ApproachAngle(vec1[3], vec2[3], d)

    return vec3
end

function SWEP:GetViewModelPosition(pos, ang)
    if !self:GetOwner():IsValid() or !self:GetOwner():Alive() then return end
    local oldpos = Vector()
    local oldang = Angle()

    local ft = RealFrameTime()

    local asight = self:GetActiveSights()

    oldpos:Set(pos)
    oldang:Set(ang)

    ang = ang - (self:GetOwner():GetViewPunchAngles() * 0.5)

    actual = self.ActualVMData or {pos = Vector(0, 0, 0), ang = Angle(0, 0, 0), down = 1, sway = 1, bob = 1}

    local target = {
        pos = self:GetBuff_Override("Override_ActivePos") or self.ActivePos,
        ang = self:GetBuff_Override("Override_ActiveAng") or self.ActiveAng,
        down = 1,
        sway = 2,
        bob = 2,
    }

    local vm_right = GetConVar("arccw_vm_right"):GetFloat()
    local vm_up = GetConVar("arccw_vm_up"):GetFloat()
    local vm_forward = GetConVar("arccw_vm_forward"):GetFloat()

    target.pos = target.pos + Vector(vm_right, vm_forward, vm_up)

    local state = self:GetState()

    if self:GetOwner():Crouching() then
        target.down = 0
        if self.CrouchPos then
            target.pos = self.CrouchPos
            target.ang = self.CrouchAng
        end
    end

    if self:InBipod() then
        target.pos = target.pos + ((self.BipodAngle - self:GetOwner():EyeAngles()):Right() * -4)
        target.sway = 0.2
    end

    local sighted = self.Sighted or state == ArcCW.STATE_SIGHTS
    if game.SinglePlayer() then
        sighted = state == ArcCW.STATE_SIGHTS
    end

    local sprinted = self.Sprinted or state == ArcCW.STATE_SPRINT
    if game.SinglePlayer() then
        sprinted = state == ArcCW.STATE_SPRINT
    end

    if state == ArcCW.STATE_CUSTOMIZE then
        target = {
            pos = Vector(),
            ang = Angle(),
            down = 1,
            sway = 3,
            bob = 1,
        }

        local mx, my = input.GetCursorPos()

        mx = 2 * mx / ScrW()
        my = 2 * my / ScrH()

        target.pos:Set(self.CustomizePos)
        target.ang:Set(self.CustomizeAng)

        target.pos = target.pos + Vector(mx, 0, my)
        target.ang = target.ang + Angle(0, my * 2, mx * 2)

        if self.InAttMenu then
            target.ang = target.ang + Angle(0, -5, 0)
        end

    elseif (sprinted or (self:GetCurrentFiremode().Mode == 0 and !sighted)) and !(self:GetBuff_Override("Override_ShootWhileSprint") or self.ShootWhileSprint) then
        target = {
            pos = self.HolsterPos,
            ang = Angle(),
            down = 1,
            sway = 4,
            bob = 5,
        }

        target.ang:Set(self.HolsterAng)

        if ang.p < -15 then
            target.ang.p = target.ang.p + ang.p + 15
        end

        target.ang.p = math.Clamp(target.ang.p, -80, 80)
    elseif sighted then
        local irons = self:GetActiveSights()

        target = {
            pos = irons.Pos,
            ang = irons.Ang,
            evpos = irons.EVPos or Vector(0, 0, 0),
            evang = irons.EVAng or Angle(0, 0, 0),
            down = 0,
            sway = 0.1,
            bob = 0.1,
        }

        local sr = self:GetBuff_Override("Override_AddSightRoll")

        if sr then
            target.ang = Angle()

            target.ang:Set(irons.Ang)
            target.ang.r = sr
        end

        -- local anchor = irons.AnchorBone

        -- if anchor then
        --     local vm = self:GetOwner():GetViewModel()
        --     local bone = vm:LookupBone(anchor)
        --     local bpos, bang = vm:GetBonePosition(bone)

        --     print(bpos)
        -- end
    end

    local deg = self:BarrelHitWall()

    if deg > 0 then
        target = {
            pos = LerpVector(deg, target.pos, self.HolsterPos),
            ang = LerpAngle(deg, target.ang, self.HolsterAng),
            down = 2,
            sway = 2,
            bob = 2,
        }
    end

    if isangle(target.ang) then
        target.ang = Angle(target.ang)
    end

    if self.InProcDraw then
        self.InProcHolster = false
        local delta = math.Clamp((CurTime() - self.ProcDrawTime) / (0.25 * self:GetBuff_Mult("Mult_HolsterTime")), 0, 1)
        target = {
            pos = LerpVector(delta, Vector(0, -30, -30), target.pos),
            ang = LerpAngle(delta, Angle(40, 30, 0), target.ang),
            down = target.down,
            sway = target.sway,
            bob = target.bob,
        }

        if delta == 1 then
            self.InProcDraw = false
        end
    end

    if self.InProcHolster then
        self.InProcDraw = false
        local delta = 1 - math.Clamp((CurTime() - self.ProcHolsterTime) / 0.25, 0, 1)
        target = {
            pos = LerpVector(delta, Vector(0, -30, -30), target.pos),
            ang = LerpAngle(delta, Angle(40, 30, 0), target.ang),
            down = target.down,
            sway = target.sway,
            bob = target.bob,
        }

        if delta == 0 then
            self.InProcHolster = false
        end
    end

    if self.InProcBash then
        self.InProcDraw = false

        local mult = self:GetBuff_Mult("Mult_MeleeTime")
        local mt = self.MeleeTime * mult

        local delta = 1 - math.Clamp((CurTime() - self.ProcBashTime) / mt, 0, 1)

        local bp = self.BashPos
        local ba = self.BashAng

        if delta > 0.3 then
            bp = self.BashPreparePos
            ba = self.BashPrepareAng
            delta = (delta - 0.5) * 2
        else
            delta = delta * 2
        end

        target = {
            pos = LerpVector(delta, bp, target.pos),
            ang = LerpAngle(delta, ba, target.ang),
            down = target.down,
            sway = target.sway,
            bob = target.bob,
            speed = 10
        }

        if delta == 0 then
            self.InProcBash = false
        end
    end

    if self.ViewModel_Hit then
        local nap = Vector()

        nap[1] = self.ViewModel_Hit[1]
        nap[2] = self.ViewModel_Hit[2]
        nap[3] = self.ViewModel_Hit[3]

        nap[1] = math.Clamp(nap[1], -1, 1)
        nap[2] = math.Clamp(nap[2], -1, 1)
        nap[3] = math.Clamp(nap[3], -1, 1)

        target.pos = target.pos + nap

        if !self.ViewModel_Hit:IsZero() then
            local naa = Angle()

            naa[1] = self.ViewModel_Hit[1]
            naa[2] = self.ViewModel_Hit[2]
            naa[3] = self.ViewModel_Hit[3]

            naa[1] = math.Clamp(naa[1], -1, 1)
            naa[2] = math.Clamp(naa[2], -1, 1)
            naa[3] = math.Clamp(naa[3], -1, 1)

            target.ang = target.ang + (naa * 10)
        end

        local nvmh = Vector(0, 0, 0)

        local spd = self.ViewModel_Hit:Length()

        nvmh[1] = math.Approach(self.ViewModel_Hit[1], 0, ft * 5 * spd)
        nvmh[2] = math.Approach(self.ViewModel_Hit[2], 0, ft * 5 * spd)
        nvmh[3] = math.Approach(self.ViewModel_Hit[3], 0, ft * 5 * spd)

        self.ViewModel_Hit = nvmh

        -- local nvma = Angle(0, 0, 0)

        -- local spd2 = 360

        -- nvma[1] = math.ApproachAngle(self.ViewModel_HitAng[1], 0, ft * 5 * spd2)
        -- nvma[2] = math.ApproachAngle(self.ViewModel_HitAng[2], 0, ft * 5 * spd2)
        -- nvma[3] = math.ApproachAngle(self.ViewModel_HitAng[3], 0, ft * 5 * spd2)

        -- self.ViewModel_HitAng = nvma
    end

    target.pos = target.pos + (VectorRand() * self.RecoilAmount * 0.2)

    local speed = target.speed or 3

    speed = 1 / self:GetSightTime() * speed * ft

    actual.pos = LerpVector(speed, actual.pos, target.pos)
    actual.ang = LerpAngle(speed, actual.ang, target.ang)
    actual.down = Lerp(speed, actual.down, target.down)
    actual.sway = Lerp(speed, actual.sway, target.sway)
    actual.bob = Lerp(speed, actual.bob, target.bob)
    actual.evpos = Lerp(speed, actual.evpos or Vector(0, 0, 0), target.evpos or Vector(0, 0, 0))
    actual.evang = Lerp(speed, actual.evang or Angle(0, 0, 0), target.evang or Angle(0, 0, 0))

    actual.pos = ApproachVector(actual.pos, target.pos, speed * 0.1)
    actual.ang = ApproachAngleA(actual.ang, target.ang, speed * 0.1)
    actual.down = math.Approach(actual.down, target.down, speed * 0.1)

    self.SwayScale = actual.sway
    self.BobScale = actual.bob

    pos = pos + self.RecoilPunchBack * -oldang:Forward()
    pos = pos + self.RecoilPunchSide * oldang:Right()
    pos = pos + self.RecoilPunchUp * -oldang:Up()

    ang:RotateAroundAxis( oldang:Right(), actual.ang.x )
    ang:RotateAroundAxis( oldang:Up(), actual.ang.y )
    ang:RotateAroundAxis( oldang:Forward(), actual.ang.z )

    ang:RotateAroundAxis( oldang:Right(), actual.evang.x )
    ang:RotateAroundAxis( oldang:Up(), actual.evang.y )
    ang:RotateAroundAxis( oldang:Forward(), actual.evang.z )

    pos = pos + (oldang:Right() * actual.evpos.x)
    pos = pos + (oldang:Forward() * actual.evpos.y)
    pos = pos + (oldang:Up() * actual.evpos.z)

    pos = pos + actual.pos.x * ang:Right()
    pos = pos + actual.pos.y * ang:Forward()
    pos = pos + actual.pos.z * ang:Up()

    pos = pos - Vector(0, 0, actual.down)

    if asight and asight.Holosight then
        ang = ang - (self:GetOwner():GetViewPunchAngles() * 0.5)
    end

    self.ActualVMData = actual

    return pos, ang
end

local function ShouldCheapWorldModel()
    return !GetConVar("arccw_att_showothers"):GetBool()
end

function SWEP:DrawWorldModel()
    if !IsValid(self:GetOwner()) and GetConVar("arccw_2d3d"):GetBool() then
        if (EyePos() - self:GetPos()):LengthSqr() <= 262144 then -- 512^2
            local ang = LocalPlayer():EyeAngles()

            ang:RotateAroundAxis(ang:Forward(), 180)
            ang:RotateAroundAxis(ang:Right(), 90)
            ang:RotateAroundAxis(ang:Up(), 90)

            cam.Start3D2D(self:GetPos() + Vector(0, 0, 16), ang, 0.1)
                surface.SetFont("ArcCW_32_Unscaled")

                local w = surface.GetTextSize(self.PrintName)

                surface.SetTextPos(-w / 2, 0)
                surface.SetTextColor(255, 255, 255, 255)
                surface.DrawText(self.PrintName)

                surface.SetFont("ArcCW_24_Unscaled")

                local t = tostring(self:CountAttachments()) .. " Attachments"

                w = surface.GetTextSize(t)

                surface.SetTextPos(-w / 2, 32)
                surface.SetTextColor(255, 255, 255, 255)
                surface.DrawText(t)
            cam.End3D2D()
        end
    end

    if ShouldCheapWorldModel() then
        self:DrawModel()
    else
        self:DrawCustomModel(true)
    end

    self:DoLaser(true)

    if self:ShouldGlint() then
        self:DoScopeGlint()
    end

    if !self.CertainAboutAtts then
        net.Start("arccw_rqwpnnet")
        net.WriteEntity(self)
        net.SendToServer()
    end
end

function SWEP:PreDrawViewModel(vm)
    if !vm then return end

    if GetConVar("arccw_cheapscopesautoconfig"):GetBool() then
        -- auto configure what the best option is likely to be
        -- if you can't get more than 45fps you probably want cheap scopes

        local fps = 1 / RealFrameTime()

        if fps >= 45 then
            GetConVar("arccw_cheapscopes"):SetBool(false)
        else
            GetConVar("arccw_cheapscopes"):SetBool(true)
        end

        GetConVar("arccw_cheapscopesautoconfig"):SetBool(false)
    end

    local asight = self:GetActiveSights()

    if GetConVar("arccw_cheapscopes"):GetBool() and self:GetSightDelta() < 1 and asight.MagnifiedOptic then
        self:FormCheapScope()
    end

    self:DrawCustomModel(false)

    self:DoLHIK()
end

function SWEP:PostDrawViewModel()

    if ArcCW.Overdraw then
        ArcCW.Overdraw = false
    else
        self:DoLaser()
        self:DoHolosight()

        if self:GetState() == ArcCW.STATE_CUSTOMIZE then
            self:BlurNotWeapon()
        end
    end
end