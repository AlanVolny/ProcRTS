

import Entities.Menu;
import openfl.display.Tilesheet;
import openfl.display.BitmapData;
import openfl.display.Bitmap;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.events.KeyboardEvent;
import openfl.Lib;
import openfl.display.FPS;
import openfl.Assets;
import openfl.text.TextFormat;

import GameMap.PR_Map;
import Entities.Unit;
import Entities.UnitBlueprint;
import Entities.UnitInfo;
import Entities.BuildQueue;

import GameMap.Tile;

import openfl.geom.Rectangle;

import ProcDraw.Drawer;

class State{
	public static var debug:Bool;
	public static var display_tracking:Bool;
	public static var map:PR_Map;
	public static var textform: TextFormat;

	public static var main;

	public var players:Array<Player>;
	public var entities:Array<Unit>; //array of arrays of all entities, order by bpID

	public var ent_ts: Array<UnitTilesheet>;
	public var background: Sprite;

	public var menu: Menu;
	public var info: UnitInfo;

	public var prev_time: Float;

	public var player: Player;

	public var mainView: Main;


	public function new(mainView:Main){

		main = this;
		this.mainView = mainView;

		//setup defaults/basics
		background = new Sprite();
		background.graphics.beginFill(0xC2C2C2);
		background.graphics.drawRect(0,0, 1920,1080);

		mainView.addChild(background);

		textform = new TextFormat('assets/Ubuntu-R', 14, 0xFFFFFFFF);

		debug = true;

		info = null;
		menu = null;
		cash_buf = 0;

		//setup map
		map = new PR_Map();
		background.addChild(map);
		map.max_range = 8;

		//setup entities
		entities = [];
		players = [];


		//fps display
		mainView.stage.allowsFullScreen = true; 
		mainView.stage.frameRate = 60;
		var fps = new openfl.display.FPS(0, 0, 0x3030C0);
		mainView.addChild(fps);

		ent_ts = [];

		//controls
		map.stage.addEventListener( openfl.events.MouseEvent.MOUSE_DOWN, map.on_click );
		map.stage.addEventListener( openfl.events.MouseEvent.MOUSE_UP,   map.on_unclick );

		map.stage.addEventListener( openfl.events.MouseEvent.RIGHT_CLICK , map.on_rightclick);

		mainView.stage.addEventListener( KeyboardEvent.KEY_UP,   key_up );
		mainView.stage.addEventListener( KeyboardEvent.KEY_DOWN, key_down );

		//init players
		players = [];
		player = new Player([0xFF142f09, 0xFF285e13], players.length);
		player.name = 'player';
		players.push(player);
		var AIplayer = new Player([0xFF7b0505, 0xFF2f0808], players.length);
		// var AIplayer = new Player([0xFF2f0808, 0xFF7b0505 ]);
		AIplayer.name = 'AI';
		players.push(AIplayer);

		//start mainViewloop
		prev_time = 0;
		map.addEventListener(MouseEvent.MOUSE_MOVE, map.update_mouseCoords);

		mainView.addEventListener(Event.ENTER_FRAME, map.enterFrame);
		mainView.addEventListener(Event.ENTER_FRAME, mainloop);

		start();
	}

	public function start(){


		var bp = player.bps[0];
		var newUnit = new Unit(bp, map.tdw*3.5, map.tdh*3.5);
		newUnit = new Unit(player.bps[1], map.tdw*4.5, map.tdh*3.5);
		newUnit = new Unit(player.bps[2], map.tdw*5.5, map.tdh*3.5);
		newUnit = new Unit(player.bps[3], map.tdw*6.5, map.tdh*3.5);
		newUnit = new Unit(player.bps[4], map.tdw*7.5, map.tdh*3.5);
		newUnit = new Unit(player.bps[5], map.tdw*8.5, map.tdh*3.5);

		//player production building
		var newBuilding = new Unit(player.bps[6], map.tdw*9.5, map.tdh*3.5);

		players[1].ai = new AI_brain(map.ref_spots, State.map.tile_at(newBuilding.x, newBuilding.y) );
		players[1].ai.new_facility();
		players[1].ai.new_facility();
		players[1].ai.new_facility();


		//start enemy units
		var atile = State.map.tile_at(newBuilding.x, newBuilding.y);
		newUnit = new Unit(players[1].bps[0], map.tdw*4.5, map.tdh*30.5);
		newUnit.goto_cmd(atile.tx, atile.ty, 5);
		newUnit = new Unit(players[1].bps[1], map.tdw*5.5, map.tdh*30.5);
		newUnit.goto_cmd(atile.tx, atile.ty, 5);
		newUnit = new Unit(players[1].bps[1], map.tdw*6.5, map.tdh*30.5);
		newUnit.goto_cmd(atile.tx, atile.ty, 5);
	}


