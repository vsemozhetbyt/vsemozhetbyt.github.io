// ==UserScript==
// @name        FB: Preview Posts
// @namespace   vsemozhetbyt
// @version     1
// @include     https://www.facebook.com/*
// @noframes
// @grant       none
// @nocompat    Chrome
// ==/UserScript==
(function(d, l, opt){
	opt = ({
		'www.facebook.com':{
			observe_selector: '#contentArea',
			parent_selector: 'div.text_exposed_root:not(.text_exposed)',
			hidden_selector: '.text_exposed_show',
			link_selector: 'a[href=\'#\'].see_more_link'
		}
	})[l.hostname]; if(!opt) {alert('Wrong site.'); return;}
	function addPreview() {
		[].forEach.call(d.querySelectorAll(opt.parent_selector), function(el) {
			var hh = el.querySelectorAll(opt.hidden_selector);
			var l = el.querySelector(opt.link_selector);
			if(hh.length && l) {
				var txt = [].map.call(hh, function(el) {return el.textContent.trim().replace(/\s+/g, ' ');}).join(' ');
				l.title = txt.length + ': [...' + txt + ']';
			}
		});
	}
	addPreview();
	(new MutationObserver(function(mutations) {
		mutations.forEach(function(mutation) {
			addPreview();
		});
	})).observe(d.querySelector(opt.observe_selector), {childList: true, subtree: true});
})(document, location);
