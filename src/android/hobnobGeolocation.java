package in.hobnob;

import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CallbackContext;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.SystemClock;
import android.util.Log;

import com.google.android.gms.common.ConnectionResult;
import com.google.android.gms.common.GooglePlayServicesUtil;

import java.util.UUID;


/**
 * This class echoes a string called from JavaScript.
 */
public class HobnobGeolocation extends CordovaPlugin {
    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        
        SharedPreferences sharedPreferences = this.getSharedPreferences("in.hobnob.prefs", Context.MODE_PRIVATE);
        currentlyTracking = sharedPreferences.getBoolean("currentlyTracking", false);

        userId = args.getString(0);
        repeatDelayInMinutes = args.getInt(1);
        defaultUploadWebsite = args.getString(2);

        if (action.equals("start")) {

            // Set currentlyTracking to true
            SharedPreferences.Editor editor = sharedPreferences.edit();
            editor.putBoolean("currentlyTracking", true);
            editor.putInt("repeatDelayInMinutes", repeatDelayInMinutes);
            editor.putString("userId", userId);
            editor.putString("defaultUploadWebsite", defaultUploadWebsite);
            editor.apply();

            startTracking();

            return true;
        }

        if (action.equals('stop')) {

            // Set currentlyTracking to false
            SharedPreferences.Editor editor = sharedPreferences.edit();
            editor.putBoolean("currentlyTracking", false);
            editor.apply();

            stopTracking();

            return true;
        }

        if (action.equals('isTracking')) {
            callbackContext.success(currentlyTracking);
        }
        return false;
    }

    private void startAlarmManager(Context context) {
        Log.d(TAG, "startAlarmManager");
        Context context = getBaseContext();
        alarmManager = (AlarmManager)context.getSystemService(Context.ALARM_SERVICE);
        gpsTrackerIntent = new Intent(context, GpsTrackerAlarmReceiver.class);
        pendingIntent = PendingIntent.getBroadcast(context, 0, gpsTrackerIntent, 0);

        SharedPreferences sharedPreferences = this.getSharedPreferences("in.hobnob.prefs", Context.MODE_PRIVATE);
        intervalInMinutes = sharedPreferences.getInt("repeatDelayInMinutes", 15);
     
        alarmManager.setRepeating(AlarmManager.ELAPSED_REALTIME_WAKEUP,
            SystemClock.elapsedRealtime(),
            repeatDelayInMinutes * 60 * 1000,
            pendingIntent);
    }

    private void cancelAlarmManager() {
        Log.d(TAG, "cancelAlarmManager");

        Context context = getBaseContext();
        Intent gpsTrackerIntent = new Intent(context, GpsTrackerAlarmReceiver.class);
        PendingIntent pendingIntent = PendingIntent.getBroadcast(context, 0, gpsTrackerIntent, 0);
        AlarmManager alarmManager = (AlarmManager)context.getSystemService(Context.ALARM_SERVICE);
        alarmManager.cancel(pendingIntent);
    }

    protected void startTracking() {
        SharedPreferences sharedPreferences = this.getSharedPreferences("com.websmithing.gpstracker.prefs", Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = sharedPreferences.edit();

        if (!checkIfGooglePlayEnabled()) {
            return;
        }

        startAlarmManager();
    }

    protected void stopTracking() {
        cancelAlarmManager();
    }

    private boolean checkIfGooglePlayEnabled() {
        if (GooglePlayServicesUtil.isGooglePlayServicesAvailable(this) == ConnectionResult.SUCCESS) {
            return true;
        } else {
            Log.e(TAG, "unable to connect to google play services.");
            return false;
        }
    }
}