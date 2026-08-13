package com.behuman.behuman_app

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // FLAG_SECURE blocks screenshots and screen recording, and blanks the
        // app's thumbnail in the recents switcher. The app shows proposals and
        // financial records, so those should not sit in a screenshot gallery or
        // be capturable by another app on the device.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        super.onCreate(savedInstanceState)
    }
}
