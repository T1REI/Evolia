local function signal()
    local listeners = {}
    return {
        Connect = function(_, fn)
            local c = { Connected = true }
            function c:Disconnect() self.Connected = false end
            c.fn = fn
            table.insert(listeners, c)
            return c
        end,
        Fire = function(_, ...)
            for _, c in table.clone(listeners) do if c.Connected then c.fn(...) end end
        end,
        Count = function()
            local n=0
            for _,c in listeners do if c.Connected then n+=1 end end
            return n
        end,
    }
end
local vec = {}
vec.__index = function(v, key)
    if key=='R' then return v.X end
    if key=='G' then return v.Y end
    if key=='B' then return v.Z end
    if key == 'Magnitude' then return math.sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z) end
    if key == 'Dot' then return function(a,b) return a.X*b.X + a.Y*b.Y + a.Z*b.Z end end
    if key == 'Lerp' then return function(a,b,t) return a+(b-a)*t end end
end
local function vector(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vec) end
vec.__add = function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
vec.__sub = function(a,b) return vector(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
vec.__mul = function(a,b) return vector(a.X*b,a.Y*b,a.Z*b) end
vec.__eq = function(a,b) return a.X==b.X and a.Y==b.Y and a.Z==b.Z end
local Vector2 = {new=function(...) local v=vector(...);v._kind="Vector2";return v end}
Vector2.zero=Vector2.new()
local Vector3 = {new=function(...) local v=vector(...);v._kind="Vector3";return v end}
Vector3.zero=Vector3.new()
local CFrame = {}
local cf = {}
local function rotate(v, angle)
    local c,s=math.cos(angle),math.sin(angle)
    return vector(v.X*c-v.Y*s,v.X*s+v.Y*c,v.Z)
end
cf.__index = function(v,k)
    if k == 'Position' then return vector(v.X,v.Y,v.Z) end
    if k == 'LookVector' then return vector(0,0,-1) end
    if k == 'VectorToObjectSpace' then return function(a,b) return rotate(b,-a.Angle) end end
    if k == 'PointToObjectSpace' then return function(a,b) return rotate(b-a.Position,-a.Angle) end end
end
cf.__mul = function(a,b)
    local p=a.Position+rotate(b.Position,a.Angle)
    local result=CFrame.new(p.X,p.Y,p.Z)
    result.Angle=a.Angle+b.Angle
    return result
end
function CFrame.new(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0,Angle=0,_kind='CFrame'},cf) end
function CFrame.Angles(_,_,angle) local result=CFrame.new();result.Angle=angle;return result end
local Color3 = {new=function(...) local v=vector(...);v._kind='Color3';return v end}
Color3.fromRGB=function(r,g,b) return Color3.new(r/255,g/255,b/255) end
function Color3.fromHex(hex)
    return Color3.fromRGB(tonumber(hex:sub(1,2),16),tonumber(hex:sub(3,4),16),tonumber(hex:sub(5,6),16))
end
function Color3.fromHSV(h,s,v)
    local i=math.floor(h*6);local f=h*6-i;local p=v*(1-s);local q=v*(1-f*s);local t=v*(1-(1-f)*s)
    local rgb={{v,t,p},{q,v,p},{p,v,t},{p,q,v},{t,p,v},{v,p,q}}
    return Color3.new(unpack(rgb[i%6+1]))
end
local vectorIndex=vec.__index
vec.__index=function(v,key)
    if key=='ToHSV' then return function(c)
        local mx,mn=math.max(c.X,c.Y,c.Z),math.min(c.X,c.Y,c.Z)
        local d=mx-mn;local h=0
        if d>0 then
            if mx==c.X then h=((c.Y-c.Z)/d)%6 elseif mx==c.Y then h=(c.Z-c.X)/d+2 else h=(c.X-c.Y)/d+4 end
        end
        return h/6,mx==0 and 0 or d/mx,mx
    end end
    if key=='ToHex' then return function(c) return string.format('%02X%02X%02X',math.floor(c.X*255+.5),math.floor(c.Y*255+.5),math.floor(c.Z*255+.5)) end end
    return vectorIndex(v,key)
