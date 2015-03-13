

import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;

import openfl.text.TextField;
import openfl.text.TextFormat;

import openfl.events.MouseEvent;

import Game.State;
import Game.Player;
import GameMap.Tile;

import Random;



class Unit {
	public var bp: UnitBlueprint;

	public var actionStack: Array<UnitAction>;

	public var x:Float;
	public var y:Float;

	public var target: Unit;
	public var attack_sprite: Sprite;
	public var reload_time_left: Float;

	public var cur_health:Float;

	public var dead: Bool;

	public var visible: Bool;

	public function new(unit_bp:UnitBlueprint, xpos:Float, ypos:Float){

		// if (unit_bp.is_building==true){
		// 	trace('warning: do not instantiate building as a unit');
		// 	return;
		// }

		bp = unit_bp;
		x = xpos;
		y = ypos;
		actionStack = [];
		dead = false;
		target = null;
		unit_info = null;
		queue = null;
		cur_health = bp.health;

		attack_sprite = new Sprite();
		State.map.addChild(attack_sprite);

		//register to tile
		var tile = State.map.tile_at(x,y);
		tile.occupying.push(this);
		place(tile);

		//register it to tileset
		State.main.ent_ts[ bp.bpID ].entities.push(this);

		//register to main State
		State.main.entities.push(this);
	}

	public function die(){
		dead = true;
		State.main.entities.remove(this);
		State.main.ent_ts[ bp.bpID ].entities.remove(this);
		State.main.entities.remove(this);

		var curtile = State.map.tile_at(x, y);
		var tile;

		curtile.occupying.remove(this);
		
		//remove from canhit in all tiles around tile
		for (tx in Math.floor(curtile.tx-(bp.range-1))...Math.floor(curtile.tx+bp.range)){
			for (ty in Math.floor(curtile.ty-(bp.range-1))...Math.floor(curtile.ty+bp.range)){
				tile = State.map.getTile(tx,ty);
				if (tile==null) continue;

				//if out of hit range, remove
				tile.units_canhit[bp.pID].remove(this);
			}
		}

		//remove from cansee in all tiles around tile
		for (tx in Math.floor(curtile.tx-(bp.vision-1))...Math.floor(curtile.tx+bp.vision) ){
			for (ty in Math.floor(curtile.ty-(bp.vision-1))...Math.floor(curtile.ty+bp.vision) ){
				tile = State.map.getTile(tx,ty);
				if (tile==null) continue;

				tile.units_cansee[bp.pID].remove(this);
			}
		}

		if (unit_info!=null){
			State.main.mainView.removeChild(unit_info);
		}

		State.map.removeChild(attack_sprite);
	}

	//alert this unit to another's presence
	public function alert(other:Unit){
		if (target!=null) return;

		//start firing
		if ((this.bp.repair == false && other.bp.pID != this.bp.pID) || 
			(this.bp.repair == true && other.cur_health<other.bp.health && other.bp.pID==this.bp.pID)){
			// trace('got new target! repair is', this.bp.repair );
			target = other;
		}
	}

