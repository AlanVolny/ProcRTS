


import openfl.display.BitmapData;
import Entities.UnitBlueprint;
import openfl.geom.Rectangle;

import Game.State;
import Random;



class Drawer {



	//returns a BitmapData
	public static function getDrawing( uBP:UnitBlueprint, color:UInt, color2:UInt ):BitmapData {

		var width = State.map.tdw;
		var height = State.map.tdw;

		var outbmp = new BitmapData(width, height);

		// var outbmp = new BitmapData(width, height, true, 0);

		// color = 0xFFFFFF;
		// var color = 0xFF285e13;
		// var color2= 0xFF142f09;

		// var color = 0xFF142f09;
		// var color2= 0xFF285e13;


		//set to transparent
		outbmp.floodFill(0, 0, 0);

		//draw side boxes
		var n_sides = Random.int(4,8);
		for (n in 0...n_sides){
			var box_w:Int = Random.int(Math.floor(width/6), Math.floor(width/5));
			var box_y:Int = Random.int(Math.floor(height/10), Math.floor((4*height)/5));
			var box_x:Int = Random.int(Math.floor(0), Math.floor(width/2));
			var box_h:Int = Random.int(Math.floor(height/10), Math.floor(height/4 ));
			drawBox( outbmp, new Rectangle(box_x,      box_y,box_w,box_h), color, color2 );
			drawBox( outbmp, new Rectangle(width-(box_x+box_w),box_y,box_w,box_h), color, color2 );
		}


		//draw main & flavor boxes
		var n_main = Random.int(3,6);
		var n_sides = Random.int(0,3);
		while (true){

			var main:Bool = false;

			if (Random.int(0,1)==1 && n_main > 0)
				main = true;
			else if (n_sides==0)
				break;
			else main==true;

			var box_w, box_h, box_x, box_y;

			if (main){
				box_w = Random.int(Math.floor(width/6), Math.floor(width/4 )*2);
				box_y = Random.int(Math.floor(height/6), Math.floor((2*height)/3));
				box_x = Math.floor( width/2 - box_w/2 );
				box_h = Random.int(Math.floor((height-box_y)/(n_main*2)), Math.floor((height-box_y)/2 ));
				n_main-=1;
			}
			else {
				box_w = Random.int(Math.floor(width/6),Math.floor( width/3) );
				box_h = Random.int(Math.floor(height/6), Math.floor((1*height)/2));
				box_x = Random.int(0, Math.floor(width-box_w));
				box_y = Random.int(0, Math.floor(height-box_h));
				n_sides -= 1;
			}
			drawBox( outbmp, new Rectangle(box_x,box_y,box_w,box_h), color, color2 );
		}

		return outbmp;
	}


	public static function drawBox( bmp:BitmapData, rect:Rectangle, color:UInt, color2:UInt ){

		bmp.fillRect( rect, 0xFF000000 );
		bmp.fillRect( new Rectangle(rect.x+1, rect.y+1, rect.width-2, rect.height-2), color );
		bmp.fillRect( new Rectangle(rect.x+2, rect.y+2, rect.width-4, rect.height-4), color2 );

	}


	public static function genName(): String{

		// var word_starts = ['pre','die','lo','san', 'ant'];
		// var word_parts1 = ['gra', 're','tri','co','fi', 'jo', 'po', 'ra'];
		// var word_parts2 = ['o','e','ae','a','i','ie','oa', 'il'];
		// var word_ends   = ['n','p','t','st','ple'];

		var word_starts = ['die','un', 'da', 'zo'];
		var word_parts1 = ['re','co','fie', 'pa', 'run', 'lo', 'we'];
		var word_parts2 = ['ae','a','r','il', 'n', 't'];
		var word_ends   = ['n','p','t','st','ple'];

		var name = genWord(word_starts, word_parts1, word_parts2, word_ends);
		if (Random.int(0,2)<2){
			name = name + ' ' + genWord(word_starts, word_parts1, word_parts2, word_ends);
		}

		return name;
	}

	public static function genWord(starts:Array<String>, parts1:Array<String>, parts2:Array<String>, ends:Array<String>){

		var start = Random.int(0,5);
		var word = '';
		if (start<3){
			word = starts[ Random.int(0, starts.length-1) ];
		}
		else if (start<5){
			word = parts1[ Random.int(0, parts1.length-1) ];
		}
		else{
			word = parts2[ Random.int(0, parts2.length-1) ];
		}

		var length = Random.int(0,2);
		var prev_was_vowel:Bool = false;
		for (i in 0...length){
			if (prev_was_vowel || Random.int(0,3)<3){
				word += parts1[ Random.int(0,parts1.length-1) ];
				prev_was_vowel = false;
			}
			else {
				word += parts2[ Random.int(0,parts2.length-1) ];
				prev_was_vowel = true;
			}
		}

		if (Random.int(0,2)<2){
			word += ends[ Random.int(0,ends.length-1) ];
		}

		return word;

	}

}


