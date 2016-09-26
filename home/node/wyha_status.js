var express = require('express');
var app = express();
var Gamedig = require('gamedig');
var https = require('https');
var urls = ["https://wyha.gg/office.json", "https://wyha.gg/throwback.json"];

// Varnish cache warming for Gamedig endpoints. Additional endpoints must be added to the "urls" array.
function start() {
for (i in urls) {
    https.get(urls[i]);
}
setTimeout(start, 1000);
}

start();

// Gamedig endpoint 1, makes Gamedig json output available at /office.json on listening port.
app.get('/office.json', function (req, res) {
  Gamedig.query(
    {
        type: 'csgo',
        host: '72.5.195.44',
        hostport: '27015'
    },
    function(state) {
        res.setHeader('Access-Control-Allow-Origin', '*');
	if(state.error) console.log("Server is offline");
        else res.send(state);

    }
  );
});


// Gamedig endpoint 2, makes Gamedig json output available at /throwback.json on listening port.
app.get('/throwback.json', function (req, res) {
  Gamedig.query(
    {
        type: 'csgo',
        host: '66.150.214.89',
        hostport: '27015'
    },
    function(state) {
        res.setHeader('Access-Control-Allow-Origin', '*');
	if(state.error) console.log("Server is offline");
        else res.send(state);
    }
  );
});

// Listen on port 6969.
app.listen(6969, function () {
  console.log('wyHA server status listening on port 6969');
});
