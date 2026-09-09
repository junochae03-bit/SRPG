extends Control
const Art=preload("res://scripts/ui_art.gd")
var game
var records=[]
func setup(owner_game):
	game=owner_game;size=Vector2(1440,900);mouse_filter=Control.MOUSE_FILTER_IGNORE
	game.title_backdrop=Art.picture(get_parent(),load("res://assets/ui/title-storybook-v04.png"),-game.ui_offset(),Vector2(1600,900))
	game.title_backdrop.stretch_mode=TextureRect.STRETCH_SCALE;get_parent().move_child(game.title_backdrop,0)
	var title=game.label(self,"스텔알피지",Vector2(599,187),Vector2(694,114),79,Color("fff4ce"))
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_override("font",game.bold_font)
	title.add_theme_color_override("font_outline_color",Color("234e3f"));title.add_theme_constant_override("outline_size",10)
	title.add_theme_color_override("font_shadow_color",Color("143c3875"));title.add_theme_constant_override("shadow_offset_x",3);title.add_theme_constant_override("shadow_offset_y",6)
	var version=game.label(self,"V"+str(ProjectSettings.get_setting("application/config/version","0.5.0")),Vector2(1240,35),Vector2(113,22),14,Color("54452d"));version.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	game.name_input=LineEdit.new();game.name_input.text="모험가";game.name_input.hide();add_child(game.name_input)
	game.slot_picker=OptionButton.new();game.slot_picker.hide();add_child(game.slot_picker)
	for i in range(3):
		game.slot_picker.add_item("모험 기록 %d"%(i+1))
		var index=i
		var b=wood_button("빈 기록",Vector2(845+i*146,408),Vector2(140,68),func():game.slot_picker.select(index);game.refresh_slot_summary(),15)
		records.append(b)
	game.slot_picker.item_selected.connect(func(_i):game.refresh_slot_summary())
	game.slot_summary=game.label(self,"",Vector2(820,713),Vector2(490,36),19,Color("fff3d6"));game.slot_summary.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	game.slot_summary.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;game.slot_summary.clip_text=true
	game.slot_summary.add_theme_color_override("font_shadow_color",Color("402616"));game.slot_summary.add_theme_constant_override("shadow_offset_y",2)
	game.start_button=wood_button("모험 시작",Vector2(836,483),Vector2(467,62),game.begin_adventure,27)
	wood_button("키 설정",Vector2(836,551),Vector2(467,62),game.toggle_help,23)
	wood_button("종료",Vector2(836,619),Vector2(467,59),game.finish_run,23)
	game.menu_status=game.label(self,"",Vector2(760,761),Vector2(579,54),17,Color("fff1d4"));game.menu_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	game.menu_status.add_theme_color_override("font_outline_color",Color("284538"));game.menu_status.add_theme_constant_override("outline_size",4)
func wood_button(caption:String,at:Vector2,dimensions:Vector2,callback:Callable,font_size:int=22)->Button:
	var b=Button.new();b.text=caption;b.position=at;b.size=dimensions;b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font",game.serif);b.add_theme_font_size_override("font_size",font_size)
	b.add_theme_color_override("font_color",Color("fff3d6"));b.add_theme_color_override("font_hover_color",Color("fffdb2"));b.add_theme_color_override("font_pressed_color",Color("ffdc83"));b.add_theme_color_override("font_focus_color",Color("fffdb2"));b.add_theme_color_override("font_disabled_color",Color("b6aa90"))
	b.add_theme_color_override("font_outline_color",Color("513020"));b.add_theme_constant_override("outline_size",4)
	for state in ["normal","hover","pressed","disabled"]:b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var focus=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT;focus.border_color=Color("f6d88790");focus.set_border_width_all(1);focus.set_corner_radius_all(6);focus.content_margin_left=7;focus.content_margin_right=7
	b.add_theme_stylebox_override("focus",focus);b.pressed.connect(callback);add_child(b);return b
func refresh_records():
	for i in range(records.size()):
		var path=game.session.save_directory.path_join("slot-%d.json"%(i+1))
		var saved=game.session.parse_save(path)
		if saved==null:saved=game.session.parse_save(path+".bak")
		var prefix="◆ " if game.slot_picker.selected==i else ""
		if saved!=null:
			var name=str(saved.name);var wrapped=name if name.length()<=8 else name.substr(0,8)+"\n"+name.substr(8)
			records[i].text=prefix+"Lv.%d\n"%int(saved.level)+wrapped
			records[i].tooltip_text="Lv.%d · %s"%[int(saved.level),name]
		else:
			records[i].text=prefix+("읽을 수 없는 기록" if game.session.slot_state(i+1)=="damaged" else "빈 기록")
			records[i].tooltip_text=""
		var pixels=17;var font=records[i].get_theme_font("font");var lines=Array(records[i].text.split("\n"))
		while pixels>12 and (font.get_height(pixels)*lines.size()>records[i].size.y-4 or lines.any(func(line):return font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x>records[i].size.x-8)):
			pixels-=1
		records[i].add_theme_font_size_override("font_size",pixels)