	public function update(dt:Float){

		var curtile = State.map.tile_at(x,y);

		//if target has expired (dead, out of range, out of vision)
		if (target!=null && 
				(target.dead==true || 
				Math.abs(x - target.x)>(bp.range)*State.map.tdw || 
				Math.abs(y - target.y)>(bp.range)*State.map.tdh || 
				State.map.tile_at(target.x, target.y).units_cansee[bp.pID].length==0) ){

			// trace('bad target!');
			// if (target.dead==true)
			// 	trace('is dead');
			// if (Math.abs(x - target.x)>(bp.range-1)*State.map.tdw || 
			// 	Math.abs(y - target.y)>(bp.range-1)*State.map.tdh )
			// 	trace('out of range');
			// if (State.map.tile_at(target.x, target.y).units_cansee[bp.pID].length==0)
			// 	trace('no vision!');

			target = null;
			scan_for_target(curtile);
		}

		if (reload_time_left>0){
			reload_time_left = Math.max(0, reload_time_left - dt);
			if (reload_time_left <= bp.ms_per_fire/2){
				// trace('cleaning chemtrails, bp.ms_per_fire/2, dt is', bp.ms_per_fire/2, dt);
				attack_sprite.graphics.clear();
			}
			// else trace('time left:', reload_time_left);
		}
		//fire upon targeted unit
		else if (target!=null){
			// trace('firing! reload time is', reload_time_left);
			attack_sprite.x = this.x;
			attack_sprite.y = this.y;

			var colorbg;
			var colorfg;

			if (bp.repair==true){
				colorfg = 0xFF0108a2;
				colorbg = 0xFF43dde3;
			}
			else {
				colorfg = bp.color1;
				colorbg = bp.color2;
			}

			//draw the attack
			attack_sprite.graphics.clear();
			attack_sprite.graphics.lineStyle(7, colorbg, 0.5);
			attack_sprite.graphics.moveTo(0,0);
			attack_sprite.graphics.lineTo(target.x-x, target.y-y);

			attack_sprite.graphics.lineStyle(3, colorfg, 0.9);
			attack_sprite.graphics.moveTo(0,0);
			attack_sprite.graphics.lineTo(target.x-x, target.y-y);

			//damage (or rep) the target
			if (bp.repair==true){
				colorfg = 0xFF0108a2;
				colorbg = 0xFF43dde3;

				var healing = target.cur_health+bp.damage;
				target.cur_health = Math.min(target.bp.health, healing);
				// trace('healed', target.cur_health, 'health, now has', target.cur_health);
				if (target.cur_health==target.bp.health){
					target = null;
					scan_for_target(curtile);
				}
			}
			else {
				colorfg = bp.color1;
				colorbg = bp.color2;

				var adj_damage = bp.damage;
				if (target.bp.armor>0){
					adj_damage -= bp.armor_damge_mult*target.bp.armor;
				}
				adj_damage = Math.max(1, adj_damage);
				target.cur_health -= adj_damage;
				// trace('did', adj_damage, 'damage; ', target.cur_health, 'health left');
				if (target.cur_health<=0)
					target.die();
				//alert any possible enemy nearby healers
				var target_tile = State.map.tile_at(target.x, target.y);
				for (u in target_tile.units_canhit[target.bp.pID]){
					if (u.bp.repair==true)
						u.alert(target);
				}
			}

			reload_time_left = bp.ms_per_fire;
		}

		if (unit_info!=null){
			unit_info.updateHP(cur_health);
		}
		if (queue!=null){
			queue.update(dt, x, y);
		}

		
		//update actions
		if (actionStack.length == 0)
			return;

		var curAct = actionStack[ actionStack.length-1 ];

		if (curAct.type=='goto'){
			var speed = dt * bp.speed;

			var xdist = curAct.x - this.x;
			var ydist = curAct.y - this.y;
			var tdist = Math.sqrt(xdist*xdist + ydist*ydist);

			if (tdist < curAct.minDist){
				actionStack.pop();
				return;
			}

			var xspeed = speed * (xdist/tdist);
			var yspeed = speed * (ydist/tdist);


			var nexttile = State.map.tile_at(x+xspeed, y+yspeed);
			if (nexttile!=curtile){

				var dir:UInt = -1;
				if (nexttile.ty > curtile.ty)      dir = 0;
				else if (nexttile.tx > curtile.tx) dir = 1;
				else if (nexttile.tx < curtile.tx) dir = 2;
				else if (nexttile.ty < curtile.ty) dir = 3;

				if (nexttile.occupying.length!=0){
					for (i in nexttile.occupying){
						if (i.bp.is_building==false && bp.pID==i.bp.pID)
							i.moveaway_cmd( dir );
						else moveaway_cmd( dir );
					}
				}

				tile_update(curtile, nexttile);

				curtile.occupying.remove(this);
				nexttile.occupying.push(this);
			}

			x += xspeed;
			y += yspeed;
		}
	}

	public function scan_for_target(curtile: Tile){
		//scan for new, visible targets in hitrange
		for (tx in curtile.tx-(bp.range-1)...curtile.tx+bp.range){
			for (ty in curtile.ty-(bp.range-1)...curtile.ty+bp.range){
				var tile = State.map.getTile(tx,ty);
				if (tile==null) 
					continue;

				for (unit in tile.occupying){
					if (tile.units_cansee[bp.pID].length>0){
						this.alert(unit);
					}
				}
				if (target!=null) break;
			}
			if (target!=null) break;
		}	
	}

	//only for unit creation
	//place unit on tile
	public function place(newtile:Tile){
		var tile;
		//add to cansee to all tiles around new tile
		for (tx in Math.floor(newtile.tx-(bp.vision-1))...Math.floor(newtile.tx+bp.vision) ){
			for (ty in Math.floor(newtile.ty-(bp.vision-1))...Math.floor(newtile.ty+bp.vision) ){
				tile = State.map.getTile(tx,ty);
				if (tile==null) continue;

				tile.units_cansee[bp.pID].push(this);
			}
		}

		//add to canhit to all tiles around new tile
		for (tx in Math.floor(newtile.tx-(bp.range-1))...Math.floor(newtile.tx+bp.range)){
			for (ty in Math.floor(newtile.ty-(bp.range-1))...Math.floor(newtile.ty+bp.range)){
				tile = State.map.getTile(tx,ty);
				if (tile==null) continue;

				tile.units_canhit[bp.pID].push(this);
			}
		}

	}

