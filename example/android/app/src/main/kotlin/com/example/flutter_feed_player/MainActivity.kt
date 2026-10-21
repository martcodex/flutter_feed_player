package com.example.flutter_feed_player

import android.content.res.Configuration
import dev.martcodex.flutter_feed_player.FlutterFeedPlayerPlugin
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onUserLeaveHint() {
        FlutterFeedPlayerPlugin.onUserLeaveHint()
        super.onUserLeaveHint()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration,
    ) {
        FlutterFeedPlayerPlugin.onPipModeChanged(isInPictureInPictureMode)
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
    }
}
