package in.hobnob;

import android.support.v4.content.WakefulBroadcastReceiver;
import android.content.Context;
import android.content.Intent;

public class GpsTrackerAlarmReceiver extends WakefulBroadcastReceiver {
    private static final String TAG = "GpsTrackerAlarmReceiver";

    @Override
    public void onReceive(Context context, Intent intent) {
    	Log.d(TAG, "onReceive");
        context.startService(new Intent(context, LocationService.class));
    }
}