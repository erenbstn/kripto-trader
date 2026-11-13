package app.pusula.pusula_app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.FileProvider
import androidx.core.content.pm.PackageInfoCompat
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val channelName = "app.pusula/background"
    private val updateChannelName = "app.pusula/update"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAppVersion" -> {
                        try {
                            val pInfo = packageManager.getPackageInfo(packageName, 0)
                            val versionCode = PackageInfoCompat.getLongVersionCode(pInfo)
                            result.success(
                                mapOf(
                                    "versionName" to (pInfo.versionName ?: "1.0.0"),
                                    "versionCode" to versionCode.toInt()
                                )
                            )
                        } catch (e: Exception) {
                            result.error("VERSION_ERROR", e.message, null)
                        }
                    }
                    "getUpdateCacheDir" -> {
                        val dir = File(cacheDir, "updates").apply { mkdirs() }
                        result.success(dir.absolutePath)
                    }
                    "canRequestPackageInstalls" -> {
                        val allowed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            packageManager.canRequestPackageInstalls()
                        } else {
                            true
                        }
                        result.success(allowed)
                    }
                    "openUnknownSourcesSettings" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val intent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("INVALID_PATH", "APK yolu boş.", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val updatesRoot = File(cacheDir, "updates").canonicalFile
                            val apkFile = File(path).canonicalFile
                            if (!apkFile.path.startsWith(updatesRoot.path) || !apkFile.exists() || !apkFile.name.endsWith(".apk")) {
                                result.error("INVALID_FILE", "APK dosyası doğrulanamadı.", null)
                                return@setMethodCallHandler
                            }
                            val uri = FileProvider.getUriForFile(
                                applicationContext,
                                "${packageName}.fileprovider",
                                apkFile
                            )
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedulePeriodicScan" -> {
                        val minutes = (call.argument<Number>("intervalMinutes")?.toLong() ?: 15L).coerceAtLeast(15L)
                        val req = PeriodicWorkRequestBuilder<PusulaPeriodicScanWorker>(minutes, TimeUnit.MINUTES)
                            .build()
                        WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
                            "pusula_periodic_scan",
                            ExistingPeriodicWorkPolicy.KEEP,
                            req
                        )
                        result.success(true)
                    }
                    "scheduleExactAlarms" -> {
                        val sundayMs = call.argument<Number>("sundayReportMs")?.toLong()
                        val bistOpenMs = call.argument<Number>("bistOpenMs")?.toLong()
                        val bistCloseMs = call.argument<Number>("bistCloseMs")?.toLong()
                        if (sundayMs != null) scheduleExact(101, "sunday_report", sundayMs)
                        if (bistOpenMs != null) scheduleExact(102, "bist_open", bistOpenMs)
                        if (bistCloseMs != null) scheduleExact(103, "bist_close", bistCloseMs)
                        result.success(true)
                    }
                    "setLiveMonitor" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        val svcIntent = Intent(applicationContext, PusulaLiveMonitorService::class.java)
                        if (enabled) {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                applicationContext.startForegroundService(svcIntent)
                            } else {
                                applicationContext.startService(svcIntent)
                            }
                        } else {
                            applicationContext.stopService(svcIntent)
                        }
                        result.success(enabled)
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    }
                    "initNotificationChannels" -> {
                        ensureChannels()
                        result.success(true)
                    }
                    "showLocalNotification" -> {
                        ensureChannels()
                        val id = call.argument<Number>("id")?.toInt() ?: 1000
                        val chId = call.argument<String>("channelId") ?: "pusula_signal"
                        val title = call.argument<String>("title") ?: "Pusula"
                        val body = call.argument<String>("body") ?: ""
                        val high = call.argument<Boolean>("highPriority") ?: false
                        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        val notif = NotificationCompat.Builder(applicationContext, chId)
                            .setSmallIcon(android.R.drawable.ic_dialog_info)
                            .setContentTitle(title)
                            .setContentText(body)
                            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                            .setPriority(
                                if (high) NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_DEFAULT
                            )
                            .setAutoCancel(true)
                            .build()
                        nm.notify(id, notif)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun ensureChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channels = listOf(
            NotificationChannel("pusula_signal", "Sinyal", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Yeni teknik kurulum ve giriş bölgesi bildirimleri"
            },
            NotificationChannel("pusula_outcome", "Sonuç", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Hedef, stop, başabaş ve stopa yakınlık bildirimleri"
            },
            NotificationChannel("pusula_report", "Rapor", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Pazar günü haftalık rapor bildirimleri"
            },
            NotificationChannel("pusula_system", "Sistem", NotificationManager.IMPORTANCE_LOW).apply {
                description = "Veri kaynağı ve canlı izleme durum bildirimleri"
            }
        )
        for (ch in channels) {
            nm.createNotificationChannel(ch)
        }
    }

    private fun scheduleExact(requestCode: Int, kind: String, triggerAtMs: Long) {
        val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(applicationContext, PusulaAlarmReceiver::class.java).apply {
            putExtra("alarm_kind", kind)
        }
        val pi = PendingIntent.getBroadcast(
            applicationContext,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
            } else {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
            }
        } catch (_: SecurityException) {
            am.set(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
        }
    }
}

class PusulaPeriodicScanWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        // Arka plan periyodik kontrol işareti kaydedilir
        applicationContext.getSharedPreferences("pusula_bg", Context.MODE_PRIVATE)
            .edit()
            .putLong("last_periodic_scan_ms", System.currentTimeMillis())
            .apply()
        return Result.success()
    }
}

class PusulaAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val kind = intent?.getStringExtra("alarm_kind") ?: "scheduled"
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = if (kind == "sunday_report") "pusula_report" else "pusula_system"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                channelId,
                if (kind == "sunday_report") "Rapor" else "Sistem",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            nm.createNotificationChannel(ch)
        }
        val (title, body) = when (kind) {
            "sunday_report" -> "Pazar raporun hazır" to "Haftalık BIST ve Kripto analizini görmek için Pusula'yı açın."
            "bist_open" -> "BIST seansı açıldı" to "Sürekli işlem seansı başladı; açık sinyaller izleniyor."
            "bist_close" -> "BIST seansı kapandı" to "Gün sonu kapanış verileri güncelleniyor."
            else -> "Pusula zamanlı kontrol" to "Piyasa durumu kontrol edildi."
        }
        val notif = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .build()
        nm.notify(kind.hashCode(), notif)
    }
}

class PusulaLiveMonitorService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val channelId = "pusula_system"
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(channelId, "Sistem", NotificationManager.IMPORTANCE_LOW)
            nm.createNotificationChannel(ch)
        }
        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_popup_sync)
            .setContentTitle("Pusula Canlı İzleme Aktif")
            .setContentText("Açık sinyaller ve kurulumlar 1 dk aralıkla yerel olarak izleniyor.")
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(9001, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(9001, notification)
        }
        return START_STICKY
    }
}
