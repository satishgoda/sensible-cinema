update_icon = function(request, sender, sendResponse) {
	console.log("got request in background " + request);
  var active_tab_id = sender.tab.id; // sender
  if (request.text) {
    console.log("changing " + request.text + " color:" + request.color + " details:" + request.details);
    chrome.browserAction.setBadgeText({ text: request.text, tabId: active_tab_id });
    chrome.browserAction.setBadgeBackgroundColor({ color: request.color, tabId: active_tab_id });
    chrome.browserAction.setTitle({title: request.details, tabId: active_tab_id});
  }
  if (request.version_request) {
    var manifest = chrome.runtime.getManifest();
    console.log("sent version response" + manifest.version);
    sendResponse({version: manifest.version});
   }
   
   if (request.do_url) {
     // can only do tabs from b/g not contentscript apparently :|
     chrome.tabs.create({url: "https://playitmyway.org" + request.do_url}); // opens and sets active
     return;
   }
   
};

chrome.runtime.onMessage.addListener(update_icon); // from contentscripts.js 

chrome.runtime.onMessageExternal.addListener(update_icon); // from real page [those allowed to anyway permission wise :| ]

// startup, I think only run once for the "backup html page" singleton
// not sure what this means since it only affects one tab once what?
// update_icon( { color: "#808080", text: ".." } );

chrome.runtime.onUpdateAvailable.addListener(function(status, details) {
  console.log(status);
  console.log(details);
  chrome.runtime.reload(); // hope this wurks...otherwise no update-ydatey
});
