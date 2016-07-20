#import "AudioRecorderAPI.h"
#import <Cordova/CDV.h>

@implementation AudioRecorderAPI

#define RECORDINGS_FOLDER [NSHomeDirectory() stringByAppendingPathComponent:@"Library/NoCloud"]

static const char _base64EncodingTable[64] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static const short _base64DecodingTable[256] = {
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -1, -1, -2, -1, -1, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-1, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, 62, -2, -2, -2, 63,
	52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -2, -2, -2, -2, -2, -2,
	-2,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
	15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -2, -2, -2, -2, -2,
	-2, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
	41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2
};

- (void)record:(CDVInvokedUrlCommand*)command {
  _command = command;
  if([_command.arguments count] > 0) {
    duration = [_command.arguments objectAtIndex:0];
  } else {
    duration = @0;
  }

  [self.commandDelegate runInBackground:^{

    AVAudioSession *audioSession = [AVAudioSession sharedInstance];

    NSError *err;
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&err];
    if (err)
    {
      NSLog(@"%@ %d %@", [err domain], [err code], [[err userInfo] description]);
    }
    err = nil;
    [audioSession setActive:YES error:&err];
    if (err)
    {
      NSLog(@"%@ %d %@", [err domain], [err code], [[err userInfo] description]);
    }

    NSMutableDictionary *recordSettings = [[NSMutableDictionary alloc] init];
    [recordSettings setObject:[NSNumber numberWithInt: kAudioFormatMPEG4AAC] forKey: AVFormatIDKey];
    [recordSettings setObject:[NSNumber numberWithFloat:8000.0] forKey: AVSampleRateKey];
    [recordSettings setObject:[NSNumber numberWithInt:1] forKey:AVNumberOfChannelsKey];
    [recordSettings setObject:[NSNumber numberWithInt:12000] forKey:AVEncoderBitRateKey];
    [recordSettings setObject:[NSNumber numberWithInt:8] forKey:AVLinearPCMBitDepthKey];
    [recordSettings setObject:[NSNumber numberWithInt: AVAudioQualityLow] forKey: AVEncoderAudioQualityKey];

    // Create a new dated file
    NSString *uuid = [[NSUUID UUID] UUIDString];
    recorderFilePath = [NSString stringWithFormat:@"%@/%@.m4a", RECORDINGS_FOLDER, uuid];
    NSLog(@"recording file path: %@", recorderFilePath);

    NSURL *url = [NSURL fileURLWithPath:recorderFilePath];
    err = nil;
    recorder = [[AVAudioRecorder alloc] initWithURL:url settings:recordSettings error:&err];
    if(!recorder){
      NSLog(@"recorder: %@ %d %@", [err domain], [err code], [[err userInfo] description]);
      return;
    }

    [recorder setDelegate: (id)self];

    if (![recorder prepareToRecord]) {
      NSLog(@"prepareToRecord failed");
      return;
    }

    //if (![recorder recordForDuration:(NSTimeInterval)[duration intValue]]) {
    //  NSLog(@"recordForDuration failed");
    //  return;
    //}

    if (![recorder record]) {
      NSLog(@"recordForDuration failed");
      return;
    }

  }];
}

- (void)stop:(CDVInvokedUrlCommand*)command {
  _command = command;
  [recorder setDelegate:(id)self];
  NSLog(@"stopRecording");
  [recorder stop];
  NSLog(@"stopped");
}

- (void)playback:(CDVInvokedUrlCommand*)command {
  _command = command;
  [self.commandDelegate runInBackground:^{
    NSLog(@"recording playback");
    NSError *err;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:&err];
    if (err)
    {
        NSLog(@"%@ %d %@", [err domain], [err code], [[err userInfo] description]);
    }
    err = nil;
    [audioSession setActive:YES error:&err];
    if (err)
    {
        NSLog(@"%@ %d %@", [err domain], [err code], [[err userInfo] description]);
    }
    NSURL *url = [NSURL fileURLWithPath:recorderFilePath];

    player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&err];
    player.numberOfLoops = 0;
    player.delegate = self;
    [player prepareToPlay];
    [player play];
    if (err) {
      NSLog(@"%@ %d %@", [err domain], [err code], [[err userInfo] description]);
    }
    NSLog(@"playing");
  }];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
  NSLog(@"audioPlayerDidFinishPlaying");
  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"playbackComplete"];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
  if(flag)
  {
    NSURL *url = [NSURL fileURLWithPath: recorderFilePath];
    NSError *err = nil;
    NSData *audioData = [NSData dataWithContentsOfFile:[url path] options: 0 error:&err];
    if(!audioData) {
      NSLog(@"audio data: %@ %d %@", [err domain], [err code], [[err userInfo] description]);
    } else {
      NSLog(@"recording saved: %@", recorderFilePath);
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:[audioData base64EncodedStringWithOptions:kNilOptions]];
      NSFileManager *fileManager = [NSFileManager defaultManager];
      BOOL success = [fileManager removeItemAtPath:recorderFilePath error:&err];
      if (success) {
        NSLog(@"Deleted file -:%@ ", recorderFilePath);
      }
      else
      {
        NSLog(@"Could not delete file -:%@ ", recorderFilePath);
      }
      [self.commandDelegate sendPluginResult:pluginResult callbackId:_command.callbackId];
    }
  }
  else
  {
    NSLog(@"recording not successfully");
  }
}

- (NSString *)encodeBase64WithData:(NSData *)objData {
    const unsigned char * objRawData = [objData bytes];
    char * objPointer;
    char * strResult;

    // Get the Raw Data length and ensure we actually have data
    int intLength = [objData length];
    if (intLength == 0) return nil;

    // Setup the String-based Result placeholder and pointer within that placeholder
    strResult = (char *)calloc((((intLength + 2) / 3) * 4) + 1, sizeof(char));
    objPointer = strResult;

    // Iterate through everything
    while (intLength > 2) { // keep going until we have less than 24 bits
        *objPointer++ = _base64EncodingTable[objRawData[0] >> 2];
        *objPointer++ = _base64EncodingTable[((objRawData[0] & 0x03) << 4) + (objRawData[1] >> 4)];
        *objPointer++ = _base64EncodingTable[((objRawData[1] & 0x0f) << 2) + (objRawData[2] >> 6)];
        *objPointer++ = _base64EncodingTable[objRawData[2] & 0x3f];

        // we just handled 3 octets (24 bits) of data
        objRawData += 3;
        intLength -= 3;
    }

    // now deal with the tail end of things
    if (intLength != 0) {
        *objPointer++ = _base64EncodingTable[objRawData[0] >> 2];
        if (intLength > 1) {
            *objPointer++ = _base64EncodingTable[((objRawData[0] & 0x03) << 4) + (objRawData[1] >> 4)];
            *objPointer++ = _base64EncodingTable[(objRawData[1] & 0x0f) << 2];
            *objPointer++ = '=';
        } else {
            *objPointer++ = _base64EncodingTable[(objRawData[0] & 0x03) << 4];
            *objPointer++ = '=';
            *objPointer++ = '=';
        }
    }

    // Terminate the string-based result
    *objPointer = '\0';

    // Create result NSString object
    NSString *base64String = [NSString stringWithCString:strResult encoding:NSASCIIStringEncoding];

    // Free memory
    free(strResult);

    return base64String;
}

@end
