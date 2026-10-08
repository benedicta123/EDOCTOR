package com.example.edoctor_mobile

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Bloque les captures d'écran et masque l'aperçu du multitâche pour protéger le secret médical
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
