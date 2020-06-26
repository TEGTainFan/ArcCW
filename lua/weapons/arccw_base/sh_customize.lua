function SWEP:ToggleCustomizeHUD(ic)
    if ic and self:GetState() == ArcCW.STATE_SPRINT then return end

    if ic then
        if (self:GetNextPrimaryFire() + 0.1) >= CurTime() then return end

        self:SetState(ArcCW.STATE_CUSTOMIZE)
        self:ExitSights()
        self:SetShouldHoldType()
        self:ExitBipod()
        if CLIENT then
            self:OpenCustomizeHUD()
        end
    else
        self:SetState(ArcCW.STATE_IDLE)
        self.Sighted = false
        self.Sprinted = false
        self:SetShouldHoldType()
        if CLIENT then
            self:CloseCustomizeHUD()
            self:SendAllDetails()
        end
    end
end

if CLIENT then

local function multlinetext(text, maxw, font)
    local content = {}
    local tline = ""
    local x = 0
    surface.SetFont(font)

    local newlined = string.Split(text, "\n")

    for _, line in pairs(newlined) do
        local words = string.Split(line, " ")

        for _, word in pairs(words) do
            local tx = surface.GetTextSize(word)

            if x + tx >= maxw then
                table.insert(content, tline)
                tline = ""
                x = surface.GetTextSize(word)
            end

            tline = tline .. word .. " "

            x = x + surface.GetTextSize(word .. " ")
        end

        table.insert(content, tline)
        tline = ""
        x = 0
    end

    -- local space_len = surface.GetTextSize(" ")

    -- for _, word in pairs(string.Split(text, " ")) do
    --     if word == "\n" then
    --         table.insert(content, line)
    --         line = ""
    --         x = 0
    --     else
    --         x = x + surface.GetTextSize(word)

    --         if x >= limitx then
    --             table.insert(content, line)
    --             line = ""
    --             x = 0
    --             x = x + surface.GetTextSize(word)
    --         end

    --         line = line .. word .. " "

    --         x = x + space_len

    --         -- print(word .. " at " .. tostring(x))
    --     end
    -- end

    -- table.insert(content, line)

    return content
end

function SWEP:OpenCustomizeHUD()
    if IsValid(ArcCW.InvHUD) then
        ArcCW.InvHUD:Show()
    else
        self:CreateCustomizeHUD()
        gui.SetMousePos(ScrW() / 2, ScrH() / 2)
    end

    gui.EnableScreenClicker(true)

end

function SWEP:CloseCustomizeHUD()
    if IsValid(ArcCW.InvHUD) then
        ArcCW.InvHUD:Hide()
        ArcCW.InvHUD:Clear()
        ArcCW.InvHUD:Remove()
        gui.EnableScreenClicker(false)
    end
end

local defaultatticon = Material("hud/atts/default.png")
local activeslot = nil

SWEP.InAttMenu = false

