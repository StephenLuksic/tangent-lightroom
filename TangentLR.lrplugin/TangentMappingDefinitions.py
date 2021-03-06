#!/usr/bin/env python
# Should work with both Python 2.7 and 3

# This module defines:
# - All the controls we support (for controls.xml)
# - All the mappings we support (for wave-map.xml, etc)
# in a way that is hopefully easier to edit than editing the XML by hand.
#
# Features:
# - Multiple modes (particularly useful on Wave)
# - Ability to set common definitions that apply to all modes

from TangentMapping import *
import sys
import copy

def INV(s):
    # Sets all bits of the input string to 0x80, which inverts on the Tangent display
    rv = ''
    for c in s:
        rv += (chr(ord(c) | 0x80))
    return rv

controls = ControlsFile(
    [
        Mode(1,'Colour/Tone'),
        Mode(2,'Tone/Presence'),
        Mode(3,'Tone Curve'),
        Mode(11,'HueAdjust'),
        Mode(12,'SatAdjust'),
        Mode(13,'LumAdjust'),
        Mode(19,'GreyAdjust'), # caution; XML file chokes on ampersands
        Mode(20,'Split Toning'),
        Mode(21,'Sharpening'),
        Mode(22,'Noise Reduction'),

        Mode(50,'Crop Edges'),
        Mode(51,'Crop Corners'),
        Mode(60,'Flag'),
        Mode(61,'Rotate/Export'),

        Mode(100,'ModesMenu1'),
        Mode(101,'ModesMenu2'),
    ],
    [
        Group('General', [
            Action(0x100, 'Undo', panel='Undo'),
            Action(0x101, 'Redo', panel='Redo'),
            Action(0x102, 'Prev'),
            Action(0x103, 'Next'),
            Action(0x104, 'ShowClipping', panel='Clipping On/Off', name9='Clipping'),
            Action(0x105, 'VirtualCopy', name9='Virt Copy'),

            Parameter(0x120, 'straightenAngle', panel='Angle'),
            Parameter(0x121, 'CropBottom', panel='Bottom'),
            Parameter(0x122, 'CropLeft', panel='Left'),
            Parameter(0x123, 'CropRight', panel='Right'),
            Parameter(0x124, 'CropTop', panel='Top'),
            Action(0x125, 'ResetCrop'),
            Action(0x126, 'CropOverlay', panel='Crop Overlay'),

            Action(0x127, 'Select1Left', name9='Sel Left'),
            Action(0x128, 'Select1Right', name9='Sel Right'),

            Action(0x129, 'ToggleZoomOffOn', panel='Zoom'),

            Action(0x12a, 'SwToMlibrary', panel='Library'),
            Action(0x12b, 'SwToMdevelop', panel='Develop'),

            Parameter(0x130, 'CropTopLeft', panel='Top Left'),
            Parameter(0x131, 'CropTopRight', panel='Top Right'),
            Parameter(0x132, 'CropBottomLeft', panel='Bottom L'),
            Parameter(0x133, 'CropBottomRight', panel='Bottom R'),
            Parameter(0x134, 'CropAll', panel='Crop All'),

            Action(0x40000001, 'UpArrow'),
            Action(0x40000002, 'DownArrow'),
            Action(0x40000003, 'Ignore'),
        ]),

        Group('WB', [
            Action(0x111, 'WhiteBalanceAuto', panel='Auto WB'),
            Menu(0x112, 'Treatment', verbs={'Colour':'SetTreatmentColor', 'B&W':'SetTreatmentBW'}),
            Menu(0x113, 'WB Preset', verbs={
                'Daylight':'QuickDevWBDaylight',
                'Cloudy':'QuickDevWBCloudy',
                'Shade':'QuickDevWBShade',
                'Tungsten':'QuickDevWBTungsten',
                'Fluo':'QuickDevWBFluorescent',
                'Flash':'QuickDevWBFlash'
            }),
        ]),
        Group('Tone', [
            Action(0x110, 'AutoTone', panel='Auto Tone'),

            Parameter(0x201, 'Temperature', name9='ColorTemp', name10='Color Temp', name12='Temperature'),
            Parameter(0x202, 'Tint'),
            Parameter(0x203, 'Exposure'),
            Parameter(0x204, 'Highlights'),
            Parameter(0x205, 'Shadows'),
            Parameter(0x206, 'Brightness', name9='Bright'),
            Parameter(0x207, 'Contrast'),
            Parameter(0x208, 'Blacks'),
            Parameter(0x209, 'Whites'),
        ]),
        Group('Presence', [
            Parameter(0x20a, 'Clarity'),
            Parameter(0x20b, 'Vibrance'),
            Parameter(0x20c, 'Saturation', name9='Saturate'),
            Parameter(0x20d, 'Dehaze'),
            Parameter(0x20e, 'Texture'),
        ]),
        Group('Tone Curve', [
            Parameter(0x210, 'ParametricDarks', panel='Darks'),
            Parameter(0x211, 'ParametricLights', panel='Lights'),
            Parameter(0x212, 'ParametricShadows', panel='Shadows'),
            Parameter(0x213, 'ParametricHighlights', panel='Highlights'),
            Parameter(0x214, 'ParametricShadowSplit', panel='ShadoSplit'),
            Parameter(0x215, 'ParametricMidtoneSplit', panel='Mid Split'),
            Parameter(0x216, 'ParametricHighlightSplit', panel='HighSplit'),
            Menu(0x217, 'Pt Curve', verbs={
                'Linear': 'PointCurveLinear',
                'Medium': 'PointCurveMediumContrast',
                'Strong': 'PointCurveStrongContrast'
            }),
            Action(0x218, 'EnableToneCurve', panel='ToneCurve On/Off'),
        ]),
        Group('Colour Adjust', [
            Action(0x228, 'EnableColorAdjustments', panel='ColorAdj On/Off'),
            Parameter(0x229, 'AllSaturationAdjustment', panel='Saturation', name9='Sat All'),

            # In B&W mode there are eight Grey Mixer dials only (ROYGABPM), which affect luminance
            Parameter(0x220, 'GrayMixerRed', panel='Red Grey'),
            Parameter(0x221, 'GrayMixerOrange', panel='Orange Grey'),
            Parameter(0x222, 'GrayMixerYellow', panel='Yellow Grey'),
            Parameter(0x223, 'GrayMixerGreen', panel='Green Grey'),
            Parameter(0x224, 'GrayMixerAqua', panel='Aqua Grey'),
            Parameter(0x225, 'GrayMixerBlue', panel='Blue Grey'),
            Parameter(0x226, 'GrayMixerPurple', panel='Purple G'),
            Parameter(0x227, 'GrayMixerMagenta', panel='Magenta G'),

            # In colour mode there are Sat, Hue, Lum for each of eight colurs ROYGABPM
            Parameter(0x230, 'SaturationAdjustmentRed', panel='Red Sat'),
            Parameter(0x231, 'SaturationAdjustmentOrange', panel='Orange Sat'),
            Parameter(0x232, 'SaturationAdjustmentYellow', panel='Yellow Sat'),
            Parameter(0x233, 'SaturationAdjustmentGreen', panel='Green Sat'),
            Parameter(0x234, 'SaturationAdjustmentAqua', panel='Aqua Sat'),
            Parameter(0x235, 'SaturationAdjustmentBlue', panel='Blue Sat'),
            Parameter(0x236, 'SaturationAdjustmentPurple', panel='Purple S'),
            Parameter(0x237, 'SaturationAdjustmentMagenta', panel='Magenta S'),

            Parameter(0x240, 'HueAdjustmentRed', panel='Red Hue'),
            Parameter(0x241, 'HueAdjustmentOrange', panel='Orange Hue'),
            Parameter(0x242, 'HueAdjustmentYellow', panel='Yellow Hue'),
            Parameter(0x243, 'HueAdjustmentGreen', panel='Green Hue'),
            Parameter(0x244, 'HueAdjustmentAqua', panel='Aqua Hue'),
            Parameter(0x245, 'HueAdjustmentBlue', panel='Blue Hue'),
            Parameter(0x246, 'HueAdjustmentPurple', panel='Purple H'),
            Parameter(0x247, 'HueAdjustmentMagenta', panel='Magenta H'),

            Parameter(0x250, 'LuminanceAdjustmentRed', panel='Red Lum'),
            Parameter(0x251, 'LuminanceAdjustmentOrange', panel='Orange Lum'),
            Parameter(0x252, 'LuminanceAdjustmentYellow', panel='Yellow Lum'),
            Parameter(0x253, 'LuminanceAdjustmentGreen', panel='Green Lum'),
            Parameter(0x254, 'LuminanceAdjustmentAqua', panel='Aqua Lum'),
            Parameter(0x255, 'LuminanceAdjustmentBlue', panel='Blue Lum'),
            Parameter(0x256, 'LuminanceAdjustmentPurple', panel='Purple L'),
            Parameter(0x257, 'LuminanceAdjustmentMagenta', panel='Magenta L'),
        ]),
        Group('Split Toning', [
            Action(0x260, 'EnableSplitToning', panel='Split Tone On/Off'),
            Parameter(0x261, 'SplitToningBalance', panel='ST Balance'),
            Parameter(0x262, 'SplitToningShadowHue', panel='Shadow Hue'),
            Parameter(0x263, 'SplitToningShadowSaturation', panel='Shadow Sat'),
            Parameter(0x264, 'SplitToningHighlightHue', panel='Highl Hue'),
            Parameter(0x265, 'SplitToningHighlightSaturation', panel='Highl Sat'),
        ]),

        Group('Detail', [
            Action(0x270, 'EnableDetail', panel='Detail On/Off'),
            Parameter(0x271, 'Sharpness', panel='Sharpen'),
            Parameter(0x272, 'SharpenRadius', panel='Radius'),
            Parameter(0x273, 'SharpenDetail', panel='Detail'),
            Parameter(0x274, 'SharpenEdgeMasking', panel='Masking'),

            Parameter(0x275, 'LuminanceSmoothing', panel='NR Luminance'),
            Parameter(0x276, 'LuminanceNoiseReductionDetail', panel='Detail'),
            Parameter(0x277, 'LuminanceNoiseReductionContrast', panel='Contrast'),
            Parameter(0x278, 'ColorNoiseReduction', panel='NR Colour'),
            Parameter(0x279, 'ColorNoiseReductionDetail', panel='Detail'),
            Parameter(0x27a, 'ColorNoiseReductionSmoothness', panel='Smoothness'),
        ]),

        Group('Flagging', [
            Action(0x300, 'Pick'),
            Action(0x301, 'Reject'),
            Action(0x302, 'RemoveFlag', panel='Unflag'),

            Action(0x303, 'ToggleRed', panel='Red'),
            Action(0x304, 'ToggleGreen', panel='Green'),
            Action(0x305, 'ToggleBlue', panel='Blue'),
            Action(0x306, 'TogglePurple', panel='Purple'),
            Action(0x307, 'ToggleYellow', panel='Yellow'),
            Action(0x30e, 'ColorLabelNone', panel='Clear Colours'),

            Action(0x308, 'AddOrRemoveFromTargetColl', panel='Target Collection', name9='TargetCol'),

            Action(0x309, 'RotateLeft', panel='Rotate L'),
            Action(0x30a, 'RotateRight', panel='Rotate R'),
            Action(0x30b, 'EditPhotoshop', panel='Photoshop Edit'),
            Action(0x30c, 'openExportDialog', panel='Export...'),
            Action(0x30d, 'openExportWithPreviousDialog', panel='Export again', name9='ReExport'),
        ]),
    ]
)

