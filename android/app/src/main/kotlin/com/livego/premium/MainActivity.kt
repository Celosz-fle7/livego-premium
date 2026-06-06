package com.livego.premium

import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private fun forceBlackWindow() {
        window.setBackgroundDrawable(ColorDrawable(Color.BLACK))
        window.statusBarColor = Color.BLACK
        window.navigationBarColor = Color.BLACK
        window.decorView.setBackgroundColor(Color.BLACK)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        forceBlackWindow()
        super.onCreate(savedInstanceState)
        forceBlackWindow()
    }

    override fun onResume() {
        super.onResume()
        forceBlackWindow()
    }
}