	//update vision, hit range to new tile
	public function tile_update(old_tile:Tile, new_tile:Tile){
		
		var tile:Tile;
		var pID = bp.pID;

		//if enemy unit (or friendly rep) can fire on newtile, alert said unit
		for (unit_arr in new_tile.units_canhit){
			for (unit in unit_arr){
				if (new_tile.units_cansee[unit.bp.pID].length!=0){ //if unit has vision here
					if (unit.bp.pID!=bp.pID)
					unit.alert(this);
				}
			}
		}


		//remove from cansee in all tiles around old tile
		for (tx in Math.floor(old_tile.tx-(bp.vision-1))...Math.floor(old_tile.tx+bp.vision) ){
			for (ty in Math.floor(old_tile.ty-(bp.vision-1))...Math.floor(old_tile.ty+bp.vision) ){
				tile = State.map.getTile(tx,ty);
				if (tile==null) continue;

				//if out of vision range, remove
				if (Math.abs(tx - new_tile.tx) >= bp.vision || Math.abs(ty - new_tile.ty) >= bp.vision)
					tile.units_cansee[pID].remove(this);
			}
		}

		//add to cansee to all tiles around new tile
		for (tx in Math.floor(new_tile.tx-(bp.vision-1))...Math.floor(new_tile.tx+bp.vision) ){
			for (ty in Math.floor(new_tile.ty-(bp.vision-1))...Math.floor(new_tile.ty+bp.vision)){
				tile = State.map.getTile(tx,ty);
				if (tile==null) continue;

				//if out of range of old tile, add
				if (Math.abs(tx - old_tile.tx) >= bp.vision || Math.abs(ty - old_tile.ty) >= bp.vision){
					// trace('adding tile to vision');
					tile.units_cansee[pID].push(this);
				}
			}
		}

		//add to canhit to all tiles around new tile
		for (tx in Math.floor(new_tile.tx-(bp.range-1))...Math.floor(new_tile.tx+bp.range) ){
			for (ty in Math.floor(new_tile.ty-(bp.range-1))...Math.floor(new_tile.ty+bp.range)){
				tile = State.map.getTile(tx,ty);
				if (tile==null) continue;

				//if out of hit range of old tile, add
				if (Math.abs(tx - new_tile.tx) >= bp.range || Math.abs(ty - new_tile.ty) >= bp.range)
					tile.units_canhit[pID].push(this);

				//if tile has units and is visible
				for (unit in tile.occupying){
					if (tile.units_cansee[bp.pID].length>0)
						this.alert(unit);
				}
			}
		}



		//remove from canhit in all tiles around old tile
		for (tx in Math.floor(old_tile.tx-(bp.range-1))...Math.floor(old_tile.tx+bp.range)){
			for (ty in Math.floor(old_tile.ty-(bp.range-1))...Math.floor(old_tile.ty+bp.range)){
				tile = State.map.getTile(tx,ty);
				if (tile==null) continue;

				//if out of hit range, remove
				if (Math.abs(tx - new_tile.tx) >= bp.range || Math.abs(ty - new_tile.ty) >= bp.range)
					tile.units_canhit[pID].remove(this);
			}
		}

	}

	//receive a 'move' command, for 'move out of the way'
	//dir is (0:from above, 1:from left, 2:from right, 3:from below)
	public function moveaway_cmd(dir:UInt){
		var possible_tiles:Array<Tile> = [];


		var tilex = Math.floor( x / State.map.tdw );
		var tiley = Math.floor( y / State.map.tdh );

		if (dir!=0) possible_tiles.push( State.map.getTile( tilex,   tiley-1 ) );
		if (dir!=1) possible_tiles.push( State.map.getTile( tilex-1, tiley   ) );
		if (dir!=2) possible_tiles.push( State.map.getTile( tilex+1, tiley   ) );
		if (dir!=3) possible_tiles.push( State.map.getTile( tilex,   tiley+1 ) );

		//if already has a goto, make sure best are chosen first
		//NOTE: not sure this actually works properly
		if (actionStack.length>0 && actionStack[actionStack.length-1].type=='goto'){
			var act = actionStack[actionStack.length-1];
			var to_tx = Math.floor(act.x/State.map.tdw);
			var to_ty = Math.floor(act.y/State.map.tdh);

			var cur_tdistx = Math.abs( Math.floor(x/State.map.tdw) - to_tx);
			var cur_tdisty = Math.abs( Math.floor(y/State.map.tdh) - to_ty);

			var closer_arr = [];
			var further_arr = [];

			for (t in possible_tiles){
				var t_distx = Math.abs( t.tx - to_tx);
				var t_disty = Math.abs( t.ty - to_ty);
				if (t_distx < cur_tdistx || t_disty < cur_tdisty){
					// trace('pushing closer', t_distx, cur_tdistx, t_disty, cur_tdisty );
					closer_arr.push(t);
				}
				else{
					// trace('pushing farther');
					further_arr.push(t);
				}
			}

			for (t in further_arr){
				closer_arr.push(t);
			}
			possible_tiles = closer_arr;
		}
		else {
			Random.shuffle(possible_tiles);
		}		
		//if we have 'goto' command, don't bother

		//first, check if any are empty, if so, go there
		for (tile in possible_tiles){

			if (tile!=null && tile.is_impassible==false && tile.occupying.length==0){
				// trace('found empty tile to go to!');
				goto_cmd(tile.tx, tile.ty, 2);
				return;
			}
		}

		// trace('no passable, non-occupied tile found, moving to any other one');

		for (tile in possible_tiles){

			if (tile==null || tile.is_impassible){
				continue;
			}
			else {
				goto_cmd( tile.tx, tile.ty, 2 );
				return;
			}
		}

		trace('could find no place to run! Euh oh!');
		return;
	}