GO_TO_MODE = 0x8000000b

wave = MapFile([Panel(
    'Wave',
    [ # common definitions
            ControlBank('Standard',[
                # Buttons and encoders without displays
                Bank([
                    # Truly standard controls which should appear in every bank:
                    Button(36, 0x102, 0x127), # Previous / Select1Left
                    Button(37, 0x103, 0x128), # Next / Select1Right
                    Button( 9, 0x80000001, 0x80000001), # Alt
                    Button(25, 0x40000001, 0x40000001), # Up arrow -> special logic
                    Button(26, 0x40000002, 0x40000002), # Down arrow -> special logic
                    Encoder(12, 0x81000001, 0x81000001), # Transport dial

                    Encoder( 9, 0x205, 0x205), # Dial 1 - Shadows
                    Encoder(10, 0x203, 0x203), # Dial 2 - Exposure
                    Encoder(11, 0x204, 0x204), # Dial 3 - Highlights

                    Button(33, 0x100, 0x100), # F1 - Undo
                    Button(34, 0x101, 0x101), # F2 - Redo
                    Button(35, 0x105), # F3 - Create Virtual Copy

                    Button(30, 0x104), # F4 - Clipping On/Off
                    Button(31, 0x127), # F5 - Select1Left
                    Button(32, 0x128), # F6 - Select1Right

                    Button(27, 0x12a), # F7 - Library
                    Button(28, 0x12b), # F8 - Develop
                    Button(29, 0x129), # F9 - ToggleZoomOffOn
                ]),
            ]),
    ],
    [ # Mode-specific definitions

        # Develop WB/Tone
        Mode(1, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, 0x201, 0x201), # Temp
                    Encoder(1, 0x202, 0x202), # Tint
                    # WB mode on enc 2?
                    Encoder(3, 0x207, 0x207), # Contrast
                    Encoder(4, 0x208, 0x208), # Blacks
                    Encoder(5, 0x209, 0x209), # Whites
                ]),
            ]),
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button(10, 0x112), # Colour/B&W
                    Button(11, 0x113), # WB presets
                    Button(12, 0x111), # Auto WB
                    Button(16, 0x110), # Auto Tone
                ]),
            ]),
        ]),

        # Develop Tone/Presence
        Mode(2, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, 0x207, 0x207), # Contrast
                    Encoder(1, 0x208, 0x208), # Blacks
                    Encoder(2, 0x209, 0x209), # Whites

                    Encoder(3, 0x20e, 0x20e), # Texture
                    Encoder(4, 0x20a, 0x20a), # Clarity
                    Encoder(5, 0x20d, 0x20d), # Dehaze
                    Encoder(6, 0x20b, 0x20b), # Vibrance
                    Encoder(7, 0x20c, 0x20c), # Saturation
                ]),
            ]),
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button(11, 0x110), # Auto Tone
                ]),
            ]),
        ]),

        # Point Curve
        Mode(3, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(1, 0x212, 0x212), # Shadows
                    Encoder(2, 0x210, 0x210), # Darks
                    Encoder(3, 0x211, 0x211), # Lights
                    Encoder(4, 0x213, 0x213), # Highlights

                    Encoder(6, 0x214, 0x214), # Shadow split
                    Encoder(7, 0x215, 0x215), # Midtone split
                    Encoder(8, 0x216, 0x216), # Highlight split
                ]),
            ]),
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button(10, 0x218), # Enable/Disable Tone Curve
                    Button(12, 0x217), # Pt Curve menu
                ]),
            ]),
        ]),

        # HSL Hue:
        Mode(11, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, 0x240, 0x240), # Hue Red
                    Encoder(1, 0x241, 0x241), # Hue Orange
                    Encoder(2, 0x242, 0x242), # Hue Yellow
                    Encoder(3, 0x243, 0x243), # Hue Green
                    Encoder(4, 0x244, 0x244), # Hue Aqua
                    Encoder(5, 0x245, 0x245), # Hue Blue
                    Encoder(6, 0x246, 0x246), # Hue Purple
                    Encoder(7, 0x247, 0x247), # Hue Magenta

                    #Encoder(8, 0x229, 0x229), # All Sat
                ]),
            ]),
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button(10, 0x228), # ColorAdj On/Off
                ]),
            ]),
        ]),
        # HSL Sat
        Mode(12, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, 0x230, 0x230), # Sat Red
                    Encoder(1, 0x231, 0x231), # Sat Orange
                    Encoder(2, 0x232, 0x232), # Sat Yellow
                    Encoder(3, 0x233, 0x233), # Sat Green
                    Encoder(4, 0x234, 0x234), # Sat Aqua
                    Encoder(5, 0x235, 0x235), # Sat Blue
                    Encoder(6, 0x236, 0x236), # Sat Purple
                    Encoder(7, 0x237, 0x237), # Sat Magenta

                    Encoder(8, 0x229, 0x229), # All Sat
                ]),
            ]),
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button(10, 0x228), # ColorAdj On/Off
                ]),
            ]),
        ]),
        # HSL Luminance
        Mode(13, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, 0x250, 0x250), # Lum Red
                    Encoder(1, 0x251, 0x251), # Lum Orange
                    Encoder(2, 0x252, 0x252), # Lum Yellow
                    Encoder(3, 0x253, 0x253), # Lum Green
                    Encoder(4, 0x254, 0x254), # Lum Aqua
                    Encoder(5, 0x255, 0x255), # Lum Blue
                    Encoder(6, 0x256, 0x256), # Lum Purple
                    Encoder(7, 0x257, 0x257), # Lum Magenta

                    #Encoder(8, 0x229, 0x229), # All Sat
                ]),
            ]),
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button(10, 0x228), # ColorAdj On/Off
                ]),
            ]),
        ]),

        # B&W Grey Mixers
        Mode(19, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, 0x220, 0x220), # Grey Red
                    Encoder(1, 0x221, 0x221), # Grey Orange
                    Encoder(2, 0x222, 0x222), # Grey Yellow
                    Encoder(3, 0x223, 0x223), # Grey Green
                    Encoder(4, 0x224, 0x224), # Grey Aqua
                    Encoder(5, 0x225, 0x225), # Grey Blue
                    Encoder(6, 0x226, 0x226), # Grey Purple
                    Encoder(7, 0x227, 0x227), # Grey Magenta
                ]),
            ]),
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button(10, 0x228), # ColorAdj On/Off
                ]),
            ]),
        ]),

        # Split Toning
        Mode(20, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button(10, 0x260), # Split Toning On/Off
                ]),
            ]),
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(1, 0x262, 0x262), # Hue Shadow
                    Encoder(2, 0x263, 0x263), # Sat Shadow
                    Encoder(3, 0x264, 0x264), # Hue HL
                    Encoder(4, 0x265, 0x265), # Sat HL
                    Encoder(6, 0x261, 0x261), # Balance
                ]),
            ]),
        ]),

        # Sharpening
        Mode(21, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button(10, 0x270), # Detail On/Off
                ]),
            ]),
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(2, 0x271, 0x271), # Sharpness
                    Encoder(3, 0x272, 0x272), # Radius
                    Encoder(4, 0x273, 0x273), # Detail
                    Encoder(5, 0x274, 0x274), # Edge Masking
                ]),
            ]),
        ]),

        # Noise Reduction
        Mode(22, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button(10, 0x270), # Detail On/Off
                ]),
            ]),
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, 0x275, 0x275), # Luminance NR
                    Encoder(1, 0x276, 0x276), # Detail
                    Encoder(2, 0x277, 0x277), # Contrast
                    Encoder(3, 0x278, 0x278), # Colour NR
                    Encoder(4, 0x279, 0x279), # Detail
                    Encoder(5, 0x27a, 0x27a), # Smoothness
                ]),
            ]),
        ]),

        # Crop
        Mode(50, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button(17, 0x125), # Reset Crop
                    Button(10, 0x126), # Crop Overlay
                ]),
            ]),
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(6, 0x134, 0x134), # All
                    Encoder(8, 0x120, 0x120), # Angle

                    Encoder(1, 0x124, 0x124), # Top
                    Encoder(2, 0x121, 0x121), # Bottom
                    Encoder(3, 0x122, 0x122), # Left
                    Encoder(4, 0x123, 0x123), # Right
                ]),
            ]),
        ]),

        # Crop 2
        Mode(51, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button(17, 0x125), # Reset Crop
                    Button(10, 0x126), # Crop Overlay
                ]),
            ]),
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(6, 0x134, 0x134), # All
                    Encoder(8, 0x120, 0x120), # Angle

                    Encoder(1, 0x130, 0x130), # TL
                    Encoder(2, 0x132, 0x132), # BL
                    Encoder(3, 0x133, 0x133), # BR
                    Encoder(4, 0x131, 0x131), # TR

                ]),
            ]),
        ]),

        # Flag/Rotate/Export
        Mode(60, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button(10, 0x300), # Pick
                    Button(11, 0x301), # Reject
                    Button(12, 0x302), # Unflag

                    Button(15, 0x303), # Red
                    Button(16, 0x304), # Green
                    Button(17, 0x305), # Blue

                    Button(20, 0x306), # Purple
                    Button(21, 0x307), # Yellow
                    Button(22, 0x308), # Toggle Target Collection
                    #Button(22, 0x30e), # Clear Labels
                ]),
            ]),
        ]),

        # Rotate/Export
        Mode(61, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button(10, 0x309), # RotateLeft
                    Button(11, 0x30a), # RotateRight

                    Button(15, 0x30c), # Export...
                    Button(16, 0x30d), # Export Again

                    Button(20, 0x30b), # Edit in Photoshop
                ]),
            ]),
        ]),

        # ModesMenu
        Mode(100, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, Std(0x40000003, None, INV(' Modes 1 '))), # action ignored
                ]),
            ]),
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button(10, Std(GO_TO_MODE, 1, 'Colour/ Tone'), Alt(GO_TO_MODE, 50, 'Crop Corners')),
                    Button(11, Std(GO_TO_MODE, 2, 'Tone/ Presence'), Alt(GO_TO_MODE, 51, 'Crop Edges')),
                    Button(12, Std(GO_TO_MODE, 3, 'Tone Curve'), Alt(GO_TO_MODE, 60, 'Flag')),

                    Button(15, Std(GO_TO_MODE, 11, 'Hue')),
                    Button(16, Std(GO_TO_MODE, 12, 'Saturation')),
                    Button(17, Std(GO_TO_MODE, 13, 'Luminance'), Alt(GO_TO_MODE, 19, 'Greys')),

                    Button(20, Std(GO_TO_MODE, 20, 'Split Toning')),
                    Button(21, Std(GO_TO_MODE, 21, 'Sharpening')),
                    Button(22, Std(GO_TO_MODE, 22, 'Noise Reduction')),
                ]),
            ]),
        ]),

        Mode(101, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, Std(0x40000003, None, INV(' Modes 2 '))), # action ignored
                ]),
            ]),
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button(10, Std(GO_TO_MODE, 50, 'Crop Edges')),
                    Button(11, Std(GO_TO_MODE, 51, 'Crop Corners')),
                    Button(12, Std(GO_TO_MODE, 60, 'Flag')),
                    Button(15, Std(GO_TO_MODE, 61, 'Rotate/ Export')),
                ]),
            ]),
        ]),
    ]
)])

