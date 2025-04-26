local Weapon = script.Parent
local AnimationsFolder = Weapon:WaitForChild("Animations")
local SoundFXFolder = Weapon:WaitForChild("SoundFX")
local MuzzleFlash = Weapon:WaitForChild("MuzzleFlash")
local RS = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Player = game.Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Character = Player.Character or Player.CharacterAdded:Wait()
local hum = Character:WaitForChild("Humanoid")
local TweenService = game:GetService("TweenService")
local EquipAnimation = hum:LoadAnimation(AnimationsFolder:WaitForChild("Equip"))
local UnequipAnimation = hum:LoadAnimation(AnimationsFolder:WaitForChild("Unequip"))
local IdleAnimation = hum:LoadAnimation(AnimationsFolder:WaitForChild("Idle"))
local AimAnimation = hum:LoadAnimation(AnimationsFolder:WaitForChild("Aim"))
local FireAnimation = hum:LoadAnimation(AnimationsFolder:WaitForChild("Fire"))
local ReloadAnimation = hum:LoadAnimation(AnimationsFolder:WaitForChild("Reload"))
local AimSound = SoundFXFolder:WaitForChild("Aim")
local EquipSound = SoundFXFolder:WaitForChild("Equip")
local NoAmmoSound = SoundFXFolder:WaitForChild("NoAmmo")
local ReloadSound = SoundFXFolder:WaitForChild("Reload")
local FireSound = SoundFXFolder:WaitForChild("Fire")
local BulletShellHitSound = SoundFXFolder:WaitForChild("BulletShellHit")
local Ammo = 20
local MaxAmmo = 20
local CurrentAmmo = 20
local IsAiming = false
local Equipped = false
local CanShoot = true
local CanReload = true
local GameSetting = UserSettings().GameSettings
local HeartbeatConnection
local Last = nil
local CamOffset = Vector3.new(0.5, 0, 0)
local AimingOffset = Vector3.new(2.5, 0, 0)
local PreviousOffset = nil
local PlayerGui = Player:WaitForChild("PlayerGui")
local GunHUD = PlayerGui:WaitForChild("Framework"):WaitForChild("GunHUD")
local GunHUD_Crosshair = GunHUD:WaitForChild("Crosshair")
local GunHUD_Ammo = GunHUD:WaitForChild("AmmoFrame"):WaitForChild("Ammo")
local GunHUD_Mag = GunHUD:WaitForChild("AmmoFrame"):WaitForChild("Mag")
local Tween

local function updateHUD()
	GunHUD_Ammo.Text = tostring(CurrentAmmo)
	GunHUD_Mag.Text = tostring(MaxAmmo)
end

local function smoothCameraOffset(targetOffset)
	if Tween then Tween:Cancel() end
	Tween = TweenService:Create(
		hum,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{CameraOffset = targetOffset}
	)
	Tween:Play()
end

local function startShiftLock()
	if HeartbeatConnection then return end
	HeartbeatConnection = RS.Heartbeat:Connect(function()
		if not Character:FindFirstChild("Head") then
			_G.ForceShiftLock = false
			return
		end
		if Last == _G.ForceShiftLock then return end
		Last = _G.ForceShiftLock
		UIS.MouseBehavior = Last and Enum.MouseBehavior.LockCenter or Enum.MouseBehavior.Default
		GameSetting.RotationType = Last and Enum.RotationType.CameraRelative or Enum.RotationType.MovementRelative
	end)
end

local function stopShiftLock()
	if HeartbeatConnection then
		HeartbeatConnection:Disconnect()
		HeartbeatConnection = nil
	end
	_G.ForceShiftLock = false
	Last = nil
	UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
	GameSetting.RotationType = Enum.RotationType.MovementRelative
end

local function reloadGun()
	if not CanReload or CurrentAmmo == MaxAmmo then return end
	CanReload = false
	ReloadSound:Play()
	ReloadAnimation:Play()
	wait(2)
	CurrentAmmo = MaxAmmo
	ReloadAnimation:Stop()
	CanReload = true
	updateHUD()