	//received a goto command
	public function goto_cmd(to_tilex:Int, to_tiley:Int, minDist, ?from_tilex:Int, ?from_tiley:Int){

		var cur_tilex:Float;
		var cur_tiley:Float;

		if (from_tilex!=null)
			cur_tilex = from_tilex;
		else cur_tilex = Math.floor( x/State.map.tdw );
		if (from_tiley!=null)
			cur_tiley = from_tiley;
		else cur_tiley = Math.floor( y/State.map.tdh );
		// trace('\n\ngot new goto, to', to_tilex, to_tiley, 'from', cur_tilex, cur_tiley);

		if (to_tilex==cur_tilex && to_tiley==cur_tiley){
			return;
		}

		var distx:Float = to_tilex - cur_tilex;
		var disty:Float = to_tiley - cur_tiley;
		var distt:Float = Math.sqrt(distx*distx + disty*disty);

		var was_blocked:Bool = false;


		var checkx = cur_tilex;
		var checky = cur_tiley;

		//check whether path is unblocked (note, not entirely accurate)
		if (Math.abs(disty) > Math.abs(distx)){
			var x_it:Float = distx/Math.abs(disty);
			var y_it:Float = (disty>0)?1:-1;

			if (x_it>0) checkx += 0.5;

			// trace('its are', x_it, y_it);


			while (checky!=to_tiley){

				if (Math.floor((checkx+x_it*.9999999))!=Math.floor(checkx) ){
					// trace('checking', checkx+x_it, checky);
					var tile = State.map.getTile( Math.floor(checkx+x_it), Math.floor(checky) );
					if (tile.is_impassible){
						checkx += x_it;
						was_blocked = true;
						break;
					}
				}
				checkx += x_it;
				checky += y_it;

				// trace('checking', checkx, checky);

				//if tile is impassible
				var tile = State.map.getTile( Math.floor(checkx), Math.floor(checky) );
				if (tile.is_impassible){
					was_blocked = true;
					break;
				}
			}
		}
		else {
			var x_it:Float = (distx>0)?1:-1;
			var y_it:Float = disty/Math.abs(distx);

			// trace('its are', x_it, y_it);

			while (checkx!=to_tilex){

				if (Math.floor((checky+y_it*.9999999))!=Math.floor(checky) ){
					// trace('checking specially', checkx, checky+y_it, Math.floor(checkx), Math.floor(checky+y_it) );
					var tile = State.map.getTile( Math.floor(checkx), Math.floor(checky+y_it) );
					if (tile.is_impassible){
						checky += y_it;
						was_blocked = true;
						break;
					}
				}
				checky += y_it;
				checkx += x_it;

				// trace('checking', checkx, checky);

				//if tile is impassible
				var tile = State.map.getTile( Math.floor(checkx), Math.floor(checky) );
				if (tile.is_impassible){
					was_blocked = true;
					break;
				}
			}
		}

		if (was_blocked==false){

			var newAct = new UnitAction('goto');
			newAct.x = (to_tilex+.5)*State.map.tdw;
			newAct.y = (to_tiley+.5)*State.map.tdh;
			newAct.minDist = minDist;
			actionStack.push(newAct);
		}

		else {
			// trace('found obstacle tile, going to route around, at', checkx, checky);

			var tilepos:Array<Int> = get_route_around( 
				Math.floor(cur_tilex), Math.floor(cur_tiley), 
				Math.floor(checkx), Math.floor(checky),
				Math.floor(to_tilex), Math.floor(to_tiley) );

			var mid_x = tilepos[0];
			var mid_y = tilepos[1];

			// trace('going from',cur_tilex, cur_tiley, 'to', mid_x, mid_y, 'to', to_tilex, to_tiley);

			goto_cmd(to_tilex, to_tiley, minDist, mid_x, mid_y);
			// trace('second goto:');
			goto_cmd(tilepos[0], tilepos[1], minDist, Math.floor(cur_tilex), Math.floor(cur_tiley));
		}
	}

