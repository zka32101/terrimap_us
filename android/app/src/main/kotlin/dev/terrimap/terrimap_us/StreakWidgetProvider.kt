package dev.terrimap.terrimap_us

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** ホーム画面ウィジェット。アプリが書き出した文字（streak / status / landmark）と配色番号（skin）を出すだけ。タップでアプリを開く。 */
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
                val skin = widgetData.getInt("skin", 0).coerceIn(0, SKINS.size - 1)
                setInt(R.id.widget_root, "setBackgroundResource", SKINS[skin])
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private companion object {
        /** Flutter 側 `widgetSkinIndex` の番号と同じ並び。0 が標準。 */
        val SKINS = intArrayOf(
            R.drawable.widget_bg_0, R.drawable.widget_bg_1, R.drawable.widget_bg_2,
            R.drawable.widget_bg_3, R.drawable.widget_bg_4, R.drawable.widget_bg_5,
        )
    }
}
