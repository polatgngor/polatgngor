package com.taksibu.driver.driver_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.os.Build
import android.os.PowerManager
import android.app.KeyguardManager
import androidx.core.app.NotificationCompat

class WakeUpReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "com.taksibu.driver.WAKE_UP") {
            // 1. Acquire WakeLock (CPU + Screen) - Vital for "Zınk" effect
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.ACQUIRE_CAUSES_WAKEUP or 
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK, 
                "TaksibuDriver::WakeUpLock"
            )
            wakeLock.acquire(10000) // Hold for 10 seconds max

            // 2. Disable Keyguard / Request Dismissal
            val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // keyguardManager.requestDismissKeyguard(activity, null) // This requires an Activity.
                // Since we are in a Receiver, we rely on the Activity's setShowWhenLocked/turnScreenOn in Manifest.
            }
            
            showIncomingCallNotification(context)
        }
    }

    private fun showIncomingCallNotification(context: Context) {
        val channelId = "incoming_request_v2"
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Ensure channel exists (Duplicate safety)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Gelen Çağrılar",
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "Yeni yolculuk çağrıları için kullanılır"
            
            // Critical for sound
             val audioAttributes = android.media.AudioAttributes.Builder()
                .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(android.media.AudioAttributes.USAGE_ALARM)
                .build()
                
            // Use default sound or custom if needed. Default is usually safest for "noise".
            // If we want to force sound even if silent mode... that's harder without MediaPlayer, 
            // but IMPORTANCE_HIGH usually breaks through Do Not Disturb depending on user settings.
            channel.setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI, audioAttributes)
            
            channel.enableVibration(true)
            channel.lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            
            notificationManager.createNotificationChannel(channel)
        }

        // Create Full Screen Intent
        val fullScreenIntent = Intent(context, MainActivity::class.java)
        // CRITICAL FLAGS FOR "ZINK" OPEN
        fullScreenIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                                 Intent.FLAG_ACTIVITY_CLEAR_TOP or 
                                 Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                 Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
        
        // Create PendingIntents for actions (even if dummy)
        val fullScreenPendingIntent = PendingIntent.getActivity(
            context, 
            0, 
            fullScreenIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(context, channelId)
            // USE NEW ICON HERE
            .setSmallIcon(R.drawable.ic_notification) 
            .setContentTitle("Yeni Yolculuk Çağrısı")
            .setContentText("Müşteri bekliyor...")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setTimeoutAfter(30000)
            .setOngoing(true) // Make it sticky so it doesn't just swipe away initially

        // Use CallStyle for Android 11+ (API 31+)
        val person = androidx.core.app.Person.Builder()
            .setName("Müşteri")
            .setIcon(androidx.core.graphics.drawable.IconCompat.createWithResource(context, R.drawable.ic_notification))
            .setImportant(true)
            .build()

        val callStyle = NotificationCompat.CallStyle.forIncomingCall(
            person,
            fullScreenPendingIntent, // Decline intent (dummy)
            fullScreenPendingIntent  // Answer intent (we just want to open app)
        )
        
        builder.setStyle(callStyle)

        notificationManager.notify(888, builder.build())
        
        // Also try direct launch for good measure
        try {
           context.startActivity(fullScreenIntent)
        } catch (e: Exception) {
            // Ignore if blocked, FullScreenIntent is the backup
        }
    }
}
