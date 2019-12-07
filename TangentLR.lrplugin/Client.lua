--[[----------------------------------------------------------------------------

Client.lua

Receives and processes commands from MIDI2LR
Sends parameters to MIDI2LR

This file is part of MIDI2LR. Copyright 2015 by Rory Jaffe.

MIDI2LR is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later version.

MIDI2LR is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
MIDI2LR.  If not, see <http://www.gnu.org/licenses/>.
------------------------------------------------------------------------------]]
--[[-----------debug section, enable by adding - to beginning this line
local LrMobdebug = import 'LrMobdebug'
LrMobdebug.start()
--]]-----------end debug section
local Database = require 'Database'
local LrTasks = import 'LrTasks'
-- Main task
LrTasks.startAsyncTask(
  function()
    --[[-----------debug section, enable by adding - to beginning this line
    LrMobdebug.on()
    --]]-----------end debug section
-------------preferences
    local Preferences     = require 'Preferences'
    Preferences.Load()
-------------end preferences section


    local LrFunctionContext   = import 'LrFunctionContext'
    local LrPathUtils         = import 'LrPathUtils'

    do --save localized file for app
      local LrFileUtils    = import 'LrFileUtils'
      local LrLocalization = import 'LrLocalization'
      local Info           = require 'Info'
      local versionmismatch = false

      if ProgramPreferences.DataStructure == nil then
        versionmismatch = true
      else
        for k,v in pairs(Info.VERSION) do
          versionmismatch = versionmismatch or ProgramPreferences.DataStructure.version[k] ~= v
        end
      end

      if
      versionmismatch or
      LrFileUtils.exists(Database.AppTrans) ~= 'file' or
      ProgramPreferences.DataStructure.language ~= LrLocalization.currentLanguage()
      then
        ProgramPreferences.DataStructure = {version={},language = LrLocalization.currentLanguage()}
        Database.WriteAppTrans(ProgramPreferences.DataStructure.language)
        for k,v in pairs(Info.VERSION) do
          ProgramPreferences.DataStructure.version[k] = v
        end
        Preferences.Save() --ensure that new version/language info saved
      end
    end --save localized file for app

    --delay loading most modules until after data structure refreshed
    local ActionSeries    = require 'ActionSeries'
    local CU              = require 'ClientUtilities'
    local DebugInfo       = require 'DebugInfo'
    local Info            = require 'Info'
    local Keys            = require 'Keys'
    local KS              = require 'KeyShortcuts'
    local Keywords        = require 'Keywords'
    local Limits          = require 'Limits'
    local LocalPresets    = require 'LocalPresets'
    local Profiles        = require 'Profiles'
    local Ut              = require 'Utilities'
    local Virtual         = require 'Virtual'
    local LrApplication       = import 'LrApplication'
    local LrApplicationView   = import 'LrApplicationView'
    local LrDevelopController = import 'LrDevelopController'
    local LrDialogs           = import 'LrDialogs'
    local LrSelection         = import 'LrSelection'
    local LrUndo              = import 'LrUndo'
    --global variables
    MIDI2LR = {PARAM_OBSERVER = {}, SERVER = {}, CLIENT = {}, RUNNING = true} --non-local but in MIDI2LR namespace
    --local variables
    local LastParam           = ''
    local UpdateParamPickup, UpdateParamNoPickup, UpdateParam
    local sendIsConnected = false --tell whether send socket is up or not
    --local constants--may edit these to change program behaviors
    local BUTTON_ON        = 0.40 -- sending 1.0, but use > BUTTON_ON because of note keypressess not hitting 100%
    local PICKUP_THRESHOLD = 0.03 -- roughly equivalent to 4/127
    local RECEIVE_PORT     = 54778
    local SEND_PORT        = 54779

    local LrLogger = import 'LrLogger'
    local logger = LrLogger( 'tangent2midi2lr' )
    --[[-- Debug logging master switch:
    logger:enable("logfile")
    --]]--

    local ACTIONS = {
      AdjustmentBrush                        = CU.fToggleTool('localized'),
      AppInfoClear                           = function() Info.AppInfo = {}; end,
      AppInfoDone                            = DebugInfo.write,
      AutoLateralCA                          = CU.fToggle01('AutoLateralCA'),
      BrushFeatherLarger                     = CU.fSimulateKeys(KS.KeyCode.FeatherIncreaseKey,true,{dust=true, localized=true, gradient=true, circularGradient=true}),
      BrushFeatherSmaller                    = CU.fSimulateKeys(KS.KeyCode.FeatherDecreaseKey,true,{dust=true, localized=true, gradient=true, circularGradient=true}),
      BrushSizeLarger                        = CU.fSimulateKeys(KS.KeyCode.BrushIncreaseKey,true,{dust=true, localized=true, gradient=true, circularGradient=true}),
      BrushSizeSmaller                       = CU.fSimulateKeys(KS.KeyCode.BrushDecreaseKey,true,{dust=true, localized=true, gradient=true, circularGradient=true}),
      ConvertToGrayscale                     = CU.fToggleTFasync('ConvertToGrayscale'),
      CloseApp                               = function() MIDI2LR.SERVER:send('TerminateApplication 1\n') end,
      ColorLabelNone                         = function() LrSelection.setColorLabel("none") end,
      CropConstrainToWarp                    = CU.fToggle01('CropConstrainToWarp'),
      CropOverlay                            = CU.fToggleTool('crop'),
      CycleMaskOverlayColor                  = CU.fSimulateKeys(KS.KeyCode.CycleAdjustmentBrushOverlayKey,true),
      DecreaseRating                         = LrSelection.decreaseRating,
      DecrementLastDevelopParameter          = function() CU.execFOM(LrDevelopController.decrement,LastParam) end,
      EnableCalibration                      = CU.fToggleTFasync('EnableCalibration'),
      EnableCircularGradientBasedCorrections = CU.fToggleTFasync('EnableCircularGradientBasedCorrections'),
      EnableColorAdjustments                 = CU.fToggleTFasync('EnableColorAdjustments'),
      EnableDetail                           = CU.fToggleTFasync('EnableDetail'),
      EnableEffects                          = CU.fToggleTFasync('EnableEffects'),
      EnableGradientBasedCorrections         = CU.fToggleTFasync('EnableGradientBasedCorrections'),
      EnableGrayscaleMix                     = CU.fToggleTFasync('EnableGrayscaleMix'),
      EnableLensCorrections                  = CU.fToggleTFasync('EnableLensCorrections'),
      EnablePaintBasedCorrections            = CU.fToggleTFasync('EnablePaintBasedCorrections'),
      EnableRedEye                           = CU.fToggleTFasync('EnableRedEye'),
      EnableRetouch                          = CU.fToggleTFasync('EnableRetouch'),
      EnableSplitToning                      = CU.fToggleTFasync('EnableSplitToning'),
      EnableTransform                        = CU.fToggleTFasync('EnableTransform'),
      Filter_1                               = CU.fApplyFilter(1),
      Filter_2                               = CU.fApplyFilter(2),
      Filter_3                               = CU.fApplyFilter(3),
      Filter_4                               = CU.fApplyFilter(4),
      Filter_5                               = CU.fApplyFilter(5),
      Filter_6                               = CU.fApplyFilter(6),
      Filter_7                               = CU.fApplyFilter(7),
      Filter_8                               = CU.fApplyFilter(8),
      Filter_9                               = CU.fApplyFilter(9),
      Filter_10                              = CU.fApplyFilter(10),
      Filter_11                              = CU.fApplyFilter(11),
      Filter_12                              = CU.fApplyFilter(12),
      FullRefresh                            = CU.FullRefresh,
      GetPluginInfo                          = DebugInfo.sendLog, -- not in db: internal use only
      IncreaseRating                         = LrSelection.increaseRating,
      IncrementLastDevelopParameter          = function() CU.execFOM(LrDevelopController.increment,LastParam) end,
      Key1  = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(1) .. '\n') end,
      Key2  = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(2) .. '\n') end,
      Key3  = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(3) .. '\n') end,
      Key4  = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(4) .. '\n') end,
      Key5  = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(5) .. '\n') end,
      Key6  = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(6) .. '\n') end,
      Key7  = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(7) .. '\n') end,
      Key8  = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(8) .. '\n') end,
      Key9  = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(9) .. '\n') end,
      Key10 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(10) .. '\n') end,
      Key11 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(11) .. '\n') end,
      Key12 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(12) .. '\n') end,
      Key13 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(13) .. '\n') end,
      Key14 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(14) .. '\n') end,
      Key15 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(15) .. '\n') end,
      Key16 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(16) .. '\n') end,
      Key17 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(17) .. '\n') end,
      Key18 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(18) .. '\n') end,
      Key19 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(19) .. '\n') end,
      Key20 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(20) .. '\n') end,
      Key21 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(21) .. '\n') end,
      Key22 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(22) .. '\n') end,
      Key23 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(23) .. '\n') end,
      Key24 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(24) .. '\n') end,
      Key25 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(25) .. '\n') end,
      Key26 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(26) .. '\n') end,
      Key27 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(27) .. '\n') end,
      Key28 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(28) .. '\n') end,
      Key29 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(29) .. '\n') end,
      Key30 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(30) .. '\n') end,
      Key31 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(31) .. '\n') end,
      Key32 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(32) .. '\n') end,
      Key33 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(33) .. '\n') end,
      Key34 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(34) .. '\n') end,
      Key35 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(35) .. '\n') end,
      Key36 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(36) .. '\n') end,
      Key37 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(37) .. '\n') end,
      Key38 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(38) .. '\n') end,
      Key39 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(39) .. '\n') end,
      Key40 = function() MIDI2LR.SERVER:send('SendKey ' .. Keys.GetKey(40) .. '\n') end,
      Keyword1  = function() Keywords.ApplyKeyword(ProgramPreferences.Keywords[1]) end,
      Keyword2  = function() Keywords.ApplyKeyword(ProgramPreferences.Keywords[2]) end,
      Keyword3  = function() Keywords.ApplyKeyword(ProgramPreferences.Keywords[3]) end,
      Keyword4  = function() Keywords.ApplyKeyword(ProgramPreferences.Keywords[4]) end,
      Keyword5  = function() Keywords.ApplyKeyword(ProgramPreferences.Keywords[5]) end,
      Keyword6  = function() Keywords.ApplyKeyword(ProgramPreferences.Keywords[6]) end,
      Keyword7  = function() Keywords.ApplyKeyword(ProgramPreferences.Keywords[7]) end,
      Keyword8  = function() Keywords.ApplyKeyword(ProgramPreferences.Keywords[8]) end,
      Keyword9  = function() Keywords.ApplyKeyword(ProgramPreferences.Keywords[9]) end,
      Keyword10 = function() Keywords.ApplyKeyword(ProgramPreferences.Keywords[10]) end,
      Keyword11 = function() Keywords.ApplyKeyword(ProgramPreferences.Keywords[11]) end,
      Keyword12 = function() Keywords.ApplyKeyword(ProgramPreferences.Keywords[12]) end,
      Keyword13 = function() Keywords.ApplyKeyword(ProgramPreferences.Keywords[13]) end,
      Keyword14 = function() Keywords.ApplyKeyword(ProgramPreferences.Keywords[14]) end,
      Keyword15 = function() Keywords.ApplyKeyword(ProgramPreferences.Keywords[15]) end,
      Keyword16 = function() Keywords.ApplyKeyword(ProgramPreferences.Keywords[16]) end,
      LensProfileEnable               = CU.fToggle01Async('LensProfileEnable'),
      LocalPreset1  = function() LocalPresets.ApplyLocalPreset(ProgramPreferences.LocalPresets[1]) end,
      LocalPreset2  = function() LocalPresets.ApplyLocalPreset(ProgramPreferences.LocalPresets[2]) end,
      LocalPreset3  = function() LocalPresets.ApplyLocalPreset(ProgramPreferences.LocalPresets[3]) end,
      LocalPreset4  = function() LocalPresets.ApplyLocalPreset(ProgramPreferences.LocalPresets[4]) end,
      LocalPreset5  = function() LocalPresets.ApplyLocalPreset(ProgramPreferences.LocalPresets[5]) end,
      LocalPreset6  = function() LocalPresets.ApplyLocalPreset(ProgramPreferences.LocalPresets[6]) end,
      LocalPreset7  = function() LocalPresets.ApplyLocalPreset(ProgramPreferences.LocalPresets[7]) end,
      LocalPreset8  = function() LocalPresets.ApplyLocalPreset(ProgramPreferences.LocalPresets[8]) end,
      LocalPreset9  = function() LocalPresets.ApplyLocalPreset(ProgramPreferences.LocalPresets[9]) end,
      LocalPreset10 = function() LocalPresets.ApplyLocalPreset(ProgramPreferences.LocalPresets[10]) end,
      LocalPreset11 = function() LocalPresets.ApplyLocalPreset(ProgramPreferences.LocalPresets[11]) end,
      LocalPreset12 = function() LocalPresets.ApplyLocalPreset(ProgramPreferences.LocalPresets[12]) end,
      LocalPreset13 = function() LocalPresets.ApplyLocalPreset(ProgramPreferences.LocalPresets[13]) end,
      LocalPreset14 = function() LocalPresets.ApplyLocalPreset(ProgramPreferences.LocalPresets[14]) end,
      LocalPreset15 = function() LocalPresets.ApplyLocalPreset(ProgramPreferences.LocalPresets[15]) end,
      LocalPreset16 = function() LocalPresets.ApplyLocalPreset(ProgramPreferences.LocalPresets[16]) end,
      Loupe                           = CU.fToggleTool('loupe'),
      LRCopy                          = CU.fSimulateKeys(KS.KeyCode.CopyKey,true),
      LRPaste                         = CU.fSimulateKeys(KS.KeyCode.PasteKey,true),
      Next                            = LrSelection.nextPhoto,
      Pause                           = function() LrTasks.sleep( 0.02 ) end,
      Pick                            = LrSelection.flagAsPick,
      PointCurveLinear                = CU.UpdatePointCurve({ToneCurveName="Linear",ToneCurveName2012="Linear",ToneCurvePV2012={0,0,255,255,}}),
      PointCurveMediumContrast        = CU.UpdatePointCurve({ToneCurveName="Medium Contrast",ToneCurveName2012="Medium Contrast",
          ToneCurvePV2012={0,0,32,22,64,56,128,128,192,196,255,255,}}),
      PointCurveStrongContrast        = CU.UpdatePointCurve({ToneCurveName="Strong Contrast",ToneCurveName2012="Strong Contrast",
          ToneCurvePV2012={0,0,32,16,64,50,128,128,192,202,255,255,}}),
      PostCropVignetteStyle           = CU.fToggle1ModN('PostCropVignetteStyle', 3),
      PostCropVignetteStyleColorPriority     = CU.wrapFOM(LrDevelopController.setValue,'PostCropVignetteStyle',2),
      PostCropVignetteStyleHighlightPriority = CU.wrapFOM(LrDevelopController.setValue,'PostCropVignetteStyle',1),
      PostCropVignetteStylePaintOverlay      = CU.wrapFOM(LrDevelopController.setValue,'PostCropVignetteStyle',3),
      Preset_1                        = CU.fApplyPreset(1),
      Preset_2                        = CU.fApplyPreset(2),
      Preset_3                        = CU.fApplyPreset(3),
      Preset_4                        = CU.fApplyPreset(4),
      Preset_5                        = CU.fApplyPreset(5),
      Preset_6                        = CU.fApplyPreset(6),
      Preset_7                        = CU.fApplyPreset(7),
      Preset_8                        = CU.fApplyPreset(8),
      Preset_9                        = CU.fApplyPreset(9),
      Preset_10                       = CU.fApplyPreset(10),
      Preset_11                       = CU.fApplyPreset(11),
      Preset_12                       = CU.fApplyPreset(12),
      Preset_13                       = CU.fApplyPreset(13),
      Preset_14                       = CU.fApplyPreset(14),
      Preset_15                       = CU.fApplyPreset(15),
      Preset_16                       = CU.fApplyPreset(16),
      Preset_17                       = CU.fApplyPreset(17),
      Preset_18                       = CU.fApplyPreset(18),
      Preset_19                       = CU.fApplyPreset(19),
      Preset_20                       = CU.fApplyPreset(20),
      Preset_21                       = CU.fApplyPreset(21),
      Preset_22                       = CU.fApplyPreset(22),
      Preset_23                       = CU.fApplyPreset(23),
      Preset_24                       = CU.fApplyPreset(24),
      Preset_25                       = CU.fApplyPreset(25),
      Preset_26                       = CU.fApplyPreset(26),
      Preset_27                       = CU.fApplyPreset(27),
      Preset_28                       = CU.fApplyPreset(28),
      Preset_29                       = CU.fApplyPreset(29),
      Preset_30                       = CU.fApplyPreset(30),
      Preset_31                       = CU.fApplyPreset(31),
      Preset_32                       = CU.fApplyPreset(32),
      Preset_33                       = CU.fApplyPreset(33),
      Preset_34                       = CU.fApplyPreset(34),
      Preset_35                       = CU.fApplyPreset(35),
      Preset_36                       = CU.fApplyPreset(36),
      Preset_37                       = CU.fApplyPreset(37),
      Preset_38                       = CU.fApplyPreset(38),
      Preset_39                       = CU.fApplyPreset(39),
      Preset_40                       = CU.fApplyPreset(40),
      Preset_41                       = CU.fApplyPreset(41),
      Preset_42                       = CU.fApplyPreset(42),
      Preset_43                       = CU.fApplyPreset(43),
      Preset_44                       = CU.fApplyPreset(44),
      Preset_45                       = CU.fApplyPreset(45),
      Preset_46                       = CU.fApplyPreset(46),
      Preset_47                       = CU.fApplyPreset(47),
      Preset_48                       = CU.fApplyPreset(48),
      Preset_49                       = CU.fApplyPreset(49),
      Preset_50                       = CU.fApplyPreset(50),
      Preset_51                       = CU.fApplyPreset(51),
      Preset_52                       = CU.fApplyPreset(52),
      Preset_53                       = CU.fApplyPreset(53),
      Preset_54                       = CU.fApplyPreset(54),
      Preset_55                       = CU.fApplyPreset(55),
      Preset_56                       = CU.fApplyPreset(56),
      Preset_57                       = CU.fApplyPreset(57),
      Preset_58                       = CU.fApplyPreset(58),
      Preset_59                       = CU.fApplyPreset(59),
      Preset_60                       = CU.fApplyPreset(60),
      Preset_61                       = CU.fApplyPreset(61),
      Preset_62                       = CU.fApplyPreset(62),
      Preset_63                       = CU.fApplyPreset(63),
      Preset_64                       = CU.fApplyPreset(64),
      Preset_65                       = CU.fApplyPreset(65),
      Preset_66                       = CU.fApplyPreset(66),
      Preset_67                       = CU.fApplyPreset(67),
      Preset_68                       = CU.fApplyPreset(68),
      Preset_69                       = CU.fApplyPreset(69),
      Preset_70                       = CU.fApplyPreset(70),
      Preset_71                       = CU.fApplyPreset(71),
      Preset_72                       = CU.fApplyPreset(72),
      Preset_73                       = CU.fApplyPreset(73),
      Preset_74                       = CU.fApplyPreset(74),
      Preset_75                       = CU.fApplyPreset(75),
      Preset_76                       = CU.fApplyPreset(76),
      Preset_77                       = CU.fApplyPreset(77),
      Preset_78                       = CU.fApplyPreset(78),
      Preset_79                       = CU.fApplyPreset(79),
      Preset_80                       = CU.fApplyPreset(80),
      Prev                            = LrSelection.previousPhoto,
      Profile_Adobe_Standard          = CU.UpdateCameraProfile('Adobe Standard'),
      Profile_Camera_Bold             = CU.UpdateCameraProfile('Camera Bold'),
      Profile_Camera_Clear            = CU.UpdateCameraProfile('Camera Clear'),
      Profile_Camera_Color            = CU.UpdateCameraProfile('Camera Color'),
      Profile_Camera_Darker_Skin_Tone = CU.UpdateCameraProfile('Camera Darker Skin Tone'),
      Profile_Camera_Deep             = CU.UpdateCameraProfile('Camera Deep'),
      Profile_Camera_Faithful         = CU.UpdateCameraProfile('Camera Faithful'),
      Profile_Camera_Flat             = CU.UpdateCameraProfile('Camera Flat'),
      Profile_Camera_Landscape        = CU.UpdateCameraProfile('Camera Landscape'),
      Profile_Camera_Light            = CU.UpdateCameraProfile('Camera Light'),
      Profile_Camera_Lighter_Skin_Tone= CU.UpdateCameraProfile('Camera Lighter Skin Tone'),
      Profile_Camera_LMonochrome      = CU.UpdateCameraProfile('Camera LMonochrome'),
      Profile_Camera_Monochrome       = CU.UpdateCameraProfile('Camera Monochrome'),
      Profile_Camera_Monotone         = CU.UpdateCameraProfile('Camera Monotone'),
      Profile_Camera_Muted            = CU.UpdateCameraProfile('Camera Muted'),
      Profile_Camera_Natural          = CU.UpdateCameraProfile('Camera Natural'),
      Profile_Camera_Neutral          = CU.UpdateCameraProfile('Camera Neutral'),
      Profile_Camera_Portrait         = CU.UpdateCameraProfile('Camera Portrait'),
      Profile_Camera_Positive_Film    = CU.UpdateCameraProfile('Camera Positive Film'),
      Profile_Camera_Scenery          = CU.UpdateCameraProfile('Camera Scenery'),
      Profile_Camera_Standard         = CU.UpdateCameraProfile('Camera Standard'),
      Profile_Camera_Vibrant          = CU.UpdateCameraProfile('Camera Vibrant'),
      Profile_Camera_Vivid            = CU.UpdateCameraProfile('Camera Vivid'),
      Profile_Camera_Vivid_Blue       = CU.UpdateCameraProfile('Camera Vivid Blue'),
      Profile_Camera_Vivid_Green      = CU.UpdateCameraProfile('Camera Vivid Green'),
      Profile_Camera_Vivid_Red        = CU.UpdateCameraProfile('Camera Vivid Red'),
      profile1                        = function() Profiles.changeProfile('profile1', true) end,
      profile2                        = function() Profiles.changeProfile('profile2', true) end,
      profile3                        = function() Profiles.changeProfile('profile3', true) end,
      profile4                        = function() Profiles.changeProfile('profile4', true) end,
      profile5                        = function() Profiles.changeProfile('profile5', true) end,
      profile6                        = function() Profiles.changeProfile('profile6', true) end,
      profile7                        = function() Profiles.changeProfile('profile7', true) end,
      profile8                        = function() Profiles.changeProfile('profile8', true) end,
      profile9                        = function() Profiles.changeProfile('profile9', true) end,
      profile10                       = function() Profiles.changeProfile('profile10', true) end,
      profile11                       = function() Profiles.changeProfile('profile11', true) end,
      profile12                       = function() Profiles.changeProfile('profile12', true) end,
      profile13                       = function() Profiles.changeProfile('profile13', true) end,
      profile14                       = function() Profiles.changeProfile('profile14', true) end,
      profile15                       = function() Profiles.changeProfile('profile15', true) end,
      profile16                       = function() Profiles.changeProfile('profile16', true) end,
      profile17                       = function() Profiles.changeProfile('profile17', true) end,
      profile18                       = function() Profiles.changeProfile('profile18', true) end,
      profile19                       = function() Profiles.changeProfile('profile19', true) end, 
      profile20                       = function() Profiles.changeProfile('profile20', true) end, 
      profile21                       = function() Profiles.changeProfile('profile21', true) end, 
      profile22                       = function() Profiles.changeProfile('profile22', true) end, 
      profile23                       = function() Profiles.changeProfile('profile23', true) end, 
      profile24                       = function() Profiles.changeProfile('profile24', true) end, 
      profile25                       = function() Profiles.changeProfile('profile25', true) end, 
      profile26                       = function() Profiles.changeProfile('profile26', true) end, 
      PVLatest                        = CU.wrapFOM(LrDevelopController.setProcessVersion, 'Version ' .. Database.LatestPVSupported),
      RedEye                          = CU.fToggleTool('redeye'),
      Redo                            = LrUndo.redo,
      Reject                          = LrSelection.flagAsReject,
      RemoveFlag                      = LrSelection.removeFlag,
      ResetAll                        = CU.wrapFOM(LrDevelopController.resetAllDevelopAdjustments),
      ResetBrushing                   = CU.wrapFOM(LrDevelopController.resetBrushing),
      ResetCircGrad                   = CU.wrapFOM(LrDevelopController.resetCircularGradient),
      ResetCrop                       = CU.wrapFOM(LrDevelopController.resetCrop),
      ResetGradient                   = CU.wrapFOM(LrDevelopController.resetGradient),
      ResetLast                       = function() CU.execFOM(LrDevelopController.resetToDefault,LastParam) end,
      ResetRedeye                     = CU.wrapFOM(LrDevelopController.resetRedeye),
      ResetSpotRem                    = CU.wrapFOM(LrDevelopController.resetSpotRemoval),
      RevealPanelAdjust               = CU.fChangePanel('adjustPanel'),
      RevealPanelCalibrate            = CU.fChangePanel('calibratePanel'),
      RevealPanelDetail               = CU.fChangePanel('detailPanel'),
      RevealPanelEffects              = CU.fChangePanel('effectsPanel'),
      RevealPanelLens                 = CU.fChangePanel('lensCorrectionsPanel'),
      RevealPanelMixer                = CU.fChangePanel('mixerPanel'),
      RevealPanelSplit                = CU.fChangePanel('splitToningPanel'),
      RevealPanelTone                 = CU.fChangePanel('tonePanel'),
      RevealPanelTransform            = CU.fChangePanel('transformPanel'),
      Select1Left                     = function() LrSelection.extendSelection('left',1) end,
      Select1Right                    = function() LrSelection.extendSelection('right',1) end,
      SetRating0                      = function() LrSelection.setRating(0) end,
      SetRating1                      = function() LrSelection.setRating(1) end,
      SetRating2                      = function() LrSelection.setRating(2) end,
      SetRating3                      = function() LrSelection.setRating(3) end,
      SetRating4                      = function() LrSelection.setRating(4) end,
      SetRating5                      = function() LrSelection.setRating(5) end,
      ShoScndVwcompare                = function() LrApplicationView.showSecondaryView('compare') end,
      ShoScndVwgrid                   = function() LrApplicationView.showSecondaryView('grid') end,
      ShoScndVwlive_loupe             = function() LrApplicationView.showSecondaryView('live_loupe') end,
      ShoScndVwlocked_loupe           = function() LrApplicationView.showSecondaryView('locked_loupe') end,
      ShoScndVwloupe                  = function() LrApplicationView.showSecondaryView('loupe') end,
      ShoScndVwslideshow              = function() LrApplicationView.showSecondaryView('slideshow') end,
      ShoScndVwsurvey                 = function() LrApplicationView.showSecondaryView('survey') end,
      ShoVwRefHoriz                   = function() LrApplicationView.showView('develop_reference_horiz') end,
      ShoVwRefVert                    = function() LrApplicationView.showView('develop_reference_vert') end,
      ShoVwcompare                    = function() LrApplicationView.showView('compare') end,
      ShoVwdevelop_before             = function() LrApplicationView.showView('develop_before') end,
      ShoVwdevelop_before_after_horiz = function() LrApplicationView.showView('develop_before_after_horiz') end,
      ShoVwdevelop_before_after_vert  = function() LrApplicationView.showView('develop_before_after_vert') end,
      ShoVwdevelop_loupe              = function() LrApplicationView.showView('develop_loupe') end,
      ShoVwgrid                       = function() LrApplicationView.showView('grid') end,
      ShoVwloupe                      = function() LrApplicationView.showView('loupe') end,
      ShoVwpeople                     = function() LrApplicationView.showView('people') end,
      ShoVwsurvey                     = function() LrApplicationView.showView('survey') end,
      ShowMaskOverlay                 = CU.fSimulateKeys(KS.KeyCode.ShowAdjustmentBrushOverlayKey,true),
      SliderDecrease                  = CU.fSimulateKeys(KS.KeyCode.SliderDecreaseKey,true),
      SliderIncrease                  = CU.fSimulateKeys(KS.KeyCode.SliderIncreaseKey,true),
      SwToMbook                       = CU.fChangeModule('book'),
      SwToMdevelop                    = CU.fChangeModule('develop'),
      SwToMlibrary                    = CU.fChangeModule('library'),
      SwToMmap                        = CU.fChangeModule('map'),
      SwToMprint                      = CU.fChangeModule('print'),
      SwToMslideshow                  = CU.fChangeModule('slideshow'),
      SwToMweb                        = CU.fChangeModule('web'),
      ToggleBlue                      = LrSelection.toggleBlueLabel,
      ToggleGreen                     = LrSelection.toggleGreenLabel,
      TogglePurple                    = LrSelection.togglePurpleLabel,
      ToggleRed                       = LrSelection.toggleRedLabel,
      ToggleScreenTwo                 = LrApplicationView.toggleSecondaryDisplay,
      ToggleYellow                    = LrSelection.toggleYellowLabel,
      ToggleZoomOffOn                 = LrApplicationView.toggleZoom,
      Undo                            = LrUndo.undo,
      UprightAuto                     = CU.wrapFOM(LrDevelopController.setValue,'PerspectiveUpright',1),
      UprightFull                     = CU.wrapFOM(LrDevelopController.setValue,'PerspectiveUpright',2),
      UprightGuided                   = CU.wrapFOM(LrDevelopController.setValue,'PerspectiveUpright',5),
      UprightLevel                    = CU.wrapFOM(LrDevelopController.setValue,'PerspectiveUpright',3),
      UprightOff                      = CU.wrapFOM(LrDevelopController.setValue,'PerspectiveUpright',0),
      UprightVertical                 = CU.wrapFOM(LrDevelopController.setValue,'PerspectiveUpright',4),
      VirtualCopy                     = function() LrApplication.activeCatalog():createVirtualCopies() end,
      WhiteBalanceAs_Shot             = CU.wrapFOM(LrDevelopController.setValue,'WhiteBalance','As Shot'),
      WhiteBalanceCloudy              = CU.wrapFOM(LrDevelopController.setValue,'WhiteBalance','Cloudy'),
      WhiteBalanceDaylight            = CU.wrapFOM(LrDevelopController.setValue,'WhiteBalance','Daylight'),
      WhiteBalanceFlash               = CU.wrapFOM(LrDevelopController.setValue,'WhiteBalance','Flash'),
      WhiteBalanceFluorescent         = CU.wrapFOM(LrDevelopController.setValue,'WhiteBalance','Fluorescent'),
      WhiteBalanceShade               = CU.wrapFOM(LrDevelopController.setValue,'WhiteBalance','Shade'),
      WhiteBalanceTungsten            = CU.wrapFOM(LrDevelopController.setValue,'WhiteBalance','Tungsten'),
      ZoomInLargeStep                 = LrApplicationView.zoomIn,
      ZoomInSmallStep                 = LrApplicationView.zoomInSome,
      ZoomOutLargeStep                = LrApplicationView.zoomOut,
      ZoomOutSmallStep                = LrApplicationView.zoomOutSome,
    }
