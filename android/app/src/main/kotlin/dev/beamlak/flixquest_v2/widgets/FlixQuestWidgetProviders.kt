package dev.beamlak.flixquest_v2.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import dev.beamlak.flixquest_v2.MainActivity
import dev.beamlak.flixquest_v2.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.LocalDate
import org.json.JSONObject

data class WidgetContent(
    val eyebrow: String,
    val title: String,
    val subtitle: String,
    val meta: String,
    val imagePath: String?,
    val deepLink: String,
    val progress: Int? = null,
    val statA: String = "",
    val statB: String = "",
    val statC: String = "",
)

abstract class FlixQuestWidgetProvider : HomeWidgetProvider() {
    abstract fun content(widgetData: SharedPreferences): WidgetContent

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(
            context,
            appWidgetManager,
            intArrayOf(appWidgetId),
            HomeWidgetPlugin.getData(context),
        )
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val content = content(widgetData)
        appWidgetIds.forEach { widgetId ->
            try {
                val options = appWidgetManager.getAppWidgetOptions(widgetId)
                val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 320)
                val compact = width < 190
                val primary = widgetData.safeColor("theme_primary", 0xFFF57C00.toInt())
                val foreground = widgetData.safeColor("theme_foreground", 0xFFFFFFFF.toInt())
                val muted = widgetData.safeColor("theme_muted", 0xA6FFFFFF.toInt())
                val layout = if (compact) {
                    R.layout.flixquest_widget_compact
                } else {
                    R.layout.flixquest_widget
                }
                val views = RemoteViews(context.packageName, layout).apply {
                    setTextColor(R.id.widget_eyebrow, primary)
                    setTextColor(R.id.widget_title, foreground)
                    setTextColor(R.id.widget_subtitle, muted)
                    setTextColor(R.id.widget_meta, muted)
                    setTextViewText(R.id.widget_eyebrow, content.eyebrow)
                    setTextViewText(R.id.widget_title, content.title)
                    setTextViewText(R.id.widget_subtitle, content.subtitle)
                    setTextViewText(R.id.widget_meta, content.meta)
                    setTextViewText(R.id.widget_stat_a, content.statA)
                    setTextViewText(R.id.widget_stat_b, content.statB)
                    setTextViewText(R.id.widget_stat_c, content.statC)

                    val bitmap = content.imagePath
                        ?.takeIf { it.isNotBlank() }
                        ?.let(::decodeWidgetPoster)
                    if (bitmap == null) {
                        setViewVisibility(R.id.widget_hero, View.GONE)
                    } else {
                        setImageViewBitmap(R.id.widget_hero, bitmap)
                        setViewVisibility(R.id.widget_hero, View.VISIBLE)
                        setTextColor(R.id.widget_title, 0xFFFFFFFF.toInt())
                        setTextColor(R.id.widget_subtitle, 0xE6FFFFFF.toInt())
                        setTextColor(R.id.widget_meta, 0xCCFFFFFF.toInt())
                        setTextColor(R.id.widget_stat_a, 0xFFFFFFFF.toInt())
                        setTextColor(R.id.widget_stat_b, 0xFFFFFFFF.toInt())
                        setTextColor(R.id.widget_stat_c, 0xFFFFFFFF.toInt())
                    }
                    if (bitmap == null || compact) {
                        setViewVisibility(R.id.widget_poster, View.GONE)
                    } else {
                        setImageViewBitmap(R.id.widget_poster, bitmap)
                        setViewVisibility(R.id.widget_poster, View.VISIBLE)
                    }
                    setViewVisibility(R.id.widget_meta, if (compact) View.GONE else View.VISIBLE)
                    setViewVisibility(R.id.widget_stat_row, if (compact) View.GONE else View.VISIBLE)

                    val progress = content.progress
                    if (progress == null || compact) {
                        setViewVisibility(R.id.widget_progress, View.GONE)
                    } else {
                        setProgressBar(
                            R.id.widget_progress,
                            100,
                            progress.coerceIn(0, 100),
                            false,
                        )
                        setViewVisibility(R.id.widget_progress, View.VISIBLE)
                    }

                    val launchIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse(content.deepLink),
                    )
                    setOnClickPendingIntent(R.id.widget_container, launchIntent)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            } catch (error: Exception) {
                android.util.Log.e("FlixQuestWidget", "Could not update widget $widgetId", error)
            }
        }
    }

    private fun SharedPreferences.safeColor(key: String, fallback: Int): Int =
        try {
            getInt(key, fallback)
        } catch (_: ClassCastException) {
            (all[key] as? Number)?.toInt() ?: fallback
        }

    private fun decodeWidgetPoster(path: String): Bitmap? {
        val decoded = BitmapFactory.decodeFile(path) ?: return null
        val targetWidth = 180
        if (decoded.width <= targetWidth) return decoded
        val targetHeight = (decoded.height * (targetWidth.toFloat() / decoded.width)).toInt()
        return Bitmap.createScaledBitmap(decoded, targetWidth, targetHeight, true).also {
            if (it !== decoded) decoded.recycle()
        }
    }
}