##############################################################

ripple = MapFile([Panel(
    'Ripple',
    [ # common definitions
    ],
    [Mode(1, controlBanks=[
        ControlBank('Standard',[
            Bank([
                Button(0, 0x80000001), # A -> Alt
                Button(7, 0x100, 0x101), # B -> Undo / Redo
            ]),
        ]),
        ControlBank('Trackerball',[
            # for some reason Tangent Hub insists this is a separate bank, even though the Ripple has no displays
            Bank([
                Encoder(2, 0x205, 0x205), # Dial 1 -> Shadows
                Encoder(5, 0x203, 0x203), # Dial 2 -> Exposure
                Encoder(8, 0x204, 0x204), # Dial 3 -> Highlights
            ]),
        ]),

    ])],
    ignoreModesCheck=True
)])


##############################################################

emptymodes = copy.deepcopy(controls.modes)
for m in emptymodes:
    m.Name = None
    m.controlbanks = []

tkmodes = copy.deepcopy(emptymodes)
mfmodes = copy.deepcopy(emptymodes)
mfmodes = list(filter(lambda m : m.id is not 100, mfmodes))
mfmodes.append(Mode(100, controlBanks=[
    ControlBank('Button',[
        # Buttons with displays
        Bank([
            Button( 0, Std(GO_TO_MODE, 1, 'Basic'), Alt(GO_TO_MODE, 50, 'Crop')),
            # modes 1 & 2 are same
            Button( 1, Std(GO_TO_MODE, 3, 'ToneCurve'), Alt(GO_TO_MODE, 60, 'Flag')),
            Button( 2, Std(GO_TO_MODE, 19, 'Greys')),

            Button( 3, Std(GO_TO_MODE, 11, 'Hue')),
            Button( 4, Std(GO_TO_MODE, 12, 'Sat')),
            Button( 5, Std(GO_TO_MODE, 13, 'Lum'), Alt(GO_TO_MODE, 19, 'Greys')),

            Button( 6, Std(GO_TO_MODE, 20, 'SplitTone')),
            Button( 7, Std(GO_TO_MODE, 21, 'Sharpen')),
            Button( 8, Std(GO_TO_MODE, 22, 'Noise Red')),

            Button( 9, Std(GO_TO_MODE, 50, 'Crop')),
            # modes 50 & 51 are same
            Button(10, Std(GO_TO_MODE, 60, 'Flag')),
            Button(11, Std(GO_TO_MODE, 61, 'Rota/Expo')),
        ]),
    ]),
]))

