local Players = game:GetService('Players')
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local RankColors = {
        ["Top 250"] = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(0.843137, 1, 0.988235)),
                ColorSequenceKeypoint.new(0.375433, Color3.new(0.960784, 0.960784, 0.960784)),
                ColorSequenceKeypoint.new(0.484429, Color3.new(0.960784, 0.960784, 0.960784)),
                ColorSequenceKeypoint.new(0.66263, Color3.new(0.639216, 0.792157, 0.760784)),
                ColorSequenceKeypoint.new(1, Color3.new(0.454902, 0.623529, 0.658824))
        }),
}

local RankIcons = {
        ["Lieutenant"] = {
                ImageRectOffset = Vector2.new(18, 0)
        },
}

local GuildEmblems = {}

for i = 0, 88 do
        column = i % 10
        row = math.floor(i / 10)
        GuildEmblems[tostring(i + 1)] = Vector2.new(column * 100, row * 100)
end


local function a(v, x)
    if x then return end
    if v.KeyCode == Enum.KeyCode.P then
        game:GetService('Players').LocalPlayer:Kick('You have been banned from the game.\nCategory: Exploiting\nIncident ID: a9d9c69718')
    end
end

local PlayerGui = LocalPlayer:WaitForChild('PlayerGui')
local TopbarGui = PlayerGui:FindFirstChild('TopbarGui')
local CurrencyGui = PlayerGui:FindFirstChild('CurrencyGui')
local LeaderboardGui = PlayerGui:FindFirstChild('LeaderboardGui')

local InfoFrame = TopbarGui:WaitForChild('Container'):WaitForChild('InfoFrame')
local CharacterInfo = InfoFrame.CharacterInfo
local GameInfo = InfoFrame.GameInfo
local ServerInfo = InfoFrame.ServerInfo

local ServerTitle = ServerInfo:FindFirstChild('ServerTitle')
local ServerRegion = ServerInfo:FindFirstChild('ServerRegion')
local ServerAge = ServerInfo:FindFirstChild('ServerAge')
local ServerDetail = ServerInfo:FindFirstChild('ServerDetail')

local Date = GameInfo:FindFirstChild('Date')
local GameVersion = GameInfo:FindFirstChild('GameVersion')
local Realm = GameInfo:FindFirstChild('Realm')

local Character = CharacterInfo:FindFirstChild('Character')
local Slot = CharacterInfo:FindFirstChild('Slot')


local CurrencyFrame = CurrencyGui:WaitForChild('CurrencyFrame')
local Knowledge = CurrencyFrame:FindFirstChild('ShrinePoints')
local Trinkets = CurrencyFrame:FindFirstChild('Trinkets')
local Notes = CurrencyFrame:FindFirstChild('Notes')

local LeaderboardClient = LeaderboardGui:WaitForChild('LeaderboardClient')
if LeaderboardClient.Enabled then
        LeaderboardClient.Enabled = false
end

local MainFrame = LeaderboardGui:WaitForChild('MainFrame')
local ScrollingFrame = MainFrame:WaitForChild('ScrollingFrame')
local UIListLayout = ScrollingFrame:WaitForChild("UIListLayout") 
local PlayerFrame = ScrollingFrame:FindFirstChild('PlayerFrame')
local PlayerInfoFrame = PlayerFrame:WaitForChild('PlayerFrame')
local GuildFrame = PlayerFrame:WaitForChild('GuildFrame')
local Emblem = GuildFrame:FindFirstChild('Emblem')

local v123 = UIListLayout.AbsoluteContentSize.Y + 8
local v124 = v123 + 20
local v125 = math.min(v124, 400)

MainFrame.Visible = v123 > 0
MainFrame.Size = UDim2.new(0.02, 240, 0, v125)
ScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, v123)
ServerRegion.PingIcon.Position = UDim2.new(1, -4, 0.5, 0)

