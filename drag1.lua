local DrawLib  = {}
DrawLib.__index = DrawLib
DrawLib.Flags  = {}

-- ─────────────────────────────────────────────────────────────
--  WINDOWS VIRTUAL KEY CODE TABLE
-- ─────────────────────────────────────────────────────────────
local VK = {}
for i = 0, 25 do VK[string.char(65+i)] = 0x41+i end
for i = 0,  9 do VK[tostring(i)]       = 0x30+i end
VK.BACK=0x08; VK.TAB=0x09; VK.RETURN=0x0D; VK.SHIFT=0x10
VK.CONTROL=0x11; VK.ESCAPE=0x1B; VK.SPACE=0x20
VK.PRIOR=0x21; VK.NEXT=0x22; VK.END=0x23; VK.HOME=0x24
VK.LEFT=0x25; VK.UP=0x26; VK.RIGHT=0x27; VK.DOWN=0x28
VK.INSERT=0x2D; VK.DELETE=0x2E
for i=1,12 do VK["F"..i]=0x6F+i end
for i=0,9  do VK["NUMPAD"..i]=0x60+i end
VK.LSHIFT=0xA0; VK.RSHIFT=0xA1; VK.LCTRL=0xA2; VK.RCTRL=0xA3
VK.LALT=0xA4; VK.RALT=0xA5
VK.SEMICOLON=0xBA; VK.PLUS=0xBB; VK.COMMA=0xBC; VK.MINUS=0xBD
VK.PERIOD=0xBE; VK.SLASH=0xBF; VK.GRAVE=0xC0
VK.LBRACE=0xDB; VK.BACKSLASH=0xDC; VK.RBRACE=0xDD; VK.QUOTE=0xDE

local VK_NAME = {}
for name, code in pairs(VK) do VK_NAME[code] = name end

local ALL_VK = {}
do
    local seen = {}
    for _, code in pairs(VK) do
        if not seen[code] and code~=0x10 and code~=0x01 and code~=0x02 then
            seen[code]=true; table.insert(ALL_VK, code)
        end
    end
end

-- ─────────────────────────────────────────────────────────────
--  CHARACTER MAP  (VK code -> {normal_char, shifted_char})
-- ─────────────────────────────────────────────────────────────
local _charMap = {}
for i=0,25 do _charMap[0x41+i]={string.char(97+i), string.char(65+i)} end
local _ns={")", "!", "@", "#", "$", "%", "^", "&", "*", "("}
for i=0,9 do _charMap[0x30+i]={tostring(i), _ns[i+1]} end
_charMap[0xBA]={";",":"};  _charMap[0xBB]={"=","+"};  _charMap[0xBC]={",","<"}
_charMap[0xBD]={"-","_"};  _charMap[0xBE]={".",">"}; _charMap[0xBF]={"/","?"}
_charMap[0xC0]={"`","~"};  _charMap[0xDB]={"[","{"};  _charMap[0xDC]={"\\","|"}
_charMap[0xDD]={"]","}"};  _charMap[0xDE]={"'",'"'};  _charMap[0x20]={" "," "}

-- ─────────────────────────────────────────────────────────────
--  THEME
-- ─────────────────────────────────────────────────────────────
local C = {
    WindowBg   = Color3.fromRGB(14, 14, 19),
    ContentBg  = Color3.fromRGB(19, 19, 27),
    SectionBg  = Color3.fromRGB(16, 16, 23),
    TitleBg    = Color3.fromRGB(11, 11, 17),
    TabBarBg   = Color3.fromRGB(12, 12, 18),
    TabActive  = Color3.fromRGB(19, 19, 27),
    TabInactive= Color3.fromRGB(12, 12, 18),
    Border     = Color3.fromRGB(50, 50, 70),
    BorderDim  = Color3.fromRGB(35, 35, 52),
    Accent     = Color3.fromRGB(100,80, 200),
    AccentDim  = Color3.fromRGB(72, 55, 150),
    AccentHov  = Color3.fromRGB(120,98, 228),
    Text       = Color3.fromRGB(222,222,230),
    TextDim    = Color3.fromRGB(138,138,155),
    TextAcc    = Color3.fromRGB(162,142,255),
    HoverBg    = Color3.fromRGB(26, 26, 38),
    ToggleOff  = Color3.fromRGB(36, 36, 52),
    SliderTrack= Color3.fromRGB(28, 28, 42),
    Black      = Color3.new(0,0,0),
    White      = Color3.new(1,1,1),
    Red        = Color3.fromRGB(200,60, 60),
    Yellow     = Color3.fromRGB(200,160,30),
    Green      = Color3.fromRGB(70, 200,110),
}

-- ─────────────────────────────────────────────────────────────
--  DRAWING FACTORY
-- ─────────────────────────────────────────────────────────────
local _drawings = {}
local _font     = Drawing.Fonts.UI

local function D(dtype, props)
    local obj = Drawing.new(dtype)
    props = props or {}
    for k, v in pairs(props) do pcall(function() obj[k]=v end) end
    if props.Visible == nil then obj.Visible = true end
    table.insert(_drawings, obj)
    return obj
end

-- ─────────────────────────────────────────────────────────────
--  CENTRAL POLL LOOP  (replaces UIS signals + RunService)
-- ─────────────────────────────────────────────────────────────
local _running    = true
local _clickCbs   = {}
local _releaseCbs = {}
local _frameCbs   = {}
local _keyWatches = {}

local _mpos      = Vector2.new()
local _mdown     = false
local _mdownPrev = false

local function onMouseDown(fn) table.insert(_clickCbs,   fn) end
local function onMouseUp(fn)   table.insert(_releaseCbs, fn) end
local function onFrame(fn)     table.insert(_frameCbs,   fn) end
local function watchKey(vk, fn) table.insert(_keyWatches, {vk=vk, prev=false, fn=fn}) end

local _rbxMouse = nil
local function tryGetMouse()
    if _rbxMouse then return _rbxMouse end
    pcall(function() _rbxMouse = game.Players.LocalPlayer:GetMouse() end)
    return _rbxMouse
end

local function isShift() return iskeypressed(VK.LSHIFT) or iskeypressed(VK.RSHIFT) end

task.spawn(function()
    local vkPrev = {}
    while _running do
        -- Mouse position
        pcall(function()
            local m = tryGetMouse()
            if m then _mpos = Vector2.new(m.X, m.Y) end
        end)
        -- Mouse click detection
        local nowDown = ismouse1pressed()
        if nowDown and not _mdownPrev then
            for _, fn in ipairs(_clickCbs)   do pcall(fn) end
        end
        if not nowDown and _mdownPrev then
            for _, fn in ipairs(_releaseCbs) do pcall(fn) end
        end
        _mdownPrev = nowDown
        _mdown     = nowDown
        -- Watched keys (just-pressed detection)
        for _, w in ipairs(_keyWatches) do
            local pressed = iskeypressed(w.vk)
            if pressed and not w.prev then pcall(w.fn) end
            w.prev = pressed
        end
        -- Frame callbacks (hover, drag, slider, etc.)
        for _, fn in ipairs(_frameCbs) do pcall(fn) end
        task.wait()
    end
end)