end
local UDim = {new=function(s,o) return {Scale=s,Offset=o,_kind="UDim"} end}
local UDim2 = {new=function(xs,xo,ys,yo) return {X=UDim.new(xs,xo),Y=UDim.new(ys,yo),_kind='UDim2'} end}
function UDim2.fromOffset(x,y) return UDim2.new(0,x,0,y) end
function UDim2.fromScale(x,y) return UDim2.new(x,0,y,0) end
local NumberSequence = {new=function(t) return t end}
local NumberSequenceKeypoint = {new=function(t,v) return {t,v} end}
local ColorSequence = {new=function(t) return t end}
local ColorSequenceKeypoint = {new=function(t,v) return {t,v} end}
local function warn(...) end
local Random = {new=function() return {NextNumber=function(_,a,b) return (a or 0)+0.37*((b or 1)-(a or 0)) end} end}
local Enum = setmetatable({RenderPriority={Camera={Value=200},Last={Value=2000}}},{__index=function(t,k)
    local group=setmetatable({}, {__index=function(g,n)
        if k=='KeyCode' and n~='Unknown' and n~='RightShift' and n~='LeftAlt' and n~='T' and n~='F4' and n~='Escape' then
            error('Invalid KeyCode '..n)
        end
        rawset(g,n,{_kind='EnumItem',EnumType=g,Name=n})
        return g[n]
    end})
    rawset(t,k,group);return group
end})
local eventNames = {Destroying=true,ChildAdded=true,InputBegan=true,InputChanged=true,InputEnded=true,
    WindowFocusReleased=true,Activated=true,MouseEnter=true,MouseLeave=true,RenderStepped=true,FocusLost=true}
local methods = {}
local inst = {}
local view = vector(1280,720)
local coreInset = vector(18,36)
inst.__index = function(o,k)
    if methods[k] then return methods[k] end
    if eventNames[k] then
        if not o._events[k] then o._events[k]=signal() end
        return o._events[k]
    end
    if k == 'AbsoluteRotation' then return (o.Rotation or 0)+(o.Parent and o.Parent.AbsoluteRotation or 0) end
    if k == 'AbsoluteSize' then
        if o.ClassName=='PlayerGui' then return view end
        if o.ClassName=='ScreenGui' then
            return o.ScreenInsets==Enum.ScreenInsets.None and view or view-coreInset
        end
        local p=o.Parent and o.Parent.AbsoluteSize or vector()
        local s=o.Size or UDim2.fromOffset(0,0)
        return vector(p.X*s.X.Scale+s.X.Offset,p.Y*s.Y.Scale+s.Y.Offset)
    end
    if k == 'AbsolutePosition' then
        if o.ClassName=='PlayerGui' then return vector() end
        if o.ClassName=='ScreenGui' then
            return o.ScreenInsets==Enum.ScreenInsets.None and coreInset*-1 or vector()
        end
        local parent=o.Parent
        local p=parent and parent.AbsolutePosition or vector()
        local size=parent and parent.AbsoluteSize or vector()
        local s=o.Position or UDim2.fromOffset(0,0)
        local a=o.AnchorPoint or vector()
        return p+vector(size.X*s.X.Scale+s.X.Offset-o.AbsoluteSize.X*a.X,size.Y*s.Y.Scale+s.Y.Offset-o.AbsoluteSize.Y*a.Y)
    end
    return o._props[k]
end
inst.__newindex = function(o,k,v)
    local old=o._props[k]
    if k=='Parent' and old then
        local index=table.find(old._children,o)
        if index then table.remove(old._children,index) end
    end
    o._props[k]=v
    if k=='Parent' and v then table.insert(v._children,o);v.ChildAdded:Fire(o) end
    if old~=v and o._signals[k] then o._signals[k]:Fire() end
end
function methods:GetPropertyChangedSignal(k)
    if not self._signals[k] then self._signals[k]=signal() end
    return self._signals[k]
end
function methods:GetChildren() return table.clone(self._children) end
local guiClasses={Frame=true,TextLabel=true,TextButton=true,ImageLabel=true,ImageButton=true,ScrollingFrame=true,TextBox=true,CanvasGroup=true}
function methods:IsA(k) return self.ClassName==k or (k=='GuiObject' and guiClasses[self.ClassName]) or k=='Instance' end
function methods:FindFirstChildOfClass(k)
    for _,c in self._children do if c:IsA(k) then return c end end
