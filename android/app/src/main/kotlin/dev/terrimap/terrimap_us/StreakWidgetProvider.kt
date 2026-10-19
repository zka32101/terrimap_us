package dev.terrimap.terrimap_us

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** ホーム画面ウィジェット。アプリが書き出した文字（streak / status / landmark）を出すだけ。タップでアプリを開く。 */
class StreakWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.streak_widget).apply {
                setTextViewText(R.id.widget_streak, widgetData.getString("streak", "") ?: "")
                setTextViewText(R.id.widget_status, widgetData.getString("status", "") ?: "")
                setTextViewText(R.id.widget_landmark, widgetData.getString("landmark", "") ?: "")
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