	private function get_route_around(orig_x, orig_y, obs_x, obs_y, dest_x, dest_y):Array<Int>{

		var tpos1 = [];
		var tpos2 = [];

		var dirx = (dest_x>=orig_x)? 1 : -1;
		var diry = (dest_y>=orig_y)? 1 : -1;

		if ((dirx==1 && diry==1) || (dirx==-1 && diry==-1)) {
			tpos1 = get_go_around(Math.floor(obs_x), Math.floor(obs_y), 1);
			tpos2 = get_go_around(Math.floor(obs_x), Math.floor(obs_y), 2);
		}
		else {
			tpos1 = get_go_around(Math.floor(obs_x), Math.floor(obs_y), 0);
			tpos2 = get_go_around(Math.floor(obs_x), Math.floor(obs_y), 3);
		}

		// trace('got routes', tpos1, tpos2);
		// trace('squared distances', tp1_dist2, tp2_dist2);


		var tilepos=[-1];


		if (tpos1[0]==-1){
			tilepos = tpos2;
		}
		else if (tpos2[0]==-1){
			tilepos = tpos1;
		}
		else {

			var tp1_dist = 
				Math.sqrt((tpos1[0]-orig_x)*(tpos1[0]-orig_x) + (tpos1[1]-orig_y)*(tpos1[1]-orig_y)) + 
				Math.sqrt((tpos1[0]-dest_x)*(tpos1[0]-dest_x) + (tpos1[1]-dest_y)*(tpos1[1]-dest_y));
			var tp2_dist = 
				Math.sqrt((tpos2[0]-orig_x)*(tpos2[0]-orig_x) + (tpos2[1]-orig_y)*(tpos2[1]-orig_y)) + 
				Math.sqrt((tpos2[0]-dest_x)*(tpos2[0]-dest_x) + (tpos2[1]-dest_y)*(tpos2[1]-dest_y));


			if (tp1_dist < tp2_dist)
				tilepos = tpos1;
			else
				tilepos = tpos2;
		}

		return tilepos;
	}

	//Gets place to go around that's not obstructed by obstruction at tilex,tiley,
	///	checks in direction dir. Returns place x,y
	//dir:
	//  0   1
	//   \ /
	//    X
	//   / \
	//  2   3
	private function get_go_around(tilex:Int, tiley:Int, dir:UInt):Array<Int>{
		var xdir = (dir==1||dir==3)? 1 : -1;
		var ydir = (dir==2||dir==3)? 1 : -1;

		// trace('go around; dir, x,y dir is', dir, xdir, ydir);

		while (true){
			var tile; 

			tile = State.map.getTile(tilex+xdir, tiley+ydir);
			if (tile==null) return [-1, -1];
			if (tile.is_impassible){
				tilex += xdir;
				tiley += ydir;
				continue;
			}

			tile = State.map.getTile(tilex+xdir, tiley);
			if (tile==null) return [-1, -1];
			if (tile.is_impassible){
				tilex += xdir;
				continue;
			}

			tile = State.map.getTile(tilex, tiley+ydir);
			if (tile==null) return [-1, -1];
			if (tile.is_impassible){
				tiley += ydir;
				continue;
			}

			tilex += xdir;
			tiley += ydir;
			// trace('\tgo around returning', tilex, tiley);
			return [tilex, tiley];
		}
	}




	public var unit_info: UnitInfo;
	public var queue: BuildQueue;
	public var menu: Menu;

	//to show unit info and shutff
	public function select(){

		// trace('selected');

		if (queue == null){
			queue = new BuildQueue();
		}

		//create menu, production queue
		unit_info = new UnitInfo(bp);

		unit_info.x = 0;
		unit_info.y = 0;

		State.main.mainView.addChild(unit_info);

		if (this.bp.is_building==true && this.bp.name=='Production facility'){
			menu = new Menu(0, queue);
			menu.x = unit_info.w+4;
			menu.y = 0;
			State.main.mainView.addChild(menu);
		}

	}

	public function unselect(){
		if (unit_info!=null){
			State.main.mainView.removeChild(unit_info);
			unit_info = null;
		}
		if (menu!=null){
			State.main.mainView.removeChild(unit_info);
			menu = null;
		}
	}

}


class BuildQueue {
	public var building:Array<UnitBlueprint>;
	public var time_left: Float;

	public function new(){
		building = [];
		time_left = 0;
	}

	public function add_to_queue(unitbp:UnitBlueprint){
		// trace('added unit', unitbp.name, 'to build queue!');
		building.push(unitbp);
	}

	public function update(dt, curx:Float, cury:Float){
		//for now, units will be instant

		if (building.length>0){
			var tobuild = building[0];
			var cash = State.main.players[tobuild.pID].resources;
			if (building[0].cost > cash){
				trace('No cash!');
				// State.main.menu.update_cash()
				building = [];
				return;
			}
			State.main.players[tobuild.pID].resources -= building[0].cost;
			create_unit(tobuild, curx, cury);
			building = [];
		}
	}

	//place unit in nearest available location
	public function create_unit(bp, curx:Float, cury:Float): Unit{

		// trace('placing unit');

		var look_dist = 1;

		var tx:Int = Math.floor(curx / State.map.tdw);
		var ty:Int = Math.floor(cury / State.map.tdh);

		var out = null;

		var placed=false;
		while (placed==false){
			for (look_tx in tx-look_dist...tx+look_dist+1){
				for (look_ty in ty-look_dist...ty+look_dist+1){
					var tile = State.map.getTile(look_tx, look_ty);
					if (tile==null || tile.is_impassible || tile.occupying.length>0)
						continue;

					out = new Unit(bp, (look_tx+.5)*State.map.tdw, (look_ty+.5)*State.map.tdh);
					placed = true;
					break;
				}
				if (placed==true) break;
			}
			look_dist += 1;
		}

		return out;
	}
}

class UnitAction {
	public var type:String;
	public var x:Float;  //in disp units
	public var y:Float;
	public var minDist:Int; //min distance to accomplish goal
	public function new(act_type:String){
		type = act_type;
	}
}

