package com.emj365.plugins;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import android.media.MediaRecorder;
import android.media.MediaPlayer;
import android.media.AudioManager;
import android.os.CountDownTimer;
import android.os.Environment;
import android.content.Context;
import java.util.UUID;
import java.io.FileInputStream;
import java.io.File;
import java.io.FileNotFoundException;
import android.util.Base64;
import java.io.IOException;
import android.util.Log;

public class AudioRecorderAPI extends CordovaPlugin {

  private MediaRecorder myRecorder;
  private String outputFile;
  private CountDownTimer countDowntimer;
  public static String TAG = "AudioRecorder";

  @Override
  public boolean execute(String action, JSONArray args, final CallbackContext callbackContext) throws JSONException {
    Context context = cordova.getActivity().getApplicationContext();
    Integer seconds;
    if (args.length() >= 1) {
      seconds = args.getInt(0);
    } else {
      seconds = 0;
    }
    if (action.equals("record")) {
      outputFile = context.getFilesDir().getAbsoluteFile() + "/"
        + UUID.randomUUID().toString() + ".m4a";
      myRecorder = new MediaRecorder();
      myRecorder.setAudioSource(MediaRecorder.AudioSource.MIC);
      myRecorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);
      myRecorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);
      myRecorder.setAudioSamplingRate(16000);// 44100 for high quality, 8000 for lowest
      myRecorder.setAudioChannels(1);
      myRecorder.setAudioEncodingBitRate(12200);// 32000 for high quality, 12200 for lowest
      myRecorder.setOutputFile(outputFile);

      try {
        myRecorder.prepare();
        myRecorder.start();
      } catch (final Exception e) {
        cordova.getThreadPool().execute(new Runnable() {
          public void run() {
            callbackContext.error(e.getMessage());
          }
        });
        return false;
      }

      if(seconds > 0) {
        countDowntimer = new CountDownTimer(seconds * 1000, 1000) {
          public void onTick(long millisUntilFinished) {}
          public void onFinish() {
            stopRecord(callbackContext);
          }
        };
        countDowntimer.start();
      }
      return true;
    }

    if (action.equals("stop")) {
      //countDowntimer.cancel();
      stopRecord(callbackContext);
      return true;
    }

    if (action.equals("stopTimer")) {
      countDowntimer.cancel();
      stopRecord(callbackContext);
      return true;
    }

    if (action.equals("playback")) {
      MediaPlayer mp = new MediaPlayer();
      mp.setAudioStreamType(AudioManager.STREAM_MUSIC);
      try {
        FileInputStream fis = new FileInputStream(new File(outputFile));
        mp.setDataSource(fis.getFD());
      } catch (IllegalArgumentException e) {
        e.printStackTrace();
      } catch (SecurityException e) {
        e.printStackTrace();
      } catch (IllegalStateException e) {
        e.printStackTrace();
      } catch (IOException e) {
        e.printStackTrace();
      }
      try {
        mp.prepare();
      } catch (IllegalStateException e) {
        e.printStackTrace();
      } catch (IOException e) {
        e.printStackTrace();
      }
      mp.setOnCompletionListener(new MediaPlayer.OnCompletionListener() {
        public void onCompletion(MediaPlayer mp) {
          callbackContext.success("playbackComplete");
        }
      });
      mp.start();
      return true;
    }

    return false;
  }

  private void stopRecord(final CallbackContext callbackContext) {
    if(myRecorder != null) {
      Log.w(TAG, "stop audio");
      myRecorder.stop();
      myRecorder.release();
      cordova.getThreadPool().execute(new Runnable() {
        public void run() {
          Log.w(TAG, "outputFile: " + outputFile);
          try {
            File fileAudio = new File(outputFile);
            FileInputStream fis = new FileInputStream(fileAudio);
            byte bArray[] = new byte[(int)fileAudio.length()];
            fis.read(bArray);
            String audioEncoded = Base64.encodeToString(bArray,Base64.NO_WRAP);
            Log.w(TAG, "audioEncoded: " + audioEncoded);
            if(fis != null) {
              fis.close();
            }
            callbackContext.success(audioEncoded);
          } catch(FileNotFoundException e) {
            Log.w(TAG, "FileNotFoundException");
          } catch(IOException e) {
            Log.w(TAG, "IOException");
          }
        }
      });
    }
  }

}
