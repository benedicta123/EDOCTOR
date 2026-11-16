package com.example.edoctor_mobile

import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Restriction FLAG_SECURE désactivée pour la phase de tests et retours collaborateurs
    }
}
