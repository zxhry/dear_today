package com.myokohi.dear_today

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.media.MediaMetadataRetriever
import android.net.Uri
import androidx.annotation.OptIn
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.effect.TextureOverlay
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import com.google.common.collect.ImmutableList
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// FragmentActivity is needed for the fingerprint / face / PIN prompt.
class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Makes a day's vlog: every clip in order, each with its time in the middle.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dear_today/video")
            .setMethodCallHandler { call, result ->
                if (call.method != "exportDay") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val inputs = call.argument<List<String>>("inputs") ?: emptyList()
                val times = call.argument<List<String>>("times") ?: emptyList()
                val output = call.argument<String>("output") ?: ""
                try {
                    exportDay(inputs, times, output) { error ->
                        if (error == null) result.success(output) else result.error("export_failed", error, null)
                    }
                } catch (e: Exception) {
                    result.error("export_failed", e.message, null)
                }
            }
    }

    /** The picture size of a clip as it's shown (turned the right way). */
    private fun shownSize(path: String): Pair<Int, Int> {
        val mmr = MediaMetadataRetriever()
        try {
            mmr.setDataSource(path)
            val w = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: 1280
            val h = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: 720
            val r = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            return if (r == 90 || r == 270) Pair(h, w) else Pair(w, h)
        } finally {
            mmr.release()
        }
    }

    /** A see-through picture the size of the video with the time in the middle. */
    private fun timeOverlay(time: String, width: Int, height: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = height / 22f
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create("sans-serif", Typeface.NORMAL)
            letterSpacing = 0.04f
            setShadowLayer(height / 110f, 0f, 0f, Color.argb(140, 0, 0, 0))
        }
        val y = height / 2f - (paint.ascent() + paint.descent()) / 2f
        Canvas(bitmap).drawText(time, width / 2f, y, paint)
        return bitmap
    }

    @OptIn(UnstableApi::class)
    private fun exportDay(inputs: List<String>, times: List<String>, output: String, done: (String?) -> Unit) {
        require(inputs.isNotEmpty()) { "No clips" }
        // One size for the whole vlog (16:9): 1080p if any clip is 1080p, else 720p.
        val sharp = inputs.any { val (w, h) = shownSize(it); maxOf(w, h) >= 1900 }
        val outW = if (sharp) 1920 else 1280
        val outH = if (sharp) 1080 else 720

        val items = inputs.mapIndexed { i, path ->
            val time = times.getOrElse(i) { "" }
            val videoEffects = ImmutableList.of<Effect>(
                Presentation.createForWidthAndHeight(outW, outH, Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP),
                OverlayEffect(ImmutableList.of<TextureOverlay>(BitmapOverlay.createStaticBitmapOverlay(timeOverlay(time, outW, outH)))),
            )
            EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(path))))
                .setEffects(Effects(ImmutableList.of(), videoEffects))
                .build()
        }
        val composition = Composition.Builder(ImmutableList.of(EditedMediaItemSequence.Builder(items).build())).build()

        val transformer = Transformer.Builder(this)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) = done(null)
                override fun onError(composition: Composition, exportResult: ExportResult, exportException: ExportException) =
                    done(exportException.message ?: "The video couldn't be made.")
            })
            .build()
        transformer.start(composition, output)
    }
}
