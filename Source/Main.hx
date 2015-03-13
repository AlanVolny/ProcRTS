package;


import openfl.display.Sprite;


class Main extends Sprite {
	
	
	public function new () {
		
		super ();

		trace('starting');
		
		var state = new Game.State(this);
		
	}
	
	
}