class Menu extends Sprite {

	public var pID: UInt;
	public var w:Int;
	public var h:Int;
	public var cash_w: Float;
	public var cash_h: Float;

	public var buttons: Array<Sprite>;
	public var queue: BuildQueue;
	public var cash: TextField;

	public function new(pID, queue){
		this.pID = pID;
		this.queue = queue;
		buttons = [];

		super();

		var cury = 4;
		var curx = 4;

		State.main.menu = this;

		w = 32*6+8*5+4*2;
		h = 32+4*2;
		graphics.beginFill(0xFFFFFF, 0.8);
		graphics.drawRect(0, 0, w, h);

		//create buttons
		for (b in 0...State.main.players[0].n_units){
			var bp = State.main.players[0].bps[b];
			var newbox = new Sprite();
			newbox.graphics.lineStyle(2, 0x000000);
			newbox.graphics.drawRect(0, 0, 32, 32);
			newbox.graphics.beginFill(0x000000, 0.3);
			newbox.graphics.drawRect(0, 0, 32, 32);
			newbox.addChild( new Bitmap(bp.disp) );
			newbox.x = curx;
			newbox.y = cury;

			buttons.push(newbox);
			this.addChild(newbox);

			curx += 32+8;
		}


		cash_w = 30;
		cash_h = 16+4*2;

		graphics.beginFill(State.main.players[0].colors[0], 0.8);
		graphics.drawRect(w, 0, w+cash_w, cash_h);

		cash = new TextField();
		cash.selectable = false;
		cash.defaultTextFormat = State.textform;
		cash.width = 100;
		cash.text = '$' + ' ';

		cash.x = w+4;
		cash.y = 4;
		addChild(cash);


		addEventListener(MouseEvent.MOUSE_OVER, mouseover);
		addEventListener(MouseEvent.MOUSE_UP,  mouseclick);

	}

	public function update_cash(resources:Float){
		cash.text = '$ '+ Std.string(resources - resources%.1);
	}

	public function remove(){
		State.main.mainView.removeChild(this);
		removeEventListener(MouseEvent.MOUSE_OVER, mouseclick);
		removeEventListener(MouseEvent.MOUSE_UP, mouseover);
	}

	public function mouseclick(event:MouseEvent){
		var boxy = 4;
		var boxx = 4;
		var mouse_x = event.stageX - x;
		var mouse_y = event.stageY - y;
		for (b in 0...State.main.players[0].n_units){
			//if over a box
			if (mouse_x>=boxx && mouse_x<=boxx+32 && mouse_y>=boxy && mouse_y<=boxy+32){

				//add to build queue!
				queue.add_to_queue(State.main.players[0].bps[b]);
			}
			boxx += 32 + 8;
		}
	}

	public function mouseover(event:MouseEvent){
		var boxy = 4;
		var boxx = 4;
		var mouse_x = event.stageX - x;
		var mouse_y = event.stageY - y;
		for (b in 0...State.main.players[0].n_units){
			//if moused over a box
			if (mouse_x>=boxx && mouse_x<=boxx+32 && mouse_y>=boxy && mouse_y<=boxy+32){
				//remove old info box, if any
				State.main.players[0].remove_info();

				State.main.info = new UnitInfo( State.main.players[0].bps[b] );
				State.main.info.updateCost( State.main.players[0].bps[b].cost );

				State.main.mainView.addChild( State.main.info );

			}
			boxx += 32 + 8;
		}
	}


}



class UnitInfo extends Sprite {
	public var text_fields: Array<TextField>;

	private var bp:UnitBlueprint;

	public var w:Int;
	public var h:Int;

	public var nametxt:TextField;
	public var special:TextField;
	public var health: TextField;
	public var armor:  TextField;
	public var vision: TextField;
	public var speed:  TextField;
	public var damage: TextField;
	public var fire_rate:TextField;
	public var range:  TextField;
	public var aoe:    TextField;

	public function new(bp:UnitBlueprint){
		super();
		w = 200;
		h = 140;
		this.bp = bp;
		draw();
		State.main.info = this;
	}

	public function updateHP(hp:Float){
		// + ' (HP: ' + Std.string(bp.cost) + ')';
		nametxt.text = bp.name + '  (HP: '+Std.string(hp - hp%1) + ' )';
	}

	public function updateCost(cost:Float){
		// + ' (HP: ' + Std.string(bp.cost) + ')';
		nametxt.text = bp.name + '  (Cost: '+Std.string(cost) + ' )';
	}