abstract class DailyPickWidgetProvider : FlixQuestWidgetProvider() {
    abstract val scheduleKey: String
    abstract val eyebrow: String
    abstract val fallbackTitle: String

    override fun content(widgetData: SharedPreferences): WidgetContent {
        val payload = widgetData.getString(scheduleKey, null)
        if (payload.isNullOrBlank()) {
            return WidgetContent(
                eyebrow = eyebrow,
                title = fallbackTitle,
                subtitle = "Open FlixQuest to load today's pick",
                meta = "Updates daily",
                imagePath = null,
                deepLink = "flixquest://home",
            )
        }
        return try {
            val root = JSONObject(payload)
            val items = root.getJSONArray("items")
            val startDay = root.getLong("startDay")
            val currentDay = LocalDate.now().toEpochDay()
            val index = Math.floorMod((currentDay - startDay).toInt(), items.length())
            val item = items.getJSONObject(index)
            WidgetContent(
                eyebrow = eyebrow,
                title = item.optString("title", fallbackTitle),
                subtitle = item.optString("subtitle", "Today's pick"),
                meta = item.optString("meta", "Picked for today"),
                imagePath = item.optString("image").takeIf { it.isNotBlank() && it != "null" },
                deepLink = item.optString("deepLink", "flixquest://home"),
                statA = item.optString("meta", "TODAY"),
                statB = "TRENDING NOW",
            )
        } catch (_: Exception) {
            WidgetContent(
                eyebrow = eyebrow,
                title = fallbackTitle,
                subtitle = "Open FlixQuest to refresh",
                meta = "Updates daily",
                imagePath = null,
                deepLink = "flixquest://home",
            )
        }
    }
}

class MovieOfDayWidgetProvider : DailyPickWidgetProvider() {
    override val scheduleKey = "movie_daily_schedule"
    override val eyebrow = "MOVIE OF THE DAY"
    override val fallbackTitle = "Today's movie"
}

class TvShowOfDayWidgetProvider : DailyPickWidgetProvider() {
    override val scheduleKey = "tv_daily_schedule"
    override val eyebrow = "TV SHOW OF THE DAY"
    override val fallbackTitle = "Today's TV show"
}

class WellnessWidgetProvider : FlixQuestWidgetProvider() {
    override fun content(widgetData: SharedPreferences) = WidgetContent(
        eyebrow = "VIEWING INSIGHTS  |  THIS WEEK",
        title = widgetData.getString("wellness_title", null) ?: "Your week is ready",
        subtitle = widgetData.getString("wellness_subtitle", null)
            ?: "Watch something to begin your private insights",
        meta = widgetData.getString("wellness_meta", null) ?: "Viewing Insights",
        imagePath = null,
        deepLink = widgetData.getString("wellness_deep_link", null) ?: "flixquest://wellness",
        progress = widgetData.getInt("wellness_progress", 0),
        statA = "PRIVATE",
        statB = "THIS WEEK",
        statC = "↗ INSIGHT",
    )
}

class ContinueWatchingWidgetProvider : FlixQuestWidgetProvider() {
    override fun content(widgetData: SharedPreferences) = WidgetContent(
        eyebrow = "CONTINUE WATCHING",
        title = widgetData.getString("continue_title", null) ?: "Nothing in progress",
        subtitle = widgetData.getString("continue_subtitle", null)
            ?: "Your latest title will appear here",
        meta = widgetData.getString("continue_meta", null) ?: "Continue watching",
        imagePath = widgetData.getString("continue_image", null),
        deepLink = widgetData.getString("continue_deep_link", null) ?: "flixquest://wellness",
        progress = widgetData.getInt("continue_progress", 0),
        statA = widgetData.getInt("continue_progress", 0).toString() + "%",
        statB = "IN PROGRESS",
    )
}

class MyListWidgetProvider : FlixQuestWidgetProvider() {
    override fun content(widgetData: SharedPreferences) = WidgetContent(
        eyebrow = "MY LIST",
        title = widgetData.getString("my_list_title", null) ?: "Your list is empty",
        subtitle = widgetData.getString("my_list_subtitle", null) ?: "0 movies  |  0 TV shows",
        meta = widgetData.getString("my_list_meta", null) ?: "Build your watchlist",
        imagePath = widgetData.getString("my_list_image", null),
        deepLink = widgetData.getString("my_list_deep_link", null) ?: "flixquest://my-list",
        statA = "CURATED",
        statB = "FOR YOU",
    )
}
