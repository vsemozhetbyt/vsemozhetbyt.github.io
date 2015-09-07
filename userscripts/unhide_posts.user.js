// ==UserScript==
// @name        FB: Unhide Posts
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
			link_selector: 'a[href=\'#\'].see_more_link'
		}
	})[l.hostname]; if(!opt) {alert('Wrong site.'); return;}
	function unhide() {
		[].forEach.call(d.querySelectorAll(opt.parent_selector), function(el) {
			var l = el.querySelector(opt.link_selector);
			if(l) {
				l.click();
			}
		});
	}
	unhide();
	(new MutationObserver(function(mutations) {
		mutations.forEach(function(mutation) {
			unhide();
		});
	})).observe(d.querySelector(opt.observe_selector), {childList: true, subtree: true});
})(document, location);
