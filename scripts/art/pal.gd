# GENEROWANE przez tools/make_palette.py - nie edytować ręcznie.
class_name Pal
extends RefCounted
## Wspólna paleta 256 kolorów. Rampy: Pal.r("wood", 3) = 4. odcień od najciemniejszego.

const RAMPS := {
	"ink": [Color8(10, 7, 8), Color8(21, 16, 17), Color8(31, 25, 27), Color8(42, 34, 36)],
	"grey": [Color8(58, 58, 63), Color8(78, 77, 81), Color8(98, 96, 98), Color8(117, 116, 116), Color8(137, 135, 134), Color8(157, 154, 151), Color8(176, 174, 169), Color8(196, 193, 186), Color8(216, 212, 204)],
	"steel": [Color8(43, 48, 56), Color8(64, 70, 79), Color8(85, 92, 101), Color8(106, 114, 124), Color8(127, 136, 147), Color8(148, 158, 169), Color8(169, 180, 192)],
	"wood": [Color8(26, 16, 8), Color8(39, 26, 15), Color8(52, 37, 23), Color8(65, 47, 30), Color8(78, 57, 38), Color8(91, 68, 45), Color8(103, 78, 53), Color8(116, 89, 60), Color8(129, 99, 68), Color8(142, 109, 75), Color8(155, 120, 83), Color8(168, 130, 90)],
	"mud": [Color8(42, 32, 22), Color8(55, 44, 30), Color8(68, 55, 38), Color8(81, 67, 46), Color8(94, 78, 54), Color8(107, 90, 62)],
	"straw": [Color8(74, 58, 24), Color8(98, 80, 39), Color8(121, 103, 53), Color8(145, 125, 68), Color8(169, 147, 83), Color8(192, 170, 97), Color8(216, 192, 112)],
	"moss": [Color8(16, 24, 12), Color8(30, 39, 21), Color8(43, 54, 29), Color8(57, 69, 38), Color8(70, 84, 47), Color8(84, 100, 55), Color8(97, 115, 64), Color8(111, 130, 73), Color8(124, 145, 81), Color8(138, 160, 90)],
	"fog": [Color8(24, 36, 31), Color8(41, 56, 50), Color8(59, 77, 70), Color8(76, 97, 89), Color8(94, 118, 109), Color8(111, 138, 128)],
	"skin": [Color8(74, 42, 28), Color8(95, 61, 43), Color8(117, 80, 59), Color8(138, 99, 74), Color8(160, 119, 90), Color8(181, 138, 105), Color8(203, 157, 121), Color8(224, 176, 136)],
	"fur": [Color8(42, 28, 20), Color8(61, 43, 30), Color8(79, 58, 40), Color8(98, 73, 50), Color8(117, 88, 60), Color8(135, 103, 70), Color8(154, 118, 80)],
	"blood": [Color8(42, 5, 8), Color8(62, 10, 12), Color8(82, 15, 17), Color8(103, 19, 21), Color8(123, 24, 26), Color8(143, 29, 30), Color8(163, 34, 35), Color8(184, 38, 39), Color8(204, 43, 44), Color8(224, 48, 48)],
	"ember": [Color8(138, 15, 20), Color8(177, 45, 40), Color8(216, 76, 60), Color8(255, 106, 80)],
	"fire": [Color8(106, 26, 8), Color8(131, 56, 23), Color8(156, 87, 37), Color8(180, 117, 52), Color8(205, 147, 67), Color8(230, 178, 81), Color8(255, 208, 96)],
	"chaos": [Color8(26, 10, 42), Color8(47, 19, 65), Color8(68, 28, 88), Color8(88, 36, 110), Color8(109, 45, 133), Color8(130, 54, 156), Color8(150, 62, 178), Color8(171, 71, 201), Color8(192, 80, 224)],
	"glow": [Color8(96, 16, 64), Color8(149, 53, 107), Color8(202, 91, 149), Color8(255, 128, 192)],
	"dusk": [Color8(42, 26, 48), Color8(60, 38, 54), Color8(79, 51, 61), Color8(97, 63, 67), Color8(116, 76, 74), Color8(134, 88, 80), Color8(153, 101, 87), Color8(171, 113, 93), Color8(190, 126, 100), Color8(208, 138, 106)],
	"night": [Color8(20, 28, 44), Color8(37, 47, 66), Color8(54, 65, 88), Color8(71, 84, 110), Color8(88, 103, 132), Color8(105, 121, 154), Color8(122, 140, 176)],
	"bone": [Color8(122, 114, 96), Color8(152, 144, 124), Color8(181, 173, 152), Color8(210, 202, 180), Color8(240, 232, 208)],
	"gold": [Color8(90, 64, 16), Color8(131, 102, 30), Color8(172, 140, 44), Color8(214, 178, 58), Color8(255, 216, 72)],
	"white": [Color8(200, 192, 176), Color8(228, 224, 216), Color8(255, 255, 255)],
	"ivo": [Color8(156, 87, 72), Color8(9, 1, 6), Color8(76, 63, 51), Color8(199, 81, 60), Color8(75, 6, 7), Color8(120, 21, 20), Color8(64, 75, 87), Color8(79, 42, 37), Color8(168, 61, 47), Color8(147, 42, 32), Color8(6, 4, 6), Color8(94, 43, 36), Color8(169, 156, 151), Color8(91, 0, 1), Color8(174, 76, 80), Color8(58, 47, 38), Color8(139, 1, 5), Color8(103, 69, 54), Color8(31, 23, 15), Color8(6, 1, 0), Color8(97, 111, 122), Color8(91, 82, 69), Color8(164, 43, 43), Color8(106, 86, 67), Color8(10, 0, 0), Color8(51, 70, 81), Color8(67, 31, 18), Color8(120, 1, 4), Color8(190, 164, 153), Color8(130, 55, 52), Color8(198, 47, 29), Color8(165, 149, 134), Color8(173, 15, 21), Color8(34, 11, 5), Color8(59, 95, 123), Color8(202, 90, 86), Color8(62, 55, 43), Color8(63, 18, 19), Color8(126, 87, 108), Color8(137, 87, 74), Color8(197, 192, 187), Color8(41, 6, 10), Color8(114, 123, 131), Color8(5, 6, 15), Color8(93, 86, 80), Color8(66, 44, 33), Color8(23, 1, 6), Color8(14, 28, 17), Color8(202, 174, 159), Color8(185, 85, 39), Color8(42, 28, 17), Color8(210, 150, 112), Color8(131, 18, 30), Color8(8, 36, 22), Color8(20, 27, 39), Color8(104, 16, 14), Color8(142, 80, 44), Color8(213, 138, 139), Color8(198, 138, 127), Color8(50, 52, 51), Color8(23, 12, 8), Color8(157, 140, 124), Color8(35, 18, 5), Color8(0, 6, 5), Color8(151, 32, 41), Color8(37, 36, 35), Color8(13, 19, 29), Color8(115, 96, 79), Color8(26, 8, 9), Color8(76, 72, 62), Color8(196, 132, 130), Color8(184, 101, 104), Color8(20, 22, 23), Color8(215, 197, 185), Color8(217, 131, 72), Color8(250, 141, 119), Color8(165, 167, 172), Color8(200, 111, 76), Color8(92, 97, 94), Color8(35, 51, 62), Color8(54, 31, 19), Color8(166, 134, 115), Color8(48, 22, 15), Color8(43, 44, 38), Color8(76, 24, 19), Color8(166, 67, 70), Color8(149, 104, 82), Color8(150, 132, 116), Color8(1, 1, 6), Color8(0, 0, 0), Color8(85, 60, 46), Color8(25, 46, 66), Color8(2, 10, 6), Color8(185, 46, 52), Color8(152, 114, 104), Color8(142, 62, 54), Color8(12, 8, 0), Color8(182, 68, 64), Color8(24, 26, 20), Color8(86, 9, 9), Color8(83, 108, 124), Color8(189, 36, 37), Color8(181, 55, 51), Color8(243, 178, 124), Color8(47, 3, 3), Color8(4, 0, 0), Color8(104, 0, 2), Color8(23, 1, 1), Color8(0, 4, 0), Color8(151, 2, 11), Color8(162, 7, 13), Color8(33, 0, 0), Color8(66, 5, 6), Color8(55, 1, 1), Color8(175, 40, 43), Color8(166, 26, 42)],
}

static func r(ramp: String, i: int) -> Color:
	var a: Array = RAMPS[ramp]
	return a[clampi(i, 0, a.size() - 1)]

## t = 0..1 wzdłuż rampy
static func rt(ramp: String, t: float) -> Color:
	var a: Array = RAMPS[ramp]
	return a[clampi(int(round(t * (a.size() - 1))), 0, a.size() - 1)]
