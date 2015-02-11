module.exports = {
    start: function(success, failure, config) {
        cordova.exec(success || function() {},
             failure || function() {},
             'HobnobGeolocation',
             'start',
             [config.userId, config.delay, config.url, config.minimumDistance]);
    },
    stop: function(success, failure, config) {
        cordova.exec(success || function() {},
            failure || function() {},
            'HobnobGeolocation',
            'stop',
            []);
    }
};