elementtk = MapFile([Panel(
    'Element-Tk',
    [
        # same as ripple
        ControlBank('Standard',[
            Bank([
                Button(0, 0x80000001), # A -> Alt
                Button(7, 0x100, 0x101), # B -> Undo / Redo
            ]),
        ]),
        ControlBank('Trackerball',[
            Bank([
                Encoder(2, 0x205, 0x205), # Dial 1 -> Shadows
                Encoder(5, 0x203, 0x203), # Dial 2 -> Exposure
                Encoder(8, 0x204, 0x204), # Dial 3 -> Highlights
            ]),
        ]),
    ],
    tkmodes
)])


elementmf = MapFile([Panel(
    'Element-Mf',
    [
        # This setup is very similar to my Wave F keys and transport dial map
        ControlBank('Standard', [
            Bank([
                Button(16, 0x102, 0x127), # Previous / Select1Left
                Button(17, 0x103, 0x128), # Next / Select1Right
                Button(12, 0x80000001, 0x80000001), # Alt
            ])
        ]),
        ControlBank('Button', [
            Bank([

                Button( 9, 0x100, 0x100), # Undo
                Button(10, 0x101, 0x101), # Redo
                Button(11, 0x105), # Create Virtual Copy

                Button( 6, 0x104), # Clipping On/Off
                Button( 7, 0x127), # Select1Left
                Button( 8, 0x128), # Select1Right

                Button( 3, 0x12a), # Library
                Button( 4, 0x12b), # Develop
                Button( 5, 0x129), # ToggleZoomOffOn

                Button(2, Std(GO_TO_MODE, 100, 'Modes')),
            ])
        ]),
        ControlBank('Trackerball', [
            Bank([
                Encoder(2, 0x81000001, 0x81000001), # Transport dial
            ])
        ]),
    ],
    mfmodes,
)])

