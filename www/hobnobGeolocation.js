module.exports = {
    start: function(success, failure, config) {
        exec(success || function() {},
             failure || function() {},
             'HobnobGeolocation',
             'start',
             []);
    },
    stop: function(success, failure, config) {
        exec(success || function() {},
            failure || function() {},
            'HobnobGeolocation',
            'stop',
            []);
    }
};