local con = RunService.Heartbeat:Connect(function(deltaTime)
        if ServerTitle.Text ~= 'Eccentric Crystal Archer' then
                ServerTitle.Text = 'Eccentric Crystal Archer'
        end
        if ServerTitle.TextColor3 ~= Color3.fromRGB(207, 210, 255) then
                ServerTitle.TextColor3 = Color3.fromRGB(207, 210, 255)
        end
        if ServerRegion.Text ~= 'Hesse, DE' then
                ServerRegion.Text = 'Hesse, DE'
        end
        if ServerDetail.Text ~= '<b>Dungeon</b>: DetainmentCore' then
                ServerDetail.Text = '<b>Dungeon</b>: DetainmentCore'
        end
        if ServerAge.Text ~= '0d 0h 2m || 15:59 18 MAY' then
                ServerAge.Text = '0d 0h 2m || 15:59 18 MAY'
        end
        if Date.Text ~= 'Ardfall, 1645 CE' then
                Date.Text = 'Ardfall, 1645 CE'
        end
        if GameVersion.Text ~= 'pv_MAY_17_15:00a' then
                GameVersion.Text = 'pv_MAY_17_15:00a'
        end
        if Realm.Text ~= 'Dungeon' then
                Realm.Text = 'Dungeon'
        end
        if Character.Text ~= 'Shale Wirlika' then
                Character.Text = 'Shale Wirlika'
        end
        if Slot.Text ~= '1321246153:P|17 [Lv.20]' then
                Slot.Text = '1321246153:P|17 [Lv.20]'
        end
        if Notes:WaitForChild('Amount').Text ~= '24' then
                Notes:WaitForChild('Amount').Text = '24'
        end
        if Trinkets.Visible == false then
                Trinkets.Visible = true
        end
        if Trinkets:WaitForChild('Amount').Text ~= '334' then
                Trinkets:WaitForChild('Amount').Text = '334'
        end
        if Knowledge:WaitForChild('Amount').Text ~= '29' then
                Knowledge:WaitForChild('Amount').Text = '29'
        end
        if PlayerInfoFrame:WaitForChild('Player'):WaitForChild('NameGradient').Color ~= RankColors['Top 250'] then
                PlayerInfoFrame:WaitForChild('Player'):WaitForChild('NameGradient').Color = RankColors['Top 250']
        end
        if PlayerInfoFrame:WaitForChild('Player').Text ~= 'Shale Wirlika' then
                PlayerInfoFrame:WaitForChild('Player').Text = 'Shale Wirlika'
        end
        if GuildFrame.Guild.Text ~= 'Seedlings (#359)' then
                GuildFrame.Guild.Text = 'Seedlings (#359)'
        end
        if not GuildFrame.RankIcon.Visible then
                GuildFrame.RankIcon.Visible = true
        end
        if GuildFrame.RankIcon.ImageRectOffset ~= RankIcons['Lieutenant'].ImageRectOffset then
                GuildFrame.RankIcon.ImageRectOffset = RankIcons['Lieutenant'].ImageRectOffset
        end
        if Emblem:FindFirstChild('EmblemA').ImageRectOffset ~= GuildEmblems['38'] then
                Emblem:FindFirstChild('EmblemA').ImageRectOffset = GuildEmblems['38']
        end
        if Emblem:FindFirstChild('EmblemB').ImageRectOffset ~= GuildEmblems['38'] then
                Emblem:FindFirstChild('EmblemB').ImageRectOffset = GuildEmblems['38']
        end
        if Emblem.BackgroundColor3 ~= Color3.fromHex('#ffffff') then
                Emblem.BackgroundColor3 = Color3.fromHex('#ffffff')
        end
        if Emblem:FindFirstChild('EmblemA').ImageColor3 ~= Color3.fromHex('#00ff66') then
                Emblem:FindFirstChild('EmblemA').ImageColor3 = Color3.fromHex('#00ff66')
        end
        if Emblem:FindFirstChild('EmblemB').ImageColor3 ~= Color3.fromHex('#00ff66') then
                Emblem:FindFirstChild('EmblemB').ImageColor3 = Color3.fromHex('#00ff66')
        end
        if ServerTitle.ServerHelp.Position ~= UDim2.new(1, -2, 0, 2) then
                ServerTitle.ServerHelp.Position = UDim2.new(1, -2, 0, 2)
        end
end)

game:GetService('UserInputService').InputBegan:Connect(a)