# Kb and Bt are based on the Wave

elementkb = MapFile([Panel(
    'Element-Kb',
    [],
    [ # Mode-specific definitions
        # Develop WB/Tone
        Mode(1, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, 0x201, 0x201), # Temp
                    Encoder(1, 0x202, 0x202), # Tint
                    # WB mode on enc 2?
                    Encoder(3, 0x207, 0x207), # Contrast
                    Encoder(4, 0x208, 0x208), # Blacks
                    Encoder(5, 0x209, 0x209), # Whites

                    Encoder(6, 0x20e, 0x20e), # Texture
                    Encoder(7, 0x20a, 0x20a), # Clarity
                    Encoder(8, 0x20d, 0x20d), # Dehaze
                    Encoder(9, 0x20b, 0x20b), # Vibrance
                    Encoder(10,0x20c, 0x20c), # Saturation
                ]),
            ]),
            ControlBank('Standard',[Bank([
                Button(12, 0x80000001),
            ])]),
        ]),

        # Develop Tone/Presence
        Mode(2, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, 0x201, 0x201), # Temp
                    Encoder(1, 0x202, 0x202), # Tint
                    # WB mode on enc 2?
                    Encoder(3, 0x207, 0x207), # Contrast
                    Encoder(4, 0x208, 0x208), # Blacks
                    Encoder(5, 0x209, 0x209), # Whites

                    Encoder(6, 0x20e, 0x20e), # Texture
                    Encoder(7, 0x20a, 0x20a), # Clarity
                    Encoder(8, 0x20d, 0x20d), # Dehaze
                    Encoder(9, 0x20b, 0x20b), # Vibrance
                    Encoder(10,0x20c, 0x20c), # Saturation
                ]),
            ]),
            ControlBank('Standard',[Bank([
                Button(12, 0x80000001),
                Button(13, 0x110), # Auto Tone
            ])]),
        ]),

        # Point Curve
        Mode(3, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, 0x212, 0x212), # Shadows
                    Encoder(1, 0x210, 0x210), # Darks
                    Encoder(4, 0x211, 0x211), # Lights
                    Encoder(5, 0x213, 0x213), # Highlights

                    Encoder(9, 0x214, 0x214), # Shadow split
                    Encoder(10,0x215, 0x215), # Midtone split
                    Encoder(11,0x216, 0x216), # Highlight split
                ]),
            ]),
            ControlBank('Standard',[Bank([
                Button(12, 0x80000001),
                Button(13, 0x218, 0x217), # Enable/Disable Tone Curve / Pt Curve Menu
            ])]),
        ]),

        # HSL Hue:
        Mode(11, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, 0x240, 0x240), # Hue Red
                    Encoder(1, 0x241, 0x241), # Hue Orange
                    Encoder(2, 0x242, 0x242), # Hue Yellow
                    Encoder(3, 0x243, 0x243), # Hue Green
                    Encoder(4, 0x244, 0x244), # Hue Aqua
                    Encoder(5, 0x245, 0x245), # Hue Blue
                    Encoder(6, 0x246, 0x246), # Hue Purple
                    Encoder(7, 0x247, 0x247), # Hue Magenta

                    #Encoder(8, 0x229, 0x229), # All Sat
                ]),
            ]),
            ControlBank('Standard',[Bank([
                Button(12, 0x80000001),
                Button(13, 0x228), # ColorAdj On/Off
            ])]),
        ]),
        # HSL Sat
        Mode(12, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, 0x230, 0x230), # Sat Red
                    Encoder(1, 0x231, 0x231), # Sat Orange
                    Encoder(2, 0x232, 0x232), # Sat Yellow
                    Encoder(3, 0x233, 0x233), # Sat Green
                    Encoder(4, 0x234, 0x234), # Sat Aqua
                    Encoder(5, 0x235, 0x235), # Sat Blue
                    Encoder(6, 0x236, 0x236), # Sat Purple
                    Encoder(7, 0x237, 0x237), # Sat Magenta

                    Encoder(8, 0x229, 0x229), # All Sat
                ]),
            ]),
            ControlBank('Standard',[Bank([
                Button(12, 0x80000001),
                Button(13, 0x228), # ColorAdj On/Off
            ])]),
        ]),
        # HSL Luminance
        Mode(13, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, 0x250, 0x250), # Lum Red
                    Encoder(1, 0x251, 0x251), # Lum Orange
                    Encoder(2, 0x252, 0x252), # Lum Yellow
                    Encoder(3, 0x253, 0x253), # Lum Green
                    Encoder(4, 0x254, 0x254), # Lum Aqua
                    Encoder(5, 0x255, 0x255), # Lum Blue
                    Encoder(6, 0x256, 0x256), # Lum Purple
                    Encoder(7, 0x257, 0x257), # Lum Magenta

                    #Encoder(8, 0x229, 0x229), # All Sat
                ]),
            ]),
            ControlBank('Standard',[Bank([
                Button(12, 0x80000001),
                Button(13, 0x228), # ColorAdj On/Off
            ])]),
        ]),

        # B&W Grey Mixers
        Mode(19, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, 0x220, 0x220), # Grey Red
                    Encoder(1, 0x221, 0x221), # Grey Orange
                    Encoder(2, 0x222, 0x222), # Grey Yellow
                    Encoder(3, 0x223, 0x223), # Grey Green
                    Encoder(4, 0x224, 0x224), # Grey Aqua
                    Encoder(5, 0x225, 0x225), # Grey Blue
                    Encoder(6, 0x226, 0x226), # Grey Purple
                    Encoder(7, 0x227, 0x227), # Grey Magenta
                ]),
            ]),
            ControlBank('Standard',[Bank([
                Button(12, 0x80000001),
                Button(13, 0x228), # ColorAdj On/Off
            ])]),
        ]),

        # Split Toning
        Mode(20, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, 0x262, 0x262), # Hue Shadow
                    Encoder(2, 0x263, 0x263), # Sat Shadow
                    Encoder(6, 0x264, 0x264), # Hue HL
                    Encoder(8, 0x265, 0x265), # Sat HL
                    Encoder(4, 0x261, 0x261), # Balance
                ]),
            ]),
            ControlBank('Standard',[Bank([
                Button(12, 0x80000001),
                Button(13, 0x260), # Split Toning On/Off
            ])]),
        ]),

        # Sharpening
        Mode(21, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(1, 0x271, 0x271), # Sharpness
                    Encoder(3, 0x272, 0x272), # Radius
                    Encoder(4, 0x273, 0x273), # Detail
                    Encoder(5, 0x274, 0x274), # Edge Masking
                ]),
            ]),
            ControlBank('Standard',[Bank([
                Button(12, 0x80000001),
                Button(13, 0x270), # Detail On/Off
            ])]),
        ]),

        # Noise Reduction
        Mode(22, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, 0x275, 0x275), # Luminance NR
                    Encoder(1, 0x276, 0x276), # Detail
                    Encoder(2, 0x277, 0x277), # Contrast
                    Encoder(3, 0x278, 0x278), # Colour NR
                    Encoder(4, 0x279, 0x279), # Detail
                    Encoder(5, 0x27a, 0x27a), # Smoothness
                ]),
            ]),
            ControlBank('Standard',[Bank([
                Button(12, 0x80000001),
                Button(13, 0x270), # Detail On/Off
            ])]),
        ]),

        # Crop
        Mode(50, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, 0x134, 0x134), # All
                    Encoder(2, 0x120, 0x120), # Angle

                    Encoder(4, 0x124, 0x124), # Top
                    Encoder(10,0x121, 0x121), # Bottom
                    Encoder(6, 0x122, 0x122), # Left
                    Encoder(8, 0x123, 0x123), # Right

                    Encoder(3, 0x130, 0x130), # TL
                    Encoder(9, 0x132, 0x132), # BL
                    Encoder(11,0x133, 0x133), # BR
                    Encoder(5, 0x131, 0x131), # TR
                ]),
            ]),
            ControlBank('Standard',[Bank([
                Button(12, 0x80000001),
                Button(13, 0x125, 0x126), # Reset Crop / Crop Overlay
            ])]),
        ]),

        # Crop 2
        Mode(51, controlBanks=[
            ControlBank('Encoder',[
                # Encoders with displays
                Bank([
                    Encoder(0, 0x134, 0x134), # All
                    Encoder(2, 0x120, 0x120), # Angle

                    Encoder(4, 0x124, 0x124), # Top
                    Encoder(10,0x121, 0x121), # Bottom
                    Encoder(6, 0x122, 0x122), # Left
                    Encoder(8, 0x123, 0x123), # Right

                    Encoder(3, 0x130, 0x130), # TL
                    Encoder(9, 0x132, 0x132), # BL
                    Encoder(11,0x133, 0x133), # BR
                    Encoder(5, 0x131, 0x131), # TR

                ]),
            ]),
            ControlBank('Standard',[Bank([
                Button(12, 0x80000001),
                Button(13, 0x125, 0x126), # Reset Crop / Crop Overlay
            ])]),
        ]),

        # Flag/Rotate/Export
        Mode(60, controlBanks=[
        ]),

        # Rotate/Export
        Mode(61, controlBanks=[
        ]),

        # ModesMenu
        Mode(100, controlBanks=[
        ]),

        Mode(101, controlBanks=[
        ]),
    ]
)])

