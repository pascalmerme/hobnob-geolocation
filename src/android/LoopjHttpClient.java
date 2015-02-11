package in.hobnob;

import android.util.Log;

import com.loopj.android.http.AsyncHttpClient;
import com.loopj.android.http.AsyncHttpResponseHandler;
import com.loopj.android.http.RequestParams;

import org.apache.http.Header;

import java.io.UnsupportedEncodingException;
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.util.Locale;

public class LoopjHttpClient {
    private static AsyncHttpClient client = new AsyncHttpClient();

    public static void get(String url, RequestParams params, AsyncHttpResponseHandler responseHandler) {
        client.get(url, params, responseHandler);
    }

    public static void post(String url, HttpEntity entity, AsyncHttpResponseHandler responseHandler) {
        client.post(url, entity, "application/json", responseHandler);
    }

    public static void debugLoopJ(String TAG, String methodName,String url, byte[] response, Header[] headers, int statusCode, Throwable t) {
        if (headers != null) {
            Log.e(TAG, methodName);
            Log.d(TAG, "Return Headers:");
            for (Header h : headers) {
                String _h = String.format(Locale.US, "%s : %s", h.getName(), h.getValue());
                Log.d(TAG, _h);
            }

            if (t != null) {
                Log.d(TAG, "Throwable:" + t);
            }

            Log.e(TAG, "StatusCode: " + statusCode);

            if (response != null) {
                Log.d(TAG, "Response: " + new String(response));
            }

        }
    }
}
