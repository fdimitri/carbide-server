
	$.fn.buildAce = function(mySelector, myFileName, statusBar) {
		var fileExt = myFileName.match(/\.\w+$/);
		var modelist = require("ace/ext/modelist");
		var mode = modelist.getModeForPath(myFileName).mode;
		console.log("buildAce called with mySelector: " + mySelector + " and myFileName: " + myFileName);zxccccccccccccccccccccccccccccccccccccccccccc
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
			var like_a_boss = [
			];
			
				for(i = 0; i++; i<5) {
				
				}
				$(editor).attr('ignore', 'FALSE');
				editor.setTheme("ace/theme/twilight");
    // enable autocompletion and snippets
				editor.setOptions({
					enableBasicAutocompletion: true,
					enableSnippets: true,
					enableLiveAutocompletion: false
				});
				console.log(editor);
				var statusJSON = {
					"commandSet": "document",
					"command": "getContents",
					"targetDocument": $(editor).attr('srcPath'), 
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
function THISFUNCTION (j, ab, c) {
    return 0;
}

test = THISFUNCTION()	
	
$.fn.buildAce = function() { };








var servers = {
  'iceServers': [
    {
      'url': 'stun:stun.l.google.com:19302'
    },
    {
      'url': 'turn:192.158.29.39:3478?transport=udp',
      'credential': 'JZEOEt2V3Qb0y27GRntt2u2PAYA=',
      'username': '28224511:1379330808'
    },
    {
      'url': 'turn:192.158.29.39:3478?transport=tcp',
      'credential': 'JZEOEt2V3Qb0y27GRntt2u2PAYA=',
      'username': '28224511:1379330808'
    }
  ]
};