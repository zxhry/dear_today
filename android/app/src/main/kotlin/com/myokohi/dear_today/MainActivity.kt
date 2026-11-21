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
        // Makes a day reel: every clip in order, each with its time in the middle
        // (or none), wide or tall, with or without sound.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dear_today/video")
            .setMethodCallHandler { call, result ->
                if (call.method != "exportDay") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val inputs = call.argument<List<String>>("inputs") ?: emptyList()
                val times = call.argument<List<String>>("times") ?: emptyList()
                val output = call.argument<String>("output") ?: ""
                val portrait = call.argument<Boolean>("portrait") ?: false
                val sound = call.argument<Boolean>("sound") ?: true
                try {
                    exportDay(inputs, times, output, portrait, sound) { error ->
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

    /** A see-through picture the size of the video with the time in the middle.
     *  [band] is the height of the picture itself (less than [height] in a tall
     *  reel, where the wide clip sits between black bars). */
    private fun timeOverlay(time: String, width: Int, height: Int, band: Float): Bitmap {
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = band / 15f // small and light, like the time in Threads-style vlogs
            textAlign = Paint.Align.CENTER
            typeface = Typeface.create("sans-serif", Typeface.NORMAL)
            letterSpacing = 0.05f
            setShadowLayer(band / 90f, 0f, 0f, Color.argb(150, 0, 0, 0))
        }
        val y = height / 2f - (paint.ascent() + paint.descent()) / 2f
        Canvas(bitmap).drawText(time, width / 2f, y, paint)
        return bitmap
    }

    @OptIn(UnstableApi::class)
    private fun exportDay(
        inputs: List<String>,
        times: List<String>,
        output: String,
        portrait: Boolean,
        sound: Boolean,
        done: (String?) -> Unit,
    ) {
        require(inputs.isNotEmpty()) { "No clips" }
        // One size for the whole reel: 1080p if any clip is 1080p, else 720p.
        // Wide reels fill 16:9; tall reels (9:16) keep each wide clip whole
        // between black bars.
        val sharp = inputs.any { val (w, h) = shownSize(it); maxOf(w, h) >= 1900 }
        val longSide = if (sharp) 1920 else 1280
        val shortSide = if (sharp) 1080 else 720
        val outW = if (portrait) shortSide else longSide
        val outH = if (portrait) longSide else shortSide
        val band = if (portrait) outW * 9f / 16f else outH.toFloat()
        val layout = if (portrait) Presentation.LAYOUT_SCALE_TO_FIT else Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP

        val items = inputs.mapIndexed { i, path ->
            val time = times.getOrElse(i) { "" }
            val size = Presentation.createForWidthAndHeight(outW, outH, layout)
            val videoEffects = if (time.isEmpty()) {
                ImmutableList.of<Effect>(size)
            } else {
                ImmutableList.of<Effect>(
                    size,
                    OverlayEffect(
                        ImmutableList.of<TextureOverlay>(
                            BitmapOverlay.createStaticBitmapOverlay(timeOverlay(time, outW, outH, band)),
                        ),
                    ),
                )
            }
            EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(path))))
                .setEffects(Effects(ImmutableList.of(), videoEffects))
                .setRemoveAudio(!sound)
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
