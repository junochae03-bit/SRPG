extends SceneTree
const Env=preload("res://scripts/expedition_environment.gd")
const Sim=preload("res://scripts/simulation.gd")
var checks=0
var failures=[]
var game
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures.append(label);push_error(label)
func capture(name):
 game._process(.1);game.hud.refresh();game.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png("res://../artifacts/"+name+".png")==OK,"actual rendered "+name)
func run():
 root.borderless=true;root.size=Vector2i(1920,1080)
 game=load("res://main.tscn").instantiate();game.options.mute=true
 game.options["save-dir"]=ProjectSettings.globalize_path("res://../runtime/environment-visual/"+str(Time.get_ticks_usec()))
 root.add_child(game);await process_frame;game.join_game()
 game.session.set_physics_process(false);game.set_physics_process(false);game.set_process(false)
 for id in ["echo","mist"]:
  var seed_value=1
  for value in range(1,100):
   if Env.select(value,12).id==id:seed_value=value;break
  var sim=Sim.new(seed_value,"cave",12);var p=sim.add_player(1,"별하")
  p.level=20;p.tutorial_done=true;p.highest_floor=12;sim.recalculate(p)
  for enemy in sim.enemies.values():enemy.hp=0
  var site=sim.map.exploration_sites.filter(func(s):return s.kind=="gather")[0];p.pos=site.pos
  game.session.sim=sim;game.session.refresh();game.on_entered();game.hud.refresh();game.exploration_panel._process(0.)
  await capture("expedition-environment-"+id)
  check(game.exploration_panel.visible and game.exploration_panel.first.text.contains("+%d"%(4+int(sim.map.environment.gather_bonus))),"actual button displays environmental reward")
  check(game.hud.region.text.contains(sim.map.environment.name),"active condition remains visible in region HUD")
  var label=game.hud.region
  check(label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x<=label.size.x,"condition HUD text fits")
  game.exploration_panel.first.pressed.emit();game.session.refresh()
  check(p.materials.get("ore",0)==4+int(sim.map.environment.gather_bonus),"actual UI collection matches announced amount")
 check(await game.audio_director.shutdown(),"audio drained")
 game.session.connected=false;game.queue_free();await process_frame;await process_frame
 print("EXPEDITION_ENVIRONMENT_VISUAL checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