	private var cash_buf:Float; //aethsetics
	public function mainloop(event:MouseEvent){
		var curtime = openfl.Lib.getTimer();
		var dt:Float = curtime - prev_time;
		for (e in entities){
			e.update(dt/30);
		}
		prev_time = curtime;

		//update entities tilesheet
		for (e_ts in ent_ts){
			e_ts.update();
		}

		for (p in players){
			if (p.ai!=null){
				p.ai.update(dt);
			}
			else {
				cash_buf += 20*(dt/1000); //40 cash per second
				if (cash_buf>50){
					p.resources += cash_buf - cash_buf%.1;
					cash_buf = 0;
				}
				if (menu!=null){
					menu.update_cash(p.resources);
				}
			}
		}

		if (!have_won)
			if (check_win()==true)
				trace('Congrats! You wiped out the enemy facilities!\nMore facilities shall be spawning shortly');

		map.x += dirx;
		map.y += diry;
	}


	public var have_won = false;
	public function check_win(){
		if (players[1].ai.facilities.length==0){
			have_won = true;
			return true;
		}
		return false;
	}


	public var dirx = 0;
	public var diry = 0;
	public function key_up(event:KeyboardEvent){
		if      (event.keyCode==87 || event.keyCode==38 || event.keyCode==83 || event.keyCode==40){ //w,s
			diry = 0;
		}
		else if (event.keyCode==65 || event.keyCode==37 || event.keyCode==68 || event.keyCode==39){ //a,d
			dirx = 0;
		}
	}

	public function key_down(event:KeyboardEvent){

		if      (event.keyCode==87 || event.keyCode==38){ //w
			diry = 6;
		}
		else if (event.keyCode==65 || event.keyCode==37){ //a
			dirx = 6;
		}
		else if (event.keyCode==83 || event.keyCode==40){ //s
			diry = -6;
		}
		else if (event.keyCode==68 || event.keyCode==39){ //d
			dirx = -6;
		}

		else if (event.keyCode==69){ //q
			map.scaleX/=2;
			map.scaleY/=2;
		}
		else if (event.keyCode==81){ //e
			map.scaleX*=2;
			map.scaleY*=2;
		}

		// else trace('unkown keycode',event.keyCode);
	}
}



class Player{
	public var name:String;
	public var colors:Array<UInt>;

	public var bps: Array<UnitBlueprint>;
	public var n_units: Int;
	public var pID: UInt;

	public var selected: Array<Unit>;

	public var resources: Float;

	public var ai: AI_brain;

	public function new(colors:Array<UInt>, pID:UInt){

		this.pID = pID;

		this.colors = colors;

		resources = 0;

		ai = null;

		//create unit blueprints;
		bps = [];

		// trace('genning player', pID);

		n_units = 6;
		for (i in 0...n_units){
			var newbp = new UnitBlueprint(this, pID);
			// newbp.genValues();
			newbp.alt_gen();
			newbp.bpID = State.main.ent_ts.length;

			// trace('bmp is', newbp.disp);

			//relevant tilesheet
			State.main.ent_ts.push( new UnitTilesheet(newbp.disp) );

			bps.push( newbp );
		}

		//production factory
		var newbp = new UnitBlueprint(this, pID);
		newbp.bpID = State.main.ent_ts.length;
		newbp.is_building = true;
		newbp.health = 1000;
		newbp.cost = 50000;
		newbp.vision = 3;
		newbp.name = 'Production facility';
		newbp.disp = Assets.getBitmapData ("assets/production.png", false);
		var color_trans = new openfl.geom.ColorTransform();
		color_trans.redMultiplier   = (colors[1]&0xFF0000)/0xFF0000;
		color_trans.greenMultiplier = (colors[1]&0x00FF00)/0x00FF00;
		color_trans.blueMultiplier  = (colors[1]&0x0000FF)/0x0000FF;
		newbp.disp.colorTransform( new Rectangle(0, 0, 64, 64), color_trans );
		State.main.ent_ts.push( new UnitTilesheet(newbp.disp) );
		bps.push( newbp );

		selected = [];
	};

	//unselect all selected units
	public function unselect(){
		remove_info();

		for (e in selected){

			//remove menu
			if (e.menu!=null){
				e.menu.remove();
				State.main.menu = null;
				State.main.mainView.removeChild(e.menu);
			}
		}

		selected = [];
	}

	public function remove_info(){		
		for (e in selected){
			if (e.unit_info!=null){
				State.main.mainView.removeChild(e.unit_info);
				e.unit_info = null;
				State.main.info = null; 
			}
		}

		if (State.main.info!=null){
			State.main.mainView.removeChild(State.main.info);
			State.main.info = null;
		}

	}

}



class AI_brain{

	public var known_refs:Array<Tile>;

	public var bands:Array<Unit_Band>;

	public var facilities: Array<Facility>;

	public var attack_tile: Tile;

	public var time_to_next_expansion: Float;

	public var difficulty: Float;

	public function new(refs, attack){
		known_refs = refs;//
		facilities = [];
		attack_tile = attack;

		difficulty = 0.5;

		time_to_next_expansion = .5 * 60*1000; //.5 minutes

		bands = [];
	}

