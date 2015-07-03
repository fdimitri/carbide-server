	$.fn.buildAce = function(mySelector, myFileName, statusBar) {
		var fileExt = myFileName.match(/\.\w+$/);
		var modelist = require("ace/ext/modelist");
		var mode = modelist.getModeForPath(myFileName).mode;
		console.log("buildAce called with mySelector: " + mySelector + " and myFileName: " + myFileName);
		console.log("buildAce Calaculated ace.edit() call: " + mySelector.replace(/\#/, ''));
		console.log($(mySelector));
		$(mySelector).each(
			function() {
				var editor = ace.edit(mySelector.replace(/\#/, ''));
				$(mySelector).ace = editor;
				$(editor).attr('srcPath', $(mySelector).attr('srcPath'));
				var StatusBar = require("ace/ext/statusbar").StatusBar;
				editor.session.setMode(mode);
				var lt = require("ace/ext/language_tools");
				console.log("Language tools:");
				console.log(lt);
// 				tpying  oasdf jaskld oasisleeeeeee
				
				
// 				andrew sledgianowski is a polish
// 				We, the people!
// 				See I make new lines
				
// 				While you're typing..
				
// 				And it just moves your stuff down!
				
// 				for the least part
// 				for the most part
// 				for the part part
// 				part 2 in which doris gets her oats
				
// 				in which paul mcartney proclaims that doris obtains her oats
// 				oaty oats of peace and love
				
// 				and foreign aid
				
// 				foreign aid expat oats from best korea.
				
				
// 				least best korea
				
// 				and upjapanwards
				
				
// 				spaceland earth
// 				the 3erdiest planeto
// 				system of solars 
				
// 				solarsystems 
// 				voice over photon solar system
				
				
// 			this and that
			var like_a_boss = [
			];
			
// 			oats on boats thats how they get the oats
			
// 			boats with oats
// 			boats filled with oats and they come across 
			
// 			come across
			
			
			
// 			boass boat it float 
// 			and its besterly westerly and ferting
			
			
			
// 			ferty
// 			fertingly
// 			fertisly
// 			fertyistingly
			
			
// 			alphabetically souply
            Souperly
            I commented you out!souply   pooply
            
            i am peroples
            
            preopley
            
            
            creepoly
            
            deeeeeepoly
            they are your choices and you make them
            
            and then you make then
            
            and them you make then
            
            
            and then them then them
            eta!
            and also
            you have dreams of the house you lived in when you were too young to drive and then you were a little older
            and then you were slighly older
            and you were still growing up
            
            growing uply
            bubbblly
            
            
            bubbly
            
            tupperware
            
            
            made of tupper
            what is tupper made of
            
            its tupper
            
            
            uppertupper
            
            
            
            
            
            outerspace
            wares.
            tupper-warez
            
				// create a simple selection status indicator
				//var statusBar = new StatusBar(editor, $(statusBar));
				// I'm tnyping on this line now!
				// my sharo a! 
				// for each mostest part
				for(i = 0; i++; i<5) {
				
				}				$(editor).attr('ignore', 'FALSE');
				editor.setTheme("ace/theme/twilight");
    // enable autocompletion and snippets
				editor.setOptions({
					enableBasicAutocompletion: true,
					enableSnippets: true,
					enableLiveAutocompletion: false
				});				why would u want that as a feature
				console.log(editor);
				var statusJSON = {
					"commandSet": "document",
					"command": "getContents",
					"targetDocument": $(editor).attr('srcPath'), code lintingit doesnt write backwards
			backtwards
			fortwards
			upsidedowntwards
			reversetwards
			unmomentwards
			im a moron its greater than moreoff formoref
			forlessof
			greateroff
			lessthanoff
			lessthand
			greaterthand
			beforethands
			upsidedownthands
			outerspacestwards
			atomosphereishy
			astmopsfie
			
		
		ahhhShhhhPhhhhAhhhChhE!!h!!!h!hhhhh!hhh hhhhShhhhPhAhhhChhhEhhhhh!!!!
		nomorecheesecharacter SPACE!!!!!!!
		
		
		
		
		void!     n
		void * ull;
		
		
		
		Hi Andrew, I'm typing down here.. and I see you typing up there!
					"getContents": {
						"document": $(editor).attr('srcPath'),
					},
				};
				console.log("The pre should still exist right now..");
				console.log($(mySelector));

				wsSendMsg(JSON.stringify(statusJSON));

				editor.getSession().on("change", function(e) {
					//console.log("Change on editor");
					//console.log(editor);
					//console.log(e);
					$.fn.aceChange(editor, e);
				});
			}
		);
	};
	
	
$.fn.buildAce = function() { };
