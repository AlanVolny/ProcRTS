

import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.display.Tilesheet;
import openfl.events.Event;
import openfl.events.MouseEvent;
import openfl.Lib;
import openfl.display.FPS;
import openfl.Assets;
import openfl.geom.Rectangle;

import Entities.Unit;
import Game.State;


class Tile {
	
	public var tx:Int; //tile x,y
	public var ty:Int;
	public var is_impassible:Bool;

	public var occupying:Array<Unit>;

	public var tile_ind: Int;

	public var units_cansee: Array<Array<Unit>>; //all units who can see this tile, sorted by player
	public var units_canhit: Array<Array<Unit>>; //array of all viewing units, sorted by player

	public function new(tilex, tiley){
		tx = tilex;
		ty = tiley;
		set_passible();
		units_canhit = [[],[]];
		units_cansee = [[],[]];
		occupying = [];
	}


	public function set_passible(){
		// tile_ind = (tx%3 + (tx*ty)%7)%3 + 1;
		tile_ind = (tx%3 + ty%7 + (tx+ty*tx)%5)%3 + 1;
		is_impassible = false;
	}

	public function set_impassible(){
		// trace('setting impassible');
		tile_ind = 0;
		is_impassible = true;
	}

	public function select(){
		// trace(tx, ty);

		for (e in occupying){
			if (e.bp.pID==0){
				State.main.player.selected.push(e);
			}
		}
	}
}



class PR_Map extends Sprite{
	public var tiles:Array<Tile>;
	public var tile_w:Int; //width, height in tiles
	public var tile_h:Int;

	public var tdw:Int; //tile display width
	public var tdh:Int; //tile display height

	public var mouse_x: Float;
	public var mouse_y: Float;
	public var map_mouse_x: Float;
	public var map_mouse_y: Float;

	public var max_range: UInt;

	public var tiles_ts: Tilesheet;

	public var selection_box: Sprite;

	public var place_building_mode: Bool;

	public var mouse_down:Bool;

	public var fog_ts: Tilesheet;
	public var fog_sprite: Sprite;

	public var ref_spots: Array<Tile>;

	public function new(){
		super();
		tdw = tdh = 32;
		tile_w  = 64;
		tile_h = 64;
		width = tdw*tile_w;
		height = tdh*tile_h;
		mouse_x = 0;
		mouse_y = 0;
		mouse_down = false;
		tiles = [];
		ref_spots = [];
		for (tn in 0...tile_w*tile_h){
			var tx:Int = tn%tile_w;
			var ty:Int = Math.floor(tn/tile_w);
			tiles.push(new Tile(tx,ty));
		}

		selection_box = new Sprite();
		addChild(selection_box);

		place_building_mode = false;


		//tiles
		var tile_bmp = new BitmapData( tdw*4, tdh, false, 0x000000 );
		tile_bmp.fillRect( new Rectangle(tdw,   0, tdw*2, tdh), 0xd9d9d9 );
		tile_bmp.fillRect( new Rectangle(tdw*2, 0, tdw*3, tdh), 0xc4c4c4 );
		tile_bmp.fillRect( new Rectangle(tdw*3, 0, tdw*4, tdh), 0xbababa );

		tiles_ts = new Tilesheet( tile_bmp );
		tiles_ts.addTileRect( new Rectangle(0,     0, tdw,   tdh) );
		tiles_ts.addTileRect( new Rectangle(tdw,   0, tdw*2, tdh) );
		tiles_ts.addTileRect( new Rectangle(tdw*2, 0, tdw*3, tdh) );
		tiles_ts.addTileRect( new Rectangle(tdw*3, 0, tdw*4, tdh) );


		//create fog of war
		var fog_bmp = new BitmapData( tdw, tdh, true, 0x80000000 );
		fog_ts = new Tilesheet(fog_bmp);
		fog_ts.addTileRect( new Rectangle(0, 0, tdw, tdh) );
		fog_sprite = new Sprite();
		addChild(fog_sprite);


		//load the map
		load_map('assets/map01');
	}

	//get tile at tile coords
	public function getTile(tilex:Int, tiley:Int){
		if (tilex<0 || tiley<0 || tilex>=tile_w || tiley>=tile_h)
			return null;
		return tiles[tiley*tile_w + tilex];
	}

	//get tile at display coords
	public function tile_at(dispx:Float, dispy:Float){
		var tilex = Math.floor(dispx/tdw);
		var tiley = Math.floor(dispy/tdh);
		return getTile(tilex, tiley);
	}


	public function load_map(mapfile:String){
		
		var map_contents = sys.io.File.getContent('assets/map01');

		//assumed is size 64x64
		tile_w = 64;
		tile_h = 64;

		var ind = 0;
		for (tiley in 0...tile_h){
			for (tilex in 0...tile_w){
				var tile = tiles[tiley*tile_w + tilex];

				if (map_contents.charAt(ind)=='#'){
					tile.set_impassible();
				}
				if (map_contents.charAt(ind)=='!'){
					ref_spots.push(tile);
				}
				ind += 2;
			}
			if (map_contents.charAt(ind)=='\n')
				ind += 1;
		}
	}

	var box_tilex:Int;
	var box_tiley:Int;
	var end_tilex:Int;
	var end_tiley:Int;