	//draw the info box
	public function draw(){
		graphics.clear();

		graphics.beginFill(0x808080, .5);
		graphics.drawRect(0, 0, w, h);
		graphics.lineStyle(5, 0x000000);
		graphics.drawRect(0, 0, w, h);

		graphics.lineStyle(3, 0x000000);

		var textheight = 16;
		var divider = 8;
		var column_size = 160;

		nametxt = new TextField();
		nametxt.selectable = false;
		nametxt.width = 200;
		nametxt.defaultTextFormat = State.textform;
		nametxt.x = 4; nametxt.y = 4;
		nametxt.text = bp.name; // + ' (cost: ' + Std.string(bp.cost) + ')';

		nametxt.text = bp.name;// + ' (HP: ' + Std.string(bp.cost) + ')';
		addChild(nametxt);

		var cury;
		cury = nametxt.y + textheight + divider/2;
		graphics.moveTo(0, cury);
		graphics.lineTo(w, cury);


		cury += divider/2;

		special = new TextField();
		special.selectable = false;
		special.width = 200;
		special.defaultTextFormat = State.textform;
		special.x = 4; special.y = cury;
		special.text =  (((bp.repair==true)?'Repair':'') + ((bp.is_building==true)?'Building':''));
		if (special.text=='') special.text = '---';
		addChild(special);


		cury += textheight + divider/2;
		graphics.moveTo(0, cury);
		graphics.lineTo(w, cury);


		var stats_top = cury + divider/2;


		var curx = 4;
		var cury = stats_top;

		health = new TextField();
		health.selectable = false;
		health.width = 100;
		health.defaultTextFormat = State.textform;
		health.x = curx; health.y = cury;
		cury += textheight;
		health.text = 'Health: ' + Std.string(bp.health);
		addChild(health);

		armor = new TextField();
		armor.selectable = false;
		armor.width = 100;
		armor.defaultTextFormat = State.textform;
		armor.x = curx; armor.y = cury;
		cury += textheight;
		armor.text = 'Armor: '+ Std.string( bp.armor );
		addChild(armor);

		vision = new TextField();
		vision.selectable = false;
		vision.width = 100;
		vision.defaultTextFormat = State.textform;
		vision.x = curx; vision.y = cury;
		cury += textheight;
		vision.text = 'Vision: ' + Std.string(bp.vision);
		addChild(vision);

		speed = new TextField();
		speed.selectable = false;
		speed.width = 100;
		speed.defaultTextFormat = State.textform;
		speed.x = curx; speed.y = cury;
		cury += textheight;
		speed.text = 'Speed: ' + Std.string(bp.speed);
		addChild(speed);



		//second column
		graphics.moveTo(w/2, stats_top);
		graphics.lineTo(w/2, h);

		cury = stats_top;
		curx = 104;

		damage = new TextField();
		damage.selectable = false;
		damage.width = 100;
		damage.defaultTextFormat = State.textform;
		damage.x = curx; damage.y = cury;
		cury += textheight;
		damage.text = 'Damage: ' + Std.string(bp.damage);
		addChild(damage);

		fire_rate = new TextField();
		fire_rate.selectable = false;
		fire_rate.width = 100;
		fire_rate.defaultTextFormat = State.textform;
		fire_rate.x = curx; fire_rate.y = cury;
		cury += textheight;
		fire_rate.text = 'Fire rate: ' + Std.string(bp.fire_rate);
		addChild(fire_rate);

		range = new TextField();
		range.selectable = false;
		range.width = 100;
		range.defaultTextFormat = State.textform;
		range.x = curx; range.y = cury;
		cury += textheight;
		range.text = 'Range: ' + Std.string(bp.range);
		addChild(range);

		// aoe = new TextField();
		// aoe.selectable = false;
		// aoe.width = 100;
		// aoe.defaultTextFormat = txtform;
		// aoe.x = curx; aoe.y = cury;
		// cury += textheight;
		// aoe.text = 'aoe: ' + Std.string(bp.aoe);
		// addChild(aoe);
	}


}


class UnitBlueprint {

	public var name: String;
	public var bpID: UInt;
	public var pID: UInt;
	public var color1:UInt;
	public var color2:UInt;

	public var damage:    Float;
	public var fire_rate: Float;
	public var aoe:       Float;
	public var range:     Int;

	public var speed:     Float;
	public var vision:    Int;

	public var health:    Float;
	public var armor:     Float;
	public var cost:      Float;
	public var buildtime: Float;

	public var shielding:      Bool;
	public var shield_capacity:Float;
	public var shield_recharge:Float;
	public var shield_delay:   Float; //in ms

	public var cloaking:  Bool;
	public var decloak:  Bool;
	public var repair:    Bool;
	public var can_build: Bool;

	public var ms_per_fire:Float;
	public var armor_damge_mult: Float;

	public var is_building: Bool;

	public var disp: BitmapData;

	public function new(player:Player, pID:UInt){

		is_building = false;

		this.pID = pID;
		bpID = -1;
		color1 = player.colors[0];
		color2 = player.colors[1];
		damage = 0;
		fire_rate = 0;
		ms_per_fire = 1000;
		range = 0;
		aoe = 0;

		speed = 0;
		vision = 0;

		health = 0;
		armor = 0;
		cost = 0;
		buildtime = 0;

		shielding = false;
		shield_capacity = 0;
		shield_recharge = 0;
		shield_delay = 0;      //in ms

		cloaking = false;
		decloak = false;
		repair = false;
		can_build = false;
	}