elementbt = MapFile([Panel(
    'Element-Bt',
    [],
    [ # Mode-specific definitions
        # Develop WB/Tone
        Mode(1, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button( 0, 0x112), # Colour/B&W
                    Button( 1, 0x113), # WB presets
                    Button( 2, 0x111), # Auto WB
                    Button( 3, 0x110), # Auto Tone
                    Button(11, Std(GO_TO_MODE, 100, 'Modes')),
                ]),
            ]),
        ]),

        # Develop Tone/Presence
        Mode(2, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button( 0, 0x112), # Colour/B&W
                    Button( 1, 0x113), # WB presets
                    Button( 2, 0x111), # Auto WB
                    Button( 3, 0x110), # Auto Tone
                    Button(11, Std(GO_TO_MODE, 100, 'Modes')),
                ]),
            ]),
        ]),

        # Point Curve
        Mode(3, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button( 0, 0x218), # Enable/Disable Tone Curve
                    Button( 1, 0x217), # Pt Curve menu
                    Button(11, Std(GO_TO_MODE, 100, 'Modes')),
                ]),
            ]),
        ]),

        # HSL Hue:
        Mode(11, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button( 0, 0x228), # ColorAdj On/Off
                    Button(11, Std(GO_TO_MODE, 100, 'Modes')),
                ]),
            ]),
        ]),
        # HSL Sat
        Mode(12, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button( 0, 0x228), # ColorAdj On/Off
                    Button(11, Std(GO_TO_MODE, 100, 'Modes')),
                ]),
            ]),
        ]),
        # HSL Luminance
        Mode(13, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button( 0, 0x228), # ColorAdj On/Off
                    Button(11, Std(GO_TO_MODE, 100, 'Modes')),
                ]),
            ]),
        ]),

        # B&W Grey Mixers
        Mode(19, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button( 0, 0x228), # ColorAdj On/Off
                    Button(11, Std(GO_TO_MODE, 100, 'Modes')),
                ]),
            ]),
        ]),

        # Split Toning
        Mode(20, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button( 0, 0x260), # Split Toning On/Off
                    Button(11, Std(GO_TO_MODE, 100, 'Modes')),
                ]),
            ]),
        ]),

        # Sharpening
        Mode(21, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button( 0, 0x270), # Detail On/Off
                    Button(11, Std(GO_TO_MODE, 100, 'Modes')),
                ]),
            ]),
        ]),

        # Noise Reduction
        Mode(22, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button( 0, 0x270), # Detail On/Off
                    Button(11, Std(GO_TO_MODE, 100, 'Modes')),
                ]),
            ]),
        ]),

        # Crop
        Mode(50, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button( 2, 0x125), # Reset Crop
                    Button(10, 0x126), # Crop Overlay
                    Button(11, Std(GO_TO_MODE, 100, 'Modes')),
                ]),
            ]),
        ]),

        # Crop 2
        Mode(51, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button( 2, 0x125), # Reset Crop
                    Button(10, 0x126), # Crop Overlay
                    Button(11, Std(GO_TO_MODE, 100, 'Modes')),
                ]),
            ]),
        ]),

        # Flag/Rotate/Export
        Mode(60, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button( 0, 0x300), # Pick
                    Button( 1, 0x301), # Reject
                    Button( 2, 0x302), # Unflag

                    Button( 3, 0x303), # Red
                    Button( 4, 0x304), # Green
                    Button( 5, 0x305), # Blue

                    Button( 6, 0x306), # Purple
                    Button( 7, 0x307), # Yellow
                    Button( 8, 0x308), # Toggle Target Collection
                    #Button(22, 0x30e), # Clear Labels
                    Button(11, Std(GO_TO_MODE, 100, 'Modes')),
                ]),
            ]),
        ]),

        # Rotate/Export
        Mode(61, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button( 0, 0x309), # RotateLeft
                    Button( 2, 0x30a), # RotateRight

                    Button( 6, 0x30c), # Export...
                    Button( 7, 0x30d), # Export Again

                    Button( 8, 0x30b), # Edit in Photoshop

                    Button(11, Std(GO_TO_MODE, 100, 'Modes')),
                ]),
            ]),
        ]),

        # ModesMenu
        Mode(100, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button( 0, Std(GO_TO_MODE, 1, 'Basic'), Alt(GO_TO_MODE, 50, 'Crop')),
                    # modes 1 & 2 are same
                    Button( 1, Std(GO_TO_MODE, 3, 'ToneCurve'), Alt(GO_TO_MODE, 60, 'Flag')),
                    Button( 2, Std(GO_TO_MODE, 19, 'Greys')),

                    Button( 3, Std(GO_TO_MODE, 11, 'Hue')),
                    Button( 4, Std(GO_TO_MODE, 12, 'Sat')),
                    Button( 5, Std(GO_TO_MODE, 13, 'Lum'), Alt(GO_TO_MODE, 19, 'Greys')),

                    Button( 6, Std(GO_TO_MODE, 20, 'SplitTone')),
                    Button( 7, Std(GO_TO_MODE, 21, 'Sharpen')),
                    Button( 8, Std(GO_TO_MODE, 22, 'Noise Red')),

                    Button( 9, Std(GO_TO_MODE, 50, 'Crop')),
                    # modes 50 & 51 are same
                    Button(10, Std(GO_TO_MODE, 60, 'Flag')),
                    Button(11, Std(GO_TO_MODE, 61, 'Rota/Expo')),
                ]),
            ]),
        ]),

        Mode(101, controlBanks=[
            ControlBank('Button',[
                # Buttons with displays
                Bank([
                    Button( 0, Std(GO_TO_MODE, 1, 'Basic'), Alt(GO_TO_MODE, 50, 'Crop')),
                    # modes 1 & 2 are same
                    Button( 1, Std(GO_TO_MODE, 3, 'ToneCurve'), Alt(GO_TO_MODE, 60, 'Flag')),
                    Button( 2, Std(GO_TO_MODE, 19, 'Greys')),

                    Button( 3, Std(GO_TO_MODE, 11, 'Hue')),
                    Button( 4, Std(GO_TO_MODE, 12, 'Sat')),
                    Button( 5, Std(GO_TO_MODE, 13, 'Lum'), Alt(GO_TO_MODE, 19, 'Greys')),

                    Button( 6, Std(GO_TO_MODE, 20, 'SplitTone')),
                    Button( 7, Std(GO_TO_MODE, 21, 'Sharpen')),
                    Button( 8, Std(GO_TO_MODE, 22, 'Noise Red')),

                    Button( 9, Std(GO_TO_MODE, 50, 'Crop')),
                    # modes 50 & 51 are same
                    Button(10, Std(GO_TO_MODE, 60, 'Flag')),
                    Button(11, Std(GO_TO_MODE, 61, 'Rota/Expo')),
                ]),
            ]),
        ]),
    ]
)])

controls.check(None)
wave.check(controls)
ripple.check(controls)
elementtk.check(controls)
elementmf.check(controls)
elementkb.check(controls)
elementbt.check(controls)

def write_file(filename, obj):
    if sys.version_info[0] < 3:
        # N.B. assumes latin_1 encoding; ASCII + some high-bit-set characters
        with open(filename, 'w') as f:
            f.write( obj.xml(0, controls) )
    else:
        with open(filename, 'w',encoding='latin_1') as f:
            f.write( obj.xml(0, controls) )
    print("Wrote to %s"%filename)


if __name__ == '__main__':
    write_file('controls.xml', controls)
    write_file('wave-map.xml', wave)
    write_file('ripple-map.xml', ripple)
    write_file('element-tk-map.xml', elementtk)
    write_file('element-mf-map.xml', elementmf)
    write_file('element-bt-map.xml', elementbt)
    write_file('element-kb-map.xml', elementkb)
