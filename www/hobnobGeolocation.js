module.exports = {
    start: function(success, failure, config) {
        cordova.exec(success || function() {},
             failure || function() {},
             'HobnobGeolocation',
             'start',
             [config.userId, config.delay, config.url]);
    },
    stop: function(success, failure, config) {
        cordova.exec(success || function() {},
            failure || function() {},
            'HobnobGeolocation',
            'stop',
            []);
    }
};