end
function methods:IsDescendantOf(ancestor)
    local p=self.Parent
    while p do if p==ancestor then return true end;p=p.Parent end
    return false
end
function methods:SetAttribute(k,v) self._attributes[k]=v end
function methods:GetAttribute(k) return self._attributes[k] end
function methods:FindFirstChild(k)
    for _,c in self._children do if c.Name==k then return c end end
end
function methods:WaitForChild(k) return (assert(self:FindFirstChild(k),k)) end
function methods:Destroy()
    self.Destroying:Fire()
    for _,c in self:GetChildren() do c:Destroy() end
    self.Parent=nil
    self._destroyed=true
end
local Instance = {}
function Instance.new(class)
    return setmetatable({_kind="Instance",_props={ClassName=class,Name=class,Enabled=true,Visible=true,ZIndex=1,Rotation=0,ClipsDescendants=false,GroupTransparency=0},
        _children={},_events={},_signals={},_attributes={}},inst)
end
local workspace=Instance.new('Workspace')
local playerGui=Instance.new('PlayerGui')
local player=Instance.new('Player')
playerGui.Parent=player
local lighting=Instance.new('Lighting')
local input=Instance.new('UserInputService')
function input:GetFocusedTextBox() return self.FocusedTextBox end
local frames={}
local run=Instance.new('RunService')
function run:IsClient() return true end
function run:BindToRenderStep(name,_,fn) frames[name]=fn end
function run:UnbindFromRenderStep(name) frames[name]=nil end
local guiService=Instance.new('GuiService')
function guiService:GetGuiInset() return coreInset,vector() end
local counter=0
local services={Players={LocalPlayer=player},Lighting=lighting,RunService=run,
    UserInputService=input,GuiService=guiService,HttpService={GenerateGUID=function() counter+=1;return tostring(counter) end}}
local game=Instance.new('DataModel')
function game:GetService(name) return assert(services[name],name) end
workspace.Parent=game
lighting.Parent=game
player.Parent=game
local function makeCamera()
    local camera=Instance.new('Camera')
    camera.CFrame=CFrame.new()
    camera.ViewportSize=view
    camera.FieldOfView=70
    camera.NearPlaneZ=-0.5
    function camera:ViewportPointToRay(x,y)
        local s=math.tan(math.rad(self.FieldOfView)/2)/(self.ViewportSize.Y/2)
        local d=vector((x-self.ViewportSize.X/2)*s,(self.ViewportSize.Y/2-y)*s,-1)
        return {Origin=self.CFrame.Position,Direction=d*(1/d.Magnitude)}
    end
    function camera:ScreenPointToRay(x,y)
        return self:ViewportPointToRay(x+coreInset.X,y+coreInset.Y)
    end
    return camera
end
workspace.CurrentCamera=makeCamera()
local initial=Instance.new('DepthOfFieldEffect');initial.Parent=lighting
local initiallyOff=Instance.new('DepthOfFieldEffect');initiallyOff.Enabled=false;initiallyOff.Parent=lighting

local nativeTypeof=typeof
local function typeof(value) return type(value)=='table' and value._kind or nativeTypeof(value) end
local function stepFrames(n,dt)
    for _=1,n or 1 do
        for _,fn in table.clone(frames) do fn(dt or 1/60) end
        run.RenderStepped:Fire(dt or 1/60)
    end
end
local function count(t) local n=0;for _ in t do n+=1 end;return n end
local function child(p,n) return assert(p:FindFirstChild(n),n) end
local function makeGui()
    local gui=Instance.new('ScreenGui');gui.Parent=playerGui
    return gui
end
local function makeTarget(gui,x,y,w,h,class)
    local target=Instance.new(class or 'Frame')
    target.Position=UDim2.fromOffset(x or 100,y or 100)
    target.Size=UDim2.fromOffset(w or 540,h or 340)
    target.BackgroundTransparency=1
    target.Parent=gui
    return target
end