--need to refer to table after it is initially constructed, so can't put in initial construction statement
    ACTIONS.ActionSeries1 = function() ActionSeries.Run(ProgramPreferences.ActionSeries[1],ACTIONS) end
    ACTIONS.ActionSeries2 = function() ActionSeries.Run(ProgramPreferences.ActionSeries[2],ACTIONS) end
    ACTIONS.ActionSeries3 = function() ActionSeries.Run(ProgramPreferences.ActionSeries[3],ACTIONS) end
    ACTIONS.ActionSeries4 = function() ActionSeries.Run(ProgramPreferences.ActionSeries[4],ACTIONS) end
    ACTIONS.ActionSeries5 = function() ActionSeries.Run(ProgramPreferences.ActionSeries[5],ACTIONS) end
    ACTIONS.ActionSeries6 = function() ActionSeries.Run(ProgramPreferences.ActionSeries[6],ACTIONS) end
    ACTIONS.ActionSeries7 = function() ActionSeries.Run(ProgramPreferences.ActionSeries[7],ACTIONS) end
    ACTIONS.ActionSeries8 = function() ActionSeries.Run(ProgramPreferences.ActionSeries[8],ACTIONS) end
    ACTIONS.ActionSeries9 = function() ActionSeries.Run(ProgramPreferences.ActionSeries[9],ACTIONS) end  
    ACTIONS.ActionSeries10 = function() ActionSeries.Run(ProgramPreferences.ActionSeries[10],ACTIONS) end  
    ACTIONS.ActionSeries11 = function() ActionSeries.Run(ProgramPreferences.ActionSeries[11],ACTIONS) end  
    ACTIONS.ActionSeries12 = function() ActionSeries.Run(ProgramPreferences.ActionSeries[12],ACTIONS) end  
    ACTIONS.ActionSeries13 = function() ActionSeries.Run(ProgramPreferences.ActionSeries[13],ACTIONS) end  
    ACTIONS.ActionSeries14 = function() ActionSeries.Run(ProgramPreferences.ActionSeries[14],ACTIONS) end  
    ACTIONS.ActionSeries15 = function() ActionSeries.Run(ProgramPreferences.ActionSeries[15],ACTIONS) end  
    ACTIONS.ActionSeries16 = function() ActionSeries.Run(ProgramPreferences.ActionSeries[16],ACTIONS) end  

    --some functions not available before 7.4
    if not Ut.LrVersion74orMore then
      local endmsg = ' only available in Lightroom version 7.4 and later.'
      local nocar = function() LrDialogs.message('Quick develop crop aspect ratio'..endmsg) end
      local nowb = function() LrDialogs.message('Quick develop white balance'..endmsg) end
      ACTIONS.AddOrRemoveFromTargetColl    =  function() LrDialogs.message('Add or remove from target collection'..endmsg)  end     
      ACTIONS.AutoTone                     = function() CU.ApplySettings({AutoTone = true}); CU.FullRefresh(); LrDevelopController.revealPanel('adjustPanel'); end
      ACTIONS.CycleLoupeViewInfo           = function() LrDialogs.message('Cycle loupe view style'..endmsg) end
      ACTIONS.EditPhotoshop                = function() LrDialogs.message('Edit in Photoshop action'..endmsg) end
      ACTIONS.EnableToneCurve              = function() LrDialogs.message('Enable Tone Curve action'..endmsg) end
      ACTIONS.GraduatedFilter              = CU.fToggleTool('gradient')
      ACTIONS.GridViewStyle                = function() LrDialogs.message('Cycle grid view style'..endmsg) end
      ACTIONS.NextScreenMode               = function() LrDialogs.message('Cycle screen mode'..endmsg) end
      ACTIONS.openExportDialog             = function() LrDialogs.message('Open export dialog action'..endmsg) end
      ACTIONS.openExportWithPreviousDialog = function() LrDialogs.message('Open export with previous settings action'..endmsg) end
      ACTIONS.QuickDevCropAspect1x1        = nocar
      ACTIONS.QuickDevCropAspect2x3        = nocar
      ACTIONS.QuickDevCropAspect3x4        = nocar
      ACTIONS.QuickDevCropAspect4x5        = nocar
      ACTIONS.QuickDevCropAspect5x7        = nocar
      ACTIONS.QuickDevCropAspect85x11      = nocar
      ACTIONS.QuickDevCropAspect9x16       = nocar
      ACTIONS.QuickDevCropAspectAsShot     = nocar
      ACTIONS.QuickDevCropAspectOriginal   = nocar
      ACTIONS.QuickDevWBAuto               = nowb
      ACTIONS.QuickDevWBCloudy             = nowb
      ACTIONS.QuickDevWBDaylight           = nowb
      ACTIONS.QuickDevWBFlash              = nowb
      ACTIONS.QuickDevWBFluorescent        = nowb
      ACTIONS.QuickDevWBShade              = nowb
      ACTIONS.QuickDevWBTungsten           = nowb
      ACTIONS.RadialFilter                 = CU.fToggleTool('circularGradient')     
      ACTIONS.RotateLeft                   = function() LrDialogs.message('Rotate left action'..endmsg)  end
      ACTIONS.RotateRight                  = function() LrDialogs.message('Rotate right action'..endmsg)  end 
      ACTIONS.SetTreatmentBW               = function() LrDialogs.message('Set treatment B&W'..endmsg) end
      ACTIONS.SetTreatmentColor            = function() LrDialogs.message('Set treatment Color'..endmsg) end
      ACTIONS.ShoFullHidePanels            = function() LrDialogs.message('Show full screen and hide panels action'..endmsg) end
      ACTIONS.ShoFullPreview               = function() LrDialogs.message('Show full screen preview action'..endmsg) end
      ACTIONS.ShowClipping                 = function() LrDialogs.message('Show clipping'..endmsg) end
      ACTIONS.SpotRemoval                  = CU.fToggleTool('dust')
      ACTIONS.ToggleLoupe                  = function() LrDialogs.message('Toggle loupe'..endmsg) end
      ACTIONS.ToggleOverlay                = function() LrDialogs.message('Toggle local adjustments mask overlay'..endmsg) end
      ACTIONS.WhiteBalanceAuto             = CU.wrapFOM(LrDevelopController.setValue,'WhiteBalance','Auto')
    else
      ACTIONS.AddOrRemoveFromTargetColl    = CU.wrapForEachPhoto('addOrRemoveFromTargetCollection')
      ACTIONS.AutoTone                     = function() LrDevelopController.setAutoTone(); LrDevelopController.revealPanel('adjustPanel'); end
      ACTIONS.CycleLoupeViewInfo           = LrApplicationView.cycleLoupeViewInfo
      ACTIONS.EditPhotoshop                = LrDevelopController.editInPhotoshop
      ACTIONS.EnableToneCurve              = CU.fToggleTFasync('EnableToneCurve')
      ACTIONS.GraduatedFilter              = CU.fToggleTool1('gradient')
      ACTIONS.GridViewStyle                = LrApplicationView.gridViewStyle
      ACTIONS.NextScreenMode               = LrApplicationView.nextScreenMode
      ACTIONS.openExportDialog             = CU.wrapForEachPhoto('openExportDialog')
      ACTIONS.openExportWithPreviousDialog = CU.wrapForEachPhoto('openExportWithPreviousDialog')  
      ACTIONS.QuickDevCropAspect1x1        = function() CU.QuickCropAspect({w=1,h=1}) end
      ACTIONS.QuickDevCropAspect2x3        = function() CU.QuickCropAspect({w=2,h=3}) end
      ACTIONS.QuickDevCropAspect3x4        = function() CU.QuickCropAspect({w=3,h=4}) end
      ACTIONS.QuickDevCropAspect4x5        = function() CU.QuickCropAspect({w=4,h=5}) end
      ACTIONS.QuickDevCropAspect5x7        = function() CU.QuickCropAspect({w=5,h=7}) end
      ACTIONS.QuickDevCropAspect85x11      = function() CU.QuickCropAspect({w=8.5,h=11}) end
      ACTIONS.QuickDevCropAspect9x16       = function() CU.QuickCropAspect({w=9,h=16}) end
      ACTIONS.QuickDevCropAspectAsShot     = function() CU.QuickCropAspect('asshot') end
      ACTIONS.QuickDevCropAspectOriginal   = function() CU.QuickCropAspect('original') end
      ACTIONS.QuickDevWBAuto               = CU.wrapForEachPhoto('QuickDevWBAuto')
      ACTIONS.QuickDevWBCloudy             = CU.wrapForEachPhoto('QuickDevWBCloudy')
      ACTIONS.QuickDevWBDaylight           = CU.wrapForEachPhoto('QuickDevWBDaylight')
      ACTIONS.QuickDevWBFlash              = CU.wrapForEachPhoto('QuickDevWBFlash')
      ACTIONS.QuickDevWBFluorescent        = CU.wrapForEachPhoto('QuickDevWBFluorescent')
      ACTIONS.QuickDevWBShade              = CU.wrapForEachPhoto('QuickDevWBShade')
      ACTIONS.QuickDevWBTungsten           = CU.wrapForEachPhoto('QuickDevWBTungsten')
      ACTIONS.RadialFilter                 = CU.fToggleTool1('circularGradient')
      ACTIONS.RotateLeft                   = CU.wrapForEachPhoto('rotateLeft')
      ACTIONS.RotateRight                  = CU.wrapForEachPhoto('rotateRight')
      ACTIONS.SetTreatmentBW               = CU.wrapForEachPhoto('SetTreatmentBW')
      ACTIONS.SetTreatmentColor            = CU.wrapForEachPhoto('SetTreatmentColor')
      ACTIONS.ShoFullHidePanels            = LrApplicationView.fullscreenHidePanels
      ACTIONS.ShoFullPreview               = LrApplicationView.fullscreenPreview
      ACTIONS.ShowClipping                 = CU.wrapFOM(LrDevelopController.showClipping)
      ACTIONS.SpotRemoval                  = CU.fToggleTool1('dust')
      ACTIONS.ToggleLoupe                  = LrApplicationView.toggleLoupe
      ACTIONS.ToggleOverlay                = LrDevelopController.toggleOverlay
      ACTIONS.WhiteBalanceAuto             = LrDevelopController.setAutoWhiteBalance
    end

    if not Ut.LrVersion66orMore then
      ACTIONS.ResetTransforms              = function() LrDialogs.message('Reset transforms action only available in Lightroom version 6.6 and later.') end
    else
      ACTIONS.ResetTransforms              = CU.wrapFOM(LrDevelopController.resetTransforms)
    end

    local SETTINGS = {
      AppInfo            = function(value) Info.AppInfo[#Info.AppInfo+1] = value end,
      ChangedToDirectory = function(value) Profiles.setDirectory(value) end,
      ChangedToFile      = function(value) Profiles.setFile(value) end,
      ChangedToFullPath  = function(value) Profiles.setFullPath(value) end,
      Pickup             = function(enabled)
        if tonumber(enabled) == 1 then -- state machine
          UpdateParam = UpdateParamPickup
        else
          UpdateParam = UpdateParamNoPickup
        end
      end,
      --[[
      For SetRating, if send back sync value to controller, formula is:
        (Rating * 2 + 1)/12
      or,
        0 = 0.083333333, 1 = 0.25, 2 = 4.16667, 3 = 0.583333, 4 = 0.75, 5 = 0.916667
      Make sure to send back sync only when controller not in the range of current value, or we will
      be yanking the controller out of people's hands, as "correct value" is 1/6th of fader's travel.
      Will need to add code to AdjustmentChangeObserver and FullRefresh, and remember last fader
      position received by SetRating.
      --]]
      SetRating          = function(value) 
        local newrating = math.min(5,math.floor(tonumber(value)*6))
        if (newrating ~= LrSelection.getRating()) then
          LrSelection.setRating(newrating)
        end
      end,
    }


    function UpdateParamPickup() --closure
      local paramlastmoved = {}
      local lastfullrefresh = 0
      return function(param, midi_value, silent)
        if LrApplication.activeCatalog():getTargetPhoto() == nil then return end--unable to update param
        local value
        if LrApplicationView.getCurrentModuleName() ~= 'develop' then
          LrApplicationView.switchToModule('develop')
          LrTasks.yield() -- need this to allow module change before value sent
        end
        if Limits.Parameters[param] then
          Limits.ClampValue(param)
        end
        if((math.abs(midi_value - CU.LRValueToMIDIValue(param)) <= PICKUP_THRESHOLD) or (paramlastmoved[param] ~= nil and paramlastmoved[param] + 0.5 > os.clock())) then -- pickup succeeded
          paramlastmoved[param] = os.clock()
          value = CU.MIDIValueToLRValue(param, midi_value)
          if value ~= LrDevelopController.getValue(param) then
            MIDI2LR.PARAM_OBSERVER[param] = value
            LrDevelopController.setValue(param, value)
            LastParam = param
            if ProgramPreferences.ClientShowBezelOnChange and not silent then
              CU.showBezel(param,value)
            elseif type(silent) == 'string' then
              LrDialogs.showBezel(silent)
            end
          end
          if Database.CmdPanel[param] then
            Profiles.changeProfile(Database.CmdPanel[param])
          end
        else --failed pickup
          if ProgramPreferences.ClientShowBezelOnChange then -- failed pickup. do I display bezel?
            value = CU.MIDIValueToLRValue(param, midi_value)
            local actualvalue = LrDevelopController.getValue(param)
            CU.showBezel(param,value,actualvalue)
          end
          if lastfullrefresh + 1 < os.clock() then --try refreshing controller once a second
            CU.FullRefresh()
            lastfullrefresh = os.clock()
          end
        end -- end of if pickup/elseif bezel group
      end -- end of returned function
    end
    UpdateParamPickup = UpdateParamPickup() --complete closure
    --called within LrRecursionGuard for setting
    function UpdateParamNoPickup(param, midi_value, silent)
      if LrApplication.activeCatalog():getTargetPhoto() == nil then return end--unable to update param
      local value
      if LrApplicationView.getCurrentModuleName() ~= 'develop' then
        LrApplicationView.switchToModule('develop')
        LrTasks.yield() -- need this to allow module change before value sent
      end
      --Don't need to clamp limited parameters without pickup, as MIDI controls will still work
      --if value is outside limits range
      value = CU.MIDIValueToLRValue(param, midi_value)
      if value ~= LrDevelopController.getValue(param) then
        MIDI2LR.PARAM_OBSERVER[param] = value
        LrDevelopController.setValue(param, value)
        LastParam = param
        if ProgramPreferences.ClientShowBezelOnChange and not silent then
          CU.showBezel(param,value)
        elseif type(silent) == 'string' then
          LrDialogs.showBezel(silent)
        end
      end
      if Database.CmdPanel[param] then
        Profiles.changeProfile(Database.CmdPanel[param])
      end
    end
    UpdateParam = UpdateParamPickup --initial state


    LrFunctionContext.callWithContext(
      'socket_remote',
      function( context )
        --[[-----------debug section, enable by adding - to beginning this line
        LrMobdebug.on()
        --]]-----------end debug section
        local LrShell             = import 'LrShell'
        local LrSocket            = import 'LrSocket'
        local CurrentObserver
        --call following within guard for reading
        local function AdjustmentChangeObserver()
          local lastrefresh = 0 --will be set to os.clock + increment to rate limit
          return function(observer) -- closure
            if not sendIsConnected then return end -- can't send
            if Limits.LimitsCanBeSet() and lastrefresh < os.clock() then
              -- refresh crop values
              local val = LrDevelopController.getValue("CropBottom")
              MIDI2LR.SERVER:send(string.format('CropBottomRight %g\n', val))
              MIDI2LR.SERVER:send(string.format('CropBottomLeft %g\n', val))
              MIDI2LR.SERVER:send(string.format('CropAll %g\n', val))
              MIDI2LR.SERVER:send(string.format('CropBottom %g\n', val))
              val = LrDevelopController.getValue("CropTop")
              MIDI2LR.SERVER:send(string.format('CropTopRight %g\n', val))
              MIDI2LR.SERVER:send(string.format('CropTopLeft %g\n', val))
              MIDI2LR.SERVER:send(string.format('CropTop %g\n', val))
              MIDI2LR.SERVER:send(string.format('CropLeft %g\n', LrDevelopController.getValue("CropLeft")))
              MIDI2LR.SERVER:send(string.format('CropRight %g\n', LrDevelopController.getValue("CropRight")))
              for param in pairs(Database.Parameters) do
                local lrvalue = LrDevelopController.getValue(param)
                if observer[param] ~= lrvalue and type(lrvalue) == 'number' then --testing for MIDI2LR.SERVER.send kills responsiveness
                  MIDI2LR.SERVER:send(string.format('%s %g\n', param, CU.LRValueToMIDIValue(param)))
                  observer[param] = lrvalue
                  LastParam = param
                end
              end
              lastrefresh = os.clock() + 0.1 --1/10 sec between refreshes
            end
          end
        end
        AdjustmentChangeObserver = AdjustmentChangeObserver() --complete closure
        local function InactiveObserver() end
        CurrentObserver = AdjustmentChangeObserver -- will change when detect loss of MIDI controller

        -- wrapped in function so can be called when connection lost
        local function startServer(context1)
          MIDI2LR.SERVER = LrSocket.bind {
            functionContext = context1,
            plugin = _PLUGIN,
            port = SEND_PORT,
            mode = 'send',
            onClosed = function () sendIsConnected = false end,
            onConnected = function () sendIsConnected = true end,
            onError = function( socket )
              sendIsConnected = false
              if MIDI2LR.RUNNING then --
                socket:reconnect()
              end
            end,
          }
        end

        local cropbezel = LOC('$$$/AgCameraRawNamedSettings/SaveNamedDialog/Crop=Crop') .. ' ' -- no need to recompute each time we crop
        local LrStringUtils       = import 'LrStringUtils'

        local function RatioCrop(param, value)
          if LrApplication.activeCatalog():getTargetPhoto() == nil then return end
          if LrApplicationView.getCurrentModuleName() ~= 'develop' then
            LrApplicationView.switchToModule('develop')
          end
          LrDevelopController.selectTool('crop')
          local prior_c_bottom = LrDevelopController.getValue("CropBottom") --starts at 1
          local prior_c_top = LrDevelopController.getValue("CropTop") -- starts at 0
          local prior_c_left = LrDevelopController.getValue("CropLeft") -- starts at 0
          local prior_c_right = LrDevelopController.getValue("CropRight") -- starts at 1
          local ratio = (prior_c_right - prior_c_left) / (prior_c_bottom - prior_c_top)
          if param == "CropTopLeft" then
            local new_top = tonumber(value)
            local new_left = prior_c_right - ratio * (prior_c_bottom - new_top)
            if new_left < 0 then
              new_top = prior_c_bottom - prior_c_right / ratio
              new_left = 0
            end
            UpdateParam("CropTop",new_top, 
              cropbezel..LrStringUtils.numberToStringWithSeparators((prior_c_right-new_left)*(prior_c_bottom-new_top)*100,0)..'%')
            UpdateParam("CropLeft",new_left,true)
          elseif param == "CropTopRight" then
            local new_top = tonumber(value)
            local new_right = prior_c_left + ratio * (prior_c_bottom - new_top)
            if new_right > 1 then
              new_top = prior_c_bottom - (1 - prior_c_left) / ratio
              new_right = 1
            end
            UpdateParam("CropTop",new_top,              
              cropbezel..LrStringUtils.numberToStringWithSeparators((new_right-prior_c_left)*(prior_c_bottom-new_top)*100,0)..'%')
            UpdateParam("CropRight",new_right,true)
          elseif param == "CropBottomLeft" then
            local new_bottom = tonumber(value)
            local new_left = prior_c_right - ratio * (new_bottom - prior_c_top)
            if new_left < 0 then
              new_bottom = prior_c_right / ratio + prior_c_top
              new_left = 0
            end
            UpdateParam("CropBottom",new_bottom,              
              cropbezel..LrStringUtils.numberToStringWithSeparators((prior_c_right-new_left)*(new_bottom-prior_c_top)*100,0)..'%')
            UpdateParam("CropLeft",new_left,true)
          elseif param == "CropBottomRight" then
            local new_bottom = tonumber(value)
            local new_right = prior_c_left + ratio * (new_bottom - prior_c_top)
            if new_right > 1 then
              new_bottom = (1 - prior_c_left) / ratio + prior_c_top
              new_right = 1
            end
            UpdateParam("CropBottom",new_bottom,              
              cropbezel..LrStringUtils.numberToStringWithSeparators((new_right-prior_c_left)*(new_bottom-prior_c_top)*100,0)..'%')
            UpdateParam("CropRight",new_right,true)
          elseif param == "CropAll" then
            local new_bottom = tonumber(value)
            local new_right = prior_c_left + ratio * (new_bottom - prior_c_top)
            if new_right > 1 then
              new_right = 1
            end
            local new_top = math.max(prior_c_bottom - new_bottom + prior_c_top,0)
            local new_left = new_right - ratio * (new_bottom - new_top)
            if new_left < 0 then
              new_top = new_bottom - new_right / ratio
              new_left = 0
            end
            UpdateParam("CropBottom",new_bottom,              
              cropbezel..LrStringUtils.numberToStringWithSeparators((new_right-new_left)*(new_bottom-new_top)*100,0)..'%')
            UpdateParam("CropRight",new_right,true)
            UpdateParam("CropTop",new_top,true)
            UpdateParam("CropLeft",new_left,true)
          end
        end

        MIDI2LR.CLIENT = LrSocket.bind {
          functionContext = context,
          plugin = _PLUGIN,
          port = RECEIVE_PORT,
          mode = 'receive',
          onMessage = function(_, message) --message processor
            if type(message) == 'string' then
              local split = message:find(' ',1,true)
              local param = message:sub(1,split-1)
              local value = message:sub(split+1)
              logger:trace('<<< '..param)
              if Database.Parameters[param] then
                UpdateParam(param,tonumber(value))
              elseif(ACTIONS[param]) then -- perform a one time action
                if(tonumber(value) > BUTTON_ON) then
                  logger:trace('Action: '..param)
                  ACTIONS[param]()
                end
              elseif(SETTINGS[param]) then -- do something requiring the transmitted value to be known
                SETTINGS[param](value)
              elseif(Virtual[param]) then -- handle a virtual command
                local lp = Virtual[param](value, UpdateParam)
                if lp then
                  LastParam = lp
                end
              elseif(param:find('Crop') == 1) then 
                RatioCrop(param,value)
              elseif(param:find('Reset') == 1) then -- perform a reset other than those explicitly coded in ACTIONS array
                if(tonumber(value) > BUTTON_ON) then
                  local resetparam = param:sub(6)
                  CU.execFOM(LrDevelopController.resetToDefault,resetparam)
                  if ProgramPreferences.ClientShowBezelOnChange then
                    local lrvalue = LrDevelopController.getValue(resetparam)
                    CU.showBezel(resetparam,lrvalue)
                  end
                end
              elseif param == 'GetValue' then
                local lrvalue = LrDevelopController.getValue(value)
                --logger:trace('GetValue '..value)
                --logger:trace('GetValue '..value..' = '..lrvalue)
                --logger:trace('cooked value is '..CU.LRValueToMIDIValue(value))
                MIDI2LR.SERVER:send(string.format('%s %g\n', value, CU.LRValueToMIDIValue(value)))
                observer[param] = lrvalue
              end
            end
          end,
          onClosed = function( socket )
            if MIDI2LR.RUNNING then
              logger:trace('client closed, reconnecting')
              -- MIDI2LR closed connection, allow for reconnection
              socket:reconnect()
              -- calling SERVER:reconnect causes LR to hang for some reason...
              MIDI2LR.SERVER:close()
              startServer(context)
            end
          end,
          onError = function(socket, err)
            if err == 'timeout' then -- reconnect if timed out
              socket:reconnect()
            end
          end
        }

        startServer(context)
        logger:trace('startServer')

        if(WIN_ENV) then
          -- UNTESTED:
          LrShell.openPathsViaCommandLine({LrPathUtils.child(_PLUGIN.path, 'TangentBridge.py')}, 'python.exe')
        else
          LrShell.openPathsViaCommandLine({LrPathUtils.child(_PLUGIN.path, 'TangentBridge.py')}, '/usr/bin/env', 'python')
        end

        -- add an observer for develop param changes--needs to occur in develop module
        -- will drop out of loop if loadversion changes or if in develop module with selected photo
        while  MIDI2LR.RUNNING and ((LrApplicationView.getCurrentModuleName() ~= 'develop') or (LrApplication.activeCatalog():getTargetPhoto() == nil)) do
          LrTasks.sleep ( .29 )
          Profiles.checkProfile()
        end --sleep away until ended or until develop module activated
        if MIDI2LR.RUNNING then --didn't drop out of loop because of program termination
          if ProgramPreferences.RevealAdjustedControls then --may be nil or false
            LrDevelopController.revealAdjustedControls( true ) -- reveal affected parameter in panel track
          end
          if ProgramPreferences.TrackingDelay ~= nil then
            LrDevelopController.setTrackingDelay(ProgramPreferences.TrackingDelay)
          end
          LrDevelopController.addAdjustmentChangeObserver(
            context,
            MIDI2LR.PARAM_OBSERVER,
            function ( observer )
              CurrentObserver(observer)
            end
          )
          while MIDI2LR.RUNNING do --detect halt or reload
            LrTasks.sleep( .29 )
            Profiles.checkProfile()
          end
        end
      end
    )
  end
)