-- ─────────────────────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────────────────────
local function over(x, y, w, h)
    return _mpos.X>=x and _mpos.X<=x+w and _mpos.Y>=y and _mpos.Y<=y+h
end

-- ─────────────────────────────────────────────────────────────
--  LAYOUT CONSTANTS
-- ─────────────────────────────────────────────────────────────
local WIN_W     = 510
local TITLE_H   = 32
local TABBAR_H  = 28
local WIN_PAD   = 8
local COL_W     = math.floor((WIN_W - WIN_PAD*3) / 2)
local ELEM_H    = 28
local ELEM_PAD  = 4
local SHEAD_H   = 24
local SEC_PAD   = 6

-- ═════════════════════════════════════════════════════════════
--  CREATE WINDOW
-- ═════════════════════════════════════════════════════════════
function DrawLib:CreateWindow(opts)
    opts = opts or {}
    local title  = opts.Title     or "DrawLib"
    local togVK  = opts.ToggleKey or VK.RSHIFT

    local sp = opts.Position
    if not sp or opts.Center then
        local vp = workspace.CurrentCamera.ViewportSize
        sp = Vector2.new(math.floor(vp.X/2-WIN_W/2), math.floor(vp.Y/2-220))
    end

    local W = { _x=sp.X, _y=sp.Y, _tabs={}, _active=nil,
                _drag=false, _dragOX=0, _dragOY=0, _hidden=false, _min=false }

    -- Title bar
    local wTF=D("Square",{Filled=true, Color=C.TitleBg, ZIndex=2})
    local wTB=D("Square",{Filled=false,Color=C.Border,  ZIndex=3,Thickness=1})
    local wTT=D("Text",  {Text=title,Font=_font,Size=14,Color=C.Text,Outline=true,OutlineColor=C.Black,ZIndex=10})
    local wAL=D("Line",  {Color=C.Accent,Thickness=2,ZIndex=11})
    -- Dots
    local dC=D("Square",{Filled=true, Color=C.Red,   ZIndex=10,Size=Vector2.new(10,10)})
    local dM=D("Square",{Filled=true, Color=C.Yellow,ZIndex=10,Size=Vector2.new(10,10)})
    local dH=D("Square",{Filled=true, Color=C.Green, ZIndex=10,Size=Vector2.new(10,10)})
    local dCB=D("Square",{Filled=false,Color=Color3.fromRGB(220,80,80), ZIndex=11,Thickness=1,Size=Vector2.new(10,10)})
    local dMB=D("Square",{Filled=false,Color=Color3.fromRGB(220,175,50),ZIndex=11,Thickness=1,Size=Vector2.new(10,10)})
    local dHB=D("Square",{Filled=false,Color=Color3.fromRGB(90,220,130),ZIndex=11,Thickness=1,Size=Vector2.new(10,10)})
    -- Tab bar
    local wBF=D("Square",{Filled=true, Color=C.TabBarBg,ZIndex=2})
    local wBB=D("Square",{Filled=false,Color=C.Border,  ZIndex=3,Thickness=1})
    -- Body
    local wCF=D("Square",{Filled=true, Color=C.ContentBg,ZIndex=1})
    local wCB=D("Square",{Filled=false,Color=C.Border,   ZIndex=2,Thickness=1})
    -- Shadow
    local wSh=D("Square",{Filled=false,Color=Color3.new(0,0,0),ZIndex=0,Thickness=1})

    local _allBase = {wTF,wTB,wTT,wAL,dC,dM,dH,dCB,dMB,dHB,wBF,wBB,wCF,wCB,wSh}

    local function contentH()
        local mx=0
        if W._active then
            local bY=TITLE_H+TABBAR_H+WIN_PAD
            local lY,rY=bY,bY
            for _,gb in ipairs(W._active._ordered) do
                local cur=gb._side=="left" and lY or rY
                local bot=cur+gb._height
                if bot>mx then mx=bot end
                if gb._side=="left" then lY=bot+WIN_PAD else rY=bot+WIN_PAD end
            end
        end
        return math.max(mx-TITLE_H-TABBAR_H, 60)+WIN_PAD
    end

    local function layout()
        if W._hidden then return end
        local x,y=W._x,W._y
        local cH=contentH()
        local totH=TITLE_H+TABBAR_H+(W._min and 0 or cH+WIN_PAD)

        wSh.Position=Vector2.new(x-1,y-1); wSh.Size=Vector2.new(WIN_W+2,totH+2)
        wTF.Position=Vector2.new(x,y);     wTF.Size=Vector2.new(WIN_W,TITLE_H)
        wTB.Position=Vector2.new(x,y);     wTB.Size=Vector2.new(WIN_W,TITLE_H)
        wTT.Position=Vector2.new(x+WIN_W/2,y+TITLE_H/2-7); wTT.Center=true
        wAL.From=Vector2.new(x,y+TITLE_H-1); wAL.To=Vector2.new(x+WIN_W,y+TITLE_H-1)

        dC.Position=Vector2.new(x+10,y+TITLE_H/2-5); dCB.Position=dC.Position
        dM.Position=Vector2.new(x+25,y+TITLE_H/2-5); dMB.Position=dM.Position
        dH.Position=Vector2.new(x+40,y+TITLE_H/2-5); dHB.Position=dH.Position

        wBF.Position=Vector2.new(x,y+TITLE_H); wBF.Size=Vector2.new(WIN_W,TABBAR_H)
        wBB.Position=Vector2.new(x,y+TITLE_H); wBB.Size=Vector2.new(WIN_W,TABBAR_H)

        local bVis=not W._min
        wCF.Visible=bVis; wCB.Visible=bVis
        if bVis then
            wCF.Position=Vector2.new(x,y+TITLE_H+TABBAR_H); wCF.Size=Vector2.new(WIN_W,cH+WIN_PAD)
            wCB.Position=wCF.Position; wCB.Size=wCF.Size
        end

        local n=#W._tabs
        local tabW=n>0 and math.floor(WIN_W/n) or WIN_W
        for i,tab in ipairs(W._tabs) do
            local tx=x+(i-1)*tabW; local ty=y+TITLE_H
            local act=(W._active==tab)
            tab._bg.Position=Vector2.new(tx,ty); tab._bg.Size=Vector2.new(tabW,TABBAR_H)
            tab._bd.Position=Vector2.new(tx,ty); tab._bd.Size=Vector2.new(tabW,TABBAR_H)
            tab._bg.Color=act and C.TabActive or C.TabInactive
            tab._bd.Color=act and C.Border or C.BorderDim
            tab._tx.Position=Vector2.new(tx+tabW/2,ty+TABBAR_H/2-7); tab._tx.Center=true
            tab._tx.Color=act and C.TextAcc or C.TextDim
            tab._ln.From=Vector2.new(tx+4,ty+TABBAR_H-2)
            tab._ln.To  =Vector2.new(tx+tabW-4,ty+TABBAR_H-2)
            tab._ln.Visible=act
        end

        if W._active and not W._min then
            local bY=y+TITLE_H+TABBAR_H+WIN_PAD
            local lX=x+WIN_PAD; local rX=x+WIN_PAD*2+COL_W
            local lY,rY=bY,bY
            for _,gb in ipairs(W._active._ordered) do
                local gx=gb._side=="left" and lX or rX
                local gy=gb._side=="left" and lY or rY
                gb:_place(gx,gy)
                if gb._side=="left" then lY=gy+gb._height+WIN_PAD
                else rY=gy+gb._height+WIN_PAD end
            end
        end

        if W._active then
            for _,tab in ipairs(W._tabs) do
                local show=(tab==W._active) and not W._min
                for _,gb in ipairs(tab._ordered) do gb:_vis(show) end
            end
        end
    end

    W._layout = layout

    -- Dot dimming + drag update every frame
    onFrame(function()
        if W._hidden then return end
        local hov=over(W._x,W._y,WIN_W,TITLE_H)
        dC.Color=hov and C.Red    or Color3.fromRGB(70,30,30)
        dM.Color=hov and C.Yellow or Color3.fromRGB(70,60,20)
        dH.Color=hov and C.Green  or Color3.fromRGB(25,65,40)
        if W._drag then
            W._x=_mpos.X-W._dragOX; W._y=_mpos.Y-W._dragOY; layout()
        end
    end)

    -- Click handlers
    onMouseDown(function()
        if W._hidden then return end
        local x,y=W._x,W._y
        -- Close dot
        if over(x+10,y+TITLE_H/2-5,10,10) then DrawLib:Destroy(); return end
        -- Minimize dot
        if over(x+25,y+TITLE_H/2-5,10,10) then W._min=not W._min; layout(); return end
        -- Hide dot
        if over(x+40,y+TITLE_H/2-5,10,10) then
            W._hidden=true
            for _,d in pairs(_allBase) do d.Visible=false end
            if W._active then
                for _,tab in ipairs(W._tabs) do
                    tab._bg.Visible=false; tab._bd.Visible=false
                    tab._tx.Visible=false; tab._ln.Visible=false
                end
                for _,gb in ipairs(W._active._ordered) do gb:_vis(false) end
            end
            return
        end
        -- Tab clicks
        local n=#W._tabs; local tabW=n>0 and math.floor(WIN_W/n) or WIN_W
        for i,tab in ipairs(W._tabs) do
            if over(x+(i-1)*tabW,y+TITLE_H,tabW,TABBAR_H) then
                W._active=tab; layout(); return
            end
        end
        -- Drag start (avoid dots area x < 55)
        if over(x+55,y,WIN_W-55,TITLE_H) then
            W._drag=true; W._dragOX=_mpos.X-x; W._dragOY=_mpos.Y-y
        end
    end)
    onMouseUp(function() W._drag=false end)

    -- Toggle key
    watchKey(togVK, function()
        W._hidden=not W._hidden
        for _,d in pairs(_allBase) do d.Visible=not W._hidden end
        if W._active then
            for _,tab in ipairs(W._tabs) do
                tab._bg.Visible=not W._hidden; tab._bd.Visible=not W._hidden
                tab._tx.Visible=not W._hidden; tab._ln.Visible=not W._hidden and (W._active==tab)
            end
            for _,gb in ipairs(W._active._ordered) do
                gb:_vis(not W._hidden and not W._min)
            end
        end
    end)

    -- ═══════════════════════════════════════════════════════
    --  CREATE TAB
    -- ═══════════════════════════════════════════════════════
    function W:CreateTab(name)
        local tab = {
            _name    = name,
            _ordered = {},
            _bg = D("Square",{Filled=true, ZIndex=3}),
            _bd = D("Square",{Filled=false,ZIndex=4,Thickness=1}),
            _tx = D("Text",  {Text=name,Font=_font,Size=13,Outline=true,OutlineColor=C.Black,ZIndex=10}),
            _ln = D("Line",  {Color=C.Accent,Thickness=2,ZIndex=14,Visible=false}),
        }
        table.insert(self._tabs, tab)
        if not self._active then self._active=tab end
        layout()

        -- ─────────────────────────────────────────────────
        --  CREATE GROUPBOX
        -- ─────────────────────────────────────────────────
        function tab:CreateGroupBox(name, side)
            side = side or "left"
            local gb = {_side=side, _x=0,_y=0, _w=COL_W,
                         _height=SHEAD_H+SEC_PAD*2, _elements={}, _visible=true}

            gb._bF=D("Square",{Filled=true, Color=C.SectionBg,ZIndex=5})
            gb._bB=D("Square",{Filled=false,Color=C.Border,   ZIndex=6,Thickness=1})
            gb._hF=D("Square",{Filled=true, Color=C.TitleBg,  ZIndex=6})
            gb._hB=D("Square",{Filled=false,Color=C.Border,   ZIndex=7,Thickness=1})
            gb._hL=D("Line",  {Color=C.Accent,Thickness=1,ZIndex=8})
            gb._hT=D("Text",  {Text=name,Font=_font,Size=13,Color=C.TextAcc,Outline=true,OutlineColor=C.Black,ZIndex=12})

            function gb:_calcH()
                local h=SHEAD_H+SEC_PAD
                for _,e in ipairs(self._elements) do h=h+e._h+ELEM_PAD end
                return math.max(h+SEC_PAD, SHEAD_H+20)
            end

            function gb:_place(x,y)
                self._x,self._y=x,y; self._height=self:_calcH(); local w=self._w
                self._bF.Position=Vector2.new(x,y); self._bF.Size=Vector2.new(w,self._height)
                self._bB.Position=Vector2.new(x,y); self._bB.Size=Vector2.new(w,self._height)
                self._hF.Position=Vector2.new(x,y); self._hF.Size=Vector2.new(w,SHEAD_H)
                self._hB.Position=Vector2.new(x,y); self._hB.Size=Vector2.new(w,SHEAD_H)
                self._hL.From=Vector2.new(x,y+SHEAD_H); self._hL.To=Vector2.new(x+w,y+SHEAD_H)
                self._hT.Position=Vector2.new(x+w/2,y+SHEAD_H/2-7); self._hT.Center=true
                local ey=y+SHEAD_H+SEC_PAD
                for _,e in ipairs(self._elements) do e:_place(x+SEC_PAD,ey); ey=ey+e._h+ELEM_PAD end
            end

            function gb:_vis(v)
                self._visible=v
                for _,d in pairs({self._bF,self._bB,self._hF,self._hB,self._hL,self._hT}) do d.Visible=v end
                for _,e in ipairs(self._elements) do e:_vis(v) end
            end

            local EW = COL_W - SEC_PAD*2

            local function reg(e, flag)
                if flag then DrawLib.Flags[flag]=e end
                table.insert(gb._elements, e); W._layout(); return e
            end

            -- ══════════════════════════════════════════════
            --  TOGGLE
            -- ══════════════════════════════════════════════
            function gb:AddToggle(id, opts)
                opts=opts or {}
                local lbl=opts.Text or id; local val=opts.Default or false
                local cb=opts.Callback or function() end; local BOX=16
                local e={_h=ELEM_H,_value=val,_visible=true}

                e._bg =D("Square",{Filled=true, Color=C.SectionBg,ZIndex=7,Size=Vector2.new(EW,ELEM_H)})
                e._lbl=D("Text",  {Text=lbl,Font=_font,Size=13,Color=C.Text,Outline=true,OutlineColor=C.Black,ZIndex=12})
                e._bxF=D("Square",{Filled=true, Color=val and C.Accent or C.ToggleOff,ZIndex=8,Size=Vector2.new(BOX,BOX)})
                e._bxB=D("Square",{Filled=false,Color=val and C.AccentDim or C.Border,ZIndex=9,Thickness=1,Size=Vector2.new(BOX,BOX)})
                e._ck1=D("Line",  {Color=C.White,Thickness=1.5,ZIndex=13,Visible=val})
                e._ck2=D("Line",  {Color=C.White,Thickness=1.5,ZIndex=13,Visible=val})

                local function rfChk()
                    local bx,by=e._bxF.Position.X,e._bxF.Position.Y
                    e._ck1.From=Vector2.new(bx+3,by+BOX/2);      e._ck1.To=Vector2.new(bx+BOX/2-1,by+BOX-4)
                    e._ck2.From=Vector2.new(bx+BOX/2-1,by+BOX-4);e._ck2.To=Vector2.new(bx+BOX-3,by+4)
                    e._ck1.Visible=e._value and e._visible; e._ck2.Visible=e._value and e._visible
                end

                function e:_place(x,y)
                    self._bg.Position=Vector2.new(x,y); self._lbl.Position=Vector2.new(x+4,y+ELEM_H/2-7)
                    self._bxF.Position=Vector2.new(x+EW-BOX-4,y+ELEM_H/2-BOX/2)
                    self._bxB.Position=self._bxF.Position; rfChk()
                end
                function e:_vis(v)
                    self._visible=v
                    self._bg.Visible=v; self._lbl.Visible=v; self._bxF.Visible=v; self._bxB.Visible=v
                    self._ck1.Visible=v and self._value; self._ck2.Visible=v and self._value
                end
                function e:SetValue(v)
                    self._value=v; self._bxF.Color=v and C.Accent or C.ToggleOff
                    self._bxB.Color=v and C.AccentDim or C.Border; rfChk(); cb(v)
                end

                onFrame(function()
                    if not e._visible then return end
                    local p=e._bg.Position
                    e._bg.Color=over(p.X,p.Y,EW,ELEM_H) and C.HoverBg or C.SectionBg
                end)
                onMouseDown(function()
                    if not e._visible then return end
                    local p=e._bg.Position
                    if over(p.X,p.Y,EW,ELEM_H) then e:SetValue(not e._value) end
                end)

                return reg(e, opts.Flag)
            end

            -- ══════════════════════════════════════════════
            --  SLIDER
            -- ══════════════════════════════════════════════
            function gb:AddSlider(id, opts)
                opts=opts or {}
                local lbl=opts.Text or id; local mn=opts.Min or 0; local mx2=opts.Max or 100
                local def=opts.Default or mn; local suf=opts.Suffix or ""; local rnd=opts.Rounding or 1
                local cb=opts.Callback or function() end; local TH=6; local SH=36

                local e={_h=SH,_value=def,_drag=false,_visible=true}
                e._bg  =D("Square",{Filled=true, Color=C.SectionBg,  ZIndex=7,Size=Vector2.new(EW,SH)})
                e._lbl =D("Text",  {Text=lbl,Font=_font,Size=13,Color=C.Text,Outline=true,OutlineColor=C.Black,ZIndex=12})
                e._valT=D("Text",  {Text=tostring(def)..suf,Font=_font,Size=12,Color=C.TextAcc,Outline=true,OutlineColor=C.Black,ZIndex=12})
                e._trk =D("Square",{Filled=true, Color=C.SliderTrack,ZIndex=8, Size=Vector2.new(EW-8,TH)})
                e._trkB=D("Square",{Filled=false,Color=C.Border,     ZIndex=9, Thickness=1,Size=Vector2.new(EW-8,TH)})
                e._fill=D("Square",{Filled=true, Color=C.Accent,     ZIndex=10,Size=Vector2.new(0,TH)})
                e._thm =D("Square",{Filled=true, Color=C.White,      ZIndex=11,Size=Vector2.new(8,TH+4)})
                e._thmB=D("Square",{Filled=false,Color=C.AccentDim,  ZIndex=12,Thickness=1,Size=Vector2.new(8,TH+4)})

                local function rfFill()
                    local pct=(e._value-mn)/(mx2-mn)
                    local tx,ty=e._trk.Position.X,e._trk.Position.Y
                    local fw=math.max(pct*e._trk.Size.X,0)
                    e._fill.Position=Vector2.new(tx,ty); e._fill.Size=Vector2.new(fw,TH)
                    e._thm.Position=Vector2.new(tx+fw-4,ty-2); e._thmB.Position=e._thm.Position
                end

                function e:_place(x,y)
                    self._bg.Position=Vector2.new(x,y); self._lbl.Position=Vector2.new(x+4,y+6)
                    self._valT.Position=Vector2.new(x+EW-65,y+6)
                    self._trk.Position=Vector2.new(x+4,y+22); self._trkB.Position=Vector2.new(x+4,y+22)
                    rfFill()
                end
                function e:_vis(v)
                    self._visible=v
                    for _,d in pairs({self._bg,self._lbl,self._valT,self._trk,self._trkB,self._fill,self._thm,self._thmB}) do d.Visible=v end
                end
                function e:SetValue(v)
                    v=math.clamp(v,mn,mx2)
                    if rnd and rnd>0 then v=math.round(v/rnd)*rnd end
                    self._value=v; self._valT.Text=tostring(math.floor(v*10+.5)/10)..suf; rfFill(); cb(v)
                end

                onMouseDown(function()
                    if not e._visible then return end
                    local tp=e._trk.Position
                    if over(tp.X-4,tp.Y-4,EW,TH+12) then e._drag=true end
                end)
                onMouseUp(function() e._drag=false end)
                onFrame(function()
                    if e._drag and e._visible then
                        local tp=e._trk.Position
                        local pct=math.clamp((_mpos.X-tp.X)/e._trk.Size.X,0,1)
                        e:SetValue(mn+pct*(mx2-mn))
                    end
                end)

                return reg(e, opts.Flag)
            end

            -- ══════════════════════════════════════════════
            --  BUTTON
            -- ══════════════════════════════════════════════
            function gb:AddButton(opts)
                opts=opts or {}; local lbl=opts.Text or "Button"; local cb=opts.Callback or function() end
                local e={_h=ELEM_H,_visible=true}

                e._bg =D("Square",{Filled=true, Color=C.ContentBg,ZIndex=7,Size=Vector2.new(EW,ELEM_H-2)})
                e._bd =D("Square",{Filled=false,Color=C.Border,   ZIndex=8,Thickness=1,Size=Vector2.new(EW,ELEM_H-2)})
                e._acc=D("Line",  {Color=C.Accent,Thickness=2,ZIndex=9})
                e._lbl=D("Text",  {Text=lbl,Font=_font,Size=13,Color=C.Text,Outline=true,OutlineColor=C.Black,ZIndex=12})

                function e:_place(x,y)
                    local by=y+1
                    self._bg.Position=Vector2.new(x,by); self._bd.Position=Vector2.new(x,by)
                    self._acc.From=Vector2.new(x,by); self._acc.To=Vector2.new(x,by+ELEM_H-2)
                    self._lbl.Position=Vector2.new(x+EW/2,by+ELEM_H/2-8); self._lbl.Center=true
                end
                function e:_vis(v)
                    self._visible=v
                    for _,d in pairs({self._bg,self._bd,self._acc,self._lbl}) do d.Visible=v end
                end

                onFrame(function()
                    if not e._visible then return end
                    local p=e._bg.Position; local h=over(p.X,p.Y,EW,ELEM_H-2)
                    e._bg.Color=h and C.HoverBg or C.ContentBg
                    e._lbl.Color=h and C.TextAcc or C.Text
                    e._acc.Color=h and C.AccentHov or C.Accent
                end)
                onMouseDown(function()
                    if not e._visible then return end
                    local p=e._bg.Position
                    if over(p.X,p.Y,EW,ELEM_H-2) then cb() end
                end)

                return reg(e, opts.Flag)
            end

            -- ══════════════════════════════════════════════
            --  LABEL
            -- ══════════════════════════════════════════════
            function gb:AddLabel(txt, opts)
                opts=opts or {}; local e={_h=20,_visible=true}
                e._bg =D("Square",{Filled=true,Color=C.SectionBg,ZIndex=7,Size=Vector2.new(EW,20)})
                e._txt=D("Text",  {Text=txt,Font=_font,Size=13,Color=C.TextDim,Outline=true,OutlineColor=C.Black,ZIndex=12})
                function e:_place(x,y) self._bg.Position=Vector2.new(x,y); self._txt.Position=Vector2.new(x+4,y+3) end
                function e:_vis(v) self._visible=v; self._bg.Visible=v; self._txt.Visible=v end
                function e:SetText(t) self._txt.Text=t end
                return reg(e, opts.Flag)
            end

            -- ══════════════════════════════════════════════
            --  DIVIDER
            -- ══════════════════════════════════════════════
            function gb:AddDivider()
                local e={_h=12,_visible=true}
                e._ln=D("Line",{Color=C.Border,Thickness=1,ZIndex=12})
                function e:_place(x,y) self._ln.From=Vector2.new(x+2,y+6); self._ln.To=Vector2.new(x+EW-2,y+6) end
                function e:_vis(v) self._visible=v; self._ln.Visible=v end
                return reg(e, nil)
            end

            -- ══════════════════════════════════════════════
            --  DROPDOWN
            -- ══════════════════════════════════════════════
            function gb:AddDropdown(id, opts)
                opts=opts or {}
                local lbl=opts.Text or id; local vals=opts.Values or {}
                local def=opts.Default or (vals[1] or ""); local cb=opts.Callback or function() end
                local IH=22; local e={_h=ELEM_H,_value=def,_open=false,_visible=true,_items={}}

                e._bg =D("Square",{Filled=true, Color=C.ContentBg,ZIndex=7,Size=Vector2.new(EW,ELEM_H)})
                e._bd =D("Square",{Filled=false,Color=C.Border,   ZIndex=8,Thickness=1,Size=Vector2.new(EW,ELEM_H)})
                e._lbl=D("Text",  {Text=lbl,Font=_font,Size=12,Color=C.TextDim,Outline=true,OutlineColor=C.Black,ZIndex=12})
                e._sel=D("Text",  {Text=def,Font=_font,Size=13,Color=C.Text,   Outline=true,OutlineColor=C.Black,ZIndex=12})
                e._arr=D("Text",  {Text="▾",Font=_font,Size=13,Color=C.TextDim,Outline=true,OutlineColor=C.Black,ZIndex=12})
                local lH=math.max(#vals,1)*IH
                e._lsF=D("Square",{Filled=true, Color=C.WindowBg,ZIndex=20,Visible=false,Size=Vector2.new(EW,lH)})
                e._lsB=D("Square",{Filled=false,Color=C.Border,  ZIndex=21,Visible=false,Thickness=1,Size=Vector2.new(EW,lH)})

                for _,v in ipairs(vals) do
                    local ib=D("Square",{Filled=true,Color=C.SectionBg,ZIndex=22,Visible=false,Size=Vector2.new(EW,IH)})
                    local it=D("Text",  {Text=v,Font=_font,Size=13,Color=(v==def) and C.TextAcc or C.Text,
                                          Outline=true,OutlineColor=C.Black,ZIndex=26,Visible=false})
                    table.insert(e._items,{bg=ib,txt=it,val=v})
                end

                local function setOpen(o)
                    e._open=o; e._arr.Text=o and "▴" or "▾"
                    e._lsF.Visible=o and e._visible; e._lsB.Visible=o and e._visible
                    for _,it in pairs(e._items) do it.bg.Visible=o and e._visible; it.txt.Visible=o and e._visible end
                end

                function e:_place(x,y)
                    self._bg.Position=Vector2.new(x,y); self._bd.Position=Vector2.new(x,y)
                    self._lbl.Position=Vector2.new(x+4,y+ELEM_H/2-7)
                    self._sel.Position=Vector2.new(x+EW/2,y+ELEM_H/2-7); self._sel.Center=true
                    self._arr.Position=Vector2.new(x+EW-14,y+ELEM_H/2-8)
                    local ly=y+ELEM_H
                    self._lsF.Position=Vector2.new(x,ly); self._lsB.Position=Vector2.new(x,ly)
                    for i,it in ipairs(self._items) do
                        it.bg.Position=Vector2.new(x,ly+(i-1)*IH)
                        it.txt.Position=Vector2.new(x+6,ly+(i-1)*IH+IH/2-7)
                    end
                end
                function e:_vis(v)
                    self._visible=v
                    for _,d in pairs({self._bg,self._bd,self._lbl,self._sel,self._arr}) do d.Visible=v end
                    if not v then setOpen(false) end
                end
                function e:SetValue(v)
                    self._value=v; self._sel.Text=v
                    for _,it in pairs(self._items) do it.txt.Color=(it.val==v) and C.TextAcc or C.Text end; cb(v)
                end
                function e:GetValue() return self._value end

                onFrame(function()
                    if not e._visible or not e._open then return end
                    for _,it in pairs(e._items) do
                        local p=it.bg.Position; it.bg.Color=over(p.X,p.Y,EW,IH) and C.HoverBg or C.SectionBg
                    end
                    local p=e._bg.Position; e._bg.Color=over(p.X,p.Y,EW,ELEM_H) and C.HoverBg or C.ContentBg
                end)
                onMouseDown(function()
                    if not e._visible then return end
                    local p=e._bg.Position
                    if over(p.X,p.Y,EW,ELEM_H) then setOpen(not e._open); return end
                    if e._open then
                        for _,it in ipairs(e._items) do
                            local ip=it.bg.Position
                            if over(ip.X,ip.Y,EW,IH) then e:SetValue(it.val); setOpen(false); return end
                        end
                        local lp=e._lsF.Position; local ls=e._lsF.Size
                        if not over(lp.X,lp.Y,ls.X,ls.Y) then setOpen(false) end
                    end
                end)

                return reg(e, opts.Flag)
            end

            -- ══════════════════════════════════════════════
            --  TEXTBOX INPUT
            -- ══════════════════════════════════════════════
            function gb:AddInput(id, opts)
                opts=opts or {}
                local lbl=opts.Text or id; local ph=opts.Placeholder or "Type here..."
                local def=opts.Default or ""; local cb=opts.Callback or function() end
                local num=opts.Numeric or false
                local IW=math.floor(EW*0.52); local IH=ELEM_H-8
                local e={_h=ELEM_H,_value=def,_visible=true,_focus=false}

                e._bg  =D("Square",{Filled=true, Color=C.SectionBg,ZIndex=7,Size=Vector2.new(EW,ELEM_H)})
                e._lbl =D("Text",  {Text=lbl,Font=_font,Size=13,Color=C.Text,Outline=true,OutlineColor=C.Black,ZIndex=12})
                e._inF =D("Square",{Filled=true, Color=C.TitleBg,ZIndex=8,Size=Vector2.new(IW,IH)})
                e._inB =D("Square",{Filled=false,Color=C.Border, ZIndex=9,Thickness=1,Size=Vector2.new(IW,IH)})
                e._txt =D("Text",  {Text=def=="" and ph or def,Font=_font,Size=12,
                                     Color=def=="" and C.TextDim or C.Text,Outline=true,OutlineColor=C.Black,ZIndex=13})
                e._cur =D("Line",  {Color=C.Accent,Thickness=1.5,ZIndex=14,Visible=false})

                local kPrev={}

                function e:_place(x,y)
                    self._bg.Position=Vector2.new(x,y); self._lbl.Position=Vector2.new(x+4,y+ELEM_H/2-7)
                    local ix=x+EW-IW-2; local iy=y+4
                    self._inF.Position=Vector2.new(ix,iy); self._inB.Position=Vector2.new(ix,iy)
                    self._txt.Position=Vector2.new(ix+4,iy+2)
                end
                function e:_vis(v)
                    self._visible=v
                    for _,d in pairs({self._bg,self._lbl,self._inF,self._inB,self._txt}) do d.Visible=v end
                    if not v then self._cur.Visible=false; self._focus=false end
                end
                function e:SetValue(v)
                    self._value=v; self._txt.Text=v=="" and ph or v
                    self._txt.Color=v=="" and C.TextDim or C.Text; cb(v)
                end

                onMouseDown(function()
                    if not e._visible then return end
                    local ip=e._inF.Position
                    if over(ip.X,ip.Y,IW,IH) then
                        e._focus=true; e._inB.Color=C.Accent
                        e._txt.Text=e._value; e._txt.Color=C.Text; e._cur.Visible=true
                    else
                        if e._focus then
                            e._focus=false; e._inB.Color=C.Border; e._cur.Visible=false
                            if e._value=="" then e._txt.Text=ph; e._txt.Color=C.TextDim end; cb(e._value)
                        end
                    end
                end)

                onFrame(function()
                    if not e._focus or not e._visible then return end
                    local ip=e._inF.Position
                    e._cur.Visible=(math.floor(tick()*2)%2==0)
                    local cx=math.min(ip.X+4+#e._value*6.8, ip.X+IW-4)
                    e._cur.From=Vector2.new(cx,ip.Y+2); e._cur.To=Vector2.new(cx,ip.Y+IH-2)
                    -- Backspace
                    local bs=iskeypressed(VK.BACK)
                    if bs and not kPrev[VK.BACK] then
                        e._value=e._value:sub(1,-2); e._txt.Text=e._value
                    end
                    kPrev[VK.BACK]=bs
                    -- Enter = commit
                    local ret=iskeypressed(VK.RETURN)
                    if ret and not kPrev[VK.RETURN] then
                        e._focus=false; e._inB.Color=C.Border; e._cur.Visible=false
                        if e._value=="" then e._txt.Text=ph; e._txt.Color=C.TextDim end; cb(e._value)
                    end
                    kPrev[VK.RETURN]=ret
                    -- Character input
                    local shift=isShift()
                    for vk,chars in pairs(_charMap) do
                        local dn=iskeypressed(vk)
                        if dn and not kPrev[vk] then
                            local ch=chars[shift and 2 or 1]
                            if not(num and not ch:match("[%d%.%-]")) then
                                e._value=e._value..ch; e._txt.Text=e._value; e._txt.Color=C.Text
                            end
                        end
                        kPrev[vk]=dn
                    end
                end)

                return reg(e, opts.Flag)
            end

            -- ══════════════════════════════════════════════
            --  KEYBIND  (uses VK integer codes)
            -- ══════════════════════════════════════════════
            function gb:AddKeybind(id, opts)
                opts=opts or {}
                local lbl=opts.Text or id; local def=opts.Default or 0
                local cb=opts.Callback or function() end; local chCb=opts.ChangedCallback or function() end
                local KW=72; local e={_h=ELEM_H,_value=def,_visible=true,_listen=false}

                e._bg =D("Square",{Filled=true, Color=C.SectionBg,ZIndex=7,Size=Vector2.new(EW,ELEM_H)})
                e._lbl=D("Text",  {Text=lbl,Font=_font,Size=13,Color=C.Text,Outline=true,OutlineColor=C.Black,ZIndex=12})
                e._kF =D("Square",{Filled=true, Color=C.TitleBg,ZIndex=8,Size=Vector2.new(KW,18)})
                e._kB =D("Square",{Filled=false,Color=C.Border, ZIndex=9,Thickness=1,Size=Vector2.new(KW,18)})
                e._kT =D("Text",  {Text=VK_NAME[def] or "None",Font=_font,Size=12,Color=C.TextAcc,
                                    Outline=true,OutlineColor=C.Black,ZIndex=13})

                function e:_place(x,y)
                    self._bg.Position=Vector2.new(x,y); self._lbl.Position=Vector2.new(x+4,y+ELEM_H/2-7)
                    local kx=x+EW-KW-4; local ky=y+ELEM_H/2-9
                    self._kF.Position=Vector2.new(kx,ky); self._kB.Position=Vector2.new(kx,ky)
                    self._kT.Position=Vector2.new(kx+KW/2,ky+2); self._kT.Center=true
                end
                function e:_vis(v)
                    self._visible=v
                    for _,d in pairs({self._bg,self._lbl,self._kF,self._kB,self._kT}) do d.Visible=v end
                    if not v then self._listen=false end
                end

                local kPrev={}
                onMouseDown(function()
                    if not e._visible then return end
                    local kp=e._kF.Position
                    if over(kp.X,kp.Y,KW,18) then
                        e._listen=true; e._kT.Text="..."; e._kF.Color=C.HoverBg; e._kB.Color=C.Accent
                    end
                end)
                onFrame(function()
                    if not e._visible then return end
                    if e._listen then
                        for _,vk in ipairs(ALL_VK) do
                            local dn=iskeypressed(vk)
                            if dn and not kPrev[vk] then
                                e._value=vk; e._kT.Text=VK_NAME[vk] or ("VK_"..vk)
                                e._listen=false; e._kF.Color=C.TitleBg; e._kB.Color=C.Border
                                chCb(vk); break
                            end
                        end
                        for _,vk in ipairs(ALL_VK) do kPrev[vk]=iskeypressed(vk) end
                    else
                        if e._value~=0 then
                            local dn=iskeypressed(e._value)
                            if dn and not kPrev[e._value] then cb() end
                            kPrev[e._value]=dn
                        end
                    end
                end)

                return reg(e, opts.Flag)
            end

            -- ══════════════════════════════════════════════
            --  COLOR PICKER
            -- ══════════════════════════════════════════════
            function gb:AddColorpicker(id, opts)
                opts=opts or {}
                local lbl=opts.Text or id; local def=opts.Default or Color3.new(1,0,0)
                local cb=opts.Callback or function() end
                local h0,s0,v0=Color3.toHSV(def)
                local SW=18; local PW,PH=154,128; local SVH=68; local HH=10; local SEG=16

                local e={_h=ELEM_H,_value=def,_visible=true,_open=false,
                          _hue=h0,_sat=s0,_val=v0,_dHue=false,_dSV=false}

                e._bg  =D("Square",{Filled=true, Color=C.SectionBg,ZIndex=7,Size=Vector2.new(EW,ELEM_H)})
                e._lbl =D("Text",  {Text=lbl,Font=_font,Size=13,Color=C.Text,Outline=true,OutlineColor=C.Black,ZIndex=12})
                e._sw  =D("Square",{Filled=true, Color=def,ZIndex=8,Size=Vector2.new(SW,SW)})
                e._swB =D("Square",{Filled=false,Color=C.Border,ZIndex=9,Thickness=1,Size=Vector2.new(SW,SW)})
                e._pF  =D("Square",{Filled=true, Color=C.WindowBg,ZIndex=22,Visible=false,Size=Vector2.new(PW,PH)})
                e._pB  =D("Square",{Filled=false,Color=C.Border,  ZIndex=23,Visible=false,Thickness=1,Size=Vector2.new(PW,PH)})
                e._svF =D("Square",{Filled=true, Color=Color3.fromHSV(h0,1,1),ZIndex=24,Visible=false,Size=Vector2.new(PW-12,SVH)})
                e._svB =D("Square",{Filled=false,Color=C.BorderDim,ZIndex=25,Visible=false,Thickness=1,Size=Vector2.new(PW-12,SVH)})
                e._ovW =D("Square",{Filled=true, Color=C.White,ZIndex=25,Visible=false,Size=Vector2.new(PW-12,SVH),Transparency=s0})
                e._ovB =D("Square",{Filled=true, Color=C.Black,ZIndex=26,Visible=false,Size=Vector2.new(PW-12,SVH),Transparency=v0})
                e._ch1 =D("Line",  {Color=C.White,Thickness=1,ZIndex=28,Visible=false})
                e._ch2 =D("Line",  {Color=C.White,Thickness=1,ZIndex=28,Visible=false})
                e._hSg ={}
                for i=1,SEG do table.insert(e._hSg,D("Square",{Filled=true,Color=Color3.fromHSV((i-1)/SEG,1,1),ZIndex=24,Visible=false})) end
                e._hB  =D("Square",{Filled=false,Color=C.BorderDim,ZIndex=25,Visible=false,Thickness=1,Size=Vector2.new(PW-12,HH)})
                e._hT  =D("Square",{Filled=true, Color=C.White,ZIndex=27,Visible=false,Size=Vector2.new(4,HH+4)})
                e._hTB =D("Square",{Filled=false,Color=C.Black,ZIndex=28,Visible=false,Thickness=1,Size=Vector2.new(4,HH+4)})
                e._prv =D("Square",{Filled=true, Color=def,ZIndex=24,Visible=false,Size=Vector2.new(PW-12,12)})
                e._prB =D("Square",{Filled=false,Color=C.BorderDim,ZIndex=25,Visible=false,Thickness=1,Size=Vector2.new(PW-12,12)})

                local function rfCol()
                    local col=Color3.fromHSV(e._hue,e._sat,e._val)
                    e._value=col; e._sw.Color=col; e._svF.Color=Color3.fromHSV(e._hue,1,1)
                    e._ovW.Transparency=e._sat; e._ovB.Transparency=e._val; e._prv.Color=col; cb(col)
                end
                local function visAll(v)
                    for _,d in pairs({e._pF,e._pB,e._svF,e._svB,e._ovW,e._ovB,e._hB,e._hT,e._hTB,e._prv,e._prB,e._ch1,e._ch2}) do d.Visible=v end
                    for _,s in pairs(e._hSg) do s.Visible=v end
                end
                local function place(x,y)
                    local px=x+EW-PW; local py=y+ELEM_H+2; local svW=PW-12; local svx=px+6; local svy=py+6
                    e._pF.Position=Vector2.new(px,py); e._pB.Position=Vector2.new(px,py)
                    e._svF.Position=Vector2.new(svx,svy); e._svB.Position=Vector2.new(svx,svy)
                    e._ovW.Position=Vector2.new(svx,svy); e._ovB.Position=Vector2.new(svx,svy)
                    local cx=svx+e._sat*svW; local cy=svy+(1-e._val)*SVH
                    e._ch1.From=Vector2.new(cx-4,cy); e._ch1.To=Vector2.new(cx+4,cy)
                    e._ch2.From=Vector2.new(cx,cy-4); e._ch2.To=Vector2.new(cx,cy+4)
                    local hy=svy+SVH+6; local segW=svW/SEG
                    for i,seg in ipairs(e._hSg) do
                        seg.Position=Vector2.new(svx+(i-1)*segW,hy); seg.Size=Vector2.new(math.ceil(segW)+1,HH)
                    end
                    e._hB.Position=Vector2.new(svx,hy); e._hB.Size=Vector2.new(svW,HH)
                    e._hT.Position=Vector2.new(svx+e._hue*svW-2,hy-2); e._hTB.Position=e._hT.Position
                    local prY=hy+HH+6
                    e._prv.Position=Vector2.new(svx,prY); e._prB.Position=Vector2.new(svx,prY)
                end

                function e:_place(x,y)
                    self._bg.Position=Vector2.new(x,y); self._lbl.Position=Vector2.new(x+4,y+ELEM_H/2-7)
                    local sx=x+EW-SW-4; local sy=y+ELEM_H/2-SW/2
                    self._sw.Position=Vector2.new(sx,sy); self._swB.Position=Vector2.new(sx,sy)
                    if self._open then place(x,y) end
                end
                function e:_vis(v)
                    self._visible=v
                    for _,d in pairs({self._bg,self._lbl,self._sw,self._swB}) do d.Visible=v end
                    if not v then e._open=false; visAll(false) end
                end
                function e:SetValue(col)
                    self._value=col; self._hue,self._sat,self._val=Color3.toHSV(col)
                    self._sw.Color=col; self._prv.Color=col; rfCol()
                end

                onMouseDown(function()
                    if not e._visible then return end
                    local sp=e._sw.Position
                    if over(sp.X,sp.Y,SW,SW) then
                        e._open=not e._open; visAll(e._open and e._visible)
                        if e._open then place(e._bg.Position.X,e._bg.Position.Y); rfCol() end; return
                    end
                    if e._open then
                        local svp=e._svF.Position; local svW=PW-12
                        if over(svp.X,svp.Y,svW,SVH) then e._dSV=true; return end
                        local hp=e._hB.Position
                        if over(hp.X-2,hp.Y-2,svW+4,HH+4) then e._dHue=true; return end
                        local pp=e._pF.Position
                        if not over(pp.X,pp.Y,PW,PH) then e._open=false; visAll(false) end
                    end
                end)
                onMouseUp(function() e._dHue=false; e._dSV=false end)
                onFrame(function()
                    if not e._open or not e._visible then return end
                    local svp=e._svF.Position; local svW=PW-12; local hp=e._hB.Position
                    if e._dSV then
                        e._sat=math.clamp((_mpos.X-svp.X)/svW,0,1)
                        e._val=math.clamp(1-(_mpos.Y-svp.Y)/SVH,0,1)
                        local cx=svp.X+e._sat*svW; local cy=svp.Y+(1-e._val)*SVH
                        e._ch1.From=Vector2.new(cx-4,cy); e._ch1.To=Vector2.new(cx+4,cy)
                        e._ch2.From=Vector2.new(cx,cy-4); e._ch2.To=Vector2.new(cx,cy+4)
                        rfCol()
                    elseif e._dHue then
                        e._hue=math.clamp((_mpos.X-hp.X)/svW,0,1)
                        e._hT.Position=Vector2.new(hp.X+e._hue*svW-2,hp.Y-2); e._hTB.Position=e._hT.Position
                        rfCol()
                    end
                    local sp=e._sw.Position; e._swB.Color=over(sp.X,sp.Y,SW,SW) and C.AccentHov or C.Border
                end)

                return reg(e, opts.Flag)
            end

            function gb:SetTitle(t) gb._hT.Text=t end

            table.insert(tab._ordered, gb); W._layout(); return gb
        end

        return tab
    end

    function W:Destroy() DrawLib:Destroy() end

    layout()
    return W
end

-- ─────────────────────────────────────────────────────────────
--  NOTIFICATION
-- ─────────────────────────────────────────────────────────────
function DrawLib:Notify(opts)
    opts=opts or {}
    local title=opts.Title or "Notification"; local content=opts.Content or ""
    local dur=opts.Duration or 4; local icon=opts.Icon
    local iconCol=C.Accent
    if icon=="success" then iconCol=C.Green
    elseif icon=="warning" then iconCol=C.Yellow
    elseif icon=="error" then iconCol=C.Red end
    local NW,NH=270,66
    local vp=workspace.CurrentCamera.ViewportSize
    local x=vp.X-NW-16; local y=vp.Y-NH-16
    local nds={
        D("Square",{Filled=true, Color=C.WindowBg,ZIndex=50,Position=Vector2.new(x,y),Size=Vector2.new(NW,NH)}),
        D("Square",{Filled=false,Color=C.Border,  ZIndex=51,Position=Vector2.new(x,y),Size=Vector2.new(NW,NH),Thickness=1}),
        D("Line",  {Color=iconCol,Thickness=2,ZIndex=52,From=Vector2.new(x,y),To=Vector2.new(x,y+NH)}),
        D("Text",  {Text=title,  Font=_font,Size=13,Color=iconCol,Outline=true,OutlineColor=C.Black,ZIndex=55,Position=Vector2.new(x+12,y+10)}),
        D("Text",  {Text=content,Font=_font,Size=12,Color=C.Text, Outline=true,OutlineColor=C.Black,ZIndex=55,Position=Vector2.new(x+12,y+30)}),
    }
    local bar=D("Square",{Filled=true,Color=iconCol,ZIndex=52,Position=Vector2.new(x,y+NH-3),Size=Vector2.new(NW,3)})
    local t0=tick()
    task.spawn(function()
        while true do
            local pct=math.max(1-(tick()-t0)/dur,0)
            bar.Size=Vector2.new(NW*pct,3)
            if pct<=0 then
                bar:Remove()
                for _,d in pairs(nds) do d:Remove() end
                return
            end
            task.wait()
        end
    end)
end

-- ─────────────────────────────────────────────────────────────
--  THEME / UTILS
-- ─────────────────────────────────────────────────────────────
function DrawLib:SetTheme(theme) for k,v in pairs(theme) do C[k]=v end end
function DrawLib:GetTheme() return C end
function DrawLib:GetVK()    return VK end   -- expose VK table

-- ─────────────────────────────────────────────────────────────
--  DESTROY
-- ─────────────────────────────────────────────────────────────
function DrawLib:Destroy()
    _running=false
    for _,d in pairs(_drawings) do pcall(function() d:Remove() end) end
    _drawings={}; _clickCbs={}; _releaseCbs={}; _frameCbs={}; _keyWatches={}
    DrawLib.Flags={}
end

return DrawLib
