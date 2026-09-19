(function (window, document) {
  function loadPixel(pixelId) {
    pixelId = pixelId || window.RAST_SNAP_PIXEL_ID;
    if (!pixelId || window.snaptr) return;

    window.snaptr = function () {
      window.snaptr.handleRequest
        ? window.snaptr.handleRequest.apply(window.snaptr, arguments)
        : window.snaptr.queue.push(arguments);
    };
    window.snaptr.queue = [];

    var script = document.createElement('script');
    script.async = true;
    script.src = 'https://sc-static.net/scevent.min.js';
    var firstScript = document.getElementsByTagName('script')[0];
    firstScript.parentNode.insertBefore(script, firstScript);
    window.snaptr('init', pixelId);
    window.snaptr('track', 'PAGE_VIEW');
  }

  window.rastSnapPixelInit = function (pixelId) {
    window.RAST_SNAP_PIXEL_ID = pixelId || '';
    loadPixel(window.RAST_SNAP_PIXEL_ID);
  };
  window.rastSnapPixelTrack = function (eventName, parameters) {
    loadPixel();
    if (typeof parameters === 'string') {
      try {
        parameters = JSON.parse(parameters);
      } catch (_) {
        parameters = {};
      }
    }
    if (window.snaptr && eventName) {
      var standardEvents = {
        app_open: 'PAGE_VIEW',
        begin_checkout: 'START_CHECKOUT',
        purchase: 'PURCHASE',
        sign_up: 'SIGN_UP',
        subscribe: 'SUBSCRIBE'
      };
      var snapEventName = standardEvents[eventName];
      if (snapEventName) {
        window.snaptr('track', snapEventName, parameters || {});
      } else {
        window.snaptr('track_custom_event', eventName, parameters || {});
      }
    }
  };
})(window, document);