function SWEP:CreateCustomizeHUD()
    local barsize = ScreenScale(160)
    local airgap = ScreenScale(16)
    local smallgap = ScreenScale(2)
    local linesize = ScreenScale(1)
    local buttonsize = ScreenScale(32)
    local fg_col = Color(255, 255, 255, 255)
    local bg_col = Color(0, 0, 0, 150)

    if !self:IsValid() then return end

    self.InAttMenu = false
    activeslot = nil

    ArcCW.InvHUD = vgui.Create("DFrame")

    ArcCW.InvHUD:SetPos(0, 0)
    ArcCW.InvHUD:SetSize(ScrW(), ScrH())
    ArcCW.InvHUD:SetText("")
    ArcCW.InvHUD:SetTitle("")
    ArcCW.InvHUD.Paint = function(span)
        if !IsValid(self) then
            gui.EnableScreenClicker(false)
            span:Remove()
        end
    end
    ArcCW.InvHUD.OnRemove = function()
        if self:IsValid() and self:GetState() == ArcCW.STATE_CUSTOMIZE then
            net.Start("arccw_togglecustomize")
            net.WriteBool(false)
            net.SendToServer()

            self:ToggleCustomizeHUD(false)
        end
    end

    if GetConVar("arccw_attinv_onlyinspect"):GetBool() then
        return
    end

    local loadpresets = vgui.Create("DButton", ArcCW.InvHUD)
    loadpresets:SetSize((barsize - ScreenScale(2)) / 2, ScreenScale(14))
    loadpresets:SetText("")
    loadpresets:SetPos(ScrW() - barsize - airgap, airgap)

    loadpresets.OnMousePressed = function(spaa, kc)
        self:CreatePresetMenu()
    end

    loadpresets.Paint = function(spaa, w, h)
        if !self:IsValid() then return end
        if !self.Attachments then return end
        local Bfg_col = Color(255, 255, 255, 255)
        local Bbg_col = Color(0, 0, 0, 100)

        if spaa:IsHovered() then
            Bbg_col = Color(255, 255, 255, 100)
            Bfg_col = Color(0, 0, 0, 255)
        end

        surface.SetDrawColor(Bbg_col)
        surface.DrawRect(0, 0, w, h)

        local txt = "Load Preset"

        surface.SetTextColor(Bfg_col)
        surface.SetTextPos(smallgap, ScreenScale(1))
        surface.SetFont("ArcCW_12")
        surface.DrawText(txt)
    end

    local savepresets = vgui.Create("DButton", ArcCW.InvHUD)
    savepresets:SetSize((barsize - ScreenScale(2)) / 2, ScreenScale(14))
    savepresets:SetText("")
    savepresets:SetPos(ScrW() - (barsize / 2) + ScreenScale(1) - airgap, airgap)

    savepresets.OnMousePressed = function(spaa, kc)
        self:CreatePresetSave()
    end

    savepresets.Paint = function(spaa, w, h)
        if !self:IsValid() then return end
        if !self.Attachments then return end
        local Bfg_col = Color(255, 255, 255, 255)
        local Bbg_col = Color(0, 0, 0, 100)

        if spaa:IsHovered() then
            Bbg_col = Color(255, 255, 255, 100)
            Bfg_col = Color(0, 0, 0, 255)
        end

        surface.SetDrawColor(Bbg_col)
        surface.DrawRect(0, 0, w, h)

        local txt = "Save Preset"

        surface.SetTextColor(Bfg_col)
        surface.SetTextPos(smallgap, ScreenScale(1))
        surface.SetFont("ArcCW_12")
        surface.DrawText(txt)
    end

    local attcatsy = ScrH() - ScreenScale(64) - airgap

    local attcats = vgui.Create("DScrollPanel", ArcCW.InvHUD)
    attcats:SetText("")
    attcats:SetSize(barsize, attcatsy)
    attcats:SetPos(airgap, airgap)
    attcats.Paint = function(span, w, h)
        -- surface.SetDrawColor(bg_col)
        -- surface.DrawRect(0, 0, w, h)
    end

    local triviabox = vgui.Create("DScrollPanel", ArcCW.InvHUD)
    triviabox:SetText("")
    triviabox:SetSize(barsize, ScrH() - ScreenScale(64) - (3 * airgap))
    triviabox:SetPos(ScrW() - barsize - airgap, 2 * airgap)
    triviabox.Paint = function(span, w, h)
        surface.SetDrawColor(bg_col)
        surface.DrawRect(0, 0, w, h)
    end

    local sbar = attcats:GetVBar()
    sbar.Paint = function() end

    sbar.btnUp.Paint = function(span, w, h)
    end

    sbar.btnDown.Paint = function(span, w, h)
    end

    sbar.btnGrip.Paint = function(span, w, h)
        surface.SetDrawColor(fg_col)
        surface.DrawRect(0, 0, w, h)
    end

    local wpninfo = attcats:Add("DLabel")
    wpninfo:SetSize(barsize, buttonsize)
    wpninfo:SetText("")
    wpninfo:Dock( TOP )
    wpninfo:DockMargin( 0, 0, 0, smallgap )

    wpninfo.Paint = function(span, w, h)
        if !IsValid(self) then return end
        local Bfg_col = fg_col
        local Bbg_col = bg_col

        surface.SetDrawColor(Bbg_col)
        surface.DrawRect(0, 0, w, h)
        surface.DrawRect(0, 0, w, h / 2)

        surface.SetDrawColor(Bfg_col)
        surface.DrawRect(0, (h - linesize) / 2, w, linesize)

        surface.SetTextColor(0, 0, 0)
        surface.SetTextPos(smallgap, 0)
        surface.SetFont("ArcCW_12_Glow")
        surface.DrawText(self.PrintName)

        surface.SetTextColor(Bfg_col)
        surface.SetTextPos(smallgap, 0)
        surface.SetFont("ArcCW_12")
        surface.DrawText(self.PrintName)

        surface.SetTextColor(Bfg_col)
        surface.SetTextPos(smallgap * 2, (h - linesize) / 2 + smallgap)
        surface.SetFont("ArcCW_12")

        local pick = GetConVar("arccw_atts_pickx"):GetInt()

        if pick <= 0 then
            surface.DrawText(self.Trivia_Class)
        else
            local txt = self:CountAttachments() .. "/" .. pick .. " Attachments"

            surface.DrawText(txt)
        end
    end

    local attmenuh = ScrH() - (2 * airgap)

    local attmenu = vgui.Create("DScrollPanel", ArcCW.InvHUD)
    attmenu:SetText("")
    attmenu:SetSize(barsize + ScreenScale(12), attmenuh)
    attmenu:SetPos(airgap + barsize + smallgap, airgap)
    attmenu.Paint = function(span, w, h)
        -- surface.SetDrawColor(bg_col)
        -- surface.DrawRect(0, 0, w, h)
    end
    attmenu:Hide()

    local sbar3 = attmenu:GetVBar()
    sbar3.Paint = function() end

    sbar3.btnUp.Paint = function(span, w, h)
    end

    sbar3.btnDown.Paint = function(span, w, h)
    end

    sbar3.btnGrip.Paint = function(span, w, h)
        surface.SetDrawColor(fg_col)
        surface.DrawRect(0, 0, w, h)
    end

    local attslidebox = vgui.Create("DPanel", ArcCW.InvHUD)
    attslidebox:SetSize(barsize, ScreenScale(20))
    attslidebox:SetPos(ScrW() - barsize - airgap, ScrH() - ScreenScale(64) - (1 * airgap))
    attslidebox.Paint = function(span, w, h)
        surface.SetDrawColor(bg_col)
        surface.DrawRect(0, 0, w, h)

        surface.SetTextColor(fg_col)
        surface.SetFont("ArcCW_6")
        surface.SetTextPos(smallgap, smallgap)
        surface.DrawText("POSITION")
    end

    local attslider = vgui.Create("DSlider", attslidebox)
    attslider:SetPos(ScreenScale(4), ScreenScale(12))
    attslider:SetSize(barsize - ScreenScale(4 * 2), ScreenScale(4))

    attslider.Paint = function(span, w, h)
        surface.SetDrawColor(fg_col)
        surface.DrawRect(0, h / 2, w, ScreenScale(1))
    end

    local lastslidepos = 0
    local lastsoundtime = 0

    attslider.Knob.Paint = function(span, w, h)
        if !self:IsValid() then return end
        if !self.Attachments then return end

        if span:IsHovered() or attslider:GetDragging() then
            surface.SetDrawColor(fg_col)
            surface.DrawRect((w - ScreenScale(2)) / 2, 0, ScreenScale(2), h)
        else
            surface.SetDrawColor(fg_col)
            surface.DrawRect((w - ScreenScale(1)) / 2, 0, ScreenScale(1), h)
        end

        if attslider:GetDragging() then
            if activeslot then
                local delta = attslider:GetSlideX()
                if lastslidepos != delta and lastsoundtime <= CurTime() then
                    EmitSound("weapons/arccw/dragatt.wav", EyePos(), -2, CHAN_ITEM, 1,75, 0, math.Rand(95, 105))

                    lastsoundtime = CurTime() + 0.05
                end

                self.Attachments[activeslot].SlidePos = delta
                lastslidepos = delta
            end
        end

        attslider:SetSlideX((self.Attachments[activeslot] or {}).SlidePos or 0.5)
    end

    local og_attsliderknobmr = attslider.Knob.OnMouseReleased

    attslider.Knob.OnMouseReleased = function(span, kc)
        og_attsliderknobmr(span, kc)
        self:SendDetail_SlidePos(activeslot)
    end

    attslidebox:Hide()

    local atttrivia = vgui.Create("DScrollPanel", ArcCW.InvHUD)
    atttrivia:SetSize(barsize, ScrH() - ScreenScale(116))
    atttrivia:SetPos(ScrW() - barsize - airgap, 2 * airgap)
    atttrivia.Paint = function(span, w, h)
        surface.SetDrawColor(bg_col)
        surface.DrawRect(0, 0, w, h)
    end
    atttrivia:Hide()

    local sbar4 = atttrivia:GetVBar()
    sbar4.Paint = function() end

    sbar4.btnUp.Paint = function(span, w, h)
    end

    sbar4.btnDown.Paint = function(span, w, h)
    end

    sbar4.btnGrip.Paint = function(span, w, h)
        surface.SetDrawColor(fg_col)
        surface.DrawRect(0, 0, w, h)
    end

    local last_atttrivia = nil

    local function atttrivia_do(att)

        if !att then
            last_atttrivia = att
            atttrivia:Hide()
            atttrivia:Clear()
            return
        end

        if att == "" then
            last_atttrivia = att
            atttrivia:Hide()
            atttrivia:Clear()
            return
        end

        if att == last_atttrivia then
            last_atttrivia = att
            return
        end

        atttrivia:Clear()

        last_atttrivia = att

        local atttbl = ArcCW.AttachmentTable[att]

        atttrivia:Show()

        -- att name

        local triv_attname = vgui.Create("DLabel", atttrivia)
            triv_attname:SetSize(barsize, ScreenScale(16))
            triv_attname:Dock(TOP)
            triv_attname:DockMargin( 0, 0, 0, 0 )
            triv_attname:SetText("")
            triv_attname.Paint = function(span, w, h)
                local txt = multlinetext(atttbl.PrintName, w, "ArcCW_16")

                c = 0

                for _, i in pairs(txt) do
                    surface.SetFont("ArcCW_16")
                    local tw = surface.GetTextSize(i)

                    surface.SetFont("ArcCW_16_Glow")
                    surface.SetTextPos((smallgap + (w - tw)) / 2, c)
                    surface.SetTextColor(Color(0, 0, 0))
                    surface.DrawText(i)

                    surface.SetFont("ArcCW_16")
                    surface.SetTextPos((smallgap + (w - tw)) / 2, c)
                    surface.SetTextColor(fg_col)
                    surface.DrawText(i)

                    c = c + ScreenScale(16)
                end

                span:SetSize(barsize, c)
            end

        -- att pic

        local triv_pic = vgui.Create("DLabel", atttrivia)
            triv_pic:SetSize(barsize, barsize / 2)
            triv_pic:Dock(TOP)
            triv_pic:DockMargin( 0, 0, 0, smallgap )
            triv_pic:SetText("")
            triv_pic.Paint = function(span, w, h)
                local img = atttbl.Icon or defaultatticon

                surface.SetDrawColor(fg_col)
                surface.SetMaterial(img)
                surface.DrawTexturedRect(h / 2, 0, h, h)
            end

        -- att desc

        desctext = multlinetext(atttbl.Description, barsize - smallgap * 2, "ArcCW_8")

        local triv_desc = vgui.Create("DLabel", atttrivia)
        triv_desc:SetSize(barsize, ScreenScale(8) * (table.Count(desctext) + 1))
        triv_desc:SetText("")
        triv_desc:DockMargin( 0, 0, 0, smallgap )
        triv_desc:Dock(TOP)
        triv_desc.Paint = function(span, w, h)
            local y = ScreenScale(8)
            for i, line in pairs(desctext) do
                surface.SetFont("ArcCW_8")
                surface.SetTextPos(smallgap * 2, y)
                surface.SetTextColor(fg_col)
                surface.DrawText(line)
                y = y + ScreenScale(8)
            end
        end

        local triv_pros = vgui.Create("DLabel", atttrivia)
        triv_pros:SetSize(barsize, ScreenScale(10))
        triv_pros:SetText("")
        triv_pros:Dock(TOP)
        triv_pros.Paint = function(span, w, h)
            surface.SetDrawColor(Color(0, 50, 0, 100))
            surface.DrawRect(0, 0, w, h)

            surface.SetTextColor(Color(125, 200, 125))
            surface.SetFont("ArcCW_8")
            surface.SetTextPos(smallgap, 0)
            surface.DrawText("POSITIVES:")
        end

        local pros, cons = ArcCW:GetProsCons(atttbl)

        for _, i in pairs(pros) do
            local triv_pro = vgui.Create("DLabel", atttrivia)
            triv_pro:SetSize(barsize, ScreenScale(10))
            triv_pro:SetText("")
            triv_pro:Dock(TOP)
            triv_pro.Paint = function(span, w, h)

                surface.SetTextColor(Color(150, 225, 150))
                surface.SetFont("ArcCW_8")
                surface.SetTextPos(smallgap, 0)
                surface.DrawText(i)
            end
        end

        local triv_cons = vgui.Create("DLabel", atttrivia)
        triv_cons:SetSize(barsize, ScreenScale(10))
        triv_cons:SetText("")
        triv_cons:Dock(TOP)
        triv_cons.Paint = function(span, w, h)
            surface.SetDrawColor(Color(50, 0, 0, 100))
            surface.DrawRect(0, 0, w, h)

            surface.SetTextColor(Color(200, 125, 125))
            surface.SetFont("ArcCW_8")
            surface.SetTextPos(smallgap, 0)
            surface.DrawText("NEGATIVES:")
        end

        for _, i in pairs(cons) do
            local triv_con = vgui.Create("DLabel", atttrivia)
            triv_con:SetSize(barsize, ScreenScale(10))
            triv_con:SetText("")
            triv_con:Dock(TOP)
            triv_con.Paint = function(span, w, h)

                surface.SetTextColor(Color(225, 150, 150))
                surface.SetFont("ArcCW_8")
                surface.SetTextPos(smallgap, 0)
                surface.DrawText(i)
            end
        end
    end

    ArcCW.InvHUD.OnMousePressed = function(span, kc)
        if kc == MOUSE_LEFT or kc == MOUSE_RIGHT then
            activeslot = nil
            triviabox:Show()
            attmenu:Hide()
            self.InAttMenu = false
            atttrivia:Hide()
        end
    end

    for i, k in pairs(self.Attachments) do
        if !k.PrintName then continue end
        if i == "BaseClass" then continue end
        if k.Hidden then continue end
        if k.Integral then continue end

        local attcatb = attcats:Add("DButton")
        attcatb:SetSize(barsize, buttonsize)
        attcatb:SetText("")
        attcatb:Dock( TOP )
        attcatb:DockMargin( 0, 0, 0, smallgap )

        attcatb.AttIndex = i
        attcatb.AttSlot = k

        local function attcatb_regen(span)
            local catt = self.Attachments[span.AttIndex].Installed
            local catttbl
            if catt then
                catttbl = ArcCW.AttachmentTable[catt]
            end

            if self.Attachments[span.AttIndex].Installed and self.Attachments[span.AttIndex].SlideAmount and !catttbl.MountPositionOverride then
                attslidebox:Show()
            else
                attslidebox:Hide()
            end

            attmenu:Clear()

            local atts = {}
            local slots = {i}

            table.Add(slots, k.MergeSlots or {})

            for _, y in pairs(slots) do
                for _, bruh in pairs(ArcCW:GetAttsForSlot((self.Attachments[y] or {}).Slot, self)) do
                    table.insert(atts, {
                        att = bruh,
                        slot = y
                    })
                end
            end

            atts[0] = ""

            table.sort(atts, function(a, b)
                a = a.att
                b = b.att
                local atttbl_a = ArcCW.AttachmentTable[a]
                local atttbl_b = ArcCW.AttachmentTable[b]

                local order_a = 0
                local order_b = 0

                order_a = atttbl_a.SortOrder or order_a
                order_b = atttbl_b.SortOrder or order_b

                if order_a == order_b then
                    return atttbl_a.PrintName > atttbl_b.PrintName
                end

                return order_a > order_b
            end)

            local ca = 0

            for _, att in pairs(atts) do
                local aslot = att
                if istable(att) then
                    aslot = aslot.slot
                    att = att.att
                end
                local owned = self:PlayerOwnsAtt(att)

                if !owned and GetConVar("arccw_attinv_hideunowned"):GetBool() then continue end

                local attbtn = attmenu:Add("DButton")
                attbtn:SetSize(barsize + ScreenScale(12), ScreenScale(14))
                attbtn:SetText("")
                attbtn:Dock( TOP )
                attbtn:DockMargin( 0, 0, 0, smallgap )

                ca = ca + 1

                attbtn.AttName = att

                attbtn.OnMousePressed = function(spaa, kc2)
                    if kc2 == MOUSE_LEFT then
                        if spaa.AttName == "" then
                            self:DetachAllMergeSlots(span.AttIndex)
                        else
                            self:DetachAllMergeSlots(span.AttIndex, true)
                            self:Attach(aslot, spaa.AttName)
                        end
                    else
                        self:DetachAllMergeSlots(span.AttIndex)
                    end

                    attcatb_regen(span)
                end

                attbtn.Paint = function(spaa, w, h)
                    if !self:IsValid() then return end
                    if !self.Attachments then return end
                    local Bfg_col = Color(255, 255, 255, 255)
                    local Bbg_col = Color(0, 0, 0, 100)
                    local atttbl = ArcCW.AttachmentTable[spaa.AttName]
                    local qty = ArcCW:PlayerGetAtts(self:GetOwner(), spaa.AttName)
                    local showqty = true

                    owned = self:PlayerOwnsAtt(spaa.AttName)

                    if !atttbl then
                        atttbl = {
                            PrintName = k.DefaultAttName or "No Attachment",
                            Icon = defaultatticon,
                            Free = true
                        }
                    end

                    if atttbl.Free then
                        showqty = false
                    end

                    if GetConVar("arccw_attinv_free"):GetBool() then
                        showqty = false
                    end

                    if !owned then
                        showqty = false
                    end

                    if GetConVar("arccw_attinv_lockmode"):GetBool() then
                        showqty = false
                    end

                    local installed = false

                    if span.AttSlot.Installed == spaa.AttName then
                        installed = true
                    end

                    for _, slot in pairs(k.MergeSlots or {}) do
                        if !slot then continue end
                        if !self.Attachments[slot] then continue end
                        if self.Attachments[slot].Installed == spaa.AttName then
                            installed = true
                            break
                        end
                    end

                    if spaa.AttName == "" and !span.AttSlot.Installed then
                        installed = true

                        for _, slot in pairs(span.AttSlot.MergeSlots or {}) do
                            if self.Attachments[slot].Installed then
                                installed = false
                                break
                            end
                        end
                    end

                    if spaa:IsHovered() or installed then
                        Bbg_col = Color(255, 255, 255, 100)
                        Bfg_col = Color(0, 0, 0, 255)
                    end

                    if spaa:IsHovered() and installed then
                        Bbg_col = Color(255, 255, 255, 200)
                        Bfg_col = Color(0, 0, 0, 255)
                    end

                    if spaa:IsHovered() then
                        atttrivia_do(spaa.AttName)
                    end

                    if !owned or !self:CheckFlags(atttbl.ExcludeFlags, atttbl.RequireFlags) then
                        Bbg_col = Color(75, 0, 0, 150)
                        Bfg_col = Color(150, 50, 50, 255)
                    end

                    surface.SetDrawColor(Bbg_col)
                    surface.DrawRect(0, 0, w, h)
                    surface.DrawRect(0, 0, h * 1.5, h)

                    surface.SetDrawColor(Bfg_col)
                    surface.DrawRect((h * 1.5) - (linesize / 2), 0, linesize, h)

                    local txt = atttbl.PrintName

                    if showqty then
                        txt = txt .. " (" .. tostring(qty) .. ")"
                    end

                    surface.SetTextColor(Bfg_col)
                    surface.SetTextPos((h * 1.5) + smallgap, ScreenScale(1))
                    surface.SetFont("ArcCW_12")
                    surface.DrawText(txt)

                    surface.SetDrawColor(Bfg_col)
                    surface.SetMaterial(atttbl.Icon or defaultatticon)
                    surface.DrawTexturedRect(h / 4, 0, h, h)
                end
            end

            local specsize = ca * (ScreenScale(14) + smallgap)

            attmenu:SetSize(barsize + ScreenScale(12), math.min(specsize, attmenuh))
        end

        attcatb.OnMousePressed = function(span, kc)
            if !self:CheckFlags(span.AttSlot.ExcludeFlags, span.AttSlot.RequireFlags) then
                return
            end

            if kc == MOUSE_LEFT then
                if activeslot == span.AttIndex then
                    activeslot = nil
                    triviabox:Show()
                    attmenu:Hide()
                    self.InAttMenu = false
                    atttrivia:Hide()
                    attslidebox:Hide()
                else
                    activeslot = span.AttIndex
                    triviabox:Hide()
                    attmenu:Show()
                    attslider:SetSlideX(self.Attachments[span.AttIndex].SlidePos)
                    lastslidepos = self.Attachments[span.AttIndex].SlidePos
                    self.InAttMenu = true

                    if self.Attachments[span.AttIndex].Installed then
                        atttrivia_do(self.Attachments[span.AttIndex].Installed)
                    end

                    attcatb_regen(span)
                end
            elseif kc == MOUSE_RIGHT then
                self:DetachAllMergeSlots(span.AttIndex)
                attcatb_regen(span)
            end
        end

        attcatb.Paint = function(span, w, h)
            local Bfg_col = Color(255, 255, 255, 255)
            local Bbg_col = Color(0, 0, 0, 100)

            if span:IsHovered() or activeslot == span.AttIndex then
                Bbg_col = Color(255, 255, 255, 100)
                Bfg_col = Color(0, 0, 0, 255)
            end

            if span:IsHovered() and activeslot == span.AttIndex then
                Bbg_col = Color(255, 255, 255, 200)
                Bfg_col = Color(0, 0, 0, 255)
            end

            if self.CheckFlags and !self:CheckFlags(span.AttSlot.ExcludeFlags, span.AttSlot.RequireFlags) then
                Bbg_col = Color(75, 0, 0, 150)
                Bfg_col = Color(150, 50, 50, 255)
            end

            local txt = k.PrintName

            local att_txt = k.DefaultAttName or "No Attachment"
            local att_icon = defaultatticon

            local installed = k.Installed

            if !installed then
                (k.MergeSlots or {})["BaseClass"] = nil
                for _, slot in pairs(k.MergeSlots or {}) do
                    if self.Attachments[slot] and self.Attachments[slot].Installed then
                        installed = self.Attachments[slot].Installed
                        break
                    elseif !self.Attachments[slot] then
                        print("ERROR! No attachment " .. tostring(slot))
                    end
                end
            end

            if installed then
                local atttbl = ArcCW.AttachmentTable[installed]

                if atttbl.Breakable then
                    local perc = self:GetAttachmentHP(slot) / self:GetAttachmentMaxHP(slot)
                    perc = math.Round(perc)
                    txt = txt .. " (" .. tostring(perc) .. "%)"
                end
            end

            surface.SetDrawColor(Bbg_col)
            surface.DrawRect(0, 0, w, h)
            surface.DrawRect(0, 0, w, h / 2)
            surface.DrawRect(w - (1.5 * h), h / 2, 1.5 * h, h / 2)

            surface.SetDrawColor(Bfg_col)
            surface.DrawRect(0, (h - linesize) / 2, w - (1.5 * h), linesize)

            surface.SetTextColor(0, 0, 0)
            surface.SetTextPos(smallgap, 0)
            surface.SetFont("ArcCW_12_Glow")
            surface.DrawText(txt)

            surface.SetTextColor(Bfg_col)
            surface.SetTextPos(smallgap, 0)
            surface.SetFont("ArcCW_12")
            surface.DrawText(txt)

            if installed then
                local atttbl = ArcCW.AttachmentTable[installed]

                att_txt = atttbl.PrintName

                if atttbl.Icon then
                    att_icon = atttbl.Icon
                end
            end

            surface.SetTextColor(Bfg_col)
            surface.SetTextPos(smallgap * 2, (h - linesize) / 2 + smallgap)
            surface.SetFont("ArcCW_12")
            surface.DrawText(att_txt)

            surface.SetDrawColor(Bfg_col)
            surface.DrawRect(w - (1.5 * h), 0, linesize, h)

            surface.SetDrawColor(Bfg_col)
            surface.SetMaterial(att_icon)
            surface.DrawTexturedRect(w - (1.25 * h), 0, h, h)
        end
    end

    local sbar2 = triviabox:GetVBar()
    sbar2.Paint = function() end

    sbar2.btnUp.Paint = function(span, w, h)
    end

    sbar2.btnDown.Paint = function(span, w, h)
    end

    sbar2.btnGrip.Paint = function(span, w, h)
        surface.SetDrawColor(fg_col)
        surface.DrawRect(0, 0, w, h)
    end

    local triv_wpnnamelabel = vgui.Create("DLabel", triviabox)
    triv_wpnnamelabel:SetSize(barsize, buttonsize)
    triv_wpnnamelabel:Dock(TOP)
    triv_wpnnamelabel:DockMargin( 0, 0, 0, smallgap )
    triv_wpnnamelabel:SetText("")
    triv_wpnnamelabel.Paint = function(span, w, h)
        if !IsValid(self) then return end
        local txt = self.PrintName

        surface.SetFont("ArcCW_20")
        local tw, th = surface.GetTextSize(txt)

        surface.SetFont("ArcCW_20_Glow")
        surface.SetTextPos((w - tw) / 2, th / 2)
        surface.SetTextColor(Color(0, 0, 0))
        surface.DrawText(txt)

        surface.SetFont("ArcCW_20")
        surface.SetTextPos((w - tw) / 2, th / 2)
        surface.SetTextColor(fg_col)
        surface.DrawText(txt)
    end

    local year = tostring(self.Trivia_Year)

    if isnumber(self.Trivia_Year) and self.Trivia_Year < 0 then
        year = tostring(math.abs(year)) .. "BC"
    end

    local trivia = {
        function() return "Class: " .. self.Trivia_Class or "Unknown" end,
        function() return "Year: " .. tostring(self.Trivia_Year) or "Unknown" end,
        function() return "Mechanism: " .. self.Trivia_Mechanism or "Unknown" end,
        function() return "Calibre: " .. self.Trivia_Calibre or "Unknown" end,
        function() return "Ammo Type: " .. language.GetPhrase(self.Primary.Ammo) end,
        function() return "Country: " .. self.Trivia_Country or "Unknown" end,
        function() return "Manufacturer: " .. self.Trivia_Manufacturer or "Unknown" end,
        function() return "Magazine Capacity: " .. self:GetCapacity() end,
        function() return "Precision: " .. self.AccuracyMOA * self:GetBuff_Mult("Mult_AccuracyMOA") .. " MOA" end,
        function() return "Noise: " .. (self.ShootVol * self:GetBuff_Mult("Mult_ShootVol")) .. "dB" end,
        function() return "Effective Recoil Momentum: " .. math.Truncate(self.Recoil * 41.4 * self:GetBuff_Mult("Mult_Recoil"), 1) .. " lb-fps" end,
        function() return "Penetration: " .. math.Round(self.Penetration * self:GetBuff_Mult("Mult_Penetration"), 1) .. "mm" end,
    }

    if !self.ManualAction and !self:GetBuff_Override("Override_ManualAction") then
        table.insert(trivia, function()
            local rpm = 60 / (self.Delay * (1 / self:GetBuff_Mult("Mult_RPM")))
            rpm = math.ceil(rpm / 25) * 25
            return "Firerate: " .. rpm .. "RPM"
        end)
    end

    if !self.Trivia_Class then
        trivia[1] = nil
    end

    if !self.Trivia_Year then
        trivia[2] = nil
    end

    if !self.Trivia_Mechanism then
        trivia[3] = nil
    end

    if !self.Trivia_Calibre then
        trivia[4] = nil
    end

    if !self.Trivia_Country then
        trivia[6] = nil
    end

    if !self.Trivia_Manufacturer then
        trivia[7] = nil
    end

    if self.PrimaryBash then
        trivia[4] = nil
        trivia[5] = nil
        trivia[8] = nil
        trivia[9] = nil
        trivia[10] = nil
        trivia[11] = nil
        trivia[12] = nil
        trivia[13] = nil
    end

    if self.Throwing then
        trivia[4] = nil
        trivia[8] = nil
        trivia[9] = nil
        trivia[10] = nil
        trivia[11] = nil
        trivia[12] = nil
        trivia[13] = nil
    end

    if self.FuseTime then
        table.insert(trivia, function() return "Fuse Time: " .. self.FuseTime end)
    end

    for _, i in pairs(trivia) do
        if !i then continue end
        local triv_misc = vgui.Create("DLabel", triviabox)
        triv_misc:SetSize(barsize, ScreenScale(8))
        triv_misc:Dock(TOP)
        triv_misc:SetText("")
        triv_misc:DockMargin( 0, 0, 0, 0 )
        triv_misc.Paint = function(span, w, h)
            if !IsValid(self) then return end
            local txt = i()

            surface.SetFont("ArcCW_8")
            surface.SetTextPos(smallgap, 0)
            surface.SetTextColor(fg_col)
            surface.DrawText(txt)
        end
    end

    -- multlinetext(text, maxw, font)

    local adesctext = multlinetext(self.Trivia_Desc, barsize, "ArcCW_8")

    table.insert(adesctext, "")

    local triv_desc = vgui.Create("DLabel", triviabox)
        triv_desc:SetSize(barsize, ScreenScale(8) * (table.Count(adesctext) + 1))
        triv_desc:SetText("")
        triv_desc:Dock(TOP)
        triv_desc.Paint = function(span, w, h)
            local y = ScreenScale(8)
            for _, line in pairs(adesctext) do
                surface.SetFont("ArcCW_8")
                surface.SetTextPos(smallgap, y)
                surface.SetTextColor(fg_col)
                surface.DrawText(line)
                y = y + ScreenScale(8)
            end
        end

    if self.ShootEntity then return end
    if self.PrimaryBash then return end
    if self.Throwing then return end
    if self.NoRangeGraph then return end

    local rangegraph = vgui.Create("DLabel", triviabox)
    rangegraph:SetSize(barsize, ScreenScale(64))
    rangegraph:SetText("")
    rangegraph:Dock(TOP)
    rangegraph.Paint = function(span, w, h)
        if !IsValid(self) then return end
        local sidegap = 0
        local gx, gy = 0, smallgap
        local gw, gh = w - (2 * sidegap), h - smallgap - ScreenScale(6)

        local dmgmax = math.Round(self:GetDamage(0))
        local dmgmin = math.Round(self:GetDamage(self.Range))

        local grsh = math.max(dmgmax, dmgmin)

        grsh = math.ceil((grsh / 25) + 1) * 25

        local maxgr = (self.Range * self:GetBuff_Mult("Mult_Range"))

        if dmgmax < dmgmin then
            maxgr = (self.Range / self:GetBuff_Mult("Mult_Range"))
        end

        maxgr = math.Round(maxgr)

        local grsw = math.ceil((maxgr / 50) + 1) * 50

        local convw = gw / grsw
        local convh = gh / grsh

        local starty = gh - (dmgmax * convh)
        local endy = gh - (dmgmin * convh)
        local startx = 0
        local endx = maxgr * convw

        surface.SetDrawColor(bg_col)
        surface.DrawRect(gx, gy, gw, gh)

        surface.SetDrawColor(fg_col)
        surface.DrawLine(gx + startx, gy + starty, gx + endx, gy + endy)
        surface.DrawLine(gx + endx, gy + endy, gx + gw, gy + endy)

        -- start dmg
        surface.SetTextColor(fg_col)
        surface.SetFont("ArcCW_6")
        surface.SetTextPos(gx + startx, gy + starty - ScreenScale(7) - 1)
        surface.DrawText(tostring(dmgmax) .. "DMG")

        -- end dmg
        surface.SetTextColor(fg_col)
        surface.SetFont("ArcCW_6")

        local dtw = surface.GetTextSize(tostring(dmgmin) .. "DMG")
        surface.SetTextPos(gx + gw - dtw, gy + endy - ScreenScale(7) - 1)
        surface.DrawText(tostring(dmgmin) .. "DMG")

        -- start range
        surface.SetTextColor(fg_col)
        surface.SetFont("ArcCW_6")
        surface.SetTextPos(sidegap, smallgap + gh)
        surface.DrawText("0m")

        -- mid range
        surface.SetTextColor(fg_col)
        surface.SetFont("ArcCW_6")
        local mtw = surface.GetTextSize(tostring(maxgr) .. "m")
        surface.SetTextPos(gx + endx - (mtw / 2), smallgap + gh)
        surface.DrawText(tostring(maxgr) .. "m")

        -- end range
        surface.SetTextColor(fg_col)
        surface.SetFont("ArcCW_6")
        local rtw = surface.GetTextSize(tostring(grsw) .. "m")
        surface.SetTextPos(w - sidegap - rtw, smallgap + gh)
        surface.DrawText(tostring(grsw) .. "m")

        local mousex, mousey = span:CursorPos()

        if mousex > gx and mousex < (gx + gw) and
            (mousey > gy and mousey < (gy + gh)) then
            local mouser = (mousex - gx) / convw

            local shy
            local shdmg

            if mouser < maxgr then
                local delta = mouser / maxgr
                shy = Lerp(delta, starty, endy)
                shdmg = Lerp(delta, dmgmax, dmgmin)
            else
                shy = endy
                shdmg = dmgmin
            end

            surface.SetDrawColor(Color(fg_col.r, fg_col.g, fg_col.b, 150))
            surface.DrawLine(gx, gy + shy, gw, gy + shy)
            surface.DrawLine(mousex, gy, mousex, gh + gy)

            shy = shy + ScreenScale(4)

            mouser = math.Round(mouser)
            shdmg = math.Round(shdmg)

            local alignleft = true

            surface.SetFont("ArcCW_6")
            local twmr = surface.GetTextSize(tostring(mouser) .. "m")
            local twmb = surface.GetTextSize(tostring(shdmg) .. "DMG")

            if mousex < math.max(twmr, twmb) + ScreenScale(2) then
                alignleft = false
            end

            surface.SetTextColor(fg_col)
            surface.SetFont("ArcCW_6")
            if alignleft then
                surface.SetTextPos(mousex - ScreenScale(2) - twmr, shy)
            else
                surface.SetTextPos(mousex + ScreenScale(2), shy)
            end
            surface.DrawText(tostring(mouser) .. "m")

            surface.SetTextColor(fg_col)
            surface.SetFont("ArcCW_6")
            if alignleft then
                surface.SetTextPos(mousex - ScreenScale(2) - twmb, ScreenScale(2) + gy)
            else
                surface.SetTextPos(mousex + ScreenScale(2), ScreenScale(2) + gy)
            end
            surface.DrawText(tostring(shdmg) .. "DMG")
        end
    end
end

end