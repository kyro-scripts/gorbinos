extends RefCounted
## Small engine test map (not part of the campaign).

const DATA := {
	"name": "TEST CHAMBER",
	"music": "village", "ambience": "amb_village", "sky": "sky_village",
	"fog": Color(0.75, 0.85, 0.55, 0.5), "fog_start": 20.0, "fog_end": 90.0,
	"start_angle": 0.0, "par": 60,
	"test_views": [[2, 7, -90, -5], [9, 11, 180, 0], [14, 6, -10, 0], [12, 3, -90, 0], [9, 7, -20, 0], [15, 14, 90, 0]],
	"wall": "v_brick", "side": "v_stonewall",
	"legend": {
		"#": {"wall": "v_brick"},
		"%": {"wall": "v_stonewall"},
		"&": {"wall": "v_timber"},
		".": {"floor": 0.0, "ceil": 8.0, "ftex": "v_grass", "ctex": "SKY", "light": 0.95},
		",": {"floor": 0.0, "ceil": 3.5, "ftex": "v_woodfloor", "ctex": "v_ceiling", "light": 0.55, "side": "v_timber", "upper": "v_plaster"},
		"1": {"like": ".", "floor": 0.5, "ftex": "v_cobble"},
		"2": {"like": ".", "floor": 1.0, "ftex": "v_cobble"},
		"3": {"like": ".", "floor": 1.5, "ftex": "v_cobble"},
		"4": {"like": ".", "floor": 2.0, "ftex": "v_cobble"},
		"D": {"door": "door_metal"},
		"(": {"door": "door_red", "key": "red"},
		"~": {"like": ".", "floor": -0.5, "liquid": "liq_sludge", "damage": 5, "light": 1.0},
		"S": {"door": "v_brick", "secret_door": true},
		"$": {"like": ",", "secret": true, "light": 0.8, "flicker": 2},
		"L": {"lift": true, "floor": 0.0, "top": 2.0, "ftex": "metal_floor", "side": "i_hazard"},
		"E": {"wall": "exit_panel", "use": "exit"},
		"!": {"wall": "switch_off", "use": "switch", "tag": 1},
		"=": {"door": "i_grate", "remote": true, "tag": 1},
	},
	"map": """
##################%%%%%%
#.........#,,,,,,,#$$$$%
#.@.......D,,g,,,,S$MV$%
#.........#,,,,,,,#$$$$%
#....x....#,,,,,,,%%%%%%
#.........####D####
#..1234...........#
#..1234....s......#
#.........~~~.....#
#....T....~~~..R..#
#.........~~~.....#
#..y..............#
#######(######L####
      #,,,,,,!4444#
      #,,2,,3#4444#
      #,,,,,,=44E4#
      #############
""",
}