	public function getTileCoords(event:MouseEvent): Array<Int>{
		mouse_x = event.stageX;
		mouse_y = event.stageY;
		map_mouse_x = mouse_x - this.x;
		map_mouse_y = mouse_y - this.y;

		var tilex = Math.floor( (map_mouse_x / tdw) * (1/scaleX) );
		var tiley = Math.floor( (map_mouse_y / tdh) * (1/scaleY) );

		return [tilex, tiley];
	}

	public function update_mouseCoords(event:MouseEvent){
		mouse_x = event.stageX;
		mouse_y = event.stageY;

		if (mouse_down){
			map_mouse_x = mouse_x - this.x;
			map_mouse_y = mouse_y - this.y;

			end_tilex = Math.floor( (map_mouse_x / tdw) / scaleX )+1;
			end_tiley = Math.floor( (map_mouse_y / tdh) / scaleY )+1;


			selection_box.graphics.clear();

			selection_box.graphics.beginFill(0x57e836, 0.5);
			selection_box.graphics.drawRect(0, 0, (end_tilex-box_tilex)*tdw, (end_tiley-box_tiley)*tdh);
		}
	}

	//when you click a tile
	public function on_click(event:MouseEvent){


		var menu = State.main.menu;
		if (State.main.menu!=null 
			&& (event.stageX>=menu.x && event.stageX<menu.x+menu.w)
			&& (event.stageY>=menu.y && event.stageY<menu.y+menu.h)){
			return;
		}


		mouse_x = event.stageX;
		mouse_y = event.stageY;
		map_mouse_x = mouse_x - this.x;
		map_mouse_y = mouse_y - this.y;
		
		box_tilex = Math.floor( (map_mouse_x / tdw) / scaleX );
		box_tiley = Math.floor( (map_mouse_y / tdh) / scaleY );
		end_tilex = box_tilex+1;
		end_tiley = box_tiley+1;

		selection_box.x = box_tilex*tdw;
		selection_box.y = box_tiley*tdh;
		selection_box.graphics.clear();

		selection_box.graphics.beginFill(0x57e836, 0.5);		
		// selection_box.graphics.beginFill(0xa5c69d, 0.5);
		selection_box.graphics.drawRect(0, 0, tdw, tdh);

		mouse_down = true;
	}

	public function on_unclick(event:MouseEvent){
		mouse_down = false;

		var menu = State.main.menu;
		if (State.main.menu!=null 
			&& (event.stageX>=menu.x && event.stageX<menu.x+menu.w)
			&& (event.stageY>=menu.y && event.stageY<menu.y+menu.h)){
			return;
		}

		selection_box.graphics.clear();

		if (end_tilex < box_tilex){
			var tmp = end_tilex;
			end_tilex = box_tilex;
			box_tilex = tmp;
		}
		if (end_tiley < box_tiley){
			var tmp = end_tiley;
			end_tiley = box_tiley;
			box_tiley = tmp;
		}


		// trace('end, box', end_tilex, end_tiley, box_tilex, box_tiley);

		// //double click
		// if (box_tilex==end_tilex-1 && box_tiley==end_tiley-1){

		// 	trace('possible double click!');

		// 	var select_type:Entities.UnitBlueprint = null;

		// 	if (State.main.players[0].selected.length>0){
		// 		select_type = State.main.players[0].selected[0].bp;
		// 	}

		// 	//unselect previously selected
		// 	if (event.shiftKey==false){
		// 		State.main.players[0].unselect();
		// 	}

		// 	for (e in State.main.entities){
		// 		if (e.bp==select_type){
		// 			State.main.players[0].selected.push(e);
		// 		}
		// 	}

		// }
		// else {

		//unselect previously selected
		if (event.shiftKey==false){
			State.main.players[0].unselect();
		}
		//select all in selection box
		for (tx in box_tilex...end_tilex){
			for (ty in box_tiley...end_tiley){
				var tile = getTile(tx, ty);
				if (tile!=null)
					tile.select();
			}
		}

		//info box
		if (State.main.player.selected.length!=0){
			State.main.player.selected[0].select();
		}
	}

	public function on_rightclick(event:MouseEvent){
		var tilepos = getTileCoords(event);
		var tilex = tilepos[0];
		var tiley = tilepos[1];

		// trace('right click: coords', tilex, tiley);

		var tile = getTile(tilex, tiley);
		if (tile==null || tile.is_impassible){
			trace('Can\'t move there!');
			return;
		}

		for (e in State.main.player.selected){
			if (e.bp.is_building==true) continue;
			e.actionStack = [];
			e.goto_cmd(tilex, tiley, 2);
		}
	}

	public function enterFrame(e){

		graphics.clear ();

		var tile_drawlist:Array<Float> = [];
		var fog_drawlist: Array<Float> = [];

		for (tile in tiles){

 			var dispx = tdw*tile.tx;
 			var dispy = tdh*tile.ty;

			tile_drawlist.push(dispx);
			tile_drawlist.push(dispy);

			tile_drawlist.push(tile.tile_ind);

			if (tile.units_cansee[0].length==0){
				fog_drawlist.push(dispx);
				fog_drawlist.push(dispy);
				fog_drawlist.push(0);
			}
		}

		// trace('tile_drawlist is');
		
		tiles_ts.drawTiles(graphics, tile_drawlist);
		fog_ts.drawTiles(  graphics, fog_drawlist);
	}
}