	//print unit's values to console
	public function print(){
		trace(	
			"\ndamage", damage,   
			"\nfire_rate", fire_rate, 
			"\nrange", range,     
			"\naoe", aoe,       
			"\nspeed", speed,     
			"\nvision", vision,    
			"\nhealth", health,    
			"\narmor", armor,     
			"\ncost", cost,      
			"\nbuildtime", buildtime, 
			"\nshielding", shielding,  
			"\nshield_capacity", shield_capacity,
			"\nshield_recharge", shield_recharge,
			"\nshield_delay", shield_delay,    
			"\ncloaking", cloaking,  
			"\ndecloak", decloak, 
			"\nrepair", repair,  
			"\ncan_build", can_build, 
			"\ndisp", disp
		);
	}


	//generate unit values
	public function alt_gen(){

		var damage_range:Array<Float> = [30, 50, 80, 120, 200];
		var fire_rate:Array<Float>    = [1, 1, 2, 3, 4];
		var range:Array<Float>        = [2, 2, 3, 4, 6, 12];
		// var aoe:Array<Float>          = [0, 0, 0, 1, 3, 7];

		var speed:Array<Float>   = [1, 1.5, 2, 2.5, 3, 6];
		// var speed:Array<Float>   = [3, 4];

		var vision:Array<Float>  = [2, 2, 2, 3, 3, 4, 5, 10];

		var health:Array<Float>    = [200, 220, 300, 400, 600, 1000];
		var cost:Array<Float>      = [120, 110, 100, 95, 90, 60];
		// var buildtime:Array<Float> = [20, 12, 7, 5, 3, 3];
		// var buildtime:Array<Float> = [300, 200, 120];

		var buildtime:Array<Float> = [200, 160, 120, 100];

		var armor:Array<Float>   = [0, 0, 0, 1, 2, 6];

		var repair:Array<Float>   = [0, 0, 0, 2];

		// var cloaking:Array<Float> = [0, 0, 0, 0, 1];
		// var decloak:Array<Float>  = [0, 0, 0, 1];

		var n_points = Random.float(10*.4, 10*.45);
		var vals:Array<Float> = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
		while (n_points>0){
			var points_to_add = Random.float(0.2,0.8);

			var ind = Random.int(0, vals.length-1);
			vals[ind] = Math.min(1.0, vals[ind]+points_to_add);
			n_points -= points_to_add;
		}

		var total:Float = 0;
		for (i in vals){
			total += i;
		}
		// trace('vals are', vals, 'total is', total);

		var points = vals[0];
		var ind = Math.floor((vals[0] * (damage_range.length-2)));
		var base = damage_range[ind];
		var secondary = damage_range[ind+1];
		var val = Random.float(base, secondary);
		this.damage = val - val%.1;

		var points = vals[1];
		var ind = Math.floor((points * (fire_rate.length-2)));
		var base = fire_rate[ind];
		var secondary = fire_rate[ind+1];
		var val = Random.float(base, secondary);
		this.fire_rate = val - val%.1;

		var points = vals[2];
		var ind = Math.floor((points * (range.length-2)));
		var base = range[ind];
		var secondary = range[ind+1];
		var val = Random.float(base, secondary);
		this.range = Math.floor(val);

		var points = vals[3];
		var ind = Math.floor((points * (speed.length-2)));
		var base = speed[ind];
		var secondary = speed[ind+1];
		var val = Random.float(base, secondary);
		this.speed = val - val%.1;

		var points = vals[4];
		var ind = Math.floor((points * (vision.length-2)));
		var base = vision[ind];
		var secondary = vision[ind+1];
		var val = Random.float(base, secondary);
		this.vision = Math.floor(val);

		var points = vals[5];
		var ind = Math.floor((points * (health.length-2)));
		var base = health[ind];
		var secondary = health[ind+1];
		var val = Random.float(base, secondary);
		this.health = val - val%.1;

		var points = vals[6];
		var ind = Math.floor((points * (cost.length-2)));
		var base = cost[ind];
		var secondary = cost[ind+1];
		var val = Random.float(base, secondary);
		this.cost = val - val%.1;

		var points = vals[7];
		var ind = Math.floor((points * (buildtime.length-2)));
		var base = buildtime[ind];
		var secondary = buildtime[ind+1];
		var val = Random.float(base, secondary);
		this.buildtime = val - val%.1;

		var points = vals[8];
		var ind = Math.floor((points * (armor.length-2)));
		var base = armor[ind];
		var secondary = armor[ind+1];
		var val = Random.float(base, secondary);
		this.armor = val - val%.1;

		var points = vals[9];
		var ind = Math.floor((points * (repair.length-2)));
		var base = repair[ind];
		var secondary = repair[ind+1];
		var val = Random.float(base, secondary);
		if (val>=0.1)
			this.repair = true;
		else this.repair = false;


		this.ms_per_fire = 100/this.fire_rate;
		armor_damge_mult = Math.sqrt(this.damage); //for calculating damage against enemy armor

		name = ProcDraw.Drawer.genName();
		disp = ProcDraw.Drawer.getDrawing(this, color1, color2);

		if (this.repair==true){
			damage/=2;
		}

	}
}




