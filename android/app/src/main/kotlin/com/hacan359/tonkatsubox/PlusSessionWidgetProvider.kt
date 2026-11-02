package com.hacan359.tonkatsubox

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

// Home-screen widget: the session in progress with a live chronometer, and
// this year's goals. Data is pushed from Dart through home_widget.
class PlusSessionWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val title = widgetData.getString("plus_title", null)
        val idle = widgetData.getString("plus_idle", null) ?: "Tonkatsu Box Plus"
        val goals = widgetData.getString("plus_goals", null)
        val startedAt = widgetData.getString("plus_started_at", null)?.toLongOrNull()

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.plus_session_widget)
            if (title != null && startedAt != null && startedAt > 0) {
                views.setTextViewText(R.id.plus_widget_title, title)
                val elapsed = System.currentTimeMillis() - startedAt
                views.setChronometer(
                    R.id.plus_widget_chrono,
                    SystemClock.elapsedRealtime() - elapsed,
                    null,
                    true,
                )
                views.setViewVisibility(R.id.plus_widget_chrono, View.VISIBLE)
            } else {
                views.setTextViewText(R.id.plus_widget_title, idle)
                views.setChronometer(R.id.plus_widget_chrono, SystemClock.elapsedRealtime(), null, false)
                views.setViewVisibility(R.id.plus_widget_chrono, View.GONE)
            }
            if (goals.isNullOrBlank()) {
                views.setViewVisibility(R.id.plus_widget_goals, View.GONE)
            } else {
                views.setTextViewText(R.id.plus_widget_goals, goals)
                views.setViewVisibility(R.id.plus_widget_goals, View.VISIBLE)
            }
            views.setOnClickPendingIntent(
                R.id.plus_widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