	public function update(dt){

		for (b in bands)
			b.update();

		for (f in facilities){
			f.update(dt);
		}

		if (time_to_next_expansion<=0){
			new_facility();
			time_to_next_expansion = 2 * 60*1000; //2 minutes
		}
		else time_to_next_expansion -= dt;
	}

	//create a new facility to spawn enemies from
	public function new_facility(){
		//available facility locations
		var available = [];
		for (r in known_refs){
			if (r.occupying.length > 0){
				continue;
			}
			available.push(r);
		}

		if (available.length==0)
			return;

		var ref = available[ Random.int(0, available.length-1) ];
		var bp = State.main.players[1].bps[6];
		var building = new Unit(bp, (ref.tx+.5)*State.map.tdw, (ref.ty+.5)*State.map.tdh);
		var queue = new BuildQueue();
		var fac = new Facility(building, queue);
	}

}

class Unit_Band{
	public var is_offence: Bool;
	public var home_facility: Facility;

	public var units:Array<Unit>;


	public function new(is_offence, facility, units){
		// trace('new band of AI units');
		this.is_offence = is_offence;
		home_facility = facility;
		this.units = units;
	}

	public function update(){
		if (is_offence){
			for (u in units){
				if (u.actionStack.length==0){
					var to_tile = State.main.players[1].ai.attack_tile;
					u.goto_cmd(to_tile.tx, to_tile.ty, 5);
				}
			}
		}
		else{

			if (home_facility.is_dead){
				is_offence = true;
				return;
			}

			for (u in units){
				if (u.actionStack.length==0){
					var factile = State.map.tile_at( home_facility.building.x, home_facility.building.y ); 
					var to_tiles = [
						State.map.getTile(factile.tx-4, factile.ty-4),
						State.map.getTile(factile.tx+4, factile.ty-4),
						State.map.getTile(factile.tx+4, factile.ty+4),
						State.map.getTile(factile.tx-4, factile.ty+4)];

					for (t in to_tiles){
						if (t!=null && t.is_impassible==false)
							u.goto_cmd(t.tx, t.ty, 5);
					}
				}
			}
		}
	}

}


//enemy facility
class Facility{
	public var queue: BuildQueue;
	public var building: Unit;
	public var pID: UInt;
	public var preferred_units:Array<UInt>;

	public var defense_bands: Int;

	public var is_dead: Bool;

	public function new(building, queue){

		is_dead = false;
		defense_bands = 0;

		this.building = building;
		this.queue = queue;

		this.pID = building.bp.pID;

		State.main.players[1].ai.facilities.push(this);

		//choose three prefered units at random
		preferred_units = [];
		for (i in 0...3){
			preferred_units.push( Random.int(0, 5) );
		}
	}

	public function update(dt:Float){

		//if we died
		if (building.dead){
			is_dead=true;
			death();
			return;
		}

		if (is_dead)
			return;

		//if we can create a new band
		if (queue.time_left<=0){
			new_unit_band();
		}
	}

	public function death(){
		is_dead=true;
		State.main.players[1].ai.facilities.remove(this);
		State.main.players[1].ai.difficulty += 1;

		for (fac in State.main.players[1].ai.facilities)
			fac.queue.time_left /= 4;
	}

	public function new_unit_band(){
		var n_new = Random.int(4,5) + Math.floor(State.main.players[1].ai.difficulty)*2;
		var units = [];

		//get a new band of units populated by units this facility prefers
		for (i in 0...n_new){
			var bp = State.main.players[1].bps[ preferred_units[ Random.int(0,preferred_units.length-1) ] ];
			queue.time_left += Math.min( 50, bp.buildtime - State.main.players[1].ai.difficulty*8);
			var unit = queue.create_unit(bp, building.x, building.y);
			units.push(unit);
		}

		var offence;
		//if we've created less defences than difficulty dictates, focus on defense, else focus offense
		if (defense_bands==0) 
			offence = false;
		else if (defense_bands>2*State.main.players[1].ai.difficulty)
			offence = (Random.int(0,3)==0)? true : false; 
		else
			offence = (Random.int(0,3)<=2)? true : false;

		if (offence==false)
			defense_bands += 1;

		var band = new Unit_Band( offence, this, units );
		State.main.players[1].ai.bands.push(band);
	}

}


class UnitTilesheet extends Sprite{
	public var entities:Array<Unit>;
	public var ts: Tilesheet;

	public function new(bmp:BitmapData){
		super();
		entities = [];
		ts = new Tilesheet(bmp);
		ts.addTileRect( new Rectangle(0, 0, State.map.tdw, State.map.tdh) );
		State.map.addChild(this);
	}

	public function update(){
		graphics.clear();
		var drawList:Array<Float> = [];
		for (e in entities){
			// trace('ent at', e.x, e.y);
			// drawList.push(e.x);
			// drawList.push(e.y);
			var tile = State.map.tile_at(e.x, e.y);
			if (tile.units_cansee[0].length==0)
				continue;

			drawList.push(e.x - State.map.tdw/2);
			drawList.push(e.y - State.map.tdh/2);
			drawList.push(0);
		}

		ts.drawTiles( graphics, drawList, true );
	}
}