end

local function shootGun()
	if not CanShoot or CurrentAmmo <= 0 or not IsAiming then
		NoAmmoSound:Play()
		return
	end
	CanShoot = false
	FireAnimation:Play()
	FireSound:Play()
	local fireSoundClone = FireSound:Clone()
	fireSoundClone:Play()
	local recoilAmountX = math.random(5, 15)
	local recoilAmountY = math.random(5, 15)
	local recoilX = math.rad(math.random(-recoilAmountX, recoilAmountX))
	local recoilY = math.rad(math.random(-recoilAmountY, recoilAmountY))
	local recoilTween = TweenService:Create(Camera, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
		CFrame = Camera.CFrame * CFrame.Angles(recoilX, recoilY, 0)
	})
	recoilTween:Play()
	local fovTween = TweenService:Create(Camera, TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
		FieldOfView = 65
	})
	fovTween:Play()
	fovTween.Completed:Connect(function()
		local returnFovTween = TweenService:Create(Camera, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			FieldOfView = math.random(71, 80)
		})
		returnFovTween:Play()
	end)
	for i = 1, 6 do
		local effect = MuzzleFlash:FindFirstChild("Effect" .. i)
		if effect then
			effect.Enabled = true
			wait(0.05)
			effect.Enabled = false
		end
	end
	wait(0.001)
	BulletShellHitSound:Play()
	CurrentAmmo -= 1
	updateHUD()
	wait(0.001)
	CanShoot = true
end

local function startAiming()
	if IsAiming then return end
	IsAiming = true
	AimSound:Play()
	AimAnimation:Play()
	_G.ForceShiftLock = true
	PreviousOffset = Camera.CFrame.Position
	smoothCameraOffset(AimingOffset)
	startShiftLock()
	local aimTween = TweenService:Create(GunHUD_Crosshair, TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
		Transparency = 0
	})
	aimTween:Play()
end

local function stopAiming()
	if not IsAiming then return end
	IsAiming = false
	AimAnimation:Stop()
	_G.ForceShiftLock = false
	stopShiftLock()
	if PreviousOffset then
		smoothCameraOffset(CamOffset)
	end
	local stopTween = TweenService:Create(GunHUD_Crosshair, TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
		Transparency = 1
	})
	stopTween:Play()
end

local function stopAll()
	EquipAnimation:Stop()
	UnequipAnimation:Stop()
	IdleAnimation:Stop()
	AimAnimation:Stop()
	FireAnimation:Stop()
	ReloadAnimation:Stop()
	FireSound:Stop()
	ReloadSound:Stop()
	NoAmmoSound:Stop()
	for _, effect in pairs(MuzzleFlash:GetChildren()) do
		if effect:IsA("ParticleEmitter") then
			effect.Enabled = false
		end
	end
end

local function resetCameraEffects()
	_G.ForceShiftLock = false
	smoothCameraOffset(CamOffset)
	stopShiftLock()
	UIS.MouseBehavior = Enum.MouseBehavior.Default
	Player.CameraMaxZoomDistance = 20
	Player.CameraMinZoomDistance = 0.5
end

Weapon.Equipped:Connect(function()
	Equipped = true
	EquipSound:Play()
	EquipAnimation:Play()
	Player.CameraMaxZoomDistance = 5
	Player.CameraMinZoomDistance = 5
	IdleAnimation:Play()
	UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
	GunHUD.Visible = true
	updateHUD()
	UIS.MouseIconEnabled = false
end)

Weapon.Unequipped:Connect(function()
	Equipped = false
	stopAll()
	UnequipAnimation:Play()
	resetCameraEffects()
	GunHUD.Visible = false
	UIS.MouseIconEnabled = true
end)

UIS.InputBegan:Connect(function(input)
	if not Equipped then return end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		startAiming()
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		shootGun()
	end
	if input.KeyCode == Enum.KeyCode.R then
		reloadGun()
	end
end)

UIS.InputEnded:Connect(function(input)
	if not Equipped then return end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		stopAiming()
	end
end)
